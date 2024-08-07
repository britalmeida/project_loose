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
}
