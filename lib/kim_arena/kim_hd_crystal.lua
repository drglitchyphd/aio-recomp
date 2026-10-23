-- KIM_ARENA: choose a Kanto in Motion HD battle background (1920x950, the
-- set KIM downloads into its asset cache) for a Gold/Silver/Crystal battle.
--
-- KIM's own router reads Gen 1 map ids. Crystal maps are Johto names, so this
-- maps them through the Stadium environment classifier (grass, town, water,
-- cave, gym, ...) plus a short list of named places, and picks the KIM scene
-- with the closest look. Timed scenes follow Crystal's time of day.
local M = {}

-- Scenes KIM ships in sunrise/day/sunset/night variants.
local TIMED = {
  grass=true, road=true, sea=true, viridian_forest=true, mt_moon=true,
  oak_lab=true, pokemon_mansion=true, pokemon_tower=true,
  power_plant_exterior=true, cerulean_bridge=true, safari=true, ss_anne=true,
}

-- Named maps first (exact id, then prefix).
local EXACT = {
  -- Johto gyms, matched by type theme
  VIOLET_GYM="gym_viridian", AZALEA_GYM="gym_celadon",
  GOLDENROD_GYM="gym_saffron_fighting", ECRUTEAK_GYM="gym_saffron_psychic",
  OLIVINE_GYM="gym_vermilion", CIANWOOD_GYM="gym_saffron_fighting",
  MAHOGANY_GYM="gym_cerulean", BLACKTHORN_GYM_1F="gym_cinnabar",
  BLACKTHORN_GYM_2F="gym_cinnabar",
  -- Kanto gyms in Crystal
  PEWTER_GYM="gym_pewter", CERULEAN_GYM="gym_cerulean",
  VERMILION_GYM="gym_vermilion", CELADON_GYM="gym_celadon",
  FUCHSIA_GYM="gym_fuchsia", SAFFRON_GYM="gym_saffron_psychic",
  SEAFOAM_GYM="gym_cinnabar", CINNABAR_GYM="gym_cinnabar",
  VIRIDIAN_GYM="gym_viridian",
  -- Elite Four
  WILLS_ROOM="league_lorelei", KOGAS_ROOM="league_agatha",
  BRUNOS_ROOM="league_bruno", KARENS_ROOM="league_agatha",
  LANCES_ROOM="league_lance", CHAMPIONS_ROOM="league_champion",
  -- places with a close KIM equivalent
  ILEX_FOREST="viridian_forest", NATIONAL_PARK="safari",
  NATIONAL_PARK_BUG_CONTEST="safari", POWER_PLANT="power_plant_1",
  ELMS_LAB="oak_lab", OAKS_LAB="oak_lab",
}
local PREFIX = {
  {"MOUNT_MOON", "mt_moon"}, {"MT_MOON", "mt_moon"},
  {"FAST_SHIP", "ss_anne"}, {"SS_AQUA", "ss_anne"},
  {"SPROUT_TOWER", "pokemon_tower"}, {"BURNED_TOWER", "pokemon_tower"},
  {"TIN_TOWER", "pokemon_tower"}, {"BELL_TOWER", "pokemon_tower"},
  {"POKEMON_TOWER", "pokemon_tower"}, {"RADIO_TOWER", "rocket_hideout"},
  {"TEAM_ROCKET_BASE", "rocket_hideout"}, {"UNDERGROUND_WAREHOUSE", "rocket_hideout"},
  {"SILPH_CO", "silph_co"}, {"VICTORY_ROAD", "cave_victory_road"},
  {"ICE_PATH", "cave_seafoam"}, {"SEAFOAM", "cave_seafoam"},
  {"CERULEAN_CAVE", "cave_cerulean"},
}
-- Broad environment categories (lib/battle_environment.lua's ids).
local CATEGORY = {
  grass="grass", town="road", freshwater="sea", ocean="sea", mountain="road",
  cave="cave_dark", cave_water="cave_dark", ice_cave="cave_seafoam",
  interior="oak_lab", industrial="power_plant_2", ruins="pokemon_tower",
  ship="ss_anne", gym="gym_pewter", league="league_champion",
  indoor_water="sea", unknown="road",
}

local function key(v) return (tostring(v or ""):upper():gsub("[^A-Z0-9_]", "_")) end

-- Crystal's time of day -> KIM's four lighting periods.
function M.period(tod)
  tod = key(tod)
  if tod == "MORN" or tod == "MORNING" then return "sunrise" end
  if tod == "EVE" or tod == "EVENING" then return "sunset" end
  if tod == "NITE" or tod == "NIGHT" then return "night" end
  return "day"
end

-- ctx: the battle context the host captured; category: classifier id.
function M.file(ctx, category)
  ctx = ctx or {}
  local map = key(ctx.mapId)
  local scene = EXACT[map]
  if not scene then
    for _, row in ipairs(PREFIX) do
      if map:sub(1, #row[1]) == row[1] then scene = row[2]; break end
    end
  end
  scene = scene or CATEGORY[category or "unknown"] or "road"
  if TIMED[scene] then
    return scene .. "_" .. M.period(ctx.timeOfDay), scene
  end
  return scene, scene
end

M.TIMED, M.EXACT, M.CATEGORY = TIMED, EXACT, CATEGORY
return M
