
gfx = playdate.graphics
local Sprite = gfx.sprite

-- Ingredient types
local ingredient_types = {
    { name = "Whimsical Cat", img = gfx.image.new('images/ingredients/cat') }
}

INGREDIENTS = {}

class('Ingredient').extends(Sprite)

function Ingredient:init()
    Ingredient.super.init(self)

    self:setImage(ingredient_types[1].img)

    self:addSprite()
    self:setVisible(true)
end


function Ingredient:tick()
    -- Called during gameplay when self:isVisible == true
end
