local gfx <const> = playdate.graphics
local gfxi <const> = playdate.graphics.image

RECIPE_TEXT = {}
RECIPE_MAX_HEIGHT = 0

function Recipe_to_steps(recipe)
    if recipe == nil then
        return {}
    elseif next(recipe) == nil then
        return {}
    end

    local current_ingredient = recipe[1]
    local ingredient_stack = 0
    local recipe_steps = {}

    for a = 1, #recipe, 1 do
        if recipe[a] == current_ingredient then
            ingredient_stack += 1
        else
            recipe_steps[#recipe_steps+1] = {current_ingredient, ingredient_stack}
            ingredient_stack = 1
            current_ingredient = recipe[a]
        end
    end
    recipe_steps[#recipe_steps+1] = {current_ingredient, ingredient_stack}
    return recipe_steps
end

function Recipe_steps_to_text_success(recipe_steps)
    if recipe_steps == nil then
        return {}
    elseif next(recipe_steps) == nil then
        return {}
    end
    local text_lines = {}
    for step = 1, #recipe_steps, 1 do
        local step_type = recipe_steps[step][1]
        local line = ""
        line = line .. tostring(step) .. ". " 
        if step_type > 0 then
            line = line .. "Add " .. recipe_steps[step][2]
            line = line .. " " .. INGREDIENT_TYPES[step_type].drop_name
        else
            line = line .. "Stir "
            if step_type == -1 then
                line = line .. "light "
            else
                line = line .. "dark "
            end
            line = line .. recipe_steps[step][2] .. " time"
        end
        if recipe_steps[step][2] > 1 then
            line = line .. "s"
        end
        text_lines[#text_lines+1] = line
    end
    return text_lines
end

function Recipe_steps_to_text_menu(recipe_steps)
    if recipe_steps == nil then
        return {}
    elseif next(recipe_steps) == nil then
        return {}
    end
    local text_lines = {}
    for step = 1, #recipe_steps, 1 do
        local test = recipe_steps[step]
        local step_type = recipe_steps[step][1]
        local line = ""
        line = line .. tostring(step) .. ". " 
        if step_type > 0 then
            line = line .. "Add " .. recipe_steps[step][2]
            line = line .. " " .. INGREDIENT_TYPES[step_type].drop_name
            if recipe_steps[step][2] > 1 then
                line = line .. "s"
            end
        else
            line = line .. "Stir "
            if step_type == -1 then
                line = line .. "light "
            else
                line = line .. "dark "
            end
            line = line .. recipe_steps[step][2] .. "x"
        end
        text_lines[#text_lines+1] = line
    end
    return text_lines
end

function Recipe_update_current()
    RECIPE_TEXT = Recipe_steps_to_text_success(Recipe_to_steps(CURRENT_RECIPE))
    RECIPE_TEXT_SMALL = (Recipe_to_steps(CURRENT_RECIPE))
end

function Recipe_draw_success(y)
    -- draw full scrollable recipe on success

    local recipe_x = 40
    local recipe_y = y
    local text_x = 24
    local text_y = 180
    local line_height = 20
    local extra_lines = 3
    local flip_table = {"flipX", "flipY", "flipXY"}

    local header_img = COCKTAILS[TARGET_COCKTAIL.type_idx].recipe_img

    -- figure out amount of insert pieces for the text
    local insert_height = TEXTURES.recipe_middle[1].height
    local number_of_lines = #RECIPE_TEXT + extra_lines
    local number_of_inserts = math.max(0, math.ceil(((number_of_lines * line_height) + text_y - TEXTURES.recipe_top.height ) / insert_height))
    math.randomseed(10)
    gfx.setDitherPattern(0.6, gfxi.kDitherTypeBayer4x4)
    gfx.fillRect(0, 0, 400, 240)

    -- Draw recipe background
    gfx.pushContext()
        TEXTURES.recipe_top:draw(recipe_x, recipe_y)
        for a = 1, number_of_inserts, 1 do
            TEXTURES.recipe_middle[math.random(3)]:draw(recipe_x, recipe_y + TEXTURES.recipe_top.height + (a-1) * insert_height, flip_table[math.random(3)])
        end
        TEXTURES.recipe_bottom:draw(recipe_x, recipe_y + number_of_inserts * insert_height + TEXTURES.recipe_top.height)
    gfx.popContext()

    -- Draw recipe content
    gfx.pushContext()
        header_img:draw(recipe_x-40, recipe_y)
        local y = recipe_y + text_y
        gfx.setFont(FONTS.speech_font)
        gfx.drawTextAligned(win_text, recipe_x + 66, recipe_y + 118, kTextAlignment.center)
        gfx.drawText("Just follow these steps:", recipe_x + text_x, y)
        y += line_height * 1.5
        for a = 1, #RECIPE_TEXT, 1 do
            gfx.drawText(RECIPE_TEXT[a], recipe_x + text_x, y)
            y += line_height
        end
        y += line_height
        if #RECIPE_TEXT > 1 then
            gfx.drawText("Easy! Just " .. tostring(#RECIPE_TEXT) .. " steps . . .", recipe_x + text_x, y)
        else
            gfx.drawText("Easy! Just " .. tostring(#RECIPE_TEXT) .. " step . . .", recipe_x + text_x, y)
        end
    gfx.popContext()
end

function Recipe_draw_menu(x, y, recipe_text, step_types)
    -- draw scrollable top recipe in menu
    local text_x = 12
    local text_y = 50
    local line_height = 20
    local extra_lines = 3

    -- figure out number of middle inserts
    local insert_height = TEXTURES.recipe_small_middle.height
    local top_height = TEXTURES.recipe_small_top.height
    local number_of_lines = #recipe_text + extra_lines
    local number_of_inserts = math.max(0, math.ceil(((number_of_lines * line_height) + text_y - top_height ) / insert_height))
    RECIPE_MAX_HEIGHT = top_height + number_of_inserts * insert_height + TEXTURES.recipe_small_bottom.height

    -- draw recipe background
    gfx.pushContext()
        TEXTURES.recipe_small_top:draw(x, y)
        for a = 1, number_of_inserts, 1 do
            TEXTURES.recipe_small_middle:draw(x, y + top_height + (a-1) * insert_height)
        end
        TEXTURES.recipe_small_bottom:draw(x, y + top_height + number_of_inserts * insert_height)
    gfx.popContext()

    -- draw recipe content
    gfx.pushContext()
        local y = y + text_y
        gfx.setFont(FONTS.speech_font)

        gfx.drawText("Just " .. tostring(#recipe_text) .. " steps!", x + text_x, y)

        for a = 1, #recipe_text, 1 do
            gfx.drawText(recipe_text[a], x + text_x, y + 20)
            y += line_height
        end
    gfx.popContext()
end