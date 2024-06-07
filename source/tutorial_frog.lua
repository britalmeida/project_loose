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
local TUTORIAL_STATE <const> = { start = 1, grab = 1, shake = 2, fire = 3, stir = 4, complete = 5 }

local positive_acceptance <const> = "That'll do it!"
local win_hint <const> = "That looks delicious!"
local fire_reminders <const> = {
    "Keep it warm to see \nthe magic.",
    "Fire is good, glow is good.",
    "9",
}
local fire_tutorials <const> = {
    "Magical brews need fire\nto reveal their magic.",
    "Blow air onto the\nbottom of the cauldron.",
    "10",
    "For realz, blow air\non the mic.\nTryyyy it!",
}
local fire_tips <const> = {
    "No need to stoke\nthe fire this often.",
    "Save your breath!\nLeave it for a bit.",
}
local stir_tutorials <const> = {
    "Always stir to see\nwhat ingredient do.",
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
    "Can you weaken\nthat love a bit?", "1",
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
    "Could be less vegetarian?", "5",
}
local grab_tutorials <const> = {
    "Try grabbing an ingredient.",
    "Tilt to move your hand.\nHold { to grab.",
    "Let it go over the cauldron.",
}
local drop_tutorials <const> = {
    "Place the ingredient over\nthe cauldron and shake!",
    "Shake, shake. Shake it off!!",
    "13",
}
local drop_tips <const> = {
    "Seems a bit excessive . . .\nFewer shakes are also fine.",
    "Remember to stir it all in.",
    "11",
}
local recipe_struggle <const> = {
    "Look above the cauldron.\nMagical symbols will guide you.",
    "Consider how the ingredients\nmatch the 3 magical aspects.",
    "Ingredients may raise one \nmagic and lower another.",
    "Some ingredients are potent.\nOthers are subtle.",
}
local cocktail_struggle <const> = {
    "Use [ to check what\nthe cocktail looks like?",
}

local sayings <const> = {
    tutorial = { grab_tutorials, drop_tutorials, fire_tutorials, stir_tutorials }, -- order of tutorials
    help = {
        fire = fire_reminders,
        ingredient = {
            { need_less_love, need_more_love },
            { need_less_doom, need_more_doom },
            { need_less_weed, need_more_weed },
        },
        stir = need_more_stir
    },
    struggle = {
        fire = { fire_tutorials, fire_tips},
        drop = { drop_tutorials, drop_tips},
        stir = { stir_tutorials, stir_tips},
    },
    hint = { -- hook these up poperly everywhere
        recipe = recipe_struggle,
        cocktail = cocktail_struggle,
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


-- B button / poke the frog prompt
-- e.g. time since last prompt.


class('Froggo').extends(Sprite)
Froggo = NewSubClass("Froggo", Sprite)

function Froggo:init()
    Froggo.super.init(self)

    -- Load animation images and initialize animation state.
    self.anim_current = nil
    self.anim_idle       = animloop.new(16 * frame_ms, gfxit.new('images/frog/animation-idle'), true)
    self.anim_headshake  = animloop.new(8 * frame_ms, gfxit.new('images/frog/animation-headshake'), true)
    self.anim_happy      = animloop.new(8 * frame_ms, gfxit.new('images/frog/animation-excited'), true)
    self.anim_cocktail   = animloop.new(5 * frame_ms, gfxit.new('images/frog/animation-sip'), true)
    self.anim_burp       = animloop.new(5 * frame_ms, gfxit.new('images/frog/animation-burp'), false)
    self.anim_burptalk   = animloop.new(5 * frame_ms, gfxit.new('images/frog/animation-burptalk'), true)
    self.anim_blabla     = animloop.new(8 * frame_ms, gfxit.new('images/frog/animation-blabla'), true)
    self.anim_tickleface = animloop.new(2.5 * frame_ms, gfxit.new('images/frog/animation-tickleface'), false)
    self.anim_eyeball    = animloop.new(4 * frame_ms, gfxit.new('images/frog/animation-eyeball'), true)
    self.anim_frogfire   = animloop.new(4 * frame_ms, gfxit.new('images/frog/animation-frogfire'), true)
    self.anim_facepalm   = animloop.new(4 * frame_ms, gfxit.new('images/frog/animation-facepalm'), true)

    self:setZIndex(Z_DEPTH.frog)

    self:addSprite()
    self:setVisible(true)

    self:reset()
end


function Froggo:reset()
    -- Reset frog action state machine.
    self:go_idle()
    self.x_offset = 0
    self.y_offset = 0

    -- Reset speech content state machine.
    self.tutorial_state = TUTORIAL_STATE.start
    self.last_spoken_sentence_topic = nil
    self.last_spoken_sentence_pool = nil
    self.last_spoken_sentence_cycle_idx = 0
    self.last_spoken_sentence_str = ""

    -- Reset speech Bubble state used by draw_dialog_bubble().
    self:stop_speech_bubble()
    GAMEPLAY_TIMERS.speech_timer.paused = true

    -- Ensure the B button prompt is not flashing.
    if ANIMATIONS.b_prompt then
        ANIMATIONS.b_prompt.paused = true
    end
end


function Froggo:start_animation(anim_loop)
    self.x_offset = 0
    self.y_offset = 0
    self.anim_current = anim_loop
    self.anim_current.frame = 1  -- Restart the animation from the beggining
end


function Froggo:flash_b_prompt(duration)
    -- Set default duration if none is specified
    if duration == nil then
        duration = 3000
    end
    -- Restart the animation and start
    ANIMATIONS.b_prompt.frame = 1
    ANIMATIONS.b_prompt.paused = false

    -- Start the timer that eventually pauses the blinking
    Restart_timer(GAMEPLAY_TIMERS.stop_b_flashing, duration)
end


-- Events for transition

function Froggo:Ask_the_frog()
    if self.state == ACTION_STATE.idle or self.state == ACTION_STATE.reacting then
        -- Possibly interrupt an emoting animation.
        -- Start speaking.
        self:think()
        self:croak()
    elseif self.state == ACTION_STATE.speaking then
        -- Prevent speech bubble kill and transition to idle from the previous sentence.
        GAMEPLAY_TIMERS.speech_timer.paused = true
        -- Clear the previous text or animated icon graphic. (bc text/icon isn't guaranteed to be replaced)
        self:stop_speech_bubble()
        -- Run a new sentence.
        self:think()
        self:croak()
    end
end


function Froggo:Ask_for_cocktail()
    self.last_spoken_sentence_str = string.format("One \"%s\", please!", COCKTAILS[TARGET_COCKTAIL.type_idx].name)
    self:croak()

    -- tmp: update to flash B button some time after starting a cocktail
    self:flash_b_prompt(4000)
end


function Froggo:Click_the_frog()
    local bounds = self:getBoundsRect()
    -- Make it a bit smaller, so we don't accedentially click on the frog
    bounds:inset(15, 15)
    if bounds:containsPoint(GAMEPLAY_STATE.cursor_pos) and self.state == ACTION_STATE.idle then
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
        if Is_potion_good_enough() and CHECK_IF_DELICIOUS then
            self:flash_b_prompt(20*1000)
            self:start_animation(self.anim_eyeball)
            self.x_offset = -11
            CHECK_IF_DELICIOUS = false
        end
    end
end


function Froggo:fire_reaction()
    self.state = ACTION_STATE.reacting
    self:start_animation(self.anim_frogfire)
    Restart_timer(GAMEPLAY_TIMERS.frog_go_idle, 2*1000)
end


function Froggo:go_idle()
    self.state = ACTION_STATE.idle
    self:start_animation(self.anim_idle)
end


function Froggo:go_reacting()
    self.state = ACTION_STATE.reacting

    -- If the potion was right already, give propper reaction :D
    if self.anim_current == self.anim_eyeball then
        local runtime = self.anim_facepalm.delay * self.anim_facepalm.endFrame

        self:start_animation(self.anim_facepalm)
        self.x_offset = -10
        self.y_offset = 9
        Restart_timer(GAMEPLAY_TIMERS.frog_go_idle, runtime)
        CHECK_IF_DELICIOUS = false

    -- Otherwise reacht to ingredient direction
    elseif TREND > 0 then
        self:start_animation(self.anim_happy)
        Restart_timer(GAMEPLAY_TIMERS.frog_go_idle, 2*1000)
        CHECK_IF_DELICIOUS = false
    elseif TREND < 0 then
        self:start_animation(self.anim_headshake)
        Restart_timer(GAMEPLAY_TIMERS.frog_go_idle, 2*1000)
        CHECK_IF_DELICIOUS = false
    end

end


function Froggo:froggo_tickleface()
    self.state = ACTION_STATE.reacting
    self:start_animation(self.anim_tickleface)
    Restart_timer(GAMEPLAY_TIMERS.frog_go_idle, 2.9*1000)
end


function Froggo:go_drinking()
    local cocktail_runtime = self.anim_cocktail.delay * (self.anim_cocktail.endFrame - 3)
    local burp_runtime = self.anim_burp.delay * (self.anim_burp.endFrame - 4)
    local burp_speak_runtime = self.anim_burp.delay * self.anim_burp.endFrame
    local runtime = 0

    self.state = ACTION_STATE.drinking
    self:start_animation(self.anim_cocktail)
    self.anim_current.frame = 3
    self.x_offset = -9

    -- Start sequence of timers to trigger animations and speech
    duration = cocktail_runtime
    Restart_timer(GAMEPLAY_TIMERS.drinking_cocktail, duration)

    duration += burp_runtime
    Restart_timer(GAMEPLAY_TIMERS.drinking_burp, duration)

    duration += burp_speak_runtime - burp_runtime
    Restart_timer(GAMEPLAY_TIMERS.drinking_burp_talk, duration)

    duration += 2*1000
    Restart_timer(GAMEPLAY_TIMERS.drinking_talk, duration)

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

        local dialog_display_time = self:start_speech_bubble()

        Restart_timer(GAMEPLAY_TIMERS.speech_timer, dialog_display_time)
    end
end


function Froggo:froggo_react()
    self.state = ACTION_STATE.reacting

    self:go_reacting()
end



-- Sentences and Speech Bubble

-- Select what should the frog say, adjust sentence state and trigger the speech bubble.
function Froggo:think()

    local automated = not GAMEPLAY_TIMERS.talk_reminder.paused

    -- Check if the potion is approved and early out!
    -- If the frog is speaking up as a talk reminder, don't end the game!
    if Is_potion_good_enough() and not automated then
        Win_game()
        Reset_ingredients()
        self.last_spoken_sentence_str = positive_acceptance
        return
    elseif Is_potion_good_enough() and automated then
        self.last_spoken_sentence_str = win_hint
    end

    -- Check what the player has already done and advance tutorial steps.
    -- Intentional fallthrough, so that the frog advances as many tutorial steps as needed in one go.
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
    if self.tutorial_state == TUTORIAL_STATE.fire then
        if PLAYER_LEARNED.how_to_fire then
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

        -- Loop throught the sentences for this tutorial step.
        self:select_next_sentence(sayings.tutorial[idx])

    else
        local struggle_lvl = PLAYER_STRUGGLES.recipe_struggle_lvl
        local struggles_unread = PLAYER_STRUGGLES.struggle_hint_asked < 5

        PLAYER_LEARNED.complete = true
        -- Frustration checks:
        -- PLAYER_STRUGGLES are usually on a timer before set to false again

        if PLAYER_STRUGGLES.recipe_struggle and struggles_unread then
            print("Giving gameplay hint Nr. " .. struggle_lvl)
            self:select_sentence(sayings.hint.recipe, struggle_lvl)
        elseif PLAYER_STRUGGLES.cocktail_struggle and struggles_unread then
            print("Giving hint towards cocktail artwork")
            self:select_sentence(sayings.hint.cocktail, 1)
        elseif PLAYER_STRUGGLES.no_fire and struggles_unread then
            print("Reminding fire tutorial.")
            self:select_next_sentence(sayings.struggle.fire[1])
        elseif PLAYER_STRUGGLES.too_much_fire and struggles_unread then
            print("Giving fire hint.")
            self:select_next_sentence(sayings.struggle.fire[2])
        elseif PLAYER_STRUGGLES.no_shake and struggles_unread then
            print("Reminding drop tutorial.")
            self:select_next_sentence(sayings.struggle.drop[1])
        elseif PLAYER_STRUGGLES.too_much_shaking and struggles_unread then
            print("Giving drop hint.")
            self:select_next_sentence(sayings.struggle.drop[2])
        elseif PLAYER_STRUGGLES.too_much_stir and struggles_unread then
            print("Giving stir hint.")
            self:select_next_sentence(sayings.struggle.stir[2])

        -- Normal help loop:
        -- Some lines will not be picked if the frog speaks autoamtically with a talk reminder
        elseif GAMEPLAY_STATE.heat_amount < 0.3 and not automated then
            -- Reminder to keep the heat up whenever it goes low.
            self:select_next_sentence(sayings.help.fire)
        elseif
            -- First check if drops need to be stirred in
            -- Also automated frog messaages need to be stopped or the potion is good but instirred
            GAMEPLAY_STATE.dropped_ingredients > 0 and
            (not automated or (Are_ingredients_good_enough() and not Is_potion_good_enough())) then
            self:give_stirring_direction()
        elseif not Are_ingredients_good_enough() then
            -- Then give hints on next ingredient
            self:give_ingredients_direction()
        end

        -- If they went through struggle tips too much, skip them
        if not struggles_unread then
            PLAYER_STRUGGLES.struggle_hint_asked = 0
            PLAYER_STRUGGLES.no_fire = false
            PLAYER_STRUGGLES.too_much_fire = false
            PLAYER_STRUGGLES.no_shake = false
            PLAYER_STRUGGLES.too_much_shaking = false
            PLAYER_STRUGGLES.too_much_stir = false
        end
    end
end


local stir_offset = 1

function Froggo:give_stirring_direction()

    print("giving stirring reminder for NOW")
    self:select_next_sentence(sayings.help.stir)

end


function Froggo:give_ingredients_direction()

    local runes_abs_diff = DIFF_TO_TARGET.runes_abs

    local rune_idx = RUNES.weed
    if runes_abs_diff[1] >= runes_abs_diff[2] and runes_abs_diff[1] >= runes_abs_diff[3]
    and TARGET_COCKTAIL.rune_count[1] > 0 then
        rune_idx = RUNES.love
    elseif runes_abs_diff[2] >= runes_abs_diff[1] and runes_abs_diff[2] >= runes_abs_diff[3]
    and TARGET_COCKTAIL.rune_count[2] > 0 then
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
    local ingredient_direction = false
    -- Compare if any ingredient direction is used
    for rune_idx, v in pairs(sayings.help.ingredient) do
        for rune_direction, v in pairs(sayings.help.ingredient[rune_idx]) do
            if sayings.help.ingredient[rune_idx][rune_direction] == sentence_pool then
                ingredient_direction = true
            end
        end
    end
    -- Compare if any struggle hint is used
    for mechanic in pairs(sayings.struggle) do
        for severity in pairs(sayings.struggle[mechanic]) do
            if sayings.struggle[mechanic][severity] == sentence_pool then
                struggle_tip = true
            end
        end
    end
    -- Check if player is stuck in the same frog hint dialogue
    if self.last_spoken_sentence_pool == sentence_pool
    and sentence_pool == sayings.help.fire then
        PLAYER_STRUGGLES.fire_struggle_asked += 1
    elseif self.last_spoken_sentence_pool == sentence_pool
    and ingredient_direction then
        PLAYER_STRUGGLES.ingredient_struggle_asked += 1
    -- Check if they already went through struggle/tips
    elseif self.last_spoken_sentence_pool == sentence_pool
    and struggle_tip then
        PLAYER_STRUGGLES.struggle_hint_asked += 1
    else
        PLAYER_STRUGGLES.fire_struggle_asked = 0
        PLAYER_STRUGGLES.ingredient_struggle_asked = 0
        PLAYER_STRUGGLES.struggle_hint_asked = 0
    end
    self.last_spoken_sentence_pool = sentence_pool
    self.last_spoken_sentence_cycle_idx = sentence_cycle_idx
    self.last_spoken_sentence_str = sentence_pool[sentence_cycle_idx]
end


function Froggo:select_next_sentence(sentence_pool)
    local sentence_cycle_idx = self:get_next_sentence_in_pool(sentence_pool)
    self:select_sentence(sentence_pool, sentence_cycle_idx)
end


function Froggo:start_speech_bubble()
    -- Set the text or animation to be displayed in a dialog bubble.
    -- Return the time in ms for which it should be displayed.

    local text = self.last_spoken_sentence_str
    local anim_idx = tonumber(text)
    local pool = self.last_spoken_sentence_pool
    if anim_idx then
        -- Select the dialog bubble animation corresponding to anim_idx.
        local bubble_anim_imgs = SPEECH_BUBBLE_ANIM_IMGS[anim_idx][1]
        local bubble_framerate = SPEECH_BUBBLE_ANIM_IMGS[anim_idx][2]
        -- Set the dialog visuals to be picked up in draw_dialog_bubble().
        SPEECH_BUBBLE_ANIM = animloop.new(bubble_framerate * frame_ms, bubble_anim_imgs, true)
        -- Return the time that the animation should be displayed.
        return math.max(SPEECH_BUBBLE_ANIM.endFrame * SPEECH_BUBBLE_ANIM.delay, 2800)
    else
        -- Add additional time for recipe hints. They can trigger by themselves.
        local extra_time = 0
        if pool == sayings.hint.recipe then
            extra_time = 1500
        end
        -- Split text into lines.
        local text_lines = {}
        for line in string.gmatch(text, "[^\n]+") do
            table.insert(text_lines, line)
        end
        -- Set the dialog visuals to be picked up in draw_dialog_bubble().
        SPEECH_BUBBLE_TEXT = text_lines
        -- Return the time that the speech bubble should be displayed.
        return math.max(2500, #text_lines*1600 + extra_time)
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
        self:moveTo(350 + self.x_offset, 148 + self.y_offset)
    end
end
