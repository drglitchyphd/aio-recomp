-- One-time import from the former identity. Never remove or overwrite old data.
local M = {}
local OLD, NEW = 'KIM_ARENA', 'gen2-aio'
function M.install(mod)
  local function clone(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}; seen[value] = out
    for k,v in pairs(value) do out[k] = clone(v, seen) end
    return out
  end
  local function migrateSave(save)
    local buckets = save and save.modData
    local old = buckets and buckets[OLD]
    if type(old) ~= 'table' then return end
    local new = buckets[NEW] or {}
    for k,v in pairs(old) do if new[k] == nil then new[k] = clone(v) end end
    buckets[NEW] = new
  end
  mod.events:on('save.loading', function(ev) migrateSave(ev and ev.raw) end)
  mod.events:on('game.ready', function(ev) migrateSave(ev and ev.game and ev.game.save) end)
  local ok, SaveData = pcall(require, 'src.core.SaveData')
  if not ok or type(SaveData.persistenceFs) ~= 'function' then return false end
  local fs = SaveData.persistenceFs()
  local options = SaveData.loadOptions(fs)
  local buckets = options.modOptions or {}
  local legacy, current = buckets[OLD] or {}, buckets[NEW] or {}
  local imported, fallback = {}, {}
  for k,v in pairs(current) do imported[k] = v end
  for k,v in pairs(legacy) do
    if current[k] == nil then
      if type(v) == 'string' then v = v:gsub('^kim_arena:', 'gen2_aio:') end
      imported[k], fallback[k] = v, v
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
  local marker = 'mod_cache/' .. NEW .. '/identity_migrated.txt'
  if fs.getInfo(marker) then return true end
  local function copyTree(from, to)
    local info = fs.getInfo(from)
    if not info then return end
    if info.type == 'directory' then
      assert(fs.createDirectory(to))
      for _, name in ipairs(fs.getDirectoryItems(from)) do
        assert(name ~= '.' and name ~= '..' and not name:find('[/\\]'))
        copyTree(from .. '/' .. name, to .. '/' .. name)
      end
    elseif info.type == 'file' and not fs.getInfo(to) then
      assert(fs.createDirectory(to:match('^(.*)/[^/]+$')))
      assert(fs.write(to, assert(fs.read(from))))
    end
  end
  copyTree('mod_cache/' .. OLD, 'mod_cache/' .. NEW)
  -- Storage is scoped by game and playthrough, then mod ID.
  if fs.getInfo('mod_storage') then
    for _, version in ipairs(fs.getDirectoryItems('mod_storage')) do
      local dir = 'mod_storage/' .. version
      local info = fs.getInfo(dir)
      if info and info.type == 'directory' then
        for _, run in ipairs(fs.getDirectoryItems(dir)) do
          copyTree(dir .. '/' .. run .. '/' .. OLD, dir .. '/' .. run .. '/' .. NEW)
        end
      end
    end
  end
  assert(fs.createDirectory('mod_cache/' .. NEW))
  assert(fs.write(marker, 'Imported settings and cache; original data retained.\n'))
  return true
end
return M
