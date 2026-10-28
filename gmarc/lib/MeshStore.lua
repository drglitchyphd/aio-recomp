-- gen2-aio: persistent voxel map cache (VOXEL DISK CACHE).
--
-- Every finished map build (terrain + water + instanced trees + grass,
-- flowers, figures, cuttable trees and authored support heights) is packed
-- into one blob and written, LZ4-compressed, to
-- save/mod_cache/<mod>/voxel/<key>.kms by a background thread. The next time
-- that map is needed -- this session or any later one -- the thread reads and
-- decompresses it, and ChunkMesher restores the meshes from it in budgeted
-- slices instead of rebuilding them. Rebuilding is the expensive part
-- (Structures + geometry, seconds for a route on a phone); a restore is a
-- file read plus a GPU upload.
--
-- The KEY is a hash of everything the geometry is made from: the map id,
-- the variant (body / full + neighbour masks), the map's live block layout,
-- its tileset, Crystal's VOID FILL (the border ring) and the bundle build.
-- Changing any of them simply asks for a different file, so a stale blob
-- can never be drawn; files for old builds are swept at start-up.
local V = ...
local MeshStore = {}
local okFfi, ffi = pcall(require, "ffi")
local okBit, bit = pcall(require, "bit")
if not (okFfi and okBit) then return { enabled = function() return false end } end

local DIR = "voxel"
local MAGIC = "KMS1"

local thread, toWorker, fromWorker
local root = nil          -- save-dir path of this mod's cache
local pending = {}        -- request id -> { done, blob }
local nextId = 0
local disabled = false
MeshStore.stats = { hits = 0, misses = 0, saves = 0, failures = 0 }

local function hostFn(name)
  local mod = V and V.mod
  local fn = mod and rawget(mod, name)
  return type(fn) == "function" and fn or nil
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

-- ---------------------------------------------------------------- worker
local WORKER = [[
require("love.filesystem"); require("love.data")
local inbox, outbox = ...
while true do
  local job = inbox:demand()
  if job.op == "quit" then return end
  if job.op == "save" then
    local ok, err = pcall(function()
      local packed = love.data.compress("data", "lz4", job.data)
      love.filesystem.createDirectory(job.dir)
      local tmp = job.path .. ".tmp"
      assert(love.filesystem.write(tmp, packed))
      love.filesystem.remove(job.path)
      local data = love.filesystem.read("data", tmp)
      assert(love.filesystem.write(job.path, data))
      love.filesystem.remove(tmp)
    end)
    job.data:release()
    outbox:push({ op = "saved", id = job.id, ok = ok, err = (not ok) and tostring(err) or nil })
  elseif job.op == "load" then
    local ok, res = pcall(function()
      local raw = love.filesystem.read("data", job.path)
      if not raw then return nil end
      return love.data.decompress("data", "lz4", raw)
    end)
    outbox:push({ op = "loaded", id = job.id, ok = ok and res ~= nil, data = ok and res or nil,
      err = (not ok) and tostring(res) or nil })
  elseif job.op == "sweep" then
    local keep = job.keep
    for _, name in ipairs(love.filesystem.getDirectoryItems(job.dir) or {}) do
      if name:sub(1, #keep) ~= keep then love.filesystem.remove(job.dir .. "/" .. name) end
    end
  end
end
]]

local function ensureThread()
  if thread or disabled then return thread ~= nil end
  local ok = pcall(function()
    local mod = V and V.mod
    root = "mod_cache/" .. tostring(mod and mod.id or "GEN2_VOXEL")
    toWorker = love.thread.newChannel()
    fromWorker = love.thread.newChannel()
    thread = love.thread.newThread(WORKER)
    thread:start(toWorker, fromWorker)
  end)
  if not ok then disabled = true; thread = nil; offReason = "no worker thread"; report(); return false end
  -- count what survived from earlier plays: this build's files are the
  -- ones a revisit can hit; old builds' files are swept below
  pcall(function()
    local tag = MeshStore.tag()
    fileCount, oldCount = 0, 0
    for _, name in ipairs(love.filesystem.getDirectoryItems(root .. "/" .. DIR) or {}) do
      if name:sub(1, #tag) == tag then fileCount = fileCount + 1 else oldCount = oldCount + 1 end
    end
  end)
  -- old builds' files go: keep only names that start with this build's tag
  toWorker:push({ op = "sweep", dir = root .. "/" .. DIR, keep = MeshStore.tag() })
  return true
end

-- gen2-aio 0.9.58: what DIAGNOSTICS says about the cache. Published on
-- every lookup and save (a run of nothing but misses used to say nothing),
-- with the files on storage for this build and for older builds.
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

local function poll()
  if not fromWorker then report(); return end
  while true do
    local msg = fromWorker:pop()
    if not msg then break end
    if msg.op == "loaded" then
      local p = pending[msg.id]
      if p then p.done = true; p.blob = msg.ok and msg.data or false end
    elseif msg.op == "saved" then
      if msg.ok then
        MeshStore.stats.saves = MeshStore.stats.saves + 1
        fileCount = (fileCount or 0) + 1
      else
        MeshStore.stats.failures = MeshStore.stats.failures + 1
        lastError = tostring(msg.err):sub(1, 60)
      end
    end
    if thread and thread:getError() then disabled = true end
  end
  report()
end
MeshStore.poll = poll

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
  parts[#parts + 1] = tostring(TR and TR.voidFill or "?")
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

local function pathOf(name) return root .. "/" .. DIR .. "/" .. name end

-- ---------------------------------------------------------------- loading
-- Ask for a blob. Returns a ticket, or nil when there is no file.
function MeshStore.begin(name)
  if not MeshStore.enabled() or not ensureThread() then return nil end
  local info = love.filesystem.getInfo(pathOf(name))
  local short = name:match("^[^-]*%-(.-)_%x+%x*%.kms$") or name
  if not info then
    MeshStore.stats.misses = MeshStore.stats.misses + 1
    lastEvent = "miss " .. short
    poll()
    return nil
  end
  lastEvent = "load " .. short
  nextId = nextId + 1
  local ticket = { id = nextId, started = love.timer.getTime() }
  pending[nextId] = ticket
  toWorker:push({ op = "load", id = nextId, path = pathOf(name) })
  return ticket
end

-- nil while waiting, false on failure, ByteData when it arrived
local function threadDead()
  if not thread then return true end
  local okE, err = pcall(thread.getError, thread)
  if okE and err then
    print("[warn] voxel disk cache thread stopped: " .. tostring(err))
    disabled = true
    return true
  end
  return false
end
MeshStore.LOAD_TIMEOUT = 3

function MeshStore.result(ticket)
  poll()
  if not ticket.done then
    -- never wait on a dead worker or forever: build normally instead
    if threadDead() or love.timer.getTime() - (ticket.started or 0) > MeshStore.LOAD_TIMEOUT then
      pending[ticket.id] = nil
      MeshStore.stats.failures = MeshStore.stats.failures + 1
      return false
    end
    return nil
  end
  pending[ticket.id] = nil
  if ticket.blob then MeshStore.stats.hits = MeshStore.stats.hits + 1
  else MeshStore.stats.misses = MeshStore.stats.misses + 1 end
  return ticket.blob
end

function MeshStore.save(name, data)
  if not MeshStore.enabled() or not ensureThread() or threadDead() then
    pcall(data.release, data); return false
  end
  toWorker:push({ op = "save", id = 0, path = pathOf(name), dir = root .. "/" .. DIR, data = data })
  lastEvent = "save " .. (name:match("^[^-]*%-(.-)_%x+%x*%.kms$") or name)
  poll()
  return true
end

-- ---------------------------------------------------------- blob format
-- MAGIC, uint32 header length, header (a Lua table literal), then raw
-- sections; the header names each section's offset and byte length.
local function serialize(v, out)
  local t = type(v)
  if t == "number" then out[#out + 1] = string.format("%.17g", v)
  elseif t == "boolean" or t == "nil" then out[#out + 1] = tostring(v)
  elseif t == "string" then out[#out + 1] = string.format("%q", v)
  elseif t == "table" then
    out[#out + 1] = "{"
    for k, x in pairs(v) do
      out[#out + 1] = "["; serialize(k, out); out[#out + 1] = "]="
      serialize(x, out); out[#out + 1] = ","
    end
    out[#out + 1] = "}"
  else out[#out + 1] = "nil" end
end

-- sections: list of { name, ptr, bytes }
function MeshStore.pack(meta, sections)
  local offset = 0
  meta.sections = {}
  for _, s in ipairs(sections) do
    meta.sections[s.name] = { offset = offset, bytes = s.bytes }
    offset = offset + s.bytes
  end
  local out = {}
  serialize(meta, out)
  local header = table.concat(out)
  local total = 8 + #header + offset
  local data = love.data.newByteData(total)
  local p = ffi.cast("uint8_t*", data:getFFIPointer())
  ffi.copy(p, MAGIC, 4)
  ffi.cast("uint32_t*", p + 4)[0] = #header
  ffi.copy(p + 8, header, #header)
  local base = 8 + #header
  for _, s in ipairs(sections) do
    if s.bytes > 0 then ffi.copy(p + base + meta.sections[s.name].offset, s.ptr, s.bytes) end
  end
  return data
end

-- -> meta, function(name) -> ptr, bytes
function MeshStore.unpack(data)
  local p = ffi.cast("uint8_t*", data:getFFIPointer())
  if ffi.string(p, 4) ~= MAGIC then return nil end
  local hl = ffi.cast("uint32_t*", p + 4)[0]
  local header = ffi.string(p + 8, hl)
  local fn = (loadstring or load)("return " .. header)
  if not fn then return nil end
  if setfenv then setfenv(fn, {}) end
  local ok, meta = pcall(fn)
  if not ok or type(meta) ~= "table" then return nil end
  local base = 8 + hl
  return meta, function(name)
    local s = meta.sections and meta.sections[name]
    if not s then return nil, 0 end
    return p + base + s.offset, s.bytes
  end
end

return MeshStore
