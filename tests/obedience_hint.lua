-- Obedience (lib/gen2_aio/obedience_hint.lua) on the engine's real Battle.
--
-- Crystal's CheckObedience only tests a mon whose OT ID is not the player's;
-- such a mon obeys up to Lv10 until the HIVEBADGE (the ZEPHYRBADGE does not
-- raise it).  The player's own Lv13 mon with one badge obeys; a traded one
-- (renamed through the mod's RENAME row, so it looks like the player's own)
-- disobeys, and its first refusal in a battle now says why.
--   AIO_ENGINE=<engine>/src luajit tests/obedience_hint.lua
local engine = os.getenv("AIO_ENGINE")
if not engine then print("obedience hint: SKIP (set AIO_ENGINE to the engine's src root)") return end
love = { graphics = setmetatable({}, { __index = function() return function() end end }),
  timer = { getTime = function() return 0 end }, audio = setmetatable({}, { __index = function() return function() end end }) }
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path
local Battle = require("src.battle.gen2.Battle")
local n = 0
local function check(c, m) if not c then error("FAIL: " .. m, 2) end n = n + 1 end

local factory = assert(loadfile("lib/gen2_aio/obedience_hint.lua"))
check(factory()({ mod = {} }) ~= nil, "installs on the real Battle")
-- a relaunch in the same Lua state must not wrap twice
check(factory()({ mod = {} }) ~= nil, "second session installs")

local function battle(mon, badges, roll)
  local b = setmetatable({
    save = { player = { id = 40000, name = "GOLD", badges = badges or {} } },
    player = mon, events = {},
    -- every roll misses (the re-roll fallback folds `roll` past the cap):
    -- the mon disobeys and loafs
    random = function(k) if k == 256 then return roll or 200 end return k - 1 end,
  }, { __index = Battle })
  return b
end
local function texts(b)
  local out = {}
  for _, e in ipairs(b.events) do if e.text then out[#out + 1] = e.text end end
  return out
end

-- the player's own Lv13 mon with the ZEPHYRBADGE obeys (OT ID matches)
local own = { species = "QUILAVA", nickname = "KIMCHI", level = 13, otId = 40000,
  moves = { { id = "EMBER", pp = 25 } } }
local b = battle(own, { ZEPHYR = true })
check(b:checkObedience("EMBER") == false and #b.events == 0, "own mon obeys")

-- a traded Lv13 mon with only the ZEPHYRBADGE: the cart's cap is 10
local zooter = { species = "ONIX", nickname = "ZOOTER", level = 13, otId = 1001,
  ot = "KYLE", moves = { { id = "TACKLE", pp = 35 } } }
b = battle(zooter, { ZEPHYR = true })
check(b:obedienceLevel() == 10, "ZEPHYRBADGE leaves the cap at 10")
check(b:checkObedience("TACKLE") == true, "traded Lv13 disobeys with one badge")
local lines = texts(b)
check(#lines == 2, "the refusal plus one hint (" .. #lines .. ")")
local hint = lines[#lines]
check(hint:find("ZOOTER", 1, true) and hint:find("another TRAINER", 1, true), "hint names the mon")
check(hint:find("Lv10", 1, true), "hint gives the cap")
check(hint:find("HIVEBADGE", 1, true), "hint names the next badge")
-- once per mon per battle
check(b:checkObedience("TACKLE") == true and #texts(b) == 3, "no second hint in the same battle")

-- HIVEBADGE lifts the cap to 30: the same mon obeys
b = battle(zooter, { ZEPHYR = true, HIVE = true })
check(b:checkObedience("TACKLE") == false and #b.events == 0, "HIVEBADGE: Lv13 obeys")
-- Lv35 with HIVE: hint points at the FOGBADGE
zooter.level = 35
b = battle(zooter, { ZEPHYR = true, HIVE = true }, 255)
check(b:checkObedience("TACKLE") == true, "Lv35 over the HIVE cap")
hint = texts(b)[#texts(b)]
check(hint:find("Lv30", 1, true) and hint:find("FOGBADGE", 1, true), "cap 30, next FOGBADGE")

print(("obedience hint: %d checks ok"):format(n))
