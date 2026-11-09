# File: res://tests/soak_story.gd
# Headless soak test: a long session that cycles through everything the smoke and story tests can drive, and fails on a
# leak (steady growth across cycles). One cycle =
#   - the 13 scenes of tests/smoke_all_stages.gd (menu, the 7 stages, FreeRoam, the 4 story levels), each instantiated
#     under the root, run SCENE_FRAMES frames, freed;
#   - CINES, each played to its end in a CinePlayer (empty world, manual steps, no music; a choice picks option 2), freed.
# After each cycle (everything freed, SETTLE_FRAMES frames later) it samples the node count, the object count, the orphan
# nodes (Performance.OBJECT_ORPHAN_NODE_COUNT), the static memory and the resource count, plus the frame time: the wall
# interval between scene frames (the loading frames left out; median and 90th percentile; headless Godot paces frames at
# the 6.9 ms low-processor sleep, so a frame that finished sooner reads 6.9 ms) and the wall time of a cinematic frame's
# steps. Performance.TIME_PROCESS is no use here: the monitor refreshes once a second.
# Cycle 1 is the warm-up (caches fill: CharacterBuilder materials, MusicDirector, StoryAudio, pools); its sample is the
# baseline. The object count is judged NET of the entries of the static mesh / material / texture caches (CACHE_SIZES):
# those are bounded by design but fill slowly, because the crowds draw random looks (PS2Head snaps its head keys to
# K_STEP, so a cycle keeps finding a few new keys: about +20 objects per cycle in the first minutes, shrinking). The raw
# object count and the cache entries are printed too. A metric LEAKS when all three hold after the baseline: it rose in
# at least 75 % of the cycle-to-cycle steps, its total growth is over the tolerance (nodes max(10, 0.5 %), net objects
# max(100, 1 %), orphans > 0, static memory max(4 MB, 1 %)), and it is not settling (the mean step of the later half is
# at least half the mean step of the earlier half: a cache that fills up, then stops, is not a leak; a leak keeps its pace).
# The frame time is reported and only warned about (a drift over 2x), because other Godot processes on the machine move it.
# SOAK_TRACE=1 also prints, per scene and cinematic, the objects and static memory it left behind, against the previous
# cycle: the place to look when a metric leaks.
# Length: SOAK_SECONDS (default 180 = about 3 minutes); the run ends at the first cycle end after it, and never before
# MIN_CYCLES cycles (1 warm-up + 3 measured). 30 minutes:  SOAK_SECONDS=1800 godot --headless --path . --script tests/soak_story.gd
# Temp user:// paths only (per process): the story save, the chapter / unlock files, the settings file; the music
# loader is a silent test stream (never the owner's user://music) and the SFX folders point at an empty temp folder.
# Not in the regression list on purpose (it is not a test_*.gd): run it on its own.
# Run:  godot --headless --path . --script tests/soak_story.gd
extends SceneTree

const SCENES: Array[String] = [
	"res://scenes/MainMenu.tscn",
	"res://scenes/Main.tscn",
	"res://scenes/Stage2_Parking.tscn",
	"res://scenes/Stage3_ClassroomFAP.tscn",
	"res://scenes/Stage4_Vovinam.tscn",
	"res://scenes/Stage5_Canteen.tscn",
	"res://scenes/Stage6_CapstoneBoss.tscn",
	"res://scenes/StageExtra_EOSExam.tscn",
	"res://scenes/FreeRoam.tscn",
	"res://scenes/story/NightBuilding.tscn",
	"res://scenes/story/StoryBasement.tscn",
	"res://scenes/story/StoryCanal.tscn",
	"res://scenes/story/StoryTower.tscn",
]
## Props and a scare, a villain card over a freeze frame, a choice, a 4-actor fight, the credits ending.
const CINES: Array[String] = ["cine_d0_midnight", "cine_d4_stare", "cine_d5_choice", "seg_d1_brawl", "end_c"]
const SCENE_FRAMES: int = 45
const LOAD_FRAMES: int = 15            # the first frames of a scene are left out of the frame time
const SETTLE_FRAMES: int = 5
const CINE_STEPS_PER_FRAME: int = 4
const MIN_CYCLES: int = 4
const DEFAULT_SECONDS: float = 180.0
const RISE_SHARE: float = 0.75
const MB: float = 1048576.0

var PID: int = OS.get_process_id()
var SAVE: String = "user://soak_story_%d.cfg" % PID
var UNLOCKS: String = "user://soak_story_%d_unlocks.cfg" % PID
var CHAPTERS: String = "user://soak_story_%d_chapters.cfg" % PID
var BACKUP: String = "user://soak_story_%d_backup.cfg" % PID
var SETTINGS: String = "user://soak_story_%d_settings.cfg" % PID
var SFX_DIR: String = "user://soak_story_%d_sfx/" % PID

var fails: Array[String] = []
var soak_s: float = DEFAULT_SECONDS
var trace: bool = false
var trace_prev: Dictionary = {}       # item -> [objects, static MB] it left behind in the previous cycle
var trace_last: Array[float] = []     # [objects, static MB] after the previous item
var last_us: int = 0
var frames: int = 0
var phase: String = "init"
var t_start: int = 0
var cycle: int = 0
var idx: int = 0
var pf: int = 0                       # frames in the current phase
var current: Node = null
var player: CinePlayer = null
var cine_done: Array = []
var cine_steps: int = 0
var cine_limit: int = 0
var scene_ms: Array[float] = []       # this cycle's steady scene frames
var cine_ms: Array[float] = []        # this cycle's cinematic frames
var samples: Array[Dictionary] = []   # one per cycle
var sd: Node = null
var fx: Node = null
var saved: Dictionary = {}


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  FAIL ", msg)


func _initialize() -> void:
	var env: String = OS.get_environment("SOAK_SECONDS")
	if env.is_valid_float() and float(env) > 0.0:
		soak_s = float(env)
	trace = OS.get_environment("SOAK_TRACE") == "1"
	print("=== SOAK: %d s (min %d cycles), %d scenes x %d frames + %d cinematics per cycle ===" % [int(soak_s), MIN_CYCLES, SCENES.size(), SCENE_FRAMES, CINES.size()])


func _process(_d: float) -> bool:
	frames += 1
	var now: int = Time.get_ticks_usec()
	var frame_ms: float = float(now - last_us) / 1000.0 if last_us > 0 else 0.0
	last_us = now
	match phase:
		"init":
			if frames < 2:
				return false
			_setup()
			t_start = Time.get_ticks_msec()
			_begin_cycle()
		"scene":
			pf += 1
			if pf > LOAD_FRAMES:
				scene_ms.append(frame_ms)
			if pf >= SCENE_FRAMES:
				current.queue_free()
				current = null
				Engine.time_scale = 1.0
				_go("scene_free")
		"scene_free":
			pf += 1
			if pf >= 2:
				_trace(SCENES[idx].get_file().get_basename())
				idx += 1
				if idx < SCENES.size():
					_load_scene()
				else:
					idx = 0
					_start_cine()
		"cine":
			var t0: int = Time.get_ticks_usec()
			_step_cine()
			cine_ms.append(float(Time.get_ticks_usec() - t0) / 1000.0)
		"cine_free":
			pf += 1
			if pf >= 2:
				_trace(CINES[idx])
				idx += 1
				if idx < CINES.size():
					_start_cine()
				else:
					_go("settle")
		"settle":
			pf += 1
			if pf >= SETTLE_FRAMES:
				_sample()
				var elapsed: float = float(Time.get_ticks_msec() - t_start) / 1000.0
				if cycle >= MIN_CYCLES and elapsed >= soak_s:
					return _end()
				_begin_cycle()
	return false


func _go(p: String) -> void:
	phase = p
	pf = 0


func _setup() -> void:
	sd = root.get_node_or_null("StoryDirector")
	fx = root.get_node_or_null("GameFX")
	_check(sd != null and fx != null, "the StoryDirector and GameFX autoloads are there")
	saved = {"unlocks": StoryChapters.unlocks_path, "chapters": StoryChapters.chapters_path, "backup": StoryChapters.backup_path,
		"bike_sfx": PlayerBike.sfx_dir, "story_sfx": StoryAudio.sfx_dir}
	StoryChapters.unlocks_path = UNLOCKS
	StoryChapters.chapters_path = CHAPTERS
	StoryChapters.backup_path = BACKUP
	PlayerBike.sfx_dir = SFX_DIR
	StoryAudio.sfx_dir = SFX_DIR
	MusicDirector.clear_cache()
	MusicDirector.test_loader = func(_s: String) -> AudioStream: return _silent_loop(0.5)
	if fx:
		saved["settings"] = fx.get("settings_path")
		fx.set("settings_path", SETTINGS)
	if sd:
		saved["save"] = sd.get("save_path")
		sd.set("nav_enabled", false)
		sd.set("save_path", SAVE)
		sd.call("reset_state")
		sd.call("new_story", {"female": false, "name": "Soak", "hair_style": "short", "variant": 0, "skin": 1, "hair_color": 0})


## A silent looping test stream standing in for an owner file (not game music; a new object each load, like a file read).
func _silent_loop(secs: float) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 11025
	var data := PackedByteArray()
	data.resize(int(secs * 11025.0) * 2)
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = int(secs * 11025.0)
	return w


func _begin_cycle() -> void:
	cycle += 1
	idx = 0
	trace_last = [Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.MEMORY_STATIC) / MB]
	scene_ms.clear()
	cine_ms.clear()
	_load_scene()


func _load_scene() -> void:
	var packed: PackedScene = load(SCENES[idx])
	current = packed.instantiate() if packed else null
	_check(current != null, "cycle %d: %s loads" % [cycle, SCENES[idx]])
	if current == null:
		_go("scene_free")
		return
	root.add_child(current)
	_go("scene")


func _start_cine() -> void:
	var s: String = CINES[idx]
	var tl: CineTimeline = CineTimeline.load_slot(s)
	_check(tl != null, "cycle %d: %s loads" % [cycle, s])
	if tl == null:
		_go("cine_free")
		return
	var world := Node3D.new()
	world.name = "SoakCine"
	root.add_child(world)
	current = world
	player = CinePlayer.new()
	world.add_child(player)
	var errs: PackedStringArray = player.setup(tl, Transform3D.IDENTITY, {"manual": true, "music": false})
	_check(errs.is_empty(), "cycle %d: %s sets up %s" % [cycle, s, str(errs)])
	if not errs.is_empty():
		_free_cine()
		return
	cine_done = []
	var box: Array = cine_done
	player.finished.connect(func(sk: bool) -> void: box.append(sk))
	player.start()
	cine_steps = 0
	cine_limit = int(tl.length * 60.0) + 60
	_go("cine")


func _step_cine() -> void:
	for k: int in CINE_STEPS_PER_FRAME:
		if not cine_done.is_empty() or cine_steps >= cine_limit:
			break
		if player.choice_node != null:
			player.choice_node.pick(1)
			cine_limit += 1
		player.step(1.0 / 60.0)
		cine_steps += 1
	if not cine_done.is_empty() or cine_steps >= cine_limit:
		_check(cine_done == [false], "cycle %d: %s plays to its end (%d steps)" % [cycle, CINES[idx], cine_steps])
		_free_cine()


func _free_cine() -> void:
	player = null
	if current:
		current.queue_free()
	current = null
	_go("cine_free")


func _sample() -> void:
	var s: Dictionary = {
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"cache_entries": float(_cache_entries()),
		"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / MB,
		"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"scene_ms": _pct(scene_ms, 0.5),
		"scene_p90": _pct(scene_ms, 0.9),
		"cine_ms": _pct(cine_ms, 0.5),
		"t_s": float(Time.get_ticks_msec() - t_start) / 1000.0,
	}
	s["net_objects"] = float(s.objects) - float(s.cache_entries)
	samples.append(s)
	print("  cycle %d at %.0f s: nodes %d, objects %d (%d cache entries, net %d), orphans %d, static %.1f MB, resources %d, scene frame %.2f ms median / %.2f ms p90, cinematic steps %.2f ms median" % [
		cycle, s.t_s, int(s.nodes), int(s.objects), int(s.cache_entries), int(s.net_objects), int(s.orphans), s.static_mb, int(s.resources), s.scene_ms, s.scene_p90, s.cine_ms])


## Entries of the static caches of built meshes, materials and textures (each entry holds about one object).
func _cache_entries() -> int:
	var n: int = 0
	for d: Dictionary in [CharacterBuilder._tex_cache, CharacterBuilder._mat_cache, CharacterBuilder._mesh_cache,
			CharacterBuilder._outline_cache, CharacterBuilder._scene_cache, CharacterBuilder._smooth_cache,
			CharacterBuilder._skin_cache, CharacterBuilder._base_cache, CharacterBuilder._body_fit_cache, PS2Head._mesh_cache,
			PropBuilder._palm_cache, PropBuilder._traffic_lamp_mats, MapBuilder._mats, MapBuilder._style_mats,
			FPTUCampusBuilder._materials_cache, FxPool._res, CrowdImpostors._bake_cache, RoamTraffic._pool_meshes,
			ViceStyle._lut_cache, ViceStyle._window_tex, Readability._mats, CineFX._tex_cache, CineAnimProp._tex]:
		n += d.size()
	return n


func _pct(a: Array[float], q: float) -> float:
	if a.is_empty():
		return 0.0
	var b: Array[float] = a.duplicate()
	b.sort()
	return b[mini(int(float(b.size()) * q), b.size() - 1)]


## Steady growth of one metric from the baseline (cycle 1) to the last cycle (see the header for the rule).
func _leak(key: String, abs_tol: float, rel_tol: float, unit: String) -> void:
	var base: float = float(samples[0][key])
	var last: float = float(samples[samples.size() - 1][key])
	var steps: int = samples.size() - 1
	var d: Array[float] = []
	for i: int in range(1, samples.size()):
		d.append(float(samples[i][key]) - float(samples[i - 1][key]))
	var rises: int = d.filter(func(x: float) -> bool: return x > 0.0).size()
	var half: int = steps / 2
	var early: float = 0.0
	var late: float = 0.0
	for i: int in half:
		early += d[i] / float(half)
		late += d[steps - half + i] / float(half)
	var settling: bool = half >= 1 and early > 0.0 and late < early * 0.5
	var tol: float = maxf(abs_tol, rel_tol * absf(base))
	var growth: float = last - base
	var per_cycle: float = growth / float(maxi(steps, 1))
	var steady: bool = rises >= int(ceil(RISE_SHARE * float(steps))) and growth > tol and not settling
	print("  %-11s baseline %.1f, last %.1f %s, growth %+.1f (%+.2f per cycle; early steps %+.2f, late %+.2f), rose %d of %d steps, tolerance %.1f -> %s" % [
		key, base, last, unit, growth, per_cycle, early, late, rises, steps, tol, "LEAK" if steady else ("ok (settling)" if settling and growth > tol else "ok")])
	_check(not steady, "%s grows steadily: %+.1f %s over %d cycles (%+.2f per cycle)" % [key, growth, unit, steps, per_cycle])


## SOAK_TRACE=1: what one scene or cinematic left behind (objects, static memory), against the previous cycle.
func _trace(item: String) -> void:
	if not trace:
		return
	var o: float = Performance.get_monitor(Performance.OBJECT_COUNT)
	var m: float = Performance.get_monitor(Performance.MEMORY_STATIC) / MB
	var d_o: int = int(o - trace_last[0])
	var d_m: float = m - trace_last[1]
	var prev: Array = trace_prev.get(item, [])
	var was: String = " (cycle %d: %+d, %+.2f MB)" % [cycle - 1, int(prev[0]), float(prev[1])] if prev.size() == 2 else ""
	print("    trace cycle %d %-20s objects %+d, static %+.2f MB%s" % [cycle, item, d_o, d_m, was])
	trace_prev[item] = [d_o, d_m]
	trace_last = [o, m]


func _end() -> bool:
	print("=== SOAK RESULT: %d cycles in %.0f s (cycle 1 = warm-up baseline) ===" % [samples.size(), float(Time.get_ticks_msec() - t_start) / 1000.0])
	_check(samples.size() >= MIN_CYCLES, "at least %d cycles ran" % MIN_CYCLES)
	if samples.size() >= 2:
		_leak("nodes", 10.0, 0.005, "")
		_leak("net_objects", 100.0, 0.01, "")
		print("  (raw objects %+d, of which %+d are new static cache entries)" % [
			int(samples[samples.size() - 1]["objects"] - samples[0]["objects"]), int(samples[samples.size() - 1]["cache_entries"] - samples[0]["cache_entries"])])
		_leak("orphans", 0.0, 0.0, "")
		_leak("static_mb", 4.0, 0.01, "MB")
		var f0: float = float(samples[1]["scene_p90"]) if samples.size() > 1 else 0.0
		var f1: float = float(samples[samples.size() - 1]["scene_p90"])
		var drift: String = "WARNING: over 2x the cycle 2 p90 (check other Godot processes before calling it a slowdown)" if f0 > 0.0 and f1 > f0 * 2.0 else "ok"
		print("  scene frame time p90: cycle 2 %.2f ms, last %.2f ms -> %s" % [f0, f1, drift])
	_teardown()
	if fails.is_empty():
		print("SUCCESS: SOAK (%d cycles, no steady growth of nodes, objects, orphans or static memory)" % samples.size())
		quit(0)
	else:
		print("FAILED: %d issues" % fails.size())
		quit(1)
	return true


func _teardown() -> void:
	MusicDirector.test_loader = Callable()
	MusicDirector.clear_cache()
	if saved.has("unlocks"):
		StoryChapters.unlocks_path = saved["unlocks"]
		StoryChapters.chapters_path = saved["chapters"]
		StoryChapters.backup_path = saved["backup"]
		PlayerBike.sfx_dir = saved["bike_sfx"]
		StoryAudio.sfx_dir = saved["story_sfx"]
	if fx and saved.has("settings"):
		fx.set("settings_path", saved["settings"])
	if sd and saved.has("save"):
		sd.set("save_path", saved["save"])
	for p: String in [SAVE, UNLOCKS, CHAPTERS, BACKUP, SETTINGS]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	if DirAccess.dir_exists_absolute(SFX_DIR):
		DirAccess.remove_absolute(SFX_DIR)
