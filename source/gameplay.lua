local vec2d <const> = playdate.geometry.vector2D

GYRO_X, GYRO_Y = 200, 120
PREV_GYRO_X, PREV_GYRO_Y = 200, 120

NUM_RUNES = 3
RUNES = { love = 1, doom = 2, weed = 3 }
DIR = { need_more_of = 1, need_less_of = 2 }

GAMEPLAY_STATE = {
    showing_cocktail = false,
    showing_instructions = false,
    showing_recipe = false,
    -- Fire!
    flame_amount = 0.0,
    heat_amount = 0.0,
    -- Viscosity
    liquid_offset = 0.0,
    liquid_momentum = 0.0,
    liquid_viscosity = 0.9, -- This is a factor between 0 and 1 (0.85 = high viscosity, 0.95 = low viscosity)
    -- Current potion mix
    potion_color = 0.5,
    potion_bubbliness = 0.0,
    rune_count = {0, 0, 0},
    rune_ratio = {0, 0, 0},
    -- ??
    game_tick = 0,
    -- The cursor is held down
    cursor_hold = false,
}

CURRENT_RECIPE = {}

DIFF_TO_TARGET = {
    color = 1,
    color_abs = 1,
    ingredients_abs = 1,
    runes = { 1, 1, 1},
}
GAME_ENDED = false

TREND = 0

PLAYER_LEARNED = {
    how_to_fire = false,
    how_to_grab = false,
    how_to_shake = false,
    how_to_cw_for_brighter = false,
    how_to_ccw_for_darker = false,
}

FROG = nil

-- Stir speed is the speed of cranking in revolutions per seconds
STIR_SPEED = 0

-- Stir position is an angle in radians
STIR_POSITION = 0

STIR_DIRECTION = 0
STIR_REVOLUTION = 0
STIR_COUNT = 0

IS_GYRO_INITIALZIED = false
AVG_GRAVITY_X = 0
AVG_GRAVITY_Y = 0
AVG_GRAVITY_Z = 0

GRAVITY_X = 0
GRAVITY_Y = 0
GRAVITY_Z = 0

SHAKE_VAL = 0

-- Resource Management


function Init_gameplay()
    -- Done only once on start of the game, to load and setup const resources.

    playdate.startAccelerometer()

    FROG = Froggo()
    INGREDIENT_SPLASH = IngredientSplash()
end


function Stop_gameplay()
    -- Done on every game over/win to stop ongoing sounds and events.
    -- Not a complete tear down of resources.
end


function Reset_gameplay()
    -- Done on every (re)start of the play.

    GAME_ENDED = false
    GAMEPLAY_STATE.game_tick = 0
    GAMEPLAY_STATE.showing_cocktail = false
    GAMEPLAY_STATE.showing_instructions = false
    GAMEPLAY_STATE.showing_recipe = false
    GAMEPLAY_STATE.flame_amount = 0.0
    GAMEPLAY_STATE.heat_amount = 0.0
    GAMEPLAY_STATE.liquid_offset = 0.0
    GAMEPLAY_STATE.liquid_momentum = 0.0
    GAMEPLAY_STATE.liquid_viscosity = 0.9
    GAMEPLAY_STATE.potion_color = 0.5
    GAMEPLAY_STATE.potion_bubbliness = 0.0
    -- Reset current ingredient mix.
    for a = 1, NUM_RUNES, 1 do
        GAMEPLAY_STATE.rune_count[a] = 0
        GAMEPLAY_STATE.rune_ratio[a] = 0
    end
    CURRENT_RECIPE = {}
    RECIPE_TEXT = {}

    Calculate_goodness()

    Reset_ingredients()
    INGREDIENT_SPLASH:reset()
    FROG:reset()
    playdate.timer.new(1000, function ()
      FROG:Ask_for_cocktail()
    end)

    PLAYER_LEARNED.how_to_fire = false
    PLAYER_LEARNED.how_to_grab = false
    PLAYER_LEARNED.how_to_release = false
    PLAYER_LEARNED.how_to_shake = false
    PLAYER_LEARNED.how_to_cw_for_brighter = false
    PLAYER_LEARNED.how_to_ccw_for_darker = false

    -- Reset time delta
    playdate.resetElapsedTime()
end


function Update_rune_count(difference)
    local sum = 0
    for a = 1, NUM_RUNES, 1 do
        GAMEPLAY_STATE.rune_count[a] = GAMEPLAY_STATE.rune_count[a] * 0.9 + difference[a] * 0.1
        if GAMEPLAY_STATE.rune_count[a] < 0 then
            GAMEPLAY_STATE.rune_count[a] = 0
        end
        sum = sum + GAMEPLAY_STATE.rune_count[a]
    end
    if sum > 0 then
        for a = 1, NUM_RUNES, 1 do
            GAMEPLAY_STATE.rune_ratio[a] = GAMEPLAY_STATE.rune_count[a] / sum
        end
    end
    -- Trigger rune traveling animation
    if prev_rune_ratio ~= GAMEPLAY_STATE.rune_ratio then
        add_rune_travel_anim()
    end
    local prev_rune_ratio = GAMEPLAY_STATE.rune_ratio
end

win_text = ""

function Win_game()
    GAME_ENDED = true

    STIR_SPEED = 0 -- Stop liquid and stirring sounds.

    local new_high_score = false
    if not FROGS_FAVES.accomplishments[TARGET_COCKTAIL.name] then 
        new_high_score = true
        win_text = "RECIPE \nDONE!"
    elseif Score_of_recipe(CURRENT_RECIPE) < Score_of_recipe(FROGS_FAVES.recipes[TARGET_COCKTAIL.name]) then
        new_high_score = true
        win_text = "NEW \nHIGHSCORE!"
    else
        win_text = "GOOD \nENOUGH!"
    end
    if new_high_score then
        FROGS_FAVES.recipes[TARGET_COCKTAIL.name] = CURRENT_RECIPE
    end

    FROGS_FAVES.accomplishments[TARGET_COCKTAIL.name] = true
    Store_high_scores()
end

end_recipe_y = 0
local scroll_speed = 1.8

-- Update Loop
function Handle_input()

    -- When transitioning to end game, stop processing and reacting to new input.
    if GAME_ENDED then
        -- Put the hand off screen
        GYRO_X = -50
        GYRO_Y = -50

        -- Wait for recipe to show up before handling more input
        if GAMEPLAY_STATE.showing_recipe == true then
            local crankTicks = playdate.getCrankTicks(100)
            end_recipe_y += -crankTicks
            if playdate.buttonIsPressed( playdate.kButtonUp ) then
                end_recipe_y += scroll_speed * 2
            elseif playdate.buttonIsPressed( playdate.kButtonDown ) then
                end_recipe_y += -scroll_speed * 2
            end

            -- Cap scrollable range
            local line_height = 20
            local extra_lines = 3
            local recipe_scroll_range = #RECIPE_TEXT * line_height + (extra_lines * line_height) -- Line height from recipe_book.lua
            if end_recipe_y > 0 then
                end_recipe_y = 0
            elseif end_recipe_y < -recipe_scroll_range then
                end_recipe_y = -recipe_scroll_range
            end

            -- Back to menus
            if playdate.buttonJustReleased( playdate.kButtonB ) or
            playdate.buttonJustReleased( playdate.kButtonA ) then
                -- A few ticks timer so it doesn't overap with the mission menu controlls
                playdate.timer.new(5, function ()
                    enter_menu_mission(true)
                    remove_system_menu_entries()
                    Stop_gameplay()
                end)
            end
        end
    else
        check_gyro_and_gravity()

        -- Check the crank to update the stirring.
        check_crank_to_stir()

        -- Microphone level check.
        local mic_lvl = playdate.sound.micinput.getLevel()
        if mic_lvl > GAMEPLAY_STATE.flame_amount then
            GAMEPLAY_STATE.flame_amount = mic_lvl
        end

        -- Check for pressed buttons.
        if playdate.buttonJustPressed( playdate.kButtonA ) then
            GAMEPLAY_STATE.cursor_hold = true
            for i, ingredient in pairs(INGREDIENTS) do
                if ingredient.state == INGREDIENT_STATE.is_over_cauldron then
                    ingredient.state = INGREDIENT_STATE.is_in_air
                    ingredient:setZIndex(Z_DEPTH.ingredients)
                end
            end
            for i, ingredient in pairs(INGREDIENTS) do
                if ingredient:try_pickup() then
                    PLAYER_LEARNED.how_to_grab = true
                    break
                end
            end
            FROG:Click_the_frog()
        end
        if playdate.buttonJustReleased(playdate.kButtonA) then
            GAMEPLAY_STATE.cursor_hold = false
            for i, ingredient in pairs(INGREDIENTS) do
                if ingredient.state == INGREDIENT_STATE.is_picked_up then
                    ingredient:release()
                end
            end
        end

        if playdate.buttonIsPressed( playdate.kButtonB ) then
            FROG:Ask_the_frog()
        end

        -- Modal instruction overlays.
        if playdate.buttonJustPressed( playdate.kButtonLeft ) then
            GAMEPLAY_STATE.showing_cocktail = true
        elseif playdate.buttonJustReleased( playdate.kButtonLeft ) then
            GAMEPLAY_STATE.showing_cocktail = false
        end
        if playdate.buttonJustPressed( playdate.kButtonRight ) then
            GAMEPLAY_STATE.showing_instructions = true
        elseif playdate.buttonJustReleased( playdate.kButtonRight ) then
            GAMEPLAY_STATE.showing_instructions = false
        end
        if playdate.buttonJustPressed( playdate.kButtonDown ) then
            GAMEPLAY_STATE.showing_recipe = true
        elseif playdate.buttonJustReleased( playdate.kButtonDown ) then
            GAMEPLAY_STATE.showing_recipe = false
        end
    end
end


function check_gyro_and_gravity()
    -- Get values from gyro.
    local raw_gravity_x, raw_gravity_y, raw_gravity_z = playdate.readAccelerometer()
    -- Occasionally when simulator starts to upload the game to the actual
    -- device the gyro returns nil as results.
    if raw_gravity_x == nil then
        return
    end

    -- Calculate G's (length of acceleration vector)
    SHAKE_VAL = raw_gravity_x * raw_gravity_x + raw_gravity_y * raw_gravity_y + raw_gravity_z * raw_gravity_z

    if IS_GYRO_INITIALZIED == false then
        -- For the initial vlaue use the gyro at the start of the game, so that
        -- it calibrates as quickly as possible to the current device orientation.
        AVG_GRAVITY_X = raw_gravity_x
        AVG_GRAVITY_Y = raw_gravity_y
        AVG_GRAVITY_Z = raw_gravity_z
        IS_GYRO_INITIALZIED = true
    else
        -- Exponential moving average:
        --   https://en.wikipedia.org/wiki/Exponential_smoothing
        --
        -- The weight from the number of samples can be estimated as `2 / (n + 1)`.
        -- See the Relationship between SMA and EMA section of the
        --   https://en.wikipedia.org/wiki/Moving_average
        local num_smooth_samples = 120
        local alpha = 2 / (num_smooth_samples + 1)

        AVG_GRAVITY_X = alpha * raw_gravity_x + (1 - alpha) * AVG_GRAVITY_X
        AVG_GRAVITY_Y = alpha * raw_gravity_y + (1 - alpha) * AVG_GRAVITY_Y
        AVG_GRAVITY_Z = alpha * raw_gravity_z + (1 - alpha) * AVG_GRAVITY_Z

        local len = math.sqrt(AVG_GRAVITY_X*AVG_GRAVITY_X + AVG_GRAVITY_Y*AVG_GRAVITY_Y + AVG_GRAVITY_Z*AVG_GRAVITY_Z)
        AVG_GRAVITY_X /= len
        AVG_GRAVITY_Y /= len
        AVG_GRAVITY_Z /= len
    end

    local v1 = vec2d.new(0, 1)
    local v2 = vec2d.new(AVG_GRAVITY_Y, AVG_GRAVITY_Z)
    local angle = v2:angleBetween(v1) / 180 * math.pi

    local co = math.cos(angle)
    local si = math.sin(angle)

    GRAVITY_X = raw_gravity_x

    GRAVITY_Y = raw_gravity_y*co - raw_gravity_z*si
    GRAVITY_Z = raw_gravity_y*si + raw_gravity_z*co

    local axis_sign = 0
    if raw_gravity_z < 0 then
        axis_sign = -1
    else
        axis_sign = 1
    end

    local gyroSpeed = 60
    if SHAKE_VAL < 1.1 then
        PREV_GYRO_X = GYRO_X
        PREV_GYRO_Y = GYRO_Y
        GYRO_X = Clamp(GYRO_X + GRAVITY_X * gyroSpeed * axis_sign, 0, 400)
        GYRO_Y = Clamp(GYRO_Y + GRAVITY_Y * gyroSpeed, 0, 240)
    end
end


function check_crank_to_stir()
    -- Track crank changes
    local prev_stir_position = STIR_POSITION
    local prev_stir_direction = STIR_DIRECTION

    -- Crank stirring
    local angleDelta, acceleratedChange = playdate.getCrankChange()
    STIR_SPEED = acceleratedChange
    -- Use the absolute position of the crank to drive the stick in the cauldorn
    STIR_POSITION = math.rad(playdate.getCrankPosition())

    -- Count crank revolutions
    if math.abs(STIR_SPEED) > 1 then
        STIR_DIRECTION = Sign(STIR_SPEED)
    end
    if Sign(prev_stir_direction) * Sign(STIR_DIRECTION) < 0 or prev_stir_direction == 0 then
        STIR_REVOLUTION = 0
        STIR_COUNT = 0
    else
        local delta_stir = math.abs(STIR_POSITION - prev_stir_position) / (math.pi * 2)
        if delta_stir > 0.5 then
            delta_stir = 1 - delta_stir
        end
        STIR_REVOLUTION += delta_stir
        if STIR_REVOLUTION - STIR_COUNT > 0.2 then
            STIR_COUNT += 1
            if STIR_DIRECTION > 0 then
                CURRENT_RECIPE[#CURRENT_RECIPE+1] = -1
            else
                CURRENT_RECIPE[#CURRENT_RECIPE+1] = -2
            end
            Recipe_update_current()
        end
    end

    if math.abs(STIR_SPEED) > 3 then
        if not SOUND.stir_sound:isPlaying() then
            SOUND.stir_sound:play()

            -- Stop the sound with a bit of delay when stirring stops.
            -- There is one timer to count a delay of time after stopping stirring.
            delay_to_stop_timer = playdate.timer.new(0.4 * 1000)
            -- There is a second timer that ticks a function while the sound plays.
            sfx_dur = SOUND.stir_sound:getLength() * 1000
            sound_effect_timer = playdate.timer.new(sfx_dur)
            sound_effect_timer.updateCallback = function()
                -- If the player is still cranking, reset the delay count after stopping to stir,
                -- because stirring hasn't stopped yet.
                if math.abs(STIR_SPEED) > 0 then
                    delay_to_stop_timer:reset()
                end
                -- After the time without stirring, stop the stirring sound.
                if delay_to_stop_timer.timeLeft == 0 and SOUND.stir_sound:isPlaying() then
                    SOUND.stir_sound:stop()
                    sound_effect_timer.active = false
                end
            end
        end
    end
end


function Tick_gameplay()
    GAMEPLAY_STATE.game_tick += 1
    local crankTicks = playdate.getCrankTicks(1) --Not really used, but resets the ticks before going back to start menu

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

    update_fire()
    update_liquid()

    FROG:animation_tick()
end

-- The amount of time before the next blow sound can play
local blow_sound_timer = playdate.timer.new(0.5 * 1000, 0, 1)

function update_fire()
    if GAMEPLAY_STATE.flame_amount > 0.01 then
        local flame_decay = 0.99
        GAMEPLAY_STATE.flame_amount *= flame_decay

        if (GAMEPLAY_STATE.flame_amount > 0.8) then
            if not SOUND.fire_blow:isPlaying() or blow_sound_timer.value == 1 then
                SOUND.fire_blow:playAt(1)
                blow_sound_timer:remove()
                blow_sound_timer = playdate.timer.new(1.5 * 1000, 0, 1)
                    if GAMEPLAY_STATE.heat_amount < 0.2 then
                        FROG:fire_reaction()
                    end
            end
        end

    else
        if SOUND.fire_blow:isPlaying() then
            SOUND.fire_blow:stop()
        end
        GAMEPLAY_STATE.flame_amount = 0
    end

    if GAMEPLAY_STATE.heat_amount > GAMEPLAY_STATE.flame_amount then
        -- Slowly decay the heat
        GAMEPLAY_STATE.heat_amount -= 0.0007
    else
        -- The flame heats up the cauldron
        GAMEPLAY_STATE.heat_amount += 0.01 * GAMEPLAY_STATE.flame_amount
    end
    if GAMEPLAY_STATE.heat_amount > 0.1 then
        if not SOUND.fire_burn:isPlaying() then
            SOUND.fire_burn:play()
        end
    else
        if SOUND.fire_burn:isPlaying() then
            SOUND.fire_burn:stop()
        end
    end
end


function update_liquid()
    -- Update liquid color
    local color_change = 0.0005
    GAMEPLAY_STATE.potion_color = GAMEPLAY_STATE.potion_color + color_change * STIR_SPEED
    if GAMEPLAY_STATE.potion_color < 0 then
        GAMEPLAY_STATE.potion_color = 0
    elseif GAMEPLAY_STATE.potion_color > 1 then
        GAMEPLAY_STATE.potion_color = 1
    end

    -- Update liquid state
    GAMEPLAY_STATE.liquid_momentum += Clamp(STIR_SPEED, -8, 8) / 10
    GAMEPLAY_STATE.liquid_offset += GAMEPLAY_STATE.liquid_momentum
    GAMEPLAY_STATE.liquid_momentum *= GAMEPLAY_STATE.liquid_viscosity
    if math.abs(GAMEPLAY_STATE.liquid_momentum) < 1e-4 then
        GAMEPLAY_STATE.liquid_momentum = 0
    end
end


local tolerance = 0.1

function Are_ingredients_good_enough()
    return DIFF_TO_TARGET.ingredients_abs < tolerance
end

function Is_color_good_enough()
    return DIFF_TO_TARGET.color_abs < tolerance
end

function Is_potion_good_enough()
    return Are_ingredients_good_enough() and Is_color_good_enough()
end

function Calculate_goodness()
    local prev_diff = {}
    if DIFF_TO_TARGET ~= nil then
        for k, v in pairs(DIFF_TO_TARGET) do
            prev_diff[k] = v
        end
    end

    local prev_trend = TREND

    -- Match expectations with reality.
    DIFF_TO_TARGET.color = TARGET_COCKTAIL.color - GAMEPLAY_STATE.potion_color
    DIFF_TO_TARGET.color_abs = math.abs(DIFF_TO_TARGET.color)

    local runes_diff = {
        TARGET_COCKTAIL.rune_ratio[1] - GAMEPLAY_STATE.rune_ratio[1],
        TARGET_COCKTAIL.rune_ratio[2] - GAMEPLAY_STATE.rune_ratio[2],
        TARGET_COCKTAIL.rune_ratio[3] - GAMEPLAY_STATE.rune_ratio[3],
    }
    DIFF_TO_TARGET.ingredients_abs = (
        math.abs(runes_diff[1]) + math.abs(runes_diff[2]) + math.abs(runes_diff[3])
    ) * 0.5
    DIFF_TO_TARGET.runes = runes_diff

    -- calculate state change
    local diff_change_color = DIFF_TO_TARGET.color_abs - prev_diff.color_abs
    local diff_change_runes = DIFF_TO_TARGET.ingredients_abs - prev_diff.ingredients_abs
    if math.abs(diff_change_color) <= 0.001 then
        diff_change_color = 0
    end

    local diff_change_overall = diff_change_color + diff_change_runes

    local color_trend = -Sign(diff_change_color)
    local rune_trend = -Sign(diff_change_runes)

    local new_trend = color_trend + rune_trend
    if new_trend ~= 0 then
        TREND = new_trend
    end

    if math.abs(TREND - prev_trend) == 2 then
        FROG:Notify_the_frog()
    elseif math.abs(diff_change_overall) > 0.01 then
        FROG:Notify_the_frog()
    end

    -- print(prev_diff.color, DIFF_TO_TARGET.color, DIFF_TO_TARGET.color - prev_diff.color)
end


function Check_player_learnings()
    if GAMEPLAY_STATE.heat_amount > 0.3 then
        PLAYER_LEARNED.how_to_fire = true
    end

    if STIR_SPEED > 7.5 then
        PLAYER_LEARNED.how_to_cw_for_brighter = true
    elseif STIR_SPEED < -7.5 then
        PLAYER_LEARNED.how_to_ccw_for_darker = true
    end
end
