
function init_gameplay()
    -- Done only once on start of the game, to load and setup const resources.
end


function reset_gameplay()
    -- Done on every (re)start of the play.
end


function handle_input()
    if playdate.buttonIsPressed( playdate.kButtonA ) then
        if not SOUND.cat_meow:isPlaying() then
            SOUND.cat_meow:play()
        end
        print("Hello!")
    end
end

