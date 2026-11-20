-------------------------------------------------------------------------------
--  JaseQoL: auction house warning after /reload
--
--  On WoW Forever, posting at the auction house after a /reload lists the
--  first item and then times out (scans still work); a relog fixes it. When
--  the auction house opens and the interface has been reloaded since login,
--  this says so on screen, in chat and in a banner above the auction house.
-------------------------------------------------------------------------------
local _, JQ = ...
local KEY = "ahReloadWarn"

JQ.AddModule({
    key = KEY,
    label = "Warn at the auction house after /reload",
    description = "After a /reload, posting at the auction house lists one item and then times out until you relog. When you open the auction house after a /reload, a warning tells you to relog (/camp, then log back in) before posting. Scanning is fine either way.",
    default = true,
})

local reloaded = false   -- has the interface been reloaded since this login?
local warnedThisVisit = false
local banner

local MSG = "You've used /reload since logging in. Posting may time out after the first item: relog (/camp, then log back in) before you post. Scanning is fine."

local function AHFrame()
    return _G.AuctionHouseFrame or _G.AuctionFrame
end

local function Banner()
    if banner then return banner end
    banner = CreateFrame("Frame", "JaseQoLAHReloadWarn", UIParent)
    banner:SetSize(520, 46)
    banner:SetFrameStrata("HIGH")
    banner:Hide()
    local bg = banner:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.12, 0.03, 0.03, 0.92)
    local edge = banner:CreateTexture(nil, "BORDER")
    edge:SetPoint("TOPLEFT"); edge:SetPoint("BOTTOMLEFT"); edge:SetWidth(3)
    edge:SetColorTexture(1, 0.3, 0.25, 1)
    banner.text = banner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    banner.text:SetPoint("TOPLEFT", 12, -6)
    banner.text:SetPoint("BOTTOMRIGHT", -30, 6)
    banner.text:SetJustifyH("LEFT")
    banner.text:SetTextColor(1, 0.55, 0.5)
    banner.text:SetText(MSG)
    local close = CreateFrame("Button", nil, banner, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() banner:Hide() end)
    return banner
end

local function Warn()
    if not (JQ.IsEnabled(KEY) and reloaded) or warnedThisVisit then return end
    warnedThisVisit = true
    JQ.Print("|cffff6050" .. MSG .. "|r")
    if RaidNotice_AddMessage and RaidWarningFrame then
        RaidNotice_AddMessage(RaidWarningFrame, "Relog before posting: /reload breaks auction posting",
            ChatTypeInfo and ChatTypeInfo.RAID_WARNING or { r = 1, g = 0.3, b = 0.2 })
    end
    local b = Banner()
    b:ClearAllPoints()
    local ah = AHFrame()
    if ah and ah.IsShown and ah:IsShown() then
        b:SetPoint("BOTTOM", ah, "TOP", 0, 6)
    else
        b:SetPoint("TOP", UIParent, "TOP", 0, -120)
    end
    b:Show()
end

local function Closed()
    warnedThisVisit = false
    if banner then banner:Hide() end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
for _, e in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED",
    "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event, a1, a2)
    if event == "PLAYER_ENTERING_WORLD" then
        if a1 then reloaded = false elseif a2 then reloaded = true end
        return
    end
    if event == "AUCTION_HOUSE_SHOW" then
        -- the frame shows on the same event; anchor once it's up
        if C_Timer then C_Timer.After(0, Warn) else Warn() end
    elseif event == "AUCTION_HOUSE_CLOSED" then
        Closed()
    else
        local PIT = Enum and Enum.PlayerInteractionType
        if not (PIT and PIT.Auctioneer and a1 == PIT.Auctioneer) then return end
        if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
            if C_Timer then C_Timer.After(0, Warn) else Warn() end
        else
            Closed()
        end
    end
end)

JQ.byKey[KEY].onDisable = function() if banner then banner:Hide() end end

-- for tests
JQ._AHReloadWarn = { IsReloaded = function() return reloaded end }
