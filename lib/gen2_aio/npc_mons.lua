-- gen2-aio 0.9.24: WILDS NPC POKEMON.
--
-- Crystal's Pokemon object events (Ilex's Farfetch'd, Azalea's Slowpoke, the
-- Red Gyarados, Lugia, Ho-Oh, the day-care mons, the beasts, ...) are drawn
-- with the same Wilds sprite set as wild Pokemon and followers, in the
-- active SPRITE STYLE.
--
-- One swap covers 2D and gmarc: the NPC's SpriteRenderer is replaced and
-- gmarc builds its billboard from that same renderer (pose() / sprite.def).
-- npc.spriteDef stays the native record, so OBJ palettes, NPC.bigFacing and
-- `variablesprite` keep reading Crystal's own data; NPC:setSpriteDef is
-- wrapped so a scripted sheet change is swapped again (or restored).
--
-- Species: SPRITE_POKEMON rows carry it from the ROM (SpriteMons); the
-- generic overworld sheets (FAIRY, BIRD, DRAGON, MONSTER, SURF) get it from
-- the object's own talk script (`cry` / `loadwildmon` / `pokepic`).
--
-- Left native on purpose: Sudowoodo (gmarc builds it as a 3D tree prop, and
-- the disguise is the joke), the 32px dolls (BIG_SNORLAX / LAPRAS / ONIX),
-- and the decoration dolls in the player's bedroom.
return function(host)
  local mod, diag = host.mod, host.diag or function() end
  local okW, World = pcall(require, "src.world.gen2.World")
  local okN, NPC = pcall(require, "src.world.gen2.Npc")
  local okS, SpriteRenderer = pcall(require, "src.render.SpriteRenderer")
  if not (okW and okN and okS and type(World) == "table" and type(NPC) == "table"
      and type(World.pooledNpc) == "function" and type(SpriteRenderer) == "table") then
    return nil
  end
  if World._kimArenaNpcMons then return World._kimArenaNpcMons end

  local M = {}
  World._kimArenaNpcMons = M

  -- generic overworld sheets: species from the script; value = fallback
  local GENERIC = {
    SPRITE_FAIRY = false, SPRITE_BIRD = false, SPRITE_DRAGON = false,
    SPRITE_MONSTER = false, SPRITE_SURF = "LAPRAS",
    SPRITE_SUICUNE = "SUICUNE", SPRITE_ENTEI = "ENTEI", SPRITE_RAIKOU = "RAIKOU",
  }
  -- 0.9.44: the 32x32 BIG_SNORLAX / BIG_LAPRAS / BIG_ONIX sheets are swapped
  -- too (Vermilion's sleeping Snorlax and friends) -- except as the bedroom
  -- dolls, which SKIP_MAPS still covers.
  -- 0.9.87: sheets Crystal borrows for another Pokemon. Moltres never
  -- stands in GSC's overworld; its sheet is the bird the Charcoal Kiln's
  -- Farfetch'd is drawn with. The talk script still decides when it names a
  -- species; this is the answer when it does not (or has no script key).
  local BORROWED = { SPRITE_MOLTRES = "FARFETCH_D" }
  local SKIP_IDS = { SPRITE_SUDOWOODO = true }
  local SKIP_MAPS = { PLAYERS_HOUSE_2F = true }
  -- Lake of Rage's Red Gyarados
  local SHINY = { LAKE_OF_RAGE = { GYARADOS = true } }
  local SPECIES_OPS = { cry = true, loadwildmon = true, pokepic = true }
  local DEF_ID = "SPRITE_KIM_NPC_MON"

  local function enabled()
    local ok, v = pcall(mod.options.get, mod.options, "npcMonSprites")
    return not ok or v ~= false
  end

  local function wilds()
    local ex = host.wilds and host.wilds()
    if type(ex) == "table" and type(ex.resolveFollowerSprite) == "function" then return ex end
    return nil
  end

  local function wreq(name)
    local ex = wilds()
    if not (ex and type(ex.require) == "function") then return nil end
    local ok, m = pcall(ex.require, name)
    return ok and m or nil
  end

  local function speciesName(world, s)
    if type(s) == "string" and s ~= "" then return s:upper() end
    local n = tonumber(s)
    local order = world and world.constants and world.constants.speciesOrder
    if n and type(order) == "table" and type(order[n]) == "string" then return order[n] end
    return nil
  end

  -- first species a talk script names (follows sjump / scall / branches)
  local function scanScript(world, key, depth, seen)
    if depth > 4 then return nil end
    local list = type(key) == "table" and key or (world.scripts and world.scripts[key])
    if type(list) ~= "table" or seen[list] then return nil end
    seen[list] = true
    for i, cmd in ipairs(list) do
      if i > 120 then break end
      if type(cmd) == "table" then
        if SPECIES_OPS[cmd.op] then
          local s = speciesName(world, cmd.species or cmd.id or (cmd.args and cmd.args[1]))
          if s then return s end
        end
        local target = cmd.script
        if type(target) == "string" or type(target) == "table" then
          local s = scanScript(world, target, depth + 1, seen)
          if s then return s end
        end
      end
    end
    return nil
  end

  -- 0.9.24b: species named by the sheet itself (SPRITE_SLOWPOKE, SPRITE_GYARADOS).
  -- A sprites.lua cache built before the extractor recorded `.species` /
  -- `spriteType` on the SPRITE_POKEMON rows has neither field, so the name is
  -- the answer that always works. Validated against Crystal's species list,
  -- then Wilds' own table (FARFETCHD / MR_MIME spellings too).
  -- 0.9.87: also the game's own species table (game.data.pokemon, what the
  -- battle reads): on the device no sheet was ever recognised -- "0
  -- swapped", Azalea's Slowpoke and the Kiln's Farfetch'd drawn native --
  -- so the list no longer rests on world.constants alone.
  local speciesSet, speciesFrom
  local function isSpecies(world, name)
    if not speciesSet then
      local order = world and world.constants and world.constants.speciesOrder
      local set, n = {}, 0
      if type(order) == "table" then
        for _, s in pairs(order) do if type(s) == "string" then set[s] = true; n = n + 1 end end
        if n > 0 then speciesFrom = "constants" end
      end
      local data = world and world.game and world.game.data
      local mons = type(data) == "table" and data.pokemon
      if n == 0 and type(mons) == "table" then
        for s in pairs(mons) do if type(s) == "string" then set[s] = true; n = n + 1 end end
        if n > 0 then speciesFrom = "game data" end
      end
      if n > 0 then speciesSet, M.speciesCount = set, n end
    end
    if speciesSet and speciesSet[name] then return true end
    local Assets = wreq("species_assets")
    if Assets and Assets.idFor then
      for _, v in ipairs({ name, (name:gsub("__", "_")), (name:gsub("_", "")) }) do
        local ok, n = pcall(Assets.idFor, v)
        if ok and n then return true end
      end
    end
    return false
  end
  -- 0.9.28: the key Wilds' own tables use. Crystal spells FARFETCH_D and
  -- MR__MIME; Wilds keys FARFETCHD and MR_MIME, and handed the engine
  -- spelling its providers fell through to placeholder art (Ilex's
  -- Farfetch'd came out as a grey rock).
  local function wildsKey(name)
    local Assets = wreq("species_assets")
    if not (Assets and Assets.idFor and type(name) == "string") then return name, nil end
    for _, v in ipairs({ name, (name:gsub("__", "_")), (name:gsub("_", "")) }) do
      local ok, n = pcall(Assets.idFor, v)
      if ok and n then return v, n end
    end
    return name, nil
  end

  local function nameSpecies(world, id)
    local name = type(id) == "string" and id:match("^SPRITE_(.+)$")
    if name and isSpecies(world, name) then return name end
    return nil
  end

  -- species for this NPC, or nil (+ the native sprite id when unresolved)
  local function speciesFor(world, npc)
    local def = npc.spriteDef
    if type(def) ~= "table" then return nil end
    local id = def.id
    if SKIP_IDS[id] or id == DEF_ID then return nil end
    if npc.bigObject then
      local big = type(id) == "string" and id:match("^SPRITE_BIG_(.+)$")
      if big and isSpecies(world, big) then return big end
      return nil
    end
    if type(def.species) == "string" and def.species ~= "" then return def.species end
    if def.species ~= nil then
      local s = speciesName(world, def.species)
      if s then return s end
    end
    if BORROWED[id] then
      local key = npc.def and npc.def.scriptKey
      local s = key and scanScript(world, key, 0, {})
      return s or BORROWED[id]
    end
    local named = nameSpecies(world, id)
    if named then
      -- 0.9.81: the sheet name is only a hint. Crystal borrows sheets:
      -- the Charcoal Kiln's Farfetch'd is a SPRITE_MOLTRES object (the
      -- generic bird slot -- Moltres never stands in GSC's overworld), so
      -- the object's own talk script (`cry FARFETCH_D`) has the last word.
      local key = npc.def and npc.def.scriptKey
      local s = key and scanScript(world, key, 0, {})
      return s or named
    end
    if GENERIC[id] ~= nil then
      local key = npc.def and npc.def.scriptKey
      local s = key and scanScript(world, key, 0, {})
      if s then return s end
      if GENERIC[id] then return GENERIC[id] end
      return nil, id
    end
    return nil
  end

  local function bounceAsWalk(self)
    local b = NPC.bounceFrame(self)
    if b ~= nil then return b end
    return NPC.walkPhase(self)
  end
  local function noBounce() return nil end

  local function clearOverrides(npc)
    rawset(npc, "walkPhase", nil)
    rawset(npc, "bounceFrame", nil)
    rawset(npc, "drawBig", nil)
    rawset(npc, "drawBigAsym", nil)
    rawset(npc, "pose", nil)
  end
  -- a big object's coordinates are the TOP LEFT of its 2x2 blob; a normal
  -- sprite stands on the bottom-centre of one 16x16 cell. Draw (and pose for
  -- gmarc) the Wilds sprite on the blob's bottom-centre instead.
  local function bigOverrides(npc)
    local function drawCentered(self)
      self.sprite:draw(self.px + 8, self.py + 16, 0, 0, self.facing or "down",
        self:walkPhase() or 0, false, false, nil)
    end
    rawset(npc, "drawBig", drawCentered)
    rawset(npc, "drawBigAsym", drawCentered)
    if type(NPC.pose) == "function" then
      rawset(npc, "pose", function(self, ...)
        local r = { NPC.pose(self, ...) }
        if type(r[2]) == "number" then r[2] = r[2] + 8 end
        if type(r[3]) == "number" then r[3] = r[3] + 16 end
        return unpack(r)
      end)
    end
  end

  local function restore(world, npc)
    clearOverrides(npc)
    if npc._kimMonSpecies then
      local ok, sprite = pcall(SpriteRenderer.new, npc.spriteDef, npc.id)
      if ok and sprite then
        npc.sprite = sprite
        if world and world.applySpritePalette then pcall(world.applySpritePalette, world, npc) end
      end
    end
    npc._kimMonSpecies = nil
  end

  local gen = 0
  local stats = { swapped = {}, native = {}, other = {} }

  local function buildDef(resolved, species, wkey)
    local def = {
      id = DEF_ID,
      image = resolved.image,
      frames = resolved.frames or 6,
      walker = resolved.walker ~= false,
      trueColor = resolved.trueColor ~= false,
      frameWidth = resolved.frameWidth,
      frameHeight = resolved.frameHeight,
      anchorX = resolved.anchorX,
      anchorY = resolved.anchorY,
      idleFrameCount = resolved.idleFrameCount,
      idleDurations = resolved.idleDurations,
      walkFrameCount = resolved.walkFrameCount,
      walkDurations = resolved.walkDurations,
      walkCycleBase = resolved.walkCycleBase,
      disableVerticalStepFlip = resolved.disableVerticalStepFlip,
      forceRawTrueColor = resolved.forceRawTrueColor,
      species = species,
      kimNpcMon = true,
    }
    -- 0.9.27: draw Wilds' colour art as it is. These NPCs live in the World's
    -- people pool, so World:applySpritePalette / applyPalettes hand their
    -- renderer Crystal's 4-colour OBJ palette every second, and whenever the
    -- engine does not honour trueColor (COLOR modes other than GBC) that
    -- palette was baked over the art -- Ilex's Farfetch'd came out as a grey
    -- and white blob. gbaArt is SpriteRenderer's "always raw" flag (2D draw
    -- and resolveImage, which gmarc textures from). Luminance sheets
    -- (trueColor == false) still take the palette, as Wilds intends.
    if def.trueColor then def.gbaArt = true end
    -- Wilds' per-species display size (same as its followers)
    local Geo = wreq("species_geometry")
    local Assets = wreq("species_assets")
    local Config = wreq("config")
    if Geo and Geo.resolveDisplayGeometry and Assets and Assets.idForRuntime then
      pcall(function()
        local dex = Assets.idForRuntime(wkey or species, resolved.dex) or wkey or species
        local style = Config and Config.spriteStyle and Config.spriteStyle(mod) or nil
        def.displayWidth, def.displayHeight, def.displayAnchorX, def.displayAnchorY =
          Geo.resolveDisplayGeometry(dex, style, def.frameWidth, def.frameHeight,
            def.anchorX, def.anchorY)
      end)
    end
    return def
  end

  local function apply(world, npc)
    if type(npc) ~= "table" then return end
    local ex = enabled() and wilds() or nil
    local species, unresolved
    if ex and not SKIP_MAPS[npc.mapId] then species, unresolved = speciesFor(world, npc) end
    if unresolved then stats.native[unresolved] = true end
    if not species and not unresolved and npc.spriteDef and npc.spriteDef.id then
      stats.other[npc.spriteDef.id] = true
    end
    local shiny = species and SHINY[npc.mapId] and SHINY[npc.mapId][species] or false
    local key = species and (species .. (shiny and "*" or "") .. "#" .. gen
      .. "#" .. tostring(npc.spriteDef)) or nil
    if npc._kimMonKey == key and (key == nil or npc._kimMonSpecies) then return end
    npc._kimMonKey = key
    if not species then return restore(world, npc) end

    local wkey, assetId = wildsKey(species)
    local ok, resolved = pcall(ex.resolveFollowerSprite, {
      species = wkey, shiny = shiny, game = world and world.game,
      surface = "land", role = "npc",
    })
    if not (ok and type(resolved) == "table" and resolved.image and not resolved.fallback) then
      stats.native[species] = true
      return restore(world, npc)
    end
    local okSR, sprite = pcall(SpriteRenderer.new, buildDef(resolved, species, wkey), npc.id)
    if not (okSR and sprite) then
      stats.native[species] = true
      return restore(world, npc)
    end
    npc.sprite = sprite
    npc._kimMonSpecies = species
    stats.swapped[species .. (assetId and ("#" .. assetId) or "#?")] = true
    local Pres = wreq("sprite_presentation")
    if Pres and Pres.attach then pcall(Pres.attach, sprite, npc) end
    -- the icon's two-frame hop becomes a step in place on the walker sheet
    clearOverrides(npc)
    if npc.bouncing then
      rawset(npc, "bounceFrame", noBounce)
      rawset(npc, "walkPhase", bounceAsWalk)
    end
    if npc.bigObject then bigOverrides(npc) end
    if world and world.applySpritePalette then pcall(world.applySpritePalette, world, npc) end
  end

  local lastWorld
  local function report()
    local s, n = {}, {}
    for k in pairs(stats.swapped) do s[#s + 1] = k end
    for k in pairs(stats.native) do n[#n + 1] = k end
    table.sort(s); table.sort(n)
    local text
    if not wilds() then text = "Wilds not running"
    elseif not enabled() then text = "off"
    else
      text = ("%d swapped%s"):format(#s, #s > 0 and (" (" .. table.concat(s, " ") .. ")") or "")
      text = text .. ("; species %s"):format(speciesSet and (tostring(M.speciesCount) .. " from " .. tostring(speciesFrom))
        or "list missing")
      if #n > 0 then text = text .. "; native: " .. table.concat(n, " ") end
      local o = {}
      for k in pairs(stats.other) do o[#o + 1] = (tostring(k):gsub("^SPRITE_", "")) end
      table.sort(o)
      if #o > 0 then
        local more = #o > 24 and (" +" .. (#o - 24)) or ""
        while #o > 24 do table.remove(o) end
        text = text .. "; other: " .. table.concat(o, " ") .. more
      end
    end
    diag("npc mons", text)
  end

  local origPooled = World.pooledNpc
  World.pooledNpc = function(self, mapId, obj, ...)
    local npc = origPooled(self, mapId, obj, ...)
    if npc then
      local here = self.map and self.map.id
      if lastWorld ~= self or M._mapId ~= here then
        lastWorld, M._mapId = self, here
        stats.swapped, stats.native, stats.other = {}, {}, {}
      end
      pcall(apply, self, npc)
      pcall(report)
    end
    return npc
  end

  local origSetDef = NPC.setSpriteDef
  if type(origSetDef) == "function" then
    NPC.setSpriteDef = function(self, spriteDef, ...)
      local changed = origSetDef(self, spriteDef, ...)
      if changed then
        -- the engine just built a native renderer for the new sheet
        clearOverrides(self)
        self._kimMonSpecies, self._kimMonKey = nil, nil
        pcall(apply, lastWorld, self)
      end
      return changed
    end
  end

  -- re-apply live when this setting or any Wilds option (sprite style) changes
  local dirty = false
  pcall(function()
    mod.events:on("mod.options_changed", function()
      gen = gen + 1
      dirty = true
    end)
  end)
  pcall(function()
    mod.hooks:wrap("render.hud", function(nextFn, ...)
      if dirty and lastWorld and type(lastWorld.npcPool) == "table" then
        dirty = false
        stats.swapped, stats.native, stats.other = {}, {}, {}
        for _, npc in pairs(lastWorld.npcPool) do pcall(apply, lastWorld, npc) end
        pcall(report)
      end
      return nextFn(...)
    end, -100)
  end)

  -- test surface
  M.apply = apply
  M.speciesFor = speciesFor
  M.scanScript = scanScript
  M.stats = stats
  M.bump = function() gen = gen + 1; dirty = true end
  return M
end
