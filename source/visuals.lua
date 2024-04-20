local gfx <const> = playdate.graphics
local gfxi <const> = playdate.graphics.image

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

local function draw_game_background( x, y, width, height )

    -- Draw full screen background.
    gfx.pushContext()
        TEXTURES.bg:draw(0, 0)
    gfx.popContext()

end


local function draw_hud()
    do
        gfx.pushContext()
        -- Flame ammount indication.
        local x = 60
        local y = 210
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRoundRect(x - 3, y - 3, 75, 22, 3)
        gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        gfx.setColor(gfx.kColorWhite)
        gfx.setFont(TEXTURES.font)
        gfx.drawText("flame " .. string.format("%02d", GAMEPLAY_STATE.flame_amount * 100), x, y)
        gfx.popContext()
    end
    do
        gfx.pushContext()
        -- Crank speed indication.
        local x = 10
        local y = 10
        local border = 3
        local width = 22
        local height = 150
        local meter = (STIR_METER / 100) * (height - border * 2)
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRoundRect(x, y, width, height, border)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRoundRect(x + border, y + height - meter - border, width - border * 2, meter, 3)
        gfx.popContext()
    end
end


local function draw_debug()
    gfx.pushContext()
        gfx.setColor(gfx.kColorBlack)
        gfx.drawCircleAtPoint(GYRO_X, GYRO_Y, 30)
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

    -- Set the multiple things in their Z order of what overlaps what.
    Set_draw_pass(-40, draw_game_background)
    Set_draw_pass(10, draw_hud)
    Set_draw_pass(20, draw_debug)
    --Set_draw_pass(20, draw_test_dither_patterns)
end
