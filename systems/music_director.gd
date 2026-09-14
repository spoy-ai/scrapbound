extends Node
## Three pre-rendered, phase-aligned stems. State changes never restart the score.

const STEM_PATHS := [
 "res://assets/v03/music/clockwork.wav",
 "res://assets/v03/music/drive.wav",
 "res://assets/v03/music/overdrive.wav"
]
const BPM := 140.0
const LOOP_SECONDS := 82.2857142857

var music_volume := 0.65
var player: AudioStreamPlayer
var synchronized: AudioStreamSynchronized
var loaded := false
var target_gains := Vector3(0.80, 0.035, 0.0)
var current_gains := Vector3.ZERO
var current_volume := 0.0
var latest_state := "menu"
var latest_intensity := 0.0
var last_muted := false

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 synchronized = AudioStreamSynchronized.new()
 synchronized.stream_count = STEM_PATHS.size()
 for index in STEM_PATHS.size():
  var stream := load(STEM_PATHS[index]) as AudioStreamWAV
  if stream == null:
   push_error("Music stem could not load: " + STEM_PATHS[index])
   return
  stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
  stream.loop_begin = 0
  stream.loop_end = 3628800
  synchronized.set_sync_stream(index, stream)
  synchronized.set_sync_stream_volume(index, -80.0)
 player = AudioStreamPlayer.new()
 player.name = "ClockworkScore"
 player.process_mode = Node.PROCESS_MODE_ALWAYS
 player.stream = synchronized
 player.volume_db = -80.0
 add_child(player)
 loaded = true
 player.play()

func set_music_volume(value: float) -> void:
 music_volume = clampf(value, 0.0, 1.0)

func update_mix(game_state: String, intensity: float, muted: bool, delta: float) -> void:
 latest_state = game_state
 latest_intensity = clampf(intensity, 0.0, 1.0)
 last_muted = muted
 if not loaded:
  return
 var drive := 0.79 + latest_intensity * 0.21
 var overdrive := smoothstep(0.25, 0.95, latest_intensity) * 0.94
 match game_state:
  "playing":
   target_gains = Vector3(0.90, drive, overdrive)
  "paused":
   target_gains = Vector3(0.34, 0.10, 0.0)
  "upgrade", "route", "event_reward":
   target_gains = Vector3(0.71, 0.19, 0.0)
  "dead":
   target_gains = Vector3(0.45, 0.0, 0.0)
  "won":
   target_gains = Vector3(0.85, 0.34, 0.13)
  _:
   target_gains = Vector3(0.80, 0.035, 0.0)
 # Exponential ramps are frame-rate independent and protect clicks on mute/pause.
 var blend := 1.0 - exp(-maxf(delta, 0.0) * 3.0)
 current_gains = current_gains.lerp(target_gains, blend)
 var desired_volume := 0.0 if muted else music_volume
 current_volume = lerpf(current_volume, desired_volume, 1.0-exp(-maxf(delta, 0.0)*7.0))
 player.volume_db = _gain_db(current_volume)
 for index in 3:
  synchronized.set_sync_stream_volume(index, _gain_db(current_gains[index]))

func playback_seconds() -> float:
 if not loaded:
  return 0.0
 return fposmod(player.get_playback_position(), LOOP_SECONDS)

func _gain_db(value: float) -> float:
 return -80.0 if value <= 0.0001 else linear_to_db(value)

func _exit_tree() -> void:
 if is_instance_valid(player):
  player.stop()
  player.stream = null
 synchronized = null
 loaded = false
