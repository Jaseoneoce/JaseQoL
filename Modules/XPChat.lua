-------------------------------------------------------------------------------
--  JaseTools: experience in chat
--
--  WoW Forever shows the XP for a kill as floating text over the mob, not in
--  chat. This prints a chat line for every XP gain, read from the XP bar
--  itself (so nothing is missed): how much, where from when it can tell (the
--  mob you just killed, the quest you just handed in), rested bonus, and how
--  far to the next level.
--    "JaseTools: +156 XP (Kobold Vermin, 78 rested) - 2,340 to level 23 (61%)"
-------------------------------------------------------------------------------
local _, JQ = ...
local KEY = "xpChat"

JQ.AddModule({
    key = KEY,
    label = "Experience in chat",
    description = "Prints a chat line for every bit of experience you gain - how much, from which mob or quest, how much was rested bonus, and how far you are from the next level. WoW Forever otherwise only shows kill XP as floating text.",
    default = true,
})

local lastXP, lastMax, lastLevel
local source, sourceTime            -- the latest kill / quest, and when
local restedBefore

local function Num(n)
    local s = tostring(math.floor(n + 0.5))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

local function Snapshot()
    lastXP, lastMax, lastLevel = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
    restedBefore = GetXPExhaustion and GetXPExhaustion() or 0
end

local function MaxedOut()
    local maxLevel = (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion())
        or (GetMaxPlayerLevel and GetMaxPlayerLevel()) or MAX_PLAYER_LEVEL
    return maxLevel and UnitLevel("player") >= maxLevel
end

local function SetSource(text)
    source, sourceTime = text, GetTime()
end

local function OnXP()
    if not lastXP then Snapshot() return end
    local xp, max, level = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
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
    if gained <= 0 or not JQ.IsEnabled(KEY) then return end

    local from = {}
    if source and sourceTime and GetTime() - sourceTime < 3 then from[#from + 1] = source end
    source = nil
    -- rested XP doubles a kill: the bonus is about what the rested pool went down by
    if restedUsed > 0 then from[#from + 1] = Num(math.min(restedUsed, gained)) .. " rested" end
    local line = "|cffb07bffXP +" .. Num(gained) .. "|r"
    if #from > 0 then line = line .. " (" .. table.concat(from, ", ") .. ")" end
    if not MaxedOut() and max and max > 0 then
        line = line .. (" - %s to level %d (%d%%)"):format(Num(max - xp), level + 1, math.floor(xp / max * 100))
    end
    JQ.Print(line)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP",
    "QUEST_TURNED_IN", "CHAT_MSG_COMBAT_XP_GAIN", "PLAYER_TARGET_CHANGED", "UNIT_HEALTH" }) do
    pcall(ev.RegisterEvent, ev, e)
end

local targetName
ev:SetScript("OnEvent", function(_, event, a1, a2)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        Snapshot()
    elseif event == "PLAYER_XP_UPDATE" then
        if a1 == nil or a1 == "player" then OnXP() end
    elseif event == "PLAYER_LEVEL_UP" then
        -- PLAYER_XP_UPDATE follows with the new level's numbers
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
