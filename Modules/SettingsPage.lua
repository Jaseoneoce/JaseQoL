-------------------------------------------------------------------------------
--  JaseTools: Settings tab
--
--  The JaseTools window's Settings tab, the only settings page:
--    * groups down the left, with how many of their switches are on
--    * the group's switches on the right: name, what it does, an on/off
--      switch; settings that only work with another one on sit indented under
--      it and are greyed out while it's off
--    * a search box that looks through every switch (name, text, /jq key)
--    * "Reload UI" appears once a switch that needs a reload is changed
--  /jq, and a right-click on the J button or the minimap button, open it.
-------------------------------------------------------------------------------
local _, JQ = ...
local UI = JQ.UI

-- Groups of switches. An entry is a module key, or { key, { child keys } }:
-- children only work while their parent is on.
local GROUPS = {
    { "Experience", "XP in chat and XP colours", {
        { "xpChat", { "xpBreakdown", "xpMissedRested", "xpMissedFood" } }, "xpLevelColor" } },
    { "Quests", "Quest items and escorts", {
        "questItemGuard", "questBagCategory", { "escortGuard", { "escortAnnounce" } } } },
    { "Dungeon Journal", "The new journal view and its skin", { "djOverhaul", "djSkin" } },
    { "Alts, bank & mail", "Alt inventory, Send mats, Requests and crates", {
        { "altTracker", { "altTooltip", "altInventory", "bankMail", "altRequest" } } } },
    { "Selling & auction house", "Sell warnings and auction house help", { "boeGuard", "ahCopperWarn", "ahDebug" } },
    { "Professions", "The profession window", { "profResize" } },
    { "Skins", "EllesmereUI look for other addons", { "mcSkin", "gosSkin" } },
    { "Buttons", "Where to open JaseTools from", { "hubButton", "minimapButton" } },
}
local SLASH = {
    djOverhaul = "/jdj", altInventory = "/jinv", bankMail = "/jmats", ahDebug = "/jahlog",
}

local win, db
local reloadPending = false
local ROW_H, SIDE_W, GROUP_H = 54, 190, 34

-------------------------------------------------------------------------------
--  The rows: each group's switches, children right after their parent
-------------------------------------------------------------------------------
local placed = {}   -- keys that have a group

local function GroupRows(g)
    local rows = {}
    for _, entry in ipairs(g[3]) do
        local key, children = entry, nil
        if type(entry) == "table" then key, children = entry[1], entry[2] end
        local spec = JQ.byKey[key]
        if spec then
            rows[#rows + 1] = { spec = spec }
            placed[key] = true
            for _, ck in ipairs(children or {}) do
                local cspec = JQ.byKey[ck]
                if cspec then
                    rows[#rows + 1] = { spec = cspec, parent = key }
                    placed[ck] = true
                end
            end
        end
    end
    return rows
end

-- All groups, plus "More" for any switch not given a group yet.
local function AllGroups()
    local out = {}
    for _, g in ipairs(GROUPS) do
        local rows = GroupRows(g)
        if #rows > 0 then out[#out + 1] = { name = g[1], blurb = g[2], rows = rows } end
    end
    local extra = {}
    for _, spec in ipairs(JQ.modules) do
        if not placed[spec.key] then extra[#extra + 1] = { spec = spec } end
    end
    if #extra > 0 then out[#out + 1] = { name = "More", blurb = "Everything else", rows = extra } end
    return out
end

local function Blocked(row) return row.parent and not JQ.IsEnabled(row.parent) end

local function CountOn(rows)
    local on = 0
    for _, r in ipairs(rows) do if JQ.IsEnabled(r.spec.key) and not Blocked(r) then on = on + 1 end end
    return on, #rows
end

local function Matches(spec, needle)
    if needle == "" then return true end
    return (spec.label or ""):lower():find(needle, 1, true)
        or (spec.description or ""):lower():find(needle, 1, true)
        or spec.key:lower():find(needle, 1, true)
end

-------------------------------------------------------------------------------
--  An on/off switch: a track that fills with the accent colour, and a knob
-------------------------------------------------------------------------------
local function Switch(parent)
    local s = CreateFrame("Button", nil, parent)
    s:SetSize(40, 20)
    s.track = s:CreateTexture(nil, "BACKGROUND")
    s.track:SetAllPoints()
    s.track:SetColorTexture(1, 1, 1, 0.12)
    UI.Border(s, 0.9)
    s.knob = s:CreateTexture(nil, "ARTWORK")
    s.knob:SetSize(14, 14)
    s.knob:SetColorTexture(0.92, 0.92, 0.94, 1)
    local hl = s:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)
    function s:SetState(on, blocked)
        self.knob:ClearAllPoints()
        if on then
            local r, g, b = UI.Accent()
            self.track:SetColorTexture(r, g, b, blocked and 0.25 or 0.75)
            self.knob:SetPoint("RIGHT", -3, 0)
        else
            self.track:SetColorTexture(1, 1, 1, 0.12)
            self.knob:SetPoint("LEFT", 3, 0)
        end
        self.knob:SetAlpha(blocked and 0.4 or 1)
        self:SetAlpha(blocked and 0.6 or 1)
    end
    return s
end

-------------------------------------------------------------------------------
--  Tooltip
-------------------------------------------------------------------------------
local function RowTooltip(row)
    local spec = row.spec
    if not spec then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(spec.label, 1, 1, 1)
    GameTooltip:AddLine(spec.description or "", 0.85, 0.85, 0.88, true)
    if row.parent and not JQ.IsEnabled(row.parent) then
        local p = JQ.byKey[row.parent]
        GameTooltip:AddLine("Needs " .. (p and p.label or row.parent) .. " switched on.", 1, 0.45, 0.4, true)
    end
    if SLASH[spec.key] then GameTooltip:AddLine("Open with " .. SLASH[spec.key], 0.62, 0.62, 0.66) end
    if spec.needsReload then GameTooltip:AddLine("Changes after /reload.", 1, 0.82, 0.2) end
    GameTooltip:AddLine("Toggle: /jq " .. spec.key, 0.5, 0.5, 0.55)
    GameTooltip:Show()
end

local function Toggle(row)
    local spec = row.spec
    if not spec or Blocked(row) then return end
    JQ.SetEnabled(spec.key, not JQ.IsEnabled(spec.key))
    if spec.needsReload then reloadPending = true end
    win:Refresh()
end

-------------------------------------------------------------------------------
--  Window
-------------------------------------------------------------------------------
local function Build()
    JaseQoLDB.settingsWin = JaseQoLDB.settingsWin or {}
    db = JaseQoLDB.settingsWin
    win = UI.Window("JaseQoLSettings", "Settings", 780, 540, db)

    -- top bar: search, how many are on, Reload UI
    win.search = UI.SearchBox(win, "Search all settings", function() win:Refresh() end)
    win.search:SetPoint("TOPLEFT", 10, -32)
    win.search:SetWidth(SIDE_W + 70)

    win.reload = UI.Button(win, "Reload UI", 100, 22)
    win.reload:SetPoint("TOPRIGHT", -12, -31)
    win.reload:SetScript("OnClick", function() ReloadUI() end)
    win.reload:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Reload UI", 1, 1, 1)
        GameTooltip:AddLine("Some of the switches you changed only take effect after a reload.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    win.reload:SetScript("OnLeave", UI.HideTip)
    win.reload:Hide()

    win.summary = UI.Text(win, 11, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3], "RIGHT")
    win.summary:SetPoint("RIGHT", win.reload, "LEFT", -12, 0)

    -- left: the groups
    local side = UI.Panel(win)
    side:SetPoint("TOPLEFT", 10, -60)
    side:SetPoint("BOTTOMLEFT", 10, 10)
    side:SetWidth(SIDE_W)
    win.groupButtons = {}
    local function GroupButton(i)
        local b = win.groupButtons[i]
        if b then return b end
        b = CreateFrame("Button", nil, side)
        b:SetHeight(GROUP_H)
        b:SetPoint("TOPLEFT", 2, -2 - (i - 1) * GROUP_H)
        b:SetPoint("TOPRIGHT", -2, -2 - (i - 1) * GROUP_H)
        b.bg = UI.Fill(b, 1, 1, 1, 0)
        UI.Fill(b, 1, 1, 1, 0.05, "HIGHLIGHT")
        b.bar = b:CreateTexture(nil, "ARTWORK")
        b.bar:SetPoint("TOPLEFT"); b.bar:SetPoint("BOTTOMLEFT"); b.bar:SetWidth(3)
        b.name = UI.Text(b, 12)
        b.name:SetPoint("LEFT", 12, 0)
        b.count = UI.Text(b, 10, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3], "RIGHT")
        b.count:SetPoint("RIGHT", -10, 0)
        b.name:SetPoint("RIGHT", b.count, "LEFT", -6, 0)
        b:SetScript("OnClick", function(self)
            db.group = self.groupName
            win.search:SetText("")
            win.search:ClearFocus()
            win:Refresh()
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.groupName, 1, 1, 1)
            if self.blurb then GameTooltip:AddLine(self.blurb, 0.85, 0.85, 0.88, true) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", UI.HideTip)
        win.groupButtons[i] = b
        return b
    end

    -- right: the switches
    local main = UI.Panel(win)
    main:SetPoint("TOPLEFT", side, "TOPRIGHT", 8, 0)
    main:SetPoint("BOTTOMRIGHT", -10, 10)
    win.heading = UI.Text(main, 14)
    win.heading:SetPoint("TOPLEFT", 12, -10)
    win.blurb = UI.Text(main, 11, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3])
    win.blurb:SetPoint("LEFT", win.heading, "RIGHT", 10, 0)
    win.blurb:SetPoint("RIGHT", main, "RIGHT", -12, 0)
    local rule = main:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(1, 1, 1, 0.08)
    rule:SetPoint("TOPLEFT", 8, -32); rule:SetPoint("TOPRIGHT", -8, -32); rule:SetHeight(1)

    win.list = UI.List(main, ROW_H, function(L)
        local row = CreateFrame("Button", nil, L)
        row.hl = UI.Fill(row, 1, 1, 1, 0.04, "HIGHLIGHT")
        -- group heading (search results)
        row.head = UI.Text(row, 11)
        row.head:SetPoint("BOTTOMLEFT", 10, 8)
        -- a switch
        row.guide = row:CreateTexture(nil, "ARTWORK")
        row.guide:SetColorTexture(1, 1, 1, 0.14)
        row.guide:SetWidth(2)
        row.guide:SetPoint("TOPLEFT", 20, 0)
        row.guide:SetPoint("BOTTOMLEFT", 20, 0)
        row.switch = Switch(row)
        row.switch:SetPoint("RIGHT", -14, 0)
        row.switch.row = row
        row.switch:SetScript("OnClick", function(self) Toggle(self.row) end)
        row.switch:SetScript("OnEnter", function(self) RowTooltip(self.row) end)
        row.switch:SetScript("OnLeave", UI.HideTip)
        row.tag = UI.Text(row, 10, 0.62, 0.62, 0.66, "RIGHT")
        row.tag:SetPoint("RIGHT", row.switch, "LEFT", -12, 0)
        row.label = UI.Text(row, 13)
        row.desc = UI.Text(row, 11, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3])
        row.desc:SetWordWrap(true)
        if row.desc.SetMaxLines then row.desc:SetMaxLines(2) end
        row.desc:SetJustifyV("TOP")
        row.sep = row:CreateTexture(nil, "ARTWORK")
        row.sep:SetColorTexture(1, 1, 1, 0.05)
        row.sep:SetPoint("BOTTOMLEFT", 10, 0); row.sep:SetPoint("BOTTOMRIGHT", -10, 0); row.sep:SetHeight(1)
        row:SetScript("OnEnter", RowTooltip)
        row:SetScript("OnLeave", UI.HideTip)
        row:SetScript("OnClick", Toggle)
        return row
    end, function(row, d)
        row.spec, row.parent = d.spec, d.parent
        if d.header then
            row.head:SetText(("|cff%s%s|r"):format(UI.AccentHex(), d.header:upper()))
            row.head:Show(); row.hl:Hide(); row.guide:Hide(); row.sep:Hide()
            row.switch:Hide(); row.tag:Hide(); row.label:Hide(); row.desc:Hide()
            return
        end
        row.head:Hide(); row.hl:Show(); row.sep:Show()
        row.switch:Show(); row.label:Show(); row.desc:Show(); row.tag:Show()
        local x = d.parent and 34 or 14
        row.guide:SetShown(d.parent ~= nil)
        row.label:ClearAllPoints()
        row.label:SetPoint("TOPLEFT", x, -8)
        row.label:SetPoint("RIGHT", row.tag, "LEFT", -10, 0)
        row.desc:ClearAllPoints()
        row.desc:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -3)
        row.desc:SetPoint("RIGHT", row.switch, "LEFT", -14, 0)
        row.desc:SetHeight(28)

        local blocked = Blocked(d)
        local on = JQ.IsEnabled(d.spec.key)
        local lit = on and not blocked
        UI.SetFont(row.label, d.parent and 12 or 13)
        row.label:SetText(d.spec.label)
        row.label:SetTextColor(lit and 1 or 0.55, lit and 1 or 0.55, lit and 1 or 0.58)
        row.desc:SetText(d.spec.description or "")
        row.desc:SetAlpha(blocked and 0.45 or 1)
        row.switch:SetState(on, blocked)
        row.tag:SetText(d.spec.needsReload and "reload" or (SLASH[d.spec.key] or ""))
        row.tag:SetTextColor(d.spec.needsReload and 1 or 0.62, d.spec.needsReload and 0.82 or 0.62, d.spec.needsReload and 0.2 or 0.66)
    end)
    win.list:SetPoint("TOPLEFT", 4, -38)
    win.list:SetPoint("BOTTOMRIGHT", -4, 4)

    function win:Refresh()
        if not self:IsShown() then return end
        self.reload:SetShown(reloadPending)
        local groups = AllGroups()
        local needle = self.search:Needle()

        -- summary
        local on, total = 0, 0
        for _, g in ipairs(groups) do
            local a, b = CountOn(g.rows)
            on, total = on + a, total + b
        end
        self.summary:SetText(("%d of %d switched on"):format(on, total))

        -- the selected group (first one by default)
        local current
        for _, g in ipairs(groups) do if g.name == db.group then current = g end end
        current = current or groups[1]
        if current then db.group = current.name end

        -- sidebar
        for i, g in ipairs(groups) do
            local b = GroupButton(i)
            b.groupName, b.blurb = g.name, g.blurb
            b.name:SetText(g.name)
            local a, n = CountOn(g.rows)
            b.count:SetText(a .. "/" .. n)
            local sel = needle == "" and g == current
            local r, gg, bb = UI.Accent()
            b.bar:SetColorTexture(r, gg, bb, sel and 1 or 0)
            b.bg:SetVertexColor(1, 1, 1, sel and 0.07 or 0)
            b.name:SetTextColor(sel and 1 or 0.85, sel and 1 or 0.85, sel and 1 or 0.88)
            b:Show()
        end
        for i = #groups + 1, #self.groupButtons do self.groupButtons[i]:Hide() end

        -- main list: the group, or search results across every group
        local items = {}
        if needle ~= "" then
            local hits = 0
            for _, g in ipairs(groups) do
                local found = {}
                for _, r in ipairs(g.rows) do
                    if Matches(r.spec, needle) then found[#found + 1] = r end
                end
                if #found > 0 then
                    items[#items + 1] = { header = g.name }
                    for _, r in ipairs(found) do items[#items + 1] = r end
                    hits = hits + #found
                end
            end
            self.heading:SetText("Search")
            self.blurb:SetText(hits == 0 and "Nothing matches." or (hits .. " found"))
        elseif current then
            for _, r in ipairs(current.rows) do items[#items + 1] = r end
            self.heading:SetText(current.name)
            self.blurb:SetText(current.blurb or "")
        end
        self.list:SetItems(items, true)
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

-- Changes made elsewhere (/jq) show here too.
local origApply = JQ.ApplyChange
function JQ.ApplyChange(key, value)
    origApply(key, value)
    local spec = JQ.byKey[key]
    if spec and spec.needsReload then reloadPending = true end
    if win and win:IsShown() then win:Refresh() end
end

-- for tests
JQ._Settings = { AllGroups = AllGroups, Matches = Matches }
