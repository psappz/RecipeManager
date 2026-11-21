local RM = ns.RM
local M = RM.Merchant
local printed = {}
RM.Print = function(_, t) table.insert(printed, t) end
RM.UI = RM.UI or {} RM.UI.ItemName = function(id) return "Muster " .. id end
RM.settings = { autoBuy = true, autoBuyMax = 5, autoBuyQty = 2 }
RM.db = { watch = { [101] = true, [102] = true } }
local items = { { id = 101, price = 40000, avail = 3 }, { id = 102, price = 90000, avail = 1 }, { id = 103, price = 100, avail = 1 }, { id = 104, price = 20000, avail = 3 } }
RM.db.watch[104] = true
RM.Data.RecipeInfo = function(_, id) return { bind = id == 104 and "BoP" or "BoE" } end
RM.Prof.Knows = function() return false end
GetItemCount = function() return 0 end
GetMerchantNumItems = function() return #items end
GetMerchantItemLink = function(i) return "item:" .. items[i].id end
C_Item = C_Item or {} C_Item.GetItemInfoInstant = function(l) return tonumber(l:match("%d+")) end
C_MerchantFrame = { GetItemInfo = function(i) local it = items[i] return { name = "x", price = it.price, stackCount = 1, numAvailable = it.avail } end }
GetMoney = function() return 1000000 end
M.highlight = { "stock", "stock", "stock", "stock" } M.bop = {}
local t = 1000
GetTime = function() return t end
for k = 1, 8 do M:AutoBuy() t = t + 1 end
return "bought: " .. table.concat(BUY_LOG, ",") .. " | " .. table.concat(printed, " / ")
