extends SceneTree

var game

func _initialize():
 call_deferred("review")

func shot(name:String):
 game.queue_redraw()
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://captures/v03/art-"+name+".png")
 print("ART_SCREENSHOT "+name)

func stage(route:String="saw"):
 game.route_id=route
 game.mode="endless"
 game.start_game()
 game.setup_showcase()
 game.art_time=1.1
 game.banner_time=0
 game.tutorial_time=0
 game.player=Vector2(667,470)
 game.player_prev=game.player

func review():
 DirAccess.make_dir_recursive_absolute("res://captures/v03")
 game=load("res://main.tscn").instantiate()
 game.test_mode="art-review-v03"
 game.muted=true
 root.add_child(game)
 game.set_process(false)
 game.set_physics_process(false)
 if game.music_director!=null:
  game.music_director.player.stop()
 await process_frame
 game.art_time=1.1
 game.state="menu"
 await shot("menu-endless")
 game.mode="challenge"
 await shot("menu-challenge")
 game.begin_run_choice("endless")
 await shot("routes")
 for route in ["saw","thread","coil"]:
  stage(route)
  game.state="upgrade"
  game.choices=[]
  for blueprint in game.BLUEPRINTS:
   if blueprint.route==route:game.choices.append(blueprint.duplicate(true))
  await shot("blueprints-"+route)
 game.state="event_reward"
 for u in game.choices:u["rare"]=true
 await shot("event-reward")
 for kind in ["musicbox","recycler"]:
  stage("thread")
  game.start_field_event(kind)
  game.field_event.pos=Vector2(572,412)
  game.field_event.active=true
  game.field_event.progress=6.2
  game.field_event.kills=9
  game.field_event.remaining=17.3
  game.banner_time=0
  for phase in [0.0,0.7,1.7]:
   game.art_time=phase
   await shot("event-"+kind+"-"+str(phase).replace(".","_"))
 game.state="paused"
 game.music_director.set_music_volume(.65)
 await shot("pause")
 game.state="playing"
 game.time_alive=203
 game.bosses_defeated=1
 game.event_rewards=2
 game.finish_game(true)
 await shot("victory")
 game.state="dead"
 game.death_elapsed=2
 await shot("defeat")
 quit()
