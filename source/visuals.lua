local gfx <const> = playdate.graphics
local gfxi <const> = playdate.graphics.image
local geo <const> = playdate.geometry
local vec2d <const> = playdate.geometry.vector2D

-- Image Passes
TEXTURES = {}

-- Constants
LIQUID_CENTER_X, LIQUID_CENTER_Y = 145, 147
LIQUID_WIDTH, LIQUID_HEIGHT = 65, 25
LIQUID_AABB = geo.rect.new(
    LIQUID_CENTER_X-LIQUID_WIDTH,
    LIQUID_CENTER_Y-LIQUID_HEIGHT*0.5,
    LIQUID_WIDTH*2, LIQUID_HEIGHT)
MAGIC_TRIANGLE_CENTER_X, MAGIC_TRIANGLE_CENTER_Y = 150, 70
MAGIC_TRIANGLE_SIZE = 100


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

local function draw_symbols( x_min, y_min, width, height, position_params, value_params)
    local params = position_params
    if params == nil then
        return
    end

    gfx.pushContext()
        gfx.setFont(TEXTURES.font_symbols)
        local margin = 3

        local n = #params
        local x1 = x_min + width / 2
        local y1 = y_min + (1 - math.sqrt(params[1])) * height / 2
        for a = 1, n, 1 do
            local glyph_width = TEXTURES.rune_images[a].width
            local glyph_height = TEXTURES.rune_images[a].height
            local i = (a<n and a or 0) + 1
            local phi = (a)/n * 2 * math.pi
            local r = math.sqrt(params[i])
            local x2 = x_min + ((math.sin(phi) * r) + 1) * width / 2
            local y2 = y_min + ((-math.cos(phi) * r) + 1) * height / 2

            local glyph_x = x1-glyph_width*0.5
            local glyph_y = y1-glyph_height*0.5

            gfx.pushContext()
                gfx.setDitherPattern(value_params[i], gfxi.kDitherTypeScreen)
                gfx.fillRoundRect(
                    glyph_x-margin, glyph_y-margin,
                    glyph_width+margin*2, glyph_height+margin*2, 4)
            gfx.popContext()

            local target = TARGET_COCKTAIL.rune_ratio[a]
            local difference_weight = math.max(target, 1-target)
            local rune_strength = math.min(math.sqrt(GAMEPLAY_STATE.heat_amount * 1.2), 1) * (1 - math.abs((GAMEPLAY_STATE.rune_ratio[a] - target) / difference_weight))
            draw_soft_circle(x1, y1, 20*rune_strength, 4, 0.5, rune_strength, gfx.kColorWhite)

            gfx.pushContext()
                --gfx.setImageDrawMode(gfx.kDrawModeInverted)
                TEXTURES.rune_images[a]:draw(glyph_x, glyph_y)
                gfx.setColor(gfx.kColorBlack)
                gfx.setDitherPattern(1-(math.max(0.8-GAMEPLAY_STATE.heat_amount, 0) * 0.8), gfxi.kDitherTypeBayer4x4)
                gfx.fillRoundRect(
                    glyph_x-margin, glyph_y-margin,
                    glyph_width+margin*2, glyph_height+margin*2, 4)
                --gfx.drawText(tostring(a), glyph_x, glyph_y)
            gfx.popContext()

            x1 = x2
            y1 = y2
        end

    gfx.popContext()
end

local function draw_poly_shape( x_min, y_min, width, height, params, alpha, color)
    if params == nil then
        return
    end
    gfx.pushContext()
        gfx.setColor(color)
        local n = #params
        local x1 = x_min + width / 2
        local y1 = y_min + (1 - math.sqrt(params[1])) * height / 2
        for a = 0, n-1, 1 do
            local phi = (a+1)/n * 2 * math.pi
            local r = math.sqrt(params[(a+1<n and a+1 or 0) + 1])
            local x2 = x_min + ((math.sin(phi) * r) + 1) * width / 2
            local y2 = y_min + ((-math.cos(phi) * r) + 1) * height / 2
            gfx.pushContext()
                gfx.setDitherPattern(alpha, gfxi.kDitherTypeBayer4x4)
                gfx.fillTriangle(x1, y1, x2, y2, x_min + width / 2, y_min + height / 2)
            gfx.popContext()
            gfx.drawLine( x1, y1, x2, y2)
            x1 = x2
            y1 = y2
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

    local target_params = TARGET_COCKTAIL.rune_ratio

    gfx.pushContext()
        local size = MAGIC_TRIANGLE_SIZE
        local width = MAGIC_TRIANGLE_SIZE
        local height = MAGIC_TRIANGLE_SIZE
        local x_min = MAGIC_TRIANGLE_CENTER_X - width * 0.5
        local y_min = MAGIC_TRIANGLE_CENTER_Y - height * 0.5

        -- Draw outline polygon
        local par_lim = {}
        for a = 1, #params, 1 do
            par_lim[a] = 1
        end

        gfx.pushContext()
            gfx.setColor(gfx.kColorBlack)
            gfx.setDitherPattern(0, gfxi.kDitherTypeBayer4x4)
            --gfx.fillRect(0,0,400,240)
        gfx.popContext()

        -- Draw background gradient
        --draw_soft_circle(x_center, y_center, size * 0.5, 4, gfx.kColorWhite)


        draw_poly_shape(x_min, y_min, width, height, par_lim, 0, gfx.kColorBlack)
        -- Draw current potion mix
        --draw_poly_shape(x_min, y_min, width, height, params, 0.45, gfx.kColorWhite)
        -- Draw target potion mix
        --draw_poly_shape(x_min, y_min, width, height, target_params, 1.00, gfx.kColorWhite)
        draw_symbols(x_min, y_min, width, height, par_lim, params)

    gfx.popContext()
end


local function draw_stirring_stick()
    gfx.pushContext()
    do
        local t = STIR_POSITION

        -- Calculate 2 elipses:
        -- 'a': for the path of the top point of the stick,
        -- 'b': for the bottom point
        local stick_height, stick_tilt = 60, 45
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
        gfx.setColor(gfx.kColorBlack)
        gfx.setLineWidth(6)
        gfx.drawLine(a_x, a_y, b_x, b_y)
        gfx.setColor(gfx.kColorWhite)
        gfx.setLineWidth(3)
        gfx.drawLine(a_x - math.cos(t) * 2, a_y + 2, b_x, b_y)
    end
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
NUM_BUBBLES = 10
Phi = math.pi * (math.sqrt(5.) - 1.) -- Golden angle in radians
for a = 1, NUM_BUBBLES, 1 do
    local y = 1 - ((a - 1) / (NUM_BUBBLES - 1)) * 2
    Bubbles_amplitude[a] = math.sqrt(1 - y * y) * 0.8 + 0.2
    Bubbles_radians[a] = Phi * (a - 1) -- Golden angle increment
    Bubbles_tick_offset[a] = math.floor(Phi * (a - 1) * 50)
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

            local table_size = TEXTURES.bubble_table:getLength()
            local anim_tick = math.fmod(Bubbles_tick_offset[x] + GAMEPLAY_STATE.game_tick // 3, table_size)

            if Bubbles_flip[x] then
                TEXTURES.bubble_table[anim_tick + 1]:draw(b_x - 5, b_y - 12, "flipX")
            else
                TEXTURES.bubble_table[anim_tick + 1]:draw(b_x - 5, b_y - 12)
            end

            if (anim_tick + 1) == table_size then
               Bubbles_animation_playing[x] = false
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


local function draw_dialog_bubble()
    local text = SHOWN_STRING

    if text == "" then
        return
    end

    -- local text_lines = {"Just blow air onto", "the bottom of the cauldron"}
    local text_lines = {}
    for line in string.gmatch(text, "[^\n]+") do
        table.insert(text_lines, line)
    end

    -- Bounding box of the dialog bubble, within which it is safe to place text.
    local x_min = 140
    local y_min = 60
    local width = 210
    local height = 65

    -- Vertical advance of the line, in pixels.
    local line_height = 18

    local y_center =  y_min + height / 2
    local current_line_y = y_center - line_height * #text_lines / 2

    gfx.pushContext()
    do
        -- The buggle graphics itself.
        TEXTURES.dialog_bubble:draw(0, 0)

        -- Debug drawing of the safe area bounds.
        -- gfx.drawRect(x_min, y_min, width, height)

        -- Draw lines of the text.
        for i = 1, #text_lines, 1 do
            gfx.drawTextAligned(text_lines[i], x_min + width / 2, current_line_y, kTextAlignment.center)
            current_line_y += line_height
        end
    end
    gfx.popContext()
end

local function draw_bg_lighting()
    local light_strength = GAMEPLAY_STATE.heat_amount * 0.8 + 0.2
    gfx.pushContext()
        draw_soft_ellipse(LIQUID_CENTER_X, 240, 200 + light_strength * 60, 120 + light_strength * 40, 10, math.max(0.25, light_strength) * 0.8, light_strength, gfx.kColorWhite)
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
        TEXTURES.cauldron:draw(0, 0)
    gfx.popContext()

    -- Draw flame animation
    local fmod = math.fmod
    gfx.pushContext()
        if GAMEPLAY_STATE.flame_amount > 0.8 then
            local table_size = TEXTURES.stir_flame_table:getLength()
            local anim_tick = fmod(GAMEPLAY_STATE.game_tick // 3, table_size)
            TEXTURES.stir_flame_table[anim_tick + 1]:draw(0, 0)
        elseif GAMEPLAY_STATE.flame_amount > 0.6 then
            local table_size = TEXTURES.high_flame_table:getLength()
            local anim_tick = fmod(GAMEPLAY_STATE.game_tick // 3, table_size)
            TEXTURES.high_flame_table[anim_tick + 1]:draw(22, 160)
        elseif GAMEPLAY_STATE.flame_amount > 0.3 then
            local table_size = TEXTURES.high_flame_table:getLength()
            local anim_tick = fmod(GAMEPLAY_STATE.game_tick // 3, table_size)
            TEXTURES.medium_flame_table[anim_tick + 1]:draw(22, 160)
        else
            local table_size = TEXTURES.low_flame_table:getLength()
            local anim_tick = fmod(GAMEPLAY_STATE.game_tick // 4, table_size)
            TEXTURES.low_flame_table[anim_tick + 1]:draw(22, 160)
        end
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

        -- Draw FPS
        playdate.drawFPS(200,0)
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

    -- Load image layers.
    TEXTURES.bg = gfxi.new("images/bg")
    TEXTURES.cauldron = gfxi.new("images/cauldron")
    TEXTURES.dialog_bubble = gfxi.new("images/dialog_bubble")
    TEXTURES.instructions = gfxi.new("images/instructions")

    TEXTURES.rune_images = {gfxi.new("images/passion"), gfxi.new("images/doom"), gfxi.new("images/weeds")}

    -- Load cauldron flame textures
    TEXTURES.low_flame_table = gfx.imagetable.new("images/fire/lowflame")
    TEXTURES.medium_flame_table = gfx.imagetable.new("images/fire/mediumflame")
    TEXTURES.high_flame_table = gfx.imagetable.new("images/fire/highflame")
    TEXTURES.stir_flame_table = gfx.imagetable.new("images/fire/stirredflame")

    TEXTURES.bubble_table = gfx.imagetable.new("images/bubbles/bubble")

    TEXTURES.font_symbols = gfx.font.new("fonts/symbols_outline")

    TEXTURES.cursor = gfxi.new("images/open_hand")
    TEXTURES.cursor_hold = gfxi.new("images/closed_hand")

    TEXTURES.place_hint = gfxi.new("images/empty_circle")

    -- Set the multiple things in their Z order of what overlaps what.
    Set_draw_pass(-40, draw_game_background)
    -- -5: shelved ingredients
    Set_draw_pass(-1, draw_bg_lighting)
    Set_draw_pass(0, draw_cauldron)
    Set_draw_pass(3, draw_liquid_surface)
    Set_draw_pass(4, draw_liquid_bubbles)
    Set_draw_pass(5, draw_parameter_diagram)
    Set_draw_pass(6, draw_stirring_stick)
    -- 10: frog
    Set_draw_pass(11, draw_ingredient_place_hint)
    -- depth 20+: UI
    -- 22: grabbed ingredients
    Set_draw_pass(22, draw_ingredient_grab_cursor)
    Set_draw_pass(25, draw_dialog_bubble)
    -- depth 30+: overlayed modal instructions
    Set_draw_pass(30, draw_overlayed_instructions)
    -- Development
    --Set_draw_pass(20, draw_debug)
    --Set_draw_pass(20, draw_test_dither_patterns)
end

Z_DEPTH = { frog=10, ingredients=-5, grabbed_ingredient = 21 }
