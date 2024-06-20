local gfx <const> = playdate.graphics
local gfxi <const> = playdate.graphics.image

RECIPE_TEXT = {}
RECIPE_MAX_HEIGHT = 0


-- Convert a list of ingredient drop types to a counted list of consecutive drops.
-- e.g.: { 1, 1, 1, 4, 1, 1 } -> { {1, 3}, {4, 1}, {1, 2} }
function Recipe_to_steps(recipe)
    -- Early out when there's no added ingredients (recipe table is empty).
    if next(recipe) == nil then
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


-- Generate recipe text from the list of steps.
function Recipe_steps_to_text_success(recipe_steps)

    local text_lines = {}

    for step = 1, #recipe_steps, 1 do
        local line = "" .. tostring(step) .. ". "
        local step_type = recipe_steps[step][1]
        if step_type > 0 then
            if recipe_steps[step][2] == 1 then
                line = line .. "Add a"
            else
                line = line .. "Add " .. recipe_steps[step][2]
            end
            if INGREDIENT_TYPES[step_type].drop_name == "salt" and recipe_steps[step][2] > 1 then
                line = line .. " pinches of"
            elseif INGREDIENT_TYPES[step_type].drop_name == "salt" and recipe_steps[step][2] == 1 then
                line = line .. " pinch of"
            end
            line = line .. " " .. INGREDIENT_TYPES[step_type].drop_name
            if recipe_steps[step][2] > 1 and INGREDIENT_TYPES[step_type].drop_name ~= "salt" then
                line = line .. "s"
            end
        else
            if recipe_steps[step][2] >= 12 then
                line = line .. "Stir forever . . ."
            elseif recipe_steps[step][2] >= 10 then
                line = line .. "Stir for a while"
            elseif recipe_steps[step][2] >= 8 then
                line = line .. "Stir it a lot"
            elseif recipe_steps[step][2] >= 5 then
                line = line .. "Stir it in"
            elseif recipe_steps[step][2] < 5 then
                line = line .. "Stir a bit"
            end
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
        line = ""
        if step_type > 0 then
            line = line .. recipe_steps[step][2]
            if INGREDIENT_TYPES[step_type].drop_name == "salt" and recipe_steps[step][2] > 1 then
                line = line .. " pinches of "
            elseif INGREDIENT_TYPES[step_type].drop_name == "salt" and recipe_steps[step][2] == 1 then
                line = line .. " pinch of "
            end
            line = line .. " " .. INGREDIENT_TYPES[step_type].drop_name
            if recipe_steps[step][2] > 1 and INGREDIENT_TYPES[step_type].drop_name ~= "salt" then
                line = line .. "s"
            end
        else
            if recipe_steps[step][2] >= 12 then
                line = line .. "Stir forever . . ."
            elseif recipe_steps[step][2] >= 10 then
                line = line .. "Stir for a while"
            elseif recipe_steps[step][2] >= 8 then
                line = line .. "Stir it a lot"
            elseif recipe_steps[step][2] >= 5 then
                line = line .. "Stir it in"
            elseif recipe_steps[step][2] < 5 then
                line = line .. "Stir a bit"
            end
        end
        text_lines[#text_lines+1] = line
    end
    return text_lines
end

function Recipe_update_current()
    RECIPE_TEXT = Recipe_steps_to_text_success(Recipe_to_steps(CURRENT_RECIPE))
    RECIPE_TEXT_SMALL = (Recipe_to_steps(CURRENT_RECIPE))
    -- The steps where the frog speaks up and gives a hint (20th step and then ever 15 steps)
    RECIPE_STRUGGLE_STEPS = #RECIPE_TEXT_SMALL >= 20 and math.fmod(#RECIPE_TEXT_SMALL - 20, 15) == 0
end

function Recipe_draw_success(y, recipe_steps_text)
    -- draw full scrollable recipe on success

    -- Scroll window: which part of the recipe is in view. (window relative to the recipe)
    -- y can be negative: it's where the recipe starts relative to the playdate viewport.
    local scroll_offset <const> = -y
    local scroll_window_end <const> = scroll_offset + 240

    local recipe_x <const> = 40
    local text_x <const> = 24
    local text_y <const> = 180
    local line_height <const> = 23
    local extra_lines <const> = 4
    local flip_table <const> = {"flipX", "flipY", "flipXY"}

    local num_steps <const> = #recipe_steps_text
    local number_of_lines <const> = num_steps + extra_lines

    local header_img <const> = COCKTAILS[TARGET_COCKTAIL.type_idx].recipe_img

    -- figure out amount of insert pieces for the text
    local insert_height <const> = TEXTURES.recipe_middle[1].height
    local number_of_inserts <const> = math.ceil(((number_of_lines * line_height) + text_y - TEXTURES.recipe_top.height ) / insert_height)

    -- FIXME: this makes the game not random anymore. The inserts randomness should instead be picked
    -- on something static like the cocktail or number of steps.
    math.randomseed(10)

    local y_paper_top <const> = 0 -- margin from the recipe to the top of the screen.
    local y_first_insert <const> = y_paper_top + TEXTURES.recipe_top.height
    local y_recipe_step_start <const> = line_height * 2.2
    local y_header_img <const> = 0
    local y_win_sticker <const> = 124
    local y_first_text <const> = text_y
    local y_paper_bottom <const> = y_first_text + y_recipe_step_start + (line_height * (num_steps + 1.65))

    -- Draw a dark dither background.
    gfx.pushContext()
        gfx.setDitherPattern(0.6, gfxi.kDitherTypeBayer4x4)
        gfx.fillRect(0, 0, 400, 240)
        -- Note: would it help perf to draw the bg only where it wouldn't be occluded?
        -- local recipe_x2 = recipe_x + header_img.width
        -- gfx.fillRect(0, 0, recipe_x+10, 240)
        -- gfx.fillRect(recipe_x2-10, 0, 400-recipe_x2+10, 240)
    gfx.popContext()

    -- Draw recipe paper background.
    gfx.pushContext()
        if scroll_offset < y_first_insert then
            TEXTURES.recipe_top:draw(recipe_x, y + y_paper_top)
        end
        for a = 1, number_of_inserts, 1 do
            local y_paper_insert <const> = y_first_insert + (a-1) * insert_height
            if y_paper_insert < scroll_window_end and y_paper_insert + insert_height > scroll_offset  then
                TEXTURES.recipe_middle[math.random(3)]:draw(recipe_x, y + y_paper_insert, flip_table[math.random(3)])
            end
        end
        if y_paper_bottom < scroll_window_end then
            TEXTURES.recipe_bottom:draw(recipe_x, y + y_paper_bottom)
        end
    gfx.popContext()

    -- Draw recipe content
    gfx.pushContext()

        if scroll_offset < y_first_text then
            header_img:draw(recipe_x-40, y + y_header_img)
        end

        gfx.setFont(FONTS.speech_font)
        gfx.drawTextAligned(win_text, recipe_x + 66, y + y_win_sticker, kTextAlignment.center)

        y = y + y_first_text
        gfx.drawText("So the recipe goes\nlike this?", recipe_x + text_x, y)

        y += line_height * 2.2
        for a = 1, #recipe_steps_text, 1 do
            if y + line_height > 0 then
                gfx.drawText(recipe_steps_text[a], recipe_x + text_x, y)
            end
            y += line_height
            if y > 240 then
                break
            end
        end

        -- Show "rating" text.
        y += line_height
        if y > 0 and y < 240 then
            if num_steps > TARGET_COCKTAIL.step_ratings[3] then
                gfx.drawText("Yep . . . that was " .. tostring(num_steps) .. " steps.", recipe_x + text_x, y)
            elseif num_steps > TARGET_COCKTAIL.step_ratings[2] then
                gfx.drawText("Well done. Just " .. tostring(num_steps) .. " steps.", recipe_x + text_x, y)
            elseif num_steps > TARGET_COCKTAIL.step_ratings[1] then
                gfx.drawText("Fantastic! In only " .. tostring(num_steps) .. " steps!", recipe_x + text_x, y)
            else
                gfx.drawText("No way to beat " .. tostring(num_steps) .. " steps!!!", recipe_x + text_x, y)
            end
        end

    gfx.popContext()
end


function Recipe_draw_menu(x, y, recipe_text, step_types)
    -- draw scrollable top recipe in menu
    local text_x = 16
    local text_y = 54
    local line_height = 23
    local extra_lines = 4

    -- figure out number of middle inserts
    local insert_height = TEXTURES.recipe_small_middle.height
    local top_height = TEXTURES.recipe_small_top.height
    local number_of_lines = #recipe_text + extra_lines
    local number_of_inserts = math.max(0, math.ceil(((number_of_lines * line_height) + text_y - top_height ) / insert_height))
    RECIPE_MAX_HEIGHT = top_height + number_of_inserts * insert_height + TEXTURES.recipe_small_bottom.height
    local selected_recipe = COCKTAILS[MENU_STATE.focused_option+1]

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

        if #recipe_text > selected_recipe.step_ratings[3] then
            gfx.drawText("Ok . . .\nIn " .. tostring(#recipe_text) .. " steps:", x + text_x, y)
        elseif #recipe_text > selected_recipe.step_ratings[2] then
            gfx.drawText("Well done.\nIn " .. tostring(#recipe_text) .. " steps:", x + text_x, y)
        elseif #recipe_text > selected_recipe.step_ratings[1] then
            gfx.drawText("Fantastic!\nIn only " .. tostring(#recipe_text) .. " steps:", x + text_x, y)
        else
            gfx.drawText("Mastered!!!\nIn only " .. tostring(#recipe_text) .. " steps:", x + text_x, y)
        end

        for a = 1, #recipe_text, 1 do
            gfx.drawText(recipe_text[a], x + text_x + 8, y + 46)
            y += line_height
        end
    gfx.popContext()
end
