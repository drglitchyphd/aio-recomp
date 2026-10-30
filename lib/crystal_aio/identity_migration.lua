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

  local function removeTree(path)
    local info = fs.getInfo(path)
    if not info then return end
    if info.type == 'directory' then
      for _, name in ipairs(fs.getDirectoryItems(path) or {}) do
        if name ~= '.' and name ~= '..' and not name:find('[/\\]') then
          removeTree(path .. '/' .. name)
        end
      end
    end
    if fs.remove then fs.remove(path) end
  end
  -- the old voxel disk cache is a cache: free the space (every boot, so an
  -- interrupted delete finishes later; nothing here is settings or run data)
  pcall(removeTree, 'mod_cache/gen2-aio/voxel')

  local marker = 'mod_cache/' .. NEW .. '/' .. MARKER
  if fs.getInfo(marker) then return true end
  local function copyTree(from, to, top)
    local info = fs.getInfo(from)
    if not info then return end
    if info.type == 'directory' then
      assert(fs.createDirectory(to))
      for _, name in ipairs(fs.getDirectoryItems(from)) do
        assert(name ~= '.' and name ~= '..' and not name:find('[/\\]'))
        if not (top and SKIP_TOP[name]) then
          copyTree(from .. '/' .. name, to .. '/' .. name)
        end
      end
    elseif info.type == 'file' and not fs.getInfo(to) then
      assert(fs.createDirectory(to:match('^(.*)/[^/]+$')))
      assert(fs.write(to, assert(fs.read(from))))
    end
  end
  -- mod.cache: mod_cache/<id>/ (the HD asset pack, KIM settings, zoom...)
  for _, src in ipairs(M.OLD) do
    copyTree('mod_cache/' .. src.id, 'mod_cache/' .. NEW, true)
  end
  -- mod.storage: mod_storage/<game>/<playthrough>/<id>/ (Nuzlocke runs,
  -- QoL Toggles settings, auto-save backups...)
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
  assert(fs.createDirectory('mod_cache/' .. NEW))
  assert(fs.write(marker, 'Imported settings, storage and cache from gen2-aio / KIM_ARENA; originals retained.\n'))
  return true
end
return M
