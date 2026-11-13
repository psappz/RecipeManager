#!/usr/bin/env python3
"""Generate Data/SkillLevels.lua from Skillet-Classic's SkillLevelData1.lua (GPL-3.0).

Usage: gen_skill_levels.py <Skillet-Classic/SkillLevelData1.lua> <out.lua>
Keeps two tables:
  byItem  [itemID or enchant spellID] = "orange/yellow/green/grey" or { [recipeID] = "..." }
  bySpell [recipeID] = "min/yellow/green/grey"   (fallback; first value is often 1)
Later entries win, like in Lua.
"""
import re, sys
src = open(sys.argv[1], encoding="utf-8").read()
def block(name):
    i = src.index("Skillet.db.global.%s = {" % name)
    depth, j = 0, src.index("{", i)
    k = j
    while True:
        c = src[k]
        if c == "{": depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0: return src[j + 1:k]
        k += 1
def entries(body):
    out = {}
    for m in re.finditer(r"\[(\d+)\]\s*=\s*(\"[0-9/]+\"|'[0-9/]+'|\{[^}]*\})", body):
        k, v = int(m.group(1)), m.group(2)
        if v.startswith("{"):
            inner = re.findall(r"\[(\d+)\]\s*=\s*[\"']([0-9/]+)[\"']", v)
            out[k] = "{" + ",".join('[%s]="%s"' % (a, b) for a, b in inner) + "}"
        else:
            out[k] = '"%s"' % v.strip("\"'")
    return out
by_item, by_spell = entries(block("SkillLevels")), entries(block("SkillLineAbility"))
lines = ["-- RecipeManager - skill-up levels (orange/yellow/green/grey) of Classic profession recipes.",
         "-- Taken from Skillet-Classic (b-morgan/Skillet-Classic, SkillLevelData1.lua, GPL-3.0) by",
         "-- tools/gen_skill_levels.py. byItem: crafted item or enchant spell -> levels (first value = learn level);",
         "-- bySpell: recipe spell -> levels (first value often 1, use byItem first).",
         "local _, ns = ...", "ns.SkillLevels = { byItem = {"]
lines += ["[%d]=%s," % (k, by_item[k]) for k in sorted(by_item)]
lines += ["}, bySpell = {"]
lines += ["[%d]=%s," % (k, by_spell[k]) for k in sorted(by_spell)]
lines += ["} }"]
open(sys.argv[2], "w").write("\n".join(lines) + "\n")
print(len(by_item), len(by_spell))
