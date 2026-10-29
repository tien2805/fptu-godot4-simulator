# File: res://scripts/combat/guns/PlayerForklift.gd
# D3W-3 (plan 2026-10-30-w3-day3.md T7): the player's own forklift in the Day 3 boss arena (a second Forklift driven by the
# player). [F] within ENTER_R gets in / out; WASD drives (TOP_SPEED), [Q] / [E] forks down / up, [Chuột trái] throws the
# crate on the forks. Its own chase camera (CameraRules: the 70/30 framing toward the boss, COMBAT_DIST_MAX behind,
# FOOT_FOV; meta CameraDirector.META_FX: the director's punch / shake applied). Bullet time is off in it (guarded).
#   - rams: driving into the boss forklift at RAM_R calls boss.take_ram(dir, speed): "hit" (a side / back ram while his
#     forks are up) -> signal rammed(boss, power); "front" -> both bounce and the player takes front_dmg; one per RAM_CD;
#   - his charge into the player's forklift hurts the player through fight.hit_player (once per charge);
#   - lifting: forks low (< LOW_H), a tossed crate of his within PICK_R of the fork tips = on the forks; raised, then
#     [Chuột trái] throws it ahead in an arc (THROW_S); landing within HIT_R of him = boss.take_crate_hit(dir).
# The owner (MissionForklift) steps it: step(dt); tests drive it with input_override {"throttle", "steer", "fork"}.
class_name PlayerForklift
extends Node3D

signal rammed(target: Node3D, power: float)
signal entered
signal left

const ENTER_R: float = 2.6
const TOP_SPEED: float = 7.5
const RAM_R: float = 2.4
const RAM_CD: float = 1.0
const LOW_H: float = 0.45
const PICK_R: float = 1.3
const THROW_S: float = 0.9
const THROW_DIST: float = 9.0
const HIT_R: float = 2.4
const CHARGE_HIT_R: float = 2.6
const T_ENTER: String = "[F] lái xe nâng"
const T_DRIVE: String = "WASD lái · [Q]/[E] càng nâng · [Chuột trái] ném thùng · [F] xuống"

var fight: GunFight = null
var player: ThirdPersonController = null
var forklift: Forklift
var cam: Camera3D
var inside: bool = false
var input_override: Variant = null      # {"throttle": float, "steer": float, "fork": -1 | 0 | 1}
var front_dmg: float = 10.0
var rams: int = 0
var front_rams: int = 0
var charge_hits: int = 0
var throws: int = 0
var throw_hits: int = 0
var _home: Transform3D = Transform3D.IDENTITY
var _ram_cd: float = 0.0
var _flying: Array[Dictionary] = []      # {"node", "from", "to", "t", "dir"}
var _hint: String = ""
var _prev_cam: Camera3D = null
var _cover_was: bool = true
var _throw_req: bool = false
## Review fixes: false = no getting in (MissionForklift: while the arena crane is in use); the camera to pass the screen
## back to when a director cut held it at leave().
var usable: bool = true
var _restore_pending: bool = false
var _restore_to: Camera3D = null


## A forklift at `at` facing `yaw` (world) for the fight's player.
func setup(f: GunFight, at: Vector3, yaw: float) -> void:
	name = "PlayerForklift"
	fight = f
	player = f.player if f else null
	front_dmg = float(Difficulty.pick(10.0, 6.0))
	forklift = Forklift.new()
	forklift.name = "Forklift"
	forklift.top_level = true
	add_child(forklift)
	forklift.global_position = at
	forklift.rotation.y = yaw
	forklift.floor_y = at.y
	_home = forklift.global_transform
	if player:
		forklift.add_collision_exception_with(player)
		player.add_collision_exception_with(forklift)
	cam = Camera3D.new()
	cam.name = "ForkCam"
	cam.fov = CameraRules.FOOT_FOV
	cam.set_meta(CameraDirector.META_FX, self)
	cam.top_level = true
	add_child(cam)


func forks_h() -> float:
	return forklift.fork_h


func carrying() -> bool:
	return forklift.crate != null and is_instance_valid(forklift.crate)


func speed() -> float:
	return absf(forklift.speed)


func hint() -> String:
	return _hint


func boss() -> ForkliftBoss:
	return fight.boss as ForkliftBoss if fight and fight.boss and is_instance_valid(fight.boss) else null


# ----- in / out -----
func can_enter() -> bool:
	if inside or not usable or player == null or not player.controls_enabled or forklift.topple_done:
		return false
	return WeaponMath.flat(player.global_position, forklift.global_position) <= ENTER_R


func enter() -> bool:
	if not can_enter():
		return false
	inside = true
	player.controls_enabled = false
	if player.model:
		CharacterBuilder.set_base_clip(player.model, "sit")
		CharacterBuilder.play(player.model, "sit")
	if fight and fight.cover_ctl:
		fight.cover_ctl.leave()
		_cover_was = fight.cover_ctl.enabled
		fight.cover_ctl.enabled = false
	_bullet_time(false)
	_weapons_held(true)
	_ride()
	_restore_pending = false
	_prev_cam = _screen_cam()
	_update_cam()
	if cam.is_inside_tree():
		cam.make_current()
	entered.emit()
	return true


func leave() -> void:
	if not inside:
		return
	inside = false
	forklift.drive(0.0, 0.0, 0.0)
	if player and is_instance_valid(player):
		var out: Vector3 = forklift.global_transform * Vector3(-1.6, 0.0, 0.3)
		if player.model:
			player.model.position = Vector3.ZERO
			CharacterBuilder.set_base_clip(player.model, "")
			CharacterBuilder.stop_clip(player.model)
		player.teleport(Vector3(out.x, forklift.floor_y + 0.05, out.z), forklift.rotation.y)
		player.controls_enabled = true
	if fight and fight.cover_ctl:
		fight.cover_ctl.enabled = _cover_was
	_bullet_time(true)
	_weapons_held(false)
	if cam.current:
		cam.current = false
		var back: Camera3D = _back_cam(_prev_cam)
		if back:
			back.make_current()
	else:
		var d: CameraDirector = CameraDirector.live()
		if d != null and d.cutting():
			_restore_pending = true     # the cut (the topple orbit) gives the screen back to this camera: pass it on then
			_restore_to = _prev_cam
	_prev_cam = null
	left.emit()


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
	if inside:
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
			_restore_pending = false
			_restore_to = null


## Inside, [Chuột trái] throws the crate and nothing else: the guns neither fire nor aim; cleared on leave.
func _weapons_held(on: bool) -> void:
	var w: WeaponDirector = fight.weapons if fight else null
	if w == null or not is_instance_valid(w):
		return
	w.fire_override = false if on else null
	w.aim_override = false if on else null


## Back to its parking spot, empty (a retry).
func reset() -> void:
	leave()
	for e: Dictionary in _flying:
		if is_instance_valid(e["node"]):
			(e["node"] as Node).queue_free()
	_flying.clear()
	forklift.release_crate()
	forklift.speed = 0.0
	forklift.global_transform = _home
	forklift.lift_to(0.15)
	forklift.fork_h = 0.15
	forklift.forks.position.y = 0.15
	_ram_cd = 0.0


func _bullet_time(on: bool) -> void:
	if fight == null or not ("bullet_time" in fight):
		return
	var bt: Variant = fight.get("bullet_time")
	if bt is Object and is_instance_valid(bt) and "enabled" in (bt as Object):
		(bt as Object).set("enabled", on)


## The player rides on the seat: his body stays on the floor at the forklift (the boss and the gunmen aim at it; he is
## visible, so their hits count), his model sits on the seat.
func _ride() -> void:
	if player == null:
		return
	player.global_position = Vector3(forklift.global_position.x, forklift.floor_y + 0.05, forklift.global_position.z)
	player.set_facing(forklift.rotation.y)
	if player.model:
		player.model.position = forklift.seat_point() - player.global_position - Vector3(0.0, 0.47, 0.0)


# ----- step -----
func step(dt: float) -> void:
	_hint = ""
	_ram_cd = maxf(0.0, _ram_cd - dt)
	_tick_flying(dt)
	if not inside:
		if can_enter():
			_hint = T_ENTER
		return
	_hint = T_DRIVE
	var inp: Dictionary = _input_now()
	forklift.drive(float(inp["throttle"]), float(inp["steer"]), TOP_SPEED)
	var fk: int = int(inp["fork"])
	if fk != 0:
		forklift.lift_to(forklift.fork_target + float(fk) * Forklift.FORK_SPEED * dt)
	_ride()
	_pick_up()
	if _throw_req:
		_throw_req = false
		throw_crate()
	var b: ForkliftBoss = boss()
	if b and not b.is_down():
		_check_ram(b)
		_check_charge(b)
	_update_cam()


func _input_now() -> Dictionary:
	if input_override is Dictionary:
		var o: Dictionary = input_override
		return {"throttle": float(o.get("throttle", 0.0)), "steer": float(o.get("steer", 0.0)), "fork": int(o.get("fork", 0))}
	var th: float = 0.0
	var st: float = 0.0
	var fk: int = 0
	if Input.is_physical_key_pressed(KEY_W):
		th += 1.0
	if Input.is_physical_key_pressed(KEY_S):
		th -= 1.0
	if Input.is_physical_key_pressed(KEY_A):
		st += 1.0
	if Input.is_physical_key_pressed(KEY_D):
		st -= 1.0
	if Input.is_physical_key_pressed(KEY_E):
		fk += 1
	if Input.is_physical_key_pressed(KEY_Q):
		fk -= 1
	return {"throttle": th, "steer": st, "fork": fk}


func _check_ram(b: ForkliftBoss) -> void:
	if _ram_cd > 0.0 or speed() < 1.0:
		return
	var front: Vector3 = forklift.global_transform * Vector3(0.0, 0.0, -1.6 * signf(forklift.speed if absf(forklift.speed) > 0.01 else 1.0))
	if WeaponMath.flat(front, b.forklift.global_position) > RAM_R:
		return
	_ram_cd = RAM_CD
	var dir: Vector3 = forklift.forward() * signf(forklift.speed)
	var spd: float = speed()
	var r: String = b.take_ram(dir, spd)
	match r:
		"hit":
			rams += 1
			forklift.speed *= 0.3
			rammed.emit(b, spd)
		"front":
			front_rams += 1
			forklift.speed = -3.0 * signf(forklift.speed)
			if fight:
				fight.hit_player(b.forklift, front_dmg)
			Impact.hit(self, "heavy", {"pos": front + Vector3(0.0, 1.0, 0.0), "dir": -dir})
		"bump":
			forklift.speed *= -0.4


## His charge into the player's forklift: the chassis within CHARGE_HIT_R of his line hurts the player once per charge.
func _check_charge(b: ForkliftBoss) -> void:
	if b.st != ForkliftBoss.St.CHARGE or b.charge_hit_now():
		return
	if WeaponMath.flat(b.forklift.global_position, forklift.global_position) > CHARGE_HIT_R:
		return
	b.mark_charge_hit()
	if fight and String(fight.hit_player(b.forklift, b.charge_dmg(), true)) == "hit":
		charge_hits += 1
	forklift.speed = 0.0
	Impact.hit(self, "heavy", {"pos": forklift.global_position + Vector3(0.0, 1.0, 0.0), "dir": b.forklift.forward()})


func _pick_up() -> void:
	if carrying() or forklift.fork_h > LOW_H:
		return
	var b: ForkliftBoss = boss()
	if b == null:
		return
	var c: Node3D = b.take_floor_crate(forklift.fork_tips(), PICK_R)
	if c:
		forklift.carry(c)
		fight.play_cue("forklift_lift", forklift.global_position, -4.0)


## [Chuột trái]: the crate on the forks flies ahead in an arc.
func throw_crate() -> bool:
	if not inside or not carrying():
		return false
	var c: Node3D = forklift.release_crate(self)
	if c == null:
		return false
	throws += 1
	var dir: Vector3 = forklift.forward()
	var from: Vector3 = c.global_position
	var to: Vector3 = Vector3(from.x, forklift.floor_y, from.z) + dir * THROW_DIST
	var b: ForkliftBoss = boss()
	if b and WeaponMath.flat(b.forklift.global_position, to) < 4.0:
		to = Vector3(b.forklift.global_position.x, forklift.floor_y, b.forklift.global_position.z)   # a little aim help
	_flying.append({"node": c, "from": from, "to": to, "t": 0.0, "dir": dir})
	fight.play_cue("forklift_lift", forklift.global_position, 0.0)
	return true


func _tick_flying(dt: float) -> void:
	for i: int in range(_flying.size() - 1, -1, -1):
		var e: Dictionary = _flying[i]
		var c: Node3D = e["node"]
		e["t"] = float(e["t"]) + dt
		var u: float = clampf(float(e["t"]) / THROW_S, 0.0, 1.0)
		if is_instance_valid(c):
			c.global_position = (e["from"] as Vector3).lerp(e["to"], u) + Vector3(0.0, 3.0 * u * (1.0 - u) * 2.0, 0.0)
			c.rotation.x = u * 4.0
		if u >= 1.0:
			_flying.remove_at(i)
			var b: ForkliftBoss = boss()
			if b and WeaponMath.flat(b.forklift.global_position, e["to"]) <= HIT_R:
				if b.take_crate_hit(e["dir"]) == "hit":
					throw_hits += 1
			if fight:
				fight.play_cue("crate_smash", e["to"] + Vector3(0.0, 0.5, 0.0), 2.0)
			Impact.particles(self, "debris", e["to"] + Vector3(0.0, 0.4, 0.0), Vector3.UP, 0.8)
			if is_instance_valid(c):
				c.queue_free()


## The chase camera: behind the forklift on the line from the boss (the 70/30 framing), COMBAT_DIST_MAX back, raised.
func _update_cam() -> void:
	var me: Vector3 = forklift.global_position
	var b: ForkliftBoss = boss()
	var focus: Vector3 = me + Vector3(0.0, 1.2, 0.0)
	var back: Vector3 = -forklift.forward()
	if b and not b.is_down():
		var bp: Vector3 = b.forklift.global_position
		focus = me.lerp(bp, CameraRules.COMBAT_SPLIT) + Vector3(0.0, 1.2, 0.0)
		var away: Vector3 = WeaponMath.flat_dir(me - bp)
		if away.length() > 0.1:
			back = (back + away).normalized()
	var at: Vector3 = me + back * CameraRules.COMBAT_DIST_MAX + Vector3(0.0, 3.4, 0.0)
	var xf := Transform3D(Basis.IDENTITY, at).looking_at(focus, Vector3.UP)
	var d: CameraDirector = CameraDirector.live()
	var fov_add: float = 0.0
	if d != null:
		var r: Vector3 = d.fx_rot_deg
		xf = xf * Transform3D(Basis.from_euler(Vector3(deg_to_rad(r.x), deg_to_rad(r.y), deg_to_rad(r.z))), d.fx_offset)
		fov_add = d.fx_fov
	cam.global_transform = xf
	cam.fov = CameraRules.FOOT_FOV + fov_add


func _input(event: InputEvent) -> void:
	if fight == null or fight.state != "running":
		return
	if event is InputEventKey:
		var k: InputEventKey = event
		if k.pressed and not k.echo and k.physical_keycode == KEY_F:
			if inside:
				leave()
				get_viewport().set_input_as_handled()
			elif can_enter():
				enter()
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and inside:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_throw_req = true
			get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if inside:
		leave()
