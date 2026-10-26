local caps=assert(loadfile("lib/gen2_aio/gsc_caps.lua"))()
local source=assert(io.open("nuzlocke/main.lua")):read("*a")
local stages=assert(loadstring("return "..assert(source:match("gscStages = (%b{})"))))()
local count=0
local function cap(save,recorded,scope,expected,name)
  local value,label=caps.next(stages,save,recorded,scope)
  assert(value==expected and label==name,tostring(value).."/"..tostring(label).." expected "..expected.."/"..name)
  count=count+1
end
local save={player={badges={},kantoBadges={}}}
cap(save,{},1,9,"FALKNER")
-- Load an existing game whose Nuzlocke battle-event record is empty.
save.player.badges.ZEPHYR=true
cap(save,{},1,16,"BUGSY")
save.player.badges.HIVE=true
cap(save,{},1,20,"WHITNEY")
-- A stale mod record cannot award badges absent from the loaded game.
cap({player={badges={}}},{FALKNER=true,BUGSY=true},1,9,"FALKNER")
-- Numeric badge slots use ROM bit order, not the order of gym challenges.
save.player.badges={[1]=true,[2]=true,[3]=true,[4]=true,[5]=true}
cap(save,{},1,35,"CHUCK")
save.player.badges[6]=true
cap(save,{},1,35,"PRYCE")
save.player.badges[7]=true;save.player.badges[8]=true
cap(save,{},1,100,"MAX")
cap(save,{},2,42,"WILL")
local league={WILL=true,KOGA=true,BRUNO=true,KAREN=true}
cap(save,league,3,50,"LANCE")
league.LANCE=true
save.player.kantoBadges.THUNDER=true
cap(save,league,4,50,"SABRINA")
save.player.kantoBadges={BOULDER=true,CASCADE=true,THUNDER=true,RAINBOW=true,SOUL=true,MARSH=true,VOLCANO=true,EARTH=true}
cap(save,league,4,81,"RED")
save.hallOfFame={count=1}
cap(save,{},4,81,"RED")
-- A legacy engine without badge stores retains event progression.
cap({player={}},{FALKNER=true},1,16,"BUGSY")
print("GSC cap progression: "..count.." checks PASS")
