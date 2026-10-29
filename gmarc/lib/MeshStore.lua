-- gen2-aio: persistent voxel map cache (VOXEL DISK CACHE).
--
-- Every finished map build (terrain + water + instanced trees + grass,
-- flowers, figures, cuttable trees and authored support heights) is packed
-- into one blob and written, LZ4-compressed, to
-- save/mod_cache/<mod>/voxel/<key>.kms. The next time that map is needed --
-- this session or any later one -- ChunkMesher reads it back and restores
-- the meshes from it in budgeted slices instead of rebuilding them.
-- Rebuilding is the expensive part (Structures + geometry, seconds for a
-- route on a phone); a restore is a file read plus a GPU upload.
--
-- The KEY is a hash of everything the geometry is made from: the map id,
-- the variant (body / full + neighbour masks), the map's live block layout,
-- its tileset, Crystal's VOID FILL (the border ring) and the bundle build.
-- Changing any of them simply asks for a different file, so a stale blob
-- can never be drawn; files for old builds are swept at start-up.
--
-- gen2-aio 0.9.84: SANDBOX-SAFE BACKEND. On the device mods run in the
-- engine's sandbox (src/mods/Sandbox.lua): require("ffi") is denied,
-- love.filesystem is blocked and love.thread is permission-gated, so the
-- ffi + worker-thread store this used to be returned a stub there and the
-- cache was simply OFF ("this build of LOVE has no ffi library" -- LOVE has
-- one, the sandbox refuses it). It now uses only what the sandbox hands a
-- mod, on every platform:
--
--   * mod.cache (src/mods/ImportAccess.lua) for the files -- byte strings
--     in, byte strings out, under mod_cache/<mod-id>/;
--   * love.data.pack for the vertex bytes (a few thousand floats per call,
--     with BuildBudget ticks between calls so the build coroutine yields),
--     love.data.compress / decompress (lz4) per ~1 MB frame;
--   * love.data.newByteData(string) + Mesh:setVertices / setVertexMap on
--     the way back, so a restore runs no per-vertex Lua at all.
--
-- Reads and writes are synchronous (mod.cache has no worker), one file per
-- map variant: a read when a build starts, a write when it finishes -- both
-- moments that already cost a hitch-free slice budget's worth of setup.
--
-- mod.cache cannot list a directory, so old builds are swept through an
-- index file (voxel/index.txt, one file name per line) that every save
-- appends to before its blob lands; at start-up every listed name from
-- another build is deleted and the index is rewritten without them.
local V = ...
local MeshStore = {}
local okBit, bit = pcall(require, "bit")
if not okBit then bit = rawget(_G or {}, "bit") end
local loveData = love and love.data
if not (bit and loveData and loveData.pack and loveData.compress and loveData.newByteData) then
  local why = bit and "this build of LOVE has no love.data packing" or "this build of LOVE has no bit library"
  return { enabled = function() return false end, whyOff = function() return why end }
end

local DIR = "voxel"
local INDEX = DIR .. "/index.txt"
local MAGIC = "KMS2"
-- raw bytes per compressed frame: a whole number of vertices (24 bytes),
-- indices (4) and instance rows, ~1 MB so one decompress or upload is short
local FRAME = 24 * 43690
local unpackList = table.unpack or unpack

local disabled = false
local started = false
local store = nil         -- the mod.cache handle (or a love.filesystem stand-in)
local indexNames = nil    -- this build's names in the index, name -> true
MeshStore.stats = { hits = 0, misses = 0, saves = 0, failures = 0 }

local function hostFn(name)
  local mod = V and V.mod
  local fn = mod and rawget(mod, name)
  return type(fn) == "function" and fn or nil
end

-- BuildBudget when loaded inside gmarc (yields the build coroutine); a
-- no-op for a bare load (the tests' loadStore)
local tick, check = function() end, function() end
do
  local ok, B = pcall(function() return V and V.require and V.require("BuildBudget") end)
  if ok and type(B) == "table" then tick, check = B.tick, B.check end
end

function MeshStore.enabled()
  if disabled then return false end
  local fn = hostFn("_kimArenaMeshStore")
  if fn then
    local ok, on = pcall(fn)
    if ok and on == false then return false end
  end
  return true
end

local function buildId()
  local fn = hostFn("_kimArenaBuildId")
  local ok, id = false, nil
  if fn then ok, id = pcall(fn) end
  return ok and tostring(id) or "dev"
end

-- gen2-aio 0.9.58: what DIAGNOSTICS says about the cache. Published on
-- every lookup and save (a run of nothing but misses used to say nothing),
-- with the files on storage for this build and the old builds' files swept.
local lastEvent, lastError, fileCount, oldCount, offReason = "-", nil, nil, nil, nil
local function report()
  local mod = V and V.mod
  local d = mod and rawget(mod, "_kimArenaDiag")
  if not d then return end
  local st = MeshStore.stats
  local state = disabled and ("OFF" .. (offReason and (" (" .. offReason .. ")") or ""))
    or (MeshStore.enabled() and "on" or "OFF (setting)")
  pcall(d, "disk cache", ("%s; hits %d, misses %d, saves %d, failures %d; files %s (+%s old); last %s%s"):format(
    state, st.hits, st.misses, st.saves, st.failures, tostring(fileCount or "?"),
    tostring(oldCount or "?"), lastEvent, lastError and ("; error " .. lastError) or ""))
end
MeshStore.report = report
-- nothing is in flight any more; kept for callers that poll
MeshStore.poll = report

-- ---------------------------------------------------------------- storage
-- The engine's mod.cache (reached through the voxel proxy's __index, see
-- main.lua subMod). Outside the sandbox on an engine without mod.cache, a
-- stand-in over love.filesystem with the same calls and the same root.
local function rawFs()
  local ok, fs = pcall(function() return love.filesystem end)
  return ok and type(fs) == "table" and fs or nil
end
local function modId()
  local ok, id = pcall(function() return V.mod.id end)
  return tostring(ok and id or "GEN2_VOXEL")
end
local function fsCache(fs, root)
  local c = {}
  local function path(rel) return root .. "/" .. rel end
  function c:write(rel, bytes)
    local dir = path(rel):match("^(.*)/[^/]*$")
    if dir then fs.createDirectory(dir) end
    return fs.write(path(rel), bytes)
  end
  function c:read(rel) return fs.read(path(rel)) end
  function c:info(rel) return fs.getInfo(path(rel)) end
  function c:exists(rel) local i = fs.getInfo(path(rel)); return i ~= nil and i.type == "file" end
  function c:delete(rel) return fs.remove(path(rel)) end
  return c
end
local function findCache()
  local ok, c = pcall(function() return V.mod.cache end)
  if ok and type(c) == "table" and type(c.write) == "function" and type(c.read) == "function" then
    return c
  end
  local fs = rawFs()
  if fs and fs.write and fs.read and fs.getInfo then return fsCache(fs, "mod_cache/" .. modId()) end
  return nil
end
-- tests swap the storage (a mod.cache stand-in) without a mod object
function MeshStore.setCache(c) store, started, indexNames, disabled = c, false, nil, false end

local function readIndex()
  local okR, body = pcall(store.read, store, INDEX)
  local names = {}
  if okR and type(body) == "string" then
    for line in body:gmatch("[^\n]+") do names[#names + 1] = line end
  end
  return names
end

-- First use: find the storage, then sweep the old builds' files.
local function start()
  if started then return not disabled end
  started = true
  store = store or findCache()
  if not store then
    disabled = true; offReason = "no mod.cache in this engine"; report(); return false
  end
  local ok, err = pcall(function()
    local tag = MeshStore.tag()
    local keep, kept, gone = {}, {}, 0
    for _, name in ipairs(readIndex()) do
      if name:sub(1, #tag) == tag then
        if not kept[name] then kept[name] = true; keep[#keep + 1] = name end
      else
        pcall(store.delete, store, DIR .. "/" .. name); gone = gone + 1
      end
    end
    -- files from before the index (the 0.9.83 desktop worker): only a
    -- real filesystem can list them; the sandbox never had any
    local fs = rawFs()
    if fs and fs.getDirectoryItems then
      for _, name in ipairs(fs.getDirectoryItems("mod_cache/" .. modId() .. "/" .. DIR) or {}) do
        if name:match("%.kms$") and name:sub(1, #tag) ~= tag then
          pcall(store.delete, store, DIR .. "/" .. name); gone = gone + 1
        end
      end
    end
    if gone > 0 then store:write(INDEX, #keep > 0 and (table.concat(keep, "\n") .. "\n") or "") end
    indexNames = kept
    fileCount, oldCount = #keep, gone
  end)
  if not ok then lastError = tostring(err):sub(1, 60); indexNames = indexNames or {} end
  return true
end

-- gen2-aio 0.9.82: nil when the cache works, else why not, in words for the
-- BUILD 3D CACHE row
function MeshStore.whyOff()
  local fn = hostFn("_kimArenaMeshStore")
  if fn then
    local ok, on = pcall(fn)
    if ok and on == false then return "VOXEL DISK CACHE is OFF" end
  end
  if not disabled then start() end
  if disabled then return "the disk cache could not start (" .. tostring(offReason or "?") .. ")" end
  return nil
end

-- ------------------------------------------------------------------- key
local function fnv(h, s)
  for i = 1, #s do
    h = bit.bxor(h, s:byte(i))
    h = bit.tobit(bit.lshift(h, 24) + bit.tobit(h * 403))
  end
  return h
end

function MeshStore.tag()
  local id = buildId():gsub("[^%w]", "_")
  return id .. "-"
end

function MeshStore.key(map, slot, masks)
  local parts = { tostring(map.id), slot }
  local def = map.def or {}
  parts[#parts + 1] = tostring(def.width) .. "x" .. tostring(def.height)
  parts[#parts + 1] = tostring(def.borderBlock)
  parts[#parts + 1] = tostring(map.tileset and (map.tileset.id or map.tileset.name) or "?")
  local TR = (select(2, pcall(require, "src.render.TileRenderer")))
  parts[#parts + 1] = tostring(type(TR) == "table" and TR.voidFill or "?")
  for _, m in ipairs(masks or {}) do
    parts[#parts + 1] = table.concat({ m[1], m[2], m[3], m[4] }, ",")
  end
  local s = table.concat(parts, "|")
  local h1, h2 = fnv(-2128831035, s), fnv(16777619, s)
  local blocks = def.blocks or {}
  local buf = {}
  for i = 1, #blocks do
    buf[#buf + 1] = string.char((tonumber(blocks[i]) or 0) % 256)
    if #buf == 512 then
      local chunk = table.concat(buf); buf = {}
      h1, h2 = fnv(h1, chunk), fnv(h2, chunk)
    end
  end
  if #buf > 0 then local chunk = table.concat(buf); h1, h2 = fnv(h1, chunk), fnv(h2, chunk) end
  local safeId = tostring(map.id):gsub("[^%w_]", "_")
  return ("%s%s_%s_%s%s.kms"):format(MeshStore.tag(), safeId, slot,
    bit.tohex(h1), bit.tohex(h2))
end

local function short(name) return name:match("^[^-]*%-(.-)_%x+%x*%.kms$") or name end

-- ------------------------------------------------------- files (sync)
function MeshStore.exists(name)
  if not MeshStore.enabled() or not start() then return false end
  local ok, yes = pcall(function()
    if store.exists then return store:exists(DIR .. "/" .. name) end
    return store:info(DIR .. "/" .. name) ~= nil
  end)
  return ok and yes == true
end
-- writes are synchronous: nothing ever waits behind them (BUILD 3D CACHE
-- asks before queueing more work)
function MeshStore.backlog() return 0 end

-- The file's bytes, nil when there is none, false when it could not be read.
function MeshStore.load(name)
  if not MeshStore.enabled() or not start() then return nil end
  if not MeshStore.exists(name) then
    MeshStore.stats.misses = MeshStore.stats.misses + 1
    lastEvent = "miss " .. short(name)
    report()
    return nil
  end
  local ok, bytes = pcall(store.read, store, DIR .. "/" .. name)
  if not ok or type(bytes) ~= "string" then
    MeshStore.stats.failures = MeshStore.stats.failures + 1
    lastError = tostring(ok and "read failed" or bytes):sub(1, 60)
    report()
    return false
  end
  MeshStore.stats.hits = MeshStore.stats.hits + 1
  lastEvent = "load " .. short(name)
  report()
  return bytes
end

-- A blob that turned out unusable (old format, damaged): count it, drop it.
function MeshStore.reject(name, why)
  MeshStore.stats.hits = math.max(0, MeshStore.stats.hits - 1)
  MeshStore.stats.failures = MeshStore.stats.failures + 1
  lastError = tostring(why or "unusable"):sub(1, 60)
  if store then pcall(store.delete, store, DIR .. "/" .. name) end
  report()
end

-- One synchronous write of a finished blob (a byte string).
function MeshStore.save(name, bytes)
  if type(bytes) ~= "string" or not MeshStore.enabled() or not start() then return false end
  local ok, err = pcall(function()
    -- listed BEFORE the blob lands: a crash in between leaves a name to
    -- sweep, never a file nothing knows about
    if indexNames and not indexNames[name] then
      local names = readIndex()
      names[#names + 1] = name
      local okI, errI = store:write(INDEX, table.concat(names, "\n") .. "\n")
      if not okI then error(errI or "index write failed", 0) end
      indexNames[name] = true
      fileCount = (fileCount or 0) + 1
    end
    local okW, errW = store:write(DIR .. "/" .. name, bytes)
    if not okW then error(errW or "write failed", 0) end
  end)
  lastEvent = "save " .. short(name)
  if ok then MeshStore.stats.saves = MeshStore.stats.saves + 1
  else
    MeshStore.stats.failures = MeshStore.stats.failures + 1
    lastError = tostring(err):sub(1, 60)
  end
  report()
  return ok
end

-- ------------------------------------------------------ byte packing
-- Lua numbers -> native float32 / uint32 bytes through love.data.pack, a
-- few thousand values per call (a C call's argument count stays far from
-- LuaJIT's unpack limit), ticking the build budget between calls.
local BATCH = 3072
local formats = {}
local function fmt(kind, k)
  local key = kind .. k
  local f = formats[key]
  if not f then f = "=" .. kind:rep(k); formats[key] = f end
  return f
end
local function packRun(kind, list, count, out)
  local i = 1
  while i <= count do
    local j = math.min(count, i + BATCH - 1)
    out[#out + 1] = loveData.pack("string", fmt(kind, j - i + 1), unpackList(list, i, j))
    i = j + 1
    tick()
  end
end

-- flat Lua array of floats -> bytes
function MeshStore.packFloats(list, count)
  local out = {}
  packRun("f", list, count or #list, out)
  return table.concat(out)
end

-- vertex tables { x, y, z, u, v, shade } (the table sink, tree models) -> bytes
function MeshStore.packVerts(verts, nv)
  nv = nv or #verts
  local out, flat, k = {}, {}, 0
  for j = 1, nv do
    local v = verts[j]
    flat[k + 1], flat[k + 2], flat[k + 3] = v[1], v[2], v[3]
    flat[k + 4], flat[k + 5], flat[k + 6] = v[4], v[5], v[6]
    k = k + 6
    if k >= BATCH then packRun("f", flat, k, out); k = 0 end
  end
  if k > 0 then packRun("f", flat, k, out) end
  return table.concat(out)
end

-- 1-based Lua index list -> zero-based uint32 bytes (setVertexMap's Data form)
function MeshStore.packIndices(list, count)
  count = count or #list
  local out, flat, k = {}, {}, 0
  for j = 1, count do
    k = k + 1
    flat[k] = list[j] - 1
    if k >= BATCH then packRun("I4", flat, k, out); k = 0 end
  end
  if k > 0 then packRun("I4", flat, k, out) end
  return table.concat(out)
end

-- The plain quad index list (q*4 + 0,1,2, 0,2,3) as uint32 bytes, built
-- once per session and grown on demand: grass, flowers, figures, tree
-- models and cut props all restore with it instead of a per-quad loop.
local quadIdx, quadIdxN = "", 0
function MeshStore.quadIndex(quads)
  if quads > quadIdxN then
    local want = math.max(quads, 1024)
    want = math.ceil(want / 1024) * 1024
    local out, flat, k = { quadIdx }, {}, 0
    for q = quadIdxN, want - 1 do
      local b = q * 4
      flat[k + 1], flat[k + 2], flat[k + 3] = b, b + 1, b + 2
      flat[k + 4], flat[k + 5], flat[k + 6] = b, b + 2, b + 3
      k = k + 6
      if k >= BATCH then packRun("I4", flat, k, out); k = 0 end
    end
    if k > 0 then packRun("I4", flat, k, out) end
    quadIdx, quadIdxN = table.concat(out), want
  end
  if quads == quadIdxN then return quadIdx end
  return quadIdx:sub(1, quads * 24)
end

-- A static triangle mesh from vertex bytes: `src` is a string or a list of
-- strings (frames, each a whole number of vertices), `n` the vertex count,
-- `idx` the uint32 index bytes (nil = plain quads). Uploads frame by frame
-- with budget checks between; no per-vertex Lua.
function MeshStore.mesh(format, src, n, idx)
  if not n or n <= 0 or not src then return nil end
  local stride = 0
  for _, a in ipairs(format) do stride = stride + 4 * (a[3] or 1) end
  local m
  local ok = pcall(function()
    m = love.graphics.newMesh(format, n, "triangles", "static")
    local at = 1
    for _, chunk in ipairs(type(src) == "table" and src or { src }) do
      if #chunk > 0 then
        local d = loveData.newByteData(chunk)
        m:setVertices(d, at); d:release()
        at = at + #chunk / stride
        check()
      end
    end
    local d = loveData.newByteData(idx or MeshStore.quadIndex(n / 4))
    m:setVertexMap(d, "uint32"); d:release()
  end)
  if not ok then
    if m then pcall(m.release, m) end
    return nil
  end
  return m
end

-- ---------------------------------------------------------- blob format
-- MAGIC, then frames: uint32 (little-endian) compressed length + LZ4 bytes.
-- Frame 1 is the header (a Lua table literal); every section follows in
-- the header's order as ceil(bytes / FRAME) frames.
local function serialize(v, out)
  local t = type(v)
  if t == "number" then
    if v ~= v then out[#out + 1] = "0/0"
    elseif v == math.huge then out[#out + 1] = "1/0"
    elseif v == -math.huge then out[#out + 1] = "-1/0"
    else out[#out + 1] = string.format("%.17g", v) end
  elseif t == "boolean" or t == "nil" then out[#out + 1] = tostring(v)
  elseif t == "string" then out[#out + 1] = string.format("%q", v)
  elseif t == "table" then
    out[#out + 1] = "{"
    for k, x in pairs(v) do
      out[#out + 1] = "["; serialize(k, out); out[#out + 1] = "]="
      serialize(x, out); out[#out + 1] = ","
      tick()
    end
    out[#out + 1] = "}"
  else out[#out + 1] = "nil" end
end

local function frame(raw)
  local z = loveData.compress("string", "lz4", raw)
  return loveData.pack("string", "<I4", #z) .. z
end

-- writer: w:add(name, bytes) for each section, then w:finish(meta) -> the
-- file's bytes. Compression runs a frame at a time between budget checks.
function MeshStore.writer()
  local w, sections = {}, {}
  function w:add(name, bytes)
    if type(bytes) == "string" and #bytes > 0 then
      sections[#sections + 1] = { name = name, data = bytes }
    end
    return self
  end
  function w:finish(meta)
    local frames, list = {}, {}
    for _, s in ipairs(sections) do
      local data, count = s.data, 0
      s.data = nil
      for at = 1, #data, FRAME do
        frames[#frames + 1] = frame(data:sub(at, at + FRAME - 1))
        count = count + 1
        check()
      end
      list[#list + 1] = { name = s.name, bytes = #data, frames = count }
    end
    meta.sections = list
    local out = {}
    serialize(meta, out)
    local head = frame(table.concat(out))
    return MAGIC .. head .. table.concat(frames)
  end
  return w
end

-- -> meta, reader | nil, why. reader:frames(name) -> list of decompressed
-- frame strings ({} when absent); reader:string(name) -> one string or nil.
function MeshStore.open(bytes)
  if type(bytes) ~= "string" or bytes:sub(1, 4) ~= MAGIC then return nil, "not a " .. MAGIC .. " blob" end
  local pos = 5
  local function nextFrame()
    if pos + 3 > #bytes then return nil end
    local len = loveData.unpack("<I4", bytes, pos)
    local z = bytes:sub(pos + 4, pos + 3 + len)
    pos = pos + 4 + len
    return z
  end
  local hz = nextFrame()
  if not hz then return nil, "no header" end
  local okH, header = pcall(loveData.decompress, "string", "lz4", hz)
  if not okH then return nil, "header: " .. tostring(header) end
  local fn = (loadstring or load)("return " .. header)
  if not fn then return nil, "header does not parse" end
  if setfenv then setfenv(fn, {}) end
  local ok, meta = pcall(fn)
  if not ok or type(meta) ~= "table" or type(meta.sections) ~= "table" then return nil, "bad header" end
  -- each section's compressed frames, in order
  local packed = {}
  for _, s in ipairs(meta.sections) do
    local list = {}
    for i = 1, s.frames or 0 do
      local z = nextFrame()
      if not z then return nil, "truncated" end
      list[i] = z
    end
    packed[s.name] = list
  end
  local reader = {}
  function reader:frames(name)
    local out = {}
    for i, z in ipairs(packed[name] or {}) do
      out[i] = loveData.decompress("string", "lz4", z)
      check()
    end
    return out
  end
  function reader:string(name)
    if not packed[name] then return nil end
    return table.concat(self:frames(name))
  end
  return meta, reader
end

return MeshStore
