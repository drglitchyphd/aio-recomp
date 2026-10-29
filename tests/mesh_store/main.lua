-- 0.9.80: VOXEL DISK CACHE (gmarc/lib/MeshStore.lua) with LOVE's real worker
-- thread and filesystem: save, exists, load back, the DIAGNOSTICS line, and
-- a worker that cannot start reports why instead of throwing.
-- Run from the repo root: love tests/mesh_store
local n, lines = 0, {}
local function check(c, m) if not c then error("FAIL: " .. m, 2) end n = n + 1 end
local function loadStore(mod)
  local src = assert(io.open("gmarc/lib/MeshStore.lua")):read("*a")
  return assert(load(src, "@MeshStore.lua"))({ mod = mod })
end
function love.load()
  local ok, err = pcall(function()
    local mod = { id = "MESHSTORE_TEST", _kimArenaDiag = function(k, v) lines[k] = v end,
      _kimArenaBuildId = function() return "t1" end }
    local S = loadStore(mod)
    check(S.enabled(), "enabled by default")
    local name = S.tag() .. "MAP_body_1.kms"
    check(S.begin(name) == nil and lines["disk cache"], "a miss is reported: " .. tostring(lines["disk cache"]))
    local data = love.data.newByteData(("x"):rep(4096))
    check(S.save(name, data), "save queued")
    local t0 = love.timer.getTime()
    while not S.exists(name) and love.timer.getTime() - t0 < 5 do love.timer.sleep(0.01); S.poll() end
    check(S.exists(name), "the file lands on storage")
    while S.backlog() > 0 and love.timer.getTime() - t0 < 5 do love.timer.sleep(0.01) end
    local ticket = S.begin(name)
    check(ticket, "a hit starts a load")
    local blob
    repeat blob = S.result(ticket); love.timer.sleep(0.01) until blob ~= nil
    check(blob and blob:getSize() == 4096, "loads back what was saved")
    check(lines["disk cache"]:find("^on;") and lines["disk cache"]:find("saves 1"), lines["disk cache"])
    -- a worker that cannot start: OFF with the reason, no error
    local realNew = love.thread.newThread
    love.thread.newThread = function() error("no threads here") end
    lines = {}
    local mod2 = { id = "MESHSTORE_TEST2", _kimArenaDiag = function(k, v) lines[k] = v end }
    local S2 = loadStore(mod2)
    local okB, r = pcall(S2.begin, "x.kms")
    love.thread.newThread = realNew
    check(okB and r == nil, "a failed start does not throw: " .. tostring(r))
    check(not S2.enabled(), "the cache is off afterwards")
    check(lines["disk cache"] and lines["disk cache"]:find("OFF %(no worker thread: .*no threads here"),
      "it says why: " .. tostring(lines["disk cache"]))
    love.filesystem.remove("mod_cache/MESHSTORE_TEST/voxel/" .. name)
  end)
  print(ok and ("mesh store: %d checks PASS"):format(n) or tostring(err))
  love.event.quit(ok and 0 or 1)
end
