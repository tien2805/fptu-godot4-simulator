# File: res://scripts/story/missions/MissionChase.gd
# Day 1 foot chase (spec B-D5 beat 4): Shipper Mũ Đỏ bolts from the handover spot along PATH (campus-plot local points,
# measured clear with rays at 0.5 and 1.2 m): through the back-wing passage into the courtyard (the evening crowd), a loop
# round the courtyard, back out to the parking lane, west along it, down the west lane to the west gate. Stay within
# LEASH_M of him; farther than that for LEASH_GRACE s = fail ("TOANG!", retry from the start). His speed rubber-bands with
# the distance (fast when the player is close, slow when far, a taunting stop when very far) and is capped so the run
# lasts at least MIN_S (60-90 s overall). At SLIP_U of the path he slips on a banana peel (slide_whistle, "Ét o ét!"), the
# replay mark. At the end the short replay seg_d1_chase (A1 CineReplayRecorder / CineReplay) plays, then done.
class_name MissionChase
extends StoryMission

const PATH: Array[Vector3] = [Vector3(122.0, 0.0, 103.5), Vector3(121.5, 0.0, 95.0), Vector3(121.5, 0.0, 77.0),
	Vector3(135.0, 0.0, 66.0), Vector3(128.0, 0.0, 52.0), Vector3(140.0, 0.0, 40.0), Vector3(146.0, 0.0, 60.0),
	Vector3(121.5, 0.0, 77.5), Vector3(121.5, 0.0, 95.0), Vector3(121.5, 0.0, 103.5), Vector3(178.0, 0.0, 103.5),
	Vector3(183.0, 0.0, 98.0), Vector3(183.0, 0.0, 8.0), Vector3(181.0, 0.0, 3.0)]
## Player start: on the lane, 10 m east of the handover (where the stake-out leaves the player watching).
const START := Vector3(112.0, 0.0, 103.5)
const LEASH_M: float = 25.0
const LEASH_GRACE: float = 2.5
const WARN_M: float = 19.0
const TAUNT_M: float = 21.0
const SPEED_CLOSE: float = 5.0
const SPEED_MID: float = 4.2
const SPEED_FAR: float = 3.4
const MIN_S: float = 60.0
const SLIP_U: float = 0.55
const SLIP_S: float = 2.2
const T_LOST: String = "Mất dấu shipper rồi!"
const T_SLIP: String = "Ét o ét!"
const T_TAUNT: String = "Lêu lêu, đuổi không kịp!"
const T_WARN: String = "Sắp mất dấu! Chạy nhanh lên [Shift]"

var courier: Node3D
var banana: Node3D
var rec: CineReplayRecorder
var pts: PackedVector3Array = PackedVector3Array()
var cum: PackedFloat32Array = PackedFloat32Array()
var length_m: float = 0.0
var s: float = 0.0
var slipped: bool = false
var slip_t: float = 0.0
var far_t: float = 0.0
var taunts: int = 0
var ended: bool = false
var bubble: Label3D
var _taunt_cd: float = 0.0


func _start() -> void:
	pts.clear()
	cum.clear()
	length_m = 0.0
	for i: int in PATH.size():
		var p: Vector3 = campus(PATH[i])
		p.y = ground_y(p)
		pts.append(p)
		if i > 0:
			length_m += flat(pts[i - 1], p)
		cum.append(length_m)
	courier = spawn_body("courier_do", pts[0], 0.0)
	bubble = Label3D.new()
	bubble.name = "Bubble"
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.font_size = 56
	bubble.pixel_size = 0.008
	bubble.outline_size = 10
	bubble.position = Vector3(0.0, 2.3, 0.0)
	bubble.visible = false
	courier.add_child(bubble)
	banana = CineFX.build_prop("banana")
	add_child(banana)
	banana.global_position = point_at(SLIP_U * length_m)
	rec = StoryStage.make_recorder(self, [player, courier])
	_reset()


func _reset() -> void:
	s = 0.0
	slipped = false
	slip_t = 0.0
	far_t = 0.0
	ended = false
	_taunt_cd = 0.0
	banana.visible = true
	bubble.visible = false
	CharacterBuilder.stop_clip(courier)
	_place(0.0)
	var st: Vector3 = campus(START)
	teleport_player(free_spot(st), yaw_of(pts[0] - st))
	popup("Mũ Đỏ bỏ chạy! Đuổi theo!", 2.0, Color("#FFE66D"))


## Point at path distance d (clamped).
func point_at(d: float) -> Vector3:
	d = clampf(d, 0.0, length_m)
	for i: int in range(1, pts.size()):
		if d <= cum[i] or i == pts.size() - 1:
			var seg: float = maxf(cum[i] - cum[i - 1], 0.001)
			return pts[i - 1].lerp(pts[i], clampf((d - cum[i - 1]) / seg, 0.0, 1.0))
	return pts[pts.size() - 1]


func _place(v: float) -> void:
	var p: Vector3 = point_at(s)
	var ahead: Vector3 = point_at(s + 1.0) - p
	courier.global_position = p
	if Vector2(ahead.x, ahead.z).length() > 0.01:
		courier.rotation.y = yaw_of(ahead)
	CharacterBuilder.set_speed(courier, v)


func distance() -> float:
	return flat(player.global_position, courier.global_position) if player and courier else 0.0


## Courier speed for the player's distance, capped so the run never ends before MIN_S.
func speed_for(dist: float) -> float:
	var v: float = SPEED_CLOSE if dist < 8.0 else (SPEED_MID if dist < 15.0 else SPEED_FAR)
	if dist > TAUNT_M:
		v = 0.0
	if clock < MIN_S:
		v = minf(v, (length_m - s) / maxf(MIN_S - clock, 0.5))
	return v


func _tick(dt: float) -> void:
	if ended:
		return
	_taunt_cd -= dt
	var dist: float = distance()
	# leash
	if dist > LEASH_M:
		far_t += dt
		if far_t >= LEASH_GRACE:
			CharacterBuilder.set_speed(courier, 0.0)
			fail(T_LOST)
			return
	else:
		far_t = 0.0
	set_prompt(T_WARN if dist > WARN_M else "")
	set_info("Khoảng cách: %d m · %d giây" % [int(dist), int(clock)])
	# banana slip
	if slip_t > 0.0:
		slip_t -= dt
		if slip_t <= 0.0:
			CharacterBuilder.stop_clip(courier)
			bubble.visible = false
		return
	var v: float = speed_for(dist)
	if v <= 0.0 and _taunt_cd <= 0.0:
		taunts += 1
		_taunt_cd = 4.0
		_say(T_TAUNT, Color("#FF6B5A"))
		courier.rotation.y = yaw_of(player.global_position - courier.global_position)
	s = minf(s + v * dt, length_m)
	_place(v)
	if v <= 0.0:
		courier.rotation.y = yaw_of(player.global_position - courier.global_position)
	if not slipped and s >= SLIP_U * length_m:
		slip()
	if s >= length_m - 0.01 and clock >= MIN_S - 0.01:
		_end_run()


## The banana peel: slide whistle, the courier down for SLIP_S, the replay mark.
func slip() -> void:
	slipped = true
	slip_t = SLIP_S
	banana.visible = false
	CharacterBuilder.set_speed(courier, 0.0)
	CharacterBuilder.play(courier, "knockdown")
	_say(T_SLIP, Color("#FFE66D"))
	play_cue("slide_whistle")
	if rec:
		rec.mark("blow")


func _say(text: String, col: Color) -> void:
	bubble.text = text
	bubble.modulate = col
	bubble.visible = true


## End of the path: the short replay (the run keeps recording REPLAY_AFTER s first), then done.
func _end_run() -> void:
	ended = true
	set_prompt("")
	CharacterBuilder.set_speed(courier, 0.0)
	courier.rotation.y = yaw_of(player.global_position - courier.global_position)
	_say("Hết đường chạy rồi…", Color("#FFE66D"))
	var t := get_tree().create_timer(StoryStage.REPLAY_AFTER if not manual else 0.0)
	t.timeout.connect(func() -> void:
		if state != "running":
			return
		play_short_replay(rec, String(beat.get("replay", "seg_d1_chase")), courier, player,
			func() -> void: finish({"taunts": taunts, "secs": clock})))


func _cleanup() -> void:
	for n: Variant in [courier, banana, rec]:
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
