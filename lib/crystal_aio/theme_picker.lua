-- gen2-aio 0.9.37: CUSTOM UI THEME pickers.
--
-- Three rows at the top of the hub's DISPLAY & UI page -- CUSTOM BORDER,
-- CUSTOM BACKING, CUSTOM BORDER COLOR. Each opens a LIST (a page of Crystal's
-- OPTION screen) instead of cycling left/right; picking an entry saves it and
-- returns. The colours themselves live in gen2_modern_battle_ui.lua's
-- "gen2_aio:custom" theme (UI THEME = CUSTOM).
return function(host)
  local mod = host.mod
  local Hub = rawget(mod, "_kimArenaHub")
  if not (Hub and Hub.page and Hub.extras) then return nil end

  -- UI THEME itself (KIM's gen2UiTheme), as a list. Same entries, same order
  -- as kim_main.lua's UI THEME choices.
  local THEME = { key = "gen2UiTheme", label = "UI THEME", default = "default", items = {
    { "GEN1 MODERN", "default" }, { "HEARTGOLD", "gen2_aio:heartgold" },
    { "SOULSILVER", "gen2_aio:soulsilver" }, { "JOHTO NIGHT", "gen2_aio:johto_night" },
    { "CLASSIC MONO", "gen1_modern_ui:classic_mono" }, { "CRIMSON", "gen1_modern_ui:crimson" },
    { "CRIMSON GLASS", "gen1_modern_ui:crimson_glass" }, { "MODERN GLASS", "gen1_modern_ui:modern_glass" },
    { "POCKET GREEN", "gen1_modern_ui:pocket_green" }, { "MIDNIGHT", "gen1_modern_ui:midnight" },
    { "MIDNIGHT GLASS", "gen1_modern_ui:midnight_glass" }, { "FROST", "gen1_modern_ui:frost" },
    { "LIGHT", "gen1_modern_ui:light" }, { "DARK", "gen1_modern_ui:dark" },
    { "CRYSTAL", "gen2_aio:crystal" }, { "GOLD", "gen2_aio:gold" }, { "SILVER", "gen2_aio:silver" },
    { "POKEGEAR", "gen2_aio:pokegear" }, { "HIGH CONTRAST", "gen2_aio:high_contrast" },
    { "TYPE (LEAD POKEMON)", "gen2_aio:type" }, { "TYPE LIGHT (LEAD POKEMON)", "gen2_aio:type_light" }, { "GEN 3 (FRLG)", "gen2_aio:gen3" },
    { "CUSTOM", "gen2_aio:custom" } } }

  local PICKERS = {
    { key = "kimArenaCustomFrame", label = "CUSTOM BORDER", default = "gen3", items = {
      { "GEN 3", "gen3" }, { "FRAME 1", "frame1" }, { "FRAME 2", "frame2" },
      { "FRAME 3", "frame3" }, { "SOFT", "soft" }, { "PLAIN", "plain" } } },
    { key = "kimArenaCustomBacking", label = "CUSTOM BACKING", default = "cream", items = {
      { "WHITE", "white" }, { "CREAM", "cream" }, { "SKY", "sky" }, { "MINT", "mint" },
      { "PINK", "pink" }, { "SLATE", "slate" }, { "NAVY", "navy" }, { "BROWN", "brown" },
      { "FOREST", "forest" }, { "PLUM", "plum" }, { "BLACK", "black" } } },
    { key = "kimArenaCustomBorder", label = "CUSTOM BORDER COLOR", default = "teal", items = {
      { "TEAL", "teal" }, { "BLUE", "blue" }, { "RED", "red" }, { "GOLD", "gold" },
      { "SILVER", "silver" }, { "GREEN", "green" }, { "PURPLE", "purple" },
      { "ORANGE", "orange" }, { "PINK", "pink" }, { "BLACK", "black" }, { "WHITE", "white" } } },
  }

  local function get(key, default)
    local ok, v = pcall(mod.options.get, mod.options, key)
    return ok and v ~= nil and tostring(v) or default
  end
  -- same write path as the OPTION rows (lib/crystal_aio/ingame_options.lua)
  local function set(game, key, value)
    local opts = game and ((game.save and game.save.options) or game.options)
    if not opts then return false end
    opts.modOptions = opts.modOptions or {}
    opts.modOptions[mod.id] = opts.modOptions[mod.id] or {}
    opts.modOptions[mod.id][key] = value
    if game.mods then
      game.mods.modOptions = game.mods.modOptions or {}
      game.mods.modOptions[mod.id] = game.mods.modOptions[mod.id] or {}
      game.mods.modOptions[mod.id][key] = value
    end
    pcall(function() require("src.mods.Runtime").emit("mod.options_changed",
      { mod = mod.id, key = key, value = value }) end)
    if game.writeOptions then pcall(game.writeOptions, game)
    elseif game.persistOptions then pcall(game.persistOptions, game) end
    return true
  end
  local function nameOf(p, code)
    for _, it in ipairs(p.items) do if it[2] == code then return it[1] end end
    return p.items[1][1]
  end

  -- a list page: every entry reads ON or OFF, choosing one turns it ON (and
  -- whichever was ON before turns OFF); the list stays open so you can try a
  -- few. BACK returns. (0.9.39: entries were OPEN rows, which read as if
  -- they opened something.)
  local function openList(game, p, parent, rebuild)
    local rows = {}
    for _, it in ipairs(p.items) do
      local row = { id = "kimArena.pick." .. p.key .. "." .. it[2], label = it[1],
        help = p.label:gsub("^%s+", "") .. ": " .. it[1] }
      row.value = function() return get(p.key, p.default) == it[2] and "ON" or "OFF" end
      local function choose(g)
        g = g or game
        if get(p.key, p.default) == it[2] then return true end
        set(g, p.key, it[2])
        if parent then parent.label = p.label .. ": " .. it[1] end
        -- a theme change adds / removes the CUSTOM rows on the page below
        if rebuild and Hub.refreshOpen then pcall(Hub.refreshOpen, g, "ui") end
        return true
      end
      row.step = function(g) return choose(g) end
      row.activate = choose
      rows[#rows + 1] = row
    end
    Hub.page(game, rows, (p.label:gsub("^%s+", "")))
  end

  Hub.extras.ui = function(game)
    local rows = {}
    local themeRow = { id = "kimArena.picker.theme",
      label = THEME.label .. ": " .. nameOf(THEME, get(THEME.key, THEME.default)), group = true,
      help = "Opens the list of UI themes; tap one to use it." }
    themeRow.activate = function(g) openList(g or game, THEME, themeRow, true) end
    rows[1] = themeRow
    -- the CUSTOM settings sit under UI THEME, only while CUSTOM is chosen
    if get(THEME.key, THEME.default) == "gen2_aio:custom" then
      for _, p in ipairs(PICKERS) do
        local short = p.label:gsub("^CUSTOM ", "")
        local row = { id = "kimArena.picker." .. p.key,
          label = "  " .. short .. ": " .. nameOf(p, get(p.key, p.default)), group = true,
          help = "Opens a list for the CUSTOM theme." }
        local view = { key = p.key, label = "  " .. short, default = p.default, items = p.items }
        row.activate = function(g) openList(g or game, view, row) end
        rows[#rows + 1] = row
      end
    end
    return rows
  end
  return { pickers = PICKERS }
end
