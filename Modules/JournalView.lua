-------------------------------------------------------------------------------
--  JaseTools: Dungeon Journal (new view)
--
--  A lighter, list-based window over ForeverDungeonJournal's own data
--  (FDJ.DB / FDJ.ORDER). It never edits that addon; it reads its tables and
--  swaps its window for this one. "Classic view" opens the original.
--
--  Layout
--    title bar   : title, search (dungeons, bosses, items, quests), Classic view, close
--    sidebar     : dungeons with level range coloured for you + quests done
--    header      : icon, name, level / location, description, Map button
--    tabs        : Bosses | Loot | Quests, with filter chips on the right
--    content     : one virtual list (rows are pooled and only the visible ones
--                  exist), so long loot / quest pages stay cheap.
--
--  Updates: quest log / bag changes only re-render the visible rows, and only
--  while the window is open. Last dungeon, tab, filters, size and position are
--  saved in JaseQoLDB.journal.
-------------------------------------------------------------------------------
local _, JQ = ...
local KEY = "djOverhaul"

JQ.AddModule({
    key = KEY,
    label = "Dungeon Journal: new view",
    description = "Opens a cleaner list-based Dungeon Journal (bosses, loot grid, quest status, filters, search) instead of the original window. The original stays one click away (Classic view). /jdj opens it.",
    default = true,
})

local FDJ                       -- ForeverDungeonJournal namespace
local S                         -- EllesmereUI skin facade (optional)
local win                       -- main window, built on first open
local state                     -- JaseQoLDB.journal
local allowClassic = false      -- true while the user asked for the old window

local WHITE = "Interface\\Buttons\\WHITE8X8"
local BOSS_ICON = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01"
local TRASH_ICON = "Interface\\Icons\\INV_Misc_Bag_10"
local QUEST_ICON = "Interface\\GossipFrame\\AvailableQuestIcon"
local MISSING_ICON = 134400

-------------------------------------------------------------------------------
--  Look
-------------------------------------------------------------------------------
local function Accent()
    local c = EllesmereUI and EllesmereUI.ELLESMERE_GREEN
    if c and c.r then return c.r, c.g, c.b end
    return 0.047, 0.824, 0.616
end

local C_BG      = { 0.045, 0.045, 0.05, 0.96 }
local C_PANEL   = { 0.075, 0.075, 0.08, 0.95 }
local C_ROW     = { 1, 1, 1, 0.035 }
local C_HOVER   = { 1, 1, 1, 0.08 }
local C_MUTED   = { 0.62, 0.62, 0.66 }

local function SetF(fs, size, flags)
    local path, fl = STANDARD_TEXT_FONT, ""
    if S and S.GetFont then
        local p, f = S.GetFont()
        if p then path, fl = p, f or "" end
    end
    fs:SetFont(path, size or 12, flags or fl)
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.8)
end

local function Text(parent, size, r, g, b, justify, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    SetF(fs, size)
    fs:SetTextColor(r or 1, g or 1, b or 1)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function Fill(parent, c, layer, sub)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
    t:SetTexture(WHITE)
    t:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
    t:SetAllPoints()
    return t
end

local function Border(frame, a)
    local function edge()
        local t = frame:CreateTexture(nil, "BORDER", nil, 7)
        t:SetColorTexture(0, 0, 0, a or 1)
        return t
    end
    local t, b, l, r = edge(), edge(), edge(), edge()
    t:SetPoint("TOPLEFT"); t:SetPoint("TOPRIGHT"); t:SetHeight(1)
    b:SetPoint("BOTTOMLEFT"); b:SetPoint("BOTTOMRIGHT"); b:SetHeight(1)
    l:SetPoint("TOPLEFT"); l:SetPoint("BOTTOMLEFT"); l:SetWidth(1)
    r:SetPoint("TOPRIGHT"); r:SetPoint("BOTTOMRIGHT"); r:SetWidth(1)
end

-- Flat button: dark plate, white hover, optional "on" state in the accent.
local function FlatButton(parent, label, w, h)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w or 90, h or 22)
    b.bg = Fill(b, { 1, 1, 1, 0.06 })
    b.hl = Fill(b, C_HOVER, "HIGHLIGHT")
    Border(b)
    b.text = Text(b, 11, 0.9, 0.9, 0.9, "CENTER")
    b.text:SetPoint("LEFT", 6, 0); b.text:SetPoint("RIGHT", -6, 0)
    b.text:SetText(label or "")
    function b:SetOn(on)
        self.on = on
        if on then
            local r, g, bb = Accent()
            self.bg:SetVertexColor(r, g, bb, 0.22)
            self.text:SetTextColor(r, g, bb)
        else
            self.bg:SetVertexColor(1, 1, 1, 0.06)
            self.text:SetTextColor(0.9, 0.9, 0.9)
        end
    end
    return b
end

-------------------------------------------------------------------------------
--  Data helpers
-------------------------------------------------------------------------------
local GetItemCountFn = (C_Item and C_Item.GetItemCount) or GetItemCount
local GetItemInfoFn = (C_Item and C_Item.GetItemInfo) or GetItemInfo

local function ItemIcon(id)
    if C_Item and C_Item.GetItemIconByID then
        local i = C_Item.GetItemIconByID(id)
        if i then return i end
    end
    local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if instant then
        local icon = select(5, instant(id))
        if icon then return icon end
    end
    return MISSING_ICON
end

local function QualityColor(q)
    q = q or 1
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c then return c.r, c.g, c.b end
    if C_Item and C_Item.GetItemQualityColor then
        local r, g, b = C_Item.GetItemQualityColor(q)
        if r then return r, g, b end
    end
    return 1, 1, 1
end

local function Owned(id)
    if not GetItemCountFn then return false end
    local ok, n = pcall(GetItemCountFn, id, true)
    return ok and type(n) == "number" and n > 0
end

local function PlayerLevel()
    return UnitLevel("player") or 1
end

local function LevelColor(lvl)
    if type(lvl) == "number" and GetQuestDifficultyColor then
        local c = GetQuestDifficultyColor(lvl)
        if c and c.r then return c.r, c.g, c.b end
    end
    return 1, 0.82, 0
end

local function ParseRange(s)
    local lo, hi = tostring(s or ""):match("(%d+)%s*%-%s*(%d+)")
    return tonumber(lo), tonumber(hi)
end

-- Classic proficiencies, for the "Usable by me" chip. Non-gear (recipes,
-- reagents, quest items...) always passes.
local ARMOR = {
    Cloth = true, Leather = { WARRIOR = 1, PALADIN = 1, HUNTER = 1, ROGUE = 1, SHAMAN = 1, DRUID = 1 },
    Mail = { WARRIOR = 1, PALADIN = 1, HUNTER = 40, SHAMAN = 40 },
    Plate = { WARRIOR = 40, PALADIN = 40 },
}
local W_ALL = { "1H Sword", "2H Sword", "1H Axe", "2H Axe", "1H Mace", "2H Mace", "Dagger",
    "Fist Weapon", "Polearm", "Staff", "Bow", "Crossbow", "Gun", "Thrown" }
local WEAPONS = {
    PALADIN = { "1H Sword", "2H Sword", "1H Axe", "2H Axe", "1H Mace", "2H Mace", "Polearm", "Shield" },
    HUNTER  = { "1H Sword", "2H Sword", "1H Axe", "2H Axe", "Dagger", "Fist Weapon", "Polearm", "Staff", "Bow", "Crossbow", "Gun", "Thrown" },
    ROGUE   = { "1H Sword", "1H Mace", "Dagger", "Fist Weapon", "Bow", "Crossbow", "Gun", "Thrown" },
    PRIEST  = { "1H Mace", "Dagger", "Staff", "Wand" },
    SHAMAN  = { "1H Axe", "2H Axe", "1H Mace", "2H Mace", "Dagger", "Fist Weapon", "Staff", "Shield" },
    MAGE    = { "1H Sword", "Dagger", "Staff", "Wand" },
    WARLOCK = { "1H Sword", "Dagger", "Staff", "Wand" },
    DRUID   = { "1H Mace", "2H Mace", "Dagger", "Fist Weapon", "Staff", "Polearm" },
    WARRIOR = W_ALL,
}
local RELIC = { Totem = "SHAMAN", Libram = "PALADIN", Idol = "DRUID" }
local GEAR_SLOTS = { Head = 1, Shoulder = 1, Chest = 1, Waist = 1, Legs = 1, Feet = 1, Wrist = 1, Hands = 1 }
local HANDS = { ["One-Hand"] = "1H", ["Main Hand"] = "1H", ["Off Hand"] = "1H", ["Two-Hand"] = "2H" }

local weaponSet
local function CanUse(slotText)
    local _, class = UnitClass("player")
    if not class then return true end
    if not weaponSet then
        weaponSet = {}
        for _, w in ipairs(WEAPONS[class] or W_ALL) do weaponSet[w] = true end
        if class == "WARRIOR" then weaponSet.Shield = true end
    end
    local slot, sub = tostring(slotText or ""):match("^([^,]+),%s*(.+)$")
    slot = slot or slotText
    if GEAR_SLOTS[slot] and sub then
        local rule = ARMOR[sub]
        if rule == true or rule == nil then return true end
        local need = rule[class]
        return need ~= nil and PlayerLevel() >= need
    end
    if slot == "Relic" and sub then return RELIC[sub] == class end
    if slot == "Ranged" and sub then return weaponSet[sub] or false end
    if slot == "Thrown" then return weaponSet.Thrown or false end
    if sub == "Shield" then return weaponSet.Shield or false end
    local hand = HANDS[slot]
    if hand and sub then
        if sub == "Sword" or sub == "Axe" or sub == "Mace" then
            return weaponSet[hand .. " " .. sub] or false
        end
        return weaponSet[sub] or false
    end
    return true
end

local function QuestInLog(id)
    if FDJ.IsQuestInLog then
        local ok, v = pcall(FDJ.IsQuestInLog, id)
        if ok then return v and true or false end
    end
    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        local i = C_QuestLog.GetLogIndexForQuestID(id)
        return i ~= nil and i > 0
    end
    if GetQuestLogIndexByID then return (GetQuestLogIndexByID(id) or 0) > 0 end
    return false
end

local function QuestDone(id)
    -- The journal's own check also knows its hand-made steps (e.g. holding
    -- the Sacred Mallet counts as that step done).
    if FDJ.QuestTurnedIn then
        local ok, v = pcall(FDJ.QuestTurnedIn, id)
        if ok then return v and true or false end
    end
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        return C_QuestLog.IsQuestFlaggedCompleted(id) and true or false
    end
    if IsQuestFlaggedCompleted then return IsQuestFlaggedCompleted(id) and true or false end
    return false
end

-- Live objective text for a quest in your log ("Uncracked Scarab Shell: 0/5"),
-- finished objectives in green. nil when not in the log / no objectives.
local function QuestProgress(id)
    if not (id and C_QuestLog and C_QuestLog.GetQuestObjectives) then return nil end
    local ok, objs = pcall(C_QuestLog.GetQuestObjectives, id)
    if not ok or type(objs) ~= "table" or #objs == 0 then return nil end
    local parts = {}
    for _, o in ipairs(objs) do
        if type(o.text) == "string" and o.text ~= "" then
            parts[#parts + 1] = (o.finished and "|cff59d959" or "|cffd8d8dc") .. o.text .. "|r"
        end
    end
    return #parts > 0 and table.concat(parts, "  •  ") or nil
end

local questIndex
local function QuestByID(id)
    if not questIndex then
        questIndex = {}
        for _, page in pairs(FDJ.DB) do
            if type(page) == "table" then
                for _, q in ipairs(page.quests or {}) do
                    if q.id and not questIndex[q.id] then questIndex[q.id] = q end
                end
            end
        end
    end
    return questIndex[id]
end

-- Step details: the journal's prerequisite notes, filled in from the full
-- quest when the step is a quest it lists somewhere (items, maps, warning).
local function StepDet(id)
    local det = FDJ.QUEST_PREREQ_DETAILS and FDJ.QUEST_PREREQ_DETAILS[id]
    local fq = QuestByID(id)
    if not fq then return det end
    local out = {}
    for k, v in pairs(fq) do out[k] = v end
    out.map = (FDJ.QUEST_START_MAPS and FDJ.QUEST_START_MAPS[id]) or fq.startMap
    for k, v in pairs(det or {}) do out[k] = v end
    return out
end

-- Side chains the journal keeps on pages of their own (questChainPage with a
-- parentDungeon + parentBoss, e.g. "Mallet of Zul'Farrak", which summons
-- Gahz'rilla). They are prerequisites of the dungeon quest for that boss, so
-- their steps are folded into that quest's chain instead of being listed as
-- quests. sideSteps[questID] = { step, ... } (each with .det and .summon).
local sideSteps
local function SideDet(pq)
    return {
        objective = pq.objective, pickup = pq.pickup, turnin = pq.turnin, note = pq.note,
        map = pq.startMap, providedItem = pq.rewardItems and pq.rewardItems[1],
    }
end

local function EnsureSideSteps()
    if sideSteps then return end
    sideSteps = {}
    for pageName, page in pairs(FDJ.DB) do
        local parent = type(page) == "table" and page.questChainPage and page.parentDungeon and FDJ.DB[page.parentDungeon]
        local boss = parent and page.parentBoss
        if boss then
            local target
            for _, q in ipairs(parent.quests or {}) do
                if q.name == boss then target = q; break end
            end
            if not target then
                for _, q in ipairs(parent.quests or {}) do
                    if q.objective and q.objective:find(boss, 1, true) then target = q; break end
                end
            end
            if target and target.id then
                local list = sideSteps[target.id] or {}
                for _, pq in ipairs(page.quests or {}) do
                    for _, st in ipairs((FDJ.QUEST_PREREQ_CHAINS and FDJ.QUEST_PREREQ_CHAINS[pq.id]) or {}) do
                        list[#list + 1] = { id = st.id, name = st.name, summon = true, page = pageName,
                            det = StepDet(st.id) }
                    end
                    list[#list + 1] = { id = pq.id, name = pq.name, summon = true, page = pageName, det = SideDet(pq) }
                end
                sideSteps[target.id] = list
            end
        end
    end
end

-- Real prerequisites first, then side-chain steps; nil when there are none.
local function FullChain(q)
    if not q.id then return nil end
    EnsureSideSteps()
    local real = FDJ.QUEST_PREREQ_CHAINS and FDJ.QUEST_PREREQ_CHAINS[q.id]
    local side = sideSteps[q.id]
    if not real and not side then return nil end
    local out = {}
    for _, st in ipairs(real or {}) do
        out[#out + 1] = { id = st.id, name = st.name, det = StepDet(st.id) }
    end
    for _, st in ipairs(side or {}) do out[#out + 1] = st end
    return #out > 0 and out or nil
end

-- Chain status: steps done, total, the first step not done (+ in your log?),
-- and whether a real prerequisite is still open (side-chain steps such as the
-- Mallet don't stop you picking the quest up, so they never lock it).
local function ChainStatus(q)
    local chain = FullChain(q)
    if not chain then return nil end
    local nDone, nextIdx, locked = 0, nil, false
    for i, step in ipairs(chain) do
        if QuestDone(step.id) then
            nDone = nDone + 1
        else
            if not nextIdx then nextIdx = i end
            if not step.summon then locked = true end
        end
    end
    local nextStep = nextIdx and chain[nextIdx]
    return nDone, #chain, nextStep, nextIdx, nextStep and QuestInLog(nextStep.id), locked
end

-- "done" | "log" | "locked" | "available" | "low" | nil (not for this character)
local function QuestState(q)
    local faction = UnitFactionGroup("player")
    if q.faction and q.faction ~= "Both" and faction and q.faction ~= faction then
        return state and state.bothFactions and "faction" or nil
    end
    if FDJ.QuestCountsForCharacter and not FDJ.QuestCountsForCharacter(q) then return nil end
    if q.id and QuestDone(q.id) then return "done" end
    if q.id and QuestInLog(q.id) then return "log" end
    local nDone, _, _, _, _, locked = ChainStatus(q)
    if nDone and locked then return "locked" end
    if q.requires and PlayerLevel() < q.requires then return "low" end
    return "available"
end

local STATE_LABEL = {
    done = { "Done", 0.35, 0.85, 0.35 },
    log = { "In log", 1.00, 0.82, 0.20 },
    locked = { "Chain", 1.00, 0.60, 0.25 },
    faction = { "Other faction", 0.55, 0.55, 0.58 },
    available = { "Available", 0.90, 0.90, 0.90 },
    low = { "Too low", 0.55, 0.55, 0.58 },
}

-- Side-chain pages the journal adds (e.g. "Mallet of Zul'Farrak", which
-- summons Gahz'rilla): pages with questChainPage + parentDungeon. Their quests
-- are listed under the parent dungeon, tagged with the page name.
local sideChains
local function SideChainsFor(dungeonName)
    if not sideChains then
        sideChains = {}
        for pageName, page in pairs(FDJ.DB) do
            if type(page) == "table" and page.questChainPage and page.parentDungeon then
                local list = sideChains[page.parentDungeon] or {}
                list[#list + 1] = { name = pageName, page = page }
                sideChains[page.parentDungeon] = list
            end
        end
    end
    return sideChains[dungeonName]
end

local function QuestsFor(d, dungeonName)
    local out, done = {}, 0
    local function add(q, side)
        if q.hideFromMainList then return end   -- shown inside the quest that links it
        local st = QuestState(q)
        if st then
            out[#out + 1] = { q = q, state = st, side = side }
            if st == "done" then done = done + 1 end
        end
    end
    for _, q in ipairs(d.quests or {}) do add(q) end
    return out, done
end

-------------------------------------------------------------------------------
--  Party check: the game says who has a quest in their log; party members who
--  run JaseTools too answer with done / in log / not started (addon messages).
-------------------------------------------------------------------------------
local PARTY_PREFIX = "JaseQoL"
local party = {}            -- [first name] = { [questID] = "d" | "l" | "n" }
local partyAskedAt = 0
local PartyRefresh          -- set by the window (redraw after answers)
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    pcall(C_ChatInfo.RegisterAddonMessagePrefix, PARTY_PREFIX)
end

local function FirstName(n) return n and (tostring(n):gsub("%-.*$", ""):match("^(%S+)")) end

local function PartyMembers()
    local out = {}
    if not IsInGroup or not IsInGroup() then return out end
    for i = 1, (GetNumSubgroupMembers and GetNumSubgroupMembers() or 0) do
        local unit = "party" .. i
        local name = UnitName(unit)
        if name then out[#out + 1] = { unit = unit, name = FirstName(name) } end
    end
    return out
end

local function PartySend(msg)
    if not (IsInGroup and IsInGroup() and C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
    pcall(C_ChatInfo.SendAddonMessage, PARTY_PREFIX, msg, (IsInRaid and IsInRaid()) and "RAID" or "PARTY")
end

-- "Q?" / "Q=" + comma list, split under the 255-byte message limit
local function PartySendList(tag, items)
    local buf = tag
    for _, it in ipairs(items) do
        if #buf + #it + 1 > 240 then PartySend(buf); buf = tag end
        buf = buf .. (buf == tag and "" or ",") .. it
    end
    if buf ~= tag then PartySend(buf) end
end

local QuestDone, QuestInLog = QuestDone, QuestInLog

-- state for a party member: "d" / "l" / "n", or nil when unknown; known = from JaseTools
local function PartyState(m, id)
    local t = party[m.name]
    if t and t[id] then return t[id], true end
    if m.unit and C_QuestLog and C_QuestLog.IsUnitOnQuest then
        local ok, v = pcall(C_QuestLog.IsUnitOnQuest, m.unit, id)
        if ok and v then return "l", false end
    end
    return nil, false
end

local function PartyAsk(ids)
    if #PartyMembers() == 0 then return false end
    local list = {}
    for _, id in ipairs(ids) do if id and id > 0 then list[#list + 1] = tostring(id) end end
    if #list == 0 then return false end
    partyAskedAt = GetTime()
    PartySendList("Q?", list)
    return true
end

local partyEv = CreateFrame("Frame")
partyEv:RegisterEvent("CHAT_MSG_ADDON")
partyEv:SetScript("OnEvent", function(_, _, prefix, msg, _, sender)
    if prefix ~= PARTY_PREFIX or type(msg) ~= "string" then return end
    local who = FirstName(Ambiguate and Ambiguate(sender or "", "short") or sender)
    if not who or who == FirstName(UnitName("player")) then return end
    local tag, body = msg:sub(1, 2), msg:sub(3)
    if tag == "Q?" then
        if not (FDJ and QuestDone) then return end
        local out = {}
        for id in body:gmatch("%-?%d+") do
            id = tonumber(id)
            local st = QuestDone(id) and "d" or (QuestInLog(id) and "l" or "n")
            out[#out + 1] = id .. ":" .. st
        end
        PartySendList("Q=", out)
    elseif tag == "Q=" then
        party[who] = party[who] or {}
        for id, st in body:gmatch("(%-?%d+):(%a)") do party[who][tonumber(id)] = st end
        if PartyRefresh then PartyRefresh() end
    end
end)

local STATE_HEX = { d = "59d959", l = "ffd233", n = "7f7f85" }
-- "Bob Sue Tim" coloured by state for one quest
local function PartyNames(id)
    local parts = {}
    for _, m in ipairs(PartyMembers()) do
        local st = PartyState(m, id)
        parts[#parts + 1] = ("|cff%s%s|r"):format(st and STATE_HEX[st] or "ffffff", m.name)
    end
    return table.concat(parts, " ")
end

-- Quest by id across a dungeon (main list + hidden + side chains).
local function FindQuest(d, dungeonName, id)
    for _, q in ipairs(d.quests or {}) do if q.id == id then return q end end
    for _, sc in ipairs(dungeonName and SideChainsFor(dungeonName) or {}) do
        for _, q in ipairs(sc.page.quests or {}) do if q.id == id then return q end end
    end
end

-- Puts a pin on the world map (and the journal's waypoint arrow) through the
-- journal's own marker system, so pins behave exactly like the original's.
local function ShowOnMap(loc, text, questID, title, turnIn)
    if not (loc and FDJ.MapMarkers and FDJ.MapMarkers.ShowRecordedLocationOnMap) then return end
    FDJ.pendingMarkerQuestTitle = title
    FDJ.pendingMarkerQuestID = questID
    FDJ.pendingMarkerTurnIn = turnIn or nil
    pcall(FDJ.MapMarkers.ShowRecordedLocationOnMap, loc, text)
end

-- Lower-case search index per dungeon (names of dungeon, bosses, items, quests).
local searchIndex = {}
local function IndexFor(name)
    local idx = searchIndex[name]
    if idx then return idx end
    idx = { name:lower() }
    local d = FDJ.DB[name]
    for _, b in ipairs(d.bosses or {}) do
        idx[#idx + 1] = (b.name or ""):lower()
        for _, it in ipairs(b.loot or {}) do idx[#idx + 1] = (it[2] or ""):lower() end
    end
    for _, q in ipairs(d.quests or {}) do idx[#idx + 1] = (q.name or ""):lower() end
    searchIndex[name] = idx
    return idx
end

local function SearchHits(name, needle)
    if needle == "" then return 0 end
    local n = 0
    for _, s in ipairs(IndexFor(name)) do
        if s:find(needle, 1, true) then n = n + 1 end
    end
    return n
end

local function Match(s, needle)
    return needle == "" or (s or ""):lower():find(needle, 1, true) ~= nil
end

-------------------------------------------------------------------------------
--  Tooltips and item clicks
-------------------------------------------------------------------------------
local function ItemEnter(self)
    if not self.itemID then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(self.itemID)
    if self.source then
        GameTooltip:AddLine("Drops from: " .. self.source, 0.62, 0.62, 0.66)
    end
    GameTooltip:Show()
end

local function ItemClick(self)
    if not self.itemID then return end
    local _, link = GetItemInfoFn(self.itemID)
    if not link then return end
    if IsModifiedClick("CHATLINK") then
        ChatEdit_InsertLink(link)
    elseif IsModifiedClick("DRESSUP") and DressUpItemLink then
        DressUpItemLink(link)
    end
end

local function HideTip() GameTooltip:Hide() end

-------------------------------------------------------------------------------
--  Virtual list: items = { {kind=, height=, data=}, ... }. Only rows inside
--  the visible window exist; they come from per-kind pools.
-------------------------------------------------------------------------------
local function NewList(parent, kinds)
    local L = CreateFrame("Frame", nil, parent)
    L:SetClipsChildren(true)
    L.kinds = kinds
    L.items, L.offsets, L.total, L.scroll = {}, {}, 0, 0
    L.free, L.used = {}, {}

    local bar = CreateFrame("Slider", nil, L)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(6)
    bar:SetPoint("TOPRIGHT", 0, -2)
    bar:SetPoint("BOTTOMRIGHT", 0, 2)
    local thumb = bar:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(1, 1, 1, 0.3)
    thumb:SetSize(4, 40)
    bar:SetThumbTexture(thumb)
    bar:SetMinMaxValues(0, 0)
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(false)
    L.bar, L.thumb = bar, thumb

    function L:MaxScroll()
        return math.max(0, self.total - self:GetHeight())
    end

    function L:SetScroll(v, fromBar)
        v = math.max(0, math.min(v or 0, self:MaxScroll()))
        self.scroll = v
        if not fromBar then
            self.settingBar = true
            bar:SetValue(v)
            self.settingBar = nil
        end
        self:Render()
    end

    bar:SetScript("OnValueChanged", function(_, v)
        if not L.settingBar then L:SetScroll(v, true) end
    end)
    L:EnableMouseWheel(true)
    L:SetScript("OnMouseWheel", function(self, delta)
        self:SetScroll(self.scroll - delta * 70)
    end)

    function L:SetItems(items, keepScroll)
        self.items = items
        local y = 0
        for i, it in ipairs(items) do
            self.offsets[i] = y
            y = y + it.height
        end
        for i = #items + 1, #self.offsets do self.offsets[i] = nil end
        self.total = y
        local h = self:GetHeight()
        local maxS = self:MaxScroll()
        bar:SetMinMaxValues(0, maxS)
        bar:SetShown(maxS > 0)
        if h > 0 and y > 0 then thumb:SetHeight(math.max(24, h * h / y)) end
        self:SetScroll(keepScroll and self.scroll or 0)
    end

    function L:Release()
        for row in pairs(self.used) do
            row:Hide()
            row:ClearAllPoints()
            local pool = self.free[row.kind]
            pool[#pool + 1] = row
        end
        wipe(self.used)
    end

    function L:Acquire(kind)
        self.free[kind] = self.free[kind] or {}
        local pool = self.free[kind]
        local row = table.remove(pool)
        if not row then
            row = self.kinds[kind].create(self)
            row.kind = kind
        end
        self.used[row] = true
        return row
    end

    function L:Render()
        self:Release()
        local items, offs = self.items, self.offsets
        local n = #items
        if n == 0 then return end
        local top, bottom = self.scroll, self.scroll + self:GetHeight()
        -- binary search for the first row ending below the top edge
        local lo, hi = 1, n
        while lo < hi do
            local mid = math.floor((lo + hi) / 2)
            if offs[mid] + items[mid].height <= top then lo = mid + 1 else hi = mid end
        end
        local rightPad = bar:IsShown() and 10 or 0
        for i = lo, n do
            local y = offs[i]
            if y >= bottom then break end
            local it = items[i]
            local row = self:Acquire(it.kind)
            row:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(y - top))
            row:SetPoint("RIGHT", self, "RIGHT", -rightPad, 0)
            row:SetHeight(it.height)
            self.kinds[it.kind].update(row, it.data, self)
            row:Show()
        end
    end

    L:SetScript("OnSizeChanged", function(self)
        if self.onResize then self.onResize(self) else self:SetItems(self.items, true) end
    end)
    return L
end

-------------------------------------------------------------------------------
--  Row kinds
-------------------------------------------------------------------------------
local Refresh          -- forward: Refresh(what)
local SelectDungeon, SelectTab

local function RowBase(L, height)
    local row = CreateFrame("Button", nil, L)
    row:SetHeight(height)
    row.bg = Fill(row, C_ROW)
    row.hl = Fill(row, C_HOVER, "HIGHLIGHT")
    return row
end

-- Sidebar: one dungeon
local DungeonRow = {
    -- Name + level range on top; quest progress under it ("4/9 quests",
    -- "3 in log"), and a thin bar along the bottom filled by quests done.
    create = function(L)
        local row = RowBase(L, 40)
        row.bar = row:CreateTexture(nil, "ARTWORK")
        row.bar:SetColorTexture(Accent())
        row.bar:SetPoint("TOPLEFT"); row.bar:SetPoint("BOTTOMLEFT"); row.bar:SetWidth(2)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(24, 24)
        row.icon:SetPoint("LEFT", 8, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.right = Text(row, 10, 0.7, 0.7, 0.7, "RIGHT")
        row.right:SetPoint("TOPRIGHT", -8, -6)
        row.name = Text(row, 12)
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 1)
        row.name:SetPoint("RIGHT", row.right, "LEFT", -6, 0)
        row.prog = Text(row, 10, C_MUTED[1], C_MUTED[2], C_MUTED[3])
        row.prog:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, -1)
        row.prog:SetPoint("RIGHT", -8, 0)
        row.track = row:CreateTexture(nil, "ARTWORK")
        row.track:SetColorTexture(1, 1, 1, 0.06)
        row.track:SetPoint("BOTTOMLEFT", 40, 3)
        row.track:SetPoint("BOTTOMRIGHT", -8, 3)
        row.track:SetHeight(2)
        row.fill = row:CreateTexture(nil, "OVERLAY")
        row.fill:SetPoint("TOPLEFT", row.track)
        row.fill:SetPoint("BOTTOMLEFT", row.track)
        row:SetScript("OnClick", function(self) SelectDungeon(self.dungeon) end)
        return row
    end,
    update = function(row, data, L)
        row.dungeon = data.name
        local sel = data.name == state.dungeon
        row.bar:SetShown(sel)
        row.bar:SetColorTexture(Accent())
        row.bg:SetVertexColor(1, 1, 1, sel and 0.10 or 0.0)
        row.icon:SetTexture(data.d.icon or BOSS_ICON)
        row.name:SetText(data.name)
        row.name:SetTextColor(sel and 1 or 0.88, sel and 1 or 0.88, sel and 1 or 0.88)
        if data.hits and data.hits > 0 then
            local r, g, b = Accent()
            row.right:SetText(data.hits .. " match" .. (data.hits > 1 and "es" or ""))
            row.right:SetTextColor(r, g, b)
        else
            local lo, hi = ParseRange(data.d.level)
            row.right:SetText(data.d.level or "")
            if lo and hi then
                row.right:SetTextColor(LevelColor(math.floor((lo + hi) / 2)))
            else
                row.right:SetTextColor(0.7, 0.7, 0.7)
            end
        end

        -- Quest progress for this character.
        local list, done = QuestsFor(data.d, data.name)
        local total, inLog = #list, 0
        for _, e in ipairs(list) do
            if e.state == "log" then inLog = inLog + 1 end
        end
        local r, g, b = Accent()
        if total == 0 then
            row.prog:SetText("No quests")
            row.track:Hide(); row.fill:Hide()
        else
            local txt
            if done == total then
                txt = "|cff59d959All " .. total .. " quests done|r"
            else
                txt = done .. "/" .. total .. " quests"
                if inLog > 0 then txt = txt .. "  •  |cffffd233" .. inLog .. " in log|r" end
            end
            row.prog:SetText(txt)
            row.track:Show()
            local w = (L:GetWidth() - (L.bar:IsShown() and 10 or 0)) - 48
            if done > 0 and w > 0 then
                row.fill:SetWidth(math.max(1, w * done / total))
                if done == total then row.fill:SetColorTexture(0.35, 0.85, 0.35, 0.9)
                else row.fill:SetColorTexture(r, g, b, 0.9) end
                row.fill:Show()
            else
                row.fill:Hide()
            end
        end
    end,
}

-- Content: boss row
local BossRow = {
    create = function(L)
        local row = RowBase(L, 46)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(34, 34)
        row.icon:SetPoint("LEFT", 8, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.name = Text(row, 13)
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, -2)
        row.sub = Text(row, 11, C_MUTED[1], C_MUTED[2], C_MUTED[3])
        row.sub:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 10, 2)
        row.sub:SetPoint("RIGHT", -150, 0)
        row.right = Text(row, 11, 0.8, 0.8, 0.8, "RIGHT")
        row.right:SetPoint("RIGHT", -12, 0)
        -- "Summon with" item (e.g. Gahz'rilla's Mallet of Zul'Farrak): tooltip,
        -- and a click opens the quest chain that gets it.
        row.summon = FlatButton(row, "", 170, 22)
        row.summon:SetPoint("RIGHT", row.right, "LEFT", -12, 0)
        row.summon:SetScript("OnEnter", ItemEnter)
        row.summon:SetScript("OnLeave", HideTip)
        row.summon:SetScript("OnClick", function(self)
            if IsModifiedClick("CHATLINK") then return ItemClick(self) end
            local sc = self.chain
            if not sc then return end
            EnsureSideSteps()
            local target
            for qid, steps in pairs(sideSteps) do
                for _, st in ipairs(steps) do
                    if st.page == sc.page then target = qid end
                end
            end
            if target then
                state.openQuests[target] = true
                state.scrollTo = target
                SelectTab("quests")
            end
        end)
        row:SetScript("OnClick", function(self)
            state.boss = self.bossName
            SelectTab("loot")
        end)
        return row
    end,
    update = function(row, data)
        local b = data.boss
        row.bossName = b.name
        row.icon:SetTexture(b.customIcon or (b.trash and TRASH_ICON) or BOSS_ICON)
        local tags = ""
        if b.rare then tags = tags .. "  |cffc0a0ffRARE|r" end
        if b.factionOnly then tags = tags .. "  |cffff7070" .. b.factionOnly:upper() .. " ONLY|r" end
        row.name:SetText((b.name or "?") .. tags)
        row.sub:SetText(b.description or (b.trash and "Drops from trash in this dungeon" or ""))
        local n, own = 0, 0
        for _, it in ipairs(b.loot or {}) do
            n = n + 1
            if Owned(it[1]) then own = own + 1 end
        end
        row.right:SetText(n .. " items" .. (own > 0 and ("  •  |cff59d959" .. own .. " owned|r") or "") .. "   ›")
        if b.summonItem then
            local name = GetItemInfoFn(b.summonItem)
            if not name and b.summonChain then
                local page = FDJ.DB[b.summonChain.page]
                for _, q in ipairs(page and page.quests or {}) do
                    for _, it in ipairs(q.rewardItems or {}) do
                        if it[1] == b.summonItem then name = it[2] end
                    end
                end
            end
            name = name or "summon item"
            row.summon.itemID = b.summonItem
            row.summon.source = nil
            row.summon.chain = b.summonChain
            local have = Owned(b.summonItem)
            row.summon.text:SetText((have and "|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t " or "") .. "Summon: " .. name .. (b.summonChain and "  ›" or ""))
            row.summon:SetWidth(math.min(240, row.summon.text:GetStringWidth() + 20))
            row.summon:SetOn(have)
            row.summon:Show()
            if not b.description then row.sub:SetText("Summoned with " .. name) end
            row.sub:SetPoint("RIGHT", row.summon, "LEFT", -8, 0)
        else
            row.summon:Hide()
            row.sub:SetPoint("RIGHT", -150, 0)
        end
    end,
}

-- Content: section header (boss name over its loot)
local HeaderRow = {
    create = function(L)
        local row = CreateFrame("Frame", nil, L)
        row.text = Text(row, 12, 1, 1, 1)
        row.text:SetPoint("BOTTOMLEFT", 4, 6)
        row.line = row:CreateTexture(nil, "ARTWORK")
        row.line:SetColorTexture(1, 1, 1, 0.08)
        row.line:SetPoint("BOTTOMLEFT", 0, 2); row.line:SetPoint("BOTTOMRIGHT", 0, 2); row.line:SetHeight(1)
        return row
    end,
    update = function(row, data)
        local r, g, b = Accent()
        row.text:SetText(data.text)
        row.text:SetTextColor(r, g, b)
    end,
}

-- Content: a row of item cards (the loot grid)
local CARD_W, CARD_GAP = 230, 6
local function MakeCard(row)
    local c = CreateFrame("Button", nil, row)
    c.bg = Fill(c, C_ROW)
    c.hl = Fill(c, C_HOVER, "HIGHLIGHT")
    c.iconBorder = c:CreateTexture(nil, "ARTWORK", nil, 0)
    c.iconBorder:SetSize(34, 34)
    c.iconBorder:SetPoint("LEFT", 5, 0)
    c.icon = c:CreateTexture(nil, "ARTWORK", nil, 1)
    c.icon:SetPoint("TOPLEFT", c.iconBorder, 1, -1)
    c.icon:SetPoint("BOTTOMRIGHT", c.iconBorder, -1, 1)
    c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    c.check = c:CreateTexture(nil, "OVERLAY")
    c.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    c.check:SetSize(14, 14)
    c.check:SetPoint("BOTTOMRIGHT", c.iconBorder, 4, -4)
    c.name = Text(c, 12)
    c.name:SetPoint("TOPLEFT", c.iconBorder, "TOPRIGHT", 8, -2)
    c.name:SetPoint("RIGHT", -6, 0)
    c.sub = Text(c, 10, C_MUTED[1], C_MUTED[2], C_MUTED[3])
    c.sub:SetPoint("BOTTOMLEFT", c.iconBorder, "BOTTOMRIGHT", 8, 2)
    c.sub:SetPoint("RIGHT", -6, 0)
    c:SetScript("OnEnter", ItemEnter)
    c:SetScript("OnLeave", HideTip)
    c:SetScript("OnClick", ItemClick)
    return c
end

local CardRow = {
    create = function(L)
        local row = CreateFrame("Frame", nil, L)
        row.cards = {}
        return row
    end,
    update = function(row, data, L)
        local cols = data.cols
        local w = (L:GetWidth() - (L.bar:IsShown() and 10 or 0) - CARD_GAP * (cols - 1)) / cols
        for i = 1, math.max(cols, #row.cards) do
            local entry = data.items[i]
            local c = row.cards[i]
            if entry then
                if not c then c = MakeCard(row); row.cards[i] = c end
                local it = entry.item
                c:ClearAllPoints()
                c:SetPoint("TOPLEFT", row, "TOPLEFT", (i - 1) * (w + CARD_GAP), -2)
                c:SetSize(w, 44)
                c.itemID = it[1]
                c.source = entry.boss
                local r, g, b = QualityColor(it[4])
                c.iconBorder:SetColorTexture(r * 0.8, g * 0.8, b * 0.8, 1)
                c.icon:SetTexture(ItemIcon(it[1]))
                c.name:SetText(it[2] or "?")
                c.name:SetTextColor(r, g, b)
                local src = type(it[5]) == "string" and it[5] or nil
                c.sub:SetText(src and ((it[3] or "") .. "  •  " .. src) or (it[3] or ""))
                c.check:SetShown(entry.owned)
                c.icon:SetDesaturated(false)
                c:Show()
            elseif c then
                c:Hide()
            end
        end
    end,
}

-- Content: quest row (click to expand). The expanded part is a stack of
-- "lines": warning, objective, start (+ Show on map), start object / items
-- you need / items you are given (with tooltips and their own map spots),
-- turn-in (+ Show turn-in), the prerequisite chain with a tick per step and
-- the next step's details, an optional intro quest, rewards and notes.
local QUEST_H = 48
local LINE_LEFT, LABEL_W, ICON_W, MAPBTN_W = 38, 74, 20, 104
local measure

local function ItemDesc(it)
    if type(it[4]) == "string" then return it[4] end
    if type(it[5]) == "string" then return it[5] end
end

local function TextWidth(line, rowWidth)
    local w = rowWidth - LINE_LEFT - 12
    if line.label then w = w - LABEL_W end
    if line.icon or line.item or line.step then w = w - ICON_W end
    if line.map or line.action then w = w - MAPBTN_W end
    return math.max(80, w)
end

local function Measure(text, width, size)
    if not measure then
        measure = UIParent:CreateFontString(nil, "BACKGROUND")
        measure:Hide()
        measure:SetWordWrap(true)
        measure:SetJustifyH("LEFT")
    end
    SetF(measure, size or 12)
    measure:SetWidth(width)
    measure:SetText(text)
    return math.ceil(measure:GetStringHeight())
end

-- Colours by kind of line: label colour, and the colour of its plain text.
local LABEL_HEX = {
    ["You need"] = "ffb24d", ["Starts from"] = "ffd25a", ["Given"] = "59d959", ["Gives"] = "59d959",
    ["Note"] = "ffd25a", ["Rewards"] = "59d959", ["Start"] = "8fc8ff", ["Turn in"] = "8fc8ff",
    ["Optional"] = "c0a0ff", ["Summon"] = "ff5a4a", ["Party"] = "8fb8ff", ["Progress"] = "0bd29d",
}
local TEXT_RGB = {
    ["Note"] = { 1, 0.92, 0.66 }, ["Start"] = { 0.74, 0.86, 1 }, ["Turn in"] = { 0.74, 0.86, 1 },
    ["Rewards"] = { 0.68, 0.92, 0.68 }, ["Optional"] = { 0.86, 0.8, 1 },
}
local DESC_HEX = { ["You need"] = "ffcc88", ["Starts from"] = "ffe0a0", ["Given"] = "a8e6a8", ["Gives"] = "a8e6a8" }

-- Reward item names in a rewards line become item links (quality coloured),
-- so hovering one shows its tooltip and shift-click links it in chat.
local function RewardLinks(text, items)
    if type(items) ~= "table" then return text end
    for _, it in ipairs(items) do
        local id, name = it[1], it[2]
        if id and type(name) == "string" and name ~= "" then
            local r, g, b = QualityColor(it[3])
            local link = ("|cff%02x%02x%02x|Hitem:%d|h%s|h|r"):format(r * 255, g * 255, b * 255, id, name)
            local s, e = text:find(name, 1, true)
            if s then text = text:sub(1, s - 1) .. link .. text:sub(e + 1) end
        end
    end
    return text
end

local function LineText(line)
    if line.custom then
        return (line.text or "") .. (line.owned and "  |cff59d959(you have it)|r" or "")
    end
    if line.item then
        local it = line.item
        local r, g, b = QualityColor(it[3])
        local s = ("|cff%02x%02x%02x%s|r"):format(r * 255, g * 255, b * 255, it[2] or "?")
        local desc = ItemDesc(it)
        if desc then s = s .. "  |cff" .. (DESC_HEX[line.label] or "9e9ea8") .. desc .. "|r" end
        return s
    end
    return line.text or ""
end

local function QuestLines(q, dungeonName, d, rowWidth)
    local lines = {}
    local function add(l) lines[#lines + 1] = l end
    local starts = FDJ.QUEST_START_MAPS or {}

    -- A quest boss that has to be summoned first (Gahz'rilla: the Mallet).
    local help = type(q.summonHelp) == "table" and q.summonHelp
    if help then
        local have = help.item and Owned(help.item)
        add({ item = help.item and { help.item, help.itemName or "summon item", 1 } or nil,
              label = "Summon",
              text = ("|cffff5a4a%s has to be summoned: use the %s at the gong by his pool.|r"):format(help.boss or "The boss", help.itemName or "summon item"),
              custom = true, owned = have })
    end
    if q.warning and q.warning ~= "" then add({ text = "|cffff9a3c" .. q.warning .. "|r" }) end
    local prog = QuestInLog(q.id) and QuestProgress(q.id)
    if prog then add({ label = "Progress", text = prog }) end
    if q.id and FDJ.IsQuestShareable and FDJ.IsQuestShareable(q.id) then
        if FDJ.IsQuestShareableNow and FDJ.IsQuestShareableNow(q.id) then
            add({ label = "Party", text = "Share this quest with your group", mapText = "Share",
                  action = function() FDJ.ShareQuestByID(q.id) end })
        else
            add({ label = "Party", text = "|cff9e9ea8Shareable once it's in your quest log|r" })
        end
    end
    if q.objective and q.objective ~= "" then add({ text = q.objective }) end
    if q.pickup then
        add({ label = "Start", text = q.pickup, map = starts[q.id] or q.startMap, mapText = "Show on map",
              qid = q.id, title = q.name })
    end
    if q.startObject then
        local o = q.startObject
        add({ label = "Starts from", icon = o[2], text = (o[1] or "") .. (o[3] and ("  |cff9e9ea8" .. o[3] .. "|r") or "") })
    end
    if q.startItem then add({ label = "Starts from", item = q.startItem, map = q.startItem.map, mapText = "Show on map" }) end
    if q.noteItem then add({ label = "You need", item = q.noteItem, map = q.noteItemMap or q.noteItem.map, mapText = "Show on map" }) end
    if q.requiredItem then add({ label = "You need", item = q.requiredItem, map = q.requiredItem.map, mapText = "Show on map" }) end
    for _, it in ipairs(q.requiredItems or {}) do
        add({ label = "You need", item = it, map = it.map, mapText = "Show on map" })
    end
    if q.providedItem then add({ label = "Given", item = q.providedItem }) end
    if q.turnin then
        add({ label = "Turn in", text = q.turnin, map = q.turninMap, mapText = "Show turn-in",
              qid = q.id, title = q.name, turnIn = true })
    end

    -- Optional intro quest (hidden from the main list, linked from here).
    if q.noteQuestLink and q.noteQuestLink.id then
        local link = q.noteQuestLink
        local lq = FindQuest(d, dungeonName, link.id)
        add({ label = "Optional", step = true, done = QuestDone(link.id),
              text = (link.name or (lq and lq.name) or "?") ..
                  (lq and lq.pickup and ("  |cff9e9ea8" .. lq.pickup .. "|r") or ""),
              map = starts[link.id], mapText = "Show on map", qid = link.id, title = link.name })
    end

    -- Party: where each member is (whole chain when there is one)
    local members = PartyMembers()
    local chainForParty = FullChain(q)
    local at = {}   -- [step index] = { names }
    if #members > 0 then
        local ids = {}
        for _, st in ipairs(chainForParty or {}) do ids[#ids + 1] = st.id end
        ids[#ids + 1] = q.id
        local parts = {}
        for _, m in ipairs(members) do
            local where, col = nil, "ffffff"
            local allKnown = true
            for i, id in ipairs(ids) do
                local st, known = PartyState(m, id)
                if not known then allKnown = false end
                if st == "l" then
                    where, col = (#ids > 1 and ("in log, step %d of %d"):format(i, #ids) or "in log"), STATE_HEX.l
                    at[i] = at[i] or {}; table.insert(at[i], m.name)
                    break
                elseif st ~= "d" and known then
                    where, col = (#ids > 1 and ("needs step %d of %d"):format(i, #ids) or "not started"), STATE_HEX.n
                    at[i] = at[i] or {}; table.insert(at[i], m.name)
                    break
                end
            end
            if not where then
                local st = PartyState(m, q.id)
                if st == "d" then where, col = "done", STATE_HEX.d
                elseif allKnown then where, col = "done", STATE_HEX.d
                else where = "unknown (no JaseTools)" end
            end
            parts[#parts + 1] = ("|cff%s%s|r |cff9e9ea8%s|r"):format(col, m.name, where)
        end
        add({ label = "Party", text = table.concat(parts, "  •  ") })
    end

    -- Prerequisite chain: steps in order, then this quest.
    local chain = chainForParty
    if chain then
        local nDone, nextIdx = 0, nil
        for i, step in ipairs(chain) do
            if QuestDone(step.id) then nDone = nDone + 1 elseif not nextIdx then nextIdx = i end
        end
        local r, g, b = Accent()
        local accentHex = ("%02x%02x%02x"):format(r * 255, g * 255, b * 255)
        add({ header = true, text = ("|cff%sQuest chain|r  |cff9e9ea8%d of %d steps done|r"):format(accentHex, nDone, #chain) })
        for i, step in ipairs(chain) do
            local det = step.det
            local isNext = i == nextIdx
            local done = QuestDone(step.id)
            local inLog = not done and QuestInLog(step.id)
            local txt = i .. ". " .. (step.name or "?")
            if step.summon then txt = txt .. "  |cff8fb8ff(to summon the boss)|r" end
            if at[i] then txt = txt .. "  |cff8fb8ff<- " .. table.concat(at[i], ", ") .. "|r" end
            if isNext then
                txt = ("|cff%s%s  (%s)|r"):format(accentHex, txt, inLog and "in your log" or "next")
                local prog = inLog and QuestProgress(step.id)
                if prog then txt = txt .. "\n" .. prog end
            elseif done then
                txt = "|cff7f7f85" .. txt .. "|r"
            end
            if isNext and det then
                if det.warning and det.warning ~= "" then txt = txt .. "\n|cffff9a3c" .. det.warning .. "|r" end
                if det.objective then txt = txt .. "\n|cffd8d8dc" .. det.objective .. "|r" end
                if det.pickup then txt = txt .. "\n|cff9e9ea8Start:|r " .. det.pickup end
                if det.turnin then txt = txt .. "\n|cff9e9ea8Turn in:|r " .. det.turnin end
                if det.note then txt = txt .. "\n|cffffd25aNote:|r " .. det.note end
            end
            add({ step = true, done = done, inLog = inLog, text = txt,
                  map = (det and (det.map or det.hubMap)) or starts[step.id],
                  mapText = "Show on map", qid = step.id, title = step.name })
            if isNext and det then
                if det.startItem then add({ label = "Starts from", item = det.startItem, map = det.startItem.map, mapText = "Show on map" }) end
                if det.noteItem then add({ label = "You need", item = det.noteItem, map = det.noteItemMap or det.noteItem.map, mapText = "Show on map" }) end
                if det.requiredItem then add({ label = "You need", item = det.requiredItem, map = det.requiredItem.map, mapText = "Show on map" }) end
                for _, it in ipairs(det.requiredItems or {}) do
                    add({ label = "You need", item = it, map = it.map, mapText = "Show on map" })
                end
                if det.providedItem then add({ label = "Gives", item = det.providedItem }) end
                if det.turninMap then
                    add({ label = "Turn in", text = det.turnin or step.name, map = det.turninMap,
                          mapText = "Show turn-in", qid = step.id, title = step.name, turnIn = true })
                end
            end
        end
        add({ step = true, done = QuestDone(q.id), inLog = QuestInLog(q.id), text = (#chain + 1) .. ". " .. (q.name or "?") .. "  |cff9e9ea8(this quest)|r"
            .. (at[#chain + 1] and ("  |cff8fb8ff<- " .. table.concat(at[#chain + 1], ", ") .. "|r") or "") })
    end

    if q.rewards and q.rewards ~= "" then
        add({ label = "Rewards", text = RewardLinks(q.rewards:gsub("\n", "  •  "), q.rewardItems), links = true })
    end
    -- (a note that only introduces the linked optional quest is already the Optional line)
    if q.note and q.note ~= "" and not (q.noteQuestLink and q.note:match(":%s*$")) then
        add({ label = "Note", text = q.note })
    end

    -- heights
    local total = 6
    for _, l in ipairs(lines) do
        local h = Measure(LineText(l), TextWidth(l, rowWidth), 12)
        if l.map or l.action then h = math.max(h, 20) end
        l.height = math.max(18, h) + (l.header and 10 or 5)
        total = total + l.height
    end
    return lines, total + 6
end

local function MakeLine(row)
    local f = CreateFrame("Button", nil, row)
    f.label = Text(f, 11, C_MUTED[1], C_MUTED[2], C_MUTED[3])
    f.label:SetPoint("TOPLEFT", 0, -2)
    f.label:SetWidth(LABEL_W - 6)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(16, 16)
    f.text = f:CreateFontString(nil, "OVERLAY")
    f.text:SetWordWrap(true)
    f.text:SetJustifyH("LEFT")
    f.text:SetJustifyV("TOP")
    f.map = FlatButton(f, "Show on map", MAPBTN_W - 8, 20)
    f.map:SetPoint("TOPRIGHT", 0, 0)
    f.map:SetScript("OnClick", function(self)
        local l = self:GetParent().line
        if l and l.action then
            pcall(l.action)
            Refresh(nil, true)
        elseif l then
            ShowOnMap(l.map, l.title or l.text, l.qid, l.title, l.turnIn)
        end
    end)
    f:SetScript("OnEnter", function(self)
        if self.itemID then ItemEnter(self) end
    end)
    f:SetScript("OnLeave", HideTip)
    f:SetScript("OnClick", function(self)
        if self.itemID then ItemClick(self) end
    end)
    -- reward item links in the text
    if f.SetHyperlinksEnabled then f:SetHyperlinksEnabled(true) end
    f:SetScript("OnHyperlinkEnter", function(self, link)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if not pcall(GameTooltip.SetHyperlink, GameTooltip, link) then
            local id = tonumber(tostring(link):match("item:(%d+)"))
            if id then GameTooltip:SetItemByID(id) end
        end
        GameTooltip:Show()
    end)
    f:SetScript("OnHyperlinkLeave", HideTip)
    f:SetScript("OnHyperlinkClick", function(_, link)
        local id = tonumber(tostring(link):match("item:(%d+)"))
        local full = id and select(2, GetItemInfoFn(id))
        if not full then return end
        if IsModifiedClick("CHATLINK") then
            ChatEdit_InsertLink(full)
        elseif IsModifiedClick("DRESSUP") and DressUpItemLink then
            DressUpItemLink(full)
        end
    end)
    return f
end

local QuestRow = {
    create = function(L)
        local row = RowBase(L, QUEST_H)
        row.dot = row:CreateTexture(nil, "ARTWORK")
        row.dot:SetSize(4, 30)
        row.dot:SetPoint("TOPLEFT", 0, -9)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("TOPLEFT", 12, -15)
        row.name = Text(row, 13)
        row.name:SetPoint("TOPLEFT", LINE_LEFT, -8)
        row.name:SetPoint("RIGHT", -210, 0)
        row.sub = Text(row, 11, C_MUTED[1], C_MUTED[2], C_MUTED[3])
        row.sub:SetPoint("TOPLEFT", LINE_LEFT, -27)
        row.sub:SetPoint("RIGHT", -210, 0)
        row.status = Text(row, 11, 1, 1, 1, "RIGHT")
        row.status:SetPoint("TOPRIGHT", -12, -17)
        row.status:SetWidth(70)
        row.rewards = {}
        for i = 1, 4 do
            local r = CreateFrame("Button", nil, row)
            r:SetSize(24, 24)
            r.border = r:CreateTexture(nil, "ARTWORK", nil, 0)
            r.border:SetAllPoints()
            r.icon = r:CreateTexture(nil, "ARTWORK", nil, 1)
            r.icon:SetPoint("TOPLEFT", 1, -1); r.icon:SetPoint("BOTTOMRIGHT", -1, 1)
            r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            r:SetPoint("TOPRIGHT", row, "TOPRIGHT", -86 - (i - 1) * 28, -12)
            r:SetScript("OnEnter", ItemEnter)
            r:SetScript("OnLeave", HideTip)
            r:SetScript("OnClick", ItemClick)
            row.rewards[i] = r
        end
        row.lines = {}
        row:SetScript("OnClick", function(self)
            if not self.questID then return end
            local open = state.openQuests
            open[self.questID] = not open[self.questID] or nil
            Refresh("content", true)
        end)
        return row
    end,
    update = function(row, data)
        local q, st = data.q, data.state
        row.questID = q.id
        local lbl = STATE_LABEL[st]
        row.dot:SetColorTexture(lbl[2], lbl[3], lbl[4], st == "available" and 0.35 or 0.9)
        row.icon:SetTexture(QUEST_ICON)
        row.icon:SetDesaturated(st == "done" or st == "low")
        local tags = ""
        if FullChain(q) then tags = tags .. "  |cff8fb8ffCHAIN|r" end
        if q.requiredItem or q.requiredItems or q.noteItem then tags = tags .. "  |cffffb24dITEM NEEDED|r" end
        if q.startItem or q.startObject then tags = tags .. "  |cffffd25aSTARTS FROM ITEM|r" end
        if q.classOnly then tags = tags .. "  |cffc0a0ff" .. tostring(q.classOnly):upper() .. "|r" end
        row.name:SetText((q.name or "?") .. tags)
        row.name:SetTextColor(LevelColor(q.level))
        local extra = ""
        if q.faction and q.faction ~= "Both" then extra = extra .. "  •  " .. q.faction end
        if data.side then extra = extra .. "  •  |cff8fb8ff" .. data.side .. "|r" end
        if q.startsInDungeon then extra = extra .. "  •  starts inside" end
        -- What's blocking / how far along: the chain step to do first, or the
        -- live objective progress from your quest log.
        local _, total, nextStep, nextIdx, nextInLog = ChainStatus(q)
        if st == "locked" and nextStep then
            local prog = nextInLog and QuestProgress(nextStep.id)
            extra = extra .. ("  •  |cffff9a40Do first: %s|r"):format(nextStep.name or "?")
                .. (nextInLog and "  |cffffd233(in log)|r" or "")
                .. (prog and ("  " .. prog) or "")
        elseif st == "log" then
            if nextStep and nextStep.summon then
                extra = extra .. ("  •  |cffff9a40Needs: %s|r"):format(nextStep.page or nextStep.name or "?")
            end
            local prog = QuestProgress(q.id)
            if prog then extra = extra .. "  •  " .. prog end
        elseif nextStep and nextStep.summon then
            extra = extra .. ("  •  |cff8fb8ffNeeds %s to summon|r"):format(nextStep.page or nextStep.name or "?")
        end
        if q.id and #PartyMembers() > 0 then extra = extra .. "  •  Party: " .. PartyNames(q.id) end
        row.sub:SetText(("Level %s  •  Requires %s%s"):format(q.level or "?", q.requires or "?", extra))
        local statusText = lbl[1]
        if st == "low" then
            statusText = "Level " .. (q.requires or "?")
        elseif st == "faction" then
            statusText = (q.faction or "?") .. " only"
        elseif st == "locked" and nextIdx then
            statusText = ("Step %d/%d"):format(nextIdx, total + 1)
        end
        row.status:SetText(statusText)
        row.status:SetTextColor(lbl[2], lbl[3], lbl[4])
        local items = q.rewardItems or {}
        for i, r in ipairs(row.rewards) do
            local it = items[i]
            if it then
                r.itemID = it[1]
                r.source = nil
                r.icon:SetTexture(ItemIcon(it[1]))
                local cr, cg, cb = QualityColor(it[3])
                r.border:SetColorTexture(cr * 0.8, cg * 0.8, cb * 0.8, 1)
                r:Show()
            else
                r:Hide()
            end
        end

        local lines = data.open and data.lines or {}
        local y = -QUEST_H
        for i = 1, math.max(#lines, #row.lines) do
            local l = lines[i]
            local f = row.lines[i]
            if l then
                if not f then f = MakeLine(row); row.lines[i] = f end
                f.line = l
                f:ClearAllPoints()
                f:SetPoint("TOPLEFT", row, "TOPLEFT", LINE_LEFT, y)
                f:SetPoint("RIGHT", row, "RIGHT", -12, 0)
                f:SetHeight(l.height)
                local lh = l.label and LABEL_HEX[l.label]
                if l.label == "Progress" then
                    local ar, ag, ab = Accent()
                    lh = ("%02x%02x%02x"):format(ar * 255, ag * 255, ab * 255)
                end
                f.label:SetText(l.label and (lh and ("|cff" .. lh .. l.label .. "|r") or l.label) or "")
                f.label:SetShown(l.label ~= nil)
                local x = l.label and LABEL_W or 0
                local iconTex
                if l.item then
                    iconTex = ItemIcon(l.item[1])
                    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                elseif l.step then
                    iconTex = (l.done and "Interface\\RaidFrame\\ReadyCheck-Ready")
                        or (l.inLog and "Interface\\GossipFrame\\IncompleteQuestIcon")
                        or "Interface\\RaidFrame\\ReadyCheck-Waiting"
                    f.icon:SetTexCoord(0, 1, 0, 1)
                elseif l.icon then
                    iconTex = l.icon
                    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                end
                f.icon:ClearAllPoints()
                if iconTex then
                    f.icon:SetTexture(iconTex)
                    f.icon:SetPoint("TOPLEFT", x, 0)
                    f.icon:Show()
                    x = x + ICON_W
                else
                    f.icon:Hide()
                end
                SetF(f.text, 12)
                local tc = l.label and TEXT_RGB[l.label]
                if tc then f.text:SetTextColor(tc[1], tc[2], tc[3]) else f.text:SetTextColor(0.86, 0.86, 0.88) end
                f.text:ClearAllPoints()
                f.text:SetPoint("TOPLEFT", x, -2)
                f.text:SetWidth(TextWidth(l, data.width))
                f.text:SetText(LineText(l))
                f.itemID = l.item and l.item[1] or nil
                f.source = nil
                if l.map or l.action then
                    f.map.text:SetText(l.mapText or "Show on map")
                    f.map:Show()
                else
                    f.map:Hide()
                end
                f:Show()
                y = y - l.height
            elseif f then
                f:Hide()
            end
        end
        if data.open then
            row.bg:SetVertexColor(1, 1, 1, 0.07)
        else
            row.bg:SetVertexColor(C_ROW[1], C_ROW[2], C_ROW[3], C_ROW[4])
        end
    end,
}

local EmptyRow = {
    create = function(L)
        local row = CreateFrame("Frame", nil, L)
        row.text = Text(row, 12, C_MUTED[1], C_MUTED[2], C_MUTED[3], "CENTER")
        row.text:SetPoint("CENTER")
        return row
    end,
    update = function(row, data) row.text:SetText(data.text) end,
}

-------------------------------------------------------------------------------
--  Building the item lists
-------------------------------------------------------------------------------
local function Needle()
    local s = (win and win.search:GetText() or ""):lower()
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function SidebarItems()
    local needle = Needle()
    local items = {}
    for _, name in ipairs(FDJ.ORDER or {}) do
        local d = FDJ.DB[name]
        if d then
            local hits = SearchHits(name, needle)
            if needle == "" or hits > 0 then
                items[#items + 1] = { kind = "dungeon", height = 42, data = { name = name, d = d, hits = hits } }
            end
        end
    end
    if #items == 0 then
        items[1] = { kind = "empty", height = 60, data = { text = "No dungeon matches" } }
    end
    return items
end

local function BossItems(d, needle)
    local items = {}
    for _, b in ipairs(d.bosses or {}) do
        local show = Match(b.name, needle)
        if not show then
            for _, it in ipairs(b.loot or {}) do
                if Match(it[2], needle) then show = true; break end
            end
        end
        if show then items[#items + 1] = { kind = "boss", height = 48, data = { boss = b } } end
    end
    return items
end

local function LootItems(d, needle, width)
    local cols = math.max(1, math.floor((width + CARD_GAP) / (CARD_W + CARD_GAP)))
    local items = {}
    for _, b in ipairs(d.bosses or {}) do
        if not state.boss or state.boss == b.name then
            local list = {}
            for _, it in ipairs(b.loot or {}) do
                local owned = Owned(it[1])
                local ok = Match(it[2], needle) or Match(b.name, needle)
                if ok and state.usable and not CanUse(it[3]) then ok = false end
                if ok and state.hideOwned and owned then ok = false end
                if ok then list[#list + 1] = { item = it, boss = b.name, owned = owned } end
            end
            if #list > 0 then
                items[#items + 1] = { kind = "header", height = 30, data = { text = (b.name or "?") .. "  (" .. #list .. ")" } }
                for i = 1, #list, cols do
                    local chunk = {}
                    for j = i, math.min(i + cols - 1, #list) do chunk[#chunk + 1] = list[j] end
                    items[#items + 1] = { kind = "cards", height = 50, data = { items = chunk, cols = cols } }
                end
            end
        end
    end
    return items
end

local function QuestItems(d, needle, width)
    local items = {}
    local list = QuestsFor(d, state.dungeon)
    for _, e in ipairs(list) do
        local q = e.q
        if (Match(q.name, needle) or Match(e.side, needle)) and not (state.hideDone and e.state == "done") then
            local open = state.openQuests[q.id] and true or false
            local lines, extra
            if open then lines, extra = QuestLines(q, state.dungeon, d, width) end
            items[#items + 1] = { kind = "quest", height = QUEST_H + (extra or 0) + 2,
                data = { q = q, state = e.state, open = open, lines = lines, width = width, side = e.side } }
        end
    end
    return items
end

-------------------------------------------------------------------------------
--  Window
-------------------------------------------------------------------------------
local TABS = { { key = "bosses", label = "Bosses" }, { key = "loot", label = "Loot" }, { key = "quests", label = "Quests" } }

local function UpdateHeader()
    local d = FDJ.DB[state.dungeon]
    if not d then return end
    win.hIcon:SetTexture(d.icon or BOSS_ICON)
    win.hName:SetText(state.dungeon)
    local lo, hi = ParseRange(d.level)
    local lvl = d.level and ("Level " .. d.level) or ""
    if lo and hi then
        local r, g, b = LevelColor(math.floor((lo + hi) / 2))
        lvl = ("|cff%02x%02x%02x%s|r"):format(r * 255, g * 255, b * 255, lvl)
    end
    win.hMeta:SetText(lvl .. (d.location and ("   |cff9e9ea8" .. d.location .. "|r") or ""))
    win.hDesc:SetText(d.description or "")
    win.mapBtn:SetShown(FDJ.OpenDungeonMap ~= nil)
    win.trackBtn:SetShown(FDJ.ToggleQuestTracking ~= nil)
    local tracked = false
    local cdb = ForeverDungeonJournalCharacterDB
    for _, n in ipairs((type(cdb) == "table" and type(cdb.trackedDungeons) == "table" and cdb.trackedDungeons) or {}) do
        if n == state.dungeon then tracked = true end
    end
    win.trackBtn:SetOn(tracked)
    win.trackBtn.text:SetText(tracked and "Tracking" or "Track")

    -- tab counts
    local nb, nl = 0, 0
    for _, b in ipairs(d.bosses or {}) do
        nb = nb + 1
        nl = nl + #(b.loot or {})
    end
    local quests, done = QuestsFor(d, state.dungeon)
    local counts = { bosses = tostring(nb), loot = tostring(nl), quests = done .. "/" .. #quests }
    for _, t in ipairs(win.tabs) do
        local on = t.key == state.tab
        local r, g, b = Accent()
        t.text:SetText(t.label .. "  |cff8a8a90" .. counts[t.key] .. "|r")
        t.text:SetTextColor(on and 1 or 0.7, on and 1 or 0.7, on and 1 or 0.7)
        t.line:SetColorTexture(r, g, b)
        t.line:SetShown(on)
    end

    -- chips for this tab
    win.chipUsable:SetShown(state.tab == "loot")
    win.chipOwned:SetShown(state.tab == "loot")
    win.chipDone:SetShown(state.tab == "quests")
    win.chipFaction:SetShown(state.tab == "quests")
    win.chipParty:SetShown(state.tab == "quests" and #PartyMembers() > 0)
    win.chipFaction:SetOn(state.bothFactions)
    win.chipBoss:SetShown(state.tab == "loot" and state.boss ~= nil)
    win.chipUsable:SetOn(state.usable)
    win.chipOwned:SetOn(state.hideOwned)
    win.chipDone:SetOn(state.hideDone)
    if state.boss then
        win.chipBoss.text:SetText(state.boss .. "  ×")
        win.chipBoss:SetWidth(math.min(220, win.chipBoss.text:GetStringWidth() + 24))
        win.chipBoss:SetOn(true)
    end
end

local function UpdateContent(keepScroll)
    local d = FDJ.DB[state.dungeon]
    local L = win.content
    if not d then L:SetItems({}); return end
    local needle = Needle()
    local width = L:GetWidth()
    if width < 50 then width = 600 end
    local items
    if state.tab == "loot" then
        items = LootItems(d, needle, width - 12)
    elseif state.tab == "quests" then
        items = QuestItems(d, needle, width)
    else
        items = BossItems(d, needle)
    end
    if #items == 0 then
        local msg = state.tab == "quests" and "No quests to show" or "Nothing matches these filters"
        items[1] = { kind = "empty", height = 80, data = { text = msg } }
    end
    L:SetItems(items, keepScroll)
    -- jump to a quest (from a boss's summon link)
    if state.scrollTo then
        for i, it in ipairs(items) do
            if it.kind == "quest" and it.data.q.id == state.scrollTo then
                L:SetScroll(L.offsets[i])
                break
            end
        end
        state.scrollTo = nil
    end
end

function Refresh(what, keepScroll)
    if not (win and win:IsShown()) then return end
    if what == nil or what == "sidebar" then win.side:SetItems(SidebarItems(), true) end
    if what == nil or what == "header" or what == "content" then UpdateHeader() end
    if what == nil or what == "content" or what == "header" then UpdateContent(keepScroll) end
end

function SelectDungeon(name)
    if not FDJ.DB[name] then return end
    state.dungeon = name
    state.boss = nil
    Refresh()
end

function SelectTab(key)
    if key == "quests" and win and win.AskParty then win.AskParty(false) end
    state.tab = key
    if key ~= "loot" then state.boss = nil end
    Refresh("content")
end

local function OpenClassic()
    allowClassic = true
    win:Hide()
    if ForeverDungeonJournalDB then ForeverDungeonJournalDB.lastDungeon = state.dungeon end
    local f = _G.ForeverDungeonJournalFrame
    if f then f:Show() elseif _G.ForeverDungeonJournal_Toggle then _G.ForeverDungeonJournal_Toggle() end
end

local function SavePosition()
    local p, _, rp, x, y = win:GetPoint()
    state.pos = { p, rp, x, y }
    state.w, state.h = win:GetSize()
end

local function Build()
    win = CreateFrame("Frame", "JaseQoLJournalFrame", UIParent)
    win:SetSize(state.w or 940, state.h or 600)
    if state.pos then
        win:SetPoint(state.pos[1], UIParent, state.pos[2], state.pos[3], state.pos[4])
    else
        win:SetPoint("CENTER", 0, 20)
    end
    win:SetFrameStrata("MEDIUM")   -- below the world map, so Show on map is visible
    win:SetToplevel(true)
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:SetResizable(true)
    if win.SetResizeBounds then win:SetResizeBounds(780, 460, 1600, 1100) end
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePosition() end)
    win:Hide()
    tinsert(UISpecialFrames, "JaseQoLJournalFrame")

    -- Our own backdrop sits on a child so EllesmereUI's Shell (which fades
    -- the window's own textures) can lay its themed backdrop underneath.
    local back = CreateFrame("Frame", nil, win)
    back:SetAllPoints()
    back:SetFrameLevel(win:GetFrameLevel())
    win.back = back
    if S and S.Shell then
        S.Shell(win)
    else
        Fill(back, C_BG)
        Border(back)
    end

    -- Title bar
    local title = Text(win, 13, 1, 1, 1)
    title:SetPoint("TOPLEFT", 12, -6)
    title:SetText("Dungeon Journal")

    local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() win:Hide() end)
    if S and S.CloseButton then S.CloseButton(close) end

    local classic = FlatButton(win, "Classic view", 92, 20)
    classic:SetPoint("TOPRIGHT", -32, -3)
    classic:SetScript("OnClick", OpenClassic)

    local search = CreateFrame("EditBox", nil, win)
    search:SetSize(260, 20)
    search:SetPoint("RIGHT", classic, "LEFT", -10, 0)
    search:SetAutoFocus(false)
    search:SetTextInsets(22, 8, 0, 0)
    SetF(search, 12)
    Fill(search, { 0, 0, 0, 0.5 })
    Border(search)
    local glass = search:CreateTexture(nil, "OVERLAY")
    glass:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    glass:SetSize(13, 13)
    glass:SetPoint("LEFT", 6, -1)
    glass:SetVertexColor(0.7, 0.7, 0.7)
    local hint = Text(search, 12, 0.45, 0.45, 0.5)
    hint:SetPoint("LEFT", 22, 0)
    hint:SetText("Search dungeons, bosses, items, quests")
    search:SetScript("OnEscapePressed", function(self)
        if self:GetText() ~= "" then self:SetText("") else self:ClearFocus() end
    end)
    search:SetScript("OnEnterPressed", search.ClearFocus)
    local pending
    search:SetScript("OnTextChanged", function(self)
        hint:SetShown(self:GetText() == "")
        if pending then pending:Cancel() end
        pending = C_Timer.NewTimer(0.15, function()
            pending = nil
            Refresh()
        end)
    end)
    win.search = search

    -- Sidebar
    local side = CreateFrame("Frame", nil, win)
    side:SetPoint("TOPLEFT", 8, -32)
    side:SetPoint("BOTTOMLEFT", 8, 8)
    side:SetWidth(230)
    Fill(side, C_PANEL)
    Border(side)
    win.side = NewList(side, { dungeon = DungeonRow, empty = EmptyRow })
    win.side:SetPoint("TOPLEFT", 1, -1)
    win.side:SetPoint("BOTTOMRIGHT", -1, 1)

    -- Main area
    local main = CreateFrame("Frame", nil, win)
    main:SetPoint("TOPLEFT", side, "TOPRIGHT", 8, 0)
    main:SetPoint("BOTTOMRIGHT", -8, 8)
    Fill(main, C_PANEL)
    Border(main)

    -- Header
    win.hIcon = main:CreateTexture(nil, "ARTWORK")
    win.hIcon:SetSize(44, 44)
    win.hIcon:SetPoint("TOPLEFT", 14, -14)
    win.hIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    win.hName = Text(main, 20)
    win.hName:SetPoint("TOPLEFT", win.hIcon, "TOPRIGHT", 12, 0)
    win.hMeta = Text(main, 12, 0.8, 0.8, 0.8)
    win.hMeta:SetPoint("TOPLEFT", win.hName, "BOTTOMLEFT", 0, -5)
    win.hDesc = Text(main, 12, 0.72, 0.72, 0.76)
    win.hDesc:SetPoint("TOPLEFT", win.hIcon, "BOTTOMLEFT", 0, -10)
    win.hDesc:SetPoint("RIGHT", main, "RIGHT", -14, 0)
    win.hDesc:SetWordWrap(true)
    win.hDesc:SetMaxLines(2)

    win.mapBtn = FlatButton(main, "Map", 70, 22)
    win.mapBtn:SetPoint("TOPRIGHT", -14, -14)
    win.trackBtn = FlatButton(main, "Track", 70, 22)
    win.trackBtn:SetPoint("RIGHT", win.mapBtn, "LEFT", -6, 0)
    win.trackBtn:SetScript("OnClick", function()
        if FDJ.ToggleQuestTracking then pcall(FDJ.ToggleQuestTracking, state.dungeon) end
        UpdateHeader()
    end)
    win.trackBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.on and "Stop tracking" or "Track", 1, 1, 1)
        if not self.on then
            GameTooltip:AddLine("Shows this dungeon's quests on your screen with your progress.", 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    win.trackBtn:SetScript("OnLeave", HideTip)
    win.mapBtn:SetScript("OnClick", function()
        if FDJ.OpenDungeonMap then pcall(FDJ.OpenDungeonMap, state.dungeon) end
    end)

    -- Tabs
    local tabBar = CreateFrame("Frame", nil, main)
    tabBar:SetPoint("TOPLEFT", 8, -98)
    tabBar:SetPoint("TOPRIGHT", -8, -98)
    tabBar:SetHeight(30)
    local sep = tabBar:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(1, 1, 1, 0.08)
    sep:SetPoint("BOTTOMLEFT"); sep:SetPoint("BOTTOMRIGHT"); sep:SetHeight(1)
    win.tabs = {}
    local prev
    for _, t in ipairs(TABS) do
        local b = CreateFrame("Button", nil, tabBar)
        b:SetSize(110, 30)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 2, 0) else b:SetPoint("LEFT", 0, 0) end
        Fill(b, C_HOVER, "HIGHLIGHT")
        b.text = Text(b, 13, 0.8, 0.8, 0.8, "CENTER")
        b.text:SetPoint("CENTER", 0, 1)
        b.line = b:CreateTexture(nil, "OVERLAY")
        b.line:SetPoint("BOTTOMLEFT", 6, 0); b.line:SetPoint("BOTTOMRIGHT", -6, 0); b.line:SetHeight(2)
        b.key, b.label = t.key, t.label
        b:SetScript("OnClick", function(self) SelectTab(self.key) end)
        win.tabs[#win.tabs + 1] = b
        prev = b
    end

    local function Chip(label, field)
        local c = FlatButton(tabBar, label, 110, 22)
        c:SetScript("OnClick", function()
            state[field] = not state[field]
            Refresh("content")
        end)
        return c
    end
    win.chipOwned = Chip("Hide owned", "hideOwned")
    win.chipOwned:SetPoint("RIGHT", tabBar, "RIGHT", 0, 1)
    win.chipUsable = Chip("Usable by me", "usable")
    win.chipUsable:SetPoint("RIGHT", win.chipOwned, "LEFT", -6, 0)
    win.chipDone = Chip("Hide done", "hideDone")
    win.chipDone:SetPoint("RIGHT", tabBar, "RIGHT", 0, 1)
    win.chipFaction = Chip("Both factions", "bothFactions")
    win.chipFaction:SetPoint("RIGHT", win.chipDone, "LEFT", -6, 0)
    win.chipParty = FlatButton(tabBar, "Party check", 100, 22)
    win.chipParty:SetPoint("RIGHT", win.chipFaction, "LEFT", -6, 0)
    win.chipParty:SetScript("OnClick", function()
        if not win.AskParty(true) then JQ.Print("Party check: you're not in a party.") end
    end)
    win.chipParty:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Party check", 1, 1, 1)
        GameTooltip:AddLine("Who in your party has these quests. Names are coloured:", 0.85, 0.85, 0.88, true)
        GameTooltip:AddLine("|cff59d959done|r  |cffffd233in their log|r  |cff7f7f85not started|r  |cffffffffunknown|r", 1, 1, 1)
        GameTooltip:AddLine("Done and chain steps come from party members who also run JaseTools; for others the game only tells \"in their log\".", 0.62, 0.62, 0.66, true)
        GameTooltip:Show()
    end)
    win.chipParty:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Every quest of this dungeon and its chains, for the party check.
    function win.AskParty(force)
        if not force and GetTime() - partyAskedAt < 30 then return true end
        local d = FDJ.DB[state.dungeon]
        if not d then return false end
        local ids, seen = {}, {}
        local function add(id) if id and not seen[id] then seen[id] = true; ids[#ids + 1] = id end end
        for _, e in ipairs(QuestsFor(d, state.dungeon)) do
            add(e.q.id)
            for _, st in ipairs(FullChain(e.q) or {}) do add(st.id) end
            if e.q.noteQuestLink then add(e.q.noteQuestLink.id) end
        end
        local ok = PartyAsk(ids)
        if ok and force then JQ.Print("Party check sent. Party members with JaseTools answer in a moment.") end
        return ok
    end
    PartyRefresh = function()
        if win:IsShown() and state.tab == "quests" then Refresh("content", true) end
    end
    win.chipBoss = FlatButton(tabBar, "", 120, 22)
    win.chipBoss:SetPoint("RIGHT", win.chipUsable, "LEFT", -6, 0)
    win.chipBoss:SetScript("OnClick", function()
        state.boss = nil
        Refresh("content")
    end)

    -- Content list
    win.content = NewList(main, {
        boss = BossRow, header = HeaderRow, cards = CardRow, quest = QuestRow, empty = EmptyRow,
    })
    win.content:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -8)
    win.content:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -8, 8)
    -- loot columns / quest heights depend on width: rebuild on resize
    win.content.onResize = function() UpdateContent(true) end

    -- Resize grip
    local grip = CreateFrame("Button", nil, win)
    grip:SetSize(14, 14)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() win:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function() win:StopMovingOrSizing(); SavePosition() end)

    -- Live updates while open only.
    local ev = CreateFrame("Frame", nil, win)
    local pendingEv
    ev:SetScript("OnEvent", function()
        if pendingEv then return end
        pendingEv = C_Timer.NewTimer(0.3, function()
            pendingEv = nil
            Refresh(nil, true)
        end)
    end)
    win:SetScript("OnShow", function()
        if state.tab == "quests" and win.AskParty then win.AskParty(false) end
        for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_TURNED_IN", "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP", "GROUP_ROSTER_UPDATE" }) do
            pcall(ev.RegisterEvent, ev, e)
        end
        Refresh()
    end)
    win:SetScript("OnHide", function()
        ev:UnregisterAllEvents()
        if win.search:HasFocus() then win.search:ClearFocus() end
    end)
end

local function Toggle(show)
    if not FDJ then
        JQ.Print("ForeverDungeonJournal is not loaded.")
        return
    end
    if not win then Build() end
    if show == nil then show = not win:IsShown() end
    if show then
        if not FDJ.DB[state.dungeon or ""] then
            local last = ForeverDungeonJournalDB and ForeverDungeonJournalDB.lastDungeon
            state.dungeon = (last and FDJ.DB[last] and last) or (FDJ.ORDER and FDJ.ORDER[1])
        end
        local orig = _G.ForeverDungeonJournalFrame
        if orig and orig:IsShown() then orig:Hide() end
        win:Show()
    else
        win:Hide()
    end
end
JQ.ToggleJournalView = Toggle

-------------------------------------------------------------------------------
--  Hook-up: take over the original window's opening while this is enabled.
-------------------------------------------------------------------------------
local function HookOriginal()
    local orig = _G.ForeverDungeonJournalFrame
    if not orig or orig._jqHooked then return orig ~= nil end
    orig._jqHooked = true
    orig:HookScript("OnShow", function(self)
        if allowClassic or not JQ.IsEnabled(KEY) then return end
        -- The journal window holds action buttons (target / mark the quest
        -- giver): hiding it in combat is blocked, so in combat it stays as it is.
        if InCombatLockdown() then return end
        self:Hide()
        Toggle(true)
    end)
    orig:HookScript("OnHide", function() allowClassic = false end)
    return true
end

JQ.byKey[KEY].onLoad = function()
    FDJ = _G.ForeverDungeonJournal_NS
    if not (FDJ and FDJ.DB) then return end
    JaseQoLDB.journal = JaseQoLDB.journal or {}
    state = JaseQoLDB.journal
    state.tab = state.tab or "bosses"
    state.openQuests = {}     -- expanded quests: per session only
    state.boss = nil

    if EllesmereUI and EllesmereUI.RegisterSkin then
        EllesmereUI.RegisterSkin("JaseTools Dungeon Journal", function(facade) S = facade end)
    end

    local boot = CreateFrame("Frame")
    boot:RegisterEvent("PLAYER_LOGIN")
    boot:SetScript("OnEvent", function()
        boot:UnregisterAllEvents()
        if HookOriginal() then return end
        local tries = 0
        local function retry()
            tries = tries + 1
            if HookOriginal() or tries > 20 then return end
            C_Timer.After(0.5, retry)
        end
        C_Timer.After(0.5, retry)
    end)

    SLASH_JASEQOLDJ1 = "/jdj"
    SlashCmdList.JASEQOLDJ = function() Toggle() end
end

JQ.byKey[KEY].onDisable = function()
    if win and win:IsShown() then win:Hide() end
end
