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
local fmod <const> = math.fmod
local random <const> = math.random
local PI <const> = 3.141592653589793
local TWO_PI <const> = 6.283185307179586
local PHI <const> = PI * (sqrt(5.0) - 1.0) -- Golden angle in radians


-- Resources
FONTS = {}
TEXTURES = {}
ANIMATIONS = {}

-- Constants
LIQUID_CENTER_X, LIQUID_CENTER_Y = 145, 175
LIQUID_WIDTH, LIQUID_HEIGHT = 66, 29
LIQUID_AABB = geo.rect.new(
    LIQUID_CENTER_X-LIQUID_WIDTH,
    LIQUID_CENTER_Y-LIQUID_HEIGHT*0.5,
    LIQUID_WIDTH*2, LIQUID_HEIGHT)
MAGIC_TRIANGLE_CENTER_X, MAGIC_TRIANGLE_CENTER_Y = 150, 112
MAGIC_TRIANGLE_SIZE = 100

-- check for the fog if conditions are correct at the right time
CHECK_IF_DELICIOUS = false

-- Debug / Development

local function draw_test_dither_patterns()

    local dither_types = {
        gfxi.kDitherTypeNone,
        gfxi.kDitherTypeDiagonalLine,
        gfxi.kDitherTypeVerticalLine,
        gfxi.kDitherTypeHorizontalLine,
        gfxi.kDitherTypeScreen,
        gfxi.kDitherTypeBayer2x2,
        gfxi.kDitherTypeBayer4x4,
        gfxi.kDitherTypeBayer8x8,
        gfxi.kDitherTypeFloydSteinberg,
        gfxi.kDitherTypeBurkes,
        gfxi.kDitherTypeAtkinson
    }
    local size = 20
    local x = 2
    local y = 2

    gfx.pushContext()
        gfx.setColor(gfx.kColorWhite)

        -- kDitherTypeBayer8x8 gradient
        local dither_type = gfxi.kDitherTypeBayer8x8
        local pattern_img = gfxi.new(size, size, gfx.kColorBlack)
        for i = 0, 10, 1 do
            pattern_img:clear(gfx.kColorBlack)
            gfx.pushContext(pattern_img)
                gfx.setDitherPattern(i/10, dither_type)
                gfx.fillRect(0, 0, size, size)
            gfx.popContext()
            pattern_img:draw(x, y)
            y += size+2
        end

        -- different types
        local alpha = 0.0
        for a = 0, 10, 1 do
            y = 2
            x += size
            for i = 0, 10, 1 do
                pattern_img:clear(gfx.kColorBlack)
                gfx.pushContext(pattern_img)
                    gfx.setDitherPattern(alpha, dither_types[i+1])
                    gfx.fillRect(0, 0, size, size)
                gfx.popContext()
                pattern_img:draw(x, y)
                y += size+2
            end
            alpha += 0.1
        end
     gfx.popContext()

end


-- Draw passes

local function draw_soft_circle(x_center, y_center, radius, steps, blend, alpha, color)
    gfx.pushContext()
        for a = 1, steps, 1 do
            gfx.setColor(color)
            gfx.setDitherPattern((1 - a / steps * alpha), gfxi.kDitherTypeBayer4x4)
            gfx.fillCircleAtPoint(x_center, y_center, (1 - a / steps) * radius * blend + radius)
        end
    gfx.popContext()
end

local function draw_soft_ring(x_center, y_center, radius, steps, blend, alpha, color)
    gfx.pushContext()
        for a = 1, steps, 1 do
            gfx.setColor(color)
            gfx.setDitherPattern((1 - a / steps * alpha), gfxi.kDitherTypeBayer4x4)
            gfx.drawCircleAtPoint(x_center, y_center, (1 - a / steps) * radius * blend + radius)
        end
    gfx.popContext()
end

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


local function draw_symbols()
    local PI <const> = 3.141592653589793

    local rune_area_x = MAGIC_TRIANGLE_CENTER_X
    local rune_area_y = MAGIC_TRIANGLE_CENTER_Y - 60
    local rune_area_width = 80
    local rune_area_height = 60

    local wiggle_freq_avg = 2
    local freq_var = 0.1
    local lower_glow_start = -0.8 -- It takes a bit of heat for glow to start
    local upper_glow_end = 2 -- It takes a lot of  time for glow to decay

    local should_draw_on_target_anim = GAMEPLAY_STATE.dropped_ingredients == 0 and GAMEPLAY_STATE.heat_amount > 0.3
    local heat_response = min(sqrt(max(GAMEPLAY_STATE.heat_amount * 1.2, 0)), 1)
    local glow_strength = (lower_glow_start * (1 - heat_response)) + (upper_glow_end * heat_response)
    glow_strength = Clamp(glow_strength, 0, 1) * 0.75
    local glyph_overlay_alpha = max(0.8-GAMEPLAY_STATE.heat_amount * 2, 0) * 0.8

    local rune_count_travel = {0, 0, 0}
    for k, v in pairs(rune_count_travel) do
        rune_count_travel[k] = GAMEPLAY_STATE.rune_count_unstirred[k] * (1 - STIR_FACTOR) + (GAMEPLAY_STATE.rune_count[k] * STIR_FACTOR)
    end

    gfx.pushContext()
        for a = 1, NUM_RUNES do
            if TARGET_COCKTAIL.rune_count[a] == 0 then
                -- Don't draw disabled runes
                goto continue
            end
            local wiggle_freq = wiggle_freq_avg + (a - 2) * freq_var
            local wiggle = sin(GAMEPLAY_STATE.game_tick / 30 * wiggle_freq + PI * 0.3)

            local glyph_x = rune_area_x + rune_area_width * 0.5 * (a - 2)
            local glyph_y = rune_area_y - (rune_count_travel[a] - 0.5) * rune_area_height + wiggle
            local target_y = rune_area_y - (TARGET_COCKTAIL.rune_count[a] - 0.5) * rune_area_height + wiggle
            local glyph_topleft_x = glyph_x - TEXTURES.rune_images[a].width * 0.5
            local glyph_topleft_y = glyph_y - TEXTURES.rune_images[a].height * 0.5

            -- Rune circle
            draw_soft_circle(glyph_x, glyph_y, 10 * glow_strength + 3, 3, 0.5, glow_strength, gfx.kColorWhite)

            -- Target ring
            draw_soft_ring(glyph_x, target_y, 10 * glow_strength + 7, 3, 0.5, glow_strength, gfx.kColorWhite)

            -- Rune image
            if should_draw_on_target_anim and DIFF_TO_TARGET.runes_abs[a] < GOAL_TOLERANCE then
                ANIMATIONS.rune_correct[a]:draw(glyph_topleft_x, glyph_topleft_y)
            else
                TEXTURES.rune_images[a]:draw(glyph_topleft_x, glyph_topleft_y)
            end

            gfx.pushContext()
                gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
                TEXTURES.rune_images[a]:drawFaded(glyph_topleft_x, glyph_topleft_y, glyph_overlay_alpha, gfxi.kDitherTypeBayer4x4)
            gfx.popContext()
            ::continue::
        end

    gfx.popContext()
end


local function draw_stirring_stick()
    gfx.pushContext()
    do
        local t = STIR_POSITION

        -- Calculate 2 elipses:
        -- 'a': for the path of the top point of the stick,
        -- 'b': for the bottom point
        local stick_width, stick_height, stick_tilt = 10, 60, 45
        local stick_half_width = stick_width * 0.5
        local ellipse_height = LIQUID_HEIGHT - 5 -- Lil' bit less than the actual liquid height.
        local ellipse_bottom_width = LIQUID_WIDTH - 10 -- Lil' bit less than liquid
        local ellipse_top_width = ellipse_bottom_width + stick_tilt

        local a_x = cos(t) * ellipse_top_width + LIQUID_CENTER_X
        local a_y = sin(t) * ellipse_height + LIQUID_CENTER_Y - stick_height
        local b_x = cos(t) * ellipse_bottom_width + LIQUID_CENTER_X
        local b_y = sin(t) * ellipse_height + LIQUID_CENTER_Y

        -- Bottom offset is used to make sure that the bottom stick doesn't go out of the water
        local bot_offset = 0
        if t > PI and t < TWO_PI then
            local max_amp = 15
            bot_offset = sin(t) * max_amp * Clamp(abs(GAMEPLAY_STATE.liquid_momentum) / 20, 0, 1)
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
    -- Draw the laddle only if it's on the farther side of the cauldron
    if STIR_POSITION >= PI and STIR_POSITION < TWO_PI then
        draw_stirring_stick()
    end
end


local function draw_stirring_stick_front()
    -- Draw the laddle only if it's on the front side of the cauldron
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
        -- Draw fill: black clear color
        gfx.setColor(gfx.kColorBlack)
        gfx.fillPolygon(liquid_surface)
        -- Draw fill: dithered white pattern
        gfx.setColor(gfx.kColorWhite)
        gfx.setDitherPattern((1 - GAMEPLAY_STATE.potion_color), gfx.image.kDitherTypeBayer8x8)
        gfx.fillPolygon(liquid_surface)
        -- Draw line
        gfx.setColor(gfx.kColorWhite)
        gfx.setLineWidth(3)
        gfx.drawPolygon(liquid_surface)
    gfx.popContext()
end

Bubbles_amplitude = {}
Bubbles_radians = {}
Bubbles_tick_offset = {}
Bubbles_animation_playing = {}
Bubbles_flip = {}
Bubbles_types = {}
Bubbles_animation_length = {}
NUM_BUBBLES = 10
for a = 1, NUM_BUBBLES, 1 do
    local y = 1 - ((a - 1) / (NUM_BUBBLES - 1)) * 2
    Bubbles_amplitude[a] = sqrt(1 - y * y) * 0.8 + 0.2
    Bubbles_radians[a] = PHI * (a - 1) -- Golden angle increment
    Bubbles_tick_offset[a] = floor(PHI * (a - 1) * 50)
    Bubbles_types[a] = 0
end

local function draw_liquid_bubbles()
    local TWO_PI <const> = 6.283185307179586

    gfx.pushContext()
    do
        local ellipse_height = LIQUID_HEIGHT - 5 -- Lil' bit less than the actual liquid height.
        local ellipse_bottom_width = LIQUID_WIDTH - 10 -- Lil' bit less than liquid

        local freq = 0.65
        local speed_fac = 0.035 -- speed of the waves (0.01 slow 0.1 fast)
        local offset = GAMEPLAY_STATE.liquid_offset * speed_fac * freq / 2

        for x = 1, NUM_BUBBLES, 1 do
            if not Bubbles_animation_playing[x] and GAMEPLAY_STATE.heat_amount > random() + 0.1 then
                Bubbles_animation_playing[x] = true
                Bubbles_flip[x] = random() > 0.5
                if random() > 0.9 then
                    Bubbles_types[x] = -1
                end
            end
        end
        for x = 1, NUM_BUBBLES, 1 do
            if not Bubbles_animation_playing[x] then goto continue end

            local bubble_rad = Bubbles_radians[x] + offset
            local bubble_amp = Bubbles_amplitude[x]

            local bot_offset = 0
            if sin(bubble_rad) < 0 then
                local max_amp = 15
                bot_offset = sin(bubble_rad) * max_amp * Clamp(abs(GAMEPLAY_STATE.liquid_momentum) / 20, 0, 1)
            end

            local b_x = bubble_amp * cos(bubble_rad) * ellipse_bottom_width + LIQUID_CENTER_X
            local b_y = bubble_amp * sin(bubble_rad) * ellipse_height + LIQUID_CENTER_Y - bot_offset

            local bubble_tab = ANIMATIONS.bubble
            local bub_off_x, bub_off_y = 5, 12

            -- Check if they are bubbles
            if Bubbles_types[x] < 0 then
                bubble_tab = ANIMATIONS.bubble2
                bub_off_x, bub_off_y = 12, 12
            end

            local anim_length = 0
            -- Check if they are ingredient drops
            if Bubbles_types[x] <= 0 then
                anim_length = bubble_tab:getLength()
                anim_tick = fmod(Bubbles_tick_offset[x] + GAMEPLAY_STATE.game_tick // 3, anim_length)
            else
                anim_length = 30
                anim_tick = STIR_FACTOR * (anim_length -1)
            end


            if Bubbles_types[x] > 0 then
                -- This is the spot for adding a factor. Might need to split the bubble sinking time from drop sprites.
                local sink = sin(GAMEPLAY_STATE.game_tick / TWO_PI * 0.7 + Bubbles_tick_offset[x]) * 0.3 + (anim_tick / anim_length)
                local drop_sprite = INGREDIENT_TYPES[Bubbles_types[x]].drop
                local offset_y = drop_sprite.height * sink
                local mask = geo.rect.new(0, 0, drop_sprite.width, drop_sprite.height - offset_y)
              if Bubbles_flip[x] then
                drop_sprite:draw(b_x - drop_sprite.width/2, b_y - drop_sprite.height/2 + offset_y - 12, "flipX", mask)
              else
                drop_sprite:draw(b_x - drop_sprite.width/2, b_y - drop_sprite.height/2 + offset_y - 12, 0, mask)
              end
            else
              if Bubbles_flip[x] then
                  bubble_tab[anim_tick + 1]:draw(b_x - bub_off_x, b_y - bub_off_y, "flipX")
              else
                  bubble_tab[anim_tick + 1]:draw(b_x - bub_off_x, b_y - bub_off_y)
              end
            end

            if (anim_tick + 1) == anim_length then
               Bubbles_animation_playing[x] = false
               Bubbles_types[x] = 0
            end
            ::continue::
        end
    end
    gfx.popContext()
end


local function draw_overlayed_instructions()
    if GAMEPLAY_STATE.showing_cocktail then
        gfx.pushContext()
            COCKTAILS[TARGET_COCKTAIL.type_idx].img:draw(0, 0)
        gfx.popContext()
    end

    if GAMEPLAY_STATE.showing_instructions then
        gfx.pushContext()
            TEXTURES.instructions:draw(400-TEXTURES.instructions.width, 0)
        gfx.popContext()
    end
end

local function draw_overlayed_recipe()
    if GAMEPLAY_STATE.showing_recipe then
        Recipe_draw_success(end_recipe_y)
    end
end

local function draw_dialog_bubble()
    if SPEECH_BUBBLE_ANIM then
        -- Should be displaying an animated speech bubble.

        gfx.pushContext()
            SPEECH_BUBBLE_ANIM:image():draw(0, 0)
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

    end
end


local function draw_bg_lighting()
    local flicker_freq <const> = {0.0023, 0.3, 5.2}
    local flicker_strength <const> = {0.01, 0.002, 0.004}
    local tick <const> = GAMEPLAY_STATE.game_tick + random()
    local time <const>  = TWO_PI * (tick - fmod(tick, 8)) / playdate.getFPS()

    local flicker = 0
    for a = 1, #flicker_freq, 1 do
        flicker += sin(time * flicker_freq[a]) * flicker_strength[a]
    end
    flicker *= (1 - GAMEPLAY_STATE.heat_amount ^ 2)

    local light_strength = (GAMEPLAY_STATE.heat_amount * 0.8 + 0.2 ) + flicker
    local glow_center_x = LIQUID_CENTER_X
    local glow_center_y = 240
    local glow_width = 200 + light_strength * 60
    local glow_height = 120 + light_strength * 40
    local glow_blend = max(0.25, light_strength) * 0.8

    gfx.pushContext()
        draw_soft_ellipse(glow_center_x, glow_center_y, glow_width, glow_height, 6, glow_blend, light_strength * 0.5, gfx.kColorWhite)
    gfx.popContext()
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
        TEXTURES.cauldron:draw(43, 128)
    gfx.popContext()
end

local buildupflame_counter = 0

local function draw_cauldron_front()
    -- Draw cauldron foreground image
    gfx.pushContext()
        TEXTURES.cauldron_front:draw(43, 128)
    gfx.popContext()

    -- Draw flame animation
    gfx.pushContext()
        if GAMEPLAY_STATE.flame_amount > 0.8 then
            buildupflame_counter += 1
            if buildupflame_counter < 5 then
                TEXTURES.flame_buildup:draw(-1, 0)
            else
                ANIMATIONS.flame.stir:draw(-1, 0)
            end
        elseif GAMEPLAY_STATE.flame_amount > 0.5 then
            buildupflame_counter = buildupflame_counter * 0.5
            if buildupflame_counter > 2 then
                ANIMATIONS.flame.stir:draw(-1, 0)
            else
                ANIMATIONS.flame.high:draw(-1, 0)
                buildupflame_counter = 0
            end
        elseif GAMEPLAY_STATE.heat_amount > 0.4 then
            ANIMATIONS.flame.medium:draw(-1, 0)
        elseif GAMEPLAY_STATE.heat_amount > 0.2 then
            ANIMATIONS.flame.low:draw(-1, 0)
        elseif GAMEPLAY_STATE.heat_amount > 0.08 then
            ANIMATIONS.flame.ember:draw(-1, 0)
        end
    gfx.popContext()
end


local function draw_ui_prompts()
    if GAME_ENDED then
        -- Disappear button prompts when the game transitions to win!
        return
    end

    gfx.pushContext()
    TEXTURES.instructions_prompt:draw(-10, 240-TEXTURES.instructions_prompt.height, 0)
    ANIMATIONS.b_prompt:draw(362, 203)
    gfx.popContext()

    if Is_potion_good_enough() then
        local time = playdate.getElapsedTime()
        local pulsing_freq = 1
        local pulse = math.sin(time * 1 * math.pi * (pulsing_freq + 0.1))
        gfx.pushContext()
        draw_soft_ring(381, 222, 15 + pulse, 7, 0.7, (pulse + 1) / 2, gfx.kColorWhite) -- tmp. need to animate radius
        gfx.popContext()
    end
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

    -- Cauldron hit zone
    gfx.pushContext()
        gfx.setColor(gfx.kColorWhite)
        gfx.setLineWidth(2)
        gfx.drawRect(LIQUID_AABB)
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
    gfx.pushContext()
        if GAMEPLAY_STATE.cursor_hold then
            TEXTURES.cursor_hold:drawCentered(GYRO_X, GYRO_Y)
        else
            TEXTURES.cursor:drawCentered(GYRO_X, GYRO_Y)
        end
    gfx.popContext()
end


local function draw_ingredient_place_hint()
    gfx.pushContext()
        -- Blink the circle on and off every 12 frames
        local blink_time = 12
        if GAMEPLAY_STATE.cursor_hold and GAMEPLAY_STATE.game_tick % blink_time*2 > blink_time then
          TEXTURES.place_hint:drawCentered(MAGIC_TRIANGLE_CENTER_X, MAGIC_TRIANGLE_CENTER_Y)
        end
    gfx.popContext()
end


-- Set a draw pass on Z depth

function Set_draw_pass(z, drawCallback)
    local sprite = gfx.sprite.new()
    sprite:setSize(playdate.display.getSize())
    sprite:setCenter(0, 0)
    sprite:moveTo(0, 0)
    sprite:setZIndex(z)
    sprite:setIgnoresDrawOffset(true)
    sprite:setUpdatesEnabled(false)
    sprite.draw = function(s, x, y, w, h)
        drawCallback(x, y, w, h)
    end
    sprite:add()
    return sprite
end


-- Load resources and initialize draw passes
DRAW_PASSES = {}

function Init_visuals()

    -- Load image layers.
    TEXTURES.bg = gfxi.new("images/bg")
    TEXTURES.cauldron = gfxi.new("images/cauldron")
    TEXTURES.cauldron_front = gfxi.new("images/cauldron_front")
    TEXTURES.instructions_prompt = gfxi.new("images/instructions_prompt")
    TEXTURES.dialog_bubble_oneline = gfxi.new("images/speech/speechbubble_oneline_wide")
    TEXTURES.dialog_bubble_twolines = gfxi.new("images/speech/speechbubble_twolines_extrawide")
    TEXTURES.instructions = gfxi.new("images/instructions")
    if playdate.isSimulator then
        TEXTURES.instructions = gfxi.new("images/instructions_sim")
    end
    TEXTURES.recipe_top = gfxi.new("images/recipes/recipe_top_section")
    TEXTURES.recipe_bottom = gfxi.new("images/recipes/recipe_bottom_section")
    TEXTURES.recipe_middle = {  gfxi.new("images/recipes/recipe_mid_1"),
                                gfxi.new("images/recipes/recipe_mid_2"),
                                gfxi.new("images/recipes/recipe_mid_3"),}
    TEXTURES.recipe_small_top = gfxi.new("images/recipes/recipe__small_top_section")
    TEXTURES.recipe_small_middle = gfxi.new("images/recipes/recipe__small_mid")
    TEXTURES.recipe_small_bottom = gfxi.new("images/recipes/recipe_small_bottom_section")
    -- Load images
    TEXTURES.cursor = gfxi.new("images/cursor/open_hand")
    TEXTURES.cursor_hold = gfxi.new("images/cursor/closed_hand")
    TEXTURES.place_hint = gfxi.new("images/cursor/empty_jar")
    TEXTURES.rune_images = {gfxi.new("images/passion"), gfxi.new("images/doom"), gfxi.new("images/weeds")}
    ANIMATIONS.rune_correct = {
        animloop.new(8 * frame_ms, gfxit.new("images/love_correct"), true),
        animloop.new(8 * frame_ms, gfxit.new("images/doom_correct"), true),
        animloop.new(8 * frame_ms, gfxit.new("images/weeds_correct"), true)}
    -- Load fx
    -- Load animation images and initialize animation loop timers.
    ANIMATIONS.bubble = gfxit.new("images/fx/bubble")
    ANIMATIONS.bubble2 = gfxit.new("images/fx/bubble2")
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
    table.insert(DRAW_PASSES, Set_draw_pass(-2, draw_bg_lighting))
    --table.insert(DRAW_PASSES, Set_draw_pass(-1, draw_liquid_glow))
    table.insert(DRAW_PASSES, Set_draw_pass(0, draw_cauldron))
    table.insert(DRAW_PASSES, Set_draw_pass(2, draw_liquid_surface))
    table.insert(DRAW_PASSES, Set_draw_pass(3, draw_stirring_stick_back)) -- draw ladle when on farther side
    table.insert(DRAW_PASSES, Set_draw_pass(4, draw_liquid_bubbles))
    -- 4: ingredient drops floating in the liquid
    -- 5: ingredient drop splash
    -- 5: ingredient slotted over cauldron
    table.insert(DRAW_PASSES, Set_draw_pass(6, draw_symbols))
    table.insert(DRAW_PASSES, Set_draw_pass(7, draw_stirring_stick_front)) -- draw ladle when on front side
    table.insert(DRAW_PASSES, Set_draw_pass(8, draw_cauldron_front))
    -- 10: frog
    -- depth 20+: UI
    table.insert(DRAW_PASSES, Set_draw_pass(21, draw_ui_prompts))
    table.insert(DRAW_PASSES, Set_draw_pass(23, draw_ingredient_place_hint))
    -- 24: grabbed ingredients
    table.insert(DRAW_PASSES, Set_draw_pass(25, draw_ingredient_grab_cursor))
    table.insert(DRAW_PASSES, Set_draw_pass(27, draw_dialog_bubble))
    -- depth 30+: overlayed modal instructions
    table.insert(DRAW_PASSES, Set_draw_pass(30, draw_overlayed_instructions))
    table.insert(DRAW_PASSES, Set_draw_pass(35, draw_overlayed_recipe))
    -- Development
    --table.insert(DRAW_PASSES, Set_draw_pass(50, draw_debug))
    table.insert(DRAW_PASSES, Set_draw_pass(50, draw_debug_fps))
    --table.insert(DRAW_PASSES, Set_draw_pass(50, draw_test_dither_patterns))
end

Z_DEPTH = {
    frog = 10,
    ingredients_in_shelve = -5,
    indredient_drops = 4,
    ingredient_slotted_over_cauldron = 5,
    ingredient_drop_splash = 5,
    grabbed_ingredient = 24
}
