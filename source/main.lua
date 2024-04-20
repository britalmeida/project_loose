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


local gfx <const> = playdate.graphics
frame_ms = 1000 / 30


local function initialize()
    -- Start all systems needed by the game to start ticking

    -- Make it different, every time!
    math.randomseed(playdate.getSecondsSinceEpoch())

    -- Init all the things!
    Init_gameplay()
    Init_visuals()
    Init_menus()

    -- Reset time delta
    playdate.resetElapsedTime()
end

initialize()
-- For testing, enter gameplay directly.
--enter_menu_start()
Enter_gameplay()


function playdate.update()
    -- Called before every frame is drawn.
    local timeDelta = playdate.getElapsedTime()

    if MENU_STATE.screen ~= MENU_SCREEN.gameplay then
        -- In Menu system.
        Handle_menu_input()
    end
    -- Intentionally check again (no else), the menu might have just started gameplay
    if MENU_STATE.screen == MENU_SCREEN.gameplay then
        -- In gameplay.
        Handle_input(timeDelta)
        Tick_gameplay()
    end

    -- Always redraw and update entities (sprites) and timers.
    gfx.clear()
    gfx.sprite.update()
    playdate.timer.updateTimers()

    playdate.resetElapsedTime()
end
