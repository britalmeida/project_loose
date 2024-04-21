GYRO_X, GYRO_Y = 200, 120

NUM_ELEMENTS = 5
GAMEPLAY_STATE = {
    flame_amount = 0.0,
    water_amount = 0.0,
    liquid_offset = 0.0,
    liquid_momentum = 0.0,
    -- This is a factor between 0 and 1 (0.85 = high viscosity, 0.95 = low viscosity)
    liquid_viscosity = 0.9,
    -- Potion mix?
    potion_color = 0.5,
    potion_bubbliness = 0.0,
    game_tick = 0,
    element_target_ratio = {},
    element_count = {},
}

-- Stir speed is the speed of cranking in revolutions per seconds
STIR_SPEED = 0

-- Stir position is an angle in radians
STIR_POSITION = 0

-- Resource Management


function Init_gameplay()
    -- Done only once on start of the game, to load and setup const resources.

    playdate.startAccelerometer()
end


function Stop_gameplay()
    -- Done on every game over/win to stop ongoing sounds and events.
    -- Not a complete tear down of resources.
end


function Reset_gameplay()
    -- Done on every (re)start of the play.

    -- Reset available ingredients.
    for _, ingredient in ipairs(INGREDIENTS) do
        ingredient:remove()
    end
    Init_ingredients()

    -- Reset target ingredients.
    local sum = 0
    for a = 1, NUM_ELEMENTS, 1 do
        GAMEPLAY_STATE.element_target_ratio[a] = math.random(100)
        sum = sum + GAMEPLAY_STATE.element_target_ratio[a]
    end
    for a = 1, #GAMEPLAY_STATE.element_target_ratio, 1 do
        GAMEPLAY_STATE.element_target_ratio[a] = GAMEPLAY_STATE.element_target_ratio[a] / sum
    end
    for a = 1, #GAMEPLAY_STATE.element_target_ratio, 1 do
        GAMEPLAY_STATE.element_count[a] = 0
    end

    -- Reset time delta
    playdate.resetElapsedTime()
end


-- Update Loop
--- `timeDelta` is the time in seconds since the last update.
---@param timeDelta number
function Handle_input(timeDelta)
    local gravityX, gravityY, _gravityZ = playdate.readAccelerometer()
    GYRO_X = Clamp(GYRO_X + gravityX * 10, 0, 400)
    GYRO_Y = Clamp(GYRO_Y + gravityY * 10, 0, 240)

    if playdate.buttonIsPressed( playdate.kButtonA ) then
        if not SOUND.cat_meow:isPlaying() then
            SOUND.cat_meow:play()
        end

        mixed_ingredient = INGREDIENTS[1]
        mixed_ingredient_type_idx = mixed_ingredient.ingredient_type_idx
        element_mix = INGREDIENT_TYPES[mixed_ingredient_type_idx].element_composition

        mixed_ingredient.is_going_in_the_pot = true
        -- Start a timer to despawn the ingredient visuals.
         playdate.timer.new(0.8*1000, function()
            mixed_ingredient:setVisible(false)

            for a = 1, #GAMEPLAY_STATE.element_target_ratio, 1 do
                GAMEPLAY_STATE.element_count[a] += element_mix[a]
            end
        end)
    end

    local angleDelta, _ = playdate.getCrankChange()
    local revolutionsPerSecond = math.rad(angleDelta) / (timeDelta)
    STIR_SPEED = revolutionsPerSecond

    if playdate.buttonIsPressed( playdate.kButtonB ) then
        GAMEPLAY_STATE.flame_amount += 1
    end

    -- Use the absolute position of the crank to drive the stick in the cauldorn
    STIR_POSITION = math.rad(playdate.getCrankPosition())

    -- DEBUG VISCOSITY
    if playdate.buttonIsPressed( playdate.kButtonUp ) then
      GAMEPLAY_STATE.liquid_viscosity -= 0.01
      GAMEPLAY_STATE.liquid_viscosity = Clamp(GAMEPLAY_STATE.liquid_viscosity, 0.80, 0.99)
      print(GAMEPLAY_STATE.liquid_viscosity)
    end

    if playdate.buttonIsPressed( playdate.kButtonDown ) then
      GAMEPLAY_STATE.liquid_viscosity += 0.01
      GAMEPLAY_STATE.liquid_viscosity = Clamp(GAMEPLAY_STATE.liquid_viscosity, 0.80, 0.99)
      print(GAMEPLAY_STATE.liquid_viscosity)
    end
end


function Tick_gameplay()
    GAMEPLAY_STATE.game_tick += 1
    -- Update ingredient animations.
    for _, ingredient in ipairs(INGREDIENTS) do
        if ingredient:isVisible() then
            ingredient:tick()
        end
    end

    if not playdate.buttonIsPressed( playdate.kButtonB ) then
        GAMEPLAY_STATE.flame_amount -= 1
        if GAMEPLAY_STATE.flame_amount < 0 then
            GAMEPLAY_STATE.flame_amount = 0
        end
    end

    -- Update liquid state
    GAMEPLAY_STATE.liquid_momentum += Clamp(STIR_SPEED, -8, 8) / 10
    GAMEPLAY_STATE.liquid_offset += GAMEPLAY_STATE.liquid_momentum
    GAMEPLAY_STATE.liquid_momentum *= GAMEPLAY_STATE.liquid_viscosity
    if math.abs(GAMEPLAY_STATE.liquid_momentum) < 1e-4 then
      GAMEPLAY_STATE.liquid_momentum = 0
    end
end

