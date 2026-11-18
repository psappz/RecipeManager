local RM = ns.RM
RM.settings = RM.settings or {}
RM.settings.copilot = true RM.settings.copilotLearned = true RM.settings.muted = {}
RM.db = RM.db or {}
RM.db.collect = { crafts = { r3915 = { name="Braunes Leinenhemd", out=4344, qty=1, rea={[2996]=1,[2320]=1}, lineName="Schneiderei", learned=true } }, trainers = {} }
RM.db.recipeInfo = {} RM.db.reagents = {}
RM.realm = RM.realm or { chars = {}, observations = {}, vendors = {}, prices = {} }
RM.char = RM.char or { focus = {} }
_G.ProfessionsFrame = newmock("ProfessionsFrame")
C_TradeSkillUI = {
  GetAllRecipeIDs = function() return {3915} end,
  GetRecipeInfo = function(id) return { name = "R"..id, learned = true, relativeDifficulty = 3, icon = 1 } end,
  GetRecipeSchematic = function(id) return { outputItemID = 4344, quantityMin = 1, reagentSlotSchematics = {} } end,
  GetTradeSkillLine = function() return 197, "Schneiderei", 202, 300 end,
}
RM.Prices.AHPrice = function(self, id) if id == 4344 then return 5000 end if id == 2996 then return 300 end end
local rows = RM.Copilot:Rows()
local lines = RM.Copilot:DetailLines(rows[1])
return table.concat(lines, "\n"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
