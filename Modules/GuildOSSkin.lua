-------------------------------------------------------------------------------
--  JaseTools: GuildOS skin (EllesmereUI)
--
--  GuildOS paints everything from one palette (GuildOS.Colors, named tokens it
--  re-points in place for its styles) and sets every font through
--  GuildOS:ApplyFont. On its flat "GuildOS" style this skin:
--    * re-points the palette to EllesmereUI's look: neutral near-black
--      windows and panels, grey hairlines, white text, and your EllesmereUI
--      accent in place of GuildOS's gold (status colours stay);
--    * draws text in your EllesmereUI font at GuildOS's own sizes;
--    * follows live accent changes, and shows under EllesmereUI's
--      Third-Party Addons switches as "GuildOS".
--  GuildOS's "WoW: Forever" style (bronze art) is left as it is: pick the
--  GuildOS style in its settings to use this skin. Switching off needs a /reload.
-------------------------------------------------------------------------------
local _, JQ = ...
local KEY = "gosSkin"

JQ.AddModule({
    key = KEY,
    label = "GuildOS skin",
    description = "Skins GuildOS in the EllesmereUI style: neutral dark windows, grey hairlines, your EUI accent instead of GuildOS's gold, and your EUI font. Works on GuildOS's flat 'GuildOS' style (its 'WoW: Forever' style is left alone).",
    default = true,
    needsReload = true,
})

local S   -- EllesmereUI skin facade (font, live accent)

local function rgb(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end

local function Palette()
    local ar, ag, ab = 0.047, 0.824, 0.616
    local c = EllesmereUI and EllesmereUI.ELLESMERE_GREEN
    if c and c.r then ar, ag, ab = c.r, c.g, c.b end
    local function shade(k) return rgb(math.min(1, ar * k), math.min(1, ag * k), math.min(1, ab * k)) end
    return {
        bg       = rgb(0.051, 0.051, 0.055),
        panel    = rgb(0.078, 0.078, 0.082),
        popup    = rgb(0.102, 0.102, 0.106),
        well     = rgb(0.035, 0.035, 0.039),
        line     = rgb(0.000, 0.000, 0.000),
        lineHi   = rgb(0.300, 0.300, 0.310),
        text     = rgb(0.960, 0.960, 0.960),
        textSoft = rgb(0.720, 0.720, 0.740),
        label    = rgb(0.620, 0.620, 0.660),
        labelDim = rgb(0.450, 0.450, 0.480),
        disabled = rgb(0.300, 0.300, 0.320),
        gold       = rgb(ar, ag, ab),
        goldHover  = shade(1.18),
        goldActive = shade(0.82),
        onGold     = rgb(0.040, 0.040, 0.040),
    }
end

local function Repoint()
    if GuildOS and GuildOS.RepointColors and GuildOS.Colors then
        JQ.Try("GuildOS skin", GuildOS.RepointColors, GuildOS, Palette())
    end
end

local function UsingFlatStyle()
    local st = GuildOS and GuildOS.Style
    return not st or not st.current or st.current == "guildos"
end

local function WrapFonts()
    if not (GuildOS and GuildOS.ApplyFont) or GuildOS.__jqFont then return end
    GuildOS.__jqFont = true
    local orig = GuildOS.ApplyFont
    function GuildOS.ApplyFont(self, fontString, size, role)
        local file, px = orig(self, fontString, size, role)
        if GuildOS.GameFontOnly or not (S and S.GetFont) then return file, px end
        local path, flags = S.GetFont()
        if path and px and fontString:SetFont(path, px, flags or "") ~= false then
            return path, px
        end
        return file, px
    end
end

JQ.byKey[KEY].onLoad = function(enabled)
    if not enabled then return end
    if not (GuildOS and GuildOS.Colors) then return end   -- GuildOS not loaded
    if not UsingFlatStyle() then return end
    -- before GuildOS builds anything (it builds at login and on demand)
    Repoint()
    WrapFonts()
    if EllesmereUI and EllesmereUI.RegisterSkin then
        EllesmereUI.RegisterSkin("GuildOS", function(facade)
            S = facade
            Repoint()   -- the profile's accent is settled by now
            if S.OnLooksChanged then S.OnLooksChanged(Repoint) end
        end)
    end
end
