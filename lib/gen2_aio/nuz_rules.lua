-- gen2-aio 0.9.35: Nuzlocke's run rules on a Modern UI page.
--
-- GEN2-AIO -> RULES -> RUN RULES opens the rules of the
-- current run as rows of Crystal's own OPTION screen, so they take the KIM
-- theme and touch like every other setting, instead of Nuzlocke's Game Boy
-- config screen. Values are read and written through Nuzlocke's own
-- getConfigValue / setConfigValue (exported as getRule / setRule), so
-- clamping, Locke presets and the save keys stay Nuzlocke's. LOCK RULES on
-- makes every row read-only, as on the original screen. The title screen's
-- SETUP (pre-game rules) keeps the original screen.
return function(host)
  local mod, nz = host.mod, host.nz
  if type(nz) ~= "table" or type(nz.ruleCategories) ~= "table"
      or type(nz.getRule) ~= "function" or type(nz.setRule) ~= "function" then
    return nil
  end
  local Hub = rawget(mod, "_kimArenaHub")

  local LABELS = {
    level_cap_scope = { [0] = "NONE", "GYMS", "E4", "CHAMP", "POSTGAME" },
    dupes_mode = { [0] = "OFF", "SPECIES", "FAMILY" },
    world_building_tier = { [0] = "OFF", "T1", "T2", "T3" },
  }
  -- pre-game only (they act at NEW GAME) or not selectable
  local SKIP = { starting_money = true, starting_pokeballs = true,
    starting_rare_candies = true, wonderlocke = true }

  local function locked()
    local ok, v = pcall(nz.getRule, "rules_locked")
    return ok and v == true
  end

  local function buildRows()
    local rows = {}
    for _, cat in ipairs(nz.ruleCategories) do
      for _, rule in ipairs(cat.rules or {}) do
        local key = rule.key
        if key and not SKIP[key] then
          local row = { id = "kimArena.nzr." .. key,
            label = tostring(rule.name or key):upper(),
            help = tostring(rule.desc or "") }
          row.value = function()
            local ok, v = pcall(nz.getRule, key)
            if not ok then return "?" end
            if rule.numeric then
              local n = math.floor(tonumber(v) or 0)
              local names = LABELS[key]
              return names and names[n] or tostring(n)
            end
            return v == true and "ON" or "OFF"
          end
          row.step = function(_, dir)
            if key ~= "rules_locked" and locked() then return end
            -- LOCK RULES can be turned on mid-run, never back off
            if key == "rules_locked" and locked() then return end
            local ok, v = pcall(nz.getRule, key)
            if not ok then return end
            if rule.numeric then
              local lo, hi = tonumber(rule.min) or 0, tonumber(rule.max) or 1
              local n = math.floor(tonumber(v) or lo) + ((dir or 1) < 0 and -1 or 1)
              if n > hi then n = lo elseif n < lo then n = hi end
              pcall(nz.setRule, key, n)
            else
              pcall(nz.setRule, key, v ~= true)
            end
          end
          row.activate = function(g) row.step(g, 1) end
          rows[#rows + 1] = row
        end
      end
    end
    return rows
  end

  local function open(game)
    Hub = Hub or rawget(mod, "_kimArenaHub")
    if not (Hub and Hub.page) then return false end
    local rows = buildRows()
    if #rows == 0 then return false end
    return Hub.page(game, rows, locked() and "RULES (LOCKED)" or "RULES") ~= nil
  end
  rawset(mod, "_kimArenaNuzRules", open)

  if Hub and Hub.extras then
    Hub.extras.rules = function()
      return { { id = "kimArena.nzr.open", label = "RUN RULES", group = true,
        help = "This run's Nuzlocke rules: level cap scope, clauses, hardcore rules.",
        activate = function(g) open(g) end } }
    end
  end
  return { open = open, rows = buildRows }
end
