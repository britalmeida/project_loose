local FROG_STATE = { idle = 0, speaking = 1, cooldown = 2 }
local THINGS_TO_REMEMBER <const> = { none = 0, fire = 1, stir = 2, secret_ingredient = 3 }

local frog_state = FROG_STATE.waiting
local last_topic_hint = THINGS_TO_REMEMBER.none
local current_topic_hint = THINGS_TO_REMEMBER.none
local current_rune_hint = 1
local rune_offset = 1
local current_stirr_hint = 1
local stirr_offset = 1
local last_sentence = -1
local current_sentence = -1
SHOWN_STRING = ""

local positive_acceptance <const> = "that'll do it!"
local forgotten_topics_callouts <const> = {
    "hey, you forgot the fire",
    "hey, you forgot to stir",
    "hey, you forgot an ingredient",
}
local fire_reminders <const> = {
    {"seriously, gently blow the fire", "your potion won't cook without fire. just sayin'"},
    {"just blow air onto the\nbottom of the cauldron"},
    {"for realz, blow air.\ntryyyy it!"},
}

local stirr_reminders <const> = {
    {"Waaaaay too dark\ncrank it the other way", "The liquid looks too dark\nstirr!", "Just a lil'bit too dark"}, -- 1 == too dark
    {"Oh my eyes!\nLiquid is way too bright", "The liquid looks too bright\nstirr!", "Just a lil'bit too light"} -- 2 = too bright
}

local ingredient_reminders <const> = {
    {"Too much love\ncan't stand it!", "Add some passion?"}, -- 1 = heart
    {"Definitely missing happy stuff", "Missing doom and gloom"}, -- 2 = doom
    {"What a tangle :/", "Add some veggies"}, -- 3 = weeds
}


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
    playdate.timer.new(0.1*1000, function()
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
    playdate.timer.new(2*1000, function()
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
    local rune_diff = (math.abs(rune_per_component_diff[1]) + math.abs(rune_per_component_diff[2]) + math.abs(rune_per_component_diff[3])) * 0.5

    -- Check for new priority of thing that is off target.
    last_topic_hint = current_topic_hint

    -- viscosity is not an active target now.
    viscous_diff = 0

    local tolerance = 0.1
    if color_diff < tolerance and viscous_diff < tolerance and rune_diff < tolerance then
        current_topic_hint = -1
    elseif color_diff > viscous_diff and color_diff > rune_diff then
        current_topic_hint = THINGS_TO_REMEMBER.stir
        -- clockwise makes it more 1
        if (TARGET_COCKTAIL.color - GAMEPLAY_STATE.potion_color) < 0.0 then
            current_stirr_hint = 2
        else
            current_stirr_hint = 1
        end
        local abs_diff = math.abs(TARGET_COCKTAIL.color - GAMEPLAY_STATE.potion_color)
        if abs_diff < 0.3 then
            stirr_offset = 3
        elseif abs_diff < 0.75 then
            stirr_offset = 2
        else
            stirr_offset = 1
        end
    elseif viscous_diff > color_diff and viscous_diff > rune_diff then
        current_topic_hint = THINGS_TO_REMEMBER.fire
    else
        current_topic_hint = THINGS_TO_REMEMBER.secret_ingredient
        if math.abs(rune_per_component_diff[1]) >= math.abs(rune_per_component_diff[2]) and math.abs(rune_per_component_diff[1]) >= math.abs(rune_per_component_diff[3]) then
            current_rune_hint = 1
        elseif math.abs(rune_per_component_diff[2]) >= math.abs(rune_per_component_diff[1]) and math.abs(rune_per_component_diff[2]) >= math.abs(rune_per_component_diff[3]) then
            current_rune_hint = 2
        else
            current_rune_hint = 3
        end
        if rune_per_component_diff[current_rune_hint] < 0 then
            rune_offset = 1
        else
            rune_offset = 2
        end
    end

    print("froggo thinks priority is "..current_topic_hint.." diffs: v:"..tostring(viscous_diff).." c:"..tostring(color_diff).." r:"..tostring(rune_diff).." becaaause "..rune_per_component_diff[1]..","..rune_per_component_diff[2]..","..rune_per_component_diff[3])

    if last_topic_hint ~= current_topic_hint then
        last_sentence = -1
    end
    -- Counting time with no flame. As soon as there is flame, restart.
    --if playdate.sound.micinput.getLevel() > 0.1 then
    --    days_without_fire_timer:reset()
    --end
end


function set_current_sentence()

    last_sentence = current_sentence
    current_sentence = -1

    froggo_reality_check()

    if current_topic_hint == -1 then
        -- Potion approved!
        current_sentence = -2
        return
    elseif current_topic_hint == THINGS_TO_REMEMBER.fire then
        if last_sentence == -1 then
            current_sentence = 0
        elseif last_sentence < 3 then
            current_sentence = last_sentence + 1
        end
    elseif current_topic_hint == THINGS_TO_REMEMBER.stir then
        if last_sentence == -1 then
            current_sentence = 0
        else
            current_sentence = 1
        end
    elseif current_topic_hint == THINGS_TO_REMEMBER.secret_ingredient then
        if last_sentence == -1 then
            current_sentence = 0
        else
            current_sentence = 1
        end
    end
end


function set_speech_bubble_content()
    if current_sentence == -1 then
        -- Disable speech bubble.
        SHOWN_STRING = ""
    else
        if current_sentence == 0 then
            -- Hinting a topic for the first time.
            SHOWN_STRING = forgotten_topics_callouts[current_topic_hint]
        elseif current_sentence == -2 then
            -- Won the game.
            SHOWN_STRING = positive_acceptance
        else
            if current_topic_hint == THINGS_TO_REMEMBER.fire then
                SHOWN_STRING = fire_reminders[current_sentence][1]
            elseif current_topic_hint == THINGS_TO_REMEMBER.stir then
                SHOWN_STRING = stirr_reminders[current_stirr_hint][stirr_offset]
            elseif current_topic_hint == THINGS_TO_REMEMBER.secret_ingredient then
                SHOWN_STRING = ingredient_reminders[current_rune_hint][rune_offset]
            end
        end
        print(SHOWN_STRING)
    end
end


-- ><
function Tick_frog()
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