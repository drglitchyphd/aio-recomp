-- gen2-aio 0.9.75: the Modern move-learning screens over the ENGINE's own
-- classes, and RELEARN in the party submenu.
--
--   AIO_ENGINE_SRC=/path/to/engine/src xvfb-run -a love tests/modern_moves
--
-- AIO_ENGINE_SRC is the engine checkout's root (the folder holding src/).
-- The real src/ui/gen2/MoveDeleter.lua, ForgetMoveList.lua, MoveTutor.lua,
-- PartyMenu.lua, src/ui/Menu.lua, src/battle/gen2/Mon.lua, Strings.lua and
-- Game2:learnMoveOn run, with Gen1Remember (qol/modules/Gen1Remember) on the
-- engine's ui.party.submenu hook. Only drawing, audio, assets and the text
-- box are stubbed. Without an engine the test says SKIP and passes. Renders
-- every screen at the Fold's outer (1080x2520) and inner (2184x1968) sizes,
-- and the native screens with MODERN UI off, into AIO_TEST_OUTPUT.
io.stdout:setvbuf("no")
local root=love.filesystem.getSource():gsub("/tests/modern_moves/?$","").."/"
local output=os.getenv("AIO_TEST_OUTPUT") or os.getenv("TEMP") or "/tmp"
local engine=os.getenv("AIO_ENGINE_SRC")
function love.errorhandler(err) print(debug.traceback(tostring(err)));os.exit(1) end

local failures=0
local function check(cond,msg)
  if not cond then failures=failures+1;print("FAIL: "..msg) else print("ok   "..msg) end
end

function love.load()
  if not engine or engine=="" or not io.open(engine.."/src/ui/gen2/MoveDeleter.lua","rb") then
    print("modern moves: SKIP (set AIO_ENGINE_SRC to the engine's src root)")
    love.event.quit(0)
    return
  end
  package.path=engine.."/?.lua;"..package.path
  local G=love.graphics
  local dims={1080,2520}
  G.getDimensions=function()return dims[1],dims[2] end
  love.system.getOS=function()return "Android" end

  -- ------------------------------------------------------------ stubs
  -- Anything not named below that a module merely holds as a local: a table
  -- whose every field is a no-op function.
  local function permissive()
    return setmetatable({},{__index=function(t,k) local f=function()end; rawset(t,k,f); return f end})
  end
  -- The native Game Boy chrome, drawn for real at tile scale so the MODERN
  -- UI off PNGs show the native layout; every call is also recorded.
  local native={}
  local K=4
  local function tile(v)return (tonumber(v) or 0)*8*K end
  local Chrome=permissive()
  local function nprint(text,x,y)
    native[#native+1]={op="print",text=tostring(text),x=x,y=y}
    G.setColor(0,0,0,1);G.print(tostring(text),tile(x),tile(y),0,K*.75,K*.75)
  end
  Chrome.textbox=function(x,y,w,h)
    native[#native+1]={op="box",x=x,y=y,w=w,h=h}
    G.setColor(1,1,1,1);G.rectangle("fill",tile(x),tile(y),tile(w+2),tile(h+2))
    G.setColor(0,0,0,1);G.setLineWidth(K);G.rectangle("line",tile(x)+K*2,tile(y)+K*2,tile(w+2)-K*4,tile(h+2)-K*4)
  end
  Chrome.box=Chrome.textbox
  Chrome.print=nprint
  Chrome.printThrough=function(t,x,y)nprint(t,x,y)end
  Chrome.cursor=function(x,y)native[#native+1]={op="cursor",x=x,y=y};nprint(">",x,y)end
  Chrome.cursorThrough=Chrome.cursor
  Chrome.number=function(n,digits)return ("%"..(digits or 1).."d"):format(tonumber(n) or 0)end
  Chrome.fitScale=function()return 1 end
  Chrome.fitOrigin=function()return 0,0 end
  local Font=permissive()
  Font.split=function(s)local out={};for ch in tostring(s):gmatch("[\1-\127\194-\244][\128-\191]*") do out[#out+1]=ch end;return out end
  Font.draw=function(t,x,y)native[#native+1]={op="print",text=tostring(t),x=x/8,y=y/8}
    G.setColor(0,0,0,1);G.print(tostring(t),x*K,y*K,0,K*.75,K*.75) end
  Font.drawBox=function(x,y,w,h)Chrome.textbox(x,y,w-2,h-2)end
  Font.drawCode=function(code,x,y)if code=="cursor" then native[#native+1]={op="cursor",x=x/8,y=y/8};G.print(">",x*K,y*K,0,K*.75,K*.75) end end
  Font.useBattleExtra=function()return false end
  local hooks,opts,remOpts={},{},{}
  local function chain(name,base,...)
    local h={}
    for i,v in ipairs(hooks[name] or {}) do h[i]=v end
    table.sort(h,function(a,b)return a.p<b.p end)
    local fn=base
    for _,link in ipairs(h)do local nextFn=fn;fn=function(...)return link.fn(nextFn,...)end end
    return fn(...)
  end
  local Runtime={wants=function()return false end,emit=function()end,
    wantsHook=function(n)return hooks[n]~=nil end,
    call=function(name,base,...)return chain(name,base,...)end}
  -- the text box: holds its text, its callbacks and its choice
  local TextBox={};TextBox.__index=TextBox
  function TextBox.new(game,text,onDone,o)return setmetatable({game=game,text=text,onDone=onDone,opts=o or {}},TextBox)end
  function TextBox.soundOpts(_,_,o)return o or {} end
  local pushed={}
  local stubs={
    ["src.ui.gen2.Chrome"]=Chrome,["src.render.Font"]=Font,
    ["src.ui.Theme"]={cursor="cursor",cursorHollow="hollow",moreArrow="more"},
    ["src.core.Sound"]={resolve=function(_,n)return n end,play=function()end},
    ["src.core.GameVersion"]={get=function()return "crystal" end,engine=function()return "crystal" end,
      generation=function()return 2 end},
    ["src.mods.Runtime"]=Runtime,
    ["src.core.Logger"]={warn=function()end,info=function()end,error=function(...)print("engine error",...)end},
    ["src.render.TextBox"]=TextBox,
    ["src.core.RomText"]=function(_,_,fmt,...)return fmt:format(...) end,
    ["src.core.gen2.Unown"]={SPECIES="UNOWN",monLetter=function()return nil end},
    ["src.core.gen2.Gender"]=permissive(),
    ["src.core.gen2.Mail"]={monHoldsMail=function()return false end},
    ["src.ui.gen2.BattleHud"]={new=function()return permissive() end},
  }
  stubs["src.ui.Screens"]={get=function()return true end,push=function(game,id,o,...)
    pushed[#pushed+1]=id
    if id=="Gen2MoveDeleter" then
      game.stack:push(require("src.ui.gen2.MoveDeleter").new(game,o))
    else game.stack:push({screen=id,opts=o}) end
    return true
  end}
  for name,v in pairs(stubs) do package.preload[name]=function()return v end end
  for _,name in ipairs({"src.render.Assets","src.world.gen2.FieldMoves","src.render.GbcPalette",
    "src.battle.gen2.HpBar","src.core.gen2.ItemEffects","src.ui.LevelDisplay","src.battle.Status",
    "src.ui.gen2.WaitPlaySFX"}) do
    package.preload[name]=function()return permissive() end
  end
  -- Game2 is loaded for its learnMoveOn alone; every module it holds at file
  -- scope (the world, the save, the renderer) is an inert stand-in
  do
    local f=assert(io.open(engine.."/src/core/Game2.lua","rb"));local src=f:read("*a");f:close()
    for name in src:gmatch('require%("([^"]+)"%)') do
      if not package.preload[name] and name~="src.core.Strings" and name~="src.battle.gen2.Mon" then
        package.preload[name]=function()return permissive() end
      end
    end
  end
  local Game2=require("src.core.Game2")
  local MoveDeleter=require("src.ui.gen2.MoveDeleter")
  local MoveTutor=require("src.ui.gen2.MoveTutor")
  local PartyMenu=require("src.ui.gen2.PartyMenu")
  local Menu=require("src.ui.Menu")

  -- ------------------------------------------------------------ the mod
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
  local mod={exports={},path=root:gsub("/$",""),options={get=function(_,k)return opts[k]end},
    log={info=function()end,warn=function()end,error=function(_,...)print("mod error",...)end},
    read=function(_,rel)return readFile(rel)end,
    assets={image=function(_,p)return image(p)end},
    hooks={wrap=function(_,name,fn,priority)
      hooks[name]=hooks[name] or {};hooks[name][#hooks[name]+1]={fn=fn,p=priority or 0}
    end}}
  mod._kimArenaDiag=function(k,v)error(k..": "..tostring(v))end
  local function run(rel,...)
    return assert(loadstring(assert(readFile(rel)),"@"..rel))()(...)
  end
  run("lib/crystal_aio/font.lua",{mod=mod})
  local S=run("lib/gen2_modern_style.lua",mod)
  assert(run("lib/gen2_modern_core_menus.lua",mod))
  local Moves=run("lib/crystal_aio/modern_moves.lua",{mod=mod})
  local DEX={QUILAVA=156,CYNDAQUIL=155,TOTODILE=158,PIDGEY=16,MEW=151}
  mod._kantoInMotionHdMenuIconForModernUi=function(_,m)
    local d=DEX[m.species];return d and ("assets/menu_icons/hd/normal/%03d.png"):format(d) or nil
  end
  -- Gen1Remember, as the QOL bundle's facade hands it the mod
  local rem={id="gen1_wild_qol",path=root.."qol/modules/Gen1Remember",exports={},
    options={define=function()end,get=function(_,k)return remOpts[k] end},
    hooks=mod.hooks,events={on=function()end},
    log={info=function()end,warn=function(_,...)print("remember warn",...)end,error=function(_,...)print("remember error",...)end},
    read=function(_,name)return readFile("qol/modules/Gen1Remember/"..name)end,
    find=function()return nil end}
  run("qol/modules/Gen1Remember/main.lua",rem)
  check(type(rem.exports.open)=="function","Gen1Remember installed (its screen built on the Gen 2 engine)")

  local draws={}
  local originalText=S.text
  S.text=function(value,font,x,y,w,align,c)
    draws[#draws+1]={text=tostring(value),font=font,x=x,y=y,w=w,align=align}
    return originalText(value,font,x,y,w,align,c)
  end
  local function drew(s)
    for _,d in ipairs(draws) do if d.text==s then return d end end
  end
  local function drewFind(s)
    for _,d in ipairs(draws) do if d.text:find(s,1,true) then return d end end
  end

  -- ------------------------------------------------------------ data (Gen 2 shape)
  local function mv(name,t,p,a,pp)return {name=name,type=t,power=p,accuracy=a,pp=pp} end
  local data={moves={
    TACKLE=mv("TACKLE","NORMAL",35,95,35),LEER=mv("LEER","NORMAL",0,100,30),
    SMOKESCREEN=mv("SMOKESCREEN","NORMAL",0,100,20),EMBER=mv("EMBER","FIRE",40,100,25),
    QUICK_ATTACK=mv("QUICK ATTACK","NORMAL",40,100,30),FLAME_WHEEL=mv("FLAME WHEEL","FIRE",60,100,25),
    DEFENSE_CURL=mv("DEFENSE CURL","NORMAL",0,100,40),SWIFT=mv("SWIFT","NORMAL",60,100,20),
    FLAMETHROWER=mv("FLAMETHROWER","FIRE",95,100,15),CUT=mv("CUT","NORMAL",50,95,30),
    SCRATCH=mv("SCRATCH","NORMAL",40,100,35),WATER_GUN=mv("WATER GUN","WATER",40,100,25),
    RAGE=mv("RAGE","NORMAL",20,100,20),BITE=mv("BITE","DARK",60,100,25),
    POUND=mv("POUND","NORMAL",40,100,35),TRANSFORM=mv("TRANSFORM","NORMAL",0,100,10),
    MEGA_PUNCH=mv("MEGA PUNCH","NORMAL",80,85,20),METRONOME=mv("METRONOME","NORMAL",0,100,10),
    PSYCHIC_M=mv("PSYCHIC","PSYCHIC_TYPE",90,100,10),ANCIENTPOWER=mv("ANCIENTPOWER","ROCK",60,100,5),
    BARRIER=mv("BARRIER","PSYCHIC_TYPE",0,100,30),AMNESIA=mv("AMNESIA","PSYCHIC_TYPE",0,100,20),
    BATON_PASS=mv("BATON PASS","NORMAL",0,100,40),THUNDERBOLT=mv("THUNDERBOLT","ELECTRIC",95,100,15),
    ICE_BEAM=mv("ICE BEAM","ICE",95,100,10),SURF=mv("SURF","WATER",95,100,15),
  },pokemon={
    CYNDAQUIL={name="CYNDAQUIL",levelMoves={{level=1,move="TACKLE"},{level=1,move="LEER"},{level=6,move="SMOKESCREEN"},
      {level=10,move="DEFENSE_CURL"},{level=12,move="EMBER"},{level=19,move="QUICK_ATTACK"}},
      evolutions={{method="EVOLVE_LEVEL",level=14,into="QUILAVA"}},tmhm={"CUT"},tutorMoves={"FLAMETHROWER"}},
    QUILAVA={name="QUILAVA",levelMoves={{level=1,move="TACKLE"},{level=1,move="LEER"},{level=1,move="SMOKESCREEN"},
      {level=12,move="EMBER"},{level=20,move="SWIFT"},{level=21,move="QUICK_ATTACK"},{level=31,move="FLAME_WHEEL"}},
      evolutions={},tmhm={"CUT"},tutorMoves={"FLAMETHROWER"}},
    TOTODILE={name="TOTODILE",levelMoves={{level=1,move="SCRATCH"},{level=1,move="LEER"},{level=7,move="RAGE"},
      {level=13,move="WATER_GUN"}},evolutions={},tmhm={"CUT","SURF"}},
    PIDGEY={name="PIDGEY",levelMoves={{level=1,move="TACKLE"}},evolutions={},tmhm={}},
    MEW={name="MEW",levelMoves={{level=1,move="POUND"},{level=10,move="TRANSFORM"},{level=20,move="MEGA_PUNCH"},
      {level=30,move="METRONOME"},{level=40,move="PSYCHIC_M"},{level=50,move="ANCIENTPOWER"},
      {level=1,move="BARRIER"},{level=5,move="AMNESIA"},{level=15,move="BATON_PASS"},{level=25,move="SWIFT"},
      {level=35,move="EMBER"},{level=45,move="BITE"},{level=46,move="CUT"}},evolutions={},
      tmhm={"FLAMETHROWER","THUNDERBOLT","ICE_BEAM","SURF"}},
  }}
  local function slot(id,pp)return {id=id,pp=pp or data.moves[id].pp,maxPp=data.moves[id].pp} end
  local function newParty()
    return {
      {species="QUILAVA",nickname="BLAZE",level=22,hp=60,maxHp=66,
        moves={slot("TACKLE"),slot("SMOKESCREEN",12),slot("EMBER",20),slot("QUICK_ATTACK")}},
      {species="TOTODILE",nickname="TOTODILE",level=13,hp=40,maxHp=44,
        moves={slot("SCRATCH"),slot("LEER"),slot("RAGE"),slot("WATER_GUN")}},
      {species="PIDGEY",nickname="PIDGEY",level=5,hp=0,maxHp=20,moves={slot("TACKLE")}},
      {species="CYNDAQUIL",nickname="CYNDAQUIL",level=12,hp=30,maxHp=33,isEgg=true,moves={slot("TACKLE")}},
      {species="MEW",nickname="MEW",level=50,hp=150,maxHp=150,
        moves={slot("FLAMETHROWER"),slot("THUNDERBOLT"),slot("ICE_BEAM"),slot("SURF")}},
    }
  end
  local input={pressed={}}
  function input:wasPressed(b)return self.pressed[b] or false end
  local function newGame()
    local game=setmetatable({data=data,input=input,stack={states={}}},{__index=Game2})
    game.save={party=newParty()}
    function game.stack:top()return self.states[#self.states] end
    function game.stack:push(s)self.states[#self.states+1]=s end
    function game.stack:pop()self.states[#self.states]=nil end
    function game:say(text,onDone)self.stack:push(TextBox.new(self,text,onDone))end
    return game
  end
  local function press(state,btn)
    input.pressed={[btn]=true};state:update(1/60);input.pressed={}
  end
  -- the text box's own behaviour: it leaves the stack, then answers
  local function answer(game,yes)
    local t=game.stack:top();assert(getmetatable(t)==TextBox and t.opts.choice,"a YES/NO box is up")
    game.stack:pop();t.opts.choice(yes)
  end
  local function advance(game)
    local t=game.stack:top();assert(getmetatable(t)==TextBox,"a text box is up")
    game.stack:pop();if t.onDone then t.onDone() end
  end
  local function shown(game)
    local t=game.stack:top();assert(getmetatable(t)==TextBox and t.opts.stay,"a staying box is up")
    t.opts.stay.onShown()
  end

  local shots={}
  local function frame(game,name)
    draws={};rawset(mod,"_kimScreenTapTargets",nil)
    local canvas=G.newCanvas(dims[1],dims[2])
    G.setCanvas(canvas);G.clear(.16,.27,.2,1)
    chain("render.hud",function()end,game,{})
    G.setCanvas()
    if name then
      local path=output.."/aio-moves-"..name.."-"..dims[1].."x"..dims[2]..".png"
      local f=assert(io.open(path,"wb"))
      f:write(canvas:newImageData():encode("png"):getString());f:close()
      shots[#shots+1]=path
    end
    canvas:release()
    return rawget(mod,"_kimScreenTapTargets"),rawget(mod,"_kimMenuClose")
  end
  -- what KIM Touch does with a generic cell: select, then its button
  local function tapCell(state,c)
    if c.select then c.select(state) end
    local b=c.button;if b==nil then b="a" end
    if b then press(state,b) end
  end
  local function rowCells(t)
    local out={}
    for _,c in ipairs(t and t.cells or {}) do if c.button=="a" then out[#out+1]=c end end
    return out
  end
  -- every cell on screen and inside the window, none overlapping another,
  -- the close button or the footer
  local function layoutOk(tag,t,close)
    local bad={}
    local cells=t and t.cells or {}
    local footer=drew("BACK") or drew("FORGET") or drew("TEACH") or drew("LEARN")
    for i,a in ipairs(cells) do
      if a.x<0 or a.y<0 or a.x+a.w>dims[1] or a.y+a.h>dims[2] then bad[#bad+1]="offscreen "..i end
      for j=i+1,#cells do
        local b=cells[j]
        if a.x<b.x+b.w-0.5 and b.x<a.x+a.w-0.5 and a.y<b.y+b.h-0.5 and b.y<a.y+a.h-0.5 then bad[#bad+1]=("overlap %d/%d"):format(i,j) end
      end
      if close and a.x<close.x+close.w and close.x<a.x+a.w and a.y<close.y+close.h and close.y<a.y+a.h then bad[#bad+1]="close "..i end
      if footer and a.y+a.h>footer.y+1 then bad[#bad+1]="footer "..i end
    end
    check(close~=nil and close.state==t.state,tag.." close button published for the screen")
    check(footer~=nil,tag.." footer drawn")
    check(#bad==0,tag.." cells on screen, apart, clear of close and footer ("..table.concat(bad,",")..")")
    -- text clear of the close button
    local over=nil
    for _,d in ipairs(draws) do
      local w=d.w or (d.font and d.font:getWidth(d.text)) or 0
      if close and d.font and d.text~="" and d.x<close.x+close.w and close.x<d.x+w and d.y<close.y+close.h and close.y<d.y+d.font:getHeight() then
        -- a full-width box reaching under the button is fine if the text is short of it
        local tw=d.font:getWidth(d.text)
        local tx=d.align=="right" and d.x+(d.w or tw)-tw or (d.align=="center" and d.x+((d.w or tw)-tw)/2) or d.x
        if tx<close.x+close.w and close.x<tx+tw then over=d.text end
      end
    end
    check(over==nil,tag.." no text under the close button ("..tostring(over)..")")
  end

  -- ------------------------------------------------------------ screens at both sizes
  for _,d in ipairs({{1080,2520},{2184,1968}}) do
    dims=d
    local tag=dims[1].."x"..dims[2]
    -- 1. the Blackthorn deleter
    do
      local game=newGame()
      local mon=game.save.party[1]
      game.stack:push(TextBox.new(game,"Which move should it forget?"))
      local s=MoveDeleter.new(game,{mon=mon,moves=data.moves})
      game.stack:push(s)
      local t,close=frame(game,"deleter")
      check(t and t.state==s,tag.." deleter: tap cells published")
      check(#rowCells(t)==4,tag.." deleter: one row per move ("..#rowCells(t)..")")
      check(drew("MOVE DELETER") and drew("SMOKESCREEN") and drew("PP 12/20"),tag.." deleter: title, moves and PP")
      layoutOk(tag.." deleter",t,close)
    end
    -- 2. LearnMove's forget list, reached through the real Game2:learnMoveOn
    do
      local game=newGame()
      local mon=game.save.party[1]
      game:learnMoveOn(mon,"FLAMETHROWER",function()end)
      answer(game,true) -- "Delete an older move?" YES
      shown(game)       -- "Which move should be forgotten?" stays; the list comes up
      local s=game.stack:top()
      check(getmetatable(s)==MoveDeleter and s.forget,tag.." forget: Game2:learnMoveOn opened the engine's forget list")
      local t,close=frame(game,"forget")
      check(drew("FORGET A MOVE") and drew("NEW MOVE") and drewFind("trying to learn FLAMETHROWER"),
        tag.." forget: title, the incoming move named")
      check(#rowCells(t)==4,tag.." forget: four rows")
      layoutOk(tag.." forget",t,close)
    end
    -- 3. the PP item's move pick (over the party list)
    do
      local game=newGame()
      local mon=game.save.party[1]
      game.stack:push(PartyMenu.new(game,{}))
      local s=MoveDeleter.new(game,{mon=mon,moves=data.moves})
      game.stack:push(s)
      local t,close=frame(game,"restorepp")
      check(drew("RESTORE PP"),tag.." pp pick: titled RESTORE PP")
      layoutOk(tag.." pp pick",t,close)
    end
    -- 4. the move tutor
    do
      local game=newGame()
      local s=MoveTutor.new(game,{move="FLAMETHROWER",moveName="FLAMETHROWER",onDone=function()end})
      game.stack:push(s)
      local t,close=frame(game,"tutor")
      check(t and t.state==s and #rowCells(t)==#game.save.party,tag.." tutor: one row per party mon")
      check(drew("ABLE") and drew("NOT ABLE") and drew("KNOWS IT"),tag.." tutor: ABLE / NOT ABLE from the engine, KNOWS IT")
      layoutOk(tag.." tutor",t,close)
    end
    -- 5. RELEARN, from the party submenu
    do
      local game=newGame()
      local party=PartyMenu.new(game,{submenu=true})
      game.stack:push(party)
      party.index=1
      press(party,"a")
      local items=party.submenu and party.submenu.items or {}
      local labels={}
      for i,it in ipairs(items) do labels[i]=tostring(it.label) end
      check(labels[#labels]=="CANCEL" and labels[#labels-1]=="RELEARN",
        tag.." party submenu: RELEARN above CANCEL ("..table.concat(labels,",")..")")
      party.submenu.index=#items-1
      press(party,"a")
      local s=game.stack:top()
      check(getmetatable(s)==Menu and type(s.relearn)=="table",tag.." RELEARN opens Gen1Remember's list")
      local t,close=frame(game,"relearn")
      check(drew("RELEARN A MOVE") and drew("LEER") and drew("DEFENSE CURL") and drew("SWIFT"),
        tag.." relearn: the Gen 2 pool (LEER, DEFENSE CURL from CYNDAQUIL, SWIFT)")
      check(drewFind("FROM CYNDAQUIL")==nil,tag.." relearn: no FROM line on an own-form move")
      check(#rowCells(t)==3,tag.." relearn: three rows ("..#rowCells(t)..")")
      layoutOk(tag.." relearn",t,close)
      -- the long list (MEW): scrolls, UP / DOWN cells
      press(s,"b")
      party.index=5
      press(party,"a")
      party.submenu.index=#party.submenu.items-1
      press(party,"a")
      local m=game.stack:top()
      check(getmetatable(m)==Menu and #m.items>=8,tag.." MEW: a long pool ("..#(m.items or {})..")")
      m.index=#m.items
      local t2,close2=frame(game,"relearn-long")
      local up,down=false,false
      for _,c in ipairs(t2.cells) do if c.button=="up" then up=true elseif c.button=="down" then down=true end end
      check(up and down,tag.." long relearn list: UP / DOWN cells")
      check(drew(data.moves[m.relearn.rows[#m.items].move].name),tag.." long relearn list: the selected (last) row is drawn")
      layoutOk(tag.." relearn long",t2,close2)
    end
  end
  dims={1080,2520}

  -- ------------------------------------------------------------ inputs
  -- deleter: a tap is the row + A; the close button's B cancels
  do
    local game=newGame()
    local chosen,cancelled
    local s=MoveDeleter.new(game,{mon=game.save.party[1],moves=data.moves,
      onChoose=function(i)chosen=i end,onCancel=function()cancelled=true end})
    game.stack:push(s)
    local t=frame(game)
    tapCell(s,rowCells(t)[3])
    check(chosen==3 and s.row==3,"deleter: tapping row 3 answers slot 3 through MoveDeleter's own A")
    local s2=MoveDeleter.new(game,{mon=game.save.party[1],moves=data.moves,onCancel=function()cancelled=true end})
    game.stack:push(s2)
    press(s2,"b")
    check(cancelled,"deleter: B (the close button) cancels")
  end
  -- forget: tap SMOKESCREEN -> the engine replaces it, "Poof!"
  do
    local game=newGame()
    local mon=game.save.party[1]
    local result
    game:learnMoveOn(mon,"FLAMETHROWER",function(l)result=l end)
    answer(game,true);shown(game)
    local s=game.stack:top()
    local t=frame(game)
    tapCell(s,rowCells(t)[2])
    check(mon.moves[2].id=="FLAMETHROWER","forget: a tap on row 2 swapped SMOKESCREEN for FLAMETHROWER")
    local top=game.stack:top()
    check(getmetatable(top)==TextBox and tostring(top.text):find("Poof"),"forget: the engine's 1, 2 and... Poof!")
    advance(game)
    check(result==true and rawget(mod,"_aioLearning")==nil,"forget: learnMoveOn answered learned; the note is cleared")
    -- B on the list: the engine's "Stop learning?"
    game:learnMoveOn(mon,"SWIFT",function(l)result=l end)
    answer(game,true);shown(game)
    press(game.stack:top(),"b")
    check(getmetatable(game.stack:top())==TextBox and tostring(game.stack:top().text):find("Stop learning"),
      "forget: B asks Stop learning (engine)")
  end
  -- tutor: NOT ABLE refuses (engine text); ABLE teaches through learnMoveOn
  do
    local game=newGame()
    local done
    local s=MoveTutor.new(game,{move="FLAMETHROWER",moveName="FLAMETHROWER",onDone=function(l)done=l end})
    game.stack:push(s)
    local t=frame(game)
    tapCell(s,rowCells(t)[2]) -- TOTODILE: not compatible
    local top=game.stack:top()
    check(getmetatable(top)==TextBox and tostring(top.text):find("not compatible"),"tutor: NOT ABLE row gets the engine's refusal")
    advance(game)
    t=frame(game)
    tapCell(s,rowCells(t)[1]) -- BLAZE: full set -> ask to forget
    top=game.stack:top()
    check(getmetatable(top)==TextBox and top.opts.choice,"tutor: an ABLE mon with four moves gets LearnMove's question")
    answer(game,true);shown(game)
    t=frame(game)
    tapCell(game.stack:top(),rowCells(t)[1])
    advance(game)
    check(game.save.party[1].moves[1].id=="FLAMETHROWER" and done==true,"tutor: taught, the tutor finished")
  end
  -- relearn: free slot and full set, both through the engine's LearnMove
  do
    local game=newGame()
    local mon=game.save.party[1]
    table.remove(mon.moves,4) -- three moves: TACKLE SMOKESCREEN EMBER
    rem.exports.open(game,mon)
    local m=game.stack:top()
    local t=frame(game)
    local names={}
    for i,r in ipairs(m.relearn.rows) do names[i]=r.move end
    local target
    for i,id in ipairs(names) do if id=="SWIFT" then target=i end end
    tapCell(m,rowCells(t)[target])
    local top=game.stack:top()
    check(getmetatable(top)==TextBox and tostring(top.text):find("learned"),"relearn: a free slot learns outright (engine text)")
    advance(game)
    check(#mon.moves==4 and mon.moves[4].id=="SWIFT" and mon.moves[4].maxPp==20,"relearn: SWIFT in slot 4 as the engine writes it {id,pp,maxPp}")
    -- full set: the forget list, Modern, then Poof
    rem.exports.open(game,mon)
    m=game.stack:top()
    t=frame(game)
    tapCell(m,rowCells(t)[1]) -- LEER
    answer(game,true);shown(game)
    local fl=game.stack:top()
    check(getmetatable(fl)==MoveDeleter and fl.forget,"relearn: a full set opens the engine's forget list")
    frame(game,"relearn-forget")
    check(drewFind("trying to learn LEER"),"relearn: the forget list names LEER")
    t=frame(game)
    tapCell(fl,rowCells(t)[1])
    advance(game)
    check(mon.moves[1].id=="LEER","relearn: TACKLE forgotten, LEER learned")
    -- nothing to relearn: no row (HIDE WHEN EMPTY), and the egg has none
    local party=PartyMenu.new(game,{submenu=true})
    game.stack:push(party)
    for _,i in ipairs({2,4}) do
      party.index=i;press(party,"a")
      local has=false
      for _,it in ipairs(party.submenu.items) do if it.label=="RELEARN" then has=true end end
      check(not has,"relearn: no row on "..game.save.party[i].nickname..(i==4 and " (egg)" or " (nothing to relearn)"))
      press(party,"b")
    end
    -- HIDE WHEN EMPTY off: the row shows, and says so
    remOpts.hide_empty=false
    party.index=2;press(party,"a")
    local idx
    for i,it in ipairs(party.submenu.items) do if it.label=="RELEARN" then idx=i end end
    check(idx~=nil,"relearn: HIDE WHEN EMPTY off keeps the row")
    party.submenu.index=idx;press(party,"a")
    check(getmetatable(game.stack:top())==TextBox and tostring(game.stack:top().text):find("no"),"relearn: an empty pool says so")
    game.stack:pop()
    remOpts.hide_empty=nil
    -- PARTY REMEMBER off: no row
    remOpts.party_row=false
    party.index=1;press(party,"a")
    local any=false
    for _,it in ipairs(party.submenu.items) do if it.label=="RELEARN" then any=true end end
    check(not any,"relearn: PARTY REMEMBER off drops the row")
    press(party,"b")
    remOpts.party_row=nil
    -- a full eight-row list: RELEARN takes CANCEL's place
    local items={}
    for i=1,7 do items[i]={id="F"..i,label="F"..i} end
    items[8]={id="CANCEL",label="CANCEL"}
    local out=chain("ui.party.submenu",function(_,x)return x end,game,items,game.save.party[1],{battle=false})
    check(#out==8 and out[8].label=="RELEARN","relearn: at eight rows RELEARN takes CANCEL's place")
    local inBattle=chain("ui.party.submenu",function(_,x)return x end,game,{{id="SWITCH"},{id="CANCEL"}},game.save.party[1],{battle=true})
    check(#inBattle==2,"relearn: not in battle")
  end
  -- Relearn pool on Gen 1 data shape still works (learnset / species)
  do
    local Relearn=assert(loadstring(readFile("qol/modules/Gen1Remember/relearn.lua")))()
    local d1={moves={A={name="A"},B={name="B"},C={name="C"}},pokemon={
      X={learnset={{level=5,move="B"}},level1Moves={"A"},evolutions={{species="Y"}}},
      Y={learnset={{level=9,move="C"}},evolutions={}}}}
    local p=Relearn.pool(d1,{species="Y",level=10,moves={{id="A"}}})
    check(#p==2 and p[1].move=="B" and p[1].inherited and p[2].move=="C","Gen 1 learnset / species still read")
  end

  -- ------------------------------------------------------------ MODERN UI off
  local function nativeFrame(state,name)
    native={}
    local canvas=G.newCanvas(160*K,144*K)
    G.setCanvas(canvas);G.clear(1,1,1,1)
    local ok,err=pcall(state.draw,state)
    G.setCanvas()
    local path=output.."/aio-moves-native-"..name..".png"
    local f=assert(io.open(path,"wb"))
    f:write(canvas:newImageData():encode("png"):getString());f:close()
    shots[#shots+1]=path;canvas:release()
    return ok,err
  end
  local function nativePrinted(s)
    for _,n in ipairs(native) do if n.op=="print" and n.text==s then return true end end
    return false
  end
  for _,off in ipairs({{"gen2IntegratedModernUi","MODERN UI"},{"menuUi","MENU UI"},{"hideOriginalUi","HIDE ORIGINAL"}}) do
    opts[off[1]]=false
    local label=off[2].." off"
    local game=newGame()
    local mon=game.save.party[1]
    local d=MoveDeleter.new(game,{mon=mon,moves=data.moves,layout="forget"})
    game.stack:push(d)
    local t=frame(game)
    check(t==nil and rawget(mod,"_kimMenuClose")==nil,label..": no Modern window over the forget list")
    check(chain("screen.render_visible",function()return true end,d)==true,label..": native forget list renders")
    if off[1]=="gen2IntegratedModernUi" then
      local ok,err=nativeFrame(d,"forget")
      check(ok and nativePrinted("SMOKESCREEN"),label..": native ForgetMoveList drew the moves ("..tostring(err)..")")
      local dd=MoveDeleter.new(game,{mon=mon,moves=data.moves})
      ok,err=nativeFrame(dd,"deleter")
      check(ok and nativePrinted("EMBER") and nativePrinted("PP"),label..": native deleter drew ("..tostring(err)..")")
    end
    press(d,"down")
    check(d.row==2,label..": native DOWN moves the engine's cursor")
    local tutor=MoveTutor.new(game,{move="FLAMETHROWER",moveName="FLAMETHROWER"})
    game.stack:push(tutor)
    frame(game)
    check(rawget(mod,"_kimScreenTapTargets")==nil,label..": no Modern tutor")
    check(chain("screen.render_visible",function()return true end,tutor)==true,label..": native tutor renders")
    rem.exports.open(game,mon)
    local m=game.stack:top()
    frame(game)
    check(rawget(mod,"_kimScreenTapTargets")==nil,label..": no Modern relearn list")
    check(chain("screen.render_visible",function()return true end,m)==true,label..": native relearn Menu renders")
    if off[1]=="gen2IntegratedModernUi" then
      local ok,err=nativeFrame(m,"relearn")
      check(ok and nativePrinted((m.items[1].label)),label..": native relearn Menu drew its rows ("..tostring(err)..")")
    end
    press(m,"down")
    check(m.index==2,label..": native relearn DOWN")
    opts[off[1]]=nil
  end
  -- the generic Modern menu window leaves RELEARN's Menu alone; other Menus keep it
  do
    local game=newGame()
    data.gen2MenuGfx={}
    rem.exports.open(game,game.save.party[1])
    local t=frame(game)
    check(t and t.state==game.stack:top() and drew("RELEARN A MOVE") and not drew("MENU"),
      "core menus' generic window steps aside for RELEARN")
    local plain=Menu.new(game,{{label="ONE"},{label="TWO"}},{})
    game.stack:push(plain)
    frame(game)
    check(drew("ONE") and not drew("RELEARN A MOVE"),"a plain Menu still gets the generic Modern window")
    data.gen2MenuGfx=nil
  end
  check(Moves and type(Moves.kind)=="function","module returns its detector")

  for _,p in ipairs(shots) do print("png",p) end
  if failures>0 then print(("modern moves: %d FAILED"):format(failures));os.exit(1) end
  print("modern moves: PASS")
  love.event.quit(0)
end
