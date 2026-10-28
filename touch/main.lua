-- Kanto in Motion: Touch (KIM_TOUCH)
--
-- Dragon Quest smartphone-style controls for Crystal, on top of gen2-aio:
--
--   * put a finger down ANYWHERE: a D-pad ring appears there; drag past the
--     dead zone to hold a direction (4-way, the grid's own); the ring follows
--     a thumb that strays too far; lift to stop
--   * a quick tap anywhere (no drag) is A
--   * a side button is B; START and SELECT sit beside it
--   * in battle, tap KIM's command and move cells directly
--
-- Everything goes through the engine's public input path: mod.input presses
-- the same GB buttons a pad would, and battle cells only move the menu cursor
-- before pressing A. The stock pad is hidden by moving its buttons off-screen
-- (its quick-menu "hotbar" stays). KIM's own menus see every touch first
-- (their input.pointer link runs before this one) and pass on what they do
-- not use.

return function(mod)
  local okTC, TouchControls = pcall(require, "src.core.TouchControls")
  local okSkin, TouchSkin = pcall(require, "src.core.TouchSkin")
  if not okTC or type(TouchControls) ~= "table" then
    if mod.log then mod.log:warn("KIM Touch: touch controls unavailable") end
    return
  end

  local function log(level, fmt, ...)
    if mod.log and mod.log[level] then pcall(mod.log[level], mod.log, fmt, ...) end
  end

  local function rawOpt(key, default)
    local ok, value = pcall(mod.options.get, mod.options, key)
    if ok and value ~= nil then return value end
    return default
  end

  -- gen2-aio: one button layout per screen SHAPE (Fold outer / inner,
  -- portrait / landscape), detected from the window's proportions. Change a
  -- layout setting on one screen and only that screen keeps it; folding or
  -- rotating loads the other screen's layout. Kept in mod.cache (per
  -- device). A screen with no saved layout yet starts from the current one.
  local LAYOUT_KEYS = { touchHand = true, touchButtonHeight = true, touchSize = true,
    touchOpacity = true, touchDeadzone = true }
  local LAYOUT_FILE = "touch_layouts.lua"
  local layouts = nil
  local function profile()
    local w, h = 0, 0
    if love and love.graphics and love.graphics.getDimensions then w, h = love.graphics.getDimensions() end
    w, h = tonumber(w) or 0, tonumber(h) or 0
    if w <= 0 or h <= 0 then return "port-wide" end
    local orient = w > h and "land" or "port"
    local narrow = math.max(w, h) / math.min(w, h) > 1.9
    return orient .. (narrow and "-narrow" or "-wide")
  end
  local function loadLayouts()
    if layouts then return layouts end
    layouts = {}
    local c = mod.cache
    if c and c.read then
      local okR, body = pcall(c.read, c, LAYOUT_FILE)
      local fn = okR and type(body) == "string" and (loadstring or load)("return " .. body)
      if fn then
        if setfenv then setfenv(fn, {}) end
        local okF, t = pcall(fn)
        if okF and type(t) == "table" then layouts = t end
      end
    end
    return layouts
  end
  local function saveLayouts()
    local c = mod.cache
    if not (c and c.write and layouts) then return end
    local out = { "{" }
    for prof, t in pairs(layouts) do
      out[#out + 1] = ("[%q]={"):format(prof)
      for k, v in pairs(t) do
        out[#out + 1] = ("[%q]=%s,"):format(k, type(v) == "string" and ("%q"):format(v) or tostring(v))
      end
      out[#out + 1] = "},"
    end
    out[#out + 1] = "}"
    pcall(c.write, c, LAYOUT_FILE, table.concat(out))
  end
  local function opt(key, default)
    if key == "touchMouse" then return false end   -- removed (PC testing aid)
    if LAYOUT_KEYS[key] then
      local slot = loadLayouts()[profile()]
      if slot and slot[key] ~= nil then return slot[key] end
    end
    return rawOpt(key, default)
  end
  -- a changed layout setting belongs to the screen it was changed on
  if mod.events and mod.events.on then
    pcall(mod.events.on, mod.events, "mod.options_changed", function(ev)
      if type(ev) ~= "table" or not LAYOUT_KEYS[ev.key] then return end
      local L = loadLayouts()
      local prof = profile()
      L[prof] = L[prof] or {}
      L[prof][ev.key] = ev.value
      saveLayouts()
    end)
  end
  mod._kimTouchLayoutProfile = profile

  -- When the screen shape changes, put that screen's layout into the option
  -- buckets too, so the settings rows show the values actually in use.
  local shownProfile = nil
  local function syncShown(game)
    local prof = profile()
    if prof == shownProfile or type(game) ~= "table" then return end
    shownProfile = prof
    local slot = loadLayouts()[prof]
    if not slot then return end
    local id = mod.id
    for _, owner in ipairs({ game.options, game.save and game.save.options, game.mods }) do
      local all = type(owner) == "table" and owner.modOptions
      if type(all) == "table" then
        all[id] = all[id] or {}
        for k, v in pairs(slot) do all[id][k] = v end
      end
    end
  end
  mod._kimTouchSyncShown = syncShown

  local function now()
    return love and love.timer and love.timer.getTime and love.timer.getTime() or 0
  end

  local function kim()
    local handle = mod.find and mod.find("gen2-aio")
    return handle and handle.exports or nil
  end
  -- gen2-aio 0.9.46: QUICK MENU / KEY ITEM WHEEL / info cards (host module)
  local function Q()
    local q = mod._kimArenaQuick
    return type(q) == "table" and q or nil
  end

  -- ------------------------------------------------------------ options
  local schema = {
    { key = "touchFloating", label = "FLOATING CONTROLS", type = "toggle", default = true,
      help = "Dragon Quest-style touch: touch anywhere for a D-pad, tap anywhere for A, "
        .. "B / START / SELECT on the side. OFF restores the standard on-screen pad." },
    { key = "touchHand", label = "BUTTON SIDE", type = "choice", default = "right",
      choices = { { "RIGHT", "right" }, { "LEFT", "left" } },
      help = "Which screen edge B, START and SELECT sit on." },
    { key = "touchButtonHeight", label = "BUTTON HEIGHT", type = "choice", default = "mid",
      choices = { { "LOW", "low" }, { "MID", "mid" }, { "HIGH", "high" } },
      help = "How high up the edge the B button sits." },
    { key = "touchSize", label = "CONTROL SIZE", type = "choice", default = 100,
      choices = (function()
        local out = {}
        for v = 50, 200, 5 do out[#out + 1] = { v .. "%", v } end
        return out
      end)(),
      help = "Size of the floating D-pad ring and the side buttons, in 5% steps." },
    { key = "touchOpacity", label = "CONTROL OPACITY", type = "choice", default = 70,
      choices = { { "40%", 40 }, { "55%", 55 }, { "70%", 70 }, { "85%", 85 }, { "100%", 100 } } },
    { key = "touchDeadzone", label = "DRAG DEAD ZONE", type = "choice", default = "medium",
      choices = { { "SMALL", "small" }, { "MEDIUM", "medium" }, { "LARGE", "large" } },
      help = "How far a finger must slide before it counts as a direction instead of a tap." },
    { key = "touchBattleTap", label = "TAP MENUS", type = "toggle", default = true,
      help = "Tap menu entries directly: FIGHT / PKMN / PACK / RUN and moves in battle, "
        .. "Pokemon on the POKeMON screen, items and pocket tabs in the PACK." },
    { key = "touchLongPress", label = "LONG PRESS", type = "toggle", default = true,
      help = "Hold a move in battle for its type, power, accuracy, PP and description. "
        .. "Hold a Pokemon on the POKeMON screen (outside battle) and drag it to a new slot; "
        .. "let go on its own row to open its STATS. Hold a battle HUD card or a Pokemon on the "
        .. "in-battle party screen for its info; hold a PACK item to pin it to the KEY ITEM WHEEL. "
        .. "On the overworld, hold START for the QUICK MENU and SELECT for the KEY ITEM WHEEL." },
    { key = "touchHotbar", label = "KEY BAR (...)", type = "toggle", default = true,
      help = "Shows the engine's round \"...\" button (its quick key bar) at the top right. "
        .. "OFF hides it and stops it catching touches; the engine's own KEY BAR setting only "
        .. "applies after a full restart." },
    { key = "touchRunDrag", label = "FAR DRAG HOLDS B", type = "toggle", default = false,
      help = "On the overworld, dragging well past the ring also holds B (for running mods)." },
    -- touchMouse (MOUSE TEST MODE) stays readable but is not listed: a
    -- desktop testing aid that shows the floating controls for a mouse
  }
  mod.options:define(schema)

  local DEADZONE = { small = 0.035, medium = 0.05, large = 0.07 }
  local HEIGHT = { low = 0.84, mid = 0.74, high = 0.60 }

  -- ------------------------------------------------------------ takeover
  local function overlayWanted()
    if opt("touchMouse", false) == true then return true end
    return TouchControls.active == true
  end

  local function takeover()
    if opt("touchFloating", true) == false then return false end
    if okSkin and type(TouchSkin) == "table" and TouchSkin.active then return false end
    if TouchControls.preview then return false end
    return overlayWanted()
  end

  -- Move the stock pad's buttons off-screen while floating controls are on:
  -- they neither draw nor capture touches, and the hotbar keeps working.
  local HIDE = { "dpad", "a", "b", "start", "select", "l", "r" }
  local origLayout = TouchControls.layout
  local hiddenFor, hidden, hiddenBar
  TouchControls.layout = function(self, ...)
    local L = origLayout(self, ...)
    if type(L) ~= "table" then return L end
    -- 0.9.60: KEY BAR OFF moves the engine's "..." hotbar button off-screen
    -- too (it is drawn and hit-tested from this same layout)
    local barOff = opt("touchHotbar", true) == false
    if not takeover() and not barOff then return L end
    if hiddenFor ~= L or hiddenBar ~= barOff then
      hidden = {}
      for k, v in pairs(L) do hidden[k] = v end
      local list = takeover() and HIDE or {}
      if barOff then
        list = { table.unpack and table.unpack(list) or unpack(list) }
        list[#list + 1] = "hotbar"
      end
      for _, k in ipairs(list) do
        if type(L[k]) == "table" then
          local z = {}
          for kk, vv in pairs(L[k]) do z[kk] = vv end
          z.cx, z.cy = -100000, -100000
          hidden[k] = z
        end
      end
      hiddenFor, hiddenBar = L, barOff
    end
    return hidden
  end
  local wasTakeover = nil

  -- ------------------------------------------------------------ geometry
  local function screen()
    local w, h = love.graphics.getDimensions()
    local ox, oy, sw, sh = 0, 0, w, h
    local okSA, SafeArea = pcall(require, "src.core.SafeArea")
    if okSA and SafeArea and type(SafeArea.windowRect) == "function" then
      local ok, a, b, c, d = pcall(SafeArea.windowRect)
      if ok and tonumber(c) and tonumber(d) and c > 0 and d > 0 then ox, oy, sw, sh = a, b, c, d end
    end
    return ox, oy, sw, sh
  end

  local function sizeScale()
    return math.max(0.5, math.min(2, (tonumber(opt("touchSize", 100)) or 100) / 100))
  end

  -- B, START, SELECT in window units.
  local function buttons()
    local ox, oy, sw, sh = screen()
    local short = math.min(sw, sh)
    local s = sizeScale()
    local r = short * 0.085 * s
    local margin = short * 0.035
    local left = opt("touchHand", "right") == "left"
    local landscape = sw > sh
    local hy = landscape and 0.50 or (HEIGHT[opt("touchButtonHeight", "mid")] or 0.74)
    -- Tall screens (over 1.9x, e.g. a Fold cover screen): KIM's battle panel
    -- sits in the bottom third there, so the side buttons go below it.
    if not landscape and sh > sw * 1.9 then
      hy = ({ low = 0.94, mid = 0.915, high = 0.88 })[opt("touchButtonHeight", "mid")] or 0.915
    end
    if landscape and opt("touchButtonHeight", "mid") == "high" then hy = 0.38 end
    if landscape and opt("touchButtonHeight", "mid") == "low" then hy = 0.62 end
    local bx = left and (ox + margin + r) or (ox + sw - margin - r)
    local by = oy + sh * hy
    local pr = r * 0.42
    local pw = r * 1.5
    local sy = by - r - margin - pr
    local startX = left and (bx - r + pw / 2) or (bx + r - pw / 2)
    local selectX = left and (startX + pw + margin * 0.6) or (startX - pw - margin * 0.6)
    return {
      b = { kind = "circle", btn = "b", label = "B", x = bx, y = by, r = r },
      start = { kind = "pill", btn = "start", label = "START", x = startX, y = sy, w = pw, h = pr * 2 },
      select = { kind = "pill", btn = "select", label = "SELECT", x = selectX, y = sy, w = pw, h = pr * 2 },
    }
  end

  local function hit(z, x, y)
    if z.kind == "circle" then
      local dx, dy = x - z.x, y - z.y
      local rr = z.r * 1.15
      return dx * dx + dy * dy <= rr * rr
    end
    local pad = z.h * 0.35
    return math.abs(x - z.x) <= z.w / 2 + pad and math.abs(y - z.y) <= z.h / 2 + pad
  end

  -- ------------------------------------------------------------ battle
  local function topBattle(game)
    local stack = game and game.stack
    local top = stack and type(stack.top) == "function" and stack:top() or nil
    if type(top) == "table" and top.isBattle == true and top.battle ~= nil then return top end
    return nil
  end

  local function battleTargets(game)
    if opt("touchBattleTap", true) == false then return nil end
    local state = topBattle(game)
    if not state then return nil end
    local exports = kim()
    local ui = exports and exports.gen2ModernBattleUi
    if not (ui and type(ui.tapTargets) == "function") then return nil end
    local ok, t = pcall(ui.tapTargets)
    if not ok or type(t) ~= "table" or t.state ~= state then return nil end
    if now() - (tonumber(t.time) or 0) > 0.5 then return nil end
    return t, state
  end

  -- Party / Pack rows and pocket tabs KIM drew last frame, when that screen
  -- is on top and its list (not a submenu, message or quantity box) has focus.
  local function topState(game)
    local stack = game and game.stack
    return stack and type(stack.top) == "function" and stack:top() or nil
  end

  -- What has focus on a Party / Pack screen: "list" (rows, pocket tabs),
  -- "sub" (SWITCH/STATS, USE/TOSS, YES/NO, quantity), or nil (a message or
  -- result the plain A of a tap should answer).
  local LIST_KINDS = { party = true, pack = true, pocket = true, start = true }
  local SUB_KINDS = { partySub = true, modal = true }
  local function screenMode(t, state)
    -- gen2-aio 0.9.8: generic screens publish their own focus ("list" by
    -- default); their cells carry a select function and a button to press.
    if t.generic then
      -- targets drawn for another phase of the same state (a battle YES/NO
      -- that just closed) are stale
      if t.phase ~= nil and t.phase ~= state.phase then return nil end
      local m = t.mode
      if type(m) == "function" then local ok, v = pcall(m, state); m = ok and v or nil end
      return m or "list"
    end
    if t.kind == "start" then
      -- 0.9.47: QUIT / END CONTEST asks YES / NO over the START menu
      if state.phase == "confirm" or state.phase == "confirmContest" then return "sub" end
      return "list"
    end
    if t.kind == "party" then
      if state.submenu then return "sub" end
      if state.itemResult then return nil end
      return "list"
    elseif t.kind == "pack" then
      if state.submenu or state.confirm or state.qtyState then return "sub" end
      if state.staleRows or state.switching or state.message then return nil end
      return "list"
    end
    return nil
  end

  local function screenTargets(game)
    if opt("touchBattleTap", true) == false then return nil end
    local exports = kim()
    local fn = exports and exports.screenTapTargets
    if type(fn) ~= "function" then return nil end
    local ok, t = pcall(fn)
    if not ok or type(t) ~= "table" then return nil end
    local state = topState(game)
    if not state or t.state ~= state then return nil end
    if now() - (tonumber(t.time) or 0) > 0.5 then return nil end
    local smode = screenMode(t, state)
    if not smode then return nil end
    return t, state, smode
  end

  local function cellIn(t, x, y, kinds)
    for _, c in ipairs(t and t.cells or {}) do
      if kinds[c.kind] and x >= c.x and x <= c.x + c.w and y >= c.y and y <= c.y + c.h then
        return c
      end
    end
    return nil
  end

  local function cellAt(t, x, y)
    for _, c in ipairs(t and t.cells or {}) do
      if x >= c.x and x <= c.x + c.w and y >= c.y and y <= c.y + c.h then return c end
    end
    return nil
  end

  -- gen2-aio: the close button a Modern menu window drew last frame (top
  -- right of the window); a tap on it is B and only B.
  local function closeTarget(game)
    local exports = kim()
    local fn = exports and exports.menuCloseRect
    local r
    if type(fn) == "function" then local ok, v = pcall(fn); r = ok and v or nil end
    if type(r) ~= "table" then return nil end
    local state = topState(game)
    if state == nil or r.state ~= state then return nil end
    if now() - (tonumber(r.time) or 0) > 0.5 then return nil end
    return r, state
  end
  local function inClose(r, x, y)
    local h = type(r.hit) == "table" and r.hit or r
    return x >= h.x and x <= h.x + h.w and y >= h.y and y <= h.y + h.h
  end

  local function inPanel(t, x, y)
    local p = t and t.panel
    return p and x >= p.x and x <= p.x + p.w and y >= p.y and y <= p.y + p.h
  end

  -- ------------------------------------------------------------ input
  local pointers = {}   -- id -> gesture
  local ring = nil      -- the live movement gesture, for drawing

  local function buzz()
    if type(TouchControls.buzz) == "function" then pcall(TouchControls.buzz, TouchControls.haptics) end
  end

  local function press(game, btn) local ok, token = pcall(mod.input.press, mod.input, game, btn); return ok and token or nil end
  local function release(token) if token then pcall(mod.input.release, mod.input, token) end end
  local function tap(game, btn) pcall(mod.input.tap, mod.input, game, btn) end

  local function deadzone()
    local _, _, sw, sh = screen()
    return math.min(sw, sh) * (DEADZONE[opt("touchDeadzone", "medium")] or 0.05) * sizeScale()
  end

  local function overworld(game)
    local stack = game and game.stack
    local top = stack and type(stack.top) == "function" and stack:top() or nil
    return top ~= nil and (top == game.overworld or top == game.world)
  end

  local function endGesture(id)
    local g = pointers[id]
    if not g then return nil end
    pointers[id] = nil
    release(g.token); release(g.runToken); release(g.aToken); g.aToken = nil
    if ring == g then ring = nil end
    return g
  end

  local function setDir(game, g, dir)
    if g.dir == dir then return end
    release(g.token); g.token = nil
    g.dir = dir
    g.dirSince, g.lastRep = now(), now()
    if dir then g.token = press(game, dir); buzz() end
  end

  -- gen2-aio 0.9.40: LONG PRESS (setting touchLongPress, default on).
  -- Hold a battle move ~0.45 s for its full info; hold a Pokemon on the PKMN
  -- list (outside battle) to pick it up and drag it to a new slot -- let go
  -- on its own row to open its STATS instead. A long press never also taps A.
  local LONG = 0.45
  local popup = nil      -- { title, lines } shown until the next touch

  local PHYSICAL = { NORMAL = true, FIGHTING = true, FLYING = true, POISON = true,
    GROUND = true, ROCK = true, BUG = true, GHOST = true, STEEL = true }

  local function moveInfo(game, state, index)
    local fighter = state.battle and state.battle.player
    local entry = fighter and fighter.moves and fighter.moves[index]
    if type(entry) ~= "table" or not entry.id then return nil end
    local data = game and game.data
    local def = data and data.moves and data.moves[entry.id] or {}
    local typ = tostring(def.type or "???"):gsub("_TYPE$", "")
    local power = tonumber(def.power) or 0
    local acc = tonumber(def.accuracy)
    if acc and acc <= 1 then acc = acc * 100 end
    if acc and acc > 100 then acc = acc * 100 / 255 end
    local name = def.name or tostring(entry.id):gsub("_", " ")
    local lines = {
      ("TYPE  %s   %s"):format(typ, power < 2 and "STATUS" or (PHYSICAL[typ] and "PHYSICAL" or "SPECIAL")),
      ("POWER %s   ACC %s"):format(power >= 2 and tostring(power) or "---",
        acc and (math.floor(acc + 0.5) .. "%") or "---"),
      ("PP    %d/%d"):format(tonumber(entry.pp) or 0, tonumber(entry.maxPp or def.pp) or 0),
    }
    local desc = tostring(def.description or "")
    for line in (desc .. "<NEXT>"):gmatch("(.-)<NEXT>") do
      if line ~= "" then lines[#lines + 1] = line end
    end
    return { title = tostring(name):upper(), lines = lines }
  end

  local function partyDragOk(state)
    return type(state) == "table" and type(state.beginSwitch) == "function"
      and type(state.finishSwitch) == "function" and not state.submenu
      and not state.switchFrom and type(state.party) == "table" and #state.party > 1
      and state.save ~= nil and state.save.party == state.party   -- not a battle copy
  end

  -- 0.9.45 HOLD TO REPEAT: in a menu, a joystick direction held past
  -- REPEAT_DELAY keeps stepping instead of one row per push. gen2-aio 0.9.52:
  -- slowed from 0.35 s / 11 rows a second, which overshot rows on the Fold.
  local REPEAT_DELAY, REPEAT_INTERVAL = 0.5, 0.18
  local function repeatDirs(game)
    if topState(game) == nil then return end   -- overworld walking holds natively
    for _, g in pairs(pointers) do
      if g.kind == "move" and g.dir and g.token and g.dirSince then
        local t = now()
        if t - g.dirSince > REPEAT_DELAY and t - (g.lastRep or 0) > REPEAT_INTERVAL then
          release(g.token)
          g.token = press(game, g.dir)
          g.lastRep = t
        end
      end
    end
  end

  local lastFrame = nil
  local function freeScrollStep()
    local t = now()
    local dt = lastFrame and math.min(0.05, t - lastFrame) or 0
    lastFrame = t
    local FS = mod._kimFreeScroll
    if type(FS) ~= "table" or dt <= 0 then return end
    for _, e in pairs(FS) do
      if not e.held and e.vel and e.vel ~= 0 then
        e.offset = (tonumber(e.offset) or 0) + e.vel * dt
        e.vel = e.vel * math.exp(-3.2 * dt)
        if math.abs(e.vel) < 0.6 then e.vel = 0 end
      end
    end
  end
  local function checkLong(game)
    pcall(freeScrollStep)
    pcall(repeatDirs, game)
    if opt("touchLongPress", true) == false then return end
    for _, g in pairs(pointers) do
      if not g.long and g.t0 and now() - g.t0 >= LONG then
        local c = g.cell
        if g.kind == "cell" and c and c.kind == "move" then
          local _, state = battleTargets(game)
          if state and state == g.state and state.phase == "moves" then
            local info = moveInfo(game, state, c.index)
            if info then g.long = true; popup = info; buzz() end
          end
        elseif g.kind == "move" and not g.dragged and not g.aToken then
          -- 0.9.42: hold on an open text box = hold A (Crystal speeds text up)
          local w = game and game.world
          if w and w.textbox then
            g.long = true
            g.aToken = press(game, "a")
          end
        elseif g.kind == "screencell" and c and c.kind == "party" and not g.generic then
          local state = g.state
          if topState(game) == state and partyDragOk(state) then
            g.long, g.drag = true, true
            state.index = c.index
            pcall(state.beginSwitch, state, c.index)
            buzz()
          elseif topState(game) == state and Q() and type(state.party) == "table" then
            -- 0.9.46: in battle (no reordering there): the Pokemon's info card
            local okI, card = pcall(Q().monInfo, game, state.party[c.index])
            if okI and card then g.long = true; popup = card; buzz() else g.t0 = nil end
          else
            g.t0 = nil
          end
        elseif g.kind == "screencell" and c and c.kind == "pack" and not g.generic then
          -- 0.9.46: hold an item in the PACK: pin / unpin it on the KEY ITEM WHEEL
          local state = g.state
          local row = type(state.rows) == "table" and state.rows[c.index]
          local q = Q()
          if topState(game) == state and row and row.id and q then
            local okP, card = pcall(q.togglePin, game, row.id)
            if okP and card then g.long = true; popup = card; buzz() else g.t0 = nil end
          else
            g.t0 = nil
          end
        elseif g.kind == "hud" then
          local q = Q()
          local okI, card = false, nil
          if q and topBattle(game) == g.state then okI, card = pcall(q.battleInfo, game, g.state, g.side) end
          if okI and card then g.long = true; popup = card; buzz() else g.t0 = nil end
        elseif g.kind == "button" and g.deferred then
          local q = Q()
          if g.btn == "start" then
            local okO, opened = false, false
            if q and q.ready(game) then okO, opened = pcall(q.openQuick, game) end
            if okO and opened then g.long = true; buzz() else g.t0 = nil end
          else
            local okO, opened = false, false
            if q and q.ready(game) then okO, opened = pcall(q.wheelOpen, game) end
            -- an empty wheel says so; either way the hold is used up
            if okO then g.long = true; buzz() else g.t0 = nil end
          end
        end
      end
    end
  end

  local function onPressed(game, ev)
    local x, y = ev.x, ev.y
    if popup then popup = nil; pointers[ev.id] = { kind = "swallow" }; return end
    -- 0.9.46: an open KEY ITEM WHEEL takes every touch (tap a slot / tap away)
    local q = Q()
    if q and q.wheelActive and q.wheelActive() then
      pointers[ev.id] = { kind = "wheel" }
      pcall(q.wheelHover, x, y)
      return
    end
    for _, z in pairs(buttons()) do
      if hit(z, x, y) then
        -- 0.9.46: on the open overworld START and SELECT wait for the finger:
        -- a tap is the button, a hold opens the QUICK MENU / KEY ITEM WHEEL
        local deferred = (z.btn == "start" or z.btn == "select")
          and opt("touchLongPress", true) ~= false and q and q.ready and q.ready(game)
        if deferred then
          pointers[ev.id] = { kind = "button", zone = z, deferred = true, btn = z.btn, t0 = now() }
        else
          pointers[ev.id] = { kind = "button", zone = z, token = press(game, z.btn) }
        end
        buzz()
        return
      end
    end
    local cr, cstate = closeTarget(game)
    if cr and inClose(cr, x, y) then
      pointers[ev.id] = { kind = "close", rect = cr, state = cstate }
      return
    end
    local st, sstate, smode = screenTargets(game)
    if st and st.freeScroll then
      -- a touch catches a list that is still gliding
      local FS = mod._kimFreeScroll
      local e = type(FS) == "table" and FS[sstate]
      if e and e.vel and e.vel ~= 0 then e.vel = 0; pointers[ev.id] = { kind = "swallow" }; return end
    end
    if st then
      local c
      if st.generic then c = cellAt(st, x, y)
      else c = cellIn(st, x, y, smode == "sub" and SUB_KINDS or LIST_KINDS) end
      if c then
        pointers[ev.id] = { kind = "screencell", cell = c, state = sstate,
          screen = st.kind, mode = smode, generic = st.generic, targets = st, t0 = now(),
          sx = x, sy = y }
        return
      end
      if smode == "sub" then
        -- a submenu is open: a tap that misses its options does nothing
        -- (B backs out); a drag still moves its cursor
        -- 0.9.47: it used to fall through to A (picking whatever option was
        -- highlighted); a tap beside a popup menu now closes it (B), as on a
        -- phone. Generic "sub" screens (the naming keyboard, where B deletes)
        -- ignore the miss.
        -- gen2-aio 0.9.54: a miss beside a Party / Pack / START popup is A
        -- again (tap anywhere = A; B is the side button). Only generic "sub"
        -- screens (the naming keyboard) still ignore the miss.
        local g = { kind = "move", ox = x, oy = y, x = x, y = y, t0 = now(),
          dragged = false, battleMenu = false, missTap = nil }
        if st.generic then g.missTap = false end
        pointers[ev.id] = g
        ring = g
        return
      end
    end
    local t, state = battleTargets(game)
    if t and (t.phase == "menu" or t.phase == "moves" or t.phase == "choose-forget") then
      local c = cellAt(t, x, y)
      if c then
        pointers[ev.id] = { kind = "cell", cell = c, state = state, phase = t.phase, t0 = now(),
          sx = x, sy = y }
        return
      end
    end
    -- 0.9.46: hold a battle HUD card for that Pokemon's info
    local hb = topBattle(game)
    local rects = mod._kimArenaHudRects
    if hb and type(rects) == "table" and rects.state == hb and now() - (tonumber(rects.time) or 0) < 0.5 then
      for _, side in ipairs({ "enemy", "player" }) do
        local r = rects[side]
        if r and rects[side .. "Shown"] and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
          pointers[ev.id] = { kind = "hud", side = side, state = hb, t0 = now(), sx = x, sy = y }
          return
        end
      end
    end
    local g = { kind = "move", ox = x, oy = y, x = x, y = y, t0 = now(), dragged = false,
      battleMenu = false,   -- 0.9.5: a tap that misses every button is A everywhere
      inPanel = t ~= nil and inPanel(t, x, y) }
    pointers[ev.id] = g
    ring = g
  end

  local function onMoved(game, ev)
    local g = pointers[ev.id]
    if g and (g.kind == "wheel" or (g.kind == "button" and g.deferred and g.long and g.btn == "select")) then
      local q = Q()
      if q then pcall(q.wheelHover, ev.x, ev.y) end
      return
    end
    if g and g.kind == "hud" then
      local dx, dy = ev.x - g.sx, ev.y - g.sy
      if dx * dx + dy * dy > deadzone() ^ 2 then g.t0, g.moved = nil, true end
      return
    end
    if g and g.drag then
      local st = screenTargets(game)
      local c = st and cellIn(st, ev.x, ev.y, { party = true })
      if c and g.state then g.state.index = c.index end
      return
    end
    -- 0.9.45 SWIPE: dragging across a menu scrolls it -- one row per row
    -- height travelled (finger up = further down the list, like a phone),
    -- left/right steps for sideways swipes -- and never ends in an A press.
    if g and (g.kind == "cell" or g.kind == "screencell") and not g.long and g.sx then
      local c = g.cell
      local dx, dy = ev.x - g.sx, ev.y - g.sy
      if not g.swipe and (math.abs(dy) > c.h * 0.6 or math.abs(dx) > c.w * 0.45) then
        g.swipe = math.abs(dy) * 1.2 >= math.abs(dx) and "v" or "h"
        g.t0, g.done = nil, 0
      end
      -- 0.9.47 FREE SCROLL: a screen that supports it is dragged like a web
      -- page -- the list window follows the finger (and keeps going after a
      -- flick), the selection stays where it was
      local FS = mod._kimFreeScroll
      local st = g.targets
      if g.swipe == "v" and type(FS) == "table" and st and st.freeScroll and g.state then
        local e = FS[g.state]
        if not e then
          e = { offset = tonumber(st.scroll) or 0 }
          FS[g.state] = e
        end
        if not g.fs then
          g.fs = { start = e.offset, rowH = math.max(8, tonumber(st.rowH) or c.h),
            lastT = now(), lastOff = e.offset, vel = 0 }
        end
        e.vel, e.held = 0, true
        local off = g.fs.start - (ev.y - g.sy) / g.fs.rowH
        local t = now()
        local dt = t - g.fs.lastT
        if dt > 0.004 then
          local v = (off - g.fs.lastOff) / dt
          g.fs.vel = g.fs.vel * 0.4 + v * 0.6
          g.fs.lastT, g.fs.lastOff = t, off
        end
        e.offset = off
        return
      end
      if g.swipe then
        local step = (g.swipe == "v" and c.h or c.w * 0.6) * 0.9
        local d = g.swipe == "v" and dy or dx
        while d - g.done * step >= step do
          tap(game, g.swipe == "v" and "up" or "left"); g.done = g.done + 1
        end
        while d - g.done * step <= -step do
          tap(game, g.swipe == "v" and "down" or "right"); g.done = g.done - 1
        end
        return
      end
    end
    if g and (g.kind == "cell" or g.kind == "screencell") and not g.long and g.t0 then
      -- a finger that wanders off before the hold completes is not a long press
      local c = g.cell
      if not (ev.x >= c.x and ev.x <= c.x + c.w and ev.y >= c.y and ev.y <= c.y + c.h) then g.t0 = nil end
    end
    if not g or g.kind ~= "move" then return end
    g.x, g.y = ev.x, ev.y
    local dz = deadzone()
    local dx, dy = g.x - g.ox, g.y - g.oy
    local d = math.sqrt(dx * dx + dy * dy)
    if not g.dragged and d > dz then g.dragged = true end
    if not g.dragged then return end
    -- the ring follows a thumb that strays past its rim
    local maxR = dz * 2.6
    if d > maxR then
      local k = (d - maxR) / d
      g.ox, g.oy = g.ox + dx * k, g.oy + dy * k
      dx, dy = g.x - g.ox, g.y - g.oy
      d = maxR
    end
    local dir
    if d > dz * 0.6 then
      if math.abs(dx) > math.abs(dy) then dir = dx > 0 and "right" or "left"
      else dir = dy > 0 and "down" or "up" end
    end
    setDir(game, g, dir)
    if opt("touchRunDrag", false) == true and overworld(game) then
      local far = d >= maxR * 0.98
      if far and not g.runToken then g.runToken = press(game, "b")
      elseif not far and g.runToken then release(g.runToken); g.runToken = nil end
    end
  end

  local function onReleased(game, ev)
    local g = endGesture(ev.id)
    if g and g.fs then
      -- let go of a free-scroll drag: fling (rows per second, capped)
      local FS = mod._kimFreeScroll
      local e = type(FS) == "table" and g.state and FS[g.state]
      if e then
        e.held = nil
        local v = g.fs.vel
        if now() - g.fs.lastT > 0.08 then v = 0 end   -- finger stopped before lifting
        e.vel = math.max(-60, math.min(60, v))
      end
      return
    end
    if not g or g.kind == "swallow" or g.swipe then return end
    if g.kind == "close" then
      -- lifted on the close button, with the same screen still on top: B
      if inClose(g.rect, ev.x, ev.y) and topState(game) == g.state then
        tap(game, "b"); buzz()
      end
      return
    end
    if g.kind == "wheel" then
      local q = Q()
      if q then pcall(q.wheelRelease, ev.x, ev.y, true) end
      return
    end
    if g.kind == "button" and g.deferred then
      if not g.long then tap(game, g.btn)
      elseif g.btn == "select" then
        local q = Q()
        if q and q.wheelActive() then pcall(q.wheelRelease, ev.x, ev.y, false) end
      end
      return
    end
    if g.kind == "hud" then
      if not g.long and not g.moved then tap(game, "a"); buzz() end
      return
    end
    if g.long then
      if g.aToken then release(g.aToken); g.aToken = nil end
      if g.drag then
        local state = g.state
        if state and state.switchFrom then
          if state.index and state.index ~= state.switchFrom then
            pcall(state.finishSwitch, state)
          else
            state.switchFrom = nil
            if type(state.openStats) == "function" then pcall(state.openStats, state) end
          end
          buzz()
        end
      end
      return
    end
    if g.kind == "screencell" then
      local c = g.cell
      local inside = ev.x >= c.x and ev.x <= c.x + c.w and ev.y >= c.y and ev.y <= c.y + c.h
      local state = g.state
      if not (inside and topState(game) == state
          and screenMode(g.generic and g.targets or { kind = g.screen }, state) == g.mode) then return end
      if g.generic then
        if type(c.select) == "function" then pcall(c.select, state) end
        local btn = c.button
        if btn == nil then btn = "a" end
        if btn then tap(game, btn) end
        buzz()
        return
      end
      if c.kind == "partySub" and state.submenu then
        state.submenu.index = c.index
        tap(game, "a"); buzz()
      elseif c.kind == "modal" then
        if state.submenu then state.submenu.index = c.index
        elseif state.confirm then state.confirm.choice = c.index
        elseif state.phase == "confirm" or state.phase == "confirmContest" then
          state.confirmChoice = c.index
        end
        tap(game, "a"); buzz()
      elseif c.kind == "pocket" then
        local delta = c.index - (tonumber(state.pocketIndex) or c.index)
        if delta ~= 0 and type(state.switchPocket) == "function" then
          pcall(state.switchPocket, state, delta); buzz()
        end
      elseif c.kind == "start" and type(state.list) == "table" then
        state.list.index = c.index
        tap(game, "a"); buzz()
      elseif c.kind == "party" or c.kind == "pack" then
        state.index = c.index
        tap(game, "a"); buzz()
      end
      return
    end
    if g.kind == "cell" then
      local t, state = battleTargets(game)
      local c = g.cell
      local inside = ev.x >= c.x and ev.x <= c.x + c.w and ev.y >= c.y and ev.y <= c.y + c.h
      if inside and state == g.state and state.phase == g.phase then
        if c.kind == "menu" and state.phase == "menu" then
          state.menuIndex = c.index
          tap(game, "a"); buzz()
        elseif c.kind == "forget" and state.phase == "choose-forget" then
          state.forgetIndex = c.index
          tap(game, "a"); buzz()
        elseif c.kind == "move" and state.phase == "moves" then
          state.moveIndex = c.index
          tap(game, "a"); buzz()
        end
      end
      return
    end
    if g.kind == "move" and not g.dragged and now() - g.t0 < 0.45 then
      -- a tap is A, except on the open part of a battle menu, where only the
      -- cells mean something (an A there would pick whatever is highlighted)
      if g.missTap ~= nil then
        if g.missTap then tap(game, g.missTap); buzz() end
      elseif not (g.battleMenu) then tap(game, "a"); buzz() end
    end
  end

  -- Below KIM's Modern UI link (100): KIM's menus see each touch first.
  mod.hooks:wrap("input.pointer", function(next, game, ev)
    if type(ev) ~= "table" or not takeover() then return next(game, ev) end
    if ev.source == "mouse" and opt("touchMouse", false) ~= true then return next(game, ev) end
    if ev.source == "mouse" and ev.phase == "moved" and not pointers[ev.id] then return next(game, ev) end
    local ok, err = pcall(function()
      if ev.phase == "pressed" then onPressed(game, ev)
      elseif ev.phase == "moved" then onMoved(game, ev)
      elseif ev.phase == "released" then onReleased(game, ev)
      elseif ev.phase == "cancelled" then endGesture(ev.id) end
    end)
    if not ok then log("warn", "KIM Touch: %s", tostring(err)) end
    return true
  end, 10)

  -- Drop every hold if the controls switch off mid-gesture.
  local function releaseAll()
    for id in pairs(pointers) do endGesture(id) end
    ring = nil
  end

  -- ------------------------------------------------------------ drawing
  local fonts = {}
  local function font(px)
    px = math.max(8, math.floor(px + 0.5))
    if not fonts[px] then
      -- gen2-aio: touch labels share KIM's UI font
      local arenaFont = mod._kimArenaFont
      local ok, f = false, nil
      if type(arenaFont) == "function" then ok, f = pcall(arenaFont, px) end
      if not (ok and f) then ok, f = pcall(love.graphics.newFont, px) end
      fonts[px] = ok and f or love.graphics.getFont()
    end
    return fonts[px]
  end

  local function theme()
    local exports = kim()
    local styleFn = exports and exports.kimStyle
    local ok, S = false, nil
    if type(styleFn) == "function" then ok, S = pcall(styleFn) end
    local t = ok and S and S.theme and S.theme() or nil
    return t or { surface = { .075, .105, .17, .96 }, accent = { .48, .86, 1, 1 },
      text = { .96, .98, 1, 1 }, frame = { .48, .86, 1, 1 }, selected = { .18, .43, .72, 1 } }
  end

  local function held(btn)
    for _, g in pairs(pointers) do
      if g.kind == "button" and g.zone.btn == btn then return true end
    end
    return false
  end

  local function draw()
    local G = love.graphics
    local alpha = math.max(0.2, math.min(1, (tonumber(opt("touchOpacity", 70)) or 70) / 100))
    local th = theme()
    G.push("all")
    G.origin()
    for _, z in pairs(buttons()) do
      local on = held(z.btn)
      local a = alpha * (on and 1 or 0.85)
      local fill = on and (th.selected or th.accent) or th.surface
      G.setColor(fill[1], fill[2], fill[3], a * 0.85)
      local f
      if z.kind == "circle" then
        G.circle("fill", z.x, z.y, z.r)
        G.setColor(th.frame[1], th.frame[2], th.frame[3], a)
        G.setLineWidth(math.max(2, z.r * 0.08)); G.circle("line", z.x, z.y, z.r)
        f = font(z.r * 0.9)
      else
        local rr = z.h / 2
        G.rectangle("fill", z.x - z.w / 2, z.y - z.h / 2, z.w, z.h, rr, rr)
        G.setColor(th.frame[1], th.frame[2], th.frame[3], a)
        G.setLineWidth(math.max(1.5, z.h * 0.07))
        G.rectangle("line", z.x - z.w / 2, z.y - z.h / 2, z.w, z.h, rr, rr)
        f = font(z.h * 0.38)
      end
      G.setFont(f)
      G.setColor(th.text[1], th.text[2], th.text[3], math.min(1, a + 0.1))
      -- gen2-aio: the SELECT pill reads BALL while SELECT throws a quick ball
      local label = z.label
      if z.btn == "select" then
        local qb = mod._kimArenaQuickBallReady
        if type(qb) == "function" then
          local okQ, ready = pcall(qb)
          if okQ and ready then label = "BALL" end
        end
      end
      G.printf(label, z.x - 200, z.y - f:getHeight() / 2, 400, "center")
    end
    if popup then
      local W, H = G.getDimensions()
      local f = font(math.max(14, math.min(W, H) * 0.035))
      local tf = font(math.max(16, math.min(W, H) * 0.042))
      local pw = math.min(W * 0.9, 760)
      local lh = f:getHeight() * 1.25
      local ph = tf:getHeight() * 1.6 + #popup.lines * lh + lh * 0.6
      local px, py = (W - pw) / 2, H * 0.18
      local Style = mod._kantoInMotionGen2Ui
      if Style and Style.panel then pcall(Style.panel, px, py, pw, ph, th)
      else
        G.setColor(th.surface[1], th.surface[2], th.surface[3], 0.96)
        G.rectangle("fill", px, py, pw, ph, 10, 10)
        G.setColor(th.frame[1], th.frame[2], th.frame[3], 1)
        G.setLineWidth(3); G.rectangle("line", px, py, pw, ph, 10, 10)
      end
      G.setFont(tf); G.setColor(th.accent[1], th.accent[2], th.accent[3], 1)
      G.print(popup.title, px + pw * 0.05, py + tf:getHeight() * 0.4)
      G.setFont(f); G.setColor(th.text[1], th.text[2], th.text[3], 1)
      for i, line in ipairs(popup.lines) do
        G.print(line, px + pw * 0.05, py + tf:getHeight() * 1.6 + (i - 1) * lh)
      end
    end
    local g = ring
    if g and g.dragged then
      local dz = deadzone()
      local R = dz * 2.6
      G.setColor(th.surface[1], th.surface[2], th.surface[3], alpha * 0.55)
      G.circle("fill", g.ox, g.oy, R)
      G.setColor(th.frame[1], th.frame[2], th.frame[3], alpha * 0.9)
      G.setLineWidth(math.max(2, R * 0.04)); G.circle("line", g.ox, g.oy, R)
      -- the four arms, the held one lit
      for dir, v in pairs({ up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 } }) do
        local cx, cy = g.ox + v[1] * R * 0.62, g.oy + v[2] * R * 0.62
        local s = R * 0.20
        local lit = g.dir == dir
        local c = lit and th.accent or th.text
        G.setColor(c[1], c[2], c[3], alpha * (lit and 1 or 0.45))
        local px, py = -v[2], v[1]
        G.polygon("fill", cx + v[1] * s, cy + v[2] * s,
          cx - v[1] * s * 0.6 + px * s, cy - v[2] * s * 0.6 + py * s,
          cx - v[1] * s * 0.6 - px * s, cy - v[2] * s * 0.6 - py * s)
      end
      local kx, ky = g.x - g.ox, g.y - g.oy
      local kd = math.sqrt(kx * kx + ky * ky)
      if kd > R then kx, ky = kx / kd * R, ky / kd * R end
      G.setColor(th.accent[1], th.accent[2], th.accent[3], alpha * 0.9)
      G.circle("fill", g.ox + kx, g.oy + ky, R * 0.30)
    end
    G.pop()
  end

  mod.hooks:wrap("render.hud", function(next, game, viewport)
    pcall(syncShown, game)
    local result = { pcall(next, game, viewport) }
    local ok = table.remove(result, 1)
    if not ok then error(result[1], 0) end
    local on = takeover()
    if wasTakeover ~= nil and on ~= wasTakeover then
      releaseAll()
      if type(TouchControls.reset) == "function" then pcall(TouchControls.reset, TouchControls) end
    end
    wasTakeover = on
    if on then pcall(checkLong, game) else popup = nil end
    local visible = on and not TouchControls.controllerHidden
    if visible then
      local drawn, err = pcall(draw)
      if not drawn then log("warn", "KIM Touch draw: %s", tostring(err)) end
    end
    return (table.unpack or unpack)(result)
  end, 30000)

  -- ------------------------------------------------------------ menu rows
  local okRows, InGameOptions = pcall(function()
    local src = assert(mod:read("lib/ingame_options.lua"))
    return assert((loadstring or load)(src, "@" .. tostring(mod.path) .. "/lib/ingame_options.lua"))()
  end)
  if okRows and type(InGameOptions) == "table" and InGameOptions.install then
    pcall(InGameOptions.install, mod, schema, "KIM TOUCH")
  end

  mod.exports.version = "0.3.0"
  mod.exports.active = takeover
  log("info", "KIM Touch ready")
end
