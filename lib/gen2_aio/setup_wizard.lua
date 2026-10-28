-- gen2-aio 0.9.67: SETUP WIZARD.
--
-- A handful of plain questions instead of nine pages of settings: pick a
-- ready-made profile (RECOMMENDED, CASUAL, NUZLOCKE, ...) or go step by step
-- through DIFFICULTY, NUZLOCKE, LOOK, BATTLES, WORLD, WILD POKEMON and
-- CONVENIENCE. Each step offers three to six choices, each a preset of the
-- settings behind it, with the one that matches the current settings marked.
-- Nothing changes until FINISH, so B backs out of the whole thing safely.
--
-- Opened from:
--   * NEW GAME on the title screen (setting SETUP WIZARD ON NEW GAME, on by
--     default). FINISH then starts the game; Nuzlocke choices go to the run
--     NEW GAME is about to create.
--   * GEN2-AIO -> SETUP WIZARD at any time, to switch presets mid-game.
--     Nuzlocke choices then apply to the current run (unless LOCK RULES).
--
-- Every page is the hub's Modern UI OPTION page (Hub.page), so it is themed
-- and tappable like the rest of the settings.
return function(host)
  local mod, diag = host.mod, host.diag or function() end
  local Hub = rawget(mod, "_kimArenaHub")
  if not (Hub and Hub.page and Hub.read and Hub.write) then return nil end

  local function exportsOf(name)
    local ex = mod.exports and mod.exports[name]
    return type(ex) == "table" and ex or nil
  end

  -- ---- the voxel world is a render pipeline, not a mod option
  local function voxelLabel()
    local okP, P = pcall(require, "src.render.Pipelines")
    if not (okP and type(P) == "table" and P.get and P.get("voxel")) then return nil end
    local okL, label = pcall(P.levelLabel, "voxel", P.level("voxel"))
    return okL and label or nil
  end
  local function setVoxel(game, label)
    local okP, P = pcall(require, "src.render.Pipelines")
    if not (okP and type(P) == "table" and P.get and P.get("voxel")) then return end
    local okL, labels = pcall(P.levelLabels, "voxel")
    if not (okL and type(labels) == "table") then return end
    for i, l in ipairs(labels) do
      if l == label then
        P.setLevel("voxel", i - 1)
        local opts = game and ((game.save and game.save.options) or game.options)
        pcall(P.syncOptions, opts)
        if game and game.writeOptions then pcall(game.writeOptions, game) end
        return
      end
    end
  end

  -- ---- Nuzlocke, through its own rules store
  local function nuzlocke() return exportsOf("nuzlocke") end
  local function nzRead(key, preGame)
    local nz = nuzlocke()
    if not (nz and nz.getRuleFor) then return nil end
    local ok, v = pcall(nz.getRuleFor, key, preGame)
    return ok and v or nil
  end
  local function nzLocked(preGame)
    return not preGame and nzRead("rules_locked", false) == true
  end
  -- 0 off, 1 NUZLOCKE, 2 HARDCORE, 3 SOLO (Nuzlocke's own Locke presets)
  local function nzMode(preGame)
    if nzRead("nuzlocke_enabled", preGame) == false then return "off" end
    local t = tonumber(nzRead("locke_type", preGame)) or 0
    return ({ [1] = "nuzlocke", [2] = "hardcore", [3] = "solo" })[t] or "custom"
  end
  local function nzApply(mode, preGame)
    local nz = nuzlocke()
    if not (nz and nz.setRuleFor and nz.applyLockePreset) or nzLocked(preGame) then return end
    if mode == "off" then
      pcall(nz.setRuleFor, "nuzlocke_enabled", false, preGame)
    else
      local n = ({ nuzlocke = 1, hardcore = 2, solo = 3 })[mode]
      if n then pcall(nz.applyLockePreset, n, preGame) end
    end
  end

  local setFollowers
  -- ---- the steps. `set` is a preset of settings; `apply` does anything a
  -- plain setting cannot; `is` says whether the current settings match.
  local STEPS = {
    { id = "difficulty", title = "DIFFICULTY", choices = {
      { id = "easy", label = "EASY",
        help = "Trainers stay a few levels under your team. 1.5x EXP. Moves show SUPER / WEAK hints in battle.",
        set = { trainerLevels = "matchm5", qt_exp_mult = "1.5", moveEffectHint = true } },
      { id = "normal", label = "NORMAL", recommended = true,
        help = "Each trainer's strongest Pokemon matches your strongest, so battles stay a fair fight all game. Normal EXP.",
        set = { trainerLevels = "match", qt_exp_mult = "off", moveEffectHint = false } },
      { id = "hard", label = "HARD",
        help = "Each trainer's strongest Pokemon is 2 levels above your strongest. Normal EXP, no move hints.",
        set = { trainerLevels = "match2", qt_exp_mult = "off", moveEffectHint = false } },
      { id = "classic", label = "CLASSIC",
        help = "Crystal's own trainer levels and EXP, as on the cartridge.",
        set = { trainerLevels = "off", qt_exp_mult = "off", moveEffectHint = false } },
    } },
    { id = "nuzlocke", title = "NUZLOCKE",
      available = function(ctx) return nuzlocke() ~= nil and not nzLocked(ctx.preGame) end,
      current = function(ctx) return nzMode(ctx.preGame) end,
      choices = {
      { id = "off", label = "OFF", recommended = true,
        help = "A normal playthrough: no Nuzlocke rules.",
        apply = function(_, ctx) nzApply("off", ctx.preGame) end },
      { id = "nuzlocke", label = "NUZLOCKE",
        help = "The classic rules: a fainted Pokemon is gone for good, only the first Pokemon in each area may be caught, and every catch gets a nickname.",
        apply = function(_, ctx) nzApply("nuzlocke", ctx.preGame) end },
      { id = "hardcore", label = "HARDCORE",
        help = "NUZLOCKE plus level caps through the Champion and no healing or X items in battle.",
        apply = function(_, ctx) nzApply("hardcore", ctx.preGame) end },
      { id = "solo", label = "SOLO",
        help = "NUZLOCKE with a single Pokemon: if your one active Pokemon faints, the run is over.",
        apply = function(_, ctx) nzApply("solo", ctx.preGame) end },
    } },
    { id = "look", title = "LOOK", choices = {
      { id = "crystal", label = "CRYSTAL", recommended = true,
        help = "Modern menus in Crystal's blue and silver.",
        set = { gen2IntegratedModernUi = true, gen2UiTheme = "gen2_aio:crystal" } },
      { id = "heartgold", label = "HEARTGOLD",
        help = "Modern menus in HeartGold's warm gold.",
        set = { gen2IntegratedModernUi = true, gen2UiTheme = "gen2_aio:heartgold" } },
      { id = "johto_night", label = "JOHTO NIGHT",
        help = "Modern menus in a dark night-sky theme, easy on the eyes.",
        set = { gen2IntegratedModernUi = true, gen2UiTheme = "gen2_aio:johto_night" } },
      { id = "gen3", label = "GEN 3",
        help = "Modern menus styled after FireRed / LeafGreen.",
        set = { gen2IntegratedModernUi = true, gen2UiTheme = "gen2_aio:gen3" } },
      { id = "original", label = "ORIGINAL",
        help = "Crystal's own Game Boy menus and text boxes.",
        set = { gen2IntegratedModernUi = false } },
    } },
    { id = "battles", title = "BATTLES", choices = {
      { id = "hd", label = "HD + PAINTED", recommended = true,
        help = "Animated HD Pokemon on painted backgrounds for each place. (HD art downloads from GEN2-AIO > ADVANCED > ASSET MANAGER.)",
        set = { battleSprites = true, gen2MenuSpriteSource = "kim", spriteAnim = "on",
          arenaBackground = "kim_hd" } },
      { id = "hd3d", label = "HD + 3D SCENES",
        help = "Animated HD Pokemon in a 3D scene of the place. Looks best; uses the most battery.",
        set = { battleSprites = true, gen2MenuSpriteSource = "kim", spriteAnim = "on",
          arenaBackground = "kenney" } },
      { id = "hdstill", label = "HD, LIGHTER",
        help = "HD Pokemon on painted backgrounds, animated only in battle. Easier on older phones and the battery.",
        set = { battleSprites = true, gen2MenuSpriteSource = "kim", spriteAnim = "battle",
          arenaBackground = "kim_hd" } },
      { id = "original", label = "ORIGINAL",
        help = "Crystal's own Pokemon sprites and plain battle screen.",
        set = { battleSprites = false, gen2MenuSpriteSource = "vanilla", spriteAnim = "off" } },
    } },
    { id = "world", title = "WORLD",
      available = function() return voxelLabel() ~= nil end,
      current = function()
        local l = voxelLabel()
        if l == "FULL" then return "diorama" elseif l == "OFF" then return "classic"
        elseif l == "50" then return "tilted" end
        return nil
      end,
      choices = {
      { id = "diorama", label = "3D DIORAMA", recommended = true,
        help = "The overworld in 3D, framed like a tabletop model.",
        apply = function(game) setVoxel(game, "FULL") end },
      { id = "tilted", label = "3D TILTED",
        help = "The overworld in 3D with the camera tilted toward the horizon.",
        apply = function(game) setVoxel(game, "50") end },
      { id = "classic", label = "CLASSIC 2D",
        help = "Crystal's own top-down overworld.",
        apply = function(game) setVoxel(game, "OFF") end },
    } },
    { id = "wild", title = "WILD POKEMON",
      available = function() return exportsOf("wilds") ~= nil end,
      current = function()
        if Hub.read("wok_enabled") == false then return "classic" end
        local n = tonumber(Hub.read("wok_follower_count")) or 0
        return n > 0 and "follow" or "visible"
      end,
      choices = {
      { id = "follow", label = "SEEN + FOLLOWER", recommended = true,
        help = "Wild Pokemon roam where you can see them, and your lead Pokemon walks behind you.",
        apply = function(game) Hub.write(game, "wok_enabled", true); setFollowers(game, 1) end },
      { id = "visible", label = "SEEN, NO FOLLOWER",
        help = "Wild Pokemon roam where you can see them. No follower.",
        apply = function(game) Hub.write(game, "wok_enabled", true); setFollowers(game, 0) end },
      { id = "classic", label = "CLASSIC",
        help = "Crystal's hidden random encounters in grass, caves and water. No follower.",
        apply = function(game)
          Hub.write(game, "wok_enabled", false); Hub.write(game, "wok_random_encounters", true)
          setFollowers(game, 0)
        end },
    } },
    { id = "qol", title = "CONVENIENCE", choices = {
      { id = "classic", label = "CLASSIC",
        help = "As on the cartridge: no running, single-use TMs, HMs from the party menu, the full nurse speech.",
        set = { sprint_enabled = false, repels = "off", interact_qol_easy_interactions = false,
          qt_field_moves_all = false, qt_quick_nurse = false, qt_instant_text = false,
          qt_hold_to_scroll = false, qt_unlimited_tms = false, qt_forgettable_hms = false,
          qt_auto_cut = false, qt_bulk_mart = false } },
      { id = "standard", label = "STANDARD", recommended = true,
        help = "Run with B, press A on a tree or boulder to use its HM, and get offered another REPEL when one wears off. TMs stay single-use.",
        set = { sprint_enabled = true, repels = "ask", interact_qol_easy_interactions = true,
          qt_field_moves_all = true, qt_quick_nurse = false, qt_instant_text = false,
          qt_hold_to_scroll = false, qt_unlimited_tms = false, qt_forgettable_hms = false,
          qt_auto_cut = false, qt_bulk_mart = false } },
      { id = "max", label = "MAXIMUM",
        help = "STANDARD plus instant text, quick nurse, REPELS used automatically, reusable TMs, forgettable HMs, auto CUT and buying in bulk. (Some bend Nuzlocke rules.)",
        set = { sprint_enabled = true, repels = "auto", interact_qol_easy_interactions = true,
          qt_field_moves_all = true, qt_quick_nurse = true, qt_instant_text = true,
          qt_hold_to_scroll = true, qt_unlimited_tms = true, qt_forgettable_hms = true,
          qt_auto_cut = true, qt_bulk_mart = true } },
    } },
  }
  setFollowers = function(game, n)
    local wilds = exportsOf("wilds")
    if wilds and type(wilds.setFollowerCount) == "function" then
      pcall(wilds.setFollowerCount, game, n)
    else
      Hub.write(game, "wok_follower_count", n)
    end
  end

  -- ready-made answers to every step (nil = leave that step as it is)
  local PROFILES = {
    { id = "recommended", label = "RECOMMENDED",
      help = "The way Gen2-AIO is meant to be played: fair trainers, no Nuzlocke, HD battles, the 3D world, visible wild Pokemon and the standard conveniences.",
      pick = { difficulty = "normal", nuzlocke = "off", battles = "hd", world = "diorama",
        wild = "follow", qol = "standard" } },
    { id = "casual", label = "CASUAL",
      help = "Relaxed: easier trainers, more EXP and every convenience.",
      pick = { difficulty = "easy", nuzlocke = "off", battles = "hd", world = "diorama",
        wild = "follow", qol = "max" } },
    { id = "nuzlocke", label = "NUZLOCKE",
      help = "A classic Nuzlocke run with fair trainers and the standard conveniences.",
      pick = { difficulty = "normal", nuzlocke = "nuzlocke", battles = "hd", world = "diorama",
        wild = "follow", qol = "standard" } },
    { id = "hardcore", label = "HARDCORE NUZLOCKE",
      help = "HARD trainers and HARDCORE Nuzlocke rules: level caps, no items in battle.",
      pick = { difficulty = "hard", nuzlocke = "hardcore", battles = "hd", world = "diorama",
        wild = "follow", qol = "standard" } },
    { id = "classic", label = "CLASSIC CRYSTAL",
      help = "As close to the cartridge as it gets: original menus, sprites, levels and 2D overworld.",
      pick = { difficulty = "classic", nuzlocke = "off", look = "original", battles = "original",
        world = "classic", wild = "classic", qol = "classic" } },
  }

  local function stepById(id)
    for _, s in ipairs(STEPS) do if s.id == id then return s end end
    return nil
  end
  local function choiceById(step, id)
    for _, c in ipairs(step.choices) do if c.id == id then return c end end
    return nil
  end
  local function same(a, b)
    if a == b then return true end
    return tostring(a) == tostring(b)
  end
  -- the choice that matches the settings as they are now, if any
  local function currentChoice(step, ctx)
    if step.current then
      local ok, id = pcall(step.current, ctx)
      return ok and id or nil
    end
    for _, c in ipairs(step.choices) do
      if c.set then
        local all = true
        for key, value in pairs(c.set) do
          if not same(Hub.read(key), value) then all = false; break end
        end
        if all then return c.id end
      end
    end
    return nil
  end
  local function stepsFor(ctx)
    local out = {}
    for _, s in ipairs(STEPS) do
      local ok, avail = true, true
      if s.available then ok, avail = pcall(s.available, ctx) end
      if ok and avail then out[#out + 1] = s end
    end
    return out
  end

  -- ---- applying
  local function applyAll(game, ctx)
    local applied = {}
    for _, step in ipairs(stepsFor(ctx)) do
      local id = ctx.picks[step.id]
      local c = id and choiceById(step, id)
      if c then
        for key, value in pairs(c.set or {}) do Hub.write(game, key, value) end
        if c.apply then pcall(c.apply, game, ctx) end
        applied[#applied + 1] = step.id .. "=" .. c.id
      end
    end
    if ctx.preGame then
      local nz = nuzlocke()
      if nz and nz.stageNewGame then pcall(nz.stageNewGame) end
    end
    diag("setup wizard", #applied > 0 and table.concat(applied, " ") or "no changes")
    return applied
  end

  -- ---- pages
  local function closeWizard(game)
    local stack = game and game.stack
    local states = stack and stack.states
    for _ = 1, 32 do
      local top = type(states) == "table" and states[#states] or nil
      if not (type(top) == "table" and rawget(top, "_kimWizard")) then break end
      stack:pop()
    end
  end
  local function push(game, rows, title, subtitle)
    local page = Hub.page(game, rows, title)
    if page then
      page._kimWizard = true
      page.kimSubtitle = subtitle
    end
    return page
  end
  local function refresh(page, rows)
    if type(page) ~= "table" then return end
    local was = page.view and page.view[page.index or 1]
    page.rows = rows
    page.view = {}
    for i, r in ipairs(rows) do page.view[i] = r end
    page.view[#page.view + 1] = { label = "BACK", cancel = true, id = "cancel" }
    for i, r in ipairs(page.view) do
      if was and r.id == was.id then page.index = i; break end
    end
    if (page.index or 1) > #page.view then page.index = #page.view end
  end

  local openSummary
  -- one step's page. `after(choiceId)` runs once a choice is made.
  local function openStep(game, ctx, step, index, total, after)
    local cur = currentChoice(step, ctx)
    local rows = {}
    for _, c in ipairs(step.choices) do
      local row = { id = "kimArena.wiz." .. step.id .. "." .. c.id, group = true,
        label = c.label, help = c.help }
      row.value = function()
        local picked = ctx.picks[step.id]
        if picked == c.id then return "CHOSEN" end
        if picked == nil and cur == c.id then return "CURRENT" end
        if c.recommended then return "SUGGESTED" end
        return ""
      end
      row.activate = function(g)
        ctx.picks[step.id] = c.id
        after(g or game, c.id)
      end
      rows[#rows + 1] = row
    end
    rows[#rows + 1] = { id = "kimArena.wiz." .. step.id .. ".keep", group = true,
      label = "KEEP AS IS", help = "Leave these settings exactly as they are now.",
      activate = function(g) ctx.picks[step.id] = nil; after(g or game, nil) end }
    local sub = index and ("STEP " .. index .. " OF " .. total) or "SETUP"
    return push(game, rows, step.title, sub)
  end

  local function stepLabel(step, ctx)
    local id = ctx.picks[step.id]
    if id then
      local c = choiceById(step, id)
      return c and c.label or id
    end
    local cur = currentChoice(step, ctx)
    local c = cur and choiceById(step, cur)
    return "KEEP" .. (c and (" (" .. c.label .. ")") or "")
  end

  -- the review page: every step's answer, tap one to change it, FINISH
  function openSummary(game, ctx)
    local page
    local function rows()
      local out = {}
      for _, step in ipairs(stepsFor(ctx)) do
        out[#out + 1] = { id = "kimArena.wiz.sum." .. step.id, group = true,
          label = step.title, value = function() return stepLabel(step, ctx) end,
          help = "Tap to change.",
          activate = function(g)
            openStep(g or game, ctx, step, nil, nil, function(g2)
              -- back to the review page, which shows the new answer
              local states = g2.stack and g2.stack.states
              if states and states[#states] ~= page then g2.stack:pop() end
              refresh(page, rows())
            end)
          end }
      end
      out[#out + 1] = { id = "kimArena.wiz.finish", group = true,
        label = ctx.preGame and "START GAME" or "APPLY",
        help = ctx.preGame and "Use these settings and start the new game. Every one of them can be changed later from GEN2-AIO."
          or "Use these settings now. Each can also be changed one by one on the GEN2-AIO pages.",
        activate = function(g)
          g = g or game
          applyAll(g, ctx)
          closeWizard(g)
          if ctx.onDone then ctx.onDone(g) end
        end }
      return out
    end
    page = push(game, rows(), "REVIEW", ctx.preGame and "NEW GAME" or "SETUP")
    return page
  end

  local function runSteps(game, ctx)
    local list = stepsFor(ctx)
    local function go(g, i)
      if i > #list then return openSummary(g, ctx) end
      openStep(g, ctx, list[i], i, #list, function(g2) go(g2, i + 1) end)
    end
    go(game, 1)
  end

  -- the first page: a profile in one tap, or step by step
  local Wizard = {}
  function Wizard.open(game, opts)
    if type(game) ~= "table" or not game.stack then return nil end
    opts = opts or {}
    local ctx = { picks = {}, preGame = opts.preGame == true, onDone = opts.onDone }
    if ctx.preGame then
      local nz = nuzlocke()
      if nz and nz.prepareNewGame then pcall(nz.prepareNewGame, game) end
    end
    local rows = {}
    for _, p in ipairs(PROFILES) do
      rows[#rows + 1] = { id = "kimArena.wiz.profile." .. p.id, group = true,
        label = p.label, help = p.help,
        value = function() return p.id == "recommended" and "SUGGESTED" or "" end,
        activate = function(g)
          ctx.picks = {}
          for k, v in pairs(p.pick) do ctx.picks[k] = v end
          openSummary(g or game, ctx)
        end }
    end
    rows[#rows + 1] = { id = "kimArena.wiz.custom", group = true, label = "STEP BY STEP",
      help = "Choose each part yourself: difficulty, Nuzlocke, look, battles, world, wild Pokemon and conveniences.",
      activate = function(g) ctx.picks = {}; runSteps(g or game, ctx) end }
    if ctx.preGame then
      rows[#rows + 1] = { id = "kimArena.wiz.skip", group = true, label = "SKIP",
        help = "Start the new game with the settings as they are now. The wizard is always in GEN2-AIO.",
        activate = function(g)
          g = g or game
          closeWizard(g)
          if ctx.onDone then ctx.onDone(g) end
        end }
    end
    return push(game, rows, "SETUP WIZARD", ctx.preGame and "NEW GAME" or "PRESETS")
  end
  Wizard.steps, Wizard.profiles, Wizard.currentChoice = STEPS, PROFILES, currentChoice
  Wizard.applyAll = applyAll

  -- GEN2-AIO's root page: SETUP WIZARD above the pages
  local prevTop = Hub.rootTop
  Hub.rootTop = function(game)
    local rows = {}
    if type(prevTop) == "function" then
      local ok, list = pcall(prevTop, game)
      if ok and type(list) == "table" then for _, r in ipairs(list) do rows[#rows + 1] = r end end
    end
    rows[#rows + 1] = { id = "kimArena.wiz.open", group = true, label = "SETUP WIZARD",
      help = "Switch to a ready-made set of settings (RECOMMENDED, CASUAL, NUZLOCKE, CLASSIC ...) "
        .. "or answer a few questions step by step.",
      activate = function(g) Wizard.open(g or game) end }
    return rows
  end

  -- NEW GAME on the title screen. Crystal's title list dispatches through
  -- MainMenu:choose(value); Nuzlocke wraps it too, in either order, which is
  -- why FINISH re-stages its pending rules. Engine modules outlive a session
  -- (Android relaunches in the same Lua state): wrap once, and route each
  -- call to this session's wizard.
  local okM, MainMenu = pcall(require, "src.ui.gen2.MainMenu")
  if okM and type(MainMenu) == "table" and type(MainMenu.choose) == "function" then
    rawset(MainMenu, "_aioWizardLive", function(self, value, vanilla, ...)
      if value ~= "new" or self._aioWizardPassed then return vanilla(self, value, ...) end
      local wanted = Hub.read("setupWizard")
      if wanted == false then return vanilla(self, value, ...) end
      local args = { ... }
      local opened = Wizard.open(self.game, { preGame = true, onDone = function()
        self._aioWizardPassed = true
        local ok, err = pcall(vanilla, self, value, unpack(args))
        self._aioWizardPassed = nil
        if not ok then error(err, 0) end
      end })
      if not opened then return vanilla(self, value, ...) end
    end)
    if not rawget(MainMenu, "_aioWizardWrapped") then
      rawset(MainMenu, "_aioWizardWrapped", true)
      local vanilla = MainMenu.choose
      MainMenu.choose = function(self, value, ...)
        local live = rawget(MainMenu, "_aioWizardLive")
        if type(live) == "function" then return live(self, value, vanilla, ...) end
        return vanilla(self, value, ...)
      end
    end
  end

  mod._kimArenaWizard = Wizard
  return Wizard
end
