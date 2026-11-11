-- RecipeManager - Collector: records what the WoW Forever client really shows at trainers and in
-- profession windows (costs, skill and level requirements, skill-up colours, reagents).
-- Data goes to RecipeManagerDB.collect and is used to verify the CMaNGOS / Classic base data.
-- Copyright (C) 2026 psappz - GPL-3.0-or-later
local _, ns = ...
local RM = ns.RM
local L = ns.L

local C = {}
RM.Collector = C
C.FORMAT = 1

local function store()
    local db = RM.db
    db.collect = db.collect or {}
    local c = db.collect
    if c.format ~= C.FORMAT then
        c.format = C.FORMAT
        c.trainers = c.trainers or {}
        c.crafts = c.crafts or {}
    end
    c.trainers = c.trainers or {}
    c.crafts = c.crafts or {}
    c.locale = GetLocale()
    local version, build = GetBuildInfo()
    c.client = (version or "?") .. "." .. (build or "?")
    c.addon = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("RecipeManager", "Version")
        or (GetAddOnMetadata and GetAddOnMetadata("RecipeManager", "Version")) or "?"
    return c
end

local function npcID(unit)
    local guid = UnitGUID(unit)
    if not guid then return end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind == "Creature" then return tonumber(id) end
end

local function call(fn, ...)
    if type(fn) ~= "function" then return end
    local res = { pcall(fn, ...) }
    if not res[1] then return end
    return select(2, unpack(res))
end

local function itemIDFromLink(link)
    return link and tonumber(link:match("item:(%d+)"))
end

local function spellIDFromLink(link)
    return link and tonumber(link:match("spell:(%d+)") or link:match("enchant:(%d+)"))
end

local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

---------------------------------------------------------------------------
-- Trainers
---------------------------------------------------------------------------
local FILTERS = { "available", "unavailable", "used" }
local scanning = false

function C:ScanTrainer()
    if scanning or not RM.db then return end
    if type(GetNumTrainerServices) ~= "function" then return end
    local id = npcID("npc")
    if not id then return end
    scanning = true

    -- show everything the trainer offers, then put the player's filters back
    local saved = {}
    if type(GetTrainerServiceTypeFilter) == "function" and type(SetTrainerServiceTypeFilter) == "function" then
        for _, f in ipairs(FILTERS) do
            saved[f] = call(GetTrainerServiceTypeFilter, f)
            if not saved[f] then call(SetTrainerServiceTypeFilter, f, 1) end
        end
    end

    local services = {}
    local header
    local n = call(GetNumTrainerServices) or 0
    for i = 1, n do
        local name, sub, kind = call(GetTrainerServiceInfo, i)
        if kind == "header" then
            header = name
        elseif name then
            local s = { name = name, sub = (sub ~= "" and sub) or nil, header = header, kind = kind }
            s.cost = call(GetTrainerServiceCost, i)
            local skillName, skillLevel = call(GetTrainerServiceSkillReq, i)
            if skillName then s.skill, s.skillLevel = skillName, skillLevel end
            s.level = call(GetTrainerServiceLevelReq, i)
            local link = call(GetTrainerServiceItemLink, i)
            s.item = itemIDFromLink(link)
            s.spell = spellIDFromLink(link) or (GetTrainerServiceSpellID and call(GetTrainerServiceSpellID, i))
            if s.level == 0 then s.level = nil end
            services[name .. "|" .. (s.sub or "")] = s
        end
    end

    for f, v in pairs(saved) do
        if not v then call(SetTrainerServiceTypeFilter, f, 0) end
    end
    scanning = false
    C.lastOwn = GetTime()
    if n == 0 then return end

    local c = store()
    local t = c.trainers[id]
    local added, changed = 0, 0
    if t then
        for k, s in pairs(services) do
            local old = t.services[k]
            if not old then added = added + 1
            else
                local a, b = {}, {}
                for _, f in ipairs({ "cost", "skill", "skillLevel", "level", "item", "spell" }) do a[f], b[f] = s[f], old[f] end
                if not same(a, b) then changed = changed + 1 end
            end
        end
    end
    local _, _, _, map, x, y = RM:PlayerWorldPos()
    c.trainers[id] = {
        name = UnitName("npc"), zone = GetZoneText(), map = map, x = x, y = y, faction = RM.faction,
        seen = time(), count = n, services = services,
        greeting = call(GetTrainerGreetingText),
    }
    local count = 0
    for _ in pairs(services) do count = count + 1 end
    if not t then
        RM:Print(L["Trainer recorded:"], UnitName("npc") or "?", "(" .. count .. ")")
    elseif added > 0 or changed > 0 then
        RM:Print(string.format(L["Trainer %s changed: %d new, %d changed."], UnitName("npc") or "?", added, changed))
        c.changes = c.changes or {}
        table.insert(c.changes, { npc = id, time = time(), added = added, changed = changed })
    end
    RM:Fire("COLLECT_CHANGED")
end

---------------------------------------------------------------------------
-- Profession windows
---------------------------------------------------------------------------
local DIFF = { [0] = "optimal", [1] = "medium", [2] = "easy", [3] = "trivial" }

local function lineInfo()
    if C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillLine then
        local a, b, c, d = call(C_TradeSkillUI.GetTradeSkillLine)
        if type(a) == "number" then return a, b, c, d end   -- id, name, rank, max
        if type(a) == "string" then return nil, a, b, c end -- name, rank, max
    end
    if C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo then
        local p = call(C_TradeSkillUI.GetBaseProfessionInfo)
        if type(p) == "table" then return p.professionID, p.professionName, p.skillLevel, p.maxSkillLevel end
    end
    if type(GetTradeSkillLine) == "function" then
        local name, rank, max = call(GetTradeSkillLine)
        return nil, name, rank, max
    end
end

local function record(c, key, entry, rank, diff)
    local old = c.crafts[key]
    if not old then
        entry.obs = {}
        c.crafts[key] = entry
        old = entry
    else
        for k, v in pairs(entry) do if k ~= "obs" then old[k] = v end end
    end
    if rank and diff then old.obs[rank] = diff end
end

function C:ScanTradeSkill()
    if not RM.db then return end
    local c = store()
    local lineID, lineName, rank = lineInfo()
    local n = 0
    if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then
        local ids = call(C_TradeSkillUI.GetAllRecipeIDs)
        for _, rid in ipairs(ids or {}) do
            local info = call(C_TradeSkillUI.GetRecipeInfo, rid)
            if info and info.name then
                local e = { name = info.name, line = lineID, lineName = lineName, learned = info.learned and true or nil }
                local s = C_TradeSkillUI.GetRecipeSchematic and call(C_TradeSkillUI.GetRecipeSchematic, rid, false)
                if type(s) == "table" then
                    e.out, e.qty = s.outputItemID, s.quantityMin
                    e.rea = {}
                    for _, slot in ipairs(s.reagentSlotSchematics or {}) do
                        local r = slot.reagents and slot.reagents[1]
                        if r and r.itemID then e.rea[r.itemID] = slot.quantityRequired or 1 end
                    end
                end
                local d = info.relativeDifficulty
                if type(d) == "number" then d = DIFF[d] end
                record(c, "r" .. rid, e, info.learned and rank or nil, info.learned and d or nil)
                n = n + 1
            end
        end
    elseif type(GetNumTradeSkills) == "function" then
        for i = 1, (call(GetNumTradeSkills) or 0) do
            local name, kind = call(GetTradeSkillInfo, i)
            if name and kind ~= "header" then
                local e = { name = name, lineName = lineName, learned = true, out = itemIDFromLink(call(GetTradeSkillItemLink, i)), rea = {} }
                for j = 1, (call(GetTradeSkillNumReagents, i) or 0) do
                    local _, _, count = call(GetTradeSkillReagentInfo, i, j)
                    local rid = itemIDFromLink(call(GetTradeSkillReagentItemLink, i, j))
                    if rid then e.rea[rid] = count or 1 end
                end
                record(c, "n" .. (lineName or "?") .. "|" .. name, e, rank, kind)
                n = n + 1
            end
        end
    end
    if n > 0 then
        c.lines = c.lines or {}
        c.lines[lineName or "?"] = { id = lineID, rank = rank, seen = time() }
        RM:Fire("COLLECT_CHANGED")
    end
end

-- Enchanting in Classic clients uses the separate Craft window
function C:ScanCraft()
    if not RM.db or type(GetNumCrafts) ~= "function" then return end
    local c = store()
    local lineName, rank = call(GetCraftDisplaySkillLine)
    for i = 1, (call(GetNumCrafts) or 0) do
        local name, _, kind = call(GetCraftInfo, i)
        if name and kind ~= "header" then
            local e = { name = name, lineName = lineName, learned = true, rea = {} }
            for j = 1, (call(GetCraftNumReagents, i) or 0) do
                local _, _, count = call(GetCraftReagentInfo, i, j)
                local rid = itemIDFromLink(call(GetCraftReagentItemLink, i, j))
                if rid then e.rea[rid] = count or 1 end
            end
            record(c, "c" .. (lineName or "?") .. "|" .. name, e, rank, kind)
        end
    end
    RM:Fire("COLLECT_CHANGED")
end

function C:Summary()
    local c = store()
    local trainers, services, crafts, colours = 0, 0, 0, 0
    for _, t in pairs(c.trainers) do
        trainers = trainers + 1
        for _ in pairs(t.services) do services = services + 1 end
    end
    for _, e in pairs(c.crafts) do
        crafts = crafts + 1
        for _ in pairs(e.obs or {}) do colours = colours + 1 end
    end
    RM:Print(string.format(L["Collected: %d trainers (%d entries), %d recipes, %d skill-up colours."], trainers, services, crafts, colours))
end

-- debounce: windows fire several update events in a row
local pending = {}
local function soon(what, fn)
    if pending[what] then return end
    pending[what] = true
    C_Timer.After(0.4, function() pending[what] = nil; fn() end)
end

RM:On("TRAINER_SHOW", function() soon("trainer", function() C:ScanTrainer() end) end)
-- our own filter switching fires TRAINER_UPDATE too; ignore it for a moment to avoid a loop
RM:On("TRAINER_UPDATE", function()
    if scanning or (C.lastOwn and GetTime() - C.lastOwn < 2) then return end
    soon("trainer", function() C:ScanTrainer() end)
end)
RM:On("TRADE_SKILL_SHOW", function() soon("trade", function() C:ScanTradeSkill() end) end)
RM:On("TRADE_SKILL_LIST_UPDATE", function() soon("trade", function() C:ScanTradeSkill() end) end)
RM:On("CRAFT_SHOW", function() soon("craft", function() C:ScanCraft() end) end)
RM:On("CRAFT_UPDATE", function() soon("craft", function() C:ScanCraft() end) end)
