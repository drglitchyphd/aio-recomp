io.stdout:setvbuf("no")
function love.errorhandler(msg) io.stderr:write(tostring(msg).."\n"..debug.traceback().."\n"); return function() return 1 end end
local root=love.filesystem.getSource():gsub('/tests/kenney_portrait/?$', '') .. '/'
local prefix='mods.gen2-aio.stadium2.lib.'
function love.load()
 table.insert(package.loaders,1,function(name)
  local base='mods.gen2-aio.'; if name:sub(1,#base)==base then return assert(loadfile(root..name:sub(#base+1):gsub('%.','/')..'.lua')) end
 end)
 package.preload['src.mods.Runtime']=function() return {call=function(_,fallback,ctx) return fallback(ctx) end} end
 local options={stadium2_shader='stadium',stadium2_scene_resolution=50,stadium2_fx_particles=false,stadium2_visitors='off',stadium2_weather='off',stadium2_camera='free',arenaBackground='kenney'}
 local events={}
 local mod={options={get=function(_,k) return options[k] end},events={on=function(_,n,f) events[n]=f end},hooks={wrap=function() end}}
 function mod:read(path) local f=assert(io.open(root..'stadium2/'..path,'rb')); local s=f:read('*a');f:close();return s end
 for _,name in ipairs({'importer','battle_aa','battle_nature','battle_cave','battle_freshwater','battle_town','battle_ocean','scene_kit'}) do local m=require(prefix..name); if m.bind then m.bind(mod) end end
 local B=assert(loadfile(root..'lib/gen2_aio/backdrop.lua'))()({mod=mod,load=function(p) return assert(loadfile(root..p))() end})
 local K=assert(loadfile(root..'lib/gen2_aio/kenney_camera.lua'))()

 local checks=0
 local function check(v,msg) assert(v,msg); checks=checks+1 end
 local scenes={'grass','town','cave','freshwater','ocean','mountain','ice_cave','interior','industrial','ruins','ship','gym','league','cave_water','indoor_water'}
 local thumbs={}
 local function render(id,W,H,dpi)
  love.graphics.getDimensions=function() return W/dpi,H/dpi end
  love.graphics.getPixelDimensions=function() return W,H end
  check(B.mode()=='kenney','portrait must retain KENNEY HD')
  events['map.entered']({mapId='TEST_'..id:upper(),map={id='TEST_'..id:upper(),def={environment=id:upper()}}})
  events['battle.started']({kind='wild'})
  local p=assert(B.plate(),'no plate for '..id)
  check(p.sceneId==id,'correct real scene: '..id)
  local bottom=H>W*1.9 and .67 or 1
  local cam=assert(K.solve({0,48},{0,0},0,W/H,id,bottom),'camera solve: '..id)
  local ax,ay=K.project(cam.eye,cam.focus,cam.fov,W/H,{0,0,48})
  local bx,by=K.project(cam.eye,cam.focus,cam.fov,W/H,{0,0,0})
  check(math.abs(ax-K.TARGET.player[1])<.005 and math.abs(ay-K.TARGET.player[2]*bottom)<.005,'player projection')
  check(math.abs(bx-K.TARGET.enemy[1])<.005 and math.abs(by-K.TARGET.enemy[2]*bottom)<.005,'enemy projection')
  if id=='grass' and H>W*1.9 then check(cam.eye[3]-24<100,'eye stays inside foreground tree ring') end
  local G=love.graphics
  G.setScissor(2,3,4,5);G.translate(17,29);G.setColor(.2,.3,.4,.5)
  local canvas=p.render({player={0,0,48},enemy={0,0,0},eye=cam.eye,focus=cam.focus,fov=cam.fov,width=W,height=H})
  assert(canvas,p.scene.defect or 'render failed: '..id)
  local sx,sy,sw,sh=G.getScissor();local tx,ty=G.transformPoint(0,0);local r,g,b,a=G.getColor()
  check(sx==2 and sy==3 and sw==4 and sh==5 and tx==17 and ty==29 and math.abs(a-.5)<.001,'caller graphics state restored')
  G.origin();G.setScissor();G.setColor(1,1,1,1)
  local cw,ch=canvas:getDimensions()
  check(cw==W and ch==H,'DPI output dimensions')
  local data=canvas:newImageData()
  local lo,hi=math.huge,-math.huge
  for x=0,cw-1,math.max(1,math.floor(cw/12)) do for y=0,ch-1,math.max(1,math.floor(ch/12)) do
   local cr,cg,cb,ca=data:getPixel(x,y);lo=math.min(lo,cr+cg+cb);hi=math.max(hi,cr+cg+cb)
   check(ca>.99,'opaque frame')
  end end
  check(hi-lo>.1,'scene contains visible geometry/lighting')
  local png=data:encode('png');local f=assert(io.open('/tmp/kenney-'..id..'-'..W..'x'..H..'-dpi'..dpi..'.png','wb'));f:write(png:getString());f:close()
  if W==270 then thumbs[#thumbs+1]={image=G.newImage(data),label=id} end
  print('PASS '..id..' '..W..'x'..H..' DPI '..dpi)
  return p
 end
 for _,id in ipairs(scenes) do render(id,270,630,1) end
 render('grass',1080,2520,3)
 render('grass',2184,1968,2)
 render('grass',1280,720,1)
 -- A scene error must restore caller state and enter the existing fallback.
 local p=render('grass',270,630,1)
 p.scene.render=function() error('injected GPU error') end
 check(p.render({player={0,0,48},enemy={0,0,0},eye={0,20,70},focus={0,0,0},fov=.6,width=270,height=630})==nil and p.broken,'render error marks plan broken')
 mod._kimAssetProvider={image=function() return love.graphics.newCanvas(16,16) end}
 check(B.plate().kind=='kim','broken scene falls back to KIM HD')
 B.release()
 local G=love.graphics
 local sheet=G.newCanvas(900,1125);G.setCanvas(sheet);G.clear(.04,.05,.07,1);G.origin();G.setScissor()
 local f=G.newFont(14);G.setFont(f)
 for i=1,15 do local t=thumbs[i];local x=((i-1)%5)*180;local y=math.floor((i-1)/5)*375
  G.setColor(1,1,1,1);G.draw(t.image,x,y,0,180/270,350/630);G.print(t.label,x+6,y+353)
 end
 G.setCanvas();local png=sheet:newImageData():encode('png');local out=assert(io.open('/tmp/kenney-portrait-scenes.png','wb'));out:write(png:getString());out:close()
 print('Kenney portrait: '..checks..' checks PASS; 15 scene types, Fold cover/inner, desktop, DPI and failure recovery')
 love.event.quit(0)
end
