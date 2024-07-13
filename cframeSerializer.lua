---@diagnostic disable: redefined-local
--[[
version: 2.0
https://github.com/math-rad/physics_serialization/blob/master/cframeSerializer.lua 
script: cframeSerializer.lua
description: designed to be somewhat portable and not limited to just roblox and its datatype CFrames. dynamically allocatable medium buffers. Essentially allows for data transmission without the use of remotes by encoding characters in base9, separating them with the exclusive character to base9, of base10: the digit 9. after this process, it's then split by digit precision limits for floats, and then put into "mediums", which on roblox is a CFrame and has 16 components(16 numbers). buffer support and should soon be able to be two way streams, by creating buffers. it's one big buffer that contains buffers. it's like a heap of buffers.
created: ~july 13th 2024
written under an individual whos aliases are:
    math.rad math-rad bytereality radicalbytes
]]
local floor, clamp, abs, byte, char, insert, concat, sort, clear, remove, find, unpack, yield, running, resume, wrap, status = math.floor, math.clamp, math.abs, string.byte, string.char, table.insert, table.concat, table.sort, table.clear, table.remove, table.find, table.unpack, coroutine.yield, coroutine.running, coroutine.resume, coroutine.wrap, coroutine.status

do 
    if not clamp then 
        function clamp(n, min, max)
            return n < min and min or n > max or n
        end
    end

    if not clear then
        function clear(t)
            for i = 1, #t, 1 do
                t[i] = nil
            end
        end
    end

    if not find then
        function find(t, v, i)
            for i  = i or i, #t do 
                if t[i] == v then 
                    return i
                end
            end
        end
    end
end

local module = {}

local symbol = {}

local printRadix = true

do 
    local characterRangePairs = {{'0', '1'}, {'a', 'z'}, {'A', 'Z'}}
    local function getCharacterSet(characterA, characterB)
        characterA, characterB = tostring(characterA), tostring(characterB)

        local startChar, endChar = byte(characterA), byte(characterB)
        local index = startChar 
        local increment = true 
        local terminate = false 

        local characters = {}

        while index ~= endChar or terminate do 
            insert(characters, byte(index))
            index = index + increment and 1 or -1

            if index == 0xff + 1 then 
                increment = false 
                index = startChar 
                characters = {}
            elseif index == -1 then
                terminate = true 
            end
        end

        return characters
    end

    for _, characterRange in ipairs(characterRangePairs) do
        local characterSet = getCharacterSet(unpack(characterRange))

        for _, character in ipairs(characterSet) do
            insert(symbol, character)
        end
    end

    if printRadix then 
        print(("Maximum radix is " .. #symbol))
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
    ["terminate"] = 0x100
}

for key, value in pairs(module.encodingIndex) do 
    module.encodingIndex[key] = module.base9(value)
end

local componentsPerMedium = 16
local maximumDigits = 7 

module.addressCache = {}
local addressCache = module.addressCache
function module.makeAddress(index)
    if addressCache[index] then
        return addressCache[index]
    end 

    local address = "0x" .. module.base16(index)

    addressCache[index] = address
    return address
end

local makeAddress = module.makeAddress

function module:encode(content, componentsPerMedium, maximumDigits)
    local encodedContent = ''
    local componentBuffer = ''
    local mediumBuffer = {}
    local mediums = {}

     -- default to Roblox CFrames which contain 16 numbers: 3 numbers representing XYZ, and a 3x3 rotation matrix 
    componentsPerMedium = componentsPerMedium or 16
    maximumDigits = maximumDigits or 7 -- it said 6-7 digits for floats 

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

-- if not running in roblox you may have to implement the super buffer yourself 
module.superBuffer = {
    size = 0,
    capacity = 0,
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
module.superBufferMaximumCapacity = 250
module.useSuperBufferCapacity = true

module.buffer = {}

function module.buffer:getNextAvailableIndex() 
    superBuffer:reorganize()

    module.threadController:async()

    if not buffers[self.index + 1] then 
        if module.superBufferCapacity - self.endIndex == 0 then 
            module.threadController:wakeup()
            return 
        else 
            module.threadController:wakeup()
            return self.endIndex + 1, module.makeAddress(self.endIndex + 1), self, nil
        end
    end

    for index = self.index + 1, superBuffer.size, 1 do
        local buffer, precedingBuffer = buffers[index - 1], buffers[index]
        if buffer.startingIndex - precedingBuffer.endingIndex > 1 then
            module.threadController:wakeup()
            return precedingBuffer.endingIndex + 1, module.makeAddress(precedingBuffer.endingIndex + 1), precedingBuffer, buffer
        end
    end
end

local bufferMeta = {
    ["__index"] = module.buffer,
    ["__newindex"] = function()
        error "The buffer may not be modified"
    end
}



function module.superBuffer:assertInitialized()
    assert(self.initialized, "Super buffer has not yet been initialized, please call :initializeSBuffer")
end

 -- makeBlock can be overided with custom super buffer implementation, Vector3 will most likely only be used in settings like Roblox, or other engines which have a native Vector3 datatype
---@diagnostic disable-next-line: undefined-global
local zero = Vector3.zero

function module.superBuffer:makeBlock(adhereToMaxCapacity)
     self:assertInitialized()
     self:reorganize()

     module.threadController:async()

     local size = self.capacity

     if module.useSuperBufferCapacity and adhereToMaxCapacity and size > module.superBufferMaximumCapacity then
        module.threadController:wakeup()
        return
     end
     
     module.threadController:async()
     
     local address = makeAddress(#self.addresses + 1)

      -- same with instance, see previous comment 
---@diagnostic disable-next-line: undefined-global
     local block = Instance.new("Part")
     block.Size = zero
     block.Position = zero
     block.Anchored = true
     block.Name = address
     block.Parent = self.instance
     
     insert(self.addresses, address)

     module.threadController:wakeup()

     return block, address
end

local function orderAddressRanges(buffer1, buffer2)
    return buffer1.startIndex < buffer2.startIndex 
end

function module.superBuffer:reorganize(skipRangeCalculation)
    self:assertInitialized()

    module.threadController:async()

    if not self.safe then 
        sort(self.buffers, orderAddressRanges)

        for index, buffer in ipairs(self.buffers) do 
            buffer.index = index 
        end

        self.size = #self.buffers

        self.safe = true
    end

    if not skipRangeCalculation then
        self:calculateAvailableRanges()
    end

    module.threadController:wakeup()
end


 -- no need to pass buffer when it it needs to be defined within a loop first with respect to an iterating index 
function module.superBuffer:getEarliestIndex()
    self:assertInitialized()

    module.threadController:async()

    self:reorganize(true)

    local index, address = 1, '0x0'

    for bufferIndex, buffer in ipairs(buffers) do 
        if index == 1 and buffer.startIndex ~= 1 then
            return 1 -- one based indexing is not based :/
        else
            local precedingBuffer = buffers[index - 1]
            if buffer.startIndex - precedingBuffer.endingIndex > 1 then
                return precedingBuffer.endingIndex + 1, module.makeAddress(precedingBuffer.endingIndex + 1), buffer.startIndex - precedingBuffer.endIndex, precedingBuffer
            end
        end
    end

    module.threadController:wakeup()
end

function superBuffer:calculateAvailableRanges()
    self:assertInitialized()

    module.threadController:async()

    self:reorganize(true)

    local availableRanges = self.availableRanges
    clear(availableRanges)

     -- no anchored buffer implicates the earliest index to be 0
    local currentIndex, anchoredBuffer = self:getEarliestIndex()

    local function push(startIndex, endIndex, buffer1, buffer2)
        insert(availableRanges, {startIndex, endIndex, endIndex - startIndex + 2, buffer1, buffer2})
    end

    if not anchoredBuffer and buffers[1] then 
        push(1, buffers[1].startIndex, nil, buffers[1])
    end

    for bufferIndex, buffer in ipairs(buffers) do 
         -- if there is a next index and there is a following buffer, we can assume the next index is the following buffers start index 
        local nextIndex, endingIndex, buffer1, buffer2 = buffer:getNextAvailableIndex()

        if nextIndex then
            push(nextIndex, endingIndex, buffer1, buffer2)
        end
    end

    module.threadController:wakeup()

    return availableRanges
end

-- prefer one closest to start

local function sortRanges(range1, range2) 
    return range1[1] < range2[1] 
end

function module.superBuffer:balloc(buffer, size, forceCapacity)
    self:assertInitialized()

    module.threadController:async()

    self:reorganize()

    local sufficentRanges = {}

    for index, range in ipairs(self.availableRanges) do 
        if range[3] >= size then 
            insert(sufficentRanges, range)
        end
    end

    sort(sufficentRanges, sortRanges)

    if not sufficentRanges[1] then
        if forceCapacity then
            local lastIndex = buffers[superBuffer.size]
            self:incrementHeapCapacity()
        end
    end

    local range = sufficentRanges[1]
    local newStartIndex, newEndIndex = unpack(range)

    if buffer.startIndex then 
        for index = 0, buffer.capacity - 1, 1 do 
            local addressFrom, addressTo = buffer.startIndex + index, newStartIndex + index
            
            if self.customImplementation then
                self.write(addressTo, self.read(addressFrom))
            else
                local pBuffer = self.instance
                pBuffer[addressTo].CFrame = pBuffer[addressFrom].CFrame
            end
        end
    end

    buffer.startIndex = newStartIndex
    buffer.endIndex = newEndIndex

    superBuffer.safe = false

    module.threadController:wakeup()

    return newStartIndex, newEndIndex
end

function module.superBuffer:incrementHeapCapacity(sizeIncrement, adhereToMaxCapacity) 
    self:assertInitialized()

    module.threadController:async()

    self:reorganize()

    local currentCapacity = self.capacity 
    local newCapacity = currentCapacity + sizeIncrement

    if module.useSuperBufferCapacity and adhereToMaxCapacity and newCapacity > module.superBufferMaximumCapacity then 
        local difference = newCapacity - module.superBufferMaximumCapacity
        warn (("Adhearing to max super buffer capacity policy(%s block(s) not created)"):format(difference))
        newCapacity = newCapacity - difference
    end

    if newCapacity > currentCapacity then 
        module.threadController:wakeup()
        return warn "super buffer capacity not altered, current capacity is already greater than max capacity"
    end

    for index = currentCapacity + 1, currentCapacity + 1 + sizeIncrement, 1 do 
        self:makeBlock(adhereToMaxCapacity)
    end

    module.threadController:wakeup()
end

function module.buffer:new(capacity, forceCapacity, params)
    module:assertInitialized()

    module.threadController:async()

    local buffer = setmetatable({}, bufferMeta)
    insert(self.buffers, buffer)

    buffer.capacity = capacity

    if params and params.customImplementation then 
        buffer.customImplementation = true
        assert(params.read, "custom implementation must have a read function") 
        assert(params.write, "custom implementation must have a write function")

        buffer.read = params.read 
        buffer.write = params.write
        
        if params.superBufferInit then
            params.superBufferInit(superBuffer)
        end
    end

    superBuffer:malloc(buffer, capacity, forceCapacity)

    module.threadController:wakeup()

    return buffer
end



 -- size in blocks, perhaps use bytes in the feature 
function module:initializeSBuffer()
    self.superBuffer.initialized = true
end

local threadController = {}
module.threadController = threadController

threadController.threads = {}

function threadController:async()
    local thread = running()
    local process = self.process
    if thread ~= process then 
        insert(self.threads, thread)
        resume(self.process)
        yield()
    end
end

function threadController:wakeup()
    resume(self.process)
end

threadController.thread = wrap(function()
    local self = threadController

    while true do 
        local thread = remove(self.threads, 1)

        if thread then 
            if status(thread) == "suspended" then 
                self.process = thread 
                resume(thread)
                yield()
            else 
                insert(self.threads, thread, 1)
            end 
        else 
            self.process = nil 
            yield()
        end
    end
end)