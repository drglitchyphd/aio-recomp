-- gen2-aio 0.9.75: the Modern windows of lib/crystal_aio/modern_extras.lua over
-- the ENGINE's own small Crystal screens.
--
--   AIO_ENGINE_SRC=/path/to/engine/src xvfb-run -a love tests/modern_extras
--
-- AIO_ENGINE_SRC is the engine checkout's root (the folder holding src/).
-- The real ContestMenu, BattleTowerMenu (+ BattleTower), DecorationMenu (+
-- Decorations, Typer), ElevatorMenu, BuenaPassword, PhotoStudio, ScriptMenu
-- (+ CoinCase), BugContest and Strings run; only rendering / audio / asset
-- modules are stubbed. Without an engine the test says SKIP and passes.
-- Renders every screen at the Fold's outer (1080x2520) and inner (2184x1968)
-- sizes into AIO_TEST_OUTPUT.
io.stdout:setvbuf("no")
local root=love.filesystem.getSource():gsub("/tests/modern_extras/?$","").."/"
local output=os.getenv("AIO_TEST_OUTPUT") or os.getenv("TEMP") or "/tmp"
local engine=os.getenv("AIO_ENGINE_SRC")
function love.errorhandler(err) print(debug.traceback(tostring(err)));os.exit(1) end

local failures=0
local function check(cond,msg)
  if not cond then failures=failures+1;print("FAIL: "..msg) else print("ok   "..msg) end
end

function love.load()
  if not engine or engine=="" or not io.open(engine.."/src/ui/gen2/ContestMenu.lua","rb") then
    print("modern extras: SKIP (set AIO_ENGINE_SRC to the engine's src root)")
    love.event.quit(0)
    return
  end
  package.path=engine.."/?.lua;"..package.path
  -- screens the other presenters only detect: plain classes
  for _,name in ipairs({"src.render.TextBox","src.ui.ChoiceBox","src.ui.gen2.MartMenu","src.ui.gen2.BattleState",
    "src.ui.gen2.GenderSelect","src.ui.gen2.InitClock","src.ui.gen2.OakSpeech","src.ui.gen2.NamePick",
    "src.ui.gen2.NamingScreen"}) do
    local c={};c.__index=c
    package.preload[name]=function()return c end
  end
  -- Chrome records what the NATIVE screens draw (MODERN UI off)
  local chromeCalls=0
  local Chrome=setmetatable({number=function(v)chromeCalls=chromeCalls+1;return tostring(v)end,
    fitScale=function()return 1 end,fitOrigin=function()return 0,0 end},
    {__index=function(_,k)return function()chromeCalls=chromeCalls+1 end end})
  local G=love.graphics
  local function readFile(rel)
    local f=io.open(root..rel,"rb");if not f then return nil end
    local s=f:read("*a");f:close();return s
  end
  local images={}
  local function image(path)
    if images[path]==nil then
      local bytes=readFile(path)
      images[path]=bytes and G.newImage(love.filesystem.newFileData(bytes,path)) or false
    end
    return images[path] or nil
  end
  local stubs={
    ["src.ui.gen2.Chrome"]=Chrome,
    ["src.render.Assets"]={image=function(p)return assert(image(p),"no image "..tostring(p))end},
    ["src.render.Font"]={useBattleExtra=function()return false end},
    ["src.core.GameVersion"]={get=function()return "crystal" end,engine=function()return "crystal" end},
    ["src.render.GbcPalette"]={available=function()return false end,mode="gbc"},
    ["src.world.gen2.Palettes"]={monColors=function()return nil end},
    ["src.core.Sound"]={resolve=function(_,n)return n end,play=function()end},
    ["src.pokemon.Sprites"]={pic=function(p)return p end},
    ["src.mods.Runtime"]={wants=function()return false end,wantsHook=function()return false end,emit=function()end},
    ["src.core.Logger"]={warn=function()end,info=function()end},
    ["src.core.gen2.Save"]={MAX_COINS=9999,MAX_MONEY=999999,PARTY_SIZE=6,
      battleTowerState=function(s)s.battleTower=s.battleTower or {};return s.battleTower end},
    ["src.core.gen2.Breeding"]={isEgg=function()return false end},
    ["src.core.gen2.HallOfFame"]={hasEntered=function()return false end},
    ["src.battle.gen2.Mon"]={},
  }
  for name,v in pairs(stubs) do package.preload[name]=function()return v end end

  local ContestMenu=require("src.ui.gen2.ContestMenu")
  local BattleTowerMenu=require("src.ui.gen2.BattleTowerMenu")
  local DecorationMenu=require("src.ui.gen2.DecorationMenu")
  local Decorations=require("src.core.gen2.Decorations")
  local ElevatorMenu=require("src.ui.gen2.ElevatorMenu")
  local BuenaPassword=require("src.ui.gen2.BuenaPassword")
  local PhotoStudio=require("src.ui.gen2.PhotoStudio")
  local ScriptMenu=require("src.ui.gen2.ScriptMenu")
  local TextBox=require("src.render.TextBox")

  local dims={1080,2520}
  G.getDimensions=function()return dims[1],dims[2] end
  love.system.getOS=function()return "Android" end
  local hooks,opts={},{}
  local mod={exports={},path=root:gsub("/$",""),options={get=function(_,k)return opts[k]end},
    log={info=function()end,warn=function()end,error=function()end},
    read=function(_,rel)return readFile(rel)end,
    assets={image=function(_,p)return image(p)end},
    hooks={wrap=function(_,name,fn,priority)
      hooks[name]=hooks[name] or {};hooks[name][#hooks[name]+1]={fn=fn,p=priority or 0}
    end}}
  local function run(rel,...)
    return assert(loadstring(assert(readFile(rel)),"@"..rel))()(...)
  end
  run("lib/crystal_aio/font.lua",{mod=mod})
  local S=run("lib/gen2_modern_style.lua",mod)
  run("lib/gen2_modern_dialog_ui.lua",mod)
  check(run("lib/crystal_aio/modern_extras.lua",{mod=mod})==true,"modern_extras loads")
  -- MENU SPRITES: the HD menu icons on disk
  local DEX={SCYTHER=123,CATERPIE=10,PINSIR=127,TOTODILE=158,MAREEP=179,LUGIA=249}
  mod._kantoInMotionHdMenuIconForModernUi=function(_,mon)
    local d=mon and DEX[mon.species]
    return d and ("assets/menu_icons/hd/normal/%03d.png"):format(d) or nil
  end

  local draws,footers={},{}
  local originalText=S.text
  S.text=function(value,font,x,y,w,align,c)
    draws[#draws+1]={text=tostring(value),font=font,x=x,y=y,w=w,align=align}
    return originalText(value,font,x,y,w,align,c)
  end
  local originalFooter=S.footer
  S.footer=function(x,y,w,h,spec)
    footers[#footers+1]={x=x,y=y,w=w,h=h,top=y+h-S.footerHeight()}
    return originalFooter(x,y,w,h,spec)
  end
  local function chain(name,base,...)
    local h={}
    for i,v in ipairs(hooks[name] or {}) do h[i]=v end
    table.sort(h,function(a,b)return a.p<b.p end)
    local fn=base
    for _,link in ipairs(h)do local nextFn=fn;fn=function(...)return link.fn(nextFn,...)end end
    return fn(...)
  end

  local input={pressed={}}
  function input:wasPressed(b) return self.pressed[b] or false end
  local function newGame(save)
    local game={save=save,input=input,data={pokemon={},moves={TACKLE={name="TACKLE"},CUT={name="CUT"}},items={}},
      stack={states={}}}
    for sp,d in pairs(DEX) do
      game.data.pokemon[sp]={name=sp,dex=d,spriteFront=("assets/menu_icons/hd/normal/%03d.png"):format(d)}
    end
    function game.stack:top()return self.states[#self.states] end
    function game.stack:push(s)self.states[#self.states+1]=s end
    function game.stack:pop()self.states[#self.states]=nil end
    return game
  end
  local function press(s,btn)
    input.pressed={[btn]=true};s:update(1/60);input.pressed={}
  end
  local function mon(species,level,maxHp,extra)
    local m={species=species,nickname=species,level=level,hp=maxHp,maxHp=maxHp,moves={{id="TACKLE"}}}
    for k,v in pairs(extra or {}) do m[k]=v end
    return m
  end

  -- ------------------------------------------------------------ frames
  local shots={}
  local function frame(s,game,name)
    draws,footers={},{}
    rawset(mod,"_kimScreenTapTargets",nil)
    local canvas=G.newCanvas(dims[1],dims[2])
    G.setCanvas(canvas);G.clear(.16,.27,.2,1)
    chain("render.hud",function()end,game,{})
    G.setCanvas()
    if name then
      local path=output.."/aio-extras-"..name.."-"..dims[1].."x"..dims[2]..".png"
      local f=assert(io.open(path,"wb"))
      f:write(canvas:newImageData():encode("png"):getString());f:close()
      shots[#shots+1]=path
    end
    canvas:release()
    return rawget(mod,"_kimScreenTapTargets"),rawget(mod,"_kimMenuClose")
  end
  local function cellNamed(t,label)
    for _,c in ipairs(t and t.cells or {}) do if c.label==label then return c end end
  end
  -- the touch module's own generic tap: select, then the cell's button
  local function tapCell(s,t,label)
    local c=assert(cellNamed(t,label),"no cell "..label)
    local m=t.mode(s)
    assert(m=="list" or m=="sub","stale cells for "..label)
    if c.select then c.select(s) end
    local b=c.button;if b==nil then b="a" end
    if b then press(s,b) end
  end
  local function textBox(dr)
    local fw=dr.font:getWidth(dr.text)
    local x=dr.x
    if dr.w and dr.align=="right" then x=dr.x+dr.w-fw elseif dr.w and dr.align=="center" then x=dr.x+(dr.w-fw)/2 end
    return x,dr.y,fw,dr.font:getHeight()
  end
  local function over(ax,ay,aw,ah,bx,by,bw,bh,slack)
    slack=slack or 1
    return ax<bx+bw-slack and bx<ax+aw-slack and ay<by+bh-slack and by<ay+ah-slack
  end
  -- the common layout checks every screen gets
  local function layout(tag,s,t,close,wantClose)
    check(t and t.state==s,tag.." publishes tap cells for the screen on top")
    if wantClose==false then check(close==nil,tag.." no close button (B does nothing here)")
    else check(close and close.state==s,tag.." has the close button") end
    local f=footers[1]
    check(f~=nil,tag.." has the footer")
    if not (t and f) then return end
    local bad={}
    for i,a in ipairs(t.cells) do
      if a.label~="card" then
        if a.x<f.x or a.y<f.y or a.x+a.w>f.x+f.w+0.5 or a.y+a.h>f.top+0.5 then bad[#bad+1]="outside:"..tostring(a.label) end
        for j=i+1,#t.cells do
          local b=t.cells[j]
          if b.label~="card" and over(a.x,a.y,a.w,a.h,b.x,b.y,b.w,b.h) then bad[#bad+1]=tostring(a.label).."/"..tostring(b.label) end
        end
        if close and over(a.x,a.y,a.w,a.h,close.x,close.y,close.w,close.h,0) then bad[#bad+1]="close:"..tostring(a.label) end
      end
    end
    check(#bad==0,tag.." cells inside the window, apart, clear of close and footer "..table.concat(bad," "))
    -- no two texts on top of each other, none under the close button
    local tb={}
    for _,dr in ipairs(draws) do
      if dr.text:match("%S") then local x,y,w,h=textBox(dr);tb[#tb+1]={dr.text,x,y,w,h} end
    end
    local clash={}
    for i,a in ipairs(tb) do
      for j=i+1,#tb do
        local b=tb[j]
        if over(a[2],a[3],a[4],a[5],b[2],b[3],b[4],b[5],2) then clash[#clash+1]=a[1].."|"..b[1] end
      end
      if close and over(a[2],a[3],a[4],a[5],close.x,close.y,close.w,close.h,0) then clash[#clash+1]=a[1].."|CLOSE" end
      if a[2]<0 or a[2]+a[4]>dims[1]+1 then clash[#clash+1]=a[1].."|offscreen" end
    end
    check(#clash==0,tag.." no text overlaps "..table.concat(clash,"  "))
  end
  local function drew(text)
    for _,dr in ipairs(draws) do if dr.text==text then return true end end
    return false
  end
  -- DecorationMenu's typed message: let it type, then A through its pages
  local function settle(s)
    for _=1,10 do
      if not s.pages then return end
      for _=1,300 do s:update(1/60) end
      press(s,"a")
    end
  end

  -- ------------------------------------------------------------ builders
  local function contest()
    local save={bugContest={}}
    local game=newGame(save)
    local kept
    local caught=mon("SCYTHER",14,41)
    save.bugContest.caught=mon("CATERPIE",7,23,{nickname="CATERPIE"})
    local s=ContestMenu.new(game,{save=save,caught=caught,onClose=function(k)kept=k;game.stack:pop()end})
    game.stack:push(s)
    return s,game,function()return kept end,caught
  end
  local function tower(party)
    local save={party=party or {mon("TOTODILE",18,52)}}
    local game=newGame(save)
    local done,group=false,nil
    local s=BattleTowerMenu.new(game,{save=save,monName=function(sp)return sp end,
      onDone=function(g)done=true;group=g end})
    game.stack:push(s)
    return s,game,function()return done,group end
  end
  local function events(flags)
    local e={bits={}}
    function e:get(f)return self.bits[f]==true end
    function e:set(f,v)self.bits[f]=v and true or nil end
    for _,id in ipairs(flags) do Decorations.give(e,id) end
    return e
  end
  local function deco()
    local save={}
    local game=newGame(save)
    local done
    -- PINK / PIKACHU BEDS, the RED CARPET, MAGNAPLANT and two dolls
    local s=DecorationMenu.new(game,{save=save,events=events({3,5,7,12,30,31}),
      onDone=function(changed)done=changed==true and "changed" or "same";game.stack:pop()end})
    game.stack:push(s)
    return s,game,function()return done end
  end
  -- floorId is the FLOOR_* row: 3 = B1F, 4 = 1F, ... (ElevatorMenu's fallback names)
  local FLOORS={{floorId=3,destMap="B1",destWarp=1},{floorId=4,destMap="F1",destWarp=1},{floorId=5,destMap="F2",destWarp=1},
    {floorId=6,destMap="F3",destWarp=1},{floorId=7,destMap="F4",destWarp=1},{floorId=8,destMap="F5",destWarp=1},
    {floorId=9,destMap="F6",destWarp=1}}
  local function elevator()
    local game=newGame({})
    local picked,done=nil,false
    local s=ElevatorMenu.new(game,{floors=FLOORS,currentMap="F2",onDone=function(r)done=true;picked=r;game.stack:pop()end})
    game.stack:push(s)
    return s,game,function()return done,picked end
  end
  local function buena(mode)
    local game=newGame({})
    local answer
    local s=BuenaPassword.new(game,mode=="prize" and {mode="prize",balance=7,
      prizes={{item="ULTRA_BALL",name="ULTRA BALL",cost=2},{item="FULL_RESTORE",name="FULL RESTORE",cost=2},
        {item="NUGGET",name="NUGGET",cost=3},{item="RARE_CANDY",name="RARE CANDY",cost=3},{item="PROTEIN",name="PROTEIN",cost=5},
        {item="IRON",name="IRON",cost=5},{item="CARBOS",name="CARBOS",cost=5},{item="CALCIUM",name="CALCIUM",cost=5},
        {item="HP_UP",name="HP UP",cost=5}},onDone=function(v)answer=v end}
      or {mode="password",width=8,words={"CYNDAQUIL","TOTODILE","CHIKORITA"},onDone=function(v)answer=v end})
    game.stack:push(s)
    return s,game,function()return answer end
  end
  local function photo()
    local save={player={name="KRIS"}}
    local game=newGame(save)
    local closed=false
    local s=PhotoStudio.new(game,{mon=mon("MAREEP",21,58,{gender="female",ot="KRIS",otId=4521,shiny=true}),
      onClose=function()closed=true;game.stack:pop()end})
    game.stack:push(s)
    return s,game,function()return closed end
  end
  local function prize(kind)
    local save={player={money=12345,coins=1234},inventory={COIN_CASE=1}}
    local game=newGame(save)
    local chose
    local items=kind=="vendor" and {" 50 :  \xc2\xa51000","500 : \xc2\xa510000","CANCEL"}
      or {"TM32      1500","TM29      3500","TM15      7500","CANCEL"}
    -- the vendor's question stays up under the menu, as World leaves it
    local box=setmetatable({pages={{"Which prize would","you like?"}},pageIndex=1},TextBox)
    game.stack:push(box)
    local s=ScriptMenu.new(game,{header={left=0,top=2,right=15,bottom=11,dataFlags=0x80,items=items,cursor=1},
      style="vertical",balance=kind=="vendor" and "moneycoins" or "coins",save=save,
      onChoose=function(i)chose=i;game.stack:pop()end})
    game.stack:push(s)
    return s,game,function()return chose end
  end

  -- ------------------------------------------------------------ layout, both sizes
  for _,d in ipairs({{1080,2520},{2184,1968}}) do
    dims=d
    local tag=dims[1].."x"..dims[2]
    do
      local s,game=contest()
      local t,close=frame(s,game,"contest")
      layout(tag.." contest",s,t,close)
      check(cellNamed(t,"YES") and cellNamed(t,"NO"),tag.." contest: YES / NO buttons")
      check(drew("STOCK POKéMON") and drew("THIS POKéMON") and drew("SCYTHER") and drew("CATERPIE"),tag.." contest: both cards")
    end
    do
      local s,game=tower()
      local t,close=frame(s,game,"tower")
      layout(tag.." tower",s,t,close)
      check(cellNamed(t,"LEVEL 10") and cellNamed(t,"CANCEL"),tag.." tower: the level groups as a list")
      press(s,"b")
      t,close=frame(s,game,"tower-quit")
      layout(tag.." tower quit",s,t,close)
      check(close and close.back==true,tag.." tower: the cancel question shows the back arrow")
    end
    do
      local s,game=deco()
      local t,close=frame(s,game,"deco")
      layout(tag.." decoration",s,t,close)
      check(close and close.back==false,tag.." decoration categories: close X")
      tapCell(s,t,"BED")
      t,close=frame(s,game,"deco-items")
      layout(tag.." decoration items",s,t,close)
      check(close and close.back==true,tag.." decoration items: back arrow")
      check(drew("SET UP")==false,tag.." no bed of these set up yet (the FEATHERY BED is)")
      tapCell(s,t,"PINK BED")
      t=frame(s,game)
      check(#t.cells==0,tag.." decoration message: no row cells while it types (a tap is A)")
      for _=1,300 do s:update(1/60) end
      t,close=frame(s,game,"deco-message")
      layout(tag.." decoration message",s,t,close)
      settle(s)
      t=frame(s,game)
      check(drew("SET UP") and s.mode=="items",tag.." PINK BED now tagged SET UP")
      press(s,"b")
      t=frame(s,game);tapCell(s,t,"ORNAMENT")
      t=frame(s,game);tapCell(s,t,"PIKACHU DOLL")
      t,close=frame(s,game,"deco-side")
      layout(tag.." decoration side",s,t,close)
    end
    do
      local s,game=elevator()
      local t,close=frame(s,game,"elevator")
      layout(tag.." elevator",s,t,close)
      check(drew("NOW ON") and drew("NOW ON  2F"),tag.." elevator: the floor you are on is tagged")
    end
    do
      local s,game=buena("password")
      local t,close=frame(s,game,"buena-password")
      layout(tag.." buena password",s,t,close,false)
      s,game=buena("prize")
      t,close=frame(s,game,"buena-prize")
      layout(tag.." buena prize",s,t,close)
      check(drew("POINTS 7"),tag.." buena: the Blue Card balance")
    end
    do
      local s,game=photo()
      local t,close=frame(s,game,"photo")
      layout(tag.." photo",s,t,close)
      check(drew("MAREEP") and drew("04521") and drew("TACKLE"),tag.." photo: name, ID and move on the card")
    end
    do
      local s,game=prize("tm")
      local t,close=frame(s,game,"prize")
      layout(tag.." prize",s,t,close)
      check(drew("COINS 1234") and drew("1500 COINS") and drew("TM32"),tag.." prize: coins and a price column ("..tostring(drew("COINS 1234"))..")")
      check(drew("Which prize would you like?"),tag.." prize: the counter's question")
      s,game=prize("vendor")
      t,close=frame(s,game,"coin-vendor")
      layout(tag.." coin vendor",s,t,close)
      check(drew("¥12345   COINS 1234") and drew("50 COINS") and drew("¥1000"),tag.." coin vendor: money, coins, price")
    end
  end
  dims={1080,2520}

  -- ------------------------------------------------------------ taps through the engine
  do
    local s,game,kept,caught=contest()
    local t=frame(s,game);tapCell(s,t,"NO")
    check(kept() and kept().species=="CATERPIE" and s.save.bugContest.caught.species=="CATERPIE","contest: NO keeps the stock mon")
    s,game,kept,caught=contest()
    t=frame(s,game);tapCell(s,t,"YES")
    check(kept()==caught and s.save.bugContest.caught==caught,"contest: YES switches through BugContest.switchCaught")
    s,game,kept=contest();press(s,"b")
    check(kept().species=="CATERPIE","contest: B (the close button) keeps the stock mon")
  end
  do
    local s,game,res=tower()
    local t=frame(s,game);tapCell(s,t,"LEVEL 20")
    local done,group=res()
    check(done and group==2,"tower: tapping LEVEL 20 picks group 2 ("..tostring(group)..")")
    s,game,res=tower({mon("LUGIA",40,150)})
    t=frame(s,game);tapCell(s,t,"LEVEL 10")
    check(s.phase=="message" and not res(),"tower: a party mon over the level is the engine's refusal")
    t=frame(s,game,"tower-refusal")
    check(t and #t.cells==0,"tower: the refusal shows no cells (a tap is A)")
    s,game,res=tower()
    t=frame(s,game);tapCell(s,t,"CANCEL")
    check(s.phase=="quit","tower: CANCEL asks to cancel")
    local stale=t
    t=frame(s,game);tapCell(s,t,"NO")
    check(s.phase=="pick" and not res(),"tower: NO goes back to the list")
    check(stale.mode(s)=="list","tower: the pick cells are live again on the list")
    press(s,"b");check(stale.mode(s)==nil,"tower: cells drawn for the list are stale on the question")
    t=frame(s,game);tapCell(s,t,"YES")
    local done2,g2=res()
    check(done2 and g2==nil,"tower: YES cancels the challenge")
  end
  do
    local s,game,done=deco()
    local t=frame(s,game);tapCell(s,t,"BED")
    t=frame(s,game);tapCell(s,t,"PIKACHU BED")
    check(s.save.decorations.bed==5,"deco: the PIKACHU BED set up by Decorations.apply")
    settle(s)
    t=frame(s,game);tapCell(s,t,"CANCEL")
    check(s.mode=="category","deco: CANCEL back to the categories")
    t=frame(s,game);tapCell(s,t,"ORNAMENT")
    t=frame(s,game);tapCell(s,t,"PIKACHU DOLL")
    check(s.mode=="side","deco: an ornament asks which side")
    t=frame(s,game);tapCell(s,t,"LEFT SIDE")
    check(s.save.decorations.leftOrnament==30,"deco: the doll stands on the LEFT")
    settle(s)
    t=frame(s,game)
    check(drew("LEFT"),"deco: the doll's row is tagged LEFT")
    press(s,"b")
    t=frame(s,game);tapCell(s,t,"EXIT")
    check(done()=="changed","deco: EXIT reports the room changed")
  end
  do
    local s,game,res=elevator()
    local t=frame(s,game);tapCell(s,t,"5F")
    local done,row=res()
    check(done and row==FLOORS[6],"elevator: tapping 5F rides there")
    s,game,res=elevator()
    t=frame(s,game);tapCell(s,t,"2F")
    done,row=res()
    check(done and row==nil,"elevator: the floor you are on just closes the doors")
  end
  do
    local s,game,ans=buena("password")
    local t=frame(s,game)
    check(t.mode(s)=="sub","buena: a tap that misses every word answers nothing (0.9.75)")
    tapCell(s,t,"CHIKORITA")
    check(ans()==2,"buena: the third word answers index 2")
    s,game,ans=buena("prize")
    t=frame(s,game);tapCell(s,t,"RARE CANDY")
    check(ans()==4,"buena: the prize row answers its row")
  end
  do
    local s,game,closed=photo()
    local t=frame(s,game);tapCell(s,t,"card")
    check(closed(),"photo: a tap puts the card away")
  end
  do
    local s,game,chose=prize("tm")
    local t=frame(s,game);tapCell(s,t,"TM29")
    check(chose()==2,"prize: tapping TM29 answers 2 to the counter's script")
    check(s.save.player.coins==1234,"prize: the menu never touches the coins")
    s,game,chose=prize("vendor");press(s,"b")
    check(chose()==0,"coin vendor: B is the cancel arm")
  end

  -- ------------------------------------------------------------ MODERN UI / MENU UI off
  for _,o in ipairs({{"gen2IntegratedModernUi","MODERN UI"},{"menuUi","MENU UI"}}) do
    opts[o[1]]=false
    for name,make in pairs({contest=contest,tower=tower,deco=deco,elevator=elevator,photo=photo,
        buena=function()return buena("prize")end,prize=function()return prize("tm")end}) do
      local s,game=make()
      local t=frame(s,game)
      check(t==nil and rawget(mod,"_kimMenuClose")==nil,o[2].." off: no Modern window over "..name)
      chromeCalls=0
      local shown=chain("screen.render_visible",function(st)
        local okD=pcall(st.drawPanel or st.draw,st);return okD end,s)
      check(shown==true and chromeCalls>0,o[2].." off: the native "..name.." draws ("..chromeCalls.." Chrome calls)")
    end
    local s=elevator();press(s,"down")
    check(s.index==2,o[2].." off: the native elevator's own DOWN")
    opts[o[1]]=nil
  end

  for _,p in ipairs(shots) do print("png",p) end
  if failures>0 then print(("modern extras: %d FAILED"):format(failures));os.exit(1) end
  print("modern extras: PASS")
  love.event.quit(0)
end
