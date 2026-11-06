-- A QoL Toggles value honoured from a legacy key shows on its settings row.
--
-- The report: beating a trainer printed no "<PLAYER> got ¥N for winning!"
-- and the wallet did not move, while the hub's MONEY MULT row read OFF.
-- QoL Toggles reads a value from several places (qoltoggles/main.lua
-- sessionGetRaw): the row's own "qt_<key>", then the bare key the old card
-- menu wrote and the "qt_qt_<key>" 0.9.58's hub wrote. The row only reads
-- "qt_<key>", so a MONEY MULT = 0x left under a legacy key was in effect --
-- Battle:awardPrizeMoney is short-circuited at 0x, no money event, no
-- payout -- while the row showed the default.
--
-- Now the value in effect is copied under the row's key when the save comes
-- up, so the row shows 0X and setting it to OFF pays again.
--   luajit tests/legacy_qt_rows.lua
--   AIO_ENGINE=<engine>/src luajit tests/legacy_qt_rows.lua  (+ the payout)
local engine = os.getenv("AIO_ENGINE") or os.getenv("AIO_ENGINE_SRC")
local Prize, Battle
if engine then
  -- the real Prize / Battle, loaded before the harness stubs require
  package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path
  love = love or { graphics = setmetatable({}, { __index = function() return function() end end }),
    timer = { getTime = function() return 0 end } }
  local okP, P = pcall(require, "src.battle.gen2.Prize")
  local okB, B = pcall(require, "src.battle.gen2.Battle")
  if okP and okB then Prize, Battle = P, B end
  love = nil
end
-- a plain Game table: the MONEY MULT wrap is installed once per process,
-- behind a flag on it
HARNESS_STUBS = { ["src.battle.gen2.Prize"] = Prize, ["src.battle.gen2.Battle"] = Battle,
  ["src.core.Game"] = {} }
local H = dofile("tests/settings_overhaul/harness.lua")
local mod, OPTS = H.mod, H.OPTS
local Hub = mod._kimArenaHub
local n = 0
local function check(c, m) if not c then error("FAIL: " .. m, 2) end n = n + 1 end

local game = { stack = { states = {} }, save = { options = { modOptions = { ["crystal-aio"] = OPTS } } },
  options = {}, mods = { modOptions = { ["crystal-aio"] = OPTS } } }
game.stack.push = function(_, page) game.stack.states[#game.stack.states + 1] = page end
local G = require("src.core.Game")
rawset(G, "mods", game.mods); rawset(G, "save", game.save); rawset(G, "options", game.options)
local LIVE = H.Runtime._qolTogglesLive
check(LIVE and LIVE.get, "QoL Toggles is live")

local function rows(id)
  game.stack.states = {}
  local p = Hub.openSection(game, id)
  local byLabel = {}
  for _, r in ipairs(p.rows) do if r.label then byLabel[r.label] = r end end
  return byLabel
end
local function val(r) return type(r.value) == "function" and r.value() or r.value end
local function ready() for _, fn in ipairs(H.listeners["game.ready"] or {}) do fn({ game = game }) end end

-- what a 0.9.58 player who once picked 0X left behind; the new row never
-- touched, and an old EXP x2 `true` under the bare key
OPTS.qt_qt_money_mult = "0"
OPTS.exp_mult = true
-- a legacy INFINITE REPEL: the host's REPELS row owns that one
OPTS.repel = true
ready()

check(LIVE.get("money_mult") == 0, "the legacy 0x is still the value in effect")
local g = rows("gameplay")
check(g["MONEY MULT"], "MONEY MULT row")
check(val(g["MONEY MULT"]) == "0X", "the row shows the 0x in effect: " .. tostring(val(g["MONEY MULT"])))
check(OPTS.qt_money_mult == "0", "stored under the row's key in its own code")
check(val(g["EXP MULT"]) == "2X", "legacy EXP x2 shows as 2X: " .. tostring(val(g["EXP MULT"])))
check(OPTS.qt_exp_mult == "2" and LIVE.get("exp_mult") == 2, "and stays 2x")
check(OPTS.qt_repel == nil, "a key the host holds is not copied")

-- the player sees 0X and steps the row round to OFF: that is what is read
local row = g["MONEY MULT"]
row.step(game, 1)   -- 1.0.0: 0X is the cycle's last entry, so one step wraps to OFF
check(OPTS.qt_money_mult == "off", "stepped to OFF: " .. tostring(OPTS.qt_money_mult))
check(LIVE.get("money_mult") == false, "OFF is in effect, over the legacy key")
-- and from OFF the first step is 1.5X, not 0X (no stray tap stops prizes)
row.step(game, 1)
check(OPTS.qt_money_mult == "1.5", "OFF steps to 1.5X first: " .. tostring(OPTS.qt_money_mult))
row.step(game, -1)
check(OPTS.qt_money_mult == "off", "and back to OFF")

if Battle and Prize then
  -- the trainer-win payout through the engine's own Battle:awardPrizeMoney,
  -- with QoL Toggles' MONEY MULT wrap installed on it
  local function win()
    local save = { player = { name = "GOLD", money = 1000 } }
    local b = setmetatable({ save = save, events = {}, amuletCoin = false,
      trainer = { name = "YOUNGSTER JOEY", baseMoney = 4 },
      enemyParty = { { level = 5 } } }, { __index = Battle })
    b:awardPrizeMoney()
    local text
    for _, e in ipairs(b.events) do if e.kind == "money" then text = e.text end end
    return save.player.money, text
  end
  local money, text = win()
  check(money == 1080 and text and text:find("for winning", 1, true), "OFF pays ¥80 with its line")
  row.step(game, -1)   -- 0X is now OFF's step backwards (the cycle's end)
  check(OPTS.qt_money_mult == "0" and LIVE.get("money_mult") == 0, "0X again")
  money, text = win()
  check(money == 1000 and text == nil, "0x: no prize and no line (the setting's own behaviour)")
  row.step(game, 1)
else
  print("legacy qt rows: payout part SKIPPED (set AIO_ENGINE to the engine's src root)")
end

print(("legacy qt rows: %d checks ok"):format(n))
