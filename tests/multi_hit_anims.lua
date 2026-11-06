local Battle = {}
Battle.__index = Battle
function Battle:emit(e) self.events[#self.events+1] = e; return e end
function Battle:sideOf(m) return m.side end
function Battle:hitOnce(a, d, def) return self:emit({ kind = "damage", side = d.side }) end
package.loaded["src.battle.gen2.Battle"] = Battle
local f = dofile("lib/crystal_aio/multi_hit_anims.lua")
print("install", f({ diag = function() end }), f({}))  -- second install must not re-wrap
local b = setmetatable({ events = {} }, Battle)
local me, foe = { side = "player" }, { side = "enemy" }
local function use(move, hits)
  b.moveEvent = b:emit({ kind = "move", move = move, side = "player", afterAnim = "damage", effectiveness = 20 })
  for _ = 1, hits do b:hitOnce(me, foe, {}) end
end
use("BARRAGE", 3); use("TACKLE", 1)
for i, e in ipairs(b.events) do print(i, e.kind, e.move or e.moveAnim or "", e.afterAnim or "", e.effectiveness or "") end
