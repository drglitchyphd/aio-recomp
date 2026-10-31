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
    if t.surfaces and type(t.voxelEdits) == "table" then
      total = total + #t.voxelEdits   -- hand-built in the data file (mansion pieces)
      check(editsOf(t) == t.voxelEdits, "a table list is used as it is")
    end
    if t.surfaces and type(t.voxelEdits) == "string" then
      local e = editsOf(t)
      -- 0.9.85: decoded per call and NOT kept on the template (a whole-game
      -- BUILD 3D CACHE would otherwise bring every list back into memory)
      check(type(e) == "table" and type(t.voxelEdits) == "string", "decoded, template stays compact: " .. tostring(t.id))
      total = total + #e
      if t.spriteRoof then roofs = roofs + 1 end
      local again = editsOf(t)
      check(again ~= e and #again == #e, "a second call decodes the same list afresh")
    end
  end
end
-- every template decoded (what BUILD 3D CACHE does) leaves nothing behind
collectgarbage(); collectgarbage()
local afterMB = (collectgarbage("count") - base) / 1024
check(afterMB < heapMB + 20, ("decoding every template keeps nothing (%.0f MB after, %.0f before)"):format(afterMB, heapMB))
-- the count the fully expanded file produced (0.9.83), roof pass applied;
-- 1.0.0 gmarc 1.0.17 merge: +89 from upstream's small-tree polish (the
-- Johto/modern/forest saplings +12 each, kanto_sapling +12, forest_cut_tree +41)
check(total == 2408453, "every edit decodes, same as the eager load: " .. total)
check(roofs > 0, "pitched Kanto roofs get their spriteRoof on decode: " .. roofs)
local sample = data.buildings.TILESET_CAVE and data.buildings.TILESET_CAVE[1]
if sample and sample.voxelEdits then
  local first = editsOf(sample)[1]
  check(type(first.x) == "number" and type(first.y) == "number" and type(first.z) == "number", "numeric coords")
end
print(("voxel heights lazy: %d checks PASS (load %.0f ms, %.0f MB)"):format(n, loadMs, heapMB))
