-------------------------------------------------------------------------------
--  JaseTools: shared UI helpers (flat EllesmereUI-style widgets)
--
--  JQ.UI.Window(name, title, w, h)  draggable, resizable window with title + close
--  JQ.UI.Button(parent, label, w, h) flat button with :SetOn(bool)
--  JQ.UI.Text(parent, size, r, g, b, justify)
--  JQ.UI.Fill / Border / Accent / SetFont
--  JQ.UI.List(parent, rowHeight, create(row), update(row, data))  pooled scrolling list
--  JQ.UI.SearchBox(parent, hint, onChange)
--  JQ.UI.ItemIcon(id), QualityColor(q), ItemTip(owner, id, extra)
-------------------------------------------------------------------------------
local _, JQ = ...
local UI = {}
JQ.UI = UI

local WHITE = "Interface\\Buttons\\WHITE8X8"
local S    -- EllesmereUI skin facade, if present

if EllesmereUI and EllesmereUI.RegisterSkin then
    EllesmereUI.RegisterSkin("JaseTools Windows", function(facade) S = facade end)
end

function UI.Accent()
    local c = EllesmereUI and EllesmereUI.ELLESMERE_GREEN
    if c and c.r then return c.r, c.g, c.b end
    return 0.047, 0.824, 0.616
end

function UI.AccentHex()
    local r, g, b = UI.Accent()
    return ("%02x%02x%02x"):format(r * 255, g * 255, b * 255)
end

UI.MUTED = { 0.62, 0.62, 0.66 }

function UI.SetFont(fs, size, flags)
    local path, fl = STANDARD_TEXT_FONT, ""
    if S and S.GetFont then
        local p, f = S.GetFont()
        if p then path, fl = p, f or "" end
    end
    fs:SetFont(path, size or 12, flags or fl)
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.8)
end

function UI.Text(parent, size, r, g, b, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    UI.SetFont(fs, size)
    fs:SetTextColor(r or 1, g or 1, b or 1)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

function UI.Fill(parent, r, g, b, a, layer)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetTexture(WHITE)
    t:SetVertexColor(r, g, b, a or 1)
    t:SetAllPoints()
    return t
end

function UI.Border(frame, a)
    local function edge()
        local t = frame:CreateTexture(nil, "BORDER", nil, 7)
        t:SetColorTexture(0, 0, 0, a or 1)
        return t
    end
    local t, b, l, r = edge(), edge(), edge(), edge()
    t:SetPoint("TOPLEFT"); t:SetPoint("TOPRIGHT"); t:SetHeight(1)
    b:SetPoint("BOTTOMLEFT"); b:SetPoint("BOTTOMRIGHT"); b:SetHeight(1)
    l:SetPoint("TOPLEFT"); l:SetPoint("BOTTOMLEFT"); l:SetWidth(1)
    r:SetPoint("TOPRIGHT"); r:SetPoint("BOTTOMRIGHT"); r:SetWidth(1)
end

function UI.Button(parent, label, w, h)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w or 90, h or 22)
    b.bg = UI.Fill(b, 1, 1, 1, 0.06)
    UI.Fill(b, 1, 1, 1, 0.08, "HIGHLIGHT")
    UI.Border(b)
    b.text = UI.Text(b, 11, 0.9, 0.9, 0.9, "CENTER")
    b.text:SetPoint("LEFT", 6, 0); b.text:SetPoint("RIGHT", -6, 0)
    b.text:SetText(label or "")
    function b:SetOn(on)
        self.on = on
        if on then
            local r, g, bb = UI.Accent()
            self.bg:SetVertexColor(r, g, bb, 0.22)
            self.text:SetTextColor(r, g, bb)
        else
            self.bg:SetVertexColor(1, 1, 1, 0.06)
            self.text:SetTextColor(0.9, 0.9, 0.9)
        end
    end
    function b:SetEnabledLook(on)
        self:SetEnabled(on)
        self:SetAlpha(on and 1 or 0.45)
    end
    return b
end

function UI.Window(name, title, w, h, db)
    local f = CreateFrame("Frame", name, UIParent)
    f:SetSize((db and db.w) or w, (db and db.h) or h)
    if db and db.pos then
        f:SetPoint(db.pos[1], UIParent, db.pos[2], db.pos[3], db.pos[4])
    else
        f:SetPoint("CENTER")
    end
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:SetResizable(true)
    if f.SetResizeBounds then f:SetResizeBounds(w * 0.7, h * 0.6, 1600, 1100) end
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    local function save()
        if not db then return end
        local p, _, rp, x, y = f:GetPoint()
        db.pos = { p, rp, x, y }
        db.w, db.h = f:GetSize()
    end
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); save() end)
    f:Hide()
    if name then tinsert(UISpecialFrames, name) end

    local back = CreateFrame("Frame", nil, f)
    back:SetAllPoints()
    back:SetFrameLevel(f:GetFrameLevel())
    if S and S.Shell then
        S.Shell(f)
    else
        UI.Fill(back, 0.045, 0.045, 0.05, 0.96)
        UI.Border(back)
    end

    f.title = UI.Text(f, 13)
    f.title:SetPoint("TOPLEFT", 12, -6)
    f.title:SetText(title)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() f:Hide() end)
    if S and S.CloseButton then S.CloseButton(close) end

    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(14, 14)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing(); save() end)
    return f
end

function UI.Panel(parent)
    local p = CreateFrame("Frame", nil, parent)
    UI.Fill(p, 0.075, 0.075, 0.08, 0.95)
    UI.Border(p)
    return p
end

function UI.SearchBox(parent, hintText, onChange)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetHeight(20)
    e:SetAutoFocus(false)
    e:SetTextInsets(22, 8, 0, 0)
    UI.SetFont(e, 12)
    UI.Fill(e, 0, 0, 0, 0.5)
    UI.Border(e)
    local glass = e:CreateTexture(nil, "OVERLAY")
    glass:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    glass:SetSize(13, 13)
    glass:SetPoint("LEFT", 6, -1)
    glass:SetVertexColor(0.7, 0.7, 0.7)
    local hint = UI.Text(e, 12, 0.45, 0.45, 0.5)
    hint:SetPoint("LEFT", 22, 0)
    hint:SetText(hintText or "Search")
    e:SetScript("OnEscapePressed", function(self)
        if self:GetText() ~= "" then self:SetText("") else self:ClearFocus() end
    end)
    e:SetScript("OnEnterPressed", e.ClearFocus)
    local pending
    e:SetScript("OnTextChanged", function(self)
        hint:SetShown(self:GetText() == "")
        if pending then pending:Cancel() end
        pending = C_Timer.NewTimer(0.15, function()
            pending = nil
            if onChange then onChange(self:GetText()) end
        end)
    end)
    function e:Needle()
        local s = (self:GetText() or ""):lower()
        return (s:gsub("^%s+", ""):gsub("%s+$", ""))
    end
    return e
end

-- Pooled list: only visible rows exist. items = array of data; update(row, data, index).
function UI.List(parent, rowH, create, update)
    local L = CreateFrame("Frame", nil, parent)
    L:SetClipsChildren(true)
    L.rows, L.items, L.offset = {}, {}, 0
    local bar = CreateFrame("Slider", nil, L)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(6)
    bar:SetPoint("TOPRIGHT", 0, -2)
    bar:SetPoint("BOTTOMRIGHT", 0, 2)
    local thumb = bar:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(1, 1, 1, 0.3)
    thumb:SetSize(4, 30)
    bar:SetThumbTexture(thumb)
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)
    L.bar = bar

    local function visible() return math.max(1, math.floor(L:GetHeight() / rowH)) end

    function L:Render()
        local n = visible()
        local maxOff = math.max(0, #self.items - n)
        if self.offset > maxOff then self.offset = maxOff end
        self.setting = true
        bar:SetMinMaxValues(0, maxOff)
        bar:SetValue(self.offset)
        self.setting = nil
        bar:SetShown(maxOff > 0)
        if #self.items > 0 then thumb:SetHeight(math.max(20, L:GetHeight() * n / #self.items)) end
        local pad = bar:IsShown() and 10 or 0
        for i = 1, math.max(n + 1, #self.rows) do
            local row = self.rows[i]
            local data = self.items[self.offset + i]
            if data and i <= n then
                if not row then
                    row = create(self)
                    row:SetHeight(rowH)
                    self.rows[i] = row
                end
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, -(i - 1) * rowH)
                row:SetPoint("RIGHT", -pad, 0)
                update(row, data, self.offset + i)
                row:Show()
            elseif row then
                row:Hide()
            end
        end
    end

    function L:SetItems(items, keep)
        self.items = items or {}
        if not keep then self.offset = 0 end
        self:Render()
    end

    bar:SetScript("OnValueChanged", function(_, v)
        if L.setting then return end
        L.offset = math.floor(v + 0.5)
        L:Render()
    end)
    L:EnableMouseWheel(true)
    L:SetScript("OnMouseWheel", function(self, delta)
        self.offset = math.max(0, self.offset - delta * 3)
        self:Render()
    end)
    L:SetScript("OnSizeChanged", function(self) self:Render() end)
    return L
end

-- Items -----------------------------------------------------------------------
function UI.ItemIcon(id)
    if C_Item and C_Item.GetItemIconByID then
        local i = C_Item.GetItemIconByID(id)
        if i then return i end
    end
    local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if instant then
        local icon = select(5, instant(id))
        if icon then return icon end
    end
    return 134400
end

function UI.QualityColor(q)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q or 1]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

local GetItemInfoFn = (C_Item and C_Item.GetItemInfo) or GetItemInfo

-- Name + quality for an item id: live item info first, then what JaseTools has
-- remembered from scans (JaseQoLDB.items[id] = { n = name, q = quality }).
function UI.ItemNameQuality(id)
    local name, _, q = GetItemInfoFn(id)
    local known = JaseQoLDB and JaseQoLDB.items and JaseQoLDB.items[id]
    if name then
        if JaseQoLDB and JaseQoLDB.items and (not known or known.n ~= name or known.q ~= q) then
            JaseQoLDB.items[id] = { n = name, q = q }
        end
        return name, q
    end
    if known then return known.n, known.q end
    return "item:" .. tostring(id), 1
end

function UI.ItemEnter(self)
    if not self.itemID then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(self.itemID)
    GameTooltip:Show()
end

function UI.ItemClick(self)
    if not self.itemID then return end
    local _, link = GetItemInfoFn(self.itemID)
    if link and IsModifiedClick("CHATLINK") then ChatEdit_InsertLink(link) end
end

function UI.HideTip() GameTooltip:Hide() end

-- Class colour hex for a class token.
function UI.ClassHex(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return ("%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255) end
    return "ffffff"
end
