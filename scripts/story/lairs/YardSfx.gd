# File: res://scripts/story/lairs/YardSfx.gd
# Tiny synthesized one-shots of the Day 3 yard (plan 2026-10-30-w3-day3.md): a guard's boot step, a snore, the
# floodlight hum (a seamless 1 s loop), a creak (forks going up), a short beep (the smart glasses), a chain rattle tick
# and a beacon blip. Each is a few thousand samples, built once on first use and cached (well under a millisecond, the
# MissionSfx pattern). No music. play(node, cue, db) on the SFX bus; play3d(node, cue, at, db) positioned.
class_name YardSfx
extends RefCounted

const SR: int = 22050
const CUES: Array[String] = ["step", "snore", "hum", "creak", "beep", "beacon"]
static var _cache: Dictionary = {}


static func stream(cue: String) -> AudioStreamWAV:
	if _cache.has(cue):
		return _cache[cue]
	var s := PackedFloat32Array()
	match cue:
		"step":
			s = _step()
		"snore":
			s = _snore()
		"hum":
			s = _hum()
		"creak":
			s = _creak()
		"beep":
			s = _beep(1320.0, 0.09, 2)
		"beacon":
			s = _beep(880.0, 0.12, 1)
		_:
			return null
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = _pack(s)
	if cue == "hum":
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = s.size()
	_cache[cue] = w
	return w


static func play(parent: Node, cue: String, db: float = 0.0) -> bool:
	if parent == null or not parent.is_inside_tree():
		return false
	var st: AudioStreamWAV = stream(cue)
	if st == null:
		return false
	var sp := AudioStreamPlayer.new()
	sp.stream = st
	sp.volume_db = db
	sp.bus = CinePlayer._bus("SFX")
	parent.add_child(sp)
	sp.play()
	sp.finished.connect(sp.queue_free)
	return true


static func play3d(parent: Node, cue: String, at: Vector3, db: float = 0.0, max_m: float = 22.0) -> bool:
	if parent == null or not parent.is_inside_tree():
		return false
	var st: AudioStreamWAV = stream(cue)
	if st == null:
		return false
	var sp := AudioStreamPlayer3D.new()
	sp.stream = st
	sp.volume_db = db
	sp.max_distance = max_m
	sp.bus = CinePlayer._bus("SFX")
	parent.add_child(sp)
	sp.global_position = at
	sp.play()
	sp.finished.connect(sp.queue_free)
	return true


## A looping 3D player of `cue` under parent (the floodlight hum); the caller frees it with the parent.
static func loop3d(parent: Node3D, cue: String, db: float = -14.0, max_m: float = 14.0) -> AudioStreamPlayer3D:
	var sp := AudioStreamPlayer3D.new()
	sp.name = "Loop_" + cue
	sp.stream = stream(cue)
	sp.volume_db = db
	sp.max_distance = max_m
	sp.bus = CinePlayer._bus("SFX")
	parent.add_child(sp)
	if sp.is_inside_tree():
		sp.play()
	return sp


static func _pack(samples: PackedFloat32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(samples.size() * 2)
	for i: int in samples.size():
		out.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	return out


## A boot on concrete: a low thump and a gritty scrape.
static func _step() -> PackedFloat32Array:
	var n: int = int(SR * 0.14)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / SR
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.3)
		s[i] = (sin(TAU * 85.0 * t) * exp(-t * 45.0) * 0.9 + lp * exp(-t * 30.0) * 0.5) * 0.8
	return s


## One comic snore: a rough low inhale buzz, then a whistling exhale.
static func _snore() -> PackedFloat32Array:
	var n: int = int(SR * 1.3)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var ph: float = 0.0
	for i: int in n:
		var t: float = float(i) / SR
		var v: float = 0.0
		if t < 0.7:
			ph += TAU * (70.0 + 8.0 * sin(t * 30.0)) / SR
			v = (signf(sin(ph)) * 0.4 + rng.randf_range(-0.3, 0.3)) * sin(PI * t / 0.7)
		else:
			var u: float = (t - 0.7) / 0.6
			ph += TAU * lerpf(900.0, 600.0, u) / SR
			v = sin(ph) * 0.25 * sin(PI * u) + rng.randf_range(-0.05, 0.05) * sin(PI * u)
		s[i] = v * 0.6
	return s


## Mains hum of a big lamp: 100 Hz and harmonics, exactly 1 s (whole cycles: a seamless loop).
static func _hum() -> PackedFloat32Array:
	var n: int = SR
	var s := PackedFloat32Array()
	s.resize(n)
	for i: int in n:
		var t: float = float(i) / SR
		s[i] = (sin(TAU * 100.0 * t) * 0.5 + sin(TAU * 200.0 * t) * 0.25 + sin(TAU * 300.0 * t) * 0.12) * 0.5
	return s


## A metal creak: a slow sliding squeal with a rough edge.
static func _creak() -> PackedFloat32Array:
	var n: int = int(SR * 0.6)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var ph: float = 0.0
	for i: int in n:
		var t: float = float(i) / SR
		ph += TAU * (420.0 + 160.0 * sin(t * 9.0)) / SR
		s[i] = (sin(ph) * 0.4 + signf(sin(ph * 0.5)) * 0.12 + rng.randf_range(-0.08, 0.08)) * sin(PI * t / 0.6) * 0.7
	return s


## `count` short sine beeps of `secs` at `f`.
static func _beep(f: float, secs: float, count: int) -> PackedFloat32Array:
	var gap: float = secs * 0.8
	var n: int = int(SR * (secs + gap) * count)
	var s := PackedFloat32Array()
	s.resize(n)
	for i: int in n:
		var t: float = float(i) / SR
		var local: float = fmod(t, secs + gap)
		s[i] = sin(TAU * f * t) * 0.45 if local < secs else 0.0
	return s
