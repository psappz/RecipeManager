-- Manager family: shows which of psappz' Manager addons are installed (same file in every member)
-- Copyright (C) 2026 psappz - GPL-3.0-or-later
local _, ns = ...

local F = {}
ns.Family = F
F.MEMBERS = { "ConfigManager", "LegacyManager", "RecipeManager", "DungeonManager" }
F.URL = "curseforge.com/members/psappz/projects"

local READY = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t"
local MISSING = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:12:12|t"

local function state(name)
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name)) or (IsAddOnLoaded and IsAddOnLoaded(name))
    if loaded then return "loaded" end
    local get = C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo
    if get then
        local ok, n, _, _, _, reason = pcall(get, name)
        if ok and n and reason ~= "MISSING" then return "installed" end
    end
    return "missing"
end

-- One line, e.g. "Manager family: [ok] ConfigManager  [ok] LegacyManager  [x] RecipeManager ..."
function F.Line(title)
    local parts = {}
    for _, name in ipairs(F.MEMBERS) do
        local s = state(name)
        if s == "loaded" then table.insert(parts, READY .. " |cffffffff" .. name .. "|r")
        elseif s == "installed" then table.insert(parts, READY .. " |cff9a9a9a" .. name .. "|r")
        else table.insert(parts, MISSING .. " |cff9a9a9a" .. name .. "|r") end
    end
    return (title or "Manager family") .. ":  " .. table.concat(parts, "   ")
end

function F.Missing()
    local out = {}
    for _, name in ipairs(F.MEMBERS) do if state(name) == "missing" then table.insert(out, name) end end
    return out
end
