local RM = ns.RM
local msgs = {}
RaidNotice_AddMessage = function(_, t) table.insert(msgs, t) end
ChatTypeInfo = { RAID_WARNING = {} } UnitOnTaxi = function() return false end
RM.settings = { warnDistance = 500, muted = {}, sound = false }
RM.Data.ready = true
RM.Data.vendors = { [5] = { name = "Jutak", points = {} } }
RM.UI = RM.UI or {} RM.UI.ItemName = function(id) return "Rezept " .. id end
RM.Arrow = { Target = function() return true end }
local PX = RM.Proximity
PX.BuildIndex = function() end PX.UpdateZoneDot = function() end
PX.Nearest = function() return 5, 300, {} end
PX.Relevant = function() return { { id = 1, limited = true, hot = true, margin = 125000 }, { id = 2, limited = true, hot = true, margin = 300000 }, { id = 3, limited = true, hot = true, margin = 5000 }, { id = 4 } }, 3 end
RM.Print = function() end
PX:Check()
-- merchant highlight
MerchantFrame = newmock("MerchantFrame") MerchantFrame.page = 1 MerchantFrame.selectedTab = 1
MERCHANT_ITEMS_PER_PAGE = 10
for i = 1, 3 do _G["MerchantItem" .. i] = newmock("row") _G["MerchantItem" .. i .. "ItemButton"] = newmock("btn") end
RM.Merchant.highlight = { [1] = "stock", [2] = "out" }
local ok, err = pcall(function() RM.Merchant:UpdateHighlight() RM.Merchant.highlight = {} RM.Merchant:UpdateHighlight() end)
return table.concat(msgs, " || ") .. " | highlight " .. tostring(ok) .. " " .. tostring(err)
