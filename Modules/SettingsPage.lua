-------------------------------------------------------------------------------
--  JaseQoL: Settings tab
--
--  A "Settings" tab in the JaseQoL window: every tweak in groups, with an
--  On/Off switch, a one-line description and a tooltip with the full text.
--  Tweaks that change only after a reload say so, and a "Reload UI" button
--  appears once one of them is switched. /jq and a right-click on the J button
--  open it.
-------------------------------------------------------------------------------
local _, JQ = ...
local UI = JQ.UI

local GROUPS = {
    { "Dungeon Journal", { "djOverhaul", "djSkin" } },
    { "Alts, bank & mail", { "altTracker", "altTooltip", "altInventory", "bankMail", "altRequest" } },
    { "Unit frames & nameplates", { "xpLevelColor" } },
    { "Skins", { "mcSkin", "gosSkin" } },
    { "Professions", { "profResize" } },
    { "Other", { "boeGuard", "ahCopperWarn", "ahDebug", "escortGuard", "escortAnnounce", "hubButton" } },
}
local SLASH = {
    djOverhaul = "/jdj", altInventory = "/jinv", bankMail = "/jmats", ahDebug = "/jahlog",
}

local win, db
local reloadPending = false
local ROW_H = 44

local function Items()
    local items, seen = {}, {}
    for _, g in ipairs(GROUPS) do
        local rows = {}
        for _, key in ipairs(g[2]) do
            local spec = JQ.byKey[key]
            if spec then rows[#rows + 1] = { spec = spec }; seen[key] = true end
        end
        if #rows > 0 then
            items[#items + 1] = { header = g[1] }
            for _, r in ipairs(rows) do items[#items + 1] = r end
        end
    end
    -- anything not in a group yet
    local extra = {}
    for _, spec in ipairs(JQ.modules) do
        if not seen[spec.key] then extra[#extra + 1] = { spec = spec } end
    end
    if #extra > 0 then
        items[#items + 1] = { header = "More" }
        for _, r in ipairs(extra) do items[#items + 1] = r end
    end
    return items
end

local function RowTooltip(row)
    local spec = row.spec
    if not spec then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(spec.label, 1, 1, 1)
    GameTooltip:AddLine(spec.description or "", 0.85, 0.85, 0.88, true)
    if SLASH[spec.key] then GameTooltip:AddLine("Open with " .. SLASH[spec.key], 0.62, 0.62, 0.66) end
    if spec.needsReload then GameTooltip:AddLine("Changes after /reload.", 1, 0.82, 0.2) end
    GameTooltip:AddLine("Toggle: /jq " .. spec.key, 0.5, 0.5, 0.55)
    GameTooltip:Show()
end

local function Build()
    JaseQoLDB.settingsWin = JaseQoLDB.settingsWin or {}
    db = JaseQoLDB.settingsWin
    win = UI.Window("JaseQoLSettings", "Settings", 720, 520, db)

    local intro = UI.Text(win, 11, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3])
    intro:SetPoint("TOPLEFT", 12, -34)
    intro:SetText("Switch any tweak on or off. Hover one for the details.")

    win.reload = UI.Button(win, "Reload UI", 100, 22)
    win.reload:SetPoint("TOPRIGHT", -12, -30)
    win.reload:SetScript("OnClick", function() ReloadUI() end)
    win.reload:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Reload UI", 1, 1, 1)
        GameTooltip:AddLine("Some of the switches you changed only take effect after a reload.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    win.reload:SetScript("OnLeave", UI.HideTip)
    win.reload:Hide()

    local panel = UI.Panel(win)
    panel:SetPoint("TOPLEFT", 10, -58)
    panel:SetPoint("BOTTOMRIGHT", -10, 10)

    win.list = UI.List(panel, ROW_H, function(L)
        local row = CreateFrame("Button", nil, L)
        row.hl = UI.Fill(row, 1, 1, 1, 0.05, "HIGHLIGHT")
        row.head = UI.Text(row, 12)
        row.head:SetPoint("BOTTOMLEFT", 8, 8)
        row.line = row:CreateTexture(nil, "ARTWORK")
        row.line:SetColorTexture(1, 1, 1, 0.08)
        row.line:SetPoint("BOTTOMLEFT", 4, 4); row.line:SetPoint("BOTTOMRIGHT", -4, 4); row.line:SetHeight(1)

        row.switch = UI.Button(row, "Off", 56, 22)
        row.switch.row = row
        row.switch:SetPoint("RIGHT", -10, 0)
        row.switch:SetScript("OnClick", function(self)
            local spec = self.row.spec
            if not spec then return end
            JQ.SetEnabled(spec.key, not JQ.IsEnabled(spec.key))
            if spec.needsReload then reloadPending = true end
            win:Refresh()
        end)
        row.switch:SetScript("OnEnter", function(self) RowTooltip(self.row) end)
        row.switch:SetScript("OnLeave", UI.HideTip)
        row.tag = UI.Text(row, 10, 1, 0.82, 0.2, "RIGHT")
        row.tag:SetPoint("RIGHT", row.switch, "LEFT", -10, 0)
        row.label = UI.Text(row, 13)
        row.label:SetPoint("TOPLEFT", 12, -6)
        row.label:SetPoint("RIGHT", row.tag, "LEFT", -10, 0)
        row.desc = UI.Text(row, 11, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3])
        row.desc:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -4)
        row.desc:SetPoint("RIGHT", row.switch, "LEFT", -10, 0)
        row:SetScript("OnEnter", RowTooltip)
        row:SetScript("OnLeave", UI.HideTip)
        row:SetScript("OnClick", function(self) if self.spec then self.switch:Click() end end)
        return row
    end, function(row, d)
        row.spec = d.spec
        if d.header then
            row.head:SetText(("|cff%s%s|r"):format(UI.AccentHex(), d.header:upper()))
            row.head:Show(); row.line:Show(); row.hl:Hide()
            row.switch:Hide(); row.tag:Hide(); row.label:Hide(); row.desc:Hide()
            return
        end
        row.head:Hide(); row.line:Hide(); row.hl:Show()
        row.switch:Show(); row.label:Show(); row.desc:Show(); row.tag:Show()
        local on = JQ.IsEnabled(d.spec.key)
        row.label:SetText(d.spec.label)
        row.label:SetTextColor(on and 1 or 0.6, on and 1 or 0.6, on and 1 or 0.62)
        row.desc:SetText(d.spec.description or "")
        row.switch.text:SetText(on and "On" or "Off")
        row.switch:SetOn(on)
        row.tag:SetText(d.spec.needsReload and "reload" or (SLASH[d.spec.key] or ""))
        row.tag:SetTextColor(d.spec.needsReload and 1 or 0.62, d.spec.needsReload and 0.82 or 0.62, d.spec.needsReload and 0.2 or 0.66)
    end)
    win.list:SetPoint("TOPLEFT", 4, -4)
    win.list:SetPoint("BOTTOMRIGHT", -4, 4)

    function win:Refresh()
        if not self:IsShown() then return end
        self.reload:SetShown(reloadPending)
        self.list:SetItems(Items(), true)
    end
    win:SetScript("OnShow", function(self) self:Refresh() end)
    JQ.Hub.Attach(win, "settings")
end

JQ.Hub.Register({
    key = "settings", label = "Settings",
    frame = function() return win end,
    open = function()
        if not win then Build() end
        return win
    end,
})

function JQ.OpenSettings() JQ.Hub.Show("settings") end

-- Changes made elsewhere (/jq, the game's Options page) show here too.
local origApply = JQ.ApplyChange
function JQ.ApplyChange(key, value)
    origApply(key, value)
    local spec = JQ.byKey[key]
    if spec and spec.needsReload then reloadPending = true end
    if win and win:IsShown() then win:Refresh() end
end
