-------------------------------------------------------------------------------
--  JaseTools: Request mats from alts
--
--  1. Profession window (the game's own; Enchanting's craft window too): a
--     side panel shows the selected recipe's reagents for N crafts: how many
--     you need, have (bags + bank + incoming mail) and your alts hold.
--     "Request" asks your alts for the shortfall, for this character.
--  2. Plan: who sends what. Fewest logins first (alts that cover the most of
--     what's still needed), then alts parked in a town with a bank, then items
--     already in bags (no bank trip). Alts of the other faction can't mail you.
--  3. Requests tab (JaseTools window): your requests, the plan as an action list
--     ("Log in on Herbie S. - Ironforge / Bank: take ... / Mailbox: send to
--     ..."), and on a supplying alt its job with two buttons:
--       Pull from bank  - moves exactly what's needed from the bank to bags
--       Send            - mails exactly that to the requester (12 per mail)
--     It opens by itself when that alt opens a bank or mailbox.
--  Keep amounts: right-click a requested item to leave at least N on each alt.
--
--  JaseQoLDB.altRequest = { requests = {[realm] = {[recipient] =
--      {items = {[itemID] = {need = n, sent = n}}, recipes = {...}}}},
--    keep = {[itemID] = n}, win = {...} }
-------------------------------------------------------------------------------
local _, JQ = ...
local KEY = "altRequest"

JQ.AddModule({
    key = KEY,
    label = "Request mats from alts",
    description = "In your profession window, request a recipe's missing reagents from your alts. JaseTools plans who sends what (fewest logins, alts parked in bank towns, bags before bank) and gives each alt a job with Pull from bank and Send buttons. Requests tab in the JaseTools window. Needs Alt tracking.",
    default = true,
})

local UI = JQ.UI
local Alts, db
local C = C_Container
local MAX_ATTACH = ATTACHMENTS_MAX_SEND or 12
local mailOpen = false

-------------------------------------------------------------------------------
--  Counts
-------------------------------------------------------------------------------
local function NumSlots(bag) return (C and C.GetContainerNumSlots and C.GetContainerNumSlots(bag)) or 0 end
local function Info(bag, slot) return C and C.GetContainerItemInfo and C.GetContainerItemInfo(bag, slot) end

-- Live unbound counts in some containers.
local function Live(bagIDs)
    local t = {}
    for _, bag in ipairs(bagIDs) do
        for slot = 1, NumSlots(bag) do
            local i = Info(bag, slot)
            if i and i.itemID and not i.isBound then t[i.itemID] = (t[i.itemID] or 0) + (i.stackCount or 1) end
        end
    end
    return t
end

local function Keep(id) return (db.keep and db.keep[id]) or 0 end

-- bags / bank / mailbox counts for a character: bags (and an open bank) live
-- for me, the rest as last recorded.
local function Holdings(alt)
    local d = Alts.RealmTable()[alt] or {}
    if alt == Alts.MyName() then
        local bank = Alts.IsBankOpen() and Live(Alts.BankIDs()) or (d.bank or {})
        return Live(Alts.BagIDs()), bank, d.mail or {}
    end
    return d.bags or {}, d.bank or {}, d.mail or {}
end

-- How many of id this alt can give: total minus the keep amount. Bags first,
-- then the mailbox (they're at one to send anyway), then the bank.
-- Returns take, fromBags, fromBank, fromMail.
local function Give(bags, bank, id, want, mail)
    local b, m, k = bags[id] or 0, (mail and mail[id]) or 0, bank[id] or 0
    local take = math.min(want, math.max(0, b + m + k - Keep(id)))
    local fromBags = math.min(take, b)
    local fromMail = math.min(take - fromBags, m)
    return take, fromBags, take - fromBags - fromMail, fromMail
end

-------------------------------------------------------------------------------
--  Requests
-------------------------------------------------------------------------------
local function RealmRequests()
    local realm = Alts.Realm()
    db.requests[realm] = db.requests[realm] or {}
    return db.requests[realm]
end

local function RequestOf(recipient, create)
    local t = RealmRequests()
    if not t[recipient] and create then t[recipient] = { items = {}, recipes = {} } end
    return t[recipient]
end

-- {[id] = still needed} for a recipient
local IsVendor   -- forward (vendor list below): vendor items are never requested

local function Remaining(recipient)
    local r = RequestOf(recipient)
    local out = {}
    for id, e in pairs(r and r.items or {}) do
        local left = (e.need or 0) - (e.sent or 0)
        if left > 0 and not IsVendor(id) then out[id] = left end
    end
    return out
end

local function Tidy(recipient)
    local r = RequestOf(recipient)
    if not r then return end
    for id, e in pairs(r.items) do
        -- done, or something you buy from a vendor (requests made before that rule)
        if (e.need or 0) - (e.sent or 0) <= 0 or IsVendor(id) then r.items[id] = nil end
    end
    if not next(r.items) then RealmRequests()[recipient] = nil end
end

local function AddRequest(recipient, wants, label)
    local r = RequestOf(recipient, true)
    for id, n in pairs(wants) do
        if n > 0 and not IsVendor(id) then
            local e = r.items[id] or { need = 0, sent = 0 }
            e.need = e.need + n
            r.items[id] = e
        end
    end
    if label then table.insert(r.recipes, label) end
    if not next(r.items) then RealmRequests()[recipient] = nil end
end

-------------------------------------------------------------------------------
--  Planner
-------------------------------------------------------------------------------
-- steps = { {alt, items = {[id] = {bags = n, bank = n, mail = n}}, bankTown}, ... }, short = {[id] = n}
local function Plan(recipient)
    local rem = Remaining(recipient)
    if not next(rem) then return nil end
    local realm = Alts.RealmTable()
    local faction = realm[recipient] and realm[recipient].faction
    local cands = {}
    for name, data in pairs(realm) do
        if name ~= recipient and (not faction or not data.faction or data.faction == faction) then
            local bags, bank, mail = Holdings(name)
            cands[#cands + 1] = { name = name, bags = bags, bank = bank, mail = mail, town = Alts.InBankTown(name) }
        end
    end
    table.sort(cands, function(a, b) return a.name < b.name end)
    local steps, used = {}, {}
    while next(rem) do
        local best, bestScore
        for _, c in ipairs(cands) do
            if not used[c.name] then
                local cover, fromBags = 0, 0
                for id, want in pairs(rem) do
                    local take, fb, _, fm = Give(c.bags, c.bank, id, want, c.mail)
                    cover, fromBags = cover + take, fromBags + fb + fm
                end
                if cover > 0 then
                    -- fewest logins: most units first; bank towns and bag stock break ties
                    local score = cover * (c.town and 1 or 0.6) + fromBags * 0.05
                    if not bestScore or score > bestScore then best, bestScore = c, score end
                end
            end
        end
        if not best then break end
        used[best.name] = true
        local step = { alt = best.name, items = {}, town = best.town, needsBank = false }
        for id, want in pairs(rem) do
            local take, fb, fk, fm = Give(best.bags, best.bank, id, want, best.mail)
            if take > 0 then
                step.items[id] = { bags = fb, bank = fk, mail = fm }
                if fk > 0 then step.needsBank = true end
                rem[id] = want - take
                if rem[id] <= 0 then rem[id] = nil end
            end
        end
        steps[#steps + 1] = step
    end
    return steps, rem
end

-- This character's jobs: { {to = recipient, items = {[id] = {bags, bank, mail}}, needsBank}, ... }
local function MyJobs()
    local jobs = {}
    local me = Alts.MyName()
    for recipient in pairs(RealmRequests()) do
        if recipient ~= me then
            local steps = Plan(recipient)
            for _, s in ipairs(steps or {}) do
                if s.alt == me then
                    jobs[#jobs + 1] = { to = recipient, items = s.items, needsBank = s.needsBank }
                end
            end
        end
    end
    table.sort(jobs, function(a, b) return a.to < b.to end)
    return jobs
end

-------------------------------------------------------------------------------
--  Bank pull: exactly what the jobs need from the bank, into free bag slots
-------------------------------------------------------------------------------
local Status   -- forward (Requests tab status line + chat)

local function FreeBagSlots()
    local out = {}
    for _, bag in ipairs(Alts.BagIDs()) do
        for slot = 1, NumSlots(bag) do
            if not Info(bag, slot) then out[#out + 1] = { bag, slot } end
        end
    end
    return out
end

local function PullFromBank()
    if not Alts.IsBankOpen() then Status("Open your bank first.") return end
    if InCombatLockdown() then return end
    local want, fromBank = {}, {}
    for _, job in ipairs(MyJobs()) do
        for id, e in pairs(job.items) do
            want[id] = (want[id] or 0) + (e.bags or 0) + (e.bank or 0) + (e.mail or 0)
            fromBank[id] = (fromBank[id] or 0) + (e.bank or 0)
        end
    end
    local inBags = Live(Alts.BagIDs())
    local free = FreeBagSlots()
    local moved, short = 0, false
    ClearCursor()
    for id, total in pairs(want) do
        local pull = math.min(fromBank[id] or 0, total - (inBags[id] or 0))
        for _, bag in ipairs(Alts.BankIDs()) do
            if pull <= 0 then break end
            for slot = 1, NumSlots(bag) do
                if pull <= 0 then break end
                local i = Info(bag, slot)
                if i and i.itemID == id and not i.isBound and not i.isLocked then
                    local dest = table.remove(free, 1)
                    if not dest then short = true; break end
                    local n = i.stackCount or 1
                    if n <= pull then
                        C.PickupContainerItem(bag, slot)
                    else
                        C.SplitContainerItem(bag, slot, pull)
                        n = pull
                    end
                    C.PickupContainerItem(dest[1], dest[2])
                    ClearCursor()
                    pull, moved = pull - n, moved + 1
                end
            end
        end
    end
    if short then
        Status(("Bags full: moved %d stack(s). Make room and press Pull from bank again."):format(moved))
    elseif moved > 0 then
        Status(("Moved %d stack(s) from the bank. Now go to a mailbox and press Send."):format(moved))
    else
        Status("Nothing to take from the bank: it's all in your bags already.")
    end
end

-------------------------------------------------------------------------------
--  Sending: exact amounts, 12 attachments per mail, next mail on success
-------------------------------------------------------------------------------
local job   -- { to, left = {[id] = n}, batch, mails, sent }

local function FirstFree()
    for i = 1, MAX_ATTACH do
        if not HasSendMailItem(i) then return i end
    end
end

local SendNext
local function FinishSend(msg)
    job = nil
    Status(msg)
end

function SendNext()
    if not job then return end
    if not (MailFrame and MailFrame:IsShown()) then return FinishSend("Mailbox closed: stopped.") end
    if MailFrameTab2 and MailFrameTab2.Click and not (SendMailFrame and SendMailFrame:IsShown()) then MailFrameTab2:Click() end
    local attached, batch = 0, {}
    ClearCursor()
    for id, left in pairs(job.left) do
        if left > 0 then
            for _, bag in ipairs(Alts.BagIDs()) do
                for slot = 1, NumSlots(bag) do
                    if attached >= MAX_ATTACH or job.left[id] <= 0 then break end
                    local i = Info(bag, slot)
                    if i and i.itemID == id and not i.isBound and not i.isLocked then
                        local at = FirstFree()
                        if not at then break end
                        local n = i.stackCount or 1
                        if n <= job.left[id] then
                            C.PickupContainerItem(bag, slot)
                        else
                            C.SplitContainerItem(bag, slot, job.left[id])
                            n = job.left[id]
                        end
                        ClickSendMailItemButton(at)
                        ClearCursor()
                        attached = attached + 1
                        job.left[id] = job.left[id] - n
                        batch[id] = (batch[id] or 0) + n
                    end
                end
            end
        end
    end
    if attached == 0 then
        local done = job.mails
        local missing = 0
        for _, n in pairs(job.left) do missing = missing + math.max(0, n) end
        if missing > 0 then
            return FinishSend(("Sent %d mail(s). %d item(s) weren't in your bags - pull them from the bank or take them out of your mail first."):format(done, missing))
        end
        return FinishSend(("Done: %d mail(s) sent to %s"):format(done, Alts.Display(job.to)))
    end
    if (GetSendMailPrice and GetSendMailPrice() or 0) > GetMoney() then
        ClearSendMail()
        return FinishSend("Not enough money for postage.")
    end
    job.batch = batch
    job.mails = job.mails + 1
    Status(("Sending mail %d to %s..."):format(job.mails, Alts.Display(job.to)), true)
    SendMail(Alts.MailName(job.to), "Requested mats", "Sent by JaseTools (Request from alts)")
end

local function StartSend(recipient)
    if job then return end
    if not mailOpen then Status("Open a mailbox first.") return end
    if InCombatLockdown() then return end
    if not Alts.HasFullName(recipient) then pcall(Alts.LearnNames) end
    if not Alts.HasFullName(recipient) then
        Status("Mail needs " .. recipient .. "'s full name. Log in on " .. recipient .. " once so JaseTools learns it.")
        return
    end
    for i = 1, MAX_ATTACH do
        if HasSendMailItem(i) then Status("Clear the attachments already on the Send Mail page first.") return end
    end
    local left = {}
    for _, j in ipairs(MyJobs()) do
        if j.to == recipient then
            for id, e in pairs(j.items) do left[id] = (left[id] or 0) + (e.bags or 0) + (e.bank or 0) + (e.mail or 0) end
        end
    end
    if not next(left) then Status("Nothing to send to " .. Alts.Display(recipient)) return end
    job = { to = recipient, left = left, mails = 0 }
    SendNext()
end

local ev = CreateFrame("Frame")

-------------------------------------------------------------------------------
--  Requests tab
-------------------------------------------------------------------------------
local win
local ROW_H = 26

local function ItemText(id, n)
    local name, q = UI.ItemNameQuality(id)
    local r, g, b = UI.QualityColor(q)
    return ("%d |cff%02x%02x%02x%s|r"):format(n, r * 255, g * 255, b * 255, name)
end

local function NameOf(alt)
    local d = Alts.RealmTable()[alt]
    return ("|cff%s%s|r"):format(UI.ClassHex(d and d.class), Alts.Display(alt))
end

-------------------------------------------------------------------------------
--  Waylaid crates: a crate takes any ONE bundle from the list on its tooltip
--  ("Use: Fill the crate with any bundle from the following list:" then
--  "- 10 Golden Sansam" lines). For each crate in your bags JaseTools picks
--  the bundle your characters can fill most easily and can request it.
-------------------------------------------------------------------------------
local CRATE_MARK = "bundle from the following list"

-- tooltip text lines (split on line breaks) for a bag slot, or for raw lines
local scanTip
local function SlotLines(bag, slot)
    local out = {}
    if C_TooltipInfo and C_TooltipInfo.GetBagItem then
        local ok, data = pcall(C_TooltipInfo.GetBagItem, bag, slot)
        if ok and data and data.lines then
            for _, l in ipairs(data.lines) do
                if type(l.leftText) == "string" then out[#out + 1] = l.leftText end
            end
            return out
        end
    end
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "JaseQoLScanTip", nil, "GameTooltipTemplate")
    end
    scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanTip:SetBagItem(bag, slot)
    for i = 1, scanTip:NumLines() do
        local fs = _G["JaseQoLScanTipTextLeft" .. i]
        local t = fs and fs:GetText()
        if t then out[#out + 1] = t end
    end
    scanTip:Hide()
    return out
end

-- { {n = 10, name = "Golden Sansam"}, ... } from tooltip lines, or nil
local function ParseBundles(lines)
    local found, list = false, {}
    for _, text in ipairs(lines) do
        if type(text) == "string" then
            if text:find(CRATE_MARK, 1, true) then found = true end
            for part in (text .. "\n"):gmatch("(.-)\n") do
                local n, name = part:match("^%s*%-%s*(%d+)%s*x?%s+(.-)%s*$")
                if n and name ~= "" then list[#list + 1] = { n = tonumber(n), name = name } end
            end
        end
    end
    if found and #list > 0 then return list end
end

-- item name (lower case) -> item ID, from everything JaseTools has seen
local function NameIndex()
    local idx = {}
    for id, it in pairs(JaseQoLDB.items or {}) do
        if type(it) == "table" and type(it.n) == "string" then idx[it.n:lower()] = id end
    end
    return idx
end

-- Crates in my bags: { {bag, slot, id, name, bundles}, ... } (bundles cached per crate type)
local function MyCrates()
    db.crates = db.crates or {}
    local out = {}
    for _, bag in ipairs(Alts.BagIDs()) do
        for slot = 1, NumSlots(bag) do
            local i = Info(bag, slot)
            local id = i and i.itemID
            if id then
                local cached = db.crates[id]
                if cached == nil then
                    local name = ((C_Item and C_Item.GetItemInfo) or GetItemInfo)(id)
                    if name and name:find("Waylaid", 1, true) then
                        local bundles = ParseBundles(SlotLines(bag, slot))
                        if bundles then
                            cached = { name = name, bundles = bundles }
                            db.crates[id] = cached
                        end
                    elseif name then
                        db.crates[id] = false   -- not a crate
                    end
                end
                if cached then
                    for _ = 1, (i.stackCount or 1) do
                        out[#out + 1] = { bag = bag, slot = slot, id = id, name = cached.name, bundles = cached.bundles }
                    end
                end
            end
        end
    end
    return out
end

-- Smelting (Mining): bars from ore, known up front so a crate can count ore as
-- bars before you've opened the smelting window. Coal is bought from a vendor.
-- [bar] = { n = bars per smelt, r = {[reagent] = qty}, skill = Mining needed }
local SMELT = {
    [2840]  = { n = 1, r = { [2770] = 1 }, skill = 1 },                  -- Copper Bar <- Copper Ore
    [3576]  = { n = 1, r = { [2771] = 1 }, skill = 65 },                 -- Tin Bar <- Tin Ore
    [2841]  = { n = 2, r = { [2840] = 1, [3576] = 1 }, skill = 65 },     -- Bronze Bar x2 <- Copper Bar + Tin Bar
    [2842]  = { n = 1, r = { [2775] = 1 }, skill = 75 },                 -- Silver Bar <- Silver Ore
    [3575]  = { n = 1, r = { [2772] = 1 }, skill = 125 },                -- Iron Bar <- Iron Ore
    [3577]  = { n = 1, r = { [2776] = 1 }, skill = 155 },                -- Gold Bar <- Gold Ore
    [3859]  = { n = 1, r = { [3575] = 1, [3857] = 1 }, skill = 165, vendor = { [3857] = true } }, -- Steel Bar <- Iron Bar + Coal
    [3860]  = { n = 1, r = { [3858] = 1 }, skill = 175 },                -- Mithril Bar <- Mithril Ore
    [6037]  = { n = 1, r = { [7911] = 1 }, skill = 230 },                -- Truesilver Bar <- Truesilver Ore
    [11371] = { n = 1, r = { [11370] = 8 }, skill = 230 },               -- Dark Iron Bar <- 8 Dark Iron Ore
    [12359] = { n = 1, r = { [10620] = 1 }, skill = 250 },               -- Thorium Bar <- Thorium Ore
}

-- How id is made, whether I can make it, and who can.
-- Learned recipes (opened profession windows) first, then smelting.
local function MakeRecipe(id, me)
    local learned = JaseQoLDB.recipeIndex and JaseQoLDB.recipeIndex[id]
    if type(learned) == "table" and learned.r and next(learned.r) then
        local makers = {}
        for who in pairs(learned.by or {}) do makers[#makers + 1] = who end
        return { n = learned.n or 1, r = learned.r }, (learned.by or {})[me] and true or false, makers
    end
    local smelt = SMELT[id]
    if not smelt then return nil end
    local makers, mine = {}, false
    for name, data in pairs(Alts.RealmTable()) do
        local rank = data.profs and data.profs.Mining
        if rank and rank >= smelt.skill then
            makers[#makers + 1] = name
            if name == me then mine = true end
        end
    end
    return smelt, mine, makers
end

-- How a bundle can be filled. used = { bags = {[id] = n}, alts = {[id] = n} }:
-- what other crates and earlier requests already take from my bags / the alts.
-- Returns { id, n, mine, alts = {{alt, n}}, short, logins }.
local function Coverage(bundle, idx, used)
    local id = idx[bundle.name:lower()]
    local r = { name = bundle.name, n = bundle.n, id = id, mine = 0, alts = {}, short = bundle.n, logins = 99 }
    if not id then return r end
    local me = Alts.MyName()
    -- mine: my bags (live), my mailbox and my own bank (live while open, else as
    -- last seen); claims by other crates come off bags first, then mail, then bank
    local myBags, myBank, myMail = Holdings(me)
    local claimed = used.bags[id] or 0
    local function after(have) local t = math.min(have, claimed); claimed = claimed - t; return have - t end
    local inBags = after(myBags[id] or 0)
    local inMail = after(myMail[id] or 0)
    local inBank = after(myBank[id] or 0)
    local spoken = used.alts[id] or 0
    r.mine = math.min(inBags + inMail + inBank, bundle.n)
    r.fromMail = math.min(inMail, math.max(0, r.mine - inBags))
    r.fromBank = math.max(0, r.mine - inBags - r.fromMail)
    local left = bundle.n - r.mine
    local realm = Alts.RealmTable()
    local faction = realm[me] and realm[me].faction

    -- What can make this item (smelting ore into bars, or a learned recipe), and
    -- whether I can: then my own reagents come before anyone else's bars.
    local rec, canMake, makers = MakeRecipe(id, me)
    r.makers, r.rec, r.canMake = makers, rec, canMake
    local myReagents = {}
    if rec then
        for rid in pairs(rec.r) do
            local b, k, m = Holdings(me)
            local have = (b[rid] or 0) + (k[rid] or 0) + (m[rid] or 0) - (used.bags[rid] or 0)
            myReagents[rid] = math.max(0, have)
        end
    end
    local function CraftsFrom(avail)
        local c = math.huge
        for rid, q in pairs(rec.r) do
            if not (rec.vendor and rec.vendor[rid]) and not IsVendor(rid) then
                c = math.min(c, math.floor((avail[rid] or 0) / q))
            end
        end
        return c == math.huge and 0 or c
    end
    if left > 0 and rec and canMake then
        local crafts = math.min(math.ceil(left / rec.n), CraftsFrom(myReagents))
        if crafts > 0 then
            local bars = math.min(left, crafts * rec.n)
            r.make = { bars = bars, crafts = crafts, mine = {}, ask = {}, n = rec.n, r = rec.r, vendor = rec.vendor }
            for rid, q in pairs(rec.r) do r.make.mine[rid] = crafts * q end
            left = left - bars
        end
    end

    -- other characters' bars
    local offers = {}
    for name, data in pairs(realm) do
        if name ~= me and (not faction or not data.faction or data.faction == faction) then
            local bags, bank, mail = Holdings(name)
            local give = Give(bags, bank, id, math.huge, mail)
            if give > 0 then offers[#offers + 1] = { alt = name, n = give } end
        end
    end
    table.sort(offers, function(a, b) return a.n > b.n end)
    for _, o in ipairs(offers) do
        local avail = o.n
        if spoken > 0 then local s = math.min(spoken, avail); avail = avail - s; spoken = spoken - s end
        if left > 0 and avail > 0 then
            local take = math.min(left, avail)
            r.alts[#r.alts + 1] = { alt = o.alt, n = take, has = o.n }
            left = left - take
        end
    end

    -- still short: other characters' reagents, sent to me to make the rest
    local extraLogins = 0
    if left > 0 and rec and canMake then
        local crafts = math.ceil(left / rec.n)
        local ask, ok, who = {}, true, {}
        for rid, q in pairs(rec.r) do
            if not (rec.vendor and rec.vendor[rid]) and not IsVendor(rid) then
                local usedMine = r.make and r.make.mine[rid] or 0
                local need = crafts * q - math.max(0, (myReagents[rid] or 0) - usedMine)
                if need > 0 then
                    local got, spokenR = 0, used.alts[rid] or 0
                    for name, data in pairs(realm) do
                        if name ~= me and (not faction or not data.faction or data.faction == faction) then
                            local bags, bank, mail = Holdings(name)
                            local give = Give(bags, bank, rid, math.huge, mail)
                            local s = math.min(spokenR, give); give = give - s; spokenR = spokenR - s
                            if give > 0 and got < need then
                                got = got + give
                                who[name] = true
                            end
                        end
                    end
                    if got < need then ok = false end
                    ask[rid] = need
                end
            end
        end
        if ok then
            r.make = r.make or { bars = 0, crafts = 0, mine = {}, ask = {}, n = rec.n, r = rec.r, vendor = rec.vendor }
            r.make.bars = r.make.bars + left
            r.make.crafts = r.make.crafts + crafts
            for rid, n in pairs(ask) do r.make.ask[rid] = n end
            for rid, q in pairs(rec.r) do
                r.make.mine[rid] = math.min(myReagents[rid] or 0, (r.make.mine[rid] or 0) + crafts * q - (ask[rid] or 0))
            end
            for _ in pairs(who) do extraLogins = extraLogins + 1 end
            left = 0
        end
    end
    r.short = left
    r.logins = left > 0 and 99 or (#r.alts + extraLogins)
    return r
end

-- the easiest bundle: fillable by you now, else fewest alt logins; when none
-- can be filled, the one you're furthest along with (share of it you have)
local function Better(c, best)
    if not best then return true end
    if c.logins ~= best.logins then return c.logins < best.logins end
    if c.logins >= 99 then
        local fc, fb = (c.n - c.short) / c.n, (best.n - best.short) / best.n
        if fc ~= fb then return fc > fb end
        return c.short < best.short
    end
    if c.mine ~= best.mine then return c.mine > best.mine end
    return (c.fromBank or 0) < (best.fromBank or 0)
end

-------------------------------------------------------------------------------
--  Auction house prices, read from the last scan of Mastercraft (its saved
--  prices: listed price tiers, so it knows what buying 12 really costs) or
--  Auctionator (its public API: the lowest price only), whichever is newer.
-------------------------------------------------------------------------------
local function MastercraftEntry(id)
    local mdb = _G.MastercraftDB
    if type(mdb) ~= "table" or type(mdb.prices) ~= "table" then return nil end
    local faction = (UnitFactionGroup and UnitFactionGroup("player")) or ""
    local best
    for key, book in pairs(mdb.prices) do
        if type(key) == "string" and key:sub(-(#faction + 1)) == "-" .. faction
            and type(book) == "table" and type(book.items) == "table" then
            local e = book.items[id]
            if type(e) == "table" and type(e.p) == "number" and (not best or (e.t or 0) > (best.t or 0)) then best = e end
        end
    end
    return best
end

local function AuctionatorPrice(id)
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if not (api and api.GetAuctionPriceByItemID) then return nil end
    local ok, price = pcall(api.GetAuctionPriceByItemID, "JaseTools", id)
    if not (ok and type(price) == "number" and price > 0) then return nil end
    local age
    if api.GetAuctionAgeByItemID then
        local ok2, days = pcall(api.GetAuctionAgeByItemID, "JaseTools", id)
        if ok2 and type(days) == "number" then age = days end
    end
    return price, age
end

-- What buying qty of id costs now: cost, enough (false: fewer listed), source, age in days.
-- nil when no scan has a price for it.
local function CostToBuy(id, qty)
    local e = MastercraftEntry(id)
    local aPrice, aAge = AuctionatorPrice(id)
    local mAge = e and math.floor((time() - (e.t or 0)) / 86400)
    if e and not (aPrice and aAge and aAge < mAge) then
        if e.gone then return nil end
        if type(e.tiers) == "table" and #e.tiers > 0 then
            local left, cost = qty, 0
            for _, tier in ipairs(e.tiers) do
                local take = math.min(left, tier[2] or 0)
                cost = cost + take * (tier[1] or 0)
                left = left - take
                if left <= 0 then break end
            end
            if left > 0 then cost = cost + left * (e.tiers[#e.tiers][1] or e.p) end
            return cost, left <= 0, "Mastercraft", mAge
        end
        return e.p * qty, not (e.n and qty > e.n), "Mastercraft", mAge
    end
    if aPrice then return aPrice * qty, true, "Auctionator", aAge end
    return nil
end
JQ.CostToBuy = CostToBuy

-- The cheapest way to buy what a bundle is short: the item itself, or (when
-- you can make it) its reagents. { cost, id, qty, make, source, age, enough }
local function BuyPlan(c)
    if not c.id or c.short <= 0 then return nil end
    local plan
    local cost, enough, source, age = CostToBuy(c.id, c.short)
    if cost then plan = { cost = cost, id = c.id, qty = c.short, source = source, age = age, enough = enough } end
    local rec = c.rec
    if rec and c.canMake then
        local crafts = math.ceil(c.short / rec.n)
        local total, parts, ok = 0, {}, true
        for rid, q in pairs(rec.r) do
            if not ((rec.vendor and rec.vendor[rid]) or IsVendor(rid)) then
                local rc, renough, rsource, rage = CostToBuy(rid, crafts * q)
                if not rc then ok = false; break end
                total = total + rc
                parts[#parts + 1] = { id = rid, qty = crafts * q, source = rsource, age = rage, enough = renough }
            end
        end
        if ok and #parts > 0 and (not plan or total < plan.cost) then
            plan = { cost = total, make = true, crafts = crafts, parts = parts, id = c.id, qty = c.short, vendor = rec.vendor, r = rec.r }
        end
    end
    return plan
end

local function BestBundle(crate, idx, used)
    local best, all = nil, {}
    for _, b in ipairs(crate.bundles) do
        local c = Coverage(b, idx, used)
        all[#all + 1] = c
        if Better(c, best) then best = c end
    end
    -- nothing can be filled from your characters: the cheapest to finish off the auction house
    if best and best.short > 0 then
        local cheapest
        for _, c in ipairs(all) do
            c.buy = BuyPlan(c)
            if c.buy and (not cheapest or c.buy.cost < cheapest.buy.cost) then cheapest = c end
        end
        if cheapest then best = cheapest end
    end
    return best, all
end

-- What earlier requests and requested crates already take: { bags, alts }, and
-- how many crates of each kind are requested.
local function CrateUsed(me)
    local used = { bags = {}, alts = {} }
    for id, n in pairs(Remaining(me)) do used.alts[id] = n end
    local requested = {}
    local mine = RequestOf(me)
    for _, c in ipairs(mine and mine.crates or {}) do
        requested[c.label] = (requested[c.label] or 0) + 1
        used.bags[c.id] = (used.bags[c.id] or 0) + (c.mine or 0)
        for rid, n in pairs(c.reagents or {}) do used.bags[rid] = (used.bags[rid] or 0) + n end
    end
    return used, requested
end

-- Take a picked bundle out of what's left, so the next crate doesn't count it.
local function Claim(used, best)
    -- a crate finished off the auction house still uses what your characters have
    if not best or (best.short > 0 and not best.buy) then return end
    used.bags[best.id] = (used.bags[best.id] or 0) + best.mine
    local fromAlts = 0
    for _, a in ipairs(best.alts) do fromAlts = fromAlts + a.n end
    used.alts[best.id] = (used.alts[best.id] or 0) + fromAlts
    if best.make then
        for rid, n in pairs(best.make.mine) do used.bags[rid] = (used.bags[rid] or 0) + n end
        for rid, n in pairs(best.make.ask) do used.alts[rid] = (used.alts[rid] or 0) + n end
    end
end

local function ItemName(id) return (UI.ItemNameQuality(id)) end

-- One line about the pick, shared by the Requests tab and the crate tooltip.
-- Returns text, and the request it needs ({[id] = n}, or nil when you can fill it yourself).
local function Money(c)
    if GetMoneyString then
        local ok, s = pcall(GetMoneyString, c, true)
        if ok and s then return s end
    end
    local g, s, cc = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    return (g > 0 and (g .. "g ") or "") .. ((g > 0 or s > 0) and (s .. "s ") or "") .. cc .. "c"
end

local function FromScan(source, age)
    return source .. (age and (age == 0 and ", today" or (", " .. age .. "d old")) or "")
end

local function Describe(best)
    if not best then return "|cffff7070can't fill yet|r" end
    if best.short > 0 and best.buy then
        local b = best.buy
        local what
        if b.make then
            local list = {}
            for _, p in ipairs(b.parts) do
                list[#list + 1] = p.qty .. " " .. ItemName(p.id) .. (p.enough == false and " (fewer listed)" or "")
            end
            what = ("buy %s for |cffffffff%s|r and make %d %s"):format(table.concat(list, " + "), Money(b.cost), b.qty, best.name)
            local vend = {}
            for rid, q in pairs(b.r or {}) do
                if (b.vendor and b.vendor[rid]) or IsVendor(rid) then vend[#vend + 1] = (b.crafts * q) .. " " .. ItemName(rid) end
            end
            if #vend > 0 then what = what .. " (+ " .. table.concat(vend, ", ") .. " from a vendor)" end
            what = what .. " |cff9e9ea8(" .. FromScan(b.parts[1].source, b.parts[1].age) .. ")|r"
        else
            what = ("buy %d %s for |cffffffff%s|r%s |cff9e9ea8(%s)|r"):format(b.qty, best.name, Money(b.cost),
                b.enough == false and " - fewer are listed" or "", FromScan(b.source, b.age))
        end
        local have = best.n - best.short
        local wants
        local parts = {}
        local inBags = best.mine - (best.fromMail or 0) - (best.fromBank or 0)
        if inBags > 0 then parts[#parts + 1] = inBags .. " in your bags" end
        if (best.fromMail or 0) > 0 then parts[#parts + 1] = best.fromMail .. " in your mail" end
        if (best.fromBank or 0) > 0 then parts[#parts + 1] = best.fromBank .. " in your bank" end
        if best.make and best.make.bars > 0 then parts[#parts + 1] = "make " .. best.make.bars end
        for _, a in ipairs(best.alts) do
            parts[#parts + 1] = NameOf(a.alt) .. " " .. a.n
            wants = wants or {}
            wants[best.id] = (wants[best.id] or 0) + a.n
        end
        local text = ("|cffffd25acheapest to finish|r %d %s: %s"):format(best.n, best.name, what)
        if have > 0 then text = text .. " - plus " .. table.concat(parts, ", ") end
        return text, wants
    end
    if best.short > 0 then
        local text = ("|cffff7070can't fill yet|r - closest: %d %s (have %d, short %d)"):format(
            best.n, best.name, best.n - best.short, best.short)
        local others = {}
        for _, m in ipairs(best.makers or {}) do
            if m ~= Alts.MyName() then others[#others + 1] = NameOf(m) end
        end
        if #others > 0 then text = text .. " - " .. table.concat(others, ", ") .. " can make it" end
        return text
    end
    local parts = {}
    local inBags = best.mine - (best.fromMail or 0) - (best.fromBank or 0)
    if inBags > 0 then parts[#parts + 1] = inBags .. " in your bags" end
    if (best.fromMail or 0) > 0 then parts[#parts + 1] = best.fromMail .. " in your mail" end
    if (best.fromBank or 0) > 0 then parts[#parts + 1] = best.fromBank .. " in your bank" end
    local mk = best.make
    local buy = {}
    if mk and mk.bars > 0 then
        local rs = {}
        for rid, q in pairs(mk.r) do
            rs[#rs + 1] = (mk.crafts * q) .. " " .. ItemName(rid)
            if (mk.vendor and mk.vendor[rid]) or IsVendor(rid) then buy[#buy + 1] = (mk.crafts * q) .. " " .. ItemName(rid) end
        end
        parts[#parts + 1] = "make " .. mk.bars .. " from " .. table.concat(rs, " + ")
    end
    local wants = {}
    for _, a in ipairs(best.alts) do
        parts[#parts + 1] = NameOf(a.alt) .. " " .. a.n
        wants[best.id] = (wants[best.id] or 0) + a.n
    end
    if mk then
        for rid, n in pairs(mk.ask) do wants[rid] = (wants[rid] or 0) + n end
    end
    local needAlts = next(wants) ~= nil
    local text = ("%s with |cffffffff%d %s|r: %s"):format(needAlts and "|cffffd25acan fill|r" or "|cff59d959fill it now|r",
        best.n, best.name, table.concat(parts, ", "))
    if mk and next(mk.ask) then
        local a = {}
        for rid, n in pairs(mk.ask) do a[#a + 1] = n .. " " .. ItemName(rid) end
        text = text .. " - ask alts for " .. table.concat(a, ", ")
    end
    if #buy > 0 then text = text .. " - buy " .. table.concat(buy, ", ") end
    return text, needAlts and wants or nil
end

-- Every crate in my bags with its pick, in bag order (each claims its items).
local function CrateResults(me)
    local crates = MyCrates()
    if #crates == 0 then return {} end
    local idx = NameIndex()
    local used, requested = CrateUsed(me)
    local out = {}
    for _, crate in ipairs(crates) do
        local label = crate.name:gsub("^Waylaid Crate:%s*", "")
        local e = { crate = crate, label = label }
        if (requested[label] or 0) > 0 then
            requested[label] = requested[label] - 1
            e.requested = true
        else
            e.best, e.all = BestBundle(crate, idx, used)
            Claim(used, e.best)
        end
        out[#out + 1] = e
    end
    return out
end

local function RequestCrate(me, e)
    local best = e.best
    local _, wants = Describe(best)
    if not wants then return end
    AddRequest(me, wants, "Crate: " .. e.label)
    local r = RequestOf(me, true)
    r.crates = r.crates or {}
    r.crates[#r.crates + 1] = { label = e.label, id = best.id, n = best.n, mine = best.mine,
        reagents = best.make and best.make.mine or nil }
    local list = {}
    for id, n in pairs(wants) do list[#list + 1] = n .. " " .. ItemName(id) end
    Status(("Requested %s from alts for %s. The plan is below."):format(table.concat(list, ", "), e.label))
end

local function CrateRows(add, me)
    local results = CrateResults(me)
    if #results == 0 then return end
    add({ head = "Waylaid crates in your bags" })
    for _, e in ipairs(results) do
        local crate = e.crate
        if e.requested then
            add({ icon = crate.id, itemID = crate.id,
                  text = "|cffffd25a" .. e.label .. "|r  |cff8fb8ffrequested - see the plan below|r" })
        else
            local text, wants = Describe(e.best)
            local button, enabled, action
            if wants then
                button, enabled, action = "Request", true, function() RequestCrate(me, e) end
            elseif e.best and e.best.buy then
                -- Auctionator can search the auction house for what to buy
                local api = Auctionator and Auctionator.API and Auctionator.API.v1
                if api and api.MultiSearchExact then
                    local names = {}
                    if e.best.buy.make then
                        for _, p in ipairs(e.best.buy.parts) do names[#names + 1] = ItemName(p.id) end
                    else
                        names[1] = e.best.name
                    end
                    local ahOpen = (AuctionHouseFrame and AuctionHouseFrame:IsShown()) or (AuctionFrame and AuctionFrame:IsShown())
                    button, enabled = "Search AH", ahOpen and true or false
                    action = function()
                        if not ((AuctionHouseFrame and AuctionHouseFrame:IsShown()) or (AuctionFrame and AuctionFrame:IsShown())) then
                            Status("Open the auction house first.")
                            return
                        end
                        pcall(api.MultiSearchExact, "JaseTools", names)
                    end
                end
            end
            add({ icon = crate.id, itemID = crate.id, text = "|cffffd25a" .. e.label .. "|r  " .. text,
                  button = button, enabled = enabled, action = action })
            for _, c in ipairs(e.all or {}) do
                local total = c.mine + (c.make and c.make.bars or 0)
                for _, a in ipairs(c.alts) do total = total + a.n end
                local mark = c.short == 0 and "|cff59d959ok|r" or ("|cff9e9ea8" .. (c.id and ("have " .. total) or "none seen") .. "|r")
                if c.short > 0 and c.buy then
                    mark = mark .. ("|cff9e9ea8 - buying the rest: %s%s|r"):format(Money(c.buy.cost), c.buy.make and " (as reagents)" or "")
                end
                add({ text = ("%d %s  %s"):format(c.n, c.name, mark), indent = true, muted = c.short > 0 })
            end
        end
    end
end

-- Crate tooltips: can I fill it, and from where.
local function CrateTooltip(tt, data)
    if tt ~= GameTooltip and tt ~= ItemRefTooltip then return end
    if not (JQ.IsEnabled(KEY) and JaseQoLDB and Alts.MyName()) then return end
    local id = data and data.id
    if not id and tt.GetItem then
        local _, link = tt:GetItem()
        id = link and tonumber(link:match("item:(%d+)"))
    end
    local cached = id and db and db.crates and db.crates[id]
    if not cached then return end
    local me = Alts.MyName()
    local pick
    for _, e in ipairs(CrateResults(me)) do
        if e.crate.id == id then pick = e; break end
    end
    if not pick then
        -- not in my bags: judge it on its own
        local used = CrateUsed(me)
        pick = { best = (BestBundle({ bundles = cached.bundles }, NameIndex(), used)) }
    end
    tt:AddLine(" ")
    if pick.requested then
        tt:AddLine("|cff0cd29fJaseTools:|r requested from your alts - see the Requests tab", 1, 1, 1, true)
    else
        tt:AddLine("|cff0cd29fJaseTools:|r " .. (Describe(pick.best)), 1, 1, 1, true)
    end
    tt:Show()
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data) pcall(CrateTooltip, tt, data) end)
else
    for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
        if tt then pcall(tt.HookScript, tt, "OnTooltipSetItem", function(self) pcall(CrateTooltip, self) end) end
    end
end

local function Rows()
    local rows = {}
    local function add(r) rows[#rows + 1] = r end
    local me = Alts.MyName()

    -- Jobs for this character first: that's what to do right now.
    local jobs = MyJobs()
    if #jobs > 0 then
        add({ head = "Job for this character" })
        for _, j in ipairs(jobs) do
            local fromBank, fromMail, list = 0, 0, {}
            for id, e in pairs(j.items) do
                fromBank = fromBank + (e.bank or 0)
                fromMail = fromMail + (e.mail or 0)
                list[#list + 1] = { id = id, n = (e.bags or 0) + (e.bank or 0) + (e.mail or 0), bank = e.bank or 0, mail = e.mail or 0 }
            end
            table.sort(list, function(a, b) return UI.ItemNameQuality(a.id) < UI.ItemNameQuality(b.id) end)
            add({ text = "For " .. NameOf(j.to) .. ":", muted = true })
            for _, it in ipairs(list) do
                local where = {}
                if it.bank > 0 then where[#where + 1] = it.bank .. " from bank" end
                if it.mail > 0 then where[#where + 1] = it.mail .. " from your mail" end
                add({ icon = it.id, text = ItemText(it.id, it.n) .. (#where > 0 and ("  |cff9e9ea8(" .. table.concat(where, ", ") .. ")|r") or ""), indent = true })
            end
            if fromBank > 0 then
                add({ step = "1. At a bank: take what's needed out", button = "Pull from bank",
                      enabled = Alts.IsBankOpen(), action = PullFromBank })
            end
            add({ step = (fromBank > 0 and "2" or "1") .. ". At a mailbox: " .. (fromMail > 0 and "take the items out of your mail, then " or "") .. "send to " .. NameOf(j.to), button = "Send",
                  enabled = mailOpen and not job, action = function() StartSend(j.to) end })
        end
    end

    -- Waylaid crates in my bags: can they be filled, and from whom.
    CrateRows(add, me)

    -- My requests, and the plan for them.
    local mine = RequestOf(me)
    if mine and next(mine.items) then
        add({ head = "Requested for " .. NameOf(me) })
        local ids = {}
        for id in pairs(mine.items) do ids[#ids + 1] = id end
        table.sort(ids, function(a, b) return UI.ItemNameQuality(a) < UI.ItemNameQuality(b) end)
        for _, id in ipairs(ids) do
            local e = mine.items[id]
            local keep = Keep(id)
            add({ icon = id, itemID = id,
                  text = ItemText(id, e.need) .. ("  |cff9e9ea8sent %d%s|r"):format(e.sent or 0, keep > 0 and (" - keep " .. keep .. " on alts") or ""),
                  button = "Cancel", enabled = true, action = function()
                      mine.items[id] = nil
                      for i = #(mine.crates or {}), 1, -1 do
                          if mine.crates[i].id == id then table.remove(mine.crates, i) end
                      end
                      Tidy(me)
                      if win then win:Refresh() end
                  end })
        end
        local steps, short = Plan(me)
        add({ head = "Plan" })
        if not steps or #steps == 0 then
            add({ text = "None of your alts on this faction has these (as far as JaseTools has seen).", muted = true })
        end
        for n, s in ipairs(steps or {}) do
            local where = Alts.WhereText(s.alt)
            add({ step = ("%d. Log in on %s%s"):format(n, NameOf(s.alt),
                where and ("  |cff9e9ea8" .. where .. (s.town and " (bank town)" or " - not in a bank town") .. "|r") or "  |cff9e9ea8location not known yet|r") })
            local bankList, bagList, mailList = {}, {}, {}
            for id, e in pairs(s.items) do
                if (e.bank or 0) > 0 then bankList[#bankList + 1] = ItemText(id, e.bank) end
                if (e.bags or 0) > 0 then bagList[#bagList + 1] = ItemText(id, e.bags) end
                if (e.mail or 0) > 0 then mailList[#mailList + 1] = ItemText(id, e.mail) end
            end
            if #bankList > 0 then add({ text = "Bank: take " .. table.concat(bankList, ", "), indent = true }) end
            if #bagList > 0 then add({ text = "In bags: " .. table.concat(bagList, ", "), indent = true }) end
            if #mailList > 0 then add({ text = "In their mail: " .. table.concat(mailList, ", "), indent = true }) end
            add({ text = "Mailbox: send to " .. NameOf(me), indent = true })
        end
        if short and next(short) then
            local list = {}
            for id, n in pairs(short) do list[#list + 1] = ItemText(id, n) end
            add({ head = "Not on your alts" })
            add({ text = table.concat(list, ", ") .. "  |cff9e9ea8(buy or farm these)|r", indent = true })
        end
    end

    -- Requests other characters have made (as information).
    for recipient, r in pairs(RealmRequests()) do
        if recipient ~= me and next(r.items) then
            local placed = false
            for _, j in ipairs(jobs) do if j.to == recipient then placed = true end end
            if not placed then
                local n = 0
                for _ in pairs(r.items) do n = n + 1 end
                add({ text = NameOf(recipient) .. ("  |cff9e9ea8has %d item(s) requested; this character has nothing for it.|r"):format(n), muted = true })
            end
        end
    end
    if #rows == 0 then
        add({ text = "No requests. Open a profession window, pick a recipe and press Request, or carry a waylaid crate.", muted = true })
    end
    return rows
end

local AskKeep   -- forward (defined with the prompt below)

local function Build()
    db.win = db.win or {}
    win = UI.Window("JaseQoLRequests", "Requests", 720, 520, db.win)
    win.status = UI.Text(win, 11, 1, 0.82, 0.2)
    win.status:SetPoint("TOPLEFT", 12, -34)
    win.status:SetPoint("RIGHT", -12, 0)
    local panel = UI.Panel(win)
    panel:SetPoint("TOPLEFT", 10, -54)
    panel:SetPoint("BOTTOMRIGHT", -10, 10)
    win.list = UI.List(panel, ROW_H, function(L)
        local row = CreateFrame("Button", nil, L)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        UI.Fill(row, 1, 1, 1, 0.05, "HIGHLIGHT")
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.btn = UI.Button(row, "", 110, 20)
        row.btn:SetPoint("RIGHT", -6, 0)
        row.btn:SetScript("OnClick", function(self)
            local d = self.row.data
            if d and d.action then d.action() end
            if win:IsShown() then win:Refresh() end
        end)
        row.btn.row = row
        row.text = UI.Text(row, 12)
        row.text:SetPoint("RIGHT", row.btn, "LEFT", -8, 0)
        row:SetScript("OnEnter", function(self) if self.itemID then UI.ItemEnter(self) end end)
        row:SetScript("OnLeave", UI.HideTip)
        row:SetScript("OnClick", function(self, mouse)
            local d = self.data
            if mouse == "RightButton" and d and d.itemID then
                AskKeep(d.itemID)
            end
        end)
        return row
    end, function(row, d)
        row.data = d
        row.itemID = d.icon
        local x = d.indent and 30 or 8
        row.icon:ClearAllPoints()
        if d.icon then
            row.icon:SetPoint("LEFT", x, 0)
            row.icon:SetTexture(UI.ItemIcon(d.icon))
            row.icon:Show()
            x = x + 24
        else
            row.icon:Hide()
        end
        row.text:ClearAllPoints()
        row.text:SetPoint("LEFT", x, 0)
        row.text:SetPoint("RIGHT", row.btn, "LEFT", -8, 0)
        if d.head then
            UI.SetFont(row.text, 12)
            row.text:SetText(("|cff%s%s|r"):format(UI.AccentHex(), d.head:upper()))
        elseif d.step then
            UI.SetFont(row.text, 12)
            row.text:SetText(d.step)
            row.text:SetTextColor(1, 1, 1)
        else
            UI.SetFont(row.text, 12)
            row.text:SetText(d.text or "")
            if d.muted then row.text:SetTextColor(UI.MUTED[1], UI.MUTED[2], UI.MUTED[3]) else row.text:SetTextColor(0.9, 0.9, 0.92) end
        end
        if d.button then
            row.btn.text:SetText(d.button)
            row.btn:SetEnabledLook(d.enabled and true or false)
            row.btn:Show()
        else
            row.btn:Hide()
        end
    end)
    win.list:SetPoint("TOPLEFT", 4, -4)
    win.list:SetPoint("BOTTOMRIGHT", -4, 4)
    function win:Refresh()
        if not self:IsShown() then return end
        self.list:SetItems(Rows(), true)
    end
    win:SetScript("OnShow", function(self) self:Refresh() end)
    JQ.Hub.Attach(win, "requests")
end

function Status(text, quiet)
    if win and win.status then win.status:SetText(text or "") end
    if text and text ~= "" and not quiet then JQ.Print(text) end
    if win and win:IsShown() then win:Refresh() end
end

JQ.Hub.Register({
    key = "requests", label = "Requests",
    enabled = function() return JQ.IsEnabled(KEY) end,
    frame = function() return win end,
    open = function()
        if not JQ.IsEnabled(KEY) then return end
        if not win then Build() end
        return win
    end,
})

-------------------------------------------------------------------------------
--  Profession window side panel
-------------------------------------------------------------------------------
local side

-- The modern profession window (ProfessionsFrame, which WoW Forever uses):
-- the recipe its form shows, and that recipe's basic reagents.
local function ModernForm()
    local page = ProfessionsFrame and ProfessionsFrame:IsShown() and ProfessionsFrame.CraftingPage
    local form = page and page:IsShown() and page.SchematicForm
    return form, page
end

local function ModernReagents()
    local form = ModernForm()
    if not (form and form.GetRecipeInfo) then return nil end
    local ok, info = pcall(form.GetRecipeInfo, form)
    if not (ok and info and info.recipeID) then return nil end
    local T = C_TradeSkillUI
    local schematic = T and T.GetRecipeSchematic and T.GetRecipeSchematic(info.recipeID, false)
    local list = {}
    for _, slot in ipairs(schematic and schematic.reagentSlotSchematics or {}) do
        local basic = not (Enum and Enum.CraftingReagentType) or slot.reagentType == Enum.CraftingReagentType.Basic
        local reagent = slot.reagents and slot.reagents[1]
        if basic and reagent and reagent.itemID then
            list[#list + 1] = { id = reagent.itemID, per = slot.quantityRequired or 1 }
        end
    end
    return info.name or (schematic and schematic.name), list, info.recipeID
end

-- The game's own "how many" box under the recipe, if there is one.
local function GameCraftCount()
    local _, page = ModernForm()
    local box = page and page.CreateMultipleInputBox
    if box and box.GetValue then
        local ok, v = pcall(box.GetValue, box)
        if ok and tonumber(v) then return tonumber(v) end
    end
    if TradeSkillInputBox and TradeSkillInputBox.GetNumber then return TradeSkillInputBox:GetNumber() end
end

local function Reagents()
    -- returns recipeName, { {id, perCraft}, ... }
    local list = {}
    if ProfessionsFrame and ProfessionsFrame:IsShown() then
        return ModernReagents()
    end
    if CraftFrame and CraftFrame:IsShown() and GetCraftSelectionIndex then
        local i = GetCraftSelectionIndex()
        if not i or i == 0 then return nil end
        local name = GetCraftInfo(i)
        for j = 1, (GetCraftNumReagents(i) or 0) do
            local _, _, count = GetCraftReagentInfo(i, j)
            local link = GetCraftReagentItemLink(i, j)
            local id = link and tonumber(link:match("item:(%d+)"))
            if id then list[#list + 1] = { id = id, per = count or 1 } end
        end
        return name, list
    end
    if TradeSkillFrame and TradeSkillFrame:IsShown() and GetTradeSkillSelectionIndex then
        local i = GetTradeSkillSelectionIndex()
        if not i or i == 0 then return nil end
        local name, kind = GetTradeSkillInfo(i)
        if kind == "header" or kind == "subheader" then return nil end
        for j = 1, (GetTradeSkillNumReagents(i) or 0) do
            local _, _, count = GetTradeSkillReagentInfo(i, j)
            local link = GetTradeSkillReagentItemLink(i, j)
            local id = link and tonumber(link:match("item:(%d+)"))
            if id then list[#list + 1] = { id = id, per = count or 1 } end
        end
        return name, list
    end
end

-- What this character has (bags live + recorded bank + incoming mail) and what alts can give.
local function HaveAndAlts(id)
    local me = Alts.MyName()
    local data = Alts.RealmTable()[me] or {}
    local bags, bank = Holdings(me)
    local have = (bags[id] or 0) + (bank[id] or 0) + ((data.mail or {})[id] or 0)
    local alts = 0
    local faction = UnitFactionGroup("player")
    for name, d in pairs(Alts.RealmTable()) do
        if name ~= me and (not d.faction or d.faction == faction) then
            local b, k, m = Holdings(name)
            alts = alts + math.max(0, (b[id] or 0) + (k[id] or 0) + (m[id] or 0) - Keep(id))
        end
    end
    return have, alts
end

-------------------------------------------------------------------------------
--  Vendor items (never requested) and the recipe index (for drill-down)
-------------------------------------------------------------------------------
-- Common reagents sold by vendors; any item a vendor sells unlimited is added
-- when you open that vendor (JaseQoLDB.vendorItems), so Forever's own count too.
local VENDOR = {}
for _, id in ipairs({
    2320, 2321, 4291, 8343, 14341,                               -- threads
    2324, 2325, 2604, 2605, 4340, 4341, 4342, 6260, 6261, 10290,  -- bleach, dyes
    3371, 3372, 8925, 18256,                                      -- vials
    2880, 3466, 3857,                                             -- flux, coal
    4289, 2678, 2692, 3713, 17194, 159, 1179, 2596,              -- salt, spices, drinks
    6217, 4470, 11291,                                            -- rods, wood
    4399, 4400, 5140, 10647, 10648, 7191,                         -- engineering
    2928, 2930, 5173, 8923, 8924,                                 -- poison reagents
}) do VENDOR[id] = true end

function IsVendor(id)
    return VENDOR[id] or (JaseQoLDB.vendorItems and JaseQoLDB.vendorItems[id]) or false
end

local function LearnVendor()
    if not (GetMerchantNumItems and GetMerchantItemInfo) then return end
    JaseQoLDB.vendorItems = JaseQoLDB.vendorItems or {}
    for i = 1, GetMerchantNumItems() or 0 do
        local id = GetMerchantItemID and GetMerchantItemID(i)
        if not id then
            local link = GetMerchantItemLink and GetMerchantItemLink(i)
            id = link and tonumber(link:match("item:(%d+)"))
        end
        local numAvailable = select(5, GetMerchantItemInfo(i))
        if id and numAvailable == -1 then JaseQoLDB.vendorItems[id] = true end
    end
end

-- What makes what: recorded from your profession windows.
-- JaseQoLDB.recipeIndex[outputItemID] = { n = made per craft, r = {[reagentID] = qty}, by = {[character] = true} }
local function Index()
    JaseQoLDB.recipeIndex = JaseQoLDB.recipeIndex or {}
    return JaseQoLDB.recipeIndex
end

local function Record(outID, n, reagents)
    if not outID or not next(reagents) then return end
    local idx = Index()
    local e = idx[outID] or { by = {} }
    e.n, e.r = math.max(1, n or 1), reagents
    e.by[Alts.MyName()] = true
    idx[outID] = e
end

local function ScanRecipes()
    local T = C_TradeSkillUI
    if T and T.GetAllRecipeIDs and ProfessionsFrame and ProfessionsFrame:IsShown() then
        if (T.IsTradeSkillLinked and T.IsTradeSkillLinked()) or (T.IsTradeSkillGuild and T.IsTradeSkillGuild()) then return end
        for _, id in ipairs(T.GetAllRecipeIDs() or {}) do
            local info = T.GetRecipeInfo and T.GetRecipeInfo(id)
            if info and info.learned then
                local sch = T.GetRecipeSchematic and T.GetRecipeSchematic(id, false)
                if sch and sch.outputItemID then
                    local r = {}
                    for _, slot in ipairs(sch.reagentSlotSchematics or {}) do
                        local basic = not (Enum and Enum.CraftingReagentType) or slot.reagentType == Enum.CraftingReagentType.Basic
                        local reagent = slot.reagents and slot.reagents[1]
                        if basic and reagent and reagent.itemID then r[reagent.itemID] = slot.quantityRequired or 1 end
                    end
                    Record(sch.outputItemID, sch.quantityMin, r)
                end
            end
        end
        return
    end
    if TradeSkillFrame and TradeSkillFrame:IsShown() and GetNumTradeSkills then
        if IsTradeSkillLinked and IsTradeSkillLinked() then return end
        for i = 1, GetNumTradeSkills() do
            local _, kind = GetTradeSkillInfo(i)
            local link = kind ~= "header" and GetTradeSkillItemLink and GetTradeSkillItemLink(i)
            local out = link and tonumber(link:match("item:(%d+)"))
            if out then
                local r = {}
                for j = 1, GetTradeSkillNumReagents(i) or 0 do
                    local _, _, q = GetTradeSkillReagentInfo(i, j)
                    local rl = GetTradeSkillReagentItemLink(i, j)
                    local rid = rl and tonumber(rl:match("item:(%d+)"))
                    if rid then r[rid] = q or 1 end
                end
                Record(out, GetTradeSkillNumMade and GetTradeSkillNumMade(i) or 1, r)
            end
        end
    end
end

-- The full picture for N crafts: what you have, what alts send, what's bought
-- from a vendor, and - when nobody has enough of something you can make - the
-- crafts and their own reagents (up to three levels down).
-- rows: { id, need, have, alts, depth, kind = ok|alts|vendor|make|missing, make }
local function Breakdown(list, crafts)
    local rows, request = {}, {}
    local tot = { request = 0, vendor = 0, still = 0 }
    local usedHave, usedAlts = {}, {}
    local idx = Index()
    local me = Alts.MyName()
    local function walk(id, need, depth, seen)
        local haveAll, altsAll = HaveAndAlts(id)
        local row = { id = id, need = need, have = haveAll, alts = altsAll, depth = depth }
        rows[#rows + 1] = row
        local have = math.max(0, haveAll - (usedHave[id] or 0))
        local fromHave = math.min(need, have)
        usedHave[id] = (usedHave[id] or 0) + fromHave
        local short = need - fromHave
        if short <= 0 then row.kind = "ok"; return end
        if IsVendor(id) then
            row.kind, row.buy = "vendor", short
            tot.vendor = tot.vendor + short
            return
        end
        local alts = math.max(0, altsAll - (usedAlts[id] or 0))
        local fromAlts = math.min(short, alts)
        usedAlts[id] = (usedAlts[id] or 0) + fromAlts
        if fromAlts > 0 then request[id] = (request[id] or 0) + fromAlts end
        local still = short - fromAlts
        if still <= 0 then row.kind = "alts"; return end
        local rec = idx[id]
        if rec and rec.r and depth < 3 and not seen[id] then
            local makes = math.ceil(still / (rec.n or 1))
            row.kind, row.make = "make", makes
            row.maker = rec.by and (rec.by[me] and "you" or next(rec.by)) or nil
            seen[id] = true
            for rid, q in pairs(rec.r) do walk(rid, q * makes, depth + 1, seen) end
            seen[id] = nil
        else
            -- not seen anywhere yet: still asked for, the plan lists it as short
            row.kind = "missing"
            request[id] = (request[id] or 0) + still
            tot.still = tot.still + still
        end
    end
    for _, e in ipairs(list or {}) do walk(e.id, e.per * crafts, 0, {}) end
    for _, n in pairs(request) do tot.request = tot.request + n end
    return rows, request, tot
end

local function BuildSide(parent)
    side = CreateFrame("Frame", "JaseQoLRequestPanel", UIParent)
    side:SetSize((db.sideSize and db.sideSize[1]) or 260, (db.sideSize and db.sideSize[2]) or 300)
    side:SetResizable(true)
    if side.SetResizeBounds then side:SetResizeBounds(240, 220, 700, 800) end
    side:SetFrameStrata("HIGH")
    UI.Fill(side, 0.045, 0.045, 0.05, 0.96)
    UI.Border(side)
    side:EnableMouse(true)
    side:SetMovable(true)
    side:RegisterForDrag("LeftButton")
    side:SetScript("OnDragStart", side.StartMoving)
    side:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        db.sidePos = { p, rp, x, y }
    end)

    side.title = UI.Text(side, 13)
    side.title:SetPoint("TOPLEFT", 10, -8)
    side.title:SetText("Request from alts")
    side.recipe = UI.Text(side, 11, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3])
    side.recipe:SetPoint("TOPLEFT", 10, -26)
    side.recipe:SetPoint("RIGHT", -10, 0)

    local qtyLabel = UI.Text(side, 11, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3])
    qtyLabel:SetPoint("TOPLEFT", 10, -48)
    qtyLabel:SetText("Crafts")
    side.qty = CreateFrame("EditBox", nil, side)
    side.qty:SetSize(50, 20)
    side.qty:SetPoint("LEFT", qtyLabel, "RIGHT", 8, 0)
    side.qty:SetAutoFocus(false)
    side.qty:SetNumeric(true)
    side.qty:SetMaxLetters(4)
    side.qty:SetJustifyH("CENTER")
    UI.SetFont(side.qty, 12)
    UI.Fill(side.qty, 0, 0, 0, 0.5)
    UI.Border(side.qty)
    side.qty:SetText("1")
    side.qty:SetScript("OnTextChanged", function() side:Refresh() end)
    side.qty:SetScript("OnEnterPressed", side.qty.ClearFocus)
    side.qty:SetScript("OnEscapePressed", side.qty.ClearFocus)
    local head = UI.Text(side, 10, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3], "RIGHT")
    head:SetPoint("TOPRIGHT", -10, -52)
    head:SetText("need  have  alts")

    side.rows = {}
    for i = 1, 20 do
        local r = CreateFrame("Button", nil, side)
        r:SetHeight(22)
        r:SetPoint("TOPLEFT", 10, -72 - (i - 1) * 24)
        r:SetPoint("RIGHT", side, "RIGHT", -10, 0)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(18, 18)
        r.icon:SetPoint("LEFT")
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.nums = UI.Text(r, 11, 1, 1, 1, "RIGHT")
        r.nums:SetPoint("RIGHT")
        r.nums:SetWidth(96)
        r.name = UI.Text(r, 11)
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
        r.name:SetPoint("RIGHT", r.nums, "LEFT", -4, 0)
        r:SetScript("OnEnter", UI.ItemEnter)
        r:SetScript("OnLeave", UI.HideTip)
        side.rows[i] = r
    end

    side.summary = UI.Text(side, 11, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3])
    side.summary:SetPoint("BOTTOMLEFT", 10, 40)
    if side.summary.SetMaxLines then side.summary:SetMaxLines(3) end
    side.summary:SetPoint("RIGHT", -10, 0)
    side.summary:SetWordWrap(true)

    side.request = UI.Button(side, "Request", 110, 24)
    side.request:SetPoint("BOTTOMLEFT", 10, 10)
    side.request:SetScript("OnClick", function()
        local name, short = side.recipeName, side.short
        if not (short and next(short)) then return end
        local n = tonumber(side.qty:GetText()) or 1
        AddRequest(Alts.MyName(), short, (name or "?") .. " x" .. n)
        local parts = {}
        for id, k in pairs(short) do parts[#parts + 1] = ItemText(id, k) end
        JQ.Print("Requested from alts: " .. table.concat(parts, ", ") .. ". See the Requests tab for the plan.")
        side:Refresh()
        if win and win:IsShown() then win:Refresh() end
    end)
    local open = UI.Button(side, "Requests", 110, 24)
    open:SetPoint("BOTTOMRIGHT", -10, 10)
    open:SetScript("OnClick", function() JQ.Hub.Show("requests") end)

    local grip = CreateFrame("Button", nil, side)
    grip:SetSize(14, 14)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() side:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        side:StopMovingOrSizing()
        db.sideSize = { side:GetWidth(), side:GetHeight() }
        local p, _, rp, x, y = side:GetPoint()
        db.sidePos = { p, rp, x, y }
        side:Refresh()
    end)
    side:SetScript("OnSizeChanged", function(self) if self:IsShown() then self:Refresh() end end)

    function side:Place(frame)
        self:ClearAllPoints()
        if db.sidePos then
            self:SetPoint(db.sidePos[1], UIParent, db.sidePos[2], db.sidePos[3], db.sidePos[4])
        else
            if frame == ProfessionsFrame then
                -- left side: Mastercraft and others put buttons on its right edge
                self:SetPoint("TOPRIGHT", frame, "TOPLEFT", -6, 0)
            else
                self:SetPoint("TOPLEFT", frame, "TOPRIGHT", -30, -12)
            end
        end
    end

    function side:Refresh()
        if not self:IsShown() then return end
        local name, list = Reagents()
        self.recipeName = name
        local n = tonumber(self.qty:GetText()) or 1
        if n < 1 then n = 1 end
        self.recipe:SetText(name and (name .. "  x" .. n) or "Pick a recipe")
        local rows, request, tot = Breakdown(list, n)
        -- as many rows as the panel's height fits (it can be resized)
        local fits = math.max(1, math.floor((self:GetHeight() - 72 - 76) / 24))
        local hidden = 0
        for i, r in ipairs(self.rows) do
            local e = rows[i]
            if e and i > fits then hidden = hidden + 1; e = nil end
            if e then
                local iname, q = UI.ItemNameQuality(e.id)
                r.itemID = e.id
                local indent = e.depth * 14
                r.icon:ClearAllPoints()
                r.icon:SetPoint("LEFT", indent, 0)
                r.icon:SetTexture(UI.ItemIcon(e.id))
                r.icon:SetDesaturated(e.kind == "vendor")
                local tag = ""
                if e.kind == "vendor" then
                    tag = "  |cff9e9ea8vendor|r"
                elseif e.kind == "make" then
                    tag = ("  |cffffd233make %d%s|r"):format(e.make, (e.maker and e.maker ~= "you") and (" - " .. Alts.Display(e.maker)) or "")
                end
                r.name:SetText(iname .. tag)
                if e.kind == "vendor" then r.name:SetTextColor(0.6, 0.6, 0.62) else r.name:SetTextColor(UI.QualityColor(q)) end
                local hc = (e.kind == "ok") and "59d959" or (e.kind == "vendor" and "9e9ea8" or "ff7070")
                r.nums:SetText(("%d   |cff%s%d|r   %d"):format(e.need, hc, e.have, e.alts))
                r:Show()
            else
                r:Hide()
            end
        end
        self.short = request
        local parts = {}
        if tot.request > 0 then parts[#parts + 1] = ("Request %d from alts."):format(tot.request) end
        for _, e in ipairs(rows) do
            if e.kind == "make" then
                parts[#parts + 1] = ("Make %d %s."):format(e.make, (UI.ItemNameQuality(e.id)))
            end
        end
        if tot.vendor > 0 then parts[#parts + 1] = ("|cff9e9ea8Buy %d from a vendor.|r"):format(tot.vendor) end
        if tot.still > 0 then parts[#parts + 1] = ("|cffff7070%d not seen on any alt.|r"):format(tot.still) end
        if hidden > 0 then parts[#parts + 1] = ("|cffffd233(%d more rows: make the panel taller)|r"):format(hidden) end
        if not list or #list == 0 then
            self.summary:SetText("")
        elseif tot.request == 0 and tot.vendor == 0 and #parts == 0 then
            self.summary:SetText("|cff59d959You have everything for this.|r")
        else
            self.summary:SetText(#parts > 0 and table.concat(parts, " ") or "|cff59d959You have everything you can't buy.|r")
        end
        self.request:SetEnabledLook(tot.request > 0)
        self.request.text:SetText(tot.request > 0 and ("Request " .. tot.request) or "Request")
    end

    side.elapsed = 0
    side:SetScript("OnUpdate", function(self, e)
        self.elapsed = self.elapsed + e
        if self.elapsed < 0.4 then return end
        self.elapsed = 0
        local name = Reagents()
        if name ~= self.lastName then
            self.lastName = name
            local n = GameCraftCount()
            if n and n > 0 and not self.qty:HasFocus() then self.qty:SetText(tostring(n)) end
            self:Refresh()
        end
    end)
end

local function ShowSide(frame)
    if not JQ.IsEnabled(KEY) or not frame then return end
    if not side then BuildSide() end
    side.host = frame
    side:Place(frame)
    side:Show()
    side:Refresh()
end

local function HideSide()
    if side then side:Hide() end
end

-------------------------------------------------------------------------------
--  Events
-------------------------------------------------------------------------------
local profHooked = false
local function HasJobs() return #MyJobs() > 0 end

ev:SetScript("OnEvent", function(_, event, ...)
    if not JQ.IsEnabled(KEY) then return end
    if event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
        pcall(LearnVendor)
        for recipient in pairs(RealmRequests()) do Tidy(recipient) end
        return
    elseif event == "TRADE_SKILL_LIST_UPDATE" then
        C_Timer.After(0.3, function() pcall(ScanRecipes) end)
        return
    end
    if event == "TRADE_SKILL_SHOW" then
        C_Timer.After(0.5, function() pcall(ScanRecipes) end)
        C_Timer.After(0, function()
            local f = (ProfessionsFrame and ProfessionsFrame:IsShown() and ProfessionsFrame) or TradeSkillFrame
            ShowSide(f)
            -- the modern window can close without TRADE_SKILL_CLOSE reaching us first
            if f == ProfessionsFrame and not profHooked then
                profHooked = true
                ProfessionsFrame:HookScript("OnHide", HideSide)
            end
        end)
    elseif event == "CRAFT_SHOW" then
        C_Timer.After(0, function() ShowSide(CraftFrame) end)
    elseif event == "TRADE_SKILL_CLOSE" or event == "CRAFT_CLOSE" then
        HideSide()
    elseif event == "TRADE_SKILL_UPDATE" or event == "CRAFT_UPDATE" then
        if side and side:IsShown() then side:Refresh() end
    elseif event == "MAIL_SHOW" then
        mailOpen = true
        if HasJobs() then JQ.Hub.Show("requests") end
    elseif event == "MAIL_CLOSED" then
        mailOpen = false
        if job then FinishSend("Mailbox closed: stopped.") end
        if win and win:IsShown() then win:Refresh() end
    elseif event == "BANKFRAME_OPENED" or (event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW"
        and Enum and Enum.PlayerInteractionType and (... == Enum.PlayerInteractionType.Banker
        or ... == Enum.PlayerInteractionType.CharacterBanker)) then
        if HasJobs() then C_Timer.After(0.2, function() JQ.Hub.Show("requests") end) end
        if win and win:IsShown() then C_Timer.After(0.2, function() win:Refresh() end) end
    elseif event == "BANKFRAME_CLOSED" then
        if win and win:IsShown() then win:Refresh() end
    elseif event == "BAG_UPDATE_DELAYED" then
        if win and win:IsShown() then win:Refresh() end
        if side and side:IsShown() then side:Refresh() end
    elseif event == "MAIL_SEND_SUCCESS" then
        if not job then return end
        local r = RequestOf(job.to)
        for id, n in pairs(job.batch or {}) do
            if r and r.items[id] then r.items[id].sent = (r.items[id].sent or 0) + n end
        end
        Alts.AddMail(job.to, job.batch or {})
        job.batch = nil
        Tidy(job.to)
        C_Timer.After(0.4, SendNext)
    elseif event == "MAIL_FAILED" then
        if job then ClearSendMail(); FinishSend("The mail failed: stopped.") end
    elseif event == "PLAYER_LOGIN" then
        for recipient in pairs(RealmRequests()) do Tidy(recipient) end
        C_Timer.After(3, function()
            local jobs = MyJobs()
            if #jobs == 0 then return end
            for _, j in ipairs(jobs) do
                local n, bank = 0, false
                for _, e in pairs(j.items) do n = n + (e.bags or 0) + (e.bank or 0) + (e.mail or 0); if (e.bank or 0) > 0 then bank = true end end
                local line = ("Job: send %d item(s) to %s%s"):format(
                    n, Alts.Display(j.to), bank and " (some are in your bank)" or "")
                if not line:find("%.$") then line = line .. "." end
                JQ.Print(line .. " The Requests tab has the list.")
            end
            -- open the Requests tab straight away (not in combat, not over another JaseTools tab)
            if not InCombatLockdown() and not (JQ.Hub.IsOpen and JQ.Hub.IsOpen()) then
                JQ.Hub.Show("requests")
            end
        end)
    end
end)

-------------------------------------------------------------------------------
--  Keep amount prompt (JaseTools's own little box: the game's StaticPopup
--  system is left alone, so its protected confirmations never get tainted)
-------------------------------------------------------------------------------
local prompt
function AskKeep(id)
    if not prompt then
        prompt = CreateFrame("Frame", "JaseQoLKeepPrompt", UIParent)
        prompt:SetSize(300, 110)
        prompt:SetPoint("CENTER", 0, 120)
        prompt:SetFrameStrata("DIALOG")
        prompt:EnableMouse(true)
        UI.Fill(prompt, 0.045, 0.045, 0.05, 0.97)
        UI.Border(prompt)
        tinsert(UISpecialFrames, "JaseQoLKeepPrompt")
        prompt.text = UI.Text(prompt, 12, 1, 1, 1, "CENTER")
        prompt.text:SetPoint("TOPLEFT", 10, -12)
        prompt.text:SetPoint("TOPRIGHT", -10, -12)
        prompt.text:SetWordWrap(true)
        prompt.box = CreateFrame("EditBox", nil, prompt)
        prompt.box:SetSize(80, 22)
        prompt.box:SetPoint("TOP", 0, -46)
        prompt.box:SetAutoFocus(true)
        prompt.box:SetNumeric(true)
        prompt.box:SetMaxLetters(5)
        prompt.box:SetJustifyH("CENTER")
        UI.SetFont(prompt.box, 12)
        UI.Fill(prompt.box, 0, 0, 0, 0.5)
        UI.Border(prompt.box)
        local function Accept()
            local n = tonumber(prompt.box:GetText())
            if n and prompt.itemID then db.keep[prompt.itemID] = n > 0 and math.floor(n) or nil end
            prompt:Hide()
            if win and win:IsShown() then win:Refresh() end
        end
        prompt.box:SetScript("OnEnterPressed", Accept)
        prompt.box:SetScript("OnEscapePressed", function() prompt:Hide() end)
        local ok = UI.Button(prompt, "OK", 90, 22)
        ok:SetPoint("BOTTOMRIGHT", prompt, "BOTTOM", -4, 10)
        ok:SetScript("OnClick", Accept)
        local cancel = UI.Button(prompt, "Cancel", 90, 22)
        cancel:SetPoint("BOTTOMLEFT", prompt, "BOTTOM", 4, 10)
        cancel:SetScript("OnClick", function() prompt:Hide() end)
    end
    prompt.itemID = id
    prompt.text:SetText(("Keep at least how many %s on each alt?"):format(UI.ItemNameQuality(id)))
    prompt.box:SetText(tostring(Keep(id)))
    prompt:Show()
    prompt.box:SetFocus()
    prompt.box:HighlightText()
end

-------------------------------------------------------------------------------
--  Load
-------------------------------------------------------------------------------
JQ.byKey[KEY].onLoad = function()
    Alts = JQ.Alts
    JaseQoLDB.altRequest = JaseQoLDB.altRequest or {}
    db = JaseQoLDB.altRequest
    db.requests = db.requests or {}
    db.keep = db.keep or {}
    for _, e in ipairs({ "PLAYER_LOGIN", "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "TRADE_SKILL_UPDATE",
        "TRADE_SKILL_LIST_UPDATE", "MERCHANT_SHOW", "MERCHANT_UPDATE",
        "CRAFT_SHOW", "CRAFT_CLOSE", "CRAFT_UPDATE", "MAIL_SHOW", "MAIL_CLOSED", "MAIL_SEND_SUCCESS", "MAIL_FAILED",
        "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "BAG_UPDATE_DELAYED", "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    Alts.OnChange(function() if win and win:IsShown() then win:Refresh() end end)
end
JQ.byKey[KEY].onDisable = function()
    HideSide()
    if win then win:Hide() end
end

-- for tests
JQ._AltRequest = { Breakdown = Breakdown, ScanRecipes = ScanRecipes, IsVendor = IsVendor, Plan = Plan, MyJobs = MyJobs, AddRequest = AddRequest, Remaining = Remaining,
    PullFromBank = PullFromBank, StartSend = StartSend, Rows = Rows,
    ParseBundles = ParseBundles, MyCrates = MyCrates, BestBundle = BestBundle, NameIndex = NameIndex }
