-- KIM_ARENA: the floor beyond the map.
--
-- gmarc meshes the map, its connected neighbours and a three-block ring of
-- the border block around them; past that ring the scene was cleared to
-- black, which a tall phone screen or a zoomed-out view shows as a void.
-- This lays one large, curve-tessellated plane under everything, textured
-- with the map's own border block -- the same 32x32 bake the 2D overworld
-- tiles across its void (World:borderImageFor), so it follows Crystal's
-- VOID FILL option (FADE / WATER / TREES; BLACK keeps the black void) and
-- the time-of-day palette. It sits a few pixels below the ground (under
-- recessed water too), so every real tile covers it and only the space
-- past the ring shows it. Battle Art's WORLD FILL works the same way.
local V = ...
local Voxel3D = V.require("Voxel3D")
local Mat4 = V.require("Mat4")
local VoidFloor = {}
local function diag(key, value)
  local fn = V.mod and rawget(V.mod, "_kimArenaDiag")
  if type(fn) == "function" then pcall(fn, key, value) end
end

local HEIGHT = -6
local BLOCK = 32
local RANGE = 32768
local cachedMesh = nil

local function axis()
  local positive, p, step, band = { 0 }, 0, 32, 512
  while p < RANGE do
    p = math.min(RANGE, p + step)
    positive[#positive + 1] = p
    if p >= band then step = math.min(step * 2, 2048); band = band * 2 end
  end
  local out = {}
  for i = #positive, 2, -1 do out[#out + 1] = -positive[i] end
  for i = 1, #positive do out[#out + 1] = positive[i] end
  return out
end

local function meshFor()
  if cachedMesh ~= nil then return cachedMesh or nil end
  local pts = axis()
  local verts, idx = {}, {}
  for z = 1, #pts do
    for x = 1, #pts do
      verts[#verts + 1] = { pts[x], HEIGHT, pts[z], pts[x] / BLOCK, pts[z] / BLOCK, 1 }
    end
  end
  local stride = #pts
  for z = 0, #pts - 2 do
    for x = 0, #pts - 2 do
      local a = z * stride + x + 1
      idx[#idx + 1] = a; idx[#idx + 1] = a + 1; idx[#idx + 1] = a + stride + 1
      idx[#idx + 1] = a; idx[#idx + 1] = a + stride + 1; idx[#idx + 1] = a + stride
    end
  end
  cachedMesh = Voxel3D.newMesh(verts, idx) or false
  return cachedMesh or nil
end

local function enabled()
  local fn = V.mod and rawget(V.mod, "_kimArenaVoidFloor")
  if type(fn) ~= "function" then return true end
  local ok, v = pcall(fn)
  return not ok or v ~= false
end

-- ------------------------------------------------------ voxel relief
-- Past the ring the plane alone reads as a painted carpet. Where the
-- border block is tall scenery (forest trees / canopies / walls), a band of
-- RELIEF continues it as voxels: one 16px box per cell at the border's own
-- height (from TileShape, so it follows the place), with a little per-cell
-- variation so the canopy is not a table top, textured with the same border
-- art. Built once per map into one static mesh (a few tens of thousands of
-- vertices, one draw call); cells under the map, its ring or a connected
-- neighbour's body are left out.
-- ffi is optional: some sandboxes hand mods no ffi, and a module-level
-- require that throws would take the whole overworld render down with it
local ffi
do local okF, f = pcall(require, "ffi"); if okF then ffi = f end end
local RELIEF_CELLS = 24          -- cells of relief beyond the ring
local reliefCache = {}           -- key -> mesh | false | "building"
local reliefJobs = {}            -- key -> coroutine (and key#d -> deadline setter)
local reliefDeadline

-- The ring is built from TileRenderer.borderBlockFor (outdoor maps ring
-- with the solid tree wall, NOT their own borderBlock, which on a route is
-- grass) -- the same block Structures uses -- so its tallest tile is the
-- height the relief continues at.
local function borderHeight(map)
  local okT, TileShape = pcall(V.require, "TileShape")
  if not okT then return nil end
  local okS, shapes = pcall(TileShape.forMap, map)
  if not okS or not shapes then return nil end
  local TR = (select(2, pcall(require, "src.render.TileRenderer")))
  local borderId = TR and TR.borderBlockFor and TR.borderBlockFor(map)
  -- TREES fill on an outdoor map: the ring is the round 32px canopy wall
  local env = map.def and map.def.environment
  -- (Ilex Forest is TILESET_FOREST with border block 5 -- the same canopy
  -- wall, whatever its environment says; Structures treats it the same way)
  local forest = map.tileset and map.tileset.id == "TILESET_FOREST" and borderId == 5
  if borderId and TR and (TR.voidFill or "trees") == "trees"
     and (env == "ROUTE" or env == "TOWN" or forest) then
    return 32, "canopy"
  end
  if shapes.borderBlocks and shapes.borderBlocks[map.id] ~= nil then borderId = shapes.borderBlocks[map.id] end
  local why = ("tileset %s, env %s, border %s, fill %s"):format(tostring(map.tileset and map.tileset.id),
    tostring(env), tostring(borderId), tostring(type(TR) == "table" and TR.voidFill or "?"))
  local blk = borderId and map.tileset and map.tileset.blocks and map.tileset.blocks[borderId + 1]
  if not blk then return nil, why end
  local best, cls = 0, nil
  for ty = -4, -1 do
    for tx = -4, -1 do
      local tile = blk[(ty % 4) * 4 + (tx % 4) + 1]
      local okB, sh = false, nil
      if tile then okB, sh = pcall(TileShape.at, map, shapes, tile, tx, ty) end
      if okB and sh and type(sh.h) == "number" and sh.h > best then best, cls = sh.h, sh.class end
    end
  end
  if best < 8 then return nil, why .. ", tallest " .. tostring(best) end
  return best, cls
end

local function hash2(x, z)
  local h = (x * 73856093) % 2147483647
  h = (h + z * 19349663) % 2147483647
  return h
end

local function buildRelief(world, height, tick, cls)
  local map = world.map
  local TR = (select(2, pcall(require, "src.render.TileRenderer")))
  local roundRing = (cls == "canopy" or cls == "cylinder" or cls == "tree" or cls == "stump")
    and (TR and (TR.voidFill or "trees") == "trees")
  local RING_PX = roundRing and 32 or 96
  local W, H = (map.def.width or 0) * 32, (map.def.height or 0) * 32
  local masks = { { -RING_PX, -RING_PX, W + RING_PX, H + RING_PX } }
  for _, nb in ipairs(world.neighbors or {}) do
    local d = nb.map and nb.map.def
    if d then
      masks[#masks + 1] = { nb.ox or 0, nb.oy or 0, (nb.ox or 0) + (d.width or 0) * 32,
        (nb.oy or 0) + (d.height or 0) * 32 }
    end
  end
  local x0 = -RING_PX - RELIEF_CELLS * 16
  local z0 = -RING_PX - RELIEF_CELLS * 16
  local nx = math.floor((W + 2 * RING_PX + 2 * RELIEF_CELLS * 16) / 16)
  local nz = math.floor((H + 2 * RING_PX + 2 * RELIEF_CELLS * 16) / 16)
  local function masked(x, z)
    local cx, cz = x + 8, z + 8
    for _, m in ipairs(masks) do
      if cx > m[1] and cx < m[3] and cz > m[2] and cz < m[4] then return true end
    end
    return false
  end
  -- per-cell heights (0 = masked: no box, and sides drop to the ground)
  local hs = {}
  for j = 0, nz - 1 do
    tick()
    for i = 0, nx - 1 do
      local x, z = x0 + i * 16, z0 + j * 16
      if masked(x, z) then hs[j * nx + i] = 0
      else hs[j * nx + i] = height + ((hash2(i + x0, j + z0) % 3) - 1) * 3 end
    end
  end
  local cap = nx * nz * 20
  -- ffi when there is one; otherwise a plain array indexed the same way
  local buf = ffi and ffi.new("float[?]", cap * 6) or {}
  local n = 0
  local function quad(ax, ay, az, bx, by, bz, cx2, cy2, cz2, dx, dy, dz, u0, v0, u1, v1, shade)
    local o = n * 6
    buf[o], buf[o+1], buf[o+2], buf[o+3], buf[o+4], buf[o+5] = ax, ay, az, u0, v0, shade
    buf[o+6], buf[o+7], buf[o+8], buf[o+9], buf[o+10], buf[o+11] = bx, by, bz, u1, v0, shade
    buf[o+12], buf[o+13], buf[o+14], buf[o+15], buf[o+16], buf[o+17] = cx2, cy2, cz2, u1, v1, shade
    buf[o+18], buf[o+19], buf[o+20], buf[o+21], buf[o+22], buf[o+23] = dx, dy, dz, u0, v1, shade
    n = n + 4
  end
  local function hAt(i, j)
    if i < 0 or j < 0 or i >= nx or j >= nz then return 0 end
    return hs[j * nx + i]
  end
  -- Forest borders: low-poly round trees (an eight-sided canopy per 32px
  -- tree, the size and spacing of the ring's own trees) instead of boxes
  if roundRing then
    local R, SIDES = 15, 8
    local ang = {}
    for k = 0, SIDES - 1 do
      local a = (k + 0.5) / SIDES * math.pi * 2
      ang[k] = { math.cos(a), math.sin(a) }
    end
    for j = 0, nz - 2, 2 do
      tick()
      for i = 0, nx - 2, 2 do
        local x, z = x0 + i * 16, z0 + j * 16
        local cx, cz = x + 16, z + 16
        if not masked(cx - 8, cz - 8) then
          local h = height + ((hash2(i + x0, j + z0) % 5) - 2) * 1.5
          local px, pz = {}, {}
          for k = 0, SIDES - 1 do px[k] = cx + ang[k][1] * R; pz[k] = cz + ang[k][2] * R end
          local function tq(a, b, c, d)
            quad(px[a], h, pz[a], px[b], h, pz[b], px[c], h, pz[c], px[d], h, pz[d],
              px[a] / 32, pz[a] / 32, px[c] / 32, pz[c] / 32, 1.0)
          end
          tq(0, 1, 2, 3); tq(0, 3, 4, 7); tq(4, 5, 6, 7)
          for k = 0, SIDES - 1 do
            local k2 = (k + 1) % SIDES
            local shade = 0.6 + 0.3 * (0.5 + 0.5 * ang[k][2])
            quad(px[k], h, pz[k], px[k2], h, pz[k2], px[k2], 0, pz[k2], px[k], 0, pz[k],
              (px[k] + pz[k]) / 32, h / 32, (px[k2] + pz[k2]) / 32, 0, shade)
          end
        end
      end
    end
  end
  for j = 0, nz - 1 do
    tick()
    for i = 0, nx - 1 do
      local h = (not roundRing) and hs[j * nx + i] or 0
      if h > 0 then
        local x, z = x0 + i * 16, z0 + j * 16
        local X, Z = x + 16, z + 16
        -- top (art locked to the block grid, like the plane)
        quad(x, h, z, X, h, z, X, h, Z, x, h, Z, x / 32, z / 32, X / 32, Z / 32, 1.0)
        -- exposed sides down to whatever is next door
        local e = hAt(i + 1, j); if e < h then quad(X, h, Z, X, h, z, X, e, z, X, e, Z, Z / 32, h / 32, z / 32, e / 32, 0.72) end
        local w = hAt(i - 1, j); if w < h then quad(x, h, z, x, h, Z, x, w, Z, x, w, z, z / 32, h / 32, Z / 32, w / 32, 0.72) end
        local s = hAt(i, j + 1); if s < h then quad(x, h, Z, X, h, Z, X, s, Z, x, s, Z, x / 32, h / 32, X / 32, s / 32, 0.86) end
        local nn = hAt(i, j - 1); if nn < h then quad(X, h, z, x, h, z, x, nn, z, X, nn, z, X / 32, h / 32, x / 32, nn / 32, 0.6) end
      end
    end
  end
  if n == 0 then return false end
  local ok, mesh = pcall(function()
    local order = { 0, 1, 2, 0, 2, 3 }
    if ffi and love.data and love.data.newByteData then
      local m = love.graphics.newMesh(Voxel3D.FORMAT, n, "triangles", "static")
      local data = love.data.newByteData(n * 24)
      ffi.copy(data:getFFIPointer(), buf, n * 24)
      m:setVertices(data); data:release()
      local idx = love.data.newByteData(n / 4 * 6 * 4)
      local ip = ffi.cast("uint32_t*", idx:getFFIPointer())
      for q = 0, n / 4 - 1 do
        for k = 1, 6 do ip[q * 6 + k - 1] = q * 4 + order[k] end
        if q % 2048 == 0 then tick() end
      end
      m:setVertexMap(idx, "uint32"); idx:release()
      return m
    end
    -- no ffi: Lua tables (slower, still built a slice at a time)
    local verts, map = {}, {}
    for v = 0, n - 1 do
      local o = v * 6
      verts[v + 1] = { buf[o], buf[o+1], buf[o+2], buf[o+3], buf[o+4], buf[o+5] }
      if v % 4096 == 0 then tick() end
    end
    for q = 0, n / 4 - 1 do
      for k = 1, 6 do map[#map + 1] = q * 4 + order[k] + 1 end
      if q % 2048 == 0 then tick() end
    end
    local m = love.graphics.newMesh(Voxel3D.FORMAT, verts, "triangles", "static")
    m:setVertexMap(map)
    return m
  end)
  return ok and mesh or false
end

local function reliefFor(world)
  local map = world.map
  local TR = (select(2, pcall(require, "src.render.TileRenderer")))
  local key = tostring(map.id) .. "|" .. tostring(TR and TR.voidFill)
  for _, nb in ipairs(world.neighbors or {}) do
    key = key .. "|" .. tostring(nb.map and nb.map.id) .. "@" .. tostring(nb.ox) .. "," .. tostring(nb.oy)
  end
  local hit = reliefCache[key]
  if hit ~= nil and hit ~= "building" then return hit or nil end
  -- built a few milliseconds per frame (never a hitch); drawn once done
  local job = reliefJobs[key]
  if not job then
    local h, cls = borderHeight(map)
    if not h then
      reliefCache[key] = false
      diag("voxel edge", "flat border here (" .. tostring(map.id) .. "; " .. tostring(cls) .. ")")
      return nil
    end
    local deadline = 0
    local function tick()
      if love.timer.getTime() > deadline then coroutine.yield() end
    end
    job = coroutine.create(function() return buildRelief(world, h, tick, cls) end)
    reliefJobs[key] = job
    reliefCache[key] = "building"
    reliefDeadline = function(d) deadline = d end
    reliefJobs[key .. "#d"] = reliefDeadline
  end
  local setDeadline = reliefJobs[key .. "#d"]
  setDeadline(love.timer.getTime() + 0.003)
  local okC, result = coroutine.resume(job)
  if coroutine.status(job) ~= "dead" then return nil end
  reliefJobs[key], reliefJobs[key .. "#d"] = nil, nil
  local mesh = okC and result or false
  diag("voxel edge", okC and (mesh and ("built " .. mesh:getVertexCount() .. " verts") or "nothing to build")
    or ("FAILED: " .. tostring(result)))
  -- keep a handful; old ones go
  local count = 0
  for k, m in pairs(reliefCache) do count = count + 1 end
  if count > 6 then
    for k, m in pairs(reliefCache) do
      if type(m) == "userdata" then pcall(m.release, m) end
      if m ~= "building" then reliefCache[k] = nil end
    end
  end
  reliefCache[key] = mesh
  return mesh or nil
end

-- gmarc's own round tree (the hull template its ring stamps), when this
-- map's structures are already built: copies of it, two trees deep past the
-- ring, look exactly like the edge -- textured with the terrain atlas.
local templateCache = {}
local function treeTemplate(map)
  local okS, Structures = pcall(V.require, "Structures")
  if not okS or not Structures.cached then return nil end
  local S = Structures.cached(map.id)
  local st = S and S.roundStamps and S.roundStamps[1]
  if not (st and st.quads and #st.quads > 0) then return nil end
  return st.quads
end

local function buildTreeBand(world, quads, tick)
  local map = world.map
  local W, H = (map.def.width or 0) * 32, (map.def.height or 0) * 32
  local RING, ROWS = 32, 2
  local masks = { { -RING, -RING, W + RING, H + RING } }
  for _, nb in ipairs(world.neighbors or {}) do
    local d = nb.map and nb.map.def
    if d then masks[#masks + 1] = { nb.ox or 0, nb.oy or 0, (nb.ox or 0) + (d.width or 0) * 32,
      (nb.oy or 0) + (d.height or 0) * 32 } end
  end
  local function masked(cx, cz)
    for _, m in ipairs(masks) do
      if cx > m[1] and cx < m[3] and cz > m[2] and cz < m[4] then return true end
    end
    return false
  end
  local verts, map_ = {}, {}
  local n = 0
  local x0, z0 = -RING - ROWS * 32, -RING - ROWS * 32
  local nx, nz = (W + 2 * (RING + ROWS * 32)) / 32, (H + 2 * (RING + ROWS * 32)) / 32
  for j = 0, nz - 1 do
    tick()
    for i = 0, nx - 1 do
      local cx, cz = x0 + i * 32 + 16, z0 + j * 32 + 16
      if not masked(cx, cz) then
        for _, q in ipairs(quads) do
          for k = 1, 4 do
            local c = q[k]
            local uv = q.uv and q.uv[k] or { q.u, q.v }
            local sh = type(q.shade) == "table" and q.shade[k] or q.shade or 1
            verts[#verts + 1] = { c[1] + cx, c[2], c[3] + cz, uv[1], uv[2], sh }
          end
          local b = n * 4
          map_[#map_ + 1] = b + 1; map_[#map_ + 1] = b + 2; map_[#map_ + 1] = b + 3
          map_[#map_ + 1] = b + 1; map_[#map_ + 1] = b + 3; map_[#map_ + 1] = b + 4
          n = n + 1
        end
      end
    end
  end
  if n == 0 then return false end
  local ok, mesh = pcall(function()
    local m = love.graphics.newMesh(Voxel3D.FORMAT, verts, "triangles", "static")
    m:setVertexMap(map_)
    return m
  end)
  return ok and mesh or false
end

local treeJobs = {}
local function treeBandFor(world)
  local map = world.map
  local key = tostring(map.id)
  for _, nb in ipairs(world.neighbors or {}) do key = key .. "|" .. tostring(nb.map and nb.map.id) end
  local hit = templateCache[key]
  if hit ~= nil and hit ~= "building" then return hit or nil end
  local quads = treeTemplate(map)
  if not quads then return nil end
  local job = treeJobs[key]
  local deadline = 0
  if not job then
    job = { co = coroutine.create(function()
      return buildTreeBand(world, quads, function()
        if love.timer.getTime() > job.deadline then coroutine.yield() end
      end)
    end), deadline = 0 }
    treeJobs[key] = job
    templateCache[key] = "building"
  end
  job.deadline = love.timer.getTime() + 0.003
  local okC, result = coroutine.resume(job.co)
  if coroutine.status(job.co) ~= "dead" then return nil end
  treeJobs[key] = nil
  templateCache[key] = okC and result or false
  diag("voxel edge", okC and result and ("gmarc trees, " .. result:getVertexCount() .. " verts")
    or ("tree copies FAILED: " .. tostring(result)))
  return templateCache[key] or nil
end

local function reliefEnabled()
  local fn = V.mod and rawget(V.mod, "_kimArenaVoidRelief")
  if type(fn) ~= "function" then return true end
  local ok, v = pcall(fn)
  return not ok or v ~= false
end

-- `world` is the engine's Gen 2 World (VoxelScene's state); cx, cy the
-- scene centre in world pixels.
function VoidFloor.draw(world, cx, cy, atlas)
  if not enabled() then return false end
  if not (world and world.map and type(world.borderImageFor) == "function") then return false end
  local okI, image = pcall(world.borderImageFor, world, world.map.id)
  if okI and not image then
    -- KIM_ARENA 0.9.1: WORLD EDGE FILL always repeats the map's OWN border,
    -- like the original game. Crystal's VOID FILL = BLACK returns no image,
    -- so ask once more with FADE (the map's own border block) for this draw.
    local okB, BorderFill = pcall(require, "src.world.gen2.BorderFill")
    if okB and type(BorderFill) == "table" and BorderFill.voidFill == "black" then
      BorderFill.voidFill = "fade"
      okI, image = pcall(world.borderImageFor, world, world.map.id)
      BorderFill.voidFill = "black"
    end
  end
  if not okI or not image then return false end
  local mesh = meshFor()
  if not mesh then return false end
  -- snapped to whole blocks so the art stays locked to the map's block grid
  local ox = math.floor((tonumber(cx) or 0) / BLOCK) * BLOCK
  local oz = math.floor((tonumber(cy) or 0) / BLOCK) * BLOCK
  pcall(image.setWrap, image, "repeat", "repeat")
  Voxel3D.seams(false)
  Voxel3D.glass(false)
  Voxel3D.draw(mesh, image, Mat4.translate(ox, 0, oz))
  if not reliefEnabled() then diag("voxel edge", "off (VOXEL EDGE setting)") end
  -- forest edge: copies of gmarc's own trees when its template is at hand
  local band = nil
  if reliefEnabled() and atlas then
    local okB, b = pcall(treeBandFor, world)
    if okB then band = b else diag("voxel edge", "tree copies FAILED: " .. tostring(b)) end
    if band then Voxel3D.draw(band, atlas, Mat4.translate(0, 0, 0)) end
  end
  if reliefEnabled() and not band then
    local okR, relief = pcall(reliefFor, world)
    if not okR then diag("voxel edge", "FAILED: " .. tostring(relief)) end
    if okR and relief then Voxel3D.draw(relief, image, Mat4.translate(0, 0, 0)) end
  end
  Voxel3D.glass(true)
  Voxel3D.seams(true)
  return true
end

VoidFloor.HEIGHT = HEIGHT
return VoidFloor
