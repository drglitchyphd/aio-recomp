-- 0.9.93: the Nuzlocke catch line ("FIRST ENCOUNTER! ... joins the run.")
-- went up the moment the Poke Ball was thrown.  The engine emits
-- pokemon.caught from BattleState:pushCaught, synchronously inside useItem,
-- before the ball animation, the wobbles and "Gotcha!" are drained
-- (src/ui/gen2/BattleState.lua), and the listener pushed a TextBox over the
-- battle right then.  This throws real balls through the engine's Crystal
-- Battle + BattleState with the bundle (and its Nuzlocke) booted on top:
--   * nothing Nuzlocke shows while the ball is in the air
--   * on a catch the line is read after "Gotcha!", before the nickname prompt
--   * a ball the Pokemon breaks out of shows no capture line and records no
--     CAUGHT
--   AIO_ENGINE=<engine root> luajit tests/nuzlocke_catch_message.lua
local engine = os.getenv("AIO_ENGINE") or os.getenv("AIO_ENGINE_SRC")
if not engine then print("nuzlocke catch message: SKIP (set AIO_ENGINE to the engine root)") return end
local n = 0
local function check(c, m) if not c then error("FAIL: " .. m, 2) end n = n + 1 end

local realRequire = require
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path
love = realRequire("tests.love_stub")
local engineLove = love
local Battle = realRequire("src.battle.gen2.Battle")
local BattleState = realRequire("src.ui.gen2.BattleState")
local Input = realRequire("src.core.Input")
local Mon = realRequire("src.battle.gen2.Mon")
local Runtime = realRequire("src.mods.Runtime")
local TextBox = realRequire("src.render.TextBox")
local StateStack = realRequire("src.core.StateStack")

-- the bundle boots on its stubs; the battle screen and the text box it
-- would push are the engine's own
HARNESS_STUBS = { ["src.ui.gen2.BattleState"] = BattleState, ["src.render.TextBox"] = TextBox }
local H = dofile("tests/settings_overhaul/harness.lua")
love = engineLove
-- from here on the engine's modules resolve to themselves
setmetatable(HARNESS_STUBS, { __index = function(_, name)
  if name:match("^src%.") or name:match("^tests%.") then
    local ok, v = pcall(realRequire, name)
    if ok then return v end
  end
end })
for _, fn in ipairs(H.listeners["game.ready"] or {}) do pcall(fn, { game = {} }) end

local mod = H.mod
local store = {}
rawset(mod.save, "get", function(_, k, d) local v = store[k]; if v == nil then return d end return v end)
rawset(mod.save, "set", function(_, k, v) store[k] = v end)

-- the engine's public events reach the bundle's listeners
local emitted = {}
local vanillaEmit = Runtime.emit
Runtime.emit = function(name, payload)
  emitted[#emitted + 1] = name
  for _, fn in ipairs(H.listeners[name] or {}) do fn(payload) end
  return vanillaEmit(name, payload)
end

-- ---- ROM-free Crystal fixtures (the extractor's shapes)
local TYPES = { NORMAL = { id = "NORMAL", index = 0, category = "physical" } }
local DATA = {
  pokemon = {
    growthRates = { GROWTH_MEDIUM_FAST = { numerator = 1, denominator = 1, squared = 0, linear = 0, constant = 0 } },
    CYNDAQUIL = { id = "CYNDAQUIL", index = 155, name = "CYNDAQUIL",
      baseStats = { hp = 39, attack = 52, defense = 43, speed = 65, specialAttack = 60, specialDefense = 50 },
      types = { "NORMAL", "NORMAL" }, catchRate = 45, baseExp = 65, growthRate = "GROWTH_MEDIUM_FAST",
      genderRatio = 31, levelMoves = { { level = 1, move = "TACKLE" } }, evolutions = {} },
    PIDGEY = { id = "PIDGEY", index = 16, name = "PIDGEY",
      baseStats = { hp = 40, attack = 45, defense = 40, speed = 56, specialAttack = 35, specialDefense = 35 },
      types = { "NORMAL", "NORMAL" }, catchRate = 255, baseExp = 55, growthRate = "GROWTH_MEDIUM_FAST",
      genderRatio = 127, levelMoves = { { level = 1, move = "TACKLE" } }, evolutions = {} },
    LUGIA = { id = "LUGIA", index = 249, name = "LUGIA",
      baseStats = { hp = 106, attack = 90, defense = 130, speed = 110, specialAttack = 90, specialDefense = 154 },
      types = { "NORMAL", "NORMAL" }, catchRate = 3, baseExp = 220, growthRate = "GROWTH_MEDIUM_FAST",
      genderRatio = 255, levelMoves = { { level = 1, move = "TACKLE" } }, evolutions = {} },
  },
  moves = { TACKLE = { id = "TACKLE", name = "TACKLE", power = 35, type = "NORMAL",
    accuracy = 95, accuracyRaw = 242, pp = 35, effect = "EFFECT_NORMAL_HIT" } },
  text = realRequire("tests.gen2_battle_text_fixture")(),
  type_chart = { battleRules = realRequire("tests.gen2_battle_rules_fixture")(), types = TYPES, matchups = {} },
  items = { POKE_BALL = { id = "POKE_BALL", name = "POKé BALL", pocket = "BALL" } },
}
local perfect = { attack = 15, defense = 15, speed = 15, special = 15 }
perfect.hp = Mon.hpDV(perfect)

local function newThrow(species, roll)
  Input:init()
  local player = Mon.new(DATA, "CYNDAQUIL", 10, { dvs = perfect })
  player.moves = { { id = "TACKLE", pp = 35, maxPp = 35 } }
  local wild = Mon.new(DATA, species, 5, { dvs = perfect })
  wild.moves = { { id = "TACKLE", pp = 35, maxPp = 35 } }
  local save = { party = { player }, inventory = { POKE_BALL = 5 }, player = { name = "GOLD", map = "ROUTE_29" },
    pokedex = { seen = {}, caught = {} }, boxes = { {} } }
  local game = { data = DATA, save = save, input = Input, options = {}, world = { map = { id = "ROUTE_29" } } }
  game.stack = setmetatable({}, { __index = StateStack }); game.stack:init()
  local battle = Battle.new({ data = DATA, party = { player }, wild = wild, save = save,
    random = function(k) return roll(k) end })
  local screen = BattleState.new(game, { battle = battle, save = save })
  -- the cart's ANIM_THROW_POKE_BALL, reduced to its timing: the ball flies,
  -- GetPokeBallWobble runs once per wobble, then the script ends and the
  -- queue the throw built is drained
  screen.startBallAnim = function(self)
    local frame = 0
    self.anim = { animId = "ANIM_THROW_POKE_BALL", keepSprites = false,
      done = function() return frame >= 90 end,
      step = function()
        frame = frame + 1
        if frame % 20 == 0 then self:pokeballWobble() end
        return frame < 90
      end }
  end
  game.stack:push(screen)
  return game, screen, battle
end

local function settle(screen, game, cap)
  for _ = 1, (cap or 3000) do
    if game.stack:top() ~= screen then return end
    local waiting = (screen.messageTimer or 0) > 0
    if waiting then Input:overlayPressed("a") end
    Input:step()
    screen:update(1 / 60)
    if waiting then Input:overlayReleased("a") end
    if screen.phase == "menu" and #screen.queue == 0 and not screen.anim then return end
  end
end

-- the catch line at each world-building tier (T1 / T2 / T3)
local NUZ = { "FIRST ENCOUNTER", "joins the run", "New teammate", "officially part of" }
local function isNuz(text)
  if type(text) ~= "string" then return false end
  for _, s in ipairs(NUZ) do if text:find(s, 1, true) then return true end end
  return false
end

-- Throw, then play the battle out like a player, logging every line the
-- battle box shows and anything pushed over the battle.
local function throw(game, screen)
  local lines, over = {}, {}
  local last
  local function note()
    local top = game.stack:top()
    if top ~= screen and top and not over[top] then
      over[top] = true
      over[#over + 1] = { text = top.text or top.message or tostring(top), atLine = #lines }
    end
    if screen.message and screen.message ~= last then lines[#lines + 1] = screen.message end
    last = screen.message
  end
  screen:useItem("POKE_BALL")
  note()
  local inFlight = screen.anim ~= nil
  local overAtThrow = game.stack:top() ~= screen
  for _ = 1, 4000 do
    local top = game.stack:top()
    if top ~= screen then
      -- a text box (or the old catch line) over the battle: read it out
      Input:overlayPressed("a"); Input:step()
      if top.update then top:update(1 / 60) end
      Input:overlayReleased("a"); Input:step()
      if top.update then top:update(1 / 60) end
      note()
    else
      local waiting = (screen.messageTimer or 0) > 0
      if screen.phase == "ask-nickname" then
        -- B is the NO arm: keep the species name
        Input:overlayPressed("b"); Input:step(); screen:update(1 / 60); Input:overlayReleased("b")
      else
        if waiting then Input:overlayPressed("a") end
        Input:step()
        screen:update(1 / 60)
        if waiting then Input:overlayReleased("a") end
      end
      note()
      if screen.phase == "done" or (screen.phase == "menu" and #screen.queue == 0 and not screen.anim) then break end
      if screen.battle.over and #screen.queue == 0 and not screen.anim and (screen.messageTimer or 0) == 0
        and screen.phase ~= "ask-nickname" then break end
    end
  end
  return lines, over, inFlight, overAtThrow
end

local function indexOf(lines, pred)
  for i, l in ipairs(lines) do if pred(l) then return i end end
end

-- ---- a catch: PIDGEY (rate 255), every roll 0
do
  local game, screen = newThrow("PIDGEY", function() return 0 end)
  settle(screen, game)
  check(screen.phase == "menu", "battle reaches the command menu: " .. tostring(screen.phase))
  local lines, over, inFlight, overAtThrow = throw(game, screen)
  check(inFlight, "the ball is in the air after the throw")
  check(not overAtThrow, "nothing is pushed over the battle as the ball is thrown")
  check(#over == 0, "no text box goes up over the battle (" .. tostring(over[1] and over[1].text) .. ")")
  local gotcha = indexOf(lines, function(l) return l:find("Gotcha", 1, true) end)
  local nuz = indexOf(lines, isNuz)
  local nick = indexOf(lines, function(l) return l:find("nickname", 1, true) end)
  check(gotcha, "Gotcha! is shown: " .. table.concat(lines, " | "))
  check(nuz, "the Nuzlocke catch line is shown: " .. table.concat(lines, " | "))
  check(nuz > gotcha, "the Nuzlocke line comes after Gotcha!")
  check(nick and nuz < nick, "and before the nickname prompt")
  local states = store.encounter_states or {}
  local tracked
  for _, v in pairs(states) do tracked = v end
  check(tracked == nil or tracked.status == "CAUGHT", "the area records CAUGHT on a catch")
  check(#game.save.party == 2, "PIDGEY joined the party")
end

-- ---- a break-free: LUGIA (rate 3), every roll 255
do
  store = {}
  local game, screen = newThrow("LUGIA", function(k) return (k or 256) - 1 end)
  settle(screen, game)
  check(screen.phase == "menu", "second battle reaches the command menu")
  emitted = {}
  local lines, over = throw(game, screen)
  check(#over == 0, "no text box over the battle on a break-free")
  check(indexOf(lines, function(l) return l:find("broke free", 1, true) or l:find("Shoot", 1, true)
    or l:find("Aww", 1, true) or l:find("Aargh", 1, true) end),
    "the break-free line is shown: " .. table.concat(lines, " | "))
  check(not indexOf(lines, function(l) return l:find("Gotcha", 1, true) end), "no Gotcha! on a break-free")
  check(not indexOf(lines, isNuz), "no Nuzlocke capture line on a break-free: " .. table.concat(lines, " | "))
  for _, name in ipairs(emitted) do check(name ~= "pokemon.caught", "no pokemon.caught on a break-free") end
  for _, v in pairs(store.encounter_states or {}) do
    check(v.status ~= "CAUGHT", "a break-free never records CAUGHT")
  end
  check(#game.save.party == 1, "LUGIA did not join")
end

print(("nuzlocke catch message: %d checks ok"):format(n))
