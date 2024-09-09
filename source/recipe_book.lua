local gfx <const> = playdate.graphics
local gfxi <const> = playdate.graphics.image

FROGS_FAVES = {
    accomplishments = {},
    recipes = {},
}
FROGS_FAVES_TEXT = {}

RECIPE_TEXT = {}
RECIPE_MAX_HEIGHT = 0

GAME_END_RECIPE = {
    cocktail = nil, -- reference to the COCKTAILS table entry.
    win_sticker = "", -- e.g. "Recipe\nImproved"
    text_steps = {}, -- e.g. {"1. Add 3 peppermints", "2. Stir just a bit", ...}
    num_text_steps = 0, -- precalculated number of text steps. Looks like this is O(n) in Lua.
    rating_text = "", -- e.g. "No way to beat X steps!!!"
}
RECIPE_SCROLL = 0 -- In px. 0 or negative. It's where the recipe starts offscreen relative to the top of the playdate screen.
RECIPE_MAX_SCROLL = 0 -- In px. Maximum value that the recipe can go up. Less than the recipe height so it doesn't fully disappear.


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
-- Steps are given as a list of consecutive drops e.g. { {1, 3}, {4, 1}, {1, 2} }
-- is_win_recipe - if it is the gameplay ended version, false for the menu version.
-- Outputs list of strings e.g. { "- 3 peppermints", "Stir forever ..." }
function Recipe_steps_to_text(recipe_steps, is_win_recipe)

    -- Pre-size the array to the necessary number of text line steps to avoid resizes.
    local text_lines = table.create(#recipe_steps, 0)

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

            if is_win_recipe then
                if quantity == 1 then
                    line = line .. "Add a "
                else
                    line = line .. "Add " .. quantity .. " "
                end
            else -- menu version
                line = line .. quantity .. " "
            end

            if ingredient_name == "salt" then
                if quantity > 1 then
                    line = line .. "pinches" .." of "..ingredient_name
                else
                    line = line .. "pinch" .." of "..ingredient_name
                end
            elseif ingredient_name == "perfume" then
                if is_win_recipe then
                    if quantity > 1 then
                        line = line .. "drops".." of "..ingredient_name
                    else
                        line = line .. "drop".." of "..ingredient_name
                    end
                else -- menu version
                    line = line .. ingredient_name .. " drop"
                    if quantity > 1 then
                        line = line .. "s"
                    end
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



-- High Scores

function Unlock_all_cocktails() -- Should be removed in final game + any references
    debug_cocktail_unlock = true
end


function Load_test_scores() -- Should be removed in final game
    local frogs_faves = {
        ["accomplishments"] = {
            ["Dicey Brew"] = true,
            ["Green Toe"] = true,
            ["Hodge Podge"] = true,
            ["Overdose"] = true,
            ["Silkini"] = true,
            ["Snailiva"] = true,
        },
        ["recipes"] = {
            ["Dicey Brew"] = { 9, 9, -1, -1, -1, -1, },
            ["Green Toe"] = { 5, 5, 5, -1, -1, 3, 3, 7, 7, -1, -1, 5, 5, -1, -1, 4, 4, -1, -1, -1, 4, -1, 4, 4, 4, 3, 3, -1, -1, -1, -1, -1, -1, -1, -1, 4, -1, 4, 4, 4, -1, -1, 4, 4, 4, -1, -1, -1, 3, 3, -1, -1, -1, 5, 5, -1, -1, -1, -1, -1, 4, -1, -1, -1, 4, 4, 3, 3, -1, -1, -1, 5, -1, -1, -1, 5, -1, 5, -1, 5, 5, 4, 4, 4, -1, -1, -1, 9, 9, -1, -1, 7, 7, -1, -1, 5, -1, -1, -1, 5, 5, -1, -1, -1, },
            ["Hodge Podge"] = { 6, 6, 6, -1, 6, 3, 3, 3, 3, -1, -1, -1, 9, 1, -1, -1, -1, 7, -1, -1, -1, 5, 1, -1, -1, -1, -1, 9, -1, -1, -1, 6, 6, 6, -1, 6, 3, 3, 3, 3, -1, -1, -1, 9, 1, -1, -1, -1, 7, -1, -1, -1, 5, 1, -1, -1, -1, -1, 9, -1, -1, -1, 6, 6, 6, -1, 6, 3, 3, 3, 3, -1, -1, -1, 9, 1, -1, -1, -1, 7, -1, -1, -1, 5, 1, -1, -1, -1, -1, 9, -1, -1, -1, 6, 6, 6, -1, 6, 3, 3, 3, 3, -1, -1, -1, 9, 1, -1, -1, -1, 7, -1, -1, -1, 5, 1, -1, -1, -1, -1, 9, -1, -1, -1, 6, 6, 6, -1, 6, 3, 3, 3, 3, -1, -1, -1, 9, 1, -1, -1, -1, 7, -1, -1, -1, 5, 1, -1, -1, -1, -1, 9, -1, -1, -1, 6, 6, 6, -1, 6, 3, 3, 3, 3, -1, -1, -1, 9, 1, -1, -1, -1, 7, -1, -1, -1, 5, 1, -1, -1, -1, -1, 9, -1, -1, -1, 6, 6, 6, -1, 6, 3, 3, 3, 3, -1, -1, -1, 9, 1, -1, -1, -1, 7, -1, -1, -1, 5, 1, -1, -1, -1, -1, 9, -1, -1, -1, 6, 6, 6, -1, 6, 3, 3, 3, 3, -1, -1, -1, 9, 1, -1, -1, -1, 7, -1, -1, -1, 5, 1, -1, -1, -1, -1, 9, -1, -1, -1, 6, 6, 6, -1, 6, 3, 3, 3, 3, -1, -1, -1, 9, 1, -1, -1, -1, 7, -1, -1, -1, 5, 1, -1, -1, -1, -1, 9, -1, -1, -1,},
            ["Overdose"] = { 1, 3, 3, 3, 3, -1, -1, -1, 3, -1, -1, 9, -1, -1, -1, 3, -1, -1, -1, },
            ["Silkini"] = { 8, 8, 8, 2, 2, -1, -1, },
            ["Snailiva"] = { 2, 2, 2, -1, -1, -1, },
        },
    }

    FROGS_FAVES = frogs_faves
    playdate.datastore.write(frogs_faves, 'frogs_faves')
end


function Reset_high_scores() -- Should be removed in final game
    local frogs_faves = {
        accomplishments = {},
        recipes = {}
    }

    for a = 1, #COCKTAILS, 1 do
        frogs_faves.accomplishments[COCKTAILS[a].name] = false
        frogs_faves.recipes[COCKTAILS[a].name] = {}
    end

    FROGS_FAVES = frogs_faves
    playdate.datastore.write(frogs_faves, 'frogs_faves')
end


function Store_high_scores()
    playdate.datastore.write(FROGS_FAVES, 'frogs_faves')
end


function Load_high_scores()
    FROGS_FAVES = playdate.datastore.read('frogs_faves')
    if FROGS_FAVES == nil or next(FROGS_FAVES) == nil then
        Reset_high_scores()
    end

    -- Generate text version of high score recipes
    for a = 1, #COCKTAILS, 1 do
        local cocktail_name = COCKTAILS[a].name
        recipe_steps = Recipe_to_steps(FROGS_FAVES.recipes[cocktail_name])
        FROGS_FAVES_TEXT[cocktail_name] = Recipe_steps_to_text(recipe_steps, false)
    end
end


-- Recipe drawing.

function Calculate_recipe_size_for_success_draw()
    local num_steps <const> = GAME_END_RECIPE.num_text_steps

    local line_height <const> = 23
    local paragraph_space <const> = 18
    local y_first_insert <const> = TEXTURES.recipe.top.height
    local y_first_step <const> = y_first_insert + paragraph_space
    local y_paper_bottom <const> = y_first_step + (line_height * num_steps) + paragraph_space
    local recipe_height <const> = y_paper_bottom + TEXTURES.recipe.bottom.height

    return recipe_height
end


function Recipe_draw_success()
    -- Draw full scrollable recipe on game ended.

    -- Notes: the recipe top texture fits all of the header parts.
    -- The variable length steps go in paper inserts, as many as needed.
    -- At a fixed offset from the last step, starts the footer background on top of the remainder of the last insert.
    -- All the footer bits fit on the footer texture.

    -- The recipe layout is in its own coordinates: 0 is the top left-corner of the paper,
    -- no matter where it is placed on screen and if scrolled out of view.
    -- The draw code uses scroll_offset as the origin.
    local scroll_offset <const> = RECIPE_SCROLL -- 0 or negative. It's where the recipe starts offscreen.
    local visible_top_y <const> = -RECIPE_SCROLL -- Part of the recipe which is shown, in recipe coordinates. For clipping.
    local visible_bottom_y <const> = visible_top_y + 240

    local num_steps <const> = GAME_END_RECIPE.num_text_steps

    local recipe_x <const> = 40
    local text_x <const> = recipe_x + 24
    local line_height <const> = 23
    local paragraph_space <const> = 18
    local insert_height <const> = 30 -- height of midsection textures.
    local y_first_insert <const> = TEXTURES.recipe.top.height
    local y_first_step <const> = y_first_insert + paragraph_space
    local y_paper_bottom <const> = y_first_step + (line_height * num_steps) + paragraph_space
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
            GAME_END_RECIPE.cocktail.recipe_img:draw(recipe_x - 40, scroll_offset)
            -- Sticker: "Recipe Done" / "Recipe Improved".
            gfx.drawTextAligned(GAME_END_RECIPE.win_sticker, recipe_x + 66, scroll_offset + 124, kTextAlignment.center)
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
            local img_idx = GAME_END_RECIPE.cocktail.recipe_mid_idxs[i]
            local flip = GAME_END_RECIPE.cocktail.recipe_mid_flips[i]
            TEXTURES.recipe.middle[img_idx]:draw(recipe_x, scroll_offset + y_paper_insert, flip)
        end
        -- Draw steps.
        for a = first_step_to_draw, last_step_to_draw, 1 do
            gfx.drawText(GAME_END_RECIPE.text_steps[a], text_x, scroll_offset + y_first_step + (a-1) * line_height)
        end

        -- Draw footer.
        if visible_bottom_y > y_paper_bottom then
            -- Paper background.
            TEXTURES.recipe.bottom:draw(recipe_x, scroll_offset + y_paper_bottom)
            -- Show "rating" text.
            gfx.drawText(GAME_END_RECIPE.rating_text, text_x, scroll_offset + y_paper_bottom)
        end
    gfx.popContext()
end


function Recipe_draw_menu(x, y, recipe_text)
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
