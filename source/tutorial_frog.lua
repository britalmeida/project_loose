local gfx <const> = playdate.graphics
local Sprite <const> = gfx.sprite
local animloop <const> = playdate.graphics.animation.loop

local FROG_STATE = { idle = 0, speaking = 1, reacting = 2, drinking = 3 }
local THINGS_TO_REMEMBER <const> = { none = 0, fire = 1, stir = 2, secret_ingredient = 3, grab = 4, shake = 5, fire2 = 6 }

local last_topic_hint = THINGS_TO_REMEMBER.none
local current_topic_hint = THINGS_TO_REMEMBER.none
local current_rune_hint = 1
local rune_offset = 1
local current_stirr_hint = 1
local stirr_offset = 1
local last_sentence = -1
local current_sentence = -1
SHOWN_STRING = ""

local positive_acceptance <const> = "That'll do it!"
local forgotten_topics_callouts <const> = {
    "Hey, you forgot the fire",
    "Hey, you forgot to stir",
    "Hey, you forgot an ingredient",
}
local fire_reminders <const> = {
    --{"hey... the fire is getting low"},
    {"Keep it warm to see the magic"},
    {"Fire is good, glow is good"},
}

local fire_tutorials <const> = {
    "Magical brews need fire\nto reveal their magic",
    "Blow to stoke up the fire\npuff puff puff!",
    "Just blow air onto the\nbottom of the cauldron",
    "For realz, blow air\non the mic.\nTryyyy it!",
}

local stirr_reminders <const> = {
    {"Waaaaay too dark\ncrank it the other way", "The liquid looks too dark\nstirr!", "Just a lil'bit too dark"}, -- 1 == too dark
    {"Oh my eyes!\nLiquid is way too bright", "The liquid looks too bright\nstirr!", "Just a lil'bit too light"} -- 2 = too bright
}

local ingredient_reminders <const> = {
    {"Too much love\ncan't stand it!", "Add some passion?"}, -- 1 = heart
    {"Definitely missing happy stuff", "Missing doom and gloom"}, -- 2 = doom
    {"Too much organic in it", "Add some veggies"}, -- 3 = weeds
}

local ingredient_tutorials_grab <const> = {
    "Try grabbing an ingredient",
    "Tilt to hover an ingredient\nHold (A) to grab",
}

local ingredient_tutorials_drop <const> = {
    "Release the ingredient over\nthe cauldron and shake!",
    "Shake, shake. Shake it off!!",
}

local anim_idle_imgs, anim_idle_framerate = gfx.imagetable.new('images/frog/animation-idle'), 16
local anim_headshake_imgs, anim_headshake_framerate = gfx.imagetable.new('images/frog/animation-headshake'), 8
local anim_happy_imgs, anim_happy_framerate = gfx.imagetable.new('images/frog/animation-excited'), 8
local anim_cocktail_imgs, anim_cocktail_framerate = gfx.imagetable.new('images/frog/animation-cocktail'), 8
local anim_blabla_imgs, anim_blabla_framerate = gfx.imagetable.new('images/frog/animation-blabla'), 8

class('Froggo').extends(Sprite)

function Froggo:init()
    Froggo.super.init(self)

    -- Initialize animation state
    self.anim_current = nil
    self.anim_idle = animloop.new(anim_idle_framerate * frame_ms, anim_idle_imgs, true)
    self.anim_headshake = animloop.new(anim_headshake_framerate * frame_ms, anim_headshake_imgs, true)
    self.anim_happy = animloop.new(anim_happy_framerate * frame_ms, anim_happy_imgs, true)
    self.anim_cocktail = animloop.new(anim_cocktail_framerate * frame_ms, anim_cocktail_imgs, true)
    self.anim_blabla = animloop.new(anim_blabla_framerate * frame_ms, anim_blabla_imgs, true)

    self:setZIndex(Z_DEPTH.frog)
    self:moveTo(350, 148)

    self:addSprite()
    self:setVisible(true)

    self:reset()
end


function Froggo:reset()
    self:go_idle()

    Reset_frog()
end


-- Events for transition
function Froggo:Ask_the_frog()
    if self.state == FROG_STATE.idle then
        -- Start speaking
        self:croak()
    end
end

function Froggo:Notify_the_frog()
    -- notify the frog when significant change happened
    if self.state == FROG_STATE.idle then
        -- React to a state change
        self:froggo_react()
    end
end

function Froggo:go_idle()
    self.state = FROG_STATE.idle
    self.anim_current = self.anim_idle
end

function Froggo:go_reacting()
    self.state = FROG_STATE.reacting

    if TREND > 0 then
        self.anim_current = self.anim_happy
    elseif TREND < 0 then
        self.anim_current = self.anim_headshake
    end

end

function Froggo:go_drinking()
    self.state = FROG_STATE.drinking
    self.anim_current = self.anim_cocktail

    playdate.timer.new(5*1000, function()
        Enter_menu_start()
    end)
end

-- Actions

function Froggo:croak()
    -- Speak!
    self.state = FROG_STATE.speaking
    self.anim_current = self.anim_blabla

    set_current_sentence()
    set_speech_bubble_content()

    playdate.timer.new(2*1000, function()
        -- Disable speech bubble after a short moment.
        SHOWN_STRING = ""

        -- Give the frog a short moment to breathe before speaking/drinking again.
        playdate.timer.new(0.1*1000, function()
            if current_topic_hint == -1 then
                -- The potion is correct!
                self:go_drinking()
            else
                self:go_idle()
            end
        end)
    end)
end

function Froggo:froggo_react()
    self.state = FROG_STATE.reacting
    
    self:go_reacting()
    playdate.timer.new(2*1000, function()
        self:go_idle()
    end)
end

function froggo_reality_check()
    -- Match expectations with reality.
    local rune_per_component_diff = DIFF_TO_TARGET.runes

    -- Check for new priority of thing that is off target.
    last_topic_hint = current_topic_hint

    if Is_potion_good_enough() then
        current_topic_hint = -1
    elseif PLAYER_LEARNED.how_to_fire == false then
        current_topic_hint = THINGS_TO_REMEMBER.fire
    elseif PLAYER_LEARNED.how_to_grab == false then
        current_topic_hint = THINGS_TO_REMEMBER.grab
    elseif PLAYER_LEARNED.how_to_shake == false then
        current_topic_hint = THINGS_TO_REMEMBER.shake
    elseif GAMEPLAY_STATE.heat_amount < 0.3 then
        current_topic_hint = THINGS_TO_REMEMBER.fire
    elseif DIFF_TO_TARGET.color_abs > DIFF_TO_TARGET.ingredients_abs then
        current_topic_hint = THINGS_TO_REMEMBER.stir
        -- clockwise makes it more 1
        if DIFF_TO_TARGET.color < 0.0 then
            current_stirr_hint = 2
        else
            current_stirr_hint = 1
        end
        if DIFF_TO_TARGET.color_abs < 0.3 then
            stirr_offset = 3
        elseif DIFF_TO_TARGET.color_abs < 0.75 then
            stirr_offset = 2
        else
            stirr_offset = 1
        end
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

    print("froggo thinks priority is "..current_topic_hint.." diffs: ".." c:"..tostring(DIFF_TO_TARGET.color_abs).." r:"..tostring(DIFF_TO_TARGET.ingredients_abs).." becaaause "..rune_per_component_diff[1]..","..rune_per_component_diff[2]..","..rune_per_component_diff[3])

    if last_topic_hint ~= current_topic_hint then
        last_sentence = -1
    end
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
        elseif last_sentence < 4 then
            current_sentence = last_sentence + 1
        end
    elseif current_topic_hint == THINGS_TO_REMEMBER.grab or current_topic_hint == THINGS_TO_REMEMBER.shake or current_topic_hint == THINGS_TO_REMEMBER.fire2 then
        if last_sentence == -1 then
            current_sentence = 1
        elseif last_sentence < 2 then
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
                SHOWN_STRING = fire_tutorials[current_sentence]
            elseif current_topic_hint == THINGS_TO_REMEMBER.fire2 then
                SHOWN_STRING = fire_reminders[current_sentence]
            elseif current_topic_hint == THINGS_TO_REMEMBER.grab then
                SHOWN_STRING = ingredient_tutorials_grab[current_sentence]
            elseif current_topic_hint == THINGS_TO_REMEMBER.shake then
                SHOWN_STRING = ingredient_tutorials_drop[current_sentence]
            elseif current_topic_hint == THINGS_TO_REMEMBER.stir then
                SHOWN_STRING = stirr_reminders[current_stirr_hint][stirr_offset]
            elseif current_topic_hint == THINGS_TO_REMEMBER.secret_ingredient then
                SHOWN_STRING = ingredient_reminders[current_rune_hint][rune_offset]
            end
        end
    end
end


-- ><
function Reset_frog()
    last_topic_hint = THINGS_TO_REMEMBER.none
    current_topic_hint = THINGS_TO_REMEMBER.none
    last_sentence = -1
    current_sentence = -1
    SHOWN_STRING = ""
end


function Froggo:tick()
    -- Set the image frame to display.
    if self.anim_current then
        self:setImage(self.anim_current:image())
    end
end

