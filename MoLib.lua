--[[
  MoLib -- (c) 2009-2019 moorea@ymail.com (MooreaTv)
  Covered by the GNU General Public License version 3 (GPLv3)
  NO WARRANTY
  (contact the author if you need a different license)
]] --
--
-- name of the addon embedding us, our empty default anonymous ns (not used)
local addon, ns = ...

-- install into addon's namespace by default
if not _G[addon] then
  -- we may not be the first file loaded in the addon, create its global NS if we are
  _G[addon] = {}
  -- Note that if we do that CreateFrame won't work later, so we shouldn't be loaded first for WhoTracker for instance
end

local ML = _G[addon]

ML.name = addon

function ML.deepmerge(dstTable, dstKey, src)
  if type(src) ~= 'table' then
    if not dstKey then
      error("setting leave object on nil key")
    end
    dstTable[dstKey] = src
    return
  end
  if dstKey then
    if not dstTable[dstKey] then
      dstTable[dstKey] = {}
    end
    dstTable = dstTable[dstKey]
  end
  for k, v in pairs(src) do
    ML.deepmerge(dstTable, k, v)
  end
end

function ML.MoLibInstallInto(namespace, name)
  ML.deepmerge(namespace, nil, ML)
  namespace.name = name
  ML:Print("MoLib aliased into " .. name)
end

-- to force debug from empty state, uncomment: (otherwise "/<addon> debug on" to turn on later
-- and /reload to get it save/start over)
-- ML.debug = 1

function ML:Print(...)
  DEFAULT_CHAT_FRAME:AddMessage(...)
end

-- like format except simpler... just use % to replace a value that will be tostring()'ed
-- string arguments are quoted (ie "Zone") so you can distinguish nil from "nil" etc
-- and works for all types (like boolean), unlike format
function ML.format(fmtstr, firstarg, ...)
  local i = fmtstr:find("%%")
  if not i then
    return fmtstr -- no % in the format string anymore, we're done with literal value returned
  end
  local t = type(firstarg)
  local s
  if t == "string" then -- if the argument is a string, quote it, else tostring it
    s = format("%q", firstarg)
  elseif t == "table" then
    local t = {}
    ML.DumpT["table"](t, firstarg)
    s = table.concat(t, "")
  else
    s = tostring(firstarg)
  end
  -- emit the part of the format string up to %, the processed first argument and recurse with the rest
  return fmtstr:sub(1, i - 1) .. s .. ML.format(fmtstr:sub(i + 1), ...)
end

-- Use: YourAddon:Debug("foo is %, bar is %!", foo, bar)
-- must be called with : (as method, to access state)
-- first argument is optional debug level for more verbose level set to 9
function ML:Debug(level, ...)
  if not self.debug then
    return
  end
  if type(level) == "number" then
    if level > self.debug then
      return
    end
    ML:debugPrint(level, ...)
  else
    -- level was omitted
    ML:debugPrint(1, level, ...)
  end
end

function ML:debugPrint(level, ...)
  ML:Print(string.format("%02d", GetServerTime() % 60) .. " " .. self.name .. " DBG[" .. tostring(level) .. "]: " ..
             ML.format(...), .1, .75, .1)
end

function ML:Error(...)
  ML:Print(self.name .. " Error: " .. ML.format(...), 0.9, .1, .1)
end

function ML:Warning(...)
  ML:Print(self.name .. " Warning: " .. ML.format(...), 0.96, 0.63, 0.26)
end

ML.first = 1
ML.manifestVersion = GetAddOnMetadata(addon, "Version")

-- Returns 1 if already done; must be called with : (as method, to access state)
function ML:MoLibInit()
  if not (self.first == 1) then
    return true
  end
  self.first = 0
  local version = "(" .. addon .. " / " .. self.name .. " " .. ML.manifestVersion .. ")"
  ML:Print("MoLib embeded in " .. version)
  return false -- so caller can continue with 1 time init
end

-- Start of handy poor man's "/dump" --

ML.DumpT = {}
ML.DumpT["string"] = function(into, v)
  table.insert(into, "\"")
  table.insert(into, v)
  table.insert(into, "\"")
end
ML.DumpT["number"] = function(into, v)
  table.insert(into, tostring(v))
end
ML.DumpT["boolean"] = ML.DumpT["number"]

for _, t in next, {"function", "nil", "userdata"} do
  ML.DumpT[t] = function(into, _)
    table.insert(into, t)
  end
end

ML.DumpT["table"] = function(into, t)
  table.insert(into, "[")
  local sep = ""
  for k, v in pairs(t) do
    table.insert(into, sep)
    sep = ", " -- inserts coma seperator after the first one
    ML.DumpInto(into, k) -- so we get the type/difference betwee [1] and ["1"]
    table.insert(into, " = ")
    ML.DumpInto(into, v)
  end
  table.insert(into, "]")
end

function ML.DumpInto(into, v)
  local type = type(v)
  if ML.DumpT[type] then
    ML.DumpT[type](into, v)
  else
    table.insert(into, "<Unknown Type " .. type .. ">")
  end
end

function ML.Dump(...)
  local into = {}
  for i = 1, select("#", ...) do
    if i > 1 then
      table.insert(into, " , ")
    end
    ML.DumpInto(into, select(i, ...))
  end
  return table.concat(into, "")
end
-- End of handy poor man's "/dump" --

function ML:DebugEvCall(level, ...)
  self:Debug(level, "On ev " .. ML.Dump(...))
end

-- Retuns the normalized fully qualified name of the player
function ML:GetMyFQN()
  local p, realm = UnitFullName("player")
  self:Debug(1, "GetMyFQN % , %", p, realm)
  if not realm then
    self:Error("GetMyFQN: Realm not yet available!")
    return p
  end
  return p .. "-" .. realm
end

ML.AlphaNum = {}

-- generate the 62 alpha nums (A-Za-z0-9 but in 1 pass so not in order)
for i = 1, 26 do
  table.insert(ML.AlphaNum, format("%c", 64 + i)) -- 'A'-1
  table.insert(ML.AlphaNum, format("%c", 64 + 32 + i)) -- 'a'-1
  if i <= 10 then
    table.insert(ML.AlphaNum, format("%c", 47 + i)) -- '0'-1
  end
end

function ML.RandomId(len)
  ML:Debug(9, "AlphaNum table has % elem: %", #ML.AlphaNum, ML.AlphaNum)
  local res = {}
  for i = 1, len do
    table.insert(res, ML.AlphaNum[math.random(1, #ML.AlphaNum)])
  end
  local strRes = table.concat(res)
  ML:Debug(8, "Generated % long id from alphabet of % characters: %", len, #ML.AlphaNum, strRes)
  return strRes
end

-- ML.debug = 9
-- local rnum = math.random()
-- local randomId = format("%.25f", rnum):sub(3)
-- ML:Debug("random id %", randomId)
-- ML:Debug("RandomId 6 is %", ML.RandomId(6))
