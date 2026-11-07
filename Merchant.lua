-- RecipeManager - Merchant: learn vendor stock, Limited Supply "buy now" alarm, highlight in the merchant frame
-- Copyright (C) 2026 psappz - GPL-3.0-or-later
local _, ns = ...
local RM = ns.RM
local L = ns.L

local M = {}
RM.Merchant = M

local alarmed = {} -- [npc..":"..item] = time (one alarm per vendor visit)
M.highlight = {}   -- [merchantIndex] = true

local function npcIdFromGuid(guid)
    if not guid then return nil end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
end

local function itemInfo(i)
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local t = C_MerchantFrame.GetItemInfo(i)
        if t then return t.name, t.price, t.stackCount, t.numAvailable, t.hasExtendedCost end
    end
    if GetMerchantItemInfo then
        local name, _, price, quantity, numAvailable, _, _, extendedCost = GetMerchantItemInfo(i)
        return name, price, quantity, numAvailable, extendedCost
    end
end

function M:Scan()
    local npc = npcIdFromGuid(UnitGUID("npc"))
    if not npc then return end
    local now = time()
    local obs = RM.realm.observations[npc] or {}
    local foundRecipe, favor = false, false
    local alarms = {}
    wipe(self.highlight)
    for i = 1, GetMerchantNumItems() do
        local link = GetMerchantItemLink(i)
        local id, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(link or "")
        if id and classID == 9 then
            local skill = RM.Data.SKILL_BY_SUBCLASS[subClassID]
            local _, price, stack, avail, extended = itemInfo(i)
            if extended then
                favor = true -- bought with a currency (Merchant's Favor): never part of RecipeManager
            elseif skill then
                foundRecipe = true
                local o = obs[id] or {}
                o.skillLine = skill
                o.price = price and stack and stack > 0 and math.floor(price / stack) or price
                o.limited = avail ~= nil and avail >= 0
                o.avail = avail
                o.last = now
                if o.limited then
                    if avail > 0 then o.lastAvail = now else o.lastSoldOut = now end
                end
                obs[id] = o
                if o.limited and avail and avail > 0 then
                    self.highlight[i] = true
                    table.insert(alarms, id)
                end
            end
        end
    end
    if foundRecipe then
        RM.realm.observations[npc] = obs
        if RM.Sales then RM.Sales:ShareStock(npc, obs) end
        local _, _, _, map, x, y = RM:PlayerWorldPos()
        local f = UnitFactionGroup("npc")
        RM.realm.vendors[npc] = {
            name = UnitName("npc"), map = map, x = x, y = y,
            faction = (f == "Horde" and "H") or (f == "Alliance" and "A") or "AH",
        }
    end
    if favor then
        RM.realm.vendors[npc] = RM.realm.vendors[npc] or { name = UnitName("npc") }
        RM.realm.vendors[npc].favor = true
        if RM.Data.vendors[npc] then RM.Data.vendors[npc].favor = true end
    end
    if RM.Data.ready then RM.Data:MergeLearned() end
    self:Alarm(npc, alarms)
    self:UpdateHighlight()
    RM:Fire("OBSERVATIONS_CHANGED", npc)
end

function M:Alarm(npc, ids)
    for _, id in ipairs(ids) do
        local key = npc .. ":" .. id
        local s = RM.Rules:Status(id, npc)
        if s and RM.Rules:ShouldWarn(s) and not alarmed[key] then
            alarmed[key] = time()
            local name = (RM.UI.ItemName(id))
            local text = string.format(L["BUY NOW - Limited Supply: %s"], name)
            RaidNotice_AddMessage(RaidWarningFrame, text, ChatTypeInfo["RAID_WARNING"])
            RM:Print(text)
            if RM.settings.sound then PlaySound(SOUNDKIT.RAID_WARNING, "Master") end
        end
    end
end

local glows = {}
function M:UpdateHighlight()
    if not MerchantFrame or not MerchantFrame:IsShown() then return end
    local per = MERCHANT_ITEMS_PER_PAGE or 10
    local page = MerchantFrame.page or 1
    for i = 1, per do
        local button = _G["MerchantItem" .. i .. "ItemButton"]
        if button then
            local g = glows[i]
            if not g then
                g = button:CreateTexture(nil, "OVERLAY")
                g:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
                g:SetBlendMode("ADD")
                g:SetVertexColor(1, 0.42, 0.24)
                g:SetPoint("CENTER")
                g:SetSize(button:GetWidth() * 1.8, button:GetHeight() * 1.8)
                glows[i] = g
            end
            local index = (page - 1) * per + i
            g:SetShown(MerchantFrame.selectedTab ~= 2 and self.highlight[index] == true)
        end
    end
end

RM:On("MERCHANT_SHOW", function()
    wipe(alarmed)
    C_Timer.After(0.2, function() M:Scan() end)
end)
RM:On("MERCHANT_UPDATE", function() M:Scan() end)
if MerchantFrame_UpdateMerchantInfo then
    hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function() M:UpdateHighlight() end)
end
