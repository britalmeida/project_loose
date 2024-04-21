import "tutorial_frog"

GYRO_X, GYRO_Y = 200, 120
PREV_GYRO_X, PREV_GYRO_Y = 200, 120

NUM_RUNES = 3
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
    rune_count = {0, 0, 0},
    rune_ratio = {0, 0, 0},
}

-- Stir speed is the speed of cranking in revolutions per seconds
STIR_SPEED = 0

-- Stir position is an angle in radians
STIR_POSITION = 0

GRAVITY_X = 0
GRAVITY_Y = 0
GRAVITY_Z = 0

SHAKE_VAL = 0

-- Resource Management


function Init_gameplay()
    -- Done only once on start of the game, to load and setup const resources.

    playdate.startAccelerometer()

    Init_frog()
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

    -- Reset current ingredient mix.
    for a = 1, NUM_RUNES, 1 do
        GAMEPLAY_STATE.rune_count[a] = 0
        GAMEPLAY_STATE.rune_ratio[a] = 0
    end

    Reset_frog()

    -- Reset time delta
    playdate.resetElapsedTime()
end

function Update_rune_count(difference)
    local sum = 0
    for a = 1, NUM_RUNES, 1 do
        GAMEPLAY_STATE.rune_count[a] += difference[a]
        if GAMEPLAY_STATE.rune_count[a]<0 then
            GAMEPLAY_STATE.rune_count[a] = 0
        end
        sum = sum + GAMEPLAY_STATE.rune_count[a]
    end
    for a = 1, NUM_RUNES, 1 do
        GAMEPLAY_STATE.rune_ratio[a] = GAMEPLAY_STATE.rune_count[a] / sum
    end
end

-- Update Loop
--- `timeDelta` is the time in seconds since the last update.
---@param timeDelta number
function Handle_input(timeDelta)
    GRAVITY_X, GRAVITY_Y, GRAVITY_Z = playdate.readAccelerometer()
    -- Occasionally when simulator startes to upload the game to the actual
    -- device the gyro returns nil as results.
    if GRAVITY_X == nil then
        return
    end
    SHAKE_VAL = GRAVITY_X * GRAVITY_X + GRAVITY_Y * GRAVITY_Y + GRAVITY_Z * GRAVITY_Z

    local gyroSpeed = 30
    if SHAKE_VAL < 1.1 then
      PREV_GYRO_X = GYRO_X
      PREV_GYRO_Y = GYRO_Y
      GYRO_X = Clamp(GYRO_X + GRAVITY_X * gyroSpeed, 0, 400)
      GYRO_Y = Clamp(GYRO_Y + GRAVITY_Y * gyroSpeed, 0, 240)
    end

    if playdate.buttonIsPressed( playdate.kButtonB ) then
        Ask_the_frog()
    end
    if playdate.buttonJustPressed( playdate.kButtonA ) then
      for i, ingredient in pairs(INGREDIENTS) do
          if ingredient.is_over_cauldron then
            ingredient:release()
          end
      end
        for i, ingredient in pairs(INGREDIENTS) do
          if ingredient:try_pickup() then
            break
          end
        end
    end
    if playdate.buttonJustReleased(playdate.kButtonA) then
        for i, ingredient in pairs(INGREDIENTS) do
            if ingredient.is_picked_up then
              ingredient:release()
            end
        end
    end

    local angleDelta, _ = playdate.getCrankChange()
    local revolutionsPerSecond = math.rad(angleDelta) / (timeDelta)
    STIR_SPEED = revolutionsPerSecond

    local mic_lvl = playdate.sound.micinput.getLevel()
    if mic_lvl > GAMEPLAY_STATE.flame_amount then
        GAMEPLAY_STATE.flame_amount = mic_lvl
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

    -- Update drops animations.
    for _, drop in ipairs(DROPS) do
        if drop:isVisible() then
          drop:tick()
        end
    end

    if GAMEPLAY_STATE.flame_amount > 0.01 then
        local flame_decay = 0.99
        GAMEPLAY_STATE.flame_amount *= flame_decay
    else
        GAMEPLAY_STATE.flame_amount = 0
    end

    -- Update liquid color
    local color_change = 0.001
    if STIR_SPEED < 0 then
        GAMEPLAY_STATE.potion_color = GAMEPLAY_STATE.potion_color / ((color_change * math.abs(STIR_SPEED)) + 1)
    elseif STIR_SPEED > 0 then
        GAMEPLAY_STATE.potion_color = 1 - (1 - GAMEPLAY_STATE.potion_color) / ((color_change * STIR_SPEED) + 1)
    end

    -- Update liquid state
    GAMEPLAY_STATE.liquid_momentum += Clamp(STIR_SPEED, -8, 8) / 10
    GAMEPLAY_STATE.liquid_offset += GAMEPLAY_STATE.liquid_momentum
    GAMEPLAY_STATE.liquid_momentum *= GAMEPLAY_STATE.liquid_viscosity
    if math.abs(GAMEPLAY_STATE.liquid_momentum) < 1e-4 then
      GAMEPLAY_STATE.liquid_momentum = 0
    end

    Tick_frog()
end

