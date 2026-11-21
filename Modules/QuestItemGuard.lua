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
    description = "Items a quest in your log asks for (like Scorpok Pincer) get a yellow \"Quest\" tag on their bag slot and a \"Needed for\" line on their tooltip, and selling one to a vendor shows a big warning so you can buy it back.",
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
    if not item then return nil end
    local name = GetItemInfoFn(item)
    if not name and type(item) == "string" then name = item:match("%[(.-)%]") end
    return name
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
local tagged = setmetatable({}, { __mode = "k" })   -- buttons we've looked at

local function Paint(btn)
    local item = rawget(btn, "_jqItem")
    local show = item and Needed(item) ~= nil
    local tag = rawget(btn, "_jqQuestTag")
    if show and not tag then
        tag = (rawget(btn, "_textOverlay") or btn):CreateFontString(nil, "OVERLAY")
        local font, size = GameFontNormalSmall and GameFontNormalSmall:GetFont()
        tag:SetFont(font or STANDARD_TEXT_FONT, math.max(9, (size or 10) - 1), "OUTLINE")
        tag:SetTextColor(1, 0.82, 0)
        tag:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 2, 2)
        tag:SetText("QST")
        btn._jqQuestTag = tag
    end
    if tag then tag:SetShown(show and true or false) end
end

local function OnQuality(btn, _, item)
    tagged[btn] = true
    btn._jqItem = item
    Paint(btn)
end

local function OnTexture(btn, texture)
    if texture == nil then
        btn._jqItem = nil
        local tag = rawget(btn, "_jqQuestTag")
        if tag then tag:Hide() end
    end
end

local function RepaintAll()
    for btn in pairs(tagged) do pcall(Paint, btn) end
end

if ItemButtonMixin then
    if ItemButtonMixin.SetItemButtonQuality then hooksecurefunc(ItemButtonMixin, "SetItemButtonQuality", OnQuality) end
    if ItemButtonMixin.SetItemButtonTexture then hooksecurefunc(ItemButtonMixin, "SetItemButtonTexture", OnTexture) end
end
if SetItemButtonQuality then hooksecurefunc("SetItemButtonQuality", OnQuality) end

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
--  Keep the list current
-------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN",
    "GET_ITEM_INFO_RECEIVED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
local pending
ev:SetScript("OnEvent", function()
    if pending then return end
    pending = true
    C_Timer.After(0.3, function()
        pending = nil
        Rebuild()
        RepaintAll()
    end)
end)

JQ.byKey[KEY].onEnable = function() Rebuild(); RepaintAll() end
JQ.byKey[KEY].onDisable = function() RepaintAll() end

-- for tests
JQ._QuestItemGuard = { Rebuild = Rebuild, Needed = Needed, Parse = ParseObjective, Paint = Paint }
