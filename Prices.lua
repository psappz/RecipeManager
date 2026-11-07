-- RecipeManager - Prices: AH addon sources, own price history, hot / very lucrative
-- Copyright (C) 2026 psappz - GPL-3.0-or-later
local _, ns = ...
local RM = ns.RM

local P = {}
RM.Prices = P

local AH_CUT = 0.95
local HISTORY_MAX = 10
local HISTORY_DAYS = 14
local CONFIRM_WINDOW = 3 * 86400

-- Sources that share their prices with other addons. Only these lock RecipeScan.
P.sources = {
    auctionator = {
        available = function() return Auctionator and Auctionator.API and Auctionator.API.v1 and Auctionator.API.v1.GetAuctionPriceByItemID end,
        price = function(id) return Auctionator.API.v1.GetAuctionPriceByItemID("RecipeManager", id) end,
    },
    auctioneer = {
        available = function() return AucAdvanced and AucAdvanced.API and AucAdvanced.API.GetMarketValue end,
        price = function(id)
            local link = select(2, C_Item.GetItemInfo(id))
            if not link then return nil end
            return AucAdvanced.API.GetMarketValue(link)
        end,
    },
    tsm = {
        available = function() return TSM_API and TSM_API.GetCustomPriceValue end,
        price = function(id) return TSM_API.GetCustomPriceValue("DBMarket", "i:" .. id) end,
    },
}
P.ORDER = { "auctionator", "auctioneer", "tsm" }

function P:AnyAddon()
    for _, k in ipairs(self.ORDER) do
        if self.sources[k].available() then return k end
    end
end

function P:RecipeScanAllowed()
    return self:AnyAddon() == nil
end

function P:ActiveSource()
    local want = RM.settings.priceSource
    if want ~= "auto" and want ~= "recipescan" and self.sources[want] and self.sources[want].available() then
        return want
    end
    local any = self:AnyAddon()
    if any then return any end
    return "recipescan"
end

-- Raw AH price (gross, per item) from the active source
function P:AHPrice(id)
    if not id then return nil end
    local src = self:ActiveSource()
    if src == "recipescan" then
        local h = RM.realm.prices[id]
        local last = h and h[#h]
        return last and last[2], last and last[1]
    end
    local ok, v = pcall(self.sources[src].price, id)
    if ok and type(v) == "number" and v > 0 then return v end
end

function P:Net(gross)
    return gross and math.floor(gross * AH_CUT)
end

-- Record a price snapshot for a recipe item (own history, all sources)
function P:Record(id, gross, t)
    if not (id and gross and gross > 0) then return end
    t = t or time()
    local h = RM.realm.prices[id]
    if not h then h = {} RM.realm.prices[id] = h end
    local last = h[#h]
    if last and t - last[1] < 3600 then
        last[1], last[2] = t, gross     -- same scan session: overwrite
    else
        table.insert(h, { t, gross })
    end
    local cutoff = time() - HISTORY_DAYS * 86400
    while #h > HISTORY_MAX or (h[1] and h[1][1] < cutoff and #h > 1) do table.remove(h, 1) end
end

function P:SnapshotAll()
    if self:ActiveSource() == "recipescan" then return end
    for id in pairs(RM.Data.recipes) do
        local v = self:AHPrice(id)
        if v then self:Record(id, v) end
    end
    RM:Fire("PRICES_CHANGED")
end

-- Vendor price: observed in game first, then shipped classic data
function P:VendorPrice(id, npc)
    local obs = RM.realm.observations
    if npc and obs[npc] and obs[npc][id] and obs[npc][id].price then return obs[npc][id].price end
    for _, o in pairs(obs) do
        if o[id] and o[id].price then return o[id].price end
    end
    return ns.VendorPrices and ns.VendorPrices[id]
end

local function confirmed(id, threshold)
    local h = RM.realm.prices[id]
    if not h then return false end
    local n, now = 0, time()
    for i = #h, 1, -1 do
        if now - h[i][1] > CONFIRM_WINDOW then break end
        if h[i][2] >= threshold then n = n + 1 end
    end
    return n >= 2
end

-- Evaluation of a recipe item: resale of the recipe only (never the crafted product)
function P:Evaluate(id, npc)
    local r = { vendor = self:VendorPrice(id, npc) }
    local gross = self:AHPrice(id)
    r.ah = self:Net(gross)
    if r.ah and r.vendor then
        r.margin = r.ah - r.vendor
        local hotT = RM.settings.hotFactor * r.vendor
        local luxT = RM.settings.luxFactor * r.vendor
        local enough = r.margin >= (RM.settings.hotMinMargin or 0)
        r.hot = enough and r.ah > hotT and confirmed(id, hotT / AH_CUT)
        r.lux = enough and r.ah >= luxT and confirmed(id, luxT / AH_CUT)
    elseif r.ah and not r.vendor then
        r.margin = r.ah -- quest / drop recipes: full value
    end
    return r
end

-- Crafted product: AH price and crafting profit where reagents are known
function P:Product(id)
    local rec = RM.Data.recipes[id]
    local product = rec and rec.product
    if not product then return nil end
    local gross = self:AHPrice(product)
    local out = { id = product, ah = self:Net(gross) }
    local r = RM.db.reagents[product]
    if out.ah and r then
        local cost = 0
        for reagent, count in pairs(r.reagents) do
            local p = self:AHPrice(reagent) or (ns.VendorPrices and ns.VendorPrices[reagent])
            if not p then cost = nil break end
            cost = cost + p * count
        end
        if cost then out.craft = out.ah * (r.qty or 1) - cost end
    end
    return out
end

-- Auctionator tells us when its database changed
local function hookAuctionator()
    if Auctionator and Auctionator.API and Auctionator.API.v1 and Auctionator.API.v1.RegisterForDBUpdate then
        pcall(Auctionator.API.v1.RegisterForDBUpdate, "RecipeManager", function()
            C_Timer.After(1, function() P:SnapshotAll() end)
        end)
    end
end
RM:Listen("DATA_READY", function()
    hookAuctionator()
    C_Timer.After(5, function() P:SnapshotAll() end)
end)
RM:On("AUCTION_HOUSE_CLOSED", function() C_Timer.After(2, function() P:SnapshotAll() end) end)
