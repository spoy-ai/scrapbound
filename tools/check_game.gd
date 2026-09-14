extends SceneTree
var game
var failures:Array=[]
func _initialize():
 call_deferred("run")
func check(condition:bool,label:String):
 if not condition:failures.append(label);push_error(label)
 else:print("PASS ",label)
func key(code:int,pressed:bool):
 var ev=InputEventKey.new()
 ev.physical_keycode=code
 ev.keycode=code
 ev.pressed=pressed
 Input.parse_input_event(ev)
 Input.flush_buffered_events()
func run():
 game=load("res://main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.test_mode="checks"
 game.muted=true
 game.set_physics_process(false)
 game.set_process(false)
 game.start_game()
 game.enemies.clear()
 game.spawn_cd=999
 var origin:Vector2=game.player
 key(KEY_D,true)
 game._physics_process(1.0/60)
 var straight=game.player.distance_to(origin)
 check(straight>3,"Movement responds to keyboard input")
 game.player=origin
 key(KEY_W,true)
 game._physics_process(1.0/60)
 check(absf(game.player.distance_to(origin)-straight)<.01,"Diagonal movement is normalized")
 key(KEY_D,false);key(KEY_W,false)
 game.player=Vector2(1200,400)
 game.last_dir=Vector2.RIGHT
 key(KEY_SPACE,true);key(KEY_SPACE,false)
 game._physics_process(1.0/60)
 check(game.dash_time>0 and game.invincible>0,"Dash starts immediately and grants invulnerability")
 for i in 20:game._physics_process(1.0/60)
 check(game.player.x<=1200.01,"Dash cannot cross arena boundary")
 var cd:float=game.dash_cd
 key(KEY_SPACE,true);key(KEY_SPACE,false)
 game._physics_process(1.0/60)
 check(game.dash_cd<cd,"Repeated input cannot bypass dash cooldown")
 game.start_game();game.enemies.clear();game.spawn_cd=999
 game.spawn_enemy(0)
 var rat:Dictionary=game.enemies[0]
 rat.spawn=0
 rat.pos=game.player+Vector2(80,0);rat.prev=rat.pos
 var before:float=rat.hp
 game.attack_cd=0
 for i in 18:game._physics_process(1.0/60)
 check(rat.hp<before,"Automatic saw lands damage on nearby enemy")
 game.start_game();game.enemies.clear();game.spawn_cd=999
 game.spawn_enemy(1)
 var car:Dictionary=game.enemies[0]
 car.spawn=0
 car.pos=game.player+Vector2(250,0);car.prev=car.pos;car.timer=0
 game.update_enemies(.01)
 check(car.phase=="warn","Car warns before charging")
 var dir:Vector2=car.dir
 game.player+=Vector2(0,150)
 game.update_enemies(.9)
 check(car.phase=="charge" and car.dir==dir,"Charge keeps its telegraphed direction")
 game.invincible=0
 var old_hp:float=game.hp
 game.take_damage(14)
 game.take_damage(14)
 check(game.hp==old_hp-14,"Damage invulnerability prevents simultaneous repeated hits")
 game.xp=game.next_xp
 game.update_drops(.01)
 var old_time:float=game.time_alive
 game._physics_process(1)
 check(game.state=="upgrade" and game.time_alive==old_time,"Upgrade selection pauses combat")
 check(game.choices.size()==3 and game.choices[0].id!=game.choices[1].id and game.choices[1].id!=game.choices[2].id,"Three distinct upgrades offered")
 game.choose_upgrade(0)
 check(game.state=="playing" and game.upgrades_taken.size()==1,"Choosing an upgrade applies it and resumes combat")
 game.enemies.clear();game.projectiles.clear();game.spawn_cd=999
 game.boss_spawned=true;game.time_alive=180;game.boss_defeated=false
 game._physics_process(.01)
 check(game.state=="playing","Timer alone cannot bypass the boss")
 game.boss_defeated=true
 game._physics_process(.01)
 check(game.state=="won","Surviving and defeating boss triggers victory")
 game.start_game();game.invincible=0;game.take_damage(1000)
 check(game.state=="dead","Lethal damage shows defeat")
 game.start_game()
 check(game.hp==100 and game.level==1 and game.upgrades_taken.is_empty() and game.bolt_count==1 and game.dash_cd==0,"Restart resets gameplay state")
 for glyph in "缝隙求生锯齿加固纽扣弹弓废料吞吞瓶盖甲虫弹簧盒偶线轴飞蜂":
  check(game.font.has_char(glyph.unicode_at(0)),"Font glyph "+glyph)
 check(game.atlases.size()>=31,"Original and new generated motion and VFX atlases loaded")
 # Every material death uses its own animation and leaves a fading corpse.
 game.crit_chance=0
 for kind in 7:
  game.start_game();game.enemies.clear();game.spawn_enemy(kind,kind==6)
  var foe:Dictionary=game.enemies[0];foe.spawn=0
  game.hurt_enemy(foe,100000,Vector2.RIGHT*300)
  var death_key:String=game.corpses[0].key
  if kind==0:death_key="rat_death2"
  if kind==3:death_key="beetle_death2"
  check(game.atlases.has(death_key) and game.kills==1,"Unique death animation: "+foe.key)
  game.hurt_enemy(foe,100000,Vector2.RIGHT)
  check(game.kills==1 and game.corpses.size()==1,"Death and loot fire exactly once: "+foe.key)
  game.update_presentation(4)
  check(game.corpses.is_empty(),"Wreckage fades and is removed: "+foe.key)
 game.start_game();game.enemies.clear();game.spawn_cd=999
 game.spawn_enemy(3)
 var beetle:Dictionary=game.enemies[0];beetle.spawn=0;beetle.dir=Vector2.RIGHT
 before=beetle.hp;game.hurt_enemy(beetle,20,Vector2.LEFT*10)
 check(is_equal_approx(before-beetle.hp,9.6),"Beetle frontal shell blocks 52 percent damage")
 before=beetle.hp;game.hurt_enemy(beetle,20,Vector2.RIGHT*10)
 check(is_equal_approx(before-beetle.hp,20.0),"Beetle rear remains vulnerable")
 game.start_game();game.enemies.clear();game.spawn_cd=999
 game.spawn_enemy(4)
 var jack:Dictionary=game.enemies[0];jack.spawn=0;jack.timer=0;jack.pos=game.player+Vector2(230,0)
 game.update_enemies(.01)
 var target:Vector2=jack.jump_to
 check(jack.phase=="jump_warn","Spring enemy shows landing warning")
 game.player+=Vector2(0,170);game.update_enemies(1.0);game.update_enemies(.3)
 check(jack.phase=="jump" and jack.jump_height>50 and jack.jump_to==target,"Spring jump follows locked target and has height")
 game.update_enemies(.36)
 check(jack.phase=="recover" and jack.jump_height==0,"Spring enemy has landing recovery window")
 game.start_game();game.enemies.clear();game.spawn_cd=999
 game.spawn_enemy(5)
 var wasp:Dictionary=game.enemies[0];wasp.spawn=0;wasp.timer=0
 game.update_enemies(.01)
 check(wasp.phase=="shoot_warn","Wasp warns before needle shot")
 game.update_enemies(.7)
 check(game.projectiles.size()==1 and game.projectiles[0].enemy,"Wasp fires one distinct needle projectile")
 game.start_game();game.enemies.clear();game.spawn_cd=999
 game.spawn_enemy(6,true)
 var boss:Dictionary=game.enemies[0];boss.spawn=0;boss.timer=0;boss.attack_cycle=1;boss.pos=game.player+Vector2(240,0)
 game.update_enemies(.01);check(boss.phase=="slam_warn","Unique boss warns before area slam")
 game.update_enemies(1.01);game.update_enemies(.56)
 check(boss.phase=="recover" and game.projectiles.size()==6,"Boss slam produces radial attack and recovery")
 game.start_game();game.enemies.clear();game.spawn_cd=999;game.ricochets=1
 game.spawn_enemy(0);game.spawn_enemy(0)
 var first:Dictionary=game.enemies[0];var second:Dictionary=game.enemies[1]
 first.pos=Vector2(600,400);second.pos=Vector2(720,400);first.spawn=0;second.spawn=0
 game.add_projectile(Vector2(500,377),Vector2(8000,0),false,10)
 game.update_projectiles(.02)
 check(first.hp<first.max_hp,"Fast button collision cannot tunnel through enemy")
 check(game.projectiles.size()==1 and game.projectiles[0].hit_ids.has(first.id),"Ricochet remembers its first target")
 for i in 20:game.update_projectiles(.01)
 check(second.hp<second.max_hp and game.projectiles.is_empty(),"Ricochet strikes second target and expires")
 game.start_game();game.enemies.clear();game.spawn_cd=999
 game.player=game.crates[0].pos+Vector2(75,0);game.player_prev=game.player
 for i in 110:game._physics_process(1.0/60)
 check(game.crates[0].hp<=0,"Player can break a crate without nearby enemies")
 game.start_game();game.enemies.clear();game.spawn_cd=999
 var frozen_time:float=game.time_alive
 key(KEY_TAB,true);key(KEY_TAB,false);game._physics_process(.5)
 check(game.state=="cabinet" and game.time_alive==frozen_time,"Gallery pauses live combat")
 key(KEY_RIGHT,true);key(KEY_RIGHT,false);key(KEY_SPACE,true);key(KEY_SPACE,false)
 check(game.cabinet_index==1 and game.cabinet_death==0,"Gallery keyboard selects enemy and starts death")
 key(KEY_ESCAPE,true);key(KEY_ESCAPE,false)
 check(game.state=="playing","Closing gallery restores previous state")
 for up in game.UPGRADES+game.MORE_UPGRADES:
  check(game.textures.has("button" if up.id=="ricochet" else up.id),"Illustrated upgrade: "+up.id)
 for k in ["button_spin","battery_loop","medkit_loop","hero_idle","boss2_slam"]:
  check(game.atlases[k].frames>20,"Animated detail loaded: "+k)
 game.turret_level=3;game.ricochets=3;game.bolt_count=6
 var all_valid=true
 for i in 50:
  game.open_upgrade()
  for u in game.choices:
   if u.id in ["turret","ricochet","bolt"]:all_valid=false
 check(all_valid,"Capped upgrades are excluded from choices")
 var file=FileAccess.open("res://captures/v02/checks.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures},"  "))
 print("CHECKS ","PASSED" if failures.is_empty() else "FAILED")
 quit(0 if failures.is_empty() else 1)
