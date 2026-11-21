-------------------------------------------------------------------------------
--  JaseTools: don't auto-accept escort quests
--
--  Accepting an escort quest starts the escort straight away. EllesmereUI's
--  Quest Tracker can auto-accept quests; this keeps it from accepting escorts
--  so the quest window stays open until you press Accept.
--
--  How: EllesmereUI asks EllesmereUIQuestTracker.Cfg("autoAccept") each time a
--  quest window opens. While an escort quest's window is open, JaseTools answers
--  "off" for that one question. EllesmereUI's files and settings are never
--  changed; switching this off restores its own answer.
--
--  An escort is spotted by, in order: your own list (/jq escort), the game's
--  Escort quest tag (84), the word "escort" in the quest's title, text or
--  objective, or two of the softer phrases ("to safety", "protect me"...).
--  /jq escort        mark the open quest as an escort
--  /jq escort no     mark the open quest as not an escort
--  /jq escort list   list your marks
--  /jq escort clear  forget your marks
-------------------------------------------------------------------------------
local _, JQ = ...
local KEY = "escortGuard"

JQ.AddModule({
    key = KEY,
    label = "Don't auto-accept escort quests",
    description = "Accepting an escort quest starts the escort straight away. When EllesmereUI's Quest Tracker auto-accepts quests, this leaves escort quests open for you to accept when your group is ready. Escorts are spotted by the game's Escort tag or the quest text; /jq escort marks the open quest as an escort, /jq escort no as not one.",
    default = true,
})
local ANNOUNCE_KEY = "escortAnnounce"
JQ.AddModule({
    key = ANNOUNCE_KEY,
    label = "Tell the group about escort quests",
    description = "When you open an escort quest while in a group, JaseTools tells everyone not to auto-accept or auto hand it in: a whisper to each party member and a message in party chat (in a raid, one message in raid chat). Said once per quest every 10 minutes.",
    default = true,
})

local ESCORT_TAG = (Enum and Enum.QuestTag and Enum.QuestTag.Escort) or 84

-- softer hints: two of these together count as an escort
local HINTS = {
    "to safety", "safely to", "safely out", "see me safely", "get me out", "protect me", "protect him",
    "protect her", "guard me", "accompany me", "follow me", "lead me", "lead him", "lead her",
    "keep me alive", "keep him alive", "keep her alive", "make it out",
}

local function DB()
    JaseQoLDB.escort = JaseQoLDB.escort or {}
    local d = JaseQoLDB.escort
    d.marks = d.marks or {}   -- [questID] = true (escort) / false (not one)
    d.names = d.names or {}
    return d
end

local function Lower(s) return type(s) == "string" and s:lower() or "" end

-- Is questID an escort? Returns true/false and why.
local function IsEscort(questID, title, text, objective)
    local mark = DB().marks[questID]
    if mark ~= nil then return mark, mark and "you marked it" or nil end
    if C_QuestLog and C_QuestLog.GetQuestTagInfo then
        local ok, info = pcall(C_QuestLog.GetQuestTagInfo, questID)
        if ok and type(info) == "table" and info.tagID == ESCORT_TAG then return true, "the game tags it Escort" end
    end
    local all = Lower(title) .. "\n" .. Lower(text) .. "\n" .. Lower(objective)
    if all:find("escort", 1, true) then return true, "the quest says \"escort\"" end
    local hits = 0
    for _, h in ipairs(HINTS) do
        if all:find(h, 1, true) then hits = hits + 1 end
    end
    if hits >= 2 then return true, "the quest text reads like an escort" end
    return false
end
JQ.IsEscortQuest = IsEscort

-- The quest whose details are showing now, if any.
local function OpenQuest()
    local id = GetQuestID and GetQuestID()
    if not id or id == 0 then return nil end
    local panel = _G.QuestFrameDetailPanel
    if panel and not panel:IsShown() then return nil end
    return id, GetTitleText and GetTitleText(), GetQuestText and GetQuestText(),
        GetObjectiveText and GetObjectiveText()
end

local told -- quest last announced, so it's said once per opening
local function Blocked()
    if not JQ.IsEnabled(KEY) then return false end
    local id, title, text, objective = OpenQuest()
    if not id then return false end
    local escort, why = IsEscort(id, title, text, objective)
    if not escort then return false end
    if told ~= id then
        told = id
        if title and title ~= "" then DB().names[id] = title end
        JQ.Print(("|cffffd25aEscort quest: %s.|r Not auto-accepted (%s). Accept it when your group is ready. Wrong? /jq escort no")
            :format(title or ("quest " .. id), why))
    end
    return true
end

-------------------------------------------------------------------------------
--  Tell the group
-------------------------------------------------------------------------------
local SEP = (Constants and Constants.CharacterNameSeparatorConsts
    and Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR) or " "
local ANNOUNCE_EVERY = 600
local announced = {}   -- [questID] = GetTime() of the last announcement

-- Who to whisper: "First Last" on WoW Forever (UnitName's second value is
-- the last name there), else the name with its realm.
local function WhisperName(unit)
    local first, second = (UnitNameUnmodified or UnitName)(unit)
    if type(first) ~= "string" or first == "" or first == UNKNOWNOBJECT then return nil end
    if issecretvalue and (issecretvalue(first) or issecretvalue(second)) then return nil end
    if type(second) == "string" and second ~= "" then
        if Constants and Constants.CharacterNameSeparatorConsts then return first .. SEP .. second end
        return first .. "-" .. second
    end
    return first
end

local function Send(msg, chatType, target)
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if send then pcall(send, msg, chatType, nil, target) end
end

local function Announce(id, title)
    if not JQ.IsEnabled(ANNOUNCE_KEY) or not (IsInGroup and IsInGroup()) then return end
    local now = GetTime()
    if announced[id] and now - announced[id] < ANNOUNCE_EVERY then return end
    announced[id] = now
    local msg = ("JaseTools: Escort detected: %s - do not auto-accept or auto hand in, wait for the group.")
        :format(title or ("quest " .. id))
    local instance = LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
        and not IsInGroup(LE_PARTY_CATEGORY_HOME)
    if IsInRaid and IsInRaid() then
        Send(msg, instance and "INSTANCE_CHAT" or "RAID")
        return
    end
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) and UnitIsPlayer(unit) then
            local name = WhisperName(unit)
            if name then Send(msg, "WHISPER", name) end
        end
    end
    Send(msg, instance and "INSTANCE_CHAT" or "PARTY")
end

-- Announce on every escort quest window, whether or not auto-accept is on.
local function OnDetail()
    if not JQ.IsEnabled(KEY) then return end
    local id, title, text, objective = OpenQuest()
    if not id then
        id = GetQuestID and GetQuestID()
        if not id or id == 0 then return end
        title, text, objective = GetTitleText and GetTitleText(), GetQuestText and GetQuestText(),
            GetObjectiveText and GetObjectiveText()
    end
    if IsEscort(id, title, text, objective) then Announce(id, title) end
end

-------------------------------------------------------------------------------
--  Wrap EllesmereUI Quest Tracker's setting lookup
-------------------------------------------------------------------------------
local wrapped = false
local function Wrap()
    local EQT = _G.EllesmereUIQuestTracker
    if wrapped or type(EQT) ~= "table" or type(EQT.Cfg) ~= "function" then return wrapped end
    local orig = EQT.Cfg
    EQT.Cfg = function(k, ...)
        local v = orig(k, ...)
        if k == "autoAccept" and v and Blocked() then return false end
        return v
    end
    wrapped = true
    return true
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("QUEST_FINISHED")
ev:RegisterEvent("QUEST_DETAIL")
ev:SetScript("OnEvent", function(_, event, name)
    if event == "QUEST_FINISHED" then told = nil; return end
    if event == "QUEST_DETAIL" then OnDetail(); return end
    if event == "PLAYER_LOGIN" or name == "EllesmereUIQuestTracker" or name == "JaseQoL" then Wrap() end
end)

-------------------------------------------------------------------------------
--  /jq escort
-------------------------------------------------------------------------------
function JQ.EscortCommand(arg)
    arg = (arg or ""):lower()
    local d = DB()
    if arg == "list" then
        local n = 0
        for id, v in pairs(d.marks) do
            n = n + 1
            JQ.Print(("  %s  %s"):format(d.names[id] or ("quest " .. id), v and "|cffff6050escort|r" or "|cff59d959not an escort|r"))
        end
        if n == 0 then JQ.Print("No quests marked. Open a quest and type /jq escort (or /jq escort no).") end
        return
    end
    if arg == "clear" then
        d.marks = {}
        JQ.Print("Escort marks cleared.")
        return
    end
    local id, title = OpenQuest()
    if not id then
        JQ.Print("Open the quest first (talk to the quest giver), then type /jq escort or /jq escort no.")
        return
    end
    if title and title ~= "" then d.names[id] = title end
    local isEscort = not (arg == "no" or arg == "off" or arg == "not")
    d.marks[id] = isEscort
    told = nil
    JQ.Print(("%s marked as %s."):format(title or ("quest " .. id), isEscort and "an escort: it won't be auto-accepted" or "not an escort"))
end

-- for tests
JQ._EscortGuard = { IsEscort = IsEscort, Wrap = Wrap }
