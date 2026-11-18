-- RecipeManager - Rules: recipe status for the current character and warning decisions
-- Copyright (C) 2026 psappz - GPL-3.0-or-later
local _, ns = ...
local RM = ns.RM
local L = ns.L

local R = {}
RM.Rules = R

-- Is this profession in scope? Focus if set, otherwise the character's own professions.
function R:InScope(skillLine)
    local focus = RM.char.focus
    if focus and next(focus) then return focus[skillLine] == true end
    return RM.Prof:Skill(skillLine) ~= nil
end

-- the twink with this profession and the highest skill in it
function R:TwinkWithProfession(skillLine)
    local best, bestSkill
    for _, name in ipairs(RM.Prof:Twinks()) do
        local c = RM.realm.chars[name]
        local sk = c.twink ~= false and c.profs and c.profs[skillLine]
        if sk then
            local n = tonumber(type(sk) == "table" and (sk.rank or sk.skill) or sk) or 0
            if not best or n > bestSkill then best, bestSkill = name, n end
        end
    end
    return best, best and RM.realm.chars[best].profs[skillLine]
end

local function skillNumber(sk)
    return tonumber(type(sk) == "table" and (sk.rank or sk.skill) or sk)
end

-- Returns a status table for a recipe item, optionally at a given vendor.
function R:Status(itemID, npc)
    local rec = RM.Data.recipes[itemID]
    if not rec then return nil end
    local info = RM.Data:RecipeInfo(itemID) or {}
    local s = {
        id = itemID,
        skillLine = rec.skillLine,
        req = info.skill,
        bind = info.bind or "BoE",
        limited = RM.Data:IsLimited(itemID, npc),
        mySkill = RM.Prof:Skill(rec.skillLine),
        inScope = self:InScope(rec.skillLine),
    }
    s.known = s.mySkill and RM.Prof:Knows(itemID) or false
    if s.known then
        s.state, s.text, s.color = "known", L["known"], "|cff9d9d9d"
    elseif s.mySkill and (not s.req or s.mySkill >= s.req) then
        s.state, s.text, s.color = "learnable", L["learnable"], "|cff1eff00"
    elseif s.mySkill then
        s.state = "presale"
        s.text = string.format(L["pre-buy from skill %d (%d)"], s.req or 0, s.mySkill)
        s.color = "|cffe0c060"
    else
        local tw, twSkill = self:TwinkWithProfession(rec.skillLine)
        if tw and s.bind == "BoE" then
            s.state, s.twink, s.twinkSkill = "twink", tw, skillNumber(twSkill)
            s.text = string.format(L["for %s (%d)"], tw, twSkill or 0)
            s.color = "|cff8fd0ff"
        else
            s.state, s.text, s.color = "other", L["other profession"], "|cff9a9488"
        end
    end
    local p = RM.Prices:Evaluate(itemID, npc)
    s.vendorPrice, s.ahPrice, s.margin, s.hot, s.lux = p.vendor, p.ah, p.margin, p.hot, p.lux
    return s
end

-- Should the proximity warning include this recipe?
-- Can the character (or, for a BoE recipe, a twink) learn it now or within the set number of points?
function R:LearnableSoon(s)
    local ahead = math.max(0, tonumber(RM.settings.learnAhead) or 0)
    if s.known then return false end
    local skill
    if s.state == "learnable" or s.state == "presale" then skill = s.mySkill
    elseif s.state == "twink" then skill = s.twinkSkill end
    if not skill then return false end
    return not s.req or skill + ahead >= s.req
end

function R:ShouldWarn(s)
    local set = RM.settings
    if set.warnLearnableOnly and not self:LearnableSoon(s) then return false end
    -- a BoE recipe that one of my characters already has in bags, bank or mail is not worth a warning
    if set.skipOwned and s.bind == "BoE" and not s.known and RM.Int and RM.Int:Owned(s.id) then return false end
    if s.limited then
        if s.bind == "BoE" then return true end
        -- BoP: only if the character could learn it (also when only the skill is missing)
        return s.state == "learnable" or s.state == "presale"
    end
    if set.warnLimitedOnly then return false end
    if not set.warnProfessions then return s.hot end
    if s.state == "learnable" or s.state == "presale" then return s.inScope end
    if s.state == "twink" then return true end
    -- known or other profession: only worth a warning for resale
    return s.bind == "BoE" and s.hot or false
end
