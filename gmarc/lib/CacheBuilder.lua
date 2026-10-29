-- gen2-aio 0.9.77: BUILD 3D CACHE.
--
-- Walks every map of the game and builds the two variants play asks for --
-- BODY (what a neighbour or a door destination draws) and FULL (the map you
-- stand on, with its border ring masked under its connected neighbours) --
-- through ChunkMesher's own queue, so each finished build lands in the
-- VOXEL DISK CACHE exactly as a visit would have left it (MeshStore keys
-- the file on the same inputs). Afterwards no map ever builds during play:
-- every first visit is a restore.
--
-- A variant already on storage is skipped, so stopping and starting again
-- carries on where it left off. Maps built here are dropped from memory as
-- soon as their files are queued; the maps around the player (already in
-- memory) are left alone. The FULL masks come from the engine's own
-- neighbour walk (World.computeNeighbors, 2 hops, the current view size),
-- so they match what the scene will ask for on this screen.
local V = ...
local CacheBuilder = {}
CacheBuilder.__index = CacheBuilder

local HOPS = 2          -- World's NEIGHBOR_HOPS (Gen2Compat.neighborHops)
local BACKLOG = 2       -- packed maps waiting for the writer before we wait

local function neighbourWalk()
  local okW, World = pcall(require, "src.world.gen2.World")
  if okW and type(World) == "table" and type(World.computeNeighbors) == "function" then
    return World.computeNeighbors
  end
  return nil
end

-- every map id with a def and a tileset, in a stable order
local function mapIds(world)
  local ids = {}
  for id, def in pairs(world.maps or {}) do
    if type(def) == "table" and world.tilesets and world.tilesets[def.tileset] then
      ids[#ids + 1] = id
    end
  end
  table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)
  return ids
end

-- nil when a build can run, else why not (shown on the BUILD 3D CACHE row)
function CacheBuilder.whyNot(world)
  if type(world) ~= "table" or type(world.maps) ~= "table" then return "the world is not loaded yet" end
  local okS, S = pcall(V.require, "MeshStore")
  if not (okS and type(S) == "table") then return "the disk cache did not load (" .. tostring(S) .. ")" end
  if type(S.whyOff) == "function" then
    local okW, why = pcall(S.whyOff)
    if not okW then return "the disk cache failed (" .. tostring(why) .. ")" end
    if why then return why end
  end
  if not S.enabled() or S.exists == nil then return "the disk cache is off" end
  return nil
end
function CacheBuilder.available(world)
  return CacheBuilder.whyNot(world) == nil
end

function CacheBuilder.new(world)
  local self = setmetatable({}, CacheBuilder)
  self.world = world
  self.ids = mapIds(world)
  self.total = #self.ids
  self.index = 0
  self.built, self.skipped, self.failed = 0, 0, 0
  self.done = self.total == 0
  return self
end

-- the masks the scene would pass for `id`'s FULL build
function CacheBuilder:masks(id)
  local walk = neighbourWalk()
  local w = self.world
  local vw, vh = tonumber(w.viewW), tonumber(w.viewH)
  if not (walk and vw and vh) then return nil end
  local ok, list = pcall(walk, w.maps, id, HOPS, vw, vh)
  if not ok or type(list) ~= "table" then return nil end
  local masks = {}
  for _, nb in ipairs(list) do
    local def = w.maps[nb.id]
    if def then
      masks[#masks + 1] = { nb.ox, nb.oy, nb.ox + def.width * 32, nb.oy + def.height * 32 }
    end
  end
  return masks
end

local function newMap(world, id)
  local def = world.maps[id]
  local tset = def and world.tilesets[def.tileset]
  local okM, Map = pcall(require, "src.world.Map")
  if not (tset and okM) then return nil end
  local ok, m = pcall(Map.new, def, tset)
  return ok and m or nil
end

-- the next map's work, or nil when every map is done
function CacheBuilder:open()
  self.index = self.index + 1
  local id = self.ids[self.index]
  if id == nil then return nil end
  local map = newMap(self.world, id)
  if not map then
    self.failed = self.failed + 1
    return self:open()
  end
  local masks = self:masks(id)
  local units = { { body = true } }
  if masks then units[2] = { body = false, masks = masks } end
  local CM = V.require("ChunkMesher")
  return { id = id, map = map, units = units, k = 1, wrote = false,
           resident = CM.cached(id) }
end

-- One frame of work inside `budget` seconds. Returns true once finished.
function CacheBuilder:step(budget)
  if self.done then return true end
  local CM, S = V.require("ChunkMesher"), V.require("MeshStore")
  if not S.enabled() then self.done, self.off = true, true; return true end
  local clock = love.timer.getTime
  local deadline = clock() + (budget or 0.03)
  while clock() < deadline do
    local cur = self.cur
    if not cur then
      cur = self:open()
      if not cur then self.done = true; return true end
      self.cur = cur
    end
    local u = cur.units[cur.k]
    if not u then
      -- every variant of this map is on storage (or could not be built)
      if cur.wrote then self.built = self.built + 1
      elseif cur.missing then self.failed = self.failed + 1
      else self.skipped = self.skipped + 1 end
      if cur.touched and not cur.resident then pcall(CM.invalidate, cur.id) end
      self.cur = nil
    elseif u.started then
      if CM.queued(cur.map, u.body) then
        CM.pump(true)
        return false
      end
      if CM.stored(cur.map, u.body, u.masks) then cur.wrote = true
      else cur.missing = true end
      cur.k = cur.k + 1
    elseif CM.stored(cur.map, u.body, u.masks) or cur.resident then
      -- already on storage; a map in play is the scene's to build
      cur.k = cur.k + 1
    else
      if S.backlog() > BACKLOG then return false end
      CM.request(cur.map, u.body, u.masks, false)
      u.started, cur.touched = true, true
    end
  end
  return false
end

-- 0..1, counting the map in progress as half done
function CacheBuilder:progress()
  if self.total == 0 then return 1 end
  local n = self.index - (self.cur and 0.5 or 0)
  return math.max(0, math.min(1, n / self.total))
end

-- drop the map in progress (its queued build goes with it)
function CacheBuilder:stop()
  local cur = self.cur
  if cur and cur.touched and not cur.resident then pcall(V.require("ChunkMesher").invalidate, cur.id) end
  self.cur = nil
  self.done = true
end

return CacheBuilder
