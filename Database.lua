-- RecipeManager - Database: recipe extract from QuestieDB, Limited Supply list, learned vendors
-- Copyright (C) 2026 psappz - GPL-3.0-or-later
local _, ns = ...
local RM = ns.RM
local L = ns.L

local DB = {}
RM.Data = DB

-- Item subclass of class 9 (Recipe) -> profession skill line ID
DB.SKILL_BY_SUBCLASS = {
    [1] = 165, -- Leatherworking
    [2] = 197, -- Tailoring
    [3] = 202, -- Engineering
    [4] = 164, -- Blacksmithing
    [5] = 185, -- Cooking
    [6] = 171, -- Alchemy
    [7] = 129, -- First Aid
    [8] = 333, -- Enchanting
    [9] = 356, -- Fishing
}
DB.SECONDARY = { [185] = true, [129] = true, [356] = true }
DB.PROFESSION_ORDER = { 171, 164, 333, 202, 165, 197, 185, 129, 356 }

-- Vendor subnames (English base data) that mean a reputation quartermaster
local REP_PATTERNS = { "Quartermaster", "Argent Dawn", "Cenarion", "Timbermaw", "Thorium",
    "Zandalar", "Hydraxian", "Brood", "Emissary", "Supply Officer", "Wintersaber",
    "Frostwolf", "Stormpike", "Silverwing", "Warsong", "Arathor", "Defilers", "League" }

DB.recipes = {}        -- [itemID] = { id, skillLine, vendors = {npcID...}, quests, drops, rep = bool }
DB.vendors = {}        -- [npcID] = { name, faction = "A"/"H"/"AH", rep, points = { {uiMap, x, y} }, recipes = {itemID...} }
DB.vendorsByMap = {}   -- [uiMapID] = { npcID, ... }
DB.ready = false

local function isRepVendor(npc)
    local sub = NpcDB.GetRaw and NpcDB.GetRaw(npc, "subName") or NpcDB.subName(npc)
    if type(sub) ~= "string" then return false end
    for _, p in ipairs(REP_PATTERNS) do
        if sub:find(p, 1, true) then return true end
    end
    return false
end

local function loadAreaToUiMap()
    local ok, zdb = pcall(LibQuestieDB.Support.Get, "ZoneDB")
    if not ok or not zdb or not zdb.private then return {} end
    local m = zdb.private.areaIdToUiMapId
    if type(m) == "string" then
        local f = loadstring(m)
        local ok2, t = pcall(f or function() end)
        m = ok2 and t or nil
    end
    return type(m) == "table" and m or {}
end

function DB:QuestieAvailable()
    return type(LibQuestieDB) == "table" and type(ItemDB) == "table" and type(NpcDB) == "table"
end

function DB:AddVendor(npc, areaToUi)
    if self.vendors[npc] then return self.vendors[npc] end
    local spawns = NpcDB.spawns(npc)
    local v = {
        id = npc,
        name = NpcDB.name(npc) or ("NPC " .. npc),
        faction = NpcDB.friendlyToFaction(npc),
        rep = isRepVendor(npc),
        points = {},
        recipes = {},
    }
    if spawns then
        for areaId, coords in pairs(spawns) do
            local ui = areaToUi[areaId]
            if ui and type(coords) == "table" then
                for _, c in ipairs(coords) do
                    if c[1] and c[1] >= 0 then
                        table.insert(v.points, { ui, c[1] / 100, c[2] / 100 })
                    end
                end
                self.vendorsByMap[ui] = self.vendorsByMap[ui] or {}
                table.insert(self.vendorsByMap[ui], npc)
            end
        end
    end
    self.vendors[npc] = v
    return v
end

-- Builds the extract in small slices so login does not stall.
function DB:Build(onDone)
    if not self:QuestieAvailable() then
        RM:Print(L["QuestieDB is missing or disabled. RecipeManager stays inactive."])
        return
    end
    if LibQuestieDB.RequireContract then
        local ok, msg = LibQuestieDB.RequireContract(1)
        if not ok then
            RM:Print(msg or L["QuestieDB version not supported."])
            return
        end
    end
    local areaToUi = loadAreaToUiMap()
    local ids = ItemDB.GetAllIds()
    local i, n = 1, #ids
    local SLICE = 400
    local ticker
    ticker = C_Timer.NewTicker(0, function()
        local stop = math.min(i + SLICE - 1, n)
        for k = i, stop do
            local id = ids[k]
            if ItemDB.class(id) == 9 then
                local sub = ItemDB.subClass(id)
                local skill = self.SKILL_BY_SUBCLASS[sub]
                if skill then
                    local rec = {
                        id = id,
                        skillLine = skill,
                        vendors = ItemDB.vendors(id),
                        quests = ItemDB.questRewards(id),
                        drops = ItemDB.npcDrops(id),
                        limited = ns.LimitedSupply[id],
                        product = ns.RecipeProducts[id],
                    }
                    local allRep = rec.vendors and #rec.vendors > 0
                    if rec.vendors then
                        for _, npc in ipairs(rec.vendors) do
                            local v = self:AddVendor(npc, areaToUi)
                            table.insert(v.recipes, id)
                            if not v.rep then allRep = false end
                        end
                    end
                    rec.rep = allRep or false
                    self.recipes[id] = rec
                end
            end
        end
        i = stop + 1
        if i > n then
            ticker:Cancel()
            self:MergeLearned(areaToUi)
            self.ready = true
            if onDone then onDone() end
            RM:Fire("DATA_READY")
        end
    end)
end

-- Merge vendors/recipes the addon has observed in game (Forever-only content)
function DB:MergeLearned()
    for npc, obs in pairs(RM.realm.observations) do
        local lv = RM.realm.vendors[npc]
        local v = self.vendors[npc]
        if not v and lv then
            v = { id = npc, name = lv.name, faction = lv.faction, rep = false, points = {}, recipes = {} }
            if lv.map then
                table.insert(v.points, { lv.map, lv.x, lv.y })
                self.vendorsByMap[lv.map] = self.vendorsByMap[lv.map] or {}
                table.insert(self.vendorsByMap[lv.map], npc)
            end
            self.vendors[npc] = v
        end
        if v then
            for itemID, o in pairs(obs) do
                local rec = self.recipes[itemID]
                if not rec and o.skillLine then
                    rec = { id = itemID, skillLine = o.skillLine, vendors = {}, learned = true, product = ns.RecipeProducts[itemID] }
                    self.recipes[itemID] = rec
                end
                if rec then
                    rec.vendors = rec.vendors or {}
                    local has = false
                    for _, x in ipairs(rec.vendors) do if x == npc then has = true break end end
                    if not has then
                        table.insert(rec.vendors, npc)
                        table.insert(v.recipes, itemID)
                    end
                    if o.limited then
                        rec.limitedSeen = true
                    end
                end
            end
        end
    end
end

function DB:IsLimited(itemID, npc)
    local rec = self.recipes[itemID]
    if not rec then return false end
    if npc then
        local o = RM.realm.observations[npc] and RM.realm.observations[npc][itemID]
        if o and o.limited ~= nil then return o.limited end
        return rec.limited and rec.limited[npc] ~= nil or false
    end
    return (rec.limited ~= nil) or rec.limitedSeen or false
end

function DB:RestockSeconds(itemID, npc)
    local rec = self.recipes[itemID]
    local l = rec and rec.limited and rec.limited[npc]
    return l and l[2]
end

function DB:VendorAllowed(v)
    if not v then return false end
    if v.favor then return false end
    local f = v.faction
    if not f then return true end -- unknown: allow
    if RM.faction == "Horde" then return f:find("H", 1, true) ~= nil end
    if RM.faction == "Alliance" then return f:find("A", 1, true) ~= nil end
    return true
end

-- Recipe meta from the item tooltip: required skill and bind type (cached per account)
local MIN_SKILL_PATTERN
function DB:RecipeInfo(itemID)
    local cache = RM.db.recipeInfo
    local info = cache[itemID]
    if info and info.skill then return info end
    if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return info end
    MIN_SKILL_PATTERN = MIN_SKILL_PATTERN or RM:FormatToPattern(ITEM_MIN_SKILL)
    local data = C_TooltipInfo.GetItemByID(itemID)
    if not data or not data.lines then return info end
    info = info or {}
    for _, line in ipairs(data.lines) do
        local t = line.leftText
        if t then
            if t == ITEM_BIND_ON_PICKUP then info.bind = "BoP"
            elseif t == ITEM_BIND_ON_EQUIP or t == ITEM_BIND_ON_USE then info.bind = info.bind or "BoE" end
            if MIN_SKILL_PATTERN then
                local _, rank = t:match(MIN_SKILL_PATTERN)
                if rank then info.skill = tonumber(rank) end
            end
        end
    end
    info.bind = info.bind or "BoE"
    cache[itemID] = info
    return info
end

-- Known by the current character? (tooltip "Already known"), cached until something is learned
local knownCache = {}
function DB:KnownByPlayer(itemID)
    if knownCache[itemID] ~= nil then return knownCache[itemID] end
    if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return nil end
    local data = C_TooltipInfo.GetItemByID(itemID)
    if not data or not data.lines then return nil end
    local known = false
    for _, line in ipairs(data.lines) do
        if line.leftText == ITEM_SPELL_KNOWN then known = true break end
    end
    knownCache[itemID] = known
    return known
end
local function clearKnown() wipe(knownCache) end
RM:On("NEW_RECIPE_LEARNED", clearKnown)
RM:On("LEARNED_SPELL_IN_TAB", clearKnown)
RM:On("TRADE_SKILL_LIST_UPDATE", clearKnown)
RM:On("SKILL_LINES_CHANGED", clearKnown)

-- Recipe name without the "Pattern: " prefix, used to match learned recipe names of alts
function DB:BareName(itemID)
    local name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
    if not name then
        C_Item.RequestLoadItemDataByID(itemID)
        return nil
    end
    local bare = name:match("^[^:]+:%s*(.+)$") or name
    return bare:lower()
end

function DB:ProfessionName(skillLine)
    -- C_TradeSkillUI.GetTradeSkillDisplayName may be missing or fail in Classic clients; never let it break the UI
    local name
    local f = C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName
    if type(f) == "function" then
        local ok, n = pcall(f, skillLine)
        if ok and type(n) == "string" and n ~= "" then name = n end
    end
    return name or L["PROF_" .. skillLine] or tostring(skillLine)
end

function DB:Rank(skill)
    if not skill then return nil end
    if skill < 75 then return "Apprentice" end
    if skill < 150 then return "Journeyman" end
    if skill < 225 then return "Expert" end
    return "Artisan"
end
