local View,BS={},{}
local native,drawn=0,nil
View.drawObjects=function(self,runner) native=#runner:oam() end
BS.startBallAnim=function()end
package.preload["src.ui.gen2.BattleAnimView"]=function()return View end
package.preload["src.ui.gen2.BattleState"]=function()return BS end
local G={}
local tx,ty=1,1
local image={setFilter=function()end,getDimensions=function()return 30,30 end}
G.newImage=function()return image end
G.newQuad=function()return {} end
G.transformPoint=function(x,y)return x*tx,y*ty end
G.draw=function(img,q,x,y,r,sx,sy)drawn={sx,sy}end
G.setShader=function()end;G.setColor=function()end
love={graphics=G,filesystem={newFileData=function()end},image={newImageData=function()end}}
local factory=assert(loadfile("lib/gen2_aio/hd_ball.lua"))()
local enabled=true
local mod={read=function()return "image"end,options={get=function()return enabled end}}
factory({mod=mod})
local runner={loaded={{gfx="ANIM_GFX_POKE_BALL",tile=0,tiles=4}},
  oam=function()return {{tile=0,x=20,y=30},{tile=9,x=5,y=5}}end}
for _,dims in ipairs({{1,1},{2,5},{5,2}})do
  tx,ty=unpack(dims);drawn=nil
  View:drawObjects(runner,{})
  assert(native==1 and drawn)
  assert(math.abs(drawn[1]*tx-drawn[2]*ty)<1e-9,"ball must stay square")
  assert(math.abs(drawn[1]*tx*18-8*math.min(tx,ty))<1e-9,"ball must not round up to 18px")
end
drawn=nil;runner._aioCaptureBall=true
View:drawObjects(runner,{})
assert(not drawn and runner._aioHdBall and runner._aioHdBall.size==8)
runner._aioCaptureBall=nil
factory({mod={options={get=function()return false end}}})
View:drawObjects(runner,{})
assert(native==2 and not runner._aioHdBall,"relaunch OFF uses native sprites")
print("HD ball: size, aspect, 3D capture and relaunch option PASS")
