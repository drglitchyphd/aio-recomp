-- gen2-aio 0.9.75: the Modern service screens (lib/gen2_aio/modern_services.lua)
-- over the ENGINE's own classes: ItemPcMenu (with the real PackMenu for
-- DEPOSIT), BankOfMom, MailboxMenu, MailMenu, MailRead, MailCompose and
-- DayCareMenu.
--
--   AIO_ENGINE_SRC=/path/to/engine/src xvfb-run -a love tests/modern_services
--
-- AIO_ENGINE_SRC is the engine checkout's root (the folder holding src/).
-- Only rendering / audio / asset modules are stubbed; Bag, PcItems, Mail,
-- Breeding, Strings, Typer and the screens themselves are real. Without an
-- engine the test says SKIP and passes. Every screen and phase is rendered at
-- the Fold's outer (1080x2520) and inner (2184x1968) sizes into
-- AIO_TEST_OUTPUT; taps go through the published cells exactly as KIM Touch
-- uses them (select, then the cell's button).
io.stdout:setvbuf("no")
local root=love.filesystem.getSource():gsub("/tests/modern_services/?$","").."/"
local output=os.getenv("AIO_TEST_OUTPUT") or os.getenv("TEMP") or "/tmp"
local engine=os.getenv("AIO_ENGINE_SRC")
function love.errorhandler(err) print(debug.traceback(tostring(err)));os.exit(1) end

local failures=0
local function check(cond,msg)
  if not cond then failures=failures+1;print("FAIL: "..msg) else print("ok   "..msg) end
end

function love.load()
  if not engine or engine=="" or not io.open(engine.."/src/ui/gen2/ItemPcMenu.lua","rb") then
    print("modern services: SKIP (set AIO_ENGINE_SRC to the engine's src root)")
    love.event.quit(0)
    return
  end
  package.path=engine.."/?.lua;"..package.path
  -- the native draw is recorded, not rendered: any Chrome / Font call counts
  local nativeCalls=0
  local function recorder(base)
    return setmetatable(base,{__index=function(_,k)
      return function(...)
        nativeCalls=nativeCalls+1
        if k=="number" then return tostring((...)) end
        if k=="fitScale" then return 1 end
        if k=="fitOrigin" then return 0,0 end
      end
    end})
  end
  local stubs={
    ["src.ui.gen2.Chrome"]=recorder({SCREEN_W=20,SCREEN_H=18}),
    -- Typer splits lines into glyphs through Font.split
    ["src.render.Font"]=recorder({split=function(text)
      local spans,i=({}),1
      for ch in tostring(text):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        spans[#spans+1]={from=i,to=i+#ch-1};i=i+#ch
      end
      return spans
    end}),
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
    ["src.core.gen2.Save"]={NUM_BOXES=14,MONS_PER_BOX=20,PARTY_SIZE=6},
    ["src.ui.gen2.PackGfx"]={new=function()return {} end},
  }
  stubs["src.ui.Screens"]={
    build=function(game,name,opts)return require("src.ui.gen2."..name:gsub("^Gen2","")).new(game,opts)end,
    push=function(game,name,opts)
      local s=require("src.ui.gen2."..name:gsub("^Gen2","")).new(game,opts)
      game.stack:push(s);return true
    end}
  for name,v in pairs(stubs) do package.preload[name]=function()return v end end

  local ItemPcMenu=require("src.ui.gen2.ItemPcMenu")
  local BankOfMom=require("src.ui.gen2.BankOfMom")
  local MailboxMenu=require("src.ui.gen2.MailboxMenu")
  local MailMenu=require("src.ui.gen2.MailMenu")
  local MailRead=require("src.ui.gen2.MailRead")
  local MailCompose=require("src.ui.gen2.MailCompose")
  local DayCareMenu=require("src.ui.gen2.DayCareMenu")
  local Mail=require("src.core.gen2.Mail")
  local Typer=require("src.ui.gen2.Typer")

  local G=love.graphics
  local dims={1080,2520}
  G.getDimensions=function()return dims[1],dims[2] end
  love.system.getOS=function()return "Android" end
  local function readFile(rel)
    local f=io.open(root..rel,"rb");if not f then return nil end
    local s=f:read("*a");f:close();return s
  end
  local hooks,opts={},{}
  local mod={exports={},path=root:gsub("/$",""),options={get=function(_,k)return opts[k]end},
    log={info=function()end,warn=function()end,error=function()end},
    read=function(_,rel)return readFile(rel)end,
    assets={image=function()return nil end},
    hooks={wrap=function(_,name,fn,priority)
      hooks[name]=hooks[name] or {};hooks[name][#hooks[name]+1]={fn=fn,p=priority or 0}
    end}}
  local function run(rel,...)
    return assert(loadstring(assert(readFile(rel)),"@"..rel))()(...)
  end
  run("lib/gen2_aio/font.lua",{mod=mod})
  local S=run("lib/gen2_modern_style.lua",mod)
  run("lib/gen2_aio/modern_services.lua",{mod=mod})
  mod.exports.screenTapTargets=function()return rawget(mod,"_kimScreenTapTargets") end
  mod.exports.menuCloseRect=function()return rawget(mod,"_kimMenuClose")end

  local draws,footers={},0
  local originalText,originalFooter=S.text,S.footer
  S.text=function(value,font,x,y,w,align,c)
    draws[#draws+1]={text=tostring(value),font=font,x=x,y=y,w=w}
    return originalText(value,font,x,y,w,align,c)
  end
  S.footer=function(...) footers=footers+1;return originalFooter(...) end
  local function chain(name,base,...)
    local h={}
    for i,v in ipairs(hooks[name] or {}) do h[i]=v end
    table.sort(h,function(a,b)return a.p<b.p end)
    local fn=base
    for _,link in ipairs(h)do local nextFn=fn;fn=function(...)return link.fn(nextFn,...)end end
    return fn(...)
  end

  -- ------------------------------------------------------------ the world
  local ITEMS={
    POTION={name="POTION",description="Restores HP<NEXT>by 20 points.",pocket="ITEM",index=18},
    ANTIDOTE={name="ANTIDOTE",description="Cures poisoned<NEXT>#MON.",pocket="ITEM",index=9},
    REPEL={name="REPEL",description="Repels weak #MON<NEXT>for 100 steps.",pocket="ITEM",index=30},
    ESCAPE_ROPE={name="ESCAPE ROPE",description="Use for escaping<NEXT>from caves, etc.",pocket="ITEM",index=29},
    BICYCLE={name="BICYCLE",description="A collapsible bike<NEXT>for fast movement.",pocket="KEY_ITEM",canToss=false,index=7},
    POKE_BALL={name="POKé BALL",description="A tool for<NEXT>catching wild #MON.",pocket="BALL",index=5},
    FLOWER_MAIL={name="FLOWER MAIL",description="Flower-print MAIL.",pocket="ITEM",index=158},
    SURF_MAIL={name="SURF MAIL",description="LAPRAS-print MAIL.",pocket="ITEM",index=159},
    PORTRAITMAIL={name="PORTRAITMAIL",description="MAIL featuring the<NEXT>holder's likeness.",pocket="ITEM",index=158},
  }
  local function mon(species,level,hp,extra)
    local m={species=species,nickname=species,level=level,hp=hp,maxHp=math.max(hp,level*3),moves={},experience=0}
    for k,v in pairs(extra or {}) do m[k]=v end
    return m
  end
  local function newSave()
    return {player={name="GOLD",money=3000,id=12345},options={textSpeed="FAST"},
      party={mon("TOTODILE",14,40),mon("PIDGEY",9,20)},
      inventory={POTION=5,ANTIDOTE=2,BICYCLE=1,POKE_BALL=4},
      pcItems={POTION=3,REPEL=10,ESCAPE_ROPE=1}}
  end
  local input={pressed={}}
  function input:wasPressed(b) return self.pressed[b] or false end
  function input:isDown() return false end
  local function newGame(save)
    local game={save=save,input=input,data={items=ITEMS,pokemon={TOTODILE={name="TOTODILE",growthRate="MEDIUM_SLOW"},
      PIDGEY={name="PIDGEY",growthRate="MEDIUM_SLOW"}},moves={}},stack={states={}}}
    function game.stack:top()return self.states[#self.states] end
    function game.stack:push(s)self.states[#self.states+1]=s end
    function game.stack:pop()self.states[#self.states]=nil end
    return game
  end
  local function push(game,s) game.stack:push(s);return s end
  local function press(s,btn) input.pressed={[btn]=true};s:update(1/60);input.pressed={} end
  -- let the Typer finish the page it is on
  local function settle(s)
    for _=1,600 do
      if not Typer.typing(s) then break end
      s:update(1/60)
    end
  end

  local shots={}
  local function frame(game,name)
    draws={};footers=0
    rawset(mod,"_kimScreenTapTargets",nil)
    local canvas=G.newCanvas(dims[1],dims[2])
    G.setCanvas(canvas);G.clear(.16,.27,.2,1)
    chain("render.hud",function()end,game,{})
    G.setCanvas()
    if name then
      local path=output.."/aio-services-"..name.."-"..dims[1].."x"..dims[2]..".png"
      local f=assert(io.open(path,"wb"))
      f:write(canvas:newImageData():encode("png"):getString());f:close()
      shots[#shots+1]=path
    end
    canvas:release()
    return rawget(mod,"_kimScreenTapTargets"),rawget(mod,"_kimMenuClose")
  end
  -- a cell the way KIM Touch fires it: select, then the button (default A)
  local function fire(s,c)
    assert(c,"no cell")
    if type(c.select)=="function" then c.select(s) end
    local b=c.button; if b==nil then b="a" end
    if b then press(s,b) end
  end
  -- the cell under a drawn label
  local function cellFor(t,label)
    for _,d in ipairs(draws) do
      if d.text==label then
        local cx,cy=d.x+(d.w or d.font:getWidth(d.text))/2,d.y+d.font:getHeight()/2
        if not d.w then cx=d.x+d.font:getWidth(d.text)/2 end
        for _,c in ipairs(t and t.cells or {}) do
          if cx>=c.x and cx<=c.x+c.w and cy>=c.y and cy<=c.y+c.h then return c end
        end
      end
    end
  end
  local function drew(label)
    for _,d in ipairs(draws) do if d.text==label then return true end end
    return false
  end
  -- every cell on screen, apart, and clear of the close button
  local function layout(tag,t,close,wantClose)
    local cells=t and t.cells or {}
    local bad=0
    for i,a in ipairs(cells) do
      if a.x<0 or a.y<0 or a.x+a.w>dims[1]+.5 or a.y+a.h>dims[2]+.5 then bad=bad+1 end
      for j=i+1,#cells do
        local b=cells[j]
        if a.x<b.x+b.w-.5 and b.x<a.x+a.w-.5 and a.y<b.y+b.h-.5 and b.y<a.y+a.h-.5 then bad=bad+1 end
      end
      if close and a.x<close.x+close.w and close.x<a.x+a.w and a.y<close.y+close.h and close.y<a.y+a.h then bad=bad+1 end
    end
    check(bad==0,tag..": "..#cells.." cells on screen, apart, clear of the close button")
    if wantClose~=false then
      check(close~=nil,tag..": close button")
      check(footers>0,tag..": footer")
    end
    -- text stays inside the screen
    local out=0
    for _,d in ipairs(draws) do
      if d.x<0 or d.y<0 or d.y+d.font:getHeight()>dims[2] or d.x+(d.w or d.font:getWidth(d.text))>dims[1]+1 then out=out+1 end
    end
    check(out==0,tag..": text on screen")
  end

  for _,d in ipairs({{1080,2520},{2184,1968}}) do
    dims=d
    local sz=dims[1].."x"..dims[2]
    -- ---------------------------------------------------------- item PC
    do
      local save=newSave();local game=newGame(save)
      local closed=false
      local s=push(game,ItemPcMenu.new(game,{save=save,items=ITEMS,onClose=function()closed=true end}))
      local t,close=frame(game,"itempc-menu")
      layout(sz.." item PC menu",t,close)
      check(close and close.back==false,sz.." item PC menu: close is X")
      fire(s,cellFor(t,"WITHDRAW ITEM"))
      check(s.phase=="withdraw","tap WITHDRAW ITEM: the engine's withdraw list")
      t,close=frame(game,"itempc-withdraw")
      layout(sz.." withdraw list",t,close)
      check(close and close.back==true,sz.." withdraw list: close is a back arrow")
      check(drew("Restores HP by 20 points."),sz.." withdraw: selected item's description")
      fire(s,cellFor(t,"REPEL"))
      check(s.qtyState and s.qtyState.max==10,"tap REPEL: the engine's HOW MANY (max 10)")
      t,close=frame(game,"itempc-quantity")
      layout(sz.." quantity",t,close)
      fire(s,cellFor(t,"+1"));fire(s,cellFor(t,"+1"))
      check(s.qtyState.qty==3,"+1 twice: x3 (engine qtyStep)")
      fire(s,cellFor(t,"+10"))
      check(s.qtyState.qty==10,"+10 clamps at the stack (x10)")
      fire(s,cellFor(t,"-1"))
      check(s.qtyState.qty==9,"-1: x9")
      fire(s,cellFor(t,"OK"))
      check(save.inventory.REPEL==9 and save.pcItems.REPEL==1,"OK: 9 REPEL withdrawn by the engine")
      settle(s)
      t,close=frame(game,"itempc-message")
      layout(sz.." message",t,close)
      check(#t.cells==0 and t.mode=="list","message: no row cells (a tap anywhere is A)")
      press(s,"a")
      check(s.message==nil,"A clears the message")
      -- SELECT: move a stack
      t=frame(game)
      local before=table.concat(save.pcOrder,",")
      fire(s,cellFor(t,"MOVE"))
      check(s.switching~=nil,"MOVE: the engine's switch cursor")
      t=frame(game,"itempc-move")
      fire(s,cellFor(t,"POTION"))
      check(s.switching==nil and table.concat(save.pcOrder,",")~=before,"tap a row: stack moved ("..table.concat(save.pcOrder,",")..")")
      press(s,"b")
      check(s.phase=="menu","B: back to the PC menu")
      -- TOSS with its YES / NO
      t=frame(game)
      fire(s,cellFor(t,"TOSS ITEM"))
      t=frame(game)
      fire(s,cellFor(t,"POTION"))
      t=frame(game)
      fire(s,cellFor(t,"OK"))
      check(s.confirm~=nil,"TOSS x1: the engine's throw-away YES/NO")
      t,close=frame(game,"itempc-toss-confirm")
      layout(sz.." toss confirm",t,close)
      check(t.mode=="sub","YES/NO: a miss is not A")
      fire(s,cellFor(t,"YES"))
      check(save.pcItems.POTION==2,"YES: one POTION tossed by the engine")
      settle(s);press(s,"a");press(s,"b")
      -- DEPOSIT: the real PackMenu as the chooser
      t=frame(game)
      fire(s,cellFor(t,"DEPOSIT ITEM"))
      check(s.phase=="deposit" and s.pack~=nil,"DEPOSIT ITEM: the engine's PACK chooser")
      t,close=frame(game,"itempc-deposit")
      layout(sz.." deposit",t,close)
      local tab=cellFor(t,"BALLS")
      fire(s,tab)
      check(s.pack.pocketIndex==2 and s.phase=="deposit","BALLS tab: the pack's own switchPocket, no A")
      t=frame(game,"itempc-deposit-balls")
      check(drew("POKé BALL"),sz.." BALLS pocket rows")
      fire(s,cellFor(t,"ITEMS"))
      t=frame(game)
      fire(s,cellFor(t,"ANTIDOTE"))
      check(s.qtyState~=nil,"tap ANTIDOTE: HOW MANY")
      t=frame(game,"itempc-deposit-quantity")
      fire(s,cellFor(t,"OK"))
      check(save.pcItems.ANTIDOTE==1 and save.inventory.ANTIDOTE==1,"OK: 1 ANTIDOTE deposited by the engine")
      settle(s);press(s,"a");press(s,"b")
      check(s.phase=="menu","B leaves the PACK")
      t=frame(game)
      fire(s,cellFor(t,"LOG OFF"))
      check(closed,"LOG OFF closes the PC")
      -- the bedroom PC opens on its turned-on message

      local g2=newGame(newSave())
      local s2=push(g2,ItemPcMenu.new(g2,{save=g2.save,items=ITEMS,house=true}))
      settle(s2)
      t,close=frame(g2,"itempc-house")
      layout(sz.." house PC",t,close)
      check(drew("GOLD turned on"),sz.." house PC: the engine's message")
    end
    -- ---------------------------------------------------------- Bank of Mom
    do
      local game=newGame(newSave())
      -- Mom's question sits in a TextBox under the keypad
      push(game,{pages={{"How much do you","want to take?"}},pageIndex=1})
      local got="none"
      local s=push(game,BankOfMom.new(game,{kind="withdraw",saved=12345,held=3000,onDone=function(a)got=a end}))
      local t,close=frame(game,"bank-withdraw")
      layout(sz.." bank",t,close)
      check(drew("How much do you want to take?"),sz.." bank: Mom's question")
      check(drew("¥12345") and drew("¥3000"),sz.." bank: SAVED and HELD")
      check(t.mode=="sub","bank: a miss is not A")
      local ups,downs,digits={},{},{}
      for _,c in ipairs(t.cells) do
        if c.button=="up" then ups[#ups+1]=c elseif c.button=="down" then downs[#downs+1]=c
        elseif c.button==false then digits[#digits+1]=c end
      end
      check(#ups==6 and #downs==6 and #digits==6,"bank: six digits with up / down")
      fire(s,ups[3])
      check(s.amount==1000 and s.position==2,"up over the thousands: +1000 through the engine")
      fire(s,digits[6])
      check(s.position==5 and s.amount==1000,"tap a digit: only the cursor moves")
      fire(s,downs[4])
      check(s.amount==900,"down over the hundreds: 900")
      fire(s,cellFor(t,"OK"))
      check(got==900,"OK hands the engine's amount to Mom (900)")
      local g3=newGame(newSave())
      local s3=push(g3,BankOfMom.new(g3,{kind="deposit",saved=0,held=999999}))
      s3.amount=4520;s3.position=3
      t,close=frame(g3,"bank-deposit")
      layout(sz.." bank deposit",t,close)
    end
    -- ---------------------------------------------------------- MAILBOX
    do
      local save=newSave();local game=newGame(save)
      local box=Mail.state(save).box
      box[1]=Mail.entry("FLOWER_MAIL","Hello from\nNEW BARK TOWN!","MOM",1,"TOTODILE")
      box[2]=Mail.entry("SURF_MAIL","See you at the LAKE OF RAGE!","ELM",2)
      box[3]=Mail.entry("PORTRAITMAIL","","",3)
      local s=push(game,MailboxMenu.new(game,{save=save,onClose=function()game.stack:pop()end}))
      local t,close=frame(game,"mailbox")
      layout(sz.." mailbox",t,close)
      check(drew("Hello from"),sz.." mailbox: the selected letter")
      fire(s,cellFor(t,"ELM"))
      check(s.index==2 and s.submenu~=nil,"tap ELM: the engine's letter menu")
      t,close=frame(game,"mailbox-submenu")
      layout(sz.." mailbox submenu",t,close)
      check(close and close.back==true,sz.." mailbox submenu: back arrow")
      fire(s,cellFor(t,"PUT IN PACK"))
      check(s.confirm~=nil,"PUT IN PACK: the engine's YES/NO")
      t,close=frame(game,"mailbox-confirm")
      layout(sz.." mailbox confirm",t,close)
      fire(s,cellFor(t,"YES"))
      check(Mail.mailboxCount(save)==2 and save.inventory.SURF_MAIL==1,"YES: letter cleared, SURF MAIL in the PACK")
      t,close=frame(game,"mailbox-message")
      press(s,"a")
      -- READ MAIL opens the engine's reader
      t=frame(game)
      fire(s,cellFor(t,"MOM"))
      t=frame(game)
      fire(s,cellFor(t,"READ MAIL"))
      local reader=game.stack:top()
      check(getmetatable(reader)==MailRead,"READ MAIL: MailRead on the stack")
      t,close=frame(game,"mailread")
      layout(sz.." mail read",t,close)
      check(drew("NEW BARK TOWN!") and drew("MOM"),sz.." mail read: message and author")
      press(reader,"a")
      check(game.stack:top()==s and s.submenu==nil,"A closes the letter")
      -- empty mailbox
      local g2=newGame(newSave())
      push(g2,MailboxMenu.new(g2,{save=g2.save}))
      t,close=frame(g2,"mailbox-empty")
      layout(sz.." empty mailbox",t,close)
    end
    -- ---------------------------------------------------------- party MAIL
    do
      local save=newSave();local game=newGame(save)
      save.party[1].item="FLOWER_MAIL"
      Mail.set(save,1,Mail.entry("FLOWER_MAIL","Take care of\nTOTODILE!","ELM",2))
      local closed=false
      local s=push(game,MailMenu.new(game,{save=save,slot=1,onClose=function()closed=true end}))
      local t,close=frame(game,"mailmenu")
      layout(sz.." mail menu",t,close)
      check(drew("TOTODILE!"),sz.." mail menu: the letter")
      fire(s,cellFor(t,"TAKE"))
      check(s.confirm~=nil,"TAKE: Send to PC?")
      t,close=frame(game,"mailmenu-confirm")
      layout(sz.." mail menu confirm",t,close)
      fire(s,cellFor(t,"YES"))
      check(Mail.mailboxCount(save)==1 and save.party[1].item==nil,"YES: the engine sent it to the MAILBOX")
      t=frame(game,"mailmenu-message")
      press(s,"a")
      check(closed,"the message closes the menu")
    end
    -- ---------------------------------------------------------- compose
    do
      local game=newGame(newSave())
      local done
      local s=push(game,MailCompose.new(game,{onDone=function(text)done=text end}))
      local t,close=frame(game,"compose")
      layout(sz.." compose",t,nil,false)
      check(close==nil,sz.." compose: no close button (B deletes, END leaves)")
      check(t.mode=="sub","compose: a miss types nothing")
      fire(s,cellFor(t,"H"));fire(s,cellFor(t,"I"))
      fire(s,cellFor(t,"lower"))
      check(s.lower==true,"lower: the engine's case switch")
      t=frame(game,"compose-lower")
      fire(s,cellFor(t,"a"))
      fire(s,cellFor(t,"DEL"))
      check(s.text=="HI","DEL: the engine deletes one")
      t=frame(game)
      fire(s,cellFor(t,"END"))
      check(done=="HI","END: onDone(\"HI\")")
    end
    -- ---------------------------------------------------------- Day-Care
    do
      local save=newSave();local game=newGame(save)
      local closed=false
      local s=push(game,DayCareMenu.new(game,{save=save,side="man",onClose=function()closed=true end}))
      settle(s)
      local t,close=frame(game,"daycare-message")
      layout(sz.." day-care",t,close,false)
      check(#t.cells==0,"day-care page: a tap anywhere is A")
      for _=1,12 do
        if s.confirm and s:yesNoVisible() then break end
        press(s,"a");settle(s)
      end
      t,close=frame(game,"daycare-yesno")
      layout(sz.." day-care yes/no",t,close,false)
      fire(s,cellFor(t,"NO"))
      check(s.confirm==nil and s.message~=nil,"NO: the engine's Come again.")
      settle(s);press(s,"a")
      check(closed,"the conversation closes")
    end
  end
  dims={1080,2520}

  -- ------------------------------------------------------------ touch
  do
    local game=newGame(newSave())
    local s=push(game,BankOfMom.new(game,{kind="deposit",saved=0,held=5000}))
    local T=100
    love.timer.getTime=function()return T end
    local thooks={}
    local tmod={id="touch",exports={},options={get=function()return nil end,define=function()end},read=function()return nil end,
      hooks={wrap=function(_,n,f,p)thooks[n]=thooks[n] or {};thooks[n][p]=f end},
      input={tap=function(_,g,b)press(g.stack:top(),b)end,press=function()return {} end,release=function()end},
      find=function()return {exports=mod.exports} end}
    setmetatable(tmod,{__index=mod})
    package.preload["src.core.TouchControls"]=function()return {active=true,layout=function()return {} end} end
    package.preload["src.core.TouchSkin"]=function()return {active=false} end
    assert(loadstring(assert(readFile("touch/main.lua")),"@touch/main.lua"))()(tmod)
    local ptr=thooks["input.pointer"][10]
    local function tap(x,y)
      ptr(function()end,game,{phase="pressed",x=x,y=y,id=1,source="touch"});T=T+.08
      ptr(function()end,game,{phase="released",x=x,y=y,id=1,source="touch"});T=T+.5
    end
    local t=frame(game)
    local up
    for _,c in ipairs(t.cells) do if c.button=="up" then up=c end end
    tap(up.x+up.w/2,up.y+up.h/2)
    check(s.amount==1,"touch: the ones digit's up arrow is the engine's UP (+1)")
    t=frame(game)
    tap(5,5)
    check(s.amount==1 and not s.done,"touch: a miss on the keypad does not accept")
    local _,close=frame(game)
    local got="none";s.onDone=function(a)got=a end
    tap(close.x+close.w/2,close.y+close.h/2)
    check(got==nil,"touch: the close button is B (Mom gets nil)")
  end

  -- ------------------------------------------------------------ MODERN UI off
  local function nativeOk(tag,s,game)
    rawset(mod,"_kimScreenTapTargets",nil)
    check(chain("screen.render_visible",function()return true end,s)==true,tag..": native screen renders")
    frame(game)
    check(rawget(mod,"_kimScreenTapTargets")==nil,tag..": no Modern window")
    nativeCalls=0
    G.push("all");s:draw();G.pop()
    check(nativeCalls>0,tag..": native draw ran ("..nativeCalls.." Chrome calls)")
  end
  for _,off in ipairs({{"gen2IntegratedModernUi","MODERN UI off"},{"menuUi","MENU UI off"},{"hideOriginalUi","HIDE ORIGINAL off"}}) do
    opts[off[1]]=false
    local save=newSave();local game=newGame(save)
    local s=push(game,ItemPcMenu.new(game,{save=save,items=ITEMS}))
    nativeOk(off[2].." item PC",s,game)
    press(s,"down")
    check(s.index==2,off[2]..": the native PC menu's own DOWN")
    local g=newGame(newSave())
    nativeOk(off[2].." bank",push(g,BankOfMom.new(g,{kind="withdraw",saved=10,held=10})),g)
    g=newGame(newSave());Mail.state(g.save).box[1]=Mail.entry("FLOWER_MAIL","Hi","MOM",1)
    nativeOk(off[2].." mailbox",push(g,MailboxMenu.new(g,{save=g.save})),g)
    g=newGame(newSave());g.save.party[1].item="FLOWER_MAIL"
    nativeOk(off[2].." mail menu",push(g,MailMenu.new(g,{save=g.save,slot=1})),g)
    g=newGame(newSave())
    nativeOk(off[2].." mail read",push(g,MailRead.new(g,{entry=Mail.entry("FLOWER_MAIL","Hi","MOM",1)})),g)
    g=newGame(newSave())
    nativeOk(off[2].." compose",push(g,MailCompose.new(g,{})),g)
    opts[off[1]]=nil
  end
  -- the Day-Care is a conversation: DIALOGUE UI decides, MENU UI does not
  do
    local g=newGame(newSave())
    local s=push(g,DayCareMenu.new(g,{save=g.save,side="lady"}))
    opts.menuUi=false
    frame(g)
    check(rawget(mod,"_kimScreenTapTargets")~=nil,"MENU UI off: the Day-Care stays Modern (a dialogue)")
    opts.menuUi=nil;opts.dialogueUi=false
    nativeOk("DIALOGUE UI off day-care",s,g)
    opts.dialogueUi=nil
  end

  for _,p in ipairs(shots) do print("png",p) end
  if failures>0 then print(("modern services: %d FAILED"):format(failures));os.exit(1) end
  print("modern services: PASS")
  love.event.quit(0)
end
