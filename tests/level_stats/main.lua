-- gen2-aio: the level-up STATS card is ONE presentation.
--
-- The report: "ZOOTER grew to level 10!" showed once without stats, then a
-- second time, higher, with the STATS card.  The Modern battle panel drew
-- the line in the resolving phase and lib/gen2_modern_dialog_ui.lua took the
-- stats-box phase over with its own (higher) panel.  Now the card goes up
-- with the line, the stats-box phase keeps the battle panel, and the line's
-- own A closes both.  Covers a bench mon leveling (EXP. SHARE-style: ZOOTER
-- while KIMCHI is out) and the active mon, whose last line pages itself.
--   xvfb-run -a love tests/level_stats
io.stdout:setvbuf("no")
local root=love.filesystem.getSource():gsub("/tests/level_stats/?$","").."/"
for _,name in ipairs({"src.render.TextBox","src.ui.ChoiceBox"}) do
  local class={};class.__index=class
  package.preload[name]=function()return class end
end
-- the engine's BattleState update, reduced to the three steps that matter
-- here (ui/gen2/BattleState.lua: PromptButton, the pendingStatsMon hand-off
-- and WaitPressAorB in stats-box)
local BattleState={};BattleState.__index=BattleState
function BattleState:update()
  local a=self.game.input.a
  if self.phase=="resolving" then
    if self.messageTimer>0 then if a then self.messageTimer=0 end return end
    if self.pendingStatsMon then
      self.statsBoxMon=self.pendingStatsMon;self.pendingStatsMon=nil
      self.phase="stats-box";return
    end
    self.done=true
  elseif self.phase=="stats-box" then
    if a then self.statsBoxMon=nil;self.phase="resolving" end
  end
end
package.preload["src.ui.gen2.BattleState"]=function()return BattleState end
function love.errorhandler(err) print(debug.traceback(tostring(err)));os.exit(1) end

function love.load()
  local G=love.graphics
  local dims={1080,2520}
  G.getDimensions=function()return unpack(dims)end
  local hooks,opts={},{}
  local mod={exports={},options={get=function(_,k)return opts[k]end},hooks={wrap=function(_,name,fn,priority)
    hooks[name]=hooks[name] or {};hooks[name][#hooks[name]+1]={fn=fn,p=priority}
  end},log={info=function()end,warn=function()end}}
  mod._kimArenaDiag=function(k,v)error(k..": "..v)end
  local S=assert(loadfile(root.."lib/gen2_modern_style.lua"))()(mod)
  local draws={}
  local originalText=S.text
  S.text=function(value,font,x,y,w,align,c)
    draws[#draws+1]={text=tostring(value),font=font,x=x,y=y,w=w,align=align}
    return originalText(value,font,x,y,w,align,c)
  end
  assert(loadfile(root.."lib/gen2_modern_battle_ui.lua"))()(mod)
  assert(loadfile(root.."lib/gen2_modern_dialog_ui.lua"))()(mod)
  -- a second session in the same Lua state (Android relaunch) must not
  -- wrap BattleState.update twice
  -- (the new session gets a fresh hook registry, as the loader gives it)
  local wrapped=BattleState.update
  for k in pairs(hooks) do hooks[k]=nil end
  assert(loadfile(root.."lib/gen2_modern_battle_ui.lua"))()(mod)
  assert(loadfile(root.."lib/gen2_modern_dialog_ui.lua"))()(mod)
  assert(BattleState.update==wrapped,"update wrapped once per process")

  local function chain(name,base,...)
    local h=hooks[name] or {}
    table.sort(h,function(a,b)return a.p<b.p end)
    local fn=base
    for _,link in ipairs(h)do local nextFn=fn;fn=function(...)return link.fn(nextFn,...)end end
    return fn(...)
  end
  local function frame(state)
    draws={}
    local canvas=G.newCanvas(unpack(dims))
    G.setCanvas(canvas);G.clear(.12,.20,.18,1)
    chain("render.hud",function()end,state.game,{})
    G.setCanvas()
    canvas:release()
    local seen={}
    for _,d in ipairs(draws) do seen[#seen+1]=d end
    return seen
  end
  local function find(list,value)
    local hits={}
    for _,d in ipairs(list) do if d.text==value then hits[#hits+1]=d end end
    return hits
  end
  local function step(state,a)
    state.game.input.a=a;state:update(1/60);state.game.input.a=false
  end

  local LINE="ZOOTER grew to level 10!"
  local function newBattle(mon,timer)
    local game={input={a=false},stack={}}
    local s=setmetatable({game=game,isBattle=true,battle={},phase="resolving",
      message=LINE,messageTimer=timer,pendingStatsMon=mon},BattleState)
    game.stack.states={s};function game.stack:top()return s end
    return s
  end
  local zooter={nickname="ZOOTER",level=10,stats={attack=31,defense=22,specialAttack=19,specialDefense=20,speed=27}}

  for _,d in ipairs({{1080,2520},{2184,1968},{1280,720}}) do
    dims=d
    -- a bench mon (not the active one): the line waits for A
    local s=newBattle(zooter,90)
    local first=frame(s)
    local line1,card1=find(first,LINE),find(first,"ZOOTER  STATS")
    assert(#line1==1,"the line is drawn once ("..#line1..")")
    assert(#card1==1,"the STATS card goes up WITH the line")
    assert(#find(first,"27")==1,"the card shows the stats")
    -- one A: the line and its card close together
    step(s,true)          -- PromptButton
    step(s,false)         -- -> stats-box, closed on entry (the card was read)
    assert(s.phase=="resolving" and s.statsBoxMon==nil,"one A closes line + stats")
    step(s,false)
    assert(s.done,"the queue moves on without a second A")

    -- the active mon: its last line pages itself (no A), so the stats box
    -- holds -- and looks exactly like the frame before it (no jump)
    s=newBattle(zooter,0)
    local before=frame(s)
    step(s,false)
    assert(s.phase=="stats-box","the active mon's stats box holds for A")
    local after=frame(s)
    local a1,a2=find(before,LINE)[1],find(after,LINE)[1]
    local c1,c2=find(before,"ZOOTER  STATS")[1],find(after,"ZOOTER  STATS")[1]
    assert(a1 and a2 and #find(after,LINE)==1,"one line in both phases")
    assert(a1.x==a2.x and a1.y==a2.y,"the line does not move")
    assert(c1 and c2 and c1.x==c2.x and c1.y==c2.y,"the card does not move")
    step(s,true)
    assert(s.phase=="resolving","A closes the stats box")

    -- a mid-crawl line of a multi-level gain has no card yet
    s=newBattle(zooter,90);s.expAnim={};s.shownLevel=9
    assert(#find(frame(s),"ZOOTER  STATS")==0,"no card before the last level")
  end

  -- Modern battle panel off: the dialog presenter draws line + card itself,
  -- still as one panel in both phases
  opts.battleUiWip=false
  dims={1080,2520}
  local s=newBattle(zooter,0)
  local before=frame(s);step(s,false);local after=frame(s)
  local a1,a2=find(before,LINE)[1],find(after,LINE)[1]
  assert(a1 and a2 and a1.y==a2.y and #find(after,"ZOOTER  STATS")==1,"dialog-only path is stable too")
  print("level stats: line + STATS card in one stable panel, one A, three screen sizes PASS")
  love.event.quit(0)
end
