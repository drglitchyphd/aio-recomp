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
    -- gen2-aio: the shared close button (B) and footer
    local reserve=S.closeReserve and S.closeReserve() or 0
    if S.closeButton then S.closeButton(x,y,w,h,c) end
    local fb=S.footerHeight and S.footerHeight() or small:getHeight()+pad
    S.text(d.title,title,x+pad,y+pad,math.max(1,w-pad-reserve),"left",c.text)
    local rowH=math.max(40*scale,body:getHeight()+pad)
    local rows=d.rows or {}
    local listY=y+pad*2+title:getHeight()
    local helpH=math.max(small:getHeight()*4,pad*3)
    local helpY=y+h-fb-helpH-pad*3-small:getHeight()
    local visible=math.max(1,math.floor((helpY-listY-pad)/rowH))
    local selected=d.selected or 1
    local start=math.max(1,math.min(d.start or (selected-math.floor(visible/2)),math.max(1,#rows-visible+1)))
    local taps={state=state,kind="generic",generic=true,mode="list",cells={},phase=state.phase,
      time=love.timer.getTime()}
    local function cell(cx,cy,cw,ch,select,button)
      -- button false: the tap only selects (gen2-aio 0.9.72)
      if button==nil then button="a" end
      taps.cells[#taps.cells+1]={kind="row",index=#taps.cells+1,x=cx,y=cy,w=cw,h=ch,
        select=select,button=button}
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
    local footerTop=y+h-fb
    if S.footer then
      S.footer(x,y,w,h,{colors=c,hints=d.footer or {{"A","CHOOSE"},{"B","BACK"}}})
    else
      S.text(d.footer or "A CHOOSE   B BACK",small,x+pad,footerTop,w-pad*2,"center",c.muted)
    end
    local fy=footerTop-pad*.75-small:getHeight()
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
  -- gen2-aio 0.9.72: the Nuzlocke ENCOUNTERS page (kind "tracker"): LOG /
  -- MAP tabs, totals, then one row per area: the Pokemon's icon, the area,
  -- the species and a status chip. Rows take a tap without acting (a tap on
  -- open space would otherwise be A, which flips the tab); a drag scrolls.
  local icons={}
  local function iconFor(state,species,shiny)
    if not species then return nil end
    local key=tostring(species)..(shiny and "*" or "")
    if icons[key]~=nil then return icons[key] or nil end
    local img=nil
    local fn=mod._kantoInMotionHdMenuIconForModernUi
    if type(fn)=="function" then
      local game=state.game or rawget(mod,"_kantoInMotionActiveGame")
      local ok,path=pcall(fn,game,{species=species,isShiny=shiny,shiny=shiny})
      if ok and path then
        local okI,i=false,nil
        if mod.assets and type(mod.assets.image)=="function" then okI,i=pcall(mod.assets.image,mod.assets,path) end
        if not (okI and i) then okI,i=pcall(G.newImage,path) end
        if okI and i then img=i; if img.setFilter then pcall(img.setFilter,img,"nearest","nearest") end end
      end
    end
    icons[key]=img or false
    return img
  end
  local STATUS={
    party={"PARTY",{0.20,0.52,0.85,1}}, caught={"CAUGHT",{0.22,0.60,0.32,1}},
    lost={"FAINTED",{0.78,0.20,0.18,1}}, failed={"FAILED",{0.85,0.50,0.12,1}},
    open={"OPEN",nil},
  }
  local function drawTracker(state,d)
    local S=mod._kantoInMotionGen2Ui
    local c=S.theme()
    local W,H=G.getDimensions()
    local scale=math.min(W/800,H/650,1.35)
    local body=S.font(math.max(14,24*scale))
    local small=S.font(math.max(12,18*scale))
    local title=S.font(math.max(18,31*scale))
    local pad=math.max(12,22*scale)
    local w=math.min(W-pad*2,1100*scale)
    local h=math.min(H-pad*2,860*scale)
    local x,y=(W-w)/2,(H-h)/2
    S.color(c.surface);G.rectangle("fill",0,0,W,H)
    S.panel(x,y,w,h,c,.98)
    local reserve=S.closeReserve and S.closeReserve() or 0
    if S.closeButton then S.closeButton(x,y,w,h,c) end
    local fb=S.footerHeight and S.footerHeight() or small:getHeight()+pad
    local taps={state=state,kind="generic",generic=true,mode="list",cells={},phase=state.phase,
      time=love.timer.getTime()}
    local function cell(cx,cy,cw,ch,select,button)
      taps.cells[#taps.cells+1]={kind="row",index=#taps.cells+1,x=cx,y=cy,w=cw,h=ch,
        select=select,button=button}
    end
    S.text(d.title or "ENCOUNTERS",title,x+pad,y+pad,math.max(1,w-pad-reserve),"left",c.text)
    -- tabs
    local ty=y+pad+title:getHeight()+pad*.6
    local tabH=small:getHeight()+pad*.9
    local tabs=d.tabs or {"LOG"}
    local tabW=math.min(w*.3,small:getWidth("MAP")*4)
    for i,label in ipairs(tabs) do
      local tx=x+pad+(i-1)*(tabW+pad*.5)
      local on=(d.tab or 1)==i
      S.color(on and c.selected or (c.raised or c.surface))
      G.rectangle("fill",tx,ty,tabW,tabH,tabH/2,tabH/2)
      S.color(c.frame or c.accent,on and 1 or .5)
      G.setLineWidth(math.max(1,1.5*scale)); G.rectangle("line",tx,ty,tabW,tabH,tabH/2,tabH/2)
      S.text(label,small,tx,ty+(tabH-small:getHeight())/2,tabW,"center",on and c.text or c.muted)
      if #tabs>1 and d.setTab then
        cell(tx,ty,tabW,tabH,function(st) d.setTab(st,i) end,false)
      end
    end
    -- totals and the level cap, right of the tabs (below them when narrow)
    local k=d.counts or {}
    local totals=("CAUGHT %d   FAINTED %d   FAILED %d"):format(k.caught or 0,k.lost or 0,k.failed or 0)
    local afterTabs=x+pad+#tabs*(tabW+pad*.5)
    local infoY=ty+(tabH-small:getHeight())/2
    local infoW=x+w-pad-afterTabs
    if small:getWidth(totals)>infoW then
      infoY=ty+tabH+pad*.4; afterTabs=x+pad; infoW=w-pad*2
    end
    S.text(totals,small,afterTabs,infoY,infoW,"right",c.muted)
    local capY=math.max(ty+tabH,infoY+small:getHeight())+pad*.4
    if d.cap then S.text(d.cap,small,x+pad,capY,w-pad*2,"left",c.accent) end
    -- rows
    local listY=capY+small:getHeight()+pad*.6
    local listBottom=y+h-fb-pad*.5
    local rowH=math.max(48*scale,body:getHeight()+small:getHeight()+pad*.6)
    local rows=d.rows or {}
    local visible=math.max(1,math.floor((listBottom-listY)/rowH))
    rawset(state,"_aioVisible",visible)
    local start=math.max(1,math.min(d.start or 1,math.max(1,#rows-visible+1)))
    S.color(c.divider or c.muted,.6); G.rectangle("fill",x+pad,listY-pad*.3,w-pad*2,1)
    if #rows==0 then
      S.text(d.empty or "",body,x+pad*2,listY+pad,w-pad*4,"center",c.muted)
    end
    local iconS=rowH*.86
    for i=start,math.min(#rows,start+visible-1) do
      local r=rows[i]; local yy=listY+(i-start)*rowH
      if (i-start)%2==1 then S.color(c.raised or c.surface,.45); G.rectangle("fill",x+pad*.5,yy,w-pad,rowH,6,6) end
      local ix=x+pad
      local img=iconFor(state,r.species,r.shiny)
      if img then
        local iw,ih=img:getDimensions(); local s=math.min(iconS/iw,iconS/ih)
        local a=(r.status=="lost" or r.status=="failed") and .45 or 1
        G.setColor(1,1,1,a); G.draw(img,ix+(iconS-iw*s)/2,yy+(rowH-ih*s)/2,0,s,s)
      else
        S.color(c.muted,.35); G.circle("line",ix+iconS/2,yy+rowH/2,iconS*.28)
      end
      local st=STATUS[r.status] or STATUS.open
      local chip=st[1]
      local chipW=small:getWidth("FAINTED")+pad
      local chipH=small:getHeight()+pad*.35
      local cx=x+w-pad-chipW
      local cy=yy+(rowH-chipH)/2
      if st[2] then
        G.setColor(st[2]); G.rectangle("fill",cx,cy,chipW,chipH,chipH/2,chipH/2)
        S.text(chip,small,cx,cy+(chipH-small:getHeight())/2,chipW,"center",{1,1,1,1})
      else
        S.color(c.muted,.6); G.setLineWidth(math.max(1,scale)); G.rectangle("line",cx,cy,chipW,chipH,chipH/2,chipH/2)
        S.text(chip,small,cx,cy+(chipH-small:getHeight())/2,chipW,"center",c.muted)
      end
      local tx=ix+iconS+pad*.6
      local tw=cx-pad*.6-tx
      local textTop=yy+(rowH-body:getHeight()-small:getHeight())/2
      local label=tostring(r.label or "")
      local lf=body
      -- long area names shrink a little before they would run into the chip
      local px=math.max(14,24*scale)
      while lf:getWidth(label)>tw and px>math.max(11,16*scale) do px=px-1; lf=S.font(px) end
      S.text(label,lf,tx,textTop,tw,"left",c.text)
      local sp=r.species and ((r.shiny and "* " or "")..tostring(r.species)) or "-"
      S.text(sp,small,tx,textTop+body:getHeight(),tw,"left",r.status=="lost" and c.muted or c.accent)
      cell(x+pad*.5,yy,w-pad,rowH,nil,false)
    end
    -- more above / below
    if start>1 then
      S.color(c.accent); local ax=x+w-pad*1.2; G.polygon("fill",ax-6*scale,listY+6*scale,ax+6*scale,listY+6*scale,ax,listY-3*scale)
    end
    if start+visible-1<#rows then
      S.color(c.accent); local ax=x+w-pad*1.2; local ay=listBottom-2*scale
      G.polygon("fill",ax-6*scale,ay-9*scale,ax+6*scale,ay-9*scale,ax,ay)
    end
    if S.footer then S.footer(x,y,w,h,{colors=c,hints=d.footer}) end
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
        local ok,err=pcall(d.kind=="tracker" and drawTracker or draw,top,d)
        G.pop()
        if not ok then error(err,0) end
      end
    end
    return result
  end,46000)
end
