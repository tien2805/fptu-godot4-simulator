# File: res://scripts/cine/CineClock.gd
# Cinematic clock (A1-D6, A1-D7): maps REAL time r (seconds of video: music, subtitles, camera motion, the fixed slot length)
# to STORY time s (seconds inside the scene: actors, FX, cue times) through analytic slow-motion ramps.
# A ramp sits around an impact at story time `s` and is defined by REAL-time durations:
#   ri  speed base -> k (smoothstep)   hp  hold k   freeze  speed 0   hq  hold k   ro  speed k -> base (smoothstep)
# so every ramp has an exact real span (ri + hp + freeze + hq + ro) and an exact story span
#   pre  = ri·(base + k)/2 + hp·k        (story seconds before the impact)
#   post = hq·k + ro·(k + base)/2        (story seconds after the impact)
# (∫₀¹ smoothstep = 1/2). Between ramps the clock runs at `base` (1 for cinematics). Hence the real length of a timeline is
#   real = (story_end − Σ(pre + post)) / base + Σ real_span
# exactly, and validate() checks it against the declared slot length (A1-D8). The impact's real time is the start of its
# freeze. Playback only needs story_at(r) (closed form); real_at(s) inverts with bisection inside smooth ramps.
class_name CineClock
extends RefCounted

const PRESETS: Dictionary = {
	"light":    {"k": 0.40, "freeze": 0.10, "ri": 0.10, "hp": 0.10, "hq": 0.25, "ro": 0.15},
	"medium":   {"k": 0.30, "freeze": 0.14, "ri": 0.12, "hp": 0.20, "hq": 0.50, "ro": 0.22},
	"heavy":    {"k": 0.25, "freeze": 0.18, "ri": 0.15, "hp": 0.30, "hq": 0.80, "ro": 0.30},
	"finisher": {"k": 0.25, "freeze": 0.20, "ri": 0.20, "hp": 0.45, "hq": 1.00, "ro": 0.35},
	"accent":   {"k": 0.30, "freeze": 0.00, "ri": 0.12, "hp": 0.25, "hq": 0.35, "ro": 0.25},
}
const TOL: float = 0.0005          # real-length tolerance (s)
const TAIL_MIN: float = 3.0        # last seconds at base speed (A1-D8)
const TAIL_MAX: float = 4.0
enum Seg { ONE, IN, HOLD, FREEZE, OUT }

var length: float = 25.0           # declared real length (the slot length)
var story_end: float = 0.0         # declared story length
var base: float = 1.0              # speed between ramps (replays use 0.5)
var tail_rule: bool = true         # replays switch the 3-4 s tail rule off
var ramps: Array[Dictionary] = []  # sorted by s: {name, preset, s, k, freeze, ri, hp, hq, ro, s0, s1, r0, r_hit, r1}
var _segs: Array = []              # [r0, dur, s0, Seg, k]


## Add a ramp around the impact at story time s. over: per-ramp overrides of the preset values (extra keys are kept).
func add(name: String, s: float, preset: String = "medium", over: Dictionary = {}) -> void:
	var p: Dictionary = (PRESETS[preset] as Dictionary).duplicate()
	p.merge(over, true)
	p["name"] = name
	p["preset"] = preset
	p["s"] = s
	ramps.append(p)
	_segs.clear()


static func _I(u: float) -> float:   # ∫₀ᵘ smoothstep
	return u * u * u - u * u * u * u * 0.5


static func _S(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


## Sort the ramps and build the real-time segment list. Called lazily by the queries.
func build() -> void:
	ramps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) < float(b["s"]))
	_segs.clear()
	var r: float = 0.0
	var s: float = 0.0
	var b: float = base
	for p: Dictionary in ramps:
		var k: float = p["k"]
		var pre: float = float(p["ri"]) * (b + k) * 0.5 + float(p["hp"]) * k
		var post: float = float(p["hq"]) * k + float(p["ro"]) * (k + b) * 0.5
		p["s0"] = float(p["s"]) - pre
		p["s1"] = float(p["s"]) + post
		var gap: float = maxf(float(p["s0"]) - s, 0.0)
		_segs.append([r, gap / b, s, Seg.ONE, b])
		r += gap / b
		s = p["s0"]
		p["r0"] = r
		for part: Array in [[Seg.IN, float(p["ri"])], [Seg.HOLD, float(p["hp"])], [Seg.FREEZE, float(p["freeze"])], [Seg.HOLD, float(p["hq"])], [Seg.OUT, float(p["ro"])]]:
			var d: float = part[1]
			if d <= 0.0:
				continue
			if part[0] == Seg.FREEZE:
				p["r_hit"] = r
			_segs.append([r, d, s, part[0], k])
			r += d
			s += _story_span(part[0], d, k, b)
		if float(p["freeze"]) <= 0.0:
			p["r_hit"] = float(p["r0"]) + float(p["ri"]) + float(p["hp"])
		p["r1"] = r
	_segs.append([r, INF, s, Seg.ONE, b])


static func _story_span(seg: int, d: float, k: float, b: float) -> float:
	match seg:
		Seg.ONE:
			return d * b
		Seg.IN, Seg.OUT:
			return d * (b + k) * 0.5
		Seg.HOLD:
			return d * k
	return 0.0


func _ensure() -> void:
	if _segs.is_empty():
		build()


## Story time at real time r (closed form).
func story_at(r: float) -> float:
	_ensure()
	if r <= 0.0:
		return 0.0
	for g: Array in _segs:
		var r0: float = g[0]
		var d: float = g[1]
		if r > r0 + d:
			continue
		var dt: float = r - r0
		var s0: float = g[2]
		var k: float = g[4]
		match int(g[3]):
			Seg.ONE:
				return s0 + dt * base
			Seg.HOLD:
				return s0 + dt * k
			Seg.FREEZE:
				return s0
			Seg.IN:
				var u: float = dt / d
				return s0 + d * (base * u + (k - base) * _I(u))
			Seg.OUT:
				var u2: float = dt / d
				return s0 + d * (k * u2 + (base - k) * _I(u2))
	return 0.0


## Speed ds/dr at real time r (0 during a freeze).
func speed_at(r: float) -> float:
	_ensure()
	for g: Array in _segs:
		var r0: float = g[0]
		var d: float = g[1]
		if r > r0 + d:
			continue
		var k: float = g[4]
		match int(g[3]):
			Seg.ONE:
				return base
			Seg.HOLD:
				return k
			Seg.FREEZE:
				return 0.0
			Seg.IN:
				return base + (k - base) * _S(clampf((r - r0) / d, 0.0, 1.0))
			Seg.OUT:
				return k + (base - k) * _S(clampf((r - r0) / d, 0.0, 1.0))
	return base


## Real time at story time s (an impact's story time maps to the start of its freeze).
func real_at(s: float) -> float:
	_ensure()
	if s <= 0.0:
		return 0.0
	for g: Array in _segs:
		var r0: float = g[0]
		var d: float = g[1]
		var s0: float = g[2]
		var k: float = g[4]
		var seg: int = g[3]
		if seg == Seg.FREEZE:
			continue
		var span: float = INF if d == INF else _story_span(seg, d, k, base)
		if s > s0 + span + 1e-9:
			continue
		match seg:
			Seg.ONE:
				return r0 + (s - s0) / base
			Seg.HOLD:
				return r0 + (s - s0) / k
			_:
				var lo: float = 0.0
				var hi: float = 1.0
				for i: int in 40:
					var m: float = (lo + hi) * 0.5
					var sm: float = d * (base * m + (k - base) * _I(m)) if seg == Seg.IN else d * (k * m + (base - k) * _I(m))
					if s0 + sm < s:
						lo = m
					else:
						hi = m
				return r0 + d * hi
	return 0.0


## Real duration of the declared story (analytic through the segments).
func real_duration() -> float:
	return real_at(story_end)


func ramp(name: String) -> Dictionary:
	_ensure()
	for p: Dictionary in ramps:
		if String(p["name"]) == name:
			return p
	return {}


## Errors (empty = valid): real length, overlaps, ranges, tail at base speed.
func validate() -> PackedStringArray:
	build()
	var err: PackedStringArray = []
	var prev_s1: float = 0.0
	var prev_name: String = "start"
	for p: Dictionary in ramps:
		var nm: String = p["name"]
		var k: float = p["k"]
		var fr: float = p["freeze"]
		if float(p["s0"]) < prev_s1 - 1e-6:
			err.append("%s: ramp starts at story %.4f before %s ends at %.4f" % [nm, float(p["s0"]), prev_name, prev_s1])
		if fr > 0.0 and (k < 0.25 - 1e-6 or k > 0.40 + 1e-6):
			err.append("%s: impact speed %.3f outside 0.25-0.40" % [nm, k])
		if fr > 0.0 and (fr < 0.10 - 1e-6 or fr > 0.20 + 1e-6):
			err.append("%s: freeze %.3f s outside 0.10-0.20" % [nm, fr])
		if fr <= 0.0 and (k < 0.2 - 1e-6 or k > 0.6 + 1e-6):
			err.append("%s: accent speed %.3f outside 0.20-0.60" % [nm, k])
		prev_s1 = p["s1"]
		prev_name = nm
	if story_end < prev_s1 - 1e-6:
		err.append("story_end %.4f is before the last ramp ends (%.4f)" % [story_end, prev_s1])
	var real: float = real_duration()
	if absf(real - length) > TOL:
		err.append("real length %.4f s != slot %.4f s: set story_end to %.5f" % [real, length, story_end + (length - real) * base])
	if tail_rule and not ramps.is_empty():
		var tail: float = length - float(ramps[ramps.size() - 1]["r1"])
		if tail < TAIL_MIN - 1e-6 or tail > TAIL_MAX + 1e-6:
			err.append("tail at normal speed %.3f s outside %.1f-%.1f s" % [tail, TAIL_MIN, TAIL_MAX])
	return err


## Beat rows in real seconds, sorted: {name, preset, s, k, freeze, r_hit, r_freeze_end, r_start, r_end, what}.
func beat_rows() -> Array[Dictionary]:
	_ensure()
	var rows: Array[Dictionary] = []
	for p: Dictionary in ramps:
		rows.append({"name": p["name"], "preset": p["preset"], "s": p["s"], "k": p["k"], "freeze": p["freeze"],
			"r_hit": p["r_hit"], "r_freeze_end": float(p["r_hit"]) + float(p["freeze"]), "r_start": p["r0"], "r_end": p["r1"],
			"what": String(p.get("what", ""))})
	return rows
