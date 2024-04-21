
local gfx <const> = playdate.graphics
local Sprite <const> = gfx.sprite

-- Ingredient types
INGREDIENT_TYPES = {
    { name = "Garlic", rune_composition = {3, 1, 0}, img = gfx.image.new('images/ingredients/garlic'), drop = gfx.image.new('images/ingredients/garlic_drop') },
    { name = "Mushrooms", rune_composition = {0, 3, 1}, img = gfx.image.new('images/ingredients/mushrooms'), drop = gfx.image.new('images/ingredients/mushrooms_drop') },
    { name = "Peanut Butter", rune_composition = {1, 0, 3}, img = gfx.image.new('images/ingredients/peanutbutter'), drop = gfx.image.new('images/ingredients/peanutbutter_drop') },
    { name = "Peppermints", rune_composition = {2, 0, 2}, img = gfx.image.new('images/ingredients/peppermints'), drop = gfx.image.new('images/ingredients/peppermints_drop') },
    { name = "Perfume", rune_composition = {2, 2, 0}, img = gfx.image.new('images/ingredients/perfume'), drop = gfx.image.new('images/ingredients/perfume_drop') },
    { name = "Salt", rune_composition = {0, 2, 2}, img = gfx.image.new('images/ingredients/salt'), drop = gfx.image.new('images/ingredients/salt_drop') },
    { name = "Snail Shells", rune_composition = {-3, 1, 0}, img = gfx.image.new('images/ingredients/snailshells'), drop = gfx.image.new('images/ingredients/snailshells_drop') },
    { name = "Spiderweb", rune_composition = {0, -3, 1}, img = gfx.image.new('images/ingredients/spiderweb'), drop = gfx.image.new('images/ingredients/spiderweb_drop') },
    { name = "Toenails", rune_composition = {1, 0, -3}, img = gfx.image.new('images/ingredients/toenails'), drop = gfx.image.new('images/ingredients/toenails_drop') },
}

INGREDIENTS = {}
DROPS = {}

class('Ingredient').extends(Sprite)

function Ingredient:init(ingredient_type_idx, start_pos, is_drop)
    Ingredient.super.init(self)

    self.ingredient_type_idx = ingredient_type_idx
    self.start_pos = start_pos
    self.is_picked_up = false
    self.is_over_cauldron = false
    self.is_in_air = false
    self.can_drop = true
    self.is_drop = is_drop

    self.vel = playdate.geometry.vector2D.new(0, 0)

    if self.is_drop then
      self:setImage(INGREDIENT_TYPES[ingredient_type_idx].drop)
    else
      self:setImage(INGREDIENT_TYPES[ingredient_type_idx].img)
    end
    self:moveTo(self.start_pos:unpack())

    self:addSprite()
    self:setVisible(true)
end


function Ingredient:tick()
    -- Called during gameplay when self:isVisible == true

    local cauldron = playdate.geometry.rect.new(65, 152, 80, 15)
    if self.is_drop and self:getBoundsRect():intersects(cauldron) then
        Update_rune_count(INGREDIENT_TYPES[self.ingredient_type_idx].rune_composition)
        self:remove()
    end
    if self.is_picked_up then
        self.vel.dx, self.vel.dy = PREV_GYRO_X - GYRO_X, PREV_GYRO_Y - GYRO_Y
        self:moveTo(GYRO_X, GYRO_Y)
    elseif self.is_over_cauldron then
      if SHAKE_VAL > 2 and self.can_drop then
        playdate.timer.new(200, function ()
          self:drop()
        end)
      end
    elseif self.is_in_air then
        self:moveBy(self.vel:unpack())
        self.vel:addVector(playdate.geometry.vector2D.new(0, 9))
        local _, y = self:getPosition()
        if y > 300 then
          if self.is_drop then
              self:remove()
          else
            self:moveTo(self.start_pos:unpack())
            self.is_in_air = false
            self.is_over_cauldron = false
            self.is_picked_up = false
          end
        end
    end
end

function Ingredient:try_pickup()
    local bounds = self:getBoundsRect()
    if bounds:containsPoint(GYRO_X, GYRO_Y) then
        -- Move sprite to the front
        self:setZIndex(8)
        self.is_picked_up = true
        return true
    end
    return false
end

function Ingredient:release()
    self.is_picked_up = false
    self.is_over_cauldron = false

    local bounds = self:getBoundsRect()

    local size = 100
    local x_center = 100
    local y_center = 80
    local triangle_bounds = playdate.geometry.rect.new(x_center - size/2, y_center - size/2, size, size)
    if bounds:intersects(triangle_bounds) then
        self:moveTo(x_center, y_center)
        self.is_over_cauldron = true
    else
        self.is_in_air = true
    end
end

function Ingredient:drop()
  local drop = Ingredient(self.ingredient_type_idx, playdate.geometry.point.new(100, 80), true)
  drop.is_in_air = true
  drop:setZIndex(8)
  drop.vel.dx, drop.vel.dy = math.random(-8, 8), math.random(-8, 8)
  table.insert(DROPS, drop)

  self.can_drop = false
  playdate.timer.new(500, function ()
      self.can_drop = true
  end)
end


function Init_ingredients()
    INGREDIENTS = {}
    table.insert(INGREDIENTS, Ingredient(1, playdate.geometry.point.new(260, 30), false))
    table.insert(INGREDIENTS, Ingredient(2, playdate.geometry.point.new(300, 30), false))
    table.insert(INGREDIENTS, Ingredient(3, playdate.geometry.point.new(340, 30), false))
    table.insert(INGREDIENTS, Ingredient(4, playdate.geometry.point.new(260, 90), false))
    table.insert(INGREDIENTS, Ingredient(5, playdate.geometry.point.new(300, 90), false))
    table.insert(INGREDIENTS, Ingredient(6, playdate.geometry.point.new(340, 90), false))
    table.insert(INGREDIENTS, Ingredient(7, playdate.geometry.point.new(260, 150), false))
    table.insert(INGREDIENTS, Ingredient(8, playdate.geometry.point.new(300, 150), false))
    table.insert(INGREDIENTS, Ingredient(9, playdate.geometry.point.new(340, 150), false))
end
