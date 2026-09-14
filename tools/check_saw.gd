extends "res://tools/check_v03.gd"
# Focused combat regression. No backups or separate project copies are created.

func reset_saw(route := "thread"):
 reset_run("challenge", route)
 game.crates.clear()
 game.bolt_count = 0
 game.pulse_level = 0
 game.turret_level = 0
 game.next_event_at = 100000
 game.next_elite_at = 100000
 game.boss_spawned = true
 game.last_dir = Vector2.RIGHT
 for kind in 6: game.introduced[kind] = true

func clock_snapshot(enemy: Dictionary) -> Dictionary:
 return {"time":game.time_alive,"attack":game.attack_time,"attack_cd":game.attack_cd,
  "bolt_cd":game.bolt_cd,"pulse_cd":game.pulse_cd,"turret_cd":game.turret_cd,
  "dash_cd":game.dash_cd,"invincible":game.invincible,"overdrive":game.overdrive_time,
  "spawn_cd":game.spawn_cd,"event":game.field_event.remaining,"event_age":game.field_event.age,
  "enemy_timer":enemy.timer,"enemy_phase":enemy.phase_t,"enemy_anim":enemy.anim,
  "projectile_t":game.projectiles[0].t,"projectile_pos":game.projectiles[0].pos,
  "tether_life":game.tethers[0].life,"player":game.player}

func check_single_strikes():
 reset_saw()
 var target := foe(0, game.player + Vector2(80, 0))
 var health: float = target.hp
 game.begin_saw_attack(Vector2.RIGHT)
 game.land_attack()
 check(is_equal_approx(health - target.hp, 29.0) and game.test_stats.hits == 1,
  "Ordinary saw strike deals the original damage exactly once")
 check(game.saw_metrics.contacts == 1 and game.saw_metrics.stops == 1 and game.hit_freeze > 0 and game.hit_freeze <= 0.075,
  "Ordinary contact creates one bounded hit stop")
 health = target.hp
 var hold: float = game.hit_freeze
 game.land_attack()
 check(target.hp == health and game.test_stats.hits == 1 and game.hit_freeze == hold and game.saw_metrics.stops == 1,
  "Repeated land callback cannot duplicate damage or extend stop")
 reset_saw("saw")
 target = foe(0, game.player + Vector2(80, 0))
 game.saw_swings = 2
 game.begin_saw_attack(Vector2.RIGHT)
 health = target.hp
 game.land_attack()
 check(is_equal_approx(health - target.hp, 29.0 * 1.3 * (1.18 + 0.28)) and game.test_stats.hits == 2,
  "Third saw strike preserves one heavy hit plus its existing echo")
 check(game.saw_metrics.contacts == 1 and game.saw_metrics.stops == 1 and game.saw_metrics.heavy == 1,
  "Third-strike echo shares contact feedback without creating a second stop")
 health = target.hp
 game.land_attack()
 check(target.hp == health and game.saw_swings == 3, "Heavy strike callback is also idempotent")
 reset_saw()
 game.begin_saw_attack(Vector2.RIGHT)
 game.land_attack()
 check(game.hit_freeze == 0 and game.saw_metrics.stops == 0, "Empty swing does not stop combat")
 target = foe(0, game.player + Vector2(-80, 0))
 game.begin_saw_attack(Vector2.RIGHT)
 game.land_attack()
 check(target.hp == target.max_hp and game.hit_freeze == 0, "An enemy outside the attack cone cannot create a false hit stop")
 reset_saw()
 target = foe(0, game.player + Vector2(80, 0))
 game.add_projectile(game.player + Vector2(0, -23), Vector2(8000, 0), false, 10)
 game.update_projectiles(0.02)
 check(target.hp < target.max_hp and game.hit_freeze == 0 and game.saw_metrics.contacts == 0,
  "Button damage remains effective without saw stop or saw feedback")
 reset_saw("saw")
 game.saw_swings = 2
 game.crit_chance = 1
 for index in 50: foe(0, game.player + Vector2(60 + index % 8 * 4, index % 5 * 3), 1)
 game.begin_saw_attack(Vector2.RIGHT)
 game.land_attack()
 check(game.kills == 50 and game.saw_metrics.contacts == 50 and game.saw_metrics.stops == 1,
  "Fifty simultaneous kills produce one stop rather than fifty additive stops")
 check(game.hit_freeze <= 0.075 and game.saw_metrics.max_stop <= 0.075 and game.saw_impacts.size() <= 40,
  "Crowd impact respects the 75 ms stop and forty-effect limits")
 var kill_count: int = game.kills
 var drop_count: int = game.drops.size()
 game.land_attack()
 check(game.kills == kill_count and game.drops.size() == drop_count, "Crowd strike cannot duplicate kills or loot")

func check_frozen_clocks_and_input():
 reset_saw("coil")
 var target := foe(1, game.player + Vector2(300, 0))
 var other := foe(0, game.player + Vector2(360, 30))
 target.phase = "warn"; target.timer = 0.8; target.phase_t = 0.1
 game.attack_time = 0.25; game.attack_cd = 0.5; game.attack_landed = true
 game.bolt_count = 1; game.bolt_cd = 0.7
 game.pulse_level = 1; game.pulse_cd = 0.7
 game.turret_level = 1; game.turret_cd = 0.7
 game.overdrive_time = 5; game.dash_cd = 1
 game.start_field_event("musicbox")
 game.add_projectile(Vector2(160, 250), Vector2(50, 0), true, 12)
 game.tethers = [{"a":target.id,"b":other.id,"life":5.0,"phase":0.0}]
 game.hit_freeze = 0.06
 var before := clock_snapshot(target)
 game._physics_process(0.025)
 check(clock_snapshot(target) == before,
  "Hit stop freezes attack, enemies, projectiles, dash, invulnerability, spawn, overdrive, event, sentry and tether clocks together")
 check(is_equal_approx(game.hit_freeze, 0.035), "Stop itself counts down once at the outer simulation level")
 game._physics_process(0.055)
 check(is_equal_approx(game.time_alive, 0.02) and is_equal_approx(game.overdrive_time, 4.98)
  and is_equal_approx(game.field_event.remaining, float(before.event) - 0.02)
  and is_equal_approx(target.timer, float(before.enemy_timer) - 0.02)
  and is_equal_approx(game.projectiles[0].t, float(before.projectile_t) - 0.02),
  "Only the unheld remainder advances every combat clock after stop expiry")
 check(game.hit_freeze == 0 and not game.simulation_dt_prepared,
  "Stop expires and the inherited simulation preparation flag is cleared")
 reset_saw()
 game.hit_freeze = 0.075
 var origin: Vector2 = game.player
 tap(KEY_SPACE)
 game._physics_process(0.05)
 check(game.player == origin and game.dash_time == 0 and game.dash_buffer > 0,
  "Space pressed during hit stop is buffered without moving the frozen scene")
 game._physics_process(0.04)
 check(game.dash_time > 0 and game.test_stats.dashes == 1 and game.player.distance_to(origin) > 0,
  "Buffered Space starts one dash on the first unheld simulation step")
 reset_saw()
 game.hit_freeze = 0.05
 origin = game.player
 key(KEY_D)
 game._physics_process(0.025)
 key(KEY_D, false)
 game._physics_process(0.05)
 check(game.player == origin and game.move_dir == Vector2.ZERO,
  "Movement key released during stop does not create a stale movement burst")
 reset_saw()
 game.hit_freeze = 0.05
 tap(KEY_ESCAPE)
 game._physics_process(0.4)
 check(game.state == "paused" and game.hit_freeze == 0.05 and game.time_alive == 0,
  "Pause responds during impact and preserves the held simulation")
 tap(KEY_ESCAPE)
 game._physics_process(0.08)
 check(game.state == "playing" and is_equal_approx(game.time_alive, 0.03) and game.hit_freeze == 0,
  "Resume finishes remaining stop and restores simulation")
 for hz in [30, 60, 120]:
  reset_saw()
  game.hit_freeze = 0.075
  for tick in int(hz / 5): game._physics_process(1.0 / hz)
  check(is_equal_approx(game.time_alive, 0.125) and game.hit_freeze == 0,
   "Stop duration stays bounded and frame-rate independent at " + str(hz) + " Hz")

func check_reaction_and_lifecycle():
 reset_saw()
 var target := foe(3, game.player + Vector2(80, 0))
 game.expose_core(target, 3)
 game.hurt_enemy(target, 5, Vector2.RIGHT)
 check(is_equal_approx(target.frozen, 0.15), "A hit does not shorten the longer exposed-core stagger")
 reset_saw()
 target = foe(0, game.player + Vector2(80, 0), 1)
 game.begin_saw_attack(Vector2.RIGHT)
 game.land_attack()
 check(game.corpses.size() == 1 and game.corpses[0].get("vel", Vector2.ZERO).length() > 0,
  "Saw kill gives debris remains a short directional reaction")
 game.hit_freeze = 0
 game._process(0.5)
 check(game.saw_impacts.is_empty(), "Transient saw effects expire instead of accumulating")
 game.hit_freeze = 0.075
 game.saw_camera_strength = 6
 game.saw_metrics.stops = 8
 game.simulation_dt_prepared = true
 game.start_game()
 check(game.hit_freeze == 0 and game.saw_impacts.is_empty() and game.saw_contacts.is_empty()
  and game.saw_metrics.stops == 0 and game.saw_metrics.contacts == 0
  and game.saw_camera_strength == 0 and not game.simulation_dt_prepared and not game.attack_landed,
  "Restart clears stop, transient impacts, camera reaction and contact state")
 check(game.saw_audio_pool.size() == 6, "Saw transients have six dedicated audio voices")
 var isolated := true
 for voice in game.saw_audio_pool:
  if voice in game.audio_pool: isolated = false
 check(isolated, "Pickups and debris cannot steal a saw voice")

func check_small_difficulty_adjustment():
 for mode_name in ["challenge", "endless"]:
  reset_saw()
  game.mode = mode_name
  var valid := true
  for seconds in [0.0, 45.0, 90.0, 180.0, 300.0, 600.0]:
   game.time_alive = seconds
   var floor_delay := 0.19 if mode_name == "endless" else 0.24
   var old := maxf(floor_delay, (0.82 - seconds * 0.0022) if mode_name == "endless" else (0.88 - seconds * 0.0035))
   var current: float = game.regular_spawn_delay()
   if current < old * 0.94 - 0.00001 or current > old + 0.00001 or current < floor_delay - 0.00001:
    valid = false
  check(valid, "Difficulty raises only uncapped spawn density by at most 6.4 percent: " + mode_name)
 reset_saw()
 game.time_alive = 0
 game.spawn_enemy(1)
 var car: Dictionary = game.enemies[-1]
 check(is_equal_approx(car.max_hp, 74) and is_equal_approx(game.enemy_move_speed(car), 68),
  "Starting car health and movement keep their original combat thresholds")
 car.spawn = 0; car.timer = 0; car.pos = game.player + Vector2(250, 0)
 game.update_enemies(0.01)
 check(car.phase == "warn" and is_equal_approx(car.timer, 0.87), "Car warning duration remains readable and unchanged")
 game.invincible = 0
 var hp: float = game.hp
 game.take_damage(13)
 check(game.hp == hp - 13 and is_equal_approx(game.invincible, 0.85), "Contact damage and hurt invulnerability remain unchanged")

func run():
 started_us = Time.get_ticks_usec()
 DirAccess.make_dir_recursive_absolute("res://captures/v04")
 report_path = "res://captures/v04/saw-checks.json"
 game = load("res://main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.test_mode = "checks_saw"
 game.muted = true
 game.set_physics_process(false)
 game.set_process(false)
 check_single_strikes()
 check_echo_edge_feedback()
 check_frozen_clocks_and_input()
 check_reaction_and_lifecycle()
 check_small_difficulty_adjustment()
 write_report()
 if game.music_director != null and game.music_director.loaded: game.music_director.player.stop()
 game.queue_free()
 game = null
 await process_frame
 await create_timer(0.2).timeout
 quit(0 if failures.is_empty() else 1)

func check_echo_edge_feedback():
 reset_saw("saw")
 var target := foe(0, game.player + Vector2(154, 0))
 game.saw_swings = 2
 game.begin_saw_attack(Vector2.RIGHT)
 var health: float = target.hp
 game.land_attack()
 check(is_equal_approx(health - target.hp, 29.0 * 1.3 * 0.28) and game.test_stats.hits == 1,
  "Target outside the blade radius receives only the original outer echo damage")
 check(game.saw_metrics.contacts == 1 and game.saw_metrics.stops == 1 and game.saw_metrics.heavy == 1
  and game.hit_freeze > 0 and game.hit_freeze <= 0.075,
  "Outer-echo-only contact now receives one heavy impact response")
 reset_saw("saw")
 target = foe(0, game.player + Vector2(80, 0), 50)
 game.saw_swings = 2
 game.muted = false
 game.begin_saw_attack(Vector2.RIGHT)
 var previous_audio: int = game.saw_audio_index
 game.land_attack()
 check(target.hp <= 0 and game.test_stats.hits == 2 and game.kills == 1
  and game.saw_contacts.size() == 1 and game.saw_kills == 1 and game.saw_metrics.kills == 1,
  "Echo finisher counts one kill after the blade left the same target alive")
 check(game.saw_metrics.stops == 1 and game.saw_metrics.contacts == 1
  and game.saw_audio_index == previous_audio + 2
  and game.saw_audio_pool[(game.saw_audio_index - 1) % 6].stream == game.sounds.get("saw_finish"),
  "Echo finisher plays its finishing sound and shares a single bounded stop")
 var drops: int = game.drops.size()
 previous_audio = game.saw_audio_index
 game.land_attack()
 check(game.kills == 1 and game.saw_kills == 1 and game.drops.size() == drops and game.saw_audio_index == previous_audio,
  "Repeated echo-finisher callback cannot duplicate kill, loot, or finishing sound")
 game.muted = true
 reset_saw()
 game.crates = [{"pos":game.player + Vector2(75, 0),"hp":55.0,"hit":0.0}]
 game.begin_saw_attack(Vector2.RIGHT)
 game.land_attack()
 check(game.crates[0].hp == 26 and game.saw_crate_contacts == 1 and game.saw_metrics.stops == 1 and game.hit_freeze > 0,
  "Crate-only saw hit retains damage and one deferred impact response")
