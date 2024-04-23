local sp <const> = playdate.sound.sampleplayer

local bg_loop_menu = sp.new("sound/menu_music_loop_thin")

SOUND = {
  fire_blow = sp.new("sound/fire_blow"),
  fire_burn = sp.new("sound/fire_burn"),
  drop_01 = sp.new("sound/drop_01"),
  drop_02 = sp.new("sound/drop_02"),
  drop_03 = sp.new("sound/drop_03"),
  stir_sound = sp.new("sound/pot_stir"),
  bg_loop_menu = bg_loop_menu,
  bg_loop_gameplay = bg_loop_menu,
  menu_confirm = sp.new("sound/menu_item_confirm"),
}
