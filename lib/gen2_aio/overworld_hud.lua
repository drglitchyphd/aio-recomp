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
    local safeTop = 0
    if love.window and type(love.window.getSafeArea) == "function" then
      local _, top = love.window.getSafeArea()
      safeTop = tonumber(top) or 0
    end
    -- Keep clear of the launcher's top-right menu without tying placement
    -- to tall-screen height (10% was 252px down on the Fold cover).
    local x, y = W - width - gap * 2, safeTop + math.max(gap * 2, math.min(W,H) * .055)
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
      radius = math.min(clockPx * .3, step * .36)
    end
    statusW = math.min(W - gap * 4, statusW)
    return { cells = cells, x = x, y = y, w = width, size = size, gap = gap, W = W, H = H,
      clockPx = clockPx, padding = padding, radius = radius, step = step, clockW = clockW,
      statusW = statusW, statusX = W - statusW - gap * 2 }
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
    local th = theme()
    for _, r in ipairs(l.cells) do
      local held = false
      for _, p in pairs(pointers) do if p.id == r.action.id and not p.cancelled then held = true end end
      panel(r.x, r.y, r.w, r.h, th, held)
      color(th.accent)
      icon(r.action.id, r.x + r.w * .29, r.y + r.h * .13, r.w * .42)
      local f = font(r.w * .16)
      G.setFont(f); color(th.text)
      G.printf(r.action.label, r.x + 2, r.y + r.h * .72, r.w - 4, "center")
    end
    local f = font(l.clockPx)
    local padding = l.padding
    local h = f:getHeight() + padding * 2
    local y = l.y + l.size + l.gap
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
      if not mon then
        color(th.muted or th.text, .55)
        G.setLineWidth(math.max(1.5, radius * .25))
        G.circle("line", x, y + h / 2, radius - .5)
      else
        local hp = tonumber(mon.hp) or 0
        local max = tonumber(mon.maxHp or (mon.stats and mon.stats.hp)) or math.max(1, hp)
        -- Fainted is a solid grey dot so it is not mistaken for an empty slot.
        if hp <= 0 then G.setColor(.42, .44, .48, 1)
        elseif hp / math.max(1, max) <= .2 then G.setColor(1, .34, .32, 1)
        elseif hp / math.max(1, max) <= .5 then G.setColor(1, .76, .27, 1)
        else G.setColor(.34, .88, .59, 1) end
        G.circle("fill", x, y + h / 2, radius)
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
        for _, r in ipairs(l and l.cells or {}) do
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
    for _, r in ipairs(l and l.cells or {}) do
      if contains(r, ev.x, ev.y) then
        pointers[ev.id] = { id = r.action.id, W = l.W, H = l.H, game = game }
        return true
      end
    end
    return nextFn(game, ev)
  end, 200)
  return M
end
