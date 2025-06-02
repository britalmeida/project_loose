local gfx <const> = playdate.graphics
local gfxit <const> = playdate.graphics.imagetable
local Sprite <const> = gfx.sprite
local animloop <const> = playdate.graphics.animation.loop


-- Froggo state machine
--- The Action State indicates what the frog is currently doing, e.g. speaking or emoting/reacting.
--- It ensures animations play to completion, and valid transitions (e.g. no emoting when already speaking).
--- The Frog is always in one and only one state and changes state on events (e.g. player pressed B, time passed).
local ACTION_STATE <const> = { idle = 0, speaking = 1, reacting = 2, alarmed = 3, drinking = 4 }

-- Froggo sounds state machine
---- Each sound the frog makes is mutually exclusive. Some loop. All can be interrupted by another.
local SOUND_STATE <const> = {
    silent      = 0,
    speaking    = 1,
    excited     = 2,
    headshake   = 3,
    facepalm   = 4,
    tickleface  = 5,
    urgent      = 6,
    eyelick     = 7,
    drinking    = 8,
    burp        = 9,
}

-- Froggo content machine
--- A separate multi-level state machine to select the sentence the frog says when speaking.
local TUTORIAL_STATE <const> = { start = 1, grab = 1, shake = 2, fire = 3, stir = 4, complete = 5 }

local positive_acceptance <const> = "That'll do it!"
local win_hint <const> = "Just don't mess it up now!"
local almost_win_hint <const> = "Just needs a little stir."
local fire_reminders <const> = {
    "Keep it warm to see \nthe magic.",
    "Fire is good, glow is good.",
    "9",
}
local fire_tutorials <const> = {
    "Stoke the fire to\n activate the magic.",
    "Blow air onto the\nbottom of the cauldron.",
    "10",
    "For realz, blow air\non the mic.\nTryyyy it!",
}
local fire_tips_a <const> = {
    "No need to stoke\nthe fire this often.",
    "Save your breath!\nLeave it for a bit.",
}
local fire_tips_b <const> = {
    "Raise the fire higher!\nIt will stick around longer.",
    "Really get the fire started!",
}
local stir_tutorials <const> = {
    "Always stir to see\nwhat ingredients do.",
    "Use the crank to stir.",
    "11",
}
local stir_tips <const> = {
    "The ingredients were \nalready stirred in.",
    "No need to stir that much.",
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
    "Too grim ...\nEvil repellent may work?",  "3",
}
local need_more_weed <const> = {
    "Could use some veggies.",  "6",
}
local need_less_weed <const> = {
    "Could be less vegetarian?", "5",
}
local positive_reinforcement <const> = {
    "That's the good stuff!\nShake in more.",
}
local grab_tutorials <const> = {
    "Try grabbing an ingredient.",
    "Tilt to move your hand.\nHold { to grab.",
    "Let it go over the cauldron.",
}
local drop_tutorials <const> = {
    "Place an ingredient over\nthe cauldron and shake!",
    "Shake, shake. Shake it off!!",
    "13",
}
local drop_tips <const> = {
    "Seems a bit excessive?\nMind how much you drop in.",
    "Remember to stir it in too.",
    "11",
}
local recipe_struggle <const> = {
    "Look above the cauldron\nfor guidance.",
    "Consider how the ingredients\nmatch the magical symbols.",
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
        fire = { fire_tutorials, fire_tips_a, fire_tips_b},
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
    self.anim_idle          = animloop.new(16 * frame_ms, gfxit.new('images/frog/animation-idle'), true)
    self.anim_headshake     = animloop.new(8 * frame_ms, gfxit.new('images/frog/animation-headshake'), true)
    self.anim_happy         = animloop.new(8 * frame_ms, gfxit.new('images/frog/animation-excited'), true)
    self.anim_burp          = animloop.new(5 * frame_ms, gfxit.new('images/frog/animation-burp'), false)
    self.anim_burptalk      = animloop.new(5 * frame_ms, gfxit.new('images/frog/animation-burp-talk'), true)
    self.anim_drink         = animloop.new(5 * frame_ms, gfxit.new('images/frog/animation-drink'), true)
    self.anim_blabla        = animloop.new(8 * frame_ms, gfxit.new('images/frog/animation-blabla'), true)
    self.anim_tickleface    = animloop.new(2.5 * frame_ms, gfxit.new('images/frog/animation-tickleface'), false)
    self.anim_eyeball       = animloop.new(4 * frame_ms, gfxit.new('images/frog/animation-eyeball'), true)
    self.anim_frogfire      = animloop.new(4 * frame_ms, gfxit.new('images/frog/animation-frogfire'), true)
    self.anim_facepalm      = animloop.new(4 * frame_ms, gfxit.new('images/frog/animation-facepalm'), true)
    self.anim_urgent        = animloop.new(3.75 * frame_ms, gfxit.new('images/frog/animation-urgent'), true)
    self.anim_urgent_start  = animloop.new(3.75 * frame_ms, gfxit.new('images/frog/animation-urgent_start'), true)
    self.anim_urgent_end    = animloop.new(6 * frame_ms, gfxit.new('images/frog/animation-urgent_end'), true)



    self:setZIndex(Z_DEPTH.frog)
    self:setUpdatesEnabled(false)
    self:setCollisionsEnabled(false)
    self:setAlwaysRedraw(true)

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
    self.sound_state = SOUND_STATE.silent
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

function Froggo:Ask_the_frog(automated)
    self:stop_urgent_animations()
    if self.state == ACTION_STATE.idle or self.state == ACTION_STATE.reacting or self.state == ACTION_STATE.alarmed then
        -- Possibly interrupt an emoting animation.
        -- Start speaking.
        self:think(automated)
        self:croak()
    elseif self.state == ACTION_STATE.speaking then
        -- Prevent speech bubble kill and transition to idle from the previous sentence.
        GAMEPLAY_TIMERS.speech_timer.paused = true
        -- Clear the previous text or animated icon graphic. (bc text/icon isn't guaranteed to be replaced)
        self:stop_speech_bubble()
        -- Run a new sentence.
        self:think(automated)
        self:croak()
    end
end


function Froggo:Ask_for_cocktail()
    self.last_spoken_sentence_str = string.format("One \"%s\", please!", COCKTAILS[TARGET_COCKTAIL.type_idx].name)
    self:croak()
end

-- Will trigger tickleface reaction of the frog if it is clicked on.
-- Takes an extra argument for cases where the bubble pop flicking is used (shortens the animation)
function Froggo:Click_the_frog(is_reacting_to_flick)
    local bounds = self:getBoundsRect()
    if is_reacting_to_flick == nil then
        is_reacting_to_flick = false
    end
    -- Make it a bit smaller, so we don't accedentially click on the frog
    bounds:inset(15, 15)
    if bounds:containsPoint(GAMEPLAY_STATE.cursor_pos) and self.state == ACTION_STATE.idle then
        self:froggo_tickleface(is_reacting_to_flick)
    end
end


function Froggo:Notify_the_frog()
    -- notify the frog when significant change happened

    -- Save the trend of the latest ingredient drop, just in case the frog is occupied
    if TREND > 0 then
        CAN_REINFORCE = true
    end
    if self.state == ACTION_STATE.idle then
            -- React to a state change
            self:froggo_react()
    end
end

function Froggo:Lick_eyeballs()
    if self.state == ACTION_STATE.idle then
        -- Check if the rune count is still within the goal
        local rune_count_unchanged = true
        for i in pairs(GAMEPLAY_STATE.rune_count) do
            local distance_from_goal = math.abs(GAMEPLAY_STATE.rune_count[i] - GAMEPLAY_STATE.rune_count_unstirred[i])
            if distance_from_goal > GOAL_TOLERANCE then
                rune_count_unchanged = false
            end
        end

        -- lick eyeballs if:
        -- - The potion is confirmed to be good
        -- - The potion was good already, some new ingredients were thrown in but it should still be the same
        if (Is_potion_good_enough() and CHECK_IF_DELICIOUS) or
        (Are_ingredients_good_enough() and CHECK_IF_DELICIOUS and rune_count_unchanged) then
            self.sound_state = SOUND_STATE.eyelick
            self:set_frog_sounds()
            self:flash_b_prompt(60*1000)
            self:start_animation(self.anim_eyeball)
            self.x_offset = -11
            self:start_thought_bubble()
            CHECK_IF_DELICIOUS = false
        end
    end
end


function Froggo:wants_to_talk()
    self.state = ACTION_STATE.alarmed

    local total_time = 6*1000

    -- Unless the game is over:
    -- Start with a very brief intro animation for the animation loop. Once ended, trigger urgent loop
    if not GAME_ENDED then
        local duration = (self.anim_urgent_start.delay * self.anim_urgent_start.endFrame) - 50

        self:stop_speech_bubble()
        
        self.sound_state = SOUND_STATE.urgent
        self:set_frog_sounds()

        -- Sequence of animation transitions, ending with going idle
        self:start_animation(self.anim_urgent_start)
        Restart_timer(GAMEPLAY_TIMERS.frog_go_urgent, duration)
        -- Make this only 2 seconds long if frog is automated. Then make the frog speak up
        if GAMEPLAY_STATE.asked_frog_count < MINIMUM_FROG_INTERACTIONS then
            duration = 2*1000
            total_time = duration
            Restart_timer(GAMEPLAY_TIMERS.talk_reminder, duration)
        else
            duration = total_time - duration
        end
        Restart_timer(GAMEPLAY_TIMERS.frog_go_urgent_end, duration)
        duration += self.anim_urgent_end.delay + 100
        Restart_timer(GAMEPLAY_TIMERS.frog_go_idle, duration)

        self:flash_b_prompt(total_time)

    end
end


function Froggo:stop_urgent_animations()
    -- Make sure the sequence of anim timers are stopped
    GAMEPLAY_TIMERS.frog_go_urgent:pause()
    GAMEPLAY_TIMERS.frog_go_urgent_end:pause()
    GAMEPLAY_TIMERS.frog_go_idle:pause()
end


function Froggo:fire_reaction()
    self.state = ACTION_STATE.alarmed
    self.sound_state = SOUND_STATE.silent
    self:set_frog_sounds()
    self:start_animation(self.anim_frogfire)
    self:prepare_to_idle()
end


function Froggo:prepare_to_idle(delay)

    -- Set standard time
    if delay == nil then
        delay = 2*1000
    end

    -- Stop thought bubbles and go idle after delay is passed
    self:stop_thought_bubble()
    Restart_timer(GAMEPLAY_TIMERS.frog_go_idle, delay)

    -- Make sure that eyelick animation restarts if needed
    CHECK_IF_DELICIOUS = false
end


function Froggo:go_idle()

    self.state = ACTION_STATE.idle
    self.sound_state = SOUND_STATE.silent
    self:set_frog_sounds()
    self:start_animation(self.anim_idle)
end


function Froggo:go_reacting()

    -- If the potion was right already, give propper reaction :D
    if self.anim_current == self.anim_eyeball and TUTORIAL_COMPLETED then
        self:facepalm()
    elseif self.anim_current == self.anim_eyeball and not TUTORIAL_COMPLETED then
        self.sound_state = SOUND_STATE.headshake
        self:set_frog_sounds()

        self:start_animation(self.anim_headshake)
        self:prepare_to_idle()

    -- Otherwise react to ingredient direction
    elseif TREND > 0 and TUTORIAL_COMPLETED then
        self.sound_state = SOUND_STATE.excited
        self:set_frog_sounds()

        self:start_animation(self.anim_happy)
        self:prepare_to_idle()
    elseif TREND < 0 and TUTORIAL_COMPLETED then
        self.sound_state = SOUND_STATE.headshake
        self:set_frog_sounds()

        self:start_animation(self.anim_headshake)
        self:prepare_to_idle()
    else
        -- return back to idle if no reaction applies
        self:go_idle()
    end
end


function Froggo:facepalm()
    print("FACEPALM")

    self.state = ACTION_STATE.reacting

    local runtime = self.anim_facepalm.delay * self.anim_facepalm.endFrame

    self:stop_speech_bubble()

    self.sound_state = SOUND_STATE.facepalm
    self:set_frog_sounds()

    self:start_animation(self.anim_facepalm)
    self.x_offset = -10
    self.y_offset = 9

    self:prepare_to_idle(runtime)
end


function Froggo:check_ignored_advice(situation)
    local facepalm_duration = self.anim_facepalm.delay * self.anim_facepalm.endFrame
    local target_timer

    if self.state == ACTION_STATE.reacting then
        -- Avoid spamming this logic each frame
        return
    end
    if situation == "too much fire"
    and self.last_spoken_sentence_pool == sayings.struggle.fire[2] then
        target_timer = GAMEPLAY_TIMERS.frog_give_hint_fire
        STRUGGLE_PROGRESS.too_much_fire_tracking = 0
    elseif situation == "too much stirring"
    and self.last_spoken_sentence_pool == sayings.struggle.stir[2] then
        target_timer = GAMEPLAY_TIMERS.frog_give_hint_stir
        STRUGGLE_PROGRESS.too_much_stir_tracking = 0
    elseif situation == "too much drops" 
    and self.last_spoken_sentence_pool == sayings.struggle.drop[2] then
        target_timer = GAMEPLAY_TIMERS.frog_give_hint_drop
        STRUGGLE_PROGRESS.too_much_shaking_tracking = 0
    else
        print("No advice was ignored")
        return
    end
    
    print("Advice was ignored. Bemoan player and instruct them again")
    -- After the facepalm is over, this timer triggers the same advice from the frog again
    Restart_timer(target_timer, facepalm_duration)
    self:facepalm()
end



function Froggo:froggo_tickleface(is_reacting_to_flick)
    self.state = ACTION_STATE.alarmed
    self.sound_state = SOUND_STATE.tickleface
    self:set_frog_sounds()
    self:start_animation(self.anim_tickleface)
    -- If the animation is triggered by a flick, skip the first 3 frames
    if is_reacting_to_flick then
        local three_frames_skipped = 7.5 * frame_ms
        self.anim_current.frame = 4
        self:prepare_to_idle(2.9*1000 - three_frames_skipped)
    else
        self:prepare_to_idle(2.9*1000)
    end
end


function Froggo:go_drinking()
    -- Stop currently running timers that might interrupt animation sequence
    for k in pairs(GAMEPLAY_TIMERS) do
        GAMEPLAY_TIMERS[k]:pause()
    end

    local burp_runtime = self.anim_burp.delay * self.anim_burp.endFrame
    local burptalk_runtime = (self.anim_burptalk.delay * self.anim_burptalk.endFrame) * 4
    local runtime = 0

    self.state = ACTION_STATE.drinking
    self.sound_state = SOUND_STATE.burp
    self:set_frog_sounds()
    self:start_animation(self.anim_burp)
    self.x_offset = -9

    -- Start sequence of timers to trigger animations and speech
    -- First one transitions to burptalk loop and starts speech bubble
    -- Second stops speech bubble, triggers recipe screen and starts looping drinking animation
    Restart_timer(GAMEPLAY_TIMERS.burp_anim, burp_runtime)
    Restart_timer(GAMEPLAY_TIMERS.burptalk_anim, burp_runtime + burptalk_runtime)

end


-- These are functions that the timers execute. 
-- ToDo: It would be better to have the timers cleaned up and tied to the states?
function Froggo:burp_anim_timer_function()
    self.sound_state = SOUND_STATE.speaking
    self:set_frog_sounds()
    self:start_animation(FROG.anim_burptalk)
    self.x_offset = -9
    self:start_speech_bubble()
end


function Froggo:burptalk_anim_timer_function()
    self.sound_state = SOUND_STATE.drinking
    self:set_frog_sounds()
    self:stop_speech_bubble()
    self:start_animation(FROG.anim_drink)
    self.x_offset = -9
    GAMEPLAY_STATE.showing_recipe = true
    SOUND.win_recipe_open:play()
end


-- Actions

function Froggo:croak()

    -- Speak!
    self.state = ACTION_STATE.speaking
    self.sound_state = SOUND_STATE.speaking
    self:set_frog_sounds()

    if GAME_ENDED then
        -- The potion is correct!
        self:go_drinking()
    else
        self:start_animation(self.anim_blabla)

        local dialog_display_time = self:start_speech_bubble()

        Restart_timer(GAMEPLAY_TIMERS.speech_timer, dialog_display_time)
        self:prepare_to_idle(dialog_display_time)
    end
end


function Froggo:froggo_react()
    self.state = ACTION_STATE.reacting

    self:go_reacting()
end



-- Sentences and Speech Bubble

-- Select what should the frog say, adjust sentence state and trigger the speech bubble.
function Froggo:think(automated)

    -- Check if the potion is approved and early out!
    -- If the frog is speaking up as a talk reminder, don't end the game!
    if Is_potion_good_enough() and not automated then
        Win_game()
        Reset_ingredients()
        self.last_spoken_sentence_str = positive_acceptance
        self:stop_speech_bubble()
        self:stop_thought_bubble()
        return
    elseif Is_potion_good_enough() and automated then
        self.last_spoken_sentence_str = win_hint
        return
    elseif Are_ingredients_good_enough() and automated then
        self.last_spoken_sentence_str = almost_win_hint
        return
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
        local struggle_lvl = STRUGGLE_PROGRESS.recipe_struggle_lvl
        -- How often you can cycle through hints before they disappear
        local struggles_unread = STRUGGLE_PROGRESS.struggle_hint_asked < 5
        local recipe_struggle_unread = STRUGGLE_PROGRESS.recipe_hint_asked < 1

        -- Frustration checks:
        -- PLAYER_STRUGGLES are usually on a timer before set to false again

        if PLAYER_STRUGGLES.recipe_struggle and recipe_struggle_unread then
            print("Giving gameplay hint Nr. " .. struggle_lvl)
            self:select_sentence(sayings.hint.recipe, struggle_lvl)
        elseif PLAYER_STRUGGLES.cocktail_struggle and struggles_unread then
            print("Giving hint towards cocktail artwork")
            self:select_sentence(sayings.hint.cocktail, 1)
        elseif PLAYER_STRUGGLES.no_fire and struggles_unread then
            print("Reminding fire tutorial.")
            self:select_next_sentence(sayings.struggle.fire[1])
        elseif PLAYER_STRUGGLES.too_much_fire and struggles_unread then
            print("Giving hint to use fire less.")
            self:select_next_sentence(sayings.struggle.fire[2])
        elseif PLAYER_STRUGGLES.too_little_fire and struggles_unread then
            print("Giving hint to use fire more.")
            self:select_next_sentence(sayings.struggle.fire[3])
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
        elseif GAMEPLAY_STATE.heat_amount < 0.2 then
            -- Reminder to keep the heat up whenever it goes low.
            self:select_next_sentence(sayings.help.fire)
        elseif GAMEPLAY_STATE.dropped_ingredients > 0 and not automated then
                self:give_stirring_direction()
        elseif not Are_ingredients_good_enough() then
            -- Then give hints on next ingredient
            self:give_ingredients_direction()
        end

        -- If they went through struggle tips too much, skip them
        if not struggles_unread then
            STRUGGLE_PROGRESS.struggle_hint_asked = 0
            PLAYER_STRUGGLES.no_fire = false
            PLAYER_STRUGGLES.too_much_fire = false
            PLAYER_STRUGGLES.too_little_fire = false
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
    local struggle_tip = false
    local recipe_hint = false
    local any_ingredient_direction = false
    local ingredient_rune_idx = 0
    local ingredient_rune_direction = 0
    local same_prev_direction = self.last_spoken_sentence_pool == sentence_pool
    local directed_rune_improved = false
    local same_ingredient_in_use = (GAMEPLAY_STATE.cauldron_ingredient == GAMEPLAY_STATE.last_shaken_ingredient)
    -- Check if any, and which, ingredient direction is used
    for rune_idx in pairs(sayings.help.ingredient) do
        for rune_direction in pairs(sayings.help.ingredient[rune_idx]) do
            if sayings.help.ingredient[rune_idx][rune_direction] == sentence_pool then
                any_ingredient_direction = true
                -- save the specific ingredient direction and see if they were followed/improved since last time
                ingredient_rune_idx = rune_idx
                ingredient_rune_direction = rune_direction
                directed_rune_improved = DIFF_TO_TARGET.runes_abs[ingredient_rune_idx] < DIFF_TO_TARGET.runes_abs_prev[ingredient_rune_idx]
            end
        end
    end
    -- Check if any struggle hint is used
    for mechanic in pairs(sayings.struggle) do
        for severity in pairs(sayings.struggle[mechanic]) do
            if sayings.struggle[mechanic][severity] == sentence_pool then
                struggle_tip = true
            end
        end
    end
    for type in pairs(sayings.hint) do
        if sayings.hint[type] == sentence_pool then
            recipe_hint = true
        end
    end
    -- Check if player is still in the same frog hint dialogue.
    -- Eventually this triggers a hint message
    if self.last_spoken_sentence_pool == sentence_pool
    and sentence_pool == sayings.help.fire then
        STRUGGLE_PROGRESS.fire_struggle_asked += 1
    elseif self.last_spoken_sentence_pool == sentence_pool
    and any_ingredient_direction then
        STRUGGLE_PROGRESS.ingredient_struggle_asked += 1
    -- Check if they already went through struggle/tips
    elseif self.last_spoken_sentence_pool == sentence_pool and
    struggle_tip then
        STRUGGLE_PROGRESS.struggle_hint_asked += 1
    elseif self.last_spoken_sentence_pool == sentence_pool and
    recipe_hint then
        STRUGGLE_PROGRESS.recipe_hint_asked += 1
    else
        STRUGGLE_PROGRESS.fire_struggle_asked = 0
        STRUGGLE_PROGRESS.ingredient_struggle_asked = 0
        STRUGGLE_PROGRESS.struggle_hint_asked = 0
    end

    -- Set the current sentence variables
    self.last_spoken_sentence_pool = sentence_pool
    self.last_spoken_sentence_cycle_idx = sentence_cycle_idx
    -- In case the directed ingredient was used last time and is still over the cauldron,
    -- replace current ingredient direction with positive reinforcement.
    if any_ingredient_direction and
        same_prev_direction and
        directed_rune_improved and
        same_ingredient_in_use and
        CAN_REINFORCE then
            self.last_spoken_sentence_str = positive_reinforcement[1]
            -- Reset to 0 so the sentence won't repeat
            CAN_REINFORCE = false
    else
        self.last_spoken_sentence_str = sentence_pool[sentence_cycle_idx]
        -- Reset to 0 so the sentence won't appear afterwards
        CAN_REINFORCE = false
    end
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

-- Stops speech bubbles and sets variables for the popping animation to start.
function Froggo:pop_speech_bubble()
    -- replace speech bubble with the corresponiding pop animation
    local bubble_type = get_speech_bubble_type()
    Froggo:stop_speech_bubble()
    -- Set active bubble animation and reset pop animations
    SPEECH_BUBBLE_POP = bubble_type
    ANIMATIONS.dialog_bubble_anim_pop.frame = 1
    ANIMATIONS.dialog_bubble_oneline_pop.frame = 1
    ANIMATIONS.dialog_bubble_twoline_pop.frame = 1
end


function Froggo:stop_speech_bubble()
    -- Disable speech bubble.
    SPEECH_BUBBLE_TEXT = nil
    SPEECH_BUBBLE_ANIM = nil
end


function Froggo:start_thought_bubble()
    -- start though bubble intro animation and switch to anim loop after timer ended

    local duration = (ANIMATIONS.thought_bubble_start.delay * ANIMATIONS.thought_bubble_start.endFrame) - 50

    ANIMATIONS.thought_bubble_start.frame = 1
    THOUGHT_BUBBLE_ANIM = ANIMATIONS.thought_bubble_start
    Restart_timer(GAMEPLAY_TIMERS.thought_bubble_anim, duration)

end


function Froggo:stop_thought_bubble()
    -- Also clear thought bubble anim and timers
    THOUGHT_BUBBLE_ANIM = nil
    GAMEPLAY_TIMERS.thought_bubble_anim:pause()
end


-- Update
function Froggo:animation_tick()
    -- Set the image frame to display.
    if self.anim_current then
        self:setImage(self.anim_current:image())
        self:moveTo(350 + self.x_offset, 148 + self.y_offset)
    end
end


-- Start and stop frog sounds depending on the Froggo.sound_state
function Froggo:set_frog_sounds()
    if self.sound_state == SOUND_STATE.silent then
        self:stop_sounds()
    
    -- For frog talking/eyelick the sound loops until the state changes 
    elseif self.sound_state == SOUND_STATE.speaking and not FROG_SOUND.speaking:isPlaying() then
        self:stop_sounds()
        FROG_SOUND.speaking:play(0)
    elseif self.sound_state == SOUND_STATE.eyelick and not FROG_SOUND.eyelick:isPlaying() then
        self:stop_sounds()
        FROG_SOUND.eyelick:play(0)

    -- All other sounds aare just played once if the state matches
    elseif self.sound_state == SOUND_STATE.excited then
        self:stop_sounds()
        FROG_SOUND.excited:play()
    elseif self.sound_state == SOUND_STATE.headshake then
        self:stop_sounds()
        FROG_SOUND.headshake:play()
    elseif self.sound_state == SOUND_STATE.facepalm then
        self:stop_sounds()
        FROG_SOUND.facepalm:play()
    elseif self.sound_state == SOUND_STATE.tickleface then
        self:stop_sounds()
        -- FROG_SOUND.tickleface:play()
    elseif self.sound_state == SOUND_STATE.urgent then
        self:stop_sounds()
        -- FROG_SOUND.urgent:play()
    elseif self.sound_state == SOUND_STATE.drinking then
        self:stop_sounds()
        -- FROG_SOUND.drinking:play()
    elseif self.sound_state == SOUND_STATE.burp then
        self:stop_sounds()
        -- FROG_SOUND.burp:play()
    end
end

-- stop all sounds from the frog
function Froggo:stop_sounds()
    for sound in pairs(FROG_SOUND) do
        if FROG_SOUND[sound]:isPlaying() then
            FROG_SOUND[sound]:stop()
        end
    end
end