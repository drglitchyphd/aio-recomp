-- gen2-aio 0.9.72: the Modern PC box grid over the ENGINE's own BoxMenu.
--
--   AIO_ENGINE_SRC=/path/to/engine/src xvfb-run -a love tests/box_pc
--
-- AIO_ENGINE_SRC is the engine checkout's root (the folder holding src/).
-- The real src/ui/gen2/BoxMenu.lua, src/core/gen2/Boxes.lua, Mail.lua and
-- Strings.lua run; only rendering / audio / asset modules are stubbed. Without
-- an engine the test says SKIP and passes. Renders the screen at the Fold's
-- outer (1080x2520) and inner (2184x1968) sizes into AIO_TEST_OUTPUT.
io.stdout:setvbuf("no")
local root=love.filesystem.getSource():gsub("/tests/box_pc/?$","").."/"
local output=os.getenv("AIO_TEST_OUTPUT") or os.getenv("TEMP") or "/tmp"
local engine=os.getenv("AIO_ENGINE_SRC")
function love.errorhandler(err) print(debug.traceback(tostring(err)));os.exit(1) end

local failures=0
local function check(cond,msg)
  if not cond then failures=failures+1;print("FAIL: "..msg) else print("ok   "..msg) end
end

function love.load()
  if not engine or engine=="" or not io.open(engine.."/src/ui/gen2/BoxMenu.lua","rb") then
    print("box pc: SKIP (set AIO_ENGINE_SRC to the engine's src root)")
    love.event.quit(0)
    return
  end
  package.path=engine.."/?.lua;"..package.path
  -- screens the presenter only detects: plain classes
  for _,name in ipairs({"src.render.TextBox","src.ui.ChoiceBox","src.ui.gen2.MartMenu","src.ui.gen2.MainMenu",
    "src.ui.gen2.TitleState","src.ui.gen2.StartMenu","src.ui.gen2.PackMenu","src.ui.gen2.TrainerCard",
    "src.ui.gen2.SaveMenu","src.ui.gen2.OptionsMenu","src.ui.gen2.Pokegear","src.ui.gen2.SummaryMenu",
    "src.ui.gen2.PokedexMenu","src.ui.gen2.HeldItemMenu","src.ui.gen2.InitClock","src.ui.gen2.CenterPcMenu",
    "src.ui.gen2.PcMenu","src.ui.gen2.EvolutionAnim","src.ui.ListMenu","src.ui.Menu","src.mods.ManagerState",
    "src.world.gen2.FieldMoves","src.ui.gen2.Typer"}) do
    local c={};c.__index=c
    package.preload[name]=function()return c end
  end
  -- rendering / audio / assets BoxMenu pulls in
  local Party={};Party.__index=Party
  function Party.heldMarkerRow()return nil end
  local stubs={
    ["src.render.Assets"]={image=function()error("no assets in the test")end},
    ["src.ui.gen2.Chrome"]={},
    ["src.render.Font"]={useBattleExtra=function()return false end},
    ["src.core.GameVersion"]={get=function()return "crystal" end,engine=function()return "crystal" end},
    ["src.render.GbcPalette"]={available=function()return false end},
    ["src.world.gen2.Palettes"]={monColors=function()return nil end},
    ["src.ui.gen2.PartyMenu"]=Party,
    ["src.core.Sound"]={resolve=function(_,n)return n end,play=function()end,waitSfxDone=function()end,playCry=function()end},
    ["src.pokemon.Sprites"]={pic=function(p)return p end},
    ["src.core.gen2.Unown"]={SPECIES="UNOWN",monLetter=function()return nil end},
    ["src.battle.gen2.Mon"]={restoreAllPp=function()end},
    ["src.core.gen2.Save"]={NUM_BOXES=14,MONS_PER_BOX=20,PARTY_SIZE=6},
    ["src.mods.Runtime"]={wants=function()return false end,emit=function()end},
    ["src.core.Logger"]={warn=function()end,info=function()end},
  }
  local pushed={}
  stubs["src.ui.Screens"]={get=function()return true end,push=function(game,name,opts)
    pushed[#pushed+1]=name;game.stack:push({screen=name,opts=opts})end}
  for name,v in pairs(stubs) do package.preload[name]=function()return v end end
  local CommonText={pages=function(t)
    local out={}
    for page in (tostring(t).."\f"):gmatch("(.-)\f") do
      local rows={};for l in (page.."\n"):gmatch("(.-)\n") do rows[#rows+1]=l end
      out[#out+1]=rows
    end
    return out
  end}
  package.preload["src.core.gen2.CommonText"]=function()return CommonText end

  local BoxMenu=require("src.ui.gen2.BoxMenu")
  local Boxes=require("src.core.gen2.Boxes")

  local G=love.graphics
  local dims={1080,2520}
  G.getDimensions=function()return dims[1],dims[2] end
  love.system.getOS=function()return "Android" end
  local function readFile(rel)
    local f=io.open(root..rel,"rb");if not f then return nil end
    local s=f:read("*a");f:close();return s
  end
  local hooks,opts={},{}
  local images={}
  local function image(path)
    if images[path]==nil then
      local bytes=readFile(path)
      images[path]=bytes and G.newImage(love.filesystem.newFileData(bytes,path)) or false
    end
    return images[path] or nil
  end
  local mod={exports={},path=root:gsub("/$",""),options={get=function(_,k)return opts[k]end},
    log={info=function()end,warn=function()end,error=function()end},
    read=function(_,rel)return readFile(rel)end,
    assets={image=function(_,p)return image(p)end},
    hooks={wrap=function(_,name,fn,priority)
      hooks[name]=hooks[name] or {};hooks[name][#hooks[name]+1]={fn=fn,p=priority or 0}
    end}}
  mod._kimArenaDiag=function(k,v)error(k..": "..tostring(v))end
  local function run(rel,...)
    return assert(loadstring(assert(readFile(rel)),"@"..rel))()(...)
  end
  run("lib/gen2_aio/font.lua",{mod=mod})
  local S=run("lib/gen2_modern_style.lua",mod)
  assert(run("lib/gen2_modern_core_menus.lua",mod))
  mod.exports.screenTapTargets=function()return rawget(mod,"_kimScreenTapTargets") end
  mod.exports.menuCloseRect=function()return rawget(mod,"_kimMenuClose")end
  -- MENU SPRITES = KIM: the HD menu art; the test has only the HD menu icons
  -- on disk, so they stand in for the sprite sheets
  local DEX={TOTODILE=158,PIDGEY=16,MAREEP=179,SENTRET=161,HOOTHOOT=163,RATTATA=19,GEODUDE=74,ZUBAT=41,
    BELLSPROUT=69,WOOPER=194,ONIX=95,SPINARAK=167,LEDYBA=165,MAGIKARP=129}
  local spriteCalls=0
  mod.exports.getSprite=function(species,o)
    spriteCalls=spriteCalls+1
    if opts.gen2MenuSpriteSource=="vanilla" then return nil end
    local dex=DEX[species]
    return dex and image(("assets/menu_icons/hd/normal/%03d.png"):format(dex)) or nil
  end

  local draws={}
  local originalText=S.text
  S.text=function(value,font,x,y,w,align,c)
    draws[#draws+1]={text=tostring(value),font=font,x=x,y=y,w=w,align=align}
    return originalText(value,font,x,y,w,align,c)
  end
  local function chain(name,base,...)
    local h={}
    for i,v in ipairs(hooks[name] or {}) do h[i]=v end
    table.sort(h,function(a,b)return a.p<b.p end)
    local fn=base
    for _,link in ipairs(h)do local nextFn=fn;fn=function(...)return link.fn(nextFn,...)end end
    return fn(...)
  end

  -- ------------------------------------------------------------ the save
  local function mon(species,level,hp,extra)
    local m={species=species,nickname=species,level=level,hp=hp,maxHp=math.max(hp,level*3),moves={{id="TACKLE",pp=35}}}
    for k,v in pairs(extra or {}) do m[k]=v end
    return m
  end
  local function newSave()
    local save={currentBox=1,party={mon("TOTODILE",14,40),mon("PIDGEY",9,0),mon("MAREEP",11,30)},boxes={}}
    save.boxes[1]={mon("SENTRET",5,15),mon("HOOTHOOT",6,18),mon("RATTATA",4,12),mon("GEODUDE",8,24),mon("ZUBAT",7,21)}
    save.boxes[2]={}
    for i=1,20 do save.boxes[2][i]=mon("MAGIKARP",i,i*3) end
    return save
  end
  local input={pressed={}}
  function input:wasPressed(b) return self.pressed[b] or false end
  local function newGame(save)
    local states={}
    local game={save=save,input=input,data={pokemon={},moves={TACKLE={name="TACKLE"}}},stack={states=states}}
    for sp,d in pairs(DEX) do game.data.pokemon[sp]={name=sp,nationalDex=d,types={"NORMAL","NORMAL"}} end
    function game.stack:top()return self.states[#self.states] end
    function game.stack:push(s)self.states[#self.states+1]=s end
    function game.stack:pop()self.states[#self.states]=nil end
    return game
  end
  local function open(mode,save)
    save=save or newSave()
    local game=newGame(save)
    local closed=false
    local s=BoxMenu.new(game,{save=save,mode=mode,onClose=function()closed=true;game.stack:pop()end})
    game.stack:push(s)
    return s,game,function()return closed end
  end
  local function press(s,btn)
    input.pressed={[btn]=true};s:update(1/60);input.pressed={}
  end
  -- let BoxMenu's cry / "Stored X!" hold run out, then clear any message
  local function settle(s)
    for _=1,200 do
      if not (s.messageFrames or s.cryWait) then break end
      s:update(1/60)
    end
    local n=0
    while s.message and n<6 do press(s,"a");n=n+1 end
  end
  local function names(list)
    local out={};for i,m in ipairs(list or {}) do out[i]=m.species end
    return table.concat(out,",")
  end
  local shots={}
  local function frame(s,game,name)
    draws={}
    local canvas=G.newCanvas(dims[1],dims[2])
    G.setCanvas(canvas);G.clear(.16,.27,.2,1)
    chain("render.hud",function()end,game,{})
    G.setCanvas()
    if name then
      local path=output.."/aio-boxpc-"..name.."-"..dims[1].."x"..dims[2]..".png"
      local f=assert(io.open(path,"wb"))
      f:write(canvas:newImageData():encode("png"):getString());f:close()
      shots[#shots+1]=path
    end
    canvas:release()
    return rawget(mod,"_kimScreenTapTargets"),rawget(mod,"_kimMenuClose")
  end
  local function cellsOf(t,area)
    local out={}
    for _,c in ipairs(t and t.cells or {}) do
      local p=c.drop or c.drag
      if p and p.area==area then out[p.slot]=c end
    end
    return out
  end

  -- ------------------------------------------------------------ layout
  for _,d in ipairs({{1080,2520},{2184,1968},{1280,720}}) do
    dims=d
    local s,game=open("withdraw")
    local t,close=frame(s,game,"browse")
    local tag=dims[1].."x"..dims[2]
    check(close and close.state==s,tag.." publishes the close button")
    check(t and t.state==s,tag.." publishes tap cells")
    local party,box=cellsOf(t,"party"),cellsOf(t,"box")
    local np,nb=0,0
    for _ in pairs(party) do np=np+1 end
    for _ in pairs(box) do nb=nb+1 end
    check(np==6 and nb==20,tag.." party strip of 6 and a page of 20 ("..np..","..nb..")")
    -- every cell on screen, none overlapping another or the close button
    local all={}
    for _,c in pairs(party) do all[#all+1]=c end
    for _,c in pairs(box) do all[#all+1]=c end
    local bad=0
    for i,a in ipairs(all) do
      if a.x<0 or a.y<0 or a.x+a.w>dims[1] or a.y+a.h>dims[2] then bad=bad+1 end
      for j=i+1,#all do
        local b=all[j]
        if a.x<b.x+b.w-0.5 and b.x<a.x+a.w-0.5 and a.y<b.y+b.h-0.5 and b.y<a.y+a.h-0.5 then bad=bad+1 end
      end
      if close and a.x<close.x+close.w and close.x<a.x+a.w and a.y<close.y+close.h and close.y<a.y+a.h then bad=bad+1 end
    end
    check(bad==0,tag.." cells on screen, apart, clear of the close button")
    -- the party strip sits above the page; the page's last row above the footer text
    check(party[1].y+party[1].h<=box[1].y,tag.." party strip above the grid")
    local footerY
    for _,dr in ipairs(draws) do if dr.text=="BACK" then footerY=dr.y end end
    check(footerY and box[20].y+box[20].h<footerY,tag.." grid clear of the footer")
    local sawPage,sawBoxName=false,false
    for _,dr in ipairs(draws) do
      if dr.text=="PAGE 1 / 14" then sawPage=true end
      if dr.text:find("BOX1",1,true) then sawBoxName=true end
    end
    check(sawPage and not sawBoxName,tag.." shows PAGE 1 / 14, no box name")
    if dims[1]>=2000 then check(box[1].w>=(1080*.94-60)/5*0.9,tag.." inner screen grid at least as big as the outer one") end
    -- detail text (the selected mon's name) clear of the cells
    for _,dr in ipairs(draws) do
      if dr.text=="SENTRET" then
        local over=false
        for _,c in ipairs(all) do
          if dr.x<c.x+c.w and c.x<dr.x+dr.font:getWidth(dr.text) and dr.y<c.y+c.h and c.y<dr.y+dr.font:getHeight() then over=true end
        end
        check(not over,tag.." detail panel clear of the grid")
      end
    end
    -- the context menu and a message, rendered
    press(s,"a")
    frame(s,game,"submenu")
    press(s,"b")
    -- page 2 (full) with the cursor on a mon
    press(s,"r")
    frame(s,game,"page2")
    press(s,"l")
  end
  dims={1080,2520}

  -- ------------------------------------------------------------ buttons
  do
    local s,game,closed=open("withdraw")
    press(s,"a")
    check(s.phase=="submenu" and s.mode=="withdraw","A on a boxed mon opens BoxMenu's WITHDRAW submenu")
    local rows=s:submenuRows()
    check(rows[1]=="WITHDRAW" and rows[3]=="RELEASE","submenu rows are the engine's (WITHDRAW/STATS/RELEASE/CANCEL)")
    press(s,"a") -- WITHDRAW
    settle(s)
    check(names(s.save.party)=="TOTODILE,PIDGEY,MAREEP,SENTRET","WITHDRAW through the engine: SENTRET joined the party")
    check(#s.save.boxes[1]==4,"and left box 1")
    -- up to the party strip: DEPOSIT's rows
    press(s,"up")
    press(s,"a")
    check(s.phase=="submenu" and s:submenuRows()[1]=="DEPOSIT","A on a party mon opens DEPOSIT's submenu")
    press(s,"b")
    check(s.phase==nil,"B closes the submenu")
    -- the page: right off the edge turns it, L/R too
    press(s,"down")
    for _=1,5 do press(s,"right") end
    local t=frame(s,game)
    local sawPage=false
    for _,dr in ipairs(draws) do if dr.text=="PAGE 2 / 14" then sawPage=true end end
    check(sawPage,"RIGHT off the page's edge turns to PAGE 2")
    press(s,"l");press(s,"l")
    frame(s,game)
    for _,dr in ipairs(draws) do if dr.text=="PAGE 14 / 14" then sawPage="wrap" end end
    check(sawPage=="wrap","L wraps to PAGE 14")
    press(s,"b")
    check(closed(),"B on the grid closes the PC")
  end

  -- STATS from the context menu is the engine's own (Gen2SummaryMenu)
  do
    local s=open("withdraw")
    press(s,"a");press(s,"down");press(s,"a")
    check(pushed[#pushed]=="Gen2SummaryMenu","STATS opens the engine's summary")
  end

  -- ------------------------------------------------------------ drags
  local function drop(s,game,from,to)
    local t=frame(s,game)
    t.dragStart(s,from,0,0)
    t.dragDrop(s,from,to)
  end
  local function P(s,area,page,slot)
    local list=area=="party" and s.save.party or s.save.boxes[page]
    return {area=area,page=page,slot=slot,mon=list[slot]}
  end
  do
    local s,game=open("withdraw")
    -- reorder inside a page: SENTRET onto slot 3
    drop(s,game,P(s,"box",1,1),{area="box",page=1,slot=3})
    settle(s)
    check(names(s.save.boxes[1])=="HOOTHOOT,RATTATA,SENTRET,GEODUDE,ZUBAT","drag inside a page: lands on the slot it was dropped on")
    -- onto the empty cell past the end: last
    drop(s,game,P(s,"box",1,1),{area="box",page=1,slot=12})
    settle(s)
    check(names(s.save.boxes[1])=="RATTATA,SENTRET,GEODUDE,ZUBAT,HOOTHOOT","drag past the last mon: goes last")
    check(s.message==nil and s.phase==nil,"a drag move leaves no message to clear")
    -- forward to the front
    drop(s,game,P(s,"box",1,5),{area="box",page=1,slot=1})
    check(names(s.save.boxes[1])=="HOOTHOOT,RATTATA,SENTRET,GEODUDE,ZUBAT","drag to the front")
    -- to another page (empty box 3)
    drop(s,game,P(s,"box",1,2),{area="box",page=3,slot=7})
    check(names(s.save.boxes[3])=="RATTATA" and #s.save.boxes[1]==4,"drag to an empty page: moved there")
    -- into a full page: the engine's "There's no room!", nothing moved
    drop(s,game,P(s,"box",1,1),{area="box",page=2,slot=1})
    check(s.message and tostring(s.message):find("no room"),"drag into a full page: the engine's refusal ("..tostring(s.message)..")")
    check(#s.save.boxes[2]==20 and #s.save.boxes[1]==4,"nothing moved")
    settle(s)
    -- party -> page: DEPOSIT (Stored X!), onto slot 2
    drop(s,game,P(s,"party",nil,3),{area="box",page=1,slot=2})
    check(s.message and tostring(s.message):find("Stored"),"party -> page is DEPOSIT (engine message: "..tostring(s.message)..")")
    settle(s)
    check(names(s.save.party)=="TOTODILE,PIDGEY","MAREEP left the party")
    check(names(s.save.boxes[1])=="HOOTHOOT,MAREEP,SENTRET,GEODUDE,ZUBAT","and landed on the slot it was dropped on")
    -- the last healthy mon may not be deposited
    drop(s,game,P(s,"party",nil,1),{area="box",page=1,slot=1})
    check(s.message and tostring(s.message):find("last"),"last healthy mon refused ("..tostring(s.message)..")")
    settle(s)
    check(#s.save.party==2,"party unchanged")
    -- into a full page via DEPOSIT
    s.save.party[3]=mon("WOOPER",5,15)
    drop(s,game,P(s,"party",nil,3),{area="box",page=2,slot=4})
    check(s.message and tostring(s.message):find("full"),"deposit into a full page refused ("..tostring(s.message)..")")
    settle(s)
    -- page -> party: WITHDRAW, onto party slot 1
    drop(s,game,P(s,"box",1,1),{area="party",slot=1})
    check(s.message and tostring(s.message):find("Got"),"page -> party is WITHDRAW ("..tostring(s.message)..")")
    settle(s)
    check(names(s.save.party)=="HOOTHOOT,TOTODILE,PIDGEY,WOOPER","withdrawn mon lands on the dropped party slot")
    -- party full
    s.save.party[5]=mon("ONIX",10,30);s.save.party[6]=mon("SPINARAK",10,30)
    drop(s,game,P(s,"box",1,1),{area="party",slot=2})
    check(s.message and tostring(s.message):find("any more"),"withdraw into a full party refused ("..tostring(s.message)..")")
    settle(s)
    -- party reorder
    drop(s,game,P(s,"party",nil,6),{area="party",slot=1})
    check(names(s.save.party)=="SPINARAK,HOOTHOOT,TOTODILE,PIDGEY,WOOPER,ONIX","party reorder by drag")
    -- with a letter in the party, party moves are refused (sPartyMail is per slot)
    s.save.party[2].item="FLOWER_MAIL"
    drop(s,game,P(s,"party",nil,1),{area="party",slot=4})
    check(s.message and tostring(s.message):find("MAIL"),"party reorder refused while a mon holds MAIL")
    settle(s)
    s.save.party[2].item=nil
    -- picked up and put back = the tap's context menu
    drop(s,game,P(s,"box",1,1),{area="box",page=1,slot=1})
    check(s.phase=="submenu","drop on its own cell opens the context menu")
    press(s,"b")
    -- a stale payload (the mon moved since) does nothing
    local stale=P(s,"box",1,1);stale.mon={}
    local before=names(s.save.boxes[1])
    drop(s,game,stale,{area="box",page=1,slot=3})
    check(names(s.save.boxes[1])==before and s.phase==nil,"stale drag ignored")
    check(s.mode=="withdraw","the state goes back to the mode PcMenu opened")
  end

  -- ------------------------------------------------------------ MOVE PKMN W/O MAIL with buttons
  do
    local s,game=open("move")
    press(s,"a")
    check(s:submenuRows()[1]=="MOVE","MOVE PKMN: the engine's MOVE / STATS / CANCEL")
    press(s,"a")
    check(s.phase=="insert","MOVE: the insert cursor")
    frame(s,game,"insert")
    press(s,"r");press(s,"r") -- page 3
    press(s,"a")
    check(names(s.save.boxes[3])=="SENTRET" and #s.save.boxes[1]==4,"A puts it on page 3")
    check(s.message~=nil,"the cart's Saving… message stays for the button flow")
    settle(s)
    -- into the party: up to the strip, slot 2
    press(s,"l");press(s,"l") -- page 1
    press(s,"a");press(s,"a")
    press(s,"up");press(s,"right")
    press(s,"a")
    settle(s)
    check(names(s.save.party)=="TOTODILE,HOOTHOOT,PIDGEY,MAREEP","MOVE into the party at the cursor")
    -- B backs out of the insert cursor
    press(s,"down");press(s,"a");press(s,"a")
    check(s.phase=="insert","insert again")
    press(s,"b")
    check(s.phase==nil and #s.save.boxes[1]==3,"B cancels the move")
  end

  -- ------------------------------------------------------------ touch
  do
    local s,game=open("withdraw")
    local tlog={}
    local T=100
    love.timer.getTime=function()return T end
    local thooks={}
    local tmod={id="touch",exports={},options={get=function()return nil end,define=function()end},read=function()return nil end,
      hooks={wrap=function(_,n,f,p)thooks[n]=thooks[n] or {};thooks[n][p]=f end},
      input={tap=function(_,g,b)tlog[#tlog+1]="tap:"..b;press(s,b)end,press=function(_,g,b)tlog[#tlog+1]="press:"..b;return {} end,release=function()end},
      find=function()return {exports=mod.exports} end}
    setmetatable(tmod,{__index=mod})
    package.preload["src.core.TouchControls"]=function()return {active=true,layout=function()return {} end} end
    package.preload["src.core.TouchSkin"]=function()return {active=false} end
    assert(loadstring(assert(readFile("touch/main.lua")),"@touch/main.lua"))()(tmod)
    local ptr=thooks["input.pointer"][10]
    local function send(phase,x,y)return ptr(function()end,game,{phase=phase,x=x,y=y,id=1,source="touch"}) end
    local t=frame(s,game)
    local box=cellsOf(t,"box");local party=cellsOf(t,"party")
    local function mid(c)return c.x+c.w/2,c.y+c.h/2 end
    -- a short tap on a mon = its context menu
    local x,y=mid(box[2])
    tlog={};send("pressed",x,y);T=T+0.08;send("released",x,y)
    check(s.phase=="submenu" and s.index==2,"touch: a tap on a mon opens its context menu ("..table.concat(tlog,",")..")")
    t=frame(s,game)
    check(t.mode=="sub","touch: the context menu publishes its own rows")
    -- a tap beside the menu does nothing; the close button (back) is B
    press(s,"b")
    -- slide a mon from the page to party slot 1: WITHDRAW
    t=frame(s,game);box=cellsOf(t,"box");party=cellsOf(t,"party")
    x,y=mid(box[1])
    local px,py=mid(party[1])
    tlog={};send("pressed",x,y);T=T+0.05
    send("moved",x+30,y-30);T=T+0.05
    frame(s,game,"touch-drag")
    send("moved",px,py);T=T+0.05
    frame(s,game,"touch-drag-hover")
    send("released",px,py)
    settle(s)
    check(names(s.save.party)=="SENTRET,TOTODILE,PIDGEY,MAREEP","touch: a drag to party slot 1 withdrew SENTRET there")
    check(not table.concat(tlog,","):find("tap:a"),"touch: a drag never also taps A ("..table.concat(tlog,",")..")")
    -- hold still (long press) then drag within the page
    t=frame(s,game);box=cellsOf(t,"box")
    x,y=mid(box[1]);local x4,y4=mid(box[4])
    send("pressed",x,y);T=T+0.6;frame(s,game)
    send("moved",x4,y4);T=T+0.05
    send("released",x4,y4)
    check(names(s.save.boxes[1])=="RATTATA,GEODUDE,ZUBAT,HOOTHOOT","touch: hold then drag reorders the page")
    -- a drag resting on the page arrow turns the page
    t=frame(s,game);box=cellsOf(t,"box")
    local arrowCell
    for _,c in ipairs(t.cells) do
      if not c.drop and c.y<box[1].y and c.x>dims[1]*.6 and math.abs(c.w-c.h)<1 then arrowCell=c end
    end
    check(arrowCell~=nil,"touch: the next-page arrow is a tap cell")
    x,y=mid(box[1])
    send("pressed",x,y);T=T+0.05
    local ax,ay=arrowCell.x+arrowCell.w/2,arrowCell.y+arrowCell.h/2
    send("moved",ax,ay);frame(s,game);T=T+0.7;frame(s,game);T=T+0.05
    t=frame(s,game);box=cellsOf(t,"box")
    local bx,by=mid(box[1])
    send("moved",bx,by);T=T+0.05
    send("released",bx,by)
    check(s.message and tostring(s.message):find("no room") and #s.save.boxes[1]==4,
      "touch: resting on the arrow turned to page 2 (full: the engine's no room)")
    settle(s)
    -- the arrow itself, tapped
    t=frame(s,game)
    tlog={};send("pressed",ax,ay);T=T+0.08;send("released",ax,ay)
    frame(s,game)
    local sawPage
    for _,dr in ipairs(draws) do if dr.text:match("^PAGE %d+ / 14$") then sawPage=dr.text end end
    check(sawPage=="PAGE 3 / 14" and not table.concat(tlog,","):find("tap"),"touch: tapping the arrow turns the page, no button ("..tostring(sawPage)..")")
  end

  -- ------------------------------------------------------------ MENU SPRITES VANILLA
  do
    opts.gen2MenuSpriteSource="vanilla"
    local s,game=open("withdraw")
    spriteCalls=0
    frame(s,game,"vanilla")
    opts.gen2MenuSpriteSource=nil
  end

  -- ------------------------------------------------------------ MODERN UI off
  do
    opts.gen2IntegratedModernUi=false
    local s,game=open("withdraw")
    local t=frame(s,game)
    check(rawget(mod,"_kimMenuClose")==nil,"MODERN UI off: no Modern window")
    check(chain("screen.render_visible",function()return true end,s)==true,"MODERN UI off: native BoxMenu renders")
    press(s,"down")
    check(s.index==2,"MODERN UI off: the native list's own DOWN")
    press(s,"a")
    check(s.phase=="submenu" and s.mode=="withdraw","MODERN UI off: native A")
    opts.gen2IntegratedModernUi=nil
    opts.pokemonUi=false
    local s2=open("deposit")
    press(s2,"down")
    check(s2.index==2,"MENU UI (pokemonUi) off: native list")
    opts.pokemonUi=nil
  end

  for _,p in ipairs(shots) do print("png",p) end
  if failures>0 then print(("box pc: %d FAILED"):format(failures));os.exit(1) end
  print("box pc: PASS")
  love.event.quit(0)
end
