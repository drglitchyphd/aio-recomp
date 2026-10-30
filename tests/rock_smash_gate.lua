-- FIELD MOVES ALL and Gold's TM field moves (qoltoggles/main.lua).
--
-- Crystal smashes a rock only for a party mon that KNOWS ROCK SMASH (TM08).
-- FIELD MOVES ALL lends a field move to a species that can learn it; for a
-- TM-only field move that loan now needs the TM in the bag, so ROCK SMASH no
-- longer works before Route 36 hands out TM08.  A mon that knows the move,
-- or a species that learns it by level-up, is never gated; the HM rules
-- (HM ITEM REQUIRED, badges) are unchanged.
--   luajit tests/rock_smash_gate.lua
local function U(name)
  return setmetatable({}, {
    __index = function(s, k) local v = U(name .. "." .. tostring(k)); rawset(s, k, v); return v end,
    __call = function() return U(name .. "()") end,
    __concat = function(a, b) return tostring(a) .. tostring(b) end,
    __tostring = function() return name end,
  })
end
love = U("love")
local opts = { qt_field_moves_all = true, qt_badgeless_moves = false, qt_hm_item_required = true }
local stubs = {
  ["src.mods.Runtime"] = { wants = function() return false end, emit = function() end },
  ["src.core.Game"] = { save = { party = {} }, mods = {} },
  ["src.core.GameVersion"] = { generation = function() return 2 end, get = function() return "crystal" end },
  ["src.world.gen2.FieldMoves"] = {
    BADGE = { CUT = "HIVE" },
    hasBadge = function(save, badge) return save.player.badges[badge] == true end,
  },
}
local realRequire = require
require = function(n) if stubs[n] then return stubs[n] end; local v = U(n); stubs[n] = v; return v end
local wraps = {}
local mod = { exports = {}, generation = 2, id = "crystal-aio",
  events = { on = function() end, once = function() end, emit = function() end },
  hooks = { wrap = function(_, name, fn) wraps[name] = fn end },
  options = { get = function(_, k) return opts["qt_" .. k] end, define = function() end },
  content = U("content"), log = U("log"), find = function() return nil end,
  read = function() return nil end }
local entry = assert(loadfile("qoltoggles/main.lua"))()
assert(pcall(entry, mod))
package.loaded["src.world.gen2.FieldMoves"] = stubs["src.world.gen2.FieldMoves"]
require = realRequire

local n = 0
local function check(c, m) if not c then error("FAIL: " .. m, 2) end n = n + 1 end
local eligibility = wraps["fieldmove.eligibility"]
check(type(eligibility) == "function", "fieldmove.eligibility is wrapped")

local data = { pokemon = {
  QUILAVA = { tmhm = { "ROCK_SMASH", "CUT", "DIG" } },
  GEODUDE = { learnset = { { level = 1, move = "TACKLE" } }, tmhm = { "ROCK_SMASH" } },
  MANKEY = { learnset = { { level = 1, move = "ROCK_SMASH" } } },
} }
local function vanilla() return nil end
local function ask(moveId, party, inventory, badges)
  local save = { party = party, inventory = inventory or {},
    player = { badges = badges or {} } }
  return eligibility(vanilla, moveId, { save = save, data = data, party = party, moveId = moveId })
end
local kimchi = { species = "QUILAVA", nickname = "KIMCHI", moves = { { id = "EMBER" } } }

-- the report: no TM08, no mon knowing it -> no ROCK SMASH
check(ask("ROCK_SMASH", { kimchi }) == nil, "no TM08: a TM learner cannot smash")
check(ask("ROCK_SMASH", { kimchi }, { TM_ROCK_SMASH = 0 }) == nil, "a zero count is not holding it")
check(ask("ROCK_SMASH", { kimchi }, { TM_ROCK_SMASH = 1 }) == kimchi, "TM08 in the bag lends it")
-- knowing the move always works, FIELD MOVES ALL on or off
local smasher = { species = "GEODUDE", moves = { { id = "ROCK_SMASH" } } }
check(ask("ROCK_SMASH", { kimchi, smasher }) == smasher, "a mon that knows it smashes")
-- a level-up learner is not a TM loan
local mankey = { species = "MANKEY", moves = { { id = "SCRATCH" } } }
check(ask("ROCK_SMASH", { mankey }) == mankey, "a level-up learner is not gated on the TM")
-- DIG is TM28 on Gold: same gate
check(ask("DIG", { kimchi }) == nil, "DIG without TM28")
check(ask("DIG", { kimchi }, { TM_DIG = 1 }) == kimchi, "DIG with TM28")
-- HMs keep their own rules: item (HM ITEM REQUIRED) and badge
check(ask("CUT", { kimchi }, {}, { HIVE = true }) == nil, "CUT needs HM01 while HM ITEM REQUIRED")
check(ask("CUT", { kimchi }, { HM_CUT = 1 }, {}) == nil, "CUT needs the HIVEBADGE")
check(ask("CUT", { kimchi }, { HM_CUT = 1 }, { HIVE = true }) == kimchi, "CUT with HM01 and badge")
opts.qt_hm_item_required = false
check(ask("CUT", { kimchi }, {}, { HIVE = true }) == kimchi, "HM ITEM REQUIRED off drops the HM item gate")
check(ask("ROCK_SMASH", { kimchi }) == nil, "...but never the TM gate")
opts.qt_hm_item_required = true

-- the party menu's phantom rows follow the same rule
local function has(list, id) for _, v in ipairs(list) do if v == id then return true end end end
local rows = mod.exports.learnableFieldMoves(data.pokemon.QUILAVA, kimchi, {}, true)
check(not has(rows, "ROCK_SMASH") and not has(rows, "DIG"), "no phantom TM rows without the TMs")
rows = mod.exports.learnableFieldMoves(data.pokemon.QUILAVA, kimchi, { TM_ROCK_SMASH = 1 }, true)
check(has(rows, "ROCK_SMASH") and not has(rows, "DIG"), "ROCK SMASH row once TM08 is held")

print(("rock smash gate: %d checks ok"):format(n))
