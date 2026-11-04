# RecipeManager

**Never walk past a good recipe again.**

RecipeManager warns you when you get close to a recipe vendor that sells something worth your attention – a recipe you can learn, one you should buy ahead for later, or one that resells for a lot more on the Auction House. Limited Supply recipes get a loud **"BUY NOW"** the moment you open the vendor and the recipe is in stock.

Made for **WoW Forever**. **Requires Questie (QuestieDB).**

> Version 0.x – first release for the Forever launch. Please report anything that looks wrong (see *Feedback* below).

---

## Why RecipeManager?

Forever is full of recipe vendors, and travel takes time. Nobody wants to cross half of Azeroth again because they rode past a vendor that sold exactly the pattern they will need at skill 175 – or because someone else bought the one Limited Supply copy first.

Recipe browsers tell you *where* a recipe is sold. RecipeManager tells you **when you are near it**, whether it is **in stock**, and whether it is **worth the money** – for you, for your twinks or for the Auction House.

---

## Proximity warning

When a relevant recipe vendor is within your warning distance (default **1000 yards**), a raid-warning style message appears in the middle of the screen:

*Recipe vendor nearby: Jutak (420 yd) – 2 recipes, 1 Limited Supply*

- Checked every 5 seconds and immediately after zone changes, portals, loading screens and flights.
- Nothing is shown in combat, in instances or while you are on a flight path.
- Each vendor warns again only after 10 minutes. Vendors you are not interested in can be muted.
- Vendors of the other faction are never reported. Neutral vendors (e.g. Booty Bay) are.
- Merchant's Favor vendors are not part of the warning.

You decide what you are warned about: recipes of your own or focus professions, or Limited Supply only.

---

## Limited Supply

Many classic vendor recipes are sold in **limited supply**: one copy for the whole realm, then the vendor needs time to restock. These are the ones that sell for the most on the Auction House.

- **Near the vendor:** the warning mentions Limited Supply and when the recipe was last seen in stock.
- **Vendor window open and the recipe in stock:** **"BUY NOW – Limited Supply"** as a raid warning, with a sound, and the item is highlighted in the merchant window.
- The alarm fires for every **BoE** recipe and for **BoP** recipes your character can learn – also when only the skill is still missing, so you can buy it ahead.
- Approximate restock times are included, and every visit is remembered.

---

## Arrow to the vendor

Click the minimap button, pick a recipe in the window, or follow a warning, and an arrow points the way. The vendor name and distance are shown under it, the tooltip lists the recipes and their prices.

- **Click** – target the vendor (the arrow stays where it is)
- **Ctrl + drag** – move the arrow
- **Drag onto an action bar** – places the **RecipeManager macro**
- **Right-click** – hide the arrow

The **RecipeManager macro** is a single macro that RecipeManager rewrites for the vendor you are heading to (`/targetexact <name>`). Leave it on your bar and it always targets the current vendor, much like the macros of RestedXP.

---

## The window (`/rm`)

### Hot
All vendor recipes for gold, sorted by what reselling the **recipe itself** earns: vendor price, Auction House price after the 5 % cut, margin and age of the price. Filter by profession, *only hot*, *only Limited Supply* or *only learned in Forever*.

- **Hot** – the recipe sells for more than **2×** its vendor price (configurable), confirmed in at least two price snapshots, so a single overpriced listing does not count.
- **Gold coin** – *very lucrative*: at least **4×** the vendor price (configurable).

### Vendor recipes
Look up any recipe: filter by profession and rank (Apprentice 1–75, Journeyman 75–150, Expert 150–225, Artisan 225–300).

- **Only vendors within …** (on by default, 300 yards or meters) shows what you can buy right around you.
- Untick it to see **all** recipes, including quest rewards and drops.
- Columns: recipe (in its quality colour), skill, source / vendor, distance, vendor price, AH price of the recipe, margin, AH price of the crafted item and crafting profit.
- Limited Supply recipes are highlighted.
- Click a recipe for details, the arrow and the option to mute the vendor.

RecipeManager values the **recipe**. The crafted item's price is shown for information; for serious crafting analysis use TSM, CraftProfit and friends.

### Focus / Settings
- **Focus professions:** pick any primary or secondary profession – also ones your character does not have. Without a focus, RecipeManager uses your own professions automatically.
- **Warnings:** professions or Limited Supply only, warning distance, sound.
- **Prices:** hot and very lucrative thresholds, choice of Auction House addon.
- **Twinks:** your other characters on the same realm and faction with their professions. Tick a twink and BoE recipes for its professions count for you too (you can mail them).

---

## Prices

RecipeManager reads prices from an Auction House addon that shares its data with other addons:

- **Auctionator**
- **Auctioneer** (Forever version)
- **TradeSkillMaster**

No such addon installed? Choose **RecipeScan** in the settings and a button appears in the Auction House. It scans **only the Recipe category** (recipes and profession books) – no full scan, no competition with real Auction House addons. Prices are shared by all characters on the realm. RecipeScan is locked as soon as one of the addons above is installed.

On a fresh server, prices take a few scans to appear. Until then the window shows *no price* instead of a made-up number.

---

## Data

- **QuestieDB** provides recipes, vendors, positions, quest rewards and drops. RecipeManager reads it once at login.
- **Limited Supply** information, restock times and base vendor prices come from the CMaNGOS classic database.
- **Forever-only recipes** and changed vendors are **learned in game**: every vendor visit updates stock, prices and Limited Supply. `/rm export` creates a text with what your client has learned – please send it in so everyone benefits.

---

## Commands

| Command | Action |
|---|---|
| `/rm` | Open or close the window |
| `/rm arrow` | Arrow to the nearest relevant vendor |
| `/rm hide` | Hide the arrow |
| `/rm settings` | Open the settings |
| `/rm macro` | Put the RecipeManager macro on the cursor |
| `/rm export` | Export learned vendor data |

Minimap button: **click** = arrow to the nearest vendor, **Shift-click** = window, **right-click** = settings. The yellow dot means a relevant vendor in your current zone.

---

## Requirements

- WoW Forever
- **Questie with QuestieDB** (QuestieDB must be enabled; the Questie map and tracker are optional)
- Optional: Auctionator, Auctioneer or TradeSkillMaster for prices

## Languages

Works with all Latin-script game clients. Interface texts in English, German, French, Spanish, Italian and Portuguese.

## Known limitations

- Twinks are matched to recipes by name: open the profession window once on every character.
- Crafting profit is only shown where the reagents are known, i.e. for recipes one of your characters already has.
- Merchant's Favor recipes, a fishing water overview and twink recipe books are planned for a later version.

## Feedback

Bugs, wrong vendors or missing Limited Supply recipes: please open an issue on [GitHub](https://github.com/psappz/RecipeManager/issues) and include the output of `/rm export` where it helps.

## License

GPL-3.0. Provided as is, without warranty. Source: [github.com/psappz/RecipeManager](https://github.com/psappz/RecipeManager)
