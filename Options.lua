-------------------------------------------------------------------------------
--  JaseQoL: options
--
--  * EllesmereUI options panel: a "JaseQoL" section with one toggle per module
--    (via EllesmereUI.RegisterPlugin).
--  * /jq            open that page (or list the toggles if EUI is missing)
--    /jq list       list every module and whether it is on
--    /jq <key>      toggle a module, e.g. /jq xpLevelColor, /jq djSkin
-------------------------------------------------------------------------------
local ADDON_NAME, JQ = ...
local PLUGIN_ID = "JaseQoL"

local function BuildPage(_, parent, yOffset)
    local W = EllesmereUI.Widgets
    local y = yOffset
    local _, h
    _, h = W:SectionHeader(parent, "TWEAKS", y); y = y - h
    for _, spec in ipairs(JQ.modules) do
        local label = spec.label .. (spec.needsReload and " (reload)" or "")
        local tip = spec.description
        if spec.needsReload then tip = (tip or "") .. "\n\nChanges apply after /reload." end
        _, h = W:Toggle(parent, label, y,
            function() return JQ.IsEnabled(spec.key) end,
            function(v)
                if EllesmereUI.IsSearchPrebuild and EllesmereUI.IsSearchPrebuild() then return end
                JQ.SetEnabled(spec.key, v)
            end,
            tip); y = y - h
    end
    return math.abs(y)
end

if EllesmereUI and EllesmereUI.RegisterPlugin then
    EllesmereUI.RegisterPlugin(PLUGIN_ID, {
        label = "JaseQoL",
        modules = {
            {
                key = "General",
                title = "Tweaks",
                description = "Switch each of Jase's tweaks on or off.",
                pages = { "Tweaks" },
                buildPage = BuildPage,
            },
        },
    })
end

-------------------------------------------------------------------------------
--  Game menu > Options > AddOns > JaseQoL: one checkbox per module.
-------------------------------------------------------------------------------
local function RegisterBlizzardSettings()
    if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnSetting) then return end
    local category = Settings.RegisterVerticalLayoutCategory("JaseQoL")
    local makeCheckbox = Settings.CreateCheckbox or Settings.CreateCheckBox
    local db = JaseQoLDB.modules
    for _, spec in ipairs(JQ.modules) do
        if db[spec.key] == nil then db[spec.key] = JQ.IsEnabled(spec.key) end
        local name = spec.label .. (spec.needsReload and " (reload)" or "")
        local ok, setting = pcall(Settings.RegisterAddOnSetting, category,
            "JASEQOL_" .. spec.key:upper(), spec.key, db, type(true), name, spec.default)
        if ok and setting then
            local tip = spec.description
            if spec.needsReload then tip = (tip or "") .. "\n\nChanges apply after /reload." end
            if makeCheckbox then makeCheckbox(category, setting, tip) end
            if setting.SetValueChangedCallback then
                setting:SetValueChangedCallback(function(_, value) JQ.ApplyChange(spec.key, value) end)
            end
        end
    end
    Settings.RegisterAddOnCategory(category)
    JQ.settingsCategory = category
end

local reg = CreateFrame("Frame")
reg:RegisterEvent("ADDON_LOADED")
reg:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON_NAME then return end
    self:UnregisterEvent("ADDON_LOADED")
    local ok, err = pcall(RegisterBlizzardSettings)
    if not ok then geterrorhandler()(err) end
end)

local function List()
    JQ.Print("modules (type /jq <key> to toggle):")
    for _, spec in ipairs(JQ.modules) do
        local on = JQ.IsEnabled(spec.key)
        print(("  %s%s|r  |cffaaaaaa%s|r  %s"):format(
            on and "|cff33ff33ON  " or "|cffff4444OFF ", spec.label, spec.key,
            spec.needsReload and "(reload)" or ""))
    end
end

SLASH_JASEQOL1 = "/jq"
SLASH_JASEQOL2 = "/jaseqol"
SlashCmdList.JASEQOL = function(msg)
    msg = strtrim(msg or "")
    if msg == "" then
        if EllesmereUI and EllesmereUI.OpenPlugin and EllesmereUI.OpenPlugin(PLUGIN_ID) then return end
        local cat = JQ.settingsCategory
        if cat and Settings and Settings.OpenToCategory then
            Settings.OpenToCategory(cat.GetID and cat:GetID() or cat)
            return
        end
        return List()
    end
    if msg == "list" then return List() end
    for _, spec in ipairs(JQ.modules) do
        if spec.key:lower() == msg:lower() then
            return JQ.SetEnabled(spec.key, not JQ.IsEnabled(spec.key))
        end
    end
    JQ.Print("unknown module '" .. msg .. "'.")
    List()
end
