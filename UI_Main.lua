-- RecipeManager - main dialog: tabs Hot and Vendor recipes (settings in UI_Settings.lua)
-- Copyright (C) 2026 psappz - GPL-3.0-or-later
local _, ns = ...
local RM = ns.RM
local L = ns.L
local W = RM.W

local UI = {}
RM.UI = UI

local WIDTH, HEIGHT = 980, 560
local frame, tabs, pages = nil, {}, {}

---------------------------------------------------------------------------
-- shared helpers
---------------------------------------------------------------------------
-- Missing item names: the client answers item requests in batches and drops some under load,
-- so ask again a few times while names are missing. Meanwhile the name comes from QuestieDB.
local retries, retryPending = 0, false
local function retryMissing()
    if retryPending or retries >= 6 then return end
    retryPending = true
    C_Timer.After(3, function()
        retryPending = false
        retries = retries + 1
        UI:RefreshSoon()
    end)
end
RM:On("GET_ITEM_INFO_RECEIVED", function() retries = 0 end)

local function questieName(id)
    if type(ItemDB) ~= "table" or type(ItemDB.name) ~= "function" then return nil end
    local ok, n = pcall(ItemDB.name, id)
    if ok and type(n) == "string" and n ~= "" then return n end
end

local function itemName(id)
    local name = C_Item.GetItemNameByID(id)
    if not name then
        C_Item.RequestLoadItemDataByID(id)
        retryMissing()
        return questieName(id) or ("item " .. id), "|cffffffff"
    end
    local q = C_Item.GetItemQualityByID(id)
    local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    return name, (c and c.hex) or "|cffffffff"
end
UI.ItemName = itemName

local function zoneName(uiMap)
    local info = uiMap and C_Map.GetMapInfo(uiMap)
    return info and info.name or ""
end

local function age(t)
    if not t then return "-" end
    local d = time() - t
    if d < 3600 then return string.format(L["%d min"], math.floor(d / 60)) end
    if d < 86400 then return string.format(L["%d h"], math.floor(d / 3600)) end
    return string.format(L["%d d"], math.floor(d / 86400))
end
UI.Age = age

-- Nearest usable vendor of a recipe: npc, point, distance (yards or nil)
local function bestVendor(rec)
    if not rec.vendors then return nil end
    local cont, px, py = RM:PlayerWorldPos()
    local best, bestP, bestD
    for _, npc in ipairs(rec.vendors) do
        local v = RM.Data.vendors[npc]
        if v and not v.rep and RM.Data:VendorAllowed(v) then
            if not v.world then
                v.world = {}
                for _, p in ipairs(v.points) do
                    local c, wx, wy = RM:WorldPos(p[1], p[2], p[3])
                    if c then table.insert(v.world, { c, wx, wy, p }) end
                end
            end
            for _, w in ipairs(v.world) do
                local d = RM:Distance(cont, px, py, w[1], w[2], w[3])
                if not best or (d and (not bestD or d < bestD)) then best, bestP, bestD = npc, w[4], d end
            end
            if not best then best = npc end
        end
    end
    return best, bestP, bestD
end
UI.BestVendor = bestVendor

local function lastScan(id)
    local h = RM.realm.prices[id]
    return h and h[#h] and h[#h][1]
end

local function profName(skill)
    local name = RM.Data and RM.Data.ProfessionName and RM.Data:ProfessionName(skill)
    return name or L["PROF_" .. skill] or tostring(skill)
end

---------------------------------------------------------------------------
-- Tab: Hot (resale of vendor recipes)
---------------------------------------------------------------------------
local hotFilter = { onlyHot = false, onlyLimited = false, onlyForever = false, profs = nil }

local function buildHotPage(page)
    local y = -8
    local x = 10
    hotFilter.profs = {}
    for _, skill in ipairs(RM.Data.PROFESSION_ORDER) do hotFilter.profs[skill] = true end
    page.profButtons = {}
    for _, skill in ipairs(RM.Data.PROFESSION_ORDER) do
        local b = W:Toggle(page, profName(skill), 96, function() return hotFilter.profs[skill] end,
            function(v) hotFilter.profs[skill] = v UI:Refresh() end)
        local last = page.profButtons[#page.profButtons]
        if last then b:SetPoint("LEFT", last, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", page, "TOPLEFT", x, y) end
        table.insert(page.profButtons, b)
    end
    y = y - 28
    local c1 = W:Check(page, L["only hot"], function() return hotFilter.onlyHot end, function(v) hotFilter.onlyHot = v UI:Refresh() end)
    c1:SetPoint("TOPLEFT", page, "TOPLEFT", 8, y)
    local c2 = W:Check(page, L["only Limited Supply"], function() return hotFilter.onlyLimited end, function(v) hotFilter.onlyLimited = v UI:Refresh() end)
    c2:SetPoint("LEFT", c1, "RIGHT", 90, 0)
    local c3 = W:Check(page, L["only learned in Forever"], function() return hotFilter.onlyForever end, function(v) hotFilter.onlyForever = v UI:Refresh() end)
    c3:SetPoint("LEFT", c2, "RIGHT", 150, 0)
    page.hint = W:Text(page, "GameFontDisableSmall")
    page.hint:SetPoint("TOPRIGHT", page, "TOPRIGHT", -10, y - 6)

    W.sortHint = L["Click: sort ascending - click again: descending"]
    page.table = W:Table(page, {
        { "name", L["Recipe"], 220, nil, L["TIP_RECIPE_HOT"] }, { "prof", L["Profession"], 92, nil, L["TIP_PROF"] },
        { "skill", L["Skill"], 38, "RIGHT", L["TIP_SKILL"] },
        { "vendor", L["Vendor / Zone"], 150, nil, L["TIP_VENDOR"] }, { "ek", L["Vendor price"], 58, "RIGHT", L["TIP_EK"] },
        { "ah", L["AH recipe"], 70, "RIGHT", L["TIP_AH"] }, { "margin", L["Margin"], 70, "RIGHT", L["TIP_MARGIN"] },
        { "sold", L["Sold for"], 70, "RIGHT", L["TIP_SOLD"] }, { "evidence", L["Evidence"], 82, nil, L["TIP_EVIDENCE"] },
        { "status", L["Status"], 100, nil, L["TIP_STATUS"] },
    }, 22, 17, function(item) UI:SelectRecipe(item.itemID, item.npc, item.point) end)
    page.table:SetPoint("TOPLEFT", page, "TOPLEFT", 4, y - 30)
    page.table:SetPoint("RIGHT", page, "RIGHT", -4, 0)
end

local function hotRows()
    local rows = {}
    for id, rec in pairs(RM.Data.recipes) do
        if rec.vendors and #rec.vendors > 0 and not rec.rep and hotFilter.profs[rec.skillLine] then
            local npc, point, dist = bestVendor(rec)
            if npc then
                local s = RM.Rules:Status(id, npc)
                if s and (not hotFilter.onlyHot or s.hot) and (not hotFilter.onlyLimited or s.limited)
                    and (not hotFilter.onlyForever or rec.learned) then
                    local name, color = itemName(id)
                    local v = RM.Data.vendors[npc]
                    local ev = RM.Sales:Evidence(id, s.vendorPrice, s.limited)
                    local tags = s.limited and ("|cffff6a3d[" .. L["LIMITED"] .. "]|r ") or ""
                    if s.hot then tags = tags .. "|cffffb100[" .. L["HOT"] .. "]|r " end
                    table.insert(rows, {
                        itemID = id, npc = npc, point = point,
                        name = tags .. color .. name .. "|r",
                        prof = profName(rec.skillLine),
                        skill = s.req or "?",
                        vendor = v.name .. " |cff9a9488" .. zoneName(point and point[1]) .. "|r",
                        ek = s.vendorPrice and RM:Money(s.vendorPrice) or "-",
                        ah = s.ahPrice and RM:Money(s.ahPrice) or ("|cff8a8270" .. L["no price"] .. "|r"),
                        margin = s.margin and ((s.hot and "|cffffd100" or "") .. RM:Money(s.margin) .. "|r") or "-",
                        sold = ev and ev.realized and RM:Money(ev.realized) or "|cff8a8270-|r",
                        evidence = RM.Sales:EvidenceText(ev) .. ((ev and ev.buy and ev.buy > 0) and (" |cffffd100x" .. ev.buy .. "|r") or ""),
                        status = s.color .. s.text .. "|r",
                        -- with sales evidence: expected profit per listing; without: listed margin, ranked below
                        sortMargin = (ev and ev.profit) and (1e9 + ev.profit) or (s.margin or -1e12),
                        -- evidence column: success rate, more auctions first on equal rate
                        sortValues = { evidence = ev and ev.rate and (ev.rate + math.min(ev.s + ev.f, 999) / 1e6) or false },
                        luxColumn = s.lux and 1 or nil,
                        bg = s.limited and { 0.16, 0.08, 0.03 } or (s.hot and { 0.13, 0.1, 0.05 }) or nil,
                        border = s.limited and { 1, 0.42, 0.24 } or nil,
                    })
                end
            end
        end
    end
    table.sort(rows, function(a, b) return a.sortMargin > b.sortMargin end)
    return rows
end

-- Tab: Recipes -> UI_Recipes.lua
UI.ZoneName = zoneName
UI.ProfName = profName

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local function create()
    frame = W:Panel(UIParent, 0.09, 0.075, 0.05, 0.97)
    frame:SetBackdropBorderColor(0.54, 0.48, 0.33, 1)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    tinsert(UISpecialFrames, "RecipeManagerFrame")
    _G.RecipeManagerFrame = frame

    local title = W:Text(frame, "GameFontNormalLarge", "RecipeManager")
    title:SetPoint("TOPLEFT", 14, -12)
    frame.sub = W:Text(frame, "GameFontDisableSmall")
    frame.sub:SetPoint("LEFT", title, "RIGHT", 12, -1)
    W:Close(frame)

    local defs = { { "hot", L["Hot"], buildHotPage }, { "recipes", L["Recipes"], function(page) UI:BuildRecipePage(page) end },
        { "settings", L["Focus / Settings"], RM.Settings.Build } }
    local prevTab
    for _, def in ipairs(defs) do
        local key = def[1]
        local b = W:Toggle(frame, def[2], 150, function() return UI.tab == key end, function() UI:ShowTab(key) end)
        if prevTab then b:SetPoint("LEFT", prevTab, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -38) end
        prevTab = b
        tabs[key] = b
        local page = CreateFrame("Frame", nil, frame)
        page:SetPoint("TOPLEFT", 6, -66)
        page:SetPoint("BOTTOMRIGHT", -6, 26)
        page:Hide()
        def[3](page)
        pages[key] = page
    end
    frame.footer = W:Text(frame, "GameFontDisableSmall")
    frame.footer:SetPoint("BOTTOMLEFT", 14, 8)
    frame.version = W:Text(frame, "GameFontDisableSmall", "v" .. RM.version)
    frame.version:SetPoint("BOTTOMRIGHT", -14, 8)
    frame:SetScript("OnShow", function() UI:Refresh() end)
end

function UI:ShowTab(key)
    self.tab = key
    for k, p in pairs(pages) do p:SetShown(k == key) end
    for _, b in pairs(tabs) do b:Refresh() end
    self:Refresh()
end

function UI:Toggle(tab)
    if not frame then
        local ok, err = pcall(create)
        if not ok then
            -- a half-built window would fail on every later call: drop it and report once
            if frame then frame:Hide() end
            frame, tabs, pages = nil, {}, {}
            geterrorhandler()(err)
            return
        end
    end
    if frame:IsShown() and (not tab or tab == self.tab) then frame:Hide() return end
    frame:Show()
    self:ShowTab(tab or self.tab or "hot")
end

local pending
function UI:Refresh()
    if not frame or not frame:IsShown() then return end
    if not frame.footer then return end
    if not RM.Data.ready then
        frame.footer:SetText(L["Loading recipe data from QuestieDB..."])
        return
    end
    local src = RM.Prices:ActiveSource()
    frame.sub:SetText(string.format(L["Prices: %s"], src))
    frame.footer:SetText("/rm  -  " .. L["Minimap: click = arrow, shift-click = dialog"])
    if self.tab == "hot" then
        local p = pages.hot
        for _, b in ipairs(p.profButtons or {}) do b:Refresh() end
        p.hint:SetText(string.format(L["hot = AH price > %.1fx vendor price - gold coin = at least %.1fx"], RM.settings.hotFactor, RM.settings.luxFactor))
        p.table:SetData(hotRows())
    elseif self.tab == "recipes" then
        UI:RefreshRecipes(pages.recipes)
    elseif self.tab == "settings" then
        RM.Settings:Refresh(pages.settings)
    end
end

-- Coalesce refreshes (item data arrives in bursts)
function UI:RefreshSoon()
    if pending then return end
    pending = true
    C_Timer.After(0.5, function() pending = false UI:Refresh() end)
end

function UI:SelectRecipe(itemID, npc, point)
    UI.selected = { itemID = itemID, npc = npc, point = point }
    self:ShowTab("recipes")
end

RM:On("GET_ITEM_INFO_RECEIVED", function() UI:RefreshSoon() end)
RM:Listen("PRICES_CHANGED", function() UI:RefreshSoon() end)
RM:Listen("DATA_READY", function() UI:RefreshSoon() end)
RM:Listen("OBSERVATIONS_CHANGED", function() UI:RefreshSoon() end)
RM:Listen("PROFESSIONS_CHANGED", function() UI:RefreshSoon() end)
