-- 0.9.67 SETUP WIZARD: profiles, step by step, editing from REVIEW, FINISH
-- applying the presets (and nothing before it), Nuzlocke pre-game rules and
-- the title screen's NEW GAME flow.
-- Run from the repo root: luajit tests/setup_wizard.lua
local chosen = {}
local MainMenu = { choose = function(self, value) chosen[#chosen + 1] = value end }
HARNESS_STUBS = { ["src.ui.gen2.MainMenu"] = MainMenu }
local H = dofile("tests/settings_overhaul/harness.lua")
local mod, OPTS = H.mod, H.OPTS
local Hub, Wizard = mod._kimArenaHub, mod._kimArenaWizard
local n = 0
local function check(c, m) if not c then error("FAIL: " .. m, 2) end n = n + 1 end
check(Wizard ~= nil, "wizard installed")

local game = { save = { options = { modOptions = { ["crystal-aio"] = OPTS } } }, options = {},
  mods = { modOptions = { ["crystal-aio"] = OPTS } } }
game.stack = { states = {} }
function game.stack:push(p) self.states[#self.states + 1] = p end
function game.stack:pop() self.states[#self.states] = nil end
local G = require("src.core.Game")
rawset(G, "mods", game.mods); rawset(G, "save", game.save); rawset(G, "options", game.options)

local function top() return game.stack.states[#game.stack.states] end
local function row(label)
  for _, r in ipairs(top().rows) do if r.label == label then return r end end
  error("no row " .. label .. " on " .. tostring(top().title), 2)
end
local function val(r) return type(r.value) == "function" and r.value() or r.value end
local function labels()
  local out = {}
  for _, r in ipairs(top().rows) do out[#out + 1] = r.label end
  return table.concat(out, ",")
end

-- root page has SETUP WIZARD first
Hub.open(game)
check(top().rows[1].label == "SETUP WIZARD", "SETUP WIZARD heads CRYSTAL-AIO")
game.stack.states = {}

-- profile -> REVIEW, nothing applied until APPLY
Wizard.open(game)
check(top().title == "SETUP WIZARD", "first page")
check(labels():find("RECOMMENDED,CASUAL,NUZLOCKE,HARDCORE NUZLOCKE,CLASSIC CRYSTAL,STEP BY STEP", 1, true),
  "profiles then STEP BY STEP: " .. labels())
check(not labels():find("SKIP"), "no SKIP outside NEW GAME")
row("CASUAL").activate(game)
check(top().title == "REVIEW", "profile opens REVIEW")
check(val(row("DIFFICULTY")) == "EASY" and val(row("CONVENIENCE")) == "MAXIMUM", "REVIEW shows the picks")
check(val(row("LOOK")):sub(1, 4) == "KEEP", "a profile leaves LOOK alone: " .. val(row("LOOK")))
check(OPTS.trainerLevels == nil, "nothing applied before APPLY")
-- change one answer from REVIEW
row("DIFFICULTY").activate(game)
check(top().title == "DIFFICULTY", "step page from REVIEW")
check(val(row("EASY")) == "CHOSEN" and val(row("NORMAL")) == "SUGGESTED", "step marks chosen / suggested")
row("HARD").activate(game)
check(top().title == "REVIEW" and val(row("DIFFICULTY")) == "HARD", "back on REVIEW with the new answer")
row("APPLY").activate(game)
check(#game.stack.states == 0, "wizard pages closed")
check(OPTS.trainerLevels == "match2" and OPTS.qt_exp_mult == "off", "HARD applied")
check(OPTS.repels == "auto" and OPTS.qt_quick_nurse == true and OPTS.qt_unlimited_tms == true,
  "MAXIMUM conveniences applied")
check(H.Runtime._qolTogglesLive.get("unlimited_tms") == true, "QoL Toggles reads REUSABLE TMS on")
check(mod.exports.qol.optionValue("sprint_enabled") == true, "SPRINT through QOL's store")
check(OPTS.battleSprites == true and OPTS.arenaBackground == "kim_hd", "HD battles applied")
-- the current settings now read as those choices
Wizard.open(game)
row("STEP BY STEP").activate(game)
check(top().title == "DIFFICULTY" and top().kimSubtitle:find("STEP 1 OF"), "step by step starts at 1")
check(val(row("HARD")) == "CURRENT", "current settings recognised")
row("KEEP AS IS").activate(game)
check(top().title == "NUZLOCKE", "KEEP AS IS moves on")
-- walk the rest choosing the first option of each, then APPLY
local guard = 0
while top().title ~= "REVIEW" and guard < 10 do
  top().rows[1].activate(game); guard = guard + 1
end
check(top().title == "REVIEW", "steps end on REVIEW")
check(val(row("DIFFICULTY")):sub(1, 4) == "KEEP", "kept step reads KEEP")
row("APPLY").activate(game)
check(OPTS.trainerLevels == "match2", "KEEP left difficulty alone")
check(OPTS.qt_quick_nurse == false and OPTS.repels == "off", "CONVENIENCE CLASSIC applied")
check(mod.exports.qol.optionValue("sprint_enabled") == false, "CLASSIC turns SPRINT off")
check(OPTS.gen2UiTheme == "gen2_aio:crystal", "LOOK CRYSTAL applied")

-- B out of the wizard changes nothing
local before = OPTS.trainerLevels
Wizard.open(game); row("CASUAL").activate(game)
game.stack.states = {}
check(OPTS.trainerLevels == before, "leaving without APPLY changes nothing")

-- NEW GAME on the title screen
local nz = mod.exports.nuzlocke
local menu = { game = game }
setmetatable(menu, { __index = MainMenu })
chosen = {}
MainMenu.choose(menu, "new")
check(#chosen == 0 and top().title == "SETUP WIZARD", "NEW GAME opens the wizard first")
check(labels():find("SKIP", 1, true), "SKIP offered at NEW GAME")
row("NUZLOCKE").activate(game)
check(val(row("NUZLOCKE")) == "NUZLOCKE", "NUZLOCKE profile picks the rules")
row("START GAME").activate(game)
check(chosen[1] == "new" and #game.stack.states == 0, "START GAME starts the game")
if nz and nz.getRuleFor then
  check(nz.getRuleFor("nuzlocke_enabled", true) == true and nz.getRuleFor("locke_type", true) == 1,
    "Nuzlocke preset staged for the new run")
end
-- SKIP starts the game untouched; OPTION / CONTINUE are not intercepted
chosen = {}
MainMenu.choose(menu, "new"); row("SKIP").activate(game)
check(chosen[1] == "new", "SKIP starts the game")
chosen = {}
MainMenu.choose(menu, "continue")
check(chosen[1] == "continue", "CONTINUE untouched")
-- setting off: straight into the game
OPTS.setupWizard = false
chosen = {}
MainMenu.choose(menu, "new")
check(chosen[1] == "new" and #game.stack.states == 0, "SETUP WIZARD ON NEW GAME off")
OPTS.setupWizard = nil
-- Nuzlocke OFF for the new run
MainMenu.choose(menu, "new"); row("RECOMMENDED").activate(game); row("START GAME").activate(game)
if nz and nz.getRuleFor then
  check(nz.getRuleFor("nuzlocke_enabled", true) == false, "RECOMMENDED starts without Nuzlocke")
end
-- 0.9.68: no separate Nuzlocke SETUP row on the title menu
local items = H.Runtime.call("ui.title_menu.items", function(_, it) return it end, game,
  { { label = "CONTINUE", value = "continue" }, { label = "NEW GAME", value = "new" },
    { label = "OPTION", value = "option" } })
local names = {}
for _, it in ipairs(items) do names[#names + 1] = it.label end
check(not table.concat(names, ","):find("SETUP"), "title menu has no SETUP row: " .. table.concat(names, ","))
print(("setup wizard: %d checks PASS"):format(n))
