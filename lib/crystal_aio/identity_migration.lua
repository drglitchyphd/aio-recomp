-- One-time import from the mod's former identities. Never removes or
-- overwrites old data: a setting, save key or file the current id already
-- has always wins, and the old buckets and folders are left as they were.
--
-- 1.0.0 renamed gen2-aio to crystal-aio; 0.9.50 had renamed KIM_ARENA to
-- gen2-aio. Both are imported here, newest first, so a player coming from
-- either keeps their settings, run data and downloads. A player who already
-- went KIM_ARENA -> gen2-aio has both buckets; gen2-aio's (newer) values win.
local M = {}
local NEW = 'crystal-aio'
M.NEW = NEW
-- newest first; map rewrites a stored option value from that era
M.OLD = {
  { id = 'gen2-aio' },
  { id = 'KIM_ARENA', map = function(v)
    if type(v) == 'string' then return (v:gsub('^kim_arena:', 'gen2_aio:')) end
    return v
  end },
}
local MARKER = 'identity_migrated.txt'
-- Not copied: the voxel disk cache (gmarc/lib/MeshStore.lua, mod_cache/<id>/
-- voxel/). Its file names carry a build id that changes with the code, so
-- copied maps would be swept as stale on first use anyway; the new id
-- rebuilds them. The old id's copy is deleted below to free the space.
local SKIP_TOP = { voxel = true, [MARKER] = true }

function M.install(mod)
  local function clone(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}; seen[value] = out
    for k, v in pairs(value) do out[k] = clone(v, seen) end
    return out
  end
  -- save.modData (mod.save): buckets keyed by mod id inside each save
  local function migrateSave(save)
    local buckets = save and save.modData
    if type(buckets) ~= 'table' then return end
    local new = buckets[NEW]
    for _, src in ipairs(M.OLD) do
      local old = buckets[src.id]
      if type(old) == 'table' then
        new = new or {}
        for k, v in pairs(old) do if new[k] == nil then new[k] = clone(v) end end
      end
    end
    if new then buckets[NEW] = new end
  end
  mod.events:on('save.loading', function(ev) migrateSave(ev and ev.raw) end)
  mod.events:on('game.ready', function(ev) migrateSave(ev and ev.game and ev.game.save) end)

  local ok, SaveData = pcall(require, 'src.core.SaveData')
  if not ok or type(SaveData.persistenceFs) ~= 'function' then return false end
  local fs = SaveData.persistenceFs()

  -- mod options: options.modOptions[id]
  local options = SaveData.loadOptions(fs)
  local buckets = options.modOptions or {}
  local current = buckets[NEW] or {}
  local imported, fallback = {}, {}
  for k, v in pairs(current) do imported[k] = v end
  for _, src in ipairs(M.OLD) do
    for k, v in pairs(buckets[src.id] or {}) do
      if imported[k] == nil then
        if src.map then v = src.map(v) end
        imported[k], fallback[k] = clone(v), v
      end
    end
  end
  if next(fallback) then
    buckets[NEW], options.modOptions = imported, buckets
    assert(SaveData.saveOptions(options, fs), 'could not save migrated options')
    -- The loader already read options before this entry ran; bridge this boot.
    local get = mod.options.get
    mod.options.get = function(self, key)
      if fallback[key] ~= nil then return fallback[key] end
      return get(self, key)
    end
    mod.events:on('mod.options_changed', function(ev)
      if ev and ev.mod and ev.mod ~= NEW then return end
      if ev and ev.key then fallback[ev.key] = nil else fallback = {} end
    end)
  end

  local marker = 'mod_cache/' .. NEW .. '/' .. MARKER
  local function copyFile(from, to)
    if fs.getInfo(to) then return end            -- what the new id has wins
    assert(fs.createDirectory(to:match('^(.*)/[^/]+$')))
    assert(fs.write(to, assert(fs.read(from))))
  end
  local function copyTree(from, to)
    local info = fs.getInfo(from)
    if not info then return end
    if info.type == 'directory' then
      assert(fs.createDirectory(to))
      for _, name in ipairs(fs.getDirectoryItems(from)) do
        assert(name ~= '.' and name ~= '..' and not name:find('[/\\]'))
        copyTree(from .. '/' .. name, to .. '/' .. name)
      end
    elseif info.type == 'file' then
      copyFile(from, to)
    end
  end

  -- 1.0.0: what has to be there before anything reads it is copied now --
  -- mod.storage (Nuzlocke runs, QoL Toggles settings, auto-save backups)
  -- and mod.cache's top-level files (KIM settings, zoom). mod.cache's
  -- FOLDERS (the HD asset pack: hundreds of MB, file by file) and freeing
  -- the old voxel cache run in the background a few milliseconds a frame,
  -- so the first launch does not sit on a frozen screen; until the art has
  -- arrived the game simply shows the fallback art for it. The marker is
  -- written only when the whole import is through, so an interrupted copy
  -- carries on the next time the game starts.
  local jobs = {}                                 -- stack, popped from the end
  if not fs.getInfo(marker) then
    if fs.getInfo('mod_storage') then
      for _, version in ipairs(fs.getDirectoryItems('mod_storage')) do
        local dir = 'mod_storage/' .. version
        local info = fs.getInfo(dir)
        if info and info.type == 'directory' then
          for _, run in ipairs(fs.getDirectoryItems(dir)) do
            for _, src in ipairs(M.OLD) do
              copyTree(dir .. '/' .. run .. '/' .. src.id, dir .. '/' .. run .. '/' .. NEW)
            end
          end
        end
      end
    end
    -- older ids last on the stack's bottom: gen2-aio's files land first and win
    for i = #M.OLD, 1, -1 do
      local root = 'mod_cache/' .. M.OLD[i].id
      local info = fs.getInfo(root)
      if info and info.type == 'directory' then
        for _, name in ipairs(fs.getDirectoryItems(root)) do
          assert(name ~= '.' and name ~= '..' and not name:find('[/\\]'))
          local from = root .. '/' .. name
          local kind = fs.getInfo(from)
          if not SKIP_TOP[name] and kind then
            if kind.type == 'file' then
              -- small settings files: now, in precedence order below
            else
              jobs[#jobs + 1] = { from = from, to = 'mod_cache/' .. NEW .. '/' .. name }
            end
          end
        end
      end
    end
    for _, src in ipairs(M.OLD) do
      local root = 'mod_cache/' .. src.id
      if fs.getInfo(root) then
        for _, name in ipairs(fs.getDirectoryItems(root)) do
          local from = root .. '/' .. name
          local kind = fs.getInfo(from)
          if not SKIP_TOP[name] and kind and kind.type == 'file' then
            copyFile(from, 'mod_cache/' .. NEW .. '/' .. name)
          end
        end
      end
    end
  end
  -- the old voxel disk cache is a cache: free the space (every start until
  -- it is gone, in the background like the copy)
  if fs.getInfo('mod_cache/gen2-aio/voxel') then
    table.insert(jobs, 1, { rm = 'mod_cache/gen2-aio/voxel' })
  end

  local total, done = 0, 0
  local function finish()
    if fs.getInfo(marker) then return end
    assert(fs.createDirectory('mod_cache/' .. NEW))
    assert(fs.write(marker, 'Imported settings, storage and cache from gen2-aio / KIM_ARENA; originals retained.\n'))
  end
  -- one unit of work; false when there is none left
  local function work()
    local job = jobs[#jobs]
    if not job then return false end
    jobs[#jobs] = nil
    if job.rm then
      local info = fs.getInfo(job.rm)
      if info and info.type == 'directory' and not job.expanded then
        job.expanded = true
        jobs[#jobs + 1] = job                     -- the folder itself, after its contents
        for _, name in ipairs(fs.getDirectoryItems(job.rm) or {}) do
          if name ~= '.' and name ~= '..' and not name:find('[/\\]') then
            jobs[#jobs + 1] = { rm = job.rm .. '/' .. name }
          end
        end
      elseif info and fs.remove then
        fs.remove(job.rm)
      end
      return true
    end
    local info = fs.getInfo(job.from)
    if info and info.type == 'directory' then
      assert(fs.createDirectory(job.to))
      for _, name in ipairs(fs.getDirectoryItems(job.from)) do
        assert(name ~= '.' and name ~= '..' and not name:find('[/\\]'))
        jobs[#jobs + 1] = { from = job.from .. '/' .. name, to = job.to .. '/' .. name }
      end
    elseif info and info.type == 'file' then
      copyFile(job.from, job.to)
      done = done + 1
    end
    return true
  end
  local failed = nil
  local clock = love and love.timer and love.timer.getTime or os.clock
  -- run the import for up to `budget` seconds; true once everything is done
  function M.step(budget)
    if failed then return false, failed end
    local deadline = clock() + (budget or 0.006)
    repeat
      local ok, more = pcall(work)
      if not ok then
        failed = tostring(more)
        local d = rawget(mod, '_kimArenaDiag')
        if d then pcall(d, 'import', 'stopped: ' .. failed:sub(1, 80) .. ' (retried next start)') end
        return false, failed
      end
      if not more then
        finish()
        local d = rawget(mod, '_kimArenaDiag')
        if d and total > 0 then pcall(d, 'import', ('gen2-aio files imported: %d'):format(done)) end
        return true
      end
    until clock() >= deadline
    local d = rawget(mod, '_kimArenaDiag')
    if d then pcall(d, 'import', ('importing gen2-aio files: %d copied...'):format(done)) end
    return false
  end
  total = #jobs
  if #jobs == 0 then
    finish()
  elseif mod.hooks and type(mod.hooks.wrap) == 'function' then
    local finished = false
    mod.hooks:wrap('core.update', function(nextFn, ...)
      if not finished and not failed then
        local okS, fin = pcall(M.step)
        finished = okS and fin == true
      end
      return nextFn(...)
    end)
  end
  return true
end
return M
