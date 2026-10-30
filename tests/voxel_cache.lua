-- 0.9.77 BUILD 3D CACHE: gmarc/lib/CacheBuilder.lua over a stand-in
-- ChunkMesher / MeshStore, and lib/gen2_aio/voxel_cache.lua's question and
-- build page over a stand-in hub. Run from the repo root: luajit tests/voxel_cache.lua
local n = 0
local function check(c, m) if not c then error("FAIL: " .. m, 2) end n = n + 1 end
local t = 0
love = { timer = { getTime = function() t = t + 0.001; return t end } }

-- ---- the world: A connects east to B; C is an interior; D has no tileset
local maps = {
  A = { width = 4, height = 3, tileset = "town", connections = { east = { mapId = "B", offset = 0 } } },
  B = { width = 2, height = 3, tileset = "town", connections = { west = { mapId = "A", offset = 0 } } },
  C = { width = 1, height = 1, tileset = "house" },
  D = { width = 1, height = 1, tileset = "missing" },
}
local world = { maps = maps, tilesets = { town = {}, house = {} }, viewW = 160, viewH = 144 }
package.loaded["src.world.Map"] = { new = function(def) return { id = def._id, def = def } end }
for id, def in pairs(maps) do def._id = id end
package.loaded["src.world.gen2.World"] = { computeNeighbors = function(all, root)
  local out = {}
  for dir, c in pairs(all[root].connections or {}) do
    out[#out + 1] = { id = c.mapId, ox = dir == "east" and all[root].width * 32 or -all[c.mapId].width * 32, oy = 0 }
  end
  return out
end }

-- ---- stand-in ChunkMesher / MeshStore
local stored, queue, resident, invalidated, requests = {}, {}, {}, {}, {}
local backlog = 0
local function key(map, body, masks)
  local k = map.id .. (body and ":body" or ":full")
  for _, m in ipairs(masks or {}) do k = k .. "|" .. table.concat(m, ",") end
  return k
end
local CM = {
  stored = function(map, body, masks) return stored[key(map, body, masks)] == true end,
  queued = function(map, body) return queue[map.id .. (body and ":body" or ":full")] ~= nil end,
  cached = function(id) return resident[id] == true end,
  invalidate = function(id) invalidated[#invalidated + 1] = id end,
  request = function(map, body, masks)
    requests[#requests + 1] = key(map, body, masks)
    queue[map.id .. (body and ":body" or ":full")] = key(map, body, masks)
  end,
  pump = function()
    for q, k in pairs(queue) do stored[k] = true; queue[q] = nil; return end
  end,
}
local S = { enabled = function() return true end, exists = function() return false end,
  backlog = function() return backlog end }
local V = { require = function(name)
  if name == "ChunkMesher" then return CM elseif name == "MeshStore" then return S end
  error("unexpected " .. name)
end }
local CB = assert(loadfile("gmarc/lib/CacheBuilder.lua"))(V)

check(CB.available(world), "available with a disk cache")
local b = CB.new(world)
check(b.total == 3, "maps with a tileset only: " .. b.total)
local m = b:masks("A")
check(#m == 1 and m[1][1] == 128 and m[1][3] == 128 + 64, "FULL masks are the neighbours' bodies")
stored["C:body"] = true; stored["C:full"] = true    -- C was cached by an earlier run
resident.B = true                                    -- B is around the player
for _ = 1, 200 do if b:step(0.01) then break end end
check(b.done, "finishes")
check(stored["A:body"] and stored["A:full|128,0,192,96"], "A built in both variants, with masks")
check(b.built == 1 and b.skipped == 2 and b.failed == 0, ("counts %d/%d/%d"):format(b.built, b.skipped, b.failed))
check(#invalidated == 1 and invalidated[1] == "A", "only the map it built leaves memory")
for _, r in ipairs(requests) do check(not r:find("^[BC]:"), "no request for B or C: " .. r) end
check(b:progress() == 1, "progress 100%")

-- the writer's backlog holds new requests
stored, requests, resident, invalidated = {}, {}, {}, {}
backlog = 5
local b2 = CB.new(world)
b2:step(0.01)
check(#requests == 0, "waits while the writer is behind")
backlog = 0
b2:step(0.002)
check(#requests >= 1, "carries on once it catches up")
b2:stop()
check(b2.done and invalidated[1] == requests[1]:match("^(%w+)"), "STOP drops the map in progress")

-- ---- lib/gen2_aio/voxel_cache.lua
local options, pages, hooks = {}, {}, {}
local stack = { states = {} }
function stack:push(s) self.states[#self.states + 1] = s end
function stack:pop() self.states[#self.states] = nil end
local Hub = { extras = {},
  page = function(game, rows, title)
    local p = { rows = rows, title = title, update = function() end }
    game.stack:push(p); pages[#pages + 1] = p; return p
  end,
  read = function(k) if options[k] == nil and k == "voxelDiskCache" then return true end return options[k] end,
  write = function(_, k, v) options[k] = v end }
local voxelActive = true
local gmarcMod = { _kimArenaBuildId = function() return "b1" end }
local lib = { mod = gmarcMod, require = function(name)
  if name == "CacheBuilder" then return CB end
  if name == "VoxelState" then return { active = function() return voxelActive end } end
  return V.require(name)
end }
local free = true
local mod = { exports = { voxel = { lib = lib } },
  hooks = { wrap = function(_, name, fn) hooks[name] = fn end } }
mod._kimArenaHub = Hub
mod._kimArenaQuick = { overworld = function() return free end }
local VC = assert(loadfile("lib/gen2_aio/voxel_cache.lua"))()({ mod = mod })
check(VC and hooks["core.update"], "installed")
local game = { world = world, stack = stack }
local function tick(dt) hooks["core.update"](function() end, game, dt or 0.5) end
local row = Hub.extras.voxelCache(game)[1]
check(row and row.id == "gen2-aio:voxel_cache" and row.value() == nil, "ADVANCED row, not built yet")
tick(); tick()
check(#pages == 0, "waits until the player has been free a moment")
tick(); tick(); tick()
check(#pages == 1 and pages[1].title == "BUILD 3D CACHE?", "asks once the player is free")
tick(); tick(); tick(); tick(); tick()
check(#pages == 1, "asks once per start")
-- BUILD NOW opens the build page; its update drives the build
stored, requests, resident, invalidated = {}, {}, {}, {}
pages[1].rows[1].activate(game)
local p = stack.states[#stack.states]
check(p and p.title == "BUILD 3D CACHE" and #stack.states == 1, "BUILD NOW swaps to the build page")
for _ = 1, 200 do p:update(0.016) end
check(options.voxelCacheDone == "b1", "a finished build is remembered for this voxel build")
check(row.value() == "BUILT", "ADVANCED row says BUILT")
-- 0.9.85: the finished page: summary, restart note (selected), close
check(p.rows[1].label == "FINISHED" and p.rows[1].value():find("NEW"), "the page says FINISHED")
check(p.rows[2].label == "RESTART RECOMMENDED" and p.index == 2
  and p.rows[2].help:find("close and reopen", 1, true), "it asks for a restart, with the row selected")
check(p.view[#p.view].cancel, "BACK stays last")
p.rows[3].activate(game)
check(#stack.states == 0, "CLOSE leaves")
-- a page left mid-build stops its build
stored = {}
options.voxelCacheDone = nil
VC.open(game)
local p2 = stack.states[#stack.states]
p2:update(0.016)
stack:pop()
tick()
check(options.voxelCacheDone == nil and row.value() == nil, "leaving mid-build stops it unfinished")
local before = #requests
p2:update(0.016); tick()
check(#requests == before, "nothing more is built after leaving")
-- DON'T ASK AGAIN
local mod2 = { exports = mod.exports, hooks = { wrap = function(_, name, fn) hooks[name] = fn end } }
mod2._kimArenaHub = Hub; mod2._kimArenaQuick = mod._kimArenaQuick
pages = {}
assert(loadfile("lib/gen2_aio/voxel_cache.lua"))()({ mod = mod2 })
for _ = 1, 6 do tick() end
check(#pages == 1, "asks again next start (LATER)")
pages[1].rows[3].activate(game)
check(options.voxelCacheAsk == false and #stack.states == 0, "DON'T ASK AGAIN")
pages = {}
assert(loadfile("lib/gen2_aio/voxel_cache.lua"))()({ mod = mod2 })
for _ = 1, 6 do tick() end
check(#pages == 0, "not asked after DON'T ASK AGAIN")
-- not asked with the 3D world off
options.voxelCacheAsk = nil
voxelActive = false
assert(loadfile("lib/gen2_aio/voxel_cache.lua"))()({ mod = mod2 })
for _ = 1, 6 do tick() end
check(#pages == 0, "not asked with the 3D world off")
-- 0.9.82: the row stays listed when a build cannot run, and says why
S.whyOff = function() return "VOXEL DISK CACHE is OFF" end
local off = Hub.extras.voxelCache(game)[1]
check(off and off.value() == "OFF" and off.help:find("VOXEL DISK CACHE is OFF", 1, true), "listed as OFF with the reason")
local before = #stack.states
off.activate(game)
check(#stack.states == before, "an OFF row opens nothing")
S.whyOff = function() return nil end
check(Hub.extras.voxelCache(game)[1].value() ~= "OFF", "back on once the cache works")
-- 0.9.84: BUILD 3D CACHE over the REAL MeshStore. The device's sandbox has
-- no ffi and no love.filesystem; what the store needs is mod.cache (reached
-- through the voxel proxy's __index) and love.data -- with those the row is
-- available, without them it is OFF and says why.
local function realStore(mod)
  return assert(loadfile("gmarc/lib/MeshStore.lua"))({ mod = mod })
end
local function realCB(S2)
  return assert(loadfile("gmarc/lib/CacheBuilder.lua"))({ require = function(name)
    if name == "MeshStore" then return S2 end
    return V.require(name)
  end })
end
local files = {}
local fakeCache = {
  write = function(_, rel, bytes) assert(type(bytes) == "string"); files[rel] = bytes; return true end,
  read = function(_, rel) return files[rel] end,
  info = function(_, rel) return files[rel] and { type = "file", size = #files[rel] } or nil end,
  exists = function(_, rel) return files[rel] ~= nil end,
  delete = function(_, rel) files[rel] = nil; return true end,
}
local mainMod = { id = "gen2-aio", cache = fakeCache }
local proxy = setmetatable({}, { __index = mainMod })
proxy._kimArenaBuildId = function() return "b1" end
local noData = realStore(proxy)
check(noData.whyOff():find("love.data", 1, true), "no love.data: OFF with the reason: " .. tostring(noData.whyOff()))
check(realCB(noData).whyNot(world) == noData.whyOff(), "BUILD 3D CACHE gives the store's reason")
love.data = { pack = function() return "" end, compress = function(_, _, s) return s end,
  newByteData = function() return {} end }
local real = realStore(proxy)
check(real.whyOff() == nil, "mod.cache + love.data: the cache works without ffi: " .. tostring(real.whyOff()))
check(realCB(real).available(world), "BUILD 3D CACHE is available")
check(real.save("b1-A_body_1.kms", "blob") and files["voxel/b1-A_body_1.kms"] == "blob", "writes through mod.cache")
check(real.exists("b1-A_body_1.kms") and real.load("b1-A_body_1.kms") == "blob", "and reads back")
check(files["voxel/index.txt"] == "b1-A_body_1.kms\n", "the index lists it for the old-build sweep")
local bare = realStore(setmetatable({}, { __index = { id = "gen2-aio" } }))
check(bare.whyOff():find("no mod.cache", 1, true), "no mod.cache: OFF with the reason: " .. tostring(bare.whyOff()))
love.data = nil
print(("voxel cache: %d checks PASS"):format(n))
