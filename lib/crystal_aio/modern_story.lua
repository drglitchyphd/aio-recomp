-- gen2-aio 0.9.75: Modern windows for Crystal's story screens -- the Hall of
-- Fame (the induction after the Champion and the PC's roster viewer), the
-- #DEX diploma, the egg hatch, the Unown sliding puzzle and the ALPH RUINS
-- STAMP printer. The engine classes stay authoritative: their update, frame
-- counts, sounds, music and callbacks run untouched. This file only hides the
-- native 160x144 draw while MODERN UI + MENU UI are on and paints the same
-- live state in a Modern window. Touch cells press the screen's own buttons.
--
-- The cutscenes (Hall of Fame induction, egg hatch) keep their animation on
-- a paper "stage": the native pic routines (drawScrolled, drawPortrait,
-- drawPic, drawSprites) are called under a transform that maps the Game Boy
-- screen onto the stage, so every slide, wobble, crack and shell fragment is
-- the engine's own, frame for frame. Where KIM HD art exists the hatchling and
-- the Hall of Famer are swapped for it at the same spot.
return function(host)
  local mod,G=host.mod,love.graphics
  local function req(n) local ok,m=pcall(require,n); return ok and m or nil end
  -- resolved lazily: the classes pull in render modules that need a live game
  local CLASSES={hof="src.ui.gen2.HallOfFame",diploma="src.ui.gen2.Diploma",
    hatch="src.ui.gen2.EggHatchAnim",puzzle="src.ui.gen2.UnownPuzzle",printer="src.ui.gen2.UnownPrinter"}
  local loaded={}
  local function class(k)
    if loaded[k]==nil then loaded[k]=req(CLASSES[k]) or false end
    return loaded[k] or nil
  end
  local function kindOf(s)
    if type(s)~="table" then return nil end
    local mt=getmetatable(s)
    if not mt then return nil end
    for k in pairs(CLASSES) do if class(k)==mt then return k end end
  end
  local function enabled()
    local S=mod._kantoInMotionGen2Ui
    return S and S.presenterEnabled("menu") and S.hideOriginal()
  end
  -- a draw that failed once goes back to the native screen for good
  local Broken=setmetatable({},{__mode="k"})
  local function isTop(s)
    local st=s.game and s.game.stack
    return not (st and type(st.top)=="function") or st:top()==s
  end
  local function now() return love.timer and love.timer.getTime() or 0 end
  -- the screen's own buttons, queued for its next update like a pad press
  local function press(s,btn)
    if mod.input and type(mod.input.tap)=="function" then pcall(mod.input.tap,mod.input,s.game,btn) end
  end

  -- ------------------------------------------------------------ shared
  local PAPER={.97,.97,.94,1}
  -- need(L): the pixel height the content wants once widths and fonts are
  -- known, so a tall phone screen gets a window the size of its content
  local function layout(capH,need)
    local S=mod._kantoInMotionGen2Ui
    local W,H=G.getDimensions()
    local scale=math.min(W/800,H/650,1.35)
    local pad=math.max(12,22*scale)
    local L={S=S,c=S.theme(),W=W,H=H,scale=scale,pad=pad,
      title=S.font(math.max(18,31*scale)),body=S.font(math.max(14,24*scale)),
      small=S.font(math.max(12,19*scale)),big=S.font(math.max(20,40*scale))}
    L.w=math.min(W-pad*2,1100*scale)
    L.h=math.min(H-pad*2,capH*scale)
    if need then L.h=math.min(L.h,math.floor(need(L))) end
    L.x,L.y=math.floor((W-L.w)/2),math.floor((H-L.h)/2)
    -- ClearTilemap: nothing of the map survives under these screens
    L.S.color(L.c.surface,1);G.rectangle("fill",0,0,W,H)
    L.S.panel(L.x,L.y,L.w,L.h,L.c,.98)
    return L
  end
  local function taps(s)
    return {state=s,kind="generic",generic=true,mode="list",cells={},phase=s.phase,time=now()}
  end
  local function cell(t,x,y,w,h,select,button,extra)
    if button==nil then button="a" end
    local c={kind="row",index=#t.cells+1,x=x,y=y,w=w,h=h,select=select,button=button}
    for k,v in pairs(extra or {}) do c[k]=v end
    t.cells[#t.cells+1]=c
    return c
  end
  local function opt(k,d) local S=mod._kantoInMotionGen2Ui; return S and S.opt and S.opt(k,d) or d end
  local function hdOn()
    return opt("menuSprites",true)~=false and tostring(opt("gen2MenuSpriteSource","kim"))~="vanilla"
  end
  -- KIM's HD front sprite (MENU SPRITES = KIM), the art the party and summary use
  local function hdArt(species,mon)
    if not (species and hdOn() and mod.exports and type(mod.exports.getSprite)=="function") then return nil end
    local m={}
    if type(mon)=="table" then for k,v in pairs(mon) do m[k]=v end end
    m.species=species
    local ok,img=pcall(mod.exports.getSprite,species,{generation="hd",mon=m,side="front"})
    if ok and img and type(img.getDimensions)=="function" then return img end
  end
  -- image (or image + quad) fitted into a box, standing on its bottom edge
  local function fit(img,quad,x,y,w,h,alpha)
    if not img then return false end
    local iw,ih
    if quad then local _,_,qw,qh=quad:getViewport(); iw,ih=qw,qh else iw,ih=img:getDimensions() end
    iw,ih=math.max(1,iw),math.max(1,ih)
    local k=math.min(w/iw,h/ih)
    G.setColor(1,1,1,alpha or 1)
    local dx,dy=x+(w-iw*k)/2,y+h-ih*k
    if quad then G.draw(img,quad,dx,dy,0,k,k) else G.draw(img,dx,dy,0,k,k) end
    return true
  end
  local function paper(L,x,y,w,h)
    local r=math.max(6,8*L.scale)
    G.setColor(PAPER);G.rectangle("fill",x,y,w,h,r,r)
    L.S.color(L.c.frame or L.c.accent,.55,true);G.setLineWidth(math.max(1.5,2*L.scale))
    G.rectangle("line",x,y,w,h,r,r)
  end
  -- Draw native pic routines into a stage: the Game Boy rectangle gx,gy,gw,gh
  -- is fitted into x,y,w,h and clipped to it.
  local function gbStage(x,y,w,h,gx,gy,gw,gh,fn)
    local k=math.min(w/gw,h/gh)
    G.push("all")
    G.intersectScissor(x,y,w,h)
    G.translate(x+(w-gw*k)/2-gx*k,y+(h-gh*k)/2-gy*k)
    G.scale(k,k)
    local ok,err=pcall(fn)
    G.pop()
    if not ok then error(err,0) end
    return k
  end
  local function trim(t) return (tostring(t or ""):gsub("^%s+",""):gsub("%s+$","")) end
  local function clean(t) return (trim(t):gsub("#","POKé")) end
  local function genderMark(cx,cy,size,g)
    if g~="male" and g~="female" then return end
    G.setColor(g=="male" and {.28,.66,1,1} or {1,.40,.66,1})
    G.setLineWidth(math.max(1.5,size*.12))
    local r=size*.24
    if g=="male" then
      local ox,oy=cx-size*.1,cy+size*.1
      G.circle("line",ox,oy,r)
      local ex,ey=cx+size*.36,cy-size*.36
      G.line(ox+r*.72,oy-r*.72,ex,ey)
      G.line(ex-size*.2,ey,ex,ey,ex,ey+size*.2)
    else
      local ox,oy=cx,cy-size*.14
      G.circle("line",ox,oy,r)
      G.line(ox,oy+r,ox,cy+size*.4)
      G.line(ox-size*.18,cy+size*.2,ox+size*.18,cy+size*.2)
    end
  end
  -- a rounded button the touch layer can press
  local function pill(L,x,y,w,h,label,on)
    local r=h/2
    L.S.color(on and L.c.selected or (L.c.raised or L.c.surface));G.rectangle("fill",x,y,w,h,r,r)
    L.S.color(L.c.frame or L.c.accent,on and 1 or .6,true);G.setLineWidth(math.max(1.5,1.5*L.scale))
    G.rectangle("line",x,y,w,h,r,r)
    L.S.text(label,L.small,x,y+(h-L.small:getHeight())/2,w,"center",L.c.text)
  end

  -- ------------------------------------------------------------ Hall of Fame
  -- The induction is a cutscene (no close button, no footer); the PC viewer is
  -- a menu: A next mon, START next team, B out -- HallOfFame:viewInput's arms.
  local HOF_GB={0,32,160,72}   -- every pic HallOfFame places lies in this band
  local function hofMonInfo(s,mon)
    local HoF=class("hof")
    local p=HoF.monPlacements(mon,s:speciesDef(mon.species))
    local at=function(x,y) return HoF.at(p,x,y) end
    return {nick=clean(at(9,14)),species=clean(at(7,13)),dex=trim(at(3,13)),
      level=trim((at(1,16) or ""):gsub("<LV>","")),id=trim(at(10,16)),gender=mon.gender}
  end
  local function drawHof(s)
    local HoF=class("hof")
    local view=s.mode=="view"
    local L=layout(1000)
    local S,c,pad,x,y,w,h=L.S,L.c,L.pad,L.x,L.y,L.w,L.h
    local reserve=0
    if view then S.closeButton(x,y,w,h,c);reserve=S.closeReserve() end
    S.text("HALL OF FAME",L.title,x+pad,y+pad,w-pad*2-reserve,"left",c.text)
    local phase=s.phase
    local player=phase=="playerBack" or phase=="playerFront" or phase=="player"
    local mon=not player and s:currentMon() or nil
    -- HallOfFame's own header line (1,2): "New Hall of Famer!", "12-Time Famer"
    if mon then
      local p=HoF.headerPlacements(s.mode,s.entry and s.entry.winCount,s.textData)
      local head=trim(HoF.at(p,2,2))..clean(HoF.at(p,1,2))
      S.text(head:upper(),L.body,x+pad,y+pad+L.title:getHeight(),w-pad*2-reserve,"left",c.accent)
    end
    local top=y+pad*2+L.title:getHeight()+L.body:getHeight()
    local fb=view and S.footerHeight() or pad
    local bottom=y+h-fb
    local t=view and taps(s) or nil
    if view then
      local bh=L.small:getHeight()+pad
      local bw=(w-pad*3)/2
      local by=bottom-pad*.6-bh
      pill(L,x+pad,by,bw,bh,"NEXT")
      cell(t,x+pad,by,bw,bh,nil,"a")
      pill(L,x+pad*2+bw,by,bw,bh,"NEXT TEAM")
      cell(t,x+pad*2+bw,by,bw,bh,nil,"start")
      bottom=by-pad*.6
    end
    -- the team strip: who has walked in so far (the whole team in the viewer)
    local mons=s.entry and s.entry.mons or {}
    local stripH=math.max(40,64*L.scale)
    local shown=view and #mons or (player and #mons or math.min(#mons,s.index or 1))
    if #mons>0 then
      local sy=bottom-stripH
      local n=math.min(6,#mons)
      local sw=math.min(stripH*1.3,(w-pad*2)/6)
      local sx=x+(w-sw*n)/2
      for i=1,n do
        local cx=sx+(i-1)*sw
        if i==s.index and not player then
          S.color(c.selected);G.rectangle("fill",cx+2,sy,sw-4,stripH,6,6)
        end
        local m=mons[i]
        if i<=shown and m then
          local img=hdArt(m.species,m)
          if not fit(img,nil,cx+sw*.1,sy+stripH*.08,sw*.8,stripH*.84) then
            S.color(c.muted,.6);G.circle("fill",cx+sw/2,sy+stripH/2,stripH*.12)
          end
        else
          S.color(c.muted,.35);G.circle("line",cx+sw/2,sy+stripH/2,stripH*.16)
        end
      end
      bottom=sy-pad*.6
    end
    -- the text block: the mon's line, or the player's card
    local infoH=L.big:getHeight()+L.body:getHeight()*2+pad*.6
    local iy=bottom-infoH
    S.color(c.divider or c.muted,.6);G.rectangle("fill",x+pad,iy-pad*.4,w-pad*2,1)
    if mon and phase=="display" then
      local info=hofMonInfo(s,mon)
      S.text(info.nick,L.big,x+pad,iy,w-pad*2,"center",c.text)
      local line=("No.%s  %s"):format(info.dex,info.species)
      local lw=L.body:getWidth(line)
      local ly=iy+L.big:getHeight()
      S.text(line,L.body,x+(w-lw)/2,ly,lw+2,"left",c.accent)
      local gs=L.body:getHeight()*.8
      genderMark(x+(w+lw)/2+gs*.8,ly+L.body:getHeight()/2,gs,info.gender)
      local lv=info.level~="" and ("Lv"..info.level.."     ") or ""
      S.text(lv.."ID No."..info.id,L.body,x+pad,ly+L.body:getHeight(),w-pad*2,"center",c.muted)
    elseif player and phase~="playerBack" then
      -- HOF_AnimatePlayerPic's card text (HallOfFame.playerPlacements)
      local p=HoF.playerPlacements(s.save)
      local at=function(px,py) return trim(HoF.at(p,px,py)) end
      S.text(clean(at(2,4)),L.big,x+pad,iy,w-pad*2,"center",c.text)
      S.text("ID No."..at(4,6),L.body,x+pad,iy+L.big:getHeight(),w-pad*2,"center",c.accent)
      S.text("PLAY TIME  "..at(3,9)..":"..at(7,9),L.body,x+pad,iy+L.big:getHeight()+L.body:getHeight(),
        w-pad*2,"center",c.muted)
    end
    -- the stage
    local stY=top+pad*.4
    local stH=iy-pad-stY
    paper(L,x+pad,stY,w-pad*2,stH)
    gbStage(x+pad,stY,w-pad*2,stH,HOF_GB[1],HOF_GB[2],HOF_GB[3],HOF_GB[4],function()
      local m=s:currentMon()
      if phase=="backpic" then
        local img,tc=s:monPic(m,true)
        s:drawScrolled(img,6,6,s:monColors(m),nil,nil,tc)
      elseif phase=="frontpic" or phase=="display" then
        local img=hdArt(m and m.species,m)
        if img then
          -- the native slide: hSCX / hSCY move the pic, both wrapped copies
          local bx,by=6*8,5*8
          for _,ox in ipairs({(bx-s.scx)%256,(bx-s.scx)%256-256}) do
            for _,oy in ipairs({(by-s.scy)%256,(by-s.scy)%256-256}) do
              fit(img,nil,ox-6,oy-8,68,64)
            end
          end
        elseif phase=="display" and s:picAnimFrame() then
          local sheet,quad,size=s:picAnimFrame()
          s:drawScrolled(sheet,6,5,s:monColors(m),quad,size,s.picAnim.trueColor)
        else
          local im,tc=s:monPic(m,false)
          s:drawScrolled(im,6,5,s:monColors(m),nil,nil,tc)
        end
      elseif phase=="playerBack" then
        s:drawScrolled(s:image(s.playerBackPath),6,6,nil)
      elseif phase=="playerFront" or phase=="player" then
        s:drawPortrait(12,5)
      end
    end)
    if view then S.footer(x,y,w,h,{colors=c,hints={{"A","NEXT"},{"START","NEXT TEAM"},{"B","BACK"}}}) end
    if t then mod._kimScreenTapTargets=t end
  end

  -- ------------------------------------------------------------ Diploma
  local CERT={"This certifies","that you have","completed the","new #DEX.","Congratulations!"}
  local function drawDiploma(s)
    local Strings=req("src.core.Strings")
    local function loc(t) if Strings then local ok,v=pcall(Strings,t); if ok and v then return v end end return t end
    local lines={}
    for i,t in ipairs(CERT) do lines[i]=clean(loc(t)) end
    local last=table.remove(lines)
    local L=layout(820,function(L)
      local r=math.max(28,54*L.scale)
      local _,wr=L.body:getWrap(table.concat(lines," "),L.w-L.pad*4)
      return L.pad*4+L.title:getHeight()+r*3.7+L.small:getHeight()+L.big:getHeight()+L.pad*1.6
        +(#wr+1.5)*L.body:getHeight()+L.S.footerHeight()
    end)
    local S,c,pad,x,y,w,h=L.S,L.c,L.pad,L.x,L.y,L.w,L.h
    S.text("DIPLOMA",L.title,x+pad,y+pad,w-pad*2,"center",c.text)
    -- a seal and ribbon in theme colours (the cart's page art is a tilemap)
    local r=math.max(28,54*L.scale)
    local cx,cy=x+w/2,y+pad*2+L.title:getHeight()+r
    S.color(c.selected);G.polygon("fill",cx-r*.55,cy,cx-r*.85,cy+r*1.55,cx-r*.35,cy+r*1.25,cx-r*.1,cy+r*.2)
    G.polygon("fill",cx+r*.55,cy,cx+r*.85,cy+r*1.55,cx+r*.35,cy+r*1.25,cx+r*.1,cy+r*.2)
    S.color(c.accent);G.circle("fill",cx,cy,r)
    S.color(c.surface);G.circle("line",cx,cy,r*.8)
    -- a five-point star, as triangles from the centre (polygon() wants convex)
    S.color(c.surface)
    local function pt(i)
      local a=-math.pi/2+i*math.pi/5
      local rr=(i%2==0) and r*.55 or r*.24
      return cx+math.cos(a)*rr,cy+math.sin(a)*rr
    end
    for i=0,9 do
      local ax,ay=pt(i);local bx2,by2=pt(i+1)
      G.polygon("fill",cx,cy,ax,ay,bx2,by2)
    end
    local ny=cy+r*1.7+pad
    S.text(clean(loc("PLAYER")),L.small,x+pad,ny,w-pad*2,"center",c.muted)
    S.text(clean(s.playerName),L.big,x+pad,ny+L.small:getHeight(),w-pad*2,"center",c.text)
    local dy=ny+L.small:getHeight()+L.big:getHeight()+pad*.6
    S.color(c.divider or c.muted,.6);G.rectangle("fill",x+w*.2,dy,w*.6,1)
    local bodyY=dy+pad
    S.text(table.concat(lines," "),L.body,x+pad*2,bodyY,w-pad*4,"center",c.text)
    local _,wrapped=L.body:getWrap(table.concat(lines," "),w-pad*4)
    S.text(last,L.body,x+pad*2,bodyY+(#wrapped+.5)*L.body:getHeight(),w-pad*4,"center",c.accent)
    S.footer(x,y,w,h,{colors=c,hints={{"A","OK"}}})
    -- WaitPressAorB: a tap anywhere is A
    local t=taps(s);cell(t,x,y,w,h,nil,"a")
    mod._kimScreenTapTargets=t
  end

  -- ------------------------------------------------------------ Egg hatch
  -- The engine's beats own everything; the stage replays EggHatchAnim's own
  -- drawPic / drawSprites (shake included), and once the hatchling shows
  -- (showMon) its KIM HD sprite stands where the pic is placed.
  local HATCH_GB={24,8,112,96}
  local function drawHatch(s)
    local L=layout(860,function(L)
      return L.pad*3+L.title:getHeight()+(L.w-L.pad*2)*HATCH_GB[4]/HATCH_GB[3]
    end)
    local S,c,pad,x,y,w,h=L.S,L.c,L.pad,L.x,L.y,L.w,L.h
    local def=s.species and s.data and s.data.pokemon and s.data.pokemon[s.species]
    local title=s.showMon and clean((s.mon and (s.mon.nickname or s.mon.name)) or (def and def.name) or s.species) or "EGG"
    S.text(title,L.title,x+pad,y+pad,w-pad*2,"center",c.text)
    local sy=y+pad*2+L.title:getHeight()
    local sh=y+h-pad-sy
    paper(L,x+pad,sy,w-pad*2,sh)
    local img=s.showMon and hdArt(s.species,s.mon) or nil
    gbStage(x+pad,sy,w-pad*2,sh,HATCH_GB[1],HATCH_GB[2],HATCH_GB[3],HATCH_GB[4],function()
      G.translate(-(s.shakeX or 0),0)
      -- the hatchling's 7x7 box at hlcoord 6, 3
      if not (img and fit(img,nil,6*8-8,3*8-8,72,64)) then s:drawPic() end
      s:drawSprites()
    end)
  end

  -- ------------------------------------------------------------ Unown printer
  local function unownArt(letter)
    if not (hdOn() and mod.exports and type(mod.exports.getGen2UnownSprite)=="function") then return nil end
    local ok,img,quad=pcall(mod.exports.getGen2UnownSprite,letter,{kind="unown_printer"})
    if not (ok and img and type(img.getDimensions)=="function") then return nil end
    if type(quad)~="userdata" or type(quad.getViewport)~="function" then quad=nil end
    return img,quad
  end
  local function drawPrinter(s)
    local L=layout(900,function(L)
      local arrowW=math.max(44,70*L.scale)
      return L.pad*3.5+L.title:getHeight()+(L.w-L.pad*4-arrowW*2)+L.big:getHeight()+L.small:getHeight()
        +L.pad+L.S.footerHeight()
    end)
    local S,c,pad,x,y,w,h=L.S,L.c,L.pad,L.x,L.y,L.w,L.h
    S.closeButton(x,y,w,h,c)
    local Strings=req("src.core.Strings")
    local title=" ALPH RUINS STAMP"
    if Strings then local ok,v=pcall(Strings,title); if ok and v then title=v end end
    S.text(trim(title),L.title,x+pad,y+pad,w-pad*2-S.closeReserve(),"left",c.text)
    local t=taps(s)
    local fb=S.footerHeight()
    local top=y+pad*2+L.title:getHeight()
    local labelH=L.big:getHeight()+L.small:getHeight()+pad
    local arrowW=math.max(44,70*L.scale)
    local size=math.min(w-pad*4-arrowW*2,y+h-fb-labelH-pad-top)
    local px,py=x+(w-size)/2,top
    paper(L,px,py,size,size)
    local letter=s:letter()
    if letter then
      local img,quad=unownArt(letter)
      if not fit(img,quad,px+size*.1,py+size*.08,size*.8,size*.8) then
        -- Crystal's own form pic (UnownPrinter:drawPic, its palette included)
        gbStage(px+size*.06,py+size*.06,size*.88,size*.88,8,48,56,56,function() s:drawPic(letter) end)
      end
    end
    -- LEFT / RIGHT, the cart's .LeftRight arms
    for i,dir in ipairs({"left","right"}) do
      local ax=i==1 and px-pad-arrowW or px+size+pad
      local ay=py+size/2-arrowW/2
      S.color(c.raised or c.surface);G.rectangle("fill",ax,ay,arrowW,arrowW,arrowW/2,arrowW/2)
      S.color(c.accent,nil,true)
      local k=arrowW*.22
      local mx,my=ax+arrowW/2,ay+arrowW/2
      if dir=="left" then G.polygon("fill",mx+k*.6,my-k,mx+k*.6,my+k,mx-k*.8,my)
      else G.polygon("fill",mx-k*.6,my-k,mx-k*.6,my+k,mx+k*.8,my) end
      cell(t,ax-pad*.5,py,arrowW+pad,size,nil,dir)
    end
    local ly=py+size+pad*.5
    local name=letter and string.char(64+letter) or "VACANT"
    if not letter and Strings then local ok,v=pcall(Strings,"VACANT"); if ok and v then name=v end end
    S.text(name,L.big,x+pad,ly,w-pad*2,"center",letter and c.text or c.muted)
    S.text(("%d / %d"):format((s.index or 0)+1,s:slots()),L.small,x+pad,ly+L.big:getHeight(),w-pad*2,"center",c.muted)
    S.footer(x,y,w,h,{colors=c,hints={{"LR","CHOOSE"},{"B","BACK"}}})
    mod._kimScreenTapTargets=t
  end

  -- ------------------------------------------------------------ Unown puzzle
  -- A tap moves UnownPuzzle's own cursor to the cell and presses A, so
  -- UnownPuzzle_A picks up / puts down (or buzzes SFX_WRONG) exactly as on the
  -- pad. A drag is the same two presses: A on the panel's cell, A on the
  -- drop cell (back to where it came from when that one is taken). Row 5's
  -- middle four cells are never cursor positions (UnownPuzzle.moveCursor);
  -- the START>CANCEL box lives there, and here it is a CANCEL button.
  local Drag=setmetatable({},{__mode="k"})
  local function reachable(cell)
    return not (cell>=31 and cell<=34)
  end
  local quads=setmetatable({},{__mode="k"})
  local function pieceQuad(img,piece)
    local q=quads[img]
    if not q then q={};quads[img]=q end
    if not q[piece] then
      local i=piece-1
      local iw,ih=img:getDimensions()
      q[piece]=G.newQuad((i%4)*24,math.floor(i/4)*24,24,24,iw,ih)
    end
    return q[piece]
  end
  local function drawPiece(L,s,piece,x,y,size,alpha)
    local GbcPalette=req("src.render.GbcPalette")
    if s.picture then
      local function body()
        G.setColor(1,1,1,alpha or 1)
        G.draw(s.picture,pieceQuad(s.picture,piece),x,y,0,size/24,size/24)
      end
      if s.palette and GbcPalette and GbcPalette.available() then GbcPalette.with(s.palette,body) else body() end
      return
    end
    -- no art in the cache: numbered panels, as the native degrade does
    local r=size*.08
    L.S.color({.77,.65,.35,1},alpha);G.rectangle("fill",x,y,size,size,r,r)
    L.S.color({.35,.24,.18,1},alpha);G.setLineWidth(math.max(1,size*.03));G.rectangle("line",x,y,size,size,r,r)
    L.S.text(tostring(piece),L.big,x,y+(size-L.big:getHeight())/2,size,"center",{.2,.13,.1,alpha or 1})
  end
  local function drawPuzzle(s)
    local L=layout(1200,function(L)
      return L.pad*3.5+L.title:getHeight()+(L.w-L.pad*2)+L.S.footerHeight()
    end)
    local S,c,pad,x,y,w,h=L.S,L.c,L.pad,L.x,L.y,L.w,L.h
    S.text("PUZZLE",L.title,x+pad,y+pad,w-pad*2,"left",c.text)
    local fb=S.footerHeight()
    local top=y+pad*2+L.title:getHeight()
    local B=math.floor(math.min(w-pad*2,y+h-fb-pad-top))
    local cs=B/6
    local bx,by=x+(w-B)/2,top
    local t=taps(s)
    local d=Drag[s]
    local gap=math.max(2,cs*.04)
    -- the 4x4 target the pieces assemble in
    S.color(c.surface,.9);G.rectangle("fill",bx+cs-gap,by+cs-gap,cs*4+gap*2,cs*4+gap*2,gap*2,gap*2)
    for cellNo=0,35 do
      local row,col=math.floor(cellNo/6),cellNo%6
      if reachable(cellNo) then
        local cx,cy=bx+col*cs+gap,by+row*cs+gap
        local sz=cs-gap*2
        local interior=row>=1 and row<=4 and col>=1 and col<=4
        S.color(interior and (c.raised or c.surface) or c.surface,interior and .55 or 1)
        G.rectangle("fill",cx,cy,sz,sz,gap*1.5,gap*1.5)
        if not interior then S.color(c.divider or c.muted,.5,true);G.setLineWidth(1);G.rectangle("line",cx,cy,sz,sz,gap*1.5,gap*1.5) end
        local piece=s.pieces[cellNo+1] or 0
        if piece~=0 and not (d and not s.holding and d.from==cellNo) then drawPiece(L,s,piece,cx,cy,sz) end
        if not s.solved then
          local extra={drop=cellNo}
          if (not s.holding and piece~=0) or (s.holding and cellNo==s.cursor) then extra.drag=cellNo end
          cell(t,bx+col*cs,by+row*cs,cs,cs,function(st) st.cursor=cellNo end,"a",extra)
        end
      end
    end
    S.color(c.accent,.8,true);G.setLineWidth(math.max(2,3*L.scale))
    G.rectangle("line",bx+cs-gap,by+cs-gap,cs*4+gap*2,cs*4+gap*2,gap*2,gap*2)
    -- START>CANCEL, in the cells the cart's box covers
    local cbx,cby,cbw,cbh=bx+cs+gap,by+cs*5+cs*.18,cs*4-gap*2,cs*.64
    if s.solved then
      S.text("COMPLETE!",L.big,cbx,cby+(cbh-L.big:getHeight())/2,cbw,"center",c.accent)
    else
      pill(L,cbx,cby,cbw,cbh,"CANCEL")
      cell(t,cbx,cby,cbw,cbh,nil,"start")
    end
    -- the cursor (and the panel riding it)
    if not s.solved then
      local col,row=s.cursor%6,math.floor(s.cursor/6)
      local cx,cy=bx+col*cs,by+row*cs
      if s.holding and s.held~=0 and not d then
        S.color({0,0,0,1},.3);G.rectangle("fill",cx+gap*2,cy+gap*3,cs-gap*2,cs-gap*2,gap*2,gap*2)
        drawPiece(L,s,s.held,cx+gap-cs*.04,cy+gap-cs*.08,cs-gap*2)
      end
      if not d then
        S.color(c.accent,nil,true);G.setLineWidth(math.max(3,4*L.scale))
        G.rectangle("line",cx+gap*.5,cy+gap*.5,cs-gap,cs-gap,gap*2,gap*2)
      end
    end
    -- the panel in the finger
    if d and d.x then
      local piece=s.holding and s.held or (s.pieces[d.from+1] or 0)
      if piece~=0 then
        local sz=cs*1.08
        S.color({0,0,0,1},.3);G.rectangle("fill",d.x-sz/2+gap*2,d.y-sz*.6+gap*3,sz,sz,gap*2,gap*2)
        drawPiece(L,s,piece,d.x-sz/2,d.y-sz*.6,sz)
      end
    end
    local hints
    if s.waiting then hints={{"A","OK"}}
    elseif s.holding then hints={{"A","PUT DOWN"},{"START","CANCEL"}}
    else hints={{"A","PICK UP"},{"START","CANCEL"}} end
    local info
    local touch=mod.exports and mod.exports.touch
    if not s.solved and type(touch)=="table" and type(touch.active)=="function" then
      local ok,on=pcall(touch.active); if ok and on==true then info="DRAG A PANEL" end
    end
    S.footer(x,y,w,h,{colors=c,hints=hints,info=info})
    if s.waiting then cell(t,x,y,w,h,nil,"a") end
    t.dragStart=function(st,from,px,py)
      if st.waiting or st.solved then return end
      if st.holding then
        if from~=st.cursor then return end
      else
        if (st.pieces[from+1] or 0)==0 then return end
        st.cursor=from;press(st,"a")
      end
      Drag[st]={from=from,x=px,y=py}
    end
    t.dragMove=function(st,_,px,py) local dd=Drag[st]; if dd then dd.x,dd.y=px,py end end
    t.dragDrop=function(st,_,to)
      local dd=Drag[st];Drag[st]=nil
      -- the pick-up press has not been read yet: nothing in hand to place
      if not (dd and st.holding) then return end
      local target=dd.from
      if to~=nil and reachable(to) and (st.pieces[to+1] or 0)==0 then target=to end
      st.cursor=target;press(st,"a")
    end
    t.dragCancel=function(st) Drag[st]=nil end
    mod._kimScreenTapTargets=t
  end

  local DRAW={hof=drawHof,diploma=drawDiploma,hatch=drawHatch,puzzle=drawPuzzle,printer=drawPrinter}
  mod.hooks:wrap("screen.render_visible",function(nextFn,state)
    if kindOf(state) and not Broken[state] and enabled() and isTop(state) then return false end
    return nextFn(state)
  end,46000)
  mod.hooks:wrap("render.hud",function(nextFn,game,viewport)
    local result=nextFn(game,viewport)
    local top=game and game.stack and game.stack:top()
    local k=kindOf(top)
    if k and not Broken[top] and enabled() then
      G.push("all");G.origin()
      local ok,err=pcall(DRAW[k],top)
      G.pop()
      if not ok then
        Broken[top]=true
        if mod.log and mod.log.warn then pcall(mod.log.warn,mod.log,"Crystal-AiO: modern %s: %s",k,tostring(err)) end
      end
    end
    return result
  end,46000)
  -- for tests
  mod._aioModernStory={kindOf=kindOf,broken=Broken,drag=Drag}
end
