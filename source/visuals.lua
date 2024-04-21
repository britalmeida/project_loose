local gfx <const> = playdate.graphics
local gfxi <const> = playdate.graphics.image
local vec2d <const> = playdate.geometry.vector2D

-- Image Passes
TEXTURES = {}

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

local function draw_symbols( x_min, y_min, width, height, position_params, value_params)
    params = position_params
    if params == nil then
        return
    end

    gfx.pushContext()
        gfx.setFont(TEXTURES.font_symbols)
        local glyph_size = 14
        local margin = 3

        local n = #params
        local x1 = x_min + width / 2
        local y1 = y_min + (1 - math.sqrt(params[1])) * height / 2
        for a = 0, n-1, 1 do
            local i = (a+1<n and a+1 or 0) + 1
            local phi = (a+1)/n * 2 * math.pi
            local r = math.sqrt(params[i])
            local x2 = x_min + ((math.sin(phi) * r) + 1) * width / 2
            local y2 = y_min + ((-math.cos(phi) * r) + 1) * height / 2

            local glyph_x = x1-glyph_size*0.5
            local glyph_y = y1-glyph_size*0.5

            gfx.pushContext()
                gfx.setDitherPattern(value_params[i], gfxi.kDitherTypeScreen)
                gfx.fillRoundRect(
                    glyph_x-margin, glyph_y-margin,
                    glyph_size+margin*2, glyph_size+margin*2, 4)
            gfx.popContext()

            local rune_strength = GAMEPLAY_STATE.rune_ratio[a+1]
            draw_soft_circle(x1, y1, 20*rune_strength, 4, 0.5, rune_strength, gfx.kColorWhite)

            gfx.pushContext()
                gfx.setImageDrawMode(gfx.kDrawModeInverted)
                gfx.drawText(tostring(a+1), glyph_x, glyph_y)
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
        local size = 100
        local x_center = 100
        local y_center = 80
        local width = size
        local height = size
        local x_min = x_center - width * 0.5
        local y_min = y_center - height * 0.5

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
        draw_poly_shape(x_min, y_min, width, height, params, 0.45, gfx.kColorWhite)
        -- Draw target potion mix
        draw_poly_shape(x_min, y_min, width, height, target_params, 1.00, gfx.kColorBlack)
        draw_symbols(x_min, y_min, width, height, par_lim, params)

    gfx.popContext()
end

local function draw_debug_color_viscosity()
    gfx.pushContext()

        gfx.setColor(playdate.graphics.kColorWhite)

        -- Color.
        gfx.pushContext()
            gfx.setDitherPattern(1 - TARGET_COCKTAIL.color, gfx.image.kDitherTypeBayer8x8)
            gfx.fillRect(200, 25, 20, 20)
        gfx.popContext()
        gfx.drawRect(200, 25, 20, 20)  -- Outline

        -- Viscosity.
        gfx.pushContext()
            gfx.setDitherPattern(1 - TARGET_COCKTAIL.viscosity, gfx.image.kDitherTypeBayer8x8)
            gfx.fillRect(200, 50, 20, 20)
        gfx.popContext()
        gfx.drawRect(200, 50, 20, 20) -- Outline

    gfx.popContext()
end

local function draw_stirring_stick()
    gfx.pushContext()
    do
        local t = STIR_POSITION
        local cauldron_center_x, cauldron_center_y = 105, 160
        local ellipse_top_width, ellipse_bottom_width = 100, 70
        local ellipse_height = 12
        local stick_height = 70

        local a_x = math.cos(t) * ellipse_top_width + cauldron_center_x
        local a_y = math.sin(t) * ellipse_height + cauldron_center_y - stick_height
        local b_x = math.cos(t) * ellipse_bottom_width + cauldron_center_x
        local b_y = math.sin(t) * ellipse_height + cauldron_center_y

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

        local cauldron_center_x, cauldron_center_y = 105, 160
        local cauldron_width, cauldron_height = 80, 15

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
            local a_x = math.cos(angle) * cauldron_width + cauldron_center_x
            local a_y = math.sin(angle) * cauldron_height + cauldron_center_y - wave_height
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

Bubbles = {}
Bubbles_rad = {}
NUM_BUBBLES = 8
for a = 1, NUM_BUBBLES, 1 do
     Bubbles[a] = math.random(90) / 100 + 0.1
     Bubbles_rad[a] = (math.random(100) / 100) * 2 * math.pi
end

local function draw_liquid_bubbles()
    gfx.pushContext()
    do
        -- TODO: probably make these global variables so we don't have to change this in multiple places
        local cauldron_center_x, cauldron_center_y = 105, 160
        local ellipse_bottom_width = 70
        local ellipse_height = 12

        local speed_fac = MapRange(GAMEPLAY_STATE.liquid_viscosity, 0.85, 0.95, 0.05, 0.02)
        local freq = MapRange(GAMEPLAY_STATE.liquid_viscosity, 0.85, 0.95, 0.4, 0.9)
        local offset = GAMEPLAY_STATE.liquid_offset * speed_fac * freq / 2

        for x = 1, NUM_BUBBLES, 1 do
            local bubble_rad = Bubbles_rad[x] + offset
            local bubble_amp = Bubbles[x]

            local bot_offset = 0
            if math.sin(bubble_rad) < 0 then
                local max_amp = 15
                bot_offset = math.sin(bubble_rad) * max_amp * Clamp(math.abs(GAMEPLAY_STATE.liquid_momentum) / 20, 0, 1)
            end

            local b_x = bubble_amp * math.cos(bubble_rad) * ellipse_bottom_width + cauldron_center_x
            local b_y = bubble_amp * math.sin(bubble_rad) * ellipse_height + cauldron_center_y - bot_offset

            gfx.setColor(gfx.kColorWhite)
            gfx.drawCircleAtPoint(b_x, b_y, 3)
        end
    end
    gfx.popContext()
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

local function draw_game_background( x, y, width, height )
    local sin = math.sin
    local fmod = math.fmod
    local x_pos = 0
    local y_pos = 0

    -- Screen shake
    --x_pos = sin( (fmod(GAMEPLAY_STATE.game_tick, 4) / 2) * math.pi) * GAMEPLAY_STATE.flame_amount * 5
    --x_pos += sin( (fmod(GAMEPLAY_STATE.game_tick, 8) / 4) * math.pi) * GAMEPLAY_STATE.flame_amount * 2

    --if GAMEPLAY_STATE.flame_amount > 0.5 then
    --    y_pos = sin( (fmod(GAMEPLAY_STATE.game_tick, 6) / 3) * math.pi) * 2
    --else
    --    y_pos = 0
    --end
    -- Draw full screen background.
    gfx.pushContext()
    do
        TEXTURES.bg:draw(x_pos, y_pos)

        -- Draw flame animation
        if GAMEPLAY_STATE.flame_amount > 0.7 then
            local table_size = TEXTURES.stir_flame_table:getLength()
            local anim_tick = fmod(GAMEPLAY_STATE.game_tick // 3, table_size)
            TEXTURES.stir_flame_table[anim_tick + 1]:draw(-27, 0)
        elseif GAMEPLAY_STATE.flame_amount > 0.4 then
            local table_size = TEXTURES.high_flame_table:getLength()
            local anim_tick = fmod(GAMEPLAY_STATE.game_tick // 3, table_size)
            TEXTURES.high_flame_table[anim_tick + 1]:draw(-15, 160)
        else
            local table_size = TEXTURES.low_flame_table:getLength()
            local anim_tick = fmod(GAMEPLAY_STATE.game_tick // 4, table_size)
            TEXTURES.low_flame_table[anim_tick + 1]:draw(-15, 160)
        end
    end
    gfx.popContext()
end


local function draw_hud()
    do
        gfx.pushContext()
        -- Flame ammount indication.
        local x = 10
        local y = 10
        local border = 3
        local width = 22
        local height = 150

        local meter = ( GAMEPLAY_STATE.flame_amount ) * (height - border * 2)
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRoundRect(x, y, width, height, border)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRoundRect(x + border, y + height - meter - border, width - border * 2, meter, 3)
        gfx.popContext()
    end
end


local function draw_debug()
    gfx.pushContext()
        gfx.setColor(gfx.kColorWhite)
        gfx.drawCircleAtPoint(GYRO_X, GYRO_Y, 30)
        playdate.drawFPS(200,0)
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
    TEXTURES.dialog_bubble = gfxi.new("images/dialog_bubble")

    -- Load cauldron flame textures
    local lowflame_a = gfxi.new("images/fire/lowflame_a")
    local lowflame_b = gfxi.new("images/fire/lowflame_b")

    TEXTURES.low_flame_table = gfx.imagetable.new(2)
    TEXTURES.low_flame_table:setImage(1, lowflame_a)
    TEXTURES.low_flame_table:setImage(2, lowflame_b)

    local highflame_a = gfxi.new("images/fire/highflame_a")
    local highflame_b = gfxi.new("images/fire/highflame_b")

    TEXTURES.high_flame_table = gfx.imagetable.new(2)
    TEXTURES.high_flame_table:setImage(1, highflame_a)
    TEXTURES.high_flame_table:setImage(2, highflame_b)

    local stir_flame_1 = gfxi.new("images/fire/stirredflame_1.png")
    local stir_flame_2 = gfxi.new("images/fire/stirredflame_2.png")
    local stir_flame_3 = gfxi.new("images/fire/stirredflame_3.png")

    TEXTURES.stir_flame_table = gfx.imagetable.new(3)
    TEXTURES.stir_flame_table:setImage(1, stir_flame_1)
    TEXTURES.stir_flame_table:setImage(2, stir_flame_2)
    TEXTURES.stir_flame_table:setImage(3, stir_flame_3)

    TEXTURES.font_symbols = gfx.font.new("fonts/symbols_outline")

    -- Set the multiple things in their Z order of what overlaps what.
    Set_draw_pass(-40, draw_game_background)
    -- depth 0: will be the cauldron? or the frog?
    Set_draw_pass(3, draw_liquid_surface)
    Set_draw_pass(4, draw_liquid_bubbles)
    Set_draw_pass(5, draw_parameter_diagram)
    Set_draw_pass(6, draw_stirring_stick)
    Set_draw_pass(7, draw_dialog_bubble)
    Set_draw_pass(8, draw_debug_color_viscosity)
    Set_draw_pass(10, draw_hud)
    Set_draw_pass(20, draw_debug)
    --Set_draw_pass(20, draw_test_dither_patterns)
end
