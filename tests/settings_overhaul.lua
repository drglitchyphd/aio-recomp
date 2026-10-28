-- 0.9.66 settings overhaul: merged rows, removed toggles, dependent rows
-- hiding, NEXT LAUNCH marks, Wilds writes and PERFECT DVS.
-- Run from the repo root: luajit tests/settings_overhaul.lua
local H = dofile("tests/settings_overhaul/harness.lua")
local mod, OPTS = H.mod, H.OPTS
local Hub = mod._kimArenaHub
local game = { stack = { states = {} }, save = { options = { modOptions = { ["gen2-aio"] = OPTS } } },
  options = {}, mods = { modOptions = { ["gen2-aio"] = OPTS } } }
game.stack.push = function(_, page) game.stack.states[#game.stack.states + 1] = page end
local function page(id)
  game.stack.states = {}
  local p = Hub.openSection(game, id)
  local byLabel = {}
  for _, r in ipairs(p.rows) do if r.label then byLabel[r.label] = r end end
  return p, byLabel
end
local function val(r) return type(r.value) == "function" and r.value() or r.value end
local n = 0
local function check(c, m) if not c then error("FAIL: " .. m, 2) end n = n + 1 end
local G = require("src.core.Game")
rawset(G, "mods", game.mods); rawset(G, "save", game.save); rawset(G, "options", game.options)
local LIVE = H.Runtime._qolTogglesLive
-- REPELS
local _, q = page("qol")
check(val(q.REPELS) == "ASK", "repels default ask")
check(mod.options:get("repels") == "ask", "derived get")
q.REPELS.step(game, 1)
check(OPTS.repels == "auto", "repels stored auto: " .. tostring(OPTS.repels))
if LIVE then
  check(LIVE.get("auto_repel") == true and LIVE.get("repel") == false, "auto")
end
q.REPELS.step(game, 1)
if LIVE then check(LIVE.get("repel") == true and LIVE.get("auto_repel") == false, "infinite") end
local qol = mod.exports.qol
check(qol.optionValue("interact_qol_repel_prompt") == true, "prompt on unless OFF")
q.REPELS.step(game, 1)
check(OPTS.repels == "off", "off")
check(qol.optionValue("interact_qol_repel_prompt") == false, "prompt off at OFF")
check(qol.optionValue("rematch_scale") == false, "match levels held off")
-- quick ship / bulk coins
if LIVE then
  OPTS.qt_quick_ssanne = true; OPTS.qt_bulk_coins = true
  check(LIVE.get("quick_ssanne") == false and LIVE.get("bulk_coins") == false, "removed toggles off")
  OPTS.qt_exp_mult = "off"; check(LIVE.get("exp_mult") == false, "exp mult off decoded: " .. tostring(LIVE.get("exp_mult")))
  OPTS.qt_exp_mult = "2"; check(LIVE.get("exp_mult") == 2, "exp mult 2 decoded: " .. tostring(LIVE.get("exp_mult")))
  check(LIVE.get("unlimited_tms") == false, "tms default off")
end
-- ANIMATED SPRITES
local _, u = page("ui")
check(val(u["ANIMATED SPRITES"]) == "ON", "anim on")
u["ANIMATED SPRITES"].step(game, 1)
check(mod.options:get("animate") == true and mod.options:get("spriteAnimation") == false, "battle only")
u["ANIMATED SPRITES"].step(game, 1)
check(mod.options:get("animate") == false, "off")
OPTS.spriteAnim = nil; OPTS.animate = false
check(mod.options:get("spriteAnim") == "off", "migrates old ANIMATION OFF")
OPTS.animate = nil
-- native HUD rows
local _, b = page("battle")
check(b["HUD COLOR"] == nil and b["EXP BAR"] == nil, "native rows hidden at MODERN")
b["BATTLE HUD"].step(game, 1)
local p2, b2 = page("battle")
check(b2["HUD COLOR"] ~= nil and b2["EXP BAR"] ~= nil and b2["POKéDEX INDICATOR"] ~= nil, "native rows shown")
-- live refresh keeps cursor
game.stack.states = {}
local bp = Hub.openSection(game, "battle")
for i, r in ipairs(bp.view) do if r.label == "BATTLE HUD" then bp.index = i end end
bp.view[bp.index].step(game, 1)
check(bp.view[bp.index].label == "BATTLE HUD", "cursor stays on the changed row")
check(#bp.rows < #p2.rows, "page rebuilt without the native rows")
-- qol sprint master hides its rows
local _, q2 = page("qol")
check(q2["SPRINT SPEED"] ~= nil, "sprint rows shown")
q2.SPRINT.step(game, 1)
local _, q3 = page("qol")
check(q3["SPRINT SPEED"] == nil and q3["BIKE SPEED"] ~= nil, "sprint rows hidden, bike stays")
-- load switch marker
local _, w = page("wilds")
check(val(w["WILDS OF KANTO"]) == "ON", "switch plain")
w["WILDS OF KANTO"].step(game, 1)
local _, w2 = page("wilds")
check(val(w2["WILDS OF KANTO"]) == "OFF (NEXT LAUNCH)", "switch marked: " .. tostring(val(w2["WILDS OF KANTO"])))
check(w2["WILDS OF KANTO"].help:find("next time"), "switch help")
-- weather dependents
local _, o = page("world")
o.WEATHER.step(game, -1)
local _, o2 = page("world")
check(o2["RANDOM RAIN"] == nil, "weather rows hide at OFF")
-- Wilds rows write through Wilds' own setter
check(type(mod.exports.wilds.setOption) == "function", "wilds setter exported")
local _, wl = page("wilds")
local before = val(wl["TOWN POKEMON"])
wl["TOWN POKEMON"].step(game, 1)
local _, wl2 = page("wilds")
check(val(wl2["TOWN POKEMON"]) ~= before, "wilds row changed: " .. tostring(before) .. " -> " .. tostring(val(wl2["TOWN POKEMON"])))
-- PERFECT DVS keeps shiny / gender / Unown
local Mon = require("src.battle.gen2.Mon")
rawset(Mon, "vanillaShiny", function(d) return d.speed == 10 and d.defense == 10 and d.special == 10 and (d.attack % 4 == 2 or d.attack % 4 == 3) end)
rawset(Mon, "gender", function(def, d) if def.genderRatio == "f50" then return d.attack < 8 and "female" or "male" end return "male" end)
local qt = mod.exports.qolToggles
local s = qt.perfectDVSet({ species = "X", dvs = { attack = 3, defense = 10, speed = 10, special = 10 } }, { genderRatio = "f50" })
check(s.defense == 10 and s.speed == 10 and s.special == 10 and s.attack == 7, "shiny female: " .. s.attack)
local s2 = qt.perfectDVSet({ species = "X", dvs = { attack = 9, defense = 1, speed = 2, special = 3 } }, { genderRatio = "f50" })
check(s2.attack == 15 and s2.defense == 15 and s2.hp == 15, "male maxed")
local s3 = qt.perfectDVSet({ species = "X", dvs = { attack = 2, defense = 1, speed = 2, special = 3 } }, { genderRatio = "f50" })
check(s3.attack == 7 and s3.defense == 15, "female keeps gender: " .. s3.attack)
local u = { attack = 4, defense = 2, speed = 6, special = 0 }
local s4 = qt.perfectDVSet({ species = "UNOWN", dvs = u }, {})
local function mid(x) return math.floor(x / 2) % 4 end
check(mid(s4.attack) == mid(4) and mid(s4.defense) == mid(2) and mid(s4.speed) == mid(6) and mid(s4.special) == 0, "unown letter kept")
check(s4.attack >= 9 and s4.defense >= 9, "unown raised")
-- every row lands on a named page: nothing falls through to ADVANCED
local _, adv = page("advanced")
local known = { PERFORMANCE = 1, ["VOXEL PRECACHE"] = 1, ["VOXEL DISK CACHE"] = 1,
  ["ASSET MANAGER"] = 1, DIAGNOSTICS = 1, ["MOD LIST"] = 1, ["SETUP WIZARD ON NEW GAME"] = 1 }
for label in pairs(adv) do check(known[label], "unplaced row on ADVANCED: " .. label) end
local _, root = (function() game.stack.states = {}; local r = Hub.open(game); local m = {}
  for _, x in ipairs(r.rows) do m[x.label] = x end; return r, m end)()
check(root.GAMEPLAY and root["NUZLOCKE & RULES"] and root.ADVANCED and not root["QOL TOGGLES"], "nine pages")
print(("settings overhaul: %d checks PASS"):format(n))
