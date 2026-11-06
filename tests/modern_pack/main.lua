-- gen2-aio 0.9.92: the redesigned Modern PACK (lib/crystal_aio/modern_pack.lua)
-- over the ENGINE's own PackMenu, Bag, ItemEffects and Mon.
--
--   AIO_ENGINE_SRC=/path/to/engine/src xvfb-run -a love tests/modern_pack
--
-- Rendered at the Fold's outer (1080x2520) and inner (2184x1968) screens and
-- a 1280x720 desktop window into AIO_TEST_OUTPUT. Checks: more rows than the
-- old layout, tab counts, SORT through Bag.move (persisted in save.bagOrder),
-- the detail panel (category / sell price / holders), the USE / GIVE / TOSS /
-- REGISTER buttons running the PACK's own submenu actions, the battle PACK's
-- buttons, the TM/HM learn strip and the medicine strip, and that nothing
-- overlaps the close button or the footer. Without an engine: SKIP.
io.stdout:setvbuf("no")
local root=love.filesystem.getSource():gsub("/tests/modern_pack/?$","").."/"
local output=os.getenv("AIO_TEST_OUTPUT") or os.getenv("TEMP") or "/tmp"
local engine=os.getenv("AIO_ENGINE_SRC")
function love.errorhandler(err) print(debug.traceback(tostring(err)));os.exit(1) end

local failures=0
local function check(cond,msg)
  if not cond then failures=failures+1;print("FAIL: "..msg) else print("ok   "..msg) end
end

function love.load()
  if not engine or engine=="" or not io.open(engine.."/src/ui/gen2/PackMenu.lua","rb") then
    print("modern pack: SKIP (set AIO_ENGINE_SRC to the engine's src root)")
    love.event.quit(0)
    return
  end
  package.path=engine.."/?.lua;"..package.path
  local function recorder(base)
    return setmetatable(base,{__index=function(_,k)
      return function(...)
        if k=="number" then return tostring((...)) end
        if k=="fitScale" then return 1 end
        if k=="fitOrigin" then return 0,0 end
      end
    end})
  end
  local classes={}
  local function class(name)
    local c={};c.__index=c;classes[name]=c
    package.preload[name]=function()return c end
  end
  -- the other screens the core menus module looks for (not under test)
  for _,n in ipairs({"src.ui.gen2.StartMenu","src.ui.gen2.Pokegear","src.ui.gen2.TrainerCard",
    "src.ui.gen2.SaveMenu","src.ui.gen2.OptionsMenu","src.ui.gen2.MainMenu","src.ui.gen2.TitleState",
    "src.ui.gen2.CenterPcMenu","src.ui.gen2.PcMenu","src.ui.gen2.BoxMenu","src.ui.gen2.EvolutionAnim",
    "src.ui.gen2.Typer","src.ui.Menu","src.ui.ListMenu","src.mods.ManagerState","src.core.gen2.Boxes",
    "src.world.gen2.FieldMoves"}) do class(n) end
  local screens={}
  local stubs={
    ["src.ui.gen2.Chrome"]=recorder({SCREEN_W=20,SCREEN_H=18}),
    ["src.render.Font"]=recorder({}),
    ["src.render.Assets"]={image=function()error("no assets in the test")end},
    ["src.core.GameVersion"]={get=function()return "crystal" end,engine=function()return "crystal" end,
      generation=function()return 2 end},
    ["src.render.GbcPalette"]={available=function()return false end},
    ["src.core.Sound"]={resolve=function(_,n)return n end,play=function()end,waitSfxDone=function()end,
      playCry=function()end,waitFramesFor=function()return 0 end,sfxBusy=function()return false end},
    ["src.mods.Runtime"]={call=function(_,base,...)return base(...)end,wants=function()return false end,
      wantsHook=function()return false end,emit=function()end},
    ["src.core.Logger"]={warn=function()end,info=function()end,error=function()end},
    ["src.core.Data"]={},
    ["src.core.gen2.Save"]={NUM_BOXES=14,MONS_PER_BOX=20,PARTY_SIZE=6,isFemale=function()return false end},
    ["src.ui.gen2.PackGfx"]={new=function()return {available=function()return false end} end},
    ["src.ui.Screens"]={
      get=function(_,name)return true end,
      build=function(game,name,opts)screens[#screens+1]={build=name,opts=opts};return {giveItem=function()end,say=function()end} end,
      push=function(game,name,opts)screens[#screens+1]={push=name,opts=opts};game.stack:push({screen=name,opts=opts});return true end},
  }
  for name,v in pairs(stubs) do package.preload[name]=function()return v end end
  local PackMenu=require("src.ui.gen2.PackMenu")
  local Bag=require("src.inventory.Bag")

  local G=love.graphics
  local dims={1080,2520}
  local os_="Android"
  G.getDimensions=function()return dims[1],dims[2] end
  love.system.getOS=function()return os_ end
  local function readFile(rel)
    local f=io.open(root..rel,"rb");if not f then return nil end
    local s=f:read("*a");f:close();return s
  end
  local hooks,opts={},{}
  local images={}
  local mod={exports={},path=root:gsub("/$",""),options={get=function(_,k)return opts[k]end},
    log={info=function()end,warn=function()end,error=function()end},
    read=function(_,rel)return readFile(rel)end,
    assets={image=function(_,path)
      if images[path]==nil then
        local bytes=readFile(path)
        images[path]=bytes and G.newImage(love.filesystem.newFileData(bytes,path)) or false
      end
      return images[path] or nil
    end},
    hooks={wrap=function(_,name,fn,priority)
      hooks[name]=hooks[name] or {};hooks[name][#hooks[name]+1]={fn=fn,p=priority or 0}
    end}}
  local DEX={TOTODILE=158,PIDGEY=16,MAREEP=179,GEODUDE=74,ONIX=95,HOOTHOOT=163}
  mod._kantoInMotionHdMenuIconForModernUi=function(_,mon)
    local d=DEX[mon.species]; return d and ("assets/menu_icons/hd/normal/%03d.png"):format(d) or nil
  end
  local function run(rel,...)
    return assert(loadstring(assert(readFile(rel)),"@"..rel))()(...)
  end
  run("lib/crystal_aio/font.lua",{mod=mod})
  local S=run("lib/gen2_modern_style.lua",mod)
  assert(run("lib/gen2_modern_core_menus.lua",mod),"core menus installed")
  local MP=run("lib/crystal_aio/modern_pack.lua",{mod=mod})
  check(type(MP)=="table" and rawget(mod,"_aioModernPack")==MP,"modern pack module installed")

  local draws={}
  local originalText=S.text
  S.text=function(value,font,x,y,w,align,c)
    draws[#draws+1]={text=tostring(value),font=font,x=x,y=y,w=w}
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

  -- ------------------------------------------------------------ the world
  local function item(id,t) t.id=id; t.name=t.name or id:gsub("_"," "); return t end
  local ITEMS={
    POTION=item("POTION",{description="Restores HP<NEXT>by 20 points.",pocket="ITEM",index=18,price=300,
      fieldMenu="ITEMMENU_PARTY",battleMenu="ITEMMENU_PARTY",canToss=true,canSelect=false,heldEffect="HELD_NONE"}),
    SUPER_POTION=item("SUPER_POTION",{description="Restores HP<NEXT>by 50 points.",pocket="ITEM",index=17,price=700,
      fieldMenu="ITEMMENU_PARTY",battleMenu="ITEMMENU_PARTY",canToss=true,heldEffect="HELD_NONE"}),
    PARLYZ_HEAL=item("PARLYZ_HEAL",{description="Heals paralysis.",pocket="ITEM",index=13,price=200,
      fieldMenu="ITEMMENU_PARTY",battleMenu="ITEMMENU_PARTY",canToss=true,heldEffect="HELD_NONE"}),
    REVIVE=item("REVIVE",{description="Restores a fainted<NEXT>#MON to 1/2 HP.",pocket="ITEM",index=27,price=1500,
      fieldMenu="ITEMMENU_PARTY",battleMenu="ITEMMENU_PARTY",canToss=true,heldEffect="HELD_NONE"}),
    ETHER=item("ETHER",{description="Restores PP of one<NEXT>move by 10.",pocket="ITEM",index=60,price=0,
      fieldMenu="ITEMMENU_PARTY",battleMenu="ITEMMENU_PARTY",canToss=true,heldEffect="HELD_NONE"}),
    X_ATTACK=item("X_ATTACK",{description="Raises ATTACK.<NEXT>(1 BTL)",pocket="ITEM",index=49,price=500,
      fieldMenu="ITEMMENU_NOUSE",battleMenu="ITEMMENU_CURRENT",canToss=true,heldEffect="HELD_NONE"}),
    LEFTOVERS=item("LEFTOVERS",{description="Restores HP during<NEXT>battle.",pocket="ITEM",index=146,price=200,
      fieldMenu="ITEMMENU_NOUSE",battleMenu="ITEMMENU_NOUSE",canToss=true,heldEffect="HELD_LEFTOVERS"}),
    BERRY=item("BERRY",{description="A self-restore<NEXT>item (10HP).",pocket="ITEM",index=173,price=20,
      fieldMenu="ITEMMENU_PARTY",battleMenu="ITEMMENU_PARTY",canToss=true,heldEffect="HELD_BERRY"}),
    REPEL=item("REPEL",{description="Repels weak #MON<NEXT>for 100 steps.",pocket="ITEM",index=30,price=350,
      fieldMenu="ITEMMENU_CURRENT",battleMenu="ITEMMENU_NOUSE",canToss=true,heldEffect="HELD_NONE"}),
    FLOWER_MAIL=item("FLOWER_MAIL",{description="Flower-print MAIL.",pocket="ITEM",index=158,price=50,
      fieldMenu="ITEMMENU_NOUSE",battleMenu="ITEMMENU_NOUSE",canToss=true,heldEffect="HELD_NONE"}),
    NUGGET=item("NUGGET",{description="Made of pure gold.<NEXT>Sell high.",pocket="ITEM",index=40,price=10000,
      fieldMenu="ITEMMENU_NOUSE",battleMenu="ITEMMENU_NOUSE",canToss=true,heldEffect="HELD_NONE"}),
    POKE_BALL=item("POKE_BALL",{name="POKé BALL",description="A tool for<NEXT>catching wild #MON.",pocket="BALL",index=5,price=200,
      fieldMenu="ITEMMENU_NOUSE",battleMenu="ITEMMENU_CLOSE",canToss=true,heldEffect="HELD_NONE"}),
    BICYCLE=item("BICYCLE",{description="A collapsible bike<NEXT>for fast movement.",pocket="KEY_ITEM",index=7,price=0,
      fieldMenu="ITEMMENU_CURRENT",battleMenu="ITEMMENU_NOUSE",canToss=false,canSelect=true,heldEffect="HELD_NONE"}),
    TM_DYNAMICPUNCH=item("TM_DYNAMICPUNCH",{name="TM01",tmLabel="TM01",tmNumber=1,teaches="DYNAMICPUNCH",pocket="TM_HM",
      index=191,price=3000,fieldMenu="ITEMMENU_PARTY",battleMenu="ITEMMENU_NOUSE",canToss=true,heldEffect="HELD_NONE"}),
    HM_SURF=item("HM_SURF",{name="HM03",tmLabel="HM03",tmNumber=53,teaches="SURF",pocket="TM_HM",
      index=245,price=0,fieldMenu="ITEMMENU_PARTY",battleMenu="ITEMMENU_NOUSE",canToss=false,heldEffect="HELD_NONE"}),
  }
  -- filler for a full ITEMS pocket
  local FILLER={}
  for i=1,12 do
    local id=("TREASURE_%02d"):format(i)
    ITEMS[id]=item(id,{description="Filler.",pocket="ITEM",index=200+i,price=100*i,
      fieldMenu="ITEMMENU_NOUSE",battleMenu="ITEMMENU_NOUSE",canToss=true,heldEffect="HELD_NONE"})
    FILLER[#FILLER+1]=id
  end
  local MOVES={
    DYNAMICPUNCH={name="DYNAMICPUNCH",pp=5,type="FIGHTING",power=100,accuracy=50,description="Powerful, but<NEXT>always confuses."},
    SURF={name="SURF",pp=15,type="WATER",power=95,accuracy=100,description="A strong WATER<NEXT>attack."},
    SCRATCH={name="SCRATCH",pp=35},TACKLE={name="TACKLE",pp=35},GUST={name="GUST",pp=35},
  }
  local POKEMON={
    TOTODILE={name="TOTODILE",tmhm={"DYNAMICPUNCH","SURF"}},
    PIDGEY={name="PIDGEY",tmhm={}},
    MAREEP={name="MAREEP",tmhm={"DYNAMICPUNCH"}},
    GEODUDE={name="GEODUDE",tmhm={"DYNAMICPUNCH"}},
    ONIX={name="ONIX",tmhm={}},
    HOOTHOOT={name="HOOTHOOT",tmhm={}},
  }
  local function mon(species,level,hp,maxHp,extra)
    local m={species=species,nickname=species,level=level,hp=hp,maxHp=maxHp,moves={{id="TACKLE",pp=35}},experience=0}
    for k,v in pairs(extra or {}) do m[k]=v end
    return m
  end
  local function newSave()
    local inv={POTION=5,SUPER_POTION=2,PARLYZ_HEAL=1,REVIVE=1,ETHER=3,X_ATTACK=2,LEFTOVERS=1,BERRY=4,
      REPEL=6,FLOWER_MAIL=1,NUGGET=2,POKE_BALL=10,BICYCLE=1,TM_DYNAMICPUNCH=1,HM_SURF=1}
    for i,id in ipairs(FILLER) do inv[id]=i end
    return {player={name="GOLD",money=3000,id=12345},
      party={mon("TOTODILE",14,40,44,{moves={{id="SCRATCH",pp=35},{id="SURF",pp=15}}}),
        mon("PIDGEY",9,0,27,{item="LEFTOVERS"}),
        mon("MAREEP",11,33,33,{status="par"}),
        mon("GEODUDE",12,30,30,{moves={{id="TACKLE",pp=20}},item="BERRY"}),
        mon("ONIX",13,10,40),
        mon("HOOTHOOT",8,24,24,{isEgg=true})},
      inventory=inv,registeredItem={id="BICYCLE"}}
  end
  local input={pressed={}}
  function input:wasPressed(b) return self.pressed[b] or false end
  function input:isDown() return false end
  local log={}
  local function newGame(save)
    local game={save=save,input=input,data={items=ITEMS,pokemon=POKEMON,moves=MOVES},stack={states={}}}
    function game.stack:top()return self.states[#self.states] end
    function game.stack:push(s)self.states[#self.states+1]=s end
    function game.stack:pop()self.states[#self.states]=nil end
    function game.stack:clear()self.states={} end
    game.world={
      useFieldItem=function(_,id) log[#log+1]="field:"..id; return nil end,
      registerItem=function(_,id) log[#log+1]="register:"..id; save.registeredItem={id=id}; return true end,
    }
    return game
  end
  local function press(s,btn) input.pressed={[btn]=true};s:update(1/60);input.pressed={} end
  -- spy the PACK's own action methods (the submenu's chooseSubmenu calls them)
  local function spy(s)
    for _,m in ipairs({"useSelected","giveItem","tossItem","registerSelected"}) do
      local orig=PackMenu[m]
      s[m]=function(self,...) log[#log+1]=m; return orig(self,...) end
    end
  end

  local shots={}
  local function frame(game,name)
    draws={}
    rawset(mod,"_kimScreenTapTargets",nil)
    local canvas=G.newCanvas(dims[1],dims[2])
    G.setCanvas(canvas);G.clear(.16,.27,.2,1)
    chain("render.hud",function()end,game,{})
    G.setCanvas()
    if name then
      local path=output.."/aio-pack-"..name.."-"..dims[1].."x"..dims[2]..".png"
      local f=assert(io.open(path,"wb"))
      f:write(canvas:newImageData():encode("png"):getString());f:close()
      shots[#shots+1]=path
    end
    canvas:release()
    return rawget(mod,"_kimScreenTapTargets"),rawget(mod,"_kimMenuClose")
  end
  local function cells(t,kind,action)
    local out={}
    for _,c in ipairs(t and t.cells or {}) do
      if c.kind==kind and (action==nil or c.action==action) then out[#out+1]=c end
    end
    return out
  end
  -- a cell the way KIM Touch fires it (touch/main.lua packAction): select,
  -- then the button unless select answered false
  local function fire(s,c)
    assert(c,"no cell")
    local go=true
    if type(c.select)=="function" then go=c.select(s) end
    if go~=false and c.button then press(s,c.button) end
  end
  local function drew(label)
    for _,d in ipairs(draws) do if d.text==label then return true end end
    return false
  end
  local function drewLike(pat)
    for _,d in ipairs(draws) do if d.text:find(pat) then return true end end
    return false
  end
  local function layout(tag,t,close)
    local all=t and t.cells or {}
    local foot=MP._footerY
    local bad,overlap,below=0,0,0
    for i,a in ipairs(all) do
      if a.x<0 or a.y<0 or a.x+a.w>dims[1]+.5 or a.y+a.h>dims[2]+.5 then bad=bad+1 end
      for j=i+1,#all do
        local b=all[j]
        if a.x<b.x+b.w-.5 and b.x<a.x+a.w-.5 and a.y<b.y+b.h-.5 and b.y<a.y+a.h-.5 then overlap=overlap+1 end
      end
      if close and a.x<close.x+close.w and close.x<a.x+a.w and a.y<close.y+close.h and close.y<a.y+a.h then bad=bad+1 end
      if foot and a.y+a.h>foot+.5 then below=below+1 end
    end
    check(close~=nil,tag..": close button drawn")
    check(bad==0,tag..": "..#all.." cells on screen and clear of the close button")
    check(overlap==0,tag..": no two cells overlap")
    check(below==0,tag..": nothing reaches into the footer")
    local out=0
    for _,d in ipairs(draws) do
      if d.font and (d.x<0 or d.y<0 or d.y+d.font:getHeight()>dims[2]+1) then out=out+1 end
    end
    check(out==0,tag..": text on screen")
  end

  local SIZES={{1080,2520,"Android"},{2184,1968,"Android"},{1280,720,"Linux"}}
  for _,d in ipairs(SIZES) do
    dims={d[1],d[2]}; os_=d[3]
    local sz=dims[1].."x"..dims[2]
    opts.gen2UiTheme=nil

    -- ------------------------------------------------ rows: old vs new
    do
      local save=newSave();local game=newGame(save)
      local s=PackMenu.new(game,{save=save,items=ITEMS,onClose=function()end})
      game.stack:push(s)
      rawset(mod,"_aioModernPack",nil)
      local t=frame(game,"old")
      local old=#cells(t,"pack")
      rawset(mod,"_aioModernPack",MP)
      for i,r in ipairs(s.rows) do if r.id=="POTION" then s.index=i end end
      t=frame(game,"items")
      local new=#cells(t,"pack")
      check(new>=math.floor(old*1.6),sz..": rows on screen "..old.." -> "..new.." (about twice)")
      check((MP._scrollBar~=nil)==(#s.rows+1>MP._visible),sz..": a scroll bar exactly when the pocket overflows ("..(#s.rows+1).." rows, "..MP._visible.." visible)")
      local counts=MP.pocketCounts(s)
      check(counts[1]==23 and counts[2]==1 and counts[3]==1 and counts[4]==2,sz..": pocket counts 23/1/1/2")
      check(drew("23") and drew("2"),sz..": tabs draw their counts")
      check(drew("x5"),sz..": POTION's quantity pill x5")
      check(drew("MEDICINE"),sz..": POTION is MEDICINE")
      check(drew("SELLS FOR ¥150"),sz..": POTION sells for half (¥150)")
      check(drew("WOULD HELP"),sz..": POTION strip caption")
      local comp=MP._compat
      check(comp and comp.mode=="help" and comp.marks[1]=="help" and comp.marks[2]=="none"
        and comp.marks[3]=="none" and comp.marks[5]=="help" and comp.marks[6]=="egg",
        sz..": POTION helps TOTODILE + ONIX (below full HP), not the fainted PIDGEY / full MAREEP / the EGG")
      local labels={}
      for _,b in ipairs(MP._buttons or {}) do labels[#labels+1]=b.id end
      check(table.concat(labels,",")=="use,give,toss",sz..": POTION buttons USE / GIVE / TOSS (its submenu)")
      local close=rawget(mod,"_kimMenuClose")
      layout(sz.." items",t,close)

      -- tabs: tap KEY ITEMS
      local tabs=cells(t,"pocket")
      check(#tabs==4,sz..": four pocket tab cells")
      s:switchPocket(2)
      t=frame(game,"key")
      check(drew("KEY"),sz..": BICYCLE tagged KEY")
      check(drew("SEL"),sz..": the registered BICYCLE wears SEL")
      check(drew("CAN'T SELL"),sz..": BICYCLE can't be sold")
      labels={}
      for _,b in ipairs(MP._buttons or {}) do labels[#labels+1]=b.id end
      check(table.concat(labels,",")=="use,sel",sz..": BICYCLE: USE / REGISTER, no TOSS")
      layout(sz.." key items",t,rawget(mod,"_kimMenuClose"))

      -- TM/HM: the learn strip
      s:switchPocket(1)
      t=frame(game,"tmhm")
      check(MP._sortRect==nil and #cells(t,"packAction","sort")==0,sz..": no SORT in the TM/HM pocket (cart order)")
      comp=MP._compat
      check(comp and comp.mode=="learn" and comp.marks[1]=="yes" and comp.marks[2]=="no" and comp.marks[3]=="yes"
        and comp.marks[4]=="yes" and comp.marks[5]=="no" and comp.marks[6]=="egg",
        sz..": TM01 DYNAMICPUNCH: TOTODILE/MAREEP/GEODUDE yes, PIDGEY/ONIX no, EGG")
      check(drew("TM") and drew("DYNAMICPUNCH") and drew("CAN LEARN"),sz..": TM tag, move name, CAN LEARN")
      check(drew("SELLS FOR ¥1500"),sz..": TM01 sells for ¥1500")
      s.index=2
      frame(game,"hm")
      comp=MP._compat
      check(comp.marks[1]=="knows" and comp.marks[2]=="no",sz..": HM03 SURF: TOTODILE already knows it")
      check(drew("HM"),sz..": HM tag")
      labels={}
      for _,b in ipairs(MP._buttons or {}) do labels[#labels+1]=b.id end
      check(table.concat(labels,",")=="use",sz..": HM: USE only (no GIVE/TOSS)")
    end

    -- --------------------------------------------- strips and categories
    do
      local save=newSave();local game=newGame(save)
      local s=PackMenu.new(game,{save=save,items=ITEMS,onClose=function()end})
      game.stack:push(s)
      local function on(id) for i,r in ipairs(s.rows) do if r.id==id then s.index=i end end end
      on("PARLYZ_HEAL"); frame(game)
      local comp=MP._compat
      check(comp.marks[3]=="help" and comp.marks[1]=="none",sz..": PARLYZ HEAL helps the paralyzed MAREEP only")
      on("REVIVE"); frame(game)
      comp=MP._compat
      check(comp.marks[2]=="help" and comp.marks[1]=="none",sz..": REVIVE helps the fainted PIDGEY only")
      on("ETHER"); frame(game)
      comp=MP._compat
      check(comp.marks[4]=="help" and comp.marks[1]=="none",sz..": ETHER helps GEODUDE (TACKLE 20/35 PP)")
      check(drew("CAN'T SELL"),sz..": ETHER (no price) can't be sold")
      on("LEFTOVERS"); frame(game,"leftovers")
      comp=MP._compat
      check(comp.mode=="hold" and comp.marks[2]=="held" and drew("HOLD") and drew("HOLDING"),
        sz..": LEFTOVERS: HOLD tag, PIDGEY holding it")
      on("BERRY"); frame(game,"berry")
      check(drew("BERRY") and drew("HELD BY GEODUDE"),sz..": BERRY tag and HELD BY GEODUDE")
      on("X_ATTACK"); frame(game)
      check(drew("BATTLE"),sz..": X ATTACK is BATTLE")
      on("FLOWER_MAIL"); frame(game)
      check(drew("MAIL"),sz..": FLOWER MAIL is MAIL")
      on("NUGGET"); frame(game)
      check(drew("OTHER") and drew("SELLS FOR ¥5000"),sz..": NUGGET is OTHER, sells for ¥5000")
      s:switchPocket(1); frame(game)
      check(drew("BALL"),sz..": POKe BALL is BALL")
    end

    -- ---------------------------------------------------------- SORT
    do
      local save=newSave();local game=newGame(save)
      local s=PackMenu.new(game,{save=save,items=ITEMS,onClose=function()end})
      game.stack:push(s)
      local before={}
      for i,r in ipairs(s.rows) do before[i]=r.id end
      s.index=3
      local was=s.rows[3].id
      local t=frame(game)
      local sc=cells(t,"packAction","sort")[1]
      check(sc~=nil and sc.button==false,sz..": a SORT cell (no button press)")
      fire(s,sc)
      local names={}
      for i,r in ipairs(s.rows) do names[i]=r.name:upper() end
      local sorted=true
      for i=2,#names do if names[i-1]>names[i] then sorted=false end end
      check(sorted,sz..": SORT A-Z orders the ITEMS pocket by name")
      check(s.rows[s.index].id==was,sz..": the cursor stays on "..was)
      -- persisted: a fresh PACK over the same save shows the same order
      local s2=PackMenu.new(game,{save=save,items=ITEMS})
      local same=true
      for i,r in ipairs(s2.rows) do if r.id~=s.rows[i].id then same=false end end
      check(same,sz..": the order lives in save.bagOrder (a new PACK sees it)")
      -- the other pockets keep their own order
      local key=PackMenu.new(game,{save=save,items=ITEMS,pocket="KEY_ITEM"})
      check(key.rows[1].id=="BICYCLE",sz..": KEY ITEMS untouched")
      -- TYPE: START cycles it (the modern PACK's keyboard SORT)
      t=frame(game,"sorted-az")
      press(s,"start")
      check(MP.lastSort.ITEM=="type",sz..": START: SORT TYPE")
      local rank=MP.CAT_RANK
      local ok=true
      for i=2,#s.rows do
        local a=rank[MP.category(s.rows[i-1].id,ITEMS[s.rows[i-1].id],game.data)]
        local b=rank[MP.category(s.rows[i].id,ITEMS[s.rows[i].id],game.data)]
        if a>b then ok=false end
      end
      check(ok,sz..": SORT TYPE groups by category (MEDICINE first)")
      check(s.rows[1].id=="ETHER" or MP.category(s.rows[1].id,ITEMS[s.rows[1].id],game.data)=="MEDICINE",sz..": a MEDICINE item first")
      press(s,"start")
      check(MP.lastSort.ITEM=="count",sz..": START again: SORT COUNT")
      ok=true
      for i=2,#s.rows do if s.rows[i-1].count<s.rows[i].count then ok=false end end
      check(ok,sz..": SORT COUNT orders by quantity (most first)")
      frame(game,"sorted-count")
      -- SELECT still moves an item the cart's way
      s.index=1
      local first=s.rows[1].id
      press(s,"select")
      check(s.switching==1,sz..": SELECT arms the native item move")
      press(s,"down");press(s,"a")
      check(s.rows[2].id==first,sz..": ...and places it (Bag.move)")
      while s.message do press(s,"a") end
      MP.lastSort.ITEM=nil
    end

    -- ------------------------------------------- buttons = native submenu
    do
      local save=newSave();local game=newGame(save)
      local chosen={}
      local s=PackMenu.new(game,{save=save,items=ITEMS,onClose=function()end,
        onChoose=function(id,n) chosen[#chosen+1]=id end})
      game.stack:push(s); spy(s)
      local function on(id) for i,r in ipairs(s.rows) do if r.id==id then s.index=i end end end
      on("POTION")
      local t=frame(game)
      log={}
      fire(s,cells(t,"packAction","use")[1])
      check(log[1]=="useSelected" and log[2]=="field:POTION" and chosen[1]=="POTION",
        sz..": USE: the submenu's useSelected -> World:useFieldItem -> onChoose (party pick)")
      check(s.submenu==nil,sz..": the submenu is closed again")
      s.staleRows=nil
      on("POTION"); t=frame(game)
      log={}
      fire(s,cells(t,"packAction","give")[1])
      check(log[1]=="giveItem" and screens[#screens].push=="Gen2PartyMenu",sz..": GIVE: giveItem -> the party list (To which?)")
      game.stack:pop()
      on("POTION"); t=frame(game)
      log={}
      fire(s,cells(t,"packAction","toss")[1])
      check(log[1]=="tossItem" and s.qtyState and s.qtyState.max==5,sz..": TOSS: tossItem -> HOW MANY (max 5)")
      frame(game,"toss-qty")
      press(s,"up");press(s,"a")
      check(s.confirm~=nil,sz..": ... YES/NO")
      press(s,"a")
      check(save.inventory.POTION==3,sz..": TOSS x2 through the engine (5 -> 3)")
      while s.message do press(s,"a") end
      -- REGISTER on a key item
      s:switchPocket(2); t=frame(game)
      log={}
      fire(s,cells(t,"packAction","sel")[1])
      check(log[1]=="registerSelected" and log[2]=="register:BICYCLE",sz..": REGISTER: registerSelected -> World:registerItem")
      while s.message do press(s,"a") end
      -- a button that is not offered does nothing
      t=frame(game)
      check(#cells(t,"packAction","toss")==0,sz..": no TOSS button on a key item")
      check(MP.prepareAction(s,"toss")==false and s.submenu==nil,sz..": TOSS refused on a key item (not in its submenu)")
      -- busy: no buttons while the submenu is open
      s:openSubmenu(); t=frame(game,"submenu")
      check(#cells(t,"packAction")==0,sz..": no action cells while the native submenu is open")
      check(#cells(t,"modal")>0,sz..": the submenu's own rows are tappable")
      s:closeSubmenu()
    end

    -- --------------------------------------------------- the battle PACK
    do
      local save=newSave();local game=newGame(save)
      local chosen={}
      local s=PackMenu.new(game,{save=save,items=ITEMS,battle=true,onClose=function()end,
        onChoose=function(id) chosen[#chosen+1]=id end})
      game.stack:push(s); spy(s)
      local t=frame(game,"battle")
      local labels={}
      for _,b in ipairs(MP._buttons or {}) do labels[#labels+1]=b.id end
      check(table.concat(labels,",")=="use",sz..": battle PACK: USE only")
      log={}
      fire(s,cells(t,"packAction","use")[1])
      check(log[1]=="useSelected" and chosen[1]==s.rows[s.index].id,sz..": battle USE -> the battle's onChoose")
      s.staleRows=nil
      for i,r in ipairs(s.rows) do if r.id=="LEFTOVERS" then s.index=i end end
      t=frame(game,"battle-nouse")
      check(#cells(t,"packAction")<=1 and #cells(t,"packAction","use")==0,sz..": battle PACK: no USE for LEFTOVERS")
      check(drew("CAN'T USE THIS IN BATTLE"),sz..": ... says so")
      s:switchPocket(-1); t=frame(game)
      check(#cells(t,"packAction","use")==0,sz..": battle PACK: no USE in TM/HM")
      layout(sz.." battle",t,rawget(mod,"_kimMenuClose"))
    end

    -- ------------------------------------------- a chooser (DEPOSIT/GIVE)
    do
      local save=newSave();local game=newGame(save)
      local chosen={}
      local s=PackMenu.new(game,{save=save,items=ITEMS,give=true,onClose=function()end,
        onChoose=function(id) chosen[#chosen+1]=id end})
      game.stack:push(s)
      local t=frame(game)
      local c=cells(t,"packAction","choose")[1]
      check(c~=nil,sz..": a chooser PACK shows CHOOSE")
      fire(s,c)
      check(chosen[1]==s.rows[s.index].id,sz..": CHOOSE is the chooser's A (onChoose)")
    end

    -- ------------------------------------------------ the light theme
    do
      mod._kantoInMotionGen2Themes={default=S.theme(),light={
        surface={.97,.97,.95,.98},raised={.90,.91,.88,1},selected={.72,.86,.66,1},accent={.22,.45,.20,1},
        frame={.30,.56,.26,1},frameShadow={.1,.12,.15,.35},text={.13,.13,.16,1},muted={.30,.34,.30,1},
        divider={.35,.55,.32,.9}}}
      opts.gen2UiTheme="light"
      local save=newSave();local game=newGame(save)
      local s=PackMenu.new(game,{save=save,items=ITEMS,pocket="TM_HM"})
      game.stack:push(s)
      local t=frame(game,"light-tmhm")
      layout(sz.." light theme",t,rawget(mod,"_kimMenuClose"))
      opts.gen2UiTheme=nil
      mod._kantoInMotionGen2Themes=nil
    end

    -- --------------------------------------- MODERN UI off: native PACK
    do
      opts.gen2IntegratedModernUi=false
      local save=newSave();local game=newGame(save)
      local s=PackMenu.new(game,{save=save,items=ITEMS})
      game.stack:push(s)
      local before=#s.rows
      press(s,"start")
      check(MP.lastSort.ITEM==nil and #s.rows==before,sz..": MODERN UI off: START does not sort")
      local t=frame(game)
      check(t==nil or t.state~=s,sz..": MODERN UI off: no modern pack drawn")
      opts.gen2IntegratedModernUi=nil
    end
  end

  print("renders:")
  for _,p in ipairs(shots) do print("  "..p) end
  print(failures==0 and "modern pack: ALL OK" or ("modern pack: "..failures.." FAILURE(S)"))
  love.event.quit(failures==0 and 0 or 1)
end
