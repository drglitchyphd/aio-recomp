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
local M = assert(loadfile("lib/crystal_aio/npc_mons.lua"))()({ mod = mod })
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
-- 0.9.87: the Kiln's bird with no script key is still a Farfetch'd
check(M.speciesFor(world, npc("SPRITE_MOLTRES", nil)) == "FARFETCH_D", "MOLTRES sheet without a script: Farfetch'd")
-- 0.9.88: the ROM's sprite table tags the sheet itself as MOLTRES (device)
local kiln = npc("SPRITE_MOLTRES", nil); kiln.spriteDef.species = "MOLTRES"
check(M.speciesFor(world, kiln) == "FARFETCH_D", "sheet tagged MOLTRES by the ROM: still Farfetch'd")
local kiln2 = npc("SPRITE_MOLTRES", "KilnFarfetchd"); kiln2.spriteDef.species = "MOLTRES"
check(M.speciesFor(world, kiln2) == "FARFETCH_D", "tagged sheet with its script: Farfetch'd")
local slow = npc("SPRITE_SLOWPOKE", nil); slow.spriteDef.species = "SLOWPOKE"
check(M.speciesFor(world, slow) == "SLOWPOKE", "other tagged sheets keep their species")
-- the species list from the game's own data when world.constants has none
local World2 = require("src.world.gen2.World")
World2._kimArenaNpcMons = nil
local M2 = assert(loadfile("lib/crystal_aio/npc_mons.lua"))()({ mod = mod })
local world2 = { constants = {}, game = { data = { pokemon = { SLOWPOKE = {}, GYARADOS = {} } } }, scripts = {} }
check(M2.speciesFor(world2, npc("SPRITE_SLOWPOKE", nil)) == "SLOWPOKE", "species known from game.data.pokemon")
check(M2.speciesCount == 2, "and counted: " .. tostring(M2.speciesCount))
-- 0.9.90: the True Size style is read through WILDS' mod handle (its own
-- options), as the followers do -- not this mod's, which never has it
do
  local seen = {}
  local wmod = { id = "wilds_of_kanto_gen3" }
  local Config = { spriteStyle = function(m) return m == wmod and "pokemmo" or "followers" end }
  local Geo = { resolveDisplayGeometry = function(dex, style, fw, fh, ax, ay)
    seen.dex, seen.style = dex, style
    return fw * 0.5, fh * 0.5, ax, ay
  end }
  local Assets = { idForRuntime = function(k, d) return d or k end, idFor = function() return 83 end }
  local mods = { species_geometry = Geo, species_assets = Assets, config = Config,
    game_compat = { speciesId = function() return 83 end } }
  local ex = {
    resolveFollowerSprite = function() return { image = "x.png", frames = 2, frameWidth = 64, frameHeight = 64, anchorX = 32, anchorY = 60 } end,
    require = function(name) return mods[name] end,
    lib = { mod = wmod },
  }
  local World3 = require("src.world.gen2.World"); World3._kimArenaNpcMons = nil
  local SR = require("src.render.SpriteRenderer")
  local realNew = SR.new
  SR.new = function(def) return { def = def } end
  local M3 = assert(loadfile("lib/crystal_aio/npc_mons.lua"))()({ mod = mod, wilds = function() return ex end })
  local bird = npc("SPRITE_MOLTRES", "KilnFarfetchd")
  pcall(M3.apply, world, bird)
  SR.new = realNew
  check(seen.style == "pokemmo", "style read from Wilds' own options: " .. tostring(seen.style))
  check(bird.sprite and bird.sprite.def and bird.sprite.def.displayWidth == 32, "display size applied to the NPC")
end
print(("npc mon species: %d checks PASS"):format(n))
