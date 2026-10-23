-- KIM_ARENA: VOXEL PRECACHE.
--
-- gmarc keeps the current map, its rendered neighbours and the previous
-- neighbourhood warm. This looks one step ahead through DOORS: while you stand
-- in an area, the body mesh of every map its warps lead to (up to MAX) is
-- queued through ChunkMesher's own background queue at idle priority, and
-- those maps count as live so they are not evicted before use. Stepping
-- through a door then swaps in a ready mesh instead of building one; the
-- border ring still builds on arrival, as it always has, behind the body.
-- "Back to where you came from" warps (destWarp 0xff) are skipped: that map is
-- the previous neighbourhood, which ChunkMesher already keeps.
local V = ...
local Prefetch = {}
local MAX = 12

local maps = {}        -- id -> Map built for prefetching (bounded below)
local mapCount = 0

function Prefetch.enabled()
  local mod = V and V.mod
  local fn = mod and rawget(mod, "_kimArenaPrecache")
  if type(fn) ~= "function" then return true end
  local ok, on = pcall(fn)
  return not ok or on ~= false
end

-- destination map ids of the current map's doors
function Prefetch.ids(state)
  if not Prefetch.enabled() then return {} end
  local map = state and state.map
  local warps = map and map.def and map.def.warps
  if type(warps) ~= "table" or type(state.maps) ~= "table" then return {} end
  local seen = { [map.id] = true }
  for _, nb in ipairs(state.neighbors or {}) do
    if nb.map then seen[nb.map.id] = true elseif nb.id then seen[nb.id] = true end
  end
  local out = {}
  for _, w in ipairs(warps) do
    local id = w.destMap
    if id ~= nil and w.destWarp ~= 0xff and not seen[id] and state.maps[id] then
      seen[id] = true
      out[#out + 1] = id
      if #out >= MAX then break end
    end
  end
  return out
end

local function mapFor(state, id)
  if maps[id] then return maps[id] end
  local def = state.maps[id]
  local tset = def and state.tilesets and state.tilesets[def.tileset]
  if not tset then return nil end
  local okM, Map = pcall(require, "src.world.Map")
  if not okM then return nil end
  local ok, m = pcall(Map.new, def, tset)
  if not ok or not m then return nil end
  if mapCount >= 48 then maps, mapCount = {}, 0 end   -- keep the stand-ins bounded
  maps[id] = m
  mapCount = mapCount + 1
  return m
end

-- queue the door destinations' body meshes behind whatever is urgent
function Prefetch.request(state, ChunkMesher)
  if not Prefetch.enabled() then return end
  local okP, pending = pcall(ChunkMesher.pending)
  if okP and tonumber(pending) and tonumber(pending) > 3 then return end
  for _, id in ipairs(Prefetch.ids(state)) do
    local m = mapFor(state, id)
    if m then pcall(ChunkMesher.request, m, true, nil, false) end
  end
end

return Prefetch
