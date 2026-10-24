local T = 100
love = { timer = { getTime = function() return T end },
  graphics = { getDimensions = function() return 1080, 2520 end, push=function() end, pop=function() end, origin=function() end },
  system = { getOS = function() return "Android" end } }
package.preload["src.core.TouchControls"] = function() return { active = true, layout = function() return {} end } end
package.preload["src.core.TouchSkin"] = function() return { active = false } end
local hooks, log = {}, {}
local exports = {}
local mod = { id = "touch", exports = {}, options = { get = function() return nil end, define = function() end }, read = function() return nil end,
  hooks = { wrap = function(_, n, f, p) hooks[n] = hooks[n] or {}; hooks[n][p] = f end },
  input = { tap = function(_, g, b) log[#log+1] = "tap:" .. b end,
            press = function(_, g, b) log[#log+1] = "press:" .. b; return {} end,
            release = function() end },
  find = function() return { exports = exports } end }
local parent = { }
setmetatable(mod, { __index = parent })
assert(loadfile("touch/main.lua"))()(mod)
local top
local game = { stack = { top = function() return top end }, world = {}, input = {} }
local ptr = hooks["input.pointer"][10]
local hud = hooks["render.hud"][30000]
local function send(phase, x, y) return ptr(function() log[#log+1]="next" end, game, { phase = phase, x = x, y = y, id = 1, source = "touch" }) end
local function tapAt(x, y) log = {}; hud(function() end, game); send("pressed", x, y); T = T + 0.1; hud(function() end, game); send("released", x, y); return table.concat(log, ",") end

-- party (list)
local party = { index = 1, party = { {}, {} } }
top = party
exports.screenTapTargets = function() return { state = party, kind = "party", time = T,
  cells = { { kind = "party", index = 1, x = 100, y = 500, w = 800, h = 120 }, { kind = "party", index = 2, x = 100, y = 620, w = 800, h = 120 } } } end
print("party open space:", tapAt(500, 1500))
print("party row:", tapAt(500, 650))
-- ask-shift
local battle = { isBattle = true, battle = {}, phase = "ask-shift" }
top = battle
exports.screenTapTargets = function() return { state = battle, kind = "generic", generic = true, mode = "list", phase = "ask-shift", time = T,
  cells = { { kind = "row", index = 1, x = 700, y = 1900, w = 240, h = 42, select = function(s) s.shiftIndex = 1 end },
            { kind = "row", index = 2, x = 700, y = 1946, w = 240, h = 42, select = function(s) s.shiftIndex = 2 end } } } end
exports.gen2ModernBattleUi = { tapTargets = function() return { cells = {}, state = nil, phase = "ask-shift", time = T } end }
print("ask-shift open space:", tapAt(500, 1000))
print("ask-shift YES:", tapAt(800, 1920))
-- joystick drag then tap, ask-shift
log = {}
hud(function() end, game); send("pressed", 500, 1000)
for i=1,10 do T=T+0.05; send("moved", 500, 1000 + i*15); hud(function() end, game) end
T=T+0.7; hud(function() end, game); send("released", 500, 1150)
print("ask-shift joystick:", table.concat(log, ","))
print("ask-shift tap after joystick:", tapAt(500, 1000))
-- party with submenu open
party.submenu = { index = 1, items = {{},{},{}} }
top = party
exports.screenTapTargets = function() return { state = party, kind = "party", time = T,
  cells = { { kind = "party", index = 1, x = 100, y = 500, w = 800, h = 120 },
            { kind = "partySub", index = 1, x = 600, y = 900, w = 300, h = 80 } } } end
print("party submenu open space:", tapAt(300, 1500))
print("party submenu row:", tapAt(700, 940))
