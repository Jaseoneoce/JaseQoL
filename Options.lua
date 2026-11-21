-------------------------------------------------------------------------------
--  JaseTools: slash commands
--
--  Every setting lives on the JaseTools window's Settings tab only
--  (Modules\SettingsPage.lua); nothing is added to EllesmereUI's options or
--  to the game's Options > AddOns list.
--    /jq            open the Settings tab   (also /jasetools, /jaseqol)
--    /jq list       list every module and whether it is on
--    /jq <key>      toggle a module, e.g. /jq xpLevelColor, /jq djSkin
--    /jq escort ... escort quest marks (see Modules\EscortGuard.lua)
-------------------------------------------------------------------------------
local _, JQ = ...

local function List()
    JQ.Print("modules (type /jq <key> to toggle):")
    for _, spec in ipairs(JQ.modules) do
        local on = JQ.IsEnabled(spec.key)
        JQ.Print(("%s%s|r  |cffaaaaaa%s|r  %s"):format(
            on and "|cff33ff33ON  " or "|cffff4444OFF ", spec.label, spec.key,
            spec.needsReload and "(reload)" or ""))
    end
end

SLASH_JASEQOL1 = "/jq"
SLASH_JASEQOL2 = "/jaseqol"
SLASH_JASEQOL3 = "/jasetools"
SlashCmdList.JASEQOL = function(msg)
    msg = strtrim(msg or "")
    if msg == "" then
        if JQ.OpenSettings then return JQ.OpenSettings() end
        return List()
    end
    if msg == "list" then return List() end
    local sub, rest = msg:match("^(%S+)%s*(.-)$")
    if sub and sub:lower() == "escort" and JQ.EscortCommand then return JQ.EscortCommand(rest) end
    for _, spec in ipairs(JQ.modules) do
        if spec.key:lower() == msg:lower() then
            return JQ.SetEnabled(spec.key, not JQ.IsEnabled(spec.key))
        end
    end
    JQ.Print("unknown module '" .. msg .. "'.")
    List()
end
