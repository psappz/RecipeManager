-- RecipeManager - Macro: one macro that RecipeManager rewrites to target the current vendor
-- Copyright (C) 2026 psappz - GPL-3.0-or-later
local _, ns = ...
local RM = ns.RM
local L = ns.L

local MC = {}
RM.Macro = MC

MC.NAME = "RecipeManager"
MC.ICON = "INV_Scroll_03"

local function body(name)
    if not name then return "/run RecipeManager:Print(\"" .. L["No vendor selected."] .. "\")" end
    return "/targetexact " .. name
end

function MC:Index()
    local i = GetMacroIndexByName(self.NAME)
    if i and i > 0 then return i end
end

function MC:Ensure(name)
    if InCombatLockdown() then return nil end
    local i = self:Index()
    if i then return i end
    local general = (GetNumMacros())
    if general >= (MAX_ACCOUNT_MACROS or 120) then
        RM:Print(L["No free general macro slot for the RecipeManager macro."])
        return nil
    end
    local ok, idx = pcall(CreateMacro, self.NAME, self.ICON, body(name), nil)
    if ok then return idx end
end

-- Rewrite the macro for the selected vendor (deferred until combat ends)
function MC:SetVendor(name)
    self.vendorName = name
    RM:AfterCombat("macro", function()
        local i = self:Index()
        if i then EditMacro(i, nil, nil, body(self.vendorName)) end
    end)
end

-- Put the macro on the cursor so the player can drop it on an action bar
function MC:Pickup()
    if InCombatLockdown() then return end
    local i = self:Ensure(self.vendorName)
    if i then
        EditMacro(i, nil, nil, body(self.vendorName))
        PickupMacro(i)
    end
end
