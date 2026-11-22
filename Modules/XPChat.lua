-------------------------------------------------------------------------------
--  JaseTools: experience in chat
--
--  WoW Forever shows the XP for a kill as floating text over the mob, not in
--  chat. This prints a chat line for every XP gain, read from the XP bar
--  itself (so nothing is missed): the XP, and the rested part in blue.
--    "JaseTools: +156 XP (78 rested)"
-------------------------------------------------------------------------------
local _, JQ = ...
local KEY = "xpChat"

JQ.AddModule({
    key = KEY,
    label = "Experience in chat",
    description = "Prints a chat line for every bit of experience you gain, with the rested bonus in blue. WoW Forever otherwise only shows kill XP as floating text.",
    default = true,
})

local lastXP, lastMax, lastLevel, restedBefore

local function Num(n)
    local s = tostring(math.floor(n + 0.5))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

local function Snapshot()
    lastXP, lastMax, lastLevel = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
    restedBefore = GetXPExhaustion and GetXPExhaustion() or 0
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
    if gained <= 0 or not JQ.IsEnabled(KEY) then return end

    -- the XP, and the rested part of it in blue (what the rested pool went down by)
    local line = "|cffb07bff+" .. Num(gained) .. " XP|r"
    if restedUsed > 0 then
        line = line .. " |cff4fa8ff(" .. Num(math.min(restedUsed, gained)) .. " rested)|r"
    end
    JQ.Print(line)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_XP_UPDATE")
ev:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_XP_UPDATE" then
        if unit == nil or unit == "player" then OnXP() end
    else
        Snapshot()
    end
end)

-- for tests
JQ._XPChat = { Num = Num }
