extends SceneTree
var game
func _initialize():call_deferred("review")
func shot(name:String):
 game.queue_redraw()
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://captures/v02/"+name+".png")
func review():
 game=load("res://main.tscn").instantiate();root.add_child(game)
 await process_frame
 game.test_mode="art-review";game.muted=true
 game.set_process(false);game.set_physics_process(false)
 game.art_time=1.1
 await shot("menu")
 game.start_game();game.setup_showcase()
 game.open_upgrade()
 game.choices=[game.UPGRADES[3],game.MORE_UPGRADES[0],game.MORE_UPGRADES[1]]
 await shot("upgrade")
 game.state="cabinet"
 for i in 7:
  game.cabinet_index=i;game.cabinet_death=-1
  await shot("cabinet-"+str(i))
  game.cabinet_death=1.6
  await shot("death-"+str(i))
 game.start_game();game.setup_showcase()
 game.spawn_enemy(6,true)
 var boss:Dictionary=game.enemies.back();boss.pos=Vector2(893,450);boss.prev=boss.pos;boss.spawn=0
 boss.phase="slam_warn";boss.timer=.5;boss.phase_t=.5
 game.boss_spawned=true;game.time_alive=144;game.wave=4
 await shot("boss-battle")
 game.state="paused";await shot("pause")
 game.finish_game(true);await shot("victory")
 game.state="dead";game.death_elapsed=2;await shot("defeat")
 quit()
