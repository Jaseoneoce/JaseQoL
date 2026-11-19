-------------------------------------------------------------------------------
--  JaseQoL: one window, tabs, and a minimap button
--
--  The Alt Inventory (/jinv) and Send mats setup (/jmats) windows share one
--  place on screen and carry a tab bar ("Inventory" | "Send mats"): a tab
--  click swaps to the other window at the same position and size.
--  A J button you can put anywhere on screen (drag to move) and an
--  entry in the minimap's addon menu open the last tab; click again to close.
-------------------------------------------------------------------------------
local _, JQ = ...
local KEY = "hubButton"

JQ.AddModule({
    key = KEY,
    label = "JaseQoL button",
    description = "A J button you can drag anywhere on screen; it opens the JaseQoL window (Inventory and Send mats tabs). Drag it to move it. Also in the minimap's addon menu.",
    default = true,
})

local UI = JQ.UI
local Hub = { tabs = {}, byKey = {} }
local tabsOf = setmetatable({}, { __mode = "k" })   -- frame -> { key, buttons }
JQ.Hub = Hub
local db

-- spec = { key, label, open = fn() -> frame, frame = fn() -> frame|nil, enabled = fn() -> bool }
function Hub.Register(spec)
    if Hub.byKey[spec.key] then return end
    Hub.tabs[#Hub.tabs + 1] = spec
    Hub.byKey[spec.key] = spec
end

local function CurrentFrame()
    for _, t in ipairs(Hub.tabs) do
        local f = t.frame()
        if f and f:IsShown() then return f, t end
    end
end

function Hub.IsOpen() return CurrentFrame() ~= nil end

function Hub.Show(key)
    local spec = Hub.byKey[key]
    if not spec or (spec.enabled and not spec.enabled()) then
        -- fall back to the first tab that's switched on
        spec = nil
        for _, t in ipairs(Hub.tabs) do
            if not t.enabled or t.enabled() then spec = t; break end
        end
        if not spec then JQ.Print("Inventory and Send mats are both switched off (/jq).") return end
    end
    local cur = CurrentFrame()
    local target = spec.open()
    if not target then return end
    if cur and cur ~= target then
        -- same place, same size
        local p, rel, rp, x, y = cur:GetPoint()
        target:ClearAllPoints()
        target:SetPoint(p, rel or UIParent, rp, x, y)
        target:SetSize(cur:GetSize())
        cur:Hide()
    end
    target:Show()
    if target.Raise then target:Raise() end
    if db then db.lastTab = spec.key end
    Hub.UpdateTabs()
end

function Hub.Toggle()
    local cur = CurrentFrame()
    if cur then cur:Hide() return end
    Hub.Show((db and db.lastTab) or (Hub.tabs[1] and Hub.tabs[1].key))
end

-- Tab bar on a window built by a module: title becomes "JaseQoL", tabs after it.
function Hub.Attach(frame, key)
    if not frame or tabsOf[frame] then return end
    local entry = { key = key, buttons = {} }
    tabsOf[frame] = entry
    frame.hubTabs = entry.buttons
    frame.title:SetText("JaseQoL")
    local prev = frame.title
    for _, t in ipairs(Hub.tabs) do
        local b = UI.Button(frame, t.label, 96, 20)
        b:SetPoint("LEFT", prev, "RIGHT", prev == frame.title and 14 or 4, 0)
        b.key = t.key
        b:SetScript("OnClick", function(self) Hub.Show(self.key) end)
        entry.buttons[#entry.buttons + 1] = b
        prev = b
    end
    frame:HookScript("OnShow", Hub.UpdateTabs)
    Hub.UpdateTabs()
end

function Hub.UpdateTabs()
    for _, t in ipairs(Hub.tabs) do
        local f = t.frame()
        local entry = f and tabsOf[f]
        if entry then
            for _, b in ipairs(entry.buttons) do
                local spec = Hub.byKey[b.key]
                b:SetShown(not spec.enabled or spec.enabled())
                b:SetOn(b.key == entry.key)
            end
        end
    end
end

-------------------------------------------------------------------------------
--  Floating J button (drag anywhere; position saved)
-------------------------------------------------------------------------------
local button

local function Tooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText("JaseQoL", 1, 1, 1)
    GameTooltip:AddLine("Click: Inventory / Send mats", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click: settings", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Drag: move it anywhere", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

local function OpenSettings()
    if SlashCmdList.JASEQOL then SlashCmdList.JASEQOL("") end
end

local function SavePos()
    local p, _, rp, x, y = button:GetPoint()
    db.button = { p, rp, x, y }
end

local function BuildButton()
    button = CreateFrame("Button", "JaseQoLButton", UIParent)
    button:SetSize(36, 36)
    button:SetFrameStrata("MEDIUM")
    button:SetClampedToScreen(true)
    button:SetMovable(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    local pos = db.button
    if pos then
        button:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        button:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    end
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\AddOns\\JaseQoL\\Media\\icon")
    icon:SetAllPoints()
    local hl = button:CreateTexture(nil, "HIGHLIGHT")
    hl:SetColorTexture(1, 1, 1, 0.15)
    hl:SetAllPoints()
    button:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then OpenSettings() else Hub.Toggle() end
    end)
    button:SetScript("OnEnter", Tooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Dragging only starts once the mouse moves, so a click never nudges it.
    button:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePos()
    end)
end

-- Minimap addon menu (AddonCompartmentFunc in the toc)
function JaseQoL_OnAddonCompartmentClick(_, mouse)
    if mouse == "RightButton" then OpenSettings() else Hub.Toggle() end
end
function JaseQoL_OnAddonCompartmentEnter(_, frame) Tooltip(frame) end
function JaseQoL_OnAddonCompartmentLeave() GameTooltip:Hide() end

JQ.byKey[KEY].onLoad = function(enabled)
    JaseQoLDB.hub = JaseQoLDB.hub or {}
    db = JaseQoLDB.hub
    local boot = CreateFrame("Frame")
    boot:RegisterEvent("PLAYER_LOGIN")
    boot:SetScript("OnEvent", function()
        BuildButton()
        button:SetShown(JQ.IsEnabled(KEY))
    end)
end
JQ.byKey[KEY].onEnable = function() if button then button:Show() end end
JQ.byKey[KEY].onDisable = function() if button then button:Hide() end end
