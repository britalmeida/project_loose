local gfxi <const> = playdate.graphics.image
local gfxit <const> = playdate.graphics.imagetable


COCKTAILS = {
  { name="Snailiva",
    rune_composition={1, 0, 0},
    color=1.0,
    img=gfxi.new('images/cocktails/snailiva_sheet'),
    table= gfxit.new('images/cocktails/snailiva_sheet'),
    recipe_img = gfxi.new('images/recipes/recipe_snailiva'),
    framerate= 16,
    sticker= gfxi.new('images/cocktails/success_sticker'),
    sticker_pos= {50, 50} },
    --Intro 1 (Love)

  { name="Silkini",
    rune_composition={1, 2, 0},
    color=0.0,
    img=gfxi.new('images/cocktails/silkini_sheet'),
    table= gfxit.new('images/cocktails/silkini_sheet'),
    recipe_img = gfxi.new('images/recipes/recipe_snailiva'),
    framerate= 16,
    sticker= gfxi.new('images/cocktails/sticker_b'),
    sticker_pos= {109, 116} },
    -- Intro 2 (Love & Doom)

  { name="Green Toe",
    rune_composition={0, 3, 9},
    color=0.25,
    img=gfxi.new('images/cocktails/green_toe_sheet'),
    table= gfxit.new('images/cocktails/green_toe_sheet'),
    recipe_img = gfxi.new('images/recipes/recipe_snailiva'),
    framerate= 16,
    sticker= gfxi.new('images/cocktails/sticker_c'),
    sticker_pos= {114, 79} },
    --Easy (Doom & Weeds but specific)

  { name="Overdose",
    rune_composition={1.5, 6, 4},
    color=0.15,
    img=gfxi.new('images/cocktails/overdose_sheet'),
    table= gfxit.new('images/cocktails/overdose_sheet'),
    recipe_img = gfxi.new('images/recipes/recipe_snailiva'),
    framerate= 16,
    sticker= gfxi.new('images/cocktails/success_sticker'),
    sticker_pos= {50, 50} },
    --Medium (3 runes and specific. Spamming = fine tuning)

  { name="Hodge Podge",
    rune_composition={1, 1, 1},
    color=0.85,
    img=gfxi.new('images/cocktails/hodge_podge_sheet'),
    table= gfxit.new('images/cocktails/hodge_podge_sheet'),
    recipe_img = gfxi.new('images/recipes/recipe_snailiva'),
    framerate= 16,
    sticker= gfxi.new('images/cocktails/success_sticker'),
    sticker_pos= {50, 50} },
    --Hard (3 Runes. All equally balanced)

  { name="Diceybrew",
    rune_composition={1, 1, 1},
    color=1,0,
    img=gfxi.new('images/cocktails/dicey_brew_sheet'),
    table= gfxit.new('images/cocktails/dicey_brew_sheet'),
    recipe_img = gfxi.new('images/recipes/recipe_snailiva'),
    framerate= 16,
    sticker= gfxi.new('images/cocktails/success_sticker'),
    sticker_pos= {50, 50} },
    --Random
}

TARGET_COCKTAIL = {
  name = '',
  type_idx = 1,
  rune_ratio = {1, 0, 0},
  color = 0.1,
}

function Reroll_mystery_potion()
    for a = 1, #COCKTAILS, 1 do
      if COCKTAILS[a].name == "Diceybrew" then
          COCKTAILS[a].color = math.random(100)/100
          for b = 1, 3, 1 do
            COCKTAILS[a].rune_composition[b] = math.random(9)
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
    TARGET_COCKTAIL.rune_ratio[a] = chosen_cocktail.rune_composition[a]
      sum = sum + TARGET_COCKTAIL.rune_ratio[a]
  end
  for a = 1, #TARGET_COCKTAIL.rune_ratio, 1 do
      TARGET_COCKTAIL.rune_ratio[a] = TARGET_COCKTAIL.rune_ratio[a] / sum
  end
end

function Score_of_recipe(recipe)
  local score = #recipe
  return score
end