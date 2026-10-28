# File: res://tests/test_camera_director.gd
# Headless test of the Q1 camera director (spec 2026-10-29 Q1, plan 2026-10-29-q1-camera.md) in small arenas. The framing
# checks (CameraFraming: head, chest and hips inside the 8 % safe area through Camera3D.unproject_position, a clear line of
# sight, the camera not in geometry) stand in for screenshots.
#   U  CamSpring (no overshoot, settling, impulse peak, angles the short way), CameraRules mappings at their ends, the
#      auto-yaw cap, trauma squared, the framing maths on a known camera.
#   D  CameraDirector: installed on demand (one, in the group), punch decays, shake on the player's camera and through
#      GameFX on another camera, preview_cut and slowmo_orbit frame their target (walls block candidates), slow motion only
#      through RadialWheel.scale_owner (another owner wins), the camera and the time scale come back, a pause ends a cut,
#      a stale restore of the director camera hands back.
#   F  FootCamRig: shoulder / distance / height, framing, pull-in against walls behind / beside / in a corner (never in
#      geometry), look-ahead, sprint FOV, landing dip.
#   C  Combat framing in a MeleeFight with 1-4 enemies: distance by count, the player and the target framed, the auto-yaw
#      never faster than 90 deg/s, an attacker straight behind stays behind (test_melee_combat's edge markers).
#   B  BikeCamRig: height 1.35 m, distance 3.8 -> 5.2 m and FOV 70 -> 86 with speed, +8 with nitro, the drift swing to the
#      outside, roll 30 % of the lean, the whip (cam_whip and a director punch with a dir), small road shake, the rider
#      framed at rest / top speed / nitro / drift, pulled in (not into) a wall behind.
#   T  BikeChase takedown cams: a crash cuts to the first clear candidate; walls block candidate 0, then 0 and 1; the
#      rider framed with a clear view; a kick hit whips the chase cam.
#   S  Cinematic shot helpers (two_shot, ots, hero, dutch, push_in) at u 0 / 0.5 / 1 for 3 actor spacings: the subjects
#      inside the letterboxed safe area, OTS keeps the face clear of the foreground head, dutch rolls; the helpers
#      validate, an unknown actor is refused, and CinePlayer plays a helper timeline with the subjects framed.
# Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_camera_director.gd   (dev: append -- --only=DFCBTS to pick parts)
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")

var fails: Array[String] = []
var arena: Node3D
var player: ThirdPersonController
var stats: Dictionary = {}


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		fails.append(msg)
		print("  FAIL ", msg)
	return ok


func _initialize() -> void:
	Engine.max_fps = 60
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	print("--- TEST CAMERA DIRECTOR ---")
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var n: Node = (load(pair[1]) as Script).new()
			n.name = pair[0]
			root.add_child(n)
	_part_u()
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _run() -> void:
	await _frames(2)
	_build_arena()
	await _frames(3)
	var only: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=")   # dev: run some parts only, e.g. -- --only=BT
	if only == "" or only.contains("D"):
		await _part_d()
	if only == "" or only.contains("F"):
		await _part_f()
	if only == "" or only.contains("C"):
		await _part_c()
	if only == "" or only.contains("B") or only.contains("T"):
		await _part_b()
	if only == "" or only.contains("T"):
		await _part_t()
	if only == "" or only.contains("S"):
		await _part_s()
	_finish()


func _finish() -> void:
	for a: String in ["gas", "brake", "steer_left", "steer_right", "drift", "nitro", "duck"]:
		if InputMap.has_action(a):
			Input.action_release(a)
	Engine.time_scale = 1.0
	RadialWheel.scale_owner = null
	if arena and is_instance_valid(arena):
		arena.free()
	if fails.is_empty():
		print("SUCCESS: camera director")
		quit(0)
	else:
		print("FAILED: %d issues" % fails.size())
		quit(1)


func _space() -> PhysicsDirectSpaceState3D:
	return arena.get_world_3d().direct_space_state


func _excl() -> Array[RID]:
	var e: Array[RID] = []
	if player:
		e.append(player.get_rid())
	return e


## Framing of subject n through cam; counts into stats[key] = [ok, total]; returns ok.
func _framed(key: String, cam: Camera3D, n: Node3D, lb: float = 0.0, quiet: bool = false) -> bool:
	var pts: PackedVector3Array = CameraFraming.subject_points(n)
	var rep: Dictionary = CameraFraming.report(cam, pts, _space(), _excl(), CameraRules.SAFE_MARGIN, lb)
	var s: Array = stats.get(key, [0, 0])
	s[1] = int(s[1]) + 1
	if bool(rep["ok"]):
		s[0] = int(s[0]) + 1
	elif not quiet:
		print("    %s: %s" % [key, CameraFraming.describe(cam, pts, rep)])
	stats[key] = s
	return bool(rep["ok"])


func _rate(key: String) -> float:
	var s: Array = stats.get(key, [0, 0])
	return float(s[0]) / maxf(float(s[1]), 1.0)


# ---------------------------------------------------------------------------
# U: maths
# ---------------------------------------------------------------------------
func _part_u() -> void:
	# spring: step response, no overshoot at small and big steps, 99 % by 6.6 / omega
	var w: float = 10.0
	for dt: float in [1.0 / 60.0, 1.0 / 20.0, 0.5]:
		var s := CamSpring.new()
		var peak: float = 0.0
		var t: float = 0.0
		var at99: float = -1.0
		while t < 3.0:
			s.step(Vector3.ONE, w, dt)
			t += dt
			peak = maxf(peak, s.pos.x)
			if at99 < 0.0 and s.pos.x >= 0.99:
				at99 = t
		_check(peak <= 1.0 + 1e-5, "spring dt %.3f: no overshoot (peak %.6f)" % [dt, peak])
		if dt < 0.1:
			_check(at99 > 0.0 and at99 <= 6.64 / w + dt, "spring dt %.3f: 99 %% by 6.6 / omega (%.3f s)" % [dt, at99])
	var v2: Vector2 = Vector2(0.0, 0.0)
	var mx: float = 0.0
	v2.y = w * exp(1.0)
	for i: int in 120:
		v2 = CamSpring.damp(v2.x, v2.y, 0.0, w, 1.0 / 120.0)
		mx = maxf(mx, v2.x)
	_check(absf(mx - 1.0) < 0.01 and absf(v2.x) < 0.05, "impulse w*e peaks at 1 and returns (%.3f, end %.3f)" % [mx, v2.x])
	var a: Vector2 = Vector2(3.0, 0.0)
	a = CamSpring.damp_angle(a.x, a.y, -3.0, 10.0, 0.05)
	_check(a.x > 3.0, "damp_angle goes the short way through PI (%.3f)" % a.x)
	# rules
	_check(is_equal_approx(CameraRules.combat_distance(0), 3.2) and is_equal_approx(CameraRules.combat_distance(1), 3.5) and is_equal_approx(CameraRules.combat_distance(2), 4.5)
		and is_equal_approx(CameraRules.combat_distance(4), 6.5) and is_equal_approx(CameraRules.combat_distance(9), 6.5), "combat distance 3.5 m (1 enemy) to 6.5 m (4+), 3.2 m without")
	_check(is_equal_approx(CameraRules.bike_distance(0.0), 3.8) and is_equal_approx(CameraRules.bike_distance(1.0), 5.2) and is_equal_approx(CameraRules.bike_distance(1.3), 5.2), "bike distance 3.8 -> 5.2 m")
	_check(is_equal_approx(CameraRules.bike_fov(0.0, false), 70.0) and is_equal_approx(CameraRules.bike_fov(1.0, false), 86.0) and is_equal_approx(CameraRules.bike_fov(1.0, true), 94.0), "bike FOV 70 -> 86, +8 nitro")
	_check(is_equal_approx(CameraRules.drift_swing_deg(1.0), 18.0) and is_equal_approx(CameraRules.drift_swing_deg(-0.0001), 0.0) and is_equal_approx(CameraRules.drift_swing_deg(-0.5), -15.0)
		and absf(CameraRules.drift_swing_deg(0.05)) >= 12.0, "drift swing 12-18 deg to the outside")
	_check(is_equal_approx(CameraRules.whip_curve(0.06), 1.0) and CameraRules.whip_curve(0.121) == 0.0 and CameraRules.whip_curve(-0.01) == 0.0, "whip pulse peaks at 0.06 s, over at 0.12 s")
	var yaw: float = 0.0
	var max_rate: float = 0.0
	for i: int in 240:
		var y2: float = CameraRules.auto_yaw_step(yaw, PI * 0.999, 1.0 / 60.0)
		max_rate = maxf(max_rate, absf(wrapf(y2 - yaw, -PI, PI)) * 60.0)
		yaw = y2
	_check(max_rate <= deg_to_rad(90.0) + 1e-4, "auto-yaw never above 90 deg/s (%.1f)" % rad_to_deg(max_rate))
	_check(absf(wrapf(PI * 0.999 - yaw, -PI, PI)) <= deg_to_rad(20.5), "auto-yaw ends within the dead zone (%.1f deg off)" % rad_to_deg(absf(wrapf(PI - yaw, -PI, PI))))
	_check(is_equal_approx(CameraRules.auto_yaw_step(0.0, deg_to_rad(15.0), 1.0 / 60.0), 0.0), "auto-yaw leaves a target inside the dead zone alone")
	# trauma squared: the same noise sample at trauma 1 and 0.5 is 4x
	var d := CameraDirector.new()
	d.trauma = 1.0
	d.clock = 0.37
	d._process(0.0)
	var big: float = d.fx_offset.length()
	d.trauma = 0.5
	d._process(0.0)
	var small: float = d.fx_offset.length()
	_check(big > 0.01 and absf(small / big - 0.25) < 1e-3, "shake amplitude is trauma squared (%.4f vs %.4f)" % [small, big])
	d.free()


## Framing maths on a known camera (needs the tree).
func _framing_maths() -> void:
	var cam := Camera3D.new()
	cam.fov = 70.0
	arena.add_child(cam)
	cam.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 50.0, 0.0))
	var c: Vector3 = Vector3(0.0, 50.0, -5.0)
	_check(CameraFraming.in_safe(cam, c), "a point straight ahead is in the safe area")
	var uv: Vector2 = CameraFraming.screen_uv(cam, c)
	_check(uv.distance_to(Vector2(0.5, 0.5)) < 0.01, "straight ahead is the screen centre (%s)" % str(uv))
	var half_h: float = 5.0 * tan(deg_to_rad(35.0))
	_check(not CameraFraming.in_safe(cam, c + Vector3(0.0, half_h * 0.9, 0.0)) and CameraFraming.in_safe(cam, c + Vector3(0.0, half_h * 0.8, 0.0)), "the 8 % margin at the top edge")
	_check(not CameraFraming.in_safe(cam, Vector3(0.0, 50.0, 5.0)), "a point behind is not framed")
	_check(not CameraFraming.in_safe(cam, c + Vector3(0.0, half_h * 0.7, 0.0), 0.08, 0.12) and CameraFraming.in_safe(cam, c + Vector3(0.0, half_h * 0.6, 0.0), 0.08, 0.12), "the letterbox shrinks the safe area")
	cam.free()


# ---------------------------------------------------------------------------
# arena
# ---------------------------------------------------------------------------
func _build_arena() -> void:
	arena = Node3D.new()
	arena.name = "Arena"
	root.add_child(arena)
	World.floor_box(arena, 1200.0)
	player = World.player(arena, Vector3(0.0, 0.0, 0.0), 0.0)
	player.pitch = ThirdPersonController.DEFAULT_PITCH
	player._update_camera(true)


func _wall(center: Vector3, size: Vector3) -> StaticBody3D:
	return World.wall(arena, center, size)


func _place(at: Vector3, yaw: float) -> void:
	player.teleport(at, yaw)
	player.pitch = ThirdPersonController.DEFAULT_PITCH
	player.input_override = null
	player.sprint_override = false
	player._update_camera(true)


# ---------------------------------------------------------------------------
# D: the director
# ---------------------------------------------------------------------------
func _part_d() -> void:
	print("  D: director")
	_framing_maths()
	var ds: Array[Node] = get_nodes_in_group(CameraDirector.GROUP)
	_check(ds.size() == 1 and CameraDirector.live() == ds[0], "one CameraDirector installed on demand, in the group (%d)" % ds.size())
	var d: CameraDirector = CameraDirector.live()
	if d == null:
		return
	_check(d.has_method("punch") and d.has_method("shake") and d.has_method("preview_cut") and d.has_method("slowmo_orbit"), "the director API")
	_check(player.camera.current and player.camera.has_meta(CameraDirector.META_FX), "the player's camera is current and director-aware")
	# punch
	await _frames(5)
	d.punch(0.6, Vector3(1.0, 0.0, 0.0))
	var peak: float = 0.0
	var rpeak: float = 0.0
	for i: int in 30:
		await _frames(1)
		peak = maxf(peak, d.fx_offset.length())
		rpeak = maxf(rpeak, d.fx_rot_deg.length())
	_check(peak > 0.08 and peak < 0.2, "punch 0.6 kicks the camera ~0.12 m (%.3f)" % peak)
	_check(rpeak > 1.0, "punch turns the camera a few degrees (%.2f)" % rpeak)
	_check(d.fx_offset.length() < 0.01 and absf(d.fx_fov) < 0.1, "the punch springs back within 0.5 s (%.4f)" % d.fx_offset.length())
	# shake on the player's camera
	var rot0: Vector3 = player.camera.rotation
	d.shake(0.8)
	await _frames(3)
	var rot: float = (player.camera.rotation - rot0).length()
	_check(rot > 0.001, "shake moves the player's camera (%.4f rad)" % rot)
	await _frames(45)
	_check(d.trauma == 0.0 and (player.camera.rotation - rot0).length() < 1e-4, "the shake is over after 0.8 / decay s (%.3f)" % d.trauma)
	# shake on a camera without a rig: GameFX
	var other := Camera3D.new()
	arena.add_child(other)
	other.make_current()
	var gfx: Node = root.get_node("GameFX")
	gfx.set("_shake_trauma", 0.0)
	d.shake(0.4)
	_check(float(gfx.get("_shake_trauma")) >= 0.39, "shake on another camera goes through GameFX.shake (%.2f)" % float(gfx.get("_shake_trauma")))
	gfx.set("_shake_trauma", 0.0)
	player.camera.make_current()
	other.queue_free()
	await _frames(30)
	d.trauma = 0.0
	# preview cut: the target 16 m ahead, a wall right on the first candidate's line
	_place(Vector3(0.0, 0.0, 0.0), 0.0)
	await _frames(5)
	var tgt := Node3D.new()
	tgt.name = "Hazard"
	arena.add_child(tgt)
	tgt.global_position = Vector3(0.0, 0.0, -16.0)
	var blocker: StaticBody3D = _wall(Vector3(0.0, 2.5, -10.0), Vector3(3.0, 5.0, 0.5))
	await _frames(2)
	_check(d.preview_cut(tgt, 0.6), "preview_cut runs")
	_check(d.cam.current and d.cut_kind == "preview" and d.cuts == 1, "the director camera holds the screen")
	_check(is_equal_approx(Engine.time_scale, CameraRules.CUT_SCALE) and RadialWheel.scale_owner == d, "slow motion %.2f through RadialWheel.scale_owner" % Engine.time_scale)
	var cut_ok: int = 0
	var cut_n: int = 0
	for i: int in 30:
		await _frames(1)
		if d.cut_kind == "":
			break
		cut_n += 1
		if _framed("preview", d.cam, tgt, 0.0, true):
			cut_ok += 1
	_check(cut_n > 20 and cut_ok == cut_n, "the preview cut frames the hazard past the wall every frame (%d / %d)" % [cut_ok, cut_n])
	await _frames(15)
	_check(d.cut_kind == "" and player.camera.current and is_equal_approx(Engine.time_scale, 1.0) and RadialWheel.scale_owner == null,
		"after 0.6 s real: the player's camera, normal time, owner released (%.2f)" % Engine.time_scale)
	# another owner of the time scale wins; the cut still plays
	var other_owner := RefCounted.new()
	RadialWheel.scale_owner = other_owner
	Engine.time_scale = 0.5
	_check(d.preview_cut(tgt, 0.3), "preview_cut with another time-scale owner")
	_check(is_equal_approx(Engine.time_scale, 0.5) and RadialWheel.scale_owner == other_owner, "the other owner's time scale is kept")
	await _frames(40)
	_check(d.cut_kind == "" and player.camera.current and is_equal_approx(Engine.time_scale, 0.5) and RadialWheel.scale_owner == other_owner, "... and never written back")
	RadialWheel.scale_owner = null
	Engine.time_scale = 1.0
	blocker.queue_free()
	# slow-motion orbit: a wall on the left of the target -> the orbit swings right, framed all along
	var enemy := MeleeEnemy.new()
	enemy.setup("courier", {"seed": 3, "ai": false, "label": "Thử"})
	enemy.top_level = true
	enemy.position = Vector3(0.0, 0.0, -4.0)
	arena.add_child(enemy)
	var wl: StaticBody3D = _wall(Vector3(-2.6, 2.0, -2.0), Vector3(0.4, 4.0, 6.0))
	await _frames(3)
	_check(d.slowmo_orbit(enemy, 0.5), "slowmo_orbit runs")
	_check(d.cut_kind == "orbit" and is_equal_approx(Engine.time_scale, CameraRules.ORBIT_SCALE), "orbit: slow motion %.2f" % Engine.time_scale)
	var orbit_ok: int = 0
	var orbit_n: int = 0
	var start_side: float = d.cam.global_position.x - enemy.global_position.x
	var end_side: float = start_side
	for i: int in 40:
		await _frames(1)
		if d.cut_kind == "":
			break
		orbit_n += 1
		end_side = d.cam.global_position.x - enemy.global_position.x
		if _framed("orbit", d.cam, enemy, 0.0, true):
			orbit_ok += 1
	_check(orbit_n >= 25 and orbit_ok == orbit_n, "the orbit frames the knocked-out enemy every frame (%d / %d)" % [orbit_ok, orbit_n])
	_check(end_side > start_side + 1.0, "the orbit swings away from the wall (x %.2f -> %.2f)" % [start_side, end_side])
	await _frames(5)
	_check(player.camera.current and is_equal_approx(Engine.time_scale, 1.0) and RadialWheel.scale_owner == null, "orbit over: the player's camera, normal time")
	wl.queue_free()
	# a pause ends a cut at once
	d.slowmo_orbit(enemy, 2.0)
	paused = true
	await process_frame
	_check(d.cut_kind == "" and is_equal_approx(Engine.time_scale, 1.0) and RadialWheel.scale_owner == null, "a pause ends the cut and gives back the time scale")
	paused = false
	await _frames(2)
	# a stale restore of the director camera hands back
	d.cam.make_current()
	await _frames(2)
	_check(player.camera.current, "a stale make_current of the director camera hands back to the gameplay camera")
	enemy.queue_free()
	tgt.queue_free()
	await _frames(2)


# ---------------------------------------------------------------------------
# F: on foot
# ---------------------------------------------------------------------------
func _part_f() -> void:
	print("  F: on foot")
	var rig: FootCamRig = player.cam_rig
	_place(Vector3(40.0, 0.0, 40.0), 0.0)
	await _frames(20)
	var cp: Vector3 = player.camera.position
	_check(absf(cp.x - CameraRules.FOOT_SHOULDER) < 0.01 and absf(cp.z - CameraRules.FOOT_DIST) < 0.01, "shoulder 0.45 m, distance 3.2 m (%s)" % str(cp))
	_check(absf(player.cam_pivot.global_position.y - (player.global_position.y + CameraRules.FOOT_HEIGHT)) < 0.02, "pivot 1.55 m above the feet")
	_check(_framed("foot_open", player.camera, player), "open ground: the player framed")
	# a wall 1.5 m behind (across the camera path)
	var walls: Array[Node] = []
	walls.append(_wall(Vector3(40.0, 2.0, 41.5 + 0.25), Vector3(8.0, 4.0, 0.5)))
	await _frames(10)
	_check(rig.dist <= 1.5 - CameraRules.PULL_MARGIN + 0.25 and rig.dist >= CameraRules.PULL_MIN, "a wall behind pulls the camera in (%.2f m)" % rig.dist)
	_check(_framed("foot_wall_back", player.camera, player), "wall behind: framed, clear view, not in the wall")
	# a wall 0.55 m to the right
	for w: Node in walls:
		w.free()
	walls.clear()
	walls.append(_wall(Vector3(40.0 + 0.55 + 0.25, 2.0, 40.0), Vector3(0.5, 4.0, 10.0)))
	await _frames(10)
	_check(rig.side <= 0.55 - CameraRules.PROBE_SIDE + 0.01, "a wall on the right pulls the shoulder in (%.2f m)" % rig.side)
	_check(_framed("foot_wall_right", player.camera, player), "wall on the right: framed, not in the wall")
	# a corner (behind + right)
	walls.append(_wall(Vector3(40.0, 2.0, 41.2 + 0.25), Vector3(8.0, 4.0, 0.5)))
	await _frames(10)
	_check(_framed("foot_corner", player.camera, player), "corner: framed, not in geometry")
	# turning a full circle pressed into that corner (0.55 m / 1.2 m): never in a wall, the view to the player clear
	var turn_geo: int = 0
	for k: int in 16:
		player.yaw = TAU * float(k) / 16.0
		await _frames(4)
		var rep: Dictionary = CameraFraming.report(player.camera, CameraFraming.subject_points(player), _space(), _excl())
		if bool(rep["los"]) and not bool(rep["in_geo"]):
			turn_geo += 1
		_framed("foot_tight_turn", player.camera, player, 0.0, true)
	_check(turn_geo == 16, "a full turn pressed into a corner: never in a wall, the view clear at every yaw (%d / 16)" % turn_geo)
	print("    pressed into a corner: head / chest / hips framed at %d / 16 yaws" % int((stats["foot_tight_turn"] as Array)[0]))
	for w: Node in walls:
		w.free()
	walls.clear()
	# a roomier corner (1.0 m / 1.6 m): framed at every yaw
	walls.append(_wall(Vector3(40.0 + 1.0 + 0.25, 2.0, 40.0), Vector3(0.5, 4.0, 10.0)))
	walls.append(_wall(Vector3(40.0, 2.0, 41.6 + 0.25), Vector3(8.0, 4.0, 0.5)))
	await _frames(10)
	var turn_ok: int = 0
	for k: int in 16:
		player.yaw = TAU * float(k) / 16.0
		await _frames(4)
		if _framed("foot_corner_turn", player.camera, player):
			turn_ok += 1
	_check(turn_ok == 16, "turning a full circle in a corner (1.0 m / 1.6 m): framed at every yaw (%d / 16)" % turn_ok)
	for w: Node in walls:
		w.free()
	walls.clear()
	# look-ahead and sprint FOV
	_place(Vector3(-40.0, 0.0, 60.0), 0.0)
	await _frames(5)
	player.input_override = Vector2(0.0, -1.0)
	await _frames(90)
	var ahead: Vector3 = rig._ahead.pos
	_check(absf(ahead.length() - CameraRules.FOOT_LOOK_AHEAD) < 0.08 and ahead.z < -0.5, "jogging: look-ahead 0.8 m in the move direction (%s)" % str(ahead))
	_check(_framed("foot_jog", player.camera, player), "jogging: framed")
	player.sprint_override = true
	await _frames(90)
	_check(absf(player.camera.fov - (CameraRules.FOOT_FOV + CameraRules.FOOT_SPRINT_FOV)) < 0.6, "sprint FOV +6 (%.1f)" % player.camera.fov)
	_check(_framed("foot_sprint", player.camera, player), "sprinting: framed")
	player.sprint_override = false
	player.input_override = null
	await _frames(60)
	# landing dip: a 3.5 m drop (a roll landing)
	var spot := Vector3(-60.0, 3.5, 0.0)
	_place(spot, 0.0)
	var low: float = 0.0
	var landed_at: int = -1
	for i: int in 150:
		await _frames(1)
		if landed_at < 0 and player.move_state == "LAND_ROLL":
			landed_at = i
		if landed_at >= 0:
			low = minf(low, rig._dip.x)
	_check(landed_at >= 0 and low <= -0.08, "a roll landing dips the camera (%.3f m)" % low)
	_check(absf(rig._dip.x) < 0.01, "the dip recovers (%.3f)" % rig._dip.x)
	_check(_framed("foot_landed", player.camera, player), "after the landing: framed")


# ---------------------------------------------------------------------------
# C: melee combat framing
# ---------------------------------------------------------------------------
func _part_c() -> void:
	print("  C: combat")
	var rig: FootCamRig = player.cam_rig
	var spots: Array[Vector3] = [Vector3(100.0, 0.0, 0.0), Vector3(140.0, 0.0, 0.0), Vector3(180.0, 0.0, 0.0), Vector3(220.0, 0.0, 0.0)]
	var wall_near: StaticBody3D = _wall(Vector3(220.0, 2.0, 2.6), Vector3(14.0, 4.0, 0.5))   # the 4-enemy fight next to a wall
	for n: int in range(1, 5):
		var at: Vector3 = spots[n - 1]
		_place(at, 0.0)
		await _frames(3)
		var fight := MeleeFight.new()
		fight.name = "Fight%d" % n
		arena.add_child(fight)
		fight.setup({"player": player, "seed": 10 + n, "max_attackers": 2})
		var spawns: Array = []
		for i: int in n:
			var ang: float = deg_to_rad(-40.0 + 80.0 * float(i) / maxf(float(n - 1), 1.0)) if n > 1 else 0.0
			spawns.append({"archetype": "courier", "at": at + Vector3(sin(ang) * 4.0, 0.0, -cos(ang) * 4.0), "opts": {"label": "C%d" % i, "hp_scale": 50.0}})
		fight.add_wave(spawns)
		fight.start()
		fight.combat.god = true
		var key: String = "combat_%d" % n
		var max_rate: float = 0.0
		var both: int = 0
		var samples: int = 0
		var player_ok: int = 0
		var dist_ok: bool = false
		for f: int in 300:
			await _frames(1)
			max_rate = maxf(max_rate, rig.last_auto_yaw_rate)
			if f >= 60 and f % 6 == 0:
				samples += 1
				var p_ok: bool = _framed(key + "_player", player.camera, player, 0.0, samples > 3 and (stats.get(key + "_player", [0, 0]) as Array)[1] - (stats.get(key + "_player", [0, 0]) as Array)[0] > 2)
				if p_ok:
					player_ok += 1
				elif samples < 40 and (samples % 4 == 0):
					print("      dbg f%d state %s ms %s pos %s cam %s pivot %s dist %.2f side %.2f full %.2f tgt %s pitch %.2f" % [f, str(fight.combat.state), player.move_state, str(player.global_position), str(player.camera.global_position), str(player.cam_pivot.global_position), rig.dist, rig.side, rig.full_dist, str(rig.target.global_position if rig.target else Vector3.ZERO), player.pitch])
				var t: Node3D = rig.target
				if t != null and p_ok and _framed(key + "_target", player.camera, t, 0.0, true):
					both += 1
			if f == 240:
				dist_ok = rig.in_combat and rig.combat_n == n and absf(rig.full_dist - CameraRules.combat_distance(n)) < 0.25
				_check(dist_ok, "%d enemies: distance %.2f m for %d in range (want %.1f)" % [n, rig.full_dist, rig.combat_n, CameraRules.combat_distance(n)])
		print("    %d enemies: player framed %d / %d, player + target %d / %d, max auto-yaw %.1f deg/s" % [n, player_ok, samples, both, samples, rad_to_deg(max_rate)])
		_check(player_ok == samples, "%d enemies: the player framed at every sample (%d / %d)" % [n, player_ok, samples])
		_check(float(both) >= 0.9 * float(samples), "%d enemies: player and target framed together in >= 90 %% of samples (%d / %d)" % [n, both, samples])
		_check(max_rate <= deg_to_rad(90.0) + 0.01, "%d enemies: auto-yaw never above 90 deg/s (%.1f)" % [n, rad_to_deg(max_rate)])
		fight.stop()
		fight.queue_free()
		await _frames(5)
	wall_near.queue_free()
	# an attacker straight behind (test_melee_combat's edge markers): the camera does not swing round
	_place(Vector3(300.0, 0.0, 0.0), 0.0)
	await _frames(3)
	var fb := MeleeFight.new()
	fb.name = "FightBehind"
	arena.add_child(fb)
	fb.setup({"player": player, "seed": 5})
	fb.add_wave([{"archetype": "courier", "at": Vector3(300.0, 0.0, 5.5), "opts": {"label": "B", "hp_scale": 50.0}}])
	fb.start()
	fb.combat.god = true
	var e: MeleeEnemy = fb.enemies[0]
	e.ai = false
	var yaw0: float = player.yaw
	await _frames(16)
	_check(player.camera.is_position_behind(e.global_position + Vector3.UP), "an enemy 5.5 m straight behind is behind the camera (edge markers)")
	await _frames(74)
	_check(absf(wrapf(player.yaw - yaw0, -PI, PI)) < 0.05, "the camera never swings round to it (yaw moved %.1f deg)" % rad_to_deg(absf(wrapf(player.yaw - yaw0, -PI, PI))))
	fb.stop()
	fb.queue_free()
	await _frames(3)


# ---------------------------------------------------------------------------
# B: the bike chase cam
# ---------------------------------------------------------------------------
var bike: PlayerBike


func _bike_excl() -> Array[RID]:
	var e: Array[RID] = _excl()
	if bike:
		e.append(bike.get_rid())
	return e


func _bike_framed(key: String, cam: Camera3D, n: Node3D, quiet: bool = false) -> bool:
	var pts: PackedVector3Array = CameraFraming.subject_points(n)
	var rep: Dictionary = CameraFraming.report(cam, pts, _space(), _bike_excl())
	var st: Array = stats.get(key, [0, 0])
	st[1] = int(st[1]) + 1
	if bool(rep["ok"]):
		st[0] = int(st[0]) + 1
	elif not quiet:
		print("    %s: %s" % [key, CameraFraming.describe(cam, pts, rep)])
	stats[key] = st
	return bool(rep["ok"])


func _bike_local_cam() -> Vector3:
	return bike.global_transform.affine_inverse() * bike.chase_cam.global_position


func _part_b() -> void:
	print("  B: bike")
	bike = (load("res://scenes/PlayerBike.tscn") as PackedScene).instantiate() as PlayerBike
	bike.name = "Bike"
	bike.lane_clamp_enabled = false
	bike.fallback_fall_y = -5.0
	arena.add_child(bike)
	bike.apply_speed_profile(PlayerBike.STAGE_PROFILE)
	bike.global_position = Vector3(-300.0, -0.13, 240.0)
	bike.chase_cam.make_current()
	await _frames(40)
	var rig: BikeCamRig = bike.cam_rig
	_check(rig != null and bike.chase_cam.has_meta(CameraDirector.META_FX), "the bike has a BikeCamRig and a director-aware camera")
	var lc: Vector3 = _bike_local_cam()
	_check(absf(bike.chase_cam.global_position.y - CameraRules.BIKE_HEIGHT) < 0.05, "at rest: camera 1.35 m above the road (%.2f)" % bike.chase_cam.global_position.y)
	_check(absf(Vector2(lc.x, lc.z).length() - CameraRules.BIKE_DIST_REST) < 0.1 and lc.z > 3.0, "at rest: 3.8 m behind (%s)" % str(lc))
	_check(absf(bike.chase_cam.fov - 70.0) < 0.5, "at rest: FOV 70 (%.1f)" % bike.chase_cam.fov)
	_check(_bike_framed("bike_rest", bike.chase_cam, bike.rider_node), "at rest: the rider framed")
	# top speed (straight along -Z)
	Input.action_press("gas")
	var shake_max: float = 0.0
	for i: int in 240:
		await _frames(1)
		if i > 120:
			shake_max = maxf(shake_max, maxf(absf(bike.chase_cam.h_offset), absf(bike.chase_cam.v_offset)))
		if i > 150 and i % 15 == 0:
			_bike_framed("bike_speed", bike.chase_cam, bike.rider_node)
	var u: float = bike.current_speed_ms / bike.max_speed_ms
	_check(u > 0.97, "the bike reached its top speed (%.2f)" % u)
	_check(absf(rig.dist - CameraRules.BIKE_DIST_TOP) < 0.2, "top speed: distance 5.2 m (%.2f)" % rig.dist)
	_check(absf(bike.chase_cam.fov - 86.0) < 1.2, "top speed: FOV 86 (%.1f)" % bike.chase_cam.fov)
	_check(absf(bike.chase_cam.global_position.y - CameraRules.BIKE_HEIGHT) < 0.06, "top speed: still 1.35 m high (%.2f)" % bike.chase_cam.global_position.y)
	_check(shake_max > 0.0005 and shake_max <= CameraRules.BIKE_ROAD_SHAKE * 1.05, "road shake grows with speed and stays small (%.4f m)" % shake_max)
	_check(_rate("bike_speed") == 1.0, "top speed: the rider framed at every sample")
	# nitro
	bike.set_nitro_enabled(true)
	bike.drift_charge = 100.0
	_check(bike.fire_nitro(), "nitro fires")
	var fov_max: float = 0.0
	for i: int in 120:
		await _frames(1)
		fov_max = maxf(fov_max, bike.chase_cam.fov)
		if i % 20 == 10:
			_bike_framed("bike_nitro", bike.chase_cam, bike.rider_node)
	_check(fov_max >= 86.0 + CameraRules.BIKE_NITRO_FOV - 0.5, "nitro: FOV +8 (max %.1f)" % fov_max)
	_check(_rate("bike_nitro") == 1.0, "nitro: the rider framed")
	await _frames(200)
	bike.set_nitro_enabled(false)
	# drift left: the camera swings 12-18 deg to the right (outside), roll follows the lean
	Input.action_press("steer_left", 1.0)
	Input.action_press("drift")
	var swing_ok: int = 0
	var swing_n: int = 0
	var roll_ok: bool = true
	var side_ok: int = 0
	for i: int in 120:
		await _frames(1)
		if i >= 60 and bike.is_drifting:
			swing_n += 1
			var sd: float = rad_to_deg(rig.swing)
			if sd >= CameraRules.BIKE_DRIFT_SWING_MIN - 0.5 and sd <= CameraRules.BIKE_DRIFT_SWING_MAX + 0.5:
				swing_ok += 1
			if _bike_local_cam().x > 0.4:
				side_ok += 1
			if absf(rig.roll - bike.tilt_angle * CameraRules.BIKE_ROLL_K) > 1e-4 or absf(rig.roll) < 0.02:
				roll_ok = false
			if i % 10 == 0:
				_bike_framed("bike_drift", bike.chase_cam, bike.rider_node)
	_check(swing_n > 40 and swing_ok == swing_n, "drift: swing 12-18 deg (%d / %d frames, last %.1f deg)" % [swing_ok, swing_n, rad_to_deg(rig.swing)])
	_check(side_ok == swing_n, "drift left: the camera sits on the outside (right) of the bike (%d / %d)" % [side_ok, swing_n])
	_check(roll_ok, "roll = 30 %% of the lean (%.3f vs %.3f)" % [rig.roll, bike.tilt_angle])
	_check(_rate("bike_drift") == 1.0, "drift: the rider framed")
	Input.action_release("drift")
	Input.action_release("steer_left")
	await _frames(60)
	# whip: cam_whip toward the right, then a director punch toward the left
	var w0: int = rig.whips
	bike.cam_whip(bike.global_basis.x)
	var wmin: float = 0.0
	var wmax: float = 0.0
	for i: int in 10:
		await _frames(1)
		wmin = minf(wmin, rig.whip_yaw)
	_check(rig.whips == w0 + 1 and rad_to_deg(wmin) < -CameraRules.BIKE_WHIP_DEG * 0.8, "cam_whip right: the view turns right ~7 deg (%.1f)" % rad_to_deg(wmin))
	_check(absf(rig.whip_yaw) < 1e-4, "the whip is over in 0.12 s")
	var d: CameraDirector = CameraDirector.live()
	d.punch(0.35, -bike.global_basis.x)
	for i: int in 10:
		await _frames(1)
		wmax = maxf(wmax, rig.whip_yaw)
	_check(rig.whips == w0 + 2 and rad_to_deg(wmax) > CameraRules.BIKE_WHIP_DEG * 0.8, "a director punch with a dir whips the chase cam toward it (%.1f)" % rad_to_deg(wmax))
	# brake to a stop 2.4 m in front of a wall behind: pulled in, never in the wall
	Input.action_release("gas")
	bike.current_speed_ms = 0.0
	await _frames(30)
	var back: Vector3 = bike.global_basis.z
	var wall: StaticBody3D = _wall(bike.global_position + back * 2.4 + Vector3.UP * 2.0, Vector3(8.0, 4.0, 0.4))
	wall.look_at(wall.global_position + back, Vector3.UP)
	await _frames(20)
	var cd: float = bike.chase_cam.global_position.distance_to(bike.global_position + Vector3.UP * 1.2)
	_check(cd < 2.4, "a wall 2.4 m behind pulls the chase cam in (%.2f m)" % cd)
	_check(_bike_framed("bike_wall", bike.chase_cam, bike.rider_node), "wall behind: the rider framed, the camera not in the wall")
	wall.queue_free()
	await _frames(3)


# ---------------------------------------------------------------------------
# T: takedown cams
# ---------------------------------------------------------------------------
func _part_t() -> void:
	print("  T: takedown cams")
	bike.global_position = Vector3(-300.0, -0.13, 200.0)
	bike.rotation = Vector3.ZERO
	bike.current_speed_ms = 0.0
	bike.chase_cam.make_current()
	for round_i: int in 3:
		var c := BikeChase.new()
		c.name = "TdChase%d" % round_i
		arena.add_child(c)
		c.setup({"bike": bike, "route": [Vector2(-300.0, 250.0), Vector2(-300.0, -500.0)], "start_s": 60.0, "manual_replay": true, "seed": 4})
		var w: Array = []
		for i: int in 2:
			w.append({"lane": [-1, 1][i], "opts": {"ai": false, "hp": 99, "label": "T%d" % i}})
		c.add_wave(w)
		c.start()
		c.combat.god = true
		await _frames(3)
		var b0: BikerEnemy = c.bikers[0]
		var b1: BikerEnemy = c.bikers[1]
		for pair: Array in [[b0, 1.95], [b1, -1.95]]:
			var be: BikerEnemy = pair[0]
			be.hold_along = 0.0
			be.hold_lat = float(pair[1])
			var p2: Vector2 = c.target_at(0.0, float(pair[1]))
			be.place(Vector3(p2.x, 0.0, p2.y), 0.0, 0.0)
		await _frames(3)
		var cpos: Vector3 = b0.ground_pos()
		var s3 := Vector3(c.p_right.x, 0.0, c.p_right.y) * (1.0 if (b0.pos2 - c.p_pos).dot(c.p_right) >= 0.0 else -1.0)
		var f3 := Vector3(c.p_fwd.x, 0.0, c.p_fwd.y)
		var walls: Array[Node] = []
		if round_i >= 1:                     # block candidate 0 (side, 5.5 m out)
			var wa: StaticBody3D = _wall(cpos + s3 * 3.6 + Vector3.UP * 2.0, Vector3(0.4, 4.0, 5.0))
			wa.look_at(wa.global_position + f3, Vector3.UP)
			walls.append(wa)
		if round_i >= 2:                     # block candidate 1 (front-low, 6 m ahead)
			var wb: StaticBody3D = _wall(cpos + f3 * 3.0 + s3 * 1.6 + Vector3.UP * 1.5, Vector3(2.4, 3.0, 0.4))
			wb.look_at(wb.global_position + f3, Vector3.UP)
			walls.append(wb)
		await _frames(2)
		b0.crash("traffic")
		_check(c.cam_mode == "td" and c.cam.current, "round %d: the takedown cuts to the chase camera" % round_i)
		_check(c.cam_pick == round_i, "round %d: candidate %d picked (got %d)" % [round_i, round_i, c.cam_pick])
		var ok_n: int = 0
		var n: int = 0
		for f: int in 24:
			await _frames(1)
			if c.cam_mode != "td":
				break
			n += 1
			if _bike_framed("td_%d" % round_i, c.cam, b0, true):
				ok_n += 1
		_check(n >= 10 and float(ok_n) >= 0.9 * float(n), "round %d: the falling rider framed with a clear view (%d / %d)" % [round_i, ok_n, n])
		await _frames(30)
		_check(c.cam_mode == "" and bike.chase_cam.current, "round %d: back to the bike's camera" % round_i)
		if round_i == 0:
			var w0: int = bike.cam_rig.whips
			c.combat.kick_hit.emit(b1, -1)
			_check(bike.cam_rig.whips == w0 + 1, "a kick hit whips the chase cam")
		c.stop()
		c.queue_free()
		for wn: Node in walls:
			wn.queue_free()
		await _frames(5)
		bike.global_position = Vector3(-300.0, -0.13, 200.0)
		bike.rotation = Vector3.ZERO
		bike.current_speed_ms = 0.0


# ---------------------------------------------------------------------------
# S: cinematic shot helpers
# ---------------------------------------------------------------------------
## One letterbox bar of the cinematic overlay (2.39:1) as a fraction of the screen height.
func _letterbox_frac() -> float:
	var vs: Vector2 = root.get_visible_rect().size
	return maxf((vs.y - vs.x / 2.39) * 0.5, 0.0) / vs.y


## The CinePlayer camera maths for one CineShots.eval result.
static func _apply_shot(cam: Camera3D, xf: Transform3D, c: Dictionary) -> void:
	var pos_w: Vector3 = xf * (c["pos"] as Vector3)
	var look_w: Vector3 = xf * (c["look"] as Vector3)
	var b: Basis = Basis.looking_at(look_w - pos_w, Vector3.UP)
	if c.has("roll"):
		b = b * Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(float(c["roll"])))
	cam.global_transform = Transform3D(b, pos_w)
	cam.fov = float(c["fov"])


## The view from cam to the subject's head passes at least 0.22 m from the foreground actor's head and neck (OTS).
static func _clear_of(cam: Camera3D, subject_head: Vector3, fg: Node3D) -> bool:
	var pts: PackedVector3Array = CameraFraming.subject_points(fg)
	var a: Vector3 = cam.global_position
	for q: Vector3 in [pts[0], pts[0].lerp(pts[1], 0.5)]:
		var t: float = clampf((q - a).dot(subject_head - a) / maxf((subject_head - a).length_squared(), 1e-6), 0.0, 1.0)
		if (a + (subject_head - a) * t).distance_to(q) < 0.22:
			return false
	return true


func _part_s() -> void:
	print("  S: cinematic shot helpers")
	var lb: float = _letterbox_frac()
	var stage := Node3D.new()
	stage.name = "ShotStage"
	arena.add_child(stage)
	stage.global_position = Vector3(400.0, 0.0, -400.0)
	var a: Node3D = CharacterBuilder.build({"preset": "player", "seed": 3, "rigged": true, "name": "ActorA"})
	var b: Node3D = CharacterBuilder.build({"preset": "rider", "seed": 4, "rigged": true, "name": "ActorB"})
	stage.add_child(a)
	stage.add_child(b)
	var cam := Camera3D.new()
	cam.name = "ShotCam"
	arena.add_child(cam)
	cam.make_current()
	var ctx: Dictionary = {"actors": {"a": a, "b": b}}
	var shots: Array = [
		["two_shot", {"a": "a", "b": "b"}, ["a", "b"]],
		["two_shot", {"a": "a", "b": "b", "side": -1.0, "push": 0.2}, ["a", "b"]],
		["ots", {"over": "a", "at": "b"}, ["b"]],
		["ots", {"over": "b", "at": "a", "side": -1.0}, ["a"]],
		["low_hero", {"actor": "a", "fov": 50.0}, ["a"]],
		["low_hero", {"actor": "b", "side_deg": -30.0, "fov": 50.0}, ["b"]],
		["dutch", {"actor": "b"}, ["b"]],
		["dutch", {"actor": "a", "roll": -14.0, "side_deg": -25.0}, ["a"]],
		["push_in", {"actor": "a"}, ["a"]],
		["push_in", {"actor": "b", "side_deg": 20.0, "to": 2.0}, ["b"]],
	]
	var total: int = 0
	var ok: int = 0
	var fails_s: Array[String] = []
	for sep: float in [1.2, 2.5, 4.0]:
		a.position = Vector3(-sep * 0.5, 0.0, 0.0)
		a.rotation.y = deg_to_rad(-90.0)     # faces +X (characters face -Z at yaw 0)
		b.position = Vector3(sep * 0.5, 0.0, 0.0)
		b.rotation.y = deg_to_rad(90.0)
		await _frames(3)
		for sh: Array in shots:
			var shot: Dictionary = {"id": "T", "s": 0.0, "rig": sh[0], "what": "", "params": sh[1]}
			for u: float in [0.0, 0.5, 1.0]:
				_apply_shot(cam, stage.global_transform, CineShots.eval(shot, u, ctx))
				var good: bool = true
				for id: String in sh[2]:
					var n: Node3D = (ctx["actors"] as Dictionary)[id]
					var pts: PackedVector3Array = CameraFraming.subject_points(n)
					var rep: Dictionary = CameraFraming.report(cam, pts, _space(), [], CameraRules.SAFE_MARGIN, lb)
					if not bool(rep["ok"]):
						good = false
						fails_s.append("%s %s sep %.1f u %.1f: %s %s" % [sh[0], str(sh[1]), sep, u, id, CameraFraming.describe(cam, pts, rep)])
				if String(sh[0]) == "ots":
					var fg: Node3D = (ctx["actors"] as Dictionary)[String((sh[1] as Dictionary)["over"])]
					var subj: Node3D = (ctx["actors"] as Dictionary)[String((sh[1] as Dictionary)["at"])]
					if not _clear_of(cam, CameraFraming.subject_points(subj)[0], fg):
						good = false
						fails_s.append("ots %s sep %.1f u %.1f: the foreground head hides the subject's face" % [str(sh[1]), sep, u])
				if String(sh[0]) == "dutch":
					var want: float = float((sh[1] as Dictionary).get("roll", 14.0))
					var got: float = rad_to_deg(asin(clampf(cam.global_basis.x.y, -1.0, 1.0)))
					if absf(got) < absf(want) * 0.8 or signf(got) != signf(want):
						good = false
						fails_s.append("dutch roll %.1f, want ~%.1f" % [got, want])
				total += 1
				if good:
					ok += 1
	for f: String in fails_s.slice(0, 8):
		print("    ", f)
	_check(ok == total, "every shot helper frames its subjects inside the letterboxed safe area, OTS keeps the face clear, dutch rolls (%d / %d)" % [ok, total])
	cam.queue_free()
	stage.queue_free()
	# timelines: the helpers validate, an unknown actor is refused, CinePlayer plays them (roll applied, subjects framed)
	var tl: CineTimeline = (load("res://tests/support/cine_test_timeline.gd") as GDScript).new()
	tl.build()
	tl.shots.clear()
	tl.two_shot("S1", 0.0, "hero", "dummy")
	tl.dutch_shot("S2", 1.4, "dummy", {"roll": 14.0})
	tl.ots_shot("S3", 2.6, "hero", "dummy")
	tl.push_in("S4", 3.6, "dummy")
	tl.hero_shot("S5", 4.6, "hero")
	var errs: PackedStringArray = tl.validate()
	_check(errs.is_empty(), "a timeline of shot helpers validates (%s)" % str(errs))
	var bad: CineTimeline = (load("res://tests/support/cine_test_timeline.gd") as GDScript).new()
	bad.build()
	bad.shots.clear()
	bad.two_shot("S1", 0.0, "hero", "nobody")
	_check(not bad.validate().is_empty(), "a shot helper naming an unknown actor is refused")
	var cp := CinePlayer.new()
	cp.name = "ShotPlayer"
	arena.add_child(cp)
	var se: PackedStringArray = cp.setup(tl, Transform3D(Basis.IDENTITY, Vector3(400.0, 0.0, -380.0)), {"manual": true, "music": false})
	_check(se.is_empty(), "CinePlayer sets up the helper timeline (%s)" % str(se))
	cp.start()
	var subj: Dictionary = {"S1": ["hero", "dummy"], "S2": ["dummy"], "S3": ["dummy"], "S4": ["dummy"], "S5": ["hero"]}
	var seen: Dictionary = {}
	var cp_ok: int = 0
	var cp_n: int = 0
	var rolled: bool = false
	for i: int in 330:
		cp.step(1.0 / 60.0)
		if i < 30 or i % 6 != 0 or not subj.has(cp.current_shot):
			continue
		await process_frame
		seen[cp.current_shot] = true
		var good2: bool = true
		for id: String in subj[cp.current_shot]:
			var an: Node3D = cp.actors[id]
			var pts2: PackedVector3Array = CameraFraming.subject_points(an)
			var rep2: Dictionary = CameraFraming.report(cp.camera, pts2, _space(), [], CameraRules.SAFE_MARGIN, lb)
			if not bool(rep2["ok"]):
				good2 = false
				print("    cine %s r %.2f %s: %s" % [cp.current_shot, cp.r, id, CameraFraming.describe(cp.camera, pts2, rep2)])
		if cp.current_shot == "S2" and absf(cp.camera.global_basis.x.y) > sin(deg_to_rad(10.0)):
			rolled = true
		cp_n += 1
		if good2:
			cp_ok += 1
	_check(seen.size() == 5, "CinePlayer reached every helper shot (%s)" % str(seen.keys()))
	_check(rolled, "CinePlayer applies the dutch roll")
	_check(cp_ok == cp_n, "CinePlayer: the helper shots frame their subjects while the actors move (%d / %d)" % [cp_ok, cp_n])
	cp.queue_free()
	await _frames(2)
