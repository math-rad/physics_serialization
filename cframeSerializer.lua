local floor, clamp, byte, char, insert, concat, yield, running = math.floor, math.clamp, string.byte, string.char, table.insert, table.concat, coroutine.yield, coroutine.running 

local module = {}

local symbol = {}

local printRadix = true

do 
    local characterRangePairs = {{'0', '1'}, {'a', 'z'}, {'A', 'Z'}}
    local function getCharacterSet(characterA, characterB)
        characterA, characterB = tostring(characterA), tostring(characterB)

        local startChar, endChar = char(characterA), char(characterB)
        local index = startChar 
        local increment = true 
        local terminate = false 

        local characters = {}

        while index ~= endCHar or terminate do 
            insert(characters, byte(index))
            index = index + increment and 1 or -1

            if index == 0xff + 1 then 
                increment = false 
                index = start 
                characters = {}
            elseif index == -1 then
                terminate = true 
            end
        end
    end

    for _, characterRange in ipairs(characterRangePairs) do
        local characterSet = getCharacterSet(unpack(characterRange))

        for _, character in ipairs(characterSet) do
            insert(symbol, character)
        end
    end

    if printRadix then 
        print(("Maximum radix is " .. #symbol)
    end
end

function module.getBase(base, symbol)
    return function(number)
        local convertedNumber = ''
        repeat
            local remainder = number % base 
            number = floor(number / base)
            convertedNumber = symbol[remainder + 1] .. convertedNumber
        until number == 0
        return base <= 10 and tonumber(convertedNumber) or convertedNumber
    end
end

module.base9 = module.getBase(9)
module.base16 = module.getBase(16)

module.encodingIndex = {
    "terminate": 0x100
}

 -- default to Roblox CFrames which contain 16 numbers: 3 numbers representing XYZ, and a 3x3 rotation matrix 
local componentsPerMedium = 16
local maximumDigits = 15

function module.encode(content, componentsPerMedium, maximumDigits)
    local encodedContent = ''
    local componentBuffer = ''
    local mediumBuffer = {}
    local mediums = {}

    local components = 0
    local digits = 0

    for index = 1, #content, 1 do
        encodedContent = encodedContent .. index ~= 1 and '9' or '' .. module.base9(byte(content:sub(index, index))) 
    end

     -- Used in decoding to know when to stop reading
    encodedContent = encodedContent .. '9' .. module.encodingIndex.terminate

    for index = 1, #encodedContent, 1 do
        componentBuffer = componentBuffer .. encodedContent:sub(index, index)
        digits = digits + 1

        if digits == 2 then 
            componentBuffer = componentBuffer .. '.'
        elseif digits == 15 then
            insert(mediumBuffer, tonumber(componentBuffer))
            componentBuffer = ''
            digits = 0
            components = components + 1
        end
        
        if components == componentsPerMedium then
            insert(mediums, componentBuffer)
            componentBuffer = {}
            components = 0
        end
    end

    return mediums
end