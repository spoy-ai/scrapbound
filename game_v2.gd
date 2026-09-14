extends "res://game.gd"

const FOES = [
 {"key":"rat","name":"发条鼠","hp":34.0,"speed":91.0,"size":93.0,"radius":22.0,"material":"metal","note":"成群围追。受击后铁皮外壳散开，发条与轮子落地。"},
 {"key":"car","name":"冲撞小车","hp":74.0,"speed":68.0,"size":102.0,"radius":25.0,"material":"metal","note":"先锁定红色车道，再直线冲撞。击毁后轮胎脱落、车架塌下。"},
 {"key":"doll","name":"断线娃娃","hp":58.0,"speed":61.0,"size":111.0,"radius":23.0,"material":"cloth","note":"停步蓄力，甩出扇形缝衣针。倒下后关节松脱、头部滚落。"},
 {"key":"beetle","name":"瓶盖甲虫","hp":104.0,"speed":57.0,"size":113.0,"radius":28.0,"material":"metal","note":"正面瓶盖抵挡一半伤害。绕到侧后方，击碎外壳与齿轮。"},
 {"key":"jack","name":"弹簧盒偶","hp":70.0,"speed":56.0,"size":119.0,"radius":25.0,"material":"wood","note":"压缩弹簧后跃向标记地点。死亡时弹簧散开、木盒坍塌。"},
 {"key":"wasp","name":"线轴飞蜂","hp":43.0,"speed":104.0,"size":102.0,"radius":22.0,"material":"metal","note":"在外侧盘旋，瞄准后刺射。翅膀折落，线轴坠地并松线。"},
 {"key":"boss2","name":"废料吞吞","hp":780.0,"speed":58.0,"size":179.0,"radius":47.0,"material":"wood","note":"废料场的大家伙。铲击、冲撞交替，半血后攻击加快。"}
]
const MORE_UPGRADES = [
 {"id":"pulse","title":"线圈脉冲","desc":"每 5 秒释放一次近身电击","note":"叠加：脉冲伤害 +45%","icon":"pulse"},
 {"id":"turret","title":"线轴哨兵","desc":"召唤一个环绕发射的哨兵","note":"让纽扣从另一个角度飞来","icon":"turret"},
 {"id":"ricochet","title":"跳针纽扣","desc":"纽扣命中后额外弹射一次","note":"同时装配基础纽扣发射器","icon":"button"}
]
var corpses:Array=[]
var chips:Array=[]
var visual_effects:Array=[]
var props:Array=[]
var crates:Array=[]
var pulse_level=0
var pulse_cd=3.0
var turret_level=0
var turret_cd=.5
var ricochets=0
var crit_chance=.14
var attack_hold=0.0
var hit_freeze=0.0
var recoil=0.0
var shot_recoil=0.0
var death_elapsed=0.0
var art_time=0.0
var introduced:Dictionary={}
var cabinet_index=0
var cabinet_from="menu"
var cabinet_death=-1.0
var sample_loaded=false
var saw_swings=0
var best_combo=0
var final_art_capture=false
var styleboxes:Dictionary={}
var simulation_dt_prepared=false
var saw_contact_active=false
var saw_contacts:Dictionary={}
var saw_kills=0
var saw_crate_contacts=0
var saw_critical=false
var saw_material="metal"
var saw_impacts:Array=[]
var saw_camera_age=1.0
var saw_camera_strength=0.0
var saw_camera_dir=Vector2.RIGHT
var saw_audio_pool:Array[AudioStreamPlayer]=[]
var saw_audio_index=0
var saw_metrics={"contacts":0,"stops":0,"heavy":0,"kills":0,"max_stop":0.0}

func _ready():
 super._ready()
 var dir=DirAccess.open("res://assets/v02")
 if dir:
  for f in dir.get_files():
   if f.ends_with(".png") and not f.ends_with("-atlas.png"):
    textures[f.get_basename()]=load("res://assets/v02/"+f)
 for key in ["metal_break","wood_break","cloth_break","button_fire","button_hit","heavy_hit","pulse_sound"]:
  if ResourceLoader.exists("res://assets/v02/"+key+".wav"):sounds[key]=load("res://assets/v02/"+key+".wav")
 for key in ["saw_swing_a","saw_swing_b","saw_swing_heavy","saw_hit_metal","saw_hit_cloth","saw_finish"]:
  if ResourceLoader.exists("res://assets/v04/audio/"+key+".wav"):sounds[key]=load("res://assets/v04/audio/"+key+".wav")
 # A separate pool keeps pickup and debris sounds from cutting off saw transients.
 for i in 6:
  var voice=AudioStreamPlayer.new()
  add_child(voice);saw_audio_pool.append(voice)
 if atlases.has("hero_attack2"):atlases["hero_attack"]=atlases.hero_attack2
 for key in ["card","plaque","slot"]:
  if textures.has(key):
   var box=StyleBoxTexture.new()
   box.texture=textures[key]
   var margin=110 if key=="card" else 63
   box.set_texture_margin_all(margin)
   styleboxes[key]=box
 setup_props()
 sample_loaded=true
 if test_mode in ["showcase","stress"]:setup_showcase()
 if test_mode=="showcase":muted=false
 if test_mode=="stress":
  hp=100000;max_hp=100000;spawn_cd=999
  while enemies.size()<70:spawn_enemy(enemies.size()%6)
  for e in enemies:e.hp=100000;e.max_hp=100000;e.spawn=0
  for i in 24:corpses.append({"key":"car_death","pos":Vector2(190+i%8*125,300+i/8*120),"face":1.0,"height":153.0,"age":0.0,"life":30.0,"crate":false})

func setup_props():
 props=[
  {"key":"prop_spool","pos":Vector2(1190,178),"size":153.0},
  {"key":"prop_bricks","pos":Vector2(89,259),"size":130.0},
  {"key":"prop_bricks","pos":Vector2(1180,614),"size":139.0},
  {"key":"prop_wire","pos":Vector2(96,643),"size":105.0},
  {"key":"prop_lantern","pos":Vector2(119,193),"size":114.0},
  {"key":"prop_lantern","pos":Vector2(1165,722),"size":113.0},
  {"key":"prop_flag","pos":Vector2(1132,309),"size":94.0},
  {"key":"prop_gears","pos":Vector2(1190,410),"size":96.0},
  {"key":"prop_fabric","pos":Vector2(100,491),"size":91.0}
 ]

func start_game():
 super.start_game()
 corpses.clear();chips.clear();visual_effects.clear();crates.clear()
 introduced.clear()
 pulse_level=0;pulse_cd=3;turret_level=0;turret_cd=.5;ricochets=0
 attack_hold=0;hit_freeze=0;recoil=0;shot_recoil=0;death_elapsed=0
 saw_swings=0;best_combo=0
 simulation_dt_prepared=false;saw_contact_active=false
 saw_contacts.clear();saw_impacts.clear();saw_kills=0;saw_crate_contacts=0;saw_critical=false
 saw_camera_age=1;saw_camera_strength=0
 saw_metrics={"contacts":0,"stops":0,"heavy":0,"kills":0,"max_stop":0.0}
 for voice in saw_audio_pool:voice.stop()
 damage=29;interval=.65;reach=133
 # One readable projectile weapon from the outset; upgrades expand the build.
 bolt_count=1
 for p in [Vector2(220,255),Vector2(1060,258),Vector2(237,662),Vector2(1044,660)]:
  crates.append({"pos":p,"hp":55.0,"hit":0.0})

func _input(event):
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_TAB:
   if state=="cabinet":state=cabinet_from
   elif state in ["menu","playing","paused"]:cabinet_from=state;state="cabinet";cabinet_death=-1
   return
  if state=="cabinet":
   if event.keycode in [KEY_ESCAPE,KEY_ENTER]:state=cabinet_from
   elif event.keycode in [KEY_LEFT,KEY_A]:cabinet_index=(cabinet_index+6)%7;cabinet_death=-1
   elif event.keycode in [KEY_RIGHT,KEY_D]:cabinet_index=(cabinet_index+1)%7;cabinet_death=-1
   elif event.keycode==KEY_SPACE:cabinet_death=0
   return
 if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
  var m=get_global_mouse_position()
  if state=="upgrade":
   for i in 3:
    if Rect2(178+i*317,213,290,402).has_point(m):choose_upgrade(i);return
   return
  if state=="menu" and Rect2(102,494,300,64).has_point(m):start_game();return
  if state=="menu" and Rect2(106,574,295,45).has_point(m):cabinet_from="menu";state="cabinet";return
  if state=="cabinet":
   for i in 7:
    if Rect2(292+i*100,659,84,80).has_point(m):cabinet_index=i;cabinet_death=-1;return
 super._input(event)

func _process(delta):
 if state not in ["paused","upgrade","route","event_reward"]:
  var art_dt=delta*.18 if state=="playing" and hit_freeze>0 else delta
  art_time+=art_dt
  if state=="cabinet" and cabinet_death>=0:cabinet_death+=delta
  if state in ["playing","dead","won"]:
   update_presentation(art_dt)
   saw_camera_age+=delta
   for impact in saw_impacts:impact.age+=delta
   saw_impacts=saw_impacts.filter(func(impact):return impact.age<impact.life)
 super._process(delta)
 if state=="playing":
  var response=exp(-saw_camera_age*23.0)*cos(saw_camera_age*49.0)
  shake_offset=(shake_offset+saw_camera_dir*saw_camera_strength*response).limit_length(7.5)

func consume_hit_stop(dt:float)->float:
 var held=minf(dt,maxf(0,hit_freeze))
 hit_freeze=maxf(0,hit_freeze-held)
 if held>0:
  # Keep interpolation still during held ticks instead of replaying the last move.
  player_prev=player
  for e in enemies:e.prev=e.pos
  for p in projectiles:p.prev=p.pos
 return maxf(0,dt-held)

func _physics_process(dt):
 if state=="playing":
  if not simulation_dt_prepared:dt=consume_hit_stop(dt)
  if dt<=0:return
  recoil=maxf(0,recoil-dt*6)
  shot_recoil=maxf(0,shot_recoil-dt*7)
  var was_dashing=dash_time>0
  var old_bolt_cd=bolt_cd
  super._physics_process(dt)
  if not was_dashing and dash_time>0:
   fx("dash_trail",player-Vector2(0,17),145,last_dir.angle(),.3)
   for i in 4:material_chip(player,"shard_cloth",100,8)
  if bolt_cd>old_bolt_cd:shot_recoil=1;play_sound("button_fire",.95+rng.randf()*.1)
  if state!="playing":return
  if attack_time<=0 and attack_cd<=0:
   for b in crates:
    if b.hp>0 and b.pos.distance_to(player)<reach+24:
     begin_saw_attack(b.pos-player);break
  for i in range(1,6):
   var t=[0,12,39,53,26,65][i]
   if time_alive>t and not introduced.has(i):
    introduced[i]=true;spawn_enemy(i)
    banner="新威胁 · "+FOES[i].name;banner_time=2.2
  if pulse_level>0:
   pulse_cd-=dt
   if pulse_cd<=0:
    pulse_cd=5
    fx("pulse_ring",player,350,0,.6)
    play_sound("pulse_sound")
    for e in enemies:
     if e.hp>0 and player.distance_to(e.pos)<168:hurt_enemy(e,damage*(1.1+pulse_level*.45),(e.pos-player).normalized()*190)
  if turret_level>0:
   turret_cd-=dt
   if turret_cd<=0:
    turret_cd=.7
    for i in turret_level:
     var p=player+Vector2.from_angle(art_time+i*TAU/turret_level)*62+Vector2(0,-24)
     var target=nearest_enemy(p,650)
     if target!=null:
      add_projectile(p,(target.pos-p).normalized()*465,false,damage*.52)
      fx("pickup_burst",p,43,0,.18)
  for b in crates:b.hit=maxf(0,b.hit-dt)

func pick_spawn_type()->int:
 var roll=rng.randf()
 if time_alive>65:
  if roll>.87:return 5
  if roll>.72:return 3
  if roll>.57:return 4
  if roll>.40:return 2
  if roll>.23:return 1
 elif time_alive>39:
  if roll>.83:return 3 if time_alive>53 else 4
  if roll>.65:return 2
  if roll>.46:return 4
  if roll>.26:return 1
 elif time_alive>26:
  if roll>.77:return 4
  if roll>.5:return 1
 elif time_alive>12 and roll>.63:return 1
 return 0

func spawn_enemy(kind:int,boss:bool=false):
 if boss:kind=6
 var spec=FOES[kind]
 var pos:Vector2
 match rng.randi_range(0,3):
  0:pos=Vector2(90,rng.randf_range(233,687))
  1:pos=Vector2(1190,rng.randf_range(233,687))
  2:pos=Vector2(rng.randf_range(130,1150),224)
  _:pos=Vector2(rng.randf_range(130,1150),699)
 if pos.distance_to(player)<235:pos=Vector2(1280-player.x,850-player.y).clamp(Vector2(110,230),Vector2(1170,690))
 var life:float=spec.hp*(1+time_alive*.002)
 if boss:life=spec.hp
 enemy_serial+=1
 enemies.append({"id":enemy_serial,"type":kind,"key":spec.key,"pos":pos,"prev":pos,"hp":life,"max_hp":life,"boss":boss,"phase":"walk","timer":rng.randf_range(1.3,2.7),"dir":Vector2.RIGHT,"kb":Vector2.ZERO,"hit":0.0,"anim":rng.randf()*4,"face":1.0,"spawn":.55,"phase_t":0.0,"jump_from":pos,"jump_to":pos,"jump_height":0.0,"attack_cycle":0,"frozen":0.0})

func add_projectile(pos:Vector2,velocity:Vector2,hostile:bool,amount:float):
 projectiles.append({"pos":pos,"prev":pos,"vel":velocity,"t":4.5 if hostile else 1.65,"enemy":hostile,"damage":amount,"age":0.0,"bounces":ricochets if not hostile else 0,"hit_ids":[]})

func change_phase(e:Dictionary,phase:String,duration:float):
 e.phase=phase;e.timer=duration;e.phase_t=0

func update_enemies(dt:float):
 for e in enemies:
  if e.hp<=0:continue
  e.prev=e.pos
  e.spawn=maxf(0,e.spawn-dt)
  e.hit=maxf(0,e.hit-dt)
  e.frozen=maxf(0,e.frozen-dt)
  if e.frozen>0:continue
  e.anim+=dt;e.timer-=dt;e.phase_t+=dt
  var diff:Vector2=player-e.pos
  var direction=diff.normalized()
  if e.phase=="walk":
   if e.type==3:e.dir=e.dir.slerp(direction,minf(1,dt*1.65)).normalized()
   else:e.dir=direction
   e.face=1.0 if e.dir.x>=0 else -1.0
   var velocity=e.dir*enemy_move_speed(e)
   if e.type==2 and diff.length()<275:velocity=direction*(-28 if diff.length()<220 else 0)
   if e.type==5:
    velocity=direction*(70 if diff.length()>290 else (-45 if diff.length()<200 else 0))+direction.orthogonal()*82
    e.jump_height=16+sin(e.anim*5)*4
   var separation=Vector2.ZERO
   for other in enemies:
    if other.id==e.id or other.hp<=0:continue
    var gap:Vector2=e.pos-other.pos
    var distance=gap.length()
    var space=FOES[e.type].radius+FOES[other.type].radius
    if distance>.01 and distance<space:separation+=gap/distance*(1-distance/space)*97
   e.pos+=(velocity+separation+e.kb)*dt
   if e.timer<=0 and e.spawn<=0 and can_start_special(e):
    if e.type==1 or e.boss:
     e.dir=direction
     if e.boss and e.attack_cycle%2==1:
      change_phase(e,"slam_warn",1.0)
     else:change_phase(e,"warn",1.0 if e.boss else .87)
     e.attack_cycle+=1
    elif e.type==2 or e.type==5:
     e.dir=direction
     change_phase(e,"shoot_warn",.85 if e.type==2 else .65)
    elif e.type==4:
     e.jump_from=e.pos;e.jump_to=(player+move_dir*35).clamp(Vector2(105,230),Vector2(1175,680))
     change_phase(e,"jump_warn",.95)
    elif e.type==3 and diff.length()<125:
     e.dir=direction;change_phase(e,"beetle_warn",.65)
  elif e.phase=="warn" and e.timer<=0:
   change_phase(e,"charge",.73 if e.boss else .59)
   test_stats.charges+=1
  elif e.phase=="charge":
   e.pos+=e.dir*(525 if e.boss else 423)*dt
   if e.timer<=0 or not Rect2(84,207,1112,501).has_point(e.pos):
    change_phase(e,"recover",1.05)
    fx("impact_metal",e.pos,95 if e.boss else 65,0,.3)
    for i in 3:material_chip(e.pos,"shard_metal",85,7)
  elif e.phase=="shoot_warn" and e.timer<=0:
   var count=3 if e.type==2 else 1
   if wave>=4 and e.type==2:count=5
   for i in count:
    var angle=e.dir.angle()+(i-(count-1)*.5)*.25
    add_projectile(e.pos+Vector2(0,-28-e.jump_height),Vector2.from_angle(angle)*(210 if e.type==2 else 272),true,12)
    test_stats.enemy_shots+=1
   fx("impact_metal",e.pos+Vector2(0,-35),40,e.dir.angle(),.18)
   change_phase(e,"cast",.4)
  elif e.phase=="cast" and e.timer<=0:change_phase(e,"recover",.7)
  elif e.phase=="jump_warn" and e.timer<=0:change_phase(e,"jump",.65)
  elif e.phase=="jump":
   var progress=clampf(e.phase_t/.65,0,1)
   e.pos=e.jump_from.lerp(e.jump_to,progress)
   e.jump_height=sin(progress*PI)*95
   if e.timer<=0:
    e.jump_height=0
    fx("impact_metal",e.pos,140,0,.45)
    fx("pulse_ring",e.pos,160,0,.35)
    if e.pos.distance_to(player)<59:take_damage(20)
    shake=maxf(shake,3.5)
    change_phase(e,"recover",1.1)
  elif e.phase=="slam_warn" and e.timer<=0:
   fx("pulse_ring",e.pos,345,0,.6)
   fx("impact_metal",e.pos+e.dir*45,125,0,.45)
   play_sound("heavy_hit",.8)
   if e.pos.distance_to(player)<139:take_damage(26)
   shake=maxf(shake,5.5)
   change_phase(e,"slam",.55)
  elif e.phase=="slam" and e.timer<=0:
   var count=8 if e.hp<e.max_hp*.5 else 6
   for i in count:add_projectile(e.pos,Vector2.from_angle(i*TAU/count)*165,true,14)
   change_phase(e,"recover",1.2)
  elif e.phase=="beetle_warn" and e.timer<=0:
   if e.pos.distance_to(player)<90:take_damage(18)
   fx("impact_metal",e.pos+e.dir*35,68,0,.3)
   change_phase(e,"recover",1.1)
  elif e.phase=="recover" and e.timer<=0:
   change_phase(e,"walk",1.2 if e.boss and e.hp<e.max_hp*.5 else (2.25 if e.type==2 else 1.9))
  e.kb=e.kb.lerp(Vector2.ZERO,minf(1,dt*7))
  e.pos=e.pos.clamp(Vector2(89,241 if e.boss else 215),Vector2(1191,702))
  if e.spawn<=0 and e.phase!="jump" and e.pos.distance_to(player)<FOES[e.type].radius+7:
   take_damage(24 if e.phase=="charge" else (17 if e.boss else 13))
   if invincible>.8:e.kb-=direction*180

func begin_saw_attack(direction:Vector2):
 attack_duration=.38 if (saw_swings+1)%3==0 else .32
 super.begin_saw_attack(direction)

func is_saw_heavy()->bool:
 return (saw_swings if attack_landed else saw_swings+1)%3==0

func is_saw_contact()->bool:
 return saw_contact_active

func defer_saw_feedback()->bool:
 return false

func land_attack():
 if attack_landed:return
 attack_landed=true
 saw_swings+=1
 saw_contacts.clear();saw_kills=0;saw_crate_contacts=0;saw_critical=false;saw_material="metal"
 saw_contact_active=true
 var count=0
 var strong=saw_swings%3==0
 for e in enemies:
  if e.hp<=0 or e.spawn>0:continue
  var rel:Vector2=e.pos-player
  if rel.length()<=reach+FOES[e.type].radius*.45 and absf(angle_difference(attack_angle,rel.angle()))<2.08:
   hurt_enemy(e,damage*(1.18 if strong else 1),rel.normalized()*(370 if strong else 285))
   count+=1
 for b in crates:
  if b.hp>0 and b.pos.distance_to(player)<reach+24:
   count+=1;saw_crate_contacts+=1;saw_material="wood"
   b.hp-=damage;b.hit=.2
   fx("impact_cloth",b.pos,75,0,.3)
   if b.hp<=0:
    corpses.append({"key":"crate_break","pos":b.pos,"face":1.0,"height":141.0,"age":0.0,"life":3.3,"crate":true})
    for i in 7:material_chip(b.pos,"shard_wood",160,12)
    drop_loot(b.pos,3,false)
    if rng.randf()<.5:drop_loot(b.pos+Vector2(18,0),18,true)
    play_sound("wood_break")
 saw_contact_active=false
 if count>0 and not defer_saw_feedback():finish_saw_feedback(count,strong)

func finish_saw_feedback(count:int,strong:bool):
 var hold=.055 if strong else .035
 if saw_critical:hold+=.009
 if saw_kills>0:hold+=.009
 if count>=3:hold+=.007
 hold=minf(hold,.075)
 hit_freeze=maxf(hit_freeze,hold)
 saw_metrics.stops+=1;saw_metrics.max_stop=maxf(saw_metrics.max_stop,hold)
 if strong:saw_metrics.heavy+=1
 shake=maxf(shake,1.4 if strong else .65)
 saw_camera_dir=-Vector2.from_angle(attack_angle)
 saw_camera_age=0;saw_camera_strength=6.8 if strong or count>=3 else 4.4
 recoil=1.5 if strong else 1.0
 play_saw_audio("saw_hit_cloth" if saw_material in ["cloth","wood"] else "saw_hit_metal",.94 if strong else 1.0,-10.0)
 if strong and saw_kills>0:play_saw_audio("saw_finish",1.0,-13.0)
 if strong:
  add_saw_impact({"pos":player+Vector2(0,-12),"dir":Vector2.from_angle(attack_angle),"age":0.0,"life":.24,"heavy":true,"wave":true,"material":"metal"})

func add_saw_impact(impact:Dictionary):
 if saw_impacts.size()>=40:saw_impacts.pop_front()
 saw_impacts.append(impact)

func record_saw_contact(e:Dictionary,direction:Vector2,critical:bool,blocked:bool):
 # An echo can finish a target already touched by the main blade this swing.
 saw_critical=saw_critical or critical
 if e.hp<=0:
  saw_kills+=1;saw_metrics.kills+=1
 if saw_contacts.has(e.id):return
 saw_contacts[e.id]=true;saw_metrics.contacts+=1
 saw_material=FOES[e.type].material
 var strong=is_saw_heavy()
 e.hit_dir=direction.normalized();e.hit_weight=.4 if blocked else (1.0 if strong else .72)
 e.hit=.14
 add_saw_impact({"pos":e.pos+Vector2(0,-FOES[e.type].size*.38-e.jump_height),"dir":e.hit_dir,"age":0.0,"life":.23 if strong else .18,"heavy":strong or critical,"wave":false,"material":saw_material})

func play_saw_audio(key:String,pitch:float=1.0,volume:float=-13.0):
 if muted or not sounds.has(key) or saw_audio_pool.is_empty():return
 var voice=saw_audio_pool[saw_audio_index%saw_audio_pool.size()]
 saw_audio_index+=1;voice.stream=sounds[key];voice.pitch_scale=pitch;voice.volume_db=volume;voice.play()

func play_sound(key:String,pitch:float=1.0):
 if key=="saw" and sounds.has("saw_swing_a"):
  var heavy=(saw_swings+1)%3==0
  play_saw_audio("saw_swing_heavy" if heavy else ("saw_swing_a" if saw_swings%2==0 else "saw_swing_b"),pitch,-11.0 if heavy else -13.0)
 else:super.play_sound(key,pitch)

func _exit_tree():
 for voice in saw_audio_pool:
  voice.stop();voice.stream=null
 for voice in audio_pool:
  voice.stop();voice.stream=null

func hurt_enemy(e:Dictionary,amount:float,knockback:Vector2):
 if e.hp<=0:return
 var blocked=is_guarding(e,knockback)
 var critical=not blocked and rng.randf()<crit_chance
 if blocked:amount*=.48
 elif critical:amount*=1.8
 e.hp-=amount;e.hit=.12;e.frozen=maxf(e.frozen,.038 if not e.boss else .018)
 var saw_hit=is_saw_contact()
 if saw_hit:record_saw_contact(e,knockback,critical,blocked)
 else:e.hit_weight=0.0
 e.kb+=knockback*(.22 if e.boss else (.5 if blocked else 1.15))
 test_stats.hits+=1
 labels.append({"pos":e.pos+Vector2(rng.randf_range(-6,6),-69),"text":("格挡 " if blocked else ("暴击 " if critical else ""))+str(int(amount)),"t":.72 if critical else .5,"color":GOLD if not blocked else Color("abbcbc"),"big":critical or saw_hit and is_saw_heavy()})
 var material:String=FOES[e.type].material
 fx("impact_cloth" if material=="cloth" else "impact_metal",e.pos+Vector2(0,-24-e.jump_height),83 if critical else 58,knockback.angle(),.29)
 for i in (5 if critical else 2):material_chip(e.pos+Vector2(0,-22),"shard_cloth" if material=="cloth" else ("shard_wood" if material=="wood" else "shard_metal"),110,7)
 if e.hp<=0:
  kills+=1;combo+=1;combo_time=3.3;best_combo=maxi(best_combo,combo)
  corpses.append({"key":e.key+"_death","pos":e.pos,"face":e.face,"height":FOES[e.type].size*1.5,"age":0.0,"life":3.35,"crate":false})
  if saw_hit:
   corpses.back().vel=knockback.normalized()*(58 if e.boss else (145 if is_saw_heavy() else 105))
  if corpses.size()>24:corpses.pop_front()
  for i in (14 if e.boss else 6):material_chip(e.pos,"shard_cloth" if material=="cloth" else ("shard_wood" if material=="wood" else "shard_metal"),185,12 if e.boss else 8)
  drop_loot(e.pos,14 if e.boss else (2 if e.type>0 else 1),false)
  if rng.randf()<.045:drop_loot(e.pos+Vector2(18,0),18,true)
  play_sound(material+"_break",rng.randf_range(.88,1.14))
  if e.boss:
   boss_defeated=true;banner="废料吞吞已拆解 · 守住最后的时间";banner_time=3.4
   shake=maxf(shake,7)

func drop_loot(pos:Vector2,amount:int,heal:bool):
 drops.append({"pos":pos,"amount":amount,"heal":heal,"phase":rng.randf()*TAU,"age":0.0,"z":30.0,"vz":rng.randf_range(115,170),"vel":Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(30,95)})
 if drops.size()>90:
  for d in drops:
   if not d.heal and not heal and d.pos.distance_to(pos)<100:
    d.amount+=amount;drops.pop_back();break

func take_damage(amount:float):
 if invincible>0:return
 fx("impact_cloth",player+Vector2(0,-29),105,0,.4)
 for i in 7:material_chip(player,"shard_cloth",135,10)
 super.take_damage(amount)
 if state=="dead":
  death_elapsed=0
  corpses.append({"key":"hero_death","pos":player,"face":facing,"height":182.0,"age":0.0,"life":4.5,"crate":false})

func segment_distance(point:Vector2,a:Vector2,b:Vector2)->float:
 var line=b-a
 var t=clampf((point-a).dot(line)/maxf(line.length_squared(),.001),0,1)
 return point.distance_to(a+line*t)

func update_projectiles(dt:float):
 for p in projectiles:
  if not p.has("age"):p.age=0.0;p.bounces=ricochets;p.hit_ids=[]
  p.prev=p.pos;p.age+=dt;p.pos+=p.vel*dt;p.t-=dt
  if p.enemy:
   if segment_distance(player+Vector2(0,-15),p.prev,p.pos)<17 and invincible<=0:
    take_damage(p.damage);p.t=0
    fx("impact_cloth",p.pos,60,0,.28)
  else:
   for e in enemies:
    if e.hp<=0 or e.spawn>0 or e.id in p.hit_ids:continue
    if segment_distance(e.pos+Vector2(0,-23-e.jump_height),p.prev,p.pos)<FOES[e.type].radius+5:
     hurt_enemy(e,p.damage,p.vel.normalized()*175)
     play_sound("button_hit",rng.randf_range(.92,1.14))
     p.hit_ids.append(e.id)
     if p.bounces>0:
      var target=null;var distance=310.0
      for other in enemies:
       if other.hp>0 and other.id not in p.hit_ids and p.pos.distance_to(other.pos)<distance:target=other;distance=p.pos.distance_to(other.pos)
      if target!=null:p.vel=(target.pos+Vector2(0,-23)-p.pos).normalized()*500;p.bounces-=1;p.t=.8
      else:p.t=0
     else:p.t=0
     if p.t<=0:
      for i in 3:material_chip(p.pos,"button",95,7)
     break
  if not Rect2(20,100,1240,660).has_point(p.pos):p.t=0
 projectiles=projectiles.filter(func(p):return p.t>0)

func update_drops(dt:float):
 var keep:Array=[]
 for d in drops:
  if not d.has("age"):d.age=0.0;d.z=20.0;d.vz=100.0;d.vel=Vector2.ZERO
  d.age+=dt
  if d.z>0 or d.vz>0:
   d.vz-=520*dt;d.z+=d.vz*dt;d.pos+=d.vel*dt;d.vel*=maxf(0,1-dt*2)
   if d.z<0:
    d.z=0;d.vz=-d.vz*.32
    if d.vz<22:d.vz=0
  var dist=player.distance_to(d.pos)
  if dist<pickup_range and d.age>.15:
   d.pos=d.pos.move_toward(player,(210+(pickup_range-dist)*8)*dt)
   d.z=lerpf(d.z,15,minf(1,dt*10))
  if dist<24 and d.age>.23:
   if d.heal:hp=minf(max_hp,hp+d.amount);play_sound("pick",.7)
   else:xp+=d.amount;play_sound("pick",1.0+float(xp%5)*.08)
   fx("pickup_burst",player+Vector2(0,-20),68,0,.35)
  else:keep.append(d)
 drops=keep
 if xp>=next_xp and state=="playing":open_upgrade()

func open_upgrade():
 xp-=next_xp;level+=1;next_xp=8+level*5
 choices=[]
 var pool=UPGRADES.duplicate(true)+MORE_UPGRADES.duplicate(true)
 pool=pool.filter(func(u):return not ((u.id=="turret" and turret_level>=3) or (u.id=="ricochet" and ricochets>=3) or (u.id=="bolt" and bolt_count>=6) or (u.id=="range" and reach>=225) or (u.id=="speed" and interval<=.2)))
 for i in 3:
  var index=rng.randi_range(0,pool.size()-1);choices.append(pool[index]);pool.remove_at(index)
 selected_upgrade=0;state="upgrade";test_upgrade_ready_at=world_t+1.0
 play_sound("upgrade")

func choose_upgrade(index:int):
 if index<0 or index>=choices.size():return
 var key:String=choices[index].id
 if key=="pulse":pulse_level+=1
 elif key=="turret":turret_level=mini(3,turret_level+1)
 elif key=="ricochet":ricochets=mini(3,ricochets+1);bolt_count=maxi(bolt_count,1)
 super.choose_upgrade(index)
 fx("pickup_burst",player+Vector2(0,-30),160,0,.65)

func fx(key:String,pos:Vector2,size:float,angle:float,duration:float):
 if visual_effects.size()>=60:visual_effects.pop_front()
 visual_effects.append({"key":key,"pos":pos,"size":size,"angle":angle,"age":0.0,"life":duration})

func material_chip(pos:Vector2,key:String,force:float,size:float):
 if chips.size()>=190:return
 chips.append({"pos":pos,"key":key,"vel":Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(force*.3,force),"z":12.0,"vz":rng.randf_range(90,180),"age":0.0,"life":rng.randf_range(.8,1.7),"size":size,"angle":rng.randf()*TAU,"spin":rng.randf_range(-11,11)})

func update_presentation(dt:float):
 if state=="dead":death_elapsed+=dt
 for c in corpses:
  c.age+=dt
  if c.has("vel"):
   c.pos+=c.vel*dt;c.vel*=exp(-dt*10)
 corpses=corpses.filter(func(c):return c.age<c.life)
 for e in visual_effects:e.age+=dt
 visual_effects=visual_effects.filter(func(e):return e.age<e.life)
 for c in chips:
  c.age+=dt;c.pos+=c.vel*dt;c.vel*=maxf(0,1-dt*2.5);c.vz-=480*dt;c.z+=c.vz*dt;c.angle+=c.spin*dt
  if c.z<0:c.z=0;c.vz=-c.vz*.28;c.spin*=.5
 chips=chips.filter(func(c):return c.age<c.life)

func image_at(key:String,pos:Vector2,height:float,angle:float=0,tint:Color=Color.WHITE):
 if not textures.has(key):return
 var tex:Texture2D=textures[key]
 var width=height*tex.get_width()/float(tex.get_height())
 draw_set_transform(pos,angle)
 draw_texture_rect(tex,Rect2(-width*.5,-height*.5,width,height),false,tint)
 draw_set_transform(Vector2.ZERO)

func animation_at(key:String,pos:Vector2,size:float,progress:float,angle:float=0,tint:Color=Color.WHITE,loop:bool=false):
 if not atlases.has(key):return
 var a=atlases[key]
 var frame=int(progress*float(a.fps))%int(a.frames) if loop else clampi(int(progress*(int(a.frames)-1)),0,int(a.frames)-1)
 var cell=int(a.cell);var cols=int(a.cols)
 var region=Rect2(frame%cols*cell,int(frame/cols)*cell,cell,cell)
 draw_set_transform(pos,angle)
 draw_texture_rect_region(a.texture,Rect2(-size*.5,-size*.5,size,size),region,tint)
 draw_set_transform(Vector2.ZERO)

func art_panel(rect:Rect2,key:String="card",tint:Color=Color.WHITE):
 if styleboxes.has(key):
  var b:StyleBoxTexture=styleboxes[key]
  b.modulate_color=tint
  var scale_factor=.27*minf(1.0,rect.size.y/67.0) if key=="plaque" else .33
  draw_set_transform(rect.position,0,Vector2.ONE*scale_factor)
  draw_style_box(b,Rect2(Vector2.ZERO,rect.size/scale_factor))
  draw_set_transform(Vector2.ZERO)
 else:panel(rect,Color("766043"),Color("b89f72"),15)

func draw_death(c:Dictionary):
 var life:float=c.life
 var alpha=clampf((life-c.age)/1.05,0,1)
 var key:String=c.key
 var height:float=c.height
 if key=="rat_death" and atlases.has("rat_death2"):key="rat_death2";height*=4.0/3.0
 if key=="beetle_death" and atlases.has("beetle_death2"):key="beetle_death2";height*=4.0/3.0
 if key=="crate_break" and atlases.has("crate_break2"):key="crate_break2";height=250
 if not atlases.has(key):return
 var a=atlases[key]
 var duration=float(a.frames)/float(a.fps)
 var time=minf(c.age*1.45,duration-.05)
 var p:Vector2=c.pos+shake_offset
 var foot_margin=height*.132
 draw_shadow(p,height*.17,.12*alpha)
 sprite("",p+Vector2(0,foot_margin),height,c.face,time,key,Color(1,1,1,alpha))

func draw_prop(p:Dictionary):
 var pos:Vector2=p.pos+shake_offset
 var sway=sin(art_time*1.8+pos.x)*.028 if p.key=="prop_flag" else 0.0
 if p.key=="prop_lantern":
  var glow=.055+sin(art_time*4.2+pos.x)*.009
  draw_circle(pos-Vector2(0,40),72,Color(1,.67,.25,glow))
  draw_circle(pos-Vector2(0,40),40,Color(1,.77,.37,glow*.85))
 image_at(p.key,pos-Vector2(0,p.size*.38),p.size,sway)

func draw_enemy(e:Dictionary,interp:float):
 var spec=FOES[e.type]
 var pos:Vector2=e.prev.lerp(e.pos,interp)+shake_offset
 var height:float=spec.size
 var fly:float=e.jump_height
 draw_shadow(pos,38 if e.boss else 23,.18 if fly<10 else .1)
 var anim:String=spec.key+"_run"
 var anim_t:float=e.anim
 if e.phase in ["warn","jump_warn","beetle_warn"]:
  anim_t=0
  pos.x+=sin(art_time*45)*1.4
 if e.type==2 and e.phase in ["shoot_warn","cast"] and atlases.has("doll_cast"):
  anim="doll_cast"
  anim_t=e.phase_t if e.phase=="shoot_warn" else .85+e.phase_t
 if e.boss and e.phase in ["slam_warn","slam"] and atlases.has("boss2_slam"):
  anim="boss2_slam"
  anim_t=e.phase_t if e.phase=="slam_warn" else 1.0+e.phase_t
 var alpha=1.0-clampf(e.spawn/.6,0,.8)
 var tint=Color(1.85,1.75,1.5,alpha) if e.hit>0 else Color(1,1,1,alpha)
 var weight:float=e.get("hit_weight",0.0)*pow(clampf(e.hit/.14,0,1),2)
 var hit_dir:Vector2=e.get("hit_dir",Vector2.ZERO)
 var tilt=hit_dir.x*weight*(.04 if e.boss else .085)
 var stretch=Vector2(1+weight*.09,1-weight*.075)
 draw_set_transform(pos+hit_dir*weight*(2 if e.boss else 5),tilt,stretch)
 sprite(spec.key,Vector2(0,height*.132-fly),height,e.face,anim_t,anim,tint)
 draw_set_transform(Vector2.ZERO)
 if e.spawn>0:draw_arc(pos,34,0,TAU,30,Color(.89,.73,.43,e.spawn*.7),1.5,true)
 if e.hp<e.max_hp:
  var bar=Rect2(pos.x-22,pos.y-height*.74-fly,44,4)
  meter(bar,e.hp/e.max_hp,RED)
 if e.type==3:
  var weak=pos-e.dir*20+Vector2(0,-25)
  draw_circle(weak,7,Color(.3,1,.83,.15+.05*sin(art_time*6)))

func draw_player(interp:float):
 if state=="dead":return
 var p=player_prev.lerp(player,interp)+shake_offset
 draw_shadow(p,27)
 if dash_cd<=0:
  draw_arc(p,29,0,TAU,48,Color(.43,.84,.73,.45),1.4,true)
 for g in ghosts:sprite("hero",g.pos+Vector2(0,16)+shake_offset,124,g.face,art_time,"hero_run",Color(.46,1,.88,g.t*1.5))
 var anim="hero_run" if move_dir.length_squared()>0 or dash_time>0 else "hero_idle"
 var anim_t=art_time
 if attack_time>0:
  anim="hero_attack"
  if atlases.has(anim):anim_t=saw_pose_progress(1-attack_time/attack_duration)*(float(atlases[anim].frames)-1)/float(atlases[anim].fps)
 var tint=Color.WHITE
 if invincible>0 and int(art_time*19)%2==0:tint=Color(1.7,1.45,1.2,.88)
 var anticipation=0.0
 if attack_time>0 and not attack_landed:anticipation=sin(clampf((1-attack_time/attack_duration)/.42,0,1)*PI)*3.5
 var body=p+Vector2(0,16)-Vector2.from_angle(attack_angle)*(recoil*7+anticipation)
 sprite("hero",body,124,facing,anim_t,anim,tint)
 # The slingshot is equipped in world space, with a visible elastic recoil.
 if bolt_count>0:
  var gun=p+Vector2(31*facing,-28)
  image_at("bolt",gun-Vector2(facing*shot_recoil*5,0),39,0 if facing>0 else -.35)
 for i in turret_level:
  var pos=p+Vector2.from_angle(art_time+i*TAU/turret_level)*62+Vector2(0,-24)
  draw_shadow(pos+Vector2(0,22),17,.15)
  image_at("turret",pos,43,sin(art_time*3)*.05)

func draw_warnings():
 draw_set_transform(shake_offset)
 for e in enemies:
  if e.hp<=0:continue
  if e.phase=="warn":
   var normal:Vector2=e.dir.orthogonal()*(39 if e.boss else 25)
   var end:Vector2=e.pos+e.dir*(383 if e.boss else 249)
   draw_colored_polygon(PackedVector2Array([e.pos+normal,end+normal,end-normal,e.pos-normal]),Color(1,.31,.2,.15+sin(art_time*19)*.025))
   draw_line(e.pos+normal,end+normal,RED,1.8,true)
   draw_line(e.pos-normal,end-normal,RED,1.8,true)
   for n in range(1,5):
    var p:Vector2=e.pos+e.dir*n*49
    draw_line(p-e.dir*8+normal*.3,p,RED,2,true)
    draw_line(p-e.dir*8-normal*.3,p,RED,2,true)
   draw_arc(e.pos,45 if e.boss else 33,0,TAU,44,RED,2,true)
  elif e.phase=="jump_warn" or e.phase=="jump":
   draw_circle(e.jump_to,61,Color(1,.3,.22,.12))
   draw_arc(e.jump_to,61,0,TAU,56,RED,2,true)
   draw_arc(e.jump_to,40,0,TAU,48,Color(1,.67,.38,.7),1.3,true)
   draw_line(e.jump_to-Vector2(8,0),e.jump_to+Vector2(8,0),RED,2)
   draw_line(e.jump_to-Vector2(0,8),e.jump_to+Vector2(0,8),RED,2)
  elif e.phase=="slam_warn":
   draw_circle(e.pos,139,Color(1,.3,.21,.12))
   draw_arc(e.pos,139,0,TAU,80,RED,2.5,true)
   draw_arc(e.pos,139*clampf(e.phase_t,0,1),0,TAU,64,Color(1,.7,.4,.5),2,true)
  elif e.phase=="shoot_warn":
   var origin:Vector2=e.pos+Vector2(0,-25-e.jump_height)
   draw_line(origin,origin+e.dir*260,Color(1,.35,.24,.32),1,true)
   draw_arc(e.pos,34,0,TAU*clampf(e.phase_t/.8,0,1),32,RED,2.5,true)
  elif e.phase=="beetle_warn":draw_arc(e.pos,87,e.dir.angle()-1.1,e.dir.angle()+1.1,28,RED,3,true)
 draw_set_transform(Vector2.ZERO)

func saw_pose_progress(progress:float)->float:
 var p=clampf(progress,0,1)
 # Keep the wind-up readable, then pass the blade through contact at 42%.
 if p<.30:return lerpf(0,13.0/41.0,smoothstep(0,.30,p))
 if p<.42:return lerpf(13.0/41.0,18.0/41.0,(p-.30)/.12)
 if p<.65:return lerpf(18.0/41.0,26.0/41.0,(p-.42)/.23)
 return lerpf(26.0/41.0,1.0,smoothstep(.65,1,p))

func cut_ribbon(center:Vector2,radius:float,angle:float,span:float,width:float,color:Color):
 var points=PackedVector2Array()
 for side in [1.0,-1.0]:
  for j in 19:
   var i=j if side>0 else 18-j
   var t=i/18.0
   var r=radius*(.93+.07*t)+side*width*pow(t,.65)*.5
   points.append(center+Vector2.from_angle(angle-span+span*t)*r)
 draw_colored_polygon(points,color)

func draw_saw_sweep(pos:Vector2):
 if attack_time<=0:return
 var progress=1-attack_time/attack_duration
 if progress<.18 or progress>.86:return
 var sweep=clampf((progress-.18)/.48,0,1)
 var opacity=sin(clampf((progress-.18)/.68,0,1)*PI)
 var strong=is_saw_heavy()
 var center=pos+Vector2(0,-20)
 var angle=attack_angle-1.85+sweep*3.7
 var width=15.0 if strong else 9.5
 var radius=reach*(1.01 if strong else .95)
 animation_at("slash",center,reach*2.18,clampf((progress-.18)/.68,0,1),attack_angle,Color(1,1,.92,opacity*(.47 if strong else .28)))
 cut_ribbon(center,radius,angle,1.1,width*2.7,Color(1,.58,.19,opacity*.075))
 cut_ribbon(center,radius,angle,1.08,width,Color(1,.76,.32,opacity*.68))
 cut_ribbon(center,radius+1,angle,.95,width*.34,Color(1,.98,.83,opacity*.95))
 draw_arc(center,radius+width*.5,angle-.85,angle,28,Color(1,.94,.64,opacity*.65),1.5,true)
 if strong:draw_arc(center,radius-16,angle-.9,angle-.05,28,Color(1,.76,.36,opacity*.65),2.0,true)

func draw_saw_impacts():
 for impact in saw_impacts:
  var p:Vector2=impact.pos+shake_offset
  var t:float=clampf(impact.age/impact.life,0,1)
  var dir:Vector2=impact.dir
  var a=dir.angle()
  if impact.wave:
   var r=reach*(.48+.62*(1-pow(1-t,2)))
   draw_arc(p,r,a-1.16,a+1.16,38,Color(1,.72,.3,(1-t)*.38),4*(1-t)+.5,true)
   draw_arc(p,r+6,a-.95,a+.95,32,Color(1,.96,.77,(1-t)*.68),1.4,true)
   continue
  var scale=1.3 if impact.heavy else 1.0
  var hue=Color("efd3a0") if impact.material=="cloth" else Color("ffc767")
  var bloom=maxf(0,1-t*4)
  draw_circle(p,22*scale,Color(hue,bloom*.1))
  if bloom>0:
   var across=dir.orthogonal()
   var core=PackedVector2Array([p-dir*18*scale*bloom,p-across*4.5*scale,p+dir*26*scale*bloom,p+across*4.5*scale])
   draw_colored_polygon(core,Color(1,.98,.85,bloom*.9))
  # Deterministic sparks do not consume the combat RNG or change loot rolls.
  for i in 7:
   var spread=sin(i*7.13)*1.3
   var ray=Vector2.from_angle(a+spread)
   var travel=(12+40*t)*(1.0+.13*(i%3))*scale
   var tail=travel-(8+5*(i%2))*(1-t)
   draw_line(p+ray*maxf(0,tail),p+ray*travel,Color(hue,pow(1-t,1.7)*.9),1.3 if i%2 else 2.0,true)

func _draw():
 if not sample_loaded or font==null:return
 if textures.has("arena"):draw_texture_rect(textures.arena,Rect2(-8+shake_offset.x,68+shake_offset.y,1296,738),false)
 else:draw_rect(Rect2(0,0,1280,800),Color("74664f"))
 for p in props:draw_prop(p)
 # Fine drifting textile dust; environmental details stay outside danger colours.
 for i in 30:
  var pos=Vector2(fmod(i*181.7+art_time*(2+i%4),1190)+45,190+fmod(i*71.8+sin(art_time*.4+i)*9,510))
  draw_circle(pos,.7+(i%3)*.35,Color(.98,.87,.62,.12+.06*sin(art_time+i)))
 if state=="menu":draw_menu();return
 if state=="cabinet":draw_cabinet();return
 for c in corpses:draw_death(c)
 for b in crates:
  if b.hp>0:
   var p:Vector2=b.pos+Vector2(sin(art_time*70)*b.hit*12,0)+shake_offset
   draw_shadow(p,31,.17)
   image_at("prop_crate",p-Vector2(0,24),82,0,Color(1.5,1.4,1.1) if b.hit>0 else Color.WHITE)
 draw_world_details()
 for d in drops:
  var z:float=d.get("z",0.0)+5+sin(art_time*3+d.phase)*3
  var p:Vector2=d.pos+shake_offset
  draw_shadow(p,10,.13)
  draw_circle(p-Vector2(0,z+10),17,Color(.22,.9,.74,.075+.025*sin(art_time*5+d.phase)))
  var anim="medkit_loop" if d.heal else "battery_loop"
  if atlases.has(anim):animation_at(anim,p-Vector2(0,z+13),49 if d.heal else 47,art_time+d.phase,0,Color.WHITE,true)
  else:image_at("medkit" if d.heal else "battery",p-Vector2(0,z+13),27)
  if d.amount>=4:text_at(str(d.amount),p+Vector2(9,-9),11,CREAM)
 draw_warnings()
 var interp=Engine.get_physics_interpolation_fraction() if state=="playing" else 1.0
 var actors=enemies.filter(func(e):return e.hp>0)
 actors.append({"hero":true,"pos":player})
 actors.sort_custom(func(a,b):return a.pos.y<b.pos.y)
 for actor in actors:
  if actor.has("hero"):draw_player(interp)
  else:draw_enemy(actor,interp)
 var pp=player_prev.lerp(player,interp)+shake_offset
 draw_saw_sweep(pp)
 for p in projectiles:
  var pos:Vector2=p.get("prev",p.pos).lerp(p.pos,interp)+shake_offset
  var angle:float=p.vel.angle()
  if p.enemy:
   draw_line(pos-p.vel.normalized()*17,pos,Color(1,.32,.19,.26),2.5,true)
   image_at("needle",pos,29,angle+PI*.25)
  else:
   draw_line(pos-p.vel.normalized()*24,pos,Color(.4,.89,.75,.29),3,true)
   if atlases.has("button_spin"):animation_at("button_spin",pos,35,p.get("age",0.0)*2.5,angle,Color.WHITE,true)
   else:image_at("button",pos,23,art_time*18)
 for v in visual_effects:
  animation_at(v.key,v.pos+shake_offset,v.size,v.age/v.life,v.angle)
 draw_saw_impacts()
 for c in chips:
  var alpha=clampf((c.life-c.age)*2.5,0,1)
  image_at(c.key,c.pos+Vector2(0,-c.z)+shake_offset,c.size,c.angle,Color(1,1,1,alpha))
 for l in labels:
  var color=Color(l.color,minf(1,l.t*3))
  var size=21 if l.get("big",false) else 17
  draw_string_outline(font,l.pos+shake_offset,l.text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,3,Color(.15,.11,.065,color.a*.8))
  text_at(l.text,l.pos+shake_offset,size,color)
 if hp<max_hp*.3 and state=="playing":
  var a=.1+.025*sin(art_time*7)
  draw_rect(Rect2(0,106,16,635),Color(.8,.1,.05,a));draw_rect(Rect2(1264,106,16,635),Color(.8,.1,.05,a))
 draw_hud()
 if state=="upgrade":draw_upgrade()
 elif state=="paused":draw_pause()
 elif state=="won" or state=="dead" and death_elapsed>1.05:draw_result()

func draw_hud():
 draw_rect(Rect2(0,0,1280,103),Color("241f17"))
 draw_line(Vector2(0,102),Vector2(1280,102),Color("92724a"),2)
 art_panel(Rect2(17,8,399,79),"plaque")
 image_at("slot",Vector2(57,46),63)
 sprite("hero",Vector2(58,78),73,1,0,"",Color.WHITE)
 text_at("补丁",Vector2(97,31),14,CREAM)
 for i in 5:
  var fill=clampf((hp/max_hp*5)-i,0,1)
  image_at("heart",Vector2(122+i*42,53),32,0,Color(1,1,1,.22+.78*fill))
 text_at("%d / %d"%[hp,max_hp],Vector2(322,60),15,CREAM)
 art_panel(Rect2(496,7,289,79),"plaque")
 var overtime=time_alive>=total_time and not boss_defeated
 var remaining=maxf(0,(total_time+45 if overtime else total_time)-time_alive)
 centered("%02d:%02d"%[int(remaining)/60,int(remaining)%60],46,30,CREAM)
 centered("拆解首领 · 最后窗口" if overtime else "第 %d 波  ·  坚持到撤离"%wave,70,12,GOLD)
 art_panel(Rect2(862,8,400,79),"plaque")
 image_at("scrap",Vector2(900,44),39)
 text_at("拆解 %03d"%kills,Vector2(931,43),21,CREAM)
 text_at("Lv. %02d"%level,Vector2(1121,42),22,TEAL)
 text_at("零件 %d / %d"%[xp,next_xp],Vector2(1084,67),12,CREAM)
 meter(Rect2(29,92,1222,4),float(xp)/next_xp,TEAL)
 draw_rect(Rect2(0,737,1280,63),Color("241f17"))
 draw_line(Vector2(0,737),Vector2(1280,737),Color("92724a"),2)
 image_at("slot",Vector2(55,770),54)
 image_at("damage",Vector2(55,770),38,-.15)
 text_at("瓶盖锯",Vector2(91,765),14,CREAM)
 text_at("自动攻击",Vector2(91,785),11,GOLD)
 image_at("slot",Vector2(201,770),54)
 image_at("dash",Vector2(201,770),35)
 text_at("SPACE 冲刺",Vector2(236,765),13,TEAL if dash_cd<=0 else CREAM)
 meter(Rect2(237,779,91,5),1-dash_cd/dash_cooldown,TEAL)
 var equipped=["bolt"]
 for key in upgrades_taken:
  if key!="bolt":equipped.append(key)
 var x=389
 for key in equipped:
  image_at("slot",Vector2(x,770),51)
  image_at("button" if key=="ricochet" else key,Vector2(x,770),34)
  var count=upgrades_taken.get(key,0)+(1 if key=="bolt" else 0)
  text_at(str(count),Vector2(x+15,790),11,CREAM)
  x+=53
 text_at("WASD 移动   ESC 暂停",Vector2(1024,762),12,CREAM)
 text_at("TAB 图鉴   M 静音   F11 全屏",Vector2(1009,786),11,Color("b7a788"))
 if banner_time>0:
  art_panel(Rect2(412,112,456,42),"plaque",Color(1,1,1,.94))
  centered(banner,140,16,CREAM)
 if tutorial_time>0 and time_alive>3:
  art_panel(Rect2(390,689,500,35),"plaque",Color(1,1,1,.88))
  centered("靠近挥锯  ·  拾取电池升级  ·  冲刺穿过危险  ·  木箱可以打碎",711,12,CREAM)
 if combo>=5 and combo_time>0:
  text_at("%d 连拆"%combo,Vector2(1103,135),22,GOLD)
 for e in enemies:
  if e.boss:
   art_panel(Rect2(445,160,390,45),"plaque")
   centered("废料吞吞"+(" · 暴走" if e.hp<e.max_hp*.5 else ""),179,13,RED)
   meter(Rect2(471,188,338,6),e.hp/e.max_hp,RED)

func draw_upgrade():
 draw_rect(Rect2(0,0,1280,800),Color(.04,.035,.025,.79))
 centered("捡来的，也能成为力量",141,37,CREAM)
 centered("等级 %d  ·  选一件改装，让旧玩具焕然一新"%level,178,17,TEAL)
 for i in choices.size():
  var rect=Rect2(178+i*317,213,290,402)
  var hover=rect.has_point(get_global_mouse_position()) or i==selected_upgrade
  var lift=-7.0 if hover else 0.0
  rect.position.y+=lift
  if hover:panel(Rect2(rect.position-Vector2(3,3),rect.size+Vector2(6,6)),Color(.35,.78,.63,.5),Color.TRANSPARENT,24)
  art_panel(rect,"card")
  var choice=choices[i]
  var icon:String="button" if choice.id=="ricochet" else choice.id
  var center=rect.position+Vector2(145,107)
  image_at("slot",center,132)
  image_at(icon,center,91,sin(art_time*2+i)*.028)
  text_at("0%d"%(i+1),rect.position+Vector2(38,63),17,Color("806143"))
  var title_width=font.get_string_size(choice.title,HORIZONTAL_ALIGNMENT_LEFT,-1,26).x
  text_at(choice.title,rect.position+Vector2((290-title_width)*.5,207),26,Color("392d20"))
  draw_line(rect.position+Vector2(35,229),rect.position+Vector2(255,229),Color("ad9065"),1)
  text_at(choice.desc,rect.position+Vector2((290-font.get_string_size(choice.desc,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x)*.5,270),14,Color("5b442a"))
  text_at(choice.note,rect.position+Vector2((290-font.get_string_size(choice.note,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x)*.5,304),12,Color("827052"))
  art_panel(Rect2(rect.position+Vector2(51,329),Vector2(188,43)),"plaque")
  text_at("按 %d  装配 →"%(i+1),rect.position+Vector2(95,357),16,CREAM)
 centered("战斗已暂停  ·  数字 1 / 2 / 3 或点击卡片",668,15,CREAM)

func draw_menu():
 draw_rect(Rect2(0,0,1280,800),Color(.08,.06,.035,.48))
 art_panel(Rect2(66,82,541,616),"card")
 text_at("被遗忘的玩具，也有自己的战场",Vector2(108,147),16,Color("745b37"))
 text_at("缝隙求生",Vector2(102,255),68,Color("392a1a"))
 text_at("S C R A P B O U N D",Vector2(111,298),22,Color("846640"))
 draw_line(Vector2(111,326),Vector2(549,326),Color("b39b71"),1)
 text_at("把旧零件，拼成新的生路。",Vector2(112,372),24,Color("4c3821"))
 text_at("六种失控玩具  ·  十种改装  ·  三分钟求生",Vector2(112,414),15,Color("715a3c"))
 text_at("自动挥锯与纽扣射击，冲刺躲开致命攻击。",Vector2(112,446),15,Color("715a3c"))
 art_panel(Rect2(102,494,300,64),"plaque",Color(1.15,1.16,1.04) if Rect2(102,494,300,64).has_point(get_global_mouse_position()) else Color.WHITE)
 text_at("开始求生   ENTER →",Vector2(139,536),22,CREAM)
 art_panel(Rect2(106,574,295,45),"plaque")
 text_at("玩具图鉴  ·  TAB",Vector2(163,604),17,CREAM)
 text_at("最高拆解  %03d"%best,Vector2(111,654),14,Color("785e36"))
 draw_shadow(Vector2(950,593),116,.36)
 sprite("hero",Vector2(951,658),494,1,art_time,"hero_idle")
 art_panel(Rect2(789,636,321,47),"plaque")
 text_at("补丁  /  缝好自己，再出发",Vector2(826,667),16,CREAM)
 centered("废土玩具 · 美术与战斗升级版 0.2",765,13,CREAM)

func draw_cabinet():
 draw_rect(Rect2(0,0,1280,800),Color(.07,.055,.035,.72))
 art_panel(Rect2(65,65,1150,677),"card")
 text_at("失控玩具图鉴",Vector2(125,148),34,Color("46321d"))
 text_at("← / → 切换   ·   SPACE 播放死亡动作   ·   ESC 返回",Vector2(125,184),15,Color("806445"))
 var spec=FOES[cabinet_index]
 var p=Vector2(369,588)
 draw_shadow(p,110,.16)
 if cabinet_death<0:
  sprite(spec.key,p+Vector2(0,57),425,1,art_time,spec.key+"_run")
 else:
  var key:String=spec.key+"_death"
  var size=638.0
  if cabinet_index==0 and atlases.has("rat_death2"):key="rat_death2";size=850
  if cabinet_index==3 and atlases.has("beetle_death2"):key="beetle_death2";size=850
  if atlases.has(key):
   var a=atlases[key];var time=minf(cabinet_death,float(a.frames)/float(a.fps)-.05)
   sprite("",p+Vector2(0,size*.132),size,1,time,key)
 text_at("0%d / %s"%[cabinet_index+1,spec.name],Vector2(674,296),31,Color("42301c"))
 var note:String=spec.note
 for i in range(0,note.length(),19):text_at(note.substr(i,19),Vector2(676,346+i/19*32),17,Color("725735"))
 text_at("材质："+{"metal":"铁皮与黄铜","wood":"旧木头与弹簧","cloth":"布料与松动关节"}[spec.material],Vector2(676,469),17,Color("725735"))
 art_panel(Rect2(678,512,357,52),"plaque")
 text_at("空格  ·  看它如何散架",Vector2(748,547),18,CREAM)
 for i in 7:
  var center=Vector2(334+i*100,700)
  image_at("slot",center,79,0,Color(1.3,1.2,1) if i==cabinet_index else Color.WHITE)
  sprite(FOES[i].key,center+Vector2(0,35),81,1)

func draw_pause():
 draw_rect(Rect2(0,0,1280,800),Color(.055,.045,.028,.77))
 art_panel(Rect2(382,242,516,355),"card")
 centered("让发条歇一会儿",326,33,Color("473420"))
 centered("WASD 移动  ·  SPACE 冲刺  ·  自动攻击",379,16,Color("816447"))
 centered("TAB 可查看每个玩具的动作与死亡过程",414,14,Color("816447"))
 art_panel(Rect2(490,451,300,60),"plaque")
 centered("继续战斗  ·  ESC",490,22,CREAM)
 centered("声音："+("关闭" if muted else "开启")+"  ·  M 切换",549,14,Color("816447"))

func draw_result():
 draw_rect(Rect2(0,0,1280,800),Color(.055,.045,.028,.77))
 art_panel(Rect2(314,204,652,452),"card")
 centered("破旧，也值得新生" if state=="won" else "线断了，再缝一次",290,37,Color("45331e"))
 centered("守住了这块小小的领地" if state=="won" else "绕开甲虫正面，留意冲撞车道与落点",338,16,Color("826446"))
 centered("存活 %02d:%02d   ·   拆解 %d   ·   等级 %d"%[int(time_alive)/60,int(time_alive)%60,kills,level],404,22,Color("6c4d29"))
 centered("最高连拆 %d"%best_combo,448,16,Color("826446"))
 art_panel(Rect2(490,498,300,60),"plaque")
 centered("再来一局   ENTER",538,22,CREAM)
 centered("旧零件，下一次还能有新搭配。",603,14,Color("826446"))

func setup_showcase():
 time_alive=68;wave=2;level=5;xp=12;next_xp=38;hp=86;damage=39;reach=142
 bolt_count=2;ricochets=1;pulse_level=1;turret_level=1
 upgrades_taken={"bolt":1,"ricochet":1,"pulse":1,"turret":1}
 introduced={1:true,2:true,3:true,4:true,5:true}
 enemies.clear();player=Vector2(667,440);player_prev=player
 for i in 20:
  spawn_enemy(i%6)
  var e=enemies.back()
  var angle=i*TAU/20
  e.pos=player+Vector2(cos(angle)*rng.randf_range(150,350),sin(angle)*rng.randf_range(100,230));e.prev=e.pos;e.spawn=0
 for i in 8:drop_loot(Vector2(rng.randf_range(340,860),rng.randf_range(360,570)),1,false)
 banner="废料场 · 战斗实机演示";banner_time=3

func run_test():
 if test_mode in ["showcase","stress"]:
  if test_finishing:return
  if state=="upgrade" and world_t>=test_upgrade_ready_at:choose_upgrade(0)
  if test_elapsed>3.5 and not test_shots.has("art"):
   test_shots.art=true;capture("v02/"+test_mode)
  if test_elapsed>8:
   test_finishing=true
   await capture("v02/"+test_mode+"-final")
   write_test_report()
   for ap in audio_pool:ap.stop()
   await get_tree().process_frame
   await get_tree().process_frame
   get_tree().quit()
  return
 super.run_test()

func enemy_move_speed(e:Dictionary)->float:
 return FOES[e.type].speed*(1+time_alive*.0012)

func can_start_special(_e:Dictionary)->bool:
 return true

func is_guarding(e:Dictionary,knockback:Vector2)->bool:
 return e.type==3 and (-knockback.normalized()).dot(e.dir)>.35 and e.phase!="recover"

func draw_world_details():
 pass
