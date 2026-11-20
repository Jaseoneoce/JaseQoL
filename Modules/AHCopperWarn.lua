-------------------------------------------------------------------------------
--  JaseQoL: auction house copper warning
--
--  WoW Forever's auction house doesn't post single items (gear, recipes,
--  scrolls...) whose price has copper in it: the server never answers, so the
--  sell window (the game's or Auctionator's) hangs. Stackable goods are fine.
--  Blizzard know (EU forums, 9 Nov 2026: "leaving copper out seems to be
--  helping for now"). When a single item is posted with copper in its price,
--  this warns on screen and in chat. Nothing is changed or blocked.
-------------------------------------------------------------------------------
local _, JQ = ...
local KEY = "ahCopperWarn"

JQ.AddModule({
    key = KEY,
    label = "Warn about copper in auction prices",
    description = "WoW Forever's auction house won't post single items (gear, recipes, scrolls) when the price has copper in it: the sell window just hangs. Stackable goods are fine. This warns you when you post a single item with copper in its price, so you can relist at whole silver (e.g. 1s, not 46c). It doesn't change or block anything.",
    default = true,
})

local function HasCopper(v)
    return type(v) == "number" and v > 0 and v % 100 ~= 0
end

local function Money(v)
    if GetMoneyString then
        local ok, s = pcall(GetMoneyString, v)
        if ok and s then return s end
    end
    local g, s, c = math.floor(v / 10000), math.floor(v / 100) % 100, v % 100
    local out = (g > 0 and (g .. "g ") or "") .. (s > 0 and (s .. "s ") or "") .. (c > 0 and (c .. "c") or "")
    return (out:gsub("%s+$", ""))
end

local function ItemName(loc)
    if type(loc) == "table" and C_Item and C_Item.GetItemLink then
        local ok, link = pcall(C_Item.GetItemLink, loc)
        if ok and link then return link end
    end
    return "this item"
end

local function Warn(loc, bid, buyout)
    if not JQ.IsEnabled(KEY) then return end
    local price = HasCopper(buyout) and buyout or (HasCopper(bid) and bid) or nil
    if not price then return end
    local item = ItemName(loc)
    local down, up = math.floor(price / 100) * 100, math.ceil(price / 100) * 100
    local suggest = down > 0 and (Money(down) .. " or " .. Money(up)) or Money(up)
    JQ.Print(("|cffff6050%s was posted at %s, which has copper in it. WoW Forever's auction house doesn't post single items with copper: if the sell window hangs, relog and list it at whole silver (%s).|r")
        :format(item, Money(price), suggest))
    if RaidNotice_AddMessage and RaidWarningFrame then
        RaidNotice_AddMessage(RaidWarningFrame, "Copper in the price: single items may not post. Use whole silver.",
            ChatTypeInfo and ChatTypeInfo.RAID_WARNING or { r = 1, g = 0.3, b = 0.2 })
    end
    if PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then PlaySound(SOUNDKIT.RAID_WARNING) end
end

-- C_AuctionHouse.PostItem(item, duration, quantity, bid, buyout); commodities
-- (PostCommodity) post fine with copper, so they're left alone.
if C_AuctionHouse and C_AuctionHouse.PostItem then
    hooksecurefunc(C_AuctionHouse, "PostItem", function(loc, _, _, bid, buyout)
        Warn(loc, bid, buyout)
    end)
end

-- for tests
JQ._AHCopperWarn = { HasCopper = HasCopper }
