# File: res://scripts/story/lairs/YardCrane.gd
# D3W-2 (plan 2026-10-30-w3-day3.md T4): the container gantry crane over the middle lane of the yard.
#   - a gantry on two rails (it rolls along the lane, local z), a trolley on its bridge (local x) with a half-height
#     container on the hook (CONT_H = 1.15 m: low cover the player AND the gunmen use, under GunData.GUNMAN_COVER_MAX_H); the cabin
#     on the west leg, reached by a ladder: [E] at its foot climbs (CLIMB_S), in the cabin WASD moves the trolley and the
#     gantry (SPEED m/s), [E] drops, [F] climbs down;
#   - telegraph: the hanging container's shadow and a red footprint on the floor under it, a chain rattle, then a FALL_S fall;
#   - landing: every gunman inside the footprint is knocked out (take_hit "blast" from above -> his knockout and stars),
#     Impact finisher (dust ring, sparks, debris, the director punch) and a shake; the container stays as cover
#     (group "cover" collider, GunFight.cover.add_box + reprune()); signal dropped(pos, kos);
#   - fairness: the player stands in the open cabin (the gunmen see and shoot him there); their accuracy is scaled by
#     cabin_acc while he is up (0.75 Thường, 0.55 Dễ: the cabin's railings); bullet time is off in the cabin (guarded:
#     the shared stream's GunFight.bullet_time);
#   - the cabin camera: its own Camera3D (meta CameraDirector.META_FX: it applies the director's punch / shake offsets), a
#     high three-quarter view of the hook and the footprint.
# Review fixes: no ladder prompt or climb while the player's controls are held (a forklift seat, the hide's freeze); the
# guns neither fire nor aim from the ladder or the cabin; leave() restores the controls as they were; a leave() while a
# director cut holds the screen passes the screen on (the previous or the player's camera) when the cut hands it back.
# The owner steps it: step(dt) from its mission tick (tests too); input: _input ([E] / [F]) and WASD polled in step()
# (move_override for tests). reset() (a retry): out of the cabin, the drops back, the dropped containers gone (their
# cover slots stay in the CoverMap but are held as taken by the crane, so nobody is sent to empty floor).
class_name YardCrane
extends Node3D

signal dropped(pos: Vector3, kos: int)
signal entered
signal left

const RAIL_X: float = 10.2
const Z_RANGE := Vector2(-1.0, 12.0)
const X_RANGE := Vector2(-8.5, 8.5)
const BRIDGE_Y: float = 9.0
const HANG_Y: float = 5.6
const CABIN_Y: float = 6.4
const SPEED: float = 2.5
const CLIMB_S: float = 1.2
const RATTLE_S: float = 0.25
const FALL_S: float = 0.6
const RELOAD_S: float = 1.4
const CONT_W: float = 2.44
const CONT_L: float = 6.06
const CONT_H: float = 1.15         # under GunData.GUNMAN_COVER_MAX_H (1.2, float32-safe): the gunmen use it too
const FOOT_MARGIN: float = 0.35
const LADDER_R: float = 1.7
const T_LADDER: String = "[E] leo lên cần cẩu"
const T_CABIN: String = "WASD di chuyển · [E] thả container · [F] xuống"
const T_EMPTY: String = "Hết container rồi · [F] xuống"
const COLS: Array[Color] = [Color("#C0392B"), Color("#2E5E8C"), Color("#3F7A4A")]

var fight: GunFight = null
var player: ThirdPersonController = null
var drops_max: int = 3
var drops_left: int = 3
## "idle" | "climb" | "cabin"
var state: String = "idle"
var usable: bool = true
var gantry_z: float = 5.0
var trolley_x: float = 0.0
var drop_t: float = -1.0           # >= 0 while a drop runs (rattle, then the fall)
var reload_t: float = -1.0
var climb_t: float = 0.0
var move_override: Variant = null  # Vector2 (x = trolley, y = gantry) for tests
var cabin_acc: float = 1.0
var drops_done: int = 0
var kos_total: int = 0
var landed: Array[StaticBody3D] = []
var cam: Camera3D
var gantry: Node3D
var trolley: Node3D
var hook_box: Node3D
var footprint: MeshInstance3D
var shadow: MeshInstance3D
var chain: MeshInstance3D
var cabin_floor: StaticBody3D
## The cabin (a preview cut's target: "Lên cần cẩu kìa e!").
var cabin_mark: Node3D
var _prev_cam: Camera3D = null
var _acc_saved: Dictionary = {}     # Gunman -> accuracy_k
var _slots_of: Dictionary = {}      # landed body -> PackedInt32Array of its cover slots
var _climb_from: Vector3 = Vector3.ZERO
var _hint: String = ""
var _start_z: float = 5.0
var _start_x: float = 0.0
var _player_ctl: bool = true
## Review fix: leave() while a director cut (the last-KO orbit) holds the screen: the cut hands the screen back to the
## cabin camera when it ends, so the camera to come back to is passed on then (or the player's camera).
var _restore_pending: bool = false
var _restore_to: Camera3D = null
var _cover_was: bool = true


## Built on the yard's transform `xf` (yard-local x / z), the fight's cover / gunmen, `drops` containers.
func setup(xf: Transform3D, f: GunFight, drops: int = 3, start_z: float = 5.0, start_x: float = 0.0) -> void:
	name = "YardCrane"
	transform = xf
	fight = f
	player = f.player if f else null
	drops_max = drops
	_start_z = clampf(start_z, Z_RANGE.x, Z_RANGE.y)
	_start_x = clampf(start_x, X_RANGE.x, X_RANGE.y)
	cabin_acc = float(Difficulty.pick(0.75, 0.55))   # T9: the open cabin was a death trap at x1.0 for the sloppy bot
	_build()
	reset()


func _build() -> void:
	var steel: StandardMaterial3D = CineFX._mat(Color("#D9A521"), 0.5)
	var dark: StandardMaterial3D = CineFX._mat(Color("#3A3D42"), 0.6)
	for sx: float in [-1.0, 1.0]:
		var rail: MeshInstance3D = CineFX._box(self, "Rail", Vector3(0.25, 0.12, Z_RANGE.y - Z_RANGE.x + 4.0), Vector3(sx * RAIL_X, 0.06, (Z_RANGE.x + Z_RANGE.y) * 0.5), dark)
		rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gantry = Node3D.new()
	gantry.name = "Gantry"
	add_child(gantry)
	for sx2: float in [-1.0, 1.0]:
		CineFX._box(gantry, "Leg", Vector3(0.5, BRIDGE_Y, 0.5), Vector3(sx2 * RAIL_X, BRIDGE_Y * 0.5, -1.2), steel)
		CineFX._box(gantry, "Leg", Vector3(0.5, BRIDGE_Y, 0.5), Vector3(sx2 * RAIL_X, BRIDGE_Y * 0.5, 1.2), steel)
		CineFX._box(gantry, "Bogie", Vector3(0.7, 0.5, 3.4), Vector3(sx2 * RAIL_X, 0.3, 0.0), dark)
	CineFX._box(gantry, "Bridge", Vector3(RAIL_X * 2.0 + 0.6, 0.7, 0.6), Vector3(0.0, BRIDGE_Y, -1.0), steel)
	CineFX._box(gantry, "Bridge", Vector3(RAIL_X * 2.0 + 0.6, 0.7, 0.6), Vector3(0.0, BRIDGE_Y, 1.0), steel)
	# the cabin on the west leg (open sides: the player is exposed up there) and its ladder
	var cx: float = -RAIL_X + 1.0
	CineFX._box(gantry, "CabinRoof", Vector3(1.8, 0.12, 1.8), Vector3(cx, CABIN_Y + 2.1, 0.0), dark)
	CineFX._box(gantry, "CabinFloorMesh", Vector3(1.8, 0.12, 1.8), Vector3(cx, CABIN_Y - 0.06, 0.0), dark)
	CineFX._box(gantry, "CabinPanel", Vector3(1.8, 0.9, 0.06), Vector3(cx, CABIN_Y + 0.45, 0.88), CineFX._glow_mat(Color("#FFB347"), 0.6))
	cabin_mark = Node3D.new()
	cabin_mark.name = "CabinMark"
	gantry.add_child(cabin_mark)
	cabin_mark.position = Vector3(cx, CABIN_Y + 1.0, 0.0)
	cabin_floor = StaticBody3D.new()
	cabin_floor.name = "CabinFloor"
	gantry.add_child(cabin_floor)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.8, 0.12, 1.8)
	cs.shape = bs
	cs.position = Vector3(cx, CABIN_Y - 0.06, 0.0)
	cabin_floor.add_child(cs)
	CineFX._box(gantry, "Ladder", Vector3(0.06, CABIN_Y, 0.5), Vector3(-RAIL_X + 0.35, CABIN_Y * 0.5, 0.6), dark)
	for k: int in int(CABIN_Y / 0.45):
		CineFX._box(gantry, "Rung", Vector3(0.05, 0.05, 0.5), Vector3(-RAIL_X + 0.4, 0.3 + 0.45 * k, 0.6), steel)
	trolley = Node3D.new()
	trolley.name = "Trolley"
	gantry.add_child(trolley)
	CineFX._box(trolley, "Carriage", Vector3(1.6, 0.6, 2.6), Vector3(0.0, BRIDGE_Y + 0.6, 0.0), dark)
	chain = CineFX._cyl(trolley, "Chain", 0.04, 0.04, BRIDGE_Y - HANG_Y - CONT_H, Vector3(0.0, (BRIDGE_Y + HANG_Y + CONT_H) * 0.5, 0.0), dark)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.12, 0.08, 0.45)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.set_meta("vice_done", true)
	footprint = CineFX._box(trolley, "Footprint", Vector3(CONT_L + FOOT_MARGIN * 2.0, 0.02, CONT_W + FOOT_MARGIN * 2.0), Vector3(0.0, 0.06, 0.0), fm)
	footprint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.0, 0.0, 0.0, 0.45)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.set_meta("vice_done", true)
	shadow = CineFX._box(trolley, "Shadow", Vector3(CONT_L, 0.02, CONT_W), Vector3(0.0, 0.08, 0.0), sm)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cam = Camera3D.new()
	cam.name = "CraneCam"
	cam.fov = 62.0
	cam.set_meta(CameraDirector.META_FX, self)
	add_child(cam)


## A half-height container (a 20 ft shell cut down: body, ribs, door bars), origin at its floor centre.
func _container_mesh(parent: Node3D, col: Color) -> Node3D:
	var n := Node3D.new()
	n.name = "HalfContainer"
	parent.add_child(n)
	var m: StandardMaterial3D = CineFX._mat(col, 0.7)
	CineFX._box(n, "Body", Vector3(CONT_L, CONT_H, CONT_W), Vector3(0.0, CONT_H * 0.5, 0.0), m)
	var rib: StandardMaterial3D = CineFX._mat(col.darkened(0.25), 0.7)
	for k: int in 7:
		CineFX._box(n, "Rib", Vector3(0.08, CONT_H + 0.02, CONT_W + 0.04), Vector3(-CONT_L * 0.5 + 0.3 + k * (CONT_L - 0.6) / 6.0, CONT_H * 0.5, 0.0), rib)
	return n


func reset() -> void:
	if state != "idle":
		leave()
	drops_left = drops_max
	drop_t = -1.0
	reload_t = -1.0
	drops_done = 0
	kos_total = 0
	gantry_z = _start_z
	trolley_x = _start_x
	for b: StaticBody3D in landed:
		if is_instance_valid(b):
			if fight and _slots_of.has(b):
				for i: int in (_slots_of[b] as PackedInt32Array):
					fight.taken[i] = self   # no slot by a container that is gone
			b.queue_free()
	landed.clear()
	_slots_of.clear()
	_hang_new()
	_place()


func _hang_new() -> void:
	if hook_box and is_instance_valid(hook_box):
		hook_box.queue_free()
	hook_box = null
	if drops_left <= 0:
		footprint.visible = false
		shadow.visible = false
		return
	hook_box = _container_mesh(trolley, COLS[drops_done % COLS.size()])
	hook_box.position = Vector3(0.0, HANG_Y, 0.0)
	footprint.visible = true
	shadow.visible = true


func _place() -> void:
	gantry.position = Vector3(0.0, 0.0, gantry_z)
	trolley.position = Vector3(trolley_x, 0.0, 0.0)


## The ladder foot (world), on the inside of the west leg.
func ladder_foot() -> Vector3:
	return global_transform * Vector3(-RAIL_X + 1.0, 0.0, gantry_z + 0.6)


func cabin_spot() -> Vector3:
	return global_transform * Vector3(-RAIL_X + 1.0, CABIN_Y + 0.02, gantry_z)


## The footprint centre on the floor (world).
func footprint_centre() -> Vector3:
	return global_transform * Vector3(trolley_x, 0.0, gantry_z)


func hook_pos() -> Vector3:
	return hook_box.global_position + Vector3(0.0, CONT_H * 0.5, 0.0) if hook_box and is_instance_valid(hook_box) else global_transform * Vector3(trolley_x, HANG_Y, gantry_z)


## True when a floor point lies under the hanging container (its footprint plus FOOT_MARGIN).
func footprint_has(p: Vector3) -> bool:
	var l: Vector3 = global_transform.affine_inverse() * p
	return absf(l.x - trolley_x) <= CONT_L * 0.5 + FOOT_MARGIN and absf(l.z - gantry_z) <= CONT_W * 0.5 + FOOT_MARGIN


func near_ladder(p: Vector3) -> bool:
	var f: Vector3 = ladder_foot()
	return Vector2(p.x - f.x, p.z - f.z).length() <= LADDER_R and absf(p.y - f.y) < 1.5


func in_cabin() -> bool:
	return state == "cabin"


## The prompt the mission shows ("" none).
func hint() -> String:
	return _hint


# ----- enter / leave -----
## Starts the climb (the player at the ladder; false otherwise or when the crane is not usable).
func enter(p: ThirdPersonController = null) -> bool:
	if p != null:
		player = p
	if state != "idle" or not usable or player == null or not player.controls_enabled:
		return false             # review fix: not while the player is in a forklift, frozen or otherwise held
	state = "climb"
	climb_t = 0.0
	_climb_from = player.global_position
	_player_ctl = player.controls_enabled
	player.controls_enabled = false
	if fight and fight.cover_ctl:
		fight.cover_ctl.leave()
		_cover_was = fight.cover_ctl.enabled
		fight.cover_ctl.enabled = false
	_bullet_time(false)
	_weapons_held(true)
	return true


func _arrive() -> void:
	state = "cabin"
	player.teleport(cabin_spot(), PI)
	_restore_pending = false
	_prev_cam = _screen_cam()
	_update_cam()
	if cam.is_inside_tree():
		cam.make_current()
	_apply_acc(true)
	entered.emit()


func leave() -> void:
	if state == "idle":
		return
	var was_cabin: bool = state == "cabin"
	state = "idle"
	if player and is_instance_valid(player):
		player.teleport(ladder_foot(), PI)
		player.controls_enabled = _player_ctl
	if fight and fight.cover_ctl:
		fight.cover_ctl.enabled = _cover_was
	_bullet_time(true)
	_weapons_held(false)
	_apply_acc(false)
	if cam.current:
		cam.current = false
		var back: Camera3D = _back_cam(_prev_cam)
		if back:
			back.make_current()
	else:
		var d: CameraDirector = CameraDirector.live()
		if d != null and d.cutting():
			_restore_pending = true     # the cut gives the screen back to the cabin camera when it ends: pass it on then
			_restore_to = _prev_cam
	_prev_cam = null
	if was_cabin:
		left.emit()


## The camera to come back to: the current one, or the player's when a director cut holds the screen.
func _screen_cam() -> Camera3D:
	var cur: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var d: CameraDirector = CameraDirector.live()
	if cur != null and d != null and cur == d.cam:
		return player.camera if player and is_instance_valid(player) else null
	return cur


func _back_cam(c: Camera3D) -> Camera3D:
	if c != null and is_instance_valid(c) and c.is_inside_tree():
		return c
	if player and is_instance_valid(player) and player.camera and player.camera.is_inside_tree():
		return player.camera
	return null


func _process(_delta: float) -> void:
	if not _restore_pending:
		return
	if state != "idle":
		_restore_pending = false
		return
	if cam.current:
		_restore_pending = false
		cam.current = false
		var back: Camera3D = _back_cam(_restore_to)
		if back:
			back.make_current()
		_restore_to = null
	else:
		var d: CameraDirector = CameraDirector.live()
		if d == null or not d.cutting():
			_restore_pending = false   # the cut gave the screen to someone else (a cinematic): nothing to undo
			_restore_to = null


## No shooting and no aiming from the ladder or the cabin (the [E] / mouse belong to the crane); cleared on leave.
func _weapons_held(on: bool) -> void:
	var w: WeaponDirector = fight.weapons if fight else null
	if w == null or not is_instance_valid(w):
		return
	w.fire_override = false if on else null
	w.aim_override = false if on else null


func _bullet_time(on: bool) -> void:
	if fight == null or not ("bullet_time" in fight):
		return
	var bt: Variant = fight.get("bullet_time")
	if bt is Object and is_instance_valid(bt) and "enabled" in (bt as Object):
		(bt as Object).set("enabled", on)


## The gunmen aim worse at the cabin (accuracy x cabin_acc while the player is up there).
func _apply_acc(on: bool) -> void:
	if not on:
		for g: Variant in _acc_saved.keys():
			if is_instance_valid(g):
				(g as Gunman).accuracy_k = float(_acc_saved[g])
		_acc_saved.clear()
		return
	if fight == null or is_equal_approx(cabin_acc, 1.0):
		return
	for g2: Variant in fight.gunmen:
		if is_instance_valid(g2) and not _acc_saved.has(g2):
			_acc_saved[g2] = (g2 as Gunman).accuracy_k
			(g2 as Gunman).accuracy_k *= cabin_acc


# ----- drop -----
func drop() -> bool:
	if state != "cabin" or drops_left <= 0 or drop_t >= 0.0 or reload_t >= 0.0 or hook_box == null:
		return false
	drop_t = 0.0
	if fight:
		fight.play_cue("chain_rattle", hook_pos(), 2.0)
	return true


func _land() -> void:
	drop_t = -1.0
	drops_left -= 1
	drops_done += 1
	var c: Vector3 = footprint_centre()
	var kos: int = 0
	if fight:
		for e: Variant in fight.alive():
			if e is Gunman and footprint_has((e as Gunman).feet()):
				var r: String = (e as Gunman).take_hit({"kind": "blast", "from": c + Vector3(0.0, 6.0, 0.0)})
				if r == "knocked_out":
					kos += 1
	kos_total += kos
	# the container stays: low cover for everyone
	var body := StaticBody3D.new()
	body.name = "DroppedContainer%d" % drops_done
	body.add_to_group("cover")
	body.top_level = true
	add_child(body)
	body.global_transform = Transform3D(global_transform.basis, c)
	_container_mesh(body, COLS[(drops_done - 1) % COLS.size()])
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(CONT_L, CONT_H, CONT_W)
	cs.shape = bs
	cs.position = Vector3(0.0, CONT_H * 0.5, 0.0)
	body.add_child(cs)
	landed.append(body)
	if fight and fight.cover:
		var before: int = fight.cover.count()
		fight.cover.add_box(Transform3D(global_transform.basis, c + Vector3(0.0, CONT_H * 0.5, 0.0)), Vector3(CONT_L, CONT_H, CONT_W))
		var ids := PackedInt32Array()
		for i: int in range(before, fight.cover.count()):
			ids.append(i)
		_slots_of[body] = ids
		fight.reprune()
	Impact.hit(self, "finisher", {"pos": c + Vector3(0.0, 0.4, 0.0), "dir": Vector3.DOWN})
	Impact.shake(self, 0.55)
	if hook_box and is_instance_valid(hook_box):
		hook_box.queue_free()
	hook_box = null
	footprint.visible = false
	shadow.visible = false
	if drops_left > 0:
		reload_t = 0.0
	dropped.emit(c, kos)


# ----- step -----
func step(dt: float) -> void:
	_hint = ""
	match state:
		"idle":
			if usable and player and player.controls_enabled and drops_left > 0 and near_ladder(player.global_position):
				_hint = T_LADDER
		"climb":
			climb_t += dt
			var u: float = clampf(climb_t / CLIMB_S, 0.0, 1.0)
			player.global_position = _climb_from.lerp(ladder_foot(), minf(u * 4.0, 1.0)) + Vector3(0.0, (CABIN_Y + 0.05) * u, 0.0)
			if u >= 1.0:
				_arrive()
		"cabin":
			_hint = T_CABIN if drops_left > 0 else T_EMPTY
			if drop_t < 0.0:
				var mv: Vector2 = _move_input()
				if mv != Vector2.ZERO:
					var oz: float = gantry_z
					trolley_x = clampf(trolley_x + mv.x * SPEED * dt, X_RANGE.x, X_RANGE.y)
					gantry_z = clampf(gantry_z + mv.y * SPEED * dt, Z_RANGE.x, Z_RANGE.y)
					_place()
					if not is_equal_approx(oz, gantry_z):
						player.global_position = cabin_spot()   # the cabin rolls with the gantry
			_apply_acc(true)
	if drop_t >= 0.0:
		drop_t += dt
		if drop_t > RATTLE_S and hook_box:
			var u2: float = clampf((drop_t - RATTLE_S) / FALL_S, 0.0, 1.0)
			hook_box.position.y = HANG_Y * (1.0 - u2 * u2)
			if u2 >= 1.0:
				_land()
	elif reload_t >= 0.0:
		reload_t += dt
		if reload_t >= RELOAD_S:
			reload_t = -1.0
			_hang_new()
	if state == "cabin":
		_update_cam()


func _move_input() -> Vector2:
	if move_override is Vector2:
		return move_override
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		v.x += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		v.y += 1.0
	return v


## A high three-quarter view of the hook and the footprint, with the director's punch / shake applied (META_FX).
func _update_cam() -> void:
	var look: Vector3 = global_transform * Vector3(trolley_x, HANG_Y * 0.42, gantry_z)
	var at: Vector3 = global_transform * Vector3(trolley_x + 3.0, BRIDGE_Y + 1.6, gantry_z + 9.0)
	var xf := Transform3D(Basis.IDENTITY, at).looking_at(look, Vector3.UP)
	var d: CameraDirector = CameraDirector.live()
	var fov_add: float = 0.0
	if d != null:
		var r: Vector3 = d.fx_rot_deg
		xf = xf * Transform3D(Basis.from_euler(Vector3(deg_to_rad(r.x), deg_to_rad(r.y), deg_to_rad(r.z))), d.fx_offset)
		fov_add = d.fx_fov
	cam.global_transform = xf
	cam.fov = 62.0 + fov_add


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or fight == null or fight.state != "running":
		return
	var k: InputEventKey = event
	if not k.pressed or k.echo:
		return
	if k.physical_keycode == KEY_E:
		if state == "idle" and _hint == T_LADDER:
			enter()
			get_viewport().set_input_as_handled()
		elif state == "cabin":
			drop()
			get_viewport().set_input_as_handled()
	elif k.physical_keycode == KEY_F and state == "cabin":
		leave()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if state != "idle":
		leave()
