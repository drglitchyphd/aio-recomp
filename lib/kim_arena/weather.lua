-- KIM_ARENA: lore-friendly weather.
--
-- Three sources, strongest first:
--   1. BATTLE MOVES  -- Crystal's own battle weather (Rain Dance / Sunny Day /
--      Sandstorm, battle.weather = "rain" / "sun" / "sandstorm"), only while
--      it is active.
--   2. PLACES        -- what Crystal / HGSS establish about a location: snow
--      outside Mt. Silver, frost in the Ice Path, mist on Lake of Rage, the
--      Whirl Islands, Dragon's Den and the sea routes, embers in the Burned
--      Tower, damp in Slowpoke Well and Union Cave, dust in Mt. Mortar and
--      Rock Tunnel. Never in houses, gates or Pokemon Centers.
--   3. RANDOM RAIN   -- outdoor routes and towns only. Decided by Crystal's own
--      clock (weekday and 3-hour block), so it is the same all over Johto and
--      Kanto at a given time and changes as the day goes on.
-- Battles at a place carry its weather (setting).
--
-- Everything is screen space, drawn at the very start of render.hud (under
-- KIM's HUD, menus and the menu dim), with one SpriteBatch of a 1x1 texel:
-- one or two draw calls per frame, no shaders, no canvases. Works with the
-- 2D overworld, gmarc and every battle background alike.
return function(host)
  local mod = host.mod
  local G = love and love.graphics
  if not (G and G.newImage and G.newSpriteBatch and love.image) then return nil end

  local function opt(key, default)
    local ok, v = pcall(mod.options.get, mod.options, key)
    if not ok or v == nil then return default end
    return v
  end

  -- ------------------------------------------------------------- places
  local PLACES = {
    { "^SILVER_CAVE_OUTSIDE", "snow" },
    { "^ICE_PATH", "frost" },
    { "^LAKE_OF_RAGE", "mist" },
    { "^WHIRL_ISLAND", "mist" },
    { "^DRAGONS_DEN", "mist" },
    { "^ROUTE_40$", "mist" }, { "^ROUTE_41$", "mist" },
    { "^ROUTE_19$", "mist" }, { "^ROUTE_20$", "mist" }, { "^ROUTE_21$", "mist" },
    { "^BURNED_TOWER", "embers" },
    { "^SLOWPOKE_WELL", "damp" },
    { "^UNION_CAVE", "damp" },
    { "^MOUNT_MORTAR", "dust" },
    { "^ROCK_TUNNEL", "dust" },
  }
  local RAIN_CHANCE = { LAKE_OF_RAGE = 40 }   -- per cent per 3-hour block
  local DEFAULT_RAIN_CHANCE = 18

  local function mapInfo(game)
    local world = type(game) == "table" and game.world
    local map = world and world.map
    if not map then return nil end
    local def = map.def or {}
    return world, tostring(map.id or def.id or ""), tostring(def.environment or "")
  end

  local function placeFx(id, env)
    if env == "INDOOR" or env == "GATE" then return nil end
    if id:find("POKECENTER") or id:find("HOUSE") or id:find("_MART") then return nil end
    for _, p in ipairs(PLACES) do
      if id:match(p[1]) then return p[2] end
    end
    return nil
  end

  local function hash(n)
    n = (n * 1103515245 + 12345) % 2147483648
    n = (n * 1103515245 + 12345) % 2147483648
    return n
  end

  local function randomRain(world, id, env)
    if opt("weatherRain", true) == false then return false end
    if env ~= "ROUTE" and env ~= "TOWN" then return false end
    local okH, hour = pcall(world.hour, world)
    local okW, wd = pcall(world.weekday, world)
    hour = okH and tonumber(hour) or 12
    wd = okW and tonumber(wd) or 0
    local slot = wd * 8 + math.floor(hour / 3)
    local chance = RAIN_CHANCE[id] or DEFAULT_RAIN_CHANCE
    return hash(slot + 7919) % 100 < chance
  end

  local function battleState(game)
    local states = game and game.stack and game.stack.states or {}
    for i = #states, 1, -1 do
      local st = states[i]
      if type(st) == "table" and type(rawget(st, "battle")) == "table"
          and type(st.bgMode) == "function" then return st end
    end
    return nil
  end

  local MOVE_FX = { rain = "rain", sun = "sun", sandstorm = "sand" }

  -- which effect, given everything above
  local function pick(game)
    local mode = opt("weatherFx", "on")
    if mode == "off" then return nil end
    local world, id, env = mapInfo(game)
    local bs = battleState(game)
    if bs then
      local bw = bs.battle and bs.battle.weather
      if bw and MOVE_FX[bw] and opt("weatherMoves", true) ~= false then return MOVE_FX[bw] end
      if opt("weatherBattle", true) == false then return nil end
    end
    if not world then return nil end
    local fx = placeFx(id, env)
    if fx and opt("weatherPlaces", true) ~= false then
      if fx == "mist" and randomRain(world, id, env) then return "rain" end
      return fx
    end
    if randomRain(world, id, env) then return "rain" end
    return nil
  end

  -- ---------------------------------------------------------- particles
  local texel
  do
    local data = love.image.newImageData(1, 1)
    data:setPixel(0, 0, 1, 1, 1, 1)
    texel = G.newImage(data)
    texel:setFilter("nearest", "nearest")
  end
  local blob   -- soft round blob for mist / glare
  do
    local N = 64
    local data = love.image.newImageData(N, N)
    for y = 0, N - 1 do
      for x = 0, N - 1 do
        local dx, dy = (x + 0.5) / N * 2 - 1, (y + 0.5) / N * 2 - 1
        local d = math.sqrt(dx * dx + dy * dy)
        local a = math.max(0, 1 - d)
        data:setPixel(x, y, 1, 1, 1, a * a * (3 - 2 * a))
      end
    end
    blob = G.newImage(data)
    blob:setFilter("linear", "linear")
  end
  local batch = G.newSpriteBatch(texel, 512, "stream")
  local blobBatch = G.newSpriteBatch(blob, 32, "stream")

  local current, level, parts, lastW, lastH, lastT = nil, 0, {}, 0, 0, nil
  local wanted = nil

  local SPEC = {
    rain   = { n = 220, tint = { 0.10, 0.12, 0.20, 0.16 } },
    snow   = { n = 150, tint = { 0.80, 0.86, 1.00, 0.06 } },
    frost  = { n = 80,  tint = { 0.55, 0.75, 1.00, 0.09 } },
    mist   = { n = 0,   tint = { 0.85, 0.90, 0.95, 0.05 }, blobs = 10, blobColor = { 0.92, 0.95, 1.00 } },
    damp   = { n = 40,  tint = { 0.30, 0.40, 0.32, 0.10 }, blobs = 9, blobColor = { 0.70, 0.80, 0.72 } },
    embers = { n = 80,  tint = { 0.45, 0.18, 0.05, 0.12 } },
    dust   = { n = 90,  tint = { 0.50, 0.38, 0.22, 0.07 } },
    sun    = { n = 0,   tint = { 1.00, 0.80, 0.40, 0.10 }, glare = true },
    sand   = { n = 200, tint = { 0.70, 0.55, 0.30, 0.16 } },
  }

  local function rnd(a, b) return a + math.random() * (b - a) end

  local function spawn(kind, W, H, p, initial)
    p = p or {}
    if kind == "rain" then
      p.x, p.y = rnd(-W * 0.2, W), initial and rnd(-H, H) or rnd(-H * 0.3, -10)
      p.v = rnd(1.2, 1.7) * H; p.len = rnd(0.018, 0.032) * H; p.a = rnd(0.25, 0.5)
    elseif kind == "snow" then
      p.x, p.y = rnd(0, W), initial and rnd(0, H) or rnd(-H * 0.1, -5)
      p.v = rnd(0.05, 0.12) * H; p.s = rnd(2, 5) * H / 1000; p.ph = rnd(0, 6.28); p.a = rnd(0.6, 0.95)
    elseif kind == "frost" then
      p.x, p.y = rnd(0, W), rnd(0, H)
      p.v = rnd(0.01, 0.03) * H; p.s = rnd(3, 5.5) * H / 1000; p.ph = rnd(0, 6.28); p.a = rnd(0.6, 1)
    elseif kind == "embers" then
      p.x, p.y = rnd(0, W), initial and rnd(0, H) or H + rnd(5, H * 0.1)
      p.v = -rnd(0.05, 0.13) * H; p.s = rnd(3.5, 7) * H / 1000; p.ph = rnd(0, 6.28); p.a = rnd(0.7, 1)
    elseif kind == "dust" or kind == "damp" then
      p.x, p.y = initial and rnd(0, W) or rnd(-W * 0.1, -5), rnd(0, H)
      p.v = rnd(0.02, 0.06) * W; p.s = rnd(2.5, 5) * H / 1000; p.ph = rnd(0, 6.28); p.a = rnd(0.4, 0.8)
    elseif kind == "sand" then
      p.x, p.y = initial and rnd(0, W) or rnd(-W * 0.3, -10), rnd(0, H)
      p.v = rnd(0.9, 1.5) * W; p.len = rnd(0.02, 0.05) * W; p.a = rnd(0.25, 0.55)
    end
    return p
  end

  local function reset(kind, W, H)
    parts = {}
    local spec = SPEC[kind]
    if not spec then return end
    local n = spec.n
    if opt("weatherFx", "on") == "lite" then n = math.floor(n / 2) end
    for i = 1, n do parts[i] = spawn(kind, W, H, nil, true) end
    parts.blobs = {}
    for i = 1, (spec.blobs or 0) do
      parts.blobs[i] = { x = rnd(-0.2, 1.1) * W, y = rnd(0.1, 0.95) * H,
        s = rnd(0.35, 0.7) * math.max(W, H), v = rnd(0.008, 0.02) * W, a = rnd(0.10, 0.20) }
    end
  end

  local function step(dt, W, H, t)
    local kind = current
    for _, p in ipairs(parts) do
      if kind == "rain" then
        p.y = p.y + p.v * dt; p.x = p.x + p.v * 0.18 * dt
        if p.y > H + p.len then spawn(kind, W, H, p) end
      elseif kind == "snow" then
        p.y = p.y + p.v * dt; p.x = p.x + math.sin(t * 0.9 + p.ph) * H * 0.02 * dt
        if p.y > H + 5 then spawn(kind, W, H, p) end
      elseif kind == "frost" then
        p.y = p.y + p.v * dt
        if p.y > H + 5 then p.y = -5; p.x = rnd(0, W) end
      elseif kind == "embers" then
        p.y = p.y + p.v * dt; p.x = p.x + math.sin(t * 1.7 + p.ph) * H * 0.03 * dt
        if p.y < -10 then spawn(kind, W, H, p) end
      elseif kind == "dust" or kind == "damp" then
        p.x = p.x + p.v * dt; p.y = p.y + math.sin(t * 0.6 + p.ph) * H * 0.006 * dt
        if p.x > W + 10 then spawn(kind, W, H, p) end
      elseif kind == "sand" then
        p.x = p.x + p.v * dt; p.y = p.y + p.v * 0.05 * dt
        if p.x > W + p.len then spawn(kind, W, H, p) end
      end
    end
    for _, b in ipairs(parts.blobs or {}) do
      b.x = b.x + b.v * dt
      if b.x - b.s > W then b.x = -b.s * 0.9; b.y = rnd(0.1, 0.95) * H end
    end
  end

  local function draw(W, H, t, k)
    local spec = SPEC[current]
    if not spec then return end
    local night = false
    G.push("all")
    G.origin(); G.setShader(); G.setScissor()
    G.setBlendMode("alpha")
    local tint = spec.tint
    G.setColor(tint[1], tint[2], tint[3], tint[4] * k)
    G.rectangle("fill", 0, 0, W, H)
    if spec.glare then
      blobBatch:clear()
      local s = math.max(W, H) * 1.1
      blobBatch:setColor(1, 0.92, 0.70, 0.30 * k)
      blobBatch:add(W * 0.85 - s / 2, -s * 0.45, 0, s / 64, s / 64)
      G.setColor(1, 1, 1, 1); G.setBlendMode("add"); G.draw(blobBatch); G.setBlendMode("alpha")
    end
    if parts.blobs and #parts.blobs > 0 then
      blobBatch:clear()
      local c = spec.blobColor
      for _, b in ipairs(parts.blobs) do
        blobBatch:setColor(c[1], c[2], c[3], b.a * k)
        blobBatch:add(b.x - b.s / 2, b.y - b.s * 0.25, 0, b.s / 64, b.s * 0.5 / 64)
      end
      G.setColor(1, 1, 1, 1); G.draw(blobBatch)
    end
    batch:clear()
    local kind = current
    for _, p in ipairs(parts) do
      if kind == "rain" then
        batch:setColor(0.78, 0.84, 0.96, p.a * k)
        batch:add(p.x, p.y, -0.18, math.max(1, H / 900), p.len)
      elseif kind == "sand" then
        batch:setColor(0.90, 0.76, 0.50, p.a * k)
        batch:add(p.x, p.y, 0, p.len, math.max(1, H / 1000))
      elseif kind == "snow" then
        batch:setColor(1, 1, 1, p.a * k)
        batch:add(p.x, p.y, 0, p.s, p.s)
      elseif kind == "frost" then
        local tw = 0.5 + 0.5 * math.sin(t * 3 + p.ph)
        batch:setColor(0.85, 0.95, 1, p.a * tw * k)
        batch:add(p.x, p.y, 0, p.s, p.s)
      elseif kind == "embers" then
        local fl = 0.6 + 0.4 * math.sin(t * 9 + p.ph)
        batch:setColor(1, 0.55 + 0.25 * fl, 0.15, p.a * fl * k)
        batch:add(p.x, p.y, 0, p.s, p.s)
      elseif kind == "dust" then
        batch:setColor(0.82, 0.70, 0.52, p.a * k)
        batch:add(p.x, p.y, 0, p.s, p.s)
      elseif kind == "damp" then
        batch:setColor(0.80, 0.90, 0.82, p.a * 0.7 * k)
        batch:add(p.x, p.y, 0, p.s, p.s)
      end
    end
    if #parts > 0 then G.setColor(1, 1, 1, 1); G.draw(batch) end
    G.pop()
  end

  local function now() return love.timer and love.timer.getTime and love.timer.getTime() or 0 end

  local function frame(game)
    local W, H = G.getDimensions()
    local t = now()
    local dt = lastT and math.min(0.1, t - lastT) or 0
    lastT = t
    local okP, want = pcall(pick, game)
    want = okP and want or nil
    -- cross-fade: fade the old effect out, then the new one in
    if want ~= current then
      level = level - dt / 0.8
      if level <= 0 or current == nil then
        current, level = want, 0
        if current then reset(current, W, H); lastW, lastH = W, H end
      end
    elseif current then
      level = math.min(1, level + dt / 1.2)
    end
    if current and (W ~= lastW or H ~= lastH) then reset(current, W, H); lastW, lastH = W, H end
    if not current or level <= 0 then return end
    step(dt, W, H, t)
    draw(W, H, t, level)
  end

  mod.hooks:wrap("render.hud", function(nextFn, game, viewport)
    if type(game) == "table" and game.world then pcall(frame, game) end
    return nextFn(game, viewport)
  end, -90000)

  local api = { pick = pick, placeFx = placeFx, current = function() return current end }
  mod._kimArenaWeather = api
  return api
end
