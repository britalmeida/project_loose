
local gfx <const> = playdate.graphics
local Sprite <const> = gfx.sprite

-- Ingredient types
INGREDIENT_TYPES = {
    { name = "Whimsical Cat", rune_composition = {1, 1, 2, 0, 1}, img = gfx.image.new('images/ingredients/cat') }
}

INGREDIENTS = {}


class('Ingredient').extends(Sprite)

function Ingredient:init(ingredient_type_idx, start_pos)
    Ingredient.super.init(self)

    self.ingredient_type_idx = ingredient_type_idx
    self.start_pos = start_pos
    self.is_picked_up = false

    self:setImage(INGREDIENT_TYPES[ingredient_type_idx].img)
    self:moveTo(self.start_pos:unpack())

    self:addSprite()
    self:setVisible(true)
end


function Ingredient:tick()
    -- Called during gameplay when self:isVisible == true

    if self.is_picked_up then
        self:moveTo(GYRO_X, GYRO_Y)
    end
end

function Ingredient:try_pickup()
    local bounds = self:getBoundsRect()
    if bounds:containsPoint(GYRO_X, GYRO_Y) then
        -- Move sprite to the front
        self:setZIndex(8)
        self.is_picked_up = true
    end
end

function Ingredient:release()
    self.is_picked_up = false
    local bounds = self:getBoundsRect()
    local cauldron = playdate.geometry.rect.new(65, 152, 80, 15)
    if bounds:intersects(cauldron) then
        print("Dropped!")
        self:setVisible(false)
    else
        self:moveTo(self.start_pos:unpack())
    end
end



function Init_ingredients()
    INGREDIENTS = {}
    table.insert(INGREDIENTS, Ingredient(1, playdate.geometry.point.new(300, 30)))
end
