GYRO_X, GYRO_Y = 200, 120



-- Utility Functions

local function clamp(value, min, max)
    return math.max(math.min(value, max), min)
end



-- Resource Management


function Init_gameplay()
    -- Done only once on start of the game, to load and setup const resources.

    playdate.startAccelerometer()
end


function Stop_gameplay()
    -- Done on every game over/win to stop ongoing sounds and events.
    -- Not a complete tear down of resources.
end


function Reset_gameplay()
    -- Done on every (re)start of the play.
end



-- Update Loop

function Handle_input()
    local gravityX, gravityY, _gravityZ = playdate.readAccelerometer()
    GYRO_X = clamp(GYRO_X + gravityX * 10, 0, 400)
    GYRO_Y = clamp(GYRO_Y + gravityY * 10, 0, 240)

    if playdate.buttonIsPressed( playdate.kButtonA ) then
        if not SOUND.cat_meow:isPlaying() then
            SOUND.cat_meow:play()
        end
        print("Hello!")
    end
end

