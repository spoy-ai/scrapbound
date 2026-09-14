extends "res://game_v2.gd"

const RUN_SAVE="user://scrapbound_v03.json"
const ROUTES=[
 {"id":"saw","title":"裂甲重锯","desc":"贴身挥锯 · 击碎护甲","note":"锯击伤害 +30%，第三挥震开敌群","icon":"route_saw","color":"e8b56b"},
 {"id":"thread","title":"缝线纽扣","desc":"纽扣牵线 · 冲刺断线","note":"双纽扣连接敌人，冲刺切线连杀","icon":"route_thread","color":"74d8c3"},
 {"id":"coil","title":"线圈工坊","desc":"环绕哨兵 · 脉冲回收","note":"自带哨兵与脉冲，走位编织火力","icon":"route_coil","color":"90bfd3"}
]
const BLUEPRINTS=[
 {"id":"saw_echo","route":"saw","title":"余震锯齿","desc":"第三挥追加一道扇形震波","note":"每级提高余震伤害，最多三级","icon":"route_saw","cap":3},
 {"id":"saw_mend","route":"saw","title":"棉芯收割","desc":"挥锯拆解敌人时缝回生命","note":"每级恢复 1 点，每挥最多恢复 3 次","icon":"health","cap":3},
 {"id":"saw_open","route":"saw","title":"拆甲钉","desc":"锯击让护甲失效 3 秒","note":"随后命中暴露核心，伤害再增 20%","icon":"route_saw","cap":1},
 {"id":"thread_tension","route":"thread","title":"拉力缝线","desc":"断线伤害与扩散范围提高","note":"冲刺切线的连锁伤害每级 +30%","icon":"route_thread","cap":3},
 {"id":"thread_return","route":"thread","title":"回缝弹头","desc":"纽扣额外弹射一次","note":"在更多敌人之间编织缝线","icon":"button","cap":3},
 {"id":"thread_energy","route":"thread","title":"针脚回能","desc":"冲刺断线额外获得发条劲","note":"每断一根线，额外积攒 8 点能量","icon":"overdrive","cap":1},
 {"id":"coil_arc","route":"coil","title":"铜线共鸣","desc":"拆解带电敌人触发连锁放电","note":"每级提高放电伤害，最多三级","icon":"route_coil","cap":3},
 {"id":"coil_capacitor","route":"coil","title":"回收电容","desc":"吸收电池也能积攒发条劲","note":"每份电池补充 2 点能量","icon":"battery","cap":1},
 {"id":"coil_orbit","route":"coil","title":"分流哨兵","desc":"增加一座环绕线轴哨兵","note":"最多三座，与脉冲形成交叉火力","icon":"turret","cap":2}
]
var mode:String="endless"
var route_id:String="saw"
var energy:float=30.0
var overdrive_time:float=0.0
var perfect_dash_used=false
var next_boss_at:float=135.0
var bosses_defeated=0
var next_elite_at:float=62.0
var next_event_at:float=25.0
var event_serial=0
var field_event:Dictionary={}
var tethers:Array=[]
var chain_fx:Array=[]
var blueprints:Dictionary={}
var event_rewards=0
var damage_context:String="generic"
var chain_depth=0
var mend_this_swing=0
var forced_interact=false
var new_stats={"cuts":0,"rams":0,"overdrives":0,"events":0,"elites":0,"cores":0,"perfect_dashes":0}
var record_endless:float=0.0
var record_challenge=0
var music_director:Node
var v3_loaded=false
var attack_base_damage:float=29.0
var last_danger=0.0
var volume_drag=false
var UI_TEXT_COLOR=Color("513921")

func _ready():
 super._ready()
 var dir=DirAccess.open("res://assets/v03/art")
 if dir:
  for f in dir.get_files():
   if f.ends_with(".png") and not f.contains("atlas"):
    textures[f.get_basename()]=load("res://assets/v03/art/"+f)
 var anim_path="res://assets/v03/art/animations.json"
 if FileAccess.file_exists(anim_path):
  var meta=JSON.parse_string(FileAccess.get_file_as_string(anim_path))
  for k in meta:
   var a=meta[k].duplicate();var path:String=a.file
   if not path.begins_with("res://"):path="res://assets/"+path
   a.texture=load(path);atlases[k]=a
 music_director=load("res://systems/music_director.gd").new()
 add_child(music_director)
 if FileAccess.file_exists(RUN_SAVE):
  var saved=JSON.parse_string(FileAccess.get_file_as_string(RUN_SAVE))
  if saved is Dictionary:
   record_endless=float(saved.get("endless_seconds",0));record_challenge=int(saved.get("challenge_wins",0))
   music_director.set_music_volume(float(saved.get("music_volume",.65)))
 v3_loaded=true
 if test_mode.begins_with("v03_"):setup_v03_test()
 if test_mode.begins_with("saw_"):setup_saw_test()
 if test_mode in ["v03_demo","v03_music"]:muted=false

func start_game():
 energy=30;overdrive_time=0;perfect_dash_used=false
 next_boss_at=135;bosses_defeated=0;next_elite_at=62;next_event_at=25;event_serial=0
 field_event={};tethers.clear();chain_fx.clear();blueprints.clear();event_rewards=0
 damage_context="generic";chain_depth=0;mend_this_swing=0;forced_interact=false
 new_stats={"cuts":0,"rams":0,"overdrives":0,"events":0,"elites":0,"cores":0,"perfect_dashes":0}
 crit_chance=.14;combo_time=0;enemy_serial=0;last_danger=0
 super.start_game()
 test_stats={"attacks":0,"hits":0,"damage_taken":0,"dashes":0,"enemy_shots":0,"charges":0,"upgrades":0,"max_enemies":0}
 if route_id=="thread":bolt_count=2
 elif route_id=="coil":turret_level=1;pulse_level=1
 banner=("无尽求生" if mode=="endless" else "三分钟挑战")+" · "+route_spec().title
 tutorial_time=20

func begin_run_choice(new_mode:String):
 mode=new_mode;state="route";selected_upgrade=0

func choose_route(index:int):
 if index<0 or index>=3:return
 route_id=ROUTES[index].id
 start_game()
 play_sound("upgrade")

func route_spec()->Dictionary:
 for r in ROUTES:
  if r.id==route_id:return r
 return ROUTES[0]

func _input(event):
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_F11 or event.keycode==KEY_M:
   super._input(event);return
  if event.keycode in [KEY_MINUS,KEY_EQUAL]:
   if music_director!=null:
    music_director.set_music_volume(music_director.music_volume+(.1 if event.keycode==KEY_EQUAL else -.1));save_progress()
   return
  if state=="menu":
   if event.keycode==KEY_ENTER:begin_run_choice(mode);return
   if event.keycode in [KEY_LEFT,KEY_RIGHT,KEY_A,KEY_D]:mode="challenge" if mode=="endless" else "endless";return
  if state=="route":
   if event.keycode==KEY_ESCAPE:state="menu"
   elif event.keycode in [KEY_LEFT,KEY_A]:selected_upgrade=(selected_upgrade+2)%3
   elif event.keycode in [KEY_RIGHT,KEY_D]:selected_upgrade=(selected_upgrade+1)%3
   elif event.keycode==KEY_ENTER:choose_route(selected_upgrade)
   elif event.keycode in [KEY_1,KEY_2,KEY_3]:choose_route(event.keycode-KEY_1)
   return
  if state=="event_reward":
   if event.keycode in [KEY_LEFT,KEY_A]:selected_upgrade=(selected_upgrade+2)%3
   elif event.keycode in [KEY_RIGHT,KEY_D]:selected_upgrade=(selected_upgrade+1)%3
   elif event.keycode==KEY_ENTER:choose_upgrade(selected_upgrade)
   elif event.keycode in [KEY_1,KEY_2,KEY_3]:choose_upgrade(event.keycode-KEY_1)
   return
  if state=="playing" and event.keycode==KEY_R:activate_overdrive();return
  if state in ["dead","won"]:
   if state=="won" and event.keycode==KEY_E:continue_endless();return
   if event.keycode==KEY_ESCAPE:state="menu";return
  if state=="paused" and event.keycode==KEY_Q:state="menu";return
 if event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:volume_drag=false
  if event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
   var m=get_global_mouse_position()
   if state in ["menu","paused"] and music_slider_rect().grow(12).has_point(m):
    volume_drag=true;set_volume_at(m.x);return
   if state=="menu":
    if Rect2(110,378,210,58).has_point(m):mode="endless";return
    if Rect2(336,378,210,58).has_point(m):mode="challenge";return
    if Rect2(108,488,438,61).has_point(m):begin_run_choice(mode);return
    if Rect2(108,563,213,45).has_point(m):cabinet_from="menu";state="cabinet";return
    return
   if state in ["route","event_reward"]:
    for i in 3:
     if Rect2(178+i*317,213,290,402).has_point(m):
      if state=="route":choose_route(i)
      else:choose_upgrade(i)
      return
    if state=="route" and Rect2(540,711,200,44).has_point(m):state="menu"
    return
   if state=="paused":
    if Rect2(426,437,426,55).has_point(m):state="playing";return
    if Rect2(426,568,426,45).has_point(m):state="menu";return
    return
   if state in ["won","dead"]:
    if state=="won" and Rect2(426,454,426,55).has_point(m):continue_endless();return
    if Rect2(426,520,426,55).has_point(m):begin_run_choice(mode);return
    if Rect2(526,586,228,40).has_point(m):state="menu";return
    return
 if event is InputEventMouseMotion and volume_drag:
  set_volume_at(get_global_mouse_position().x);return
 super._input(event)

func _process(delta):
 if music_director!=null:
  var intensity=clampf(.28+time_alive/650.0+minf(enemies.size()/100.0,.3),0,1)
  if any_boss() or overdrive_time>0:intensity=1
  music_director.update_mix(state,intensity,muted,delta)
 if state in ["playing","dead","won"]:
  for f in chain_fx:f.age+=delta
  chain_fx=chain_fx.filter(func(f):return f.age<f.life)
 super._process(delta)
 if state!="playing":shake_offset=Vector2.ZERO

func _physics_process(dt):
 if state!="playing":return
 # Hold the entire combat simulation together; input and music remain responsive.
 dt=consume_hit_stop(dt)
 if dt<=0:return
 overdrive_time=maxf(0,overdrive_time-dt)
 if overdrive_time>0:
  attack_cd-=dt*.8;bolt_cd-=dt*.65;turret_cd-=dt*.65;pulse_cd-=dt*.8
 var before_dash=dash_time
 var normal_speed:float=speed
 if overdrive_time>0:speed*=1.16
 simulation_dt_prepared=true
 super._physics_process(dt)
 simulation_dt_prepared=false
 speed=normal_speed
 if state!="playing":return
 if before_dash<=0 and dash_time>0:perfect_dash_used=false
 if dash_time>0 and not perfect_dash_used:
  for e in enemies:
   if e.hp>0 and e.spawn<=0 and segment_distance(e.pos,player_prev,player)<65 and e.phase in ["charge","jump","slam_warn","shoot_warn"]:
    perfect_dash_used=true;new_stats.perfect_dashes+=1;add_energy(12)
    labels.append({"pos":player+Vector2(-22,-83),"text":"惊险闪避 +12","t":.8,"color":TEAL,"big":false});break
 update_tethers(dt)
 update_field_event(dt)
 last_danger=maxf(0,last_danger-dt)

func update_spawning(dt:float):
 if mode=="challenge":
  super.update_spawning(dt)
 else:
  var next_wave=1+int(time_alive/45)
  if next_wave!=wave:
   wave=next_wave;banner="无尽第 %d 波 · 发条继续转动"%wave;banner_time=3
   if wave%2==0:refresh_crates()
  spawn_cd-=dt
  if spawn_cd<=0:
   if enemies.size()<70:spawn_enemy(pick_spawn_type())
   spawn_cd=regular_spawn_delay()
  if time_alive>=next_boss_at and not any_boss():
   spawn_enemy(6,true)
   next_boss_at+=120
   while next_boss_at<=time_alive:next_boss_at+=120
   boss_spawned=true;banner="首领来袭 · 第 %d 次拆解"%(bosses_defeated+1);banner_time=3.5
 if time_alive>=next_elite_at:
  next_elite_at=time_alive+maxf(20,43-time_alive*.035)
  if enemies.size()<66:
   spawn_enemy(1+rng.randi_range(0,4))
   make_elite(enemies.back())

func regular_spawn_delay()->float:
 # A small density increase; health thresholds and readable warning times stay intact.
 if mode=="endless":return maxf(.19,(.82-time_alive*.0022)*.94)
 return maxf(.24,(.88-time_alive*.0035)*.94)

func check_run_end():
 if mode=="challenge":super.check_run_end()

func any_boss()->bool:
 for e in enemies:
  if e.boss and e.hp>0:return true
 return false

func spawn_enemy(kind:int,boss:bool=false):
 super.spawn_enemy(kind,boss)
 var e:Dictionary=enemies.back()
 e.exposed=0.0;e.elite=false;e.charged=0.0;e.rammed=[];e.last_phase="walk"
 e.chain_settled=false
 if mode=="endless":
  var minute=minf(35.0,time_alive/60.0)
  var scale=pow(1.18,minute)
  if boss:scale=pow(1.48,bosses_defeated)
  e.hp=FOES[e.type].hp*scale;e.max_hp=e.hp

func make_elite(e:Dictionary):
 if e.elite or e.boss:return
 e.elite=true;e.hp*=2.1;e.max_hp=e.hp;e.timer=.9
 new_stats.elites+=1

func enemy_move_speed(e:Dictionary)->float:
 var scale=minf(1.65,1+time_alive*.001)
 return FOES[e.type].speed*scale*(1.12 if e.get("elite",false) else 1.0)

func can_start_special(e:Dictionary)->bool:
 if e.type==0:return true
 var active=0
 for other in enemies:
  if other.id!=e.id and other.hp>0 and other.phase in ["warn","charge","jump_warn","jump","shoot_warn","slam_warn","slam","beetle_warn"]:active+=1
 return active<mini(6,4+int(time_alive/240))

func is_guarding(e:Dictionary,knockback:Vector2)->bool:
 return e.get("exposed",0.0)<=0 and super.is_guarding(e,knockback)

func update_enemies(dt:float):
 for e in enemies:
  e.exposed=maxf(0,e.get("exposed",0.0)-dt);e.charged=maxf(0,e.get("charged",0.0)-dt)
  e.last_phase=e.phase
 super.update_enemies(dt)
 for car in enemies:
  if car.hp<=0 or car.type!=1 and not car.boss:continue
  if car.phase=="charge" and car.last_phase!="charge":car.rammed=[]
  if car.phase!="charge" and car.last_phase!="charge":continue
  for other in enemies:
   if other.id==car.id or other.hp<=0 or other.spawn>0 or other.id in car.rammed:continue
   if segment_distance(other.pos,car.prev,car.pos)<FOES[other.type].radius+22:
    car.rammed.append(other.id);new_stats.rams+=1
    expose_core(other,3.5)
    var previous=damage_context;damage_context="collision"
    hurt_enemy(other,30+damage*.35,car.dir*350)
    damage_context=previous
    chain_fx.append({"a":car.pos,"b":other.pos,"age":0.0,"life":.3,"color":GOLD})
    fx("impact_metal",other.pos,113,car.dir.angle(),.35)
    play_sound("heavy_hit",.82)

func expose_core(e:Dictionary,duration:float):
 e.exposed=maxf(e.get("exposed",0.0),duration)
 e.frozen=maxf(e.frozen,.15)
 if e.type==3:change_phase(e,"recover",1.05)

func is_saw_contact()->bool:
 return damage_context=="saw"

func defer_saw_feedback()->bool:
 return true

func land_attack():
 if attack_landed:return
 var previous=damage_context;damage_context="saw";mend_this_swing=0
 super.land_attack()
 if route_id=="saw" and saw_swings%3==0:
  var extra=.28+.3*blueprints.get("saw_echo",0)
  fx("impact_metal",player+Vector2.from_angle(attack_angle)*70,168,attack_angle,.36)
  for e in enemies:
   var delta:Vector2=e.pos-player
   if e.hp>0 and delta.length()<reach*1.2 and absf(angle_difference(attack_angle,delta.angle()))<1.35:
    hurt_enemy(e,damage*extra,delta.normalized()*170)
 var contact_count=saw_contacts.size()+saw_crate_contacts
 if contact_count>0:finish_saw_feedback(contact_count,is_saw_heavy())
 damage_context=previous

func update_projectiles(dt:float):
 var previous=damage_context;damage_context="button"
 super.update_projectiles(dt)
 damage_context=previous

func hurt_enemy(e:Dictionary,amount:float,knockback:Vector2):
 if e.hp<=0:return
 var context=damage_context
 var was_exposed=e.get("exposed",0.0)>0
 if overdrive_time>0:amount*=1.35
 if context=="saw" and route_id=="saw":
  amount*=1.3
  if blueprints.get("saw_open",0)>0:expose_core(e,3.0)
 if was_exposed:amount*=1.2
 if route_id=="coil" and context in ["button","generic"]:e.charged=4.0
 super.hurt_enemy(e,amount,knockback)
 if e.hp>0:
  if route_id=="thread" and context=="button":link_enemy(e)
  return
 add_energy(5 if not e.boss else 28)
 if e.get("elite",false):drop_loot(e.pos,5,false);add_energy(10)
 if context=="saw" and blueprints.get("saw_mend",0)>0 and mend_this_swing<3:
  hp=minf(max_hp,hp+blueprints.saw_mend);mend_this_swing+=1
 if e.boss:
  bosses_defeated+=1
  if mode=="endless":
   boss_defeated=false
   hp=minf(max_hp,hp+20)
   banner="首领已拆解 · 战斗继续";banner_time=3.4
 if not field_event.is_empty() and field_event.get("active",false) and field_event.kind=="recycler":
  field_event.kills+=1
 if e.get("chain_settled",false):return
 e.chain_settled=true
 for t in tethers:
  if t.life>0 and (t.a==e.id or t.b==e.id):
   var other=enemy_by_id(t.b if t.a==e.id else t.a)
   t.life=0
   if other!=null and other.hp>0 and chain_depth<2:
    chain_hit(other,damage*.48,other.pos-e.pos)
 if was_exposed and context!="core_chain" and chain_depth<2:
  new_stats.cores+=1
  fx("impact_metal",e.pos,143,0,.4)
  for other in enemies:
   if other.id!=e.id and other.hp>0 and other.pos.distance_to(e.pos)<105:
    chain_hit(other,damage*.65,other.pos-e.pos,"core_chain")
 if e.get("charged",0.0)>0 and blueprints.get("coil_arc",0)>0 and context!="coil_chain" and chain_depth<2:
  var candidates=0
  for other in enemies:
   if other.id!=e.id and other.hp>0 and other.pos.distance_to(e.pos)<170 and candidates<3:
    chain_fx.append({"a":e.pos,"b":other.pos,"age":0.0,"life":.3,"color":TEAL})
    chain_hit(other,damage*(.4+.25*blueprints.coil_arc),other.pos-e.pos,"coil_chain");candidates+=1

func chain_hit(e:Dictionary,amount:float,dir:Vector2,context:String="thread_chain"):
 var old=damage_context;damage_context=context;chain_depth+=1
 hurt_enemy(e,amount,dir.normalized()*130)
 chain_depth-=1;damage_context=old

func enemy_by_id(id:int):
 for e in enemies:
  if e.id==id:return e
 return null

func link_enemy(e:Dictionary):
 for t in tethers:
  if t.life>0 and (t.a==e.id or t.b==e.id):t.life=6.0;return
 var other=null;var distance=260.0
 for candidate in enemies:
  if candidate.id==e.id or candidate.hp<=0 or candidate.spawn>0:continue
  var d=e.pos.distance_to(candidate.pos)
  if d<distance:distance=d;other=candidate
 if other==null:return
 if tethers.size()>=7:tethers.pop_front()
 tethers.append({"a":e.id,"b":other.id,"life":6.0,"phase":rng.randf()*TAU})

func update_tethers(dt:float):
 for t in tethers:
  t.life-=dt
  var a=enemy_by_id(t.a);var b=enemy_by_id(t.b)
  if a==null or b==null or a.hp<=0 or b.hp<=0:t.life=0;continue
  if a.pos.distance_to(b.pos)>390:t.life=0;continue
  if t.life>0 and dash_time>0:
   var crossing=Geometry2D.segment_intersects_segment(player_prev,player,a.pos,b.pos)
   if crossing!=null or segment_distance(player,a.pos,b.pos)<21:
    cut_tether(t)
 tethers=tethers.filter(func(t):return t.life>0)

func cut_tether(t:Dictionary):
 if t.life<=0:return
 t.life=0
 var a=enemy_by_id(t.a);var b=enemy_by_id(t.b)
 if a==null or b==null:return
 new_stats.cuts+=1
 var power=damage*(1.55+.3*blueprints.get("thread_tension",0))
 var center:Vector2=(a.pos+b.pos)*.5
 chain_fx.append({"a":a.pos,"b":b.pos,"age":0.0,"life":.4,"color":Color("fff0b0")})
 fx("pickup_burst",center,160,0,.4)
 chain_hit(a,power,a.pos-center);chain_hit(b,power,b.pos-center)
 if blueprints.get("thread_tension",0)>0:
  for other in enemies:
   if other.id!=a.id and other.id!=b.id and other.hp>0 and segment_distance(other.pos,a.pos,b.pos)<38+blueprints.thread_tension*8:
    chain_hit(other,power*.5,other.pos-center)
 add_energy(7+(8 if blueprints.get("thread_energy",0)>0 else 0))
 play_sound("heavy_hit",1.3)
 labels.append({"pos":center+Vector2(-32,-54),"text":"断线连拆","t":.8,"color":TEAL,"big":true})

func add_energy(value:float):
 if overdrive_time<=0:energy=clampf(energy+value,0,100)

func activate_overdrive()->bool:
 if state!="playing" or energy<100 or overdrive_time>0:return false
 energy=0;overdrive_time=6.0;invincible=maxf(invincible,.3);new_stats.overdrives+=1
 fx("pulse_ring",player,350,0,.6);play_sound("pulse_sound",.85)
 banner="上紧发条 · 六秒暴走";banner_time=2
 return true

func take_damage(amount:float):
 var old_hp:float=hp
 super.take_damage(amount)
 if hp<old_hp:add_energy(7);last_danger=2.0

func update_drops(dt:float):
 var before=drops.filter(func(d):return not d.heal).size()
 super.update_drops(dt)
 var after=drops.filter(func(d):return not d.heal).size()
 if blueprints.get("coil_capacitor",0)>0 and after<before:add_energy((before-after)*2)

func start_field_event(kind:String=""):
 if not field_event.is_empty() or state!="playing":return
 event_serial+=1
 if kind=="":kind="musicbox" if event_serial%2==1 else "recycler"
 var places=[Vector2(350,312),Vector2(918,528),Vector2(355,562),Vector2(917,315)]
 var pos:Vector2=places[rng.randi_range(0,3)]
 if pos.distance_to(player)<155:pos=Vector2(1280-pos.x,850-pos.y)
 field_event={"kind":kind,"pos":pos,"progress":0.0,"remaining":48.0,"active":false,"completed":false,"kills":0,"noise":1.5,"age":0.0}
 banner="发现音乐盒 · 靠近按住 E 上弦" if kind=="musicbox" else "回收委托 · 靠近按 E 接单"
 banner_time=3.5

func update_field_event(dt:float):
 if state!="playing":return
 if field_event.is_empty():
  if time_alive>=next_event_at and not any_boss():start_field_event()
  return
 var ev=field_event
 if ev.completed:return
 ev.age+=dt;ev.remaining-=dt
 var near=player.distance_to(ev.pos)<87
 var interact=near and (forced_interact or Input.is_physical_key_pressed(KEY_E))
 if ev.kind=="musicbox":
  ev.active=interact
  if interact:
   ev.progress+=dt
   ev.noise-=dt
   if ev.noise<=0:
    ev.noise=2.3
    if enemies.size()<64:
     spawn_enemy(pick_spawn_type());spawn_enemy(0)
    play_sound("pick",.8+ev.progress*.035)
  else:ev.progress=maxf(0,ev.progress-dt*.25)
  if ev.progress>=9.0:complete_field_event();return
 else:
  if interact and not ev.active:
   ev.active=true;ev.remaining=30;ev.kills=0
   spawn_enemy(1);make_elite(enemies.back())
   banner="回收开始 · 30 秒内拆解 14 个玩具";banner_time=3
   fx("pulse_ring",ev.pos,160,0,.4);play_sound("pulse_sound",.85)
  if ev.active:
   ev.noise-=dt
   if ev.noise<=0:
    ev.noise=2.0
    if enemies.size()<63:spawn_enemy(pick_spawn_type());spawn_enemy(0)
   if ev.kills>=14:complete_field_event();return
 if ev.remaining<=0:
  field_event={};next_event_at=time_alive+35
  banner="委托暂时结束 · 下次再试";banner_time=2.2

func complete_field_event():
 if field_event.is_empty() or field_event.get("completed",false):return
 field_event.completed=true;new_stats.events+=1
 event_rewards+=1
 fx("pickup_burst",field_event.pos,210,0,.7)
 play_sound("upgrade",.9)
 choices=make_choices(true)
 selected_upgrade=0;state="event_reward"

func available_upgrades()->Array:
 var pool:Array=[]
 for u in UPGRADES+MORE_UPGRADES:
  if u.id=="turret" and turret_level>=3:continue
  if u.id=="ricochet" and ricochets>=3:continue
  if u.id=="bolt" and bolt_count>=6:continue
  if u.id=="range" and reach>=225:continue
  if u.id=="speed" and interval<=.2:continue
  pool.append(u.duplicate(true))
 for u in BLUEPRINTS:
  if u.route!=route_id or blueprints.get(u.id,0)>=u.cap:continue
  if u.id=="coil_orbit" and turret_level>=3:continue
  if u.id=="thread_return" and ricochets>=3:continue
  pool.append(u.duplicate(true))
 return pool

func make_choices(rare:bool=false)->Array:
 var pool=available_upgrades()
 var result:Array=[]
 var preferred:Array=[]
 for u in pool:
  if u.get("route","")==route_id:preferred.append(u)
 if not preferred.is_empty():
  var first=preferred[rng.randi_range(0,preferred.size()-1)]
  result.append(first);pool=pool.filter(func(u):return u.id!=first.id)
 while result.size()<3 and not pool.is_empty():
  var index=rng.randi_range(0,pool.size()-1)
  result.append(pool[index]);pool.remove_at(index)
 for u in result:u["rare"]=rare
 return result

func open_upgrade():
 xp-=next_xp;level+=1;next_xp=8+level*5
 choices=make_choices();selected_upgrade=0;state="upgrade"
 test_upgrade_ready_at=world_t+1.0
 play_sound("upgrade")

func choose_upgrade(index:int):
 if state not in ["upgrade","event_reward"] or index<0 or index>=choices.size():return
 var rare=state=="event_reward"
 var u:Dictionary=choices[index]
 var key:String=u.id
 if u.has("route"):
  blueprints[key]=blueprints.get(key,0)+1
  upgrades_taken[key]=upgrades_taken.get(key,0)+1
  if key=="thread_return":ricochets=mini(3,ricochets+1)
  if key=="coil_orbit":turret_level=mini(3,turret_level+1)
  test_stats.upgrades+=1;state="playing";invincible=maxf(invincible,.8);player_prev=player
  play_sound("upgrade",1.15)
 else:super.choose_upgrade(index)
 if rare:
  hp=minf(max_hp,hp+20);add_energy(25)
  # A refined blueprint includes a guaranteed permanent damage bonus.
  damage*=1.08
  field_event={};next_event_at=time_alive+45
  banner="精制改装已装配 · 伤害 +8%，缝回 20 生命";banner_time=3
 fx("pickup_burst",player+Vector2(0,-25),170,0,.5)

func refresh_crates():
 for b in crates:
  if b.hp<=0 and b.pos.distance_to(player)>145:b.hp=55.0;b.hit=0.0

func continue_endless():
 if state!="won":return
 mode="endless";state="playing";boss_defeated=false
 bosses_defeated=maxi(1,bosses_defeated)
 next_boss_at=time_alive+100;next_event_at=time_alive+12;next_elite_at=time_alive+25
 field_event={};hp=minf(max_hp,hp+35);invincible=1.5
 banner="无尽开启 · 带着这套改装继续战斗";banner_time=4
 spawn_cd=1.5

func finish_game(won:bool):
 if state in ["dead","won"]:return
 super.finish_game(won)
 if mode=="endless":record_endless=maxf(record_endless,time_alive)
 elif won:record_challenge+=1
 save_progress()

func save_progress():
 if test_mode!="":return
 var volume=.65
 if music_director!=null:volume=music_director.music_volume
 var f=FileAccess.open(RUN_SAVE,FileAccess.WRITE)
 if f:f.store_string(JSON.stringify({"endless_seconds":record_endless,"challenge_wins":record_challenge,"music_volume":volume}))

func music_slider_rect()->Rect2:
 return Rect2(198,649,246,6) if state=="menu" else Rect2(529,531,245,6)

func set_volume_at(x:float):
 if music_director==null:return
 var rect=music_slider_rect()
 music_director.set_music_volume(clampf((x-rect.position.x)/rect.size.x,0,1))
 save_progress()

func draw_world_details():
 if not field_event.is_empty() and not field_event.completed:
  var e=field_event
  var p:Vector2=e.pos+shake_offset
  var active:bool=e.active
  var hue=TEAL if e.kind=="musicbox" else GOLD
  draw_circle(p,85,Color(hue,.055 if active else .025))
  draw_arc(p,85,0,TAU,60,Color(hue,.55 if active else .23),1.4,true)
  draw_shadow(p,39,.18)
  var key:String=e.kind+"_loop"
  if atlases.has(key):
   # Animation pivot is the stationary base, independent of bobbing mechanisms.
   animation_at(key,p-Vector2(0,160*.3203125),160,art_time*(1.6 if active else .75),0,Color.WHITE,true)
  else:image_at(e.kind,p-Vector2(0,38),98)
  var text="按住 E 上弦" if e.kind=="musicbox" else ("拆解 %d / 14"%e.kills if active else "E 接取委托")
  var width=146.0
  art_panel(Rect2(p.x-width*.5,p.y+12,width,31),"plaque")
  var tw=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
  text_at(text,Vector2(p.x-tw*.5,p.y+33),13,CREAM)
  if e.kind=="musicbox":meter(Rect2(p.x-61,p.y+49,122,5),e.progress/9.0,hue)
  elif active:meter(Rect2(p.x-61,p.y+49,122,5),e.kills/14.0,hue)
  text_at("%02d 秒"%int(ceil(e.remaining)),p+Vector2(-19,70),11,hue)
 for t in tethers:
  if t.life<=0:continue
  var a=enemy_by_id(t.a);var b=enemy_by_id(t.b)
  if a==null or b==null or a.hp<=0 or b.hp<=0:continue
  var from:Vector2=a.pos+Vector2(0,-12)+shake_offset;var to:Vector2=b.pos+Vector2(0,-12)+shake_offset
  var mid=(from+to)*.5+Vector2(0,sin(art_time*5+t.phase)*8)
  var points=PackedVector2Array()
  for i in 17:
   var f=i/16.0;points.append(from.lerp(mid,f).lerp(mid.lerp(to,f),f))
  draw_polyline(points,Color(.23,.53,.48,.5),5,true)
  draw_polyline(points,Color(.76,1,.81,.9),1.7,true)
  for i in range(1,16,3):draw_circle(points[i],2.3,Color("fbe5ac"))
 for f in chain_fx:
  var a:Vector2=f.a+Vector2(0,-17)+shake_offset;var b:Vector2=f.b+Vector2(0,-17)+shake_offset
  var color=Color(f.color,1-f.age/f.life)
  draw_line(a,b,Color(color,.2),9,true)
  var points=PackedVector2Array([a,a.lerp(b,.32)+Vector2(0,-8),a.lerp(b,.65)+Vector2(0,9),b])
  draw_polyline(points,color,2.5,true)

func draw_enemy(e:Dictionary,interp:float):
 super.draw_enemy(e,interp)
 if e.hp<=0:return
 var p:Vector2=e.prev.lerp(e.pos,interp)+shake_offset
 if e.get("elite",false):
  draw_arc(p,31,0,TAU,40,Color(1,.57,.25,.7),2,true)
  image_at("amber",p+Vector2(0,-FOES[e.type].size*.83-e.jump_height),18)
 if e.get("exposed",0)>0:
  image_at("overdrive",p+Vector2(0,-29-e.jump_height),27,art_time*4,Color(1,1,.7,.95))
  draw_arc(p,26,0,TAU,32,Color(1,.81,.34,.4),1.4,true)

func draw_player(interp:float):
 var p=player_prev.lerp(player,interp)+shake_offset
 if overdrive_time>0:
  draw_circle(p,42,Color(1,.66,.25,.1))
  for i in 3:
   var a=art_time*5+i*TAU/3
   draw_arc(p,35+i*7,a,a+1.1,20,Color(1,.8,.37,.7),2,true)
 super.draw_player(interp)

func _draw():
 super._draw()
 if not v3_loaded:return
 if state=="route":draw_route_choice()
 elif state=="event_reward":draw_upgrade()

func upgrade_icon(id:String)->String:
 for u in BLUEPRINTS:
  if u.id==id:return u.icon
 return "button" if id=="ricochet" else id

func text_center_at(s:String,x:float,y:float,width:float,size:int,color:Color):
 var w=font.get_string_size(s,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
 text_at(s,Vector2(x+(width-w)*.5,y),size,color)

func wrapped(s:String,pos:Vector2,width:float,size:int,color:Color,max_lines:int=2):
 var line="";var lines=0
 for c in s:
  if font.get_string_size(line+c,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:
   text_at(line,pos+Vector2(0,lines*(size+9)),size,color)
   lines+=1;line=""
   if lines>=max_lines:return
  line+=c
 if line!="" and lines<max_lines:text_at(line,pos+Vector2(0,lines*(size+9)),size,color)

func draw_hud():
 draw_rect(Rect2(0,0,1280,103),Color("241f17"))
 draw_line(Vector2(0,102),Vector2(1280,102),Color("92724a"),2)
 art_panel(Rect2(17,8,382,79),"plaque")
 image_at("slot",Vector2(55,46),63)
 sprite("hero",Vector2(56,78),73,1)
 text_at("补丁",Vector2(96,31),14,CREAM)
 for i in 5:
  var fill=clampf(hp/max_hp*5-i,0,1)
  image_at("heart",Vector2(117+i*40,54),31,0,Color(1,1,1,.2+.8*fill))
 text_at("%d / %d"%[hp,max_hp],Vector2(312,60),14,CREAM)
 art_panel(Rect2(459,7,360,79),"plaque")
 var t=time_alive if mode=="endless" else maxf(0,total_time-time_alive)
 var timer_text="%02d:%02d"%[int(t)/60,int(t)%60]
 centered(timer_text,47,30,CREAM)
 centered(("无尽 · 第 %d 波"%wave) if mode=="endless" else ("拆解首领 · 加时中" if time_alive>180 else "挑战 · 坚持三分钟"),72,13,TEAL if mode=="endless" else GOLD)
 art_panel(Rect2(866,8,396,79),"plaque")
 image_at("scrap",Vector2(899,43),37)
 text_at("拆解 %03d"%kills,Vector2(929,43),21,CREAM)
 text_at("Lv. %02d"%level,Vector2(1122,42),22,TEAL)
 text_at("电池 %d / %d"%[xp,next_xp],Vector2(1081,67),12,CREAM)
 meter(Rect2(29,92,1222,4),float(xp)/next_xp,TEAL)
 draw_rect(Rect2(0,737,1280,63),Color("241f17"))
 draw_line(Vector2(0,737),Vector2(1280,737),Color("92724a"),2)
 image_at("slot",Vector2(39,770),53)
 image_at(route_spec().icon,Vector2(39,770),37)
 text_at(route_spec().title,Vector2(74,765),14,CREAM)
 text_at("自动攻击",Vector2(74,785),11,GOLD)
 image_at("slot",Vector2(206,770),53)
 image_at("dash",Vector2(206,770),35)
 text_at("SPACE 冲刺",Vector2(241,765),13,TEAL if dash_cd<=0 else CREAM)
 meter(Rect2(242,779,92,5),1-dash_cd/dash_cooldown,TEAL)
 image_at("slot",Vector2(380,770),53)
 image_at("overdrive",Vector2(380,770),38,art_time*.8 if energy>=100 or overdrive_time>0 else 0)
 text_at("R 暴走中" if overdrive_time>0 else ("R 上紧发条" if energy>=100 else "积攒发条劲"),Vector2(415,765),13,GOLD if energy>=100 or overdrive_time>0 else CREAM)
 meter(Rect2(416,779,106,5),overdrive_time/6.0 if overdrive_time>0 else energy/100.0,GOLD)
 text_at("%.0f秒"%ceil(overdrive_time) if overdrive_time>0 else "%d%%"%energy,Vector2(534,784),12,GOLD)
 var equipped=upgrades_taken.keys()
 var x=626
 for key in equipped.slice(maxi(0,equipped.size()-6),equipped.size()):
  image_at("slot",Vector2(x,770),48)
  image_at(upgrade_icon(key),Vector2(x,770),31)
  text_at(str(upgrades_taken[key]),Vector2(x+13,790),10,CREAM)
  x+=48
 if equipped.size()>6:text_at("+%d"%(equipped.size()-6),Vector2(x+3,776),12,GOLD)
 text_at("E 交互   TAB 图鉴   ESC 暂停",Vector2(1030,763),11,CREAM)
 text_at("WASD 移动   M 静音   F11 全屏",Vector2(1020,786),11,Color("b7a788"))
 if banner_time>0:
  art_panel(Rect2(367,112,547,41),"plaque",Color(1,1,1,.95))
  centered(banner,139,14,CREAM)
 if tutorial_time>0 and time_alive>2:
  art_panel(Rect2(322,689,636,35),"plaque")
  centered("拆解积攒发条劲，按 R 暴走  ·  靠近事件按 E 交互  ·  精英有琥珀标记",712,12,CREAM)
 if combo>=5 and combo_time>0:text_at("%d 连拆"%combo,Vector2(1120,137),21,GOLD)
 for e in enemies:
  if e.boss and e.hp>0:
   art_panel(Rect2(426,160,428,45),"plaque")
   centered("废料吞吞"+(" · 暴走" if e.hp<e.max_hp*.5 else "")+"  /  首领 %d"%(bosses_defeated+1),179,13,RED)
   meter(Rect2(451,188,378,6),e.hp/e.max_hp,RED)
 if overdrive_time>0:
  draw_rect(Rect2(0,103,5,634),Color(1,.65,.22,.5))
  draw_rect(Rect2(1275,103,5,634),Color(1,.65,.22,.5))

func draw_music_slider():
 var rect=music_slider_rect()
 var volume=.65 if music_director==null else music_director.music_volume
 var color=Color("715738")
 text_at("背景音乐",Vector2(rect.position.x-88,rect.position.y+7),14,color)
 draw_line(rect.position,Vector2(rect.end.x,rect.position.y),Color("b3a184"),5,true)
 draw_line(rect.position,rect.position+Vector2(rect.size.x*volume,0),Color("3a8c7e"),5,true)
 draw_circle(rect.position+Vector2(rect.size.x*volume,0),7,Color("f1deae"))
 draw_arc(rect.position+Vector2(rect.size.x*volume,0),7,0,TAU,24,Color("6f5635"),1.5,true)
 text_at("%d%%"%int(volume*100),Vector2(rect.end.x+16,rect.position.y+6),13,color)

func draw_menu():
 draw_rect(Rect2(0,0,1280,800),Color(.08,.06,.035,.48))
 art_panel(Rect2(66,65,541,656),"card")
 text_at("被遗忘的玩具，也有自己的战场",Vector2(110,124),16,Color("745b37"))
 text_at("缝隙求生",Vector2(102,231),68,Color("392a1a"))
 text_at("S C R A P B O U N D",Vector2(111,270),22,Color("846640"))
 draw_line(Vector2(111,293),Vector2(549,293),Color("b39b71"),1)
 text_at("发条不停，战斗不息。",Vector2(112,334),25,Color("4c3821"))
 text_at("三条构筑  ·  场中委托  ·  连锁拆解",Vector2(112,361),15,Color("715a3c"))
 for i in 2:
  var rect=Rect2(110+i*226,378,210,58)
  var selected=mode==("endless" if i==0 else "challenge")
  if selected:panel(rect.grow(3),Color("377d70"),Color.TRANSPARENT,12)
  art_panel(rect,"plaque",Color(1.15,1.15,1.02) if selected else Color(.78,.75,.7))
  text_center_at("无尽求生" if i==0 else "三分钟挑战",rect.position.x,415,210,20,CREAM)
 text_at("持续刷怪，周期首领，挑战自己的生存纪录。" if mode=="endless" else "守住三分钟、拆解首领，也能带着构筑转入无尽。",Vector2(112,465),13,Color("715a3c"))
 art_panel(Rect2(108,488,438,61),"plaque")
 text_center_at("开始拼装   ENTER →",108,528,438,22,CREAM)
 art_panel(Rect2(108,563,213,45),"plaque")
 text_center_at("玩具图鉴  TAB",108,594,213,16,CREAM)
 var record="无尽纪录 %02d:%02d"%[int(record_endless)/60,int(record_endless)%60]
 text_at(record,Vector2(344,593),14,Color("715a3c"))
 draw_music_slider()
 text_at("拖动调节  ·  − / + 音乐音量  ·  M 总静音",Vector2(112,686),12,Color("806645"))
 draw_shadow(Vector2(951,583),116,.36)
 sprite("hero",Vector2(951,648),494,1,art_time,"hero_idle")
 image_at("overdrive",Vector2(779,436),83,sin(art_time)*.13)
 art_panel(Rect2(779,628,352,54),"plaque")
 text_center_at("补丁  /  把零件拼成新的生路",779,664,352,16,CREAM)
 centered("锯击手感更新 0.3.1  ·  原创配乐《发条不眠》",765,13,CREAM)

func choice_card(u:Dictionary,index:int,route_card:bool=false):
 var rect=Rect2(178+index*317,213,290,402)
 var selected=index==selected_upgrade or rect.has_point(get_global_mouse_position())
 if selected:rect.position.y-=7;panel(rect.grow(4),Color("438b77"),Color.TRANSPARENT,20)
 art_panel(rect,"card")
 var icon:String=u.get("icon",upgrade_icon(u.id))
 if not textures.has(icon):icon=upgrade_icon(u.id)
 var p=rect.position
 image_at("slot",p+Vector2(145,107),132)
 image_at(icon,p+Vector2(145,107),95,sin(art_time*2+index)*.035)
 text_at("0%d"%(index+1),p+Vector2(38,57),15,Color("806143"))
 var tag="核心" if route_card else ("精制" if u.get("rare",false) else ("蓝图" if u.has("route") else "改装"))
 text_at(tag,p+Vector2(215,57),13,Color("806143"))
 text_center_at(u.title,p.x,p.y+207,290,25,Color("392d20"))
 draw_line(p+Vector2(37,229),p+Vector2(253,229),Color("ad9065"),1)
 wrapped(u.desc,p+Vector2(36,263),218,14,Color("5b442a"),2)
 wrapped(u.note,p+Vector2(36,299),218,12,Color("6b5237"),2)
 art_panel(Rect2(p+Vector2(51,341),Vector2(188,40)),"plaque")
 text_center_at("按 %d  装配 →"%(index+1),p.x+51,p.y+368,188,15,CREAM)

func draw_route_choice():
 draw_rect(Rect2(0,0,1280,800),Color(.05,.04,.025,.88))
 centered("这一次，怎么拼？",141,38,CREAM)
 centered(("无尽求生" if mode=="endless" else "三分钟挑战")+" · 选择一枚核心，后续升级会提供对应蓝图",179,16,TEAL)
 for i in 3:choice_card(ROUTES[i],i,true)
 centered("所有路线均可移动、冲刺和暴走，战斗中仍能混搭通用改装。",663,14,CREAM)
 centered("1 / 2 / 3 选择   ·   ← / → 切换   ·   ENTER 确认   ·   ESC 返回",696,13,GOLD)

func draw_upgrade():
 var rare=state=="event_reward"
 draw_rect(Rect2(0,0,1280,800),Color(.04,.035,.025,.83))
 centered("旧玩具的谢礼" if rare else "捡来的，也能成为力量",141,37,CREAM)
 centered("精制蓝图 · 装配后伤害 +8%，修补 20 生命，补充 25 发条劲" if rare else ("等级 %d · %s，挑一件顺手的改装"%[level,route_spec().title]),179,15,GOLD if rare else TEAL)
 for i in choices.size():choice_card(choices[i],i)
 centered("战斗已暂停 · 数字 1 / 2 / 3 或点击卡片 · 优先提供尚未升满的本路线蓝图",668,14,CREAM)

func draw_pause():
 draw_rect(Rect2(0,0,1280,800),Color(.055,.045,.028,.81))
 art_panel(Rect2(363,192,554,449),"card")
 centered("让发条歇一会儿",270,34,Color("473420"))
 centered(("无尽求生" if mode=="endless" else "三分钟挑战")+"  /  "+route_spec().title,315,18,Color("816447"))
 centered("WASD 移动  ·  SPACE 冲刺  ·  R 暴走  ·  E 交互",355,15,Color("816447"))
 centered("TAB 图鉴  ·  M 总静音  ·  F11 全屏",383,14,Color("816447"))
 centered("已装配 %d 种改装  ·  完成 %d 次委托"%[upgrades_taken.size(),event_rewards],410,14,Color("816447"))
 art_panel(Rect2(426,437,426,55),"plaque")
 text_center_at("继续战斗  ESC",426,474,426,21,CREAM)
 draw_music_slider()
 art_panel(Rect2(426,568,426,45),"plaque")
 text_center_at("回到标题  Q",426,598,426,15,CREAM)

func draw_result():
 draw_rect(Rect2(0,0,1280,800),Color(.055,.045,.028,.83))
 art_panel(Rect2(304,172,672,488),"card")
 centered("破旧，也值得新生" if state=="won" else "线断了，再缝一次",247,35,Color("45331e"))
 centered("带着整套改装继续无尽，看看还能走多远。" if state=="won" else "利用小车撞开护甲，留一段冲刺穿过缝线。",287,16,Color("826446"))
 centered("存活 %02d:%02d   ·   拆解 %d   ·   等级 %d"%[int(time_alive)/60,int(time_alive)%60,kills,level],345,23,Color("6c4d29"))
 centered("最高连拆 %d   ·   首领 %d   ·   委托 %d"%[best_combo,bosses_defeated,event_rewards],386,16,Color("826446"))
 centered("断线 %d   ·   借力冲撞 %d   ·   发条暴走 %d"%[new_stats.cuts,new_stats.rams,new_stats.overdrives],418,15,Color("826446"))
 if state=="won":
  art_panel(Rect2(426,454,426,55),"plaque")
  text_center_at("继续无尽   E →",426,491,426,21,CREAM)
 else:centered("换一枚核心，会有另一种解法。",480,16,Color("826446"))
 art_panel(Rect2(426,520,426,55),"plaque")
 text_center_at("再来一局   ENTER",426,557,426,21,CREAM)
 centered("ESC  回到标题",613,14,Color("826446"))

func get_move_direction()->Vector2:
 if test_mode=="saw_demo":
  var target=Vector2(640,450)+Vector2(cos(time_alive*.7)*175,sin(time_alive*.7)*115)
  return (target-player).normalized()
 if test_mode=="saw_stress":return Vector2.ZERO
 if test_mode in ["v03_demo","v03_soak","v03_endless","v03_music"]:return test_movement()
 return super.get_move_direction()

func setup_saw_test():
 if test_mode=="saw_native":state="menu";return
 mode="endless";route_id="saw";start_game()
 time_alive=48;level=4;xp=0;next_xp=28;next_boss_at=999;next_event_at=999
 for i in range(1,6):introduced[i]=true
 enemies.clear()
 var count=70 if test_mode=="saw_stress" else 10
 for i in count:
  spawn_enemy(i%6)
  var e:Dictionary=enemies.back()
  var a=i*TAU/count
  e.pos=player+Vector2(cos(a),sin(a))*(98+i%4*44);e.prev=e.pos;e.spawn=0;e.timer=1.5+i*.1
 if test_mode=="saw_stress":
  hp=100000;max_hp=100000;spawn_cd=999
  for e in enemies:e.hp=100000;e.max_hp=100000
 else:muted=false

func run_saw_test():
 if test_finishing:return
 if test_mode=="saw_native":return
 if state in ["upgrade","event_reward"] and world_t>=test_upgrade_ready_at+.5:choose_upgrade(0)
 if hit_freeze>0 and is_saw_heavy() and not test_shots.has("heavy"):
  test_shots.heavy=true;capture("v04/"+test_mode+"-heavy")
 if test_elapsed>5 and not test_shots.has("action"):
  test_shots.action=true;capture("v04/"+test_mode)
 if test_elapsed>13:
  test_finishing=true
  await capture("v04/"+test_mode+"-final")
  write_test_report()
  for voice in saw_audio_pool:voice.stop()
  for voice in audio_pool:voice.stop()
  if music_director!=null and music_director.player!=null:music_director.player.stop()
  await get_tree().process_frame
  await get_tree().process_frame
  get_tree().quit()

func setup_v03_test():
 if test_mode=="v03_menu":state="menu";return
 if test_mode=="v03_native":state="menu";return
 if test_mode in ["v03_demo","v03_endless","v03_music"]:
  mode="endless";route_id="thread";start_game()
  setup_showcase();mode="endless";route_id="thread";next_boss_at=135;next_event_at=999
  blueprints={"thread_tension":1,"thread_energy":1};energy=100
  for e in enemies:e.spawn=0
  start_field_event("musicbox");field_event.pos=Vector2(854,487)
  if test_mode=="v03_endless":
   time_alive=230;next_boss_at=255;next_event_at=999;field_event={};hp=100000;max_hp=100000
 if test_mode=="v03_soak":
  Engine.time_scale=8;hp=100000;max_hp=100000

func run_test():
 if test_mode.begins_with("saw_"):run_saw_test();return
 if not test_mode.begins_with("v03_"):super.run_test();return
 if test_finishing:return
 if test_mode in ["v03_menu","v03_native"]:
  var finish_at=2.5 if test_mode=="v03_menu" else 300.0
  if test_elapsed>finish_at:
   test_finishing=true
   await capture("v03/"+test_mode)
   write_test_report();get_tree().quit()
  return
 if state in ["upgrade","event_reward"] and world_t>=test_upgrade_ready_at+1:
  choose_upgrade(0)
 if test_mode=="v03_demo" and test_elapsed>2 and not test_shots.has("overdrive"):
  if activate_overdrive():test_shots.overdrive=true
 if test_elapsed>4 and not test_shots.has("action"):
  test_shots.action=true;capture("v03/"+test_mode)
 if test_elapsed>(33 if test_mode=="v03_soak" else 13):
  test_finishing=true
  await capture("v03/"+test_mode+"-final")
  write_test_report()
  for ap in audio_pool:ap.stop()
  if music_director!=null and music_director.player!=null:music_director.player.stop()
  await get_tree().process_frame
  await get_tree().process_frame
  get_tree().quit()

func write_test_report():
 super.write_test_report()
 var path="res://captures/"+test_mode+"-report.json"
 var report=JSON.parse_string(FileAccess.get_file_as_string(path))
 report.mode=mode;report.route=route_id;report.new_stats=new_stats.duplicate();report.bosses_defeated=bosses_defeated
 report.energy=energy;report.event=field_event;report.blueprints=blueprints
 report.music_loaded=music_director!=null and music_director.loaded
 report.saw_feedback=saw_metrics
 var f=FileAccess.open(path,FileAccess.WRITE)
 f.store_string(JSON.stringify(report,"  "))
