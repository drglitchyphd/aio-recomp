-- gen2-aio 0.9.27: HIT FLICKER = STEADY, at the engine seam.
--
-- Crystal's damage animation blinks the target: BattleAnim_EnemyDamage is
-- HIDE_MON / wait / SHOW_MON / wait, three times, and other moves clear the
-- pic for a frame or two. 0.9's fix lived only in gmarc's 3D card capture
-- (GoldBattle.lua keeps the last card for 0.25 s), so any path that draws
-- the Pokemon itself -- KIM's HD drawPic over a painting, the 2D battle, a
-- card captured fresh because the gmarc entry was rebuilt -- blinked again.
--
-- This answers the question every renderer asks, BattleState:animPicState
-- (and picBoxCleared, which is built on it): a hide that has lasted less
-- than HOLD reads as "still shown". Real hides are left alone:
--   * anything still hidden after HOLD (Fly, Dig, Substitute's swap, ...)
--   * the end state of an animation (picHidden: send-out, return, faint)
--   * Fly / Dig's own vanish animation (vanishAnim), from its first frame
--   * a hide that follows a shrink (RETURN_MON / Baton Pass pic resize)
return function(host)
  local mod = host.mod
  local diag = host.diag or function() end
  -- DIAGNOSTICS `hits`: proves the seam is reached and what the last hides
  -- looked like (how long, held or not), so a remaining blink can be traced
  local hides, held, lastMs, lastWhy = 0, 0, nil, "-"
  local function report()
    diag("hits", ("%d hides, %d held; last %s ms (%s)"):format(hides, held,
      lastMs and tostring(lastMs) or "-", lastWhy))
  end
  local ok, BS = pcall(require, "src.ui.gen2.BattleState")
  if not (ok and type(BS) == "table" and type(BS.animPicState) == "function") then return nil end
  if BS._kimArenaSteady then return BS._kimArenaSteady end

  local HOLD = 0.25
  local function steady()
    local okO, v = pcall(mod.options.get, mod.options, "hitFlicker")
    return not (okO and v == "flicker")
  end
  local function now()
    if love and love.timer and love.timer.getTime then return love.timer.getTime() end
    return os.clock()
  end

  -- 0.9.29 DIAGNOSTICS `anim fx`: what each battle animation actually did to
  -- the battlers -- the BG effects it queued and which visibility levers moved
  -- (hidden / shade / size / slide / lcdc). The 0.9.28 phone test showed no
  -- `hits` line at all after a flickering hit, i.e. the blink is not the
  -- hidden flag; this names the real lever.
  local summaries, calls = {}, 0
  local function pushSummary(rec)
    if not rec or not rec.id then return end
    local fx = {}
    for i, n in ipairs(rec.fx) do
      if i > 6 then fx[#fx + 1] = "+" .. (#rec.fx - 6); break end
      fx[#fx + 1] = (tostring(n):gsub("^BATTLE_BG_EFFECT_", ""))
    end
    local lev = {}
    for k in pairs(rec.levers) do lev[#lev + 1] = k end
    table.sort(lev)
    table.insert(summaries, 1, ("%s[%s]%s"):format((tostring(rec.id):gsub("^ANIM_", "")),
      table.concat(fx, ","), #lev > 0 and (" " .. table.concat(lev, "/")) or ""))
    while #summaries > 3 do table.remove(summaries) end
    diag("anim fx", table.concat(summaries, "; "))
  end
  local patchedPools = setmetatable({}, { __mode = "k" })
  local current
  local function watchAnim(self)
    local anim = self.anim
    if current and current.anim ~= anim then pushSummary(current); current = nil end
    if not anim then return end
    local bg = anim.bg
    if not current then
      current = { anim = anim, id = anim.animId or "?", fx = {}, levers = {} }
      local mt = type(bg) == "table" and getmetatable(bg)
      local cls = mt and type(mt.__index) == "table" and mt.__index
      if cls and type(cls.queue) == "function" and not patchedPools[cls] then
        patchedPools[cls] = true
        local q = cls.queue
        cls.queue = function(pool, effectId, ...)
          local rec = current
          if rec and rec.anim and rec.anim.bg == pool then
            local name = effectId
            if type(effectId) == "number" and pool.order then name = pool.order[effectId + 1] or effectId end
            if #rec.fx < 40 then rec.fx[#rec.fx + 1] = name end
          end
          return q(pool, effectId, ...)
        end
      end
    end
    if type(bg) == "table" then
      for _, sd in ipairs({ "player", "enemy" }) do
        if bg.hidden and bg.hidden[sd] then current.levers["hidden:" .. sd] = true end
        if bg.monShade and bg.monShade[sd] and bg.monShade[sd] ~= 0xe4 then
          current.levers[("shade%02x:%s"):format(bg.monShade[sd], sd)] = true
        end
        if bg.picSize and bg.picSize[sd] ~= nil then current.levers["size:" .. sd] = true end
        if bg.slide and (bg.slide[sd] or 0) ~= 0 then current.levers["slide:" .. sd] = true end
      end
      if bg.lcdc ~= nil then current.levers["lcdc"] = true end
      if bg.bgp and bg.bgp ~= 0xe4 then current.levers[("bgp%02x"):format(bg.bgp)] = true end
    end
  end

  local orig = BS.animPicState
  BS.animPicState = function(self, side, ...)
    calls = calls + 1
    if calls == 1 then diag("hits", "seam reached, 0 hides") end
    pcall(watchAnim, self)
    local st = orig(self, side, ...)
    if type(st) ~= "table" or side == nil then return st end
    local book = rawget(self, "_kimSteady")
    if not book then book = {}; rawset(self, "_kimSteady", book) end
    local rec = book[side]
    if not st.hidden then
      if rec and rec.t then
        lastMs = math.floor((now() - rec.t) * 1000 + 0.5)
        pcall(report)
      end
      book[side] = { lastSize = st.size }
      return st
    end
    if not rec or rec.anim ~= self.anim or rec.t == nil then
      rec = { anim = self.anim, t = now(),
        afterShrink = rec ~= nil and rec.lastSize ~= nil }
      book[side] = rec
      hides = hides + 1
      lastWhy = "shown"
    end
    local function why(w) if rec.why ~= w then rec.why = w; lastWhy = w; pcall(report) end end
    if not steady() then why("FLICKER set"); return st end
    if rec.afterShrink then why("after shrink"); return st end
    if self.picHidden and self.picHidden[side] then why("end state"); return st end
    if self.vanishAnim and self.vanishAnim == self.anim then why("fly/dig"); return st end
    if now() - rec.t >= HOLD then why("long hide"); return st end
    if not rec.counted then rec.counted = true; held = held + 1; why("held") end
    local copy = {}
    for k, v in pairs(st) do copy[k] = v end
    copy.hidden = false
    return copy
  end

  -- 0.9.30: THE ACTUAL BLINK. KIM's BattleAnimView.present wrapper handles
  -- scanline effects (VIBRATE_MON, SHAKE_SCREEN, wavy screens: anything
  -- BattleAnimView.needsCanvas says rasterises the field) in two passes: a
  -- low-res bake with KIM's battlers left OUT, then an HD overlay of both
  -- battlers -- but only for the BattleState it recorded in drawSceneBody.
  -- gmarc's 3D battle captures each Pokemon's card by calling present()
  -- itself, outside drawSceneBody, so the overlay never ran and the card
  -- came out empty for every frame of the effect: the hit / stat-down
  -- "flicker" (0.9.29 diagnostics: VIBRATE_MON + lcdc, never `hidden`).
  -- Outside drawSceneBody, draw the caller's battler once more after the
  -- bake, now that KIM's bake pass is over and its drawPic paints HD.
  local redraws = 0
  local okV, View = pcall(require, "src.ui.gen2.BattleAnimView")
  if okV and type(View) == "table" and type(View.present) == "function"
      and type(View.needsCanvas) == "function" and type(BS.drawSceneBody) == "function"
      and not View._kimArenaSteadyPresent then
    View._kimArenaSteadyPresent = true
    local sceneDepth = 0
    local origBody = BS.drawSceneBody
    BS.drawSceneBody = function(self, ...)
      sceneDepth = sceneDepth + 1
      local r = { pcall(origBody, self, ...) }
      sceneDepth = sceneDepth - 1
      if not r[1] then error(r[2], 0) end
      return unpack(r, 2)
    end
    -- 0.9.44: the redraw also carries the effect's motion (VIBRATE_MON's
    -- shake, SHAKE_SCREEN, wavy rows): the same SCX/SCY + per-row LY offset
    -- KIM's overlay pass applies (kim_main gen2HdAnimMotion), sampled at the
    -- middle row of the battler being drawn (enemy pic rows 0-55, player
    -- 40-87 in Crystal's 160x144 layout).
    local function signed(v) v = (tonumber(v) or 0) % 256; return v < 0x80 and v or v - 256 end
    local function motion(runner, row)
      local bg = runner and runner.bg
      if type(bg) ~= "table" then return 0, 0 end
      local dx, dy = -signed(bg.scx), -signed(bg.scy)
      local lyStart, lyEnd = tonumber(bg.lyStart) or 0, tonumber(bg.lyEnd) or 0
      if bg.lcdc and bg.lcdc ~= "BGP" and row > lyStart and row <= lyEnd then
        local off = signed(type(bg.lyBackup) == "table" and (bg.lyBackup[row - 1] or 0) or 0)
        if bg.lcdc == "SCX" then dx = dx - off elseif bg.lcdc == "SCY" then dy = dy - off end
      end
      return dx, dy
    end
    local redrawRunner = nil
    if type(BS.drawPic) == "function" then
      local origDrawPic = BS.drawPic
      BS.drawPic = function(self, mon, back, ...)
        if redrawRunner then
          local okM, dx, dy = pcall(motion, redrawRunner, back and 64 or 28)
          if okM and (dx ~= 0 or dy ~= 0) then
            local G = love.graphics
            G.push(); G.translate(dx, dy)
            local r = { pcall(origDrawPic, self, mon, back, ...) }
            G.pop()
            if not r[1] then error(r[2], 0) end
            return unpack(r, 2)
          end
        end
        return origDrawPic(self, mon, back, ...)
      end
    end
    local origPresent = View.present
    View.present = function(view, runner, drawBg, battle, ...)
      local r = { origPresent(view, runner, drawBg, battle, ...) }
      if sceneDepth == 0 and type(drawBg) == "function"
          and View._kantoInMotionGen2HdPresent then
        local okN, needs = pcall(View.needsCanvas, runner)
        if okN and needs then
          redrawRunner = runner
          local okD = pcall(drawBg)
          redrawRunner = nil
          if okD then
            redraws = redraws + 1
            if redraws == 1 or redraws % 30 == 0 then
              diag("hits", ("%d hides, %d held; %d hd redraws"):format(hides, held, redraws))
            end
          end
        end
      end
      return unpack(r)
    end
  end

  local api = { HOLD = HOLD }
  BS._kimArenaSteady = api
  return api
end
