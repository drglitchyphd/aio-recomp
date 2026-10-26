io.stdout:setvbuf("no")
local ROOT = love.filesystem.getSource():gsub("/tests/held_item_menu/?$", "") .. "/"
local PartyMenu = {}; PartyMenu.__index = PartyMenu
PartyMenu.new = function(game, opts) return setmetatable({ party = {}, index = 1, game = game }, PartyMenu) end
PartyMenu.update = function() end
PartyMenu.draw = function() end
local Held = {}; Held.__index = Held
function Held:mon() return { nickname = "TOTODILE" } end
local Typer = { text = function(self, p) return p end, typing = function() return false end }
package.preload["src.ui.gen2.PartyMenu"] = function() return PartyMenu end
package.preload["src.ui.gen2.HeldItemMenu"] = function() return Held end
package.preload["src.ui.gen2.Chrome"] = function() return {} end
package.preload["src.ui.gen2.Typer"] = function() return Typer end
local hooks = {}
local mod = { hooks = { wrap = function(_, name, fn) hooks[name] = fn end }, options = { get = function() return nil end } }
function love.load()
  love.graphics.getDimensions = function() return 1080, 2520 end
  local src = assert(io.open(ROOT.."lib/gen2_modern_party_ui.lua")):read("*a")
  local setup = assert(loadstring(src, "@party_ui"))()
  print("install", pcall(setup, mod))
  local party = PartyMenu.new({})
  local function frame(held, name)
    local game = { stack = { states = { party, held }, top = function() return held end } }
    local c = love.graphics.newCanvas(1080, 2520); love.graphics.setCanvas(c); love.graphics.clear(.2,.3,.25,1)
    local ok, err = pcall(hooks["render.hud"], function() end, game, {})
    love.graphics.setCanvas()
    print(name, ok, err, "taps", mod._kimScreenTapTargets and mod._kimScreenTapTargets.state == held, mod._kimScreenTapTargets and #mod._kimScreenTapTargets.cells)
    assert(ok,err)
    assert(mod._kimScreenTapTargets and mod._kimScreenTapTargets.state==held)
    local f = assert(io.open((os.getenv('AIO_TEST_OUTPUT') or os.getenv('TEMP') or '/tmp').."/aio-held-" .. name .. ".png", "wb")); f:write(c:newImageData():encode("png"):getString()); f:close()
  end
  print("hidden:", hooks["screen.render_visible"](function() return true end, setmetatable({}, Held)))
  frame(setmetatable({ index = 1 }, Held), "menu")
  frame(setmetatable({ index = 2, confirm = { pages = { { "TOTODILE is already", "holding BERRY." }, { "Switch items?" } }, page = 2, choice = 1 } }, Held), "confirm")
  love.event.quit(0)
end
