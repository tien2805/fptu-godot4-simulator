# File: res://tools/mixamo_report.gd
# Owner tool (run by tools/import_mixamo.bat): lists the Mixamo clips found in res://assets/local/mixamo/, the expected ones
# that are missing, and checks every clip retargets onto a game body without NaN.
# Run:  godot --headless --path . --script tools/mixamo_report.gd
extends SceneTree

const EXPECTED: Array[String] = ["Jab_Cross", "Hook_Punch", "Uppercut", "Elbow_Punch", "Punch_Combo", "Roundhouse_Kick",
	"Flying_Kick", "Hurricane_Kick", "Front_Kick", "Mma_Kick", "Knee_Kick", "Front_Flip", "Back_Flip", "Running_Jump", "Cartwheel",
	"Running_Slide", "Dodging", "Block", "Stand_To_Roll", "Head_Hit", "Stomach_Hit", "Flying_Back_Death", "Knocked_Out",
	"Falling_Back_Death", "Sweep_Fall", "Getting_Up", "Taunt", "Victory", "Fighting_Idle", "Sprint", "Jumping_Down"]


func _initialize() -> void:
	if not CineRetarget.available("mixamo"):
		print("MIXAMO REPORT: khong co file nao trong %s (game van chay voi clip CC0 / tu dung)." % CineRetarget.MIXAMO_DIR)
		quit(1)
		return
	var body: Node3D = CharacterBuilder.build({"preset": "player", "seed": 1, "female": false, "rigged": true, "animate": false})
	var sk: Skeleton3D = body.get_meta("skeleton") as Skeleton3D
	var ap: AnimationPlayer = body.get_node("Model").find_child("AnimationPlayer", true, false) as AnimationPlayer
	var bd: Dictionary = CineRetarget.bind(sk, ap)
	var have: PackedStringArray = CineRetarget.clips("mixamo")
	var bad: int = 0
	for nm: String in have:
		var ln: float = CineRetarget.anim_length("mixamo", nm)
		var p: Dictionary = CineRetarget.sample(bd, "mixamo", nm, ln * 0.5)
		var ok: bool = (p["rot"] as Dictionary).size() >= 45
		for q: Quaternion in (p["rot"] as Dictionary).values():
			ok = ok and not is_nan(q.x)
		bad += 0 if ok else 1
		print("  %-20s %5.2f s  %s" % [nm, ln, "OK" if ok else "LOI"])
	var missing: Array[String] = []
	for nm: String in EXPECTED:
		if not have.has(nm):
			missing.append(nm)
	if not missing.is_empty():
		print("  Thieu (se dung clip du phong): ", ", ".join(missing))
	print("MIXAMO REPORT: %d clip, %d thieu, %d loi, k = %.3f" % [have.size(), missing.size(), bad, float(bd["mixamo"]["k"]) if bd.has("mixamo") else 0.0])
	body.free()
	quit(0 if bad == 0 else 1)
