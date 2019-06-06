-- MoLib -- (c) 2009-2019 moorea@ymail.com (MooreaTv)
-- Covered by the GNU General Public License version 3 (GPLv3)
-- NO WARRANTY
-- (contact the author if you need a different license)

local addon, ns = ... -- our name, our empty default anonymous ns

local ML = _G[addon]

if not ML -- we may not be the first file loaded in the addon
  ML = {}
end

-- to force debug from empty state, uncomment: (otherwise "/wt debug on" to turn on later
-- and /reload to get it save/start over)
-- whoTrackerSaved.debug = 1

function ML.Print(...)
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
  else
    s = tostring(firstarg)
  end
  -- emit the part of the format string up to %, the processed first argument and recurse with the rest
  return fmtstr:sub(1, i - 1) .. s .. ML.format(fmtstr:sub(i + 1), ...)
end

function ML.Debug(...)
  if ML.debug and ML.debug == 1 then
    ML.Print(addon .. " DBG: " .. WT.format(...), 0, 1, 0)
  end
end


ML.first = 1
ML.manifestVersion = GetAddOnMetadata(addon, "Version")

function ML.MoLibInit()
  if not (ML.first == 1) then
    return
  end
  ML.first = 0
  -- saved vars handling
  local version = "(" .. addon .. " " .. WT.manifestVersion .. ")"
  WT.Print("MoLib embeded in " .. version)
end

-- Start of handy poor man's "/dump" --

WT.DumpT = {}
WT.DumpT["string"] = function(into, v)
  table.insert(into, "\"")
  table.insert(into, v)
  table.insert(into, "\"")
end
WT.DumpT["number"] = function(into, v)
  table.insert(into, tostring(v))
end
WT.DumpT["boolean"] = WT.DumpT["number"]

for _, t in next, {"function", "nil", "userdata"} do
  WT.DumpT[t] = function(into, v)
    table.insert(into, t)
  end
end

WT.DumpT["table"] = function(into, t)
  table.insert(into, "[")
  local sep = ""
  for k,v in pairs(t) do 
    table.insert(into, sep)
    sep = ", " -- inserts coma seperator after the first one
    WT.DumpInto(into, k) -- so we get the type/difference betwee [1] and ["1"]
    table.insert(into, " = ")
    WT.DumpInto(into, v)
  end
  table.insert(into, "]")
end

function WT.DumpInto(into, v)
  local type = type(v)
   if WT.DumpT[type] then
    WT.DumpT[type](into, v)
   else
    table.insert(into, "<Unknown Type " .. type .. ">")
   end
end

function WT.Dump(v)
   local into = {}
   WT.DumpInto(into, v)
   return table.concat(into, "")
end
-- End of handy poor man's "/dump" --
