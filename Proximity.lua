-- RecipeManager - Proximity: 5 s check against vendors, raid-warning style alert, minimap dot
-- Copyright (C) 2026 psappz - GPL-3.0-or-later
local _, ns = ...
local RM = ns.RM
local L = ns.L

local PX = {}
RM.Proximity = PX

local INTERVAL = 5          -- design decision: fixed, not configurable
local REALERT = 600         -- same vendor again after 10 minutes
local worldIndex            -- [continent] = { { npc, wx, wy, point }, ... }
local lastAlert = {}

function PX:BuildIndex()
    worldIndex = {}
    for npc, v in pairs(RM.Data.vendors) do
        for _, p in ipairs(v.points) do
            local cont, wx, wy = RM:WorldPos(p[1], p[2], p[3])
            if cont then
                worldIndex[cont] = worldIndex[cont] or {}
                table.insert(worldIndex[cont], { npc, wx, wy, p })
            end
        end
    end
end

-- Recipes worth a warning at this vendor
function PX:Relevant(npc)
    local v = RM.Data.vendors[npc]
    if not v or not RM.Data:VendorAllowed(v) or v.rep then return nil end
    local list, limited = {}, 0
    for _, id in ipairs(v.recipes) do
        local s = RM.Rules:Status(id, npc)
        if s and RM.Rules:ShouldWarn(s) then
            table.insert(list, s)
            if s.limited then limited = limited + 1 end
        end
    end
    if #list == 0 then return nil end
    return list, limited
end

-- Nearest relevant vendor point within maxYards
function PX:Nearest(maxYards)
    if not worldIndex then return end
    local cont, px, py = RM:PlayerWorldPos()
    if not cont or not worldIndex[cont] then return end
    local best, bestD, bestPoint
    for _, e in ipairs(worldIndex[cont]) do
        local dx, dy = e[2] - px, e[3] - py
        local d = math.sqrt(dx * dx + dy * dy)
        if d <= maxYards and (not bestD or d < bestD) and not RM.settings.muted[e[1]] then
            if self:Relevant(e[1]) then best, bestD, bestPoint = e[1], d, e[4] end
        end
    end
    return best, bestD, bestPoint
end

local function suppressed()
    if UnitOnTaxi("player") or InCombatLockdown() then return true end
    local inInstance = IsInInstance()
    return inInstance
end

function PX:Check()
    if not RM.Data.ready then return end
    if not worldIndex then self:BuildIndex() end
    self:UpdateZoneDot()
    if suppressed() then return end
    local npc, d, point = self:Nearest(RM.settings.warnDistance)
    if not npc then return end
    local now = time()
    if lastAlert[npc] and now - lastAlert[npc] < REALERT then return end
    lastAlert[npc] = now
    local list, limited = self:Relevant(npc)
    local v = RM.Data.vendors[npc]
    local text
    if limited > 0 then
        text = string.format(L["Recipe vendor nearby: %s (%s) - %d recipes, %d Limited Supply"], v.name, RM:FormatDistance(d), #list, limited)
    else
        text = string.format(L["Recipe vendor nearby: %s (%s) - %d recipes"], v.name, RM:FormatDistance(d), #list)
    end
    RaidNotice_AddMessage(RaidWarningFrame, text, ChatTypeInfo["RAID_WARNING"])
    if RM.settings.sound and limited > 0 then PlaySound(SOUNDKIT.RAID_WARNING, "Master") end
    local ids = {}
    for _, s in ipairs(list) do table.insert(ids, s.id) end
    if not RM.Arrow:Target() then RM.Arrow:Point(npc, point, ids) end
end

-- Yellow minimap dot: a relevant vendor somewhere in the current zone
function PX:UpdateZoneDot()
    local map = C_Map.GetBestMapForUnit("player")
    local has = false
    local list = map and RM.Data.vendorsByMap[map]
    if list then
        for _, npc in ipairs(list) do
            if not RM.settings.muted[npc] and self:Relevant(npc) then has = true break end
        end
    end
    RM:Fire("ZONE_DOT", has)
end

function PX:Start()
    if self.ticker then return end
    self.ticker = C_Timer.NewTicker(INTERVAL, function() PX:Check() end)
    self:Check()
end

local function soon() C_Timer.After(1, function() PX:Check() end) end
RM:On("ZONE_CHANGED_NEW_AREA", soon)
RM:On("PLAYER_ENTERING_WORLD", soon)
RM:On("PLAYER_CONTROL_GAINED", soon) -- e.g. after a flight
RM:Listen("DATA_READY", function() PX:BuildIndex() PX:Start() end)
RM:Listen("OBSERVATIONS_CHANGED", function() worldIndex = nil end)
