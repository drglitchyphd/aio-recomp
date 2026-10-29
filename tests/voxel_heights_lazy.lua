-- 0.9.84: gmarc/data/voxel_heights.lua keeps building voxelEdits as compact
-- strings, decoded per template on first use (gmarc/lib/Buildings.lua
-- editsOf). Expanded at load they were ~17 million tables: a 600 MB heap and
-- seconds of load on every start, and a garbage collector walking all of it
-- for the rest of the session. Run from the repo root: luajit tests/voxel_heights_lazy.lua
local n = 0
local function check(c, m) if not c then error("FAIL: " .. m, 2) end n = n + 1 end
collectgarbage(); collectgarbage()
local base = collectgarbage("count")
local t0 = os.clock()
local data = assert(loadfile("gmarc/data/voxel_heights.lua"))({})
local loadMs = (os.clock() - t0) * 1000
collectgarbage(); collectgarbage()
local heapMB = (collectgarbage("count") - base) / 1024
check(loadMs < 1000, ("loads in under a second (%.0f ms)"):format(loadMs))
check(heapMB < 120, ("stays small in memory (%.0f MB)"):format(heapMB))
local strings, fixes = 0, 0
for _, list in pairs(data.buildings) do
  for _, t in ipairs(list) do
    if type(t.voxelEdits) == "string" then strings = strings + 1 end
    if t.editsFix then fixes = fixes + 1 end
  end
end
check(strings > 300, "edits ship as strings: " .. strings)
check(fixes > 0, "the Kanto roof pass is deferred: " .. fixes)

-- Buildings.editsOf, standalone (BuildBudget stubbed)
local src = assert(io.open("gmarc/lib/Buildings.lua")):read("*a")
local body = assert(src:match("(local function editsOf%(t%).-\nend\n)"), "editsOf in Buildings.lua")
local editsOf = assert(loadstring("local Budget = ...\n" .. body .. "\nreturn editsOf"))({ tick = function() end })
local total, roofs = 0, 0
for _, list in pairs(data.buildings) do
  for _, t in ipairs(list) do
    if t.surfaces and t.voxelEdits ~= nil then
      local e = editsOf(t)
      check(type(e) == "table" and t.voxelEdits == e and not t.editsFix, "decoded once and kept: " .. tostring(t.id))
      total = total + #e
      if t.spriteRoof then roofs = roofs + 1 end
      check(editsOf(t) == e, "a second call reuses the list")
    end
  end
end
-- the count the fully expanded file produced (0.9.83), roof pass applied
check(total == 2408364, "every edit decodes, same as the eager load: " .. total)
check(roofs > 0, "pitched Kanto roofs get their spriteRoof on decode: " .. roofs)
local sample = data.buildings.TILESET_CAVE and data.buildings.TILESET_CAVE[1]
if sample and sample.voxelEdits then
  local first = sample.voxelEdits[1]
  check(type(first.x) == "number" and type(first.y) == "number" and type(first.z) == "number", "numeric coords")
end
print(("voxel heights lazy: %d checks PASS (load %.0f ms, %.0f MB)"):format(n, loadMs, heapMB))
