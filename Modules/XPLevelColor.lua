-------------------------------------------------------------------------------
--  JaseQoL: XP Level Colour  (was the EllesmereUIXPLevelColor plugin)
--
--  Replaces EllesmereUI.GetLevelDifficultyColor (used by the unit frame
--  "Level Text: Difficulty Color" option and by the nameplates) with the
--  classic mob-XP rule, so GREY means "this mob gives you no XP":
--
--    red     mob is 5+ levels above you
--    orange  mob is 3-4 levels above you
--    yellow  mob is within 2 levels of you
--    green   mob is 3+ levels below you but still gives XP
--    grey    mob is at or below your grey level (no XP)
--
--  Grey level (classic formula):
--    player 1-5   : 0 (nothing is grey)
--    player 6-39  : level - floor(level / 10) - 5
--    player 40-59 : level - floor(level / 5) - 1
--    player 60+   : level - 9
--
--  Toggle is live: when off, EllesmereUI's own colouring is used.
-------------------------------------------------------------------------------
local _, JQ = ...
local KEY = "xpLevelColor"

JQ.AddModule({
    key = KEY,
    label = "XP Level Colour",
    description = "Colours unit frame and nameplate level text by whether the mob gives XP: red, orange, yellow, green, grey (grey = no XP). Needs EllesmereUI's \"Level Text: Difficulty Color\" option on.",
    default = true,
})

local EUI = EllesmereUI
if not EUI or type(EUI.GetLevelDifficultyColor) ~= "function" then return end

local floor = math.floor

local function GrayLevel(pl)
    if pl <= 5 then return 0 end
    if pl <= 39 then return pl - floor(pl / 10) - 5 end
    if pl <= 59 then return pl - floor(pl / 5) - 1 end
    return pl - 9
end

-- Classic colours (Blizzard's QuestDifficultyColors), with literal fallbacks.
local function C(global, r, g, b)
    local c = _G[global]
    if c and c.r then return c.r, c.g, c.b end
    return r, g, b
end

local original = EUI.GetLevelDifficultyColor

function EUI.GetLevelDifficultyColor(level, attackable)
    if not JQ.IsEnabled(KEY) then
        return original(level, attackable)
    end
    if type(level) ~= "number" then return nil end
    -- Keep EllesmereUI's handling of "??" (skull) and non-attackable (gold).
    if level <= 0 or not attackable then
        return original(level, attackable)
    end
    local mine = UnitEffectiveLevel and UnitEffectiveLevel("player") or UnitLevel("player")
    if mine == nil or (issecretvalue and issecretvalue(mine)) then
        return original(level, attackable)
    end
    local diff = level - mine
    if diff >= 5 then
        return C("IMPOSSIBLE_DIFFICULTY_COLOR", 1.00, 0.10, 0.10)
    elseif diff >= 3 then
        return C("DIFFICULT_DIFFICULTY_COLOR", 1.00, 0.50, 0.25)
    elseif diff >= -2 then
        return C("FAIR_DIFFICULTY_COLOR", 1.00, 1.00, 0.00)
    elseif level > GrayLevel(mine) then
        return C("EASY_DIFFICULTY_COLOR", 0.25, 0.75, 0.25)
    else
        return C("TRIVIAL_DIFFICULTY_COLOR", 0.50, 0.50, 0.50)
    end
end
