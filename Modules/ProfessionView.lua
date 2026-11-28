-------------------------------------------------------------------------------
--  JaseTools: Professions (one window)
--
--  Opening a profession shows this window instead of the game's:
--    left    : your recipes, grouped as the game groups them, with the
--              game's skill-up chevrons, the profit of one craft and how many
--              you can make; search, filters, and sorting by profit
--    middle  : the recipe you picked: what it needs for N crafts (you have /
--              your alts have, and what would be made or bought), what the
--              materials cost on the auction house - buying each one, or
--              making it yourself from its own materials where that is
--              cheaper - Make, Make all and Plan mats
--    right   : two tabs. Plan: the request plan with its Take from bank /
--              Send / Make buttons and auto ticks, docked here while the
--              window is open. Guide: the step Mastercraft's guide is on,
--              drawn here as an order of work - what has to be made first
--              (sub-crafts, each with its own Make), then the main craft -
--              or Mastercraft's own mini guide panel, docked.
--  "Classic view" opens the game's own window until you close it.
--  While your character moves (running, jumping, falling - not on a flight
--  path) the window fades to 20% so you can see where you're going, like the
--  world map; it's whole again when you stop, or while the mouse is over it.
--  WoW Forever's all-professions book (K, the micro-menu button) opens this
--  window straight away on the profession you used last; its "All
--  professions" button opens the book itself. Forever's book has no
--  ProfessionsBookFrame (the debug log showed it): it is caught where it is
--  opened, ToggleProfessionsBook.
--
--  The game's window is still open underneath: a profession's data and
--  crafting only work while it is, and hiding it would close the profession.
--  So it is moved off the screen and made see-through (never resized: that
--  breaks its layout), and put back whenever this window closes or Classic
--  view is asked for.
--
--  JaseQoLDB.profView = { win = {...}, canMake = bool, skillUps = bool,
--    sort = nil | "desc" | "asc" (by profit), tab = "plan" | "guide",
--    theirGuide = bool (the Guide tab shows Mastercraft's own panel), lastLine = skill line last open,
--    skip = { ["Character|Profession"] = { [step title] = true } } (guide steps you skipped here),
--    debug = bool, debugLog = { "time  text", ... } (/jprof debug: what opening professions does) }
-------------------------------------------------------------------------------
local _, JQ = ...
local KEY = "profView"

JQ.AddModule({
    key = KEY,
    label = "Professions: one window",
    description = "Opening a profession shows one JaseTools window instead of the game's: your recipes with search and filters, the picked recipe's materials (yours and your alts') with Make and Plan mats, and your request plan and Mastercraft's mini guide docked beside them. Classic view opens the game's own window. Off unless you switch it on: here, with /jq profView, or with the JaseTools view button on the game's profession window. Needs Request mats from alts.",
    default = false,
})

local UI = JQ.UI
local win, db
local classic = false      -- the game's own window was asked for, until it closes
local tucked               -- the game's window's own scale and alpha while it is out of sight
local recipes = {}         -- the open profession's learned recipes
local byID = {}
local byOut = {}           -- [item made] = recipe
local byName = {}
local selected             -- recipe id
local pending = false
local RefreshDetail, RefreshGuide   -- forward (below)
local PlanGuideStep, NextOrderEntry, SetTab   -- forward (the guide, below)

-- Skill lines, to switch profession from this window (the game's own tabs are out of sight).
local LINES = {
    Alchemy = 171, Blacksmithing = 164, Cooking = 185, Enchanting = 333, Engineering = 202,
    ["First Aid"] = 129, Inscription = 773, Jewelcrafting = 755, Leatherworking = 165,
    Mining = 186, Tailoring = 197,
}

-------------------------------------------------------------------------------
--  Debug log (/jprof debug): every step of opening a profession, kept in
--  JaseQoLDB.profView.debugLog (saved on /reload or logout) so it can be read.
-------------------------------------------------------------------------------
local function Dbg(fmt, ...)
    if not (db and db.debug) then return end
    local ok, text = pcall(string.format, fmt, ...)
    if not ok then text = tostring(fmt) end
    db.debugLog = db.debugLog or {}
    table.insert(db.debugLog, ("%.2f  %s"):format(GetTime and GetTime() or 0, text))
    while #db.debugLog > 400 do table.remove(db.debugLog, 1) end
end

-- Your professions as the game lists them (the spellbook's), name -> the skill line
-- the game opens it with. Those are what opening a profession needs.
local function GameLines()
    local out = {}
    if not (GetProfessions and GetProfessionInfo) then return out end
    local ok, a, b, c, d, e, f = pcall(GetProfessions)
    if not ok then return out end
    for _, idx in pairs({ a, b, c, d, e, f }) do
        if idx then
            local ok2, name, _, _, _, _, _, line = pcall(GetProfessionInfo, idx)
            if ok2 and name and line then out[name] = line end
        end
    end
    return out
end

-- The skill line to open a profession with: the game's own list first, then what
-- this window learned while it was open, then the usual IDs.
local function LineFor(prof)
    if not prof then return nil end
    local game = GameLines()
    if game[prof] then return game[prof] end
    if prof == "Smelting" and game.Mining then return game.Mining end
    local learned = db and db.lines
    if learned and learned[prof] then return learned[prof] end
    if prof == "Mining" and learned and learned.Smelting then return learned.Smelting end
    return LINES[prof] or (prof == "Smelting" and LINES.Mining) or nil
end

local LINES_BY_ID = {}
for _, id in pairs(LINES) do LINES_BY_ID[id] = true end

local DIFF = {   -- skill-up chance, as the game colours it
    [0] = { 1.00, 0.50, 0.25 }, [1] = { 1.00, 1.00, 0.00 }, [2] = { 0.25, 0.75, 0.25 }, [3] = { 0.50, 0.50, 0.50 },
}
-- The game's own skill-up chevrons (its recipe list's art), by skill-up chance; none when trivial.
local SKILL_ATLAS = { [0] = "Professions-Icon-Skill-High", [1] = "Professions-Icon-Skill-Medium", [2] = "Professions-Icon-Skill-Low" }
local SKILL_TEXT = { [0] = "^^^", [1] = "^^", [2] = "^" }      -- where that art isn't in the client
local SKILL_WORD = { [0] = "high", [1] = "medium", [2] = "low", [3] = "none" }
local atlasOK = {}
local function HasAtlas(name)
    if atlasOK[name] == nil then
        local ok, info = pcall(function() return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) end)
        atlasOK[name] = (ok and info) and true or false
    end
    return atlasOK[name]
end
local RecipeProfit   -- forward (the gold section below)
local ShowSwitch     -- forward (the button on the game's own window, below)
local OpenBook       -- forward (WoW Forever's all-professions book, below)
local ProfessionInfo -- forward (the open profession, below)

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
-- Off the screen, where nothing of it can be seen or clicked.
local function Park(f)
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", -4000, -4000)
end

local parkHooked = false
local function Tuck(on)
    local f = Blizzard()
    if not f then return end
    if on then
        if not tucked then
            -- where it was, to put it back exactly
            local points = {}
            for i = 1, (f.GetNumPoints and f:GetNumPoints() or 0) do points[i] = { f:GetPoint(i) } end
            tucked = { alpha = f:GetAlpha(), points = points }
        end
        if not parkHooked and hooksecurefunc and UpdateUIPanelPositions then
            parkHooked = true
            -- the game lays its windows out again now and then: keep it parked while tucked
            hooksecurefunc("UpdateUIPanelPositions", function()
                local pf = Blizzard()
                if tucked and pf and pf:IsShown() then Park(pf) end
            end)
        end
        f:SetAlpha(0)
        Park(f)
    elseif tucked then
        local t = tucked
        tucked = nil
        f:ClearAllPoints()
        for _, pt in ipairs(t.points or {}) do
            if pt[1] then f:SetPoint(pt[1], pt[2] or UIParent, pt[3] or pt[1], pt[4] or 0, pt[5] or 0) end
        end
        if #(t.points or {}) == 0 and UpdateUIPanelPositions then pcall(UpdateUIPanelPositions, f) end
        f:SetAlpha(t.alpha or 1)
    end
    -- (an earlier version shrank it instead: undo that if this session still has it)
    if f.GetScale and f:GetScale() < 0.05 then f:SetScale(1) end
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
    recipes, byID, byOut, byName = {}, {}, {}, {}
    local t = T()
    if not (t and t.GetAllRecipeIDs and t.GetRecipeInfo) then return end
    local cats = {}
    for _, rid in ipairs(t.GetAllRecipeIDs() or {}) do
        local ok, info = pcall(t.GetRecipeInfo, rid)
        if ok and info and info.learned and info.name then
            local r = { id = rid, name = info.name, icon = info.icon, diff = info.relativeDifficulty,
                ups = info.numSkillUps, reagents = {}, per = 1 }
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
            byName[r.name] = r
            if r.out and not byOut[r.out] then byOut[r.out] = r end
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

-- What a recipe needs besides its materials (an anvil, a forge, a tool) and
-- you don't have here: { "Anvil", ... }, or nil when nothing is missing. The
-- game says so per recipe; where a client can't, the game's own error from the
-- last Make on it is used instead (kept a little while).
local makeError = {}   -- [recipe id] = { text, at }
local lastMake         -- { id, at }
local function Missing(r)
    local t = T()
    if t and t.GetRecipeRequirements then
        local ok, list = pcall(t.GetRecipeRequirements, r.id)
        if ok and type(list) == "table" then
            local out
            for _, need in ipairs(list) do
                if type(need) == "table" and need.met == false and need.name then
                    out = out or {}
                    out[#out + 1] = need.name
                end
            end
            return out
        end
    end
    local e = makeError[r.id]
    if e and (GetTime() - e.at) < 30 then return { e.text } end
end

local function MissingText(miss)
    return miss and ("Needs " .. table.concat(miss, ", ") .. " nearby") or nil
end

local function ListItems()
    local needle = win and win.search:Needle() or ""
    local shown = {}
    for _, r in ipairs(recipes) do
        local can = CanMake(r)
        local show = needle == "" or r.name:lower():find(needle, 1, true) ~= nil
        if show and db.canMake and can < 1 then show = false end
        if show and db.skillUps and r.diff == 3 then show = false end
        if show then shown[#shown + 1] = { r = r, can = can } end
    end
    local items = {}
    if db.sort == "gpd" and not (JQ.Market and JQ.Market.On()) then db.sort = "desc" end
    if db.sort then
        -- by the profit of one craft, or by the sales advisor's gold a day
        -- (Sales ledger); what has no price goes last
        for _, e in ipairs(shown) do
            if db.sort == "gpd" then
                e.profit = e.r.out and JQ.Market.Score(e.r.out) or nil
            else
                e.profit = RecipeProfit(e.r)
            end
        end
        table.sort(shown, function(a, b)
            local pa, pb = a.profit, b.profit
            if (pa == nil) ~= (pb == nil) then return pa ~= nil end
            if pa == nil or pa == pb then return a.r.name < b.r.name end
            if db.sort == "asc" then return pa < pb end
            return pa > pb
        end)
        items = shown
    else
        local lastCat
        for _, e in ipairs(shown) do
            if e.r.cat ~= lastCat then
                lastCat = e.r.cat
                items[#items + 1] = { head = e.r.cat }
            end
            items[#items + 1] = e
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

-- The profit of one craft: what it makes sells for, less its materials. nil
-- when either side has no price.
function RecipeProfit(r)
    local cost, unpriced = RecipeCost(r)
    if not cost or (unpriced or 0) > 0 or not r.out then return nil end
    local worth = JQ.CostToBuy and JQ.CostToBuy(r.out, r.per)
    if not worth then return nil end
    return worth - cost
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
        -- can be made: plans may make it, or always buy it (right-click)
        local R = JQ.Requests
        if R.MakeRecipe(self.itemID, JQ.Alts.MyName()) and R.BuyOnly then
            if not JQ.IsEnabled("planSubMats") then
                GameTooltip:AddLine("Plans buy it: Plans make sub-materials is off.", 1, 0.82, 0.35, true)
            elseif R.BuyOnly(self.itemID) then
                GameTooltip:AddLine("Plans always buy it. Right-click: let plans make it again.", 1, 0.82, 0.35, true)
            else
                GameTooltip:AddLine("Right-click: plans always buy it, never make it.", 0.62, 0.62, 0.66, true)
            end
        end
    end
    GameTooltip:Show()
end

-- Right-click on a material: always buy it rather than make it in plans (or undo that).
local function RowRightClick(self)
    local R = JQ.Requests
    if not (self.itemID and R and R.ToggleBuyOnly and R.MakeRecipe(self.itemID, JQ.Alts.MyName())) then return end
    R.ToggleBuyOnly(self.itemID)
    RefreshDetail()
    if db.tab == "guide" then RefreshGuide() end
    if GameTooltip:IsOwned(self) then RowEnter(self) end
end

-- where a material comes from, as a small icon and a word
local ICON = {
    bags = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t",
    bank = "|TInterface\\Minimap\\Tracking\\Banker:12:12|t",
    alts = "|TInterface\\Minimap\\Tracking\\Mailbox:12:12|t",
    make = "|TInterface\\Icons\\Trade_BlackSmithing:12:12:0:0:64:64:5:59:5:59|t",
    buy = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12|t",
    vendor = "|TInterface\\GossipFrame\\VendorGossipIcon:12:12|t",
}
local KIND_TEXT = {
    ok = ICON.bags .. " |cff59d959in bags|r", alts = ICON.alts .. " |cffffd25afrom alts|r",
    vendor = ICON.vendor .. " |cff9e9ea8vendor|r", missing = ICON.buy .. " |cffff7070buy|r",
}

function RefreshDetail()
    local d = win.detail
    local r = selected and byID[selected]
    if not r then
        d.icon:Hide()
        d.name:SetText("Pick a recipe")
        d.sub:SetText("")
        d.summary:SetText("")
        d.req:SetText("")
        for _, g in ipairs(d.gold) do g:SetText("") end
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
    d.name:SetText(r.name)
    d.name:SetTextColor(1, 1, 1)
    local dc = DIFF[r.diff or -1]
    d.sub:SetText(("Makes %d each  •  you can make |cff%s%d|r now%s"):format(r.per, can > 0 and "59d959" or "ff7070", can,
        (dc and SKILL_WORD[r.diff]) and ("  •  skill-up chance |cff%02x%02x%02x%s|r"):format(dc[1] * 255, dc[2] * 255, dc[3] * 255, SKILL_WORD[r.diff]) or ""))
    local miss = Missing(r)
    win.missKey = table.concat(miss or {}, ",")   -- (the tick redraws when this changes)
    d.req:SetText(miss and ("|cffff5a4a%s: you can't make it here.|r"):format(MissingText(miss)) or "")

    local rows, request, tot = {}, {}, { request = 0, vendor = 0, still = 0 }
    if R and #r.reagents > 0 then rows, request, tot = R.Breakdown(ReagentList(r), n) end
    local bags = R and R.Holdings(JQ.Alts.MyName()) or {}
    for i, row in ipairs(d.rows) do
        local e = rows[i]
        if e then
            local name, q = UI.ItemNameQuality(e.id)
            row.itemID = e.id
            row.icon:ClearAllPoints()
            row.icon:SetPoint("TOPLEFT", e.depth * 18, -5)
            row.icon:SetTexture(UI.ItemIcon(e.id))
            row.name:SetText(name)
            row.name:SetTextColor(UI.QualityColor(q))
            local inBags = bags[e.id] or 0
            local tag = KIND_TEXT[e.kind] or ""
            if e.kind == "make" then
                tag = ICON.make .. (" |cffffd25amake %d|r"):format(e.makeQty or 0)
            elseif e.kind == "ok" and inBags < e.need then
                tag = ICON.bank .. " |cffffd25ayour bank / mail|r"
            end
            row.need = e.need
            local cost, how = BestCost(e.id, e.need, 0, {})
            local price = (how == "vendor" and "|cff9e9ea8vendor|r")
                or (cost and ((how == "make" and "|cffffd25acheaper made:|r " or "") .. Gold(cost)))
                or "|cff9e9ea8no price|r"
            -- second line: where it comes from, and what the lot costs
            row.info:SetText((tag ~= "" and (tag .. "   ") or "") .. price)
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
    if #parts == 0 and #rows > 0 then
        parts[1] = can >= n and (miss and "Every material is in your bags." or "|cff59d959Everything is in your bags.|r") or ""
    end
    if #rows > #d.rows then parts[#parts + 1] = ("(%d more rows: make the window taller)"):format(#rows - #d.rows) end
    d.summary:SetText(table.concat(parts, "  "))
    -- gold: one line each (a wrapped text misplaces the coin icons)
    local gold = (R and #r.reagents > 0) and CostLines(r, n, rows) or {}
    for i, g in ipairs(d.gold) do g:SetText(gold[i] or "") end

    d.make.text:SetText(("Make %d"):format(math.min(n, math.max(can, 1))))
    d.make:SetEnabledLook(can > 0 and not miss)
    d.makeAll.text:SetText(can > 0 and ("Make all (%d)"):format(can) or "Make all")
    d.makeAll:SetEnabledLook(can > 0 and not miss)
    d.missing = miss
    d.plan:SetEnabledLook(#r.reagents > 0 and R ~= nil)
    if d.subBtn then
        local on = JQ.IsEnabled("planSubMats")
        d.subBtn.text:SetText(on and "Sub-mats: make" or "Sub-mats: buy")
        d.subBtn:SetOn(not on)
    end
    -- in your plan: how many of it the plan still has to make
    local left = R and R.GoalLeft and r.out and R.GoalLeft(r.out)
    if left and left > 0 then
        d.sub:SetText(d.sub:GetText() .. ("  •  |cff%sin your plan: make %d|r"):format(UI.AccentHex(), left))
    end
end

-------------------------------------------------------------------------------
--  Crafting. The game's own Create button is used wherever it can be: the
--  recipe is picked in the game's (hidden) window as you pick it here, the
--  count is put in its box, and its Create button is pressed - exactly what a
--  click on it would do. Only if that's not possible is the craft asked for
--  directly. Either way, if no craft has started a moment later, chat says so.
-------------------------------------------------------------------------------
local craftWatch   -- { name, at } while waiting for the craft's cast to begin

-- The recipe the game's own window shows.
local function GameFormRecipe()
    local f = Blizzard()
    local form = f and f.CraftingPage and f.CraftingPage.SchematicForm
    if not (form and form.GetRecipeInfo) then return nil end
    local ok, info = pcall(form.GetRecipeInfo, form)
    return ok and info and info.recipeID or nil
end

-- Pick a recipe in the game's window too, so its Create button makes this one.
local function PickInGame(rid)
    local t = T()
    if rid and t and t.OpenRecipe and GameFormRecipe() ~= rid and not InCombatLockdown() then
        pcall(t.OpenRecipe, rid)
    end
end

-- Make n of a recipe (a click must have led here). Returns true when a craft was asked for.
local function CraftNow(rid, n, name, quiet)
    n = math.max(1, math.floor(n or 1))
    local f = Blizzard()
    local page = f and f.CraftingPage
    local asked = false
    if page and GameFormRecipe() == rid then
        local box = page.CreateMultipleInputBox
        if box and box.SetValue then pcall(box.SetValue, box, n) end
        local btn = (n > 1 and page.CreateAllButton and box == nil) and page.CreateAllButton or page.CreateButton
        if btn and btn.IsEnabled and btn:IsEnabled() and btn.Click then
            btn:Click()
            asked = true
        end
    end
    if not asked then
        local t = T()
        if t and t.CraftRecipe then
            t.CraftRecipe(rid, n)
            asked = true
        end
    end
    if asked and not quiet then
        local at = GetTime()
        craftWatch = { name = name or "it", at = at }
        C_Timer.After(1.5, function()
            if craftWatch and craftWatch.at == at then
                craftWatch = nil
                JQ.Print(("The game didn't start making %s. If Classic view's Create button works for it, this window has a bug: please say so."):format(name or "it"))
            end
        end)
    end
    return asked
end

-- crafts: put that count in the Crafts box. Without it, a recipe your plan
-- is for gets the crafts the plan still has to make.
local function Select(id, crafts)
    selected = id
    JQ.Try("professions window: pick in the game's window", PickInGame, id)
    if not crafts then
        local r = byID[id]
        local left = r and r.out and JQ.Requests and JQ.Requests.GoalLeft and JQ.Requests.GoalLeft(r.out)
        if left and left > 0 then crafts = math.ceil(left / math.max(1, r.per or 1)) end
    end
    if crafts and win then win.count:SetText(tostring(math.max(1, math.floor(crafts)))) end
    if win and win:IsShown() then
        win.list:Render()
        RefreshDetail()
    end
end

-- A row of the guide's order of work: pick its recipe in the middle with the
-- crafts the guide asks for, ready for Make or Plan mats.
local function PickFromGuide(e)
    if not e then return end
    local r = e.recipe
    if not r then
        JQ.Print(("%s is made in another profession: its Make button opens that one."):format((UI.ItemNameQuality(e.id))))
        return
    end
    local crafts = e.main and e.need or math.ceil(((e.make or 0) > 0 and e.make or e.need) / math.max(1, r.per or 1))
    Select(r.id, crafts)
end

local function Make(all)
    local r = selected and byID[selected]
    local t = T()
    if not (r and t and t.CraftRecipe) or InCombatLockdown() then return end
    local can = CanMake(r)
    if can < 1 then JQ.Print(("You can't make %s yet: the materials aren't in your bags."):format(r.name)) return end
    local miss = Missing(r)
    if miss then JQ.Print(("You can't make %s here: %s."):format(r.name, MissingText(miss):lower())) return end
    lastMake = { id = r.id, at = GetTime() }
    CraftNow(r.id, all and can or math.min(Crafts(), can), r.name)
end

-- who: plan it for that character (its alts send to it, it makes it); this one by default
local function Plan(who)
    local r = selected and byID[selected]
    local R = JQ.Requests
    if not (r and R and R.PlanFor) then return end
    local n = Crafts()
    local plan = R.PlanConfirm or R.PlanFor
    plan((n > 1 and (n .. "x ") or "") .. r.name, ReagentList(r), n, r.name,
        r.out and { id = r.out, n = n * math.max(1, r.per or 1) } or nil, who, function()
            if win and win:IsShown() then RefreshDetail() end
        end)
end

-- Right-click on Plan mats: the characters known to make it, to plan it for one of them.
local planMenu
local function PlanForMenu(anchor)
    local r = selected and byID[selected]
    local R = JQ.Requests
    if not (r and r.out and R and R.Makers) then return end
    local me = JQ.Alts.MyName()
    local who = R.Makers(r.out)
    local others = {}
    for _, name in ipairs(who) do if name ~= me then others[#others + 1] = name end end
    if #others == 0 then
        JQ.Print(("No other character is known to make %s yet: open the profession on that character once and JaseTools learns it."):format(r.name))
        return
    end
    if not planMenu then
        planMenu = UI.Panel(win)
        planMenu:SetFrameStrata("DIALOG")
        planMenu.buttons = {}
        planMenu.head = UI.Text(planMenu, 10, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3])
        planMenu.head:SetPoint("TOPLEFT", 8, -6)
        planMenu.head:SetText("Plan it for")
    end
    for _, b in ipairs(planMenu.buttons) do b:Hide() end
    for i, name in ipairs(others) do
        local b = planMenu.buttons[i]
        if not b then
            b = UI.Button(planMenu, "", 140, 20)
            b:SetPoint("TOPLEFT", 6, -20 - (i - 1) * 22)
            b:SetScript("OnClick", function(self)
                planMenu:Hide()
                JQ.Try("professions window: plan for", Plan, self.who)
            end)
            planMenu.buttons[i] = b
        end
        b.who = name
        b.text:SetText(JQ.Alts.Display(name))
        b:Show()
    end
    planMenu:SetSize(152, 26 + #others * 22)
    planMenu:ClearAllPoints()
    planMenu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    planMenu:Show()
    -- gone after a while, or when the mouse leaves it
    planMenu.at = GetTime()
    planMenu:SetScript("OnUpdate", function(self)
        if GetTime() - self.at > 1 and not self:IsMouseOver() and not anchor:IsMouseOver() then self:Hide() end
    end)
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
    if info and info.professionID and info.professionName and info.professionName ~= "" then
        -- what this client calls this profession's window, learned as it is open
        db.lines = db.lines or {}
        db.lines[info.professionName] = info.professionID
        db.lastLine = info.professionID
    end
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
                    self.line = LineFor(self.prof) or self.line
                    Dbg("header button %s: OpenTradeSkill(%s)", tostring(self.prof), tostring(self.line))
                    if tt and tt.OpenTradeSkill and not InCombatLockdown() then pcall(tt.OpenTradeSkill, self.line) end
                    -- say so when the game didn't switch
                    local want = self.prof
                    C_Timer.After(0.6, function()
                        local now = ProfessionInfo()
                        local name = now and now.professionName
                        Dbg("  0.6s later the game shows: %s", tostring(name))
                        if name and name ~= want and not (want == "Mining" and name == "Smelting") then
                            JQ.Print(("The game didn't open %s from here. Open it from your spellbook once; after that this button knows it."):format(want == "Mining" and "Smelting" or want))
                        end
                    end)
                end)
                win.profs[i] = bt
            end
            bt.line = LineFor(prof)
            bt.prof = prof
            bt.text:SetText(prof == "Mining" and "Smelting" or prof)
            bt:SetWidth(math.max(70, bt.text:GetStringWidth() + 22))
            bt:ClearAllPoints()
            if prev then bt:SetPoint("LEFT", prev, "RIGHT", 4, 0) else bt:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -30) end
            bt:SetOn(info and (info.professionID == bt.line or info.professionName == prof
                or (prof == "Mining" and info.professionName == "Smelting")))
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

-- Mastercraft is installed and loaded (its button and mini guide only exist a moment after a profession opens).
local function HasMastercraft()
    if _G.MastercraftProfessionButton or _G.MastercraftMiniGuide then return true end
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    if loaded then
        local ok, yes = pcall(loaded, "Mastercraft")
        return ok and yes and true or false
    end
    return false
end

-- Mastercraft's own click for its mini guide (right-click on its profession button).
local function ClickGuide()
    local button = _G.MastercraftProfessionButton
    if button then button:Click("RightButton") end
    return button ~= nil
end

local function HideGuide()
    local mg = MiniGuide()
    if mg and mg:IsShown() and mg.jqDocked then mg:Hide() end
    if mg then mg.jqDocked = nil end
end

-- Keep Mastercraft's own panel in its place in this window, when that's what the Guide tab shows.
local function DockGuide()
    local mg = MiniGuide()
    local host = win and win.guideHost
    if not (mg and host and mg:IsShown() and win:IsShown() and db.tab == "guide" and db.theirGuide) then return end
    local _, rel = mg:GetPoint(1)
    if rel ~= host then
        mg:ClearAllPoints()
        mg:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -26)
    end
    mg.jqDocked = true
end

-------------------------------------------------------------------------------
--  The guide step as an order of work. Mastercraft's mini guide keeps the
--  guide it shows on its frame (.guide: steps with min / max skill, title,
--  count and materials). The step you are on is worked out from your skill;
--  its recipe and what that needs come from the open profession. Anything it
--  needs that you can make yourself is a sub-craft: those come first, numbered,
--  each with what you have and how many to make, and the main craft is last.
-------------------------------------------------------------------------------
local guideTried = 0

function ProfessionInfo()
    local t = T()
    if t and t.GetBaseProfessionInfo then
        local ok, info = pcall(t.GetBaseProfessionInfo)
        if ok and type(info) == "table" then return info end
    end
end

-- Mastercraft's guide for the open profession, read off its mini guide (made to show once, then put away).
local function GuideData()
    local mg = MiniGuide()
    local g = mg and mg.guide
    if type(g) == "table" and type(g.steps) == "table" then return g end
end

local function EnsureGuide()
    local info = ProfessionInfo()
    local g = GuideData()
    local prof = info and info.professionName
    local fits = g and (not prof or not g.name or g.name == prof or (g.name == "Mining" and prof == "Smelting"))
    if fits then return g end
    -- ask Mastercraft for it (a moment apart: its button appears just after the profession opens)
    local now = GetTime and GetTime() or 0
    if now - guideTried < 1 then return nil end
    guideTried = now
    local mg = MiniGuide()
    if mg and mg:IsShown() then mg:Hide() end
    if ClickGuide() then
        mg = MiniGuide()
        if mg and mg:IsShown() and not db.theirGuide then mg:Hide() end
    end
    return GuideData()
end

-- The guide steps you skipped in this window, for this character and profession.
-- (Mastercraft keeps its own Skip ticks to itself: these are separate.)
local function Skipped(g, create)
    local me = JQ.Alts and JQ.Alts.MyName()
    if not (me and g) then return {} end
    local key = me .. "|" .. tostring(g.name or g.key or "?")
    db.skip = db.skip or {}
    if not db.skip[key] and create then db.skip[key] = {} end
    return db.skip[key] or {}
end

-- The first step your skill hasn't passed and you haven't skipped, the one after it, and how many crafts it is about.
local function GuideStep(g, skill, skipped)
    skipped = skipped or {}
    local step, nextStep
    for _, st in ipairs(g.steps) do
        if type(st) == "table" and not st.special and st.max and st.min and not skipped[tostring(st.title)] then
            if not step then
                if skill < st.max then step = st end
            else
                nextStep = st
                break
            end
        end
    end
    if not step then return nil end
    local from = math.max(skill, step.min)
    local count = step.count or 1
    local crafts = skill >= step.max and count
        or math.max(1, math.ceil(count * (step.max - from) / math.max(1, step.max - step.min)))
    return step, nextStep, crafts
end

-- { {id, need, have, make, recipe | other}, ..., {main = true, recipe, need} }: what to make, in order.
local function WorkOrder(main, crafts)
    local R = JQ.Requests
    local me = JQ.Alts.MyName()
    local bags, bank, mail = R.Holdings(me)
    local order, seen = {}, {}
    local function add(id, qty, depth)
        if seen[id] then
            seen[id].need = seen[id].need + qty
            seen[id].make = math.max(0, seen[id].need - seen[id].have)
            return
        end
        local sub = byOut[id]                    -- made in the open profession
        local per, list, other = nil, nil, false
        if sub then
            per, list = sub.per, sub.reagents
        else
            local rec, can = R.MakeRecipe(id, me)   -- or by another profession of yours (bars from ore)
            if rec and can and rec.r then
                per, list, other = rec.n or 1, {}, true
                for rid, q in pairs(rec.r) do list[#list + 1] = { id = rid, per = q } end
            end
        end
        if not per then return end
        if R.MakeAllowed and not R.MakeAllowed(id) then return end   -- to buy, not make (Plans make sub-materials)
        local have = (bags[id] or 0) + (bank[id] or 0) + (mail[id] or 0)
        local e = { id = id, need = qty, have = have, make = math.max(0, qty - have), recipe = sub, other = other, per = per }
        if e.make > 0 and depth < 3 then
            local n = math.ceil(e.make / math.max(1, per))
            for _, g in ipairs(list) do add(g.id, g.per * n, depth + 1) end   -- what it needs comes before it
        end
        seen[id] = e
        order[#order + 1] = e
    end
    for _, g in ipairs(main.reagents) do add(g.id, g.per * crafts, 1) end
    order[#order + 1] = { main = true, recipe = main, need = crafts }
    return order
end

local function MakeOrderEntry(e)
    local t = T()
    if InCombatLockdown() or not e then return end
    if e.main or e.recipe then
        local r = e.recipe
        local can = CanMake(r)
        if can < 1 then
            JQ.Print(("You can't make %s yet: the materials aren't in your bags."):format(r.name))
            return
        end
        local miss = Missing(r)
        if miss then
            JQ.Print(("You can't make %s here: %s."):format(r.name, MissingText(miss):lower()))
            return
        end
        lastMake = { id = r.id, at = GetTime() }
        local want = e.main and e.need or math.ceil(e.make / math.max(1, r.per))
        PickInGame(r.id)
        CraftNow(r.id, math.max(1, math.min(want, can)), r.name)
    elseif JQ.Requests.MakeNow then
        JQ.Requests.MakeNow(e.id, e.make)   -- another profession's: it opens that one
    end
end

local SKIP_UNDO = 15   -- seconds Undo skip takes back just the last one

-- Plan one guide step (its main craft as the plan's goal), after the confirm box.
function PlanGuideStep(main, crafts, label)
    local R = JQ.Requests
    if not (main and R and R.PlanFor) then return end
    local list = {}
    for _, g in ipairs(main.reagents) do list[#list + 1] = { id = g.id, per = g.per } end
    local plan = R.PlanConfirm or R.PlanFor
    plan(label, list, crafts, main.name, main.out and { id = main.out, n = crafts * math.max(1, main.per or 1) } or nil, nil,
        function() JQ.Try("professions window: tab", SetTab, "plan") end)
end

-- The next thing to make in an order of work: the first sub-craft still short, then the main craft.
function NextOrderEntry(order)
    for _, e in ipairs(order or {}) do
        if e.main then return e end
        if (e.make or 0) > 0 and (e.recipe or e.other) then return e end
    end
end

function RefreshGuide()
    local card = win and win.guideCard
    if not card or db.tab ~= "guide" then return end
    win.theirBtn.text:SetText(db.theirGuide and "Back to the work order" or "Mastercraft's own panel")
    if db.theirGuide then
        card:Hide()
        local mg = MiniGuide()
        if not (mg and mg:IsShown()) then ClickGuide() end
        return
    end
    card:Show()
    local mg = MiniGuide()
    if mg and mg:IsShown() and mg.jqDocked then mg:Hide() end
    for _, row in ipairs(card.rows) do row:Hide() end
    card.planBtn:Hide()
    card.skipBtn:Hide()
    card.unskipBtn:Hide()
    card.learnBtn:Hide()
    card.nextPlanBtn:Hide()
    card.makeNext:Hide()
    card.skillBg:Hide()
    card.skillBar:Hide()
    card.order = nil
    local g = EnsureGuide()
    local info = ProfessionInfo()
    local skill = info and info.skillLevel or 0
    card.waiting = not g   -- (the window's tick tries again)
    if not g then
        card.head:SetText("")
        card.title:SetText("Fetching Mastercraft's guide...")
        card.sub:SetText(_G.MastercraftProfessionButton and "Asking Mastercraft for this profession's guide."
            or "Waiting for Mastercraft: its button appears a moment after the profession opens. If this stays, Mastercraft has no guide for this profession.")
        card.hint:SetText("")
        card.next:SetText("")
        return
    end
    local skipped = Skipped(g)
    local nSkipped = 0
    for _ in pairs(skipped) do nSkipped = nSkipped + 1 end
    card.guide = g
    if nSkipped > 0 then
        local last = card.lastSkip
        card.unskipBtn.text:SetText((last and GetTime() - last.at <= SKIP_UNDO) and "Undo skip" or ("Undo skips (%d)"):format(nSkipped))
        card.unskipBtn:Show()
    end
    local step, nextStep, crafts = GuideStep(g, skill, skipped)
    if step then
        card.skipBtn.title = tostring(step.title)
        card.skipBtn:Show()
    end
    if not step then
        card.head:SetText("")
        card.title:SetText(nSkipped > 0 and "No step left" or "Guide complete")
        card.sub:SetText(nSkipped > 0 and ("You skipped the rest (%d). Undo skips to see them again."):format(nSkipped)
            or ("Every step is done: you're at %d."):format(skill))
        card.hint:SetText("")
        card.next:SetText("")
        return
    end
    card.head:SetText(("|cff%sNOW|r  |cff9e9ea8skill %d - %d|r  |cffffffff%d|r"):format(UI.AccentHex(), step.min, step.max, skill))
    -- how far into this step your skill is
    do
        local span = math.max(1, step.max - step.min)
        local frac = math.max(0, math.min(1, (skill - step.min) / span))
        local ar, ag, ab = UI.Accent()
        card.skillBar:SetColorTexture(ar, ag, ab, 0.9)
        card.skillBg:Show()
        local w = card.skillBg:GetWidth() or 0
        card.skillBar:SetWidth(math.max(0.01, w * frac))
        card.skillBar:SetShown(frac > 0 and w > 0)
    end
    local main = step.title and byName[step.title]
    if not main then
        card.title:SetText(tostring(step.title or "?"))
        card.sub:SetText(step.mats and ("|cffff9a3cYou haven't learned this recipe yet.|r About %d crafts once you have. Learn from: %s."):format(crafts,
            tostring(step.source or "a trainer"))
            or "A gathering step: nothing to craft here.")
        -- where: Mastercraft knows the trainers and has the way there (its guide page, with a waypoint)
        card.learnBtn:SetShown(step.mats ~= nil and _G.MastercraftProfessionButton ~= nil)
        card.hint:SetText(type(step.mats) == "string" and ("Needs each: " .. step.mats) or "")
        card.next:SetText(nextStep and ("|cff9e9ea8Next: %d+  %s|r"):format(nextStep.min or 0, tostring(nextStep.title or "")) or "")
        return
    end
    card.title:SetText(("%s  |cff9e9ea8x%d|r"):format(main.name, crafts))
    local order = WorkOrder(main, crafts)
    local subs = #order - 1
    card.sub:SetText(subs > 0
        and ("|cffffd25a%d sub-craft%s first|r, then the main craft. Work down the list:"):format(subs, subs == 1 and "" or "s")
        or "Nothing to make first: straight to the main craft.")
    card.hint:SetText("")
    card.order = order
    for i, row in ipairs(card.rows) do
        local e = order[i]
        if e then
            row.entry = e
            local r = e.recipe
            row.sel:SetShown(r ~= nil and r.id == selected)
            if e.main then
                local can = CanMake(r)
                row.itemID = r.out
                row.icon:SetTexture(r.icon or (r.out and UI.ItemIcon(r.out)) or 134400)
                row.name:SetText(("%d. |cffffffff%d %s|r"):format(i, e.need, r.name))
                local miss = Missing(r)
                row.info:SetText(miss and ("|cff%sMAIN CRAFT|r   |cffff5a4a%s|r"):format(UI.AccentHex(), MissingText(miss))
                    or ("|cff%sMAIN CRAFT|r   you can make |cff%s%d|r now"):format(UI.AccentHex(), can > 0 and "59d959" or "ff7070", can))
                row.btn.text:SetText(("Make %d"):format(math.max(1, math.min(e.need, math.max(can, 1)))))
                row.btn:SetEnabledLook(can > 0 and not miss)
                row.btn:Show()
                row.done:Hide()
            else
                row.itemID = e.id
                row.icon:SetTexture(UI.ItemIcon(e.id))
                row.name:SetText(("%d. |cffffffff%d %s|r"):format(i, e.need, (UI.ItemNameQuality(e.id))))
                if e.make <= 0 then
                    row.info:SetText(("|cffffd25aSUB-CRAFT|r   |cff59d959have %d: enough|r"):format(e.have))
                    row.btn:Hide()
                    row.done:Show()
                else
                    local can = r and CanMake(r) or nil
                    local miss = r and Missing(r) or nil
                    row.info:SetText(("|cffffd25aSUB-CRAFT|r   have %d   |cffffffffmake %d|r%s"):format(e.have, e.make,
                        e.other and "   |cff9e9ea8(another profession)|r"
                        or (miss and ("   |cffff5a4a" .. MissingText(miss) .. "|r"))
                        or (can and can < 1 and "   |cffff7070mats not in bags|r") or ""))
                    row.btn.text:SetText(("Make %d"):format(e.make))
                    row.btn:SetEnabledLook(e.other or (can ~= nil and can > 0 and not miss))
                    row.btn:Show()
                    row.done:Hide()
                end
            end
            row:Show()
        end
    end
    if #order > #card.rows then card.hint:SetText(("(%d more: make the window taller)"):format(#order - #card.rows)) end
    card.planBtn.label = (crafts > 1 and (crafts .. "x ") or "") .. main.name .. " (guide)"
    card.planBtn.main, card.planBtn.crafts = main, crafts
    card.planBtn:Show()
    card.makeNext:Show()
    -- the next step: into the same plan, when its recipe is known here
    local nextMain = nextStep and nextStep.title and byName[nextStep.title]
    if nextMain and #nextMain.reagents > 0 then
        local n = math.max(1, nextStep.count or 1)
        card.nextPlanBtn.main, card.nextPlanBtn.crafts = nextMain, n
        card.nextPlanBtn.label = (n > 1 and (n .. "x ") or "") .. nextMain.name .. " (guide)"
        card.nextPlanBtn:Show()
    end
    card.next:SetText(nextStep and ("|cff9e9ea8Next: %d+  %s|r"):format(nextStep.min or 0, tostring(nextStep.title or "")) or "")
end

-- The right column's tabs: Plan (the docked request plan) or Guide (the step as an order of work).
function SetTab(tab)
    local hasMC = HasMastercraft()
    if tab == "guide" and not hasMC then tab = "plan" end
    db.tab = tab
    win.tabPlan:SetOn(tab == "plan")
    win.tabGuide:SetOn(tab == "guide")
    win.tabGuide:SetShown(hasMC)
    win.planHost:SetShown(tab == "plan")
    win.guideHost:SetShown(tab == "guide")
    if tab == "guide" then
        win.planEmpty:Hide()
        RefreshGuide()
    else
        HideGuide()
    end
end

-------------------------------------------------------------------------------
--  Window
-------------------------------------------------------------------------------
local LEFT_W, RIGHT_W = 330, 320

local function Refresh()
    pending = false
    if not (win and win:IsShown()) then return end
    ReadRecipes()
    costCache = {}
    if not (selected and byID[selected]) then selected = recipes[1] and recipes[1].id or nil end
    RefreshHeader()
    win.list:SetItems(ListItems(), true)
    RefreshDetail()
    win.tabGuide:SetShown(HasMastercraft())
    JQ.Try("professions window: guide step", RefreshGuide)
end

local function Queue()
    if pending then return end
    pending = true
    C_Timer.After(0.15, function() JQ.Try("professions window", Refresh) end)
end

local SORT_LABEL = { desc = "Profit: high first", asc = "Profit: low first", gpd = "Gold a day: best" }

local function Chip(parent, label, key)
    local b = UI.Button(parent, label, 80, 20)
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
    win.bookBtn = UI.Button(win, "All professions", 110, 20)
    win.bookBtn:SetPoint("TOPRIGHT", -34, -30)
    win.bookBtn:SetScript("OnClick", function() JQ.Try("professions window: professions book", OpenBook) end)
    win.search = UI.SearchBox(win, "Search recipes", function() win.list:SetItems(ListItems()) end)
    win.search:SetWidth(220)
    win.search:SetPoint("RIGHT", classicBtn, "LEFT", -8, 0)

    -- left: recipes
    local left = UI.Panel(win)
    win.left = left
    left:SetPoint("TOPLEFT", 10, -58)
    left:SetPoint("BOTTOMLEFT", 10, 36)
    left:SetWidth(LEFT_W)
    win.chipCan = Chip(left, "Can make", "canMake")
    win.chipCan:SetPoint("TOPLEFT", 6, -6)
    win.chipUps = Chip(left, "Skill ups", "skillUps")
    win.chipUps:SetPoint("LEFT", win.chipCan, "RIGHT", 4, 0)
    -- sorting: the game's order with its headings, or one list by the profit of a craft
    win.sortBtn = UI.Button(left, SORT_LABEL[db.sort] or "Sort: game order", 130, 20)
    win.sortBtn:SetPoint("LEFT", win.chipUps, "RIGHT", 4, 0)
    win.sortBtn:SetOn(db.sort ~= nil)
    win.sortBtn:SetScript("OnClick", function(self)
        local advisor = JQ.Market and JQ.Market.On()
        db.sort = (db.sort == nil and "desc") or (db.sort == "desc" and "asc")
            or (db.sort == "asc" and advisor and "gpd") or nil
        self.text:SetText(SORT_LABEL[db.sort] or "Sort: game order")
        self:SetOn(db.sort ~= nil)
        win.list:SetItems(ListItems())
    end)
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
        row.cost = UI.Text(row, 10, 0.8, 0.8, 0.82, "RIGHT")   -- the profit of one craft
        row.cost:SetPoint("RIGHT", row.can, "LEFT", -4, 0)
        row.cost:SetWidth(84)
        row.skill = row:CreateTexture(nil, "ARTWORK")          -- the game's skill-up chevrons
        row.skill:SetSize(14, 14)
        row.skill:SetPoint("RIGHT", row.cost, "LEFT", -4, 0)
        row.skillText = UI.Text(row, 10, 1, 1, 1, "RIGHT")
        row.skillText:SetPoint("RIGHT", row.cost, "LEFT", -4, 0)
        row.skillText:SetWidth(26)
        row.name = UI.Text(row, 12)
        row.name:SetPoint("LEFT", 30, 0)
        row.name:SetPoint("RIGHT", row.cost, "LEFT", -34, 0)
        row:SetScript("OnClick", function(self) if self.rid then Select(self.rid) end end)
        row:SetScript("OnEnter", function(self)
            local r = self.rid and byID[self.rid]
            if not (r and r.out) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(r.out)
            local miss = Missing(r)
            if miss then GameTooltip:AddLine("Can't make it here: " .. MissingText(miss):lower() .. ".", 1, 0.35, 0.3, true) end
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
            row.skill:Hide()
            row.skillText:SetText("")
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
            row.name:SetPoint("RIGHT", row.cost, "LEFT", -34, 0)
            row.name:SetText(r.name)
            row.name:SetTextColor(0.9, 0.9, 0.92)
            -- profit of one craft: green when it pays, red when it costs
            local profit = RecipeProfit(r)
            if profit then
                row.cost:SetText((profit >= 0 and "|cff59d959+" or "|cffff7070-") .. Gold(math.abs(profit)) .. "|r")
            else
                row.cost:SetText("")
            end
            -- skill-up chance: the game's chevrons (and how many points, when more than one)
            local atlas = SKILL_ATLAS[r.diff or -1]
            local c = DIFF[r.diff or -1]
            local many = (type(r.ups) == "number" and r.ups > 1) and tostring(r.ups) or ""
            if atlas and HasAtlas(atlas) then
                row.skill:SetAtlas(atlas)
                row.skill:Show()
                row.skillText:ClearAllPoints()
                row.skillText:SetPoint("RIGHT", row.skill, "LEFT", -1, 0)
                row.skillText:SetText(many)
            else
                row.skill:Hide()
                row.skillText:ClearAllPoints()
                row.skillText:SetPoint("RIGHT", row.cost, "LEFT", -4, 0)
                row.skillText:SetText((SKILL_TEXT[r.diff or -1] or "") .. many)
            end
            if c then row.skillText:SetTextColor(c[1], c[2], c[3]) end
            local can = CanMake(r)
            -- the count is orange while something else it needs isn't here (an anvil, a forge)
            row.can:SetText(can > 0 and ((Missing(r) and "|cffff9a3c" or "|cff59d959") .. can .. "|r") or "")
        end
    end)
    win.list:SetPoint("TOPLEFT", 4, -32)
    win.list:SetPoint("BOTTOMRIGHT", -4, 4)

    -- right: Plan | Guide
    local right = CreateFrame("Frame", nil, win)
    win.right = right
    right:SetPoint("TOPRIGHT", -10, -58)
    right:SetPoint("BOTTOMRIGHT", -10, 36)
    -- the bottom strip: the crafting progress bar, across the whole window
    win.barHost = CreateFrame("Frame", nil, win)
    win.barHost:SetPoint("BOTTOMLEFT", 10, 10)
    win.barHost:SetPoint("BOTTOMRIGHT", -20, 10)
    win.barHost:SetHeight(20)
    right:SetWidth(RIGHT_W)
    win.tabPlan = UI.Button(right, "Plan", 90, 20)
    win.tabPlan:SetPoint("TOPLEFT", 0, 0)
    win.tabPlan:SetScript("OnClick", function() JQ.Try("professions window: tab", SetTab, "plan") end)
    win.tabGuide = UI.Button(right, "Mastercraft guide", 130, 20)
    win.tabGuide:SetPoint("LEFT", win.tabPlan, "RIGHT", 4, 0)
    win.tabGuide:SetScript("OnClick", function() JQ.Try("professions window: tab", SetTab, "guide") end)
    win.planHost = CreateFrame("Frame", nil, right)
    win.planHost:SetPoint("TOPLEFT", 0, -26)
    win.planHost:SetSize(RIGHT_W, 10)
    win.planEmpty = UI.Text(right, 11, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3])
    win.planEmpty:SetPoint("TOPLEFT", 2, -32)
    win.planEmpty:SetPoint("RIGHT", -2, 0)
    win.planEmpty:SetWordWrap(true)
    win.planEmpty:SetText("Nothing planned. Pick a recipe and press Plan mats: what's in your bank, what your alts send, what to make and what to buy all show here.")
    -- this character's plan can be dropped from here
    win.clearBtn = UI.Button(right, "Clear plan", 90, 20)
    win.clearBtn:SetPoint("TOPRIGHT", 0, 0)
    win.clearBtn:SetScript("OnClick", function()
        local R = JQ.Requests
        if R and R.CanUndoCancel and R.CanUndoCancel() then
            R.UndoCancel()
        elseif R and R.Cancel then
            R.Cancel()
        end
        RefreshDetail()
    end)
    win.clearBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Clear plan", 1, 1, 1)
        GameTooltip:AddLine("Drops this character's whole plan: what it asked alts for, its bank run and what it was going to make. Nothing already sent is taken back. For a few seconds after, the button brings it back.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    win.clearBtn:SetScript("OnLeave", UI.HideTip)
    win.clearBtn:Hide()
    win.guideHost = CreateFrame("Frame", nil, right)
    win.guideHost:SetPoint("TOPLEFT", 0, -26)
    win.guideHost:SetPoint("BOTTOMRIGHT", 0, 0)
    -- the Guide tab: this step as an order of work, or Mastercraft's own panel
    win.theirBtn = UI.Button(win.guideHost, "Mastercraft's own panel", 170, 18)
    win.theirBtn:SetPoint("TOPRIGHT", 0, 0)
    win.theirBtn:SetScript("OnClick", function()
        db.theirGuide = not db.theirGuide or nil
        if not db.theirGuide then HideGuide() end
        JQ.Try("professions window: guide step", RefreshGuide)
    end)
    local card = UI.Panel(win.guideHost)
    win.guideCard = card
    card:SetPoint("TOPLEFT", 0, -24)
    card:SetPoint("BOTTOMRIGHT", 0, 0)
    card.head = UI.Text(card, 11)
    card.head:SetPoint("TOPLEFT", 10, -10)
    card.title = UI.Text(card, 15)
    card.title:SetPoint("TOPLEFT", 10, -28)
    card.title:SetPoint("RIGHT", -10, 0)
    card.sub = UI.Text(card, 11, 0.86, 0.86, 0.88)
    card.sub:SetPoint("TOPLEFT", 10, -50)
    card.sub:SetPoint("RIGHT", -10, 0)
    card.sub:SetWordWrap(true)
    card.rows = {}
    for i = 1, 9 do
        local row = CreateFrame("Button", nil, card)
        row:SetHeight(38)
        row:SetPoint("TOPLEFT", 8, -86 - (i - 1) * 42)
        row:SetPoint("RIGHT", -8, 0)
        UI.Fill(row, 1, 1, 1, 0.04)
        UI.Fill(row, 1, 1, 1, 0.05, "HIGHLIGHT")
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(26, 26)
        row.icon:SetPoint("LEFT", 6, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.btn = UI.Button(row, "Make", 76, 22)
        row.btn:SetPoint("RIGHT", -6, 0)
        row.btn:SetScript("OnClick", function(self)
            JQ.Try("professions window: guide make", MakeOrderEntry, self:GetParent().entry)
        end)
        -- another profession's sub-craft: the press opens that profession, the release makes it
        row.btn:SetScript("OnMouseDown", function(self, button)
            local e = self:GetParent().entry
            if e and e.other and button == "LeftButton" and JQ.Requests and JQ.Requests.MakePrepare then
                JQ.Try("professions window: guide make", JQ.Requests.MakePrepare, e.id)
            end
        end)
        row.done = row:CreateTexture(nil, "OVERLAY")
        row.done:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        row.done:SetSize(18, 18)
        row.done:SetPoint("RIGHT", -32, 0)
        row.name = UI.Text(row, 12)
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 0)
        row.name:SetPoint("RIGHT", row.btn, "LEFT", -6, 0)
        row.info = UI.Text(row, 10, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3])
        row.info:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
        row.info:SetPoint("RIGHT", row.btn, "LEFT", -6, 0)
        row.sel = UI.Fill(row, 1, 1, 1, 0.10)
        row.sel:Hide()
        row:SetScript("OnEnter", function(self)
            UI.ItemEnter(self)
            local e = self.entry
            if not (e and GameTooltip:IsOwned(self)) then return end
            if e.recipe then
                local n = e.main and e.need or math.ceil(((e.make or 0) > 0 and e.make or e.need) / math.max(1, e.recipe.per or 1))
                GameTooltip:AddLine(("Click: pick it in the middle with %d craft%s, ready for Make or Plan mats."):format(n, n == 1 and "" or "s"), 0.05, 0.82, 0.62, true)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", UI.HideTip)
        row:SetScript("OnClick", function(self)
            if IsModifiedClick("CHATLINK") then UI.ItemClick(self) return end
            JQ.Try("professions window: guide pick", PickFromGuide, self.entry)
            JQ.Try("professions window: guide step", RefreshGuide)
        end)
        card.rows[i] = row
    end
    card.hint = UI.Text(card, 10, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3])
    card.hint:SetPoint("BOTTOMLEFT", 10, 52)
    card.hint:SetPoint("RIGHT", -10, 0)
    card.hint:SetWordWrap(true)
    card.planBtn = UI.Button(card, "Plan step", 90, 22)
    card.planBtn:SetPoint("BOTTOMLEFT", 10, 26)
    card.planBtn:SetScript("OnClick", function(self)
        JQ.Try("professions window: plan the guide step", PlanGuideStep, self.main, self.crafts, self.label)
    end)
    card.planBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Plan mats for this step", 1, 1, 1)
        GameTooltip:AddLine("Everything this step needs, sub-crafts included: bank run, alts, make and buy. The craft itself stays on the plan as its last step until it's made.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    card.planBtn:SetScript("OnLeave", UI.HideTip)
    -- the step after this one, into the same plan (one bank run for both)
    card.nextPlanBtn = UI.Button(card, "Plan it too", 90, 18)
    card.nextPlanBtn:SetPoint("BOTTOMRIGHT", -10, 6)
    card.nextPlanBtn:SetScript("OnClick", function(self)
        JQ.Try("professions window: plan the next guide step", PlanGuideStep, self.main, self.crafts, self.label)
    end)
    card.nextPlanBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Plan the next step too", 1, 1, 1)
        GameTooltip:AddLine("Adds the next step's materials to the plan, so one bank run and one round of alts covers both. Plans add up: what one counts on, the next doesn't count again.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    card.nextPlanBtn:SetScript("OnLeave", UI.HideTip)
    card.nextPlanBtn:Hide()
    -- the next thing to make in the order of work, one click at a time
    card.makeNext = UI.Button(card, "Make next", 90, 20)
    card.makeNext:SetPoint("TOPRIGHT", -10, -8)
    card.makeNext:SetScript("OnClick", function()
        JQ.Try("professions window: make next", MakeOrderEntry, NextOrderEntry(card.order))
    end)
    card.makeNext:SetScript("OnMouseDown", function(_, button)
        local e = NextOrderEntry(card.order)
        if e and e.other and button == "LeftButton" and JQ.Requests and JQ.Requests.MakePrepare then
            JQ.Try("professions window: make next", JQ.Requests.MakePrepare, e.id)
        end
    end)
    card.makeNext:SetScript("OnEnter", function(self)
        local e = NextOrderEntry(card.order)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Make the next one", 1, 1, 1)
        if e then
            local name = e.main and e.recipe.name or (UI.ItemNameQuality(e.id))
            GameTooltip:AddLine(("Next: %d %s%s."):format(e.main and e.need or e.make, name, e.main and " (the main craft)" or ""), 0.9, 0.9, 0.9, true)
        end
        GameTooltip:AddLine("Works down the list: each click makes the next sub-craft still short, then the main craft. Crafting needs a click each time.", 0.62, 0.62, 0.66, true)
        GameTooltip:Show()
    end)
    card.makeNext:SetScript("OnLeave", UI.HideTip)
    card.makeNext:Hide()
    -- where your skill is in this step
    card.skillBg = card:CreateTexture(nil, "ARTWORK")
    card.skillBg:SetColorTexture(1, 1, 1, 0.10)
    card.skillBg:SetHeight(5)
    card.skillBg:SetPoint("LEFT", card.head, "RIGHT", 8, 0)
    card.skillBg:SetPoint("RIGHT", card.makeNext, "LEFT", -10, 0)
    card.skillBar = card:CreateTexture(nil, "OVERLAY")
    card.skillBar:SetHeight(5)
    card.skillBar:SetPoint("LEFT", card.skillBg, "LEFT")
    card.skillBg:Hide()
    card.skillBar:Hide()
    -- skip the step shown (a recipe you won't make, mats you won't buy), and get skipped ones back
    card.learnBtn = UI.Button(card, "Where to learn it", 150, 22)
    card.learnBtn:SetPoint("TOPLEFT", card.sub, "BOTTOMLEFT", 0, -10)
    card.learnBtn:SetScript("OnClick", function()
        local b = _G.MastercraftProfessionButton
        if b then b:Click("LeftButton") end   -- Mastercraft's guide page: its Learn from card lists the trainers and makes a waypoint
    end)
    card.learnBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Where to learn it", 1, 1, 1)
        GameTooltip:AddLine("Opens Mastercraft's guide for this profession: its Learn from card names the trainers and can put a waypoint on the nearest.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    card.learnBtn:SetScript("OnLeave", UI.HideTip)
    card.learnBtn:Hide()
    card.skipBtn = UI.Button(card, "Skip step", 80, 22)
    card.skipBtn:SetPoint("LEFT", card.planBtn, "RIGHT", 6, 0)
    card.skipBtn:SetPoint("BOTTOM", card, "BOTTOM", 0, 26)
    card.skipBtn:SetScript("OnClick", function(self)
        if not (self.title and card.guide) then return end
        Skipped(card.guide, true)[self.title] = true
        -- a moment to take it back: Undo skip brings just this one back
        card.lastSkip = { title = self.title, at = GetTime() }
        C_Timer.After(SKIP_UNDO + 0.1, function()
            if win and win:IsShown() and db.tab == "guide" then JQ.Try("professions window: guide step", RefreshGuide) end
        end)
        JQ.Try("professions window: guide step", RefreshGuide)
    end)
    card.skipBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Skip this step", 1, 1, 1)
        GameTooltip:AddLine("Moves on to the next step of the guide, for this character. Skips made here are JaseTools' own: Mastercraft's window keeps its own Skip ticks.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    card.skipBtn:SetScript("OnLeave", UI.HideTip)
    card.unskipBtn = UI.Button(card, "Undo skips", 110, 22)
    card.unskipBtn:SetPoint("LEFT", card.skipBtn, "RIGHT", 6, 0)
    card.unskipBtn:SetScript("OnClick", function()
        if not card.guide then return end
        local last = card.lastSkip
        if last and GetTime() - last.at <= SKIP_UNDO then
            Skipped(card.guide)[last.title] = nil   -- just the one skipped a moment ago
        else
            local me = JQ.Alts and JQ.Alts.MyName()
            if me and db.skip then db.skip[me .. "|" .. tostring(card.guide.name or card.guide.key or "?")] = nil end
        end
        card.lastSkip = nil
        JQ.Try("professions window: guide step", RefreshGuide)
    end)
    card.next = UI.Text(card, 11)
    card.next:SetPoint("BOTTOMLEFT", 10, 8)
    card.next:SetPoint("RIGHT", card.nextPlanBtn, "LEFT", -6, 0)

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
    -- what's missing besides materials (an anvil, a forge, a tool): red, under it
    d.req = UI.Text(mid, 11, 1, 0.35, 0.3)
    d.req:SetPoint("TOPLEFT", d.sub, "BOTTOMLEFT", 0, -3)
    d.req:SetPoint("RIGHT", -12, 0)

    local countLabel = UI.Text(mid, 11, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3])
    countLabel:SetPoint("TOPLEFT", 12, -70)
    countLabel:SetText("Crafts")
    win.count = CreateFrame("EditBox", nil, mid)
    win.count:SetSize(44, 22)
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
    d.make = UI.Button(mid, "Make", 72, 22)
    d.make:SetPoint("LEFT", win.count, "RIGHT", 8, 0)
    d.make:SetScript("OnClick", function() JQ.Try("professions window: make", Make, false) end)
    d.make:SetScript("OnEnter", function(self)
        if not d.missing then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Can't make it here", 1, 0.35, 0.3)
        GameTooltip:AddLine(MissingText(d.missing) .. ".", 0.9, 0.9, 0.9, true)
        GameTooltip:Show()
    end)
    d.make:SetScript("OnLeave", UI.HideTip)
    d.makeAll = UI.Button(mid, "Make all", 92, 22)
    d.makeAll:SetPoint("LEFT", d.make, "RIGHT", 4, 0)
    d.makeAll:SetScript("OnClick", function() JQ.Try("professions window: make", Make, true) end)
    d.makeAll:SetScript("OnEnter", function(self)
        if not d.missing then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Can't make it here", 1, 0.35, 0.3)
        GameTooltip:AddLine(MissingText(d.missing) .. ".", 0.9, 0.9, 0.9, true)
        GameTooltip:Show()
    end)
    d.makeAll:SetScript("OnLeave", UI.HideTip)
    d.plan = UI.Button(mid, "Plan mats", 80, 22)
    d.plan:SetPoint("LEFT", d.makeAll, "RIGHT", 4, 0)
    d.plan:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    d.plan:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            JQ.Try("professions window: plan for", PlanForMenu, self)
        else
            JQ.Try("professions window: plan", Plan)
        end
    end)
    d.plan:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Plan the materials", 1, 1, 1)
        GameTooltip:AddLine("Plans a bank run for what's in your own bank or mail, asks your alts for the rest, adds a make step for what you can craft, and puts what nobody has on the buy list. The plan shows on the right.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Right-click: plan it for another character that makes it.", 0.62, 0.62, 0.66, true)
        GameTooltip:Show()
    end)
    d.plan:SetScript("OnLeave", UI.HideTip)

    -- Plans make sub-materials: one click to buy them all instead (the switch in Settings too)
    d.subBtn = UI.Button(mid, "Sub-mats: make", 120, 18)
    d.subBtn:SetPoint("TOPLEFT", 12, -98)
    d.subBtn:SetScript("OnClick", function()
        JQ.SetEnabled("planSubMats", not JQ.IsEnabled("planSubMats"))
        RefreshDetail()
        if db.tab == "guide" then JQ.Try("professions window: guide step", RefreshGuide) end
    end)
    d.subBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Sub-materials", 1, 1, 1)
        GameTooltip:AddLine(JQ.IsEnabled("planSubMats")
            and "Make: when nobody has enough of a material you can make (bars, heavier leather), the plan makes it from its own materials. Click to buy them instead."
            or "Buy: materials nobody has go on the buy list, even ones you could make. Click to make them again.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Right-click a material to always buy just that one.", 0.62, 0.62, 0.66, true)
        GameTooltip:Show()
    end)
    d.subBtn:SetScript("OnLeave", UI.HideTip)
    local head = UI.Text(mid, 10, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3], "RIGHT")
    head:SetPoint("TOPRIGHT", -12, -104)
    head:SetText("need   have   alts")
    -- two lines a material: its name, then where it comes from and what the lot costs
    for i = 1, 11 do
        local row = CreateFrame("Button", nil, mid)
        row:SetHeight(34)
        row:SetPoint("TOPLEFT", 12, -118 - (i - 1) * 36)
        row:SetPoint("RIGHT", -12, 0)
        UI.Fill(row, 1, 1, 1, 0.05, "HIGHLIGHT")
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(24, 24)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.nums = UI.Text(row, 11, 1, 1, 1, "RIGHT")
        row.nums:SetPoint("RIGHT")
        row.nums:SetWidth(104)
        row.name = UI.Text(row, 12)
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, 1)
        row.name:SetPoint("RIGHT", row.nums, "LEFT", -6, 0)
        row.info = UI.Text(row, 10, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3])
        row.info:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
        row.info:SetPoint("RIGHT", row.nums, "LEFT", -6, 0)
        row:SetScript("OnEnter", function(self) JQ.Try("professions window: material tooltip", RowEnter, self) end)
        row:SetScript("OnLeave", UI.HideTip)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                JQ.Try("professions window: buy, don't make", RowRightClick, self)
            else
                UI.ItemClick(self)
            end
        end)
        d.rows[i] = row
    end
    d.summary = UI.Text(mid, 11, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3])
    d.summary:SetPoint("BOTTOMLEFT", 12, 8)
    d.summary:SetPoint("RIGHT", -12, 0)
    d.summary:SetHeight(28)
    d.summary:SetWordWrap(true)
    d.summary:SetJustifyV("TOP")
    if d.summary.SetMaxLines then d.summary:SetMaxLines(2) end
    -- gold: three single lines above it
    d.gold = {}
    for i = 1, 3 do
        local g = UI.Text(mid, 11, 0.86, 0.86, 0.88)
        g:SetPoint("BOTTOMLEFT", 12, 40 + (3 - i) * 16)
        g:SetPoint("RIGHT", -12, 0)
        d.gold[i] = g
    end

    classicBtn:SetScript("OnClick", function()
        classic = true
        Tuck(false)
        win:Hide()
        JQ.Try("professions window: switch button", ShowSwitch)   -- the way back
    end)

    win:SetScript("OnShow", function()
        if JQ.Requests and JQ.Requests.Dock then JQ.Requests.Dock(win.planHost) end
        if JQ.Requests and JQ.Requests.DockBar then
            local docked = JQ.Requests.DockBar(win.barHost)
            -- (with the bar switched off, the panels use the strip)
            win.left:SetPoint("BOTTOMLEFT", 10, docked and 36 or 10)
            win.right:SetPoint("BOTTOMRIGHT", -10, docked and 36 or 10)
        end
        JQ.Try("professions window: tab", SetTab, db.tab or "plan")
        Queue()
    end)
    win:SetScript("OnHide", function()
        if JQ.Requests and JQ.Requests.Undock then JQ.Requests.Undock() end
        if JQ.Requests and JQ.Requests.DockBar then JQ.Requests.DockBar(nil) end
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
        if since < 0.1 then return end
        since = 0
        JQ.Try("professions window: mini guide", DockGuide)
        -- moving: 20%, so the window doesn't hide where you're going; whole when still or under the mouse
        -- (on a flight path you're not steering: it stays whole)
        local onTaxi = UnitOnTaxi and UnitOnTaxi("player")
        local moving = not onTaxi and ((GetUnitSpeed and (GetUnitSpeed("player") or 0) > 0) or (IsFalling and IsFalling())) or false
        local want = (moving and not win:IsMouseOver()) and 0.2 or 1
        if math.abs((win:GetAlpha() or 1) - want) > 0.01 then win:SetAlpha(want) end
        -- walking up to (or away from) an anvil or forge changes what can be made here
        local r = selected and byID[selected]
        local key = r and table.concat(Missing(r) or {}, ",") or ""
        if key ~= (win.missKey or "") then
            win.missKey = key
            JQ.Try("professions window: needs", function()
                RefreshDetail()
                win.list:Render()
                if db.tab == "guide" then RefreshGuide() end
            end)
        end
        if JQ.Requests and JQ.Requests.PlanShown then
            win.planEmpty:SetShown(db.tab ~= "guide" and not JQ.Requests.PlanShown())
        end
        local R = JQ.Requests
        local canUndo = R ~= nil and R.CanUndoCancel ~= nil and R.CanUndoCancel()
        win.clearBtn.text:SetText(canUndo and "Undo clear" or "Clear plan")
        win.clearBtn:SetShown(db.tab ~= "guide" and R ~= nil and ((R.HasPlan ~= nil and R.HasPlan()) or canUndo))
        win.tabGuide:SetShown(HasMastercraft())
        -- Mastercraft's guide wasn't there yet: ask again
        if db.tab == "guide" and not db.theirGuide and win.guideCard.waiting then
            JQ.Try("professions window: guide step", RefreshGuide)
        end
    end)
end

-- Should a profession that opens now get this window?
local function Wanted()
    return JQ.IsEnabled(KEY) and JQ.IsEnabled("altRequest") and not classic
end

local function Open()
    local f = Blizzard()
    Dbg("Open: wanted=%s classic=%s frame=%s shown=%s own=%s", tostring(Wanted()), tostring(classic),
        tostring(f ~= nil), tostring(f and f:IsShown()), tostring(IsOwnProfession()))
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
    -- the Guide tab, when that's where you left it (Mastercraft's button appears a moment after)
    if db.tab == "guide" then
        C_Timer.After(0.6, function()
            if win:IsShown() then JQ.Try("professions window: tab", SetTab, "guide") end
        end)
    end
end

-- On the game's own profession window: a button to this one. It shows while
-- the JaseTools window is switched off, and in Classic view; one click
-- switches the window on (if it was off) and opens it.
local switchBtn
function ShowSwitch()
    local f = Blizzard()
    if not (f and f:IsShown()) or not JQ.IsEnabled("altRequest") then
        if switchBtn then switchBtn:Hide() end
        return
    end
    if not switchBtn then
        switchBtn = UI.Button(f, "JaseTools view", 124, 22)
        switchBtn:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -8, 2)
        switchBtn:SetScript("OnClick", function()
            classic = false
            if not JQ.IsEnabled(KEY) then
                JQ.SetEnabled(KEY, true)   -- (switching it on opens it)
            else
                Open()
            end
            if switchBtn then switchBtn:SetShown(not (win and win:IsShown())) end
        end)
        switchBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("JaseTools professions window", 1, 1, 1)
            GameTooltip:AddLine("One window for recipes, materials, gold, your plan and the Mastercraft guide. Click to use it"
                .. (JQ.IsEnabled(KEY) and "." or " from now on (it is switched off). Switch it off again in /jq > Professions, or use Classic view."),
                0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        switchBtn:SetScript("OnLeave", UI.HideTip)
    end
    switchBtn:SetShown(IsOwnProfession() and (not JQ.IsEnabled(KEY) or classic) and not (win and win:IsShown()))
end

-------------------------------------------------------------------------------
--  WoW Forever's all-professions book: opening it opens this window instead,
--  on the profession you had open last (or your first crafting profession).
--  With no crafting profession, or after "All professions", the book stays.
-------------------------------------------------------------------------------
local tradeOpen = false    -- a profession is open (between TRADE_SKILL_SHOW and its close)
local allowBook = false   -- the book was asked for from this window: leave it open once
local bookHooked = false

local function FirstLine()
    if db.lastLine then return db.lastLine end
    local game = GameLines()
    local names = {}
    for prof in pairs(game) do
        if LINES[prof] and prof ~= "Mining" then names[#names + 1] = prof end
    end
    table.sort(names)
    if names[1] then return game[names[1]] end
    local me = JQ.Alts and JQ.Alts.MyName()
    local data = me and JQ.Alts.RealmTable()[me]
    local names = {}
    for prof in pairs(data and data.profs or {}) do
        if LINES[prof] and prof ~= "Mining" then names[#names + 1] = prof end
    end
    table.sort(names)
    if names[1] then return LINES[names[1]] end
    return data and data.profs and data.profs.Mining and LINES.Mining or nil
end

local function BookShown(book)
    Dbg("professions book: OnShow (allowBook=%s wanted=%s combat=%s)", tostring(allowBook), tostring(Wanted()), tostring(InCombatLockdown()))
    if toggleHooked then return end   -- (the toggle hook does it)
    if allowBook then allowBook = false return end
    if not Wanted() or InCombatLockdown() then return end
    local line = FirstLine()
    local t = T()
    if not (line and t and t.OpenTradeSkill) then return end   -- nothing to craft: the book is all there is
    local ok, err = pcall(t.OpenTradeSkill, line)
    Dbg("  book -> OpenTradeSkill(%s): %s %s", tostring(line), tostring(ok), tostring(err))
    if not ok then return end
    -- once the profession is up, the book goes
    C_Timer.After(0, function()
        local f = Blizzard()
        if f and f:IsShown() and book:IsShown() and not InCombatLockdown() then
            if HideUIPanel then pcall(HideUIPanel, book) else book:Hide() end
        end
    end)
end

local panelsHooked = false
local function HookPanels()
    if panelsHooked or not hooksecurefunc then return end
    panelsHooked = true
    local function name(f) return type(f) == "table" and f.GetName and f:GetName() or tostring(f) end
    if ShowUIPanel then hooksecurefunc("ShowUIPanel", function(f) Dbg("ShowUIPanel %s", name(f)) end) end
    if HideUIPanel then hooksecurefunc("HideUIPanel", function(f) Dbg("HideUIPanel %s", name(f)) end) end
    for _, fn in ipairs({ "ToggleProfessionsBook", "ToggleSpellBook", "ProfessionsFrame_LoadUI", "ProfessionsBook_LoadUI" }) do
        if type(_G[fn]) == "function" then hooksecurefunc(fn, function(...) Dbg("%s(%s)", fn, table.concat({ tostringall(...) }, ", ")) end) end
    end
end

-- The book was toggled (K, the micro-menu button). When that opened it, and no
-- profession is open yet, open the profession you used last instead.
local function BookToggled()
    local book = _G.ProfessionsBookFrame
    local pf = Blizzard()
    Dbg("book toggled: allowBook=%s wanted=%s combat=%s tradeOpen=%s book=%s profFrame=%s ours=%s", tostring(allowBook),
        tostring(Wanted()), tostring(InCombatLockdown()), tostring(tradeOpen), tostring(book and book:IsShown()),
        tostring(pf and pf:IsShown()), tostring(win and win:IsShown()))
    if allowBook then allowBook = false return end
    if not Wanted() or InCombatLockdown() or tradeOpen or (win and win:IsShown()) then return end
    -- a toggle that closed it: nothing to do
    local opened = (book and book:IsShown()) or (pf and pf:IsShown())
    if not opened then return end
    local line = FirstLine()
    local t = T()
    if not (line and t and t.OpenTradeSkill) then return end   -- nothing to craft: the book is all there is
    local ok, err = pcall(t.OpenTradeSkill, line)
    Dbg("  book -> OpenTradeSkill(%s): %s %s", tostring(line), tostring(ok), tostring(err))
    if ok and book and book:IsShown() then
        C_Timer.After(0, function()
            if book:IsShown() and tradeOpen and not InCombatLockdown() then
                if HideUIPanel then pcall(HideUIPanel, book) else book:Hide() end
            end
        end)
    end
end

local toggleHooked = false
local function HookToggle()
    if toggleHooked or not (hooksecurefunc and type(_G.ToggleProfessionsBook) == "function") then return end
    toggleHooked = true
    hooksecurefunc("ToggleProfessionsBook", function() JQ.Try("professions window: professions book", BookToggled) end)
end

local function HookBook()
    local book = _G.ProfessionsBookFrame
    Dbg("HookBook: ProfessionsBookFrame %s, already hooked %s", book and "exists" or "missing", tostring(bookHooked))
    if bookHooked or not book then return end
    bookHooked = true
    book:HookScript("OnShow", function(self) JQ.Try("professions window: professions book", BookShown, self) end)
    book:HookScript("OnHide", function() Dbg("professions book: OnHide") end)
end

function OpenBook()
    allowBook = true
    if ToggleProfessionsBook then
        pcall(ToggleProfessionsBook)
    elseif _G.ProfessionsBookFrame and ShowUIPanel then
        pcall(ShowUIPanel, _G.ProfessionsBookFrame)
    else
        allowBook = false
        JQ.Print("The professions book isn't available.")
    end
end

-- A profession has opened. The game's window can take a moment to appear
-- (it is loaded on first use), and the game a moment to say whose profession
-- it is: so this tries until our window is open or it is clear it shouldn't be.
local blizzHooked = false
local Close   -- forward

local function TryOpen(n)
    n = n or 1
    local f = Blizzard()
    Dbg("TryOpen #%d: tradeOpen=%s frame=%s shown=%s ours=%s", n, tostring(tradeOpen), tostring(f ~= nil),
        tostring(f and f:IsShown()), tostring(win and win:IsShown()))
    if f and not blizzHooked then
        blizzHooked = true
        f:HookScript("OnShow", function() Dbg("game's profession window: OnShow") end)
        -- the game's window can close without the close event reaching us:
        -- then Classic view would stick, and the next profession would open in the game's window
        f:HookScript("OnHide", function()
            Dbg("game's profession window: OnHide")
            JQ.Try("professions window: closing", Close)
        end)
    end
    if not tradeOpen then return end
    if f and f:IsShown() then
        if Wanted() then Tuck(true) end
        Open()
        ShowSwitch()
    end
    if (win and win:IsShown()) or not Wanted() or n >= 10 then return end
    C_Timer.After(0.15, function() JQ.Try("professions window: opening", TryOpen, n + 1) end)
end

function Close()
    tradeOpen = false
    classic = false
    if win and win:IsShown() then
        classic = true      -- (the profession is closing already: don't close it again)
        win:Hide()
        classic = false
    end
    Tuck(false)
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if type(name) == "string" and name:find("Profession", 1, true) then Dbg("ADDON_LOADED %s", name) end
        if name == "Blizzard_ProfessionsBook" then
            JQ.Try("professions window: professions book", HookToggle)
            JQ.Try("professions window: professions book", HookBook)
        end
        return
    end
    if event ~= "BAG_UPDATE_DELAYED" and event ~= "UNIT_SPELLCAST_START" and event ~= "UNIT_SPELLCAST_SUCCEEDED" then
        Dbg("event %s", event)
    end
    if event == "TRADE_SKILL_SHOW" and db and db.debug then
        local t = T()
        local ok, info = pcall(function() return t and t.GetBaseProfessionInfo and t.GetBaseProfessionInfo() end)
        Dbg("  base profession: %s id=%s skill=%s", tostring(ok and info and info.professionName), tostring(ok and info and info.professionID),
            tostring(ok and info and info.skillLevel))
        local list = {}
        for name, line in pairs(GameLines()) do list[#list + 1] = name .. "=" .. line end
        Dbg("  game's profession lines: %s", #list > 0 and table.concat(list, ", ") or "(none: GetProfessions not here)")
        Dbg("  linked=%s guild=%s npc=%s", tostring(t and t.IsTradeSkillLinked and t.IsTradeSkillLinked()),
            tostring(t and t.IsTradeSkillGuild and t.IsTradeSkillGuild()), tostring(t and t.IsNPCCrafting and t.IsNPCCrafting()))
    end
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_SUCCEEDED" then
        if ... == "player" then craftWatch = nil end
        return
    end
    if event == "UI_ERROR_MESSAGE" then
        craftWatch = nil   -- (the game said why itself)
        -- the game refused a Make of ours (no anvil, wrong place): say why on that recipe
        local _, text = ...
        if lastMake and type(text) == "string" and (GetTime() - lastMake.at) < 2 then
            makeError[lastMake.id] = { text = text, at = GetTime() }
            lastMake = nil
            if win and win:IsShown() then Queue() end
        end
        return
    end
    if event == "TRADE_SKILL_SHOW" then
        -- out of sight straight away (no flash of the game's window); a moment
        -- later the game can say whose profession it is, and this window opens
        tradeOpen = true
        JQ.Try("professions window: opening", TryOpen, 1)
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
        "BAG_UPDATE_DELAYED", "NEW_RECIPE_LEARNED", "SKILL_LINES_CHANGED", "UI_ERROR_MESSAGE", "ADDON_LOADED", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    if db.debug then JQ.Try("professions window: debug", HookPanels) end
    JQ.Try("professions window: professions book", HookToggle)
    JQ.Try("professions window: professions book", HookBook)   -- (already loaded)
    SLASH_JASEQOLPROF1 = "/jprof"
    SlashCmdList.JASEQOLPROF = function(msg)
        msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        if msg == "debug" then
            db.debug = not db.debug or nil
            if db.debug then
                db.debugLog = {}
                HookPanels()
            end
            JQ.Print(db.debug and "Professions debug log ON. Open your professions the usual way (and press make in the plan), then /reload so it's saved. /jprof debug again turns it off."
                or ("Professions debug log off (%d lines kept until it's turned on again)."):format(#(db.debugLog or {})))
            return
        end
        if win and win:IsShown() then
            win:Hide()
        else
            classic = false
            Open()
            if not (win and win:IsShown()) then JQ.Print("Open a profession first: its window becomes the JaseTools one.") end
        end
    end
end
JQ.byKey[KEY].onEnable = function()
    -- a profession that's open right now gets the window straight away
    classic = false
    local f = Blizzard()
    tradeOpen = f ~= nil and f:IsShown() and true or false
    JQ.Try("professions window: opening", Open)
    JQ.Try("professions window: switch button", ShowSwitch)
end
JQ.byKey[KEY].onDisable = function()
    C_Timer.After(0, function() JQ.Try("professions window: switch button", ShowSwitch) end)
    if win and win:IsShown() then
        classic = true
        win:Hide()
        classic = false
    end
    Tuck(false)
end

-- A plan's craft is made. When it was a guide step's, offer to plan the next.
local function GoalDone(label, id, n)
    if not (type(label) == "string" and (label:find("%(guide%)$") or label:find("%(Mastercraft%)$"))) then return end
    if not (StaticPopup_Show and StaticPopupDialogs) then return end
    StaticPopupDialogs.JASEQOL_NEXT_STEP = StaticPopupDialogs.JASEQOL_NEXT_STEP or {
        text = "%s", button1 = "Plan next step", button2 = CANCEL or "Not now",
        OnAccept = function()
            if not (win and win:IsShown() and HasMastercraft()) then
                JQ.Print("Open the profession to plan the guide's next step: the Mastercraft guide tab has it.")
                return
            end
            SetTab("guide")
            local b = win.guideCard and win.guideCard.planBtn
            if b and b:IsShown() and b.main then
                PlanGuideStep(b.main, b.crafts, b.label)
            else
                JQ.Print("The guide's next step has nothing to plan here (a recipe to learn, or gathering).")
            end
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopup_Show("JASEQOL_NEXT_STEP", ("Made %d %s: that guide step's plan is done.\n\nPlan the next step's materials?"):format(n or 0, (UI.ItemNameQuality(id))))
end
if JQ.Requests and JQ.Requests.OnGoalDone then JQ.Requests.OnGoalDone(function(...) JQ.Try("professions window: next step", GoalDone, ...) end) end

JQ.ProfView = { Active = function() return win ~= nil and win:IsShown() end, Wanted = Wanted,
    CraftNow = function(rid, n, name, quiet) PickInGame(rid); return CraftNow(rid, n, name, quiet) end,
    LineFor = LineFor, Debug = Dbg,
    -- show the recipe that makes an item (once its profession is open)
    SelectOutput = function(itemID)
        if not (win and win:IsShown()) then return false end
        ReadRecipes()
        local r = byOut[itemID]
        if r then Select(r.id); win.list:SetItems(ListItems(), true) end
        return r ~= nil
    end,
    Line = function(prof) return db and db.lines and db.lines[prof] end }

-- for tests
JQ._ProfView = { HookToggleAgain = function() toggleHooked = false; HookToggle() end, LineFor = LineFor, GameLines = GameLines, CraftNow = CraftNow, GameFormRecipe = GameFormRecipe, FirstLine = FirstLine, HookBook = HookBook, Missing = Missing, Switch = function() return switchBtn end, GuideStep = GuideStep, WorkOrder = WorkOrder, RefreshGuide = RefreshGuide, SetTab = SetTab,
    RecipeProfit = function(r) return RecipeProfit(r) end, RecipeCost = RecipeCost, BestCost = BestCost, CostLines = CostLines, ReadRecipes = function() ReadRecipes(); return recipes end, ListItems = ListItems, CanMake = CanMake,
    Open = Open, Close = Close, Select = Select, Make = Make, Plan = Plan, Refresh = Refresh,
    Tucked = function() return tucked end, Window = function() return win end }
