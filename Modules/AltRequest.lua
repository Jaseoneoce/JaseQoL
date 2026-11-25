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
--      {items = {[itemID] = {need = n, sent = n}}, recipes = {...},
--       done = {[alt] = {[itemID] = n}}, own = {[itemID] = {n = n, base = n}},
--       make = {[itemID] = {n = n, base = n}}}}},
--    keep = {[itemID] = n}, win = {...},
--    auto = { bank = bool, send = bool, mail = bool } (the plan popout's "auto" ticks) }
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
local QueueMini  -- forward (plan popout below): redraw it shortly
local Plan       -- forward (the planner below)
local FinishRequest  -- forward (plan popout below): this character's plan is over

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
    if not next(r.items) then
        r.crates = nil
        -- all sent: the request stays, as "collect the mail", until none of
        -- it is left in its owner's mailbox (r.done = what each alt sent)
        -- or while its owner still has a bank run of its own to do (r.own)
        -- or something of its own to make (r.make)
        if not (r.done and next(r.done)) and not (r.own and next(r.own)) and not (r.make and next(r.make)) then
            RealmRequests()[recipient] = nil
        end
    end
end

local function AddRequest(recipient, wants, label)
    local r = RequestOf(recipient, true)
    local bags, bank, mail
    for id, n in pairs(wants) do
        if n > 0 and not IsVendor(id) then
            local e = r.items[id] or { need = 0, sent = 0 }
            e.need = e.need + n
            if not e.base then
                bags, bank, mail = bags or Holdings(recipient)
                if not bank then bags, bank, mail = Holdings(recipient) end
                e.base = (bags[id] or 0) + (bank[id] or 0) + (mail[id] or 0)
            end
            r.items[id] = e
        end
    end
    if label then table.insert(r.recipes, label) end
    Tidy(recipient)
    QueueMini(true)
end

-------------------------------------------------------------------------------
--  Own bank run: what a request needs that its owner already has, but in its
--  own bank or mail rather than its bags. r.own[id] = { n = how many to
--  fetch, base = how many were in bags when it was asked for }.
-------------------------------------------------------------------------------
-- wants = {[id] = total needed}; madeInto = {[id] = the item it's a reagent of}
-- (that part of the run is over once that item has been made).
-- Returns how many items the bank run got.
local function AddOwn(recipient, wants, madeInto)
    local bags, bank, mail = Holdings(recipient)
    local r, added = nil, 0
    for id, need in pairs(wants or {}) do
        local b = bags[id] or 0
        local fetch = math.min(need, b + (bank[id] or 0) + (mail[id] or 0)) - math.min(need, b)
        if fetch > 0 then
            r = r or RequestOf(recipient, true)
            r.own = r.own or {}
            r.own[id] = { n = fetch, base = b, of = madeInto and madeInto[id] or nil }
            added = added + fetch
        end
    end
    if added > 0 then QueueMini(true) end
    return added
end

-- What's still to fetch: { {id, bank = n, mail = n}, ... } by name. Bags (and
-- an open bank) are counted live on the owner, as last seen on anyone else.
local function OwnFetch(recipient)
    local out = {}
    local r = recipient and RequestOf(recipient)
    if not (r and r.own) then return out end
    local bags, bank, mail = Holdings(recipient)
    for id, o in pairs(r.own) do
        local left = math.max(0, (o.base or 0) + (o.n or 0) - (bags[id] or 0))
        local fromBank = math.min(left, bank[id] or 0)
        local fromMail = math.min(left - fromBank, mail[id] or 0)
        if fromBank + fromMail > 0 then out[#out + 1] = { id = id, bank = fromBank, mail = fromMail } end
    end
    table.sort(out, function(a, b) return UI.ItemNameQuality(a.id) < UI.ItemNameQuality(b.id) end)
    return out
end

-- To make: what the plan has its owner smelt or craft because nobody has
-- enough of it, from reagents the plan also gathers. r.make[id] = { n = how
-- many to make, base = how many it had (bags + bank + mail) when planned }.
local function AddMake(recipient, makes)
    local bags, bank, mail = Holdings(recipient)
    local added = 0
    for id, n in pairs(makes or {}) do
        if n > 0 then
            local r = RequestOf(recipient, true)
            r.make = r.make or {}
            r.make[id] = { n = n, base = (bags[id] or 0) + (bank[id] or 0) + (mail[id] or 0) }
            added = added + n
        end
    end
    if added > 0 then QueueMini(true) end
    return added
end

-- What's still to make: { {id, n}, ... } by name. What alts have sent of it doesn't count as made.
local function MakeLeft(recipient)
    local out = {}
    local r = recipient and RequestOf(recipient)
    if not (r and r.make) then return out end
    local bags, bank, mail = Holdings(recipient)
    for id, m in pairs(r.make) do
        local sent = 0
        for _, list in pairs(r.done or {}) do sent = sent + (list[id] or 0) end
        local total = (bags[id] or 0) + (bank[id] or 0) + (mail[id] or 0)
        local left = (m.base or 0) + (m.n or 0) + sent - total
        if left > 0 then out[#out + 1] = { id = id, n = math.min(left, m.n or left) } end
    end
    table.sort(out, function(a, b) return UI.ItemNameQuality(a.id) < UI.ItemNameQuality(b.id) end)
    return out
end

-- From a Breakdown's rows: the bank run for everything it counts on from this
-- character's own bank and mail (reagents of what's to be made included), and
-- what's to be made. Returns items in the bank run, items to make.
local function PlanOwn(recipient, rows)
    local wants, makes, madeInto = {}, {}, {}
    local makeAt = {}   -- [depth] = the item being made at that depth
    for _, e in ipairs(rows or {}) do
        wants[e.id] = (wants[e.id] or 0) + e.need
        if e.depth > 0 and makeAt[e.depth - 1] then madeInto[e.id] = makeAt[e.depth - 1] end
        makeAt[e.depth] = nil
        if e.kind == "make" and (e.makeQty or 0) > 0 then
            makes[e.id] = (makes[e.id] or 0) + e.makeQty
            makeAt[e.depth] = e.id
        end
    end
    -- what's to be made first: the bank run's reagents refer to it
    local made = AddMake(recipient, makes)
    return AddOwn(recipient, wants, madeInto), made
end

-- On the owner: drop what has been fetched or made (or is no longer there to
-- fetch). Not while the mail window is open: the inbox may still be loading.
local function TidyOwn()
    local me = db and Alts and Alts.MyName()
    local r = me and RequestOf(me)
    if not (r and (r.own or r.make or next(r.items))) or (MailFrame and MailFrame:IsShown()) then return end
    local changed = false
    -- what no alt had and you've since bought (or farmed): that part is done
    local _, short = Plan(me)
    if short and next(short) then
        local bags, bank, mail = Holdings(me)
        for id, left in pairs(short) do
            local e = r.items[id]
            local have = (bags[id] or 0) + (bank[id] or 0) + (mail[id] or 0)
            if e and e.base and have - e.base >= left then
                e.need = math.max(e.sent or 0, (e.need or 0) - left)
                e.base = e.base + left
                changed = true
            end
        end
    end
    if r.make then
        local still = {}
        for _, e in ipairs(MakeLeft(me)) do still[e.id] = true end
        for id in pairs(r.make) do
            if not still[id] then r.make[id] = nil end
        end
        if not next(r.make) then r.make, changed = nil, true end
    end
    if r.own then
        local still = {}
        for _, e in ipairs(OwnFetch(me)) do still[e.id] = true end
        for id, o in pairs(r.own) do
            -- fetched, gone, or a reagent of something that has since been made
            if not still[id] or (o.of and not (r.make and r.make[o.of])) then r.own[id] = nil end
        end
        if not next(r.own) then r.own, changed = nil, true end
    end
    if changed then Tidy(me) end
end

-------------------------------------------------------------------------------
--  Planner
-------------------------------------------------------------------------------
-- steps = { {alt, items = {[id] = {bags = n, bank = n, mail = n}}, bankTown}, ... }, short = {[id] = n}
function Plan(recipient)
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

-- {[id] = how many to take out of the bank}, and whether any of it is for an alt's job
local function BankPulls()
    local want, fromBank = {}, {}
    for _, job in ipairs(MyJobs()) do
        for id, e in pairs(job.items) do
            want[id] = (want[id] or 0) + (e.bags or 0) + (e.bank or 0) + (e.mail or 0)
            fromBank[id] = (fromBank[id] or 0) + (e.bank or 0)
        end
    end
    local inBags = Live(Alts.BagIDs())
    local pulls, forJobs = {}, false
    for id, total in pairs(want) do
        local n = math.min(fromBank[id] or 0, total - (inBags[id] or 0))
        if n > 0 then pulls[id], forJobs = n, true end
    end
    -- this character's own bank run
    for _, e in ipairs(OwnFetch(Alts.MyName())) do
        if e.bank > 0 then pulls[e.id] = (pulls[e.id] or 0) + e.bank end
    end
    return pulls, forJobs
end

local function PullFromBank()
    if not Alts.IsBankOpen() then Status("Open your bank first.") return end
    if InCombatLockdown() then return end
    local pulls, forJobs = BankPulls()
    local free = FreeBagSlots()
    local moved, short = 0, false
    ClearCursor()
    for id, pull in pairs(pulls) do
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
        Status(("Bags full: moved %d stack(s). Make room and take from the bank again."):format(moved))
    elseif moved > 0 then
        Status(forJobs and ("Moved %d stack(s) from the bank. Now go to a mailbox and press Send."):format(moved)
            or ("Moved %d stack(s) from the bank into your bags."):format(moved))
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
    if not Alts.HasFullName(recipient) then JQ.Try("requests: learning names", Alts.LearnNames) end
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

-------------------------------------------------------------------------------
--  Taking out of the mail: what the plan has in this character's mailbox -
--  what alts sent it, its own bank run's mail part, and what a job of its own
--  says is in its mail. One attachment at a time; mails with a COD are left.
-------------------------------------------------------------------------------
local taking      -- { want = {[id] = n}, n = stacks taken }
local inboxSeen = false   -- the inbox has loaded since the mailbox was opened

-- {[id] = how many to take}, never more than the mailbox held when last looked at
local function MailWants()
    local me = Alts.MyName()
    local want = {}
    local r = RequestOf(me)
    for _, sent in pairs(r and r.done or {}) do
        for id, n in pairs(sent) do want[id] = (want[id] or 0) + n end
    end
    for _, e in ipairs(OwnFetch(me)) do
        if e.mail > 0 then want[e.id] = (want[e.id] or 0) + e.mail end
    end
    for _, j in ipairs(MyJobs()) do
        for id, e in pairs(j.items) do
            if (e.mail or 0) > 0 then want[id] = (want[id] or 0) + e.mail end
        end
    end
    local data = Alts.RealmTable()[me]
    local mail = (data and data.mail) or {}
    for id, n in pairs(want) do
        local have = mail[id] or 0
        want[id] = have > 0 and math.min(n, have) or nil
    end
    return want
end

local TakeNext
local function FinishTake(msg)
    taking = nil
    Status(msg)
end

function TakeNext()
    if not taking then return end
    if not (MailFrame and MailFrame:IsShown()) then return FinishTake("Mailbox closed: stopped.") end
    if #FreeBagSlots() == 0 then
        return FinishTake(("Bags full: took %d stack(s) out of your mail. Make room and take from the mail again."):format(taking.n))
    end
    local maxAttach = ATTACHMENTS_MAX_RECEIVE or 16
    for i = (GetInboxNumItems and GetInboxNumItems() or 0), 1, -1 do
        local _, _, _, _, _, cod = GetInboxHeaderInfo(i)
        if (cod or 0) == 0 then
            for a = 1, maxAttach do
                local name, id, _, count = GetInboxItem(i, a)
                if name and id and (taking.want[id] or 0) > 0 then
                    taking.want[id] = taking.want[id] - (count or 1)
                    taking.n = taking.n + 1
                    TakeInboxItem(i, a)
                    C_Timer.After(0.6, TakeNext)   -- the next one once this has landed
                    return
                end
            end
        end
    end
    FinishTake(taking.n > 0 and ("Took %d stack(s) out of your mail."):format(taking.n)
        or "None of it is in your mail right now.")
end

local function StartTake()
    if taking or job then return end
    if not mailOpen then Status("Open a mailbox first.") return end
    local want = MailWants()
    if not next(want) then Status("None of it is in your mail right now.") return end
    taking = { want = want, n = 0 }
    TakeNext()
end

-------------------------------------------------------------------------------
--  Automatic steps: with a step's "auto" ticked in the plan popout, its
--  button presses itself when the bank or mailbox is opened - once per visit.
-------------------------------------------------------------------------------
local autoDone = {}

local function AutoRun()
    if not (db and db.auto and Alts and Alts.MyName()) or InCombatLockdown() then return end
    if not (JQ.IsEnabled(KEY) and JQ.IsEnabled("requestMini")) then return end
    local auto = db.auto
    if not Alts.IsBankOpen() then
        autoDone.bank = nil
    elseif auto.bank and not autoDone.bank and next((BankPulls())) then
        autoDone.bank = true
        PullFromBank()
    end
    if not (mailOpen and MailFrame and MailFrame:IsShown()) then
        for k in pairs(autoDone) do
            if k ~= "bank" then autoDone[k] = nil end
        end
        return
    end
    if taking or job or not inboxSeen then return end
    if auto.mail and not autoDone.mail and next(MailWants()) then
        autoDone.mail = true
        StartTake()
        return
    end
    if auto.send then
        for _, j in ipairs(MyJobs()) do
            local inMail = 0
            for _, e in pairs(j.items) do inMail = inMail + (e.mail or 0) end
            -- only when it's all in the bags: nothing left in the bank or the mail
            if not autoDone["send:" .. j.to] and not j.needsBank and inMail == 0 then
                autoDone["send:" .. j.to] = true
                StartSend(j.to)
                return
            end
        end
    end
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

-------------------------------------------------------------------------------
--  Buy list: what the plan says to buy (crates' cheapest shortfall, request
--  items no alt has), and an Auctionator shopping list made from it.
-------------------------------------------------------------------------------
local SHOP_LIST = "JaseTools"

local function ShoppingListAPI()
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if api and api.CreateShoppingList and api.ConvertToSearchString then return api end
end

-- toBuy = {[id] = qty}, order = { id, ... } (in the order they come up)
local function BuyList(me)
    local toBuy, order = {}, {}
    local function want(id, n)
        if not id or not n or n <= 0 or IsVendor(id) then return end
        if not toBuy[id] then order[#order + 1] = id end
        toBuy[id] = (toBuy[id] or 0) + n
    end
    for _, e in ipairs(CrateResults(me)) do
        local b = not e.requested and e.best and e.best.buy
        if b then
            if b.make then
                for _, p in ipairs(b.parts) do want(p.id, p.qty) end
            else
                want(b.id, b.qty)
            end
        end
    end
    local mine = RequestOf(me)
    if mine and next(mine.items) then
        local _, short = Plan(me)
        for id, n in pairs(short or {}) do want(id, n) end
    end
    return toBuy, order
end

local function MakeShoppingList(order, toBuy)
    local api = ShoppingListAPI()
    if not api then return end
    local terms = {}
    for _, id in ipairs(order) do
        local name = ItemName(id)
        local ok, s = pcall(api.ConvertToSearchString, "JaseTools",
            { searchString = name, isExact = true, quantity = toBuy[id] })
        terms[#terms + 1] = (ok and type(s) == "string") and s or name
    end
    local ok, err = pcall(api.CreateShoppingList, "JaseTools", SHOP_LIST, terms)
    if ok then
        local ahOpen = (AuctionHouseFrame and AuctionHouseFrame:IsShown()) or (AuctionFrame and AuctionFrame:IsShown())
        Status(("Auctionator shopping list \"%s\" made with %d item(s)%s"):format(SHOP_LIST, #terms,
            ahOpen and " - Auctionator is searching it now." or ". Open it in Auctionator's Shopping tab at the auction house."))
    else
        Status("Auctionator couldn't make the list: " .. tostring(err))
    end
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
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data) JQ.Try("crate tooltip", CrateTooltip, tt, data) end)
else
    for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
        if tt then pcall(tt.HookScript, tt, "OnTooltipSetItem", function(self) JQ.Try("crate tooltip", CrateTooltip, self) end) end
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

    -- This character's plan as a whole: what it's for, and a way to drop all of it.
    local plan = RequestOf(me)
    if plan then
        add({ head = "Plan for " .. NameOf(me) })
        local what = (plan.recipes and #plan.recipes > 0) and table.concat(plan.recipes, ", ") or "Requested items"
        add({ text = what, indent = true, button = "Cancel plan", enabled = true,
              action = function() FinishRequest("Plan cancelled.") end })
    end

    -- This character's own bank run: what its requests need from its own bank or mail.
    local ownRun = OwnFetch(me)
    if #ownRun > 0 then
        add({ head = "Bank run for this character" })
        local anyBank = false
        for _, e in ipairs(ownRun) do
            local where = {}
            if e.bank > 0 then where[#where + 1] = e.bank .. " in your bank"; anyBank = true end
            if e.mail > 0 then where[#where + 1] = e.mail .. " in your mail" end
            add({ icon = e.id, indent = true,
                  text = ItemText(e.id, e.bank + e.mail) .. "  |cff9e9ea8(" .. table.concat(where, ", ") .. ")|r" })
        end
        if anyBank then
            add({ step = "At a bank: take them out", button = "Take from bank",
                  enabled = Alts.IsBankOpen(), action = PullFromBank })
        end
    end

    local toMake = MakeLeft(me)
    if #toMake > 0 then
        add({ head = "To make on this character" })
        for _, m in ipairs(toMake) do
            add({ icon = m.id, indent = true, text = ItemText(m.id, m.n) .. "  |cff9e9ea8(once the materials are in your bags)|r" })
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
                      QueueMini()
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

    if mine and not next(mine.items) and mine.done and next(mine.done) then
        add({ head = "Requested for " .. NameOf(me) })
        add({ text = "Everything has been sent. Collect it from a mailbox.", indent = true })
    end

    -- Everything the plan says to buy, as one Auctionator shopping list.
    local toBuy, order = BuyList(me)
    if #order > 0 then
        add({ head = "Buy on the auction house" })
        local list = {}
        for _, id in ipairs(order) do list[#list + 1] = ItemText(id, toBuy[id]) end
        local can = ShoppingListAPI() ~= nil
        add({ text = table.concat(list, ", "), indent = true,
              button = can and "Shopping list" or nil, enabled = can,
              action = can and function() MakeShoppingList(order, toBuy) end or nil })
        if not can then
            add({ text = "With Auctionator installed, this becomes a shopping list in one click.", muted = true, indent = true })
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

-------------------------------------------------------------------------------
--  Fill crate: one click fills the next crate you can fill from your bags.
--  Using an item needs a real click on a secure button, and a secure button
--  can't be touched in combat: so it isn't part of the Requests window (which
--  must stay free to open and close in a fight) but floats over a spot in it.
-------------------------------------------------------------------------------
local fillBtn

-- Crates whose pick is all in my bags right now (nothing to make, fetch or wait for).
local function FillableCrates(me)
    local out, seen = {}, {}
    for _, e in ipairs(CrateResults(me)) do
        local b = e.best
        if not e.requested and b and b.short == 0 and #b.alts == 0 and not b.make
            and (b.fromMail or 0) == 0 and (b.fromBank or 0) == 0 then
            local key = e.crate.bag .. ":" .. e.crate.slot
            if not seen[key] then
                seen[key] = true
                out[#out + 1] = e.crate
            end
        end
    end
    return out
end

local function PlaceFill()
    if not (fillBtn and win and win.fillSpot) or InCombatLockdown() then return end
    local x, y = win.fillSpot:GetLeft(), win.fillSpot:GetTop()
    if not (x and y) or (x == fillBtn.x and y == fillBtn.y) then return end
    fillBtn.x, fillBtn.y = x, y
    fillBtn:ClearAllPoints()
    fillBtn:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
end

local function SyncFill()
    if InCombatLockdown() then return end   -- again when the fight ends
    local me = Alts and Alts.MyName()
    local crates = (me and win and win:IsShown() and JQ.IsEnabled(KEY)) and FillableCrates(me) or {}
    if #crates == 0 then
        if fillBtn then fillBtn:Hide() end
        return
    end
    if not fillBtn then
        fillBtn = CreateFrame("Button", "JaseQoLFillCrate", UIParent, "SecureActionButtonTemplate")
        fillBtn:SetSize(150, 20)
        fillBtn:SetFrameStrata("HIGH")
        fillBtn:RegisterForClicks("AnyUp", "AnyDown")
        fillBtn:SetAttribute("type", "macro")
        UI.Fill(fillBtn, 1, 1, 1, 0.06)
        UI.Fill(fillBtn, 1, 1, 1, 0.08, "HIGHLIGHT")
        UI.Border(fillBtn)
        fillBtn.text = UI.Text(fillBtn, 11, 0.9, 0.9, 0.9, "CENTER")
        fillBtn.text:SetPoint("CENTER")
        fillBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText("Fill crate", 1, 1, 1)
            GameTooltip:AddLine("Uses the next waylaid crate you can fill from your bags, one per click.", 0.8, 0.8, 0.8, true)
            if self.crateName then GameTooltip:AddLine("Next: " .. self.crateName, 1, 0.82, 0.35, true) end
            GameTooltip:Show()
        end)
        fillBtn:SetScript("OnLeave", UI.HideTip)
    end
    local c = crates[1]
    fillBtn.crateName = c.name
    fillBtn:SetAttribute("macrotext", ("/use %d %d"):format(c.bag, c.slot))
    fillBtn.text:SetText(#crates > 1 and ("Fill crate (%d to fill)"):format(#crates) or "Fill crate")
    PlaceFill()
    fillBtn:Show()
end

local function Build()
    db.win = db.win or {}
    win = UI.Window("JaseQoLRequests", "Requests", 720, 520, db.win)
    win.fillSpot = CreateFrame("Frame", nil, win)   -- where the Fill crate button sits
    win.fillSpot:SetSize(150, 20)
    win.fillSpot:SetPoint("TOPRIGHT", -12, -30)
    win.status = UI.Text(win, 11, 1, 0.82, 0.2)
    win.status:SetPoint("TOPLEFT", 12, -34)
    win.status:SetPoint("RIGHT", win.fillSpot, "LEFT", -8, 0)
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
        JQ.Try("requests: fill crate button", SyncFill)
    end
    win:SetScript("OnShow", function(self) self:Refresh() end)
    win:HookScript("OnHide", function() JQ.Try("requests: fill crate button", SyncFill) end)
    -- the button follows the window as it's moved or resized
    local since = 0
    win:HookScript("OnUpdate", function(_, elapsed)
        since = since + elapsed
        if since < 0.1 then return end
        since = 0
        if fillBtn and fillBtn:IsShown() then PlaceFill() end
    end)
    JQ.Hub.Attach(win, "requests")
end

function Status(text, quiet)
    if win and win.status then win.status:SetText(text or "") end
    if text and text ~= "" and not quiet then JQ.Print(text) end
    if win and win:IsShown() then win:Refresh() end
    QueueMini()
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
--  Plan popout: while a request is open, a small list of its steps on every
--  character: who has sent (ticked, kept in the request as r.done), who is
--  next, and this character's own step with its button. Drag it to move it.
-------------------------------------------------------------------------------
local MINI_KEY = "requestMini"
JQ.AddModule({
    key = MINI_KEY,
    label = "Request plan popout",
    description = "While a request is open, a small list of the plan's steps shows on every character: your own bank run, who has sent, who is next, and this character's own step with its Take from bank / Take from mail / Send button. Tick auto on a step and its button presses itself when you open the bank or mailbox. Drag it to move it. Needs Request mats from alts.",
    default = true,
})

local MINI_W, MINI_LINE = 320, 14
local TICK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t"
local MINI_EVENTS = {
    PLAYER_LOGIN = true, BAG_UPDATE_DELAYED = true, MAIL_SHOW = true, MAIL_CLOSED = true, MAIL_INBOX_UPDATE = true,
    MAIL_SEND_SUCCESS = true, MAIL_FAILED = true, BANKFRAME_OPENED = true, BANKFRAME_CLOSED = true,
    PLAYER_INTERACTION_MANAGER_FRAME_SHOW = true, PLAYER_INTERACTION_MANAGER_FRAME_HIDE = true, MERCHANT_SHOW = true,
    AUCTION_HOUSE_SHOW = true, AUCTION_HOUSE_CLOSED = true,
}
local mini, miniHidden, miniQueued
local dockHost   -- a frame of another JaseTools window the plan sits in while that window is open

local function Sum(t)
    local n = 0
    for _, v in pairs(t or {}) do n = n + v end
    return n
end

-- Make n of an item now, in the open profession window (the plan's "make"
-- step). Crafting needs a real click, so this only ever runs from one.
local MINING_LINE = 186   -- the Mining skill line: its window is Smelting

-------------------------------------------------------------------------------
--  Crafting progress bar: whenever a batch is crafted in a profession window
--  (the game's Create / Create All, Mastercraft's Craft button, the plan's
--  "make"), one bar for the whole batch: a tick per craft, how many are done
--  and the time left. While the Professions window is open it is that
--  window's bottom strip; otherwise it floats where you drag it.
--  JaseQoLDB.altRequest.bar = { w, h, pos = { point, relPoint, x, y } }
-------------------------------------------------------------------------------
local BAR_KEY = "craftProgress"
JQ.AddModule({
    key = BAR_KEY,
    label = "Crafting progress bar",
    description = "While you craft a batch in a profession window, a bar shows the whole batch: a tick for every craft, how many are done and the time left. Works for every craft, however it was started. In the Professions window it is the bottom strip; otherwise drag it where you like. Needs Request mats from alts.",
    default = true,
})

-- The batch being made:
-- { rid = recipe spell, name, total = crafts, done, per = seconds a craft,
--   castStart, castEnd (GetTime), idleAt = when it last had nothing casting }
local making
local craftBar

local function StopMaking()
    making = nil
end

local BAR_W, BAR_H = 280, 18
local barDock   -- a frame of the Professions window the bar fills while that window is open
local function BarCfg()
    db.bar = db.bar or {}
    if db.barPos then   -- where an earlier version kept it
        db.bar.pos = db.bar.pos or { point = db.barPos[1], relPoint = db.barPos[2], x = db.barPos[3], y = db.barPos[4] }
        db.barPos = nil
    end
    return db.bar
end

-- Size and place the bar from its settings.
local function ApplyCraftBar()
    local bar = craftBar
    if not bar then return end
    if barDock then
        -- docked: the Professions window's whole bottom strip, always there
        bar:SetParent(barDock)
        bar:ClearAllPoints()
        bar:SetAllPoints(barDock)
        bar:SetFrameLevel(barDock:GetFrameLevel() + 2)
        bar.total = nil
        UI.SetFont(bar.text, 11)
        bar.text:Show()
        return
    end
    bar:SetParent(UIParent)
    bar:SetFrameStrata("MEDIUM")
    local c = BarCfg()
    local w, h = math.max(60, c.w or BAR_W), math.max(6, c.h or BAR_H)
    bar:SetSize(w, h)
    bar.total = nil   -- the ticks are laid out again for the new width
    UI.SetFont(bar.text, math.max(8, math.min(14, math.floor(h - 6))))
    bar.text:SetShown(h >= 12)
    bar:ClearAllPoints()
    local pos = c.pos
    if pos and pos.point then
        bar:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        bar:SetPoint("CENTER", UIParent, "CENTER", 0, -170)
    end
end

local function BuildCraftBar()
    local bar = CreateFrame("Frame", "JaseQoLCraftBar", UIParent)
    craftBar = bar
    bar:SetFrameStrata("MEDIUM")
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function(self) if not barDock then self:StartMoving() end end)
    bar:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if barDock then return end
        local p, _, rp, x, y = self:GetPoint()
        BarCfg().pos = { point = p, relPoint = rp, x = x, y = y }
    end)
    UI.Fill(bar, 0.045, 0.045, 0.05, 0.92)
    UI.Border(bar)
    bar.fill = bar:CreateTexture(nil, "ARTWORK")
    bar.fill:SetPoint("TOPLEFT", 1, -1)
    bar.fill:SetPoint("BOTTOMLEFT", 1, 1)
    do
        local r, g, b = UI.Accent()
        bar.fill:SetColorTexture(r, g, b, 0.7)
    end
    bar.text = UI.Text(bar, 11, 1, 1, 1, "CENTER")
    bar.text:SetPoint("LEFT", 6, 0)
    bar.text:SetPoint("RIGHT", -6, 0)
    bar.ticks = {}
    function bar:Layout(total)
        if self.total == total then return end
        self.total = total
        local w = self:GetWidth() - 2
        local n = total <= 100 and total - 1 or 0   -- too many to tell apart: no ticks
        for i = 1, n do
            local t = self.ticks[i]
            if not t then
                t = self:CreateTexture(nil, "OVERLAY")
                t:SetColorTexture(0, 0, 0, 0.65)
                t:SetWidth(1)
                self.ticks[i] = t
            end
            t:ClearAllPoints()
            t:SetPoint("TOP", self, "TOPLEFT", 1 + w * i / total, -1)
            t:SetPoint("BOTTOM", self, "BOTTOMLEFT", 1 + w * i / total, 1)
            t:Show()
        end
        for i = n + 1, #self.ticks do self.ticks[i]:Hide() end
    end
    -- The bar is always there and invisible while nothing is being made
    -- (docked in the Professions window it stays visible, empty).
    function bar:SetIdle(idle)
        if self.idle == idle then return end
        self.idle = idle
        self:SetAlpha(idle and 0 or 1)
        self:EnableMouse(not idle)
    end
    bar:SetScript("OnUpdate", function(self)
        -- docked: put back in the Professions window's strip if anything moved it
        if barDock and self:GetParent() ~= barDock then ApplyCraftBar() end
        local m = making
        if not m and barDock then
            -- docked and idle: an empty bar that says so
            self:SetIdle(false)
            self:Layout(1)
            self.fill:SetWidth(0.001)
            self.text:SetText("|cff9e9ea8Crafting progress: nothing being made|r")
            return
        end
        if not m then
            self:SetIdle(true)
            return
        end
        self:SetIdle(false)
        local now = GetTime()
        -- over: finished a moment ago, or nothing has been casting for a while
        if (m.finished and now - m.finished > 1.5) or (not m.castStart and m.idleAt and now - m.idleAt > 2.5) then
            StopMaking()
            return
        end
        local frac = 0
        if m.castStart and m.castEnd and m.castEnd > m.castStart then
            frac = math.max(0, math.min(1, (now - m.castStart) / (m.castEnd - m.castStart)))
        end
        local done = math.min(m.total, m.done + frac)
        self:Layout(m.total)
        self.fill:SetWidth(math.max(0.001, (self:GetWidth() - 2) * done / m.total))
        local left = m.per and math.ceil((m.total - done) * m.per)
        local count = ("%d / %d"):format(m.done, m.total)
        if left then count = count .. ("   %d:%02d left"):format(math.floor(left / 60), left % 60) end
        self.text:SetText(m.name and (m.name .. "   " .. count) or count)
    end)
    ApplyCraftBar()
    bar:SetIdle(true)
end


-- A batch of count crafts of a recipe has just been started.
local function StartMaking(rid, count)
    if not (db and JQ.IsEnabled(KEY) and JQ.IsEnabled(BAR_KEY)) then return end
    local total = math.max(1, math.floor(tonumber(count) or 1))
    if total <= 1 then
        -- some ways of crafting don't pass the count on: the profession window's "how many" box has it
        local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
        local box = page and page.CreateMultipleInputBox
        if box and box.GetValue then
            local ok, v = pcall(box.GetValue, box)
            if ok and tonumber(v) and tonumber(v) > total then total = math.floor(tonumber(v)) end
        end
    end
    local name
    if rid and C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo then
        local ok, info = pcall(C_TradeSkillUI.GetRecipeInfo, rid)
        name = ok and info and info.name or nil
    end
    making = { rid = rid, name = name, total = total, done = 0, idleAt = GetTime() }
    if not craftBar then BuildCraftBar() end
    craftBar.total = nil
    craftBar:Show()
    craftBar:SetIdle(false)
end

-- Every way a batch gets started ends in one of these two calls.
local craftsHooked = false
local function HookCrafts()
    if craftsHooked or not hooksecurefunc then return end
    craftsHooked = true
    if C_TradeSkillUI and C_TradeSkillUI.CraftRecipe then
        hooksecurefunc(C_TradeSkillUI, "CraftRecipe", function(rid, count)
            JQ.Try("crafting progress bar", StartMaking, rid, count)
        end)
    end
    if DoTradeSkill then
        hooksecurefunc("DoTradeSkill", function(_, count)
            JQ.Try("crafting progress bar", StartMaking, nil, count)
        end)
    end
end

-- UNIT_SPELLCAST_* for the player while a batch is being made
-- How many crafts of the batch the game still has queued, where the client can say (nil otherwise).
local function RepeatsLeft()
    for _, fn in ipairs({ C_TradeSkillUI and C_TradeSkillUI.GetRemainingRepeatCount, _G.GetTradeskillRepeatCount }) do
        if type(fn) == "function" then
            local ok, n = pcall(fn)
            if ok and type(n) == "number" and n >= 0 then return n end
        end
    end
end

local function CastEvent(event, unit, _, spellID)
    if not making or unit ~= "player" then return end
    -- the first cast after starting says which spell the batch is (recipe IDs aren't always the spell)
    if event == "UNIT_SPELLCAST_START" and not making.spell then making.spell = spellID end
    if making.spell and spellID and spellID ~= making.spell then return end
    local now = GetTime()
    if event == "UNIT_SPELLCAST_START" then
        local startMS, endMS
        if UnitCastingInfo then
            local _, _, _, s, e = UnitCastingInfo("player")
            startMS, endMS = s, e
        end
        if startMS and endMS and endMS > startMS then
            making.castStart, making.castEnd = startMS / 1000, endMS / 1000
            making.per = making.castEnd - making.castStart
        else
            making.castStart, making.castEnd = now, now + (making.per or 2)
        end
        making.idleAt = nil
        making.finished = nil
        -- another craft of the batch: never more done than the batch holds
        local left = RepeatsLeft()
        if left and left > 0 then making.total = math.max(making.total, making.done + left) end
        if making.done >= making.total then making.total = making.done + 1 end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        making.done = making.done + 1
        making.castStart, making.castEnd = nil, nil
        making.idleAt = now
        if making.done >= making.total and not making.finished then
            making.finished = now   -- the full bar stays a moment (unless another craft starts)
        end
    else
        -- interrupted or failed: over unless the next craft starts straight away
        making.castStart, making.castEnd = nil, nil
        making.idleAt = now
    end
end

-- The recipe in the open profession window that makes an item, or nil.
local function OpenRecipeFor(id)
    local T = C_TradeSkillUI
    if not (T and T.GetAllRecipeIDs and ProfessionsFrame and ProfessionsFrame:IsShown()) then return nil end
    for _, rid in ipairs(T.GetAllRecipeIDs() or {}) do
        local info = T.GetRecipeInfo and T.GetRecipeInfo(rid)
        local sch = info and info.learned and T.GetRecipeSchematic and T.GetRecipeSchematic(rid, false)
        if sch and sch.outputItemID == id then return rid end
    end
end

-- On the button's press: open the profession that makes it, so the release
-- (a second click of its own, a moment later) finds it open and makes it.
-- One click does both: switching profession and crafting each need a click.
local function MakePrepare(id)
    if not id or InCombatLockdown() or OpenRecipeFor(id) then return end
    local T = C_TradeSkillUI
    local known = JaseQoLDB.recipeIndex and JaseQoLDB.recipeIndex[id]
    local PV = JQ.ProfView
    local line = (type(known) == "table" and known.line)
        or (SMELT[id] and ((PV and PV.LineFor and PV.LineFor("Mining")) or MINING_LINE)) or nil
    if PV and PV.Debug then PV.Debug("make press %s: open line %s first", ItemName(id), tostring(line)) end
    if line and T and T.OpenTradeSkill then pcall(T.OpenTradeSkill, line) end
end

local function MakeNow(id, n)
    if not id or InCombatLockdown() then return end
    local name = ItemName(id)
    local T = C_TradeSkillUI
    if T and T.GetAllRecipeIDs and T.CraftRecipe and ProfessionsFrame then
        local open = ProfessionsFrame:IsShown()
        if open then
            for _, rid in ipairs(T.GetAllRecipeIDs() or {}) do
                local info = T.GetRecipeInfo and T.GetRecipeInfo(rid)
                local sch = info and info.learned and T.GetRecipeSchematic and T.GetRecipeSchematic(rid, false)
                if sch and sch.outputItemID == id then
                    local crafts = math.ceil(n / math.max(1, sch.quantityMin or 1))
                    local can = info.numAvailable
                    if can and can < 1 then
                        Status(("You can't make %s yet: the materials aren't in your bags."):format(name))
                        return
                    end
                    if can then crafts = math.min(crafts, can) end
                    if JQ.ProfView and JQ.ProfView.Debug then
                        JQ.ProfView.Debug("plan make %s: recipe %s in the open window, crafting %d (can %s)", name, tostring(rid), crafts, tostring(can))
                    end
                    -- through the Professions window (the game's own Create button) when it's there
                    if JQ.ProfView and JQ.ProfView.Active() and JQ.ProfView.CraftNow then
                        JQ.ProfView.CraftNow(rid, crafts, info.name or name)
                    else
                        T.CraftRecipe(rid, crafts)
                    end
                    Status(("Making %d %s."):format(crafts * math.max(1, sch.quantityMin or 1), name), true)
                    return
                end
            end
        end
        -- not in the open window (or none open): open the profession that makes
        -- it (remembered from when its recipes were read; bars are smelted)
        local known = JaseQoLDB.recipeIndex and JaseQoLDB.recipeIndex[id]
        local PV = JQ.ProfView
        local smelt = SMELT[id] and ((PV and PV.LineFor and PV.LineFor("Mining")) or MINING_LINE)
        local line = (type(known) == "table" and known.line) or smelt or nil
        local before = T.GetBaseProfessionInfo and select(2, pcall(T.GetBaseProfessionInfo))
        if PV and PV.Debug then PV.Debug("plan make %s: open line %s (known=%s smelt=%s)", name, tostring(line),
            tostring(type(known) == "table" and known.line), tostring(smelt)) end
        if line and T.OpenTradeSkill and pcall(T.OpenTradeSkill, line) then
            -- only say it opened once it has: check a moment later
            C_Timer.After(0.6, function()
                local ok, now = pcall(T.GetBaseProfessionInfo)
                local opened = ok and type(now) == "table" and now.professionID == line
                    and not (type(before) == "table" and before.professionID == line)
                if PV and PV.Debug then PV.Debug("  0.6s later: %s id=%s", tostring(ok and now and now.professionName), tostring(ok and now and now.professionID)) end
                if opened then
                    -- the recipe ready in the window: the next click makes it
                    if PV and PV.SelectOutput then pcall(PV.SelectOutput, id) end
                    Status(("Opened %s for %s. Click make again."):format(now.professionName or "the profession", name))
                else
                    Status(("The game didn't open the profession for %s from here. Open %s yourself (spellbook), then click make: from then on it's known."):format(
                        name, SMELT[id] and "Smelting" or "it"))
                end
            end)
            return
        end
        Status(open and ("%s isn't in the open profession window. Open the profession that makes it, then click make."):format(name)
            or ("Open the profession that makes %s, then click make."):format(name))
        return
    end
    -- the old trade skill window
    if TradeSkillFrame and TradeSkillFrame:IsShown() and GetNumTradeSkills and DoTradeSkill then
        for i = 1, GetNumTradeSkills() do
            local link = GetTradeSkillItemLink and GetTradeSkillItemLink(i)
            if link and tonumber(link:match("item:(%d+)")) == id then
                local per = GetTradeSkillNumMade and GetTradeSkillNumMade(i) or 1
                local crafts = math.ceil(n / math.max(1, per))
                DoTradeSkill(i, crafts)
                return
            end
        end
    end
    Status(("Open the profession that makes %s, then click make."):format(name))
end

-- One row per item of a step kept in one place (field = "bags" / "bank" /
-- "mail"), by name: its icon, "40 Rugged Leather" and the place on the right.
local function PlaceRows(lines, items, field, tag, now)
    local ids = {}
    for id, e in pairs(items) do
        if (e[field] or 0) > 0 then ids[#ids + 1] = id end
    end
    table.sort(ids, function(a, b) return ItemName(a) < ItemName(b) end)
    for _, id in ipairs(ids) do
        lines[#lines + 1] = { sub = true, now = now, item = id, text = ItemText(id, items[id][field]), tag = tag }
    end
end

-- { {text, now, head, sub, gap, item, tag, auto}, ... } for every open request on
-- this realm: a line per step, under it a row per item (where it is) and what
-- to do with them
local function MiniLines()
    local me = Alts.MyName()
    local lines, names = {}, {}
    for recipient in pairs(RealmRequests()) do names[#names + 1] = recipient end
    table.sort(names, function(a, b)
        if (a == me) ~= (b == me) then return a == me end
        return a < b
    end)
    for _, recipient in ipairs(names) do
        local r = RequestOf(recipient)
        local steps, short = Plan(recipient)
        steps = steps or {}
        local inPlan, sent = {}, {}
        for _, s in ipairs(steps) do inPlan[s.alt] = true end
        -- an alt with more still to send shows as a step, not as done
        for alt in pairs(r.done or {}) do
            if not inPlan[alt] then sent[#sent + 1] = alt end
        end
        table.sort(sent)
        local own = OwnFetch(recipient)
        local collect = #steps > 0 or #sent > 0
        local makes = MakeLeft(recipient)
        local buy = {}
        for id, k in pairs(short or {}) do buy[#buy + 1] = { id = id, n = k } end
        table.sort(buy, function(a, b) return ItemName(a.id) < ItemName(b.id) end)
        local total = #sent + #steps + (#own > 0 and 1 or 0) + (collect and 1 or 0) + (#buy > 0 and 1 or 0) + (#makes > 0 and 1 or 0)
        do
            lines[#lines + 1] = { head = true, text = total > 0 and ("For %s  |cff9e9ea8step %d of %d|r"):format(
                NameOf(recipient), math.min(#sent + 1, total), total) or ("For " .. NameOf(recipient)) }
            for _, alt in ipairs(sent) do
                lines[#lines + 1] = { text = ("%s %s  |cff9e9ea8sent %d|r"):format(TICK, NameOf(alt), Sum(r.done[alt])) }
            end
            local n = #sent
            -- the requester's own bank run comes first: it needs no one else
            if #own > 0 then
                n = n + 1
                local mineStep = recipient == me
                lines[#lines + 1] = { now = true, gap = true, text = ("%d. %s  |cff9e9ea8bank run|r"):format(n,
                    mineStep and "|cffffd25aThis character|r" or ("Log in on " .. NameOf(recipient))) }
                local fromBank = 0
                for _, e in ipairs(own) do
                    if e.bank > 0 then
                        fromBank = fromBank + e.bank
                        lines[#lines + 1] = { sub = true, now = true, item = e.id, text = ItemText(e.id, e.bank), tag = "in your bank" }
                    end
                end
                for _, e in ipairs(own) do
                    if e.mail > 0 then
                        lines[#lines + 1] = { sub = true, now = true, item = e.id, text = ItemText(e.id, e.mail), tag = "take out of your mail" }
                    end
                end
                if fromBank > 0 then
                    lines[#lines + 1] = { sub = true, now = true, auto = "bank", text = mineStep
                        and ("|cffffffffBank:|r open it and press Take from bank (%d item%s)"):format(fromBank, fromBank == 1 and "" or "s")
                        or ("|cffffffffBank:|r take out %d item%s"):format(fromBank, fromBank == 1 and "" or "s") }
                end
                local fromMail = 0
                for _, e in ipairs(own) do fromMail = fromMail + e.mail end
                if fromMail > 0 then
                    lines[#lines + 1] = { sub = true, now = true, auto = "mail",
                        text = ("|cffffffffMailbox:|r take %d item%s out of the mail"):format(fromMail, fromMail == 1 and "" or "s") }
                end
            end
            for i, s in ipairs(steps) do
                n = n + 1
                local mineStep = s.alt == me
                local now = (i == 1) or mineStep
                local count, inBank, inMail = 0, 0, 0
                for _, e in pairs(s.items) do
                    count = count + (e.bags or 0) + (e.bank or 0) + (e.mail or 0)
                    inBank, inMail = inBank + (e.bank or 0), inMail + (e.mail or 0)
                end
                local where = not mineStep and Alts.WhereText(s.alt)
                lines[#lines + 1] = { now = now, gap = true, text = ("%d. %s%s"):format(n,
                    mineStep and "|cffffd25aThis character|r" or ("Log in on " .. NameOf(s.alt)),
                    where and ("  |cff9e9ea8" .. where .. (s.town and "" or " - no bank here") .. "|r") or "") }
                PlaceRows(lines, s.items, "bank", "in the bank", now)
                PlaceRows(lines, s.items, "mail", "in the mail", now)
                PlaceRows(lines, s.items, "bags", "in bags", now)
                if inBank > 0 then
                    lines[#lines + 1] = { sub = true, now = now, auto = "bank",
                        text = ("|cffffffffBank:|r take %d item%s out"):format(inBank, inBank == 1 and "" or "s") }
                end
                if inMail > 0 then
                    lines[#lines + 1] = { sub = true, now = now, auto = "mail",
                        text = ("|cffffffffMailbox:|r take %d item%s out of the mail"):format(inMail, inMail == 1 and "" or "s") }
                end
                lines[#lines + 1] = { sub = true, now = now, auto = "send", text = ("|cffffffffMailbox:|r send %d item%s to %s"):format(
                    count, count == 1 and "" or "s", NameOf(recipient)) }
            end
            if collect then
                lines[#lines + 1] = { now = #steps == 0, gap = true, text = ("%d. %s"):format(n + 1,
                    recipient == me and "|cffffd25aThis character|r" or ("Log in on " .. NameOf(recipient))) }
                lines[#lines + 1] = { sub = true, now = #steps == 0, auto = "mail", text = "|cffffffffMailbox:|r collect the mail" }
            end
            if collect then n = n + 1 end
            -- what no alt has: the auction house (or farm it), before anything is made from it
            if #buy > 0 then
                n = n + 1
                local mineStep = recipient == me
                local bags, bank, mail = Holdings(recipient)
                lines[#lines + 1] = { now = true, gap = true, text = ("%d. %s  |cff9e9ea8auction house|r"):format(n,
                    mineStep and "|cffffd25aThis character|r" or ("Log in on " .. NameOf(recipient))) }
                local cost, priced = 0, 0
                for i, b in ipairs(buy) do
                    if i > 6 then
                        lines[#lines + 1] = { sub = true, text = ("and %d more - see Details"):format(#buy - 6) }
                        break
                    end
                    local e = r.items[b.id]
                    local have = (bags[b.id] or 0) + (bank[b.id] or 0) + (mail[b.id] or 0)
                    local got = e and e.base and math.max(0, have - e.base) or 0
                    local price = JQ.CostToBuy and JQ.CostToBuy(b.id, b.n)
                    if price then cost, priced = cost + price, priced + 1 end
                    lines[#lines + 1] = { sub = true, now = true, item = b.id, text = ItemText(b.id, b.n),
                        tag = got > 0 and ("|cff59d959bought %d|r"):format(math.min(got, b.n))
                            or (price and Money(price)) or "no price yet" }
                end
                local api = ShoppingListAPI() ~= nil
                lines[#lines + 1] = { sub = true, now = true, text = ("|cffffffffAuction house:|r buy %s%s"):format(
                    #buy == 1 and "it" or "them",
                    (priced > 0 and ("  |cff9e9ea8about %s|r"):format(Money(cost)) or "")
                    .. (api and (mineStep and "  |cff9e9ea8(press Shopping list there)|r" or "") or "  |cff9e9ea8(or farm it)|r")) }
            end
            -- last: what the requester makes itself once the materials are in its bags
            if #makes > 0 then
                local ready = #steps == 0 and #own == 0 and #buy == 0
                lines[#lines + 1] = { now = ready, gap = true, text = ("%d. %s  |cff9e9ea8make|r"):format(n + 1,
                    recipient == me and "|cffffd25aThis character|r" or ("Log in on " .. NameOf(recipient))) }
                local bags, bank, mail = Holdings(recipient)
                for _, m in ipairs(makes) do
                    local rec = MakeRecipe(m.id, recipient)
                    lines[#lines + 1] = { sub = true, now = ready, item = m.id, text = ItemText(m.id, m.n),
                        tag = recipient == me and "click to make" or "make", make = recipient == me and m or nil }
                    -- what it's made from, each with what's on hand (bags, then bank / mail)
                    local crafts = rec and math.ceil(m.n / math.max(1, rec.n or 1)) or 0
                    local ids = {}
                    for rid in pairs(rec and rec.r or {}) do ids[#ids + 1] = rid end
                    table.sort(ids, function(a, b) return ItemName(a) < ItemName(b) end)
                    for _, rid in ipairs(ids) do
                        local need = crafts * rec.r[rid]
                        local inBags = bags[rid] or 0
                        local away = (bank[rid] or 0) + (mail[rid] or 0)
                        local col = inBags >= need and "59d959" or (inBags + away >= need and "ffd25a" or "ff7070")
                        lines[#lines + 1] = { deep = true, now = ready, item = rid, text = ItemText(rid, need),
                            tag = ("|cff%shave %d|r%s"):format(col, inBags, away > 0 and ("  |cff9e9ea8+%d bank/mail|r"):format(away) or ""),
                            soh = { need = need, bags = inBags, bank = bank[rid] or 0, mail = mail[rid] or 0, who = recipient } }
                    end
                end
            end
        end
    end
    return lines
end

-- This character's own request is over: drop it and say so.
function FinishRequest(msg)
    local me = Alts.MyName()
    if not (me and RealmRequests()[me]) then return end
    RealmRequests()[me] = nil
    if msg then JQ.Print(msg) end
    if win and win:IsShown() then win:Refresh() end
    QueueMini()
end

-- Everything was sent to this character and none of it is in its mailbox any
-- more (as the mailbox was when last looked at): the request is finished.
-- Not decided while the mail window is open: the inbox may still be loading.
local function CheckCollected()
    local me = db and Alts and Alts.MyName()
    local r = me and RequestOf(me)
    if not r or next(r.items) or not (r.done and next(r.done)) then return end
    if MailFrame and MailFrame:IsShown() then return end
    local data = Alts.RealmTable()[me]
    local mail = (data and data.mail) or {}
    for _, sent in pairs(r.done) do
        for id in pairs(sent) do
            if (mail[id] or 0) > 0 then return end
        end
    end
    if r.own and next(r.own) then
        -- the mail is in; the bank run is still to do
        r.done = nil
        JQ.Print("Everything sent has been collected. Your own bank run is still on the plan.")
        return
    end
    FinishRequest("Request finished: everything has been collected.")
end

-- The "auto" tick at the right of an action line. One setting per kind of
-- action (bank / mail / send): every line of that kind shows the same tick.
local AUTO_TIP = {
    bank = "Takes the items out of the bank by itself as soon as you open the bank.",
    mail = "Takes the items out of the mail by itself as soon as you open a mailbox.",
    send = "Sends the mail by itself as soon as you open a mailbox, once everything is in your bags.",
}
local function AutoCheck(row)
    local c = CreateFrame("Button", nil, row)
    c:SetSize(46, 14)
    c:SetPoint("TOPRIGHT", 0, 0)
    c.box = CreateFrame("Frame", nil, c)
    c.box:SetSize(11, 11)
    c.box:SetPoint("RIGHT", -1, 0)
    UI.Fill(c.box, 0, 0, 0, 0.5)
    UI.Border(c.box)
    c.tick = c.box:CreateTexture(nil, "OVERLAY")
    c.tick:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    c.tick:SetPoint("TOPLEFT", -2, 2)
    c.tick:SetPoint("BOTTOMRIGHT", 2, -2)
    c.label = UI.Text(c, 10, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3], "RIGHT")
    c.label:SetPoint("RIGHT", c.box, "LEFT", -4, 0)
    c.label:SetText("auto")
    c:SetScript("OnClick", function(self)
        db.auto[self.kind] = (not db.auto[self.kind]) or nil
        QueueMini()
    end)
    c:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Automatic", 1, 1, 1)
        GameTooltip:AddLine(AUTO_TIP[self.kind] or "", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("One switch for every step of this kind, on all your characters.", 0.62, 0.62, 0.66, true)
        GameTooltip:Show()
    end)
    c:SetScript("OnLeave", UI.HideTip)
    return c
end

local function BuildMini()
    db.mini = db.mini or {}
    mini = CreateFrame("Frame", "JaseQoLRequestMini", UIParent)
    mini:SetWidth(MINI_W)
    mini:SetFrameStrata("MEDIUM")
    mini:SetClampedToScreen(true)
    UI.Fill(mini, 0.045, 0.045, 0.05, 0.92)
    UI.Border(mini)
    -- anchored by its top left corner, so it grows downwards as steps are added
    function mini:Place()
        self:ClearAllPoints()
        if dockHost then
            -- docked: part of that window, not a floating box
            self:SetParent(dockHost)
            self:SetPoint("TOPLEFT", dockHost, "TOPLEFT", 0, 0)
            self:SetFrameLevel(dockHost:GetFrameLevel() + 2)
            -- (that window has its own heading and close button)
            if self.title then self.title:Hide() end
            if self.close then self.close:Hide() end
            return
        end
        if self.title then self.title:Show() end
        if self.close then self.close:Show() end
        self:SetParent(UIParent)
        self:SetFrameStrata("MEDIUM")
        local pos = db.mini.pos
        if pos then
            self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos[1], pos[2])
        else
            self:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -220)
        end
    end
    mini:Place()
    mini:EnableMouse(true)
    mini:SetMovable(true)
    mini:RegisterForDrag("LeftButton")
    mini:SetScript("OnDragStart", function(self) if not dockHost then self:StartMoving() end end)
    mini:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if dockHost then return end
        local x, y = self:GetLeft(), self:GetTop()
        if x and y then db.mini.pos = { x, y } end
        self:Place()
    end)

    mini.title = UI.Text(mini, 12)
    mini.title:SetPoint("TOPLEFT", 10, -8)
    mini.title:SetText(("|cff%sRequest plan|r"):format(UI.AccentHex()))
    local close = UI.Button(mini, "x", 18, 18)
    mini.close = close
    close:SetPoint("TOPRIGHT", -5, -5)
    close.text:ClearAllPoints()   -- the usual side padding leaves no room for the x
    close.text:SetPoint("CENTER")
    close:SetScript("OnClick", function()
        miniHidden = true
        mini:Hide()
        JQ.Print("Request plan hidden until you log in again or make a new request. The Requests tab still has it.")
    end)

    mini.lines = {}
    mini.action = UI.Button(mini, "", 144, 22)
    mini.action:SetPoint("BOTTOMLEFT", 10, 8)
    mini.action:SetScript("OnClick", function(self)
        if self.run then JQ.Try("request plan popout: button", self.run) end
        QueueMini()
    end)
    mini.action:SetScript("OnMouseDown", function(self, button)
        if self.prep and button == "LeftButton" and self:IsEnabled() then JQ.Try("request plan popout: button", self.prep) end
    end)
    mini.details = UI.Button(mini, "Details", 144, 22)
    mini.details:SetPoint("BOTTOMRIGHT", -10, 8)
    -- shows the Requests tab, or closes it when it's the one already open
    mini.details:SetScript("OnClick", function()
        if win and win:IsShown() then win:Hide() else JQ.Hub.Show("requests") end
    end)
end

local function RefreshMini()
    -- docked in the Professions window it always shows (that window asked for it)
    local show = db and Alts and Alts.MyName() and JQ.IsEnabled(KEY) and next(RealmRequests()) ~= nil
        and (dockHost ~= nil or (not miniHidden and JQ.IsEnabled(MINI_KEY)))
    local lines = show and MiniLines() or {}
    if #lines == 0 then
        if mini then mini:Hide() end
        return
    end
    if not mini then BuildMini() end
    if mini.dockedTo ~= dockHost then
        mini.dockedTo = dockHost
        mini:Place()
    end
    -- text lines wrap, so each row is placed under the one before by its real height
    local y = dockHost and 8 or 30
    for i, d in ipairs(lines) do
        local row = mini.lines[i]
        if not row then
            row = CreateFrame("Button", nil, mini)
            UI.Fill(row, 1, 1, 1, 0.06, "HIGHLIGHT")
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(14, 14)
            row.icon:SetPoint("LEFT", 1, 0)
            row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            row.tag = UI.Text(row, 10, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3], "RIGHT")
            row.tag:SetPoint("RIGHT", -2, 0)
            row.text = UI.Text(row, 11)
            row.text:SetJustifyV("TOP")
            row:SetScript("OnEnter", function(self)
                UI.ItemEnter(self)
                -- a material: what's on hand, where, and on your alts
                local soh = self.soh
                if not (soh and self.itemID and GameTooltip:IsOwned(self)) then return end
                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine("Needed", tostring(soh.need), 1, 0.82, 0.35, 1, 1, 1)
                local function line(label, n, r, g, b)
                    if n > 0 then GameTooltip:AddDoubleLine(label, tostring(n), r or 0.9, g or 0.9, b or 0.9, 1, 1, 1) end
                end
                line("In bags", soh.bags, 0.35, 0.85, 0.35)
                line("In the bank", soh.bank)
                line("In the mail", soh.mail)
                if soh.bags + soh.bank + soh.mail == 0 then GameTooltip:AddLine("None on this character", 1, 0.44, 0.44) end
                for name, data in pairs(Alts.RealmTable()) do
                    if name ~= soh.who then
                        local b, k, m = Holdings(name)
                        local n = (b[self.itemID] or 0) + (k[self.itemID] or 0) + (m[self.itemID] or 0)
                        if n > 0 then
                            GameTooltip:AddDoubleLine(Alts.Display(name), tostring(n), UI.QualityColor(1))
                        end
                    end
                end
                local missing = soh.need - soh.bags
                if missing > 0 then
                    GameTooltip:AddLine(soh.bags + soh.bank + soh.mail >= soh.need
                        and ("Take %d out of the bank or mail first."):format(missing)
                        or ("Short by %d."):format(soh.need - soh.bags - soh.bank - soh.mail), 1, 0.82, 0.35, true)
                end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", UI.HideTip)
            row:SetScript("OnMouseDown", function(self, button)
                if self.make and button == "LeftButton" and not IsModifiedClick("CHATLINK") then
                    JQ.Try("request plan popout: make", MakePrepare, self.make.id)
                end
            end)
            row:SetScript("OnClick", function(self)
                -- a "make" row crafts; any other item row links the item with shift
                if self.make and not IsModifiedClick("CHATLINK") then
                    JQ.Try("request plan popout: make", MakeNow, self.make.id, self.make.n)
                else
                    UI.ItemClick(self)
                end
            end)
            -- dragging a row moves the popout, like dragging its background
            row:RegisterForDrag("LeftButton")
            row:SetScript("OnDragStart", function() mini:GetScript("OnDragStart")(mini) end)
            row:SetScript("OnDragStop", function() mini:GetScript("OnDragStop")(mini) end)
            mini.lines[i] = row
        end
        local indent = (d.deep and 32) or (d.sub and 16) or 0
        local w = MINI_W - 20 - indent
        if d.gap or d.head then y = y + (i > 1 and 6 or 0) end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 10 + indent, -y)
        row:SetWidth(w)
        row.itemID = d.item
        row.make = d.make
        row.soh = d.soh
        row.text:ClearAllPoints()
        local h
        if d.item then
            row.icon:SetTexture(UI.ItemIcon(d.item))
            row.icon:Show()
            row.tag:SetText(d.tag or "")
            row.tag:Show()
            row.text:SetWordWrap(false)
            row.text:SetPoint("LEFT", 20, 0)
            row.text:SetPoint("RIGHT", row.tag, "LEFT", -6, 0)
            row.text:SetText(d.text)
            row:EnableMouse(true)
            h = 17
        else
            row.icon:Hide()
            row.tag:Hide()
            row.text:SetWordWrap(true)
            row.text:SetPoint("TOPLEFT")
            row.text:SetWidth(w - (d.auto and 50 or 0))
            row.text:SetText(d.text)
            row:EnableMouse(false)
            h = math.max(MINI_LINE, math.ceil(row.text:GetStringHeight() or 0))
        end
        if d.auto then
            row.check = row.check or AutoCheck(row)
            row.check.kind = d.auto
            row.check.tick:SetShown(db.auto[d.auto] and true or false)
            row.check:Show()
        elseif row.check then
            row.check:Hide()
        end
        if d.head or d.now then
            row.text:SetTextColor(0.9, 0.9, 0.92)
        else
            row.text:SetTextColor(UI.MUTED[1], UI.MUTED[2], UI.MUTED[3])
        end
        row:SetAlpha((d.item and not d.now) and 0.7 or 1)
        row:SetHeight(h)
        row:Show()
        y = y + h + 2
    end
    for i = #lines + 1, #mini.lines do mini.lines[i]:Hide() end

    -- this character's step, as one button
    local mine = MyJobs()[1]
    local b = mini.action
    local req = RequestOf(Alts.MyName())
    local cands = {}
    if next((BankPulls())) then
        -- for an alt's job or this character's own bank run: one press moves it all
        cands[#cands + 1] = { "Take from bank", PullFromBank, Alts.IsBankOpen() }
    end
    if next(MailWants()) then
        cands[#cands + 1] = { "Take from mail", StartTake, mailOpen and not taking and not job }
    end
    if mine then
        cands[#cands + 1] = { "Send", function() StartSend(mine.to) end, mailOpen and not job and not taking }
    end
    -- at the auction house: the shopping list of what no alt has
    local ahOpen = (AuctionHouseFrame and AuctionHouseFrame:IsShown()) or (AuctionFrame and AuctionFrame:IsShown())
    if ahOpen and ShoppingListAPI() then
        local toBuy, order = BuyList(Alts.MyName())
        if #order > 0 then
            table.insert(cands, 1, { "Shopping list", function() MakeShoppingList(order, toBuy) end, true })
        end
    end
    local toMake = MakeLeft(Alts.MyName())[1]
    if toMake then
        cands[#cands + 1] = { ("Make %d"):format(toMake.n), function() MakeNow(toMake.id, toMake.n) end, true,
            function() MakePrepare(toMake.id) end }
    end
    if #cands == 0 and req and not next(req.items) then
        -- nothing left for anyone to send: finish by hand if it's still listed
        cands[1] = { "Done", function() FinishRequest("Request finished.") end, true }
    end
    -- what can be done right here first; making comes last, once nothing is left to fetch
    local pick = cands[1]
    for _, c in ipairs(cands) do
        if c[3] and (c ~= cands[#cands] or not toMake or #cands == 1) then pick = c; break end
    end
    if pick then
        b.text:SetText(pick[1])
        b.run = pick[2]
        b.prep = pick[4]
        b:SetEnabledLook(pick[3] and true or false)
        b:Show()
    else
        b:Hide()
    end
    mini:SetHeight(y + 38)
    mini:Show()
end

-- Redraw shortly (many events arrive together). show = a hidden popout comes back.
function QueueMini(show)
    if show then miniHidden = false end
    if miniQueued then return end
    miniQueued = true
    C_Timer.After(0.3, function()
        miniQueued = false
        JQ.Try("requests: checking the bank run", TidyOwn)
        JQ.Try("requests: checking the mail was collected", CheckCollected)
        JQ.Try("requests: automatic steps", AutoRun)
        JQ.Try("request plan popout", RefreshMini)
    end)
end

JQ.byKey[MINI_KEY].onEnable = function() QueueMini(true) end
JQ.byKey[MINI_KEY].onDisable = function() if mini then mini:Hide() end end

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

-- line: the skill line of the profession window it was read in (so "make"
-- can open that window by itself later)
local function Record(outID, n, reagents, line)
    if not outID or not next(reagents) then return end
    local idx = Index()
    local e = idx[outID] or { by = {} }
    e.n, e.r = math.max(1, n or 1), reagents
    if line then e.line = line end
    e.by[Alts.MyName()] = true
    idx[outID] = e
end

local function ScanRecipes()
    local T = C_TradeSkillUI
    if T and T.GetAllRecipeIDs and ProfessionsFrame and ProfessionsFrame:IsShown() then
        if (T.IsTradeSkillLinked and T.IsTradeSkillLinked()) or (T.IsTradeSkillGuild and T.IsTradeSkillGuild()) then return end
        local line
        if T.GetBaseProfessionInfo then
            local ok, prof = pcall(T.GetBaseProfessionInfo)
            line = ok and type(prof) == "table" and prof.professionID or nil
        end
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
                    Record(sch.outputItemID, sch.quantityMin, r, line)
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
        if not (rec and rec.r) then
            -- not read from a profession window yet: smelting is known up front
            local known, can = MakeRecipe(id, me)
            if known and can then rec = { n = known.n, r = known.r, by = { [me] = true } } end
        end
        if rec and rec.r and depth < 3 and not seen[id] then
            local makes = math.ceil(still / (rec.n or 1))
            row.kind, row.make, row.makeQty = "make", makes, still
            row.maker = rec.by and (rec.by[me] and "you" or next(rec.by)) or nil
            seen[id] = true
            for rid, q in pairs(rec.r) do walk(rid, q * makes, depth + 1, seen) end
            seen[id] = nil
        else
            -- not seen anywhere yet: still asked for, the plan lists it as short
            row.kind, row.buyQty = "missing", still
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
        local _, reagents = Reagents()
        PlanOwn(Alts.MyName(), (Breakdown(reagents or {}, n)))
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
    -- the Professions window has its own materials pane
    if JQ.ProfView and (JQ.ProfView.Active() or (frame == ProfessionsFrame and JQ.ProfView.Wanted())) then return end
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
local profHooked, mailHooked = false, false
local function HasJobs() return #MyJobs() > 0 end

ev:SetScript("OnEvent", function(_, event, ...)
    if not JQ.IsEnabled(KEY) then return end
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_SUCCEEDED"
        or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
        if making then JQ.Try("crafting progress bar", CastEvent, event, ...) end
        return
    end
    if MINI_EVENTS[event] then QueueMini() end
    if event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
        JQ.Try("requests: learning vendor items", LearnVendor)
        for recipient in pairs(RealmRequests()) do Tidy(recipient) end
        return
    elseif event == "TRADE_SKILL_LIST_UPDATE" then
        C_Timer.After(0.3, function() JQ.Try("requests: reading recipes", ScanRecipes) end)
        return
    end
    if event == "TRADE_SKILL_SHOW" then
        C_Timer.After(0.5, function() JQ.Try("requests: reading recipes", ScanRecipes) end)
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
        -- the window closing is what settles whether the mail was collected
        if MailFrame and not mailHooked then
            mailHooked = true
            MailFrame:HookScript("OnHide", function() QueueMini() end)
        end
        -- (the plan popout shows the job and its buttons: the full tab only without it)
        if HasJobs() and not JQ.IsEnabled(MINI_KEY) then JQ.Hub.Show("requests") end
    elseif event == "MAIL_INBOX_UPDATE" then
        inboxSeen = true
    elseif event == "MAIL_CLOSED" then
        mailOpen, inboxSeen, taking = false, false, nil
        if job then FinishSend("Mailbox closed: stopped.") end
        if win and win:IsShown() then win:Refresh() end
    elseif event == "BANKFRAME_OPENED" or (event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW"
        and Enum and Enum.PlayerInteractionType and (... == Enum.PlayerInteractionType.Banker
        or ... == Enum.PlayerInteractionType.CharacterBanker)) then
        if HasJobs() and not JQ.IsEnabled(MINI_KEY) then C_Timer.After(0.2, function() JQ.Hub.Show("requests") end) end
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
        -- what I've sent, so the plan popout can tick this step off on every character
        local me = Alts.MyName()
        if r and me and job.batch and next(job.batch) then
            r.done = r.done or {}
            r.done[me] = r.done[me] or {}
            for id, n in pairs(job.batch) do r.done[me][id] = (r.done[me][id] or 0) + n end
        end
        Alts.AddMail(job.to, job.batch or {})
        job.batch = nil
        Tidy(job.to)
        C_Timer.After(0.4, SendNext)
    elseif event == "MAIL_FAILED" then
        if job then ClearSendMail(); FinishSend("The mail failed: stopped.") end
    elseif event == "PLAYER_REGEN_ENABLED" then
        JQ.Try("requests: fill crate button", SyncFill)
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
            -- the plan popout shows the job; without it, open the Requests tab
            -- straight away (not in combat, not over another JaseTools tab)
            if not JQ.IsEnabled(MINI_KEY) and not InCombatLockdown() and not (JQ.Hub.IsOpen and JQ.Hub.IsOpen()) then
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
            QueueMini()
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
    db.auto = db.auto or {}
    HookCrafts()
    for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "TRADE_SKILL_UPDATE",
        "TRADE_SKILL_LIST_UPDATE", "MERCHANT_SHOW", "MERCHANT_UPDATE",
        "CRAFT_SHOW", "CRAFT_CLOSE", "CRAFT_UPDATE", "MAIL_SHOW", "MAIL_CLOSED", "MAIL_INBOX_UPDATE", "MAIL_SEND_SUCCESS", "MAIL_FAILED",
        "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED",
        "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "BAG_UPDATE_DELAYED", "PLAYER_INTERACTION_MANAGER_FRAME_SHOW",
        "PLAYER_INTERACTION_MANAGER_FRAME_HIDE", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    Alts.OnChange(function()
        if win and win:IsShown() then win:Refresh() end
        QueueMini()
    end)
end
JQ.byKey[KEY].onEnable = function() QueueMini(true) end
JQ.byKey[KEY].onDisable = function()
    HideSide()
    if win then win:Hide() end
    if mini then mini:Hide() end
    StopMaking()
end
JQ.byKey[BAR_KEY].onDisable = function() StopMaking() end

-- Plan the materials of N crafts of something: the bank run, the request to
-- alts, what to make, and the buy list (an Auctionator shopping list when
-- Auctionator is there). Planning the same label again takes the earlier plan's
-- asks back out first, so nothing doubles. list = { {id, per}, ... }.
local function PlanFor(label, list, crafts, title)
    local me = Alts and Alts.MyName()
    if not (me and label) then return false end
    title = title or label
    local mine = RequestOf(me)
    local again = false
    if mine then
        for id, n in pairs((mine.plans and mine.plans[label]) or {}) do
            local e = mine.items[id]
            if e then e.need = math.max(e.sent or 0, (e.need or 0) - n) end
        end
        if mine.plans then mine.plans[label] = nil end
        for i = #(mine.recipes or {}), 1, -1 do
            if mine.recipes[i] == label then
                table.remove(mine.recipes, i)
                again = true
            end
        end
    end
    local rows, request, tot = Breakdown(list, crafts or 1)
    local own, made = PlanOwn(me, rows)
    if not next(request) and own == 0 and made == 0 then
        if again then AddRequest(me, {}, nil) end   -- tidies away what was taken back out
        JQ.Print(tot.vendor > 0 and ("Nothing to plan for %s: the rest is sold by vendors."):format(title)
            or ("Nothing to plan for %s: it's all in your bags."):format(title))
        return false
    end
    AddRequest(me, request, label)
    if next(request) then
        local r = RequestOf(me)
        if r then
            r.plans = r.plans or {}
            r.plans[label] = {}
            for id, n in pairs(request) do r.plans[label][id] = n end
        end
    end
    if again then JQ.Print(("Planned %s again, from what you have now."):format(label)) end
    if own > 0 then JQ.Print(("Bank run for %s: %d item(s) to take from your own bank or mail."):format(label, own)) end
    if made > 0 then
        local parts = {}
        for _, e in ipairs(rows) do
            if e.kind == "make" and (e.makeQty or 0) > 0 then parts[#parts + 1] = ItemText(e.id, e.makeQty) end
        end
        JQ.Print("To make yourself: " .. table.concat(parts, ", ") .. ". The plan gathers what they're made from.")
    end
    if next(request) then
        local parts = {}
        for id, n in pairs(request) do parts[#parts + 1] = ItemText(id, n) end
        JQ.Print(("Requested for %s: %s."):format(label, table.concat(parts, ", ")))
    end
    local toBuy, order = BuyList(me)
    if #order > 0 then
        if ShoppingListAPI() then
            MakeShoppingList(order, toBuy)
        else
            JQ.Print(("%d item(s) are on no alt: the Requests tab lists what to buy."):format(#order))
        end
    end
    return true
end

-- for other modules (Mastercraft's Request from alts button)
JQ.Requests = {
    PlanFor = PlanFor, HideSide = function() HideSide() end, MakeNow = MakeNow, MakePrepare = MakePrepare,
    -- the crafting progress bar along the bottom of another window (nil: back where you put it)
    DockBar = function(host)
        if not (JQ.IsEnabled(KEY) and JQ.IsEnabled(BAR_KEY)) then host = nil end
        barDock = host
        if host and not craftBar then BuildCraftBar() end
        if craftBar then
            craftBar.idle = nil
            ApplyCraftBar()
            craftBar:Show()
            if not making and not host then craftBar:SetIdle(true) end
        end
        return host ~= nil
    end,
    -- this character's own plan: is there one, and drop all of it
    HasPlan = function() local me = Alts and Alts.MyName(); return me ~= nil and RequestOf(me) ~= nil end,
    Cancel = function() FinishRequest("Plan cancelled.") end,
    MakeRecipe = MakeRecipe, IsVendor = function(id) return IsVendor(id) end, Money = Money,
    Dock = function(host) dockHost = host; QueueMini() end,
    Undock = function()
        dockHost = nil
        if mini then
            mini.dockedTo = nil
            mini:Place()
        end
        QueueMini()
    end,
    PlanShown = function() return mini ~= nil and mini:IsShown() end, Breakdown = Breakdown, AddRequest = AddRequest, RequestOf = RequestOf, BuyList = BuyList,
    AddOwn = AddOwn, OwnFetch = OwnFetch, Holdings = Holdings, PlanOwn = PlanOwn, MakeLeft = MakeLeft,
    MakeShoppingList = MakeShoppingList, ShoppingListAPI = ShoppingListAPI, ItemText = ItemText, NameIndex = NameIndex }

-- for tests
JQ._AltRequest = { Breakdown = Breakdown, ScanRecipes = ScanRecipes, IsVendor = IsVendor, Plan = Plan, MyJobs = MyJobs, AddRequest = AddRequest, Remaining = Remaining,
    PullFromBank = PullFromBank, StartSend = StartSend, Rows = Rows, FillableCrates = FillableCrates,
    MailWants = MailWants, BankPulls = BankPulls, AutoRun = AutoRun, MakeNow = MakeNow, MakePrepare = MakePrepare,
    Making = function() return making end, StartMaking = StartMaking, CastEvent = CastEvent,
    BarFrame = function() return craftBar end,
    ApplyCraftBar = function() ApplyCraftBar() end,
    ParseBundles = ParseBundles, MyCrates = MyCrates, BestBundle = BestBundle, NameIndex = NameIndex }
