-- Menu chrome: the shared footer and the top-right close button of every full
-- Modern menu window, rendered headless at the Fold's two screen sizes, plus
-- the KIM Touch path (a tap on the close button is exactly one B).
--
--   xvfb-run -a love tests/menu_chrome
--
-- AIO_TEST_OUTPUT: where the PNGs go (default TEMP or /tmp).
-- AIO_ROOT / AIO_RENDER_ONLY=1 / AIO_TAG: render another tree's UI files
-- (e.g. an extracted older commit) without the chrome assertions.
io.stdout:setvbuf("no")
local root=(os.getenv("AIO_ROOT") or love.filesystem.getSource():gsub("/tests/menu_chrome/?$","")):gsub("/?$","/")
local output=os.getenv("AIO_TEST_OUTPUT") or os.getenv("TEMP") or "/tmp"
local tag=os.getenv("AIO_TAG") or "chrome"
local renderOnly=os.getenv("AIO_RENDER_ONLY")=="1"

local classes={}
local function class(name)
  local c={};c.__index=c;classes[name]=c
  package.preload[name]=function()return c end
  return c
end
for _,name in ipairs({"src.render.TextBox","src.ui.ChoiceBox","src.ui.gen2.MartMenu",
  "src.ui.gen2.StartMenu","src.ui.gen2.PackMenu","src.ui.gen2.TrainerCard","src.ui.gen2.SaveMenu",
  "src.ui.gen2.OptionsMenu","src.ui.gen2.Pokegear","src.ui.gen2.PartyMenu","src.ui.gen2.SummaryMenu",
  "src.ui.gen2.PokedexMenu","src.ui.gen2.HeldItemMenu","src.ui.gen2.InitClock"}) do class(name) end
package.preload["src.ui.gen2.Chrome"]=function()return {} end
local Typer={text=function(s,page)return page end,typing=function(s)return s.typing==true end}
package.preload["src.ui.gen2.Typer"]=function()return Typer end
package.preload["src.core.TouchControls"]=function()return {active=true,layout=function()return {} end} end
package.preload["src.core.TouchSkin"]=function()return {active=false} end

local failures=0
local function check(cond,msg)
  if renderOnly then return end
  if not cond then failures=failures+1;print("FAIL: "..msg) else print("ok   "..msg) end
end

function love.errorhandler(err) print(debug.traceback(tostring(err)));os.exit(1) end
function love.load()
  local G=love.graphics
  local dims={1080,2520}
  G.getDimensions=function()return dims[1],dims[2] end
  love.system.getOS=function()return "Android" end   -- the Fold's phone layouts
  local function readFile(rel)
    local f=io.open(root..rel,"rb");if not f then return nil,"missing "..rel end
    local s=f:read("*a");f:close();return s
  end
  local hooks,opts={},{}
  local images={}
  local mod={exports={},path=root:gsub("/$",""),options={get=function(_,k)return opts[k]end},
    log={info=function()end,warn=function(_,...)print("warn",...)end,error=function(_,...)print("error",...)end},
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
  local function run(rel,...)
    local chunk=assert(loadstring(assert(readFile(rel)),"@"..rel))
    return chunk()(...)
  end
  run("lib/gen2_aio/font.lua",{mod=mod})
  local S=run("lib/gen2_modern_style.lua",mod)
  run("lib/gen2_modern_dialog_ui.lua",mod)
  assert(run("lib/gen2_modern_core_menus.lua",mod))
  assert(run("lib/gen2_modern_party_ui.lua",mod))
  assert(run("lib/gen2_modern_summary_ui.lua",mod))
  local dexOk=run("lib/gen2_modern_pokedex_ui.lua",mod)
  run("lib/gen2_aio/modern_pages.lua",{mod=mod})
  local Quick=run("lib/gen2_aio/quick_menu.lua",{mod=mod})
  mod.exports.menuCloseRect=function()return rawget(mod,"_kimMenuClose")end

  -- record every text the screens draw (footer checks)
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
  local function gameFor(state,below)
    local states={}
    for _,s in ipairs(below or {}) do states[#states+1]=s end
    states[#states+1]=state
    local game={data={},stack={states=states}}
    function game.stack:top()return self.states[#self.states] end
    function game.stack:push(s)self.states[#self.states+1]=s end
    function game.stack:pop()self.states[#self.states]=nil end
    return game
  end
  local shots={}
  local function frame(state,name,below)
    draws={}
    local game=type(state)=="table" and state.__game or gameFor(state,below)
    local canvas=G.newCanvas(dims[1],dims[2])
    G.setCanvas(canvas);G.clear(.16,.27,.2,1)
    chain("render.hud",function()end,game,{})
    G.setCanvas()
    local path=output.."/aio-"..tag.."-"..name.."-"..dims[1].."x"..dims[2]..".png"
    local file=assert(io.open(path,"wb"))
    file:write(canvas:newImageData():encode("png"):getString());file:close();canvas:release()
    shots[#shots+1]=path
    return draws,game
  end

  -- ------------------------------------------------------------ screens
  local mons={
    {species="TOTODILE",nickname="TOTODILE",level=14,hp=40,maxHp=44,moves={{id="SCRATCH",pp=30}}},
    {species="PIDGEY",nickname="PIDGEY",level=9,hp=0,maxHp=27,moves={}},
    {species="MAREEP",nickname="MAREEP",level=11,hp=30,maxHp=33,moves={}},
  }
  local Party=classes["src.ui.gen2.PartyMenu"]
  function Party:shownHpFor(i,mon)return mon.hp end
  function Party:isCancel()return self.index==#self.party+1 end
  local Summary=classes["src.ui.gen2.SummaryMenu"]
  Summary.GREEN_PAGE=2;Summary.BLUE_PAGE=3
  local Opt=classes["src.ui.gen2.OptionsMenu"]
  local Mart=classes["src.ui.gen2.MartMenu"]
  local function value(v)return function()return v end end
  local screens={
    {"party",function()return setmetatable({party=mons,index=1,game={data={}}},Party)end},
    {"party-cancel",function()return setmetatable({party=mons,index=4,game={data={}}},Party)end},
    {"pack",function()return setmetatable({pocketIndex=1,index=1,scroll=0,
      rows={{id="POTION",name="POTION",count=3,showCount=true},{id="ANTIDOTE",name="ANTIDOTE",count=1,showCount=true},
        {id="ESCAPE_ROPE",name="ESCAPE ROPE",count=2,showCount=true}},
      items={POTION={description="Restores HP<NEXT>by 20 points."}}},classes["src.ui.gen2.PackMenu"])end},
    {"card",function()return setmetatable({page=1,save={player={name="STEVEN",id=12345,money=4820,
      badges={ZEPHYR=true,HIVE=true}},pokedex={caught={}},playTime={hours=12,minutes=7}}},classes["src.ui.gen2.TrainerCard"])end},
    {"gear",function()return setmetatable({cards={{id="clock",label="CLOCK"},{id="map",label="MAP"},
      {id="phone",label="PHONE"},{id="radio",label="RADIO"}},cardIndex=1,mode="strip",
      clockParts=function()return 14,5,2 end},classes["src.ui.gen2.Pokegear"])end},
    {"gear-phone",function()return setmetatable({cards={{id="clock",label="CLOCK"},{id="map",label="MAP"},
      {id="phone",label="PHONE"},{id="radio",label="RADIO"}},cardIndex=3,mode="card",phoneCursor=0,
      phoneList=function()return {1,2}end,contactRow=function(_,v)return v==1 and "MOM:" or "JOEY:",v==1 and "" or "YOUNGSTER" end},
      classes["src.ui.gen2.Pokegear"])end},
    {"options",function()return setmetatable({title="SETTINGS",kimSubtitle="UI",index=2,scroll=0,rows={
      {label="TEXT SPEED",text=value("FAST")},{label="BATTLE SCENE",text=value("ON")},
      {label="UI THEME",text=value("DEFAULT")},{label="FONT SCALE",text=value("100%")},
      {label="QUICK MENU",group=true},{label="CANCEL",cancel=true}}},Opt)end},
    -- 0.9.66: hub pages show the selected row's help above the footer
    {"options-help",function()return setmetatable({title="QUALITY OF LIFE",kimSubtitle="CATEGORY",index=2,scroll=0,rows={
      {label="SPRINT",text=value("ON"),help="Run faster on foot while you hold the sprint button."},
      {label="REPELS",text=value("ASK"),help="When a REPEL wears off. ASK: offer to use another. AUTO: use the next one from your bag by itself. INFINITE: a used REPEL never wears off (bends Nuzlocke rules). OFF: Crystal's own message only."},
      {label="QUICK NURSE",text=value("OFF"),help="Skip the nurse's speech. Bends Nuzlocke rules."},
      {label="BACK",cancel=true}}},Opt)end},
    -- 0.9.67: the setup wizard's first page
    {"wizard",function()return setmetatable({title="SETUP WIZARD",kimSubtitle="NEW GAME",index=1,scroll=0,rows={
      {label="RECOMMENDED",group=true,value=value("SUGGESTED"),help="The way Gen2-AIO is meant to be played: fair trainers, no Nuzlocke, HD battles, the 3D world, visible wild Pokemon and the standard conveniences."},
      {label="CASUAL",group=true,help="Relaxed: easier trainers, more EXP and every convenience."},
      {label="NUZLOCKE",group=true,help="A classic Nuzlocke run."},
      {label="HARDCORE NUZLOCKE",group=true,help="HARD trainers and HARDCORE rules."},
      {label="CLASSIC CRYSTAL",group=true,help="As close to the cartridge as it gets."},
      {label="STEP BY STEP",group=true,help="Choose each part yourself."},
      {label="SKIP",group=true,help="Start with the settings as they are."},
      {label="BACK",cancel=true}}},Opt)end},
    -- 0.9.68: NEW GAME clock; "DAY 12 o'clock" wrapped onto the arrows
    {"clock",function()return setmetatable({phase="hour",mode="clock",
      question=function()return "What time is it?" end,
      display=function()return "DAY 12 o'clock" end},classes["src.ui.gen2.InitClock"])end},
    {"quick",function()return setmetatable({title="QUICK MENU",kimSubtitle="HOLD START",index=1,scroll=0,rows={
      {label="POKeGEAR",group=true},{label="FLY",group=true},{label="AREA DEX",group=true},
      {label="DAY-CARE",group=true},{label="TODAY",group=true},{label="QUICK HEAL",group=true}}},Opt)end},
    {"mart",function()return setmetatable({phase="buy",index=1,entries={{name="POKé BALL",price=200},
      {name="ESCAPE ROPE",price=550},{name="PARLYZ HEAL",price=200}},
      selected=function(s)return s.entries[s.index]end,description=function()return "Escape from a cave.<NEXT>Useful on a long journey."end,
      money=function()return 12345 end},Mart)end},
    {"summary",function()return setmetatable({mon=mons[1],page=1,pokemon={}},Summary)end},
    {"start",function()return setmetatable({items={{label="POKéDEX",desc={"Pokemon","database"}},{label="POKéMON"},
      {label="PACK"},{label="POKéGEAR",value="pokegear"},{label="STEVEN"},{label="SAVE"},{label="OPTION"},{label="EXIT"}},
      list={index=2,rows=8,scroll=0}},classes["src.ui.gen2.StartMenu"])end},
    {"nuzlocke",function()
      local page={cursor=1}
      function page:_aioModernData()return {title="NUZLOCKE SETUP",selected=self.cursor,
        rows={{label="LEVEL CAP",value="GYMS",select=function()end},{label="RULES LOCKED",value="OFF"}},
        help="These settings belong to the new game.",footer="A CHOOSE   SELECT HELP   B BACK"}end
      return page end},
    {"areadex",function()
      local game=gameFor({})
      game.stack.states={}
      Quick.openAreaDex(game)
      local s=game.stack:top()
      s.__game=game
      s.title="ROUTE 29"
      s.sections={{title="GRASS (DAY)",mons={{species="PIDGEY",lo=2,hi=4,pct=55},{species="SENTRET",lo=2,hi=3,pct=40},
        {species="HOOTHOOT",lo=3,hi=3,pct=5}}}}
      return s end},
  }
  if dexOk then
    local function dexRows()
      return {{species="CHIKORITA",dex=1,seen=true,caught=true},{species="BAYLEEF",dex=2,seen=true},
        {species="MEGANIUM",dex=3},{species="CYNDAQUIL",dex=4,seen=true,caught=true}}
    end
    screens[#screens+1]={"pokedex",function()return setmetatable({view="list",index=1,rows=dexRows(),game={data={}}},classes["src.ui.gen2.PokedexMenu"])end}
    screens[#screens+1]={"pokedex-entry",function()return setmetatable({view="entry",index=1,rows=dexRows(),game={data={}}},classes["src.ui.gen2.PokedexMenu"])end}
  end

  local results={}
  for _,d in ipairs({{1080,2520},{2184,1968}}) do
    dims=d
    for _,sc in ipairs(screens) do
      local state=sc[2]()
      local drawn=frame(state,sc[1])
      local close=rawget(mod,"_kimMenuClose")
      results[sc[1]..dims[1]]={draws=drawn,close=close,state=state}
      if not renderOnly then
        if sc[1]=="nuzlocke" or sc[1]=="pokedex" then
          -- pages without footer assertions of their own below
        end
        if sc[1]=="clock" then
          -- not a menu window: no close button; the hour reads on one line,
          -- clear of the footer below it
          check(close==nil,"clock "..dims[1].." has no close button")
          local value,footer
          for _,d in ipairs(drawn) do
            if d.text=="DAY 12 o'clock" then value=d end
            if tostring(d.text):find("UP/DOWN",1,true) then footer=d end
          end
          check(value and footer,"clock "..dims[1].." draws the hour and the footer")
          if value and footer then
            check(value.font:getWidth(value.text)<=(value.w or 1e9)+1,"clock "..dims[1].." hour fits on one line")
            check(value.y+value.font:getHeight()<=footer.y,"clock "..dims[1].." hour clear of the footer")
          end
        else
        check(close and close.state==state,sc[1].." "..dims[1].." publishes a close button")
        end
        if close and sc[1]~="clock" then
          -- clear of every text on the window
          for _,t in ipairs(drawn) do
            local f=t.font
            if f and t.text~="" then
              local tw=t.w and (t.align=="right" and t.w or math.min(t.w,f:getWidth(t.text))) or f:getWidth(t.text)
              local tx=t.x
              if t.align=="right" and t.w then tx=t.x+t.w-math.min(t.w,f:getWidth(t.text)) end
              if t.align=="center" and t.w then tx=t.x+(t.w-math.min(t.w,f:getWidth(t.text)))/2 end
              local th=f:getHeight()
              local overlap=tx<close.x+close.w and tx+math.min(tw,f:getWidth(t.text))>close.x
                and t.y<close.y+close.h and t.y+th>close.y
              check(not overlap,sc[1].." "..dims[1].." close button clear of '"..t.text.."'")
            end
          end
        end
      end
    end
  end

  if not renderOnly then
    -- one footer: same font height and the same distance from the window's
    -- bottom edge on each screen (party, pack, card, gear, options, mart, area dex)
    local function footerOf(name,w)
      local r=results[name..w]
      local last
      for _,t in ipairs(r.draws) do if t.text=="BACK" and (not last or t.y>=last.y) then last=t end end
      return last
    end
    for _,w in ipairs({1080,2184}) do
      local ref
      for _,name in ipairs({"party","pack","card","gear","options","quick","mart","areadex","summary","nuzlocke"}) do
        local b=footerOf(name,w)
        check(b~=nil,name.." "..w.." footer ends in B BACK")
        if b then
          local close=results[name..w].close
          if ref then check(math.abs(b.font:getHeight()-ref.font:getHeight())<0.5,name.." "..w.." footer font matches") end
          ref=ref or b
        end
      end
    end
    for _,w in ipairs({1080,2184}) do
      for _,name in ipairs({"party","pack","card","gear","options","mart","areadex"}) do
        for _,t in ipairs(results[name..w].draws) do
          check(not (t.text:find("B/START") or t.text:find("RETURN") or t.text:find("TAP / B")),
            name.." "..w.." no old hint wording ("..t.text..")")
        end
      end
    end

    -- not on a dialogue box or a YES/NO prompt
    dims={1080,2520}
    -- 0.9.63: back arrow when B steps back inside the same screen, X when
    -- B closes it (tapping is B either way)
    do
      local S=mod._kantoInMotionGen2Ui
      local function back(st,below)
        local g={stack={states=below and {below,st} or {st}}}
        return S.closeIsBack(g,st)
      end
      local P,K,M=classes["src.ui.gen2.PartyMenu"],classes["src.ui.gen2.PackMenu"],classes["src.ui.gen2.MartMenu"]
      local D,Gr,O=classes["src.ui.gen2.PokedexMenu"],classes["src.ui.gen2.Pokegear"],classes["src.ui.gen2.OptionsMenu"]
      check(not back(setmetatable({},P)),"party list shows X")
      check(back(setmetatable({submenu={}},P)),"party popup shows back")
      check(back(setmetatable({},classes["src.ui.gen2.HeldItemMenu"])),"GIVE / TAKE shows back")
      check(not back(setmetatable({},K)),"pack list shows X")
      check(back(setmetatable({qtyState={}},K)),"pack quantity shows back")
      check(not back(setmetatable({phase="top"},M)),"mart BUY/SELL/QUIT shows X")
      check(back(setmetatable({phase="buy"},M)) and back(setmetatable({phase="sellQuantity"},M)),"mart lists show back")
      check(not back(setmetatable({view="list"},D)) and back(setmetatable({view="entry"},D)),"pokedex list X, entry back")
      check(not back(setmetatable({mode="strip"},Gr)) and back(setmetatable({mode="card"},Gr)),"pokegear strip X, card back")
      check(back(setmetatable({},O),setmetatable({},O)),"settings sub-page shows back")
      check(not back(setmetatable({},O),{}),"top settings page shows X")
      check(results["mart1080"].close and results["mart1080"].close.back==true,"rendered mart BUY list publishes back")
      check(results["party1080"].close and results["party1080"].close.back==false,"rendered party list publishes X")
    end
    local box=setmetatable({pages={{"Welcome to the","POKéMON CENTER!"}},page=1,lines={"Welcome to the","POKéMON CENTER!"}},
      classes["src.render.TextBox"])
    pcall(frame,box,"dialogue")
    check(rawget(mod,"_kimMenuClose")==nil,"dialogue box publishes no close button")
    local choice=setmetatable({items={"YES","NO"},index=1},classes["src.ui.ChoiceBox"])
    pcall(frame,choice,"yesno")
    check(rawget(mod,"_kimMenuClose")==nil,"YES/NO prompt publishes no close button")

    -- 0.9.69: touch controls up: the footer drops its B BACK hint
    mod.exports.touch={active=function()return true end}
    local packT=setmetatable({pocketIndex=1,index=1,scroll=0,rows={{id="POTION",name="POTION",count=1,showCount=true}},
      items={POTION={description="x"}}},classes["src.ui.gen2.PackMenu"])
    local drawnT=frame(packT,"touch-hints")
    local sawBack,sawChoose=false,false
    for _,d in ipairs(drawnT) do
      if d.text=="BACK" then sawBack=true end
      if d.text=="CHOOSE" then sawChoose=true end
    end
    check(sawChoose and not sawBack,"touch up: footer keeps A CHOOSE, drops B BACK")
    mod.exports.touch=nil

    -- MODERN UI off: native screens, nothing published
    opts.gen2IntegratedModernUi=false
    local pack=setmetatable({pocketIndex=1,index=1,rows={}},classes["src.ui.gen2.PackMenu"])
    frame(pack,"native-pack")
    check(rawget(mod,"_kimMenuClose")==nil,"native (MODERN UI off) pack publishes no close button")
    check(chain("screen.render_visible",function()return true end,pack)==true,"native pack still renders")
    opts.gen2IntegratedModernUi=nil

    -- KIM Touch: press + release on the close button = one B, never A
    local tlog={}
    local T=100
    love.timer.getTime=function()return T end
    local thooks={}
    local tmod={id="touch",exports={},options={get=function()return nil end,define=function()end},read=function()return nil end,
      hooks={wrap=function(_,n,f,p)thooks[n]=thooks[n] or {};thooks[n][p]=f end},
      input={tap=function(_,g,b)tlog[#tlog+1]="tap:"..b end,press=function(_,g,b)tlog[#tlog+1]="press:"..b;return {} end,release=function()end},
      find=function()return {exports=mod.exports} end}
    setmetatable(tmod,{__index=mod})
    assert(loadstring(assert(readFile("touch/main.lua")),"@touch/main.lua"))()(tmod)
    local ptr=thooks["input.pointer"][10]
    local partyState=setmetatable({party=mons,index=1,game={data={}}},Party)
    local _,game=frame(partyState,"touch-party")
    local close=rawget(mod,"_kimMenuClose")
    check(close~=nil,"touch: party published its close button")
    local function send(phase,x,y)return ptr(function()tlog[#tlog+1]="next" end,game,{phase=phase,x=x,y=y,id=1,source="touch"}) end
    local cx,cy=close.x+close.w/2,close.y+close.h/2
    tlog={}; send("pressed",cx,cy); T=T+0.08; send("released",cx,cy)
    check(table.concat(tlog,",")=="tap:b","touch: tap on close = exactly one B (got "..table.concat(tlog,",")..")")
    -- the generous hit area: just above the button
    tlog={}; send("pressed",cx,close.y-close.h*.4); T=T+0.08; send("released",cx,close.y-close.h*.4)
    check(table.concat(tlog,",")=="tap:b","touch: tap just above close = B (got "..table.concat(tlog,",")..")")
    -- 0.9.71: a key of the screen under the margin wins (naming keyboard's
    -- top-right letters); the button's own square still means B
    local realTargets=mod.exports.screenTapTargets
    local keyY=close.y-close.h*.4
    mod.exports.screenTapTargets=function()return {state=partyState,kind="generic",generic=true,mode="list",time=T,
      cells={{kind="row",index=1,x=cx-40,y=keyY-20,w=80,h=40}}}end
    tlog={}; send("pressed",cx,keyY); T=T+0.08; send("released",cx,keyY)
    check(not table.concat(tlog,","):find("b"),"touch: key under the close margin is not B (got "..table.concat(tlog,",")..")")
    tlog={}; send("pressed",cx,cy); T=T+0.08; send("released",cx,cy)
    check(table.concat(tlog,",")=="tap:b","touch: the button's own square is still B (got "..table.concat(tlog,",")..")")
    mod.exports.screenTapTargets=realTargets
    -- 0.9.64: the lower half of the button counts too (it used to miss)
    tlog={}; send("pressed",cx,close.y+close.h*.9); T=T+0.08; send("released",cx,close.y+close.h*.9)
    check(table.concat(tlog,",")=="tap:b","touch: tap on the button's lower edge = B (got "..table.concat(tlog,",")..")")
    tlog={}; send("pressed",close.x-close.w*.4,cy); T=T+0.08; send("released",close.x-close.w*.4,cy)
    check(table.concat(tlog,",")=="tap:b","touch: tap just left of close = B (got "..table.concat(tlog,",")..")")
    -- slid off before lifting: nothing
    tlog={}; send("pressed",cx,cy); T=T+0.08; send("released",cx-close.w*4,cy+close.h*6)
    check(#tlog==0,"touch: press on close, release far away = nothing (got "..table.concat(tlog,",")..")")
    -- open space is still A
    tlog={}; send("pressed",dims[1]/2,dims[2]*.95); T=T+0.08; send("released",dims[1]/2,dims[2]*.95)
    check(table.concat(tlog,",")=="tap:a","touch: open space still A (got "..table.concat(tlog,",")..")")
    -- 0.9.68: with a close button showing, the floating B is gone; START /
    -- SELECT stay on PARTY (SELECT switches) but not on, say, the MART
    local _,gameP=frame(partyState,"touch-party-buttons")
    local shown=tmod.exports.shownButtons(gameP)
    check(shown.b==nil and shown.start~=nil and shown.select~=nil,"touch: PARTY hides B, keeps START / SELECT")
    local martState=setmetatable({phase="buy",index=1,entries={{name="POTION",price=300}},
      selected=function(s)return s.entries[s.index]end,description=function()return ""end,
      money=function()return 100 end},Mart)
    local _,mgame=frame(martState,"touch-mart")
    local ms=tmod.exports.shownButtons(mgame)
    check(ms.b==nil and ms.start==nil and ms.select==nil,"touch: MART hides B, START and SELECT")
    local _,game2=frame(partyState,"touch-party2")
    game=game2
    -- a stale rect (half a second old, or another state on top) is ignored
    T=T+1
    local stale=tmod.exports.shownButtons(game)
    check(stale.b~=nil and stale.start~=nil,"touch: no live close button = all buttons back")
    tlog={}; send("pressed",cx,cy); T=T+0.08; send("released",cx,cy)
    check(table.concat(tlog,",")=="tap:a","touch: stale close rect ignored (got "..table.concat(tlog,",")..")")
  end

  -- 0.9.64: MENU BUTTON in a bottom corner sits in the footer band, the
  -- footer text stays clear of it, and the title row gets its width back
  if not renderOnly then
    local S=mod._kantoInMotionGen2Ui
    for _,corner in ipairs({"br","bl"}) do
      opts.menuClosePos=corner
      dims={1080,2520}
      local Pk=classes["src.ui.gen2.PackMenu"]
      for _,sc in ipairs(screens) do
        if sc[1]=="pack" or sc[1]=="party" then
          local state=sc[2]()
          local drawn=frame(state,sc[1].."-"..corner)
          local close=rawget(mod,"_kimMenuClose")
          check(close~=nil,sc[1].." "..corner.." publishes a close button")
          check(S.closeReserve()==0,corner.." frees the title row")
          if close then
            local leftSide=corner=="bl"
            local winTop=nil
            for _,t in ipairs(drawn) do
              local f=t.font
              if f and t.text~="" then
                local tw=math.min(t.w or f:getWidth(t.text),f:getWidth(t.text))
                local tx=t.x
                if t.align=="right" and t.w then tx=t.x+t.w-tw end
                if t.align=="center" and t.w then tx=t.x+(t.w-tw)/2 end
                local overlap=tx<close.x+close.w and tx+tw>close.x and t.y<close.y+close.h and t.y+f:getHeight()>close.y
                check(not overlap,sc[1].." "..corner.." button clear of '"..t.text.."'")
              end
            end
            check(close.y>dims[2]*.5,sc[1].." "..corner.." button sits low (footer)")
            check(leftSide and close.x<dims[1]*.5 or (not leftSide and close.x>dims[1]*.5),sc[1].." "..corner.." on the chosen side")
          end
        end
      end
    end
    opts.menuClosePos=nil
  end

  for _,p in ipairs(shots) do print("png",p) end
  if failures>0 then print(("menu chrome: %d FAILED"):format(failures));os.exit(1) end
  print(renderOnly and "menu chrome: renders written" or "menu chrome: footers, close button, touch B PASS")
  love.event.quit(0)
end
