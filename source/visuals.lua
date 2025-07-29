local gfx <const> = playdate.graphics
local gfxi <const> = playdate.graphics.image
local gfxit <const> = playdate.graphics.imagetable
local animloop <const> = playdate.graphics.animation.loop
local geo <const> = playdate.geometry
local vec2d <const> = playdate.geometry.vector2D
-- Alias frequently accessed math as local variables due to Lua performance reasons.
-- See https://lua.org/gems/sample.pdf about being 30% faster to access function locals
-- as opposed to global tables, and file locals being somewhere in between.
local sin <const> = math.sin
local cos <const> = math.cos
local sqrt <const> = math.sqrt
local min <const> = math.min
local max <const> = math.max
local floor <const> = math.floor
local abs <const> = math.abs
local random <const> = math.random
local PI <const> = 3.141592653589793
local TWO_PI <const> = 6.283185307179586
local PHI <const> = PI * (sqrt(5.0) - 1.0) -- Golden angle in radians


-- Resources
FONTS = {}
TEXTURES = {}
ANIMATIONS = {}

-- Constants
LIQUID_CENTER_X, LIQUID_CENTER_Y = 156, 175
LIQUID_WIDTH, LIQUID_HEIGHT = 66, 29
LIQUID_AABB = geo.rect.new(
    LIQUID_CENTER_X-LIQUID_WIDTH,
    LIQUID_CENTER_Y-LIQUID_HEIGHT*0.5,
    LIQUID_WIDTH*2, LIQUID_HEIGHT)
MAGIC_TRIANGLE_CENTER_X, MAGIC_TRIANGLE_CENTER_Y = 158, 124
MAGIC_TRIANGLE_SIZE = 100
CAULDRON_SLOT_X, CAULDRON_SLOT_Y = MAGIC_TRIANGLE_CENTER_X, MAGIC_TRIANGLE_CENTER_Y

-- The frog speech bubbles are full screen images and hit tested.
-- Ideally they would be cropped to size and positioned.
-- There was an organic expansion of types of bubbles without refactor, so the code CBB.
SPEECH_BUBBLE_AABB = {
    geo.rect.new(127, 65, 240, 70), -- small
    geo.rect.new(116, 56, 260, 90), -- big
    geo.rect.new(254, 60, 90, 70) -- anim
}

function get_speech_bubble_bounds()
    -- No speech bubble being shown.
    if SPEECH_BUBBLE_ANIM == nil and SPEECH_BUBBLE_TEXT == nil then
        return nil
    end

    -- Select active bubble animation and reset it to start from the beginning.
    if SPEECH_BUBBLE_ANIM then
        return SPEECH_BUBBLE_AABB[3]
    elseif #SPEECH_BUBBLE_TEXT == 1 then
        return SPEECH_BUBBLE_AABB[1]
    elseif #SPEECH_BUBBLE_TEXT > 1 then
        return SPEECH_BUBBLE_AABB[2]
    end
end


-- Draw utilities

local function draw_soft_ellipse(x_center, y_center, width, height, steps, blend, alpha, color)
    gfx.pushContext()
        for a = 1, steps, 1 do
            local step_blend <const> = (1 - a / steps) * blend
            local iteration_width <const> = step_blend * width + width
            local iteration_height <const> = step_blend * height + height
            local iteration_left <const> = x_center - iteration_width * 0.5
            local iteration_top <const> = y_center - iteration_height * 0.5

            gfx.setColor(color)
            gfx.setDitherPattern((1 - a / steps * alpha), gfxi.kDitherTypeBayer4x4)
            gfx.fillEllipseInRect(iteration_left, iteration_top, iteration_width, iteration_height)
        end
    gfx.popContext()
end


-- Draw passes

local function draw_symbols()
    local rune_area_x = MAGIC_TRIANGLE_CENTER_X
    local rune_area_y = MAGIC_TRIANGLE_CENTER_Y - 72
    local rune_area_width = 80
    local rune_area_height = 60
    local rune_half_size = 21

    local lower_glow_start = -0.8 -- It takes a bit of heat for glow to start
    local upper_glow_end = 2 -- It takes a lot of  time for glow to decay

    local should_draw_on_target_runes = GAMEPLAY_STATE.dropped_ingredients == 0 and GAMEPLAY_STATE.heat_amount > 0.3
    local should_draw_moving_runes    = GAMEPLAY_STATE.dropped_ingredients ~= 0 and GAMEPLAY_STATE.heat_amount > 0.3
    local heat_response = min(sqrt(max(GAMEPLAY_STATE.heat_amount * 1.2, 0)), 1)
    local glow_strength = Clamp((lower_glow_start * (1 - heat_response)) + (upper_glow_end * heat_response), 0, 1) * 0.75
    local glyph_fade  = Clamp(glow_strength, 0.2, 0.6)
    local target_fade = Clamp(glow_strength, 0.0, 0.5)

    local time_s <const> = playdate.getElapsedTime() -- Time of update shared by all runes.

    gfx.pushContext()
        for a = 1, NUM_RUNES do
            if TARGET_COCKTAIL.rune_count[a] == 0 then
                -- Don't draw disabled runes
                goto continue
            end

            local wiggle_freq = 2 + (a - 2) * 0.1
            local wiggle = sin((time_s / 30) * wiggle_freq + PI * 0.3)

            local glyph_x = rune_area_x + rune_area_width * 0.5 * (a - 2)
            local glyph_y = rune_area_y - (GAMEPLAY_STATE.rune_count_current[a] - 0.5) * rune_area_height + wiggle
            local target_y = rune_area_y - (TARGET_COCKTAIL.rune_count[a] - 0.5) * rune_area_height + wiggle
            -- Center rune images on the position.
            target_y -= rune_half_size
            glyph_x -= rune_half_size
            glyph_y -= rune_half_size

            -- Draw rune target.
            ANIMATIONS.rune_target_outline[a]:image():drawFaded(glyph_x, target_y, target_fade, gfxi.kDitherTypeBayer4x4)

            -- Rune glyphs. Draw idle, moving or correct
            if should_draw_on_target_runes and DIFF_TO_TARGET.runes_abs[a] < GOAL_TOLERANCE then
                ANIMATIONS.rune_correct[a]:draw(glyph_x, glyph_y)
            else
                ANIMATIONS.rune_idle[a]:image():drawFaded(glyph_x, glyph_y, glyph_fade, gfxi.kDitherTypeBayer4x4)
                -- if the rune is currently moving, draw the blinking outline
                if should_draw_moving_runes and GAMEPLAY_STATE.rune_count_change[a] ~= 0 then
                    ANIMATIONS.rune_active_outline[a]:draw(glyph_x, glyph_y)
                end
            end
            ::continue::
        end

    gfx.popContext()
end


local function draw_stirring_stick()
    gfx.pushContext()
    do
        local t = STIR_POSITION

        -- Calculate 2 ellipses:
        -- 'a': for the path of the top point of the stick,
        -- 'b': for the bottom point
        local stick_width, stick_height, stick_tilt = 10, 60, 45
        local stick_half_width = stick_width * 0.5
        local ellipse_height = LIQUID_HEIGHT - 5 -- Lil' bit less than the actual liquid height.
        local ellipse_bottom_width = LIQUID_WIDTH - 10 -- Lil' bit less than liquid
        local ellipse_top_width = ellipse_bottom_width + stick_tilt

        local sin_t <const> = sin(t)
        local cos_t <const> = cos(t)
        local a_x = cos_t * ellipse_top_width + LIQUID_CENTER_X
        local a_y = sin_t * ellipse_height + LIQUID_CENTER_Y - stick_height
        local b_x = cos_t * ellipse_bottom_width + LIQUID_CENTER_X
        local b_y = sin_t * ellipse_height + LIQUID_CENTER_Y

        -- Bottom offset is used to make sure that the bottom stick doesn't go out of the water
        local bot_offset = 0
        if t > PI and t < TWO_PI then
            local max_amp = 15
            bot_offset = sin_t * max_amp * Clamp(abs(GAMEPLAY_STATE.liquid_momentum) / 20, 0, 1)
            local vec_top = vec2d.new(a_x, a_y)
            local vec_bot = vec2d.new(b_x, b_y)
            local vec_dir = vec_bot - vec_top
            vec_dir:normalize()
            vec_bot = vec_bot - vec_dir * bot_offset
            b_x, b_y = vec_bot:unpack()
        end

        -- Draw stick
        local stick_outline_width = 3
        local stick_outer = geo.polygon.new(4)
        stick_outer:setPointAt(1, a_x + stick_half_width + stick_outline_width, a_y)
        stick_outer:setPointAt(2, a_x - stick_half_width - stick_outline_width, a_y)
        stick_outer:setPointAt(3, b_x - stick_half_width - stick_outline_width, b_y)
        stick_outer:setPointAt(4, b_x + stick_half_width + stick_outline_width, b_y)
        stick_outer:close()

        local stick_inner = geo.polygon.new(4)
        stick_inner:setPointAt(1, a_x + stick_half_width, a_y)
        stick_inner:setPointAt(2, a_x - stick_half_width, a_y)
        stick_inner:setPointAt(3, b_x - stick_half_width, b_y)
        stick_inner:setPointAt(4, b_x + stick_half_width, b_y)
        stick_inner:close()
        

        gfx.setColor(gfx.kColorWhite)
        gfx.fillCircleAtPoint(a_x, a_y, stick_half_width + stick_outline_width - 1)
        gfx.fillPolygon(stick_outer)

        gfx.setColor(gfx.kColorBlack)
        gfx.fillCircleAtPoint(a_x, a_y, stick_half_width -1)
        gfx.setDitherPattern(0.05)
        gfx.fillPolygon(stick_inner)
        
        gfx.setColor(gfx.kColorWhite)
        gfx.setLineWidth(1)
        gfx.drawLine(a_x - 2, a_y, b_x - 2, b_y)
    end
    gfx.popContext()
end


local function draw_stirring_stick_back()
    -- Draw the ladle only if it's on the farther side of the cauldron
    if STIR_POSITION >= PI and STIR_POSITION < TWO_PI then
        draw_stirring_stick()
    end
end


local function draw_stirring_stick_front()
    -- Draw the ladle only if it's on the front side of the cauldron
    if STIR_POSITION >= 0 and STIR_POSITION < PI then
        draw_stirring_stick()
    end
end

-- Create the cauldron liquid surface from a polygon of points.
-- Allocate these and set the position of the bottom points only once, as it is expensive to do on draw.
local liquid_num_points = 30
local liquid_half_num_points = liquid_num_points * 0.5
local liquid_surface = geo.polygon.new(liquid_num_points)
local liquid_point_radial_increment = (1 / liquid_num_points) * TWO_PI
for i=1, liquid_half_num_points do
    local angle = i * liquid_point_radial_increment
    local a_x = cos(angle) * LIQUID_WIDTH + LIQUID_CENTER_X
    local a_y = sin(angle) * LIQUID_HEIGHT + LIQUID_CENTER_Y
    liquid_surface:setPointAt(i, a_x, a_y)
end
liquid_surface:close()

local function draw_liquid_surface()
    local sin = sin -- make these local to the function, not just the file, for performance.
    local cos = cos

    -- Move the points on the back of the liquid in a wave as a response to stirring.
    -- Calculate a new position for those points, while the front/bottom points don't move.
    local freq = 0.65
    local max_amp = 15 -- maximum amplitude in pixels
    local speed_fac = 0.035 -- speed of the waves (0.01 slow 0.1 fast)
    -- Get dynamic factors from stirring.
    local offset = GAMEPLAY_STATE.liquid_offset * speed_fac % PI
    local amp_range = Clamp(abs(GAMEPLAY_STATE.liquid_momentum) / 20, 0, 1)

    -- Premultiply loop constants for performance.
    local half_points_increment = (1 / liquid_half_num_points) * PI
    local half_points_increment_x2 = (1 / liquid_half_num_points) * TWO_PI
    local amp_fac = max_amp * amp_range
    local period = freq * PI
    for i=liquid_half_num_points, liquid_num_points do
        local angle = i * liquid_point_radial_increment

        -- Make the point wavy if it's on the backside of the cauldron.
        local x = i - liquid_half_num_points
        local amplitude = sin(x * half_points_increment) * amp_fac
        local wave_height = amplitude * sin(((x * half_points_increment_x2) - offset) * period)

        -- Set the new point position.
        local a_x = cos(angle) * LIQUID_WIDTH + LIQUID_CENTER_X
        local a_y = sin(angle) * LIQUID_HEIGHT + LIQUID_CENTER_Y - wave_height
        liquid_surface:setPointAt(i, a_x, a_y)
    end

    -- Draw
    gfx.pushContext()
        -- Draw fill: black color
        gfx.setColor(gfx.kColorBlack)
        gfx.fillPolygon(liquid_surface)
        -- Draw line: white
        gfx.setColor(gfx.kColorWhite)
        gfx.setLineWidth(3)
        gfx.drawPolygon(liquid_surface)
    gfx.popContext()
end

-- Initialize elements that float in the cauldron liquid.
-- They can be either visual bubbles representing heat or ingredient drops to a maximum of 10.
NUM_BUBBLES = 10
local Bubbles = table.create(NUM_BUBBLES, 0)
for a = 1, NUM_BUBBLES, 1 do
    local y = 1 - ((a - 1) / (NUM_BUBBLES - 1)) * 2
    Bubbles[a] = {
        type = 0, -- Negative numbers for different bubble visuals, positive numbers correspond to an ingredient idx type.
        visible = false, -- If this bubble/ingredient should draw (as in if it exists/is alive, not as in if it's occluded).
        flip = gfx.kImageUnflipped, -- Mirror bubble and drop graphics for variety.
        amplitude = sqrt(1 - y * y) * 0.8 + 0.2,
        angle_rad = PHI * (a - 1), -- Initial angular position of each bubble given by golden angle increment. In radians.
        anim_offset = floor(PHI * (a - 1) * 50), -- Offset to the animation timing so things don't move in sync.
        img_table = nil, -- The image or image table to draw for this drop/bubble.
        img_center_x = 0, -- Offset from the top-left corner to the image center.
        img_center_y = 0,
    }
end

-- Spawn a (single) ingredient drop floating in the liquid.
-- There's a limited number of spots for drops/bubbles. A drop will take an empty space if there is
-- any or replace a heat bubble. If all spots are already taken by ingredient drops, *this new one
-- won't spawn*. It's too crowded and we opted not to make a physics simulation of a little pyramid
-- of drops on top of spinning liquid. Shame!
-- CBB: this makes a linear search twice, unideal but it's only 10 bubbles and only run on shake.
function Add_visual_ingredient_drop_to_liquid(type_idx)
    bubble_idx = -1
    -- Search for an unused bubble.
    for x = 1, NUM_BUBBLES, 1 do
        if not Bubbles[x].visible then
            bubble_idx = x
            break
        end
    end
    -- If there's no free spots, replace heat bubbles with ingredients
    if bubble_idx == -1 then
        for x = 1, NUM_BUBBLES, 1 do
            if Bubbles[x].type < 0 then
                bubble_idx = x
                break
            end
        end
    end
    -- If everything is already an ingredient and the player is still adding more, they won't show.

    -- Setup floating ingredient drop.
    if bubble_idx ~= -1 then
        Bubbles[bubble_idx].type = type_idx
        Bubbles[bubble_idx].visible = true
        Bubbles[bubble_idx].start_time_s = playdate.getElapsedTime()
        local drop_img = INGREDIENT_TYPES[type_idx].drop
        Bubbles[bubble_idx].img_table = drop_img
        Bubbles[bubble_idx].img_center_x = floor(drop_img.width / 2)
        Bubbles[bubble_idx].img_center_y = floor(drop_img.height / 2)
    end
end

local function draw_liquid_bubbles_and_drops()
    local sin = sin -- make these local to the function, not just the file, for performance.
    local cos = cos
    local floor = floor
    local anim_frame_dur_s <const> = 3 * (frame_ms / 1000)
    local time_s <const> = playdate.getElapsedTime() -- Time of update shared by all bubbles.
    local drop_bob_period = time_s * 3.3

    -- Despawn ingredient drops if stirring is completed in a cloud of smoke.
    if STIR_FACTOR >= 1.0 then
        for x = 1, NUM_BUBBLES, 1 do
            if Bubbles[x].type > 0 then
                Bubbles[x].visible = false
                Bubbles[x].type = 0
            end
        end
    end

    -- Spawn liquid bubbles when there is heat.
    if GAMEPLAY_STATE.heat_amount > 0.1 then
        for x = 1, NUM_BUBBLES, 1 do
            -- After a bubble pops, it gets respawned with in the same spot with a mirrored or different visual.
            -- There is a probability to the spawning according to the heat level so that a bubble has a bit of
            -- an interval before re-bubbling which is longer and more likely when there is less heat.
            if not Bubbles[x].visible and GAMEPLAY_STATE.heat_amount > random() + 0.1 then
                Bubbles[x].visible = true
                Bubbles[x].start_time_s = time_s

                if random() > 0.5 then
                    Bubbles[x].flip = gfx.kImageUnflipped
                else
                    Bubbles[x].flip = gfx.kImageFlippedX
                end
                -- Note: it would be nicer to assign an animloop which would keep track of both the visual
                -- and the lifetime, but unfortunately those are expensive to create and *copy* the image table :/
                if random() > 0.9 then
                    Bubbles[x].type = -2 -- Rare bubble visual.
                    Bubbles[x].img_table = ANIMATIONS.bubble2
                    Bubbles[x].img_center_x = 12
                    Bubbles[x].img_center_y = 12
                else
                    Bubbles[x].type = -1 -- Regular bubble visual.
                    Bubbles[x].img_table = ANIMATIONS.bubble
                    Bubbles[x].img_center_x = 5
                    Bubbles[x].img_center_y = 12
                end
            end
        end
    end

    gfx.pushContext()
        -- Values for calculating bubble/drop position, shared with liquid and ladle.
        -- The bubbles travel along an ellipse. T
        local ellipse_height <const>  = LIQUID_HEIGHT - 5 -- Lil' bit less than the actual liquid height.
        local ellipse_width <const> = LIQUID_WIDTH - 10 -- Lil' bit less than liquid

        local freq <const> = 0.65
        local max_amp <const> = 15
        local speed_fac <const> = 0.035 -- speed of the waves (0.01 slow 0.1 fast)
        -- Get dynamic factors from stirring.
        local stir_offset <const> = GAMEPLAY_STATE.liquid_offset * speed_fac * freq / 2
        local speed_squish_amp <const> = Clamp(abs(GAMEPLAY_STATE.liquid_momentum) / 20, 0, 1) * max_amp

        for x = 1, NUM_BUBBLES, 1 do
            if Bubbles[x].visible then

                -- Calculate bubble/ingredient drop position.
                local bubble_rad <const> = Bubbles[x].angle_rad + stir_offset
                local bubble_sin <const> = sin(bubble_rad)
                local bubble_cos <const> = cos(bubble_rad)
                local speed_squish_offset = bubble_sin * speed_squish_amp
                local pos_x = Bubbles[x].amplitude * bubble_cos * ellipse_width + LIQUID_CENTER_X
                local pos_y = Bubbles[x].amplitude * bubble_sin * ellipse_height + LIQUID_CENTER_Y - speed_squish_offset
                -- Center sprite on the ellipse path (avoid drawCentered as that adds 30% cost and doesn't support mask clipping).
                pos_x -= Bubbles[x].img_center_x
                pos_y -= Bubbles[x].img_center_y

                if Bubbles[x].type > 0 then
                    -- Draw ingredient drop.

                    local bob = sin(drop_bob_period + Bubbles[x].anim_offset) * 0.1
                    local sink = STIR_FACTOR + 0.1 + bob

                    local drop_sprite = Bubbles[x].img_table
                    drop_sprite:draw(
                        pos_x, pos_y - bob * 10, -- Buoy the ingredient y pos by 10px.
                        Bubbles[x].flip,
                        0, 0, drop_sprite.width, drop_sprite.height * (1-sink)) -- Clip the bottom of the image.
                else
                    -- Draw bubble.

                    -- Advance animation lifetime.
                    local elapsed_time_s = time_s - Bubbles[x].start_time_s
                    local lifetime_frame = floor(elapsed_time_s / anim_frame_dur_s)
                    local anim_length = #Bubbles[x].img_table
                    local img_frame = (lifetime_frame + Bubbles[x].anim_offset) % anim_length + 1 -- +1 for Lua arrays

                    Bubbles[x].img_table[img_frame]:draw(pos_x, pos_y, Bubbles[x].flip)

                    -- Despawn bubble.
                    if lifetime_frame == anim_length then
                        Bubbles[x].visible = false
                        Bubbles[x].type = 0
                    end
                end
            end
        end
    gfx.popContext()
end


function draw_stirring_bubbles()
    local ingredients_being_stirred = GAMEPLAY_STATE.dropped_ingredients > 0

    -- Check if stirring was completed and draw puff animation for one loop
    if GAMEPLAY_STATE.stirring_complete then
        -- Reset animation if it now starts
        if not GAMEPLAY_STATE.puff_anim_started then
            ANIMATIONS.stirring_bubble.puff.frame = 1
            GAMEPLAY_STATE.puff_anim_started = true
        end

        gfx.pushContext()
        ANIMATIONS.stirring_bubble.puff:draw(0, 0)
        gfx.popContext()

        -- Play correct sounds
        SOUND.cauldron_bubble_big:stop()
        if not SOUND.cauldron_bubble_pop:isPlaying() then
            SOUND.cauldron_bubble_pop:play()
        end

        -- End animation once it reaches the end frame
        if ANIMATIONS.stirring_bubble.puff.frame == ANIMATIONS.stirring_bubble.puff.endFrame then
            GAMEPLAY_STATE.stirring_complete = false
        end
    -- Check if no stirring bubbles are needed
    elseif (STIR_FACTOR < 0.1 and not GAMEPLAY_STATE.stirring_complete) or
        not ingredients_being_stirred then
            return
    -- Draw appropriate stirring_bubble state anim
    elseif (STIR_FACTOR >= 0.1 and STIR_FACTOR < 0.4) and ingredients_being_stirred then
        gfx.pushContext()
        ANIMATIONS.stirring_bubble.small:draw(125, 154)
        gfx.popContext()
        -- Play correct sounds
        SOUND.cauldron_bubble_big:stop()
        if not SOUND.cauldron_bubble_small:isPlaying() then
            SOUND.cauldron_bubble_small:play(0)
        end
    elseif STIR_FACTOR < 0.99 and ingredients_being_stirred then
        gfx.pushContext()
        ANIMATIONS.stirring_bubble.big:draw(125, 154)
        gfx.popContext()
        -- Play correct sounds
        SOUND.cauldron_bubble_small:stop()
        if not SOUND.cauldron_bubble_big:isPlaying() then
            SOUND.cauldron_bubble_big:play(0)
        end
        -- Restart puff anim in case it is triggered next
    end
end


local function draw_overlaid_instructions()
    if GAMEPLAY_STATE.showing_cocktail then
        gfx.pushContext()
            COCKTAILS[TARGET_COCKTAIL.type_idx].img:draw(0, 0)
        gfx.popContext()
    end

    if GAMEPLAY_STATE.showing_instructions then
        if TUTORIAL_COMPLETED or INTRO_COMPLETED then
            gfx.pushContext()
                TEXTURES.instructions:draw(400-TEXTURES.instructions.width, 0)
            gfx.popContext()
        else
            gfx.pushContext()
                TEXTURES.instructions_blank:draw(400-TEXTURES.instructions.width, 0)
            gfx.popContext()
        end
    end
end

local function draw_overlaid_recipe()
    if GAMEPLAY_STATE.showing_recipe then
        Recipe_draw_success()
    end
end

local function draw_dialog_bubble()
    if SPEECH_BUBBLE_ANIM then
        -- Should be displaying an animated speech bubble.

        gfx.pushContext()
            SPEECH_BUBBLE_ANIM:image():draw(13, 5)
        gfx.popContext()

    elseif SPEECH_BUBBLE_TEXT then
        -- Should be displaying a static speech bubble with text.

        local text_lines = SPEECH_BUBBLE_TEXT

        -- Bounding box of the dialog bubble, within which it is safe to place text.
        local x_min = 141
        local y_min = 67
        local width = 210
        local height = 58

        -- Vertical advance of the line, in pixels.
        local line_height = 18

        local y_center =  y_min + height / 2
        local current_line_y = y_center - line_height * #text_lines / 2

        -- Draw the buggle graphics itself.
        gfx.pushContext()
            if #text_lines > 1 then
                TEXTURES.dialog_bubble_twolines:draw(0, 0)
            else
                TEXTURES.dialog_bubble_oneline:draw(0, 0)
            end
        gfx.popContext()

        -- Debug drawing of the safe area bounds.
        -- gfx.pushContext()
        --    gfx.setColor(gfx.kColorWhite)
        --    gfx.drawRect(x_min, y_min, width, height)
        -- gfx.popContext()

        -- Draw lines of the text.
        gfx.pushContext()
            gfx.setFont(FONTS.speech_font)
            for i = 1, #text_lines, 1 do
                gfx.drawTextAligned(text_lines[i], x_min + width / 2, current_line_y, kTextAlignment.center)
                current_line_y += line_height
            end
        gfx.popContext()

    elseif SPEECH_BUBBLE_POP then
        -- Draw pop animation
        gfx.pushContext()
            SPEECH_BUBBLE_POP:image():draw(0, 0)
        gfx.popContext()

        -- Stop drawing when done
        -- FIXME: there shouldn't be logic changes on draw, but at this point we want to be done with refactoring code.
        -- There is no strong reason to fix this thing and not all the timer code, so leave it be.
        if SPEECH_BUBBLE_POP.frame == SPEECH_BUBBLE_POP.endFrame then
            SPEECH_BUBBLE_POP = nil
        end
    elseif THOUGHT_BUBBLE_ANIM then
        -- Animated thought bubble when frog wants to say something
        gfx.pushContext()
            THOUGHT_BUBBLE_ANIM:image():draw(0, 0)
        gfx.popContext()
    end
end


local function draw_bg_lighting()
    local light_strength = (GAMEPLAY_STATE.heat_amount * 0.8 + 0.2 )
    local glow_center_x = LIQUID_CENTER_X
    local glow_center_y = 240
    local glow_width = 200 + light_strength * 60
    local glow_height = 120 + light_strength * 40
    local glow_blend = max(0.25, light_strength) * 0.8

    draw_soft_ellipse(glow_center_x, glow_center_y, glow_width, glow_height, 6, glow_blend, light_strength * 0.5, gfx.kColorWhite)
end

local function draw_game_background()
    -- Draw full screen background.
    gfx.pushContext()
        TEXTURES.bg:draw(0, 0)
    gfx.popContext()
end


local function draw_cauldron()
    -- Draw cauldron image
    gfx.pushContext()
        TEXTURES.cauldron:draw(54, 128)
    gfx.popContext()
end

local buildupflame_counter = 0
-- Constants for splish animation.
local splish_detect_area <const> = 0.4 -- In radians, about 23 degrees.
local splish_detect_top_right_angle <const> = PI/2 - splish_detect_area
local splish_detect_top_left_angle <const> = PI/2 + splish_detect_area
local splish_detect_bot_left_angle <const> = PI*1.5 - splish_detect_area
local splish_detect_bot_right_angle <const> = PI*1.5 + splish_detect_area

local function draw_cauldron_front()
    gfx.pushContext()
        -- Draw cauldron foreground image
        TEXTURES.cauldron_front:draw(54, 128)

        -- Draw flame animation
        if GAMEPLAY_STATE.flame_amount > 0.8 then
            buildupflame_counter += 1
            if buildupflame_counter < 5 then
                TEXTURES.flame_buildup:draw(10, 0)
            else
                ANIMATIONS.flame.stir:draw(10, 0)
            end
        elseif GAMEPLAY_STATE.flame_amount > 0.5 then
            buildupflame_counter = buildupflame_counter * 0.5
            if buildupflame_counter > 2 then
                ANIMATIONS.flame.stir:draw(10, 0)
            else
                ANIMATIONS.flame.high:draw(10, 0)
                buildupflame_counter = 0
            end
        elseif GAMEPLAY_STATE.heat_amount > 0.4 then
            ANIMATIONS.flame.medium:draw(10, 0)
        elseif GAMEPLAY_STATE.heat_amount > 0.2 then
            ANIMATIONS.flame.low:draw(10, 0)
        elseif GAMEPLAY_STATE.heat_amount > 0.08 then
            ANIMATIONS.flame.ember:draw(10, 0)
        end

        -- Draw splish animations
        local splish_left_paused <const> = GAMEPLAY_TIMERS.splish_left.paused
        local splish_right_paused <const> = GAMEPLAY_TIMERS.splish_right.paused
        -- Restart splish animations when stirring with a certain speed if they were previously paused.
        local min_stir_speed <const> = 35
        if math.abs(STIR_SPEED) > min_stir_speed then
            -- Start a splish when the ladle is at a certain angle range at the top or bottom of the cauldron.
            local splish_right_detected <const> = STIR_POSITION > splish_detect_top_right_angle and STIR_POSITION < splish_detect_top_left_angle
            local splish_left_detected <const> = STIR_POSITION > splish_detect_bot_left_angle and STIR_POSITION < splish_detect_bot_right_angle
            local splish_duration <const> = ANIMATIONS.splish.right.delay * ANIMATIONS.splish.right.endFrame - 33
            if splish_left_detected and splish_left_paused then
                Restart_timer(GAMEPLAY_TIMERS.splish_left, splish_duration)
                ANIMATIONS.splish.left.frame = 1
            elseif splish_right_detected and splish_right_paused then
                Restart_timer(GAMEPLAY_TIMERS.splish_right, splish_duration)
                ANIMATIONS.splish.right.frame = 1
            end
        end
        if not splish_left_paused then
            ANIMATIONS.splish.left:draw(27, 122)
        end
        if not splish_right_paused then
            ANIMATIONS.splish.right:draw(220, 130)
        end
    gfx.popContext()
end


local function draw_ui_prompts()
    if GAME_ENDED then
        -- Disappear button prompts when the game transitions to win!
        return
    end

    gfx.pushContext()
        TEXTURES.instructions_prompt:draw(GAMEPLAY_STATE.instructions_prompt_pos, 0)
        ANIMATIONS.b_prompt:draw(362, 203)
    gfx.popContext()
end


local function draw_debug()
    -- Fire meters.
    local x = 10
    local y = 10
    local border = 3
    local width = 22
    local height = 150
    -- Flame amount meter.
    local meter = ( GAMEPLAY_STATE.flame_amount ) * (height - border * 2)
    gfx.pushContext()
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRoundRect(x, y, width, height, border)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRoundRect(x + border, y + height - meter - border, width - border * 2, meter, 3)
    gfx.popContext()
    -- Heat amount meter.
    x += width + border
    meter = ( GAMEPLAY_STATE.heat_amount ) * (height - border * 2)
    gfx.pushContext()
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRoundRect(x, y, width, height, border)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRoundRect(x + border, y + height - meter - border, width - border * 2, meter, 3)
    gfx.popContext()

    -- Hit zones
    gfx.pushContext()
        gfx.setColor(gfx.kColorWhite)
        gfx.setLineWidth(2)

        -- Cauldron (ingredient drops).
        gfx.drawRect(LIQUID_AABB)

        -- Speech bubbles (cursor flick pop).
        for _, rect in pairs(SPEECH_BUBBLE_AABB) do
            gfx.drawRect(rect)
        end
        gfx.drawRect(FROG:getBoundsRect())
    gfx.popContext()
end


local function draw_debug_fps()
    -- FPS
    gfx.pushContext()
        gfx.setColor(gfx.kColorWhite)
        playdate.drawFPS(200,0)
    gfx.popContext()
end


local function draw_ingredient_grab_cursor()
    if GAME_ENDED then
        -- Disappear interaction visuals when the game transitions to win!
        return
    end

    gfx.pushContext()

        -- Set which hand cursor is drawn 
        if GAMEPLAY_STATE.cursor == CURSORS.hold then
            TEXTURES.cursor_hold:drawCentered(GAMEPLAY_STATE.cursor_pos:unpack())
        elseif GAMEPLAY_STATE.cursor == CURSORS.open then
            TEXTURES.cursor:drawCentered(GAMEPLAY_STATE.cursor_pos:unpack())
        elseif GAMEPLAY_STATE.cursor == CURSORS.flick_hover or GAMEPLAY_STATE.cursor == CURSORS.flick_hold then
            TEXTURES.cursor_flick_hold:drawCentered(GAMEPLAY_STATE.cursor_pos:unpack())
        elseif GAMEPLAY_STATE.cursor == CURSORS.flick then
            ANIMATIONS.cursor_flick:image():drawCentered(GAMEPLAY_STATE.cursor_pos:unpack())
        end

        if GAMEPLAY_STATE.cursor == CURSORS.flick then
            -- Reset flick animation if it just started.
            if GAMEPLAY_STATE.cursor_prev ~= CURSORS.flick then
                ANIMATIONS.cursor_flick.frame = 1
            end
            -- Switch to regular open hand once flick anim is done.
            if ANIMATIONS.cursor_flick.frame == ANIMATIONS.cursor_flick.endFrame then
                GAMEPLAY_STATE.cursor = CURSORS.open
            end
        end

    gfx.popContext()
end


local function draw_ingredient_place_hint()
    if GAME_ENDED then
        -- Disappear interaction visuals when the game transitions to win!
        return
    end

    -- Draw hint of where to place the grabbed ingredient above the cauldron.
    if GAMEPLAY_STATE.cursor == CURSORS.hold
        and GAMEPLAY_STATE.cauldron_ingredient == nil
        and GAMEPLAY_STATE.held_ingredient ~= 0
    then
        gfx.pushContext()
            ANIMATIONS.place_hints[GAMEPLAY_STATE.held_ingredient]:image():drawCentered(
                MAGIC_TRIANGLE_CENTER_X, MAGIC_TRIANGLE_CENTER_Y)
        gfx.popContext()
    end
end



-- Load resources and initialize draw passes
DRAW_PASSES = table.create(24, 0) -- Pre-size the array with enough size for all the draw passes.
PASSES_HIDDEN_ON_DRINK  = table.create(12, 0)
PASSES_HIDDEN_ON_RECIPE = table.create(12, 0)
local HIDE <const> = { never = 0, on_drink = 1, on_recipe = 2 }


-- Configure a draw pass on Z depth
function Set_draw_pass(z, drawCallback, hide_type)
    local sprite = gfx.sprite.new()
    sprite:setSize(playdate.display.getSize())
    sprite:setCenter(0, 0)
    sprite:moveTo(0, 0)
    sprite:setZIndex(z)
    sprite:setIgnoresDrawOffset(true)
    sprite:setUpdatesEnabled(false)
    sprite:setCollisionsEnabled(false)
    sprite:setAlwaysRedraw(true)
    sprite.draw = function(s, x, y, w, h)
        drawCallback(x, y, w, h)
    end

    -- Keep track of sprites to enable/disable later.
    if hide_type == HIDE.on_drink then
        table.insert(PASSES_HIDDEN_ON_DRINK, sprite)
    elseif hide_type == HIDE.on_recipe then
        table.insert(PASSES_HIDDEN_ON_RECIPE, sprite)
    else
        -- Add sprites that are always visible to the list to be drawn and updated.
        -- Note: these passes don't update when on menus.
        sprite:add()
    end

    return sprite
end


function Init_visuals()

    -- Load image layers.
    TEXTURES.bg = gfxi.new("images/bg")
    TEXTURES.cauldron = gfxi.new("images/cauldron")
    TEXTURES.cauldron_front = gfxi.new("images/cauldron_front")
    TEXTURES.instructions_prompt = gfxi.new("images/instructions_prompt")
    TEXTURES.dialog_bubble_oneline = gfxi.new("images/speech/speechbubble_oneline_wide")
    TEXTURES.dialog_bubble_twolines = gfxi.new("images/speech/speechbubble_twolines_extrawide")
    ANIMATIONS.dialog_bubble_anim_pop = animloop.new(3 * frame_ms, gfxit.new("images/speech/animation-bubble-pop-icon"), true)
    ANIMATIONS.dialog_bubble_oneline_pop = animloop.new(3 * frame_ms, gfxit.new("images/speech/animation-bubble-pop-one-line"), true)
    ANIMATIONS.dialog_bubble_twoline_pop = animloop.new(3 * frame_ms, gfxit.new("images/speech/animation-bubble-pop-two-lines"), true)
    ANIMATIONS.thought_bubble_start = animloop.new(6 * frame_ms, gfxit.new("images/speech/animation-dream-cocktail_start"), true)
    ANIMATIONS.thought_bubble = animloop.new(6 * frame_ms, gfxit.new("images/speech/animation-dream-cocktail"), true)
    TEXTURES.instructions = gfxi.new("images/instructions")
    TEXTURES.instructions_blank = gfxi.new("images/instructions_blank")
    if playdate.isSimulator then
        TEXTURES.instructions = gfxi.new("images/instructions_sim")
        TEXTURES.instructions_blank = gfxi.new("images/instructions_blank_sim")
    end
    -- Load recipe paper backgrounds.
    TEXTURES.recipe = {
        top = gfxi.new("images/recipes/recipe_top_section"),
        bottom = gfxi.new("images/recipes/recipe_bottom_section"),
        middle = {
            gfxi.new("images/recipes/recipe_mid_1"),
            gfxi.new("images/recipes/recipe_mid_2"),
            gfxi.new("images/recipes/recipe_mid_3"),
            gfxi.new("images/recipes/recipe_mid_4"),
            gfxi.new("images/recipes/recipe_mid_5"),
            gfxi.new("images/recipes/recipe_mid_6"),},
    }
    TEXTURES.recipe_small = {
        top = gfxi.new("images/recipes/recipe_small_top_section"),
        bottom = gfxi.new("images/recipes/recipe_small_bottom_section"),
        middle = {
            gfxi.new("images/recipes/recipe_small_mid_1"),
            gfxi.new("images/recipes/recipe_small_mid_2"),
            gfxi.new("images/recipes/recipe_small_mid_3"),
            gfxi.new("images/recipes/recipe_small_mid_4"),
            gfxi.new("images/recipes/recipe_small_mid_5"),
            gfxi.new("images/recipes/recipe_small_mid_6"),}
    }
    -- Load images
    TEXTURES.cursor = gfxi.new("images/cursor/open_hand")
    TEXTURES.cursor_hold = gfxi.new("images/cursor/closed_hand")
    TEXTURES.cursor_flick_hold = gfxi.new("images/cursor/finger_snip_held")
    ANIMATIONS.cursor_flick = animloop.new(4 * frame_ms, gfxit.new("images/cursor/animation_finger_snip"), true)
    ANIMATIONS.place_hints = {
        animloop.new(15 * frame_ms, gfxit.new("images/cursor/animation_peppermints_blink"), true), -- peppermints
        animloop.new(15 * frame_ms, gfxit.new("images/cursor/animation_perfume_blink"), true), -- perfume
        animloop.new(15 * frame_ms, gfxit.new("images/cursor/animation_mushrooms_blink"), true), -- mushroom
        animloop.new(15 * frame_ms, gfxit.new("images/cursor/animation_coffee_blink"), true), -- coffee
        animloop.new(15 * frame_ms, gfxit.new("images/cursor/animation_toenails_blink"), true), -- toenails
        animloop.new(15 * frame_ms, gfxit.new("images/cursor/animation_salt_blink"), true), -- salt
        animloop.new(15 * frame_ms, gfxit.new("images/cursor/animation_garlic_blink"), true), -- garlic
        animloop.new(15 * frame_ms, gfxit.new("images/cursor/animation_spiderweb_blink"), true), -- spiderweb
        animloop.new(15 * frame_ms, gfxit.new("images/cursor/animation_snailshells_blink"), true), -- snailshells
    }
    ANIMATIONS.rune_idle = {
        animloop.new(16 * frame_ms, gfxit.new("images/runes/love_idle"), true),
        animloop.new(16 * frame_ms, gfxit.new("images/runes/doom_idle"), true),
        animloop.new(16 * frame_ms, gfxit.new("images/runes/weeds_idle"), true),}
    ANIMATIONS.rune_active_outline = {
        animloop.new(8 * frame_ms, gfxit.new("images/runes/love_active_white_line"), true),
        animloop.new(8 * frame_ms, gfxit.new("images/runes/doom_active_white_line"), true),
        animloop.new(8 * frame_ms, gfxit.new("images/runes/weeds_active_white_line"), true),
    }
    ANIMATIONS.rune_correct = {
        animloop.new(8 * frame_ms, gfxit.new("images/runes/love_correct"), true),
        animloop.new(8 * frame_ms, gfxit.new("images/runes/doom_correct"), true),
        animloop.new(8 * frame_ms, gfxit.new("images/runes/weeds_correct"), true)}
    ANIMATIONS.rune_target_outline = {
        animloop.new(16 * frame_ms, gfxit.new("images/runes/love_goal_white_line"), true),
        animloop.new(16 * frame_ms, gfxit.new("images/runes/doom_goal_white_line"), true),
        animloop.new(16 * frame_ms, gfxit.new("images/runes/weeds_goal_white_line"), true),
    }
    -- Load fx
    -- Load animation images and initialize animation loop timers.
    ANIMATIONS.bubble = gfxit.new("images/fx/bubble")
    ANIMATIONS.bubble2 = gfxit.new("images/fx/bubble2")
    ANIMATIONS.stirring_bubble = {
        small  = animloop.new(3.75 * frame_ms, gfxit.new("images/fx/stirring_bubble_small"), true),
        big  = animloop.new(3.75 * frame_ms, gfxit.new("images/fx/stirring_bubble_big"), true),
        puff  = animloop.new(3.75 * frame_ms, gfxit.new("images/fx/stirring_bubble_puff"), true),
    }
    ANIMATIONS.splish = {
        left  = animloop.new(3.5 * frame_ms, gfxit.new("images/fx/cauldron_splish_left"), true),
        right = animloop.new(3.5 * frame_ms, gfxit.new("images/fx/cauldron_splish_right"), true),
    }
    TEXTURES.flame_buildup = gfxi.new("images/fx/buildupflame")
    ANIMATIONS.flame = {
        ember  = animloop.new(4 * frame_ms, gfxit.new("images/fx/ember"), true),
        low    = animloop.new(4 * frame_ms, gfxit.new("images/fx/lowflame"), true),
        medium = animloop.new(4 * frame_ms, gfxit.new("images/fx/mediumflame"), true),
        high   = animloop.new(4 * frame_ms, gfxit.new("images/fx/highflame"), true),
        stir   = animloop.new(3.33 * frame_ms, gfxit.new("images/fx/stirredflame"), true)
    }
    ANIMATIONS.b_prompt     = animloop.new(8 * frame_ms, gfxit.new("images/animation-b"), true)
    ANIMATIONS.b_prompt.paused = true

    -- Load fonts
    FONTS.speech_font = gfx.font.new("fonts/froggotini17")


    -- Set the multiple things in their Z order of what overlaps what.

    table.insert(DRAW_PASSES, Set_draw_pass(-40, draw_game_background))
    -- -5: shelved ingredients
    table.insert(DRAW_PASSES, Set_draw_pass(-2, draw_bg_lighting, HIDE.on_recipe))
    table.insert(DRAW_PASSES, Set_draw_pass(0, draw_cauldron, HIDE.on_recipe))
    table.insert(DRAW_PASSES, Set_draw_pass(1, draw_liquid_surface, HIDE.on_recipe))
    table.insert(DRAW_PASSES, Set_draw_pass(2, draw_stirring_stick_back, HIDE.on_recipe)) -- draw ladle when on farther side
    table.insert(DRAW_PASSES, Set_draw_pass(3, draw_liquid_bubbles_and_drops, HIDE.on_recipe))
    -- 3: ingredient drops floating in the liquid
    -- 4: ingredient slotted over cauldron
    table.insert(DRAW_PASSES, Set_draw_pass(5, draw_stirring_bubbles, HIDE.on_recipe))
    -- 6: ingredient drop splash
    table.insert(DRAW_PASSES, Set_draw_pass(7, draw_symbols, HIDE.on_recipe))
    table.insert(DRAW_PASSES, Set_draw_pass(8, draw_stirring_stick_front, HIDE.on_recipe)) -- draw ladle when on front side
    table.insert(DRAW_PASSES, Set_draw_pass(9, draw_cauldron_front))
    -- 10: frog
    -- depth 20+: UI
    table.insert(DRAW_PASSES, Set_draw_pass(21, draw_ui_prompts, HIDE.on_drink))
    table.insert(DRAW_PASSES, Set_draw_pass(23, draw_ingredient_place_hint, HIDE.on_drink))
    -- 24: grabbed ingredients
    table.insert(DRAW_PASSES, Set_draw_pass(27, draw_ingredient_grab_cursor, HIDE.on_drink))
    table.insert(DRAW_PASSES, Set_draw_pass(25, draw_dialog_bubble))
    -- depth 30+: overlaid modal instructions
    table.insert(DRAW_PASSES, Set_draw_pass(30, draw_overlaid_instructions))
    table.insert(DRAW_PASSES, Set_draw_pass(35, draw_overlaid_recipe))
    -- Development
    --table.insert(DRAW_PASSES, Set_draw_pass(50, draw_debug))
    --table.insert(DRAW_PASSES, Set_draw_pass(50, draw_debug_fps))
end

Z_DEPTH = {
    frog = 10,
    ingredients_in_shelve = -5,
    ingredient_drops = 3,
    ingredient_slotted_over_cauldron = 4,
    ingredient_drop_splash = 6,
    grabbed_ingredient = 26
}
