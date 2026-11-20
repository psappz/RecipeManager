-- Forever: first name + surname; two characters share the first name
local RM = ns.RM
UnitName = function() return "Monaco", "Stenz" end
UnitClass = function() return "Krieger", "WARRIOR" end
UnitLevel = function() return 42 end
RM.realm = { chars = { Monaco = { level = 1, class = "MAGE", profs = { [197] = 50 } }, ["Donk Mcallister"] = { level = 11 } } }
RM.playerName = RM:FullName()
RM:MigrateCharKey()
local r1 = RM.playerName .. " old=" .. tostring(RM.realm.chars.Monaco) .. " stenz=" .. tostring(RM.realm.chars["Monaco Stenz"])
-- matching old entry is taken over
UnitName = function() return "Monaco", "Bank" end UnitLevel = function() return 1 end UnitClass = function() return "Magier", "MAGE" end
RM.realm.chars.Monaco = { level = 1, class = "MAGE", profs = { [197] = 50 } }
RM.playerName = RM:FullName() RM:MigrateCharKey()
local b = RM.realm.chars["Monaco Bank"]
return r1 .. " | " .. RM.playerName .. " claimed=" .. tostring(b and b.profs[197]) .. " | sender " .. RM:SenderName("Monaco-Stenz") .. " / " .. RM:SenderName("Jd-Icelance-Realm")
