local floor, clamp, abs, byte, char, insert, concat, sort, clear, yield, running = math.floor, math.clamp, math.abs, string.byte, string.char, table.insert, table.concat, table.sort, table.clear, coroutine.yield, coroutine.running 

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
    local cache = {}
    local optNumberType = base <= 10
    return function(number)
        if cache[number] then
            return cache[number]
        end

        local convertedNumber = ''

        repeat
            local remainder = number % base 
            number = floor(number / base)
            convertedNumber = symbol[remainder + 1] .. convertedNumber
        until number == 0
        
        local convertedNumber = optNumberType and tonumber(convertedNumber) or convertedNumber
        cache[number] = convertedNumber

        return convertedNumber
    end
end

module.base9 = module.getBase(9)
module.base16 = module.getBase(16)

module.encodingIndex = {
    "terminate": 0x100
}

for key, value in pairs(module.encodingIndex) do 
    module.encodingIndex[key] = base9(value)
end
 -- default to Roblox CFrames which contain 16 numbers: 3 numbers representing XYZ, and a 3x3 rotation matrix 
local componentsPerMedium = 16
local maximumDigits = 15

function module:encode(content, componentsPerMedium, maximumDigits)
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
    encodedContent = encodedContent .. '9' .. self.encodingIndex.terminate

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
            clear(componentBuffer)
            components = 0
        end
    end

    return mediums
end

module.buffer = {}

function module.buffer:getNextAvailableIndex() 
    superBuffer:reorganize()

    if not buffers[self.index + 1] then 
        if module.superBufferCapacity - self.endIndex == 0 then 
            return 
        else 
            return self.endIndex + 1, "0x" .. base16(self.endIndex + 1)
        end
    end

    for bufferIndex = self.index + 1, superBuffer.size, 1 do 
       if buffers[bufferIndex].startingIndex - buffers[bufferIndex - 1].endingIndex > 0 then
        return buffers[bufferIndex - 1].endingIndex + 1, "0x" .. base16(buffers[bufferIndex - 1].endingIndex + 1)
       end
    end
end

local bufferMeta = {
    ["__index"] = module.buffer,
    ["__newindex"] = function()
        error "The buffer may not be modified"
    end
}

 -- if not running in roblox you may have to implement the super buffer yourself 
module.superBuffer = {
    size = 0,
    instance = nil, 
    initialized = false,
    safe = false,
    buffers = {},
    availableRanges = {},

    -- cache addresses to minimize computing addresses 
    addresses = {}
}

local superBuffer = module.superBuffer
local buffers = superBuffer.buffers

 -- Confine super buffer to a maximum size if large block counts consumes too many resources 
module.superBufferCapacity = 250
module.useSuperBufferCapacity = true

function module.superBuffer:assertInitialized()
    assert(self.initialized, "Super buffer has not yet been initialized, please call :initializeSBuffer")
end

local zero = Vector3.zero

function module.superBuffer:makeBlock(adhereToCapacity)
     self:assertInitialized()

     local address = "0x" .. base16(#self.addresses + 1)

     local block = Instance.new("Part")
     block.Size = zero
     block.Position = zero 
     block.Anchored = true 
     block.Name = address
     block.Parent = self.instance
     
     insert(self.addresses, address)

     return block, address
end

function orderAddressRanges(buffer1, buffer2)
    return buffer1.startIndex < buffer2.startIndex 
end

function module.superBuffer:reorganize(skipRangeCalculation)
    sort(self.buffers, orderAddressRanges)

    for index, buffer in ipairs(self.buffers) do 
        buffer.index = index 
    end

    self.size = #self.buffers

    if not skipRangeCalculation then
        self:calculateAvailableRanges()
    end
end


 -- no need to pass buffer when it it needs to be defined within a loop first with respect to an iterating index 
function module.superBuffer:getEarliestIndex()
    self:reorganize(true)

    local index, address = 1, '0x0'
    if buffers[1].startIndex ~= 0 then
         -- I think -1 ?
        return index, address, buffers[1].startIndex - 1
    end

    for index, buffer in ipairs(self.buffers) do 
        if index ~= 1 then
            if buffer.startIndex - buffers[index - 1].endingIndex > 0 then
                return buffers[index - 1].endingIndex + 1, "0x" .. base16(buffers[index - 1].endingIndex + 1), buffer.startIndex - buffers[index - 1].endIndex, buffers[index - 1]
            end
        end
    end
end

function superBuffer:calculateAvailableRanges()
    self:reorganize(true)

    local availableRanges = self.availableRanges

     -- no anchored buffer implicates the earliest index to be 0
    local currentIndex, anchoredBuffer = self:getEarliestIndex()

    function push(endingIndex)
        insert(availableRanges, {currentIndex + 1, endingIndex - 1, endingIndex - currentIndex})
    end

    if not anchoredBuffer and buffers[1] then 
        push(buffers[1].startingIndex)
    end

    for bufferIndex, buffer in ipairs(buffers) do 
         -- if there is a next index and there is a following buffer, we can assume the next index is the following buffers start index 
        local nextIndex = buffer:getNextAvailableIndex()

        if nextIndex and buffers[bufferIndex + 1] then 

    end
end

function module.superBuffer:allocate(size)
    self:assertInitialized()
    self:reorganize()

    local startAddress = 0x0
    local differences = {}
    for index, buffer in ipairs(self.buffers) do 
        local startIndex, endIndex = buffer.startIndex, buffer.endIndex 
        if not (startAddress >= startIndex and startAddress <= endIndex) then 

        end
    end


    local referenceIndex = startAddress
    local sufficentSpace = false 

    for _, buffer in ipairs(self.buffers) do 
        local startIndex, endIndex = buffer.startIndex, buffer.endIndex
        if startIndex - referenceIndex  > size then 
            referenceIndex = endIndex
        else 
            sufficentSpace = true 
            
            break
        end
    end

    if sufficentSpace then 

end

function module.buffer:new()
    module:assertInitialized()
    local buffer = setmetatable({}, bufferMeta)
    insert(self.buffers, buffer)

    return buffer
end



 -- size in blocks, perhaps use bytes in the feature 
function module:initializeSBuffer(size)



    -- ...
    self.superBuffer.initialized = true
end