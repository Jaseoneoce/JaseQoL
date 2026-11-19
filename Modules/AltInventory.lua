-------------------------------------------------------------------------------
--  JaseQoL: Alt inventory window  (/jinv)
--
--  Every item on your characters on this realm in one list: icon, name, the
--  total, and who has how many (bags / bank / mail). Search box, a chip per
--  character to narrow it to some of them, and Bags / Bank / Mail chips.
--  Uses the data Alt tracking records.
-------------------------------------------------------------------------------
local _, JQ = ...
local KEY = "altInventory"

JQ.AddModule({
    key = KEY,
    label = "Alt inventory window",
    description = "A window listing every item on all your characters on this realm, with search and per-character filters. /jinv opens it. Needs Alt tracking.",
    default = true,
})

local UI = JQ.UI
local win, state
local ROW_H = 30

local function Build()
    state = JaseQoLDB.altInventory or {}
    JaseQoLDB.altInventory = state
    state.places = state.places or { bags = true, bank = true, mail = true }
    state.only = state.only or {}

    win = UI.Window("JaseQoLAltInventory", "Alt Inventory", 720, 520, state)

    win.search = UI.SearchBox(win, "Search items", function() win:Refresh() end)
    win.search:SetPoint("TOPLEFT", 10, -32)
    win.search:SetPoint("TOPRIGHT", -10, -32)

    -- Character chips (multi-select; none selected = everyone)
    win.chipBar = CreateFrame("Frame", nil, win)
    win.chipBar:SetPoint("TOPLEFT", win.search, "BOTTOMLEFT", 0, -8)
    win.chipBar:SetPoint("TOPRIGHT", win.search, "BOTTOMRIGHT", 0, -8)
    win.chipBar:SetHeight(22)
    win.chips = {}

    -- Place chips
    win.placeBar = CreateFrame("Frame", nil, win)
    win.placeBar:SetPoint("TOPLEFT", win.chipBar, "BOTTOMLEFT", 0, -6)
    win.placeBar:SetPoint("TOPRIGHT", win.chipBar, "BOTTOMRIGHT", 0, -6)
    win.placeBar:SetHeight(22)
    local prev
    for _, p in ipairs({ { "bags", "Bags" }, { "bank", "Bank" }, { "mail", "Mail" } }) do
        local b = UI.Button(win.placeBar, p[2], 64, 22)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("LEFT") end
        b.key = p[1]
        b:SetScript("OnClick", function(self)
            state.places[self.key] = not state.places[self.key]
            win:Refresh()
        end)
        win["place_" .. p[1]] = b
        prev = b
    end
    win.summary = UI.Text(win.placeBar, 11, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3], "RIGHT")
    win.summary:SetPoint("RIGHT")

    local panel = UI.Panel(win)
    panel:SetPoint("TOPLEFT", win.placeBar, "BOTTOMLEFT", 0, -8)
    panel:SetPoint("BOTTOMRIGHT", -10, 10)

    win.list = UI.List(panel, ROW_H, function(L)
        local row = CreateFrame("Button", nil, L)
        UI.Fill(row, 1, 1, 1, 0.08, "HIGHLIGHT")
        row.stripe = UI.Fill(row, 1, 1, 1, 0.03)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(22, 22)
        row.icon:SetPoint("LEFT", 6, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.total = UI.Text(row, 13, 1, 1, 1, "RIGHT")
        row.total:SetPoint("RIGHT", -10, 0)
        row.total:SetWidth(60)
        row.name = UI.Text(row, 12)
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.name:SetWidth(220)
        row.who = UI.Text(row, 11, 0.85, 0.85, 0.88)
        row.who:SetPoint("LEFT", row.name, "RIGHT", 10, 0)
        row.who:SetPoint("RIGHT", row.total, "LEFT", -10, 0)
        row:SetScript("OnEnter", UI.ItemEnter)
        row:SetScript("OnLeave", UI.HideTip)
        row:SetScript("OnClick", UI.ItemClick)
        return row
    end, function(row, d, i)
        row.itemID = d.id
        row.stripe:SetShown(i % 2 == 0)
        row.icon:SetTexture(UI.ItemIcon(d.id))
        row.name:SetText(d.name)
        row.name:SetTextColor(UI.QualityColor(d.q))
        row.total:SetText(d.total)
        row.who:SetText(d.who)
    end)
    win.list:SetPoint("TOPLEFT", 4, -4)
    win.list:SetPoint("BOTTOMRIGHT", -4, 4)

    function win:BuildChips()
        for _, c in ipairs(self.chips) do c:Hide() end
        local x = 0
        for i, e in ipairs(JQ.Alts.List(false)) do
            local c = self.chips[i]
            if not c then
                c = UI.Button(self.chipBar, "", 80, 22)
                c:SetScript("OnClick", function(b)
                    state.only[b.alt] = not state.only[b.alt] or nil
                    win:Refresh()
                end)
                self.chips[i] = c
            end
            c.alt = e.name
            c.text:SetText(("|cff%s%s|r"):format(UI.ClassHex(e.data.class), e.display))
            local w = c.text:GetStringWidth() + 20
            c:SetWidth(w)
            c:ClearAllPoints()
            c:SetPoint("LEFT", self.chipBar, "LEFT", x, 0)
            x = x + w + 6
            c:Show()
        end
    end

    function win:Refresh()
        if not self:IsShown() then return end
        self:BuildChips()
        local anyOnly = next(state.only) ~= nil
        for _, c in ipairs(self.chips) do c:SetOn(state.only[c.alt] == true) end
        for _, k in ipairs({ "bags", "bank", "mail" }) do self["place_" .. k]:SetOn(state.places[k]) end

        local needle = self.search:Needle()
        local byItem, order = {}, {}
        local alts = JQ.Alts.List(false)
        for _, e in ipairs(alts) do
            if not anyOnly or state.only[e.name] then
                for place in pairs(state.places) do
                    if state.places[place] then
                        for id, n in pairs(e.data[place] or {}) do
                            local it = byItem[id]
                            if not it then
                                it = { id = id, total = 0, per = {} }
                                byItem[id] = it
                                order[#order + 1] = it
                            end
                            it.total = it.total + n
                            it.per[e.name] = (it.per[e.name] or 0) + n
                        end
                    end
                end
            end
        end
        local items = {}
        local classOf = {}
        local displayOf = {}
        for _, e in ipairs(alts) do classOf[e.name] = e.data.class; displayOf[e.name] = e.display end
        for _, it in ipairs(order) do
            it.name, it.q = UI.ItemNameQuality(it.id)
            if needle == "" or it.name:lower():find(needle, 1, true) then
                local names = {}
                for n in pairs(it.per) do names[#names + 1] = n end
                table.sort(names, function(a, b) return it.per[a] > it.per[b] end)
                local parts = {}
                for _, n in ipairs(names) do
                    parts[#parts + 1] = ("|cff%s%s|r %d"):format(UI.ClassHex(classOf[n]), displayOf[n] or n, it.per[n])
                end
                it.who = table.concat(parts, "   ")
                items[#items + 1] = it
            end
        end
        table.sort(items, function(a, b) return a.name < b.name end)
        self.summary:SetText(#items .. " items  •  " .. #alts .. " characters")
        self.list:SetItems(items, true)
    end

    win:SetScript("OnShow", function(self) self:Refresh() end)
    JQ.Alts.OnChange(function() if win:IsShown() then win:Refresh() end end)
    JQ.Hub.Attach(win, "inventory")
end

JQ.Hub.Register({
    key = "inventory", label = "Inventory",
    enabled = function() return JQ.IsEnabled(KEY) end,
    frame = function() return win end,
    open = function()
        if not JQ.IsEnabled(KEY) then return end
        if not win then Build() end
        return win
    end,
})

local function Toggle()
    if not JQ.IsEnabled(KEY) then JQ.Print("Alt inventory window is off (/jq altInventory).") return end
    if win and win:IsShown() then win:Hide() return end
    JQ.Hub.Show("inventory")
end
JQ.ToggleAltInventory = Toggle

JQ.byKey[KEY].onLoad = function()
    SLASH_JASEQOLINV1 = "/jinv"
    SlashCmdList.JASEQOLINV = Toggle
end
JQ.byKey[KEY].onDisable = function() if win then win:Hide() end end
