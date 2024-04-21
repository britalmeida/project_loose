
local gfx <const> = playdate.graphics
local Sprite <const> = gfx.sprite

-- Ingredient types
INGREDIENT_TYPES = {
    { name = "Garlic", rune_composition = {1, -3, 3}, img = gfx.image.new('images/ingredients/garlic') },
    { name = "Mushrooms", rune_composition = {-1, 1, 3}, img = gfx.image.new('images/ingredients/mushrooms') },
    { name = "Peanut Butter", rune_composition = {2, -2, 2}, img = gfx.image.new('images/ingredients/peanutbutter') },
    { name = "Peppermints", rune_composition = {1, 3, -1}, img = gfx.image.new('images/ingredients/peppermints') },
    { name = "Perfume", rune_composition = {3, -1, 1}, img = gfx.image.new('images/ingredients/perfume') },
    { name = "Salt", rune_composition = {3, 1, -3}, img = gfx.image.new('images/ingredients/salt') },
    { name = "Snail Shells", rune_composition = {2, 2, -2}, img = gfx.image.new('images/ingredients/snailshells') },
    { name = "Spiderweb", rune_composition = {-2, 2, 2}, img = gfx.image.new('images/ingredients/spiderweb') },
    { name = "Toenails", rune_composition = {-3, 3, 1}, img = gfx.image.new('images/ingredients/toenails') },
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
        Update_rune_count(INGREDIENT_TYPES[self.ingredient_type_idx].rune_composition)
    end
    self:moveTo(self.start_pos:unpack())
end



function Init_ingredients()
    INGREDIENTS = {}
    table.insert(INGREDIENTS, Ingredient(1, playdate.geometry.point.new(260, 30)))
    table.insert(INGREDIENTS, Ingredient(2, playdate.geometry.point.new(300, 30)))
    table.insert(INGREDIENTS, Ingredient(3, playdate.geometry.point.new(340, 30)))
    table.insert(INGREDIENTS, Ingredient(4, playdate.geometry.point.new(260, 90)))
    table.insert(INGREDIENTS, Ingredient(5, playdate.geometry.point.new(300, 90)))
    table.insert(INGREDIENTS, Ingredient(6, playdate.geometry.point.new(340, 90)))
    table.insert(INGREDIENTS, Ingredient(7, playdate.geometry.point.new(260, 150)))
    table.insert(INGREDIENTS, Ingredient(8, playdate.geometry.point.new(300, 150)))
    table.insert(INGREDIENTS, Ingredient(9, playdate.geometry.point.new(340, 150)))
end
