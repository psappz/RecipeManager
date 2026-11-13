-- RecipeManager - Profession copilot: a panel beside the profession window with every recipe of
-- that profession, sorted by the skill needed to learn it. Each row shows where the recipe comes from
-- (trainer, vendor, drop, quest) and its colour at your current skill (red, orange, yellow, green, grey).
-- Copyright (C) 2026 psappz - GPL-3.0-or-later
local _, ns = ...
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
    world = { "World drop", "|cffc080ff" }, quest = { "Quest", "|cffe8e0c8" }, unknown = { "unknown", "|cff8a8270" },
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
                table.insert(list, { id = rid, name = info.name, learned = info.learned and true or false, out = out,
                    diff = info.learned and MAP_DIFF[d] or nil, icon = info.icon, src = src })
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
        if t or tLevel then kind = "trainer"
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
            diff = diff, kind = kind, trainer = t, recipeItem = recipeItem, est = est, src = r.src })
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
        if row.recipeItem then tt:AddLine(L["Click: open in RecipeManager"], 0.5, 0.8, 1) end
    end
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
    p.showLearned:SetPoint("TOPRIGHT", -90, -6)
    p.close = W:Button(p, "x", 20, function() RM.settings.copilot = false CP:Refresh() end)
    p.close:SetPoint("TOPRIGHT", -6, -6)
    local legend = {}
    for _, k in ipairs({ "red", "orange", "yellow", "green", "grey" }) do table.insert(legend, square(DIFF_COLOR[k]) .. " " .. L["DIFF_" .. k]) end
    p.legend = W:Text(p, "GameFontDisableSmall", table.concat(legend, "  "))
    p.legend:SetPoint("BOTTOMLEFT", 10, 8)
    local rows = math.max(6, math.floor((host:GetHeight() - 100) / 20))
    p.table = W:Table(p, {
        { "dot", "", 18, "CENTER" }, { "skill", L["Skill"], 40, "RIGHT", L["TIP_COPILOT_SKILL"] },
        { "name", L["Recipe"], 214, nil }, { "source", L["Source"], 92, nil, L["TIP_COPILOT_SOURCE"] },
    }, 20, rows, function(item)
        if item.recipeItem and RM.UI then RM.UI:SelectRecipe(item.recipeItem, item.npc) end
    end)
    p.table:SetPoint("TOPLEFT", 4, -44)
    p.table:SetPoint("RIGHT", -4, 0)
    p.host = host
    return p
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
        local b = RM.W:Button(host, L["Copilot"], 80, function()
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
    local p = host.rmCopilot or self:Build(host)
    host.rmCopilot = p
    self:Place(p, host)
    p:Show()
    local list, lineName, rank = self:Rows()
    local data, learnable, total = {}, 0, 0
    for _, r in ipairs(list) do
        total = total + 1
        if not r.learned and r.learnAt and r.diff ~= "red" then learnable = learnable + 1 end
        if RM.settings.copilotLearned or not r.learned then
            local c = DIFF_COLOR[r.diff or "grey"] or DIFF_COLOR.grey
            local s = SOURCE[r.kind]
            local npc = r.recipeItem and RM.Data.recipes[r.recipeItem] and RM.Data.recipes[r.recipeItem].vendors and RM.Data.recipes[r.recipeItem].vendors[1]
            table.insert(data, {
                dot = r.diff and square(c) or "",
                skill = r.learnAt and (hex(c) .. (r.est and "~" or "") .. r.learnAt .. "|r") or "|cff8a8270?|r",
                name = (r.learned and "|cff9d9d9d" or "|cffffffff") .. r.name .. "|r" .. (r.learned and " |cff7ad07a(" .. L["known"] .. ")|r" or ""),
                source = s[2] .. L[s[1]] .. "|r",
                sortValues = { skill = r.learnAt or 999, dot = DIFF_ORDER[r.diff or "grey"] },
                recipeItem = r.recipeItem, npc = npc,
                onTooltip = tooltip(r),
            })
        end
    end
    p.title:SetText(L["Copilot"] .. " - " .. (lineName or "?") .. " " .. rank)
    p.info:SetText(string.format(L["%d of %d recipes learnable now"], learnable, total))
    p.showLearned:Refresh()
    p.table:SetData(data)
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
