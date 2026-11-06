-- Crystal-AiO 1.0.0: BATTLE SPRITES = BLACK/WHITE (IMPORTED).
--
-- gmarc 1.0.17 can draw the battle Pokemon from the engine's shared asset
-- pack gen5_bw / battle_sprites (gmarc/lib/BattleSprites.lua and
-- ImportedBattleSprites.lua, read through mod.packs; manifest.json declares
-- the pack under optional_assets). The engine's importer builds that pack
-- from the player's own Black/White dump; nothing is bundled.
--
-- The host's BATTLE SPRITES row (KIM's battleSprites, a toggle) becomes a
-- choice: KIM HD (true), BLACK/WHITE (IMPORTED) ("bw"), OFF (false). "bw" is
-- not false, so every KIM reader keeps treating it as KIM HD: that is the
-- fallback everywhere the imported sprites do not apply. Only gmarc's 3D
-- battle swaps the picture, through its hidden voxelBattleSprites setting,
-- which the host pins (main.lua locks) from status() below.
local BW = {}

BW.VALUE = "bw"
BW.LABEL = "BLACK/WHITE (IMPORTED)"
BW.HOWTO = "Import Pokemon Black/White in the game's IMPORT screen first "
  .. "(IMPORTERS > Pokemon Black / White, from your own cartridge dump), then restart the game."

BW.HELP = "Which Pokemon pictures battles use. KIM HD: Kanto in Motion's animated HD "
  .. "Pokemon. BLACK/WHITE (IMPORTED): the animated Black/White sprites, in 3D battles "
  .. "(any BATTLE BACKGROUND but DEFAULT). " .. BW.HOWTO .. " Without them, or in a "
  .. "DEFAULT battle, KIM HD is used. OFF: Crystal's own sprites."

-- the host's version of KIM's battleSprites row (main.lua mergeDefine)
function BW.schemaRow(row)
  return {
    key = "battleSprites", label = (type(row) == "table" and row.label) or "BATTLE SPRITES",
    type = "choice", default = true,
    choices = { { "KIM HD", true }, { BW.LABEL, BW.VALUE }, { "OFF", false } },
    help = BW.HELP,
  }
end

-- why the imported sprites cannot be used right now, or nil when they can.
-- ctx: { opt = fn(key, default), threeD = fn() -> bool,
--        packReason = fn() -> string|nil }
function BW.status(ctx)
  local okV, chosen = pcall(ctx.opt, "battleSprites", true)
  if not (okV and chosen == BW.VALUE) then return { chosen = false, active = false } end
  local okT, threeD = pcall(ctx.threeD)
  if not (okT and threeD) then
    return { chosen = true, active = false,
      why = "Black/White sprites are drawn in 3D battles only (pick a BATTLE BACKGROUND "
        .. "other than DEFAULT); using KIM HD." }
  end
  local okR, reason = pcall(ctx.packReason)
  if not okR then reason = tostring(reason) end
  if reason then
    return { chosen = true, active = false,
      why = "No Black/White sprites: " .. BW.HOWTO .. " Using KIM HD." }
  end
  return { chosen = true, active = true }
end

-- the gmarc provider's verdict (validated pack, readable index), else the
-- engine's pack API directly; nil = usable
function BW.packReason(gmarcLib, packs)
  if type(gmarcLib) == "table" and type(gmarcLib.require) == "function" then
    local okB, Sprites = pcall(gmarcLib.require, "BattleSprites")
    if okB and type(Sprites) == "table" and type(Sprites.unavailableReason) == "function" then
      local okR, reason = pcall(Sprites.unavailableReason)
      if okR then return reason end
      return tostring(reason)
    end
  end
  if type(packs) ~= "table" or type(packs.info) ~= "function" then
    return "this engine has no shared asset packs"
  end
  local okI, info, err = pcall(packs.info, packs, "gen5_bw", "battle_sprites")
  if okI and type(info) == "table" then return nil end
  return tostring(okI and err or info or "pack missing")
end

return BW
