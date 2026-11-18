-------------------------------------------------------------------------------
--  JaseQoL: Dungeon Journal skin (EllesmereUI)
--
--  Paints the ForeverDungeonJournal window in the EllesmereUI house style
--  through EllesmereUI's third-party skinning API (EllesmereUI.RegisterSkin),
--  the same path EUI uses for other addons. That means:
--    * the window gets EUI's Shell (themed backdrop, top bar, window border)
--      and follows Modern / EllesmereUI style and accent changes live;
--    * buttons, the close button and scroll bars use EUI's primitives;
--    * text uses your EUI font;
--    * it also shows up in EllesmereUI > Blizzard Skins+ > Window Skins >
--      Third-Party Addons as "ForeverDungeonJournal" (either switch turns it off).
--
--  The journal draws its own panels with BackdropTemplate and recolours them
--  per dungeon. Those backdrops are flattened to a 1px border and their dark,
--  tinted fills are shifted to neutral greys of the same brightness, so
--  hover / selected rows still read. Light fills (the parchment quest page,
--  coloured status pills) keep their colour so text on them stays readable.
--
--  Rows the journal builds later are picked up while the window is open.
--  Turning the skin off needs a /reload.
-------------------------------------------------------------------------------
local _, JQ = ...
local KEY = "djSkin"
local SKIN_NAME = "ForeverDungeonJournal"

JQ.AddModule({
    key = KEY,
    label = "Dungeon Journal Skin",
    description = "Skins the Dungeon Journal (ForeverDungeonJournal) window in the EllesmereUI style. Needs EllesmereUI Blizzard Skins+.",
    default = true,
    needsReload = true,
})

local WHITE = "Interface\\Buttons\\WHITE8X8"
local S                       -- EUI skin facade, set when the callback runs
local done = setmetatable({}, { __mode = "k" })    -- frames already handled
local busy = setmetatable({}, { __mode = "k" })    -- re-entry guards for hooks
local fonted = setmetatable({}, { __mode = "k" })  -- FontStrings already re-fonted
local reFont = true

do
    local loc = GetLocale and GetLocale() or "enUS"
    -- EUI fonts may lack CJK / Cyrillic glyphs: keep the journal's own fonts there.
    if loc == "koKR" or loc == "zhCN" or loc == "zhTW" or loc == "ruRU" then reFont = false end
end

local function Lum(r, g, b) return 0.299 * r + 0.587 * g + 0.114 * b end

-- Dark tinted fills -> neutral grey of similar brightness (keeps hover/selected
-- contrast); light or strongly coloured fills are left alone.
local function MapFill(r, g, b, a)
    if not r then return r, g, b, a end
    local l = Lum(r, g, b)
    if l >= 0.30 then return r, g, b, a end
    local v = 0.035 + l * 0.75
    return v, v, v, a
end

-- Dull borders -> black hairline; bright ones (gold highlight, glows) keep
-- their colour so selection and status still show.
local function MapBorder(r, g, b, a)
    if not r then return r, g, b, a end
    if Lum(r, g, b) > 0.45 then return r, g, b, a end
    return 0, 0, 0, (a or 1)
end

local function KeepsTexture(bg)
    if type(bg) ~= "string" then return false end
    local l = bg:lower()
    return l:find("questframe", 1, true) or l:find("parchment", 1, true)
end

local FlattenBackdrop

local function HookBackdrop(f)
    hooksecurefunc(f, "SetBackdropColor", function(self, r, g, b, a)
        if busy[self] then return end
        busy[self] = true
        self:SetBackdropColor(MapFill(r, g, b, a))
        busy[self] = nil
    end)
    hooksecurefunc(f, "SetBackdropBorderColor", function(self, r, g, b, a)
        if busy[self] then return end
        busy[self] = true
        self:SetBackdropBorderColor(MapBorder(r, g, b, a))
        busy[self] = nil
    end)
    -- The journal sometimes re-applies a backdrop (pills, glows): flatten again.
    hooksecurefunc(f, "SetBackdrop", function(self)
        if busy[self] then return end
        FlattenBackdrop(self, true)
    end)
end

function FlattenBackdrop(f, rehook)
    local info = f.backdropInfo
    if not info then return end
    if info._jqFlat then return end
    local r, g, b, a = f:GetBackdropColor()
    local br, bg, bb, ba = f:GetBackdropBorderColor()
    local flat = {
        bgFile = info.bgFile and (KeepsTexture(info.bgFile) and info.bgFile or WHITE) or nil,
        edgeFile = info.edgeFile and WHITE or nil,
        edgeSize = 1,
        tile = info.tile, tileSize = info.tileSize,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
        _jqFlat = true,
    }
    busy[f] = true
    f:SetBackdrop(flat)
    busy[f] = nil
    if not rehook then HookBackdrop(f) end
    if r then f:SetBackdropColor(r, g, b, a) end          -- goes through MapFill
    if br then f:SetBackdropBorderColor(br, bg, bb, ba) end
end

-- UIPanelScrollFrameTemplate's bar is a Slider with up/down buttons: fade the
-- art, keep the buttons clickable, thin white thumb like EUI's scroll bars.
local function SkinSliderScrollBar(sb)
    if done[sb] then return end
    done[sb] = true
    local thumb = sb.GetThumbTexture and sb:GetThumbTexture()
    S.FadeRegions(sb, thumb and { [thumb] = true } or nil)
    local name = sb:GetName()
    local up = sb.ScrollUpButton or (name and _G[name .. "ScrollUpButton"])
    local down = sb.ScrollDownButton or (name and _G[name .. "ScrollDownButton"])
    if up then S.FadeRegions(up) end
    if down then S.FadeRegions(down) end
    if thumb then
        thumb:SetColorTexture(1, 1, 1, 0.3)
        thumb:SetWidth(4)
    end
end

local function IsPanelButton(f)
    return f.Left and f.Middle and f.Right and f.GetFontString
end

local function SkinTree(root, depth)
    if depth > 14 or not root or (root.IsForbidden and root:IsForbidden()) then return end

    if not done[root] then
        local otype = root:GetObjectType()
        if otype == "Slider" and (root.ScrollUpButton or (root:GetName() and _G[root:GetName() .. "ScrollUpButton"])) then
            SkinSliderScrollBar(root)
        else
            done[root] = true
            if root.backdropInfo and root.SetBackdrop then
                FlattenBackdrop(root)
            end
            if otype == "Button" and IsPanelButton(root) then
                S.Button(root)
                S.StateButtonLabel(root)
            end
        end
    end

    if reFont then
        local regions = { root:GetRegions() }
        for i = 1, #regions do
            local rg = regions[i]
            if not fonted[rg] and rg:GetObjectType() == "FontString" then
                fonted[rg] = true
                S.Font(rg)
            end
        end
    end

    local kids = { root:GetChildren() }
    for i = 1, #kids do SkinTree(kids[i], depth + 1) end
end

-- Faint parchment overlays the journal lays over its panels.
local PARCHMENTS = {
    "homeParchment", "contentParchment", "headerParchment", "leftParchment",
    "rightParchment", "questLeftParchment", "questRightParchment",
}

local function SkinMain(f)
    if not done[f] then
        done[f] = true
        S.Shell(f)
        if f.closeButton then S.CloseButton(f.closeButton) end
        if f.mainTitle then S.White(f.mainTitle) end
        for _, k in ipairs(PARCHMENTS) do
            if f[k] and f[k].Hide then f[k]:Hide() end
        end
    end
    SkinTree(f, 0)
end

-- Rows and panels are built on demand, so re-walk while the window is open.
local ticker
local function StartWatching(f)
    if ticker then return end
    ticker = C_Timer.NewTicker(0.5, function()
        if not f:IsShown() then
            ticker:Cancel(); ticker = nil
            return
        end
        SkinTree(f, 0)
    end)
end

local function Attach()
    local f = _G.ForeverDungeonJournalFrame
    if not f then return false end
    SkinMain(f)
    f:HookScript("OnShow", function(self)
        SkinTree(self, 0)
        StartWatching(self)
    end)
    if f:IsShown() then StartWatching(f) end
    return true
end

local function Apply(facade)
    S = facade
    if Attach() then return end
    -- EUI dispatches at PLAYER_LOGIN, which can be before the journal builds
    -- its window (also at PLAYER_LOGIN): retry briefly.
    local tries = 0
    local function retry()
        tries = tries + 1
        if Attach() or tries > 40 then return end
        C_Timer.After(0.25, retry)
    end
    C_Timer.After(0, retry)
end

JQ.byKey[KEY].onLoad = function(enabled)
    if not enabled then return end
    -- The journal is an OptionalDep, so if it is enabled it has loaded by now.
    if not _G.ForeverDungeonJournal_NS then return end
    if EllesmereUI and EllesmereUI.RegisterSkin then
        EllesmereUI.RegisterSkin(SKIN_NAME, Apply)
    end
end
