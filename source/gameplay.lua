local point <const> = playdate.geometry.point
local vec2d <const> = playdate.geometry.vector2D

NUM_RUNES = 3
RUNES = { love = 1, doom = 2, weed = 3 }
DIR = { need_more_of = 1, need_less_of = 2 }

GAMEPLAY_STATE = {
    -- User modal interation
    showing_cocktail = false,
    showing_instructions = false,
    instructions_prompt_expanded = false,
    instructions_offset_x = -10,
    instructions_offset_y = 275,
    showing_recipe = false,
    cursor_hold = false,  -- The gyro hand cursor is held down.
    cursor_pos = point.new(200, 120),
    -- Fire!
    flame_amount = 0.0,
    heat_amount = 0.0,
    -- Keeping track of fire over-use
    fire_stoke_count = 0,
    start_counting_blows = true,
    -- Liquid fluid simulation.
    liquid_offset = 0.0,
    liquid_momentum = 0.0,
    -- Current potion mix
    potion_bubbliness = 0.0,
    rune_count = {0, 0, 0},
    rune_count_unstirred = {0, 0, 0},
    -- To check which directions runes would travel in. Reset regularly when ingredients are stirred in
    rune_count_unclamped = {0, 0, 0},
    held_ingredient = 0, -- index of currently helf ingredient
    dropped_ingredients = 0,
    counting_stirs = false,
    stirring_complete = false,
    puff_anim_started = false, -- specific for the anim when stirring is complete
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
    used_ingredients = 0,
    -- Variables for primarily detecting player struggle
    cauldron_ingredient = nil,
    last_cauldron_ingredient = nil,
    last_shaken_ingredient = nil,
    cauldron_swap_count = 0,
    asked_frog_count = 0,
    -- If new stickers were unlocked after beating the cocktail
    cocktail_learned = false,
    new_high_score = false,
    new_mastered = false,
    -- DEPRECATED - this 'tick' is used for progressing animations, but it should be removed
    -- as it makes animations framerate dependent.
    game_tick = 0,
}

CURRENT_RECIPE = {}

DIFF_TO_TARGET = {
    ingredients_abs = 1,
    runes = { 1, 1, 1},
    runes_trend = { 0, 0, 0},
    runes_abs = { 1, 1, 1},
    runes_abs_prev = { 1, 1, 1},
}
GOAL_TOLERANCE = 0.1
GAME_ENDED = false

-- Minimum number of frog interactions before no longer automated
FROG_AUTOMATED = 3

-- Trend on the current tick
TREND = 0
-- If a positive reinforcement can be triggered
CAN_REINFORCE = false
PREV_RUNE_COUNT = {0, 0, 0}
-- fog will check again if win conditions are correct
CHECK_IF_DELICIOUS = false

PLAYER_LEARNED = {
    how_to_fire = false,
    how_to_grab = false,
    how_to_shake = false,
    how_to_stir = false,
}

TUTORIAL_COMPLETED = false

PLAYER_STRUGGLES = {
    -- Turns true when struggle is detected
    no_fire = false,
    too_much_fire = false,
    no_shake = false,
    too_much_shaking = false,
    too_much_stir = false,
    recipe_struggle = false,
}

STRUGGLE_PROGRESS = {
    -- Current line in pool of recipe struggle hints
    recipe_struggle_lvl = 0,
    -- Track how often struggle hints have been read
    fire_struggle_asked = 0,
    ingredient_struggle_asked = 0,
    struggle_hint_asked = 0,
    recipe_hint_asked = 0,
    -- Live values to detect struggle
    no_fire_tracking = 0,
    too_much_fire_tracking = 0,
    too_little_fire_tracking = 0,
    no_shake_tracking = 0,
    too_much_stir_tracking = 0,
    too_much_shaking_tracking = 0,
}

-- The recipe steps that trigger a gameplay tip from the frog
RECIPE_STRUGGLE_STEPS = nil

-- Constants to detect struggle
local min_drops_without_stirring <const> = 6
local excess_stirring_factor <const> = 0.008
local struggle_reminder_timout <const> = 7*1000


-- Frog entity.
FROG = nil

-- Various timers that are running during gameplay
GAMEPLAY_TIMERS = {
    instructions_expanded = playdate.timer.new(100, function ()
        GAMEPLAY_STATE.instructions_prompt_expanded = false
        end),
    stop_b_flashing = playdate.timer.new(100, function ()
        ANIMATIONS.b_prompt.frame = 1
        ANIMATIONS.b_prompt.paused = true
        end),
    talk_reminder = playdate.timer.new(100, function()
        local automated = true
        FROG:Ask_the_frog(automated)
        FROG:flash_b_prompt(6*1000)
        Restart_timer(GAMEPLAY_TIMERS.talk_reminder, 20*1000)
        end),
    speech_timer = playdate.timer.new(100, function()
        FROG:stop_speech_bubble()
        CHECK_IF_DELICIOUS = true
        end),
    frog_go_idle = playdate.timer.new(100, function()
        FROG:go_idle()
        -- Check if the potion is still good. If yes, start eyeball lick anim
        CHECK_IF_DELICIOUS = true
        FROG:Lick_eyeballs()
        end),
    frog_go_urgent = playdate.timer.new(100, function()
        FROG:start_animation(FROG.anim_urgent)
        Restart_timer(GAMEPLAY_TIMERS.frog_go_idle, 6*1000)
        end),
    thought_bubble_anim = playdate.timer.new(100, function()
        THOUGHT_BUBBLE_ANIM = ANIMATIONS.thought_bubble
        ANIMATIONS.thought_bubble.frame = 1
        end),
    burp_anim = playdate.timer.new(100, function()
        FROG:start_animation(FROG.anim_burptalk)
        FROG.x_offset = -9
        FROG:start_speech_bubble()
        end),
    burptalk_anim = playdate.timer.new(100, function()
        FROG:stop_speech_bubble()
        FROG:start_animation(FROG.anim_drink)
        FROG.x_offset = -9
        GAMEPLAY_STATE.showing_recipe = true
        end),
    -- Timout values and timers fore stopping struggle dialogue
    tutorial_timeout = playdate.timer.new(100, function ()
        -- special timer that starts after tutorial is complete.
        -- Only once done, struggles can be triggerd
        TUTORIAL_COMPLETED = true
      end),
    cocktail_struggle_timeout = playdate.timer.new(100, function ()
        PLAYER_STRUGGLES.cocktail_struggle = false
        end),
    recipe_struggle_timeout = playdate.timer.new(100, function ()
        PLAYER_STRUGGLES.recipe_struggle = false
        end),
    no_fire_timeout = playdate.timer.new(100, function ()
        PLAYER_STRUGGLES.no_fire = false
        end),
    too_much_fire_timeout = playdate.timer.new(100, function ()
        PLAYER_STRUGGLES.too_much_fire = false
        end),
    too_little_fire_timeout = playdate.timer.new(100, function ()
        PLAYER_STRUGGLES.too_little_fire = false
        end),
    no_shake_timeout = playdate.timer.new(100, function ()
        PLAYER_STRUGGLES.no_shake = false
        end),
    too_much_shaking_timeout = playdate.timer.new(100, function ()
        PLAYER_STRUGGLES.too_much_shaking = false
      end),
    too_much_stir_timeout = playdate.timer.new(100, function ()
        PLAYER_STRUGGLES.too_much_stir = false
        end),
    sticker_slap = playdate.timer.new(100, function ()
        Restart_timer(GAMEPLAY_TIMERS.sticker_glitter, UI_TEXTURES.sticker_glitter.delay * UI_TEXTURES.sticker_glitter.endFrame)
    end),
    sticker_glitter = playdate.timer.new(100, function ()
        MENU_STATE.screen = MENU_SCREEN.mission
    end),
    selection_finger = playdate.timer.new(100, function ()
        Set_target_potion(MENU_STATE.focused_option + 1)
        Enter_gameplay()
    end),
}
-- Make sure none of the gameplay timers are removed on completion
for k in pairs(GAMEPLAY_TIMERS) do
    GAMEPLAY_TIMERS[k]:pause()
    GAMEPLAY_TIMERS[k].discardOnCompletion = false
end

-- Stirring.
STIR_POSITION = 0 -- Ladle position as an angle in radians.
STIR_FACTOR = 0  -- Effect stirring has on the potion
STIR_CHANGE = 0 -- Amount of player induced change in STIR_FACTOR this frame

STIR_SPEED = 0 -- Speed of cranking in revolutions per second
STIR_REVOLUTION = 0
STIR_COUNT = 0

-- Gyro.
local GYRO_X, GYRO_Y = 200, 120
local IS_GYRO_INITIALIZED = false
local AVG_GRAVITY_X = 0
local AVG_GRAVITY_Y = 0
local AVG_GRAVITY_Z = 0

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

    -- Reset to default randomness
    math.randomseed(playdate.getSecondsSinceEpoch())

    GAME_ENDED = false
    CAN_REINFORCE = false
    GAMEPLAY_STATE.game_tick = 0
    GAMEPLAY_STATE.showing_cocktail = false
    GAMEPLAY_STATE.showing_instructions = false
    GAMEPLAY_STATE.instructions_prompt_expanded = false
    GAMEPLAY_STATE.instructions_offset_x = -10
    GAMEPLAY_STATE.instructions_offset_y = 275
    GAMEPLAY_STATE.showing_recipe = false
    GAMEPLAY_STATE.flame_amount = 0.0
    GAMEPLAY_STATE.heat_amount = 0.0
    GAMEPLAY_STATE.fire_stoke_count = 0
    GAMEPLAY_STATE.start_counting_blows = true
    GAMEPLAY_STATE.liquid_offset = 0.0
    GAMEPLAY_STATE.liquid_momentum = 0.0
    GAMEPLAY_STATE.liquid_viscosity = 0.9
    GAMEPLAY_STATE.potion_bubbliness = 0.0
    GAMEPLAY_STATE.cauldron_ingredient = nil
    GAMEPLAY_STATE.held_ingredient = 0
    GAMEPLAY_STATE.last_cauldron_ingredient = nil
    GAMEPLAY_STATE.last_shaken_ingredient = nil
    GAMEPLAY_STATE.cauldron_swap_count = 0
    GAMEPLAY_STATE.asked_frog_count = 0
    -- Reset current ingredient mix.
    for a = 1, NUM_RUNES, 1 do
        GAMEPLAY_STATE.rune_count[a] = 0
        GAMEPLAY_STATE.rune_count_unstirred[a] = 0
        GAMEPLAY_STATE.rune_count_unclamped[a] = 0
    end
    for k, v in pairs(GAMEPLAY_STATE.used_ingredients_table) do
        GAMEPLAY_STATE.used_ingredients_table[k] = false
    end
    GAMEPLAY_STATE.used_ingredients = 0
    GAMEPLAY_STATE.dropped_ingredients = 0
    GAMEPLAY_STATE.counting_stirs = false
    GAMEPLAY_STATE.stirring_complete = false
    GAMEPLAY_STATE.puff_anim_started = false
    GAMEPLAY_STATE.cocktail_learned = false
    GAMEPLAY_STATE.new_high_score = false
    GAMEPLAY_STATE.new_mastered = false
    CURRENT_RECIPE = {}
    RECIPE_TEXT = {}

    -- Reset active timers
    for k in pairs(GAMEPLAY_TIMERS) do
        GAMEPLAY_TIMERS[k]:reset()
        GAMEPLAY_TIMERS[k]:pause()
    end

    Calculate_goodness()

    Reset_ingredients()
    INGREDIENT_SPLASH:reset()
    FROG:reset()
    playdate.timer.new(1000, function ()
      FROG:Ask_for_cocktail()
    end)
    -- Regular talk reminders on the beginner cocktails
    if TARGET_COCKTAIL.type_idx < 4 then
        Restart_timer(GAMEPLAY_TIMERS.talk_reminder, 20*1000)
    end

    PLAYER_LEARNED.how_to_fire = false
    PLAYER_LEARNED.how_to_grab = false
    PLAYER_LEARNED.how_to_release = false
    PLAYER_LEARNED.how_to_shake = false
    PLAYER_LEARNED.how_to_stir = false

    TUTORIAL_COMPLETED = false

    PLAYER_STRUGGLES.no_fire = false
    PLAYER_STRUGGLES.too_much_fire = false
    PLAYER_STRUGGLES.too_little_fire = false
    PLAYER_STRUGGLES.no_shake = false
    PLAYER_STRUGGLES.too_much_shaking = false
    PLAYER_STRUGGLES.too_much_stir = false
    PLAYER_STRUGGLES.recipe_struggle = false
    PLAYER_STRUGGLES.cocktail_struggle = false

    STRUGGLE_PROGRESS.recipe_struggle_lvl = 0
    STRUGGLE_PROGRESS.fire_struggle_asked = 0
    STRUGGLE_PROGRESS.ingredient_struggle_asked = 0
    STRUGGLE_PROGRESS.struggle_hint_asked = 0
    STRUGGLE_PROGRESS.recipe_hint_asked = 0
    STRUGGLE_PROGRESS.no_fire_tracking = 0
    STRUGGLE_PROGRESS.too_much_fire_tracking = 0
    STRUGGLE_PROGRESS.too_little_fire_tracking = 0
    STRUGGLE_PROGRESS.no_shake_tracking = 0
    STRUGGLE_PROGRESS.too_much_stir_tracking = 0
    STRUGGLE_PROGRESS.too_much_shaking_tracking = 0

    STIR_FACTOR = 1.5 -- sink and despawn all drops. Overshooting it a bit to ensure they definitely despawn. Cbb


    -- Reset time delta
    playdate.resetElapsedTime()

    -- Reset highscore recipe scroll
    end_recipe_y = 0
end


function Update_rune_count(drop_rune_count)

    -- Calculate new rune count
    for a = 1, NUM_RUNES, 1 do
        if TARGET_COCKTAIL.rune_count[a] > 0 then
            GAMEPLAY_STATE.rune_count_unclamped[a] = GAMEPLAY_STATE.rune_count[a] + ((drop_rune_count[a]/6) * 0.3)
            GAMEPLAY_STATE.rune_count[a] = Clamp(GAMEPLAY_STATE.rune_count_unclamped[a], 0, 1)
        end
    end

    -- Update variables
    GAMEPLAY_STATE.dropped_ingredients += 1
    -- Adjust stir factor relative to new count of drops
    local drops = GAMEPLAY_STATE.dropped_ingredients
    STIR_FACTOR = (STIR_FACTOR / drops) * (drops - 1)

    -- Set neutral recorded trend if the rune count is the same
    local matching_runes = 0
    for i in pairs(GAMEPLAY_STATE.rune_count) do
        if GAMEPLAY_STATE.rune_count[i] == PREV_RUNE_COUNT[i] then
            matching_runes += 1
        end
    end

    if matching_runes == 3 then
        -- Rune count didn't change, so frog reinforcement is disabled
        CAN_REINFORCE = false
    else
        -- Compare how the trend of each rune changed
        for i in pairs(DIFF_TO_TARGET.runes_abs) do
            if DIFF_TO_TARGET.runes_abs[i] < DIFF_TO_TARGET.runes_abs_prev[i] then
                DIFF_TO_TARGET.runes_trend[i] = 1
            elseif DIFF_TO_TARGET.runes_abs[i] > DIFF_TO_TARGET.runes_abs_prev[i] then
                DIFF_TO_TARGET.runes_trend[i] = -1
            else
                DIFF_TO_TARGET.runes_trend[i] = 0
            end
            DIFF_TO_TARGET.runes_abs_prev[i] = DIFF_TO_TARGET.runes_abs[i]
        end
    end


    local prev_rune_avg = (PREV_RUNE_COUNT[1] + PREV_RUNE_COUNT[2] + PREV_RUNE_COUNT[3]) /3
    local current_rune_avg = (GAMEPLAY_STATE.rune_count[1] + GAMEPLAY_STATE.rune_count[2] + GAMEPLAY_STATE.rune_count[3]) / 3

    PREV_RUNE_COUNT = table.shallowcopy(GAMEPLAY_STATE.rune_count)

    --print("Rune Count = " .. tostring(GAMEPLAY_STATE.rune_count[1] .. ", " .. tostring(GAMEPLAY_STATE.rune_count[2]) .. ", " .. tostring(GAMEPLAY_STATE.rune_count[3])))
end


win_text = ""

function Win_game()
    GAME_ENDED = true

    STIR_SPEED = 0 -- Stop liquid and stirring sounds.
    STIR_FACTOR = 1.5 -- sink and despawn all drops. Overshooting it a bit to ensure they definitely despawn. Cbb

    -- Reset cursor position to avoid floating shelf ingredients
    GAMEPLAY_STATE.cursor_pos.x = 0
    GAMEPLAY_STATE.cursor_pos.y = 240

    -- Set win recipe top text
    GAMEPLAY_STATE.new_high_score = false
    if not FROGS_FAVES.accomplishments[TARGET_COCKTAIL.name] then
        GAMEPLAY_STATE.new_high_score = true
        GAMEPLAY_STATE.cocktail_learned = true
        win_text = "RECIPE\nLEARNED!"
    elseif Score_of_recipe(CURRENT_RECIPE) < Score_of_recipe(FROGS_FAVES.recipes[TARGET_COCKTAIL.name]) then
        GAMEPLAY_STATE.new_high_score = true
        win_text = "RECIPE\nIMPROVED!"
    else
        win_text = "RECIPE\nDONE!"
    end
    if GAMEPLAY_STATE.new_high_score then
        FROGS_FAVES.recipes[TARGET_COCKTAIL.name] = CURRENT_RECIPE
    end

    -- Check if the cocktail has been mastered for the first time
    local current_steps <const> = #RECIPE_TEXT
    local prev_top_steps <const> = #FROGS_FAVES_TEXT[COCKTAILS[RECIPE_COCKTAIL].name]
    if current_steps <= TARGET_COCKTAIL.step_ratings[1] and
        (prev_top_steps > TARGET_COCKTAIL.step_ratings[1] or prev_top_steps == 0) then
            GAMEPLAY_STATE.new_mastered = true
    else
        GAMEPLAY_STATE.new_mastered = false
    end

    FROGS_FAVES.accomplishments[TARGET_COCKTAIL.name] = true
    Store_high_scores()
end


end_recipe_y = 0
local scroll_speed = 1.8



-- Update Loop: input

function Handle_input()

    -- When transitioning to end game, stop processing and reacting to new input.
    if GAME_ENDED then
        -- Wait for recipe to show up before handling more input
        if not GAMEPLAY_STATE.showing_recipe and playdate.buttonJustReleased( playdate.kButtonB ) then
            -- stop burp_anim timer
            GAMEPLAY_TIMERS.burp_anim:pause()
            -- trim time off burptalk_anim timer to trigger its function
            GAMEPLAY_TIMERS.burptalk_anim.duration -= 10*1000
        elseif GAMEPLAY_STATE.showing_recipe then
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
                        Check_tutorial_completion()
                        print('Learned how to grab.')
                    end
                    break
                end
            end
            for i, ingredient in pairs(INGREDIENTS) do
                if ingredient.state == INGREDIENT_STATE.is_over_cauldron and picked_up then
                    ingredient.state = INGREDIENT_STATE.is_in_air
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
            -- Press B 3 times for the frog to stop speaking by himself (Unless it's late cocktails)
            if GAMEPLAY_STATE.asked_frog_count < FROG_AUTOMATED then
                GAMEPLAY_STATE.asked_frog_count += 1
                if TARGET_COCKTAIL.type_idx < 4 then
                    Restart_timer(GAMEPLAY_TIMERS.talk_reminder, 20*1000)
                end
            end
            if GAMEPLAY_STATE.asked_frog_count >= FROG_AUTOMATED then
                GAMEPLAY_TIMERS.talk_reminder:pause()
            end

            -- Start frog player initiated dialogue
            local automated = false
            FROG:Ask_the_frog(automated)
        end

        -- Modal instruction overlays.
        if playdate.buttonJustPressed( playdate.kButtonLeft ) then
            GAMEPLAY_STATE.showing_cocktail = true
            PLAYER_STRUGGLES.cocktail_struggle = false
            -- Set a negative tracking for ingredient types,
            -- so the cocktail struggle won't be triggered in the level anymore
            GAMEPLAY_STATE.used_ingredients = -9
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
    -- Note: check all values and not just x for nil so that the IDE linter is sure it's numbers.
    if raw_gravity_x == nil or raw_gravity_y == nil or raw_gravity_z == nil then
        return
    end

    -- Calculate G's (length of acceleration vector)
    SHAKE_VAL = raw_gravity_x * raw_gravity_x + raw_gravity_y * raw_gravity_y + raw_gravity_z * raw_gravity_z

    -- Update the average "normal" gyroscope position. This depends on the tilt that players are
    -- comfortable holding the playdate and might change over time. aka Normalize Gravity.
    if IS_GYRO_INITIALIZED == false then
        -- For the initial value, use the gyro at the start of the game, so that
        -- it calibrates as quickly as possible to the current device orientation.
        AVG_GRAVITY_X = raw_gravity_x
        AVG_GRAVITY_Y = raw_gravity_y
        AVG_GRAVITY_Z = raw_gravity_z
        IS_GYRO_INITIALIZED = true
    else
        -- Exponential moving average:
        --   https://en.wikipedia.org/wiki/Exponential_smoothing
        --
        -- The weight from the number of samples can be estimated as `2 / (n + 1)`.
        -- See the Relationship between SMA and EMA section of the
        --   https://en.wikipedia.org/wiki/Moving_average
        local num_smooth_samples <const> = 120
        local alpha <const> = 2 / (num_smooth_samples + 1)

        AVG_GRAVITY_X = alpha * raw_gravity_x + (1 - alpha) * AVG_GRAVITY_X
        AVG_GRAVITY_Y = alpha * raw_gravity_y + (1 - alpha) * AVG_GRAVITY_Y
        AVG_GRAVITY_Z = alpha * raw_gravity_z + (1 - alpha) * AVG_GRAVITY_Z

        local len <const> = math.sqrt(AVG_GRAVITY_X*AVG_GRAVITY_X + AVG_GRAVITY_Y*AVG_GRAVITY_Y + AVG_GRAVITY_Z*AVG_GRAVITY_Z)
        AVG_GRAVITY_X /= len
        AVG_GRAVITY_Y /= len
        AVG_GRAVITY_Z /= len
    end

    -- Only update the gyro onscreen position when it's fairly stable (player isn't actively shaking the console).
    if SHAKE_VAL < 1.1 then
        local v1 <const> = vec2d.new(0, 1)
        local v2 <const> = vec2d.new(AVG_GRAVITY_Y, AVG_GRAVITY_Z)
        local angle <const> = v2:angleBetween(v1) / 180 * math.pi

        local co <const> = math.cos(angle)
        local si <const> = math.sin(angle)

        local gravity_x <const> = raw_gravity_x
        local gravity_y <const> = raw_gravity_y*co - raw_gravity_z*si
        --    gravity_z <const> = raw_gravity_y*si + raw_gravity_z*co

        local axis_sign <const> = Sign(raw_gravity_z)
        local gyroSpeed <const> = 60

        GYRO_X = Clamp(GYRO_X + gravity_x * gyroSpeed * axis_sign, 0, 400)
        GYRO_Y = Clamp(GYRO_Y + gravity_y * gyroSpeed, 0, 240)
        GAMEPLAY_STATE.cursor_pos.x = GYRO_X
        GAMEPLAY_STATE.cursor_pos.y = GYRO_Y
    end
end


function check_crank_to_stir()
    local prev_stir_position <const> = STIR_POSITION

    -- Poll crank input.
    local _, acceleratedChange = playdate.getCrankChange()
    STIR_SPEED = acceleratedChange or 0
    -- Use the absolute position of the crank to drive the stick in the cauldron.
    STIR_POSITION = math.rad(playdate.getCrankPosition() or 0)

    local delta_stir = math.abs(STIR_POSITION - prev_stir_position) / (math.pi * 2)

    if GAMEPLAY_STATE.dropped_ingredients > 0 then
        GAMEPLAY_STATE.counting_stirs = true
    end

    -- Count crank revolutions
    -- Reset counting when cranking stops
    -- Also resets if there's no ingredient in the cauldron
    if (delta_stir == 0 and GAMEPLAY_STATE.dropped_ingredients == 0 and GAMEPLAY_STATE.counting_stirs)
    or not GAMEPLAY_STATE.counting_stirs then
        STIR_REVOLUTION = 0
        STIR_COUNT = 0
        -- Reset to check again if there's an ingredent in the cauldron only once stirring starts again
        GAMEPLAY_STATE.counting_stirs = false
    else
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

    -- Play stirring sound when the ladle is moving.
    if math.abs(STIR_SPEED) > 3 then
        if not SOUND.stir_sound:isPlaying() then
            SOUND.stir_sound:play()

            -- Stop the sound with a bit of delay when stirring stops.
            -- There is one timer to count a delay of time after stopping stirring.
            delay_to_stop_timer = playdate.timer.new(0.4 * 1000) --tmp this timer should also become a GAMEPLAY_TIMERS
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


-- Update Loop: logic

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

        if GAMEPLAY_STATE.flame_amount > 0.8 then
            if not SOUND.fire_blow:isPlaying() or blow_sound_timer.value == 1 then
                SOUND.fire_blow:playAt(1)
                blow_sound_timer:remove()
                blow_sound_timer = playdate.timer.new(1.5 * 1000, 0, 1)
                    if GAMEPLAY_STATE.heat_amount < 0.5 then
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


function update_liquid()
    -- Update liquid stir effect

    local stir_change_unclamped <const> = math.abs(STIR_SPEED) * 0.001
    local min_stir_change <const> = 0.005
    local max_stir_change <const> = 0.02
    local idle_stir_change <const> = 0.001
    local floating_drops <const> = GAMEPLAY_STATE.dropped_ingredients

    STIR_CHANGE = Clamp(stir_change_unclamped, min_stir_change, max_stir_change)

    -- Calculate current stirring effect.
    if floating_drops > 0 and STIR_FACTOR > 0.9 then
        STIR_FACTOR += STIR_FACTOR * 0.002
        STIR_FACTOR = math.min(STIR_FACTOR, 1)
    elseif floating_drops == 0 then
        STIR_FACTOR -= 0.08
    end
    if stir_change_unclamped >= idle_stir_change then
        STIR_FACTOR += STIR_CHANGE
    else
        STIR_CHANGE = 0
    end
    STIR_FACTOR = Clamp(STIR_FACTOR, 0, 1)

    -- Reset rune travel variables and mark stirring as complete
    if STIR_FACTOR >= 1 then
        table.shallowcopy(GAMEPLAY_STATE.rune_count, GAMEPLAY_STATE.rune_count_unstirred)
        table.shallowcopy(GAMEPLAY_STATE.rune_count, GAMEPLAY_STATE.rune_count_unclamped)
        GAMEPLAY_STATE.dropped_ingredients = 0
        CHECK_IF_DELICIOUS = true
        if not GAMEPLAY_STATE.stirring_complete and GAMEPLAY_STATE.counting_stirs then
            GAMEPLAY_STATE.stirring_complete = true
            GAMEPLAY_STATE.puff_anim_started = false
        end
    end

    -- Update liquid state
    GAMEPLAY_STATE.liquid_momentum += Clamp(STIR_SPEED, -8, 8) / 10
    GAMEPLAY_STATE.liquid_offset += GAMEPLAY_STATE.liquid_momentum
    GAMEPLAY_STATE.liquid_momentum *= 0.9 -- viscosity factor
    if math.abs(GAMEPLAY_STATE.liquid_momentum) < 1e-4 then
        GAMEPLAY_STATE.liquid_momentum = 0
    end
end



-- Game target goal checks


function Are_ingredients_good_enough()
    for i=1, NUM_RUNES do
        if DIFF_TO_TARGET.runes_abs[i] > GOAL_TOLERANCE
        and TARGET_COCKTAIL.rune_count[i] ~= 0 then -- Runes that target 0 are for intro cocktails
            return false
        end
    end
    return true
end

function Is_potion_good_enough()
    if Are_ingredients_good_enough() and GAMEPLAY_STATE.dropped_ingredients == 0 then
        return true
    else
        return false
    end
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
    and not RECIPE_STRUGGLE_STEPS then
        FROG:Notify_the_frog()
        -- Stop potentual blinking from eyeball lick
        ANIMATIONS.b_prompt.frame = 1
        ANIMATIONS.b_prompt.paused = true
    elseif math.abs(diff_change_overall) > 0.01
    and not RECIPE_STRUGGLE_STEPS then
        FROG:Notify_the_frog()
        -- Stop potentual blinking from eyeball lick
        ANIMATIONS.b_prompt.frame = 1
        ANIMATIONS.b_prompt.paused = true
    elseif CHECK_IF_DELICIOUS then
        FROG:Lick_eyeballs()
    end
end


function Check_player_learnings()
    if GAMEPLAY_STATE.flame_amount > 0.3
    and not PLAYER_LEARNED.how_to_fire
    and GAMEPLAY_STATE.last_shaken_ingredient ~= nil then
        PLAYER_LEARNED.how_to_fire = true
        FROG:flash_b_prompt()
        Check_tutorial_completion()
        print('Learned how to fire.')
    end

    if math.abs(STIR_SPEED) > 7.5
    and GAMEPLAY_STATE.dropped_ingredients > 0
    and not PLAYER_LEARNED.how_to_stir then
        PLAYER_LEARNED.how_to_stir = true
        FROG:flash_b_prompt()
        Check_tutorial_completion()
        print('Learned how to stir.')
    end
end


function Shorten_talk_reminder()
    -- If the player hasn't talked to to frog yet, shorten the regular intervals in some cases
    -- Don't do this if the cocktail is already close to done.
    if GAMEPLAY_TIMERS.talk_reminder.paused == false and not Is_potion_good_enough() then
        GAMEPLAY_TIMERS.talk_reminder.duration -= 10*1000
    end
end


function Check_player_struggle()

    -- Only once tutorial is complete
    if not TUTORIAL_COMPLETED and not Are_ingredients_good_enough() then
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

    -- Too little fire
    if not PLAYER_STRUGGLES.too_little_fire then
        Check_too_little_fire_struggle()
    end

    -- Too much shaking
    if GAMEPLAY_STATE.dropped_ingredients >= min_drops_without_stirring then
        Check_too_much_shaking_struggle()
    end

    -- No shaking
    if not Cauldron_ingredient_was_shaken() then
        Check_no_shaking_struggle()
    end

    -- Too much stirring
    if Cauldron_ingredient_was_shaken() then
        Check_too_much_stirring_struggle()
    end

    -- No check for "No Stirring needed". There's already frequent remidners in place

    -- Cocktail struggle (Pointing towards cocktail artwork or clues)
    -- If you used too many different ingredients
    if GAMEPLAY_STATE.used_ingredients > 5 and not PLAYER_STRUGGLES.cocktail_struggle
    and TARGET_COCKTAIL.type_idx < 5 then
        print("Player used too many ingredient types.")
        PLAYER_STRUGGLES.cocktail_struggle = true
        Shorten_talk_reminder()
        -- Reset tracked used ingredients
        GAMEPLAY_STATE.used_ingredients = 0
        for k, v in pairs(GAMEPLAY_STATE.used_ingredients_table) do
            GAMEPLAY_STATE.used_ingredients_table[k] = false
        end
        -- Timeout to stop cocktail hint dialogue
        Restart_timer(GAMEPLAY_TIMERS.cocktail_struggle_timeout, struggle_reminder_timout)
        FROG:wants_to_talk()
    end

    -- Recipe struggle (General gameplay hints)
    -- If you used to many actions so far
    -- Or if you keep asking the same question
    if not PLAYER_STRUGGLES.recipe_struggle and
    (RECIPE_STRUGGLE_STEPS == true or STRUGGLE_PROGRESS.ingredient_struggle_asked >= 4) then
        PLAYER_STRUGGLES.recipe_struggle = true
        Shorten_talk_reminder()
        Next_recipe_struggle_tip()
        print("Giving gameplay hint Nr. " .. STRUGGLE_PROGRESS.recipe_struggle_lvl)
        -- Only when not cycling through dialogue, use the urgent reaction of the frog
        if RECIPE_STRUGGLE_STEPS == true then
            FROG:wants_to_talk()
            Restart_timer(GAMEPLAY_TIMERS.recipe_struggle_timeout, struggle_reminder_timout)
        end
    -- Reset so the struggle can be detected and triggered again
    elseif not RECIPE_STRUGGLE_STEPS and GAMEPLAY_TIMERS.recipe_struggle_timeout.paused then
        if PLAYER_STRUGGLES.recipe_struggle then
            PLAYER_STRUGGLES.recipe_struggle = false
        end
        STRUGGLE_PROGRESS.recipe_hint_asked = 0
    end
end

function Check_no_fire_struggle()
    if GAMEPLAY_STATE.heat_amount < 0.1 then
        STRUGGLE_PROGRESS.no_fire_tracking += 0.0006
    else
        STRUGGLE_PROGRESS.no_fire_tracking = 0
    end
    if STRUGGLE_PROGRESS.no_fire_tracking >= 1 or
    STRUGGLE_PROGRESS.fire_struggle_asked >= 4 then
        print("Fire is never used or player forgot how!")
        PLAYER_STRUGGLES.no_fire = true
        FROG:wants_to_talk()
        Restart_timer(GAMEPLAY_TIMERS.no_fire_timeout, struggle_reminder_timout)
    end
    --print("No fire tracking: " .. STRUGGLE_PROGRESS.no_fire_tracking)
end


function Check_too_much_fire_struggle()
    -- 1. Heat doesn't fall under a high threshold for a certain amount of time
    -- 2. Flame is kept over a very high threshold for a prolonged period of time
    if GAMEPLAY_STATE.heat_amount > 0.9 then
        STRUGGLE_PROGRESS.too_much_fire_tracking += 0.003
    else
        STRUGGLE_PROGRESS.too_much_fire_tracking -= 0.001
    end

    STRUGGLE_PROGRESS.too_much_fire_tracking = Clamp(STRUGGLE_PROGRESS.too_much_fire_tracking, 0, 1)
    if STRUGGLE_PROGRESS.too_much_fire_tracking >= 1 then
        print("Fire is stoked way too much!")
        PLAYER_STRUGGLES.too_much_fire = true
        Shorten_talk_reminder()
        FROG:wants_to_talk()
        STRUGGLE_PROGRESS.too_much_fire_tracking = 0
        -- timer to stop struggle dialogue
        Restart_timer(GAMEPLAY_TIMERS.too_much_fire_timeout, struggle_reminder_timout)
    end
    --print("Too much fire tracker: " .. STRUGGLE_PROGRESS.too_much_fire_tracking)
    --print(GAMEPLAY_STATE.fire_stoke_count)
end


function Check_too_little_fire_struggle()
    -- 1. Fire is stoked 4 times and not going above a threshold
    if GAMEPLAY_STATE.heat_amount < 0.6 then
    -- Start tracking stoke counts if it stays under the threshold
        if GAMEPLAY_STATE.flame_amount > 0.3 then
            if GAMEPLAY_STATE.start_counting_blows then
                GAMEPLAY_STATE.fire_stoke_count += 1
                GAMEPLAY_STATE.start_counting_blows = false
            end
        else
            GAMEPLAY_STATE.start_counting_blows = true
        end
    else
        GAMEPLAY_STATE.fire_stoke_count = 0
    end

    if GAMEPLAY_STATE.fire_stoke_count >= 5 then
        print("Fire is stoked way little!")
        PLAYER_STRUGGLES.too_little_fire = true
        Shorten_talk_reminder()
        FROG:wants_to_talk()
        -- reset counting
        GAMEPLAY_STATE.fire_stoke_count = 0
        -- timer to stop struggle dialogue
        Restart_timer(GAMEPLAY_TIMERS.too_little_fire_timeout, struggle_reminder_timout)
    end
    --print(GAMEPLAY_STATE.fire_stoke_count)
end


function Check_no_shaking_struggle()
    -- Check if the ingredient was swapped many times without shaking
    if GAMEPLAY_STATE.cauldron_swap_count > 3 and not PLAYER_STRUGGLES.no_shake then
        print("Swapped ingredients too much without shaking")
        PLAYER_STRUGGLES.no_shake = true
        Shorten_talk_reminder()
        FROG:wants_to_talk()
        Restart_timer(GAMEPLAY_TIMERS.no_shake_timeout, struggle_reminder_timout)
        GAMEPLAY_STATE.cauldron_swap_count = 0
    -- Check it there's too much stirring without a dropped ingredient
    elseif not PLAYER_STRUGGLES.no_shake then
        if GAMEPLAY_STATE.dropped_ingredients == 0 and math.abs(STIR_SPEED) > 7.5 then
            -- Start tracking stirring
            STRUGGLE_PROGRESS.no_shake_tracking += excess_stirring_factor
            if STRUGGLE_PROGRESS.no_shake_tracking > 1 then
                --print("Stirring reached struggling amount.")
                print("Too much stirring without shaking")
                PLAYER_STRUGGLES.no_shake = true
                Shorten_talk_reminder()
                FROG:wants_to_talk()
                Restart_timer(GAMEPLAY_TIMERS.no_shake_timeout, struggle_reminder_timout)
                STRUGGLE_PROGRESS.no_shake_tracking = 0
            end
        elseif GAMEPLAY_STATE.dropped_ingredients > 0 then
            -- New ingredients dropped in. Reset tracked stirring and timeout
            STRUGGLE_PROGRESS.no_shake_tracking = 0
            PLAYER_STRUGGLES.no_shake = false
            print("Shaking struggle canceled")
            GAMEPLAY_TIMERS.no_shake_timeout:pause()
        end
    end
    --print("No shake tracking: " .. STRUGGLE_PROGRESS.no_shake_tracking)
end

function Check_too_much_shaking_struggle()
    -- min combined stirring factor to trigger struggle dialogue
    local min_stirring = STIR_FACTOR + STRUGGLE_PROGRESS.too_much_shaking_tracking
    if min_stirring < 0.15 and
    not PLAYER_STRUGGLES.too_much_shaking then
        print("Player is struggling with stir")
        PLAYER_STRUGGLES.too_much_shaking = true
        Shorten_talk_reminder()
        FROG:wants_to_talk()
        Restart_timer(GAMEPLAY_TIMERS.too_much_shaking_timeout, struggle_reminder_timout)
        -- Increasing the tracking variable will make sure the frog won't retrigger the dialogue,
        -- unless the player addressed the issue
        STRUGGLE_PROGRESS.too_much_shaking_tracking = 1
    elseif STIR_FACTOR >= 0.15 and STRUGGLE_PROGRESS.too_much_shaking_tracking > 0 then
        print("Player shaking struggle was reset")
        -- Reset variables and start tracking struggle again to retrigger later
        PLAYER_STRUGGLES.too_much_shaking = false
        GAMEPLAY_TIMERS.too_much_shaking_timeout:pause()
        STRUGGLE_PROGRESS.too_much_shaking_tracking = 0
        --print("Player struggle with stir resolved")
    end
end

function Cauldron_ingredient_was_shaken()
    -- Check if ingredient has been shaken and same ingredient is still on cauldron
    if GAMEPLAY_STATE.last_cauldron_ingredient == nil and GAMEPLAY_STATE.last_shaken_ingredient == nil then
        return false
    elseif GAMEPLAY_STATE.last_cauldron_ingredient == GAMEPLAY_STATE.last_shaken_ingredient then
        return true
    else
        return false
    end
end

function Check_too_much_stirring_struggle()
    if GAMEPLAY_STATE.dropped_ingredients == 0 and math.abs(STIR_SPEED) > 7.5 then
        -- Start tracking stirring
        STRUGGLE_PROGRESS.too_much_stir_tracking += excess_stirring_factor
        if STRUGGLE_PROGRESS.too_much_stir_tracking > 1 then
            --print("Stirring reached struggling amount.")
            PLAYER_STRUGGLES.too_much_stir = true
            Shorten_talk_reminder()
            FROG:wants_to_talk()
            Restart_timer(GAMEPLAY_TIMERS.too_much_stir_timeout, struggle_reminder_timout)
            STRUGGLE_PROGRESS.too_much_stir_tracking = 0
        end
    elseif GAMEPLAY_STATE.dropped_ingredients > 0 then
        -- New ingredients dropped in. Reset tracked stirring and timeout
        STRUGGLE_PROGRESS.too_much_stir_tracking = 0
        PLAYER_STRUGGLES.too_much_stir = false
        GAMEPLAY_TIMERS.too_much_stir_timeout:pause()
    end
    --print("Too much stir tracking: " .. STRUGGLE_PROGRESS.too_much_stir_tracking)
end

function Next_recipe_struggle_tip()
    local lines = 4 -- Same as recipe_struggle table
    -- Trigger frog hint line
    STRUGGLE_PROGRESS.recipe_struggle_lvl = math.fmod(STRUGGLE_PROGRESS.recipe_struggle_lvl + 1, lines)
    if STRUGGLE_PROGRESS.recipe_struggle_lvl == 0 then
        STRUGGLE_PROGRESS.recipe_struggle_lvl = lines
    end

end

function Check_tutorial_completion()
    -- Check if everything has been learned
    for i in pairs(PLAYER_LEARNED) do
        if not PLAYER_LEARNED[i] then
            return
        end
    end
    Restart_timer(GAMEPLAY_TIMERS.tutorial_timeout, 3*1000)
end

function Restart_timer(timer, duration)

    timer:start()
    timer:reset()
    timer.duration = duration
end