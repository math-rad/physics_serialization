

local floor, ceil, sqrt, clamp = math.floor, math.ceil, math.sqrt, math.clamp
local bBuffer = {}

local symbol = ("012345679abcdefgijlkmnopqrstuvwxyz"):split('')

local function getBase(base)
    return function(n)
        local digits = ""
        local buffer = 0
        local token = tostring(n)
        local index = #token
        
        local splitToken = token:split('')
        repeat
            local digit = tonumber(splitToken[index] or 0) + buffer
            digits =  (digit % base) .. digits 
            buffer = floor(digit / base)

            index -= 1
        until buffer == 0

        return digits
    end
end

local base = getBase(2)
print(base(0))