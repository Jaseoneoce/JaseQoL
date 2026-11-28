-------------------------------------------------------------------------------
--  JaseTools: sales ledger
--
--  Records everything you put on the auction house and what became of it, so
--  the craft advisor (MarketBrain.lua) can learn what really sells.
--
--  Captured (account-wide, one book per realm + faction):
--    posts      C_AuctionHouse.PostItem / PostCommodity (the game's sell
--               window and Auctionator both go through them): item, quantity,
--               unit price, duration, deposit, the market's lowest price at
--               the time, what it cost to make, and what the advisor
--               predicted (to grade itself later)
--    confirmed  AUCTION_HOUSE_AUCTION_CREATED, or seen in your own auctions
--    sold       "A buyer has been found..." (the exact time, when online);
--               the sale mail's invoice (units, money, AH cut, buyer); a
--               listing that left your auctions early (a cancel is hooked,
--               so anything else that leaves early sold); your auctions
--               showing fewer units left (part of a stack sold)
--    expired    the chat line, the "Auction expired" mail, or the time
--               running out (a later sale mail can still turn it into a sale)
--    cancelled  C_AuctionHouse.CancelAuction
--    bought     "Auction won" invoices (what you paid, for flips)
--    market     a daily snapshot of the lowest price and how many are listed
--               for every item you can make or have sold (from Mastercraft's
--               or Auctionator's last scan); units that vanish between scans
--               are counted as the market's own turnover
--
--  JaseQoLDB.market.books["Realm-Faction"] = {
--    listings = { [n] = { id, name, q, u, dur (hours), dep, t, who, aid, st =
--      "pend"|"live"|"done", conf, sold, est (sold units not yet confirmed by
--      mail), rev (copper, est units at list price), cut, sT (unit-hours to
--      sale), exp, inf (expiry inferred from time), can, tEnd, tSold, hints,
--      mkt, cost, pP, pH, adopt } },
--    nextID, seenMail = { {k, s, ty} }, buys = { {id, name, n, c, t} },
--    snaps = { [itemID] = { d = { [day] = {p, n} }, lp, ln, lt, drop = { [day] = n } } },
--    cut, mailLife, firstT }
-------------------------------------------------------------------------------
local _, JQ = ...
local KEY = "salesLedger"

JQ.AddModule({
    key = KEY,
    label = "Sales ledger and craft advisor",
    description = "Records every auction you post and what became of it: sold (and how long it took), expired, cancelled, the money from the sale mail and the deposit lost. From that it learns what really sells and recommends what to craft for steady gold: the Market tab (/jmarket). Also keeps a daily note of auction prices and how many are listed for what you can make.",
    default = true,
})

local M = {}
JQ.Market = M

local HOUR, DAY = 3600, 86400
local KEEP_DAYS = 180
local SNAP_DAYS = 45
local DUR_HOURS = { 12, 24, 48 }
local DEFAULT_CUT = 0.05

local function On() return JQ.IsEnabled(KEY) and JaseQoLDB ~= nil end
M.On = On

local function Me() return (JQ.Alts and JQ.Alts.MyName and JQ.Alts.MyName()) or (UnitName and UnitName("player")) or "?" end
M.Me = Me

local listeners = {}
function M.OnChange(fn) listeners[#listeners + 1] = fn end
local changeQueued = false
local function Changed()
    M.version = (M.version or 0) + 1
    if changeQueued then return end
    changeQueued = true
    C_Timer.After(0.2, function()
        changeQueued = false
        for _, fn in ipairs(listeners) do JQ.Try("sales ledger: update", fn) end
    end)
end
M.Changed = Changed

-------------------------------------------------------------------------------
--  Storage
-------------------------------------------------------------------------------
local function BookKey()
    local realm = (JQ.Alts and JQ.Alts.Realm and JQ.Alts.Realm()) or (GetRealmName and GetRealmName()) or "?"
    local faction = (UnitFactionGroup and UnitFactionGroup("player")) or "?"
    return realm .. "-" .. faction
end

function M.Book()
    local root = JaseQoLDB.market
    if type(root) ~= "table" then root = { v = 1 }; JaseQoLDB.market = root end
    root.books = root.books or {}
    local k = BookKey()
    local b = root.books[k]
    if not b then
        b = {}
        root.books[k] = b
    end
    b.listings = b.listings or {}
    b.nextID = b.nextID or 1
    b.seenMail = b.seenMail or {}
    b.buys = b.buys or {}
    b.snaps = b.snaps or {}
    b.firstT = b.firstT or time()
    return b
end

function M.Settings()
    local root = JaseQoLDB.market or {}
    JaseQoLDB.market = root
    root.settings = root.settings or {}
    local s = root.settings
    s.style = s.style or "steady"     -- steady | balanced | bold
    s.dur = s.dur or 48               -- the listing length you use
    return s
end

local function Left(L) return math.max(0, (L.q or 0) - (L.sold or 0) - (L.exp or 0) - (L.can or 0)) end
M.Left = Left

local function Close(L, t)
    if Left(L) <= 0 and L.st ~= "done" then
        L.st = "done"
        L.tEnd = L.tEnd or t or time()
    end
end

local function Plain(s)
    if type(s) ~= "string" then return nil end
    local inLink = s:match("%[(.-)%]")
    if inLink then return inLink end
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function Name(id)
    if JQ.UI and JQ.UI.ItemNameQuality then return (JQ.UI.ItemNameQuality(id)) end
    local n = GetItemInfo and GetItemInfo(id)
    return n or ("item:" .. tostring(id))
end

-- id of an item name, from what you have posted before, then JaseTools' item names
local function IdOfName(name)
    if not name then return nil end
    local b = M.Book()
    for _, L in pairs(b.listings) do
        if L.name == name and L.id then return L.id end
    end
    for id, e in pairs((JaseQoLDB and JaseQoLDB.items) or {}) do
        if type(e) == "table" and e.n == name then return id end
    end
end
M.IdOfName = IdOfName

-------------------------------------------------------------------------------
--  Market price now: lowest price, units listed, scan time (Mastercraft's
--  saved scan, else Auctionator's price without the count).
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

function M.MarketNow(id)
    local e = MastercraftEntry(id)
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    local aPrice, aT
    if api and api.GetAuctionPriceByItemID then
        local ok, p = pcall(api.GetAuctionPriceByItemID, "JaseTools", id)
        if ok and type(p) == "number" and p > 0 then
            aPrice = p
            if api.GetAuctionAgeByItemID then
                local ok2, days = pcall(api.GetAuctionAgeByItemID, "JaseTools", id)
                if ok2 and type(days) == "number" then aT = time() - days * DAY end
            end
        end
    end
    if e and not e.gone and not (aPrice and aT and aT > (e.t or 0) + DAY) then
        return e.p, e.n, e.t
    end
    if aPrice then return aPrice, nil, aT end
    if e and e.gone then return nil, 0, e.t end
end

-------------------------------------------------------------------------------
--  Posting
-------------------------------------------------------------------------------
local function NewListing(fields)
    local b = M.Book()
    local lid = b.nextID
    b.nextID = lid + 1
    fields.lid = lid
    b.listings[lid] = fields
    return fields
end

local function ItemFromLoc(loc)
    if type(loc) ~= "table" or not C_Item then return nil end
    if C_Item.DoesItemExist then
        local ok, exists = pcall(C_Item.DoesItemExist, loc)
        if ok and not exists then return nil end
    end
    local id, link
    if C_Item.GetItemID then
        local ok, v = pcall(C_Item.GetItemID, loc)
        if ok then id = v end
    end
    if C_Item.GetItemLink then
        local ok, v = pcall(C_Item.GetItemLink, loc)
        if ok then link = v end
    end
    return id, link
end

-- the item last put in the AH sell window, for when its bag slot can't be read
local lastSellID

local moneyWatch   -- { L, before, at }

local function OnPost(loc, duration, qty, unit, commodity)
    if not On() then return end
    local id, link = ItemFromLoc(loc)
    id = id or lastSellID
    if not id or type(qty) ~= "number" or qty < 1 or type(unit) ~= "number" or unit <= 0 then return end
    local hours = DUR_HOURS[duration] or 48
    local AH = C_AuctionHouse
    local dep
    if commodity and AH.CalculateCommodityDeposit then
        local ok, v = pcall(AH.CalculateCommodityDeposit, id, duration, qty)
        if ok and type(v) == "number" then dep = v end
    elseif AH.CalculateItemDeposit then
        local ok, v = pcall(AH.CalculateItemDeposit, loc, duration, qty)
        if ok and type(v) == "number" then dep = v end
    end
    local mkt = M.MarketNow(id)
    local cost = M.UnitCost and select(1, M.UnitCost(id)) or nil
    local pP, pH, pR
    if M.Predict then
        local ok, p, h, raw = pcall(M.Predict, id, unit, hours)
        if ok then pP, pH, pR = p, h, raw end
    end
    local L = NewListing({
        id = id, name = Plain(link) or Name(id), q = qty, u = unit, dur = hours, dep = dep,
        t = time(), who = Me(), st = "pend", sold = 0, est = 0, rev = 0, exp = 0, can = 0,
        mkt = mkt, cost = cost, pP = pP, pH = pH, pR = pR, comm = commodity or nil,
    })
    if not dep and GetMoney then moneyWatch = { L = L, before = GetMoney(), at = GetTime() } end
    Changed()
end

-------------------------------------------------------------------------------
--  Matching outcomes to listings
-------------------------------------------------------------------------------
local function OpenListings(filter)
    local out = {}
    for _, L in pairs(M.Book().listings) do
        if L.st ~= "done" and filter(L) then out[#out + 1] = L end
    end
    table.sort(out, function(a, b) return (a.t or 0) < (b.t or 0) end)
    return out
end

-- Mark n units of L sold at time t (estimated: no mail has said so yet).
local function SoldEst(L, n, t)
    n = math.min(n, Left(L))
    if n <= 0 then return 0 end
    L.sold = (L.sold or 0) + n
    L.est = (L.est or 0) + n
    L.rev = (L.rev or 0) + (L.u or 0) * n
    L.sT = (L.sT or 0) + n * math.max(0, (t - (L.t or t)) / HOUR)
    L.tSold = L.tSold or t
    L.conf = true
    Close(L, t)
    return n
end

-- When a listing's time is up: units still out are expired (or sold, one per
-- unused "buyer found" line). Unconfirmed posts that never showed are dropped.
local function ExpireByTime(L, t, inferred)
    local left = Left(L)
    if left <= 0 then Close(L, t); return end
    local hints = L.hints and #L.hints or 0
    if hints > 0 then
        local h = table.remove(L.hints, 1)
        SoldEst(L, math.min(left, hints), h or t)
        L.hints = nil
        left = Left(L)
    end
    if left > 0 then
        L.exp = (L.exp or 0) + left
        if inferred then L.inf = (L.inf or 0) + left end
    end
    L.tEnd = math.min(t, (L.t or t) + (L.dur or 48) * HOUR)
    Close(L, L.tEnd)
end

local function SaleHint(name)
    local me, now = Me(), time()
    local list = OpenListings(function(L) return L.name == name and L.who == me end)
    local L = list[1]
    if not L then return end
    L.conf = true
    if Left(L) <= 1 then
        SoldEst(L, 1, now)
    else
        -- part of a stack: the count comes from your auctions or the mail
        L.hints = L.hints or {}
        if #L.hints < 50 then L.hints[#L.hints + 1] = now end
        L.tSold = L.tSold or now
    end
    Changed()
end

-- A sale mail: count units for gross copper (cut taken by the AH), at about time t.
local function Sale(name, count, gross, cut, t)
    if not name or not count or count < 1 then return end
    local b = M.Book()
    if gross and gross > 0 and cut and cut >= 0 then
        local r = cut / gross
        if r > 0 and r < 0.3 then b.cut = b.cut and (b.cut * 0.8 + r * 0.2) or r end
    end
    local unit = gross and gross / count or nil
    local function priceOK(L, strict)
        if not strict then return true end
        return not unit or not L.u or math.abs(L.u - unit) <= math.max(1, L.u * 0.02)
    end
    -- listings this could be: estimated sales first (the mail confirms them),
    -- then ones still out, then ones the clock said expired, oldest first.
    -- Same price first; then any price (a bid below the buyout).
    local cands = {}
    for pass = 1, 2 do
        local these = {}
        for _, L in pairs(b.listings) do
            if L.name == name and priceOK(L, pass == 1) and ((L.est or 0) > 0 or Left(L) > 0 or (L.inf or 0) > 0) then
                these[#these + 1] = L
            end
        end
        table.sort(these, function(a, c)
            local ea, ec = (a.est or 0) > 0, (c.est or 0) > 0
            if ea ~= ec then return ea end
            return (a.t or 0) < (c.t or 0)
        end)
        for _, L in ipairs(these) do cands[#cands + 1] = L end
    end
    local left = count
    for _, L in ipairs(cands) do
        if left <= 0 then break end
        -- confirm estimated units
        local take = math.min(left, L.est or 0)
        if take > 0 then
            L.est = L.est - take
            L.rev = (L.rev or 0) - (L.u or 0) * take + (gross or 0) * take / count
            left = left - take
        end
        -- units still out
        local add = math.min(left, Left(L))
        if add > 0 then
            local when = t
            if L.hints and #L.hints > 0 then when = table.remove(L.hints, 1) end
            when = math.max(L.t or when, math.min(time(), when))
            L.sold = (L.sold or 0) + add
            L.rev = (L.rev or 0) + (gross or 0) * add / count
            L.sT = (L.sT or 0) + add * (when - (L.t or when)) / HOUR
            L.tSold = L.tSold and math.min(L.tSold, when) or when
            left = left - add
        end
        -- units the clock called expired: they sold after all
        local fix = math.min(left, L.inf or 0)
        if fix > 0 then
            L.inf, L.exp = L.inf - fix, (L.exp or 0) - fix
            local when = math.min(t, (L.t or t) + (L.dur or 48) * HOUR)
            L.sold = (L.sold or 0) + fix
            L.rev = (L.rev or 0) + (gross or 0) * fix / count
            L.sT = (L.sT or 0) + fix * math.max(0, (when - (L.t or when)) / HOUR)
            L.tSold = L.tSold and math.min(L.tSold, when) or when
            left = left - fix
        end
        if cut then L.cut = (L.cut or 0) + cut * (count - left) / count end
        L.conf = true
        Close(L, t)
    end
    if left > 0 then
        -- posted before the ledger knew (or elsewhere): income only, no timing
        NewListing({ id = IdOfName(name), name = name, q = left, u = unit, t = t, who = Me(), st = "done",
            sold = left, est = 0, rev = (gross or 0) * left / count, exp = 0, can = 0, tEnd = t, tSold = t,
            adopt = true, conf = true, cut = cut and cut * left / count or nil })
    end
    Changed()
end

local function Expired(name, count, t)
    local me = Me()
    local now = t or time()
    -- only listings whose time is (about) up: a newer one of the same item stays out
    local list = OpenListings(function(L)
        return L.name == name and L.who == me and (L.t or now) + (L.dur or 48) * HOUR <= now + 2 * HOUR
    end)
    -- the one whose time ran out first
    table.sort(list, function(a, c) return (a.t or 0) + (a.dur or 48) * HOUR < (c.t or 0) + (c.dur or 48) * HOUR end)
    local L = list[1]
    if L then
        L.conf = true
        ExpireByTime(L, t or time(), false)
        Changed()
        return
    end
    -- already expired by the clock: now it's confirmed
    for _, X in pairs(M.Book().listings) do
        if X.name == name and (X.inf or 0) > 0 then X.inf = math.max(0, X.inf - (count or X.inf)); return end
    end
end

local function OnCancel(aid)
    if not On() or not aid then return end
    for _, L in pairs(M.Book().listings) do
        if L.aid == aid and L.st ~= "done" then
            L.can = (L.can or 0) + Left(L)
            L.tEnd = time()
            Close(L, L.tEnd)
            Changed()
            return
        end
    end
end

-------------------------------------------------------------------------------
--  Your auctions (the AH's Auctions tab, or our own quiet query on opening)
-------------------------------------------------------------------------------
local ownedQueried = false
local function ReadOwned()
    if not On() then return end
    local AH = C_AuctionHouse
    if not (AH and AH.GetNumOwnedAuctions and AH.GetOwnedAuctionInfo) then return end
    if AH.HasFullOwnedAuctionResults and not AH.HasFullOwnedAuctionResults() then return end
    local b, me, now = M.Book(), Me(), time()
    local SOLD = Enum and Enum.AuctionStatus and Enum.AuctionStatus.Sold or 1
    local byAid = {}
    for _, L in pairs(b.listings) do if L.aid then byAid[L.aid] = L end end
    local seen = {}
    local n = AH.GetNumOwnedAuctions() or 0
    for i = 1, n do
        local ok, a = pcall(AH.GetOwnedAuctionInfo, i)
        if ok and type(a) == "table" and a.auctionID then
            seen[a.auctionID] = true
            local id = a.itemKey and a.itemKey.itemID
            local qty = a.quantity or 1
            local L = byAid[a.auctionID]
            if not L and id then
                -- a post the ledger saw but whose id it never heard
                local best
                for _, X in pairs(b.listings) do
                    if X.st ~= "done" and not X.aid and X.who == me and X.id == id and X.q == qty + (X.sold or 0)
                        and (not a.buyoutAmount or X.u == a.buyoutAmount or X.u * X.q == a.buyoutAmount)
                        and (not best or (X.t or 0) < (best.t or 0)) then best = X end
                end
                L = best
                if L then L.aid = a.auctionID; byAid[a.auctionID] = L end
            end
            if not L and id and a.status ~= SOLD then
                -- posted before the ledger (or by another addon path): followed from here on
                local unit = a.buyoutAmount
                -- when it was posted isn't known: take it as a 48 h auction
                local posted = now
                if type(a.timeLeftSeconds) == "number" then posted = now + a.timeLeftSeconds - 48 * HOUR end
                L = NewListing({ id = id, name = Plain(a.itemLink) or Name(id), q = qty, u = unit, dur = 48,
                    t = posted, who = me, st = "live", conf = true, aid = a.auctionID, adopt = true,
                    sold = 0, est = 0, rev = 0, exp = 0, can = 0 })
                byAid[a.auctionID] = L
            end
            if L then
                L.conf = true
                if L.st == "pend" then L.st = "live" end
                if a.status == SOLD then
                    SoldEst(L, Left(L), (L.tSold or now))
                else
                    local gone = Left(L) - qty
                    if gone > 0 then SoldEst(L, gone, now) end
                end
            end
        end
    end
    -- mine, out, and no longer in the list (not just posted: the list can be
    -- from before the post)
    for _, L in pairs(b.listings) do
        if L.st ~= "done" and L.who == me and L.aid and not seen[L.aid] and now - (L.t or now) > 300 then
            local ends = (L.t or now) + (L.dur or 48) * HOUR
            if now >= ends - 60 then
                ExpireByTime(L, now, false)
            else
                -- cancels are caught when made, so leaving early means it sold
                local when = (L.hints and L.hints[1]) or L.tSold or now
                L.hints = nil
                SoldEst(L, Left(L), when)
            end
        end
    end
    -- posts that never turned up anywhere: they didn't go through
    for lid, L in pairs(b.listings) do
        if L.st == "pend" and not L.conf and L.who == me and now - (L.t or now) > 600 then
            b.listings[lid] = nil
        end
    end
    Changed()
end

local function QueryOwned()
    local AH = C_AuctionHouse
    if ownedQueried or not (AH and AH.QueryOwnedAuctions) then return end
    if AH.IsThrottledMessageSystemReady and not AH.IsThrottledMessageSystemReady() then
        C_Timer.After(2, QueryOwned)
        return
    end
    ownedQueried = true
    pcall(AH.QueryOwnedAuctions, {})
end

-------------------------------------------------------------------------------
--  Mail: sale invoices, expired and won auctions
-------------------------------------------------------------------------------
local function SubjectPattern(fmt)
    if type(fmt) ~= "string" then return nil end
    local p = fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    p = p:gsub("%%%%s", "(.+)"):gsub("%%%%d", "%%d+")
    return "^" .. p .. "$"
end

local EXPIRED_MAIL = SubjectPattern(AUCTION_EXPIRED_MAIL_SUBJECT or "Auction expired: %s")
local CANCEL_MAIL = SubjectPattern(AUCTION_REMOVED_MAIL_SUBJECT or "Auction cancelled: %s")
local SOLD_MSG = SubjectPattern(ERR_AUCTION_SOLD_S or "A buyer has been found for your auction of %s.")
local EXPIRED_MSG = ERR_AUCTION_EXPIRED_S and SubjectPattern(ERR_AUCTION_EXPIRED_S)

-- Has this mail been counted? Mails are told apart by what they say and when
-- they were sent (worked out from the days left: steady to a few seconds).
local function Seen(b, key, sent, ty)
    for _, e in ipairs(b.seenMail) do
        if e.k == key then
            local d = math.abs((e.s or 0) - sent)
            if d < 300 then return true end
            -- the temporary invoice and the final one for the same sale
            if e.ty ~= ty and (e.ty == "seller_temp_invoice" or ty == "seller_temp_invoice") and d < 4 * HOUR then return true end
        end
    end
    b.seenMail[#b.seenMail + 1] = { k = key, s = sent, ty = ty }
    return false
end

local function ScanMail()
    if not On() or not GetInboxNumItems then return end
    local b, now = M.Book(), time()
    local n = GetInboxNumItems() or 0
    local changed = false
    for i = 1, n do
        local _, _, sender, subject, money, _, daysLeft, itemCount = GetInboxHeaderInfo(i)
        if type(daysLeft) == "number" and type(subject) == "string" then
            if daysLeft > (b.mailLife or 30) and daysLeft < 100 then b.mailLife = math.ceil(daysLeft) end
            local sent = math.min(now, now - ((b.mailLife or 30) - daysLeft) * DAY)
            local invType, itemName, buyer, bid, buyout, deposit, consignment, _, _, _, count
            if GetInboxInvoiceInfo then
                invType, itemName, buyer, bid, buyout, deposit, consignment, _, _, _, count = GetInboxInvoiceInfo(i)
            end
            if invType == "seller" or invType == "seller_temp_invoice" then
                local gross = (buyout and buyout > 0) and buyout or bid or 0
                local key = table.concat({ "s", tostring(itemName), tostring(count or 1), tostring(gross), tostring(buyer) }, "|")
                if not Seen(b, key, sent, invType) then
                    Sale(itemName, count or 1, gross, consignment, sent)
                    changed = true
                end
            elseif invType == "buyer" then
                local paid = (buyout and buyout > 0) and buyout or bid or 0
                local key = table.concat({ "b", tostring(itemName), tostring(count or 1), tostring(paid) }, "|")
                if not Seen(b, key, sent, invType) then
                    b.buys[#b.buys + 1] = { id = IdOfName(itemName), name = itemName, n = count or 1, c = paid, t = sent }
                    changed = true
                end
            else
                local name = EXPIRED_MAIL and subject:match(EXPIRED_MAIL)
                if name then
                    local key = "e|" .. name .. "|" .. tostring(itemCount)
                    if not Seen(b, key, sent, "expired") then
                        Expired(Plain(name), nil, sent)
                        changed = true
                    end
                end
            end
        end
    end
    if changed then Changed() end
end

-------------------------------------------------------------------------------
--  Market snapshots: one per item per day, plus the units that vanished
--  between two scans (the market's turnover: sales, and some cancels).
-------------------------------------------------------------------------------
function M.Watched()
    local ids = {}
    for out in pairs((JaseQoLDB and JaseQoLDB.recipeIndex) or {}) do ids[out] = true end
    for _, L in pairs(M.Book().listings) do if L.id then ids[L.id] = true end end
    return ids
end

function M.Snapshot()
    if not On() then return end
    local b = M.Book()
    local changed = false
    for id in pairs(M.Watched()) do
        local p, n, t = M.MarketNow(id)
        if t and (p or n == 0) then
            local s = b.snaps[id] or { d = {}, drop = {} }
            b.snaps[id] = s
            if not s.lt or t > s.lt + 60 then
                local day = math.floor(t / DAY)
                if s.ln and n and n < s.ln and t - s.lt < 36 * HOUR then
                    s.drop[day] = (s.drop[day] or 0) + (s.ln - n)
                end
                local d = s.d[day]
                if d then
                    if p and (not d[1] or p < d[1]) then d[1] = p end
                    if n then d[2] = n end
                else
                    s.d[day] = { p, n }
                end
                s.lp, s.ln, s.lt = p, n, t
                changed = true
            end
        end
    end
    if changed then Changed() end
end

-------------------------------------------------------------------------------
--  Housekeeping: the clock, and trimming old records
-------------------------------------------------------------------------------
function M.Tidy()
    if not On() then return end
    local b, now = M.Book(), time()
    local changed = false
    for lid, L in pairs(b.listings) do
        if L.st ~= "done" then
            local ends = (L.t or now) + (L.dur or 48) * HOUR
            -- an hour's grace for the mail and the chat line
            if now > ends + HOUR then
                if L.conf or (L.sold or 0) > 0 then
                    ExpireByTime(L, now, true)
                else
                    b.listings[lid] = nil
                end
                changed = true
            elseif L.st == "pend" and L.conf then
                L.st = "live"
            end
        elseif (L.tEnd or L.t or now) < now - KEEP_DAYS * DAY then
            b.listings[lid] = nil
            changed = true
        end
    end
    local keep = {}
    for _, e in ipairs(b.seenMail) do if (e.s or 0) > now - 35 * DAY then keep[#keep + 1] = e end end
    b.seenMail = keep
    local buys = {}
    for _, e in ipairs(b.buys) do if (e.t or 0) > now - 90 * DAY then buys[#buys + 1] = e end end
    b.buys = buys
    local oldest = math.floor(now / DAY) - SNAP_DAYS
    for _, s in pairs(b.snaps) do
        for day in pairs(s.d or {}) do if day < oldest then s.d[day] = nil end end
        for day in pairs(s.drop or {}) do if day < oldest then s.drop[day] = nil end end
    end
    if changed then Changed() end
end

-------------------------------------------------------------------------------
--  Events and hooks
-------------------------------------------------------------------------------
local function OnSystem(msg)
    if not On() or type(msg) ~= "string" then return end
    local name = SOLD_MSG and msg:match(SOLD_MSG)
    if name then return SaleHint(Plain(name)) end
    name = EXPIRED_MSG and msg:match(EXPIRED_MSG)
    if name then return Expired(Plain(name), nil, time()) end
end

local hooked = false
local function Hook()
    if hooked then return end
    local AH = C_AuctionHouse
    if not AH then return end
    hooked = true
    if AH.PostItem then
        hooksecurefunc(AH, "PostItem", function(loc, duration, qty, bid, buyout)
            JQ.Try("sales ledger: post", OnPost, loc, duration, qty, buyout or bid, false)
        end)
    end
    if AH.PostCommodity then
        hooksecurefunc(AH, "PostCommodity", function(loc, duration, qty, unit)
            JQ.Try("sales ledger: post", OnPost, loc, duration, qty, unit, true)
        end)
    end
    if AH.CancelAuction then
        hooksecurefunc(AH, "CancelAuction", function(aid) JQ.Try("sales ledger: cancel", OnCancel, aid) end)
    end
    -- the item in the sell window, in case its bag slot can't be read after posting
    for _, fn in ipairs({ "CalculateItemDeposit", "IsSellItemValid", "GetItemCommodityStatus" }) do
        if AH[fn] then
            hooksecurefunc(AH, fn, function(loc)
                local id = ItemFromLoc(loc)
                if id then lastSellID = id end
            end)
        end
    end
    if AH.CalculateCommodityDeposit then
        hooksecurefunc(AH, "CalculateCommodityDeposit", function(id) if type(id) == "number" then lastSellID = id end end)
    end
end

local ev = CreateFrame("Frame")
local EVENTS = {
    "PLAYER_LOGIN", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_AUCTION_CREATED",
    "OWNED_AUCTIONS_UPDATED", "MAIL_INBOX_UPDATE", "CHAT_MSG_SYSTEM", "PLAYER_MONEY",
}
ev:SetScript("OnEvent", function(_, event, a1)
    if event == "PLAYER_LOGIN" then
        Hook()
        C_Timer.After(8, function() JQ.Try("sales ledger: tidy", M.Tidy); JQ.Try("sales ledger: snapshot", M.Snapshot) end)
        C_Timer.NewTicker(60, function() JQ.Try("sales ledger: tidy", M.Tidy) end)
        return
    end
    if not On() then return end
    if event == "AUCTION_HOUSE_SHOW" then
        Hook()
        ownedQueried = false
        C_Timer.After(3, function() JQ.Try("sales ledger: your auctions", QueryOwned) end)
    elseif event == "AUCTION_HOUSE_CLOSED" then
        C_Timer.After(1, function() JQ.Try("sales ledger: snapshot", M.Snapshot) end)
    elseif event == "AUCTION_HOUSE_AUCTION_CREATED" then
        local me = Me()
        local list = OpenListings(function(L) return L.who == me and not L.aid and L.st == "pend" end)
        local L = list[1]
        if L then
            L.aid = a1
            L.conf = true
            L.st = "live"
            Changed()
        end
    elseif event == "OWNED_AUCTIONS_UPDATED" then
        JQ.Try("sales ledger: your auctions", ReadOwned)
    elseif event == "MAIL_INBOX_UPDATE" then
        JQ.Try("sales ledger: mail", ScanMail)
    elseif event == "CHAT_MSG_SYSTEM" then
        JQ.Try("sales ledger: chat", OnSystem, a1)
    elseif event == "PLAYER_MONEY" then
        local w = moneyWatch
        if w and GetTime() - w.at < 5 and GetMoney then
            local spent = w.before - GetMoney()
            if spent > 0 and not w.L.dep then w.L.dep = spent end
            moneyWatch = nil
        end
    end
end)
for _, e in ipairs(EVENTS) do pcall(ev.RegisterEvent, ev, e) end

JQ.byKey[KEY].onEnable = function() Hook() end

-- for tests
JQ._MarketLedger = { OnPost = OnPost, Sale = Sale, SaleHint = SaleHint, Expired = Expired, OnCancel = OnCancel,
    ReadOwned = ReadOwned, ScanMail = ScanMail, ExpireByTime = ExpireByTime, SubjectPattern = SubjectPattern,
    Seen = Seen, OnSystem = OnSystem }
