--[[
  MoLib (Auction House part) -- (c) 2019 moorea@ymail.com (MooreaTv)
  Covered by the GNU Lesser General Public License v3.0 (LGPLv3)
  NO WARRANTY
  (contact the author if you need a different license)
]] --
-- our name, our empty default (and unused) anonymous ns
local addonName, _ns = ...

local ML = _G[addonName]

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
  -- SetAuctionsTabShowing(false)
  self.ahStartTS = debugprofilestop()
  wipe(self.ahResult)
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
  AuctionFrameBrowse:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
end

-- (default) page size is NUM_AUCTION_ITEMS_PER_PAGE (50) which
-- we don't to prefetch as that's way too slow
ML.ahPrefetch = 1000
ML.ahMaxRetries = 10 -- how many retries without making progress (ie 1sec)
ML.ahRetryTimerInterval = 0.1

function ML:AHdump(fromEvent)
  if not self.waitingForAH then
    self.Debug("Not expecting AHdump() call")
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
    -- SetAuctionsTabShowing(true)
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
          self.ahResult[j] = {info = {GetAuctionItemInfo("list", j)}, link = linkRes}
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
  -- SetAuctionsTabShowing(true)
  if not self.savedVar.ah then
    self.savedVar.ah = {}
  end
  local toon = self:GetMyFQN()
  local entry = self:AHContext()
  entry.ts = GetServerTime()
  entry.data = self.ahResult
  entry.char = toon
  entry.count = count
  self.ahEndTS = debugprofilestop()
  local elapsed = (self.ahEndTS - self.ahStartTS) / 1000 -- in seconds not ms
  entry.elapsed = elapsed
  table.insert(self.savedVar.ah, entry)
  local speed = self:round(count / elapsed, 0.1)
  elapsed = self:round(elapsed, 0.01)
  self:PrintInfo(self.name ..
                   ": Auction scan complete and captured for % listings in % s (% auctions/sec). Consider /reload to save it asap.",
                 count, elapsed, speed)
  self:AHrestoreNormal()
  return entry
end
