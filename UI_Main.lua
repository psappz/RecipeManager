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
local function itemName(id)
    local name = C_Item.GetItemNameByID(id)
    if not name then C_Item.RequestLoadItemDataByID(id) return "item " .. id, "|cffffffff" end
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

    page.table = W:Table(page, {
        { "name", L["Recipe"], 220 }, { "prof", L["Profession"], 92 }, { "skill", L["Skill"], 38, "RIGHT" },
        { "vendor", L["Vendor / Zone"], 150 }, { "ek", L["Vendor price"], 58, "RIGHT" },
        { "ah", L["AH recipe"], 70, "RIGHT" }, { "margin", L["Margin"], 70, "RIGHT" },
        { "sold", L["Sold for"], 70, "RIGHT" }, { "evidence", L["Evidence"], 82 }, { "status", L["Status"], 100 },
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

---------------------------------------------------------------------------
-- Tab: Vendor recipes (look-up)
---------------------------------------------------------------------------
local recFilter = { prof = "all", rank = "all" }
local selected -- { itemID, npc, point }

local function buildRecipePage(page)
    local function profOptions()
        local o = { { "all", L["All professions"] } }
        for _, skill in ipairs(RM.Data.PROFESSION_ORDER) do table.insert(o, { skill, profName(skill) }) end
        return o
    end
    local prof = W:Cycle(page, 150, profOptions, function() return recFilter.prof end, function(v) recFilter.prof = v UI:Refresh() end)
    prof:SetPoint("TOPLEFT", page, "TOPLEFT", 10, -8)
    local x = 170
    for _, r in ipairs({ { "all", L["All"] }, { "Apprentice", "Apprentice 1-75" }, { "Journeyman", "Journeyman 75-150" },
        { "Expert", "Expert 150-225" }, { "Artisan", "Artisan 225-300" } }) do
        local b = W:Toggle(page, r[2], r[1] == "all" and 50 or 120, function() return recFilter.rank == r[1] end,
            function() recFilter.rank = r[1] UI:Refresh() end)
        page.rankButtons = page.rankButtons or {}
        local last = page.rankButtons[#page.rankButtons]
        if last then b:SetPoint("LEFT", last, "RIGHT", 4, 0) else b:SetPoint("LEFT", prof, "RIGHT", 10, 0) end
        table.insert(page.rankButtons, b)
    end
    local near = W:Check(page, L["only vendors within"], function() return RM.settings.nearOnly end,
        function(v) RM.settings.nearOnly = v UI:Refresh() end)
    near:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -36)
    local radius = W:Number(page, 50, function() return RM.settings.nearRadius end,
        function(v) RM.settings.nearRadius = math.max(10, math.floor(v)) UI:Refresh() end)
    radius:SetPoint("LEFT", near.text, "RIGHT", 8, 0)
    local unit = W:Cycle(page, 70, function() return { { "yd", L["yards"] }, { "m", L["meters"] } } end,
        function() return RM.settings.unit end, function(v)
            RM.settings.unit = v
            RM.settings.unitChosen = true
            UI:Refresh()
        end)
    unit:SetPoint("LEFT", radius, "RIGHT", 6, 0)
    page.count = W:Text(page, "GameFontDisableSmall")
    page.count:SetPoint("TOPRIGHT", page, "TOPRIGHT", -10, -42)
    page.near, page.radius, page.unit, page.prof = near, radius, unit, prof

    page.table = W:Table(page, {
        { "name", L["Recipe"], 245 }, { "skill", L["Skill"], 40, "RIGHT" }, { "source", L["Source / Vendor"], 170 },
        { "dist", L["Distance"], 65, "RIGHT" }, { "ek", L["Vendor price"], 65, "RIGHT" },
        { "ah", L["AH recipe"], 75, "RIGHT" }, { "margin", L["Margin"], 75, "RIGHT" },
        { "product", L["AH product"], 75, "RIGHT" }, { "craft", L["Craft profit"], 75, "RIGHT" },
    }, 22, 12, function(item)
        selected = { itemID = item.itemID, npc = item.npc, point = item.point }
        UI:Refresh()
    end)
    page.table:SetPoint("TOPLEFT", page, "TOPLEFT", 4, -64)
    page.table:SetPoint("RIGHT", page, "RIGHT", -4, 0)

    local d = W:Panel(page)
    d:SetPoint("TOPLEFT", page.table, "BOTTOMLEFT", 2, -4)
    d:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -6, 6)
    d.title = W:Text(d, "GameFontNormal")
    d.title:SetPoint("TOPLEFT", 10, -8)
    d.left = W:Text(d, "GameFontHighlightSmall")
    d.left:SetPoint("TOPLEFT", 10, -28)
    d.left:SetWidth(440)
    d.left:SetJustifyH("LEFT")
    d.right = W:Text(d, "GameFontHighlightSmall")
    d.right:SetPoint("TOPLEFT", 470, -28)
    d.right:SetWidth(330)
    d.right:SetJustifyH("LEFT")
    d.arrow = W:Button(d, L["Show arrow"], 120, function()
        if selected and selected.npc and selected.point then RM.Arrow:Point(selected.npc, selected.point, { selected.itemID }) end
    end)
    d.arrow:SetPoint("TOPRIGHT", d, "TOPRIGHT", -10, -8)
    d.mute = W:Button(d, L["Mute vendor"], 120, function()
        if selected and selected.npc then RM.settings.muted[selected.npc] = true RM:Print(L["Vendor muted."]) end
    end)
    d.mute:SetPoint("TOPRIGHT", d.arrow, "BOTTOMRIGHT", 0, -4)
    d.guild = W:Button(d, L["Post to guild"], 120, function()
        if selected then RM.Int:PostToGuild(selected.itemID, selected.npc, selected.point) end
    end)
    d.guild:SetPoint("TOPRIGHT", d.mute, "BOTTOMRIGHT", 0, -4)
    d.shop = W:Button(d, L["Auctionator list"], 120, function()
        if selected then RM.Int:CreateShoppingList(selected.itemID) end
    end)
    d.shop:SetPoint("RIGHT", d.arrow, "LEFT", -6, 0)
    page.detail = d
end

local function recipeRows()
    local rows = {}
    local radiusYards = RM:RadiusYards(RM.settings.nearRadius)
    for id, rec in pairs(RM.Data.recipes) do
        if (recFilter.prof == "all" or rec.skillLine == recFilter.prof) and not rec.rep then
            local info = RM.Data:RecipeInfo(id) or {}
            if recFilter.rank == "all" or RM.Data:Rank(info.skill) == recFilter.rank then
                local npc, point, dist = bestVendor(rec)
                local source
                if npc then
                    source = RM.Data.vendors[npc].name .. " |cff9a9488" .. zoneName(point and point[1]) .. "|r"
                elseif rec.quests then
                    source = "|cffb0b0b0" .. L["Quest"] .. "|r"
                elseif rec.drops then
                    source = "|cffb0b0b0" .. L["Drop"] .. "|r"
                end
                local include = source ~= nil
                if RM.settings.nearOnly then include = npc ~= nil and dist ~= nil and dist <= radiusYards end
                if include then
                    local s = RM.Rules:Status(id, npc)
                    local name, color = itemName(id)
                    local product = RM.Prices:Product(id)
                    local tradable = s.bind ~= "BoP"
                    local tag = s.limited and ("|cffff6a3d[" .. L["LIMITED SUPPLY"] .. "]|r ") or ""
                    local isSel = selected and selected.itemID == id
                    table.insert(rows, {
                        itemID = id, npc = npc, point = point,
                        name = tag .. color .. name .. "|r",
                        skill = s.req or "?",
                        source = source,
                        dist = RM:FormatDistance(dist),
                        ek = s.vendorPrice and RM:Money(s.vendorPrice) or "-",
                        ah = (not tradable and ("|cff8a8270" .. L["not tradable"] .. "|r")) or (s.ahPrice and RM:Money(s.ahPrice)) or ("|cff8a8270" .. L["no price"] .. "|r"),
                        margin = (tradable and s.margin) and ((s.hot and "|cffffd100" or "") .. RM:Money(s.margin) .. "|r") or "-",
                        product = product and product.ah and RM:Money(product.ah) or "-",
                        craft = (product and product.craft and RM.Prof:Skill(rec.skillLine)) and RM:Money(product.craft) or "-",
                        sortDist = dist or 1e9,
                        luxColumn = (tradable and s.lux) and 1 or nil,
                        selected = isSel,
                        bg = isSel and { 0.16, 0.13, 0.08 } or (s.limited and { 0.16, 0.08, 0.03 }) or nil,
                        border = (not isSel and s.limited) and { 1, 0.42, 0.24 } or nil,
                        status = s,
                    })
                end
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.sortDist ~= b.sortDist then return a.sortDist < b.sortDist end
        return (tonumber(a.skill) or 0) < (tonumber(b.skill) or 0)
    end)
    return rows
end

local function renderDetail(page)
    local d = page.detail
    if not selected then
        d.title:SetText(L["Click a recipe for details."])
        d.left:SetText("") d.right:SetText("")
        d.arrow:Hide() d.mute:Hide() d.guild:Hide() d.shop:Hide()
        return
    end
    local id, npc = selected.itemID, selected.npc
    local rec = RM.Data.recipes[id]
    local s = RM.Rules:Status(id, npc)
    local name, color = itemName(id)
    d.title:SetText(color .. name .. "|r")
    local lines = {}
    table.insert(lines, s.color .. s.text .. "|r  -  " .. profName(rec.skillLine) .. " " .. (s.req or "?") .. "  -  " .. (s.bind or ""))
    if npc then
        local v = RM.Data.vendors[npc]
        table.insert(lines, L["Vendor"] .. ": " .. v.name .. " - " .. zoneName(selected.point and selected.point[1]))
    end
    if s.limited then
        local o = npc and RM.realm.observations[npc] and RM.realm.observations[npc][id]
        local restock = RM.Data:RestockSeconds(id, npc)
        local txt = "|cffff6a3d" .. L["Limited Supply"] .. "|r"
        if restock then txt = txt .. " - " .. string.format(L["restock about %d min"], math.floor(restock / 60)) end
        if o and o.lastAvail then txt = txt .. " - " .. string.format(L["last seen in stock %s ago"], age(o.lastAvail)) end
        table.insert(lines, txt)
        local g = RM.Sales:GuildStock(npc, id)
        if g and (not o or not o.last or g.t > o.last) then
            table.insert(lines, "|cff69ccf0" .. string.format(g.avail > 0 and L["guild: %s saw %d in stock %s ago"] or L["guild: %s saw it sold out %s ago"],
                g.who or "?", g.avail > 0 and g.avail or age(g.t), g.avail > 0 and age(g.t) or nil) .. "|r")
        end
    end
    local owned = RM.Int:OwnedText(id)
    if owned then table.insert(lines, "|cff8fe39b" .. owned .. "|r") end
    d.left:SetText(table.concat(lines, "\n"))
    local r = {}
    table.insert(r, L["Sell recipe"] .. ": " .. L["Vendor price"] .. " " .. (s.vendorPrice and RM:Money(s.vendorPrice) or "-")
        .. "  ->  " .. L["AH"] .. " " .. (s.ahPrice and RM:Money(s.ahPrice) or L["no price"]))
    table.insert(r, L["Margin"] .. ": " .. (s.margin and RM:Money(s.margin) or "-") .. (s.lux and ("  |cffffd100" .. L["very lucrative"] .. "|r") or ""))
    local ev = RM.Sales:Evidence(id, s.vendorPrice, s.limited)
    if ev then
        local src = (ev.src == "guild") and string.format(L["guild (%d players)"], ev.n or 1) or ((ev.src == "both") and L["own + guild"] or L["own (Journalator)"])
        table.insert(r, L["Sales"] .. " " .. src .. ": " .. string.format(L["%d of %d sold"], ev.s, ev.s + ev.f)
            .. (ev.realized and ("  -  " .. L["Sold for"] .. " " .. RM:Money(ev.realized)) or ""))
        if ev.profit then
            table.insert(r, L["Expected profit per listing"] .. ": " .. RM:Money(ev.profit)
                .. ((ev.buy or 0) > 0 and ("  -  |cffffd100" .. string.format(L["buy %d at the vendor"], ev.buy) .. "|r") or ("  -  |cffe0806a" .. L["not worth buying"] .. "|r")))
        end
    elseif RM.Sales:HasJournalator() then
        table.insert(r, "|cff8a8270" .. L["No sales recorded yet (Journalator)."] .. "|r")
    else
        table.insert(r, "|cff8a8270" .. L["Real sales: install Journalator."] .. "|r")
    end
    local p = RM.Prices:Product(id)
    if p then
        local pname = itemName(p.id)
        table.insert(r, L["Product"] .. ": " .. pname .. " - " .. L["AH"] .. " " .. (p.ah and RM:Money(p.ah) or L["no price"]))
        if p.craft and RM.Prof:Skill(rec.skillLine) then table.insert(r, L["Craft profit"] .. ": " .. RM:Money(p.craft)) end
    end
    d.right:SetText(table.concat(r, "\n"))
    d.arrow:SetShown(npc ~= nil and selected.point ~= nil)
    d.mute:SetShown(npc ~= nil)
    d.guild:SetShown(IsInGuild())
    d.shop:SetShown(RM.Int:HasAuctionatorLists() and RM.Int:Reagents(id) ~= nil)
end

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

    local defs = { { "hot", L["Hot"], buildHotPage }, { "recipes", L["Vendor recipes"], buildRecipePage },
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
        local p = pages.recipes
        for _, b in ipairs(p.rankButtons or {}) do b:Refresh() end
        p.prof:Refresh()
        local rows = recipeRows()
        p.count:SetText(string.format(L["%d recipes"], #rows))
        p.table:SetData(rows)
        p.near:Refresh() p.radius:Refresh() p.unit:Refresh()
        renderDetail(p)
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
    selected = { itemID = itemID, npc = npc, point = point }
    self:ShowTab("recipes")
end

RM:On("GET_ITEM_INFO_RECEIVED", function() UI:RefreshSoon() end)
RM:Listen("PRICES_CHANGED", function() UI:RefreshSoon() end)
RM:Listen("DATA_READY", function() UI:RefreshSoon() end)
RM:Listen("OBSERVATIONS_CHANGED", function() UI:RefreshSoon() end)
RM:Listen("PROFESSIONS_CHANGED", function() UI:RefreshSoon() end)
