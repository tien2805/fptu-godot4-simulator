# File: res://scripts/story/missions/MissionSfx.gd
# Tiny synthesized one-shots of the Wave 2 early-days missions (plan 2026-10-29-w2-early.md): a dog bark (Lu), a phone
# shutter click, a soft food splat and a whoosh-thump for vaults. Each is a few thousand samples, built once on first use
# and cached (well under a millisecond: no worker thread needed). No music. play(node, cue, db) plays one on the SFX bus.
class_name MissionSfx
extends RefCounted

const SR: int = 22050
const CUES: Array[String] = ["bark", "shutter", "splat", "vault"]
static var _cache: Dictionary = {}


static func stream(cue: String) -> AudioStreamWAV:
	if _cache.has(cue):
		return _cache[cue]
	var data := PackedByteArray()
	match cue:
		"bark":
			data = _bark()
		"shutter":
			data = _shutter()
		"splat":
			data = _splat()
		"vault":
			data = _vault()
		_:
			return null
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = data
	_cache[cue] = w
	return w


## One shot under `parent` (freed when done); false when the cue is unknown or the parent is not in the tree.
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


static func _pack(samples: PackedFloat32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(samples.size() * 2)
	for i: int in samples.size():
		out.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	return out


## Two short "gâu" barks: a falling voiced tone with a rough edge, an attack and a quick decay each.
static func _bark() -> PackedByteArray:
	var n: int = int(SR * 0.42)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ph: float = 0.0
	for i: int in n:
		var t: float = float(i) / SR
		var local: float = fmod(t, 0.21)
		var env: float = minf(local / 0.012, 1.0) * exp(-local * 18.0) if local < 0.16 else 0.0
		var f: float = lerpf(620.0, 360.0, clampf(local / 0.12, 0.0, 1.0))
		ph += TAU * f / SR
		var v: float = sin(ph) * 0.6 + sin(ph * 2.0) * 0.25 + signf(sin(ph * 0.5)) * 0.12 + rng.randf_range(-0.2, 0.2)
		s[i] = v * env * 0.8
	return _pack(s)


## A phone camera shutter: two clicks 70 ms apart.
static func _shutter() -> PackedByteArray:
	var n: int = int(SR * 0.16)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i: int in n:
		var t: float = float(i) / SR
		var a: float = exp(-t * 300.0) if t < 0.03 else 0.0
		var b: float = exp(-(t - 0.07) * 260.0) if t >= 0.07 and t < 0.1 else 0.0
		s[i] = rng.randf_range(-1.0, 1.0) * (a + b * 0.8) * 0.7
	return _pack(s)


## A soft wet splat: low-passed noise with a fast decay and a little pitch drop.
static func _splat() -> PackedByteArray:
	var n: int = int(SR * 0.3)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / SR
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.18)
		s[i] = (lp * 1.6 + sin(TAU * lerpf(180.0, 70.0, t / 0.3) * t) * 0.4) * exp(-t * 14.0) * 0.8
	return _pack(s)


## A vault: a short whoosh into a soft landing thump.
static func _vault() -> PackedByteArray:
	var n: int = int(SR * 0.35)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / SR
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.35)
		var whoosh: float = lp * sin(PI * clampf(t / 0.22, 0.0, 1.0)) * 0.5
		var thump: float = sin(TAU * 70.0 * (t - 0.24)) * exp(-(t - 0.24) * 30.0) if t >= 0.24 else 0.0
		s[i] = whoosh + thump * 0.8
	return _pack(s)
