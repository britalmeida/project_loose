import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"


function init_gameplay()
    -- Done only once on start of the game, to load and setup const resources.
end


function reset_gameplay()
    -- Done on every (re)start of the play.
end


function handle_input()
    -- Left/Right button switches the active arm.
    if playdate.buttonIsPressed( playdate.kButtonA ) then
        print("Hello!")
    end
end

