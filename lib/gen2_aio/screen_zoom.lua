-- gen2-aio: per-screen overworld ZOOM.
--
-- The engine keeps ONE survey-zoom offset (src/render/Zoom.lua, stored as
-- options.zoom) on top of an integer fit scale floor(min(w/160, h/144)). On a
-- Galaxy Z Fold the outer screen is tall and narrow, so its fit is ~6x against
-- the inner screen's ~13x, and at the same offset the outer view comes out far
-- too wide. This keeps one offset per screen SHAPE: "tall" (height > 1.9 x
-- width) and "regular". Folding or unfolding swaps them, the native ZOOM row,
-- hotkey and wheel change only the screen they are used on, and both are kept
-- in mod.cache (install-scoped, so per device and outside any save slot).
return function(host)
  local mod = host.mod
  local ok, Zoom = pcall(require, "src.render.Zoom")
  if not ok or type(Zoom) ~= "table" or type(Zoom.scale) ~= "function" then return nil end
  if Zoom._kimArenaScreenZoom then return Zoom._kimArenaScreenZoom end

  -- v2 (0.9.1): the tall default is computed, not a fixed +2; a new file so
  -- the old fixed default is not carried over.
  local FILE = "screen_zoom_v2.lua"
  -- World area the inner view shows at offset 0 (GB 160x144 plus the margin
  -- a near-square screen's whole-number fit leaves), in world px^2.
  local REFERENCE_AREA = 160 * 144 * 1.18
  local cache = mod.cache
  local slots, profile, opts, dirty = nil, nil, nil, false

  local function load()
    if not (cache and cache.read) then return nil end
    local okR, body = pcall(cache.read, cache, FILE)
    if not okR or type(body) ~= "string" then return nil end
    local fn = (loadstring or load)("return " .. body)
    if not fn then return nil end
    pcall(setfenv or function() end, fn, {})
    local okF, t = pcall(fn)
    if okF and type(t) == "table" then return t end
    return nil
  end
  local function save()
    dirty = false
    if not (cache and cache.write and slots) then return end
    local body = ("{ regular = %d%s }"):format(math.floor(tonumber(slots.regular) or 0),
      slots.tall ~= nil and (", tall = %d"):format(math.floor(tonumber(slots.tall) or 0)) or "")
    pcall(cache.write, cache, FILE, body)
  end

  local function shape()
    local w, h = 0, 0
    if love and love.graphics and love.graphics.getDimensions then
      w, h = love.graphics.getDimensions()
    end
    w, h = tonumber(w) or 0, tonumber(h) or 0
    if w <= 0 or h <= 0 then return profile or "regular" end
    return (h > 1.9 * w) and "tall" or "regular"
  end

  local function ensure()
    if slots then return end
    slots = load()
    if not slots then
      -- the tall slot is computed the first time a tall screen is seen
      slots = { regular = math.floor(tonumber(Zoom.offset) or 0) }
      dirty = true
    end
  end
  -- Automatic tall-screen zoom: the offset at which this tall screen shows
  -- about the same AREA of world as the inner screen does, plus whatever
  -- zoom the player uses there. Its whole-number fit is limited by the
  -- narrow width (about 6x on a Fold cover screen against about 12x inside),
  -- so at the same offset it showed nearly three times the world height.
  local function autoTall()
    local w, h = love.graphics.getDimensions()
    w, h = tonumber(w) or 0, tonumber(h) or 0
    if w <= 0 or h <= 0 then return math.floor(tonumber(slots.regular) or 0) end
    local fit = math.max(1, math.floor(math.min(w / 160, h / 144)))
    local want = math.sqrt(w * h / REFERENCE_AREA)
    return math.floor(want + 0.5) - fit + math.floor(tonumber(slots.regular) or 0)
  end

  -- Called every frame through Zoom.scale (the renderer and gmarc's
  -- world:zoomScale both go through it), so a fold is seen on the next frame.
  local function sync()
    ensure()
    local now = shape()
    if now == "tall" and slots.tall == nil then slots.tall = autoTall(); dirty = true end
    if now == profile then
      local cur = math.floor(tonumber(Zoom.offset) or 0)
      if slots[now] ~= cur then slots[now] = cur; dirty = true end
    else
      profile = now
      Zoom.offset = math.floor(tonumber(slots[now]) or 0)
      -- the native ZOOM row shows options.zoom; keep it on this screen's value
      if type(opts) == "table" then opts.zoom = Zoom.offset end
    end
    if dirty then save() end
  end

  local origScale = Zoom.scale
  Zoom.scale = function(S, ...)
    pcall(sync)
    return origScale(S, ...)
  end

  -- options.zoom is ONE value; on boot / OPTIONS apply, take this screen's own.
  local origApply = Zoom.applyOptions
  Zoom.applyOptions = function(o, ...)
    opts = o
    local r = origApply(o, ...)
    ensure()
    local now = shape()
    if now == "tall" and slots.tall == nil then slots.tall = autoTall(); dirty = true end
    profile = now
    Zoom.offset = math.floor(tonumber(slots[now]) or Zoom.offset or 0)
    if type(o) == "table" then o.zoom = Zoom.offset end
    return r
  end

  local origNudge = Zoom.nudgeOptions
  Zoom.nudgeOptions = function(o, ...)
    if type(o) == "table" then opts = o end
    local r = origNudge(o, ...)
    pcall(sync)
    return r
  end

  local api = { shape = shape, slots = function() ensure(); return slots end }
  Zoom._kimArenaScreenZoom = api
  return api
end
