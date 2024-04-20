GYRO_X, GYRO_Y = 200, 120

GAMEPLAY_STATE = {
    flame_amount = 0.0,
    water_amount = 0.0,
    -- Potion mix?
    potion_color = 0.5,
    potion_bubbliness = 0.0,
    -- TODO: elements ratio
    game_tick = 0,
}

-- Stir meter goes from 0 to 100
STIR_METER = 0

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

    for _, ingredient in ipairs(INGREDIENTS) do
        ingredient:remove()
    end
    INGREDIENTS = {}
end



-- Update Loop
--- `timeDelta` is the time in seconds since the last update.
---@param timeDelta number
function Handle_input(timeDelta)
    local gravityX, gravityY, _gravityZ = playdate.readAccelerometer()
    GYRO_X = Clamp(GYRO_X + gravityX * 10, 0, 400)
    GYRO_Y = Clamp(GYRO_Y + gravityY * 10, 0, 240)

    if playdate.buttonIsPressed( playdate.kButtonA ) then
        if not SOUND.cat_meow:isPlaying() then
            SOUND.cat_meow:play()
        end
        print("Hello!")
    end

    local angleDelta, _ = playdate.getCrankChange()
    local revolutionsPerSecond = math.abs(angleDelta) / 360 / timeDelta
    local decaySpeed = 5
    STIR_METER += revolutionsPerSecond * 3 - decaySpeed
    STIR_METER = math.max(STIR_METER, 0)
    STIR_METER = math.min(STIR_METER, 100)

    if playdate.buttonIsPressed( playdate.kButtonB ) then
        GAMEPLAY_STATE.flame_amount += 1
    end
end


function Tick_gameplay()
    GAMEPLAY_STATE.game_tick += 1
    -- Update ingredient animations.
    for _, ingredient in ipairs(INGREDIENTS) do
        if ingredient:isVisible() then
            ingredient:tick()
        end
    end

    if not playdate.buttonIsPressed( playdate.kButtonB ) then
        GAMEPLAY_STATE.flame_amount -= 1
        if GAMEPLAY_STATE.flame_amount < 0 then
            GAMEPLAY_STATE.flame_amount = 0
        end
    end
end

