-- 0.9.77 QUICK SELL (lib/gen2_aio/quick_sell.lua) on the engine's real
-- MartMenu and Bag: SELL VALUABLES pays what selling each stack would, and
-- ALL fills the quantity picker. Run from the repo root with
-- AIO_ENGINE=<engine>/src (skips without it): luajit tests/quick_sell.lua
local engine = os.getenv("AIO_ENGINE")
if not engine then print("quick sell: SKIP (set AIO_ENGINE to the engine's src root)") return end
love = { graphics = setmetatable({}, { __index = function() return function() end end }),
  timer = { getTime = function() return 0 end }, audio = setmetatable({}, { __index = function() return function() end end }) }
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path
local MartMenu = require("src.ui.gen2.MartMenu")
local n = 0
local function check(c, m) if not c then error("FAIL: " .. m, 2) end n = n + 1 end
local mod = {}
local QS = assert(loadfile("lib/gen2_aio/quick_sell.lua"))()({ mod = mod })
check(QS and mod._kimArenaQuickSell == QS, "quick sell installed")

local items = {
  NUGGET = { name = "NUGGET", price = 10000, pocket = "ITEM" },
  STARDUST = { name = "STARDUST", price = 2000, pocket = "ITEM" },
  BIG_MUSHROOM = { name = "BIG MUSHROOM", price = 5000, pocket = "ITEM" },
  POTION = { name = "POTION", price = 300, pocket = "ITEM" },
}
local save = { player = { money = 1000 }, inventory = { NUGGET = 2, STARDUST = 3, POTION = 5, BIG_MUSHROOM = 1 } }
local game = { save = save, data = { items = items }, input = { wasPressed = function() return false end } }
local mart = MartMenu.new(game, { save = save, items = items, martType = "STANDARD" })
mart.phase = "sell"
local list, sum = QS.valuables(mart)
local expected = MartMenu.sellPrice(10000, 2) + MartMenu.sellPrice(2000, 3) + MartMenu.sellPrice(5000, 1)
check(#list == 3 and sum == expected, "valuables: nuggets, stardust, mushroom = " .. tostring(sum))
check(QS.sellValuables(mart) and mart.confirm ~= nil, "SELL VALUABLES asks first")
mart.confirm.onNo()
check(save.player.money == 1000 and save.inventory.NUGGET == 2, "NO sells nothing")
mart.confirm = nil
QS.sellValuables(mart)
mart.confirm.onYes()
check(save.player.money == 1000 + expected, "YES pays the mart's own price: " .. save.player.money)
check(not save.inventory.NUGGET and not save.inventory.STARDUST and not save.inventory.BIG_MUSHROOM,
  "valuables gone")
check(save.inventory.POTION == 5, "everything else stays")
check(mart.message ~= nil, "the clerk says what you got")
mart.message = nil; mart.confirm = nil
local l2 = QS.valuables(mart)
check(#l2 == 0 and not QS.sellValuables(mart), "nothing left: no SELL VALUABLES")
-- ALL in the quantity picker
mart:offerToSell("POTION", 5)
check(mart.phase == "sellQuantity" and mart.qty == 1, "picker opens at 1")
check(QS.all(mart) and mart.qty == 5, "ALL picks the whole stack")
print(("quick sell: %d checks PASS"):format(n))
