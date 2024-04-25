local gfx <const> = playdate.graphics
local gfxi <const> = playdate.graphics.image
local geo <const> = playdate.geometry
local Sprite <const> = gfx.sprite

-- Ingredient types
INGREDIENT_TYPES = {
    { name="Peppermints",    rune_composition={ 2, -1,  0},  x= 30, y= 30, img=gfxi.new('images/ingredients/peppermints'),  drop=gfx.image.new('images/ingredients/peppermints_drop'), hold=nil },
    { name="Perfume",        rune_composition={ 3, -1, -1},  x=250, y= 25, img=gfxi.new('images/ingredients/perfume'),      drop=gfx.image.new('images/ingredients/perfume_drop'), hold=nil  },
    { name="Mushrooms",      rune_composition={ 0,  3,  1},  x=300, y= 25, img=gfxi.new('images/ingredients/mushrooms'),    drop=gfx.image.new('images/ingredients/mushrooms_drop'), hold=nil  },
    { name="Peanut Butter",  rune_composition={ 1,  -1, 1},  x=365, y= 25, img=gfxi.new('images/ingredients/peanutbutter'), drop=gfx.image.new('images/ingredients/peanutbutter_drop'), hold=nil  },
    { name="Toenails",       rune_composition={-2,  1,  0},  x= 20, y= 82, img=gfxi.new('images/ingredients/toenails'),     drop=gfx.image.new('images/ingredients/toenails_drop'), hold=nil  },
    { name="Salt",           rune_composition={ 1, -2, -1},  x= 60, y= 83, img=gfxi.new('images/ingredients/salt'),         drop=gfx.image.new('images/ingredients/salt_drop'), hold=nil  },
    { name="Garlic",         rune_composition={-1, -1,  3},  x=270, y= 95, img=gfxi.new('images/ingredients/garlic'),       drop=gfx.image.new('images/ingredients/garlic_drop'), hold=nil  },
    { name="Spiderweb",      rune_composition={ 1,  3,  0},  x=365, y= 95, img=gfxi.new('images/ingredients/spiderweb'),    drop=gfx.image.new('images/ingredients/spiderweb_drop'), hold=gfx.image.new('images/ingredients/spiderweb_held')  },
    { name="Snail Shells",   rune_composition={ 1,  1, -2},  x= 20, y=137, img=gfxi.new('images/ingredients/snailshells'),  drop=gfx.image.new('images/ingredients/snailshells_drop'), hold=gfx.image.new('images/ingredients/snailshells_held')  },
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
    self.is_hover = false
    self.hover_tick = 0

    self.wiggle_tick = 0

    self.vel = geo.vector2D.new(0, 0)

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

    if self.is_drop and self:getBoundsRect():intersects(LIQUID_AABB) then
        Update_rune_count(INGREDIENT_TYPES[self.ingredient_type_idx].rune_composition)
        table.remove(DROPS, table.indexOfElement(DROPS, self))
        self:remove()
        local num_floating_drops = 4
        for _ = 1, num_floating_drops do
          for x = 1, NUM_BUBBLES, 1 do
            if not Bubbles_animation_playing[x] then
              Bubbles_animation_playing[x] = true
              Bubbles_types[x] = self.ingredient_type_idx
              break
            end
          end
        end
    end
    if self.is_picked_up then
        self.vel.dx, self.vel.dy = GYRO_X - PREV_GYRO_X, GYRO_Y - PREV_GYRO_Y
        -- Follow the gyro
        self:moveTo(GYRO_X, GYRO_Y)
    elseif self.is_over_cauldron then
      self:wiggle()
      if SHAKE_VAL > 2 and self.can_drop then
        PLAYER_LEARNED.how_to_shake = true
        self.can_drop = false
        playdate.timer.new(200, function ()
          self:drop()
        end)
      end
    elseif self.is_in_air then
        self:moveBy(self.vel:unpack())
        self.vel:addVector(geo.vector2D.new(0, 6))
        local _, y = self:getPosition()
        -- Falling off the bottom
        if y > 500 then
          self:respawn()
        end
    else
      self:hover()
    end
end

function Ingredient:hover()
  local bounds = self:getBoundsRect()
  local hover_time = 10
  if bounds:containsPoint(GYRO_X, GYRO_Y) then
    self.is_hover = true
    self.hover_tick += 1
  else
    self.hover_tick -= 1
  end

  self.hover_tick = math.max(self.hover_tick, 0)
  self.hover_tick = math.min(self.hover_tick, hover_time)

  if self.hover_tick > 0 then
    -- Move sprite to the front
    self:setZIndex(Z_DEPTH.grabbed_ingredient)
    local time = GAMEPLAY_STATE.game_tick / playdate.getFPS()
    local wiggle_freq = 1
    local x_offset = math.sin(time * 2 * math.pi * (wiggle_freq - 0.1))
    local y_offset = math.sin(time * 2 * math.pi * (wiggle_freq + 0.1))
    local hover_vector = geo.vector2D.new(0 + x_offset, -5 + y_offset) * self.hover_tick / hover_time

    self:moveTo((self.start_pos + hover_vector):unpack())
    return true
  else
    if self.is_hover then
      self:moveTo(self.start_pos:unpack())
    end
    self.is_hover = false
  end
  return false
end

function Ingredient:wiggle()
  self.wiggle_tick += 1
  local fps = math.ceil(playdate.getFPS())
  local center = geo.point.new(MAGIC_TRIANGLE_CENTER_X, MAGIC_TRIANGLE_CENTER_Y)
  if self.wiggle_tick / fps >= self.wiggle_time then
    -- reset and wait
    local pause = math.random(2 * fps, 4 * fps)
    self.wiggle_tick = -pause
    self.wiggle_time = math.random(2, 8) / 10
    self:moveTo(center:unpack())
  elseif self.wiggle_tick > 0 then
    -- wiggle!
    local wiggle_freq = 8
    local time = GAMEPLAY_STATE.game_tick / playdate.getFPS()
    local x_offset = math.sin(time * 2 * math.pi * (wiggle_freq - 0.1))
    local y_offset = math.sin(time * 2 * math.pi * (wiggle_freq + 0.1))
    local hover_vector = geo.vector2D.new(x_offset, y_offset) * self.wiggle_tick / fps / self.wiggle_time * 0.8

    self:moveTo((center + hover_vector):unpack())
  end
end

function Ingredient:try_pickup()
    local bounds = self:getBoundsRect()
    if bounds:containsPoint(GYRO_X, GYRO_Y) then
      -- Move sprite to the front
      self:setZIndex(Z_DEPTH.grabbed_ingredient)
      self.is_picked_up = true
      if INGREDIENT_TYPES[self.ingredient_type_idx].hold then
        self:setImage(INGREDIENT_TYPES[self.ingredient_type_idx].hold)
      end
      return true
    end
    return false
end

function Ingredient:release()
    self.is_picked_up = false
    self.is_over_cauldron = false
    self.vel.dx, self.vel.dy = 0, 0

    local bounds = self:getBoundsRect()

    local size = MAGIC_TRIANGLE_SIZE
    local x_center = MAGIC_TRIANGLE_CENTER_X
    local y_center = MAGIC_TRIANGLE_CENTER_Y
    local triangle_bounds = geo.rect.new(x_center - size/2, y_center - size/2, size, size)
    if bounds:intersects(triangle_bounds) then
        self:moveTo(x_center, y_center)
        self:setZIndex(5)
        self.wiggle_time = math.random(2, 8) / 10
        self.is_over_cauldron = true
    elseif bounds:containsPoint(self.start_pos) then
        self:respawn()
    else
        self.is_in_air = true
    end
end

function Ingredient:drop()
  Splash_animating = true
  local drop = Ingredient(self.ingredient_type_idx, geo.point.new(MAGIC_TRIANGLE_CENTER_X, MAGIC_TRIANGLE_CENTER_Y), true)
  drop.is_in_air = true
  drop:setZIndex(Z_DEPTH.grabbed_ingredient)
  drop.vel.dx, drop.vel.dy = math.random(-4, 4), math.random(-15, 0)
  table.insert(DROPS, drop)

  local drops = {SOUND.drop_01, SOUND.drop_02, SOUND.drop_03}
  local r = math.random(1, 3)
  if not drops[r]:isPlaying() then
    drops[r]:play()
  end

  playdate.timer.new(500, function ()
      self.can_drop = true
  end)
end

function Ingredient:respawn()
  if self.is_drop then
    table.remove(DROPS, table.indexOfElement(DROPS, self))
    self:remove()
  else
    self:moveTo(self.start_pos:unpack())
    self:setZIndex(Z_DEPTH.ingredients)
    self.is_in_air = false
    self.is_over_cauldron = false
    self.is_picked_up = false
    if INGREDIENT_TYPES[self.ingredient_type_idx].hold then
      self:setImage(INGREDIENT_TYPES[self.ingredient_type_idx].img)
    end
  end
end


function Reset_ingredients()

  -- Clear current ingredients.
  for _, ingredient in ipairs(INGREDIENTS) do
    ingredient:remove()
  end
  INGREDIENTS = {}

  -- Recreate the shelve ingredients.
  for a=1, #INGREDIENT_TYPES, 1 do
    table.insert(INGREDIENTS, Ingredient(a, geo.point.new(INGREDIENT_TYPES[a].x, INGREDIENT_TYPES[a].y), false))
  end
end
