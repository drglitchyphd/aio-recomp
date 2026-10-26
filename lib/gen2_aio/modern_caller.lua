-- Caller ID rides underneath phone dialogue and follows its stack lifetime.
return function(host)
  local mod,G=host.mod,love.graphics
  local ok,Caller=pcall(require,"src.ui.gen2.CallerBox")
  if not ok then return end
  local function enabled()
    local S=mod._kantoInMotionGen2Ui
    return S and S.presenterEnabled("dialogue") and S.hideOriginal()
  end
  mod.hooks:wrap("screen.render_visible",function(nextFn,state)
    if enabled() and type(state)=="table" and getmetatable(state)==Caller then return false end
    return nextFn(state)
  end,48000)
  mod.hooks:wrap("render.hud",function(nextFn,game,viewport)
    local r=nextFn(game,viewport)
    if enabled() then
      for _,state in ipairs(game and game.stack and game.stack.states or {}) do
        if getmetatable(state)==Caller then
          local S=mod._kantoInMotionGen2Ui;local c=S.theme()
          local W,H=G.getDimensions();local pad=math.max(12,math.min(W,H)*.02)
          local f=S.font(math.max(16,math.min(W,H)*.025))
          local w=math.min(W-pad*2,700);local x=(W-w)/2
          local label=tostring(state.name or "")
          if state.className and state.className~="" then label=label.."\n"..state.className end
          local _,lines=f:getWrap(label,w-pad*2)
          G.push("all");G.origin()
          S.panel(x,pad,w,#lines*f:getHeight()+pad*2,c,.99)
          S.text(label,f,x+pad,pad*2,w-pad*2,"left",c.text)
          G.pop()
          break
        end
      end
    end
    return r
  end,48000)
end
