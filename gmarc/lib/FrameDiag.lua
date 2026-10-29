-- gen2-aio 0.9.78: DIAGNOSTICS `voxel frame` -- where a slow area's frame
-- goes, readable off a phone screen.
--
-- Wraps the voxel pipeline's update and drawWorld with a wall-clock span
-- each and, once a second, reports the averages and peaks of both, the GPU
-- work the last frame submitted (love.graphics.getStats: draw calls, shader
-- and canvas switches, texture memory), how many characters the world is
-- running, and how many mesh rebuilds the last second asked for -- a map
-- whose blocks keep being rewritten rebuilds forever, which reads exactly
-- like "slow even after a while". Costs two clock reads a frame when
-- DIAGNOSTICS is off (the report itself is skipped).
local V = ...
local FrameDiag = {}

local clock = love and love.timer and love.timer.getTime or os.clock
local acc = { upd = 0, updMax = 0, draw = 0, drawMax = 0, n = 0 }
local lastReport = 0

local function diagOn()
  local mod = V and V.mod
  local fn = mod and rawget(mod, "_kimArenaDiagOn")
  if type(fn) ~= "function" then return false end
  local ok, on = pcall(fn)
  return ok and on == true
end

local function characters()
  local okG, Game = pcall(require, "src.core.Game")
  local w = okG and Game and (Game.world or Game.overworld)
  if type(w) ~= "table" then return 0 end
  local n = 0
  for _, list in ipairs({ w.npcs, w.npcPool, w.objects }) do
    if type(list) == "table" then
      for _ in pairs(list) do n = n + 1 end
      if n > 0 then break end
    end
  end
  return n
end

local function report()
  local now = clock()
  if now - lastReport < 1 then return end
  local n = math.max(1, acc.n)
  lastReport = now
  if diagOn() then
    local d = V.mod and rawget(V.mod, "_kimArenaDiag")
    if d then
      local okS, st = pcall(love.graphics.getStats)
      st = okS and type(st) == "table" and st or {}
      local CM = V.require("ChunkMesher")
      local cs = type(CM.stats) == "table" and CM.stats or {}
      pcall(d, "voxel frame", ("upd %.1f/%.1f ms, draw %.1f/%.1f ms; %s calls, %s shader, %s canvas, %d MB tex"):format(
        acc.upd / n * 1000, acc.updMax * 1000, acc.draw / n * 1000, acc.drawMax * 1000,
        tostring(st.drawcalls or "?"), tostring(st.shaderswitches or "?"), tostring(st.canvasswitches or "?"),
        math.floor((st.texturememory or 0) / 1048576)))
      pcall(d, "voxel churn", ("%d chars; %d rebuilds/s (last %s), %d builds total (%d disk), %d pending"):format(
        characters(), cs.refreshSec or 0, tostring(cs.lastRefresh or "-"), cs.builds or 0, cs.restores or 0,
        CM.pending()))
    end
  end
  local CM = V.require("ChunkMesher")
  if type(CM.stats) == "table" then CM.stats.refreshSec = 0 end
  acc.upd, acc.updMax, acc.draw, acc.drawMax, acc.n = 0, 0, 0, 0, 0
end

-- the pipeline record with its update / drawWorld timed
function FrameDiag.wrap(record)
  local update, drawWorld = record.update, record.drawWorld
  if update then
    record.update = function(...)
      local t0 = clock()
      local r = { update(...) }
      local dt = clock() - t0
      acc.upd = acc.upd + dt
      if dt > acc.updMax then acc.updMax = dt end
      return unpack(r)
    end
  end
  if drawWorld then
    record.drawWorld = function(...)
      local t0 = clock()
      local r = { drawWorld(...) }
      local dt = clock() - t0
      acc.draw = acc.draw + dt
      if dt > acc.drawMax then acc.drawMax = dt end
      acc.n = acc.n + 1
      pcall(report)
      return unpack(r)
    end
  end
  return record
end

return FrameDiag
