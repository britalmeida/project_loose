-- Utility Functions
---comment
---@param value number
---@param min number
---@param max number
---@return number
function Clamp(value, min, max)
    return math.max(math.min(value, max), min)
end

---Map Range
---@param value number
---@param from_min number
---@param from_max number
---@param to_min number
---@param to_max number
---@return number
function MapRange(value, from_min, from_max, to_min, to_max)
  local factor = (value - from_min) / (from_max - from_min)
  return to_min + factor * (to_max - to_min);
end

function Sign(value)
  if value < 0 then
    return -1
  elseif value > 0 then
    return 1
  end
  return 0
end


-- Playdate Lua SDK patch
-- Utility to avoid playdate's Sprite "extends" syntax to trigger warnings about an undefined global.
-- See https://devforum.play.date/t/class-extends-could-return-the-class/5165/3
function NewSubClass(name, parent)
  class(name).extends(parent)
  return _G[name]
end
