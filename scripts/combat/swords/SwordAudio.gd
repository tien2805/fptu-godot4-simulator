# File: res://scripts/combat/swords/SwordAudio.gd
# Phase C duel SFX (spec C-D3 / C-D4), synthesized in code from the frozen CineAudio statics (_tone, _noise, _mix, _paste,
# _to_wav): no recording, no melody. Cues:
#   staff_swish, staff_hit, staff_hit_heavy (the Vovinam staff), blade_clash (staff on katana), parry_ring (a parry),
#   glint / glint_red (the katana boss's tell 0.5 s before a hit: blockable / unblockable), katana_slash, katana_boing (the
#   cheap blade bending), katana_snap (it breaks), howl (Sói Xám's howl phase).
# Owner override: user://sfx/<cue>.ogg | .mp3 (WeaponAudio.owner_file: local only, never committed).
# warm(cues) builds each missing cue on its own WorkerThreadPool task (Phase W / A2 lesson: never synthesize on a frame);
# stream(cue) adopts finished tasks, waits for one pending cue, or synthesizes as a last resort. Main thread only (static
# cache); synth(cue) is pure.
class_name SwordAudio
extends RefCounted

const CUES: Array[String] = ["staff_swish", "staff_hit", "staff_hit_heavy", "blade_clash", "parry_ring", "glint", "glint_red",
	"katana_slash", "katana_boing", "katana_snap", "howl"]
static var _cache: Dictionary = {}
static var _tasks: Dictionary = {}       # cue -> {"task": id, "box": [AudioStreamWAV]}
## Cues built by worker tasks (tests).
static var warm_builds: int = 0


static func is_cue(cue: String) -> bool:
	return CUES.has(cue)


## Start a worker task for every cue of `cues` that is neither cached, pending nor overridden. Returns the tasks started.
static func warm(cues: Array = CUES) -> int:
	poll()
	var n: int = 0
	for c: Variant in cues:
		var cue: String = String(c)
		if not is_cue(cue) or _cache.has(cue) or _tasks.has(cue) or WeaponAudio.owner_file(cue) != "":
			continue
		var box: Array = [null]
		_tasks[cue] = {"task": WorkerThreadPool.add_task(_job(box, cue)), "box": box}
		n += 1
	return n


static func _job(box: Array, cue: String) -> Callable:
	return func() -> void: box[0] = synth(cue)


## Adopt the finished warm tasks (main thread). true when nothing is pending.
static func poll() -> bool:
	for cue: String in _tasks.keys():
		if WorkerThreadPool.is_task_completed(int((_tasks[cue] as Dictionary)["task"])):
			_adopt(cue)
	return _tasks.is_empty()


static func _adopt(cue: String) -> void:
	var t: Dictionary = _tasks[cue]
	WorkerThreadPool.wait_for_task_completion(int(t["task"]))
	_tasks.erase(cue)
	var st: Variant = (t["box"] as Array)[0]
	if not _cache.has(cue) and st != null:
		_cache[cue] = st
		warm_builds += 1


## The cue's stream: the owner's file, else the synthesized cue (cached). Main thread only.
static func stream(cue: String) -> AudioStream:
	if _cache.has(cue):
		return _cache[cue]
	if _tasks.has(cue):
		_adopt(cue)
		if _cache.has(cue):
			return _cache[cue]
	var st: AudioStream = null
	var f: String = WeaponAudio.owner_file(cue)
	if f != "":
		st = CineAudio._load_file(f)
	if st == null:
		st = synth(cue)
	_cache[cue] = st
	return st


static func is_cached(cue: String) -> bool:
	return _cache.has(cue)


static func clear_cache() -> void:
	for cue: String in _tasks.keys():
		WorkerThreadPool.wait_for_task_completion(int((_tasks[cue] as Dictionary)["task"]))
	_tasks.clear()
	_cache.clear()


# ---------------------------------------------------------------------------
# Synthesis (pure)
# ---------------------------------------------------------------------------
## Inharmonic metal ring: partials f * ratios, each decaying (bright steel).
static func _ring(dur: float, f: float, ratios: Array, amp: float, decay: float) -> PackedFloat32Array:
	var parts: Array = []
	for i: int in ratios.size():
		var r: float = float(ratios[i])
		parts.append(CineAudio._tone(dur, f * r, f * r * 0.995, amp / (1.0 + float(i) * 0.6), decay * (1.0 + float(i) * 0.35)))
	return CineAudio._mix(parts)


static func synth(cue: String) -> AudioStreamWAV:
	match cue:
		"staff_swish":       # a wooden pole cutting the air: low, airy
			return CineAudio._to_wav(CineAudio._noise(0.26, 0.32, 9.0, 81, 0.88))
		"staff_hit":         # wood on a body: a dull thwack
			return CineAudio._to_wav(CineAudio._mix([CineAudio._noise(0.07, 0.6, 55.0, 82, 0.5), CineAudio._tone(0.14, 240.0, 120.0, 0.55, 22.0),
				CineAudio._tone(0.05, 900.0, 700.0, 0.12, 60.0)]))
		"staff_hit_heavy":
			return CineAudio._to_wav(CineAudio._mix([CineAudio._noise(0.14, 0.75, 30.0, 83, 0.55), CineAudio._tone(0.28, 170.0, 70.0, 0.75, 11.0),
				CineAudio._tone(0.06, 700.0, 500.0, 0.15, 50.0)]))
		"blade_clash":       # staff on katana: a hard clack and a short steel ring
			return CineAudio._to_wav(CineAudio._mix([CineAudio._noise(0.05, 0.75, 80.0, 84, 0.15),
				_ring(0.45, 1870.0, [1.0, 1.52, 2.33, 3.1], 0.22, 9.0), CineAudio._tone(0.08, 420.0, 300.0, 0.3, 40.0)]))
		"parry_ring":        # a clean parry: brighter, longer ring
			return CineAudio._to_wav(CineAudio._mix([CineAudio._noise(0.04, 0.6, 90.0, 85, 0.1),
				_ring(0.9, 2480.0, [1.0, 1.41, 2.05, 2.76], 0.24, 4.5)]))
		"glint":             # the tell of a blockable slash: a high shimmering "ting"
			var g: PackedFloat32Array = _ring(0.38, 3300.0, [1.0, 1.5, 2.02], 0.16, 7.0)
			var sh: PackedFloat32Array = CineAudio._tone(0.38, 5200.0, 6100.0, 0.05, 6.0)
			return CineAudio._to_wav(CineAudio._mix([g, sh]))
		"glint_red":         # the tell of an unblockable move: lower, with a rising swell
			var r: PackedFloat32Array = _ring(0.5, 1250.0, [1.0, 1.33, 2.0], 0.2, 5.0)
			var rise: PackedFloat32Array = CineAudio._noise(0.5, 0.12, 0.0, 86, 0.75)
			for i: int in rise.size():
				rise[i] *= float(i) / float(rise.size())
			return CineAudio._to_wav(CineAudio._mix([r, rise]))
		"katana_slash":      # a sharp, thin whoosh
			var w: PackedFloat32Array = CineAudio._noise(0.22, 0.4, 12.0, 87, 0.35)
			return CineAudio._to_wav(CineAudio._mix([w, CineAudio._tone(0.18, 1800.0, 900.0, 0.05, 14.0)]))
		"katana_boing":      # the cheap blade bending: a wobbling "boing"
			var n: int = int(0.6 * CineAudio.SR)
			var b := PackedFloat32Array()
			b.resize(n)
			var ph: float = 0.0
			for i2: int in n:
				var t: float = float(i2) / CineAudio.SR
				var f: float = 210.0 * (1.0 + 0.18 * sin(TAU * 11.0 * t) * exp(-3.0 * t)) * (1.0 - 0.25 * t)
				ph += TAU * f / CineAudio.SR
				b[i2] = (sin(ph) + 0.3 * sin(ph * 2.0)) * 0.45 * exp(-4.5 * t) * minf(1.0, t / 0.004)
			return CineAudio._to_wav(b)
		"katana_snap":       # the blade breaks: a crack, then little tinkles
			var s: PackedFloat32Array = CineAudio._mix([CineAudio._noise(0.12, 0.9, 40.0, 88, 0.05), CineAudio._tone(0.1, 3000.0, 2200.0, 0.2, 30.0)])
			var buf := PackedFloat32Array()
			buf.resize(int(0.9 * CineAudio.SR))
			CineAudio._paste(buf, s, 0.0, 1.0)
			CineAudio._paste(buf, _ring(0.25, 4100.0, [1.0, 1.6], 0.1, 14.0), 0.32, 1.0)
			CineAudio._paste(buf, _ring(0.25, 3600.0, [1.0, 1.7], 0.08, 14.0), 0.5, 1.0)
			CineAudio._paste(buf, _ring(0.2, 4600.0, [1.0, 1.5], 0.06, 16.0), 0.66, 1.0)
			return CineAudio._to_wav(buf)
		"howl":              # a wolf's howl: a voiced glide up, a long held note, a fall; soft breath under it
			return synth_howl()
	return CineAudio._to_wav(CineAudio._tone(0.08, 800.0, 800.0, 0.3, 20.0))


## Synthesized howl (no recording): 1.7 s, pitch 330 -> 560 Hz in 0.35 s, held with vibrato, falling to 420 Hz; a few
## harmonics thinning out (an "ooo" vowel), an attack / release envelope and a breathy noise layer.
static func synth_howl() -> AudioStreamWAV:
	var sr: int = CineAudio.SR
	var dur: float = 1.7
	var n: int = int(dur * sr)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph: float = 0.0
	for i: int in n:
		var t: float = float(i) / sr
		var f: float
		if t < 0.35:
			f = lerpf(330.0, 560.0, smoothstep(0.0, 0.35, t))
		elif t < 1.15:
			f = 560.0
		else:
			f = lerpf(560.0, 420.0, smoothstep(1.15, dur, t))
		f *= 1.0 + 0.012 * sin(TAU * 5.0 * t) * smoothstep(0.3, 0.6, t)
		ph += TAU * f / sr
		var v: float = sin(ph) + 0.35 * sin(2.0 * ph) + 0.12 * sin(3.0 * ph)
		var env: float = minf(1.0, t / 0.12) * minf(1.0, (dur - t) / 0.35)
		buf[i] = v * 0.33 * env
	var breath: PackedFloat32Array = CineAudio._noise(dur, 0.05, 0.0, 89, 0.9)
	for i2: int in n:
		var t2: float = float(i2) / sr
		buf[i2] += breath[i2] * minf(1.0, t2 / 0.2) * minf(1.0, (dur - t2) / 0.4)
	return CineAudio._to_wav(buf)
