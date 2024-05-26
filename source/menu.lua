local gfx <const> = playdate.graphics
local gfxi <const> = playdate.graphics.image
local gfxit <const> = playdate.graphics.imagetable
local animloop <const> = playdate.graphics.animation.loop

MENU_STATE = {}
MENU_SCREEN = { gameplay = 0, start = 2, mission = 3, credits = 4 }

FROGS_FAVES = {
    accomplishments = {},
    recipes = {}, 
}
FROGS_FAVES_TEXT = {}
FROGS_FAVES_STEPS = {}

local UI_TEXTURES = {}
local NUM_VISIBLE_MISSIONS = 2 -- Number of cocktails fully visible in the mission selection, others are (half) clipped.
local global_origin = {0, 0}
local music_speed = 1.13  -- Extra factor to synch to music
local cocktail_anims = {}
local cocktail_anims_locked = {}

TOP_RECIPE_OFFSET = 0
RECIPE_COCKTAIL = 1
SIDE_SCROLL_X = 400

INTRO_COMPLETED = false
DICEY_UNLOCKED = false


-- System Menu

local function add_system_menu_entries_gameplay()

    local menu = playdate.getSystemMenu()
    menu:removeAllMenuItems() -- ensure there's no duplicated entries.

    -- Add custom entries to system menu.

    local menuItem, error = menu:addMenuItem("restart", function()
        Reset_gameplay()
    end)
    local menuItem, error = menu:addMenuItem("main menu", function()
        Enter_menu_start(0, 0, true)
    end)
end


local function add_system_menu_entries_cocktails()

    local menu = playdate.getSystemMenu()
    menu:removeAllMenuItems() -- ensure there's no duplicated entries.

    -- Add custom entries to system menu.

    local menuItem, error = menu:addMenuItem("reset scores", function()
        Reset_high_scores()
    end)
    local menuItem, error = menu:addMenuItem("unlock all", function()
        Unlock_all_cocktails()
    end)
end


function remove_system_menu_entries()
    playdate.getSystemMenu():removeAllMenuItems()
end



-- High Score

function Reset_high_scores() -- Should be removed in final game
    local frogs_faves = {
        accomplishments = {},
        recipes = {}
    }

    for a = 1, #COCKTAILS, 1 do
        frogs_faves.accomplishments[COCKTAILS[a].name] = false
        frogs_faves.recipes[COCKTAILS[a].name] = {}
    end

    FROGS_FAVES = frogs_faves
    playdate.datastore.write(frogs_faves, 'frogs_faves')
end


function Unlock_all_cocktails() -- Should be removed in final game + any references
    debug_cocktail_unlock = true
end


function Store_high_scores()
    playdate.datastore.write(FROGS_FAVES, 'frogs_faves')
end


function Load_high_scores()
    FROGS_FAVES = playdate.datastore.read('frogs_faves')
    if FROGS_FAVES == nil then
        Reset_high_scores()
    elseif next(FROGS_FAVES) == nil then
        Reset_high_scores()
    end
    
    -- Generate text version of high score recipes
    for a = 1, #COCKTAILS, 1 do
        local cocktail_name = COCKTAILS[a].name
        FROGS_FAVES_STEPS[cocktail_name] = Recipe_to_steps(FROGS_FAVES.recipes[cocktail_name])
        FROGS_FAVES_TEXT[cocktail_name] = Recipe_steps_to_text_menu(FROGS_FAVES_STEPS[cocktail_name])
    end
end



-- Menu State Transitions

function Enter_menu_start(new_global_x, new_global_y, side_scroll_reset)
    MENU_STATE.screen = MENU_SCREEN.start
    MENU_STATE.focused_option = 0
    MENU_STATE.first_option_in_view = 0
    if side_scroll_reset then
        SIDE_SCROLL_X = 400
    end

    remove_system_menu_entries()
    Stop_gameplay()

    SOUND.bg_loop_gameplay:stop()
    if not SOUND.bg_loop_menu:isPlaying() then
        SOUND.bg_loop_menu:play(0)
    end

    -- Reset menu positions if needed
    global_origin[1], global_origin[2] = new_global_x, new_global_y
end


function enter_menu_mission(enter_from_gameplay)

    Load_high_scores()
    add_system_menu_entries_cocktails()
    MENU_STATE.screen = MENU_SCREEN.mission

    SOUND.bg_loop_gameplay:stop()
    if not SOUND.bg_loop_menu:isPlaying() then
        SOUND.bg_loop_menu:play(0)
    end

    -- Locking/Unlocking cocktails
    if (FROGS_FAVES.accomplishments[COCKTAILS[1].name] and
    FROGS_FAVES.accomplishments[COCKTAILS[2].name]) then
        INTRO_COMPLETED = true
    end
    if (FROGS_FAVES.accomplishments[COCKTAILS[3].name] and
    FROGS_FAVES.accomplishments[COCKTAILS[4].name] and
    FROGS_FAVES.accomplishments[COCKTAILS[5].name]) then
        DICEY_UNLOCKED = true
    end

    -- Side scroll amount if coming directly from gameplay
    if enter_from_gameplay == true then
        SIDE_SCROLL_X = 30
    else
        SIDE_SCROLL_X = 400
    end
    -- Reset menu positions if needed
    global_origin[1], global_origin[2] = 0, 0

end


local function enter_menu_credits()
    MENU_STATE.screen = MENU_SCREEN.credits
end


function Enter_gameplay()
    MENU_STATE.screen = MENU_SCREEN.gameplay

    SOUND.bg_loop_menu:stop()
    if not SOUND.bg_loop_gameplay:isPlaying() then
        SOUND.bg_loop_gameplay:play(0)
    end

    add_system_menu_entries_gameplay()
    Reroll_mystery_potion()
    Reset_gameplay()
end


local recipe_hover_time = 20
local recipe_is_hovering = false
local recipe_hover_tick = 0

function Small_recipe_hover(TOP_RECIPE_OFFSET)

    --local bounds = self:getBoundsRect()
    if TOP_RECIPE_OFFSET < 50 then
        recipe_is_hovering = true
        recipe_hover_tick += 1
    else
        recipe_hover_tick -= 3
    end

    recipe_hover_tick = math.max(recipe_hover_tick, 0)
    recipe_hover_tick = math.min(recipe_hover_tick, recipe_hover_time)

    if recipe_hover_tick > 0 then
        -- Move sprite to the front
        local time = playdate.getElapsedTime()
        local wiggle_freq = 1
        local x_offset = math.sin(time * 1 * math.pi * (wiggle_freq + 0.1))
        local y_offset = math.sin(time * 2 * math.pi * (wiggle_freq + 0.1))
        local x_hover = x_offset * 2.5 * recipe_hover_tick / (recipe_hover_time)
        local y_hover = y_offset * 2.5 * recipe_hover_tick / recipe_hover_time

        return {math.floor(x_hover), math.floor(y_hover + TOP_RECIPE_OFFSET)}
    else
        if recipe_is_hovering then
            recipe_is_hovering = false
            return {0, TOP_RECIPE_OFFSET}
        end
    end
    return {0, TOP_RECIPE_OFFSET}
end


-- Draw & Update

local music_tick = 0
local side_scroll_direction = 1
local side_scroll_speed = 40
local credits_return = false

local function draw_ui()

    -- Timing to the music for credits animation
    music_tick += 1
    local music_speed = 9.1

    if MENU_STATE.screen == MENU_SCREEN.gameplay then
        music_tick = 0
        return
    end

    -- In menus. The gameplay is inactive.

    -- Draw combined menus
    if MENU_STATE.screen == MENU_SCREEN.start or MENU_SCREEN.credits or MENU_SCREEN.mission then
        local fmod = math.fmod
        gfx.pushContext()

            -- Fullscreen bg fill
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(0, 0, 400, 240)

            -- Side_scroll to auto-scroll to the correct screen
            if MENU_STATE.screen == MENU_SCREEN.mission then
                side_scroll_direction = 1.2
            else
                side_scroll_direction = -1.2
            end

            SIDE_SCROLL_X += -side_scroll_speed * side_scroll_direction

            -- Cap side_scroll range
            if SIDE_SCROLL_X < 30 then
                SIDE_SCROLL_X = 30
            elseif SIDE_SCROLL_X > 400 then
                SIDE_SCROLL_X = 400
            end


            -- Draw credit scroll
            UI_TEXTURES.credit_scroll:draw(global_origin[1], global_origin[2] + 240)


            -- Draw main menu
            UI_TEXTURES.start:draw(global_origin[1] + SIDE_SCROLL_X - 400, global_origin[2])


            -- Draw cocktail selection

            if debug_cocktail_unlock then
                INTRO_COMPLETED = true
                DICEY_UNLOCKED = true
            end

            -- Draw cocktails
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
            local cocktail_width = 142
            local first_cocktail_x = -cocktail_width * 0.5 + global_origin[1] + SIDE_SCROLL_X - 73
            local selected_cocktail_done = FROGS_FAVES.accomplishments[COCKTAILS[MENU_STATE.focused_option+1].name]

            for i, cocktail in pairs(cocktail_anims) do
                local cocktail_done = FROGS_FAVES.accomplishments[COCKTAILS[i].name]

                if (i-1) >= MENU_STATE.first_option_in_view - 1 and
                    (i-1) <= MENU_STATE.first_option_in_view + NUM_VISIBLE_MISSIONS then
                    local cocktail_relative_to_window = (i-1) - MENU_STATE.first_option_in_view +1
                    local cocktail_x = first_cocktail_x + cocktail_width * cocktail_relative_to_window
                    if (i-1) == MENU_STATE.focused_option and MENU_STATE.screen == 3 then
                        if (i > 2 and not INTRO_COMPLETED) or
                            i == 6 and not DICEY_UNLOCKED then
                                cocktail_anims_locked[i]:draw(cocktail_x, global_origin[2])
                        else
                            cocktail:draw(cocktail_x, global_origin[2])
                        end
                    else
                        if (i > 2 and not INTRO_COMPLETED) or
                            i == 6 and not DICEY_UNLOCKED then
                                COCKTAILS[i].locked_img:draw(cocktail_x, global_origin[2])
                        else
                            COCKTAILS[i].img:draw(cocktail_x, global_origin[2])
                        end
                    end

                    -- draw badge of accomplishment
                    if cocktail_done then
                        gfx.pushContext()
                            COCKTAILS[i].sticker:drawAnchored(cocktail_x + COCKTAILS[i].sticker_pos[1] , COCKTAILS[i].sticker_pos[2] - 10, 0.5, 0.5)
                        gfx.popContext()
                    end
                end
            end

            -- Draw current option indicator
            local focus_relative_to_window = MENU_STATE.focused_option - MENU_STATE.first_option_in_view +1
            local selected_cocktail_x = first_cocktail_x + cocktail_width * focus_relative_to_window
            UI_TEXTURES.selection_highlight:draw(selected_cocktail_x, global_origin[2])


            -- draw top recipe
            local recipe_popup_speed = 3
            local recipe_hide_speed = 0.2
            local recipe_scroll_speed = 1
            local recipe_min_height = 44
            local recipe_max_height = RECIPE_MAX_HEIGHT - 90

            local recipe_offset_x = (RECIPE_COCKTAIL - MENU_STATE.focused_option - 1) * cocktail_width
            local recipe_x = selected_cocktail_x - 14 + recipe_offset_x
            if TOP_RECIPE_OFFSET <= 0 then
                RECIPE_COCKTAIL = MENU_STATE.focused_option + 1
            end

            if RECIPE_COCKTAIL == MENU_STATE.focused_option + 1 and MENU_STATE.screen == 3 then
                if selected_cocktail_done and TOP_RECIPE_OFFSET < recipe_min_height then
                    TOP_RECIPE_OFFSET += recipe_popup_speed
                else
                    local crank_change = playdate.getCrankChange()
                    local button_speed = 8
                    if playdate.buttonIsPressed(playdate.kButtonUp) then
                        crank_change += -button_speed
                    elseif playdate.buttonIsPressed(playdate.kButtonDown) then
                        crank_change += button_speed
                    end
                    if math.abs(crank_change) > 0.01 and TOP_RECIPE_OFFSET >= recipe_min_height then
                        TOP_RECIPE_OFFSET += crank_change * recipe_scroll_speed
                        if TOP_RECIPE_OFFSET > recipe_max_height then
                            TOP_RECIPE_OFFSET = recipe_max_height
                        elseif TOP_RECIPE_OFFSET < recipe_min_height then
                            TOP_RECIPE_OFFSET = recipe_min_height
                        end
                    end
                end

            else
                if TOP_RECIPE_OFFSET > -1 then
                    TOP_RECIPE_OFFSET -= math.ceil(TOP_RECIPE_OFFSET * recipe_hide_speed)
                    if TOP_RECIPE_OFFSET < 1 then
                        TOP_RECIPE_OFFSET = -1
                    end
                end
            end

            local recipe_cocktail_name = COCKTAILS[RECIPE_COCKTAIL].name
            local recipe_text = FROGS_FAVES_TEXT[recipe_cocktail_name]
            local recipe_steps = FROGS_FAVES_STEPS[recipe_cocktail_name]

            local x_hover, y_hover = Small_recipe_hover(TOP_RECIPE_OFFSET)[1], Small_recipe_hover(TOP_RECIPE_OFFSET)[2]
            if FROGS_FAVES_TEXT[recipe_cocktail_name] ~= nil then
                Recipe_draw_menu(recipe_x - x_hover, 240 - y_hover + 6, recipe_text, recipe_steps)
            end

            -- FPS debugging
            gfx.pushContext()
            gfx.setColor(gfx.kColorWhite)
            playdate.drawFPS(200,0)
            gfx.popContext()

        gfx.popContext()
    end

end


local scroll_speed = 1.8
local auto_scroll_enabled = true
local auto_scroll = 1
local auto_scroll_max = 1
local auto_scroll_wind_up = 0.025
local wind_up_delay = 0.5
local wind_up_timer = playdate.timer.new(wind_up_delay*1000, function()
    end)
local crank_ccw = false


function Calculate_auto_scroll(direction_button)

    -- Disable auto-scroll and start wind-up timer
    local acceleratedChange = playdate.getCrankChange()
    if math.abs(acceleratedChange) > 10 or
    playdate.buttonIsPressed( direction_button ) then
        auto_scroll_enabled = false
        wind_up_timer:remove()
        wind_up_timer = playdate.timer.new(wind_up_delay*1000, function()
            auto_scroll_enabled = true
            end)
        if MENU_STATE.screen == MENU_SCREEN.start then
            auto_scroll_enabled = true
        end
    end
    if auto_scroll_enabled then
        auto_scroll += auto_scroll_wind_up
        if auto_scroll > auto_scroll_max then
            auto_scroll = auto_scroll_max
        end
    else
        auto_scroll = 0
    end
end


function Handle_menu_input()
    local acceleratedChange = playdate.getCrankChange()

    if MENU_STATE.screen == MENU_SCREEN.start then

        Calculate_auto_scroll( playdate.kButtonDown )

        -- Select an Option.
        if playdate.buttonJustReleased( playdate.kButtonRight ) or
            playdate.buttonJustReleased( playdate.kButtonA ) then
            SOUND.menu_confirm:play()
            enter_menu_mission(false)
        end

        -- Calculate scrolling
        local crankTicks = playdate.getCrankTicks(scroll_speed * 100)
        global_origin[2] += -crankTicks + (auto_scroll * 6)
        if playdate.buttonIsPressed( playdate.kButtonUp ) then
            global_origin[2] += scroll_speed * 2
        elseif playdate.buttonIsPressed( playdate.kButtonDown ) then
            global_origin[2] += -scroll_speed * 2
        end

        -- Limit scroll range
        if global_origin[2] > 0 then
            global_origin[2] = 0
        end

        -- Switch to credits
        if acceleratedChange < 3 then
            crank_ccw = true
        elseif acceleratedChange > 3 then
            crank_ccw = false
        end
        if playdate.buttonIsPressed( playdate.kButtonDown ) or
            not crank_ccw then
                auto_scroll_enabled = true
                enter_menu_credits()
        end

    elseif MENU_STATE.screen == MENU_SCREEN.mission then

        -- Make sure global_y get's back to 0 position
        global_origin[2] += 20
        if global_origin[2] > 0 then
            global_origin[2] = 0
        end

        if playdate.buttonJustReleased( playdate.kButtonA ) then
            if MENU_STATE.focused_option > 1 and
            MENU_STATE.focused_option < 5 and not INTRO_COMPLETED then
                print("Intro not completed yet!")
            elseif MENU_STATE.focused_option == 5 and not DICEY_UNLOCKED then
                print("Dicey not unlocked yet!")
            else
                SOUND.menu_confirm:play()
                -- reset mystery potion
                Set_target_potion(MENU_STATE.focused_option + 1)
                Enter_gameplay()
            end
        elseif playdate.buttonJustReleased( playdate.kButtonLeft ) and
        MENU_STATE.focused_option < 1 or
        playdate.buttonJustReleased( playdate.kButtonB )then
            SOUND.menu_confirm:play()
            Enter_menu_start(global_origin[1], global_origin[2], false)
        end

        -- Cycle Options.
        if playdate.buttonJustReleased( playdate.kButtonRight ) then
            MENU_STATE.focused_option += 1
            SOUND.menu_confirm:play()
        end
        if playdate.buttonJustReleased( playdate.kButtonLeft ) then
            MENU_STATE.focused_option -= 1
            SOUND.menu_confirm:play()
        end
        local crankTicks = playdate.getCrankTicks(3)
        -- Clamp so the option cycling doesn't wrap around.
        MENU_STATE.focused_option = math.max(MENU_STATE.focused_option, 0)
        MENU_STATE.focused_option = math.min(MENU_STATE.focused_option, #COCKTAILS - 1)

        -- Set the scroll window so that the selected option is in view.
        if MENU_STATE.focused_option < MENU_STATE.first_option_in_view then
            MENU_STATE.first_option_in_view = MENU_STATE.focused_option
        elseif MENU_STATE.focused_option >= MENU_STATE.first_option_in_view + NUM_VISIBLE_MISSIONS then
            MENU_STATE.first_option_in_view = MENU_STATE.first_option_in_view + NUM_VISIBLE_MISSIONS - 1
        end

    elseif MENU_STATE.screen == MENU_SCREEN.credits then

        Calculate_auto_scroll( playdate.kButtonUp )

        -- Calculate credit scroll
        local crankTicks = playdate.getCrankTicks(scroll_speed * 100)
        global_origin[2] += -crankTicks - auto_scroll
        if playdate.buttonIsPressed( playdate.kButtonUp ) then
            global_origin[2] += scroll_speed * 2
        elseif playdate.buttonIsPressed( playdate.kButtonDown ) then
            global_origin[2] += -scroll_speed * 2
        end

        -- Limit scroll range
        if global_origin[2] < -990 - 240 then
            global_origin[2] = -990 - 240
        end

        -- Return to start
        if acceleratedChange < 0 then
            crank_ccw = true
        else
            crank_ccw = false
        end
        if global_origin[2] > -60 and playdate.buttonIsPressed( playdate.kButtonUp ) or
            global_origin[2] > -60 and crank_ccw then
                auto_scroll_enabled = true
                Enter_menu_start(global_origin[1], global_origin[2])
        end
        if playdate.buttonJustReleased( playdate.kButtonB ) then
            Enter_menu_start(0, 0, true)
        end
    end
end


function Init_menus()

    -- Create animation loops for the cocktails.
    for i in pairs(COCKTAILS) do
        table.insert(cocktail_anims, animloop.new(COCKTAILS[i].framerate * frame_ms * music_speed, COCKTAILS[i].table, true))
    end

    for i in pairs(COCKTAILS) do
        table.insert(cocktail_anims_locked, animloop.new(COCKTAILS[i].framerate * frame_ms * music_speed, COCKTAILS[i].locked_table, true))
    end

    -- Create animation loops for the menu backgrounds
    UI_TEXTURES.start = animloop.new(16 * frame_ms * music_speed, gfxit.new("images/menu_start"), true)
    UI_TEXTURES.selection_highlight = animloop.new(16 * frame_ms * music_speed, gfxit.new("images/cocktails/white_selection_border"), true)
    UI_TEXTURES.credit_scroll = animloop.new(8 * frame_ms * music_speed, gfxit.new("images/credits"), true)

    MENU_STATE.screen = MENU_SCREEN.start
    MENU_STATE.focused_option = 0
    MENU_STATE.first_option_in_view = 0

    -- Set the multiple things in their Z order of what overlaps what.
    Set_draw_pass(100, draw_ui) -- UI goes on top of everything.
end
