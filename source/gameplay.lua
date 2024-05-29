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
    -- Current potion mix
    potion_color = 0.5,
    potion_bubbliness = 0.0,
    rune_count = {0, 0, 0},
    rune_count_unstirred = {0, 0, 0},
    dropped_ingredients = 0,
    -- ??
    game_tick = 0,
    -- The cursor is held down
    cursor_hold = false,
    used_ingredients_table = {
        false, -- peppermints
        false, -- perfume
        false, -- mushrooms
        false, -- coffee
        false, -- toenails
        false, -- salt
        false, -- garlic
        false, -- spiderweb
        false, -- snail_shells
    },
    used_ingredients = 0
}

CURRENT_RECIPE = {}

DIFF_TO_TARGET = {
    color = 1,
    color_abs = 1,
    ingredients_abs = 1,
    runes = { 1, 1, 1},
    runes_abs = { 1, 1, 1},
}
GOAL_TOLERANCE = 0.1
GAME_ENDED = false

TREND = 0
PREV_RUNE_COUNT = {0, 0, 0}
CHECK_IF_DELICIOUS = false

PLAYER_LEARNED = {
    how_to_fire = false,
    how_to_grab = false,
    how_to_shake = false,
    how_to_stir = false,
    complete = false,
}

PLAYER_STRUGGLES = {
    no_fire = false,
    too_much_fire = false,
    no_shake = false,
    too_much_shaking = false,
    no_stir = false,
    too_much_stir = false,
    recipe_struggle = false,
    recipe_struggle_lvl = 0,
    fire_struggle_asked = 0,
    ingredient_struggle_asked = 0,
}

-- The recipe steps that trigger a gameplay tip from the frog
RECIPE_STRUGGLE_STEPS = nil

FROG = nil

-- Stir speed is the speed of cranking in revolutions per seconds
STIR_SPEED = 0
-- Effect stirring has on the potion
STIR_FACTOR = 0

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
IS_SIMULATING_SHAKE = false -- Simulator only control to mimic shaking the playdate.

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
    GAMEPLAY_STATE.potion_color = 0.0
    GAMEPLAY_STATE.potion_bubbliness = 0.0
    -- Reset current ingredient mix.
    for a = 1, NUM_RUNES, 1 do
        GAMEPLAY_STATE.rune_count[a] = 0
        GAMEPLAY_STATE.rune_count_unstirred[a] = 0
    end
    for k, v in pairs(GAMEPLAY_STATE.used_ingredients_table) do
        GAMEPLAY_STATE.used_ingredients_table[k] = false
    end
    used_ingredients = 0
    GAMEPLAY_STATE.dropped_ingredients = 0
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
    PLAYER_LEARNED.how_to_stir = false
    PLAYER_LEARNED.complete = false

    PLAYER_STRUGGLES.no_fire = false
    PLAYER_STRUGGLES.too_much_fire = false
    PLAYER_STRUGGLES.no_shake = false
    PLAYER_STRUGGLES.too_much_shaking = false
    PLAYER_STRUGGLES.no_stir = false
    PLAYER_STRUGGLES.too_much_stir = false
    PLAYER_STRUGGLES.recipe_struggle = false
    PLAYER_STRUGGLES.recipe_struggle_lvl = 0
    PLAYER_STRUGGLES.cocktail_struggle = false
    PLAYER_STRUGGLES.fire_struggle_asked = 0
    PLAYER_STRUGGLES.ingredient_struggle_asked = 0

    -- Variables for detecting player struggle
    CAULDRON_INGREDIENT = nil
    LAST_CAULDRON_INGREDIENT = nil
    LAST_SHAKEN_INGREDIENT = nil
    CALUDRON_SWAP_COUNT = 0

    STIR_FACTOR = 1 -- sink and despawn all drops


    -- Reset time delta
    playdate.resetElapsedTime()

    -- Reset highscore recipe scroll
    end_recipe_y = 0
end

function Update_rune_count(drop_rune_count)

    -- Calculate new rune count
    for a = 1, NUM_RUNES, 1 do
        GAMEPLAY_STATE.rune_count[a] = GAMEPLAY_STATE.rune_count[a] + (drop_rune_count[a] * 0.3)
        if GAMEPLAY_STATE.rune_count[a] < 0 then
            GAMEPLAY_STATE.rune_count[a] = 0
        end
    end

      -- Cap rune count
      for a = 1, NUM_RUNES, 1 do
        if GAMEPLAY_STATE.rune_count[a] > 1 then
            GAMEPLAY_STATE.rune_count[a] = 1
        end
    end

    -- Update variables
    GAMEPLAY_STATE.dropped_ingredients += 1
    -- Adjust stir factor relative to new count of drops
    local drops = GAMEPLAY_STATE.dropped_ingredients
    STIR_FACTOR = (STIR_FACTOR / drops) * (drops - 1)


    local prev_rune_avg = (PREV_RUNE_COUNT[1] + PREV_RUNE_COUNT[2] + PREV_RUNE_COUNT[3]) /3
    local current_rune_avg = (GAMEPLAY_STATE.rune_count[1] + GAMEPLAY_STATE.rune_count[2] + GAMEPLAY_STATE.rune_count[3]) / 3

    PREV_RUNE_COUNT = table.shallowcopy(GAMEPLAY_STATE.rune_count)

    --print("Rune Count = " .. tostring(GAMEPLAY_STATE.rune_count[1] .. ", " .. tostring(GAMEPLAY_STATE.rune_count[2]) .. ", " .. tostring(GAMEPLAY_STATE.rune_count[3])))
end

win_text = ""

function Win_game()
    GAME_ENDED = true

    STIR_SPEED = 0 -- Stop liquid and stirring sounds.
    STIR_FACTOR = 1 -- sink and despawn all drops

    local new_high_score = false
    if not FROGS_FAVES.accomplishments[TARGET_COCKTAIL.name] then 
        new_high_score = true
        win_text = "RECIPE\nDONE!"
    elseif Score_of_recipe(CURRENT_RECIPE) < Score_of_recipe(FROGS_FAVES.recipes[TARGET_COCKTAIL.name]) then
        new_high_score = true
        win_text = "RECIPE\nIMPROVED!"
    else
        win_text = "GOOD\nENOUGH!"
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
            local line_height = 23
            local extra_lines = 4
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
            local picked_up = false
            GAMEPLAY_STATE.cursor_hold = true
            for i, ingredient in pairs(INGREDIENTS) do
                if ingredient:try_pickup() then
                    picked_up = true
                    if not PLAYER_LEARNED.how_to_grab then
                        PLAYER_LEARNED.how_to_grab = true
                        FROG:flash_b_prompt()
                        print('Learned how to grab.')
                    end
                    break
                end
            end
            for i, ingredient in pairs(INGREDIENTS) do
                if ingredient.state == INGREDIENT_STATE.is_over_cauldron and picked_up then
                    ingredient.state = INGREDIENT_STATE.is_in_air
                    ingredient:setZIndex(Z_DEPTH.ingredients)
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
            FROG:Click_the_frog()
        end

        if playdate.buttonJustReleased( playdate.kButtonB ) then
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
    end
end


-- When playing on the simulator, allow the keyboard to override the Gyro and mic.
function playdate.keyPressed(key)
    -- Note: do not use keys that the simulator might use.
    -- No: arrows, WASD, B, space, esc, [, ], ., , =, -, or OEV for Dvorak.
    -- Check Simulator>Controls and https://help.play.date/manual/simulator/#keyboard-shortcuts

    -- Alternative Gyro: shake in ingredients.
    if key == 'm' then
        IS_SIMULATING_SHAKE = true
    -- Alternative Gyro: arrow like controls to position the cursor hand.
    elseif key == 'j' then
      GYRO_X -= 15
    elseif key == 'l' then
      GYRO_X += 15
    elseif key == 'i' then
      GYRO_Y -= 15
    elseif key == 'k' then
      GYRO_Y += 15
    end
end

function playdate.keyReleased(key)
    -- Microphone alternative for Fire.
    if key == 'f' then
        GAMEPLAY_STATE.flame_amount = math.min(1.0, GAMEPLAY_STATE.flame_amount + 0.2)
    -- Alternative Gyro: shake in ingredients
    elseif key == 'm' then
        IS_SIMULATING_SHAKE = false
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
            CURRENT_RECIPE[#CURRENT_RECIPE+1] = -1
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
        GAMEPLAY_STATE.heat_amount -= 0.0004
    else
        -- The flame heats up the cauldron
        GAMEPLAY_STATE.heat_amount += 0.015 * GAMEPLAY_STATE.flame_amount
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

local liquid_darkening = 0

function update_liquid()
    -- Update liquid color & stir effect


    local stir_change = 0.001
    local floating_drops = GAMEPLAY_STATE.dropped_ingredients
    local color_change = 0.005
    local max_darkness = 0.2 * floating_drops

    max_darkness = math.min(max_darkness, 1)

    -- Calculate current base color of liquid
    if floating_drops > 0 then
        liquid_darkening += color_change * floating_drops
        STIR_FACTOR += STIR_FACTOR * 0.002
        STIR_FACTOR = math.min(STIR_FACTOR, 1)
    elseif floating_drops == 0 then --tmp this could be simplified
        liquid_darkening = 0
        STIR_FACTOR = 0
    end
    liquid_darkening = Clamp(liquid_darkening, 0, max_darkness)
    -- Calculate current stirring effect
    STIR_FACTOR += (math.abs(STIR_SPEED) * stir_change)
    STIR_FACTOR = Clamp(STIR_FACTOR, 0, 1)

    -- Reset rune travel variables
    if STIR_FACTOR >= 1 then
        table.shallowcopy(GAMEPLAY_STATE.rune_count, GAMEPLAY_STATE.rune_count_unstirred)
        GAMEPLAY_STATE.dropped_ingredients = 0
        CHECK_IF_DELICIOUS = true
    end

    -- Total mixed color of liquid
    --GAMEPLAY_STATE.potion_color = (1 - liquid_darkening) + (STIR_FACTOR * max_darkness)
    -- print(STIR_FACTOR)

    -- Update liquid state
    GAMEPLAY_STATE.liquid_momentum += Clamp(STIR_SPEED, -8, 8) / 10
    GAMEPLAY_STATE.liquid_offset += GAMEPLAY_STATE.liquid_momentum
    GAMEPLAY_STATE.liquid_momentum *= 0.9 -- viscosity factor
    if math.abs(GAMEPLAY_STATE.liquid_momentum) < 1e-4 then
        GAMEPLAY_STATE.liquid_momentum = 0
    end
end


function Are_ingredients_good_enough()
    for i=1, NUM_RUNES do
        if DIFF_TO_TARGET.runes_abs[i] > GOAL_TOLERANCE then
            return false
        end
    end
    if GAMEPLAY_STATE.dropped_ingredients > 0 then
        return false
    else
        return true
    end
end

function Is_potion_good_enough()
    return Are_ingredients_good_enough()
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
        TARGET_COCKTAIL.rune_count[1] - GAMEPLAY_STATE.rune_count[1],
        TARGET_COCKTAIL.rune_count[2] - GAMEPLAY_STATE.rune_count[2],
        TARGET_COCKTAIL.rune_count[3] - GAMEPLAY_STATE.rune_count[3],
    }
    DIFF_TO_TARGET.runes = runes_diff
    DIFF_TO_TARGET.runes_abs = { math.abs(runes_diff[1]), math.abs(runes_diff[2]), math.abs(runes_diff[3]) }

    DIFF_TO_TARGET.ingredients_abs = DIFF_TO_TARGET.runes_abs[1] + DIFF_TO_TARGET.runes_abs[2] + DIFF_TO_TARGET.runes_abs[3]

    -- calculate state change
    local diff_change_runes = DIFF_TO_TARGET.ingredients_abs - prev_diff.ingredients_abs
    local diff_change_overall = diff_change_runes
    local rune_trend = -Sign(diff_change_runes)

    local new_trend = rune_trend
    if new_trend ~= 0 then
        TREND = new_trend
    end

    if math.abs(TREND - prev_trend) == 2
    and not RECIPE_STRUGGLE_STEPS
    and PLAYER_LEARNED.complete then
        FROG:Notify_the_frog()
    elseif math.abs(diff_change_overall) > 0.01
    and not RECIPE_STRUGGLE_STEPS
    and PLAYER_LEARNED.complete then
        FROG:Notify_the_frog()
    elseif CHECK_IF_DELICIOUS then
        FROG:Lick_eyeballs()
    end

    -- print(prev_diff.color, DIFF_TO_TARGET.color, DIFF_TO_TARGET.color - prev_diff.color)
end


function Check_player_learnings()
    if GAMEPLAY_STATE.heat_amount > 0.3 and not PLAYER_LEARNED.how_to_fire then
        PLAYER_LEARNED.how_to_fire = true
        FROG:flash_b_prompt()
    end

    if math.abs(STIR_SPEED) > 7.5
    and GAMEPLAY_STATE.dropped_ingredients > 0
    and not PLAYER_LEARNED.how_to_stir then
        PLAYER_LEARNED.how_to_stir = true
        FROG:flash_b_prompt()
    end
end

-- Values to detect struggle
local min_drops_without_stirring = 6
local excess_stirring_factor = 0.008

-- Timout values and timers fore stopping struggle dialogue
local struggle_reminder_timout = 10*1000
local no_fire_tracking = 0
local too_much_fire_tracking = 0
local no_shake_timeout = nil
local no_stir_timeout = nil
local no_shake_tracking = 0
local too_much_stir_tracking = 0
local too_much_stir_timeout = nil

function Check_player_struggle()

    -- Only once tutorial is complete
    if not PLAYER_LEARNED.complete then
        return
    end

    -- No Fire
    if not PLAYER_STRUGGLES.no_fire then
        Check_no_fire_struggle()
    end

    -- Too much fire
    if not PLAYER_STRUGGLES.too_much_fire then
        Check_too_much_fire_struggle()
    end

    -- No shaking
    if not Cauldron_ingredient_was_shaken() then
        Check_no_shaking_struggle()
    end

    -- No stirring
    if GAMEPLAY_STATE.dropped_ingredients >= min_drops_without_stirring then
        Check_no_stirring_struggle()
    end

    -- Too much stirring
    if Cauldron_ingredient_was_shaken() then
        Check_too_much_stirring_struggle()
    end

    -- Coktail struggle
    if GAMEPLAY_STATE.used_ingredients > 5 and not PLAYER_STRUGGLES.cocktail_struggle then
        print("Player used too many ingredient types.")
        PLAYER_STRUGGLES.cocktail_struggle = true
        -- Reset tracked used ingredients
        GAMEPLAY_STATE.used_ingredients = 0
        for k, v in pairs(GAMEPLAY_STATE.used_ingredients_table) do
            GAMEPLAY_STATE.used_ingredients_table[k] = false
        end
        -- Timeout to stop cocktail hint dialogue
        cocktail_struggle_timeout = playdate.timer.new(struggle_reminder_timout, function ()
            PLAYER_STRUGGLES.cocktail_struggle = false
            end)
        FROG:Ask_the_frog()
    end

    -- Recipe struggle
    if not PLAYER_STRUGGLES.recipe_struggle and
    (RECIPE_STRUGGLE_STEPS == true or PLAYER_STRUGGLES.ingredient_struggle_asked >= 4) then
        PLAYER_STRUGGLES.recipe_struggle = true
        Next_recipe_struggle_tip()
        FROG:flash_b_prompt()
    elseif not RECIPE_STRUGGLE_STEPS then
        if PLAYER_STRUGGLES.recipe_struggle then
            PLAYER_STRUGGLES.recipe_struggle = false
        end
    end
end

function Check_no_fire_struggle()
    if GAMEPLAY_STATE.heat_amount < 0.1 then
        no_fire_tracking += 0.0006
    else
        no_fire_tracking = 0
    end
    if no_fire_tracking >= 1 or
    PLAYER_STRUGGLES.fire_struggle_asked >= 4 then
        print("Fire is never used or player forgot how!")
        PLAYER_STRUGGLES.no_fire = true
        FROG:flash_b_prompt()
        no_shake_timeout = playdate.timer.new(struggle_reminder_timout, function ()
            PLAYER_STRUGGLES.no_fire = false
            end)
    end
    --print("No fire tracking: " .. no_fire_tracking)
end


function Check_too_much_fire_struggle()
    if GAMEPLAY_STATE.flame_amount > 0.3 then
        too_much_fire_tracking += 0.003
    else
        too_much_fire_tracking -= 0.001
        PLAYER_STRUGGLES.too_much_fire = false
    end
    if too_much_fire_tracking >= 1 then
        print("Fire is stroked way too much!")
        PLAYER_STRUGGLES.too_much_fire = true
        FROG:flash_b_prompt()
        no_shake_timeout = playdate.timer.new(struggle_reminder_timout, function ()
            PLAYER_STRUGGLES.too_much_fire = false
            end)
    end
    --print("Too much fire tracker: " .. too_much_fire_tracking)
end


function Check_no_shaking_struggle()
    -- Check if the ingredient was swapped many times without shaking
    if CALUDRON_SWAP_COUNT > 3 and not PLAYER_STRUGGLES.no_shake then
        print("Swapped ingredients too much without shaking")
        PLAYER_STRUGGLES.no_shake = true
        FROG:flash_b_prompt()
        no_shake_timeout = playdate.timer.new(struggle_reminder_timout, function ()
            PLAYER_STRUGGLES.no_shake = false
            end)
            CALUDRON_SWAP_COUNT = 0
    elseif not PLAYER_STRUGGLES.no_shake then
        if GAMEPLAY_STATE.dropped_ingredients == 0 and math.abs(STIR_SPEED) > 7.5 then
            -- Start tracking stirring
            no_shake_tracking += excess_stirring_factor
            if no_shake_tracking > 1 then
                --print("Stirring reached struggling amount.")
                print("Too much stirring without shaking")
                PLAYER_STRUGGLES.no_shake = true
                FROG:flash_b_prompt()
                no_shake_timeout = playdate.timer.new(struggle_reminder_timout, function ()
                    PLAYER_STRUGGLES.no_shake = false
                    end)
                no_shake_tracking = 0
            end
        elseif GAMEPLAY_STATE.dropped_ingredients > 0 then
            -- New ingredients dropped in. Reset tracked stirring and timeout
            no_shake_tracking = 0
            PLAYER_STRUGGLES.no_shake = false
            print("Shaking struggle canceled")
            if no_shake_timeout ~= nil then
                no_shake_timeout:remove()
            end
        end
    end
    --print("No shake tracking: " .. no_shake_tracking)
end

function Check_no_stirring_struggle()
    if  STIR_FACTOR < 0.3 and not PLAYER_STRUGGLES.too_much_shaking then
        print("Player is struggling with stir")
        PLAYER_STRUGGLES.too_much_shaking = true
        FROG:flash_b_prompt()
        no_stir_timeout = playdate.timer.new(struggle_reminder_timout, function ()
            PLAYER_STRUGGLES.too_much_shaking = false
          end)
    elseif STIR_FACTOR > 0.3 and PLAYER_STRUGGLES.no_stir then
        --print("Player struggle with stir resolved")
        PLAYER_STRUGGLES.too_much_shaking = false
        if no_stir_timeout ~= nil then
            no_stir_timeout:remove()
        end
    end
end

function Cauldron_ingredient_was_shaken()
    -- Check if ingredient has been shaken and same ingredient is still on cauldron
    if LAST_CAULDRON_INGREDIENT == nil and LAST_SHAKEN_INGREDIENT == nil then
        return false
    elseif LAST_CAULDRON_INGREDIENT == LAST_SHAKEN_INGREDIENT then
        return true
    else
        return false
    end
end

function Check_too_much_stirring_struggle()
    if GAMEPLAY_STATE.dropped_ingredients == 0 and math.abs(STIR_SPEED) > 7.5 then
        -- Start tracking stirring
        too_much_stir_tracking += excess_stirring_factor
        if too_much_stir_tracking > 1 then
            --print("Stirring reached struggling amount.")
            PLAYER_STRUGGLES.too_much_stir = true
            FROG:flash_b_prompt()
            too_much_stir_timeout = playdate.timer.new(struggle_reminder_timout, function ()
                PLAYER_STRUGGLES.too_much_stir = false
                end)
                too_much_stir_tracking = 0
        end
    elseif GAMEPLAY_STATE.dropped_ingredients > 0 then
        -- New ingredients dropped in. Reset tracked stirring and timeout
        too_much_stir_tracking = 0
        PLAYER_STRUGGLES.too_much_stir = false
        if too_much_stir_timeout ~= nil then
            too_much_stir_timeout:remove()
        end
    end
    --print("Too much stir tracking: " .. too_much_stir_tracking)
end

function Next_recipe_struggle_tip()
    local lines = 5 -- Same as recipe_struggle table
    -- Trigger frog hint line
    PLAYER_STRUGGLES.recipe_struggle_lvl = math.fmod(PLAYER_STRUGGLES.recipe_struggle_lvl + 1, lines)
    if PLAYER_STRUGGLES.recipe_struggle_lvl == 0 then
        PLAYER_STRUGGLES.recipe_struggle_lvl = lines
    end
    print("Giving gameplay hint Nr. " .. PLAYER_STRUGGLES.recipe_struggle_lvl)
    FROG:Ask_the_frog()

end