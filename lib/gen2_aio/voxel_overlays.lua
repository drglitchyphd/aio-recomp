-- gen2-aio 0.9.41: the overlays World:draw paints AFTER the map, in 3D too.
--
-- gmarc replaces Crystal's World:draw with its voxel frame and returns early,
-- so everything the engine draws after the world body never appeared in 3D:
-- the town / route NAME SIGN on entering an area (engine/events/
-- map_name_sign.asm) and the POKEPIC window scripts open (a Pokemon's picture
-- in a box: Bill's grandpa, Elm's starters, ...). This wraps World:draw
-- outside gmarc and, on any frame where the engine's own path did not run
-- (MapNameSign.draw was not reached), draws both exactly as World:draw does.
return function(host)
  local okW, World = pcall(require, "src.world.gen2.World")
  local okS, MapNameSign = pcall(require, "src.world.gen2.MapNameSign")
  local okP, Playfield = pcall(require, "src.render.Playfield")
  local okSP, ScreenPosition = pcall(require, "src.core.ScreenPosition")
  if not (okW and okS and okP and type(World) == "table" and type(World.draw) == "function"
      and type(MapNameSign) == "table" and type(MapNameSign.draw) == "function") then
    return nil
  end
  if World._kimArenaOverlays then return World._kimArenaOverlays end
  local okF, Font = pcall(require, "src.render.Font")
  local okG, GbcPalette = pcall(require, "src.render.GbcPalette")

  local POKEPIC = { left = 6, top = 4, w = 9, h = 10,
    pad = { [7] = { 0, 0 }, [6] = { 1, 1 }, [5] = { 1, 2 } } }

  local signDrawn = false
  local origSign = MapNameSign.draw

  -- 0.9.42 MODERN NAME SIGN: with KIM's Modern UI on, the area name is a
  -- themed plaque in the top-left corner (current UI THEME and frame) that
  -- slides in and fades out over Crystal's own sign timing, instead of the
  -- Game Boy tile sign. AREA SIGN = NATIVE keeps the original.
  local mod = host.mod
  local DUR = tonumber(MapNameSign.DURATION) or 60
  local function modernWanted()
    if not mod then return false end
    local okO, v = pcall(mod.options.get, mod.options, "areaSignStyle")
    if okO and v == "native" then return false end
    local Style = rawget(mod, "_kantoInMotionGen2Ui")
    if not (Style and Style.panel and Style.font) then return false end
    local okM, on = pcall(function() return Style.masterEnabled() and Style.presenterEnabled("dialogue") end)
    return okM and on, Style
  end
  local function drawModern(world, Style)
    local s = world.mapSign
    if not s or not s.shown or world.textbox then return end
    local G = love.graphics
    local timer = tonumber(s.timer) or 0
    local inA = math.min(1, (DUR - timer) / 8)
    local outA = math.min(1, timer / 12)
    local a = math.max(0, math.min(inA, outA))
    if a <= 0 then return end
    G.push("all"); G.origin()
    local W, H = G.getDimensions()
    local scale = (Style.uiScale and Style.uiScale(W, H)) or 1
    local f = Style.font(math.floor(26 * scale + 0.5))
    local name = tostring(s.name or "")
    local pad = 16 * scale
    local pw, ph = f:getWidth(name) + pad * 2.2, f:getHeight() + pad * 1.3
    local x = math.max(14 * scale, W * 0.03)
    local y = math.max(14 * scale, H * 0.03) - (1 - inA) * (ph + 20 * scale)
    local c = Style.theme()
    pcall(Style.panel, x, y, pw, ph, c, a)
    local tc = c.text or { 1, 1, 1, 1 }
    G.setFont(f)
    G.setColor(tc[1], tc[2], tc[3], (tc[4] or 1) * a)
    G.print(name, x + pad * 1.1, y + (ph - f:getHeight()) / 2)
    G.pop()
  end

  MapNameSign.draw = function(world, ...)
    signDrawn = true
    local want, Style = modernWanted()
    if want then pcall(drawModern, world, Style); return end
    return origSign(world, ...)
  end

  local function overlays(self)
    local G = love.graphics
    local w, h = Playfield.dimensions()
    local d = Playfield.ratio()
    local ph = math.floor(h * d + 0.5)
    local liftPx = 0
    if okSP and ScreenPosition and not ScreenPosition.skinActive(w, h) then
      liftPx = ScreenPosition.lift(ph, 144 * self:pixelFitScale(), ScreenPosition.safeTop() * d)
    end
    local posLift = liftPx / d
    G.push("all")
    G.origin()
    local uiLayer = self.game and self.game.fxUiDrawn and self.game.fxUiLayer
    if uiLayer then G.setCanvas(uiLayer) end
    MapNameSign.draw(self, w, h, posLift)
    if self.pokePic and okF then
      local sPic = self:fitScale()
      local picW = self.pokePic:getDimensions()
      local pad = POKEPIC.pad[math.floor(picW / 8)] or POKEPIC.pad[7]
      G.translate(Playfield.snap((w - 160 * sPic) / 2, d),
        Playfield.snap((h - 144 * sPic) / 2, d) - posLift)
      G.scale(sPic, sPic)
      G.setColor(1, 1, 1, 1)
      local raw = self.pokePicTrueColor and okG and GbcPalette.mode == "gbc"
      local function pic()
        G.draw(self.pokePic, (POKEPIC.left + 1 + pad[1]) * 8, (POKEPIC.top + 1 + pad[2]) * 8)
      end
      local function body()
        Font.drawBox(POKEPIC.left, POKEPIC.top, POKEPIC.w, POKEPIC.h)
        if not raw then pic() end
      end
      if self.pokePicColors and okG then GbcPalette.with(self.pokePicColors, body) else body() end
      if raw then pic() end
    end
    G.pop()
  end

  -- 0.9.41 STARTUP: with VOXEL on, the first frames after loading a save
  -- came out flat (the engine's 2D path) until gmarc had built the map, then
  -- popped to 3D. Until the first voxel frame lands -- for at most HOLD
  -- seconds, so a map gmarc never builds can't black the game out -- the 2D
  -- frame is covered with a plain loading card.
  local okPL, Pipelines = pcall(require, "src.render.Pipelines")
  local HOLD = 20
  local firstDraw, voxelSeen = nil, false
  local function loadingCard()
    local G = love.graphics
    G.push("all"); G.origin()
    local w, h = G.getDimensions()
    G.setColor(0.03, 0.03, 0.04, 1); G.rectangle("fill", 0, 0, w, h)
    local dots = ("."):rep(1 + math.floor((love.timer.getTime() * 2) % 3))
    G.setColor(0.85, 0.85, 0.88, 1)
    G.printf("LOADING" .. dots, 0, h * 0.48, w, "center")
    G.pop()
  end

  local inner = World.draw
  World.draw = function(self, ...)
    signDrawn = false
    local r = { inner(self, ...) }
    if okPL and Pipelines and self.mapImage and self.player and not voxelSeen then
      local now = love.timer and love.timer.getTime() or 0
      firstDraw = firstDraw or now
      local voxelOn = Pipelines.worldPipeline and Pipelines.worldPipeline() == "voxel"
      if voxelOn and not signDrawn then
        voxelSeen = true                       -- gmarc drew this frame
      elseif voxelOn and now - firstDraw < HOLD then
        pcall(loadingCard)                     -- still the flat fallback
        return unpack(r)
      elseif not voxelOn and now - firstDraw > 2 then
        voxelSeen = true                       -- 2D by choice: stop watching
      end
    end
    if not signDrawn and self.mapImage and self.player then
      local ok, err = pcall(overlays, self)
      if not ok and host.log then host.log("warn", "Gen2-AIO voxel overlays: %s", tostring(err)) end
    end
    return unpack(r)
  end
  World._kimArenaOverlays = { overlays = overlays }
  return World._kimArenaOverlays
end
