local M = dofile('lib/gen2_aio/identity_migration.lua')
local files = {['mod_cache/KIM_ARENA/hd/a.png']='art', ['mod_cache/KIM_ARENA/key_wheel.lua']='BICYCLE',
 ['mod_cache/gen2-aio/key_wheel.lua']='OLD_ROD', ['mod_storage/crystal/run1/KIM_ARENA/data']='state'}
local fs={}
function fs.getInfo(p)
 if files[p] then return {type='file'} end
 for k in pairs(files) do if k:sub(1,#p+1)==p..'/' then return {type='directory'} end end
end
function fs.getDirectoryItems(p)
 local result,seen={},{}
 for k in pairs(files) do if k:sub(1,#p+1)==p..'/' then
  local child=k:sub(#p+2):match('^[^/]+');if not seen[child] then result[#result+1]=child;seen[child]=true end
 end end
 return result
end
function fs.createDirectory() return true end
function fs.read(p) return files[p] end
function fs.write(p,v) if fs.fail==p then return false end;files[p]=v;return true end
local options={modOptions={KIM_ARENA={weatherFx=false,gen2UiTheme='kim_arena:custom',volume=3},['gen2-aio']={volume=8}}}
package.loaded['src.core.SaveData']={persistenceFs=function() return fs end,loadOptions=function() return options end,
 saveOptions=function(o) options=o;return true end}
local events = {}
local current={volume=8}
local mod={options={get=function(_,k) return current[k] end},events={on=function(_,name,f) events[name]=f end}}
assert(M.install(mod))
assert(mod.options:get('volume')==8 and mod.options:get('weatherFx')==false)
assert(mod.options:get('gen2UiTheme')=='gen2_aio:custom')
assert(files['mod_cache/gen2-aio/hd/a.png']=='art')
assert(files['mod_cache/gen2-aio/key_wheel.lua']=='OLD_ROD')
assert(files['mod_cache/KIM_ARENA/hd/a.png']=='art')
assert(files['mod_storage/crystal/run1/gen2-aio/data']=='state')
current.weatherFx=true;events['mod.options_changed']({mod='gen2-aio',key='weatherFx'})
assert(mod.options:get('weatherFx')==true)
local save={modData={KIM_ARENA={nz_tracker={caught=4}},['gen2-aio']={keep=true}}}
events['save.loading']({raw=save})
assert(save.modData['gen2-aio'].nz_tracker.caught==4 and save.modData['gen2-aio'].keep)
save.modData['gen2-aio'].nz_tracker.caught=9
assert(save.modData.KIM_ARENA.nz_tracker.caught==4)
assert(M.install(mod))
files['mod_cache/gen2-aio/identity_migrated.txt']=nil
files['mod_cache/gen2-aio/hd/a.png']=nil
fs.fail='mod_cache/gen2-aio/hd/a.png'
assert(not pcall(M.install,mod));assert(not files['mod_cache/gen2-aio/identity_migrated.txt'])
fs.fail=nil;assert(M.install(mod));assert(files['mod_cache/gen2-aio/hd/a.png']=='art')
print('Identity migration: settings, theme mapping, asset/storage copy, non-overwrite, originals, changed settings and retry PASS')
