-- gen2-aio: TRAINER LEVELS (level-matched trainers).
--
-- trainer.party hands over each trainer's roster before battle; the engine
-- recomputes every member's stats from its level right after the hook
-- (Battle.lua, Mon.refreshStats), so raising levels here is the whole job.
--
--   MATCH     the trainer's strongest Pokemon is raised to your strongest
--             Pokemon's level; the rest of the team moves up by the same
--             amount, keeping the trainer's own spacing.
--   MATCH +2  the same, two levels above you.
--   MATCH -1/-2   (0.9.36) the ace lands one or two levels under yours.
--   MATCH -5 TO 0 (0.9.36) anywhere from five under to level with you.
--             The offset is drawn per trainer and stays the same for that
--             trainer at that party level (seeded, so a reload or a second
--             call within the same fight agrees with the first).
--
-- Trainers are only ever raised, never lowered: a gym leader already above
-- you stays as Crystal made them. Default movesets are re-learned for the new
-- level; hand-picked movesets (most leaders, the rival, the Elite Four) are
-- kept as they are. Nuzlocke's level caps limit how high YOUR team can go, so
-- matching follows the cap too.
return function(host)
  local mod, log = host.mod, host.log or function() end
  local M = {}
  local okMon, Mon = pcall(require, "src.battle.gen2.Mon")

  local function opt(key, default)
    local ok, v = pcall(mod.options.get, mod.options, key)
    if ok and v ~= nil then return v end
    return default
  end

  local function activeGame()
    return rawget(mod, "_kantoInMotionActiveGame") or mod.game
  end

  local function playerTopLevel(game)
    local party = game and game.save and game.save.party
    local top = 0
    for _, mon in ipairs(type(party) == "table" and party or {}) do
      local lv = tonumber(mon and mon.level) or 0
      if lv > top then top = lv end
    end
    return top
  end

  local function sameMoves(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    local function ids(list)
      local out = {}
      for _, m in ipairs(list) do out[#out + 1] = tostring(type(m) == "table" and (m.id or m.move) or m) end
      return table.concat(out, ",")
    end
    return ids(a) == ids(b)
  end

  -- stable per-trainer offset in [lo, hi]
  local function offset(lo, hi, class, member, top)
    local key = tostring(class) .. "|" .. tostring(member) .. "|" .. tostring(top)
    local h = 5381
    for i = 1, #key do h = (h * 33 + key:byte(i)) % 2147483647 end
    for _ = 1, 3 do h = (h * 48271) % 2147483647 end  -- spread nearby keys
    return lo + (h % (hi - lo + 1))
  end
  local RANGES = { matchm12 = { -2, -1 }, matchm5 = { -5, 0 } }

  function M.scale(roster, game, class, member)
    local mode = opt("trainerLevels", "match")
    if mode == "off" or type(roster) ~= "table" or #roster == 0 then return roster end
    local target = playerTopLevel(game)
    if target <= 0 then return roster end
    if mode == "match2" then target = target + 2 end
    local range = RANGES[mode]
    if range then target = math.max(1, target + offset(range[1], range[2], class, member, target)) end
    local ace = 0
    for _, mon in ipairs(roster) do ace = math.max(ace, tonumber(mon.level) or 0) end
    local delta = math.min(99, target) - ace
    if delta <= 0 then return roster end              -- never lowered
    local data = game and game.data
    for _, mon in ipairs(roster) do
      local old = tonumber(mon.level) or 1
      local new = math.max(1, math.min(100, old + delta))
      local def = data and data.pokemon and data.pokemon[mon.species]
      if okMon and def and type(Mon.movesAtLevel) == "function" then
        local okOld, defaultOld = pcall(Mon.movesAtLevel, def, old, data.moves)
        if okOld and sameMoves(mon.moves, defaultOld) then
          local okNew, moves = pcall(Mon.movesAtLevel, def, new, data.moves)
          if okNew and type(moves) == "table" then mon.moves = moves end
        end
      end
      mon.level = new
      mon.hp = nil                                   -- refreshStats fills it
    end
    return roster
  end

  mod.hooks:wrap("trainer.party", function(next, class, member, roster)
    local out = next(class, member, roster)
    local ok, scaled = pcall(M.scale, out, activeGame(), class, member)
    if ok and scaled then return scaled end
    if not ok then log("warn", "Crystal-AiO trainer levels: %s", tostring(scaled)) end
    return out
  end, 50)

  return M
end
