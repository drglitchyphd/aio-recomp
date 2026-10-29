-- VOXEL DISK CACHE (gmarc/lib/MeshStore.lua).
-- 0.9.80: save, exists, load back, the DIAGNOSTICS line, a cache that
-- cannot start says why instead of throwing.
-- 0.9.84: the sandbox-safe backend -- mod.cache files, love.data packing,
-- no ffi and no worker thread -- plus the old-build sweep through the index
-- file, and (with AIO_ENGINE_SRC) a synthetic map built END TO END through
-- ChunkMesher inside the engine's real mod sandbox (src/mods/Sandbox.lua:
-- ffi denied, love.filesystem blocked) with the engine's real mod.cache
-- (src/mods/ImportAccess.lua): the cold build persists, and the restore
-- reproduces the cold build's vertex data, index order and visibility
-- groups. The same map is also run unsandboxed (the ffi sink, desktop) and
-- with the JIT off (the device's interpreter), and the timings printed.
-- Run from the repo root:
--   AIO_ENGINE_SRC=/path/to/engine/src xvfb-run -a love tests/mesh_store
local n, lines = 0, {}
local function check(c, m) if not c then error("FAIL: " .. m, 2) end n = n + 1 end
local repo = love.filesystem.getSource():gsub("/tests/mesh_store/?$", "")
local engine = os.getenv("AIO_ENGINE_SRC")
if engine then package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path end

-- the mod.cache calls (src/mods/ImportAccess.lua makeCache) over love.filesystem
local function standInCache(root)
  local fs = love.filesystem
  local c = {}
  function c:write(rel, bytes)
    assert(type(bytes) == "string", "mod.cache:write expects a byte string")
    fs.createDirectory((root .. "/" .. rel):match("^(.*)/[^/]+$"))
    return fs.write(root .. "/" .. rel, bytes)
  end
  function c:read(rel) return fs.read(root .. "/" .. rel) end
  function c:info(rel) return fs.getInfo(root .. "/" .. rel) end
  function c:exists(rel) local i = fs.getInfo(root .. "/" .. rel); return i ~= nil and i.type == "file" end
  function c:delete(rel) return fs.remove(root .. "/" .. rel) end
  return c
end
-- the engine's own mod.cache when the engine is on the path
local function modCache(id)
  local ok, IA = pcall(require, "src.mods.ImportAccess")
  if ok then
    local okN, _, cache = pcall(IA.new, { id = id }, love.filesystem)
    if okN and cache then return cache, "engine mod.cache" end
  end
  return standInCache("mod_cache/" .. id), "stand-in mod.cache"
end
local function wipe(id)
  local dir = "mod_cache/" .. id .. "/voxel"
  for _, f in ipairs(love.filesystem.getDirectoryItems(dir)) do love.filesystem.remove(dir .. "/" .. f) end
end

local function loadStore(mod)
  local src = assert(io.open("gmarc/lib/MeshStore.lua")):read("*a")
  return assert(load(src, "@MeshStore.lua"))({ mod = mod })
end

-- ------------------------------------------------------------ the store
local function unit()
  wipe("MESHSTORE_TEST")
  local mod = { id = "MESHSTORE_TEST", _kimArenaDiag = function(k, v) lines[k] = v end,
    _kimArenaBuildId = function() return "t1" end }
  mod.cache = modCache("MESHSTORE_TEST")
  local S = loadStore(mod)
  check(S.enabled(), "enabled by default")
  check(S.whyOff() == nil, "nothing to explain when it works")
  check(S.backlog() == 0, "nothing queued: writes are synchronous")
  local name = S.tag() .. "MAP_body_1.kms"
  check(S.load(name) == nil and lines["disk cache"]:find("misses 1"), "a miss is reported: " .. tostring(lines["disk cache"]))
  local bytes = ("x"):rep(4096)
  check(S.save(name, bytes), "saved")
  check(S.exists(name), "the file is on storage at once")
  check(S.load(name) == bytes, "loads back what was saved")
  check(lines["disk cache"]:find("^on;") and lines["disk cache"]:find("saves 1") and lines["disk cache"]:find("hits 1"),
    lines["disk cache"])
  local index = love.filesystem.read("mod_cache/MESHSTORE_TEST/voxel/index.txt")
  check(index and index:find(name, 1, true), "the save is listed in the index")

  -- packing and the blob format
  local floats = {}
  for i = 1, 24 * 12000 do floats[i] = (i % 97) * 0.25 - 3 end
  local fb = S.packFloats(floats)
  check(#fb == #floats * 4, "packFloats: 4 bytes per float")
  check(select(1, love.data.unpack("=f", fb, 4 * 1000 + 1)) == floats[1001], "packFloats: values round-trip")
  local verts = { { 1, 2, 3, 0.5, 0.25, 0.75 }, { -1, 8, 16, 1, 0, 1 } }
  local vb = S.packVerts(verts)
  check(#vb == 48 and select(1, love.data.unpack("=f", vb, 4 * 7 + 1)) == 8, "packVerts: six floats per vertex")
  local ib = S.packIndices({ 1, 2, 3, 70000 })
  check(select(4, love.data.unpack("=I4I4I4I4", ib)) == 69999, "packIndices: zero-based uint32")
  local q = S.quadIndex(3000)
  check(#q == 3000 * 24, "quadIndex: six uint32 per quad")
  local a, b, c, d, e, f = love.data.unpack("=I4I4I4I4I4I4", q, 2999 * 24 + 1)
  check(a == 11996 and b == 11997 and c == 11998 and d == 11996 and e == 11998 and f == 11999,
    "quadIndex: the quad order (0,1,2, 0,2,3)")
  local w = S.writer()
  w:add("big", fb):add("small", vb):add("empty", "")
  local blob = w:finish({ version = 2, list = { 1, 2.5, "s" }, huge = math.huge })
  check(blob:sub(1, 4) == "KMS2" and #blob < #fb, "a compressed KMS2 blob")
  local meta, rd = S.open(blob)
  check(meta and meta.version == 2 and meta.list[2] == 2.5 and meta.huge == math.huge, "header round-trips")
  check(#rd:frames("big") == 2 and rd:string("big") == fb, "a section across two frames comes back whole")
  check(rd:string("small") == vb and rd:string("empty") == nil, "small and absent sections")
  check(S.open("KMS1junk") == nil, "an old-format blob is refused")

  -- old builds are swept through the index on the next start
  local old = love.filesystem.read("mod_cache/MESHSTORE_TEST/voxel/" .. name)
  check(old, "the t1 file is there before the sweep")
  -- mod.cache and id through __index (main.lua's subMod proxy); the host
  -- hooks sit on the proxy itself, as main.lua assigns them
  local proxy = setmetatable({}, { __index = { id = "MESHSTORE_TEST", cache = mod.cache } })
  proxy._kimArenaDiag = function(k, v) lines[k] = v end
  proxy._kimArenaBuildId = function() return "t2" end
  local S2 = loadStore(proxy)
  check(S2.whyOff() == nil, "a new build starts")
  check(not love.filesystem.getInfo("mod_cache/MESHSTORE_TEST/voxel/" .. name), "the old build's file is swept")
  local index2 = love.filesystem.read("mod_cache/MESHSTORE_TEST/voxel/index.txt")
  check(not index2:find(name, 1, true), "and dropped from the index")
  S2.report()
  check(lines["disk cache"]:find("files 0 %(%+1 old%)"), "DIAGNOSTICS counts the swept file: " .. lines["disk cache"])

  -- no mod.cache and no filesystem (the sandbox on an older engine): OFF, why
  lines = {}
  local realFs = love.filesystem
  local S3 = loadStore({ id = "MESHSTORE_TEST3", _kimArenaDiag = function(k, v) lines[k] = v end })
  love.filesystem = nil
  local okB, r = pcall(S3.load, "x.kms")
  local why = S3.whyOff()
  love.filesystem = realFs
  check(okB and r == nil, "a failed start does not throw: " .. tostring(r))
  check(not S3.enabled(), "the cache is off afterwards")
  check(why:find("could not start", 1, true), "whyOff says it could not start: " .. tostring(why))
  check(lines["disk cache"] and lines["disk cache"]:find("OFF %(no mod.cache"), "it says why: " .. tostring(lines["disk cache"]))
  local S4 = loadStore({ id = "MESHSTORE_TEST4", _kimArenaMeshStore = function() return false end })
  check(S4.whyOff() == "VOXEL DISK CACHE is OFF", "whyOff names the setting")
  wipe("MESHSTORE_TEST")
end

-- ------------------------------------------- end to end through ChunkMesher
local Sandbox
local function gmarc(modId, sandboxed)
  wipe(modId)
  local diag = {}
  local main = { id = modId }
  main.cache = modCache(modId)
  -- the voxel proxy: __index reaches the main mod (main.lua subMod)
  local mod = setmetatable({ path = repo .. "/gmarc" }, { __index = main })
  mod._kimArenaDiag = function(k, v) diag[k] = v end
  mod._kimArenaBuildId = function() return "e2e" end
  local env
  if sandboxed then
    Sandbox = Sandbox or require("src.mods.Sandbox")
    env = Sandbox.envFor({ modId = modId, permissions = {} })
  end
  local V = { mod = mod, path = mod.path }
  local modules = {}
  local function source(rel)
    local fh = io.open(repo .. "/gmarc/" .. rel); if not fh then return nil end
    local s = fh:read("*a"); fh:close(); return s
  end
  function V.require(name)
    if modules[name] ~= nil then return modules[name] end
    local src = assert(source("lib/" .. name .. ".lua"), name)
    local chunk = env and assert(Sandbox.compile(src, "@" .. name, env)) or assert(load(src, "@" .. name))
    local v = chunk(V); modules[name] = v; return v
  end
  function V.data(name)
    local src = assert(source("data/" .. name .. ".lua"), name)
    local chunk = env and assert(Sandbox.compile(src, "@" .. name, env)) or assert(load(src, "@" .. name))
    return chunk(V)
  end
  return V, diag, env
end

local function syntheticMap(id, w, h)
  local Map = require("src.world.Map")
  local blocks = {}
  for i = 1, 16 do
    blocks[i] = {}
    for t = 1, 16 do blocks[i][t] = ((i - 1) * 4 + (t - 1) % 4 + math.floor((t - 1) / 4) * 16) % 96 end
  end
  local tileset = { id = "TILESET_E2E", name = "e2e", blocks = blocks, walkable = { 0, 1, 2, 3 },
    tilesPerRow = 16, generation = 2, image = "e2e_atlas" }
  local def = { id = id, width = w, height = h, tileset = "TILESET_E2E", borderBlock = 0, blocks = {} }
  for i = 1, w * h do def.blocks[i] = (i * 7 + math.floor(i / w) * 3) % 16 end
  return Map.new(def, tileset)
end

local function meshData(MV, m)
  if not m then return nil end
  local out = { n = m:getVertexCount(), map = m:getVertexMap() or {}, v = {} }
  for i = 1, out.n do
    local a = { m:getVertex(i) }
    for k = 1, 6 do out.v[#out.v + 1] = a[k] end
  end
  local g = MV.groups(m)
  if g then
    out.groups = {}
    for i, x in ipairs(g) do out.groups[i] = x.first .. ":" .. x.count end
  end
  return out
end
local function same(a, b, what)
  check((a == nil) == (b == nil), what .. ": both or neither")
  if not a then return end
  check(a.n == b.n, ("%s: vertex count %d vs %d"):format(what, a.n, b.n))
  local diff = 0
  for i = 1, #a.v do if a.v[i] ~= b.v[i] then diff = diff + 1 end end
  check(diff == 0, what .. ": vertex data identical (" .. diff .. " values differ)")
  check(#a.map == #b.map, what .. ": index count")
  local idiff = 0
  for i = 1, #a.map do if a.map[i] ~= b.map[i] then idiff = idiff + 1 end end
  check(idiff == 0, what .. ": index order identical (" .. idiff .. " differ)")
  check((a.groups == nil) == (b.groups == nil), what .. ": visibility groups both or neither")
  if a.groups then check(table.concat(a.groups, ",") == table.concat(b.groups, ","), what .. ": same groups") end
end

local results = {}
local function scenario(label, sandboxed, jitOff)
  local modId = "MESHSTORE_E2E_" .. label:gsub("%W", "_")
  local V, diag, env = gmarc(modId, sandboxed)
  if sandboxed then
    check(not pcall(env.require, "ffi"), label .. ": the sandbox denies ffi")
    check(not pcall(function() return env.love.filesystem end), label .. ": and love.filesystem")
  end
  local CM = V.require("ChunkMesher")
  local S = V.require("MeshStore")
  local MV = V.require("MeshVisibility")
  local TI = V.require("TreeInstances")
  -- the synthetic tileset grows no trees, grass, flowers or figures of its
  -- own: hand the scene some, so every section of the blob is exercised
  local St = V.require("Structures")
  local realForMap = St.forMap
  St.forMap = function(m)
    local scene = realForMap(m)
    if not scene._e2e then
      scene._e2e = true
      local function quad(x, y, z, w, h, shade)
        return { { x, y, z }, { x + w, y, z }, { x + w, y + h, z }, { x, y + h, z },
          u = 0.125, v = 0.25, shade = shade or 0.9 }
      end
      local tree = { quad(-6, 0, 0, 12, 20), quad(-4, 4, -3, 8, 14, 0.7), quad(-5, 12, 2, 10, 6, 1) }
      tree[2].uv = { { 0.1, 0.2 }, { 0.2, 0.2 }, { 0.2, 0.1 }, { 0.1, 0.1 } }
      scene.assetStamps = scene.assetStamps or {}
      for k = 1, 5 do
        scene.assetStamps[#scene.assetStamps + 1] = { quads = tree, mx = 40 + k * 24, mz = 60 + k * 8, tree = true }
      end
      scene.grassQuads = {}
      for k = 1, 40 do scene.grassQuads[k] = quad(k * 4, 0, 30 + k, 4, 3, k % 3 * 0.1 + 0.7) end
      scene.flowerQuads = { quad(10, 0, 12, 4, 4), quad(30, 0, 50, 4, 4, 0.6) }
      scene.figures = { { quads = { quad(0, 0, 0, 12, 16), quad(2, 4, 1, 6, 6) }, wx = 96, wz = 80, y = 2 } }
    end
    return scene
  end
  check(S.enabled() and S.whyOff() == nil, label .. ": the disk cache is ON: " .. tostring(S.whyOff()))
  -- time the persist (writer() .. save()) and the restore (load() .. done)
  local t = {}
  local realWriter, realSave, realLoad = S.writer, S.save, S.load
  S.writer = function(...)
    t.persist0 = love.timer.getTime()
    local w = realWriter(...)
    local finish = w.finish
    function w:finish(meta)
      local out = finish(self, meta)
      t.sections = {}
      for _, s in ipairs(meta.sections) do t.sections[#t.sections + 1] = s.name end
      return out
    end
    return w
  end
  S.save = function(name, bytes)
    t.blob = #bytes; t.compress = love.timer.getTime() - t.persist0
    local w0 = love.timer.getTime()
    local ok = realSave(name, bytes)
    t.write = love.timer.getTime() - w0
    t.persist = love.timer.getTime() - t.persist0
    return ok
  end
  S.load = function(name)
    local r0 = love.timer.getTime()
    local b = realLoad(name)
    t.read = love.timer.getTime() - r0
    return b
  end
  local map = syntheticMap("E2E_ROUTE", 18, 9)
  local function settle()
    local t0 = love.timer.getTime()
    while CM.pending() > 0 do
      CM.pump(true)
      assert(love.timer.getTime() - t0 < 120, "build did not finish")
    end
    return love.timer.getTime() - t0
  end
  if jitOff and jit then jit.off(); jit.flush() end
  CM.request(map, true, nil, true)
  local cold = settle()
  check(CM.stats.builds == 1 and CM.stats.restores == 0, label .. ": a cold build")
  check(CM.stored(map, true, nil), label .. ": it is on storage right after the build")
  local mesh, water = CM.pair(map, true)
  check(mesh, label .. ": the cold build has a mesh")
  local figure = CM.figures(map) and CM.figures(map)[1]
  local before = { main = meshData(MV, mesh), water = meshData(MV, water),
    grass = meshData(MV, CM.grass(map)), flowers = meshData(MV, CM.flowers(map)),
    figure = figure and meshData(MV, figure.mesh), figureAt = figure and (figure.wx .. "," .. figure.wz .. "," .. figure.w),
    trees = TI.stats(mesh) }
  check(before.grass and before.flowers and before.figure, label .. (": grass, flowers and a figure were built %s %s %s"):format(tostring(before.grass), tostring(before.flowers), tostring(before.figure)))
  -- the next visit (or the next session) restores
  CM.invalidate(map.id)
  check(CM.pair(map, true) == nil, label .. ": dropped from memory")
  CM.request(map, true, nil, true)
  local warm = settle()
  if jitOff and jit then jit.on() end
  check(CM.stats.restores == 1, label .. ": the second build is a restore: " .. tostring(diag["voxel build"]))
  check(diag["disk cache"]:find("^on;") and diag["disk cache"]:find("hits 1") and diag["disk cache"]:find("saves 1"),
    label .. ": DIAGNOSTICS: " .. tostring(diag["disk cache"]))
  local m2, w2 = CM.pair(map, true)
  same(before.main, meshData(MV, m2), label .. " main")
  same(before.water, meshData(MV, w2), label .. " water")
  same(before.grass, meshData(MV, CM.grass(map)), label .. " grass")
  same(before.flowers, meshData(MV, CM.flowers(map)), label .. " flowers")
  local fig2 = CM.figures(map) and CM.figures(map)[1]
  same(before.figure, fig2 and meshData(MV, fig2.mesh), label .. " figure")
  check(fig2 and before.figureAt == fig2.wx .. "," .. fig2.wz .. "," .. fig2.w, label .. ": the figure's placement")
  if before.trees then
    local after = TI.stats(m2)
    check(after and after.instances == before.trees.instances and after.modelVertices == before.trees.modelVertices
      and before.trees.instances == 5, label .. ": the instanced trees come back")
  else
    results[#results + 1] = label .. ": no instancing on this GPU -- tree models not exercised"
  end
  -- a cuttable tree comes back from vertex bytes (LiveCutProps.restore)
  local LC = V.require("LiveCutProps")
  local flat = {}
  for k = 1, 8 do for _, x in ipairs({ k, k * 2, 3, 0.25, 0.5, 0.9 }) do flat[#flat + 1] = x end end
  LC.restore("E2E_CUT", { tileset = "TILESET_E2E", targets = {
    { x = 1, y = 1, bx = 0, by = 0, block = 3, stamps = { { mx = 8, mz = 8, bytes = S.packFloats(flat), count = 8 } } },
    { x = 2, y = 1, bx = 1, by = 0, block = 3, stamps = { { mx = 8, mz = 8, bytes = "", count = 0 } } } } })
  local cutMap = { id = "E2E_CUT", widthCells = 4, heightCells = 4, cellCollision = function() return 0x12 end }
  check(LC.visible(cutMap) == 1, label .. ": a restored cut tree has its mesh")
  LC.invalidate("E2E_CUT")
  results[#results + 1] = ("%s: %d vertices (%s groups, water %s); blob %.0f KB (raw %.0f KB); cold %.0f ms "
    .. "(persist %.0f ms: pack+lz4 %.0f, write %.1f); restore %.0f ms (read %.1f)"):format(
    label, before.main.n, before.main.groups and #before.main.groups or "no",
    before.water and before.water.n or 0, t.blob / 1024, before.main.n * 24 / 1024,
    cold * 1000, t.persist * 1000, t.compress * 1000, t.write * 1000, warm * 1000, t.read * 1000)
    .. "; sections " .. table.concat(t.sections, " ")
    .. "; longest slice " .. tostring(diag["voxel slow worst"] or "under 50 ms")
  wipe(modId)
end

function love.load()
  local ok, err = xpcall(function()
    unit()
    if not engine then
      print("mesh store: end-to-end SKIP (set AIO_ENGINE_SRC to the engine's src root)")
      return
    end
    -- a synthetic tileset atlas: solid tiles plus every fifth tile with a
    -- transparent notch, so the scene has props as well as terrain
    local Assets = require("src.render.Assets")
    local realData = Assets.imageData
    Assets.imageData = function(path)
      if path ~= "e2e_atlas" then return realData(path) end
      local d = love.image.newImageData(128, 48)
      d:mapPixel(function(x, y)
        local t = math.floor(y / 8) * 16 + math.floor(x / 8)
        if t % 5 == 3 and ((x % 8) < 2 or (y % 8) < 2) then return 0, 0, 0, 0 end
        return (t * 37 % 255) / 255, (t * 91 % 255) / 255, (x * 3 % 255) / 255, 1
      end)
      return d
    end
    scenario("sandbox", true, false)
    scenario("sandbox jit off", true, true)
    scenario("desktop ffi", false, false)
  end, debug.traceback)
  for _, r in ipairs(results) do print("  " .. r) end
  print(ok and ("mesh store: %d checks PASS"):format(n) or tostring(err))
  love.event.quit(ok and 0 or 1)
end
