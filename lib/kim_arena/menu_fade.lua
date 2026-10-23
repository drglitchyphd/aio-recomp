-- KIM_ARENA: MENU TRANSITIONS.
--
-- The engine recreates Crystal's FadeToMenu / ExitMenu (src/ui/gen2/
-- MenuFade.lua): opening or leaving the party, pack, Pokedex, trainer card,
-- Pokegear or options fades the screen to WHITE and holds it for the frames
-- the Game Boy spent reloading VRAM. Over KIM's Modern menus and a 3D world
-- that reads as a white flash. DARK (the default) drops the hold and fades
-- through the KIM theme's dark surface instead; the menu change still
-- happens when the (shorter) fade completes, exactly as before. WHITE keeps
-- the original.
return function(host)
  local mod = host.mod
  local ok, MenuFade = pcall(require, "src.ui.gen2.MenuFade")
  if not ok or type(MenuFade) ~= "table" or type(MenuFade.new) ~= "function" then
    return nil
  end
  if MenuFade._kimArenaPatched then return MenuFade end
  MenuFade._kimArenaPatched = true
  local okChrome, Chrome = pcall(require, "src.ui.gen2.Chrome")

  local function dark()
    local ok2, value = pcall(mod.options.get, mod.options, "menuTransitions")
    return not (ok2 and value == "white")
  end

  local function sheetColor()
    local S = rawget(mod, "_kantoInMotionGen2Ui")
    local theme = S and S.theme and S.theme() or nil
    local c = theme and theme.surface or { 0.075, 0.105, 0.17, 1 }
    return c[1], c[2], c[3]
  end

  local origNew = MenuFade.new
  MenuFade.new = function(game, opts)
    if dark() then
      local copy = {}
      for k, v in pairs(opts or {}) do copy[k] = v end
      copy.white = 0
      local fade = origNew(game, copy)
      fade._kimDark = true
      return fade
    end
    return origNew(game, opts)
  end

  local function sheet(fade, w, h)
    local G = love.graphics
    local a = fade:level()
    if fade._kimDark then
      local r, g, b = sheetColor()
      G.setColor(r, g, b, a)
    else
      G.setColor(1, 1, 1, a)
    end
    G.rectangle("fill", 0, 0, w, h)
    G.setColor(1, 1, 1, 1)
  end

  local origWide = MenuFade.drawWidescreen
  MenuFade.drawWidescreen = function(self, w, h)
    if not self._kimDark then return origWide(self, w, h) end
    local G = love.graphics
    local stack = self.game and self.game.stack
    if stack and stack.states and okChrome then
      local world = self.game.world
      local scale = (world and world.fitScale) and world:fitScale() or Chrome.fitScale(w, h)
      local ox, oy = Chrome.fitOrigin(w, h, scale)
      G.push()
      G.translate(ox, oy)
      G.scale(scale, scale)
      for i = stack:visibleBase(), #stack.states do
        local state = stack.states[i]
        if state ~= self and state.draw and stack:renderVisible(state) then
          state:draw()
        end
      end
      G.pop()
    end
    sheet(self, w, h)
  end

  local origDraw = MenuFade.draw
  MenuFade.draw = function(self)
    if not self._kimDark then return origDraw(self) end
    local W = okChrome and Chrome.SCREEN_W and Chrome.SCREEN_W * 8 or 160
    local H = okChrome and Chrome.SCREEN_H and Chrome.SCREEN_H * 8 or 144
    sheet(self, W, H)
  end

  return MenuFade
end
