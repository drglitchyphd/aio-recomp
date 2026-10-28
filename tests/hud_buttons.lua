-- HUD BUTTONS editor, QUICK HEAL and FLY / DIG / ROPE (lib/gen2_aio/quick_menu.lua).
-- Run from the repo root: luajit tests/hud_buttons.lua
local count = 0
local function check(v, msg) assert(v, msg); count = count + 1 end

love = { timer = { getTime = function() return 0 end }, graphics = setmetatable({}, { __index = function() return function() end end }) }
local IE = {
  HEAL_HP = { POTION = 20, SUPER_POTION = 50, HYPER_POTION = 200, MAX_POTION = 999, ENERGYPOWDER = 50 },
  HEAL_STATUS = { ANTIDOTE = "psn", PARLYZ_HEAL = "par", FULL_HEAL = "all", HEAL_POWDER = "all" },
  REVIVE = { REVIVE = "half", MAX_REVIVE = "full" },
}
function IE.useOnMon(id, mon)
  if IE.REVIVE[id] then
    if mon.hp > 0 then return { used = false } end
    mon.hp = IE.REVIVE[id] == "half" and math.floor(mon.maxHp / 2) or mon.maxHp
    return { used = true }
  elseif IE.HEAL_STATUS[id] then
    if not mon.status then return { used = false } end
    mon.status = nil; return { used = true }
  elseif IE.HEAL_HP[id] then
    if mon.hp <= 0 or mon.hp >= mon.maxHp then return { used = false } end
    mon.hp = math.min(mon.maxHp, mon.hp + IE.HEAL_HP[id]); return { used = true }
  end
  return { used = false }
end
local env, ctxEscape, fliers, diggers = "ROUTE", false, true, false
package.preload["src.core.gen2.ItemEffects"] = function() return IE end
package.preload["src.ui.gen2.StartMenu"] = function()
  return { availability = function() return { pokegear = true, pokedex = true } end }
end
package.preload["src.world.gen2.FieldMoves"] = function()
  return { partyMoveUser = function(_, move)
    if move == "FLY" and fliers then return { name = "PIDGEOTTO" } end
    if move == "DIG" and diggers then return { name = "DIGLETT" } end
  end }
end

local said, pushed, used, escaped = nil, nil, {}, false
local prices = { POTION = 300, SUPER_POTION = 700, HYPER_POTION = 1200, MAX_POTION = 2500,
  ANTIDOTE = 100, PARLYZ_HEAL = 200, FULL_HEAL = 600, REVIVE = 1500, MAX_REVIVE = 4000,
  ENERGYPOWDER = 500, HEAL_POWDER = 450 }
local items = {}
for id, p in pairs(prices) do items[id] = { price = p, name = id } end
local game = {
  data = { items = items },
  save = { inventory = {}, party = {} },
  mods = { modOptions = {} },
  options = {},
  world = {
    fieldContext = function() return { environment = env, canEscapeRope = ctxEscape } end,
    useFieldMove = function(_, m) used[#used + 1] = m; return { ok = true } end,
    useEscapeRope = function() escaped = true end,
  },
  say = function(_, t) said = t end,
  consumeItem = function(self, id) self.save.inventory[id] = self.save.inventory[id] - 1 end,
  pushStartMenuItem = function(_, id) pushed = id end,
}
local mod = { id = "gen2-aio", exports = {}, hooks = { wrap = function() end } }
mod._kimArenaOpt = function(k, d)
  local b = game.mods.modOptions["gen2-aio"]
  if b and b[k] ~= nil then return b[k] end
  return d
end
local q = assert(loadfile("lib/gen2_aio/quick_menu.lua"))()({ mod = mod })

local function ids()
  local out = {}
  for _, a in ipairs(q.hudActions(game)) do out[#out + 1] = a.id end
  return table.concat(out, ",")
end

-- defaults: GEAR, AREA (BIKE / ITEMS need the items)
check(ids() == "gear,dex", "default HUD is GEAR, AREA without a bike or key items")
q.setHudPlace(game, "heal", 1)
check(table.concat(q.hudOrder(), ",") == "heal,gear,dex,bike,items", "editor inserts at a place")
check(game.options.modOptions["gen2-aio"].hudButtons == "heal,gear,dex,bike,items", "editor persists to options")
check(ids() == "gear,dex", "QUICK HEAL hidden while the party is healthy")
q.setHudPlace(game, "gear", nil)
check(table.concat(q.hudOrder(), ",") == "heal,dex,bike,items", "editor removes a button")
q.setHudPlace(game, "pokedex", 2); q.setHudPlace(game, "travel", 9)
check(table.concat(q.hudOrder(), ",") == "heal,pokedex,dex,bike,items,travel", "places clamp to the row")
q.setHudPlace(game, "quick", 3)
check(#q.hudOrder() == 6, "row holds at most six buttons")

-- FLY / DIG / ROPE
env, fliers = "ROUTE", true
local label = q.travelAction(game); check(label == "FLY", "outdoors with a flier: FLY")
fliers = false; check(q.travelAction(game) == nil, "outdoors without FLY: hidden")
env, ctxEscape, diggers = "CAVE", true, true
local l2, run2 = q.travelAction(game); check(l2 == "DIG", "cave with a digger: DIG"); run2(game)
check(#used == 1, "DIG uses the field move")
diggers = false; game.save.inventory.ESCAPE_ROPE = 1
local l3, run3 = q.travelAction(game); check(l3 == "ROPE", "cave, no digger, rope in bag: ROPE"); run3(game)
check(escaped, "ROPE uses the engine's escape rope")
ctxEscape = false; check(q.travelAction(game) == nil, "nowhere to escape to: hidden")
env = "INDOOR"; check(q.travelAction(game) == nil, "indoors: hidden")

-- QUICK HEAL
local inv = game.save.inventory
inv.POTION, inv.SUPER_POTION, inv.HYPER_POTION, inv.ENERGYPOWDER = 5, 2, 1, 9
inv.ANTIDOTE, inv.FULL_HEAL, inv.HEAL_POWDER, inv.REVIVE = 1, 1, 9, 1
game.save.party = {
  { hp = 30, maxHp = 45 },                    -- missing 15: one POTION covers it
  { hp = 10, maxHp = 60 },                    -- missing 50: SUPER covers (cheaper than HYPER)
  { hp = 0, maxHp = 40 },                     -- fainted: REVIVE to 20, then POTION covers 20
  { hp = 20, maxHp = 20, status = "psn" },    -- ANTIDOTE, not FULL_HEAL
  { hp = 20, maxHp = 20, status = "par" },    -- no PARLYZ: FULL_HEAL, never HEAL_POWDER
  { hp = 50, maxHp = 50 },                    -- healthy: untouched
}
check(ids():find("heal") ~= nil, "QUICK HEAL shows when someone needs care")
q.quickHeal(game)
local p = game.save.party
check(p[1].hp == 45 and p[2].hp == 60 and p[3].hp == 40, "everyone topped up")
check(not p[4].status and not p[5].status, "statuses cured")
check(inv.POTION == 3 and inv.SUPER_POTION == 1 and inv.HYPER_POTION == 1, "cheapest covering potions used")
check(inv.REVIVE == 0 and inv.ANTIDOTE == 0 and inv.FULL_HEAL == 0, "revive and matching cures used")
check(inv.ENERGYPOWDER == 9 and inv.HEAL_POWDER == 9, "bitter herbs never used")
check(said and said:find("Used") ~= nil, "result message shown")
q.quickHeal(game)
check(said:find("already healthy") ~= nil, "healthy party reports so")
print(("HUD buttons, quick heal and travel: %d checks PASS"):format(count))
