-------------------------------------------------------------------------------
--  JaseTools: Market tab (/jmarket, /jsales)
--
--  Views:
--    Make     proven sellers, best steady gold a day first: how many to make
--             (one listing period's worth, less what you and your alts hold
--             and have up), the price to post at, chance and time to sell.
--             Make crafts it when this character knows the recipe.
--    Test     look good on paper but you've not sold them yet: make 1-2 and
--             see. Ranked by their upside; they move to Make once proven.
--    Stop     what isn't paying its way, and why.
--    Items    everything you've posted, with its record.
--    Log      every post, newest first, and what became of it.
--    Summary  income, deposits lost, sell-through, how right the forecasts
--             have been, and what it has learned about pricing.
--  Style (Steady / Balanced / Bold) sets how cautious the ranking is;
--  Listing sets the auction length you use (12, 24 or 48 h).
--  Hover any row for the full working.
-------------------------------------------------------------------------------
local _, JQ = ...
local M = JQ.Market
if not M then return end
local UI = JQ.UI
local KEY = "salesLedger"

local win, db
local ROW_H = 26
local Money, Hours = M.Money, M.Hours

local VIEWS = {
    { key = "make", label = "Make" },
    { key = "test", label = "Test" },
    { key = "stop", label = "Stop" },
    { key = "items", label = "Items" },
    { key = "log", label = "Log" },
    { key = "summary", label = "Summary" },
}

-- column headings and widths per view (right to left after the name)
local COLS = {
    make = { who = "Made by", { "Gold/day", 78 }, { "Profit/sale", 78 }, { "Post at", 74 }, { "Sells in", 58 }, { "Chance", 52 }, { "Have", 52 } },
    test = { who = "Made by", { "Upside/day", 78 }, { "Profit/sale", 78 }, { "Post at", 74 }, { "Sells in", 58 }, { "Chance", 52 }, { "Have", 52 } },
    stop = { who = "Why", { "Sold", 64 }, { "Deposits lost", 86 }, { "Profit", 78 } },
    items = { who = "Last sale", { "Sold", 64 }, { "Sell rate", 62 }, { "Time to sell", 76 }, { "Avg sale", 78 }, { "Profit", 78 }, { "Up now", 52 } },
    log = { who = "What happened", { "Qty", 44 }, { "Price each", 78 }, { "Posted", 70 }, { "By", 90 } },
    summary = { who = "" },
}

local function Pct(v) return v and ("%d%%"):format(math.floor(v * 100 + 0.5)) or "-" end

local function Green(s) return "|cff59d959" .. s .. "|r" end
local function Red(s) return "|cffff7070" .. s .. "|r" end
local function Muted(s) return "|cff9e9ea8" .. s .. "|r" end
local function Signed(c) if not c then return Muted("?") end return c >= 0 and Green(Money(c)) or Red(Money(c)) end

local function WhoText(names)
    if not names or #names == 0 then return Muted("-") end
    local me = M.Me()
    local parts = {}
    for i, n in ipairs(names) do
        if i > 2 then parts[#parts + 1] = Muted("+" .. (#names - 2)); break end
        local data = JQ.Alts.RealmTable()[n]
        local disp = JQ.Alts.Display and JQ.Alts.Display(n) or n
        parts[#parts + 1] = ("|cff%s%s|r"):format(UI.ClassHex(data and data.class), n == me and (disp .. "*") or disp)
    end
    return table.concat(parts, ", ")
end

-------------------------------------------------------------------------------
--  Rows for each view
-------------------------------------------------------------------------------
local function Matches(name)
    local needle = win.search:Needle()
    return needle == "" or (name or ""):lower():find(needle, 1, true) ~= nil
end

local function EvRows(list, upside)
    local out = {}
    for _, ev in ipairs(list) do
        local name, q = UI.ItemNameQuality(ev.id)
        if Matches(name) then
            out[#out + 1] = {
                id = ev.id, name = name, q = q, ev = ev, who = WhoText(ev.makers),
                cols = {
                    Signed(upside and ev.gpdHigh or ev.gpd),
                    Signed(ev.profitU),
                    Money(ev.price),
                    Hours(ev.hours),
                    Pct(ev.p),
                    ("%d|cff9e9ea8/%d|r"):format((ev.have or 0) + (ev.listedMine or 0), ev.target or 0),
                },
                make = ev.mine and (ev.toMake or 0) > 0 and ev.toMake or nil,
                makeAlt = not ev.mine and (ev.toMake or 0) > 0,
            }
        end
    end
    return out
end

local function StopRows(list)
    local out = {}
    for _, ev in ipairs(list) do
        local it = ev.item
        local name, q = UI.ItemNameQuality(ev.id)
        if it and Matches(name) then
            out[#out + 1] = {
                id = ev.id, name = name, q = q, ev = ev, who = "|cffffb040" .. table.concat(ev.reasons, "; ") .. "|r",
                cols = {
                    ("%d/%d"):format(it.soldN, it.soldN + it.expN + it.canN),
                    it.depLost > 0 and Red(Money(it.depLost)) or Muted("-"),
                    it.profitU > 0 and Signed(it.profit) or Muted("?"),
                },
            }
        end
    end
    return out
end

local function ItemRows()
    local st = M.Stats()
    local out = {}
    for id, it in pairs(st.items) do
        local name, q = UI.ItemNameQuality(id)
        if Matches(name) then
            local done = it.soldN + it.expN + it.canN
            local med = M.Median(it.hours)
            out[#out + 1] = {
                id = id, name = name, q = q, item = it, who = Muted(M.Ago(it.lastSale)), sortKey = it.net,
                cols = {
                    ("%d/%d"):format(it.soldN, done),
                    done > 0 and Pct(it.soldN / done) or Muted("-"),
                    med and Hours(med) or Muted("-"),
                    it.soldN > 0 and Money(it.rev / it.soldN) or Muted("-"),
                    it.profitU > 0 and Signed(it.profit) or Muted("?"),
                    it.live > 0 and tostring(it.live) or Muted("-"),
                },
            }
        end
    end
    table.sort(out, function(a, b) return (a.sortKey or 0) > (b.sortKey or 0) end)
    return out
end

local function Status(L)
    local left = M.Left(L)
    if L.st == "pend" and not L.conf then return Muted("posting...") end
    if L.st ~= "done" then
        local ends = (L.t or 0) + (L.dur or 48) * 3600
        local sold = (L.sold or 0) > 0 and (Green(("%d sold"):format(L.sold)) .. ", ") or ""
        return sold .. ("up, %s left"):format(Hours(math.max(0, ends - time()) / 3600))
    end
    local parts = {}
    if (L.sold or 0) > 0 then
        local h = (L.sT and L.sold > 0) and L.sT / L.sold or nil
        parts[#parts + 1] = Green(((L.sold == L.q) and "sold" or ("%d sold"):format(L.sold))
            .. ((h and not L.adopt) and (" in " .. Hours(h)) or ""))
            .. ((L.est or 0) > 0 and Muted(" (no mail yet)") or "")
    end
    if (L.exp or 0) > 0 then parts[#parts + 1] = Red(((L.exp == L.q) and "expired" or ("%d expired"):format(L.exp))) .. ((L.inf or 0) > 0 and Muted(" (by the clock)") or "") end
    if (L.can or 0) > 0 then parts[#parts + 1] = "|cffffb040" .. ((L.can == L.q) and "cancelled" or ("%d cancelled"):format(L.can)) .. "|r" end
    if left > 0 then parts[#parts + 1] = left .. " unaccounted" end
    return table.concat(parts, ", ")
end

local function LogRows()
    local out = {}
    for _, L in pairs(M.Book().listings) do
        local name = L.name or (L.id and UI.ItemNameQuality(L.id)) or "?"
        if Matches(name) then
            local _, q = L.id and UI.ItemNameQuality(L.id)
            out[#out + 1] = {
                id = L.id, name = name, q = q, L = L, who = Status(L), t = L.t or 0,
                cols = {
                    tostring(L.q or "?"),
                    Money(L.u),
                    L.adopt and Muted("before") or M.Ago(L.t),
                    WhoText({ L.who }),
                },
            }
        end
    end
    table.sort(out, function(a, b) return a.t > b.t end)
    while #out > 300 do table.remove(out) end
    return out
end

local function SummaryRows()
    local st = M.Stats()
    local T = st.totals
    local rows = {}
    local function head(s) rows[#rows + 1] = { text = ("|cff%s%s|r"):format(UI.AccentHex(), s:upper()), head = true } end
    local function line(l, r) rows[#rows + 1] = { text = l, right = r } end
    local set = M.Settings()

    head("Income (after the AH cut)")
    line("Today", Money(T.day))
    line("Last 7 days", ("%s   |cff9e9ea8profit %s, deposits lost %s|r"):format(Money(T.week), Money(T.profitWeek), Money(T.depWeek)))
    line("Last 30 days", ("%s   |cff9e9ea8profit %s, deposits lost %s|r"):format(Money(T.month), Money(T.profitMonth), Money(T.depMonth)))
    line("Average a day (30 days, less deposits lost)", Money((T.month - T.depMonth) / 30))
    line("Up on the AH now", ("%d units, %s at list price"):format(T.liveUnits, Money(T.liveValue)))

    head("How things sell")
    local done = T.soldMonth + T.failMonth
    line("Sell-through (30 days)", done > 0 and ("%s  |cff9e9ea8(%d sold, %d expired or cancelled)|r"):format(Pct(T.soldMonth / done), T.soldMonth, T.failMonth) or Muted("nothing finished yet"))
    local med = M.Median(st.G.hours)
    line("Typical time to sell", med and Hours(med) or Muted("-"))
    line("AH cut", ("%.1f%%%s"):format((st.cut or 0.05) * 100, M.Book().cut and "" or Muted("  (assumed until a sale mail is read)")))

    head("How right the forecasts have been")
    local cal = st.cal.g
    if cal.cnt > 0 and cal.n > 0 then
        line("Listings graded", tostring(cal.cnt))
        line("Forecast to sell vs did sell", ("%s vs %s"):format(Pct(cal.pred / cal.n), Pct(cal.out / cal.n)))
        line("Accuracy (Brier)", ("%.2f  |cff9e9ea8(0 is perfect, 0.25 is a coin toss)|r"):format(cal.sq / cal.n))
        local bias = cal.err / (cal.n + 10)
        line("Correction to guesses for new items", ("%s%d%%"):format(bias >= 0 and "+" or "", math.floor(bias * 100 + 0.5)))
    else
        line(Muted("Every post records a forecast; once listings finish they are graded here."))
    end

    head("What it has learned about price")
    for i, bk in ipairs(M.BUCKETS) do
        local d = st.buckets[i]
        line("Listed " .. bk.label, ("sells %.2fx as fast  |cff9e9ea8(%d%% learned, %d%% guess)|r"):format(d.mult, d.weight * 100, (1 - d.weight) * 100))
    end

    head("Top earners (all time, profit or income)")
    local top = {}
    for id, it in pairs(st.items) do
        local v = it.profitU > 0 and it.profit or it.net
        if v > 0 then top[#top + 1] = { id = id, v = v, it = it } end
    end
    table.sort(top, function(a, b) return a.v > b.v end)
    for i = 1, math.min(6, #top) do
        local e = top[i]
        local name = UI.ItemNameQuality(e.id)
        local hrs = M.Median(e.it.hours)
        line("  " .. name, ("%s  |cff9e9ea8%d sold%s|r"):format(Signed(e.v), e.it.soldN, hrs and (", ~" .. Hours(hrs)) or ""))
    end
    if #top == 0 then line(Muted("Post something on the auction house to start the ledger.")) end

    head("Settings")
    line("Style", M.STYLE[set.style].label .. Muted("  - Steady ranks by a cautious estimate; Bold by the average"))
    line("Listing length", set.dur .. "h" .. Muted("  - the auction length you post at"))
    line("Ledger started", date("%d %b %Y", M.Book().firstT))
    return rows
end

-------------------------------------------------------------------------------
--  Window
-------------------------------------------------------------------------------
local function Layout(row, view)
    local spec = COLS[view]
    local x = -8
    if view == "make" or view == "test" then
        row.make:Show()
        row.make:ClearAllPoints()
        row.make:SetPoint("RIGHT", x, 0)
        x = x - 72
    else
        row.make:Hide()
    end
    for i = 1, 6 do
        local c = row.c[i]
        local idx = #spec - i + 1
        local col = spec[idx]
        if idx >= 1 and col then
            c:ClearAllPoints()
            c:SetPoint("RIGHT", x, 0)
            c:SetWidth(col[2])
            c:Show()
            c.slot = idx
            x = x - col[2] - 6
        else
            c:Hide()
            c.slot = nil
        end
    end
    row.who:ClearAllPoints()
    row.who:SetPoint("RIGHT", x, 0)
    row.who:SetPoint("LEFT", row, "LEFT", 250, 0)
    return x
end

local function RowEnter(self)
    local d = self.data
    if not d or d.text then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if d.id then GameTooltip:SetItemByID(d.id) else GameTooltip:SetText(d.name or "?") end
    local ev = d.ev
    if not ev and d.id and (d.item or d.L) then
        local ok, e = pcall(M.Evaluate, d.id)
        if ok then ev = e end
    end
    if d.L then
        local L = d.L
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Posted", ("%d x %s for %dh by %s"):format(L.q or 0, Money(L.u), L.dur or 48, L.who or "?"), 0.8, 0.8, 0.8, 1, 1, 1)
        if L.mkt then GameTooltip:AddDoubleLine("Lowest on the AH then", Money(L.mkt), 0.8, 0.8, 0.8, 1, 1, 1) end
        if L.dep then GameTooltip:AddDoubleLine("Deposit", Money(L.dep), 0.8, 0.8, 0.8, 1, 1, 1) end
        if L.cost then GameTooltip:AddDoubleLine("Cost to make then", Money(L.cost) .. " each", 0.8, 0.8, 0.8, 1, 1, 1) end
        if L.pP then GameTooltip:AddDoubleLine("Forecast", ("%s chance, ~%s"):format(Pct(L.pP), Hours(L.pH)), 0.8, 0.8, 0.8, 1, 1, 1) end
        if (L.rev or 0) > 0 then GameTooltip:AddDoubleLine("Taken", Money(L.rev), 0.8, 0.8, 0.8, 1, 1, 1) end
    elseif ev and not ev.noPrice then
        GameTooltip:AddLine(" ")
        for _, l in ipairs(M.Explain(ev)) do
            if l[2] then GameTooltip:AddDoubleLine(l[1], l[2], 0.8, 0.8, 0.8, 1, 1, 1)
            else GameTooltip:AddLine(l[1], 1, 1, 1, true) end
        end
        if d.make then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(("Make: makes %d now (opens the profession if it has to: click again if it does)."):format(d.make), 0.35, 0.85, 0.35, true)
        elseif d.makeAlt then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Made by an alt: log onto them to make it.", 0.62, 0.62, 0.66, true)
        end
    elseif ev and ev.noPrice then
        GameTooltip:AddLine("No auction price yet: scan the auction house.", 0.62, 0.62, 0.66, true)
    end
    GameTooltip:Show()
end

local function CreateRow(L)
    local row = CreateFrame("Button", nil, L)
    UI.Fill(row, 1, 1, 1, 0.07, "HIGHLIGHT")
    row.stripe = UI.Fill(row, 1, 1, 1, 0.03)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", 6, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.name = UI.Text(row, 12)
    row.name:SetPoint("LEFT", 32, 0)
    row.name:SetWidth(210)
    row.who = UI.Text(row, 11, 0.85, 0.85, 0.88)
    row.c = {}
    for i = 1, 6 do row.c[i] = UI.Text(row, 11, 0.92, 0.92, 0.94, "RIGHT") end
    row.make = UI.Button(row, "Make", 64, 20)
    row.make:SetScript("OnMouseDown", function(self)
        if self.id and JQ.Requests and JQ.Requests.MakePrepare then JQ.Try("market: make", JQ.Requests.MakePrepare, self.id) end
    end)
    row.make:SetScript("OnClick", function(self)
        if self.id and self.n and JQ.Requests and JQ.Requests.MakeNow then JQ.Try("market: make", JQ.Requests.MakeNow, self.id, self.n) end
    end)
    row.text = UI.Text(row, 12)
    row.text:SetPoint("LEFT", 10, 0)
    row.right = UI.Text(row, 12, 1, 1, 1, "LEFT")
    row.right:SetPoint("LEFT", 260, 0)
    row.right:SetPoint("RIGHT", -10, 0)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", UI.HideTip)
    row:SetScript("OnClick", UI.ItemClick)
    return row
end

local function UpdateRow(row, d, i)
    row.data = d
    row.itemID = d.id
    row.stripe:SetShown(i % 2 == 0)
    local view = db.view
    if d.text then
        row.icon:Hide(); row.name:Hide(); row.who:Hide(); row.make:Hide()
        for _, c in ipairs(row.c) do c:Hide() end
        row.text:Show(); row.right:Show()
        row.text:SetText(d.text)
        row.right:SetText(d.right or "")
        row.stripe:SetShown(false)
        return
    end
    row.text:Hide(); row.right:Hide()
    row.icon:Show(); row.name:Show(); row.who:Show()
    row.icon:SetTexture(d.id and UI.ItemIcon(d.id) or 134400)
    row.name:SetText(d.name or "?")
    row.name:SetTextColor(UI.QualityColor(d.q))
    Layout(row, view)
    row.who:SetText(d.who or "")
    for _, c in ipairs(row.c) do
        if c.slot then c:SetText((d.cols and d.cols[c.slot]) or "") end
    end
    if view == "make" or view == "test" then
        row.make.id = d.id
        row.make.n = d.make
        if d.make then
            row.make.text:SetText("Make " .. d.make)
            row.make:SetEnabledLook(true)
        else
            row.make.text:SetText(d.makeAlt and "Alt" or "Stocked")
            row.make:SetEnabledLook(false)
        end
    end
end

local function Refresh()
    if not (win and win:IsShown()) then return end
    local view = db.view
    for _, b in ipairs(win.viewBtns) do b:SetOn(b.key == view) end
    local set = M.Settings()
    win.styleBtn.text:SetText("Style: " .. M.STYLE[set.style].label)
    win.durBtn.text:SetText("Listing: " .. set.dur .. "h")
    -- headings
    local spec = COLS[view]
    win.headName:SetText(view == "summary" and "" or "Item")
    win.head.who:SetText(spec.who or "")
    Layout(win.head, view)
    win.head.make:Hide()
    for _, c in ipairs(win.head.c) do
        c:SetText(c.slot and spec[c.slot] and spec[c.slot][1] or "")
    end
    win.head:SetShown(view ~= "summary")

    local items
    local ok, err = pcall(function()
        if view == "make" or view == "test" or view == "stop" then
            local rec = M.Recommend()
            if view == "make" then items = EvRows(rec.make, false)
            elseif view == "test" then items = EvRows(rec.test, true)
            else items = StopRows(rec.stop) end
        elseif view == "items" then items = ItemRows()
        elseif view == "log" then items = LogRows()
        else items = SummaryRows() end
    end)
    if not ok then
        JQ.Error("market window", err)
        items = { { text = Red("Something went wrong building this view (logged: /jq errors).") } }
    end
    if #items == 0 then
        local empty = {
            make = "Nothing proven yet. Items move here once they've sold " .. 3 .. " times: try some from Test.",
            test = "Nothing to test: open your professions (so JaseTools knows your recipes) and scan the auction house.",
            stop = "Nothing to stop: everything you've posted is paying its way.",
            items = "Nothing posted yet. Post on the auction house and it's recorded here.",
            log = "No posts yet.",
        }
        items = { { text = Muted(empty[view] or "") } }
    end
    win.list:SetItems(items, true)
    local st = M.Stats()
    win.status:SetText(("Last 7 days %s  |  30 days %s  |  %d up now"):format(Money(st.totals.week), Money(st.totals.month), st.totals.liveUnits))
end

local function Build()
    JaseQoLDB.marketView = JaseQoLDB.marketView or {}
    db = JaseQoLDB.marketView
    db.view = db.view or "make"
    win = UI.Window("JaseQoLMarket", "Market", 980, 560, db)

    win.viewBtns = {}
    local prev
    for _, v in ipairs(VIEWS) do
        local b = UI.Button(win, v.label, 74, 22)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", 10, -32) end
        b.key = v.key
        b:SetScript("OnClick", function(self) db.view = self.key; Refresh() end)
        win.viewBtns[#win.viewBtns + 1] = b
        prev = b
    end
    win.search = UI.SearchBox(win, "Search", Refresh)
    win.search:SetPoint("LEFT", prev, "RIGHT", 10, 0)
    win.search:SetWidth(160)

    win.durBtn = UI.Button(win, "", 96, 22)
    win.durBtn:SetPoint("TOPRIGHT", -10, -32)
    win.durBtn:SetScript("OnClick", function()
        local s = M.Settings()
        s.dur = (s.dur == 12 and 24) or (s.dur == 24 and 48) or 12
        Refresh()
    end)
    win.durBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Listing length")
        GameTooltip:AddLine("The auction length you usually post at. Chances to sell, deposits and how many to make are worked out for it.", 0.85, 0.85, 0.88, true)
        GameTooltip:Show()
    end)
    win.durBtn:SetScript("OnLeave", UI.HideTip)
    win.styleBtn = UI.Button(win, "", 120, 22)
    win.styleBtn:SetPoint("RIGHT", win.durBtn, "LEFT", -6, 0)
    win.styleBtn:SetScript("OnClick", function()
        local s = M.Settings()
        s.style = (s.style == "steady" and "balanced") or (s.style == "balanced" and "bold") or "steady"
        Refresh()
    end)
    win.styleBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Style")
        GameTooltip:AddLine("Steady: ranks by a cautious estimate of gold a day, and marks down items whose price jumps about or whose supply has piled up. Best for reliable income.", 0.85, 0.85, 0.88, true)
        GameTooltip:AddLine("Balanced: halfway.", 0.85, 0.85, 0.88, true)
        GameTooltip:AddLine("Bold: ranks by the average estimate and ignores market risk.", 0.85, 0.85, 0.88, true)
        GameTooltip:Show()
    end)
    win.styleBtn:SetScript("OnLeave", UI.HideTip)

    local panel = UI.Panel(win)
    panel:SetPoint("TOPLEFT", 10, -84)
    panel:SetPoint("BOTTOMRIGHT", -10, 30)

    -- column headings (a row built like the list's, without the stripe)
    win.head = CreateRow(win)
    win.head:SetHeight(18)
    win.head:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 4, 2)
    win.head:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", -14, 2)
    win.head:EnableMouse(false)
    win.head.icon:Hide()
    win.head.stripe:Hide()
    win.head.text:Hide(); win.head.right:Hide()
    win.headName = win.head.name
    for _, fs in ipairs({ win.head.name, win.head.who, unpack(win.head.c) }) do fs:SetTextColor(0.62, 0.62, 0.66) end

    win.list = UI.List(panel, ROW_H, CreateRow, UpdateRow)
    win.list:SetPoint("TOPLEFT", 4, -4)
    win.list:SetPoint("BOTTOMRIGHT", -4, 4)

    win.status = UI.Text(win, 11, 0.62, 0.62, 0.66)
    win.status:SetPoint("BOTTOMLEFT", 14, 10)
    win.hint = UI.Text(win, 11, 0.62, 0.62, 0.66, "RIGHT")
    win.hint:SetPoint("BOTTOMRIGHT", -24, 10)
    win.hint:SetText("Hover a row for the working.  * = this character")

    win:SetScript("OnShow", Refresh)
    M.OnChange(Refresh)
    JQ.Hub.Attach(win, "market")
end

JQ.Hub.Register({
    key = "market", label = "Market",
    enabled = function() return JQ.IsEnabled(KEY) end,
    frame = function() return win end,
    open = function()
        if not JQ.IsEnabled(KEY) then return end
        if not win then Build() end
        return win
    end,
})

local function Toggle(msg)
    if not JQ.IsEnabled(KEY) then JQ.Print("The sales ledger is off (/jq salesLedger).") return end
    msg = strtrim(msg or ""):lower()
    if win and win:IsShown() and msg == "" then win:Hide() return end
    JQ.Hub.Show("market")
    for _, v in ipairs(VIEWS) do
        if msg == v.key then db.view = v.key; Refresh() end
    end
end
JQ.ToggleMarket = Toggle

local function Init()
    SLASH_JASEQOLMARKET1 = "/jmarket"
    SLASH_JASEQOLMARKET2 = "/jsales"
    SlashCmdList.JASEQOLMARKET = Toggle
end
local prevLoad = JQ.byKey[KEY].onLoad
JQ.byKey[KEY].onLoad = function(enabled)
    if prevLoad then prevLoad(enabled) end
    Init()
end
local prevDisable = JQ.byKey[KEY].onDisable
JQ.byKey[KEY].onDisable = function()
    if prevDisable then prevDisable() end
    if win then win:Hide() end
end

-- for tests
JQ._MarketView = { Refresh = Refresh, SummaryRows = SummaryRows, LogRows = LogRows, ItemRows = ItemRows, Window = function() return win end }
