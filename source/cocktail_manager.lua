local gfxi <const> = playdate.graphics.image
local gfxit <const> = playdate.graphics.imagetable


COCKTAILS = {
  { name="Snailiva",
    rune_composition={1, 0, 0},
    color=1.0,
    img=gfxi.new('images/cocktails/snailiva_sheet'),
    table= gfxit.new('images/cocktails/snailiva_sheet'),
    locked_img = gfxi.new('images/cocktails/snailiva_sheet_locked'),
    locked_table = gfxit.new('images/cocktails/snailiva_sheet_locked'),
    recipe_img = gfxi.new('images/recipes/recipe_snailiva'),
    framerate= 16,
    sticker= gfxi.new('images/cocktails/sticker_a'),
    sticker_pos= {41, 131} },
    --Intro 1 (Love)

  { name="Silkini",
    rune_composition={0.6, 1, 0},
    color=0.0,
    img=gfxi.new('images/cocktails/silkini_sheet'),
    table= gfxit.new('images/cocktails/silkini_sheet'),
    locked_img = gfxi.new('images/cocktails/silkini_sheet_locked'),
    locked_table = gfxit.new('images/cocktails/silkini_sheet_locked'),
    recipe_img = gfxi.new('images/recipes/recipe_silkini'),
    framerate= 16,
    sticker= gfxi.new('images/cocktails/sticker_b'),
    sticker_pos= {109, 116} },
    -- Intro 2 (Love & Doom)

  { name="Green Toe",
    rune_composition={0, 0.33, 0.8},
    color=0.25,
    img=gfxi.new('images/cocktails/green_toe_sheet'),
    table= gfxit.new('images/cocktails/green_toe_sheet'),
    locked_img = gfxi.new('images/cocktails/green_toe_sheet_locked'),
    locked_table = gfxit.new('images/cocktails/green_toe_sheet_locked'),
    recipe_img = gfxi.new('images/recipes/recipe_green_toe'),
    framerate= 16,
    sticker= gfxi.new('images/cocktails/sticker_c'),
    sticker_pos= {114, 79} },
    --Easy (Doom & Weeds but specific)

  { name="Overdose",
    rune_composition={0.25, 1, 0.66},
    color=0.15,
    img=gfxi.new('images/cocktails/overdose_sheet'),
    table= gfxit.new('images/cocktails/overdose_sheet'),
    locked_img = gfxi.new('images/cocktails/overdose_sheet_locked'),
    locked_table = gfxit.new('images/cocktails/overdose_sheet_locked'),
    recipe_img = gfxi.new('images/recipes/recipe_overdose'),
    framerate= 16,
    sticker= gfxi.new('images/cocktails/sticker_a'),
    sticker_pos= {109, 135} },
    --Medium (3 runes and specific. Spamming = fine tuning)

  { name="Hodge Podge",
    rune_composition={0.5, 0.5, 0.5},
    color=0.85,
    img=gfxi.new('images/cocktails/hodge_podge_sheet'),
    table= gfxit.new('images/cocktails/hodge_podge_sheet'),
    locked_img = gfxi.new('images/cocktails/hodge_podge_sheet_locked'),
    locked_table = gfxit.new('images/cocktails/hodge_podge_sheet_locked'),
    recipe_img = gfxi.new('images/recipes/recipe_hodge_podge'),
    framerate= 16,
    sticker= gfxi.new('images/cocktails/sticker_c'),
    sticker_pos= {112, 134} },
    --Hard (3 Runes. All equally balanced)

  { name="Dicey Brew",
    rune_composition={1, 1, 1},
    color=1,0,
    img=gfxi.new('images/cocktails/dicey_brew_sheet'),
    table= gfxit.new('images/cocktails/dicey_brew_sheet'),
    locked_img = gfxi.new('images/cocktails/dicey_brew_sheet_locked'),
    locked_table = gfxit.new('images/cocktails/dicey_brew_sheet_locked'),
    recipe_img = gfxi.new('images/recipes/recipe_dicey_brew'),
    framerate= 16,
    sticker= gfxi.new('images/cocktails/sticker_b'),
    sticker_pos= {107, 111} },
    --Random
}

TARGET_COCKTAIL = {
  name = '',
  type_idx = 1,
  rune_count = {0, 0, 0},
  color = 0.1,
}

function Reroll_mystery_potion()
    for a = 1, #COCKTAILS, 1 do
      if COCKTAILS[a].name == "Dicey Brew" then
          COCKTAILS[a].color = math.random(100)/100
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
  TARGET_COCKTAIL.color = chosen_cocktail.color

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