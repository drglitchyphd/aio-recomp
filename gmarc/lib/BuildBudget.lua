-- Voxel world mode: the cooperative build budget.
--
-- Mesh building runs inside a plain coroutine that ChunkMesher pumps for
-- a few milliseconds a frame (there is no worker thread: LOVE's graphics
-- objects are main-thread only, and the build is pure Lua that slices
-- cleanly). The long loops in Structures and ChunkMesher call tick() as
-- they go; when the frame's slice is spent, tick() suspends the build
-- coroutine and the frame carries on rendering whatever is already
-- cached.
--
-- tick() is deliberately safe to call from ANY context: outside the pump
-- (headless tests, the pure geometry API, a driver poking a build
-- function directly) it recognises it is not inside the build coroutine
-- and does nothing, so synchronous callers keep their synchronous
-- behavior.

local B = { n = 0 }

local clock = (love and love.timer and love.timer.getTime) or os.clock

local deadline = math.huge
local buildCo = nil

-- Enter/leave a pumped slice. `co` is the coroutine being resumed, so
-- tick() can tell the build apart from any other coroutine the engine
-- happens to be running (drivers are coroutines too).
function B.begin(co, seconds)
  buildCo = co
  deadline = clock() + seconds
end

function B.finish()
  buildCo = nil
  deadline = math.huge
end

function B.expired()
  return clock() > deadline
end

-- Cheap enough to sprinkle through inner loops: one modulo most calls,
-- a clock read every 4th. gen2-aio 0.9.79: was every 32nd, and in a dense
-- forest one map cell (a carved tree hull) costs milliseconds, so 32 of
-- them between looks overran a 4 ms slice by 130 ms (Ilex Forest).
function B.tick()
  local n = B.n + 1
  B.n = n
  if n % 4 ~= 0 then return end
  if buildCo and coroutine.running() == buildCo and clock() > deadline then
    coroutine.yield("budget")
  end
end

-- Like tick() but consults the clock every call -- for coarse loops
-- whose single iteration already costs milliseconds (mesh upload
-- slices), where tick()'s 1-in-32 sampling would never fire.
function B.check()
  if buildCo and coroutine.running() == buildCo and clock() > deadline then
    coroutine.yield("budget")
  end
end

return B
