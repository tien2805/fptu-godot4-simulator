# File: res://tests/test_cine_d1_brawl.gd
# Headless test of seg_d1_brawl (re-timed to the owner's track "I've Gotta Be Me", ~112 bpm): valid, exactly 25.000 s, every
# impact on its music onset within 0.5 ms (ramps placed by real time), the long finisher slow-mo ending at real 22.000 with a
# 3.000 s tail, the crate crash and the SFX accents on their onsets, the shot cuts, the committed beat sheet in sync (CRLF
# normalised); plays 1500 steps of 1/60 with actors inside the 14 x 10 m box; contacts within 0.6 m and lying bodies on the
# floor on every tier (cap 0 Mixamo when present, 1 UAL, 2 native, 3 code); a clear stage at the campus west gate; F9 plays
# it inside FreeRoam and a hold-Esc skip restores the world.
# Run:  godot --headless --path . --script tests/test_cine_d1_brawl.gd
# CINE_NO_MIXAMO=1 sets CineRetarget.disabled = ["mixamo"] before any check (covers the fallback tiers with files present).
# Every player built here passes {"music": false} (plan review B1): the test never depends on user://music.
extends SceneTree

## Real impact times (the track's strong onsets).
const IMPACTS: Dictionary = {"H1": 2.76, "A1": 6.15, "H2": 7.17, "H3": 8.48, "A2": 9.30, "H4": 10.14, "H5": 11.76, "H6": 12.71}
## Real start of every shot (cuts on onsets; S11 / S12 / S14 / S15 on the 112 bpm grid through the sustained note and tail).
const SHOTS: Dictionary = {"S1": 0.0, "S2": 1.45, "S3": 2.76, "S4": 5.89, "S5": 7.17, "S6": 7.72, "S7": 9.02, "S8": 9.83,
	"S9": 10.73, "S10": 12.13, "S11": 15.92, "S12": 19.14, "S13": 21.99, "S14": 22.53, "S15": 23.60}
## Non-ramp SFX accents on the remaining onsets (real s); 21.99 is the crash into the crate stack.
const ACCENTS: Array[float] = [3.02, 5.89, 7.72, 9.02, 12.13, 21.99]
const CRASH_R: float = 21.99
## Lying checks: [actor, real time] -> hips on the floor (code-tier lying height, plan Task 2 concern).
const LYING: Array = [["c2", 16.0], ["c3", 17.0], ["c1", 24.6]]
const GROUPS: Dictionary = {"hands": ["Wrist.L", "Wrist.R"], "feet": ["Foot.L", "Foot.R"], "knees": ["LowerLeg.L", "LowerLeg.R"],
	"torso": ["Hips", "Chest"]}
const HALF: Vector2 = Vector2(7.0, 5.0)

var fails: Array[String] = []
var phase: int = -1
var frames: int = 0
var world: Node3D
var p: CinePlayer
var tl: CineTimeline
var fr: Node
var ended: Array = []
var worst: Dictionary = {}


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _points(pl: CinePlayer, spec: String) -> Array[Vector3]:
	var parts: PackedStringArray = spec.split(":")
	var out: Array[Vector3] = []
	var a: CineActor = pl.actors[parts[0]]
	for bone: String in GROUPS.get(parts[1], [parts[1]]):
		out.append(a.bone_world(bone))
	return out


func _contacts(pl: CinePlayer, label: String) -> void:
	for row: Dictionary in tl.clock.ramps:
		if not row.has("att"):
			continue
		pl.seek(float(row["r_hit"]))
		var best: float = 99.0
		for x: Vector3 in _points(pl, String(row["att"])):
			for y: Vector3 in _points(pl, String(row["tgt"])):
				best = minf(best, x.distance_to(y))
		var who: String = String(row["att"]).get_slice(":", 0)
		var mv: Dictionary = (pl.actors[who] as CineActor).active_move(pl.s)
		print("  contact %-6s %-3s %.2f m  (%s %s)" % [label, String(row["name"]), best, String(mv.get("move", "?")),
			String((mv.get("res", {}) as Dictionary).get("tier", "?"))])
		_check(best < 0.6, "%s: %s contact %.2f m < 0.6" % [label, String(row["name"]), best])


func _lying(pl: CinePlayer, label: String) -> void:
	for e: Array in LYING:
		pl.seek(float(e[1]))
		var a: CineActor = pl.actors[String(e[0])]
		var hy: float = a.bone_world("Hips").y
		var lo: float = INF
		for b: String in ["Head", "Hips", "Chest", "Foot.L", "Foot.R", "Wrist.L", "Wrist.R"]:
			lo = minf(lo, a.bone_world(b).y)
		print("  lying  %-6s %s r %.1f: hips %.2f m, lowest bone %.2f m" % [label, String(e[0]), float(e[1]), hy, lo])
		_check(hy < 0.45 and lo > -0.08, "%s: %s lies on the floor at r %.1f (hips %.2f, lowest %.2f)" % [label, String(e[0]), float(e[1]), hy, lo])


func _initialize() -> void:
	print("--- TEST CINE seg_d1_brawl ---")
	if OS.get_environment("CINE_NO_MIXAMO") == "1":
		CineRetarget.disabled = PackedStringArray(["mixamo"])
		print("  CINE_NO_MIXAMO=1: mixamo source disabled")
	tl = CineTimeline.load_slot("seg_d1_brawl")
	_check(tl != null, "timeline loads")
	if tl == null:
		_end()
		return
	var errs: PackedStringArray = tl.validate()
	_check(errs.is_empty(), "valid: %s" % str(errs))
	_check(is_equal_approx(tl.length, 25.0) and absf(tl.clock.real_duration() - 25.0) < 0.0005, "exactly 25.000 s (%.5f)" % tl.clock.real_duration())
	var freezes: int = 0
	for row: Dictionary in tl.clock.ramps:
		freezes += 1 if float(row["freeze"]) > 0.0 else 0
	_check(tl.clock.ramps.size() == 8 and freezes == 6, "6 impacts + 2 accents (%d ramps, %d freezes)" % [tl.clock.ramps.size(), freezes])
	for nm: String in IMPACTS.keys():
		var rh: float = float(tl.clock.ramp(nm).get("r_hit", -1.0))
		_check(absf(rh - float(IMPACTS[nm])) < 0.0005, "%s real impact %.4f on the onset %.3f" % [nm, rh, float(IMPACTS[nm])])
	var fin: Dictionary = tl.clock.ramp("H6")
	_check(String(fin.get("preset", "")) == "finisher" and absf(float(fin.get("r1", 0.0)) - 22.0) < 0.0005, "finisher slow-mo ends at real 22.000")
	var tail: float = 25.0 - float(tl.clock.ramps[tl.clock.ramps.size() - 1]["r1"])
	_check(absf(tail - 3.0) < 0.0005, "normal-speed tail %.4f s = 3.000" % tail)
	_check(tl.shots.size() == SHOTS.size(), "%d shots" % SHOTS.size())
	for sh: Dictionary in tl.shots:
		var want: float = float(SHOTS.get(String(sh["id"]), -99.0))
		var got: float = tl.clock.real_at(float(sh["s"]))
		_check(absf(got - want) < 0.002, "shot %s real start %.3f (got %.3f)" % [String(sh["id"]), want, got])
	for ra: float in ACCENTS:
		var near: float = 99.0
		for e: Dictionary in tl.sfx:
			near = minf(near, absf(tl.clock.real_at(tl.story_time(e["at"])) - ra))
		_check(near < 0.0005, "SFX accent on the onset %.3f (off %.4f)" % [ra, near])
	var crash: bool = false
	for e2: Dictionary in tl.fx:
		if String(e2["kind"]) == "crate" and absf(tl.clock.real_at(tl.story_time(e2["at"])) - CRASH_R) < 0.0005:
			crash = true
	_check(crash, "the crate stack breaks at real %.2f" % CRASH_R)
	_check(tl.clock.speed_at(CRASH_R) > 0.0, "no freeze on the crash (tail rule)")
	for pr: Dictionary in tl.props:
		var pp: Vector3 = pr["pos"]
		_check(absf(pp.x) <= HALF.x and absf(pp.z) <= HALF.y, "prop %s inside the 14 x 10 box" % String(pr["id"]))
	var committed: String = FileAccess.get_file_as_string("res://docs/cinematics/seg_d1_brawl.txt").replace("\r\n", "\n")
	_check(committed == tl.beat_sheet(), "docs/cinematics/seg_d1_brawl.txt is in sync (run tools/cine_beats.gd)")
	world = Node3D.new()
	root.add_child(world)
	# nodes added in _initialize enter the tree only after it returns (actor global transforms need the tree)
	await process_frame
	CineMoves.max_tier = 1
	p = CinePlayer.new()
	world.add_child(p)
	_check(p.setup(tl, Transform3D.IDENTITY, {"manual": true, "music": false}).is_empty(), "sets up in an empty world")
	p.finished.connect(func(sk: bool) -> void: ended.append(sk))
	p.start()
	phase = 0


func _process(_d: float) -> bool:
	frames += 1
	match phase:
		0:
			var n: int = 0
			var outside: String = ""
			while ended.is_empty() and n < 1600:
				p.step(1.0 / 60.0)
				n += 1
				if outside == "" and n % 6 == 0:
					for id: String in p.actors.keys():
						var ap: Vector3 = (p.actors[id] as CineActor).position
						if absf(ap.x) > HALF.x or absf(ap.z) > HALF.y:
							outside = "%s at r %.2f (%.2f, %.2f)" % [id, p.r, ap.x, ap.z]
			_check(absi(n - 1500) <= 1 and ended == [false], "plays 1500 steps of 1/60 (%d)" % n)
			_check(outside == "", "actors stay inside the 14 x 10 box (%s)" % outside)
			var ms: float = p.frame_ms_total / maxf(float(p.frames), 1.0)
			_check(ms < 8.0, "frame update %.2f ms < 8 (4 actors)" % ms)
			_contacts(p, "ual")
			_lying(p, "ual")
			p.queue_free()
			var caps: Array[int] = [2, 3]
			if CineRetarget.available("mixamo"):
				caps.push_front(0)
			else:
				print("  SKIP mixamo contacts (no Mixamo files in res://assets/local/mixamo/ or CINE_NO_MIXAMO=1)")
			for cap: int in caps:
				CineMoves.max_tier = cap
				var label: String = ["mixamo", "ual", "native", "code"][cap]
				var pc := CinePlayer.new()
				world.add_child(pc)
				pc.setup(tl, Transform3D.IDENTITY, {"manual": true, "music": false})
				_contacts(pc, label)
				_lying(pc, label)
				pc.queue_free()
			CineMoves.max_tier = 0
			var ps: PackedScene = load("res://scenes/FreeRoam.tscn")
			fr = ps.instantiate()
			fr.set("crowd_enabled", false)
			root.add_child(fr)
			frames = 0
			phase = 1
		1:
			if frames < 3:
				return false
			var xf: Variant = fr.call("cine_stage", tl.stage)
			_check(xf is Transform3D, "clear 14 x 10 m stage near the west gate")
			var info: Dictionary = fr.get("cine_stage_info")
			print("  stage spot: %s" % str(info))
			_check(String(info.get("landmark", "")) == "campus_west_gate" and bool(info.get("road_aligned", false)),
				"stage at the west gate, road-aligned")
			if xf is Transform3D:
				var cl: Array = fr.call("cine_clutter", xf, tl.stage["size"])
				_check(cl.is_empty(), "no visual clutter inside the 14 x 10 box (%s)" % str(cl))
			ended.clear()
			fr.connect("cinematic_finished", func(slot: String, sk: bool) -> void: ended.append([slot, sk]))
			var cp: CinePlayer = fr.call("_play_next_cinematic")
			_check(cp != null and cp.timeline.slot == "seg_d1_brawl", "F9 plays seg_d1_brawl")
			if cp == null:
				return _end()
			_check(paused, "game paused during the cinematic")
			cp.force_skip_hold = true
			frames = 0
			phase = 2
		2:
			if not ended.is_empty():
				_check(ended[0] == ["seg_d1_brawl", true], "skip finished the cinematic: %s" % str(ended))
				_check(not paused and (fr.get("player") as Node3D).visible, "world restored")
				return _end()
			if frames > 2000:
				return _fail_end("skip never finished")
	return false


func _fail_end(msg: String) -> bool:
	_check(false, msg)
	return _end()


func _end() -> bool:
	if fails.is_empty():
		print("✅ SUCCESS: CINE seg_d1_brawl (25.000 s on the track's onsets, beat sheet, tiers, contacts, FreeRoam)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true
