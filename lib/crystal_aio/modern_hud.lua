-- gen2-aio modern battle HUD for Gold/Silver/Crystal.
--
-- Kanto in Motion's Gen 2 Modern UI redraws only the lower battle panel; the
-- name / level / HP / EXP boxes stay Crystal's tile HUD. This module replaces
-- those boxes with cards in the same theme as KIM's panel:
--
--   * battle.status_hud_visible answers false, the engine's official switch,
--     so the native HUD (and every capture of it in gmarc's 3D battle)
--     draws nothing;
--   * render.hud draws the cards at window resolution, reading the same
--     values the native HUD reads (animated HP, chased EXP fill, status tag,
--     gender, caught marker, party balls).
--
-- Gameplay, input and battle state are untouched.

return function(host)
  local mod = host.mod
  local G = love and love.graphics
  if not G then return nil end

  local okChrome, Chrome = pcall(require, "src.ui.gen2.Chrome")
  local okHud, NativeHud = pcall(require, "src.ui.gen2.BattleHud")
  local EXP_PX = okHud and type(NativeHud) == "table"
    and tonumber(NativeHud.EXP_LENGTH_PX) or 64

  local M = {}

  local function opt(key, default)
    local ok, value = pcall(mod.options.get, mod.options, key)
    if ok and value ~= nil then return value end
    return default
  end

  local function style()
    return rawget(mod, "_kantoInMotionGen2Ui")
  end

  function M.enabled()
    if M.failed then return false end
    if tonumber(mod.generation) ~= 2 then return false end
    if opt("arenaHud", "modern") ~= "modern" then return false end
    local S = style()
    if not S then return false end
    if type(S.presenterEnabled) == "function" then
      local ok, on = pcall(S.presenterEnabled, "battle")
      if ok and on == false then return false end
    end
    return true
  end

  local function isBattle(state)
    return type(state) == "table" and state.isBattle == true and state.battle ~= nil
  end

  local function topBattle(game)
    local stack = game and game.stack
    local top = stack and type(stack.top) == "function" and stack:top() or nil
    if isBattle(top) and top.phase ~= nil then return top end
    return nil
  end

  local function call(state, name, ...)
    local fn = state and state[name]
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, state, ...)
    if ok then return a end
    return nil
  end

  local function mobileHost()
    local fn = rawget(mod, "_kantoInMotionNativeMobileHost")
    if type(fn) == "function" then
      local ok, value = pcall(fn)
      if ok then return value == true end
    end
    return false
  end

  -- ------------------------------------------------------------ drawing
  local HP_GREEN = { 0.30, 0.86, 0.38, 1 }
  local HP_YELLOW = { 0.97, 0.80, 0.18, 1 }
  local HP_RED = { 0.96, 0.30, 0.26, 1 }
  local EXP_BLUE = { 0.30, 0.62, 1.00, 1 }
  local MALE = { 0.40, 0.68, 1.00, 1 }
  local FEMALE = { 1.00, 0.52, 0.70, 1 }
  local STATUS = {
    poison = { 0.66, 0.36, 0.86, 1 }, toxic = { 0.66, 0.36, 0.86, 1 },
    burn = { 0.95, 0.47, 0.20, 1 }, freeze = { 0.42, 0.80, 0.95, 1 },
    paralyze = { 0.92, 0.78, 0.14, 1 }, sleep = { 0.60, 0.62, 0.68, 1 },
  }

  local function setColor(c, a)
    local S = style()
    if S and S.color then return S.color(c, a, true) end
    G.setColor(c[1], c[2], c[3], (a or c[4] or 1))
  end

  local function font(px)
    local S = style()
    if S and S.font then return S.font(px) end
    return G.getFont()
  end

  local function text(value, f, x, y, w, align, c)
    local S = style()
    if S and S.text then return S.text(value, f, x, y, w, align, c) end
    G.setFont(f); setColor(c); G.printf(tostring(value), x, y, w, align or "left")
  end

  local function panel(x, y, w, h, theme)
    local S = style()
    if S and S.panel then return S.panel(x, y, w, h, theme) end
    setColor(theme.surface); G.rectangle("fill", x, y, w, h, 6, 6)
    setColor(theme.frame or theme.accent); G.rectangle("line", x, y, w, h, 6, 6)
  end

  local function bar(x, y, w, h, fraction, fill, theme)
    fraction = math.max(0, math.min(1, fraction or 0))
    local r = h / 2
    setColor({ 0, 0, 0, 1 }, 0.45)
    G.rectangle("fill", x, y, w, h, r, r)
    if fraction > 0 then
      setColor(fill)
      G.rectangle("fill", x, y, math.max(h, w * fraction), h, r, r)
      setColor({ 1, 1, 1, 1 }, 0.22)
      G.rectangle("fill", x + r * 0.5, y + h * 0.12, math.max(0, w * fraction - r), h * 0.28, r, r)
    end
    setColor(theme.divider or theme.muted, 0.9)
    G.setLineWidth(math.max(1, h * 0.12))
    G.rectangle("line", x, y, w, h, r, r)
  end

  local function hpColor(fraction)
    if fraction > 0.5 then return HP_GREEN end
    if fraction > 10 / 48 then return HP_YELLOW end
    return HP_RED
  end

  local function pill(label, x, y, h, f, fill)
    local w = f:getWidth(label) + h * 0.8
    setColor(fill)
    G.rectangle("fill", x, y, w, h, h * 0.3, h * 0.3)
    text(label, f, x, y + (h - f:getHeight()) / 2, w, "center", { 0.05, 0.05, 0.07, 1 })
    return w
  end

  -- Drawn, not printed: the UI fonts have no glyphs for these symbols.
  local function genderGlyph(x, y, size, female)
    local r = size * 0.27
    local cx, cy = x + size * 0.40, y + (female and size * 0.40 or size * 0.58)
    setColor(female and FEMALE or MALE)
    G.setLineWidth(math.max(1.5, size * 0.11))
    G.circle("line", cx, cy, r)
    if female then
      G.line(cx, cy + r, cx, cy + r + size * 0.36)
      G.line(cx - size * 0.15, cy + r + size * 0.19, cx + size * 0.15, cy + r + size * 0.19)
    else
      local d = r * 0.7071
      local tx, ty = cx + d + size * 0.26, cy - d - size * 0.26
      G.line(cx + d, cy - d, tx, ty)
      G.line(tx, ty, tx - size * 0.20, ty)
      G.line(tx, ty, tx, ty + size * 0.20)
    end
    return size * 0.85
  end

  local function caughtBall(cx, cy, r)
    setColor({ 0.92, 0.25, 0.22, 1 })
    G.arc("fill", cx, cy, r, math.pi, 2 * math.pi)
    setColor({ 0.97, 0.97, 0.97, 1 })
    G.arc("fill", cx, cy, r, 0, math.pi)
    setColor({ 0.08, 0.08, 0.1, 1 })
    G.setLineWidth(math.max(1, r * 0.22))
    G.circle("line", cx, cy, r)
    G.line(cx - r, cy, cx + r, cy)
    setColor({ 0.97, 0.97, 0.97, 1 })
    G.circle("fill", cx, cy, r * 0.32)
  end

  -- 0.9.74: the party rows are little Poke Balls, drawn like the overworld
  -- HUD's (lib/crystal_aio/overworld_hud.lua): the top half in the HP colour
  -- (yellow for a status, grey when fainted), a white bottom, black band and
  -- button; an empty slot is a faint outline of a ball
  local function partyBalls(party, x, y, r, step, theme)
    local lw = math.max(1, r * 0.16)
    for i = 1, 6 do
      local mon = type(party) == "table" and party[i] or nil
      local cx = x + (i - 1) * step
      if mon then
        local hp = tonumber(mon.hp) or 0
        local max = tonumber(mon.maxHp or (mon.stats and mon.stats.hp)) or math.max(1, hp)
        local statused = mon.status ~= nil and mon.status ~= false and mon.status ~= ""
        if hp <= 0 then setColor({ 0.42, 0.44, 0.48, 1 })
        elseif statused then setColor(HP_YELLOW)
        elseif hp / math.max(1, max) <= 0.2 then setColor({ 1, 0.34, 0.32, 1 })
        elseif hp / math.max(1, max) <= 0.5 then setColor(HP_YELLOW)
        else setColor(HP_GREEN) end
        G.arc("fill", cx, y, r, math.pi, 2 * math.pi)
        setColor({ 0.94, 0.95, 0.96, hp <= 0 and 0.7 or 1 })
        G.arc("fill", cx, y, r, 0, math.pi)
        setColor({ 0.08, 0.09, 0.11, 1 })
        G.setLineWidth(lw)
        G.circle("line", cx, y, r)
        G.line(cx - r, y, cx + r, y)
        setColor({ 0.94, 0.95, 0.96, 1 })
        G.circle("fill", cx, y, r * 0.3)
        setColor({ 0.08, 0.09, 0.11, 1 })
        G.circle("line", cx, y, r * 0.3)
      else
        setColor(theme.muted or theme.text, 0.45)
        G.setLineWidth(lw)
        G.circle("line", cx, y, r - lw * 0.5)
        G.line(cx - r + lw, y, cx + r - lw, y)
        G.circle("line", cx, y, r * 0.3)
      end
    end
  end

  -- Height a card will take, so it can be placed before it is drawn.
  local function cardHeight(side, fit)
    local pad = 4 * fit
    local nameH, smallH = font(7.2 * fit):getHeight(), font(5.4 * fit):getHeight()
    local barH = math.max(4, 3.4 * fit)
    local h = pad + nameH + 2 * fit + barH + pad
    if side == "player" then h = h + smallH + 1.5 * fit + math.max(3, 2.2 * fit) + 2 * fit end
    return h
  end

  -- KIM's lower battle panel as it was drawn this frame (window units), or
  -- nil. Its position depends on KIM's layout for the screen shape: tall,
  -- narrow phones (Fold cover screens) put it mid-screen above the touch pad.
  local function kimPanel(state)
    local ui = mod.exports and mod.exports.gen2ModernBattleUi
    if not (ui and type(ui.tapTargets) == "function") then return nil end
    local ok, t = pcall(ui.tapTargets)
    if not ok or type(t) ~= "table" or t.state ~= state then return nil end
    local p = t.panel
    if type(p) ~= "table" or not (tonumber(p.y) and tonumber(p.h)) then return nil end
    return p
  end

  -- The engine's quick-menu button ("•••"), which the cards must not cover.
  local okTC, TouchControls = pcall(require, "src.core.TouchControls")
  local function hotbarZone()
    if not (okTC and type(TouchControls) == "table") then return nil end
    local okV, visible = pcall(TouchControls.visible, TouchControls)
    if not okV or not visible then return nil end
    local okShown, shown = pcall(TouchControls.hotbarShown, TouchControls)
    if okShown and shown == false then return nil end
    local okL, L = pcall(TouchControls.layout, TouchControls)
    local z = okL and type(L) == "table" and L.hotbar or nil
    if not (z and tonumber(z.cx) and tonumber(z.cy) and tonumber(z.w)) then return nil end
    return z
  end

  local function overlaps(z, x, y, w, h)
    local r = z.w * 0.75
    return z.cx + r > x and z.cx - r < x + w and z.cy + r > y and z.cy - r < y + h
  end

  -- One status card. side: "enemy" | "player".
  local function card(state, side, x, y, w, fit, theme)
    local mon = call(state, "activeMon", side)
    if not mon then return nil end
    local pad = 4 * fit
    local nameFont = font(7.2 * fit)
    local smallFont = font(5.4 * fit)
    local nameH, smallH = nameFont:getHeight(), smallFont:getHeight()
    local barH = math.max(4, 3.4 * fit)
    local isPlayer = side == "player"
    local h = pad + nameH + 2 * fit + barH + pad
    if isPlayer then h = h + smallH + 1.5 * fit + math.max(3, 2.2 * fit) + 2 * fit end

    panel(x, y, w, h, theme)
    local ix, iw = x + pad, w - pad * 2
    local cy = y + pad

    -- name row: [caught] NAME [STATUS]          [gender] Lv
    local nx = ix
    if side == "enemy" and call(state, "caughtMarkerVisible") then
      local r = nameH * 0.32
      caughtBall(nx + r, cy + nameH * 0.52, r)
      nx = nx + r * 2 + 2 * fit
    end
    local level = isPlayer and (state.shownLevel or mon.level) or mon.level
    local levelText = "Lv" .. tostring(level or 1)
    local levelW = smallFont:getWidth(levelText)
    local gender = call(state, "genderSymbol", mon)
    local glyph = smallH * 1.05
    local genderW = gender and glyph * 0.85 + 2 * fit or 0
    local status = call(state, "hudStatus", mon, side)
    local tag = call(state, "statusTag", mon, side)
    local tagW = 0
    if tag then tagW = smallFont:getWidth(tag) + smallH * 0.8 + 2 * fit end
    local nameRoom = math.max(10, ix + iw - levelW - genderW - tagW - 3 * fit - nx)
    local name = tostring(call(state, "name", mon) or "?")
    while #name > 1 and nameFont:getWidth(name) > nameRoom do name = name:sub(1, -2) end
    text(name, nameFont, nx, cy, nameRoom, "left", theme.text)
    if tag then
      pill(tag, nx + nameFont:getWidth(name) + 3 * fit,
        cy + (nameH - smallH * 1.15) / 2, smallH * 1.15, smallFont,
        STATUS[status] or theme.accent)
    end
    text(levelText, smallFont, ix + iw - levelW, cy + (nameH - smallH) * 0.7, levelW, "right", theme.muted)
    if gender then
      genderGlyph(ix + iw - levelW - genderW, cy + (nameH - glyph) / 2, glyph,
        gender ~= "\xe2\x99\x82")
    end
    cy = cy + nameH + 2 * fit

    -- HP bar
    local maxHp = tonumber(mon.maxHp or (mon.stats and mon.stats.hp)) or 0
    local hp = tonumber(call(state, "hudHp", mon, side)) or tonumber(mon.hp) or 0
    local pixels = tonumber(call(state, "hudHpPixels", mon, side))
    local fraction = pixels and pixels / 48 or (maxHp > 0 and hp / maxHp or 0)
    local labelW = smallFont:getWidth("HP") + 2.5 * fit
    text("HP", smallFont, ix, cy + (barH - smallH) / 2, labelW, "left", theme.accent)
    bar(ix + labelW, cy, iw - labelW, barH, fraction, hpColor(fraction), theme)
    cy = cy + barH

    if isPlayer then
      cy = cy + 1.5 * fit
      text(("%d/%d"):format(math.floor(hp + 0.5), maxHp), smallFont, ix, cy, iw, "right", theme.text)
      cy = cy + smallH + 2 * fit
      local expH = math.max(3, 2.2 * fit)
      local expLabel = smallFont:getWidth("EXP") + 2.5 * fit
      text("EXP", smallFont, ix, cy + (expH - smallH) / 2, expLabel, "left", theme.muted)
      bar(ix + expLabel, cy, iw - expLabel, expH, (tonumber(state.shownExp) or 0) / EXP_PX,
        EXP_BLUE, theme)
    end
    return h
  end

  local function draw(game, state, viewport)
    local winW, winH = G.getDimensions()
    local uiScale = math.max(0.6, math.min(1.5, (tonumber(opt("battleUiSize", "100")) or 100) / 100))
    local fit = math.min(winW / 170, winH / 144) * uiScale
    local S = style()
    local theme = (S and S.theme and S.theme()) or {
      surface = { .075, .105, .17, .96 }, text = { .96, .98, 1, 1 },
      muted = { .74, .82, .92, 1 }, accent = { .48, .86, 1, 1 },
      divider = { .38, .5, .68, .94 }, frame = { .48, .86, 1, 1 },
    }

    -- the playfield the HUD may use (notches / letterboxed layouts)
    local px, py, pw, ph = 0, 0, winW, winH
    if okChrome and Chrome and type(Chrome.playfieldRect) == "function" then
      local ok, a, b, c, d = pcall(Chrome.playfieldRect, winW, winH)
      if ok and tonumber(c) and tonumber(d) and c > 0 and d > 0 then px, py, pw, ph = a, b, c, d end
    end
    local margin = 4 * fit
    local cardW = math.min(pw * 0.48, 82 * fit)
    local topY = py + (mobileHost() and math.max(margin, ph * 0.075) or margin)
    -- keep the enemy card clear of the "•••" quick-menu button
    local hz = hotbarZone()
    if hz and overlaps(hz, px + margin, topY, cardW, cardHeight("enemy", fit)) then
      topY = hz.cy + hz.w * 0.75 + margin * 0.5
    end
    local party = state.battle

    G.push("all")
    G.origin()
    local okDraw, err = pcall(function()
    -- enemy: top-left
    local enemyShown = state.showEnemyHud
    local eh = enemyShown and card(state, "enemy", px + margin, topY, cardW, fit, theme) or nil
    if state.ballRows and state.ballRows.enemy then
      local r = 2.9 * fit
      partyBalls(party and party.enemyParty, px + margin + r + 2 * fit,
        topY + (eh or 0) + r + 2.5 * fit, r, r * 2.5, theme)
    end
    -- player: right, ending just above KIM's lower battle panel wherever
    -- KIM placed it this frame; the estimate is only a fallback
    local playerH = cardHeight("player", fit)
    local enemyBottom = topY + cardHeight("enemy", fit) + margin
    local panel = kimPanel(state)
    local bottom
    if panel then
      -- both cards' frames (and the panel's) draw a few px outside their
      -- rects, so leave room for two frame thicknesses plus a small gap
      bottom = panel.y - margin - 6 * fit
    else
      local portrait = winH > winW * 1.18
      local reserve = ((portrait and 60 or 48) * 0.95 + 2) * fit
      bottom = math.min(py + ph * 0.66, py + ph - reserve - margin * 1.5)
    end
    local playerY = math.max(enemyBottom, bottom - playerH)
    local playerX = px + pw - cardW - margin
    -- gen2-aio: where the cards sit, for the locked KENNEY HD camera to
    -- keep the Pokemon clear of them (window units)
    mod._kimArenaHudRects = {
      W = winW, H = winH, state = state,
      time = love.timer and love.timer.getTime() or 0,   -- 0.9.46 (touch long press)
      enemyShown = state.showEnemyHud and true or false,
      playerShown = state.showPlayerHud and true or false,
      enemy = { x = px + margin, y = topY, w = cardW, h = cardHeight("enemy", fit) },
      player = { x = playerX, y = playerY, w = cardW, h = playerH },
      panelTop = panel and panel.y or nil,
    }
    if state.showPlayerHud then card(state, "player", playerX, playerY, cardW, fit, theme) end
    if state.ballRows and state.ballRows.player then
      local r = 2.9 * fit
      partyBalls(party and party.party, playerX + cardW - r - 2 * fit - r * 2.5 * 5,
        playerY - r - 2.5 * fit, r, r * 2.5, theme)
    end
    end)
    G.pop()
    if not okDraw then error(err, 0) end
  end

  -- ------------------------------------------------------------ hooks
  mod.hooks:wrap("battle.status_hud_visible", function(nextFn, state)
    if isBattle(state) and M.enabled() then return false end
    return nextFn(state)
  end, 26000)

  mod.hooks:wrap("render.hud", function(nextFn, game, viewport)
    local result = { pcall(nextFn, game, viewport) }
    local ok = table.remove(result, 1)
    if not ok then error(result[1], 0) end
    if M.enabled() then
      local state = topBattle(game)
      if state then
        local drawn, err = pcall(draw, game, state, viewport)
        if not drawn then
          -- Never leave a battle without a HUD: give it back to the native one.
          M.failed = true
          if mod.log and mod.log.warn then
            pcall(mod.log.warn, mod.log, "Crystal-AiO modern HUD disabled: %s", tostring(err))
          end
        end
      end
    end
    return (table.unpack or unpack)(result)
  end, 25500)

  return M
end
