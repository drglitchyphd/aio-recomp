-- gen2-aio: ALL 251 CATCHABLE (Pokemon Crystal).
--
-- Crystal leaves 33 species unobtainable on one save (computed from
-- pret/pokecrystal: every wild table -- grass, water, fishing, headbutt, rock
-- smash, Bug-Catching Contest -- plus gifts, statics, trades, prizes, the Odd
-- Egg, evolution and breeding). Only the 17 base forms below need a wild
-- slot; evolution and breeding give the other 16.
--
-- Placement priority (lore): HeartGold / SoulSilver's own location where that
-- map exists in Crystal, then Crystal 251's curated choice, then habitat.
-- Legendaries and mythicals are rare late-game encounters: their slots are
-- added only once the Elite Four has been beaten (EVENT_BEAT_ELITE_FOUR, 68).
--
-- How: each species takes one of a map's RARE slots in the real encounter
-- data (grass 30/30/20/10/5/4/1, water 60/30/10), so the engine's rolls,
-- Wilds' visible spawns, Nuzlocke and effectiveEncounters all agree. A slot is
-- only taken when the species in it still appears in another slot somewhere,
-- so nothing that was catchable stops being catchable.
--
-- Trade evolutions evolve by level-up instead (evolution.check): Kadabra,
-- Machoke, Graveler and Haunter at Lv 37+; Onix, Scyther, Seadra, Poliwhirl,
-- Slowpoke and Porygon on any level-up while holding their trade item.
-- A real trade still works as before.

return function(host)
  local mod, log = host.mod, host.log or function() end
  local M = {}

  local ALL = { "MORN", "DAY", "NITE" }
  local MD = { "MORN", "DAY" }
  -- { species, map, kind, times, slot preference, level override, late }
  M.PLACEMENTS = {
    { "BULBASAUR",  "ROUTE_2",            "grass", MD,                { 7, 6 } },
    { "CHARMANDER", "ROUTE_3",            "grass", MD,                { 7, 6 } },
    { "SQUIRTLE",   "ROUTE_25",           "grass", MD,                { 7, 6 } },
    { "CHIKORITA",  "ROUTE_24",           "grass", MD,                { 7, 6 } },
    { "CYNDAQUIL",  "ROUTE_36",           "grass", MD,                { 7, 6 } },
    { "TOTODILE",   "ROUTE_27",           "grass", MD,                { 7, 6 } },
    { "VULPIX",     "ROUTE_37",           "grass", { "MORN", "NITE" }, { 6, 5, 7 } },
    { "MANKEY",     "ROUTE_42",           "grass", MD,                { 6, 5, 7 } },
    { "MAREEP",     "ROUTE_32",           "grass", MD,                { 5, 6, 7 } },
    { "GIRAFARIG",  "ROUTE_43",           "grass", ALL,               { 6, 5, 7 } },
    -- 0.9.47: Route 41's 10% water slot is Mantine (only there), so Omanyte
    -- was falling back to the 30% slot; Cianwood's shore keeps it rare (10%)
    { "OMANYTE",    "CIANWOOD_CITY",      "water", nil,               { 3 } },
    { "KABUTO",     "ROUTE_40",           "water", nil,               { 3, 2 } },
    { "ARTICUNO",   "ICE_PATH_B3F",       "grass", ALL,               { 7 }, 50, true },
    { "ZAPDOS",     "ROUTE_10_NORTH",     "grass", ALL,               { 7 }, 50, true },
    { "MOLTRES",    "SILVER_CAVE_ROOM_2", "grass", ALL,               { 7 }, 50, true },
    { "MEWTWO",     "SILVER_CAVE_ROOM_3", "grass", ALL,               { 7 }, 70, true },
    { "MEW",        "ROUTE_21",           "grass", ALL,               { 7 }, 30, true },
    { "CELEBI",     "ILEX_FOREST",        "grass", { "MORN" },        { 7 }, 30, true },
  }
  local EVENT_BEAT_ELITE_FOUR = 68

  local function enabled()
    local ok, v = pcall(mod.options.get, mod.options, "allCatchable")
    return not (ok and v == false)
  end

  -- slot lists of one table row: grass by time of day, water flat
  local function slotLists(row, kind)
    if type(row) ~= "table" or type(row.slots) ~= "table" then return {} end
    if kind == "water" then return { row.slots } end
    local out = {}
    for _, t in ipairs(ALL) do
      local list = row.slots[t] or row.slots[t:lower()]
      if type(list) == "table" then out[t] = list end
    end
    return out
  end

  local function countSpecies(tables)
    local n = {}
    for _, kind in ipairs({ "grass", "water" }) do
      for _, row in pairs(type(tables[kind]) == "table" and tables[kind] or {}) do
        for _, list in pairs(slotLists(row, kind)) do
          for _, s in ipairs(list) do
            if type(s) == "table" and s.species then n[s.species] = (n[s.species] or 0) + 1 end
          end
        end
      end
    end
    return n
  end

  local applied = setmetatable({}, { __mode = "k" })   -- tables -> {placement -> true}

  local function isKindFirst(t)
    return type(t) == "table" and (type(t.grass) == "table" or type(t.water) == "table")
      and not (type(t.grass) == "table" and t.grass.slots)
  end

  local function applyTo(tables, late)
    if not (enabled() and isKindFirst(tables)) then return 0 end
    local done = applied[tables] or {}
    applied[tables] = done
    local counts, changed = nil, 0
    for i, p in ipairs(M.PLACEMENTS) do
      local species, mapId, kind, times, prefs, level, isLate = unpack(p)
      if not done[i] and (late or not isLate) then
        local row = tables[kind] and tables[kind][mapId]
        local lists = slotLists(row, kind)
        if next(lists) then
          counts = counts or countSpecies(tables)
          local targets = {}
          if kind == "water" then targets = { lists[1] }
          else for _, t in ipairs(times or ALL) do targets[#targets + 1] = lists[t] end end
          local placed = false
          for _, list in ipairs(targets) do
            for _, si in ipairs(prefs) do
              local slot = list and list[si]
              if type(slot) == "table" and slot.species then
                local was = slot.species
                if was == species or (counts[was] or 0) >= 2 then
                  if was ~= species then
                    counts[was] = counts[was] - 1
                    counts[species] = (counts[species] or 0) + 1
                    slot.species = species
                  end
                  if level then slot.level = level end
                  placed = true
                  break
                end
              end
            end
          end
          done[i] = true
          if placed then changed = changed + 1
          else log("warn", "251: no free rare slot for %s on %s", species, mapId) end
        end
      end
    end
    return changed
  end

  local function lateUnlocked()
    local w = mod.world
    if not (w and w.getFlag) then return false end
    local ok, v = pcall(w.getFlag, w, EVENT_BEAT_ELITE_FOUR)
    return ok and v == true
  end

  local function applyAll(game, extra)
    local late = lateUnlocked()
    local seen = {}
    local function one(t) if t and not seen[t] then seen[t] = true; applyTo(t, late) end end
    if extra then one(extra) end
    local data = game and game.data
    if data then one(data.gen2Encounters); one(data.encounters) end
    local world = game and game.world
    if world then
      one(world.encounters)
      if type(world.wildTables) == "function" then
        local ok, t = pcall(world.wildTables, world); if ok then one(t) end
      end
    end
  end
  M.applyAll = applyAll
  M.applyTo = applyTo

  local function activeGame()
    return rawget(mod, "_kantoInMotionActiveGame") or mod.game
  end

  -- every real roll sees the additions (ctx carries the live tables and data)
  mod.hooks:wrap("encounter.roll", function(next, tables, ctx)
    if enabled() then
      pcall(applyAll, { data = ctx and ctx.data }, tables)
    end
    return next(tables, ctx)
  end, 60)
  -- Wilds reads the tables directly: apply on every map entry too (this is
  -- also where the late-game unlock is picked up)
  mod.events:on("map.entered", function() pcall(applyAll, activeGame()) end)
  mod.events:on("save.loaded", function() pcall(applyAll, activeGame()) end)

  -- ---------------------------------------------------- trade evolutions
  local LEVEL_RULE = 37
  M.TRADE_LEVEL = LEVEL_RULE
  mod.hooks:wrap("evolution.check", function(next, data, mon, entry, ctx)
    local isTrade = type(entry) == "table"
      and (entry.method == "EVOLVE_TRADE" or entry.method == "TRADE")
    if not (isTrade and enabled()) then return next(data, mon, entry, ctx) end
    ctx = ctx or {}
    if ctx.link or ctx.force then return next(data, mon, entry, ctx) end
    if type(mon) ~= "table" then return false end
    local item = mon.item
    if item == "EVERSTONE" then return false end
    if entry.item then
      return item == entry.item          -- level up holding the trade item
    end
    return (tonumber(mon.level) or 0) >= LEVEL_RULE
  end, 60)

  return M
end
