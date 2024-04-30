local gfx <const> = playdate.graphics
local gfxi <const> = playdate.graphics.image

MENU_STATE = {}
MENU_SCREEN = { gameplay = 0, start = 2, mission = 3, credits = 4 }
local UI_TEXTURES = {}
local NUM_VISIBLE_MISSIONS = 2 -- Number of cocktails fully visible in the mission selection, others are (half) clipped.

-- System Menu

local function add_system_menu_entries()

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

local function remove_system_menu_entries()
    playdate.getSystemMenu():removeAllMenuItems()
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

    add_system_menu_entries()
    Reroll_mystery_potion()
    Reset_gameplay()
end



-- Draw & Update

local function draw_ui()
    if MENU_STATE.screen == MENU_SCREEN.gameplay then
        return
    end

    -- In menus. The gameplay is inactive.

    -- Draw background screen image.
    MENU_STATE.active_screen_texture:draw(0, 0)

    -- Start menu draws a selected option indicator.
    if MENU_STATE.screen == MENU_SCREEN.start then
        gfx.pushContext()
                UI_TEXTURES.start_right_select:draw(0, 0)
                UI_TEXTURES.start_left_select:draw(0, 0)
        gfx.popContext()

    -- Draw mission selection options.
    elseif MENU_STATE.screen == MENU_SCREEN.mission then
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
                    cocktail.img:draw(first_cocktail_x + cocktail_width * cocktail_relative_to_window, 0)
                end
            end
            -- Draw current option indicator
            gfx.setColor(gfx.kColorWhite)
            gfx.setLineWidth(3.0)
            local focus_relative_to_window = MENU_STATE.focused_option - MENU_STATE.first_option_in_view +1
            gfx.drawRect(first_cocktail_x + cocktail_width * focus_relative_to_window, 0, 120, 240)
        gfx.popContext()
    end
end


function Handle_menu_input()
    if MENU_STATE.screen == MENU_SCREEN.start then
        -- Select an Option.
        if playdate.buttonJustReleased( playdate.kButtonA ) then
            SOUND.menu_confirm:play()
            enter_menu_mission()
        end
        if playdate.buttonJustReleased( playdate.kButtonB ) then
            SOUND.menu_confirm:play()
            enter_menu_credits()
        end

    elseif MENU_STATE.screen == MENU_SCREEN.mission then
        if playdate.buttonJustReleased( playdate.kButtonA ) then
            SOUND.menu_confirm:play()
            -- reset mystery potion
            Set_target_potion(MENU_STATE.focused_option + 1)
            Enter_gameplay()
        elseif playdate.buttonJustReleased( playdate.kButtonB ) then
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
        if playdate.buttonJustReleased( playdate.kButtonB ) then
            SOUND.menu_confirm:play()
            Enter_menu_start()
        end
    end
end


function Init_menus()

    UI_TEXTURES.start = gfxi.new("images/menu_start")
    UI_TEXTURES.mission = gfxi.new(1,1)  -- unused
    UI_TEXTURES.credits = gfxi.new("images/menu_credits")

    UI_TEXTURES.start_left_select = gfxi.new("images/menu_start_left")
    UI_TEXTURES.start_right_select = gfxi.new("images/menu_start_right")

    MENU_STATE.screen = MENU_SCREEN.start
    MENU_STATE.active_screen_texture = UI_TEXTURES.start
    MENU_STATE.focused_option = 0
    MENU_STATE.first_option_in_view = 0

    -- Set the multiple things in their Z order of what overlaps what.
    Set_draw_pass(100, draw_ui) -- UI goes on top of everything.
end
