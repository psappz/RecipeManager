-- RecipeManager - RecipeScan: own AH scan of the Recipe category only.
-- Only offered when no AH addon that shares its prices is installed, and only when chosen in the settings.
-- Copyright (C) 2026 psappz - GPL-3.0-or-later
local _, ns = ...
local RM = ns.RM
local L = ns.L

local S = {}
RM.Scan = S

local button, running, seen

function S:Enabled()
    return RM.settings.priceSource == "recipescan" and RM.Prices:RecipeScanAllowed()
        and C_AuctionHouse and C_AuctionHouse.SendBrowseQuery
end

function S:Start()
    if running or not self:Enabled() then return end
    running, seen = true, 0
    button:SetText(L["RecipeScan running..."])
    local recipeClass = (Enum.ItemClass and Enum.ItemClass.Recipe) or 9
    C_AuctionHouse.SendBrowseQuery({
        searchString = "",
        sorts = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } },
        filters = {},
        itemClassFilters = { { classID = recipeClass } },
    })
end

local function collect()
    if not running then return end
    local now = time()
    local results = C_AuctionHouse.GetBrowseResults() or {}
    for _, r in ipairs(results) do
        local id = r.itemKey and r.itemKey.itemID
        if id and r.minPrice and RM.Data.recipes[id] then
            RM.Prices:Record(id, r.minPrice, now)
        end
    end
    seen = #results
    if C_AuctionHouse.HasFullBrowseResults() then
        running = false
        button:SetText("RecipeScan")
        RM:Print(string.format(L["RecipeScan done: %d offers in the Recipe category."], seen))
        RM:Fire("PRICES_CHANGED")
    else
        C_AuctionHouse.RequestMoreBrowseResults()
    end
end

local function ensureButton()
    if button or not AuctionHouseFrame then return end
    button = RM.W:Button(AuctionHouseFrame, "RecipeScan", 110)
    button:SetPoint("TOPRIGHT", AuctionHouseFrame, "TOPRIGHT", -30, -1)
    button:SetScript("OnClick", function() S:Start() end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("RecipeScan")
        GameTooltip:AddLine(L["Scans only recipes and profession books. Prices are shared by all characters on this realm."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

RM:On("AUCTION_HOUSE_SHOW", function()
    ensureButton()
    if button then button:SetShown(S:Enabled() and true or false) end
end)
RM:On("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", collect)
RM:On("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", collect)
RM:On("AUCTION_HOUSE_CLOSED", function() running = false if button then button:SetText("RecipeScan") end end)
