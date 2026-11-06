-- gen2-aio 0.9.77: QUICK SELL at the Poke Mart.
--
--   * SELL VALUABLES (sell list): one YES / NO for the total, then every
--     item that exists only to be sold (Nuggets, Pearls, Stardust, the
--     mushrooms, Slowpoke Tails...) goes at once.
--   * ALL (quantity picker): the whole stack, then the mart's usual price
--     question.
--
-- Everything goes through MartMenu's own pieces -- MartMenu.sellPrice (half
-- price, halved after the multiply as on the cart), setMoney (clamped at the
-- money cap), Bag.remove, ask / say, playTransaction -- so a sale here pays
-- exactly what selling the same stacks one by one would.
return function(host)
  local mod = host.mod
  local okM, MartMenu = pcall(require, "src.ui.gen2.MartMenu")
  local okB, Bag = pcall(require, "src.inventory.Bag")
  if not (okM and type(MartMenu) == "table" and okB and type(Bag) == "table") then return nil end

  -- Crystal's sell-only treasures (both spellings the item tables use)
  local VALUABLES = { "NUGGET", "PEARL", "BIG_PEARL", "STARDUST", "STAR_PIECE",
    "TINYMUSHROOM", "TINY_MUSHROOM", "BIG_MUSHROOM", "SLOWPOKETAIL", "SLOWPOKE_TAIL",
    "BRICK_PIECE", "SILVER_LEAF", "GOLD_LEAF" }

  local QS = {}
  -- what SELL VALUABLES would sell: { {id, name, qty, total}, ... }, total
  function QS.valuables(mart)
    local inv = mart and mart.save and mart.save.inventory
    local items = mart and mart.items
    local list, sum = {}, 0
    if type(inv) ~= "table" or type(items) ~= "table" then return list, 0 end
    for _, id in ipairs(VALUABLES) do
      local n = tonumber(inv[id]) or 0
      local def = items[id]
      if n > 0 and def and def.canToss ~= false and (def.price or 0) > 0 then
        local total = MartMenu.sellPrice(def.price, n)
        list[#list + 1] = { id = id, name = def.name or id, qty = n, total = total }
        sum = sum + total
      end
    end
    return list, sum
  end

  function QS.sellValuables(mart)
    if not (mart and mart.phase == "sell") or mart.message or mart.confirm then return false end
    local list, sum = QS.valuables(mart)
    if #list == 0 then return false end
    mart:ask({ { "Sell all your", "valuables?" }, { ("I can pay you ¥%d."):format(sum), "Is that OK?" } },
      function()
        local paid = 0
        for _, v in ipairs(list) do
          mart:setMoney(mart:money() + v.total)
          Bag.remove(mart.save, v.id, v.qty)
          paid = paid + v.total
        end
        if mart.pack and type(mart.pack.rebuild) == "function" then mart.pack:rebuild() end
        mart.phase = "sell"
        if type(mart.playTransaction) == "function" then mart:playTransaction() end
        mart:say({ { ("Got ¥%d for"):format(paid), "your valuables." } })
      end,
      function() mart.phase = "sell" end)
    return true
  end

  -- ALL in the quantity picker: the whole stack (the price question follows
  -- on A as usual)
  function QS.all(mart)
    if mart and mart.phase == "sellQuantity" and tonumber(mart.qtyMax) then
      mart.qty = mart.qtyMax
      return true
    end
    return false
  end

  mod._kimArenaQuickSell = QS
  return QS
end
