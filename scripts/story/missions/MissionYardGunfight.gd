# File: res://scripts/story/missions/MissionYardGunfight.gd
# Day 3 gunfight in the container yard (plan 2026-10-30-w3-day3.md T3-T5), on MissionLairFight's GunFight.
#
# T3, D3W-1 THE MANNEQUIN HIDE (the opening phase, right after cine_d3_mannequins; fight wave 0):
#   - YardMannequins: ~40 mannequins in smart glasses in front of the opened stack; the player starts among them;
#   - 3 guards sweep the line-up with flashlights (Gunmen spawned blind: patrol_sight_m ~0; this mission does the seeing):
#     a flashlight cone of SWEEP_RANGE m and 30 deg swinging slowly across the field (a visible cone: its light reaches a
#     spot a good second before it is on it), footsteps;
#   - hold [X] = "ĐỨNG IM!" (a mannequin pose: no move, no aim), for at most HOLD_MAX s at a time (then the legs give for
#     a moment: "Mỏi chân!"); inside a cone (sees_player) while moving or not frozen = caught: the gunfight starts early,
#     no instant fail; shooting or sprinting next to a sweeper gives the player away too;
#   - gags: a live mannequin turns its head while the camera is not on it (YardMannequins.turn_head, at most twice, never
#     with "Giảm hù dọa"); one sweeper's phone plays the owner's meme_mannequin (AudioStreamPlayer3D on him; silence
#     without the file) while he checks the line-up;
#   - the end of the sweep: one "mannequin" is a guard in disguise: the v2 face scare (a soft sting and a plain shove with
#     "Giảm hù dọa"), then a scuffle: mash [E] (MASH_N presses within the window) to throw him (Impact finisher); a failed
#     mash = 20 damage and he shouts; the fight starts alerted either way;
#   - done info `hidden` = never caught. Retry inside wave 0 = the hide again from its start (wave 0's checkpoint).
# Difficulty: every number through Difficulty.pick.
class_name MissionYardGunfight
extends MissionGunfight

const CHECK_DT: float = 0.1
const SWEEP_RANGE: float = 12.0
const SWEEP_HALF_DEG: float = 15.0
const SWEEP_SWING_DEG: float = 55.0
## One full swing of a flashlight: slow enough that its light reaches a spot about 0.8 s before the cone is on it (the
## readability rule: the 55 deg swing peaks near 25 deg/s).
const SWEEP_SWING_S: float = 14.0
const FIELD_C := Vector3(-3.0, 0.0, -3.9)          # yard-local centre of the mannequin field
## Each sweeper swings round his own part of the field (yard-local aim points), so one spot is rarely lit by all three.
const AIMS: Array[Vector3] = [Vector3(-6.5, 0.0, -2.5), Vector3(0.5, 0.0, -3.0), Vector3(-3.0, 0.0, -5.8)]
const SWEEPERS: Array = [
	[Vector3(-9.0, 0.0, 0.8), Vector3(3.0, 0.0, 0.8)],
	[Vector3(-9.8, 0.0, -6.2), Vector3(-9.8, 0.0, 0.2)],
	[Vector3(3.6, 0.0, 0.2), Vector3(3.6, 0.0, -6.2)],
]
const PHONE_SWEEPER: int = 1
## No catching in the first seconds of the hide: the radio and the [X] prompt first, the flashlights already swinging.
const GRACE_S: float = 2.5
const BEAM_COL := Color(1.0, 0.95, 0.7, 0.13)
const BEAM_RED := Color(1.0, 0.2, 0.15, 0.22)
const T_FREEZE: String = "[X] giữ: ĐỨNG IM!"
const T_FROZEN: String = "ĐỨNG IM!"
const T_TIRED: String = "Mỏi chân!"
const T_CAUGHT: String = "Bị soi trúng! Đánh luôn!"
const T_MASH: String = "Bấm liên tục [E]: quật nó!"
const T_THROWN: String = "Quật bay!"
const T_SHOVED: String = "Nó xô mày rồi la toáng lên!"
const T_HIDE_INFO: String = "Lẫn vào đám ma-nơ-canh · còn %d s"
const MEME_SLOT: String = "meme_mannequin"
const CRANE_WAVE: int = 2
const JOKES: Array = [["Clear! A đang order trà sữa, e cứ tự nhiên.", "Sạch đợt này rồi."],
	["KDA đẹp đó e, a chụp màn hình rồi nha.", "Đẹp lắm, còn nữa đó."],
	["Bọn này farm exp hơi ngu, chuẩn bị đợt cuối.", "Đợt cuối sắp tới."]]

var mannequins: YardMannequins = null
## "sweep" | "scare" | "scuffle" | "done" | "caught" ("" = no hide: the mission has no level)
var hide_state: String = ""
var hide_t: float = 0.0
var hidden: bool = true
var sweep_s: float = 26.0
var sweep_range: float = SWEEP_RANGE
var sweep_half: float = SWEEP_HALF_DEG
var swing_s: float = SWEEP_SWING_S
var hold_max: float = 4.0
var mash_n: int = 9
var mash_window: float = 3.0
var mash_count: int = 0
var scuffle_t: float = 0.0
var scuffle_won: bool = false
var scares: int = 0
var meme_on: bool = false
var tired_t: float = 0.0
var frozen_t: float = 0.0
var hide_kos: int = 0
var _check_t: float = 0.0
var _beams: Array = []            # per sweeper: {"cone": MeshInstance3D, "mat": StandardMaterial3D}
var _scare: ScareDirector = null
var _guard_body: Node3D = null
var _fly_t: float = -1.0
var _fly_dir: Vector3 = Vector3.ZERO
var _fly_from: Vector3 = Vector3.ZERO
var _meme_player: AudioStreamPlayer3D = null
var _step_t: Dictionary = {}
var _info_s: int = -1
var _head_tries: Array[float] = [7.0, 15.0]
## T5: the combat waves after the hide (3 Thường / 2 Dễ), the crane (usable from wave CRANE_WAVE), ammo drops per wave.
var n_waves: int = 0
var crane: YardCrane = null
var crane_offered: bool = false
var preview_cuts: int = 0
var drops: Dictionary = {}          # fight wave -> AmmoPickup (hidden until that wave starts)
var _cleared_jokes: int = 0


func _start() -> void:
	sweep_s = float(Difficulty.pick(26.0, 20.0))
	sweep_range = float(Difficulty.pick(SWEEP_RANGE, 10.0))
	sweep_half = float(Difficulty.pick(SWEEP_HALF_DEG, 12.0))
	swing_s = float(Difficulty.pick(SWEEP_SWING_S, 16.0))
	hold_max = float(Difficulty.pick(7.0, 10.0))
	mash_n = int(Difficulty.pick(9, 6))
	mash_window = float(Difficulty.pick(3.0, 3.0))
	place_player()
	make_fight({"start_alerted": false})
	if level:
		fight.add_wave(_hide_wave())
		_add_yard_waves()
	else:
		var i: int = 0
		for w: Variant in pts.get("waves", []):
			var wave: Array = []
			for at: Variant in w:
				wave.append(guard(i, at))
				i += 1
			fight.add_wave(wave)
	fight.wave_cleared.connect(_on_wave_cleared)
	fight.start()
	if level:
		_build_hide()
		_build_crane()
		_build_drops()
		_reset_hide()
		MusicDirector.warm([MEME_SLOT])
		radio("Ma-nơ-canh full map, e cosplay ma-nơ-canh đi, giữ X đứng im khi đèn pin quét tới.", "Giữ [X] đứng im như ma-nơ-canh khi bị rọi đèn.", 6.0)
	else:
		radio("Wave guard incoming e ơi, hold Ctrl núp sau thùng rồi pop ra bắn.", "Giữ Ctrl để núp, nhắm bắn từng đứa.")


## T5: wave 1 from the gate (one pallet-shield guard: the shared stream's Gunman kind, ignored before the merge), wave 2
## on the container roofs (the crane wave), wave 3 (Thường) flankers from the east with a second shield guard.
func _add_yard_waves() -> void:
	n_waves = int(Difficulty.pick(3, 2))
	var sizes: Array = Difficulty.pick([4, 4, 5], [3, 3])
	var keys: Array[String] = ["gate", "roofs", "flank"]
	var shields: Dictionary = {0: 2, 2: 4}      # wave -> index of the shield guard in that wave
	var gi: int = 3
	for w: int in n_waves:
		var spots: Array = pts.get(keys[w], [])
		var wave: Array = []
		for k: int in mini(int(sizes[w]), spots.size()):
			var extra: Dictionary = {}
			if shields.get(w, -1) == k:
				extra["kind"] = "shield"
			wave.append(guard(gi, spots[k], [], extra))
			gi += 1
		fight.add_wave(wave)


func _lw(local: Vector3) -> Vector3:
	return (level.call("world", local) as Vector3) if level and level.has_method("world") else local


## Wave 0: the three sweepers, blind and unalerted (the hide logic sees for them), walking their lines.
func _hide_wave() -> Array:
	var w: Array = []
	for k: int in SWEEPERS.size():
		var route: Array = []
		for q: Variant in SWEEPERS[k]:
			route.append(_lw(q))
		w.append(guard(k, route[0], route, {"sight_m": 0.01, "fov_deg": 1.0, "alerted": false}))
	return w


func _build_hide() -> void:
	mannequins = YardMannequins.new()
	add_child(mannequins)
	var xf: Transform3D = (level as Node3D).global_transform
	mannequins.setup(xf, LairYard.FIGHT_START)
	_beams.clear()
	for k: int in SWEEPERS.size():
		var m := StandardMaterial3D.new()
		m.albedo_color = BEAM_COL
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.set_meta("vice_done", true)
		var cm := CylinderMesh.new()
		cm.top_radius = 0.06
		cm.bottom_radius = sweep_range * tan(deg_to_rad(sweep_half))
		cm.height = sweep_range
		cm.radial_segments = 16
		cm.rings = 1
		cm.cap_top = false
		cm.cap_bottom = false
		var cone := MeshInstance3D.new()
		cone.name = "Flashlight%d" % k
		cone.mesh = cm
		cone.material_override = m
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cone.top_level = true
		add_child(cone)
		_beams.append({"cone": cone, "mat": m})
	_scare = ScareDirector.new()
	_scare.name = "HideScare"
	_scare.loops_enabled = false
	_scare.flicker_enabled = false
	_scare.reduce_scares = StoryUtil.reduce_scares()
	add_child(_scare)


func _reset_hide() -> void:
	if mannequins == null:
		return
	hide_state = "sweep"
	hide_t = 0.0
	hidden = true
	mash_count = 0
	scuffle_t = 0.0
	scuffle_won = false
	tired_t = 0.0
	frozen_t = 0.0
	_check_t = 0.0
	_info_s = -1
	_fly_t = -1.0
	_head_tries = [7.0, 15.0]
	mannequins.reset()
	_set_frozen_controls(false)
	if _guard_body and is_instance_valid(_guard_body):
		_guard_body.queue_free()
	_guard_body = null
	for b: Dictionary in _beams:
		(b["mat"] as StandardMaterial3D).albedo_color = BEAM_COL
		(b["cone"] as Node3D).visible = true
	_set_meme(false)
	set_prompt(T_FREEZE)
	_show_hide_info()


# ----- the freeze -----
## "ĐỨNG IM!" on / off (held [X]; tests call it). No move, no aim while it holds.
func set_frozen(on: bool) -> void:
	if mannequins == null or hide_state != "sweep":
		on = false
	if on and tired_t > 0.0:
		on = false
	if mannequins and mannequins.frozen == on:
		return
	if mannequins:
		mannequins.frozen = on
	frozen_t = 0.0
	_set_frozen_controls(on)
	set_prompt(T_FROZEN if on else (T_FREEZE if hide_state == "sweep" else ""))


func _set_frozen_controls(on: bool) -> void:
	if player and is_instance_valid(player):
		player.controls_enabled = not on
		if on:
			player.velocity = Vector3.ZERO
			player.horizontal_speed = 0.0


func is_frozen() -> bool:
	return mannequins != null and mannequins.frozen


## The flashlight of sweeper k: eye and flat direction ({} when he is down or gone).
func beam_of(k: int) -> Dictionary:
	if fight == null or fight.wave != 0 or k >= fight.gunmen.size():
		return {}
	var g: Gunman = fight.gunmen[k]
	if not is_instance_valid(g) or g.is_defeated():
		return {}
	var c: Vector3 = _lw(AIMS[k] if k < AIMS.size() else FIELD_C)
	var to := Vector3(c.x - g.global_position.x, 0.0, c.z - g.global_position.z)
	var base: float = atan2(-to.x, -to.z) if to.length() > 0.5 else g.yaw
	var a: float = base + deg_to_rad(SWEEP_SWING_DEG) * sin(hide_t * TAU / swing_s + float(k) * 2.1)
	return {"eye": g.feet() + Vector3(0.0, 1.5, 0.0), "dir": Vector3(-sin(a), 0.0, -cos(a)), "g": g}


## The hide rule: a sweeper's light on the player while he moves or is not frozen.
func caught_now() -> bool:
	if player == null:
		return false
	var safe: bool = mannequins != null and mannequins.frozen_ok(player)
	if safe:
		return false
	for k: int in SWEEPERS.size():
		var b: Dictionary = beam_of(k)
		if b.is_empty():
			continue
		if sees_player(b["eye"], b["dir"], sweep_range, sweep_half):
			return true
	return false


# ----- T5: the crane, the ammo drops, the wave beats -----
func _build_crane() -> void:
	crane = YardCrane.new()
	add_child(crane)
	crane.setup((level as Node3D).global_transform, fight, int(Difficulty.pick(3, 3)), 5.0, 0.0)
	crane.usable = false
	crane.dropped.connect(_on_crane_dropped)


func _build_drops() -> void:
	var spots: Array = pts.get("drops", [])
	for k: int in mini(spots.size(), n_waves - 1):
		var p: AmmoPickup = fight.add_ammo(spots[k], WeaponData.Slot.SHOTGUN if k % 2 == 0 else WeaponData.Slot.PISTOL)
		p.take()                 # hidden until its wave calls it in on the radio
		drops[CRANE_WAVE + k] = p


## Every combat wave opens with a 0.6 s preview cut on its spawn (wave 1: the shield guard; wave 2: the crane cabin).
func _on_wave_started(i: int) -> void:
	super._on_wave_started(i)
	if crane:
		crane.usable = i >= CRANE_WAVE
	if i == 0 or level == null or state != "running":
		return
	var target: Node3D = null
	var w: int = i - 1
	if fight.gunmen.size() > 0:
		target = fight.gunmen[mini(2, fight.gunmen.size() - 1)] if w == 0 else fight.gunmen[0]
	match w:
		0:
			radio("Guard spawn ở cổng kìa e, có đứa vác pallet làm khiên, đánh vòng sườn nó!", "Bọn ở cổng. Đứa cầm khiên pallet thì bắn từ bên hông.", 4.5)
		1:
			if crane:
				target = crane.cabin_mark
				crane_offered = true
			radio_as("anh_duy", "Lên cần cẩu kìa e! Thả container đè tụi nó.", "Leo cần cẩu giữa bãi, thả container.", 4.5)
		2:
			radio("Tụi nó flank phía đông, thêm đứa khiên nữa. Đạn a thả ở bãi giữa đó.", "Bọn vòng sườn phía đông. Có đạn ở giữa bãi.", 4.5)
	if drops.has(i) and is_instance_valid(drops[i]):
		(drops[i] as AmmoPickup).reset()
		if w == 1:
			popup("Có thùng đạn ở bãi giữa!", 1.6)
	_preview(target)


func _preview(target: Node3D) -> void:
	preview_cuts += 1
	var d: CameraDirector = CameraDirector.live()
	if d != null and target != null and is_instance_valid(target) and target.is_inside_tree() and not d.cutting() and not (crane and crane.in_cabin()):
		d.preview_cut(target, 0.6)


func _on_wave_cleared(i: int) -> void:
	if i == 0 or i >= fight.waves.size() - 1 or state != "running":
		return
	var j: Array = JOKES[_cleared_jokes % JOKES.size()]
	_cleared_jokes += 1
	radio(String(j[0]), String(j[1]), 3.5)


func _on_crane_dropped(_pos: Vector3, kos: int) -> void:
	if kos > 0:
		if has_method("add_stat"):
			call("add_stat", "crane_kos", kos)
		popup("Container đè %d đứa!" % kos if kos > 1 else "Container đè trúng!", 1.6)
		if kos >= 2:
			radio("Strike! Bowling container luôn e ơi.", "Đè trúng mấy đứa luôn.", 3.0)


# ----- per tick -----
func _lair_tick(dt: float) -> void:
	if hide_state == "sweep" or hide_state == "scare" or hide_state == "scuffle":
		_hide_tick(dt)
		return
	_fly_tick(dt)
	if crane:
		crane.step(dt)
		set_prompt(crane.hint())
	if fight and int(clock * 10.0) % 3 == 0:
		if fight.wave == 0 or level == null:
			set_info("Còn %d bảo vệ" % fight.enemies_left())
		else:
			set_info("Đợt %d/%d · Còn %d bảo vệ" % [fight.wave, fight.waves.size() - 1, fight.enemies_left()])


func _hide_tick(dt: float) -> void:
	hide_t += dt
	_place_beams()
	_fly_tick(dt)
	match hide_state:
		"sweep":
			if tired_t > 0.0:
				tired_t -= dt
			if is_frozen():
				frozen_t += dt
				if frozen_t >= hold_max:
					set_frozen(false)
					tired_t = 1.0
					popup(T_TIRED, 1.0, WARN)
			_check_t -= dt
			if _check_t <= 0.0:
				_check_t = CHECK_DT
				_sweep_checks()
			_sweep_sounds(dt)
			_show_hide_info()
			if hide_state == "sweep" and hide_t >= sweep_s:
				_begin_scare()
		"scare":
			scuffle_t += dt
			if scuffle_t >= (0.35 if _reduce() else 0.9):
				hide_state = "scuffle"
				scuffle_t = 0.0
				set_prompt(T_MASH)
				popup(T_MASH, 1.6, WARN)
		"scuffle":
			scuffle_t += dt
			set_meter(clampf(float(mash_count) / float(mash_n) * 100.0, 0.0, 100.0), "Quật")
			if mash_count >= mash_n:
				_end_scuffle(true)
			elif scuffle_t >= mash_window:
				_end_scuffle(false)


func _reduce() -> bool:
	return _scare.reduce_scares if _scare else StoryUtil.reduce_scares()


func _place_beams() -> void:
	for k: int in _beams.size():
		var cone: MeshInstance3D = _beams[k]["cone"]
		var b: Dictionary = beam_of(k)
		if b.is_empty() or hide_state == "done" or hide_state == "caught":
			cone.visible = false
			continue
		cone.visible = true
		var eye: Vector3 = b["eye"]
		var d: Vector3 = b["dir"]
		var tip: Vector3 = eye + d * (sweep_range * 0.6) + Vector3(0.0, -1.5, 0.0)   # tilted down: the light on the floor ahead
		var axis: Vector3 = (eye - tip).normalized()
		var x: Vector3 = axis.cross(Vector3.UP).normalized()
		if x.length() < 0.1:
			x = Vector3.RIGHT
		var z: Vector3 = x.cross(axis).normalized()
		cone.global_transform = Transform3D(Basis(x, axis, z), eye - axis * (sweep_range * 0.5))


func _sweep_checks() -> void:
	# anyone alerted (a shot, a sprint next to him, a hit) or knocked out: the hide is blown
	for k: int in mini(SWEEPERS.size(), fight.gunmen.size()):
		var g: Gunman = fight.gunmen[k]
		if is_instance_valid(g) and (g.is_alerted or g.is_defeated()):
			_caught()
			return
	if hide_t >= GRACE_S and caught_now():
		_caught()
		return
	for i: int in _head_tries.size():
		if hide_t >= _head_tries[i] and mannequins.turn_head():
			_head_tries.remove_at(i)
			break
	if not meme_on and hide_t >= 3.0 and hide_t < sweep_s - 4.0:
		_set_meme(true)


func _caught() -> void:
	if hide_state != "sweep":
		return
	hide_state = "caught"
	hidden = false
	set_frozen(false)
	_set_meme(false)
	popup(T_CAUGHT, 2.0, WARN)
	radio("Toang r, lộ hàng r e! Combat thôi!", "Bị lộ rồi, đánh đi!", 3.0)
	for b: Dictionary in _beams:
		(b["mat"] as StandardMaterial3D).albedo_color = BEAM_RED
	_alert_all()
	_after_hide()


func _alert_all() -> void:
	for e: Variant in fight.alive():
		if e is Gunman:
			(e as Gunman).alert(player.global_position)


func _begin_scare() -> void:
	set_frozen(false)
	_set_meme(false)
	hide_state = "scare"
	scuffle_t = 0.0
	scares += 1
	var d: CineCrowd = mannequins.disguised
	var at: Vector3 = player.global_position + player.global_basis.x * -0.9 + Vector3(0.0, 0.0, 0.0)
	if d:
		d.visible = false
	_guard_body = StoryCast.build(GUARD_IDS[0])
	if _guard_body:
		add_child(_guard_body)
		_guard_body.global_position = Vector3(at.x, player.global_position.y, at.z)
		_guard_body.look_at(player.global_position, Vector3.UP, true)
	if _scare:
		_scare.play_face_scare("open", "jump", false)
	if _reduce():
		popup("Một con ma-nơ-canh xô mày!", 1.4, WARN)


func mash() -> void:
	if hide_state == "scuffle":
		mash_count += 1


func _end_scuffle(won: bool) -> void:
	scuffle_won = won
	hide_state = "done"
	set_prompt("")
	set_meter(0.0)
	if won:
		hide_kos += 1
		popup(T_THROWN, 1.6)
		var dir: Vector3 = WeaponMath.flat_dir(_guard_body.global_position - player.global_position) if _guard_body else Vector3.FORWARD
		Impact.hit(self, "finisher", {"pos": (_guard_body.global_position if _guard_body else player.global_position) + Vector3(0.0, 1.0, 0.0), "dir": dir})
		if has_method("add_stat"):
			call("add_stat", "ko")
		_fly_t = 0.0
		_fly_dir = dir
		_fly_from = _guard_body.global_position if _guard_body else player.global_position
	else:
		popup(T_SHOVED, 1.8, WARN)
		if _guard_body:
			fight.hit_player(_guard_body, 20.0)
			var sh := Label3D.new()
			sh.text = GunData.T_ALERT
			sh.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sh.font_size = 44
			sh.outline_size = 10
			sh.pixel_size = 0.006
			sh.modulate = Color("#FFE14D")
			sh.position = Vector3(0.0, 2.2, 0.0)
			_guard_body.add_child(sh)
		_fly_t = -1.0
	_alert_all()
	_after_hide()


## The thrown guard: a comic arc away from the player, a tumble, then he lies there.
func _fly_tick(dt: float) -> void:
	if _fly_t < 0.0 or _guard_body == null or not is_instance_valid(_guard_body):
		return
	_fly_t += dt
	var u: float = clampf(_fly_t / 0.7, 0.0, 1.0)
	_guard_body.global_position = _fly_from + _fly_dir * 3.2 * u + Vector3(0.0, sin(PI * u) * 1.3, 0.0)
	_guard_body.rotation.x = -PI * 0.5 * u
	if u >= 1.0:
		_fly_t = -1.0


func _after_hide() -> void:
	set_prompt("")
	for b: Dictionary in _beams:
		(b["cone"] as Node3D).visible = false


func _sweep_sounds(dt: float) -> void:
	if player == null:
		return
	for k: int in mini(SWEEPERS.size(), fight.gunmen.size()):
		var g: Gunman = fight.gunmen[k]
		if not is_instance_valid(g) or g.speed_now < 0.5:
			continue
		var t: float = float(_step_t.get(k, 0.0)) - dt
		if t <= 0.0:
			t = 0.55
			YardSfx.play3d(self, "step", g.feet(), -6.0, 16.0)
		_step_t[k] = t


func _show_hide_info() -> void:
	var s: int = maxi(0, ceili(sweep_s - hide_t))
	if s != _info_s:
		_info_s = s
		set_info(T_HIDE_INFO % s)


## The meme on the sweeper's phone while he checks the line-up: the owner's file through MusicDirector's cache (warmed at
## the start on a worker thread; not warm or no file = silence).
func _set_meme(on: bool) -> void:
	if on == meme_on:
		return
	meme_on = on
	if on:
		cues_played.append(MEME_SLOT)
	if not on:
		if _meme_player and is_instance_valid(_meme_player):
			_meme_player.queue_free()
		_meme_player = null
		return
	if fight == null or PHONE_SWEEPER >= fight.gunmen.size() or not MusicDirector.is_warm(MEME_SLOT):
		return
	var st: AudioStream = MusicDirector.load_slot(MEME_SLOT)
	var g: Gunman = fight.gunmen[PHONE_SWEEPER]
	if st == null or not is_instance_valid(g):
		return
	_meme_player = AudioStreamPlayer3D.new()
	_meme_player.name = "PhoneMeme"
	_meme_player.stream = st
	_meme_player.volume_db = -6.0
	_meme_player.max_distance = 18.0
	_meme_player.bus = CinePlayer._bus("SFX")
	_meme_player.position = Vector3(0.0, 1.3, 0.0)
	g.add_child(_meme_player)
	_meme_player.play()


func _input(event: InputEvent) -> void:
	if state != "running" or not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if k.echo:
		return
	if k.physical_keycode == KEY_X and hide_state == "sweep":
		set_frozen(k.pressed)
		get_viewport().set_input_as_handled()
	elif k.physical_keycode == KEY_E and k.pressed and hide_state == "scuffle":
		mash()
		get_viewport().set_input_as_handled()


func _on_fight_won() -> void:
	if crane and crane.in_cabin():
		crane.leave()
	won_info = {"ko": fight.ko_total + hide_kos, "hidden": hidden and mannequins != null,
		"crane": crane != null and crane.kos_total > 0}
	if rec and String(beat.get("replay", "")) != "":
		replay_wait = StoryStage.REPLAY_AFTER
	else:
		finish(won_info)


func _reset() -> void:
	if crane:
		crane.reset()            # out of the cabin first (GunFight.retry teleports the player), the drops back
	super._reset()
	if fight and fight.wave == 0:
		_reset_hide()
	if crane:
		crane.usable = fight != null and fight.wave >= CRANE_WAVE


func _cleanup() -> void:
	if crane and is_instance_valid(crane):
		crane.leave()
	_set_meme(false)
	_set_frozen_controls(false)
	super._cleanup()
