# File: res://scripts/combat/ImpactAudio.gd
# Q2 impact sound layers (spec 2026-10-29 Q2), synthesized in code from the frozen CineAudio statics (_tone, _noise, _mix,
# _paste, _to_wav): sound effects, no melody, no music. Cues:
#   whoosh_hit  a short air snap on the hit                 thud       a low punchy body thump
#   body        the body slap / stagger layer (heavy)        crowd_oh   a crowd going "ồ" (many detuned voices)
#   sting       the comic knockout sting (a spring boing over a bonk)
#   keng        a clear, bright parry ring                  slam       a body slammed into a wall
#   metal_slam  a body slammed into a car                   wood_break a table / chair cracking under a body
#   hit_tick    the gun hit marker tick                     ko_tick    the gun knockout marker (two ticks)
#   stick_crack a wooden stick snapping
# Owner override: user://sfx/<cue>.ogg | .mp3 (WeaponAudio.owner_file: local only, never committed).
# warm() builds each missing cue on its own WorkerThreadPool task (never synthesize on a frame); ready_stream(cue) (the
# Impact clock's) returns a cue only when it is ready and never waits; stream(cue) adopts finished tasks, waits for a
# pending one, or builds it as a last resort (tests, tools). Main thread only (static cache); synth(cue) is pure.
class_name ImpactAudio
extends RefCounted

const CUES: Array[String] = ["whoosh_hit", "thud", "body", "crowd_oh", "sting", "keng", "slam", "metal_slam", "wood_break",
	"hit_tick", "ko_tick", "stick_crack"]
static var _cache: Dictionary = {}
static var _tasks: Dictionary = {}       # cue -> {"task": id, "box": [AudioStream]}
## Cues built by worker tasks (tests).
static var warm_builds: int = 0


static func is_cue(cue: String) -> bool:
	return CUES.has(cue)


## Start a worker task for every cue that is neither cached nor pending. Returns the tasks started.
static func warm(cues: Array = CUES) -> int:
	poll()
	var n: int = 0
	for c: Variant in cues:
		var cue: String = String(c)
		if not is_cue(cue) or _cache.has(cue) or _tasks.has(cue):
			continue
		var box: Array = [null]
		_tasks[cue] = {"task": WorkerThreadPool.add_task(_job(box, cue, WeaponAudio.owner_file(cue))), "box": box}
		n += 1
	return n


static func _job(box: Array, cue: String, owner_path: String) -> Callable:
	return func() -> void:
		var st: AudioStream = CineAudio._load_file(owner_path) if owner_path != "" else null
		box[0] = st if st != null else synth(cue)


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


## The cue only if it is ready now: cached, or its worker task just finished. A pending task is not waited for and a
## missing cue starts building (both return null: the caller skips the sound this time).
static func ready_stream(cue: String) -> AudioStream:
	if _cache.has(cue):
		return _cache[cue]
	if _tasks.has(cue):
		if WorkerThreadPool.is_task_completed(int((_tasks[cue] as Dictionary)["task"])):
			_adopt(cue)
		return _cache.get(cue)
	warm([cue])
	return null


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


# ---------------------------------------------------------------------------
# Synthesis (pure)
# ---------------------------------------------------------------------------
static func synth(cue: String) -> AudioStreamWAV:
	match cue:
		"whoosh_hit":    # a quick air snap: band noise swelling in and cut short
			var w: PackedFloat32Array = CineAudio._noise(0.12, 0.35, 0.0, 301, 0.7)
			for i: int in w.size():
				var u: float = float(i) / float(w.size())
				w[i] *= sin(u * PI) * (1.0 - u * 0.4)
			return CineAudio._to_wav(w)
		"thud":          # low punchy thump with a click on top
			return CineAudio._to_wav(CineAudio._mix([CineAudio._tone(0.22, 120.0, 48.0, 0.85, 14.0),
				CineAudio._noise(0.05, 0.5, 70.0, 302, 0.35), CineAudio._tone(0.03, 1400.0, 900.0, 0.12, 90.0)]))
		"body":          # meaty slap: mid noise burst over a short tom
			return CineAudio._to_wav(CineAudio._mix([CineAudio._noise(0.16, 0.7, 24.0, 303, 0.55),
				CineAudio._tone(0.25, 190.0, 95.0, 0.5, 11.0)]))
		"crowd_oh":      # a crowd's "ồ": 9 detuned vowel voices sliding down, breathy noise under them
			var n: int = int(0.75 * CineAudio.SR)
			var buf := PackedFloat32Array()
			buf.resize(n)
			for v: int in 9:
				var f0: float = 150.0 + 23.0 * float(v) + (7.0 if v % 2 == 0 else -5.0)
				var start: float = 0.012 * float(v % 4)
				var ph: float = 0.0
				for i: int in n:
					var t: float = float(i) / CineAudio.SR - start
					if t < 0.0:
						continue
					var f: float = f0 * (1.0 + 0.12 * exp(-t * 6.0)) * (1.0 - 0.1 * t) * (1.0 + 0.012 * sin(t * (24.0 + float(v))))
					ph += TAU * f / CineAudio.SR
					var env: float = smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.45, 0.72, t))
					# "o" vowel: fundamental, the 2nd harmonic strong, the 3rd a touch (rounded, dark)
					buf[i] += (sin(ph) + 0.6 * sin(ph * 2.0) + 0.18 * sin(ph * 3.0)) * env * 0.045
			return CineAudio._to_wav(CineAudio._mix([buf, CineAudio._noise(0.7, 0.05, 2.5, 304, 0.85)]))
		"sting":         # comic knockout sting: a bonk, then a spring "boing" wobbling down
			var sb := PackedFloat32Array()
			sb.resize(int(0.75 * CineAudio.SR))
			CineAudio._paste(sb, CineAudio._mix([CineAudio._tone(0.18, 520.0, 380.0, 0.55, 16.0), CineAudio._noise(0.04, 0.4, 80.0, 305, 0.2)]), 0.0, 1.0)
			var bn: int = int(0.6 * CineAudio.SR)
			var bo := PackedFloat32Array()
			bo.resize(bn)
			var bph: float = 0.0
			for i: int in bn:
				var t: float = float(i) / CineAudio.SR
				var f: float = (330.0 - 140.0 * t) * (1.0 + 0.22 * sin(t * TAU * 11.0) * exp(-t * 3.5))
				bph += TAU * f / CineAudio.SR
				bo[i] = sin(bph) * 0.32 * exp(-t * 3.2) * smoothstep(0.0, 0.01, t)
			CineAudio._paste(sb, bo, 0.1, 1.0)
			return CineAudio._to_wav(sb)
		"keng":          # a clear parry: a hard click, then a bright, long, slightly beating ring
			return CineAudio._to_wav(CineAudio._mix([CineAudio._noise(0.03, 0.7, 110.0, 306, 0.05),
				CineAudio._tone(1.1, 2960.0, 2950.0, 0.26, 3.6), CineAudio._tone(1.1, 2972.0, 2962.0, 0.18, 3.8),
				CineAudio._tone(0.8, 4420.0, 4400.0, 0.12, 5.5), CineAudio._tone(0.5, 6180.0, 6150.0, 0.06, 8.0)]))
		"slam":          # a body into a wall: a deep boom with a gritty tail
			return CineAudio._to_wav(CineAudio._mix([CineAudio._tone(0.45, 85.0, 40.0, 0.95, 7.0),
				CineAudio._noise(0.3, 0.75, 13.0, 307, 0.45), CineAudio._tone(0.08, 600.0, 300.0, 0.18, 40.0)]))
		"metal_slam":    # a body into a car: a dented panel boom with a metallic ring
			return CineAudio._to_wav(CineAudio._mix([CineAudio._tone(0.5, 110.0, 70.0, 0.8, 6.0),
				CineAudio._tone(0.7, 690.0, 670.0, 0.22, 5.0), CineAudio._tone(0.6, 1130.0, 1110.0, 0.12, 6.0),
				CineAudio._noise(0.2, 0.6, 18.0, 308, 0.3)]))
		"wood_break":    # cracking wood: crackle bursts over a dull knock
			var wb := PackedFloat32Array()
			wb.resize(int(0.5 * CineAudio.SR))
			CineAudio._paste(wb, CineAudio._tone(0.25, 180.0, 90.0, 0.55, 12.0), 0.0, 1.0)
			for k: int in 6:
				CineAudio._paste(wb, CineAudio._noise(0.05, 0.6, 60.0, 309 + k, 0.1), 0.02 + 0.045 * float(k) + 0.01 * float(k % 2), 1.0 - 0.1 * float(k))
			return CineAudio._to_wav(wb)
		"hit_tick":      # hit marker: a short high tick
			return CineAudio._to_wav(CineAudio._mix([CineAudio._tone(0.05, 2400.0, 2200.0, 0.4, 60.0), CineAudio._noise(0.015, 0.3, 200.0, 320, 0.1)]))
		"ko_tick":       # knockout marker: two ticks, the second lower and longer
			var kb := PackedFloat32Array()
			kb.resize(int(0.22 * CineAudio.SR))
			CineAudio._paste(kb, CineAudio._tone(0.05, 2600.0, 2400.0, 0.4, 60.0), 0.0, 1.0)
			CineAudio._paste(kb, CineAudio._tone(0.12, 1500.0, 1300.0, 0.4, 22.0), 0.07, 1.0)
			return CineAudio._to_wav(kb)
		"stick_crack":   # a wooden stick snapping: a dry crack and a short splinter rattle
			return CineAudio._to_wav(CineAudio._mix([CineAudio._noise(0.06, 0.85, 70.0, 321, 0.0),
				CineAudio._tone(0.12, 900.0, 500.0, 0.25, 30.0), CineAudio._noise(0.25, 0.25, 14.0, 322, 0.3)]))
	return CineAudio._to_wav(CineAudio._tone(0.1, 440.0, 440.0, 0.2, 20.0))
