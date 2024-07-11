local floor, clamp= math.floor, math.clamp
local byte = string.byte
local insert = table.insert
local unpack = table.unpack
local running, yield, resume = coroutine.running, coroutine.yield, coroutine.resume

-- Uninitialized until further implemented
local client

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
        local digits = ""
        repeat
          r = n % base
          n = floor(n / base)
          digits = symbol[r + 1] .. digits
        until n == 0
        return base <= 10 and tonumber(digits) or digits
    end
end

local base9 = getBase(9)
local base16 = getBase(16)

function encode(str) 
  local stringBuffer = ""
  local componentBuffer = {}
  for i = 1, #str, 1 do
    stringBuffer = stringBuffer .. '9' .. base9(byte(str:sub(i, i)))
  end
  local componentBuffer = ""
  local frames = {}
  local frameBuffer = {}
  local c, d = 0, 0
  for i = 1, #stringBuffer, 1 do
    componentBuffer = componentBuffer .. stringBuffer:sub(i, i)
    d = d + 1
    if d == 2 then
      componentBuffer = componentBuffer .. '.'
    elseif d == 15 then
      insert(frameBuffer, tonumber(componentBuffer))
      componentBuffer = ""
      d = 0
      c = c + 1
    end
    if c == 16 then
      insert(frames, frameBuffer)
      frameBuffer = {}
    end
end
  return frames
end

local frequency = 30
local rowSize = 60
local scale = 2
local pBuffer = workspace.buffer

local flags = {}
local 

local bufferSize = 0
local bufferAdresses = {}
local blocks = {}
local currentBlock = 0

function makeByteBlock(buffer, x, y, z, flag)
  local bufferAdress
  if not flag then
   bufferSize += 1
   bufferAdress =  bufferAdress or "0x" .. base16(bufferSize)
   insert(bufferAdresses, bufferAdress)
  end
  local byteBlock = Instance.new("Part")
  byteBlock.Name = flag or bufferAdress
  byteBlock.Anchored = true
  byteBlock.Size = Vector3.one
  byteBlock.Position = Vector3.new(x, y, z)
  byteBlock.Parent = buffer
  
  blocks[bufferAdress] = byteBlock
  return byteBlock
end

function getBlock()
  currentBlock = currentBlock + 1
  local adress = bufferAdresses[currentBlock]
  if not adress then
    local x = floor(currentBlock / rowSize)
    local z = currentBlock % rowSize
    return makeByteBlock(pBuffer, x, 1, z)
  end
  return pBuffer[bufferAdresses[currentBlock]]
end

function toggleFlag(flag, bool)
  if not pBuffer:FindFirstChild(flag) then
    makeByteBlock(pBuffer, bufferSizes[flagBuffer] or #flagBuffer:GetChildren(), 3, 1, flag)
  end
  local flagBlock = pBuffer[flag]
  flagBlock.Position = ((bool ~= nil) and bool)) or flagBlock.Position == Vector3.Zero and Vector3.One or Vector3.Zero
end

function setBlock(adress, dataBuffer)
  pBuffer[adress].CFrame = CFrame.new(unpack(dataBuffer))
end

function makeClientFlag(flag)
  toggleFlag(flag, false):SetNetworkOwnership(client)
end

function awaitFlag(flag)
  if not pBuffer:FindFirstChild(flag) then
    toggleFlag(flag, false)
  end
  
  local blockFlag = pBuffer[flag]
  local thread = running()
  local function resumeThread()
    resume(thread)
  end
  
  blockFlag.Changed("Position", resumeThread)
  yield()
end

function startBuffer(buffer)
  toggleFlag("active", true)
  
  toggleFlag "sync"
  
  local frameIndex = 1
  local bufSize = #buffer
  while bufferAdresses[frameIndex] do
    for index = frameIndex, clamp(frameIndex + bufferSize, 1, bufSize),1 do
      getBlock().CFrame = CFrame.new(unpack(pBuffer[bufferAdresses[index]]))
    end
    makeClientFlag "sync"
    awaitFlag "sync"
  end
end