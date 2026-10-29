-- 0.9.81: WILDS NPC POKEMON picks the species an object's talk script names
-- over the sheet it borrows -- the Charcoal Kiln's Farfetch'd is drawn on
-- SPRITE_MOLTRES and must not come out as Moltres. Run from the repo root
-- with AIO_ENGINE=<engine>/src: luajit tests/npc_mon_species.lua
local engine = os.getenv("AIO_ENGINE")
if not engine then print("npc mon species: SKIP (set AIO_ENGINE to the engine's src root)") return end
love = { graphics = setmetatable({}, { __index = function() return function() end end }),
  timer = { getTime = function() return 0 end }, audio = setmetatable({}, { __index = function() return function() end end }) }
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path
local World = require("src.world.gen2.World")
World._kimArenaNpcMons = nil
local n = 0
local function check(c, m) if not c then error("FAIL: " .. m, 2) end n = n + 1 end
local mod = { options = { get = function() return true end } }
local M = assert(loadfile("lib/gen2_aio/npc_mons.lua"))()({ mod = mod })
check(M and M.speciesFor, "installed")
local world = {
  constants = { speciesOrder = { "FARFETCH_D", "MOLTRES", "SLOWPOKE", "GYARADOS" } },
  scripts = {
    KilnFarfetchd = { { op = "faceplayer" }, { op = "opentext" }, { op = "cry", species = "FARFETCH_D" } },
    AzaleaSlowpoke = { { op = "opentext" }, { op = "cry", species = "SLOWPOKE" } },
    Silent = { { op = "jumptext" } },
  },
}
local function npc(sprite, script) return { spriteDef = { id = sprite }, def = { scriptKey = script } } end
check(M.speciesFor(world, npc("SPRITE_MOLTRES", "KilnFarfetchd")) == "FARFETCH_D",
  "the kiln's Farfetch'd on the MOLTRES sheet is a Farfetch'd")
check(M.speciesFor(world, npc("SPRITE_SLOWPOKE", "AzaleaSlowpoke")) == "SLOWPOKE", "Slowpoke stays Slowpoke")
check(M.speciesFor(world, npc("SPRITE_GYARADOS", "Silent")) == "GYARADOS", "no species in the script: the sheet's")
check(M.speciesFor(world, npc("SPRITE_GYARADOS", nil)) == "GYARADOS", "no script: the sheet's")
print(("npc mon species: %d checks PASS"):format(n))
