-- RecipeManager - Profession copilot: a panel beside the profession window with every recipe of
-- that profession, sorted by the skill needed to learn it. Each row shows where the recipe comes from
-- (trainer, vendor, drop, quest) and its colour at your current skill (red, orange, yellow, green, grey).
-- Copyright (C) 2026 psappz - GPL-3.0-or-later
local _, ns = ...
-- QuestieDB entities (resolved in Database.lua; the ItemDB/NpcDB globals can be taken by other addons)
ns.Q = ns.Q or {}
local Q = ns.Q
local RM = ns.RM
local L = ns.L

local CP = {}
RM.Copilot = CP

local DIFF_COLOR = {
    red = { 1, 0.13, 0.13 }, orange = { 1, 0.5, 0.25 }, yellow = { 1, 1, 0 }, green = { 0.25, 0.75, 0.25 }, grey = { 0.5, 0.5, 0.5 },
}
local DIFF_ORDER = { red = 1, orange = 2, yellow = 3, green = 4, grey = 5 }
local MAP_DIFF = { optimal = "orange", medium = "yellow", easy = "green", trivial = "grey", difficult = "red" }
local SOURCE = {
    trainer = { "Trainer", "|cff6fa8ff" }, vendor = { "Vendor", "|cffffd100" }, drop = { "Drop", "|cffc080ff" },
    world = { "World drop", "|cffc080ff" }, quest = { "Quest", "|cffe8e0c8" }, event = { "World event", "|cffff9966" }, unknown = { "unknown", "|cff8a8270" },
}

local function call(fn, ...)
    if type(fn) ~= "function" then return end
    local res = { pcall(fn, ...) }
    if not res[1] then return end
    return select(2, unpack(res))
end

local function square(c)
    local r, g, b = math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255)
    return "|TInterface\\Buttons\\WHITE8X8:10:10:0:0:8:8:0:8:0:8:" .. r .. ":" .. g .. ":" .. b .. "|t"
end

local function hex(c)
    return string.format("|cff%02x%02x%02x", math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255))
end

---------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------
-- "a/b/c/d" for a recipe: crafted item first (learn level is reliable there), then the spell
function CP:Levels(recipeID, out)
    local SL = ns.SkillLevels
    if not SL then return end
    local e = out and SL.byItem[out]
    if type(e) == "table" then e = e[recipeID] or select(2, next(e)) end
    if not e then
        e = SL.byItem[recipeID]
        if type(e) == "table" then e = e[recipeID] or select(2, next(e)) end
    end
    local fromSpell = false
    if not e then e = SL.bySpell[recipeID] fromSpell = true end
    if type(e) ~= "string" then return end
    local a, b, c, d = e:match("^(%d+)/(%d+)/(%d+)/(%d+)$")
    if not a then return end
    a, b, c, d = tonumber(a), tonumber(b), tonumber(c), tonumber(d)
    local est
    if fromSpell and a <= 1 and b > 1 then
        -- spell data carries no learn level: estimate it one step below yellow
        a, est = math.max(1, b - math.max(5, c - b)), true
    end
    return { a, b, c, d, fromSpell = fromSpell, est = est }
end

-- recipes taught by trainers (CMaNGOS): recipe spell -> required skill, cost
function CP:TrainerSpell(recipeID)
    local e = ns.TrainerSpells and recipeID and ns.TrainerSpells[recipeID]
    if not e then return end
    local lvl, cost = e:match("^(%d+)/(%d+)$")
    return tonumber(lvl), tonumber(cost)
end

-- the client's own source text of a recipe (modern API), sorted into a kind
local SOURCE_WORDS = {
    { "world", { "world drop", "weltbeute", "weltdrop", "butin mondial", "botín mundial", "bottino mondiale" } },
    { "trainer", { "trainer", "lehrer", "entraîneur", "instructor", "istruttore", "instrutor", "mestre" } },
    { "vendor", { "vendor", "händler", "verkäufer", "vendeur", "marchand", "vendedor", "venditore", "mercante" } },
    { "quest", { "quest", "quête", "misión", "missione", "missão" } },
    { "drop", { "drop", "beute", "butin", "botín", "bottino", "saque" } },
}
local function sourceKind(text)
    if type(text) ~= "string" or text == "" then return end
    local t = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower()
    for _, e in ipairs(SOURCE_WORDS) do
        for _, w in ipairs(e[2]) do
            if t:find(w, 1, true) then return e[1], t end
        end
    end
end
CP.SourceKind = sourceKind

local function colorAt(lv, skill)
    if not lv then return nil end
    if skill < lv[1] then return "red" end
    if skill < lv[2] then return "orange" end
    if skill < lv[3] then return "yellow" end
    if skill < lv[4] then return "green" end
    return "grey"
end

-- trainers recorded by the collector: crafted item / name -> { cost, skillLevel, trainer }
local function trainerIndex(lineName)
    local byItem, byName = {}, {}
    local c = RM.db.collect
    for npc, t in pairs(c and c.trainers or {}) do
        for _, s in pairs(t.services or {}) do
            if not lineName or s.skill == lineName then
                local e = { cost = s.cost, level = s.skillLevel, trainer = t.name, zone = t.zone, npc = npc }
                if s.item then byItem[s.item] = byItem[s.item] or e end
                if s.name then byName[s.name] = byName[s.name] or e end
            end
        end
    end
    return byItem, byName
end

-- recipe items of RecipeManager's database, by crafted item
local productIndex
local function recipeItemFor(out)
    if not productIndex then
        productIndex = {}
        for id, rec in pairs(RM.Data.recipes) do
            if rec.product then productIndex[rec.product] = id end
        end
    end
    return out and productIndex[out]
end
RM:Listen("DATA_READY", function() productIndex = nil end)

local function lineInfo()
    if C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillLine then
        local a, b, c, d = call(C_TradeSkillUI.GetTradeSkillLine)
        if type(a) == "number" then return a, b, c, d end
        if type(a) == "string" then return nil, a, b, c end
    end
    if C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo then
        local p = call(C_TradeSkillUI.GetBaseProfessionInfo)
        if type(p) == "table" then return p.professionID, p.professionName, p.skillLevel, p.maxSkillLevel end
    end
    if type(GetTradeSkillLine) == "function" then
        local name, rank, max = call(GetTradeSkillLine)
        return nil, name, rank, max
    end
end

-- recipes of the open profession window (modern API lists learned and not yet learned recipes)
local function windowRecipes()
    local list = {}
    if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then
        for _, rid in ipairs(call(C_TradeSkillUI.GetAllRecipeIDs) or {}) do
            local info = call(C_TradeSkillUI.GetRecipeInfo, rid)
            -- Season of Discovery recipes are not part of Forever
            if info and not info.learned and RM.Data:IsSoDSpell(rid) then info = nil end
            if info and info.name then
                local craft = RM.db.collect and RM.db.collect.crafts and RM.db.collect.crafts["r" .. rid]
                local out = craft and craft.out
                if not out and C_TradeSkillUI.GetRecipeSchematic then
                    local s = call(C_TradeSkillUI.GetRecipeSchematic, rid, false)
                    out = type(s) == "table" and s.outputItemID or nil
                end
                local d = info.relativeDifficulty
                if type(d) == "number" then d = ({ [0] = "optimal", [1] = "medium", [2] = "easy", [3] = "trivial" })[d] end
                local src = craft and craft.src
                if not src and not info.learned and C_TradeSkillUI.GetRecipeSourceText then src = call(C_TradeSkillUI.GetRecipeSourceText, rid) end
                local rea, qty = craft and craft.rea, craft and craft.qty
                if not rea and C_TradeSkillUI.GetRecipeSchematic then
                    local sc = call(C_TradeSkillUI.GetRecipeSchematic, rid, false)
                    if type(sc) == "table" then qty = qty or sc.quantityMin end
                    if type(sc) == "table" and sc.reagentSlotSchematics then
                        rea = {}
                        for _, slot in ipairs(sc.reagentSlotSchematics) do
                            local rg = slot.reagents and slot.reagents[1]
                            if rg and rg.itemID then rea[rg.itemID] = slot.quantityRequired or 1 end
                        end
                    end
                end
                if info.learned or not RM.Data:IsSoDItem(out) then
                    table.insert(list, { id = rid, name = info.name, learned = info.learned and true or false, out = out,
                        diff = info.learned and MAP_DIFF[d] or nil, icon = info.icon, src = src, rea = rea, qty = qty })
                end
            end
        end
    elseif type(GetNumTradeSkills) == "function" then
        for i = 1, (call(GetNumTradeSkills) or 0) do
            local name, kind = call(GetTradeSkillInfo, i)
            if name and kind ~= "header" then
                local link = call(GetTradeSkillItemLink, i)
                local rlink = GetTradeSkillRecipeLink and call(GetTradeSkillRecipeLink, i)
                table.insert(list, { id = rlink and tonumber(rlink:match("enchant:(%d+)")) or nil, name = name, learned = true,
                    out = link and tonumber(link:match("item:(%d+)")), diff = MAP_DIFF[kind] })
            end
        end
    end
    return list
end

function CP:Rows()
    local lineID, lineName, rank = lineInfo()
    rank = rank or 0
    local tByItem, tByName = trainerIndex(lineName)
    local rows = {}
    for _, r in ipairs(windowRecipes()) do
        local lv = self:Levels(r.id, r.out)
        local t = (r.out and tByItem[r.out]) or tByName[r.name]
        local recipeItem = recipeItemFor(r.out)
        local rec = recipeItem and RM.Data.recipes[recipeItem]
        local tLevel, tCost = self:TrainerSpell(r.id)
        local srcKind = sourceKind(r.src)
        local kind
        local season = recipeItem and RM.Data:RecipeSeason(recipeItem)
        if t or tLevel then kind = "trainer"
        elseif season then kind = "event"
        elseif rec and rec.vendors and #rec.vendors > 0 then kind = "vendor"
        elseif rec and rec.loot and rec.loot.w then kind = "world"
        elseif rec and ((rec.loot and (rec.loot.n or rec.loot.o or rec.loot.c)) or rec.drops) then kind = "drop"
        elseif rec and rec.quests then kind = "quest"
        elseif srcKind then kind = srcKind
        else kind = "unknown" end
        if not t and tLevel then t = { level = tLevel, cost = tCost } end
        local itemSkill = recipeItem and (RM.Data:RecipeInfo(recipeItem) or {}).skill
        -- learn level: trainer data, then the recipe item, then skill-up data (an estimate if it came from the spell)
        local learnAt = (t and t.level) or itemSkill or (lv and lv[1])
        local est = not (t and t.level) and not itemSkill and lv and lv.est or nil
        if lv and learnAt and lv[1] ~= learnAt then
            lv = { learnAt, math.max(lv[2], learnAt), math.max(lv[3], learnAt), math.max(lv[4], learnAt) }
        end
        local diff = r.diff or colorAt(lv, rank)
        if not r.learned and learnAt and rank < learnAt then diff = "red" end
        table.insert(rows, { id = r.id, name = r.name, learned = r.learned, out = r.out, lv = lv, learnAt = learnAt,
            diff = diff, kind = kind, trainer = t, season = season, recipeItem = recipeItem, est = est, src = r.src, rea = r.rea, qty = r.qty, icon = r.icon })
    end
    table.sort(rows, function(a, b)
        local x, y = a.learnAt or 999, b.learnAt or 999
        if x ~= y then return x < y end
        return a.name < b.name
    end)
    return rows, lineName, rank
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
local function profFrame()
    for _, name in ipairs({ "ProfessionsFrame", "TradeSkillFrame", "CraftFrame" }) do
        local f = _G[name]
        if f and f:IsShown() then return f end
    end
end

local function tooltip(row)
    return function(tt)
        tt:AddLine(row.name, 1, 0.82, 0)
        local c = row.diff and DIFF_COLOR[row.diff]
        if row.lv then
            tt:AddLine(string.format(L["Learn at %d - yellow %d - green %d - grey %d"], row.lv[1], row.lv[2], row.lv[3], row.lv[4]), 0.9, 0.9, 0.9)
        elseif row.learnAt then
            tt:AddLine(string.format(L["Learn at %d"], row.learnAt), 0.9, 0.9, 0.9)
        else
            tt:AddLine(L["Skill-up levels unknown (Forever recipe?)"], 0.6, 0.6, 0.6)
        end
        if c then tt:AddLine(L["Now"] .. ": " .. hex(c) .. L["DIFF_" .. row.diff] .. "|r") end
        local s = SOURCE[row.kind]
        tt:AddLine(" ")
        tt:AddLine(L["Source"] .. ": " .. s[2] .. L[s[1]] .. "|r")
        if row.trainer then
            local who = row.trainer.trainer and (row.trainer.trainer .. " (" .. (row.trainer.zone or "?") .. ")") or L["any profession trainer"]
            tt:AddLine(who .. (row.trainer.cost and row.trainer.cost > 0 and ("  " .. RM:Money(row.trainer.cost)) or ""), 0.8, 0.8, 0.8)
        elseif row.src and not row.recipeItem then
            tt:AddLine(row.src, 0.8, 0.8, 0.8, true)
        end
        if row.est then tt:AddLine(L["Learn level estimated"], 0.6, 0.6, 0.6) end
        local rec = row.recipeItem and RM.Data.recipes[row.recipeItem]
        if rec and rec.vendors and rec.vendors[1] then
            local v = RM.Data.vendors[rec.vendors[1]]
            if v then tt:AddLine(v.name .. (#rec.vendors > 1 and (" +" .. (#rec.vendors - 1)) or ""), 0.8, 0.8, 0.8) end
        end
        if rec and rec.loot and rec.loot.w then
            tt:AddLine(string.format(L["World drop (level %d-%d)"], rec.loot.w[1], rec.loot.w[2]), 0.8, 0.8, 0.8)
        end
        tt:AddLine(L["Click: details below"], 0.5, 0.8, 1)
    end
end

-- every detail of the selected recipe, as lines for the detail box
local GREY = "|cff8a8270"
local function itemName(id)
    local n = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
    if not n and GetItemInfo then n = GetItemInfo(id) end
    return n or ("#" .. id)
end
local function npcName(id)
    local ok, n = pcall(function() return Q.Npc.name(id) end)
    return ok and n or ("#" .. id)
end
local function pct(c)
    if not c then return "" end
    local t = c >= 1 and string.format("%.1f", c) or string.format("%.2f", c)
    t = t:gsub("0+$", ""):gsub("%.$", "")
    if GetLocale() ~= "enUS" and GetLocale() ~= "enGB" then t = t:gsub("%.", ",") end
    return t .. " %"
end

-- price a buyer pays for a reagent: vendor if cheaper, else AH
local function reagentPrice(id)
    local ah = RM.Prices and RM.Prices:AHPrice(id)
    local v = ns.VendorPrices and ns.VendorPrices[id]
    if v and (not ah or v <= ah) then return v end
    return ah
end

function CP:DetailLines(row)
    local out = {}
    local function add(t) table.insert(out, t) end
    local c = row.diff and DIFF_COLOR[row.diff]
    -- levels and colour now
    if row.lv then
        local lv = row.lv
        local parts = {
            (row.est and "~" or "") .. string.format(L["Learn at %d"], lv[1]),
            hex(DIFF_COLOR.yellow) .. L["DIFF_yellow"] .. " " .. lv[2] .. "|r",
            hex(DIFF_COLOR.green) .. L["DIFF_green"] .. " " .. lv[3] .. "|r",
            hex(DIFF_COLOR.grey) .. L["DIFF_grey"] .. " " .. lv[4] .. "|r",
        }
        add(table.concat(parts, "  -  ") .. "   " .. L["Now"] .. ": " .. (c and (hex(c) .. L["DIFF_" .. row.diff] .. "|r") or (GREY .. "?|r"))
            .. (row.learned and ("   |cff7ad07a" .. L["known"] .. "|r") or ""))
    else
        add((row.learnAt and string.format(L["Learn at %d"], row.learnAt) or (GREY .. L["Skill-up levels unknown (Forever recipe?)"] .. "|r"))
            .. (row.learned and ("   |cff7ad07a" .. L["known"] .. "|r") or ""))
    end
    -- source
    local src = SOURCE[row.kind]
    local rec = row.recipeItem and RM.Data.recipes[row.recipeItem]
    local line = L["Source"] .. ": " .. src[2] .. L[src[1]] .. "|r"
    local npc, point
    if row.trainer then
        local who = row.trainer.trainer and (row.trainer.trainer .. " " .. GREY .. (row.trainer.zone or "") .. "|r") or L["any profession trainer"]
        line = line .. "  " .. who .. (row.trainer.cost and row.trainer.cost > 0 and ("  " .. RM:Money(row.trainer.cost)) or "")
    elseif row.season then
        local h = RM.Data.HOLIDAYS[row.season]
        local _, running = RM.Data:RecipeSeason(row.recipeItem)
        line = line .. "  " .. string.format(L["only during %s"], L[h.key])
            .. (running and ("  |cff7ad07a" .. L["running now"] .. "|r") or "")
    end
    if rec and rec.vendors and #rec.vendors > 0 and (not row.trainer) then
        if row.season then add(line) line = "    " end
        local dist
        if RM.UI and RM.UI.BestVendor then npc, point, dist = RM.UI.BestVendor(rec) end
        local v = npc and RM.Data.vendors[npc]
        if v then
            local zone = RM.UI and RM.UI.ZoneName and point and RM.UI.ZoneName(point[1]) or ""
            local st = RM.Rules:Status(row.recipeItem, npc)
            line = line .. "  " .. v.name .. " " .. GREY .. zone .. "|r" .. (dist and ("  " .. RM:FormatDistance(dist)) or "")
                .. (st and st.vendorPrice and ("  " .. RM:Money(st.vendorPrice)) or "")
            if st and st.limited then line = line .. "  |cffff6a3d" .. L["LIMITED"] .. "|r" end
        else
            local first = RM.Data.vendors[rec.vendors[1]]
            local _, why = RM.Data:VendorAllowed(first)
            local season = why == "season" and RM.Data.HOLIDAYS[RM.Data:VendorSeason(first)]
            line = line .. "  " .. (first and first.name or "?") .. "  " .. GREY
                .. (season and string.format(L["only during %s"], L[season.key]) or L["other faction"]) .. "|r"
        end
    elseif rec and rec.loot and rec.loot.w then
        line = line .. "  " .. string.format(L["World drop (level %d-%d)"], rec.loot.w[1], rec.loot.w[2])
    end
    add(line)
    if rec and rec.loot and rec.loot.n and not rec.loot.w then
        local drops = {}
        for i = 1, math.min(3, #rec.loot.n) do
            local e = rec.loot.n[i]
            table.insert(drops, npcName(e[1]) .. " " .. GREY .. pct(e[2]) .. "|r")
        end
        add("    " .. table.concat(drops, ", "))
    end
    if row.kind == "unknown" and row.src then add(GREY .. row.src:gsub("\n", "  ") .. "|r") end
    -- reagents with what the character has (bags and bank)
    if row.rea and next(row.rea) then
        local parts = {}
        for id, n in pairs(row.rea) do
            local have = GetItemCount and GetItemCount(id, true) or 0
            local col = have >= n and "|cff7ad07a" or "|cffd0a060"
            table.insert(parts, n .. "x " .. itemName(id) .. " " .. col .. "(" .. have .. ")|r")
        end
        table.sort(parts)
        add(L["Reagents"] .. ": " .. table.concat(parts, ", "))
    end
    -- crafting margin: product on the AH (after the AH cut) against what the reagents cost
    local P = RM.Prices
    if P and row.out then
        local mat, complete = 0, row.rea ~= nil and next(row.rea) ~= nil
        for id, n in pairs(row.rea or {}) do
            local price = reagentPrice(id)
            if price then mat = mat + price * n else complete = false end
        end
        local qty = row.qty or 1
        local sell = P:Net(P:AHPrice(row.out))
        local parts = {}
        table.insert(parts, L["Materials per craft"] .. ": " .. (complete and RM:Money(mat) or L["no price"]))
        table.insert(parts, L["Product"] .. " " .. L["AH"] .. ": " .. (sell and (RM:Money(sell * qty) .. (qty > 1 and (" (" .. qty .. "x)") or "")) or L["no price"]))
        if sell and complete then
            local profit = sell * qty - mat
            table.insert(parts, L["Craft profit"] .. ": " .. (profit >= 0 and "|cff7ad07a+|r " or "|cffff6060-|r ") .. RM:Money(math.abs(profit)))
        end
        add(table.concat(parts, "  -  "))
    end
    -- resale of the recipe itself (not for bind-on-pickup recipes)
    if row.recipeItem and RM.Rules then
        local st = RM.Rules:Status(row.recipeItem, npc)
        if st and st.bind ~= "BoP" and (st.vendorPrice or st.ahPrice) then
            local t = L["AH recipe"] .. ": " .. (st.ahPrice and RM:Money(st.ahPrice) or L["no price"])
            if st.vendorPrice then t = t .. "  -  " .. L["vendor"] .. ": " .. RM:Money(st.vendorPrice) end
            if st.margin then
                t = t .. "  -  " .. L["Margin"] .. ": " .. RM:Money(st.margin)
                    .. (st.hot and ("  |cffffb100[" .. L["HOT"] .. "]|r") or "")
            end
            add(t)
        end
    end
    return out, npc, point
end

function CP:Build(host)
    local W = RM.W
    local p = W:Panel(host, 0.06, 0.05, 0.03, 0.97)
    p:SetBackdropBorderColor(0.54, 0.45, 0.28, 1)
    p:SetWidth(380)
    p:SetFrameStrata(host:GetFrameStrata())
    p:EnableMouse(true)
    p.title = W:Text(p, "GameFontNormal", L["Copilot"])
    p.title:SetPoint("TOPLEFT", 10, -8)
    p.info = W:Text(p, "GameFontDisableSmall")
    p.info:SetPoint("TOPLEFT", 10, -26)
    p.showLearned = W:Check(p, L["show learned"], function() return RM.settings.copilotLearned end,
        function(v) RM.settings.copilotLearned = v CP:Refresh() end)
    p.showLearned:SetPoint("TOPRIGHT", -110, -8)

    -- colour legend at the bottom: a click hides or shows the recipes of that colour
    p.legend = {}
    local prev
    for _, k in ipairs({ "red", "orange", "yellow", "green", "grey" }) do
        local b = CreateFrame("Button", nil, p)
        b.text = W:Text(b, "GameFontHighlightSmall", square(DIFF_COLOR[k]) .. " " .. L["DIFF_" .. k])
        b.text:SetPoint("LEFT")
        b:SetSize(b.text:GetStringWidth() + 4, 16)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 10, 0) else b:SetPoint("BOTTOMLEFT", 10, 6) end
        b:SetScript("OnClick", function()
            local hide = RM.settings.copilotHide
            hide[k] = not hide[k] or nil
            CP:Refresh()
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(L["DIFF_" .. k], 1, 0.82, 0)
            GameTooltip:AddLine(L["Click: show or hide these recipes"], 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        p.legend[k] = b
        prev = b
    end

    p.totalRows = math.max(6, math.floor((host:GetHeight() - 100) / 20))
    p.table = W:Table(p, {
        { "dot", "", 18, "CENTER" }, { "skill", L["Skill"], 40, "RIGHT", L["TIP_COPILOT_SKILL"] },
        { "name", L["Recipe"], 214, nil }, { "source", L["Source"], 92, nil, L["TIP_COPILOT_SOURCE"] },
    }, 20, p.totalRows, function(item) CP:Select(item.row) end)
    p.table:SetPoint("TOPLEFT", 4, -44)
    p.table:SetPoint("RIGHT", -4, 0)

    -- detail box of the selected recipe (lower third)
    local d = W:Panel(p, 0.04, 0.035, 0.02, 1)
    d:SetBackdropBorderColor(0.4, 0.33, 0.2, 1)
    d:SetPoint("TOPLEFT", p.table, "BOTTOMLEFT", 2, -4)
    d:SetPoint("RIGHT", p, "RIGHT", -6, 0)
    d:SetPoint("BOTTOM", p, "BOTTOM", 0, 26)
    d.icon = d:CreateTexture(nil, "ARTWORK")
    d.icon:SetSize(18, 18)
    d.icon:SetPoint("TOPLEFT", 8, -7)
    d.title = W:Text(d, "GameFontNormal")
    d.title:SetPoint("LEFT", d.icon, "RIGHT", 6, 0)
    d.title:SetPoint("RIGHT", d, "RIGHT", -8, 0)
    d.title:SetJustifyH("LEFT")
    d.title:SetWordWrap(false)
    d.text = W:Text(d, "GameFontHighlightSmall")
    d.text:SetPoint("TOPLEFT", 8, -30)
    d.text:SetPoint("RIGHT", d, "RIGHT", -8, 0)
    d.text:SetPoint("BOTTOM", d, "BOTTOM", 0, 32)
    d.text:SetJustifyH("LEFT")
    d.text:SetJustifyV("TOP")
    d.text:SetSpacing(2)
    d.open = W:Button(d, L["Open in RecipeManager"], 150, function()
        if d.row and d.row.recipeItem and RM.UI then RM.UI:SelectRecipe(d.row.recipeItem, d.npc, d.point) end
    end)
    d.open:SetPoint("BOTTOMRIGHT", -6, 6)
    d.way = W:Button(d, L["Show the way"], 110, function()
        if d.npc and d.point and RM.Arrow then RM.Arrow:Point(d.npc, d.point, { d.row.recipeItem }) end
    end)
    d.way:SetPoint("RIGHT", d.open, "LEFT", -6, 0)
    d:Hide()
    p.detail = d
    p.host = host
    return p
end

-- click on a recipe: details below, the list shrinks to about two thirds; a second click closes them
function CP:Select(row)
    local p = self.panel
    if not p then return end
    if not row or (self.selected == row.id) then
        self.selected = nil
    else
        self.selected = row.id
    end
    self:Refresh()
end

function CP:ShowDetail(row)
    local p = self.panel
    local d = p.detail
    if not row then
        d:Hide()
        p.table:SetVisibleRows(p.totalRows)
        return
    end
    p.table:SetVisibleRows(math.max(4, math.floor(p.totalRows * 2 / 3)))
    local c = row.diff and DIFF_COLOR[row.diff] or DIFF_COLOR.grey
    d.row = row
    d.icon:SetTexture(row.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    d.title:SetText(hex(c) .. row.name .. "|r")
    local lines, npc, point = self:DetailLines(row)
    d.text:SetText(table.concat(lines, "\n"))
    d.npc, d.point = npc, point
    d.open:SetShown(row.recipeItem ~= nil)
    d.way:SetShown(npc ~= nil and point ~= nil)
    if not d.open:IsShown() then
        d.way:ClearAllPoints()
        d.way:SetPoint("BOTTOMRIGHT", -6, 6)
    else
        d.way:ClearAllPoints()
        d.way:SetPoint("RIGHT", d.open, "LEFT", -6, 0)
    end
    d:Show()
end

-- tabs and other pieces that stick out on the right of the profession window (side tabs of the
-- window itself or of other addons): the panel goes right of them
local function rightOverhang(host)
    local right = host:GetRight()
    if not right then return 0 end
    local scale = host:GetEffectiveScale()
    local m = 0
    local function check(f)
        if f == host.rmCopilot or f == host.rmCopilotButton or not f:IsShown() then return end
        local r, top, bottom = f:GetRight(), f:GetTop(), f:GetBottom()
        if not (r and top and bottom) then return end
        r = r * f:GetEffectiveScale() / scale
        local over = r - right
        -- only things beside the window, not tooltips or frames that just happen to be parented here
        if over > m and over < 90 and (f:GetWidth() or 0) < 120 then m = over end
    end
    for _, c in ipairs({ host:GetChildren() }) do check(c) end
    for _, name in ipairs({ "ProfessionsFrameTab", "TradeSkillFrameTab", "SpellBookSkillLineTab" }) do
        for i = 1, 12 do
            local f = _G[name .. i]
            if f and f.GetParent and f:IsShown() then
                local par, near = f:GetParent(), false
                while par do if par == host then near = true break end par = par:GetParent() end
                if near then check(f) end
            end
        end
    end
    return m
end

function CP:Place(p, host)
    local x = math.floor(rightOverhang(host) + 0.5) + 4
    if p.placedX == x then return end
    p.placedX = x
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", host, "TOPRIGHT", x, 0)
    p:SetPoint("BOTTOMLEFT", host, "BOTTOMRIGHT", x, 0)
end

function CP:Refresh()
    local host = profFrame()
    if not host then return end
    if not host.rmCopilotButton then
        local b = RM.W:Button(host, L["RecipeManager Copilot"], 160, function()
            RM.settings.copilot = not RM.settings.copilot
            CP:Refresh()
        end)
        b:SetFrameStrata("HIGH")
        b:SetPoint("BOTTOMRIGHT", host, "TOPRIGHT", 0, 2)
        host.rmCopilotButton = b
    end
    if not RM.settings.copilot then
        if host.rmCopilot then host.rmCopilot:Hide() end
        return
    end
    RM.settings.copilotHide = RM.settings.copilotHide or {}
    local hide = RM.settings.copilotHide
    local p = host.rmCopilot or self:Build(host)
    host.rmCopilot = p
    self.panel = p
    self:Place(p, host)
    p:Show()
    local list, lineName, rank = self:Rows()
    local data, learnable, total, hidden, sel = {}, 0, 0, 0, nil
    for _, r in ipairs(list) do
        total = total + 1
        if not r.learned and r.learnAt and r.diff ~= "red" then learnable = learnable + 1 end
        if RM.settings.copilotLearned or not r.learned then
            if r.diff and hide[r.diff] then
                hidden = hidden + 1
            else
                local c = DIFF_COLOR[r.diff or "grey"] or DIFF_COLOR.grey
                local s = SOURCE[r.kind]
                if r.id == self.selected then sel = r end
                table.insert(data, {
                    dot = r.diff and square(c) or "",
                    skill = r.learnAt and (hex(c) .. (r.est and "~" or "") .. r.learnAt .. "|r") or "|cff8a8270?|r",
                    name = (r.learned and "|cff9d9d9d" or "|cffffffff") .. r.name .. "|r" .. (r.learned and " |cff7ad07a(" .. L["known"] .. ")|r" or ""),
                    source = s[2] .. L[s[1]] .. "|r",
                    sortValues = { skill = r.learnAt or 999, dot = DIFF_ORDER[r.diff or "grey"] },
                    row = r, selected = r.id == self.selected,
                    onTooltip = tooltip(r),
                })
            end
        end
    end
    if not sel then self.selected = nil end
    for k, b in pairs(p.legend) do b:SetAlpha(hide[k] and 0.35 or 1) end
    p.title:SetText(L["Copilot"] .. " - " .. (lineName or "?") .. " " .. rank)
    p.info:SetText(string.format(L["%d of %d recipes learnable now"], learnable, total)
        .. (hidden > 0 and ("  |cff8a8270(" .. string.format(L["%d hidden"], hidden) .. ")|r") or ""))
    p.showLearned:Refresh()
    self:ShowDetail(sel)
    p.table:SetData(data)
    if sel then p.table:ShowItem(function(item) return item.row == sel end) end
end

local pending
local function soon()
    if pending then return end
    pending = true
    C_Timer.After(0.5, function() pending = false CP:Refresh() end)
end
RM:On("TRADE_SKILL_SHOW", soon)
RM:On("TRADE_SKILL_LIST_UPDATE", soon)
RM:On("CRAFT_SHOW", soon)
RM:On("SKILL_LINES_CHANGED", soon)
RM:Listen("COLLECT_CHANGED", soon)
