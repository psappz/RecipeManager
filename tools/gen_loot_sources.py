#!/usr/bin/env python3
"""Generate Data/LootSources.lua from the CMaNGOS classic-db full dump.

Usage: gen_loot_sources.py <ClassicDB_*.sql.gz> <out.lua>

For every BoE recipe item (class 9) it collects:
  n = direct creature drops: { npcID, chance% } (top 8 by chance)
  o = gameobject (chest) loot: { objectID, chance% }
  c = container items (clams, lockboxes): { itemID, chance% }
  w = world drop: { minLevel, maxLevel, creatureCount } when the recipe sits in a shared
      reference loot table used by many creatures
Not part of the addon package (.pkgmeta ignores tools/).
"""
import gzip, re, sys
from collections import defaultdict

TABLES = {"item_template", "creature_loot_template", "reference_loot_template", "gameobject_loot_template",
          "item_loot_template", "creature_template", "gameobject_template"}

def parse_values(s):
    rows, row, i, n = [], [], 0, len(s)
    cur, inq = [], False
    while i < n:
        ch = s[i]
        if inq:
            if ch == "\\": cur.append(s[i + 1]); i += 2; continue
            if ch == "'":
                if i + 1 < n and s[i + 1] == "'": cur.append("'"); i += 2; continue
                inq = False
            else: cur.append(ch)
        else:
            if ch == "'": inq = True
            elif ch == "(": row, cur = [], []
            elif ch == ",":
                if row is not None: row.append("".join(cur)); cur = []
            elif ch == ")":
                row.append("".join(cur)); rows.append(row); row, cur = None, []
            elif ch == ";": break
            elif row is not None and not ch.isspace(): cur.append(ch)
        i += 1
    return rows

def load(path):
    cols, data, table = {}, defaultdict(list), None
    with gzip.open(path, "rt", encoding="utf-8", errors="replace") as f:
        create = None
        for line in f:
            m = re.match(r"CREATE TABLE `(\w+)`", line)
            if m:
                create = m.group(1) if m.group(1) in TABLES else None
                if create: cols[create] = []
                continue
            if create:
                m = re.match(r"\s+`(\w+)`", line)
                if m: cols[create].append(m.group(1))
                if line.startswith(")"): create = None
                continue
            m = re.match(r"INSERT INTO `(\w+)` VALUES", line)
            if m and m.group(1) in TABLES:
                t = m.group(1)
                for r in parse_values(line[m.end():]):
                    data[t].append(dict(zip(cols[t], r)))
    return data

def num(v, d=0):
    try: return float(v)
    except: return d

def group_chances(rows):
    """Resolve equal-chance groups: rows with chance 0 in a group share the rest of 100%."""
    by = defaultdict(list)
    for r in rows: by[int(num(r["groupid"]))].append(r)
    out = []
    for g, rs in by.items():
        if g == 0:
            for r in rs: out.append((r, abs(num(r["ChanceOrQuestChance"]))))
        else:
            explicit = sum(abs(num(r["ChanceOrQuestChance"])) for r in rs if num(r["ChanceOrQuestChance"]) != 0)
            zero = [r for r in rs if num(r["ChanceOrQuestChance"]) == 0]
            share = max(0.0, 100.0 - explicit) / len(zero) if zero else 0
            for r in rs: out.append((r, abs(num(r["ChanceOrQuestChance"])) or share))
    return out

def main(src, dst):
    d = load(src)
    recipes = {}
    for it in d["item_template"]:
        if int(num(it.get("class"))) == 9 and int(num(it.get("bonding"))) != 1:
            recipes[int(it["entry"])] = it
    print("BoE recipes:", len(recipes))
    ctpl = {int(c["Entry"]): c for c in d["creature_template"]}
    lootid_to_npcs = defaultdict(list)
    for e, c in ctpl.items():
        lid = int(num(c.get("LootId")))
        if lid: lootid_to_npcs[lid].append(e)

    # reference tables: item -> chance inside the reference
    ref_items = defaultdict(dict)
    by_ref = defaultdict(list)
    for r in d["reference_loot_template"]: by_ref[int(r["entry"])].append(r)
    for ref, rows in by_ref.items():
        for r, ch in group_chances(rows):
            if int(num(r["mincountOrRef"])) > 0: ref_items[ref][int(r["item"])] = ch
    # nested references (reference -> reference)
    for _ in range(2):
        for ref, rows in by_ref.items():
            for r, ch in group_chances(rows):
                m = int(num(r["mincountOrRef"]))
                if m < 0:
                    for it, c2 in list(ref_items.get(-m, {}).items()):
                        ref_items[ref].setdefault(it, ch * c2 / 100)

    out = defaultdict(lambda: {"n": {}, "o": {}, "c": {}, "w": []})
    # creatures
    by_entry = defaultdict(list)
    for r in d["creature_loot_template"]: by_entry[int(r["entry"])].append(r)
    for lid, rows in by_entry.items():
        npcs = lootid_to_npcs.get(lid, [])
        if not npcs: continue
        for r, ch in group_chances(rows):
            m, item = int(num(r["mincountOrRef"])), int(r["item"])
            if m > 0 and item in recipes:
                for npc in npcs: out[item]["n"][npc] = max(out[item]["n"].get(npc, 0), ch)
            elif m < 0:
                for it, c2 in ref_items.get(-m, {}).items():
                    if it in recipes:
                        for npc in npcs: out[it]["w"].append((npc, ch * c2 / 100))
    # gameobjects
    gtpl = {}
    for g in d["gameobject_template"]:
        if int(num(g.get("type"))) in (3, 25):  # chest, fishing hole
            lid = int(num(g.get("data1")))
            if lid: gtpl.setdefault(lid, []).append(int(g["entry"]))
    by_entry = defaultdict(list)
    for r in d["gameobject_loot_template"]: by_entry[int(r["entry"])].append(r)
    for lid, rows in by_entry.items():
        for r, ch in group_chances(rows):
            m, item = int(num(r["mincountOrRef"])), int(r["item"])
            items = {item: ch} if m > 0 else {it: ch * c2 / 100 for it, c2 in ref_items.get(-m, {}).items()}
            for it, c in items.items():
                if it in recipes:
                    for go in gtpl.get(lid, []): out[it]["o"][go] = max(out[it]["o"].get(go, 0), c)
    # containers
    by_entry = defaultdict(list)
    for r in d["item_loot_template"]: by_entry[int(r["entry"])].append(r)
    for cont, rows in by_entry.items():
        for r, ch in group_chances(rows):
            m, item = int(num(r["mincountOrRef"])), int(r["item"])
            items = {item: ch} if m > 0 else {it: ch * c2 / 100 for it, c2 in ref_items.get(-m, {}).items()}
            for it, c in items.items():
                if it in recipes: out[it]["c"][cont] = max(out[it]["c"].get(cont, 0), c)

    lines = ["-- RecipeManager - loot sources of BoE recipes, generated from the CMaNGOS classic-db",
             "-- (Full_DB " + src.split("/")[-1] + ") by tools/gen_loot_sources.py. Chances are Classic 1.12 values.",
             "-- n = creatures {npcID, chance%}, o = chests {objectID, chance%}, c = containers {itemID, chance%},",
             "-- w = world drop {minLevel, maxLevel, creatures}",
             "local _, ns = ...", "ns.LootSources = {"]
    WORLD_MIN = 8  # a recipe dropped through a shared reference by at least this many creature types is a world drop
    count = 0
    for item in sorted(out):
        e = out[item]
        parts = []
        if e["n"]:
            top = sorted(e["n"].items(), key=lambda x: -x[1])[:8]
            parts.append("n={" + ",".join("{%d,%s}" % (n, ("%.2f" % c).rstrip("0").rstrip(".")) for n, c in top) + "}")
        if e["o"]:
            top = sorted(e["o"].items(), key=lambda x: -x[1])[:6]
            parts.append("o={" + ",".join("{%d,%s}" % (n, ("%.2f" % c).rstrip("0").rstrip(".")) for n, c in top) + "}")
        if e["c"]:
            top = sorted(e["c"].items(), key=lambda x: -x[1])[:6]
            parts.append("c={" + ",".join("{%d,%s}" % (n, ("%.2f" % c).rstrip("0").rstrip(".")) for n, c in top) + "}")
        npcs = {n for n, _ in e["w"]}
        if len(e["n"]) >= 20:  # dropped directly by many creature types: also a world drop
            npcs |= set(e["n"])
        if len(npcs) >= WORLD_MIN:
            lv = [int(num(ctpl[n].get("MinLevel"))) for n in npcs if n in ctpl] + [int(num(ctpl[n].get("MaxLevel"))) for n in npcs if n in ctpl]
            lv.sort()
            lo, hi = lv[len(lv) // 20], lv[-1 - len(lv) // 20]  # ignore outliers (5 %)
            parts.append("w={%d,%d,%d}" % (lo, hi, len(npcs)))
        elif npcs:
            top = sorted({n: c for n, c in e["w"]}.items(), key=lambda x: -x[1])[:8]
            if not e["n"]:
                parts.append("n={" + ",".join("{%d,%s}" % (n, ("%.3f" % c).rstrip("0").rstrip(".")) for n, c in top) + "}")
        if parts:
            lines.append("[%d]={%s}," % (item, ",".join(parts)))
            count += 1
    lines.append("}")
    open(dst, "w").write("\n".join(lines) + "\n")
    print("recipes with loot sources:", count)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
