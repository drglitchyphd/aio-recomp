-- gen2-aio: the Modern battle panel with KIM Touch on (Fold cover 1080x2520,
-- inner 2184x1968). The panel carries its own controls there, so the
-- floating B / START / SELECT / Poke Ball buttons stay off the battle:
--
--   * the command menu: a Poke Ball button in the panel (wild battles, when
--     a throw is possible) throws the quick ball (lib/gen2_aio/quick_ball.lua)
--   * the move list / forget list: a back button in the panel is B
--   * a move dragged onto another swaps the two through the engine's own
--     SELECT path; a still hold is the move's info; a tap picks the move
--   * nothing floating sits on the player's HUD card
--
--   xvfb-run -a love tests/battle_touch
--
-- AIO_TEST_OUTPUT: where the PNGs go (default TEMP or /tmp).
-- AIO_ROOT / AIO_RENDER_ONLY=1 / AIO_TAG: render another tree (e.g. an
-- extracted older commit) without the assertions.
io.stdout:setvbuf("no")
local root=(os.getenv("AIO_ROOT") or love.filesystem.getSource():gsub("/tests/battle_touch/?$","")):gsub("/?$","/")
local output=os.getenv("AIO_TEST_OUTPUT") or os.getenv("TEMP") or "/tmp"
local tag=os.getenv("AIO_TAG") or "battle"
local renderOnly=os.getenv("AIO_RENDER_ONLY")=="1"

local failures,passes=0,0
local function check(cond,msg)
  if renderOnly then return end
  if not cond then failures=failures+1;print("FAIL: "..msg) else passes=passes+1 end
end

-- the engine's Chrome fit, with the whole window as the playfield
local Chrome={SCREEN_W=20,SCREEN_H=18}
function Chrome.playfieldRect(w,h)return 0,0,w,h end
function Chrome.fitScaleFor(w,h,tw,th)return math.max(1,math.floor(math.min(w/(tw*8),h/(th*8))+1e-6)) end
function Chrome.fitOriginFor(w,h,s,tw,th)
  s=s or Chrome.fitScaleFor(w,h,tw,th)
  return math.floor((w-tw*8*s)/2),math.floor((h-th*8*s)/2)
end
package.preload["src.ui.gen2.Chrome"]=function()return Chrome end
package.preload["src.core.TouchControls"]=function()return {active=true,layout=function()return {} end} end
package.preload["src.core.TouchSkin"]=function()return {active=false} end

-- BattleState, reduced to the arms of ui/gen2/BattleState.lua:update this
-- test drives (command menu A, MoveSelectionScreen's SELECT / B / A, the
-- forget list's B), written the way the engine writes them
local BS={};BS.__index=BS
function BS:playerMoves()return self.battle.player.moves end
function BS:swapAllowed()return not self.transformed end
function BS:swapMoves(i,j)
  if i==j then return end
  local m=self:playerMoves();local a,b=m[i],m[j]
  if not(a and b)then return end
  m[i],m[j]=b,a
end
function BS:update()
  local input=self.game.input
  if self.phase=="menu" then
    if input:wasPressed("a") and self.menuIndex==1 then self.phase="moves" end
  elseif self.phase=="moves" then
    if input:wasPressed("select") then
      if self.moveSwapIndex then
        self:swapMoves(self.moveSwapIndex,self.moveIndex);self.moveSwapIndex=nil
      elseif self:swapAllowed() then self.moveSwapIndex=self.moveIndex end
    elseif input:wasPressed("b") then self.moveSwapIndex=nil;self.phase="menu"
    elseif input:wasPressed("a") then self.moveSwapIndex=nil;self.chosen=self.moveIndex end
  elseif self.phase=="choose-forget" then
    if input:wasPressed("b") then self.phase="stop-learning" end
  end
end
function BS:useItem(id)self.thrown=id end
function BS:refuseMenu(t)self.refused=t end
function BS:playSfx()end
function BS:panelSize()return 160,144 end
function BS:battlePanelScale(w,h)return Chrome.fitScaleFor(w,h,20,18) end
function BS:activeMon(side)return self.battle[side] end
function BS:name(m)return m.nickname end
function BS:hudHp(m)return m.hp end
function BS:hudStatus()return nil end
function BS:statusTag()return nil end
function BS:genderSymbol()return nil end
function BS:caughtMarkerVisible()return true end
package.preload["src.ui.gen2.BattleState"]=function()return BS end

function love.errorhandler(err) print(debug.traceback(tostring(err)));os.exit(1) end
function love.load()
  local G=love.graphics
  local dims={1080,2520}
  G.getDimensions=function()return dims[1],dims[2] end
  love.system.getOS=function()return "Android" end
  local T=100
  love.timer.getTime=function()return T end
  local function readFile(rel)
    local f=io.open(root..rel,"rb");if not f then return nil,"missing "..rel end
    local s=f:read("*a");f:close();return s
  end
  local hooks,opts,store={},{},{}
  local mod={exports={},generation=2,path=root:gsub("/$",""),options={get=function(_,k)return opts[k]end},
    log={info=function()end,warn=function(_,...)print("warn",...)end,error=function(_,...)print("error",...)end},
    read=function(_,rel)return readFile(rel)end,
    save={get=function(_,k)return store[k]end,set=function(_,k,v)store[k]=v end},
    hooks={wrap=function(_,name,fn,priority)
      hooks[name]=hooks[name] or {};hooks[name][#hooks[name]+1]={fn=fn,p=priority or 0}
    end}}
  mod._kantoInMotionNativeMobileHost=function()return true end
  local function run(rel,...)
    local chunk=assert(loadstring(assert(readFile(rel)),"@"..rel))
    return chunk()(...)
  end
  run("lib/gen2_aio/font.lua",{mod=mod})
  run("lib/gen2_modern_style.lua",mod)
  run("lib/gen2_modern_battle_ui.lua",mod)
  run("lib/gen2_aio/modern_hud.lua",{mod=mod})
  run("lib/gen2_aio/quick_ball.lua",{mod=mod})
  mod.exports.menuCloseRect=function()return rawget(mod,"_kimMenuClose")end
  -- the HD ball icons (lib/gen2_aio/hd_ball.lua needs the engine's anim view)
  local icons={}
  mod._kimArenaBallIcon=function(id)
    local name=({ULTRA_BALL="ultra",GREAT_BALL="great"})[id] or "poke"
    if icons[name]==nil then
      local bytes=readFile("assets/gen2_aio/balls/"..name..".png")
      icons[name]=bytes and G.newImage(love.filesystem.newFileData(bytes,name..".png")) or false
      if icons[name] then icons[name]:setFilter("nearest","nearest") end
    end
    local img=icons[name]
    if not img then return nil end
    return img,G.newQuad(6,6,18,18,img:getDimensions())
  end

  -- KIM Touch, as main.lua mounts it (a sub-mod over the bundle's mod)
  local tlog,topts,pending={},{},{}
  local tmod={id="touch",exports={},options={get=function(_,k)return topts[k] end,define=function()end},
    read=function()return nil end,
    hooks={wrap=function(_,name,fn,priority)
      hooks[name]=hooks[name] or {};hooks[name][#hooks[name]+1]={fn=fn,p=priority or 0}
    end},
    input={tap=function(_,g,b)tlog[#tlog+1]="tap:"..b;pending[b]=true end,
      press=function(_,g,b)tlog[#tlog+1]="press:"..b;pending[b]=true;return {} end,release=function()end},
    find=function()return {exports=mod.exports} end}
  setmetatable(tmod,{__index=mod})
  run("touch/main.lua",tmod)
  mod.exports.touch=tmod.exports

  local function chain(name,base,...)
    local h={}
    for i,v in ipairs(hooks[name] or {}) do h[i]=v end
    table.sort(h,function(a,b)return a.p<b.p end)
    local fn=base
    for _,link in ipairs(h)do local nextFn=fn;fn=function(...)return link.fn(nextFn,...)end end
    return fn(...)
  end

  local moveDefs={TACKLE={name="TACKLE",type="NORMAL",power=35,accuracy=95,pp=35},
    EMBER={name="EMBER",type="FIRE",power=40,accuracy=100,pp=25},
    SMOKESCREEN={name="SMOKESCREEN",type="NORMAL",power=0,accuracy=100,pp=20},
    QUICK_ATTACK={name="QUICK ATTACK",type="NORMAL",power=40,accuracy=100,pp=30}}
  local function newBattle(phase)
    local input={}
    function input:wasPressed(b)return pending[b]==true end
    local game={input=input,options={},data={moves=moveDefs,
      items={POKE_BALL={pocket="BALL"},ULTRA_BALL={pocket="BALL"},MASTER_BALL={pocket="BALL"}}}}
    local player={nickname="KIMCHI",species="CYNDAQUIL",level=16,hp=27,maxHp=47,
      moves={{id="TACKLE",pp=30,maxPp=35},{id="EMBER",pp=20,maxPp=25},
        {id="SMOKESCREEN",pp=18,maxPp=20},{id="QUICK_ATTACK",pp=29,maxPp=30}}}
    local enemy={nickname="RATTATA",species="RATTATA",level=12,hp=30,maxHp=30}
    local s=setmetatable({isBattle=true,game=game,phase=phase,menuIndex=1,moveIndex=1,forgetIndex=1,
      slideFrame=80,showEnemyHud=true,showPlayerHud=true,shownExp=40,
      save={inventory={POKE_BALL=5,ULTRA_BALL=2}},
      battle={wild=true,player=player,enemy=enemy,party={player}}},BS)
    game.stack={states={s}}
    function game.stack:top()return self.states[#self.states] end
    mod._kantoInMotionActiveGame=game
    return s,game
  end
  local function step(s)s:update();pending={} end

  -- a stand-in battle field where the engine draws its own
  local function field()
    local W,H=dims[1],dims[2]
    local sc=Chrome.fitScaleFor(W,H,20,18)
    local ox,oy=Chrome.fitOriginFor(W,H,sc,20,18)
    G.setColor(.55,.75,.45,1);G.rectangle("fill",ox,oy,160*sc,144*sc)
    G.setColor(.35,.55,.3,1)
    G.ellipse("fill",ox+120*sc,oy+50*sc,28*sc,8*sc);G.ellipse("fill",ox+40*sc,oy+100*sc,34*sc,10*sc)
    G.setColor(.6,.45,.3,1);G.circle("fill",ox+120*sc,oy+36*sc,14*sc);G.circle("fill",ox+40*sc,oy+82*sc,20*sc)
  end
  local shots={}
  local function frame(s,game,name)
    local canvas=G.newCanvas(dims[1],dims[2])
    G.setCanvas(canvas);G.clear(.08,.10,.14,1)
    chain("render.hud",function()field()end,game,{})
    G.setCanvas()
    if name then
      local path=output.."/aio-"..tag.."-"..name.."-"..dims[1].."x"..dims[2]..".png"
      local file=assert(io.open(path,"wb"))
      file:write(canvas:newImageData():encode("png"):getString());file:close()
      shots[#shots+1]=path
    end
    canvas:release()
  end
  local ptr
  for _,h in ipairs(hooks["input.pointer"])do if h.p==10 then ptr=h.fn end end
  local function send(game,phase,x,y,id)
    return ptr(function()tlog[#tlog+1]="next" end,game,{phase=phase,x=x,y=y,id=id or 1,source="touch"})
  end
  local function tapAt(s,game,x,y)
    tlog={};send(game,"pressed",x,y);T=T+0.08;send(game,"released",x,y);frame(s,game)
    return table.concat(tlog,",")
  end
  local function ui()return mod.exports.gen2ModernBattleUi.tapTargets() end
  local function cell(kind,index)
    for _,c in ipairs(ui().cells or {})do if c.kind==kind and (index==nil or c.index==index) then return c end end
  end
  local function mid(c)return c.x+c.w/2,c.y+c.h/2 end
  local function overlaps(a,b)
    return a.x<b.x+b.w and a.x+a.w>b.x and a.y<b.y+b.h and a.y+a.h>b.y
  end
  local function zoneRect(z)
    if z.r then local r=z.r*1.15 return {x=z.x-r,y=z.y-r,w=r*2,h=r*2} end
    return {x=z.x-z.w/2,y=z.y-z.h/2,w=z.w,h=z.h}
  end
  -- every floating button clear of both HUD cards
  local function floatingClear(game,what)
    local R=mod._kimArenaHudRects
    for k,z in pairs(tmod.exports.shownButtons(game))do
      for _,side in ipairs({"player","enemy"})do
        check(not(R and R[side] and overlaps(zoneRect(z),R[side])),
          what..": floating "..k.." clear of the "..side.." card")
      end
    end
  end
  local function shownKeys(game)
    local out={}
    for k in pairs(tmod.exports.shownButtons(game))do out[#out+1]=k end
    table.sort(out);return table.concat(out,",")
  end

  for _,d in ipairs({{1080,2520},{2184,1968}})do
    dims=d
    local size=d[1].."x"..d[2]
    -- ---------------------------------------------------- command menu
    local s,game=newBattle("menu")
    frame(s,game);frame(s,game,"menu")
    local ball=cell("ball")
    check(ball~=nil,size..": the command panel carries a Poke Ball button")
    check(shownKeys(game)=="",size..": command menu: no floating buttons ("..shownKeys(game)..")")
    local panel=ui().panel
    if ball then
      check(ball.x>=panel.x and ball.x+ball.w<=panel.x+panel.w and ball.y>=panel.y
        and ball.y+ball.h<=panel.y+panel.h,size..": the ball button sits inside the panel")
      for i=1,4 do
        local c=cell("menu",i)
        check(c and not overlaps(c,ball),size..": ball clear of command "..i)
      end
      local R=mod._kimArenaHudRects
      check(R and not overlaps(ball,R.player),size..": ball clear of the player card")
      check(tapAt(s,game,mid(ball))=="",size..": a tap on the ball presses no button")
      step(s)
      check(s.thrown=="ULTRA_BALL",size..": the ball button throws the quick ball ("..tostring(s.thrown)..")")
    end
    -- no throw possible (a trainer battle): no ball, the commands get the width
    s,game=newBattle("menu");s.battle.wild=false
    frame(s,game);frame(s,game,"menu-trainer")
    check(cell("ball")==nil,size..": no ball button in a trainer battle")
    check(shownKeys(game)=="",size..": trainer command menu: no floating buttons")
    -- FIGHT still opens the moves
    s,game=newBattle("menu");frame(s,game)
    check(tapAt(s,game,mid(cell("menu",1)))=="tap:a",size..": FIGHT is A");step(s)
    check(s.phase=="moves",size..": FIGHT opens the move list")

    -- ---------------------------------------------------- move list
    frame(s,game);frame(s,game,"moves")
    local back=mod._kimMenuClose
    check(back and back.state==s and back.back==true,size..": the move list shows a back button")
    check(shownKeys(game)=="",size..": move list: no floating buttons ("..shownKeys(game)..")")
    floatingClear(game,size.." moves")
    if back then
      panel=ui().panel
      check(back.x>=panel.x and back.x+back.w<=panel.x+panel.w and back.y>=panel.y
        and back.y+back.h<=panel.y+panel.h,size..": the back button sits inside the panel")
      for i=1,4 do check(not overlaps(cell("move",i),back.hit),size..": back's hit area clear of move "..i) end
      check(tapAt(s,game,back.x+back.w/2,back.y+back.h/2)=="tap:b",size..": back is exactly B");step(s)
      check(s.phase=="menu",size..": back returns to the commands")
    end

    -- a tap on a move picks it
    s,game=newBattle("moves");frame(s,game);frame(s,game)
    check(tapAt(s,game,mid(cell("move",2)))=="tap:a" and s.moveIndex==2,size..": a tap picks the move");step(s)
    check(s.chosen==2,size..": the tapped move is used")

    -- a drag from move 1 onto move 4 swaps them, through SELECT
    s,game=newBattle("moves");frame(s,game);frame(s,game)
    local a,b=cell("move",1),cell("move",4)
    local ax,ay=mid(a);local bx,by=mid(b)
    tlog={};send(game,"pressed",ax,ay)
    for i=1,8 do T=T+0.03;send(game,"moved",ax+(bx-ax)*i/8,ay+(by-ay)*i/8);frame(s,game) end
    check(s.moveSwapIndex==1 and s.moveIndex==4,size..": dragging marks the move and the cursor follows")
    frame(s,game,"moves-drag")
    T=T+0.6;frame(s,game)   -- held over the target past the long-press time
    check(tmod.exports.popupShown==nil or not tmod.exports.popupShown(),size..": a drag shows no move info")
    send(game,"released",bx,by)
    check(table.concat(tlog,",")=="tap:select",size..": the drop is one SELECT ("..table.concat(tlog,",")..")")
    step(s)
    local ids={};for i,m in ipairs(s.battle.player.moves)do ids[i]=m.id end
    check(ids[1]=="QUICK_ATTACK" and ids[4]=="TACKLE",size..": moves 1 and 4 swapped ("..table.concat(ids,",")..")")
    check(s.moveSwapIndex==nil and s.chosen==nil and s.phase=="moves",size..": no move used, still in the list")
    check(s.battle.player.moves[1].pp==29 and s.battle.player.moves[4].pp==30,size..": PP moves with its move")

    -- dropped back on itself: nothing changes, nothing pressed
    s,game=newBattle("moves");frame(s,game);frame(s,game)
    a=cell("move",2);ax,ay=mid(a)
    tlog={};send(game,"pressed",ax,ay)
    for i=1,6 do T=T+0.03;send(game,"moved",ax+a.w*0.8*i/6,ay);frame(s,game) end
    for i=1,6 do T=T+0.03;send(game,"moved",ax+a.w*0.8*(6-i)/6,ay);frame(s,game) end
    send(game,"released",ax,ay)
    check(#tlog==0 and s.moveSwapIndex==nil and s.moveIndex==2,size..": a drag back home changes nothing ("..table.concat(tlog,",")..")")

    -- a still hold is the move's info, never a pick
    s,game=newBattle("moves");frame(s,game);frame(s,game)
    a=cell("move",3);ax,ay=mid(a)
    tlog={};send(game,"pressed",ax,ay);T=T+0.6;frame(s,game)
    check(tmod.exports.popupShown and tmod.exports.popupShown(),size..": a still hold opens the move's info")
    frame(s,game,"moves-info")
    send(game,"released",ax,ay)
    check(#tlog==0 and s.moveSwapIndex==nil,size..": letting go of the hold presses nothing")
    tlog={};send(game,"pressed",ax,ay);send(game,"released",ax,ay)   -- closes the card
    -- a transformed mon cannot reorder (engine swapAllowed): the drag does nothing
    s,game=newBattle("moves");s.transformed=true;frame(s,game);frame(s,game)
    a,b=cell("move",1),cell("move",2);ax,ay=mid(a);bx,by=mid(b)
    tlog={};send(game,"pressed",ax,ay)
    for i=1,6 do T=T+0.03;send(game,"moved",ax+(bx-ax)*i/6,ay+(by-ay)*i/6);frame(s,game) end
    send(game,"released",bx,by)
    check(#tlog==0 and s.battle.player.moves[1].id=="TACKLE",size..": transformed: no reorder, no A")

    -- ---------------------------------------------------- forget list
    s,game=newBattle("choose-forget")
    s.pendingLearn={index=1,moveName="FLAME WHEEL"};s.messageTimer=0
    s.message="Which move should be forgotten?"
    frame(s,game);frame(s,game,"forget")
    back=mod._kimMenuClose
    check(back and back.state==s and back.back==true,size..": the forget list shows a back button")
    check(shownKeys(game)=="",size..": forget list: no floating buttons")
    if back then
      for i=1,4 do check(not overlaps(cell("forget",i),back.hit),size..": back clear of forget row "..i) end
      check(tapAt(s,game,back.x+back.w/2,back.y+back.h/2)=="tap:b",size..": forget back is B");step(s)
      check(s.phase=="stop-learning",size..": B asks to stop learning")
    end

    -- ---------------------------------------------------- the panel's own
    -- message phases keep B (animation skip), clear of the HUD cards
    s,game=newBattle("resolving");s.message="KIMCHI used EMBER!";s.messageTimer=30
    frame(s,game);frame(s,game,"message")
    check(tmod.exports.shownButtons(game).b~=nil,size..": a message phase keeps the floating B")
    floatingClear(game,size.." message")
    for _,h in ipairs({"low","mid","high"})do
      topts.touchButtonHeight=h;frame(s,game)
      floatingClear(game,size.." message "..h)
    end
    topts.touchButtonHeight=nil

    -- MODERN battle panel off (the native panel): the floating buttons are back
    opts.battleUiWip=false
    s,game=newBattle("menu");frame(s,game);frame(s,game)
    local sb=tmod.exports.shownButtons(game)
    check(sb.b and sb.ball and sb.select,size..": native panel: floating B, SELECT and ball stay")
    opts.battleUiWip=nil
    -- TAP MENUS off: the panel's cells are not tappable, so no in-panel controls
    topts.touchBattleTap=false
    s,game=newBattle("menu");frame(s,game);frame(s,game)
    check(cell("ball")==nil and tmod.exports.shownButtons(game).ball~=nil,size..": TAP MENUS off: the floating ball stays")
    s,game=newBattle("moves");frame(s,game);frame(s,game)
    check(mod._kimMenuClose==nil and tmod.exports.shownButtons(game).b~=nil,size..": TAP MENUS off: floating B in the move list")
    topts.touchBattleTap=nil
  end

  -- no touch (desktop): no in-panel controls, nothing changes
  dims={1280,720}
  require("src.core.TouchControls").active=false
  local s,game=newBattle("menu");frame(s,game);frame(s,game,"desktop-menu")
  check(cell("ball")==nil,"desktop: no ball button in the panel")
  s,game=newBattle("moves");frame(s,game);frame(s,game,"desktop-moves")
  check(mod._kimMenuClose==nil,"desktop: no back button in the move list")
  for _,p in ipairs(shots)do print("wrote "..p)end
  if failures>0 then print(("battle touch: %d FAIL, %d ok"):format(failures,passes));os.exit(1) end
  print(("battle touch: %d checks PASS"):format(passes))
  love.event.quit(0)
end
