# Changelog

## 1.5.4

### New
- The vendor warning names hot Limited Supply recipes with the margin expected now (up to two, the best first), e.g. "HOT Limited Supply: Pattern: Mooncloth Boots (~30g)".
- "BUY NOW" also says when the recipe is hot and which margin to expect.
- Merchant window: Limited Supply recipes are tinted and framed, orange while in stock, grey when sold out.
- Merchant window: bind-on-pickup recipes of a profession your character does not have are marked red, and RecipeManager asks before you buy one.
- **Automatic purchase** (settings, off by default): watched Limited Supply recipes are bought at the vendor as soon as they are in stock, up to a maximum price (gold) and a maximum quantity per recipe and vendor visit. Every purchase is reported in the chat. Bind-on-pickup recipes of professions your character lacks are never bought automatically.

## 1.5.3

### Fixed
- Characters are stored with first name and surname. Two characters with the same first name (e.g. "Monaco Stenz" and "Monaco Bank") overwrote each other's professions and twink settings. The old entry is taken over by the character it belongs to (same level and class), otherwise it is recorded again on the next login.

## 1.5.2

- In-game addon list: the addon now has a category, so it is grouped with similar addons (translated into the six interface languages). The copilot only accepts real frames as the profession window.

## 1.5.1

### Fixed
- Error "Database.lua:115: attempt to call a nil value" at login, which left RecipeManager inactive: another addon used the global name ItemDB. RecipeManager now takes the QuestieDB tables from LibQuestieDB and only falls back to the globals when they really are QuestieDB's.

## 1.5.0

### New
- **Profession copilot**: the "RecipeManager Copilot" button above the profession window shows a panel beside it with every recipe of that profession, sorted by the skill needed to learn it. Click the button again to hide it.
  - Colour square and skill number show what the recipe is for you now: red (not learnable yet), orange, yellow, green, grey. An estimated learn level is shown as "~".
  - Source in colour: trainer (blue), vendor (gold), drop and world drop (purple), quest (white), world event (orange).
  - Click a colour in the legend to hide or show those recipes, e.g. no grey ones. Learned recipes only with "show learned".
  - Click a recipe for a detail box: skill-up levels, source (trainer and cost, nearest vendor with distance and price, drops, event), reagents with what you have, crafting margin (materials against the product's AH price after the AH cut), resale margin of BoE recipes, and buttons to open it in RecipeManager or show the way. Click it again to close.
- **Warn only for recipes I can learn** (settings, off by default): warnings only for recipes the character can learn now or within +x skill points (default 10). A BoE recipe for a twink counts with the twink's skill.
- **Event recipes**: recipes and vendors of world events (Feast of Winter Veil, Lunar Festival, Pilgrim's Bounty) no longer trigger warnings and are left out of the Hot and vendor lists while the event is not running (e.g. Seersa Copperpinch). The game calendar decides, the usual event dates are the fallback. Recipe details show "only during ...".
- **No Season of Discovery recipes**: SoD recipes that the Forever client and QuestieDB still carry are hidden in the copilot, the lists and the warnings.

### Data
- Trainer recipes with required skill and cost from CMaNGOS classic-db (GPL-2.0).
- Skill-up levels of Classic recipes from Skillet-Classic (GPL-3.0).
- SoD recipe list from AtlasLootClassic_Crafting (GPL-2.0).
- The data collector also records which recipe data the client offers, to close the gaps for Forever's own recipes.

## 1.4.1

### New
- **Loot recipes** in the Recipes tab (BoE only for now): three new sources in the filter menu – **Loot: creature**, **Loot: chest or container** and **World drop**.
  - The list shows the creature with its zone (plus how many more drop it), the chest or container, or "World drop (level 26-39)".
  - The detail panel lists the best creatures, chests and containers with drop chance and, for world drops, the creature level range.
  - World drops were missing completely before, recipes from chests and containers too.
- Data from the CMaNGOS classic database; drop chances are Classic values and may differ in WoW Forever.

## 1.4.0

### New
- **Recipes tab** (was "Vendor recipes"):
  - **Search** across recipe, crafted item, reagents, vendor and zone; matches are highlighted or named next to the recipe.
  - **Filter menu**: profession (with "My characters"), rank, source (vendor, quest, drop), status (not learned, Limited Supply, hot, watchlist) and the distance filter.
  - **Active filters as chips**, click to remove, "reset all".
  - **Saved searches**: store search text and filters, apply with one click, right-click deletes.
  - **Watchlist**: star per recipe; a notice appears when a watched Limited Supply recipe was seen in stock (by you or your guild).
  - **Detail panel**: reagents with price (vendor or AH, cheaper one) and owned count, material cost, crafting profit; all vendors with distance or "other faction", Limited Supply restock; AH price, margin, sales; which of your characters know the recipe, can learn it or need how many more points.
  - New column: profession.
- **Share data** (settings or `/rm share`): copyable text with what the collector recorded, a step-by-step guide and the link to the GitHub form. Split into parts if too long for one issue.
- Reagents of not-yet-learned recipes come from the collector once you open the profession window.

## 1.3.5

### New
- **Data collector:** trainer windows (all entries, including ones you cannot learn yet: cost, skill and level requirement) and profession windows (skill-up colour at your skill, reagents) are recorded locally. RecipeManager reports in chat when a trainer is new or its offer has changed. `/rm data` shows what has been collected and, for the current zone, which profession trainers are recorded and which are still missing. This data verifies the base data for the upcoming skill planner.

## 1.3.4

### New
- **Minimum margin for hot recipes:** a recipe only counts as hot (and very lucrative) if the AH price after fees is at least this much above the vendor price. Default 50 silver, adjustable in the settings next to the warning distance.

### Fixed
- **Recipes without a name** ("item 12239") in the Hot and Vendor recipes tabs, the arrow tooltip and the Limited Supply warning: until the game client knows an item, the name comes from QuestieDB, and missing names are requested again a few times.
- **Minimap icon:** RecipeManager has its own icon in the style of the Manager family. The previous Blizzard icon does not exist in the Forever client.

## 1.3.3

### New
- **Sortable tables** in the Hot and Vendor recipes tabs: click a column header to sort ascending, click again for descending. Gold, silver and copper sort by value; empty values ("-", "no price") always go last.
- **Tooltips on every column header** explaining the column.

## 1.3.2

### Look
- The version number is shown at the bottom of the main window.

## 1.3.1

### New
- **Limited Supply sightings in the guild:** with guild sharing on, a vendor visit tells guild members which Limited Supply recipes are in stock; the detail panel shows the latest guild sighting.
- **Manager family bar** in the settings is clickable: opens the other installed Manager addons.

## 1.3.0

### New
- **Real sales instead of listings.** A listing only shows that an auction existed, not that it sold. With **Journalator** installed (it records your own sold and expired auctions from the mailbox), RecipeManager shows per recipe how many of your auctions sold, the price actually achieved and the expected profit per listing. Hot recipes with real sales rank first, by expected profit; recipes without sales follow by listed margin.
- **Buy suggestion:** how many to buy at the vendor, from the sell-through rate and the expected profit.
- **Guild sales (opt-in, off by default):** RecipeManager users in a guild can share their own sales counts, so everyone sees real sales of the whole guild – data that exists nowhere else for Forever.
- Distances are labeled in meters for all client languages except English (until you pick a unit yourself). As in the game, 1 yard = 1 meter: only the label changes, not the value.
- Fixed: "only vendors within" overlapped its input field in longer languages.
- New columns "Sold for" and "Evidence" in the Hot tab (the scan age column moved out); evidence also in the recipe tooltip and the detail panel.

## 1.2.1

### New
- **Recipe info in item tooltips** (bags, auction house, vendor): who can learn it, nearest vendor with price, Limited Supply, margin. AH prices stay with your AH addon's tooltip.
- **Auctionator shopping list** with the reagents of a recipe's product (detail panel; reagents are known once the profession window was open).
- **Syndicator:** "already owned" by one of your characters (bags, bank, mail); no proximity warning for BoE recipes you already own (option).
- **TomTom** arrow instead of the own arrow (option, off by default; the target macro keeps working).
- **Post to guild:** a recipe with vendor, prices and Limited Supply.
- Manager family line in the settings.

### Changed
- Merchant's Favor recipes stay out of RecipeManager: dedicated addons such as FavorCraft cover them.

### Look
- Own flat buttons, checkboxes, input fields and close button instead of Blizzard's templates (also the RecipeScan button in the auction house); buttons grow with their (translated) text.

## 0.1.2

- Fix: Database.lua stopped loading at an event that does not exist in the Forever client (NEW_RECIPE_LEARNED). Profession names and ranks were missing, the window and settings failed to open. Unknown events are now skipped.

## 0.1.1

- Profession names: safe fallback when the client cannot provide them
- A window that fails to build is no longer left half-created

## 0.1.0 (unreleased)

First version for WoW Forever, not yet tested in the live client.

- Proximity warning (raid-warning style), 5 s check, minimap dot for vendors in the zone
- Limited Supply warning and "BUY NOW" alarm with merchant highlight (data from CMaNGOS + learned in game)
- Arrow to the vendor with target click, Ctrl+drag, macro drag-and-drop
- Tabs: Hot, Vendor recipes, Focus / Settings with twinks
- Price sources: Auctionator, Auctioneer, TSM; RecipeScan when none is installed
- UI in English, German, French, Spanish, Italian, Portuguese
