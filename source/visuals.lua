local gfx <const> = playdate.graphics
local gfxi <const> = playdate.graphics.image
local gfxit <const> = playdate.graphics.imagetable
local animloop <const> = playdate.graphics.animation.loop
local geo <const> = playdate.geometry
local vec2d <const> = playdate.geometry.vector2D
local inOutQuad <const> = playdate.easingFunctions.inOutQuad
local outBack <const> = playdate.easingFunctions.outBack
local animator <const> = playdate.graphics.animator


-- Resources
FONTS = {}
TEXTURES = {}

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
DELICIOUS_CHECK = false

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
    for a = 1, steps, 1 do
        gfx.pushContext()
            gfx.setColor(color)
            gfx.setDitherPattern((1 - a / steps * alpha), gfxi.kDitherTypeBayer4x4)
            gfx.fillCircleAtPoint(x_center, y_center, (1 - a / steps) * radius * blend + radius)
        gfx.popContext()
    end
end

local function draw_soft_ring(x_center, y_center, radius, steps, blend, alpha, color)
    for a = 1, steps, 1 do
        gfx.pushContext()
            gfx.setColor(color)
            gfx.setDitherPattern((1 - a / steps * alpha), gfxi.kDitherTypeBayer4x4)
            gfx.drawCircleAtPoint(x_center, y_center, (1 - a / steps) * radius * blend + radius)
        gfx.popContext()
    end
end

local function draw_soft_ellipse(x_center, y_center, width, height, steps, blend, alpha, color)
    for a = 1, steps, 1 do
        gfx.pushContext()
            local iteration_width = (1 - a / steps) * width * blend + width
            local iteration_height = (1 - a / steps) * height * blend + height
            local ellipse_bb = geo.rect.new(x_center - iteration_width * 0.5, y_center - iteration_height * 0.5, iteration_width, iteration_height)
            gfx.setColor(color)
            gfx.setDitherPattern((1 - a / steps * alpha), gfxi.kDitherTypeBayer4x4)
            gfx.fillEllipseInRect(ellipse_bb)
        gfx.popContext()
    end
end

local new_rune_count = {0, 0, 0}

function add_rune_travel_anim()

    -- add current rune count and new anim to table
    local rune_count = shallow_copy(GAMEPLAY_STATE.rune_count)
    table.insert(rune_anim_table, {rune_count, animator.new(3*1000, 0.0, 1.0, inOutQuad), animator.new(200*1000, 0.0, 1.0, inOutQuad)})

end


local function draw_symbols( x, y, width, position_params)
    local params = position_params
    if params == nil then
        return
    end

    local wiggle_freq_avg = 2
    local freq_var = 0.1

    local meter_height = 60
    gfx.pushContext()
        local n = #params
        for a = 1, n, 1 do
            local glyph_width = TEXTURES.rune_images[a].width
            local glyph_height = TEXTURES.rune_images[a].height
            local glyph_x = x + width * 0.5 * (a - 2)
            local wiggle_freq = wiggle_freq_avg + (a - 2) * freq_var
            local wiggle = math.sin(GAMEPLAY_STATE.game_tick / 30 * wiggle_freq + math.pi * 0.3)
            local glyph_y = y

            local target = TARGET_COCKTAIL.rune_count[a]
            local difference_weight = math.max(target, 1-target)
            local heat_response = math.min(math.sqrt(math.max(GAMEPLAY_STATE.heat_amount * 1.2, 0)), 1)
            local lower_glow_start = -0.8 -- It takes a bit of heat for glow to start
            local upper_glow_end = 2 -- It takes a lot of  time for glow to decay
            local glow_strength = (lower_glow_start * (1 - heat_response)) + (upper_glow_end * heat_response)
            glow_strength = Clamp(glow_strength, 0, 1) * 0.75

            -- Calculate current_rune_count
            local animated_rune_count = {0, 0, 0}
            local avg_count = {0, 0, 0}
            for anim_index, anim_content in pairs(rune_anim_table) do

                local rune_count = anim_content[1]
                local progress_fast = anim_content[2]:progress()
                local progress_slow = anim_content[3]:progress()
                local progress_stirred = progress_fast * STIR_FACTOR + progress_slow * (1 - STIR_FACTOR)
                for k, v in pairs(rune_count) do
                    animated_rune_count[k] = avg_count[k] * (1 - progress_stirred) + v * progress_stirred
                    avg_count[k] = animated_rune_count[k]
                end
            end

            -- Update glyph positions
            glyph_y = glyph_y - (animated_rune_count[a] - 0.5) * meter_height
            glyph_y += wiggle

            -- Reset anim table if all animations are done
            local rune_anim_progress_avg = 0
            local rune_anim_table_count = getTableSize(rune_anim_table)
            for anim_index, anim_content in pairs(rune_anim_table) do
                local progress_fast = anim_content[2]:progress()
                local progress_slow = anim_content[3]:progress()
                local progress_stirred = progress_fast * STIR_FACTOR + progress_slow * (1 - STIR_FACTOR)
                rune_anim_progress_avg += progress_stirred / rune_anim_table_count
            end
            if rune_anim_progress_avg == 1 then
                if #rune_anim_table > 1 then
                    DELICIOUS_CHECK = true
                end
                local true_rune_count = shallow_copy(GAMEPLAY_STATE.rune_count)

                rune_anim_table = {}
                table.insert(rune_anim_table, {true_rune_count, animator.new(0, 1.0, 1.0), animator.new(0, 1.0, 1.0)})
            end

            local target_y = y - (target - 0.5) * meter_height + wiggle

            -- Rune circle
            gfx.setColor(gfx.kColorWhite)
            gfx.setDitherPattern(1 - heat_response, gfxi.kDitherTypeBayer4x4)
            draw_soft_circle(glyph_x, glyph_y, 10 * glow_strength + 3, 3, 0.5, glow_strength, gfx.kColorWhite)

            -- Target ring
            gfx.setColor(gfx.kColorWhite)
            gfx.setDitherPattern(1 - heat_response, gfxi.kDitherTypeBayer4x4)
            draw_soft_ring(glyph_x, target_y, 10 * glow_strength + 7, 3, 0.5, glow_strength, gfx.kColorWhite)


            gfx.pushContext()
            local tolerance = 0.1
            local rune_graphic = nil
            if math.abs(DIFF_TO_TARGET.runes[a]) < tolerance and #rune_anim_table <= 1 then
                TEXTURES.rune_correct[a]:draw(glyph_x - glyph_width * 0.5, glyph_y - glyph_height * 0.5)
            else
                    TEXTURES.rune_images[a]:draw(glyph_x - glyph_width * 0.5, glyph_y - glyph_height * 0.5)
                end
                gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
                local overlay = math.max(0.8-GAMEPLAY_STATE.heat_amount * 2, 0) * 0.8
                TEXTURES.rune_images[a]:drawFaded(glyph_x - glyph_width * 0.5, glyph_y - glyph_height * 0.5, overlay, gfxi.kDitherTypeBayer4x4)
                gfx.popContext()
            end

    gfx.popContext()
end


local function draw_parameter_diagram()
    local params = {}
    for k, v in pairs(GAMEPLAY_STATE.rune_count) do
        params[k] = v
    end

    local sum = 0
    for a = 1, #params, 1 do
        sum = sum + params[a]
    end
    if sum ~= 0 then
        for a = 1, #params, 1 do
            params[a] = params[a] / sum
        end
    end

    draw_symbols(MAGIC_TRIANGLE_CENTER_X, 122 - 70, 80, params)
end


local function draw_stirring_stick()
    gfx.pushContext()
    do
        local t = STIR_POSITION

        -- Calculate 2 elipses:
        -- 'a': for the path of the top point of the stick,
        -- 'b': for the bottom point
        local stick_width, stick_height, stick_tilt = 10, 60, 45
        local ellipse_height = LIQUID_HEIGHT - 5 -- Lil' bit less than the actual liquid height.
        local ellipse_bottom_width = LIQUID_WIDTH - 10 -- Lil' bit less than liquid
        local ellipse_top_width = ellipse_bottom_width + stick_tilt

        local a_x = math.cos(t) * ellipse_top_width + LIQUID_CENTER_X
        local a_y = math.sin(t) * ellipse_height + LIQUID_CENTER_Y - stick_height
        local b_x = math.cos(t) * ellipse_bottom_width + LIQUID_CENTER_X
        local b_y = math.sin(t) * ellipse_height + LIQUID_CENTER_Y

        -- Bottom offset is used to make sure that the bottom stick doesn't go out of the water
        local bot_offset = 0
        if t > math.pi and t < 2*math.pi then
            local max_amp = 15
            bot_offset = math.sin(t) * max_amp * Clamp(math.abs(GAMEPLAY_STATE.liquid_momentum) / 20, 0, 1)
            local vec_top = vec2d.new(a_x, a_y)
            local vec_bot = vec2d.new(b_x, b_y)
            local vec_dir = vec_bot - vec_top
            vec_dir:normalize()
            vec_bot = vec_bot - vec_dir * bot_offset
            b_x, b_y = vec_bot:unpack()
        end

        -- Draw stick
        local stick_outline_width = 3
        local stick_outer = playdate.geometry.polygon.new(4)
        stick_outer:setPointAt(1, a_x + stick_width/2 + stick_outline_width, a_y)
        stick_outer:setPointAt(2, a_x - stick_width/2 - stick_outline_width, a_y)
        stick_outer:setPointAt(3, b_x - stick_width/2 - stick_outline_width, b_y)
        stick_outer:setPointAt(4, b_x + stick_width/2 + stick_outline_width, b_y)
        stick_outer:close()

        local stick_inner = playdate.geometry.polygon.new(4)
        stick_inner:setPointAt(1, a_x + stick_width/2, a_y)
        stick_inner:setPointAt(2, a_x - stick_width/2, a_y)
        stick_inner:setPointAt(3, b_x - stick_width/2, b_y)
        stick_inner:setPointAt(4, b_x + stick_width/2, b_y)
        stick_inner:close()
        

        gfx.setColor(gfx.kColorWhite)
        gfx.fillCircleAtPoint(a_x, a_y, stick_width / 2 + stick_outline_width - 1)
        gfx.fillPolygon(stick_outer)

        gfx.setColor(gfx.kColorBlack)
        gfx.fillCircleAtPoint(a_x, a_y, stick_width / 2 -1)
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
    if STIR_POSITION >= math.pi and STIR_POSITION < 2*math.pi then
        draw_stirring_stick()
    end
end


local function draw_stirring_stick_front()
    -- Draw the laddle only if it's on the front side of the cauldron
    if STIR_POSITION > 0 and STIR_POSITION < math.pi then
        draw_stirring_stick()
    end
end


local function draw_liquid_glow()

    local target = TARGET_COCKTAIL.color
    local difference_weight = math.max(target, 1-target)
    
    local heat_response = math.min(math.sqrt(math.max(GAMEPLAY_STATE.heat_amount * 1.2, 0)), 1)
    local light_strength = STIR_FACTOR * 0.6
    local glow_center_x = LIQUID_CENTER_X + 2
    local glow_center_y = LIQUID_CENTER_Y
    local glow_width = LIQUID_WIDTH + 100 + light_strength * 20
    local glow_height = LIQUID_HEIGHT + 60 + light_strength * 10
    local glow_blend = math.max(0.25, light_strength) * 0.3
    gfx.pushContext()
        draw_soft_ellipse(glow_center_x, glow_center_y, glow_width, glow_height, 3, glow_blend, light_strength, gfx.kColorWhite)
    gfx.popContext()
end


local function draw_liquid_surface()
    gfx.pushContext()
    do
        local polygon = playdate.geometry.polygon
        local num_points = 64
        -- freq 0.4 speed_fac 0.05 vicousity 0.85 --> viscous
        -- freq 0.9 speed_fac 0.02 vicousity 0.95 --> liquid

        local freq = MapRange(GAMEPLAY_STATE.liquid_viscosity, 0.85, 0.95, 0.4, 0.9)
        -- maximum amplitude in pixels
        local max_amp = 15
        -- speed of the waves (0.01 slow 0.1 fast)
        local speed_fac = MapRange(GAMEPLAY_STATE.liquid_viscosity, 0.85, 0.95, 0.05, 0.02)

        local offset = GAMEPLAY_STATE.liquid_offset * speed_fac
        local amp_fac = Clamp(math.abs(GAMEPLAY_STATE.liquid_momentum) / 20, 0, 1)

        local surface = polygon.new(num_points)
        for i=1,num_points do
            local angle = i / num_points * math.pi * 2

            -- Only affects points at the back side of the cauldron
            local x = math.max(i - num_points / 2, 0)
            local amplitude = math.sin(x / (num_points / 2) * math.pi) * max_amp
            local wave_height = amplitude * amp_fac *
                math.sin(((x / (num_points / 2) * math.pi * 2) - offset) * freq * math.pi)

            -- Draw wavy points (back) and round edge (front)
            local a_x = math.cos(angle) * LIQUID_WIDTH + LIQUID_CENTER_X
            local a_y = math.sin(angle) * LIQUID_HEIGHT + LIQUID_CENTER_Y - wave_height
            surface:setPointAt(i, a_x, a_y)
        end
        surface:close()

        gfx.setColor(gfx.kColorBlack)
        gfx.fillPolygon(surface)
        gfx.pushContext()
            gfx.setColor(gfx.kColorWhite)
            gfx.setDitherPattern((1 - GAMEPLAY_STATE.potion_color), gfx.image.kDitherTypeBayer8x8)
            gfx.fillPolygon(surface)
        gfx.popContext()
        gfx.setColor(gfx.kColorWhite)
        gfx.setLineWidth(3)
        gfx.drawPolygon(surface)
    end
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
Phi = math.pi * (math.sqrt(5.) - 1.) -- Golden angle in radians
for a = 1, NUM_BUBBLES, 1 do
    local y = 1 - ((a - 1) / (NUM_BUBBLES - 1)) * 2
    Bubbles_amplitude[a] = math.sqrt(1 - y * y) * 0.8 + 0.2
    Bubbles_radians[a] = Phi * (a - 1) -- Golden angle increment
    Bubbles_tick_offset[a] = math.floor(Phi * (a - 1) * 50)
    Bubbles_types[a] = 0
end

local function draw_liquid_bubbles()
    gfx.pushContext()
    do
        local ellipse_height = LIQUID_HEIGHT - 5 -- Lil' bit less than the actual liquid height.
        local ellipse_bottom_width = LIQUID_WIDTH - 10 -- Lil' bit less than liquid

        local speed_fac = MapRange(GAMEPLAY_STATE.liquid_viscosity, 0.85, 0.95, 0.05, 0.02)
        local freq = MapRange(GAMEPLAY_STATE.liquid_viscosity, 0.85, 0.95, 0.4, 0.9)
        local offset = GAMEPLAY_STATE.liquid_offset * speed_fac * freq / 2

        for x = 1, NUM_BUBBLES, 1 do
            if not Bubbles_animation_playing[x] and GAMEPLAY_STATE.heat_amount > math.random() + 0.1 then
                Bubbles_animation_playing[x] = true
                Bubbles_flip[x] = math.random() > 0.5
                if math.random() > 0.9 then
                    Bubbles_types[x] = -1
                end
            end
        end
        for x = 1, NUM_BUBBLES, 1 do
            if not Bubbles_animation_playing[x] then goto continue end

            local bubble_rad = Bubbles_radians[x] + offset
            local bubble_amp = Bubbles_amplitude[x]

            local bot_offset = 0
            if math.sin(bubble_rad) < 0 then
                local max_amp = 15
                bot_offset = math.sin(bubble_rad) * max_amp * Clamp(math.abs(GAMEPLAY_STATE.liquid_momentum) / 20, 0, 1)
            end

            local b_x = bubble_amp * math.cos(bubble_rad) * ellipse_bottom_width + LIQUID_CENTER_X
            local b_y = bubble_amp * math.sin(bubble_rad) * ellipse_height + LIQUID_CENTER_Y - bot_offset

            local bubble_tab = TEXTURES.bubble_table
            local bub_off_x, bub_off_y = 5, 12

            -- Check if they are bubbles
            if Bubbles_types[x] < 0 then
                bubble_tab = TEXTURES.bubble_table2
                bub_off_x, bub_off_y = 12, 12
            end

            local anim_length = 0
            -- Check if they are ingredient drops
            if Bubbles_types[x] <= 0 then
                anim_length = bubble_tab:getLength()
                anim_tick = math.fmod(Bubbles_tick_offset[x] + GAMEPLAY_STATE.game_tick // 3, anim_length)
            else
                anim_length = 30
                anim_tick = STIR_FACTOR * (anim_length -1)
            end


            if Bubbles_types[x] > 0 then
                -- This is the spot for adding a factor. Might need to split the bubble sinking time from drop sprites.
                local sink = math.sin(GAMEPLAY_STATE.game_tick / (2 * math.pi) * 0.7 + Bubbles_tick_offset[x]) * 0.3 + (anim_tick / anim_length)
                local drop_sprite = INGREDIENT_TYPES[Bubbles_types[x]].drop
                local offset_y = drop_sprite.height * sink
                local mask = playdate.geometry.rect.new(0, 0, drop_sprite.width, drop_sprite.height - offset_y)
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

        local text = SPEECH_BUBBLE_TEXT

        -- Split the given text by '\n' into multiple lines.
        local text_lines = {}
        for line in string.gmatch(text, "[^\n]+") do
            table.insert(text_lines, line)
        end

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
    local flicker_freq = {0.0023, 0.3, 5.2}
    local flicker_strength = {0.01, 0.002, 0.004}
    local flicker = 0
    local tick = GAMEPLAY_STATE.game_tick + math.random()
    local time  = (tick - math.fmod(tick, 8)) / playdate.getFPS()
    for a = 1, #flicker_freq, 1 do
        flicker += math.sin(time * 2 * math.pi * flicker_freq[a]) * flicker_strength[a]
    end
    flicker *= (1 - GAMEPLAY_STATE.heat_amount ^ 2)
    
    local light_strength = (GAMEPLAY_STATE.heat_amount * 0.8 + 0.2 ) + flicker
    local glow_center_x = LIQUID_CENTER_X
    local glow_center_y = 240
    local glow_width = 200 + light_strength * 60
    local glow_height = 120 + light_strength * 40
    local glow_blend = math.max(0.25, light_strength) * 0.8

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
    local fmod = math.fmod

    gfx.pushContext()
        if GAMEPLAY_STATE.flame_amount > 0.8 then
            buildupflame_counter += 1
            if buildupflame_counter < 5 then
                TEXTURES.buildup_flame:draw(-1, 0)
            else
                TEXTURES.stir_flame_table:draw(-1, 0)
            end
        elseif GAMEPLAY_STATE.flame_amount > 0.5 then
            buildupflame_counter = buildupflame_counter * 0.5
            if buildupflame_counter > 2 then
                TEXTURES.stir_flame_table:draw(-1, 0)
            else
                TEXTURES.high_flame_table:draw(-1, 0)
                buildupflame_counter = 0
            end
        elseif GAMEPLAY_STATE.heat_amount > 0.4 then
            TEXTURES.medium_flame_table:draw(-1, 0)
        elseif GAMEPLAY_STATE.heat_amount > 0.2 then
            TEXTURES.low_flame_table:draw(-1, 0)
        elseif GAMEPLAY_STATE.heat_amount > 0.08 then
            TEXTURES.ember_table:draw(-1, 0)
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
        TEXTURES.b_prompt:drawImage(1, 362, 203)
    gfx.popContext()
end


local function draw_debug()
    -- Heat amount indication.
    local x = 10
    local y = 10
    local border = 3
    local width = 22
    local height = 150
    local meter = ( GAMEPLAY_STATE.heat_amount ) * (height - border * 2)
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

function Init_visuals()

    -- Anim loop data
    local ember_table, ember_framerate = gfxit.new("images/fx/ember"), 4
    local low_flame_table, low_flame_framerate = gfxit.new("images/fx/lowflame"), 4
    local medium_flame_table, medium_flame_framerate = gfxit.new("images/fx/mediumflame"), 4
    local high_flame_table, high_flame_framerate = gfxit.new("images/fx/highflame"), 4
    local stir_flame_table, stir_flame_framerate = gfxit.new("images/fx/stirredflame"), 3.33
    local love_correct_table, love__correct_framerate = gfxit.new("images/love_correct"), 8
    local doom_correct_table, doom_correct_framerate = gfxit.new("images/doom_correct"), 8
    local weed_correct_table, weed_correct_framerate = gfxit.new("images/weeds_correct"), 8


    -- Load image layers.
    TEXTURES.bg = gfxi.new("images/bg")
    TEXTURES.cauldron = gfxi.new("images/cauldron")
    TEXTURES.cauldron_front = gfxi.new("images/cauldron_front")
    TEXTURES.instructions_prompt = gfxi.new("images/instructions_prompt")
    TEXTURES.b_prompt = gfxit.new("images/animation-b")
    TEXTURES.dialog_bubble_oneline = gfxi.new("images/speech/speechbubble_oneline_wide")
    TEXTURES.dialog_bubble_twolines = gfxi.new("images/speech/speechbubble_twolines_extrawide")
    TEXTURES.instructions = gfxi.new("images/instructions")
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
    TEXTURES.rune_correct = {animloop.new(love__correct_framerate * frame_ms, love_correct_table, true),
                            animloop.new(doom_correct_framerate * frame_ms, doom_correct_table, true),
                            animloop.new(weed_correct_framerate * frame_ms, weed_correct_table, true)}
    -- Load fx
    TEXTURES.ember_table = animloop.new(ember_framerate * frame_ms, ember_table, true)
    TEXTURES.low_flame_table = animloop.new(low_flame_framerate * frame_ms, low_flame_table, true)
    TEXTURES.medium_flame_table = animloop.new(medium_flame_framerate * frame_ms, medium_flame_table, true)
    TEXTURES.high_flame_table = animloop.new(high_flame_framerate * frame_ms, high_flame_table, true)
    TEXTURES.stir_flame_table = animloop.new(stir_flame_framerate * frame_ms, stir_flame_table, true)
    TEXTURES.buildup_flame = gfxi.new("images/fx/buildupflame")
    TEXTURES.bubble_table = gfxit.new("images/fx/bubble")
    TEXTURES.bubble_table2 = gfxit.new("images/fx/bubble2")

    -- Starting table of active animations for runes
    rune_anim_table = {}
    local start_rune_count = {0, 0, 0}
    table.insert(rune_anim_table, {start_rune_count, animator.new(0, 1.0, 1.0), animator.new(0, 1.0, 1.0)})

    -- Load fonts
    FONTS.speech_font = gfx.font.new("fonts/froggotini17")


    -- Set the multiple things in their Z order of what overlaps what.

    Set_draw_pass(-40, draw_game_background)
    -- -5: shelved ingredients
    Set_draw_pass(-2, draw_bg_lighting)
    --Set_draw_pass(-1, draw_liquid_glow)
    Set_draw_pass(0, draw_cauldron)
    Set_draw_pass(2, draw_liquid_surface)
    Set_draw_pass(3, draw_stirring_stick_back) -- draw ladle when on farther side
    Set_draw_pass(4, draw_liquid_bubbles)
    -- 4: ingredient drops floating in the liquid
    -- 5: ingredient drop splash
    -- 5: ingredient slotted over cauldron
    Set_draw_pass(6, draw_parameter_diagram)
    Set_draw_pass(7, draw_stirring_stick_front) -- draw ladle when on front side
    Set_draw_pass(8, draw_cauldron_front)
    -- 10: frog
    -- depth 20+: UI
    Set_draw_pass(21, draw_ui_prompts)
    Set_draw_pass(23, draw_ingredient_place_hint)
    -- 24: grabbed ingredients
    Set_draw_pass(25, draw_ingredient_grab_cursor)
    Set_draw_pass(27, draw_dialog_bubble)
    -- depth 30+: overlayed modal instructions
    Set_draw_pass(30, draw_overlayed_instructions)
    Set_draw_pass(35, draw_overlayed_recipe)
    -- Development
    --Set_draw_pass(50, draw_debug)
    Set_draw_pass(50, draw_debug_fps)
    --Set_draw_pass(50, draw_test_dither_patterns)
end

Z_DEPTH = {
    frog = 10,
    ingredients = -5,
    indredient_drops = 4,
    ingredient_slotted_over_cauldron = 5,
    ingredient_drop_splash = 5,
    grabbed_ingredient = 24
}
