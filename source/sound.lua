local sp <const> = playdate.sound.sampleplayer
local fp <const> = playdate.sound.fileplayer

SOUND = {
  fire_blow = sp.new("sound/fire_blow"),
  fire_burn = fp.new("sound/fire_burn"),
  drop_01 = sp.new("sound/drop_01"),
  drop_02 = sp.new("sound/drop_02"),
  drop_03 = sp.new("sound/drop_03"),
  stir_sound = sp.new("sound/pot_stir"),
  bg_loop_menu = fp.new("sound/menu_music_loop"),
  bg_loop_gameplay = fp.new("sound/gameplay_music_loop"),
  menu_confirm = sp.new("sound/menu_item_confirm"),
  folding_open = sp.new("sound/folding_open"),
  folding_close = sp.new("sound/folding_close"),
  finger_double_tap = sp.new("sound/finger_double_tap_frog"),
  into_cocktail_menu = sp.new("sound/into_cocktail_menu_slide"),
  into_main_menu = sp.new("sound/into_main_menu_slide"),
  win_recipe_open = sp.new("sound/paper_scribble"),
}

FROG_SOUND = {
	speaking 	= sp.new("sound/frog_blabla"),
	excited 	= sp.new("sound/frog_excited"),
	headshake = sp.new("sound/frog_headshake"),
	facepalm 	= sp.new("sound/frog_facepalm"),
	tickleface = sp.new("sound/frog_excited"),
	urgent 		= sp.new("sound/frog_excited"),
	eyelick 	= sp.new("sound/frog_eye_lick"),
	drinking 	= sp.new("sound/frog_excited"),
	burp 		= sp.new("sound/frog_excited"),
}

INGREDIENT_SOUND = {
  ingredient_1A = sp.new("sound/ingredient_sounds/1A"),
  ingredient_1B = sp.new("sound/ingredient_sounds/1B"),
  ingredient_1C = sp.new("sound/ingredient_sounds/1C"),
  ingredient_1D = sp.new("sound/ingredient_sounds/1D"),

  ingredient_2A = sp.new("sound/ingredient_sounds/2A"),
  ingredient_2B = sp.new("sound/ingredient_sounds/2B"),
  ingredient_2C = sp.new("sound/ingredient_sounds/2C"),

  ingredient_3A = sp.new("sound/ingredient_sounds/3A"),
  ingredient_3B = sp.new("sound/ingredient_sounds/3B"),
  -- 3C is a duplicate
  ingredient_3D = sp.new("sound/ingredient_sounds/3D"),

  ingredient_4A = sp.new("sound/ingredient_sounds/4A"),
  ingredient_4B = sp.new("sound/ingredient_sounds/4B"),
  ingredient_4C = sp.new("sound/ingredient_sounds/4C"),
  ingredient_4D = sp.new("sound/ingredient_sounds/4D"),

  ingredient_6B = sp.new("sound/ingredient_sounds/6B"),
  ingredient_6C = sp.new("sound/ingredient_sounds/6C"),

  ingredient_7A = sp.new("sound/ingredient_sounds/7A"),
  ingredient_7B = sp.new("sound/ingredient_sounds/7B"),
  ingredient_7C = sp.new("sound/ingredient_sounds/7C"),
  ingredient_7D = sp.new("sound/ingredient_sounds/7D"),

  ingredient_8D = sp.new("sound/ingredient_sounds/8D"),

  ingredient_9A = sp.new("sound/ingredient_sounds/9A"),
  ingredient_9B = sp.new("sound/ingredient_sounds/9B"),
  ingredient_9C = sp.new("sound/ingredient_sounds/9C"),
  ingredient_9D = sp.new("sound/ingredient_sounds/9D"),
}


function Init_sounds()
  
  -- Tweaking the music volume to not drown out sounds
  SOUND.bg_loop_menu:setVolume(0.5)
  SOUND.bg_loop_gameplay:setVolume(0.5)

  -- Tweak SFX to prevent clipping on max volume
  FROG_SOUND.excited:setVolume(0.7)
  FROG_SOUND.speaking:setVolume(0.8)
  FROG_SOUND.facepalm:setVolume(0.8)
  SOUND.fire_blow:setVolume(0.8)
end