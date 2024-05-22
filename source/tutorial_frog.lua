local gfx <const> = playdate.graphics
local gfxit <const> = playdate.graphics.imagetable
local Sprite <const> = gfx.sprite
local animloop <const> = playdate.graphics.animation.loop


-- Froggo state machine
--- The Action State indicates what the frog is currently doing, e.g. speaking or emoting/reacting.
--- It ensures animations play to completion, and valid transitions (e.g. no emoting when already speaking).
--- The Frog is always in one and only one state and changes state on events (e.g. player pressed B, time passed).
local ACTION_STATE <const> = { idle = 0, speaking = 1, reacting = 2, drinking = 3 }

-- Froggo content machine
--- A separate multi-level state machine to select the sentence the frog says when speaking.
local TUTORIAL_STATE <const> = { start = 1, fire = 1, grab = 2, shake = 3, stir = 4, complete = 5 }

local positive_acceptance <const> = "That'll do it!"
local forgotten_topics_callouts <const> = {
    "Blow to stoke up the fire\npuff puff puff!",
    "Hey, you forgot an ingredient.",
    "Hey, you forgot to stir.",
}
local fire_reminders <const> = {
    "Hey... the fire is getting low.",
    "Keep it warm to see \nthe magic.",
    "Fire is good, glow is good.",
    "9",
}
local fire_tutorials <const> = {
    "Magical brews need fire\nto reveal their magic.",
    "Just blow air onto the\nbottom of the cauldron.",
    "10",
    "For realz, blow air\non the mic.\nTryyyy it!",
}
local fire_tips <const> = {
    "No need to stoke\nthe fire this often.",
    "Save your breath!\nLeave it for a bit.",
}
local stir_tutorials_color <const> = {
    "Remember the importance of\nthe stirring direction.",
    "Use the crank to stir?",
    "11", "12",
}
local need_more_bright <const> = {
    "Oh my eyes!\nLiquid is way too bright.",
    "The liquid looks too bright.\nStirr!",
    "Just a lil'bit too light.",
}
local need_less_bright <const> = {
    "Waaaaay too dark!\nCrank it the other way.",
    "The liquid looks too dark\nstirr!",
    "Just a lil'bit too dark.",
}
local stir_tutorials <const> = {
    "Stirring helps after\nusing ingredients.",
    "Stir to see if you've\ngot it right.",
    "Use the crank to stir.",
    "11",
}
local stir_tips <const> = {
    "No need to stir that much.",
    "The ingredients already sank.",
}
local need_more_stir <const> = {
    "I can't tell yet.\nTry stirring!",
    "The ingredients need\nto be fully stirred in!",
    "11",
}
local need_more_love <const> = {
    "That brew needs more heart!", "2",
}
local need_less_love <const> = {
    "Can't stand the love!\nThrow something vile in!", "1",
}
local need_more_doom <const> = {
    "Missing doom and gloom.", "4",
}
local need_less_doom <const> = {
    "Too grim . . .\nEvil repellent may work?",  "3",
}
local need_more_weed <const> = {
    "Could use some veggies.",  "6",
}
local need_less_weed <const> = {
    "Too many plants in there!\nBetter get rid of that.", "5",
}
local grab_tutorials <const> = {
    "Try grabbing an ingredient.",
    "Tilt to hover an ingredient.\nHold (A) to grab.",
}
local drop_tutorials <const> = {
    "Place the ingredient over\nthe cauldron and shake!",
    "Shake, shake. Shake it off!!",
    "13",
}
local drop_tips <const> = {
    "Seems a bit excessive . . .\nLess shaking is also fine.",
    "Remember to stir ingredients in.",
    "11",
}
local recipe_struggle <const> = {
    "Maybe double check how\nthe cocktail looks like?",
    "There's no such thing as\ntoo many ingredients.",
    "That's quite a brew . . .\nMagical symbols can guide you.",
    "Imagine how the ingredients\nmatch the three magical aspects.",
}

local sayings <const> = {
    tutorial = { fire_tutorials, grab_tutorials, drop_tutorials, stir_tutorials }, -- fires, grab, shake, stir
    once = forgotten_topics_callouts,
    help = {
        fire = fire_reminders,
        ingredient = {
            { need_less_love, need_more_love },
            { need_less_doom, need_more_doom },
            { need_less_weed, need_more_weed },
        },
        color = { need_less_bright, need_more_bright }, -- too_dark, too_bright
        stir = need_more_stir
    },
    struggle = {
        fire = { fire_tutorials, fire_tips},
        drop = { drop_tutorials, drop_tips},
        stir = { stir_tutorials, stir_tips},
        recipe = recipe_struggle,
    }
}

SPEECH_BUBBLE_ANIM_IMGS = {
    -- The order of these need to match the string number used in the sentence categories.
    { gfxit.new("images/speech/animation-lesslove"),   8 }, -- "1"
    { gfxit.new("images/speech/animation-morelove"),   8 }, -- "2"
    { gfxit.new("images/speech/animation-lessdoom"),   8 }, -- "3"
    { gfxit.new("images/speech/animation-moredoom"),   8 }, -- "4"
    { gfxit.new("images/speech/animation-lessweed"),   8 }, -- "5"
    { gfxit.new("images/speech/animation-moreweed"),   8 }, -- "6"
    { gfxit.new("images/speech/animation-moredark"),   8 }, -- "7"
    { gfxit.new("images/speech/animation-morebright"), 8 }, -- "8"
    { gfxit.new("images/speech/animation-morefire"),   5 }, -- "9"
    { gfxit.new("images/speech/animation-blow"),       5 }, -- "10"
    { gfxit.new("images/speech/animation-crankcw"),    5 }, -- "11"
    { gfxit.new("images/speech/animation-crankccw"),   5 }, -- "12"
    { gfxit.new("images/speech/animation-shake"),      7 }, -- "13"
}



class('Froggo').extends(Sprite)
Froggo = NewSubClass("Froggo", Sprite)

function Froggo:init()
    Froggo.super.init(self)

    -- Load animation images and initialize animation state.
    self.anim_current = nil
    self.anim_idle       = animloop.new(16 * frame_ms, gfxit.new('images/frog/animation-idle'), true)
    self.anim_headshake  = animloop.new(8 * frame_ms, gfxit.new('images/frog/animation-headshake'), true)
    self.anim_happy      = animloop.new(8 * frame_ms, gfxit.new('images/frog/animation-excited'), true)
    self.anim_cocktail   = animloop.new(8 * frame_ms, gfxit.new('images/frog/animation-cocktail'), true)
    self.anim_burp       = animloop.new(8 * frame_ms, gfxit.new('images/frog/animation-burp'), false)
    self.anim_burptalk   = animloop.new(8 * frame_ms, gfxit.new('images/frog/animation-burptalk'), true)
    self.anim_blabla     = animloop.new(8 * frame_ms, gfxit.new('images/frog/animation-blabla'), true)
    self.anim_tickleface = animloop.new(2.5 * frame_ms, gfxit.new('images/frog/animation-tickleface'), false)
    self.anim_eyeball    = animloop.new(4 * frame_ms, gfxit.new('images/frog/animation-eyeball'), true)
    self.anim_frogfire   = animloop.new(4 * frame_ms, gfxit.new('images/frog/animation-frogfire'), true)

    self.x_offset = 0

    self:setZIndex(Z_DEPTH.frog)

    self:addSprite()
    self:setVisible(true)

    self:reset()
end


function Froggo:reset()
    -- Reset frog action state machine.
    self:go_idle()
    self.x_offset = 0

    -- Reset speech content state machine.
    self.tutorial_state = TUTORIAL_STATE.start
    self.has_said_once_reminders = { false, false, false } -- fire, stir, ingredient
    self.last_spoken_sentence_topic = nil
    self.last_spoken_sentence_pool = nil
    self.last_spoken_sentence_cycle_idx = 0
    self.last_spoken_sentence_str = ""

    -- Reset speech Bubble state used by draw_dialog_bubble().
    self:stop_speech_bubble()
end


function Froggo:start_animation(anim_loop)
    self.x_offset = 0
    self.anim_current = anim_loop
    self.anim_current.frame = 1  -- Restart the animation from the beggining
end



-- Events for transition

function Froggo:Ask_the_frog()
    if self.state == ACTION_STATE.idle then
        -- Start speaking
        self:think()
        self:croak()
    end
end


function Froggo:Ask_for_cocktail()
    self.last_spoken_sentence_str = string.format("One \"%s\", please!", COCKTAILS[TARGET_COCKTAIL.type_idx].name)
    self:croak()
end


function Froggo:Click_the_frog()
    local bounds = self:getBoundsRect()
    -- Make it a bit smaller, so we don't accedentially click on the frog
    bounds:inset(15, 15)
    if bounds:containsPoint(GYRO_X, GYRO_Y) and self.state == ACTION_STATE.idle then
        self:froggo_tickleface()
    end
end


function Froggo:Notify_the_frog()
    -- notify the frog when significant change happened
    if self.state == ACTION_STATE.idle then
            -- React to a state change
            self:froggo_react()
    end
end

function Froggo:Lick_eyeballs()
    if self.state == ACTION_STATE.idle then
        -- continueously lick eyeballs or react
        if Is_potion_good_enough() and DELICIOUS_CHECK then
            self:start_animation(self.anim_eyeball)
            self.x_offset = -11
            DELICIOUS_CHECK = false
        end
    end
end


function Froggo:fire_reaction()
    self.state = ACTION_STATE.reacting
        self:start_animation(self.anim_frogfire)

        playdate.timer.new(2*1000, function()
        self:go_idle()
        DELICIOUS_CHECK = true
    end)
end


function Froggo:go_idle()
    self.state = ACTION_STATE.idle
    self:start_animation(self.anim_idle)
end


function Froggo:go_reacting()
    self.state = ACTION_STATE.reacting

    if TREND > 0 then
        self:start_animation(self.anim_happy)
        DELICIOUS_CHECK = false
    elseif TREND < 0 then
        self:start_animation(self.anim_headshake)
        DELICIOUS_CHECK = false
    end

end


function Froggo:froggo_tickleface()
    self.state = ACTION_STATE.reacting
    self:start_animation(self.anim_tickleface)

    playdate.timer.new(2.9*1000, function()
        self:go_idle()
        DELICIOUS_CHECK = true
    end)
end


function Froggo:go_drinking()
    local cocktail_runtime = frame_ms * anim_cocktail_framerate * anim_cocktail_imgs:getLength()
    local burp_runtime = frame_ms * anim_burp_framerate * anim_burp_imgs:getLength()

    self.state = ACTION_STATE.drinking
    self:start_animation(self.anim_cocktail)

    playdate.timer.new(cocktail_runtime, function() -- 3168 ms
        self:start_animation(self.anim_burp)

        playdate.timer.new(burp_runtime, function() -- 4224 ms
            self:start_animation(self.anim_burptalk)
            self:start_speech_bubble()

            playdate.timer.new(2*1000, function() -- 4224 ms
                -- Disable speech bubble after a short moment.
                self:stop_speech_bubble()
                self:start_animation(self.anim_cocktail)
                GAMEPLAY_STATE.showing_recipe = true
            end)
        end)
    end)

end



-- Actions

function Froggo:croak()
    -- Speak!
    self.state = ACTION_STATE.speaking

    if GAME_ENDED then
        -- The potion is correct!
        self:go_drinking()
    else
        self:start_animation(self.anim_blabla)

        self:start_speech_bubble()

        playdate.timer.new(3*1000, function()
            -- Disable speech bubble after a short moment.
            self:stop_speech_bubble()
            self:go_idle()

        end)
    end
end


function Froggo:froggo_react()
    self.state = ACTION_STATE.reacting

    self:go_reacting()
    playdate.timer.new(2*1000, function()
        self:go_idle()
    end)
end



-- Sentences and Speech Bubble

-- Select what should the frog say, adjust sentence state and trigger the speech bubble.
function Froggo:think()

    -- Check if the potion is approved and early out!
    if Is_potion_good_enough() then
        Win_game()
        Reset_ingredients()
        self.last_spoken_sentence_str = positive_acceptance
        return
    end

    -- Check what the player has already done and advance tutorial steps.
    -- Intentional fallthrough, so that the frog advances as many tutorial steps as needed in one go.
    if self.tutorial_state == TUTORIAL_STATE.fire then
        if PLAYER_LEARNED.how_to_fire then
            self.tutorial_state += 1
        end
    end
    if self.tutorial_state == TUTORIAL_STATE.grab then
        if PLAYER_LEARNED.how_to_grab and PLAYER_LEARNED.how_to_release then
            self.tutorial_state += 1
        end
    end
    if self.tutorial_state == TUTORIAL_STATE.shake then
        if PLAYER_LEARNED.how_to_shake then
            self.tutorial_state += 1
        end
    end
    if self.tutorial_state == TUTORIAL_STATE.stir then
        if PLAYER_LEARNED.how_to_stir then
            self.tutorial_state += 1
        end
    end


    if self.tutorial_state ~= TUTORIAL_STATE.complete then
        -- Froggo is teaching.

        local idx = self.tutorial_state

        -- Say things like "You forgot an ingredient!" first and only once.
        if idx < #sayings.once and not self.has_said_once_reminders[idx] then
            self:select_sentence(sayings.once, idx)
            self.has_said_once_reminders[idx] = true
        else
            -- Loop throught the sentences for this tutorial step.
            self:select_next_sentence(sayings.tutorial[idx])
        end

    else
        local struggle_lvl = PLAYER_STRUGGLES.recipe_struggle_lvl

        PLAYER_LEARNED.complete = true
        -- Frustration checks:
        -- PLAYER_STRUGGLES are usually on a timer before set to false again

        if PLAYER_STRUGGLES.recipe_struggle then
            print("Giving gameplay hint Nr. " .. struggle_lvl)
            self:select_sentence(sayings.struggle.recipe, struggle_lvl)
        elseif PLAYER_STRUGGLES.no_fire then
            print("Reminding fire tutorial.")
            self:select_next_sentence(sayings.struggle.fire[1])
        elseif PLAYER_STRUGGLES.too_much_fire then
            print("Giving fire hint.")
            self:select_next_sentence(sayings.struggle.fire[2])
        elseif PLAYER_STRUGGLES.no_shake then
            print("Reminding drop tutorial.")
            self:select_next_sentence(sayings.struggle.drop[1])
        elseif PLAYER_STRUGGLES.too_much_shaking then
            print("Giving drop hint.")
            self:select_sentence(sayings.struggle.drop[2], 1)
        elseif PLAYER_STRUGGLES.no_stir then
            print("Reminding stir tutorial.")
            self:select_next_sentence(sayings.struggle.stir[1])
        elseif PLAYER_STRUGGLES.too_much_stir then
            print("Giving stir hint.")
            self:select_next_sentence(sayings.struggle.stir[2])

        -- Normal help loop:

        elseif GAMEPLAY_STATE.heat_amount < 0.3 then
            -- Reminder to keep the heat up whenever it goes low.
            self:select_next_sentence(sayings.help.fire)
        elseif
            -- First check if drops need to be stirred in
            #rune_anim_table > 1 then
            self:give_stirring_direction()
        elseif not Are_ingredients_good_enough() then
            -- Then give hints on next ingredient
            self:give_ingredients_direction()
        end
    end
end


function Froggo:give_color_direction()
    -- clockwise makes it more 1

    -- check dir
    local needs_to_stir_in_dir = DIR.need_more_of -- need more bright,  1
    if DIFF_TO_TARGET.color < 0.0 then
        needs_to_stir_in_dir = DIR.need_less_of -- need less bright,  2
    end

    -- check amount
    local stirr_offset = 1
    if DIFF_TO_TARGET.color_abs < 0.3 then
        stirr_offset = 3
    elseif DIFF_TO_TARGET.color_abs < 0.75 then
        stirr_offset = 2
    end

    print("giving stirring direction: dir "..needs_to_stir_in_dir.." amount "..stirr_offset)
    self:select_sentence(sayings.help.color[needs_to_stir_in_dir], stirr_offset)
end

local stir_offset = 1

function Froggo:give_stirring_direction()

    print("giving stirring reminder for NOW")
    self:select_next_sentence(sayings.help.stir)

end


function Froggo:give_ingredients_direction()

    local runes_abs_diff = {math.abs(DIFF_TO_TARGET.runes[1]), math.abs(DIFF_TO_TARGET.runes[2]), math.abs(DIFF_TO_TARGET.runes[3])}

    local rune_idx = RUNES.weed
    if runes_abs_diff[1] >= runes_abs_diff[2] and runes_abs_diff[1] >= runes_abs_diff[3] then
        rune_idx = RUNES.love
    elseif runes_abs_diff[2] >= runes_abs_diff[1] and runes_abs_diff[2] >= runes_abs_diff[3] then
        rune_idx = RUNES.doom
    end

    -- check dir
    local need_dir = DIR.need_less_of -- 2
    if DIFF_TO_TARGET.runes[rune_idx] < 0 then
        need_dir = DIR.need_more_of -- 1
    end

    print("giving runes direction: rune "..rune_idx.." dir: "..need_dir)
    self:select_next_sentence(sayings.help.ingredient[rune_idx][need_dir])
end


function Froggo:get_next_sentence_in_pool(sentence_pool)
    local sentence_cycle_idx = nil
    if sentence_pool == self.last_spoken_sentence_pool then
        sentence_cycle_idx = self.last_spoken_sentence_cycle_idx + 1
        if sentence_cycle_idx > #self.last_spoken_sentence_pool then
            sentence_cycle_idx = 1
            -- full cycle
        end
    else
        sentence_cycle_idx = 1
    end
    return sentence_cycle_idx
end


function Froggo:select_sentence(sentence_pool, sentence_cycle_idx)
    print("Frog says: idx "..sentence_cycle_idx.." TUT: "..self.tutorial_state)
    self.last_spoken_sentence_pool = sentence_pool
    self.last_spoken_sentence_cycle_idx = sentence_cycle_idx
    self.last_spoken_sentence_str = sentence_pool[sentence_cycle_idx]
end


function Froggo:select_next_sentence(sentence_pool)
    local sentence_cycle_idx = self:get_next_sentence_in_pool(sentence_pool)
    self:select_sentence(sentence_pool, sentence_cycle_idx)
end


function Froggo:start_speech_bubble()
    local text = self.last_spoken_sentence_str
    local anim_idx = tonumber(text)
    if anim_idx then
        local bubble_anim_imgs = SPEECH_BUBBLE_ANIM_IMGS[anim_idx][1]
        local bubble_framerate = SPEECH_BUBBLE_ANIM_IMGS[anim_idx][2]
        SPEECH_BUBBLE_ANIM = animloop.new(bubble_framerate * frame_ms, bubble_anim_imgs, true)
    else
        SPEECH_BUBBLE_TEXT = text
    end
end


function Froggo:stop_speech_bubble()
    -- Disable speech bubble.
    SPEECH_BUBBLE_TEXT = nil
    SPEECH_BUBBLE_ANIM = nil
end



-- Update
function Froggo:animation_tick()
    -- Set the image frame to display.
    if self.anim_current then
        self:setImage(self.anim_current:image())
        self:moveTo(350 + self.x_offset, 148)
    end
end
