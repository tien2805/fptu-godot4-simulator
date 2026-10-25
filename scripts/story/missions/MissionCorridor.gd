# File: res://scripts/story/missions/MissionCorridor.gd
# Day 1 corridor horror beat (spec B-D5 beat 6, B-D3 toolkit): a 30-60 s walk down a ground-floor corridor at night. The
# corridor is a code-built set (the CineFX "corridor" walls, doors, tube lamps, exit sign, plus collision) placed on the
# flat courtyard spot next to cine_d1_corridor's stage (the arcade of the real wing is broken by link blocks). Fear caps
# the walk (WALK_CAP); the ScareDirector flickers the tubes, beats the heart by the figure's distance and plays the cues:
#   p >= 0.15  the tubes stutter, then a sheep-masked figure stands still at the far end;
#   p >= 0.55  lights out (BLACKOUT_S, frozen in place), lights back: the figure is gone, a distorted bleat;
#   p >= 0.8   whisper and another stutter;
#   the far end (p >= END_P) after MIN_S s: done (cine_d1_corridor follows: the shiba bonk).
#   p >= 0.4   (horror polish H-D7) a locker on the right wall bursts open and a sheep mask falls out (locker_slam), a
#              fake-out within the ScareDirector's fake-out budget, before the blackout;
# "Giảm hù dọa": no blackout (a slow dim), quieter cues, no stutter strobe (ScareDirector.reduce_scares); the locker opens
# slower, a soft sting.
# No fail state: a discovery walk (the beat's retry is not needed).
class_name MissionCorridor
extends StoryMission

const LEN_M: float = 40.0
const WIDTH_M: float = 3.2
const HEIGHT_M: float = 3.0
const Z0: float = 20.0
const START_Z: float = 18.4
const END_P: float = 0.9
const MIN_S: float = 30.0
const WALK_CAP: float = 2.0
const BLACKOUT_S: float = 1.4
const FIGURE_Z: float = -18.6
const T_FEAR: String = "Chân run quá, không chạy nổi…"
const LOCKER_P: float = 0.4
## The locker stands on the right wall a little past the LOCKER_P point (local z).
const LOCKER_Z: float = 0.6
const LOCKER_D: float = 0.5

var set_root: Node3D
var corridor: Node3D
var figure: Node3D
var scare: ScareDirector
var xf: Transform3D = Transform3D.IDENTITY
var lights: Array = []
var tube: StandardMaterial3D
var progress: float = 0.0
var events: Array[String] = []
var locker_door: Node3D
var mask_drop: Node3D
const _MASK_IN := Vector3(0.0, 1.45, 0.0)
var _blackout_t: float = -1.0


func _start() -> void:
	xf = _find_spot()
	set_root = Node3D.new()
	set_root.name = "CorridorSet"
	add_child(set_root)
	set_root.global_transform = xf
	corridor = CineFX.build_prop("corridor", {"len": LEN_M, "z0": Z0, "closed": true, "width": WIDTH_M, "lamps": 8, "energy": 1.3})
	set_root.add_child(corridor)
	lights = corridor.get_meta("lamp_lights", [])
	tube = corridor.get_meta("lamp_bulb", null)
	_add_collision()
	figure = StoryCast.build("clone_masked")
	set_root.add_child(figure)
	figure.position = Vector3(-0.2, 0.0, FIGURE_Z)
	figure.rotation.y = PI   # faces +Z: down the corridor at the player
	figure.visible = false
	_build_locker()
	scare = ScareDirector.new()
	scare.reduce_scares = StoryUtil.reduce_scares()
	scare.player = player
	scare.flicker_enabled = false   # scripted stutters only
	add_child(scare)
	if tube:
		scare.register_light_groups([{"pos": xf * Vector3(0.0, HEIGHT_M, Z0 - LEN_M * 0.5), "mat": tube, "energy": tube.emission_energy_multiplier}])
	StoryAudio.warm(["sheep_bleat_distorted", "whisper_bed", "metal_creak", "heartbeat", "locker_slam"])
	_reset()


## A flat spot for the 5 x 44 m set: FreeRoam.cine_stage around cine_d1_corridor's courtyard point (yaw 271, the long axis
## along the courtyard), else in front of the player.
func _find_spot() -> Transform3D:
	var o: Variant = opts.get("xf", null)
	if o is Transform3D:
		return o
	if roam and roam.has_method("cine_stage"):
		var st: Variant = roam.call("cine_stage", {"landmark": "campus_parking_center", "at": Vector2(-7.34, 7.06), "near": 34.0,
			"size": Vector2(5.0, 44.0), "yaw_deg": 271.0})
		if st is Transform3D:
			return st
	var p: Vector3 = player.global_position if player else Vector3.ZERO
	return Transform3D(Basis(Vector3.UP, player.facing_yaw() if player else 0.0), p + Vector3(0.0, 0.0, 0.0))


## A grey corridor locker on the right wall (collision included) with a door on a hinge and a sheep mask inside.
func _build_locker() -> void:
	var x: float = WIDTH_M * 0.5 - LOCKER_D * 0.5
	var root := Node3D.new()
	root.name = "BurstLocker"
	set_root.add_child(root)
	root.position = Vector3(x, 0.0, LOCKER_Z)
	var body_m := StandardMaterial3D.new()
	body_m.albedo_color = Color("#5C6F82")
	body_m.metallic = 0.5
	body_m.roughness = 0.45
	var shell := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(LOCKER_D, 1.9, 0.6)
	shell.mesh = bm
	shell.material_override = body_m
	shell.position = Vector3(0.0, 0.95, 0.0)
	root.add_child(shell)
	var col := StaticBody3D.new()
	col.name = "LockerCollision"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(LOCKER_D, 1.9, 0.6)
	cs.shape = bs
	cs.position = Vector3(0.0, 0.95, 0.0)
	col.add_child(cs)
	root.add_child(col)
	locker_door = Node3D.new()
	locker_door.name = "LockerDoor"
	locker_door.position = Vector3(-LOCKER_D * 0.5 - 0.02, 0.0, 0.29)   # hinge on the near edge: the door swings out towards the player
	root.add_child(locker_door)
	var leaf := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.03, 1.8, 0.56)
	leaf.mesh = lm
	var door_m := StandardMaterial3D.new()
	door_m.albedo_color = Color("#6E8499")
	door_m.metallic = 0.5
	leaf.material_override = door_m
	leaf.position = Vector3(0.0, 0.95, -0.28)
	locker_door.add_child(leaf)
	mask_drop = CineFX.build_prop("sheep_mask")
	mask_drop.name = "FallingMask"
	root.add_child(mask_drop)
	_close_locker()


func _close_locker() -> void:
	if locker_door:
		locker_door.rotation = Vector3.ZERO
	if mask_drop:
		mask_drop.position = _MASK_IN
		mask_drop.rotation = Vector3(0.0, PI * 0.5, 0.0)   # faces out of the locker (-X, into the corridor)


## The locker bursts open, the mask tumbles out onto the floor (H-D7).
func burst_locker() -> void:
	var slow: bool = scare != null and scare.reduce_scares
	scare.play_cue("locker_slam", -2.0)
	if not slow:
		scare.fake_sting(-14.0)
	if not is_inside_tree():
		locker_door.rotation.y = 1.9
		mask_drop.position = Vector3(-0.85, 0.08, -0.2)
		return
	var tw: Tween = create_tween()
	tw.tween_property(locker_door, "rotation:y", 1.9, 0.45 if slow else 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tm: Tween = create_tween()
	tm.set_parallel(true)
	tm.tween_property(mask_drop, "position", Vector3(-0.85, 0.08, -0.2), 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tm.tween_property(mask_drop, "rotation", Vector3(-PI * 0.5, -PI * 0.2, 0.4), 0.55)


func _add_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "CorridorWalls"
	set_root.add_child(body)
	var zc: float = Z0 - LEN_M * 0.5
	for spec: Array in [[Vector3(0.3, HEIGHT_M, LEN_M + 0.6), Vector3(-(WIDTH_M * 0.5 + 0.15), HEIGHT_M * 0.5, zc)],
			[Vector3(0.3, HEIGHT_M, LEN_M + 0.6), Vector3(WIDTH_M * 0.5 + 0.15, HEIGHT_M * 0.5, zc)],
			[Vector3(WIDTH_M + 0.6, HEIGHT_M, 0.3), Vector3(0.0, HEIGHT_M * 0.5, Z0 + 0.15)],
			[Vector3(WIDTH_M + 0.6, HEIGHT_M, 0.3), Vector3(0.0, HEIGHT_M * 0.5, Z0 - LEN_M - 0.15)],
			[Vector3(WIDTH_M + 0.6, 0.2, LEN_M + 0.6), Vector3(0.0, HEIGHT_M + 0.1, zc)]]:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = spec[0]
		cs.shape = bs
		cs.position = spec[1]
		body.add_child(cs)


func _reset() -> void:
	progress = 0.0
	events.clear()
	_blackout_t = -1.0
	figure.visible = false
	_close_locker()
	_set_lights(true)
	teleport_player(xf * Vector3(0.1, 0.0, START_Z), _yaw_down())
	player.combat_speed_cap = WALK_CAP
	popup(T_FEAR, 2.4)
	set_prompt("")


func _yaw_down() -> float:
	var d: Vector3 = xf.basis * Vector3(0.0, 0.0, -1.0)
	return yaw_of(d)


## Progress 0..1 down the corridor (player's local z from START_Z to the far end).
func local_z() -> float:
	return (xf.affine_inverse() * player.global_position).z


func _set_lights(on: bool) -> void:
	for l: Variant in lights:
		if is_instance_valid(l):
			(l as Light3D).visible = on
	if tube:
		tube.emission_energy_multiplier = 2.5 if on else 0.04


func _tick(dt: float) -> void:
	player.combat_speed_cap = WALK_CAP
	progress = clampf((START_Z - local_z()) / (START_Z - (Z0 - LEN_M) - 1.0), 0.0, 1.0)
	var fig_d: float = flat(player.global_position, figure.global_position) if figure.visible else 40.0
	scare.set_threat(fig_d, false)
	set_info("Hành lang tầng trệt · %d%%" % int(progress * 100.0))
	if _blackout_t > 0.0:
		_blackout_t -= dt
		if _blackout_t <= 0.0:
			_set_lights(true)
			player.controls_enabled = true
			figure.visible = false
			events.append("gone")
			scare.play_cue("sheep_bleat_distorted", -4.0)
		return
	if progress >= 0.15 and not "flicker" in events:
		events.append("flicker")
		scare.flicker_near(player.global_position, 1.6)
		play_cue("fluoro_buzz", -6.0)
	if progress >= 0.25 and not "figure" in events:
		events.append("figure")
		figure.visible = true
	if progress >= LOCKER_P and not "locker" in events and not "blackout" in events and scare.try_fake_out("locker"):
		events.append("locker")
		burst_locker()
	if progress >= 0.55 and clock >= 12.0 and not "blackout" in events:
		events.append("blackout")
		if scare.reduce_scares:
			scare.flicker_near(player.global_position, 2.0)   # a slow dim instead of the blackout
			figure.visible = false
			events.append("gone")
			scare.play_cue("sheep_bleat_distorted", -4.0)
		else:
			_set_lights(false)
			player.controls_enabled = false
			_blackout_t = BLACKOUT_S
			scare.play_cue("metal_creak", -2.0)
		return
	if progress >= 0.8 and not "whisper" in events:
		events.append("whisper")
		scare.flicker_near(player.global_position, 1.2)
		scare.play_cue("whisper_bed", -10.0)
	if progress >= END_P:
		if clock >= MIN_S:
			finish({"events": events.size()})
		else:
			set_prompt("…Có tiếng gì đó sau lưng?")


func _cleanup() -> void:
	if scare and is_instance_valid(scare):
		scare.stop_all()
	if set_root and is_instance_valid(set_root):
		set_root.queue_free()
