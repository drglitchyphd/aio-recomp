-- gen2-aio: HD Poke Balls in Crystal's own ball animations.
--
-- The throw (and any other animation drawing from the POKE_BALL sheet) keeps
-- running exactly as Crystal plays it -- path, bounces, wobbles, click or
-- break-out -- but the ball's 8x8 Game Boy tiles are not drawn; the ball
-- being thrown is drawn instead as its own item icon (all twelve Crystal
-- balls, PokeAPI item sprites), centred where those tiles were, at the same
-- 11px size (see below), nearest-filtered so it stays crisp when KIM / gmarc scale it.
return function(host)
  local mod, log = host.mod, host.log
  local okV, View = pcall(require, "src.ui.gen2.BattleAnimView")
  local okB, BS = pcall(require, "src.ui.gen2.BattleState")
  if not (okV and type(View) == "table" and type(View.drawObjects) == "function") then return nil end
  if View._kimArenaHdBall then
    View._kimArenaHdBall.live.mod = mod
    return View._kimArenaHdBall
  end
  local live = { mod = mod }

  local FILES = { POKE_BALL = "poke", GREAT_BALL = "great", ULTRA_BALL = "ultra",
    MASTER_BALL = "master", LEVEL_BALL = "level", LURE_BALL = "lure", MOON_BALL = "moon",
    FRIEND_BALL = "friend", LOVE_BALL = "love", HEAVY_BALL = "heavy", FAST_BALL = "fast",
    PARK_BALL = "park" }
  local images, quads = {}, {}
  local function icon(itemId)
    local name = FILES[itemId or "POKE_BALL"] or "poke"
    local hit = images[name]
    if hit ~= nil then return hit or nil, quads[name] end
    local ok, img = pcall(function()
      local bytes = live.mod:read("assets/gen2_aio/balls/" .. name .. ".png")
      local fd = love.filesystem.newFileData(bytes, name .. ".png")
      local i = love.graphics.newImage(love.image.newImageData(fd))
      i:setFilter("nearest", "nearest")
      return i
    end)
    images[name] = ok and img or false
    if ok and img then
      -- the ball itself fills the middle 18x18 of the 30x30 icon
      quads[name] = love.graphics.newQuad(6, 6, 18, 18, img:getDimensions())
    end
    return images[name] or nil, quads[name]
  end

  local enabled = function()
    local ok, v = pcall(live.mod.options.get, live.mod.options, "hdBall")
    return not (ok and v == false)
  end

  local currentBall = "POKE_BALL"
  if okB and type(BS) == "table" and type(BS.startBallAnim) == "function" then
    local origStart = BS.startBallAnim
    BS.startBallAnim = function(self, param, itemId, ...)
      currentBall = itemId or "POKE_BALL"
      return origStart(self, param, itemId, ...)
    end
  end

  local function isBallSheet(entry)
    local g = entry and entry.gfx
    return type(g) == "string" and g:upper():find("POKE_BALL", 1, true) ~= nil
  end
  local function sheetFor(runner, tile)
    local loaded = runner.loaded or {}
    for i = #loaded, 1, -1 do
      local e = loaded[i]
      if tile >= e.tile and tile < e.tile + math.max(e.tiles or 0, 1) then return e end
    end
    return nil
  end

  local origDraw = View.drawObjects
  View.drawObjects = function(self, runner, battle, ...)
    if runner then runner._aioHdBall = nil end
    if not (enabled() and runner and type(runner.oam) == "function") then
      return origDraw(self, runner, battle, ...)
    end
    local okO, list = pcall(runner.oam, runner)
    if not okO or type(list) ~= "table" then return origDraw(self, runner, battle, ...) end
    local keep, x0, y0, x1, y1 = {}, math.huge, math.huge, -math.huge, -math.huge
    for _, obj in ipairs(list) do
      if isBallSheet(sheetFor(runner, obj.tile)) then
        local x, y = obj.x - 8, obj.y - 16
        if x < x0 then x0 = x end; if y < y0 then y0 = y end
        if x + 8 > x1 then x1 = x + 8 end; if y + 8 > y1 then y1 = y + 8 end
      else
        keep[#keep + 1] = obj
      end
    end
    if x0 == math.huge then return origDraw(self, runner, battle, ...) end
    local img, quad = icon(currentBall)
    -- An unavailable asset keeps the native ball visible.
    if not img then return origDraw(self, runner, battle, ...) end
    local own = rawget(runner, "oam")
    runner.oam = function() return keep end
    local r = { pcall(origDraw, self, runner, battle, ...) }
    runner.oam = own
    if img then
      local G = love.graphics
      local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
      -- 0.9.24: 11px, not the GB tiles' 16: next to KIM's HD Pokemon (drawn
      -- well inside Crystal's 56px pic frame) a 16px ball read as huge
      local size = 8
      if runner._aioCaptureBall then
        -- The 3D effect card can shear and stretch. Its ball is composited
        -- separately at the projected center with one uniform screen size.
        runner._aioHdBall = { image=img, quad=quad, x=cx, y=cy, size=size }
        if not r[1] then error(r[2],0) end
        return unpack(r,2)
      end
      local prevShader = G.getShader and G.getShader()
      if G.setShader then G.setShader() end
      G.setColor(1, 1, 1, 1)
      -- 0.9.26: square, whole screen pixels. The battle view can be scaled
      -- unevenly (tall screens stretch it), which flattened the ball, and a
      -- fractional pixel step made its outline lumpy. Measure the current
      -- transform, keep the size, and snap each source pixel to k x k.
      local sx, sy = size / 18, size / 18
      pcall(function()
        local ax, ay = G.transformPoint(0, 0)
        local bx, by = G.transformPoint(1, 0)
        local qx, qy = G.transformPoint(0, 1)
        local tsx = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
        local tsy = math.sqrt((qx - ax) ^ 2 + (qy - ay) ^ 2)
        if tsx > 0 and tsy > 0 then
          local pixels = size * math.min(tsx,tsy)
          sx, sy = pixels / (18*tsx), pixels / (18*tsy)
        end
      end)
      G.draw(img, quad, cx, cy, 0, sx, sy, 9, 9)
      if G.setShader then G.setShader(prevShader) end
    end
    if not r[1] then error(r[2], 0) end
    return unpack(r, 2)
  end

  local api = { icon = icon, live = live }
  View._kimArenaHdBall = api
  if log then log("info", "Gen2-AIO: HD Poke Balls installed") end
  return api
end
