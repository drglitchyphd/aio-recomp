-- gen2-aio battle background provider.
--
-- Battle Art's 3D battle stage (bundled under voxel/) is the compositor on
-- Crystal: it owns the camera, KIM's HD Pokemon cards and the battle UI. Its
-- ARENA FILL "PNG" plate is pinned by the host while a picture background is
-- selected, and voxel/lib/BattleScene.lua asks this module for that plate:
--
--   KIM HD      a flat 1920x950 Kanto in Motion background, cover-fitted
--   KENNEY HD   the Stadium 2 Importer's painted Kenney scene for the place
--   STADIUM 2   a Stadium 2 arena decoded from the imported ROM
--
-- The two 3D choices are rendered every frame through Battle Art's own
-- camera: the Stadium scene is mapped onto Battle Art's world with the
-- similarity transform that puts Stadium's player/enemy slots exactly on
-- Battle Art's arena slots, so the cards stand on the scene's real ground.
--
-- Fallbacks never leave a broken battle: STADIUM 2 without the ROM (or with
-- a field that fails to decode) uses KENNEY HD; a place Kenney has no scene
-- for uses KIM HD; KIM HD art that has not been downloaded yet shows the
-- voxel world.

local SROOT = "mods.gen2-aio.stadium2.lib."

return function(host)
  local mod = host.mod
  local B = {}

  local function warn(fmt, ...)
    if mod.log and mod.log.warn then pcall(mod.log.warn, mod.log, fmt, ...) end
    -- gen2-aio: also on screen with DIAGNOSTICS on
    local d = rawget(mod, "_kimArenaDiag")
    if type(d) == "function" then
      local okF, text = pcall(string.format, fmt, ...)
      pcall(d, "battle bg", okF and text or tostring(fmt))
    end
  end

  -- ------------------------------------------------------------ settings
  local function opt(key, default)
    local ok, value = pcall(mod.options.get, mod.options, key)
    if ok and value ~= nil then return value end
    return default
  end

  local MODES = { white=true, kim_hd=true, kenney=true, voxel=true }

  -- The background the player asked for, honoring BATTLE SPRITES: with
  -- KIM's sprites off every battle is the plain native one.
  function B.mode()
    if opt("battleSprites", true) == false then return "white" end
    local mode = opt("arenaBackground", "kim_hd")
    if mode == "stadium" then mode = "kenney" end   -- STADIUM 2 was removed (0.9.1)
    return MODES[mode] and mode or "kim_hd"
  end

  -- Battle Art's 3D-BTL stage runs for every choice except DEFAULT (WHITE).
  function B.stageEnabled()
    return B.mode() ~= "white"
  end

  -- ------------------------------------------------------- battle context
  local mapContext, pendingEncounter, lastTimeOfDay
  local current        -- context of the battle on screen (or just ended)
  local plan           -- resolved background for `current`, built lazily

  local function releasePlan()
    if plan and plan.release then pcall(plan.release, plan) end
    plan = nil
  end

  local function mapFromEvent(ev)
    local map = ev and ev.map
    local def = map and map.def
    local environment = def and def.environment
    local outside
    if environment ~= nil then
      outside = environment == "TOWN" or environment == "ROUTE" or environment == "FOREST"
    end
    return { mapId = ev and ev.mapId or map and map.id,
      environment = environment, outside = outside, waterType = def and def.waterType }
  end

  mod.events:on("map.entered", function(ev)
    mapContext = mapFromEvent(ev)
    pendingEncounter = nil
    if not (current and current.live) then releasePlan() end
    B.prewarmPending = true
  end)

  mod.hooks:wrap("encounter.species", function(next, enc, ctx)
    local out = next(enc, ctx)
    if out ~= nil then
      pendingEncounter = { mapId = ctx and ctx.mapId, terrain = ctx and ctx.terrain,
        environment = ctx and ctx.environment, waterType = ctx and ctx.waterType,
        timeOfDay = ctx and ctx.daytime }
    end
    return out
  end, 95)

  mod.hooks:wrap("world.tod", function(next, tod, ctx)
    local out = next(tod, ctx)
    local hour = tonumber(ctx and ctx.hour)
    lastTimeOfDay = out == "NITE" and hour and hour >= 18 and hour < 21 and "EVE" or out
    return out
  end, 95)

  mod.events:on("world.stepped", function() pendingEncounter = nil end)

  mod.events:on("battle.started", function(ev)
    releasePlan()
    local here = mod.world and mod.world.current and mod.world:current() or nil
    local mapId = here and here.mapId or mapContext and mapContext.mapId
    local mapped = mapContext and mapContext.mapId == mapId and mapContext or nil
    local encounter = pendingEncounter and pendingEncounter.mapId == mapId
      and pendingEncounter or nil
    local battle = ev and ev.battle
    current = {
      live = true, generation = tonumber(mod.generation) or 2, mapId = mapId,
      environment = (encounter and encounter.environment) or (mapped and mapped.environment),
      outside = mapped and mapped.outside,
      terrain = encounter and encounter.terrain or nil,
      waterType = (encounter and encounter.waterType) or (mapped and mapped.waterType),
      timeOfDay = lastTimeOfDay or (encounter and encounter.timeOfDay),
      kind = ev and ev.kind, trainerId = ev and ev.trainerId,
      battleType = ev and ev.battleType,
      battleTower = battle and battle.inBattleTowerBattle == true,
    }
    pendingEncounter = nil
  end)

  mod.events:on("battle.ended", function()
    -- Gen 2 keeps drawing the battle through its exit fade; the plan lives
    -- until the next battle or map change releases it.
    if current then current.live = false end
  end)

  -- -------------------------------------------------- stadium modules
  local S = {}
  local function stadium(name)
    if S[name] == nil then
      local ok, value = pcall(require, SROOT .. name)
      S[name] = ok and value or false
      if not ok then warn("stadium2 %s: %s", name, tostring(value)) end
    end
    return S[name] or nil
  end

  -- ---------------------------------------------------- similarity map
  -- Map Battle Art world points onto the Stadium scene: Battle Art's player
  -- slot -> the scene's player slot, enemy -> enemy, uniform scale, rotation
  -- about +Y. Projection is invariant under this map, so the scene seen
  -- through the mapped camera lines up with the cards Battle Art draws.
  local function similarity(pb, eb, ps, es)
    local dbx, dbz = eb[1] - pb[1], eb[3] - pb[3]
    local dsx, dsz = es[1] - ps[1], es[3] - ps[3]
    local lb = math.sqrt(dbx * dbx + dbz * dbz)
    local ls = math.sqrt(dsx * dsx + dsz * dsz)
    if lb < 1e-6 or ls < 1e-6 then return nil end
    local k = ls / lb
    local atan2 = math.atan2 or math.atan
    local th = atan2(dsz, dsx) - atan2(dbz, dbx)
    local c, s = math.cos(th), math.sin(th)
    local function point(p)
      local vx, vz = p[1] - pb[1], p[3] - pb[3]
      return { ps[1] + k * (vx * c - vz * s), ps[2] + k * (p[2] - pb[2]),
               ps[3] + k * (vx * s + vz * c) }
    end
    local function vector(v)
      return { v[1] * c - v[3] * s, v[2], v[1] * s + v[3] * c }
    end
    return point, vector, k
  end

  local LOVE_CANVAS_Y = { 1,0,0,0, 0,-1,0,0, 0,0,1,0, 0,0,0,1 }

  local function pixelRatio()
    local g = love and love.graphics
    if not (g and g.getDimensions and g.getPixelDimensions) then return 1 end
    local ok, w = pcall(g.getDimensions)
    local okP, pw = pcall(g.getPixelDimensions)
    if ok and okP and tonumber(w) and tonumber(pw) and w > 0 and pw > 0 then
      return pw / w
    end
    return 1
  end

  -- A plan that renders a Stadium Scene (Kenney environment or ROM arena)
  -- through the Battle Art camera handed to render(view).
  local function scenePlan(scene, label)
    local Renderer, Camera = stadium("renderer"), stadium("battle_camera")
    if not (Renderer and Camera) then
      pcall(scene.release, scene)
      return nil
    end
    local p = { kind = "scene", label = label, scene = scene, exact = true,
      broken = false }
    scene.backdropOnly = true
    scene.cameraOverride = function(_, width, height)
      local c = p.camera
      if not c then return nil end
      local view = Renderer.lookAt(c.eye[1], c.eye[2], c.eye[3],
        c.focus[1], c.focus[2], c.focus[3], c.up[1], c.up[2], c.up[3])
      local projection = Renderer.matMul(LOVE_CANVAS_Y,
        Renderer.perspective(c.fov, width / math.max(1, height), c.near, c.far))
      local fit = Camera.fitScale(width, height)
      local ox, oy = Camera.fitOrigin(width, height, fit)
      return { view = view, projection = projection,
        vp = Renderer.matMul(projection, view),
        eye = c.eye, focus = c.focus,
        letterbox = { lx = ox, ly = oy, scale = fit, pw = width, ph = height } }
    end
    -- gen2-aio: a scene that keeps producing nothing is given up on after
    -- a few seconds (KIM HD takes over), with the reason on DIAGNOSTICS
    local misses = 0
    local function miss(why)
      misses = misses + 1
      if misses == 120 then
        p.broken = true
        warn("%s backdrop gave nothing for 120 frames (%s)", label, tostring(why))
      end
      return nil
    end
    function p.render(v)
      if p.broken then return nil end
      local ps, es = scene:actorPosition("player"), scene:actorPosition("enemy")
      local point, vector, k = similarity(v.player, v.enemy, ps, es)
      if not point then
        return miss(("no battler positions: view %s/%s, scene %s/%s"):format(
          tostring(v.player ~= nil), tostring(v.enemy ~= nil), tostring(ps ~= nil), tostring(es ~= nil)))
      end
      local dx, dy, dz = v.eye[1] - v.focus[1], v.eye[2] - v.focus[2], v.eye[3] - v.focus[3]
      local dist = math.max(1, math.sqrt(dx * dx + dy * dy + dz * dz))
      p.camera = {
        eye = point(v.eye), focus = point(v.focus), up = vector(v.up or { 0, 1, 0 }),
        fov = v.fov,
        near = k * math.max(1, dist * 0.05),
        far = k * (dist * 4 + 4096),
      }
      local ratio = pixelRatio()
      local w = math.max(1, math.floor((v.width or 1) / ratio + 0.5))
      local h = math.max(1, math.floor((v.height or 1) / ratio + 0.5))
      -- Scene.render uses global graphics state. A portrait HUD scissor or
      -- transform must not clip its offscreen surface, and its depth/blend
      -- changes must not leak back into gmarc's card capture.
      local g = love.graphics
      g.push("all")
      g.origin(); g.setScissor(); g.setShader()
      g.setColor(1, 1, 1, 1)
      local okRender, rendered = pcall(scene.render, scene, w, h)
      g.pop()
      if not okRender then
        p.broken = true
        warn("%s backdrop failed: %s", label, tostring(rendered))
        return nil
      end
      if not rendered then
        if scene.defect then
          p.broken = true
          warn("%s backdrop failed: %s", label, tostring(scene.defect))
          return nil
        end
        return miss("scene not ready")
      end
      misses = 0
      local d = rawget(mod, "_kimArenaDiag")
      if type(d) == "function" then
        local canvas = scene.presentCanvas or scene.canvas
        local cw, ch = canvas:getDimensions()
        pcall(d, "kenney surface", ("%s %dx%d -> %dx%d"):format(label, w, h, cw, ch))
      end
      return scene.presentCanvas or scene.canvas
    end
    function p.release()
      if scene then pcall(scene.release, scene) end
      scene = nil
    end
    -- The image handed to BattleScene before render() runs: any object with
    -- getDimensions. render() returns the real canvas for this frame.
    p.image = { getDimensions = function() return 1, 1 end }
    return p
  end

  local function newScene(opts)
    local Scene = stadium("battle_scene")
    if not Scene then return nil end
    local ok, scene = pcall(Scene.new, opts)
    if not ok then warn("stadium2 scene: %s", tostring(scene)); return nil end
    scene.game = mod.game or (host.game and host.game()) or nil
    return scene, Scene
  end

  local function kenneyPlan(ctx)
    local E = stadium("battle_environment")
    if not E then return nil end
    local ok, sel = pcall(E.select, ctx, "kenney", false, nil, nil, nil)
    if not ok or type(sel) ~= "table" then return nil end
    if sel.mode == "arena" then sel = sel.fallback end   -- gyms: painted gym
    if not (sel and sel.mode == "environment" and sel.scene) then return nil end
    local scene = newScene({ actors = {}, label = "Gen2-AIO Kenney backdrop",
      warn = function(message) warn("%s", tostring(message)) end })
    if not scene then return nil end
    scene.battleContext = ctx
    scene.environmentSelection = sel
    local made = scenePlan(scene, "Kenney " .. tostring(sel.id))
    if made then made.sceneId = sel.id end
    return made
  end


  local KimHd = host.load("lib/gen2_aio/kim_hd_crystal.lua")
  -- KIM's authored feet positions for each painted background (1920x950).
  local KimRouter = host.load("data/hd_battle_backgrounds.lua")
  local function kimAnchors(file, image)
    if not (KimRouter and type(KimRouter.groundAnchors) == "function") then return nil end
    local ok, a = pcall(KimRouter.groundAnchors, { file = file })
    if not ok or type(a) ~= "table" or not (a.player and a.enemy) then return nil end
    local okD, iw, ih = pcall(image.getDimensions, image)
    if not okD or not (iw and ih and iw > 0 and ih > 0) then return nil end
    local kx, ky = iw / 1920, ih / 950
    return { player = { a.player.x * kx, a.player.y * ky },
             enemy = { a.enemy.x * kx, a.enemy.y * ky } }
  end
  local kimImages = {}
  local function kimPlan(ctx)
    local provider = rawget(mod, "_kimAssetProvider")
    if not (provider and provider.image and KimHd) then return nil end
    local category = "unknown"
    local E = stadium("battle_environment")
    if E then
      local ok, id = pcall(E.classify, ctx or {}, {})
      if ok and id then category = id end
    end
    local file = KimHd.file(ctx, category)
    local rel = "assets/battle/backgrounds/hd/" .. file .. ".png"
    local image = kimImages[rel]
    if image == nil then
      local ok, made = pcall(provider.image, rel)
      image = ok and made or false
      if image then
        pcall(image.setFilter, image, "linear", "linear")
        pcall(image.setWrap, image, "clamp", "clamp")
      else
        warn("KIM HD background %s is not downloaded yet; showing the voxel world", file)
      end
      kimImages[rel] = image
    end
    if not image then return nil end
    -- Anchored: the art's own ground spots are fitted under the battlers'
    -- feet. KIM HD BG ALIGN OFF falls back to the plain cover crop.
    local anchors = opt("kimHdAlign", true) ~= false and kimAnchors(file, image) or nil
    return { kind = "kim", image = image, exact = false, anchors = anchors,
      fill = tostring(opt("kimHdFill", "nature")),
      offset = tonumber(opt("kimHdOffset", 100)) or 100, label = "KIM HD " .. file }
  end

  local function buildPlan()
    local ctx = current
    if not ctx then return { kind = "none" } end
    local mode = B.mode()
    local made
    -- gen2-aio 0.9.8: Stadium 2 arenas are gone; an old saved STADIUM
    -- value draws KENNEY HD.
    if mode == "stadium" then mode = "kenney" end
    if not made and mode == "kenney" then
      local okK, k = pcall(kenneyPlan, ctx)
      made = okK and k or nil
      if not made then
        warn("KENNEY HD: no scene for this battle (%s); using KIM HD", okK and "no match" or tostring(k))
        mode = "kim_hd"
      end
    end
    if not made and mode == "kim_hd" then made = kimPlan(ctx) end
    made = made or { kind = "none" }
    made.mode = B.mode()
    local d = rawget(mod, "_kimArenaDiag")
    if type(d) == "function" then
      pcall(d, "battle bg plan", tostring(made.label or made.kind) .. " (" .. tostring(made.mode) .. ")")
    end
    return made
  end

  local function currentPlan()
    if not (current and B.stageEnabled()) then return nil end
    local mode = B.mode()
    if mode == "voxel" then return nil end
    if plan and plan.mode ~= mode then releasePlan() end
    if not plan then plan = buildPlan() end
    -- a broken KENNEY scene hands over to the KIM HD painting, once
    if plan.broken and plan.kind == "scene" and not plan.fellBack then
      local okK, k = pcall(kimPlan, current)
      if okK and k then
        releasePlan()
        k.mode, k.fellBack = mode, true
        plan = k
        warn("KENNEY HD gave up here; using KIM HD")
      else
        plan.fellBack = true
      end
    end
    if plan.kind == "none" or plan.broken then return nil end
    return plan
  end

  -- Battle Art ARENA FILL while a battle is staged: PNG while this module
  -- has a plate for it, OFF (the voxel world) otherwise.
  function B.fillValue()
    return currentPlan() and "PNG" or "OFF"
  end

  -- voxel/lib/BattleScene.lua: { image, exact, offset, render(view) }
  function B.plate()
    return currentPlan()
  end

  -- the Kenney scene type of the battle on screen (grass, cave, ocean, ...)
  function B.sceneId()
    local p = plan
    return p and p.kind == "scene" and p.sceneId or nil
  end

  function B.status()
    local p = plan
    return { mode = B.mode(), plan = p and p.kind, label = p and p.label,
      battle = current and current.mapId }
  end

  -- Build the Kenney scene for the map the player just entered, outside
  -- battle, so the first encounter does not pay for the mesh build.
  function B.prewarm()
    if not B.prewarmPending then return end
    if current and current.live then return end
    B.prewarmPending = false
    if B.mode() ~= "kenney" or not mapContext then return end
    local Cache = stadium("environment_cache")
    local g = love and love.graphics
    if not (Cache and Cache.location and g and g.newCanvas) then return end
    local ok, err = pcall(Cache.location, g, mapContext, "kenney", "automatic", nil)
    if not ok then warn("Kenney prewarm: %s", tostring(err)) end
  end

  function B.release()
    releasePlan()
    current = nil
  end

  return B
end
