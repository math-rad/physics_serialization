local floor = math.floor

local symbol = {}
do
    for _, range in pairs({{48, 57}, {97, 122}, {65, 90}}) do
            for char = range[1], range[2], 1 do
                    table.insert(symbol, string.char(char))
            end
    end
    print(("Max radix: %s"):format(#symbol))
end

function getBase(base)
    return function(n)
        local buffer = 0
        local digits = ""
        repeat
          r = n % base
          n = floor(n / base)
          digits = symbol[r + 1] .. digits
        until n == 0
        return base <= 10 and tonumber(digits) or digits
    end
end