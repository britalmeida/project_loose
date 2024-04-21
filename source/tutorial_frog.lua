local FROG_STATE = { idle = 0, speaking = 1, cooldown = 2 }
local THINGS_TO_REMEMBER <const> = { none = 0, fire = 1, stir = 2, secret_ingredient = 3 }

local frog_state = FROG_STATE.waiting
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


-- Events for transition
function Ask_the_frog()
    if frog_state == FROG_STATE.idle then
        -- Start speaking
        croak()
    end
end

function Enter_cooldown()
    frog_state = FROG_STATE.cooldown

    -- Give the frog a short moment to breathe before speaking again.
    playdate.timer.new(1*1000, function()
        frog_state = FROG_STATE.idle
    end)
end

-- Actions

function croak()
    -- Speak!
    frog_state = FROG_STATE.speaking
    set_current_sentence()
    set_speech_bubble_content()

    -- Disable speech bubble after a short moment.
    playdate.timer.new(1.5*1000, function()
        SHOWN_STRING = ""
        Enter_cooldown()
    end)
end


function froggo_reality_check()
    -- Match expectations with reality.
    local color_diff = math.abs(TARGET_COCKTAIL.color - GAMEPLAY_STATE.potion_color)
    local viscous_diff = math.abs(TARGET_COCKTAIL.viscosity - GAMEPLAY_STATE.liquid_viscosity)
    local rune_per_component_diff = {
        TARGET_COCKTAIL.rune_ratio[1] - GAMEPLAY_STATE.rune_ratio[1],
        TARGET_COCKTAIL.rune_ratio[2] - GAMEPLAY_STATE.rune_ratio[2],
        TARGET_COCKTAIL.rune_ratio[3] - GAMEPLAY_STATE.rune_ratio[3],
    }
    local rune_diff = math.abs((rune_per_component_diff[1] + rune_per_component_diff[2] + rune_per_component_diff[3]) * 0.5)

    local tolerance = 0.1
    if color_diff > viscous_diff and color_diff > rune_diff then
        current_topic_hint = THINGS_TO_REMEMBER.stir
    elseif viscous_diff > color_diff and viscous_diff > rune_diff then
        current_topic_hint = THINGS_TO_REMEMBER.fire
    elseif color_diff < tolerance and viscous_diff < tolerance and rune_diff < tolerance then
        current_topic_hint = -1
    else
        current_topic_hint = THINGS_TO_REMEMBER.secret_ingredient
    end

    --print("froggo thinks priority is "..current_topic_hint.." diffs: c:"..tostring(color_diff).." v:"..tostring(viscous_diff).." r:"..tostring(rune_diff).." becaaause "..rune_per_component_diff[1]..","..rune_per_component_diff[2]..","..rune_per_component_diff[3])

    -- Counting time with no flame. As soon as there is flame, restart.
    --if playdate.sound.micinput.getLevel() > 0.1 then
    --    days_without_fire_timer:reset()
    --end
end


function set_current_sentence()

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
end


function set_speech_bubble_content()
    if current_sentence ~= -1 then
        if current_sentence == 0 then
            SHOWN_STRING = forgotten_topics_callouts[current_topic_hint]
        elseif current_sentence == -2 then
            SHOWN_STRING = positive_acceptance
        else
            SHOWN_STRING = fire_reminders[current_sentence][1]
        end
        print(SHOWN_STRING)
    else
        SHOWN_STRING = ""
    end
end


-- ><
function Tick_frog()
    froggo_reality_check()
end


function Reset_frog()
    frog_state = FROG_STATE.idle

    last_topic_hint = THINGS_TO_REMEMBER.none
    current_topic_hint = THINGS_TO_REMEMBER.none
    last_sentence = -1
    current_sentence = -1
    SHOWN_STRING = ""

    if days_without_fire_timer then
        days_without_fire_timer:reset()
    end
end


function Init_frog()
    days_without_fire_timer = playdate.timer.new(5*1000, 0, 1)
end