-------------------------------------------------------------------------------
--  JaseTools: craft advisor (the model behind the Market tab)
--
--  Turns the sales ledger into "what should I make, how many, at what price".
--  The aim is steady gold per day, not the biggest margin: something that
--  makes 30s and sells ten times a day beats 5g that sells once a week.
--
--  For every item it estimates, from your own sales:
--    sell rate (lambda)  units sold per hour a unit is on the market. Every
--                   hour a unit sits there counts, whether it then sold,
--                   expired, was cancelled or is still up, so 12 h and 48 h
--                   listings, stacks and singles all add up fairly. Chance a
--                   listing sells in D hours = 1 - e^(-lambda * D).
--    absorption (mu) units a day the market takes from you while you have
--                   some up: the ceiling on how much you can sell.
--    price, cut, deposits, cost to make, profit per unit after the deposits
--                   that expiries eat (1/p - 1 relists per sale).
--  Gold per day = profit per unit x units a day.
--
--  How it learns and gets sharper:
--    * Pooling: an item with little history borrows from its item type
--      (e.g. Cloth > Bags), which borrows from all your sales. The more an
--      item sells, the more its own numbers count (Gamma-Poisson shrinkage).
--    * Recency: everything decays with a 21-day half-life, so the advisor
--      follows the market when it moves.
--    * Price response: it learns how much faster things sell when you list
--      under the lowest price, and slower above it, and picks the price
--      with the best gold per day (starts from sensible guesses).
--    * Self-check: each post stores what it predicted; when the listing ends
--      it compares, keeps a running bias per item type and corrects for it.
--      The Summary view shows how right it has been.
--    * Exploring: things that look good on paper but you have never sold
--      are suggested as small tests (1-2), ranked by their upside, until
--      there is enough real data to judge them.
--    * Caution: "Steady" ranks by a pessimistic estimate (so a lucky sale
--      or two doesn't top the list), and marks down items whose price jumps
--      about or whose supply has just piled up.
--    * Market turnover: units that vanish between auction scans give
--      untested items a first guess at how fast they move.
-------------------------------------------------------------------------------
local _, JQ = ...
local M = JQ.Market
if not M then return end

local HOUR, DAY = 3600, 86400
local HALF_LIFE = 21            -- days
local K_LAMBDA = 2              -- pseudo-sales the type's rate is worth
local K_MU = 1.5
local MARKET_SHARE = 0.3        -- of the market's turnover you'd get as cheapest
local DEFAULT_CUT = 0.05
local PROVEN = 3                -- units sold before an item counts as proven

local STYLE = {
    steady   = { z = 1.28, risk = 1.0, label = "Steady" },
    balanced = { z = 0.67, risk = 0.5, label = "Balanced" },
    bold     = { z = 0.0,  risk = 0.0, label = "Bold" },
}
M.STYLE = STYLE

-- Price buckets: your price / the lowest price when you posted, and the
-- starting guess for how that changes the sell rate.
local BUCKETS = {
    { max = 0.92, prior = 1.7, label = "8%+ under" },
    { max = 0.97, prior = 1.35, label = "3-8% under" },
    { max = 1.01, prior = 1.0, label = "at the lowest" },
    { max = 1.06, prior = 0.7, label = "1-6% over" },
    { max = 1.15, prior = 0.45, label = "6-15% over" },
    { max = 99,   prior = 0.25, label = "15%+ over" },
}
M.BUCKETS = BUCKETS
local TRY_RATIOS = { 0.93, 0.97, 1.0, 1.04, 1.1 }

local function Bucket(r)
    for i, bk in ipairs(BUCKETS) do if r <= bk.max then return i end end
    return #BUCKETS
end

local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local GetInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local function Category(id)
    if not (id and GetInstant) then return "?", "?" end
    local ok, _, _, _, _, _, classID, subID = pcall(GetInstant, id)
    if not ok or not classID then return "?", "?" end
    return tostring(classID), classID .. "." .. tostring(subID)
end

local function MaxStack(id)
    if C_Item and C_Item.GetItemMaxStackSizeByID then
        local ok, n = pcall(C_Item.GetItemMaxStackSizeByID, id)
        if ok and type(n) == "number" then return n end
    end
    local n = GetItemInfo and select(8, GetItemInfo(id))
    return n or 20
end

local function Weight(t, now) return 0.5 ^ (math.max(0, now - (t or now)) / DAY / HALF_LIFE) end

-------------------------------------------------------------------------------
--  Cost to make one: each material bought or made from its own materials
--  (two levels down), whichever is cheaper. Vendor materials count nothing.
-------------------------------------------------------------------------------
local costCache, costStamp = {}, 0
local function BestCost(id, qty, depth, seen)
    local R = JQ.Requests
    if R and R.IsVendor and R.IsVendor(id) then return 0, true end
    local buy = JQ.CostToBuy and JQ.CostToBuy(id, qty) or nil
    local rec = JaseQoLDB.recipeIndex and JaseQoLDB.recipeIndex[id]
    local make
    if depth < 2 and type(rec) == "table" and rec.r and not seen[id] then
        seen[id] = true
        local crafts = math.ceil(qty / math.max(1, rec.n or 1))
        local total = 0
        for rid, q in pairs(rec.r) do
            local c = BestCost(rid, q * crafts, depth + 1, seen)
            if not c then total = nil; break end
            total = total + c
        end
        seen[id] = nil
        make = total
    end
    if buy and make then return math.min(buy, make), true end
    return buy or make, (buy or make) ~= nil
end

-- cost of one unit (copper) or nil, and whether it came from the recipe
function M.UnitCost(id)
    local now = time()
    if now - costStamp > 60 then costCache, costStamp = {}, now end
    local c = costCache[id]
    if c then return c.v, c.recipe end
    local rec = JaseQoLDB.recipeIndex and JaseQoLDB.recipeIndex[id]
    local v, recipe
    if type(rec) == "table" and rec.r then
        local total = 0
        for rid, q in pairs(rec.r) do
            local cc = BestCost(rid, q, 1, { [id] = true })
            if not cc then total = nil; break end
            total = total + cc
        end
        if total then v, recipe = total / math.max(1, rec.n or 1), true end
    end
    if not v then
        -- bought to resell: the average you paid lately
        local paid, n = 0, 0
        for _, e in ipairs(M.Book().buys) do
            if e.id == id and (e.n or 0) > 0 then paid, n = paid + (e.c or 0), n + e.n end
        end
        if n > 0 then v = paid / n end
    end
    costCache[id] = { v = v, recipe = recipe }
    return v, recipe
end

-------------------------------------------------------------------------------
--  Statistics from the ledger (rebuilt when it changes, or each minute)
-------------------------------------------------------------------------------
local stats, statsVersion, statsStamp

local function Blank()
    return { S = 0, E = 0, soldW = 0, stockD = 0, rev = 0, net = 0, cut = 0, profit = 0, profitU = 0,
        depLost = 0, depPaid = 0, depU = 0, ratioE = 0, ratioW = 0,
        posts = 0, units = 0, soldN = 0, expN = 0, canN = 0, live = 0, liveN = 0, hours = {},
        lastSale = nil, firstPost = nil, calN = 0, calErr = 0 }
end

local function MergeStock(iv, now)
    table.sort(iv, function(a, b) return a[1] < b[1] end)
    local days = 0
    local s, e
    local function flush()
        if s then days = days + (e - s) / DAY * Weight((s + e) / 2, now) end
    end
    for _, x in ipairs(iv) do
        if not s or x[1] > e then
            flush()
            s, e = x[1], x[2]
        elseif x[2] > e then
            e = x[2]
        end
    end
    flush()
    return days
end

function M.Stats()
    local now = time()
    if stats and statsVersion == M.version and now - statsStamp < 60 then return stats end
    local b = M.Book()
    local items, cats, sub = {}, {}, {}
    local G = Blank()
    local buckets = {}
    for i = 1, #BUCKETS do buckets[i] = { S = 0, E = 0 } end
    local cal = { g = { n = 0, err = 0, sq = 0, cnt = 0, pred = 0, out = 0 }, c = {} }
    local stock = {}
    local cut = b.cut or DEFAULT_CUT
    local totals = { day = 0, week = 0, month = 0, profitWeek = 0, profitMonth = 0, depWeek = 0, depMonth = 0,
        liveUnits = 0, liveValue = 0, soldMonth = 0, failMonth = 0 }

    for _, L in pairs(b.listings) do
        local id = L.id
        local left = M.Left(L)
        local sold, exp, can = L.sold or 0, L.exp or 0, L.can or 0
        local soldAt = L.tSold or L.tEnd or L.t or now
        local net = (L.rev or 0) - (L.cut or (L.rev or 0) * cut)
        local depLost = (L.dep and (L.q or 0) > 0) and L.dep * (exp + can) / L.q or 0
        -- income, whatever its history
        if sold > 0 then
            local age = now - soldAt
            local pr = L.cost and (net - L.cost * sold) or nil
            if age < DAY then totals.day = totals.day + net end
            if age < 7 * DAY then totals.week = totals.week + net; totals.profitWeek = totals.profitWeek + (pr or net) end
            if age < 30 * DAY then
                totals.month = totals.month + net
                totals.profitMonth = totals.profitMonth + (pr or net)
                totals.soldMonth = totals.soldMonth + sold
            end
        end
        if depLost > 0 then
            local age = now - (L.tEnd or now)
            if age < 7 * DAY then totals.depWeek = totals.depWeek + depLost end
            if age < 30 * DAY then totals.depMonth = totals.depMonth + depLost end
        end
        if L.st ~= "done" and left > 0 then
            totals.liveUnits = totals.liveUnits + left
            totals.liveValue = totals.liveValue + left * (L.u or 0)
        end
        if (exp + can) > 0 and now - (L.tEnd or now) < 30 * DAY then totals.failMonth = totals.failMonth + exp + can end

        if id then
            local it = items[id]
            if not it then it = Blank(); items[id] = it end
            it.name = it.name or L.name
            it.posts = it.posts + 1
            it.units = it.units + (L.q or 0)
            it.soldN = it.soldN + sold
            it.expN = it.expN + exp
            it.canN = it.canN + can
            it.rev = it.rev + (L.rev or 0)
            it.net = it.net + net
            it.depLost = it.depLost + depLost
            if L.st ~= "done" then it.live = it.live + left; it.liveN = it.liveN + 1 end
            if sold > 0 and (not it.lastSale or soldAt > it.lastSale) then it.lastSale = soldAt end
            if not it.firstPost or (L.t or now) < it.firstPost then it.firstPost = L.t end
            if L.cost and sold > 0 then
                it.profit = it.profit + (net - L.cost * sold)
                it.profitU = it.profitU + sold
            end

            -- the rate model: only posts whose start time is known
            if not L.adopt and (L.conf or sold > 0) and L.t then
                local w = Weight(L.t, now)
                local dur = L.dur or 48
                local soldH = L.sT or (sold * math.max(0, (soldAt - L.t) / HOUR))
                local canH = can * math.max(0, ((L.tEnd or now) - L.t) / HOUR)
                local openH = left * math.min(dur, math.max(0, (now - L.t) / HOUR))
                local E = soldH + exp * dur + canH + openH
                if E > 0 then
                    it.S = it.S + w * sold
                    it.E = it.E + w * E
                    it.soldW = it.soldW + w * sold
                    if L.dep and (L.q or 0) > 0 then
                        it.depPaid = it.depPaid + w * L.dep / L.q / dur
                        it.depU = it.depU + w
                    end
                    if L.mkt and L.mkt > 0 and L.u then
                        local r = L.u / L.mkt
                        it.ratioE = it.ratioE + w * E * r
                        it.ratioW = it.ratioW + w * E
                        local bk = buckets[Bucket(r)]
                        bk.S, bk.E = bk.S + w * sold, bk.E + w * E
                    end
                    stock[id] = stock[id] or {}
                    local stop = L.tEnd or math.min(now, L.t + dur * HOUR)
                    if stop > L.t then table.insert(stock[id], { L.t, stop, L.q or 1 }) end
                    if sold > 0 and soldH > 0 and #it.hours < 40 then it.hours[#it.hours + 1] = soldH / sold end
                end
                -- grading the forecast made when it was posted
                -- (the bias is learned against the raw forecast, before any
                -- correction, so the correction doesn't feed on itself)
                if L.st == "done" and L.pP and (L.q or 0) > 0 then
                    local o = sold / L.q
                    local raw = L.pR or L.pP
                    local _, c2 = Category(id)
                    local cc = cal.c[c2] or { n = 0, err = 0 }
                    cal.c[c2] = cc
                    cc.n, cc.err = cc.n + w, cc.err + w * (o - raw)
                    cal.g.n, cal.g.err = cal.g.n + w, cal.g.err + w * (o - raw)
                    cal.g.sq = cal.g.sq + w * (o - L.pP) ^ 2
                    cal.g.pred, cal.g.out = cal.g.pred + w * L.pP, cal.g.out + w * o
                    cal.g.cnt = cal.g.cnt + 1
                    it.calN, it.calErr = it.calN + w, it.calErr + w * (o - raw)
                end
            end
        end
    end

    -- pool up: type (class), sub-type, everything
    for id, it in pairs(items) do
        it.stockD = MergeStock(stock[id] or {}, now)
        -- the most units you've had up at once (how far the market has been tested)
        local evs = {}
        for _, x in ipairs(stock[id] or {}) do
            evs[#evs + 1] = { x[1], x[3] }
            evs[#evs + 1] = { x[2], -x[3] }
        end
        table.sort(evs, function(a, b) if a[1] ~= b[1] then return a[1] < b[1] end return a[2] < b[2] end)
        local up, peak = 0, 0
        for _, e in ipairs(evs) do up = up + e[2]; if up > peak then peak = up end end
        it.peak = peak
        local c1, c2 = Category(id)
        it.c1, it.c2 = c1, c2
        for _, pair in ipairs({ { cats, c1 }, { sub, c2 } }) do
            local t = pair[1][pair[2]] or { S = 0, E = 0, soldW = 0, stockD = 0, depPaid = 0, depU = 0 }
            pair[1][pair[2]] = t
            t.S, t.E = t.S + it.S, t.E + it.E
            t.soldW, t.stockD = t.soldW + it.soldW, t.stockD + it.stockD
            t.depPaid, t.depU = t.depPaid + it.depPaid, t.depU + it.depU
        end
        G.S, G.E = G.S + it.S, G.E + it.E
        G.soldW, G.stockD = G.soldW + it.soldW, G.stockD + it.stockD
        G.soldN, G.expN, G.canN = G.soldN + it.soldN, G.expN + it.expN, G.canN + it.canN
        for _, h in ipairs(it.hours) do if #G.hours < 400 then G.hours[#G.hours + 1] = h end end
    end
    -- rates, each shrunk to the level above it
    G.lambda = (G.S + 1) / (G.E + 24)            -- starting belief: about a day per unit
    G.mu = (G.soldW + 1) / (G.stockD + 1)        -- and one a day while stocked
    for _, t in pairs(cats) do
        t.lambda = (t.S + K_LAMBDA) / (t.E + K_LAMBDA / G.lambda)
        t.mu = (t.soldW + K_MU) / (t.stockD + K_MU / G.mu)
    end
    for key, t in pairs(sub) do
        local parent = cats[key:match("^([^%.]+)")] or G
        t.lambda = (t.S + K_LAMBDA) / (t.E + K_LAMBDA / parent.lambda)
        t.mu = (t.soldW + K_MU) / (t.stockD + K_MU / parent.mu)
    end
    -- price response, shrunk to the starting guesses (3 sales' worth)
    local mult = {}
    local base = G.S > 0 and G.E > 0 and G.S / G.E or G.lambda
    for i, bk in ipairs(BUCKETS) do
        local d = buckets[i]
        local learned = d.E > 0 and (d.S / d.E) / base or bk.prior
        local wgt = d.S / (d.S + 3)
        mult[i] = Clamp(bk.prior * (1 - wgt) + learned * wgt, 0.05, 5)
        d.mult, d.weight = mult[i], wgt
    end

    stats = { items = items, cats = cats, sub = sub, G = G, buckets = buckets, mult = mult, cal = cal,
        totals = totals, cut = cut, at = now }
    statsVersion, statsStamp = M.version, now
    return stats
end

-------------------------------------------------------------------------------
--  The market around an item (from the daily snapshots)
-------------------------------------------------------------------------------
local function Median(t)
    if #t == 0 then return nil end
    local c = {}
    for i, v in ipairs(t) do c[i] = v end
    table.sort(c)
    local m = math.floor((#c + 1) / 2)
    return #c % 2 == 1 and c[m] or (c[m] + c[m + 1]) / 2
end
M.Median = Median

function M.MarketShape(id)
    local s = M.Book().snaps[id]
    if not s then return {} end
    local today = math.floor(time() / DAY)
    local prices, counts, recent, older = {}, {}, {}, {}
    local days, drops = 0, 0
    for day = today - 13, today do
        local d = s.d and s.d[day]
        if d then
            days = days + 1
            if d[1] then
                prices[#prices + 1] = d[1]
                if day > today - 3 then recent[#recent + 1] = d[1] else older[#older + 1] = d[1] end
            end
            if d[2] then counts[#counts + 1] = d[2] end
        end
        drops = drops + ((s.drop and s.drop[day]) or 0)
    end
    local out = { days = days }
    if #prices >= 3 then
        local mean, sq = 0, 0
        for _, p in ipairs(prices) do mean = mean + p end
        mean = mean / #prices
        for _, p in ipairs(prices) do sq = sq + (p - mean) ^ 2 end
        out.cv = mean > 0 and math.sqrt(sq / #prices) / mean or 0
    end
    if #recent > 0 and #older > 0 then
        local a, c = 0, 0
        for _, p in ipairs(recent) do a = a + p end
        for _, p in ipairs(older) do c = c + p end
        out.trend = (a / #recent) / (c / #older)
    end
    out.medianN = Median(counts)
    out.n = s.ln
    if days >= 2 then out.turnover = drops / days end
    return out
end

-------------------------------------------------------------------------------
--  Evaluating an item
-------------------------------------------------------------------------------
-- What a deposit costs per unit per hour listed: the item's own, else its
-- type's, else a guess from the vendor price (15% per 12 h).
local function DepositPerHour(id, st, it)
    if it and it.depU > 0 then return it.depPaid / it.depU end
    local s = it and st.sub[it.c2]
    if s and s.depU > 0 then return s.depPaid / s.depU end
    local vendor = GetItemInfo and select(11, GetItemInfo(id))
    if type(vendor) == "number" and vendor > 0 then return vendor * 0.15 / 12 end
    return 0
end

local function RoundPrice(id, p)
    if MaxStack(id) <= 1 then
        -- WoW Forever won't post single items with copper in the price
        return math.max(100, math.floor(p / 100 + 0.5) * 100)
    end
    return math.max(1, math.floor(p + 0.5))
end

-- ev = { price, ref, p, hours, net, cost, profitU, depLoss, mu, gpd (for the
-- style), gpdMean, gpdLow, gpdHigh, evidence, proven, flags = {...}, why = {...} }
function M.Evaluate(id, opts)
    opts = opts or {}
    local st = M.Stats()
    local set = M.Settings()
    local style = STYLE[opts.style or set.style] or STYLE.steady
    local D = opts.dur or set.dur or 48
    local it = st.items[id]
    local c1, c2 = Category(id)
    local parent = st.sub[c2] or st.cats[c1] or st.G
    local shape = M.MarketShape(id)
    local mkt, listed, scanT = M.MarketNow(id)
    local ev = { id = id, flags = {}, why = {}, market = mkt, listed = listed, scanT = scanT, shape = shape, item = it }

    -- reference price: the market's lowest now, else what it has sold for
    local realized = it and it.soldN > 0 and it.rev / it.soldN or nil
    local ref = opts.price or mkt or realized
    if not ref or ref <= 0 then ev.noPrice = true; return ev end
    ev.ref = ref
    if scanT and time() - scanT > 3 * DAY then ev.flags.stale = true end

    -- the sell rate at the price you usually post at, from your sales
    local S = it and it.S or 0
    local lambda = ((S) + K_LAMBDA) / ((it and it.E or 0) + K_LAMBDA / parent.lambda)
    local rBar = (it and it.ratioW > 0) and it.ratioE / it.ratioW or 1.0
    local mBar = st.mult[Bucket(rBar)]
    -- how much the market takes from you a day while you have some up
    local muPrior = parent.mu
    if shape.turnover and shape.turnover > 0 and S < PROVEN then
        muPrior = math.max(muPrior * 0.5, shape.turnover * MARKET_SHARE)
        ev.why[#ev.why + 1] = ("market turnover ~%.1f a day"):format(shape.turnover)
    end
    local soldW = it and it.soldW or 0
    local mu = (soldW + K_MU) / ((it and it.stockD or 0) + K_MU / muPrior)
    -- certainty grows with sales
    local spread = style.z / math.sqrt(S + K_LAMBDA)
    local lowF, highF = math.max(0.12, 1 - spread), 1 + 1.28 / math.sqrt(S + K_LAMBDA)
    local muSpread = style.z / math.sqrt(soldW + K_MU)
    local muLow, muHigh = math.max(0.12, 1 - muSpread), 1 + 1.28 / math.sqrt(soldW + K_MU)

    -- the forecast's own track record for this type of item
    local cc = st.cal.c[c2]
    local bias = cc and cc.err / (cc.n + 5) or (st.cal.g.n > 0 and st.cal.g.err / (st.cal.g.n + 10) or 0)
    -- it corrects the starting guess, so it fades as the item's own sales take over
    bias = bias * K_LAMBDA / (S + K_LAMBDA)
    ev.bias = bias

    local cost = M.UnitCost(id)
    if not cost and it and it.profitU > 0 then cost = (it.net - it.profit) / it.profitU end
    ev.cost = cost
    if not cost then ev.flags.noCost = true end
    local cut = st.cut or DEFAULT_CUT
    local depH = DepositPerHour(id, st, it)

    -- market shape: price jumping about, supply piling up, price sliding
    local riskF = 1
    if shape.cv then riskF = riskF * (1 - math.min(0.4, shape.cv * 0.6) * style.risk) end
    if shape.n and shape.medianN and shape.medianN > 0 and shape.n > shape.medianN * 1.3 then
        local f = math.sqrt((shape.medianN * 1.3) / shape.n)
        riskF = riskF * (1 - (1 - f) * style.risk)
        ev.flags.flooded = true
    end
    local trendF = 1
    if shape.trend and shape.trend < 0.97 then
        trendF = 1 - (1 - shape.trend) * style.risk
        ev.flags.falling = true
    elseif shape.trend and shape.trend > 1.05 then
        ev.flags.rising = true
    end

    local function at(ratio, price)
        price = price or RoundPrice(id, ref * ratio * trendF)
        local m = st.mult[Bucket(price / (mkt or ref))] / mBar
        local lam = lambda * m
        local function p(l) return Clamp(1 - math.exp(-l * D) + bias, 0.02, 0.99) end
        local pMean, pLow, pHigh = p(lam), p(lam * lowF), p(lam * highF)
        local dep = depH * D
        local net = price * (1 - cut)
        local function profit(pp) return net - (cost or 0) - dep * (1 / pp - 1) end
        local u = mu * m
        local r = {
            price = price, ratio = price / (mkt or ref), p = pMean, pLow = pLow, pHigh = pHigh,
            pRaw = 1 - math.exp(-lam * D),
            hours = 1 / lam, net = net, dep = dep, depLoss = dep * (1 / pMean - 1),
            profitU = profit(pMean), mu = u,
            gpdMean = profit(pMean) * u,
            gpdLow = profit(pLow) * u * muLow * riskF,
            gpdHigh = profit(pHigh) * u * muHigh,
        }
        local zf = style.z / 1.28
        r.gpd = r.gpdMean + (r.gpdLow - r.gpdMean) * zf
        return r
    end

    local best
    if opts.price then
        best = at(nil, opts.price)
    else
        for _, ratio in ipairs(TRY_RATIOS) do
            local r = at(ratio)
            if not best or r.gpd > best.gpd then best = r end
        end
    end
    for k, v in pairs(best) do ev[k] = v end
    ev.evidence = (it and (it.soldN + it.expN + it.canN)) or 0
    ev.soldN = it and it.soldN or 0
    ev.proven = ev.soldN >= PROVEN
    ev.roiDay = (cost and cost > 0) and (ev.profitU / cost) / math.max(1 / 24, ev.hours / 24) or nil
    ev.style = style
    ev.dur = D
    return ev
end

-- What the advisor expects for a post: chance a unit sells within its
-- listing time, and hours to sell (stored on the post, graded later).
function M.Predict(id, unit, hours)
    local ev = M.Evaluate(id, { price = unit, dur = hours, style = "bold" })
    if ev.noPrice then return nil end
    return ev.p, ev.hours, ev.pRaw
end

-------------------------------------------------------------------------------
--  Recommendations
-------------------------------------------------------------------------------
local function Makers(rec)
    local out, mine = {}, false
    local me = M.Me()
    local alts = JQ.Alts and JQ.Alts.RealmTable and JQ.Alts.RealmTable() or {}
    for who in pairs((type(rec) == "table" and rec.by) or {}) do
        if alts[who] then
            out[#out + 1] = who
            if who == me then mine = true end
        end
    end
    table.sort(out, function(a, b) if (a == me) ~= (b == me) then return a == me end return a < b end)
    return out, mine
end
M.Makers = Makers

-- How many you have already: every character's bags, bank and mail, plus
-- what's up on the auction house now.
function M.Stock(id)
    local have = 0
    for _, e in ipairs((JQ.Alts and JQ.Alts.List and JQ.Alts.List(true)) or {}) do
        have = have + (JQ.Alts.Count(e.data, id))
    end
    local listed = 0
    for _, L in pairs(M.Book().listings) do
        if L.id == id and L.st ~= "done" then listed = listed + M.Left(L) end
    end
    return have, listed
end

local recCache, recVersion, recStamp, recStyle
function M.Recommend()
    local now = time()
    local set = M.Settings()
    if recCache and recVersion == M.version and now - recStamp < 60 and recStyle == set.style .. set.dur then return recCache end
    local st = M.Stats()
    local make, test, stop = {}, {}, {}
    local idx = JaseQoLDB.recipeIndex or {}
    local stopped = {}
    -- what isn't paying its way (anything you've posted)
    for id, it in pairs(st.items) do
        local fails = it.expN + it.canN
        local reasons = {}
        local str = (it.soldN + fails) > 0 and it.soldN / (it.soldN + fails) or nil
        if fails >= 3 and str and str < 0.3 then
            reasons[#reasons + 1] = ("sold %d of %d posted"):format(it.soldN, it.soldN + fails)
        end
        if it.profitU >= 2 and it.profit < 0 then reasons[#reasons + 1] = "sold at a loss to materials" end
        if it.depLost > 0 and it.depLost > math.max(0, it.profitU > 0 and it.profit or it.net) then
            reasons[#reasons + 1] = "deposits lost cost more than it made"
        end
        if #reasons > 0 then
            local ev = M.Evaluate(id)
            ev.reasons = reasons
            ev.makers = idx[id] and (Makers(idx[id])) or {}
            ev.stopScore = (it.depLost + math.max(0, -it.profit)) + fails
            stop[#stop + 1] = ev
            stopped[id] = true
        end
    end
    for id, rec in pairs(idx) do
        local makers, mine = Makers(rec)
        if not stopped[id] and #makers > 0 then
            local ev = M.Evaluate(id)
            if not ev.noPrice then
                ev.makers, ev.mine, ev.per = makers, mine, math.max(1, rec.n or 1)
                local have, listed = M.Stock(id)
                ev.have, ev.listedMine = have, listed
                if ev.proven and ev.gpd > 0 and ev.profitU > 0 then
                    -- one listing period's worth, but no more than a step past
                    -- what you've already had up at once and seen sell: it
                    -- scales up as the market proves it takes more
                    local it = ev.item
                    local done = it.soldN + it.expN + it.canN
                    local str = done > 0 and it.soldN / done or 0.5
                    local ramp = math.max(2, math.ceil((it.peak or 1) * str * (1.5 + (1 - ev.style.z / 1.28) * 0.5)) + 1)
                    local want = math.ceil(ev.mu * (ev.dur / 24) * math.max(0.5, 1 - ev.style.z * 0.2))
                    ev.target = Clamp(want, 1, math.min(40, ramp))
                    ev.ramped = want > ev.target
                    ev.toMake = math.max(0, ev.target - have - listed)
                    ev.crafts = math.ceil(ev.toMake / ev.per)
                    make[#make + 1] = ev
                elseif not ev.proven and ev.profitU > 0 and ev.pHigh > 0.08 and not ev.flags.noCost then
                    -- a small test
                    ev.target = 2
                    ev.toMake = math.max(0, 2 - have - listed)
                    ev.crafts = math.ceil(ev.toMake / ev.per)
                    test[#test + 1] = ev
                end
            end
        end
    end
    table.sort(make, function(a, b) return a.gpd > b.gpd end)
    table.sort(test, function(a, b) return a.gpdHigh > b.gpdHigh end)
    table.sort(stop, function(a, b) return a.stopScore > b.stopScore end)
    recCache = { make = make, test = test, stop = stop }
    recVersion, recStamp, recStyle = M.version, now, set.style .. set.dur
    return recCache
end

-- A number to sort recipes by elsewhere (the Professions window): the
-- style's gold per day, or nil when there's no price.
function M.Score(id)
    if not (M.On() and id) then return nil end
    local ok, ev = pcall(M.Evaluate, id)
    if not ok or not ev or ev.noPrice then return nil end
    return ev.gpd, ev
end

-------------------------------------------------------------------------------
--  Formatting shared by the window and tooltips
-------------------------------------------------------------------------------
function M.Money(c)
    if not c then return "?" end
    local neg = c < 0
    c = math.floor(math.abs(c) + 0.5)
    local g, s, cc = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    local out
    if g > 0 then out = ("%dg %02ds"):format(g, s)
    elseif s > 0 then out = ("%ds %02dc"):format(s, cc)
    else out = cc .. "c" end
    return (neg and "-" or "") .. out
end

function M.Hours(h)
    if not h or h ~= h or h == math.huge then return "?" end
    if h < 1 then return ("%dm"):format(math.max(1, math.floor(h * 60 + 0.5))) end
    if h < 48 then return ("%.0fh"):format(h) end
    return ("%.0fd"):format(h / 24)
end

function M.Ago(t)
    if not t then return "never" end
    local d = time() - t
    if d < HOUR then return ("%dm ago"):format(math.max(1, math.floor(d / 60))) end
    if d < DAY then return ("%dh ago"):format(math.floor(d / HOUR)) end
    return ("%dd ago"):format(math.floor(d / DAY))
end

-- the "why" of an evaluation, as tooltip lines { left, right } or { text }
function M.Explain(ev)
    local L = {}
    local M_ = M.Money
    local it = ev.item
    if it and (it.soldN + it.expN + it.canN) > 0 then
        local fails = it.expN + it.canN
        L[#L + 1] = { "Your sales", ("%d sold, %d expired, %d cancelled"):format(it.soldN, it.expN, it.canN) }
        local med = Median(it.hours)
        if med then L[#L + 1] = { "Typical time to sell", M.Hours(med) } end
        if it.soldN > 0 then L[#L + 1] = { "Average sale", M_(it.rev / it.soldN) .. " each" } end
        if it.profitU > 0 then L[#L + 1] = { "Profit made so far", M_(it.profit) } end
        if it.depLost > 0 then L[#L + 1] = { "Deposits lost", M_(it.depLost) } end
        if fails > 0 and it.soldN == 0 then L[#L + 1] = { "|cffff7070It has never sold yet.|r" } end
    else
        L[#L + 1] = { "|cff9e9ea8You haven't sold this yet: the numbers are estimates from similar items and the market.|r" }
    end
    L[#L + 1] = { " " }
    if ev.market then
        L[#L + 1] = { "Lowest on the AH", M_(ev.market) .. (ev.listed and ("  (" .. ev.listed .. " up)") or "") }
    end
    if ev.price then
        L[#L + 1] = { "Best price to post", ("%s  (%s)"):format(M_(ev.price), BUCKETS[Bucket(ev.ratio or 1)].label) }
        L[#L + 1] = { ("Chance it sells in %dh"):format(ev.dur or 48), ("%d%%  (%d-%d%%)"):format(ev.p * 100, ev.pLow * 100, ev.pHigh * 100) }
        L[#L + 1] = { "Expected time to sell", M.Hours(ev.hours) }
        L[#L + 1] = { "You get (after the AH cut)", M_(ev.net) }
        if ev.cost then L[#L + 1] = { "Costs to make", M_(ev.cost) } end
        if ev.depLoss and ev.depLoss >= 1 then L[#L + 1] = { "Deposits lost on relists", M_(ev.depLoss) .. " per sale" } end
        L[#L + 1] = { "Profit per sale", M_(ev.profitU) }
        L[#L + 1] = { "Sells about", ("%.1f a day while you have some up"):format(ev.mu) }
        L[#L + 1] = { ev.style.label .. " gold a day", M_(ev.gpd) }
        L[#L + 1] = { "Range", ("%s to %s a day"):format(M_(ev.gpdLow), M_(ev.gpdHigh)) }
        if ev.roiDay then L[#L + 1] = { "Return on gold tied up", ("%.0f%% a day"):format(ev.roiDay * 100) } end
    end
    local f = ev.flags or {}
    if f.stale then L[#L + 1] = { "|cffffb040Prices are over 3 days old: scan the auction house.|r" } end
    if f.noCost then L[#L + 1] = { "|cffffb040Some materials have no price, so the cost isn't known.|r" } end
    if f.flooded then L[#L + 1] = { "|cffffb040More are listed than usual right now.|r" } end
    if f.falling then L[#L + 1] = { ("|cffffb040Price has slipped %d%% this week.|r"):format((1 - (ev.shape.trend or 1)) * 100) } end
    if f.rising then L[#L + 1] = { "|cff59d959Price is rising.|r" } end
    if ev.shape and ev.shape.cv and ev.shape.cv > 0.25 then L[#L + 1] = { "|cffffb040The price jumps about a lot.|r" } end
    if ev.bias and math.abs(ev.bias) > 0.05 then
        L[#L + 1] = { ("|cff9e9ea8Adjusted %s%d%% from how past forecasts for this type turned out.|r"):format(ev.bias > 0 and "+" or "", ev.bias * 100) }
    end
    if ev.ramped then
        L[#L + 1] = { ("|cff9e9ea8Holding at %d up: the market may take more, but you haven't had that many up at once yet. It goes up as they keep selling.|r"):format(ev.target) }
    end
    for _, w in ipairs(ev.why or {}) do L[#L + 1] = { "|cff9e9ea8" .. w .. "|r" } end
    return L
end

-------------------------------------------------------------------------------
--  Item tooltips
-------------------------------------------------------------------------------
local TIP_KEY = "salesTooltip"
JQ.AddModule({
    key = TIP_KEY,
    label = "Sales history on item tooltips",
    description = "Item tooltips show how that item has sold for you (sold / posted, time to sell, average sale, profit) and the advisor's gold a day. Needs the Sales ledger.",
    default = true,
})

local function TipLines(tt, data)
    if not (M.On() and JQ.IsEnabled(TIP_KEY)) then return end
    if tt ~= GameTooltip and tt ~= ItemRefTooltip then return end
    local id = data and data.id
    if not id and tt.GetItem then
        local _, link = tt:GetItem()
        id = link and tonumber(link:match("item:(%d+)"))
    end
    if not id then return end
    local st = M.Stats()
    local it = st.items[id]
    local crafted = JaseQoLDB.recipeIndex and JaseQoLDB.recipeIndex[id]
    if not it and not crafted then return end
    local hex = JQ.UI and JQ.UI.AccentHex and JQ.UI.AccentHex() or "0cd29f"
    tt:AddLine(" ")
    if it and (it.soldN + it.expN + it.canN + it.live) > 0 then
        local fails = it.expN + it.canN
        local med = Median(it.hours)
        tt:AddDoubleLine(("|cff%sSales|r"):format(hex),
            ("%d of %d sold%s"):format(it.soldN, it.soldN + fails, med and ("  ~" .. M.Hours(med)) or ""), 1, 1, 1, 1, 1, 1)
        if it.soldN > 0 then
            local extra = it.profitU > 0 and ("  (profit %s each)"):format(M.Money(it.profit / it.profitU)) or ""
            tt:AddDoubleLine("|cff9e9ea8Average sale|r", M.Money(it.rev / it.soldN) .. extra, 1, 1, 1, 1, 1, 1)
        end
        if it.live > 0 then tt:AddDoubleLine("|cff9e9ea8Up now|r", it.live, 1, 1, 1, 1, 1, 1) end
    end
    local ok, ev = pcall(M.Evaluate, id)
    if ok and ev and not ev.noPrice and ev.price then
        tt:AddDoubleLine(("|cff%sAdvisor|r"):format(hex),
            ("%s a day, post at %s"):format(M.Money(ev.gpd), M.Money(ev.price)), 1, 1, 1, ev.gpd > 0 and 0.35 or 1, ev.gpd > 0 and 0.85 or 0.44, ev.gpd > 0 and 0.35 or 0.44)
    end
    tt:Show()
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
        JQ.Try("sales tooltip", TipLines, tt, data)
    end)
else
    for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
        if tt and tt.HookScript then
            pcall(tt.HookScript, tt, "OnTooltipSetItem", function(self) JQ.Try("sales tooltip", TipLines, self) end)
        end
    end
end

-- for tests
JQ._MarketBrain = { Bucket = Bucket, MergeStock = MergeStock, RoundPrice = RoundPrice, Category = Category,
    Reset = function() stats = nil; recCache = nil; costCache = {} end }
