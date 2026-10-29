-- gen2-aio: the GEN2-AIO hub.
--
-- Every component (the bundle itself, KIM, Wilds, QOL, Touch, Nuzlocke...)
-- adds its settings to Crystal's OPTION screen through ui.options.rows. This
-- hook runs OUTERMOST: it lets them all add their rows, then takes every row
-- that is not Crystal's own out of the root and files it into topic pages
-- of the hub. Crystal's OPTION keeps its own rows plus one GEN2-AIO row.
--
-- The hub's pages are Crystal's own OPTION screen class (KIM-themed and
-- tappable like it), opened from:
--   START -> GEN2-AIO, OPTION -> GEN2-AIO, and the MOD MANAGER screen
--   (which QOL had replaced with a QOL-only list).
-- 0.9.66: the pages are laid out by setting key (SECTIONS below); a row a
-- component adds later and no page names lands at the end of ADVANCED.
return function(host)
  local mod, log = host.mod, host.log
  local okO, OptionsMenu = pcall(require, "src.ui.gen2.OptionsMenu")
  local okR, Runtime = pcall(require, "src.mods.Runtime")
  if not (okO and type(OptionsMenu) == "table" and okR and Runtime) then return nil end

  -- 0.9.66: nine pages laid out by key (docs/settings_audit.md). An entry
  -- is a setting key (its component's own row when it adds one, otherwise a
  -- row built from the merged schema), or a table naming a row by id /
  -- id prefix, a Gen1Wild QOL feature screen, or MOD LIST. Rows nobody
  -- placed land at the end of ADVANCED, so a component's new row is never
  -- lost.
  local SECTIONS = {
    { id = "gameplay", label = "GAMEPLAY", rows = {
      "trainerLevels", "allCatchable", "qt_modern_types",
      "qt_exp_mult", "qt_catch_exp", { qol = "expshare", label = "EXP SHARE" },
      "qt_money_mult", "qt_keep_money", "qt_free_great_ball",
      "qt_always_catch", "qt_catch_heal", "qt_perfect_dvs", "wok_shiny_rate",
      "qt_infinite_held_item", "qt_instant_hatch", "qt_sand_free", "qt_instant_fish",
      "qt_no_enc_dupes", "qt_poison_save",
      "rematch_enabled", "rematch_prize",
    } },
    { id = "rules", label = "NUZLOCKE & RULES", rows = {
      "nuzlockeMod", { id = "kimArena.nzr.open" },
    } },
    { id = "battle", label = "BATTLE", rows = {
      "battleSprites", "arenaBackground", "kimHdAlign", "kimHdFill", "kimHdOffset",
      "arenaResolution", "arenaShader", "arenaExtras", "arenaWeather",
      "arenaCamera", "arenaCardDetail", "arenaEnemySize", "arenaPlayerIntro",
      "battleShadowQuality", "battleShadowOpacity", "hitFlicker", "hdBall",
      "weatherBattle", "weatherMoves",
      "battleUiWip", "battleWideUi", "battleUiSize", "battleUiOpacity", "battleTextScale",
      "battleMoveLayout", "battleMoveInfo", "moveTypeColors", "moveEffectHint",
      "arenaHud", "gen2BattleHudColor", "qt_exp_bar", "caught_qol_caught_indicator",
      "qt_remember_cursor", "qt_remember_move", "qt_b_to_run", "qt_instant_flee",
      "qt_anim_skip", "qt_heal_battle",
      "sound_alarm_mode", "sound_alarm_cycles", "sound_alarm_retrigger",
    } },
    { id = "world", label = "OVERWORLD & 3D", rows = {
      "pipeline:voxel", "pipeline:tiltshift", "grid", "curve", "water", "atmos", "aa",
      "voidFloor", "voidRelief",
      "timeOfDay", "timeFade", "weatherFx", "weatherPlaces", "weatherRain",
      "qt_lights_on", "areaSignStyle",
    } },
    { id = "ui", label = "DISPLAY & MENUS", rows = {
      { id = "kimArena.picker.", prefix = true },
      "gen2IntegratedModernUi", "menuUi", "dialogueUi", "pokemonUi", "managerUi", "hideOriginalUi",
      "arenaFont", "pixelFont", "fontScale", "uiScale", "density", "minimalUi", "layoutStyle",
      "frameStyle", "frameAsset", "frameScale", "panelOpacity", "foregroundOpacity",
      "dialogueTextScale", "qt_instant_text",
      "startMenuScale", "startMenuTextScale", "startMenuInset", "startMenuFastJump",
      "qt_hold_to_scroll",
      "menuTransitions", "menuDim", "menuClosePos",
      "gen2MenuSpriteSource", "menuIcons", "spriteAnim",
      "overworldHud", "hudPosition", { id = "kimArena.hud.editor" }, "qt_battery_indicator",
    } },
    { id = "qol", label = "QUALITY OF LIFE", rows = {
      "qolMod", "qolToggles",
      "sprint_enabled", "sprint_button", "sprint_speed", "sprint_surf", "sprint_bike",
      "sprint_bike_speed",
      "interact_qol_easy_interactions", "interact_qol_water_interaction",
      "qt_field_moves_all", "qt_badgeless_moves", "qt_hm_item_required", "qt_auto_cut",
      "repels",
      "qt_quick_nurse", "qt_turn_away_nurse", "qt_heal_map_change",
      "startMenuPc", "quickMenu", "quickInStart", "keyWheel",
      { id = "Gen1MenuManager", label = "MENU LAYOUT EDITOR" },
      { qol = "menus", label = "MENU LAYOUT" },
      "qt_rename", "qt_party_scroll", "qt_bulk_mart",
      { qol = "remember", label = "REMEMBER MOVES" },
      "qt_unlimited_tms", "qt_forgettable_hms",
      { qol = "autosave", label = "AUTO SAVE" },
      { qol = "autocontinue", label = "AUTO CONTINUE" },
    } },
    { id = "wilds", label = "WILD POKEMON & FOLLOWERS", rows = {
      "wildsOfKanto", "wok_enabled", "wok_random_encounters", "wok_town_pokemon",
      "wok_pokemon_grass_render_mode", "wok_wild_silhouettes", "wok_sprite_style",
      "wok_follower_count", "followerLead", "wok_pika_follower", "npcMonSprites",
    } },
    { id = "touch", label = "TOUCH CONTROLS", rows = {
      "touchFloating", "touchHand", "touchButtonHeight", "touchSize", "touchOpacity",
      "touchDeadzone", "touchBattleTap", "touchLongPress", "touchRunDrag",
    } },
    { id = "advanced", label = "ADVANCED", rows = {
      "setupWizard", "perfMode", "voxelPrecache", "voxelDiskCache",
      { id = "gen2-aio:voxel_cache" }, { id = "gen2-aio:asset_manager" }, "diagnostics", { modList = true }, { rest = true },
    } },
  }
  -- component rows that answer for a key under another id
  local ALIAS = {
    wok_enabled = "wilds_of_kanto_gen3:enabled",
    wok_random_encounters = "wilds_of_kanto_gen3:random",
  }
  -- never shown: doors to screens whose rows are on the pages now, rows
  -- merged into others (0.9.66), and the GB-card / manager duplicates
  local DROP = {
    ["gen1wild_options"] = true, ["gen2-aio:settings_open"] = true,
    ["wilds_of_kanto_gen3:followers_ex_open"] = true, ["wilds_of_kanto_gen3:wilds_open"] = true,
  }
  local HIDDEN_KEYS = {
    animate = true, spriteAnimation = true, interact_qol_repel_prompt = true,
    rematch_scale = true, qt_repel = true, qt_auto_repel = true, qt_quick_ssanne = true,
    qt_bulk_coins = true, gen2UiTheme = true, kimArenaCustomFrame = true,
    kimArenaCustomBacking = true, kimArenaCustomBorder = true,
  }
  -- labels in the hub's own capitals (Wilds names some rows in mixed case)
  local LABELS = {
    wok_town_pokemon = "TOWN POKEMON", wok_pokemon_grass_render_mode = "GRASS",
    wok_wild_silhouettes = "SILHOUETTE", wok_sprite_style = "GFX STYLE",
    wok_follower_count = "FOLLOWERS", interact_qol_easy_interactions = "EASY HM USE",
    sprint_button = "SPRINT BUTTON", qt_remember_move = "REMEMBER LAST MOVE",
  }
  -- help for rows whose schema has none
  local HELP = {
    sprint_enabled = "Run faster on foot while you hold the sprint button.",
    sprint_button = "The button you hold to sprint.",
    sprint_speed = "How much faster sprinting is than walking.",
    sprint_surf = "Holding the sprint button speeds up surfing too.",
    sprint_bike = "Holding the sprint button speeds up the bike too.",
    sprint_bike_speed = "How fast the bike goes, with or without SPRINT.",
    interact_qol_easy_interactions = "Press A facing a tree, boulder, rock or whirlpool to use "
      .. "the field move a party Pokemon knows, without opening the party menu.",
    interact_qol_water_interaction = "What A does facing water when you could both fish and "
      .. "surf: FISH FIRST or SURF FIRST.",
    rematch_enabled = "Trainers you have beaten can be battled again.",
    rematch_prize = "Rematches pay prize money like the first battle.",
    sound_alarm_mode = "The low HP alarm in battle. ONCE: one beep. N BEEPS: stops after "
      .. "BEEP COUNT beeps. VANILLA: Crystal's nonstop alarm.",
    sound_alarm_cycles = "How many beeps the low HP alarm plays before it stops.",
    sound_alarm_retrigger = "The alarm starts again each time your low-HP Pokemon is hit.",
    caught_qol_caught_indicator = "The NATIVE battle HUD's mark for species you have caught.",
    touchOpacity = "How see-through the touch controls are.",
    Gen1MenuManager = "Reorder the START and PC menus, hide rows you never use and pin "
      .. "field moves to rows of their own.",
  }
  -- component switches: they load (or not) when the game starts
  local LOAD_SWITCH = { wildsOfKanto = true, nuzlockeMod = true, qolMod = true, qolToggles = true }
  local loadedAs = {}
  do
    local o = rawget(mod, "_kimArenaOpt")
    for key in pairs(LOAD_SWITCH) do
      if type(o) == "function" then loadedAs[key] = o(key, true) ~= false
      else loadedAs[key] = true end
    end
  end

  local function dropped(row)
    local label = tostring(row.label or ""):upper()
    if row.id and DROP[row.id] then return true end
    if row.id == "qolToggles" then return true end
    return label == "MOD MANAGER" or label == "MODS MANAGER"
  end

  local capturing = false
  local captured = {}
  local function sameRows(_, rows) return rows end

  -- a page of Crystal's OPTION screen showing `rows`, with BACK
  local function pushPage(game, rows, title)
    local page = setmetatable({}, OptionsMenu)
    page.game = game
    page.rows = rows
    page.options = (game.save and game.save.options) or game.options or {}
    page.index, page.scroll, page.sub = 1, 0, true
    page.title = title
    page.view = {}
    for i, row in ipairs(rows) do page.view[i] = row end
    page.view[#page.view + 1] = { label = "BACK", cancel = true, id = "cancel" }
    game.stack:push(page)
    return page
  end

  -- every mod row, freshly built (so values are current)
  local function collect(game)
    capturing = true
    local ok, rows = pcall(Runtime.call, "ui.options.rows", sameRows, game, {})
    capturing = false
    return ok and type(rows) == "table" and rows or captured
  end

  local Hub = { extras = {} }
  -- a Modern UI page of Crystal's OPTION screen for any list of rows
  function Hub.page(game, rows, title)
    if type(game) ~= "table" or not game.stack then return nil end
    return pushPage(game, rows, title)
  end

  -- ---- the merged schema (main.lua), for rows no component builds
  local function schemaRow(key)
    local fn = rawget(mod, "_kimArenaSchema")
    if type(fn) ~= "function" then return nil end
    local okS, merged, position = pcall(fn)
    if not (okS and type(merged) == "table" and type(position) == "table") then return nil end
    local at = position[key]
    return at and merged[at] or nil
  end
  local function qolKey(key)
    local keys = rawget(mod, "_kimArenaQolKeys")
    return type(keys) == "table" and keys[key] == true
  end
  local function exportsOf(name)
    local ex = mod.exports and mod.exports[name]
    return type(ex) == "table" and ex or nil
  end
  -- what a setting reads right now, through the store its component uses
  local function readValue(key, spec)
    local qol = exportsOf("qol")
    local v
    if qolKey(key) and qol and type(qol.optionValue) == "function" then
      local okQ, q = pcall(qol.optionValue, key)
      if okQ then v = q end
    else
      local okG, g = pcall(mod.options.get, mod.options, key)
      if okG then v = g end
    end
    if v == nil and spec then v = spec.default end
    return v
  end
  local function writeValue(g, key, value)
    local qol, wilds = exportsOf("qol"), exportsOf("wilds")
    if qolKey(key) and qol and type(qol.optionWrite) == "function" then
      pcall(qol.optionWrite, key, value, g)
      return true
    end
    if key:sub(1, 4) == "wok_" and wilds and type(wilds.setOption) == "function" then
      local okW = pcall(wilds.setOption, key:sub(5), value, g)
      if okW then return true end
    end
    -- the same write path as every OPTION row (lib/gen2_aio/ingame_options.lua)
    local opts = g and ((g.save and g.save.options) or g.options)
    if opts then
      opts.modOptions = opts.modOptions or {}
      opts.modOptions[mod.id] = opts.modOptions[mod.id] or {}
      opts.modOptions[mod.id][key] = value
    end
    if g and type(g.mods) == "table" then
      g.mods.modOptions = g.mods.modOptions or {}
      g.mods.modOptions[mod.id] = g.mods.modOptions[mod.id] or {}
      g.mods.modOptions[mod.id][key] = value
    end
    pcall(Runtime.emit, "mod.options_changed", { mod = mod.id, key = key, value = value })
    if g and g.writeOptions then pcall(g.writeOptions, g)
    elseif g and g.persistOptions then pcall(g.persistOptions, g) end
    return true
  end
  local function helpOf(spec)
    if type(spec) ~= "table" then return nil end
    local h = spec.help or spec.description
    if type(h) ~= "string" or h == "" then return nil end
    h = h:gsub("[\n\v]", " "):gsub("%s+", " ")
    -- Gen1Wild QOL writes its help in capitals; the help line reads better
    if not h:find("%l") then h = h:sub(1, 1) .. h:sub(2):lower() end
    return h
  end
  -- whether a setting can do anything with the others as they are
  local function visible(key, spec)
    local hiddenFn = rawget(mod, "_kimArenaRowHidden")
    if type(hiddenFn) == "function" then
      local okH, hide = pcall(hiddenFn, key)
      if okH and hide then return false end
    end
    local vi = type(spec) == "table" and spec.visible_if
    if type(vi) == "table" and type(vi.key) == "string" then
      local other = readValue(vi.key, schemaRow(vi.key))
      if vi.equals ~= nil and other ~= vi.equals then return false end
      if vi.not_equals ~= nil and other == vi.not_equals then return false end
    end
    return true
  end
  local function choiceLabel(spec, value)
    if spec.type == "toggle" then return value and "ON" or "OFF" end
    if spec.type == "number" then return tostring(value or 0) end
    for _, c in ipairs(spec.choices or {}) do
      if c[2] == value or tostring(c[2]) == tostring(value) then return tostring(c[1]) end
    end
    local first = spec.choices and spec.choices[1]
    return first and tostring(first[1]) or "----"
  end
  -- a row for a schema key no component builds a row for
  local function builtRow(key, spec)
    local row = { id = mod.id .. ":" .. key, label = spec.label or key, help = helpOf(spec) }
    row.value = function() return choiceLabel(spec, readValue(key, spec)) end
    row.step = function(g, dir)
      dir = dir or 1
      local cur = readValue(key, spec)
      local value
      if spec.type == "toggle" then
        value = not cur
      elseif spec.type == "number" then
        value = (tonumber(cur) or spec.default or 0) + dir * (spec.step or 1)
        value = math.max(spec.min or -math.huge, math.min(spec.max or math.huge, value))
      else
        local list, at = spec.choices or {}, 0
        for i, c in ipairs(list) do
          if c[2] == cur or tostring(c[2]) == tostring(cur) then at = i; break end
        end
        if #list == 0 then return false end
        if at == 0 then at = dir > 0 and 0 or 1 end
        value = list[(at - 1 + dir) % #list + 1][2]
      end
      return writeValue(g, key, value)
    end
    return row
  end

  -- every mod row, freshly built (so values are current), plus the rows
  -- the host modules add (UI THEME, HUD BUTTONS, RUN RULES)
  local function pool(game)
    local rows = collect(game)
    local all = {}
    for _, r in ipairs(rows) do
      if type(r) == "table" and not dropped(r) then all[#all + 1] = r end
    end
    for _, extra in pairs(Hub.extras) do
      if type(extra) == "function" then
        local okE, list = pcall(extra, game)
        if okE and type(list) == "table" then
          for _, r in ipairs(list) do if type(r) == "table" then all[#all + 1] = r end end
        end
      end
    end
    return all
  end
  local function find(all, used, test)
    for i, r in ipairs(all) do
      if not used[i] and test(r) then used[i] = true; return r end
    end
    return nil
  end
  local function keyOfRow(r)
    local id = tostring(r.id or "")
    return id:match("^[^:]+:(.+)$") or r.key
  end
  -- the row for one page entry, or nil (not installed / not applicable)
  local function entryRow(game, entry, all, used)
    if type(entry) == "string" then
      local key = entry
      local spec = schemaRow(key)
      if HIDDEN_KEYS[key] then return nil end
      if not visible(key, spec) then
        -- still consume the component's row so it does not land in ADVANCED
        find(all, used, function(r) return r.id == mod.id .. ":" .. key or r.id == key end)
        return nil
      end
      local wanted = ALIAS[key]
      local row = find(all, used, function(r)
        return r.id == (wanted or (mod.id .. ":" .. key)) or r.id == key
      end)
      if not row and not wanted then
        -- a component row under its own id prefix (gmarc's GEN2_VOXEL:aa)
        row = find(all, used, function(r)
          local id = tostring(r.id or "")
          return id:sub(-(#key + 1)) == ":" .. key and not id:find("^kimArena")
        end)
      end
      if not row and spec and not key:find(":", 1, true) then row = builtRow(key, spec) end
      if not row then return nil end
      row.help = row.help or HELP[key] or helpOf(spec)
      if LABELS[key] then row.label = LABELS[key] end
      if key:sub(1, 4) == "wok_" and type(row.value) == "function" then
        local value = row.value
        row.value = function(...) return tostring(value(...) or ""):upper() end
      end
      if LOAD_SWITCH[key] then
        local value = row.value
        row.value = function(...)
          local text = type(value) == "function" and value(...) or value
          local now = readValue(key, spec) ~= false
          if now ~= loadedAs[key] then return tostring(text) .. " (NEXT LAUNCH)" end
          return text
        end
        row.help = (row.help or "") .. ((row.help or ""):find("next time", 1, true) and ""
          or " Takes effect the next time the game starts.")
      end
      return row
    end
    if entry.id then
      local row = find(all, used, function(r)
        local id = tostring(r.id or "")
        if entry.prefix then return id:sub(1, #entry.id) == entry.id end
        return id == entry.id
      end)
      if row and entry.label then row.label = entry.label end
      if row and not row.help then row.help = HELP[entry.id] end
      return row
    end
    if entry.qol then
      local qol = exportsOf("qol")
      local menu = qol and qol.menu
      for _, f in ipairs(type(menu) == "table" and menu.features or {}) do
        if f.id == entry.qol and f.screen_id then
          return { id = "kimArena.qol." .. f.id, label = entry.label or f.label, group = true,
            help = helpOf({ help = f.description }),
            activate = function(g)
              if mod.ui and mod.ui.push then pcall(mod.ui.push, g or game, f.screen_id) end
            end }
        end
      end
      return nil
    end
    if entry.modList then
      return { id = "kimArena.hub.mods", label = "MOD LIST", group = true,
        help = "The engine's list of installed mods, with every setting as a raw row.",
        activate = function(g)
          local okM, Manager = pcall(require, "src.mods.ManagerState")
          if okM and Manager and Manager.new then
            local okN, st = pcall(Manager.new, g)
            if okN and st then g.stack:push(st) end
          end
        end }
    end
    return nil
  end

  local function sectionDef(id)
    for _, sec in ipairs(SECTIONS) do if sec.id == id then return sec end end
    return nil
  end
  -- every page's rows from one pool, in page order, so a row is placed once
  -- and whatever is left over is known for ADVANCED
  local function buildAll(game)
    local all, used = pool(game), {}
    local pages, rests = {}, {}
    for _, sec in ipairs(SECTIONS) do
      local rows = {}
      for _, entry in ipairs(sec.rows) do
        if type(entry) == "table" and entry.rest then
          rests[#rests + 1] = { sec = sec.id, rows = rows }
        else
          local okR, row = pcall(entryRow, game, entry, all, used)
          if okR and row then rows[#rows + 1] = row end
        end
      end
      pages[sec.id] = rows
    end
    for _, slot in ipairs(rests) do
      for i, r in ipairs(all) do
        if not used[i] then
          local key = keyOfRow(r)
          if not (key and HIDDEN_KEYS[key]) then
            slot.rows[#slot.rows + 1] = r
          end
          used[i] = true
        end
      end
    end
    return pages
  end
  -- a change can show or hide rows (a master switch, BATTLE HUD, ...):
  -- rebuild the open page after each one
  local function live(rows, game, id)
    for _, row in ipairs(rows) do
      local step = row.step
      if type(step) == "function" and not row._kimHubLive then
        row._kimHubLive = true
        row.step = function(g, ...)
          local result = step(g, ...)
          pcall(Hub.refreshOpen, g or game, id)
          return result
        end
      end
    end
    return rows
  end
  local function sectionMembers(game, id)
    local pages = buildAll(game)
    return live(pages[id] or {}, game, id)
  end
  local function labelOf(id)
    local sec = sectionDef(id)
    return sec and sec.label or tostring(id):upper()
  end
  -- open one hub page directly (also used to rebuild a page after a change
  -- that adds or removes rows on it)
  function Hub.openSection(game, id)
    if type(game) ~= "table" or not game.stack then return nil end
    local page = pushPage(game, sectionMembers(game, id), labelOf(id))
    if page then page.kimSection = id end
    return page
  end
  -- rebuild an open hub page in place, keeping the cursor on the same row
  function Hub.refreshOpen(game, id)
    local states = game and game.stack and game.stack.states
    if type(states) ~= "table" then return false end
    for i = #states, 1, -1 do
      local page = states[i]
      if type(page) == "table" and rawget(page, "kimSection") == id then
        local was = page.view and page.view[page.index or 1]
        local wasId = was and was.id
        local rows = sectionMembers(game, id)
        page.rows = rows
        page.view = {}
        for k, row in ipairs(rows) do page.view[k] = row end
        page.view[#page.view + 1] = { label = "BACK", cancel = true, id = "cancel" }
        if wasId then
          for k, row in ipairs(page.view) do
            if row.id == wasId then page.index = k; break end
          end
        end
        if (page.index or 1) > #page.view then page.index = #page.view end
        return true
      end
    end
    return false
  end
  -- the page a key is on (for tests and diagnostics)
  function Hub.pageOf(key)
    for _, sec in ipairs(SECTIONS) do
      for _, entry in ipairs(sec.rows) do
        if entry == key then return sec.id end
      end
    end
    return nil
  end
  Hub.sections = SECTIONS
  Hub.buildAll = buildAll
  -- 0.9.67: the setup wizard reads and writes settings the way the pages do
  function Hub.read(key) return readValue(key, schemaRow(key)) end
  function Hub.write(game, key, value) return writeValue(game, key, value) end
  -- rows above the page list on the root page (SETUP WIZARD); a function
  -- of the game returning a list of rows
  Hub.rootTop = nil

  function Hub.open(game)
    if type(game) ~= "table" or not game.stack then return end
    local pages = buildAll(game)
    local root = {}
    if type(Hub.rootTop) == "function" then
      local okT, top = pcall(Hub.rootTop, game)
      if okT and type(top) == "table" then
        for _, r in ipairs(top) do root[#root + 1] = r end
      end
    end
    for _, sec in ipairs(SECTIONS) do
      if #(pages[sec.id] or {}) > 0 then
        root[#root + 1] = { id = "kimArena.hub." .. sec.id, label = sec.label, group = true,
          activate = function(g) Hub.openSection(g or game, sec.id) end }
      end
    end
    return pushPage(game, root, "GEN2-AIO")
  end
  mod._kimArenaHub = Hub

  -- OPTION: Crystal's rows + GEN2-AIO; everything else goes to the hub
  mod.hooks:wrap("ui.options.rows", function(nextFn, game, rows)
    local base = {}
    for _, r in ipairs(type(rows) == "table" and rows or {}) do base[r] = true end
    local result = nextFn(game, rows)
    if type(result) ~= "table" then return result end
    if capturing then return result end
    local kept, extras = {}, {}
    for _, r in ipairs(result) do
      if base[r] then kept[#kept + 1] = r else extras[#extras + 1] = r end
    end
    captured = extras
    kept[#kept + 1] = { id = "kimArena.hub", label = "GEN2-AIO", group = true,
      activate = function(g) Hub.open(g) end }
    return kept
  end, 1e9)

  -- START -> GEN2-AIO (8 characters keeps Crystal's START menu width)
  mod.hooks:wrap("ui.start_menu.items", function(nextFn, game, items)
    local result = nextFn(game, items)
    if type(result) ~= "table" then result = items end
    -- 0.9.35 START -> PC: Bill's PC (WITHDRAW / DEPOSIT / CHANGE BOX / MOVE)
    -- from anywhere, the same screen a Pokemon Center's PC opens. Setting
    -- startMenuPc (QUALITY OF LIFE page), default on.
    local okPc, wantPc = pcall(mod.options.get, mod.options, "startMenuPc")
    if not okPc or wantPc ~= false then
      local pcEntry = { label = "PC", onSelect = function()
        local okS, Screens = pcall(require, "src.ui.Screens")
        if not (okS and Screens and game and game.stack) then return end
        pcall(Screens.push, game, "Gen2PcMenu", {
          save = game.save, bills = true,
          onClose = function() game.stack:pop() end,
        })
      end }
      local at = #result + 1
      for i, it in ipairs(result) do if it and it.label == "OPTION" then at = i; break end end
      table.insert(result, at, pcEntry)
    end
    local entry = { label = "GEN2-AIO", onSelect = function() Hub.open(game) end }
    local inserted = false
    if mod.ui and mod.ui.insertBefore then
      inserted = pcall(mod.ui.insertBefore, result, "OPTION", entry)
    end
    if not inserted then
      local at = #result
      for i, it in ipairs(result) do if it and it.label == "OPTION" then at = i; break end end
      table.insert(result, at, entry)
    end
    return result
  end, -1e9)

  -- MOD MANAGER opens the hub (QOL had replaced it with a QOL-only list)
  pcall(function()
    local screens = mod.content and mod.content.screens
    if screens and screens.override then
      screens:override("ManagerState", {
        new = function(game)
          -- the hub pushes its own page; hand the stack something that
          -- immediately gives way to it
          local noop = function() end
          local shim = { game = game, enter = noop, exit = noop, resume = noop,
            pause = noop, leave = noop, onEnter = noop, onExit = noop }
          function shim:update()
            if not self.opened then
              self.opened = true
              game.stack:pop()
              Hub.open(game)
            end
          end
          function shim:draw() end
          return shim
        end,
      })
    end
  end)

  if log then log("info", "Gen2-AIO: GEN2-AIO hub installed") end
  return Hub
end
