-------------------------------------------------------------------------------
--  JaseQoL: Alt tracking + item tooltips
--
--  Remembers, for every character you log in on (account-wide, per realm):
--    class, level, faction, professions (with skill), and item counts in
--    bags, bank (seen when you open the bank) and mailbox (seen when you open
--    the mailbox; mail JaseQoL sends to an alt is added straight away).
--  JaseQoLDB.alts[realm][name] = { class, level, faction, profs = {name=rank},
--    bags = {[itemID]=n}, bank = {[itemID]=n}, mail = {[itemID]=n},
--    bankTime, mailTime, time }
--
--  Tooltip module: adds "Alts: Name 20 (bank 15, bags 5)" lines to item
--  tooltips, for your characters on this realm.
-------------------------------------------------------------------------------
local _, JQ = ...
local KEY, TIP_KEY = "altTracker", "altTooltip"

JQ.AddModule({
    key = KEY,
    label = "Alt tracking",
    description = "Remembers each character's professions and what's in their bags, bank and mailbox, for the alt inventory window, tooltips and Send mats. Bank and mail are read when you open them on that character.",
    default = true,
})
JQ.AddModule({
    key = TIP_KEY,
    label = "Alt counts on item tooltips",
    description = "Item tooltips list which of your characters on this realm have the item and how many (bags, bank, mail). Needs Alt tracking.",
    default = true,
})

local Alts = {}
JQ.Alts = Alts
local bankOpen = false

local C = C_Container
local REALM, NAME

-- Professions recognised (English client names).
Alts.PROFESSIONS = {
    "Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Herbalism", "Jewelcrafting",
    "Inscription", "Leatherworking", "Mining", "Skinning", "Tailoring",
    "Cooking", "First Aid", "Fishing", "Lockpicking",
}
local IS_PROF = {}
for _, p in ipairs(Alts.PROFESSIONS) do IS_PROF[p] = true end

-------------------------------------------------------------------------------
--  Storage
-------------------------------------------------------------------------------
function Alts.Realm() return REALM or GetRealmName() end

function Alts.RealmTable(realm)
    JaseQoLDB.alts = JaseQoLDB.alts or {}
    realm = realm or Alts.Realm()
    JaseQoLDB.alts[realm] = JaseQoLDB.alts[realm] or {}
    return JaseQoLDB.alts[realm]
end

-- The character's name and realm, looked up as soon as the game has them
-- (some events, like SKILL_LINES_CHANGED, arrive before PLAYER_LOGIN).
local function EnsureName()
    if NAME then return true end
    local n = UnitName and UnitName("player")
    local r = GetRealmName and GetRealmName()
    if type(n) == "string" and n ~= "" and n ~= UNKNOWNOBJECT and type(r) == "string" and r ~= "" then
        NAME, REALM = n, r
        return true
    end
    return false
end
Alts.EnsureName = EnsureName

function Alts.Me()
    if not EnsureName() then return { bags = {}, bank = {}, mail = {}, profs = {} } end   -- not saved
    local t = Alts.RealmTable()
    local me = t[NAME]
    if not me then
        me = { bags = {}, bank = {}, mail = {}, profs = {} }
        t[NAME] = me
    end
    return me
end

function Alts.MyName() return NAME end

-- Shown name: first name + last initial ("Jaseone B.") when the last name is
-- known, else the first name.
function Alts.Display(name)
    local data = name and Alts.RealmTable()[name]
    local sur = data and data.surname
    if not sur and data and data.full and data.full ~= name then
        sur = data.full:sub(#name + 2)
    end
    if sur and sur ~= "" then
        local initial = sur:match("^[%z\1-\127\194-\244][\128-\191]*") or sur:sub(1, 1)
        return name .. " " .. initial .. "."
    end
    return name
end

-- What mail is addressed to: the full name ("First Last") when known.
function Alts.MailName(name)
    local data = name and Alts.RealmTable()[name]
    return (data and data.full) or name
end

function Alts.HasFullName(name)
    local data = name and Alts.RealmTable()[name]
    return data and data.full and data.full ~= name or false
end

-- Last names JaseQoL hasn't seen yet, borrowed from EllesmereUI: it records
-- every character's full name ("First Last") when that character logs in.
function Alts.LearnNames()
    local db = EllesmereUIDB
    local chars = type(db) == "table" and type(db.chars) == "table" and db.chars
    if not chars then return end
    local realm = Alts.RealmTable()
    for _, c in pairs(chars) do
        local full = type(c) == "table" and c.name
        if type(full) == "string" then
            local first, rest = full:match("^(%S+)%s+(.+)$")
            local data = first and realm[first]
            if data and not (data.full and data.full ~= first) then
                data.full = full
                data.surname = rest
            end
        end
    end
end

-- Characters on this realm, sorted by name. sameFaction: only my faction.
function Alts.List(sameFaction)
    local out = {}
    local myFaction = UnitFactionGroup("player")
    for name, data in pairs(Alts.RealmTable()) do
        if not sameFaction or data.faction == myFaction then
            out[#out + 1] = { name = name, data = data, display = Alts.Display(name) }
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

function Alts.Count(data, id)
    local b = (data.bags and data.bags[id]) or 0
    local k = (data.bank and data.bank[id]) or 0
    local m = (data.mail and data.mail[id]) or 0
    return b + k + m, b, k, m
end

local function remember(id, link)
    if not (id and link) then return end
    JaseQoLDB.items = JaseQoLDB.items or {}
    if JaseQoLDB.items[id] then return end
    local name = link:match("%[(.-)%]")
    local q
    if C_Item and C_Item.GetItemQualityByID then q = C_Item.GetItemQualityByID(id) end
    if name then JaseQoLDB.items[id] = { n = name, q = q } end
end

-------------------------------------------------------------------------------
--  Container scanning
-------------------------------------------------------------------------------
local function NumSlots(bag)
    if C and C.GetContainerNumSlots then return C.GetContainerNumSlots(bag) or 0 end
    return GetContainerNumSlots and GetContainerNumSlots(bag) or 0
end

-- itemID, count, isBound, link
function Alts.SlotInfo(bag, slot)
    if C and C.GetContainerItemInfo then
        local i = C.GetContainerItemInfo(bag, slot)
        if i then return i.itemID, i.stackCount, i.isBound, i.hyperlink end
        return nil
    end
    if GetContainerItemInfo then
        local _, count, _, _, _, _, link, _, _, id, isBound = GetContainerItemInfo(bag, slot)
        return id, count, isBound, link
    end
end

function Alts.BagIDs()
    local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
    local ids = {}
    for b = 0, last do ids[#ids + 1] = b end
    return ids
end

function Alts.BankIDs()
    -- WoW Forever (new engine): the character bank is bank tabs, CharacterBankTab_1.._9
    local BI = Enum and Enum.BagIndex
    if BI and BI.CharacterBankTab_1 then
        local ids = {}
        for i = 1, 9 do
            local id = BI["CharacterBankTab_" .. i]
            if id then ids[#ids + 1] = id end
        end
        return ids
    end
    local ids = { (BI and BI.Bank) or BANK_CONTAINER or -1 }
    local first = (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) + 1
    for b = first, first + (NUM_BANKBAGSLOTS or 7) - 1 do ids[#ids + 1] = b end
    return ids
end

local function Scan(bagIDs)
    local counts = {}
    for _, bag in ipairs(bagIDs) do
        for slot = 1, NumSlots(bag) do
            local id, count, _, link = Alts.SlotInfo(bag, slot)
            if id then
                counts[id] = (counts[id] or 0) + (count or 1)
                remember(id, link)
            end
        end
    end
    return counts
end

bankOpen = false

local function ScanBags()
    local me = Alts.Me()
    me.bags = Scan(Alts.BagIDs())
    me.time = time()
end

local function ScanBank()
    if not bankOpen then return end
    local me = Alts.Me()
    me.bank = Scan(Alts.BankIDs())
    me.bankTime = time()
end

local function ScanMail()
    if not GetInboxNumItems then return end
    local me = Alts.Me()
    local counts = {}
    local n = GetInboxNumItems() or 0
    local maxAttach = ATTACHMENTS_MAX_RECEIVE or 16
    for i = 1, n do
        for a = 1, maxAttach do
            local name, id, _, count = GetInboxItem(i, a)
            if name and id then
                counts[id] = (counts[id] or 0) + (count or 1)
                local link = GetInboxItemLink and GetInboxItemLink(i, a)
                remember(id, link)
            end
        end
    end
    me.mail = counts
    me.mailTime = time()
end

local function ScanProfessions()
    local me = Alts.Me()
    local profs = {}
    if GetNumSkillLines and GetSkillLineInfo then
        for i = 1, GetNumSkillLines() do
            local name, isHeader, _, rank = GetSkillLineInfo(i)
            if name and not isHeader and IS_PROF[name] then profs[name] = rank or 0 end
        end
    end
    if not next(profs) and GetProfessions and GetProfessionInfo then
        for _, idx in ipairs({ GetProfessions() }) do
            if idx then
                local name, _, rank = GetProfessionInfo(idx)
                if name and IS_PROF[name] then profs[name] = rank or 0 end
            end
        end
    end
    me.profs = profs
end

-- WoW Forever characters have a last name: UnitName returns it second.
-- Mail is addressed by the full name there ("First Last").
local SEP = (Constants and Constants.CharacterNameSeparatorConsts
    and Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR) or " "

local function Identity()
    local me = Alts.Me()
    local first, surname = (UnitNameUnmodified or UnitName)("player")
    if type(first) == "string" and not (issecretvalue and issecretvalue(first)) then
        if type(surname) == "string" and surname ~= "" and not (issecretvalue and issecretvalue(surname)) then
            me.full = first .. SEP .. surname
            me.surname = surname
        else
            me.full = me.full or first
        end
    end
    local _, class = UnitClass("player")
    me.class = class
    me.level = UnitLevel("player")
    me.faction = UnitFactionGroup("player")
end

-- Where each character is parked (zone + sub-zone, saved as it moves and at
-- logout), and the towns with a bank: the known ones plus any town where a
-- bank has actually been opened (JaseQoLDB.bankTowns).
Alts.BANK_TOWNS = {
    ["Stormwind City"] = true, ["Ironforge"] = true, ["Darnassus"] = true,
    ["Orgrimmar"] = true, ["Undercity"] = true, ["Thunder Bluff"] = true,
    ["Booty Bay"] = true, ["Gadgetzan"] = true, ["Everlook"] = true,
}

local function RecordLocation()
    local me = Alts.Me()
    local zone = GetRealZoneText and GetRealZoneText() or nil
    local sub = GetSubZoneText and GetSubZoneText() or nil
    if type(zone) == "string" and zone ~= "" then me.zone = zone end
    me.subzone = (type(sub) == "string" and sub ~= "") and sub or nil
end

local function LearnBankTown()
    local me = Alts.Me()
    JaseQoLDB.bankTowns = JaseQoLDB.bankTowns or {}
    if me.subzone then JaseQoLDB.bankTowns[me.subzone] = true end
    if me.zone then JaseQoLDB.bankTowns[me.zone] = true end
end

function Alts.IsBankTown(name)
    if not name then return false end
    return Alts.BANK_TOWNS[name] or (JaseQoLDB.bankTowns and JaseQoLDB.bankTowns[name]) or false
end

-- Is this character parked in a town with a bank?
function Alts.InBankTown(altName)
    local data = Alts.RealmTable()[altName]
    if not data then return false end
    return Alts.IsBankTown(data.subzone) or Alts.IsBankTown(data.zone)
end

-- "Ironforge" / "Booty Bay, Stranglethorn Vale" / nil
function Alts.WhereText(altName)
    local data = Alts.RealmTable()[altName]
    if not (data and data.zone) then return nil end
    if data.subzone and data.subzone ~= data.zone and Alts.IsBankTown(data.subzone) then
        return data.subzone .. ", " .. data.zone
    end
    return data.zone
end

function Alts.IsBankOpen() return bankOpen end

-- Windows that show alt data refresh through this.
local listeners = {}
function Alts.OnChange(fn) listeners[#listeners + 1] = fn end
function Alts.Changed()
    for _, fn in ipairs(listeners) do pcall(fn) end
end

-- Called by Send mats after a mail goes out: the alt has it "in the mail".
function Alts.AddMail(altName, counts)
    local alt = Alts.RealmTable()[altName]
    if not alt then return end
    alt.mail = alt.mail or {}
    for id, n in pairs(counts) do alt.mail[id] = (alt.mail[id] or 0) + n end
end

-------------------------------------------------------------------------------
--  Events (throttled bag scans)
-------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
local bagPending
local function QueueBags()
    if bagPending then return end
    bagPending = true
    C_Timer.After(0.5, function()
        bagPending = nil
        if not JQ.IsEnabled(KEY) then return end
        ScanBags()
        ScanBank()
        Alts.Changed()
    end)
end

ev:SetScript("OnEvent", function(_, event, ...)
    if not JQ.IsEnabled(KEY) then return end
    -- at login, read who we are afresh
    if event == "PLAYER_LOGIN" then NAME = nil end
    -- nothing to file anything under until the game knows who we are
    if not EnsureName() then return end
    if event == "PLAYER_LOGIN" then
        Identity(); ScanProfessions(); ScanBags(); RecordLocation()
        pcall(Alts.LearnNames)
    elseif event == "SKILL_LINES_CHANGED" or event == "TRADE_SKILL_SHOW" then
        ScanProfessions()
    elseif event == "PLAYER_LEVEL_UP" then
        Identity()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED"
        or event == "ZONE_CHANGED_INDOORS" or event == "PLAYER_LOGOUT" then
        RecordLocation()
    elseif event == "BANKFRAME_OPENED" then
        bankOpen = true; RecordLocation(); LearnBankTown(); ScanBank(); Alts.Changed()
    elseif event == "BANKFRAME_CLOSED" then
        bankOpen = false
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" or event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        local kind = ...
        local PIT = Enum and Enum.PlayerInteractionType
        if PIT and (kind == PIT.Banker or kind == PIT.CharacterBanker) then
            if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
                if not bankOpen then
                    bankOpen = true; RecordLocation(); LearnBankTown(); ScanBank(); Alts.Changed()
                end
            else
                bankOpen = false
            end
        end
    elseif event == "MAIL_INBOX_UPDATE" or event == "MAIL_SHOW" then
        ScanMail(); Alts.Changed()
    else
        QueueBags()
    end
end)

JQ.byKey[KEY].onLoad = function()
    JaseQoLDB.alts = JaseQoLDB.alts or {}
    JaseQoLDB.items = JaseQoLDB.items or {}
    for _, e in ipairs({ "PLAYER_LOGIN", "SKILL_LINES_CHANGED", "TRADE_SKILL_SHOW", "PLAYER_LEVEL_UP",
        "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "PLAYER_LOGOUT",
        "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "MAIL_SHOW", "MAIL_INBOX_UPDATE",
        "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
        "BAG_UPDATE_DELAYED", "PLAYERBANKSLOTS_CHANGED", "PLAYERBANKBAGSLOTS_CHANGED" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
end

-------------------------------------------------------------------------------
--  Tooltip lines
-------------------------------------------------------------------------------
local function ItemIDFromTooltip(tt, data)
    if data and data.id then return data.id end
    if tt.GetItem then
        local _, link = tt:GetItem()
        if link then return tonumber(link:match("item:(%d+)")) end
    end
end

local function AddLines(tt, data)
    if not (JQ.IsEnabled(KEY) and JQ.IsEnabled(TIP_KEY)) then return end
    if tt ~= GameTooltip and tt ~= ItemRefTooltip then return end
    local id = ItemIDFromTooltip(tt, data)
    if not id or not REALM then return end
    local lines, total = {}, 0
    for _, e in ipairs(Alts.List(false)) do
        local n, b, k, m = Alts.Count(e.data, id)
        if n > 0 then
            total = total + n
            local parts = {}
            if b > 0 then parts[#parts + 1] = "bags " .. b end
            if k > 0 then parts[#parts + 1] = "bank " .. k end
            if m > 0 then parts[#parts + 1] = "mail " .. m end
            lines[#lines + 1] = { ("|cff%s%s|r"):format(JQ.UI.ClassHex(e.data.class), e.display),
                n .. "  |cff9e9ea8(" .. table.concat(parts, ", ") .. ")|r" }
        end
    end
    if #lines == 0 then return end
    tt:AddLine(" ")
    for _, l in ipairs(lines) do tt:AddDoubleLine(l[1], l[2], 1, 1, 1, 1, 1, 1) end
    if #lines > 1 then tt:AddDoubleLine("|cff9e9ea8Total|r", total, 1, 1, 1, 1, 1, 1) end
    tt:Show()
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AddLines)
else
    for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
        if tt and tt.HookScript then
            pcall(tt.HookScript, tt, "OnTooltipSetItem", function(self) AddLines(self) end)
        end
    end
end
