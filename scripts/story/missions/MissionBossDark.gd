# File: res://scripts/story/missions/MissionBossDark.gd
# Day 7 boss, phase 2 "Mất điện" (plan 2026-11-01-w4-day7.md T1 / T2): the blackout in the vase gallery. Lọ cut the power
# (LairTower.set_power(false), the "penthouse_blackout" look); the player has the flashlight ([F], HorrorFlashlight, no
# battery drain here) and no gun. Lọ stalks in the dark:
#   - "stalk": he walks toward the player (STALK_MS, slower when "Giảm hù dọa");
#   - "wind": within LUNGE_M he winds up for WIND_S (the telegraph: the nearest vase cracks with a glass crack, the nearest
#     speaker's ring glows and his voice comes from it), then "lunge" (LUNGE_MS for LUNGE_S): touching the player costs
#     HIT_DMG (heavy), hit or miss he melts back into the dark ("vanish", VANISH_S, then he walks in from BACK_M behind the beam);
#   - the flashlight on him for LIT_S (inside its cone, a clear line) staggers him ("stagger" STAGGER_S, then "vanish"):
#     the beam is the defence.
# The way out: the two breakers on the side walls (points.breakers): hold [E] next to one for HOLD_S (the progress stays
# when let go); both on = the power back, the lights on, Lọ runs to the roof: done {"staggers", "hits"}.
# Down (the player's HP 0) = "TOANG!"; THỬ LẠI = power off again, both breakers off, Lọ back at his desk, HP full.
# "Giảm hù dọa" (GameFX.reduce_scares): slower stalking, a longer telegraph, softer hits, no laugh, the gentle flashlight,
# a softer crack, a smaller speaker pulse and a lighter blackout (LOOK_GENTLE: brighter ambient and fill).
# T2 polish: the telegraph cracks the nearest vase still whole (one by one; the ones phase 1 broke are gone); every line he
# says comes from the speaker nearest to him (the subtitle + that speaker's ring pulsing for PULSE_S, the others dark); a
# preview cut to the first breaker when the lights go out (the way out); THỬ LẠI mends the cracks of the failed try.
# Test hooks: hold_override (bool: [E] held), lit_override (-1 off, 0 / 1 forces the beam test).
# points: start (+ start_yaw), boss_at, breakers [Vector3, Vector3], centre, leash.
class_name MissionBossDark
extends StoryMission

const LOOK: String = "penthouse_blackout"
## "Giảm hù dọa": the same blackout with a brighter ambient and fill (the hall readable without the beam).
const LOOK_GENTLE: String = "penthouse_blackout_gentle"
const STALK_MS: float = 2.6
const STALK_MS_GENTLE: float = 1.2
const LUNGE_M: float = 3.2
const WIND_S: float = 0.9
const WIND_S_GENTLE: float = 1.4
const LUNGE_MS: float = 7.0
const LUNGE_S: float = 0.55
const HIT_M: float = 1.35
const HIT_DMG: float = 50.0                # T5 (sim_day7): two missed dodges put him down on Thường (no quick heal)
const HIT_DMG_EASY: float = 36.0
const HIT_DMG_GENTLE: float = 22.0
const VANISH_S: float = 1.0
## T5: he walks back in from the dark behind the beam, this far from the player (else the farthest corner).
const BACK_M: float = 6.5
const STAGGER_S: float = 1.1
const LIT_S: float = 1.2
const LIT_DEG: float = 22.0
const LIT_RANGE: float = 17.0
## T5 (sim_day7): a breaker is a long hold (he comes for the player at it); Dễ shorter.
const HOLD_S: float = 8.5
const HOLD_S_EASY: float = 5.0
## T5: no quick heal in the dark (regeneration after this long without a hit; restored on cleanup).
const REGEN_DELAY_DARK: float = 8.0
const BREAKER_R: float = 1.6
const RAY_HZ: float = 10.0
const LO_EYE: float = 1.45
const PULSE_S: float = 2.4
const PULSE_HZ: float = 3.0
const PULSE_AMP: float = 0.45
const PULSE_AMP_GENTLE: float = 0.2
const CUT_S: float = 0.6
const T_DOWN: String = "Bị Lọ hạ trong bóng tối!"
const T_RAN: String = "Bỏ chạy khỏi phòng rồi!"
const T_INFO: String = "Cầu dao: %d / 2 · [F] đèn pin"
const T_HOLD: String = "Giữ [E] bật cầu dao"
const T_STAGGER: String = "Lọ bị chói mắt!"
const T_POWER: String = "Có điện lại rồi!"
const T_BREAKER: String = "Cầu dao"
const LAUGHS: Array[String] = ["Thầy ở ngay sau lưng em đó.", "Tắt đèn rồi, em còn thấy đường về không?",
	"Bình cổ vỡ một cái, em đền cả học kỳ.", "Học thật... đậu thật..."]

var pts: Dictionary = {}
var level: Node3D = null
var flashlight: HorrorFlashlight
var lo: Node3D = null
var lo_state: String = "stalk"
var lo_t: float = 0.0
var lit_t: float = 0.0
var lit_now: bool = false
var hold: Array[float] = [0.0, 0.0]
var restored: Array[bool] = [false, false]
var staggers: int = 0
var hits: int = 0
var lunges: int = 0
var cracks: int = 0
var voices: int = 0
var cuts: int = 0
var pulses: int = 0
var ring: Node3D = null                       # the speaker ring that pulses now (his voice)
var hold_override: bool = false
var lit_override: int = -1
var gentle: bool = false
## The look this try put on (LOOK or LOOK_GENTLE: a switch of "Giảm hù dọa" between tries takes the right one off).
var look_on: String = ""
var guide: BasementGuide = null
var _ray_acc: float = 0.0
var _ray_ok: bool = false
var _spawn_i: int = 0
var _laugh_i: int = 0
var _info_n: int = -1
var _pulse_t: float = 0.0
var _cracked: Array[Node3D] = []             # the vases this try cracked (mended on THỬ LẠI)


func setup(r: Node3D, b: Dictionary, o: Dictionary = {}) -> void:
	super.setup(r, b, o)
	pts = opts.get("points", {})
	level = opts.get("level", null)


func _start() -> void:
	flashlight = HorrorFlashlight.new()
	flashlight.auto_tick = false            # no battery drain in the boss fight
	add_child(flashlight)
	flashlight.anchor = player
	flashlight.aim = player.camera if player else null
	lo = CastD7.build("van_lo")
	if lo:
		lo.name = "LoDark"
		add_child(lo)
	guide = BasementGuide.new()
	add_child(guide)
	guide.setup(self)
	guide.hide_fn = func() -> bool: return state != "running"
	_fresh()
	var bk: Array = level.get("breakers") if level else []
	if not bk.is_empty():
		_cut(bk[0])


## The start of the blackout (first run and every retry: "Giảm hù dọa" switched on after a fail applies to the next try).
func _fresh() -> void:
	var fx: Node = get_node_or_null("/root/GameFX")
	gentle = fx != null and bool(fx.get("reduce_scares"))
	flashlight.gentle = gentle
	hold = [0.0, 0.0]
	restored = [false, false]
	lit_t = 0.0
	lo_t = 0.0
	_info_n = -1
	for v: Node3D in _cracked:
		_crack_vase(v, false)
	_cracked.clear()
	_end_pulse()
	if pts.has("start"):
		teleport_player(pts["start"], float(pts.get("start_yaw", 0.0)))
	_power(false)
	for i: int in 2:
		_set_breaker(i, false)
	flashlight.set_on(true)
	if lo:
		lo.visible = true
		lo.global_position = pts.get("boss_at", Vector3.ZERO)
		lo_state = "stalk"
	var c: Object = roam.get("combat") if roam else null
	if c and c.has_method("revive") and float(c.get("hp")) <= 0.0:
		c.call("revive")
	if c:
		c.set("regen_delay", REGEN_DELAY_DARK)
	_next_goal()
	_refresh_info()


func _power(on: bool) -> void:
	if level and level.has_method("set_power"):
		level.call("set_power", on)
	if roam and roam.has_method("look"):
		if look_on != "":
			roam.call("unlook", look_on)
			look_on = ""
		if not on:
			look_on = LOOK_GENTLE if gentle else LOOK
			roam.call("look", look_on)


func _set_breaker(i: int, on: bool) -> void:
	var bk: Array = level.get("breakers") if level else []
	if i >= bk.size():
		return
	var n: Node3D = bk[i]
	var lever: Node3D = n.get_node_or_null("Lever") as Node3D
	if lever:
		lever.rotation.x = -0.7 if on else 0.7
	var lamp: MeshInstance3D = n.get_node_or_null("Lamp") as MeshInstance3D
	if lamp:
		lamp.material_override = CineFX._glow_mat(Color("#3BFF7A") if on else Color("#FF3B3B"), 2.5)


func _unhandled_input(event: InputEvent) -> void:
	if state != "running" or not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if k.pressed and not k.echo and k.physical_keycode == KEY_F and flashlight:
		flashlight.toggle()
		get_viewport().set_input_as_handled()


func _holding() -> bool:
	return hold_override or Input.is_physical_key_pressed(KEY_E)


# ---------------------------------------------------------------------------
func _tick(dt: float) -> void:
	if player == null:
		return
	_tick_pulse(dt)
	var c: Object = roam.get("combat") if roam else null
	if c and float(c.get("hp")) <= 0.0:
		fail(T_DOWN)
		return
	if pts.has("centre") and flat(player.global_position, pts["centre"]) > float(pts.get("leash", 30.0)):
		fail(T_RAN)
		return
	_tick_breakers(dt)
	if state != "running":
		return
	_tick_lo(dt)


func _tick_breakers(dt: float) -> void:
	var br: Array = pts.get("breakers", [])
	var near: int = -1
	for i: int in br.size():
		if not restored[i] and flat(player.global_position, br[i]) <= BREAKER_R:
			near = i
	set_prompt(T_HOLD if near >= 0 else "")
	if near < 0 or not _holding():
		return
	hold[near] = minf(hold_s(), hold[near] + dt)
	set_meter(hold[near] / hold_s() * 100.0, T_BREAKER)
	if hold[near] >= hold_s():
		restored[near] = true
		_set_breaker(near, true)
		play_cue("door_bang", -10.0)
		_refresh_info()
		set_meter(-1.0)
		if restored[0] and restored[1]:
			_win()
		else:
			_next_goal()


func hold_s() -> float:
	return float(Difficulty.pick(HOLD_S, HOLD_S_EASY))


func _next_goal() -> void:
	if guide == null:
		return
	var br: Array = pts.get("breakers", [])
	var best: int = -1
	var bd: float = INF
	for i: int in br.size():
		if not restored[i] and player and flat(player.global_position, br[i]) < bd:
			bd = flat(player.global_position, br[i])
			best = i
	if best >= 0:
		guide.set_goal(br[best], T_BREAKER)
	else:
		guide.clear_goal()


func _refresh_info() -> void:
	var n: int = int(restored[0]) + int(restored[1])
	if n != _info_n:
		_info_n = n
		set_info(T_INFO % n)


func _win() -> void:
	_power(true)
	popup(T_POWER, 1.8)
	play_cue("success_fanfare", -10.0)
	if lo:
		lo.visible = false
	flashlight.set_on(false)
	finish({"staggers": staggers, "hits": hits})


# ----- Lọ in the dark -----
func _tick_lo(dt: float) -> void:
	if lo == null:
		return
	lo_t += dt
	var to_p: Vector3 = player.global_position - lo.global_position
	to_p.y = 0.0
	var dist: float = to_p.length()
	var dir: Vector3 = to_p / dist if dist > 0.01 else Vector3.FORWARD
	match lo_state:
		"stalk":
			_face(dir)
			lo.global_position += dir * (STALK_MS_GENTLE if gentle else STALK_MS) * dt
			CharacterBuilder.set_speed(lo, STALK_MS)
			if _lit(dt):
				_stagger()
			elif dist <= LUNGE_M:
				_go("wind")
				_telegraph()
		"wind":
			_face(dir)
			CharacterBuilder.set_speed(lo, 0.0)
			if _lit(dt):
				_stagger()
			elif lo_t >= (WIND_S_GENTLE if gentle else WIND_S):
				lunges += 1
				_go("lunge")
		"lunge":
			lo.global_position += -lo.global_transform.basis.z * LUNGE_MS * dt
			if dist <= HIT_M:
				_hit()
			elif lo_t >= LUNGE_S:
				_vanish()                        # a miss: he melts back into the dark too (T5: no lunge right after a lunge)
		"stagger":
			CharacterBuilder.set_speed(lo, 0.0)
			if lo_t >= STAGGER_S:
				_vanish()
		"vanish":
			if lo_t >= VANISH_S:
				lo.visible = true
				lo.global_position = _far_spot()
				_go("stalk")


func _go(s: String) -> void:
	lo_state = s
	lo_t = 0.0
	lit_t = 0.0


func _face(dir: Vector3) -> void:
	if dir.length_squared() > 0.0001:
		lo.rotation.y = atan2(-dir.x, -dir.z)


## The beam on him: inside the flashlight's cone, within range, a clear line (RAY_HZ rays); LIT_S of it staggers him.
func _lit(dt: float) -> bool:
	lit_now = false
	if lit_override >= 0:
		lit_now = lit_override == 1
	elif flashlight and flashlight.is_lit():
		var eye: Vector3 = lo.global_position + Vector3(0.0, LO_EYE, 0.0)
		var from: Vector3 = flashlight.global_position
		var fwd: Vector3 = -flashlight.global_transform.basis.z
		var d: Vector3 = eye - from
		var dl: float = d.length()
		if dl <= LIT_RANGE and dl > 0.01 and fwd.dot(d / dl) >= cos(deg_to_rad(LIT_DEG)):
			_ray_acc += dt
			if _ray_acc >= 1.0 / RAY_HZ:
				_ray_acc = 0.0
				_ray_ok = _clear(from, eye)
			lit_now = _ray_ok
	lit_t = lit_t + dt if lit_now else maxf(0.0, lit_t - dt * 0.5)
	return lit_t >= LIT_S


## Nothing between the flashlight and his eyes but him (his body has no collider) or the player.
func _clear(a: Vector3, b: Vector3) -> bool:
	if not is_inside_tree():
		return true
	var q := PhysicsRayQueryParameters3D.create(a, b)
	if player:
		q.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _stagger() -> void:
	staggers += 1
	add_stat("staggers")
	popup(T_STAGGER, 1.2)
	play_cue("impact_medium", -6.0)
	_go("stagger")


func _hit() -> void:
	hits += 1
	var c: Object = roam.get("combat") if roam else null
	if c and c.has_method("receive_attack"):
		c.call("receive_attack", lo, {"damage": HIT_DMG_GENTLE if gentle else float(Difficulty.pick(HIT_DMG, HIT_DMG_EASY)), "heavy": true})
	play_cue("impact_heavy", -4.0)
	_vanish()


func _vanish() -> void:
	lo.visible = false
	CharacterBuilder.set_speed(lo, 0.0)
	_go("vanish")
	_voice()


## The telegraph: the vase nearest to him that is still whole cracks (else the nearest standing one), the speaker nearest
## to him pulses and speaks (his laugh unless gentle).
func _telegraph() -> void:
	var best: Node3D = null
	var bd: float = INF
	for pass_i: int in 2:
		for v: Dictionary in (level.get("vases") if level else []):
			var n: Node3D = v.get("node")
			if n == null or not is_instance_valid(n) or not n.visible or (pass_i == 0 and _is_cracked(n)):
				continue
			var dd: float = flat(n.global_position, lo.global_position)
			if dd < bd:
				bd = dd
				best = n
		if best:
			break
	if best:
		if not _is_cracked(best):
			_crack_vase(best, true)
			_cracked.append(best)
		cracks += 1
		play_cue("glass_crack", -4.0 if not gentle else -12.0)
	_voice()


func _is_cracked(vase: Node3D) -> bool:
	var cr: Node3D = vase.get_node_or_null("Cracks") as Node3D
	return cr != null and cr.get_child_count() > 0 and (cr.get_child(0) as Node3D).visible


func _crack_vase(vase: Node3D, on: bool) -> void:
	if vase == null or not is_instance_valid(vase):
		return
	var cr: Node3D = vase.get_node_or_null("Cracks") as Node3D
	if cr:
		for ch: Node in cr.get_children():
			(ch as Node3D).visible = on


func _voice() -> void:
	voices += 1
	var sp: Array = level.get("speakers") if level else []
	var bd: float = INF
	var best: Node3D = null
	for s: Variant in sp:
		var n: Node3D = s
		var dd: float = flat(n.global_position, lo.global_position) if lo else 0.0
		if dd < bd:
			bd = dd
			best = n
	_end_pulse()
	for s2: Variant in sp:
		var r: Node3D = (s2 as Node3D).get_node_or_null("Ring") as Node3D
		if r:
			r.visible = s2 == best
			if s2 == best:
				ring = r
	if ring:
		_pulse_t = PULSE_S
		pulses += 1
	if not gentle and voices % 2 == 1:
		play_cue("evil_laugh", -10.0)
	radio_as("van_lo", LAUGHS[_laugh_i % LAUGHS.size()], "", 3.0)
	_laugh_i += 1


## The speaking speaker's ring beats with his voice (PULSE_HZ), fading out over PULSE_S; then dark.
func _tick_pulse(dt: float) -> void:
	if ring == null:
		return
	if not is_instance_valid(ring):
		ring = null
		return
	_pulse_t -= dt
	if _pulse_t <= 0.0:
		_end_pulse()
		return
	var k: float = _pulse_t / PULSE_S
	var s: float = 1.0 + (PULSE_AMP_GENTLE if gentle else PULSE_AMP) * absf(sin(_pulse_t * PULSE_HZ * PI)) * k
	ring.scale = Vector3(s, 1.0, s)              # the disc's radius (its height is the cylinder's local Y)


func _end_pulse() -> void:
	if ring and is_instance_valid(ring):
		ring.scale = Vector3.ONE
		ring.visible = false
	ring = null
	_pulse_t = 0.0


func _cut(target: Node3D) -> void:
	if target == null or not target.is_inside_tree():
		return
	cuts += 1
	var cd: CameraDirector = CameraDirector.live()
	if cd:
		cd.preview_cut(target, CUT_S)


## A dark corner away from the player (the four hall corners in turn, the farthest first).
func _far_spot() -> Vector3:
	var c: Vector3 = pts.get("centre", Vector3.ZERO)
	if player and flashlight:
		var back: Vector3 = flashlight.global_transform.basis.z
		back.y = 0.0
		if back.length() > 0.1:
			var q: Vector3 = player.global_position + back.normalized() * BACK_M
			q.x = clampf(q.x, c.x - 12.0, c.x + 12.0)
			q.z = clampf(q.z, c.z - 10.0, c.z + 10.0)
			q.y = c.y
			if flat(q, player.global_position) >= 5.0:
				_spawn_i += 1
				return q
	var corners: Array[Vector3] = [c + Vector3(-11.0, 0.0, -9.0), c + Vector3(11.0, 0.0, -9.0), c + Vector3(-11.0, 0.0, 9.0),
		c + Vector3(11.0, 0.0, 9.0)]
	var best: Vector3 = corners[0]
	var bd: float = -1.0
	for q: Vector3 in corners:
		var dd: float = flat(q, player.global_position) if player else 0.0
		if dd > bd:
			bd = dd
			best = q
	_spawn_i += 1
	return best


func _reset() -> void:
	_fresh()


func _cleanup() -> void:
	_power(true)
	var c: Object = roam.get("combat") if roam else null
	if c:
		c.set("regen_delay", CombatData.REGEN_DELAY)
	_end_pulse()
	for s: Variant in (level.get("speakers") if level else []):
		var r: Node3D = (s as Node3D).get_node_or_null("Ring") as Node3D
		if r:
			r.visible = false
	if flashlight and is_instance_valid(flashlight):
		flashlight.set_on(false)
