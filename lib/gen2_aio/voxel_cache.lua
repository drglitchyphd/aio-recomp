-- gen2-aio 0.9.77: BUILD 3D CACHE.
--
-- With the 3D world on, every area is built the first time you enter it --
-- seconds on a phone for a big route -- and kept in the VOXEL DISK CACHE
-- after that. This builds every area into that cache in one go
-- (gmarc/lib/CacheBuilder.lua), so no area ever builds during play:
--
--   * a one-time question once you are out in the world (BUILD NOW / LATER
--     / DON'T ASK AGAIN); LATER asks again the next time the game starts,
--     and once a full build has finished it is not asked again until a
--     voxel update makes the cache stale;
--   * GEN2-AIO > ADVANCED > BUILD 3D CACHE, any time.
--
-- The build runs on its own page with the progress and STOP; leaving the
-- page stops it, and the next run skips every area already on storage.
return function(host)
  local mod, diag = host.mod, host.diag or function() end
  local Hub = rawget(mod, "_kimArenaHub")
  if not (Hub and Hub.page and Hub.read and Hub.write) then return nil end

  local function lib()
    local ex = mod.exports and mod.exports.voxel
    return type(ex) == "table" and type(ex.lib) == "table" and ex.lib or nil
  end
  local function voxelModule(name)
    local V = lib()
    if not V then return nil end
    local ok, m = pcall(V.require, name)
    return ok and type(m) == "table" and m or nil
  end
  local function worldOf(game)
    return game and (game.world or game.overworld) or nil
  end
  -- the voxel build the cache files belong to (main.lua's _kimArenaBuildId)
  local function buildId()
    local V = lib()
    local fn = V and V.mod and rawget(V.mod, "_kimArenaBuildId")
    local ok, id = false, nil
    if type(fn) == "function" then ok, id = pcall(fn) end
    return ok and tostring(id) or "dev"
  end
  local function usable(game)
    local CB, world = voxelModule("CacheBuilder"), worldOf(game)
    if not (CB and world) then return false end
    local ok, yes = pcall(CB.available, world)
    return ok and yes == true
  end

  local VC = {}
  local run = nil       -- { builder, page, game } while a build page is open

  local function percent(b) return math.floor(b:progress() * 100 + 0.5) end
  local function closePage(game, page)
    local stack = game and game.stack
    local states = stack and stack.states
    if type(states) == "table" and states[#states] == page then stack:pop() end
  end

  function VC.open(game)
    local CB = voxelModule("CacheBuilder")
    if not (CB and usable(game)) then return nil end
    if run then pcall(run.builder.stop, run.builder) end
    local builder = CB.new(worldOf(game))
    local r = { builder = builder, game = game }
    local rows = {
      { id = "kimArena.vc.progress", label = "PROGRESS",
        help = "Every area's 3D scene is being built and saved. Keep the game open; "
          .. "you can stop any time and carry on later from where you left off.",
        value = function()
          if builder.done then return "DONE" end
          return ("%d%%  %d/%d"):format(percent(builder), math.max(0, builder.index - 1), builder.total)
        end,
        activate = function() end },
      { id = "kimArena.vc.counts", label = "NEW / ALREADY SAVED",
        help = "Areas built by this run, and areas that were already in the cache.",
        value = function() return ("%d / %d"):format(builder.built, builder.skipped) end,
        activate = function() end },
      { id = "kimArena.vc.stop", label = "STOP",
        help = "Stop building. Areas already saved stay saved; BUILD 3D CACHE carries on from there.",
        value = function() return builder.done and "CLOSE" or nil end,
        activate = function(g) closePage(g or game, r.page) end },
    }
    local page = Hub.page(game, rows, "BUILD 3D CACHE")
    if not page then return nil end
    page.kimSubtitle = "3D WORLD"
    r.page = page
    -- the page's own update drives the build, ~30 ms a frame
    local baseUpdate = page.update
    page.update = function(self, dt, ...)
      if not builder.done then
        local okS, finished = pcall(builder.step, builder, 0.03)
        if not okS then
          diag("voxel cache", "build stopped: " .. tostring(finished))
          builder:stop()
        elseif finished and not builder.off and builder.index > builder.total then
          Hub.write(game, "voxelCacheDone", buildId())
          diag("voxel cache", ("done: %d built, %d already saved, %d skipped"):format(
            builder.built, builder.skipped, builder.failed))
          -- 0.9.85: what the build used goes back now (one full collect on
          -- this page, not mid-walk), and the page says to restart: a game
          -- restart is the one sure way to start the session lean, and a
          -- mod cannot restart the game itself
          collectgarbage("collect")
          local done = {
            { id = "kimArena.vc.done", label = "FINISHED",
              help = "Every area's 3D scene is saved. Areas now load from storage instead of building.",
              value = function() return ("%d NEW / %d SAVED"):format(builder.built, builder.skipped) end,
              activate = function() end },
            { id = "kimArena.vc.restart", label = "RESTART RECOMMENDED",
              help = "SAVE your game, then close and reopen it so the cache is used from a fresh start "
                .. "(the game cannot restart itself).",
              value = function() return "SAVE + REOPEN" end,
              activate = function() end },
            { id = "kimArena.vc.close", label = "CLOSE",
              help = "Back to the game.",
              activate = function(g) closePage(g or game, r.page) end },
          }
          self.rows = done
          self.view = {}
          for i, row in ipairs(done) do self.view[i] = row end
          self.view[#self.view + 1] = { label = "BACK", cancel = true, id = "cancel" }
          self.index = 2   -- the restart row, so its help line is the one showing
          self.scroll = 0
        end
      end
      if baseUpdate then return baseUpdate(self, dt, ...) end
    end
    run = r
    return page
  end

  -- BUILD 3D CACHE in GEN2-AIO > ADVANCED. 0.9.82: always listed while the
  -- 3D engine is loaded; when a build cannot run, the row says OFF and why
  -- (it used to vanish, which read as "missing")
  local function whyNot(game)
    local CB = voxelModule("CacheBuilder")
    if not CB then return "the 3D world is not loaded" end
    if type(CB.whyNot) ~= "function" then return (usable(game) and nil) or "the disk cache is off" end
    local ok, why = pcall(CB.whyNot, worldOf(game))
    if not ok then return tostring(why) end
    return why
  end
  local BUILD_HELP = "Build every area's 3D scene now and keep it on storage, so no area has to "
    .. "build while you play. Takes a few minutes; you can stop and carry on later."
  Hub.extras.voxelCache = function(game)
    if not voxelModule("CacheBuilder") then return {} end
    local why = whyNot(game)
    local row = { id = "gen2-aio:voxel_cache", label = "BUILD 3D CACHE" }
    if why then
      row.help = "Not available: " .. why .. "."
        .. (why:find("VOXEL DISK CACHE", 1, true) and " Turn it ON above to use this." or "")
      row.value = function() return "OFF" end
      row.activate = function() end
    else
      row.help = BUILD_HELP
      row.value = function() return Hub.read("voxelCacheDone") == buildId() and "BUILT" or nil end
      row.activate = function(g) VC.open(g or game) end
    end
    return { row }
  end

  -- the one-time question, once the player has been free in the world a moment
  local asked, freeFor = false, 0
  local function shouldAsk(game)
    if Hub.read("voxelCacheAsk") == false or Hub.read("voxelDiskCache") == false then return false end
    if Hub.read("voxelCacheDone") == buildId() then return false end
    local Voxel = voxelModule("VoxelState")
    if not (Voxel and type(Voxel.active) == "function" and Voxel.active()) then return false end
    return usable(game)
  end
  function VC.ask(game)
    asked = true
    local rows = {
      { id = "kimArena.vc.now", group = true, label = "BUILD NOW",
        help = "Build every area's 3D scene now (a few minutes; keep the game open). "
          .. "After that no area builds while you play.",
        activate = function(g)
          g = g or game
          closePage(g, rawget(mod, "_kimArenaVcAsk"))
          VC.open(g)
        end },
      { id = "kimArena.vc.later", group = true, label = "LATER",
        help = "Ask again the next time the game starts.",
        activate = function(g) closePage(g or game, rawget(mod, "_kimArenaVcAsk")) end },
      { id = "kimArena.vc.never", group = true, label = "DON'T ASK AGAIN",
        help = "Areas build the first time you visit them, as before. "
          .. "BUILD 3D CACHE is always in GEN2-AIO > ADVANCED.",
        activate = function(g)
          g = g or game
          Hub.write(g, "voxelCacheAsk", false)
          closePage(g, rawget(mod, "_kimArenaVcAsk"))
        end },
    }
    local page = Hub.page(game, rows, "BUILD 3D CACHE?")
    if page then page.kimSubtitle = "3D WORLD" end
    rawset(mod, "_kimArenaVcAsk", page)
    return page
  end

  mod.hooks:wrap("core.update", function(nextFn, game, dt, ...)
    local result = { nextFn(game, dt, ...) }
    -- a build page that was left (B / BACK / STOP) stops its build
    if run and not run.builder.done then
      local states = run.game and run.game.stack and run.game.stack.states
      local open = false
      for _, s in ipairs(type(states) == "table" and states or {}) do
        if s == run.page then open = true; break end
      end
      if not open then pcall(run.builder.stop, run.builder); run = nil end
    end
    if not asked then
      local Quick = rawget(mod, "_kimArenaQuick")
      local free = Quick and type(Quick.overworld) == "function" and Quick.overworld(game)
      freeFor = free and (freeFor + (tonumber(dt) or 0)) or 0
      if freeFor > 2 then
        local okA, want = pcall(shouldAsk, game)
        if okA and want then pcall(VC.ask, game) else asked = true end
      end
    end
    return (table.unpack or unpack)(result)
  end)

  mod._kimArenaVoxelCache = VC
  return VC
end
