--[[
  MoLib -- (c) 2009-2019 moorea@ymail.com (MooreaTv)
  Covered by the GNU General Public License version 3 (GPLv3)
  NO WARRANTY
  (contact the author if you need a different license)
]] --
--
local libName = "MoLibConvTests"

_G[libName] = {}
local MLT = _G[libName]

local ns = {}

-- Simulating a few wow functions we use

_G.gsub = string.gsub
_G.strchar = string.char
_G.strbyte = string.byte

local f = assert(loadfile("../MoLibConv.lua"))
f(libName, ns)

--local rnum = math.random()
--local randomId = string.format("%.25f", rnum):sub(3)
--print("random id " ..randomId)
function _G.test1Conf(bytesStr, len, base)
  local b = string.sub(bytesStr, len)
  local e = MLT:Encode(b, base)
  local d = MLT:Decode(e, base)
  print(#b, base, #e, #d)
  if d ~= b then
    local out2 = assert(io.open("encoded", "wb"))
    out2:write(e)
    out2:close()
    local out3 = assert(io.open("decoded", "wb"))
    out3:write(d)
    out3:close()
    print("mismatch for ", len, base, #d, " check encoded/decoded files")
    assert(d==b)
  end
end

function _G.ConvCorrectnessTests()
  local bytes = {}
  for i = 1, 512 do
    bytes[i] =  strchar(math.random(0,255))
  end
  local bytesStr = table.concat(bytes, "")
  --print(#bytesStr)
  local out1 = assert(io.open("orig", "wb"))
  out1:write(bytesStr)
  out1:close()
  -- rounding error shows up with this value
  _G.test1Conf(bytesStr, 512-500, 2)
  for i = 1, #bytesStr do
    for base = 2, 255 do
      _G.test1Conf(bytesStr, i, base)
    end
  end
end

_G.ConvCorrectnessTests()
