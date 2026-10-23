# File: res://tests/test_cine_actor.gd
# Headless test of CineMoves + CineActor (spec A1-D4, A1-D5, A1-D21, A1-D22): tier resolution under every cap, impact frame
# alignment, piecewise clip-time mapping, reversed windows, pure function of story time, root keys and arcs, airborne
# extras for code-tier flips and kicks, lying / get-up code poses, look-at, expression cells (PS2) and textures (classic),
# visibility, evaluate cost; fix round: ankle-foot gap and no pop through additive leg layers, effector peak on the impact
# for code / native / UAL / Mixamo tiers, order-independent mutual look-at, code-pose crossfades without sag, place().
# Run:  godot --headless --path . --script tests/test_cine_actor.gd
# CINE_NO_MIXAMO=1 sets CineRetarget.disabled = ["mixamo"] before any check (covers the fallback path with files present).
extends SceneTree

var fails: Array[String] = []
var world: Node3D


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _actor(seed: int) -> CineActor:
	var a := CineActor.new()
	world.add_child(a)
	a.setup({"preset": "player", "seed": seed})
	return a


func _actor_m(seed: int, female: bool = false) -> CineActor:
	var a := CineActor.new()
	world.add_child(a)
	a.setup({"preset": "player", "seed": seed, "female": female})
	return a


## Distance (m) between the ankle carried by the shin and the ankle carried by the foot (Foot.L/R are IK targets under
## Root, so a layer that turns the leg without re-attaching the foot opens a gap). Rest frames, as CineRetarget attaches.
func _foot_gap(a: CineActor, side: String) -> float:
	var sk: Skeleton3D = a.sk
	var lb: int = sk.find_bone("LowerLeg." + side)
	var fb: int = sk.find_bone("Foot." + side)
	var l0: Transform3D = sk.get_bone_global_rest(lb)
	var f0: Transform3D = sk.get_bone_global_rest(fb)
	var ankle0: Vector3 = l0.origin + l0.basis.y.normalized() * CharacterBuilder.ANKLE_DOWN_SHIN
	var by_shin: Vector3 = CharacterBuilder._bone_global_now(sk, lb) * (l0.affine_inverse() * ankle0)
	var by_foot: Vector3 = CharacterBuilder._bone_global_now(sk, fb) * (f0.affine_inverse() * ankle0)
	return (sk.global_transform * by_shin).distance_to(sk.global_transform * by_foot)


## Effector metric in skeleton space (model frame: +Z forward), relative to the hips.
func _metric(a: CineActor, eff: String) -> float:
	var sk: Skeleton3D = a.sk
	var h: Vector3 = CharacterBuilder._bone_global_now(sk, sk.find_bone("Hips")).origin
	match eff:
		"wristL_z":
			return (CharacterBuilder._bone_global_now(sk, sk.find_bone("Wrist.L")).origin - h).z
		"wristR_z":
			return (CharacterBuilder._bone_global_now(sk, sk.find_bone("Wrist.R")).origin - h).z
		"footR_d":
			return (CharacterBuilder._bone_global_now(sk, sk.find_bone("Foot.R")).origin - h).length()
		"footL_d":
			return (CharacterBuilder._bone_global_now(sk, sk.find_bone("Foot.L")).origin - h).length()
		"footR_z":
			return (CharacterBuilder._bone_global_now(sk, sk.find_bone("Foot.R")).origin - h).z
		"kneeL_y":
			return (CharacterBuilder._bone_global_now(sk, sk.find_bone("LowerLeg.L")).origin - h).y
	return 0.0


## Story time of the effector's peak (first sample within 1 cm of the max) minus the strike's s_hit (1.0).
func _peak_offset(seed: int, cap: int, mv: String, eff: String, female: bool = false) -> Array:
	CineMoves.max_tier = cap
	var a: CineActor = _actor_m(seed, female)
	a.move(0.0, "fight_idle")
	var r: Dictionary = a.strike(1.0, mv)
	var c: Dictionary = a.active_move(1.0)
	var vals: Array[float] = []
	var ts: Array[float] = []
	var s: float = float(c["s"])
	while s <= float(c["s"]) + float(c["dur"]) + 1e-6:
		a.evaluate(s)
		vals.append(_metric(a, eff) * a.sk.global_transform.basis.get_scale().y)
		ts.append(s)
		s += 1.0 / 120.0
	var mx: float = vals.max()
	var t_pk: float = ts[0]
	for i: int in vals.size():
		if vals[i] >= mx - 0.01:
			t_pk = ts[i]
			break
	a.queue_free()
	CineMoves.max_tier = 0
	return [t_pk - 1.0, String(r.get("tier", "")) + " " + String(r.get("a", ""))]


## Max ankle gap on side and max Foot step (m per 1/120 s, in the body's own frame so root arcs do not count) through a
## strike at s_hit 1.0 followed by fight_idle.
func _gap_run(seed: int, cap: int, mv: String, side: String) -> Array:
	CineMoves.max_tier = cap
	var a: CineActor = _actor_m(seed)
	a.move(0.0, "fight_idle")
	var r: Dictionary = a.strike(1.0, mv)
	var c: Dictionary = a.active_move(1.0)
	var s_end: float = float(c["s"]) + float(c["dur"])
	a.move(s_end, "fight_idle")
	var gap: float = 0.0
	var gap_hit: float = 0.0
	var step: float = 0.0
	var step_s: float = 0.0
	var prev: Vector3 = Vector3.INF
	var s: float = float(c["s"]) - 0.2
	while s <= s_end + 0.4:
		a.evaluate(s)
		var g: float = _foot_gap(a, side)
		gap = maxf(gap, g)
		if absf(s - 1.0) < 0.5 / 120.0:
			gap_hit = g
		var fp: Vector3 = (CharacterBuilder._bone_global_now(a.sk, a.sk.find_bone("Foot." + side)).origin) * a.sk.global_transform.basis.get_scale().y
		if prev != Vector3.INF:
			if fp.distance_to(prev) > step:
				step = fp.distance_to(prev)
				step_s = s
		prev = fp
		s += 1.0 / 120.0
	a.queue_free()
	CineMoves.max_tier = 0
	return [gap, step, String(r.get("tier", "")) + " " + String(r.get("a", "")) + " + " + String(r.get("add", "")), gap_hit, step_s]


func _head_q(a: CineActor) -> Quaternion:
	return (a.sk.global_transform.basis * CharacterBuilder._bone_global_now(a.sk, a.sk.find_bone("Head")).basis).get_rotation_quaternion()


func _fix_round_checks() -> void:
	# --- additive leg layers keep the feet on the shins, deltas vanish at the window ends
	for e: Array in [[2, "roundhouse", "R"], [2, "knee_strike", "L"], [2, "knee_strike", "R"], [2, "uppercut", "R"]]:
		var g: Array = _gap_run(31, e[0], e[1], e[2])
		print("  gap %s cap %d side %s (%s): max %.3f m, at hit %.3f m, max foot step %.3f m at s %.3f" % [e[1], e[0], e[2], g[2], g[0], g[3], g[1], g[4]])
		_check(float(g[0]) < 0.05, "%s cap %d: ankle-foot gap %s %.3f m < 0.05" % [e[1], e[0], e[2], g[0]])
		_check(float(g[1]) < 0.08, "%s cap %d: no foot pop (max step %.3f m per 1/120 s)" % [e[1], e[0], g[1]])
	for mv: String in CineMoves.MOVES.keys():
		for en: Dictionary in CineMoves.MOVES[mv]["src"]:
			var add: String = String(en.get("add", ""))
			if add == "":
				continue
			var mag: float = 0.0
			for u: float in [0.0, 1.0]:
				for v: Variant in CineMoves.code_pose(add, u).values():
					mag = maxf(mag, (v as Vector3).length() if v is Vector3 else absf(float(v)))
			_check(mag < 1e-4, "%s: additive layer %s is zero at both window ends (%.4f)" % [mv, add, mag])
			var mid: float = 0.0
			for v2: Variant in CineMoves.code_pose(add, 0.5).values():
				mid = maxf(mid, (v2 as Vector3).length() if v2 is Vector3 else absf(float(v2)))
			_check(mid > 0.1, "%s: additive layer %s peaks mid-move (%.2f)" % [mv, add, mid])
	# --- impact frame: effector peak lands on s_hit (code tiers + re-measured native / Mixamo windows)
	var peaks: Array = [[3, "flying_kick", "footL_d"], [3, "roundhouse", "footR_d"], [3, "hurricane_kick", "footR_d"],
		[3, "knee_strike", "kneeL_y"], [2, "jab", "wristL_z"], [2, "cross", "wristR_z"], [2, "roundhouse", "footR_z"],
		[2, "knee_strike", "kneeL_y"], [1, "jab", "wristL_z"], [1, "cross", "wristR_z"]]
	if CineRetarget.available("mixamo"):
		peaks.append([0, "knee_strike", "kneeL_y"])
		peaks.append([0, "jab", "wristL_z"])
		peaks.append([0, "cross", "wristR_z"])
	for e2: Array in peaks:
		var po: Array = _peak_offset(32, e2[0], e2[1], e2[2])
		print("  peak %s cap %d (%s): %+.3f s from the hit" % [e2[1], e2[0], po[1], po[0]])
		_check(absf(float(po[0])) <= 0.06, "%s cap %d (%s): effector peak %+.3f s from the hit (±0.06)" % [e2[1], e2[0], po[1], po[0]])
	var pf: Array = _peak_offset(33, 2, "jab", "wristL_z", true)
	_check(absf(float(pf[0])) <= 0.06, "female native jab peak %+.3f s from the hit" % pf[0])
	# --- look-at depends only on s: mutual looks, seek t -> far -> t in both evaluation orders
	var la: CineActor = _actor_m(34)
	var lb: CineActor = _actor_m(35)
	la.key(0.0, Vector3(10.0, 0.0, 0.0), 0.0)
	lb.key(0.0, Vector3(10.0, 0.0, -3.0), PI)
	lb.key(9.0, Vector3(16.0, 0.0, -3.0), PI)
	la.move(0.0, "fight_idle")
	lb.move(0.0, "fight_idle")
	la.look(0.0, 20.0, lb)
	lb.look(0.0, 20.0, la)
	var res_ord: Array = []
	for order: Array in [[la, lb], [lb, la]]:
		for st: float in [2.0, 9.0, 2.0]:
			for x: CineActor in order:
				x.evaluate(st)
		res_ord.append([_head_q(la), _head_q(lb)])
	var drift_a: float = rad_to_deg((res_ord[0][0] as Quaternion).angle_to(res_ord[1][0]))
	var drift_b: float = rad_to_deg((res_ord[0][1] as Quaternion).angle_to(res_ord[1][1]))
	print("  look-at order drift: A %.3f°, B %.3f°" % [drift_a, drift_b])
	# 0.1°: float32 quaternions re-set from the same values differ by ~0.04° in angle_to (1 ulp near identity)
	_check(drift_a < 0.1 and drift_b < 0.1, "mutual look-at independent of evaluation order (A %.3f°, B %.3f°)" % [drift_a, drift_b])
	la.queue_free()
	lb.queue_free()
	# --- crossfade between two code poses does not sag toward the standing base (fall_back -> lie)
	CineMoves.max_tier = 3
	var cf: CineActor = _actor_m(36)
	cf.key(0.0, Vector3(-10.0, 0.0, 0.0), 0.0)
	cf.move(0.0, "knocked_out")
	cf.move(2.0, "lie")
	var ua: int = cf.sk.find_bone("UpperArm.L")
	cf.evaluate(1.99)
	var q0: Quaternion = CharacterBuilder._bone_global_now(cf.sk, ua).basis.get_rotation_quaternion()
	var sag: float = 0.0
	for sx: float in [2.03, 2.06, 2.09, 2.13]:
		cf.evaluate(sx)
		sag = maxf(sag, rad_to_deg(q0.angle_to(CharacterBuilder._bone_global_now(cf.sk, ua).basis.get_rotation_quaternion())))
	print("  code-pose crossfade sag: %.2f°" % sag)
	_check(sag < 2.0, "code-pose crossfade keeps the pose (shoulder moves %.2f° < 2)" % sag)
	cf.queue_free()
	CineMoves.max_tier = 0
	# --- place(): moving a key-less actor after a pre-roll evaluate re-anchors it
	var pl: CineActor = _actor_m(37)
	pl.move(0.0, "fight_idle")
	pl.evaluate(0.0)
	pl.place(Vector3(-8.0, 0.0, 2.0), 0.5)
	pl.evaluate(0.5)
	_check(pl.position.is_equal_approx(Vector3(-8.0, 0.0, 2.0)) and absf(pl.rotation.y - 0.5) < 1e-5, "place() re-anchors a key-less actor (%s)" % pl.position)
	pl.queue_free()


func _initialize() -> void:
	print("--- TEST CINE ACTOR ---")
	if OS.get_environment("CINE_NO_MIXAMO") == "1":
		CineRetarget.disabled = PackedStringArray(["mixamo"])
		print("  CINE_NO_MIXAMO=1: mixamo source disabled")
	print("  mixamo available: %s" % CineRetarget.available("mixamo"))
	world = Node3D.new()
	root.add_child(world)
	# nodes added in _initialize enter the tree only after it returns (global transforms need the tree), and the GameFX
	# autoload's _ready re-applies the saved art style then: wait one frame and force the vice style afterwards
	await process_frame
	CharacterBuilder.ps2 = true          # PS2 head with expression cells (vice style)
	# --- clip_time mapping
	var res := {"from": 0.0, "hit": 0.4, "to": 1.0, "hit_u": 0.5}
	_check(absf(CineMoves.clip_time(res, 1.0, 2.0, false) - 0.4) < 1e-6, "impact maps to the clip's hit frame")
	_check(absf(CineMoves.clip_time(res, 0.5, 2.0, false) - 0.2) < 1e-6, "first half linear to the hit")
	_check(absf(CineMoves.clip_time(res, 1.5, 2.0, false) - 0.7) < 1e-6, "second half linear from the hit")
	var rev := {"from": 1.2, "hit": -1.0, "to": 0.0, "hit_u": -1.0}
	_check(absf(CineMoves.clip_time(rev, 0.0, 1.0, false) - 1.2) < 1e-6 and absf(CineMoves.clip_time(rev, 1.0, 1.0, false)) < 1e-6, "from > to plays backwards")
	var lp := {"from": 0.5, "hit": -1.0, "to": 1.5, "hit_u": -1.0}
	_check(absf(CineMoves.clip_time(lp, 2.25, 9.0, true) - 0.75) < 1e-6, "loops wrap inside [from, to] at natural speed")
	# --- every move resolves under every cap, impact frames align
	var a: CineActor = _actor(11)
	for cap: int in [0, 1, 2, 3]:
		CineMoves.max_tier = cap
		for mv: String in CineMoves.MOVES.keys():
			var r: Dictionary = CineMoves.resolve(mv, a.bd)
			_check(not r.is_empty(), "move %s resolves at cap %d" % [mv, cap])
			if r.is_empty():
				continue
			if r["tier"] == "mixamo":
				_check(CineRetarget.available("mixamo"), "mixamo tier only with files")
			if r["tier"] != "code":
				_check(float(r["to"]) > 0.0 or float(r["from"]) > 0.0, "%s window non-empty (%s %s)" % [mv, r["t"], r["a"]])
			if CineMoves.is_strike(mv) and (r["tier"] != "code" or float(r["hit"]) >= 0.0):
				var x_hit: float = float(r["hit_u"]) * float(r["dur"])
				_check(absf(CineMoves.clip_time(r, x_hit, float(r["dur"]), false) - float(r["hit"])) < 1e-5, "%s impact frame aligned (%s)" % [mv, r["tier"]])
				_check(float(r["from"]) <= float(r["hit"]) and float(r["hit"]) <= float(r["to"]), "%s window from <= hit <= to (%s %s: %.2f/%.2f/%.2f)" % [mv, r["t"], r["a"], r["from"], r["hit"], r["to"]])
	CineMoves.max_tier = 3
	_check(CineMoves.resolve("flying_kick", a.bd)["tier"] == "code", "cap 3: flying kick uses the code pose")
	_check(CineMoves.resolve("jab", a.bd)["tier"] == "native", "cap 3: a move without a code entry falls back to its last tier")
	var hk: Dictionary = CineMoves.resolve("hurricane_kick", a.bd)
	_check(hk["tier"] == "code" and (hk["spin"] as Vector3).is_equal_approx(Vector3(0.0, -720.0, 0.0)), "cap 3: hurricane kick code spin is two full turns (y -720: impact facing the target at one turn, ends facing forward)")
	var lie_r: Dictionary = CineMoves.resolve("lie", a.bd)
	_check(lie_r["tier"] == "code" and lie_r["a"] == "lie_back", "cap 3: lie uses the lie_back code pose")
	_check(CineMoves.resolve("get_up", a.bd)["a"] == "getup", "cap 3: get_up uses the getup code pose")
	_check(not CineMoves.code_pose("lie_back", 0.0).is_empty() and not CineMoves.code_pose("getup", 0.5).is_empty(), "lie_back / getup code poses exist")
	CineMoves.max_tier = 1
	_check(CineMoves.resolve("jab", a.bd)["tier"] == "ual", "cap 1: jab from UAL")
	var lie_u: Dictionary = CineMoves.resolve("lie", a.bd)
	_check(lie_u["a"] == "Death01" and absf(float(lie_u["from"]) - 2.38) < 1e-6 and absf(float(lie_u["to"]) - 2.40) < 1e-6, "cap 1: UAL lie holds Death01 2.38-2.40")
	# native windows are authored on men/* clips; women/* clips hold the same keys 1.25x longer -> windows scale with the rig
	CineMoves.max_tier = 2
	var fem := CineActor.new()
	world.add_child(fem)
	fem.setup({"preset": "player", "seed": 18, "female": true})
	var masc := CineActor.new()
	world.add_child(masc)
	masc.setup({"preset": "player", "seed": 18, "female": false})
	var lie_m: Dictionary = CineMoves.resolve("lie", masc.bd)
	var lie_f: Dictionary = CineMoves.resolve("lie", fem.bd)
	var death_f: float = CineRetarget.anim_length("native", "Death", fem.bd)
	_check(absf(float(lie_m["from"]) - 1.05) < 1e-6, "male native lie window unscaled (%.3f)" % lie_m["from"])
	_check(absf(float(lie_f["from"]) - 1.05 * death_f / CineMoves.NATIVE_REF_LEN) < 1e-4 and float(lie_f["to"]) <= death_f + 1e-4 and float(lie_f["to"]) > death_f - 0.05,
		"female native lie window scaled to the clip end (%.3f-%.3f of %.3f)" % [lie_f["from"], lie_f["to"], death_f])
	fem.queue_free()
	masc.queue_free()
	CineMoves.max_tier = 0
	# --- pure function of story time
	a.move(0.0, "fight_idle")
	a.strike(1.0, "jab")
	a.strike(2.0, "hit_head")
	a.key(0.0, Vector3.ZERO, 0.0)
	a.key(2.0, Vector3(0.0, 0.0, 2.0), 0.0)
	a.key(3.0, Vector3(0.0, 0.0, 4.0), 0.0, Vector3.ZERO, "linear", 1.0)
	a.evaluate(2.3)
	var h1: Vector3 = a.bone_world("Head")
	a.evaluate(0.7)
	a.evaluate(2.3)
	_check(h1.distance_to(a.bone_world("Head")) < 1e-4, "evaluate(s) is a pure function of s")
	a.evaluate(2.5)
	_check(absf(a.position.y - 1.0) < 1e-4 and absf(a.position.z - 3.0) < 1e-4, "arc key: parabola apex 1.0 m at mid-span (y %.3f z %.3f)" % [a.position.y, a.position.z])
	var st: Dictionary = a.active_move(1.0)
	_check(st.get("move", "") == "jab" and absf(float(st["s"]) - (1.0 - 0.55 * 0.45)) < 1e-6, "strike starts so the impact lands on s_hit")
	# --- code-tier extras: flying kick is airborne, front flip turns over
	CineMoves.max_tier = 3
	var b: CineActor = _actor(12)
	b.key(0.0, Vector3(3.0, 0.0, 0.0), 0.0)
	b.move(0.0, "fight_idle")
	b.evaluate(0.0)
	var hips0: float = b.bone_world("Hips").y
	b.strike(2.0, "flying_kick")
	b.evaluate(2.0 - 0.55 + 0.375)     # middle of the air window [0.15, 0.6]
	_check(b.bone_world("Hips").y - hips0 > 0.5, "code flying kick lifts the body (%.2f m)" % (b.bone_world("Hips").y - hips0))
	var c: CineActor = _actor(13)
	c.key(0.0, Vector3(-3.0, 0.0, 0.0), 0.0)
	c.strike(2.0, "front_flip")
	var mv_c: Dictionary = c.active_move(2.0)
	c.evaluate(2.0)
	var up: float = c.spin.global_transform.basis.y.normalized().dot(Vector3.UP)
	_check(up < 0.0, "code front flip is upside down at the apex (up·UP %.2f)" % up)
	c.evaluate(float(mv_c["s"]) + float(mv_c["dur"]) + 0.01)
	_check(c.spin.global_transform.basis.y.normalized().dot(Vector3.UP) > 0.99, "upright again after the flip")
	# no keys: move extras must not accumulate across evaluations (spin z -80 scissor, returns after its air window)
	var e: CineActor = _actor(15)
	e.position = Vector3(6.0, 0.0, 0.0)
	e.strike(1.0, "scissor_takedown")
	e.evaluate(1.0)
	var sp1: Vector3 = e.spin.rotation
	var pos1: Vector3 = e.position
	e.evaluate(1.0)
	e.evaluate(1.0)
	_check(e.spin.rotation.is_equal_approx(sp1) and e.position.is_equal_approx(pos1), "no keys: extras do not accumulate (spin %s / %s)" % [sp1, e.spin.rotation])
	e.evaluate(5.0)
	_check(e.spin.rotation.length() < 1e-4 and e.position.is_equal_approx(Vector3(6.0, 0.0, 0.0)), "no keys: back home after the move")
	# lying and getting up (code tier): the body lies flat on the ground, then stands up again
	var f: CineActor = _actor(16)
	f.key(0.0, Vector3(0.0, 0.0, 6.0), 0.0)
	f.move(0.0, "lie")
	f.move(3.0, "get_up")
	f.evaluate(1.5)
	var head_lie: float = f.bone_world("Head").y
	var hips_lie: float = f.bone_world("Hips").y
	_check(head_lie < 0.45 and hips_lie < 0.45, "code lie_back: lying on the ground (head %.2f hips %.2f)" % [head_lie, hips_lie])
	var back: Vector3 = f.bone_world("Head") - f.bone_world("Hips")
	_check(back.z > 0.3, "code lie_back: on the back, head behind the hips (+Z, %.2f)" % back.z)
	f.evaluate(3.0 + 2.0 + 0.2)
	_check(f.bone_world("Head").y > 1.3 and f.spin.global_transform.basis.y.normalized().dot(Vector3.UP) > 0.99, "code getup ends standing (head %.2f)" % f.bone_world("Head").y)
	CineMoves.max_tier = 0
	# --- look-at, expression, visibility
	var d: CineActor = _actor(14)
	d.move(0.0, "fight_idle")
	d.key(0.0, Vector3(0.0, 0.0, -6.0), 0.0)
	d.evaluate(0.5)
	var fwd0: Vector3 = (d.bone_world("Head") - d.bone_world("Neck")).normalized()
	var head_basis0: Basis = d.sk.global_transform.basis * CharacterBuilder._bone_global_now(d.sk, d.sk.find_bone("Head")).basis
	d.look(1.0, 5.0, Vector3(-3.0, 1.5, -6.0))   # to the actor's left (actor faces -Z)
	d.evaluate(3.0)
	var head_basis1: Basis = d.sk.global_transform.basis * CharacterBuilder._bone_global_now(d.sk, d.sk.find_bone("Head")).basis
	var turn: float = rad_to_deg(head_basis0.get_rotation_quaternion().angle_to(head_basis1.get_rotation_quaternion()))
	_check(turn > 25.0 and turn < 75.0, "look-at turns the head 25-75° (%.0f°)" % turn)
	var turn_yaw: float = rad_to_deg((head_basis1 * head_basis0.inverse()).get_euler().y)
	_check(turn_yaw > 15.0, "look-at turns toward the target on the actor's left (+yaw, %.0f°)" % turn_yaw)
	_check(fwd0.length() > 0.5, "neck/head bones found")
	d.expr(4.0, "angry")
	d.evaluate(4.5)
	_check(d.face_mat != null and bool(d.face_mat.get_meta("ps2_face", false)), "PS2 actor has its own atlas face material")
	if d.face_mat:
		_check(d.face_mat.uv1_offset.is_equal_approx(PS2Head.cell_offset("angry")), "expression cell switches")
	d.show_at(6.0, false)
	d.evaluate(6.5)
	_check(not d.visible, "show_at hides the actor")
	d.evaluate(5.0)
	_check(d.visible, "and is visible before that")
	# --- classic style (ps2 = false): expressions swap the face texture, the atlas offset is never touched
	CharacterBuilder.ps2 = false
	var g: CineActor = _actor(17)
	CharacterBuilder.ps2 = true
	_check(g.face_mat != null and not bool(g.face_mat.get_meta("ps2_face", false)), "classic actor has its own face material")
	if g.face_mat:
		var skin_key: String = CharacterBuilder.SKIN_KEYS[int(g.body.get_meta("skin_idx", 1))]
		var sex: String = "f" if bool(g.body.get_meta("female", false)) else "m"
		var tex_open: Texture2D = g.face_mat.albedo_texture
		g.expr(1.0, "angry")
		g.evaluate(0.5)
		_check(g.face_mat.albedo_texture == tex_open, "classic: open face before the cue")
		g.evaluate(1.5)
		var tex_angry: Texture2D = CharacterBuilder._tex("char_face_%s%s_angry.png" % [skin_key, sex])
		_check(tex_angry != null and g.face_mat.albedo_texture == tex_angry, "classic: expression swaps the face texture")
		_check(g.face_mat.uv1_offset.is_equal_approx(Vector3.ZERO), "classic: face texture not shifted (uv1_offset %s)" % g.face_mat.uv1_offset)
		g.evaluate(0.5)
		_check(g.face_mat.albedo_texture == tex_open, "classic: back to the open face when evaluated before the cue")
	_fix_round_checks()
	# --- cost
	var t0: int = Time.get_ticks_usec()
	for i: int in 60:
		a.evaluate(float(i) * 0.05)
	var ms: float = float(Time.get_ticks_usec() - t0) / 60000.0
	_check(ms < 2.5, "evaluate %.2f ms < 2.5" % ms)
	print("  evaluate %.2f ms" % ms)
	if fails.is_empty():
		print("✅ SUCCESS: CINE ACTOR (tiers, alignment, pure evaluation, arcs, extras, lie/getup, look, cells, classic faces)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
