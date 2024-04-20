import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

import "gameplay"
import "visuals"

local gfx <const> = playdate.graphics
frame_ms = 1000 / 30


function initialize()
    -- Start all systems needed by the game to start ticking

    -- Make it different, every time!
    math.randomseed(playdate.getSecondsSinceEpoch())

    -- Init all the things!
    init_gameplay()
    init_visuals()
end

initialize()


function playdate.update()
    -- Called before every frame is drawn.

    playdate.drawFPS(0,0)

    -- In gameplay.
    handle_input()

    -- Always redraw and update entities (sprites) and timers.
    gfx.clear()
    gfx.sprite.update()
    playdate.timer.updateTimers()
end
