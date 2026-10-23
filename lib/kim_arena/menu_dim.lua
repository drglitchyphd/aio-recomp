-- KIM_ARENA: overworld menu dim.
--
-- With any menu open OUTSIDE battle, a dark translucent sheet goes over the
-- world behind KIM's UI. It is drawn at the very start of render.hud (the
-- innermost link, before the HUD layers paint), so KIM's menu cards, the
-- touch controls and the HUD all land on top of it. The battle's NATURE
-- background fill is a separate thing and is not touched.
return function(host)
  local mod = host.mod
  local NAMES = { "StartMenu", "PackMenu", "PartyMenu", "Pokegear", "PcMenu", "BoxMenu",
    "OptionsMenu", "SaveMenu", "TrainerCard", "CenterPcMenu", "PokedexMenu", "SummaryMenu",
    "ItemPcMenu", "MartMenu", "DayCareMenu", "MailMenu", "MailboxMenu", "DecorationMenu",
    "HeldItemMenu", "PrizeMenu", "ElevatorMenu", "TradeMenu" }
  local classes = {}
  for _, name in ipairs(NAMES) do
    local ok, M = pcall(require, "src.ui.gen2." .. name)
    if ok and type(M) == "table" then classes[M] = true end
  end

  local function isMenu(state)
    if type(state) ~= "table" then return false end
    local mt = getmetatable(state)
    for _ = 1, 4 do
      if not mt then return false end
      if classes[mt] then return true end
      local idx = rawget(mt, "__index")
      if type(idx) ~= "table" then return false end
      if classes[idx] then return true end
      mt = getmetatable(idx)
    end
    return false
  end

  local function inBattle(states)
    for i = 1, #states do
      local s = states[i]
      if type(s) == "table" and type(s.bgMode) == "function" then return true end
    end
    return false
  end

  local level, last = 0, nil
  local MAX = 0.45
  local function enabled()
    local ok, v = pcall(mod.options.get, mod.options, "menuDim")
    return not (ok and v == false)
  end

  mod.hooks:wrap("render.hud", function(nextFn, game, viewport)
    local states = type(game) == "table" and game.stack and game.stack.states or {}
    local top = states[#states]
    local want = enabled() and #states > 1 and game.world and game.world.map
      and not inBattle(states) and isMenu(top)
    local now = love.timer and love.timer.getTime and love.timer.getTime() or 0
    local dt = last and math.min(0.1, now - last) or 0
    last = now
    level = want and math.min(1, level + dt / 0.15) or math.max(0, level - dt / 0.12)
    if level > 0 then
      local G = love.graphics
      G.push("all")
      G.origin(); G.setShader(); G.setScissor()
      G.setColor(0, 0, 0, MAX * level)
      local w, h = G.getDimensions()
      G.rectangle("fill", 0, 0, w, h)
      G.pop()
    end
    return nextFn(game, viewport)
  end, -100000)
  return { isMenu = isMenu }
end
