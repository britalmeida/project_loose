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
function Recipe_steps_to_text(recipe_steps, is_win_recipe)

    local text_lines = {}
    -- Pre-size the array to the necessary number of text line steps to avoid resizes.
    table.create(#recipe_steps, 0)

    -- Construct a text line for each recipe step. e.g.:
    -- "1. Add 3 peppermints" or "- 3 peppermints"
    -- The style depends on the type of recipe screen
    for i = 1, #recipe_steps, 1 do
        local line = ""
        if is_win_recipe then
            -- Line starts with step number.
            line = tostring(i) .. ". "
        else
            -- Line starts with a dash
            line = "- "
        end

        local step_type = recipe_steps[i][1]
        local quantity = recipe_steps[i][2]
        if step_type > 0 then
            -- Step type: added an ingredient.
            local ingredient_name = INGREDIENT_TYPES[step_type].drop_name

            if is_win_recipe and quantity == 1 then
                line = line .. "Add a "
            elseif is_win_recipe and quantity > 1 then
                line = line .. "Add " .. quantity .. " "
            elseif not is_win_recipe then
                line = line .. quantity .. " "
            end
            if ingredient_name == "salt" then
                if quantity > 1 then
                    line = line .. "pinches"
                else
                    line = line .. "pinch"
                end
                line = line .. " of " .. ingredient_name
            elseif ingredient_name == "perfume" and is_win_recipe then
                if quantity > 1 then
                    line = line .. "drops"
                else
                    line = line .. "drop"
                end
                line = line .. " of " .. ingredient_name
            elseif ingredient_name == "perfume" and not is_win_recipe then
                line = line .. ingredient_name .. " drop"
                if quantity > 1 then
                    line = line .. "s"
                end
            else
                line = line .. ingredient_name
                if quantity > 1 then
                    line = line .. "s"
                end
            end
        else
            -- Step type: stirred.
            if quantity >= 12 then
                line = line .. "Stir forever ..."
            elseif quantity >= 10 then
                line = line .. "Stir for a while"
            elseif quantity >= 8 then
                line = line .. "Stir it a lot"
            elseif quantity >= 5 then
                line = line .. "Stir it in"
            else
                line = line .. "Stir just a bit"
            end
        end

        text_lines[#text_lines+1] = line
    end

    return text_lines
end



function Recipe_update_current()
    RECIPE_TEXT = Recipe_steps_to_text(Recipe_to_steps(CURRENT_RECIPE), true)
    RECIPE_TEXT_SMALL = (Recipe_to_steps(CURRENT_RECIPE))
    -- The steps where the frog speaks up and gives a hint (20th step and then ever 15 steps)
    RECIPE_STRUGGLE_STEPS = #RECIPE_TEXT_SMALL >= 20 and math.fmod(#RECIPE_TEXT_SMALL - 20, 15) == 0
end

function Recipe_draw_success(y, recipe_steps_text)

    local num_steps <const> = #recipe_steps_text
    if num_steps > TARGET_COCKTAIL.step_ratings[3] then
        WIN_TEXT_2 = "Yep ... that was " .. tostring(num_steps) .. " steps."
    elseif num_steps > TARGET_COCKTAIL.step_ratings[2] then
        WIN_TEXT_2 = "Well done. Just " .. tostring(num_steps) .. " steps."
    elseif num_steps > TARGET_COCKTAIL.step_ratings[1] then
        WIN_TEXT_2 = "Fantastic! In only " .. tostring(num_steps) .. " steps!"
    else
        WIN_TEXT_2 = "No way to beat " .. tostring(num_steps) .. " steps!!!"
    end

    -- Draw full scrollable recipe on game ended.

    -- Notes: the recipe top texture fits all of the header parts.
    -- The variable length steps go in paper inserts, as many as needed.
    -- At a fixed offset from the last step, starts the footer background on top of the remainder of the last insert.
    -- All the footer bits fit on the footer texture.

    -- The recipe layout is in its own coordinates: 0 is the top left-corner of the paper,
    -- no matter where it is placed on screen and if scrolled out of view.
    -- The draw code uses scroll_offset as the origin.
    local scroll_offset <const> = y -- 0 or negative. It's where the recipe starts offscreen.
    local visible_top_y <const> = -y -- Part of the recipe which is shown, in recipe coordinates. For clipping.
    local visible_bottom_y <const> = visible_top_y + 240

    local header_img <const> = COCKTAILS[TARGET_COCKTAIL.type_idx].recipe_img
    local num_steps <const> = #recipe_steps_text

    local recipe_x <const> = 40
    local text_x <const> = recipe_x + 24
    local line_height <const> = 23
    local insert_height <const> = 30 -- height of midsection textures.
    local y_first_insert <const> = TEXTURES.recipe.top.height
    local y_first_step <const> = y_first_insert + line_height
    local y_paper_bottom <const> = y_first_step + (line_height * num_steps) + line_height * 0.5
    local num_inserts <const> = math.ceil( (y_paper_bottom - y_first_insert) / insert_height )

    -- Draw a dark dither background.
    gfx.pushContext()
        gfx.setDitherPattern(0.6, gfxi.kDitherTypeBayer4x4)
        gfx.fillRect(0, 0, 400, 240)
    gfx.popContext()

    gfx.pushContext()
        gfx.setFont(FONTS.speech_font)

        -- Draw header.
        if visible_top_y < y_first_insert then
            -- Paper background.
            TEXTURES.recipe.top:draw(recipe_x, scroll_offset)
            -- Cocktail image.
            header_img:draw(recipe_x - 40, scroll_offset)
            -- Sticker: "Recipe Done" / "Recipe Improved".
            gfx.drawTextAligned(WIN_TEXT, recipe_x + 66, scroll_offset + 124, kTextAlignment.center)
            -- Starting the recipe.
            gfx.drawText("So the recipe goes\nlike this?", text_x, scroll_offset + 180)
        end

        -- Determine the range of paper mid sections and recipe steps that are visible in the scroll window.
        local first_insert_to_draw <const> = ( math.max(0, visible_top_y - y_first_insert) // insert_height ) + 1 -- +1 for Lua arrays
        local last_insert_to_draw <const> = math.min(num_inserts,
                                             ( math.max(0, visible_bottom_y - y_first_insert) // insert_height ) + 1 )
        local first_step_to_draw <const> =   ( math.max(0, visible_top_y - y_first_step) // line_height ) + 1
        local last_step_to_draw <const> = math.min(num_steps,
                                             ( math.max(0, visible_bottom_y - y_first_step) // line_height ) + 1 )

        -- Draw recipe steps paper background.
        for a = first_insert_to_draw, last_insert_to_draw, 1 do
            local y_paper_insert <const> = y_first_insert + (a-1) * insert_height
            -- Get the mid section image and its flip from this cocktail's random generated sequence.
            -- Repeat the 10 options (+1/-1 for Lua arrays yay).
            local i = ((a-1) % 10) + 1
            local img_idx = COCKTAILS[TARGET_COCKTAIL.type_idx].recipe_mid_idxs[i]
            local flip = COCKTAILS[TARGET_COCKTAIL.type_idx].recipe_mid_flips[i]
            TEXTURES.recipe.middle[img_idx]:draw(recipe_x, scroll_offset + y_paper_insert, flip)
        end
        -- Draw steps.
        for a = first_step_to_draw, last_step_to_draw, 1 do
            gfx.drawText(recipe_steps_text[a], text_x, scroll_offset + y_first_step + (a-1) * line_height)
        end

        -- Draw footer.
        if visible_bottom_y > y_paper_bottom then
            -- Paper background.
            TEXTURES.recipe.bottom:draw(recipe_x, scroll_offset + y_paper_bottom)
            -- Show "rating" text.
            gfx.drawText(WIN_TEXT_2, text_x, scroll_offset + y_paper_bottom)
        end
    gfx.popContext()
end


function Recipe_draw_menu(x, y, recipe_text, step_types)
    -- draw scrollable top recipe in menu
    local text_x <const> = 13
    local text_y <const> = 54
    local text_x_aligned <const> = TEXTURES.recipe_small.middle[1].width/2
    local line_height <const> = 21
    local extra_lines <const> = 4

    local num_steps <const> = #recipe_text

    -- figure out number of middle inserts
    local insert_height <const> = TEXTURES.recipe_small.middle[1].height
    local top_height <const> = TEXTURES.recipe_small.top.height
    local bottom_height <const> = TEXTURES.recipe_small.bottom.height
    local number_of_lines <const> = num_steps + extra_lines
    local number_of_inserts <const> = math.max(0, math.ceil(((number_of_lines * line_height) - top_height ) / insert_height))
    RECIPE_MAX_HEIGHT = top_height + number_of_inserts * insert_height + bottom_height
    local selected_recipe <const> = COCKTAILS[MENU_STATE.focused_option+1]

    -- draw recipe background
    gfx.pushContext()
        TEXTURES.recipe_small.top:draw(x, y)
        for a = 0, number_of_inserts-1, 1 do
            -- Get the mid section image and flip from this cocktail's random generated sequence.
            -- Repeat the 10 options (+1 for Lua arrays).
            local i = (a % 10) + 1
            local img_idx = COCKTAILS[TARGET_COCKTAIL.type_idx].recipe_mid_idxs[i]
            local flip = COCKTAILS[TARGET_COCKTAIL.type_idx].recipe_mid_flips[i]
            TEXTURES.recipe_small.middle[img_idx]:draw(x, y + top_height + a * insert_height, flip)
        end
        TEXTURES.recipe_small.bottom:draw(x, y + top_height + number_of_inserts * insert_height)
    gfx.popContext()

    -- draw recipe content
    gfx.pushContext()
        local y = y + text_y
        gfx.setFont(FONTS.speech_font)

        if #recipe_text > selected_recipe.step_ratings[3] then
            gfx.drawTextAligned("This works . . .\nBut it took " .. tostring(#recipe_text) .. " steps.", x + text_x_aligned, y, kTextAlignment.center)
        elseif #recipe_text > selected_recipe.step_ratings[2] then
            gfx.drawTextAligned("Not too bad!\nIn " .. tostring(#recipe_text) .. " steps.", x + text_x_aligned, y, kTextAlignment.center)
        elseif #recipe_text > selected_recipe.step_ratings[1] then
            gfx.drawTextAligned("Fantastic!\nIn only " .. tostring(#recipe_text) .. " steps.", x + text_x_aligned, y, kTextAlignment.center)
        else
            gfx.drawTextAligned("Mastered!!!\nIn " .. tostring(#recipe_text) .. " simple steps.", x + text_x_aligned, y, kTextAlignment.center)
        end

        for a = 1, #recipe_text, 1 do
            gfx.drawText(recipe_text[a], x + text_x + 8, y + 46)
            y += line_height
        end
    gfx.popContext()
end
