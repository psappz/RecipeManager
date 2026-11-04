-- RecipeManager - Core: namespace, events, saved variables, helpers
-- Copyright (C) 2026 psappz - GPL-3.0-or-later
local ADDON, ns = ...

local RM = {}
ns.RM = RM
_G.RecipeManager = RM
RM.name = ADDON
RM.version = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON, "Version") or "?"

local L = ns.L

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
local handlers = {}
RM.eventFrame = frame

function RM:On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        frame:RegisterEvent(event)
    end
    table.insert(handlers[event], fn)
end

frame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], event, ...)
        if not ok then geterrorhandler()(err) end
    end
end)

-- Simple internal message bus (UI refresh etc.)
local listeners = {}
function RM:Listen(msg, fn)
    listeners[msg] = listeners[msg] or {}
    table.insert(listeners[msg], fn)
end
function RM:Fire(msg, ...)
    local list = listeners[msg]
    if not list then return end
    for i = 1, #list do list[i](...) end
end

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------
RM.DB_VERSION = 1

local GLOBAL_DEFAULTS = {
    warnDistance = 1000,      -- yards
    warnLimitedOnly = false,  -- warn only for Limited Supply recipes
    warnProfessions = true,   -- warn for recipes of the focus / own professions
    sound = true,
    hotFactor = 2.0,          -- AH price of the recipe > hotFactor x vendor price
    luxFactor = 4.0,          -- "very lucrative": AH price >= luxFactor x vendor price
    priceSource = "auto",     -- auto | auctionator | auctioneer | tsm | recipescan
    nearOnly = true,
    nearRadius = 300,
    unit = "yd",              -- yd | m
    useMacro = true,
    muted = {},               -- [npcID] = true
    minimap = { hide = false },
    arrow = { point = "CENTER", x = 0, y = 180 },
}

local function applyDefaults(t, defaults)
    for k, v in pairs(defaults) do
        if t[k] == nil then
            if type(v) == "table" then
                t[k] = {}
                applyDefaults(t[k], v)
            else
                t[k] = v
            end
        elseif type(v) == "table" and type(t[k]) == "table" then
            applyDefaults(t[k], v)
        end
    end
end

function RM:InitDB()
    RecipeManagerDB = RecipeManagerDB or {}
    local db = RecipeManagerDB
    db.version = db.version or RM.DB_VERSION
    db.settings = db.settings or {}
    applyDefaults(db.settings, GLOBAL_DEFAULTS)
    db.realms = db.realms or {}
    db.recipeInfo = db.recipeInfo or {}     -- [itemID] = { skill = n, bind = "BoE"|"BoP" }
    db.reagents = db.reagents or {}         -- [productItemID] = { [reagentItemID] = count }

    local realm = GetRealmName() or "?"
    db.realms[realm] = db.realms[realm] or {}
    local r = db.realms[realm]
    r.chars = r.chars or {}
    r.prices = r.prices or {}               -- [itemID] = { {time, copper}, ... } (recipe items only)
    r.observations = r.observations or {}   -- [npcID] = { [itemID] = { ... } }
    r.vendors = r.vendors or {}             -- learned vendors: [npcID] = { name, map, x, y }

    RecipeManagerCharDB = RecipeManagerCharDB or {}
    local c = RecipeManagerCharDB
    c.focus = c.focus                       -- nil = no focus; table [skillLine] = true

    self.db = db
    self.settings = db.settings
    self.realm = r
    self.char = c
    self.realmName = realm
    self.playerName = UnitName("player")
    self.faction = UnitFactionGroup("player")
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
function RM:Print(...)
    print("|cffe3b55bRecipeManager|r:", ...)
end

function RM:Money(copper)
    if not copper then return L["no price"] end
    local neg = copper < 0
    copper = math.floor(math.abs(copper) + 0.5)
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    local parts = {}
    if g > 0 then table.insert(parts, g .. "|cffffd100g|r") end
    if s > 0 then table.insert(parts, s .. "|cffc7c7cfs|r") end
    if c > 0 and g == 0 then table.insert(parts, c .. "|cffeda55fc|r") end
    if #parts == 0 then parts[1] = "0|cffeda55fc|r" end
    return (neg and "-" or "") .. table.concat(parts, " ")
end

function RM:FormatDistance(yards)
    if not yards then return "-" end
    if self.settings.unit == "m" then
        return string.format("%d m", math.floor(yards * 0.9144 + 0.5))
    end
    return string.format("%d yd", math.floor(yards + 0.5))
end

-- radius setting is stored in the chosen unit; convert to yards
function RM:RadiusYards(value)
    if self.settings.unit == "m" then return value / 0.9144 end
    return value
end

-- World distance in yards between a point on a uiMap and the player
function RM:WorldPos(uiMapID, x, y)
    if not (C_Map and C_Map.GetWorldPosFromMapPos and uiMapID) then return end
    local cont, pos = C_Map.GetWorldPosFromMapPos(uiMapID, CreateVector2D(x, y))
    if not pos then return end
    local wx, wy = pos:GetXY()
    return cont, wx, wy
end

function RM:PlayerWorldPos()
    local map = C_Map.GetBestMapForUnit("player")
    if not map then return end
    local p = C_Map.GetPlayerMapPosition(map, "player")
    if not p then return end
    local x, y = p:GetXY()
    local cont, wx, wy = self:WorldPos(map, x, y)
    return cont, wx, wy, map, x, y
end

function RM:Distance(c1, x1, y1, c2, x2, y2)
    if not (c1 and c2) or c1 ~= c2 then return nil end
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

-- Turn a Blizzard format string like "Requires %s (%d)" into a Lua pattern
function RM:FormatToPattern(fmt)
    if not fmt then return nil end
    local p = fmt:gsub("%%%d%$s", "%%s"):gsub("%%%d%$d", "%%d")
    p = p:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    p = p:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
    return "^" .. p .. "$"
end

function RM:InCombat()
    return InCombatLockdown()
end

-- Run fn now, or as soon as combat ends
local afterCombat = {}
function RM:AfterCombat(key, fn)
    if not InCombatLockdown() then fn() return end
    afterCombat[key] = fn
end
RM:On("PLAYER_REGEN_ENABLED", function()
    for k, fn in pairs(afterCombat) do
        afterCombat[k] = nil
        fn()
    end
end)
