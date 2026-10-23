-- KIM_ARENA 0.9.46: QUICK MENU, AREA DEX, KEY ITEM WHEEL and info cards.
--
-- QUICK MENU (hold START on the overworld with touch, or START -> QUICK):
--   POKeGEAR, FLY (the real Fly map; badge / outdoor / party checks are the
--   engine's own), AREA DEX, DAY-CARE, TODAY, KEY ITEMS. Pages are Crystal's
--   OPTION screen class (KIM-themed, tappable) through the hub's Hub.page;
--   AREA DEX is its own screen (sprites, black silhouettes for unseen).
-- KEY ITEM WHEEL (hold SELECT on the overworld with touch): every usable key
--   item, pinned ones first (hold an item in the PACK to pin / unpin). Picking
--   one registers it (so a plain SELECT repeats it) and uses it through
--   Crystal's own SELECT path (Game2:useSelectItem).
-- INFO CARDS for KIM Touch's long press: a battler (enemy / your HUD card,
--   a Pokemon on the in-battle party screen).
--
-- Everything that has to happen on the open overworld (Pokegear, Fly, item
-- use) is queued and run on the first frame the overworld takes input again,
-- after the menus that asked for it are gone.
return function(host)
  local mod, diag = host.mod, host.diag or function() end
  local G = love and love.graphics
  local M = {}

  local function opt(key, default)
    local f = rawget(mod, "_kimArenaOpt")
    if type(f) == "function" then
      local ok, v = pcall(f, key, default)
      if ok and v ~= nil then return v end
    end
    return default
  end
  local function now() return love and love.timer and love.timer.getTime() or os.clock() end
  local function req(name) local ok, m = pcall(require, name); return ok and m or nil end

  -- ------------------------------------------------------------ helpers
  local function data(game) return game and game.data or {} end
  local function speciesName(game, sp)
    local def = data(game).pokemon and data(game).pokemon[sp]
    return tostring(def and def.name or sp or "?"):upper()
  end
  local function itemName(game, id)
    local def = data(game).items and data(game).items[id]
    return tostring(def and def.name or tostring(id):gsub("_", " ")):upper()
  end
  local function dex(game)
    local save = game and game.save
    local d = save and save.pokedex or {}
    return d.seen or {}, d.caught or {}
  end
  local function typeList(t)
    local out = {}
    for _, v in ipairs(type(t) == "table" and t or {}) do
      local s = tostring(v):upper():gsub("_TYPE$", ""):gsub("^TYPE_", "")
      if out[#out] ~= s then out[#out + 1] = s end
    end
    return table.concat(out, " / ")
  end

  -- the overworld with nothing open, taking input (Game2's START/SELECT gate)
  function M.ready(game)
    if type(game) ~= "table" or game.phase ~= "play" then return false end
    local w = game.world
    if not (w and w.player and game.stack) then return false end
    if game.stack:top() ~= nil then return false end
    if w.battleActive then return false end
    if type(w.acceptsMenuInput) == "function" then
      local ok, v = pcall(w.acceptsMenuInput, w)
      return ok and v == true
    end
    return true
  end

  -- actions that need the open overworld
  local pending = nil
  local function later(fn) pending = { fn = fn, at = now() } end
  mod.hooks:wrap("input.step", function(nextFn, game, dt)
    if pending then
      if now() - pending.at > 5 then pending = nil
      elseif M.ready(game) then
        local p = pending; pending = nil
        local ok, err = pcall(p.fn, game)
        if not ok then diag("quick menu", "action failed: " .. tostring(err):sub(1, 100)) end
      end
    end
    return nextFn(game, dt)
  end, 5)

  local function say(game, text)
    if type(game.say) == "function" then pcall(game.say, game, text) end
  end

  -- close the quick page (and START menu under it) back to the overworld
  local quickPages = setmetatable({}, { __mode = "k" })
  local function closeToWorld(game)
    local okSM, StartMenu = pcall(require, "src.ui.gen2.StartMenu")
    for _ = 1, 8 do
      local top = game.stack:top()
      if top == nil then break end
      local isStart = okSM and getmetatable(top) == StartMenu
      if not (quickPages[top] or isStart) then break end
      game.stack:pop()
    end
  end

  local function hub() return rawget(mod, "_kimArenaHub") end
  local function page(game, rows, title, sub)
    local H = hub()
    if not (H and H.page) then return nil end
    local p = H.page(game, rows, title)
    if p then rawset(p, "kimSubtitle", sub) end
    return p
  end
  local function info(label, value, hint)
    return { id = "kimArena.q." .. tostring(label), label = label, info = true, hint = hint,
      value = function() return value or "" end }
  end

  -- ------------------------------------------------------------ POKEGEAR
  local function hasPokegear(game)
    local SM = req("src.ui.gen2.StartMenu")
    if SM and SM.availability then
      local ok, a = pcall(SM.availability, { save = game.save, game = game })
      if ok and type(a) == "table" then return a.pokegear == true end
    end
    return true
  end
  local function openPokegear(game)
    if type(game.pushStartMenuItem) == "function" then
      game:pushStartMenuItem("pokegear")
    end
  end

  -- ------------------------------------------------------------ FLY
  local function fly(game)
    local w = game.world
    local FM = req("src.world.gen2.FieldMoves")
    if not (w and FM) then return end
    local ctx
    if type(w.fieldContext) == "function" then
      local ok, c = pcall(w.fieldContext, w, nil); ctx = ok and c or nil
    end
    local mon = FM.partyMoveUser(game.save and game.save.party or {}, "FLY", ctx)
    if not mon then
      say(game, "No POKeMON in your\nparty can use FLY.")
      return
    end
    w:useFieldMove("FLY", mon)
  end

  -- ------------------------------------------------------------ DAY-CARE
  local COMPAT = { none = "NO INTEREST", interest = "LOW", friendly = "GOOD", cares = "VERY GOOD",
    brimming = "BEST" }
  local function dayCareRows(game)
    local rows = {}
    local save = game.save or {}
    local dc = save.dayCare or {}
    local B = req("src.core.gen2.Breeding")
    local d = data(game)
    local any = false
    for _, side in ipairs({ { "man", "MAN" }, { "lady", "LADY" } }) do
      local slot = dc[side[1]]
      local mon = type(slot) == "table" and slot.mon
      if type(mon) == "table" then
        any = true
        local name = tostring(mon.nickname or speciesName(game, mon.species)):upper()
        local lv = tostring(mon.level or "?")
        local price = ""
        if B and B.levelGrowth then
          local ok, stored, newLv, grown = pcall(B.levelGrowth, d, slot)
          if ok then
            lv = (newLv ~= stored) and (("LV %d > %d"):format(stored, newLv)) or ("LV " .. stored)
            local okP, p = pcall(B.retrievePrice, grown)
            if okP then price = ("$%d"):format(p) end
          end
        end
        rows[#rows + 1] = info(side[2] .. ": " .. name, lv)
        if price ~= "" then rows[#rows + 1] = info("  TAKE BACK", price) end
      else
        rows[#rows + 1] = info(side[2] .. ": EMPTY", "")
      end
    end
    local m1 = dc.man and dc.man.mon
    local m2 = dc.lady and dc.lady.mon
    if m1 and m2 and B and B.compatibility then
      local ok, v = pcall(B.compatibility, d, m1, m2, { dayCare = true })
      if ok then
        local okT, key = pcall(B.compatibilityText, v)
        rows[#rows + 1] = info("GET ALONG", COMPAT[okT and key or ""] or tostring(v))
      end
    end
    if dc.hasEgg then rows[#rows + 1] = info("EGG", "READY! SEE THE MAN")
    elseif m1 and m2 then rows[#rows + 1] = info("EGG", "NOT YET") end
    local n = 0
    for _, mon in ipairs(save.party or {}) do
      local isEgg = B and B.isEgg and B.isEgg(mon)
      if isEgg then
        n = n + 1
        local steps = B.stepsToHatch and B.stepsToHatch(mon)
        rows[#rows + 1] = info(("EGG IN PARTY %d"):format(n),
          steps and (steps <= 256 and "HATCHING SOON" or ("~%d STEPS"):format(steps)) or "?")
      end
    end
    if not any and n == 0 then
      rows[#rows + 1] = info("NOTHING LEFT HERE", "")
    end
    return rows
  end

  -- ------------------------------------------------------------ TODAY
  local DAYS = { [0] = "SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY" }
  -- Crystal's weekly happenings (weekday 0 = Sunday, as the cart counts)
  local EVENTS = {
    { days = { 2, 4, 6 }, what = "BUG-CATCHING CONTEST", where = "NATIONAL PARK" },
    { days = { 1 }, what = "MONICA (WEEK SIBLING)", where = "ROUTE 40" },
    { days = { 2 }, what = "TUSCANY (WEEK SIBLING)", where = "ROUTE 29" },
    { days = { 3 }, what = "WESLEY (WEEK SIBLING)", where = "LAKE OF RAGE" },
    { days = { 4 }, what = "ARTHUR (WEEK SIBLING)", where = "ROUTE 36" },
    { days = { 5 }, what = "FRIEDA (WEEK SIBLING)", where = "ROUTE 32" },
    { days = { 6 }, what = "SANTOS (WEEK SIBLING)", where = "BLACKTHORN" },
    { days = { 0 }, what = "SUNNY (WEEK SIBLING)", where = "ROUTE 37" },
    { days = { 5 }, what = "LAPRAS", where = "UNION CAVE B2F" },
    { days = { 1 }, what = "CLEFAIRY DANCE (NIGHT)", where = "MT. MOON SQUARE" },
    { days = { 2, 4, 6 }, what = "HAIRCUT (OLDER BRO)", where = "GOLDENROD UNDERGR." },
    { days = { 0, 3 }, what = "HAIRCUT (YOUNGER BRO)", where = "GOLDENROD UNDERGR." },
  }
  local function weekday(game)
    local w = game.world
    if w and type(w.weekday) == "function" then
      local ok, d = pcall(w.weekday, w)
      if ok and tonumber(d) then return math.floor(d) % 7 end
    end
    return tonumber(os.date("%w")) or 0
  end
  local function clockText(game)
    local w = game.world
    if w and type(w.hour) == "function" and type(w.minute) == "function" then
      local okH, h = pcall(w.hour, w)
      local okM, m = pcall(w.minute, w)
      if okH and okM then return ("%02d:%02d"):format(h or 0, m or 0) end
    end
    return ""
  end
  local function eventsOn(day)
    local out = {}
    for _, e in ipairs(EVENTS) do
      for _, d in ipairs(e.days) do if d == day then out[#out + 1] = e end end
    end
    return out
  end
  local function todayRows(game)
    local d = weekday(game)
    local rows = { info("TODAY: " .. DAYS[d], clockText(game)) }
    for _, e in ipairs(eventsOn(d)) do rows[#rows + 1] = info(e.what, e.where) end
    rows[#rows + 1] = info("EVERY EVENING", "BUENA (RADIO)")
    local t = (d + 1) % 7
    rows[#rows + 1] = info("TOMORROW: " .. DAYS[t], "")
    for _, e in ipairs(eventsOn(t)) do rows[#rows + 1] = info(e.what, e.where) end
    return rows
  end
  M.eventsOn = eventsOn

  -- ------------------------------------------------------------ KEY ITEMS
  local PIN_FILE = "key_wheel.lua"
  local pins = nil
  local function loadPins()
    if pins then return pins end
    pins = {}
    local c = mod.cache
    if c and c.read then
      local ok, body = pcall(c.read, c, PIN_FILE)
      if ok and type(body) == "string" then
        for id in body:gmatch("[%w_]+") do pins[#pins + 1] = id end
      end
    end
    return pins
  end
  local function savePins()
    local c = mod.cache
    if c and c.write then pcall(c.write, c, PIN_FILE, table.concat(loadPins(), "\n")) end
  end
  local function selectable(game, id)
    local def = data(game).items and data(game).items[id]
    local inv = game.save and game.save.inventory or {}
    local n = tonumber(inv[id]) or (inv[id] and 1) or 0
    return def ~= nil and def.canSelect ~= false and n > 0, def
  end
  function M.isPinned(id)
    for i, p in ipairs(loadPins()) do if p == id then return i end end
    return nil
  end
  -- hold an item in the PACK: pin / unpin it on the wheel
  function M.togglePin(game, id)
    local ok, def = selectable(game, id)
    local name = itemName(game, id)
    if not ok then
      return { title = name, lines = { "This item can't be used", "from the KEY ITEM WHEEL." } }
    end
    local at = M.isPinned(id)
    if at then table.remove(pins, at) else pins[#pins + 1] = id end
    savePins()
    return { title = name, lines = { at and "Unpinned from the KEY ITEM WHEEL."
      or ("Pinned to the KEY ITEM WHEEL (slot %d)."):format(#pins),
      "Hold SELECT on the overworld to open the wheel." } }
  end
  function M.keyItems(game)
    local out, seen = {}, {}
    for _, id in ipairs(loadPins()) do
      if selectable(game, id) and not seen[id] then out[#out + 1] = id; seen[id] = true end
    end
    local items = data(game).items or {}
    local auto = {}
    for id, n in pairs(game.save and game.save.inventory or {}) do
      local def = items[id]
      if not seen[id] and def and def.pocket == "KEY_ITEM" and selectable(game, id) then
        auto[#auto + 1] = id
      end
    end
    table.sort(auto, function(a, b)
      local ia, ib = tonumber(items[a].index) or 999, tonumber(items[b].index) or 999
      if ia ~= ib then return ia < ib end
      return a < b
    end)
    for _, id in ipairs(auto) do out[#out + 1] = id end
    while #out > 8 do table.remove(out) end
    return out
  end
  local function useItem(game, id)
    local w = game.world
    if not (w and type(w.registerItem) == "function") then return end
    w:registerItem(id)
    if type(game.useSelectItem) == "function" then game:useSelectItem() end
  end
  local function keyItemRows(game)
    local rows = {}
    for _, id in ipairs(M.keyItems(game)) do
      rows[#rows + 1] = { id = "kimArena.q.item." .. id, label = itemName(game, id),
        value = function() return M.isPinned(id) and "PINNED" or "" end,
        activate = function(g)
          g = g or game
          closeToWorld(g)
          later(function(gg) useItem(gg, id) end)
        end }
    end
    if #rows == 0 then rows[1] = info("NO KEY ITEMS TO USE", "") end
    return rows
  end

  -- the wheel (touch: hold SELECT)
  local wheel = nil
  function M.wheelActive() return wheel ~= nil end
  function M.wheelOpen(game)
    if opt("keyWheel", true) == false then return false end
    local list = M.keyItems(game)
    if #list == 0 then
      say(game, "No KEY ITEMS can be\nused from here.")
      return false
    end
    wheel = { game = game, items = list, hover = nil, opened = now() }
    return true
  end
  local function wheelGeom()
    local W, H = G.getDimensions()
    local R = math.min(W, H) * 0.30
    return W / 2, H * 0.46, R
  end
  local function slotAt(x, y)
    if not wheel then return nil end
    local cx, cy, R = wheelGeom()
    local dx, dy = x - cx, y - cy
    local d = math.sqrt(dx * dx + dy * dy)
    if d < R * 0.35 or d > R * 1.6 then return nil, d < R * 0.35 end
    local n = #wheel.items
    local a = math.atan2(dy, dx) + math.pi / 2       -- 0 = straight up
    local i = math.floor((a / (2 * math.pi)) * n + 0.5) % n + 1
    return i
  end
  function M.wheelHover(x, y) if wheel then wheel.hover = slotAt(x, y) end end
  -- released: on a slot -> use it; in the middle -> stay open (sticky) unless
  -- this was a tap on an already-open wheel; outside -> close
  function M.wheelRelease(x, y, tapMode)
    if not wheel then return end
    local i, center = slotAt(x, y)
    if i then
      local id, game = wheel.items[i], wheel.game
      wheel = nil
      later(function(g) useItem(g, id) end)
      return
    end
    -- let go of the SELECT hold away from a slot: stay open for a tap
    if not tapMode then wheel.hover = nil; return end
    wheel = nil
  end
  function M.wheelClose() wheel = nil end

  -- ------------------------------------------------------------ AREA DEX
  -- the current map's wild Pokemon, from the same tables the engine rolls
  local GRASS_PCT = { 30, 30, 20, 10, 5, 4, 1 }
  local WATER_PCT = { 60, 30, 10 }
  local TOD_KEY = { MORN = "MORN", DAY = "DAY", NITE = "NITE", DARK = "NITE" }
  local function addMon(list, index, sp, pct, lvl)
    if not sp or sp == 0 or sp == "NO_ITEM" then return end
    local at = index[sp]
    if not at then
      at = { species = sp, pct = 0, lo = lvl, hi = lvl }
      list[#list + 1] = at; index[sp] = at
    end
    at.pct = at.pct + (pct or 0)
    if lvl then
      at.lo = math.min(at.lo or lvl, lvl); at.hi = math.max(at.hi or lvl, lvl)
    end
  end
  function M.areaSections(game)
    local w = game.world
    local map = w and w.map
    if not map then return {} end
    local tables = w.encounters
    if type(w.wildTables) == "function" then
      local ok, t = pcall(w.wildTables, w); if ok and t then tables = t end
    end
    tables = tables or {}
    local sections = {}
    local tod = TOD_KEY[tostring(w.tod or "DAY")] or "DAY"
    local grass = tables.grass and tables.grass[map.id]
    if grass and grass.slots then
      local now_, idx = {}, {}
      for i, s in ipairs(grass.slots[tod] or grass.slots.DAY or {}) do
        addMon(now_, idx, s.species, GRASS_PCT[i], s.level)
      end
      if #now_ > 0 then
        sections[#sections + 1] = { title = "GRASS / CAVE · " .. (tod == "NITE" and "NIGHT" or tod == "MORN" and "MORNING" or "DAY"), mons = now_ }
      end
      local other, oidx = {}, {}
      for _, key in ipairs({ "MORN", "DAY", "NITE" }) do
        if key ~= tod then
          for i, s in ipairs(grass.slots[key] or {}) do
            if not idx[s.species] then addMon(other, oidx, s.species, 0, s.level) end
          end
        end
      end
      if #other > 0 then sections[#sections + 1] = { title = "OTHER TIMES", mons = other, noPct = true } end
    end
    local water = tables.water and tables.water[map.id]
    if water and water.slots then
      local list, idx = {}, {}
      for i, s in ipairs(water.slots) do addMon(list, idx, s.species, WATER_PCT[i], s.level) end
      if #list > 0 then sections[#sections + 1] = { title = "SURFING", mons = list } end
    end
    local def = w.maps and w.maps[map.id]
    local group = def and def.fishGroup
    local groups = tables.fishGroups or (w.encounters and w.encounters.fishGroups)
    if group and group ~= 0 and group ~= "FISHGROUP_NONE" and groups then
      local Enc = req("src.battle.gen2.Encounter")
      local Roam = req("src.core.gen2.Roamers")
      local swarm
      if Roam and Roam.Swarm and Roam.Swarm.fishing and type(w.engineFlagResolver) == "function" then
        pcall(function() swarm = Roam.Swarm.fishing(game.save, w:engineFlagResolver()) end)
      end
      if Enc and Enc.fishGroupFor then
        local okG, g2 = pcall(Enc.fishGroupFor, tables, group, swarm)
        if okG and g2 then group = g2 end
      end
      local row = groups[group]
      local night = tod == "NITE"
      local timeGroups = tables.timeFishGroups or (w.encounters and w.encounters.timeFishGroups)
      local inv = game.save and game.save.inventory or {}
      for _, rod in ipairs({ { "old", "OLD ROD", "OLD_ROD" }, { "good", "GOOD ROD", "GOOD_ROD" },
          { "super", "SUPER ROD", "SUPER_ROD" } }) do
        local rows = type(row) == "table" and row[rod[1]]
        if type(rows) == "table" and #rows > 0 then
          local list, idx, prev = {}, {}, 0
          for _, r in ipairs(rows) do
            local ch = tonumber(r.chance) or prev
            local slot = r[night and "nite" or "day"]
            if not slot and r.timeGroup and timeGroups then
              local tg = timeGroups[r.timeGroup]; slot = tg and tg[night and "nite" or "day"]
            end
            slot = slot or r
            addMon(list, idx, slot.species, math.max(0, (ch - prev) * 100 / 256), slot.level)
            prev = ch
          end
          if #list > 0 then
            local has = (tonumber(inv[rod[3]]) or 0) > 0
            sections[#sections + 1] = { title = rod[2] .. (has and "" or "  (NOT OWNED)"), mons = list }
          end
        end
      end
    end
    return sections
  end

  local function areaTitle(game)
    local w = game.world
    local id
    if type(game.currentLandmark) == "function" then
      local ok, v = pcall(game.currentLandmark, game); if ok then id = v end
    end
    local lm = data(game).gen2Landmarks
    local rec = id and lm and lm.landmarks and (lm.landmarks[id] or lm.landmarks["LANDMARK_" .. tostring(id)])
    local name = type(rec) == "table" and rec.name
    if type(name) ~= "string" or name == "" then
      name = tostring(w and w.map and w.map.id or "HERE")
    end
    return (name:gsub("[\n_]", " "):upper())
  end

  -- sprites: KIM HD front sprite, else KIM's HD menu icon
  local imageCache = {}
  local function loadImage(path)
    if not path then return nil end
    if imageCache[path] ~= nil then return imageCache[path] or nil end
    local ok, img = false, nil
    if mod.assets and type(mod.assets.image) == "function" then ok, img = pcall(mod.assets.image, mod.assets, path) end
    if (not ok or not img) and G.newImage then ok, img = pcall(G.newImage, path) end
    imageCache[path] = (ok and img) or false
    if ok and img and img.setFilter then pcall(img.setFilter, img, "nearest", "nearest") end
    return ok and img or nil
  end
  local function spriteFor(game, sp)
    local ex = mod.exports
    if ex and type(ex.getSprite) == "function" then
      local ok, img = pcall(ex.getSprite, sp, { generation = "hd" })
      if ok and img and type(img.getDimensions) == "function" then return img end
    end
    local iconFn = rawget(mod, "_kantoInMotionHdMenuIconForModernUi")
    if type(iconFn) == "function" then
      local ok, path = pcall(iconFn, game, { species = sp, level = 5 })
      if ok and path then return loadImage(path) end
    end
    return nil
  end

  local function style() return rawget(mod, "_kantoInMotionGen2Ui") end
  local function theme()
    local S = style()
    local ok, t = false, nil
    if S and S.theme then ok, t = pcall(S.theme) end
    return (ok and t) or { surface = { .075, .105, .17, .96 }, accent = { .48, .86, 1, 1 },
      text = { .96, .98, 1, 1 }, muted = { .74, .82, .92, 1 }, frame = { .48, .86, 1, 1 },
      selected = { .18, .43, .72, 1 }, divider = { .38, .5, .68, .94 }, raised = { .2, .26, .36, 1 } }
  end
  local fonts = {}
  local function font(px)
    px = math.max(8, math.floor(px + 0.5))
    if not fonts[px] then
      local f = rawget(mod, "_kimArenaFont")
      local ok, v = false, nil
      if type(f) == "function" then ok, v = pcall(f, px) end
      if not (ok and v) then ok, v = pcall(G.newFont, px) end
      fonts[px] = ok and v or G.getFont()
    end
    return fonts[px]
  end
  local function panel(x, y, w, h, th, a)
    local S = style()
    if S and S.panel and pcall(S.panel, x, y, w, h, th, a) then return end
    G.setColor(th.surface[1], th.surface[2], th.surface[3], (a or 0.96))
    G.rectangle("fill", x, y, w, h, 10, 10)
    G.setColor(th.frame[1], th.frame[2], th.frame[3], 1)
    G.setLineWidth(3); G.rectangle("line", x, y, w, h, 10, 10)
  end
  local function setc(c, a) G.setColor(c[1], c[2], c[3], a or c[4] or 1) end
  local function ball(x, y, r)
    G.setColor(0.9, 0.18, 0.2, 1); G.arc("fill", x, y, r, math.pi, 2 * math.pi)
    G.setColor(1, 1, 1, 1); G.arc("fill", x, y, r, 0, math.pi)
    G.setColor(0.1, 0.1, 0.12, 1); G.setLineWidth(math.max(1, r * 0.18))
    G.circle("line", x, y, r); G.line(x - r, y, x + r, y)
    G.setColor(1, 1, 1, 1); G.circle("fill", x, y, r * 0.32)
    G.setColor(0.1, 0.1, 0.12, 1); G.circle("line", x, y, r * 0.32)
  end

  local AreaDex = {}
  AreaDex.__index = AreaDex
  function AreaDex.new(game)
    local self = setmetatable({}, AreaDex)
    self.game, self.isOpaque, self.scroll, self.maxScroll = game, false, 0, 0
    self.kimAreaDex = true
    self.sections = M.areaSections(game)
    self.title = areaTitle(game)
    return self
  end
  function AreaDex:drawsWidescreen() return false end
  function AreaDex:draw() end
  function AreaDex:update()
    local input = self.game and self.game.input
    if not input then return end
    if input:wasPressed("b") or input:wasPressed("a") or input:wasPressed("start") then
      self.game.stack:pop(); return
    end
    local step = self.rowStep or 60
    local FS = rawget(mod, "_kimFreeScroll")
    if type(FS) == "table" and FS[self] and (input:wasPressed("down") or input:wasPressed("up")) then FS[self] = nil end
    if input:wasPressed("down") then self.scroll = math.min(self.maxScroll, self.scroll + step)
    elseif input:wasPressed("up") then self.scroll = math.max(0, self.scroll - step) end
  end
  function AreaDex:render()
    local game = self.game
    local th = theme()
    local W, H = G.getDimensions()
    local pw, ph = math.min(W * 0.94, 1100), H * 0.86
    local px, py = (W - pw) / 2, (H - ph) / 2
    local s = math.max(0.6, math.min(pw / 900, ph / 900, 2.2))
    panel(px, py, pw, ph, th, 0.97)
    local tf, bf, sf = font(30 * s), font(20 * s), font(15 * s)
    G.setFont(tf); setc(th.text)
    G.printf("AREA DEX", px + 20 * s, py + 14 * s, pw * 0.5, "left")
    G.setFont(sf); setc(th.accent)
    G.printf(self.title, px + pw * 0.4, py + 22 * s, pw * 0.6 - 24 * s, "right")
    local top = py + 14 * s + tf:getHeight() + 10 * s
    local bottom = py + ph - sf:getHeight() - 18 * s
    local Tap = rawget(mod, "_kimTap")
    if Tap and Tap.begin then Tap.begin(self) end
    local seen, caught = dex(game)
    local cols = math.max(3, math.floor(pw / (150 * s)))
    local cw = (pw - 40 * s) / cols
    local ch = cw * 1.12
    self.rowStep = ch
    -- 0.9.47: KIM Touch free scroll (drag / flick like a web page)
    local FS = rawget(mod, "_kimFreeScroll")
    local fe = type(FS) == "table" and FS[self]
    if fe then
      local maxRows = (self.maxScroll or 0) / ch
      local off = math.max(0, math.min(maxRows, tonumber(fe.offset) or 0))
      if off ~= fe.offset then fe.vel = 0 end
      fe.offset = off
      self.scroll = off * ch
    end
    if Tap and Tap.buf then
      Tap.buf.freeScroll, Tap.buf.scroll, Tap.buf.rowH = true, self.scroll / ch, ch
    end
    G.setScissor(px + 4, top, pw - 8, bottom - top)
    local y = top - self.scroll
    if #self.sections == 0 then
      G.setFont(bf); setc(th.muted)
      G.printf("No wild POKeMON live here.", px, top + 40 * s, pw, "center")
    end
    for _, sec in ipairs(self.sections) do
      G.setFont(sf); setc(th.accent)
      G.print(sec.title, px + 22 * s, y)
      y = y + sf:getHeight() + 6 * s
      setc(th.divider or th.muted, 0.6); G.rectangle("fill", px + 20 * s, y - 3 * s, pw - 40 * s, 1)
      for i, m in ipairs(sec.mons) do
        local c = (i - 1) % cols
        if c == 0 and i > 1 then y = y + ch end
        local cx = px + 20 * s + c * cw
        local isSeen, isCaught = seen[m.species] == true, caught[m.species] == true
        if y + ch > top and y < bottom then
          setc(th.raised or th.surface, 0.55)
          G.rectangle("fill", cx + 4 * s, y + 2 * s, cw - 8 * s, ch - 6 * s, 8 * s, 8 * s)
          local box = cw * 0.62
          local img = spriteFor(game, m.species)
          if img then
            local iw, ih = img:getDimensions()
            local k = math.min(box / iw, box / ih)
            if isSeen or isCaught then G.setColor(1, 1, 1, 1) else G.setColor(0, 0, 0, 1) end
            G.draw(img, cx + (cw - iw * k) / 2, y + 6 * s + (box - ih * k), 0, k, k)
          else
            setc(isSeen and th.text or { 0, 0, 0, 1 })
            G.setFont(tf); G.printf("?", cx, y + box * 0.3, cw, "center")
          end
          if isCaught then ball(cx + cw - 18 * s, y + 16 * s, 8 * s) end
          G.setFont(sf); setc(isSeen and th.text or th.muted)
          local name = isSeen and speciesName(game, m.species) or "?????"
          G.printf(name, cx + 4 * s, y + box + 10 * s, cw - 8 * s, "center")
          local sub = (m.lo and (m.lo == m.hi and ("LV %d"):format(m.lo) or ("LV %d-%d"):format(m.lo, m.hi))) or ""
          if not sec.noPct and m.pct > 0 then sub = sub .. ("  %d%%"):format(math.floor(m.pct + 0.5)) end
          setc(th.muted)
          G.printf(sub, cx + 4 * s, y + box + 12 * s + sf:getHeight(), cw - 8 * s, "center")
          if Tap and Tap.add then Tap.add(cx, math.max(top, y), cw, math.min(ch, bottom - math.max(top, y)), function() end, false) end
        end
      end
      y = y + ch + 10 * s
    end
    G.setScissor()
    self.maxScroll = math.max(0, (y + self.scroll) - bottom)
    if self.scroll > self.maxScroll then self.scroll = self.maxScroll end
    if Tap and Tap.finish then Tap.finish() end
    local seenN, caughtN, total = 0, 0, 0
    for _, sec in ipairs(self.sections) do
      for _, m in ipairs(sec.mons) do
        total = total + 1
        if caught[m.species] then caughtN = caughtN + 1 elseif seen[m.species] then seenN = seenN + 1 end
      end
    end
    G.setFont(sf); setc(th.muted)
    G.printf(("CAUGHT %d   SEEN %d   ?? %d      SWIPE / UP-DOWN SCROLL   TAP / B CLOSE")
      :format(caughtN, seenN, total - caughtN - seenN), px + 20 * s, py + ph - sf:getHeight() - 10 * s, pw - 40 * s, "left")
  end
  function M.openAreaDex(game)
    if not (game and game.stack) then return end
    game.stack:push(AreaDex.new(game))
  end

  -- ------------------------------------------------------------ QUICK MENU
  function M.openQuick(game)
    if opt("quickMenu", true) == false then return false end
    local rows = {}
    if hasPokegear(game) then
      rows[#rows + 1] = { id = "kimArena.q.gear", label = "POKeGEAR", group = true,
        activate = function(g) g = g or game; closeToWorld(g); later(openPokegear) end }
    end
    rows[#rows + 1] = { id = "kimArena.q.fly", label = "FLY", group = true,
      activate = function(g) g = g or game; closeToWorld(g); later(fly) end }
    rows[#rows + 1] = { id = "kimArena.q.area", label = "AREA DEX", group = true,
      activate = function(g) M.openAreaDex(g or game) end }
    rows[#rows + 1] = { id = "kimArena.q.daycare", label = "DAY-CARE", group = true,
      activate = function(g) g = g or game; page(g, dayCareRows(g), "DAY-CARE", "ROUTE 34") end }
    rows[#rows + 1] = { id = "kimArena.q.today", label = "TODAY", group = true,
      activate = function(g) g = g or game; page(g, todayRows(g), "TODAY", "EVENTS") end }
    rows[#rows + 1] = { id = "kimArena.q.items", label = "KEY ITEMS", group = true,
      activate = function(g) g = g or game
        local p = page(g, keyItemRows(g), "KEY ITEMS", "USE")
        if p then quickPages[p] = true end
      end }
    local p = page(game, rows, "QUICK MENU", "HOLD START")
    if p then quickPages[p] = true end
    return p ~= nil
  end

  -- START -> QUICK (works with any controller)
  mod.hooks:wrap("ui.start_menu.items", function(nextFn, game, items)
    local result = nextFn(game, items)
    if type(result) ~= "table" then result = items end
    if opt("quickMenu", true) ~= false and opt("quickInStart", true) ~= false then
      local at = #result + 1
      for i, it in ipairs(result) do
        if it and (it.label == "PC" or it.label == "ALL-IN-1" or it.label == "OPTION") then at = i; break end
      end
      table.insert(result, at, { label = "QUICK", onSelect = function() M.openQuick(game) end })
    end
    return result
  end, -2e9)

  -- ------------------------------------------------------------ info cards
  local STAT_KEYS = { { "attack", "ATK" }, { "defense", "DEF" }, { "specialAttack", "SPA" },
    { "specialDefense", "SPD" }, { "speed", "SPE" } }
  function M.monInfo(game, mon, opts)
    if type(mon) ~= "table" then return nil end
    opts = opts or {}
    local d = data(game)
    local def = d.pokemon and d.pokemon[mon.species] or {}
    local b = opts.battle
    local types = def.types or mon.types
    if b and type(b.battlerTypes) == "function" then
      local ok, t = pcall(b.battlerTypes, b, mon); if ok and t then types = t end
    end
    local name = tostring(mon.nickname or def.name or mon.species or "?"):upper()
    local lines = {}
    lines[#lines + 1] = ("LV %d   %s"):format(tonumber(mon.level) or 0, typeList(types))
    local maxHp = tonumber(mon.maxHp or (mon.stats and mon.stats.hp)) or 0
    local hp = tonumber(mon.hp) or 0
    if opts.enemy then
      if maxHp > 0 then lines[#lines + 1] = ("HP %d%%"):format(math.floor(hp * 100 / maxHp + 0.5)) end
      local bs = def.baseStats or {}
      lines[#lines + 1] = ("BASE  HP %s  ATK %s  DEF %s"):format(bs.hp or "?", bs.attack or "?", bs.defense or "?")
      lines[#lines + 1] = ("      SPA %s  SPD %s  SPE %s"):format(bs.specialAttack or "?", bs.specialDefense or "?", bs.speed or "?")
      local seen, caught = dex(game)
      lines[#lines + 1] = caught[mon.species] and "YOU HAVE CAUGHT ONE" or "NOT CAUGHT YET"
    else
      lines[#lines + 1] = ("HP %d/%d"):format(hp, maxHp)
      local st = mon.stats or {}
      local parts = {}
      for _, k in ipairs(STAT_KEYS) do parts[#parts + 1] = k[2] .. " " .. tostring(st[k[1]] or "?") end
      lines[#lines + 1] = table.concat(parts, "  ", 1, 3)
      lines[#lines + 1] = table.concat(parts, "  ", 4, 5)
      if mon.item then lines[#lines + 1] = "HOLDS " .. itemName(game, mon.item) end
      for _, mv in ipairs(mon.moves or {}) do
        local id = type(mv) == "table" and mv.id or mv
        local md = d.moves and d.moves[id] or {}
        local pp = type(mv) == "table" and mv.pp
        lines[#lines + 1] = ("%-13s %s"):format(tostring(md.name or id):upper(),
          pp and ("%d/%d"):format(pp, tonumber(mv.maxPp or md.pp) or 0) or "")
      end
    end
    local status = mon.status
    if type(status) == "table" then status = status.id or status.name end
    if status and status ~= "" and status ~= "OK" and status ~= "NONE" then
      lines[1] = lines[1] .. "   " .. tostring(status):upper():sub(1, 4)
    end
    return { title = name, lines = lines }
  end
  function M.battleInfo(game, state, side)
    local b = state and state.battle
    local mon = b and (side == "enemy" and b.enemy or b.player)
    return M.monInfo(game, mon, { battle = b, enemy = side == "enemy" })
  end

  -- ------------------------------------------------------------ drawing
  mod.hooks:wrap("render.hud", function(nextFn, game, viewport)
    local r = { pcall(nextFn, game, viewport) }
    local ok = table.remove(r, 1)
    if not ok then error(r[1], 0) end
    local top = game and game.stack and game.stack:top()
    if type(top) == "table" and rawget(top, "kimAreaDex") then
      G.push("all"); G.origin()
      local okD, err = pcall(top.render, top)
      G.pop()
      if not okD then diag("area dex", tostring(err):sub(1, 120)) end
    end
    if wheel then
      if not M.ready(game) and not (wheel.game == game and game.stack and game.stack:top() == nil) then
        wheel = nil
      else
        G.push("all"); G.origin()
        pcall(function()
          local th = theme()
          local W, H = G.getDimensions()
          G.setColor(0, 0, 0, 0.45); G.rectangle("fill", 0, 0, W, H)
          local cx, cy, R = wheelGeom()
          local n = #wheel.items
          local f = font(math.max(14, R * 0.085))
          for i, id in ipairs(wheel.items) do
            local a = (i - 1) / n * 2 * math.pi - math.pi / 2
            local x, y = cx + math.cos(a) * R, cy + math.sin(a) * R
            local label = itemName(game, id)
            local w = math.max(f:getWidth(label) + 24, R * 0.55)
            local h = f:getHeight() * 2
            local hot = wheel.hover == i
            panel(x - w / 2, y - h / 2, w, h, th, 0.95)
            if hot then
              setc(th.selected, 0.95)
              G.rectangle("fill", x - w / 2 + 4, y - h / 2 + 4, w - 8, h - 8, 8, 8)
            end
            G.setFont(f); setc(hot and th.text or th.text)
            G.printf(label, x - w / 2, y - f:getHeight() / 2, w, "center")
            if M.isPinned(id) then
              setc(th.accent); G.circle("fill", x + w / 2 - 10, y - h / 2 + 10, 4)
            end
          end
          setc(th.surface, 0.9); G.circle("fill", cx, cy, R * 0.34)
          setc(th.frame); G.setLineWidth(3); G.circle("line", cx, cy, R * 0.34)
          local cf = font(math.max(13, R * 0.07))
          G.setFont(cf); setc(th.text)
          local center = wheel.hover and itemName(game, wheel.items[wheel.hover]) or "KEY ITEMS"
          G.printf(center, cx - R * 0.32, cy - cf:getHeight(), R * 0.64, "center")
          setc(th.muted)
          G.printf(wheel.hover and "LET GO TO USE" or "DRAG OR TAP", cx - R * 0.32, cy + 2, R * 0.64, "center")
        end)
        G.pop()
      end
    end
    return (table.unpack or unpack)(r)
  end, 31000)

  rawset(mod, "_kimArenaQuick", M)
  diag("quick menu", "ready")
  return M
end
