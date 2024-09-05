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
    --commented out for now until it works.
    -- table.setn(#recipe_steps)

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
    -- draw full scrollable recipe on success

    -- Scroll window: which part of the recipe is in view. (window relative to the recipe)
    -- y can be negative: it's where the recipe starts relative to the playdate viewport.
    local scroll_offset <const> = -y
    local scroll_window_end <const> = scroll_offset + 240

    local recipe_x <const> = 40
    local text_x <const> = 24
    local text_y <const> = 180
    local line_height <const> = 23
    local insert_height <const> = 30 -- height of midsection textures.

    local header_img <const> = COCKTAILS[TARGET_COCKTAIL.type_idx].recipe_img
    local num_steps <const> = #recipe_steps_text
    -- figure out amount of insert pieces for the text
    local number_of_inserts <const> = 2 + math.ceil( (num_steps * line_height) / insert_height )
    -- +2 midsections for extra lines at top and bottom.

    -- FIXME: this makes the game not random anymore.
    -- Recipe backgrounds should be picked based on recipe/length or something that doesn't vary every frame.
    -- Removing this needs checks that everywhere else where random() is used won't introduce new problems.
    math.randomseed(num_steps)

    local y_paper_top <const> = 0 -- margin from the recipe to the top of the screen.
    local y_first_insert <const> = y_paper_top + TEXTURES.recipe.top.height
    local y_recipe_step_start <const> = line_height * 2.2
    local y_header_img <const> = 0
    local y_win_sticker <const> = 124
    local y_first_text <const> = text_y
    local y_paper_bottom <const> = y_first_text + y_recipe_step_start + (line_height * (num_steps + 1))

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
            TEXTURES.recipe.top:draw(recipe_x, y + y_paper_top)
        end

        -- Draw mid sections
        for a = 0, number_of_inserts-1, 1 do
            local y_paper_insert <const> = y_first_insert + a * insert_height
            if y_paper_insert < scroll_window_end and y_paper_insert + insert_height > scroll_offset then
                 -- Get the mid section image and flip from this cocktail's random generated sequence.
                -- Repeat the 10 options (+1 for Lua arrays).
                local i = (a % 10) + 1
                local img_idx = COCKTAILS[TARGET_COCKTAIL.type_idx].recipe_mid_idxs[i]
                local flip = COCKTAILS[TARGET_COCKTAIL.type_idx].recipe_mid_flips[i]
                TEXTURES.recipe.middle[img_idx]:draw(recipe_x, y + y_paper_insert, flip)
            end
        end

        if y_paper_bottom < scroll_window_end then
            TEXTURES.recipe.bottom:draw(recipe_x, y + y_paper_bottom)
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
        y += line_height * 0.5
        if y > 0 and y < 240 then
            if num_steps > TARGET_COCKTAIL.step_ratings[3] then
                gfx.drawText("Yep ... that was " .. tostring(num_steps) .. " steps.", recipe_x + text_x, y)
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
    local text_x <const> = 13
    local text_y <const> = 54
    local text_x_aligned <const> = TEXTURES.recipe_small.middle[1].width/2
    local line_height <const> = 21
    local extra_lines <const> = 4

    -- Set consistent random seed based on recipe length
    local num_steps <const> = #recipe_text
    math.randomseed(num_steps)

    -- figure out number of middle inserts
    local insert_height <const> = TEXTURES.recipe_small.middle[1].height
    local top_height <const> = TEXTURES.recipe_small.top.height
    local bottom_height <const> = TEXTURES.recipe_small.bottom.height
    local number_of_lines <const> = #recipe_text + extra_lines
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
