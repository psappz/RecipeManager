local L = ns.L
local out = {}
table.insert(out, "de:" .. L["show learned"] .. "/" .. L["Language"])
ns.SetLanguage("enUS") table.insert(out, "en:" .. L["show learned"] .. "/" .. L["Language"] .. "/" .. L["DIFF_red"])
ns.SetLanguage("frFR") table.insert(out, "fr:" .. L["show learned"] .. "/" .. L["Language"])
ns.SetLanguage("auto") table.insert(out, "auto:" .. L["show learned"] .. " active=" .. ns.language)
return table.concat(out, " | ")
