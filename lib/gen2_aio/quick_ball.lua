-- gen2-aio: Quick Poke Ball on SELECT, and (0.9.70) on KIM Touch's own
-- Poke Ball button, which shows in wild battles while a throw is possible
-- (0.9.85: inside the Modern battle panel's command menu when that panel
-- is up, floating beside B otherwise).
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
  -- Engine modules outlive a session (Android relaunches in the same Lua
  -- state): BattleState is wrapped once per process; the session's mod (its
  -- save, its exports) is swapped in through `live` on every launch.
  local live = rawget(BS, "_kimArenaQuickBallLive") or {}
  rawset(BS, "_kimArenaQuickBallLive", live)
  live.mod = mod
  if BS._kimArenaQuickBall then
    BS._kimArenaQuickBall.export(mod)
    return BS._kimArenaQuickBall
  end

  -- Best first. Crystal's Apricorn balls sit between GREAT and POKE: each is
  -- a conditional multiplier, so they are spent before the plain POKE BALL
  -- only when nothing better is left.
  local ORDER = { "ULTRA_BALL", "GREAT_BALL", "LEVEL_BALL", "LURE_BALL", "MOON_BALL",
    "FRIEND_BALL", "LOVE_BALL", "HEAVY_BALL", "FAST_BALL", "POKE_BALL" }
  local INDEX = {}
  for i, id in ipairs(ORDER) do INDEX[id] = i end
  local KEY = "quickBallLast"

  local function lastBall()
    local m = live.mod
    local okS, v = pcall(m.save.get, m.save, KEY)
    return okS and type(v) == "string" and v or nil
  end
  local function setLast(id)
    if id == "MASTER_BALL" or id == "PARK_BALL" then return end
    local m = live.mod
    pcall(m.save.set, m.save, KEY, id)
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

  local function ready(state)
    return eligible(state) and state.slideFrame and state.slideFrame >= 72
  end
  local function throw(self)
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
  end

  local origUpdate = BS.update
  BS.update = function(self, ...)
    local input = self.game and self.game.input
    -- a tap on the touch ball button, queued for this battle's own update
    local queued = rawget(self, "_aioQuickBallPending")
    if queued then self._aioQuickBallPending = nil end
    if ready(self) and (queued or (input and input:wasPressed("select"))) then
      return throw(self)
    end
    return origUpdate(self, ...)
  end

  -- 0.9.85: the ball a throw would use (its HD item icon, or a drawn Poke
  -- Ball) in a round button, with how many are left; dimmed when none
  local function drawButton(m, G, cx, cy, r, a, th, fontFn)
    local info
    local fn = m._kimArenaQuickBallInfo
    if type(fn) == "function" then
      local okI, v = pcall(fn); info = okI and v or nil
    end
    local id = info and info.id
    local dim = id == nil
    local aa = dim and a * 0.45 or a
    G.setColor(th.surface[1], th.surface[2], th.surface[3], aa * 0.85)
    G.circle("fill", cx, cy, r)
    G.setColor(th.frame[1], th.frame[2], th.frame[3], aa)
    G.setLineWidth(math.max(2, r * 0.08)); G.circle("line", cx, cy, r)
    local iconFn = m._kimArenaBallIcon
    local img, quad
    if type(iconFn) == "function" then
      local okC, i, q = pcall(iconFn, id or "POKE_BALL"); if okC then img, quad = i, q end
    end
    local size = r * 1.25
    if img and quad then
      G.setColor(1, 1, 1, aa)
      G.draw(img, quad, cx, cy, 0, size / 18, size / 18, 9, 9)
    else
      local br = size / 2
      G.setColor(0.86, 0.2, 0.2, aa); G.arc("fill", cx, cy, br, math.pi, 2 * math.pi)
      G.setColor(0.96, 0.96, 0.96, aa); G.arc("fill", cx, cy, br, 0, math.pi)
      G.setColor(0.1, 0.1, 0.12, aa)
      G.setLineWidth(math.max(2, br * 0.16)); G.line(cx - br, cy, cx + br, cy)
      G.circle("line", cx, cy, br)
      G.setColor(0.96, 0.96, 0.96, aa); G.circle("fill", cx, cy, br * 0.28)
    end
    -- the count in a badge at the lower right
    local n = info and info.count or 0
    local label = dim and "0" or tostring(n)
    local bf = fontFn and fontFn(r * 0.42) or G.getFont()
    local bw = math.max(bf:getWidth(label) + r * 0.3, r * 0.62)
    local bh = bf:getHeight() * 1.05
    local bx, by = cx + r * 0.95 - bw, cy + r * 0.95 - bh
    G.setColor(th.frame[1], th.frame[2], th.frame[3], aa)
    G.rectangle("fill", bx, by, bw, bh, bh / 2, bh / 2)
    G.setFont(bf)
    G.setColor(th.surface[1], th.surface[2], th.surface[3], math.min(1, aa + 0.15))
    G.printf(label, bx, by + (bh - bf:getHeight()) / 2, bw, "center")
  end

  local function topBattle()
    local G = rawget(live.mod, "_kantoInMotionActiveGame")
    local game = type(G) == "function" and G() or G
    local stack = type(game) == "table" and game.stack
    local top = stack and stack.top and stack:top()
    if type(top) == "table" and getmetatable(top) and top.battle ~= nil then return top end
    return nil
  end
  -- the session's hooks for KIM Touch's ball button
  local function export(m)
    -- whether to show it
    m._kimArenaQuickBallReady = function()
      local top = topBattle()
      return top ~= nil and ready(top) or false
    end
    -- { id, count } of the ball a throw would use (id nil: none to throw)
    m._kimArenaQuickBallInfo = function()
      local top = topBattle()
      if not (top and ready(top)) then return nil end
      local id = pick(top)
      local inv = top.save and top.save.inventory or {}
      return { id = id, count = id and (tonumber(inv[id]) or 0) or 0 }
    end
    -- throw (or say why not) on the battle's next update
    m._kimArenaQuickBallThrow = function()
      local top = topBattle()
      if not (top and ready(top)) then return false end
      top._aioQuickBallPending = true
      return true
    end
    -- the button's art, shared by KIM Touch's floating button and the
    -- Modern battle panel's own (window units; th = a UI theme; fontFn(px))
    m._kimArenaQuickBallDraw = function(G, cx, cy, r, a, th, fontFn)
      return drawButton(m, G, cx, cy, r, a, th, fontFn)
    end
  end
  export(mod)

  local api = { pick = pick, eligible = eligible, ready = ready, export = export }
  BS._kimArenaQuickBall = api
  return api
end
