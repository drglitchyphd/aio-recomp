-- gen2-aio 0.9.75: Modern UI for Crystal's service screens -- the item PC
-- (ItemPcMenu, with its DEPOSIT pack, quantity and toss YES/NO), Mom's money
-- keypad (BankOfMom), the MAILBOX, the party MAIL menu, reading and writing a
-- letter (MailboxMenu / MailMenu / MailRead / MailCompose) and the Day-Care
-- conversation (DayCareMenu).
--
-- Presentation only. Each screen's own update() keeps all input and logic:
-- a tap sets the cursor field that screen's own D-pad would have set (or
-- calls its own method, e.g. PackMenu:switchPocket) and then taps the button,
-- so items, money and mail only ever change through the engine's code.
-- With MODERN UI / MENU UI off (DIALOGUE UI for the Day-Care, which is a
-- speech box and a YES/NO like any other conversation) nothing here runs and
-- the native screen draws untouched.
return function(host)
  local mod,G=host.mod,love.graphics
  local unpackF=table.unpack or unpack
  local function lib(n) local ok,m=pcall(require,n); return ok and type(m)=="table" and m or nil end

  -- class -> kind, resolved on first use (the engine's classes are only
  -- required once a screen could be on the stack)
  local NAMES={itempc="ItemPcMenu",mailbox="MailboxMenu",mailmenu="MailMenu",mailread="MailRead",
    compose="MailCompose",bank="BankOfMom",daycare="DayCareMenu"}
  local classes
  local function kindOf(s)
    if type(s)~="table" then return nil end
    if not classes then
      classes={}
      for k,n in pairs(NAMES) do
        local M=lib("src.ui.gen2."..n)
        if M then classes[M]=k end
      end
    end
    return classes[getmetatable(s)]
  end
  local function enabled(k)
    local S=mod._kantoInMotionGen2Ui
    return S and S.presenterEnabled(k=="daycare" and "dialogue" or "menu") and S.hideOriginal()
  end

  -- text --------------------------------------------------------------------
  local function str(v)
    local Strings=lib("src.core.Strings")
    if Strings then local ok,s=pcall(Strings,v); if ok and s then return tostring(s) end end
    return tostring(v or "")
  end
  -- the cart's glyph tokens as the Modern font can print them
  local function norm(v)
    v=tostring(v or "")
    v=v:gsub("<PK><MN>","POKéMON"):gsub("<PO><KE>","POKé"):gsub("#MON","POKéMON"):gsub("#","POKé")
    v=v:gsub("<NEXT>"," "):gsub("<PK>","PK"):gsub("<MN>","MN"):gsub("<PO>","PO"):gsub("<KE>","KE")
    -- the Modern font has no gender signs
    v=v:gsub("\226\153\130","M"):gsub("\226\153\128","F")
    return v
  end
  local function clip(f,s,w)
    s=tostring(s or "")
    if f:getWidth(s)<=w then return s end
    while #s>0 and f:getWidth(s.."...")>w do s=s:gsub("[%z\1-\127\194-\244][\128-\191]*$","") end
    return s.."..."
  end
  -- what a message record shows now: the Typer's revealed part when the
  -- screen types it out (DayCare, ItemPc), else the page itself (Mail*)
  local function pageLines(s,rec)
    if type(rec)~="table" then return {} end
    local page=rec.pages and rec.pages[rec.page or 1]
    if type(page)=="string" then page={page} end
    page=type(page)=="table" and page or {}
    local Typer=lib("src.ui.gen2.Typer")
    if Typer and s.typer then
      local ok,l=pcall(Typer.text,s,page); if ok and type(l)=="table" then page=l end
    end
    local out={}
    for i,l in ipairs(page) do out[i]=norm(l) end
    return out
  end
  local function typing(s)
    local Typer=lib("src.ui.gen2.Typer")
    return Typer and s.typer and Typer.typing(s) or false
  end
  local function stationery(s,id)
    local items=s.game and s.game.data and s.game.data.items
    local def=items and items[id]
    return norm(def and def.name or tostring(id or "MAIL"):gsub("_"," "))
  end

  -- frame -------------------------------------------------------------------
  local function open(s,mode)
    local S=mod._kantoInMotionGen2Ui
    local W,H=G.getDimensions()
    local k=math.min(W/800,H/650,1.35)
    local o={S=S,c=S.theme(),W=W,H=H,k=k,pad=math.max(12,22*k),fb=S.footerHeight()}
    o.body=S.font(math.max(14,24*k)); o.small=S.font(math.max(12,19*k))
    o.title=S.font(math.max(18,31*k)); o.big=S.font(math.max(20,44*k))
    o.taps={state=s,kind="generic",generic=true,mode=mode or "list",cells={},phase=s.phase,
      time=love.timer.getTime()}
    return o
  end
  local function cell(o,x,y,w,h,select,button)
    -- button false: the tap only selects (a pocket tab, a digit)
    if button==nil then button="a" end
    o.taps.cells[#o.taps.cells+1]={kind="row",index=#o.taps.cells+1,x=x,y=y,w=w,h=h,
      select=select,button=button}
  end
  local function headH(o,sub) return o.pad*1.6+o.title:getHeight()+(sub and o.small:getHeight()+2 or 0) end
  -- the window: panel, close button (B), title and subtitle; content runs
  -- from o.top to o.bottom (above the footer band)
  local function window(o,h,title,sub,noClose)
    local S,pad=o.S,o.pad
    o.w=math.min(o.W-pad*2,1100*o.k); o.h=math.min(o.H-pad*2,h)
    o.x,o.y=(o.W-o.w)/2,(o.H-o.h)/2
    S.panel(o.x,o.y,o.w,o.h,o.c,.98)
    local reserve=0
    if not noClose then S.closeButton(o.x,o.y,o.w,o.h,o.c); reserve=S.closeReserve() end
    local tw=math.max(1,o.w-pad*2-reserve)
    S.text(clip(o.title,title,tw),o.title,o.x+pad,o.y+pad,tw,"left",o.c.text)
    local top=o.y+pad+o.title:getHeight()
    if sub and sub~="" then
      S.text(clip(o.small,sub,tw),o.small,o.x+pad,top+2,tw,"left",o.c.muted)
      top=top+o.small:getHeight()+2
    end
    o.top=top+pad*.6
    o.bottom=o.y+o.h-o.fb-pad*.5
  end
  local function footer(o,hints) o.S.footer(o.x,o.y,o.w,o.h,{colors=o.c,hints=hints}) end
  local function tri(cx,cy,s,dir)
    if dir=="up" then G.polygon("fill",cx,cy-s*.5,cx-s*.6,cy+s*.4,cx+s*.6,cy+s*.4)
    else G.polygon("fill",cx,cy+s*.5,cx-s*.6,cy-s*.4,cx+s*.6,cy-s*.4) end
  end
  local function box(o,x,y,w,h,fill,alpha,line)
    o.S.color(fill or o.c.raised or o.c.surface,alpha or .95); G.rectangle("fill",x,y,w,h,6,6)
    if line then
      o.S.color(line,1); G.setLineWidth(math.max(1.5,2*o.k)); G.rectangle("line",x,y,w,h,6,6)
    end
  end
  -- a row of buttons; list = { {label=, button=, select=, hot=} }
  local function buttons(o,x,y,w,h,list,live)
    local gap=o.pad*.4
    local bw=(w-gap*(#list-1))/#list
    for i,b in ipairs(list) do
      local bx=x+(i-1)*(bw+gap)
      box(o,bx,y,bw,h,b.hot and o.c.selected or nil,.95,o.c.frame or o.c.accent)
      local f=o.body
      o.S.text(clip(f,b.label,bw-4),f,bx,y+(h-f:getHeight())/2,bw,"center",o.c.text)
      if live then cell(o,bx,y,bw,h,b.select,b.button) end
    end
  end
  local function btnH(o) return o.body:getHeight()+o.pad*.9 end
  -- buttons pinned to the bottom of the content area
  local function bottomButtons(o,list,live)
    local h=btnH(o)
    o.bottom=o.bottom-h
    buttons(o,o.x+o.pad,o.bottom,o.w-o.pad*2,h,list,live)
    o.bottom=o.bottom-o.pad*.5
  end

  -- a scrolling list. rows: { label, right, sub, mark }; pick(i) is the
  -- cell's select (nil while an overlay owns input). The visible window is
  -- kept on the state (key) and moves only as far as the cursor needs.
  local function list(o,s,key,rows,sel,x,y,w,h,rowH,pick)
    local S,c,pad=o.S,o.c,o.pad
    local n=#rows
    local vis=math.max(1,math.floor(h/rowH))
    local start=tonumber(rawget(s,key)) or 1
    if sel<start then start=sel elseif sel>start+vis-1 then start=sel-vis+1 end
    start=math.max(1,math.min(start,math.max(1,n-vis+1)))
    rawset(s,key,start)
    for i=start,math.min(n,start+vis-1) do
      local r=rows[i]; local yy=y+(i-start)*rowH
      local on=i==sel
      if on then S.color(c.selected); G.rectangle("fill",x,yy,w,rowH-3,5,5) end
      if r.mark then
        S.color(c.accent); G.setLineWidth(math.max(2,2.5*o.k)); G.rectangle("line",x,yy,w,rowH-3,5,5)
      end
      local right=tostring(r.right or "")
      local rw=right~="" and math.min(w*.4,o.body:getWidth(right)+pad) or 0
      local lw=w-pad*1.5-rw
      local lh=o.body:getHeight()+(r.sub and o.small:getHeight() or 0)
      local ty=yy+(rowH-3-lh)/2
      S.text(clip(o.body,r.label,lw),o.body,x+pad*.7,ty,lw,"left",(on or r.mark) and c.text or c.muted)
      if r.sub then S.text(clip(o.small,r.sub,lw),o.small,x+pad*.7,ty+o.body:getHeight(),lw,"left",c.muted) end
      if rw>0 then
        S.text(right,o.body,x+w-pad*.7-rw,yy+(rowH-3-o.body:getHeight())/2,rw,"right",on and c.text or c.muted)
      end
      if pick then cell(o,x,yy,w,rowH-3,pick(i)) end
    end
    S.color(c.accent)
    local s6=8*o.k
    if start>1 then tri(x+w-s6*1.5,y-s6*.2,s6*1.4,"up") end
    if start+vis-1<n then tri(x+w-s6*1.5,y+vis*rowH+s6*.3,s6*1.4,"down") end
    return vis
  end

  -- the speech box along the bottom of the content area; returns its top
  local function dialog(o,lines,more)
    local S,f,pad=o.S,o.body,o.pad
    local w=o.w-pad*2; local tw=w-pad*2
    local th=0
    for _,l in ipairs(lines) do local _,wr=f:getWrap(l,tw); th=th+math.max(1,#wr)*f:getHeight() end
    local dh=math.max(f:getHeight()*2,th)+pad*2
    local dx,dy=o.x+pad,o.bottom-dh
    S.color({0,0,0,1},.3); G.rectangle("fill",o.x,o.y,o.w,o.h)
    S.panel(dx,dy,w,dh,o.c,1)
    local yy=dy+pad
    for _,l in ipairs(lines) do
      S.text(l,f,dx+pad,yy,tw,"left",o.c.text)
      local _,wr=f:getWrap(l,tw); yy=yy+math.max(1,#wr)*f:getHeight()
    end
    if more and math.floor(love.timer.getTime()*2)%2==0 then
      S.color(o.c.accent); tri(dx+w-pad,dy+dh-pad*.8,f:getHeight()*.5,"down")
    end
    return dy
  end
  -- YES / NO above a speech box; set(state,i) is the engine's choice field
  local function yesNo(o,choice,above,set,right)
    local S,f,pad=o.S,o.body,o.pad
    local rh=f:getHeight()+pad
    local bw=math.max(f:getWidth("YES")*3,o.w*.3)
    local bh=rh*2+pad
    -- right: the edge to align to (the Day-Care box has no window)
    local bx=right and right-bw or o.x+o.w-pad-bw
    local by=above-bh-pad*.6
    S.panel(bx,by,bw,bh,o.c,1)
    for i,label in ipairs({"YES","NO"}) do
      local yy=by+pad*.5+(i-1)*rh
      if i==choice then S.color(o.c.selected); G.rectangle("fill",bx+pad*.4,yy,bw-pad*.8,rh-3,5,5) end
      S.text(str(label),f,bx+pad,yy+(rh-3-f:getHeight())/2,bw-pad*2,"left",i==choice and o.c.text or o.c.muted)
      cell(o,bx+pad*.4,yy,bw-pad*.8,rh-3,function(st) set(st,i) end)
    end
  end
  -- a popup menu centred on the window (Mailbox's READ / PUT IN PACK / ...)
  local function modal(o,title,rows,sel,set)
    local S,f,pad=o.S,o.body,o.pad
    S.color({0,0,0,1},.35); G.rectangle("fill",o.x,o.y,o.w,o.h)
    local rh=f:getHeight()+pad
    local mw=math.min(o.w-pad*4,math.max(560*o.k,o.w*.6))
    local mh=pad*2+o.small:getHeight()+pad*.5+#rows*rh
    local mx,my=o.x+(o.w-mw)/2,o.y+(o.h-mh)/2
    S.panel(mx,my,mw,mh,o.c,1)
    S.text(clip(o.small,title,mw-pad*2),o.small,mx+pad,my+pad,mw-pad*2,"left",o.c.accent)
    local y0=my+pad+o.small:getHeight()+pad*.5
    for i,label in ipairs(rows) do
      local yy=y0+(i-1)*rh
      if i==sel then S.color(o.c.selected); G.rectangle("fill",mx+pad*.5,yy,mw-pad,rh-3,5,5) end
      S.text(label,f,mx+pad,yy+(rh-3-f:getHeight())/2,mw-pad*2,"left",i==sel and o.c.text or o.c.muted)
      cell(o,mx+pad*.5,yy,mw-pad,rh-3,function(st) set(st,i) end)
    end
  end
  -- one letter: stationery, the two message lines, the author
  local function letterH(o,f) return o.small:getHeight()+f:getHeight()*3.4+o.pad*2 end
  local function letter(o,s,entry,x,y,w,h,f)
    local S,c,pad=o.S,o.c,o.pad
    box(o,x,y,w,h,c.raised,.9,c.divider or c.accent)
    if type(entry)~="table" then
      S.text("-",f,x,y+(h-f:getHeight())/2,w,"center",c.muted); return
    end
    local Mail=lib("src.core.gen2.Mail")
    local top,bottom="",""
    if Mail then local ok,a,b=pcall(Mail.lines,entry); if ok then top,bottom=a or "",b or "" end end
    S.text(stationery(s,entry.type),o.small,x+pad,y+pad*.7,w-pad*2,"left",c.accent)
    local ly=y+pad*.7+o.small:getHeight()+pad*.4
    S.text(norm(top),f,x+pad,ly,w-pad*2,"left",c.text)
    S.text(norm(bottom),f,x+pad,ly+f:getHeight()*1.1,w-pad*2,"left",c.text)
    local author=tostring(entry.author or "")
    if author~="" then S.text(norm(author),f,x+pad,y+h-pad*.7-f:getHeight(),w-pad*2,"right",c.muted) end
  end

  -- ItemPcMenu --------------------------------------------------------------
  local POCKETS={"ITEMS","BALLS","KEY ITEMS","TM/HM"}
  local function itemRow(s,r,qty)
    return {label=norm(r.name or r.id),right=qty and ("x%d"):format(r.count or 0) or ""}
  end
  local function drawItemPc(s)
    local Class=getmetatable(s)
    local o=open(s,(s.qtyState or s.confirm) and "sub" or "list")
    local phase=s.phase
    local busy=s.message or s.qtyState or s.confirm or (s.pack and s.pack.message)
    local E=Class.ENTRIES or {}
    local name={withdraw=E[1],deposit=E[2],toss=E[3]}
    local listy=phase=="withdraw" or phase=="toss" or phase=="deposit"
    local title=name[phase] and str(name[phase].label) or (norm(s:playerName()).."'S PC")
    local sub
    if phase=="withdraw" or phase=="toss" then
      sub=("STORED  %d / %d"):format(#(s.rows or {}),Class.PC_ITEM_CAPACITY or 50)
    elseif phase=="deposit" then sub="Choose an item to deposit."
    else sub="What do you want to do?" end
    local rowH=math.max(44*o.k,o.body:getHeight()+o.pad)
    -- lists size to their rows (5 to 10 shown; the DEPOSIT pack keeps 8 so
    -- the window does not jump between pockets)
    local shown=phase=="deposit" and 8 or math.max(5,math.min(10,#(s.rows or {})+1))
    local extra=o.body:getHeight()+o.small:getHeight()*3+btnH(o)+o.pad*2.5
      +(phase=="deposit" and o.small:getHeight()+o.pad*1.4 or 0)
    local h=listy and headH(o,sub)+shown*rowH+extra+o.fb+o.pad*2
      or headH(o,sub)+#(s.entries or {})*rowH+o.fb+o.pad*2.5
    if not listy and (s.message or s.qtyState or s.confirm) then h=math.max(h,620*o.k) end
    window(o,h,title,sub,false)
    local x,w=o.x+o.pad,o.w-o.pad*2
    if not listy then
      local rows={}
      for i,e in ipairs(s.entries or {}) do rows[i]={label=e.builtin and str(e.label) or norm(e.label)} end
      list(o,s,"_aioTop",rows,s.index or 1,x,o.top,w,o.bottom-o.top,rowH,
        not busy and function(i) return function(st) st.index=i end end or nil)
    elseif phase=="deposit" and s.pack then
      local p=s.pack
      bottomButtons(o,{{label="UP",button="up"},{label="DOWN",button="down"}},not busy)
      -- pocket tabs: the pack's own switchPocket, no button
      local tabH=o.small:getHeight()+o.pad*.8
      local tw=w/#POCKETS
      for i,label in ipairs(POCKETS) do
        local tx=x+(i-1)*tw; local on=i==(p.pocketIndex or 1)
        box(o,tx+2,o.top,tw-4,tabH,on and o.c.selected or nil,on and 1 or .7)
        o.S.text(clip(o.small,label,tw-8),o.small,tx,o.top+(tabH-o.small:getHeight())/2,tw,"center",on and o.c.text or o.c.muted)
        if not busy then
          cell(o,tx+2,o.top,tw-4,tabH,function(st)
            local pk=st.pack; local d=i-(pk and pk.pocketIndex or i)
            if d~=0 then pk:switchPocket(d) end
          end,false)
        end
      end
      local detH=o.body:getHeight()+o.small:getHeight()*3+o.pad
      local ly=o.top+tabH+o.pad*.6
      local rows={}
      for i,r in ipairs(p.rows or {}) do
        rows[i]=itemRow(s,r,r.showCount)
        if not r.showCount and r.teaches then rows[i].right=norm(r.teaches) end
      end
      rows[#rows+1]={label=str("CANCEL")}
      local sel=p.index or 1
      list(o,s,"_aioPackTop",rows,sel,x,ly,w,o.bottom-detH-ly-o.pad*.5,rowH,
        not busy and function(i) return function(st)
          if st.pack then st.pack.index=i; st.pack:ensureVisible() end end end or nil)
      local r=(p.rows or {})[sel]
      local dy=o.bottom-detH
      o.S.color(o.c.divider or o.c.muted,.6); G.rectangle("fill",x,dy,w,1)
      o.S.text(r and norm(r.name) or str("CANCEL"),o.body,x,dy+o.pad*.4,w,"left",o.c.text)
      local def=r and s:def(r.id)
      o.S.text(norm(def and def.description or ""),o.small,x,dy+o.pad*.4+o.body:getHeight(),w,"left",o.c.muted)
    else
      bottomButtons(o,{{label="UP",button="up"},{label="DOWN",button="down"},
        {label=s.switching and "PLACE" or "MOVE",button="select",hot=s.switching~=nil}},not busy)
      local detH=o.body:getHeight()+o.small:getHeight()*3+o.pad
      local rows={}
      for i,r in ipairs(s.rows or {}) do
        rows[i]=itemRow(s,r,not s:cantToss(r.id)); rows[i].mark=s.switching==i
      end
      rows[#rows+1]={label=str("CANCEL")}
      local sel=s.listIndex or 1
      list(o,s,"_aioTop",rows,sel,x,o.top,w,o.bottom-detH-o.top-o.pad*.5,rowH,
        not busy and function(i) return function(st) st.listIndex=i; st:ensureVisible() end end or nil)
      local r=(s.rows or {})[sel]
      local dy=o.bottom-detH
      o.S.color(o.c.divider or o.c.muted,.6); G.rectangle("fill",x,dy,w,1)
      o.S.text(r and norm(r.name) or str("CANCEL"),o.body,x,dy+o.pad*.4,w,"left",o.c.text)
      local def=r and s:def(r.id)
      o.S.text(norm(def and def.description or ""),o.small,x,dy+o.pad*.4+o.body:getHeight(),w,"left",o.c.muted)
    end
    -- overlays, in the order ItemPcMenu:update gives them input
    o.bottom=o.y+o.h-o.fb-o.pad*.5
    local hints={{"A","CHOOSE"},{"B","BACK"}}
    if s.message then
      dialog(o,pageLines(s,s.message),s.message.page<#s.message.pages); hints={{"A","NEXT"}}
    elseif s.qtyState then
      local q=s.qtyState
      local lines={}; for i,l in ipairs(q.prompt or {}) do lines[i]=norm(l) end
      local top=dialog(o,lines,false)
      local bh=btnH(o)
      local qh=o.big:getHeight()+bh+o.pad*2.4
      local qy=top-qh-o.pad*.6
      o.S.panel(x,qy,w,qh,o.c,1)
      o.S.text(("x%02d"):format(q.qty or 1),o.big,x,qy+o.pad*.8,w,"center",o.c.text)
      o.S.text(("/ %d"):format(q.max or 1),o.small,x,qy+o.pad*.8+o.big:getHeight()-o.small:getHeight(),w-o.pad,"right",o.c.muted)
      -- the cart's own quantity steps: UP/DOWN one, RIGHT/LEFT ten
      buttons(o,x+o.pad,qy+qh-o.pad*.8-bh,w-o.pad*2,bh,{{label="-10",button="left"},{label="-1",button="down"},
        {label="+1",button="up"},{label="+10",button="right"},{label="OK",button="a",hot=true}},true)
      hints={{"UD","1"},{"LR","10"},{"A","OK"},{"B","BACK"}}
    elseif s.confirm then
      local lines={}; for i,l in ipairs(s.confirm.prompt or {}) do lines[i]=norm(l) end
      local top=dialog(o,lines,false)
      yesNo(o,s.confirm.choice or 1,top,function(st,i) if st.confirm then st.confirm.choice=i end end)
    elseif s.pack and s.pack.message then
      local p=s.pack
      local pages=type(p.pagesFor)=="function" and p:pagesFor(p.message) or {}
      local page=pages[p.messagePage or 1]
      if type(page)~="table" then page={tostring(page or "")} end
      local lines={}; for i,l in ipairs(page) do lines[i]=norm(l) end
      dialog(o,lines,(p.messagePage or 1)<#pages); hints={{"A","NEXT"}}
    elseif phase=="deposit" then hints={{"LR","POCKET"},{"A","CHOOSE"},{"B","BACK"}}
    elseif listy then hints={{"A","CHOOSE"},{"SELECT","MOVE"},{"B","BACK"}} end
    footer(o,hints)
    mod._kimScreenTapTargets=o.taps
  end

  -- MailboxMenu -------------------------------------------------------------
  local function drawMailbox(s)
    local Class=getmetatable(s)
    local Mail=lib("src.core.gen2.Mail") or {}
    local o=open(s,(s.submenu or s.confirm) and "sub" or "list")
    local letters=type(s.box)=="function" and s:box() or {}
    local n=type(s.count)=="function" and s:count() or #letters
    local rowH=math.max(44*o.k,o.body:getHeight()+o.pad)
    local sub=("%d / %d"):format(n,Mail.MAILBOX_CAPACITY or 10)
    local h=headH(o,sub)+math.max(4,n)*rowH+letterH(o,o.body)+btnH(o)+o.fb+o.pad*3.5
    window(o,math.max(h,620*o.k),"MAILBOX",sub,false)
    local x,w=o.x+o.pad,o.w-o.pad*2
    local busy=s.message or s.confirm or s.submenu
    if n>0 then
      bottomButtons(o,{{label="UP",button="up"},{label="DOWN",button="down"}},not busy)
      local lh=letterH(o,o.body)
      local rows={}
      for i,e in ipairs(letters) do
        local a=tostring(e.author or ""); a=a~="" and norm(a) or "-"
        rows[i]={label=a,right=stationery(s,e.type)}
      end
      list(o,s,"_aioTop",rows,s.index or 1,x,o.top,w,o.bottom-lh-o.top-o.pad*.5,rowH,
        not busy and function(i) return function(st) st.index=i; st:clampIndex() end end or nil)
      letter(o,s,letters[s.index or 1],x,o.bottom-lh,w,lh,o.body)
    else
      o.S.text("No MAIL",o.body,x,o.top+o.pad,w,"center",o.c.muted)
    end
    o.bottom=o.y+o.h-o.fb-o.pad*.5
    local hints={{"A","CHOOSE"},{"B","BACK"}}
    if s.message then
      dialog(o,pageLines(s,s.message),s.message.page<#s.message.pages); hints={{"A","NEXT"}}
    elseif s.confirm then
      local cf=s.confirm
      local top=dialog(o,pageLines(s,cf),cf.page<#cf.pages)
      if cf.page>=#cf.pages then
        yesNo(o,cf.choice or 1,top,function(st,i) if st.confirm then st.confirm.choice=i end end)
      else o.taps.mode="list" end
    elseif s.submenu then
      local labels={}
      for i,e in ipairs(Class.SUB_ENTRIES or {}) do labels[i]=str(e.label) end
      local e=letters[s.index or 1]
      modal(o,e and norm(e.author or "") or "MAIL",labels,s.submenu.index or 1,
        function(st,i) if st.submenu then st.submenu.index=i end end)
    end
    footer(o,hints)
    mod._kimScreenTapTargets=o.taps
  end

  -- MailMenu (READ / TAKE / QUIT over the party) ----------------------------
  local function drawMailMenu(s)
    local Class=getmetatable(s)
    local Mail=lib("src.core.gen2.Mail") or {}
    local o=open(s,s.confirm and "sub" or "list")
    local rowH=math.max(44*o.k,o.body:getHeight()+o.pad)
    local lh=letterH(o,o.body)
    local entries=Class.ENTRIES or {}
    local sub=norm(s:monName())
    local h=headH(o,sub)+lh+o.pad+#entries*rowH+o.fb+o.pad*2.5
    if s.message or s.confirm then h=math.max(h,700*o.k) end
    window(o,h,"MAIL",sub,false)
    local x,w=o.x+o.pad,o.w-o.pad*2
    local entry=Mail.get and Mail.get(s.save,s.slot) or nil
    letter(o,s,entry,x,o.top,w,lh,o.body)
    local rows={}
    for i,e in ipairs(entries) do rows[i]={label=str(e.label)} end
    local busy=s.message or s.confirm
    list(o,s,"_aioTop",rows,s.index or 1,x,o.top+lh+o.pad,w,o.bottom-o.top-lh-o.pad,rowH,
      not busy and function(i) return function(st) st.index=i end end or nil)
    local hints={{"A","CHOOSE"},{"B","BACK"}}
    if s.message then
      dialog(o,pageLines(s,s.message),s.message.page<#s.message.pages); hints={{"A","NEXT"}}
    elseif s.confirm then
      local cf=s.confirm
      local top=dialog(o,pageLines(s,cf),cf.page<#cf.pages)
      if cf.page>=#cf.pages then
        yesNo(o,cf.choice or 1,top,function(st,i) if st.confirm then st.confirm.choice=i end end)
      else o.taps.mode="list" end
    end
    footer(o,hints)
    mod._kimScreenTapTargets=o.taps
  end

  -- MailRead: any button closes it, so a tap anywhere (A) does too ---------
  local function drawMailRead(s)
    local o=open(s,"list")
    local f=o.big
    local lh=letterH(o,f)+o.pad*2
    local e=s.entry
    window(o,headH(o)+lh+o.fb+o.pad*2.5,"MAIL",nil,false)
    letter(o,s,e,o.x+o.pad,o.top,o.w-o.pad*2,o.bottom-o.top,f)
    footer(o,{{"A","CLOSE"}})
    mod._kimScreenTapTargets=o.taps
  end

  -- MailCompose: the naming keyboard's cousin. Like the Modern naming screen
  -- it has no close button: B deletes a letter and only END leaves. ---------
  local BOTTOM_ROW=5 -- MailCompose's case / DEL / END strip
  local function drawCompose(s)
    local Mail=lib("src.core.gen2.Mail") or {}
    local o=open(s,"sub")
    local S,c,pad=o.S,o.c,o.pad
    local chars=type(Mail.characters)=="function" and Mail.characters(s.text or "") or {}
    local maxLen=Mail.MAIL_MSG_LENGTH or 32
    local lineLen=Mail.MAIL_LINE_LENGTH or 16
    local grid=type(s.rows)=="function" and s:rows() or {}
    local w0=math.min(o.W-pad*2,1100*o.k)
    local gap=math.max(4,6*o.k)
    local keyW=(w0-pad*2-gap*9)/10
    local keyH=math.min(keyW*.95,(o.H*.6)/7)
    local keyF=S.font(math.max(16,keyH*.42))
    local slotW=(w0-pad*2)/lineLen
    local entryH=keyF:getHeight()*2.6+pad
    local sub=("%d / %d"):format(#chars,maxLen)
    local h=headH(o,sub)+entryH+pad*.8+(#grid+1)*(keyH+gap)+o.fb+pad*2
    window(o,h,"WRITE MAIL",sub,true)
    local x,w=o.x+pad,o.w-pad*2
    -- the letter: two lines of MAIL_LINE_LENGTH slots
    box(o,x,o.top,w,entryH,c.raised,.55)
    local blink=math.floor(love.timer.getTime()*2)%2==0
    for i=1,maxLen do
      local row=i<=lineLen and 0 or 1
      local cx=x+((i-1)%lineLen)*slotW
      local cy=o.top+pad*.5+row*keyF:getHeight()*1.3
      local active=i==#chars+1
      S.color(active and c.accent or c.muted,active and 1 or .45)
      G.rectangle("fill",cx+slotW*.15,cy+keyF:getHeight()*1.05,slotW*.7,math.max(2,2*o.k))
      if chars[i] then
        S.text(norm(chars[i]),S.font(math.max(12,math.min(keyF:getHeight()*.75,slotW*.9))),cx,cy+keyF:getHeight()*.15,slotW,"center",c.text)
      elseif active and blink then
        S.color(c.accent,.8); G.rectangle("fill",cx+slotW*.45,cy,math.max(2,2*o.k),keyF:getHeight())
      end
    end
    local ky0=o.top+entryH+pad*.8
    local onBottom=type(s.onBottomRow)=="function" and s:onBottomRow()
    for r=1,#grid do
      for col=1,10 do
        local ch=grid[r][col]
        if ch and ch~="" and ch~=" " then
          local kx=x+(col-1)*(keyW+gap); local ky=ky0+(r-1)*(keyH+gap)
          local on=not onBottom and s.row==r-1 and s.col==col-1
          box(o,kx,ky,keyW,keyH,on and c.selected or nil,on and 1 or .7,on and c.accent or nil)
          local label=norm(ch)
          local lf=keyF:getWidth(label)>keyW*.9 and S.font(math.max(12,keyH*.3)) or keyF
          S.text(label,lf,kx,ky+(keyH-lf:getHeight())/2,keyW,"center",c.text)
          cell(o,kx,ky,keyW,keyH,function(st) st.row=r-1; st.col=col-1 end)
        end
      end
    end
    local by=ky0+#grid*(keyH+gap)
    local target=type(s.bottomTarget)=="function" and s:bottomTarget() or 1
    local labels={s.lower and "UPPER" or "lower","DEL","END"}
    local bw=(w-gap*2)/3
    for i,label in ipairs(labels) do
      local bx=x+(i-1)*(bw+gap)
      local on=onBottom and i==target
      box(o,bx,by,bw,keyH,on and c.selected or (i==3 and c.accent or nil),on and 1 or (i==3 and .35 or .7),on and c.accent or nil)
      S.text(str(label),keyF,bx,by+(keyH-keyF:getHeight())/2,bw,"center",c.text)
      cell(o,bx,by,bw,keyH,function(st) st.row=BOTTOM_ROW; st.col=(i-1)*3 end)
    end
    footer(o,{{"A","TYPE"},{"SELECT","CASE"},{"START","END"}})
    mod._kimScreenTapTargets=o.taps
  end

  -- BankOfMom: the six-digit keypad ----------------------------------------
  -- Mom's question stays in the TextBox under the keypad (hidden by the
  -- Modern dialogue UI while it is not on top), so it is shown here.
  local function promptBelow(s)
    local states=s.game and s.game.stack and s.game.stack.states
    if type(states)~="table" then return nil end
    for i=#states-1,1,-1 do
      local st=states[i]
      if type(st)=="table" and type(st.pages)=="table" and st.pageIndex then
        local page=st.pages[st.pageIndex]
        if type(page)=="table" then
          local out={}; for j,l in ipairs(page) do out[j]=norm(l) end
          return table.concat(out," ")
        end
        return nil
      end
    end
  end
  local function drawBank(s)
    local o=open(s,"sub")
    local S,c,pad=o.S,o.c,o.pad
    local prompt=promptBelow(s)
    local rowH=o.body:getHeight()+pad*.6
    local dw=math.min((math.min(o.W-pad*2,1100*o.k)-pad*4)/7.5,120*o.k)
    local dh=dw*1.2
    local arrowH=dw*.75
    local bh=btnH(o)
    local h=headH(o,prompt)+rowH*2+pad+o.small:getHeight()+arrowH*2+dh+pad*2+bh+o.fb+pad*2
    window(o,h,"MOM'S SAVINGS",prompt,false)
    local x,w=o.x+pad,o.w-pad*2
    local y=o.top
    for _,r in ipairs({{"SAVED",s.saved},{"HELD",s.held}}) do
      S.text(str(r[1]),o.body,x,y,w*.5,"left",c.muted)
      S.text(("¥%d"):format(r[2] or 0),o.body,x+w*.5,y,w*.5,"right",c.text)
      y=y+rowH
    end
    y=y+pad*.5
    S.color(c.divider or c.muted,.6); G.rectangle("fill",x,y-pad*.3,w,1)
    S.text(str(s.kind=="withdraw" and "WITHDRAW" or "DEPOSIT"),o.small,x,y,w,"center",c.accent)
    y=y+o.small:getHeight()+pad*.4
    local yen=o.big:getWidth("¥")+pad*.4
    local gap=pad*.35
    local rowW=yen+6*dw+5*gap
    local x0=x+(w-rowW)/2
    S.text("¥",o.big,x0,y+arrowH+(dh-o.big:getHeight())/2,yen,"left",c.text)
    local digits=("%06d"):format(math.max(0,math.floor(s.amount or 0)))
    for i=1,6 do
      local dx=x0+yen+(i-1)*(dw+gap)
      local on=(s.position or 5)==i-1
      local function at(st) st.position=i-1 end
      -- ▲ / ▼ add or take that place value through BankOfMom's own UP / DOWN
      box(o,dx,y,dw,arrowH-gap,nil,.7)
      S.color(c.accent); tri(dx+dw/2,y+(arrowH-gap)/2,arrowH*.45,"up")
      cell(o,dx,y,dw,arrowH-gap,at,"up")
      box(o,dx,y+arrowH,dw,dh,on and c.selected or nil,on and 1 or .8,on and c.accent or nil)
      S.text(digits:sub(i,i),o.big,dx,y+arrowH+(dh-o.big:getHeight())/2,dw,"center",c.text)
      cell(o,dx,y+arrowH,dw,dh,at,false)
      box(o,dx,y+arrowH+dh+gap,dw,arrowH-gap,nil,.7)
      S.color(c.accent); tri(dx+dw/2,y+arrowH+dh+gap+(arrowH-gap)/2,arrowH*.45,"down")
      cell(o,dx,y+arrowH+dh+gap,dw,arrowH-gap,at,"down")
    end
    bottomButtons(o,{{label="OK",button="a",hot=true}},true)
    footer(o,{{"UD","AMOUNT"},{"LR","DIGIT"},{"A","OK"},{"B","BACK"}})
    mod._kimScreenTapTargets=o.taps
  end

  -- DayCareMenu: a conversation, so a speech box and a YES/NO the way the
  -- Modern dialogue UI draws a TextBox + ChoiceBox (no window, no close
  -- button: B answers NO / turns the page, as on the cart) -----------------
  local function drawDayCare(s)
    local rec=s.message or s.confirm
    if not rec then return end
    local o=open(s,"list")
    local S,f,pad=o.S,o.body,o.pad
    local lines=pageLines(s,rec)
    local w=math.min(o.W*.92,math.max(f:getWidth(("0"):rep(18))+pad*2,900*o.k))
    local tw=w-pad*2
    local th=0
    for _,l in ipairs(lines) do local _,wr=f:getWrap(l,tw); th=th+math.max(1,#wr)*f:getHeight() end
    local dh=math.max(f:getHeight()*2,th)+pad*2
    local dx,dy=(o.W-w)/2,o.H-dh-math.max(18*o.k,o.H*.025)
    S.panel(dx,dy,w,dh,o.c,.97)
    local yy=dy+pad
    for _,l in ipairs(lines) do
      S.text(l,f,dx+pad,yy,tw,"left",o.c.text)
      local _,wr=f:getWrap(l,tw); yy=yy+math.max(1,#wr)*f:getHeight()
    end
    local yes=s.confirm and type(s.yesNoVisible)=="function" and s:yesNoVisible()
    if not yes and not typing(s) and rec.page<#rec.pages and math.floor(love.timer.getTime()*2)%2==0 then
      S.color(o.c.accent); tri(dx+w-pad,dy+dh-pad*.8,f:getHeight()*.5,"down")
    end
    if yes then
      o.x,o.w=dx,w
      yesNo(o,s.confirm.choice or 1,dy,function(st,i) if st.confirm then st.confirm.choice=i end end,dx+w)
    end
    mod._kimScreenTapTargets=o.taps
  end

  local DRAW={itempc=drawItemPc,mailbox=drawMailbox,mailmenu=drawMailMenu,mailread=drawMailRead,
    compose=drawCompose,bank=drawBank,daycare=drawDayCare}
  mod.hooks:wrap("screen.render_visible",function(nextFn,state)
    local k=kindOf(state)
    if k and enabled(k) then return false end
    return nextFn(state)
  end,46100)
  mod.hooks:wrap("render.hud",function(nextFn,game,viewport)
    local result={nextFn(game,viewport)}
    local top=game and game.stack and type(game.stack.top)=="function" and game.stack:top() or nil
    local k=kindOf(top)
    if k and enabled(k) then
      G.push("all");G.origin()
      local ok,err=pcall(DRAW[k],top)
      G.pop()
      if not ok then error(err,0) end
    end
    return unpackF(result)
  end,46100)
end
