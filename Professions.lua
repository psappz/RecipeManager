-- RecipeManager - Professions: skill lines of all characters, known recipes, reagents
-- Copyright (C) 2026 psappz - GPL-3.0-or-later
local _, ns = ...
local RM = ns.RM

local P = {}
RM.Prof = P

local function charRecord()
    local chars = RM.realm.chars
    local me = chars[RM.playerName]
    if not me then
        me = { known = {}, profs = {}, twink = true }
        chars[RM.playerName] = me
    end
    local _, class = UnitClass("player")
    me.class = class
    me.level = UnitLevel("player")
    me.faction = RM.faction
    me.seen = time()
    return me
end
P.Me = charRecord

-- Skill lines (Forever: C_SkillInfo, Classic: global API)
function P:ScanSkills()
    if not RM.realm then return end
    local me = charRecord()
    local profs = {}
    if C_SkillInfo and C_SkillInfo.GetNumSkillLines then
        for i = 1, C_SkillInfo.GetNumSkillLines() do
            local s = C_SkillInfo.GetSkillLineInfo(i)
            if s and not s.isHeader and s.skillID then
                profs[s.skillID] = s.rank
            end
        end
    elseif GetNumSkillLines then
        -- Classic fallback: match by localized name is not reliable; store by name only
        for i = 1, GetNumSkillLines() do
            local name, isHeader, _, rank = GetSkillLineInfo(i)
            if name and not isHeader then profs[name] = rank end
        end
    end
    -- keep only professions we know about
    local clean = {}
    for _, id in ipairs(RM.Data.PROFESSION_ORDER) do
        if profs[id] then clean[id] = profs[id] end
    end
    for _, id in ipairs({ 182, 186, 393 }) do -- gathering, shown in twink list
        if profs[id] then clean[id] = profs[id] end
    end
    me.profs = clean
    RM:Fire("PROFESSIONS_CHANGED")
end

function P:Skill(skillLine, charName)
    local c = RM.realm.chars[charName or RM.playerName]
    return c and c.profs and c.profs[skillLine]
end

-- Learned recipe names from the open profession window
function P:ScanTradeSkill()
    if not RM.realm then return end
    local me = charRecord()
    me.known = me.known or {}
    if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then
        local ok, ids = pcall(C_TradeSkillUI.GetAllRecipeIDs)
        if not ok or not ids then return end
        for _, recipeID in ipairs(ids) do
            local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
            if info and info.learned and info.name then
                me.known[info.name:lower()] = true
                self:StoreReagents(recipeID)
            end
        end
    elseif GetNumTradeSkills then
        for i = 1, GetNumTradeSkills() do
            local name, kind = GetTradeSkillInfo(i)
            if name and kind ~= "header" then me.known[name:lower()] = true end
        end
    end
    me.seen = time()
    RM:Fire("KNOWN_CHANGED")
end

function P:StoreReagents(recipeID)
    if not (C_TradeSkillUI.GetRecipeSchematic) then return end
    local ok, s = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
    if not ok or not s or not s.outputItemID then return end
    local list = {}
    for _, slot in ipairs(s.reagentSlotSchematics or {}) do
        local r = slot.reagents and slot.reagents[1]
        if r and r.itemID then list[r.itemID] = slot.quantityRequired or 1 end
    end
    local qty = s.quantityMin or 1
    RM.db.reagents[s.outputItemID] = { reagents = list, qty = qty }
end

-- Does character `name` know the recipe item?
function P:Knows(itemID, name)
    if (not name or name == RM.playerName) then
        local k = RM.Data:KnownByPlayer(itemID)
        if k ~= nil then return k end
    end
    local c = RM.realm.chars[name or RM.playerName]
    local bare = RM.Data:BareName(itemID)
    return bare and c and c.known and c.known[bare] or false
end

-- Twinks: same account, same realm (= ruleset), same faction, ticked as twink
function P:Twinks()
    local list = {}
    for name, c in pairs(RM.realm.chars) do
        if name ~= RM.playerName and c.faction == RM.faction then
            table.insert(list, name)
        end
    end
    table.sort(list)
    return list
end

RM:On("SKILL_LINES_CHANGED", function() P:ScanSkills() end)
RM:On("TRADE_SKILL_LIST_UPDATE", function() P:ScanTradeSkill() end)
RM:On("TRADE_SKILL_SHOW", function() C_Timer.After(0.5, function() P:ScanTradeSkill() end) end)
RM:On("CRAFT_UPDATE", function() P:ScanTradeSkill() end)
RM:On("PLAYER_LEVEL_UP", function() charRecord() end)
