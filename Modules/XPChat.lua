-------------------------------------------------------------------------------
--  JaseTools: experience in chat
--
--  WoW Forever shows the XP for a kill as floating text over the mob, not in
--  chat. This prints a chat line for every XP gain, read from the XP bar
--  itself (so nothing is missed): the XP, where it came from when it can tell
--  (the mob you just killed, the quest you just handed in), and how much of it
--  was normal, rested bonus (blue) and XP buffs (green), and in red what a
--  missing buff cost you (Well Fed: kills only; Well-Rested: kills and quests).
--    "JaseTools: XP +588 (Tar Lurker, 285 normal + 285 rested + 18 Well-Rested)"
-------------------------------------------------------------------------------
local _, JQ = ...
local KEY = "xpChat"

JQ.AddModule({
    key = KEY,
    label = "Experience in chat",
    description = "Prints a chat line for every bit of experience you gain: how much, from which mob or quest, and how much was normal, rested bonus (blue) and XP buffs like Well Fed or Well-Rested (green, worked out from their percentages). WoW Forever otherwise only shows kill XP as floating text.",
    default = true,
})

local lastXP, lastMax, lastLevel, restedBefore
local source, sourceTime, sourceKind  -- the latest kill / quest, when, and "kill" / "quest"
local targetName

-- The XP buffs you can have, for the "missed" note:
--   food (Well Fed) 5%, kills only; Well-Rested (sleeping bag) 1% a stack up
--   to 3%, kills and quests.
local FOOD_PCT, WELLRESTED_MAX = 5, 3
local function IsWellRested(name) return type(name) == "string" and name:find("Rested") ~= nil end

local function Num(n)
    local s = tostring(math.floor(n + 0.5))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

local function Snapshot()
    lastXP, lastMax, lastLevel = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
    restedBefore = GetXPExhaustion and GetXPExhaustion() or 0
end

local function SetSource(text, kind)
    source, sourceTime, sourceKind = text, GetTime(), kind
end

-------------------------------------------------------------------------------
--  XP buffs: any buff whose tooltip says "Experience gains increased by N%"
--  (the 5% food buff, Well-Rested from the sleeping bag at 1% a stack...).
--  The game only reports the total XP, so their share is worked out from the
--  percentages. They multiply the whole kill, rested bonus included.
-------------------------------------------------------------------------------
local function TooltipLines(aura, index)
    local data
    if C_TooltipInfo then
        if aura.auraInstanceID and C_TooltipInfo.GetUnitBuffByAuraInstanceID then
            local ok, d = pcall(C_TooltipInfo.GetUnitBuffByAuraInstanceID, "player", aura.auraInstanceID)
            if ok then data = d end
        end
        if not data and C_TooltipInfo.GetUnitBuff then
            local ok, d = pcall(C_TooltipInfo.GetUnitBuff, "player", index)
            if ok then data = d end
        end
    end
    local out = {}
    for _, l in ipairs(data and data.lines or {}) do
        if type(l.leftText) == "string" then out[#out + 1] = l.leftText end
    end
    return out
end

local function Readable(v) return v ~= nil and not (issecretvalue and issecretvalue(v)) end

-- Read the XP buffs from the buff bar now. Returns the list, and whether
-- everything could be read (in combat the game may hide buff details).
local function ScanXPBuffs()
    local list, complete = {}, true
    local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not get then return list, false end
    for i = 1, 40 do
        local ok, aura = pcall(get, "player", i, "HELPFUL")
        if not ok then complete = false break end
        if not aura then break end
        local name = aura.name
        if type(name) == "string" and Readable(name) then
            local lines = TooltipLines(aura, i)
            if #lines == 0 then complete = false end
            for _, text in ipairs(lines) do
                if not Readable(text) then complete = false break end
                local pct = text:match("[Ee]xperience gain[s]? increased by (%d+)%%")
                    or text:match("[Ee]xperience[^%d]-increased by (%d+)%%")
                    or text:match("(%d+)%% more experience")
                if pct then
                    local exp = aura.expirationTime
                    list[#list + 1] = { name = name, pct = tonumber(pct),
                        expires = (Readable(exp) and type(exp) == "number" and exp > 0) and exp or nil }
                    break
                end
            end
        else
            complete = false
        end
    end
    return list, complete
end

-- The last full read, kept for combat (kills give their XP while you're
-- still in combat, when the buff details may be hidden).
local known = {}
local function RememberXPBuffs()
    local list, complete = ScanXPBuffs()
    if complete then known = list end
    return list, complete
end

local function XPBuffs()
    local list, complete = RememberXPBuffs()
    if complete then return list end
    -- couldn't read them all now: what we last saw, minus anything run out
    local now = GetTime()
    local out = {}
    for _, b in ipairs(known) do
        if not b.expires or b.expires > now then
            out[#out + 1] = { name = b.name, pct = b.pct, expires = b.expires }
        end
    end
    return out
end
JQ._XPBuffs = XPBuffs

-- gained, rested pool drop, "kill"/"quest"/nil -> base, rested bonus,
-- { {name, pct, xp}, ... } of the buffs that applied, all XP buffs you had
local function Split(gained, restedUsed, kind)
    local all = XPBuffs()
    local buffs = {}
    for _, b in ipairs(all) do
        -- food buffs count for kills only
        if kind ~= "quest" or IsWellRested(b.name) then buffs[#buffs + 1] = b end
    end
    local pct = 0
    for _, b in ipairs(buffs) do pct = pct + b.pct end
    -- Seen in game: a 285 XP kill gives 570 rested (285 + 285) and 588 with
    -- Well-Rested 3% (285 x 1.03 = 294, doubled = 588), and the rested pool
    -- goes down by the whole gain. So the buffs multiply the whole kill, rested
    -- bonus included: gained = base x (1 + buffs) x (1 + rested share).
    local mult = 1 + pct / 100
    local restedRaw = math.min(restedUsed, gained) / 2      -- rested part, buffs included
    local base = (gained - restedRaw) / mult
    local restedBonus = restedRaw / mult
    -- whole numbers that still add up to the gain: normal and rested rounded,
    -- the game's own rounding left with the buffs (588 = 285 + 285 + 18)
    local n = math.floor(base + 0.5)
    local r = math.floor(restedBonus + 0.5)
    local extra = math.max(0, gained - n - r)
    local given = 0
    for i, b in ipairs(buffs) do
        if i == #buffs then
            b.xp = extra - given
        else
            b.xp = math.floor((pct > 0 and extra * b.pct / pct or 0) + 0.5)
            given = given + b.xp
        end
    end
    local kept = {}
    for _, b in ipairs(buffs) do if b.xp > 0 then kept[#kept + 1] = b end end
    if #buffs == 0 then n = gained - r end
    return n, r, kept, all
end

-- XP left on the table: Well-Rested below 3 stacks (kills and quests), no food
-- buff (kills). It would have multiplied the normal + rested part.
local function Missed(kind, base, restedBonus, all)
    if kind ~= "kill" and kind ~= "quest" then return nil end
    local wr, food = 0, false
    for _, b in ipairs(all) do
        if IsWellRested(b.name) then wr = math.max(wr, b.pct) else food = true end
    end
    local out = {}
    local plain = base + restedBonus
    if wr < WELLRESTED_MAX then
        local missing = WELLRESTED_MAX - wr
        out[#out + 1] = { xp = math.floor(plain * missing / 100 + 0.5), pct = missing,
            what = wr > 0 and ("Well-Rested " .. wr .. "/" .. WELLRESTED_MAX) or "no Well-Rested" }
    end
    if kind == "kill" and not food then
        out[#out + 1] = { xp = math.floor(plain * FOOD_PCT / 100 + 0.5), pct = FOOD_PCT, what = "no Well Fed" }
    end
    local kept = {}
    for _, m in ipairs(out) do if m.xp > 0 then kept[#kept + 1] = m end end
    return #kept > 0 and kept or nil
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
    if gained <= 0 then return end
    local fresh = source and sourceTime and GetTime() - sourceTime < 3
    local from = fresh and source or nil
    local kind = fresh and sourceKind or nil
    source = nil
    if not JQ.IsEnabled(KEY) then return end

    local base, restedBonus, buffs, all = Split(gained, restedUsed, kind)
    local parts = {}
    if from then parts[#parts + 1] = from end
    if restedBonus > 0 or #buffs > 0 then
        local split = { Num(base) .. " normal" }
        if restedBonus > 0 then split[#split + 1] = "|cff4fa8ff" .. Num(restedBonus) .. " rested|r" end
        for _, b in ipairs(buffs) do
            split[#split + 1] = "|cff59d959" .. Num(b.xp) .. " " .. b.name .. "|r"
        end
        parts[#parts + 1] = table.concat(split, " + ")
    end
    local line = "|cffb07bffXP +" .. Num(gained) .. "|r"
    if #parts > 0 then line = line .. " (" .. table.concat(parts, ", ") .. ")" end
    local missed = Missed(kind, base, restedBonus, all)
    if missed then
        -- "missed 33 (8%)" in red, then the breakdown in light orange
        local total, pct, why = 0, 0, {}
        for _, m in ipairs(missed) do
            total, pct = total + m.xp, pct + m.pct
            why[#why + 1] = m.what .. " " .. m.pct .. "%: " .. Num(m.xp)
        end
        line = line .. " |cffff5050missed " .. Num(total) .. " (" .. pct .. "%)|r"
            .. " |cffffb070(" .. table.concat(why, ", ") .. ")|r"
    end
    JQ.Print(line)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "QUEST_TURNED_IN",
    "CHAT_MSG_COMBAT_XP_GAIN", "PLAYER_TARGET_CHANGED", "UNIT_HEALTH",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
pcall(ev.RegisterUnitEvent, ev, "UNIT_AURA", "player")

ev:SetScript("OnEvent", function(_, event, a1)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        Snapshot()
        pcall(RememberXPBuffs)
    elseif event == "UNIT_AURA" or event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        -- keep the last readable list of XP buffs for kills made in combat
        pcall(RememberXPBuffs)
    elseif event == "PLAYER_XP_UPDATE" then
        if a1 == nil or a1 == "player" then OnXP() end
    elseif event == "QUEST_TURNED_IN" then
        -- questID, xpReward
        local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(a1)
        SetSource(title and ("quest: " .. title) or "quest", "quest")
    elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
        -- if the game does send its own line, take the mob's name from it
        local mob = type(a1) == "string" and a1:match("^(.-) dies, you gain")
        if mob then SetSource(mob, "kill") end
    elseif event == "PLAYER_TARGET_CHANGED" then
        targetName = UnitExists("target") and UnitCanAttack("player", "target") and UnitName("target") or nil
    elseif event == "UNIT_HEALTH" then
        -- your target dying is the likeliest source of the next XP
        if a1 == "target" and targetName and UnitIsDead("target") then SetSource(targetName, "kill") end
    end
end)

-- for tests
JQ._XPChat = { Num = Num }
