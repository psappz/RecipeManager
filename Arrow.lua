-- RecipeManager - Arrow: points to the selected vendor; click targets, Ctrl+drag moves, drag puts the macro on the cursor
-- Copyright (C) 2026 psappz - GPL-3.0-or-later
local _, ns = ...
local RM = ns.RM
local L = ns.L

local A = {}
RM.Arrow = A

local btn, tex, nameText, distText
local target -- { npc, name, cont, wx, wy, recipes = {itemID...} }
local hideAt

local function create()
    btn = CreateFrame("Button", "RecipeManagerArrow", UIParent, "SecureActionButtonTemplate")
    btn:SetSize(64, 64)
    btn:SetFrameStrata("MEDIUM")
    btn:SetMovable(true)
    btn:SetClampedToScreen(true)
    btn:RegisterForClicks("LeftButtonUp", "LeftButtonDown", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetAttribute("type1", "macro")
    btn:SetAttribute("type2", "")

    tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetTexture("Interface\\Minimap\\MiniMap-QuestArrow")
    tex:SetAllPoints()
    tex:SetVertexColor(1, 0.82, 0)

    nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("TOP", btn, "BOTTOM", 0, -2)
    distText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    distText:SetPoint("TOP", nameText, "BOTTOM", 0, -1)

    btn:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        if IsControlKeyDown() then
            self:StartMoving()
        else
            RM.Macro:Pickup()
        end
    end)
    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, _, x, y = self:GetPoint()
        RM.settings.arrow = { point = p, x = x, y = y }
    end)
    btn:HookScript("OnMouseUp", function(_, button)
        if button == "RightButton" then A:Hide() end
    end)
    btn:SetScript("OnEnter", function(self) A:ShowTooltip(self) end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local elapsed = 0
    btn:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < 0.1 then return end
        elapsed = 0
        A:Update()
    end)
    local pos = RM.settings.arrow
    btn:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or 180)
    btn:Hide()
end

-- npc: vendor id; point = { uiMap, x, y }; recipes = list of item ids to show in the tooltip
function A:Point(npc, point, recipes)
    if not btn then create() end
    local v = RM.Data.vendors[npc]
    if not v or not point then return end
    local cont, wx, wy = RM:WorldPos(point[1], point[2], point[3])
    if not cont then return end
    target = { npc = npc, name = v.name, cont = cont, wx = wx, wy = wy, recipes = recipes or v.recipes }
    hideAt = nil
    nameText:SetText(v.name)
    RM.Macro:SetVendor(v.name)
    RM:AfterCombat("arrow", function()
        btn:SetAttribute("macrotext1", "/targetexact " .. v.name)
        btn:Show()
    end)
end

function A:Hide()
    target = nil
    if btn then RM:AfterCombat("arrowhide", function() btn:Hide() end) end
end

function A:Update()
    if not target then return end
    local cont, px, py = RM:PlayerWorldPos()
    local d = RM:Distance(cont, px, py, target.cont, target.wx, target.wy)
    if not d then
        distText:SetText(L["other continent"])
        return
    end
    distText:SetText(RM:FormatDistance(d))
    local facing = GetPlayerFacing()
    if facing then
        -- world coordinates: +x north, +y west; facing: radians counter-clockwise from north
        local angle = math.atan2(target.wy - py, target.wx - px)
        tex:SetRotation(angle - facing)
    end
    if d < 10 then
        tex:SetVertexColor(0.12, 1, 0)
        hideAt = hideAt or (GetTime() + 5)
        if GetTime() > hideAt then A:Hide() end
    elseif d < 50 then
        tex:SetVertexColor(1, 0.69, 0)
        hideAt = nil
    else
        tex:SetVertexColor(1, 0.82, 0)
        hideAt = nil
    end
end

function A:ShowTooltip(owner)
    if not target then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(target.name, 1, 0.82, 0)
    for _, id in ipairs(target.recipes or {}) do
        local s = RM.Rules:Status(id, target.npc)
        if s and RM.Rules:ShouldWarn(s) then
            local name = C_Item.GetItemNameByID(id) or ("item " .. id)
            local tag = s.limited and ("|cffff6a3d" .. L["LIMITED"] .. "|r ") or ""
            GameTooltip:AddDoubleLine(tag .. name, s.color .. s.text .. "|r")
            local right = s.ahPrice and (L["AH recipe"] .. " " .. RM:Money(s.ahPrice)) or L["no price"]
            GameTooltip:AddDoubleLine("   " .. L["Vendor"] .. " " .. RM:Money(s.vendorPrice), right, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["Click: target - Ctrl+drag: move - drag to action bar: macro - right-click: hide"], 0.55, 0.8, 1, true)
    GameTooltip:Show()
end

function A:Target() return target end
