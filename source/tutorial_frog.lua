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
local TUTORIAL_STATE <const> = { start = 1, fire = 1, stir = 2, grab = 3, shake = 4, complete = 5 }

local positive_acceptance <const> = "That'll do it!"
local forgotten_topics_callouts <const> = {
    "Magical brews need fire\nto reveal their magic.",
    "Hey, you forgot to stir.",
    "Hey, you forgot an ingredient.",
}
local fire_reminders <const> = {
    "Hey... the fire is getting low.",
    "Keep it warm to see \nthe magic.",
    "Fire is good, glow is good.",
    "9",
}
local fire_tutorials <const> = {
    "Blow to stoke up the fire\npuff puff puff!",
    "Just blow air onto the\nbottom of the cauldron",
    "10",
    "For realz, blow air\non the mic.\nTryyyy it!",
}
local stir_tutorials <const> = {
    "Remember the importance of\nthe stirring direction.",
    "Use the crank to stir?",
    "11", "12",
}
local need_more_bright <const> = {
    "Oh my eyes!\nLiquid is way too bright",
    "The liquid looks too bright.\nStirr!",
    "Just a lil'bit too light.",
}
local need_less_bright <const> = {
    "Waaaaay too dark!\nCrank it the other way.",
    "The liquid looks too dark\nstirr!",
    "Just a lil'bit too dark.",
}
local need_more_love <const> = {
    "Put some heart into it!", "2",
}
local need_less_love <const> = {
    "Too much love\ncan't stand it!", "1",
}
local need_more_doom <const> = {
    "Missing doom and gloom.", "4",
}
local need_less_doom <const> = {
    "Too grim...\nThis makes me depressed.",  "3",
}
local need_more_weed <const> = {
    "Could use some plant matter.",  "6",
}
local need_less_weed <const> = {
    "Too many veggies in this!", "5",
}
local grab_tutorials <const> = {
    "Try grabbing an ingredient.",
    "Tilt to hover an ingredient.\nHold (A) to grab.",
}
local drop_tutorials <const> = {
    "Release the ingredient over\nthe cauldron and shake!",
    "Shake, shake. Shake it off!!",
    "13",
}

local sayings <const> = {
    tutorial = { fire_tutorials, stir_tutorials, grab_tutorials, drop_tutorials }, -- fire, stir, grab, shake
    once = forgotten_topics_callouts,
    help = {
        fire = fire_reminders,
        ingredient = {
            { need_less_love, need_more_love },
            { need_less_doom, need_more_doom },
            { need_less_weed, need_more_weed },
        },
        color = { need_less_bright, need_more_bright } -- too_dark, too_bright
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

-- Animations
local anim_idle_imgs, anim_idle_framerate = gfx.imagetable.new('images/frog/animation-idle'), 16
local anim_headshake_imgs, anim_headshake_framerate = gfx.imagetable.new('images/frog/animation-headshake'), 8
local anim_happy_imgs, anim_happy_framerate = gfx.imagetable.new('images/frog/animation-excited'), 8
local anim_cocktail_imgs, anim_cocktail_framerate = gfx.imagetable.new('images/frog/animation-cocktail'), 8
local anim_blabla_imgs, anim_blabla_framerate = gfx.imagetable.new('images/frog/animation-blabla'), 8
local anim_tickleface_img, anim_tickleface_framerate = gfx.imagetable.new('images/frog/animation-tickleface'), 2.5
local anim_eyeball_img, anim_eyeball_framerate = gfx.imagetable.new('images/frog/animation-eyeball'), 4
local anim_frogfire_img, anim_frogfire_framerate = gfx.imagetable.new('images/frog/animation-frogfire'), 4


class('Froggo').extends(Sprite)
Froggo = NewSubClass("Froggo", Sprite)

function Froggo:init()
    Froggo.super.init(self)

    -- Initialize animation state
    self.anim_current = nil
    self.anim_idle = animloop.new(anim_idle_framerate * frame_ms, anim_idle_imgs, true)
    self.anim_headshake = animloop.new(anim_headshake_framerate * frame_ms, anim_headshake_imgs, true)
    self.anim_happy = animloop.new(anim_happy_framerate * frame_ms, anim_happy_imgs, true)
    self.anim_cocktail = animloop.new(anim_cocktail_framerate * frame_ms, anim_cocktail_imgs, true)
    self.anim_blabla = animloop.new(anim_blabla_framerate * frame_ms, anim_blabla_imgs, true)
    self.anim_tickleface = animloop.new(anim_tickleface_framerate * frame_ms, anim_tickleface_img, false)
    self.anim_eyeball = animloop.new(anim_eyeball_framerate * frame_ms, anim_eyeball_img, true)
    self.anim_frogfire = animloop.new(anim_frogfire_framerate * frame_ms, anim_frogfire_img, true)

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


function Froggo:fire_reaction()
    self.state = ACTION_STATE.reacting
        self:start_animation(self.anim_frogfire)

        playdate.timer.new(2*1000, function()
        self:go_idle()
    end)
end


function Froggo:go_idle()
    self.state = ACTION_STATE.idle
    if Is_potion_good_enough() then
        self:start_animation(self.anim_eyeball)
        self.x_offset = -11
    else
        self:start_animation(self.anim_idle)
    end
end


function Froggo:go_reacting()
    self.state = ACTION_STATE.reacting

    if TREND > 0 then
        self:start_animation(self.anim_happy)
    elseif TREND < 0 then
        self:start_animation(self.anim_headshake)
    end

end


function Froggo:froggo_tickleface()
    self.state = ACTION_STATE.reacting
    self:start_animation(self.anim_tickleface)

    playdate.timer.new(2.9*1000, function()
        self:go_idle()
    end)
end


function Froggo:go_drinking()
    self.state = ACTION_STATE.drinking
    self:start_animation(self.anim_cocktail)

    playdate.timer.new(5*1000, function()
        Enter_menu_start(0, 0)
    end)
end



-- Actions

function Froggo:croak()
    -- Speak!
    self.state = ACTION_STATE.speaking
    self:start_animation(self.anim_blabla)

    self:start_speech_bubble()

    playdate.timer.new(3*1000, function()
        -- Disable speech bubble after a short moment.
        self:stop_speech_bubble()

        -- Give the frog a short moment to breathe before speaking/drinking again.
        playdate.timer.new(0.1*1000, function()
            if GAME_ENDED then
                -- The potion is correct!
                self:go_drinking()
            else
                self:go_idle()
            end
        end)
    end)
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
    if self.tutorial_state == TUTORIAL_STATE.stir then
        if Is_color_good_enough() then -- Skip the stirring when it's not needed even if it's never been done
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


    if self.tutorial_state ~= TUTORIAL_STATE.complete then
        -- Froggo is teaching.

        local idx = self.tutorial_state

        if self.tutorial_state == TUTORIAL_STATE.stir then

            -- Stirring is complicated man!
            if not self.has_said_once_reminders[idx] and
                -- Don't say "you forgot to stir" if any stirring has happened already.
                not PLAYER_LEARNED.how_to_cw_for_brighter and
                not PLAYER_LEARNED.how_to_ccw_for_darker then
                self:select_sentence(sayings.once, idx)
                self.has_said_once_reminders[idx] = true
            else
                if not PLAYER_LEARNED.how_to_cw_for_brighter then
                    self:select_next_sentence(sayings.tutorial[idx])
                elseif not PLAYER_LEARNED.how_to_ccw_for_darker then
                    self:select_next_sentence(sayings.tutorial[idx])
                else
                    self:give_stirring_direction()
                end
            end

        else
            -- Say things like "You forgot an ingredient!" first and only once.
            if idx < #sayings.once and not self.has_said_once_reminders[idx] then
                self:select_sentence(sayings.once, idx)
                self.has_said_once_reminders[idx] = true
            else
                -- Loop throught the sentences for this tutorial step.
                self:select_next_sentence(sayings.tutorial[idx])
            end
        end

    else -- Normal help loop.

        -- Reminder to keep the heat up whenever it goes low.
        if GAMEPLAY_STATE.heat_amount < 0.3 then
            self:select_next_sentence(sayings.help.fire)
        else
            -- First get the ingredients right, then the color.
            if not Are_ingredients_good_enough() then
                self:give_ingredients_direction()
            else
                self:give_stirring_direction()
                -- Move back to stirring tutorial if it hasn't been learned.
                -- It will advance back to complete when it's learned or color got gud.
                if not PLAYER_LEARNED.how_to_cw_for_brighter or
                    not PLAYER_LEARNED.how_to_ccw_for_darker then
                    self.tutorial_state = TUTORIAL_STATE.stir
                end
            end
        end
    end
end


function Froggo:give_stirring_direction()
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
