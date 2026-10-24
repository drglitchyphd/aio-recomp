local root = love.filesystem.getSource():gsub('/tests/overworld_hud/?$', '') .. '/'
function love.load()
 local hooks, opts, top, registered, gear, hasGear = {}, {}, nil, nil, nil, true
 local dims = {1080, 2520}
 local actualDimensions = love.graphics.getDimensions
 love.graphics.getDimensions = function() return unpack(dims) end
 package.preload['src.ui.gen2.StartMenu'] = function() return {availability=function() return {pokegear=hasGear} end} end
 local mod = {exports={}, hooks={wrap=function(_,n,f,p) hooks[n]=hooks[n] or {}; hooks[n][p]=f end}}
 mod._kimArenaOpt = function(k,d) if opts[k]~=nil then return opts[k] end; return d end
 mod._kimArenaHub = {page=function() top={}; return top end}
 local q = assert(loadfile(root..'lib/gen2_aio/quick_menu.lua'))()({mod=mod})
 local hud = assert(loadfile(root..'lib/gen2_aio/overworld_hud.lua'))()({mod=mod,diag=function(k,e) error(k..': '..e) end})
 local game = {phase='play', data={items={BICYCLE={pocket='KEY_ITEM',index=1},OLD_ROD={pocket='KEY_ITEM',index=2}}},
 save={inventory={BICYCLE=1,OLD_ROD=1},party={{hp=50,maxHp=50},{hp=15,maxHp=50},{hp=0,maxHp=50}}},
 world={player={},busy=function(self) return self.scriptBusy end,
 acceptsMenuInput=function(self) return not self.player.moving end,registerItem=function(_,id) registered=id end,
 hour=function() return 14 end,minute=function() return 32 end},
 stack={top=function() return top end,push=function(_,v) top=v end},
 pushStartMenuItem=function(_,id) gear=id; top={} end,useSelectItem=function() end}
 local count = 0
 local function check(v,msg) assert(v,msg); count=count+1 end
 local ptr=hooks['input.pointer'][200]
 local forwarded=0
 local function send(phase,x,y,id) return ptr(function() forwarded=forwarded+1 end,game,{phase=phase,x=x,y=y,id=id or 1,source='mouse',button=1}) end
 local function cell(id) for _,r in ipairs(hud.layout(game).cells) do if r.action.id==id then return r end end end
 local function tap(id) local r=cell(id); send('pressed',r.x+4,r.y+4); send('released',r.x+4,r.y+4) end
 local function step() hooks['input.step'][5](function() end,game,1/60) end
 check(#hud.layout(game).cells==4,'four available shortcuts')
 local original=hud.layout(game)
 for i=1,12 do
  game.world.player.moving=i%2==1
  local l=hud.layout(game)
  check(l and l.x==original.x and l.y==original.y,'HUD stable across walking frames')
 end
 game.world.player.moving=true
 check(not q.ready(game),'native menu gate closed mid-step')
 tap('gear');check(gear==nil,'walking tap waits for step completion')
 step();check(gear==nil,'queued shortcut cannot bypass menu input gate')
 game.world.player.moving=false;step()
 check(gear=='pokegear','queued shortcut opens once step completes');top=nil;gear=nil
 local r=cell('gear');send('pressed',r.x+4,r.y+4)
 game.world.player.moving=true;send('released',r.x+4,r.y+4)
 check(gear==nil,'a step starting during a tap defers the action')
 game.world.player.moving=false;step();check(gear=='pokegear','tap survives movement-state change');top=nil;gear=nil
 game.world.scriptBusy=true;check(hud.layout(game)==nil,'script activity hides HUD');game.world.scriptBusy=nil
 game.world.choicebox={};check(hud.layout(game)==nil,'choice box hides HUD');game.world.choicebox=nil
 tap('gear'); check(gear=='pokegear','gear opens native menu'); top=nil
 tap('bike'); check(registered=='BICYCLE','bike uses native register path')
 tap('dex'); check(top.kimAreaDex,'area opens actual area dex'); top=nil
 check(not cell('quick'),'no QUICK button (hold START opens the QUICK MENU)')
 check(q.openQuick~=nil,'QUICK MENU still reachable')
 local r=cell('gear'); gear=nil
 send('pressed',r.x+4,r.y+4); send('moved',0,0); send('released',r.x+4,r.y+4)
 check(gear==nil,'drag cancels action')
 send('pressed',r.x+4,r.y+4); top={}; send('released',r.x+4,r.y+4); top=nil
 check(gear==nil,'menu opening during gesture cancels action')
 send('pressed',r.x+4,r.y+4); ptr(function() error('cancel leaked') end,game,{phase='cancelled',id=1})
 check(gear==nil,'cancel without coordinates is safe')
 check(forwarded==0,'HUD gestures never leak to movement/A')
 send('pressed',0,0); check(forwarded==1,'world pointer passes through')
 game.world.textbox={}; check(hud.layout(game)==nil,'dialogue hidden'); game.world.textbox=nil
 game.world.battleActive=true; check(hud.layout(game)==nil,'battle hidden'); game.world.battleActive=false
 opts.overworldHud=false; check(hud.layout(game)==nil,'toggle hidden'); opts.overworldHud=true
 hasGear=false; check(not cell('gear'),'gear unavailable before unlock'); hasGear=true
 game.save.inventory.BICYCLE=nil; check(not cell('bike'),'unowned bike hidden'); game.save.inventory.BICYCLE=1
 tap('items'); check(q.wheelActive(),'items opens wheel'); check(hud.layout(game)==nil,'wheel hides hud')
 send('pressed',0,0); send('released',0,0); check(not q.wheelActive(),'mouse closes wheel')
 for _,d in ipairs({{1080,2520},{2184,1968},{1280,720},{360,640}}) do
  dims=d
  local l=hud.layout(game)
  check(l.clockPx>=20 and l.clockPx>=math.min(d[1],d[2])*.038,'clock readable at each screen size')
  check(l.statusX>=0 and l.statusX+l.statusW<=d[1],'status panel fits viewport')
  check(math.abs(l.statusW-l.w)<1 or l.statusW>l.w,'status panel matches shortcut row width')
  check(l.statusW>=l.padding*3+l.clockW+6*l.step-l.padding*.5-1,'clock and six party slots fit the status panel')
  check(math.abs(l.statusX+l.statusW-(l.x+l.w))<1,'status panel right edge aligns with shortcuts')
  for _,r in ipairs(l.cells) do check(r.x>=0 and r.x+r.w<=d[1] and r.y+r.h<=d[2],'buttons fit viewport') end
  local c=love.graphics.newCanvas(d[1],d[2]); love.graphics.setCanvas(c); love.graphics.clear(.12,.20,.18,1)
  hud.draw(game); love.graphics.setCanvas()
  local png=c:newImageData():encode('png'); local f=assert(io.open('/tmp/aio-hud-'..d[1]..'x'..d[2]..'.png','wb')); f:write(png:getString()); f:close()
 end
 print('Overworld HUD: '..count..' checks PASS; four preview renders saved')
 love.graphics.getDimensions=actualDimensions
 love.event.quit(0)
end
