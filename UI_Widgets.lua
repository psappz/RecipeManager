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

-- Flat button: own look, width grows with the (translated) text so it never touches the border
local PAD = 12
local function fitWidth(b)
    local need = math.ceil((b.label:GetStringWidth() or 0) + 2 * PAD)
    b:SetWidth(math.max(b.minWidth or 0, need))
end

local function paintButton(b)
    if not b:IsEnabled() then
        b:SetBackdropColor(0.08, 0.07, 0.05, 1)
        b:SetBackdropBorderColor(0.18, 0.15, 0.1, 1)
        b.label:SetTextColor(0.45, 0.43, 0.38)
    elseif b.down then
        b:SetBackdropColor(0.24, 0.19, 0.09, 1)
        b:SetBackdropBorderColor(0.78, 0.63, 0.29, 1)
        b.label:SetTextColor(1, 0.82, 0)
    elseif b.hover then
        b:SetBackdropColor(0.17, 0.14, 0.08, 1)
        b:SetBackdropBorderColor(0.78, 0.63, 0.29, 1)
        b.label:SetTextColor(1, 0.9, 0.6)
    else
        b:SetBackdropColor(0.12, 0.1, 0.06, 1)
        b:SetBackdropBorderColor(0.4, 0.33, 0.2, 1)
        b.label:SetTextColor(0.92, 0.88, 0.78)
    end
end

function W:Button(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetBackdrop(BACKDROP)
    b:SetHeight(22)
    b.minWidth = width or 60
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.label:SetPoint("CENTER")
    b:SetFontString(b.label)
    local nativeSetText = b.SetText
    function b:SetText(t) nativeSetText(self, t or "") fitWidth(self) end
    b:SetText(text or "")
    b:SetScript("OnEnter", function(self) self.hover = true paintButton(self) end)
    b:SetScript("OnLeave", function(self) self.hover = false self.down = false paintButton(self) end)
    b:SetScript("OnMouseDown", function(self) if self:IsEnabled() then self.down = true paintButton(self) end end)
    b:SetScript("OnMouseUp", function(self) self.down = false paintButton(self) end)
    b:SetScript("OnEnable", paintButton)
    b:SetScript("OnDisable", paintButton)
    if onClick then b:SetScript("OnClick", onClick) end
    paintButton(b)
    return b
end

-- Small close button ("x") in the window's corner
function W:Close(parent, onClick)
    local b = W:Button(parent, "x", 20, onClick or function() parent:Hide() end)
    b:SetSize(20, 20)
    b.minWidth = 20
    b:SetPoint("TOPRIGHT", -6, -6)
    return b
end

-- Toggle button with an "on" look (filters, tabs); also grows with its text
function W:Toggle(parent, text, width, get, set)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetHeight(22)
    b.minWidth = width or 90
    b:SetBackdrop(BACKDROP)
    b.label = W:Text(b, "GameFontHighlightSmall", text)
    b.label:SetPoint("CENTER")
    fitWidth(b)
    local label = b.label
    local nativeSet = label.SetText
    function label:SetText(t) nativeSet(self, t) fitWidth(b) end
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

-- Checkbox: own square box; the label is part of the clickable area
function W:CheckBox(parent, size)
    local c = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
    size = size or 16
    c:SetSize(size, size)
    c:SetBackdrop(BACKDROP)
    c:SetBackdropColor(0.06, 0.05, 0.03, 1)
    c:SetBackdropBorderColor(0.54, 0.45, 0.28, 1)
    local mark = c:CreateTexture(nil, "ARTWORK")
    mark:SetColorTexture(1, 0.82, 0, 1)
    mark:SetPoint("TOPLEFT", 3, -3)
    mark:SetPoint("BOTTOMRIGHT", -3, 3)
    c:SetCheckedTexture(mark)
    local hl = c:CreateTexture(nil, "HIGHLIGHT")
    hl:SetColorTexture(1, 0.82, 0, 0.15)
    hl:SetAllPoints()
    return c
end

function W:Check(parent, text, get, set)
    local c = W:CheckBox(parent, 16)
    c.text = W:Text(c, "GameFontHighlightSmall", text)
    c.text:SetPoint("LEFT", c, "RIGHT", 6, 0)
    c:SetHitRectInsets(0, -((c.text:GetStringWidth() or 0) + 8), -3, -3)
    c:SetChecked(get())
    c:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    function c:Refresh() self:SetChecked(get()) end
    return c
end

function W:Number(parent, width, get, set)
    local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    e:SetBackdrop(BACKDROP)
    e:SetBackdropColor(0.04, 0.035, 0.02, 1)
    e:SetBackdropBorderColor(0.4, 0.33, 0.2, 1)
    e:SetFontObject(GameFontHighlightSmall)
    e:SetTextInsets(6, 6, 0, 0)
    e:SetJustifyH("CENTER")
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
    e:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(0.78, 0.63, 0.29, 1) self:HighlightText() end)
    e:HookScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(0.4, 0.33, 0.2, 1) end)
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
-- Plain text of a cell: no colour codes, icons or [TAGS]
function W.PlainText(text)
    text = tostring(text or "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("%[.-%]%s*", "")
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Sort value of a cell: money as gold (1g 2s 3c = 1.0203), numbers as numbers, text lower case; nil = missing
function W.SortValue(text, numeric)
    local plain = W.PlainText(text)
    if plain == "" or plain == "-" or plain == "?" then return nil end
    local neg, rest = plain:match("^(%-?)(.*)$")
    if rest:find("^%d+%s*[gsc]") and rest:gsub("%d+%s*[gsc]", ""):gsub("%s", "") == "" then
        local v = 0
        for n, u in rest:gmatch("(%d+)%s*([gsc])") do
            v = v + tonumber(n) / ((u == "g" and 1) or (u == "s" and 100) or 10000)
        end
        return neg == "-" and -v or v
    end
    local lead = plain:match("^%-?%d+%.?%d*")
    local n = tonumber(plain) or (lead and tonumber(lead))
    if n then return n end
    if numeric then return nil end -- "no price", "not tradable" in a number column
    return plain:lower()
end

function W:Table(parent, columns, rowHeight, visibleRows, onClick)
    local t = CreateFrame("Frame", nil, parent)
    t.columns, t.rowHeight, t.visible, t.offset, t.data = columns, rowHeight or 22, visibleRows or 14, 0, {}
    t:SetHeight(t.rowHeight * (t.visible + 1) + 4)

    local header = CreateFrame("Frame", nil, t)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(t.rowHeight)
    -- column header: { key, label, width, justify, tooltip }; click sorts ascending, again descending
    t.heads = {}
    local x = 6
    for ci, c in ipairs(columns) do
        local h = CreateFrame("Button", nil, header)
        h:SetPoint("LEFT", header, "LEFT", x - 3, 0)
        h:SetSize(c[3], t.rowHeight)
        h.text = W:Text(h, "GameFontNormalSmall", c[2])
        h.text:SetPoint("LEFT", 3, 0)
        h.text:SetWidth(c[3] - 6)
        h.text:SetJustifyH(c[4] or "LEFT")
        h.text:SetWordWrap(false)
        h.arrow = h:CreateTexture(nil, "OVERLAY")
        h.arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
        h.arrow:SetSize(9, 8)
        h.arrow:Hide()
        h.hl = h:CreateTexture(nil, "HIGHLIGHT")
        h.hl:SetAllPoints()
        h.hl:SetColorTexture(1, 0.82, 0, 0.08)
        h:SetScript("OnClick", function()
            if t.sortCol == ci then t.sortAsc = not t.sortAsc else t.sortCol, t.sortAsc = ci, true end
            t.offset = 0
            t:Sort()
            t:Render()
        end)
        h:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(c[2], 1, 0.82, 0)
            if c[5] then GameTooltip:AddLine(c[5], 1, 1, 1, true) end
            if W.sortHint then GameTooltip:AddLine(W.sortHint, 0.5, 0.8, 1, true) end
            GameTooltip:Show()
        end)
        h:SetScript("OnLeave", function() GameTooltip:Hide() end)
        t.heads[ci] = h
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
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetScript("OnClick", function(self, button)
            if self.item and onClick then onClick(self.item, button) end
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
        self:Sort()
        self.offset = math.min(self.offset, math.max(0, #self.data - self.visible))
        self:Render()
    end

    -- Sort by the clicked column. Rows keep the caller's order until a header is clicked.
    -- Values: row.sortValues[key] if given, otherwise read from the cell text (money, number or text).
    -- Missing values ("-", "no price", ...) always go to the end.
    function t:Sort()
        for i, h in ipairs(self.heads) do
            h.arrow:SetShown(i == self.sortCol)
            if i == self.sortCol then
                h.arrow:ClearAllPoints()
                local w = math.min(h.text:GetStringWidth(), h.text:GetWidth())
                if (columns[i][4] or "LEFT") == "RIGHT" then h.arrow:SetPoint("RIGHT", h.text, "RIGHT", -w - 3, 0)
                else h.arrow:SetPoint("LEFT", h.text, "LEFT", w + 3, 0) end
                if self.sortAsc then h.arrow:SetTexCoord(0, 0.5625, 1, 0) else h.arrow:SetTexCoord(0, 0.5625, 0, 1) end
            end
        end
        local c = self.sortCol and columns[self.sortCol]
        if not c then return end
        local key, numeric, asc = c[1], (c[4] == "RIGHT"), self.sortAsc
        for i, item in ipairs(self.data) do
            local v
            if item.sortValues and item.sortValues[key] ~= nil then
                v = item.sortValues[key]
                if v == false then v = nil end
            else
                v = W.SortValue(item[key], numeric)
            end
            item._sv, item._si = v, i
        end
        table.sort(self.data, function(a, b)
            local va, vb = a._sv, b._sv
            if va == nil or vb == nil then
                if va ~= nil then return true end
                if vb ~= nil then return false end
                return a._si < b._si
            end
            if type(va) ~= type(vb) then va, vb = tostring(va), tostring(vb) end
            if va == vb then return a._si < b._si end
            if asc then return va < vb else return va > vb end
        end)
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
