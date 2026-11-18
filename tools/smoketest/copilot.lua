local RM = ns.RM
RM.settings = RM.settings or {}
local s = RM.settings
s.copilot = true s.copilotLearned = true s.muted = {}
RM.db = RM.db or {}
RM.db.collect = { crafts = { r3915 = { name="Braunes Leinenhemd", out=4344, rea={[2996]=1}, lineName="Schneiderei", learned=true }, r12087 = {name="Sturmstoffschultern", out=10038, lineName="Schneiderei"} }, trainers = {} }
RM.db.recipeInfo = {}
RM.realm = RM.realm or { chars = {}, observations = {}, vendors = {} }
RM.char = RM.char or { focus = {} }
RM.W = RM.W
_G.ProfessionsFrame = newmock("ProfessionsFrame")
C_TradeSkillUI = {
  GetAllRecipeIDs = function() return {3915, 12087, 1257479, 435841} end,
  GetRecipeInfo = function(id) return { name = "R"..id, learned = id == 3915, relativeDifficulty = 0, icon = 1 } end,
  GetRecipeSchematic = function(id) return { outputItemID = id+1, reagentSlotSchematics = {} } end,
  GetTradeSkillLine = function() return 197, "Schneiderei", 202, 300 end,
  GetRecipeSourceText = function() return nil end,
}
local ok, err = pcall(function() RM.Copilot:Refresh() end)
if not ok then return "Refresh error: " .. tostring(err) end
local p = _G.ProfessionsFrame.rmCopilot
if not p then return "no panel" end
local ok2, err2 = pcall(function() RM.Copilot:Select(p.table.data and p.table.data[1] and p.table.data[1].row) end)
local n = #p.table.data
local dbg = "sel="..tostring(RM.Copilot.selected).." first="..tostring(p.table.data[1] and p.table.data[1].row and p.table.data[1].row.id)
local ok3, err3 = pcall(function() RM.settings.copilotHide.orange = true RM.Copilot:Refresh() RM.Copilot:Refresh() end)
return dbg.." rows "..n.." select "..tostring(ok2).." "..tostring(err2).." detail shown "..tostring(p.detail:IsShown()).." filter "..tostring(ok3).." "..tostring(err3).." rows after "..#p.table.data
