# File: res://scripts/story/missions/MissionHack.gd
# Day 5 typing battle (spec C-D8 beat 6) as the W3 burning server countdown (plan 2026-10-30-w3-day5.md T4, design D5W-1):
# at the terminal in the server room the player wipes "Lọ Thần 9.0" in StoryHack (the Stage 6 typing engine's story mode)
# while the room burns:
#   - a COUNTDOWN_S (Thường 90 s, Dễ 105 s) countdown to the fire-suppression gas, big and red on its own layer; the fire
#     grows in 4 stages at 90 / 60 / 30 / 10 s left (BasementFire: pooled CPUParticles3D fire and smoke, a flickering
#     light) under the alarm SFX ("alarm_siren", synthesized);
#   - guards breach at BREACH_AT (30 s and 60 s in; 3 / 2 guards Thường / Dễ) with a 0.6 s preview cut on the room's mouth:
#     the terminal hides and typing pauses (StoryHack.paused: nothing falls, no decay), the player gets the guns (a GunFight
#     of one wave, this class being a MissionLairFight; bullet time on, guarded) and two low crates to fight from; the
#     cleared breach shows "[E] quay lại máy" at the desk (return_to_desk());
#   - typing finished before 0 = win: the core rack sparks and shakes, the room catches fire for good (LairBasement.
#     set_fire), "blow" is marked, the short replay seg_d5_hack (focus: the core rack), then done {"kills", "leaks",
#     "breach_clean"} (breach_clean: no damage taken in the breaches);
#   - at 0 the gas fires: "TOANG!"; any retry (the gas, the leaks, a down in a breach) restarts the typing: full timer,
#     fire stage 0, no breach done.
# opts: "level" (LairBasement), "points" (spot, spot_yaw, breach, breach_door, cover, fires, smoke), "manual" also steps
# StoryHack (tests: hack.manual).
class_name MissionHack
extends MissionLairFight

const T_LEAKED: String = "Lọ Thần kịp gửi đề ra ngoài!"
const T_GAS: String = "Khí chữa cháy xả rồi!"
const T_BREACH: String = "Bảo vệ xông vào!"
const T_BREACH_MORE: String = "Thêm bảo vệ đang tới!"
const T_RETURN: String = "[E] quay lại máy"
const T_DESK: String = "Máy tính"
const T_SPREAD: String = "Lửa lan rộng!"
const BREACH_AT: Array[float] = [30.0, 60.0]
const CUT_S: float = 0.6
const RETURN_R: float = 1.8
const FIRE_LEFT: Array[float] = [60.0, 30.0, 10.0]   # seconds left where stages 1, 2, 3 start
## T8 sloppy-bot tuning (Thường / Dễ): the integrity to wipe as a share of StoryHack's (more processes to kill: the typing
## outlasts the first breach), and StoryHack's pace (slower spawns and falls: a sloppy typist keeps up until the last wave).
## Wave 3 integration re-tune on the merged gun core (x2.0 accuracy, 16 HP a bullet): the breaches take longer to clear and
## hurt more, so Thường's load went 1.45 -> 1.15 (the gas stays the pressure without eating every run) and the breach
## guards 4 -> 3 (four of them in the small room killed the sloppy bot on 7 tries out of 7).
const TYPING_LOAD: float = 1.15
const TYPING_LOAD_EASY: float = 1.15
const PACE: float = 0.68
const PACE_EASY: float = 0.55
## Guards per breach (Thường / Dễ).
const BREACH_GUARDS: int = 3
const BREACH_GUARDS_EASY: int = 2

var hack: StoryHack
var core: Node3D
var sparks: CPUParticles3D
var fire: BasementFire
var countdown_s: float = 90.0
var time_left: float = 90.0
## "typing" | "breach" | "return" | "won"
var phase: String = "typing"
var breaches_started: int = 0
var breaches_cleared: int = 0
var breach_dmg: float = 0.0
var cuts: int = 0
var gas_fired: int = 0
var countdown_layer: CanvasLayer
var countdown_label: Label
var _shake_t: float = -1.0
var _core_home: Vector3 = Vector3.ZERO
var _crates: Array[Node3D] = []
var _door_mark: Node3D = null
var _desk_ring: Node3D = null
var _alarm: AudioStreamPlayer = null
var _shown_s: int = -1
## T9 readability: the breach guards off screen as edge chevrons, the desk as the goal on the way back.
var guide: BasementGuide = null


func _start() -> void:
	keep_top = false
	countdown_s = float(Difficulty.pick(90.0, 105.0))
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
	fire = BasementFire.new()
	add_child(fire)
	fire.top_level = true
	fire.setup(pts.get("fires", []), pts.get("smoke", []))
	if pts.has("breach_door"):
		_door_mark = Node3D.new()
		_door_mark.name = "BreachDoor"
		add_child(_door_mark)
		_door_mark.global_position = pts["breach_door"]
	_build_countdown()
	guide = BasementGuide.new()
	add_child(guide)
	guide.setup(self)
	_alarm = AudioStreamPlayer.new()
	_alarm.name = "Alarm"
	_alarm.bus = CinePlayer._bus("SFX")
	_alarm.volume_db = -16.0
	add_child(_alarm)
	rec = StoryStage.make_recorder(self, [player, core])
	hack = StoryHack.new()
	add_child(hack)
	hack.manual = manual
	hack.won.connect(_on_won)
	hack.lost.connect(_on_lost)
	_fresh_run(int(opts.get("seed", 5)))
	radio("Ok e, terminal mở r, gõ tên process nào kill process đó, xong thì rm -rf. Lẹ lên, phòng cháy r!", "Gõ đúng tên tiến trình để xóa tool, trước khi khí chữa cháy xả.")


## The start of the typing (the first run and every retry): full timer, fire stage 0, no breach done, at the desk.
func _fresh_run(seed_val: int) -> void:
	time_left = countdown_s
	phase = "typing"
	breaches_started = 0
	breaches_cleared = 0
	breach_dmg = 0.0
	_shown_s = -1
	_shake_t = -1.0
	if core:
		core.position = _core_home
	_end_fight()
	_set_crates(false)
	if fire:
		fire.set_stage(0)
	_alarm_on(true)
	_to_desk()
	hack.hp_max = StoryHack.MAX_HP * float(Difficulty.pick(TYPING_LOAD, TYPING_LOAD_EASY))   # the typing load (T8 tuned)
	hack.pace = float(Difficulty.pick(PACE, PACE_EASY))
	hack.start(seed_val)
	set_prompt("")
	_refresh_countdown()


## At the desk, typing: controls off, the guns away (an unarmed lock while typing), the terminal back.
func _to_desk() -> void:
	if pts.has("spot"):
		teleport_player(pts["spot"], float(pts.get("spot_yaw", 0.0)))
	if player:
		player.controls_enabled = false
	armed = false
	_lock_weapons(true)
	if _desk_ring and is_instance_valid(_desk_ring):
		_desk_ring.queue_free()
	_desk_ring = null
	if hack:
		hack.paused = false
	if guide:
		guide.watch(null)
		guide.clear_goal()
	_bullet_time(false)


# ---------------------------------------------------------------------------
# The countdown, the fire, the breaches
# ---------------------------------------------------------------------------
func _tick(dt: float) -> void:
	if manual and hack and hack.active:
		hack.step(dt)
	if _shake_t >= 0.0 and core:
		_shake_t += dt
		core.position = _core_home + Vector3(sin(_shake_t * 47.0) * 0.03, 0.0, cos(_shake_t * 39.0) * 0.03) * maxf(0.0, 1.0 - _shake_t)
	if replay_wait >= 0.0:
		replay_wait -= dt
		if replay_wait < 0.0:
			if countdown_layer:
				countdown_layer.visible = false
			play_short_replay(rec, String(beat.get("replay", "seg_d5_hack")), core if core else player, player, func() -> void:
				finish({"kills": hack.kills, "leaks": hack.leaks, "breach_clean": is_zero_approx(breach_dmg)}))
		return
	if phase == "won" or state != "running":
		return
	time_left -= dt
	var elapsed: float = countdown_s - time_left
	if breaches_started < BREACH_AT.size() and elapsed >= BREACH_AT[breaches_started]:
		_breach()
	if fire:
		var fs: int = fire_stage_of(time_left)
		if fs > fire.stage and fire.stage >= 0:
			popup(T_SPREAD, 1.6, WARN)                 # T9: the fire never grows unannounced
			play_cue("sub_boom", -8.0)
		fire.set_stage(fs)
	_refresh_countdown()
	if phase == "return" and player and pts.has("spot") and flat(player.global_position, pts["spot"]) <= RETURN_R:
		set_prompt(T_RETURN)
	if time_left <= 0.0:
		time_left = 0.0
		_gas()


## The fire stage for the seconds left (0 at 90 s, 1 from 60, 2 from 30, 3 from 10).
static func fire_stage_of(left: float) -> int:
	var s: int = 0
	for v: float in FIRE_LEFT:
		if left <= v:
			s += 1
	return s


func _gas() -> void:
	gas_fired += 1
	_alarm_on(false)
	_end_fight()                          # the gas floors everyone: no shots at the fail card
	if hack:
		hack.stop()                       # the terminal dies with the room: nothing typed behind the fail card counts
	play_cue("static_burst", -2.0)
	fail(T_GAS)


## A breach: the terminal hides (typing paused, no decay), the guns and a one-wave GunFight, the preview cut on the door.
## A breach that starts while the last one still fights joins it: its guards come in as the fight's next wave (the earlier
## guards stay; the cut and the line when they spawn).
func _breach() -> void:
	breaches_started += 1
	if _desk_ring and is_instance_valid(_desk_ring):
		_desk_ring.queue_free()           # no stale "back to the desk" ring while guards come in
	_desk_ring = null
	if phase == "breach" and fight and is_instance_valid(fight) and fight.state == "running":
		fight.add_wave(_breach_wave())
		popup(T_BREACH_MORE, 2.0, WARN)
		return
	phase = "breach"
	if hack:
		hack.paused = true
	if player:
		player.controls_enabled = true
	_lock_weapons(false)
	armed = true
	_end_fight()
	_set_crates(true)
	make_fight({"start_alerted": true, "nav": level.call("nav_graph") if level and level.has_method("nav_graph") else null})
	for c: Array in pts.get("cover", []):
		fight.cover.add_box(Transform3D(Basis(), (c[0] as Vector3) + Vector3(0.0, (c[1] as Vector3).y * 0.5, 0.0)), c[1])
	fight.add_wave(_breach_wave())
	fight.player_hit.connect(_on_player_hit)
	if guide:
		guide.watch(fight)
		guide.clear_goal()
	fight.start()
	_bullet_time(true)
	popup(T_BREACH, 2.0, WARN)
	set_prompt("Bắn hạ bảo vệ rồi quay lại máy")
	play_cue("locker_slam", -2.0)
	_door_cut()
	if breaches_started == 1:
		radio("Guard breach r e! Bỏ máy, xử tụi nó trước, progress a giữ cho.", "Bảo vệ vào! Đánh trước, máy vẫn giữ tiến độ.", 4.0)
	else:
		_shift_line()


## The guards of breach number breaches_started (Difficulty.pick), at the breach spots.
func _breach_wave() -> Array:
	var wave: Array = []
	var spots: Array = pts.get("breach", [])
	var n: int = mini(int(Difficulty.pick(BREACH_GUARDS, BREACH_GUARDS_EASY)), spots.size())
	for k: int in n:
		wave.append(guard(breaches_started * 3 + k, spots[(k + breaches_started) % spots.size()]))
	return wave


func _door_cut() -> void:
	if _door_mark:
		cuts += 1
		var cd: CameraDirector = CameraDirector.live()
		if cd:
			cd.preview_cut(_door_mark, CUT_S)


func _shift_line() -> void:
	radio_as("za_man", "Ca hai tới rồi đó em. Anh trả lương theo giờ mà.", "", 4.0)


func _on_player_hit(_source: Node3D, damage: float) -> void:
	if phase == "breach":
		breach_dmg += damage


## No recorder per breach wave: the hack's own recorder (the player and the core) stays. A joined breach's wave (index > 0)
## gets the door cut and Za Mẫn's line as it comes in.
func _on_wave_started(i: int) -> void:
	if i > 0 and phase == "breach":
		_door_cut()
		_shift_line()


func _on_enemy_ko(e: Node3D) -> void:
	super._on_enemy_ko(e)                 # the base bookkeeping (and the shared stream's ko stat after the merge)


## The breach is cleared: back to the desk with [E].
func _on_fight_won() -> void:
	if state != "running" or phase != "breach":
		return
	breaches_cleared = breaches_started     # a joined breach is cleared with the one it joined
	phase = "return"
	popup("Dọn xong! Quay lại máy!", 1.8)
	set_prompt(T_RETURN)
	if pts.has("spot"):
		_desk_ring = goal_marker(pts["spot"], 0.8)
		if guide:
			guide.set_goal(pts["spot"], T_DESK)


## [E] at the desk after a cleared breach (tests call it directly).
func return_to_desk() -> bool:
	if phase != "return" or state != "running":
		return false
	phase = "typing"
	_end_fight()
	_set_crates(false)
	_to_desk()
	set_prompt("")
	return true


func _unhandled_input(event: InputEvent) -> void:
	if state != "running" or phase != "return" or not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if k.pressed and not k.echo and k.physical_keycode == KEY_E and player and pts.has("spot") \
			and flat(player.global_position, pts["spot"]) <= RETURN_R:
		return_to_desk()
		get_viewport().set_input_as_handled()


func _end_fight() -> void:
	if fight and is_instance_valid(fight):
		fight.stop()
		fight.queue_free()
	fight = null


## The two low crates of the breaches (collision + cover), only while a breach runs.
func _set_crates(on: bool) -> void:
	if on and _crates.is_empty():
		var steel: StandardMaterial3D = CineFX._mat(Color("#5B636D"), 0.45)
		for c: Array in pts.get("cover", []):
			var body := StaticBody3D.new()
			body.name = "BreachCrate"
			add_child(body)
			body.global_position = c[0]
			var size: Vector3 = c[1]
			CineFX._box(body, "Box", size, Vector3(0.0, size.y * 0.5, 0.0), steel)
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = size
			cs.shape = bs
			cs.position = Vector3(0.0, size.y * 0.5, 0.0)
			body.add_child(cs)
			_crates.append(body)
	elif not on:
		for b: Node3D in _crates:
			if is_instance_valid(b):
				b.queue_free()
		_crates.clear()


## Bullet time (the shared stream's GunFight.bullet_time): on in the breaches, off while typing. Guarded.
func _bullet_time(on: bool) -> void:
	if fight == null or not ("bullet_time" in fight):
		return
	var bt: Variant = fight.get("bullet_time")
	if bt is Object and "enabled" in bt:
		(bt as Object).set("enabled", on)


func _alarm_on(on: bool) -> void:
	if _alarm == null:
		return
	if on and not _alarm.playing and is_inside_tree() and StoryAudio.ready_for(["alarm_siren"]):
		_alarm.stream = StoryAudio.stream("alarm_siren")
		if _alarm.stream:
			_alarm.play()
	elif not on:
		_alarm.stop()


func _build_countdown() -> void:
	countdown_layer = CanvasLayer.new()
	countdown_layer.name = "Countdown"
	countdown_layer.layer = 7
	add_child(countdown_layer)
	countdown_label = Label.new()
	countdown_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	countdown_label.offset_left = -300.0
	countdown_label.offset_right = 300.0
	countdown_label.offset_top = 14.0
	countdown_label.offset_bottom = 60.0
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.add_theme_font_size_override("font_size", 30)
	countdown_label.add_theme_color_override("font_color", Color("#FF4A3A"))
	countdown_label.add_theme_color_override("font_outline_color", Color(0.08, 0.0, 0.0, 0.95))
	countdown_label.add_theme_constant_override("outline_size", 7)
	countdown_layer.add_child(countdown_label)


func _refresh_countdown() -> void:
	if countdown_label == null:
		return
	var s: int = ceili(time_left)
	if s == _shown_s:
		return
	_shown_s = s
	countdown_label.text = "KHÍ CHỮA CHÁY XẢ SAU %02d:%02d" % [s / 60, s % 60]


# ---------------------------------------------------------------------------
# Win / lose / retry
# ---------------------------------------------------------------------------
func _on_won() -> void:
	if state != "running":
		return                            # behind the fail card (the gas, a leak): no win, no fire
	phase = "won"
	hack.stop()
	_alarm_on(false)
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
	if countdown_label:
		countdown_label.text = "ĐÃ XÓA. CÒN %d GIÂY" % ceili(time_left)
	replay_wait = StoryStage.REPLAY_AFTER


func _on_lost() -> void:
	if state != "running":
		return
	_alarm_on(false)
	fail(T_LEAKED)


func _on_fight_lost() -> void:
	_alarm_on(false)
	super._on_fight_lost()


## Any retry restarts the typing (full timer, fire stage 0, no breach done).
func _reset() -> void:
	replay_wait = -1.0
	last_ko = null
	if hack:
		_fresh_run(int(opts.get("seed", 5)) + retries)


func _cleanup() -> void:
	if core and is_instance_valid(core):
		core.position = _core_home
	if hack and is_instance_valid(hack):
		hack.stop()
		hack.queue_free()
	hack = null
	if fire and is_instance_valid(fire):
		fire.stop()
	_alarm_on(false)
	_set_crates(false)
	super._cleanup()


func hud_visible() -> bool:
	return state in ["running", "failed"] and replay == null
