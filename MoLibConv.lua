--[[
  MoLib (Conversions, encoding part) -- (c) 2020 moorea@ymail.com (MooreaTv)
  Covered by the GNU Lesser General Public License v3.0 (LGPLv3)
  NO WARRANTY
  (contact the author if you need a different license)

  If you use this please give credit and add a link to
  https://github.com/mooreatv/MoLib in your documents/addon page on curse

]] --
-- our name, our empty default (and unused) anonymous ns
local addonName, _ns = ...

local ML = _G[addonName]

-- Convert a byte array to base N where N >= 2 and <= 256

-- base2-10, base16, base36, base62, base91/92 [printable ascii], base123 [wow's ok chat messages]
-- etc all the way to base127, and base255 (all but nul)
function ML:CreateDictionary()
    local res = {}
    -- digits 0-9
    for i = 0, 9 do
        table.insert(res, tostring(i))
    end
    -- letters A-Z then a-z
    for i = 1, 26 do
        table.insert(res, strchar(64+i))
    end
    for i = 1, 26 do
        table.insert(res, strchar(96+i))
    end
    -- everything else legal in wow chat messages:
    -- https://www.ascii-code.com/
    -- https://wow.gamepedia.com/Valid_chat_message_characters
    -- printable chars but space, first
    for i = 33, 47 do
        local c = strchar(i)
        if c ~= "%" then
            table.insert(res, c)
        end
    end
    -- between digits and letters
    for i = 58, 64 do
        table.insert(res, strchar(i))
    end
    -- between uppercase and lowercase
    for i = 91, 96 do
        table.insert(res, strchar(i))
    end
    for i = 123, 126 do
        local c = strchar(i)
        if c ~= "|" then
            table.insert(res, c)
        end
    end
    table.insert(res, strchar(32)) -- space, last printable for base 91 or base 92 (with space)
    table.insert(res, strchar(127))
    for i = 1, 9 do
        table.insert(res, strchar(i))
    end
    table.insert(res, strchar(11))
    table.insert(res, strchar(12))
    for i = 14, 31 do
        table.insert(res, strchar(i))
    end
    -- after 123 it's non ok characters for wow
    table.insert(res, "%")
    table.insert(res, "|")
    table.insert(res, strchar(10))
    table.insert(res, strchar(13)) -- end of base127
    for i = 128, 255 do
        table.insert(res, strchar(i))
    end
    -- create the inverse dictionary:
    local ires = {}
    for i = 1, #res do
        ires[res[i]] = i-1
    end
    return res, ires
end

ML.base255, ML.base255inversed = ML:CreateDictionary()

-- integer division and reminder
function ML:IntDivide(num, div)
    local d = math.floor(num/div)
    local r = num - d*div
    return d, r
end

-- turn small lua number into string in given base
function ML:ToDigits(v, base, dict)
    dict = dict or self.base255
    local l = {}
    local r
    repeat
        v , r = self:IntDivide(v, base)
        table.insert(l, dict[r+1])
    until v == 0
    return string.reverse(table.concat(l, ""))
end


-- Multi byte math for base X to base Y conversion:
-- Thanks to
-- https://jonnydee.wordpress.com/2011/05/01/convert-a-block-of-digits-from-base-x-to-base-y/


function ML:incNumberByValue(digits, base, value)
   -- The initial overflow is the 'value' to add to the number.
   local overflow = value
   -- Traverse list of digits in reverse order.
   for i = #digits, 1, -1 do
        -- If there is no overflow we can stop overflow propagation to next higher digit(s).
        if not overflow then
             return
        end
        local sum = digits[i] + overflow
        overflow , digits[i] = self:IntDivide(sum, base)
    end
end

function ML:multNumberByValue(digits, base, value)
   local overflow = 0
   -- Traverse list of digits in reverse order.
   for i = #digits, 1, -1 do
        local tmp = (digits[i] * value) + overflow
        overflow, digits[i] = self:IntDivide(tmp, base)
   end
end

function ML:convertNumber(srcDigits, srcBase, destDigits, destBase)
    for _,srcDigit in ipairs(srcDigits) do
        self:multNumberByValue(destDigits, destBase, srcBase)
        self:incNumberByValue(destDigits, destBase, srcDigit)
    end
end

function ML:withoutLeadingZeros(digits)
    local res = {}
    local add = false
    for _, d in ipairs(digits) do
      if  d ~= 0 then
        add = true
      end
      if add then
        table.insert(res, d)
      end
    end
   return res
end

function ML:convertNumberExt(srcDigits, srcBase, destBase)
   -- Generate a list of zero's which is long enough to hold the destination number.
   local destDigitsLen = #srcDigits*math.log(srcBase)/math.log(destBase)
   if srcBase > destBase then
    destDigitsLen = math.ceil(destDigitsLen)
   else
    destDigitsLen = math.floor(destDigitsLen)
   end
   local destDigits = {}
   for i = 1, destDigitsLen do
    destDigits[i] = 0
   end
   -- Do conversion.
   self:convertNumber(srcDigits, srcBase, destDigits, destBase)
   -- Return result (without leading zeros).
   return destDigits
end

--- end of python to lua translation of the above awesomeness

function ML:Encode(bytes, base, dict)
    dict = dict or self.base255
    base = base or 123 -- for wow
    local bytesDigits = {}
    for i = 1, string.len(bytes) do
        bytesDigits[i] = strbyte(bytes, i)
    end
    local resN = self:convertNumberExt(bytesDigits, 256, base)
    local resC = {}
    for i, d in ipairs(resN) do
        resC[i] = dict[1+d]
    end
    return table.concat(resC, "")
end

function ML:Decode(bytes, base, invDict)
    invDict = invDict or self.base255inversed
    base = base or 123 -- for wow
    local bytesDigits = {}
    for i = 1, string.len(bytes) do
        local c = string.sub(bytes, i, i)
        bytesDigits[i] = invDict[c]
    end
    local resN = self:convertNumberExt(bytesDigits, base, 256)
    local resC = {}
    for i, d in ipairs(resN) do
        resC[i] = strchar(d)
    end
    return table.concat(resC, "")
end


---- TODO:

-- correctness tests: random data in, check encode/decode invariants (for various (or all? bases 2-255))

-- benchmark tests: at 91, 123, 255

--[[
Note my goal is correctness and compactness of the output, not necessarily encoding performance but if performance
can be improved easily, sure (without destroying readability for instance) - thus the importance of measuring and
testing before optimizing


*** Suggestions from Meorawr on discord:
    I'd remove all the table.insert function calls in favour of keeping track of table length in variables, if performance is a goal
    Same with use of ipairs to instead use for i = 1, #t style loops
    Inline incNumber and multNumber calls to convertNumber, and convertNumber into convertNumberExt

TODO ^

    The dictionary is constant; make it once and just embed it in the code as a table

my note: doubt that last bit (the dictionary inline, not the rest) makes any difference

    I'd be tempted to suggest you move the bytesDigits tables out of the encode/decode methods and into the outer scope, and
    reuse them across calls
    Otherwise you're gonna be murdering the garbage collector if used frequently
    (Especially since you'll also trigger a bunch of individual table resizes in making those tables to begin with)
    string.len => just use #)

MooreaTv
a pool of buffers?
well as long as I don't call any wow api I guess it's single threaded

    Meorawr:
    No, just literally move them out of there and reuse the tables as-is. I don't think supporting reentrancy into those function
    is worthwhile. It's always single threaded

MooreaTv
yeah but it can be reentrant

]]
