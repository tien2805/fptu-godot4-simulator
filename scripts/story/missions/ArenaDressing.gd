# File: res://scripts/story/missions/ArenaDressing.gd
# Melee arena dressing of the Phase B story brawls (Wave 2 content pass, plan 2026-10-29-w2-early.md Task 6, master plan
# Q2 / Q4 "arenas dressed with slam-able props"): MissionFight builds one per fight and drives it from its clock.
#   d1 (the west gate, three couriers): parked bikes round the ring (group slam_car: a heavy hit near one slams the enemy
#      into it), a vendor's table (slam_table); helmets and trash-can lids on the floor (MeleeFight "props", [E]).
#   d4 (in front of the canteen, the clone waves and Dolly): canteen tables (slam_table) with trays of food; trays and
#      plastic chairs as weapons; [E] next to an upright table (when nothing else takes [E]) FLIPS it: it crashes onto
#      its side away from the player (soup everywhere), enemies right behind it take a heavy knock, and it stands as cover.
#      The escalation beat at wave 2 ("ĐẠI CHIẾN CĂN TIN!", a preview cut): FOOD THROWERS at the back pelt the player:
#      each wind-up is telegraphed (a red "!" and a raised arm for throw_tell_s()), the bun flies on an arc to where the
#      player stood; a flipped table between blocks it (splat on the table), a hit costs food_dmg() and splats the screen.
#      Every slam into a table splashes soup: "Á NÓNG!".
# Every tuned number goes through Difficulty.pick(normal, easy). Tests read tables, flips, throws, blocked, food_hits,
# soup_splashes, throwers and call try_flip() / tick(dt).
class_name ArenaDressing
extends Node3D

const FLIP_M: float = 1.7
const FLIP_KNOCK_M: float = 2.2
const FLIP_S: float = 0.35
const THROWER_BACK_M: float = 9.0
const BUN_FLY_S: float = 0.75
const BUN_HIT_R: float = 0.9
const TABLE_SIZE := Vector3(1.4, 0.78, 0.8)
const SOUP := Color(0.95, 0.72, 0.3)
const T_FLIP: String = "[E] Lật bàn"
const T_FOOD_FIGHT: String = "ĐẠI CHIẾN CĂN TIN!"
const T_HOT: String = "Á NÓNG!"

var kind: String = "d1"
var mission: StoryMission
var fight: MeleeFight
var centre: Vector3 = Vector3.ZERO
var fwd: Vector3 = Vector3.FORWARD
## Tables: {root, body, flipped (bool), home (Transform3D)}.
var tables: Array[Dictionary] = []
var bikes: Array[Node3D] = []
var throwers: Array[Dictionary] = []          # {body, t (to the next wind-up), state "idle"|"tell"|"cool", tell_t, bubble}
var buns: Array[Dictionary] = []              # {node, from, to, t, blocked}
var food_on: bool = false
var flips: int = 0
var throws: int = 0
var blocked: int = 0
var food_hits: int = 0
var guarded: int = 0
var soup_splashes: int = 0
var cuts: int = 0
var bubble: Label3D
var _bubble_t: float = 0.0
var _rng := RandomNumberGenerator.new()


static func flip_dmg() -> float:
	return float(Difficulty.pick(22.0, 30.0))


static func food_dmg() -> float:
	return float(Difficulty.pick(8.0, 5.0))


static func throw_gap() -> float:
	return float(Difficulty.pick(2.6, 3.8))


static func throw_tell_s() -> float:
	return float(Difficulty.pick(0.6, 0.9))


static func thrower_count() -> int:
	return int(Difficulty.pick(2, 1))


## The weapons on the floor for MeleeFight's "props" option, around `c` (fwd = toward the enemies).
static func props_for(k: String, c: Vector3, f: Vector3) -> Array:
	var r := Vector3(-f.z, 0.0, f.x)
	if k == "d1":
		return [{"kind": "helmet", "at": c + r * 2.4 + f * 1.0}, {"kind": "lid", "at": c - r * 2.6 + f * 0.6},
			{"kind": "helmet", "at": c - r * 1.8 - f * 2.2}, {"kind": "lid", "at": c + r * 3.0 - f * 1.6}]
	return [{"kind": "tray", "at": c + r * 1.6 + f * 1.2}, {"kind": "tray", "at": c - r * 1.6 + f * 1.4},
		{"kind": "chair", "at": c + r * 3.4 - f * 0.4}, {"kind": "tray", "at": c - r * 3.0 - f * 1.8},
		{"kind": "chair", "at": c - r * 0.6 - f * 2.6}]


func setup(k: String, m: StoryMission, f: MeleeFight, c: Vector3, face: Vector3) -> void:
	kind = k
	mission = m
	fight = f
	centre = c
	fwd = Vector3(face.x, 0.0, face.z).normalized() if face.length() > 0.01 else Vector3.FORWARD
	_rng.seed = 2905
	name = "Arena_" + k
	bubble = Label3D.new()
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.font_size = 52
	bubble.pixel_size = 0.008
	bubble.outline_size = 10
	bubble.modulate = Color("#FFB347")
	bubble.visible = false
	add_child(bubble)
	if k == "d1":
		_build_d1()
	elif k == "d4":
		_build_d4()


func _right() -> Vector3:
	return Vector3(-fwd.z, 0.0, fwd.x)


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, mission.ground_y(p) if mission else p.y, p.z)


func _spot(p: Vector3, r: int = 3) -> Vector3:
	return _ground(mission.free_spot(p, r) if mission else p)


static func _box(root: Node3D, size: Vector3, cy: float, group: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Collision"
	if group != "":
		body.add_to_group(group)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = Vector3(0.0, cy, 0.0)
	body.add_child(cs)
	root.add_child(body)
	return body


# ---------------------------------------------------------------------------
func _build_d1() -> void:
	var r: Vector3 = _right()
	var cols: Array[Color] = [Color("#C8CCD2"), Color("#D63031"), Color("#0984E3"), Color("#FDCB6E")]
	var spots: Array[Vector3] = [centre + r * 4.6 + fwd * 1.5, centre - r * 4.4 + fwd * 2.2, centre + r * 3.8 - fwd * 3.0,
		centre - r * 4.0 - fwd * 2.6]
	for i: int in spots.size():
		var root := Node3D.new()
		root.name = "ParkedBike%d" % i
		add_child(root)
		root.global_position = _spot(spots[i], 2)
		root.rotation.y = StoryMission.yaw_of(fwd) + PI * 0.5 + 0.3 * float(i % 2)
		var bike: Node3D = CineFX.build_prop("scooter", {"color": cols[i]})
		root.add_child(bike)
		_box(root, Vector3(0.8, 1.1, 1.9), 0.55, "slam_car")
		bikes.append(root)
	var t: Dictionary = _table(_spot(centre - fwd * 4.2 + r * 0.8, 2), StoryMission.yaw_of(r), false)
	var sign := Label3D.new()
	sign.text = "BÁNH MÌ"
	sign.font_size = 40
	sign.outline_size = 8
	sign.modulate = Color("#FFE66D")
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(0.0, 1.6, 0.0)
	(t["root"] as Node3D).add_child(sign)


func _build_d4() -> void:
	var r: Vector3 = _right()
	for row: float in [-1.0, 1.0]:
		for k: int in 3:
			var p: Vector3 = centre + r * (float(k) - 1.0) * 3.6 + fwd * row * 3.2
			_table(_spot(p, 2), StoryMission.yaw_of(r), true)


## A canteen table (slam_table) with a tray of food on it (d4) or a vendor's table (d1).
func _table(p: Vector3, yaw: float, food: bool) -> Dictionary:
	var root := Node3D.new()
	root.name = "Table%d" % tables.size()
	add_child(root)
	root.global_position = p
	root.rotation.y = yaw
	var vis: Node3D = CineFX.build_prop("table")
	root.add_child(vis)
	if food:
		var tr: Node3D = CineFX.build_prop("tray", {"food": true})
		vis.add_child(tr)
		tr.position = Vector3(0.0, 0.76, 0.0)
	var body: StaticBody3D = _box(root, TABLE_SIZE, TABLE_SIZE.y * 0.5, "slam_table")
	var t: Dictionary = {"root": root, "vis": vis, "body": body, "flipped": false, "home": root.global_transform}
	tables.append(t)
	return t


## The upright table the player can flip right now (within FLIP_M, roughly in front), else -1. None while [E] belongs to
## the combat (a finisher, a throw, a pickup) or the player is down, stunned or mid-move.
func flip_target() -> int:
	var pl: ThirdPersonController = mission.player if mission else null
	if pl == null or kind != "d4" or not pl.controls_enabled or pl.is_knocked_down():
		return -1
	var cmb: PlayerCombat = fight.combat if fight else null
	if cmb != null:
		if cmb.finisher_target() != null or cmb.throw_target() != null or cmb.prop_target() != null:
			return -1
		if cmb.state in [PlayerCombat.St.DOWN, PlayerCombat.St.HITSTUN, PlayerCombat.St.FINISHER, PlayerCombat.St.THROW, PlayerCombat.St.DODGE]:
			return -1
	var best: int = -1
	var bd: float = FLIP_M
	var f: Vector3 = pl.facing_dir()
	for i: int in tables.size():
		var t: Dictionary = tables[i]
		if t["flipped"]:
			continue
		var d: Vector3 = (t["root"] as Node3D).global_position - pl.global_position
		d.y = 0.0
		var dist: float = d.length()
		if dist > bd:
			continue
		if dist > 0.3 and f.dot(d / dist) < 0.2:
			continue
		best = i
		bd = dist
	return best


## [E] at an upright table: it crashes onto its side away from the player (cover), soup splashes, enemies behind it are
## knocked. false when none is in reach.
func try_flip() -> bool:
	var i: int = flip_target()
	if i < 0:
		return false
	var t: Dictionary = tables[i]
	t["flipped"] = true
	flips += 1
	var root: Node3D = t["root"]
	var pl: Vector3 = mission.player.global_position
	var away: Vector3 = root.global_position - pl
	away.y = 0.0
	away = away.normalized() if away.length() > 0.05 else fwd
	# turn the table so it falls along `away`, then tip it 90 degrees: the top stands vertical (0 .. its depth high), the
	# legs toward `away`; its collision turns with it (a low wall: the cover)
	root.rotation.y = StoryMission.yaw_of(away)
	var to_pos: Vector3 = root.global_position + away * 0.35 + Vector3(0.0, TABLE_SIZE.z * 0.5, 0.0)
	if root.is_inside_tree():
		var tw: Tween = root.create_tween().set_parallel(true)
		tw.tween_property(root, "rotation:x", -PI * 0.5, FLIP_S).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(root, "global_position", to_pos, FLIP_S)
	else:
		root.rotation.x = -PI * 0.5
		root.global_position = to_pos
	_soup(root.global_position + Vector3(0.0, 0.6, 0.0), away)
	MissionSfx.play(self, "splat", -2.0)
	Impact.sound(self, "wood_break", root.global_position, -2.0)
	Impact.punch(self, 0.3, away)
	if fight:
		for e: Variant in fight.alive():
			var me: MeleeEnemy = e
			var d: Vector3 = me.global_position - root.global_position
			d.y = 0.0
			if d.length() < FLIP_KNOCK_M and d.dot(away) > -0.3:
				me.take_strike({"dmg": flip_dmg(), "stagger": 999.0, "breaks_block": true, "from": pl})
				Impact.hit(self, "heavy", {"pos": me.global_position + Vector3(0.0, 1.0, 0.0), "dir": away, "target": me, "no_hitstop": false})
	return true


## A comic soup splash: the FxPool splash (soup coloured when the pool allows), a line over `at`.
func _soup(at: Vector3, dir: Vector3) -> void:
	soup_splashes += 1
	Impact.particles(self, "splash", at, (dir + Vector3.UP).normalized(), 1.2)
	bubble.text = T_HOT
	bubble.global_position = at + Vector3(0.0, 1.4, 0.0)
	bubble.visible = true
	_bubble_t = 1.2


## An enemy slammed into something: a table splashes soup (the comic beat).
func on_slammed(e: MeleeEnemy, surface: String) -> void:
	if surface == "table" and e and is_instance_valid(e):
		_soup(e.global_position + Vector3(0.0, 0.9, 0.0), Vector3.UP)
		MissionSfx.play(self, "splat", -3.0)


## The escalation beat (d4 wave 2): food throwers at the back, a line, a preview cut on the first.
func start_food_fight() -> void:
	if kind != "d4" or food_on:
		return
	food_on = true
	var r: Vector3 = _right()
	for i: int in thrower_count():
		var p: Vector3 = _spot(centre + fwd * THROWER_BACK_M + r * (float(i) - 0.5) * 4.0, 3)
		var body: Node3D = StoryCast.build("clone_masked")
		add_child(body)
		body.global_position = p
		body.rotation.y = StoryMission.yaw_of(-fwd)
		var b := Label3D.new()
		b.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		b.font_size = 72
		b.pixel_size = 0.008
		b.outline_size = 12
		b.modulate = Color("#FF3B30")
		b.text = "!"
		b.position = Vector3(0.0, 2.3, 0.0)
		b.visible = false
		body.add_child(b)
		throwers.append({"body": body, "t": 1.2 + 0.9 * float(i), "state": "idle", "tell_t": 0.0, "bubble": b})
	if mission:
		mission.popup(T_FOOD_FIGHT, 2.2, Color("#FFB347"))
	if not throwers.is_empty():
		cuts += 1
		var d: CameraDirector = CameraDirector.live()
		if d != null and (throwers[0]["body"] as Node3D).is_inside_tree():
			d.preview_cut(throwers[0]["body"], 0.6)


func stop_food_fight() -> void:
	food_on = false
	for th: Dictionary in throwers:
		if is_instance_valid(th["body"]):
			(th["body"] as Node).queue_free()
	throwers.clear()
	for b: Dictionary in buns:
		if is_instance_valid(b["node"]):
			(b["node"] as Node).queue_free()
	buns.clear()


## Reset for a retry: tables upright, the food fight off.
func reset() -> void:
	stop_food_fight()
	for t: Dictionary in tables:
		var root: Node3D = t["root"]
		root.global_transform = t["home"]
		t["flipped"] = false
	bubble.visible = false


func tick(dt: float) -> void:
	if _bubble_t > 0.0:
		_bubble_t -= dt
		if _bubble_t <= 0.0:
			bubble.visible = false
	if not food_on:
		return
	var pl: ThirdPersonController = mission.player if mission else null
	if pl == null:
		return
	for th: Dictionary in throwers:
		var body: Node3D = th["body"]
		body.rotation.y = StoryMission.yaw_of(pl.global_position - body.global_position)
		match String(th["state"]):
			"idle":
				th["t"] = float(th["t"]) - dt
				if float(th["t"]) <= 0.0:
					th["state"] = "tell"
					th["tell_t"] = throw_tell_s()
					(th["bubble"] as Label3D).visible = true
					CharacterBuilder.play(body, "wave", throw_tell_s())
			"tell":
				th["tell_t"] = float(th["tell_t"]) - dt
				if float(th["tell_t"]) <= 0.0:
					(th["bubble"] as Label3D).visible = false
					_throw(body, pl.global_position)
					th["state"] = "idle"
					th["t"] = throw_gap() + _rng.randf_range(-0.4, 0.4)
	var i: int = buns.size() - 1
	while i >= 0:
		var b: Dictionary = buns[i]
		b["t"] = float(b["t"]) + dt
		var u: float = clampf(float(b["t"]) / BUN_FLY_S, 0.0, 1.0)
		var node: Node3D = b["node"]
		var p: Vector3 = (b["from"] as Vector3).lerp(b["to"], u)
		p.y += sin(u * PI) * 1.6
		node.global_position = p
		node.rotation.x += dt * 12.0
		if u >= 1.0:
			_land(b, pl)
			node.queue_free()
			buns.remove_at(i)
		i -= 1


func _throw(body: Node3D, target: Vector3) -> void:
	throws += 1
	var bun := MeshInstance3D.new()
	bun.name = "Bun"
	var sm := SphereMesh.new()
	sm.radius = 0.13
	sm.height = 0.2
	sm.radial_segments = 8
	sm.rings = 4
	bun.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#F5DEB3")
	m.emission_enabled = true
	m.emission = Color("#FFB347")
	m.emission_energy_multiplier = 0.4
	bun.material_override = m
	add_child(bun)
	var from: Vector3 = body.global_position + Vector3(0.0, 1.7, 0.0)
	bun.global_position = from
	var to: Vector3 = target + Vector3(0.0, 1.1, 0.0)
	# a flipped table between the thrower and the player blocks it (the ray at chest height of the cover)
	var hit_cover: bool = false
	var cover_at: Vector3 = to
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state if is_inside_tree() else null
	if space:
		var q := PhysicsRayQueryParameters3D.create(from.lerp(to, 0.0) + Vector3(0.0, -0.9, 0.0), to + Vector3(0.0, -0.5, 0.0))
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty() and _is_flipped_body(hit.get("collider")):
			hit_cover = true
			cover_at = hit["position"]
	buns.append({"node": bun, "from": from, "to": cover_at if hit_cover else to, "t": 0.0, "blocked": hit_cover})
	MissionSfx.play(self, "vault", -10.0)


func _is_flipped_body(c: Variant) -> bool:
	for t: Dictionary in tables:
		if t["flipped"] and c == t["body"]:
			return true
	return false


func _land(b: Dictionary, pl: ThirdPersonController) -> void:
	var at: Vector3 = b["to"]
	Impact.particles(self, "splash", at, Vector3.UP, 0.6)
	MissionSfx.play(self, "splat", -6.0)
	if bool(b["blocked"]):
		blocked += 1
		return
	if pl.global_position.distance_to(at - Vector3(0.0, 1.1, 0.0)) <= BUN_HIT_R:
		if fight and fight.combat and fight.combat.blocking:
			guarded += 1      # caught on the guard: no damage, and no counter toward the far thrower
			return
		food_hits += 1
		if fight and fight.combat:
			fight.combat.receive_attack(throwers[0]["body"] if not throwers.is_empty() else self, {"damage": food_dmg()})
		Impact.edge_flash(self, SOUP, 0.5, 0.4)
		if mission:
			mission.popup("Dính bánh bao vào mặt!", 1.2, Color("#FFB347"))


func _exit_tree() -> void:
	stop_food_fight()
