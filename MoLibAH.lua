--[[
  MoLib (Auction House part) -- (c) 2019 moorea@ymail.com (MooreaTv)
  Covered by the GNU General Public License version 3 (GPLv3)
  NO WARRANTY
  (contact the author if you need a different license)
]] --
-- our name, our empty default (and unused) anonymous ns
local addonName, _ns = ...

local ML = _G[addonName]

function ML:AHSaveAll()
  local _, dumpOk = CanSendAuctionQuery()
  if not dumpOk then
    self:Warning("Can't query ALL at AH, try again later...")
    return
  end
  -- SetAuctionsTabShowing(false)
  QueryAuctionItems("", nil, nil, 0, 0, 0, true)
  self:AHdump()
end

function ML:AHdump()
  local batch, count = GetNumAuctionItems("list")
  if batch ~= count then
    self:Error("Unexpected mismatch between batch % and count % for a dump all of AH", batch, count)
    -- SetAuctionsTabShowing(true)
    return
  end
  if count == 0 then
    -- TODO wait for AUCTION_ITEM_LIST_UPDATE
    self:PrintDefault("Result not ready, try :AHdump() again shortly")
    return
  end
  self:PrintInfo("Got % items from AH all dump.", count)
  local res = {}
  for i = 1, count do
    table.insert(res, {info = {GetAuctionItemInfo("list", i)}, link = GetAuctionItemLink("list", i)})
  end
  -- SetAuctionsTabShowing(true)
  if not self.savedVar.ah then
    self.savedVar.ah = {}
  end
  local p, r = UnitFullName("player")
  table.insert(self.savedVar.ah, {realm = r, ts = GetServerTime(), data = res, char = p})
  return res
end
