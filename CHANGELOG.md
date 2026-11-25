# Changelog

JaseTools (formerly JaseQoL) is built with AI assistance: written with Claude Code (Anthropic), directed and tested in game by Jase.

## v1.12.0 - 2026-11-25

### New
- **Professions: one window** (off by default: `/jq profView`) - opening one of your own professions shows a single JaseTools window instead of the game's. Left: your recipes, grouped as the game groups them, coloured by skill-up chance, with how many you can make, search, and **Can make** / **Skill ups** filters. Middle: the recipe you picked, with its materials for any number of crafts (need / have / alts, and where each comes from), **Make**, **Make all** and **Plan mats**. Right: your request plan, docked there with all its buttons, and Mastercraft's mini guide under it (**Show / hide**). Buttons along the top switch to your other professions. **Classic view** opens the game's own window; other people's professions always use it. `/jprof` reopens the JaseTools window.
- **Gold in the Professions window** - every recipe in the list shows what one craft costs in materials; hover it for what the result sells for and the profit or loss. For the picked recipe each material shows its cost: bought on the auction house, or made yourself from its own materials when that is cheaper (hover a material to compare the two). Under it: the total for the crafts you typed, what is still to buy after your own stock and your alts, and the profit or loss. Prices come from your last Mastercraft or Auctionator scan; vendor goods are not counted.
- **Dungeon Journal view: what was missing** - quests now show their **Rewards** (items, "choose one", XP, money and reputation) for nearly every quest, the reputation a quest needs and where you stand, a **Leads to** line that opens the follow-up quest, what a follow-up offers later, which chain steps are done inside the dungeon, and tags for repeatable, profession-only and attunement quests. Quests that are not available (not in WoW Forever, not for your race) are greyed with the reason and no longer counted. Bosses show the journal's own labels (Paladin Mount Quest Boss, 0.5 Quest Event), optional and grouped bosses, the note under their name, their quest, and loot chests. Loot shows random enchantments, extremely rare drops, what two drops combine into, proper trash sources, the journal's item tips in the tooltip, pinned drops first and a section for probable drops.

### Changed
- **Click to make opens the profession** - the plan's make step now opens the profession that makes the item by itself (after that profession has been opened once), then a second click makes it.
- **Dungeon Journal view: quest counts** - repeatable and unavailable quests are left out of "x of y quests".

## v1.11.0 - 2026-11-25

### New
- **Plan mats in Mastercraft** - the step shown in Mastercraft > Professions gets a **Plan mats** button on its NEEDS tile. One click plans everything the step still needs: a bank run for what's in your own bank or mail, a request to your alts for the rest, and the buy list (an Auctionator shopping list when Auctionator is installed) for what nobody has. Hover it to see where each material will come from. Clicking it again plans the step afresh. Has its own switch (`/jq mcRequest`).
- **Bank runs** - what a plan needs from the requesting character's own bank or mail is now a step of its own, with a **Take from bank** button that moves exactly the planned amounts into your bags in one press. The profession window's Request button plans it too.
- **Make what's missing** - when nobody has enough of something you can smelt or craft, the plan gathers what it's made from and adds a **make** step: for example bars from the ore in your bank. Click the make row (or the **Make** button) to craft it in the open profession window; for bars the Smelting window is opened for you. Smelting is known without opening the window first.
- **Take from mail** - a button that takes just the plan's items out of your mailbox, one attachment at a time. Mail with a COD is left alone.
- **Auto ticks on plan steps** - every bank, mail and send line in the request plan has an **auto** tick. Ticked, that kind of step does itself when you open the bank or mailbox: takes from the bank, takes from the mail, sends the mail (once everything is in your bags). One tick per kind of step, for all characters; off by default.
- **Crafting progress bar** - while you craft a batch in a profession window, however it was started, a bar shows the whole batch: a tick for every craft, how many are done and the time left. Drag it to move it. With EllesmereUI it is an Unlock Mode element (JaseTools > Crafting Progress) that you can move, resize and size-match like the XP bar. Has its own switch (`/jq craftProgress`).
- **Cancel plan** - the Requests tab starts with what your plan is for and a **Cancel plan** button that drops all of it.

### Changed
- **Request plan button** - the popout's button now offers whatever can be done where you are: Take from bank at a bank, Take from mail or Send at a mailbox, Make once everything is fetched.

## v1.10.0 - 2026-11-25

### New
- **Fill crate button** - the Requests tab has a **Fill crate** button (top right) whenever a waylaid crate can be filled from what's in your bags. Each click fills the next one; the button says how many are left. Crates that still need something from your bank, mail, a craft or an alt are left alone until the items are in your bags.
- **Request plan: items with tooltips** - every item in a step is its own row with its icon and where it is (take from bank, take out of your mail, in bags). Hover a row for the item's tooltip; shift-click links it in chat. Items no alt has are rows too.

### Changed
- **Request plan finishes when the mail is collected** - once everything has been sent and none of it is left in your mailbox, the plan closes by itself and chat says so. While it waits there's a **Done** button to finish it by hand.
- **Logging in with a job shows only the request plan** - the full Requests tab no longer opens at login while the popout is on (it still does if you switch the popout off). Opening a bank or mailbox with a job still opens it.

### Fixed
- **Request plan stayed up after collecting the mail** - a plan with everything sent could stay listed after its mail had been taken.

## v1.9.1 - 2026-11-25

### Changed
- **Request plan: each step broken down** - under every step the popout now names the items and where they are: what to take from the bank, what to take out of the mail, what is already in bags, and how many to send to whom. Long lists wrap onto the next line instead of being cut off, an alt that isn't parked near a bank says so, and the "No alt has" line names up to six items.
- **Request plan: Details opens and closes** - the **Details** button closes the Requests tab when it's already open, instead of only opening it.

### Fixed
- **Request plan: the close button** showed ".." instead of an x.

## v1.9.0 - 2026-11-25

### New
- **Request plan popout** - while a request for mats is open, a small **Request plan** box shows on every character with the plan step by step: who has already sent (ticked, with how many), who is next and where they are parked, and this character's own step with its **Pull from bank** / **Send** button. Progress is remembered across characters. Drag it to move it; **x** hides it until you log in again or make a new request; **Details** opens the Requests tab. Has its own switch (`/jq requestMini`).

### Changed
- **Requests: the last step is collecting the mail** - once every alt has sent, the request stays as "collect the mail" until the character who asked has been to a mailbox, instead of disappearing when the last mail goes out.

## v1.8.1 - 2026-11-23

### Fixed
- **Settings: every group always shows** - the list down the left of the Settings tab always has all nine groups (Exploring included), even if a group's switches didn't load; such a group says to quit the game fully and start it again. In a short window the groups get shorter so none falls off the bottom.

## v1.8.0 - 2026-11-23

### New
- **Send mats: recipes go to the right alt** - every unbound recipe in your bags (patterns, plans, schematics, formulas and the like) is now sent to the alts with the profession it teaches, without adding each one in `/jmats`. On by default for Leatherworking, Tailoring, Engineering, Blacksmithing, Cooking, Alchemy, First Aid, Enchanting and Fishing; each has a **Recipes: on/off** button in `/jmats` beside the BoE gear one. It doesn't check whether the alt already knows the recipe.

## v1.7.0 - 2026-11-23

### New
- **Explore challenge waypoints** - in Legacy Challenges (Adventure > Eastern Kingdoms / Kalimdor), every place of an Explore challenge you haven't found yet shows its coordinates as a button where the tick would be. Click it for a TomTom waypoint and the world map opened on the zone, with the ground that explores the place outlined and filled in pink; shift-click for every place still missing in that challenge, ctrl-click for the waypoint only, right-click to clear. Places drop off as you explore them. Works without TomTom too (no arrow, the map shows where to go).
- **Show this zone's places on the map** and **Show every zone's places on the map** - two switches (off by default, also in OpenMap's menu under JaseTools) that draw every place still to explore in pink on the world map, OpenMap's or the game's own: for the zone the map shows and the one you're in, or for all of Eastern Kingdoms and Kalimdor at once. `/jq exploreShowZone`, `/jq exploreShowAll`.
- Where to stand for each place comes from OpenMap's exploration data (OpenMap contributors, MIT).

## v1.6.0 - 2026-11-22

### New
- **Error log** - every JaseTools error is now recorded, even the ones it catches quietly so the game's own windows keep working: what went wrong, where, how often and when. `/jq errors` shows it in a window you can copy from (to send to Jase); `/jq errors clear` empties it. Errors from JaseTools that reach the game, and actions the game blocked because of JaseTools, are logged too - the game and BugSack still see everything. Chat says so the first time an error turns up in a session ("Tell me about JaseTools errors", in the new Troubleshooting group with the AH debug log).

## v1.5.4 - 2026-11-22

### Fixed
- **"FontString:SetText(): Font not set" errors** with the game's default bags and loot window (no EllesmereUI): the QST quest-item tag set its text before it had a font. It now starts with one. The tag also runs inside the bags' and loot window's own refresh, where anything going wrong broke them, so it can no longer throw into that code, only accepts item IDs and links, and keeps its data in JaseTools instead of on the game's bag buttons.

## v1.5.3 - 2026-11-22

### Fixed
- **Escorts could still be auto-accepted** (Suntara Stones was): EllesmereUI's auto-accept can run before the quest page is on screen, and the guard only looked once it was. It now checks the quest being offered straight away.
- Escorts whose text doesn't say so are covered too: Suntara Stones is known, and any quest you accept whose objectives read like an escort is learned - never auto-accepted again on any of your characters, and your group still gets the warning. `/jq escort` still marks any by hand.

## v1.5.2 - 2026-11-22

### Changed
- **Send mats: who gets each profession, at a glance** - the profession list has a "Who gets it" column ("Po T.", "Po T. +1" or "nobody"); click it for a dropdown of your characters with a tick each (and their skill) to switch them. Replaces the bar at the bottom of the window.
- **New Settings page** - groups down the left (Experience, Quests, Dungeon Journal, Alts, Selling & auction house, Professions, Skins, Buttons) with how many of their switches are on, the group's switches on the right with proper on/off switches, and a search box that finds any setting. Settings that need another one sit indented under it and grey out while it's off (e.g. XP breakdown and the missed-XP reminders under Experience in chat).

### Removed
- **Resizable profession window** - it made the window bigger but not what's inside it. The profession window is back to the game's own size after a reload.

## v1.5.1 - 2026-11-22

### New
- **XP chat switches** - "XP breakdown" off shows just the XP and the mob or quest ("XP +351 (Tar Lurker)"); "Missed XP: Well-Rested" and "Missed XP: Well Fed" turn each red missed-XP reminder off on its own.

### Fixed
- XP in chat missed your XP buffs on kills (it said "no Well-Rested" with 2 stacks up): the game hides buff details while you're in combat, when kill XP arrives. JaseTools now remembers your XP buffs whenever it can read them and uses that in combat, dropping any that have run out.
- The missed note shows the share too, with the breakdown in light orange: "missed 29 (8%) (no Well-Rested 3%: 11, no Well Fed 5%: 18)".

## v1.5.0 - 2026-11-22

### New
- **Cheapest way to finish a crate** - when your characters can't fill a waylaid crate, JaseTools prices the shortfall of every bundle off your last auction house scan (Mastercraft's, which knows how many are listed at each price, or Auctionator's, whichever is newer) and names the cheapest: e.g. "buy 12 Mithril Ore for 72s and make 12 Mithril Bar - plus 8 in your bank". It counts smelting when you can, and the crate tooltip says it too. With Auctionator, **Search AH** looks the items up for you.
- **Auctionator shopping list** - the Requests tab ends with "Buy on the auction house": everything the plan says to buy (each crate's cheapest shortfall, request items none of your alts have), with a **Shopping list** button that makes it an Auctionator shopping list called "JaseTools" (exact names and amounts; replaced each time). At the auction house Auctionator searches it straight away.
- **Experience in chat** - every XP gain gets a chat line (WoW Forever only shows kill XP floating over the mob): the mob or quest it came from, and the gain split into normal, rested (blue) and each XP buff (green: the 5% food buff, Well-Rested from the sleeping bag...), e.g. "XP +588 (Tar Lurker, 285 normal + 285 rested + 18 Well-Rested)". The game only reports the total, so the buff shares are worked out from the buffs' percentages (they multiply the whole kill, rested bonus included - checked against real kills). When a buff is missing it adds in red how much XP you missed and what share, with the breakdown in light orange, e.g. "missed 46 (8%) (no Well-Rested 3%: 17, no Well Fed 5%: 29)": Well Fed counts for kills only, Well-Rested (up to 3 stacks) for kills and quests.

## v1.4.0 - 2026-11-22

### New
- **Waylaid crates in the Requests tab** - every waylaid crate in your bags is listed with each of its bundles and whether your characters can fill it (counting your bags plus your alts' bags and banks). JaseTools picks the easiest bundle (fill it now from your bags, else the fewest alt logins) and shows who has it; **Request** asks your alts for the missing part and gives them the usual jobs (pull from bank, send). Two crates never count the same items.
- **Crates count smelting** - if you have Mining, ore counts as bars for a crate (Copper, Tin, Bronze, Silver, Iron, Gold, Steel, Mithril, Truesilver, Dark Iron, Thorium; plus any recipe JaseTools has seen in a profession window). Your own bars and ore come first, then alts' bars, then ore from alts sent to you to smelt; Steel says how much Coal to buy. If you can't smelt it, it says who can.
- **Crate tooltips** - hovering a waylaid crate says whether you can fill it and from where, e.g. "fill it now with 20 Mithril Bar: 8 in your bank, make 12 from 12 Mithril Ore".
- **Flag items your quests need** - items a quest in your log asks for that a vendor would also buy (like Scorpok Pincer) get a yellow "QST" tag on their bag slot, a "Needed for: <quest> (3/8)" line on their tooltip, and a big warning if you sell one, so you can buy it back. Stays on until you hand the quest in.
- **Quests category in EllesmereUI bags** - the All Items view gets a Quests category holding every quest item: pure quest items and anything a quest in your log needs (like Scorpok Pincer). It updates as you pick up and hand in quests. Items you assigned to a category yourself stay where you put them.

### Changed
- Request from alts and waylaid crates now count every character's **bags, bank and mailbox**, yours included. An alt's job says what to take out of their mail before pressing Send (the mailbox is used before the bank, since they're there to send anyway), and Pull from bank never takes more than the bank part.
- The QST tag uses the same font, size, outline and corner as EllesmereUI's own BoE / item level text.
- All JaseTools settings are now only on the JaseTools window's Settings tab (`/jq`, the J button or the minimap button). The JaseTools section is gone from EllesmereUI's options and from the game's Options > AddOns list.

### Fixed
- Waylaid crates ignored what was in your own bank (and mail), so a crate could say "have 0" while you had the bars.
- A crate you can't fill yet now names the bundle you're furthest along with as "closest" (and says how many you have), not just the one with the smallest shortfall.

## v1.3.1 - 2026-11-22

### New
- **Minimap button** - a round J button on the edge of the minimap: click for the JaseTools window, right-click for settings, drag it round the minimap to move it. Own toggle.

### Fixed
- The J button was invisible in v1.3.0 (its icon pointed at a folder that doesn't exist after the rename).
- Alts, Send mats and Requests looked empty when the game reported a blank realm name: JaseTools now uses your last real realm name instead, and moves anything filed under the blank one back. Nothing was lost.

## v1.3.0 - 2026-11-22

### New
- **Don't auto-accept escort quests** - accepting an escort starts it straight away, so when EllesmereUI's Quest Tracker auto-accepts quests, escort quests are now left open for you to accept when your group is ready (a chat line says why). Escorts are spotted by the game's Escort tag or the quest text; `/jq escort` marks the open quest as an escort, `/jq escort no` as not one. In a group, JaseTools also tells everyone: a whisper to each party member and a party chat message (raid chat in a raid), "Escort detected - do not auto-accept or auto hand in", once per quest every 10 minutes (toggle: Tell the group about escort quests).
- **Auction house debug log** (off by default) - `/jahlog on` records everything that happens at the auction house: each call and which addon made it, the server's replies, error messages and blocked actions, and a "NO REPLY" line (plus a chat note) when a post gets no answer within 10 seconds. `/jahlog` shows the latest lines, `/jahlog mark <note>` adds a note. Saved when you log out or `/reload`.
- **Copper price warning at the auction house** - WoW Forever's auction house won't post single items (gear, recipes, scrolls) when the price has copper in it: the sell window just hangs (Blizzard know, and suggest leaving copper out for now). Posting a single item with copper in its price now warns you to relist at whole silver. Stackable goods post fine with copper.
- **Lockpicking** is a Send mats category, for sending lockboxes to a rogue alt (alts with Lockpicking get it by default).

### Changed
- **JaseQoL is now JaseTools.** Every name you see says JaseTools (window, button, settings, chat lines start "JaseTools:"); `/jasetools` works alongside `/jq`. The addon folder, your saved settings and the GitHub address are unchanged, so nothing needs reinstalling.
- Dungeon Journal: reward items in a quest's Rewards line are item links - hover one for its tooltip, shift-click to link it in chat.
- Send mats: the Jewelcrafting and Inscription tabs are gone (neither is in WoW Forever).
- Send mats setup: items already assigned to another category show it after their name, e.g. "Jet Black Feather (Leatherworking)".

### Fixed
- Bank contents weren't read at all on WoW Forever (its bank is bank tabs): the alt inventory, item tooltips, Send mats and Requests now see what's in each character's bank. Open each bank once to record it.
- Two characters with the same first name (e.g. two Jaseones with different last names) overwrote each other: characters are now kept under their full name. Existing records, Send mats choices and requests are moved across at login. Log in on each once (and open their bank) to refresh them.
- The login job message no longer ends in a double full stop ("to Jaseone B..").

## v1.2.0 - 2026-11-20

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
