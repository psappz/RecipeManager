# RecipeManager

Recipe vendor companion for **WoW Forever**. RecipeManager warns you when you get close to a vendor that sells a recipe worth your attention, flags **Limited Supply** recipes ("buy now!") and shows what a recipe itself sells for on the Auction House.

**Requires Questie (QuestieDB).** QuestieDB must be installed and enabled; the Questie map and tracker are optional.

## Features (v0.1)

- **Proximity warning** in raid-warning style when a relevant recipe vendor is within the warning distance (default 1000 yd). Checked every 5 seconds, immediately after zone changes, ports and flights. Nothing is shown in combat, in instances or on a flight path.
- **Limited Supply**: warning near the vendor and a loud "BUY NOW" with sound and a highlight in the merchant window when the recipe is in stock. BoE recipes always, BoP recipes when the character can learn them (also when only the skill is missing).
- **Arrow** to the vendor: click targets the vendor, Ctrl+drag moves the arrow, dragging it onto an action bar places the **RecipeManager macro** (one macro that is rewritten for the current vendor). The tooltip shows the recipe details.
- **Hot** tab: resale of vendor recipes – vendor price, AH price (after the 5 % cut), margin, scan age. Hot = AH price > 2× vendor price (confirmed in at least two snapshots), gold coin = very lucrative (≥ 4× vendor price, configurable).
- **Vendor recipes** tab: filter by profession and rank, "only vendors within 300 yd/m"; without the radius filter also quest and drop recipes. Columns for AH price of the recipe, margin, AH price of the product and crafting profit (where reagents are known).
- **Focus / Settings**: focus professions (incl. secondary professions), warning options, price source, twinks of the same realm and faction (count for BoE recipes), muted vendors.
- **Prices** from Auctionator, Auctioneer (Forever) or TradeSkillMaster. Without any of them: **RecipeScan**, an own scan of the Recipe category only (button in the auction house, only when chosen in the settings).

Slash commands: `/rm`, `/rm arrow`, `/rm hide`, `/rm settings`, `/rm macro`, `/rm export`.

## Data sources

- **QuestieDB** (GPL-3.0): recipe items, vendors, spawn points, quests, drops – read at runtime.
- **CMaNGOS classic-db** (GPL-3.0): `Data/LimitedSupply.lua` (Limited Supply per vendor with restock time) and `Data/VendorPrices.lua` (base vendor prices).
- `Data/RecipeProducts.lua`: recipe → crafted item, derived from QuestieDB by name.
- **In game**: every merchant visit updates stock, prices and Limited Supply; Forever-only recipes are learned this way. `/rm export` produces a text you can send to the project.

## Languages

All Latin-script game clients. UI texts: English, German, French, Spanish, Italian, Portuguese.

## License

GPL-3.0 – see [LICENSE](LICENSE). Provided as is, without warranty. Third-party libraries in `Libs/` keep their own licenses (LibStub public domain, CallbackHandler-1.0 / LibDataBroker-1.1 / LibDBIcon-1.0 BSD-style).
