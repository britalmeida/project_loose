import "CoreLibs/animation"
import "CoreLibs/crank"
import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

import "utils"
import "sound"
import "gameplay"
import "visuals"
import "menu"
import "ingredients"
import "recipe_book"
import "cocktail_manager"
import "tutorial_frog"


local gfx <const> = playdate.graphics

TARGET_FPS = 30
frame_ms = 1000 / TARGET_FPS
playdate.display.setRefreshRate(TARGET_FPS)



local function initialize()
    -- Start all systems needed by the game to start ticking

    -- Make it different, every time!
    math.randomseed(playdate.getSecondsSinceEpoch())

    -- Microphone is off by default, needs manual enabling.
    playdate.sound.micinput.startListening()

    -- Init all the things!
    Init_gameplay()
    Init_visuals()
    Init_menus()
    Init_sounds()

    -- Start counting time.
    playdate.resetElapsedTime()
end

-- Start the game: initialize resources and enter the menu or gameplay.
initialize()
Enter_loading_screen()
--Enter_gameplay() -- For testing, enter gameplay directly.


function playdate.deviceDidUnlock()
    -- Seems like the playdate disables the mic when locked.
    -- So we need to turn it on again when we resume the game
    playdate.sound.micinput.startListening()
end


function playdate.update()
    -- Called every frame.

    -- Handle logic.
    if MENU_STATE.screen == MENU_SCREEN.launch then
        -- Wait for launch to finish
    elseif MENU_STATE.screen ~= MENU_SCREEN.gameplay then
        -- In Menu system.
        Handle_menu_input()
    end
    -- Intentionally check again (no else), the menu might have just started gameplay
    if MENU_STATE.screen == MENU_SCREEN.gameplay then
        -- In gameplay.
        Handle_gameplay_input()
        Tick_gameplay()
        Calculate_goodness()
        Check_player_learnings()
        Check_player_struggle()

    end

    -- Redraw
    gfx.clear()
    if MENU_STATE.screen == MENU_SCREEN.gameplay then
        -- The gameplay draws via Playdate's sprite system.
        gfx.sprite.update()
    else
        Draw_menu()
    end

    -- Always update timers.
    playdate.timer.updateTimers()
end
