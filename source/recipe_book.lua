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

function Recipe_draw_success(recipe)
    -- draw full scrollable recipe on success
end

function Recipe_draw_menu(recipe, x, y)
    -- draw scrollable top recipe in menu
end