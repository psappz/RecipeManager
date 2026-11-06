-- RecipeManager - integrations with popular addons. Everything is optional and guarded:
--   Item tooltip    who can learn the recipe, nearest vendor, Limited Supply (prices stay with the AH addon)
--   Auctionator     shopping list with the reagents of a recipe's product
--   Syndicator      "already owned" by one of your characters (bags, bank, mail)
--   TomTom          arrow instead of the own arrow (option)
--   Guild chat      post a recipe with vendor and margin
-- Copyright (C) 2026 psappz - GPL-3.0-or-later
local _, ns = ...
local RM = ns.RM
local L = ns.L

local I = {}
RM.Int = I

---------------------------------------------------------------------------
-- Syndicator: owned by one of my characters?
---------------------------------------------------------------------------
function I:HasSyndicator()
    return type(Syndicator) == "table" and type(Syndicator.API) == "table" and type(Syndicator.API.GetInventoryInfoByItemID) == "function"
end

-- { { name, count }, ... } or nil
function I:Owned(itemID)
    if not self:HasSyndicator() then return nil end
    if Syndicator.API.IsReady and not Syndicator.API.IsReady() then return nil end
    local ok, info = pcall(Syndicator.API.GetInventoryInfoByItemID, itemID, true, true)
    if not ok or type(info) ~= "table" or type(info.characters) ~= "table" then return nil end
    local out = {}
    for _, c in ipairs(info.characters) do
        local n = (c.bags or 0) + (c.bank or 0) + (c.mail or 0)
        if n > 0 then table.insert(out, { c.character, n }) end
    end
    return #out > 0 and out or nil
end

function I:OwnedText(itemID)
    local owned = self:Owned(itemID)
    if not owned then return nil end
    local parts = {}
    for _, o in ipairs(owned) do table.insert(parts, o[1] .. (o[2] > 1 and (" x" .. o[2]) or "")) end
    return string.format(L["already owned: %s"], table.concat(parts, ", "))
end

---------------------------------------------------------------------------
-- TomTom
---------------------------------------------------------------------------
function I:HasTomTom()
    return type(TomTom) == "table" and type(TomTom.AddWaypoint) == "function"
end

local lastWaypoint
function I:TomTomWaypoint(point, label)
    if not (self:HasTomTom() and point) then return false end
    if lastWaypoint and TomTom.RemoveWaypoint then pcall(TomTom.RemoveWaypoint, TomTom, lastWaypoint) end
    local ok, uid = pcall(TomTom.AddWaypoint, TomTom, point[1], point[2], point[3], { title = label, from = "RecipeManager", persistent = false })
    if ok then lastWaypoint = uid end
    return ok
end

---------------------------------------------------------------------------
-- Auctionator shopping list for the reagents of a recipe's product
---------------------------------------------------------------------------
function I:HasAuctionatorLists()
    return type(Auctionator) == "table" and Auctionator.API and Auctionator.API.v1
        and type(Auctionator.API.v1.CreateShoppingList) == "function"
        and type(Auctionator.API.v1.ConvertToSearchString) == "function"
end

-- Reagents are known once the profession window was open on a character with the recipe.
function I:Reagents(recipeItemID)
    local rec = RM.Data.recipes[recipeItemID]
    local product = rec and rec.product
    local r = product and RM.db.reagents[product]
    return r and r.reagents, product
end

function I:CreateShoppingList(recipeItemID)
    if not self:HasAuctionatorLists() then return false end
    local reagents, product = self:Reagents(recipeItemID)
    if not reagents then RM:Print(L["Reagents unknown - open the profession window once."]) return false end
    local terms = {}
    for reagent, count in pairs(reagents) do
        local name = C_Item.GetItemNameByID(reagent)
        if not name then C_Item.RequestLoadItemDataByID(reagent) RM:Print(L["Item data is loading - please try again."]) return false end
        local ok, s = pcall(Auctionator.API.v1.ConvertToSearchString, "RecipeManager", { searchString = name, isExact = true, quantity = count })
        if ok and s then table.insert(terms, s) end
    end
    if #terms == 0 then return false end
    local pname = C_Item.GetItemNameByID(product) or tostring(product)
    local listName = "RecipeManager: " .. pname
    local ok = pcall(Auctionator.API.v1.CreateShoppingList, "RecipeManager", listName, terms)
    if ok then RM:Print(string.format(L["Auctionator shopping list created: %s"], listName)) end
    return ok
end

---------------------------------------------------------------------------
-- Guild chat
---------------------------------------------------------------------------
local function plainMoney(c)
    c = math.floor(c or 0)
    local g, sv, cu = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    local out = {}
    if g > 0 then table.insert(out, g .. "g") end
    if sv > 0 then table.insert(out, sv .. "s") end
    if cu > 0 or #out == 0 then table.insert(out, cu .. "c") end
    return table.concat(out, " ")
end

local lastPost = 0
function I:PostToGuild(itemID, npc, point)
    if not IsInGuild() then RM:Print(L["You are not in a guild."]) return end
    if GetTime() - lastPost < 30 then RM:Print(L["Please wait a moment before posting again."]) return end
    local _, link = C_Item.GetItemInfo(itemID)
    if not link then C_Item.RequestLoadItemDataByID(itemID) RM:Print(L["Item data is loading - please try again."]) return end
    lastPost = GetTime()
    local s = RM.Rules:Status(itemID, npc)
    local parts = { "[RecipeManager] " .. link }
    if npc and RM.Data.vendors[npc] then
        local zone = point and C_Map.GetMapInfo(point[1])
        table.insert(parts, RM.Data.vendors[npc].name .. (zone and (" (" .. zone.name .. ")") or ""))
    end
    if s and s.vendorPrice then table.insert(parts, L["Vendor"] .. " " .. plainMoney(s.vendorPrice)) end
    if s and s.ahPrice then table.insert(parts, L["AH"] .. " " .. plainMoney(s.ahPrice)) end
    if s and s.limited then table.insert(parts, L["Limited Supply"]) end
    local text = table.concat(parts, " - ")
    pcall(SendChatMessage, text, "GUILD")
end

---------------------------------------------------------------------------
-- Item tooltip
---------------------------------------------------------------------------
local function addTooltip(tooltip, itemID)
    if not (RM.settings and RM.settings.tooltip and RM.Data and RM.Data.recipes) then return end
    local rec = RM.Data.recipes[itemID]
    if not rec then return end
    local npc, point = RM.UI.BestVendor and RM.UI.BestVendor(rec)
    local s = RM.Rules:Status(itemID, npc)
    if not s then return end
    tooltip:AddLine(" ")
    tooltip:AddDoubleLine("|cffe3b55bRecipeManager|r", s.color .. s.text .. "|r")
    if npc and RM.Data.vendors[npc] then
        local zone = point and C_Map.GetMapInfo(point[1])
        local left = RM.Data.vendors[npc].name .. (zone and (" - " .. zone.name) or "")
        if s.limited then left = "|cffff6a3d" .. L["LIMITED"] .. "|r " .. left end
        tooltip:AddDoubleLine(left, s.vendorPrice and RM:Money(s.vendorPrice) or "", 0.85, 0.82, 0.74, 1, 1, 1)
    end
    if s.margin and s.bind ~= "BoP" then
        tooltip:AddDoubleLine(L["Margin"], (s.hot and "|cffffd100" or "") .. RM:Money(s.margin) .. "|r", 0.85, 0.82, 0.74, 1, 1, 1)
    end
    local ev = RM.Sales and RM.Sales:Evidence(itemID, s.vendorPrice, s.limited)
    if ev then
        tooltip:AddDoubleLine(L["Evidence"], RM.Sales:EvidenceText(ev) .. (ev.realized and ("  " .. RM:Money(ev.realized)) or ""), 0.85, 0.82, 0.74, 1, 1, 1)
    end
    local owned = I:OwnedText(itemID)
    if owned then tooltip:AddLine(owned, 0.56, 0.89, 0.62) end
    tooltip:Show()
end

local hooked = false
function I:HookTooltip()
    if hooked then return end
    hooked = true
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
            if data and data.id then pcall(addTooltip, tooltip, data.id) end
        end)
    elseif GameTooltip.HookScript then
        GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
            local _, link = tooltip:GetItem()
            local id = link and tonumber(link:match("item:(%d+)"))
            if id then pcall(addTooltip, tooltip, id) end
        end)
    end
end

RM:Listen("DATA_READY", function() I:HookTooltip() end)
