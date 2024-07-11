local floor = math.floor
local byte = string.byte
local insert = table.insert

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
      frameBuffer = ""
      d = 0
      c = c + 1
    end
    if c == 16 then
      insert(frames, frameBuffer)
      frameBuffer = {}
    end
end

  
