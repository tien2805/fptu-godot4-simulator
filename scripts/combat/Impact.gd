# File: res://scripts/combat/Impact.gd
# Q2 shared impact recipe (spec 2026-10-29 Q2 / quality bar item 4): every hit in melee, bike, gun and sword combat goes
# through Impact.hit(ctx, tier, opts) with one of three tiers:
#   tier      hit-stop  camera punch  target reaction (the caller's)        particles                 sound layers
#   light     40 ms     0.15          directional flinch                    dust                      whoosh + thud
#   heavy     80 ms     0.35          stagger + 1.5 m knockback             dust ring + sparks        + body + crowd "ồ"
#   finisher  150 ms    0.6           comic flying tumble, bounce, stars    ring, sparks, debris      + meme sting
# A last-enemy knockout adds a 0.5 s slow-motion orbit (slowmo_orbit).
#
# ===== API =====
#   Impact.hit(ctx: Node, tier: String, opts := {}) -> Dictionary
#       ctx: any node in the tree (finds the clock, the camera director, the fx pool). opts (all optional):
#       "pos" (Vector3, the impact point), "dir" (Vector3, attacker -> target), "target" (Node3D: impact_react(tier, dir,
#       opts) is called when it has it), "fx" (WeaponFX: the particle fallback), "shake_fn" (Callable(strength): camera
#       fallback, e.g. PlayerBike.add_camera_shake), "last" (bool: last enemy -> slow-motion orbit on "target"),
#       "orbit_target" (the orbit's subject when it is not "target"), "hitstop_k" / "punch_k" / "fx_k" (scales), "no_hitstop", "no_punch", "no_fx", "no_sound", "cues" (extra
#       [[cue, db], ...] played with the layers).
#       Returns {"tier", "hitstop" (s actually added), "punch", "fx" (kinds), "cues" (played), "react"}.
#   Impact.clock(ctx) -> Impact            the one clock node (group "impact_clock", built on first use under the root)
#   clock.hitstop(secs, light := false) -> float     freeze (time scale HITSTOP_SCALE) for round(secs * ticks) physics frames
#   clock.slowmo(scale, secs, by := null) -> bool    combat slow motion (queued after a running hit-stop)
#   clock.end_slowmo(by := null), clock.slowmo_active(by := null), clock.hitstop_active()
#   Impact.punch(ctx, strength, dir, shake_fn := Callable())   camera director punch, else shake_fn, else GameFX.shake
#   Impact.shake(ctx, trauma, shake_fn := Callable())
#   Impact.particles(ctx, kind, pos, dir := UP, scale := 1.0, fx := null)   fx_pool.spawn, else WeaponFX bursts
#   Impact.sound(ctx, cue, pos, db := 0.0)                                   one cue through the clock's pool
#   Impact.edge_flash(ctx, color := red, strength := 0.65, secs := 0.35)    red screen-edge flash (hits on the player)
#   Impact.slowmo_orbit(ctx, target, secs := ORBIT_S)                        last-enemy slow motion + director orbit
#   Impact.yield_scale()                   a set piece takes the time scale: a running hit-stop / slow motion ends
#   Impact.knock(tier) -> float            the tier's knockback distance (m)
# ===============
# Time: "real" seconds are physics frames (1 / physics_ticks_per_second), so tests count frames and a hit-stop never
# depends on the render rate. Engine.time_scale is written only through RadialWheel.scale_owner: a hit-stop is skipped
# while anyone else owns the time scale (the weapon wheel, a chase slow motion) or while this clock's own slow motion runs;
# a wheel or BikeChase.slow_motion (through yield_scale) simply takes over. Light hit-stops never add up to more than
# LIGHT_CAP within LIGHT_WINDOW (no stutter lock from fast small hits); hits in one frame take the longest freeze, never
# the sum. A pause of the tree ends every hit-stop and slow motion at once (a cinematic right after a hit).
# Camera and particles go through the Q1 / Q3 nodes (groups "camera_director", "fx_pool") behind has_method guards.
# Sound: synthesized layers (ImpactAudio, plus WeaponAudio / SwordAudio / CineAudio cues by name); the crowd "ồ" at most
# every CROWD_GAP, the sting every STING_GAP, one copy of a cue per frame. No autoload is referenced by name.
class_name Impact
extends Node

const GROUP: String = "impact_clock"
const TIERS: Dictionary = {
	"light": {"hitstop": 0.04, "punch": 0.15, "knock": 0.3,
		"fx": [["dust", 0.6]],
		"cues": [["whoosh_hit", -11.0], ["thud", -4.0]]},
	"heavy": {"hitstop": 0.08, "punch": 0.35, "knock": 1.5,
		"fx": [["dust_ring", 1.0], ["sparks", 0.8]],
		"cues": [["whoosh_hit", -9.0], ["thud", 0.0], ["body", -3.0], ["crowd_oh", -10.0]]},
	"finisher": {"hitstop": 0.15, "punch": 0.6, "knock": 3.0,
		"fx": [["dust_ring", 1.6], ["sparks", 1.3], ["debris", 1.0]],
		"cues": [["whoosh_hit", -8.0], ["thud", 2.0], ["body", 0.0], ["crowd_oh", -7.0], ["sting", -5.0]]},
}
const HITSTOP_SCALE: float = 0.05
const LIGHT_CAP: float = 0.06            # s of light hit-stop at most ...
const LIGHT_WINDOW: float = 0.2          # ... within any window this long
const ORBIT_S: float = 0.5
const ORBIT_SCALE: float = 0.3
const CROWD_GAP: float = 1.2
const STING_GAP: float = 1.0
const EDGE_RED := Color(1.0, 0.1, 0.06)
const UNPOSITIONED: Array[String] = ["crowd_oh", "sting", "hit_tick", "ko_tick"]
## Slam surfaces (surface_of) and their sound.
const SLAM_CUE: Dictionary = {"wall": "slam", "car": "metal_slam", "table": "wood_break", "enemy": "body"}
const LOG_MAX: int = 32
const EDGE_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0, 0.1, 0.06, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 uv = abs(UV - vec2(0.5)) * 2.0;
	float d = max(uv.x * 0.92, uv.y);
	float a = smoothstep(0.66, 1.0, d) * strength;
	COLOR = vec4(tint.rgb, a);
}
"""

## Real seconds counted by this clock (physics frames / ticks).
var rt: float = 0.0
# Frames are Engine.get_physics_frames() indices. A freeze claimed during frame F runs slow on frames F+1 .. _hs_end
# (frame F's delta is already computed) and the clock releases it in its tick of frame _hs_end; same for slow motion.
var _hs_end: int = -1
var _light_frames := PackedInt32Array()  # frame indices of the light freeze frames granted (for the cap)
var _slow_end: int = -1                  # last slow-motion frame (-1: none running)
var _slow_frames: int = 0                # length of a slow motion queued after the freeze (0: none)
var _slow_scale: float = 1.0
var _slow_by: Object = null
# sound
var _sfx3: Array[AudioStreamPlayer3D] = []
var _sfx2: Array[AudioStreamPlayer] = []
var _i3: int = 0
var _i2: int = 0
var _cue_frame: Dictionary = {}          # cue -> frame it last played
var _cue_rt: Dictionary = {}             # cue -> rt it last played (gaps)
# edge flash
var _edge_layer: CanvasLayer = null
var _edge_mat: ShaderMaterial = null
var _edge_s: float = 0.0
var _edge_decay: float = 2.0
var _fx_own: WeaponFX = null
## Telemetry (tests): hit-stops {"frame", "frames", "tier"}, counters, the last kinds / cues / punches.
var hitstops: Array[Dictionary] = []
var hitstop_count: int = 0
var skipped: int = 0
var light_capped: int = 0
var slow_count: int = 0
var orbit_count: int = 0
var punches: Array[float] = []
var fx_log: Array[String] = []
var cue_log: Array[String] = []
var edge_flashes: int = 0
var hits: int = 0
var last_hit: Dictionary = {}


func _ready() -> void:
	add_to_group(GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -100          # first in the frame: a freeze ends before the others read the time scale
	ImpactAudio.warm()
	var bus: StringName = WeaponAudio.bus()
	for i: int in 6:
		var p := AudioStreamPlayer3D.new()
		p.name = "ImpactSfx3D%d" % i
		p.bus = bus
		p.max_distance = 90.0
		p.unit_size = 7.0
		add_child(p)
		_sfx3.append(p)
	for j: int in 3:
		var q := AudioStreamPlayer.new()
		q.name = "ImpactSfx%d" % j
		q.bus = bus
		add_child(q)
		_sfx2.append(q)


func _exit_tree() -> void:
	_hs_end = -1
	_slow_end = -1
	_slow_frames = 0
	_release()


# ---------------------------------------------------------------------------
# STATIC ENTRY POINTS
# ---------------------------------------------------------------------------
## The clock of ctx's tree (built under the root on first use). null when ctx is not in a tree.
static func clock(ctx: Node) -> Impact:
	if ctx == null or not is_instance_valid(ctx) or not ctx.is_inside_tree():
		return null
	var tree: SceneTree = ctx.get_tree()
	var c: Node = tree.get_first_node_in_group(GROUP)
	if c != null and not c.is_queued_for_deletion():
		return c as Impact
	var n := Impact.new()
	n.name = "ImpactClock"
	tree.root.add_child(n)
	return n


## The clock if one exists (no build).
static func find_clock(ctx: Node) -> Impact:
	if ctx == null or not is_instance_valid(ctx) or not ctx.is_inside_tree():
		return null
	return ctx.get_tree().get_first_node_in_group(GROUP) as Impact


static func tier_of(tier: String) -> Dictionary:
	return TIERS.get(tier, TIERS["light"])


static func knock(tier: String) -> float:
	return float(tier_of(tier)["knock"])


## What a body was slammed into: "table" (group slam_table), "car" (group slam_car, traffic_obstacle or a VehicleBody3D),
## a node's meta "slam" (any of SLAM_CUE), else "wall".
static func surface_of(col: Object) -> String:
	if col == null or not is_instance_valid(col) or not (col is Node):
		return "wall"
	var n: Node = col
	for k: int in 3:                         # the collider or one of its two parents (a prop root holding its body)
		if n == null:
			break
		if n.has_meta("slam") and SLAM_CUE.has(String(n.get_meta("slam"))):
			return String(n.get_meta("slam"))
		if n.is_in_group("slam_table"):
			return "table"
		if n.is_in_group("slam_car") or n.is_in_group("traffic_obstacle") or n is VehicleBody3D:
			return "car"
		n = n.get_parent()
	return "wall"


## The impact recipe (see the header).
static func hit(ctx: Node, tier: String, opts: Dictionary = {}) -> Dictionary:
	var td: Dictionary = tier_of(tier)
	var pos: Vector3 = opts.get("pos", (ctx as Node3D).global_position if ctx is Node3D and (ctx as Node3D).is_inside_tree() else Vector3.ZERO)
	var dir: Vector3 = opts.get("dir", Vector3.FORWARD)
	var out: Dictionary = {"tier": tier, "hitstop": 0.0, "punch": 0.0, "fx": [], "cues": [], "react": ""}
	var c: Impact = clock(ctx)
	if c != null:
		c.hits += 1
	if c != null and not bool(opts.get("no_hitstop", false)):
		out["hitstop"] = c.hitstop(float(td["hitstop"]) * float(opts.get("hitstop_k", 1.0)), tier == "light", tier)
	if not bool(opts.get("no_punch", false)):
		var s: float = float(td["punch"]) * float(opts.get("punch_k", 1.0))
		punch(ctx, s, dir, opts.get("shake_fn", Callable()))
		out["punch"] = s
	if not bool(opts.get("no_fx", false)):
		var k: float = float(opts.get("fx_k", 1.0))
		var fx: WeaponFX = opts.get("fx", null)
		for e: Array in td["fx"]:
			particles(ctx, String(e[0]), pos, dir, float(e[1]) * k, fx)
			(out["fx"] as Array).append(String(e[0]))
	if c != null and not bool(opts.get("no_sound", false)):
		for e2: Array in td["cues"]:
			if c.play(String(e2[0]), pos, float(e2[1])):
				(out["cues"] as Array).append(String(e2[0]))
		for e3: Variant in opts.get("cues", []):
			var ea: Array = e3
			if c.play(String(ea[0]), pos, float(ea[1]) if ea.size() > 1 else 0.0):
				(out["cues"] as Array).append(String(ea[0]))
	var t: Variant = opts.get("target", null)
	if t != null and is_instance_valid(t) and (t as Object).has_method("impact_react"):
		out["react"] = String((t as Object).call("impact_react", tier, dir, opts))
	var ot: Variant = opts.get("orbit_target", t)
	if bool(opts.get("last", false)) and ot != null and is_instance_valid(ot):
		slowmo_orbit(ctx, ot as Node3D, ORBIT_S)
	if c != null:
		c.last_hit = out
	return out


## Camera punch: the Q1 director's punch(strength, dir), else shake_fn(strength), else GameFX.shake(strength).
static func punch(ctx: Node, strength: float, dir: Vector3 = Vector3.ZERO, shake_fn: Callable = Callable()) -> void:
	if ctx == null or not is_instance_valid(ctx) or not ctx.is_inside_tree():
		return
	var c: Impact = find_clock(ctx)
	if c != null:
		c.punches.append(strength)
		if c.punches.size() > LOG_MAX:
			c.punches.pop_front()
	var d: Node = ctx.get_tree().get_first_node_in_group("camera_director")
	if d != null and d.has_method("punch"):
		d.call("punch", strength, dir)
		return
	if shake_fn.is_valid():
		shake_fn.call(strength)
		return
	var g: Node = ctx.get_node_or_null("/root/GameFX")
	if g != null and g.has_method("shake"):
		g.call("shake", strength)


## Camera trauma: the Q1 director's shake(trauma), else shake_fn, else GameFX.shake.
static func shake(ctx: Node, trauma: float, shake_fn: Callable = Callable()) -> void:
	if ctx == null or not is_instance_valid(ctx) or not ctx.is_inside_tree():
		return
	var d: Node = ctx.get_tree().get_first_node_in_group("camera_director")
	if d != null and d.has_method("shake"):
		d.call("shake", trauma)
		return
	if shake_fn.is_valid():
		shake_fn.call(trauma)
		return
	var g: Node = ctx.get_node_or_null("/root/GameFX")
	if g != null and g.has_method("shake"):
		g.call("shake", trauma)


## One particle effect: the Q3 pool's spawn(kind, pos, dir, scale), else WeaponFX bursts (fx, else the clock's own).
static func particles(ctx: Node, kind: String, pos: Vector3, dir: Vector3 = Vector3.UP, scale: float = 1.0, fx: WeaponFX = null) -> void:
	if ctx == null or not is_instance_valid(ctx) or not ctx.is_inside_tree():
		return
	var c: Impact = find_clock(ctx)
	if c != null:
		c.fx_log.append(kind)
		if c.fx_log.size() > LOG_MAX:
			c.fx_log.pop_front()
	var pool: Node = ctx.get_tree().get_first_node_in_group("fx_pool")
	if pool != null and pool.has_method("spawn"):
		pool.call("spawn", kind, pos, dir, scale)
		return
	if fx == null or not is_instance_valid(fx) or not fx.is_inside_tree():
		fx = c.own_fx() if c != null else null
	if fx == null:
		return
	var d: Vector3 = dir if dir.length_squared() > 1e-6 else Vector3.UP
	match kind:
		"sparks":
			fx.burst("sparks", pos, d, 0.32 * scale)
		"dust_ring":
			fx.burst("dust", pos, Vector3.UP, 0.42 * scale)
		"debris":
			fx.burst("dust", pos, Vector3.UP, 0.35 * scale)
			fx.burst("flash", pos, d, 0.25 * scale)
		"smoke", "dust", "splash":
			fx.burst("dust", pos, Vector3.UP, 0.3 * scale)
		_:
			fx.burst("dust", pos, Vector3.UP, 0.25 * scale)


## One cue through the clock's pool (dedupe and gaps apply). false when it was not played.
static func sound(ctx: Node, cue: String, pos: Vector3, db: float = 0.0) -> bool:
	var c: Impact = clock(ctx)
	return c.play(cue, pos, db) if c != null else false


static func edge_flash(ctx: Node, color: Color = EDGE_RED, strength: float = 0.65, secs: float = 0.35) -> void:
	var c: Impact = clock(ctx)
	if c != null:
		c.flash_edge(color, strength, secs)


## Last-enemy slow motion (ORBIT_SCALE for secs real, after any running hit-stop) and the director's orbit move.
static func slowmo_orbit(ctx: Node, target: Node3D, secs: float = ORBIT_S) -> bool:
	var c: Impact = clock(ctx)
	if c == null:
		return false
	var ok: bool = c.slowmo(ORBIT_SCALE, secs, c)
	if ok:
		c.orbit_count += 1
	var d: Node = ctx.get_tree().get_first_node_in_group("camera_director")
	if d != null and d.has_method("slowmo_orbit") and target != null and is_instance_valid(target):
		d.call("slowmo_orbit", target, secs)
	return ok


## A set piece (BikeChase.slow_motion) takes the time scale: a clock's running hit-stop / slow motion ends without a write.
static func yield_scale() -> void:
	var o: Object = RadialWheel.scale_owner
	if o != null and is_instance_valid(o) and o is Impact:
		(o as Impact)._drop_all()


# ---------------------------------------------------------------------------
# CLOCK
# ---------------------------------------------------------------------------
static func _ticks() -> int:
	return maxi(1, Engine.physics_ticks_per_second)


static func _foreign_owner(me: Object) -> bool:
	var o: Object = RadialWheel.scale_owner
	return o != null and o != me and is_instance_valid(o)


## Freeze for round(secs * ticks) physics frames (at least one). Skipped (0) while another node owns the time scale or this
## clock's slow motion runs; light hits are capped (LIGHT_CAP per LIGHT_WINDOW). Returns the seconds of freeze added.
func hitstop(secs: float, light: bool = false, tier: String = "") -> float:
	if secs <= 0.0:
		return 0.0
	if _foreign_owner(self) or slowmo_running() or (is_inside_tree() and get_tree().paused):
		skipped += 1
		return 0.0
	var pf: int = Engine.get_physics_frames()
	var want_end: int = pf + maxi(1, roundi(secs * float(_ticks())))
	var cur_end: int = _hs_end if _hs_end >= pf else pf
	var add: int = want_end - cur_end
	if add <= 0:
		return 0.0                           # covered by the freeze already running (same-frame hits: the longest wins)
	if light:
		add = _light_allowance(cur_end + 1, add)
		if add <= 0:
			skipped += 1
			light_capped += 1
			return 0.0
		for k: int in add:
			_light_frames.append(cur_end + 1 + k)
	_hs_end = cur_end + add
	RadialWheel.scale_owner = self
	Engine.time_scale = HITSTOP_SCALE
	hitstop_count += 1
	hitstops.append({"frame": pf, "frames": add, "tier": tier})
	if hitstops.size() > LOG_MAX:
		hitstops.pop_front()
	return float(add) / float(_ticks())


## How many of `add` new light frames starting at frame `first` fit the cap in every window that would contain them.
func _light_allowance(first: int, add: int) -> int:
	var win: int = maxi(1, roundi(LIGHT_WINDOW * float(_ticks())))
	var cap: int = int(floor(LIGHT_CAP * float(_ticks()) + 1e-4))
	var ok: int = 0
	for n: int in range(1, add + 1):
		var e: int = first + n - 1          # the window ending on the newest frame (earlier ones were checked at n - 1)
		var cnt: int = n
		for f: int in _light_frames:
			if f > e - win and f <= e:
				cnt += 1
		if cnt > cap:
			break
		ok = n
	return ok


func hitstop_active() -> bool:
	return _hs_end >= 0


func slowmo_running() -> bool:
	return _slow_end >= 0


## Combat slow motion: `scale` for round(secs * ticks) frames, after a running hit-stop. false when another node owns the
## time scale. `by` tags the request (slowmo_active / end_slowmo filter on it).
func slowmo(scale: float, secs: float, by: Object = null) -> bool:
	if _foreign_owner(self):
		return false
	_slow_scale = clampf(scale, 0.05, 1.0)
	_slow_by = by
	slow_count += 1
	RadialWheel.scale_owner = self
	var n: int = maxi(1, roundi(secs * float(_ticks())))
	if _hs_end >= 0:
		_slow_frames = n                     # starts when the freeze ends
		_slow_end = -1
	else:
		_slow_frames = 0
		_slow_end = Engine.get_physics_frames() + n
		Engine.time_scale = _slow_scale
	return true


## A slow motion is running or queued after the freeze (by: only that requester's).
func slowmo_active(by: Object = null) -> bool:
	return (_slow_end >= 0 or _slow_frames > 0) and (by == null or by == _slow_by)


func end_slowmo(by: Object = null) -> void:
	if not slowmo_active(by):
		return
	_slow_end = -1
	_slow_frames = 0
	_slow_by = null
	if _hs_end < 0:
		_release()


## Everything off at once (pause, yield): no time scale write unless this clock still owns it.
func _drop_all() -> void:
	_hs_end = -1
	_slow_end = -1
	_slow_frames = 0
	_slow_by = null
	_release()


func _release() -> void:
	if RadialWheel.scale_owner == self:
		Engine.time_scale = 1.0
		RadialWheel.scale_owner = null


func _physics_process(_d: float) -> void:
	var dt: float = 1.0 / float(_ticks())
	rt += dt
	var pf: int = Engine.get_physics_frames()
	if _hs_end >= 0 or _slow_end >= 0 or _slow_frames > 0:
		if get_tree().paused:
			_drop_all()
		elif _foreign_owner(self):
			_hs_end = -1                     # the wheel / a set piece took the time scale
			_slow_end = -1
			_slow_frames = 0
		elif _hs_end >= 0:
			if pf >= _hs_end:
				_hs_end = -1
				if _slow_frames > 0:
					_slow_end = pf + _slow_frames
					_slow_frames = 0
					Engine.time_scale = _slow_scale
				else:
					_release()
		elif _slow_end >= 0 and pf >= _slow_end:
			_slow_end = -1
			_slow_by = null
			_release()
	if _light_frames.size() > 32:
		_light_frames = _light_frames.slice(_light_frames.size() - 16)
	if _edge_s > 0.0:
		_edge_s = maxf(0.0, _edge_s - _edge_decay * dt)
		if _edge_mat:
			_edge_mat.set_shader_parameter("strength", _edge_s)
		if _edge_s <= 0.0 and _edge_layer:
			_edge_layer.visible = false


## A cue (ImpactAudio, WeaponAudio, SwordAudio or CineAudio by name) at pos; once per frame, the crowd and the sting rate
## limited. false when skipped.
func play(cue: String, pos: Vector3, db: float = 0.0) -> bool:
	var pf: int = Engine.get_physics_frames()
	if int(_cue_frame.get(cue, -99)) >= pf - 1:
		return false
	if cue == "crowd_oh" and rt - float(_cue_rt.get(cue, -99.0)) < CROWD_GAP:
		return false
	if cue == "sting" and rt - float(_cue_rt.get(cue, -99.0)) < STING_GAP:
		return false
	var st: AudioStream = _stream(cue)
	if st == null:
		return false
	_cue_frame[cue] = pf
	_cue_rt[cue] = rt
	cue_log.append(cue)
	if cue_log.size() > LOG_MAX:
		cue_log.pop_front()
	if UNPOSITIONED.has(cue):
		if _sfx2.is_empty():
			return true
		var q: AudioStreamPlayer = _sfx2[_i2]
		_i2 = (_i2 + 1) % _sfx2.size()
		q.stream = st
		q.volume_db = db
		q.play()
		return true
	if _sfx3.is_empty():
		return true
	var p: AudioStreamPlayer3D = _sfx3[_i3]
	_i3 = (_i3 + 1) % _sfx3.size()
	p.stream = st
	p.volume_db = db
	p.global_position = pos
	p.play()
	return true


static func _stream(cue: String) -> AudioStream:
	if ImpactAudio.is_cue(cue):
		return ImpactAudio.stream(cue)
	if WeaponAudio.CUES.has(cue):
		return WeaponAudio.stream(cue)
	if SwordAudio.is_cue(cue):
		return SwordAudio.stream(cue)
	return CineAudio.sfx(cue)


## The red screen-edge flash: strength now, fading to 0 over secs.
func flash_edge(color: Color, strength: float, secs: float) -> void:
	if _edge_layer == null:
		_edge_layer = CanvasLayer.new()
		_edge_layer.name = "ImpactEdge"
		_edge_layer.layer = 5
		add_child(_edge_layer)
		var r := ColorRect.new()
		r.name = "Edge"
		r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sh := Shader.new()
		sh.code = EDGE_SHADER
		_edge_mat = ShaderMaterial.new()
		_edge_mat.shader = sh
		r.material = _edge_mat
		_edge_layer.add_child(r)
	_edge_s = clampf(maxf(_edge_s, strength), 0.0, 1.0)
	_edge_decay = _edge_s / maxf(secs, 0.05)
	_edge_mat.set_shader_parameter("tint", Color(color.r, color.g, color.b, 1.0))
	_edge_mat.set_shader_parameter("strength", _edge_s)
	_edge_layer.visible = true
	edge_flashes += 1


func edge_strength() -> float:
	return _edge_s


## The clock's own WeaponFX (particle fallback when the caller gave none).
func own_fx() -> WeaponFX:
	if _fx_own == null or not is_instance_valid(_fx_own):
		_fx_own = WeaponFX.new()
		_fx_own.name = "ImpactFX"
		add_child(_fx_own)
	return _fx_own
