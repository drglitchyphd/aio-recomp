-- gen2-aio 0.9.92: the Modern PACK, redesigned.
--
--   * a denser list (about twice the rows), a scroll bar, the quantity as a
--     pill, pocket tabs with an icon and their item count, a SEL tag on the
--     item registered to SELECT, and SORT (A-Z / TYPE / COUNT)
--   * a detail panel: category tag, sell price, who is holding the item,
--     and USE / GIVE / TOSS / REGISTER buttons
--   * a party strip: for a TM/HM who can learn it (or already knows it), for
--     medicine who it would help, otherwise who is holding it
--
-- Presentation only, like every other Modern screen. The engine's PackMenu
-- keeps all input and item logic:
--
--   * the action buttons open the PACK's OWN item submenu
--     (PackMenu:openSubmenu, whose rows are PackMenu:submenuRows -- the
--     cart's permission bits, the TM/HM pair and the battle pack's USE/QUIT)
--     on the matching row and press A, so the engine's chooseSubmenu runs the
--     action with every rule it has (OAK's "not the time", eggs, mail, the
--     toss quantity and YES/NO, the battle's own item flow). Only rows the
--     submenu itself offers are drawn as buttons.
--   * SORT reorders the pocket in the save's own bag order (save.bagOrder)
--     one Bag.move at a time -- the same rotate the PACK's SELECT "move item"
--     performs -- then lets PackMenu:rebuild() lay the rows out again, so the
--     order persists in the save and the engine's cursor/scroll stay its own.
--     The TM/HM pocket is always in TM number order on the cart (rebuild
--     sorts it), so it has no SORT.
--
-- lib/gen2_modern_core_menus.lua's drawPack hands this module its helpers
-- (window sizing, fonts, footer, modal) and returns when it has drawn; with
-- MODERN UI / MENU UI off nothing here runs and the native PACK draws.
return function(host)
  local mod=host.mod
  local G=love.graphics
  local function lib(n) local ok,m=pcall(require,n); return ok and type(m)=="table" and m or nil end

  local MP={}
  rawset(mod,"_aioModernPack",MP)

  local POCKETS={
    {id="ITEM",label="ITEMS",icon="bag"},
    {id="BALL",label="POKé BALLS",icon="ball"},
    {id="KEY_ITEM",label="KEY ITEMS",icon="key"},
    {id="TM_HM",label="TM/HM",icon="disc"},
  }
  MP.POCKETS=POCKETS

  -- ------------------------------------------------------------ categories
  -- Fixed hues: the tag is a coloured pill with white text, which reads on
  -- dark and light themes alike.
  local CAT_COLOR={
    MEDICINE={.24,.62,.36},BERRY={.78,.30,.50},BATTLE={.84,.42,.16},HOLD={.48,.38,.78},
    BALL={.80,.22,.22},KEY={.70,.54,.08},TM={.20,.46,.82},HM={.12,.56,.60},
    MAIL={.40,.52,.70},OTHER={.42,.46,.52},
  }
  local CAT_RANK={MEDICINE=1,BERRY=2,BATTLE=3,HOLD=4,BALL=5,MAIL=6,OTHER=7,KEY=8,TM=9,HM=10}
  MP.CAT_RANK=CAT_RANK

  local function isMail(id)
    local Mail=lib("src.core.gen2.Mail")
    if Mail and type(Mail.isMail)=="function" then
      local ok,v=pcall(Mail.isMail,id)
      if ok and v then return true end
    end
    return tostring(id):find("MAIL",1,true)~=nil
  end
  local function partyAction(id,data,inBattle)
    local IE=lib("src.core.gen2.ItemEffects")
    if not (IE and type(IE.partyAction)=="function") then return nil end
    local ok,a=pcall(IE.partyAction,id,data,inBattle)
    return ok and a or nil
  end

  -- The tag, from the engine's own item record: its pocket, its field /
  -- battle menu nibbles (ItemAttributes), its hold effect, and whether
  -- ItemEffects has a party-use family for it.
  function MP.category(id,def,data)
    def=type(def)=="table" and def or {}
    local sid=tostring(id or "")
    local pocket=def.pocket or "ITEM"
    if pocket=="TM_HM" or def.teaches then return sid:sub(1,3)=="HM_" and "HM" or "TM" end
    if pocket=="BALL" then return "BALL" end
    if pocket=="KEY_ITEM" then return "KEY" end
    if isMail(id) then return "MAIL" end
    if sid:find("BERRY",1,true) and sid~="BERRY_JUICE" then return "BERRY" end
    local action=partyAction(id,data,false)
    if action and action~="stone" then return "MEDICINE" end
    if not action and def.fieldMenu=="ITEMMENU_PARTY" and def.battleMenu=="ITEMMENU_PARTY" then
      return "MEDICINE"
    end
    if def.fieldMenu=="ITEMMENU_NOUSE" and def.battleMenu and def.battleMenu~="ITEMMENU_NOUSE" then
      return "BATTLE"
    end
    if def.heldEffect and def.heldEffect~="HELD_NONE" then return "HOLD" end
    return "OTHER"
  end

  -- MartMenu.sellPrice: half the ItemAttributes price, halved after the
  -- multiply; nil = the mart will not buy it (CANT_TOSS, or no price).
  function MP.sellPrice(def)
    if type(def)~="table" or def.canToss==false then return nil end
    local price=tonumber(def.price) or 0
    if price<=0 then return nil end
    local Mart=lib("src.ui.gen2.MartMenu")
    if Mart and type(Mart.sellPrice)=="function" then
      local ok,v=pcall(Mart.sellPrice,price,1)
      if ok and tonumber(v) then return tonumber(v) end
    end
    return math.floor(price/2)
  end

  local function dataOf(s) return (s and s.game and s.game.data) or {} end
  local function partyOf(s) return (s and s.save and s.save.party) or {} end
  local function defOf(s,id) return s and s.items and s.items[id] or nil end
  local function maxHpOf(mon) return tonumber(mon.maxHp) or tonumber(mon.stats and mon.stats.hp) or 0 end
  local function isEgg(mon) return mon.isEgg or mon.egg end

  function MP.holders(s,id)
    local out={}
    for i,mon in ipairs(partyOf(s)) do
      if type(mon)=="table" and id~=nil and mon.item==id then out[#out+1]=i end
    end
    return out
  end

  -- Who in the party the item is for. mode: "learn" (TM/HM: yes / no /
  -- knows), "help" (medicine: help / none), "hold" (held / none).
  local function movesOf(mon)
    local Mon=lib("src.battle.gen2.Mon")
    if Mon and type(Mon.partyMoves)=="function" then
      local ok,m=pcall(Mon.partyMoves,mon)
      if ok and type(m)=="table" then return m end
    end
    return mon.moves or {}
  end
  local function maxPp(move,data)
    local Mon=lib("src.battle.gen2.Mon")
    if Mon and type(Mon.maxPpOf)=="function" then
      local ok,v=pcall(Mon.maxPpOf,move,data)
      if ok and tonumber(v) then return tonumber(v) end
    end
    return tonumber(move.maxPp) or tonumber(move.pp) or 0
  end
  local function helps(action,id,mon,data)
    local IE=lib("src.core.gen2.ItemEffects") or {}
    local hp,maxHp=tonumber(mon.hp) or 0,maxHpOf(mon)
    local fainted=hp<=0
    local function statusClass()
      if mon.status==nil or mon.status=="" then return nil end
      if type(IE.healClassOf)=="function" then
        local ok,v=pcall(IE.healClassOf,mon.status,data)
        if ok then return v end
      end
      return nil
    end
    if action=="heal" then
      if fainted then return false end
      if hp<maxHp then return true end
      return id=="FULL_RESTORE" and statusClass()~=nil
    elseif action=="status" then
      if fainted then return false end
      local want=IE.HEAL_STATUS and IE.HEAL_STATUS[id]
      local have=statusClass()
      return have~=nil and (want=="all" or want==have)
    elseif action=="revive" then
      return fainted
    elseif action=="pp" then
      if id=="PP_UP" then
        for _,mv in ipairs(movesOf(mon)) do
          if type(mv)=="table" and mv.id and mv.id~="SKETCH" and (tonumber(mv.ppUps) or 0)<3 then return true end
        end
        return false
      end
      for _,mv in ipairs(movesOf(mon)) do
        if type(mv)=="table" and mv.id and (tonumber(mv.pp) or 0)<maxPp(mv,data) then return true end
      end
      return false
    elseif action=="candy" then
      return (tonumber(mon.level) or 100)<100
    elseif action=="stone" then
      local Evo=lib("src.core.gen2.Evolution")
      if not (Evo and type(Evo.checkMon)=="function") or mon.item=="EVERSTONE" then return false end
      local ok,entry=pcall(Evo.checkMon,data,mon,{force=true,item=id})
      return ok and entry~=nil
    end
    return nil
  end
  MP.helps=helps

  function MP.compat(s,row)
    local out={marks={}}
    if not (row and row.id) then out.mode="none"; return out end
    local data=dataOf(s)
    local def=defOf(s,row.id)
    local moveId=def and def.teaches
    local party=partyOf(s)
    if moveId then
      out.mode="learn"
      for i,mon in ipairs(party) do
        local m="no"
        if type(mon)~="table" then m="none"
        elseif isEgg(mon) then m="egg"
        else
          local knows=false
          for _,mv in ipairs(movesOf(mon)) do
            if type(mv)=="table" and mv.id==moveId then knows=true end
          end
          local species=data.pokemon and data.pokemon[mon.species]
          if knows then m="knows"
          elseif not species then m="unknown"
          else
            m="no"
            for _,mid in ipairs(species.tmhm or {}) do if mid==moveId then m="yes" end end
          end
        end
        out.marks[i]=m
      end
      return out
    end
    local inBattle=false
    if type(s.inBattle)=="function" then local ok,v=pcall(s.inBattle,s); inBattle=ok and v==true end
    local action=partyAction(row.id,data,inBattle)
    local any=false
    if action and action~="vitamin" then
      for i,mon in ipairs(party) do
        local m="none"
        if type(mon)=="table" and not isEgg(mon) then
          local h=helps(action,row.id,mon,data)
          if h==nil then action=nil; break end
          if h then m="help"; any=true end
        elseif type(mon)=="table" then m="egg" end
        out.marks[i]=m
      end
      if action then out.mode="help"; out.action=action; out.any=any; return out end
    end
    out.mode="hold"; out.marks={}
    for i,mon in ipairs(party) do
      out.marks[i]=(type(mon)=="table" and mon.item==row.id) and "held" or "none"
    end
    return out
  end

  -- ------------------------------------------------------------------ sort
  local SORTS={"az","type","count"}
  local SORT_LABEL={az="A-Z",type="TYPE",count="COUNT"}
  MP.SORTS=SORTS
  MP.SORT_LABEL=SORT_LABEL
  -- the mode each pocket was last sorted by (this session), for the label
  MP.lastSort={}
  local function pocketId(s)
    local p=type(s.pocket)=="function" and s:pocket() or POCKETS[tonumber(s.pocketIndex) or 1]
    return p and p.id or "ITEM"
  end
  function MP.canSort(s)
    return type(s)=="table" and s.save~=nil and type(s.rebuild)=="function"
      and pocketId(s)~="TM_HM"
  end
  local function sortKey(s,mode)
    local data=dataOf(s)
    local function name(r) return tostring(r.name or r.id):upper() end
    if mode=="count" then
      return function(a,b)
        local ca,cb=tonumber(a.count) or 0,tonumber(b.count) or 0
        if ca~=cb then return ca>cb end
        return name(a)<name(b)
      end
    elseif mode=="type" then
      local rank={}
      return function(a,b)
        rank[a.id]=rank[a.id] or CAT_RANK[MP.category(a.id,defOf(s,a.id),data)] or 99
        rank[b.id]=rank[b.id] or CAT_RANK[MP.category(b.id,defOf(s,b.id),data)] or 99
        if rank[a.id]~=rank[b.id] then return rank[a.id]<rank[b.id] end
        return name(a)<name(b)
      end
    end
    return function(a,b)
      local na,nb=name(a),name(b)
      if na~=nb then return na<nb end
      return tostring(a.id)<tostring(b.id)
    end
  end
  -- Reorders the live pocket through the engine's Bag.move (the PACK's own
  -- SELECT rotate over save.bagOrder), then the PACK's rebuild. The cursor
  -- stays on the item it was on.
  function MP.sort(s,mode)
    if not MP.canSort(s) then return false end
    mode=SORT_LABEL[mode] and mode or "az"
    local Bag=lib("src.inventory.Bag")
    if not (Bag and type(Bag.move)=="function") then return false end
    local rows={}
    for i,r in ipairs(s.rows or {}) do rows[i]=r end
    local current=s.rows and s.rows[tonumber(s.index) or 1]
    table.sort(rows,sortKey(s,mode))
    local pid=pocketId(s)
    local data=s.bagData or {items=s.items}
    for i,r in ipairs(rows) do pcall(Bag.move,s.save,r.id,pid,i,data) end
    s:rebuild()
    if current then
      for i,r in ipairs(s.rows or {}) do if r.id==current.id then s.index=i end end
    end
    if type(s.ensureVisible)=="function" then pcall(s.ensureVisible,s) end
    if type(s.storeCursor)=="function" then pcall(s.storeCursor,s) end
    MP.lastSort[pid]=mode
    local FS=rawget(mod,"_kimFreeScroll")
    if type(FS)=="table" then FS[s]=nil end
    if type(s.playSfx)=="function" then pcall(s.playSfx,s,"Sfx_SwitchPokemon") end
    return true
  end
  function MP.nextSort(s)
    local last=MP.lastSort[pocketId(s)]
    for i,m in ipairs(SORTS) do if m==last then return SORTS[i%#SORTS+1] end end
    return SORTS[1]
  end
  function MP.cycleSort(s) return MP.sort(s,MP.nextSort(s)) end

  local function busy(s)
    return s.submenu or s.message or s.confirm or s.qtyState or s.switching or s.staleRows
  end
  MP.busy=busy

  -- --------------------------------------------------------------- actions
  local ACTION_LABEL={use="USE",give="GIVE",toss="TOSS",sel="REGISTER"}
  -- The buttons the PACK's own submenu would offer for the highlighted row
  -- (QUIT left out); a chooser pack (SELL / DEPOSIT / GIVE) has no submenu
  -- and gets one CHOOSE, which is its A.
  function MP.actions(s)
    local row=s.rows and s.rows[tonumber(s.index) or 1]
    if not row then return {} end
    local has=false
    if type(s.hasSubmenu)=="function" then local ok,v=pcall(s.hasSubmenu,s); has=ok and v==true end
    if not has then
      if s.tutorial then return {} end
      return {{id="choose",label="CHOOSE"}}
    end
    local ids={}
    if type(s.submenuRows)=="function" then
      local ok,v=pcall(s.submenuRows,s,row.id); if ok and type(v)=="table" then ids=v end
    end
    local out={}
    for _,id in ipairs(ids) do
      if id~="quit" then out[#out+1]={id=id,label=ACTION_LABEL[id] or tostring(id):upper()} end
    end
    return out
  end
  -- A tap on a button: open the PACK's own submenu on that row; the touch
  -- layer then presses A, which the engine's updateSubmenu answers with
  -- chooseSubmenu. Returns false (and opens nothing) when the submenu does
  -- not offer it.
  function MP.prepareAction(s,id)
    if busy(s) then return false end
    if id=="choose" then return true end
    if type(s.openSubmenu)~="function" then return false end
    s:openSubmenu()
    local menu=s.submenu
    if not menu then return false end
    for i,r in ipairs(menu.rows or {}) do
      if r==id then menu.index=i; return true end
    end
    s.submenu=nil
    return false
  end

  local function registeredId(s)
    local save=s.save
    local reg=save and save.registeredItem
    local id=type(reg)=="table" and reg.id or nil
    if id and save.inventory and (tonumber(save.inventory[id]) or 0)>0 then return id end
    return nil
  end
  MP.registeredId=registeredId

  function MP.pocketCounts(s)
    local counts={0,0,0,0}
    local inv=s.save and s.save.inventory or {}
    local Bag=lib("src.inventory.Bag")
    local idx={}
    for i,p in ipairs(POCKETS) do idx[p.id]=i end
    for id,n in pairs(inv) do
      local count=tonumber(n) or (n and 1) or 0
      local badge=Bag and type(Bag.isBadge)=="function" and Bag.isBadge(id)
      if count>0 and not badge then
        local pid="ITEM"
        if type(s.pocketOf)=="function" then
          local ok,v=pcall(s.pocketOf,s,id); if ok and v then pid=v end
        else
          local def=defOf(s,id); pid=def and def.pocket or "ITEM"
        end
        local i=idx[pid]
        if i then counts[i]=counts[i]+1 end
      end
    end
    return counts
  end

  -- ------------------------------------------------------------------ icons
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

  -- -------------------------------------------------------------- drawing
  local function rgba(c,a) G.setColor(c[1],c[2],c[3],a or c[4] or 1) end
  local function lum(c) return .3*c[1]+.59*c[2]+.11*c[3] end

  local function pocketIcon(kind,x,y,s,col)
    rgba(col)
    local lw=math.max(1.5,s*.1)
    G.setLineWidth(lw)
    local cx,cy=x+s/2,y+s/2
    if kind=="bag" then
      G.rectangle("fill",x+s*.12,y+s*.34,s*.76,s*.58,s*.12,s*.12)
      G.arc("line","open",cx,y+s*.36,s*.22,math.pi,2*math.pi)
    elseif kind=="ball" then
      local r=s*.42
      G.arc("fill",cx,cy,r,math.pi,2*math.pi)
      G.circle("line",cx,cy,r)
      G.line(cx-r,cy,cx+r,cy)
      G.circle("fill",cx,cy,r*.28)
    elseif kind=="key" then
      G.circle("line",x+s*.3,cy,s*.2)
      G.line(x+s*.5,cy,x+s*.92,cy)
      G.line(x+s*.78,cy,x+s*.78,cy+s*.2)
      G.line(x+s*.9,cy,x+s*.9,cy+s*.16)
    else
      G.circle("line",cx,cy,s*.42)
      G.circle("fill",cx,cy,s*.12)
      G.arc("line","open",cx,cy,s*.27,-.6,.6)
    end
  end

  local function pill(x,y,w,h,fill,alpha)
    rgba(fill,alpha)
    G.rectangle("fill",x,y,w,h,h/2,h/2)
  end

  local function check(cx,cy,r,col)
    rgba(col); G.setLineWidth(math.max(2,r*.32))
    G.line(cx-r*.55,cy,cx-r*.12,cy+r*.45,cx+r*.6,cy-r*.45)
  end
  local function cross(cx,cy,r,col)
    rgba(col); G.setLineWidth(math.max(2,r*.32))
    G.line(cx-r*.45,cy-r*.45,cx+r*.45,cy+r*.45)
    G.line(cx-r*.45,cy+r*.45,cx+r*.45,cy-r*.45)
  end

  local GOOD,BAD={.22,.68,.36,1},{.82,.24,.24,1}

  local function addCell(cell)
    local t=rawget(mod,"_kimScreenTapTargets")
    if t and t.cells then t.cells[#t.cells+1]=cell end
  end

  local function clipText(f,str,w)
    str=tostring(str or "")
    if f:getWidth(str)<=w then return str end
    while #str>0 and f:getWidth(str.."...")>w do str=str:gsub("[%z\1-\127\194-\244][\128-\191]*$","") end
    return str.."..."
  end

  -- label / value pairs under the description
  local function title(v) return (tostring(v or ""):gsub("_TYPE$",""):gsub("_"," "):upper()) end
  function MP.facts(s,row,def,reg)
    local out={}
    if not row then return out end
    def=type(def)=="table" and def or {}
    local data=dataOf(s)
    if row.showCount or (tonumber(row.count) or 0)>1 then out[#out+1]={"IN BAG","x"..tostring(row.count or 0)} end
    if def.teaches then
      local mv=data.moves and data.moves[def.teaches]
      if type(mv)=="table" then
        if mv.type then out[#out+1]={"TYPE",title(mv.type)} end
        if mv.power then out[#out+1]={"POWER",(tonumber(mv.power) or 0)>1 and tostring(mv.power) or "---"} end
        if mv.accuracy then out[#out+1]={"ACC",tostring(mv.accuracy).."%"} end
        if mv.pp then out[#out+1]={"PP",tostring(mv.pp)} end
      end
      out[#out+1]={"USE",tostring(row.id):sub(1,3)=="HM_" and "TEACH (KEEPS)" or "TEACH (ONCE)"}
    else
      local field=def.fieldMenu and def.fieldMenu~="ITEMMENU_NOUSE"
      local battle=def.battleMenu and def.battleMenu~="ITEMMENU_NOUSE"
      local held=def.heldEffect and def.heldEffect~="HELD_NONE"
      local use=(field and battle and "FIELD & BATTLE") or (field and "FIELD") or (battle and "BATTLE")
        or (held and "HOLD ONLY") or "---"
      out[#out+1]={"USE",use}
      if held and def.heldEffect~="HELD_BERRY" then
        out[#out+1]={"HOLD",title((tostring(def.heldEffect):gsub("^HELD_","")))}
      end
    end
    if reg and reg==row.id then out[#out+1]={"SELECT","REGISTERED",{.22,.68,.36,1}} end
    return out
  end

  -- the cart's text tokens as the Modern font prints them, one paragraph
  function MP.norm(ctx,v)
    v=tostring(v or "")
    if ctx and type(ctx.normalize)=="function" then
      local ok,r=pcall(ctx.normalize,v); if ok and r then v=tostring(r) end
    end
    v=v:gsub("<PO><KE>","POKé"):gsub("<PK><MN>","POKéMON"):gsub("#MON","POKéMON")
    v=v:gsub("<NEXT>"," "):gsub("[\n\f\v]+"," "):gsub("%s%s+"," ")
    return v
  end

  -- The whole window. Returns true when drawn.
  function MP.draw(s,ctx)
    if type(s)~="table" or type(ctx)~="table" then return false end
    local c=ctx.theme()
    local sx,sy,sw,sh=ctx.playfield()
    local scale=ctx.uiScale(sw,sh)
    local portrait=ctx.mobilePortrait(sw,sh)
    local mobile=ctx.mobileHost()
    local w,h
    if portrait then
      w=sw*.92; h=sh*.74
      scale=math.min(scale,w/820,h/1060)
    elseif mobile then
      w=sw*.92; h=sh*.86
      scale=math.min(scale,w/1120,h/720)
    else
      w=math.min(1120*scale,sw*.80); h=math.min(720*scale,sh*.88)
    end
    if ctx.layoutStyle()=="full" then
      w=sw*.94; h=sh*.92; scale=math.min(w/1120,h/(portrait and 1060 or 720))
    end
    -- a roomy window (the Fold's inner screen) grows the type up to half
    -- again, rather than leaving a big panel mostly empty
    do
      local fit=portrait and math.min(w/820,h/1060) or math.min(w/1120,h/720)
      if fit>scale then scale=math.min(fit,scale*1.5) end
    end
    scale=math.max(.52,scale)
    local font,fitted,text=ctx.font,ctx.fittedFont,ctx.text
    local x=sx+(sw-w)/2; local y=sy+(sh-h)/2
    ctx.panel(x,y,w,h,c,.95)
    ctx.closeButton(x,y,w,h,c)
    local pad=math.max(12,22*scale)
    local rows=s.rows or {}
    local idx=tonumber(s.index) or 1
    local selected=idx<=#rows and rows[idx] or nil
    local data=dataOf(s)
    local isBusy=busy(s)
    local pIndex=tonumber(s.pocketIndex) or 1

    -- title row: PACK, then SORT left of the close button
    local titleF=fitted(34*scale,"PACK",w*.3)
    local titleY=y+math.max(8,14*scale)
    text("PACK",titleF,x+pad,titleY,w*.3,"left",c.text)
    local small=font(18*scale)
    local sortOk=MP.canSort(s)
    MP._sortRect=nil
    if sortOk then
      local last=MP.lastSort[pocketId(s)]
      local label=last and ("SORT: "..SORT_LABEL[last]) or "SORT"
      local bh=math.max(small:getHeight()+10*scale,titleF:getHeight()*.9)
      local bw=small:getWidth("SORT: COUNT")+28*scale
      local reserve=ctx.closeReserve()
      local bx=x+w-pad-reserve-bw-(reserve>0 and reserve*.6 or 0)
      local by=titleY+(titleF:getHeight()-bh)/2
      rgba(c.raised or c.surface)
      G.rectangle("fill",bx,by,bw,bh,bh*.3,bh*.3)
      rgba(c.frame or c.accent); G.setLineWidth(math.max(1,scale*1.5))
      G.rectangle("line",bx,by,bw,bh,bh*.3,bh*.3)
      -- three bars, shortest last: the sort glyph
      local gx,gy,gs=bx+8*scale,by+bh*.3,bh*.4
      rgba(c.accent or c.text)
      for k=0,2 do G.rectangle("fill",gx,gy+k*gs*.4,gs*(1-k*.25),math.max(1.5,gs*.16)) end
      text(label,small,bx+gs+12*scale,by+(bh-small:getHeight())/2,bw-gs-16*scale,"center",c.text)
      MP._sortRect={x=bx,y=by,w=bw,h=bh}
      if not isBusy then
        addCell({kind="packAction",action="sort",x=bx,y=by,w=bw,h=bh,
          select=function(st) MP.cycleSort(st) end,button=false})
      end
    end

    -- pocket tabs: icon, label, item count
    local counts=MP.pocketCounts(s)
    local tabTop=y+math.max(46*scale,titleF:getHeight()+20*scale)
    local tabF=font(21*scale)
    local tabH=math.max(40*scale,tabF:getHeight()+14*scale)
    local tabW=(w-pad*2)/4
    for i,p in ipairs(POCKETS) do
      local tx=x+pad+(i-1)*tabW; local sel=i==pIndex
      local tw=tabW-4*scale
      if sel then rgba(c.selected); G.rectangle("fill",tx,tabTop,tw,tabH,6*scale,6*scale)
      else rgba(c.raised or c.surface,.55); G.rectangle("fill",tx,tabTop,tw,tabH,6*scale,6*scale) end
      ctx.screenTap("pocket",i,tx,tabTop,tw,tabH)
      local isz=tabH*.48
      local col=sel and c.text or c.muted
      pocketIcon(p.icon,tx+8*scale,tabTop+(tabH-isz)/2,isz,col)
      local cnt=tostring(counts[i] or 0)
      local cf=font(16*scale)
      local cw=math.max(cf:getWidth(cnt)+12*scale,cf:getHeight()+4*scale)
      local ch=cf:getHeight()+2*scale
      local cx=tx+tw-cw-6*scale
      pill(cx,tabTop+(tabH-ch)/2,cw,ch,sel and (c.accent or c.frame) or (c.divider or c.muted),sel and 1 or .8)
      local onPill=lum(sel and (c.accent or c.frame) or (c.divider or c.muted))>.55 and {.08,.08,.1,1} or {1,1,1,1}
      text(cnt,cf,cx,tabTop+(tabH-cf:getHeight())/2,cw,"center",onPill)
      local lx=tx+8*scale+isz+6*scale
      local lw=cx-lx-4*scale
      local lf=fitted(21*scale,p.label,lw)
      text(clipText(lf,p.label,lw),lf,lx,tabTop+(tabH-lf:getHeight())/2,lw,"left",col)
    end

    local footerH=ctx.chromeFooterH()
    local footerY=y+h-footerH
    local contentY=tabTop+tabH+math.max(8,12*scale)
    local contentB=footerY-math.max(6,8*scale)

    -- the list ------------------------------------------------------------
    local rowPx=22*scale
    local rowF=font(rowPx)
    local qtyF=font(17*scale)
    local reg=registeredId(s)
    local function drawList(lx,ly,lw,lh)
      -- about twice the old eight rows: the font sets the minimum, and a tall
      -- list spreads to ~16 (18 on a phone held upright) with the type
      -- growing into the room
      local target=portrait and 18 or 16
      local rh=math.floor(rowF:getHeight()+math.max(6,9*scale)+.5)
      if lh/target>rh then
        rh=math.floor(lh/target)
        rowPx=math.min(math.max(22*scale,rh*.42),30*scale)
        rowF=font(rowPx)
        qtyF=font(math.min(math.max(17*scale,rh*.32),24*scale))
      end
      local total=#rows+1
      local visible=math.max(1,math.floor(lh/rh))
      local maxScroll=math.max(0,total-visible)
      local scroll=tonumber(s.scroll) or 0
      scroll=ctx.freeScroll(s,idx,scroll,maxScroll,visible,rh,function(v) s.scroll=v end)
      MP._visible=visible
      local barW=math.max(4,6*scale)
      local rowW=lw-(maxScroll>0 and barW+6*scale or 0)
      local tmCol=rowF:getWidth("TM00")+10*scale
      for slot=1,visible do
        local i=scroll+slot
        if i>total then break end
        local row=rows[i]
        local yy=ly+(slot-1)*rh
        local by,bh=yy+1,rh-2
        local sel=i==idx
        ctx.screenTap("pack",i,lx,by,rowW,bh)
        if sel then rgba(c.selected); G.rectangle("fill",lx,by,rowW,bh,5*scale,5*scale)
        elseif slot%2==0 then rgba(c.raised or c.surface,.35); G.rectangle("fill",lx,by,rowW,bh,5*scale,5*scale) end
        if s.switching==i then
          rgba(c.accent or c.frame); G.setLineWidth(math.max(1.5,2*scale))
          G.rectangle("line",lx+1,by+1,rowW-2,bh-2,5*scale,5*scale)
        end
        local col=sel and c.text or c.muted
        local tyy=yy+(rh-rowF:getHeight())/2
        if not row then
          text("CANCEL",rowF,lx+10*scale,tyy,rowW-20*scale,"left",col)
        else
          local right=lx+rowW-8*scale
          if row.showCount then
            local q="x"..tostring(row.count or 0)
            local qw=math.max(qtyF:getWidth(q)+14*scale,qtyF:getWidth("x99")+14*scale)
            local qh=qtyF:getHeight()+4*scale
            local fill=sel and (c.accent or c.frame) or (c.raised or c.divider or c.surface)
            pill(right-qw,yy+(rh-qh)/2,qw,qh,fill,sel and 1 or .95)
            local tc=lum(fill)>.55 and {.08,.08,.1,1} or {1,1,1,1}
            text(q,qtyF,right-qw,yy+(rh-qtyF:getHeight())/2,qw,"center",tc)
            right=right-qw-6*scale
          end
          if reg and row.id==reg then
            local t="SEL"
            local tw=qtyF:getWidth(t)+12*scale
            local th=qtyF:getHeight()+2*scale
            rgba(c.accent or c.frame); G.setLineWidth(math.max(1,1.5*scale))
            G.rectangle("line",right-tw,yy+(rh-th)/2,tw,th,th*.3,th*.3)
            text(t,qtyF,right-tw,yy+(rh-qtyF:getHeight())/2,tw,"center",c.accent or c.text)
            right=right-tw-6*scale
          end
          local nx=lx+10*scale
          if row.tmhmLabel then
            local d=defOf(s,row.id)
            local lab=(d and d.tmLabel) or (row.tmhmLabel:match("^H") and ("HM%02d"):format(tonumber(row.tmhmLabel:sub(2)) or 0)) or ("TM"..row.tmhmLabel)
            text(lab,qtyF,nx,yy+(rh-qtyF:getHeight())/2,tmCol,"left",sel and c.text or c.muted)
            nx=nx+tmCol
          end
          local name=(row.tmhmLabel and row.teaches) or row.name or tostring(row.id)
          local nw=right-nx-4*scale
          local nf=fitted(rowPx,name,nw)
          text(clipText(nf,name,nw),nf,nx,yy+(rh-nf:getHeight())/2,nw,"left",col)
        end
      end
      if maxScroll>0 then
        local tx=lx+lw-barW
        rgba(c.divider or c.muted,.35); G.rectangle("fill",tx,ly,barW,visible*rh,barW/2,barW/2)
        local th=math.max(barW*3,visible*rh*visible/total)
        local tyy=ly+(visible*rh-th)*(scroll/maxScroll)
        rgba(c.accent or c.frame); G.rectangle("fill",tx,tyy,barW,th,barW/2,barW/2)
        MP._scrollBar={x=tx,y=tyy,w=barW,h=th,track=visible*rh}
      else
        MP._scrollBar=nil
      end
    end

    -- the detail panel ---------------------------------------------------------
    local function drawDetail(dx,dy,dw,dh)
      local nameF=font(30*scale)
      local bodyF=font(22*scale)
      local tagF=font(18*scale)
      local yy=dy
      if not selected then
        text("CANCEL",nameF,dx,yy,dw,"left",c.text)
        text("Close the PACK.",bodyF,dx,yy+nameF:getHeight()+8*scale,dw,"left",c.muted)
        return
      end
      local def=defOf(s,selected.id)
      local cat=MP.category(selected.id,def,data)
      local heading=(selected.tmhmLabel and selected.teaches) or selected.name or tostring(selected.id)
      local hf=fitted(30*scale,heading,dw)
      text(clipText(hf,heading,dw),hf,dx,yy,dw,"left",c.text)
      yy=yy+hf:getHeight()+6*scale
      -- tag + number + sell price
      local th=tagF:getHeight()+6*scale
      local tw=tagF:getWidth(cat)+16*scale
      pill(dx,yy,tw,th,CAT_COLOR[cat] or CAT_COLOR.OTHER,1)
      text(cat,tagF,dx,yy+3*scale,tw,"center",{1,1,1,1})
      local ix=dx+tw+10*scale
      if selected.tmhmLabel or (def and def.tmLabel) then
        local lab=(def and def.tmLabel) or selected.name
        text(lab,tagF,ix,yy+3*scale,dw,"left",c.muted)
        ix=ix+tagF:getWidth(lab)+12*scale
      end
      local price=MP.sellPrice(def)
      local ptxt=price and ("SELLS FOR ¥"..price) or "CAN'T SELL"
      if ix+tagF:getWidth(ptxt)<=dx+dw then
        text(ptxt,tagF,dx+dw-tagF:getWidth(ptxt),yy+3*scale,tagF:getWidth(ptxt)+2,"right",price and c.text or c.muted)
      end
      yy=yy+th+10*scale

      -- bottom-up: party strip, then the buttons
      local party=partyOf(s)
      local comp=MP.compat(s,selected)
      MP._compat=comp
      local capF=font(15*scale)
      local gapS=6*scale
      local slotW=(dw-gapS*5)/6
      local stripIcon=math.max(28,math.min(72*scale,slotW*.62))
      local barH=math.max(3,5*scale)
      local cardH=6*scale+stripIcon+4*scale+capF:getHeight()+4*scale+barH+4*scale+capF:getHeight()+6*scale
      local stripH=capF:getHeight()+6*scale+cardH
      local bottom=dy+dh
      local stripY=bottom-stripH
      local acts=MP.actions(s)
      local btnF=font(20*scale)
      local btnH=math.max(38*scale,btnF:getHeight()+18*scale)
      local btnY=stripY-btnH-14*scale
      MP._buttons={}
      if #party>0 then
        local caption=comp.mode=="learn" and "CAN LEARN" or comp.mode=="help"
          and (comp.any and "WOULD HELP" or "WOULD HELP: NO ONE") or "HOLDING"
        text(caption,capF,dx,stripY,dw,"left",c.muted)
        local cy0=stripY+capF:getHeight()+6*scale
        for i=1,math.min(6,#party) do
          local mon=party[i]
          local mark=comp.marks[i] or "none"
          local kx=dx+(i-1)*(slotW+gapS)
          local cx=kx+slotW/2
          local hot=mark=="yes" or mark=="help" or mark=="held"
          local dim=mark=="no" or mark=="none" or mark=="egg" or mark=="unknown"
          local rr=math.min(12*scale,slotW*.12)
          rgba(c.raised or c.surface,hot and 1 or .55)
          G.rectangle("fill",kx,cy0,slotW,cardH,rr,rr)
          if hot then
            rgba(mark=="yes" and GOOD or (c.accent or c.frame)); G.setLineWidth(math.max(2,2.5*scale))
            G.rectangle("line",kx,cy0,slotW,cardH,rr,rr)
          end
          local iy=cy0+6*scale
          local img=type(mon)=="table" and iconFor(s.game,mon)
          local alpha=dim and .38 or 1
          if img then
            local iw,ih=img:getDimensions()
            local k=math.min(stripIcon/iw,stripIcon/ih)
            G.setColor(1,1,1,alpha)
            G.draw(img,cx-iw*k/2,iy+(stripIcon-ih*k)/2,0,k,k)
          elseif type(mon)=="table" then
            local ab=tostring(mon.nickname or mon.species or "?"):sub(1,2)
            local f=font(stripIcon*.36)
            local tc=c.text; text(ab,f,cx-stripIcon/2,iy+(stripIcon-f:getHeight())/2,stripIcon,"center",{tc[1],tc[2],tc[3],alpha})
          end
          local r=math.max(7,stripIcon*.17)
          local bx,by=kx+slotW-r-4*scale,cy0+r+4*scale
          if mark=="yes" then
            rgba(GOOD); G.circle("fill",bx,by,r); check(bx,by,r*.8,{1,1,1,1})
          elseif mark=="no" then
            rgba(BAD); G.circle("fill",bx,by,r); cross(bx,by,r*.8,{1,1,1,1})
          end
          local ny=iy+stripIcon+4*scale
          if type(mon)=="table" then
            local nm=tostring(mon.nickname or mon.species or "?")
            local nf=fitted(15*scale,nm,slotW-8*scale)
            local tc=c.text
            text(clipText(nf,nm,slotW-8*scale),nf,kx+4*scale,ny,slotW-8*scale,"center",{tc[1],tc[2],tc[3],dim and .6 or 1})
            -- HP bar: green / yellow / red as on the party screen
            local maxHp=maxHpOf(mon)
            local by2=ny+capF:getHeight()+4*scale
            local bw=slotW-16*scale
            rgba(c.divider or c.muted,.35); G.rectangle("fill",kx+8*scale,by2,bw,barH,barH/2,barH/2)
            if not isEgg(mon) and maxHp>0 then
              local ratio=math.max(0,math.min(1,(tonumber(mon.hp) or 0)/maxHp))
              local col=ratio>.5 and {.30,.78,.40,1} or ratio>.2 and {.92,.76,.20,1} or {.88,.28,.24,1}
              if ratio>0 then rgba(col,alpha); G.rectangle("fill",kx+8*scale,by2,bw*ratio,barH,barH/2,barH/2) end
            end
          end
          local lab=({yes="CAN LEARN",no="CAN'T",knows="KNOWS",egg="EGG",help="HELPS",held="HELD",unknown="?"})[mark] or ""
          if lab~="" then
            local lc=(mark=="yes" and GOOD) or (mark=="no" and BAD) or ((mark=="help" or mark=="held") and (c.accent or c.text)) or c.muted
            local lf=fitted(15*scale,lab,slotW-6*scale)
            text(lab,lf,kx,cy0+cardH-6*scale-capF:getHeight(),slotW,"center",lc)
          end
        end
      else
        btnY=bottom-btnH
      end

      if #acts>0 then
        local gap=8*scale
        local n=#acts
        local bw=math.min(180*scale,(dw-gap*(n-1))/n)
        for i,a in ipairs(acts) do
          local bx=dx+(i-1)*(bw+gap)
          local primary=i==1
          rgba(primary and c.selected or (c.raised or c.surface),isBusy and .5 or 1)
          G.rectangle("fill",bx,btnY,bw,btnH,btnH*.25,btnH*.25)
          rgba(c.frame or c.accent,isBusy and .5 or 1); G.setLineWidth(math.max(1,1.5*scale))
          G.rectangle("line",bx,btnY,bw,btnH,btnH*.25,btnH*.25)
          local bf=fitted(20*scale,a.label,bw-10*scale)
          text(a.label,bf,bx,btnY+(btnH-bf:getHeight())/2,bw,"center",c.text)
          MP._buttons[#MP._buttons+1]={id=a.id,x=bx,y=btnY,w=bw,h=btnH}
          if not isBusy then
            local want=a.id
            addCell({kind="packAction",action=want,x=bx,y=btnY,w=bw,h=btnH,
              select=function(st) return MP.prepareAction(st,want) end,button="a"})
          end
        end
      elseif selected and type(s.inBattle)=="function" and select(2,pcall(s.inBattle,s))==true then
        text("CAN'T USE THIS IN BATTLE",bodyF,dx,btnY+(btnH-bodyF:getHeight())/2,dw,"left",c.muted)
      end

      -- description and holders fill what is left
      local descB=btnY-10*scale
      local holders=MP.holders(s,selected.id)
      local holdH=0
      if #holders>0 and comp.mode~="hold" then holdH=capF:getHeight()+8*scale end
      local desc=""
      if type(s.description)=="function" then
        local ok,v=pcall(s.description,s); desc=ok and v or ""
      end
      desc=MP.norm(ctx,desc or (def and def.description) or "")
      -- the facts grid (in the bag, where it works, a TM's move stats)
      local facts=MP.facts(s,selected,def,reg)
      local factF=font(19*scale)
      local factRowH=factF:getHeight()+8*scale
      local factH=math.ceil(#facts/2)*factRowH
      local room=descB-holdH-yy
      if factH>room-bodyF:getHeight()-12*scale then facts={}; factH=0 end
      local maxLines=math.max(1,math.floor((room-factH-(factH>0 and 12*scale or 0))/bodyF:getHeight()))
      local _,lines=bodyF:getWrap(desc,dw)
      local nLines=type(lines)=="table" and #lines or 1
      if type(lines)=="table" and #lines>maxLines then
        local keep={}
        for k=1,maxLines do keep[k]=lines[k] end
        keep[maxLines]=clipText(bodyF,keep[maxLines].." ...",dw)
        desc=table.concat(keep,"\n")
        nLines=maxLines
      end
      text(desc,bodyF,dx,yy,dw,"left",c.text)
      yy=yy+math.max(1,nLines)*bodyF:getHeight()+12*scale
      if #facts>0 then
        rgba(c.divider or c.muted,.5); G.rectangle("fill",dx,yy-6*scale,dw,math.max(1,scale))
        local colW=dw/2
        for k,f in ipairs(facts) do
          local fx=dx+((k-1)%2)*colW
          local fy=yy+math.floor((k-1)/2)*factRowH+3*scale
          local lw=factF:getWidth(f[1])+10*scale
          text(f[1],factF,fx,fy,lw,"left",c.muted)
          text(clipText(factF,f[2],colW-lw-8*scale),factF,fx+lw,fy,colW-lw-8*scale,"left",f[3] or c.text)
        end
      end
      if holdH>0 then
        local names={}
        for _,i in ipairs(holders) do
          local mon=party[i]
          names[#names+1]=tostring(mon.nickname or mon.species or "?")
        end
        local str="HELD BY "..table.concat(names,", ")
        text(clipText(capF,str,dw),capF,dx,descB-holdH,dw,"left",c.accent or c.text)
      end
    end

    if portrait then
      local avail=contentB-contentY
      local detailH=math.max(380*scale,avail*.36)
      local listH=avail-detailH-12*scale
      drawList(x+pad,contentY,w-pad*2,listH)
      local dy=contentY+listH+6*scale
      rgba(c.divider or c.muted,.8); G.rectangle("fill",x+pad,dy,w-pad*2,math.max(1,scale))
      drawDetail(x+pad,dy+10*scale,w-pad*2,contentB-dy-10*scale)
    else
      local listW=(w-pad*2)*.5
      drawList(x+pad,contentY,listW,contentB-contentY)
      local divX=x+pad+listW+12*scale
      rgba(c.divider or c.muted,.8); G.rectangle("fill",divX,contentY,math.max(1,scale),contentB-contentY)
      local dx=divX+14*scale
      drawDetail(dx,contentY,x+w-pad-dx,contentB-contentY)
    end

    local hints={{"LR","POCKET"},{"A","CHOOSE"}}
    if sortOk then hints[#hints+1]={"START","SORT"} end
    hints[#hints+1]={"B","BACK"}
    MP._footerY=ctx.chromeFooter(x,y,w,h,c,nil,hints)
    MP._window={x=x,y=y,w=w,h=h}

    -- the engine's own overlays, as before
    local body,smallF=font(26*scale),font(19*scale)
    if s.submenu and type(s.submenu.rows)=="table" then
      local labels={use="USE",give="GIVE",toss="TOSS",sel="REGISTER",quit="QUIT"}
      local rr={}; for _,id in ipairs(s.submenu.rows) do rr[#rr+1]=labels[id] or tostring(id) end
      ctx.modal(x,y,w,h,c,selected and selected.name or "ITEM",rr,tonumber(s.submenu.index) or 1,body,smallF)
    elseif s.qtyState then
      ctx.modal(x,y,w,h,c,"HOW MANY?",{("x%d / %d"):format(s.qtyState.qty or 1,s.qtyState.max or 1)},1,body,smallF)
    elseif s.confirm then
      ctx.modal(x,y,w,h,c,"ARE YOU SURE?",{"YES","NO"},tonumber(s.confirm.choice) or 1,body,smallF)
    elseif s.message then
      local msg=type(s.message)=="table" and table.concat(s.message," ") or tostring(s.message)
      msg=MP.norm(ctx,msg)
      if type(s.playerName)=="function" then
        local okN,n=pcall(s.playerName,s); if okN and n then msg=msg:gsub("{PLAYER}",function() return tostring(n) end) end
      end
      ctx.modal(x,y,w,h,c,msg,{},nil,body,smallF)
    end
    return true
  end

  -- -------------------------------------------------------------- START
  -- START in the PACK (unused by the cart's PACK) cycles SORT while the
  -- Modern PACK is showing and nothing is open over the list.
  local function active()
    local S=rawget(mod,"_kantoInMotionGen2Ui")
    return S and S.presenterEnabled and S.presenterEnabled("menu") and S.hideOriginal and S.hideOriginal()
  end
  MP.active=active
  local PackMenu=lib("src.ui.gen2.PackMenu")
  if PackMenu and type(PackMenu.update)=="function" and not PackMenu.__aioModernPackSort then
    local old=PackMenu.update
    PackMenu.update=function(self,dt,...)
      if type(self)=="table" and not busy(self) and active() then
        local input=self.game and self.game.input
        if input and type(input.wasPressed)=="function" and input:wasPressed("start") and MP.canSort(self) then
          MP.cycleSort(self)
          return
        end
      end
      return old(self,dt,...)
    end
    PackMenu.__aioModernPackSort=true
  end
  return MP
end
