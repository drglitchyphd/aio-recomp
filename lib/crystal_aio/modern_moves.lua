-- gen2-aio 0.9.75: Modern move-learning screens. Full-window presenters for
-- the engine screens that only drew their Game Boy boxes:
--
--   Gen2MoveDeleter   three callers share it: the Blackthorn move deleter,
--                     the PP item's "which move?" pick, and (layout "forget")
--                     LearnMove's "which move should be forgotten?" list,
--                     which Game2:learnMoveOn opens for a 5th move outside
--                     battle (a level-up after battle, evolution, TM, tutor,
--                     RELEARN). The in-battle forget list is BattleState's own
--                     phase and is already drawn by gen2_modern_battle_ui.
--   Gen2MoveTutor     the Goldenrod tutor's party pick (ABLE / NOT ABLE).
--   RELEARN           Gen1Remember's picker: an engine src.ui.Menu that its
--                     screen.lua tags with `relearn = { mon, rows }`.
--
-- The engine states own every input and change. A tap sets the state's own
-- cursor field (MoveDeleter.row, the tutor list's index, Menu.index) and
-- presses A, exactly what the D-pad and A would do; the close button is B.
return function(host)
  local mod,G=host.mod,love.graphics
  local function req(name)
    local ok,M=pcall(require,name)
    if ok and type(M)=="table" then return M end
  end
  local Deleter=req("src.ui.gen2.MoveDeleter")
  local Tutor=req("src.ui.gen2.MoveTutor")
  local Menu=req("src.ui.Menu")
  local PartyMenu=req("src.ui.gen2.PartyMenu")
  local Mon=req("src.battle.gen2.Mon")

  local function enabled()
    local S=mod._kantoInMotionGen2Ui
    return S and S.presenterEnabled("menu") and S.hideOriginal()
  end
  local function isA(s,M) return M~=nil and type(s)=="table" and getmetatable(s)==M end
  local function kind(s)
    if isA(s,Deleter) then return "deleter" end
    if isA(s,Tutor) then return "tutor" end
    if isA(s,Menu) and type(rawget(s,"relearn"))=="table" then return "relearn" end
  end

  -- The forget list does not know which move is coming in (MoveDeleter only
  -- gets the mon), so the move Game2:learnMoveOn was asked to teach is noted
  -- on the way past for the NEW MOVE card. A pass-through: same arguments,
  -- same callback, cleared when LearnMove answers.
  local Game2=package.loaded["src.core.Game2"] or req("src.core.Game2")
  if Game2 and type(Game2.learnMoveOn)=="function" and not Game2.__aioModernMoves then
    local base=Game2.learnMoveOn
    Game2.learnMoveOn=function(self,mon,moveId,onDone,...)
      local note={mon=mon,move=moveId}
      rawset(mod,"_aioLearning",note)
      return base(self,mon,moveId,function(...)
        if rawget(mod,"_aioLearning")==note then rawset(mod,"_aioLearning",nil) end
        if onDone then return onDone(...) end
      end,...)
    end
    Game2.__aioModernMoves=true
  end

  -- the battle UI's type colours (lib/gen2_modern_battle_ui.lua TYPE_RGB)
  local TYPE_RGB={
    NORMAL={.66,.66,.47},FIRE={.93,.50,.19},WATER={.39,.56,.94},ELECTRIC={.97,.82,.19},
    GRASS={.47,.78,.30},ICE={.59,.85,.85},FIGHTING={.75,.19,.16},POISON={.63,.25,.63},
    GROUND={.88,.75,.41},FLYING={.66,.56,.94},PSYCHIC={.97,.35,.53},BUG={.66,.72,.13},
    ROCK={.72,.63,.22},GHOST={.44,.35,.60},DRAGON={.44,.22,.97},DARK={.44,.35,.28},
    STEEL={.72,.72,.82},
  }
  local function opt(key,default)
    local ok,v=pcall(mod.options.get,mod.options,key)
    if ok and v~=nil then return v end
    return default
  end
  local function typeKey(t)
    t=tostring(t or ""):upper():gsub("_TYPE$",""):gsub("^TYPE_",""):gsub("_T$","")
    if t=="CURSE" then return "???" end
    return t
  end
  local function moveDef(game,id)
    local moves=game and game.data and game.data.moves
    return moves and id and moves[id] or nil
  end
  local function moveName(game,id)
    local d=moveDef(game,id)
    return tostring((d and d.name) or (id and tostring(id):gsub("_"," ")) or "-")
  end
  local function power(d)
    local p=tonumber(d and d.power)
    return (p and p>1) and tostring(math.floor(p)) or "-"
  end
  local function accuracy(d)
    local a=tonumber(d and d.accuracy)
    if not a or a<=0 then return "-" end
    if a<=1 then a=a*100 end
    -- the cart's 0-255 byte, as the battle UI reads it
    if a>100 and a<=255 then a=a*100/255 end
    return math.floor(a+.5).."%"
  end
  local function maxPp(game,entry)
    if Mon and Mon.maxPpOf then
      local ok,n=pcall(Mon.maxPpOf,entry,game and game.data)
      if ok and tonumber(n) then return n end
    end
    local d=moveDef(game,entry and entry.id)
    return tonumber(entry and entry.maxPp) or tonumber(d and d.pp) or 0
  end
  local function monName(game,mon)
    if type(mon)~="table" then return "?" end
    local def=game and game.data and game.data.pokemon and game.data.pokemon[mon.species]
    return tostring(mon.nickname or mon.name or (def and def.name) or mon.species or "?")
  end
  local function speciesName(game,species)
    local def=game and game.data and game.data.pokemon and game.data.pokemon[species]
    return tostring((def and def.name) or species or "?")
  end

  -- the party UI's HD menu icon (modern_pages.lua iconFor)
  local icons={}
  local function iconFor(game,mon)
    if type(mon)~="table" or not mon.species or mon.isEgg then return nil end
    local shiny=mon.isShiny or mon.shiny
    local key=tostring(mon.species)..(shiny and "*" or "")
    if icons[key]~=nil then return icons[key] or nil end
    local img=nil
    local fn=mod._kantoInMotionHdMenuIconForModernUi
    if type(fn)=="function" then
      local ok,path=pcall(fn,game or rawget(mod,"_kantoInMotionActiveGame"),
        {species=mon.species,isShiny=shiny,shiny=shiny})
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

  local function fit(S,label,f,maxW)
    label=tostring(label or "")
    if f:getWidth(label)<=maxW then return label end
    while #label>0 and f:getWidth(label.."...")>maxW do label=label:gsub("[\1-\127\194-\244][\128-\191]*$","") end
    return label.."..."
  end

  -- ------------------------------------------------------------ the window
  -- Sized like modern_pages: one scale off the window, the shared close
  -- button and footer, tap cells collected for KIM Touch.
  local function window(state,title,bodyRows)
    local S=mod._kantoInMotionGen2Ui
    local c=S.theme()
    local W,H=G.getDimensions()
    local scale=math.min(W/800,H/650,1.35)
    local L={S=S,c=c,scale=scale,state=state}
    L.body=S.font(math.max(14,24*scale))
    L.small=S.font(math.max(12,19*scale))
    L.title=S.font(math.max(18,31*scale))
    local pad=math.max(12,22*scale); L.pad=pad
    L.rowH=math.max(52*scale,L.body:getHeight()+pad*.9)
    L.fb=S.footerHeight and S.footerHeight() or L.small:getHeight()+pad
    -- the window grows with what it holds, up to the screen
    local need=pad*2+L.title:getHeight()+bodyRows(L)+L.fb+pad
    L.w=math.min(W-pad*2,1100*scale)
    L.h=math.min(H-pad*2,need)
    L.x,L.y=(W-L.w)/2,(H-L.h)/2
    S.color(c.surface);G.rectangle("fill",0,0,W,H)
    S.panel(L.x,L.y,L.w,L.h,c,.98)
    local reserve=S.closeReserve and S.closeReserve() or 0
    L.taps={state=state,kind="generic",generic=true,mode="list",cells={},phase=state.phase,
      time=love.timer.getTime()}
    function L.cell(cx,cy,cw,ch,select,button)
      if button==nil then button="a" end
      L.taps.cells[#L.taps.cells+1]={kind="row",index=#L.taps.cells+1,x=cx,y=cy,w=cw,h=ch,
        select=select,button=button}
    end
    S.text(title,L.title,L.x+pad,L.y+pad,math.max(1,L.w-pad-reserve),"left",c.text)
    L.top=L.y+pad*1.6+L.title:getHeight()
    L.bottom=L.y+L.h-L.fb-pad*.5
    return L
  end
  local function finish(L,hints,closeSelected)
    local S,c=L.S,L.c
    if S.closeButton then S.closeButton(L.x,L.y,L.w,L.h,c,{selected=closeSelected}) end
    if S.footer then S.footer(L.x,L.y,L.w,L.h,{colors=c,hints=hints}) end
    mod._kimScreenTapTargets=L.taps
  end

  -- a type pill: the type's colour (MOVE TYPE COLORS), its name in white
  local function typePill(L,t,x,y,h)
    local S,c,f=L.S,L.c,L.small
    local name=typeKey(t); if name=="" then name="-" end
    local w=f:getWidth("ELECTRIC")+L.pad*.8
    local rgb=opt("moveTypeColors",true)~=false and TYPE_RGB[name] or nil
    if rgb then G.setColor(rgb[1],rgb[2],rgb[3],1) else S.color(c.raised or c.surface) end
    G.rectangle("fill",x,y,w,h,h/2,h/2)
    S.color(c.frame or c.accent,.5); G.setLineWidth(math.max(1,L.scale)); G.rectangle("line",x,y,w,h,h/2,h/2)
    S.text(name,f,x,y+(h-f:getHeight())/2,w,"center",rgb and {1,1,1,1} or c.text)
    return w
  end

  -- one move row: pill, name, right-hand value. `selected` paints the bar.
  local function moveRow(L,x,y,w,h,id,right,selected,dim)
    local S,c,pad=L.S,L.c,L.pad
    if selected then S.color(c.selected);G.rectangle("fill",x,y+2,w,h-4,6,6) end
    local d=moveDef(L.state.game,id)
    local ph=math.min(h*.62,L.small:getHeight()+pad*.5)
    local px=x+pad*.6
    local pw=id and typePill(L,d and d.type,px,y+(h-ph)/2,ph) or L.small:getWidth("ELECTRIC")+pad*.8
    local rw=right and (L.body:getWidth(right)+pad*.5) or 0
    local nx=px+pw+pad*.7
    local nw=math.max(1,x+w-pad*.6-rw-nx)
    local label=id and moveName(L.state.game,id) or "-"
    S.text(fit(S,label,L.body,nw),L.body,nx,y+(h-L.body:getHeight())/2,nw,"left",
      dim and c.muted or (selected and c.text or c.text))
    if right then S.text(right,L.body,x+w-pad*.6-rw,y+(h-L.body:getHeight())/2,rw,"right",c.muted) end
  end

  -- the selected move's numbers, one line
  local function detail(L,id,y,extra)
    local d=moveDef(L.state.game,id)
    if not d then return end
    local s=("POWER %s   ACCURACY %s   PP %s"):format(power(d),accuracy(d),tostring(tonumber(d.pp) or "-"))
    if extra then s=s.."   "..extra end
    L.S.text(fit(L.S,s,L.small,L.w-L.pad*2),L.small,L.x+L.pad,y,L.w-L.pad*2,"left",L.c.muted)
  end

  -- the mon this screen is about: icon, name, level, and a line under it
  local function monHeader(L,mon,line)
    local S,c,pad=L.S,L.c,L.pad
    local hh=math.max(L.body:getHeight()+L.small:getHeight(),56*L.scale)
    local x,y=L.x+pad,L.top
    local img=iconFor(L.state.game,mon)
    local tx=x
    if img then
      local iw,ih=img:getDimensions();local s=math.min(hh/iw,hh/ih)
      G.setColor(1,1,1,1);G.draw(img,x+(hh-iw*s)/2,y+(hh-ih*s)/2,0,s,s)
      tx=x+hh+pad*.5
    end
    local lv=mon and mon.level and ("Lv "..tostring(mon.level)) or ""
    local lw=L.body:getWidth(lv)+pad*.3
    S.text(fit(S,monName(L.state.game,mon),L.body,L.x+L.w-pad-lw-tx),L.body,tx,y,L.x+L.w-pad-lw-tx,"left",c.text)
    S.text(lv,L.body,L.x+L.w-pad-lw,y,lw,"right",c.muted)
    if line then
      S.text(fit(S,line,L.small,L.x+L.w-pad-tx),L.small,tx,y+L.body:getHeight(),L.x+L.w-pad-tx,"left",c.accent)
    end
    L.top=y+hh+pad*.6
    S.color(c.divider or c.muted,.6);G.rectangle("fill",L.x+pad,L.top-pad*.3,L.w-pad*2,1)
  end
  local function headerH(L) return math.max(L.body:getHeight()+L.small:getHeight(),56*L.scale)+L.pad*.6 end

  -- ------------------------------------------------------------ MoveDeleter
  local function belowParty(state)
    local states=state.game and state.game.stack and state.game.stack.states
    for _,s in ipairs(type(states)=="table" and states or {}) do
      if isA(s,PartyMenu) then return true end
    end
    return false
  end
  local function drawDeleter(st)
    local game=st.game
    local list=st.list or {}
    local learning=rawget(mod,"_aioLearning")
    local incoming=st.forget and learning and learning.mon==st.mon and learning.move or nil
    local pp=not st.forget and belowParty(st)
    local title=st.forget and "FORGET A MOVE" or (pp and "RESTORE PP" or "MOVE DELETER")
    local L=window(st,title,function(L)
      return headerH(L)+L.rowH*4+L.small:getHeight()*2+L.pad*1.5
        +(incoming and (L.small:getHeight()+L.rowH+L.pad) or 0)
    end)
    local line
    if st.forget then
      line=incoming and ("is trying to learn "..moveName(game,incoming)..".") or "Which move should be forgotten?"
    elseif pp then line="Restore the PP of which move?"
    else line="Which move should it forget?" end
    monHeader(L,st.mon,line)
    local y=L.top
    for i=1,4 do
      local e=list[i]
      local right=e and ("PP %d/%d"):format(tonumber(e.pp) or 0,maxPp(game,e)) or nil
      moveRow(L,L.x+L.pad,y,L.w-L.pad*2,L.rowH,e and e.id,right,e and i==st.row,not e)
      if e then L.cell(L.x+L.pad,y,L.w-L.pad*2,L.rowH,function(s) s.row=i end) end
      y=y+L.rowH
    end
    local sel=list[st.row]
    if sel then detail(L,sel.id,y+L.pad*.3) end
    y=y+L.small:getHeight()+L.pad*.8
    if incoming then
      L.S.text("NEW MOVE",L.small,L.x+L.pad,y,L.w-L.pad*2,"left",L.c.accent)
      y=y+L.small:getHeight()
      local d=moveDef(game,incoming)
      L.S.color(L.c.raised or L.c.surface,.6);G.rectangle("fill",L.x+L.pad,y+2,L.w-L.pad*2,L.rowH-4,6,6)
      moveRow(L,L.x+L.pad,y,L.w-L.pad*2,L.rowH,incoming,d and d.pp and ("PP "..tostring(d.pp)) or nil,false)
    end
    finish(L,{{"UD","CHOOSE"},{"A",pp and "RESTORE" or "FORGET"},{"B","BACK"}})
  end

  -- ------------------------------------------------------------ MoveTutor
  local function drawTutor(st)
    local game=st.game
    local list=st.list or {}
    local party=list.party or {}
    local L=window(st,"MOVE TUTOR",function(L)
      return L.rowH+L.small:getHeight()+L.pad*1.6+#party*L.rowH*1.15
    end)
    local S,c,pad=L.S,L.c,L.pad
    -- the move being taught
    moveRow(L,L.x+pad,L.top,L.w-pad*2,L.rowH,st.move,nil,false)
    detail(L,st.move,L.top+L.rowH)
    local y=L.top+L.rowH+L.small:getHeight()+pad*.8
    S.color(c.divider or c.muted,.6);G.rectangle("fill",L.x+pad,y-pad*.4,L.w-pad*2,1)
    local rh=L.rowH*1.15
    for i,mon in ipairs(party) do
      local on=list.index==i
      local x,w=L.x+pad,L.w-pad*2
      if on then S.color(c.selected);G.rectangle("fill",x,y+2,w,rh-4,6,6) end
      local img=iconFor(game,mon)
      local is=rh*.86
      if img then
        local iw,ih=img:getDimensions();local s=math.min(is/iw,is/ih)
        G.setColor(1,1,1,1);G.draw(img,x+pad*.3+(is-iw*s)/2,y+(rh-ih*s)/2,0,s,s)
      end
      -- the engine's own ABLE / NOT ABLE (PartyMenu:tmhmAble over the
      -- tutor's species view); a mon that has it already says so
      local chip
      if type(list.tmhmAble)=="function" then
        local ok,v=pcall(list.tmhmAble,list,mon); chip=ok and v or nil
      end
      for _,m in ipairs(mon.moves or {}) do if m.id==st.move then chip="KNOWS IT" end end
      chip=chip and tostring(chip):upper() or ""
      local able=chip=="ABLE"
      local cw=L.small:getWidth("NOT ABLE")+pad
      local ch=L.small:getHeight()+pad*.35
      local cx=x+w-pad*.5-cw
      if chip~="" then
        if able then S.color(c.accent);G.rectangle("fill",cx,y+(rh-ch)/2,cw,ch,ch/2,ch/2)
        else S.color(c.muted,.6);G.setLineWidth(math.max(1,L.scale));G.rectangle("line",cx,y+(rh-ch)/2,cw,ch,ch/2,ch/2) end
        S.text(chip,L.small,cx,y+(rh-L.small:getHeight())/2,cw,"center",able and (c.surface or {0,0,0,1}) or c.muted)
      end
      local tx=x+pad*.6+is
      local lv="Lv "..tostring(mon.level or "?")
      local lw=L.small:getWidth(lv)+pad
      local nw=math.max(1,cx-pad*.5-lw-tx)
      S.text(fit(S,monName(game,mon),L.body,nw),L.body,tx,y+(rh-L.body:getHeight())/2,nw,"left",
        (able or chip=="") and c.text or c.muted)
      S.text(lv,L.small,cx-pad*.5-lw,y+(rh-L.small:getHeight())/2,lw,"right",c.muted)
      L.cell(x,y,w,rh,function(s) if s.list then s.list.index=i end end)
      y=y+rh
    end
    local cancel=type(list.isCancel)=="function" and list:isCancel() or false
    finish(L,{{"UD","CHOOSE"},{"A","TEACH"},{"B","BACK"}},cancel)
  end

  -- ------------------------------------------------------------ RELEARN
  local function drawRelearn(st)
    local game=st.game
    local info=rawget(st,"relearn")
    local rows=info.rows or {}
    local items=st.items or {}
    local W,H=G.getDimensions()
    local L0={}
    local L=window(st,"RELEARN A MOVE",function(L)
      L0.room=math.max(3,math.floor((H-L.pad*4-L.title:getHeight()-headerH(L)-L.fb-L.small:getHeight()*3)/L.rowH))
      L0.visible=math.min(#items,L0.room,8)
      local scroll=#items>L0.visible and (L.small:getHeight()+L.pad*1.5) or 0
      return headerH(L)+L0.visible*L.rowH+L.small:getHeight()*2+L.pad+scroll
    end)
    local S,c,pad=L.S,L.c,L.pad
    monHeader(L,info.mon,("%d move%s to relearn"):format(#items,#items==1 and "" or "s"))
    local visible=math.max(1,L0.visible)
    local sel=tonumber(st.index) or 1
    -- the selected row stays in view (the Menu's own scroll is 6 rows)
    local start=math.max(1,math.min(sel-math.floor(visible/2),#items-visible+1))
    local y=L.top
    for i=start,math.min(#items,start+visible-1) do
      local r=rows[i] or {}
      moveRow(L,L.x+pad,y,L.w-pad*2,L.rowH,r.move,r.level and ("Lv "..tostring(r.level)) or nil,i==sel)
      L.cell(L.x+pad,y,L.w-pad*2,L.rowH,function(s)
        s.index=i
        if type(s.clampScroll)=="function" then s:clampScroll() end
      end)
      y=y+L.rowH
    end
    local r=rows[sel]
    if r then
      detail(L,r.move,y+pad*.3,r.inherited and ("FROM "..speciesName(game,r.species)) or nil)
    end
    if #items>visible then
      -- UP / DOWN for lists longer than the window (the D-pad's own keys)
      local by=L.y+L.h-L.fb-pad*.5-L.small:getHeight()
      local bw=(L.w-pad*2)/2
      for k,b in ipairs({{"UP","up"},{"DOWN","down"}}) do
        local bx=L.x+pad+(k-1)*bw
        S.text(b[1],L.small,bx,by,bw,"center",c.accent)
        L.cell(bx,by-pad*.5,bw,L.small:getHeight()+pad,nil,b[2])
      end
    end
    finish(L,{{"UD","CHOOSE"},{"A","LEARN"},{"B","BACK"}})
  end

  local DRAW={deleter=drawDeleter,tutor=drawTutor,relearn=drawRelearn}
  mod.hooks:wrap("screen.render_visible",function(nextFn,state)
    if enabled() and kind(state) then return false end
    return nextFn(state)
  end,46500)
  mod.hooks:wrap("render.hud",function(nextFn,game,viewport)
    local result=nextFn(game,viewport)
    local top=game and game.stack and type(game.stack.top)=="function" and game.stack:top()
    local k=enabled() and kind(top)
    if k then
      G.push("all");G.origin()
      local ok,err=pcall(DRAW[k],top)
      G.pop()
      if not ok and type(mod._kimArenaDiag)=="function" then mod._kimArenaDiag("modern moves",tostring(err)) end
    end
    return result
  end,46500)
  return {kind=kind}
end
