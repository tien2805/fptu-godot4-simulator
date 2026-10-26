# File: res://scripts/story/missions/MissionBridge.gd
# Day 2 horror beat under the Rạch Hầm bridge (spec C-D6 beats 4-5): on foot after the chase, fog rolls over the canal bank;
# a wolf howl; red LED eyes glow in the dark under the deck: Sói Xám standing still, and the pack's eyes around him. Walking
# in, the pack's eyes go out one by one (heartbeat); at SNAP_M every eye snaps bright (a sting). Then, within RING_M, his
# phone rings: a cheesy synth ringtone (a synthesized SFX, not music) and a comic line in a bubble, the scare deflates, and
# the villain card "Sói Xám - đầu đàn Bầy Sói" (StoryVillainCard.show_for) runs before the duel beat starts.
# "Giảm hù dọa": no sting, a softer howl, the eyes fade in slowly instead of snapping.
# opts: "anchors" (StoryRoam anchors: bridge_bank = where Sói Xám stands, bridge_road = the player's start), "manual_card"
# (tests step `card`).
class_name MissionBridge
extends StoryMission

const SNAP_M: float = 11.0
const RING_M: float = 7.0
const RING_HOLD: float = 2.6
const FOG_DENSITY: float = 0.035
const FOG_BEGIN: float = 3.0
const FOG_END: float = 34.0
const PACK: Array[Vector3] = [Vector3(-4.5, 0.0, -1.5), Vector3(4.0, 0.0, -2.5), Vector3(-6.5, 0.0, -4.5), Vector3(6.5, 0.0, -5.0)]
const T_PROMPT: String = "Lại gần gầm cầu..."
const T_PHONE: String = "A lô? Mẹ hả... con đang bận, lát con gọi lại..."

var soi: Node3D
var bank: Vector3 = Vector3.ZERO
var eyes: Array[Node3D] = []
var phase: String = "walk"           # walk -> snapped -> ringing -> card -> done
var card: StoryVillainCard = null
var calm: bool = false
var bubble: Label3D
var _ring_t: float = 0.0
var _env: Environment = null
var _fog_saved: Array = []
var _howled: bool = false
var _beat_t: float = 0.0


func _start() -> void:
	calm = StoryUtil.reduce_scares()
	var anchors: Dictionary = opts.get("anchors", {})
	var ba: Dictionary = anchors.get("bridge_bank", {})
	var ra: Dictionary = anchors.get("bridge_road", {})
	bank = ba.get("pos", player.global_position + Vector3(0.0, 0.0, -14.0) if player else Vector3.ZERO)
	bank.y = ground_y(bank)
	if player and not ra.is_empty() and flat(player.global_position, bank) > 30.0:
		var st: Vector3 = free_spot(ra["pos"])
		teleport_player(st, yaw_of(bank - st))
	CineAudio.sfx("wolf_howl")
	CineAudio.sfx("ringtone_synth")
	var face: float = yaw_of((player.global_position if player else bank + Vector3(0.0, 0.0, 5.0)) - bank)
	soi = spawn_body("soi_xam", bank, face)
	bubble = Label3D.new()
	bubble.name = "Bubble"
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.font_size = 52
	bubble.pixel_size = 0.008
	bubble.outline_size = 10
	bubble.position = Vector3(0.0, 2.35, 0.0)
	bubble.visible = false
	if soi:
		soi.add_child(bubble)
	var basis := Basis(Vector3.UP, face)
	for p: Vector3 in PACK:
		var e: Node3D = _eye_pair()
		add_child(e)
		e.global_position = bank + basis * p + Vector3(0.0, 1.55, 0.0)
		e.rotation.y = face
		eyes.append(e)
	_fog(true)
	_reset()


func _reset() -> void:
	phase = "walk"
	_ring_t = 0.0
	_howled = false
	_beat_t = 0.0
	if bubble:
		bubble.visible = false
	for e: Node3D in eyes:
		e.visible = true
		e.scale = Vector3.ONE * (0.4 if calm else 1.0)
	set_prompt(T_PROMPT)
	set_info("Gầm cầu Rạch Hầm")


func _eye_pair() -> Node3D:
	var n := Node3D.new()
	n.name = "PackEyes"
	var m: StandardMaterial3D = CineFX._glow_mat(Color("#FF2A2A"), 5.0)
	for sx: float in [-0.06, 0.06]:
		CineFX._sphere(n, "Eye", 0.025, Vector3(sx, 0.0, 0.0), m)
	return n


func _tick(dt: float) -> void:
	if not _howled and clock >= 0.6:
		_howled = true
		play_cue("wolf_howl", -10.0 if calm else -2.0)
	var d: float = flat(player.global_position, bank) if player else 0.0
	match phase:
		"walk":
			if calm:   # the eyes fade in slowly instead of snapping
				for e: Node3D in eyes:
					e.scale = Vector3.ONE * minf(1.0, e.scale.x + dt * 0.25)
			_beat_t -= dt
			if _beat_t <= 0.0 and d < 22.0:
				_beat_t = 1.1
				play_cue("heartbeat", -8.0)
			for i: int in eyes.size():   # the pack's eyes go out one by one as the player comes in
				if eyes[i].visible and d < SNAP_M + 2.0 + 2.0 * float(eyes.size() - i):
					eyes[i].visible = false
			if d <= SNAP_M:
				phase = "snapped"
				if soi and soi.has_method("set_glow"):
					soi.call("set_glow", true)
				if not calm:
					play_cue("violin_screech", -4.0)
		"snapped":
			if d <= RING_M:
				phase = "ringing"
				_ring_t = 0.0
				play_cue("ringtone_synth", -3.0)
				bubble.text = T_PHONE
				bubble.visible = true
				set_prompt("")
		"ringing":
			_ring_t += dt
			if _ring_t >= RING_HOLD:
				phase = "card"
				bubble.visible = false
				_show_card()


func _show_card() -> void:
	card = StoryVillainCard.show_for(self, StoryCast.villain_data("soi_xam"), StoryCast.card_len("soi_xam"))
	if bool(opts.get("manual_card", false)):
		card.manual = true
	card.finished.connect(func() -> void:
		card = null
		phase = "done"
		finish({}), CONNECT_ONE_SHOT)


## Fog over the bank (on) or the time of day's own fog back (off): the WorldEnvironment of the host, both fog modes.
func _fog(on: bool) -> void:
	if on:
		var we: WorldEnvironment = roam.get_node_or_null("WorldEnvironment") as WorldEnvironment if roam else null
		_env = we.environment if we else null
		if _env == null:
			return
		_fog_saved = [_env.fog_enabled, _env.fog_density, _env.fog_light_color, _env.fog_depth_begin, _env.fog_depth_end]
		_env.fog_enabled = true
		_env.fog_light_color = Color(0.32, 0.36, 0.42)
		_env.fog_density = maxf(_env.fog_density, FOG_DENSITY if _env.fog_mode == Environment.FOG_MODE_EXPONENTIAL else _env.fog_density)
		_env.fog_depth_begin = FOG_BEGIN
		_env.fog_depth_end = FOG_END
	elif _env != null and _fog_saved.size() == 5:
		_env.fog_enabled = bool(_fog_saved[0])
		_env.fog_density = float(_fog_saved[1])
		_env.fog_light_color = _fog_saved[2]
		_env.fog_depth_begin = float(_fog_saved[3])
		_env.fog_depth_end = float(_fog_saved[4])
		_env = null


func _cleanup() -> void:
	_fog(false)
	if card and is_instance_valid(card):
		card.queue_free()
	card = null
