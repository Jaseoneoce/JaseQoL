-------------------------------------------------------------------------------
--  JaseTools: auction house debug log
--
--  For tracking down auction house posts that time out. While it's on, it
--  records to JaseQoLDB.ahDebug.log (saved at logout or /reload):
--    * each login / reload, with the addons that are loaded
--    * every auction house call (C_AuctionHouse.*) and which addon made it;
--      lookups (Get*, Is*, Has*, Can*, Calculate*) are only counted
--    * auction house events, error messages, system messages and blocked
--      actions while the auction house is open (repeats are collapsed)
--    * "NO REPLY" when a post gets no answer from the server within 10 s
--  /jahlog          show the latest lines
--  /jahlog mark x   add a note ("stuck here")
--  /jahlog clear    empty the log
--  /jahlog on|off   switch logging on or off
-------------------------------------------------------------------------------
local _, JQ = ...
local KEY = "ahDebug"

JQ.AddModule({
    key = KEY,
    label = "Auction house debug log",
    description = "Records what happens at the auction house (every call, which addon made it, the server's replies, errors and blocked actions) to find out why posting times out. /jahlog shows the latest lines, /jahlog mark <note> adds a note. The log is saved when you log out or /reload.",
    default = false,
})

local MAX_LINES = 5000
local REPLY_WAIT = 10

local function On() return JQ.IsEnabled(KEY) and JaseQoLDB ~= nil end

local function DB()
    JaseQoLDB.ahDebug = JaseQoLDB.ahDebug or {}
    local d = JaseQoLDB.ahDebug
    d.log = d.log or {}
    d.counts = d.counts or {}
    return d
end

local function Stamp()
    return ("%s %.3f"):format(date("%H:%M:%S"), GetTime())
end

local last   -- { text, n, index } of the newest line, for collapsing repeats
local function Add(text)
    if not On() then return end
    local log = DB().log
    if last and last.text == text and log[last.index] then
        last.n = last.n + 1
        log[last.index] = last.stamp .. "  " .. text .. ("  (x%d, last %s)"):format(last.n, Stamp())
        return
    end
    local stamp = Stamp()
    log[#log + 1] = stamp .. "  " .. text
    if #log > MAX_LINES then
        local drop = #log - MAX_LINES + 500
        local keep = {}
        for i = drop + 1, #log do keep[#keep + 1] = log[i] end
        DB().log = keep
        log = keep
    end
    last = { text = text, n = 1, index = #log, stamp = stamp }
end
JQ.AHLog = Add

-------------------------------------------------------------------------------
--  Describing arguments and callers
-------------------------------------------------------------------------------
local function Safe(v)
    if issecretvalue and issecretvalue(v) then return "<secret>" end
    local ok, s = pcall(tostring, v)
    return ok and s or "?"
end

local function Arg(v)
    if type(v) ~= "table" then
        local s = Safe(v)
        return #s > 60 and (s:sub(1, 57) .. "...") or s
    end
    if v.GetBagAndSlot then
        local ok, bag, slot = pcall(v.GetBagAndSlot, v)
        local link = C_Item and C_Item.GetItemLink and select(2, pcall(C_Item.GetItemLink, v))
        local name = type(link) == "string" and link:match("%[(.-)%]")
        return ("bag %s/%s %s"):format(ok and Safe(bag) or "?", ok and Safe(slot) or "?", name or "")
    end
    if v.itemID then
        local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(v.itemID)
        return "item " .. Safe(v.itemID) .. (name and (" " .. name) or "")
    end
    if v.auctionID then return "auction " .. Safe(v.auctionID) end
    return "{table}"
end

local function Args(...)
    local n = select("#", ...)
    local out = {}
    for i = 1, math.min(n, 6) do out[#out + 1] = Arg((select(i, ...))) end
    return table.concat(out, ", ")
end

-- The addon behind a call: the first one in the call stack that isn't
-- JaseTools, preferring a third-party addon over the game's own UI.
local function Caller()
    local stack = debugstack and debugstack(3, 20, 0) or ""
    local blizz
    for name in stack:gmatch("AddOns[/\\]([^/\\]+)[/\\]") do
        if name ~= "JaseQoL" then
            if name:find("^Blizzard_") then blizz = blizz or name else return name end
        end
    end
    if blizz then return blizz end
    if stack:find("%[string") then return "macro/script" end
    return "?"
end

-------------------------------------------------------------------------------
--  Calls
-------------------------------------------------------------------------------
local LOOKUP = { "^Get", "^Is", "^Has", "^Can", "^Calculate", "^Make", "^Favorite" }
local function IsLookup(name)
    for _, p in ipairs(LOOKUP) do if name:find(p) then return true end end
    return false
end

local POSTS = { PostItem = true, PostCommodity = true, PostAuction = true, StartAuction = true }
local pending = {}   -- [seq] = name, posts still waiting for a reply
local seq = 0
local function Answered(what)
    local oldest
    for k in pairs(pending) do if not oldest or k < oldest then oldest = k end end
    if oldest then
        Add(("   reply to %s: %s"):format(pending[oldest], what))
        pending[oldest] = nil
    end
end

local function Hook(tbl, name, label)
    if type(tbl[name]) ~= "function" then return end
    local lookup = IsLookup(name)
    hooksecurefunc(tbl, name, function(...)
        if not On() then return end
        if lookup then
            local c = DB().counts
            c[label] = (c[label] or 0) + 1
            return
        end
        Add(("CALL %s(%s)  by %s"):format(label, Args(...), Caller()))
        if POSTS[name] then
            local ready = C_AuctionHouse and C_AuctionHouse.IsThrottledMessageSystemReady
            if ready then Add("   throttle ready before the post: " .. Safe(ready())) end
            seq = seq + 1
            local mine = seq
            pending[mine] = label
            C_Timer.After(REPLY_WAIT, function()
                if pending[mine] then
                    pending[mine] = nil
                    Add(("!! NO REPLY %ds after %s"):format(REPLY_WAIT, label))
                    JQ.Print(("AH debug: no reply from the server %ds after %s. Logged. Type /jahlog mark <what you saw>."):format(REPLY_WAIT, label))
                end
            end)
        end
    end)
end

local function InstallHooks()
    if C_AuctionHouse then
        local names = {}
        for name, fn in pairs(C_AuctionHouse) do
            if type(fn) == "function" then names[#names + 1] = name end
        end
        table.sort(names)
        for _, name in ipairs(names) do Hook(C_AuctionHouse, name, "C_AuctionHouse." .. name) end
    end
    for _, name in ipairs({ "PostAuction", "StartAuction", "QueryAuctionItems", "PlaceAuctionBid", "CancelAuction" }) do
        Hook(_G, name, name)
    end
end

-------------------------------------------------------------------------------
--  Events
-------------------------------------------------------------------------------
-- Logged only while the auction house is open (all events are watched then).
local WATCH = { "AUCTION", "COMMODITY", "ITEM_SEARCH", "ITEM_KEY", "OWNED_AUCTION", "BIDS_",
    "THROTTL", "UI_ERROR_MESSAGE", "UI_INFO_MESSAGE", "CHAT_MSG_SYSTEM", "PLAYER_INTERACTION_MANAGER",
    "MODIFIERS", "CURSOR_CHANGED", "BAG_UPDATE_DELAYED", "PLAYER_MONEY", "ITEM_LOCK" }
local REPLIES = {
    AUCTION_HOUSE_AUCTION_CREATED = true, AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED = true,
    AUCTION_HOUSE_POST_ERROR = true, AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED = true,
    COMMODITY_PURCHASE_FAILED = true, UI_ERROR_MESSAGE = true,
}
-- Always logged.
local ALWAYS = { "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "LUA_WARNING",
    "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED",
    "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
    "AUCTION_HOUSE_DISABLED", "DISCONNECTED_FROM_SERVER" }
local IS_ALWAYS = {}
for _, e in ipairs(ALWAYS) do IS_ALWAYS[e] = true end

local function Watched(event)
    if IS_ALWAYS[event] then return true end
    for _, p in ipairs(WATCH) do if event:find(p, 1, true) then return true end end
    return false
end

local ahOpen = false
local ev = CreateFrame("Frame")
local function AuctioneerKind(kind)
    local PIT = Enum and Enum.PlayerInteractionType
    return PIT and PIT.Auctioneer and kind == PIT.Auctioneer
end

local function LoadedAddons()
    local out = {}
    local num = (C_AddOns and C_AddOns.GetNumAddOns or GetNumAddOns)
    local info = (C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo)
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded)
    if not (num and info and loaded) then return "?" end
    for i = 1, num() do
        local name = info(i)
        if name and not name:find("^Blizzard_") and loaded(i) then out[#out + 1] = name end
    end
    return table.concat(out, ", ")
end

local function SetOpen(open)
    if open == ahOpen then return end
    ahOpen = open
    if open then
        ev:RegisterAllEvents()
        local ready = C_AuctionHouse and C_AuctionHouse.IsThrottledMessageSystemReady
        Add("== AUCTION HOUSE OPEN" .. (ready and ("  throttle ready: " .. Safe(ready())) or ""))
    else
        ev:UnregisterAllEvents()
        for _, e in ipairs(ALWAYS) do pcall(ev.RegisterEvent, ev, e) end
        wipe(pending)
        Add("== AUCTION HOUSE CLOSED")
    end
end

ev:SetScript("OnEvent", function(_, event, ...)
    if not On() then return end
    if event == "PLAYER_ENTERING_WORLD" then
        local login, reload = ...
        if login or reload then
            local name = UnitName("player")
            Add(("==== %s as %s  (%s)"):format(login and "LOGIN" or "RELOAD", Safe(name), Safe(GetRealmName())))
            Add("addons: " .. LoadedAddons())
        end
        return
    end
    if event == "AUCTION_HOUSE_SHOW" then SetOpen(true)
    elseif event == "AUCTION_HOUSE_CLOSED" then SetOpen(false)
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" or event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        if not AuctioneerKind((...)) then return end
        SetOpen(event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
        return
    end
    if not Watched(event) then
        local c = DB().counts
        c["event " .. event] = (c["event " .. event] or 0) + 1
        return
    end
    if event == "AUCTION_HOUSE_SHOW" or event == "AUCTION_HOUSE_CLOSED" then return end
    local args = Args(...)
    Add(event .. (args ~= "" and ("  " .. args) or ""))
    if REPLIES[event] then Answered(event .. (args ~= "" and (" " .. args) or "")) end
end)

-------------------------------------------------------------------------------
--  Setup and /jahlog
-------------------------------------------------------------------------------
local setup = CreateFrame("Frame")
setup:RegisterEvent("ADDON_LOADED")
setup:SetScript("OnEvent", function(self, _, name)
    if name ~= "JaseQoL" then return end
    self:UnregisterEvent("ADDON_LOADED")
    for _, e in ipairs(ALWAYS) do pcall(ev.RegisterEvent, ev, e) end
    local ok, err = pcall(InstallHooks)
    if not ok then geterrorhandler()(err) end
end)

JQ.byKey[KEY].onEnable = function() Add("-- logging switched on") end
JQ.byKey[KEY].onDisable = function() SetOpen(false) end

SLASH_JASEQOLAHLOG1 = "/jahlog"
SlashCmdList.JASEQOLAHLOG = function(msg)
    msg = strtrim(msg or "")
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "on" or cmd == "off" then
        JQ.SetEnabled(KEY, cmd == "on")
        return
    end
    if not On() then
        JQ.Print("Auction house debug log is off. Type /jahlog on to start it.")
        return
    end
    if cmd == "clear" then
        JaseQoLDB.ahDebug = nil; last = nil
        JQ.Print("AH debug log cleared.")
    elseif cmd == "mark" then
        Add("## MARK: " .. (rest ~= "" and rest or "(no note)"))
        JQ.Print("Marked. /reload or log out to save the log.")
    else
        local log = DB().log
        JQ.Print(("AH debug log: %d lines (saved at logout or /reload). Latest:"):format(#log))
        for i = math.max(1, #log - 24), #log do JQ.Print(log[i]) end
    end
end

-- for tests
JQ._AHDebug = { Caller = Caller, Args = Args, IsLookup = IsLookup }
