local RM = ns.RM
local bought, shown = {}, nil
StaticPopup_Show = function(name, text, _, data) shown = { name = name, text = text, data = data } end
RM.UI = RM.UI or {} RM.UI.ItemName = function(id) return "Muster " .. id end RM.UI.ProfName = function() return "Schneiderei" end
RM.playerName = "Monaco Stenz"
MerchantFrame = newmock("MerchantFrame") MerchantFrame.selectedTab = 1
-- the guard wraps the global at load time; replace the original behind it via the upvalue by calling through
local guarded = BuyMerchantItem
RM.Merchant.bop = { [3] = { id = 4321, skill = 197 } }
guarded(2, 1)
guarded(3, 1)
local before = shown and shown.text or "no popup"
if shown then shown.data.buy() end
return "popup: " .. before .. " | bought: " .. table.concat(BUY_LOG, ",")
