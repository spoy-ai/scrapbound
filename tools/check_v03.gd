extends SceneTree
# Deterministic integration checks. The release test must run against main.tscn.
# Tests drive actual input handlers and physics; rendering/audio perception is
# checked separately in a native window and is not claimed by these assertions.
var game
var failures: Array = []
var results: Array = []
var started_us := 0
const REPORT := "res://captures/v03/checks.json"
var report_path := REPORT

func _initialize():
 call_deferred("run")

func check(condition: bool, label: String, details = null):
 var row := {"label": label, "passed": condition}
 if details != null: row.details = details
 results.append(row)
 if not condition:
  failures.append(label)
  push_error(label)
 else:
  print("PASS ", label)

func has_property(object: Object, name: String) -> bool:
 for item in object.get_property_list():
  if item.name == name: return true
 return false

func require_properties(names: Array) -> bool:
 var complete := true
 for name in names:
  var present := has_property(game, name)
  check(present, "Release interface: " + str(name))
  complete = complete and present
 return complete

func require_methods(names: Array) -> bool:
 var complete := true
 for name in names:
  var present: bool = game.has_method(name)
  check(present, "Release method: " + str(name))
  complete = complete and present
 return complete

func key(code: int, pressed := true):
 var event := InputEventKey.new()
 event.physical_keycode = code
 event.keycode = code
 event.pressed = pressed
 Input.parse_input_event(event)
 Input.flush_buffered_events()

func tap(code: int):
 key(code, true)
 key(code, false)

func reset_run(run_mode := "endless", route := "thread"):
 for code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_E, KEY_R, KEY_SPACE]:
  key(code, false)
 game.mode = run_mode
 game.route_id = route
 game.start_game()
 game.enemies.clear()
 game.drops.clear()
 game.projectiles.clear()
 game.spawn_cd = 100000
 game.invincible = 100000
 game.best = 2147483647
 game.rng.seed = 310903
 game.crit_chance = 0.0

func foe(kind: int, position: Vector2, health := 1000.0) -> Dictionary:
 game.spawn_enemy(kind, kind == 6)
 var enemy: Dictionary = game.enemies[-1]
 enemy.pos = position
 enemy.prev = position
 enemy.spawn = 0.0
 enemy.hp = health
 enemy.max_hp = health
 return enemy

func step(seconds: float, dt := 1.0 / 60.0):
 for index in ceili(seconds / dt):
  game._physics_process(minf(dt, seconds - index * dt))

func check_core_input():
 reset_run("challenge")
 var origin: Vector2 = game.player
 key(KEY_D)
 step(1.0 / 60.0)
 var straight: float = game.player.distance_to(origin)
 check(straight > 3.0, "Keyboard movement responds")
 game.player = origin
 key(KEY_W)
 step(1.0 / 60.0)
 check(absf(game.player.distance_to(origin) - straight) < 0.01, "Diagonal movement stays normalized")
 key(KEY_D, false)
 key(KEY_W, false)
 game.player = Vector2(1200, 400)
 game.last_dir = Vector2.RIGHT
 tap(KEY_SPACE)
 step(1.0 / 60.0)
 check(game.dash_time > 0.0, "Dash input starts dash")
 step(0.4)
 check(game.player.x <= 1200.01, "Dash stays inside arena")
 var cooldown: float = game.dash_cd
 tap(KEY_SPACE)
 step(1.0 / 60.0)
 check(game.dash_cd < cooldown, "Repeated dash input cannot bypass cooldown")
 reset_run("challenge")
 var frozen_time: float = game.time_alive
 tap(KEY_ESCAPE)
 step(0.5)
 check(game.state == "paused" and game.time_alive == frozen_time, "Pause freezes gameplay time")
 tap(KEY_ESCAPE)
 check(game.state == "playing", "Escape resumes gameplay")
 tap(KEY_TAB)
 step(0.5)
 check(game.state == "cabinet" and game.time_alive == frozen_time, "Gallery freezes gameplay time")
 tap(KEY_RIGHT)
 tap(KEY_SPACE)
 check(game.cabinet_index == 1 and game.cabinet_death == 0.0, "Gallery selects enemy and plays death")
 tap(KEY_ESCAPE)
 check(game.state == "playing", "Gallery returns to prior gameplay state")

func check_core_combat():
 reset_run("challenge")
 var rat := foe(0, game.player + Vector2(80, 0))
 game.attack_cd = 0.0
 var health: float = rat.hp
 step(0.3)
 check(rat.hp < health, "Automatic saw damages nearby enemy")
 reset_run("challenge")
 var car := foe(1, game.player + Vector2(250, 0))
 car.timer = 0.0
 game.update_enemies(0.01)
 var direction: Vector2 = car.dir
 check(car.phase == "warn", "Car telegraphs charge")
 game.player += Vector2(0, 150)
 game.update_enemies(0.9)
 check(car.phase == "charge" and car.dir == direction, "Car keeps telegraphed direction")
 reset_run("challenge")
 game.invincible = 0.0
 health = game.hp
 game.take_damage(14.0)
 game.take_damage(14.0)
 check(game.hp == health - 14.0, "Invulnerability prevents duplicate simultaneous damage")
 for kind in 7:
  reset_run("challenge")
  var enemy := foe(kind, Vector2(500, 400))
  game.hurt_enemy(enemy, 100000, Vector2.RIGHT * 300)
  var total_drops: int = game.drops.size()
  check(game.kills == 1 and game.corpses.size() == 1, "Enemy death and corpse: " + str(kind))
  game.hurt_enemy(enemy, 100000, Vector2.RIGHT)
  check(game.kills == 1 and game.corpses.size() == 1 and game.drops.size() == total_drops,
   "Death reward is idempotent: " + str(kind))
  game.update_presentation(4.0)
  check(game.corpses.is_empty(), "Enemy remains eventually disappear: " + str(kind))
 reset_run("challenge")
 game.ricochets = 1
 var first := foe(0, Vector2(600, 400))
 var second := foe(0, Vector2(720, 400))
 game.add_projectile(Vector2(500, 377), Vector2(8000, 0), false, 10)
 game.update_projectiles(0.02)
 check(first.hp < first.max_hp, "Fast button sweeps across enemy instead of tunneling")
 check(game.projectiles.size() == 1 and game.projectiles[0].hit_ids.has(first.id), "Ricochet remembers hit target")
 for index in 20: game.update_projectiles(0.01)
 check(second.hp < second.max_hp and game.projectiles.is_empty(), "Ricochet reaches next target and expires")

func check_assets_and_ui():
 check(game.atlases.size() >= 31, "Existing character and effect atlases still load")
 for glyph in "缝隙求生无尽挑战上紧发条音乐盒回收机缝线线圈暴走":
  check(game.font.has_char(glyph.unicode_at(0)), "Chinese font glyph " + glyph)
 for clip in ["button_spin", "battery_loop", "medkit_loop", "hero_idle", "boss2_slam"]:
  check(game.atlases.has(clip) and game.atlases[clip].frames > 20, "Existing animated detail: " + clip)

func write_report():
 var report := {
  "passed": failures.is_empty(), "checks": results.size(), "failures": failures,
  "results": results, "elapsed_seconds": (Time.get_ticks_usec() - started_us) / 1000000.0,
  "scope": "Deterministic input/physics/asset integration; does not assert subjective fun, visible quality, or audible music quality."
 }
 var file := FileAccess.open(report_path, FileAccess.WRITE)
 file.store_string(JSON.stringify(report, "  "))
 print("V03 CHECKS ", "PASSED" if failures.is_empty() else "FAILED", " count=", results.size())

func run():
 started_us = Time.get_ticks_usec()
 game = load("res://main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.test_mode = "checks_v03"
 game.muted = true
 game.set_physics_process(false)
 game.set_process(false)
 if not require_properties(["mode", "route_id", "energy", "field_event", "tethers"]):
  write_report()
  quit(1)
  return
 if "--targeted" in OS.get_cmdline_user_args():
  report_path = "res://captures/v03/targeted-checks.json"
  check_recent_fixes_and_modal_input()
 else:
  check(game.mode == "endless", "Fresh project boots with endless selected")
  check_core_input()
  check_core_combat()
  check_assets_and_ui()
  check_routes_and_endless()
  check_overdrive_and_reset()
  check_field_events()
  check_links_and_rams()
  check_upgrade_pools()
  check_blueprint_effects()
  await check_music_continuity()
  check_recent_fixes_and_modal_input()
 write_report()
 if game.music_director != null and game.music_director.loaded:
  game.music_director.player.stop()
 game.queue_free()
 game = null
 await process_frame
 # Allow the audio thread to release its synchronized playback references.
 await create_timer(0.1).timeout
 quit(0 if failures.is_empty() else 1)

func check_routes_and_endless():
 reset_run()
 check(game.mode == "endless", "Default run mode is endless")
 game.state = "menu"
 tap(KEY_ENTER)
 check(game.state == "route", "Menu Enter opens route selection without starting combat")
 game.energy = 100
 tap(KEY_R)
 tap(KEY_SPACE)
 check(game.overdrive_time == 0 and game.dash_buffer == 0, "Route menu consumes combat hotkeys")
 tap(KEY_RIGHT)
 tap(KEY_ENTER)
 check(game.state == "playing" and game.route_id == "thread" and game.bolt_count == 2,
  "Route keyboard choice starts thread build exactly once")
 check(game.overdrive_time == 0 and game.dash_buffer == 0, "Route confirmation does not leak into combat")
 reset_run("endless", "coil")
 check(game.turret_level == 1 and game.pulse_level == 1, "Coil route starts with sentry and pulse")
 reset_run("endless", "saw")
 check(game.bolt_count == 1 and game.turret_level == 0 and game.pulse_level == 0, "Saw route has clean independent starting equipment")
 # This checks the actual clock crossing both former termination boundaries.
 # Combat/spawning is isolated here; this is not a claim of human survival.
 game.next_boss_at = 100000
 game.next_elite_at = 100000
 game.next_event_at = 100000
 for kind in 6: game.introduced[kind] = true
 step(230.0, 0.1)
 check(game.state == "playing" and game.time_alive >= 229.9,
  "Endless clock runs through both 180 and 225 seconds without terminating")
 game.spawn_cd = 0
 game.update_spawning(0.01)
 check(not game.enemies.is_empty(), "Normal enemies continue spawning after three minutes")
 reset_run()
 game.time_alive = 135
 game.update_spawning(0.01)
 var bosses: Array = game.enemies.filter(func(e): return e.boss and e.hp > 0)
 check(bosses.size() == 1 and game.next_boss_at == 255, "First endless boss schedules next cycle")
 for index in 5: game.update_spawning(0.01)
 bosses = game.enemies.filter(func(e): return e.boss and e.hp > 0)
 check(bosses.size() == 1, "Repeated spawn updates do not duplicate a living boss")
 if not bosses.is_empty(): game.hurt_enemy(bosses[0], 1000000, Vector2.RIGHT)
 game.enemies = game.enemies.filter(func(e): return e.hp > 0)
 game.time_alive = 200
 game.update_spawning(0.01)
 check(not game.any_boss() and game.bosses_defeated == 1 and not game.boss_defeated,
  "Defeated endless boss settles once without enabling victory or instant respawn")
 game.time_alive = 255
 game.update_spawning(0.01)
 check(game.any_boss() and game.next_boss_at == 375, "Second endless boss appears on its own cycle")
 reset_run("challenge", "thread")
 game.time_alive = 180
 game.boss_spawned = true
 game.boss_defeated = false
 game.check_run_end()
 check(game.state == "playing", "Challenge still requires boss defeat at countdown end")
 game.boss_defeated = true
 game.check_run_end()
 check(game.state == "won", "Challenge survives and defeats boss to win")
 var equipment: int = game.bolt_count
 game.continue_endless()
 check(game.state == "playing" and game.mode == "endless" and game.bolt_count == equipment and game.time_alive == 180,
  "Challenge victory continues into endless with build and clock intact")
 reset_run("challenge", "thread")
 game.time_alive = 225
 game.check_run_end()
 check(game.state == "dead", "Challenge grace-period expiry still ends unsuccessful challenge")

func check_overdrive_and_reset():
 reset_run()
 game.energy = 99
 check(not game.activate_overdrive(), "Overdrive requires full energy")
 game.add_energy(20)
 check(game.energy == 100, "Energy caps at 100")
 tap(KEY_R)
 check(game.energy == 0 and game.overdrive_time == 6 and game.new_stats.overdrives == 1,
  "R consumes energy and starts six-second overdrive")
 game.add_energy(100)
 tap(KEY_R)
 check(game.energy == 0 and game.new_stats.overdrives == 1, "Active overdrive cannot refill or retrigger")
 var active: float = game.overdrive_time
 tap(KEY_ESCAPE)
 step(2.0)
 check(game.overdrive_time == active, "Pause freezes overdrive duration")
 tap(KEY_ESCAPE)
 step(0.5)
 check(game.overdrive_time < active and game.overdrive_time > 5.4, "Overdrive duration resumes with gameplay")
 game.field_event = {"kind":"musicbox", "completed":true}
 game.tethers = [{"a":1,"b":2,"life":4}]
 game.chain_fx = [{"age":0,"life":1}]
 game.blueprints = {"thread_tension":3}
 game.bosses_defeated = 4
 game.event_rewards = 7
 game.new_stats.cuts = 9
 game.crit_chance = 0.7
 game.damage_context = "core_chain"
 game.chain_depth = 2
 game.forced_interact = true
 game.start_game()
 check(game.field_event.is_empty() and game.tethers.is_empty() and game.chain_fx.is_empty() and game.blueprints.is_empty(),
  "Restart clears events, links, chain effects, and blueprints")
 check(game.energy == 30 and game.overdrive_time == 0 and game.bosses_defeated == 0 and game.event_rewards == 0
  and game.next_boss_at == 135 and game.new_stats.cuts == 0 and game.new_stats.overdrives == 0,
  "Restart resets energy, boss schedule, and new counters")
 check(is_equal_approx(game.crit_chance, 0.14) and game.damage_context == "generic" and game.chain_depth == 0 and not game.forced_interact,
  "Restart resets transient combat contexts and interaction state")

func check_field_events():
 reset_run("endless", "thread")
 game.start_field_event("musicbox")
 var position: Vector2 = game.field_event.pos
 game.forced_interact = true
 game.player = position + Vector2(150, 0)
 game.update_field_event(1.0)
 check(game.field_event.progress == 0, "Music box cannot be wound outside interaction range")
 game.player = position
 game.forced_interact = false
 key(KEY_E)
 game.update_field_event(4.0)
 key(KEY_E, false)
 check(game.field_event.progress == 4.0, "Held interaction winds music box near the player")
 var remaining: float = game.field_event.remaining
 game.state = "paused"
 game.update_field_event(20.0)
 check(game.field_event.remaining == remaining and game.field_event.progress == 4.0, "Pause freezes music box progress and deadline")
 game.state = "playing"
 game.forced_interact = false
 game.update_field_event(1.0)
 check(is_equal_approx(game.field_event.progress, 3.75), "Leaving music box slowly unwinds progress")
 game.forced_interact = true
 game.update_field_event(5.3)
 check(game.state == "event_reward" and game.event_rewards == 1 and game.new_stats.events == 1,
  "Nine seconds of winding opens exactly one rare reward")
 game.complete_field_event()
 check(game.event_rewards == 1 and game.new_stats.events == 1, "Repeated event completion cannot duplicate reward")
 check(game.choices.size() == 3 and game.choices.all(func(u): return u.get("rare", false)), "Event offers three rare illustrated choices")
 var frozen: float = game.time_alive
 remaining = game.field_event.remaining
 var motion: Vector2 = game.player
 key(KEY_D)
 tap(KEY_R)
 tap(KEY_SPACE)
 step(0.5)
 key(KEY_D, false)
 check(game.time_alive == frozen and game.player == motion and game.field_event.remaining == remaining
  and game.dash_buffer == 0 and game.overdrive_time == 0,
  "Rare reward pauses movement, timers, and combat hotkeys")
 var upgrades: int = game.test_stats.upgrades
 tap(KEY_ENTER)
 check(game.state == "playing" and game.field_event.is_empty() and game.test_stats.upgrades == upgrades + 1,
  "Rare reward confirmation applies one choice and clears event")
 var damage_after: float = game.damage
 game.choose_upgrade(0)
 check(game.damage == damage_after and game.test_stats.upgrades == upgrades + 1,
  "Reward cannot be reapplied after returning to combat")
 reset_run("endless", "thread")
 game.start_field_event("musicbox")
 game.field_event.remaining = 0.1
 game.update_field_event(0.2)
 check(game.field_event.is_empty() and game.event_rewards == 0 and game.next_event_at > game.time_alive,
  "Unfinished event expires without reward and schedules a later event")
 reset_run("endless", "thread")
 game.start_field_event("recycler")
 var victim := foe(0, Vector2(500, 400), 1)
 game.hurt_enemy(victim, 100, Vector2.RIGHT)
 check(game.field_event.kills == 0, "Recycler does not count kills before accepting contract")
 game.player = game.field_event.pos
 game.forced_interact = true
 game.update_field_event(0.01)
 check(game.field_event.active and game.field_event.remaining == 30 and game.field_event.kills == 0,
  "Recycler interaction starts a fresh 30-second contract")
 game.forced_interact = false
 for index in 13:
  victim = foe(0, Vector2(500, 400), 1)
  game.hurt_enemy(victim, 100, Vector2.RIGHT)
 game.update_field_event(0.01)
 check(game.state == "playing" and game.field_event.kills == 13, "Recycler waits for all fourteen kills")
 victim = foe(0, Vector2(500, 400), 1)
 game.hurt_enemy(victim, 100, Vector2.RIGHT)
 game.hurt_enemy(victim, 100, Vector2.RIGHT)
 game.update_field_event(0.01)
 check(game.state == "event_reward" and game.field_event.kills == 14 and game.event_rewards == 1,
  "Fourteenth unique recycler kill opens reward exactly once")
 reset_run("endless", "thread")
 game.start_field_event("recycler")
 game.player = game.field_event.pos
 game.forced_interact = true
 game.update_field_event(0.01)
 game.forced_interact = false
 game.update_field_event(30.1)
 check(game.field_event.is_empty() and game.event_rewards == 0, "Unfulfilled active recycler contract expires without reward")

func check_links_and_rams():
 reset_run("challenge", "thread")
 var a := foe(0, Vector2(550, 400))
 var b := foe(0, Vector2(700, 400))
 game.link_enemy(a)
 check(game.tethers.size() == 1 and game.tethers[0].a != game.tethers[0].b, "Thread build connects two different living enemies")
 game.link_enemy(a)
 check(game.tethers.size() == 1, "Repeated hits refresh an existing link without duplicates")
 var link: Dictionary = game.tethers[0]
 var health_a: float = a.hp
 var health_b: float = b.hp
 game.player_prev = Vector2(620, 350)
 game.player = Vector2(620, 450)
 game.dash_time = 0.1
 game.update_tethers(0.01)
 check(game.tethers.is_empty() and game.new_stats.cuts == 1 and a.hp < health_a and b.hp < health_b,
  "Dash crossing a thread cuts it and damages both endpoints")
 health_a = a.hp
 game.cut_tether(link)
 check(game.new_stats.cuts == 1 and a.hp == health_a, "Cut thread cannot damage or reward twice")
 game.link_enemy(a)
 b.hp = 0
 game.update_tethers(0.01)
 check(game.tethers.is_empty(), "Link cleans up dead endpoints")
 reset_run("challenge", "thread")
 a = foe(0, Vector2(550, 400), 1)
 b = foe(0, Vector2(600, 400), 1)
 var c := foe(0, Vector2(650, 400), 1)
 game.tethers = [{"a":a.id,"b":b.id,"life":5.0,"phase":0.0}, {"a":b.id,"b":c.id,"life":5.0,"phase":0.0}]
 game.hurt_enemy(a, 100, Vector2.RIGHT)
 var reward_count: int = game.drops.size()
 game.hurt_enemy(a, 100, Vector2.RIGHT)
 game.hurt_enemy(b, 100, Vector2.RIGHT)
 game.hurt_enemy(c, 100, Vector2.RIGHT)
 check(game.kills == 3 and game.drops.size() == reward_count and game.chain_depth == 0 and game.damage_context == "generic",
  "Linked death cascade settles each victim once and restores combat context")
 reset_run("challenge", "thread")
 var car := foe(1, Vector2(400, 400))
 var beetle := foe(3, Vector2(440, 400))
 car.phase = "charge"; car.timer = 0.5; car.dir = Vector2.RIGHT
 beetle.phase = "walk"; beetle.timer = 10; beetle.frozen = 1.0; beetle.dir = Vector2.RIGHT
 var health: float = beetle.hp
 game.update_enemies(0.05)
 check(beetle.hp < health and beetle.exposed > 0 and beetle.phase == "recover" and game.new_stats.rams == 1,
  "Charging car damages friendly beetle and exposes its core")
 health = beetle.hp
 game.update_enemies(0.01)
 check(beetle.hp == health and game.new_stats.rams == 1, "Same car charge cannot repeatedly ram one victim")
 health = beetle.hp
 game.damage_context = "generic"
 game.hurt_enemy(beetle, 20, Vector2.LEFT * 10)
 check(is_equal_approx(health - beetle.hp, 24.0), "Exposed beetle loses frontal guard and takes core bonus")
 reset_run("challenge", "thread")
 beetle = foe(3, Vector2(500, 400))
 beetle.dir = Vector2.RIGHT
 health = beetle.hp
 game.hurt_enemy(beetle, 20, Vector2.LEFT * 10)
 check(is_equal_approx(health - beetle.hp, 9.6), "Unexposed beetle retains original frontal protection")

func check_upgrade_pools():
 for route in ["saw", "thread", "coil"]:
  reset_run("challenge", route)
  var draft: Array = game.make_choices()
  check(draft.size() == 3 and draft.any(func(u): return u.get("route", "") == route),
   "Early choices include a route-specific blueprint: " + route)
  game.turret_level = 3; game.ricochets = 3; game.bolt_count = 6; game.reach = 225; game.interval = 0.2
  for blueprint in game.BLUEPRINTS: game.blueprints[blueprint.id] = blueprint.cap
  var valid := true
  for index in 100:
   draft = game.make_choices(index % 2 == 0)
   var ids := []
   if draft.size() != 3: valid = false
   for upgrade in draft:
    if upgrade.id in ids or upgrade.id in ["turret", "ricochet", "bolt", "range", "speed", "coil_orbit", "thread_return"]: valid = false
    ids.append(upgrade.id)
  check(valid, "Saturated build still yields three distinct valid choices: " + route)
 reset_run("challenge", "thread")
 game.xp = game.next_xp
 game.update_drops(0.01)
 var before: float = game.time_alive
 step(1.0)
 check(game.state == "upgrade" and game.time_alive == before, "Normal level-up pauses combat")
 var upgrade_count: int = game.test_stats.upgrades
 tap(KEY_1)
 check(game.state == "playing" and game.test_stats.upgrades == upgrade_count + 1, "Normal upgrade input selects one card")
 game.choose_upgrade(0)
 check(game.test_stats.upgrades == upgrade_count + 1, "Normal card cannot be applied twice")

func check_music_continuity():
 var director = game.music_director
 check(director != null and director.loaded and director.player.playing, "All music stems load and play through a single director")
 if director == null or not director.loaded: return
 var player_id: int = director.player.get_instance_id()
 var stream_id: int = director.player.stream.get_instance_id()
 await create_timer(0.3).timeout
 var before: float = director.playback_seconds()
 for state_name in ["playing", "paused", "upgrade", "route", "event_reward", "playing"]:
  director.update_mix(state_name, 0.8, false, 0.1)
 await create_timer(0.3).timeout
 var after: float = director.playback_seconds()
 check(director.player.get_instance_id() == player_id and director.player.stream.get_instance_id() == stream_id
  and director.player.playing, "Pause and card menus retain the same playing music instance")
 check(after > before and before > 0, "Music clock advances through menu transitions without restarting", {"before":before,"after":after})
 director.update_mix("playing", 1.0, false, 1.0)
 var intense: Vector3 = director.target_gains
 director.update_mix("upgrade", 1.0, false, 1.0)
 check(intense.y > director.target_gains.y and intense.z > director.target_gains.z, "Battle intensity raises drive layers and choices reduce them")
 director.update_mix("playing", 1.0, true, 2.0)
 check(director.current_volume < 0.00001 and director.player.playing, "Mute fades music gain without stopping its clock")

func check_blueprint_effects():
 reset_run("challenge", "saw")
 var target := foe(0, game.player + Vector2(80, 0))
 game.damage_context = "saw"
 var health: float = target.hp
 game.hurt_enemy(target, 20, Vector2.RIGHT)
 check(is_equal_approx(health - target.hp, 26.0), "Saw route adds its stated thirty percent saw damage")
 reset_run("challenge", "saw")
 game.blueprints = {"saw_mend":1}
 game.hp = 50
 game.attack_angle = 0
 for index in 6: foe(0, game.player + Vector2(65 + index * 4, index * 3), 1)
 game.land_attack()
 check(game.kills == 6 and game.hp == 53 and game.mend_this_swing == 3,
  "Saw repair heals at most three times per swing despite six kills")
 reset_run("challenge", "saw")
 game.blueprints = {"saw_open":1}
 target = foe(3, game.player + Vector2(80, 0))
 target.dir = Vector2.LEFT
 game.damage_context = "saw"
 health = target.hp
 game.hurt_enemy(target, 20, Vector2.RIGHT)
 check(target.exposed == 3 and is_equal_approx(health - target.hp, 26.0),
  "Armor nail opens frontal shell on the triggering saw hit")
 health = target.hp
 game.hurt_enemy(target, 20, Vector2.RIGHT)
 check(is_equal_approx(health - target.hp, 31.2), "Follow-up saw hit benefits from exposed core")
 reset_run("challenge", "coil")
 game.blueprints = {"coil_arc":1}
 var a := foe(0, Vector2(550, 400), 1)
 var b := foe(0, Vector2(610, 400), 1)
 var c := foe(0, Vector2(650, 400), 1)
 game.damage_context = "button"
 game.hurt_enemy(a, 50, Vector2.RIGHT)
 check(game.kills == 3 and b.hp <= 0 and c.hp <= 0 and game.chain_depth == 0,
  "Coil blueprint chains to nearby foes and terminates cleanly")
 var drops_before: int = game.drops.size()
 game.hurt_enemy(a, 50, Vector2.RIGHT)
 check(game.kills == 3 and game.drops.size() == drops_before, "Coil cascade does not repeat settled kills or loot")
 reset_run("challenge", "thread")
 game.blueprints = {"thread_energy":1}
 a = foe(0, Vector2(550, 400))
 b = foe(0, Vector2(650, 400))
 game.link_enemy(a)
 game.energy = 0
 game.cut_tether(game.tethers[0])
 check(game.energy == 15 and game.new_stats.cuts == 1, "Thread energy blueprint adds eight energy to a seven-energy cut")

func mouse_motion(position: Vector2):
 var event := InputEventMouseMotion.new()
 var physical_position: Vector2 = root.get_final_transform() * position
 event.position = physical_position
 event.global_position = physical_position
 Input.parse_input_event(event)
 Input.flush_buffered_events()

func mouse_button(position: Vector2, pressed: bool):
 var event := InputEventMouseButton.new()
 var physical_position: Vector2 = root.get_final_transform() * position
 event.position = physical_position
 event.global_position = physical_position
 event.button_index = MOUSE_BUTTON_LEFT
 event.pressed = pressed
 Input.parse_input_event(event)
 Input.flush_buffered_events()

func check_recent_fixes_and_modal_input():
 reset_run("challenge", "coil")
 game.blueprints = {"coil_capacitor":1}
 game.energy = 0
 game.hp = 50
 game.drop_loot(game.player, 18, true)
 game.drops[0].age = 1.0; game.drops[0].z = 0; game.drops[0].vz = 0; game.drops[0].vel = Vector2.ZERO
 game.update_drops(0.01)
 check(game.drops.is_empty() and game.hp == 68 and game.energy == 0,
  "Capacitor ignores collected medkits while healing still works")
 game.drop_loot(game.player, 2, false)
 game.drops[0].age = 1.0; game.drops[0].z = 0; game.drops[0].vz = 0; game.drops[0].vel = Vector2.ZERO
 game.update_drops(0.01)
 check(game.drops.is_empty() and game.xp == 2 and game.energy == 2,
  "Capacitor grants two energy for a collected battery")
 reset_run("challenge", "thread")
 var car := foe(1, Vector2(400, 400))
 var beetle := foe(3, Vector2(460, 400))
 car.phase = "charge"; car.timer = 0.001; car.dir = Vector2.RIGHT
 beetle.phase = "walk"; beetle.timer = 10; beetle.frozen = 1.0
 var health: float = beetle.hp
 game.update_enemies(0.05)
 check(car.phase == "recover" and beetle.hp < health and game.new_stats.rams == 1 and beetle.exposed > 0,
  "Car's final charge segment still rams before entering recovery")
 health = beetle.hp
 game.update_enemies(0.01)
 check(beetle.hp == health and game.new_stats.rams == 1,
  "Recovery frame cannot repeat the final charge hit")
 for result_state in ["dead", "won"]:
  reset_run("challenge", "thread")
  game.state = result_state
  game.time_alive = 42
  game.energy = 100
  tap(KEY_R)
  check(game.state == "playing" and game.time_alive == 0 and game.hp == 100 and game.energy == 30
   and game.overdrive_time == 0 and game.new_stats.overdrives == 0,
   "Result R starts a fresh run without overdrive: " + result_state)
 reset_run("challenge", "thread")
 game.state = "paused"
 var slider: Rect2 = game.music_slider_rect()
 var position := slider.position + Vector2(slider.size.x * 0.8, 2)
 mouse_motion(position)
 mouse_button(position, true)
 check(game.get_global_mouse_position().distance_to(position) < 0.1,
  "Headless viewport receives slider pointer position", {"actual":game.get_global_mouse_position(),"expected":position})
 check(game.state == "paused" and game.volume_drag and is_equal_approx(game.music_director.music_volume, 0.8),
  "Pause slider changes volume and consumes its click")
 # Drag deliberately over the resume-button area: only the slider owns this drag.
 position = Vector2(slider.position.x + slider.size.x * 0.3, 464)
 mouse_motion(position)
 check(game.state == "paused" and game.volume_drag and is_equal_approx(game.music_director.music_volume, 0.3),
  "Dragging volume over resume button does not resume gameplay")
 mouse_button(position, false)
 check(game.state == "paused" and not game.volume_drag,
  "Releasing volume drag does not leak a resume click")
 mouse_motion(Vector2(600, 460))
 mouse_button(Vector2(600, 460), true)
 mouse_button(Vector2(600, 460), false)
 check(game.state == "playing", "A separate explicit resume click still works")
