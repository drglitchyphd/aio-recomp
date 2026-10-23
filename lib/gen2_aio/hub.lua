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
-- New rows a component adds later land in a section by their name, or in
-- MORE, without any change here.
return function(host)
  local mod, log = host.mod, host.log
  local okO, OptionsMenu = pcall(require, "src.ui.gen2.OptionsMenu")
  local okR, Runtime = pcall(require, "src.mods.Runtime")
  if not (okO and type(OptionsMenu) == "table" and okR and Runtime) then return nil end

  local SECTIONS = {
    { id = "ui",      label = "DISPLAY & UI" },
    { id = "weather", label = "WEATHER & TIME" },
    { id = "world",   label = "OVERWORLD & VOXEL" },
    { id = "wilds",   label = "WILD POKEMON" },
    { id = "battle",  label = "BATTLE" },
    { id = "rules",   label = "RULES" },
    { id = "qol",     label = "QUALITY OF LIFE" },
    { id = "qt",      label = "QOL TOGGLES" },
    { id = "touch",   label = "TOUCH CONTROLS" },
    { id = "more",    label = "MORE" },
  }
  -- first match wins; tested against "<id> <label>" in lower case
  local RULES = {
    -- QOL first: Gen1Wild QOL is a quality-of-life pack, not a wild one
    -- 0.9.43: DIAGNOSTICS sits on the GEN2-AIO root page itself
    { "diagnostics", "root" },
    { "qt_", "qt" },
    { "qoltoggles", "qt" },
    { "startmenupc", "qol" },
    { "quickmenu", "qol" }, { "quickinstart", "qol" }, { "keywheel", "qol" },
    { "timefade", "weather" },
    { "areasign", "ui" },
    { "qol", "qol" }, { "gen1wild", "qol" }, { "quality", "qol" },
    { "weather", "weather" }, { "time of day", "weather" }, { "time fade", "weather" },
    { "touch", "touch" }, { "button side", "touch" }, { "control size", "touch" },
    { "control opacity", "touch" }, { "dead zone", "touch" }, { "tap menus", "touch" },
    { "far drag", "touch" }, { "floating", "touch" },
    { "nuzlocke", "rules" }, { "nz_", "rules" }, { "rules", "rules" }, { "level cap", "rules" },
    { "wok_", "wilds" }, { "wilds", "wilds" }, { "wild ", "wilds" }, { "follower", "wilds" },
    { "encounter", "wilds" }, { "shiny", "wilds" }, { "sprite style", "wilds" },
    { "gfx style", "wilds" }, { "catchable", "wilds" }, { "crystal251", "wilds" },
    { "performance", "world" }, { "voxel", "world" }, { "void", "world" }, { "edge", "world" }, { "zoom", "world" },
    { "gmarc", "world" }, { "precache", "world" }, { "disk cache", "world" },
    { "forest fx", "world" }, { "curve", "world" }, { "day/night", "world" }, { "day night", "world" },
    { "battle", "battle" }, { "arena", "battle" }, { "kim hd", "battle" }, { "kimhd", "battle" },
    { "background", "battle" }, { "camera", "battle" }, { "sprite detail", "battle" },
    { "scene fx", "battle" }, { "3d bg", "battle" }, { "trainer", "battle" }, { "exp", "battle" },
    { "hp bar", "battle" }, { "quick ball", "battle" }, { "poke ball", "battle" },
    { "qol", "qol" }, { "sprint", "qol" }, { "autosave", "qol" }, { "auto save", "qol" },
    { "reminder", "qol" }, { "banner", "qol" }, { "remember", "qol" }, { "rematch", "qol" },
    { "sound", "qol" }, { "auto continue", "qol" }, { "menu layout", "qol" },
    { "theme", "ui" }, { "font", "ui" }, { " ui", "ui" }, { "ui ", "ui" }, { "menu", "ui" },
    { "hud", "ui" }, { "modern", "ui" }, { "fade", "ui" }, { "dim", "ui" }, { "dialog", "ui" },
    { "text", "ui" }, { "kanto in motion", "ui" },
  }
  local function sectionOf(row)
    local hay = (tostring(row.id or row.key or "") .. " " .. tostring(row.label or "")):lower()
    for _, r in ipairs(RULES) do
      if hay:find(r[1], 1, true) then return r[2] end
    end
    return "more"
  end
  -- QOL's MOD MANAGER entry would only lead back here
  local function dropped(row)
    local label = tostring(row.label or ""):upper()
    -- QoL Toggles' own Game Boy card menu: its switches are hub rows now
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
  -- one page's rows, built fresh: the matching mod rows plus any rows other
  -- host modules add to it (0.9.35 RUN RULES, 0.9.38 UI THEME / CUSTOM)
  local function sectionMembers(game, id, rows)
    rows = rows or collect(game)
    local members = {}
    local extra = Hub.extras[id]
    if type(extra) == "function" then
      local okE, list = pcall(extra, game)
      if okE and type(list) == "table" then
        for _, r in ipairs(list) do members[#members + 1] = r end
      end
    end
    for _, row in ipairs(rows) do
      if type(row) == "table" and not dropped(row) and sectionOf(row) == id then
        members[#members + 1] = row
      end
    end
    return members
  end
  local function labelOf(id)
    for _, sec in ipairs(SECTIONS) do if sec.id == id then return sec.label end end
    return tostring(id):upper()
  end
  -- open one hub page directly (also used to rebuild a page after a change
  -- that adds or removes rows on it)
  function Hub.openSection(game, id)
    if type(game) ~= "table" or not game.stack then return nil end
    local page = pushPage(game, sectionMembers(game, id), labelOf(id))
    if page then page.kimSection = id end
    return page
  end
  -- rebuild an open hub page in place (rows added / removed by a change)
  function Hub.refreshOpen(game, id)
    local states = game and game.stack and game.stack.states
    if type(states) ~= "table" then return false end
    for i = #states, 1, -1 do
      local page = states[i]
      if type(page) == "table" and rawget(page, "kimSection") == id then
        local rows = sectionMembers(game, id)
        page.rows = rows
        page.view = {}
        for k, row in ipairs(rows) do page.view[k] = row end
        page.view[#page.view + 1] = { label = "BACK", cancel = true, id = "cancel" }
        if (page.index or 1) > #page.view then page.index = #page.view end
        return true
      end
    end
    return false
  end

  function Hub.open(game)
    if type(game) ~= "table" or not game.stack then return end
    local rows = collect(game)
    local root = {}
    for _, sec in ipairs(SECTIONS) do
      local members = sectionMembers(game, sec.id, rows)
      if #members > 0 then
        root[#root + 1] = { id = "kimArena.hub." .. sec.id, label = sec.label, group = true,
          activate = function(g) Hub.openSection(g or game, sec.id) end }
      end
    end
    -- rows filed to the root page itself (DIAGNOSTICS), above MOD LIST
    for _, r in ipairs(sectionMembers(game, "root", rows)) do root[#root + 1] = r end
    -- the engine's own list of installed mods and their settings
    root[#root + 1] = { id = "kimArena.hub.mods", label = "MOD LIST", group = true,
      activate = function(g)
        local okM, Manager = pcall(require, "src.mods.ManagerState")
        if okM and Manager and Manager.new then
          local okN, st = pcall(Manager.new, g)
          if okN and st then g.stack:push(st) end
        end
      end }
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
