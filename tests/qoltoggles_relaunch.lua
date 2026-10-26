-- stub harness for qoltoggles nurse paths
local function U(name)
  local t = {}
  return setmetatable(t, {
    __index = function(s, k) local v = U(name.."."..tostring(k)); rawset(s,k,v); return v end,
    __call = function() return U(name.."()") end,
    __concat = function(a,b) return tostring(a)..tostring(b) end,
    __tostring = function() return name end,
  })
end
love = U("love")
local listeners = {}
local events = { on = function(_, n, fn) listeners[n] = listeners[n] or {}; table.insert(listeners[n], fn) end, once=function() end, emit=function() end }
local function emit(n, p) for _, f in ipairs(listeners[n] or {}) do local ok, e = pcall(f, p); if not ok then print("ERR", n, e) end end end
local World2 = {}
World2.__index = World2
function World2:interactBody() self.vanillaCalled = true; return "vanilla" end
function World2:interact() self.facadeCalled=true; return "facade" end
function World2:startHealMachineAnim(t, cb) self.anim = {t=t, cb=cb} end
function World2:busy() return false end
function World2:facingObjectCell() return 5, 3 end
function World2:npcAt(x,y) if x==5 and y==3 then return self.nurse end end
function World2:healParty() end
local opts = { qt_quick_nurse = true, qt_turn_away_nurse = true }
local stubs = {
  ["src.world.gen2.World"] = World2,
  ["src.mods.Runtime"] = { wants=function() return false end, emit=function() end },
}
local GameFacade = { save = { party = {} }, mods = {} }
stubs["src.core.Game"] = GameFacade
stubs["src.core.GameVersion"] = { generation = function() return 2 end, get=function() return "crystal" end }
local realRequire = require
require = function(n) if stubs[n] then return stubs[n] end; local v = U(n); stubs[n]=v; return v end
local src = io.open("qoltoggles/main.lua"):read("*a")
local entry = assert(loadstring(src, "@qt"))()
local mod = { exports = {}, generation = 2, id = "gen2-aio", events = events,
  hooks = { wrap = function() end },
  options = { get = function(_, k) return opts["qt_"..k] end, define=function() end },
  content = U("content"), log = U("log"), storage = nil, find = function() return nil end }
mod.read = function() return nil end
local ok, err = pcall(entry, mod)
print("entry ok", ok, err)
emit("game.ready", { game = {} })
print("wrapped interactBody:", World2.interactBody ~= nil)
local w = setmetatable({ player = { cellX=5, cellY=5, facing="up" }, map = {}, vm = {},
  nurse = { def = { sprite = "SPRITE_NURSE", index = 1 } } }, World2)
print("interact ->", w:interactBody(), w.vanillaCalled, w.anim and w.anim.t)
if w.anim then w.anim.cb() end
print("facing after quick nurse:", w.player.facing)
-- turn-away path
opts.qt_quick_nurse = false
local w2 = setmetatable({ player = { cellX=5, cellY=5, facing="up" }, map = {}, vm = {} }, World2)
emit("script.started", {ctx={kind="script"}})
w2:startHealMachineAnim(0, function() end)
emit("script.ended", { ctx = { kind = "script" }, completed = true })
print("facing after turn away:", w2.player.facing)
-- ---- session 2: same Lua state, fresh event bus and fresh options table
listeners = {}
local opts2 = { qt_quick_nurse = false, qt_turn_away_nurse = true }
local entry2 = assert(loadstring(src, "@qt"))()
local events2 = { on = events.on, once = events.once, emit = events.emit }
local mod2 = { exports = {}, generation = 2, id = "gen2-aio", events = events2,
  hooks = { wrap = function() end },
  options = { get = function(_, k) return opts2["qt_"..k] end, define=function() end },
  content = U("content"), log = U("log"), storage = nil, find = function() return nil end }
mod2.read = function() return nil end
print("S2 entry ok", pcall(entry2, mod2))
emit("game.ready", { game = {} })
-- quick nurse is OFF in session 2: the A press must reach vanilla
local w3 = setmetatable({ player = { cellX=5, cellY=5, facing="up" }, map = {}, vm = {},
  nurse = { def = { sprite = "SPRITE_NURSE", index = 1 } } }, World2)
print("S2 quick nurse OFF -> vanilla:", w3:interactBody(), w3.vanillaCalled)
-- turn away fires in session 2
local w4 = setmetatable({ player = { cellX=5, cellY=5, facing="up" }, map = {}, vm = {} }, World2)
emit("script.started", {ctx={kind="script"}})
w4:startHealMachineAnim(0, function() end)
emit("script.ended", { ctx = { kind = "script" }, completed = true })
print("S2 facing after turn away:", w4.player.facing)
-- quick nurse ON again in session 2, and a second A press mid-animation
opts2.qt_quick_nurse = true
local w5 = setmetatable({ player = { cellX=5, cellY=5, facing="up" }, map = {}, vm = {},
  nurse = { def = { sprite = "SPRITE_NURSE", index = 1 } } }, World2)
print("S2 quick nurse ON:", w5:interactBody(), w5.vanillaCalled)
w5.healAnim = {}  -- machine running
local first = w5.anim
print("S2 A mid-anim ignored:", w5:interactBody(), w5.anim == first)
assert(w.player.facing=="down" and w2.player.facing=="down")
assert(w3.vanillaCalled and w4.player.facing=="down")
assert(w5.anim==first and w5._aioQuickNurse and w5:busy())
w5.anim.cb()
assert(not w5._aioQuickNurse and not w5:busy())
local w6=setmetatable({player={facing="up"},map={},vm={},
  nurse={def={sprite="SPRITE_NURSE",index=1}}},World2)
assert(w6:interact()==true and not w6.facadeCalled,"nurse must run before a facade consumes A")
w6.anim.cb()
opts2.qt_quick_nurse=false
assert(w6:interact()=="facade","OFF preserves the facade chain")
w6.player.facing="up"
emit("script.started",{ctx={kind="script",vm=w6.vm}})
w6:startHealMachineAnim("0",function()end)
emit("script.started",{ctx={kind="callback",vm=w6.vm}})
emit("script.ended",{completed=true,ctx={kind="callback",vm=w6.vm}})
assert(w6.player.facing=="up","nested callback must not consume turn-away")
emit("script.ended",{completed=true,ctx={kind="script",vm={}}})
assert(w6.player.facing=="up","another world's script must not consume turn-away")
emit("script.ended",{completed=true,ctx={kind="script",vm=w6.vm}})
assert(w6.player.facing=="down")
w6.player.facing="up";w6:startHealMachineAnim(1,function()end)
emit("script.ended",{completed=true,ctx={kind="script",vm=w6.vm}})
assert(w6.player.facing=="up","Elm's machine must not turn the player")
print("Nurse: relaunch, facade interception, busy lock, nested callbacks and VM ownership PASS")
