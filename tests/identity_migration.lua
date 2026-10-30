-- lib/crystal_aio/identity_migration.lua: gen2-aio (and the older KIM_ARENA)
-- settings, save data, storage and downloads carried over to crystal-aio.
local M = dofile('lib/crystal_aio/identity_migration.lua')
assert(M.NEW == 'crystal-aio')

local function newFs(files)
  local fs = { files = files, removed = {} }
  function fs.getInfo(p)
    if files[p] then return { type = 'file' } end
    for k in pairs(files) do if k:sub(1, #p + 1) == p .. '/' then return { type = 'directory' } end end
  end
  function fs.getDirectoryItems(p)
    local result, seen = {}, {}
    for k in pairs(files) do if k:sub(1, #p + 1) == p .. '/' then
      local child = k:sub(#p + 2):match('^[^/]+')
      if not seen[child] then result[#result + 1] = child; seen[child] = true end
    end end
    table.sort(result)
    return result
  end
  function fs.createDirectory() return true end
  function fs.read(p) return files[p] end
  function fs.write(p, v) if fs.fail == p then return false end; files[p] = v; return true end
  function fs.remove(p) if files[p] then files[p] = nil; fs.removed[#fs.removed + 1] = p end; return true end
  return fs
end

local function boot(fs, options, stored)
  local saves = 0
  package.loaded['src.core.SaveData'] = { persistenceFs = function() return fs end,
    loadOptions = function() return options end,
    saveOptions = function(o) options = o; saves = saves + 1; return true end }
  local events = {}
  local mod = { options = { get = function(_, k) return stored[k] end },
    events = { on = function(_, name, f) events[name] = f end },
    hooks = { wrap = function(_, name, f) events['hook:' .. name] = f end } }
  local ok, err = pcall(M.install, mod)
  return ok, err, mod, events, function() return options, saves end
end
-- 1.0.0: the mod.cache folders (the HD asset pack) copy in the background
-- (core.update, a few ms a frame); drive that to the end
local function drain(events)
  local hook = events['hook:core.update']
  if not hook then return true end
  for _ = 1, 100000 do
    local okS, fin, why = pcall(M.step, math.huge)
    if not okS then return false, fin end
    if fin then return true end
    if why then return false, why end
  end
  return false, 'never finished'
end

-- ------------------------------------------------ a gen2-aio 0.9.x player
-- (who came from KIM_ARENA earlier, so both old buckets exist)
local files = {
  -- HD asset pack downloaded under gen2-aio, and an older KIM_ARENA copy
  ['mod_cache/gen2-aio/kim_assets/files/a.png'] = 'gen2 art',
  ['mod_cache/KIM_ARENA/kim_assets/files/a.png'] = 'kim art',
  ['mod_cache/KIM_ARENA/kim_assets/files/b.png'] = 'kim only',
  ['mod_cache/gen2-aio/screen_zoom.lua'] = 'zoom=2',
  ['mod_cache/crystal-aio/screen_zoom.lua'] = 'zoom=3',          -- newer, kept
  ['mod_cache/gen2-aio/identity_migrated.txt'] = 'old marker',
  ['mod_cache/gen2-aio/voxel/g1234-0001.kms'] = 'mesh',
  ['mod_cache/gen2-aio/voxel/index.txt'] = 'g1234-0001.kms',
  -- Nuzlocke run / QoL Toggles storage of two playthroughs
  ['mod_storage/crystal/run1/gen2-aio/nz_run'] = 'deaths=2',
  ['mod_storage/crystal/run1/gen2-aio/settings'] = 'old',
  ['mod_storage/crystal/run1/crystal-aio/settings'] = 'new',       -- newer, kept
  ['mod_storage/crystal/run2/KIM_ARENA/nz_run'] = 'deaths=7',
  ['mod_storage/crystal/run1/other_mod/x'] = 'untouched',
}
local fs = newFs(files)
local options = { modOptions = {
  KIM_ARENA = { weatherFx = false, gen2UiTheme = 'kim_arena:custom', volume = 3, kimOnly = 'k' },
  ['gen2-aio'] = { weatherFx = true, volume = 5, nuzlocke = true, perfMode = 'quality' },
  ['crystal-aio'] = { volume = 8 },
} }
local stored = { volume = 8 }
local ok, err, mod, events, state = boot(fs, options, stored)
assert(ok, err)
-- at start-up: settings and run data now, the art not yet
assert(files['mod_storage/crystal/run2/crystal-aio/nz_run'] == 'deaths=7', 'run data imported at start-up')
assert(files['mod_cache/crystal-aio/screen_zoom.lua'] == 'zoom=3', 'settings files handled at start-up')
assert(files['mod_cache/crystal-aio/kim_assets/files/a.png'] == nil, 'the asset pack waits for the background')
assert(not files['mod_cache/crystal-aio/identity_migrated.txt'], 'no marker until the import is through')
assert(events['hook:core.update'], 'the background import is hooked')
assert(drain(events))
local opts, saves = state()
local saved = opts.modOptions['crystal-aio']
assert(saves == 1, 'options saved once')
-- crystal-aio's own value wins; gen2-aio beats KIM_ARENA; KIM_ARENA fills the rest
assert(saved.volume == 8 and saved.weatherFx == true and saved.nuzlocke == true)
assert(saved.perfMode == 'quality' and saved.kimOnly == 'k')
assert(saved.gen2UiTheme == 'gen2_aio:custom', 'KIM_ARENA theme ids mapped')
-- the loader read options before the entry ran: this boot is bridged
assert(mod.options:get('volume') == 8 and mod.options:get('weatherFx') == true)
assert(mod.options:get('nuzlocke') == true and mod.options:get('gen2UiTheme') == 'gen2_aio:custom')
-- originals untouched
assert(opts.modOptions['gen2-aio'].volume == 5 and opts.modOptions.KIM_ARENA.volume == 3)
-- a change made under the new id ends the bridge for that key
stored.weatherFx = false; events['mod.options_changed']({ mod = 'crystal-aio', key = 'weatherFx' })
assert(mod.options:get('weatherFx') == false)
events['mod.options_changed']({ mod = 'wilds', key = 'nuzlocke' })
assert(mod.options:get('nuzlocke') == true, 'another mod\'s change does not end the bridge')

-- mod.cache
assert(files['mod_cache/crystal-aio/kim_assets/files/a.png'] == 'gen2 art', 'gen2-aio download wins')
assert(files['mod_cache/crystal-aio/kim_assets/files/b.png'] == 'kim only', 'KIM_ARENA fills the gaps')
assert(files['mod_cache/crystal-aio/screen_zoom.lua'] == 'zoom=3', 'newer file not overwritten')
assert(files['mod_cache/gen2-aio/kim_assets/files/a.png'] == 'gen2 art', 'original kept')
assert(files['mod_cache/KIM_ARENA/kim_assets/files/a.png'] == 'kim art', 'original kept')
assert(files['mod_cache/crystal-aio/voxel/g1234-0001.kms'] == nil, 'voxel cache is rebuilt, not copied')
assert(files['mod_cache/gen2-aio/voxel/g1234-0001.kms'] == nil
  and files['mod_cache/gen2-aio/voxel/index.txt'] == nil, 'old voxel cache freed')
assert(files['mod_cache/crystal-aio/identity_migrated.txt']
  and files['mod_cache/crystal-aio/identity_migrated.txt'] ~= 'old marker', 'own marker, not the copied one')
-- mod.storage
assert(files['mod_storage/crystal/run1/crystal-aio/nz_run'] == 'deaths=2', 'Nuzlocke run carried over')
assert(files['mod_storage/crystal/run1/crystal-aio/settings'] == 'new', 'newer storage not overwritten')
assert(files['mod_storage/crystal/run2/crystal-aio/nz_run'] == 'deaths=7', 'KIM_ARENA-era run carried over')
assert(files['mod_storage/crystal/run1/gen2-aio/nz_run'] == 'deaths=2', 'original kept')
assert(files['mod_storage/crystal/run1/crystal-aio/x'] == nil)

-- save.modData (mod.save: Nuzlocke rules/tracker, QoL counters)
local save = { modData = {
  KIM_ARENA = { nz_tracker = { caught = 1 }, kim_key = 'k' },
  ['gen2-aio'] = { nz_tracker = { caught = 4 }, nz_rules = { dupes = true } },
  ['crystal-aio'] = { keep = true },
} }
events['save.loading']({ raw = save })
local b = save.modData['crystal-aio']
assert(b.keep and b.nz_tracker.caught == 4 and b.nz_rules.dupes and b.kim_key == 'k')
b.nz_tracker.caught = 9
assert(save.modData['gen2-aio'].nz_tracker.caught == 4, 'a copy, not the old table')
events['save.loading']({ raw = save })
assert(b.nz_tracker.caught == 9, 'loading again never overwrites')
local live = { modData = { ['gen2-aio'] = { nz_tracker = { caught = 2 } } } }
events['game.ready']({ game = { save = live } })
assert(live.modData['crystal-aio'].nz_tracker.caught == 2, 'game.ready path')
events['save.loading']({ raw = { modData = { other = {} } } })   -- nothing to import: no bucket made
events['save.loading']({ raw = {} })

-- second boot: nothing left to import, nothing written
local before = {}
for k, v in pairs(files) do before[k] = v end
options = opts
ok, err, mod, events, state = boot(fs, options, stored)
assert(ok, err)
local _, saves2 = state()
assert(saves2 == 0, 'no options write once everything is imported')
for k, v in pairs(before) do assert(files[k] == v, 'second boot changed ' .. k) end

-- ------------------------------------------------ retry after a failed copy
files = {
  ['mod_cache/gen2-aio/kim_assets/files/a.png'] = 'art',
  ['mod_cache/gen2-aio/kim_assets/files/c.png'] = 'more',
  ['mod_storage/crystal/run1/gen2-aio/nz_run'] = 'deaths=1',
}
fs = newFs(files)
fs.fail = 'mod_cache/crystal-aio/kim_assets/files/c.png'
ok, err, mod, events = boot(fs, { modOptions = { ['gen2-aio'] = { volume = 4 } } }, {})
assert(ok, err)
local fin, why = drain(events)
assert(not fin and why, 'a failed write surfaces')
assert(not files['mod_cache/crystal-aio/identity_migrated.txt'], 'no marker after a failure')
fs.fail = nil
ok, err, mod, events = boot(fs, { modOptions = {} }, {})
assert(ok, err)
assert(drain(events))
assert(files['mod_cache/crystal-aio/kim_assets/files/c.png'] == 'more', 'retry finishes the copy')
assert(files['mod_storage/crystal/run1/crystal-aio/nz_run'] == 'deaths=1')
assert(files['mod_cache/crystal-aio/identity_migrated.txt'])

-- ------------------------------------------------ straight from KIM_ARENA
files = { ['mod_cache/KIM_ARENA/kim_assets/files/a.png'] = 'kim' }
fs = newFs(files)
local stored3 = {}
ok, err, mod, events, state = boot(fs, { modOptions = { KIM_ARENA = { gen2UiTheme = 'kim_arena:gen3' } } }, stored3)
assert(ok, err)
assert(state().modOptions['crystal-aio'].gen2UiTheme == 'gen2_aio:gen3')
assert(mod.options:get('gen2UiTheme') == 'gen2_aio:gen3')
assert(drain(events))
assert(files['mod_cache/crystal-aio/kim_assets/files/a.png'] == 'kim')

-- ------------------------------------------------ a fresh install
files = {}
fs = newFs(files)
ok, err, mod, events, state = boot(fs, { modOptions = {} }, {})
assert(ok, err)
assert(select(2, state()) == 0 and state().modOptions['crystal-aio'] == nil, 'nothing to import, nothing saved')
assert(files['mod_cache/crystal-aio/identity_migrated.txt'])

print('Identity migration: gen2-aio + KIM_ARENA -> crystal-aio settings (precedence, theme mapping, boot bridge), '
  .. 'mod.cache / mod.storage / save.modData copy, Nuzlocke data, non-overwrite, originals kept, '
  .. 'voxel cache skipped and freed, asset pack in the background, idempotent second boot, retry PASS')
