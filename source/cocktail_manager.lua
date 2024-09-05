local gfxi <const> = playdate.graphics.image
local gfxit <const> = playdate.graphics.imagetable


COCKTAILS = {
  { name="Snailiva",
    rune_composition={1, 0, 0},
    step_ratings= {2, 8, 15},
    img=gfxi.new('images/cocktails/snailiva_sheet'),
    table= gfxit.new('images/cocktails/snailiva_sheet'),
    locked_img = gfxi.new('images/cocktails/snailiva_sheet_locked'),
    locked_table = gfxit.new('images/cocktails/snailiva_sheet_locked'),
    recipe_img = gfxi.new('images/recipes/header_snailiva'),
    -- Sequence of random looking numbers generated offline for the order of mid-section recipe paper images 1 to 6.
    -- The order repeats if more than 10 paper sections are needed. This is nicer for control of how each recipe paper
    -- looks and avoids repeatedly doing the math at runtime when drawing the recipe which helps the performance.
    recipe_mid_idxs = { 5, 2, 4, 3, 1, 6, 4, 5, 3, 1 },
    -- Sequence of numbers of 0-3 corresponding to enum {gfx.kImageUnflipped, gfx.kImageFlippedX, gfx.kImageFlippedY, gfx.kImageFlippedXY}
    recipe_mid_flips = { 1, 2, 0, 3, 0, 3, 2, 1, 2, 3 },
    framerate= 16,
    sticker= gfxi.new('images/cocktails/sticker_a'),
    sticker_pos= {41, 131},
    mastered_sticker_pos= {109, 124} },
    --Intro 1 (Love)

  { name="Silkini",
    rune_composition={0.6, 1, 0},
    step_ratings= {3, 10, 18},
    img=gfxi.new('images/cocktails/silkini_sheet'),
    table= gfxit.new('images/cocktails/silkini_sheet'),
    locked_img = gfxi.new('images/cocktails/silkini_sheet_locked'),
    locked_table = gfxit.new('images/cocktails/silkini_sheet_locked'),
    recipe_img = gfxi.new('images/recipes/header_silkini'),
    recipe_mid_idxs = { 2, 6, 1, 5, 6, 2, 4, 3, 3, 6 },
    recipe_mid_flips = { 0, 2, 3, 1, 1, 0, 3, 2, 3, 0 },
    framerate= 16,
    sticker= gfxi.new('images/cocktails/sticker_b'),
    sticker_pos= {109, 116},
    mastered_sticker_pos= {37, 66} },
    -- Intro 2 (Love & Doom)

  { name="Green Toe",
    rune_composition={0, 0.33, 0.75},
    step_ratings= {3, 10, 18},
    img=gfxi.new('images/cocktails/green_toe_sheet'),
    table= gfxit.new('images/cocktails/green_toe_sheet'),
    locked_img = gfxi.new('images/cocktails/green_toe_sheet_locked'),
    locked_table = gfxit.new('images/cocktails/green_toe_sheet_locked'),
    recipe_img = gfxi.new('images/recipes/header_green_toe'),
    recipe_mid_idxs = { 2, 1, 5, 4, 1, 5, 6, 3, 1, 2 },
    recipe_mid_flips = { 3, 1, 2, 1, 3, 0, 1, 2, 0, 3 },
    framerate= 16,
    sticker= gfxi.new('images/cocktails/sticker_c'),
    sticker_pos= {114, 79},
    mastered_sticker_pos= {42, 48} },
    --Easy (Doom & Weeds but specific)

  { name="Overdose",
    rune_composition={0.25, 1, 0.66},
    step_ratings= {4, 10, 18},
    img=gfxi.new('images/cocktails/overdose_sheet'),
    table= gfxit.new('images/cocktails/overdose_sheet'),
    locked_img = gfxi.new('images/cocktails/overdose_sheet_locked'),
    locked_table = gfxit.new('images/cocktails/overdose_sheet_locked'),
    recipe_img = gfxi.new('images/recipes/header_overdose'),
    recipe_mid_idxs = { 4, 6, 2, 1, 3, 5, 6, 3, 1, 2 },
    recipe_mid_flips = { 2, 1, 1, 2, 3, 0, 0, 3, 2, 1 },
    framerate= 16,
    sticker= gfxi.new('images/cocktails/sticker_a'),
    sticker_pos= {109, 135},
    mastered_sticker_pos= {37, 67} },
    --Medium (3 runes and specific. Spamming = fine tuning)

  { name="Hodge Podge",
    rune_composition={0.45, 0.45, 0.45},
    step_ratings= {4, 12, 20},
    img=gfxi.new('images/cocktails/hodge_podge_sheet'),
    table= gfxit.new('images/cocktails/hodge_podge_sheet'),
    locked_img = gfxi.new('images/cocktails/hodge_podge_sheet_locked'),
    locked_table = gfxit.new('images/cocktails/hodge_podge_sheet_locked'),
    recipe_img = gfxi.new('images/recipes/header_hodge_podge'),
    recipe_mid_idxs = { 5, 4, 1, 4, 6, 3, 2, 5, 6, 2 },
    recipe_mid_flips = { 3, 2, 0, 1, 2, 0, 1, 3, 3, 1 },
    framerate= 16,
    sticker= gfxi.new('images/cocktails/sticker_c'),
    sticker_pos= {112, 134},
    mastered_sticker_pos= {35, 128} },
    --Hard (3 Runes. All equally balanced)

  { name="Dicey Brew",
    rune_composition={1, 1, 1},
    step_ratings= {4, 10, 18},
    img=gfxi.new('images/cocktails/dicey_brew_sheet'),
    table= gfxit.new('images/cocktails/dicey_brew_sheet'),
    locked_img = gfxi.new('images/cocktails/dicey_brew_sheet_locked'),
    locked_table = gfxit.new('images/cocktails/dicey_brew_sheet_locked'),
    recipe_img = gfxi.new('images/recipes/header_dicey_brew'),
    recipe_mid_idxs = { 4, 1, 5, 3, 1, 4, 2, 5, 3, 6 },
    recipe_mid_flips = { 0, 2, 0, 2, 1, 3, 1, 2, 0, 3 },
    framerate= 16,
    sticker= gfxi.new('images/cocktails/sticker_b'),
    sticker_pos= {107, 111},
    mastered_sticker_pos= {35, 110} },
    --Random
}

TARGET_COCKTAIL = {
  name = '',
  type_idx = 1,
  rune_count = {0, 0, 0},
  step_ratings = {0, 0, 0},
}


function Reroll_mystery_potion()
    for a = 1, #COCKTAILS, 1 do
      if COCKTAILS[a].name == "Dicey Brew" then
          for b = 1, 3, 1 do
            COCKTAILS[a].rune_composition[b] = math.random()
          end
      end
  end
end


function Set_target_potion(chosen_cocktail_idx)  
  local chosen_cocktail = COCKTAILS[chosen_cocktail_idx]

  TARGET_COCKTAIL.name = chosen_cocktail.name
  TARGET_COCKTAIL.type_idx = chosen_cocktail_idx
  TARGET_COCKTAIL.step_ratings = chosen_cocktail.step_ratings

  -- Find normalized rune composition.
  local sum = 0
  for a = 1, NUM_RUNES, 1 do
    TARGET_COCKTAIL.rune_count[a] = chosen_cocktail.rune_composition[a]
  end
end


function Score_of_recipe(recipe)
  local score = #recipe
  return score
end
