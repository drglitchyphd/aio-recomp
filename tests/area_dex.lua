local engine=os.getenv("AIO_ENGINE") or ".work/engine"
package.path=engine.."/?.lua;"..package.path
local mod={exports={},hooks={wrap=function()end},events={on=function()end}}
local quick=assert(loadfile("lib/gen2_aio/quick_menu.lua"))()({mod=mod})
local game={save={version="crystal"},world={map={id="TEST"},encounters={
  trees={TEST="TREEMON_SET_CITY"},rocks={TEST="TREEMON_SET_ROCK"},treeSets={
    TREEMON_SET_CITY={common={{species="SPEAROW",level=10,chance=50},{species="SPEAROW",level=15,chance=50}},
      rare={{species="HERACROSS",level=10,chance=100}}},
    TREEMON_SET_ROCK={common={{species="KRABBY",level=15,chance=90},{species="SHUCKLE",level=15,chance=10}},
      rare={{species="MEWTWO",level=100,chance=100}}},
  }}}}
local s=quick.areaSections(game)
assert(#s==3)
assert(s[1].mons[1].pct==100 and s[1].mons[1].lo==10 and s[1].mons[1].hi==15)
assert(s[2].mons[1].species=="HERACROSS")
assert(#s[3].mons==2 and s[3].mons[2].species=="SHUCKLE" and s[3].mons[2].pct==10)
game.save.version="gold"
s=quick.areaSections(game)
assert(#s==1 and s[1].title=="ROCK SMASH","GS dead tree sets must be excluded")
game.world.map.id="NO_ENCOUNTERS"
assert(#quick.areaSections(game)==0)
print("Area Dex: Crystal/Gold tree eligibility, aggregation, rock common list, empty map PASS")
