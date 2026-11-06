-- 1.0.0 BATTLE SPRITES = BLACK/WHITE (IMPORTED): gmarc's 3D battle draws the
-- engine's shared gen5_bw / battle_sprites pack when it is there, and KIM HD
-- (with the reason on the row and on DIAGNOSTICS) when it is not.
-- Run from the repo root: luajit tests/bw_sprites.lua
-- (each case boots main.lua in its own process: the provider reads the pack
-- index once, at load, like the game does)
local case = arg and arg[1]
local n, fails = 0, 0
local function check(c, m)
  n = n + 1
  if not c then fails = fails + 1; io.stderr:write("FAIL: " .. tostring(m) .. "\n") end
end

if not case then
  -- the manifest declares the pack, or mod.packs refuses every call
  local f = assert(io.open("manifest.json")); local manifest = f:read("*a"); f:close()
  check(manifest:find('"optional_assets"', 1, true) and manifest:find('"importer": "gen5_bw"', 1, true)
    and manifest:find('"pack": "battle_sprites"', 1, true), "manifest declares gen5_bw/battle_sprites")
  -- the pure status rules
  local BW = dofile("lib/crystal_aio/bw_sprites.lua")
  local function opt(v) return function(_, d) if v == nil then return d end return v end end
  local st = BW.status({ opt = opt(true), threeD = function() return true end, packReason = function() return nil end })
  check(not st.chosen and not st.active, "KIM HD chosen: nothing to do")
  st = BW.status({ opt = opt("bw"), threeD = function() return true end, packReason = function() return "missing" end })
  check(st.chosen and not st.active and st.why:find("IMPORT screen", 1, true) and st.why:find("KIM HD", 1, true),
    "no pack: KIM HD with the import hint: " .. tostring(st.why))
  st = BW.status({ opt = opt("bw"), threeD = function() return false end, packReason = function() return nil end })
  check(st.chosen and not st.active and st.why:find("3D battles only", 1, true), "DEFAULT battle: KIM HD")
  st = BW.status({ opt = opt("bw"), threeD = function() return true end, packReason = function() return nil end })
  check(st.active, "pack + 3D: imported sprites")
  check(BW.packReason(nil, nil) ~= nil, "no pack API: unavailable")
  check(BW.packReason(nil, { info = function() return nil, "pack is not installed" end }) == "pack is not installed",
    "pack API: missing pack")
  check(BW.packReason(nil, { info = function() return { entries = 1 } end }) == nil, "pack API: present")
  local row = BW.schemaRow({ key = "battleSprites", label = "BATTLE SPRITES", type = "toggle" })
  check(row.type == "choice" and row.default == true and row.choices[1][2] == true
    and row.choices[2][1] == "BLACK/WHITE (IMPORTED)" and row.choices[2][2] == "bw" and row.choices[3][2] == false,
    "BATTLE SPRITES choices")
  check(row.help:find("IMPORT screen", 1, true), "row help says how to get the pack")
  -- the two booted cases
  local env = ""
  for _, k in ipairs({ "AIO_ENGINE", "AIO_ENGINE_SRC" }) do
    local v = os.getenv(k); if v then env = env .. k .. "='" .. v .. "' " end
  end
  for _, c in ipairs({ "absent", "present" }) do
    local p = io.popen(env .. "luajit tests/bw_sprites.lua " .. c .. " 2>&1")
    local out = p:read("*a"); p:close()
    local got = out:match("bw sprites " .. c .. ": (%d+) checks PASS")
    check(got ~= nil, c .. " case:\n" .. out:gsub("%[warn%][^\n]*\n", ""))
    if got then n = n + tonumber(got) end
  end
  if fails > 0 then print(("bw sprites: %d of %d checks FAILED"):format(fails, n)); os.exit(1) end
  print(("bw sprites: %d checks PASS"):format(n))
  return
end

-- one booted case: the engine's mod.packs as a stand-in
local present = case == "present"
local SPRITE = { width = 64, height = 64, columns = 1, frames = 1, tickRate = 60, durations = { 10 } }
HARNESS_PACKS = {
  info = function(_, importer, pack)
    if present and importer == "gen5_bw" and pack == "battle_sprites" then
      return { importer = importer, pack = pack, kind = "sprite", version = "1.1.0", entries = 1 }
    end
    return nil, "Pokemon Black / White / battle_sprites: pack is not installed"
  end,
  entries = function(_, importer, pack)
    if not present then return nil, "pack is not installed" end
    return { { id = "normal/025/front", file = "x.png", size = 100, width = 64, height = 64, sprite = SPRITE } }
  end,
  read = function() return nil, "no bytes in this test" end,
  metadata = function() return nil, "none" end,
}
local H = dofile("tests/settings_overhaul/harness.lua")
local mod, OPTS = H.mod, H.OPTS
local V = mod.exports.voxel and mod.exports.voxel.lib
check(type(V) == "table" and V.require, "gmarc loaded")
-- a 3D battle stage: KIM HD background (the default) and the voxel world on
local okVS, VoxelState = pcall(V.require, "VoxelState")
check(okVS, "VoxelState")
if okVS then VoxelState.active = function() return true end end
local Sprites = V.require("BattleSprites")
local status = rawget(mod, "_kimArenaBattleSpritesStatus")

-- KIM HD (default): gmarc stays native, no BLACK/WHITE line
OPTS.battleSprites = nil
check(not status().chosen, "default is KIM HD")
check(Sprites.setting:get() == "native", "KIM HD: gmarc native")

OPTS.battleSprites = "bw"
local st = status()
local Hub = mod._kimArenaHub
local game = { stack = { states = {} }, save = { options = { modOptions = { ["crystal-aio"] = OPTS } } },
  options = {}, mods = { modOptions = { ["crystal-aio"] = OPTS } } }
game.stack.push = function(_, page) game.stack.states[#game.stack.states + 1] = page end
local p = Hub.openSection(game, "battle")
local bsRow
for _, r in ipairs(p.rows) do if r.label == "BATTLE SPRITES" then bsRow = r end end
check(bsRow, "BATTLE SPRITES row on the BATTLE page")
local value = bsRow and (type(bsRow.value) == "function" and bsRow.value() or bsRow.value)
-- DIAGNOSTICS draws the reason
OPTS.diagnostics = true
local printed = {}
love.graphics.getFont = function() return { getWrap = function(_, l) return 0, { l } end,
  getWidth = function() return 10 end, getHeight = function() return 10 end } end
love.graphics.print = function(text) printed[#printed + 1] = tostring(text) end
love.graphics.getWidth = function() return 2184 end
pcall(H.Runtime.call, "render.hud", function() end, {}, {})
local diag = table.concat(printed, "\n")

if present then
  check(st.chosen and st.active, "pack present: imported sprites active (" .. tostring(st.why) .. ")")
  check(Sprites.setting:get() == "gen5_bw", "pack present: gmarc provider selected")
  check(Sprites.unavailableReason() == nil, "provider ready")
  check(value == "BLACK/WHITE (IMPORTED)", "row value: " .. tostring(value))
  check(diag:find("battle sprites: BLACK/WHITE", 1, true), "DIAGNOSTICS line:\n" .. diag)
  -- a DEFAULT (WHITE) battle has no 3D stage: KIM HD
  OPTS.arenaBackground = "white"
  st = status()
  check(not st.active and st.why:find("3D battles only", 1, true), "DEFAULT battle falls back")
  check(Sprites.setting:get() == "native", "DEFAULT battle: gmarc native")
  OPTS.arenaBackground = nil
  -- BATTLE BACKGROUND stays offered with BLACK/WHITE chosen
  check(not mod._kimArenaRowHidden("arenaBackground"), "BATTLE BACKGROUND row shown")
  -- the card capture draws the provider's frame through the native drawPic
  -- KIM keeps, not KIM's HD painter (which ignores state.pic)
  local IMG = { tag = "bw frame" }
  check(Sprites.register("gen5_bw", "BLACK/WHITE", { apiVersion = 2,
    capabilities = { contract = "national-dex-battle-sprites" },
    status = function() return { ready = true } end,
    frame = function() return { image = IMG, width = 64, height = 64 } end }), "test provider")
  local calls, drawn = {}, {}
  local Cls = {}; Cls.__index = Cls
  function Cls._kantoInMotionGen2HdDrawPic(self, m, back) calls[#calls + 1] = "native"; drawn[#drawn + 1] = self:pic(m, back) end
  function Cls.drawPic() calls[#calls + 1] = "kim" end
  local foe, mine = { species = "PIKACHU" }, { species = "PIKACHU" }
  local state = setmetatable({ game = { data = { pokemon = { PIKACHU = { dex = 25 } } } },
    pic = function() return "native pic" end, picScale = function() return 1 end }, Cls)
  function state.activeMon(_, side) return side == "enemy" and foe or mine end
  Sprites.withFrame(state, "enemy", function() state:drawPic(foe, false) end)
  Sprites.withFrame(state, "player", function() state:drawPic(mine, true) end)
  check(calls[1] == "native" and calls[2] == "native" and #calls == 2, "native drawPic: " .. table.concat(calls, ","))
  check(drawn[1] == IMG and drawn[2] == IMG, "provider frame drawn")
  check(Sprites.provided.enemy and Sprites.provided.player, "sides marked as provided (no KIM back flag)")
  check(state.drawPic == Cls.drawPic, "drawPic restored")
else
  check(st.chosen and not st.active and st.why:find("IMPORT screen", 1, true),
    "pack absent: KIM HD with the import hint (" .. tostring(st.why) .. ")")
  check(Sprites.setting:get() == "native", "pack absent: gmarc native")
  check(value == "B/W > KIM HD", "row value says KIM HD: " .. tostring(value))
  check(bsRow and bsRow.help:find("NOW USING KIM HD", 1, true) and bsRow.help:find("IMPORT screen", 1, true),
    "row help explains: " .. tostring(bsRow and bsRow.help))
  check(diag:find("battle sprites: KIM HD: No Black/White sprites", 1, true), "DIAGNOSTICS line:\n" .. diag)
  -- KIM HD everywhere else: KIM readers only test == false
  check(mod.options:get("battleSprites") ~= false, "KIM keeps its HD sprites")
end
-- the reverted rows are gone and nothing reads them
OPTS.voxelPrecache, OPTS.voidFloor = false, false
check(mod._kimArenaSchema and (function()
  local merged = mod._kimArenaSchema()
  for _, r in ipairs(merged) do
    if r.key == "voxelPrecache" or r.key == "voidFloor" or r.key == "voidRelief" then return false end
  end
  return true
end)(), "no VOXEL PRECACHE / WORLD EDGE FILL rows")

if fails > 0 then print(("bw sprites %s: %d of %d checks FAILED"):format(case, fails, n)); os.exit(1) end
print(("bw sprites %s: %d checks PASS"):format(case, n))
