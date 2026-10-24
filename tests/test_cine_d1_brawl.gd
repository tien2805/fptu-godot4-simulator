# File: res://tests/test_cine_d1_brawl.gd
# Headless test of seg_d1_brawl (Nobody restage on the owner's track "I've Gotta Be Me", ~112 bpm): valid, exactly 25.000 s,
# slow motion only on 4 impacts + the finisher, each on its music onset within 0.5 ms (ramps placed by real time), the long
# finisher slow-mo ending at real 22.000 with a 3.000 s tail, the crate crash and the SFX accents on their onsets, the shot
# cuts, the held helmet and the punch-ins, the committed beat sheet in sync (CRLF normalised); plays 1500 steps of 1/60 with
# actors inside the 14 x 10 m box; surface contact at every impact (fist / head / shoulder / held helmet to the target's bone
# capsules) <= 0.04 m on Mixamo and <= 0.15 m on the fallbacks, also through the drive and for Mũ Đỏ into the scooter,
# lying bodies on the floor and no hips skating (<= 0.08 m per frame) through lie / get-up crossfades on every tier (cap 0 Mixamo when present, 1 UAL, 2 native, 3 code); a clear stage at the campus west gate; F9 plays
# it inside FreeRoam and a hold-Esc skip restores the world. Bodies never sink into each other or the props (bone capsules,
# tests/support/cine_bodies.gd, every 1/60 s on every tier): <= 0.03 m, or within 0.08 story s of a hit <= 0.06 m for a
# striking limb and <= 0.04 m torso / head into torso / head; feet never more than 3 cm under the floor.
# Run:  godot --headless --path . --script tests/test_cine_d1_brawl.gd
# CINE_NO_MIXAMO=1 sets CineRetarget.disabled = ["mixamo"] before any check (covers the fallback tiers with files present).
# Every player built here passes {"music": false} (plan review B1): the test never depends on user://music.
extends SceneTree

const Bodies = preload("res://tests/support/cine_bodies.gd")

## Real impact times (the track's strong onsets).
const IMPACTS: Dictionary = {"H1": 2.76, "N1": 7.17, "H2": 8.48, "H3": 9.83, "H4": 11.76, "H5": 12.71}
## Real start of every shot (cuts on onsets; S15 / S16 / S18 / S19 on the 112 bpm grid through the sustained note and tail).
const SHOTS: Dictionary = {"S1": 0.0, "S2": 1.45, "S3": 2.76, "S4": 3.02, "S5": 5.89, "S6": 6.15, "S7": 7.17, "S8": 7.72,
	"S9": 8.48, "S10": 9.02, "S11": 9.83, "S12": 10.73, "S13": 11.76, "S14": 12.13, "S15": 15.92, "S16": 19.14, "S17": 21.99,
	"S18": 22.53, "S19": 23.60}
## Non-ramp SFX accents on the remaining onsets (real s); 21.99 is the crash into the crate stack.
const ACCENTS: Array[float] = [1.45, 3.02, 5.89, 7.17, 7.72, 9.02, 9.30, 10.14, 10.73, 12.13, 21.99]
## Camera punch-ins on normal-speed hits (real s).
const PUNCHES: Array[float] = [1.45, 7.72, 9.30, 10.73]
const CRASH_R: float = 21.99
## Lying checks: [actor, real time] -> hips on the floor (code-tier lying height, plan Task 2 concern).
const LYING: Array = [["c2", 16.0], ["c3", 17.0], ["c1", 24.6]]
const GROUPS: Dictionary = {"hands": ["Wrist.L", "Wrist.R"], "feet": ["Foot.L", "Foot.R"], "knees": ["LowerLeg.L", "LowerLeg.R"],
	"torso": ["Hips", "Chest"], "upper": ["Head", "Chest", "UpperArm.L", "UpperArm.R"]}
const HALF: Vector2 = Vector2(7.0, 5.0)
## Non-ramp hits checked like the ramps: [name, real time, attacker points, target points].
const EXTRA_CONTACTS: Array = [["SH", 1.45, "c1:hands", "hero:Chest"], ["GUT", 7.72, "hero:hands", "c2:torso"],
	["JAB", 9.30, "c3:hands", "hero:torso"], ["THR", 10.73, "hero:hands", "c3:torso"]]
## Striking part per impact: [attacker, part (fists | head | shoulder | helmet), target].
const STRIKES: Dictionary = {"SH": ["c1", "fists", "hero"], "H1": ["c1", "fists", "hero"], "GUT": ["hero", "fists", "c2"],
	"H2": ["hero", "fists", "c2"], "JAB": ["c3", "fists", "hero"], "H3": ["hero", "head", "c3"], "THR": ["hero", "fists", "c3"],
	"H4": ["hero", "helmet", "c1"], "H5": ["hero", "shoulder", "c1"]}
## Surface gap at the impact: Mixamo tier (the owner's) and the fallback tiers.
const GAP_MIXAMO: float = 0.04
const GAP_OTHER: float = 0.15
## Lie / get-up transitions: the hips may move at most this much per 1/60 frame relative to the actor root (no skating).
const HIPS_STEP_MAX: float = 0.08
const LIE_MOVES: Array[String] = ["lie", "lie_flat", "get_up", "slumped", "get_up_sit"]
## Body penetration limits (m): normal frames, and within PEN_WINDOW story s of a hit (limb / torso-head pairs).
const PEN_MAX: float = 0.03
const PEN_HIT_LIMB: float = 0.06
const PEN_HIT_CORE: float = 0.04
const PEN_WINDOW: float = 0.08
const FOOT_FLOOR: float = -0.03
## The kerb strip measured on the west-gate stage floor (stage frame, centre / half extents): 10 cm high along x -1.0.
const KERB_C: Vector3 = Vector3(-1.0, 0.05, 3.825)
const KERB_H: Vector3 = Vector3(0.05, 0.05, 1.175)

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


## Surface gap (bone-capsule bodies) from the striking part to the target at each impact, through the drive (his
## shoulder in Mũ Vàng's midriff) and for Mũ Đỏ's back into the scooter: <= GAP_MIXAMO on the Mixamo tier (what the owner
## watches), <= GAP_OTHER on the fallbacks; overlap is limited by _penetration.
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
		var deep: float = PEN_HIT_CORE if String(st[1]) in ["head", "shoulder"] else PEN_HIT_LIMB
		_check(float(res["g"]) >= -deep, "%s: %s strike sinks %.3f m into the target (> %.2f)" % [label, String(row[0]), -float(res["g"]), deep])
	# the drive: his shoulder stays on Mũ Vàng from the tackle until he heaves him off
	var h5: float = tl.story_time("H5")
	var s_rel: float = float(tl.get("sc")) - 0.3
	var worst: float = -INF
	var at: float = 0.0
	var r: float = tl.clock.real_at(h5 + 0.1)
	while r <= tl.clock.real_at(s_rel):
		pl.seek(r)
		var g: float = float(_strike_gap(pl, "hero", "shoulder", "c1")["g"])
		if g > worst:
			worst = g
			at = r
		r += 1.0 / 60.0
	print("  gap     %-6s DRV %+.3f m  worst through the drive at r %.2f" % [label, worst, at])
	_check(worst <= lim, "%s: tackle contact through the drive, worst gap %.3f m <= %.2f at r %.2f" % [label, worst, lim, at])
	# Mũ Đỏ's back into the scooter
	var boxes: Array = Bodies.prop_boxes(pl.prop_nodes["scooter"])
	var h2: float = tl.story_time("H2")
	var best: float = INF
	var bat: float = 0.0
	r = tl.clock.real_at(h2)
	while r <= tl.clock.real_at(h2 + 0.7):
		pl.seek(r)
		var g2: float = float(Bodies.gap_boxes(Bodies.capsules(pl.actors["c2"]), boxes)["g"])
		if g2 < best:
			best = g2
			bat = r
		r += 1.0 / 60.0
	print("  gap     %-6s SCT %+.3f m  Mũ Đỏ into the scooter at r %.2f" % [label, best, bat])
	_check(best <= lim, "%s: Mũ Đỏ reaches the scooter, gap %.3f m <= %.2f" % [label, best, lim])


func _strike_gap(pl: CinePlayer, who: String, part: String, target: String) -> Dictionary:
	var a: CineActor = pl.actors[who]
	var tc: Array = Bodies.capsules(pl.actors[target])
	var mine: Array = Bodies.capsules(a)
	match part:
		"fists":
			return Bodies.gap_spheres(Bodies.fists(a), tc)
		"head":
			return Bodies.gap_caps(mine.filter(func(c: Array) -> bool: return c[0] == "head"), tc)
		"shoulder":
			return Bodies.gap_caps(mine.filter(func(c: Array) -> bool: return c[0] in ["torso", "upper_arm.L", "upper_arm.R", "head"]), tc)
		"helmet":
			var hd: Dictionary = a.holds[0]
			var hx: Transform3D = a.sk.global_transform * CharacterBuilder._bone_global_now(a.sk, a.sk.find_bone(String(hd["bone"])))
			var nx: Transform3D = hx * (hd["node"] as Node3D).transform
			return Bodies.gap_spheres([["helmet", nx.origin + nx.basis.y.normalized() * 0.05, Bodies.HELMET_R]], tc)
	return {"g": INF, "from": "?", "to": "?"}


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


## The helmet: off Mũ Xanh's head after the throw, in the protagonist's right hand on the swing, hidden before and after.
func _helmet(pl: CinePlayer) -> void:
	var h: CineActor = pl.actors["hero"]
	var c3: CineActor = pl.actors["c3"]
	var att: BoneAttachment3D = (h.holds[0] as Dictionary)["att"] if not h.holds.is_empty() else null
	_check(att != null and att.bone_name == "Wrist.R", "held helmet on a BoneAttachment3D on Wrist.R")
	if att == null:
		return
	pl.seek(5.0)
	var c3_hel: bool = (c3._part_nodes.get("helmet", []) as Array).any(func(n: Node3D) -> bool: return n.visible)
	_check(not att.visible and c3_hel, "before the throw: Mũ Xanh wears his helmet, the hand is empty")
	pl.seek(float(IMPACTS["H4"]))
	var node: Node3D = (h.holds[0] as Dictionary)["node"]
	var want: Vector3 = h.bone_world("Wrist.R")
	var c3_off: bool = not (c3._part_nodes.get("helmet", []) as Array).any(func(n: Node3D) -> bool: return n.visible)
	var hx: Transform3D = h.sk.global_transform * CharacterBuilder._bone_global_now(h.sk, h.sk.find_bone("Wrist.R"))
	var got: Vector3 = (hx * node.transform).origin
	print("  helmet in hand at H4: %.3f m from the wrist, Mũ Xanh bare-headed %s" % [got.distance_to(want), c3_off])
	_check(att.visible and c3_off and got.distance_to(want) < 0.2, "on the swing the helmet is in his hand and off Mũ Xanh's head")
	pl.seek(24.0)
	_check(not att.visible, "the helmet is dropped after the swing")
	# no gap between the pop-off and the landing (review Minor 3): the loose helmet leaves from his head and is seen in flight
	var ha: Node3D = pl.prop_nodes["helmet_a"]
	var xt: float = float(tl.get("xt"))
	for ds: float in [0.07, 0.14, 0.21]:
		pl.seek(tl.clock.real_at(xt + ds))
		var dh: float = ha.global_position.distance_to(c3.bone_world("Head"))
		if ds < 0.1:
			print("  loose helmet at xt+%.2f: %.2f m from Mũ Xanh's head" % [ds, dh])
			_check(ha.visible and dh < 0.4, "the helmet leaves from Mũ Xanh's head (%.2f m)" % dh)
		else:
			_check(ha.visible, "the loose helmet is visible in flight at xt+%.2f" % ds)
	# the prop is the worn helmet's shape in this art style (vice: PS2 fit scale + crescent visor)
	var fitn: Node3D = ha.find_child("HelmetFit", true, false) as Node3D
	var want_scale: Vector3 = PS2Head.HELMET_FIT_SCALE if CharacterBuilder.ps2 else Vector3.ONE
	_check(fitn != null and fitn.scale.is_equal_approx(want_scale), "helmet prop shaped like the worn one (%s)" % (str(fitn.scale) if fitn else "none"))


## Every 1/60 s over the whole 25 s: deepest penetration between every two actors and between each actor and the scooter,
## the crate stack (until it breaks on 21.99) and the kerb; feet under the floor. Prints the worst per kind.
func _penetration(pl: CinePlayer, label: String) -> void:
	var hits: Array[float] = []
	for rw: Dictionary in tl.clock.ramps:
		hits.append(float(rw["s"]))
	for ex: Array in EXTRA_CONTACTS:
		hits.append(tl.clock.story_at(float(ex[1])))
	hits.append(tl.clock.story_at(CRASH_R))
	hits.append(float(tl.get("slam_s")))
	var s_crash: float = tl.clock.story_at(CRASH_R)
	var boxes: Dictionary = {"scooter": Bodies.prop_boxes(pl.prop_nodes["scooter"]), "crates": Bodies.prop_boxes(pl.prop_nodes["crates"]),
		"kerb": [["kerb", Transform3D(Basis.IDENTITY, KERB_C), KERB_H]]}
	var ids: Array = pl.actors.keys()
	var worst: Dictionary = {"d": -1.0, "over": -1.0, "what": "-"}
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
			for j: int in range(i + 1, ids.size()):
				if a.position.distance_to((pl.actors[ids[j]] as CineActor).position) > 2.6:
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


## The scooter headlight reads as a headlight in night haze: a dim soft pool (energy, angular falloff), faint additive haze
## cones, slow dust motes following the clock, and no opaque unshaded quad (the old "sticker" on the road).
func _headlight(pl: CinePlayer) -> void:
	var sc: Node3D = pl.prop_nodes["scooter"]
	var spot: SpotLight3D = sc.find_child("HeadlightBeam", true, false) as SpotLight3D
	_check(spot != null and spot.light_energy <= 1.5 and spot.spot_angle_attenuation >= 2.0,
		"headlight is a dim soft pool (energy %.2f <= 1.5, edge falloff %.1f >= 2)" % [spot.light_energy if spot else -1.0, spot.spot_angle_attenuation if spot else -1.0])
	var haze: int = 0
	var bad: String = ""
	for n: Node in sc.find_children("*", "MeshInstance3D", true, false):
		var m: StandardMaterial3D = (n as MeshInstance3D).material_override as StandardMaterial3D
		if m == null or m.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
			continue
		if m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
			bad = String(n.name)
		elif String(n.name).begins_with("Haze"):
			haze += 1
			if m.albedo_color.a > 0.05 or m.blend_mode != BaseMaterial3D.BLEND_MODE_ADD:
				bad = "%s (alpha %.3f)" % [n.name, m.albedo_color.a]
	_check(haze >= 2 and bad == "", "headlight haze: %d faint additive cones, no opaque unshaded quad (%s)" % [haze, bad])
	# fade along the beam: side uv.v = 0.5 x (distance from the far end) / length (Godot CylinderMesh), times uv1_scale.y,
	# then the GradientTexture2D fill (review: it ran backwards, brightest at the lens)
	var h0: MeshInstance3D = sc.find_child("Haze0", true, false) as MeshInstance3D
	if h0:
		var hm: StandardMaterial3D = h0.material_override
		var gtx: GradientTexture2D = hm.albedo_texture as GradientTexture2D
		var ln: float = (h0.mesh as CylinderMesh).height
		var prof: Array[float] = []
		for dz: float in [0.0, 0.65 * ln, ln]:
			var v: float = 0.5 * (ln - dz) / ln * hm.uv1_scale.y
			var a: Vector2 = gtx.fill_from
			var b: Vector2 = gtx.fill_to
			var t: float = clampf((v - a.y) / (b.y - a.y), 0.0, 1.0) if absf(b.y - a.y) > 1e-6 else 0.0
			prof.append(gtx.gradient.sample(t).a)
		print("  haze alpha along the beam: lamp %.2f, %.1f m %.2f, far end %.2f" % [prof[0], 0.65 * ln, prof[1], prof[2]])
		_check(prof[0] < 0.05 and prof[1] > 0.9 and prof[2] < 0.05, "haze fades in from the lamp, peaks ~2.9 m out, fades out at the far end (%s)" % str(prof))
	var dust: CPUParticles3D = sc.find_child("HeadlightDust", true, false) as CPUParticles3D
	_check(dust != null and dust.has_meta("cine_ambient") and dust.use_fixed_seed, "headlight dust motes (fixed seed, clock-driven)")
	if dust:
		pl.seek(12.9)   # inside the H5 freeze
		_check(dust.speed_scale < 0.01, "dust freezes with the clock (speed_scale %.2f)" % dust.speed_scale)
		pl.seek(24.0)
		_check(absf(dust.speed_scale - 1.0) < 0.05, "dust drifts at normal speed in the tail (%.2f)" % dust.speed_scale)


func _set_style(style: String) -> void:
	var gfx: Node = root.get_node_or_null("/root/GameFX")
	if gfx and gfx.has_method("set_art_style"):
		gfx.call("set_art_style", style, false)
	CharacterBuilder.ps2 = style == "vice"


## After the throw no visible mesh on Mũ Xanh uses a helmet material (dome, rim, visor, straps - the PS2 head rebuilds its
## own visor and straps; review I1), in the given art style.
func _helmet_off(pl: CinePlayer, style: String) -> void:
	var mats: Array = []
	for k: String in CharacterBuilder._mat_cache.keys():
		if k.begins_with("m_helmet"):
			mats.append(CharacterBuilder._mat_cache[k])
	var c3: CineActor = pl.actors["c3"]
	for rr: float in [5.0, 11.76, 17.0]:
		pl.seek(rr)
		var vis: Array[String] = []
		for n: Node in c3.body.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n
			if mi.is_visible_in_tree() and mats.has(mi.material_override):
				vis.append(String(mi.name))
		if rr < 10.0:
			_check(vis.size() >= 2, "%s: Mũ Xanh wears his helmet before the throw (%d helmet meshes)" % [style, vis.size()])
		else:
			_check(vis.is_empty(), "%s: no helmet mesh left on Mũ Xanh at r %.2f (%s)" % [style, rr, ", ".join(vis)])


## Story start of every move cue next to a lie / get_up (strikes resolved like the validator): [actor, s, "prev->move"].
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


## Hips motion relative to the actor root per 1/60 real frame from 0.3 s before to 0.6 s after each lie / get_up transition.
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
	_check(worst <= HIPS_STEP_MAX, "%s: hips step %.3f m/frame <= %.2f across lie / get_up transitions (%s)" % [label, worst, HIPS_STEP_MAX, where])


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
	_check(tl.clock.ramps.size() == 6 and freezes == 5,
		"slow motion on 4 impacts + the finisher (freezes) + the neck-crack close-up accent (%d ramps, %d freezes)" % [tl.clock.ramps.size(), freezes])
	var n1: Dictionary = tl.clock.ramp("N1")
	_check(float(n1.get("r1", 99.0)) < 7.72 - 0.25 and float(n1.get("r0", 0.0)) > 4.2,
		"neck-crack slow motion %.3f-%.3f ends before the 7.72 gut punch" % [float(n1.get("r0", 0.0)), float(n1.get("r1", 0.0))])
	for nm: String in IMPACTS.keys():
		var rh: float = float(tl.clock.ramp(nm).get("r_hit", -1.0))
		_check(absf(rh - float(IMPACTS[nm])) < 0.0005, "%s real impact %.4f on the onset %.3f" % [nm, rh, float(IMPACTS[nm])])
	var fin: Dictionary = tl.clock.ramp("H5")
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
	for rp: float in PUNCHES:
		var hitp: bool = false
		for pu: Dictionary in tl.punches:
			hitp = hitp or absf(tl.clock.real_at(tl.story_time(pu["at"])) - rp) < 0.0005
		_check(hitp, "camera punch-in on the onset %.2f" % rp)
	var held: bool = false
	for c: Dictionary in tl.cues:
		if String(c["type"]) == "hold" and String(c["actor"]) == "hero" and String(c["kind"]) == "helmet":
			held = tl.clock.real_at(float(c["s"])) < float(IMPACTS["H4"]) and tl.clock.real_at(float(c["s1"])) > float(IMPACTS["H4"])
	_check(held, "the protagonist holds the helmet through its swing (H4)")
	for pr: Dictionary in tl.props:
		var pp: Vector3 = pr["pos"]
		_check(absf(pp.x) <= HALF.x and absf(pp.z) <= HALF.y, "prop %s inside the 14 x 10 box" % String(pr["id"]))
	var committed: String = FileAccess.get_file_as_string("res://docs/cinematics/seg_d1_brawl.txt").replace("\r\n", "\n")
	_check(committed == tl.beat_sheet(), "docs/cinematics/seg_d1_brawl.txt is in sync (run tools/cine_beats.gd)")
	world = Node3D.new()
	root.add_child(world)
	# nodes added in _initialize enter the tree only after it returns (actor global transforms need the tree)
	await process_frame
	# pin the art style (user://settings.cfg must not decide what is tested; review Minor 4): vice here, classic below
	_set_style("vice")
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
			_skate(p, "ual")
			_penetration(p, "ual")
			_helmet(p)
			_helmet_off(p, "vice")
			_headlight(p)
			_set_style("classic")
			var pk := CinePlayer.new()
			world.add_child(pk)
			pk.setup(tl, Transform3D.IDENTITY, {"manual": true, "music": false})
			_helmet_off(pk, "classic")
			pk.queue_free()
			_set_style("vice")
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
				_penetration(pc, label)
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
			# F9 cycles the sorted slots; with the story timelines (ai_intro, cine_d0_*) seg_d1_brawl is not first any more
			fr.set("_cine_slot_i", CineTimeline.slots().find("seg_d1_brawl") - 1)
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
		print("✅ SUCCESS: CINE seg_d1_brawl (Nobody restage: 25.000 s on the track's onsets, beat sheet, tiers, contacts, helmet, FreeRoam)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true
