local RM = ns.RM
RM.settings = { muted = {}, learnAhead = 10, warnDistance = 1000, hotMinMargin = 5000, hotFactor = 2, luxFactor = 4, priceSource = "auto", nearRadius = 300, autoBuy = true, autoBuyMax = 5, autoBuyQty = 3 }
RM.realm = { chars = { ["Monaco Stenz"] = { profs = { [197] = 202 }, level = 49 } }, observations = {}, vendors = {}, prices = {} }
RM.char = { focus = nil } RM.playerName = "Monaco Stenz" RM.faction = "Horde"
RM.db = { collect = { crafts = {}, trainers = {} }, watch = {} }
local page = newmock("page")
local ok, err = pcall(RM.Settings.Build, page)
if not ok then return "build: " .. tostring(err) end
local ok2, err2 = pcall(function() RM.Settings:Refresh(page) end)
return "build ok, refresh " .. tostring(ok2) .. " " .. tostring(err2)
