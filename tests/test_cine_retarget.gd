# File: res://tests/test_cine_retarget.gd
# Headless test of the source-generic CineRetarget (spec A1-D2, A1-D5): UAL and native always; Mixamo when the owner's files
# are in res://assets/local/mixamo/ (otherwise SKIP). Checks: no NaN, flat-foot ankle height, flips turn the body over,
# horizontal root-motion strip, disabled-source hook, name helpers, sample cost; female rig with its own ankle / k bands.
# Run:  godot --headless --path . --script tests/test_cine_retarget.gd
# CINE_NO_MIXAMO=1 sets CineRetarget.disabled = ["mixamo"] before any check (covers the fallback path with files present).
extends SceneTree

const MIXAMO_EXPECTED: Array[String] = ["Jab_Cross", "Hook_Punch", "Uppercut", "Elbow_Punch", "Punch_Combo", "Roundhouse_Kick",
	"Flying_Kick", "Hurricane_Kick", "Front_Kick", "Mma_Kick", "Knee_Kick", "Front_Flip", "Back_Flip", "Running_Jump", "Cartwheel",
	"Running_Slide", "Dodging", "Block", "Stand_To_Roll", "Head_Hit", "Stomach_Hit", "Flying_Back_Death", "Knocked_Out",
	"Falling_Back_Death", "Sweep_Fall", "Getting_Up", "Taunt", "Victory", "Fighting_Idle", "Sprint", "Jumping_Down"]

var fails: Array[String] = []
var sk: Skeleton3D
var bd: Dictionary


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _ankle_y() -> float:
	var y: float = 99.0
	for s: String in ["L", "R"]:
		var lo: Transform3D = CharacterBuilder._bone_global_now(sk, sk.find_bone("LowerLeg." + s))
		y = minf(y, (lo.origin + lo.basis.y.normalized() * CineRetarget.ANKLE_DOWN_SHIN).y)
	return y


func _body() -> Transform3D:
	return CharacterBuilder._bone_global_now(sk, sk.find_bone("Body"))


func _nan(p: Dictionary) -> bool:
	for q: Quaternion in (p["rot"] as Dictionary).values():
		if is_nan(q.x) or is_nan(q.w):
			return true
	return false


## women/* rigs sit higher than men/* (rest ankle 0.132 vs 0.109, leg ratio k 1.109 vs 1.032): own bands.
func _female_checks() -> void:
	var fbody: Node3D = CharacterBuilder.build({"preset": "player", "seed": 7, "female": true, "rigged": true, "animate": false})
	_check(bool(fbody.get_meta("female", false)), "female rig built")
	sk = fbody.get_meta("skeleton") as Skeleton3D
	var ap: AnimationPlayer = fbody.get_node("Model").find_child("AnimationPlayer", true, false) as AnimationPlayer
	bd = CineRetarget.bind(sk, ap)
	CineRetarget.apply(sk, bd, CineRetarget.sample(bd, "ual1", "Idle", 0.5, true))
	var ay: float = _ankle_y()
	_check(ay > 0.05 and ay < 0.19, "female ual1 Idle ankle height %.3f in 0.05..0.19" % ay)
	if CineRetarget.available("mixamo") and CineRetarget.has_anim("mixamo", "Fighting_Idle"):
		var lo_y: float = 99.0
		for i: int in 8:
			CineRetarget.apply(sk, bd, CineRetarget.sample(bd, "mixamo", "Fighting_Idle", float(i) * 0.4))
			lo_y = minf(lo_y, _ankle_y())
		var k: float = float(bd["mixamo"]["k"])
		print("  female rig: mixamo Fighting_Idle lowest ankle %.3f, k = %.3f" % [lo_y, k])
		_check(lo_y > 0.12 and lo_y < 0.20, "female mixamo Fighting_Idle lowest ankle %.3f in 0.12..0.20" % lo_y)
		_check(k > 1.08 and k < 1.14, "female mixamo leg ratio k %.3f in 1.08..1.14" % k)
	fbody.free()


func _initialize() -> void:
	print("--- TEST CINE RETARGET ---")
	# CINE_NO_MIXAMO=1 forces the no-Mixamo path even when the owner's files are present (fallback tiers stay tested).
	var base_disabled := PackedStringArray()
	if OS.get_environment("CINE_NO_MIXAMO") == "1":
		base_disabled = PackedStringArray(["mixamo"])
		print("  CINE_NO_MIXAMO=1: mixamo source disabled")
	CineRetarget.disabled = base_disabled
	# Male rig pinned: the ankle bands below were measured on men/* (women/* rest ankle sits ~2.3 cm higher, k = 1.11).
	var body: Node3D = CharacterBuilder.build({"preset": "player", "seed": 7, "female": false, "rigged": true, "animate": false})
	sk = body.get_meta("skeleton") as Skeleton3D
	var ap: AnimationPlayer = body.get_node("Model").find_child("AnimationPlayer", true, false) as AnimationPlayer
	bd = CineRetarget.bind(sk, ap)
	# --- helpers
	_check(CineRetarget.clip_name_of("07_Flying_Kick.fbx") == "Flying_Kick", "clip_name_of strips NN_")
	_check(CineRetarget.clip_name_of("Taunt.fbx") == "Taunt", "clip_name_of keeps plain names")
	_check(CineRetarget.norm("mixamorig_LeftArm") == "LeftArm" and CineRetarget.norm("mixamorig:Hips") == "Hips", "norm strips both prefixes")
	# --- UAL + native (always present)
	_check(CineRetarget.available("ual1") and CineRetarget.available("ual2"), "UAL libraries load")
	var p: Dictionary = CineRetarget.sample(bd, "ual1", "Idle", 0.5, true)
	_check((p["rot"] as Dictionary).size() >= 45 and not _nan(p), "ual1 Idle: >= 45 bones, no NaN (got %d)" % (p["rot"] as Dictionary).size())
	CineRetarget.apply(sk, bd, p)
	var ay: float = _ankle_y()
	_check(ay > 0.03 and ay < 0.17, "ual1 Idle ankle height %.3f in 0.03..0.17 (flat feet)" % ay)
	var pn: Dictionary = CineRetarget.sample(bd, "native", "Kick_Right", 0.4)
	_check((pn["rot"] as Dictionary).size() >= 40, "native Kick_Right samples (%d bones)" % (pn["rot"] as Dictionary).size())
	var t0: int = Time.get_ticks_usec()
	for i: int in 50:
		CineRetarget.sample(bd, "ual2", "Melee_Hook", float(i) * 0.009)
	var us_ual: float = float(Time.get_ticks_usec() - t0) / 50.0
	_check(us_ual < 600.0, "UAL sample %.0f us < 600" % us_ual)
	# --- disabled hook
	var dis_ual1: PackedStringArray = base_disabled.duplicate()
	dis_ual1.append("ual1")
	CineRetarget.disabled = dis_ual1
	_check(not CineRetarget.available("ual1") and not CineRetarget.has_anim("ual1", "Idle"), "disabled source reports missing")
	CineRetarget.disabled = base_disabled
	_check(CineRetarget.available("ual1"), "re-enabled source is back")
	# --- Mixamo (optional)
	if not CineRetarget.available("mixamo"):
		print("  SKIP (%s)" % ("mixamo disabled by CINE_NO_MIXAMO=1" if base_disabled.has("mixamo") else "no Mixamo files in res://assets/local/mixamo/"))
	else:
		var have: PackedStringArray = CineRetarget.clips("mixamo")
		print("  mixamo clips: %d" % have.size())
		for nm: String in MIXAMO_EXPECTED:
			if not have.has(nm):
				print("  note: mixamo clip %s missing (fallback tier will play)" % nm)
				continue
			var ln: float = CineRetarget.anim_length("mixamo", nm)
			for u: float in [0.0, 0.5, 1.0]:
				var pm: Dictionary = CineRetarget.sample(bd, "mixamo", nm, ln * u, false, {"xz": true, "ref": 0.0})
				_check(not _nan(pm), "mixamo %s @%.0f%% no NaN" % [nm, u * 100.0])
		if have.has("Fighting_Idle"):
			var lo_y: float = 99.0
			for i: int in 8:
				CineRetarget.apply(sk, bd, CineRetarget.sample(bd, "mixamo", "Fighting_Idle", float(i) * 0.4))
				lo_y = minf(lo_y, _ankle_y())
			_check(lo_y > 0.05 and lo_y < 0.16, "mixamo Fighting_Idle lowest ankle %.3f in 0.05..0.16" % lo_y)
		if have.has("Front_Flip"):
			var up_min: float = 1.0
			for i: int in 26:
				CineRetarget.apply(sk, bd, CineRetarget.sample(bd, "mixamo", "Front_Flip", float(i) * 0.064))
				up_min = minf(up_min, _body().basis.y.normalized().dot(Vector3.UP))
			_check(up_min < -0.8, "mixamo Front_Flip turns the body over (min up·UP %.2f)" % up_min)
		if have.has("Flying_Kick"):
			var keep_d: float = 0.0
			var strip_d: float = 0.0
			CineRetarget.apply(sk, bd, CineRetarget.sample(bd, "mixamo", "Flying_Kick", 0.0))
			var b0: Vector3 = _body().origin
			for i: int in 16:
				var tt: float = float(i) * 0.1
				CineRetarget.apply(sk, bd, CineRetarget.sample(bd, "mixamo", "Flying_Kick", tt))
				keep_d = maxf(keep_d, Vector2(_body().origin.x - b0.x, _body().origin.z - b0.z).length())
				CineRetarget.apply(sk, bd, CineRetarget.sample(bd, "mixamo", "Flying_Kick", tt, false, {"xz": true, "ref": 0.0}))
				strip_d = maxf(strip_d, Vector2(_body().origin.x - b0.x, _body().origin.z - b0.z).length())
			_check(keep_d > 1.5, "Flying_Kick keeps its 2 m travel without strip (%.2f)" % keep_d)
			_check(strip_d < 0.35, "Flying_Kick in place with xz strip (drift %.2f)" % strip_d)
		var t1: int = Time.get_ticks_usec()
		for i: int in 50:
			CineRetarget.sample(bd, "mixamo", have[0], float(i) * 0.02, false, {"xz": true, "ref": 0.0})
		var us_mx: float = float(Time.get_ticks_usec() - t1) / 50.0
		_check(us_mx < 600.0, "Mixamo sample %.0f us < 600" % us_mx)
	body.free()
	_female_checks()
	if fails.is_empty():
		print("✅ SUCCESS: CINE RETARGET (UAL, native%s)" % (", mixamo" if CineRetarget.available("mixamo") else ", mixamo skipped"))
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
