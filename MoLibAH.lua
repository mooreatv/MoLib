--[[
  MoLib (Auction House part) -- (c) 2019 moorea@ymail.com (MooreaTv)
  Covered by the GNU Lesser General Public License v3.0 (LGPLv3)
  NO WARRANTY
  (contact the author if you need a different license)

  "doc" for GetAuctionItemInfo
  name, texture, count, quality, canUse, level, levelColHeader, minBid, minIncrement, buyoutPrice,
  bidAmount, highBidder, bidderFullName, owner, ownerFullName, saleStatus, itemId, hasAllInfo =  GetAuctionItemInfo("list", i)

]] --
-- our name, our empty default (and unused) anonymous ns
local addonName, _ns = ...

local ML = _G[addonName]

-- In bfa at least, only 2 types of AH items seen so far:
-- ["link"] = "|cff1eff00|Hitem:24767::::::::29:70:512:36:2:1679:3850:112:::|h[Clefthoof Hidemantle of the Quickblade]|h|r",
-- ["link"] = "|cff0070dd|Hbattlepet:1061:1:3:152:10:13:0000000000000000|h[Darkmoon Hatchling]|h|r",

-- Hitem:38933   :    :      :  :  :          :     :            :49:105::::::
--       itemid   ench  gemid g2 g3  suffixid   uid   linklevel : specid : upgradetypeid : instancedif
-- lets shorten those:
function ML:ItemLinkToId(link)
  if not link then
    self:DebugStack("Bad ItemLinkToId(nil) call")
    return
  end
  local idStr = link:match("^|[^|]+|H([^|]+)|")
  if not idStr then
    self:Error("Unexpected item link format %", link)
    return
  end
  local short = idStr
  short = string.gsub(short, "^(.)[^:]+:", "%1")
  -- get rid of :uid:linklevel:specid:upgradetype section
  short = string.gsub(short, "^(i[-%d]+:[-%d]*:[-%d]*:[-%d]*:[-%d]*:[-%d]*):[-%d]*:[-%d]*:[-%d]*:[-%d]*(.*)$", "%1%2")
  -- remove trailing ::::: and 00000 (battlepet)
  short = string.gsub(short, ":[:0]*$", "")
  self:Debug(5, "ItemLinkToId % -> %", idStr, short)
  return short
end

function ML:AddToItemDB(link)
  local key = self:ItemLinkToId(link)
  local idb = self.savedVar[self.itemDBKey]
  local existing = idb[key]
  if existing then
    -- test can be removed if it continues to never trigger (or left only for debug/dev mode)
    if link ~= existing then
      self:Error("key % for link % value mismatch with previous %", key, link, existing)
      idb[key] = link
    end
    return key -- already in there
  end
  idb._count_ = idb._count_ + 1 -- lua doesn't expose the number of entries (!)
  idb[key] = link
  return key
end

function ML:AHContext()
  self:InitRealms()
  local context = {}
  context.classic = self.isClassic
  context.region = self:GetMyRegion()
  context.realm = GetRealmName()
  context.faction = UnitFactionGroup("target") or "Neutral" -- Not needed in BfA
  self:PrintInfo("Scan context info: " .. context.faction .. " auction house on " .. context.region .. " / " ..
                   context.realm)
  return context
end

ML.ahResult = {}

function ML:AHSaveAll()
  local _, dumpOk = CanSendAuctionQuery()
  if not dumpOk then
    self:Warning("Can't query ALL at AH, try again later...")
    return
  end
  self.itemDBKey = "itemDB_" .. _G.WOW_PROJECT_ID -- split classic and bfa, even though they should never end up in same saved vars
  if not self.savedVar[self.itemDBKey] then
    -- create/init itemDB for each wow type (currently BfA vs Classic)
    self.savedVar[self.itemDBKey] = {}
    self.savedVar[self.itemDBKey]._formatVersion_ = 1 -- shortKey = fullLink associative array
    self.savedVar[self.itemDBKey]._count_ = 0
    self.savedVar[self.itemDBKey]._created_ = GetServerTime()
    -- else: check version (todo)
  end
  SetAuctionsTabShowing(false) -- does this do anything
  self.ahStartTS = debugprofilestop()
  self.ahResult = wipe(self.ahResult)
  QueryAuctionItems("", nil, nil, 0, 0, 0, true)
  self.waitingForAH = true
  self.ahResumeAt = nil
  AuctionFrameBrowse:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
  -- AHdump called through the first event
  self:PrintInfo("Scan started... please wait...")
end

ML.EventHdlrs.AUCTION_ITEM_LIST_UPDATE = function(frame, _event, _name)
  local addonP = frame.addonPtr
  addonP:Debug(2, "AUCTION_ITEM_LIST_UPDATE Event received - in ah wait %", addonP.waitingForAH)
  if addonP.waitingForAH then
    addonP:Debug(1, "Event received, waiting for items for AH, at % got %", addonP.ahResumeAt, #addonP.ahResult)
    addonP:AHdump(true)
  end
end

function ML:AHrestoreNormal()
  self.waitingForAH = nil
  self.ahRetries = 0
  self.ahResumeAt = nil
  AuctionFrameBrowse:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
  SetAuctionsTabShowing(true)
end

-- (default) page size is NUM_AUCTION_ITEMS_PER_PAGE (50) which
-- we don't to prefetch as that's way too slow
ML.ahPrefetch = 1000
ML.ahMaxRetries = 10 -- how many retries without making progress (ie 1sec)
ML.ahRetryTimerInterval = 0.1

function ML:AHdump(fromEvent)
  if not self.waitingForAH then
    self.Warning("Not expecting AHdump() call...")
    return
  end
  if fromEvent then
    self.ahRetries = 0
    if self.ahTimer then
      self:Debug(4, "cancelling previous timer, from event")
      self.ahTimer:Cancel()
      self.ahTimer = nil
    end
  end
  self.ahPrefetch = self.ahPrefetch or _G.NUM_AUCTION_ITEMS_PER_PAGE
  local batch, count = GetNumAuctionItems("list")
  if batch ~= count then
    self:Error("Unexpected mismatch between batch % and count % for a dump all of AH", batch, count)
    self:AHrestoreNormal()
    return
  end
  if count == 0 then
    self:PrintDefault("Result not ready, will try :AHdump() again shortly")
    return
  end
  if not self.ahResumeAt then
    self:PrintDefault(self.name .. ": Getting % items from AH all dump. (initial list took % sec to get)", count,
                      self:round((debugprofilestop() - self.ahStartTS) / 1000, 0.01))
    self.ahResumeAt = 1
  end
  -- prefetch/request at least .ahPrefetch then reschedule
  local i = self.ahResumeAt
  while (i <= count) do
    local firstIncomplete = nil
    local numIncomplete = 0
    local j = i
    repeat
      if not self.ahResult[j] then
        local linkRes = GetAuctionItemLink("list", j)
        if not linkRes then
          numIncomplete = numIncomplete + 1
          if not firstIncomplete then
            firstIncomplete = j
          end
        else
          local key = self:AddToItemDB(linkRes)
          local _name, _texture, itemCount, _quality, _canUse, _level, _levelColHeader, minBid, _minIncrement,
                buyoutPrice, _bidAmount, _highBidder, _bidderFullName, owner, ownerFullName, _saleStatus, _itemId,
                _hasAllInfo = GetAuctionItemInfo("list", j)
          self.ahResult[j] = string.format("%s,%d,%.0f,%.0f,%s", key, itemCount, minBid, buyoutPrice,
                                           ownerFullName or owner or "")
        end
      end
      j = j + 1
    until (j > count) or (numIncomplete == self.ahPrefetch)
    if numIncomplete > 0 then
      local progressMade = (firstIncomplete > self.ahResumeAt)
      if progressMade then
        self:Debug("We made progress from % to %, so resetting retries", self.ahResumeAt, firstIncomplete)
        self.ahRetries = 0
      end
      self.ahRetries = self.ahRetries + 1
      local retriesMsg = ""
      if self.ahRetries > 1 then
        retriesMsg = string.format(" retry #%d", self.ahRetries)
      end
      if not fromEvent or progressMade then
        self:PrintDefault("Expected incomplete ah % results found at % / %" .. retriesMsg, numIncomplete,
                          firstIncomplete, count, self.ahRetries)
      end
      if self.ahRetries > self.ahMaxRetries then
        self:Error("Too many retries (%) without progress when trying to get to full AH of % with page size %",
                   self.ahRetries, count, self.ahScanPage)
        self:AHrestoreNormal()
        return
      end
      self.ahResumeAt = firstIncomplete
      if self.ahTimer then
        self:Debug(4, "cancelling previous timer, from retry loop")
        self.ahTimer:Cancel()
      end
      -- prefer event based... but seems like we need more
      self:Debug(5, "scheduling retry in %s", self.ahRetryTimerInterval)
      self.ahTimer = C_Timer.NewTimer(self.ahRetryTimerInterval, function()
        self.ahTimer = nil
        self:AHdump()
      end)
      return
    end
    self.ahResumeAt = j
    self:Debug(1, "Got good page up to %/%", self.ahResumeAt - 1, count)
    self.ahRetries = 0
    i = j
  end
  self.waitingForAH = nil
  self.ahResumeAt = nil
  if not self.savedVar.ah then
    self.savedVar.ah = {}
  end
  local toon = self:GetMyFQN()
  local entry = self:AHContext()
  entry.ts = GetServerTime()
  entry.dataFormatVersion = 1
  entry.dataFormatInfo = "key,itemCount,minBid,buyoutPrice,seller ..."
  entry.data = table.concat(self.ahResult, " ") -- \n gets escaped into '\' + 'n' so might as well use 1 byte instead
  self:PrintInfo("MoLib AH Scan data packed to % Mbytes", self:round(#entry.data / 1024 / 1024, .01))
  self.ahResult = wipe(self.ahResult)
  entry.char = toon
  entry.count = count
  self.ahEndTS = debugprofilestop()
  local elapsed = (self.ahEndTS - self.ahStartTS) / 1000 -- in seconds not ms
  entry.elapsed = elapsed
  table.insert(self.savedVar.ah, entry)
  local speed = self:round(count / elapsed, 0.1)
  elapsed = self:round(elapsed, 0.01)
  self:PrintInfo(self.name ..
                   ": Auction scan complete and captured for % listings in % s (% auctions/sec). Item DB has % entries. " ..
                   "Consider /reload to save asap.", count, elapsed, speed, self.savedVar[self.itemDBKey]._count_)
  self:AHrestoreNormal()
  return entry
end
