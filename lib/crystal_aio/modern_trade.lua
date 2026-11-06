-- NPC trade presentation; native Typer, trade checks, exchange and timing stay
-- in TradeMenu/TradeAnim. Rejected/cancelled trades never change the party.
return function(host)
  local mod,G=host.mod,love.graphics
  local okT,Trade=pcall(require,"src.ui.gen2.TradeMenu")
  local okA,Anim=pcall(require,"src.ui.gen2.TradeAnim")
  local Typer=require("src.ui.gen2.Typer")
  local Timeline=require("src.core.gen2.TradeAnim")
  local function kind(s)
    if type(s)~="table" then return end
    if okT and getmetatable(s)==Trade then return "dialog" end
    if okA and getmetatable(s)==Anim then return "animation" end
  end
  local function enabled()
    local S=mod._kantoInMotionGen2Ui
    return S and S.presenterEnabled("menu") and S.hideOriginal()
  end
  local function draw(state,k)
    local S=mod._kantoInMotionGen2Ui
    local c=S.theme()
    local W,H=G.getDimensions()
    local scale=math.min(W/800,H/650,1.3)
    local pad=math.max(12,24*scale)
    local f=S.font(math.max(14,26*scale))
    local title=S.font(math.max(18,34*scale))
    local w=math.min(W-pad*2,1000*scale)
    local x=(W-w)/2
    local taps={state=state,kind="generic",generic=true,mode="list",cells={},phase=state.phase,time=love.timer.getTime()}
    if k=="animation" then
      S.color(c.surface);G.rectangle("fill",0,0,W,H)
      local h=math.min(H-pad*2,650*scale)
      local y=(H-h)/2
      S.panel(x,y,w,h,c,.98)
      S.text("POKéMON TRADE",title,x+pad,y+pad,w-pad*2,"center",c.text)
      for i,record in ipairs({state.give or {},state.get or {}}) do
        local cw=(w-pad*3)/2
        local cx=x+pad+(i-1)*(cw+pad)
        local cy=y+title:getHeight()+pad*3
        S.text(i==1 and "SENDING" or "RECEIVING",f,cx,cy,cw,"center",c.accent)
        local image
        if mod.exports.getSprite then
          local ok,img=pcall(mod.exports.getSprite,record.species,{generation="hd"})
          if ok and img and type(img.getDimensions)=="function" then image=img end
        end
        local picH=math.min(cw,h*.34)
        if image then
          local iw,ih=image:getDimensions()
          local s=math.min(cw/iw,picH/ih)*.86
          S.color({1,1,1,1});G.draw(image,cx+cw/2,cy+f:getHeight()+pad+picH/2,0,s,s,iw/2,ih/2)
        end
        local label=tostring(record.name or record.species or "?")
        S.text(label,f,cx,cy+f:getHeight()+pad*2+picH,cw,"center",c.text)
      end
      local progress=math.max(0,math.min(1,(state.frame or 0)/math.max(1,Timeline.TOTAL)))
      local py=y+h-pad*4-f:getHeight()*2
      S.color(c.raised);G.rectangle("fill",x+pad,py,w-pad*2,8)
      S.color(c.accent);G.rectangle("fill",x+pad,py,(w-pad*2)*progress,8)
      local lines=state.lines and state:lines((state.beat or {}).id)
      S.text(lines and table.concat(lines," ") or "Trading Pokémon...",f,x+pad,py+pad,w-pad*2,"center",c.text)
      S.text("B SKIP",f,x+pad,y+h-pad-f:getHeight(),w-pad*2,"center",c.muted)
      taps.cells[1]={kind="row",index=1,x=x,y=y+h-pad*2-f:getHeight(),w=w,h=pad*2+f:getHeight(),button="b"}
    else
      local box=state.message or state.confirm
      if not box then return end
      local page=box.pages and box.pages[box.page or 1] or {}
      local lines=Typer.text(state,page)
      local h=pad*2
      for _,line in ipairs(lines) do
        local _,wrapped=f:getWrap(line,w-pad*2)
        h=h+math.max(1,#wrapped)*f:getHeight()+pad*.5
      end
      local y=H-h-pad*3
      S.panel(x,y,w,h,c,.99)
      local yy=y+pad
      for _,line in ipairs(lines) do
        S.text(line,f,x+pad,yy,w-pad*2,"left",c.text)
        local _,wrapped=f:getWrap(line,w-pad*2)
        yy=yy+math.max(1,#wrapped)*f:getHeight()+pad*.5
      end
      if state.confirm and not Typer.typing(state) and box.page>=#box.pages then
        local row=math.max(40,f:getHeight()+pad)
        local cw=math.min(w*.55,250*scale)
        local cx,cy=x+w-cw,y-row*2-pad*2
        S.panel(cx,cy,cw,row*2+pad,c,.99)
        for i,label in ipairs({"YES","NO"}) do
          local ry=cy+pad/2+(i-1)*row
          if box.choice==i then S.color(c.selected);G.rectangle("fill",cx+pad/2,ry,cw-pad,row-2,4,4) end
          S.text(label,f,cx+pad,ry+(row-f:getHeight())/2,cw-pad*2,"left",c.text)
          taps.cells[#taps.cells+1]={kind="row",index=i,x=cx,y=ry,w=cw,h=row,button="a",
            select=function(st) if st.confirm then st.confirm.choice=i end end}
        end
      end
    end
    mod._kimScreenTapTargets=taps
  end
  mod.hooks:wrap("screen.render_visible",function(nextFn,state)
    if enabled() and kind(state) then return false end
    return nextFn(state)
  end,47000)
  mod.hooks:wrap("render.hud",function(nextFn,game,viewport)
    local result=nextFn(game,viewport)
    local top=game and game.stack and game.stack:top()
    local k=kind(top)
    if k and enabled() then
      G.push("all");G.origin()
      local ok,err=pcall(draw,top,k)
      G.pop()
      if not ok then error(err,0) end
    end
    return result
  end,47000)
end
