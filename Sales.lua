-- RecipeManager - sales evidence: which recipes really sold, not only which were listed.
--   own    Journalator (plusmouse) records your own sold / failed auctions from the mailbox.
--          RecipeManager only reads its public API - it never tracks mails itself.
--   guild  RecipeManager users in the guild can share their own counts (opt-in, off by default).
-- Nobody can see other players' sales in the game; scans only show listings.
-- Copyright (C) 2026 psappz - GPL-3.0-or-later
local _, ns = ...
local RM = ns.RM
local L = ns.L

local S = {}
RM.Sales = S

local CALLER = "RecipeManager"
local PREFIX = "RMGR1"
local MAX_AGE = 30 * 86400            -- guild data older than 30 days is dropped

---------------------------------------------------------------------------
-- Journalator (own sales)
---------------------------------------------------------------------------
function S:HasJournalator()
    local api = Journalator and Journalator.API and Journalator.API.v1
    return api and type(api.GetRealmSuccessCountByItemName) == "function"
        and type(Journalator.Statistics) == "table" and true or false
end

local function call(fn, ...)
    local api = Journalator and Journalator.API and Journalator.API.v1
    local f = api and api[fn]
    if type(f) ~= "function" then return nil end
    local ok, v = pcall(f, CALLER, ...)
    if ok then return v end
end

-- { s = sold, f = failed (expired/cancelled), m = mean gross price per unit } or nil
function S:Own(itemID)
    if not self:HasJournalator() then return nil end
    local name = C_Item.GetItemNameByID(itemID)
    if not name then C_Item.RequestLoadItemDataByID(itemID) return nil end
    local s = call("GetRealmSuccessCountByItemName", name) or 0
    local f = call("GetRealmFailureCountByItemName", name) or 0
    if s + f == 0 then return nil end
    return { s = s, f = f, m = (s > 0) and call("GetRealmMeanSoldByItemName", name) or nil }
end

---------------------------------------------------------------------------
-- Guild (opt-in)
---------------------------------------------------------------------------
local function guildStore()
    RM.realm.guildSales = RM.realm.guildSales or {}
    return RM.realm.guildSales
end

-- Sum over all guild members who shared (without me): { s, f, m, n = members }
function S:Guild(itemID)
    if not RM.settings.shareGuild then return nil end
    local s, f, value, n = 0, 0, 0, 0
    local now = time()
    for _, rec in pairs(guildStore()) do
        local it = rec.items and rec.items[itemID]
        if it and now - (rec.t or 0) < MAX_AGE then
            s, f, n = s + it[1], f + it[2], n + 1
            if it[3] and it[1] > 0 then value = value + it[3] * it[1] end
        end
    end
    if s + f == 0 then return nil end
    return { s = s, f = f, m = (s > 0 and value > 0) and math.floor(value / s) or nil, n = n }
end

local registered = false
local function register()
    if not registered and C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        registered = C_ChatInfo.RegisterAddonMessagePrefix(PREFIX) and true or false
    end
    return registered
end

local lastShare = 0
function S:Share(force)
    if not (RM.settings.shareGuild and IsInGuild() and register() and self:HasJournalator()) then return end
    if not force and GetTime() - lastShare < 300 then return end
    lastShare = GetTime()
    local parts = {}
    for id in pairs(RM.Data.recipes) do
        local o = self:Own(id)
        if o then table.insert(parts, string.format("%d:%d:%d:%d", id, o.s, o.f, math.floor(o.m or 0))) end
    end
    local buf, len = {}, 0
    local function flush()
        if #buf > 0 then pcall(C_ChatInfo.SendAddonMessage, PREFIX, "S|" .. table.concat(buf, ";"), "GUILD") end
        buf, len = {}, 0
    end
    pcall(C_ChatInfo.SendAddonMessage, PREFIX, "R", "GUILD")      -- receivers reset my entry
    for _, p in ipairs(parts) do
        if len + #p + 1 > 240 then flush() end
        table.insert(buf, p)
        len = len + #p + 1
    end
    flush()
end

RM:On("CHAT_MSG_ADDON", function(_, prefix, msg, channel, sender)
    if prefix ~= PREFIX or channel ~= "GUILD" or not (RM.settings and RM.settings.shareGuild) then return end
    local who = (sender or ""):match("^[^-]+")
    if who == UnitName("player") then return end
    local kind, body = strsplit("|", msg, 2)
    local store = guildStore()
    if kind == "Q" then
        C_Timer.After(math.random(2, 15), function() S:Share() end)
    elseif kind == "R" then
        store[who] = { t = time(), items = {} }
    elseif kind == "S" and body then
        local rec = store[who] or { t = time(), items = {} }
        store[who] = rec
        rec.t = time()
        for id, s, f, m in body:gmatch("(%d+):(%d+):(%d+):(%d+)") do
            rec.items[tonumber(id)] = { tonumber(s), tonumber(f), tonumber(m) > 0 and tonumber(m) or nil }
        end
        RM:Fire("PRICES_CHANGED")
    end
end)

function S:Request()
    if RM.settings.shareGuild and IsInGuild() and register() then
        pcall(C_ChatInfo.SendAddonMessage, PREFIX, "Q", "GUILD")
    end
end

RM:Listen("DATA_READY", function()
    register()
    -- drop old guild entries
    local now = time()
    for who, rec in pairs(guildStore()) do if now - (rec.t or 0) > MAX_AGE then guildStore()[who] = nil end end
    C_Timer.After(20, function() S:Share(true) S:Request() end)
end)
RM:On("MAIL_CLOSED", function() C_Timer.After(3, function() S:Share() end) end)

---------------------------------------------------------------------------
-- Scoring
---------------------------------------------------------------------------
-- Evidence for a recipe item at a vendor price:
-- { src = "own"|"guild", s, f, rate, realized (net per unit), profit (expected per listing), buy (suggested count) }
function S:Evidence(itemID, vendorPrice, limited)
    local own, guild = self:Own(itemID), self:Guild(itemID)
    local e = own and { src = "own", s = own.s, f = own.f, m = own.m } or (guild and { src = "guild", s = guild.s, f = guild.f, m = guild.m, n = guild.n })
    if not e then return nil end
    if own and guild then                -- both: combine counts, own label stays
        e.s, e.f = own.s + guild.s, own.f + guild.f
        if own.m and guild.m then e.m = math.floor((own.m * own.s + guild.m * guild.s) / math.max(1, own.s + guild.s)) end
        e.m = e.m or own.m or guild.m
        e.src = "both"
    end
    -- smoothed sell-through rate: one lucky sale is not 100 %
    e.rate = (e.s + 1) / (e.s + e.f + 2)
    e.realized = e.m and RM.Prices:Net(e.m) or nil
    if e.realized and vendorPrice then
        e.margin = e.realized - vendorPrice
        e.profit = math.floor(e.rate * e.margin)
    end
    -- how many to buy at the vendor: only with a positive expected profit
    if e.profit and e.profit > 0 then
        if e.rate >= 0.7 then e.buy = limited and 3 or 5
        elseif e.rate >= 0.45 then e.buy = 2
        else e.buy = 1 end
    else
        e.buy = 0
    end
    return e
end

function S:EvidenceText(e)
    if not e then return "|cff8a8270-|r" end
    local label = (e.src == "guild") and L["guild"] or L["own"]
    local color = (e.rate >= 0.6) and "|cff8fe39b" or (e.rate >= 0.35 and "|cffffd100" or "|cffe0806a")
    return color .. string.format("%s %d/%d", label, e.s, e.s + e.f) .. "|r"
end
