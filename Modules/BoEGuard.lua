-------------------------------------------------------------------------------
--  JaseQoL: BoE sell warning
--
--  Selling a Bind on Equip item to a vendor (right-click with the merchant
--  open) puts a big warning on screen and in chat, with the item link, so it
--  can be bought straight back from the merchant's Buyback tab.
--  (The "BoE" label on bag slots is EllesmereUI's own option:
--  EllesmereUI > Bags > Show BoE / Warbound Text.)
-------------------------------------------------------------------------------
local _, JQ = ...
local KEY = "boeGuard"

JQ.AddModule({
    key = KEY,
    label = "Warn when selling BoE items",
    description = "Selling a Bind on Equip item to a vendor shows a big on-screen warning with the item, so you can buy it back from the Buyback tab. For a BoE label on bag slots, turn on EllesmereUI > Bags > Show BoE / Warbound Text.",
    default = true,
})

local C = C_Container
local GetItemInfoFn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local BIND_ON_EQUIP = (Enum and Enum.ItemBind and Enum.ItemBind.OnEquip) or 2

local function Check(bag, slot)
    if not JQ.IsEnabled(KEY) then return end
    if not (MerchantFrame and MerchantFrame:IsShown()) then return end
    local info = C and C.GetContainerItemInfo and C.GetContainerItemInfo(bag, slot)
    if not info or info.isBound then return end
    local link = info.hyperlink
    local bindType = select(14, GetItemInfoFn(link or info.itemID))
    if bindType ~= BIND_ON_EQUIP then return end
    local msg = "Sold a BoE item: " .. (link or "?") .. "  Buy it back from the Buyback tab if that was a mistake."
    JQ.Print("|cffff4040" .. msg .. "|r")
    if RaidNotice_AddMessage and RaidWarningFrame then
        RaidNotice_AddMessage(RaidWarningFrame, "Sold BoE: " .. (link or "?"), ChatTypeInfo and ChatTypeInfo.RAID_WARNING or { r = 1, g = 0.3, b = 0.2 })
    end
    if PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then PlaySound(SOUNDKIT.RAID_WARNING) end
end

if C and C.UseContainerItem then
    hooksecurefunc(C, "UseContainerItem", Check)
end
