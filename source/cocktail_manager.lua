local gfxi <const> = playdate.graphics.image

COCKTAILS = {
  { name = "Snailiva",  rune_composition = {4, 1, 0}, color=0.1, viscosity=0.2, img = gfxi.new('images/cocktails/snailiva') },
  { name = "Greentoe",  rune_composition = {0, 3, 7}, color=0.2, viscosity=0.8, img = gfxi.new('images/cocktails/greentoe') },
  { name = "Silkini",   rune_composition = {0, 1, 2}, color=0.9, viscosity=0.4, img = gfxi.new('images/cocktails/silkini') },
}

TARGET_COCKTAIL = {
  type_idx = 1,
  rune_ratio = {1, 0, 0},
  color = 0.1,
  viscosity = 0.2,
}

function Set_target_potion(chosen_cocktail_idx)
  local chosen_cocktail = COCKTAILS[chosen_cocktail_idx]

  TARGET_COCKTAIL.type_idx = chosen_cocktail_idx
  TARGET_COCKTAIL.color = chosen_cocktail.color
  TARGET_COCKTAIL.viscosity = chosen_cocktail.viscosity

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
