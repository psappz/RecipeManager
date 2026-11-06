-- RecipeManager - startup, minimap button, slash commands
-- Copyright (C) 2026 psappz - GPL-3.0-or-later
local ADDON, ns = ...
local RM = ns.RM
local L = ns.L

local LDB = LibStub("LibDataBroker-1.1", true)
local DBIcon = LibStub("LibDBIcon-1.0", true)

local dots = {}

local function pointToNearest()
    local npc, _, point = RM.Proximity:Nearest(100000)
    if npc then
        RM.Arrow:Point(npc, point)
    else
        RM:Print(L["No relevant recipe vendor found on this continent."])
    end
end

local function setupMinimap()
    if not (LDB and DBIcon) then return end
    local obj = LDB:NewDataObject(ADDON, {
        type = "launcher",
        text = "RecipeManager",
        icon = "Interface\\Icons\\INV_Scroll_03",
        OnClick = function(_, button)
            if button == "RightButton" then
                RM.UI:Toggle("settings")
            elseif IsShiftKeyDown() then
                RM.UI:Toggle()
            else
                pointToNearest()
            end
        end,
        OnTooltipShow = function(tt)
            tt:AddLine("RecipeManager")
            tt:AddLine(L["Click: arrow to the nearest relevant vendor"], 1, 1, 1)
            tt:AddLine(L["Shift-click: dialog - right-click: settings"], 1, 1, 1)
        end,
    })
    DBIcon:Register(ADDON, obj, RM.settings.minimap)
    local button = DBIcon:GetMinimapButton(ADDON)
    if button then
        local function dot(color, x)
            local t = button:CreateTexture(nil, "OVERLAY", nil, 7)
            t:SetTexture("Interface\\COMMON\\Indicator-Gray")
            t:SetSize(14, 14)
            t:SetPoint("TOPLEFT", button, "TOPLEFT", x, 0)
            t:SetVertexColor(color[1], color[2], color[3])
            t:Hide()
            return t
        end
        dots.zone = dot({ 1, 0.82, 0 }, -2)
    end
end

RM:Listen("ZONE_DOT", function(has)
    if dots.zone then dots.zone:SetShown(has and true or false) end
end)

function RecipeManager_OnAddonCompartmentClick(_, button)
    if button == "RightButton" then RM.UI:Toggle("settings") else RM.UI:Toggle() end
end

SLASH_RECIPEMANAGER1 = "/rm"
SLASH_RECIPEMANAGER2 = "/recipemanager"
SlashCmdList.RECIPEMANAGER = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "" then RM.UI:Toggle()
    elseif msg == "arrow" then pointToNearest()
    elseif msg == "hide" then RM.Arrow:Hide()
    elseif msg == "settings" or msg == "config" then RM.UI:Toggle("settings")
    elseif msg == "export" then RM:Export()
    elseif msg == "macro" then RM.Macro:Pickup()
    else
        RM:Print("/rm, /rm arrow, /rm hide, /rm settings, /rm macro, /rm export")
    end
end

-- Export of learned vendor data (Forever-only recipes, Limited Supply) for submission to the project
function RM:Export()
    local out = {}
    for npc, obs in pairs(self.realm.observations) do
        local v = self.realm.vendors[npc] or {}
        for id, o in pairs(obs) do
            table.insert(out, string.format("%d;%s;%s;%.4f;%.4f;%d;%d;%d;%s", npc, ((v.name or ""):gsub(";", ",")),
                tostring(v.map or ""), v.x or 0, v.y or 0, id, o.price or 0, o.limited and 1 or 0, v.faction or ""))
        end
    end
    table.sort(out)
    local text = "npc;name;uiMap;x;y;item;price;limited;faction\n" .. table.concat(out, "\n")
    if not self.exportFrame then
        local f = RM.W:Panel(UIParent)
        f:SetSize(600, 400)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        -- plain scroll frame (mouse wheel), no Blizzard scroll bar
        local sf = CreateFrame("ScrollFrame", nil, f)
        sf:SetPoint("TOPLEFT", 10, -30)
        sf:SetPoint("BOTTOMRIGHT", -10, 10)
        sf:EnableMouseWheel(true)
        sf:SetScript("OnMouseWheel", function(self, delta)
            local max = self:GetVerticalScrollRange()
            self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - delta * 40)))
        end)
        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true)
        eb:SetFontObject(ChatFontNormal)
        eb:SetWidth(550)
        eb:SetAutoFocus(true)
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        sf:SetScrollChild(eb)
        local t = RM.W:Text(f, "GameFontNormal", L["Copy with Ctrl+C and send it to the project (GitHub issue)."])
        t:SetPoint("TOPLEFT", 10, -10)
        RM.W:Close(f)
        f.edit = eb
        self.exportFrame = f
    end
    self.exportFrame.edit:SetText(text)
    self.exportFrame.edit:HighlightText()
    self.exportFrame:Show()
end

RM:On("ADDON_LOADED", function(_, name)
    if name ~= ADDON then return end
    RM:InitDB()
end)

RM:On("PLAYER_LOGIN", function()
    RM.Prof:ScanSkills()
    setupMinimap()
    RM.Data:Build()
end)
