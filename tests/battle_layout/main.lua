-- gen2-aio: the Modern battle layout holds still, and YES / NO sits inside
-- the message box (Fold cover 1080x2520, inner 2184x1968, a desktop window).
--
-- The reports: a battle YES / NO ("Will KRIS change POKeMON?") opened its
-- own window above the message box and the player's HP card and the touch
-- controls moved up; the same happened, a little, when FIGHT opened the move
-- list and while a Poke Ball was thrown.  Now:
--
--   * the battle panel is ONE rect for the whole battle (command menu, move
--     list, messages, the ball throw with no message up, YES / NO, the
--     forget list), so the HP cards and the floating touch controls never
--     move between phases
--   * YES / NO are two buttons on the right of that same panel, the prompt
--     on the left; a tap answers through the engine (the index, then A),
--     B is NO, the keys still move the cursor
--   * an overworld TextBox + ChoiceBox puts YES / NO inside its text box too,
--     and the box does not move when the question opens
--
--   xvfb-run -a love tests/battle_layout
--
-- AIO_TEST_OUTPUT: where the PNGs go (default TEMP or /tmp).
-- AIO_ROOT / AIO_RENDER_ONLY=1 / AIO_TAG: render another tree (e.g. an
-- extracted older commit) without the assertions.
io.stdout:setvbuf("no")
local root=(os.getenv("AIO_ROOT") or love.filesystem.getSource():gsub("/tests/battle_layout/?$","")):gsub("/?$","/")
local output=os.getenv("AIO_TEST_OUTPUT") or os.getenv("TEMP") or "/tmp"
local tag=os.getenv("AIO_TAG") or "layout"
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
-- Chrome.wrap at the battle's TEXT_WIDTH (18 columns), word by word
local function wrap18(text)
  local out={}
  for para in (tostring(text or "").."\n"):gmatch("([^\n]*)\n") do
    local line=""
    for word in para:gmatch("%S+") do
      local try=line=="" and word or (line.." "..word)
      if #try>18 and line~="" then out[#out+1]=line;line=word else line=try end
    end
    if line~="" then out[#out+1]=line end
  end
  return out
end
package.preload["src.ui.gen2.Chrome"]=function()return Chrome end
package.preload["src.core.TouchControls"]=function()return {active=true,layout=function()return {} end} end
package.preload["src.core.TouchSkin"]=function()return {active=false} end
local TextBox={};TextBox.__index=TextBox
local ChoiceBox={};ChoiceBox.__index=ChoiceBox
package.preload["src.render.TextBox"]=function()return TextBox end
package.preload["src.ui.ChoiceBox"]=function()return ChoiceBox end

-- BattleState, reduced to the arms of ui/gen2/BattleState.lua:update this
-- test drives, written the way the engine writes them (the YES / NO arms:
-- the prompt holds for A while it types, up/down flip the cursor, B is NO,
-- A answers the highlighted row)
local BS={};BS.__index=BS
function BS:playerMoves()return self.battle.player.moves end
function BS:messageLines()return wrap18(self.message) end
local ASK={["ask-shift"]="shiftIndex",["ask-nickname"]="nicknameIndex",
  ["ask-next-mon"]="nextMonIndex",["ask-forget"]="forgetChoice",["stop-learning"]="forgetChoice"}
function BS:update()
  local input=self.game.input
  local field=ASK[self.phase]
  if self.phase=="menu" then
    if input:wasPressed("a") and self.menuIndex==1 then self.phase="moves" end
  elseif self.phase=="moves" then
    if input:wasPressed("b") then self.phase="menu" end
  elseif field then
    if (self.messageTimer or 0)>0 then
      if input:wasPressed("a") or input:wasPressed("b") then self.messageTimer=0 end
      return
    end
    if input:wasPressed("up") or input:wasPressed("down") then
      self[field]=self[field]==1 and 2 or 1
    elseif input:wasPressed("b") then
      self.answer="NO";self.phase="resolving"
    elseif input:wasPressed("a") then
      self.answer=self[field]==1 and "YES" or "NO";self.phase="resolving"
    end
  end
end
function BS:useItem(id)self.thrown=id end
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
  local mobile=true
  love.system.getOS=function()return mobile and "Android" or "Linux" end
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
  mod._kantoInMotionNativeMobileHost=function()return mobile end
  local function run(rel,...)
    local chunk=assert(loadstring(assert(readFile(rel)),"@"..rel))
    return chunk()(...)
  end
  run("lib/gen2_aio/font.lua",{mod=mod})
  local S=run("lib/gen2_modern_style.lua",mod) or mod._kantoInMotionGen2Ui
  -- every panel and text drawn, for the box / fit checks
  local panels,texts={},{}
  local oPanel,oText=S.panel,S.text
  S.panel=function(x,y,w,h,...)panels[#panels+1]={x=x,y=y,w=w,h=h};return oPanel(x,y,w,h,...)end
  S.text=function(value,font,x,y,w,...)
    texts[#texts+1]={text=tostring(value),font=font,x=x,y=y,w=w}
    return oText(value,font,x,y,w,...)
  end
  run("lib/gen2_modern_battle_ui.lua",mod)
  run("lib/gen2_modern_dialog_ui.lua",mod)
  run("lib/gen2_aio/modern_hud.lua",{mod=mod})
  run("lib/gen2_aio/quick_ball.lua",{mod=mod})
  mod.exports.menuCloseRect=function()return rawget(mod,"_kimMenuClose")end
  mod.exports.screenTapTargets=function()return rawget(mod,"_kimScreenTapTargets")end

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
  local function newGame()
    local input={}
    function input:wasPressed(b)return pending[b]==true end
    local game={input=input,options={},data={moves=moveDefs,
      items={POKE_BALL={pocket="BALL"},ULTRA_BALL={pocket="BALL"}}}}
    game.stack={states={}}
    function game.stack:top()return self.states[#self.states] end
    mod._kantoInMotionActiveGame=game
    return game
  end
  local function newBattle(phase,fields)
    local game=newGame()
    local player={nickname="KIMCHI",species="CYNDAQUIL",level=16,hp=27,maxHp=47,
      moves={{id="TACKLE",pp=30,maxPp=35},{id="EMBER",pp=20,maxPp=25},
        {id="SMOKESCREEN",pp=18,maxPp=20},{id="QUICK_ATTACK",pp=29,maxPp=30}}}
    local enemy={nickname="RATTATA",species="RATTATA",level=12,hp=30,maxHp=30}
    local s=setmetatable({isBattle=true,game=game,phase=phase,menuIndex=1,moveIndex=1,forgetIndex=1,
      slideFrame=80,showEnemyHud=true,showPlayerHud=true,shownExp=40,messageTimer=0,
      shiftIndex=1,nicknameIndex=1,nextMonIndex=1,forgetChoice=1,
      save={inventory={POKE_BALL=5,ULTRA_BALL=2}},
      battle={wild=true,player=player,enemy=enemy,party={player}}},BS)
    for k,v in pairs(fields or {})do s[k]=v end
    game.stack.states={s}
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
  -- floating touch controls are drawn by touch's render.hud link; draw
  -- their hit rects too, so the PNGs show where they are
  local function frame(game,name)
    local canvas=G.newCanvas(dims[1],dims[2])
    G.setCanvas(canvas);G.clear(.08,.10,.14,1)
    panels,texts={},{}
    chain("render.hud",function()field()end,game,{})
    if name then
      G.setColor(1,.2,.8,.9);G.setLineWidth(3)
      for _,z in pairs(tmod.exports.shownButtons(game))do
        if z.r then G.circle("line",z.x,z.y,z.r) else G.rectangle("line",z.x-z.w/2,z.y-z.h/2,z.w,z.h) end
      end
    end
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
  local function tapAt(game,x,y)
    tlog={};send(game,"pressed",x,y);T=T+0.08;send(game,"released",x,y);frame(game)
    return table.concat(tlog,",")
  end
  local function ui()return mod.exports.gen2ModernBattleUi.tapTargets() end
  local function mid(c)return c.x+c.w/2,c.y+c.h/2 end
  local function inside(a,b,slack)
    slack=slack or 0.5
    return a.x>=b.x-slack and a.y>=b.y-slack and a.x+a.w<=b.x+b.w+slack and a.y+a.h<=b.y+b.h+slack
  end
  local function overlaps(a,b)
    return a.x<b.x+b.w and a.x+a.w>b.x and a.y<b.y+b.h and a.y+a.h>b.y
  end
  local function same(a,b)
    if not(a and b)then return a==b end
    for _,k in ipairs({"x","y","w","h","r"})do
      if math.abs((tonumber(a[k]) or 0)-(tonumber(b[k]) or 0))>0.01 then return false end
    end
    return true
  end
  local function fmt(r)
    if not r then return "nil" end
    return ("%.0f,%.0f %.0fx%.0f"):format(r.x or 0,r.y or 0,r.w or (r.r or 0)*2,r.h or (r.r or 0)*2)
  end
  -- the YES / NO cells a tap can answer (the generic screen targets)
  local function yesNoCells(s)
    local t=rawget(mod,"_kimScreenTapTargets")
    if not(t and t.state==s and t.time==T)then return {} end
    return t.cells or {}
  end

  local PHASES={
    {name="menu",phase="menu"},
    {name="moves",phase="moves"},
    {name="message",phase="resolving",f={message="KIMCHI used EMBER!",messageTimer=30}},
    -- the ball throw: the animation runs with the box empty, then the lines
    {name="throw",phase="resolving",f={message=""}},
    {name="throw-msg",phase="resolving",f={message="KRIS used ULTRA BALL!",messageTimer=30}},
    {name="caught",phase="resolving",f={message="Gotcha! RATTATA was caught!",messageTimer=30}},
    {name="shift-intro",phase="shift-intro",f={message="JOEY is about to use RATTATA.",messageTimer=30}},
    {name="yesno-typing",phase="ask-shift",f={message="Will KRIS change POKéMON?",messageTimer=20}},
    {name="yesno",phase="ask-shift",f={message="Will KRIS change POKéMON?"},ask=true},
    {name="next-mon",phase="ask-next-mon",f={message="Use next POKéMON?"},ask=true},
    {name="nickname",phase="ask-nickname",f={message="Give a nickname to RATTATA?"},ask=true},
    {name="stop-learning",phase="stop-learning",f={message="Stop learning FLAME WHEEL?"},ask=true},
    {name="ask-forget",phase="ask-forget",f={message="Delete an older move to make room for FLAME WHEEL?"},ask=true},
    {name="forget",phase="choose-forget",f={message="Which move should be forgotten?",
      pendingLearn={index=1,moveName="FLAME WHEEL"}}},
  }

  local SIZES={{1080,2520,true},{2184,1968,true},{1280,720,false}}
  for _,d in ipairs(SIZES)do
    dims={d[1],d[2]};mobile=d[3]
    require("src.core.TouchControls").active=mobile
    local size=d[1].."x"..d[2]
    -- ------------------------------------------- one layout for the battle
    local ref,refButtons,refYes={},{},nil
    for _,P in ipairs(PHASES)do
      local s,game=newBattle(P.phase,P.f)
      frame(game);frame(game,P.name)
      local R=mod._kimArenaHudRects
      local panel=ui().panel
      if not ref.player then
        ref={player=R.player,enemy=R.enemy,panel=panel}
        print(("%s panel %s  player %s  enemy %s"):format(size,fmt(panel),fmt(R.player),fmt(R.enemy)))
      end
      check(same(R.player,ref.player),size.." "..P.name..": the player card stays put ("..fmt(R.player).." vs "..fmt(ref.player)..")")
      check(same(R.enemy,ref.enemy),size.." "..P.name..": the enemy card stays put")
      check(same(panel,ref.panel),size.." "..P.name..": the battle panel keeps its rect ("..fmt(panel).." vs "..fmt(ref.panel)..")")
      check(R.panelTop==(ref.panel and ref.panel.y),size.." "..P.name..": the camera's panel top stays put")
      -- every floating control a phase shows sits where it sat in any other
      for k,z in pairs(tmod.exports.shownButtons(game))do
        if refButtons[k] then
          check(same(z,refButtons[k].z),size.." "..P.name..": floating "..k.." stays put ("..fmt(z).." vs "..fmt(refButtons[k].z).." in "..refButtons[k].from..")")
        else refButtons[k]={z=z,from=P.name} end
        local zr=z.r and {x=z.x-z.r*1.15,y=z.y-z.r*1.15,w=z.r*2.3,h=z.r*2.3} or {x=z.x-z.w/2,y=z.y-z.h/2,w=z.w,h=z.h}
        for _,side in ipairs({"player","enemy"})do
          check(not overlaps(zr,R[side]),size.." "..P.name..": floating "..k.." clear of the "..side.." card")
        end
        check(not(panel and overlaps(zr,panel)),size.." "..P.name..": floating "..k.." clear of the panel ("..fmt(zr).." / "..fmt(panel)..")")
      end
      -- exactly one window besides the two HP cards: no separate YES / NO
      -- box anywhere on screen
      local windows=0
      for _,q in ipairs(panels)do
        if not(same(q,R.player) or same(q,R.enemy))then windows=windows+1 end
      end
      check(windows<=1,size.." "..P.name..": no second window ("..windows.." windows)")
      if P.ask then
        if mobile then
          local n=0;for _ in pairs(tmod.exports.shownButtons(game))do n=n+1 end
          check(n==0,size.." "..P.name..": the NO button is the B: no floating buttons over the question ("..n..")")
        end
        local cells=yesNoCells(s)
        refYes=refYes or cells
        check(#cells==2,size.." "..P.name..": YES and NO are tappable ("..#cells..")")
        for i,c in ipairs(cells)do
          check(panel and inside(c,panel),size.." "..P.name..": button "..i.." inside the message box ("..fmt(c).." in "..fmt(panel)..")")
          if mobile then
            -- a comfortable thumb target: at least ~7 mm on a phone
            -- (the Fold cover is ~2.6 px per dp: 48 dp = 125 px)
            local minH=d[1]==1080 and 120 or 100
            check(c.h>=minH and c.w>=c.h*1.5,size.." "..P.name..": button "..i.." is thumb-sized ("..fmt(c)..")")
          end
        end
        if #cells==2 then check(not overlaps(cells[1],cells[2]),size.." "..P.name..": YES and NO apart") end
        -- the prompt fits on the left, clear of the buttons
        local lines=wrap18(P.f.message)
        for _,line in ipairs(lines)do
          local hit
          for _,t in ipairs(texts)do if t.text==line then hit=t end end
          check(hit~=nil,size.." "..P.name..": prompt line '"..line.."' drawn")
          if hit and #cells==2 then
            local right=hit.x+hit.font:getWidth(line)
            local clear=true
            for _,c in ipairs(cells)do
              if right>c.x and hit.x<c.x+c.w and hit.y+hit.font:getHeight()>c.y and hit.y<c.y+c.h then clear=false end
            end
            check(clear and panel and right<=panel.x+panel.w,size.." "..P.name..": '"..line.."' fits beside the buttons")
          end
        end
      elseif P.phase:match("^ask") then
        check(#yesNoCells(s)==0,size.." "..P.name..": no YES / NO while the prompt still types")
      end
    end

    -- ------------------------------------------- the biggest BATTLE TEXT
    -- SIZE: an 18-column line no longer fits beside the buttons, so they go
    -- in a row along the bottom of the same panel (which still never moves)
    opts.battleTextScale="200"
    local s,game=newBattle("menu");frame(game);frame(game)
    local bigPanel=ui().panel
    s,game=newBattle("ask-nickname",{message="Give a nickname to RATTATA?"})
    frame(game);frame(game,"yesno-text200")
    local yn=ui().yesNo
    local cells=yesNoCells(s)
    check(same(ui().panel,bigPanel),size.." text 200%: the panel keeps its rect")
    check(#cells==2,size.." text 200%: YES / NO tappable")
    for i,c in ipairs(cells)do check(inside(c,bigPanel),size.." text 200%: button "..i.." inside the panel") end
    for _,line in ipairs(wrap18("Give a nickname to RATTATA?"))do
      for _,t in ipairs(texts)do
        if t.text==line then
          for _,c in ipairs(cells)do
            check(not(t.x+t.font:getWidth(line)>c.x and t.y<c.y+c.h and t.y+t.font:getHeight()>c.y),
              size.." text 200%: '"..line.."' clear of the buttons ("..tostring(yn and yn.mode)..")")
          end
        end
      end
    end
    print(("%s YES/NO at 100%%: %s / %s"):format(size,fmt(refYes and refYes[1]),fmt(refYes and refYes[2])))
    print(("%s YES/NO at 200%% (%s): %s / %s"):format(size,tostring(yn and yn.mode),fmt(cells[1]),fmt(cells[2])))
    opts.battleTextScale=nil

    -- ------------------------------------------- answering
    -- a tap on NO answers NO (index 2, then the engine's own A)
    s,game=newBattle("ask-shift",{message="Will KRIS change POKéMON?"})
    frame(game);frame(game)
    cells=yesNoCells(s)
    if #cells==2 and mobile and not renderOnly then
      check(tapAt(game,mid(cells[2]))=="tap:a" and s.shiftIndex==2,size..": a tap on NO is the index then A");step(s)
      check(s.answer=="NO",size..": the tap answered NO ("..tostring(s.answer)..")")
      s,game=newBattle("ask-shift",{message="Will KRIS change POKéMON?",shiftIndex=2})
      frame(game);frame(game)
      check(tapAt(game,mid(yesNoCells(s)[1]))=="tap:a" and s.shiftIndex==1,size..": a tap on YES");step(s)
      check(s.answer=="YES",size..": the tap answered YES")
      for _,P in ipairs(PHASES)do
        if P.ask then
          s,game=newBattle(P.phase,P.f);frame(game);frame(game)
          local c=yesNoCells(s)
          if #c==2 then tapAt(game,mid(c[2]));step(s) end
          check(s.answer=="NO",size.." "..P.name..": a tap on NO answers it")
        end
      end
      -- a tap that misses both is A (the highlighted answer), as before
      s,game=newBattle("ask-shift",{message="Will KRIS change POKéMON?"})
      frame(game);frame(game)
      local p=ui().panel or {x=0,y=0,w=dims[1],h=dims[2]}
      check(tapAt(game,p.x+p.w*0.2,p.y+p.h*0.5)=="tap:a",size..": a tap on the prompt is A");step(s)
      check(s.answer=="YES",size..": ... which answers the highlighted YES")
      -- stale cells: once answered, the old buttons answer nothing
      s,game=newBattle("ask-shift",{message="Will KRIS change POKéMON?"})
      frame(game);frame(game)
      local old=yesNoCells(s)[2]
      s.phase="resolving";s.message="KRIS sent out KIMCHI!"
      tlog={};send(game,"pressed",mid(old));T=T+0.08;send(game,"released",mid(old))
      check(s.shiftIndex==1,size..": the closed question's NO no longer sets the index")
    end
    -- keyboard / pad: unchanged
    s,game=newBattle("ask-shift",{message="Will KRIS change POKéMON?"})
    frame(game);pending={down=true};step(s);frame(game,"yesno-no")
    check(s.shiftIndex==2,size..": down moves to NO")
    pending={a=true};step(s)
    check(s.answer=="NO",size..": A answers the highlighted NO")
    s,game=newBattle("ask-nickname",{message="Give a nickname to RATTATA?"})
    frame(game);pending={b=true};step(s)
    check(s.answer=="NO",size..": B is NO")
    s,game=newBattle("ask-nickname",{message="Give a nickname to RATTATA?"})
    frame(game);pending={a=true};step(s)
    check(s.answer=="YES",size..": A on the opening cursor is YES")

    -- ------------------------------------------- overworld YES / NO
    local game2=newGame()
    local box=setmetatable({isTextBox=true,pages={{"Do you want to","save the game?"}},pageIndex=1,
      lineIndex=2,charIndex=99,shown={1,2}},TextBox)
    game2.stack.states={box}
    frame(game2,"overworld-text")
    local textPanel=panels[1]
    local choice=setmetatable({index=1,labels={"YES","NO"}},ChoiceBox)
    game2.stack.states={box,choice}
    frame(game2);frame(game2,"overworld-yesno")
    check(#panels==1,size..": overworld YES / NO: one window ("..#panels..")")
    -- the box keeps its place and height; the buttons widen it to the right
    local q=panels[1]
    check(q and textPanel and q.x==textPanel.x and q.y==textPanel.y and q.h==textPanel.h and q.w>textPanel.w,
      size..": overworld text box keeps its place, widened to the right ("..fmt(q).." vs "..fmt(textPanel)..")")
    check(q and q.x+q.w<=dims[1],size..": overworld box on screen")
    local oc=yesNoCells(choice)
    check(#oc==2,size..": overworld YES / NO tappable")
    for i,c in ipairs(oc)do
      check(panels[1] and inside(c,panels[1]),size..": overworld button "..i.." inside the text box")
      if mobile then check(c.h>=90,size..": overworld button "..i.." thumb-sized ("..fmt(c)..")") end
    end
    for _,line in ipairs(box.pages[1])do
      for _,t in ipairs(texts)do
        if t.text==line then
          for _,c in ipairs(oc)do
            check(not(t.x+t.font:getWidth(line)>c.x and t.y<c.y+c.h and t.y+t.font:getHeight()>c.y),
              size..": overworld '"..line.."' clear of the buttons")
          end
        end
      end
    end
    if #oc==2 and mobile then
      check(tapAt(game2,mid(oc[2]))=="tap:a" and choice.index==2,size..": overworld tap on NO")
    end

    -- ------------------------------------------- MODERN battle panel off:
    -- the dialogue presenter still asks (its own box), nothing lost
    opts.battleUiWip=false
    s,game=newBattle("ask-shift",{message="Will KRIS change POKéMON?"})
    frame(game);frame(game,"panel-off-yesno")
    check(#yesNoCells(s)==2,size..": battle panel off: the dialogue YES / NO still answers")
    opts.battleUiWip=nil
  end

  for _,p in ipairs(shots)do print("wrote "..p)end
  if failures>0 then print(("battle layout: %d FAIL, %d ok"):format(failures,passes));os.exit(1) end
  print(("battle layout: %d checks PASS"):format(passes))
  love.event.quit(0)
end
