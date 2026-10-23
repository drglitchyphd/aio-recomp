-- KIM_ARENA 0.9.40: FOLLOWER = PARTY LEAD.
--
-- Wilds' follower remembers WHICH Pokemon you picked (by fingerprint) and
-- keeps it through party reorders, so moving another Pokemon to the top only
-- took effect after a reload (when the selection was rebuilt). With this on
-- (default), whenever you are back on the overworld the follower is the first
-- healthy Pokemon in the party: a SWITCH, a long-press drag, a deposit or a
-- faint changes it right away, through Wilds' own selectFollower (the same
-- live path its FOLLOWER submenu uses). OFF hands the choice back to Wilds'
-- FOLLOWER submenu entry.
return function(host)
  local mod = host.mod
  local function wilds()
    local ex = host.wilds and host.wilds()
    if type(ex) == "table" and type(ex.selectFollower) == "function"
        and type(ex.getActiveFollowerMon) == "function" then return ex end
    return nil
  end
  local function healthy(mon)
    return type(mon) == "table" and not mon.isEgg and not mon.egg
      and (tonumber(mon.hp) or tonumber(mon.currentHp) or 1) > 0
  end
  -- 0.9.41: compare by Wilds' own fingerprint (the follower's mon can be a
  -- copy, not the party table), read the party through Wilds' GameCompat,
  -- accept any world-like top state, and report on DIAGNOSTICS `follower`.
  local diag = host.diag or function() end
  local function wreq(ex, name)
    if type(ex.require) ~= "function" then return nil end
    local ok, m = pcall(ex.require, name)
    return ok and m or nil
  end
  local synced, lastNote = 0, nil
  local function note(text) if text ~= lastNote then lastNote = text; diag("follower", text) end end
  local nextCheck = 0
  mod.hooks:wrap("render.hud", function(nextFn, game, ...)
    local okO, on = pcall(mod.options.get, mod.options, "followerLead")
    local t = love and love.timer and love.timer.getTime() or 0
    if not (okO and on == false) and t >= nextCheck then
      nextCheck = t + 0.5
      pcall(function()
        local ex = wilds()
        if not ex then return note("Wilds not running") end
        local stack = game and game.stack
        local top = stack and type(stack.top) == "function" and stack:top() or nil
        -- 0.9.44: Gen 2's overworld is NOT a stack state -- the stack is
        -- empty while you walk around (menus are pushed over game.world).
        -- 0.9.40-0.9.43 waited for a world-like top that never came, so the
        -- sync (and its diagnostics line) never ran.
        local worldTop = (top == nil and game.world ~= nil and game.world.player ~= nil)
          or (top ~= nil and (top == game.overworld or top == game.world))
        if not worldTop then return end
        local GC = wreq(ex, "game_compat")
        local Sel = wreq(ex, "follower/selection")
        local party = GC and GC.party and GC.party(game) or (game.save and game.save.party)
        if type(party) ~= "table" then return note("no party") end
        local isHealthy = (Sel and Sel.healthy) or healthy
        local lead
        for _, mon in ipairs(party) do if isHealthy(mon) then lead = mon; break end end
        if not lead then return note("no healthy Pokemon") end
        local active = ex.getActiveFollowerMon(game, true)
        if active == nil then return note("no follower out") end
        local fp = Sel and Sel.monFingerprint
        local same = active == lead or (fp and active and fp(active) == fp(lead))
        local name = tostring(lead.nickname or lead.species or "?")
        if same then return note(("following lead %s (%d syncs)"):format(name, synced)) end
        local okS, err = pcall(ex.selectFollower, lead, game, true)
        synced = synced + 1
        note(okS and ("switched to lead %s (%d syncs)"):format(name, synced)
          or ("switch failed: " .. tostring(err)))
      end)
    end
    return nextFn(game, ...)
  end, 50)
  return {}
end
