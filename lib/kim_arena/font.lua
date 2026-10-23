-- KIM_ARENA: Pixel Operator for KIM's Modern UI (HUD cards, battle panel,
-- party / pack / summary / Pokedex screens, dialogue, touch labels).
--
-- Pixel Operator by Jayvee Enaguas (HarvettFox96), CC0 1.0
-- (assets/fonts/pixeloperator/LICENSE.txt).
--
-- Loaded from the mod's own files (mod:read -> FileData), so it works however
-- the mod folder is mounted. Pixel Operator runs a little shorter and much
-- narrower than LOVE's default face at the same size, so sizes are raised by
-- SIZE_K: same line height as before (nothing grows taller than the boxes
-- KIM laid out), clearly narrower lines (nothing overflows sideways).
return function(host)
  local mod = host.mod
  local G = love and love.graphics
  if not (G and G.newFont and love.filesystem and love.filesystem.newFileData) then return nil end
  local FILES = { regular = "assets/fonts/pixeloperator/PixelOperator.ttf",
    bold = "assets/fonts/pixeloperator/PixelOperator-Bold.ttf" }
  local SIZE_K = 1.125
  local data, cache, failed = {}, {}, {}

  local function fileData(kind)
    if data[kind] ~= nil then return data[kind] or nil end
    local okR, bytes = pcall(mod.read, mod, FILES[kind])
    if okR and type(bytes) == "string" and #bytes > 0 then
      local okD, fd = pcall(love.filesystem.newFileData, bytes, kind .. ".ttf")
      data[kind] = okD and fd or false
    else
      data[kind] = false
    end
    return data[kind] or nil
  end

  local function enabled()
    local ok, v = pcall(mod.options.get, mod.options, "arenaFont")
    return not (ok and v == "kim")
  end

  local function font(px, bold)
    if not enabled() then return nil end
    local kind = bold and "bold" or "regular"
    if failed[kind] then return nil end
    local size = math.max(9, math.floor((tonumber(px) or 12) * SIZE_K + 0.5))
    local key = kind .. ":" .. size
    local hit = cache[key]
    if hit then return hit end
    local fd = fileData(kind)
    if not fd then failed[kind] = true; return nil end
    local ok, f = pcall(G.newFont, fd, size, "normal")
    if not ok or not f then failed[kind] = true; return nil end
    pcall(f.setFilter, f, "linear", "linear")
    cache[key] = f
    return f
  end

  mod._kimArenaFont = font
  return { font = font }
end
