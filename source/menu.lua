local gfx <const> = playdate.graphics
local gfxi <const> = playdate.graphics.image

MENU_STATE = {}
MENU_SCREEN = { gameplay = 0, start = 2, mission = 3, credits = 4 }

FROGS_FAVES = {
    accomplishments = {},
    recipes = {}, 
}

local UI_TEXTURES = {}
local NUM_VISIBLE_MISSIONS = 2 -- Number of cocktails fully visible in the mission selection, others are (half) clipped.

-- System Menu

local function add_system_menu_entries_gameplay()

    local menu = playdate.getSystemMenu()
    menu:removeAllMenuItems() -- ensure there's no duplicated entries.

    -- Add custom entries to system menu.

    local menuItem, error = menu:addMenuItem("restart", function()
        Reset_gameplay()
    end)
    local menuItem, error = menu:addMenuItem("main menu", function()
        Enter_menu_start()
    end)
end

local function add_system_menu_entries_cocktails()

    local menu = playdate.getSystemMenu()
    menu:removeAllMenuItems() -- ensure there's no duplicated entries.

    -- Add custom entries to system menu.
    local menuItem, error = menu:addMenuItem("reset scores", function()
        Reset_high_scores()
    end)
end

local function remove_system_menu_entries()
    playdate.getSystemMenu():removeAllMenuItems()
end

-- High Score

function Reset_high_scores()
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
end

-- Menu State Transitions

function Enter_menu_start()
    MENU_STATE.screen = MENU_SCREEN.start

    remove_system_menu_entries()
    Stop_gameplay()

    MENU_STATE.active_screen_texture = UI_TEXTURES.start
    SOUND.bg_loop_gameplay:stop()
    if not SOUND.bg_loop_menu:isPlaying() then
        SOUND.bg_loop_menu:play(0)
    end
end

local function enter_menu_mission()
    Load_high_scores()
    add_system_menu_entries_cocktails()
    MENU_STATE.screen = MENU_SCREEN.mission
    MENU_STATE.active_screen_texture = UI_TEXTURES.mission
end

local function enter_menu_credits()
    MENU_STATE.screen = MENU_SCREEN.credits
    MENU_STATE.active_screen_texture = UI_TEXTURES.credits
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



-- Draw & Update

local credits_y = 0

local function draw_ui()
    if MENU_STATE.screen == MENU_SCREEN.gameplay then
        return
    end

    -- In menus. The gameplay is inactive.

    -- Draw background screen image.
    MENU_STATE.active_screen_texture:draw(0, 0)

    -- Draw mission selection options.
    if MENU_STATE.screen == MENU_SCREEN.mission then
        gfx.pushContext()
            -- Fullscreen bg fill
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(0, 0, 400, 240)
            -- Draw cocktails
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
            local cocktail_width = 130
            local first_cocktail_x = -cocktail_width * 0.5
            for i, cocktail in pairs(COCKTAILS) do
                if (i-1) >= MENU_STATE.first_option_in_view - 1 and
                    (i-1) <= MENU_STATE.first_option_in_view + NUM_VISIBLE_MISSIONS then
                    local cocktail_relative_to_window = (i-1) - MENU_STATE.first_option_in_view +1
                    local cocktail_x = first_cocktail_x + cocktail_width * cocktail_relative_to_window 
                    cocktail.img:draw(cocktail_x, 0)
                    
                    -- draw badge of accomplishment
                    local cocktail_done = ''
                    if FROGS_FAVES.accomplishments[cocktail.name] then
                        cocktail_done = 'SERVED'
                    end
                    gfx.pushContext()
                        gfx.setFont(FONTS.speech_font)
                        gfx.setImageDrawMode(gfx.kDrawModeInverted)
                        gfx.drawText(cocktail_done, cocktail_x + 50, 214, gfx.font)
                    gfx.popContext()
                end
            end
            -- Draw current option indicator
            gfx.setColor(gfx.kColorWhite)
            gfx.setLineWidth(3.0)
            local focus_relative_to_window = MENU_STATE.focused_option - MENU_STATE.first_option_in_view +1
            gfx.drawRect(first_cocktail_x + cocktail_width * focus_relative_to_window, 0, 120, 240)
        gfx.popContext()
    end

    if MENU_STATE.screen == MENU_SCREEN.credits then
        gfx.pushContext()
                -- Fullscreen bg fill
                gfx.setColor(gfx.kColorBlack)
                gfx.fillRect(0, 0, 400, 240)
                -- Draw credit scroll
                UI_TEXTURES.credit_scroll:draw(0, credits_y)
        gfx.popContext()
    end
end

local auto_scroll_enabled = true
local auto_scroll = 1
local wind_up_timer = playdate.timer.new(2*1000, function()
    end)

function Handle_menu_input()
    if MENU_STATE.screen == MENU_SCREEN.start then
        -- Select an Option.
        if playdate.buttonJustReleased( playdate.kButtonRight ) then
            SOUND.menu_confirm:play()
            enter_menu_mission()
        end
        if playdate.buttonJustReleased( playdate.kButtonDown ) then
            SOUND.menu_confirm:play()
            enter_menu_credits()
        end

    elseif MENU_STATE.screen == MENU_SCREEN.mission then
        if playdate.buttonJustReleased( playdate.kButtonA ) then
            SOUND.menu_confirm:play()
            -- reset mystery potion
            Set_target_potion(MENU_STATE.focused_option + 1)
            Enter_gameplay()
        elseif playdate.buttonJustReleased( playdate.kButtonLeft ) and
        MENU_STATE.focused_option < 1 then
            SOUND.menu_confirm:play()
            Enter_menu_start()
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
        if crankTicks == 1 then
            MENU_STATE.focused_option += 1
        elseif crankTicks == -1 then
            MENU_STATE.focused_option -= 1
        end
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
        local scroll_speed = 1
        local auto_scroll_max = 1
        local auto_scroll_wind_up = 0.025
        local acceleratedChange = playdate.getCrankChange()

        -- Disable auto-scroll and start wind-up timer
        if math.abs(acceleratedChange) > 10 or
        playdate.buttonIsPressed( playdate.kButtonDown ) or
        playdate.buttonIsPressed( playdate.kButtonUp )
        then
            auto_scroll_enabled = false
            wind_up_timer:reset()
            wind_up_timer = playdate.timer.new(1*1000, function()
                auto_scroll_enabled = true
                end)
        end
        if auto_scroll_enabled then
            auto_scroll += auto_scroll_wind_up
            if auto_scroll > auto_scroll_max then
                auto_scroll = auto_scroll_max
            end
        else
            auto_scroll = 0
        end

        -- Calculate credit scroll
        local crankTicks = playdate.getCrankTicks(scroll_speed * 100)
        credits_y += -crankTicks - auto_scroll
        if playdate.buttonIsPressed( playdate.kButtonUp ) then
            credits_y += scroll_speed
        elseif playdate.buttonIsPressed( playdate.kButtonDown ) then
            credits_y += -scroll_speed
        end

        -- Limit scroll range
        if credits_y < -900 then
            credits_y = -900
        end

        -- Return to menu
        if credits_y > 0 or playdate.buttonJustReleased( playdate.kButtonB ) then
            credits_y = 0
            auto_scroll_enabled = true
            SOUND.menu_confirm:play()
            Enter_menu_start()
        end
    end
end


function Init_menus()

    UI_TEXTURES.start = gfxi.new("images/menu_start")
    UI_TEXTURES.mission = gfxi.new(1,1)  -- unused
    UI_TEXTURES.credits = gfxi.new(1,1)  -- unused
    UI_TEXTURES.credit_scroll = gfxi.new("images/menu_credits")

    MENU_STATE.screen = MENU_SCREEN.start
    MENU_STATE.active_screen_texture = UI_TEXTURES.start
    MENU_STATE.focused_option = 0
    MENU_STATE.first_option_in_view = 0

    -- Set the multiple things in their Z order of what overlaps what.
    Set_draw_pass(100, draw_ui) -- UI goes on top of everything.
end
