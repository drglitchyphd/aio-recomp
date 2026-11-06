-- gen2-aio: locked KENNEY HD battle camera.
--
-- With BATTLE BACKGROUND = KENNEY HD and BATTLE CAMERA = LOCKED, gmarc's battle
-- rig is replaced by a solved camera: the player's feet land where KIM HD's
-- paintings put them (about 33% across, 74% down) and the foe's at about
-- 73% / 51%, from an angle chosen per Kenney scene type (low and close in
-- caves, higher over water and towns). The Kenney scene is still rendered live
-- through this same camera, so the cards stand on its real ground.
--
-- Unknowns: focus x/z, yaw, distance. Pitch and field of view come from the
-- scene type. Four equations (two projected points), solved by Gauss-Newton
-- from a behind-the-player guess; anything that does not converge falls back
-- to gmarc's own rig.
local M = {}

-- pitch (degrees below horizontal), vertical fov (degrees)
M.PRESETS = {
  grass = { 16, 38 }, town = { 20, 40 }, freshwater = { 22, 42 }, ocean = { 24, 42 },
  cave = { 12, 36 }, cave_water = { 13, 36 }, ice_cave = { 13, 36 },
  mountain = { 18, 40 }, interior = { 20, 40 }, industrial = { 19, 40 },
  ruins = { 17, 38 }, ship = { 21, 40 }, gym = { 20, 40 }, league = { 20, 40 },
  indoor_water = { 20, 40 },
}
M.DEFAULT = { 18, 40 }
-- 0.9.5: your Pokemon sits further left (24% across) so the two are not
-- bunched toward the middle on narrow and near-square screens.
M.TARGET = { player = { 0.20, 704 / 950 }, enemy = { 1400 / 1920, 484 / 950 } }
-- 0.9.6: the lens is solved too, so your Pokemon reads this many times the
-- foe's size (depth ratio) instead of whatever a fixed field of view gave --
-- a wide lens close behind your Pokemon made it fill half the screen.
M.SIZE_RATIO = 1.5
M.FOV_MIN, M.FOV_MAX = math.rad(14), math.rad(60)

local rad = math.rad
local function sub(a, b) return { a[1] - b[1], a[2] - b[2], a[3] - b[3] } end
local function cross(a, b) return { a[2]*b[3]-a[3]*b[2], a[3]*b[1]-a[1]*b[3], a[1]*b[2]-a[2]*b[1] } end
local function dot(a, b) return a[1]*b[1] + a[2]*b[2] + a[3]*b[3] end
local function norm(a) local l = math.sqrt(dot(a, a)); return { a[1]/l, a[2]/l, a[3]/l } end

-- screen fraction (x right, y down) of world point p for the camera
local function project(eye, focus, fovY, aspect, p)
  local f = norm(sub(focus, eye))
  local r = norm(cross(f, { 0, 1, 0 }))
  local u = cross(r, f)
  local v = sub(p, eye)
  local z = dot(v, f)
  if z <= 1e-6 then return nil end
  local t = math.tan(fovY / 2)
  local nx = dot(v, r) / (z * t * aspect)
  local ny = dot(v, u) / (z * t)
  return (nx + 1) / 2, (1 - ny) / 2
end
M.project = project

local function camera(params, groundY, pitch, fovY, lookY)
  local fx, fz, yaw, dist = params[1], params[2], params[3], params[4]
  fovY = params[5] or fovY
  local focus = { fx, groundY + lookY, fz }
  local cp, sp = math.cos(pitch), math.sin(pitch)
  local eye = { fx - math.sin(yaw) * cp * dist, focus[2] + sp * dist, fz - math.cos(yaw) * cp * dist }
  return eye, focus
end

-- player, enemy: { x, z } on the arena floor. aspect: width / height.
-- fieldBottom: fraction of the screen height the battle field uses (tall
-- layouts keep the lower third for the battle panel).
-- targets (optional): { player = {x, y}, enemy = {x, y} } screen fractions,
-- overriding the KIM HD spots (the host derives them from where the HUD is).
function M.solve(player, enemy, groundY, aspect, sceneId, fieldBottom, targets)
  local pre = M.PRESETS[sceneId or ""] or M.DEFAULT
  local pitch, fovY = rad(pre[1]), rad(pre[2])
  -- At Fold cover-screen aspect the 1.5 depth ratio puts the eye behind
  -- the clearing, inside foreground trees (reproduced with the real grass
  -- scene). A 2:1 ratio brings it inside the clearing; the wider vertical
  -- lens also lets higher-pitch water/town shots keep both foot targets.
  local narrow = aspect < 1 / 1.9
  local sizeRatio = narrow and 2 or M.SIZE_RATIO
  local fovMax = narrow and rad(85) or M.FOV_MAX
  fieldBottom = fieldBottom or 1
  local tp = { M.TARGET.player[1], M.TARGET.player[2] * fieldBottom }
  local te = { M.TARGET.enemy[1], M.TARGET.enemy[2] * fieldBottom }
  if targets and targets.player and targets.enemy then
    tp, te = targets.player, targets.enemy
  end
  local P = { player[1], groundY, player[2] }
  local E = { enemy[1], groundY, enemy[2] }
  local dx, dz = E[1] - P[1], E[3] - P[3]
  local span = math.sqrt(dx * dx + dz * dz)
  if span < 1e-3 then return nil end
  local lookY = span * 0.12
  -- guess: looking from behind the player toward the foe, a little to the left
  local yaw0 = math.atan2(dx, dz) + rad(14)
  local x = { (P[1] + E[1]) / 2, (P[3] + E[3]) / 2, yaw0, span * 1.9, fovY }
  local N = 5
  local function depth(eye, focus, p)
    local f = norm(sub(focus, eye))
    return dot(sub(p, eye), f)
  end
  local function residual(q)
    if q[5] < M.FOV_MIN * 0.5 or q[5] > fovMax * 1.5 then return nil end
    local eye, focus = camera(q, groundY, pitch, q[5], lookY)
    local ax, ay = project(eye, focus, q[5], aspect, P)
    local bx, by = project(eye, focus, q[5], aspect, E)
    if not (ax and bx) then return nil end
    local dp, de = depth(eye, focus, P), depth(eye, focus, E)
    if dp <= 0 or de <= 0 then return nil end
    return { ax - tp[1], ay - tp[2], bx - te[1], by - te[2], (de / dp - sizeRatio) * 0.2 }
  end
  for _ = 1, 40 do
    local r = residual(x)
    if not r then return nil end
    local err = 0
    for i = 1, N do err = err + math.abs(r[i]) end
    if err < 1e-6 then break end
    -- numeric Jacobian (5x5), damped solve J dx = -r
    local J = {}
    local steps = { span * 1e-4, span * 1e-4, 1e-5, span * 1e-4, 1e-5 }
    for j = 1, N do
      local q = { x[1], x[2], x[3], x[4], x[5] }
      q[j] = q[j] + steps[j]
      local rq = residual(q)
      if not rq then return nil end
      for i = 1, N do J[i] = J[i] or {}; J[i][j] = (rq[i] - r[i]) / steps[j] end
    end
    local A = {}
    for i = 1, N do
      A[i] = {}
      for j = 1, N do A[i][j] = J[i][j] end
      A[i][N + 1] = -r[i]
    end
    for c = 1, N do
      local best = c
      for i = c + 1, N do if math.abs(A[i][c]) > math.abs(A[best][c]) then best = i end end
      A[c], A[best] = A[best], A[c]
      if math.abs(A[c][c]) < 1e-12 then return nil end
      for i = c + 1, N do
        local k = A[i][c] / A[c][c]
        for j = c, N + 1 do A[i][j] = A[i][j] - k * A[c][j] end
      end
    end
    local d = {}
    for i = N, 1, -1 do
      local sacc = A[i][N + 1]
      for j = i + 1, N do sacc = sacc - A[i][j] * d[j] end
      d[i] = sacc / A[i][i]
    end
    for i = 1, N do x[i] = x[i] + d[i] * 0.7 end
    if x[4] < span * 0.3 then x[4] = span * 0.3 end
    x[5] = math.max(M.FOV_MIN, math.min(fovMax, x[5]))
  end
  local r = residual(x)
  if not r then return nil end
  if math.abs(r[1]) + math.abs(r[2]) + math.abs(r[3]) + math.abs(r[4]) > 0.01 then return nil end
  fovY = x[5]
  local eye, focus = camera(x, groundY, pitch, fovY, lookY)
  -- `screenFov` is the full-screen vertical field of view, so BattleScene
  -- must not widen it from the GB frame the way it does gmarc's own rig.
  -- The second value is gmarc's pitch convention: the angle of the view from
  -- straight down (its terrain pull reads it), not from the horizon.
  return { eye = eye, focus = focus, fov = fovY, screenFov = fovY, curve = 0 },
    math.pi / 2 - pitch
end

return M
