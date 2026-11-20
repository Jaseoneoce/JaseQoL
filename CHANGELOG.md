# Changelog

JaseQoL is built with AI assistance: written with Claude Code (Anthropic), directed and tested in game by Jase.

## Unreleased

### New
- **Request mats from alts** - in your profession window, a side panel shows the selected recipe's reagents for N crafts (need / have / on your alts); **Request** asks your alts for what's missing. JaseQoL plans who sends what (fewest logins, alts parked in a bank town, bags before bank) and gives each alt a job in the new **Requests** tab: **Pull from bank** takes out exactly what's needed, **Send** mails exactly that to you. Right-click a requested item to keep some on each alt. The Requests tab opens by itself when you log in on an alt with a job. Works with the modern profession window (the panel sits on its left, starts from the game's craft count, and can be dragged and resized). Vendor-bought reagents (thread, dyes, vials, flux...) are shown as "vendor" and never requested; JaseQoL also learns what each vendor you visit sells. **Drill-down**: when nobody has enough of a reagent you can make (Bolt of Linen Cloth), it requests that recipe's reagents instead (Linen Cloth), up to three levels down; recipes are learned when you open a profession window.
- **Resizable profession window** - drag the grip in the profession window's bottom-right corner to make it bigger; it stays that size. Right-click the grip to reset.
- **Party check** in the Dungeon Journal's Quests tab: party names on each quest coloured by status (done / in log / not started), and where each member is in a quest chain ("<- Bob" on the step they're at). Party members who run JaseQoL share done and chain progress; for others the game tells whether it's in their log. Checks by itself when you open Quests in a group, or press Party check.

### Changed
- Dungeon Journal quest details are coloured by kind: items you need (orange), start-from items (gold), items given and rewards (green), notes (yellow), start / turn-in places (blue), optional quests (purple).
- Alt tracking remembers where each character is parked and learns which towns have a bank.

### Fixed
- A Lua error at login ("AltData.lua:64: table index is nil") when the game reports your skills before it knows your character's name.
- "JaseQoL has been blocked from an action only available to the Blizzard UI": the keep-amount box no longer uses the game's popup system, and the Dungeon Journal swap waits until you're out of combat.

## v1.1.1 - 2026-11-19

### Changed
- A fresh addon description in the AddOns list and in WowUp, covering every tweak.
- Release notes now come from this changelog, so WowUp's Changelog tab shows what's new in each update.
- JaseQoL now says plainly that it's built with AI assistance (Claude Code), in its addon info, README and changelog.

## v1.1.0 - 2026-11-19

### New
- **Alt tracking** - remembers each character's professions and what's in their bags, bank and mailbox (bank and mail are read when you open them).
- **Alt counts on item tooltips** - item tooltips list which of your characters on this realm have the item: bags, bank, mail and a total.
- **Alt inventory** (`/jinv`) - every item on all your characters on this realm, with search and per-character / bags / bank / mail filters.
- **Send mats to bank alts** (`/jmats`) - assign materials to professions (or "Bank"); alts get the categories of the professions they have, switchable per alt. At the mailbox, pick an alt and press **Send mats**: every unbound stack for them is mailed, 12 per mail.
- **All BoE gear** option per profession - unbound Bind on Equip weapons and armour go along too; on for Enchanting by default.
- **JaseQoL window** - Inventory, Send mats and Settings as tabs in one window, opened from a **J button you can drag anywhere** or the minimap's addon menu.
- **Settings tab** - every tweak with an On/Off switch, a one-line description and a tooltip; a Reload UI button when a switch needs one. `/jq` or right-click the J button.
- **Warn when selling BoE items** - a big warning when a Bind on Equip item is sold to a vendor, so it can be bought back.
- **Mastercraft skin** - Mastercraft in the EllesmereUI style: EUI window frames, neutral panels, your accent and font (on Mastercraft's flat Classic look).
- **GuildOS skin** - GuildOS in the EllesmereUI style: neutral dark windows, your accent instead of its gold, your font (on GuildOS's flat style).

### Changed
- Characters show as **first name + last initial** ("Jaseone B."); mail goes to the full WoW Forever name. Last names come from your own logins or EllesmereUI's records.
- The Send mats panel steps past an open letter and EllesmereUI's alt list, and moves to the left when there's no room.
- Send mats messages wrap onto two lines and also print in chat.

## v1.0.2 - 2026-11-19

### Changed
- A full-size J image for the GitHub profile picture (WowUp shows it next to the addon). No in-game changes.

## v1.0.1 - 2026-11-19

### New
- The **J icon** in the AddOns list.

## v1.0.0 - 2026-11-19

### New
- **XP level colour** - unit frame and nameplate level text coloured by whether the mob gives XP: red, orange, yellow, green, grey (grey = no XP).
- **Dungeon Journal skin** - the Dungeon Journal window in the EllesmereUI style.
- **Dungeon Journal: new view** (`/jdj`) - a list-based journal: dungeon list, bosses, a loot grid with filters, quests with status, chains, needed items, summon chains, Show on map / Show turn-in, Share and Track. Classic view is one click away.
- Every tweak has its own on/off switch (Options > AddOns > JaseQoL, EllesmereUI options, `/jq`).
