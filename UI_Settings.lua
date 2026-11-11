-- RecipeManager - tab "Focus / Settings": focus professions, warnings, prices, twinks, muted vendors
-- Copyright (C) 2026 psappz - GPL-3.0-or-later
local _, ns = ...
local RM = ns.RM
local L = ns.L
local W = RM.W

local S = {}
RM.Settings = S

local function focus() return RM.char.focus end
local function setFocus(t) RM.char.focus = t RM:Fire("FOCUS_CHANGED") RM.UI:Refresh() end

function S.Build(page)
    local controls = {}
    page.controls = controls
    local function add(c) table.insert(controls, c) return c end

    -- Focus professions -------------------------------------------------
    local box = W:Panel(page)
    box:SetPoint("TOPLEFT", 4, -4)
    box:SetSize(470, 276)
    local h = W:Text(box, "GameFontNormal", L["Focus professions"])
    h:SetPoint("TOPLEFT", 10, -8)
    local mine = W:Button(box, L["My professions"], 120, function()
        local t = {}
        for skill in pairs(RM.Prof.Me().profs or {}) do t[skill] = true end
        setFocus(t)
    end)
    mine:SetPoint("TOPLEFT", 10, -28)
    local twinks = W:Button(box, L["Mine + twinks"], 120, function()
        local t = {}
        for skill in pairs(RM.Prof.Me().profs or {}) do t[skill] = true end
        for _, n in ipairs(RM.Prof:Twinks()) do
            local c = RM.realm.chars[n]
            if c.twink ~= false then for skill in pairs(c.profs or {}) do t[skill] = true end end
        end
        setFocus(t)
    end)
    twinks:SetPoint("LEFT", mine, "RIGHT", 6, 0)
    local none = W:Button(box, L["No focus"], 120, function() setFocus(nil) end)
    none:SetPoint("LEFT", twinks, "RIGHT", 6, 0)
    local i = 0
    for _, skill in ipairs(RM.Data.PROFESSION_ORDER) do
        local col, row = i % 3, math.floor(i / 3)
        local c = add(W:Check(box, RM.Data:ProfessionName(skill),
            function() local f = focus() return f and f[skill] or false end,
            function(v)
                local f = focus() or {}
                f[skill] = v or nil
                setFocus(next(f) and f or nil)
            end))
        c:SetPoint("TOPLEFT", 10 + col * 150, -58 - row * 26)
        i = i + 1
    end
    page.focusText = W:Text(box, "GameFontDisableSmall")
    page.focusText:SetPoint("BOTTOMLEFT", 10, 10)
    page.focusText:SetWidth(450)
    page.focusText:SetJustifyH("LEFT")

    -- Warnings & prices ---------------------------------------------------
    local w = W:Panel(page)
    w:SetPoint("TOPLEFT", box, "TOPRIGHT", 8, 0)
    w:SetPoint("RIGHT", page, "RIGHT", -4, 0)
    w:SetHeight(276)
    local h2 = W:Text(w, "GameFontNormal", L["Warnings and prices"])
    h2:SetPoint("TOPLEFT", 10, -8)
    local set = RM.settings
    local c1 = add(W:Check(w, L["Warn for recipes of my / focus professions"], function() return set.warnProfessions end, function(v) set.warnProfessions = v end))
    c1:SetPoint("TOPLEFT", 8, -26)
    local c2 = add(W:Check(w, L["Warn only for Limited Supply"], function() return set.warnLimitedOnly end, function(v) set.warnLimitedOnly = v end))
    c2:SetPoint("TOPLEFT", 8, -50)
    local c3 = add(W:Check(w, L["Warning sound"], function() return set.sound end, function(v) set.sound = v end))
    c3:SetPoint("TOPLEFT", 8, -74)
    local l1 = W:Text(w, "GameFontHighlightSmall", L["Warning distance"])
    l1:SetPoint("TOPLEFT", 14, -106)
    page.warnLabel = l1
    local n1 = add(W:Number(w, 60, function() return RM:ToUnit(set.warnDistance) end, function(v) set.warnDistance = math.max(50, RM:FromUnit(v)) end))
    n1:SetPoint("LEFT", l1, "RIGHT", 10, 0)
    local lm = W:Text(w, "GameFontHighlightSmall", L["Hot only from a margin of"])
    lm:SetPoint("LEFT", n1, "RIGHT", 24, 0)
    local nm = add(W:Number(w, 50, function() return (set.hotMinMargin or 0) / 100 end,
        function(v) set.hotMinMargin = math.max(0, math.floor(v * 100 + 0.5)) RM:Fire("PRICES_CHANGED") end))
    nm:SetPoint("LEFT", lm, "RIGHT", 10, 0)
    local lms = W:Text(w, "GameFontHighlightSmall", L["silver"])
    lms:SetPoint("LEFT", nm, "RIGHT", 4, 0)
    local l2 = W:Text(w, "GameFontHighlightSmall", L["Hot from AH price >"])
    l2:SetPoint("TOPLEFT", 14, -132)
    local n2 = add(W:Number(w, 40, function() return set.hotFactor end, function(v) set.hotFactor = math.max(1, v) end))
    n2:SetPoint("LEFT", l2, "RIGHT", 10, 0)
    local l3 = W:Text(w, "GameFontHighlightSmall", L["x vendor price, very lucrative from"])
    l3:SetPoint("LEFT", n2, "RIGHT", 6, 0)
    local n3 = add(W:Number(w, 40, function() return set.luxFactor end, function(v) set.luxFactor = math.max(1, v) end))
    n3:SetPoint("LEFT", l3, "RIGHT", 10, 0)
    local l3b = W:Text(w, "GameFontHighlightSmall", "x")
    l3b:SetPoint("LEFT", n3, "RIGHT", 4, 0)
    local l4 = W:Text(w, "GameFontHighlightSmall", L["AH addon"])
    l4:SetPoint("TOPLEFT", 14, -160)
    local src = add(W:Cycle(w, 200, function()
        local o = { { "auto", L["Automatic"] } }
        for _, k in ipairs(RM.Prices.ORDER) do
            local avail = RM.Prices.sources[k].available()
            table.insert(o, { k, L["SRC_" .. k] .. (avail and "" or (" (" .. L["not installed"] .. ")")) })
        end
        if RM.Prices:RecipeScanAllowed() then table.insert(o, { "recipescan", L["RecipeScan (own scan)"] }) end
        return o
    end, function() return set.priceSource end, function(v) set.priceSource = v RM:Fire("PRICES_CHANGED") end))
    src:SetPoint("LEFT", l4, "RIGHT", 10, 0)
    page.srcHint = W:Text(w, "GameFontDisableSmall")
    page.srcHint:SetPoint("TOPLEFT", 14, -182)
    page.srcHint:SetWidth(440)
    page.srcHint:SetJustifyH("LEFT")
    local i1 = add(W:Check(w, L["Recipe info in item tooltips"], function() return set.tooltip end, function(v) set.tooltip = v end))
    i1:SetPoint("TOPLEFT", 8, -200)
    local i2 = add(W:Check(w, L["TomTom arrow instead of the own arrow"], function() return set.useTomTom end, function(v) set.useTomTom = v end))
    i2:SetPoint("TOPLEFT", 240, -200)
    local i3 = add(W:Check(w, L["No warning for recipes you already own (Syndicator)"], function() return set.skipOwned end, function(v) set.skipOwned = v end))
    i3:SetPoint("TOPLEFT", 8, -224)
    local i4 = add(W:Check(w, L["Share sales and Limited Supply sightings with RecipeManager users in my guild"], function() return set.shareGuild end, function(v)
        set.shareGuild = v
        if v then RM.Sales:Share(true) RM.Sales:Request() end
    end))
    i4:SetPoint("TOPLEFT", 8, -248)

    -- Twinks ----------------------------------------------------------------
    local t = W:Panel(page)
    t:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -8)
    t:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -4, 4)
    page.family = ns.Family.Bar(t, L["Manager family"])
    page.family:SetPoint("BOTTOMLEFT", 10, 8)
    page.twinkHeader = W:Text(t, "GameFontNormal")
    page.twinkHeader:SetPoint("TOPLEFT", 10, -8)
    page.unmute = W:Button(t, L["Unmute all vendors"], 160, function() wipe(RM.settings.muted) RM.UI:Refresh() end)
    page.unmute:SetPoint("TOPRIGHT", -10, -4)
    page.share = W:Button(t, L["Share data"], 120, function() RM.Collector:ShowShare() end)
    page.share:SetPoint("RIGHT", page.unmute, "LEFT", -6, 0)
    page.twinkRows = {}
    for r = 1, 8 do
        local row = CreateFrame("Frame", nil, t)
        row:SetSize(900, 22)
        row:SetPoint("TOPLEFT", 6, -28 - (r - 1) * 24)
        row.check = W:CheckBox(row, 16)
        row.check:SetPoint("LEFT")
        row.name = W:Text(row, "GameFontHighlightSmall")
        row.name:SetPoint("LEFT", 28, 0)
        row.name:SetWidth(150)
        row.name:SetJustifyH("LEFT")
        row.level = W:Text(row, "GameFontHighlightSmall")
        row.level:SetPoint("LEFT", 180, 0)
        row.profs = W:Text(row, "GameFontHighlightSmall")
        row.profs:SetPoint("LEFT", 220, 0)
        row.profs:SetWidth(560)
        row.profs:SetJustifyH("LEFT")
        row.seen = W:Text(row, "GameFontDisableSmall")
        row.seen:SetPoint("LEFT", 790, 0)
        page.twinkRows[r] = row
    end
end

function S:Refresh(page)
    for _, c in ipairs(page.controls) do if c.Refresh then c:Refresh() end end
    page.warnLabel:SetText(L["Warning distance"] .. " (" .. RM:UnitLabel() .. ")")
    local f = RM.char.focus
    page.focusText:SetText((f and next(f)) and L["Focus active: exact display with full status."]
        or L["No focus: own professions automatically, plus pre-buy and hot recipes."])
    local any = RM.Prices:AnyAddon()
    page.srcHint:SetText(any and string.format(L["RecipeScan is locked because %s shares its prices."], L["SRC_" .. any])
        or L["No AH addon with shared prices found: RecipeScan can be used (button in the auction house)."])

    page.family:Refresh()

    -- current character first, then twinks
    local names = { RM.playerName }
    for _, n in ipairs(RM.Prof:Twinks()) do table.insert(names, n) end
    page.twinkHeader:SetText(string.format(L["Twinks - %s - %d characters - tick = counts for BoE recipes"],
        (RM.faction == "Horde" and FACTION_HORDE) or FACTION_ALLIANCE or RM.faction, #names))
    for r, row in ipairs(page.twinkRows) do
        local name = names[r]
        local c = name and RM.realm.chars[name]
        if c then
            row:Show()
            local cc = c.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class]
            row.name:SetText((cc and cc:WrapTextInColorCode(name) or name) .. (name == RM.playerName and (" |cff9a9488(" .. L["current"] .. ")|r") or ""))
            row.level:SetText(c.level or "")
            local parts = {}
            for skill, rank in pairs(c.profs or {}) do table.insert(parts, RM.Data:ProfessionName(skill) .. " " .. rank) end
            table.sort(parts)
            row.profs:SetText(#parts > 0 and table.concat(parts, "  -  ") or ("|cff9a9488" .. L["Professions not scanned yet - open the profession window once"] .. "|r"))
            row.seen:SetText(RM.UI.Age(c.seen))
            row.check:SetChecked(c.twink ~= false)
            row.check:SetScript("OnClick", function(self) c.twink = self:GetChecked() and true or false end)
            row.check:SetShown(name ~= RM.playerName)
        else
            row:Hide()
        end
    end
end
