
-- Resource Management


function init_gameplay()
    -- Done only once on start of the game, to load and setup const resources.
end


function stop_gameplay()
    -- Done on every game over/win to stop ongoing sounds and events.
    -- Not a complete tear down of resources.
end


function reset_gameplay()
    -- Done on every (re)start of the play.
end



-- Update Loop

function handle_input()
    if playdate.buttonIsPressed( playdate.kButtonA ) then
        if not SOUND.cat_meow:isPlaying() then
            SOUND.cat_meow:play()
        end
        print("Hello!")
    end
end

