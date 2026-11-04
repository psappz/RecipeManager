-- RecipeManager - small UI building blocks (no external GUI library)
-- Copyright (C) 2026 psappz - GPL-3.0-or-later
local _, ns = ...
local RM = ns.RM

local W = {}
RM.W = W

local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

function W:Panel(parent, r, g, b, a)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetBackdrop(BACKDROP)
    f:SetBackdropColor(r or 0.06, g or 0.05, b or 0.03, a or 0.95)
    f:SetBackdropBorderColor(0.23, 0.19, 0.13, 1)
    return f
end

function W:Text(parent, template, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    if text then fs:SetText(text) end
    return fs
end

function W:Button(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 100, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

-- Toggle button with an "on" look (filters, tabs)
function W:Toggle(parent, text, width, get, set)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width or 90, 22)
    b:SetBackdrop(BACKDROP)
    b.label = W:Text(b, "GameFontHighlightSmall", text)
    b.label:SetPoint("CENTER")
    function b:Refresh()
        local on = get()
        if on then
            self:SetBackdropColor(0.24, 0.19, 0.09, 1)
            self:SetBackdropBorderColor(0.78, 0.63, 0.29, 1)
            self.label:SetTextColor(1, 0.82, 0)
        else
            self:SetBackdropColor(0.12, 0.1, 0.06, 1)
            self:SetBackdropBorderColor(0.23, 0.19, 0.13, 1)
            self.label:SetTextColor(0.85, 0.82, 0.74)
        end
    end
    b:SetScript("OnClick", function(self) set(not get()) self:Refresh() end)
    b:Refresh()
    return b
end

function W:Check(parent, text, get, set)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(24, 24)
    c.text = c.text or c.Text or W:Text(c, "GameFontHighlightSmall")
    c.text:ClearAllPoints()
    c.text:SetPoint("LEFT", c, "RIGHT", 2, 0)
    c.text:SetText(text)
    c:SetChecked(get())
    c:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    function c:Refresh() self:SetChecked(get()) end
    return c
end

function W:Number(parent, width, get, set)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(width or 50, 20)
    e:SetAutoFocus(false)
    e:SetText(tostring(get()))
    local function commit(self)
        local v = tonumber((self:GetText():gsub(",", ".")))
        if v then set(v) end
        self:SetText(tostring(get()))
        self:ClearFocus()
    end
    e:SetScript("OnEnterPressed", commit)
    e:SetScript("OnEditFocusLost", commit)
    e:SetScript("OnEscapePressed", function(self) self:SetText(tostring(get())) self:ClearFocus() end)
    function e:Refresh() self:SetText(tostring(get())) end
    return e
end

-- Button that cycles through a list of { value, label }
function W:Cycle(parent, width, options, get, set)
    local b = W:Button(parent, "", width)
    function b:Refresh()
        local v = get()
        for _, o in ipairs(options()) do
            if o[1] == v then self:SetText(o[2]) return end
        end
        self:SetText(tostring(v))
    end
    b:SetScript("OnClick", function(self, button)
        local list, v = options(), get()
        local idx = 1
        for i, o in ipairs(list) do if o[1] == v then idx = i end end
        idx = (button == "RightButton") and (idx - 2) % #list + 1 or idx % #list + 1
        set(list[idx][1])
        self:Refresh()
    end)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:Refresh()
    return b
end

-- Scrollable table: columns = { { key, title, width, justify } }, rows = list of tables with the same keys
function W:Table(parent, columns, rowHeight, visibleRows, onClick)
    local t = CreateFrame("Frame", nil, parent)
    t.columns, t.rowHeight, t.visible, t.offset, t.data = columns, rowHeight or 22, visibleRows or 14, 0, {}
    t:SetHeight(t.rowHeight * (t.visible + 1) + 4)

    local header = CreateFrame("Frame", nil, t)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(t.rowHeight)
    local x = 6
    for _, c in ipairs(columns) do
        local fs = W:Text(header, "GameFontNormalSmall", c[2])
        fs:SetPoint("LEFT", header, "LEFT", x, 0)
        fs:SetWidth(c[3] - 6)
        fs:SetJustifyH(c[4] or "LEFT")
        x = x + c[3]
    end

    t.rows = {}
    for i = 1, t.visible do
        local r = CreateFrame("Button", nil, t, "BackdropTemplate")
        r:SetPoint("TOPLEFT", t, "TOPLEFT", 0, -(i * t.rowHeight) - 2)
        r:SetPoint("RIGHT", t, "RIGHT", -2, 0)
        r:SetHeight(t.rowHeight - 2)
        r:SetBackdrop(BACKDROP)
        r.cells = {}
        local cx = 6
        for ci, c in ipairs(columns) do
            local fs = W:Text(r, "GameFontHighlightSmall")
            fs:SetPoint("LEFT", r, "LEFT", cx, 0)
            fs:SetWidth(c[3] - 6)
            fs:SetJustifyH(c[4] or "LEFT")
            fs:SetWordWrap(false)
            r.cells[ci] = fs
            cx = cx + c[3]
        end
        r.icon = r:CreateTexture(nil, "OVERLAY")
        r.icon:SetSize(14, 14)
        r.icon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
        r.icon:Hide()
        r:SetScript("OnClick", function(self)
            if self.item and onClick then onClick(self.item) end
        end)
        r:SetScript("OnEnter", function(self)
            if self.item and self.item.itemID then
                GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
                GameTooltip:SetItemByID(self.item.itemID)
                GameTooltip:Show()
            end
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        t.rows[i] = r
    end

    t:EnableMouseWheel(true)
    t:SetScript("OnMouseWheel", function(self, delta)
        local max = math.max(0, #self.data - self.visible)
        self.offset = math.min(max, math.max(0, self.offset - delta * 3))
        self:Render()
    end)

    function t:SetData(data)
        self.data = data or {}
        self.offset = math.min(self.offset, math.max(0, #self.data - self.visible))
        self:Render()
    end

    function t:Render()
        for i, r in ipairs(self.rows) do
            local item = self.data[i + self.offset]
            r.item = item
            if item then
                r:Show()
                for ci, c in ipairs(self.columns) do r.cells[ci]:SetText(item[c[1]] or "") end
                local bg = item.bg or { 0.08, 0.07, 0.05 }
                r:SetBackdropColor(bg[1], bg[2], bg[3], 1)
                local bd = item.border or (item.selected and { 0.78, 0.63, 0.29 }) or { 0.08, 0.07, 0.05 }
                r:SetBackdropBorderColor(bd[1], bd[2], bd[3], 1)
                if item.luxColumn then
                    local cell = r.cells[item.luxColumn]
                    r.icon:ClearAllPoints()
                    r.icon:SetPoint("LEFT", cell, "LEFT", math.min(cell:GetStringWidth(), cell:GetWidth()) + 2, 0)
                    r.icon:Show()
                else
                    r.icon:Hide()
                end
            else
                r:Hide()
            end
        end
    end
    return t
end
