# File: res://tests/test_cine_d4_brawl.gd
# Headless test of seg_d4_brawl (spec B-D7 / B-D10, modelled on tests/test_cine_d1_brawl.gd): valid, exactly 25.000 s,
# slow motion on 4 impacts + 1 accent + the finisher swell, each on its real time within 0.5 ms, the swell ending at real
# 22.000 with a 3.000 s tail; the beat sheet in sync; plays 1500 steps of 1/60 with every actor inside the 14 x 10 m box;
# the improvised weapons held through their swings (tray, chair, soup pot; the pot then sits on C1's head); surface
# contact at every impact (fist / held prop to the target's bone capsules) <= 0.04 m on Mixamo and <= 0.15 m on the
# fallbacks, also for C3 slammed into the counter; lying bodies on the floor; no hips skating
# (<= 0.08 m per frame) through lie / sit transitions; bodies never sink into each other or the props (bone capsules,
# tests/support/cine_bodies.gd, every 1/60 s on every tier): <= 0.03 m, or within 0.08 story s of a hit <= 0.06 m for a
# striking limb and <= 0.04 m torso / head into torso / head; feet never more than 3 cm under the floor. Tiers: cap 0
# Mixamo when present, 1 UAL, 2 native, 3 code. Then in FreeRoam: cine_stage finds a spot for every Phase B slot, and
# play_cinematic stages seg_d4_brawl at the canteen, a hold-Esc skip restores the world.
# Run:  godot --headless --path . --script tests/test_cine_d4_brawl.gd
# CINE_NO_MIXAMO=1 sets CineRetarget.disabled = ["mixamo"] (covers the fallback tiers with files present).
# Every player built here passes {"music": false}: the test never depends on user://music.
extends SceneTree

const Bodies = preload("res://tests/support/cine_bodies.gd")

const IMPACTS: Dictionary = {"H1": 2.6, "H2": 5.9, "H3": 8.4, "H4": 11.2, "A1": 13.6, "H5": 15.0}
## Non-ramp hits the protagonist takes (real s): [name, real time].
const EXTRA_CONTACTS: Array = [["C2X", 3.9], ["C3J", 7.6], ["DH", 12.6]]
## Striking part per impact: [attacker, part (fists | tray | chair | pot), target].
const STRIKES: Dictionary = {"H1": ["hero", "tray", "c1"], "C2X": ["c2", "fists", "hero"], "H2": ["hero", "chair", "c2"],
	"C3J": ["c3", "fists", "hero"], "H3": ["hero", "fists", "c3"], "H4": ["hero", "pot", "c1"], "DH": ["dolly", "fists", "hero"],
	"H5": ["hero", "fists", "c1"]}
const HELD_NODE: Dictionary = {"tray": "Tray", "chair": "Chair", "pot": "SoupPot"}
const GAP_MIXAMO: float = 0.04
const GAP_OTHER: float = 0.15
const HALF: Vector2 = Vector2(7.0, 5.0)
const LYING: Array = [["c2", 9.6], ["c2", 16.0], ["c3", 12.0], ["c1", 24.6]]
const HIPS_STEP_MAX: float = 0.08
const LIE_MOVES: Array[String] = ["lie", "lie_flat", "get_up", "slumped", "get_up_sit"]
const PEN_MAX: float = 0.03
const PEN_HIT_LIMB: float = 0.06
const PEN_HIT_CORE: float = 0.04
const PEN_WINDOW: float = 0.08
const FOOT_FLOOR: float = -0.03
const PHASE_B: Array[String] = ["cine_d1_intro", "cine_d1_corridor", "cine_d1_choice", "cine_d1_choice_cover", "cine_d1_choice_report",
	"cine_d1", "cine_d4_intro", "cine_d4_stare", "seg_d4_brawl", "cine_d4"]

var fails: Array[String] = []
var phase: int = -1
var frames: int = 0
var world: Node3D
var p: CinePlayer
var tl: CineTimeline
var fr: Node
var ended: Array = []


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


## The hold entry of `kind` (tray | chair | pot) visible on the actor now, or {}.
func _hold_of(a: CineActor, kind: String) -> Dictionary:
	for h: Dictionary in a.holds:
		var n: Node3D = h["node"]
		if String(n.name).begins_with(String(HELD_NODE[kind])) and (h["att"] as Node3D).visible:
			return h
	return {}


func _held(a: CineActor, kind: String) -> Node3D:
	var h: Dictionary = _hold_of(a, kind)
	return h["node"] if not h.is_empty() else null


## World transform of a held prop from the bones as they stand now (BoneAttachment3D globals update late after a seek,
## as in test_cine_d1_brawl's helmet check).
func _held_xf(a: CineActor, h: Dictionary) -> Transform3D:
	var hx: Transform3D = a.sk.global_transform * CharacterBuilder._bone_global_now(a.sk, a.sk.find_bone(String(h["bone"])))
	return hx * (h["node"] as Node3D).transform


## Solid boxes of a held prop (Bodies.prop_boxes, placed with _held_xf).
func _held_boxes(a: CineActor, h: Dictionary) -> Array:
	var node: Node3D = h["node"]
	var nx: Transform3D = _held_xf(a, h)
	var inv: Transform3D = node.global_transform.affine_inverse()
	var out: Array = []
	for n: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		if mi.mesh == null:
			continue
		var ab: AABB = mi.mesh.get_aabb()
		var gx: Transform3D = nx * (inv * mi.global_transform)
		out.append([String(mi.name), Transform3D(gx.basis.orthonormalized(), gx * ab.get_center()), ab.size * gx.basis.get_scale() * 0.5])
	return out


func _strike_gap(pl: CinePlayer, who: String, part: String, target: String) -> Dictionary:
	var a: CineActor = pl.actors[who]
	var tc: Array = Bodies.capsules(pl.actors[target])
	if part == "fists":
		return Bodies.gap_spheres(Bodies.fists(a), tc)
	var h: Dictionary = _hold_of(a, part)
	if h.is_empty():
		return {"g": INF, "from": "no %s in hand" % part, "to": "?"}
	var r: Dictionary = Bodies.gap_boxes(tc, _held_boxes(a, h))
	return {"g": r["g"], "from": "%s %s" % [part, r["to"]], "to": r["from"]}


func _contacts(pl: CinePlayer, label: String) -> void:
	var lim: float = GAP_MIXAMO if label == "mixamo" else GAP_OTHER
	var rows: Array = []
	for rw: Dictionary in tl.clock.ramps:
		if STRIKES.has(String(rw["name"])):
			rows.append([String(rw["name"]), float(rw["r_hit"])])
	for ex: Array in EXTRA_CONTACTS:
		rows.append([String(ex[0]), float(ex[1])])
	for row: Array in rows:
		pl.seek(float(row[1]))
		var st: Array = STRIKES[row[0]]
		var res: Dictionary = _strike_gap(pl, String(st[0]), String(st[1]), String(st[2]))
		var mv: Dictionary = (pl.actors[String(st[0])] as CineActor).active_move(pl.s)
		print("  gap     %-6s %-3s %+.3f m  %s %s -> %s %s  (%s %s)" % [label, String(row[0]), float(res["g"]), st[0], res["from"], st[2],
			res["to"], String(mv.get("move", "?")), String((mv.get("res", {}) as Dictionary).get("tier", "?"))])
		_check(float(res["g"]) <= lim, "%s: %s surface gap %.3f m <= %.2f (%s %s -> %s %s)" % [label, String(row[0]), float(res["g"]), lim,
			st[0], res["from"], st[2], res["to"]])
		var deep: float = PEN_HIT_LIMB if String(st[1]) == "fists" else PEN_HIT_LIMB + 0.04
		_check(float(res["g"]) >= -deep, "%s: %s strike sinks %.3f m into the target (> %.2f)" % [label, String(row[0]), -float(res["g"]), deep])
	# C3 slammed back into the counter (C1 bursts the crates from just short of them: see _penetration)
	for pair: Array in [["c3", "counter", tl.story_time("H3"), tl.story_time("H3") + 0.7]]:
		var boxes: Array = Bodies.prop_boxes(pl.prop_nodes[String(pair[1])])
		var best: float = INF
		var bat: float = 0.0
		var r: float = tl.clock.real_at(float(pair[2]))
		while r <= tl.clock.real_at(float(pair[3])):
			pl.seek(r)
			var g2: float = float(Bodies.gap_boxes(Bodies.capsules(pl.actors[String(pair[0])]), boxes)["g"])
			if g2 < best:
				best = g2
				bat = r
			r += 1.0 / 60.0
		print("  gap     %-6s %s into the %s %+.3f m at r %.2f" % [label, pair[0], pair[1], best, bat])
		_check(best <= lim, "%s: %s reaches the %s, gap %.3f m <= %.2f" % [label, pair[0], pair[1], best, lim])


func _lying(pl: CinePlayer, label: String) -> void:
	for e: Array in LYING:
		pl.seek(float(e[1]))
		var a: CineActor = pl.actors[String(e[0])]
		var hy: float = a.bone_world("Hips").y
		var lo: float = INF
		for b: String in ["Head", "Hips", "Chest", "Foot.L", "Foot.R", "Wrist.L", "Wrist.R"]:
			lo = minf(lo, a.bone_world(b).y)
		print("  lying  %-6s %s r %.1f: hips %.2f m, lowest bone %.2f m" % [label, String(e[0]), float(e[1]), hy, lo])
		_check(hy < 0.45 and lo > -0.08, "%s: %s on the floor at r %.1f (hips %.2f, lowest %.2f)" % [label, String(e[0]), float(e[1]), hy, lo])


func _lie_transitions() -> Array:
	var by_actor: Dictionary = {}
	for c: Dictionary in tl.cues:
		if c["type"] != "move" and c["type"] != "strike":
			continue
		var st: float = float(c["s"])
		if c["type"] == "strike":
			var dur: float = float((c["opts"] as Dictionary).get("dur", CineMoves.MOVES[c["move"]]["dur"]))
			st = tl.story_time(c["at"]) - float(CineMoves.MOVES[c["move"]]["hit_u"]) * dur
		if not by_actor.has(c["actor"]):
			by_actor[c["actor"]] = []
		(by_actor[c["actor"]] as Array).append([st, String(c["move"])])
	var out: Array = []
	for id: String in by_actor.keys():
		var arr: Array = by_actor[id]
		arr.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		for i: int in arr.size():
			var prev: String = arr[i - 1][1] if i > 0 else ""
			if String(arr[i][1]) in LIE_MOVES or prev in LIE_MOVES:
				out.append([id, float(arr[i][0]), "%s->%s" % [prev, String(arr[i][1])]])
	return out


func _skate(pl: CinePlayer, label: String) -> void:
	var worst: float = 0.0
	var where: String = ""
	for t: Array in _lie_transitions():
		var a: CineActor = pl.actors[String(t[0])]
		var rt: float = tl.clock.real_at(float(t[1]))
		var r: float = maxf(rt - 0.3, 0.0)
		var prev: Variant = null
		while r <= minf(rt + 0.6, tl.length):
			pl.seek(r)
			var h: Vector3 = a.to_local(a.bone_world("Hips"))
			if prev != null and h.distance_to(prev) > worst:
				worst = h.distance_to(prev)
				where = "%s %s at r %.2f" % [String(t[0]), String(t[2]), r]
			prev = h
			r += 1.0 / 60.0
	print("  skate  %-6s max hips step %.3f m/frame (%s)" % [label, worst, where])
	_check(worst <= HIPS_STEP_MAX, "%s: hips step %.3f m/frame <= %.2f across lie / sit transitions (%s)" % [label, worst, HIPS_STEP_MAX, where])


func _penetration(pl: CinePlayer, label: String) -> void:
	var hits: Array[float] = []
	for rw: Dictionary in tl.clock.ramps:
		hits.append(float(rw["s"]))
	for ex: Array in EXTRA_CONTACTS:
		hits.append(tl.clock.story_at(float(ex[1])))
	var s_crash: float = float(tl.get("sc"))
	hits.append(s_crash)
	hits.append(float(tl.get("slam_s")))
	var boxes: Dictionary = {}
	for pk: String in ["counter", "crates", "table_a", "table_b"]:
		boxes[pk] = Bodies.prop_boxes(pl.prop_nodes[pk])
	var ids: Array = pl.actors.keys()
	var worst: Dictionary = {"d": -1.0, "what": "-"}
	var fail: String = ""
	var f: int = 0
	while f <= int(round(tl.length * 60.0)):
		var r: float = f / 60.0
		pl.seek(r)
		var near: bool = hits.any(func(h: float) -> bool: return absf(pl.s - h) <= PEN_WINDOW)
		var caps: Dictionary = {}
		for id: String in ids:
			caps[id] = Bodies.capsules(pl.actors[id])
		for i: int in ids.size():
			var a: CineActor = pl.actors[ids[i]]
			if not a.visible:
				continue
			for j: int in range(i + 1, ids.size()):
				var b: CineActor = pl.actors[ids[j]]
				if not b.visible or a.position.distance_to(b.position) > 2.6:
					continue
				var res: Dictionary = Bodies.actor_pair(caps[ids[i]], caps[ids[j]])
				var core: bool = Bodies.is_core(res["pa"]) and Bodies.is_core(res["pb"])
				var lim: float = (PEN_HIT_CORE if core else PEN_HIT_LIMB) if near else PEN_MAX
				var what: String = "%s %s / %s %s at r %.2f%s" % [ids[i], res["pa"], ids[j], res["pb"], r, " (hit)" if near else ""]
				if float(res["d"]) > float(worst["d"]):
					worst = {"d": res["d"], "what": what}
				if float(res["d"]) > lim and fail == "":
					fail = "%.3f m > %.2f: %s" % [res["d"], lim, what]
			for pk: String in boxes.keys():
				if pk == "crates" and pl.s > s_crash + 0.001:
					continue
				var rb: Dictionary = Bodies.actor_boxes(caps[ids[i]], boxes[pk])
				var limb: float = PEN_HIT_LIMB if near else PEN_MAX
				if float(rb["d"]) > limb and fail == "":
					fail = "%.3f m > %.2f: %s %s in the %s (%s) at r %.2f" % [rb["d"], limb, ids[i], rb["part"], pk, rb["box"], r]
				if float(rb["d"]) > float(worst["d"]):
					worst = {"d": rb["d"], "what": "%s %s in the %s at r %.2f" % [ids[i], rb["part"], pk, r]}
			for fb: String in ["Foot.L", "Foot.R"]:
				var fy: float = a.bone_world(fb).y
				if fy < FOOT_FLOOR and fail == "":
					fail = "%s %s %.3f m under the floor at r %.2f" % [ids[i], fb, -fy, r]
		f += 1
	print("  bodies %-6s worst penetration %.3f m (%s)" % [label, maxf(float(worst["d"]), 0.0), worst["what"]])
	_check(fail == "", "%s: bodies never sink in (%s)" % [label, fail])


## Held weapons: the tray before H1, the chair through H2, the pot through H4 and on C1's head after it.
func _weapons(pl: CinePlayer) -> void:
	var h: CineActor = pl.actors["hero"]
	var c1: CineActor = pl.actors["c1"]
	for e: Array in [["tray", 2.6], ["chair", 5.9], ["pot", 11.2]]:
		pl.seek(float(e[1]))
		var n: Node3D = _held(h, String(e[0]))
		_check(n != null and n.is_visible_in_tree(), "the %s is in the protagonist's hands at r %.1f" % [String(e[0]), float(e[1])])
	pl.seek(5.0)
	_check(not (pl.prop_nodes["chair"] as Node3D).visible and _held(h, "chair") != null, "the floor chair is picked up (prop hidden, held)")
	pl.seek(4.0)
	_check((pl.prop_nodes["chair"] as Node3D).visible and (pl.prop_nodes["pot"] as Node3D).visible, "chair and pot in place before they are used")
	pl.seek(13.0)
	_check(_held(h, "pot") == null and _held(c1, "pot") != null, "after H4 the pot sits on C1's head")
	if _held(c1, "pot") != null:
		var pc: Vector3 = _held_xf(c1, _hold_of(c1, "pot")).origin
		print("  pot on C1: %.2f m from his head bone" % pc.distance_to(c1.bone_world("Head")))
		_check(pc.distance_to(c1.bone_world("Head")) < 0.35, "the pot is on C1's head")
	pl.seek(24.5)
	_check(not (pl.actors["dolly"] as CineActor).visible, "Dolly has escaped by the tail")
	pl.seek(tl.clock.real_at(float(tl.get("s_gone"))) - 0.05)
	_check((pl.actors["dolly"] as CineActor).visible, "Dolly is still seen running just before the S13 -> S14 cut")
	var s14: float = tl.clock.real_at(float(tl.shots.filter(func(sh: Dictionary) -> bool: return sh["id"] == "S14")[0]["s"]))
	pl.seek(s14 + 0.01)
	_check(not (pl.actors["dolly"] as CineActor).visible, "Dolly is gone when the wide tail (S14) starts: no pop in view")
	# sheep masks: on C1 until the pot replaces it, on C2, C3 and Dolly throughout
	for e2: Array in [["c1", 2.6, true], ["c1", 13.0, false], ["c2", 5.9, true], ["c3", 8.4, true], ["dolly", 12.6, true], ["dolly", 1.0, true]]:
		pl.seek(float(e2[1]))
		var masked: bool = (pl.actors[String(e2[0])] as CineActor).holds.any(func(h: Dictionary) -> bool:
			return String((h["node"] as Node3D).name).begins_with("SheepMask") and (h["att"] as Node3D).visible)
		_check(masked == bool(e2[2]), "%s %s the sheep mask at r %.1f" % [String(e2[0]), "wears" if bool(e2[2]) else "no longer wears", float(e2[1])])
	# drop_set: the pure dressing (tables) is left out, the choreography props stay
	var pd := CinePlayer.new()
	world.add_child(pd)
	pd.setup(tl, Transform3D.IDENTITY, {"manual": true, "music": false, "drop_set": true})
	_check(not pd.prop_nodes.has("table_a") and not pd.prop_nodes.has("table_b") and pd.prop_nodes.has("counter") and pd.prop_nodes.has("crates"),
		"drop_set leaves out the carried tables and keeps the counter and crates")
	pd.queue_free()


func _initialize() -> void:
	print("--- TEST CINE seg_d4_brawl ---")
	if OS.get_environment("CINE_NO_MIXAMO") == "1":
		CineRetarget.disabled = PackedStringArray(["mixamo"])
		print("  CINE_NO_MIXAMO=1: mixamo source disabled")
	tl = CineTimeline.load_slot("seg_d4_brawl")
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
	_check(tl.clock.ramps.size() == 6 and freezes == 5, "slow motion on 4 impacts + the finisher + 1 accent (%d ramps, %d freezes)" % [tl.clock.ramps.size(), freezes])
	for nm: String in IMPACTS.keys():
		var rh: float = float(tl.clock.ramp(nm).get("r_hit", -1.0))
		_check(absf(rh - float(IMPACTS[nm])) < 0.0005, "%s real impact %.4f on %.3f" % [nm, rh, float(IMPACTS[nm])])
	var fin: Dictionary = tl.clock.ramp("H5")
	_check(String(fin.get("preset", "")) == "finisher" and absf(float(fin.get("r1", 0.0)) - 22.0) < 0.0005, "finisher swell ends at real 22.000")
	var tail: float = 25.0 - float(tl.clock.ramps[tl.clock.ramps.size() - 1]["r1"])
	_check(absf(tail - 3.0) < 0.0005, "normal-speed tail %.4f s = 3.000" % tail)
	var sc_r: float = tl.clock.real_at(float(tl.get("sc")))
	_check(sc_r > 15.2 and sc_r < 22.0 and tl.clock.speed_at(sc_r) < 0.5, "the crate crash (real %.2f) sits inside the slow-motion swell" % sc_r)
	for ex: Array in EXTRA_CONTACTS:
		_check(tl.clock.speed_at(float(ex[1])) > 0.99, "the hit the protagonist takes at %.1f plays at normal speed" % float(ex[1]))
		var hitp: bool = tl.punches.any(func(pu: Dictionary) -> bool: return absf(tl.clock.real_at(tl.story_time(pu["at"])) - float(ex[1])) < 0.0005)
		_check(hitp, "camera punch-in on the hit taken at %.1f" % float(ex[1]))
	var crash: bool = tl.fx.any(func(e: Dictionary) -> bool: return String(e["kind"]) == "crate" and String(e["where"]) == "crates")
	_check(crash, "the drink crates burst")
	var hero_o: Dictionary = tl.actors["hero"]["opts"]
	_check(String(hero_o.get("preset", "")) == "player", "the hero is the protagonist look (%s)" % str(hero_o))
	_check(String((tl.actors["dolly"]["opts"] as Dictionary).get("shirt_color", Color.BLACK).to_html(false)) == StoryCast.CREAM.to_html(false), "Dolly wears the cream cardigan")
	for pr: Dictionary in tl.props:
		var pp: Vector3 = pr["pos"]
		_check(absf(pp.x) <= HALF.x and absf(pp.z) <= HALF.y, "prop %s inside the 14 x 10 box" % String(pr["id"]))
	var committed: String = FileAccess.get_file_as_string("res://docs/cinematics/seg_d4_brawl.txt").replace("\r\n", "\n")
	_check(committed == tl.beat_sheet(), "docs/cinematics/seg_d4_brawl.txt is in sync (run tools/cine_beats.gd)")
	world = Node3D.new()
	root.add_child(world)
	await process_frame
	var gfx: Node = root.get_node_or_null("/root/GameFX")
	if gfx and gfx.has_method("set_art_style"):
		gfx.call("set_art_style", "vice", false)
	CharacterBuilder.ps2 = true
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
			print("  frame update %.2f ms (5 actors)" % ms)
			_check(ms < 8.0, "frame update %.2f ms < 8 (5 actors)" % ms)
			_contacts(p, "ual")
			_lying(p, "ual")
			_skate(p, "ual")
			if OS.get_environment("CINE_FAST") != "1":
				_penetration(p, "ual")
			_weapons(p)
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
				_skate(pc, label)
				if OS.get_environment("CINE_FAST") != "1":
					_penetration(pc, label)
				pc.queue_free()
			CineMoves.max_tier = 0
			if OS.get_environment("CINE_NO_FREEROAM") == "1":
				return _end()
			var ps: PackedScene = load("res://scenes/FreeRoam.tscn")
			fr = ps.instantiate()
			fr.set("crowd_enabled", false)
			root.add_child(fr)
			frames = 0
			phase = 1
		1:
			if frames < 3:
				return false
			for slot: String in PHASE_B:
				var t: CineTimeline = CineTimeline.load_slot(slot)
				var xf: Variant = fr.call("cine_stage", t.stage)
				var info: Dictionary = fr.get("cine_stage_info")
				print("  stage %-22s %s" % [slot, str(info)])
				_check(xf is Transform3D, "%s: a clear %s m stage spot in FreeRoam" % [slot, str(t.stage.get("size"))])
				if xf is Transform3D:
					_check(String(info.get("landmark", "")) == "@at" and float(info.get("ring", 99.0)) <= 4.0,
						"%s: staged within 4 m of its explicit point (got %s, ring %s)" % [slot, String(info.get("landmark", "")), str(info.get("ring"))])
			ended.clear()
			fr.connect("cinematic_finished", func(slot: String, sk: bool) -> void: ended.append([slot, sk]))
			var cp: Variant = fr.call("play_cinematic", tl, {})
			_check(cp is CinePlayer, "FreeRoam plays seg_d4_brawl at the canteen")
			if not cp is CinePlayer:
				return _end()
			_check(paused, "game paused during the cinematic")
			(cp as CinePlayer).force_skip_hold = true
			frames = 0
			phase = 2
		2:
			if not ended.is_empty():
				_check(ended[0] == ["seg_d4_brawl", true], "skip finished the cinematic: %s" % str(ended))
				_check(not paused and (fr.get("player") as Node3D).visible, "world restored")
				return _end()
			if frames > 2000:
				_check(false, "skip never finished")
				return _end()
	return false


func _end() -> bool:
	if fails.is_empty():
		print("✅ SUCCESS: CINE seg_d4_brawl (25.000 s, ramps, beat sheet, tiers, contacts, weapons, bodies, FreeRoam stages)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true
