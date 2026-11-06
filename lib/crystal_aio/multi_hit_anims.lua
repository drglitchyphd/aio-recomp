-- gen2-aio 0.9.54: MULTI-HIT ANIMATIONS, at the engine seam.
--
-- On the cart a multi-hit move (Barrage, Double Kick, Fury Attack, Twineedle,
-- Triple Kick, Beat Up...) loops back through BattleCommand_MoveAnim for every
-- hit (effect_commands.asm EndLoop), so the animation plays once per hit.
-- Gen1Recomp 0.3.95 animates only the "used X!" move event; its hit loop
-- (battle/gen2/Battle.lua useMove) emits damage events alone, so every hit
-- after the first just shakes the HP bar.
--
-- Battle:hitOnce runs once per hit inside that loop. A second call against the
-- same move event is a later hit of the same use, so it first queues a
-- text-less message carrying moveAnim -- the shape the engine already uses to
-- replay Magnitude's animation after its number line -- and the screen plays
-- the move's animation (and its damage after-anim) before that hit's damage.
return function(host)
  local diag = host.diag or function() end
  local ok, Battle = pcall(require, "src.battle.gen2.Battle")
  if not (ok and type(Battle) == "table" and type(Battle.hitOnce) == "function") then
    return nil
  end
  -- Engine modules outlive a session (Android relaunches in the same Lua
  -- state): wrap once per process.
  if Battle._aioMultiHitAnims then return true end
  Battle._aioMultiHitAnims = true

  local replays = 0
  local vanillaHitOnce = Battle.hitOnce
  Battle.hitOnce = function(self, attacker, defender, def, opts)
    local ev = self.moveEvent
    if type(ev) == "table" then
      if self._aioHitOwner == ev then
        local animId = ev.move or ev.moveAnim
        if animId and type(self.emit) == "function" then
          local side = type(self.sideOf) == "function" and self:sideOf(attacker) or ev.side
          self:emit({ kind = "message", moveAnim = animId, side = side,
            afterAnim = ev.afterAnim, effectiveness = ev.effectiveness })
          replays = replays + 1
          diag("multi-hit", ("%d extra hit animations"):format(replays))
        end
      else
        self._aioHitOwner = ev
      end
    end
    return vanillaHitOnce(self, attacker, defender, def, opts)
  end
  return true
end
