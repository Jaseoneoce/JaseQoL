-------------------------------------------------------------------------------
--  JaseTools: Professions (one window)
--
--  Opening a profession shows this window instead of the game's:
--    left    : your recipes, grouped as the game groups them, coloured by
--              skill-up chance, with how many you can make; search and filters
--    middle  : the recipe you picked: what it needs for N crafts (you have /
--              your alts have, and what would be made or bought), what the
--              materials cost on the auction house - buying each one, or
--              making it yourself from its own materials where that is
--              cheaper - Make, Make all and Plan mats
--    right   : your plan (the request plan with its Take from bank / Send /
--              Make buttons and auto ticks, docked here while the window is
--              open) and, with Mastercraft, its mini guide docked under it
--  "Classic view" opens the game's own window until you close it.
--
--  The game's window is still open underneath: a profession's data and
--  crafting only work while it is, and hiding it would close the profession.
--  So it is shrunk out of sight and made see-through, and put back whenever
--  this window closes or Classic view is asked for.
--
--  JaseQoLDB.profView = { win = {...}, canMake = bool, skillUps = bool, guide = bool }
-------------------------------------------------------------------------------
local _, JQ = ...
local KEY = "profView"

JQ.AddModule({
    key = KEY,
    label = "Professions: one window",
    description = "Opening a profession shows one JaseTools window instead of the game's: your recipes with search and filters, the picked recipe's materials (yours and your alts') with Make and Plan mats, and your request plan and Mastercraft's mini guide docked beside them. Classic view opens the game's own window. Off unless you switch it on (/jq profView). Needs Request mats from alts.",
    default = false,
})

local UI = JQ.UI
local win, db
local classic = false      -- the game's own window was asked for, until it closes
local tucked               -- the game's window's own scale and alpha while it is out of sight
local recipes = {}         -- the open profession's learned recipes
local byID = {}
local selected             -- recipe id
local pending = false

-- Skill lines, to switch profession from this window (the game's own tabs are out of sight).
local LINES = {
    Alchemy = 171, Blacksmithing = 164, Cooking = 185, Enchanting = 333, Engineering = 202,
    ["First Aid"] = 129, Inscription = 773, Jewelcrafting = 755, Leatherworking = 165,
    Mining = 186, Tailoring = 197,
}

local DIFF = {   -- skill-up chance, as the game colours it
    [0] = { 1.00, 0.50, 0.25 }, [1] = { 1.00, 1.00, 0.00 }, [2] = { 0.25, 0.75, 0.25 }, [3] = { 0.50, 0.50, 0.50 },
}

local ItemCount = (C_Item and C_Item.GetItemCount) or GetItemCount
local function T() return C_TradeSkillUI end

local function Blizzard() return _G.ProfessionsFrame end

-- Someone else's profession (a chat link, a guild member's): the game's window shows those.
local function IsOwnProfession()
    local t = T()
    if not t then return false end
    if t.IsTradeSkillLinked and t.IsTradeSkillLinked() then return false end
    if t.IsTradeSkillGuild and t.IsTradeSkillGuild() then return false end
    if t.IsNPCCrafting and t.IsNPCCrafting() then return false end
    return true
end

-------------------------------------------------------------------------------
--  The game's window: out of sight but open
-------------------------------------------------------------------------------
local function Tuck(on)
    local f = Blizzard()
    if not f then return end
    if on then
        if not tucked then tucked = { scale = f:GetScale(), alpha = f:GetAlpha() } end
        f:SetAlpha(0)
        f:SetScale(0.01)
    elseif tucked then
        f:SetScale(tucked.scale or 1)
        f:SetAlpha(tucked.alpha or 1)
        tucked = nil
    end
end

-------------------------------------------------------------------------------
--  Recipes
-------------------------------------------------------------------------------
local function CanMake(r)
    local n
    for _, g in ipairs(r.reagents) do
        local have = ItemCount and ItemCount(g.id) or 0
        local k = math.floor((have or 0) / math.max(1, g.per))
        if not n or k < n then n = k end
    end
    return n or 0
end

local function ReadRecipes()
    recipes, byID = {}, {}
    local t = T()
    if not (t and t.GetAllRecipeIDs and t.GetRecipeInfo) then return end
    local cats = {}
    for _, rid in ipairs(t.GetAllRecipeIDs() or {}) do
        local ok, info = pcall(t.GetRecipeInfo, rid)
        if ok and info and info.learned and info.name then
            local r = { id = rid, name = info.name, icon = info.icon, diff = info.relativeDifficulty, reagents = {}, per = 1 }
            local ok2, sch = pcall(t.GetRecipeSchematic, rid, false)
            if ok2 and sch then
                r.out = sch.outputItemID
                r.per = (sch.quantityMin and sch.quantityMin > 0) and sch.quantityMin or 1
                r.icon = r.icon or sch.icon
                for _, slot in ipairs(sch.reagentSlotSchematics or {}) do
                    local basic = not (Enum and Enum.CraftingReagentType) or slot.reagentType == Enum.CraftingReagentType.Basic
                    local reagent = slot.reagents and slot.reagents[1]
                    if basic and reagent and reagent.itemID then
                        r.reagents[#r.reagents + 1] = { id = reagent.itemID, per = slot.quantityRequired or 1 }
                    end
                end
            end
            local cat = info.categoryID and cats[info.categoryID]
            if info.categoryID and cat == nil then
                cat = false
                if t.GetCategoryInfo then
                    local ok3, c = pcall(t.GetCategoryInfo, info.categoryID)
                    if ok3 and c and c.name then cat = { name = c.name, order = c.uiOrder or 0 } end
                end
                cats[info.categoryID] = cat
            end
            r.cat = cat and cat.name or "Recipes"
            r.catOrder = cat and cat.order or 0
            recipes[#recipes + 1] = r
            byID[rid] = r
        end
    end
    table.sort(recipes, function(a, b)
        if a.catOrder ~= b.catOrder then return a.catOrder < b.catOrder end
        if a.cat ~= b.cat then return a.cat < b.cat end
        local da, dbb = a.diff or 9, b.diff or 9
        if da ~= dbb then return da < dbb end
        return a.name < b.name
    end)
end

local function ListItems()
    local needle = win and win.search:Needle() or ""
    local items, lastCat = {}, nil
    for _, r in ipairs(recipes) do
        local can = CanMake(r)
        local show = needle == "" or r.name:lower():find(needle, 1, true) ~= nil
        if show and db.canMake and can < 1 then show = false end
        if show and db.skillUps and r.diff == 3 then show = false end
        if show then
            if r.cat ~= lastCat then
                lastCat = r.cat
                items[#items + 1] = { head = r.cat }
            end
            items[#items + 1] = { r = r, can = can }
        end
    end
    if #items == 0 then
        items[1] = { head = #recipes == 0 and "Reading your recipes..." or "No recipe matches" }
    end
    return items
end

-------------------------------------------------------------------------------
--  The picked recipe
-------------------------------------------------------------------------------
local function Crafts()
    local n = win and tonumber(win.count:GetText()) or 1
    if not n or n < 1 then n = 1 end
    return math.floor(n)
end

local function ReagentList(r)
    local list = {}
    for _, g in ipairs(r.reagents) do list[#list + 1] = { id = g.id, per = g.per } end
    return list
end

-------------------------------------------------------------------------------
--  Gold: what the materials cost on the auction house (the last Mastercraft
--  or Auctionator scan). A material you can make yourself is priced both
--  ways - bought, or made from its own materials (up to three levels down) -
--  and the cheaper one counts. Vendor goods have no auction price: they are
--  left out and said so.
-------------------------------------------------------------------------------
-- cost (copper, nil when nothing has a price), "buy" | "make" | "vendor", buy cost, make cost
local function BestCost(id, qty, depth, seen)
    local R = JQ.Requests
    if qty <= 0 then return 0, "buy" end
    if R.IsVendor(id) then return 0, "vendor" end
    local buy = JQ.CostToBuy and JQ.CostToBuy(id, qty) or nil
    local make
    if depth < 3 and not seen[id] then
        local rec, can = R.MakeRecipe(id, JQ.Alts.MyName())
        if rec and can and rec.r then
            seen[id] = true
            local crafts = math.ceil(qty / math.max(1, rec.n or 1))
            local total, priced = 0, true
            for rid, q in pairs(rec.r) do
                local c = BestCost(rid, q * crafts, depth + 1, seen)
                if not c then priced = false; break end
                total = total + c
            end
            seen[id] = nil
            if priced then make = total end
        end
    end
    if buy and make then
        if make < buy then return make, "make", buy, make end
        return buy, "buy", buy, make
    end
    if buy then return buy, "buy", buy, nil end
    if make then return make, "make", nil, make end
    return nil
end

local function Gold(copper)
    local R = JQ.Requests
    return R and R.Money and R.Money(math.floor(copper + 0.5)) or tostring(copper)
end

-- What one craft of a recipe costs in materials (each bought or made,
-- whichever is cheaper): cost or nil when nothing is priced, and how many
-- materials had no price. Kept until the next refresh.
local costCache = {}
local function RecipeCost(r)
    local c = costCache[r.id]
    if c then return c.cost, c.unpriced end
    local total, unpriced, priced = 0, 0, 0
    for _, g in ipairs(r.reagents) do
        local cost, how = BestCost(g.id, g.per, 0, {})
        if how == "vendor" then
            -- no auction price counted
        elseif cost then
            total, priced = total + cost, priced + 1
        else
            unpriced = unpriced + 1
        end
    end
    c = { cost = priced > 0 and total or nil, unpriced = unpriced }
    costCache[r.id] = c
    return c.cost, c.unpriced
end

-- The gold lines under a recipe: everything for N crafts, what's still to
-- buy after your own stock and your alts, and what the result is worth.
local function CostLines(r, n, rows)
    local lines = {}
    local all, unpriced, vendor, made = 0, 0, false, 0
    for _, g in ipairs(r.reagents) do
        local c, how = BestCost(g.id, g.per * n, 0, {})
        if how == "vendor" then vendor = true
        elseif c then
            all = all + c
            if how == "make" then made = made + 1 end
        else unpriced = unpriced + 1 end
    end
    local note = {}
    if made > 0 then note[#note + 1] = ("making %d of them yourself"):format(made) end
    if unpriced > 0 then note[#note + 1] = ("%d with no price yet"):format(unpriced) end
    if vendor then note[#note + 1] = "vendor goods not counted" end
    local noteText = #note > 0 and ("  |cff9e9ea8(" .. table.concat(note, ", ") .. ")|r") or ""
    if all > 0 or unpriced == 0 then
        lines[#lines + 1] = ("Materials for %d: |cffffffff%s|r%s%s"):format(n, Gold(all),
            n > 1 and ("  |cff9e9ea8" .. Gold(all / n) .. " each|r") or "", noteText)
    else
        lines[#lines + 1] = "Materials: no auction price yet - scan the auction house." .. noteText
    end
    -- what your stock and your alts don't cover
    local toBuy, missing = 0, 0
    for _, e in ipairs(rows) do
        if e.kind == "missing" and (e.buyQty or 0) > 0 then
            missing = missing + 1
            local c = JQ.CostToBuy and JQ.CostToBuy(e.id, e.buyQty)
            if c then toBuy = toBuy + c end
        end
    end
    if missing > 0 then
        lines[#lines + 1] = ("Still to buy (you and your alts don't have it): |cffffffff%s|r"):format(Gold(toBuy))
    elseif #rows > 0 then
        lines[#lines + 1] = "|cff59d959Nothing to buy: you and your alts have it all.|r"
    end
    -- what it makes
    local worth = r.out and JQ.CostToBuy and JQ.CostToBuy(r.out, r.per * n)
    if worth and all > 0 and unpriced == 0 then
        local diff = worth - all
        lines[#lines + 1] = ("Sells for about |cffffffff%s|r: |cff%s%s %s|r"):format(Gold(worth),
            diff >= 0 and "59d959" or "ff7070", diff >= 0 and "profit" or "loss", Gold(math.abs(diff)))
    end
    return lines
end

-- A material row's tooltip: the item, then buying against making it.
local function RowEnter(self)
    if not self.itemID then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(self.itemID)
    local qty = self.need or 0
    if qty > 0 and JQ.Requests then
        local _, how, buy, make = BestCost(self.itemID, qty, 0, {})
        if how == "vendor" then
            GameTooltip:AddLine("Sold by vendors: no auction price counted.", 0.62, 0.62, 0.66, true)
        else
            if buy then GameTooltip:AddDoubleLine(("Buy %d"):format(qty), Gold(buy), 0.9, 0.9, 0.9, 1, 1, 1) end
            if make then
                GameTooltip:AddDoubleLine(("Make %d yourself"):format(qty), Gold(make), 0.9, 0.9, 0.9, 1, 1, 1)
                local rec = JQ.Requests.MakeRecipe(self.itemID, JQ.Alts.MyName())
                local crafts = rec and math.ceil(qty / math.max(1, rec.n or 1)) or 0
                for rid, q in pairs(rec and rec.r or {}) do
                    local c = BestCost(rid, q * crafts, 1, { [self.itemID] = true })
                    GameTooltip:AddDoubleLine("   " .. (q * crafts) .. " " .. (UI.ItemNameQuality(rid)),
                        c and Gold(c) or "no price", 0.62, 0.62, 0.66, 0.62, 0.62, 0.66)
                end
            end
            if buy and make then
                GameTooltip:AddLine(make < buy and "Cheaper to make." or "Cheaper to buy.", 0.35, 0.85, 0.35)
            elseif not buy and not make then
                GameTooltip:AddLine("No auction price yet.", 0.62, 0.62, 0.66)
            end
        end
    end
    GameTooltip:Show()
end

local KIND_TEXT = {
    ok = "", alts = "|cffffd25afrom alts|r", vendor = "|cff9e9ea8vendor|r", missing = "|cffff7070buy|r",
}

local function RefreshDetail()
    local d = win.detail
    local r = selected and byID[selected]
    if not r then
        d.icon:Hide()
        d.name:SetText("Pick a recipe")
        d.sub:SetText("")
        d.summary:SetText("")
        for _, row in ipairs(d.rows) do row:Hide() end
        d.make:SetEnabledLook(false); d.makeAll:SetEnabledLook(false); d.plan:SetEnabledLook(false)
        return
    end
    local R = JQ.Requests
    local n = Crafts()
    local can = CanMake(r)
    d.icon.itemID = r.out
    d.icon.tex:SetTexture(r.icon or (r.out and UI.ItemIcon(r.out)) or 134400)
    d.icon:Show()
    local c = DIFF[r.diff or -1]
    d.name:SetText(r.name)
    if c then d.name:SetTextColor(c[1], c[2], c[3]) else d.name:SetTextColor(1, 1, 1) end
    d.sub:SetText(("Makes %d each  •  you can make |cff%s%d|r now"):format(r.per, can > 0 and "59d959" or "ff7070", can))

    local rows, request, tot = {}, {}, { request = 0, vendor = 0, still = 0 }
    if R and #r.reagents > 0 then rows, request, tot = R.Breakdown(ReagentList(r), n) end
    local bags = R and R.Holdings(JQ.Alts.MyName()) or {}
    for i, row in ipairs(d.rows) do
        local e = rows[i]
        if e then
            local name, q = UI.ItemNameQuality(e.id)
            row.itemID = e.id
            row.icon:ClearAllPoints()
            row.icon:SetPoint("LEFT", e.depth * 16, 0)
            row.icon:SetTexture(UI.ItemIcon(e.id))
            row.name:SetText(name)
            row.name:SetTextColor(UI.QualityColor(q))
            local inBags = bags[e.id] or 0
            local tag = KIND_TEXT[e.kind] or ""
            if e.kind == "make" then
                tag = ("|cffffd25amake %d|r"):format(e.makeQty or 0)
            elseif e.kind == "ok" and inBags < e.need then
                tag = "|cffffd25ayour bank / mail|r"
            end
            row.tag:SetText(tag)
            row.need = e.need
            local cost, how = BestCost(e.id, e.need, 0, {})
            row.cost:SetText((how == "vendor" and "|cff9e9ea8vendor|r")
                or (cost and ((how == "make" and "|cffffd25amake|r " or "") .. Gold(cost)))
                or "|cff9e9ea8no price|r")
            row.nums:SetText(("%d   |cff%s%d|r   %d"):format(e.need, e.have >= e.need and "59d959" or "ff7070", e.have, e.alts))
            row:Show()
        else
            row:Hide()
        end
    end
    local parts = {}
    local toFetch = 0
    for _, e in ipairs(rows) do
        if e.kind == "ok" and (bags[e.id] or 0) < e.need then toFetch = toFetch + 1 end
    end
    if toFetch > 0 then parts[#parts + 1] = ("%d material(s) are in your own bank or mail."):format(toFetch) end
    if tot.request - tot.still > 0 then parts[#parts + 1] = ("%d to ask your alts for."):format(tot.request - tot.still) end
    if tot.still > 0 then parts[#parts + 1] = ("|cffff7070%d on no alt: to buy.|r"):format(tot.still) end
    if tot.vendor > 0 then parts[#parts + 1] = ("|cff9e9ea8%d from a vendor.|r"):format(tot.vendor) end
    if #parts == 0 and #rows > 0 then parts[1] = can >= n and "|cff59d959Everything is in your bags.|r" or "" end
    if #rows > #d.rows then parts[#parts + 1] = ("(%d more rows: make the window taller)"):format(#rows - #d.rows) end
    local text = table.concat(parts, "  ")
    if R and #r.reagents > 0 then
        local gold = table.concat(CostLines(r, n, rows), "\n")
        text = gold .. (text ~= "" and ("\n" .. text) or "")
    end
    d.summary:SetText(text)

    d.make.text:SetText(("Make %d"):format(math.min(n, math.max(can, 1))))
    d.make:SetEnabledLook(can > 0)
    d.makeAll.text:SetText(can > 0 and ("Make all (%d)"):format(can) or "Make all")
    d.makeAll:SetEnabledLook(can > 0)
    d.plan:SetEnabledLook(#r.reagents > 0 and R ~= nil)
end

local function Select(id)
    selected = id
    if win and win:IsShown() then
        win.list:Render()
        RefreshDetail()
    end
end

local function Make(all)
    local r = selected and byID[selected]
    local t = T()
    if not (r and t and t.CraftRecipe) or InCombatLockdown() then return end
    local can = CanMake(r)
    if can < 1 then JQ.Print(("You can't make %s yet: the materials aren't in your bags."):format(r.name)) return end
    t.CraftRecipe(r.id, all and can or math.min(Crafts(), can))
end

local function Plan()
    local r = selected and byID[selected]
    if not (r and JQ.Requests and JQ.Requests.PlanFor) then return end
    local n = Crafts()
    JQ.Requests.PlanFor((n > 1 and (n .. "x ") or "") .. r.name, ReagentList(r), n, r.name)
    RefreshDetail()
end

-------------------------------------------------------------------------------
--  Header: which profession, how far, and the others you have
-------------------------------------------------------------------------------
local function RefreshHeader()
    local t = T()
    local info
    if t and t.GetBaseProfessionInfo then
        local ok, v = pcall(t.GetBaseProfessionInfo)
        info = ok and v or nil
    end
    local name = info and info.professionName
    local r, g, b = UI.Accent()
    local title = name and name ~= "" and name or "Professions"
    if info and info.skillLevel and info.maxSkillLevel and info.maxSkillLevel > 0 then
        title = title .. ("  |cff9e9ea8%d / %d|r"):format(info.skillLevel, info.maxSkillLevel)
    end
    win.title:SetText(("|cff%02x%02x%02x%s|r"):format(r * 255, g * 255, b * 255, title))

    -- your other professions
    local me = JQ.Alts and JQ.Alts.MyName()
    local data = me and JQ.Alts.RealmTable()[me]
    local names = {}
    for prof in pairs(data and data.profs or {}) do
        if LINES[prof] then names[#names + 1] = prof end
    end
    table.sort(names)
    local prev
    for i = 1, math.max(#names, #win.profs) do
        local bt = win.profs[i]
        local prof = names[i]
        if prof then
            if not bt then
                bt = UI.Button(win, "", 100, 20)
                bt:SetScript("OnClick", function(self)
                    local tt = T()
                    if tt and tt.OpenTradeSkill and not InCombatLockdown() then pcall(tt.OpenTradeSkill, self.line) end
                end)
                win.profs[i] = bt
            end
            bt.line = LINES[prof]
            bt.text:SetText(prof == "Mining" and "Smelting" or prof)
            bt:SetWidth(math.max(70, bt.text:GetStringWidth() + 22))
            bt:ClearAllPoints()
            if prev then bt:SetPoint("LEFT", prev, "RIGHT", 4, 0) else bt:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -30) end
            bt:SetOn(info and info.professionID == bt.line)
            bt:Show()
            prev = bt
        elseif bt then
            bt:Hide()
        end
    end
end

-------------------------------------------------------------------------------
--  Mastercraft's mini guide, docked
-------------------------------------------------------------------------------
local function MiniGuide() return _G.MastercraftMiniGuide end

local function ToggleGuide()
    local button = _G.MastercraftProfessionButton
    if not button then
        JQ.Print("Mastercraft's mini guide isn't ready yet: it appears a moment after a profession opens.")
        return
    end
    local mg = MiniGuide()
    db.guide = not (mg and mg:IsShown())
    button:Click("RightButton")   -- Mastercraft's own "mini guide" click
end

-- Keep the mini guide in its place in this window while both are open.
local function DockGuide()
    local mg = MiniGuide()
    local host = win and win.guideHost
    if not (mg and host and mg:IsShown() and win:IsShown()) then return end
    local _, rel = mg:GetPoint(1)
    if rel ~= host then
        mg:ClearAllPoints()
        mg:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    end
    mg.jqDocked = true
end

-------------------------------------------------------------------------------
--  Window
-------------------------------------------------------------------------------
local LEFT_W, RIGHT_W = 350, 320

local function Refresh()
    pending = false
    if not (win and win:IsShown()) then return end
    ReadRecipes()
    costCache = {}
    if not (selected and byID[selected]) then selected = recipes[1] and recipes[1].id or nil end
    RefreshHeader()
    win.list:SetItems(ListItems(), true)
    RefreshDetail()
    local hasMC = _G.MastercraftProfessionButton ~= nil or MiniGuide() ~= nil
    win.guideBtn:SetShown(hasMC)
    win.guideLabel:SetShown(hasMC)
end

local function Queue()
    if pending then return end
    pending = true
    C_Timer.After(0.15, function() JQ.Try("professions window", Refresh) end)
end

local function Chip(parent, label, key)
    local b = UI.Button(parent, label, 90, 20)
    b:SetScript("OnClick", function(self)
        db[key] = not db[key] or nil
        self:SetOn(db[key])
        win.list:SetItems(ListItems())
    end)
    b:SetOn(db[key])
    return b
end

local function Build()
    db.win = db.win or {}
    win = UI.Window("JaseQoLProfessions", "Professions", 1080, 680, db.win)
    win.profs = {}

    local classicBtn = UI.Button(win, "Classic view", 96, 20)
    classicBtn:SetPoint("TOPRIGHT", -34, -6)
    win.search = UI.SearchBox(win, "Search recipes", function() win.list:SetItems(ListItems()) end)
    win.search:SetWidth(220)
    win.search:SetPoint("RIGHT", classicBtn, "LEFT", -8, 0)

    -- left: recipes
    local left = UI.Panel(win)
    left:SetPoint("TOPLEFT", 10, -58)
    left:SetPoint("BOTTOMLEFT", 10, 10)
    left:SetWidth(LEFT_W)
    win.chipCan = Chip(left, "Can make", "canMake")
    win.chipCan:SetPoint("TOPLEFT", 6, -6)
    win.chipUps = Chip(left, "Skill ups", "skillUps")
    win.chipUps:SetPoint("LEFT", win.chipCan, "RIGHT", 4, 0)
    win.list = UI.List(left, 24, function(L)
        local row = CreateFrame("Button", nil, L)
        row.sel = UI.Fill(row, 1, 1, 1, 0.10)
        UI.Fill(row, 1, 1, 1, 0.06, "HIGHLIGHT")
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("LEFT", 6, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.can = UI.Text(row, 11, 0.62, 0.62, 0.66, "RIGHT")
        row.can:SetPoint("RIGHT", -6, 0)
        row.can:SetWidth(34)
        row.cost = UI.Text(row, 10, 0.8, 0.8, 0.82, "RIGHT")
        row.cost:SetPoint("RIGHT", row.can, "LEFT", -4, 0)
        row.cost:SetWidth(84)
        row.name = UI.Text(row, 12)
        row.name:SetPoint("LEFT", 30, 0)
        row.name:SetPoint("RIGHT", row.cost, "LEFT", -4, 0)
        row:SetScript("OnClick", function(self) if self.rid then Select(self.rid) end end)
        row:SetScript("OnEnter", function(self)
            local r = self.rid and byID[self.rid]
            if not (r and r.out) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(r.out)
            -- gold: what one craft costs in materials, and what it sells for
            local cost, unpriced = RecipeCost(r)
            if cost then
                GameTooltip:AddDoubleLine("Materials for one craft", Gold(cost), 0.9, 0.9, 0.9, 1, 1, 1)
                local worth = JQ.CostToBuy and JQ.CostToBuy(r.out, r.per)
                if worth then
                    GameTooltip:AddDoubleLine(r.per > 1 and ("Sells for (%d made)"):format(r.per) or "Sells for", Gold(worth), 0.9, 0.9, 0.9, 1, 1, 1)
                    local diff = worth - cost
                    GameTooltip:AddDoubleLine(diff >= 0 and "Profit" or "Loss", Gold(math.abs(diff)),
                        0.9, 0.9, 0.9, diff >= 0 and 0.35 or 1, diff >= 0 and 0.85 or 0.44, diff >= 0 and 0.35 or 0.44)
                end
            end
            if (unpriced or 0) > 0 then
                GameTooltip:AddLine(("%d material(s) have no auction price yet."):format(unpriced), 0.62, 0.62, 0.66, true)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", UI.HideTip)
        return row
    end, function(row, data)
        if data.head then
            row.rid = nil
            row.icon:Hide()
            row.sel:Hide()
            row.can:SetText("")
            row.cost:SetText("")
            row.name:ClearAllPoints()
            row.name:SetPoint("LEFT", 6, 0)
            row.name:SetPoint("RIGHT", -6, 0)
            row.name:SetText(("|cff%s%s|r"):format(UI.AccentHex(), data.head:upper()))
            row:EnableMouse(false)
        else
            local r = data.r
            row.rid = r.id
            row:EnableMouse(true)
            row.icon:SetTexture(r.icon or (r.out and UI.ItemIcon(r.out)) or 134400)
            row.icon:Show()
            row.sel:SetShown(r.id == selected)
            row.name:ClearAllPoints()
            row.name:SetPoint("LEFT", 30, 0)
            row.name:SetPoint("RIGHT", row.cost, "LEFT", -4, 0)
            row.name:SetText(r.name)
            local cost, unpriced = RecipeCost(r)
            row.cost:SetText(cost and (Gold(cost) .. ((unpriced or 0) > 0 and "|cff9e9ea8+|r" or "")) or "")
            local c = DIFF[r.diff or -1]
            if c then row.name:SetTextColor(c[1], c[2], c[3]) else row.name:SetTextColor(0.9, 0.9, 0.92) end
            local can = CanMake(r)
            row.can:SetText(can > 0 and ("|cff59d959" .. can .. "|r") or "")
        end
    end)
    win.list:SetPoint("TOPLEFT", 4, -32)
    win.list:SetPoint("BOTTOMRIGHT", -4, 4)

    -- right: the plan, and Mastercraft's mini guide under it
    local right = CreateFrame("Frame", nil, win)
    right:SetPoint("TOPRIGHT", -10, -58)
    right:SetPoint("BOTTOMRIGHT", -10, 10)
    right:SetWidth(RIGHT_W)
    win.planLabel = UI.Text(right, 12)
    win.planLabel:SetPoint("TOPLEFT", 2, 0)
    win.planLabel:SetText(("|cff%sYOUR PLAN|r"):format(UI.AccentHex()))
    win.planHost = CreateFrame("Frame", nil, right)
    win.planHost:SetPoint("TOPLEFT", 0, -18)
    win.planHost:SetSize(RIGHT_W, 10)
    win.planEmpty = UI.Text(right, 11, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3])
    win.planEmpty:SetPoint("TOPLEFT", 2, -22)
    win.planEmpty:SetPoint("RIGHT", -2, 0)
    win.planEmpty:SetWordWrap(true)
    win.planEmpty:SetText("Nothing planned. Pick a recipe and press Plan mats: what's in your bank, what your alts send, what to make and what to buy all show here.")
    win.guideHost = CreateFrame("Frame", nil, right)
    win.guideHost:SetSize(RIGHT_W, 262)
    win.guideHost:SetPoint("BOTTOMLEFT", 0, 0)
    win.guideLabel = UI.Text(right, 12)
    win.guideLabel:SetPoint("BOTTOMLEFT", win.guideHost, "TOPLEFT", 2, 6)
    win.guideLabel:SetText(("|cff%sMASTERCRAFT GUIDE|r"):format(UI.AccentHex()))
    win.guideBtn = UI.Button(right, "Show / hide", 96, 18)
    win.guideBtn:SetPoint("BOTTOMRIGHT", win.guideHost, "TOPRIGHT", 0, 4)
    win.guideBtn:SetScript("OnClick", function() JQ.Try("professions window: mini guide", ToggleGuide) end)

    -- middle: the picked recipe
    local mid = UI.Panel(win)
    mid:SetPoint("TOPLEFT", left, "TOPRIGHT", 6, 0)
    mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", -6, 0)
    local d = { rows = {} }
    win.detail = d
    d.icon = CreateFrame("Button", nil, mid)
    d.icon:SetSize(40, 40)
    d.icon:SetPoint("TOPLEFT", 12, -12)
    d.icon.tex = d.icon:CreateTexture(nil, "ARTWORK")
    d.icon.tex:SetAllPoints()
    d.icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    d.icon:SetScript("OnEnter", UI.ItemEnter)
    d.icon:SetScript("OnLeave", UI.HideTip)
    d.icon:SetScript("OnClick", UI.ItemClick)
    d.name = UI.Text(mid, 16)
    d.name:SetPoint("TOPLEFT", d.icon, "TOPRIGHT", 10, -2)
    d.name:SetPoint("RIGHT", -12, 0)
    d.sub = UI.Text(mid, 11, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3])
    d.sub:SetPoint("TOPLEFT", d.name, "BOTTOMLEFT", 0, -6)
    d.sub:SetPoint("RIGHT", -12, 0)

    local countLabel = UI.Text(mid, 11, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3])
    countLabel:SetPoint("TOPLEFT", 12, -70)
    countLabel:SetText("Crafts")
    win.count = CreateFrame("EditBox", nil, mid)
    win.count:SetSize(50, 22)
    win.count:SetPoint("LEFT", countLabel, "RIGHT", 8, 0)
    win.count:SetAutoFocus(false)
    win.count:SetNumeric(true)
    win.count:SetMaxLetters(4)
    win.count:SetJustifyH("CENTER")
    UI.SetFont(win.count, 12)
    UI.Fill(win.count, 0, 0, 0, 0.5)
    UI.Border(win.count)
    win.count:SetText("1")
    win.count:SetScript("OnTextChanged", function() if win.detail.make then RefreshDetail() end end)
    win.count:SetScript("OnEnterPressed", win.count.ClearFocus)
    win.count:SetScript("OnEscapePressed", win.count.ClearFocus)
    d.make = UI.Button(mid, "Make", 86, 22)
    d.make:SetPoint("LEFT", win.count, "RIGHT", 10, 0)
    d.make:SetScript("OnClick", function() JQ.Try("professions window: make", Make, false) end)
    d.makeAll = UI.Button(mid, "Make all", 100, 22)
    d.makeAll:SetPoint("LEFT", d.make, "RIGHT", 6, 0)
    d.makeAll:SetScript("OnClick", function() JQ.Try("professions window: make", Make, true) end)
    d.plan = UI.Button(mid, "Plan mats", 96, 22)
    d.plan:SetPoint("LEFT", d.makeAll, "RIGHT", 6, 0)
    d.plan:SetScript("OnClick", function() JQ.Try("professions window: plan", Plan) end)
    d.plan:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Plan the materials", 1, 1, 1)
        GameTooltip:AddLine("Plans a bank run for what's in your own bank or mail, asks your alts for the rest, adds a make step for what you can craft, and puts what nobody has on the buy list. The plan shows on the right.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    d.plan:SetScript("OnLeave", UI.HideTip)

    local head = UI.Text(mid, 10, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3], "RIGHT")
    head:SetPoint("TOPRIGHT", -12, -104)
    head:SetText("cost (all)          need   have   alts")
    for i = 1, 14 do
        local row = CreateFrame("Button", nil, mid)
        row:SetHeight(24)
        row:SetPoint("TOPLEFT", 12, -120 - (i - 1) * 26)
        row:SetPoint("RIGHT", -12, 0)
        UI.Fill(row, 1, 1, 1, 0.05, "HIGHLIGHT")
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(20, 20)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.nums = UI.Text(row, 11, 1, 1, 1, "RIGHT")
        row.nums:SetPoint("RIGHT")
        row.nums:SetWidth(104)
        row.cost = UI.Text(row, 11, 1, 1, 1, "RIGHT")
        row.cost:SetPoint("RIGHT", row.nums, "LEFT", -8, 0)
        row.cost:SetWidth(96)
        row.tag = UI.Text(row, 10, 1, 1, 1, "RIGHT")
        row.tag:SetPoint("RIGHT", row.cost, "LEFT", -6, 0)
        row.tag:SetWidth(84)
        row.name = UI.Text(row, 12)
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.name:SetPoint("RIGHT", row.tag, "LEFT", -4, 0)
        row:SetScript("OnEnter", function(self) JQ.Try("professions window: material tooltip", RowEnter, self) end)
        row:SetScript("OnLeave", UI.HideTip)
        row:SetScript("OnClick", UI.ItemClick)
        d.rows[i] = row
    end
    d.summary = UI.Text(mid, 11, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3])
    d.summary:SetPoint("BOTTOMLEFT", 12, 10)
    d.summary:SetPoint("RIGHT", -12, 0)
    d.summary:SetWordWrap(true)
    d.summary:SetJustifyV("BOTTOM")
    if d.summary.SetMaxLines then d.summary:SetMaxLines(6) end

    classicBtn:SetScript("OnClick", function()
        classic = true
        Tuck(false)
        win:Hide()
    end)

    win:SetScript("OnShow", function()
        if JQ.Requests and JQ.Requests.Dock then JQ.Requests.Dock(win.planHost) end
        Queue()
    end)
    win:SetScript("OnHide", function()
        if JQ.Requests and JQ.Requests.Undock then JQ.Requests.Undock() end
        local mg = MiniGuide()
        if mg and mg.jqDocked then
            mg.jqDocked = nil
            if not classic then mg:Hide() end
        end
        if classic then return end   -- the game's window takes over, the profession stays open
        Tuck(false)
        -- closing this window closes the profession, as closing the game's would
        local t, f = T(), Blizzard()
        if f and f:IsShown() and not InCombatLockdown() then
            if HideUIPanel then pcall(HideUIPanel, f) elseif t and t.CloseTradeSkill then pcall(t.CloseTradeSkill) end
        end
    end)
    local since = 0
    win:HookScript("OnUpdate", function(_, elapsed)
        since = since + elapsed
        if since < 0.2 then return end
        since = 0
        JQ.Try("professions window: mini guide", DockGuide)
        if JQ.Requests and JQ.Requests.PlanShown then win.planEmpty:SetShown(not JQ.Requests.PlanShown()) end
    end)
end

-- Should a profession that opens now get this window?
local function Wanted()
    return JQ.IsEnabled(KEY) and JQ.IsEnabled("altRequest") and not classic
end

local function Open()
    local f = Blizzard()
    if not Wanted() or not (f and f:IsShown()) or not IsOwnProfession() then
        -- the game's window after all (someone else's profession, Classic view)
        if not (win and win:IsShown()) then Tuck(false) end
        return
    end
    if not win then Build() end
    Tuck(true)
    if JQ.Requests and JQ.Requests.HideSide then JQ.Requests.HideSide() end
    win:Show()
    Queue()
    -- the mini guide, when you had it showing last time
    if db.guide then
        C_Timer.After(0.6, function()
            local mg, button = MiniGuide(), _G.MastercraftProfessionButton
            if win:IsShown() and button and not (mg and mg:IsShown()) then button:Click("RightButton") end
        end)
    end
end

local function Close()
    classic = false
    if win and win:IsShown() then
        classic = true      -- (the profession is closing already: don't close it again)
        win:Hide()
        classic = false
    end
    Tuck(false)
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event)
    if event == "TRADE_SKILL_SHOW" then
        -- out of sight straight away (no flash of the game's window); a moment
        -- later the game can say whose profession it is, and this window opens
        local f = Blizzard()
        if Wanted() and f and f:IsShown() then Tuck(true) end
        C_Timer.After(0.1, function() JQ.Try("professions window: opening", Open) end)
    elseif event == "TRADE_SKILL_CLOSE" then
        JQ.Try("professions window: closing", Close)
    elseif win and win:IsShown() then
        Queue()
    end
end)

JQ.byKey[KEY].onLoad = function()
    JaseQoLDB.profView = JaseQoLDB.profView or {}
    db = JaseQoLDB.profView
    for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_UPDATE",
        "BAG_UPDATE_DELAYED", "NEW_RECIPE_LEARNED", "SKILL_LINES_CHANGED" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    SLASH_JASEQOLPROF1 = "/jprof"
    SlashCmdList.JASEQOLPROF = function()
        if win and win:IsShown() then
            win:Hide()
        else
            classic = false
            Open()
            if not (win and win:IsShown()) then JQ.Print("Open a profession first: its window becomes the JaseTools one.") end
        end
    end
end
JQ.byKey[KEY].onDisable = function()
    if win and win:IsShown() then
        classic = true
        win:Hide()
        classic = false
    end
    Tuck(false)
end

JQ.ProfView = { Active = function() return win ~= nil and win:IsShown() end, Wanted = Wanted }

-- for tests
JQ._ProfView = { RecipeCost = RecipeCost, BestCost = BestCost, CostLines = CostLines, ReadRecipes = function() ReadRecipes(); return recipes end, ListItems = ListItems, CanMake = CanMake,
    Open = Open, Close = Close, Select = Select, Make = Make, Plan = Plan, Refresh = Refresh,
    Tucked = function() return tucked end, Window = function() return win end }
