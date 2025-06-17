local sp <const> = playdate.sound.sampleplayer
local fp <const> = playdate.sound.fileplayer

SOUND = {
  fire_blow = sp.new("sound/fire_blow"),
  fire_burn = fp.new("sound/fire_burn"),
  drop_01 = sp.new("sound/drop_01"),
  drop_02 = sp.new("sound/drop_02"),
  drop_03 = sp.new("sound/drop_03"),
  bubble_pop_01 = sp.new("sound/bubble_pop_1"),
  bubble_pop_02 = sp.new("sound/bubble_pop_2"),
  bubble_pop_03 = sp.new("sound/bubble_pop_3"),
  stir_sound = sp.new("sound/pot_stir"),
  cauldron_bubble_big = sp.new("sound/cauldron_bubble_big"),
  cauldron_bubble_small = sp.new("sound/cauldron_bubble_small"),
  cauldron_bubble_pop = sp.new("sound/cauldron_bubble_pop"),
  bg_loop_menu = fp.new("sound/menu_music_loop"),
  bg_loop_gameplay = fp.new("sound/gameplay_music_loop"),
  menu_confirm = sp.new("sound/menu_item_confirm"),
  folding_open = sp.new("sound/folding_open"),
  folding_close = sp.new("sound/folding_close"),
  finger_double_tap = sp.new("sound/finger_double_tap_frog"),
  into_cocktail_menu = sp.new("sound/into_cocktail_menu_slide"),
  into_main_menu = sp.new("sound/into_main_menu_slide"),
  win_recipe_open = sp.new("sound/recipe_writing"),
  sticker_slap = sp.new("sound/sticker_slap"),
  sparkles = sp.new("sound/sparkles"),
}

FROG_SOUND = {
	speaking 	= sp.new("sound/frog_blabla"),
	excited 	= sp.new("sound/frog_excited"),
	headshake = sp.new("sound/frog_headshake"),
	facepalm 	= sp.new("sound/frog_facepalm"),
	tickleface = sp.new("sound/tickleface"),
	urgent 		= sp.new("sound/frog_urgent"),
	eyelick 	= sp.new("sound/frog_eye_lick"),
	burp 		= sp.new("sound/frog_burp"),
  fire 		= sp.new("sound/frog_fire"),
}

INGREDIENT_SOUND = {
  ingredient_1A = sp.new("sound/ingredient_sounds/1A"),
  ingredient_1B = sp.new("sound/ingredient_sounds/1B"),
  ingredient_1C = sp.new("sound/ingredient_sounds/1C"),
  ingredient_1D = sp.new("sound/ingredient_sounds/1D"),

  ingredient_2A = sp.new("sound/ingredient_sounds/2A"),
  ingredient_2B = sp.new("sound/ingredient_sounds/2B"),
  ingredient_2D = sp.new("sound/ingredient_sounds/2D"),

  ingredient_3A = sp.new("sound/ingredient_sounds/3A"),
  ingredient_3B = sp.new("sound/ingredient_sounds/3B"),
  ingredient_3D = sp.new("sound/ingredient_sounds/3D"),

  ingredient_4A = sp.new("sound/ingredient_sounds/4A"),
  ingredient_4B = sp.new("sound/ingredient_sounds/4B"),
  ingredient_4C = sp.new("sound/ingredient_sounds/4C"),
  ingredient_4D = sp.new("sound/ingredient_sounds/4D"),

  ingredient_5A = sp.new("sound/ingredient_sounds/5A"),
  ingredient_5B = sp.new("sound/ingredient_sounds/5B"),
  ingredient_5D = sp.new("sound/ingredient_sounds/5D"),

  ingredient_6A = sp.new("sound/ingredient_sounds/6A"),
  ingredient_6B = sp.new("sound/ingredient_sounds/6B"),
  ingredient_6C = sp.new("sound/ingredient_sounds/6C"),
  ingredient_6D = sp.new("sound/ingredient_sounds/6D"),

  ingredient_7A = sp.new("sound/ingredient_sounds/7A"),
  ingredient_7B = sp.new("sound/ingredient_sounds/7B"),
  ingredient_7C = sp.new("sound/ingredient_sounds/7C"),
  ingredient_7D = sp.new("sound/ingredient_sounds/7D"),

  ingredient_8A = sp.new("sound/ingredient_sounds/8A"),
  ingredient_8B = sp.new("sound/ingredient_sounds/8B"),
  ingredient_8C = sp.new("sound/ingredient_sounds/8C"),
  ingredient_8D = sp.new("sound/ingredient_sounds/8D"),

  ingredient_9A = sp.new("sound/ingredient_sounds/9A"),
  ingredient_9B = sp.new("sound/ingredient_sounds/9B"),
  ingredient_9C = sp.new("sound/ingredient_sounds/9C"),
  ingredient_9D = sp.new("sound/ingredient_sounds/9D"),
}


function Init_sounds()
  
  -- Tweaking the music volume to not drown out sounds
  SOUND.bg_loop_menu:setVolume(0.4)
  SOUND.bg_loop_gameplay:setVolume(0.5)

  -- Tweak SFX to prevent clipping on max volume
  FROG_SOUND.excited:setVolume(0.7)
  FROG_SOUND.speaking:setVolume(0.8)
  FROG_SOUND.facepalm:setVolume(0.8)
  SOUND.fire_blow:setVolume(0.8)
end