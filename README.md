# JaseQoL

Small quality-of-life tweaks for **WoW Forever**, each with its own on/off switch.

| Tweak | What it does | Needs |
|---|---|---|
| **XP Level Colour** | Colours unit frame and nameplate level text by whether the mob gives XP: red, orange, yellow, green, grey (grey = no XP), using the classic grey-level formula. | EllesmereUI ("Level Text: Difficulty Color" on) |
| **Dungeon Journal Skin** | Skins the Dungeon Journal window in the EllesmereUI style through EllesmereUI's skinning API. | EllesmereUI Blizzard Skins+, Dungeon Journal |
| **Dungeon Journal: new view** | A cleaner, list-based Dungeon Journal: dungeon list with quest progress, bosses, a loot grid with filters (usable by me, hide owned), quests with status, live progress, quest chains, needed items, summon chains, Show on map / Show turn-in, Share and Track. The original window is one click away (Classic view). | Dungeon Journal |

## Switching tweaks on and off

- **Game menu → Options → AddOns → JaseQoL**
- **EllesmereUI options → JaseQoL** (when EllesmereUI is installed)
- `/jq` opens the options, `/jq list` lists the tweaks, `/jq <key>` toggles one (`xpLevelColor`, `djSkin`, `djOverhaul`)
- `/jdj` opens the new Dungeon Journal view

Every dependency is optional: a tweak whose addon is missing simply does nothing.

## Install

Copy the `JaseQoL` folder into `World of Warcraft\_forever_\Interface\AddOns\`, or install it from CurseForge.
