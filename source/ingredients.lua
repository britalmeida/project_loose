
local gfx <const> = playdate.graphics
local Sprite <const> = gfx.sprite

-- Ingredient types
INGREDIENT_TYPES = {
    { name = "Whimsical Cat", element_composition = {1, 0, -1, 0, 1}, img = gfx.image.new('images/ingredients/cat') }
}

INGREDIENTS = {}


class('Ingredient').extends(Sprite)

function Ingredient:init(ingredient_type_idx)
    Ingredient.super.init(self)

    self.ingredient_type_idx = ingredient_type_idx
    self.is_going_in_the_pot = false

    self:setImage(INGREDIENT_TYPES[ingredient_type_idx].img)
    self:moveTo(300, 30)

    self:addSprite()
    self:setVisible(true)
end


function Ingredient:tick()
    -- Called during gameplay when self:isVisible == true

    if self.is_going_in_the_pot then
        self:moveTo(self.x - 7, self.y + 5)
    end
end



function Init_ingredients()
    INGREDIENTS = {}
    table.insert(INGREDIENTS, Ingredient(1))
end
