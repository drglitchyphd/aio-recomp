-- KIM_ARENA: TIME OF DAY.
--
-- One setting decides what time it is for EVERYTHING that asks Crystal's
-- clock (World:hour / minute / weekday): the day/night palettes, the voxel
-- sky (gmarc's DAYTIME is held at SYNC, which reads that same clock), the
-- morning / day / night encounter tables, Wilds' spawns, NPC schedules,
-- weekday events, the Pokegear clock and the random-rain clock.
--
--   SYNC     the device's own clock (not the offset set at a new game)
--   MORNING  07:00   DAY 13:00   EVENING 18:30   NIGHT 23:00   (held)
--   CYCLE    a full day every 30 real minutes, running from the device
--            clock, so it carries on across sessions; weekdays advance
--            with it (one per 30 minutes)
--   CRYSTAL  Crystal's own clock, as set in the game (the old behaviour)
--
-- Crystal's periods: MORN 4:00-9:59, DAY 10:00-17:59, NITE 18:00-3:59.
return function(host)
  local mod = host.mod
  local ok, World = pcall(require, "src.world.gen2.World")
  if not ok or type(World) ~= "table" or type(World.hour) ~= "function" then return nil end
  if World._kimArenaTime then return World._kimArenaTime end

  local FIXED = { morning = 7.0, day = 13.0, evening = 18.5, night = 23.0 }
  local CYCLE_SECONDS = 30 * 60
  -- 0.9.45: CYCLE 30 ("cycle", the original) and CYCLE 60 ("cycle60")
  local CYCLES = { cycle = 30 * 60, cycle60 = 60 * 60 }

  local function mode()
    local okO, v = pcall(mod.options.get, mod.options, "timeOfDay")
    return okO and type(v) == "string" and v or "sync"
  end

  -- fractional hour, or nil for Crystal's own clock
  local function hourNow()
    local m = mode()
    if FIXED[m] then return FIXED[m] end
    if m == "sync" then
      local d = os.date("*t")
      return d.hour + d.min / 60 + d.sec / 3600
    end
    if CYCLES[m] then
      local t, len = os.time(), CYCLES[m]
      return ((t % len) / len) * 24
    end
    return nil
  end

  local origHour, origMinute, origWeekday = World.hour, World.minute, World.weekday
  World.hour = function(self, ...)
    if self.clockHour then return origHour(self, ...) end
    local h = hourNow()
    if h then return math.floor(h) % 24 end
    return origHour(self, ...)
  end
  World.minute = function(self, ...)
    local h = hourNow()
    if h then return math.floor((h % 1) * 60) % 60 end
    return origMinute(self, ...)
  end
  if type(origWeekday) == "function" then
    World.weekday = function(self, ...)
      if self.clockDay then return origWeekday(self, ...) end
      local m = mode()
      if m == "sync" then return tonumber(os.date("%w")) or origWeekday(self, ...) end
      if CYCLES[m] then return math.floor(os.time() / CYCLES[m]) % 7 end
      return origWeekday(self, ...)
    end
  end

  -- re-evaluate the palettes promptly when the setting changes
  if mod.events and mod.events.on then
    pcall(mod.events.on, mod.events, "mod.options_changed", function(ev)
      if type(ev) == "table" and ev.key == "timeOfDay" then
        local G = rawget(mod, "_kantoInMotionActiveGame")
        local w = type(G) == "table" and G.world
        if w and w.applyPalettes then
          pcall(function()
            if w:applyPalettes() then
              w.mapImages = {}
              if w.map then w.mapImage = w:imageFor(w.map.id) end
              if w.rebuildNeighbors then w:rebuildNeighbors() end
            end
          end)
        end
      end
    end)
  end

  -- The palettes ask through world.tod / map.palette too: answer those from
  -- the same clock, outermost, so nothing between can keep the old period.
  local function period(h)
    h = math.floor(h) % 24
    if h < 4 then return "NITE" end
    if h < 10 then return "MORN" end
    if h < 18 then return "DAY" end
    return "NITE"
  end
  if mod.hooks and mod.hooks.wrap then
    mod.hooks:wrap("world.tod", function(nextFn, tod, ctx)
      local out = nextFn(tod, ctx)
      local h = hourNow()
      if not h then return out end
      return period(h)
    end, 1e9)
    mod.hooks:wrap("map.palette", function(nextFn, daytime, map, ctx)
      local out = nextFn(daytime, map, ctx)
      local h = hourNow()
      -- a map whose header pins its colours (Ilex, caves, PALETTE_DARK) keeps them
      if not h or (type(ctx) == "table" and ctx.pinned) then return out end
      return period(h)
    end, 1e9)
  end

  -- 0.9.37: SOFT TWILIGHT. Crystal has three palette sets (MORN, DAY, NITE)
  -- and switches between them in one frame at 18:00 and 04:00 -- on CYCLE
  -- that lands every few minutes and reads as a jump. Around each switch a
  -- screen wash ramps up for RAMP seconds, the palette flips under its peak,
  -- and it ramps away again, so the step is masked and the light seems to
  -- fall (or rise) instead of snapping. Drawn under the HUD; skipped on maps
  -- whose colours are pinned (caves, Ilex, PALETTE_DARK), indoors included,
  -- and on fixed MORNING / DAY / NIGHT. TIME FADE turns it off.
  local RAMP, PEAK = 10, 0.42
  local FLIPS = {
    { hour = 18, color = { 0.05, 0.07, 0.20 } },   -- day -> night: deep blue
    { hour = 4,  color = { 0.16, 0.08, 0.18 } },   -- night -> morning: dusk violet
  }
  local pinnedNow = false
  local shown, shownColor = 0, nil   -- eased per frame: the clock ticks in whole seconds
  local function washAt()
    local m = mode()
    if not CYCLES[m] and m ~= "sync" then return nil end
    local h = hourNow()
    if not h then return nil end
    local secPerHour = CYCLES[m] and (CYCLES[m] / 24) or 3600
    for _, f in ipairs(FLIPS) do
      local d = ((h - f.hour + 12) % 24) - 12          -- signed hours from the flip
      local sec = math.abs(d * secPerHour)
      if sec < RAMP then return f.color, PEAK * (1 - sec / RAMP) end
    end
    return nil
  end
  if mod.hooks and mod.hooks.wrap then
    mod.hooks:wrap("map.palette", function(nextFn, daytime, map, ctx)
      local out = nextFn(daytime, map, ctx)
      local G = rawget(mod, "_kantoInMotionActiveGame")
      local cur = type(G) == "table" and G.world and G.world.map
      if map ~= nil and map == cur then pinnedNow = type(ctx) == "table" and ctx.pinned == true end
      return out
    end, 1e9 + 1)
    mod.hooks:wrap("render.hud", function(nextFn, ...)
      local okO, on = pcall(mod.options.get, mod.options, "timeFade")
      if not (okO and on == false) and not pinnedNow then
        local color, alpha = washAt()
        local dt = (love and love.timer and love.timer.getDelta and love.timer.getDelta()) or 0.016
        shown = shown + ((alpha or 0) - shown) * math.min(1, dt * 4)
        if color then shownColor = color end
        if shownColor and shown > 0.005 and love and love.graphics then
          local G = love.graphics
          local c = shownColor
          pcall(function()
            G.push("all"); G.origin()
            G.setColor(c[1], c[2], c[3], shown)
            local w, h = G.getDimensions()
            G.rectangle("fill", 0, 0, w, h)
            G.pop()
          end)
        end
      end
      return nextFn(...)
    end, 1e9)   -- outermost: drawn before every HUD layer, so all of them sit on top
  end

  local api = { mode = mode, hour = hourNow, washAt = washAt }
  World._kimArenaTime = api
  return api
end
