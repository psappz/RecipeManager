# Changelog

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
