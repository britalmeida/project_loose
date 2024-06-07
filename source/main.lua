import "CoreLibs/animation"
import "CoreLibs/crank"
import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "CoreLibs/utilities/sampler"

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
frame_ms = 1000 / 30

playdate.display.setRefreshRate(0)
local last_time = playdate.getElapsedTime()
local total_frames_menu = 0
local total_frames_gamep = 0
local max_frame_time_menu = 0
local max_frame_time_gamep = 0
local avg_frame_time_menu = 0
local avg_frame_time_gamep = 0


local function initialize()

    -- Start all systems needed by the game to start ticking
    playdate.sound.micinput.startListening()

    -- Make it different, every time!
    math.randomseed(playdate.getSecondsSinceEpoch())

    -- Init all the things!
    Init_gameplay()
    Init_visuals()
    Init_menus()

    playdate.resetElapsedTime()
end

-- Start the game: initialize resources and enter the menu or gameplay.
initialize()
Enter_menu_start(0, 0, true)
--Enter_gameplay() -- For testing, enter gameplay directly.

print("Initialized in ".. playdate.getElapsedTime() - last_time.." seconds")
last_time = playdate.getElapsedTime()


function playdate.deviceDidUnlock()
    -- Seems like the playdate disables the mic when locked.
    -- So we need to turn it on again when we resume the game
    playdate.sound.micinput.startListening()
end


function playdate.update()
    -- Called before every frame is drawn.
    sample("update", function()

    -- Calculate performance statistics.
    -- local time = playdate.getElapsedTime()
    -- local delta = time - last_time
    -- last_time = time
    -- if delta > 0 then
    --     if MENU_STATE.screen == MENU_SCREEN.gameplay then
    --         max_frame_time_gamep = math.max(max_frame_time_gamep, delta)
    --         total_frames_gamep += 1
    --         weight = (1 / total_frames_gamep)
    --         avg_frame_time_gamep = (1 - weight) * avg_frame_time_gamep + weight * delta
    --     else
    --         max_frame_time_menu = math.max(max_frame_time_menu, delta)
    --         total_frames_menu += 1
    --         weight = (1 / total_frames_menu)
    --         avg_frame_time_menu = (1 - weight) * avg_frame_time_menu + weight * delta
    --     end
    -- end
    -- print("frame time ".. delta * 1000 ..
    --     " ms    | menu avg: "..avg_frame_time_menu*1000 .." max: "..max_frame_time_menu*1000 ..
    --     "| game avg: "..avg_frame_time_gamep*1000 .." max: "..max_frame_time_gamep*1000)

    sample("-logic", function()

    if MENU_STATE.screen ~= MENU_SCREEN.gameplay then
        -- In Menu system.
        Handle_menu_input()
    end
    -- Intentionally check again (no else), the menu might have just started gameplay
    if MENU_STATE.screen == MENU_SCREEN.gameplay then
        -- In gameplay.
        sample("--input", function()
        Handle_input()
        end)
        sample("--tick_game", function()
        Tick_gameplay()
        end)
        sample("--calc score", function()
        Calculate_goodness()
        Check_player_learnings()
        Check_player_struggle()
        end)
    end

    end)

    -- Always redraw and update entities (sprites) and timers.
    gfx.clear()

    sample("-sprites", function()
    gfx.sprite.update()
    end)

    playdate.timer.updateTimers()

    end)
end
