-------------------------------------------------------------------------------
--  JaseTools: experience in chat
--
--  WoW Forever shows the XP for a kill as floating text over the mob, not in
--  chat. This prints a chat line for every XP gain, read from the XP bar
--  itself (so nothing is missed): the XP, where it came from when it can tell
--  (the mob you just killed, the quest you just handed in), and how much of it
--  was normal and how much rested bonus (in blue).
--    "JaseTools: XP +638 (Tar Lurker, 319 normal + 319 rested)"
-------------------------------------------------------------------------------
local _, JQ = ...
local KEY = "xpChat"

JQ.AddModule({
    key = KEY,
    label = "Experience in chat",
    description = "Prints a chat line for every bit of experience you gain: how much, from which mob or quest, and how much was normal and how much rested bonus (in blue). WoW Forever otherwise only shows kill XP as floating text.",
    default = true,
})

local lastXP, lastMax, lastLevel, restedBefore
local source, sourceTime            -- the latest kill / quest, and when
local targetName

local function Num(n)
    local s = tostring(math.floor(n + 0.5))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

local function Snapshot()
    lastXP, lastMax, lastLevel = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
    restedBefore = GetXPExhaustion and GetXPExhaustion() or 0
end

local function SetSource(text)
    source, sourceTime = text, GetTime()
end

local function OnXP()
    if not lastXP then Snapshot() return end
    local xp, level = UnitXP("player"), UnitLevel("player")
    local gained
    if level > lastLevel then
        -- levelled: the rest of the old level, plus what's on the new one
        gained = (lastMax - lastXP) + xp
    else
        gained = xp - lastXP
    end
    local rested = GetXPExhaustion and GetXPExhaustion() or 0
    local restedUsed = math.max(0, (restedBefore or 0) - rested)
    Snapshot()
    local from = (source and sourceTime and GetTime() - sourceTime < 3) and source or nil
    source = nil
    if gained <= 0 or not JQ.IsEnabled(KEY) then return end

    -- Rested doubles kill XP, and the rested pool goes down by the whole gain
    -- (seen in game: +638 took 638 off the pool), so the bonus is half of it.
    local bonus = math.floor(math.min(restedUsed, gained) / 2 + 0.5)
    local parts = {}
    if from then parts[#parts + 1] = from end
    if bonus > 0 then
        parts[#parts + 1] = Num(gained - bonus) .. " normal + |cff4fa8ff" .. Num(bonus) .. " rested|r"
    end
    local line = "|cffb07bffXP +" .. Num(gained) .. "|r"
    if #parts > 0 then line = line .. " (" .. table.concat(parts, ", ") .. ")" end
    JQ.Print(line)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "QUEST_TURNED_IN",
    "CHAT_MSG_COMBAT_XP_GAIN", "PLAYER_TARGET_CHANGED", "UNIT_HEALTH" }) do
    pcall(ev.RegisterEvent, ev, e)
end

ev:SetScript("OnEvent", function(_, event, a1)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        Snapshot()
    elseif event == "PLAYER_XP_UPDATE" then
        if a1 == nil or a1 == "player" then OnXP() end
    elseif event == "QUEST_TURNED_IN" then
        -- questID, xpReward
        local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(a1)
        SetSource(title and ("quest: " .. title) or "quest")
    elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
        -- if the game does send its own line, take the mob's name from it
        local mob = type(a1) == "string" and a1:match("^(.-) dies, you gain")
        if mob then SetSource(mob) end
    elseif event == "PLAYER_TARGET_CHANGED" then
        targetName = UnitExists("target") and UnitCanAttack("player", "target") and UnitName("target") or nil
    elseif event == "UNIT_HEALTH" then
        -- your target dying is the likeliest source of the next XP
        if a1 == "target" and targetName and UnitIsDead("target") then SetSource(targetName) end
    end
end)

-- for tests
JQ._XPChat = { Num = Num }
