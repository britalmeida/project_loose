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
}

FROG_SOUND = {
	speaking 	= sp.new("sound/frog_blabla"),
	excited 	= sp.new("sound/frog_excited"),
	headshake 	= sp.new("sound/frog_headshake"),
	facepalm 	= sp.new("sound/frog_excited"),
	tickleface 	= sp.new("sound/frog_excited"),
	urgent 		= sp.new("sound/frog_excited"),
	eyelick 	= sp.new("sound/frog_eye_lick"),
	drinking 	= sp.new("sound/frog_excited"),
	burp 		= sp.new("sound/frog_excited"),
}
