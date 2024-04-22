local gfxi <const> = playdate.graphics.image

COCKTAILS = {
  { name="Snailiva",  rune_composition={4, 1, 0}, color=0.1, img=gfxi.new('images/cocktails/snailiva') },
  { name="Greentoe",  rune_composition={0, 3, 7}, color=0.2, img=gfxi.new('images/cocktails/greentoe') },
  { name="Silkini",   rune_composition={0, 1, 2}, color=0.9, img=gfxi.new('images/cocktails/silkini') },
  { name="Dicybrew",   rune_composition={1, 1, 1}, color=1, img=gfxi.new('images/cocktails/silkini') },
}

TARGET_COCKTAIL = {
  type_idx = 1,
  rune_ratio = {1, 0, 0},
  color = 0.1,
}

function Reroll_mystery_potion()
    for a = 1, #COCKTAILS, 1 do
      if COCKTAILS[a].name == "Dicybrew" then
          COCKTAILS[a].color = math.random(100)/100
          for b = 1, 3, 1 do
            COCKTAILS[a].rune_composition[b] = math.random(9)
          end
      end
  end
end

function Set_target_potion(chosen_cocktail_idx)
  local chosen_cocktail = COCKTAILS[chosen_cocktail_idx]

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
