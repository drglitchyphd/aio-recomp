-- Final-window presenter for component-owned list screens. Providers only
-- describe their live state; their original update methods own all changes.
return function(host)
  local mod, G = host.mod, love.graphics
  local function enabled()
    local s=mod._kantoInMotionGen2Ui
    return s and s.presenterEnabled("menu") and s.hideOriginal()
  end
  local function data(state)
    if type(state)=="table" and type(state._aioModernData)=="function" then
      return state:_aioModernData()
    end
  end
  local function draw(state,d)
    local S=mod._kantoInMotionGen2Ui
    local c=S.theme()
    local W,H=G.getDimensions()
    local scale=math.min(W/800,H/650,1.35)
    local body=S.font(math.max(14,24*scale))
    local small=S.font(math.max(12,19*scale))
    local title=S.font(math.max(18,31*scale))
    local pad=math.max(12,22*scale)
    local w=math.min(W-pad*2,1100*scale)
    local h=math.min(H-pad*2,720*scale)
    local x,y=(W-w)/2,(H-h)/2
    S.color(c.surface);G.rectangle("fill",0,0,W,H)
    S.panel(x,y,w,h,c,.98)
    S.text(d.title,title,x+pad,y+pad,w-pad*2,"left",c.text)
    local rowH=math.max(40*scale,body:getHeight()+pad)
    local rows=d.rows or {}
    local listY=y+pad*2+title:getHeight()
    local helpH=math.max(small:getHeight()*4,pad*3)
    local helpY=y+h-helpH-pad*4-small:getHeight()*2
    local visible=math.max(1,math.floor((helpY-listY-pad)/rowH))
    local selected=d.selected or 1
    local start=math.max(1,math.min(d.start or (selected-math.floor(visible/2)),math.max(1,#rows-visible+1)))
    local taps={state=state,kind="generic",generic=true,mode="list",cells={},phase=state.phase,
      time=love.timer.getTime()}
    local function cell(cx,cy,cw,ch,select,button)
      taps.cells[#taps.cells+1]={kind="row",index=#taps.cells+1,x=cx,y=cy,w=cw,h=ch,
        select=select,button=button or "a"}
    end
    for i=start,math.min(#rows,start+visible-1) do
      local r=rows[i];local yy=listY+(i-start)*rowH
      if i==selected and d.selected then S.color(c.selected);G.rectangle("fill",x+pad,yy,w-pad*2,rowH-3,5,5) end
      local label=tostring(r.label or "")
      local value=tostring(r.value or "")
      local rightW=value~="" and math.min(w*.35,body:getWidth(value)+pad) or 0
      local labelW=w-pad*4-rightW
      -- Fit full names where possible, then truncate by UTF-8 codepoint.
      while body:getWidth(label)>labelW and #label>0 do label=label:gsub("[\1-\127\194-\244][\128-\191]*$","") end
      if label~=tostring(r.label or "") then
        while body:getWidth(label.."...")>labelW and #label>0 do label=label:gsub("[\1-\127\194-\244][\128-\191]*$","") end
        label=label.."..."
      end
      S.text(label,body,x+pad*2,yy+(rowH-body:getHeight())/2,labelW,"left",r.header and c.accent or c.text)
      S.text(value,body,x+w-pad*2-rightW,yy+(rowH-body:getHeight())/2,rightW,"right",c.muted)
      if r.select then cell(x+pad,yy,w-pad*2,rowH,r.select,r.button) end
    end
    local help=tostring(d.help or "")
    local _,lines=small:getWrap(help,w-pad*4)
    local maxLines=math.max(1,math.floor(helpH/small:getHeight()))
    local offset=(tonumber(state.descScroll) or 0)
    if offset>#lines-maxLines then offset=math.max(0,#lines-maxLines) end
    for i=offset+1,math.min(#lines,offset+maxLines) do
      S.text(lines[i],small,x+pad*2,helpY+(i-offset-1)*small:getHeight(),w-pad*4,"left",c.muted)
    end
    local fy=y+h-pad-small:getHeight()
    S.text(d.footer or "A CHOOSE   B BACK",small,x+pad,fy-small:getHeight()-pad,w-pad*2,"center",c.muted)
    local buttons=d.buttons or {{label="UP",button="up"},{label="DOWN",button="down"},{label="BACK",button="b"}}
    local bw=(w-pad*2)/#buttons
    for i,b in ipairs(buttons) do
      local bx=x+pad+(i-1)*bw
      S.text(b.label or ({up="UP",down="DOWN",left="LEFT",right="RIGHT",select="HELP",a="PAGE",b="BACK"})[b.button] or b.button,
        small,bx,fy,bw,"center",c.accent)
      cell(bx,fy-pad,bw,small:getHeight()+pad*2,b.select,b.button)
    end
    mod._kimScreenTapTargets=taps
  end
  mod.hooks:wrap("screen.render_visible",function(nextFn,state)
    if enabled() and type(state)=="table" and state._aioModernData then return false end
    return nextFn(state)
  end,46000)
  mod.hooks:wrap("render.hud",function(nextFn,game,viewport)
    local result=nextFn(game,viewport)
    local top=game and game.stack and game.stack:top()
    if enabled() then
      local d=data(top)
      if d then
        G.push("all");G.origin()
        local ok,err=pcall(draw,top,d)
        G.pop()
        if not ok then error(err,0) end
      end
    end
    return result
  end,46000)
end
