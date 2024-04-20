import "CoreLibs/crank"
import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

import "sound"
import "gameplay"
import "visuals"
import "menu"


local gfx <const> = playdate.graphics
frame_ms = 1000 / 30


function initialize()
    -- Start all systems needed by the game to start ticking

    -- Make it different, every time!
    math.randomseed(playdate.getSecondsSinceEpoch())

    -- Init all the things!
    init_gameplay()
    init_visuals()
    init_menus()
end

initialize()
-- For testing, enter gameplay directly.
--enter_menu_start()
enter_gameplay()


function playdate.update()
    -- Called before every frame is drawn.

    if MENU_STATE.menu_screen ~= MENU_SCREEN.gameplay then
        -- In Menu system.
        handle_menu_input()
    end
    -- Intentionally check again (no else), the menu might have just started gameplay
    if MENU_STATE.menu_screen == MENU_SCREEN.gameplay then
        -- In gameplay.
        handle_input()
    end

    -- Always redraw and update entities (sprites) and timers.
    gfx.clear()
    gfx.sprite.update()
    playdate.timer.updateTimers()
end
