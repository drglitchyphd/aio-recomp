-- Small, window-resolution overworld shortcuts. All actions use Quick Menu's
-- native menu/item paths; pointer capture prevents a HUD tap becoming A or walking.
return function(host)
  local mod, G = host.mod, love.graphics
  local diag = host.diag or function() end
  local M, pointers, fonts = {}, {}, {}
  local function quick() return rawget(mod, "_kimArenaQuick") end
  local function enabled(game)
    local opt = rawget(mod, "_kimArenaOpt")
    local q = quick()
    return (not opt or opt("overworldHud", true) ~= false) and q and q.overworld(game)
      and not game.world.textbox and not q.wheelActive()
  end
  local function contains(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
  end
  local function font(size)
    size = math.max(9, math.floor(size))
    if not fonts[size] then
      local f = rawget(mod, "_kimArenaFont")
      fonts[size] = f and f(size) or G.newFont(size)
    end
    return fonts[size]
  end
  function M.layout(game)
    if not enabled(game) then return nil end
    local W, H = G.getDimensions()
    local actions = quick().hudActions(game)
    local gap = math.max(4, math.min(W, H) * .008)
    local size = math.min(80, math.max(44, math.min(W, H) * .075), (W * .75) / math.max(1, #actions) - gap)
    local width = #actions * (size + gap) - gap
    local safeTop, safeBottom = 0, 0
    if love.window and type(love.window.getSafeArea) == "function" then
      local _, top, _, sh = love.window.getSafeArea()
      safeTop = tonumber(top) or 0
      -- only a safe area that matches this screen (it can lag a resize)
      sh = tonumber(sh)
      if sh and sh > H * .5 and safeTop + sh <= H then safeBottom = H - (safeTop + sh) end
    end
    -- 0.9.64: HUD POSITION. Columns: left / middle / right; rows: top (the
    -- buttons above the clock panel) or bottom (the clock panel at the
    -- bottom edge, the buttons above it).
    local opt = rawget(mod, "_kimArenaOpt")
    local pos = tostring(opt and opt("hudPosition", "tr") or "tr")
    local col, row = pos:sub(2, 2), pos:sub(1, 1)
    local function colX(wide)
      if col == "l" then return gap * 2 end
      if col == "c" then return math.floor((W - wide) / 2) end
      return W - wide - gap * 2
    end
    -- Keep clear of the launcher's top-right menu without tying placement
    -- to tall-screen height (10% was 252px down on the Fold cover).
    local edge = math.max(gap * 2, math.min(W,H) * .055)
    local x, y = colX(width), safeTop + edge
    local cells = {}
    for i, a in ipairs(actions) do
      cells[i] = { x = x + (i - 1) * (size + gap), y = y, w = size, h = size, action = a }
    end
    local clockPx = math.max(20, math.min(W, H) * .038)
    -- The status strip matches the shortcut row's width: clock on the left and
    -- six party slots on the right (empty slots drawn hollow).
    local padding = math.max(8, clockPx * .3)
    local radius = math.max(4, clockPx * .18)
    local step = radius * 2 + padding * .5
    local clockW = font(clockPx):getWidth("00:00")
    local statusW = width
    local room = (statusW - padding * 3 - clockW + padding * .5) / 6
    if room < step then
      -- Narrow row: tighten the slots first, then widen the strip if needed.
      step = math.max(room, 10)
      radius = math.min(radius, step * .36)
      statusW = math.max(statusW, padding * 3 + clockW + 6 * step - padding * .5)
    else
      -- Wide row: spread the slots over the space after the clock.
      step = room
      radius = math.min(clockPx * .36, step * .42)
    end
    statusW = math.min(W - gap * 4, statusW)
    -- 0.9.62: the clock + party panel is a tap target too (opens POKeMON)
    local statusH = font(clockPx):getHeight() + padding * 2
    local statusY = y + size + gap
    if row == "b" then
      statusY = H - safeBottom - edge - statusH
      y = statusY - gap - size
      for _, c in ipairs(cells) do c.y = y end
    end
    local statusX = colX(statusW)
    local targets = {}
    for i, c in ipairs(cells) do targets[i] = c end
    targets[#targets + 1] = { x = statusX, y = statusY,
      w = statusW, h = statusH, action = { id = "party", label = "PARTY" } }
    return { cells = cells, targets = targets, x = x, y = y, w = width, size = size, gap = gap, W = W, H = H,
      clockPx = clockPx, padding = padding, radius = radius, step = step, clockW = clockW,
      statusW = statusW, statusX = statusX, statusY = statusY, pos = pos }
  end
  local function color(c, alpha) G.setColor(c[1], c[2], c[3], alpha or c[4] or 1) end
  local function theme()
    local S = rawget(mod, "_kantoInMotionGen2Ui")
    return S and S.theme and S.theme() or {
      surface = { .06, .10, .16 }, text = { .95, .98, 1 }, accent = { .45, .85, 1 },
      frame = { .32, .52, .65 }, selected = { .16, .35, .48 }, muted = { .67, .74, .80 } }
  end
  local function panel(x, y, w, h, th, held)
    color(held and th.selected or th.surface, .86)
    G.rectangle("fill", x, y, w, h, 8, 8)
    color(th.frame or th.accent, .75)
    G.setLineWidth(1.5); G.rectangle("line", x, y, w, h, 8, 8)
  end
  -- Code-drawn icons stay sharp at Fold cover, inner and desktop sizes.
  local function icon(id, x, y, s)
    G.push(); G.translate(x, y); G.scale(s / 24)
    G.setLineWidth(1.8); G.setLineJoin("bevel")
    if id == "quick" then
      for row = 0, 1 do for col = 0, 1 do
        G.rectangle("line", 3 + col * 11, 3 + row * 11, 7, 7, 1, 1)
      end end
    elseif id == "gear" then
      G.rectangle("line", 5, 2, 14, 20, 3, 3)
      G.rectangle("line", 8, 5, 8, 8, 1, 1)
      G.line(8, 17, 12, 17); G.circle("fill", 16, 17, 1)
      G.line(15, 2, 18, -1)
    elseif id == "dex" then
      G.rectangle("line", 3, 3, 18, 18, 2, 2)
      G.line(12, 4, 12, 20); G.line(6, 8, 9, 8); G.line(6, 12, 9, 12)
      G.circle("line", 16.5, 12, 2.5)
    elseif id == "pokedex" then
      G.rectangle("line", 4, 2, 16, 20, 2, 2)
      G.circle("line", 12, 9, 4); G.line(8, 16, 16, 16); G.line(8, 19, 14, 19)
    elseif id == "heal" then
      G.rectangle("line", 3, 3, 18, 18, 4, 4)
      G.rectangle("fill", 10.5, 7, 3, 10); G.rectangle("fill", 7, 10.5, 10, 3)
    elseif id == "travel" then
      G.line(3, 15, 21, 5, 13, 21, 11, 13, 3, 15)
    elseif id == "tracker" then
      -- a clipboard with ticked rows
      G.rectangle("line", 4, 3, 16, 19, 2, 2)
      G.rectangle("fill", 9, 1.5, 6, 3, 1, 1)
      G.line(7, 10, 8.5, 11.5, 11, 8.5); G.line(13, 10, 17, 10)
      G.line(7, 16, 8.5, 17.5, 11, 14.5); G.line(13, 16, 17, 16)
    elseif id == "bike" then
      G.circle("line", 5, 17, 4); G.circle("line", 20, 17, 4)
      G.line(5, 17, 10, 8, 15, 17, 5, 17, 16, 10, 20, 17)
      G.line(8, 7, 12, 7); G.line(16, 10, 15, 4, 19, 4)
    else
      G.rectangle("line", 4, 7, 16, 15, 3, 3)
      G.line(8, 7, 8, 3, 16, 3, 16, 7)
      G.rectangle("line", 8, 12, 8, 6, 1, 1)
    end
    G.pop()
  end
  function M.draw(game)
    local l = M.layout(game)
    if not l then return end
    -- where the HUD sits this frame (window units), for KIM Touch to keep
    -- its B / START / SELECT off it
    do
      local x0, y0 = math.min(l.x, l.statusX), math.min(l.y, l.statusY)
      local x1 = math.max(l.x + l.w, l.statusX + l.statusW)
      local y1 = math.max(l.y + l.size, l.statusY + font(l.clockPx):getHeight() + l.padding * 2)
      rawset(mod, "_kimArenaOverworldHudRect", { x = x0, y = y0, w = x1 - x0, h = y1 - y0, W = l.W, H = l.H,
        time = love.timer and love.timer.getTime() or 0 })
    end
    local th = theme()
    for _, r in ipairs(l.cells) do
      local held = false
      for _, p in pairs(pointers) do if p.id == r.action.id and not p.cancelled then held = true end end
      panel(r.x, r.y, r.w, r.h, th, held)
      -- 0.9.61: a button that can't act right now stays, dimmed
      local dim = r.action.disabled and .38 or nil
      color(th.accent, dim)
      icon(r.action.id, r.x + r.w * .29, r.y + r.h * .13, r.w * .42)
      local f = font(r.w * .16)
      G.setFont(f); color(dim and (th.muted or th.text) or th.text, dim)
      G.printf(r.action.label, r.x + 2, r.y + r.h * .72, r.w - 4, "center")
    end
    local f = font(l.clockPx)
    local padding = l.padding
    local h = f:getHeight() + padding * 2
    local y = l.statusY or (l.y + l.size + l.gap)
    panel(l.statusX, y, l.statusW, h, th)
    local w, time = game.world, ""
    if type(w.hour) == "function" and type(w.minute) == "function" then
      time = ("%02d:%02d"):format(w:hour(), w:minute())
    end
    G.setFont(f); color(th.text)
    G.print(time, l.statusX + padding, y + padding)
    local party = game.save and game.save.party or {}
    local radius = l.radius
    -- Slots are right-aligned; the last slot's edge sits one padding inside.
    local dotsX = l.statusX + l.statusW - padding - radius - 5 * l.step
    for i = 1, 6 do
      local mon = party[i]
      local x = dotsX + (i - 1) * l.step
      -- 0.9.64: a Poke Ball per slot. The top half carries the HP colour
      -- (green / yellow / red, grey when fainted); an empty slot is a faint
      -- outline of a ball.
      local cy = y + h / 2
      local lw = math.max(1.2, radius * .16)
      if not mon then
        color(th.muted or th.text, .45)
        G.setLineWidth(lw)
        G.circle("line", x, cy, radius - lw * .5)
        G.line(x - radius + lw, cy, x + radius - lw, cy)
        G.circle("line", x, cy, radius * .3)
      else
        local hp = tonumber(mon.hp) or 0
        local max = tonumber(mon.maxHp or (mon.stats and mon.stats.hp)) or math.max(1, hp)
        if hp <= 0 then G.setColor(.42, .44, .48, 1)
        elseif hp / math.max(1, max) <= .2 then G.setColor(1, .34, .32, 1)
        elseif hp / math.max(1, max) <= .5 then G.setColor(1, .76, .27, 1)
        else G.setColor(.34, .88, .59, 1) end
        G.arc("fill", x, cy, radius, math.pi, math.pi * 2)       -- top half
        G.setColor(.94, .95, .96, hp <= 0 and .7 or 1)
        G.arc("fill", x, cy, radius, 0, math.pi)                 -- bottom half
        G.setColor(.08, .09, .11, 1)
        G.setLineWidth(lw)
        G.circle("line", x, cy, radius)
        G.line(x - radius, cy, x + radius, cy)                    -- band
        G.setColor(.94, .95, .96, 1)
        G.circle("fill", x, cy, radius * .3)                      -- button
        G.setColor(.08, .09, .11, 1)
        G.circle("line", x, cy, radius * .3)
      end
    end
  end
  mod.hooks:wrap("render.hud", function(nextFn, game, viewport)
    local result = nextFn(game, viewport)
    G.push("all"); G.origin()
    local ok, err = pcall(M.draw, game)
    G.pop()
    if not ok then diag("overworld hud", tostring(err):sub(1, 120)) end
    return result
  end, 32000)

  mod.hooks:wrap("input.pointer", function(nextFn, game, ev)
    if type(ev) ~= "table" then return nextFn(game, ev) end
    local p = pointers[ev.id]
    if p then
      if ev.phase == "cancelled" or p.game ~= game then
        pointers[ev.id] = nil
        return true
      end
      if p.wheel then
        local q = quick()
        if q and q.wheelActive() then
          if ev.phase == "moved" then q.wheelHover(ev.x, ev.y)
          elseif ev.phase == "released" then q.wheelRelease(ev.x, ev.y, true) end
        end
      else
        local l = M.layout(game)
        local match
        for _, r in ipairs(l and l.targets or {}) do
          if r.action.id == p.id and l.W == p.W and l.H == p.H then match = r end
        end
        if not match or not contains(match, ev.x, ev.y) then p.cancelled = true end
        if ev.phase == "released" and not p.cancelled then quick().hudActivate(game, p.id) end
      end
      if ev.phase == "released" or ev.phase == "cancelled" then pointers[ev.id] = nil end
      return true
    end
    if ev.phase ~= "pressed" or (ev.button and ev.button ~= 1) then return nextFn(game, ev) end
    -- KIM Touch owns the touch wheel; also allow desktop mouse selection.
    local q = quick()
    if ev.source == "mouse" and q and q.wheelActive() then
      pointers[ev.id] = { wheel = true, game = game }; q.wheelHover(ev.x, ev.y); return true
    end
    local l = M.layout(game)
    for _, r in ipairs(l and l.targets or {}) do
      if contains(r, ev.x, ev.y) then
        pointers[ev.id] = { id = r.action.id, W = l.W, H = l.H, game = game }
        return true
      end
    end
    return nextFn(game, ev)
  end, 200)
  return M
end
