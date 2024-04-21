
local THINGS_TO_REMEMBER <const> = { none = -1, fire = 0, stir = 1, secret_ingredient = 2 }

local last_topic_hint = THINGS_TO_REMEMBER.none
local current_topic_hint = THINGS_TO_REMEMBER.none
local last_sentence = -1
local current_sentence = -1
SHOWN_STRING = ""

local positive_acceptance <const> = "that'll do it!"
local forgotten_topics_callouts <const> = {
    "",
    "hey, you forgot the fire",
    "hey, you forgot to stir",
    "hey, you forgot the cat",
}
local fire_reminders <const> = {
    {"seriously, gently blow the fire", "your potion won't cook without fire. just sayin'"},
    {"just blow air onto the\nbottom of the cauldron"},
    {"for realz, blow air.\ntryyyy it!"},
}


local speech_cooldown_timer
local days_without_fire_timer

-- ><
function Tick_frog()

    -- Counting time with no flame. As soon as there is flame, restart.
    if playdate.sound.micinput.getLevel() > 0.1 then
        days_without_fire_timer:reset()
    end

    if speech_cooldown_timer.value ~= 1 then
        return
    end

    last_sentence = current_sentence
    current_sentence = -1

    -- Silly hint progression
    if current_topic_hint == THINGS_TO_REMEMBER.none then

        -- When the fire is out for long, transition to fire.
        if days_without_fire_timer.value >= 1 then
            current_topic_hint = THINGS_TO_REMEMBER.fire
            current_sentence = 0
        end
    elseif current_topic_hint == THINGS_TO_REMEMBER.fire then

        -- If the player makes fire, transition back to good.
        if days_without_fire_timer.value < 1 then
            current_topic_hint = THINGS_TO_REMEMBER.none
            current_sentence = -2
        else

            if last_sentence < 3 then
                current_sentence = last_sentence + 1
            else
                playdate.timer.new(1.5*1000, function()
                    current_topic_hint = THINGS_TO_REMEMBER.secret_ingredient
                    current_sentence = 0
                end)
            end
        end
    end

    -- Speak!
    if current_sentence ~= -1 then
        if current_sentence == 0 then
            SHOWN_STRING = forgotten_topics_callouts[current_topic_hint+2]
        elseif current_sentence == -2 then
            SHOWN_STRING = positive_acceptance
        else
            SHOWN_STRING = fire_reminders[current_sentence][1]
        end
        print(SHOWN_STRING)
    else
        SHOWN_STRING = ""
    end
    playdate.timer.new(1.5*1000, function()
        SHOWN_STRING = ""
    end)

    -- And pause before speaking again.
    speech_cooldown_timer:reset()
end


function Reset_frog()
    last_topic_hint = THINGS_TO_REMEMBER.none
    current_topic_hint = THINGS_TO_REMEMBER.none
    last_sentence = -1
    current_sentence = -1
    SHOWN_STRING = ""

    if speech_cooldown_timer then
        speech_cooldown_timer:reset()
    end
    if days_without_fire_timer then
        days_without_fire_timer:reset()
    end
end


function Init_frog()

    speech_cooldown_timer = playdate.timer.new(7*1000, 0, 1)
    speech_cooldown_timer.discardOnCompletion = false
    days_without_fire_timer = playdate.timer.new(5*1000, 0, 1)
end