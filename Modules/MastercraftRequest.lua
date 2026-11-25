-------------------------------------------------------------------------------
--  JaseTools: Request from alts, on Mastercraft's profession guide
--
--  Mastercraft > Professions shows the step you're on ("Craft 18 Unstable
--  Trigger") with a NEEDS tile. This puts a "Plan mats" button on that tile:
--  one click plans a bank run for what's in this character's own bank or
--  mail, asks your alts for the rest (the Requests plan and its popout take
--  it from there), and what no alt has goes on the buy list - with
--  Auctionator, straight into the "JaseTools" shopping list.
--
--  Mastercraft keeps its data to itself, so this reads what its page shows:
--  the page frame's guide / step, and the item slots of the NEEDS tile (the
--  materials as Mastercraft worked them out, up to three). A fourth material
--  and on comes from the step's own list, by name. Nothing of Mastercraft's is
--  changed; the button is JaseTools' own.
-------------------------------------------------------------------------------
local _, JQ = ...
local KEY = "mcRequest"

JQ.AddModule({
    key = KEY,
    label = "Plan mats in Mastercraft",
    description = "Adds a Plan mats button to the step shown in Mastercraft > Professions: it plans a bank run for what's in your own bank or mail, asks your alts for the rest and puts what no alt has on the buy list (an Auctionator shopping list when Auctionator is installed). Needs Request mats from alts and Mastercraft.",
    default = true,
})

local UI = JQ.UI
local page, button
local GetItemInfoFn = (C_Item and C_Item.GetItemInfo) or GetItemInfo

-- Mastercraft's Professions page: the frame that holds the step card (.now),
-- the open guide (.guide) and the step (.current, or .focus when another is open).
local function FindPage()
    if page then return page end
    local root = _G.MastercraftFrame
    if not root then return nil end
    local function walk(f, depth)
        if type(f.now) == "table" and type(f.now.tiles) == "table" and f.gate then return f end
        if depth >= 6 then return nil end
        for _, child in ipairs({ f:GetChildren() }) do
            local found = walk(child, depth + 1)
            if found then return found end
        end
    end
    page = walk(root, 0)
    return page
end

-- "2 Mithril Casing, Unstable Trigger" -> { {name, qty}, ... } (Mastercraft's own format)
local function ParseMats(text)
    local out = {}
    if type(text) ~= "string" then return out end
    for part in text:gmatch("[^,/]+") do
        part = part:gsub("^%s+", ""):gsub("%s+$", "")
        local qty, name = part:match("^(%d+)%-?%d*%s+(.+)$")
        if not qty then qty, name = 1, part end
        if name ~= "" and name ~= "shards" then out[#out + 1] = { name = name, qty = tonumber(qty) } end
    end
    return out
end

local function IDByName(name, index)
    local id = index[name:lower()]
    if id then return id end
    local _, link = GetItemInfoFn(name)
    return link and tonumber(link:match("item:(%d+)")) or nil
end

-- The step on show and what it needs: { title, crafts, needs = {{id, need}}, unknown = {names} }
local function StepNeeds()
    local p = FindPage()
    local card = p and p.now
    if not (card and card:IsVisible() and p.guide and type(p.guide.steps) == "table") then return nil end
    local step = (p.focus and p.guide.steps[p.focus]) or p.current
    if not (type(step) == "table" and step.mats) then return nil end
    local tile = card.tiles[1]
    if not (tile and type(tile.slots) == "table") then return nil end
    local out = { title = step.title or "?", needs = {}, unknown = {}, tile = tile }
    local seen = {}
    for _, slot in ipairs(tile.slots) do
        local need = slot:IsShown() and slot.itemID and slot.count and tonumber(slot.count:GetText())
        if need and need > 0 then
            out.needs[#out.needs + 1] = { id = slot.itemID, need = need }
            seen[slot.itemID] = true
        end
    end
    if #out.needs == 0 then return nil end
    out.crafts = tonumber(((card.title and card.title:GetText()) or ""):match("%d+")) or 1
    -- the tile shows three materials at most: the rest by name from the step's list
    local parsed = ParseMats(step.mats)
    if #out.needs >= 3 and #parsed > 3 then
        local index = JQ.Requests.NameIndex()
        for i = 4, #parsed do
            local m = parsed[i]
            local id = IDByName(m.name, index)
            if not id then
                out.unknown[#out.unknown + 1] = m.name
            elseif not seen[id] then
                seen[id] = true
                out.needs[#out.needs + 1] = { id = id, need = m.qty * out.crafts }
            end
        end
    end
    return out
end

local function Label(step)
    return (step.crafts > 1 and (step.crafts .. "x ") or "") .. step.title .. " (Mastercraft)"
end

local function Work(step)
    local list = {}
    for _, n in ipairs(step.needs) do list[#list + 1] = { id = n.id, per = n.need } end
    return JQ.Requests.Breakdown(list, 1)
end

local function Request()
    local R, Alts = JQ.Requests, JQ.Alts
    local me = Alts and Alts.MyName()
    local step = StepNeeds()
    if not (R and me and step) then return end
    local label = Label(step)
    -- planned before: take that plan's asks back out, then plan it afresh
    -- (what you have changes; a second click must never double anything)
    local mine = R.RequestOf(me)
    local again = false
    if mine then
        local old = mine.plans and mine.plans[label]
        for id, n in pairs(old or {}) do
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
    local rows, request, tot = Work(step)
    -- what's in this character's own bank or mail is a bank run, not a request;
    -- what nobody has enough of but this character can make (bars from ore) is made
    local own, made = R.PlanOwn(me, rows)
    if not next(request) and own == 0 and made == 0 then
        if again then R.AddRequest(me, {}, nil) end   -- tidies away what was taken back out
        JQ.Print(tot.vendor > 0 and ("Nothing to plan for %s: the rest is sold by vendors."):format(step.title)
            or ("Nothing to plan for %s: it's all in your bags."):format(step.title))
        return
    end
    R.AddRequest(me, request, label)
    if next(request) then
        -- remembered, so planning this step again can take it back out first
        local r = R.RequestOf(me)
        if r then
            r.plans = r.plans or {}
            r.plans[label] = {}
            for id, n in pairs(request) do r.plans[label][id] = n end
        end
    end
    if again then JQ.Print(("Planned %s again, from what you have now."):format(label)) end
    if own > 0 then
        JQ.Print(("Bank run for %s: %d item(s) to take from your own bank or mail."):format(label, own))
    end
    if made > 0 then
        local parts = {}
        for _, e in ipairs(rows) do
            if e.kind == "make" and (e.makeQty or 0) > 0 then parts[#parts + 1] = R.ItemText(e.id, e.makeQty) end
        end
        JQ.Print("To make yourself: " .. table.concat(parts, ", ") .. ". The plan gathers what they're made from.")
    end
    if next(request) then
        local parts = {}
        for id, n in pairs(request) do parts[#parts + 1] = R.ItemText(id, n) end
        JQ.Print(("Requested for %s: %s. The request plan has the steps."):format(label, table.concat(parts, ", ")))
    end
    if #step.unknown > 0 then
        JQ.Print("Couldn't work out these materials, add them yourself: " .. table.concat(step.unknown, ", "))
    end
    -- what no alt has: the buy list, as an Auctionator shopping list when it's there
    local toBuy, order = R.BuyList(me)
    if #order > 0 then
        if R.ShoppingListAPI() then
            R.MakeShoppingList(order, toBuy)
        else
            JQ.Print(("%d item(s) are on no alt: the Requests tab lists what to buy."):format(#order))
        end
    end
end

local function Tooltip(self)
    local step = StepNeeds()
    if not (step and JQ.Requests) then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Plan the materials", 1, 1, 1)
    GameTooltip:AddLine(Label(step), 1, 0.82, 0.35)
    local rows = Work(step)
    local bags = JQ.Requests.Holdings(JQ.Alts.MyName())
    for _, e in ipairs(rows) do
        do
            -- what a make needs is listed under it, indented
            local what = (e.kind == "ok" and ((bags[e.id] or 0) >= e.need and "|cff59d959in your bags|r" or "|cffffd25ayour bank or mail|r"))
                or (e.kind == "vendor" and "|cff9e9ea8from a vendor|r")
                or (e.kind == "alts" and "|cffffd25afrom alts|r")
                or (e.kind == "make" and ("|cffffd25amake %d|r"):format(e.makeQty or 0))
                or "|cffff7070buy it|r"
            GameTooltip:AddDoubleLine(("   "):rep(e.depth) .. JQ.Requests.ItemText(e.id, e.need),
                ("have %d, alts %d  %s"):format(e.have, e.alts, what), 0.9, 0.9, 0.9, 0.7, 0.7, 0.7)
        end
    end
    GameTooltip:AddLine("Plans a bank run for what's in your own bank or mail, asks your alts for the rest and plans who sends what. What no alt has goes on the buy list"
        .. (JQ.Requests.ShoppingListAPI() and " and into Auctionator's JaseTools shopping list." or "."), 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end

-- Keep the button on the NEEDS tile of a crafting step, and off everything else.
local function Sync()
    local on = JQ.IsEnabled(KEY) and JQ.IsEnabled("altRequest") and JQ.Requests ~= nil
    local step = on and StepNeeds()
    if not step then
        if button then button:Hide() end
        return
    end
    if not button then
        button = UI.Button(step.tile, "Plan mats", 128, 18)
        button:SetScript("OnClick", function() JQ.Try("Mastercraft request", Request) end)
        button:SetScript("OnEnter", function(self) JQ.Try("Mastercraft request tooltip", Tooltip, self) end)
        button:SetScript("OnLeave", UI.HideTip)
    end
    if button:GetParent() ~= step.tile then button:SetParent(step.tile) end
    button:ClearAllPoints()
    button:SetPoint("TOPRIGHT", step.tile, "TOPRIGHT", -6, -4)
    button:SetFrameLevel(step.tile:GetFrameLevel() + 5)
    button:Show()
end

local ticker = CreateFrame("Frame")
local since = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
    since = since + elapsed
    if since < 0.3 then return end
    since = 0
    local root = _G.MastercraftFrame
    if root and root:IsShown() then
        JQ.Try("Mastercraft request button", Sync)
    elseif button and button:IsShown() then
        button:Hide()
    end
end)

JQ.byKey[KEY].onDisable = function() if button then button:Hide() end end

-- for tests
JQ._MastercraftRequest = { ParseMats = ParseMats, StepNeeds = StepNeeds, Request = Request, Sync = Sync }
