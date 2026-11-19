-- a foreign addon owns the ItemDB global; RecipeManager must use LibQuestieDB.Item
local RM = ns.RM
RM.realm = { chars = {}, observations = {}, vendors = {}, prices = {} } RM.settings = RM.settings or {} RM.db = { recipeInfo = {}, collect = { crafts = {} } }
local item = { GetAllIds = function() return { 1, 2 } end, class = function(id) return id == 2 and 9 or 0 end,
  subClass = function() return 2 end, name = function(id) return "Item" .. id end,
  vendors = function() return nil end, questRewards = function() return nil end, npcDrops = function() return nil end,
  requiredSkill = function() return 197 end, requiredSkillLevel = function() return 50 end, objectDrops = function() end }
local npc = { GetAllIds = function() return {} end, name = function() return "N" end, spawns = function() return {} end,
  friendlyToFaction = function() return "AH" end, subName = function() return nil end }
_G.LibQuestieDB = { Item = item, Npc = npc, Object = { GetAllIds = function() return {} end }, Quest = { GetAllIds = function() return {} end } }
_G.ItemDB = { foreign = true }
local pending
C_Timer.NewTicker = function(_, f) pending = f return { Cancel = function() pending = nil end } end
local ok = RM.Data:QuestieAvailable()
local done = false
local ok2, err = pcall(function() RM.Data:Build(function() done = true end) for i = 1, 10 do if pending then pending() end end end)
return "available " .. tostring(ok) .. " usesLib " .. tostring(ns.Q.Item == item) .. " build " .. tostring(ok2) .. " " .. tostring(err) .. " done " .. tostring(done) .. " recipes " .. tostring(RM.Data.recipes and RM.Data.recipes[2] ~= nil)
