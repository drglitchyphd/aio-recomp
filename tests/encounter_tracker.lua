-- 0.9.72: the Nuzlocke ENCOUNTERS page data (nuzlocke/main.lua
-- NuzlockeTrackerScreen:_aioModernData) on a booted bundle, and the area
-- name formatting fix. Run from the repo root: luajit tests/encounter_tracker.lua
local H = dofile("tests/settings_overhaul/harness.lua")
local mod = H.mod
local n = 0
local function check(c, m) if not c then error("FAIL: " .. m, 2) end n = n + 1 end
local def = mod.content.screens.registered.NuzlockeTrackerScreen
check(def and def.new, "tracker screen registered")
local store = {}
-- the Nuzlocke component keeps its per-save data under nz_ keys on mod.save
local save = mod.save
rawset(save, "get", function(_, k, d) local v = store[k]; if v == nil then return d end return v end)
rawset(save, "set", function(_, k, v) store[k] = v end)
local alive = { species = "CYNDAQUIL", nuzlockeId = "id-1" }
local dead = { species = "SENTRET", nuzlockeDead = true, nuzlockeId = "id-2" }
local game = { save = { party = { alive }, boxes = { { dead } } }, data = { pokemon = {} },
  input = { wasPressed = function() return false end }, stack = { states = {} } }
local ok, screen = pcall(def.new, game, {})
check(ok and screen, "tracker opens: " .. tostring(screen))
local okD, d = pcall(screen._aioModernData, screen)
check(okD and type(d) == "table", "data builds: " .. tostring(d))
check(d.kind == "tracker" and d.title == "ENCOUNTERS", "tracker page kind")
check(type(d.rows) == "table" and type(d.counts) == "table", "rows and totals")
check(type(d.setTab) == "function", "tabs can be switched by tap")
-- statuses: in the party, fainted (flag on the stored mon / the loss
-- history), caught in a box, failed, open
local box = { species = "GEODUDE", nuzlockeId = "id-3" }
game.save.boxes[1][2] = box
local prefix = ""
for k in pairs(store) do if k:find("tracker_log", 1, true) then prefix = k:gsub("tracker_log.*", "") end end
store[prefix .. "tracker_log"] = {
  NEW_BARK_TOWN = { { species = "CYNDAQUIL", pokemonId = "id-1" } },
  ROUTE_29 = { { species = "SENTRET", pokemonId = "id-2" } },
  DARK_CAVE_VIOLET_ENTRANCE = { { species = "GEODUDE", pokemonId = "id-3", isShiny = true } },
  ROUTE_30 = { { species = "PIDGEY", pokemonId = "id-9" } },
}
store[prefix .. "encounter_states"] = { ROUTE_31 = { status = "FAILED", species = "BELLSPROUT" } }
-- the history logs every catch as ALIVE; only a LOST entry is a death
store[prefix .. "nuzlocke_history"] = { { pokemonId = "id-1", status = "ALIVE" },
  { pokemonId = "id-3", status = "ALIVE" }, { pokemonId = "id-9", status = "ALIVE" },
  { pokemonId = "id-9", status = "LOST" } }
-- a Crystal map named the way the game data names it, run together
game.data.maps = { DarkCaveVioletEntrance = { name = "DarkCaveVioletEntrance" } }
store[prefix .. "tracker_log"].DarkCaveVioletEntrance = { { species = "ZUBAT", pokemonId = "id-4" } }
local d2 = screen:_aioModernData()
local by = {}
for _, r in ipairs(d2.rows) do by[r.species or r.label] = r end
check(by.CYNDAQUIL and by.CYNDAQUIL.status == "party", "lead in the party: PARTY")
check(by.SENTRET and by.SENTRET.status == "lost", "fainted flag: FAINTED")
check(by.PIDGEY and by.PIDGEY.status == "lost", "in the loss history: FAINTED")
check(by.GEODUDE and by.GEODUDE.status == "caught" and by.GEODUDE.shiny, "boxed shiny: CAUGHT")
check(d2.counts.caught == 3 and d2.counts.lost == 2, "totals: " .. d2.counts.caught .. " / " .. d2.counts.lost)
for _, r in ipairs(d2.rows) do
  check(not tostring(r.label):find("%l%l+entrance"), "area names keep their spaces: " .. tostring(r.label))
end
check(by.ZUBAT and by.ZUBAT.label == "Dark Cave Violet Entrance",
  "run-together map name spaced: " .. tostring(by.ZUBAT and by.ZUBAT.label))
screen.tab = 2
local d3 = screen:_aioModernData()
local failed
for _, r in ipairs(d3.rows) do if r.status == "failed" then failed = r end end
check(failed == nil or failed.species == "BELLSPROUT", "MAP tab: a failed area shows what got away")
-- 0.9.77: currentAreaOpen, the HUD TRACK button's dot
local nz = mod.exports.nuzlocke
check(type(nz) == "table" and type(nz.currentAreaOpen) == "function", "currentAreaOpen exported")
game.data.encounters = { ROUTE_32 = { grass = { { species = "BELLSPROUT" } } },
  CHERRYGROVE_CITY = { water = { { species = "TENTACOOL" } } }, ROUTE_31 = { grass = { { species = "BELLSPROUT" } } } }
local function at(map) game.world = { map = { id = map } }; return nz.currentAreaOpen(game) end
local open, name = at("ROUTE_32")
check(open == true and type(name) == "string", "fresh route with wild Pokemon: open")
check(at("ROUTE_31") == false, "failed encounter: used")
check(at("ROUTE_29") == false, "no wild data for the map: no dot")
check(at("ELMS_LAB") == false, "indoors: no dot")
check(at("CHERRYGROVE_CITY") == false, "town without TOWN CATCHES: no dot")
store[prefix .. "town_catches"] = true
check(at("CHERRYGROVE_CITY") == true, "town with TOWN CATCHES: open")
store[prefix .. "caught_areas"] = { ROUTE_32 = "BELLSPROUT" }
check(at("ROUTE_32") == false, "caught here: used")
store[prefix .. "caught_areas"] = {}
store[prefix .. "nuzlocke_enabled"] = false
check(at("CHERRYGROVE_CITY") == false, "Nuzlocke off: no dot")
store[prefix .. "nuzlocke_enabled"] = nil
-- 0.9.77: START has no RULES row (CRYSTAL-AIO -> RULES -> RUN RULES has them)
game.save.player = { name = "KRIS" }
local items = H.Runtime.call("ui.start_menu.items", function(_, list) return list end, game,
  { { label = "POKeDEX" }, { label = "KRIS" }, { label = "OPTION" }, { label = "EXIT" } })
local labels = {}
for _, it in ipairs(items) do labels[it.label] = true end
check(labels.TRACKER and labels["CRYSTAL-AIO"] and not labels.RULES, "START: TRACKER, CRYSTAL-AIO, no RULES")
print(("encounter tracker: %d checks PASS"):format(n))
