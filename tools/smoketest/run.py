import re,sys
from lupa import lua51
L=lua51.LuaRuntime(unpack_returned_tuples=True)
root='/home/claude/src/RecipeManager/'
mock=r'''
local function newmock(name)
  local m = {}
  local mt = {}
  mt.__index = function(t,k)
    if type(k)=="string" and (k:sub(1,2)=="rm" or k:match("^%l")) then return nil end
    if type(k)=="string" and k:match("^Create") then return function() return newmock(k) end end
    if k=="GetHeight" then return function() return 500 end end
    if k=="GetWidth" then return function() return 380 end end
    if k=="GetRight" or k=="GetLeft" or k=="GetTop" or k=="GetBottom" then return function() return 100 end end
    if k=="GetEffectiveScale" or k=="GetScale" or k=="GetFrameLevel" then return function() return 1 end end
    if k=="GetStringWidth" then return function() return 50 end end
    if k=="IsShown" or k=="IsVisible" then return function(self) return not rawget(self,"_hidden") end end
    if k=="Hide" then return function(self) rawset(self,"_hidden",true) end end
    if k=="Show" then return function(self) rawset(self,"_hidden",false) end end
    if k=="SetShown" then return function(self,v) rawset(self,"_hidden",not v) end end
    if k=="GetChildren" then return function() return end end
    if k=="GetParent" then return function() return nil end end
    if k=="GetChecked" then return function() return false end end
    if k=="GetText" then return function() return "" end end
    if k=="GetFrameStrata" then return function() return "MEDIUM" end end
    if k=="GetName" then return function() return name end end
    return function() return nil end
  end
  setmetatable(m, mt)
  return m
end
_G.newmock = newmock
function CreateFrame(t, n, parent) return newmock(n or "frame") end
UIParent = newmock("UIParent")
GameTooltip = newmock("GameTooltip")
RaidWarningFrame = newmock("rw")
Minimap = newmock("Minimap")
C_Timer = { After = function(s,f) end, NewTicker = function() return {Cancel=function() end} end }
function GetLocale() return "deDE" end
function GetTime() return 1000 end
function time() return 1000 end
function date(f) return {month=11, day=18, year=2026} end
function GetCursorPosition() return 0,0 end
function UnitFactionGroup() return "Horde" end
function UnitName() return "Tester" end
function GetRealmName() return "Realm" end
function GetItemCount() return 3 end
function GetItemInfo(id) return "Item"..id end
function IsInInstance() return false end
function UnitOnTaxi() return false end
function UnitLevel() return 30 end
function UnitClass() return "Krieger", "WARRIOR" end
function InCombatLockdown() return false end
function hooksecurefunc() end
function GetAddOnMetadata() return "1.4.1" end
C_AddOns = { GetAddOnMetadata = function() return "1.4.1" end }
SOUNDKIT = {}
SlashCmdList = {}
ITEM_MIN_SKILL = "Benötigt %s (%d)"
ITEM_BIND_ON_PICKUP="BoP" ITEM_BIND_ON_EQUIP="BoE" ITEM_BIND_ON_USE="BoU"
C_Map = { GetBestMapForUnit=function() return 1 end, GetAreaInfo=function() return "Zone" end, GetMapInfo=function() return {name="Zone"} end }
LibStub = setmetatable({}, {__call=function(self, n) return newmock(n) end})
setmetatable(_G, {__index=function(t,k) return nil end})
'''
L.execute(mock)
ns=L.eval('{}')
toc=open(root+'RecipeManager.toc').read().split('\n')
files=[l.strip().replace('\\','/') for l in toc if l.strip() and not l.startswith('#')]
for f in files:
    if f.startswith('Libs/'): continue
    src=open(root+f,encoding='utf-8').read()
    fn=L.execute('return function(src,name,ns) local f,err=loadstring(src,name) if not f then error(err) end return f("RecipeManager", ns) end')
    try: fn(src,f,ns)
    except Exception as e: print('LOAD',f,e); 
L.globals().ns=ns
code=open(sys.argv[1] if len(sys.argv)>1 else root+'tools/smoketest/copilot.lua').read()
try: print(L.execute(code))
except Exception as e: print('ERR',e)
