local gfx <const> = playdate.graphics
local gfxi <const> = playdate.graphics.image
local gfxit <const> = playdate.graphics.imagetable
local geo <const> = playdate.geometry
local Sprite <const> = gfx.sprite
local animloop <const> = playdate.graphics.animation.loop


local splish_imgs, splish_framerate = gfxit.new("images/fx/splish"), 3

INGREDIENT_TYPES = {
    { name="Peppermints",   drop_name="peppermint",   rune_composition={ 1, -0.33,  0},  x= 375, y= 27,     img=gfxi.new('images/ingredients/peppermints'),  drop=gfx.image.new('images/ingredients/peppermints_drop'), hold=nil },
    { name="Perfume",       drop_name="perfume drop", rune_composition={ 1, 0, -0.33},   x=330,  y= 32,     img=gfxi.new('images/ingredients/perfume'),      drop=gfx.image.new('images/ingredients/perfume_drop'),     hold=nil  },
    { name="Mushrooms",     drop_name="mushroom",     rune_composition={ -0.33,  1,  0.5},  x=270,  y= 28,  img=gfxi.new('images/ingredients/mushrooms'),    drop=gfx.image.new('images/ingredients/mushrooms_drop'),   hold=nil  },
    { name="Coffee Beans",  drop_name="coffee bean",  rune_composition={ 0.5,  -0.33, 1},   x=33,   y= 81,  img=gfxi.new('images/ingredients/coffee'),       drop=gfx.image.new('images/ingredients/coffee_drop'),      hold=nil  },
    { name="Toenails",      drop_name="toenail",      rune_composition={-1,  0.33,  0},  x= 20,  y= 25,     img=gfxi.new('images/ingredients/toenails'),     drop=gfx.image.new('images/ingredients/toenails_drop'),    hold=nil  },
    { name="Salt",          drop_name="salt",         rune_composition={ 0, -1, -0.33},  x= 64,  y= 28,     img=gfxi.new('images/ingredients/salt'),         drop=gfx.image.new('images/ingredients/salt_drop'),        hold=nil  },
    { name="Garlic",        drop_name="garlic clove", rune_composition={0, -0.33,  1},   x=280,  y= 95,     img=gfxi.new('images/ingredients/garlic'),       drop=gfx.image.new('images/ingredients/garlic_drop'),      hold=gfx.image.new('images/ingredients/garlic_held')  },
    { name="Spiderweb",     drop_name="spider",       rune_composition={ -0.33,  1,  0}, x=365,  y= 105,    img=gfxi.new('images/ingredients/spiderweb'),    drop=gfx.image.new('images/ingredients/spiderweb_drop'),   hold=gfx.image.new('images/ingredients/spiderweb_held')  },
    { name="Snail Shells",  drop_name="snail shell",  rune_composition={ 0.33,  0, -1},  x= 20,  y=140,     img=gfxi.new('images/ingredients/snailshells'),  drop=gfx.image.new('images/ingredients/snailshells_drop'), hold=gfx.image.new('images/ingredients/snailshells_held')  },
}

INGREDIENTS = {}
DROPS = {}

INGREDIENT_STATE = { is_in_shelf = 0, is_picked_up = 2, is_in_air = 3, is_over_cauldron = 4 }

CAULDRON_INGREDIENT = nil
LAST_CAULDRON_INGREDIENT = nil
LAST_SHAKEN_INGREDIENT = nil
CALUDRON_SWAP_COUNT = 0

Ingredient = NewSubClass("Ingredient", Sprite)

function Ingredient:init(ingredient_type_idx, start_pos, is_drop)
    Ingredient.super.init(self)

    self.ingredient_type_idx = ingredient_type_idx
    self.start_pos = start_pos
    
    self.is_drop = is_drop

    self.state = INGREDIENT_STATE.is_in_shelf

    self.can_drop = true
    self.is_hovering = false
    self.hover_tick = 0

    self.is_wiggling = false

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
        -- add ingredient to current recipe and update rune count
        CURRENT_RECIPE[#CURRENT_RECIPE+1] = self.ingredient_type_idx
        Update_rune_count(INGREDIENT_TYPES[self.ingredient_type_idx].rune_composition)
        Recipe_update_current()
        LAST_SHAKEN_INGREDIENT = self.ingredient_type_idx
        CALUDRON_SWAP_COUNT = 0

        -- Update list of already used ingredients
        if GAMEPLAY_STATE.used_ingredients_table[self.ingredient_type_idx] == false then
          GAMEPLAY_STATE.used_ingredients_table[self.ingredient_type_idx] = true
          GAMEPLAY_STATE.used_ingredients += 1
        end

        -- Unregister this ingredient drop.
        table.remove(DROPS, table.indexOfElement(DROPS, self))
        self:remove()

        -- Play SFX for hitting the liquid.
        INGREDIENT_SPLASH:play(self.x, self.y)
        local drop_sounds = {SOUND.drop_01, SOUND.drop_02, SOUND.drop_03}
        local r = math.random(1, 3)
        drop_sounds[r]:playAt(0) -- Always play the sound, even if it was already playing.

        -- Show the drop as floating in the liquid.
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
    if self.state == INGREDIENT_STATE.is_in_shelf then
        self:hover()
    elseif self.state == INGREDIENT_STATE.is_picked_up then
        self.vel.dx, self.vel.dy = GYRO_X - PREV_GYRO_X, GYRO_Y - PREV_GYRO_Y
        -- Follow the gyro
        self:moveTo(GYRO_X, GYRO_Y)
        CAULDRON_INGREDIENT = nil
    elseif self.state == INGREDIENT_STATE.is_over_cauldron then
        if self.is_wiggling then
            self:wiggle()
        end
        if CAULDRON_INGREDIENT == nil then
          CALUDRON_SWAP_COUNT += 1
        end
        CAULDRON_INGREDIENT = self.ingredient_type_idx
        LAST_CAULDRON_INGREDIENT = self.ingredient_type_idx
        if self.can_drop and (SHAKE_VAL > 3 or IS_SIMULATING_SHAKE) then
            self.can_drop = false
            self:trigger_drop()
        end
    elseif self.state == INGREDIENT_STATE.is_in_air then
        self:fall()
    end
end

function Ingredient:fall()
    self:moveBy(self.vel:unpack())
    self.vel:addVector(geo.vector2D.new(0, 6))
    local _, y = self:getPosition()
    -- Falling off the bottom
    if y > 500 then
        self:respawn()
    end
end

function Ingredient:trigger_drop()
    self:start_wiggle()

    -- Do the drop with a delay
    playdate.timer.new(200, function ()
        self:drop()
    end)
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
    local time = playdate.getElapsedTime()
    local wiggle_freq = 1
    local x_offset = math.sin(time * 2 * math.pi * (wiggle_freq - 0.1))
    local y_offset = math.sin(time * 2 * math.pi * (wiggle_freq + 0.1))
    local hover_vector = geo.vector2D.new(0 + x_offset, -5 + y_offset) * self.hover_tick / hover_time

    self:moveTo((self.start_pos + hover_vector):unpack())
  else
    if self.is_hovering then
      self:moveTo(self.start_pos:unpack())
    end
    self.is_hovering = false
  end
  return false
end

function Ingredient:start_wiggle()
    if self.wiggle_timer then
        self.wiggle_timer:remove()
    end
    self.is_wiggling = true
    self.wiggle_time = math.random(2, 8) / 10
    self.wiggle_timer = playdate.timer.new(self.wiggle_time * 1000, function ()
        if self.state == INGREDIENT_STATE.is_over_cauldron then
            self:end_wiggle()
        end
    end)
end

function Ingredient:wiggle()
  -- safeguard
  -- if self.wiggle_timer == nil then
  --   return
  -- end
  local current_wiggle_time = self.wiggle_timer.currentTime / 1000
  
  local wiggle_freq = 8
  local x_offset = math.sin(current_wiggle_time * 2 * math.pi * (wiggle_freq - 0.1))
  local y_offset = math.sin(current_wiggle_time * 2 * math.pi * (wiggle_freq + 0.1))
  local hover_vector = geo.vector2D.new(x_offset, y_offset) * current_wiggle_time / self.wiggle_time * 0.8
  
  local center = geo.point.new(MAGIC_TRIANGLE_CENTER_X, MAGIC_TRIANGLE_CENTER_Y)
  self:moveTo((center + hover_vector):unpack())
end

function Ingredient:end_wiggle()
  self.is_wiggling = false

  local center = geo.point.new(MAGIC_TRIANGLE_CENTER_X, MAGIC_TRIANGLE_CENTER_Y)
  self:moveTo(center:unpack())

  -- wiggle again after random pause
  local pause = math.random(2 * 1000, 4 * 1000)
  playdate.timer.new(pause, function ()
      if self.state == INGREDIENT_STATE.is_over_cauldron then
          self:start_wiggle()
      end
  end)
end

function Ingredient:try_pickup()
    local bounds = self:getBoundsRect()
    if bounds:containsPoint(GYRO_X, GYRO_Y) then
      -- Move sprite to the front
      self:setZIndex(Z_DEPTH.grabbed_ingredient)
      self.state = INGREDIENT_STATE.is_picked_up
      if INGREDIENT_TYPES[self.ingredient_type_idx].hold then
        self:setImage(INGREDIENT_TYPES[self.ingredient_type_idx].hold)
      end
      return true
    end
    return false
end

function Ingredient:release()
    self.state = INGREDIENT_STATE.is_in_air
    self.vel.dx, self.vel.dy = 0, 0

    local bounds = self:getBoundsRect()

    local size = MAGIC_TRIANGLE_SIZE
    local center = geo.point.new(MAGIC_TRIANGLE_CENTER_X, MAGIC_TRIANGLE_CENTER_Y)
    local triangle_bounds = geo.rect.new(center.x - size/2, center.y - size/2, size, size)
    if bounds:intersects(triangle_bounds) then
        self:moveTo(center:unpack())
        self:setZIndex(Z_DEPTH.ingredient_slotted_over_cauldron)
        --start wiggling
        self:start_wiggle()
        self.state = INGREDIENT_STATE.is_over_cauldron
        if not PLAYER_LEARNED.how_to_release then
          print("learned how to release")
        end
        PLAYER_LEARNED.how_to_release = true
    elseif bounds:containsPoint(self.start_pos) then
        self:respawn()
    end
end

function Ingredient:drop()

  local drop = Ingredient(self.ingredient_type_idx, geo.point.new(MAGIC_TRIANGLE_CENTER_X, MAGIC_TRIANGLE_CENTER_Y), true)
  drop.state = INGREDIENT_STATE.is_in_air
  drop:setZIndex(Z_DEPTH.indredient_drops)
  drop.vel.dx, drop.vel.dy = math.random(-4, 4), math.random(-15, 0)
  table.insert(DROPS, drop)

  playdate.timer.new(500, function ()
      self.can_drop = true
  end)

  if not PLAYER_LEARNED.how_to_shake then
    PLAYER_LEARNED.how_to_shake = true
    FROG:flash_b_prompt()
    print("Learned how to shake")
  end
end

function Ingredient:respawn()
  if self.is_drop then
    table.remove(DROPS, table.indexOfElement(DROPS, self))
    self:remove()
  else
    self:moveTo(self.start_pos:unpack())
    self:setZIndex(Z_DEPTH.ingredients)
    self.state = INGREDIENT_STATE.is_in_shelf
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



IngredientSplash = NewSubClass("IngredientSplash", Sprite)

function IngredientSplash:init()
    IngredientSplash.super.init(self)

    self.anim = animloop.new(splish_framerate * frame_ms, gfxit.new("images/fx/splish"), false)

    self:moveTo(LIQUID_CENTER_X+5, LIQUID_CENTER_Y-10)
    self:setZIndex(Z_DEPTH.ingredient_drop_splash)

    self:reset()

    self:addSprite()
end


function IngredientSplash:reset()
  self:setVisible(false)
end


IngredientSplash.update = function(self)
  self:setImage(self.anim:image())

  -- Hide when done.
  if not self.anim:isValid() then
    self:setVisible(false)
  end
end


function IngredientSplash:play(x, y)
  self:moveTo(x, y)
  self.anim.frame = 1
  self:setVisible(true)
end
