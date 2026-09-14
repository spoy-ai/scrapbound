extends SceneTree

var director: Node
var elapsed := 0.0
var report := {"checks": [], "positions": [], "errors": []}
var checkpoints := {}
var last_position := 0.0
var finishing := false
var capture: AudioEffectCapture
var recording: FileAccess
var captured_frames := 0

func _initialize() -> void:
 root.size = Vector2i(128, 80)
 capture = AudioEffectCapture.new()
 capture.buffer_length = 1.0
 AudioServer.add_bus_effect(0, capture)
 recording = FileAccess.open("res://captures/v03/music-runtime.f32", FileAccess.WRITE)
 director = load("res://systems/music_director.gd").new()
 root.add_child.call_deferred(director)

func check(label: String, condition: bool) -> void:
 report.checks.append({"label": label, "passed": condition, "test_seconds": elapsed, "captured_frames": captured_frames})
 if not condition:
  report.errors.append(label)

func once(label: String, after: float) -> bool:
 if elapsed >= after and not checkpoints.has(label):
  checkpoints[label] = true
  return true
 return false

func _process(delta: float) -> bool:
 if finishing: return false
 if capture.get_frames_available() > 0:
  var block := capture.get_buffer(capture.get_frames_available())
  for frame in block:
   recording.store_float(frame.x)
   recording.store_float(frame.y)
  captured_frames += block.size()
 elapsed += delta
 if not director.loaded:
  if elapsed > 2.0:
   check("all stems loaded", false)
   finish()
  return false
 var state := "playing"
 var intensity := 0.65
 var muted := false
 if elapsed < 1.0: state = "menu"
 elif elapsed < 3.0: state = "playing"
 elif elapsed < 4.0: state = "upgrade"
 elif elapsed < 5.0: state = "paused"
 elif elapsed < 6.0: muted = true
 director.update_mix(state, intensity, muted, delta)
 if once("loaded", 0.1):
  director.set_music_volume(-2.0)
  check("volume lower bound", director.music_volume==0.0)
  director.set_music_volume(3.0)
  check("volume upper bound", director.music_volume==1.0)
  director.set_music_volume(0.65)
  check("one synchronized player contains three stems", director.synchronized.stream_count == 3)
  for i in 3:
   var stream: AudioStreamWAV = director.synchronized.get_sync_stream(i)
   check("stem %d sample length" % i, absf(stream.get_length()-82.2857142857)<.0001)
   check("stem %d exact loop boundaries" % i, stream.loop_begin==0 and stream.loop_end==3628800 and stream.loop_mode==AudioStreamWAV.LOOP_FORWARD)
 if once("upgraded", 3.8):
  check("upgrade preserves playback", director.playback_seconds() > 3.0)
  check("upgrade reduces rhythm", director.current_gains.y < .3)
 if once("paused", 4.9):
  check("pause preserves playback", director.playback_seconds() > 4.0)
  check("pause reduces background", director.current_gains.x < .45)
 if once("muted", 5.95):
  check("mute fades player below minus 55 dB", director.player.volume_db < -55.0)
  check("mute keeps player running", director.player.playing)
 if once("unmute", 6.9):
  check("unmute restores volume", director.player.volume_db > -5.0)
 if once("seek", 7.0):
  # Test-only seek starts immediately before the end so the actual mixer crosses EOF.
  director.player.seek(80.0)
 if elapsed > 7.1 and once("position_%d" % int(elapsed*2), elapsed):
  report.positions.append({"test_seconds":elapsed,"playback_seconds":director.playback_seconds()})
 if once("loop", 10.3):
  check("all stems loop without stopping", director.player.playing and director.playback_seconds()<2.0)
 if elapsed > 11.0:
  finish()
 return false

func finish() -> void:
 if finishing: return
 finishing = true
 recording.close()
 report["captured_frames"] = captured_frames
 report["captured_sample_rate"] = AudioServer.get_mix_rate()
 report["capture_discarded_frames"] = capture.get_discarded_frames()
 var file := FileAccess.open("res://captures/v03/music-runtime-test.json", FileAccess.WRITE)
 file.store_string(JSON.stringify(report," "))
 print(JSON.stringify(report))
 director.queue_free()
 AudioServer.remove_bus_effect(0,0)
 capture = null
 await create_timer(0.20).timeout
 quit(0 if report.errors.is_empty() else 1)
