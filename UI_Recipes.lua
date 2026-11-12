-- RecipeManager - Tab "Recipes": full-text search, filter menu, active filter chips, saved searches,
-- watchlist and a detailed recipe panel. Window size is fixed (980 x 560); lists scroll inside.
-- Copyright (C) 2026 psappz - GPL-3.0-or-later
local _, ns = ...
local RM = ns.RM
local L = ns.L
local W = RM.W
local UI = RM.UI

local STAR_ON = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:14:14|t"
local STAR_OFF = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:14:14:0:0:64:64:0:64:0:64:90:85:70|t"
local GREY = "|cff8a8270"
local RANKS = { "Apprentice", "Journeyman", "Expert", "Artisan" }
local RANK_LABEL = { Apprentice = "Apprentice (1-75)", Journeyman = "Journeyman (75-150)", Expert = "Expert (150-225)", Artisan = "Artisan (225-300)" }
local SOURCES = { "vendor", "quest", "mob", "chest", "world" }
local SOURCE_LABEL = { vendor = "Vendor", quest = "Quest", mob = "Loot: creature", chest = "Loot: chest or container", world = "World drop" }
local LOOT = { mob = true, chest = true, world = true }
local FLAGS = { "notLearned", "limited", "hot", "watch" }
local FLAG_LABEL = { notLearned = "not learned", limited = "only Limited Supply", hot = "only hot", watch = "only watchlist" }

-- current filter (session); "near" mirrors the saved setting
local F = { q = "", profs = {}, ranks = {}, srcs = {}, flags = {} }

local function db()
    RM.db.watch = RM.db.watch or {}
    RM.db.savedSearches = RM.db.savedSearches or {}
    return RM.db
end

local function copy(t) local o = {} for k, v in pairs(t or {}) do o[k] = v end return o end
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

local function itemName(id) return UI.ItemName(id) end
local function profName(skill) return UI.ProfName(skill) end
local function zoneName(map) return UI.ZoneName(map) end

---------------------------------------------------------------------------
-- Helpers: reagents, prices, alerts
---------------------------------------------------------------------------
local craftIndex, craftIndexSize
local function collectedCraft(product)
    local c = RM.db.collect and RM.db.collect.crafts
    if not c then return nil end
    local n = count(c)
    if not craftIndex or craftIndexSize ~= n then
        craftIndex, craftIndexSize = {}, n
        for _, e in pairs(c) do if e.out then craftIndex[e.out] = e end end
    end
    return craftIndex[product]
end

-- { [reagentItemID] = count }, qty or nil
local function reagentsOf(rec)
    local product = rec and rec.product
    if not product then return nil end
    local r = RM.db.reagents[product]
    if r and r.reagents then return r.reagents, r.qty or 1 end
    local e = collectedCraft(product)
    if e and e.rea and next(e.rea) then return e.rea, e.qty or 1 end
end
UI.RecipeReagents = reagentsOf

-- price a buyer pays for a reagent: vendor if cheaper, else AH
local function reagentPrice(id)
    local ah = RM.Prices:AHPrice(id)
    local v = ns.VendorPrices and ns.VendorPrices[id]
    if v and (not ah or v <= ah) then return v, "vendor" end
    if ah then return ah, "ah" end
end

local function ownedCount(id)
    local o = RM.Int:Owned(id)
    if not o then return 0 end
    local n = 0
    for _, x in ipairs(o) do n = n + x[2] end
    return n
end

-- watched Limited Supply recipes that were seen in stock recently
local function stockAlerts()
    local out = {}
    for id in pairs(db().watch) do
        local rec = RM.Data.recipes[id]
        for _, npc in ipairs(rec and rec.vendors or {}) do
            local o = RM.realm.observations[npc] and RM.realm.observations[npc][id]
            local window = RM.Data:RestockSeconds(id, npc) or 1800
            if o and o.limited and (o.avail or 0) > 0 and o.last and time() - o.last < window then
                table.insert(out, { id = id, npc = npc, t = o.last })
            else
                local g = RM.Sales and RM.Sales.GuildStock and RM.Sales:GuildStock(npc, id)
                if g and g.avail and g.avail > 0 and time() - g.t < window then table.insert(out, { id = id, npc = npc, t = g.t, guild = g.who }) end
            end
        end
    end
    table.sort(out, function(a, b) return a.t > b.t end)
    return out
end

---------------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------------
local function sourceKind(rec, npc)
    if npc then return "vendor" end
    if rec.quests then return "quest" end
    local l = rec.loot
    if l and l.w then return "world" end
    if (l and l.n) or rec.drops then return "mob" end
    if l and (l.o or l.c) then return "chest" end
end

-- QuestieDB names and zones for loot sources
local function npcName(id)
    local ok, n = pcall(NpcDB.name, id)
    return ok and n or ("#" .. id)
end
local function objectName(id)
    local ok, n = pcall(ObjectDB.name, id)
    return ok and n or ("#" .. id)
end
local function areaName(db, id)
    local ok, area = pcall(db.zoneID, id)
    if not ok or not area then return nil end
    if C_Map and C_Map.GetAreaInfo then
        local ok2, name = pcall(C_Map.GetAreaInfo, area)
        if ok2 and name then return name end
    end
end
local function pct(c)
    if not c then return "" end
    local s = c >= 1 and string.format("%.1f", c) or (c >= 0.1 and string.format("%.2f", c) or string.format("%.3f", c))
    s = s:gsub("0+$", ""):gsub("%.$", "")
    if GetLocale() ~= "enUS" and GetLocale() ~= "enGB" then s = s:gsub("%.", ",") end
    return s .. " %"
end

-- short source text for the table
local function lootSource(rec, kind)
    local l = rec.loot or {}
    if kind == "world" then
        return GREY .. string.format(L["World drop (level %d-%d)"], l.w[1], l.w[2]) .. "|r"
    elseif kind == "mob" then
        local first = l.n and l.n[1]
        if first then
            local z = areaName(NpcDB, first[1])
            return npcName(first[1]) .. (z and (" " .. GREY .. z .. "|r") or "") .. ((#l.n > 1) and (GREY .. " +" .. (#l.n - 1) .. "|r") or "")
        end
        return GREY .. L["Loot: creature"] .. "|r"
    elseif kind == "chest" then
        if l.o and l.o[1] then return GREY .. L["Chest"] .. ":|r " .. objectName(l.o[1][1]) end
        if l.c and l.c[1] then return GREY .. L["Container"] .. ":|r " .. (itemName(l.c[1][1]) or "?") end
    end
    return GREY .. L[SOURCE_LABEL[kind]] .. "|r"
end

local function highlight(name, q)
    if q == "" then return name, false end
    local i, j = name:lower():find(q, 1, true)
    if not i then return name, false end
    return name:sub(1, i - 1) .. "|cffffe066" .. name:sub(i, j) .. "|r" .. name:sub(j + 1), true
end

local function matchRest(id, rec, q)
    local p = rec.product and itemName(rec.product)
    if p and p:lower():find(q, 1, true) then return L["product"] end
    local rea = reagentsOf(rec)
    for rid in pairs(rea or {}) do
        local n = itemName(rid)
        if n and n:lower():find(q, 1, true) then return L["reagent"] .. ": " .. n end
    end
    for _, npc in ipairs(rec.vendors or {}) do
        local v = RM.Data.vendors[npc]
        if v and v.name and v.name:lower():find(q, 1, true) then return L["vendor"] .. ": " .. v.name end
        for _, pt in ipairs(v and v.points or {}) do
            local z = zoneName(pt[1])
            if z and z:lower():find(q, 1, true) then return L["zone"] .. ": " .. z end
        end
    end
end

local function rows()
    local out = {}
    local q = (F.q or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local anyProf, anyRank, anySrc = next(F.profs) ~= nil, next(F.ranks) ~= nil, next(F.srcs) ~= nil
    local near = RM.settings.nearOnly
    local radius = RM:RadiusYards(RM.settings.nearRadius)
    local watch = db().watch
    local sel = UI.selected
    for id, rec in pairs(RM.Data.recipes) do
        if not rec.rep and (not anyProf or F.profs[rec.skillLine]) then
            local info = RM.Data:RecipeInfo(id) or {}
            if not anyRank or F.ranks[RM.Data:Rank(info.skill) or ""] then
                local npc, point, dist = UI.BestVendor(rec)
                local kind = sourceKind(rec, npc)
                local ok = kind and (not anySrc or F.srcs[kind])
                if ok and near then ok = kind == "vendor" and dist ~= nil and dist <= radius end
                if ok and F.flags.watch then ok = watch[id] end
                local s = ok and RM.Rules:Status(id, npc)
                if s and LOOT[kind] and s.bind == "BoP" then s = nil end -- BoP loot recipes: later
                if s and F.flags.notLearned and s.known then s = nil end
                if s and F.flags.limited and not s.limited then s = nil end
                if s and F.flags.hot and not s.hot then s = nil end
                local name, color = itemName(id)
                local shown, hit = name, nil
                if s and q ~= "" then
                    local h, inName = highlight(name, q)
                    if inName then shown = h else
                        hit = matchRest(id, rec, q)
                        if not hit then s = nil end
                    end
                end
                if s then
                    local product = RM.Prices:Product(id)
                    local tradable = s.bind ~= "BoP"
                    local tag = s.limited and ("|cffff6a3d[" .. L["LIMITED SUPPLY"] .. "]|r ") or ""
                    if s.hot and tradable then tag = tag .. "|cffffb100[" .. L["HOT"] .. "]|r " end
                    local source
                    if npc then source = RM.Data.vendors[npc].name .. " " .. GREY .. zoneName(point and point[1]) .. "|r"
                    elseif LOOT[kind] then source = lootSource(rec, kind)
                    else source = GREY .. L[SOURCE_LABEL[kind]] .. "|r" end
                    local isSel = sel and sel.itemID == id
                    table.insert(out, {
                        itemID = id, npc = npc, point = point,
                        star = watch[id] and STAR_ON or STAR_OFF,
                        name = tag .. color .. shown .. "|r" .. (hit and (" " .. GREY .. "- " .. hit .. "|r") or ""),
                        skill = s.req or "?",
                        prof = profName(rec.skillLine),
                        source = source,
                        dist = RM:FormatDistance(dist),
                        ek = s.vendorPrice and RM:Money(s.vendorPrice) or "-",
                        ah = (not tradable and (GREY .. L["not tradable"] .. "|r")) or (s.ahPrice and RM:Money(s.ahPrice)) or (GREY .. L["no price"] .. "|r"),
                        margin = (tradable and s.margin) and ((s.hot and "|cffffd100" or "") .. RM:Money(s.margin) .. "|r") or "-",
                        product = product and product.ah and RM:Money(product.ah) or "-",
                        craft = (product and product.craft and RM.Prof:Skill(rec.skillLine)) and RM:Money(product.craft) or "-",
                        sortDist = dist or 1e9,
                        sortValues = { dist = dist or false, star = watch[id] and 1 or 0 },
                        luxColumn = (tradable and s.lux) and 2 or nil,
                        selected = isSel,
                        bg = isSel and { 0.16, 0.13, 0.08 } or (s.limited and { 0.16, 0.08, 0.03 }) or nil,
                        border = (not isSel and s.limited) and { 1, 0.42, 0.24 } or nil,
                    })
                end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.sortDist ~= b.sortDist then return a.sortDist < b.sortDist end
        return (tonumber(a.skill) or 0) < (tonumber(b.skill) or 0)
    end)
    return out
end

---------------------------------------------------------------------------
-- Chips, saved searches
---------------------------------------------------------------------------
local function activeChips()
    local list = {}
    local q = (F.q or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if q ~= "" then table.insert(list, { "\"" .. q .. "\"", function() UI.recipePage.search:SetText("") end }) end
    for _, skill in ipairs(RM.Data.PROFESSION_ORDER) do
        if F.profs[skill] then table.insert(list, { profName(skill), function() F.profs[skill] = nil UI:Refresh() end }) end
    end
    for _, r in ipairs(RANKS) do
        if F.ranks[r] then table.insert(list, { L[r], function() F.ranks[r] = nil UI:Refresh() end }) end
    end
    for _, k in ipairs(SOURCES) do
        if F.srcs[k] then table.insert(list, { L[SOURCE_LABEL[k]], function() F.srcs[k] = nil UI:Refresh() end }) end
    end
    for _, k in ipairs(FLAGS) do
        if F.flags[k] then table.insert(list, { L[FLAG_LABEL[k]], function() F.flags[k] = nil UI:Refresh() end }) end
    end
    if RM.settings.nearOnly then
        table.insert(list, { string.format(L["within %d %s"], RM.settings.nearRadius, RM:UnitLabel()),
            function() RM.settings.nearOnly = false UI:Refresh() end })
    end
    return list
end

local function filterCount()
    return count(F.profs) + count(F.ranks) + count(F.srcs) + count(F.flags) + (RM.settings.nearOnly and 1 or 0)
end

local function resetAll()
    F.profs, F.ranks, F.srcs, F.flags = {}, {}, {}, {}
    RM.settings.nearOnly = false
    UI.recipePage.search:SetText("")
    UI:Refresh()
end

local function saveSearch()
    local chips = activeChips()
    if #chips == 0 then return end
    local parts = {}
    for _, c in ipairs(chips) do table.insert(parts, c[1]) end
    local name = table.concat(parts, " - ")
    if #name > 42 then name = name:sub(1, 40) .. "..." end
    table.insert(db().savedSearches, { name = name, q = F.q, profs = copy(F.profs), ranks = copy(F.ranks), srcs = copy(F.srcs),
        flags = copy(F.flags), near = RM.settings.nearOnly })
    UI:Refresh()
end

local function applySearch(sv)
    F.profs, F.ranks, F.srcs, F.flags = copy(sv.profs), copy(sv.ranks), copy(sv.srcs), copy(sv.flags)
    RM.settings.nearOnly = sv.near and true or false
    UI.recipePage.search:SetText(sv.q or "")
    UI:Refresh()
end

---------------------------------------------------------------------------
-- Filter menu
---------------------------------------------------------------------------
local function buildMenu(page, anchor)
    local m = W:Panel(page, 0.08, 0.065, 0.04, 0.98)
    m:SetBackdropBorderColor(0.78, 0.63, 0.29, 1)
    m:SetFrameStrata("DIALOG")
    m:SetSize(640, 280)
    m:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
    m:EnableMouse(true)
    m:Hide()
    m.checks = {}
    local function head(text, x, y)
        local h = W:Text(m, "GameFontNormalSmall", text)
        h:SetPoint("TOPLEFT", x, y)
        return h
    end
    local function check(text, x, y, get, set)
        local c = W:Check(m, text, get, function(v) set(v) UI:Refresh() end)
        c:SetPoint("TOPLEFT", x, y)
        table.insert(m.checks, c)
        return c
    end
    -- column 1: professions
    head(L["Profession"], 12, -10)
    local mine = W:Button(m, L["My characters"], 90, function()
        F.profs = {}
        for _, c in pairs(RM.realm.chars) do
            for skill in pairs(c.profs or {}) do
                for _, p in ipairs(RM.Data.PROFESSION_ORDER) do if p == skill then F.profs[skill] = true end end
            end
        end
        UI:Refresh()
    end)
    mine:SetPoint("TOPLEFT", 110, -6)
    local y = -32
    for _, skill in ipairs(RM.Data.PROFESSION_ORDER) do
        check(profName(skill), 12, y, function() return F.profs[skill] end, function(v) F.profs[skill] = v or nil end)
        y = y - 22
    end
    -- column 2: rank + source
    head(L["Rank"], 230, -10)
    y = -32
    for _, r in ipairs(RANKS) do
        check(L[RANK_LABEL[r]], 230, y, function() return F.ranks[r] end, function(v) F.ranks[r] = v or nil end)
        y = y - 22
    end
    head(L["Source"], 230, y - 6)
    y = y - 28
    for _, k in ipairs(SOURCES) do
        check(L[SOURCE_LABEL[k]], 230, y, function() return F.srcs[k] end, function(v) F.srcs[k] = v or nil end)
        y = y - 22
    end
    -- column 3: status + distance
    head(L["Status"], 430, -10)
    y = -32
    for _, k in ipairs(FLAGS) do
        check(L[FLAG_LABEL[k]], 430, y, function() return F.flags[k] end, function(v) F.flags[k] = v or nil end)
        y = y - 22
    end
    local near = check(L["only vendors within"], 430, y - 8, function() return RM.settings.nearOnly end, function(v) RM.settings.nearOnly = v end)
    local radius = W:Number(m, 50, function() return RM.settings.nearRadius end,
        function(v) RM.settings.nearRadius = math.max(10, math.floor(v)) UI:Refresh() end)
    radius:SetPoint("TOPLEFT", 450, y - 32)
    local unit = W:Cycle(m, 70, function() return { { "yd", L["yards"] }, { "m", L["meters"] } } end,
        function() return RM.settings.unit end, function(v) RM.settings.unit = v RM.settings.unitChosen = true UI:Refresh() end)
    unit:SetPoint("LEFT", radius, "RIGHT", 6, 0)
    m.radius, m.unit, m.near = radius, unit, near
    local reset = W:Button(m, L["reset all"], 100, resetAll)
    reset:SetPoint("BOTTOMLEFT", 10, 10)
    local done = W:Button(m, L["Done"], 80, function() m:Hide() UI:Refresh() end)
    done:SetPoint("BOTTOMRIGHT", -10, 10)
    function m:Refresh()
        for _, c in ipairs(self.checks) do c:Refresh() end
        self.radius:Refresh() self.unit:Refresh()
    end
    return m
end

---------------------------------------------------------------------------
-- Detail panel
---------------------------------------------------------------------------
local function buildDetail(page, top)
    local d = W:Panel(page)
    d:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 2, -4)
    d:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -6, 4)
    d.title = W:Text(d, "GameFontNormal")
    d.title:SetPoint("TOPLEFT", 10, -8)
    d.title:SetWidth(430)
    d.title:SetJustifyH("LEFT")
    d.title:SetWordWrap(false)
    d.meta = W:Text(d, "GameFontDisableSmall")
    d.meta:SetPoint("TOPLEFT", 10, -24)
    d.meta:SetWidth(430)
    d.meta:SetJustifyH("LEFT")
    d.meta:SetWordWrap(false)
    local cols = {}
    for i, x in ipairs({ 10, 330, 650 }) do
        local h = W:Text(d, "GameFontNormalSmall")
        h:SetPoint("TOPLEFT", x, -42)
        local t = W:Text(d, "GameFontHighlightSmall")
        t:SetPoint("TOPLEFT", x, -56)
        t:SetWidth(300)
        t:SetJustifyH("LEFT")
        t:SetJustifyV("TOP")
        t:SetSpacing(1)
        t:SetMaxLines(6)
        cols[i] = { head = h, text = t }
    end
    d.cols = cols
    local function sel() return UI.selected end
    local buttons = {}
    local function button(text, fn)
        local b = W:Button(d, text, 70, fn)
        local last = buttons[#buttons]
        if last then b:SetPoint("RIGHT", last, "LEFT", -4, 0) else b:SetPoint("TOPRIGHT", d, "TOPRIGHT", -8, -6) end
        table.insert(buttons, b)
        return b
    end
    d.mute = button(L["Mute vendor"], function() local s = sel() if s and s.npc then RM.settings.muted[s.npc] = true RM:Print(L["Vendor muted."]) end end)
    d.guild = button(L["Post to guild"], function() local s = sel() if s then RM.Int:PostToGuild(s.itemID, s.npc, s.point) end end)
    d.shop = button(L["Auctionator list"], function() local s = sel() if s then RM.Int:CreateShoppingList(s.itemID) end end)
    d.arrow = button(L["Show arrow"], function()
        local s = sel()
        if s and s.npc and s.point then RM.Arrow:Point(s.npc, s.point, { s.itemID }) end
    end)
    d.watch = button(L["Watch"], function()
        local s = sel()
        if not s then return end
        db().watch[s.itemID] = (not db().watch[s.itemID]) or nil
        UI:Refresh()
    end)
    return d
end

local function renderDetail(page)
    local d = page.detail
    local selected = UI.selected
    local rec = selected and RM.Data.recipes[selected.itemID]
    if not rec then
        d.title:SetText(L["Click a recipe for details."])
        d.meta:SetText("")
        for _, c in ipairs(d.cols) do c.head:SetText("") c.text:SetText("") end
        for _, b in ipairs({ d.arrow, d.mute, d.guild, d.shop, d.watch }) do b:Hide() end
        return
    end
    local id, npc = selected.itemID, selected.npc
    local s = RM.Rules:Status(id, npc)
    local name, color = itemName(id)
    local tag = (s.limited and ("|cffff6a3d[" .. L["LIMITED SUPPLY"] .. "]|r ") or "") .. ((s.hot and s.bind ~= "BoP") and ("|cffffb100[" .. L["HOT"] .. "]|r ") or "")
    d.title:SetText(tag .. color .. name .. "|r")
    d.meta:SetText(profName(rec.skillLine) .. " " .. (s.req or "?") .. "  -  " .. L[RM.Data:Rank(s.req) or "Apprentice"] .. "  -  " .. (s.bind or "") .. "  -  " .. s.color .. s.text .. "|r")

    -- 1: crafting
    local c1 = {}
    local rea, qty = reagentsOf(rec)
    local mat, complete = 0, true
    if rea then
        for rid, n in pairs(rea) do
            local p, where = reagentPrice(rid)
            local have = ownedCount(rid)
            if p then mat = mat + p * n else complete = false end
            table.insert(c1, n .. "x " .. (itemName(rid) or "?") .. (have > 0 and (" " .. GREY .. "(" .. string.format(L["%d owned"], have) .. ")|r") or "")
                .. "  " .. GREY .. (p and (RM:Money(p * n) .. " " .. (where == "vendor" and L["vendor"] or L["AH"])) or L["no price"]) .. "|r")
        end
        table.insert(c1, L["Materials per craft"] .. ": " .. (complete and RM:Money(mat) or "-"))
    else
        table.insert(c1, GREY .. L["Reagents not known yet - open the profession window once."] .. "|r")
    end
    local p = RM.Prices:Product(id)
    if p then
        table.insert(c1, L["Product"] .. " " .. L["AH"] .. ": " .. (p.ah and RM:Money(p.ah) or L["no price"]))
        if p.ah and rea and complete then table.insert(c1, L["Craft profit"] .. ": " .. RM:Money(p.ah * (qty or 1) - mat)) end
    end
    d.cols[1].head:SetText(L["Crafting"])
    d.cols[1].text:SetText(table.concat(c1, "\n"))

    -- 2: sources + resale
    local c2 = {}
    local cont, px, py = RM:PlayerWorldPos()
    local list = {}
    for _, v in ipairs(rec.vendors or {}) do
        local vend = RM.Data.vendors[v]
        if vend then
            local best
            for _, pt in ipairs(vend.points or {}) do
                local c, wx, wy = RM:WorldPos(pt[1], pt[2], pt[3])
                local dd = RM:Distance(cont, px, py, c, wx, wy)
                if not best or (dd and (not best.d or dd < best.d)) then best = { d = dd, map = pt[1] } end
            end
            local allowed = RM.Data:VendorAllowed(vend)
            table.insert(list, { name = vend.name, zone = zoneName(best and best.map), d = best and best.d, allowed = allowed })
        end
    end
    table.sort(list, function(a, b) return (a.allowed and 0 or 1) < (b.allowed and 0 or 1) or ((a.allowed == b.allowed) and (a.d or 1e9) < (b.d or 1e9)) end)
    for i = 1, math.min(3, #list) do
        local v = list[i]
        table.insert(c2, v.name .. " " .. GREY .. v.zone .. "|r  " .. (v.allowed and RM:FormatDistance(v.d) or (GREY .. L["other faction"] .. "|r")))
    end
    if #list == 0 then
        local l = rec.loot
        if rec.quests then table.insert(c2, GREY .. L["Quest"] .. "|r") end
        if l and l.w then
            table.insert(c2, string.format(L["World drop: creatures of level %d-%d (%d kinds)"], l.w[1], l.w[2], l.w[3]))
        end
        local shown = 0
        for _, e in ipairs(l and l.n or {}) do
            if shown >= (l.w and 1 or 3) then break end
            local z = areaName(NpcDB, e[1])
            table.insert(c2, npcName(e[1]) .. (z and (" " .. GREY .. z .. "|r") or "") .. "  " .. GREY .. pct(e[2]) .. "|r")
            shown = shown + 1
        end
        if l and l.o and l.o[1] and shown < 3 then
            local z = areaName(ObjectDB, l.o[1][1])
            table.insert(c2, L["Chest"] .. ": " .. objectName(l.o[1][1]) .. (z and (" " .. GREY .. z .. "|r") or "") .. "  " .. GREY .. pct(l.o[1][2]) .. "|r")
            shown = shown + 1
        end
        if l and l.c and l.c[1] and shown < 3 then
            table.insert(c2, L["Container"] .. ": " .. (itemName(l.c[1][1]) or "?") .. "  " .. GREY .. pct(l.c[1][2]) .. "|r")
        end
        if l then table.insert(c2, GREY .. L["Drop chances: Classic values, Forever may differ."] .. "|r")
        elseif rec.drops then table.insert(c2, GREY .. L["Loot: creature"] .. "|r")
        elseif not rec.quests then table.insert(c2, GREY .. "-|r") end
    end
    if s.limited then
        local o = npc and RM.realm.observations[npc] and RM.realm.observations[npc][id]
        local restock = RM.Data:RestockSeconds(id, npc)
        local txt = "|cffff6a3d" .. L["Limited Supply"] .. "|r"
        if restock then txt = txt .. " - " .. string.format(L["restock about %d min"], math.floor(restock / 60)) end
        if o and o.lastAvail then txt = txt .. " - " .. string.format(L["last seen in stock %s ago"], UI.Age(o.lastAvail)) end
        table.insert(c2, txt)
    end
    if s.bind ~= "BoP" then
        table.insert(c2, L["AH recipe"] .. ": " .. (s.ahPrice and RM:Money(s.ahPrice) or L["no price"]) .. "  -  " .. L["Margin"] .. ": "
            .. (s.margin and ((s.hot and "|cffffd100" or "") .. RM:Money(s.margin) .. "|r") or "-"))
        local ev = RM.Sales:Evidence(id, s.vendorPrice, s.limited)
        if ev then table.insert(c2, L["Sales"] .. ": " .. string.format(L["%d of %d sold"], ev.s, ev.s + ev.f) .. (ev.realized and ("  -  " .. RM:Money(ev.realized)) or "")) end
    end
    d.cols[2].head:SetText(L["Sources"])
    d.cols[2].text:SetText(table.concat(c2, "\n"))

    -- 3: my characters
    local c3 = {}
    local names = {}
    for n, c in pairs(RM.realm.chars) do if c.faction == RM.faction then table.insert(names, n) end end
    table.sort(names, function(a, b) if a == RM.playerName then return true elseif b == RM.playerName then return false end return a < b end)
    for _, n in ipairs(names) do
        local c = RM.realm.chars[n]
        local skill = c.profs and c.profs[rec.skillLine]
        if skill then
            local state
            if RM.Prof:Knows(id, n) then state = "|cff9d9d9d" .. L["known"] .. "|r"
            elseif not s.req or skill >= s.req then state = "|cff1eff00" .. L["learnable"] .. "|r"
            else state = "|cffe0c060" .. string.format(L["from %d (%d more)"], s.req, s.req - skill) .. "|r" end
            table.insert(c3, n .. " " .. GREY .. skill .. "|r  " .. state)
        end
    end
    if #c3 == 0 then table.insert(c3, GREY .. L["None of your characters has this profession."] .. "|r") end
    local owned = RM.Int:OwnedText(id)
    if owned then table.insert(c3, "|cff8fe39b" .. owned .. "|r") end
    if s.bind ~= "BoP" then table.insert(c3, GREY .. L["BoE: can be bought for another character and mailed."] .. "|r") end
    d.cols[3].head:SetText(L["My characters"])
    d.cols[3].text:SetText(table.concat(c3, "\n"))

    d.watch:SetText(db().watch[id] and L["Watched"] or L["Watch"])
    d.watch:Show()
    d.arrow:SetShown(npc ~= nil and selected.point ~= nil)
    d.mute:SetShown(npc ~= nil)
    d.guild:SetShown(IsInGuild())
    d.shop:SetShown(RM.Int:HasAuctionatorLists() and RM.Int:Reagents(id) ~= nil)
    -- re-anchor the visible buttons from the right
    local last
    for _, b in ipairs({ d.mute, d.guild, d.shop, d.arrow, d.watch }) do
        if b:IsShown() then
            b:ClearAllPoints()
            if last then b:SetPoint("RIGHT", last, "LEFT", -4, 0) else b:SetPoint("TOPRIGHT", d, "TOPRIGHT", -8, -6) end
            last = b
        end
    end
end

---------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------
function UI:BuildRecipePage(page)
    UI.recipePage = page
    local pendingSearch
    page.search = W:Edit(page, 600, L["Search: recipe, product, reagent, vendor, zone"], function(text)
        F.q = text
        if pendingSearch then return end
        pendingSearch = true
        C_Timer.After(0.25, function() pendingSearch = false UI:Refresh() end)
    end)
    page.search:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -6)
    page.filterBtn = W:Button(page, L["Filter"], 110, function()
        page.menu:SetShown(not page.menu:IsShown())
        page.menu:Refresh()
    end)
    page.filterBtn:SetPoint("LEFT", page.search, "RIGHT", 8, 0)
    page.count = W:Text(page, "GameFontDisableSmall")
    page.count:SetPoint("TOPRIGHT", page, "TOPRIGHT", -10, -12)

    -- saved searches
    local sl = W:Text(page, "GameFontDisableSmall", L["Saved:"])
    sl:SetPoint("TOPLEFT", page, "TOPLEFT", 10, -38)
    page.saved = W:Chips(page, 20)
    page.saved:SetPoint("LEFT", sl, "RIGHT", 6, 0)
    page.saved:SetPoint("RIGHT", page, "RIGHT", -10, 0)
    page.saveBtn = W:Button(page, "+ " .. L["save current search"], 60, saveSearch)
    page.saveBtn:SetHeight(18)

    -- active filters
    local al = W:Text(page, "GameFontDisableSmall", L["Active:"])
    al:SetPoint("TOPLEFT", page, "TOPLEFT", 10, -62)
    page.active = W:Chips(page, 20)
    page.active:SetPoint("LEFT", al, "RIGHT", 6, 0)
    page.active:SetPoint("RIGHT", page, "RIGHT", -10, 0)
    page.none = W:Text(page, "GameFontDisableSmall", L["no filters"])
    page.reset = W:Button(page, L["reset all"], 60, resetAll)
    page.reset:SetHeight(18)
    page.alert = CreateFrame("Button", nil, page)
    page.alert:SetHeight(18)
    page.alert.text = W:Text(page.alert, "GameFontHighlightSmall")
    page.alert.text:SetPoint("RIGHT")
    page.alert:SetPoint("TOPRIGHT", page, "TOPRIGHT", -10, -60)
    page.alert:SetScript("OnClick", function(self) if self.target then UI:SelectRecipe(self.target.id, self.target.npc) end end)

    W.sortHint = L["Click: sort ascending - click again: descending"]
    page.table = W:Table(page, {
        { "star", "", 22, "CENTER", L["TIP_WATCH"], function(item) db().watch[item.itemID] = (not db().watch[item.itemID]) or nil UI:Refresh() end },
        { "name", L["Recipe"], 228, nil, L["TIP_RECIPE"] }, { "skill", L["Skill"], 38, "RIGHT", L["TIP_SKILL"] },
        { "prof", L["Profession"], 90, nil, L["TIP_PROF"] },
        { "source", L["Source / Vendor"], 160, nil, L["TIP_SOURCE"] },
        { "dist", L["Distance"], 60, "RIGHT", L["TIP_DIST"] }, { "ek", L["Vendor price"], 58, "RIGHT", L["TIP_EK"] },
        { "ah", L["AH recipe"], 70, "RIGHT", L["TIP_AH"] }, { "margin", L["Margin"], 64, "RIGHT", L["TIP_MARGIN"] },
        { "product", L["AH product"], 70, "RIGHT", L["TIP_PRODUCT"] }, { "craft", L["Craft profit"], 70, "RIGHT", L["TIP_CRAFT"] },
    }, 22, 10, function(item)
        UI.selected = { itemID = item.itemID, npc = item.npc, point = item.point }
        UI:Refresh()
    end)
    page.table:SetPoint("TOPLEFT", page, "TOPLEFT", 4, -82)
    page.table:SetPoint("RIGHT", page, "RIGHT", -4, 0)
    page.detail = buildDetail(page, page.table)
    page.menu = buildMenu(page, page.filterBtn)
    page:HookScript("OnHide", function() page.menu:Hide() end)
end

function UI:RefreshRecipes(page)
    local list = rows()
    page.count:SetText(string.format(L["%d recipes"], #list))
    page.table:SetData(list)
    local n = filterCount()
    page.filterBtn:SetText(n > 0 and (L["Filter"] .. " (" .. n .. ")") or L["Filter"])
    if page.menu:IsShown() then page.menu:Refresh() end

    -- saved searches
    local saved = {}
    for i, sv in ipairs(db().savedSearches) do
        table.insert(saved, { sv.name, function() table.remove(db().savedSearches, i) UI:Refresh() end,
            function() applySearch(sv) end, L["Click: apply - right-click: delete"] })
    end
    local w = page.saved:Set(saved, 700)
    page.saveBtn:ClearAllPoints()
    page.saveBtn:SetPoint("LEFT", page.saved, "LEFT", math.min(w, 700), 0)
    page.saveBtn:SetEnabled(#activeChips() > 0)

    -- active filters
    local chips = activeChips()
    local alerts = stockAlerts()
    local aw = page.active:Set(chips, alerts[1] and 430 or 760)
    page.none:SetShown(#chips == 0)
    page.none:ClearAllPoints()
    page.none:SetPoint("LEFT", page.active, "LEFT", 0, 0)
    page.reset:SetShown(#chips > 0)
    page.reset:ClearAllPoints()
    page.reset:SetPoint("LEFT", page.active, "LEFT", aw, 0)
    local a = alerts[1]
    if a then
        local v = RM.Data.vendors[a.npc]
        page.alert.target = a
        page.alert.text:SetText(STAR_ON .. " |cffff6a3d" .. string.format(L["%s in stock at %s (%s ago)"], (itemName(a.id)), v and v.name or "?", UI.Age(a.t)) .. "|r")
        page.alert:SetWidth(page.alert.text:GetStringWidth() + 4)
        page.alert:Show()
    else
        page.alert:Hide()
    end
    renderDetail(page)
end

RM:Listen("COLLECT_CHANGED", function() UI:RefreshSoon() end)
