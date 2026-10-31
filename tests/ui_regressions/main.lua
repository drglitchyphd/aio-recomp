io.stdout:setvbuf("no")
local root=love.filesystem.getSource():gsub("/tests/ui_regressions/?$","").."/"
local output=os.getenv("AIO_TEST_OUTPUT") or os.getenv("TEMP") or "/tmp"
local classes={}
for _,name in ipairs({"src.render.TextBox","src.ui.ChoiceBox","src.ui.gen2.MartMenu",
  "src.ui.gen2.TradeMenu","src.ui.gen2.TradeAnim","src.ui.gen2.CallerBox","src.ui.gen2.Pokegear",
  "src.ui.gen2.StartMenu","src.ui.gen2.PackMenu","src.ui.gen2.TrainerCard","src.ui.gen2.SaveMenu","src.ui.gen2.OptionsMenu"}) do
  local class={};class.__index=class;classes[name]=class
  package.preload[name]=function()return class end
end
local Typer={text=function(s,page)return page end,typing=function(s)return s.typing==true end}
package.preload["src.ui.gen2.Typer"]=function()return Typer end
package.preload["src.core.gen2.TradeAnim"]=function()return {TOTAL=100}end
function love.errorhandler(err) print(err);os.exit(1) end
function love.load()
  local G=love.graphics
  local dims={1080,2520}
  G.getDimensions=function()return unpack(dims)end
  local hooks,opts={},{}
  local mod={exports={},options={get=function(_,k)return opts[k]end},hooks={wrap=function(_,name,fn,priority)
    hooks[name]=hooks[name] or {};hooks[name][#hooks[name]+1]={fn=fn,p=priority}
  end}}
  mod._kimArenaDiag=function(k,v)error(k..": "..v)end
  local S=assert(loadfile(root.."lib/gen2_modern_style.lua"))()(mod)
  local draws={}
  local originalText=S.text
  S.text=function(value,font,x,y,w,align,c)
    draws[#draws+1]={text=tostring(value),font=font,x=x,y=y,w=w,align=align}
    return originalText(value,font,x,y,w,align,c)
  end
  assert(loadfile(root.."lib/gen2_modern_dialog_ui.lua"))()(mod)
  assert(assert(loadfile(root.."lib/gen2_modern_core_menus.lua"))()(mod))
  assert(loadfile(root.."lib/crystal_aio/modern_pages.lua"))()({mod=mod})
  assert(loadfile(root.."lib/crystal_aio/modern_trade.lua"))()({mod=mod})
  assert(loadfile(root.."lib/crystal_aio/modern_caller.lua"))()({mod=mod})
  local function chain(name,base,...)
    local h=hooks[name] or {}
    table.sort(h,function(a,b)return a.p<b.p end)
    local fn=base
    for _,link in ipairs(h)do local nextFn=fn;fn=function(...)return link.fn(nextFn,...)end end
    return fn(...)
  end
  local function frame(state,name,states)
    draws={}
    local game={stack={states=states or {state},top=function()return state end}}
    local canvas=G.newCanvas(unpack(dims))
    G.setCanvas(canvas);G.clear(.12,.20,.18,1)
    chain("render.hud",function()end,game,{})
    G.setCanvas()
    local file=assert(io.open(output.."/aio-"..name.."-"..dims[1]..".png","wb"))
    file:write(canvas:newImageData():encode("png"):getString());file:close();canvas:release()
    return draws
  end
  local function text(value)
    for _,d in ipairs(draws) do if d.text==value then return d end end
    error("missing text "..value)
  end
  local Mart=classes["src.ui.gen2.MartMenu"]
  local mart=setmetatable({phase="buy",index=1,entries={{name="ESCAPE ROPE",price=550},{name="PARLYZ HEAL",price=200}},
    selected=function(s)return s.entries[s.index]end,description=function()return "Escape from a cave.<NEXT>Useful on a long journey."end,
    money=function()return 12345 end},Mart)
  for _,d in ipairs({{1080,2520},{2184,1968},{360,800},{1280,720}}) do
    dims=d
    frame(mart,"mart-buy")
    local name,price=text("ESCAPE ROPE"),text("¥550")
    assert(name.x+name.font:getWidth(name.text)<price.x,"name/price overlap")
    local title
    for _,draw in ipairs(draws)do if draw.text=="ESCAPE ROPE" then title=draw end end
    local desc=text("Escape from a cave.\nUseful on a long journey.")
    local _,wrap=title.font:getWrap(title.text,title.w)
    assert(desc.y>=title.y+#wrap*title.font:getHeight(),"title/description overlap")
    mart.phase="top";mart.topLines={"Hello! How may I","help you today?"}
    frame(mart,"mart-top")
    local a,b=text(mart.topLines[1]),text(mart.topLines[2])
    local _,wrapped=a.font:getWrap(a.text,a.w)
    assert(b.y>=a.y+#wrapped*a.font:getHeight(),"welcome line overlap")
    mart.phase="buy"
    local page={cursor=2}
    function page:_aioModernData()return {title="NUZLOCKE SETUP",selected=self.cursor,
      rows={{label="LEVEL CAP",value="GYMS",select=function(st)st.cursor=1 end},{label="RULES LOCKED",value="OFF"}},
      help="These settings belong to the new game. Existing saves keep their rules."}end
    frame(page,"modern-setup")
    assert(chain("screen.render_visible",function()return true end,page)==false)
    mod._kimScreenTapTargets.cells[1].select(page);assert(page.cursor==1)
  end
  dims={1080,2520}
  local Trade=classes["src.ui.gen2.TradeMenu"]
  local trade=setmetatable({confirm={pages={{"Want to trade your","BELLSPROUT?"}},page=1,choice=1}},Trade)
  frame(trade,"trade-confirm")
  assert(#mod._kimScreenTapTargets.cells==2)
  mod._kimScreenTapTargets.cells[2].select(trade);assert(trade.confirm.choice==2)
  trade.typing=true;frame(trade,"trade-typing");assert(#mod._kimScreenTapTargets.cells==0)
  trade.typing=false
  local anim=setmetatable({give={name="BELLSPROUT"},get={name="ONIX"},frame=50},classes["src.ui.gen2.TradeAnim"])
  frame(anim,"trade-animation")
  local Gear=classes["src.ui.gen2.Pokegear"]
  Gear.PHONE_SUBMENUS={callDeleteCancel={entries={"CALL","DELETE","CANCEL"}}}
  local gear=setmetatable({cards={{id="phone"}},mode="card",phoneSubmenu="callDeleteCancel",phoneSubmenuCursor=0,
    phoneList=function()return {1,2}end,contactRow=function()return "JOEY:","YOUNGSTER"end},Gear)
  frame(gear,"phone-submenu")
  text("DELETE");text("CANCEL")
  local delete
  for _,cell in ipairs(mod._kimScreenTapTargets.cells) do
    if cell.select then cell.select(gear);if gear.phoneSubmenuCursor==1 then delete=true;break end end
  end
  assert(delete,"phone submenu must provide a tappable DELETE row")
  gear.phoneSubmenu=nil;gear.call={text="No signal in this area."}
  frame(gear,"phone-call");text("No signal in this area.")
  local caller=setmetatable({name="JOEY",className="YOUNGSTER"},classes["src.ui.gen2.CallerBox"])
  frame(caller,"incoming-call");text("JOEY\nYOUNGSTER")
  opts.gen2IntegratedModernUi=false
  assert(chain("screen.render_visible",function()return true end,trade)==true)
  print("UI regressions: Mart columns/wrapping, four screen sizes, setup taps, trade typing/choices, native fallback PASS")
  love.event.quit(0)
end
