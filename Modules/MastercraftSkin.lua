-------------------------------------------------------------------------------
--  JaseQoL: Mastercraft skin (EllesmereUI)
--
--  Mastercraft has four looks of its own; its flat "Classic" one is built from
--  plain coloured panels (1px-bordered backdrops). With this skin on:
--    * Mastercraft is put on Classic as it loads (JaseQoL loads first, so the
--      switch lands before Mastercraft reads it; your previous choice is kept
--      and given back when the skin is switched off);
--    * through EllesmereUI's third-party skinning API the windows get EUI's
--      Shell, the panels EUI's neutral greys and black hairlines, Mastercraft's
--      blue accent becomes your EllesmereUI accent, and text uses your EUI font.
--  Mastercraft builds its pages on demand, so new rows are picked up while a
--  window is open. Turning the skin off needs a /reload.
-------------------------------------------------------------------------------
local _, JQ = ...
local KEY = "mcSkin"
local SKIN_NAME = "Mastercraft"

JQ.AddModule({
    key = KEY,
    label = "Mastercraft skin",
    description = "Skins Mastercraft in the EllesmereUI style: EUI window frames, neutral dark panels, your EUI accent instead of Mastercraft's blue, and your EUI font. Puts Mastercraft on its flat Classic look underneath (your own choice comes back if you switch this off). Needs EllesmereUI Blizzard Skins+.",
    default = true,
    needsReload = true,
})

-- Big windows get EUI's window frame; the rest only recolours.
local WINDOWS = {
    "MastercraftFrame", "MastercraftDetails", "MastercraftRecipePanel", "MastercraftMiniGuide",
    "MastercraftGoals", "MastercraftAltView", "MastercraftTradeBoard", "MastercraftLFGPanel",
    "MastercraftFishWindow", "MastercraftNeverBank", "MastercraftCompact",
}
local SMALL = { "MastercraftFarmHUD", "MastercraftFishBar", "MastercraftFishRecap" }

local S
local done = setmetatable({}, { __mode = "k" })
local fonted = setmetatable({}, { __mode = "k" })
local busy = setmetatable({}, { __mode = "k" })
local reFont = true
do
    local loc = GetLocale and GetLocale() or "enUS"
    if loc == "koKR" or loc == "zhCN" or loc == "zhTW" or loc == "ruRU" then reFont = false end
end

-------------------------------------------------------------------------------
--  Colour mapping: Mastercraft Classic's blue-tinted palette -> EUI
-------------------------------------------------------------------------------
local function Lum(r, g, b) return 0.299 * r + 0.587 * g + 0.114 * b end

local function IsAccentBlue(r, g, b)
    return r and b and b > 0.85 and r < 0.5 and g > 0.55 and g < 0.8
end

local function AccentRGB()
    local c = EllesmereUI and EllesmereUI.ELLESMERE_GREEN
    if c and c.r then return c.r, c.g, c.b end
    return 0.047, 0.824, 0.616
end

local function MapFill(r, g, b, a)
    if not r then return r, g, b, a end
    if IsAccentBlue(r, g, b) then
        local ar, ag, ab = AccentRGB()
        return ar, ag, ab, a
    end
    -- dark, blue-tinted greys -> neutral greys of the same brightness
    local l = Lum(r, g, b)
    if l < 0.32 and b >= r then
        local v = 0.03 + l * 0.85
        return v, v, v, a
    end
    return r, g, b, a
end

local function MapBorder(r, g, b, a)
    if not r then return r, g, b, a end
    if IsAccentBlue(r, g, b) then
        local ar, ag, ab = AccentRGB()
        return ar, ag, ab, a
    end
    if Lum(r, g, b) < 0.35 and b >= r then return 0, 0, 0, a or 1 end
    return r, g, b, a
end

local function MapText(r, g, b, a)
    if IsAccentBlue(r, g, b) then
        local ar, ag, ab = AccentRGB()
        return ar, ag, ab, a
    end
    return r, g, b, a
end

-------------------------------------------------------------------------------
--  Hooks on backdrops, flat textures and text
-------------------------------------------------------------------------------
local function HookBackdrop(f)
    if not f.SetBackdropColor then return end
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
    -- re-apply to what's there now
    local r, g, b, a = f:GetBackdropColor()
    if r then f:SetBackdropColor(r, g, b, a) end
    local br, bg, bb, ba = f:GetBackdropBorderColor()
    if br then f:SetBackdropBorderColor(br, bg, bb, ba) end
end

local function HookTexture(t)
    if done[t] then return end
    done[t] = true
    -- flat colour textures (SetColorTexture) carry their colour as vertex colour
    hooksecurefunc(t, "SetColorTexture", function(self, r, g, b, a)
        if busy[self] then return end
        busy[self] = true
        self:SetColorTexture(MapFill(r, g, b, a))
        busy[self] = nil
    end)
    hooksecurefunc(t, "SetVertexColor", function(self, r, g, b, a)
        if busy[self] then return end
        local nr, ng, nb, na = MapFill(r, g, b, a)
        if nr == r and ng == g and nb == b then return end
        busy[self] = true
        self:SetVertexColor(nr, ng, nb, na)
        busy[self] = nil
    end)
    local r, g, b, a = t:GetVertexColor()
    if r and IsAccentBlue(r, g, b) then t:SetVertexColor(r, g, b, a) end
end

local function HookText(fs)
    if fonted[fs] then return end
    fonted[fs] = true
    if reFont and S and S.Font then S.Font(fs) end
    hooksecurefunc(fs, "SetTextColor", function(self, r, g, b, a)
        if busy[self] or not IsAccentBlue(r, g, b) then return end
        busy[self] = true
        self:SetTextColor(MapText(r, g, b, a))
        busy[self] = nil
    end)
    local r, g, b, a = fs:GetTextColor()
    if r and IsAccentBlue(r, g, b) then fs:SetTextColor(r, g, b, a) end
end

local function SkinTree(root, depth)
    if depth > 16 or not root or (root.IsForbidden and root:IsForbidden()) then return end
    if not done[root] then
        done[root] = true
        HookBackdrop(root)
    end
    local regions = { root:GetRegions() }
    for i = 1, #regions do
        local rg = regions[i]
        local ot = rg:GetObjectType()
        if ot == "FontString" then
            HookText(rg)
        elseif ot == "Texture" and not done[rg] then
            -- the mapping only touches dark blue-tinted greys and the blue accent,
            -- so icons and art (white / own colours) pass through unchanged
            HookTexture(rg)
        end
    end
    local kids = { root:GetChildren() }
    for i = 1, #kids do SkinTree(kids[i], depth + 1) end
end

-------------------------------------------------------------------------------
--  Windows: Shell once, then re-walk while open (pages are built on demand)
-------------------------------------------------------------------------------
local watching = {}

local function Watch(f, shell)
    if watching[f] then return end
    watching[f] = true
    if shell and S and S.Shell then S.Shell(f) end
    SkinTree(f, 0)
    local ticker
    local function Start()
        if ticker then return end
        ticker = C_Timer.NewTicker(0.5, function()
            if not f:IsShown() then ticker:Cancel(); ticker = nil; return end
            SkinTree(f, 0)
        end)
    end
    f:HookScript("OnShow", function() SkinTree(f, 0); Start() end)
    if f:IsShown() then Start() end
end

local finder
local function FindWindows()
    local missing = false
    for _, n in ipairs(WINDOWS) do
        local f = _G[n]
        if f then Watch(f, true) else missing = true end
    end
    for _, n in ipairs(SMALL) do
        local f = _G[n]
        if f then Watch(f, false) else missing = true end
    end
    if not missing and finder then finder:Cancel(); finder = nil end
end

local function Apply(facade)
    S = facade
    FindWindows()
    -- Mastercraft creates most windows the first time they are opened
    finder = C_Timer.NewTicker(1, FindWindows)
end

-------------------------------------------------------------------------------
--  Theme switch at Mastercraft's load, and registration
-------------------------------------------------------------------------------
local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("ADDON_LOADED")
loadFrame:SetScript("OnEvent", function(self, _, name)
    if name ~= "Mastercraft" then return end
    self:UnregisterEvent("ADDON_LOADED")
    if not (JaseQoLDB and JQ.IsEnabled(KEY)) then
        -- skin off: give back the look Mastercraft had before we switched it
        local prev = JaseQoLDB and JaseQoLDB.mcPrevTheme
        if prev and MastercraftDB and MastercraftDB.settings and MastercraftDB.settings.theme == "classic" then
            MastercraftDB.settings.theme = prev
        end
        if JaseQoLDB then JaseQoLDB.mcPrevTheme = nil end
        return
    end
    MastercraftDB = MastercraftDB or {}
    MastercraftDB.settings = MastercraftDB.settings or {}
    local st = MastercraftDB.settings
    if st.theme ~= "classic" then
        JaseQoLDB.mcPrevTheme = st.theme or "wow"
    end
    st.theme = "classic"
    st.wowStyleV2 = true   -- stops Mastercraft's one-time switch to its WoW look
end)

JQ.byKey[KEY].onLoad = function(enabled)
    if not enabled then return end
    if EllesmereUI and EllesmereUI.RegisterSkin then
        EllesmereUI.RegisterSkin(SKIN_NAME, Apply)
    end
end
