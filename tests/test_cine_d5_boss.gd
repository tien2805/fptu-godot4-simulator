# File: res://tests/test_cine_d5_boss.gd
# Headless test of seg_d5_boss (spec C-D8 / C-D9, reworked by plan 2026-11-05-w6-fights and its fix round) on
# tests/support/cine_brawl.gd: exactly 22.430 s, the ramps on the music's accents, the 4.5 s finisher swell and its 3 s
# tail, the blocked punch and the one hit taken at normal speed with punch-ins, contacts on every tier (the staff into the
# sheep, the wolf and the fox, the wolf's right onto the staff across, Za Mẫn's overhead cut and his flat cut onto the
# staff, the staff onto the katana wedged in the rack, the flying kick, the fox's punch), Za Mẫn into the rack on the left
# wall, bodies, framing, FreeRoam staging for every Phase C slot and the skip. Gags: the bent katana is whole until the
# staff comes down on it in the rack (H4), then a snapped stub; the snapped blade starts at the bend and ends on the floor
# clear of everyone; the flat cut bites into a rack; the staff's tip is planted on the floor at the vault (no run-up),
# both feet are off the ground at the kick, the dead rack after the crash; the hand-off to cine_d5 (Za Mẫn seated at its
# spot, the hilt, the blade).
# Run:  godot --headless --path . --script tests/test_cine_d5_boss.gd   (CINE_FAST=1 / CINE_NO_FREEROAM=1 / CINE_NO_MIXAMO=1)
extends "res://tests/support/cine_brawl.gd"

const PHASE_C: Array[String] = ["cine_d2_intro", "cine_d2", "seg_d2_boss", "cine_d3_intro", "cine_d3_mannequins", "cine_d3", "seg_d3_boss",
	"cine_d5_intro", "cine_d5_monitors", "cine_d5_choice", "cine_d5_choice_accept", "cine_d5_choice_refuse", "cine_d5", "seg_d5_boss", "end_c"]


func _conf() -> Dictionary:
	return {"slot": "seg_d5_boss", "length": 22.43, "finisher": "H5", "swell_end": 19.43, "tail": 3.0, "freezes": 5,
		"ramps": {"H1": 2.91, "H2": 6.19, "H3": 9.77, "A1": 11.65, "H4": 12.74, "H5": 14.93},
		"taken": {"X1": 3.82, "X2": 8.38},
		"touch": {"PARRY": 7.29},
		"strikes": {"H1": ["hero", "held:Staff", "sheep"], "X1": ["wolf", "fists", "hero:held:Staff"], "H2": ["hero", "held:Staff", "wolf"],
			"PARRY": ["za", "held:Katana", "hero:held:Staff"], "X2": ["fox", "fists", "hero"], "H3": ["hero", "held:Staff", "fox"],
			"A1": ["za", "held:Katana", "hero:held:Staff"], "H4": ["hero", "held:Staff", "za:held:Katana"], "H5": ["hero", "feet", "za"]},
		"slams": [["za", ["rack_x", "rack_x_dead"], 17.05, 17.25]],
		"lying": [["wolf", 7.6], ["fox", 11.2], ["wolf", 22.3], ["fox", 22.3]],
		"seated": [["sheep", 5.0], ["sheep", 21.0], ["za", 19.6], ["za", 22.3]],
		"hit_vars": ["slam_s", "sc", "s_bite"],
		"not_solid": ["staff_v", "staff_crate", "blade"],
		"held": [["hero", "Staff", 1.0, false], ["hero", "Staff", 2.5, true], ["hero", "Staff", 13.5, true], ["hero", "Staff", 16.0, false],
			["za", "Katana", 1.0, true], ["za", "Katana", 21.0, true]],
		"shown": [["staff_crate", 1.0, true], ["staff_crate", 2.5, false], ["blade", 12.5, false], ["blade", 13.3, true],
			["staff_v", 14.0, false], ["staff_v", 16.5, true], ["rack_x", 17.0, true], ["rack_x", 17.3, false], ["rack_x_dead", 17.0, false],
			["rack_x_dead", 17.3, true]],
		"gone": [["sheep", 22.3, true]],
		"keep": ["rack_x", "rack_x_dead", "rack_a", "blade", "staff_v"],
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
	var y_bite: float = float(tl.get("y_bite"))
	var a_a1: Vector3 = tl.get("A_A1")
	var zb := Basis(Vector3.UP, deg_to_rad(y_bite))
	# the bent katana wedged in rack_a (bitten at s_bite, still in it as he yanks at H4), whole until the staff comes down on
	# it, then a stub; the snapped-off blade starts where the bent part was
	var h4: float = float(tl.get("h4"))
	pl.seek(tl.clock.real_at(h4 - 0.15))
	var before: String = _katana(za)
	pl.seek(tl.clock.real_at(h4 - 0.01))
	var mv: String = String(za.active_move(pl.s).get("move", ""))
	var blade_before: bool = (pl.prop_nodes["blade"] as Node3D).visible
	var kw: Dictionary = _hold_of(za, "Katana")
	var wedged: float = INF
	if not kw.is_empty():
		wedged = float(Bodies.gap_boxes(_box_caps(_held_boxes(za, kw)), _prop_boxes(pl, "rack_a"))["g"])
	print("  the katana into rack_a as the staff lands: %.3f m" % wedged)
	_check(wedged < 0.03, "the katana is still wedged in rack_a when the staff comes down (%.3f m)" % wedged)
	pl.seek(tl.clock.real_at(h4 - 0.005))
	var kh: Dictionary = _hold_of(za, "Katana")
	var bx := Transform3D(Basis.IDENTITY, Vector3.INF)
	if not kh.is_empty():
		var tip: Node3D = (kh["node"] as Node3D).find_child("Tip", false, false)
		if tip != null:
			bx = _held_xf(za, kh) * tip.transform * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.08))
	var path: Array = tl.props.filter(func(pr: Dictionary) -> bool: return pr["id"] == "blade")[0]["opts"]["path"]
	var start: Vector3 = path[0][1]
	var sb: Basis = Basis.from_euler((path[0][2] as Vector3) * (PI / 180.0))
	var ang: float = rad_to_deg((-bx.basis.z.normalized()).angle_to(-sb.z))
	var lb: Basis = zb.inverse() * bx.basis.orthonormalized()
	print("  the bent part at H4 %s (Za Mẫn's y_bite frame %s, rot %s), blade start %s: %.3f m, %.1f deg" % [str(bx.origin),
		str((zb.inverse() * (bx.origin - a_a1)).snapped(Vector3.ONE * 0.001)), str((lb.get_euler() * (180.0 / PI)).snapped(Vector3.ONE * 0.1)),
		str(start), bx.origin.distance_to(start), ang])
	_check(bx.origin.distance_to(start) < 0.08 and ang < 12.0, "the snapped blade starts where the bent part was (%.3f m, %.1f deg)" % [bx.origin.distance_to(start), ang])
	pl.seek(tl.clock.real_at(h4) + 1.2)
	var after: String = _katana(za)
	_check(before == "bent" and after == "broken", "the bent katana snaps on the staff at H4 (%s -> %s)" % [before, after])
	_check(mv == "yank", "Za Mẫn is wrenching at his wedged katana as the staff lands (%s)" % mv)
	_check(not blade_before and (pl.prop_nodes["blade"] as Node3D).visible, "the broken-off blade appears")
	# the blade drops out of the rack onto the floor and stays there, clear of everyone
	var land: Vector3 = consts["BLADE_LAND"]
	pl.seek(14.2)
	var bn: Node3D = pl.prop_nodes["blade"]
	var lo_y: float = INF
	var hi_y: float = -INF
	for b: Array in Bodies.prop_boxes(bn):
		var c: Transform3D = b[1]
		var hv: Vector3 = b[2]
		for k: int in 8:
			var q: Vector3 = c * Vector3(hv.x * (1.0 if k & 1 else -1.0), hv.y * (1.0 if k & 2 else -1.0), hv.z * (1.0 if k & 4 else -1.0))
			lo_y = minf(lo_y, q.y)
			hi_y = maxf(hi_y, q.y)
	print("  the blade at r 14.2: %s yaw %.1f, y %.3f..%.3f" % [str(bn.position), bn.rotation_degrees.y, lo_y, hi_y])
	_check(bn.position.distance_to(land) < 0.02 and absf(wrapf(bn.rotation_degrees.y - float(consts["BLADE_YAW"]), -180.0, 180.0)) < 1.0,
		"the blade comes to rest at its landing spot")
	_check(lo_y > -0.01 and hi_y < 0.08, "the blade lies flat on the floor (y %.3f..%.3f)" % [lo_y, hi_y])
	for r: float in [14.2, 14.93, 18.0, 22.3]:
		pl.seek(r)
		for id: String in ["za", "hero", "sheep", "wolf", "fox"]:
			var ap: Vector3 = (pl.actors[id] as CineActor).position
			_check(Vector2(ap.x - land.x, ap.z - land.z).length() > 0.45, "%s does not stand on the landed blade at r %.1f" % [id, r])
	# the flat cut is met on the upright staff, clear of the protagonist's head; it bites into rack_a
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
	_check(miss > 0.08, "the flat cut stops on the staff, clear of the protagonist's head (%.2f m)" % miss)
	pl.seek(tl.clock.real_at(float(tl.get("s_bite"))))
	var kb: Dictionary = _hold_of(za, "Katana")
	var bite: float = INF
	if not kb.is_empty():
		bite = float(Bodies.gap_boxes(_box_caps(_held_boxes(za, kb)), _prop_boxes(pl, "rack_a"))["g"])
	print("  the katana into rack_a at the bite: %.3f m" % bite)
	_check(bite < 0.03 and bite > -0.2, "the katana bites into the rack (%.3f m)" % bite)
	# the vault without a run-up: he plants the staff where he smashed the blade; the staff's tip on the floor at the
	# take-off, both feet in the air at the kick, the staff lies on the floor
	var s_take: float = float(tl.get("s_take"))
	pl.seek(tl.clock.real_at(h4 + 0.02))
	var p_h4: Vector3 = hero.position
	pl.seek(tl.clock.real_at(s_take - 0.01))
	var p_take: Vector3 = hero.position
	var runs: Array = tl.cues.filter(func(c: Dictionary) -> bool: return c["actor"] == "hero" and String(c.get("move", "")) in ["staff_run", "sprint", "run", "jog", "run_in"])
	print("  vault: the protagonist moves %.2f m from the smash to the take-off" % p_h4.distance_to(p_take))
	_check(runs.is_empty() and p_h4.distance_to(p_take) < 0.3, "no run-up before the vault (%.2f m, %d run cues)" % [p_h4.distance_to(p_take), runs.size()])
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
	pl.seek(tl.clock.real_at(float(tl.get("h5"))))
	var feet: float = minf(hero.bone_world("Foot.L").y, hero.bone_world("Foot.R").y)
	print("  flying kick: the protagonist's lowest foot %.2f m" % feet)
	_check(feet > 0.3, "both feet are off the ground at the kick (%.2f m)" % feet)
	pl.seek(18.5)
	var ends: Array[float] = [(sv.global_transform * Vector3(0.0, 0.0, 0.45)).y, (sv.global_transform * Vector3(0.0, 0.0, 0.45 - CinePropsC.STAFF_LEN)).y]
	_check(ends.max() < 0.12 and ends.min() > -0.02, "the dropped staff lies on the floor (%s)" % str(ends))
	# the crash: inside the swell, his rack's lights die
	var sc_r: float = tl.clock.real_at(float(tl.get("sc")))
	_check(sc_r > 15.13 and sc_r < 19.43 and tl.clock.speed_at(sc_r) < 0.5, "the crash (real %.2f) sits inside the slow-motion swell" % sc_r)
	_check(tl.fx.any(func(e: Dictionary) -> bool: return String(e["kind"]) == "sparks" and str(e["where"]) == "rack_x"), "the rack sparks")
	_check(tl.cues.any(func(c: Dictionary) -> bool: return c["actor"] == "hero" and String(c.get("move", "")) == "flying_kick"), "the flying kick")
	_check(tl.cues.any(func(c: Dictionary) -> bool: return c["actor"] == "za" and String(c.get("move", "")) == "katana_slash"), "the flat katana cut")
	# the hand-off: cine_d5 opens on this end state (Za Mẫn slumped at its spot hugging the hilt, the blade where it fell)
	var nx: CineTimeline = CineTimeline.load_slot("cine_d5")
	_check(nx != null, "cine_d5 loads")
	if nx == null:
		return
	pl.seek(tl.length - 0.01)
	var zk: Array = nx.cues.filter(func(c: Dictionary) -> bool: return c["type"] == "key" and c["actor"] == "za")
	var zh: Array = nx.cues.filter(func(c: Dictionary) -> bool: return c["type"] == "hold" and c["actor"] == "za" and c["kind"] == "katana")
	var nb: Array = nx.props.filter(func(pr: Dictionary) -> bool: return pr["id"] == "blade")
	var yz: float = rad_to_deg(za.rotation.y)
	if not zk.is_empty():
		print("  hand-off: Za Mẫn %s yaw %.1f, cine_d5 %s yaw %.1f" % [str(za.position), yz, str(zk[0]["pos"]), float(zk[0]["yaw"])])
	_check(not zk.is_empty() and za.position.distance_to(zk[0]["pos"]) < 0.05 and absf(wrapf(yz - float(zk[0]["yaw"]), -180.0, 180.0)) < 5.0,
		"cine_d5 opens with Za Mẫn where the fight leaves him")
	var last: Array = []
	for c: Dictionary in tl.cues:
		if c["type"] == "hold" and c["actor"] == "za":
			var ks: Array = (c["opts"] as Dictionary).get("keys", [])
			if bool((c["opts"] as Dictionary).get("broken", false)) and not ks.is_empty():
				last = ks[ks.size() - 1]
	_check(not zh.is_empty() and not last.is_empty() and bool((zh[0]["opts"] as Dictionary).get("broken", false))
		and (zh[0]["opts"]["rot"] as Vector3).is_equal_approx(last[1]) and (zh[0]["opts"]["offset"] as Vector3).is_equal_approx(last[2]),
		"cine_d5 opens with the hilt in Za Mẫn's hands as the fight leaves it")
	if not nb.is_empty():
		print("  hand-off: the blade %s yaw %.1f, cine_d5 %s yaw %.1f" % [str(land), float(consts["BLADE_YAW"]), str(nb[0]["pos"]), float(nb[0]["yaw"])])
	_check(not nb.is_empty() and (nb[0]["pos"] as Vector3).distance_to(land) < 0.05
		and absf(wrapf(float(nb[0]["yaw"]) - float(consts["BLADE_YAW"]), -180.0, 180.0)) < 5.0, "cine_d5 opens with the blade where it fell")
	var na: Array = nx.props.filter(func(pr: Dictionary) -> bool: return pr["id"] == "rack_a")
	var fa: Array = tl.props.filter(func(pr: Dictionary) -> bool: return pr["id"] == "rack_a")
	_check(not na.is_empty() and not fa.is_empty() and (na[0]["pos"] as Vector3).distance_to(fa[0]["pos"]) < 0.02
		and absf(wrapf(float(na[0]["yaw"]) - float(fa[0]["yaw"]), -180.0, 180.0)) < 1.0, "cine_d5 keeps the bitten rack where the fight has it")
	var nd: Array = nx.props.filter(func(pr: Dictionary) -> bool: return pr["id"] == "rack_l1")
	_check(not nd.is_empty() and bool((nd[0]["opts"] as Dictionary).get("dead", false)) and (nd[0]["pos"] as Vector3).distance_to(tl.get("RACK_X")) < 0.02,
		"cine_d5's rack behind Za Mẫn is the dead one he was kicked into")
