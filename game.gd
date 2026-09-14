extends Node2D

const SAVE_PATH = "user://scrapbound_save.json"
const ARENA = Rect2(62, 170, 1156, 550)
const CREAM = Color("f0e2c5")
const TEAL = Color("67d7c5")
const GOLD = Color("efbd62")
const RED = Color("ff8171")
const INK = Color("18272b")
const UPGRADES = [
 {"id":"damage", "title":"锯齿加固", "desc":"瓶盖锯伤害 +35%", "note":"让每一次命中都更有分量", "icon":"✦"},
 {"id":"speed", "title":"上紧发条", "desc":"攻击速度 +22%", "note":"连绵不断的金属风暴", "icon":"»"},
 {"id":"range", "title":"加长握柄", "desc":"挥锯范围 +18%", "note":"在敌群靠近之前先出手", "icon":"＋"},
 {"id":"bolt", "title":"纽扣弹弓", "desc":"增加一枚自动发射的纽扣", "note":"为近身武器补上远程火力", "icon":"◎"},
 {"id":"health", "title":"重新缝合", "desc":"生命上限 +20，恢复 35", "note":"破了可以补，别轻易认输", "icon":"＋"},
 {"id":"dash", "title":"弹簧鞋底", "desc":"冲刺冷却 -18%，移速 +5%", "note":"留给危险一个背影", "icon":"»"},
 {"id":"magnet", "title":"口袋磁铁", "desc":"拾取范围 +55%，恢复 15", "note":"把散落的机会吸到身边", "icon":"◎"}
]
var font: Font
var textures: Dictionary = {}
var atlases: Dictionary = {}
var sounds: Dictionary = {}
var audio_pool: Array[AudioStreamPlayer] = []
var audio_index = 0
var muted = false
var state = "menu"
var time_alive = 0.0
var total_time = 180.0
var world_t = 0.0
var player = Vector2(640,430)
var player_prev = player
var move_dir = Vector2.ZERO
var last_dir = Vector2.RIGHT
var facing = 1.0
var hp:float = 100.0
var max_hp:float = 100.0
var invincible = 0.0
var dash_time = 0.0
var dash_cd = 0.0
var dash_cooldown = 1.6
var dash_buffer = 0.0
var speed = 218.0
var damage = 24.0
var reach = 126.0
var interval = .72
var attack_cd = .4
var attack_time = 0.0
var attack_angle = 0.0
var attack_landed = false
var attack_duration = .34
var bolt_count = 0
var bolt_cd = 0.0
var pickup_range = 76.0
var level = 1
var xp = 0
var next_xp = 9
var kills = 0
var combo = 0
var combo_time = 0.0
var best = 0
var enemy_serial = 0
var enemies: Array = []
var drops: Array = []
var projectiles: Array = []
var particles: Array = []
var labels: Array = []
var ghosts: Array = []
var spawn_cd = 1.0
var boss_spawned = false
var boss_defeated = false
var wave = 1
var banner = "第一波 · 发条苏醒"
var banner_time = 3.0
var shake = 0.0
var shake_offset = Vector2.ZERO
var choices: Array = []
var selected_upgrade = 0
var upgrades_taken: Dictionary = {}
var tutorial_time = 14.0
var test_mode = ""
var test_elapsed = 0.0
var test_shots: Dictionary = {}
var test_stats = {"attacks":0,"hits":0,"damage_taken":0,"dashes":0,"enemy_shots":0,"charges":0,"upgrades":0,"max_enemies":0}
var test_frames: Array = []
var test_finishing = false
var test_upgrade_ready_at = 0.0
var rng = RandomNumberGenerator.new()

func _ready():
 rng.randomize()
 font = FontVariation.new()
 font.base_font = load("res://assets/NotoSansSC.ttf")
 font.variation_opentype = {0x77676874: 520}
 for key in ["hero","rat","car","doll","arena"]:
  var path = "res://assets/"+key+".png"
  if ResourceLoader.exists(path): textures[key] = load(path)
 var meta_path = "res://assets/animations.json"
 if FileAccess.file_exists(meta_path):
  var meta = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
  for key in meta:
   var item = meta[key]
   item["texture"] = load("res://assets/"+item["file"])
   atlases[key] = item
 for key in ["hit","saw","dash","pick","hurt","upgrade","end"]:
  if ResourceLoader.exists("res://assets/"+key+".wav"): sounds[key] = load("res://assets/"+key+".wav")
 for i in 12:
  var ap = AudioStreamPlayer.new()
  ap.volume_db = -15
  add_child(ap)
  audio_pool.append(ap)
 if FileAccess.file_exists(SAVE_PATH):
  var saved = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
  if saved is Dictionary: best = int(saved.get("best",0))
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--test="): test_mode = arg.trim_prefix("--test=")
 if test_mode != "":
  muted = true
  rng.seed = 404
  if test_mode not in ["menu","native"]: start_game()
  if test_mode == "soak": Engine.time_scale = 8.0
 queue_redraw()

func start_game():
 state = "playing"
 time_alive = 0
 player = Vector2(640,430)
 player_prev = player
 hp = 100
 max_hp = 100
 invincible = 0
 dash_time = 0
 dash_cd = 0
 dash_buffer = 0
 speed = 218
 damage = 24
 reach = 126
 interval = .72
 attack_cd = .35
 attack_time = 0
 attack_landed = false
 bolt_count = 0
 bolt_cd = 0
 pickup_range = 76
 dash_cooldown = 1.6
 xp = 0
 level = 1
 next_xp = 9
 kills = 0
 combo = 0
 enemies.clear()
 projectiles.clear()
 drops.clear()
 particles.clear()
 labels.clear()
 ghosts.clear()
 upgrades_taken.clear()
 spawn_cd = .45
 boss_spawned = false
 boss_defeated = false
 wave = 1
 banner = "第一波 · 发条苏醒"
 banner_time = 3
 tutorial_time = 14
 shake = 0
 for i in 5: spawn_enemy(0)

func _input(event):
 if test_mode=="native" and event is InputEventKey:print("NATIVE_KEY ",event.as_text()," code=",event.keycode," physical=",event.physical_keycode," pressed=",event.pressed)
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode == KEY_M: muted = not muted
  if event.keycode == KEY_F11:
   DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
  if event.keycode == KEY_ESCAPE:
   if state == "playing": state = "paused"
   elif state == "paused": state = "playing"
   elif state == "upgrade": pass
  if state == "menu" and event.keycode == KEY_ENTER: start_game()
  elif state in ["dead","won"] and event.keycode in [KEY_ENTER,KEY_R]: start_game()
  elif state == "playing" and event.keycode == KEY_SPACE: dash_buffer = .14
  elif state == "upgrade":
   if event.keycode in [KEY_1,KEY_2,KEY_3]: choose_upgrade(event.keycode-KEY_1)
   elif event.keycode in [KEY_LEFT,KEY_A]: selected_upgrade = (selected_upgrade+2)%3
   elif event.keycode in [KEY_RIGHT,KEY_D]: selected_upgrade = (selected_upgrade+1)%3
   elif event.keycode == KEY_ENTER: choose_upgrade(selected_upgrade)
 if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
  var m = get_global_mouse_position()
  if state == "menu" and Rect2(102,494,300,64).has_point(m): start_game()
  elif state == "paused" and Rect2(490,451,300,60).has_point(m): state = "playing"
  elif state in ["dead","won"] and Rect2(490,498,300,60).has_point(m): start_game()
  elif state == "upgrade":
   for i in 3:
    if Rect2(175+i*320,300,290,260).has_point(m): choose_upgrade(i)

func _process(delta):
 world_t += delta
 if test_mode != "":
  test_elapsed += delta / Engine.time_scale
  test_frames.append(delta / Engine.time_scale * 1000.0)
  run_test()
 shake_offset = Vector2(sin(world_t*149),cos(world_t*173))*shake
 queue_redraw()

func _physics_process(dt):
 if state != "playing": return
 player_prev = player
 time_alive += dt
 tutorial_time -= dt
 banner_time -= dt
 invincible = maxf(0,invincible-dt)
 dash_cd = maxf(0,dash_cd-dt)
 dash_time = maxf(0,dash_time-dt)
 dash_buffer = maxf(0,dash_buffer-dt)
 shake = maxf(0,shake-dt*24)
 combo_time -= dt
 if combo_time <= 0: combo = 0
 move_dir = get_move_direction()
 if move_dir.length_squared() > 0:
  last_dir = move_dir
  if absf(move_dir.x) > .1: facing = signf(move_dir.x)
 if dash_buffer > 0 and dash_cd <= 0:
  dash_time = .19
  dash_cd = dash_cooldown
  invincible = maxf(invincible,.28)
  dash_buffer = 0
  test_stats.dashes += 1
  play_sound("dash")
 var velocity = last_dir * 760 if dash_time > 0 else move_dir * speed
 player += velocity * dt
 player.x = clampf(player.x,ARENA.position.x+18,ARENA.end.x-18)
 player.y = clampf(player.y,ARENA.position.y+35,ARENA.end.y-12)
 if dash_time > 0:
  ghosts.append({"pos":player,"t":.23,"face":facing})
 for g in ghosts: g.t -= dt
 ghosts = ghosts.filter(func(g):return g.t>0)
 attack_cd -= dt
 if attack_time > 0:
  attack_time = maxf(0,attack_time-dt)
  if not attack_landed and attack_time <= attack_duration*.58: land_attack()
 elif attack_cd <= 0:
  var target = nearest_enemy(player,reach+45)
  if target != null:
   begin_saw_attack(target.pos-player)
 if bolt_count > 0:
  bolt_cd -= dt
  if bolt_cd <= 0:
   var target = nearest_enemy(player,720)
   if target != null:
    for i in bolt_count:
     var a = (target.pos-player).angle()+(i-(bolt_count-1)*.5)*.14
     projectiles.append({"pos":player+Vector2(0,-20),"vel":Vector2.from_angle(a)*520,"t":1.6,"enemy":false,"damage":damage*.7})
    bolt_cd = .85
 update_spawning(dt)
 update_enemies(dt)
 if state=="dead":return
 update_projectiles(dt)
 if state=="dead":return
 update_drops(dt)
 update_effects(dt)
 enemies = enemies.filter(func(e):return e.hp>0)
 test_stats.max_enemies = maxi(test_stats.max_enemies,enemies.size())
 check_run_end()

func update_spawning(dt:float):
 var new_wave = mini(4,1+int(time_alive/45))
 if new_wave != wave:
  wave = new_wave
  banner = ["","第一波 · 发条苏醒","第二波 · 铁轮来袭","第三波 · 断线舞会","终局 · 废铁暴走"][wave]
  banner_time = 3
  play_sound("upgrade",.8)
 spawn_cd -= dt
 if spawn_cd <= 0 and time_alive < total_time:
  var type = pick_spawn_type()
  if enemies.size()<70: spawn_enemy(type)
  spawn_cd = regular_spawn_delay()
 if time_alive >= 135 and not boss_spawned:
  boss_spawned = true
  spawn_enemy(1,true)
  banner = "警告 · 废料吞吞"
  banner_time = 4

func regular_spawn_delay()->float:
 return maxf(.24,.88-time_alive*.0035)

func begin_saw_attack(direction:Vector2):
 attack_angle=direction.angle()
 facing=1.0 if direction.x>=0 else -1.0
 attack_time=attack_duration
 attack_cd=interval
 attack_landed=false
 test_stats.attacks+=1
 play_sound("saw",.94+randf()*.1)

func check_run_end():
 if time_alive>=total_time and boss_defeated: finish_game(true)
 elif time_alive>=total_time+45: finish_game(false)

func spawn_enemy(kind:int,boss:bool=false):
 var pos:Vector2
 match rng.randi_range(0,3):
  0: pos=Vector2(74,rng.randf_range(205,700))
  1: pos=Vector2(1206,rng.randf_range(205,700))
  2: pos=Vector2(rng.randf_range(80,1200),205)
  _: pos=Vector2(rng.randf_range(80,1200),712)
 if pos.distance_to(player)<230: pos=Vector2(1280-player.x,850-player.y).clamp(Vector2(80,205),Vector2(1200,705))
 enemy_serial += 1
 var life = [32.0,72.0,52.0][kind]*(1+time_alive*.003)
 if boss: life=650
 enemies.append({"id":enemy_serial,"type":kind,"pos":pos,"prev":pos,"hp":life,"max_hp":life,"boss":boss,"phase":"walk","timer":rng.randf_range(1.2,2.5),"dir":Vector2.ZERO,"kb":Vector2.ZERO,"hit":0.0,"anim":rng.randf()*4,"face":1.0})

func nearest_enemy(origin:Vector2,dist:float):
 var result = null
 for e in enemies:
  if e.hp<=0: continue
  var d = origin.distance_to(e.pos)
  if d<dist: dist=d;result=e
 return result

func land_attack():
 attack_landed = true
 var struck = false
 for e in enemies:
  if e.hp<=0: continue
  var rel:Vector2 = e.pos-player
  if rel.length()<=reach+(24 if e.boss else 10) and absf(angle_difference(attack_angle,rel.angle()))<2.1:
   hurt_enemy(e,damage,rel.normalized()*290)
   struck = true
 if struck:
  shake = maxf(shake,2.8)
  play_sound("hit",randf_range(.9,1.15))

func hurt_enemy(e:Dictionary,amount:float,knockback:Vector2):
 e.hp -= amount
 e.hit = .13
 e.kb += knockback*(.3 if e.boss else 1)
 test_stats.hits += 1
 labels.append({"pos":e.pos+Vector2(rng.randf_range(-8,8),-46),"text":str(int(amount)),"t":.55,"color":GOLD})
 for i in 4: emit_particle(e.pos+Vector2(0,-20),GOLD if i%2 else CREAM,80,5)
 if e.hp<=0:
  kills += 1
  combo += 1
  combo_time = 2.8
  for i in 9: emit_particle(e.pos+Vector2(0,-18),[Color("858f8c"),GOLD,Color("b6a383")][i%3],160,6)
  drops.append({"pos":e.pos,"amount":12 if e.boss else (2 if e.type else 1),"heal":false,"phase":rng.randf()*6})
  if rng.randf()<.035: drops.append({"pos":e.pos+Vector2(15,0),"amount":15,"heal":true,"phase":0})
  if e.boss:
   boss_defeated = true
   banner = "拖车已拆解 · 坚持到撤离"
   banner_time = 3
  if drops.size()>120:
   drops[0].amount += drops[1].amount
   drops.remove_at(1)

func update_enemies(dt:float):
 for e in enemies:
  if e.hp<=0: continue
  e.prev = e.pos
  e.anim += dt
  e.hit = maxf(0,e.hit-dt)
  e.timer -= dt
  var to_player:Vector2 = player-e.pos
  var direction = to_player.normalized()
  if e.phase=="walk":
   e.face = 1.0 if direction.x>=0 else -1.0
   var velocity = direction*[88.0,68.0,62.0][e.type]*(1+time_alive*.0015)
   if e.type==2 and to_player.length()<280: velocity = direction*(-30 if to_player.length()<215 else 0)
   var sep=Vector2.ZERO
   for other in enemies:
    if other.id==e.id or other.hp<=0: continue
    var diff:Vector2=e.pos-other.pos
    var dist=diff.length_squared()
    if dist>0.01 and dist<1156: sep+=diff.normalized()*(1-sqrt(dist)/34)*85
   e.pos+=(velocity+sep+e.kb)*dt
   if e.type==1 and e.timer<=0 and to_player.length()<650:
    e.phase="warn"
    e.timer=1.05 if e.boss else .82
    e.dir=direction
   elif e.type==2 and e.timer<=0:
    e.phase="shoot_warn"
    e.timer=.8
    e.dir=direction
  elif e.phase=="warn":
   if e.timer<=0:
    e.phase="charge"
    e.timer=.8 if e.boss else .62
    test_stats.charges+=1
  elif e.phase=="charge":
   e.pos+=e.dir*(570 if e.boss else 440)*dt
   if e.timer<=0 or not ARENA.has_point(e.pos):
    e.phase="recover"
    e.timer=.85
    for i in 6: emit_particle(e.pos,GOLD,100,4)
  elif e.phase=="shoot_warn":
   if e.timer<=0:
    for j in (5 if wave>=4 else 3):
     var a=e.dir.angle()+(j-(2 if wave>=4 else 1))*.24
     projectiles.append({"pos":e.pos+Vector2(0,-15),"vel":Vector2.from_angle(a)*185,"t":5.0,"enemy":true,"damage":14})
     test_stats.enemy_shots+=1
    e.phase="recover"
    e.timer=.5
  elif e.phase=="recover" and e.timer<=0:
   e.phase="walk"
   e.timer=1.9 if e.type==1 else 2.4
  e.kb=e.kb.lerp(Vector2.ZERO,minf(1,dt*9))
  e.pos=e.pos.clamp(ARENA.position+Vector2(8,58 if e.boss else 20),ARENA.end-Vector2(8,8))
  var radius=44 if e.boss else 24
  if e.pos.distance_to(player)<radius and invincible<=0:
   take_damage(25 if e.phase=="charge" else 14)
   e.kb=-direction*250

func take_damage(amount:float):
 if invincible>0: return
 hp-=amount
 test_stats.damage_taken+=int(amount)
 invincible=.85
 shake=7
 play_sound("hurt")
 for i in 12: emit_particle(player+Vector2(0,-20),CREAM,180,5)
 labels.append({"pos":player+Vector2(0,-65),"text":"−"+str(int(amount)),"t":.8,"color":RED})
 if hp<=0: hp=0;finish_game(false)

func update_projectiles(dt:float):
 for p in projectiles:
  p.pos+=p.vel*dt
  p.t-=dt
  if p.enemy:
   if p.pos.distance_to(player+Vector2(0,-12))<19 and invincible<=0:
    take_damage(p.damage)
    p.t=0
  else:
   for e in enemies:
    if e.hp>0 and p.pos.distance_to(e.pos+Vector2(0,-16))<(36 if e.boss else 24):
     hurt_enemy(e,p.damage,p.vel.normalized()*120)
     p.t=0
     break
  if not Rect2(-50,60,1380,750).has_point(p.pos):p.t=0
 projectiles=projectiles.filter(func(p):return p.t>0)

func update_drops(dt:float):
 var keep:Array=[]
 for d in drops:
  var dist=player.distance_to(d.pos)
  if dist<pickup_range: d.pos=d.pos.move_toward(player,(260+(pickup_range-dist)*7)*dt)
  if dist<22:
   if d.heal: hp=minf(max_hp,hp+d.amount);play_sound("pick",.7)
   else: xp+=d.amount;play_sound("pick",1.0+float(xp%5)*.07)
  else: keep.append(d)
 drops=keep
 if xp>=next_xp and state=="playing": open_upgrade()

func open_upgrade():
 xp-=next_xp
 level+=1
 next_xp=7+level*5
 choices=[]
 var pool=UPGRADES.duplicate(true)
 for i in 3:
  var index=rng.randi_range(0,pool.size()-1)
  choices.append(pool[index])
  pool.remove_at(index)
 selected_upgrade=0
 state="upgrade"
 test_upgrade_ready_at=world_t+.7
 play_sound("upgrade")

func choose_upgrade(index:int):
 if index<0 or index>=choices.size(): return
 var key:String=choices[index].id
 match key:
  "damage": damage*=1.35
  "speed": interval=maxf(.2,interval/1.22)
  "range": reach=minf(225,reach*1.18)
  "bolt": bolt_count=mini(6,bolt_count+1)
  "health": max_hp+=20;hp=minf(max_hp,hp+35)
  "dash": dash_cooldown=maxf(.6,dash_cooldown*.82);speed*=1.05
  "magnet": pickup_range=minf(360,pickup_range*1.55);hp=minf(max_hp,hp+15)
 upgrades_taken[key]=upgrades_taken.get(key,0)+1
 test_stats.upgrades+=1
 state="playing"
 invincible=maxf(invincible,.8)
 player_prev=player
 play_sound("upgrade",1.15)

func emit_particle(pos:Vector2,color:Color,force:float,size:float):
 if particles.size()>260:return
 particles.append({"pos":pos,"vel":Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(force*.3,force),"t":rng.randf_range(.2,.5),"color":color,"size":rng.randf_range(2,size)})

func update_effects(dt:float):
 for p in particles:p.pos+=p.vel*dt;p.vel*=maxf(0,1-dt*4);p.t-=dt
 particles=particles.filter(func(p):return p.t>0)
 for l in labels:l.pos.y-=34*dt;l.t-=dt
 labels=labels.filter(func(l):return l.t>0)

func finish_game(won:bool):
 state="won" if won else "dead"
 best=maxi(best,kills)
 if test_mode=="":
  var file=FileAccess.open(SAVE_PATH,FileAccess.WRITE)
  if file:file.store_string(JSON.stringify({"best":best}))
 play_sound("upgrade" if won else "end")

func play_sound(key:String,pitch:float=1):
 if muted or not sounds.has(key):return
 var ap=audio_pool[audio_index%audio_pool.size()]
 audio_index+=1
 ap.stream=sounds[key]
 ap.pitch_scale=pitch
 ap.play()

# Canvas helpers keep the UI at a stable virtual resolution.
func panel(rect:Rect2,color:Color,border:Color=Color.TRANSPARENT,radius:int=16):
 var box=StyleBoxFlat.new()
 box.bg_color=color
 box.set_corner_radius_all(radius)
 if border.a>0:box.border_color=border;box.set_border_width_all(1)
 draw_style_box(box,rect)

func text_at(s:String,pos:Vector2,size:int=20,color:Color=CREAM):
 draw_string(font,pos,s,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func centered(s:String,y:float,size:int=20,color:Color=CREAM):
 var w=font.get_string_size(s,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
 text_at(s,Vector2((1280-w)/2,y),size,color)

func meter(rect:Rect2,ratio:float,color:Color):
 panel(rect,Color("293739"),Color.TRANSPARENT,int(rect.size.y/2))
 if ratio>0: panel(Rect2(rect.position,Vector2(maxf(rect.size.y,rect.size.x*clampf(ratio,0,1)),rect.size.y)),color,Color.TRANSPARENT,int(rect.size.y/2))

func sprite(key:String,pos:Vector2,height:float,flip:float=1,t:float=0,anim:String="",tint:Color=Color.WHITE):
 var texture:Texture2D=textures.get(key)
 var source=Rect2()
 if atlases.has(anim):
  var a=atlases[anim]
  texture=a.texture
  var frame=clampi(int(t*float(a.fps))%int(a.frames),0,int(a.frames)-1)
  var cols=int(a.cols)
  source=Rect2((frame%cols)*int(a.cell),int(frame/cols)*int(a.cell),int(a.cell),int(a.cell))
 if texture==null:return
 var width=height
 if source.size==Vector2.ZERO:width=height*texture.get_width()/float(texture.get_height())
 var dest=Rect2(pos.x-width/2,pos.y-height,width,height)
 if flip<0:dest.size.x=-width
 if source.size!=Vector2.ZERO:draw_texture_rect_region(texture,dest,source,tint)
 else:draw_texture_rect(texture,dest,false,tint)

func draw_shadow(pos:Vector2,radius:float,alpha:float=.25):
 draw_set_transform(pos,0,Vector2(1,.32))
 draw_circle(Vector2.ZERO,radius,Color(0.03,.055,.05,alpha))
 draw_set_transform(Vector2.ZERO)

func _draw():
 if font==null:return
 if textures.has("arena"):draw_texture_rect(textures.arena,Rect2(-8+shake_offset.x,70+shake_offset.y,1296,730),false)
 else:draw_rect(Rect2(0,0,1280,800),Color("64716b"))
 if state=="menu":draw_menu();return
 # A subtle outer stitch makes the combat boundary legible.
 for x in range(66,1220,20):
  draw_line(Vector2(x,170),Vector2(x+8,170),Color(.91,.83,.66,.28),2)
  draw_line(Vector2(x,720),Vector2(x+8,720),Color(.91,.83,.66,.28),2)
 for d in drops:
  var p:Vector2=d.pos+Vector2(0,sin(world_t*3+d.phase)*2)
  draw_circle(p,13,Color(.2,.9,.77,.08))
  panel(Rect2(p-Vector2(5,7),Vector2(10,14)),TEAL if not d.heal else CREAM,Color(.9,1,.9,.7),3)
  draw_line(p-Vector2(2,0),p+Vector2(2,0),INK,1.5)
  if d.heal:draw_line(p-Vector2(0,3),p+Vector2(0,3),INK,1.5)
 for e in enemies:
  if e.phase=="warn":
   var normal:Vector2=e.dir.orthogonal()*(34 if e.boss else 23)
   var end:Vector2=e.pos+e.dir*(456 if e.boss else 273)
   draw_colored_polygon(PackedVector2Array([e.pos+normal,end+normal,end-normal,e.pos-normal]),Color(1,.31,.23,.16+sin(world_t*18)*.035))
   draw_line(e.pos+normal,end+normal,RED,1.5,true)
   draw_line(e.pos-normal,end-normal,RED,1.5,true)
   draw_arc(e.pos,48 if e.boss else 34,0,TAU,40,RED,2,true)
  elif e.phase=="shoot_warn":
   draw_arc(e.pos,35,0,TAU*(1-e.timer/.8),28,RED,3,true)
   draw_circle(e.pos+Vector2(0,-46),5,RED)
 var interp=Engine.get_physics_interpolation_fraction() if state=="playing" else 1.0
 var pp=player_prev.lerp(player,interp)+shake_offset
 for g in ghosts:sprite("hero",g.pos+Vector2(0,8),104,g.face,world_t,"hero_run",Color(.3,1,.87,g.t*1.5))
 var actors=enemies.duplicate()
 actors.append({"hero":true,"pos":player})
 actors.sort_custom(func(a,b):return a.pos.y<b.pos.y)
 for actor in actors:
  if actor.has("hero"):
   draw_shadow(pp,25)
   if dash_cd<=0:draw_arc(pp,29,0,TAU,40,Color(.4,.95,.83,.35),1.5,true)
   var color=Color.WHITE
   if invincible>0 and int(world_t*20)%2==0:color=Color(1,.8,.68,.7)
   var anim="hero_run" if move_dir.length_squared()>0 or dash_time>0 else ""
   var anim_t=world_t
   if attack_time>0 and atlases.has("hero_attack"):
    anim="hero_attack"
    var a=atlases[anim]
    anim_t=(1-attack_time/attack_duration)*(float(a.frames)-1)/float(a.fps)
   var breath=sin(world_t*3)*1.2 if anim=="" else 0.0
   sprite("hero",pp+Vector2(0,12+breath),112,facing,anim_t,anim,color)
  else:
   var p:Vector2=actor.prev.lerp(actor.pos,interp)+shake_offset
   var key:String=["rat","car","doll"][actor.type]
   draw_shadow(p,39 if actor.boss else 23)
   var height=137.0 if actor.boss else [81.0,88.0,98.0][actor.type]
   var color=Color(1.7,1.5,1.2) if actor.hit>0 else Color.WHITE
   var at:float=actor.anim
   if actor.phase in ["warn","shoot_warn","recover"]:at=0
   if actor.phase=="warn":p.x+=sin(world_t*45)*1.5
   sprite(key,p+Vector2(0,12),height,actor.face,at,key+"_run",color)
   if actor.hp<actor.max_hp:
    meter(Rect2(p.x-22,p.y-height*.7-12,44,4),actor.hp/actor.max_hp,RED)
 if attack_time>0:
  var progress=1-attack_time/attack_duration
  var a=attack_angle-1.9+progress*3.8
  var slash_color=Color(1,.89,.57,sin(progress*PI))
  draw_arc(pp+Vector2(0,-12),reach*.88,a-.65,a,22,slash_color,9,true)
  draw_arc(pp+Vector2(0,-12),reach*.9,a-.7,a+.02,22,Color(1,1,.85,slash_color.a),2,true)
  if atlases.has("slash"):
   var fx=atlases.slash
   var tex:Texture2D=fx.texture
   var frame=clampi(int(progress*(int(fx.frames)-1)),0,int(fx.frames)-1)
   var source=Rect2(frame%int(fx.cols)*int(fx.cell),int(frame/int(fx.cols))*int(fx.cell),int(fx.cell),int(fx.cell))
   draw_set_transform(pp+Vector2(0,-16),attack_angle,Vector2.ONE)
   draw_texture_rect_region(tex,Rect2(-reach,-reach,reach*2,reach*2),source,Color(1,1,1,.8))
   draw_set_transform(Vector2.ZERO)
 for p in projectiles:
  if p.enemy:
   draw_circle(p.pos,10,Color(1,.3,.25,.15))
   draw_circle(p.pos,5.5,RED)
   draw_circle(p.pos,2,Color("fff0c4"))
  else:
   draw_line(p.pos-p.vel.normalized()*14,p.pos,Color(.4,.9,.82,.5),4,true)
   draw_circle(p.pos,5,TEAL)
   draw_circle(p.pos,2,INK)
 for p in particles:draw_rect(Rect2(p.pos,Vector2(p.size,p.size)),Color(p.color,p.t*2))
 for l in labels:text_at(l.text,l.pos,19,Color(l.color,minf(1,l.t*3)))
 draw_hud()
 if state=="upgrade":draw_upgrade()
 elif state=="paused":draw_pause()
 elif state in ["dead","won"]:draw_result()

func draw_hud():
 draw_rect(Rect2(0,0,1280,107),Color("142429"))
 draw_line(Vector2(0,106),Vector2(1280,106),Color("4f6d65"),1)
 text_at("缝隙求生",Vector2(30,38),24,CREAM)
 text_at("SCRAPBOUND",Vector2(31,60),11,Color("a8b5a1"))
 meter(Rect2(228,29,220,14),hp/max_hp,RED if hp<max_hp*.3 else TEAL)
 text_at("缝合度  %d / %d"%[hp,max_hp],Vector2(228,67),14,CREAM)
 var overtime=time_alive>=total_time and not boss_defeated
 var remaining=maxf(0,(total_time+45 if overtime else total_time)-time_alive)
 centered("%02d:%02d"%[int(remaining)/60,int(remaining)%60],47,30,CREAM)
 centered("拆解拖车 · 最后窗口" if overtime else "坚持到撤离", 70,12,Color("aec1b0"))
 text_at("拆解  %03d"%kills,Vector2(856,42),23,GOLD)
 text_at("第 %d 波 / 4"%wave,Vector2(860,68),13,CREAM)
 text_at("Lv. %02d"%level,Vector2(1111,42),23,TEAL)
 text_at("零件 %d / %d"%[xp,next_xp],Vector2(1090,68),13,CREAM)
 meter(Rect2(30,88,1220,4),float(xp)/next_xp,TEAL)
 draw_rect(Rect2(0,746,1280,54),Color("142429"))
 text_at("W A S D  移动",Vector2(28,779),14,CREAM)
 text_at("SPACE  冲刺",Vector2(198,779),14,TEAL if dash_cd<=0 else Color("a2aaa0"))
 meter(Rect2(322,767,90,6),1-dash_cd/dash_cooldown,TEAL)
 text_at("自动挥锯",Vector2(450,779),14,GOLD)
 text_at("ESC 暂停   ·   M 静音   ·   F11 全屏",Vector2(917,779),12,Color("a6b3a6"))
 var slot=0
 for key in upgrades_taken:
  panel(Rect2(575+slot*46,755,38,34),Color("304943"),Color("638878"),6)
  var title=""
  for up in UPGRADES:
   if up.id==key:title=up.title.substr(0,1)
  text_at(title,Vector2(582+slot*46,777),16,TEAL)
  text_at(str(upgrades_taken[key]),Vector2(601+slot*46,787),10,GOLD)
  slot+=1
 if banner_time>0:
  panel(Rect2(410,121,460,44),Color(.07,.12,.13,.86),Color(.7,.68,.45,.3),10)
  centered(banner,151,21,GOLD)
 if tutorial_time>0 and time_alive>3 and state=="playing":
  panel(Rect2(383,675,514,38),Color(.06,.13,.14,.8),Color.TRANSPARENT,10)
  centered("靠近敌人自动挥锯  ·  拾取青色零件升级  ·  冲刺可穿过危险",700,14,CREAM)
 if combo>=5 and combo_time>0:
  text_at("%d 连拆"%combo,Vector2(1050,155),22,GOLD)
 for e in enemies:
  if e.boss:
   panel(Rect2(444,181,392,39),Color(.1,.14,.14,.9),Color.TRANSPARENT,9)
   centered("废料吞吞",198,12,RED)
   meter(Rect2(463,207,354,5),e.hp/e.max_hp,RED)

func draw_menu():
 draw_rect(Rect2(0,0,1280,800),Color(.025,.06,.065,.7))
 panel(Rect2(68,73,1144,650),Color(.045,.105,.115,.87),Color("48665c"),28)
 text_at("一场属于被遗忘者的反击",Vector2(105,139),16,TEAL)
 text_at("缝隙求生",Vector2(98,257),76,CREAM)
 text_at("S C R A P B O U N D",Vector2(107,302),24,GOLD)
 draw_line(Vector2(108,333),Vector2(465,333),Color("547468"),1)
 text_at("旧布偶，废品武器，最后三分钟。",Vector2(108,382),23,CREAM)
 text_at("在发条与碎铁之间，拼出你的下一条生路。",Vector2(108,422),18,Color("adbcaa"))
 var hover=Rect2(102,494,300,64).has_point(get_global_mouse_position())
 panel(Rect2(102,494,300,64),TEAL.lightened(.1) if hover else TEAL,Color.TRANSPARENT,12)
 text_at("开始求生    ENTER  →",Vector2(135,535),23,INK)
 text_at("自动攻击  /  WASD 移动  /  空格冲刺",Vector2(109,593),15,CREAM)
 text_at("最高拆解  %03d"%best,Vector2(109,658),15,GOLD)
 draw_circle(Vector2(939,394),222,Color(.3,.56,.47,.12))
 draw_arc(Vector2(939,394),239,0,TAU,100,Color(.51,.64,.48,.22),1,true)
 draw_shadow(Vector2(941,575),108,.3)
 sprite("hero",Vector2(936,638),469,1,world_t,"",Color.WHITE)
 panel(Rect2(786,633,303,39),Color("29443e"),Color("668c74"),9)
 text_at("01 / 补丁    ·    瓶盖锯装配",Vector2(806,659),15,CREAM)
 centered("废土玩具 · 俯视生存实验     /     原创可玩样片 0.1",766,12,Color("9aac9f"))

func draw_upgrade():
 draw_rect(Rect2(0,0,1280,800),Color(.015,.045,.05,.85))
 centered("捡来的，也能成为力量",211,37,CREAM)
 centered("等级 %d  ·  选一件改装，继续上场"%level,252,17,TEAL)
 for i in choices.size():
  var rect=Rect2(175+i*320,300,290,260)
  var active=i==selected_upgrade or rect.has_point(get_global_mouse_position())
  panel(rect,Color("2c4640") if active else Color("1d302f"),TEAL if active else Color("567067"),17)
  text_at("0%d"%(i+1),rect.position+Vector2(24,40),20,TEAL)
  text_at(choices[i].title,rect.position+Vector2(24,97),27,CREAM)
  draw_line(rect.position+Vector2(24,121),rect.position+Vector2(264,121),Color("527467"),1)
  text_at(choices[i].desc,rect.position+Vector2(24,158),17,GOLD)
  text_at(choices[i].note,rect.position+Vector2(24,192),13,Color("b4c1ad"))
  text_at("按 %d  装配 →"%(i+1),rect.position+Vector2(24,234),15,TEAL)
 centered("战斗已暂停  ·  数字 1 / 2 / 3 或鼠标选择",614,15,Color("a4b8a8"))

func draw_pause():
 draw_rect(Rect2(0,0,1280,800),Color(.025,.07,.08,.84))
 centered("让发条歇一会儿",333, 40,CREAM)
 centered("移动 WASD / 方向键    冲刺 SPACE    自动攻击",392,18,TEAL)
 panel(Rect2(490,451,300,60),TEAL,Color.TRANSPARENT,12)
 centered("继续战斗  ·  ESC",490,23,INK)
 centered("声音："+("关闭" if muted else "开启")+"  ·  按 M 切换",555,15,CREAM)

func draw_result():
 draw_rect(Rect2(0,0,1280,800),Color(.025,.07,.08,.86))
 centered("破旧，也值得新生" if state=="won" else "线断了，再缝一次",278,46,CREAM)
 centered("成功守住了这块小小的领地" if state=="won" else "留意红色预警，把冲刺留给真正的危险",328,18,TEAL)
 centered("存活 %02d:%02d    ·    拆解 %d    ·    等级 %d"%[int(time_alive)/60,int(time_alive)%60,kills,level],404,26,GOLD)
 panel(Rect2(490,498,300,60),TEAL,Color.TRANSPARENT,12)
 centered("再来一局   ENTER",538,23,INK)
 centered("同样的旧玩具，下一次会有新的搭配。",607,15,Color("b0c1af"))

# Integration playback exercises the same simulation and rendering as the app.
func test_movement()->Vector2:
 if test_mode=="combat" and test_elapsed<2:return Vector2.RIGHT
 var target=Vector2(640,435)+Vector2(cos(time_alive*.48)*370,sin(time_alive*.48)*205)
 var dir=(target-player).normalized()
 var avoid=Vector2.ZERO
 for e in enemies:
  var diff:Vector2=player-e.pos
  if diff.length()<100:avoid+=diff.normalized()*(1-diff.length()/100)*2
 if not drops.is_empty() and hp>35:
  var closest=drops[0]
  for d in drops:
   if d.pos.distance_squared_to(player)<closest.pos.distance_squared_to(player):closest=d
  if closest.pos.distance_to(player)<160:dir=(closest.pos-player).normalized()
 if avoid.length()>.5 and dash_cd<=0:dash_buffer=.1
 return (dir+avoid).normalized()

func capture(name:String):
 await RenderingServer.frame_post_draw
 var img=get_viewport().get_texture().get_image()
 img.save_png("res://captures/"+name+".png")

func run_test():
 if test_finishing:return
 if test_mode=="native":
  if test_elapsed>18:
   test_finishing=true
   await capture("native-input")
   write_test_report()
   get_tree().quit()
  return
 if test_mode=="menu":
  if test_elapsed>1.2 and not test_shots.has("menu"):
   test_shots.menu=true
   capture("menu")
  if test_elapsed>2:write_test_report();get_tree().quit()
  return
 if state=="upgrade":
  if not test_shots.has("upgrade"):
   test_shots.upgrade=true
   capture("upgrade")
  if world_t>=test_upgrade_ready_at:
   var best_index=0
   for i in choices.size():
    if choices[i].id=="bolt" or (hp<60 and choices[i].id=="health"):best_index=i
   choose_upgrade(best_index)
 if test_elapsed>2 and not test_shots.has("combat"):
  test_shots.combat=true
  capture("combat")
 if test_mode=="combat" and test_elapsed>3 and not test_shots.has("dash"):
  dash_buffer=.1
  test_shots.dash=true
 if test_mode=="combat" and test_elapsed>5 and not test_shots.has("enemies"):
  spawn_enemy(1)
  spawn_enemy(2)
  test_shots.enemies=true
 if test_mode=="soak" and time_alive>70 and not test_shots.has("midgame"):
  test_shots.midgame=true
  capture("midgame")
 if test_mode=="combat" and test_elapsed>11 or test_mode=="soak" and (test_elapsed>32 or state in ["dead","won"]):
  test_finishing=true
  await capture(test_mode+"-final")
  write_test_report()
  get_tree().quit()

func write_test_report():
 test_frames.sort()
 var report={"test":test_mode,"state":state,"survived":time_alive,"hp":hp,"kills":kills,"level":level,"stats":test_stats,"assets":textures.keys(),"animations":atlases.keys(),"frame_ms_p50":test_frames[int(test_frames.size()*.5)] if test_frames.size() else 0,"frame_ms_p95":test_frames[int(test_frames.size()*.95)] if test_frames.size() else 0}
 var file=FileAccess.open("res://captures/"+test_mode+"-report.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "))
 print("TEST_REPORT ",JSON.stringify(report))

func pick_spawn_type()->int:
 var roll=rng.randf()
 if time_alive>48 and roll>.78:return 2
 if time_alive>18 and roll>.58:return 1
 return 0

func get_move_direction()->Vector2:
 if test_mode in ["combat","soak","showcase"]:return test_movement()
 return Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))).normalized()
