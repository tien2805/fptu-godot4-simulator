# File: res://tests/test_cine_d5_boss.gd
# Headless test of seg_d5_boss (spec C-D8 / C-D9, reworked by plan 2026-11-05-w6-fights) on tests/support/cine_brawl.gd:
# exactly 24.630 s, the ramps on the music's accents, the 4.5 s finisher swell and its 3 s tail, the hits taken at normal
# speed with punch-ins, contacts on every tier (the staff into the sheep, the wolf and the fox, Za Mẫn's overhead cut onto
# the raised staff, the staff onto the blocking katana, the flying kick, the two punches the protagonist takes), Za Mẫn
# into his own server rack, bodies, framing, FreeRoam staging for every Phase C slot and the skip. Gags: the bent katana is
# whole until the staff comes down (H4) while he blocks with it, then a snapped stub; the broken-off blade starts at
# mid-blade and lands clear of everyone; the flat cut misses the ducking protagonist's head and bites into a rack; the
# staff's tip is planted on the floor at the vault, both feet are off the ground at the kick, the dead rack after the crash.
# Run:  godot --headless --path . --script tests/test_cine_d5_boss.gd   (CINE_FAST=1 / CINE_NO_FREEROAM=1 / CINE_NO_MIXAMO=1)
extends "res://tests/support/cine_brawl.gd"

const PHASE_C: Array[String] = ["cine_d2_intro", "cine_d2", "seg_d2_boss", "cine_d3_intro", "cine_d3_mannequins", "cine_d3", "seg_d3_boss",
	"cine_d5_intro", "cine_d5_monitors", "cine_d5_choice", "cine_d5_choice_accept", "cine_d5_choice_refuse", "cine_d5", "seg_d5_boss", "end_c"]


func _conf() -> Dictionary:
	return {"slot": "seg_d5_boss", "length": 24.63, "finisher": "H5", "swell_end": 21.63, "tail": 3.0, "freezes": 5,
		"ramps": {"H1": 2.91, "H2": 6.19, "H3": 9.77, "A1": 11.65, "H4": 12.74, "H5": 17.13},
		"taken": {"X1": 3.82, "X2": 8.38},
		"touch": {"PARRY": 7.29},
		"strikes": {"H1": ["hero", "held:Staff", "sheep"], "X1": ["wolf", "fists", "hero"], "H2": ["hero", "held:Staff", "wolf"],
			"PARRY": ["za", "held:Katana", "hero:held:Staff"], "X2": ["fox", "fists", "hero"], "H3": ["hero", "held:Staff", "fox"],
			"H4": ["hero", "held:Staff", "za:held:Katana"], "H5": ["hero", "feet", "za"]},
		"slams": [["za", ["rack_x", "rack_x_dead"], 19.2, 19.4]],
		"lying": [["wolf", 7.6], ["fox", 11.2], ["wolf", 24.4], ["fox", 24.4]],
		"hit_vars": ["slam_s", "sc", "s_bite"],
		"not_solid": ["staff_v", "staff_crate", "blade"],
		"held": [["hero", "Staff", 1.0, false], ["hero", "Staff", 2.5, true], ["hero", "Staff", 14.0, true], ["hero", "Staff", 18.0, false],
			["za", "Katana", 1.0, true], ["za", "Katana", 20.5, true]],
		"shown": [["staff_crate", 1.0, true], ["staff_crate", 2.5, false], ["blade", 12.5, false], ["blade", 14.5, true],
			["staff_v", 15.0, false], ["staff_v", 18.5, true], ["rack_x", 19.0, true], ["rack_x", 19.6, false], ["rack_x_dead", 19.0, false],
			["rack_x_dead", 19.6, true]],
		"gone": [["sheep", 21.0, true], ["sheep", 24.5, false]],
		"keep": ["rack_x", "rack_x_dead", "rack_a"],
		"stages": PHASE_C, "checks": _gags}


func _katana(a: CineActor) -> String:
	var h: Dictionary = _hold_of(a, "Katana")
	if h.is_empty():
		return "none"
	return "bent" if (h["node"] as Node3D).find_child("Tip", false, false) != null else "broken"


func _gags(_t: Object, pl: CinePlayer) -> void:
	var za: CineActor = pl.actors["za"]
	var hero: CineActor = pl.actors["hero"]
	var consts: Dictionary = (tl.get_script() as GDScript).get_script_constant_map()
	# the bent katana snaps on the staff at H4 while he blocks with it; the blade starts at mid-blade
	var h4: float = float(tl.get("h4"))
	pl.seek(tl.clock.real_at(h4 - 0.15))
	var before: String = _katana(za)
	pl.seek(tl.clock.real_at(h4 - 0.01))
	var mv: String = String(za.active_move(pl.s).get("move", ""))
	var blade_before: bool = (pl.prop_nodes["blade"] as Node3D).visible
	pl.seek(tl.clock.real_at(h4 - 0.005))
	var kh: Dictionary = _hold_of(za, "Katana")
	var mid := Vector3.INF
	if not kh.is_empty():
		mid = _held_xf(za, kh) * Vector3(0.0, 0.0, -(0.08 + CinePropsC.KATANA_BLADE * 0.4))
	var path: Array = tl.props.filter(func(pr: Dictionary) -> bool: return pr["id"] == "blade")[0]["opts"]["path"]
	var start: Vector3 = path[0][1]
	var a_a1: Vector3 = tl.get("A_A1")
	var local: Vector3 = Basis(Vector3.UP, deg_to_rad(float(tl.get("y_zh")))).inverse() * (mid - a_a1)
	print("  katana mid-blade at H4 %s (Za Mẫn's frame %s), blade start %s: %.3f m" % [str(mid), str(local), str(start), mid.distance_to(start)])
	_check(mid.distance_to(start) < 0.15, "the snapped blade starts at the katana's mid-blade (%.3f m)" % mid.distance_to(start))
	pl.seek(tl.clock.real_at(h4) + 1.2)
	var after: String = _katana(za)
	_check(before == "bent" and after == "broken", "the bent katana snaps on the staff at H4 (%s -> %s)" % [before, after])
	_check(mv == "block_high", "Za Mẫn blocks with the katana over his head just before the blow (%s)" % mv)
	_check(not blade_before and (pl.prop_nodes["blade"] as Node3D).visible, "the broken-off blade appears and spins away")
	var land: Vector3 = path[path.size() - 1][1]
	for r: float in [14.5, 17.13, 20.0, 24.0]:
		pl.seek(r)
		for id: String in ["za", "hero", "sheep", "wolf", "fox"]:
			var ap: Vector3 = (pl.actors[id] as CineActor).position
			_check(Vector2(ap.x - land.x, ap.z - land.z).length() > 0.45, "%s does not stand on the landed blade at r %.1f" % [id, r])
	# the signature cut: flat over the ducking protagonist's head, its tip into a rack (sparks)
	var a1: float = float(tl.get("a1"))
	var miss: float = 99.0
	var miss_at: String = ""
	for k: int in 21:
		pl.seek(tl.clock.real_at(a1 - 0.3 + k * 0.03))
		var hk: Dictionary = _hold_of(za, "Katana")
		if hk.is_empty():
			continue
		var head: Array = Bodies.capsules(hero)
		var g: float = float(Bodies.gap_boxes([head[head.size() - 1]], _held_boxes(za, hk))["g"])
		if g < miss:
			miss = g
			miss_at = "r %.2f, head %s" % [pl.r, str(hero.bone_world("Head"))]
	print("  flat cut: nearest katana to the protagonist's head %.2f m (%s)" % [miss, miss_at])
	_check(miss > 0.08, "the flat cut misses the ducking protagonist (%.2f m)" % miss)
	pl.seek(tl.clock.real_at(float(tl.get("s_bite"))))
	var kb: Dictionary = _hold_of(za, "Katana")
	var bite: float = INF
	if not kb.is_empty():
		bite = float(Bodies.gap_boxes(_box_caps(_held_boxes(za, kb)), _prop_boxes(pl, "rack_a"))["g"])
	print("  the katana into rack_a at the bite: %.3f m" % bite)
	_check(bite < 0.03 and bite > -0.2, "the katana bites into the rack (%.3f m)" % bite)
	# the vault: the staff's tip on the floor at the take-off, both feet in the air at the kick, the staff lies on the floor
	var s_take: float = float(tl.get("s_take"))
	pl.seek(tl.clock.real_at(s_take - 0.01))
	var sh: Dictionary = _hold_of(hero, "Staff")
	var tip_h := Vector3(0.0, 99.0, 0.0)
	if not sh.is_empty():
		tip_h = _held_xf(hero, sh) * Vector3(0.0, 0.0, 0.45 - CinePropsC.STAFF_LEN)
	var tip_y: float = tip_h.y
	pl.seek(tl.clock.real_at(s_take + 0.01))
	var sv: Node3D = pl.prop_nodes["staff_v"]
	var tip_v: Vector3 = sv.global_transform * Vector3(0.0, 0.0, 0.45 - CinePropsC.STAFF_LEN)
	print("  vault: the held staff's tip %s, the planted staff's tip %s (plant %s; the protagonist at %s, yaw %.1f)" % [str(tip_h),
		str(tip_v), str(tl.get("PLANT")), str(hero.position), rad_to_deg(hero.rotation.y)])
	_check(Vector2(tip_h.x - tip_v.x, tip_h.z - tip_v.z).length() < 0.15, "the planted staff takes over where the held one's tip is (%.2f m)" % Vector2(tip_h.x - tip_v.x, tip_h.z - tip_v.z).length())
	_check(tip_y < 0.15, "the staff's tip reaches the floor at the take-off (y %.2f)" % tip_y)
	_check(tip_v.distance_to(tl.get("PLANT")) < 0.08 and tip_v.y > -0.02, "the planted staff stands on its tip (%s)" % str(tip_v))
	pl.seek(17.13)
	var feet: float = minf(hero.bone_world("Foot.L").y, hero.bone_world("Foot.R").y)
	var toes: float = minf(hero.bone_world("Toes.L").y if hero.sk.find_bone("Toes.L") >= 0 else 99.0, hero.bone_world("Toes.R").y if hero.sk.find_bone("Toes.R") >= 0 else 99.0)
	print("  flying kick: the protagonist's lowest foot %.2f m (toes %.2f)" % [feet, toes])
	_check(feet > 0.3, "both feet are off the ground at the kick (%.2f m)" % feet)
	pl.seek(20.5)
	var ends: Array[float] = [(sv.global_transform * Vector3(0.0, 0.0, 0.45)).y, (sv.global_transform * Vector3(0.0, 0.0, 0.45 - CinePropsC.STAFF_LEN)).y]
	_check(ends.max() < 0.12 and ends.min() > -0.02, "the dropped staff lies on the floor (%s)" % str(ends))
	# the crash: inside the swell, his rack's lights die
	var sc_r: float = tl.clock.real_at(float(tl.get("sc")))
	_check(sc_r > 17.33 and sc_r < 21.63 and tl.clock.speed_at(sc_r) < 0.5, "the crash (real %.2f) sits inside the slow-motion swell" % sc_r)
	_check(tl.fx.any(func(e: Dictionary) -> bool: return String(e["kind"]) == "sparks" and String(e["where"]) == "rack_x"), "the rack sparks")
	_check(tl.cues.any(func(c: Dictionary) -> bool: return c["actor"] == "hero" and String(c.get("move", "")) == "flying_kick"), "the flying kick")
	_check(tl.cues.any(func(c: Dictionary) -> bool: return c["actor"] == "za" and String(c.get("move", "")) == "katana_slash"), "the flat katana cut")
	var room: Dictionary = tl.props.filter(func(pr: Dictionary) -> bool: return pr["id"] == "room")[0]
	_check(absf(float(room["opts"].get("door_x", 99.0)) - (consts["EXIT"] as Vector3).x) < 0.01, "the server room has a doorway where the sheep runs out")
