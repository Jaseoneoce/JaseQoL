-------------------------------------------------------------------------------
--  JaseTools: Core
--
--  Every tweak lives in Modules\ and registers itself here with JQ.AddModule.
--  Each module gets an on/off switch saved in JaseQoLDB.modules[key]
--  (true = on). Switches show in EllesmereUI's options (JaseTools section) and
--  under /jq. Modules marked needsReload only change after a /reload.
-------------------------------------------------------------------------------
local ADDON_NAME, JQ = ...
_G.JaseQoL = JQ

JQ.modules = {}      -- ordered list of module specs
JQ.byKey = {}

-- spec = { key, label, description, default (bool), needsReload (bool),
--          onEnable(fn), onDisable(fn), onLoad(fn, enabled) }
function JQ.AddModule(spec)
    if not spec or not spec.key or JQ.byKey[spec.key] then return end
    if spec.default == nil then spec.default = true end
    JQ.modules[#JQ.modules + 1] = spec
    JQ.byKey[spec.key] = spec
end

-- Before SavedVariables load (DB nil) a module reads as its default.
function JQ.IsEnabled(key)
    local spec = JQ.byKey[key]
    local db = JaseQoLDB and JaseQoLDB.modules
    if db and db[key] ~= nil then return db[key] end
    return spec and spec.default or false
end

function JQ.Print(msg)
    print("|cff0cd29fJaseTools|r: " .. tostring(msg))
end

-------------------------------------------------------------------------------
--  Error log: JaseTools' own errors, kept in JaseQoLDB.errors (newest first,
--  50 at most; the same error again just counts up). Code that must never
--  break the game's own windows runs through JQ.Try, which records the error
--  instead of throwing. /jq errors shows the log (Modules\ErrorLog.lua).
-------------------------------------------------------------------------------
local MAX_ERRORS = 50
local seenThisSession = {}

function JQ.Error(where, err)
    local msg = tostring(err or "?")
    JQ._lastError = msg
    local stack = debugstack and debugstack(3, 8, 0) or ""
    -- keep our own lines of the stack: they say where it went wrong
    local ours = {}
    for line in stack:gmatch("[^\n]+") do
        if line:find("JaseQoL", 1, true) then ours[#ours + 1] = line:gsub("^.-AddOns[/\\]", "") end
        if #ours >= 4 then break end
    end
    local now = time and time() or 0
    if JaseQoLDB then
        local log = JaseQoLDB.errors or {}
        JaseQoLDB.errors = log
        for i, e in ipairs(log) do
            if e.msg == msg and e.where == where then
                e.count, e.last = (e.count or 1) + 1, now
                table.remove(log, i)
                table.insert(log, 1, e)
                return
            end
        end
        table.insert(log, 1, { where = where, msg = msg, stack = table.concat(ours, "\n"),
            count = 1, first = now, last = now,
            version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("JaseQoL", "Version") })
        while #log > MAX_ERRORS do table.remove(log) end
    end
    -- a short note the first time an error turns up in a session
    local key = where .. "|" .. msg
    if not seenThisSession[key] then
        seenThisSession[key] = true
        if JQ.IsEnabled("errorNotify") then
            JQ.Print("|cffff7070error in " .. where .. "|r (logged). Type /jq errors to see it.")
        end
    end
end

-- Run fn(...) and record any error instead of throwing it. Returns pcall's results.
function JQ.Try(where, fn, ...)
    local results = { pcall(fn, ...) }
    if not results[1] then JQ.Error(where, results[2]) end
    return unpack(results)
end

function JQ.SetEnabled(key, value)
    local spec = JQ.byKey[key]
    if not spec then return end
    value = value and true or false
    if JQ.IsEnabled(key) == value then return end
    JaseQoLDB.modules[key] = value
    JQ.ApplyChange(key, value)
end

-- Side effects of a switch that was already saved (the game's Settings panel
-- writes JaseQoLDB.modules itself, then calls this).
function JQ.ApplyChange(key, value)
    local spec = JQ.byKey[key]
    if not spec then return end
    if spec.needsReload then
        JQ.Print(spec.label .. (value and " on" or " off") .. ". Type /reload to apply.")
        return
    end
    local fn = value and spec.onEnable or spec.onDisable
    if fn then JQ.Try(spec.key .. (value and " (switching on)" or " (switching off)"), fn) end
    if JQ.Hub then JQ.Try("window tabs", JQ.Hub.UpdateTabs) end
    JQ.Print(spec.label .. (value and " on." or " off."))
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON_NAME then return end
    self:UnregisterEvent("ADDON_LOADED")
    JaseQoLDB = JaseQoLDB or {}
    JaseQoLDB.modules = JaseQoLDB.modules or {}
    for _, spec in ipairs(JQ.modules) do
        if spec.onLoad then
            local ok, err = pcall(spec.onLoad, JQ.IsEnabled(spec.key))
            if not ok then
                JQ.Error(spec.key .. " (loading)", err)
                geterrorhandler()(err)
            end
        end
    end
end)
