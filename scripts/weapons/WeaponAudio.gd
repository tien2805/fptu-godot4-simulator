# File: res://scripts/weapons/WeaponAudio.gd
# Phase W sound cues, synthesized in code with the A1 voice helpers (CineAudio._tone / _noise / _mix / _paste / _to_wav).
# Any cue can be overridden by the owner's user://sfx/<cue>.ogg (local only: never committed, never exported). The loa kẹo
# kéo music (W-D5) is the owner's user://sfx/loa_keo_keo.ogg or .mp3 when present, otherwise the synthesized "bolero" cue
# (Task 6). Main thread only (static cache). Each task adds its cues to CUES and to synth().
class_name WeaponAudio
extends RefCounted

const SFX_DIR: String = "user://sfx/"
const LOA_FILE: String = "loa_keo_keo"
const SIUUU_FILE: String = "siuuu"
## Fixed layout of every siuuu cue (synthesized or the owner's file, spec section 9): "S" from SIUUU_S, the vowel burst (the
## loudest instant) at SIUUU_BURST, the vowel sustained to SIUUU_END, a soft tail to SIUUU_LEN.
const SIUUU_S: float = 0.25
const SIUUU_BURST: float = 0.31
const SIUUU_END: float = 1.57
const SIUUU_LEN: float = 2.0
## Where owner overrides are looked up (user://sfx/); tests point it at an empty folder so they never depend on his files.
static var sfx_dir: String = SFX_DIR
const CUES: Array[String] = ["punch", "swish", "knife_hit", "reload", "dry_click", "shot_pistol", "shot_shotgun", "pump", "ricochet",
	"rocket_launch", "explosion", "bonk", "dep_whoosh", "durian_pop", "cough", "bolero", "bag_drop", "siuuu"]
const BOLERO_BPM: float = 96.0
const BOLERO_ROOT: float = 110.0         # A2
static var _cache: Dictionary = {}


static func bus() -> StringName:
	return &"SFX" if AudioServer.get_bus_index("SFX") >= 0 else &"Master"


## The owner's override file of a cue ("" when there is none).
static func override_file(cue: String) -> String:
	var p: String = sfx_dir + cue + ".ogg"
	return p if FileAccess.file_exists(p) else ""


static func stream(cue: String) -> AudioStream:
	if _cache.has(cue):
		return _cache[cue]
	var st: AudioStream = null
	var f: String = override_file(cue)
	if f != "":
		st = CineAudio._load_file(f)
	if st == null:
		st = synth(cue)
	_cache[cue] = st
	return st


static func _gap(secs: float) -> PackedFloat32Array:
	var g := PackedFloat32Array()
	g.resize(int(secs * CineAudio.SR))
	return g


## Synthesized cue (pure: no cache, no scene tree).
static func synth(cue: String) -> AudioStreamWAV:
	match cue:
		"punch":
			return CineAudio._to_wav(CineAudio._mix([CineAudio._noise(0.07, 0.7, 50.0, 21, 0.45), CineAudio._tone(0.12, 180.0, 90.0, 0.6, 22.0)]))
		"swish":
			return CineAudio._to_wav(CineAudio._noise(0.22, 0.35, 10.0, 22, 0.8))
		"knife_hit":
			return CineAudio._to_wav(CineAudio._mix([CineAudio._noise(0.05, 0.5, 70.0, 23, 0.2), CineAudio._tone(0.18, 1400.0, 900.0, 0.18, 18.0), CineAudio._tone(0.1, 160.0, 90.0, 0.4, 25.0)]))
		"reload":
			var a: PackedFloat32Array = CineAudio._mix([CineAudio._noise(0.04, 0.6, 90.0, 24, 0.1), CineAudio._tone(0.04, 2200.0, 1800.0, 0.3, 80.0)])
			a.append_array(_gap(0.18))
			a.append_array(CineAudio._mix([CineAudio._noise(0.05, 0.7, 80.0, 25, 0.1), CineAudio._tone(0.05, 1600.0, 1300.0, 0.35, 70.0)]))
			return CineAudio._to_wav(a)
		"dry_click":
			return CineAudio._to_wav(CineAudio._tone(0.03, 3000.0, 2600.0, 0.3, 120.0))
		"shot_pistol":
			return CineAudio._to_wav(CineAudio._mix([CineAudio._noise(0.18, 0.9, 22.0, 31, 0.15), CineAudio._tone(0.12, 220.0, 70.0, 0.7, 20.0)]))
		"shot_shotgun":
			return CineAudio._to_wav(CineAudio._mix([CineAudio._noise(0.42, 1.0, 9.0, 32, 0.3), CineAudio._tone(0.3, 120.0, 40.0, 0.9, 9.0)]))
		"pump":
			var p: PackedFloat32Array = CineAudio._mix([CineAudio._noise(0.06, 0.7, 60.0, 33, 0.2), CineAudio._tone(0.05, 900.0, 700.0, 0.3, 50.0)])
			p.append_array(_gap(0.12))
			p.append_array(CineAudio._mix([CineAudio._noise(0.07, 0.8, 55.0, 34, 0.2), CineAudio._tone(0.06, 700.0, 520.0, 0.35, 45.0)]))
			return CineAudio._to_wav(p)
		"ricochet":
			return CineAudio._to_wav(CineAudio._tone(0.35, 2600.0, 900.0, 0.25, 7.0))
		"rocket_launch":
			return CineAudio._to_wav(CineAudio._mix([CineAudio._noise(0.6, 0.6, 3.5, 41, 0.7), CineAudio._tone(0.25, 300.0, 120.0, 0.5, 10.0)]))
		"explosion":
			return CineAudio._to_wav(CineAudio._mix([CineAudio._noise(1.4, 1.0, 3.0, 42, 0.55), CineAudio._tone(0.9, 80.0, 30.0, 1.0, 4.0), CineAudio._noise(0.12, 0.8, 30.0, 43, 0.1)]))
		"bonk":
			return CineAudio._to_wav(CineAudio._mix([CineAudio._tone(0.25, 520.0, 260.0, 0.6, 12.0), CineAudio._tone(0.25, 1040.0, 700.0, 0.15, 16.0)]))
		"dep_whoosh":
			return CineAudio._to_wav(CineAudio._noise(0.35, 0.3, 6.0, 52, 0.85))
		"durian_pop":
			return CineAudio._to_wav(CineAudio._mix([CineAudio._noise(0.5, 0.6, 6.0, 53, 0.7), CineAudio._tone(0.2, 140.0, 90.0, 0.5, 10.0)]))
		"cough":
			var c: PackedFloat32Array = CineAudio._mix([CineAudio._noise(0.12, 0.5, 18.0, 54, 0.5), CineAudio._tone(0.12, 210.0, 170.0, 0.2, 14.0)])
			c.append_array(_gap(0.1))
			c.append_array(CineAudio._mix([CineAudio._noise(0.1, 0.45, 20.0, 55, 0.5), CineAudio._tone(0.1, 200.0, 160.0, 0.18, 15.0)]))
			return CineAudio._to_wav(c)
		"bolero":
			return synth_bolero()
		"bag_drop":
			return CineAudio._to_wav(CineAudio._mix([CineAudio._tone(0.25, 95.0, 55.0, 0.7, 12.0), CineAudio._noise(0.12, 0.45, 30.0, 61, 0.6)]))
		"siuuu":
			return synth_siuuu()
	return CineAudio._to_wav(CineAudio._tone(0.08, 800.0, 800.0, 0.3, 20.0))


static func _hz(semi: int) -> float:
	return BOLERO_ROOT * pow(2.0, float(semi) / 12.0)


## One cached voice (bass / pluck / pad) per semitone, so the loop pastes a handful of precomputed tables.
static func _voice(cache: Dictionary, kind: String, semi: int, dur: float) -> PackedFloat32Array:
	var key: String = "%s%d" % [kind, semi]
	if not cache.has(key):
		var f: float = _hz(semi)
		match kind:
			"bass":
				cache[key] = CineAudio._tone(dur, f, f, 0.3, 2.5)
			"pluck":
				cache[key] = CineAudio._mix([CineAudio._tone(dur, f, f, 0.16, 6.0), CineAudio._tone(dur, f * 2.0, f * 2.0, 0.06, 9.0)])
			_:
				cache[key] = CineAudio._mix([CineAudio._tone(dur, f, f, 0.05, 0.4), CineAudio._tone(dur, f * 1.5, f * 1.5, 0.03, 0.4)])
	return cache[key]


## Synthesized slow bolero groove for the loa kẹo kéo (W-D5 default; a genre pattern, not any real song): 4 bars of 4/4 at
## BOLERO_BPM over the minor progression i - iv - V7 - i in A minor; the bolero bass rhythm (beat 1, the "and" of 2, beats
## 3 and 4: root / fifth), a plucked arpeggio of the chord tones on every eighth, a soft pad and rim ticks on the accents.
## Tails that run past the end are folded back to the start, so the 10 s buffer loops seamlessly (LOOP_FORWARD).
static func synth_bolero() -> AudioStreamWAV:
	var beat: float = 60.0 / BOLERO_BPM
	var bar: float = beat * 4.0
	var n_loop: int = int(round(bar * 4.0 * CineAudio.SR))
	var buf := PackedFloat32Array()
	buf.resize(n_loop + int(2.0 * CineAudio.SR))
	var chords: Array = [[0, 3, 7], [5, 8, 12], [7, 11, 14, 17], [0, 3, 7]]
	var roots: Array[int] = [0, 5, 7, 0]
	var cache: Dictionary = {}
	var tick: PackedFloat32Array = CineAudio._noise(0.03, 0.18, 80.0, 51, 0.2)
	for b: int in 4:
		var t0: float = float(b) * bar
		var ch: Array = chords[b]
		for e: Array in [[0.0, 0], [1.5, 7], [2.0, 0], [3.0, 7]]:
			CineAudio._paste(buf, _voice(cache, "bass", roots[b] + int(e[1]) - 12, beat * 0.9), t0 + float(e[0]) * beat, 1.0)
		for k: int in 8:
			var semi: int = int(ch[k % ch.size()]) + (12 if k >= 4 else 0) + 12
			CineAudio._paste(buf, _voice(cache, "pluck", semi, beat * 0.8), t0 + float(k) * beat * 0.5, 1.0)
		for s2: Variant in ch:
			CineAudio._paste(buf, _voice(cache, "pad", int(s2) + 12, bar), t0, 1.0)
		for x: float in [0.0, 1.5, 2.5, 3.0]:
			CineAudio._paste(buf, tick, t0 + x * beat, 1.0)
	for i: int in range(buf.size() - n_loop):
		buf[i] += buf[n_loop + i]
	buf.resize(n_loop)
	var w: AudioStreamWAV = CineAudio._to_wav(buf)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n_loop
	return w


## Loa kẹo kéo music (W-D5): the owner's user://sfx/loa_keo_keo.ogg or .mp3 (local only, never committed or exported),
## looping; otherwise the synthesized bolero cue (any user://sfx/bolero.ogg override applies to it).
static func loa_stream() -> AudioStream:
	if _cache.has("@loa"):
		return _cache["@loa"]
	var st: AudioStream = null
	var f: String = loa_file()
	if f != "":
		st = CineAudio._load_file(f)
		if st is AudioStreamOggVorbis:
			(st as AudioStreamOggVorbis).loop = true
		elif st is AudioStreamMP3:
			(st as AudioStreamMP3).loop = true
	if st == null:
		st = stream("bolero")
	_cache["@loa"] = st
	return st


## The owner's loa file ("" = none: the synthesized bolero plays).
static func loa_file() -> String:
	return owner_file(LOA_FILE)


## The owner's local file sfx_dir/<name>.ogg or .mp3 ("" when there is none).
static func owner_file(file_name: String) -> String:
	for ext: String in [".ogg", ".mp3"]:
		var p: String = sfx_dir + file_name + ext
		if FileAccess.file_exists(p):
			return p
	return ""


static func clear_cache() -> void:
	_cache.clear()


## The owner's siuuu file (W-D12, trimmed to the fixed layout) or "".
static func siuuu_file() -> String:
	return owner_file(SIUUU_FILE)


## The "Siuuu!" shout: the owner's local file when present, else the synthesized cue (same layout either way).
static func siuuu_stream() -> AudioStream:
	if _cache.has("@siuuu"):
		return _cache["@siuuu"]
	var st: AudioStream = null
	var f: String = siuuu_file()
	if f != "":
		st = CineAudio._load_file(f)
	if st == null:
		st = synth_siuuu()
	_cache["@siuuu"] = st
	return st


## Synthesized "Siuuu" on the fixed layout (no recording of any real person, W-D11/W-D12): silence, a bright noise "S" from
## SIUUU_S swelling into the vowel; at SIUUU_BURST a sharp attack into a voiced tone gliding from "i" (bright upper
## harmonics) to a long "uuu" (dark), slight vibrato, fading out by SIUUU_END; a soft crowd-like noise tail to SIUUU_LEN.
static func synth_siuuu() -> AudioStreamWAV:
	var sr: int = CineAudio.SR
	var buf := PackedFloat32Array()
	buf.resize(int(round(SIUUU_LEN * sr)))
	var s_noise: PackedFloat32Array = CineAudio._noise(SIUUU_BURST - SIUUU_S, 0.35, 0.0, 71, 0.0)
	for i: int in s_noise.size():
		s_noise[i] *= 0.4 + 0.6 * float(i) / float(s_noise.size())
	CineAudio._paste(buf, s_noise, SIUUU_S, 1.0)
	var a0: int = int(SIUUU_BURST * sr)
	var a1: int = int(SIUUU_END * sr)
	var dur: float = SIUUU_END - SIUUU_BURST
	var ph: float = 0.0
	for i2: int in range(a0, a1):
		var tt: float = float(i2 - a0) / float(sr)
		var u: float = tt / dur
		var f: float = lerpf(330.0, 230.0, smoothstep(0.0, 0.35, u)) * (1.0 + 0.025 * sin(TAU * 5.5 * tt) * smoothstep(0.1, 0.4, u))
		ph += TAU * f / float(sr)
		var bright: float = 1.0 - smoothstep(0.0, 0.3, u)
		var v: float = sin(ph) + (0.45 * bright + 0.12) * sin(2.0 * ph) + (0.3 * bright + 0.05) * sin(3.0 * ph)
		var env: float = minf(1.0, tt / 0.006) * (1.0 - 0.35 * u) * (1.0 - smoothstep(0.85, 1.0, u))
		buf[i2] += v * 0.42 * env
	var crowd: PackedFloat32Array = CineAudio._noise(SIUUU_LEN - 1.2, 0.08, 0.0, 72, 0.85)
	for i3: int in crowd.size():
		var u2: float = float(i3) / float(crowd.size())
		crowd[i3] *= smoothstep(0.0, 0.3, u2) * (1.0 - smoothstep(0.5, 1.0, u2))
	CineAudio._paste(buf, crowd, 1.2, 1.0)
	return CineAudio._to_wav(buf)
