-------------------------------------------------------------------------------
--  JaseQoL: one window, tabs, and a minimap button
--
--  The Alt Inventory (/jinv) and Send mats setup (/jmats) windows share one
--  place on screen and carry a tab bar ("Inventory" | "Send mats"): a tab
--  click swaps to the other window at the same position and size.
--  A J button on the minimap (drag it around the edge) and an entry in the
--  minimap's addon menu open the last tab; click again to close.
-------------------------------------------------------------------------------
local _, JQ = ...
local KEY = "hubButton"

JQ.AddModule({
    key = KEY,
    label = "Minimap button",
    description = "A J button on the minimap that opens the JaseQoL window (Inventory and Send mats tabs). Drag it around the minimap edge. Also in the minimap's addon menu.",
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
--  Minimap button
-------------------------------------------------------------------------------
local button

local function Place()
    local angle = math.rad(db.angle or 200)
    local r = (Minimap:GetWidth() / 2) + 6
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function Tooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText("JaseQoL", 1, 1, 1)
    GameTooltip:AddLine("Click: Inventory / Send mats", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click: settings", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Drag: move around the minimap", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

local function OpenSettings()
    if SlashCmdList.JASEQOL then SlashCmdList.JASEQOL("") end
end

local function BuildButton()
    button = CreateFrame("Button", "JaseQoLMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\AddOns\\JaseQoL\\Media\\icon")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    button:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then OpenSettings() else Hub.Toggle() end
    end)
    button:SetScript("OnEnter", Tooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            db.angle = math.deg(math.atan2(py / s - my, px / s - mx))
            Place()
        end)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    Place()
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
        if Minimap then
            BuildButton()
            button:SetShown(JQ.IsEnabled(KEY))
        end
    end)
end
JQ.byKey[KEY].onEnable = function() if button then button:Show() end end
JQ.byKey[KEY].onDisable = function() if button then button:Hide() end end
