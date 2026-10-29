-- Gen2-AIO (gen2-aio)
--
-- One mod built from three:
--   * Kanto in Motion 1.7.6   (root: kim_main.lua, lib/, data/, assets/)
--                              HD animated Pokemon, menus and battle UI
--   * gmarcs Gen 2 Voxel Mod  (gmarc/) the default voxel overworld and 3D
--     1.0.6                    battle; its 3D-BTL and Stadium rows are owned here
--   * Battle Art Voxel Gen2   (voxel/) the alternative engine (VOXEL ENGINE);
--     2.1.4                    its own battle-sprite art is pinned off
--   * Stadium 2 Importer      (stadium2/) Kenney scenes and Stadium 2 arenas,
--     0.25.0                   used only as battle backgrounds
--
-- The engine gives a mod one options schema (options:define replaces it) and
-- one id, and the bundled parts were written as separate mods. This file
-- runs each part with the view it expects:
--   * every options:define call is merged into one schema;
--   * Battle Art runs on a proxy whose files, assets and paths point at voxel/
--     and whose battle settings the host can pin;
--   * mod.find("BATTLE_ART_VOXEL_GEN2") returns the bundled Battle Art, so
--     KIM's Gen 2 Battle Art bridge (HD cards, HUD placement) finds it;
--   * Stadium modules run on a proxy whose stadium2_* settings come from this
--     mod's BATTLE BACKGROUND rows.

return function(mod)
  local ID = mod.id

  local function log(level, fmt, ...)
    local logger = mod.log
    local fn = logger and logger[level]
    if fn then pcall(fn, logger, fmt, ...) end
  end

  local loader = loadstring or load
  local function chunk(rel)
    local source, err = mod:read(rel)
    if not source then error(("%s missing: %s"):format(rel, tostring(err)), 0) end
    return assert(loader(source, "@" .. tostring(mod.path) .. "/" .. rel))
  end
  local function loadOwn(rel)
    local ok, value = pcall(function() return chunk(rel)() end)
    if ok then return value end
    log("error", "Gen2-AIO: %s failed: %s", rel, tostring(value))
    return nil
  end

  -- Import settings and downloaded assets before any component reads them.
  local migration = loadOwn("lib/gen2_aio/identity_migration.lua")
  if migration then
    local okM, err = pcall(migration.install, mod)
    if not okM then log("warn", "Gen2-AIO migration: %s", tostring(err)) end
  end

  -- -------------------------------------------------------------- options
  local realOptions = mod.options
  local repelsMode
  local realDefine = realOptions.define
  local realGet = realOptions.get
  local merged, position = {}, {}
  local function mergeDefine(_, schema)
    for _, row in ipairs(type(schema) == "table" and schema or {}) do
      if type(row) == "table" and type(row.key) == "string" then
        if row.key == "pixelFont" then row.visible_if = { key = "arenaFont", equals = "kim" } end
        local at = position[row.key]
        if at then merged[at] = row
        else merged[#merged + 1] = row; position[row.key] = #merged end
      end
    end
    realDefine(realOptions, merged)
    return schema
  end
  realOptions.define = mergeDefine
  -- the merged schema, for the hub's pages (lib/gen2_aio/hub.lua)
  rawset(mod, "_kimArenaSchema", function() return merged, position end)

  -- 0.9.66: rows merged into one. The new row has no default, so a player
  -- who never touched it keeps what the old rows said; components keep
  -- reading the old keys, answered from the new row.
  local DERIVED_OPT = {}
  local function spriteAnimMode()
    local v = realGet(realOptions, "spriteAnim")
    if v ~= nil then return v end
    if realGet(realOptions, "animate") == false then return "off" end
    if realGet(realOptions, "spriteAnimation") == false then return "battle" end
    return "on"
  end
  -- REPELS: OFF / ASK (Gen1Wild's prompt when one wears off) / AUTO
  -- (QoL Toggles' AUTO-REPEL) / INFINITE (QoL Toggles' INFINITE REPEL)
  repelsMode = function()
    local v = realGet(realOptions, "repels")
    if v ~= nil then return v end
    if realGet(realOptions, "qt_repel") == true then return "infinite" end
    return "ask"
  end
  DERIVED_OPT.spriteAnim = spriteAnimMode
  DERIVED_OPT.animate = function() return spriteAnimMode() ~= "off" end
  DERIVED_OPT.spriteAnimation = function() return spriteAnimMode() == "on" end
  DERIVED_OPT.repels = repelsMode
  realOptions.get = function(self, key)
    local derive = DERIVED_OPT[key]
    if derive then
      local ok, v = pcall(derive)
      if ok and v ~= nil then return v end
    end
    return realGet(self, key)
  end

  -- DIAGNOSTICS: short status lines components report, drawn on screen
  -- when the DIAGNOSTICS setting is on (so problems can be read off a phone)
  local diagLines, diagOrder = {}, {}
  local function diagSet(key, value)
    key = tostring(key)
    if diagLines[key] == nil then diagOrder[#diagOrder + 1] = key end
    diagLines[key] = tostring(value)
  end
  mod._kimArenaDiag = diagSet
  local function opt(key, default)
    local ok, value = pcall(realGet, realOptions, key)
    if ok and value ~= nil then return value end
    return default
  end
  -- the host's option reader, for vendored code that needs host settings
  rawset(mod, "_kimArenaOpt", function(key, default) return opt(key, default) end)


  -- Battle Art rows that belong to its own battle-sprite art or to choices
  -- this mod now owns: removed from every menu, values pinned below.
  local BA_ART = {}
  for key in ([[interfaceSprites interfaceScaling battleArt trainerArtSet
      playerArtSet playerAnimatedSet frontAnimatedSet backAnimatedSet
      duplicateFix playerView frontFlip battles arenaFill stadiumCircle
      backdropOffset bossBg]]):gmatch("%S+") do BA_ART[key] = true end
  -- Battle Art's 3D-battle HUD/textbox rows: shown with SHOW BATTLE UI ROWS.
  local BA_UI = {}
  for key in ([[backPlacement battleBack spriteLight hudColor
      textboxFill]]):gmatch("%S+") do BA_UI[key] = true end

  local Backdrop -- created after KIM loads

  local function mode()
    if Backdrop then return Backdrop.mode() end
    if opt("battleSprites", true) == false then return "white" end
    return opt("arenaBackground", "kim_hd")
  end
  local function scene3d() local m = mode(); return m == "kenney" or m == "stadium" end

  local DEPENDS
  local OWN_VISIBLE = {
    arenaStadiumField = function() return mode() == "stadium" end,
    arenaResolution = scene3d, arenaShader = scene3d,
    arenaExtras = scene3d, arenaWeather = scene3d,
    kimHdOffset = function() return mode() == "kim_hd" and opt("kimHdAlign", true) == false end,
    kimHdAlign = function() return mode() == "kim_hd" end,
    kimHdFill = function() return mode() == "kim_hd" and opt("kimHdAlign", true) ~= false end,
    arenaCamera = function() return mode() ~= "white" end,
    arenaPlayerIntro = function() return mode() ~= "white" end,
  }
  -- 0.9.66: shown only while they can do something (hub pages, gmarc rows)
  local function nativeHud() return opt("arenaHud", "modern") == "native" end
  local function weatherOn() return opt("weatherFx", "on") ~= "off" end
  local function hudOn() return opt("overworldHud", true) ~= false end
  local function quickOn() return opt("quickMenu", true) ~= false end
  local THEME_FRAME = { ["gen2_aio:gen3"] = true, ["gen2_aio:custom"] = true }
  DEPENDS = {
    gen2BattleHudColor = nativeHud, qt_exp_bar = nativeHud, caught_qol_caught_indicator = nativeHud,
    arenaCardDetail = function() return mode() ~= "white" end,
    arenaEnemySize = function() return mode() ~= "white" end,
    aa = function() return opt("perfMode", "balanced") == "quality" end,
    weatherPlaces = weatherOn, weatherRain = weatherOn, weatherMoves = weatherOn,
    weatherBattle = weatherOn,
    timeFade = function()
      local v = opt("timeOfDay", "sync")
      return v == "sync" or v == "cycle" or v == "cycle60"
    end,
    hudPosition = hudOn,
    quickInStart = quickOn,
    pixelFont = function() return opt("arenaFont", "pixel_operator") == "kim" end,
    frameStyle = function() return not THEME_FRAME[opt("gen2UiTheme", "default")] end,
    frameAsset = function()
      return not THEME_FRAME[opt("gen2UiTheme", "default")] and opt("frameStyle", "pixel") == "pixel"
    end,
    frameScale = function()
      return not THEME_FRAME[opt("gen2UiTheme", "default")] and opt("frameStyle", "pixel") == "pixel"
    end,
  }

  -- ------------------------------------------------- sub-mod proxies
  local function joined(prefix, rel)
    if rel == nil or rel == "" then return prefix end
    rel = tostring(rel):gsub("\\", "/"):gsub("^%./", "")
    -- engine-owned imports live at the real mod root
    if rel:sub(1, 9) == "baseroms/" then return rel end
    return prefix .. "/" .. rel
  end

  local function subMod(prefix)
    local p = setmetatable({}, { __index = mod })
    p.path = tostring(mod.path) .. "/" .. prefix
    p.read = function(_, rel) return mod:read(joined(prefix, rel)) end
    if mod.list then p.list = function(_, rel) return mod:list(joined(prefix, rel)) end end
    if mod.info then p.info = function(_, rel) return mod:info(joined(prefix, rel)) end end
    local realAssets = mod.assets
    if realAssets then
      p.assets = setmetatable({}, { __index = function(t, k)
        local v = realAssets[k]
        if type(v) ~= "function" then return v end
        local wrapped = function(_, rel, ...)
          if type(rel) == "string" then rel = joined(prefix, rel) end
          return v(realAssets, rel, ...)
        end
        rawset(t, k, wrapped)
        return wrapped
      end })
    end
    p.exports = {}
    return p
  end

  -- ------------------------------------------------- voxel engine
  -- gen2-aio 0.9.1: gmarc is the only voxel engine (Battle Art removed).
  local ENGINES = { gmarc = "gmarc" }
  local engine = "gmarc"
  local gmarcEngine = engine == "gmarc"

  -- gmarc rows the fork owns: its 3D-BTL mode and its own Stadium model
  -- import (the fork's backgrounds replace both).
  local GM_ART = { battles = true, stadiumImport = true, daytime = true }
  -- BATTLE SPRITES = STADIUM 2: set up after the Stadium 2 modules bind
  local StadiumModels = nil
  local function stadiumModelsReady()
    if not (gmarcEngine and StadiumModels) then return false end
    local ok, api = pcall(StadiumModels.models)
    return ok and api ~= nil
  end

  local function rowHidden(key)
    if key == "touchMouse" then return true end   -- desktop testing aid only
    -- set through the hub's list pickers (lib/gen2_aio/theme_picker.lua)
    if key == "kimArenaCustomFrame" or key == "kimArenaCustomBacking"
        or key == "kimArenaCustomBorder" then return true end
    if key == "arenaSprites" and not gmarcEngine then return true end
    if gmarcEngine then
      if GM_ART[key] then return true end
      if key == "showBattleUiRows" then return true end
    else
      if BA_ART[key] then return true end
      if BA_UI[key] then return opt("showBattleUiRows", false) ~= true end
      if key == "arenaCardDetail" then return true end
    end
    if key == "arenaBackground" then return opt("battleSprites", true) == false end
    -- 0.9.66: rows that only do something with another row's value
    local dep = DEPENDS[key]
    if dep then
      local okD, show = pcall(dep)
      if okD and not show then return true end
    end
    local visible = OWN_VISIBLE[key]
    if visible then return not visible() end
    return false
  end
  mod._kimArenaRowHidden = rowHidden

  local voxel = subMod(ENGINES[engine])
  local locks
  if gmarcEngine then
    -- gmarc's 3D-BTL: false = native battle, true = on the map, "flatB" =
    -- the platform arena, whose discs a BATTLE BACKGROUND plate replaces.
    locks = {
      -- the voxel sky reads Crystal's clock, which TIME OF DAY drives
      daytime = "sync",
      battles = function()
        if not (Backdrop and Backdrop.stageEnabled()) then return false end
        -- BATTLE SPRITES = STADIUM 2 with the model cache built: gmarc's
        -- model modes ("stadiumB" on the platform arena, "stadium" on the map)
        local models = stadiumModelsReady()
        if Backdrop.mode() == "voxel" then return models and "stadium" or true end
        if Backdrop.fillValue() == "PNG" then return models and "stadiumB" or "flatB" end
        return models and "stadium" or true
      end,
    }
  else
    locks = {
      battles = function() return Backdrop ~= nil and Backdrop.stageEnabled() end,
      arenaFill = function() return Backdrop and Backdrop.fillValue() or "OFF" end,
      battleArt = "rom",
      interfaceSprites = "off",
    }
  end
  voxel._kimArenaLocks = locks
  -- 0.9.31 PERFORMANCE = BALANCED (default): the costly gmarc rungs are held
  -- down -- supersampled AA off, FOREST FX FULL drops to LOW -- without
  -- touching what the player stored; QUALITY hands them back.
  local function perfBalanced() return opt("perfMode", "balanced") ~= "quality" end
  if gmarcEngine then
    locks.aa = function() if perfBalanced() then return 0 end return nil end
    locks.atmos = function()
      if perfBalanced() and realGet(realOptions, "atmos") == "full" then return "low" end
      return nil
    end
  end
  voxel._kimArenaRowHidden = rowHidden
  -- BATTLE CAMERA: LOCKED holds the solved battle shot (no drift, steering
  -- or zoom) so the flat sprite cards never swing in 3D.
  -- VOXEL PRECACHE: pre-build door destinations (gmarc/lib/Prefetch.lua)
  voxel._kimArenaPrecache = function() return opt("voxelPrecache", true) ~= false end
  -- VOXEL DISK CACHE: finished map builds are kept on storage between plays
  -- (gmarc/lib/MeshStore.lua); the build id retires files from older builds
  voxel._kimArenaMeshStore = function() return opt("voxelDiskCache", true) ~= false end
  -- The id is a fingerprint of gmarc's own code and data, not the bundle
  -- version: a bundle update that does not touch the voxel builder keeps
  -- every cached map. Computed once here, at load, not mid-game.
  local buildIdValue = "dev"
  pcall(function()
    local okB, bitlib = pcall(require, "bit")
    if not okB then return end
    local h = 0x811c9dc5
    local function eat(str)
      for i = 1, #str, 7 do      -- every 7th byte plus the length: fast, and
        h = bitlib.bxor(h, str:byte(i))   -- any real edit shifts the sample
        h = bitlib.tobit(bitlib.lshift(h, 24) + bitlib.tobit(h * 403))
      end
      h = bitlib.bxor(h, #str)
    end
    -- code is read in full (1.4 MB); the big data folder (~40 MB of map
    -- overrides) is fingerprinted by file names and sizes only
    local function walk(dir, full)
      local okL, items = pcall(mod.list, mod, dir)
      if not okL or type(items) ~= "table" then return end
      table.sort(items)
      for _, name in ipairs(items) do
        local path = dir .. "/" .. tostring(name)
        local info = mod.info and mod:info(path)
        if info and info.type == "directory" then walk(path, full)
        elseif full then
          local okR, body = pcall(mod.read, mod, path)
          eat(path); if okR and type(body) == "string" then eat(body) end
        else
          eat(path .. ":" .. tostring(info and info.size or "?"))
        end
      end
    end
    walk("gmarc/lib", true); walk("gmarc/data", false)
    buildIdValue = "g" .. bitlib.tohex(h)
  end)
  voxel._kimArenaBuildId = function() return buildIdValue end
  -- HIT FLICKER: STEADY keeps a card through Crystal's brief pic clears
  voxel._kimArenaSteadyHits = function() return opt("hitFlicker", "steady") ~= "flicker" end
  voxel._kimArenaCameraLocked = function()
    return opt("arenaCamera", "locked") ~= "free"
  end
  -- PLAYER INTRO SPRITE: OFF removes the player's trainer card from the 3D
  -- stage during the battle-start intro.
  voxel._kimArenaHidePlayerIntro = function()
    return opt("arenaPlayerIntro", true) == false
  end
  -- KIM's battler shadow, moved from the upright 3D card onto the plate:
  -- begin (true) asks KIM to publish the metrics instead of drawing them;
  -- end (false) returns KIM's shadow params for that side.
  -- gmarc: fill past the map's border ring with the border block (VoidFloor)
  voxel._kimArenaStadiumModels = function()
    if not (gmarcEngine and StadiumModels) then return nil end
    local ok, api = pcall(StadiumModels.models)
    return ok and api or nil
  end
  voxel._kimArenaDiag = diagSet
  voxel._kimArenaVoidRelief = function() return opt("voidRelief", true) ~= false end
  voxel._kimArenaVoidFloor = function() return opt("voidFloor", true) ~= false end
  voxel._kimArenaShadowCapture = function(begin, side)
    if not (gmarcEngine and Backdrop and Backdrop.plate and Backdrop.plate()) then return nil end
    if begin then
      rawset(mod, "_kimArenaShadowWas", rawget(mod, "_kantoInMotionGen2BattleArtCapture"))
      mod._kantoInMotionGen2BattleArtCapture = true
      local bySide = rawget(mod, "_kantoInMotionGen2BattleArtShadowMetrics")
      if type(bySide) == "table" then bySide[side] = nil end
      return true
    end
    mod._kantoInMotionGen2BattleArtCapture = rawget(mod, "_kimArenaShadowWas")
    local bySide = rawget(mod, "_kantoInMotionGen2BattleArtShadowMetrics")
    local metrics = type(bySide) == "table" and bySide[side] or nil
    local shadows = rawget(mod, "_kantoInMotionBattlerShadows")
    if not (metrics and shadows and shadows.paramsFor) then return nil end
    local okP, params = pcall(shadows.paramsFor, shadows, metrics, side, 1)
    return okP and params or nil
  end
  -- KENNEY HD + BATTLE CAMERA LOCKED: a camera solved per battle that frames
  -- the two Pokemon where KIM HD's paintings put them, at an angle chosen per
  -- Kenney scene type (lib/gen2_aio/kenney_camera.lua)
  local KenneyCam = loadOwn("lib/gen2_aio/kenney_camera.lua")
  local camCache = setmetatable({}, { __mode = "k" })
  voxel._kimArenaCameraPreset = function(arena, groundY)
    if not (KenneyCam and Backdrop and Backdrop.mode() == "kenney") then return nil end
    if opt("arenaCamera", "locked") == "free" then return nil end
    if not (arena and arena.player and arena.enemy) then return nil end
    local w, h = love.graphics.getDimensions()
    local aspect = w / math.max(1, h)
    local scene = Backdrop.sceneId and Backdrop.sceneId() or nil
    local tall = h > w * 1.9
    local touch = mod.exports and mod.exports.touch
    local floating = false
    if touch and type(touch.active) == "function" then
      local okT, on = pcall(touch.active); floating = okT and on == true
    end
    local fieldBottom = (tall and floating) and 0.67 or 1
    -- Keep the Pokemon clear of the HUD as it is actually laid out: your
    -- Pokemon's feet just above the battle panel (it stands left of your
    -- card), the foe's feet just above your card, and both below the foe's
    -- card. Falls back to the KIM HD spots until the HUD has been drawn.
    local targets
    local R = rawget(mod, "_kimArenaHudRects")
    if R and R.W == w and R.H == h and R.player and R.enemy then
      local T = KenneyCam.TARGET
      local floor = (R.panelTop or h) / h
      local cardTop = R.player.y / h
      local enemyBottom = (R.enemy.y + R.enemy.h) / h
      local py = math.min(T.player[2] * fieldBottom, floor - 0.035)
      local ey = math.min(T.enemy[2] * fieldBottom, cardTop - 0.03)
      ey = math.max(ey, enemyBottom + 0.14)          -- room for the foe's body
      py = math.max(py, ey + 0.12)                    -- your Pokemon stays nearer
      local q = function(v) return math.floor(v * 100 + 0.5) / 100 end
      targets = { player = { T.player[1], q(py) }, enemy = { T.enemy[1], q(ey) } }
    end
    -- Aim once per battle: the first solve that knows where the HUD is
    -- stays until the screen itself changes (a Fold opening or closing).
    -- Menus moving the HUD no longer re-aim the shot mid-battle.
    local screenKey = ("%.4f|%s|%.2f|%.3f"):format(aspect, tostring(scene), fieldBottom, groundY or 0)
    local key = screenKey .. "|" .. (targets and (targets.player[2] .. "," .. targets.enemy[2]) or "-")
    local entry = camCache[arena]
    if entry and entry.screenKey == screenKey and (entry.locked or entry.key == key) then
      return entry.cam, entry.pitch
    end
    local cam, pitch = KenneyCam.solve(arena.player, arena.enemy, groundY or 0, aspect, scene,
      fieldBottom, targets)
    camCache[arena] = { key = key, screenKey = screenKey, cam = cam, pitch = pitch,
      locked = targets ~= nil and cam ~= nil }
    return cam, pitch
  end
  voxel._kimArenaBackdrop = {
    plate = function() return Backdrop and Backdrop.plate() or nil end,
  }
  -- gmarc: capture KIM's HD sprites supersampled (3D SPRITE DETAIL), and
  -- tell it the player's mon is a real back sprite.
  voxel._kimArenaKimSprites = function() return opt("battleSprites", true) ~= false end
  voxel._kimArenaCardScale = function()
    if opt("battleSprites", true) == false then return 1 end
    -- 0.9.34: 3D SPRITE DETAIL is the player's own cost knob, so PERFORMANCE
    -- no longer caps it (0.9.31-0.9.33 held a chosen 4X at 2X: blurry KIM HD
    -- sprites with the row still reading 4X).
    return tonumber(opt("arenaCardDetail", 4)) or 4
  end
  -- 0.9.56: ENEMY PKMN SIZE scales the far card in gmarc's 3D battles.
  voxel._kimArenaEnemyScale = function()
    return (tonumber(opt("arenaEnemySize", 100)) or 100) / 100
  end
  local hiddenRows = gmarcEngine and GM_ART or BA_ART
  voxel.options = {
    define = function(_, schema)
      if type(schema) == "table" then
        for i = #schema, 1, -1 do
          local row = schema[i]
          if type(row) == "table" and hiddenRows[row.key] then
            table.remove(schema, i)
          elseif not gmarcEngine and type(row) == "table" and BA_UI[row.key] then
            row.visible_if = { key = "showBattleUiRows", equals = true }
          end
        end
      end
      return mergeDefine(realOptions, schema)
    end,
    get = function(_, key)
      local lock = locks[key]
      if lock ~= nil then
        if type(lock) == "function" then
          local ok, value = pcall(lock)
          if ok and value ~= nil then return value end
        else
          return lock
        end
      end
      return realGet(realOptions, key)
    end,
  }

  local internal = {}
  if gmarcEngine then
    internal.gmarcs_gen2_voxel_mod = function()
      return { id = "gmarcs_gen2_voxel_mod", version = "1.0.7", exports = voxel.exports }
    end
    -- KIM's Battle Art bridges stay off: gmarc's battle captures KIM's
    -- direct-HD drawPic itself.
    internal.BATTLE_ART_VOXEL_GEN2 = function() return nil end
  else
    -- KIM's Gen 2 bridge (HD cards on the 3D stage, HUD placement) looks
    -- for exactly this id.
    local voxelHandle = { id = "BATTLE_ART_VOXEL_GEN2", version = "2.1.4",
      exports = voxel.exports }
    internal.BATTLE_ART_VOXEL_GEN2 = function() return voxelHandle end
  end
  local realFind = mod.find
  local function find(first, second)
    local id = type(first) == "table" and second or first
    local entry = internal[id]
    if entry then
      local handle = entry()
      if handle then return handle end
      return nil
    end
    return realFind(first, second)
  end
  mod.find = find
  voxel.find = find

  local voxelOk, voxelErr = pcall(function() chunk(ENGINES[engine] .. "/main.lua")(voxel) end)
  if not voxelOk then
    log("error", "Gen2-AIO: %s voxel engine failed to start: %s", engine, tostring(voxelErr))
    internal.BATTLE_ART_VOXEL_GEN2 = function() return nil end
    internal.gmarcs_gen2_voxel_mod = nil
  end
  mod.exports.voxel = voxel.exports
  mod.exports.voxelEngine = engine

  -- ------------------------------------------------- bundled components
  -- Each runs on its own proxy (files, assets and paths under its folder),
  -- isolated by pcall so one failing never stops the rest. VOXEL ENGINE,
  -- WILDS OF KANTO and NUZLOCKE choose what loads, on the next launch.

  -- Settings and per-save data the component keeps under a key prefix, so
  -- generic names ("enabled", ...) never collide with another component.
  local function namespaced(sub, prefix)
    sub._kimKeyPrefix = prefix
    local function fix(key)
      key = tostring(key)
      if key:sub(1, #prefix) == prefix then return key end
      return prefix .. key
    end
    sub.options = {
      define = function(_, schema)
        if type(schema) == "table" then
          for _, row in ipairs(schema) do
            if type(row) == "table" and type(row.key) == "string" then
              row.key = fix(row.key)
              if type(row.visible_if) == "table" and type(row.visible_if.key) == "string" then
                row.visible_if.key = fix(row.visible_if.key)
              end
            end
          end
        end
        return mergeDefine(realOptions, schema)
      end,
      get = function(_, key) return realGet(realOptions, fix(key)) end,
    }
    local realEvents = mod.events
    sub.events = setmetatable({
      on = function(_, name, fn, ...)
        if name == "mod.options_changed" and type(fn) == "function" then
          local inner = fn
          fn = function(payload, ...)
            if type(payload) == "table" and payload.key ~= nil then
              local k = tostring(payload.key)
              if k:sub(1, #prefix) ~= prefix then return end   -- another component's
              local copy = {}
              for a, b in pairs(payload) do copy[a] = b end
              copy.key = k:sub(#prefix + 1)
              return inner(copy, ...)
            end
            return inner(payload, ...)
          end
        end
        return realEvents:on(name, fn, ...)
      end,
    }, { __index = function(_, k)
      local v = realEvents[k]
      if type(v) == "function" then return function(_, ...) return v(realEvents, ...) end end
      return v
    end })
    local realSave = mod.save
    if realSave then
      sub.save = setmetatable({}, { __index = function(t, k)
        local v = realSave[k]
        if type(v) ~= "function" then return v end
        local w = function(_, key, ...)
          if type(key) == "string" then key = fix(key) end
          return v(realSave, key, ...)
        end
        rawset(t, k, w)
        return w
      end })
    end
    return sub
  end

  local function runComponent(label, sub, rel)
    local ok, err = pcall(function()
      local entry = chunk(rel)(sub)
      if type(entry) == "function" then entry(sub) end
    end)
    if not ok then log("error", "Gen2-AIO: %s failed to start: %s", label, tostring(err)) end
    return ok
  end

  -- Wilds of Kanto Revival (wilds/): visible wild Pokemon and followers.
  local VOXEL_IDS = { DRAMATIC_SHAPE = true, BATTLE_ART_VOXEL_FORK = true,
    BATTLE_ART_VOXEL_GEN2 = true, potato_voxel = true, DRAMALESS_SHAPE = true,
    STADIUM2_OVERWORLD_MODELS = true, TERRARIUM = true }
  local wildsOk = false
  if opt("wildsOfKanto", true) ~= false then
    local wilds = namespaced(subMod("wilds"), "wok_")
    -- Wilds finds a voxel engine by mod id. gmarc is a Dramatic Shape
    -- descendant with the same SpriteBillboards / Voxel3D / VoxelState
    -- contract as Dramaless, so it answers to that id and Wilds uses its
    -- generic variable-size adapter; Battle Art answers to its own id.
    wilds.find = function(first, second)
      local id = type(first) == "table" and second or first
      if voxelOk and gmarcEngine and id == "DRAMALESS_SHAPE" then
        return { id = "DRAMALESS_SHAPE", version = "1.0.7", exports = voxel.exports }
      end
      if voxelOk and not gmarcEngine and id == "BATTLE_ART_VOXEL_GEN2" then
        return { id = id, version = "2.1.4", exports = voxel.exports }
      end
      if VOXEL_IDS[id] then return nil end
      return find(first, second)
    end
    -- 0.9.10: SPRITE STYLE is the player's again (Wilds' own menu and the
    -- settings row). GSC followers stay the default; the 0.9.6 pin that
    -- ignored every choice is gone.
    wildsOk = runComponent("Wilds of Kanto", wilds, "wilds/main.lua")
    mod.exports.wilds = wilds.exports
  end

  -- Nuzlocke (nuzlocke/): rules, run state in namespaced per-save data.
  local nuzlockeOk = false
  if opt("nuzlockeMod", true) ~= false then
    local nz = subMod("nuzlocke")
    namespaced(nz, "nz_")
    -- no title-screen SETUP row: the SETUP WIZARD sets the run's rules
    rawset(nz, "_kimArenaNoTitleSetup", true)
    nz.find = find
    nuzlockeOk = runComponent("Nuzlocke", nz, "nuzlocke/main.lua")
    mod.exports.nuzlocke = nz.exports
  end

  -- ------------------------------------------------- Kanto in Motion
  local kimEntry = chunk("kim_main.lua")()
  if type(kimEntry) == "function" then kimEntry(mod) end

  -- ------------------------------------------------- Stadium 2 (stadium2/)
  local stadium = subMod("stadium2")
  local STADIUM_OPTIONS = {
    stadium2_shader = function() return opt("arenaShader", "stadium") end,
    stadium2_scene_resolution = function() return opt("arenaResolution", "auto") end,
    stadium2_battle_aa = 0,
    stadium2_fx_particles = function()
      local v = opt("arenaExtras", "on")
      if v == "lite" then return "lite" end
      return v == "on"
    end,
    stadium2_weather = function() return opt("arenaWeather", "off") end,
    stadium2_visitors = "off",
    stadium2_environment = "kenney",
    stadium2_environment_test = "automatic",
    stadium2_arena_test = -1,
    stadium2_camera = "free",
    stadium2_models = false,
    stadium2_battle = false,
    stadium2_battle_hud = false,
    stadium2_fx_pokeball = false,
    stadium2_rapidash_cut_fx = false,
    stadium2_beta_arena_test = false,
    stadium2_beta_arena_tod = false,
    stadium2_beta_battle_fx = false,
  }
  stadium.options = {
    define = function(_, schema) return schema end,
    get = function(_, key)
      local value = STADIUM_OPTIONS[key]
      if type(value) == "function" then return value() end
      if value ~= nil then return value end
      return realGet(realOptions, key)
    end,
  }
  for _, name in ipairs({ "importer", "battle_aa", "battle_nature", "battle_cave",
      "battle_freshwater", "battle_town", "battle_ocean", "scene_kit" }) do
    local ok, module = pcall(require, "mods." .. ID .. ".stadium2.lib." .. name)
    if ok and type(module) == "table" and type(module.bind) == "function" then
      local bound, err = pcall(module.bind, stadium)
      if not bound then log("warn", "Gen2-AIO: stadium2 %s bind: %s", name, tostring(err)) end
    elseif not ok then
      log("warn", "Gen2-AIO: stadium2 %s: %s", name, tostring(module))
    end
  end

  -- ------------------------------------------------- all 251 catchable
  local c251Factory = loadOwn("lib/gen2_aio/crystal251.lua")
  if type(c251Factory) == "function" then
    local ok251, made = pcall(c251Factory, { mod = mod, log = log })
    if ok251 then mod.exports.crystal251 = made
    else log("warn", "Gen2-AIO: 251 catchable: %s", tostring(made)) end
  end

  -- ------------------------------------------------- trainer levels
  local tlFactory = loadOwn("lib/gen2_aio/trainer_levels.lua")
  if type(tlFactory) == "function" then
    local okTL, made = pcall(tlFactory, { mod = mod, log = log })
    if okTL then mod.exports.trainerLevels = made
    else log("warn", "Gen2-AIO: trainer levels: %s", tostring(made)) end
  end

  -- ------------------------------------------------- backgrounds
  local factory = loadOwn("lib/gen2_aio/backdrop.lua")
  if type(factory) == "function" then
    local ok, made = pcall(factory, { mod = mod, load = loadOwn,
      game = function() return rawget(mod, "_kantoInMotionActiveGame") end })
    if ok then Backdrop = made
    else log("error", "Gen2-AIO: background provider failed: %s", tostring(made)) end
  end
  local ModernHud = nil
  local hudFactory = loadOwn("lib/gen2_aio/modern_hud.lua")
  if type(hudFactory) == "function" then
    local ok, made = pcall(hudFactory, { mod = mod })
    if ok then ModernHud = made
    else log("error", "Gen2-AIO: modern HUD failed: %s", tostring(made)) end
  end
  -- KIM's Gen 2 Modern UI style (theme, fonts, panels) for companion mods.
  mod.exports.kimStyle = function() return rawget(mod, "_kantoInMotionGen2Ui") end
  -- Party / Pack rows KIM drew last frame: { state, kind, time, cells }.
  mod.exports.screenTapTargets = function() return rawget(mod, "_kimScreenTapTargets") end
  -- The close button a Modern menu window drew last frame: { x, y, w, h, hit,
  -- state, time } (lib/gen2_modern_style.lua); KIM Touch taps B there.
  mod.exports.menuCloseRect = function() return rawget(mod, "_kimMenuClose") end
  mod.exports.arena = Backdrop and { status = Backdrop.status, mode = Backdrop.mode } or nil

  mod.hooks:wrap("input.step", function(next, game, dt)
    local result = next(game, dt)
    if Backdrop then pcall(Backdrop.prewarm) end
    return result
  end, 4)

  -- ------------------------------------------------- this mod's rows
  local arenaNames = { "FALKNER", "BUGSY", "WHITNEY", "MORTY", "JASMINE", "CHUCK",
    "PRYCE", "CLAIR", "TEAM ROCKET", "WILL", "KOGA", "BRUNO", "KAREN", "CHAMPION",
    "BROCK", "MISTY", "LT. SURGE", "ERIKA", "JANINE", "SABRINA", "BLAINE", "BLUE", "RED" }
  arenaNames[27] = "BATTLE TOWER"; arenaNames[28] = "INDOOR"
  arenaNames[29] = "FREE BATTLE PARK"; arenaNames[30] = "RIVAL"
  local arenaChoices = { { "AUTO", -1 } }
  for index = 0, 29 do
    arenaChoices[#arenaChoices + 1] = {
      ("%02d%s"):format(index, arenaNames[index + 1] and (" " .. arenaNames[index + 1]) or ""), index }
  end
  local offsetChoices = {}
  for v = 0, 400, 50 do offsetChoices[#offsetChoices + 1] = { tostring(v), v } end

  local schema = {
    { key = "voxelPrecache", label = "VOXEL PRECACHE", type = "toggle", default = true,
      help = "Pre-build the 3D areas behind the current area's doors in the background, "
        .. "so going through a door or into a building swaps in a ready scene. Uses a "
        .. "little more memory; turn OFF on low-memory devices." },
    { key = "trainerLevels", label = "TRAINER LEVELS", type = "choice", default = "match",
      choices = { { "ORIGINAL", "off" }, { "MATCH -5 TO 0", "matchm5" },
        { "MATCH -1/-2", "matchm12" }, { "MATCH", "match" }, { "MATCH +2", "match2" } },
      help = "MATCH raises a trainer's strongest Pokemon to your strongest Pokemon's level "
        .. "(the rest of their team moves up with it). MATCH -1/-2 puts it one or two levels "
        .. "under yours, MATCH -5 TO 0 anywhere from five under to level, picked per trainer. "
        .. "Trainers are never lowered; "
        .. "hand-picked movesets are kept. Nuzlocke's level caps still apply to you." },
    { key = "allCatchable", label = "ALL 251 CATCHABLE", type = "toggle", default = true,
      help = "Adds Crystal's 33 missing species to the wild (HGSS locations first), with "
        .. "legendaries and mythicals as rare encounters after the Elite Four, and "
        .. "trade evolutions by level-up (Lv 37, or holding the trade item)." },
    { key = "qolMod", label = "QUALITY OF LIFE", type = "toggle", default = true,
      help = "Load Gen1Wild QOL: sprint, autosave, auto continue, low HP beep, EXP share, "
        .. "move reminder, rematches, easy HMs and the menu layout editor. Their settings are "
        .. "on this page. Takes effect the next time the game starts." },
    { key = "startMenuPc", label = "PC IN START MENU", type = "toggle", default = true,
      help = "START -> PC opens Bill's PC from anywhere: withdraw, deposit, change box, "
        .. "move Pokemon. Same screen as a Pokemon Center PC." },
    { key = "quickMenu", label = "QUICK MENU", type = "toggle", default = true,
      help = "Hold START on the overworld (touch) for POKEGEAR, FLY, AREA DEX, DAY-CARE, TODAY's "
        .. "events and KEY ITEMS. A quick tap of START still opens the START menu." },
    { key = "overworldHud", label = "OVERWORLD HUD", type = "toggle", default = true,
      help = "Show tappable POKEGEAR, AREA DEX, BIKE and KEY ITEMS icons, the game clock "
        .. "and party health on the overworld. Hidden during dialogue, menus and battles." },
    { key = "hudPosition", label = "HUD POSITION", type = "choice", default = "tr",
      choices = { { "TOP RIGHT", "tr" }, { "TOP MIDDLE", "tc" }, { "TOP LEFT", "tl" },
        { "BOTTOM MIDDLE", "bc" }, { "BOTTOM LEFT", "bl" }, { "BOTTOM RIGHT", "br" } },
      help = "Where the overworld HUD's buttons and clock / party panel sit. Bottom "
        .. "positions put the clock panel at the bottom edge with the buttons above it." },
    { key = "menuClosePos", label = "MENU BUTTON", type = "choice", default = "tr",
      choices = { { "TOP RIGHT", "tr" }, { "BOTTOM RIGHT", "br" }, { "BOTTOM LEFT", "bl" } },
      help = "Corner of every menu window for its close (X) / back (arrow) button. "
        .. "The bottom corners sit in the footer, easier to reach one-handed." },
    { key = "quickInStart", label = "QUICK IN START MENU", type = "toggle", default = true,
      help = "Also list QUICK in the START menu, so the QUICK MENU works with any controller." },
    { key = "keyWheel", label = "KEY ITEM WHEEL", type = "toggle", default = true,
      help = "Hold SELECT on the overworld (touch) for a wheel of your usable key items (bike, "
        .. "rods, Itemfinder, ...). Drag to one and let go, or let go and tap one. Hold an "
        .. "item in the PACK to pin it to the wheel. The item you pick also becomes your SELECT item." },
    { key = "qolToggles", label = "QOL TOGGLES", type = "toggle", default = true,
      help = "Load QoL Toggles: quick nurse, auto-repel, instant hatch, EXP / money "
        .. "multipliers, lights on and more, on their own page. Takes effect the next time "
        .. "the game starts." },
    { key = "wildsOfKanto", label = "WILDS OF KANTO", type = "toggle", default = true,
      help = "Visible wild Pokemon and followers (Wilds of Kanto Revival). Its settings are "
        .. "on this page. Takes effect the next time the game starts." },
    { key = "nuzlockeMod", label = "NUZLOCKE", type = "toggle", default = true,
      help = "Load the Nuzlocke ruleset (set up from the title screen's SETUP entry). "
        .. "Takes effect the next time the game starts." },
    { key = "menuTransitions", label = "MENU TRANSITIONS", type = "choice", default = "dark",
      choices = { { "DARK", "dark" }, { "WHITE", "white" } },
      help = "DARK: a short fade through your Modern UI theme when menus open and close. "
        .. "WHITE: Crystal's original fade to white with its reload pause." },
    { key = "arenaFont", label = "UI FONT", type = "choice", default = "pixel_operator",
      choices = { { "PIXEL OPERATOR", "pixel_operator" }, { "KIM ORIGINAL", "kim" } },
      help = "Font for KIM's Modern UI, HUD cards and touch labels. PIXEL OPERATOR is a "
        .. "clean, readable pixel face (CC0). KIM ORIGINAL keeps KIM's own font setting." },
    { key = "weatherFx", label = "WEATHER", type = "choice", default = "on",
      choices = { { "ON", "on" }, { "LITE", "lite" }, { "OFF", "off" } },
      help = "Lore-friendly weather drawn over the world and battles. LITE uses half "
        .. "the particles." },
    { key = "weatherPlaces", label = "PLACE WEATHER", type = "toggle", default = true,
      help = "Snow outside Mt. Silver, frost in the Ice Path, mist on Lake of Rage, the "
        .. "Whirl Islands, Dragon's Den and the sea routes, embers in the Burned Tower, "
        .. "damp in Slowpoke Well and Union Cave, dust in Mt. Mortar and Rock Tunnel." },
    { key = "weatherRain", label = "RANDOM RAIN", type = "toggle", default = true,
      help = "Rain on outdoor routes and towns, decided by Crystal's clock (weekday and "
        .. "time of day): the same everywhere at a given time, changing through the day." },
    { key = "weatherMoves", label = "MOVE WEATHER", type = "toggle", default = true,
      help = "Show Rain Dance, Sunny Day and Sandstorm while they are active in battle." },
    { key = "weatherBattle", label = "WEATHER IN BATTLE", type = "toggle", default = true,
      help = "Battles keep the weather of the place they happen in." },
    { key = "voxelDiskCache", label = "VOXEL DISK CACHE", type = "toggle", default = true,
      help = "Keep every voxel map you have built on storage, so it never has to be "
        .. "rebuilt -- not when you come back, not after restarting. First visits build "
        .. "as before; later ones load from storage (about 0.5-2 GB if you visit "
        .. "everything). Files from older versions are removed automatically." },
    { key = "timeOfDay", label = "TIME OF DAY", type = "choice", default = "sync",
      choices = { { "SYNC", "sync" }, { "MORNING", "morning" }, { "DAY", "day" },
        { "EVENING", "evening" }, { "NIGHT", "night" }, { "CYCLE 30", "cycle" }, { "CYCLE 60", "cycle60" },
        { "CRYSTAL CLOCK", "crystal" } },
      help = "What time it is for everything: palettes, the voxel sky, encounter tables, "
        .. "Wilds' spawns, NPC schedules, weekday events. SYNC = this device's clock. "
        .. "MORNING / DAY / EVENING / NIGHT hold that time. CYCLE 30 / CYCLE 60 = a full day every 30 / 60 "
        .. "minutes. CRYSTAL CLOCK = the clock set in your save." },
    { key = "hdBall", label = "HD POKE BALLS", type = "toggle", default = true,
      help = "Draw the thrown ball as its own item icon (every Crystal ball) instead of "
        .. "the Game Boy ball tiles. The throw, bounces and wobbles are Crystal's own." },
    { key = "npcMonSprites", label = "WILDS NPC POKEMON", type = "toggle", default = true,
      help = "Pokemon standing in the world as characters (Farfetch'd, Slowpoke, the Red "
        .. "Gyarados, the beasts, day-care Pokemon, ...) use Wilds' sprites in your SPRITE "
        .. "STYLE, in 2D and 3D. OFF keeps Crystal's own small sprites." },
    -- CUSTOM UI THEME values (picked from lists on the DISPLAY & UI page)
    { key = "kimArenaCustomFrame", label = "CUSTOM BORDER", type = "choice", default = "gen3",
      choices = { { "GEN 3", "gen3" }, { "FRAME 1", "frame1" }, { "FRAME 2", "frame2" },
        { "FRAME 3", "frame3" }, { "SOFT", "soft" }, { "PLAIN", "plain" } } },
    { key = "kimArenaCustomBacking", label = "CUSTOM BACKING", type = "choice", default = "cream",
      choices = { { "WHITE", "white" }, { "CREAM", "cream" }, { "SKY", "sky" }, { "MINT", "mint" },
        { "PINK", "pink" }, { "SLATE", "slate" }, { "NAVY", "navy" }, { "BROWN", "brown" },
        { "FOREST", "forest" }, { "PLUM", "plum" }, { "BLACK", "black" } } },
    { key = "kimArenaCustomBorder", label = "CUSTOM BORDER COLOR", type = "choice", default = "teal",
      choices = { { "TEAL", "teal" }, { "BLUE", "blue" }, { "RED", "red" }, { "GOLD", "gold" },
        { "SILVER", "silver" }, { "GREEN", "green" }, { "PURPLE", "purple" }, { "ORANGE", "orange" },
        { "PINK", "pink" }, { "BLACK", "black" }, { "WHITE", "white" } } },
    { key = "moveTypeColors", label = "MOVE TYPE COLORS", type = "toggle", default = true,
      help = "In battle, each move's box is tinted in its type colour with a colour stripe." },
    { key = "moveEffectHint", label = "EFFECTIVENESS HINT", type = "toggle", default = false,
      help = "In battle, moves show SUPER, WEAK or NO EFFECT against the current enemy. Off by "
        .. "default (it makes a Nuzlocke easier)." },
    { key = "areaSignStyle", label = "AREA SIGN", type = "choice", default = "modern",
      choices = { { "MODERN", "modern" }, { "NATIVE", "native" } },
      help = "The town / route name shown when you enter an area. MODERN: a plaque in your "
        .. "UI THEME, top left, sliding in and fading out. NATIVE: Crystal's own sign." },
    { key = "timeFade", label = "TIME FADE", type = "toggle", default = true,
      help = "Softens the jump when the colours switch from day to night (18:00) and night "
        .. "to morning (04:00) on SYNC and CYCLE: the light dims into the change and back out "
        .. "over about 20 seconds instead of snapping." },
    { key = "followerLead", label = "FOLLOWER IS PARTY LEAD", type = "toggle", default = true,
      help = "Your follower is always the first healthy Pokemon in your party, and changes "
        .. "as soon as you reorder (SWITCH or long-press drag). OFF: pick it yourself with "
        .. "FOLLOWER in a Pokemon's menu." },
    { key = "perfMode", label = "PERFORMANCE", type = "choice", default = "balanced",
      choices = { { "BALANCED", "balanced" }, { "QUALITY", "quality" } },
      help = "BALANCED: frame rate held at 60 or below (the game itself runs at 60, so a "
        .. "120Hz screen was drawing every frame twice), voxel AA off, FOREST FX FULL as LOW. "
        .. "3D SPRITE DETAIL is left to you (4X is sharpest and costs the most). Cooler and longer battery. QUALITY: your own settings." },
    { key = "setupWizard", label = "SETUP WIZARD ON NEW GAME", type = "toggle", default = true,
      help = "Starting a NEW GAME opens the setup wizard (difficulty, Nuzlocke, look, battles, "
        .. "world, wild Pokemon, conveniences). It is always on the GEN2-AIO page too." },
    { key = "diagnostics", label = "DIAGNOSTICS", type = "toggle", default = false,
      help = "Show short status lines on screen (battle background errors, voxel edge, "
        .. "disk cache, Wilds). For reporting problems; leave off otherwise." },
    { key = "menuDim", label = "MENU DIM", type = "toggle", default = true,
      help = "Darken the world behind menus opened outside battle (START menu, PACK, "
        .. "party, Pokedex, PC, ...). Battle backgrounds are not affected." },
    { key = "voidFloor", label = "WORLD EDGE FILL", type = "toggle", default = true,
      help = "Past the edge of a map, keep repeating the map's own border (trees, water, "
        .. "wall) out to the horizon, like the original game, instead of a black void." },
    { key = "voidRelief", label = "VOXEL EDGE", type = "toggle", default = true,
      help = "gmarc: past the trees at a map's edge, continue the border as low voxel "
        .. "blocks (forest canopy, walls) for a band around the map before the flat "
        .. "WORLD EDGE FILL takes over. Built once per map, one draw call." },
    { key = "arenaCardDetail", label = "3D SPRITE DETAIL", type = "choice", default = 4,
      choices = { { "1X", 1 }, { "2X", 2 }, { "3X", 3 }, { "4X", 4 } },
      help = "How sharply KIM's HD Pokemon are captured for gmarc's 3D battles. "
        .. "Lower is lighter on phones." },
    { key = "arenaEnemySize", label = "ENEMY PKMN SIZE", type = "choice", default = 100,
      choices = { { "80%", 80 }, { "90%", 90 }, { "100%", 100 }, { "110%", 110 },
        { "120%", 120 }, { "130%", 130 }, { "140%", 140 }, { "150%", 150 },
        { "160%", 160 }, { "180%", 180 }, { "200%", 200 } },
      help = "Size of the opponent's Pokemon in 3D battles, grown in place on its spot." },
    { key = "arenaBackground", label = "BATTLE BACKGROUND", type = "choice", default = "kim_hd",
      choices = { { "DEFAULT (WHITE)", "white" }, { "KIM HD", "kim_hd" },
        { "KENNEY HD", "kenney" }, { "VOXEL WORLD", "voxel" } },
      visible_if = { key = "battleSprites", equals = true },
      help = "What KIM's battle Pokemon stand on. DEFAULT is the plain Crystal battle. "
        .. "KIM HD uses Kanto in Motion's painted backgrounds (download them from KIM's "
        .. "asset screen). KENNEY HD renders a painted 3D scene for the place, framed for "
        .. "a locked camera. VOXEL WORLD fights on the map itself." },
    { key = "arenaHud", label = "BATTLE HUD", type = "choice", default = "modern",
      choices = { { "MODERN", "modern" }, { "NATIVE", "native" } },
      help = "MODERN replaces Crystal's name / level / HP / EXP boxes with Kanto in "
        .. "Motion-styled cards using your Modern UI theme, font and size settings. "
        .. "NATIVE keeps the original tile HUD. Needs KIM's Modern battle UI on." },
    { key = "arenaCamera", label = "BATTLE CAMERA", type = "choice", default = "locked",
      choices = { { "LOCKED", "locked" }, { "FREE", "free" } },
      help = "LOCKED holds the 3D battle camera in place: no slow drift, and mouse, "
        .. "stick and zoom do not move it. FREE lets the camera drift and be steered." },
    { key = "hitFlicker", label = "HIT FLICKER", type = "choice", default = "steady",
      choices = { { "STEADY", "steady" }, { "FLICKER", "flicker" } },
      help = "STEADY: your Pokemon stays visible through the frame-long blanks inside some "
        .. "move animations. FLICKER: Crystal's original behaviour. Fly, Dig and fainting "
        .. "still hide the Pokemon either way." },
    { key = "arenaPlayerIntro", label = "PLAYER INTRO SPRITE", type = "toggle", default = true,
      help = "OFF hides your trainer's sprite that appears on the 3D battle stage "
        .. "during the battle-start animation. Your Pokemon still appears as normal." },
    { key = "arenaResolution", label = "3D BG RESOLUTION", type = "choice", default = "auto",
      choices = { { "AUTO", "auto" }, { "100%", "100" }, { "75%", "75" }, { "50%", "50" } },
      help = "Render size of the Kenney / Stadium scene. AUTO is full size on PC and capped on phones." },
    { key = "arenaShader", label = "3D BG STYLE", type = "choice", default = "stadium",
      choices = { { "STADIUM", "stadium" }, { "WATERCOLOR", "cel" } },
      help = "Stadium shading or the importer's watercolor manga finish for the scene." },
    { key = "arenaExtras", label = "3D BG EFFECTS", type = "choice", default = "on",
      choices = { { "ON", "on" }, { "LITE", "lite" }, { "OFF", "off" } },
      help = "Scene shadows and weather. LITE and OFF are faster on phones." },
    { key = "arenaWeather", label = "3D BG WEATHER", type = "choice", default = "off",
      choices = { { "OFF", "off" }, { "RAIN", "rain" }, { "THUNDERSTORM", "storm" } },
      help = "Cosmetic rain or storms in outdoor Kenney scenes." },
    -- 0.9.66 merged rows (see DERIVED_OPT): no default, so an untouched row
    -- keeps what the rows it replaced said
    { key = "repels", label = "REPELS", type = "choice",
      choices = { { "OFF", "off" }, { "ASK", "ask" }, { "AUTO", "auto" }, { "INFINITE", "infinite" } },
      help = "When a REPEL wears off. ASK: offer to use another. AUTO: use the next one "
        .. "from your bag by itself. INFINITE: a used REPEL never wears off (bends Nuzlocke "
        .. "rules). OFF: Crystal's own message only." },
    { key = "spriteAnim", label = "ANIMATED SPRITES", type = "choice",
      choices = { { "ON", "on" }, { "BATTLE ONLY", "battle" }, { "OFF", "off" } },
      help = "Kanto in Motion's animated Pokemon and trainers. BATTLE ONLY animates them in "
        .. "battle and holds menu sprites (party, summary, Pokedex) still." },
    { key = "kimHdAlign", label = "KIM HD BG ALIGN", type = "toggle", default = true,
      help = "Fit each KIM HD background so its painted ground spots sit under the "
        .. "Pokemon's feet. OFF uses a plain crop (see KIM HD BG OFFSET)." },
    { key = "kimHdFill", label = "KIM HD BG FILL", type = "choice", default = "nature",
      choices = { { "NATURE", "nature" }, { "BLACK", "black" }, { "WHITE", "white" } },
      help = "What fills the screen above and below a KIM HD background on tall screens. "
        .. "NATURE: the same scene, darkened. BLACK / WHITE: a solid colour." },
    { key = "kimHdOffset", label = "KIM HD BG OFFSET", type = "choice", default = 100,
      choices = offsetChoices,
      help = "How far down into a KIM HD background the crop starts (source pixels)." },
  }
  mergeDefine(realOptions, schema)

  -- In-game OPTIONS rows for the same settings (Battle Art 1.55's adapter,
  -- kept in lib/gen2_aio; it reads _kimArenaRowHidden on every menu build).
  local InGameOptions = loadOwn("lib/gen2_aio/ingame_options.lua")
  if type(InGameOptions) == "table" and InGameOptions.install then
    local installed, err = pcall(InGameOptions.install, mod, schema, "GEN2-AIO")
    if not installed then log("warn", "Gen2-AIO: in-game rows: %s", tostring(err)) end
  end

  -- Gen1Wild QOL (qol/): sprint, autosave, auto continue, sound, EXP share,
  -- move reminder, rematches, easy HMs, reusable TMs, area banners, menu
  -- layout and its mod menu. It runs its features through its own facade
  -- with per-feature setting prefixes; its follower, Gen151, Gen251 and
  -- Celebi are left out (qol/features.lua) in favour of the bundle's own.
  local qolOk = false
  if opt("qolMod", true) ~= false then
    local qol = subMod("qol")
    qol.find = find
    -- 0.9.66: REPEL PROMPT follows REPELS (only OFF silences it); MATCH
    -- LEVELS is dropped (TRAINER LEVELS covers rematches)
    rawset(qol, "_kimArenaQolLock", function(key)
      if key == "interact_qol_repel_prompt" then return repelsMode() ~= "off" end
      if key == "rematch_scale" then return false end
      return nil
    end)
    local before = {}
    for key in pairs(position) do before[key] = true end
    qolOk = runComponent("Wild QOL", qol, "qol/main.lua")
    mod.exports.qol = qol.exports
    -- the rows Gen1Wild QOL defined: the hub writes these through QOL's own
    -- store (some live under a shared id)
    local qolKeys = {}
    for key in pairs(position) do if not before[key] then qolKeys[key] = true end end
    rawset(mod, "_kimArenaQolKeys", qolKeys)
  end

  -- QoL Toggles 1.31.1 (qoltoggles/): ~40 switches, filed as rows of the
  -- ALL-IN-ONE hub's QOL TOGGLES page. Where it duplicates the bundle, the
  -- bundle's version wins and the toggle is held OFF with no row:
  --   RUN (HOLD B) -> Gen1Wild SPRINT      MAP LOCATION -> AREA BANNER
  --   UNLIMITED TMs -> REUSABLE TMS        FORGETTABLE HMs -> FORGET HM MOVES
  --   LAST ITEM (M) -> QUICK BALL (SELECT) MOUSE CAM LOCK -> BATTLE CAMERA
  -- EXP BAR only applies with BATTLE HUD = NATIVE (MODERN has its own bar).
  -- FULL HEAL CATCH ships OFF (Nuzlocke); the other run-easing toggles
  -- already ship OFF.
  local qtOk = false
  if opt("qolToggles", true) ~= false then
    local qt = namespaced(subMod("qoltoggles"), "qt_")
    qt.find = find
    -- 0.9.66: QUICK SHIP and BULK COINS removed (their NPC matching cannot
    -- work on Crystal). UNLIMITED TMs / FORGETTABLE HMs are back as REUSABLE
    -- TMS / FORGET HM MOVES (the Gen1Wild versions are Gen 1 only), OFF by
    -- default. INFINITE REPEL and AUTO-REPEL follow the bundle's REPELS row.
    local FORCED = { run_hold_b = false, map_location = false, mouse_cam_lock = false,
      last_item = false, quick_ssanne = false, bulk_coins = false }
    local DERIVED = {
      repel = function() return repelsMode() == "infinite" end,
      auto_repel = function() return repelsMode() == "auto" end,
      exp_bar = function()
        if opt("arenaHud", "modern") ~= "native" then return false end
        return nil
      end,
    }
    local DEFAULTS = { catch_heal = false, unlimited_tms = false, forgettable_hms = false }
    local LABELS = { unlimited_tms = "REUSABLE TMS", forgettable_hms = "FORGET HM MOVES" }
    local NUZ_WARN = { catch_heal = true, always_catch = true, perfect_dvs = true,
      instant_flee = true, b_to_run = true, heal_map_change = true, heal_battle = true,
      quick_nurse = true, turn_away_nurse = true, keep_money = true }
    local CYCLES = {}
    -- the host's word on a toggle's value (qoltoggles' sessionGet asks it
    -- last, so stored values pass through it too)
    local function hostValue(bare, v)
      if FORCED[bare] ~= nil then return FORCED[bare] end
      local derive = DERIVED[bare]
      if derive then
        local d = derive()
        if d ~= nil then return d end
      end
      local dec = CYCLES[bare]
      if dec and type(v) == "string" then
        if v == "off" then return false end
        local code = dec[v]
        if code ~= nil then return code end
        return tonumber(v) or v
      end
      if v == nil and DEFAULTS[bare] ~= nil then return DEFAULTS[bare] end
      return v
    end
    rawset(qt, "_kimArenaQtFilter", function(key, v)
      return hostValue((tostring(key):gsub("^qt_", "")), v)
    end)
    local innerGet = qt.options.get
    qt.options.get = function(self, key)
      local bare = (tostring(key):gsub("^qt_", ""))
      return hostValue(bare, innerGet(self, bare))
    end
    local qtErr
    qtOk, qtErr = pcall(function()
      local entry = chunk("qoltoggles/main.lua")(qt)
      if type(entry) == "function" then entry(qt) end
    end)
    if not qtOk then
      log("error", "Gen2-AIO: QoL Toggles failed to start: %s", tostring(qtErr))
      diagSet("qol toggles", "failed: " .. tostring(qtErr):sub(1, 120))
    end
    mod.exports.qolToggles = qt.exports
    local specs = qtOk and type(qt.exports) == "table" and qt.exports.toggleSpecs
    if type(specs) == "table" then
      local schema = {}
      for _, spec in ipairs(specs) do
        if type(spec) == "table" and FORCED[spec.key] == nil
            and spec.key ~= "repel" and spec.key ~= "auto_repel" then
          local help = (tostring(spec.gen2Help or spec.help or ""):gsub("[\n\v]", " "))
          if spec.key == "exp_bar" then help = help .. " Only with BATTLE HUD = NATIVE." end
          if NUZ_WARN[spec.key] and not help:find("Nuzlocke", 1, true) then
            help = help .. " Bends Nuzlocke rules."
          end
          local default = DEFAULTS[spec.key]
          if default == nil then default = spec.default end
          local row = { key = spec.key, label = LABELS[spec.key] or spec.gen2Label or spec.label,
            help = help }
          if type(spec.cycle) == "table" then
            local choices, dec = {}, {}
            for _, v in ipairs(spec.cycle) do
              local code = v == false and "off" or tostring(v)
              local okL, lbl = pcall(function()
                if spec.labelFor then return spec.labelFor(v) end
                return qt.exports.multLabel(v)
              end)
              choices[#choices + 1] = { tostring(okL and lbl or code):upper(), code }
              dec[code] = v
            end
            CYCLES[spec.key] = dec
            row.type, row.choices = "choice", choices
            row.default = (default == false or default == nil) and "off" or tostring(default)
          else
            row.type, row.default = "toggle", default ~= false
          end
          schema[#schema + 1] = row
        end
      end
      local okD, errD = pcall(qt.options.define, qt.options, schema)
      if not okD then log("warn", "Gen2-AIO: QoL Toggles rows: %s", tostring(errD)) end
      -- 0.9.33: defining options does not put them in Crystal's OPTION
      -- screen; the native rows adapter does (as for the bundle's own
      -- schema). Same rows, keys as stored ("qt_..."), on the main mod, so
      -- the hub files them on the QOL TOGGLES page.
      local rowsSchema = {}
      for i, row in ipairs(schema) do
        local copy = {}
        for k, v in pairs(row) do copy[k] = v end
        -- define() already renamed the row to "qt_<key>" in place; adding
        -- the prefix again stored every hub QoL Toggles switch as
        -- "qt_qt_<key>", which the component never read (0.9.59)
        copy.key = row.key:sub(1, 3) == "qt_" and row.key or ("qt_" .. row.key)
        rowsSchema[i] = copy
      end
      local IGO = loadOwn("lib/gen2_aio/ingame_options.lua")
      if type(IGO) == "table" and IGO.install then
        local okI, errI = pcall(IGO.install, mod, rowsSchema, "QOL TOGGLES")
        if not okI then log("warn", "Gen2-AIO: QoL Toggles in-game rows: %s", tostring(errI)) end
      end
      diagSet("qol toggles", ("%d switches"):format(#schema))
    end
  else
    -- QoL Toggles' engine wraps outlive a session (Android relaunches in the
    -- same Lua state); with the component off they must read every toggle
    -- as off rather than the previous session's settings.
    local okR, Runtime = pcall(require, "src.mods.Runtime")
    local live = okR and type(Runtime) == "table" and rawget(Runtime, "_qolTogglesLive")
    if type(live) == "table" then live.get = function() return false end end
  end

  -- KIM Touch (touch/): Dragon Quest-style touch controls.
  local touchOk = false
  do
    local touch = subMod("touch")
    touch.find = find
    touchOk = runComponent("KIM Touch", touch, "touch/main.lua")
    mod.exports.touch = touch.exports
  end

  -- MENU TRANSITIONS: Crystal's white menu fades -> short dark fades.
  local menuFadeFactory = loadOwn("lib/gen2_aio/menu_fade.lua")
  if type(menuFadeFactory) == "function" then pcall(menuFadeFactory, { mod = mod }) end

  -- ALL-IN-ONE hub: every component's settings, out of Crystal's OPTION.
  local hubFactory = loadOwn("lib/gen2_aio/hub.lua")
  if type(hubFactory) == "function" then
    local okH, err = pcall(hubFactory, { mod = mod, log = log })
    if not okH then log("warn", "Gen2-AIO: hub: %s", tostring(err)) end
  end

  -- Name sign + pokepic in 3D (gmarc's World:draw skipped them).
  local ovFactory = loadOwn("lib/gen2_aio/voxel_overlays.lua")
  if type(ovFactory) == "function" then
    local okV, err = pcall(ovFactory, { mod = mod, log = log })
    if not okV then log("warn", "Gen2-AIO: voxel overlays: %s", tostring(err)) end
  end

  -- FOLLOWER = PARTY LEAD (Wilds' follower tracks party slot 1 live).
  local leadFactory = loadOwn("lib/gen2_aio/follower_lead.lua")
  if type(leadFactory) == "function" then
    local okL, err = pcall(leadFactory, { mod = mod, diag = diagSet,
      wilds = function() return wildsOk and mod.exports.wilds or nil end })
    if not okL then log("warn", "Gen2-AIO: follower lead: %s", tostring(err)) end
  end

  -- CUSTOM UI THEME pickers (hub DISPLAY & UI page).
  local pickFactory = loadOwn("lib/gen2_aio/theme_picker.lua")
  if type(pickFactory) == "function" then
    local okP, err = pcall(pickFactory, { mod = mod })
    if not okP then log("warn", "Gen2-AIO: theme pickers: %s", tostring(err)) end
  end

  -- Nuzlocke RULES on a Modern UI page (START -> RULES, hub RULES page).
  local nzRulesFactory = loadOwn("lib/gen2_aio/nuz_rules.lua")
  if type(nzRulesFactory) == "function" and type(mod.exports.nuzlocke) == "table" then
    local okR, err = pcall(nzRulesFactory, { mod = mod, nz = mod.exports.nuzlocke })
    if not okR then log("warn", "Gen2-AIO: nuzlocke rules page: %s", tostring(err)) end
  end

  -- 0.9.67 SETUP WIZARD (NEW GAME and GEN2-AIO -> SETUP WIZARD)
  local wizardFactory = loadOwn("lib/gen2_aio/setup_wizard.lua")
  if type(wizardFactory) == "function" then
    local okW, err = pcall(wizardFactory, { mod = mod, diag = diagSet })
    if not okW then log("warn", "Gen2-AIO: setup wizard: %s", tostring(err)) end
  end

  -- 0.9.46 QUICK MENU (hold START / START -> QUICK), AREA DEX, DAY-CARE,
  -- TODAY, KEY ITEM WHEEL (hold SELECT) and the long-press info cards.
  local quickFactory = loadOwn("lib/gen2_aio/quick_menu.lua")
  if type(quickFactory) == "function" then
    local okQ, err = pcall(quickFactory, { mod = mod, diag = diagSet })
    if not okQ then log("warn", "Gen2-AIO: quick menu: %s", tostring(err)) end
  end

  -- Window-resolution overworld shortcuts and status.
  local overworldHudFactory = loadOwn("lib/gen2_aio/overworld_hud.lua")
  if type(overworldHudFactory) == "function" then
    local okH, err = pcall(overworldHudFactory, { mod = mod, diag = diagSet })
    if not okH then log("warn", "Gen2-AIO: overworld HUD: %s", tostring(err)) end
  end

  -- TIME OF DAY: one clock for palettes, sky, encounters and Wilds.
  local todFactory = loadOwn("lib/gen2_aio/time_of_day.lua")
  if type(todFactory) == "function" then
    local okT, made = pcall(todFactory, { mod = mod })
    if not okT then log("warn", "Gen2-AIO: time of day: %s", tostring(made))
    elseif type(made) == "table" and voxel then
      voxel._kimArenaHour = function() return made.hour() end
    end
  end

  -- HD Poke Balls in Crystal's ball animations.
  local ballFactory = loadOwn("lib/gen2_aio/hd_ball.lua")
  if type(ballFactory) == "function" then
    local okBall, err = pcall(ballFactory, { mod = mod, log = log })
    if not okBall then log("warn", "Gen2-AIO: HD ball: %s", tostring(err)) end
  end

  -- HIT FLICKER = STEADY for every battle renderer (engine seam).
  local steadyFactory = loadOwn("lib/gen2_aio/steady_hits.lua")
  if type(steadyFactory) == "function" then
    local okS, err = pcall(steadyFactory, { mod = mod, diag = diagSet })
    if not okS then log("warn", "Gen2-AIO: steady hits: %s", tostring(err)) end
  end

  -- Multi-hit moves animate every hit, as on the cart (engine seam).
  local multiHitFactory = loadOwn("lib/gen2_aio/multi_hit_anims.lua")
  if type(multiHitFactory) == "function" then
    local okH, err = pcall(multiHitFactory, { mod = mod, diag = diagSet })
    if not okH then log("warn", "Gen2-AIO: multi-hit anims: %s", tostring(err)) end
  end

  -- Pixel Operator for KIM's Modern UI.
  local fontFactory = loadOwn("lib/gen2_aio/font.lua")
  if type(fontFactory) == "function" then
    local okF, err = pcall(fontFactory, { mod = mod })
    if not okF then log("warn", "Gen2-AIO: font: %s", tostring(err)) end
  end

  -- Per-screen overworld ZOOM (outer / inner screen of a Fold).
  local pagesFactory = loadOwn("lib/gen2_aio/modern_pages.lua")
  if type(pagesFactory) == "function" then pagesFactory({ mod = mod }) end
  local tradeFactory = loadOwn("lib/gen2_aio/modern_trade.lua")
  if type(tradeFactory) == "function" then tradeFactory({ mod = mod }) end
  local callerFactory = loadOwn("lib/gen2_aio/modern_caller.lua")
  if type(callerFactory) == "function" then callerFactory({ mod = mod }) end
  local zoomFactory = loadOwn("lib/gen2_aio/screen_zoom.lua")
  if type(zoomFactory) == "function" then
    local okZ, err = pcall(zoomFactory, { mod = mod })
    if not okZ then log("warn", "Gen2-AIO: screen zoom: %s", tostring(err)) end
  end

  -- Quick Poke Ball on SELECT (wild battles, command menu only).
  local quickFactory = loadOwn("lib/gen2_aio/quick_ball.lua")
  if type(quickFactory) == "function" then
    local okQ, err = pcall(quickFactory, { mod = mod })
    if not okQ then log("warn", "Gen2-AIO: quick ball: %s", tostring(err)) end
  end

  -- Lore-friendly weather (battle moves, places, random rain).
  local weatherFactory = loadOwn("lib/gen2_aio/weather.lua")
  if type(weatherFactory) == "function" then
    local okW, err = pcall(weatherFactory, { mod = mod })
    if not okW then log("warn", "Gen2-AIO: weather: %s", tostring(err)) end
  end

  -- WILDS NPC POKEMON: Crystal's Pokemon object events in Wilds' sprite set.
  local npcMonFactory = loadOwn("lib/gen2_aio/npc_mons.lua")
  if type(npcMonFactory) == "function" then
    local okM, err = pcall(npcMonFactory, { mod = mod, diag = diagSet,
      wilds = function() return wildsOk and mod.exports.wilds or nil end })
    if not okM then log("warn", "Gen2-AIO: npc mons: %s", tostring(err)) end
  end

  -- Overworld menu dim (any menu open outside battle).
  local dimFactory = loadOwn("lib/gen2_aio/menu_dim.lua")
  if type(dimFactory) == "function" then
    local okD, err = pcall(dimFactory, { mod = mod })
    if not okD then log("warn", "Gen2-AIO: menu dim: %s", tostring(err)) end
  end

  -- DIAGNOSTICS overlay
  mod.hooks:wrap("render.hud", function(nextFn, game, viewport)
    local r = { nextFn(game, viewport) }
    if opt("diagnostics", false) == true then
      pcall(function()
        diagSet("wilds", wildsOk and "running" or "not running")
        local G = love.graphics
        G.push("all"); G.origin()
        local f = G.getFont()
        local y = 230
        -- 0.9.26: long lines wrap to the screen (the Fold's outer screen cut
        -- the npc mons line off)
        local maxW = math.max(80, G.getWidth() - 34)
        for _, k in ipairs(diagOrder) do
          local line = k .. ": " .. tostring(diagLines[k])
          local _, parts = f:getWrap(line, maxW)
          if type(parts) ~= "table" or #parts == 0 then parts = { line } end
          for i, part in ipairs(parts) do
            if i > 1 then part = "  " .. part end
            G.setColor(0, 0, 0, 0.65); G.rectangle("fill", 8, y - 2, f:getWidth(part) + 12, f:getHeight() + 4)
            G.setColor(1, 1, 0.6, 1); G.print(part, 14, y)
            y = y + f:getHeight() + (i < #parts and 2 or 6)
          end
        end
        G.pop()
      end)
    end
    return unpack(r)
  end, 5)

  -- Bring the VOXEL ENGINE row in line with the engine that actually loaded.
  local engineRowSynced = false
  local okFC, FrameCap = pcall(require, "src.core.FrameCap")
  local fpsClamped, perfDiagAt = false, 0
  mod.hooks:wrap("render.hud", function(nextFn, game, viewport)
    -- PERFORMANCE: hold the render rate at 60 or below (render-only; game
    -- logic is fixed-step at 60). QUALITY restores the MAX FPS option.
    pcall(function()
      if not (okFC and type(FrameCap) == "table" and FrameCap.apply) then return end
      local cur = FrameCap.current
      if perfBalanced() then
        if cur == FrameCap.DISPLAY or (tonumber(cur) or 0) > 60 then
          FrameCap.apply(60); fpsClamped = true
        end
      elseif fpsClamped then
        fpsClamped = false
        local o = type(game) == "table" and ((game.save and game.save.options) or game.options) or {}
        FrameCap.apply(o.fpsCap)
      end
      if opt("diagnostics", false) == true and love.timer then
        local now = love.timer.getTime()
        if now - perfDiagAt > 1 then
          perfDiagAt = now
          -- 0.9.42: the GPU too (PowerVR / Adreno / Mali / Xclipse ...)
          local okR, _, _, vendor, device = pcall(love.graphics.getRendererInfo)
          local gpu = okR and tostring(device or vendor or "?"):sub(1, 40) or "?"
          diagSet("perf", ("%s, cap %s, %d fps, %s"):format(perfBalanced() and "BALANCED" or "QUALITY",
            FrameCap.current == FrameCap.DISPLAY and "DISPLAY" or tostring(FrameCap.current),
            love.timer.getFPS(), gpu))
        end
      end
    end)
    if not engineRowSynced and type(game) == "table" then
      engineRowSynced = true
      pcall(function()
        for _, bucketOwner in ipairs({ game.options, game.save and game.save.options, game.mods }) do
          local all = type(bucketOwner) == "table" and bucketOwner.modOptions
          if type(all) == "table" then
            all[ID] = all[ID] or {}
            all[ID].voxelEngine = engine
          end
        end
      end)
    end
    return nextFn(game, viewport)
  end, 3)

  log("info", "Gen2-AIO ready (voxel=%s:%s, wilds=%s, nuzlocke=%s, touch=%s, qol=%s, qoltoggles=%s, background=%s)",
    engine, tostring(voxelOk), tostring(wildsOk), tostring(nuzlockeOk), tostring(touchOk),
    tostring(qolOk), tostring(qtOk), tostring(mode()))
end
