-- Boots the bundle's main.lua on engine stubs (Crystal, Android) so the
-- GEN2-AIO hub and the settings it files can be checked without the engine.
local ROOT = (io.popen("pwd"):read("*l")) .. "/"
local OPTS = {}
local function U(name)
  local t = {}
  return setmetatable(t, {
    __index = function(s, k) local v = U(name .. "." .. tostring(k)); rawset(s, k, v); return v end,
    __call = function()
      if name:match("each$") or name:match("[Pp]airs$") or name:match("iter") then return function() return nil end end
      if name:sub(1, 4) == "love" or name:match("^g%.") or name:match("^fs%.") then return U(name .. "()") end
      return nil end,
    __concat = function(a, b) return tostring(a) .. tostring(b) end,
    __tostring = function() return name end,
    __len = function() return 0 end,
  })
end
love = U("love")
love.system = { getOS = function() return "Android" end }
love.graphics = setmetatable({ getDimensions = function() return 2184, 1968 end,
  getWidth = function() return 2184 end, getHeight = function() return 1968 end }, getmetatable(U("g")))
love.filesystem = setmetatable({ getInfo = function() return nil end, read = function() return nil end }, getmetatable(U("fs")))
love.timer = { getTime = function() return 0 end }

local hooks = {}
local Runtime = { safeMode = false }
function Runtime.call(name, base, ...)
  local h = hooks[name] or {}
  table.sort(h, function(a, b) return a.p < b.p end)
  local fn = base
  for _, link in ipairs(h) do local nextFn = fn; fn = function(...) return link.fn(nextFn, ...) end end
  return fn(...)
end
Runtime.wantsHook = function() return true end
Runtime.wants = function() return true end
Runtime.emit = function() end
Runtime.reportError = function() end
local OptionsMenu = {}; OptionsMenu.__index = OptionsMenu
local stubs = {
  ["src.mods.Runtime"] = Runtime,
  ["src.ui.gen2.OptionsMenu"] = OptionsMenu,
  ["src.render.Pipelines"] = { rows = function() return {} end, level = function() return 0 end,
    levelLabel = function() return "OFF" end, cycle = function() end, syncOptions = function() end },
  ["src.core.GameVersion"] = { generation = function() return 2 end, get = function() return "crystal" end,
    id = function() return "crystal" end, current = function() return "crystal" end },
}
local realRequire = require
require = function(n)
  if stubs[n] then return stubs[n] end
  if n == "bit" or n == "ffi" or n == "string" or n == "table" or n == "math" then return realRequire(n) end
  local v = U(n); stubs[n] = v; return v
end

local defined = {}   -- merged schema snapshots (last define wins)
local defineCalls = {}
local mod
local listeners = {}
mod = {
  id = "gen2-aio", generation = 2, path = ROOT:sub(1, -2), exports = {},
  log = setmetatable({}, { __index = function(_, k) return function(_, fmt, ...)
    if k == "error" or k == "warn" then
      local ok, s = pcall(string.format, tostring(fmt), ...)
      io.stderr:write("[" .. k .. "] " .. (ok and s or tostring(fmt)) .. "\n")
    end end end }),
  hooks = { wrap = function(_, name, fn, p)
    hooks[name] = hooks[name] or {}; hooks[name][#hooks[name] + 1] = { fn = fn, p = p or 0, n = #hooks[name] + 1 }
  end, on = function() end },
  events = { on = function(_, n, fn) listeners[n] = listeners[n] or {}; table.insert(listeners[n], fn) end,
    once = function() end, emit = function() end, off = function() end },
  options = {
    define = function(_, schema) defineCalls[#defineCalls + 1] = schema; defined = schema end,
    get = function(_, k)
      local v = OPTS[k]; if v ~= nil then return v end
      for _, r in ipairs(defined) do if r.key == k then return r.default end end
      return nil
    end,
  },
  content = U("content"), assets = U("assets"), cache = U("cache"),
  ui = U("ui"), save = U("save"), storage = U("storage"),
  find = function() return nil end,
}
mod.content.screens = { register = function() end, override = function() end }
mod.ui = { insertBefore = function(list, label, row)
  for i, it in ipairs(list) do if it.label == label then table.insert(list, i, row); return list end end
  list[#list + 1] = row; return list end, ListMenu = { new = function() return {} end }, push = function() end }
local function readFile(p)
  local f = io.open(ROOT .. p, "rb"); if not f then return nil, "missing " .. p end
  local s = f:read("*a"); f:close(); return s
end
function mod.read(_, rel) rel = tostring(rel):gsub("^%./", ""); return readFile(rel) end
function mod.list(_, rel)
  local out = {}
  local p = io.popen('ls "' .. ROOT .. rel .. '" 2>/dev/null')
  for l in p:lines() do out[#out + 1] = l end; p:close(); return out
end
function mod.info(_, rel)
  local p = io.popen('test -d "' .. ROOT .. rel .. '" && echo d || (test -f "' .. ROOT .. rel .. '" && echo f)')
  local r = p:read("*l"); p:close()
  if r == "d" then return { type = "directory" } elseif r == "f" then return { type = "file", size = 1 } end
end
-- mods.<id>.<path> requires
local function modRequire(n)
  local rel = n:match("^mods%.gen2%-aio%.(.+)$")
  if rel then
    local src = readFile(rel:gsub("%.", "/") .. ".lua")
    if src then return assert(loadstring(src, "@" .. rel))() end
  end
end
local prevRequire = require
require = function(n)
  if n:match("^mods%.gen2%-aio%.") then
    if stubs[n] == nil then local ok, v = pcall(modRequire, n); stubs[n] = ok and v or U(n) end
    return stubs[n]
  end
  return prevRequire(n)
end

local entry = assert(loadstring(readFile("main.lua"), "@main.lua"))()
local ok, err = pcall(entry, mod)
io.stderr:write("main ok " .. tostring(ok) .. " " .. tostring(err) .. "\n")
for _, fn in ipairs(listeners["game.ready"] or {}) do pcall(fn, { game = {} }) end

return { mod = mod, hooks = hooks, Runtime = Runtime, defined = function() return defined end,
  defineCalls = defineCalls, OPTS = OPTS, readFile = readFile }
