-------------------------------------------------------------------------------
--  JaseQoL: Core
--
--  Every tweak lives in Modules\ and registers itself here with JQ.AddModule.
--  Each module gets an on/off switch saved in JaseQoLDB.modules[key]
--  (true = on). Switches show in EllesmereUI's options (JaseQoL section) and
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
    print("|cff0cd29fJaseQoL|r: " .. tostring(msg))
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
    if fn then pcall(fn) end
    if JQ.Hub then pcall(JQ.Hub.UpdateTabs) end
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
            if not ok then geterrorhandler()(err) end
        end
    end
end)
