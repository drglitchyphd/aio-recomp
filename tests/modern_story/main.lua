-- gen2-aio 0.9.75: the Modern story screens (lib/gen2_aio/modern_story.lua)
-- over the ENGINE's own HallOfFame, Diploma, EggHatchAnim, UnownPuzzle and
-- UnownPrinter.
--
--   AIO_ENGINE_SRC=/path/to/engine/src xvfb-run -a love tests/modern_story
--
-- AIO_ENGINE_SRC is the engine checkout's root (the folder holding src/).
-- The real screen classes and src/core/gen2/HallOfFame.lua, Unown.lua,
-- Strings.lua, MonAnimView, SpriteAnims and TileSheet run; only rendering,
-- audio and asset modules are stubbed (pics are generated stand-ins). Without
-- an engine the test says SKIP and passes. Renders every screen at the Fold's
-- outer (1080x2520) and inner (2184x1968) sizes into AIO_TEST_OUTPUT, plus
-- the native screen with MODERN UI off.
io.stdout:setvbuf("no")
local root=love.filesystem.getSource():gsub("/tests/modern_story/?$","").."/"
local output=os.getenv("AIO_TEST_OUTPUT") or os.getenv("TEMP") or "/tmp"
local engine=os.getenv("AIO_ENGINE_SRC")
function love.errorhandler(err) print(debug.traceback(tostring(err)));os.exit(1) end

local failures=0
local function check(cond,msg)
  if not cond then failures=failures+1;print("FAIL: "..msg) else print("ok   "..msg) end
end

function love.load()
  if not engine or engine=="" or not io.open(engine.."/src/ui/gen2/HallOfFame.lua","rb") then
    print("modern story: SKIP (set AIO_ENGINE_SRC to the engine's src root)")
    love.event.quit(0)
    return
  end
  package.path=engine.."/?.lua;"..package.path
  local G=love.graphics

  -- ------------------------------------------------------------ stand-in art
  local function gen(w,h,fn)
    local d=love.image.newImageData(w,h)
    d:mapPixel(function(x,y) return fn(x,y) end)
    local img=G.newImage(d);img:setFilter("nearest","nearest")
    return img
  end
  local function blob(r,g,b,label)
    -- a 56x56 pic: white paper, a two-tone round body (a GB pic's look)
    return gen(56,56,function(x,y)
      local dx,dy=(x-28)/22,(y-32)/22
      local d=dx*dx+dy*dy
      if d<.55 then return r,g,b,1 end
      if d<1 then return r*.55,g*.55,b*.55,1 end
      return 1,1,1,1
    end)
  end
  local fake={
    ["fake/egg.png"]=gen(40,40,function(x,y)
      local dx,dy=(x-20)/15,(y-22)/18
      local d=dx*dx+dy*dy
      if d<.8 then return .96,.92,.78,1 elseif d<1 then return .55,.45,.3,1 end
      return 1,1,1,1
    end),
    ["fake/shell.png"]=gen(8,16,function(x,y)
      if y<8 then return (x==y or x==7-y) and 0 or 1,(x==y or x==7-y) and 0 or 1,(x==y or x==7-y) and 0 or 1,(x==y or x==7-y) and 1 or 0 end
      return .9,.85,.7,((x-4)^2+(y-12)^2<10) and 1 or 0
    end),
    ["fake/playerback.png"]=blob(.85,.25,.2),
    ["fake/chris.png"]=blob(.2,.35,.85),
    ["fake/unown.png"]=blob(.2,.2,.25),
    ["fake/puzzle.png"]=gen(96,96,function(x,y)
      local dx,dy=(x-48)/40,(y-50)/38
      local d=math.sqrt(dx*dx+dy*dy)
      local ring=math.floor(d*6)%2==0
      if d<1 then return ring and .77 or .58,ring and .65 or .42,ring and .35 or .35,1 end
      return .95,.93,.85,1
    end),
    ["fake/cursor.png"]=gen(32,8,function(x,y) return 1,0,0,(y==0 or x%8==0) and 1 or 0 end),
  }
  local SPECIES={CHIKORITA={152,{.4,.8,.3}},CYNDAQUIL={155,{.9,.5,.2}},TOTODILE={158,{.3,.5,.9}},
    MEGANIUM={154,{.4,.8,.3}},LUGIA={249,{.85,.85,.95}},TOGEPI={175,{.95,.95,.8}},UNOWN={201,{.2,.2,.25}}}
  for sp,v in pairs(SPECIES) do
    fake["fake/front/"..sp..".png"]=blob(v[2][1],v[2][2],v[2][3])
    fake["fake/back/"..sp..".png"]=blob(v[2][1]*.7,v[2][2]*.7,v[2][3]*.7)
  end

  -- ------------------------------------------------------------ stubs
  local sounds={}
  local tiny=G.newFont(7)
  local Chrome={SCREEN_W=20,SCREEN_H=18}
  function Chrome.number(value,width,zeros)
    local text=tostring(math.floor(value or 0))
    local pad=math.max(0,(width or 0)-#text)
    return (zeros and ("0"):rep(pad) or (" "):rep(pad))..text
  end
  function Chrome.paletteFill(x,y,w,h) G.setColor(1,1,1,1);G.rectangle("fill",x,y,w,h) end
  function Chrome.clear() Chrome.paletteFill(0,0,160,144) end
  function Chrome.textbox(tx,ty,iw,ih) G.setColor(0,0,0,1);G.setLineWidth(1);G.rectangle("line",tx*8+3.5,ty*8+3.5,(iw+2)*8-7,(ih+2)*8-7) end
  function Chrome.box(tx,ty,tw,th) G.setColor(0,0,0,1);G.setLineWidth(1);G.rectangle("line",tx*8+.5,ty*8+.5,tw*8-1,th*8-1) end
  function Chrome.print(text,tx,ty) G.setColor(0,0,0,1);G.setFont(tiny);G.print(tostring(text),tx*8,ty*8) end
  function Chrome.printThrough(text,tx,ty) Chrome.print(text,tx,ty) end
  function Chrome.fitScale(w,h) return math.max(1,math.floor(math.min(w/160,h/144))) end
  function Chrome.fitOrigin(w,h,s) s=s or Chrome.fitScale(w,h);return math.floor((w-160*s)/2),math.floor((h-144*s)/2) end
  function Chrome.letterbox(w,h,r,g,b) G.setColor(r,g,b,1);G.rectangle("fill",0,0,w,h) end
  function Chrome.withClip(fn) fn() end
  function Chrome.withPanel(w,h,r,g,b,fn)
    Chrome.letterbox(w,h,r,g,b)
    local s=Chrome.fitScale(w,h);local ox,oy=Chrome.fitOrigin(w,h,s)
    G.push();G.translate(ox,oy);G.scale(s,s);fn();G.pop()
  end
  local stubs={
    ["src.render.Assets"]={image=function(p) return fake[p] or error("no asset "..tostring(p)) end,resolve=function(p) return p end},
    ["src.ui.gen2.Chrome"]=Chrome,
    ["src.render.Font"]={useBattleExtra=function()return false end},
    ["src.render.GbcPalette"]={available=function()return false end,mode="dmg",
      color=function()return {255,255,255} end,with=function(_,b) b() end},
    ["src.world.gen2.Palettes"]={monColors=function()return nil end},
    ["src.core.Music"]={stop=function()end,play=function(_,n)sounds[#sounds+1]="music:"..n end,fadeOut=function()sounds[#sounds+1]="fade" end},
    ["src.core.Sound"]={resolve=function(_,n)return n end,play=function(_,n)sounds[#sounds+1]="sfx:"..n end,
      waitSfxDone=function()end,playCry=function(_,n)sounds[#sounds+1]="cry:"..n end},
    ["src.pokemon.Sprites"]={pic=function(p)return p,false end,playerPic=function(p)return p end},
    ["src.core.gen2.Save"]={isFemale=function()return false end},
    ["src.mods.Runtime"]={wants=function()return false end,emit=function()end,wantsHook=function()return false end},
    ["src.core.Logger"]={warn=function()end,info=function()end},
  }
  for name,v in pairs(stubs) do package.preload[name]=function()return v end end

  local HallOfFame=require("src.ui.gen2.HallOfFame")
  local Core=require("src.core.gen2.HallOfFame")
  local Diploma=require("src.ui.gen2.Diploma")
  local Hatch=require("src.ui.gen2.EggHatchAnim")
  local Puzzle=require("src.ui.gen2.UnownPuzzle")
  local Printer=require("src.ui.gen2.UnownPrinter")

  local dims={1080,2520}
  local realDims=G.getDimensions
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
  local warnings={}
  local mod={exports={},path=root:gsub("/$",""),options={get=function(_,k)return opts[k]end},
    log={info=function()end,warn=function(_,...)warnings[#warnings+1]=string.format(...);print("WARN",string.format(...))end,error=function()end},
    read=function(_,rel)return readFile(rel)end,
    assets={image=function(_,p)return image(p)end},
    hooks={wrap=function(_,name,fn,priority)
      hooks[name]=hooks[name] or {};hooks[name][#hooks[name]+1]={fn=fn,p=priority or 0}
    end}}
  local function run(rel,...)
    return assert(loadstring(assert(readFile(rel)),"@"..rel))()(...)
  end
  run("lib/gen2_aio/font.lua",{mod=mod})
  local S=run("lib/gen2_modern_style.lua",mod)
  run("lib/gen2_aio/modern_story.lua",{mod=mod})
  mod.exports.screenTapTargets=function()return rawget(mod,"_kimScreenTapTargets") end
  mod.exports.menuCloseRect=function()return rawget(mod,"_kimMenuClose")end
  -- MENU SPRITES = KIM: the HD menu icons on disk stand in for the HD sheets
  local spriteCalls=0
  mod.exports.getSprite=function(species,o)
    spriteCalls=spriteCalls+1
    local v=SPECIES[species]
    return v and image(("assets/menu_icons/hd/normal/%03d.png"):format(v[1])) or nil
  end
  mod.exports.getGen2UnownSprite=function(letter)
    return image("assets/menu_icons/hd/normal/201.png")
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

  local input={pressed={}}
  function input:wasPressed(b) return self.pressed[b] or false end
  local function newGame(save)
    local states={}
    local game={save=save,input=input,data={pokemon={},audio={songs={},sfx={Sfx_EggHatch=true,Sfx_EggCrack=true},cries={}},
      gen2MenuGfx={eggHatch={egg="fake/egg.png",shell="fake/shell.png"},
        battleHud={playerBack="fake/playerback.png",trainerPics={CHRIS="fake/chris.png"}},
        unownPuzzle={pictures={"fake/puzzle.png"},cursor="fake/cursor.png"}}},stack={states=states}}
    for sp,v in pairs(SPECIES) do
      game.data.pokemon[sp]={name=sp,dex=v[1],spriteFront="fake/front/"..sp..".png",spriteBack="fake/back/"..sp..".png"}
      game.data.audio.cries[sp]=true
    end
    function game.stack:top()return self.states[#self.states] end
    function game.stack:push(s)self.states[#self.states+1]=s end
    function game.stack:pop()self.states[#self.states]=nil end
    return game
  end
  local function press(s,btn)
    input.pressed={[btn]=true};s:update(1/60);input.pressed={}
  end
  -- mod.input.tap reaches the screen as its next update's button edge
  local tapped={}
  mod.input={tap=function(_,game,btn)tapped[#tapped+1]=btn;local s=game.stack:top();if s then press(s,btn) end end}

  local shots={}
  local function frame(s,game,name,native)
    draws={}
    local canvas=G.newCanvas(dims[1],dims[2])
    G.setCanvas(canvas);G.clear(.16,.27,.2,1)
    if native then
      -- MODERN UI off: what the engine itself draws
      if chain("screen.render_visible",function()return true end,s) then
        if s.drawWidescreen then s:drawWidescreen(dims[1],dims[2]) else s:draw() end
      end
    end
    chain("render.hud",function()end,game,{})
    G.setCanvas()
    if name then
      local path=output.."/aio-story-"..name.."-"..dims[1].."x"..dims[2]..".png"
      local f=assert(io.open(path,"wb"))
      f:write(canvas:newImageData():encode("png"):getString());f:close()
      shots[#shots+1]=path
    end
    canvas:release()
    return rawget(mod,"_kimScreenTapTargets"),rawget(mod,"_kimMenuClose")
  end
  -- every text drawn this frame: on screen and clear of every other
  local function textClear(tag)
    local boxes={}
    for _,d in ipairs(draws) do
      if d.text:match("%S") then
        local f=d.font;local tw=f:getWidth(d.text);local lines=1;local x=d.x
        if d.w then
          local _,wr=f:getWrap(d.text,d.w);lines=math.max(1,#wr)
          if lines>1 then tw=d.w else tw=math.min(tw,d.w) end
          if d.align=="center" then x=d.x+(d.w-tw)/2 elseif d.align=="right" then x=d.x+d.w-tw end
        end
        boxes[#boxes+1]={x=x,y=d.y,w=tw,h=f:getHeight()*lines,text=d.text}
      end
    end
    local bad={}
    for i,a in ipairs(boxes) do
      if a.x<-1 or a.y<-1 or a.x+a.w>dims[1]+1 or a.y+a.h>dims[2]+1 then bad[#bad+1]="off:"..a.text end
      for j=i+1,#boxes do
        local b=boxes[j]
        if a.x<b.x+b.w-2 and b.x<a.x+a.w-2 and a.y<b.y+b.h-2 and b.y<a.y+a.h-2 then bad[#bad+1]=a.text.."/"..b.text end
      end
    end
    check(#bad==0,tag.." text on screen and apart ("..table.concat(bad,"; ")..")")
    return boxes
  end
  local function cellsClear(t,close,tag)
    local bad=0
    for i,a in ipairs(t and t.cells or {}) do
      if a.w<dims[1]*.9 then   -- a whole-window "tap anywhere" cell is exempt
        if a.x<0 or a.y<0 or a.x+a.w>dims[1] or a.y+a.h>dims[2] then bad=bad+1 end
        for j=i+1,#t.cells do
          local b=t.cells[j]
          if b.w<dims[1]*.9 and a.x<b.x+b.w-0.5 and b.x<a.x+a.w-0.5 and a.y<b.y+b.h-0.5 and b.y<a.y+a.h-0.5 then bad=bad+1 end
        end
        if close and a.x<close.x+close.w and close.x<a.x+a.w and a.y<close.y+close.h and close.y<a.y+a.h then bad=bad+1 end
      end
    end
    check(bad==0,tag.." tap cells on screen, apart, clear of the close button")
  end
  local function sawText(pattern)
    for _,d in ipairs(draws) do if d.text:find(pattern) then return d end end
  end

  -- ------------------------------------------------------------ factories
  local function party()
    local function m(sp,lv,extra)
      local r={species=sp,nickname=sp,level=lv,otId=4321,gender="male"}
      for k,v in pairs(extra or {}) do r[k]=v end
      return r
    end
    return {m("TOTODILE",52),m("CHIKORITA",48,{nickname="LEAFY",gender="female"}),m("MEGANIUM",50),
      m("LUGIA",60,{gender=nil}),m("CYNDAQUIL",100),m("TOGEPI",30)}
  end
  local function newSave()
    return {player={name="KRIS",id=24680},playTime={hours=31,minutes=7},party=party()}
  end
  local function hof(mode,save)
    save=save or newSave()
    local game=newGame(save)
    local entry
    if mode=="induct" then entry=Core.induct(save,save.party)
    else Core.induct(save,save.party);Core.induct(save,{save.party[1],save.party[4]}) end
    local done=false
    local s=HallOfFame.new(game,{mode=mode,save=save,entry=entry,onDone=function()done=true;game.stack:pop()end})
    game.stack:push(s)
    return s,game,function()return done end
  end
  local function hatch()
    local game=newGame({})
    local done=false
    local s=Hatch.new(game,{mon={species="TOGEPI",nickname="TOGEPI"},onDone=function()done=true;game.stack:pop()end})
    game.stack:push(s)
    return s,game,function()return done end
  end
  local function puzzle()
    local game=newGame({})
    local closed
    local seq=0
    local s=Puzzle.new(game,{puzzle=0,random=function(n) seq=seq+7;return seq%n end,
      onClose=function(solved)closed={solved=solved};game.stack:pop()end})
    game.stack:push(s)
    return s,game,function()return closed end
  end
  local function printer()
    local game=newGame({})
    local closed=false
    local s=Printer.new(game,{onClose=function()closed=true;game.stack:pop()end})
    game.stack:push(s)
    return s,game,function()return closed end
  end
  local function diploma()
    local game=newGame({player={name="KRIS"}})
    local closed=false
    local s=Diploma.new(game,{onClose=function()closed=true;game.stack:pop()end})
    game.stack:push(s)
    return s,game,function()return closed end
  end

  -- ------------------------------------------------------------ timing
  -- The presenter only reads: the induction and the hatch run the same
  -- frames and fire the same sounds whether or not it draws every frame.
  local function timeline(make,render,limit)
    sounds={}
    local s,game,done=make()
    local log={}
    local last
    for f=1,limit do
      if done() then break end
      if render then dims={1080,2520};frame(s,game) end
      s:update(1/60)
      local key=table.concat({tostring(s.phase),tostring(s.index),tostring(s.scx),tostring(s.scy),
        tostring(s.showMon),tostring(s.shakeX),tostring(s.sprites and #s.sprites)},",")
      if key~=last then log[#log+1]=f..":"..key;last=key end
    end
    return table.concat(log,"|").."#"..table.concat(sounds,","),done()
  end
  do
    local plain,d1=timeline(function()return hof("induct")end,false,4000)
    local drawn,d2=timeline(function()return hof("induct")end,true,4000)
    check(d1 and d2,"the induction runs to onDone")
    check(plain==drawn,"Hall of Fame induction: same frames and sounds with the Modern draw")
    plain,d1=timeline(hatch,false,3000)
    drawn,d2=timeline(hatch,true,3000)
    check(d1 and d2,"the hatch runs to onDone")
    check(plain==drawn,"egg hatch: same frames and sounds with the Modern draw")
  end

  -- ------------------------------------------------------------ renders
  local function stepUntil(s,cond,limit)
    for _=1,limit or 2000 do if cond(s) then return true end;s:update(1/60) end
    return cond(s)
  end
  for _,d in ipairs({{1080,2520},{2184,1968}}) do
    dims=d
    local tag=d[1].."x"..d[2]
    -- Hall of Fame, induction: a slide, the display, the player's card
    do
      local s,game=hof("induct")
      for _=1,20 do s:update(1/60) end
      frame(s,game,"hof-slide")
      textClear(tag.." HoF slide")
      check(rawget(mod,"_kimMenuClose")==nil,tag.." HoF induction: a cutscene has no close button")
      stepUntil(s,function(x)return x.phase=="frontpic" and x.scx<0x40 end)
      frame(s,game,"hof-frontpic")
      stepUntil(s,function(x)return x.phase=="display" end)
      spriteCalls=0
      frame(s,game,"hof-display")
      check(spriteCalls>0,tag.." HoF display: KIM HD sprite")
      check(sawText("^NEW HALL OF FAMER!$") and sawText("^TOTODILE$"),tag.." HoF display: header and the mon's name")
      textClear(tag.." HoF display")
      stepUntil(s,function(x)return x.phase=="display" and x.index==2 end)
      frame(s,game,"hof-display2")
      check(sawText("^LEAFY$") and sawText("CHIKORITA"),tag.." HoF second mon: nickname and species")
      textClear(tag.." HoF display 2")
      stepUntil(s,function(x)return x.phase=="playerFront" end)
      for _=1,30 do s:update(1/60) end
      frame(s,game,"hof-player")
      check(sawText("^KRIS$") and sawText("PLAY TIME"),tag.." HoF player card")
      textClear(tag.." HoF player")
    end
    -- Hall of Fame, the PC viewer
    do
      local s,game,done=hof("view")
      local t,close=frame(s,game,"hof-view")
      check(close and close.state==s,tag.." HoF viewer: close button")
      check(sawText("^2%-TIME FAMER$"),tag.." HoF viewer: 2-Time Famer header")
      textClear(tag.." HoF viewer")
      cellsClear(t,close,tag.." HoF viewer")
      local next,team
      for _,c in ipairs(t.cells) do if c.button=="a" then next=c elseif c.button=="start" then team=c end end
      check(next and team,tag.." HoF viewer: NEXT and NEXT TEAM cells")
      tapped={}
      pcall(next.select or function()end,s);mod.input:tap(game,next.button)
      check(s.index==2 and s.team==1,tag.." NEXT is the viewer's A (next mon)")
      mod.input:tap(game,team.button)
      check(s.team==2 and s.index==1,tag.." NEXT TEAM is START")
      frame(s,game,"hof-view-team2")
      textClear(tag.." HoF viewer team 2")
      press(s,"b")
      for _=1,2 do s:update(1/60) end
      check(done(),tag.." B leaves the viewer")
    end
    -- Diploma
    do
      local s,game,closed=diploma()
      local t,close=frame(s,game,"diploma")
      check(close==nil,tag.." diploma: no close button")
      check(sawText("^KRIS$") and sawText("POKéDEX"),tag.." diploma: name and certificate")
      textClear(tag.." diploma")
      mod.input:tap(game,t.cells[1].button)
      check(closed(),tag.." diploma: a tap is A and closes it")
    end
    -- Egg hatch: the wobble, a crack, the fragments, the hatchling
    do
      local s,game=hatch()
      stepUntil(s,function(x)return x.shakeX~=0 end)
      frame(s,game,"hatch-egg")
      check(rawget(mod,"_kimMenuClose")==nil,tag.." hatch: a cutscene has no close button")
      stepUntil(s,function(x)return #x.sprites>=2 end)
      frame(s,game,"hatch-crack")
      stepUntil(s,function(x)return x.showMon end)
      for _=1,6 do s:update(1/60) end
      spriteCalls=0
      frame(s,game,"hatch-fragments")
      check(spriteCalls>0,tag.." hatch: KIM HD sprite of the hatchling")
      check(sawText("^TOGEPI$"),tag.." hatch: the hatchling's name")
      textClear(tag.." hatch")
      for _=1,40 do s:update(1/60) end
      frame(s,game,"hatch-mon")
    end
    -- Unown printer
    do
      local s,game,closed=printer()
      local t,close=frame(s,game,"printer")
      check(close and close.state==s,tag.." printer: close button")
      check(sawText("^ALPH RUINS STAMP$") and sawText("^A$"),tag.." printer: title and letter A")
      textClear(tag.." printer")
      cellsClear(t,close,tag.." printer")
      local left,right
      for _,c in ipairs(t.cells) do if c.button=="left" then left=c elseif c.button=="right" then right=c end end
      mod.input:tap(game,right.button)
      check(s.index==1,tag.." printer: the right arrow is RIGHT")
      mod.input:tap(game,left.button);mod.input:tap(game,left.button)
      check(s.index==26,tag.." printer: LEFT wraps to VACANT")
      frame(s,game,"printer-vacant")
      check(sawText("^VACANT$"),tag.." printer: VACANT slot")
      textClear(tag.." printer vacant")
      press(s,"b")
      check(closed(),tag.." printer: B closes")
    end
    -- Unown puzzle: fresh board, a held panel, solved
    do
      local s,game,closed=puzzle()
      local t,close=frame(s,game,"puzzle")
      check(close==nil,tag.." puzzle: no close button (B is not the puzzle's way out)")
      textClear(tag.." puzzle")
      cellsClear(t,close,tag.." puzzle")
      local n=0
      for _,c in ipairs(t.cells) do if c.drop then n=n+1 end end
      check(n==32,tag.." puzzle: 32 reachable cells ("..n..")")
      press(s,"right");press(s,"a")
      check(s.holding,tag.." puzzle: the pad still works (RIGHT, A picks up)")
      press(s,"down")
      frame(s,game,"puzzle-held")
      textClear(tag.." puzzle held")
      -- solved: everything in place but panel 16, which is on the ring
      local s2,game2,closed2=puzzle()
      for i=1,36 do s2.pieces[i]=Puzzle.SOLVED[i] end
      s2.pieces[29]=0;s2.pieces[30]=16
      s2.cursor=29;press(s2,"a");s2.cursor=28;press(s2,"a")
      check(s2.solved and s2.waiting,tag.." puzzle: solved through UnownPuzzle_A")
      t=frame(s2,game2,"puzzle-solved")
      textClear(tag.." puzzle solved")
      mod.input:tap(game2,t.cells[#t.cells].button)
      check(closed2() and closed2().solved,tag.." puzzle: a tap after the solve is A and closes it solved")
    end
  end

  -- ------------------------------------------------------------ touch
  do
    dims={1080,2520}
    local T=100
    love.timer.getTime=function()return T end
    local s,game,closed=puzzle()
    local tlog={}
    local thooks={}
    local tmod={id="touch",exports={},options={get=function()return nil end,define=function()end},read=function()return nil end,
      hooks={wrap=function(_,n,f,p)thooks[n]=thooks[n] or {};thooks[n][p]=f end},
      input={tap=function(_,g,b)tlog[#tlog+1]="tap:"..b;press(g.stack:top(),b)end,press=function(_,g,b)tlog[#tlog+1]="press:"..b;return {} end,release=function()end},
      find=function()return {exports=mod.exports} end}
    setmetatable(tmod,{__index=mod})
    package.preload["src.core.TouchControls"]=function()return {active=true,layout=function()return {} end} end
    package.preload["src.core.TouchSkin"]=function()return {active=false} end
    assert(loadstring(assert(readFile("touch/main.lua")),"@touch/main.lua"))()(tmod)
    mod.input=tmod.input
    local ptr=thooks["input.pointer"][10]
    local function send(phase,x,y)return ptr(function()end,game,{phase=phase,x=x,y=y,id=1,source="touch"}) end
    local function cellFor(t,no) for _,c in ipairs(t.cells) do if c.drop==no then return c end end end
    local function mid(c)return c.x+c.w/2,c.y+c.h/2 end
    local function tapAt(x,y) tlog={};send("pressed",x,y);T=T+0.08;send("released",x,y) end
    -- a tap on a ring panel picks it up; a tap on an empty middle cell puts it down
    local t=frame(s,game)
    local from
    for _,no in ipairs(Puzzle.START_CELLS) do if s.pieces[no+1]~=0 then from=no break end end
    local piece=s.pieces[from+1]
    tapAt(mid(cellFor(t,from)))
    check(s.holding and s.held==piece and s.cursor==from,"touch: a tap on a panel moves the cursor there and presses A ("..table.concat(tlog,",")..")")
    t=frame(s,game)
    tapAt(mid(cellFor(t,7)))
    check(not s.holding and s.pieces[8]==piece,"touch: a tap on an empty cell puts it down")
    -- a tap on a taken cell while holding: SFX_WRONG, the panel stays in hand
    t=frame(s,game)
    local other
    for _,no in ipairs(Puzzle.START_CELLS) do if s.pieces[no+1]~=0 then other=no break end end
    tapAt(mid(cellFor(t,other)))
    check(s.holding,"touch: picked up another")
    t=frame(s,game)
    sounds={}
    tapAt(mid(cellFor(t,7)))
    check(s.holding and sounds[#sounds]=="sfx:Sfx_Wrong","touch: a taken cell is UnownPuzzle_A's SFX_WRONG")
    -- put it back where it was by a drag of the held panel
    t=frame(s,game)
    local x,y
    local x2,y2=mid(cellFor(t,other))
    check(s.cursor==7,"touch: the held panel rides the cursor on the taken cell")
    local hx,hy=mid(cellFor(t,s.cursor))
    tlog={}
    send("pressed",hx,hy);T=T+0.05;send("moved",hx+30,hy+30);T=T+0.05
    frame(s,game)
    send("moved",x2,y2);T=T+0.05
    send("released",x2,y2)
    check(not s.holding and s.pieces[other+1]~=0,"touch: dragging the held panel drops it ("..table.concat(tlog,",")..")")
    -- drag a ring panel straight into the middle
    t=frame(s,game)
    local src
    for _,no in ipairs(Puzzle.START_CELLS) do if s.pieces[no+1]~=0 then src=no break end end
    local p2=s.pieces[src+1]
    x,y=mid(cellFor(t,src));x2,y2=mid(cellFor(t,14))
    tlog={}
    send("pressed",x,y);T=T+0.05;send("moved",x+30,y+30);T=T+0.05
    frame(s,game,"puzzle-drag")
    send("moved",x2,y2);T=T+0.05
    frame(s,game,"puzzle-drag-hover")
    send("released",x2,y2)
    check(s.pieces[15]==p2 and s.pieces[src+1]==0 and not s.holding,"touch: a drag moves a panel into the middle ("..table.concat(tlog,",")..")")
    -- a drop on a taken cell: back where it came from
    t=frame(s,game)
    for _,no in ipairs(Puzzle.START_CELLS) do if s.pieces[no+1]~=0 then src=no break end end
    p2=s.pieces[src+1]
    x,y=mid(cellFor(t,src));x2,y2=mid(cellFor(t,14))
    send("pressed",x,y);T=T+0.05;send("moved",x+30,y+30);T=T+0.05
    send("moved",x2,y2);T=T+0.05;send("released",x2,y2)
    check(s.pieces[src+1]==p2 and not s.holding,"touch: a drop on a taken cell returns the panel")
    -- CANCEL is START
    t=frame(s,game)
    local cancel
    for _,c in ipairs(t.cells) do if c.button=="start" then cancel=c end end
    tapAt(mid(cancel))
    check(closed() and closed().solved==false,"touch: CANCEL is START ("..table.concat(tlog,",")..")")
    -- the printer's close button is B
    local p,pg,pclosed=printer()
    game=pg
    local _,close=frame(p,pg)
    tapAt(close.x+close.w/2,close.y+close.h/2)
    check(pclosed(),"touch: the printer's close button is B ("..table.concat(tlog,",")..")")
    love.timer.getTime=function()return 0 end
  end

  -- ------------------------------------------------------------ MENU SPRITES VANILLA
  do
    opts.gen2MenuSpriteSource="vanilla"
    for _,d in ipairs({{1080,2520},{2184,1968}}) do
      dims=d
      local s,game=hof("view")
      spriteCalls=0
      frame(s,game,"hof-view-vanilla")
      check(spriteCalls==0,"MENU SPRITES VANILLA: Crystal's own pics")
      local h=hatch()
      stepUntil(h,function(x)return x.showMon end)
      for _=1,6 do h:update(1/60) end
      frame(h,h.game,"hatch-vanilla")
      local p,pg=printer()
      frame(p,pg,"printer-vanilla")
    end
    opts.gen2MenuSpriteSource=nil
  end

  -- ------------------------------------------------------------ MODERN UI off
  for _,off in ipairs({{"gen2IntegratedModernUi","modern-off"},{"menuUi","menu-off"}}) do
    opts[off[1]]=false
    for _,d in ipairs({{1080,2520},{2184,1968}}) do
      dims=d
      for name,make in pairs({hof=function()return hof("view")end,diploma=diploma,hatch=hatch,puzzle=puzzle,printer=printer}) do
        local s,game=make()
        if name=="hatch" then for _=1,90 do s:update(1/60) end end
        mod._kimScreenTapTargets=nil
        frame(s,game,off[2]=="modern-off" and (name.."-native") or nil,true)
        check(chain("screen.render_visible",function()return true end,s)==true and #draws==0
          and rawget(mod,"_kimScreenTapTargets")==nil,off[2]..": native "..name.." renders, no Modern window")
      end
    end
    opts[off[1]]=nil
  end
  do
    local s=puzzle()
    opts.gen2IntegratedModernUi=false
    press(s,"right")
    check(s.cursor==1,"MODERN UI off: the puzzle's own pad")
    opts.gen2IntegratedModernUi=nil
  end

  local broken=0
  for _ in pairs(mod._aioModernStory.broken) do broken=broken+1 end
  check(broken==0 and #warnings==0,"no presenter fell back to native on an error ("..table.concat(warnings,"; ")..")")
  for _,p in ipairs(shots) do print("png",p) end
  if failures>0 then print(("modern story: %d FAILED"):format(failures));os.exit(1) end
  print("modern story: PASS")
  love.event.quit(0)
end
