# JaseQoL

<img src="Media/icon-preview.png" width="96" alt="JaseQoL icon">

Small quality-of-life tweaks for **WoW Forever**, each with its own on/off switch.

| Tweak | What it does | Needs |
|---|---|---|
| **XP Level Colour** | Colours unit frame and nameplate level text by whether the mob gives XP: red, orange, yellow, green, grey (grey = no XP), using the classic grey-level formula. | EllesmereUI ("Level Text: Difficulty Color" on) |
| **Dungeon Journal Skin** | Skins the Dungeon Journal window in the EllesmereUI style through EllesmereUI's skinning API. | EllesmereUI Blizzard Skins+, Dungeon Journal |
| **Dungeon Journal: new view** | A cleaner, list-based Dungeon Journal: dungeon list with quest progress, bosses, a loot grid with filters (usable by me, hide owned), quests with status, live progress, quest chains, needed items, summon chains, Show on map / Show turn-in, Share and Track. The original window is one click away (Classic view). | Dungeon Journal |
| **Alt tracking** | Remembers each character's professions and what's in their bags, bank and mailbox (bank and mail are read when you open them). | |
| **Alt counts on item tooltips** | Item tooltips list which of your characters on this realm have the item: bags, bank, mail and total. | Alt tracking |
| **Alt inventory window** | `/jinv`: every item on all your characters on this realm, with search and per-character / bags / bank / mail filters. | Alt tracking |
| **Send mats to bank alts** | `/jmats`: assign materials to professions (or "Bank"); alts get the categories of the professions they have, and you can switch any on or off per alt. At the mailbox, pick an alt and press **Send mats**: every unbound stack for them is mailed, 12 per mail. | Alt tracking |
| **Warn when selling BoE items** | Selling a Bind on Equip item to a vendor shows a big warning so you can buy it back. For a BoE label on bag slots, use EllesmereUI > Bags > Show BoE / Warbound Text. | |

## Switching tweaks on and off

- **Game menu → Options → AddOns → JaseQoL**
- **EllesmereUI options → JaseQoL** (when EllesmereUI is installed)
- `/jq` opens the options, `/jq list` lists the tweaks, `/jq <key>` toggles one (`xpLevelColor`, `djSkin`, `djOverhaul`, `altTracker`, `altTooltip`, `altInventory`, `bankMail`, `boeGuard`)
- `/jdj` opens the new Dungeon Journal view

Every dependency is optional: a tweak whose addon is missing simply does nothing.

## Install

Copy the `JaseQoL` folder into `World of Warcraft\_forever_\Interface\AddOns\`, or install it from CurseForge.
