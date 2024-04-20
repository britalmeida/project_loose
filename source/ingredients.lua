
local gfx <const> = playdate.graphics
local Sprite <const> = gfx.sprite

-- Ingredient types
local ingredient_types = {
    { name = "Whimsical Cat", img = gfx.image.new('images/ingredients/cat') }
}

INGREDIENTS = {}


class('Ingredient').extends(Sprite)

function Ingredient:init(ingredient_type_idx)
    Ingredient.super.init(self)

    self.is_going_in_the_pot = false

    self:setImage(ingredient_types[ingredient_type_idx].img)
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
