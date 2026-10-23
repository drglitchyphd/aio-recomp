-- KIM_ARENA: Quick Poke Ball on SELECT.
--
-- Wild battles, battle command menu (phase "menu") only: in the move list
-- SELECT swaps moves, so it is never taken there. The throw goes through
-- BattleState:useItem -- the same call the PACK makes -- so Nuzlocke's
-- wrapper and every vanilla gate (box full, ...) still apply.
--
-- Which ball: the last one thrown (remembered in the save), if any are left.
-- Otherwise the next tier DOWN from it, then up; never a MASTER BALL. If the
-- Master Ball is all that is left (or there are no balls), a message says so.
return function(host)
  local mod = host.mod
  local ok, BS = pcall(require, "src.ui.gen2.BattleState")
  if not ok or type(BS) ~= "table" or type(BS.update) ~= "function" then return nil end
  if BS._kimArenaQuickBall then return BS._kimArenaQuickBall end

  -- Best first. Crystal's Apricorn balls sit between GREAT and POKE: each is
  -- a conditional multiplier, so they are spent before the plain POKE BALL
  -- only when nothing better is left.
  local ORDER = { "ULTRA_BALL", "GREAT_BALL", "LEVEL_BALL", "LURE_BALL", "MOON_BALL",
    "FRIEND_BALL", "LOVE_BALL", "HEAVY_BALL", "FAST_BALL", "POKE_BALL" }
  local INDEX = {}
  for i, id in ipairs(ORDER) do INDEX[id] = i end
  local KEY = "quickBallLast"

  local function lastBall()
    local okS, v = pcall(mod.save.get, mod.save, KEY)
    return okS and type(v) == "string" and v or nil
  end
  local function setLast(id)
    if id == "MASTER_BALL" or id == "PARK_BALL" then return end
    pcall(mod.save.set, mod.save, KEY, id)
  end

  local function isBall(state, id)
    local data = state.game and state.game.data
    local def = data and data.items and data.items[id]
    return def and def.pocket == "BALL"
  end

  local function eligible(state)
    if state.phase ~= "menu" then return false end
    local b = state.battle
    if not (b and b.wild) then return false end
    if state.tutorial or state.contest or b.inBattleTowerBattle then return false end
    return true
  end

  local function have(state, id)
    local inv = state.save and state.save.inventory
    return inv and (tonumber(inv[id]) or 0) > 0 and isBall(state, id)
  end

  local function pick(state)
    local last = lastBall()
    if last and last ~= "MASTER_BALL" and have(state, last) then return last end
    local start = (last and INDEX[last]) or 0
    for i = start + 1, #ORDER do if have(state, ORDER[i]) then return ORDER[i] end end
    for i = math.min(start, #ORDER), 1, -1 do if have(state, ORDER[i]) then return ORDER[i] end end
    -- any other ball a mod added to the BALL pocket, still never the Master
    local inv = state.save and state.save.inventory or {}
    for id, n in pairs(inv) do
      if id ~= "MASTER_BALL" and id ~= "PARK_BALL" and not INDEX[id]
          and (tonumber(n) or 0) > 0 and isBall(state, id) then return id end
    end
    return nil
  end

  -- remember every ball thrown, from the PACK too
  local origUse = BS.useItem
  if type(origUse) == "function" then
    BS.useItem = function(self, itemId, ...)
      if type(itemId) == "string" and isBall(self, itemId) and self.battle and self.battle.wild then
        setLast(itemId)
      end
      return origUse(self, itemId, ...)
    end
  end

  local origUpdate = BS.update
  BS.update = function(self, ...)
    local input = self.game and self.game.input
    if input and eligible(self) and self.slideFrame
        and self.slideFrame >= 72 and input:wasPressed("select") then
      local id = pick(self)
      if id then
        if type(self.playSfx) == "function" then pcall(self.playSfx, self, "Sfx_ReadText2") end
        return self:useItem(id)
      end
      local inv = self.save and self.save.inventory or {}
      local text = (tonumber(inv.MASTER_BALL) or 0) > 0
        and "Only a MASTER BALL is left. Throw it from the PACK."
        or "No POKé BALLS left."
      if type(self.refuseMenu) == "function" then self:refuseMenu(text) end
      return
    end
    return origUpdate(self, ...)
  end

  -- KIM Touch relabels its SELECT pill to BALL while this is armed.
  mod._kimArenaQuickBallReady = function()
    local G = rawget(mod, "_kantoInMotionActiveGame")
    local game = type(G) == "function" and G() or G
    local stack = type(game) == "table" and game.stack
    local top = stack and stack.top and stack:top()
    return type(top) == "table" and getmetatable(top) and top.battle ~= nil
      and eligible(top) or false
  end

  local api = { pick = pick, eligible = eligible }
  BS._kimArenaQuickBall = api
  return api
end
