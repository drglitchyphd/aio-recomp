-- gen2-aio 0.9.76: stopping an evolution that does not race past you.
--
-- Crystal stops an evolution only for a B pressed during the short waits
-- between the flashes (.WaitFrames_CheckPressedB). At 2x speed those windows
-- are a few frames each, and with KIM Touch the floating B sits under the
-- Modern evolution window, so in practice an evolution could not be stopped.
--
-- Here a stop request is remembered: a B press at any moment of the
-- animation (the text, the cry, the flashes), or a tap on the window's STOP
-- EVOLUTION button (gen2_modern_core_menus drawGen2Evolution), sets
-- `_aioStop` on the state, and the cart's own check honours it at its next
-- wait. Stone evolutions (wForceEvolution) still cannot be stopped.
return function(host)
  local ok, Evo = pcall(require, "src.ui.gen2.EvolutionAnim")
  if not (ok and type(Evo) == "table" and type(Evo.cancelPressed) == "function"
      and type(Evo.update) == "function") then
    return nil
  end
  -- engine modules outlive a session (Android relaunches in the same Lua
  -- state): wrap once per process
  if rawget(Evo, "_aioStopLatch") then return true end
  rawset(Evo, "_aioStopLatch", true)

  local STOPPABLE = { evolving = true, cry = true, flash = true }

  local origCancel = Evo.cancelPressed
  Evo.cancelPressed = function(self, input)
    if self.force then return false end
    if origCancel(self, input) then return true end
    return rawget(self, "_aioStop") == true
  end

  local origUpdate = Evo.update
  Evo.update = function(self, ...)
    local input = self.game and self.game.input
    if not self.force and STOPPABLE[self.phase] and input
        and type(input.wasPressed) == "function" and input:wasPressed("b") then
      self._aioStop = true
    end
    return origUpdate(self, ...)
  end
  return true
end
