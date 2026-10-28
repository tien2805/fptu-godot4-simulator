# File: res://tests/test_impact.gd
# Headless test of the Q2 impact recipe (scripts/combat/Impact.gd, plan 2026-10-29-q2-feel.md T1):
#   - the tier table (40 / 80 / 150 ms, punch 0.15 / 0.35 / 0.6, heavy knockback 1.5 m) and every ImpactAudio cue;
#   - hit-stops per tier in physics frames at the freeze scale, back to 1.0 after;
#   - skipped while another node owns the time scale (RadialWheel.scale_owner), the owner's scale untouched;
#   - light hit-stops never add up to more than 60 ms in any 0.2 s (a light hit every frame for 1 s);
#   - three heavy hits in one frame freeze once (the longest, not the sum);
#   - a slow motion queued after a finisher freeze, then 1.0; slowmo_active by requester; end_slowmo;
#   - yield_scale (a set piece takes over), a pause ends everything at once;
#   - a camera director stub gets punch(strength, dir) and slowmo_orbit(target, 0.5) on a last-enemy hit (0.3x for 0.5 s);
#     an fx_pool stub gets the tier's kinds; without them the shake_fn fallback and the clock's own WeaponFX;
#   - layered sound: the heavy layers, one copy per frame, the crowd "ồ" rate limit;
#   - the red screen-edge flash fades out; impact_react on the target.
# Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_impact.gd
extends SceneTree

var fails: Array[String] = []
var arena: Node3D


class Director:
	extends Node
	var punches: Array = []
	var shakes: Array = []
	var orbits: Array = []

	func punch(strength: float, dir: Vector3) -> void:
		punches.append([strength, dir])

	func shake(trauma: float) -> void:
		shakes.append(trauma)

	func slowmo_orbit(target: Node3D, secs: float) -> void:
		orbits.append([target, secs])


class Pool:
	extends Node
	var spawned: Array[String] = []

	func spawn(kind: String, _pos: Vector3, _dir: Vector3 = Vector3.UP, _scale: float = 1.0) -> void:
		spawned.append(kind)


class Target:
	extends Node3D
	var reacts: Array = []

	func impact_react(tier: String, dir: Vector3, _opts: Dictionary) -> String:
		reacts.append([tier, dir])
		return "flinch"


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  x ", msg)
	else:
		print("  ok ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	print("--- TEST IMPACT (Q2 shared recipe) ---")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


## Physics frames (from the next one on) that start with a frozen / slowed time scale, over n frames.
func _count_low(n: int, below: float = 0.5) -> int:
	var c: int = 0
	for i: int in n:
		await physics_frame
		if Engine.time_scale < below:
			c += 1
	return c


func _run() -> void:
	await _frames(1)
	arena = Node3D.new()
	arena.name = "Arena"
	root.add_child(arena)
	_data()
	var clock: Impact = Impact.clock(arena)
	_check(clock != null and clock.is_in_group(Impact.GROUP) and Impact.clock(arena) == clock, "one clock node in group impact_clock")
	await _frames(2)
	# ----- hit-stops per tier -----
	var expect: Dictionary = {"light": 2, "heavy": 5, "finisher": 9}
	for tier: String in ["light", "heavy", "finisher"]:
		await _frames(20)
		var r: Dictionary = Impact.hit(arena, tier, {"pos": Vector3(0.0, 1.0, 0.0), "dir": Vector3.FORWARD, "no_sound": true})
		_check(is_equal_approx(Engine.time_scale, Impact.HITSTOP_SCALE) and RadialWheel.scale_owner == clock, "%s: frozen at once (%.2f)" % [tier, Engine.time_scale])
		var n: int = await _count_low(20)
		_check(n == int(expect[tier]), "%s: hit-stop %d frames at 60 Hz (%d ms; got %d)" % [tier, int(expect[tier]), roundi(float(Impact.TIERS[tier]["hitstop"]) * 1000.0), n])
		_check(is_equal_approx(float(r["hitstop"]), float(expect[tier]) / 60.0), "%s: hit() reports %.3f s" % [tier, float(r["hitstop"])])
		_check(is_equal_approx(Engine.time_scale, 1.0) and RadialWheel.scale_owner == null, "%s: time scale back to 1.0, owner released" % tier)
	# ----- a foreign owner -----
	var wheel := Node.new()
	wheel.name = "FakeWheel"
	arena.add_child(wheel)
	RadialWheel.scale_owner = wheel
	Engine.time_scale = 0.5
	var sk0: int = clock.skipped
	var r2: Dictionary = Impact.hit(arena, "heavy", {"no_sound": true})
	await _frames(3)
	_check(is_zero_approx(float(r2["hitstop"])) and clock.skipped == sk0 + 1 and is_equal_approx(Engine.time_scale, 0.5) and RadialWheel.scale_owner == wheel,
		"skipped while another node owns the time scale (its 0.5 kept)")
	_check(not clock.slowmo(0.3, 0.3, self), "no slow motion over a foreign owner either")
	RadialWheel.scale_owner = null
	Engine.time_scale = 1.0
	await _frames(20)
	# ----- light cap: a light hit every frame for 1 s -----
	var lows: Array[bool] = []
	var granted: int = 0
	for i: int in 60:
		var r3: Dictionary = Impact.hit(arena, "light", {"no_sound": true, "no_fx": true, "no_punch": true})
		if float(r3["hitstop"]) > 0.0:
			granted += 1
		await physics_frame
		lows.append(Engine.time_scale < 0.5)
	await _frames(12)
	var worst: int = 0
	for s: int in range(0, lows.size() - 11):
		var c: int = 0
		for k: int in 12:
			if lows[s + k]:
				c += 1
		worst = maxi(worst, c)
	_check(worst <= 3 and worst >= 2, "light hit-stops: at most 3 frames (50 ms <= 60 ms) in any 0.2 s window (worst %d)" % worst)
	_check(clock.light_capped > 30 and granted >= 4, "most of 60 rapid light hits are capped (%d capped, %d granted)" % [clock.light_capped, granted])
	_check(is_equal_approx(Engine.time_scale, 1.0), "time scale 1.0 after the light burst")
	# ----- same-frame hits -----
	await _frames(20)
	var a: float = clock.hitstop(0.08, false, "heavy")
	var b: float = clock.hitstop(0.08, false, "heavy")
	var c2: float = clock.hitstop(0.08, false, "heavy")
	var n2: int = await _count_low(20)
	_check(a > 0.0 and is_zero_approx(b) and is_zero_approx(c2) and n2 == 5, "3 heavy hits in one frame: one 5-frame freeze (%.3f %.3f %.3f, %d frames)" % [a, b, c2, n2])
	# ----- slow motion queued after a finisher freeze -----
	await _frames(10)
	Impact.hit(arena, "finisher", {"no_sound": true})
	_check(clock.slowmo(0.3, 0.3, self) and clock.slowmo_active(self) and not clock.slowmo_active(wheel), "slow motion queued after the freeze (active for its requester only)")
	var frozen: int = 0
	var slowed: int = 0
	for i2: int in 40:
		await physics_frame
		if Engine.time_scale < 0.1:
			frozen += 1
		elif Engine.time_scale < 0.5:
			slowed += 1
	_check(frozen == 9 and slowed == 18 and is_equal_approx(Engine.time_scale, 1.0) and RadialWheel.scale_owner == null,
		"finisher: 9 frozen frames, then 18 frames at 0.3x (0.3 s), then 1.0 (%d, %d)" % [frozen, slowed])
	clock.slowmo(0.3, 2.0, self)
	await _frames(2)
	clock.end_slowmo(wheel)
	_check(clock.slowmo_active(self), "end_slowmo of another requester does nothing")
	clock.end_slowmo(self)
	await _frames(1)
	_check(is_equal_approx(Engine.time_scale, 1.0) and RadialWheel.scale_owner == null and not clock.slowmo_active(), "end_slowmo: 1.0 at once")
	# ----- yield and pause -----
	Impact.hit(arena, "finisher", {"no_sound": true})
	clock.slowmo(0.3, 1.0, self)
	Impact.yield_scale()
	_check(RadialWheel.scale_owner == null and is_equal_approx(Engine.time_scale, 1.0) and not clock.hitstop_active() and not clock.slowmo_active(), "yield_scale: a set piece takes over (freeze and queued slow motion dropped)")
	clock.slowmo(0.3, 2.0, self)
	await _frames(3)
	paused = true
	await process_frame
	await physics_frame
	await physics_frame
	_check(is_equal_approx(Engine.time_scale, 1.0) and RadialWheel.scale_owner == null, "a pause (cinematic) ends the slow motion at once")
	_check(is_zero_approx(clock.hitstop(0.08)), "no freeze while the tree is paused")
	paused = false
	await _frames(3)
	# ----- heavy / finisher caps -----
	await _frames(100)
	var hc0: int = clock.heavy_capped
	var h1: float = clock.hitstop(0.08, false, "heavy")
	await _frames(10)
	var h2: float = clock.hitstop(0.08, false, "heavy")
	_check(h1 > 0.0 and is_zero_approx(h2) and clock.heavy_capped == hc0 + 1, "a second heavy freeze within 0.4 s is capped (80 ms per 0.4 s)")
	await _frames(40)
	var fa: float = clock.hitstop(0.15, false, "finisher")
	await _frames(40)
	var fd0: int = clock.finisher_downgraded
	var fb: float = clock.hitstop(0.15, false, "finisher")
	_check(is_equal_approx(fa, 9.0 / 60.0) and fb <= 5.0 / 60.0 + 1e-4 and clock.finisher_downgraded == fd0 + 1, "one finisher freeze per 1.5 s, a second one freezes like a heavy (%.3f, %.3f)" % [fa, fb])
	await _frames(100)
	# ----- director, pool, target -----
	var dirn := Director.new()
	dirn.name = "Director"
	dirn.add_to_group("camera_director")
	arena.add_child(dirn)
	var pool := Pool.new()
	pool.name = "Pool"
	pool.add_to_group("fx_pool")
	arena.add_child(pool)
	var tgt := Target.new()
	tgt.name = "Target"
	arena.add_child(tgt)
	await _frames(1)
	var r4: Dictionary = Impact.hit(arena, "finisher", {"pos": Vector3(1.0, 1.0, 0.0), "dir": Vector3.RIGHT, "target": tgt, "last": true, "no_sound": true})
	_check(dirn.punches.size() == 1 and is_equal_approx(float(dirn.punches[0][0]), 0.6) and (dirn.punches[0][1] as Vector3).is_equal_approx(Vector3.RIGHT), "the director gets punch(0.6, the hit direction)")
	_check(dirn.orbits.size() == 1 and dirn.orbits[0][0] == tgt and is_equal_approx(float(dirn.orbits[0][1]), 0.5) and clock.orbit_count >= 1, "last enemy: the director's slowmo_orbit(target, 0.5)")
	_check(pool.spawned == ["dust_ring", "sparks", "debris"] and r4["fx"] == ["dust_ring", "sparks", "debris"], "the fx pool spawns the finisher kinds (%s)" % str(pool.spawned))
	_check(tgt.reacts.size() == 1 and String(tgt.reacts[0][0]) == "finisher" and String(r4["react"]) == "flinch", "impact_react(tier, dir) on the target")
	var f2: int = 0
	var s2: int = 0
	for i3: int in 50:
		await physics_frame
		if Engine.time_scale < 0.1:
			f2 += 1
		elif Engine.time_scale < 0.5:
			s2 += 1
	_check(f2 == 9 and s2 == 30 and is_equal_approx(Engine.time_scale, 1.0), "last enemy: the freeze, then 0.5 s at 0.3x (%d, %d)" % [f2, s2])
	pool.queue_free()
	dirn.queue_free()
	await _frames(2)
	# ----- fallbacks -----
	var got: Array = []
	Impact.punch(arena, 0.35, Vector3.FORWARD, func(s: float) -> void: got.append(s))
	_check(got == [0.35], "no director: the shake_fn fallback gets the strength")
	Impact.hit(arena, "heavy", {"no_sound": true})
	await _frames(1)
	_check(clock.own_fx() != null and clock.own_fx().is_inside_tree() and clock.fx_log.slice(-2) == ["dust_ring", "sparks"], "no fx pool: the clock's own WeaponFX bursts")
	await _frames(20)
	# ----- sound -----
	var n0: int = clock.cue_log.size()
	var r5: Dictionary = Impact.hit(arena, "heavy", {"no_hitstop": true})
	_check(r5["cues"] == ["whoosh_hit", "thud", "body", "crowd_oh"], "heavy sound layers: whoosh + thud + body + crowd (%s)" % str(r5["cues"]))
	var r6: Dictionary = Impact.hit(arena, "heavy", {"no_hitstop": true})
	_check((r6["cues"] as Array).is_empty(), "the same frame: no second copy of any layer")
	await _frames(10)
	var r7: Dictionary = Impact.hit(arena, "heavy", {"no_hitstop": true})
	_check((r7["cues"] as Array).has("thud") and not (r7["cues"] as Array).has("crowd_oh"), "the crowd 'ồ' at most every 1.2 s (%s)" % str(r7["cues"]))
	await _frames(80)
	var r8: Dictionary = Impact.hit(arena, "finisher", {"no_hitstop": true})
	_check((r8["cues"] as Array).has("sting") and (r8["cues"] as Array).has("crowd_oh"), "finisher: the meme sting and the crowd (%s)" % str(r8["cues"]))
	_check(clock.cue_log.size() > n0, "cues logged")
	# ----- edge flash -----
	Impact.edge_flash(arena)
	_check(clock.edge_strength() > 0.6 and clock.edge_flashes == 1, "the red edge flash shows")
	await _frames(30)
	_check(is_zero_approx(clock.edge_strength()), "... and fades out within 0.35 s")
	_finish()


func _data() -> void:
	_check(is_equal_approx(float(Impact.TIERS["light"]["hitstop"]), 0.04) and is_equal_approx(float(Impact.TIERS["heavy"]["hitstop"]), 0.08) and is_equal_approx(float(Impact.TIERS["finisher"]["hitstop"]), 0.15), "hit-stop 40 / 80 / 150 ms")
	_check(is_equal_approx(float(Impact.TIERS["light"]["punch"]), 0.15) and is_equal_approx(float(Impact.TIERS["heavy"]["punch"]), 0.35) and is_equal_approx(float(Impact.TIERS["finisher"]["punch"]), 0.6), "camera punch 0.15 / 0.35 / 0.6")
	_check(is_equal_approx(Impact.knock("heavy"), 1.5) and Impact.knock("finisher") > Impact.knock("heavy") and Impact.knock("light") < 0.5, "knockback: light flinch, heavy 1.5 m, finisher further")
	_check(is_equal_approx(Impact.LIGHT_CAP, 0.06) and is_equal_approx(Impact.LIGHT_WINDOW, 0.2) and is_equal_approx(Impact.ORBIT_S, 0.5), "light cap 60 ms per 0.2 s, orbit 0.5 s")
	for cue: String in ImpactAudio.CUES:
		var w: AudioStreamWAV = ImpactAudio.synth(cue)
		_check(w != null and w.data.size() > 400 and w.get_length() < 1.5, "ImpactAudio '%s' synthesized (%.2f s)" % [cue, w.get_length() if w else 0.0])


func _finish() -> void:
	Engine.time_scale = 1.0
	RadialWheel.scale_owner = null
	if arena and is_instance_valid(arena):
		arena.free()
	if fails.is_empty():
		print("SUCCESS: IMPACT (tiers, hit-stops, cap, owner rule, slow motion, director, pool, sound, edge flash)")
		quit(0)
	else:
		print("FAILED: %d issues" % fails.size())
		quit(1)
