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

-- Season of Discovery content is not part of WoW Forever, but the client and QuestieDB still carry
-- some of it. Recipe spells: the AtlasLoot list plus the SoD spell range (Forever's own recipes start
-- at 1229000); items: the SoD item range (Forever's own items start above 249000).
function DB:IsSoDSpell(id)
    if not id then return false end
    return (ns.SoDRecipes and ns.SoDRecipes[id]) or (id >= 400000 and id < 1229000) or false
end

function DB:IsSoDItem(id)
    return id ~= nil and id >= 200000 and id < 245000
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
            if ItemDB.class(id) == 9 and not self:IsSoDItem(id) and not self:IsSoDItem(ns.RecipeProducts[id]) then
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
                        loot = ns.LootSources and ns.LootSources[id],
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

-- World events (client holiday id): calendar names to recognise them, and the usual dates as fallback
-- (the Lunar Festival follows the lunar calendar: the fallback window is wide on purpose)
DB.HOLIDAYS = {
    [141] = { key = "Feast of Winter Veil", words = { "winter veil", "winterhauch", "voile d'hiver", "invierno", "inverno" },
        from = { 12, 15 }, to = { 1, 2 } },
    [327] = { key = "Lunar Festival", words = { "lunar festival", "mondfest", "fête lunaire", "festival lunar", "festa lunare" },
        from = { 1, 20 }, to = { 2, 20 } },
    [404] = { key = "Pilgrim's Bounty", words = { "pilgrim", "pilgerfreuden", "bienfaits du pèlerin", "generosidad", "abbondanza", "fartura" },
        from = { 11, 21 }, to = { 11, 28 } },
}

-- Recipes that only come from a world event (event vendors, event gifts and quests), from the
-- world event lists of AtlasLootClassic and later holiday recipes. Recipe item -> holiday id.
DB.SEASONAL_RECIPES = {
    -- Feast of Winter Veil
    [17200] = 141, [17201] = 141, [17706] = 141, [17709] = 141, [17720] = 141, [17722] = 141, [17724] = 141, [17725] = 141,
    [34261] = 141, [34319] = 141, [34413] = 141,
    -- Lunar Festival (Coins of Ancestry)
    [21722] = 327, [21723] = 327, [21724] = 327, [21725] = 327, [21726] = 327, [21727] = 327, [21728] = 327, [21729] = 327,
    [21730] = 327, [21731] = 327, [21732] = 327, [21733] = 327, [21734] = 327, [21735] = 327, [21737] = 327, [21738] = 327,
    -- Pilgrim's Bounty
    [44858] = 404, [44859] = 404, [44860] = 404, [44861] = 404, [44862] = 404,
}

local holidayCache, calendarOpened = {}, false
local function today()
    if C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime then
        local ok, t = pcall(C_DateAndTime.GetCurrentCalendarTime)
        if ok and type(t) == "table" and t.month then return t.month, t.monthDay, t.year end
    end
    local t = date("*t")
    return t.month, t.day, t.year
end

-- the game's calendar: true/false when it knows today's events, nil when it has nothing loaded
local function calendarSays(id, h, month, day, year)
    local C = C_Calendar
    if not (C and C.GetNumDayEvents and C.GetDayEvent and C.GetMonthInfo) then return nil end
    if not calendarOpened and C.OpenCalendar then calendarOpened = true pcall(C.OpenCalendar) end
    local ok, mi = pcall(C.GetMonthInfo, 0)
    if not ok or type(mi) ~= "table" or mi.month ~= month or mi.year ~= year then return nil end
    local ok2, n = pcall(C.GetNumDayEvents, 0, day)
    if not ok2 or not n or n == 0 then return nil end
    local holidays = 0
    for i = 1, n do
        local ok3, e = pcall(C.GetDayEvent, 0, day, i)
        if ok3 and type(e) == "table" and e.calendarType == "HOLIDAY" then
            holidays = holidays + 1
            if e.eventID == id then return true end
            local title = type(e.title) == "string" and e.title:lower() or ""
            for _, w in ipairs(h.words) do
                if title:find(w, 1, true) then return true end
            end
        end
    end
    if holidays > 0 then return false end
    return nil
end

local function inWindow(h, month, day)
    local d = month * 100 + day
    local a, b = h.from[1] * 100 + h.from[2], h.to[1] * 100 + h.to[2]
    if a <= b then return d >= a and d <= b end
    return d >= a or d <= b -- over the turn of the year
end

-- Is the world event running today? Calendar first, the usual dates otherwise.
function DB:HolidayActive(id)
    local h = self.HOLIDAYS[id]
    if not h then return true end -- unknown event: do not hide anything
    local c = holidayCache[id]
    if c and GetTime() - c.at < 300 then return c.on end
    local month, day, year = today()
    local on = calendarSays(id, h, month, day, year)
    if on == nil then on = inWindow(h, month, day) end
    holidayCache[id] = { on = on, at = GetTime() }
    return on
end

-- Seasonal recipe: holiday id and whether it is running
function DB:RecipeSeason(itemID)
    local id = itemID and self.SEASONAL_RECIPES[itemID]
    if not id then return nil end
    return id, self:HolidayActive(id)
end

-- Seasonal vendor (only there during a world event): known event NPC, or every recipe it sells
-- belongs to the same event. Holiday id and whether it is running.
function DB:VendorSeason(v)
    if not v then return nil end
    local id = v.id and ns.SeasonalVendors and ns.SeasonalVendors[v.id]
    if not id and v.season == nil then
        local h = false
        for _, item in ipairs(v.recipes or {}) do
            local r = self.SEASONAL_RECIPES[item]
            if not r or (h and h ~= r) then h = false break end
            h = r
        end
        v.season = h
    end
    id = id or v.season or nil
    if not id then return nil end
    return id, self:HolidayActive(id)
end

function DB:VendorAllowed(v)
    if not v then return false end
    if v.favor then return false end
    local season, running = self:VendorSeason(v)
    if season and not running then return false, "season" end
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
