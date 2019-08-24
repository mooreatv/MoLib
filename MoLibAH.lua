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
  if type(link) ~= "string" then
    self:DebugStack("Bad ItemLinkToId(%) call", link)
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
  -- run length encode :s  1":" is :, 2 is ; (:+1 in ascii), 3 is < etc
  short = string.gsub(short, "::+", function(match)
    return string.format("%c", 57 + #match)
  end)
  self:Debug(5, "ItemLinkToId % -> %", idStr, short)
  return short
end

function ML:AddToItemDB(link, batch)
  local key = self:ItemLinkToId(link)
  local idb = self.savedVar[self.itemDBKey]
  local existing = idb[key]
  if existing then
    -- test can fail when switching toon of different level/spec... so only for dev/debug mode
    if (batch or self.debug) and link ~= existing then
      self:Error("key % for link % value mismatch with previous % (could be just the specid or a real issue)", key,
                 link, existing)
      idb[key] = link
    end
    return key -- already in there
  end
  idb._count_ = idb._count_ + 1 -- lua doesn't expose the number of entries (!)
  idb[key] = link
  self:Debug("New item #% key %: %", idb._count_, key, link)
  if not batch and self.showNewItems then
    local newIdx = idb._count_ - self.itemDBStartingCount
    if newIdx <= self.showNewItems then
      local extra = ""
      if newIdx == self.showNewItems then
        extra = self.L[" (maximum reached, won't show more for this scan)"]
      end
      self:PrintDefault(self.name .. self.L[" Never seen before item #% (%): "] .. link .. extra, newIdx, idb._count_)
    end
  end
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

function ML:AHfullScanPossible()
  local normalQueryOk, dumpOk = CanSendAuctionQuery()
  return dumpOk and normalQueryOk
end

function ML:InitItemDB(clearAHtoo)
  self.savedVar[self.itemDBKey] = {}
  local itemDB = self.savedVar[self.itemDBKey]
  itemDB._formatVersion_ = 2 -- shorterKey = fullLink associative array
  itemDB._count_ = 0
  itemDB._created_ = GetServerTime()
  -- also clear the ah array itself
  if clearAHtoo and self.savedVar.ah then
    self.savedVar.ah = wipe(self.savedVar.ah)
  end
  return itemDB
end

function ML:CheckAndConvertItemDB()
  local itemDB = self.savedVar[self.itemDBKey]
  if not itemDB._formatVersion_ then
    self:Error("Erasing unknown/past Item DB format %", itemDB._formatVersion_)
    return self:InitItemDB(true)
  end
  if itemDB._formatVersion_ == 2 then
    -- good current version
    return itemDB
  end
  -- version 1: convert to v2
  self:Warning("Converting item db v% to current - % items", itemDB._formatVersion_, itemDB._count_)
  local newDB = self:InitItemDB()
  local oldKeySizes = 0
  local newKeySizes = 0
  local valueSizes = 0
  for k, v in pairs(itemDB) do
    if k:sub(1, 1) ~= "_" then
      oldKeySizes = oldKeySizes + #k
      valueSizes = valueSizes + #v
      local newKey = self:AddToItemDB(v, true)
      newKeySizes = newKeySizes + #newKey
    end
  end
  local percent = self:round(100 * (oldKeySizes / newKeySizes - 1), .1)
  self:Warning("Done converting now v% itemDB - % items\n" ..
                 "Size reduction % original to old key sizes %, to now % (%\\37 improvement)", newDB._formatVersion_,
               newDB._count_, valueSizes, oldKeySizes, newKeySizes, percent)
  return newDB
end

-- Main entry point for this file/feature: does a full AH query and scan/parse the results into
-- the addon saved variable.
-- Debug/test mode:
function ML:AHSaveAll(dontActuallyQuery)
  if not self:AHfullScanPossible() then
    self:Warning("Can't query ALL at AH, try again later...")
    return
  end
  if self.waitingForAH then
    self:Warning("Already doing a scan (%), try a new one later...", self.ahResumeAt)
    self:AHdump() -- in case previous one got error/got stuck
    return
  end
  if not _G.AuctionFrame or not _G.AuctionFrame:IsVisible() then
    self:Warning("Not at the AH, can't scan...")
    return
  end
  self.itemDBKey = "itemDB_" .. _G.WOW_PROJECT_ID -- split classic and bfa, even though they should never end up in same saved vars
  local itemDB = self.savedVar[self.itemDBKey]
  if not itemDB then
    -- create/init itemDB for each wow type (currently BfA vs Classic)
    itemDB = self:InitItemDB()
  else
    itemDB = self:CheckAndConvertItemDB()
  end
  self:Debug("Starting itemDB has % items (was %)", itemDB._count_, self.itemDBStartingCount)
  self.itemDBStartingCount = itemDB._count_
  SetAuctionsTabShowing(false) -- does this do anything
  self.ahStartTS = debugprofilestop()
  self.ahResult = wipe(self.ahResult)
  if dontActuallyQuery then
    self:Warning("Running with existing last AH results instead of a real scan")
    self.ahIsStale = true
    -- we won't get the first event so schedule the dump for just after this, simulating the event:
    C_Timer.After(0, function()
      self:AHdump(true)
    end)
  else
    self.ahIsStale = false
    QueryAuctionItems("", nil, nil, 0, 0, 0, true)
  end
  self.waitingForAH = true
  self.ahResumeAt = nil
  AuctionFrameBrowse:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
  -- AHdump called through the first event
  self:PrintInfo("Scan started... please wait...")
end

ML.EventHdlrs.AUCTION_ITEM_LIST_UPDATE = function(frame, _event, _name)
  local addonP = frame.addonPtr
  addonP:Debug(3, "AUCTION_ITEM_LIST_UPDATE Event received - in ah wait %", addonP.waitingForAH)
  if addonP.waitingForAH then
    addonP:Debug(2, "Event received, waiting for items for AH, at % got % - already in is %", addonP.ahResumeAt,
                 #addonP.ahResult, addonP.AHinDump)
    if not addonP.AHinDump then
      addonP:AHdump(true)
    else
      addonP:Debug(1, "Skipping item list even because we already are inside AHdump... %", addonP.ahResumeAt)
    end
  end
end

function ML:AHrestoreNormal()
  self.waitingForAH = nil
  self.ahRetries = 0
  self.ahResumeAt = nil
  if self.ahTimer then
    self:Debug(2, "cancelling previous timer, from restore normal")
    self.ahTimer:Cancel()
    self.ahTimer = nil
  end
  AuctionFrameBrowse:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
  SetAuctionsTabShowing(true)
end

-- (default) page size is NUM_AUCTION_ITEMS_PER_PAGE (50) which
-- we don't to prefetch as that's way too slow
ML.ahPrefetch = 1000
ML.ahMaxRetries = 10 -- how many retries without making progress (ie 1sec)
ML.ahBaseTimerInterval = 0.1
ML.ahMaxRestarts = 10 -- how many times to restart the scan when stepping on an expired auction

function ML:AHscheduleNextDump(msg)
  if self.ahTimer then
    self:Debug(4, "cancelling previous timer, from " .. msg)
    self.ahTimer:Cancel()
  end
  self:Debug(5, "scheduling retry in %s", self.ahRetryTimerInterval)
  self.ahTimer = C_Timer.NewTimer(self.ahCurrentTimerInterval, function()
    self.ahTimer = nil
    self:AHdump()
  end)
end

function ML:AHdump(fromEvent)
  if not self.waitingForAH then
    self.Warning("Not expecting AHdump() call...")
    return
  end
  if self.AHinDump then
    self:Warning("AHdump unexpected reentrance chkpoint %", self.ahResumeAt)
    self.ahCurrentTimerInterval = math.min(2 * self.ahCurrentTimerInterval + 0.1, 1) -- slow down but only up to 1 sec
    ML:AHscheduleNextDump("reentered too soon")
    return
  end
  self.AHinDump = true -- where is 'finally' when you need it - must check every return path below
  self.ahCurrentTimerInterval = self.ahBaseTimerInterval -- (back to) initial speed
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
    self.AHinDump = false
    return
  end
  if count == 0 then
    self:PrintDefault("Result not ready, will try :AHdump() again shortly")
    self.AHinDump = false
    return
  end
  if not self.ahResumeAt then
    self:PrintDefault(self.name .. ": Getting % items from AH all dump. (initial list took % sec to get)", count,
                      self:round((debugprofilestop() - self.ahStartTS) / 1000, 0.01))
    self.ahResumeAt = 1
    self.expectedCount = count
    self.currentCount = nil
  else
    if count ~= self.expectedCount and count ~= self.currentCount then
      self.ahRestarts = (self.ahRestarts or 0) + 1
      self:Warning(
        "Auction list count changed unexpectedly from % to % (likely bad scan, please report) - starting over (restart #%)!",
        self.currentCount or self.expectedCount, count, self.ahRestarts)
      self.currentCount = count
      -- start over
      if self.ahRestarts > self.ahMaxRestarts then
        self:Error("Too many (%) restarts of scan for % -> % auctions, aborting, please report!", self.ahRestarts,
                   self.expectedCount, self.currentCount)
        self:AHrestoreNormal()
        self.AHinDump = false
        return
      end
      self.ahResult = wipe(self.ahResult)
      self.ahResumeAt = 1
      self.ahIsStale = true
      C_Timer.After(0.5, function()
        self:AHdump(true) -- we'll probably get an event
      end)
      self.AHinDump = false
      return
    end
  end
  local itemDB = self.savedVar[self.itemDBKey]
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
          local timeLeft = GetAuctionItemTimeLeft("list", j)
          self.ahResult[j] = string.format("%s,%d,%.0f,%.0f,%s,%d", key, itemCount, minBid, buyoutPrice,
                                           ownerFullName or owner or "", (timeLeft or 0))
        end
      end
      j = j + 1
    until (j > count) or (numIncomplete == self.ahPrefetch)
    if numIncomplete > 0 then
      self:Debug(3, "ni % fi % ahR %", numIncomplete, firstIncomplete, self.ahResumeAt)
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
        self:Error(
          "Too many retries (%) without progress when trying to get to full AH of % with page size %, stuck on item %",
          self.ahRetries, count, self.ahPrefetch, firstIncomplete)
        self:AHrestoreNormal()
        self.AHinDump = false
        return
      end
      self.ahResumeAt = firstIncomplete
      -- we would prefer entirely event based... but it seems like we need more than just events but also keep retrying
      self:AHscheduleNextDump("retry loop")
      self.AHinDump = false
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
  entry.dataFormatVersion = 2
  entry.dataFormatInfo = "v2key,itemCount,minBid,buyoutPrice,seller,timeLeft ..."
  entry.data = table.concat(self.ahResult, " ") -- \n gets escaped into '\' + 'n' so might as well use 1 byte instead
  self:PrintInfo("MoLib AH Scan data packed to % Mbytes", self:round(#entry.data / 1024 / 1024, .01))
  self.ahResult = wipe(self.ahResult)
  entry.char = toon
  entry.count = count
  entry.firstCount = self.expectedCount -- the two should be equal for good scans, probably shud just discard... keeping to study it
  entry.testScan = self.ahIsStale -- did we really do a query first
  self.ahEndTS = debugprofilestop()
  local elapsed = (self.ahEndTS - self.ahStartTS) / 1000 -- in seconds not ms
  entry.elapsed = elapsed
  table.insert(self.savedVar.ah, entry)
  local speed = self:round(count / elapsed, 0.1)
  elapsed = self:round(elapsed, 0.01)
  local newItems = itemDB._count_ - self.itemDBStartingCount
  entry.newItems = newItems
  entry.itemDBcount = itemDB._count_
  self:PrintInfo(self.name .. ": Auction scan complete and captured for % listings in % s (% auctions/sec).\n" ..
                   "% new items in DB, now % entries. ", count, elapsed, speed, newItems, itemDB._count_)
  self:AHrestoreNormal()
  self:AHendOfScanCB()
  self.AHinDump = false
  return entry
end

function ML:AHendOfScanCB()
  self:Debug("Default non overridden AHendOfScanCB()")
end
