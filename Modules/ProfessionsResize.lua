-------------------------------------------------------------------------------
--  JaseTools: Resizable profession window
--
--  The game's profession window (ProfessionsFrame, the modern one WoW Forever
--  uses) gets a grip in its bottom-right corner: drag to make it bigger, and
--  that size is put back every time it opens. The game's own small view is
--  left as it is. Right-click the grip to go back to the default size.
--  Only size is changed (no Blizzard code replaced), and never in combat.
-------------------------------------------------------------------------------
local _, JQ = ...
local KEY = "profResize"

JQ.AddModule({
    key = KEY,
    label = "Resizable profession window",
    description = "Adds a grip to the bottom-right corner of the profession window: drag to make it bigger and it stays that size. Right-click the grip to reset. The game's own small view is left alone.",
    default = true,
})

local db
local frame, grip
local baseW, baseH      -- the game's normal (not small view) size, seen first time
local busy = false

local function Saved()
    return db.size and db.size[1], db.size and db.size[2]
end

-- Put our size back after the game sets its own (tab change, reopening).
local function Apply()
    if not (frame and baseW) or busy or InCombatLockdown() then return end
    if not JQ.IsEnabled(KEY) then return end
    local w, h = Saved()
    if not w then return end
    local cw, ch = frame:GetSize()
    -- the game's small view is narrower than its normal size: leave that alone
    if cw < baseW - 2 then return end
    if math.abs(cw - w) < 1 and math.abs(ch - h) < 1 then return end
    busy = true
    frame:SetSize(w, h)
    busy = false
end

local function Setup()
    if frame or not ProfessionsFrame then return end
    frame = ProfessionsFrame
    baseW, baseH = frame:GetSize()
    if not baseW or baseW < 100 then baseW, baseH = nil, nil end

    frame:SetResizable(true)
    if frame.SetResizeBounds and baseW then frame:SetResizeBounds(baseW, baseH, 1800, 1200) end

    grip = CreateFrame("Button", "JaseQoLProfessionsGrip", frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -3, 3)
    grip:SetFrameLevel(frame:GetFrameLevel() + 20)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:RegisterForClicks("RightButtonUp")
    grip:SetScript("OnMouseDown", function(_, mouse)
        if mouse ~= "LeftButton" or InCombatLockdown() then return end
        if not baseW then baseW, baseH = frame:GetSize() end
        frame:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp", function(_, mouse)
        if mouse ~= "LeftButton" then return end
        frame:StopMovingOrSizing()
        db.size = { frame:GetWidth(), frame:GetHeight() }
    end)
    grip:SetScript("OnClick", function()
        if InCombatLockdown() or not baseW then return end
        db.size = nil
        busy = true
        frame:SetSize(baseW, baseH)
        busy = false
        JQ.Print("Profession window back to its default size.")
    end)
    grip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Resize", 1, 1, 1)
        GameTooltip:AddLine("Drag to resize the profession window.", 0.85, 0.85, 0.88)
        GameTooltip:AddLine("Right-click: default size.", 0.85, 0.85, 0.88)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    grip:SetShown(JQ.IsEnabled(KEY))

    -- The game sizes the window itself when it opens and when tabs / the small
    -- view change it: put ours back right after.
    local function GameSized()
        if busy then return end
        -- the biggest size the game itself sets is its normal (not small) view
        local w, h = frame:GetSize()
        if w and (not baseW or w > baseW + 1) then
            baseW, baseH = w, h
            if frame.SetResizeBounds then frame:SetResizeBounds(baseW, baseH, 1800, 1200) end
        end
        C_Timer.After(0, Apply)
    end
    hooksecurefunc(frame, "SetSize", GameSized)
    hooksecurefunc(frame, "SetWidth", GameSized)
    frame:HookScript("OnShow", function() C_Timer.After(0, Apply) end)
    Apply()
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name ~= "Blizzard_Professions" then return end
    if not JQ.IsEnabled(KEY) then return end
    Setup()
    if event == "TRADE_SKILL_SHOW" then C_Timer.After(0, Apply) end
end)

JQ.byKey[KEY].onLoad = function()
    JaseQoLDB.profResize = JaseQoLDB.profResize or {}
    db = JaseQoLDB.profResize
    ev:RegisterEvent("ADDON_LOADED")
    ev:RegisterEvent("TRADE_SKILL_SHOW")
end
JQ.byKey[KEY].onEnable = function()
    if grip then grip:Show() end
    Setup()
end
JQ.byKey[KEY].onDisable = function()
    if grip then grip:Hide() end
    if frame and baseW and not InCombatLockdown() then
        busy = true
        frame:SetSize(baseW, baseH)
        busy = false
    end
end
