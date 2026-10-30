-- 0.9.70: the touch Poke Ball button in wild battles (touch/main.lua) and
-- the quick ball it throws (lib/crystal_aio/quick_ball.lua).
-- Run from the repo root: luajit tests/quick_ball_button.lua
local n = 0
local function check(c, m) if not c then error("FAIL: " .. m, 2) end n = n + 1 end
local T = 100
love = { timer = { getTime = function() return T end },
  graphics = { getDimensions = function() return 1080, 2520 end, push = function() end,
    pop = function() end, origin = function() end },
  system = { getOS = function() return "Android" end } }

-- ---- quick_ball.lua on a stand-in BattleState
local thrown, refused, updated = nil, nil, 0
local BS = {}
BS.__index = BS
function BS.update() updated = updated + 1 end
function BS:useItem(id) thrown = id end
function BS:refuseMenu(text) refused = text end
package.preload["src.ui.gen2.BattleState"] = function() return BS end
local store = {}
local battle = setmetatable({ phase = "menu", slideFrame = 80, battle = { wild = true },
  save = { inventory = { POKE_BALL = 5, ULTRA_BALL = 2 } },
  game = { data = { items = { POKE_BALL = { pocket = "BALL" }, ULTRA_BALL = { pocket = "BALL" },
    MASTER_BALL = { pocket = "BALL" } } }, input = { wasPressed = function() return false end } } }, BS)
local game = { stack = { top = function() return battle end } }
local host = { exports = {}, save = { get = function(_, k) return store[k] end,
  set = function(_, k, v) store[k] = v end } }
host._kantoInMotionActiveGame = function() return game end
assert(loadfile("lib/crystal_aio/quick_ball.lua"))()({ mod = host })

check(host._kimArenaQuickBallReady() == true, "ready in a wild battle's command menu")
local info = host._kimArenaQuickBallInfo()
check(info.id == "ULTRA_BALL" and info.count == 2, "best ball first, with its count")
check(host._kimArenaQuickBallThrow() == true, "a tap queues a throw")
BS.update(battle)
check(thrown == "ULTRA_BALL" and updated == 0, "the throw happens on the battle's update")
thrown = nil; BS.update(battle)
check(thrown == nil and updated == 1, "one tap, one throw")
battle.save.inventory = { MASTER_BALL = 1 }
check(host._kimArenaQuickBallInfo().id == nil, "never the MASTER BALL")
host._kimArenaQuickBallThrow(); BS.update(battle)
check(refused and refused:find("MASTER"), "says to throw the MASTER BALL from the PACK")
battle.save.inventory = { POKE_BALL = 3 }
battle.battle.wild = false
check(host._kimArenaQuickBallReady() == false and host._kimArenaQuickBallThrow() == false,
  "not in a trainer battle")
battle.battle.wild = true; battle.phase = "moves"
check(host._kimArenaQuickBallReady() == false, "not in the move list")
battle.phase = "menu"; battle.slideFrame = 10
check(host._kimArenaQuickBallReady() == false, "not before the battle's intro slide ends")
battle.slideFrame = 80
-- a relaunch in the same Lua state rebinds the session's hooks
local host2 = { exports = {}, save = host.save, _kantoInMotionActiveGame = host._kantoInMotionActiveGame }
assert(loadfile("lib/crystal_aio/quick_ball.lua"))()({ mod = host2 })
check(type(host2._kimArenaQuickBallThrow) == "function" and host2._kimArenaQuickBallReady(),
  "second session gets its own hooks")

-- ---- KIM Touch's button
package.preload["src.core.TouchControls"] = function() return { active = true, layout = function() return {} end } end
package.preload["src.core.TouchSkin"] = function() return { active = false } end
local hooks, log = {}, {}
local ready, throws = true, 0
local parent = {
  _kimArenaQuickBallReady = function() return ready end,
  _kimArenaQuickBallInfo = function() return { id = "POKE_BALL", count = 3 } end,
  _kimArenaQuickBallThrow = function() throws = throws + 1; return true end,
}
local tmod = { id = "touch", exports = {}, read = function() return nil end,
  options = { get = function() return nil end, define = function() end },
  hooks = { wrap = function(_, name, f, p) hooks[name] = hooks[name] or {}; hooks[name][p] = f end },
  input = { tap = function(_, g, b) log[#log + 1] = "tap:" .. b end,
    press = function(_, g, b) log[#log + 1] = "press:" .. b; return {} end, release = function() end },
  find = function() return { exports = {} } end }
setmetatable(tmod, { __index = parent })
assert(loadfile("touch/main.lua"))()(tmod)
local top = { isBattle = true, battle = {}, phase = "menu" }
local tgame = { stack = { top = function() return top end }, world = {}, input = {} }
local ptr = hooks["input.pointer"][10]
local shown = tmod.exports.shownButtons(tgame)
check(shown.ball and shown.b and shown.select, "ball button beside B; SELECT stays SELECT")
check(shown.ball.x < shown.b.x and math.abs(shown.ball.y - shown.b.y) < 1, "right hand: left of B")
log = {}
ptr(function() end, tgame, { phase = "pressed", x = shown.ball.x, y = shown.ball.y, id = 1, source = "touch" })
T = T + 0.1
ptr(function() end, tgame, { phase = "released", x = shown.ball.x, y = shown.ball.y, id = 1, source = "touch" })
check(throws == 1 and #log == 0, "a tap on it throws, and presses no button")
-- the player's HUD card where the ball would go: it moves above the pills
parent._kimArenaHudRects = { W = 1080, H = 2520, player = { x = shown.ball.x - 50, y = shown.ball.y - 50, w = 100, h = 100 } }
local moved = tmod.exports.shownButtons(tgame).ball
check(moved.y < shown.b.y - shown.b.r, "clear of a HUD card: above the START / SELECT pills")
parent._kimArenaHudRects = nil
ready = false
check(tmod.exports.shownButtons(tgame).ball == nil, "gone when no throw is possible")
-- 0.9.71: none of the floating buttons on the naming keyboard (they hid
-- under it and still caught its R key)
local Naming = {}; Naming.__index = Naming
package.preload["src.ui.gen2.NamingScreen"] = function() return Naming end
top = setmetatable({}, Naming)
check(next(tmod.exports.shownButtons(tgame)) == nil, "naming keyboard: no floating buttons")
log = {}
local bz = (function() top = { isBattle = true, battle = {}, phase = "menu" }; return tmod.exports.shownButtons(tgame).b end)()
top = setmetatable({}, Naming)
ptr(function() log[#log + 1] = "next" end, tgame, { phase = "pressed", x = bz.x, y = bz.y, id = 2, source = "touch" })
check(not table.concat(log, ","):find("press:b"), "naming keyboard: B's spot does not press B")
print(("quick ball button: %d checks PASS"):format(n))
