-------------------------------------------------------------------------------
--  JaseTools: error log
--
--  Every JaseTools error ends up in JaseQoLDB.errors (Core.lua, JQ.Error):
--    * errors JaseTools catches itself (code that must never break the game's
--      own windows runs through JQ.Try),
--    * errors from JaseTools' files that reach the game's error handler (it's
--      passed through: the game, BugSack etc. still see everything),
--    * actions the game blocked because of JaseTools ("taint").
--  /jq errors        the log, in a window you can copy from
--  /jq errors clear  empty it
-------------------------------------------------------------------------------
local _, JQ = ...
local UI = JQ.UI

JQ.AddModule({
    key = "errorNotify",
    label = "Tell me about JaseTools errors",
    description = "Every JaseTools error is logged (see /jq errors - copy it to send to Jase). With this on, chat also says so the first time an error turns up in a session.",
    default = true,
})

-------------------------------------------------------------------------------
--  Errors from JaseTools' files that reach the game's error handler
-------------------------------------------------------------------------------
local function Mine(msg)
    return type(msg) == "string" and (msg:find("AddOns[/\\]JaseQoL[/\\]") or msg:find("JaseQoL[/\\]Modules"))
end

local function WhereFrom(msg)
    local file = msg:match("JaseQoL[/\\]Modules[/\\]([%w_]+)%.lua") or msg:match("JaseQoL[/\\]([%w_]+)%.lua")
    return file and (file .. " (uncaught)") or "uncaught"
end

local hooked = false
local function HookErrorHandler()
    if hooked or not (geterrorhandler and seterrorhandler) then return end
    local orig = geterrorhandler()
    if type(orig) ~= "function" then return end
    hooked = true
    seterrorhandler(function(msg, ...)
        pcall(function()
            if Mine(msg) and msg ~= JQ._lastError then JQ.Error(WhereFrom(msg), msg) end
        end)
        return orig(msg, ...)
    end)
end

-- Actions the game blocked because JaseTools' code was involved
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ADDON_ACTION_BLOCKED")
ev:RegisterEvent("ADDON_ACTION_FORBIDDEN")
ev:SetScript("OnEvent", function(_, event, addon, action)
    if event == "PLAYER_LOGIN" then
        HookErrorHandler()
        return
    end
    if addon == "JaseQoL" then
        JQ.Error("blocked action", ("%s: %s"):format(event == "ADDON_ACTION_FORBIDDEN" and "forbidden" or "blocked", tostring(action)))
    end
end)

-------------------------------------------------------------------------------
--  /jq errors
-------------------------------------------------------------------------------
local win

local function When(t)
    if not t or t == 0 then return "?" end
    return date("%d/%m %H:%M", t)
end

local function LogText()
    local log = JaseQoLDB and JaseQoLDB.errors or {}
    if #log == 0 then return "No JaseTools errors logged." end
    local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("JaseQoL", "Version") or "?"
    local out = { ("JaseTools %s - %d error(s), newest first"):format(version, #log), "" }
    for i, e in ipairs(log) do
        out[#out + 1] = ("[%d] %s  -  %dx, first %s, last %s%s"):format(i, e.where or "?", e.count or 1,
            When(e.first), When(e.last), e.version and (" (" .. e.version .. ")") or "")
        out[#out + 1] = tostring(e.msg)
        if e.stack and e.stack ~= "" then
            for line in e.stack:gmatch("[^\n]+") do out[#out + 1] = "    " .. line end
        end
        out[#out + 1] = ""
    end
    return table.concat(out, "\n")
end

local function Build()
    JaseQoLDB.errorWin = JaseQoLDB.errorWin or {}
    win = UI.Window("JaseQoLErrors", "JaseTools errors", 640, 420, JaseQoLDB.errorWin)
    local hint = UI.Text(win, 11, UI.MUTED[1], UI.MUTED[2], UI.MUTED[3])
    hint:SetPoint("TOPLEFT", 12, -32)
    hint:SetText("Ctrl+A, Ctrl+C to copy - paste it to Jase.")

    win.clear = UI.Button(win, "Clear", 80, 22)
    win.clear:SetPoint("TOPRIGHT", -12, -28)
    win.clear:SetScript("OnClick", function()
        JaseQoLDB.errors = {}
        win:Refresh()
    end)

    local panel = UI.Panel(win)
    panel:SetPoint("TOPLEFT", 10, -56)
    panel:SetPoint("BOTTOMRIGHT", -10, 10)
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -28, 6)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    UI.SetFont(edit, 11)
    edit:SetWidth(560)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    -- read-only: typing puts the log back
    edit:SetScript("OnTextChanged", function(self, user) if user then self:SetText(LogText()) end end)
    scroll:SetScrollChild(edit)
    scroll:SetScript("OnSizeChanged", function(self, w) edit:SetWidth(math.max(200, (w or 560) - 4)) end)
    win.edit = edit

    function win:Refresh()
        if not self:IsShown() then return end
        self.edit:SetText(LogText())
        self.edit:SetCursorPosition(0)
    end
    win:SetScript("OnShow", function(self) self:Refresh() end)
end

function JQ.ErrorCommand(arg)
    arg = (arg or ""):lower()
    if arg == "clear" then
        JaseQoLDB.errors = {}
        JQ.Print("Error log cleared.")
        if win and win:IsShown() then win:Refresh() end
        return
    end
    if not win then Build() end
    win:Show()
    win:Refresh()
end

-- for tests
JQ._ErrorLog = { LogText = LogText, Mine = Mine, WhereFrom = WhereFrom }
