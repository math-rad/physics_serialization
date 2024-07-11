local floor, log = math.floor, math.log

local symbol = {}

do
    for _, range in {{97, 122}, {65, 90}, {48, 57}} do
	    for char = range[1], range[2], 1 do
		    table.insert(symbol, string.char(char))
	    end
    end
    print(("Max radix: %s"):format(#symbol))
end

function getBase(base)
    return function(n)
        local digits = tostring(n):split('')
        local buffer = 0
        local newDigits = ""

        repeat 
            local r = n % base 
            n %= floor(n / base)
        until n == 0
        return base <= 10 and tonumber(newDigits) or newDigits
    end

    
end