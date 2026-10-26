# File: res://scripts/story/missions/MissionHack.gd
# Day 5 typing battle (spec C-D8 beat 6): at the terminal in the server room the player wipes "Lọ Thần 9.0" in StoryHack
# (the Stage 6 typing engine's story mode: the error words become the tool's processes). The player stands at the desk,
# controls off, weapons put away. `won` (the final command typed): the core rack sparks and shakes, the room catches fire
# (the burning server room of choice 2), "blow" is marked, then the short replay seg_d5_hack (focus: the core rack) and
# done. `lost` (MAX_LEAKS processes leaked the exam) = "TOANG!" -> retry() = a fresh run.
# opts: "level" (LairBasement), "points" (spot, spot_yaw), "manual" also steps StoryHack (tests: hack.manual).
class_name MissionHack
extends StoryMission

const T_LEAKED: String = "Lọ Thần kịp gửi đề ra ngoài!"

var hack: StoryHack
var level: Node3D
var pts: Dictionary = {}
var rec: CineReplayRecorder
var core: Node3D
var sparks: CPUParticles3D
var replay_wait: float = -1.0
var _shake_t: float = -1.0
var _core_home: Vector3 = Vector3.ZERO


func setup(r: Node3D, b: Dictionary, o: Dictionary = {}) -> void:
	super.setup(r, b, o)
	level = opts.get("level", null)
	pts = opts.get("points", {})


func _start() -> void:
	hide_top_panel()
	if pts.has("spot"):
		teleport_player(pts["spot"], float(pts.get("spot_yaw", 0.0)))
	if player:
		player.controls_enabled = false
	core = level.get("core") if level else null
	if core:
		_core_home = core.position
		sparks = CPUParticles3D.new()
		sparks.name = "CoreSparks"
		sparks.emitting = false
		sparks.amount = 40
		sparks.lifetime = 0.7
		sparks.explosiveness = 0.6
		sparks.direction = Vector3(0.0, 1.0, -1.0)
		sparks.spread = 60.0
		sparks.initial_velocity_min = 2.0
		sparks.initial_velocity_max = 5.0
		var qm := QuadMesh.new()
		qm.size = Vector2(0.05, 0.05)
		sparks.mesh = qm
		sparks.material_override = CineFX._glow_mat(Color("#FFD27A"), 4.0)
		add_child(sparks)
		sparks.global_position = core.global_position + Vector3(0.0, 1.4, 0.0)
	rec = StoryStage.make_recorder(self, [player, core])
	hack = StoryHack.new()
	add_child(hack)
	hack.manual = manual
	hack.won.connect(_on_won)
	hack.lost.connect(_on_lost)
	hack.start(int(opts.get("seed", 5)))
	radio("Ok e, terminal mở r, gõ tên process nào kill process đó, xong thì rm -rf.", "Gõ đúng tên tiến trình để xóa tool.")


func _on_won() -> void:
	hack.stop()
	if rec:
		rec.mark("blow")
	_shake_t = 0.0
	if sparks:
		sparks.restart()
		sparks.emitting = true
	play_cue("glass_crack", -2.0)
	if level and level.has_method("set_fire"):
		level.call("set_fire", true)
	popup("Lọ Thần 9.0 đã bị xóa!", 2.0)
	replay_wait = StoryStage.REPLAY_AFTER


func _on_lost() -> void:
	fail(T_LEAKED)


func _tick(dt: float) -> void:
	if manual and hack and hack.active:
		hack.step(dt)
	if _shake_t >= 0.0 and core:
		_shake_t += dt
		core.position = _core_home + Vector3(sin(_shake_t * 47.0) * 0.03, 0.0, cos(_shake_t * 39.0) * 0.03) * maxf(0.0, 1.0 - _shake_t)
	if replay_wait >= 0.0:
		replay_wait -= dt
		if replay_wait < 0.0:
			play_short_replay(rec, String(beat.get("replay", "seg_d5_hack")), core if core else player, player, func() -> void:
				finish({"kills": hack.kills, "leaks": hack.leaks}))


func _reset() -> void:
	replay_wait = -1.0
	_shake_t = -1.0
	if core:
		core.position = _core_home
	if player:
		player.controls_enabled = false
	if hack:
		hack.start(int(opts.get("seed", 5)) + retries)


func _cleanup() -> void:
	if core and is_instance_valid(core):
		core.position = _core_home
	if hack and is_instance_valid(hack):
		hack.stop()
		hack.queue_free()
	hack = null


func hud_visible() -> bool:
	return state in ["running", "failed"] and replay == null
