-- gen2-aio 0.9.75: Modern UI windows for the small Crystal screens that only
-- ever drew their native Game Boy boxes: the Bug-Catching Contest's STOCK /
-- THIS compare, the Battle Tower's level desk, the bedroom PC's DECORATION
-- lists, the elevator's floors, Buena's password and prize lists, the
-- Cianwood photo card, and the Game Corner prize / coin counters.
--
-- Presentation only. Each provider below reads a screen's live fields and
-- returns a description; a tap sets the same cursor field the screen's own
-- UP/DOWN would and then taps A (or B), so coins, items, decorations and the
-- contest mon change only through the engine's own update code.
--
-- The Game Corner prize counters are not src/ui/gen2/PrizeMenu.lua: the game
-- never pushes that class (Screens.lua gives it no id). Talking to a vendor
-- runs the map script, which opens a Gen2ScriptMenu with balance "coins"
-- (prizes) or "moneycoins" (the coin vendor). Those two ScriptMenus get the
-- Mart-style window here; every other ScriptMenu keeps the generic one in
-- gen2_modern_dialog_ui.lua.
return function(host)
  local mod, G = host.mod, love.graphics
  local function S() return mod._kantoInMotionGen2Ui end
  local function enabled()
    local s=S()
    return s and s.presenterEnabled("menu") and s.hideOriginal()
  end
  local classes={}
  local function class(name)
    local c=classes[name]
    if c==nil then local ok,m=pcall(require,name); c=ok and type(m)=="table" and m or false; classes[name]=c end
    return c or nil
  end
  local function isA(state,name)
    local c=type(state)=="table" and class(name)
    return c~=nil and c~=false and getmetatable(state)==c
  end
  local function str(v)
    local Strings=class("src.core.Strings")
    if Strings and v~=nil then local ok,s=pcall(Strings,v); if ok and s~=nil then return tostring(s) end end
    return tostring(v or "")
  end
  -- engine text carries the cart's tile macros; spell them out for a TTF face
  local function clean(v)
    v=tostring(v or "")
    v=v:gsub("<PK><MN>","POKéMON"):gsub("<PO><KE>","POKé"):gsub("#","POKé")
    v=v:gsub("<LV>","Lv"):gsub("<ID>","ID"):gsub("№","No."):gsub("<[%u%d_]+>","")
    return v
  end
  local function lines(v)
    if type(v)=="table" then
      local out={}
      for _,l in ipairs(v) do out[#out+1]=clean(l) end
      return table.concat(out," ")
    end
    return (clean(v):gsub("\f"," "):gsub("\n"," "))
  end
  local function now() return love.timer and love.timer.getTime and love.timer.getTime() or 0 end
  local function fit(label,f,maxW)
    label=tostring(label or "")
    if maxW<=0 then return "" end
    if f:getWidth(label)<=maxW then return label end
    while #label>0 and f:getWidth(label.."...")>maxW do label=label:gsub("[\1-\127\194-\244][\128-\191]*$","") end
    return label.."..."
  end
  local function yesNo(sel,set)
    return {{label="YES",selected=sel==1,select=function(st) set(st,1) end},
      {label="NO",selected=sel==2,select=function(st) set(st,2) end}}
  end

  -- -------------------------------------------------------------- icons
  local icons={}
  local function iconFor(game,mon)
    if type(mon)~="table" or not mon.species then return nil end
    local key=tostring(mon.species)..(mon.shiny and "*" or "")
    if icons[key]~=nil then return icons[key] or nil end
    local img
    local fn=rawget(mod,"_kantoInMotionHdMenuIconForModernUi")
    if type(fn)=="function" then
      local ok,path=pcall(fn,game,mon)
      if ok and path then
        local okI,i=false,nil
        if mod.assets and type(mod.assets.image)=="function" then okI,i=pcall(mod.assets.image,mod.assets,path) end
        if not (okI and i) then okI,i=pcall(G.newImage,path) end
        if okI and i then img=i; pcall(img.setFilter,img,"nearest","nearest") end
      end
    end
    icons[key]=img or false
    return img
  end
  local function drawIcon(game,mon,x,y,size,alpha)
    local img=iconFor(game,mon)
    if not img then return false end
    local iw,ih=img:getDimensions()
    local s=math.min(size/iw,size/ih)
    G.setColor(1,1,1,alpha or 1)
    G.draw(img,x+(size-iw*s)/2,y+(size-ih*s)/2,0,s,s)
    return true
  end

  -- ---------------------------------------------------------- providers
  -- Each returns nil (not ours) or a table: title, info (top right), prompt,
  -- rows {label,value,tag,icon,dim,select,button}, selected, detail, cards,
  -- custom(x,y,w,h,ctx), message (text), choices, hints, close (false = no
  -- close button), sig (what the tap cells were drawn for).
  local P={}

  -- The Game Corner counters (see the top of this file).
  P.prize=function(st)
    if not (isA(st,"src.ui.gen2.ScriptMenu") and (st.balance=="coins" or st.balance=="moneycoins")) then return nil end
    local CoinCase=class("src.core.gen2.CoinCase")
    local coins=0
    if CoinCase and CoinCase.coins then local ok,v=pcall(CoinCase.coins,st.save); coins=ok and tonumber(v) or 0 end
    local player=st.save and st.save.player
    local money=tonumber(player and player.money) or 0
    local vendor=st.balance=="moneycoins"
    local cols=math.max(1,tonumber(st.cols) or 1)
    local sel=((tonumber(st.row) or 1)-1)*cols+(tonumber(st.col) or 1)
    local rows={}
    for i,label in ipairs(st.items or {}) do
      local text=clean(str(label)):gsub("^%s+",""):gsub("%s+$","")
      -- the cart pads name and price into one literal: "TM32    1500",
      -- " 50 :  ¥1000"; split it so the price lines up on the right
      -- (¥ is two bytes, so "¥?" in a pattern would only make its last
      -- byte optional: try with and without it)
      local name,price=text:match("^(.-)%s*:?%s+(¥%d+)$")
      if not name then name,price=text:match("^(.-)%s*:?%s+(%d+)$") end
      if not name or name=="" then name,price=text,nil end
      if price and vendor and name:match("^%d+$") then name=name.." COINS" end
      if price and not price:find("¥") then price=price.." COINS" end
      rows[i]={label=name,value=price,select=function(s)
        s.row=math.floor((i-1)/cols)+1; s.col=(i-1)%cols+1 end}
    end
    local info=("COINS %04d"):format(coins)
    if vendor then info=("¥%d   "):format(money)..info end
    local pick=rows[sel]
    local detail
    if pick and pick.value then
      detail={title=pick.label,lines={"COST  "..pick.value,
        vendor and ("YOU HAVE  ¥%d"):format(money) or ("YOU HAVE  %d COINS"):format(coins)}}
    elseif pick then
      detail={title=pick.label,lines={vendor and "Leave the counter." or "Leave the prize counter."}}
    end
    return {title=vendor and "GAME CORNER" or "PRIZE EXCHANGE",info=info,rows=rows,selected=sel,
      detail=detail,prompt=st._aioPrompt,hints={{"UD","CHOOSE"},{"A","EXCHANGE"},{"B","BACK"}},sig="list"}
  end

  -- Bug-Catching Contest: keep the mon in stock or switch to the new one.
  P.contest=function(st)
    if not isA(st,"src.ui.gen2.ContestMenu") then return nil end
    local function card(label,mon)
      mon=mon or {}
      return {label=label,mon=mon,name=clean(mon.nickname or mon.name or mon.species or "?"),
        level=mon.level or 1,stat="HEALTH",value=tonumber(mon.maxHp or (mon.stats and mon.stats.hp)) or 0}
    end
    return {title="BUG-CATCHING CONTEST",cards={card("STOCK POKéMON",st.stock),card("THIS POKéMON",st.caught)},
      message="Switch POKéMON?",choices=yesNo(st.choice==2 and 2 or 1,function(s,i) s.choice=i end),
      hints={{"UD","CHOOSE"},{"A","OK"},{"B","KEEP"}},sig="ask",height=900}
  end

  -- Battle Tower desk: the level groups as one list (the cart spins a single
  -- row with arrows), then the cancel question or a refusal.
  P.tower=function(st)
    if not isA(st,"src.ui.gen2.BattleTowerMenu") then return nil end
    local phase=tostring(st.phase or "pick")
    local pick=phase=="pick"
    local rows={}
    local list=st.rows or {}
    for i=1,#list+1 do
      local r=list[i]
      rows[i]={label=r and ("LEVEL %d"):format((tonumber(r.group) or 0)*10) or "CANCEL",
        dim=not pick,
        select=pick and function(s) s.cursor=i end or nil}
    end
    local d={title="BATTLE TOWER",rows=rows,selected=pick and st.cursor or nil,sig=phase,
      hints={{"UD","CHOOSE"},{"A","OK"},{"B","BACK"}}}
    if pick then d.prompt=lines(st.message)
    else
      d.message=lines(st.message)
      if phase=="quit" then d.choices=yesNo(st.yes and 1 or 2,function(s,i) s.yes=(i==1) end) end
    end
    return d
  end

  -- Bedroom PC decorations: categories, a category's items (with what is
  -- already set up), then RIGHT / LEFT SIDE for an ornament.
  P.deco=function(st)
    if not isA(st,"src.ui.gen2.DecorationMenu") then return nil end
    local Deco=class("src.core.gen2.Decorations")
    local placed=type(st.state)=="table" and st.state or {}
    local talking=st.pages~=nil
    local mode=tostring(st.mode or "category")
    local rows,sel,prompt={},nil,nil
    local function row(label,setIndex,i,extra)
      local r={label=clean(label),dim=talking,select=(not talking) and function(s) s[setIndex]=i end or nil}
      for k,v in pairs(extra or {}) do r[k]=v end
      rows[#rows+1]=r
    end
    if mode=="side" then
      local ok,name=false,nil
      if Deco and Deco.name then ok,name=pcall(Deco.name,st.pendingDeco) end
      prompt=clean(ok and name and ("Which side for the %s?"):format(tostring(name)) or "Which side?")
      for i,label in ipairs({"RIGHT SIDE","LEFT SIDE","CANCEL"}) do row(str(label),"sideIndex",i) end
      sel=st.sideIndex
    elseif mode=="items" then
      prompt=st.category and str(st.category.label) or nil
      for i,id in ipairs(st.rows or {}) do
        local ok,label=pcall(st.rowName,st,id)
        -- which slot this row sets up, to mark the one already standing
        local tag
        local attr=Deco and Deco.attributes and Deco.attributes(id)
        local act=attr and attr.action and Deco.ACTIONS and Deco.ACTIONS[attr.action]
        if act and not act.put and id~=0 then
          if act.ornament then
            if placed.leftOrnament==id then tag="LEFT" end
            if placed.rightOrnament==id then tag=tag and "BOTH" or "RIGHT" end
          elseif act.slot and placed[act.slot]==id then tag="SET UP" end
        end
        row(ok and label or "?","index",i,{tag=tag})
      end
      sel=st.index
    else
      for i,cat in ipairs(st.categories or {}) do row(str(cat.label),"index",i) end
      row(str("EXIT"),"index",#rows+1)
      sel=st.index
    end
    local d={title="DECORATION",prompt=prompt,rows=rows,selected=sel,sig=mode..(talking and ":msg" or ""),
      hints={{"UD","CHOOSE"},{"A","OK"},{"B","BACK"}}}
    if talking then
      local shown=st.typer and type(st.typer.lines)=="function" and select(2,pcall(st.typer.lines,st.typer))
      d.messageFull=lines(st.pages[st.pageIndex or 1] or "")
      d.message=type(shown)=="table" and lines(shown) or d.messageFull
    end
    return d
  end

  -- The elevator's floors; the floor the player got in on is tagged.
  P.elevator=function(st)
    if not isA(st,"src.ui.gen2.ElevatorMenu") then return nil end
    local E=class("src.ui.gen2.ElevatorMenu")
    local function name(row)
      local ok,v=pcall(E.floorName,st.floorNames,row and row.floorId)
      return ok and clean(v) or "?"
    end
    local rows={}
    for i,r in ipairs(st.floors or {}) do
      rows[i]={label=name(r),tag=(i==st.origin) and "NOW ON" or nil,select=function(s) s.index=i end}
    end
    local origin=st.origin and st.floors and st.floors[st.origin]
    return {title="ELEVATOR",info=origin and ("NOW ON  "..name(origin)) or nil,prompt="Which floor?",
      rows=rows,selected=st.index,sig="list",hints={{"UD","FLOOR"},{"A","GO"},{"B","BACK"}}}
  end

  -- Buena: the password words (B is disabled on the cart, so no close button
  -- and no B hint) or the Blue Card prize list.
  P.buena=function(st)
    if not isA(st,"src.ui.gen2.BuenaPassword") then return nil end
    local rows={}
    if st.mode=="prize" then
      for i,p in ipairs(st.prizes or {}) do
        rows[i]={label=clean(p.name or p.item),value=("%d PTS"):format(tonumber(p.cost) or 0),
          select=function(s) s.index=i end}
      end
      local pick=st.prizes and st.prizes[st.index]
      return {title="BLUE CARD PRIZES",info=("POINTS %d"):format(tonumber(st.balance) or 0),
        prompt="Which prize would you like?",rows=rows,selected=st.index,sig="prize",
        detail=pick and {title=clean(pick.name or pick.item),lines={("COST  %d POINTS"):format(tonumber(pick.cost) or 0),
          ("YOU HAVE  %d POINTS"):format(tonumber(st.balance) or 0)}} or nil,
        hints={{"UD","CHOOSE"},{"A","OK"},{"B","BACK"}}}
    end
    for i,w in ipairs(st.words or {}) do rows[i]={label=clean(w),select=function(s) s.index=i end} end
    return {title="BUENA'S PASSWORD",prompt="Which word is today's password?",rows=rows,selected=st.index,
      sig="password",close=false,hints={{"UD","CHOOSE"},{"A","ANSWER"}}}
  end

  -- Cianwood photo studio: the portrait card. A or B (or the close button)
  -- puts it away, as on the cart.
  P.photo=function(st)
    if not isA(st,"src.ui.gen2.PhotoStudio") then return nil end
    return {title="PHOTO STUDIO",custom="photo",sig="card",hints={{"A","OK"},{"B","BACK"}},height=700}
  end

  local ORDER={"prize","contest","tower","deco","elevator","buena","photo"}
  local function describe(state)
    if type(state)~="table" then return nil end
    for _,k in ipairs(ORDER) do
      local ok,d=pcall(P[k],state)
      if ok and d then d.kind=k; return d end
    end
    return nil
  end

  -- ------------------------------------------------------------ drawing
  local function drawPhoto(st,x,y,w,h,ctx)
    local s,c,body,small,big,pad=ctx.S,ctx.c,ctx.body,ctx.small,ctx.big,ctx.pad
    local mon=st.mon or {}
    local def=type(st.speciesDef)=="function" and select(2,pcall(st.speciesDef,st)) or nil
    def=type(def)=="table" and def or nil
    local size=math.floor(math.min(w*.4,h*.5)/56)*56
    if size<56 then size=math.min(w*.4,h*.5) end
    -- the cart's own pic, palette and padding (PhotoStudio:drawPic), scaled
    s.color(c.raised or c.surface); G.rectangle("fill",x,y,size,size,6,6)
    G.push(); G.translate(x,y); G.scale(size/56,size/56)
    local okPic=pcall(st.drawPic,st)
    G.pop()
    if not okPic then drawIcon(st.game,mon,x,y,size) end
    s.color(c.frame or c.accent); G.setLineWidth(math.max(2,size*.012)); G.rectangle("line",x,y,size,size,6,6)
    local tx=x+size+pad; local tw=x+w-tx
    local yy=y
    -- one label column wide enough for the longest label ("IDNo.")
    local lw=body:getWidth("IDNo.")+pad*1.5
    local function line(label,value,f,col)
      f=f or body
      local l=math.min(tw*.42,lw)
      s.text(fit(label,f,l),f,tx,yy,l,"left",c.muted)
      s.text(fit(value,f,tw-l),f,tx+l,yy,tw-l,"left",col or c.text)
      yy=yy+f:getHeight()+pad*.35
    end
    s.text(fit(clean(mon.nickname or mon.name or mon.species or "?"),big,tw),big,tx,yy,tw,"left",c.text)
    yy=yy+big:getHeight()+pad*.2
    s.text(fit("/"..clean((def and def.name) or mon.species or "?"),body,tw),body,tx,yy,tw,"left",c.accent)
    yy=yy+body:getHeight()+pad*.6
    line("No.",("%03d"):format(tonumber(def and def.dex) or 0))
    line("Lv",tostring(mon.level or 1))
    line("HP",tostring(mon.maxHp or mon.hp or 0))
    -- spelled out: the UI faces have no ♂ / ♀ glyphs
    local g=mon.gender=="male" and "MALE" or mon.gender=="female" and "FEMALE" or nil
    if g or mon.shiny then line("",(g or "")..((g and mon.shiny) and "  " or "")..(mon.shiny and "SHINY" or ""),body,c.accent) end
    local by=math.max(yy,y+size)+pad
    s.color(c.divider or c.muted,.6); G.rectangle("fill",x,by,w,1)
    yy=by+pad*.6; tx,tw=x,w
    line("OT/",clean(mon.ot or st.playerName or "?"))
    line("IDNo.",("%05d"):format(tonumber(mon.otId) or 0))
    local okM,move=pcall(st.moveName,st)
    line("MOVE",clean(okM and move or "-"))
  end

  local function drawCards(d,st,x,y,w,h,ctx)
    local s,c,body,small,big,pad=ctx.S,ctx.c,ctx.body,ctx.small,ctx.big,ctx.pad
    local n=#d.cards
    local side=w>=1300
    local cw=side and (w-pad*(n-1))/n or w
    local ch=side and h or math.min((h-pad*(n-1))/n,big:getHeight()*4.4+pad*2)
    for i,cd in ipairs(d.cards) do
      local cx=side and x+(i-1)*(cw+pad) or x
      local cy=side and y or y+(i-1)*(ch+pad)
      s.color(c.raised or c.surface,.8); G.rectangle("fill",cx,cy,cw,ch,8,8)
      s.color(c.frame or c.accent,.7); G.setLineWidth(math.max(1.5,ctx.scale*1.4)); G.rectangle("line",cx,cy,cw,ch,8,8)
      s.text(cd.label,small,cx+pad,cy+pad*.6,cw-pad*2,"left",c.accent)
      local top=cy+pad*.6+small:getHeight()+pad*.4
      local icon=math.min(ch-(top-cy)-pad*.6,cw*.32)
      local hasIcon=drawIcon(st.game,cd.mon,cx+pad*.6,top,icon)
      if not hasIcon then s.color(c.muted,.35); G.circle("line",cx+pad*.6+icon/2,top+icon/2,icon*.3) end
      local tx=cx+pad*.6+icon+pad*.6; local tw=cx+cw-pad-tx
      local ty=top+math.max(0,(icon-big:getHeight()-body:getHeight()*2-pad*.5)/2)
      s.text(fit(cd.name,big,tw),big,tx,ty,tw,"left",c.text)
      ty=ty+big:getHeight()+pad*.2
      s.text("Lv "..tostring(cd.level),body,tx,ty,tw,"left",c.muted)
      ty=ty+body:getHeight()+pad*.3
      s.text(cd.stat,body,tx,ty,tw*.6,"left",c.muted)
      s.text(tostring(cd.value),body,tx,ty,tw,"right",c.text)
    end
  end

  local function draw(st,d)
    local s=S()
    local c=s.theme()
    local W,H=G.getDimensions()
    local scale=math.min(W/800,H/650,1.35)
    local body=s.font(math.max(14,24*scale))
    local small=s.font(math.max(12,19*scale))
    local big=s.font(math.max(16,28*scale))
    local title=s.font(math.max(18,31*scale))
    local pad=math.max(12,22*scale)
    local w=math.min(W-pad*2,1100*scale)
    local h=math.min(H-pad*2,(d.height or 860)*scale)
    local x,y=(W-w)/2,(H-h)/2
    local ctx={S=s,c=c,body=body,small=small,big=big,pad=pad,scale=scale}
    -- opaque: the generic ScriptMenu window the dialog presenter drew under
    -- a prize counter must not show through
    s.color(c.surface,1); G.rectangle("fill",0,0,W,H)
    s.panel(x,y,w,h,c,.98)
    local reserve=0
    if d.close~=false then
      reserve=s.closeReserve and s.closeReserve() or 0
      if s.closeButton then s.closeButton(x,y,w,h,c) end
    end
    local fb=s.footerHeight and s.footerHeight() or small:getHeight()+pad
    local drawn=d.sig
    local taps={state=st,kind="generic",generic=true,cells={},phase=st.phase,time=now(),
      -- a tap counts only while the screen is still in the step it was drawn for
      mode=function(state) local nd=describe(state); return nd and nd.sig==drawn and "list" or nil end}
    local function cell(cx,cy,cw,ch,sel,button,label)
      if button==nil then button="a" end
      taps.cells[#taps.cells+1]={kind="row",index=#taps.cells+1,x=cx,y=cy,w=cw,h=ch,select=sel,button=button,label=label}
    end
    -- title row; the info (balance) sits right of it, or under it when narrow
    local tw=w-pad*2-reserve
    local cy=y+pad
    local infoW=d.info and big:getWidth(d.info) or 0
    if d.info and title:getWidth(d.title)+infoW+pad>tw then
      s.text(fit(d.title,title,tw),title,x+pad,cy,tw,"left",c.text)
      cy=cy+title:getHeight()+pad*.2
      s.text(fit(d.info,big,w-pad*2),big,x+pad,cy,w-pad*2,"left",c.accent)
      cy=cy+big:getHeight()
    else
      s.text(d.title,title,x+pad,cy,tw,"left",c.text)
      if d.info then s.text(d.info,big,x+pad,cy+(title:getHeight()-big:getHeight())/2,tw,"right",c.accent) end
      cy=cy+title:getHeight()
    end
    cy=cy+pad*.5
    if d.prompt and d.prompt~="" then
      local _,wl=small:getWrap(d.prompt,w-pad*2)
      for i,l in ipairs(wl) do s.text(l,small,x+pad,cy+(i-1)*small:getHeight(),w-pad*2,"left",c.muted) end
      cy=cy+#wl*small:getHeight()+pad*.4
    end
    s.color(c.divider or c.muted,.6); G.rectangle("fill",x+pad,cy,w-pad*2,math.max(1,scale))
    cy=cy+pad*.6
    local footerTop=y+h-fb
    local bottom=footerTop-pad*.5
    -- the message / question panel, above the footer
    local msgY,msgH
    if d.message then
      local mw=w-pad*2
      local _,ml=body:getWrap(d.message,mw-pad*2)
      -- sized for the whole page, so a message still typing does not grow
      local _,full=body:getWrap(d.messageFull or d.message,mw-pad*2)
      local btnH=math.max(56*scale,body:getHeight()+pad)
      msgH=pad*2+math.max(#ml,#full,1)*body:getHeight()+(d.choices and btnH+pad*.8 or 0)
      msgY=bottom-msgH
      s.panel(x+pad,msgY,mw,msgH,c,.99)
      for i,l in ipairs(ml) do s.text(l,body,x+pad*2,msgY+pad+(i-1)*body:getHeight(),mw-pad*2,"left",c.text) end
      if d.choices then
        local n=#d.choices
        local bw=math.min((mw-pad*(n+1))/n,320*scale)
        local by=msgY+msgH-pad-btnH
        local bx=x+pad+mw-pad-(bw*n+pad*(n-1))
        for i,ch in ipairs(d.choices) do
          local xx=bx+(i-1)*(bw+pad)
          s.color(ch.selected and c.selected or (c.raised or c.surface)); G.rectangle("fill",xx,by,bw,btnH,8,8)
          s.color(c.frame or c.accent,ch.selected and 1 or .5); G.setLineWidth(math.max(1.5,scale*1.4))
          G.rectangle("line",xx,by,bw,btnH,8,8)
          s.text(ch.label,body,xx,by+(btnH-body:getHeight())/2,bw,"center",ch.selected and c.text or c.muted)
          cell(xx,by,bw,btnH,ch.select,nil,ch.label)
        end
      end
      bottom=msgY-pad*.5
    end
    local areaH=bottom-cy
    if d.cards then drawCards(d,st,x+pad,cy,w-pad*2,areaH,ctx) end
    if d.custom=="photo" then
      drawPhoto(st,x+pad,cy,w-pad*2,areaH,ctx)
      -- the card itself: a tap is A (put it away), as anywhere on the screen
      cell(x+pad,cy,w-pad*2,areaH,nil,"a","card")
    end
    if d.rows then
      local rows=d.rows
      local rowH=math.max(52*scale,body:getHeight()+pad*.9)
      local lx,lw,listH=x+pad,w-pad*2,areaH
      local det=d.detail
      local detH=det and (big:getHeight()+#det.lines*small:getHeight()*1.3+pad*2) or 0
      local wide=det and w>=1300
      if wide then lw=w*.56-pad
      elseif det then listH=math.max(rowH,math.min(#rows*rowH,areaH-detH-pad)) end
      local visible=math.max(1,math.floor(listH/rowH))
      local sel=d.selected
      local start=math.max(1,math.min((sel or 1)-math.floor(visible/2),math.max(1,#rows-visible+1)))
      for i=start,math.min(#rows,start+visible-1) do
        local r=rows[i]; local yy=cy+(i-start)*rowH
        local on=i==sel
        if on then s.color(c.selected); G.rectangle("fill",lx,yy+2,lw,rowH-4,6,6) end
        local tx=lx+pad*.6
        if r.icon then
          local isz=rowH*.86
          drawIcon(st.game,r.icon,tx,yy+(rowH-isz)/2,isz,r.dim and .5 or 1)
          tx=tx+isz+pad*.4
        end
        local right=lx+lw-pad*.6
        local value=r.value and tostring(r.value) or nil
        local vw=value and math.min(lw*.45,body:getWidth(value)) or 0
        if value then s.text(value,body,right-vw,yy+(rowH-body:getHeight())/2,vw,"right",on and c.text or c.muted) end
        right=right-(value and vw+pad*.6 or 0)
        if r.tag then
          local chipW=small:getWidth(r.tag)+pad
          local chipH=small:getHeight()+pad*.35
          local chx,chy=right-chipW,yy+(rowH-chipH)/2
          s.color(c.accent,.9); G.rectangle("fill",chx,chy,chipW,chipH,chipH/2,chipH/2)
          s.text(r.tag,small,chx,chy+(chipH-small:getHeight())/2,chipW,"center",c.surface)
          right=chx-pad*.5
        end
        local label=fit(r.label,body,right-tx)
        s.text(label,body,tx,yy+(rowH-body:getHeight())/2,right-tx,"left",(r.dim and not on) and c.muted or c.text)
        if r.select then cell(lx,yy,lw,rowH,r.select,r.button,r.label) end
      end
      -- more above / below
      local ax=lx+lw-pad*.4
      s.color(c.accent)
      if start>1 then G.polygon("fill",ax-7*scale,cy+4*scale,ax+7*scale,cy+4*scale,ax,cy-5*scale) end
      if start+visible-1<#rows then
        local ay=cy+visible*rowH
        G.polygon("fill",ax-7*scale,ay-4*scale,ax+7*scale,ay-4*scale,ax,ay+5*scale)
      end
      if det then
        local dx,dy,dw,dh
        if wide then dx,dy,dw,dh=x+w*.56+pad*.5,cy,w*.44-pad*1.5,math.min(areaH,detH)
        else dx,dy,dw,dh=x+pad,cy+math.min(#rows,visible)*rowH+pad,w-pad*2,detH end
        s.color(c.raised or c.surface,.7); G.rectangle("fill",dx,dy,dw,dh,8,8)
        s.text(fit(det.title,big,dw-pad*2),big,dx+pad,dy+pad,dw-pad*2,"left",c.text)
        for i,l in ipairs(det.lines) do
          s.text(fit(l,small,dw-pad*2),small,dx+pad,dy+pad+big:getHeight()+(i-1)*small:getHeight()*1.3+pad*.3,dw-pad*2,"left",c.muted)
        end
      end
    end
    if s.footer then s.footer(x,y,w,h,{colors=c,hints=d.hints}) end
    mod._kimScreenTapTargets=taps
  end

  -- gen2-aio 0.9.75: the close button shows the back arrow on the steps B
  -- backs out of inside these screens (the Battle Tower's cancel question,
  -- a decoration category's list and the ornament side question).
  local style=S()
  if style and type(style.closeIsBack)=="function" and not style.__aioExtrasBack then
    local old=style.closeIsBack
    style.closeIsBack=function(game,top)
      if isA(top,"src.ui.gen2.BattleTowerMenu") then return top.phase=="quit" end
      if isA(top,"src.ui.gen2.DecorationMenu") then return top.mode=="items" or top.mode=="side" end
      return old(game,top)
    end
    style.__aioExtrasBack=true
  end

  -- The question a counter's script printed under its menu ("Which prize
  -- would you like?"): the TextBox just below the menu on the stack.
  local function promptBelow(game,top)
    local states=game and game.stack and game.stack.states
    if type(states)~="table" then return nil end
    for i=#states-1,1,-1 do
      local b=states[i]
      if type(b)=="table" and b~=top and type(b.pages)=="table" and b.pageIndex then
        local page=b.pages[b.pageIndex]
        if type(page)=="table" then
          local out={}
          for _,l in ipairs(page) do out[#out+1]=type(l)=="table" and "" or tostring(l) end
          local text=lines(out):gsub("%s+"," "):gsub("^%s+",""):gsub("%s+$","")
          return text~="" and text or nil
        end
        return nil
      end
    end
    return nil
  end

  mod.hooks:wrap("screen.render_visible",function(nextFn,state)
    if enabled() and describe(state) then return false end
    return nextFn(state)
  end,46100)
  mod.hooks:wrap("render.hud",function(nextFn,game,viewport)
    local result=nextFn(game,viewport)
    if enabled() then
      local top=game and game.stack and type(game.stack.top)=="function" and game.stack:top()
      if type(top)=="table" and isA(top,"src.ui.gen2.ScriptMenu") then
        rawset(top,"_aioPrompt",promptBelow(game,top))
      end
      local d=describe(top)
      if d then
        G.push("all"); G.origin()
        local ok,err=pcall(draw,top,d)
        G.pop()
        if not ok then error(err,0) end
      end
    end
    return result
  end,46100)

  mod.exports.gen2ModernExtras={apiVersion=1,describe=describe}
  return true
end
