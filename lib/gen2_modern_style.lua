-- Kanto in Motion v1.5.3 - shared Gen 2 Modern UI style/settings bridge v1
--
-- Centralizes the Gen 1-style appearance controls used by the Gen 2 Modern
-- UI adapters.  Gameplay/input/state stay native; this module only resolves
-- presentation settings, fonts, opacity, framing and responsive scale.
return function(mod)
  local G = love.graphics
  local PLAIN_PIXEL = "assets/fonts/plainpixel/PlainPixel-Regular.ttf"
  local fontCache, imageCache = {}, {}

  local FALLBACK = {
    surface={.075,.105,.17,.96},raised={.12,.17,.27,.94},
    selected={.18,.43,.72,.96},accent={.48,.86,1,1},
    frame={.48,.86,1,1},frameShadow={.01,.02,.04,.42},
    text={.96,.98,1,1},muted={.74,.82,.92,1},divider={.38,.5,.68,.94},
  }

  local function clamp(v,a,b)
    v=tonumber(v) or a
    if v<a then return a end
    if v>b then return b end
    return v
  end

  local function opt(key, fallback)
    if not (mod.options and type(mod.options.get)=="function") then return fallback end
    local ok,value=pcall(mod.options.get,mod.options,key)
    if not ok or value == nil then return fallback end
    return value
  end

  local Style={}
  Style.opt=opt

  function Style.theme()
    local themes=mod._kantoInMotionGen2Themes
    local id=tostring(opt("gen2UiTheme","default"))
    return type(themes)=="table" and (themes[id] or themes.default) or FALLBACK
  end

  function Style.masterEnabled()
    return opt("gen2IntegratedModernUi",true)~=false
  end

  function Style.presenterEnabled(kind)
    if not Style.masterEnabled() then return false end
    kind=tostring(kind or "menu")
    if kind=="dialogue" then return opt("dialogueUi",true)~=false end
    if kind=="pokemon" then return opt("pokemonUi",true)~=false end
    if kind=="manager" then return opt("managerUi",true)~=false end
    if kind=="battle" then return opt("battleUiWip",true)~=false end
    return opt("menuUi",true)~=false
  end

  function Style.hideOriginal()
    return opt("hideOriginalUi",true)~=false
  end

  local function autoScalePercent(w,h,minimum,maximum,legacyCeiling,largeFactor)
    w,h=tonumber(w) or 640,tonumber(h) or 360
    local authored
    if h>w*1.2 then authored=w/400 else authored=math.min(w/640,h/360) end
    local legacy=(legacyCeiling or maximum)/100
    largeFactor=tonumber(largeFactor) or .5
    local ratio=math.max(math.min(authored,legacy),authored*largeFactor)
    return clamp(ratio*100,minimum,maximum)
  end

  -- Gen 2 layouts were authored much larger than the Gen 1 Modern UI.  Keep
  -- an internal neutral calibration so UI SCALE=100% has the cleaner Gen 1-
  -- like footprint; the exposed setting remains a true user multiplier.
  local GEN2_NEUTRAL_BASE=.78

  function Style.uiScale(w,h)
    local value=opt("uiScale","100")
    local pct
    if tostring(value):lower()=="auto" then
      pct=autoScalePercent(w,h,75,400,150,.5)
    else
      pct=clamp(value,75,400)
    end
    local scale=(pct/100)*GEN2_NEUTRAL_BASE
    if opt("minimalUi",false)==true then scale=scale*.90 end
    return scale,pct
  end

  function Style.fontScale(w,h)
    local value=opt("fontScale","100")
    local pixel=opt("pixelFont",false)==true
    if tostring(value):lower()=="auto" then
      local ui,pct=Style.uiScale(w,h)
      if pixel then
        return clamp(math.floor((pct/100)+.5),1,2),pct
      end
      return autoScalePercent(w,h,80,200,200,2/3)/100,pct
    end
    local pct=clamp(value,80,200)
    if pixel then return clamp(math.floor(pct/100+.5),1,2),pct end
    return pct/100,pct
  end

  function Style.dialogueScale()
    local value=tostring(opt("dialogueTextScale","inherit"))
    if value=="inherit" then return 1 end
    return clamp(value,100,200)/100
  end

  function Style.density()
    local value=tostring(opt("density","auto"))
    if value=="compact" then return .86 end
    if value=="comfortable" then return 1.12 end
    return 1
  end

  function Style.layoutStyle()
    local value=tostring(opt("layoutStyle","auto"))
    if value=="full" or value=="floating" then return value end
    return "floating"
  end

  function Style.panelOpacity(extra)
    local p=clamp(opt("panelOpacity",100),0,100)/100
    return clamp(p*(tonumber(extra) or 1),0,1)
  end

  function Style.foregroundOpacity(extra)
    local p=clamp(opt("foregroundOpacity",100),0,100)/100
    return clamp(p*(tonumber(extra) or 1),0,1)
  end

  function Style.color(c,alpha,foreground)
    c=c or {1,1,1,1}
    local a=alpha==nil and (c[4] or 1) or alpha
    if foreground then a=a*Style.foregroundOpacity(1) end
    G.setColor(c[1] or 1,c[2] or 1,c[3] or 1,clamp(a,0,1))
  end

  function Style.font(px)
    local ww,wh=G.getDimensions()
    local mult=Style.fontScale(ww,wh)
    px=math.max(8,math.floor((tonumber(px) or 12)*mult+.5))
    -- gen2-aio 0.9: Pixel Operator (lib/gen2_aio/font.lua) unless UI FONT = KIM
    local arenaFont=rawget(mod,"_kimArenaFont")
    if type(arenaFont)=="function" then
      local okA,fA=pcall(arenaFont,px)
      if okA and fA then return fA end
    end
    local pixel=opt("pixelFont",false)==true
    local key=(pixel and "pixel:" or "system:")..tostring(px)
    if fontCache[key] then return fontCache[key] end
    local ok,f
    if pixel then
      ok,f=pcall(G.newFont,PLAIN_PIXEL,px,"mono",1)
      if not ok or not f then ok,f=pcall(G.newFont,PLAIN_PIXEL,px,"mono") end
    else
      ok,f=pcall(G.newFont,px)
    end
    if not ok or not f then ok,f=pcall(G.newFont,px) end
    if ok and f then
      if f.setFilter then pcall(f.setFilter,f,pixel and "nearest" or "linear",pixel and "nearest" or "linear") end
      fontCache[key]=f
      return f
    end
    return G.getFont()
  end

  function Style.text(value,font,x,y,w,align,c)
    if font then G.setFont(font) end
    Style.color(c,nil,true)
    value=tostring(value or "")
    if w then
      local ok=pcall(G.printf,value,x,y,w,align or "left")
      if not ok then G.printf(value:gsub("[\128-\255]","?"),x,y,w,align or "left") end
    else
      local ok=pcall(G.print,value,x,y)
      if not ok then G.print(value:gsub("[\128-\255]","?"),x,y) end
    end
  end

  local function frameImage(c)
    -- gen2-aio 0.9.37: a theme may pick its frame (GEN 3, CUSTOM)
    local id=tostring((c and c.frameAsset) or opt("frameAsset","2"))
    -- gen2-aio 0.9.37: "4" = Gen 3 (FRLG-style) frame, greyscale so a
    -- theme's frameTint colours it
    local path=(id=="1" and "assets/pixel_frame1.png")
      or (id=="3" and "assets/pixel_frame3.png")
      or (id=="4" and "assets/gen2_aio/frames/pixel_frame_gen3.png")
      or "assets/pixel_frame2.png"
    if imageCache[path]~=nil then return imageCache[path] or nil end
    local ok,img=false,nil
    if mod.assets and type(mod.assets.image)=="function" then
      ok,img=pcall(mod.assets.image,mod.assets,path)
    end
    if (not ok or not img) and G and type(G.newImage)=="function" then
      ok,img=pcall(G.newImage,path)
    end
    if ok and img then
      if img.setFilter then pcall(img.setFilter,img,"nearest","nearest") end
      imageCache[path]=img
      return img
    end
    imageCache[path]=false
    return nil
  end

  local function drawNineSlice(img,x,y,w,h,pixelScale)
    if not (img and type(img.getDimensions)=="function" and type(G.newQuad)=="function") then return false end
    local iw,ih=img:getDimensions()
    if not iw or not ih or iw<3 or ih<3 then return false end
    local slice=math.max(1,math.min(24,math.floor(math.min(iw,ih)/2)))
    pixelScale=clamp(math.floor(tonumber(pixelScale) or 1),1,4)
    -- The authored 128px pixel frames have their decorative edges inset
    -- from the image boundary. Extend the image outside the panel so the
    -- visible border wraps its content instead of occupying its interior.
    -- Match the seven-source-pixel offset of the shared Modern UI renderer.
    local borderOutset=math.min(7,slice)*pixelScale
    x,y=x-borderOutset,y-borderOutset
    w,h=w+borderOutset*2,h+borderOutset*2
    local corner=math.min(slice*pixelScale,w/2,h/2)
    local function part(sx,sy,sw,sh,dx,dy,dw,dh)
      if sw<=0 or sh<=0 or dw<=0 or dh<=0 then return end
      local ok,q=pcall(G.newQuad,sx,sy,sw,sh,iw,ih)
      if ok and q then G.draw(img,q,dx,dy,0,dw/sw,dh/sh) end
    end
    local midSW=math.max(1,iw-slice*2); local midSH=math.max(1,ih-slice*2)
    local midW=math.max(0,w-corner*2); local midH=math.max(0,h-corner*2)
    part(0,0,slice,slice,x,y,corner,corner)
    part(slice,0,midSW,slice,x+corner,y,midW,corner)
    part(iw-slice,0,slice,slice,x+w-corner,y,corner,corner)
    part(0,slice,slice,midSH,x,y+corner,corner,midH)
    part(iw-slice,slice,slice,midSH,x+w-corner,y+corner,corner,midH)
    part(0,ih-slice,slice,slice,x,y+h-corner,corner,corner)
    part(slice,ih-slice,midSW,slice,x+corner,y+h-corner,midW,corner)
    part(iw-slice,ih-slice,slice,slice,x+w-corner,y+h-corner,corner,corner)
    return true
  end

  function Style.panel(x,y,w,h,c,alpha)
    c=c or Style.theme()
    local style=tostring(c.frameStyle or opt("frameStyle","pixel"))
    if style=="theme" then style="soft" end
    local fillAlpha=Style.panelOpacity(alpha or 1)
    local radius=(style=="plain" or style=="pixel") and 0 or math.max(8,math.min(w,h)*.018)
    Style.color(c.frameShadow or {0,0,0,.4},.18*fillAlpha)
    G.rectangle("fill",x+2,y+3,w,h,radius,radius)
    Style.color(c.surface,math.min(1,(c.surface[4] or 1)*fillAlpha))
    G.rectangle("fill",x,y,w,h,radius,radius)
    if style=="pixel" then
      -- gen2-aio 0.9.37: themes may tint the PNG frame (GEN 3, CUSTOM)
      Style.color(c.frameTint or {1,1,1,1},Style.foregroundOpacity(1))
      local img=frameImage(c)
      if img and drawNineSlice(img,x,y,w,h,opt("frameScale","2")) then return end
    end
    Style.color(c.frame or c.accent,nil,true)
    G.setLineWidth(math.max(2,math.min(w,h)*.0045))
    G.rectangle("line",x,y,w,h,radius,radius)
  end

  function Style.panelBox(sx,sy,sw,sh,logicalW,logicalH,maxW,maxH)
    local scale=Style.uiScale(sw,sh)
    local w=math.min((logicalW or 900)*scale,sw*(maxW or .90))
    local h=math.min((logicalH or 640)*scale,sh*(maxH or .88))
    if Style.layoutStyle()=="full" then
      w=sw*.94; h=sh*.92
    end
    return sx+(sw-w)/2,sy+(sh-h)/2,w,h,scale
  end

  ---------------------------------------------------------------------------
  -- gen2-aio: shared menu chrome. Every full Modern menu window draws the same
  -- footer (Style.footer) and the same close button (Style.closeButton) so the
  -- bottom bar and the way out look and sit alike on every screen.
  --
  --   Style.footerHeight()            -> band height (same on every screen)
  --   Style.footer(x,y,w,h,spec)      -> draws the band along the window's
  --       bottom, returns the band's top y. spec = { info = "CAUGHT 3",
  --       hints = { {"LR","POCKET"}, {"A","CHOOSE"}, {"B","BACK"} } or a
  --       string such as "UP/DOWN SCROLL   A PAGE   B BACK", colors = theme }.
  --       Keys: A, B, SELECT, START, LR (drawn as left/right triangles), UD
  --       (up/down triangles). B always reads BACK.
  --   Style.closeReserve()            -> width to keep clear at the right end
  --       of a window's title row.
  --   Style.closeButton(x,y,w,h,c,opts) -> draws the close button in the
  --       window's top-right corner and records it for this frame; the late
  --       render.hud pass below publishes it (mod._kimMenuClose) for KIM Touch,
  --       which taps B there. opts.selected highlights it (a native CANCEL
  --       row is selected).
  ---------------------------------------------------------------------------
  local function clockNow()
    return love and love.timer and love.timer.getTime and love.timer.getTime() or 0
  end

  function Style.chromeScale()
    local sw,sh=G.getDimensions()
    return (Style.uiScale(sw,sh))
  end

  local FOOTER_PX=19
  local function footerFont(k)
    return Style.font(FOOTER_PX*Style.chromeScale()*(k or 1))
  end

  function Style.chromePad()
    return math.max(12,math.floor(22*Style.chromeScale()+.5))
  end

  function Style.footerHeight()
    local fh=footerFont():getHeight()
    local vpad=math.max(6,math.floor(fh*.45+.5))
    -- 0.9.69: a close button in a bottom corner keeps its full size with a
    -- margin all round, so the band grows to hold it
    if Style.closeCorner and Style.closeCorner()~="tr" then
      return math.max(fh+vpad*2,math.floor(math.max(26,fh*1.9)+.5)+2*math.max(8,math.floor(fh*.55+.5)))
    end
    return fh+vpad*2
  end

  local KEY_ALIASES={
    {"UP/DOWN/LEFT/RIGHT","UD"},{"UP/DOWN","UD"},{"UP-DOWN","UD"},{"D-PAD","UD"},
    {"LEFT/RIGHT","LR"},{"< >","LR"},{"<>","LR"},{"L/R","LR"},
    {"B/START","B"},{"B/SELECT","B"},{"A/B","B"},
    {"SELECT","SELECT"},{"START","START"},{"A","A"},{"B","B"},
  }
  -- "UP/DOWN SCROLL   A PAGE   B BACK" -> { {"UD","SCROLL"}, {"A","PAGE"}, {"B","BACK"} }
  -- Segments without a key are returned as info text.
  function Style.parseHints(value)
    local hints,info={},{}
    value=tostring(value or ""):gsub("\n"," ")
    value=value:gsub(":%s"," ")
    for seg in (value.."   "):gmatch("(.-)%s%s+") do
      seg=seg:gsub("^%s+",""):gsub("%s+$","")
      if seg~="" then
        local upper=seg:upper()
        local key,rest
        for _,alias in ipairs(KEY_ALIASES) do
          local a=alias[1]
          if upper==a or upper:sub(1,#a+1)==a.." " then
            key=alias[2]; rest=upper:sub(#a+2):gsub("^%s+","")
            break
          end
        end
        if key then
          if key=="B" then rest="BACK" end
          hints[#hints+1]={key,rest~="" and rest or nil}
        else
          info[#info+1]=upper
        end
      end
    end
    return hints,(#info>0 and table.concat(info,"  ") or nil)
  end

  local function keyWidth(key,f)
    local fh=f:getHeight()
    if key=="LR" or key=="UD" then return fh*1.05 end
    return f:getWidth(key)
  end
  local function hintWidth(h,f)
    local fh=f:getHeight()
    local w=keyWidth(h[1],f)
    if h[2] and h[2]~="" then w=w+fh*.35+f:getWidth(h[2]) end
    return w
  end
  local function hintsWidth(list,f)
    local fh=f:getHeight()
    local total=0
    for i,h in ipairs(list) do
      total=total+hintWidth(h,f)
      if i>1 then total=total+fh*1.1 end
    end
    return total
  end
  local function triangle(cx,cy,s,dir)
    if dir=="left" then G.polygon("fill",cx-s*.5,cy,cx+s*.4,cy-s*.55,cx+s*.4,cy+s*.55)
    elseif dir=="right" then G.polygon("fill",cx+s*.5,cy,cx-s*.4,cy-s*.55,cx-s*.4,cy+s*.55)
    elseif dir=="up" then G.polygon("fill",cx,cy-s*.5,cx-s*.55,cy+s*.4,cx+s*.55,cy+s*.4)
    else G.polygon("fill",cx,cy+s*.5,cx-s*.55,cy-s*.4,cx+s*.55,cy-s*.4) end
  end
  local function ellipsize(value,f,maxW)
    if f:getWidth(value)<=maxW then return value end
    local out=value
    while #out>0 and f:getWidth(out.."...")>maxW do
      out=out:gsub("[\1-\127\194-\244][\128-\191]*$","")
    end
    if out=="" then return nil end
    return out.."..."
  end

  local footerReserve -- set with the close-button metrics below
  function Style.footer(x,y,w,h,spec)
    spec=spec or {}
    local c=spec.colors or Style.theme()
    local pad=Style.chromePad()
    local bandH=Style.footerHeight()
    local top=y+h-bandH
    local hints,parsedInfo
    if type(spec.hints)=="string" then hints,parsedInfo=Style.parseHints(spec.hints)
    else hints=spec.hints or {} end
    -- 0.9.69: with the touch controls up, the floating B is hidden while a
    -- menu window shows its close / back button, so the footer stops
    -- telling the player to press it
    local touchUp=false
    do
      local touch=mod.exports and mod.exports.touch
      if type(touch)=="table" and type(touch.active)=="function" then
        local okT,on=pcall(touch.active); touchUp=okT and on==true
      end
    end
    local copy={}
    for _,hh in ipairs(hints) do
      local label=hh[2]
      if hh[1]=="B" then label="BACK" end
      if not (touchUp and hh[1]=="B") then
        copy[#copy+1]={hh[1],label and tostring(label):upper() or nil}
      end
    end
    hints=copy
    local info=spec.info or parsedInfo
    if info~=nil then info=tostring(info):upper(); if info=="" then info=nil end end

    Style.color(c.divider or c.muted,nil,true)
    G.rectangle("fill",x+pad,top,w-pad*2,math.max(1,math.floor(Style.chromeScale()+.5)))

    local reserve,side=footerReserve()
    local avail=w-pad*2-reserve
    local f=footerFont()
    local function total(fnt,inf,list)
      local t=hintsWidth(list,fnt)
      if inf then t=t+fnt:getWidth(inf)+(#list>0 and fnt:getHeight()*1.6 or 0) end
      return t
    end
    local need=total(f,info,hints)
    if need>avail then
      local k=math.max(.8,avail/need*.98)
      f=footerFont(k)
      need=total(f,info,hints)
    end
    if need>avail and info then
      local room=avail-hintsWidth(hints,f)-(#hints>0 and f:getHeight()*1.6 or 0)
      info=room>f:getWidth("MMM") and ellipsize(info,f,room) or nil
      need=total(f,info,hints)
    end
    while need>avail and #hints>1 do
      table.remove(hints,1)
      need=total(f,info,hints)
    end

    local fh=f:getHeight()
    local cy=top+bandH*.5
    local ty=math.floor(cy-fh*.5+.5)
    G.setFont(f)
    local leftX=x+pad+(side=="left" and reserve or 0)
    if info then
      Style.text(info,f,leftX,ty,nil,nil,c.muted)
    end
    local hx=x+w-pad-(side=="right" and reserve or 0)-hintsWidth(hints,f)
    local keyColor=c.text or c.muted
    for i,hh in ipairs(hints) do
      if i>1 then hx=hx+fh*1.1 end
      local key=hh[1]
      if key=="LR" or key=="UD" then
        local s=fh*.42
        Style.color(keyColor,nil,true)
        if key=="LR" then
          triangle(hx+s*.5,cy,s,"left"); triangle(hx+fh*1.05-s*.5,cy,s,"right")
        else
          triangle(hx+s*.55,cy,s,"up"); triangle(hx+fh*1.05-s*.55,cy,s,"down")
        end
      else
        Style.text(key,f,hx,ty,nil,nil,keyColor)
      end
      hx=hx+keyWidth(key,f)
      if hh[2] and hh[2]~="" then
        hx=hx+fh*.35
        Style.text(hh[2],f,hx,ty,nil,nil,c.muted)
        hx=hx+f:getWidth(hh[2])
      end
    end
    return top
  end

  -- 0.9.64: MENU BUTTON corner (option menuClosePos): "tr" top right of
  -- the title row, or "br" / "bl" inside the footer band at that end
  function Style.closeCorner()
    local v=tostring(opt("menuClosePos","tr"))
    if v=="br" or v=="bl" then return v end
    return "tr"
  end
  -- the button in a footer corner: size, side inset and top
  local function footerClose(y,h)
    local fh=footerFont():getHeight()
    local bandH=Style.footerHeight()
    local size=math.floor(math.max(26,fh*1.9)+.5)
    size=math.min(size,math.floor(bandH*.8))
    -- a little above centre: the window frame eats into the band's bottom
    local gap=math.floor((bandH-size)*.42)
    local inset=math.max(gap+8,math.floor(size*.5+.5))
    return size,inset,(y and h) and (y+h-bandH+gap) or nil
  end
  local function closeMetrics(x,y,w,h)
    local fh=footerFont():getHeight()
    local size=math.floor(math.max(26,fh*1.9)+.5)
    size=math.min(size,math.floor(math.min(w,h)*.16))
    local inset=math.max(5,math.floor(size*.24+.5))
    local corner=Style.closeCorner()
    if corner~="tr" then
      -- 0.9.69: a margin all round inside the footer band, so the button
      -- clears the footer's divider line and the window's rounded corner
      local size2,inset2,by=footerClose(y,h)
      if corner=="br" then return x+w-inset2-size2,by,size2,inset2 end
      return x+inset2,by,size2,inset2
    end
    return x+w-inset-size,y+inset,size,inset
  end

  -- width a title row keeps clear at its right end (0 when the button is
  -- in the footer)
  function Style.closeReserve()
    if Style.closeCorner()~="tr" then return 0 end
    local fh=footerFont():getHeight()
    local size=math.floor(math.max(26,fh*1.9)+.5)
    local inset=math.max(5,math.floor(size*.24+.5))
    return size+inset*2
  end
  -- width the footer keeps clear at the button's end ("left"/"right"/nil)
  footerReserve=function()
    local corner=Style.closeCorner()
    if corner=="tr" then return 0,nil end
    local size,inset=footerClose()
    return size+inset*2,(corner=="bl") and "left" or "right"
  end

  function Style.closeButton(x,y,w,h,c,opts)
    c=c or Style.theme()
    opts=opts or {}
    local bx,by,size=closeMetrics(x,y,w,h)
    local r=math.max(3,size*.22)
    local fill=opts.selected and (c.selected or c.accent) or (c.raised or c.surface)
    Style.color(fill,math.min(1,(fill[4] or 1)*Style.panelOpacity(1)))
    G.rectangle("fill",bx,by,size,size,r,r)
    Style.color(c.frame or c.accent,nil,true)
    G.setLineWidth(math.max(1.5,size*.06))
    G.rectangle("line",bx,by,size,size,r,r)
    -- 0.9.63: the glyph (close X or back arrow) is drawn by the late pass
    -- below, once it knows what is on top of the stack.
    -- A generous hit area: mostly up/right (away from the window's content),
    -- a little left/down.
    Style._frameClose={x=bx,y=by,w=size,h=size,color=c.text or {1,1,1,1},
      -- 0.9.64: centred on the button (it used to stop halfway down it, so
      -- taps on its lower half were missed), larger toward the window edge
      hit=(Style.closeCorner()=="tr")
        and {x=bx-size*.7,y=by-size*1.1,w=size*2.6,h=size*2.6}
        or {x=bx-size*.7,y=by-size*.7,w=size*2.4,h=size*2.4}}
    return bx,by,size
  end

  -- 0.9.63: back arrow vs close X. B on these states steps back INSIDE the
  -- same screen (a popup, a list, a card, a sub-page); everywhere else B
  -- closes the screen and the button shows X. Tapping it is B either way.
  local function req(name) local ok,m=pcall(require,name); return ok and m or nil end
  local function isA(state,name)
    local M=req(name)
    return M~=nil and type(state)=="table" and getmetatable(state)==M
  end
  function Style.closeIsBack(game,top)
    if type(top)~="table" then return false end
    if isA(top,"src.ui.gen2.PartyMenu") then
      return top.submenu~=nil or top.switchFrom~=nil
    end
    if isA(top,"src.ui.gen2.HeldItemMenu") then return true end
    if isA(top,"src.ui.gen2.PackMenu") then
      return top.submenu~=nil or top.confirm~=nil or top.qtyState~=nil
    end
    if isA(top,"src.ui.gen2.MartMenu") then
      local p=tostring(top.phase or "")
      return p=="buy" or p=="sell" or p=="buyQuantity" or p=="sellQuantity"
    end
    if isA(top,"src.ui.gen2.PokedexMenu") then
      return top.view~=nil and top.view~="list"
    end
    if isA(top,"src.ui.gen2.Pokegear") then
      return top.mode=="card" or top.phoneSubmenu~=nil or top.call~=nil
    end
    if isA(top,"src.ui.gen2.OptionsMenu") then
      -- a settings / quick-menu sub-page sitting on another options page
      local states=game and game.stack and game.stack.states
      if type(states)=="table" then
        for i=#states,2,-1 do
          if states[i]==top then return isA(states[i-1],"src.ui.gen2.OptionsMenu") end
        end
      end
    end
    return false
  end
  local function drawGlyph(reg,back)
    local size=reg.w
    local cx,cy=reg.x+size*.5,reg.y+size*.5
    local k=size*.27
    Style.color(reg.color,nil,true)
    G.setLineWidth(math.max(2,size*.1))
    pcall(G.setLineStyle,"smooth")
    if back then
      -- a left arrow: shaft plus a chevron head
      G.line(cx-k,cy,cx+k,cy)
      G.line(cx-k,cy,cx-k*.15,cy-k*.85)
      G.line(cx-k,cy,cx-k*.15,cy+k*.85)
    else
      G.line(cx-k,cy-k,cx+k,cy+k)
      G.line(cx-k,cy+k,cx+k,cy-k)
    end
  end

  -- The late pass: published only for a frame in which a menu window drew
  -- its close button, and tied to the state on top of the stack that frame.
  if mod.hooks and type(mod.hooks.wrap)=="function" then
    local unpackFn=table.unpack or unpack
    mod.hooks:wrap("render.hud",function(nextFn,game,viewport)
      Style._frameClose=nil
      local result={pcall(nextFn,game,viewport)}
      local ok=table.remove(result,1)
      local reg=Style._frameClose
      Style._frameClose=nil
      local stack=game and game.stack
      local top=stack and type(stack.top)=="function" and stack:top() or nil
      if reg and top~=nil then
        local okB,back=pcall(Style.closeIsBack,game,top)
        reg.back=okB and back==true or false
        G.push("all"); G.origin()
        pcall(drawGlyph,reg,reg.back)
        G.pop()
        reg.state=top; reg.time=clockNow()
        rawset(mod,"_kimMenuClose",reg)
      else
        rawset(mod,"_kimMenuClose",nil)
      end
      if not ok then error(result[1],0) end
      return unpackFn(result)
    end,120000)
  end

  mod._kantoInMotionGen2Ui=Style
  return Style
end
