-- gen2-aio: why a POKéMON won't obey.
--
-- Crystal's BattleCommand_CheckObedience (engine/battle/effect_commands.asm)
-- only ever tests a mon whose OT ID is not the player's -- an in-game trade
-- (Violet City's ONIX, Goldenrod's MACHOP, ...), a gift with its own OT
-- (Randy's SPEAROW) or a link trade.  Such a mon obeys up to Lv10 with no
-- badges, and the ZEPHYRBADGE does NOT raise that: HIVEBADGE -> 30,
-- FOGBADGE -> 50, STORMBADGE -> 70, RISINGBADGE -> every level.  The engine
-- reproduces that ladder exactly (Battle:obedienceLevel).
--
-- The mod's RENAME row lets any mon be renamed, which the cart's Name Rater
-- refuses for exactly these mons, so a renamed trade looks like the player's
-- own catch and "won't obey!" at Lv11+ read as a bug.  The rule stays; the
-- first time a mon disobeys in a battle one extra line says why and which
-- badge lifts the limit.
return function(host)
  local ok, Battle = pcall(require, "src.battle.gen2.Battle")
  if not (ok and type(Battle) == "table" and type(Battle.checkObedience) == "function"
      and type(Battle.obedienceLevel) == "function") then
    return nil
  end
  local okS, Strings = pcall(require, "src.core.Strings")
  local function fmt(text, ...)
    if okS and Strings then
      local okF, out = pcall(Strings, text, ...)
      if okF and type(out) == "string" then return out end
    end
    return text:format(...)
  end

  -- the badge that raises the cap next, in the cart's ladder order
  local function nextBadge(battle)
    if type(battle.hasBadge) ~= "function" then return nil end
    for _, badge in ipairs({ "RISING", "STORM", "FOG", "HIVE" }) do
      if battle:hasBadge("badges", badge) then
        if badge == "RISING" then return nil end
        return ({ STORM = "RISING", FOG = "STORM", HIVE = "FOG" })[badge]
      end
    end
    return "HIVE"
  end

  local function hintText(battle, mon)
    local name = type(battle.monName) == "function" and battle:monName(mon)
      or mon.nickname or mon.species or "?"
    local text = fmt("%s came from\nanother TRAINER.\fIt only obeys up\nto Lv%d for now.",
      name, battle:obedienceLevel())
    local badge = nextBadge(battle)
    if badge then text = text .. fmt("\fThe %sBADGE\nraises that limit.", badge) end
    return text
  end

  -- live per session; the wrap below is once per process (engine modules
  -- outlive a session when Android relaunches in the same Lua state)
  rawset(Battle, "_aioObedienceHintLive", function(self)
    local mon = self.player
    if type(mon) ~= "table" or type(self.emit) ~= "function" then return end
    self._aioObeyHinted = self._aioObeyHinted or setmetatable({}, { __mode = "k" })
    if self._aioObeyHinted[mon] then return end
    self._aioObeyHinted[mon] = true
    self:emit({ kind = "message", text = hintText(self, mon) })
  end)
  if not rawget(Battle, "_aioObedienceHintWrapped") then
    rawset(Battle, "_aioObedienceHintWrapped", true)
    local origCheck = Battle.checkObedience
    Battle.checkObedience = function(self, ...)
      local disobeyed = origCheck(self, ...)
      if disobeyed then
        local live = rawget(Battle, "_aioObedienceHintLive")
        if live then pcall(live, self) end
      end
      return disobeyed
    end
  end
  return { hintText = hintText, nextBadge = nextBadge }
end
