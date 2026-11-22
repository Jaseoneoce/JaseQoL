-------------------------------------------------------------------------------
--  JaseTools: quest items you could sell by mistake
--
--  Some items a quest asks for are ordinary items that a vendor buys
--  (Scorpok Pincer, Linen Cloth...), so the game doesn't mark them as quest
--  items. While one is an objective of a quest in your log (collected or not:
--  you still need it until you hand the quest in), JaseTools
--    * tags it "Quest" on its bag slot (bottom-left, like EllesmereUI's BoE),
--    * adds "Needed for: <quest> (3/8)" to its tooltip,
--    * warns on screen and in chat if you sell it, so you can buy it back.
--  The bag tag rides on the game's own SetItemButtonQuality, which
--  EllesmereUI's bags, its bank and the default bags all call for each slot.
-------------------------------------------------------------------------------
local _, JQ = ...
local KEY = "questItemGuard"

JQ.AddModule({
    key = KEY,
    label = "Flag items your quests need",
    description = "Items a quest in your log asks for (like Scorpok Pincer) get a yellow \"QST\" tag on their bag slot and a \"Needed for\" line on their tooltip, and selling one to a vendor shows a big warning so you can buy it back.",
    default = true,
})
local CAT_KEY = "questBagCategory"
JQ.AddModule({
    key = CAT_KEY,
    label = "Quests category in EllesmereUI bags",
    description = "Adds a Quests category to EllesmereUI's bags (All Items view) holding every quest item: pure quest items and items a quest in your log needs (like Scorpok Pincer). Items you've assigned to a category yourself stay where you put them. Needs EllesmereUI Bags.",
    default = true,
})

local C = C_Container
local GetItemInfoFn = (C_Item and C_Item.GetItemInfo) or GetItemInfo

-------------------------------------------------------------------------------
--  What the quests in the log ask for: need[item name, lower case]
-------------------------------------------------------------------------------
local need = {}

-- "Scorpok Pincer: 3/8" or "3/8 Scorpok Pincer" -> name, have, total
local function ParseObjective(text)
    if type(text) ~= "string" then return end
    local name, have, total = text:match("^(.-):%s*(%d+)%s*/%s*(%d+)")
    if not name then have, total, name = text:match("^(%d+)%s*/%s*(%d+)%s+(.+)$") end
    if name and name ~= "" then return name, tonumber(have), tonumber(total) end
end

local function AddNeed(questTitle, text)
    local name, have, total = ParseObjective(text)
    if not name then return end
    local key = name:lower()
    local e = need[key] or {}
    need[key] = e
    e[#e + 1] = { quest = questTitle or "?", have = have, total = total }
end

local function Rebuild()
    wipe(need)
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetQuestObjectives then
        for i = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader and info.questID then
                for _, o in ipairs(C_QuestLog.GetQuestObjectives(info.questID) or {}) do
                    if o.type == "item" then AddNeed(info.title, o.text) end
                end
            end
        end
    elseif GetNumQuestLogEntries and GetQuestLogLeaderBoard then
        for i = 1, GetNumQuestLogEntries() do
            local title, _, _, isHeader = GetQuestLogTitle(i)
            if not isHeader then
                for j = 1, (GetNumQuestLeaderBoards(i) or 0) do
                    local text, kind = GetQuestLogLeaderBoard(j, i)
                    if kind == "item" then AddNeed(title, text) end
                end
            end
        end
    end
end

local function NameOf(item)
    -- only item IDs and links (bag code can pass other things)
    if type(item) ~= "number" and type(item) ~= "string" then return nil end
    if issecretvalue and issecretvalue(item) then return nil end
    local ok, name = pcall(GetItemInfoFn, item)
    if not ok then name = nil end
    if not name and type(item) == "string" then name = item:match("%[(.-)%]") end
    return type(name) == "string" and name or nil
end

-- The quests that need this item, or nil.
local function Needed(item)
    if not JQ.IsEnabled(KEY) then return nil end
    local name = NameOf(item)
    return name and need[name:lower()] or nil
end
JQ.QuestNeeds = Needed

-------------------------------------------------------------------------------
--  Bag slot tag
-------------------------------------------------------------------------------
-- Kept in JaseTools' own tables, never written onto the game's bag buttons.
local weak = { __mode = "k" }
local itemOf = setmetatable({}, weak)    -- button -> item ID / link it shows
local tagOf = setmetatable({}, weak)     -- button -> our "QST" text
local styled = setmetatable({}, weak)

-- Look like EllesmereUI's own slot text (its BoE label): same font, size,
-- outline, shadow and corner, read from that label each time so it follows
-- EllesmereUI's font settings. Without EllesmereUI: a small outlined font.
local function Style(tag, btn)
    local ref = rawget(btn, "BindTypeText")
    if ref and type(ref) == "table" and ref.GetFont then
        local font, size, flags = ref:GetFont()
        if font then tag:SetFont(font, size or 10, flags or "") end
        if ref.GetShadowOffset then tag:SetShadowOffset(ref:GetShadowOffset()) end
        if ref.GetShadowColor then tag:SetShadowColor(ref:GetShadowColor()) end
        local p, rel, rp, x, y = ref:GetPoint(1)
        if p then
            tag:ClearAllPoints()
            tag:SetPoint(p, rel or btn, rp or p, x or 0, y or 0)
            return
        end
    elseif not styled[btn] then
        local font, size = GameFontNormalSmall and GameFontNormalSmall:GetFont()
        tag:SetFont(font or STANDARD_TEXT_FONT, math.max(9, (size or 10) - 1), "OUTLINE")
    end
    tag:ClearAllPoints()
    tag:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 2, 2)
end

local function Paint(btn)
    local item = itemOf[btn]
    local show = item and Needed(item) ~= nil
    local tag = tagOf[btn]
    if show and not tag then
        local ref = rawget(btn, "BindTypeText")
        local parent = (type(ref) == "table" and ref.GetParent and ref:GetParent()) or rawget(btn, "_textOverlay") or btn
        tag = parent:CreateFontString(nil, "OVERLAY")
        tag:SetTextColor(1, 0.82, 0)
        tag:SetText("QST")
        tagOf[btn] = tag
    end
    if tag then
        if show then Style(tag, btn); styled[btn] = true end
        tag:SetShown(show and true or false)
    end
end

local function OnQuality(btn, _, item)
    if type(btn) ~= "table" then return end
    itemOf[btn] = item
    Paint(btn)
end

local function OnTexture(btn, texture)
    if type(btn) ~= "table" then return end
    if texture == nil then
        itemOf[btn] = nil
        local tag = tagOf[btn]
        if tag then tag:Hide() end
    end
end

local function RepaintAll()
    for btn in pairs(itemOf) do pcall(Paint, btn) end
end

-- These run inside the game's own bag code: never let an error escape into it
-- (it would break the bags; seen on a friend's default bags).
local function SafeQuality(...) pcall(OnQuality, ...) end
local function SafeTexture(...) pcall(OnTexture, ...) end
if ItemButtonMixin then
    if ItemButtonMixin.SetItemButtonQuality then hooksecurefunc(ItemButtonMixin, "SetItemButtonQuality", SafeQuality) end
    if ItemButtonMixin.SetItemButtonTexture then hooksecurefunc(ItemButtonMixin, "SetItemButtonTexture", SafeTexture) end
end
if SetItemButtonQuality then hooksecurefunc("SetItemButtonQuality", SafeQuality) end

-------------------------------------------------------------------------------
--  Tooltip line
-------------------------------------------------------------------------------
local function AddTooltip(tt, data)
    if tt ~= GameTooltip and tt ~= ItemRefTooltip then return end
    local item
    if data and data.id then item = data.id
    elseif tt.GetItem then item = select(2, tt:GetItem()) end
    local list = Needed(item)
    if not list then return end
    for _, e in ipairs(list) do
        local count = (e.have and e.total) and (" (" .. e.have .. "/" .. e.total .. ")") or ""
        tt:AddLine("Needed for: " .. e.quest .. count, 1, 0.82, 0)
    end
    tt:Show()
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AddTooltip)
else
    for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
        if tt then pcall(tt.HookScript, tt, "OnTooltipSetItem", function(self) AddTooltip(self) end) end
    end
end

-------------------------------------------------------------------------------
--  Selling one
-------------------------------------------------------------------------------
local function CheckSale(bag, slot)
    if not JQ.IsEnabled(KEY) then return end
    if not (MerchantFrame and MerchantFrame:IsShown()) then return end
    local info = C and C.GetContainerItemInfo and C.GetContainerItemInfo(bag, slot)
    if not info then return end
    local list = Needed(info.hyperlink or info.itemID)
    if not list then return end
    local link = info.hyperlink or ("item " .. tostring(info.itemID))
    local msg = ("Sold a quest item: %s, needed for %s. Buy it back from the Buyback tab if that was a mistake.")
        :format(link, list[1].quest)
    JQ.Print("|cffff4040" .. msg .. "|r")
    if RaidNotice_AddMessage and RaidWarningFrame then
        RaidNotice_AddMessage(RaidWarningFrame, "Sold a quest item: " .. link,
            ChatTypeInfo and ChatTypeInfo.RAID_WARNING or { r = 1, g = 0.3, b = 0.2 })
    end
    if PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then PlaySound(SOUNDKIT.RAID_WARNING) end
end

if C and C.UseContainerItem then hooksecurefunc(C, "UseContainerItem", CheckSale) end

-------------------------------------------------------------------------------
--  EllesmereUI bags: a "Quests" category (its public virtual-category API).
--  It answers before EllesmereUI's own rules, so pure quest items land here
--  too; items the player assigned to a category themselves stay put.
-------------------------------------------------------------------------------
local CAT_ID = "JaseTools.Quests"
local catRegistered = false
local QUEST_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Questitem) or 12

local function IsQuestItem(itemLink, itemID, bag, slot)
    if bag and slot and C and C.GetContainerItemQuestInfo then
        local q = C.GetContainerItemQuestInfo(bag, slot)
        if q and (q.isQuestItem or q.questID) then return true end
    end
    local classID = select(6, ((C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant)(itemLink or itemID))
    if classID == QUEST_CLASS then return true end
    -- needed by a quest in my log (only for my own bags)
    if bag and need and next(need) then
        local name = NameOf(itemLink or itemID)
        if name and need[name:lower()] then return true end
    end
    return false
end

local function SyncCategory()
    local CM = _G.EUI_CategoryManager
    if not (CM and CM.RegisterVirtualCategory) then return end
    local want = JQ.IsEnabled(CAT_KEY)
    if want and not catRegistered then
        catRegistered = CM:RegisterVirtualCategory(CAT_ID, {
            name = "Quests",
            icon = "Crosshair_Quest_64",
            isAtlas = true,
            order = -100,
            classify = function(itemLink, itemID, bag, slot)
                return IsQuestItem(itemLink, itemID, bag, slot)
            end,
        }) and true or false
    elseif not want and catRegistered then
        CM:UnregisterVirtualCategory(CAT_ID)
        catRegistered = false
    end
end

-- the needed list changed: ask EllesmereUI to sort the bags again
local lastSig
local function RefreshCategory()
    if not catRegistered then return end
    local keys = {}
    for k in pairs(need) do keys[#keys + 1] = k end
    table.sort(keys)
    local sig = table.concat(keys, "\n")
    if sig == lastSig then return end
    lastSig = sig
    local CM = _G.EUI_CategoryManager
    if CM and CM.RefreshVirtualCategories then CM:RefreshVirtualCategories() end
end

JQ.byKey[CAT_KEY].onEnable = SyncCategory
JQ.byKey[CAT_KEY].onDisable = SyncCategory

-------------------------------------------------------------------------------
--  Keep the list current
-------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN",
    "GET_ITEM_INFO_RECEIVED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
local pending
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then pcall(SyncCategory) end
    if pending then return end
    pending = true
    C_Timer.After(0.3, function()
        pending = nil
        Rebuild()
        RepaintAll()
        pcall(RefreshCategory)
    end)
end)

JQ.byKey[KEY].onEnable = function() Rebuild(); RepaintAll() end
JQ.byKey[KEY].onDisable = function() RepaintAll() end

-- for tests
JQ._QuestItemGuard = { Rebuild = Rebuild, Needed = Needed, Parse = ParseObjective, Paint = Paint,
    TagOf = function(btn) return tagOf[btn] end }
