local gfx <const> = playdate.graphics
local gfxi <const> = playdate.graphics.image

RECIPE_TEXT = {}

function Recipe_to_steps(recipe)

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

function Recipe_steps_to_text(recipe_steps)
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

function Recipe_update_current()
    RECIPE_TEXT = Recipe_steps_to_text(Recipe_to_steps(CURRENT_RECIPE))
end

function Recipe_draw_success(y)
    -- draw full scrollable recipe on success

    local recipe_x = 50
    local recipe_y = y
    local text_x = 24
    local text_y = 40
    local line_height = 20
    local flip_table = {"flipX", "flipY", "flipXY"}

    -- figure out amount of insert pieces for the text
    local insert_height = TEXTURES.recipe_middle[1].height
    local number_of_lines = #RECIPE_TEXT
    local number_of_inserts = math.max(0, math.ceil(((number_of_lines * line_height) + text_y - TEXTURES.recipe_top.height ) / insert_height))
    if GAMEPLAY_STATE.showing_recipe then
        math.randomseed(10)
        gfx.setDitherPattern(0.6, gfxi.kDitherTypeBayer4x4)
        gfx.fillRect(0, 0, 400, 240)
        gfx.pushContext()
            TEXTURES.recipe_top:draw(recipe_x, recipe_y)
            for a = 1, number_of_inserts, 1 do
               TEXTURES.recipe_middle[math.random(3)]:draw(recipe_x, recipe_y + TEXTURES.recipe_top.height + (a-1) * insert_height, flip_table[math.random(3)])
            end
            TEXTURES.recipe_bottom:draw(recipe_x, recipe_y + number_of_inserts * insert_height + TEXTURES.recipe_top.height)
        gfx.popContext()

        gfx.pushContext()
            local y = recipe_y + text_y
            gfx.setFont(FONTS.speech_font)
            for a = 1, #RECIPE_TEXT, 1 do
                gfx.drawText(RECIPE_TEXT[a], recipe_x + text_x, y)
                y += line_height
            end
        gfx.popContext()
    end
end

function Recipe_draw_menu(recipe, x, y)
    -- draw scrollable top recipe in menu
end