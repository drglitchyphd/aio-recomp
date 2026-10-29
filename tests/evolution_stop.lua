-- 0.9.76: STOP EVOLUTION (lib/gen2_aio/evolution_stop.lua) on the engine's
-- real EvolutionAnim: a B press or a STOP tap at any moment of the animation
-- stops it at the cart's next wait; a stone evolution cannot be stopped.
-- Run from the repo root with AIO_ENGINE=<engine>/src (skips without it):
--   luajit tests/evolution_stop.lua
local engine = os.getenv("AIO_ENGINE")
if not engine then print("evolution stop: SKIP (set AIO_ENGINE to the engine's src root)") return end
love = { graphics = setmetatable({}, { __index = function() return function() end end }),
  timer = { getTime = function() return 0 end }, audio = setmetatable({}, { __index = function() return function() end end }) }
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path
local Evo = require("src.ui.gen2.EvolutionAnim")
local n = 0
local function check(c, m) if not c then error("FAIL: " .. m, 2) end n = n + 1 end
assert(loadfile("lib/gen2_aio/evolution_stop.lua"))()({ mod = {} })

local pressed = {}
local input = { wasPressed = function(_, b) return pressed[b] == true end, isDown = function() return false end }
local function run(force, pressAt, viaTap)
  local game = { input = input, data = { pokemon = {} }, stack = { states = {} } }
  function game.stack:top() return self.states[#self.states] end
  function game.stack:pop() self.states[#self.states] = nil end
  local result
  local s = Evo.new(game, { mon = { species = "CHIKORITA", nickname = "LEAF" },
    entry = { into = "BAYLEEF" }, force = force, onDone = function(r) result = r end })
  game.stack.states[1] = s
  for frame = 1, 4000 do
    pressed = {}
    if frame == pressAt then
      if viaTap then s._aioStop = true else pressed.b = true end
    end
    local ok, err = pcall(s.update, s, 1 / 60)
    if not ok then error("update " .. tostring(err)) end
    if result then return result, frame end
  end
  return result
end

-- a B press during the opening text (the cart ignores it there; the wait
-- check then runs at the first flash round)
local r = run(false, 5)
check(r and r.canceled == true, "B during the opening text stops the evolution")
-- a B press on a frame the cart is not listening (mid-flash) is remembered
local r2 = run(false, 1, false)
check(r2 and r2.canceled, "B on the very first frame is remembered")
-- the STOP EVOLUTION button
local r3 = run(false, 3, true)
check(r3 and r3.canceled, "STOP EVOLUTION tap stops it")
-- nothing pressed: it evolves
local r4 = run(false, nil)
check(r4 and not r4.canceled, "no stop: it evolves")
-- a stone evolution cannot be stopped
local r5 = run(true, 5)
check(r5 and not r5.canceled, "stone evolution ignores B")
local r6 = run(true, 3, true)
check(r6 and not r6.canceled, "stone evolution ignores STOP")
print(("evolution stop: %d checks PASS"):format(n))
