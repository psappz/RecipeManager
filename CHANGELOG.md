# Changelog

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
