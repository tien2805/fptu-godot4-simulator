# File: res://scripts/story/missions/MissionTowerLasers.gd
# Day 7 floor 5, the laser corridor into the vase gallery (plan 2026-11-01-w4-day7.md T1 / T3): on foot, unarmed, from
# the lift (points.start) to the gallery door (points.goal) through LairTower.laser_defs(): static half-width beams in a
# zigzag, blinking walls, sweeping vertical beams, a diagonal. Every beam is a thin glowing red bar (code-built); a blink
# wall flickers dim for TELE_S before it lights (and buzzes when the player is near: the telegraph), a sweeping beam is
# always lit. Touching a lit beam (BEAM_HZ checks: the player's xz distance to the beam under PLAYER_R and the beam's
# height inside the player's body) = "BỊ LỘ" with the alarm; THỬ LẠI = back at the lift, the beams' clock from zero.
# The goal: the beat's replay (seg_d7_floors: a short replay of the run, StoryStage) then done {"time"}.
# T3, the sweeps' telegraph: every sweeping beam has a dim GHOST beam (harmless, the warn colour) running TELE_S ahead of
# it (ghost_point(def, t) = beam_point(def, t + TELE_S)): any spot the lit beam reaches was marked TELE_S before; and a dim
# floor rail along its whole path. So every lethal beam is telegraphed >= TELE_S (0.6 s): a blink by its dim warn phase,
# a sweep by its ghost, a static one by simply being there.
# Static helpers (tests): beam_state(def, t) -> "on" | "warn" | "off", beam_point(def, t), ghost_point(def, t),
# beam_hits(def, t, p).
# w5-day7 T1, the readability cuts (D7Beat, once per attempt): points.laser_cuts [[trigger (world z the player passes;
# INF = at the start), target (world point on the corridor floor)]]: a preview cut on the beams ahead (the first blink wall
# at the start, the sweeps once past it), each from a spot with room to stop; under the 3.2 m ceiling: CUT_OPTS.
# points: start (+ start_yaw), goal, goal_r, lasers, laser_cuts, centre, leash.
class_name MissionTowerLasers
extends StoryMission

const BEAM_HZ: float = 20.0
const PLAYER_R: float = 0.32
const PLAYER_H: float = 1.72
const FOOT_Y: float = 0.05
const TELE_S: float = 0.6
const BUZZ_M: float = 10.0
const BEAM_W: float = 0.03
const T_TRIPPED: String = "Chạm tia laser! Báo động rồi!"
const T_INFO: String = "Hành lang laser: tia nháy là sắp bật"
const T_PROMPT: String = "Tới cửa phòng bình cổ"
const T_RAN: String = "Bỏ chạy khỏi hành lang rồi!"
const RED := Color("#FF2A3A")
const CUT_OPTS: Dictionary = {"up": 0.75, "dist": 6.0}

var pts: Dictionary = {}
var defs: Array = []
var beams: Array[Node3D] = []
## Per beam: its ghost pivot (sweeps; null for the others) and its floor rail (sweeps).
var ghosts: Array[Node3D] = []
var rails: Array[MeshInstance3D] = []
var t: float = 0.0
var trips: int = 0
var buzzes: int = 0
var rec: CineReplayRecorder = null
var replay_wait: float = -1.0
var guide: BasementGuide = null
var beat_fx: D7Beat = null
## The cut targets (markers on the corridor floor) and the cuts done this attempt.
var cut_marks: Array[Node3D] = []
var cut_done: Array[bool] = []
## Each cut's trigger (world z, from points.laser_cuts at the start) and how many are still to come this attempt.
var cut_z: PackedFloat32Array = PackedFloat32Array()
var _cuts_left: int = 0
var _acc: float = 0.0
var _buzz_cd: float = 0.0                 # one buzz for a whole blinking wall
var _warned: PackedInt32Array = PackedInt32Array()   # per beam: the blink cycle whose telegraph buzzed
var _mat_on: StandardMaterial3D
var _mat_warn: StandardMaterial3D


func setup(r: Node3D, b: Dictionary, o: Dictionary = {}) -> void:
	super.setup(r, b, o)
	pts = opts.get("points", {})
	defs = pts.get("lasers", [])


# ---------------------------------------------------------------------------
# Beam rules (static: the unit tests read them)
# ---------------------------------------------------------------------------
## "on" (lit, lethal) | "warn" (the TELE_S before a blink lights: dim, harmless) | "off".
static func beam_state(d: Dictionary, at_t: float) -> String:
	var mode: String = String(d.get("mode", "static"))
	if mode != "blink":
		return "on"
	var period: float = maxf(0.2, float(d.get("period", 3.0)))
	var u: float = fposmod(at_t + float(d.get("phase", 0.0)), period)
	if u < period * float(d.get("on", 0.5)):
		return "on"
	return "warn" if u >= period - TELE_S else "off"


## The beam's anchor now: a sweep moves along its "sweep" offset (sine), the others stay at "a".
static func beam_point(d: Dictionary, at_t: float) -> Vector3:
	var a: Vector3 = d["a"]
	if String(d.get("mode", "")) != "sweep":
		return a
	var period: float = maxf(0.2, float(d.get("period", 3.0)))
	return a + (d.get("sweep", Vector3.ZERO) as Vector3) * sin(TAU * (at_t + float(d.get("phase", 0.0))) / period)


## Where a sweep's ghost is now: where the lit beam will be TELE_S later (the others: their beam).
static func ghost_point(d: Dictionary, at_t: float) -> Vector3:
	return beam_point(d, at_t + TELE_S)


## A lit beam through the player standing at p (feet).
static func beam_hits(d: Dictionary, at_t: float, p: Vector3, r: float = PLAYER_R, h: float = PLAYER_H) -> bool:
	if beam_state(d, at_t) != "on":
		return false
	var a: Vector3 = beam_point(d, at_t)
	var b: Vector3 = (d["b"] as Vector3) + (a - (d["a"] as Vector3))
	var y0: float = float(d.get("y0", 0.5))
	var y1: float = float(d.get("y1", y0))
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	var p2 := Vector2(p.x, p.z)
	var ab: Vector2 = b2 - a2
	var s: float = 0.0 if ab.length_squared() < 0.0001 else clampf((p2 - a2).dot(ab) / ab.length_squared(), 0.0, 1.0)
	if p2.distance_to(a2 + ab * s) > r:
		return false
	var lo: float = p.y + FOOT_Y
	var hi: float = p.y + h
	if ab.length_squared() < 0.0001:            # a vertical beam: y0..y1 over the floor
		return a.y + maxf(y0, y1) >= lo and a.y + minf(y0, y1) <= hi
	var y: float = a.y + lerpf(y0, y1, s)
	return y >= lo and y <= hi


# ---------------------------------------------------------------------------
func _start() -> void:
	_mat_on = CineFX._glow_mat(RED, 4.0)
	_mat_warn = CineFX._glow_mat(RED.darkened(0.45), 1.2)
	_build_beams()
	if pts.has("goal"):
		var g := Node3D.new()
		g.name = "Goal"
		add_child(g)
		g.global_position = pts["goal"]
	guide = BasementGuide.new()
	add_child(guide)
	guide.setup(self)
	if pts.has("goal"):
		guide.set_goal(pts["goal"], "Phòng bình cổ")
	beat_fx = D7Beat.new()
	add_child(beat_fx)
	for c: Array in pts.get("laser_cuts", []):
		var mk := Node3D.new()
		mk.name = "CutMark"
		mk.top_level = true
		add_child(mk)
		mk.global_position = c[1]
		cut_marks.append(mk)
		cut_z.append(float(c[0]))
	_fresh()


func _fresh() -> void:
	t = 0.0
	_acc = 0.0
	_warned.resize(defs.size())
	_warned.fill(-1)
	replay_wait = -1.0
	cut_done.resize(cut_marks.size())
	cut_done.fill(false)
	_cuts_left = cut_marks.size()
	if pts.has("start"):
		teleport_player(pts["start"], float(pts.get("start_yaw", 0.0)))
	set_info(T_INFO)
	set_prompt(T_PROMPT)
	if rec and is_instance_valid(rec):
		rec.queue_free()
	rec = StoryStage.make_recorder(self, [player]) if String(beat.get("replay", "")) != "" else null
	_update_beams()


func _build_beams() -> void:
	var root := Node3D.new()
	root.name = "Lasers"
	root.top_level = true
	add_child(root)
	for d: Dictionary in defs:
		var pivot: Node3D = _beam_pivot(root, d, _mat_on, "Beam")
		beams.append(pivot)
		if String(d.get("mode", "")) == "sweep":
			ghosts.append(_beam_pivot(root, d, _mat_warn, "Ghost"))
			var sw: Vector3 = d.get("sweep", Vector3.ZERO)
			var a: Vector3 = d["a"]
			var rail := MeshInstance3D.new()
			rail.name = "Rail"
			var rm := BoxMesh.new()
			rm.size = Vector3(maxf(0.04, absf(sw.x) * 2.0), 0.012, maxf(0.04, absf(sw.z) * 2.0))
			rail.mesh = rm
			rail.material_override = _mat_warn
			rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(rail)
			rail.global_position = a + Vector3(0.0, 0.02, 0.0)
			rails.append(rail)
		else:
			ghosts.append(null)


## One beam's pivot (at its anchor "a") with its glowing bar.
func _beam_pivot(root: Node3D, d: Dictionary, mat: Material, nm: String) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = nm
	root.add_child(pivot)
	var mi := MeshInstance3D.new()
	mi.name = "Bar"
	var bm := BoxMesh.new()
	var a: Vector3 = d["a"]
	var b: Vector3 = d["b"]
	var y0: float = float(d.get("y0", 0.5))
	var y1: float = float(d.get("y1", y0))
	var vertical: bool = Vector2(b.x - a.x, b.z - a.z).length() < 0.01
	if vertical:
		bm.size = Vector3(BEAM_W, absf(y1 - y0), BEAM_W)
		mi.position = Vector3(0.0, (y0 + y1) * 0.5, 0.0)
	else:
		var from := a + Vector3(0.0, y0, 0.0)
		var to := b + Vector3(0.0, y1, 0.0)
		bm.size = Vector3(BEAM_W, BEAM_W, from.distance_to(to))
		mi.basis = Basis.looking_at(to - from, Vector3.UP) if absf((to - from).normalized().y) < 0.99 else Basis.IDENTITY
		mi.position = (from + to) * 0.5 - a
	mi.mesh = bm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(mi)
	pivot.global_position = a
	return pivot


## Positions (sweeps), visibility and colour (blinks) of the beams at the mission's t.
func _update_beams() -> void:
	for i: int in mini(beams.size(), defs.size()):
		var d: Dictionary = defs[i]
		var st: String = beam_state(d, t)
		var pv: Node3D = beams[i]
		pv.visible = st != "off"
		if String(d.get("mode", "")) == "sweep":
			pv.global_position = beam_point(d, t)
			if i < ghosts.size() and ghosts[i] != null:
				ghosts[i].global_position = ghost_point(d, t)
		if String(d.get("mode", "")) == "blink":
			var mi: MeshInstance3D = pv.get_child(0) as MeshInstance3D
			var want: Material = _mat_on if st == "on" else _mat_warn
			if mi.material_override != want:
				mi.material_override = want
			if st == "warn" and player:
				var cyc: int = int(floor((t + float(d.get("phase", 0.0))) / maxf(0.2, float(d.get("period", 3.0)))))
				if _warned[i] != cyc and flat(player.global_position, d["a"]) < BUZZ_M:
					_warned[i] = cyc
					if _buzz_cd > 0.0:
						continue
					_buzz_cd = TELE_S
					buzzes += 1
					play_cue("fluoro_buzz", -8.0)


func _tick(dt: float) -> void:
	if replay_wait >= 0.0:
		replay_wait -= dt
		if replay_wait < 0.0:
			play_short_replay(rec, String(beat.get("replay", "")), player, null, func() -> void: finish({"trips": trips}))
		return
	t += dt
	_buzz_cd -= dt
	_update_beams()
	_cuts()
	_acc += dt
	if _acc < 1.0 / BEAM_HZ or player == null:
		return
	_acc = 0.0
	var p: Vector3 = player.global_position
	for d: Dictionary in defs:
		if beam_hits(d, t, p):
			trip()
			return
	if pts.has("centre") and flat(p, pts["centre"]) > float(pts.get("leash", 70.0)):
		fail(T_RAN)
		return
	if pts.has("goal") and flat(p, pts["goal"]) <= float(pts.get("goal_r", 2.0)):
		_reach_goal()


## The next cut whose trigger the player passed (one at a time; a running cut waits).
func _cuts() -> void:
	if _cuts_left <= 0 or player == null or beat_fx == null:
		return
	for i: int in mini(cut_z.size(), cut_done.size()):
		if cut_done[i] or player.global_position.z > cut_z[i]:
			continue
		if beat_fx.cut(cut_marks[i], CUT_OPTS) or CameraDirector.live() == null:
			cut_done[i] = true
			_cuts_left -= 1
		return


## A lit beam touched: the alarm, "BỊ LỘ".
func trip() -> void:
	if state != "running":
		return
	trips += 1
	play_cue("alarm_siren", -6.0)
	popup(T_TRIPPED, 1.6, WARN)
	fail(T_TRIPPED, T_LO)


func _reach_goal() -> void:
	set_prompt("")
	if rec and is_instance_valid(rec) and String(beat.get("replay", "")) != "":
		rec.mark("blow")
		replay_wait = StoryStage.REPLAY_AFTER
	else:
		finish({"trips": trips})


func _reset() -> void:
	_fresh()


func _cleanup() -> void:
	if rec and is_instance_valid(rec):
		rec.queue_free()
	rec = null
