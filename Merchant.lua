-- RecipeManager - Merchant: learn vendor stock, Limited Supply "buy now" alarm, highlight in the merchant frame
-- Copyright (C) 2026 psappz - GPL-3.0-or-later
local _, ns = ...
local RM = ns.RM
local L = ns.L

local M = {}
RM.Merchant = M

local alarmed = {} -- [npc..":"..item] = time (one alarm per vendor visit)
local autoBought = {} -- [item] = count bought automatically during this vendor visit
local autoPending     -- GetTime() of the last automatic purchase, until the merchant list updates
local rawBuy = BuyMerchantItem -- the game's own purchase, before the BoP guard below
M.highlight = {}   -- [merchantIndex] = "stock" (Limited Supply in stock), "out" (sold out) or "bop"
M.bop = {}         -- [merchantIndex] = { id, skill }: bind-on-pickup recipe of a profession this character lacks

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
    wipe(self.bop)
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
                -- bind on pickup and this character does not have the profession: useless to buy here
                local info = RM.Data:RecipeInfo(id)
                if info and info.bind == "BoP" and not RM.Prof:Skill(skill) then
                    self.bop[i] = { id = id, skill = skill }
                end
                if self.bop[i] then
                    self.highlight[i] = "bop"
                elseif o.limited and avail and avail > 0 then
                    self.highlight[i] = "stock"
                    table.insert(alarms, id)
                elseif o.limited then
                    self.highlight[i] = "out"
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
    self:AutoBuy()
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
            if s.hot and s.margin then
                text = text .. "  -  " .. string.format(L["HOT, expected margin %s"], RM:Money(s.margin))
            end
            RaidNotice_AddMessage(RaidWarningFrame, text, ChatTypeInfo["RAID_WARNING"])
            RM:Print(text)
            if RM.settings.sound then PlaySound(SOUNDKIT.RAID_WARNING, "Master") end
        end
    end
end

-- Limited Supply recipes in the merchant window: tinted row with a border (orange = in stock,
-- grey = sold out) and a glow on the icon while in stock
-- Automatic purchase: watched Limited Supply recipes in stock, up to the price and quantity set in
-- the settings. One item at a time; the next one after the merchant list has updated.
function M:AutoBuy()
    local set = RM.settings
    if not (set and set.autoBuy) or not rawBuy then return end
    if autoPending and GetTime() - autoPending < 0.5 then return end
    autoPending = nil
    local watch = RM.db and RM.db.watch or {}
    local maxPrice = (tonumber(set.autoBuyMax) or 0) * 10000
    local maxQty = tonumber(set.autoBuyQty) or 1
    for i = 1, GetMerchantNumItems() do
        if self.highlight[i] == "stock" and not self.bop[i] then
            local id = C_Item.GetItemInfoInstant(GetMerchantItemLink(i) or "")
            local _, price, _, avail, extended = itemInfo(i)
            -- a bind-on-pickup recipe is learned once: at most one, and none if already known or in the bags
            local limit = maxQty
            local info = id and RM.Data:RecipeInfo(id)
            if info and info.bind == "BoP" then
                local known = RM.Prof.Knows and RM.Prof:Knows(id)
                limit = (known or (GetItemCount and GetItemCount(id, true) or 0) > 0) and 0 or 1
            end
            if id and watch[id] and not extended and price and price <= maxPrice and (avail or 0) > 0
                and (autoBought[id] or 0) < limit and GetMoney() >= price then
                autoBought[id] = (autoBought[id] or 0) + 1
                autoPending = GetTime()
                rawBuy(i, 1)
                RM:Print(string.format(L["Bought automatically: %s for %s (%d/%d)"],
                    (RM.UI.ItemName(id)), RM:Money(price), autoBought[id], limit))
                return
            end
        end
    end
end

local marks = {}
local COLORS = { stock = { 1, 0.42, 0.24 }, out = { 0.55, 0.55, 0.55 }, bop = { 1, 0.12, 0.12 } }

local function mark(i, button)
    local m = marks[i]
    if m then return m end
    local row = _G["MerchantItem" .. i] or button:GetParent() or button
    m = CreateFrame("Frame", nil, row, BackdropTemplateMixin and "BackdropTemplate" or nil)
    m:SetPoint("TOPLEFT", row, "TOPLEFT", -3, 3)
    m:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 3, -3)
    m:SetFrameLevel(row:GetFrameLevel() + 5)
    m:EnableMouse(false)
    if m.SetBackdrop then
        m:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
    end
    m.tint = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    m.tint:SetAllPoints(row)
    m.tint:SetColorTexture(1, 1, 1, 1)
    m.glow = button:CreateTexture(nil, "OVERLAY")
    m.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    m.glow:SetBlendMode("ADD")
    m.glow:SetVertexColor(1, 0.42, 0.24)
    m.glow:SetPoint("CENTER")
    m.glow:SetSize(button:GetWidth() * 1.8, button:GetHeight() * 1.8)
    marks[i] = m
    return m
end

function M:UpdateHighlight()
    if not MerchantFrame or not MerchantFrame:IsShown() then return end
    local per = MERCHANT_ITEMS_PER_PAGE or 10
    local page = MerchantFrame.page or 1
    for i = 1, per do
        local button = _G["MerchantItem" .. i .. "ItemButton"]
        if button then
            local index = (page - 1) * per + i
            local state = MerchantFrame.selectedTab ~= 2 and self.highlight[index] or nil
            local m = (state or marks[i]) and mark(i, button)
            if m then
                if state then
                    local c = COLORS[state]
                    if m.SetBackdropBorderColor then m:SetBackdropBorderColor(c[1], c[2], c[3], state == "stock" and 1 or 0.7) end
                    m.tint:SetVertexColor(c[1], c[2], c[3], (state == "out" and 0.1) or 0.22)
                    m:Show() m.tint:Show()
                    m.glow:SetShown(state == "stock")
                else
                    m:Hide() m.tint:Hide() m.glow:Hide()
                end
            end
        end
    end
end

RM:On("MERCHANT_SHOW", function()
    wipe(alarmed)
    wipe(autoBought)
    autoPending = nil
    C_Timer.After(0.2, function() M:Scan() end)
end)
RM:On("MERCHANT_UPDATE", function() M:Scan() end)
if MerchantFrame_UpdateMerchantInfo then
    hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function() M:UpdateHighlight() end)
end

-- Ask before buying a bind-on-pickup recipe of a profession this character does not have
StaticPopupDialogs["RECIPEMANAGER_BUY_BOP"] = {
    text = "%s",
    button1 = YES, button2 = NO,
    OnAccept = function(_, data) if data and data.buy then data.buy() end end,
    timeout = 0, whileDead = false, hideOnEscape = true, showAlert = true, preferredIndex = 3,
}

local function guard(original)
    return function(index, quantity, ...)
        local b = M.bop[index]
        if b and MerchantFrame and MerchantFrame:IsShown() and MerchantFrame.selectedTab ~= 2 then
            local name = (RM.UI.ItemName(b.id))
            local prof = (RM.UI.ProfName and RM.UI.ProfName(b.skill)) or "?"
            local text = string.format(L["CONFIRM_BOP"], name, RM.playerName or "?", prof)
            local args = { ... }
            StaticPopup_Show("RECIPEMANAGER_BUY_BOP", text, nil, { buy = function() original(index, quantity, unpack(args)) end })
            return
        end
        return original(index, quantity, ...)
    end
end
if type(BuyMerchantItem) == "function" then BuyMerchantItem = guard(BuyMerchantItem) end
