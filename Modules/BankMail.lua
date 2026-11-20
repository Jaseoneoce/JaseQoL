-------------------------------------------------------------------------------
--  JaseQoL: Send mats to bank alts
--
--  Setup (/jmats, or "Setup" on the mailbox panel):
--    * Categories = professions (+ "Bank" for anything a pure bank alt keeps).
--    * Assign items to one or more categories: drop an item on the box, or add
--      it (or a whole item type) from the "In your bags" list.
--    * Who gets what: each alt receives the categories of the professions it
--      has (read by Alt tracking); tick or untick categories per alt to change it.
--  Mailbox: a panel beside the mail window lists your alts on this realm and
--  faction. Pick one, check the list of what will go, press "Send mats": every
--  unbound stack in your bags assigned to that alt's categories is mailed,
--  12 attachments per mail, as many mails as needed.
--
--  JaseQoLDB.bankMail = { mats = {[itemID] = {[category]=true}},
--    receives = {[realm] = {[alt] = {[category]=true|false}}}, lastAlt }
-------------------------------------------------------------------------------
local _, JQ = ...
local KEY = "bankMail"

JQ.AddModule({
    key = KEY,
    label = "Send mats to bank alts",
    description = "Assign materials to professions, then send them from the mailbox to the alt with that profession in one click. /jmats sets it up. Needs Alt tracking.",
    default = true,
})

local UI = JQ.UI
local Alts
local db
local C = C_Container
local MAX_ATTACH = ATTACHMENTS_MAX_SEND or 12
local BANK_CAT = "Bank"

local function Categories()
    local out = {}
    for _, p in ipairs(Alts.PROFESSIONS) do out[#out + 1] = p end
    out[#out + 1] = BANK_CAT
    return out
end

-------------------------------------------------------------------------------
--  Rules
-------------------------------------------------------------------------------
local function ReceivesTable(alt)
    local realm = Alts.Realm()
    db.receives[realm] = db.receives[realm] or {}
    db.receives[realm][alt] = db.receives[realm][alt] or {}
    return db.receives[realm][alt]
end

-- Does this alt get this category? Override first, else "has the profession".
local function Receives(alt, cat)
    local o = ReceivesTable(alt)[cat]
    if o ~= nil then return o end
    local data = Alts.RealmTable()[alt]
    return data and data.profs and data.profs[cat] ~= nil or false
end

local function AltCategories(alt)
    local out = {}
    for _, c in ipairs(Categories()) do
        if Receives(alt, c) then out[#out + 1] = c end
    end
    return out
end

local function ItemGoesTo(id, alt)
    local cats = db.mats[id]
    if not cats then return false end
    for c in pairs(cats) do
        if Receives(alt, c) then return true end
    end
    return false
end

-- "Also send all BoE gear" per category (Enchanting on by default):
-- unbound Bind-on-Equip weapons and armour go to alts receiving that category.
local GetItemInfoFn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local BIND_ON_EQUIP = (Enum and Enum.ItemBind and Enum.ItemBind.OnEquip) or 2
local GEAR_CLASS = { [2] = true, [4] = true }   -- Weapon, Armor

local function BoEGearOn(cat)
    local v = db.boeGear[cat]
    if v == nil then return cat == "Enchanting" end
    return v
end

local function IsBoEGear(link)
    if not link then return false end
    local _, _, _, _, _, _, _, _, _, _, _, classID, _, bindType = GetItemInfoFn(link)
    return bindType == BIND_ON_EQUIP and GEAR_CLASS[classID] or false
end

local function GetsBoEGear(alt)
    for _, c in ipairs(Categories()) do
        if BoEGearOn(c) and Receives(alt, c) then return true end
    end
    return false
end

local function Assign(id, cat, on)
    if not id or not cat then return end
    db.mats[id] = db.mats[id] or {}
    db.mats[id][cat] = on and true or nil
    if not next(db.mats[id]) then db.mats[id] = nil end
end

-- Stacks in my bags for an alt: { {bag, slot, id, count}, ... } (unbound only).
local function StacksFor(alt)
    local out = {}
    local boe = GetsBoEGear(alt)
    for _, bag in ipairs(Alts.BagIDs()) do
        local n = (C and C.GetContainerNumSlots and C.GetContainerNumSlots(bag)) or 0
        for slot = 1, n do
            local id, count, isBound, link = Alts.SlotInfo(bag, slot)
            if id and not isBound and (ItemGoesTo(id, alt) or (boe and IsBoEGear(link))) then
                out[#out + 1] = { bag = bag, slot = slot, id = id, count = count or 1 }
            end
        end
    end
    return out
end

-------------------------------------------------------------------------------
--  Sending (12 attachments per mail, next mail after MAIL_SEND_SUCCESS)
-------------------------------------------------------------------------------
local job          -- { to, queue, sentNow = {[id]=n}, mails, cancelled }
local panel        -- mailbox panel (forward)

-- On the panel (two lines, wrapped) and, unless it's a progress line, in chat.
local function Status(text, quiet)
    if panel and panel.status then panel.status:SetText(text or "") end
    if text and text ~= "" and not quiet then JQ.Print(text) end
end

local function FirstFreeAttachSlot()
    for i = 1, MAX_ATTACH do
        if not HasSendMailItem(i) then return i end
    end
end

local function AnyAttached()
    for i = 1, MAX_ATTACH do
        if HasSendMailItem(i) then return true end
    end
    return false
end

local function Finish(msg)
    if job and job.to and next(job.sent) then Alts.AddMail(job.to, job.sent) end
    job = nil
    Status(msg)
    if panel then panel:Refresh() end
end

local SendNext

local function OpenSendTab()
    if MailFrameTab2 and MailFrameTab2.Click and not (SendMailFrame and SendMailFrame:IsShown()) then
        MailFrameTab2:Click()
    end
end

function SendNext()
    if not job then return end
    if not (MailFrame and MailFrame:IsShown()) then return Finish("Mailbox closed: stopped.") end
    OpenSendTab()
    local attached, batch = 0, {}
    while attached < MAX_ATTACH and #job.queue > 0 do
        local e = table.remove(job.queue, 1)
        local id, count, isBound = Alts.SlotInfo(e.bag, e.slot)
        if id == e.id and not isBound then
            local slotIndex = FirstFreeAttachSlot()
            if not slotIndex then break end
            ClearCursor()
            C.PickupContainerItem(e.bag, e.slot)
            ClickSendMailItemButton(slotIndex)
            ClearCursor()
            attached = attached + 1
            batch[id] = (batch[id] or 0) + (count or 1)
        end
    end
    if attached == 0 then
        return Finish(job.mails > 0 and ("Done: " .. job.mails .. " mail(s) sent to " .. Alts.Display(job.to)) or "Nothing left to send.")
    end
    local price = GetSendMailPrice and GetSendMailPrice() or 0
    if price > GetMoney() then
        ClearSendMail()
        return Finish("Not enough money for postage.")
    end
    job.batch = batch
    job.mails = job.mails + 1
    local cats = table.concat(AltCategories(job.to), ", ")
    Status(("Sending mail %d to %s..."):format(job.mails, Alts.Display(job.to)), true)
    SendMail(Alts.MailName(job.to), "Mats" .. (cats ~= "" and (": " .. cats) or ""), "Sent by JaseQoL")
end

local function StartSend(alt)
    if job then return end
    if not (MailFrame and MailFrame:IsShown()) then return end
    if alt == Alts.MyName() then return end
    if InCombatLockdown() then Status("Not in combat.") return end
    OpenSendTab()
    if AnyAttached() then
        Status("Clear the attachments already on the Send Mail page first.")
        return
    end
    local queue = StacksFor(alt)
    if #queue == 0 then Status("Nothing in your bags for " .. Alts.Display(alt)) return end
    if not Alts.HasFullName(alt) then pcall(Alts.LearnNames) end
    if not Alts.HasFullName(alt) then
        Status("Can't send yet: mail needs " .. alt .. "'s full name. Log in on " .. alt .. " once so JaseQoL learns their last name.")
        return
    end
    job = { to = alt, queue = queue, sent = {}, mails = 0 }
    SendNext()
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event)
    if event == "MAIL_SHOW" then
        if panel then panel:Refresh() end
        return
    end
    if not job then return end
    if event == "MAIL_SEND_SUCCESS" then
        for id, n in pairs(job.batch or {}) do job.sent[id] = (job.sent[id] or 0) + n end
        job.batch = nil
        C_Timer.After(0.4, SendNext)
    elseif event == "MAIL_FAILED" then
        ClearSendMail()
        Finish("The mail failed: stopped after " .. (job.mails - 1) .. " mail(s).")
    elseif event == "MAIL_CLOSED" then
        Finish("Mailbox closed: stopped.")
    end
end)

-------------------------------------------------------------------------------
--  Mailbox panel
-------------------------------------------------------------------------------
local OpenSetup

local function BuildPanel()
    panel = CreateFrame("Frame", "JaseQoLSendMats", MailFrame)
    panel:SetSize(270, 430)
    -- Beside the mail window, or beside EllesmereUI's alt list when it sits
    -- on the right of the Send Mail page.
    -- Right of everything the mailbox has open: the mail window, an open
    -- letter (OpenMailFrame, shown beside it while reading a mail) and
    -- EllesmereUI's alt list. With no room on the right of the screen it goes
    -- on the left of the leftmost of them instead.
    local hooked = setmetatable({}, { __mode = "k" })
    local function Watch(f)
        if f and not hooked[f] and f.HookScript then
            hooked[f] = true
            local again = function() C_Timer.After(0, function() panel.anchorSig = nil; panel:Reanchor() end) end
            f:HookScript("OnShow", again)
            f:HookScript("OnHide", again)
        end
    end
    function panel:Reanchor()
        local frames = { MailFrame }
        local letter, eui = _G.OpenMailFrame, _G.EllesmereUIMailAltList
        Watch(letter); Watch(eui)
        if letter and letter:IsVisible() then frames[#frames + 1] = letter end
        if eui and eui:IsVisible() then frames[#frames + 1] = eui end
        local rightmost, leftmost = MailFrame, MailFrame
        for _, f in ipairs(frames) do
            local r, l = f:GetRight(), f:GetLeft()
            if r and rightmost:GetRight() and r > rightmost:GetRight() then rightmost = f end
            if l and leftmost:GetLeft() and l < leftmost:GetLeft() then leftmost = f end
        end
        local side = "right"
        local sw = UIParent:GetRight()
        local rr = rightmost:GetRight()
        if rr and sw and rr + 8 + self:GetWidth() > sw then side = "left" end
        local to = side == "right" and rightmost or leftmost
        local sig = tostring(to) .. side
        if self.anchorSig == sig then return end
        self.anchorSig = sig
        self:ClearAllPoints()
        if side == "right" then
            self:SetPoint("TOPLEFT", to, "TOPRIGHT", 8, 0)
        else
            self:SetPoint("TOPRIGHT", to, "TOPLEFT", -8, 0)
        end
    end
    panel:Reanchor()
    UI.Fill(panel, 0.045, 0.045, 0.05, 0.96)
    UI.Border(panel)
    panel:EnableMouse(true)

    local title = UI.Text(panel, 13)
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText("Send mats")
    local setup = UI.Button(panel, "Setup", 60, 20)
    setup:SetPoint("TOPRIGHT", -8, -6)
    setup:SetScript("OnClick", function() OpenSetup() end)

    local altHead = UI.Text(panel, 11, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3])
    altHead:SetPoint("TOPLEFT", 10, -34)
    altHead:SetText("Send to")

    panel.altButtons = {}
    panel.altArea = CreateFrame("Frame", nil, panel)
    panel.altArea:SetPoint("TOPLEFT", 8, -50)
    panel.altArea:SetPoint("TOPRIGHT", -8, -50)
    panel.altArea:SetHeight(10)

    panel.listHead = UI.Text(panel, 11, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3])
    panel.listHead:SetPoint("TOPLEFT", panel.altArea, "BOTTOMLEFT", 2, -10)

    local box = UI.Panel(panel)
    box:SetPoint("TOPLEFT", panel.listHead, "BOTTOMLEFT", -2, -4)
    box:SetPoint("RIGHT", -8, 0)
    box:SetPoint("BOTTOM", 0, 90)
    panel.list = UI.List(box, 24, function(L)
        local row = CreateFrame("Button", nil, L)
        UI.Fill(row, 1, 1, 1, 0.08, "HIGHLIGHT")
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("LEFT", 4, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.count = UI.Text(row, 12, 1, 1, 1, "RIGHT")
        row.count:SetPoint("RIGHT", -6, 0)
        row.name = UI.Text(row, 12)
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.name:SetPoint("RIGHT", row.count, "LEFT", -6, 0)
        row:SetScript("OnEnter", UI.ItemEnter)
        row:SetScript("OnLeave", UI.HideTip)
        return row
    end, function(row, d)
        row.itemID = d.id
        row.icon:SetTexture(UI.ItemIcon(d.id))
        local name, q = UI.ItemNameQuality(d.id)
        row.name:SetText(name)
        row.name:SetTextColor(UI.QualityColor(q))
        row.count:SetText(d.count .. (d.stacks > 1 and ("  |cff9e9ea8(" .. d.stacks .. ")|r") or ""))
    end)
    panel.list:SetPoint("TOPLEFT", 3, -3)
    panel.list:SetPoint("BOTTOMRIGHT", -3, 3)

    panel.summary = UI.Text(panel, 11, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3])
    panel.summary:SetPoint("BOTTOMLEFT", 10, 68)
    panel.summary:SetPoint("RIGHT", -10, 0)

    panel.send = UI.Button(panel, "Send mats", 120, 26)
    panel.send:SetPoint("BOTTOM", 0, 36)
    panel.send:SetScript("OnClick", function()
        if db.lastAlt then StartSend(db.lastAlt) end
    end)

    panel.status = UI.Text(panel, 11, 1, 0.82, 0.2)
    panel.status:SetPoint("TOPLEFT", panel.send, "BOTTOMLEFT", -70, -3)
    panel.status:SetPoint("BOTTOMRIGHT", -8, 2)
    panel.status:SetJustifyH("CENTER")
    panel.status:SetJustifyV("TOP")
    panel.status:SetWordWrap(true)
    if panel.status.SetMaxLines then panel.status:SetMaxLines(2) end

    function panel:Refresh()
        if not self:IsShown() then return end
        self:Reanchor()
        local alts = {}
        for _, e in ipairs(Alts.List(true)) do
            if e.name ~= Alts.MyName() then alts[#alts + 1] = e end
        end
        -- alt buttons, two per row
        for _, b in ipairs(self.altButtons) do b:Hide() end
        local w = (self.altArea:GetWidth() - 6) / 2
        for i, e in ipairs(alts) do
            local b = self.altButtons[i]
            if not b then
                b = UI.Button(self.altArea, "", w, 34)
                b.sub = UI.Text(b, 9, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3], "CENTER")
                b.text:ClearAllPoints()
                b.text:SetPoint("TOPLEFT", 4, -4); b.text:SetPoint("TOPRIGHT", -4, -4)
                b.sub:SetPoint("BOTTOMLEFT", 4, 4); b.sub:SetPoint("BOTTOMRIGHT", -4, 4)
                b:SetScript("OnClick", function(self2)
                    db.lastAlt = self2.alt
                    panel.status:SetText("")
                    panel:Refresh()
                end)
                self.altButtons[i] = b
            end
            b.alt = e.name
            b:SetSize(w, 34)
            b:ClearAllPoints()
            local col, rowI = (i - 1) % 2, math.floor((i - 1) / 2)
            b:SetPoint("TOPLEFT", col * (w + 6), -rowI * 38)
            b.text:SetText(("|cff%s%s|r"):format(UI.ClassHex(e.data.class), e.display))
            local cats = AltCategories(e.name)
            b.sub:SetText(#cats > 0 and table.concat(cats, ", ") or "|cffff7070nothing assigned|r")
            b:SetOn(db.lastAlt == e.name)
            b:Show()
        end
        self.altArea:SetHeight(math.max(1, math.ceil(#alts / 2)) * 38)

        if #alts == 0 then
            self.listHead:SetText("Log in on your alts once so JaseQoL knows them.")
            self.list:SetItems({})
            self.summary:SetText("")
            self.send:SetEnabledLook(false)
            return
        end
        local valid = false
        for _, e in ipairs(alts) do if e.name == db.lastAlt then valid = true end end
        if not valid then
            self.listHead:SetText("Pick an alt to see what goes to them.")
            self.list:SetItems({})
            self.summary:SetText("")
            self.send:SetEnabledLook(false)
            return
        end
        local stacks = StacksFor(db.lastAlt)
        local byId, items = {}, {}
        for _, s in ipairs(stacks) do
            local it = byId[s.id]
            if not it then
                it = { id = s.id, count = 0, stacks = 0 }
                byId[s.id] = it
                items[#items + 1] = it
            end
            it.count = it.count + s.count
            it.stacks = it.stacks + 1
        end
        table.sort(items, function(a, b) return UI.ItemNameQuality(a.id) < UI.ItemNameQuality(b.id) end)
        self.listHead:SetText("In your bags for " .. Alts.Display(db.lastAlt))
        self.list:SetItems(items)
        local mails = math.ceil(#stacks / MAX_ATTACH)
        self.summary:SetText(#stacks == 0 and "Nothing in your bags for them right now."
            or (#stacks .. " stacks  •  " .. mails .. " mail" .. (mails > 1 and "s" or "")))
        self.send:SetEnabledLook(#stacks > 0 and not job)
    end

    panel:SetScript("OnShow", function(self) self:Refresh() end)
    -- follow EllesmereUI's alt list as it appears / moves (Send tab)
    if SendMailFrame then
        SendMailFrame:HookScript("OnShow", function() C_Timer.After(0.05, function() panel.anchorSig = nil; panel:Refresh() end) end)
        SendMailFrame:HookScript("OnHide", function() C_Timer.After(0.05, function() panel.anchorSig = nil; panel:Refresh() end) end)
    end
    Alts.OnChange(function() if panel:IsShown() then panel:Refresh() end end)
end

-------------------------------------------------------------------------------
--  Setup window
-------------------------------------------------------------------------------
local setup

local function BuildSetup()
    db.setupWin = db.setupWin or {}
    setup = UI.Window("JaseQoLMatsSetup", "Send mats: setup", 860, 560, db.setupWin)
    setup.cat = Alts.PROFESSIONS[1]

    -- Categories column
    local left = UI.Panel(setup)
    left:SetPoint("TOPLEFT", 10, -32)
    left:SetPoint("BOTTOMLEFT", 10, 96)
    left:SetWidth(170)
    setup.cats = UI.List(left, 26, function(L)
        local row = CreateFrame("Button", nil, L)
        UI.Fill(row, 1, 1, 1, 0.08, "HIGHLIGHT")
        row.sel = UI.Fill(row, 1, 1, 1, 0.10)
        row.bar = row:CreateTexture(nil, "ARTWORK")
        row.bar:SetPoint("TOPLEFT"); row.bar:SetPoint("BOTTOMLEFT"); row.bar:SetWidth(2)
        row.name = UI.Text(row, 12)
        row.name:SetPoint("LEFT", 10, 0)
        row.count = UI.Text(row, 11, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3], "RIGHT")
        row.count:SetPoint("RIGHT", -8, 0)
        row:SetScript("OnClick", function(self) setup.cat = self.cat; setup:Refresh() end)
        return row
    end, function(row, d)
        row.cat = d.cat
        local sel = d.cat == setup.cat
        row.sel:SetShown(sel)
        row.bar:SetColorTexture(UI.Accent())
        row.bar:SetShown(sel)
        row.name:SetText(d.cat)
        row.count:SetText(d.n > 0 and d.n or "")
    end)
    setup.cats:SetPoint("TOPLEFT", 2, -2)
    setup.cats:SetPoint("BOTTOMRIGHT", -2, 2)

    -- Assigned items column
    local mid = UI.Panel(setup)
    mid:SetPoint("TOPLEFT", left, "TOPRIGHT", 8, 0)
    mid:SetPoint("BOTTOMLEFT", left, "BOTTOMRIGHT", 8, 0)
    mid:SetWidth(300)
    setup.midHead = UI.Text(mid, 12)
    setup.midHead:SetPoint("TOPLEFT", 8, -8)
    setup.boeBtn = UI.Button(mid, "Also send all BoE gear", 150, 20)
    setup.boeBtn:SetPoint("TOPRIGHT", -6, -5)
    setup.boeBtn:SetScript("OnClick", function()
        db.boeGear[setup.cat] = not BoEGearOn(setup.cat)
        setup:Refresh()
    end)
    setup.boeBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Also send all BoE gear", 1, 1, 1)
        GameTooltip:AddLine("Every unbound Bind on Equip weapon and armour piece in your bags goes to the alts who get " .. setup.cat .. ", on top of the items listed here.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    setup.boeBtn:SetScript("OnLeave", UI.HideTip)

    local drop = CreateFrame("Button", nil, mid)
    drop:SetPoint("TOPLEFT", 6, -28)
    drop:SetPoint("TOPRIGHT", -6, -28)
    drop:SetHeight(34)
    UI.Fill(drop, 1, 1, 1, 0.04)
    UI.Fill(drop, 1, 1, 1, 0.08, "HIGHLIGHT")
    UI.Border(drop)
    drop.text = UI.Text(drop, 11, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3], "CENTER")
    drop.text:SetPoint("CENTER")
    drop.text:SetText("Drop an item here to assign it")
    local function TakeCursor()
        local kind, id = GetCursorInfo()
        if kind == "item" and id then
            Assign(id, setup.cat, true)
            ClearCursor()
            setup:Refresh()
        end
    end
    drop:SetScript("OnReceiveDrag", TakeCursor)
    drop:SetScript("OnClick", TakeCursor)

    setup.assigned = UI.List(mid, 26, function(L)
        local row = CreateFrame("Button", nil, L)
        UI.Fill(row, 1, 1, 1, 0.08, "HIGHLIGHT")
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(20, 20)
        row.icon:SetPoint("LEFT", 4, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.del = UI.Button(row, "×", 22, 20)
        row.del:SetPoint("RIGHT", -4, 0)
        row.del:SetScript("OnClick", function(self)
            Assign(self:GetParent().itemID, setup.cat, false)
            setup:Refresh()
        end)
        row.name = UI.Text(row, 12)
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.name:SetPoint("RIGHT", row.del, "LEFT", -6, 0)
        row:SetScript("OnEnter", UI.ItemEnter)
        row:SetScript("OnLeave", UI.HideTip)
        return row
    end, function(row, d)
        row.itemID = d.id
        row.icon:SetTexture(UI.ItemIcon(d.id))
        local name, q = UI.ItemNameQuality(d.id)
        row.name:SetText(name)
        row.name:SetTextColor(UI.QualityColor(q))
    end)
    setup.assigned:SetPoint("TOPLEFT", drop, "BOTTOMLEFT", 0, -6)
    setup.assigned:SetPoint("BOTTOMRIGHT", -4, 4)

    -- Your bags column (grouped by item type)
    local right = UI.Panel(setup)
    right:SetPoint("TOPLEFT", mid, "TOPRIGHT", 8, 0)
    right:SetPoint("BOTTOMRIGHT", -10, 96)
    local rightHead = UI.Text(right, 12)
    rightHead:SetPoint("TOPLEFT", 8, -8)
    rightHead:SetText("In your bags")
    setup.bags = UI.List(right, 26, function(L)
        local row = CreateFrame("Button", nil, L)
        UI.Fill(row, 1, 1, 1, 0.08, "HIGHLIGHT")
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(20, 20)
        row.icon:SetPoint("LEFT", 4, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.add = UI.Button(row, "+", 40, 20)
        row.add:SetPoint("RIGHT", -4, 0)
        row.add:SetScript("OnClick", function(self)
            local d = self:GetParent().data
            if d.header then
                for _, id in ipairs(d.ids) do Assign(id, setup.cat, true) end
            else
                Assign(d.id, setup.cat, true)
            end
            setup:Refresh()
        end)
        row.name = UI.Text(row, 12)
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.name:SetPoint("RIGHT", row.add, "LEFT", -6, 0)
        row:SetScript("OnEnter", UI.ItemEnter)
        row:SetScript("OnLeave", UI.HideTip)
        return row
    end, function(row, d)
        row.data = d
        if d.header then
            row.itemID = nil
            row.icon:Hide()
            row.name:ClearAllPoints()
            row.name:SetPoint("LEFT", 6, 0)
            row.name:SetPoint("RIGHT", row.add, "LEFT", -6, 0)
            row.name:SetText(("|cff%s%s|r  |cff9e9ea8(%d)|r"):format(UI.AccentHex(), d.text, #d.ids))
            row.add.text:SetText("+ all")
        else
            row.itemID = d.id
            row.icon:Show()
            row.icon:SetTexture(UI.ItemIcon(d.id))
            row.name:ClearAllPoints()
            row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            row.name:SetPoint("RIGHT", row.add, "LEFT", -6, 0)
            local name, q = UI.ItemNameQuality(d.id)
            row.name:SetText(name .. (d.assigned and "  |TInterface\\RaidFrame\\ReadyCheck-Ready:12|t" or "")
                .. (d.elsewhere and ("  |cff9e9ea8(" .. d.elsewhere .. ")|r") or ""))
            row.name:SetTextColor(UI.QualityColor(q))
            row.add.text:SetText("+")
        end
        row.add:SetEnabledLook(d.header or not d.assigned)
    end)
    setup.bags:SetPoint("TOPLEFT", 2, -28)
    setup.bags:SetPoint("BOTTOMRIGHT", -2, 2)

    -- Who receives this category
    local bottom = UI.Panel(setup)
    bottom:SetPoint("TOPLEFT", left, "BOTTOMLEFT", 0, -8)
    bottom:SetPoint("BOTTOMRIGHT", -10, 10)
    setup.whoHead = UI.Text(bottom, 12)
    setup.whoHead:SetPoint("TOPLEFT", 8, -8)
    setup.whoHint = UI.Text(bottom, 10, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3])
    setup.whoHint:SetPoint("LEFT", setup.whoHead, "RIGHT", 10, 0)
    setup.whoHint:SetText("Click to switch. Alts with the profession get it by default.")
    setup.whoChips = {}
    setup.whoArea = CreateFrame("Frame", nil, bottom)
    setup.whoArea:SetPoint("TOPLEFT", 8, -30)
    setup.whoArea:SetPoint("BOTTOMRIGHT", -8, 8)

    function setup:Refresh()
        if not self:IsShown() then return end
        local cat = self.cat
        -- categories with counts
        local counts = {}
        for _, cats in pairs(db.mats) do
            for c in pairs(cats) do counts[c] = (counts[c] or 0) + 1 end
        end
        local catItems = {}
        for _, c in ipairs(Categories()) do catItems[#catItems + 1] = { cat = c, n = counts[c] or 0 } end
        self.cats:SetItems(catItems, true)

        -- assigned to this category
        local assigned = {}
        for id, cats in pairs(db.mats) do
            if cats[cat] then assigned[#assigned + 1] = { id = id } end
        end
        table.sort(assigned, function(a, b) return UI.ItemNameQuality(a.id) < UI.ItemNameQuality(b.id) end)
        self.midHead:SetText(cat .. "  |cff9e9ea8" .. #assigned .. " items|r")
        self.boeBtn:SetOn(BoEGearOn(cat))
        self.boeBtn.text:SetText(BoEGearOn(cat) and "All BoE gear: on" or "All BoE gear: off")
        self.assigned:SetItems(assigned, true)

        -- bag items grouped by type (unbound only)
        local seen, groups, gOrder = {}, {}, {}
        local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
        for _, bag in ipairs(Alts.BagIDs()) do
            local n = (C and C.GetContainerNumSlots and C.GetContainerNumSlots(bag)) or 0
            for slot = 1, n do
                local id, _, isBound = Alts.SlotInfo(bag, slot)
                if id and not isBound and not seen[id] then
                    seen[id] = true
                    local _, itemType, subType = instant(id)
                    local g = (subType and subType ~= "" and subType ~= itemType) and (itemType .. ": " .. subType) or (itemType or "Other")
                    if not groups[g] then groups[g] = {}; gOrder[#gOrder + 1] = g end
                    table.insert(groups[g], id)
                end
            end
        end
        table.sort(gOrder)
        local rows = {}
        for _, g in ipairs(gOrder) do
            local ids = groups[g]
            table.sort(ids, function(a, b) return UI.ItemNameQuality(a) < UI.ItemNameQuality(b) end)
            rows[#rows + 1] = { header = true, text = g, ids = ids }
            for _, id in ipairs(ids) do
                -- other categories this item is already assigned to
                local others = {}
                for c in pairs(db.mats[id] or {}) do
                    if c ~= cat then others[#others + 1] = c end
                end
                table.sort(others)
                rows[#rows + 1] = { id = id, assigned = db.mats[id] and db.mats[id][cat] or false,
                    elsewhere = #others > 0 and table.concat(others, ", ") or nil }
            end
        end
        self.bags:SetItems(rows, true)

        -- who gets it
        self.whoHead:SetText("Who gets " .. cat)
        for _, c in ipairs(self.whoChips) do c:Hide() end
        local x, y = 0, 0
        local areaW = self.whoArea:GetWidth()
        for i, e in ipairs(Alts.List(true)) do
            local c = self.whoChips[i]
            if not c then
                c = UI.Button(self.whoArea, "", 100, 24)
                c:SetScript("OnClick", function(b)
                    local t = ReceivesTable(b.alt)
                    local data = Alts.RealmTable()[b.alt]
                    local default = data and data.profs and data.profs[setup.cat] ~= nil or false
                    local now = not Receives(b.alt, setup.cat)
                    if now ~= default then t[setup.cat] = now else t[setup.cat] = nil end
                    setup:Refresh()
                end)
                self.whoChips[i] = c
            end
            c.alt = e.name
            local rank = e.data.profs and e.data.profs[cat]
            c.text:SetText(("|cff%s%s|r%s"):format(UI.ClassHex(e.data.class), e.display, rank and ("  |cff9e9ea8" .. rank .. "|r") or ""))
            local w = c.text:GetStringWidth() + 22
            c:SetWidth(w)
            if x + w > areaW and x > 0 then x, y = 0, y + 28 end
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", x, -y)
            x = x + w + 6
            c:SetOn(Receives(e.name, cat))
            c:Show()
        end
        if panel and panel:IsShown() then panel:Refresh() end
    end

    setup:SetScript("OnShow", function(self) self:Refresh() end)
    Alts.OnChange(function() if setup:IsShown() then setup:Refresh() end end)
    JQ.Hub.Attach(setup, "mats")
end

JQ.Hub.Register({
    key = "mats", label = "Send mats",
    enabled = function() return JQ.IsEnabled(KEY) end,
    frame = function() return setup end,
    open = function()
        if not JQ.IsEnabled(KEY) then return end
        if not setup then BuildSetup() end
        return setup
    end,
})

function OpenSetup()
    JQ.Hub.Show("mats")
end

-------------------------------------------------------------------------------
--  Load
-------------------------------------------------------------------------------
JQ.byKey[KEY].onLoad = function(enabled)
    Alts = JQ.Alts
    JaseQoLDB.bankMail = JaseQoLDB.bankMail or {}
    db = JaseQoLDB.bankMail
    db.mats = db.mats or {}
    db.receives = db.receives or {}
    db.boeGear = db.boeGear or {}

    SLASH_JASEQOLMATS1 = "/jmats"
    SlashCmdList.JASEQOLMATS = function()
        if not JQ.IsEnabled(KEY) then JQ.Print("Send mats is off (/jq bankMail).") return end
        OpenSetup()
    end

    for _, e in ipairs({ "MAIL_SHOW", "MAIL_SEND_SUCCESS", "MAIL_FAILED", "MAIL_CLOSED" }) do
        ev:RegisterEvent(e)
    end
    local boot = CreateFrame("Frame")
    boot:RegisterEvent("PLAYER_LOGIN")
    boot:SetScript("OnEvent", function()
        if MailFrame then
            BuildPanel()
            panel:SetShown(JQ.IsEnabled(KEY))
        end
    end)
end

JQ.byKey[KEY].onEnable = function() if panel then panel:Show(); panel:Refresh() end end
JQ.byKey[KEY].onDisable = function()
    if panel then panel:Hide() end
    if setup then setup:Hide() end
end
