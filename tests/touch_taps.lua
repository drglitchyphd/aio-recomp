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
-- gen2-aio 0.9.92: the Modern PACK's buttons (kind packAction): select, then
-- the cell's button unless select answered false; SORT presses nothing
local pack = { index = 1, rows = { { id = "POTION" } } }
top = pack
local picked, sorted = nil, 0
exports.screenTapTargets = function() return { state = pack, kind = "pack", time = T,
  cells = { { kind = "pack", index = 1, x = 100, y = 300, w = 800, h = 60 },
            { kind = "packAction", action = "toss", x = 100, y = 1800, w = 200, h = 80,
              select = function(s) picked = "toss"; return true end, button = "a" },
            { kind = "packAction", action = "give", x = 320, y = 1800, w = 200, h = 80,
              select = function(s) return false end, button = "a" },
            { kind = "packAction", action = "sort", x = 700, y = 200, w = 200, h = 60,
              select = function(s) sorted = sorted + 1 end, button = false } } } end
local r = tapAt(200, 1840)
print("pack TOSS button:", r)
assert(picked == "toss" and r:find("tap:a"), "TOSS: select then A")
r = tapAt(400, 1840)
print("pack refused button:", r)
assert(not r:find("tap:a"), "a refused action presses nothing")
r = tapAt(800, 230)
print("pack SORT button:", r)
assert(sorted == 1 and not r:find("tap:"), "SORT: select only")
r = tapAt(500, 330)
assert(pack.index == 1 and r:find("tap:a"), "pack row still taps A")
print("touch taps: pack buttons OK")
