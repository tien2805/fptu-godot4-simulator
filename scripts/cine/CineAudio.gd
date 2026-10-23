# File: res://scripts/cine/CineAudio.gd
# Cinematic audio (spec A1-D13, A1-D14). Music slots: user://music/<slot>.ogg, then .mp3 (owner files, outside the project:
# never committed or exported); without a file a cue is synthesized offline to the exact real length with accents on the
# timeline's real impact times. A longer file fades to silence over the last 0.5 s (music_gain). SFX: user://sfx/<cue>.ogg
# overrides, otherwise the synthesized A1 cues below. Synthesis pastes short precomputed voice tables into one buffer so a
# 25 s cue costs about a million sample adds.
# Threading: synth_cue / synth_sting and the helpers they call are pure (no scene tree, no nodes, no shared mutable state), so
# CinePlayer may run them on a WorkerThreadPool task. sfx() keeps a static cache and is main-thread only.
class_name CineAudio
extends RefCounted

const MUSIC_DIR: String = "user://music/"
const SFX_DIR: String = "user://sfx/"
const SR: int = 22050
const FADE_OUT: float = 0.5
const SFX_CUES: Array[String] = ["impact_light", "impact_medium", "impact_heavy", "whoosh_down", "freeze_tick", "crate_smash",
	"body_fall", "slide_whistle", "groan", "phone_buzz"]
const MOODS: Dictionary = {
	"punchy": {"bpm": 118.0, "root": 55.0, "minor": true},
	"heavy": {"bpm": 96.0, "root": 49.0, "minor": true},
	"playful": {"bpm": 124.0, "root": 65.4, "minor": false},
	"eerie": {"bpm": 84.0, "root": 46.2, "minor": true},
}
static var _sfx_cache: Dictionary = {}


static func music_file(slot: String) -> String:
	for ext: String in [".ogg", ".mp3"]:
		var p: String = MUSIC_DIR + slot + ext
		if FileAccess.file_exists(p):
			return p
	return ""


static func load_music(slot: String) -> AudioStream:
	var p: String = music_file(slot)
	if p == "":
		return null
	return _load_file(p)


static func _load_file(p: String) -> AudioStream:
	if p.ends_with(".ogg"):
		return AudioStreamOggVorbis.load_from_file(p)
	if p.ends_with(".mp3"):
		var s := AudioStreamMP3.new()
		s.data = FileAccess.get_file_as_bytes(p)
		return s if s.data.size() > 0 else null
	return null


static func stream_length(st: AudioStream) -> float:
	return st.get_length() if st else 0.0


## Music volume (linear) at real time r for a cinematic of `length` s and a stream of stream_len s (A1-D13).
static func music_gain(r: float, length: float, stream_len: float) -> float:
	if stream_len <= length + 1e-6:
		return 1.0
	if r >= length:
		return 0.0
	return clampf((length - r) / FADE_OUT, 0.0, 1.0)


# ---------------------------------------------------------------------------
# Synthesis helpers
# ---------------------------------------------------------------------------
static func _tone(dur: float, f0: float, f1: float, amp: float, decay: float) -> PackedFloat32Array:
	var n: int = int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph: float = 0.0
	for i: int in n:
		var t: float = float(i) / SR
		var f: float = lerpf(f0, f1, t / dur)
		ph += TAU * f / SR
		out[i] = sin(ph) * amp * exp(-decay * t)
	return out


static func _noise(dur: float, amp: float, decay: float, rng_seed: int, lp: float = 0.0) -> PackedFloat32Array:
	var n: int = int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var prev: float = 0.0
	for i: int in n:
		var v: float = rng.randf_range(-1.0, 1.0)
		prev = lerpf(v, prev, lp)
		out[i] = prev * amp * exp(-decay * float(i) / SR)
	return out


static func _paste(buf: PackedFloat32Array, voice: PackedFloat32Array, at: float, gain: float) -> void:
	var o: int = int(at * SR)
	var n: int = mini(voice.size(), buf.size() - o)
	for i: int in range(maxi(0, -o), n):
		buf[o + i] += voice[i] * gain


static func _to_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i: int in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = data
	return w


static func _in_windows(t: float, hits: Array[Dictionary]) -> bool:
	for h: Dictionary in hits:
		if t >= float(h.get("r_start", h["r"])) and t <= float(h.get("r_end", h["r"])):
			return true
	return false


## Default cue for a slot: tempo grid (kick + bass + hats, ducked to 40 % inside slow-motion windows), 0.3 s riser before
## heavy/finisher impacts, a boom + noise burst on every impact, a tick on every freeze, an outro hit when the 1x tail starts,
## FADE_OUT at the end. Exactly `length` seconds.
static func synth_cue(length: float, hits: Array[Dictionary], mood: String = "punchy") -> AudioStreamWAV:
	var m: Dictionary = MOODS.get(mood, MOODS["punchy"])
	var buf := PackedFloat32Array()
	buf.resize(int(round(length * SR)))
	var beat: float = 60.0 / float(m["bpm"])
	var kick: PackedFloat32Array = _tone(0.22, 120.0, 45.0, 0.55, 14.0)
	var hat: PackedFloat32Array = _noise(0.03, 0.12, 90.0, 7, 0.0)
	var degrees: Array[int] = [0, 0, 3 if bool(m["minor"]) else 4, 5, 7, 5, 3 if bool(m["minor"]) else 4, 0]
	var bass: Dictionary = {}
	for d: int in degrees:
		if not bass.has(d):
			bass[d] = _tone(beat * 0.45, float(m["root"]) * pow(2.0, d / 12.0), float(m["root"]) * pow(2.0, d / 12.0), 0.22, 3.0)
	var t: float = 0.0
	var step: int = 0
	while t < length:
		var g: float = 0.4 if _in_windows(t, hits) else 1.0
		if step % 2 == 0:
			_paste(buf, kick, t, g)
		_paste(buf, bass[degrees[(step >> 1) % degrees.size()]], t, g)
		_paste(buf, hat, t + beat * 0.25, g * 0.8)
		t += beat * 0.5
		step += 1
	var boom: PackedFloat32Array = _tone(0.6, 90.0, 40.0, 0.9, 6.0)
	var burst: PackedFloat32Array = _noise(0.12, 0.6, 30.0, 11, 0.2)
	var tick: PackedFloat32Array = _tone(0.05, 2400.0, 2200.0, 0.35, 60.0)
	var riser: PackedFloat32Array = _noise(0.3, 0.25, -6.0, 13, 0.6)
	var last_end: float = 0.0
	for h: Dictionary in hits:
		var r: float = h["r"]
		var pre: String = h.get("preset", "medium")
		var g2: float = {"light": 0.45, "medium": 0.7, "heavy": 1.0, "finisher": 1.0, "accent": 0.3}.get(pre, 0.7)
		if pre == "heavy" or pre == "finisher":
			_paste(buf, riser, r - 0.3, 1.0)
		_paste(buf, boom, r, g2)
		_paste(buf, burst, r, g2)
		if float(h.get("freeze", 0.0)) > 0.0:
			_paste(buf, tick, r, 1.0)
		last_end = maxf(last_end, float(h.get("r_end", r)))
	if last_end > 0.0 and last_end < length - 0.2:
		_paste(buf, boom, last_end, 0.6)
	var nf: int = mini(int(FADE_OUT * SR), buf.size())
	for i: int in nf:
		buf[buf.size() - 1 - i] *= float(i) / float(nf)
	return _to_wav(buf)


## Short replay sting: the cue's voices for `length` s with one heavy impact at r_hit.
static func synth_sting(length: float, r_hit: float) -> AudioStreamWAV:
	var hits: Array[Dictionary] = [{"r": r_hit, "preset": "heavy", "freeze": 0.18, "r_start": r_hit - 0.45, "r_end": r_hit + 1.28}]
	return synth_cue(length, hits, "punchy")


## A1 SFX cue: user://sfx/<cue>.ogg if present, else synthesized (cached).
static func sfx(cue: String) -> AudioStream:
	if _sfx_cache.has(cue):
		return _sfx_cache[cue]
	var st: AudioStream = null
	if FileAccess.file_exists(SFX_DIR + cue + ".ogg"):
		st = _load_file(SFX_DIR + cue + ".ogg")
	if st == null:
		st = _synth_sfx(cue)
	_sfx_cache[cue] = st
	return st


static func _mix(parts: Array) -> PackedFloat32Array:
	var n: int = 0
	for p: PackedFloat32Array in parts:
		n = maxi(n, p.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for p2: PackedFloat32Array in parts:
		for i: int in p2.size():
			out[i] += p2[i]
	return out


static func _synth_sfx(cue: String) -> AudioStreamWAV:
	match cue:
		"impact_light":
			return _to_wav(_mix([_noise(0.08, 0.6, 45.0, 1, 0.3), _tone(0.1, 220.0, 140.0, 0.4, 25.0)]))
		"impact_medium":
			return _to_wav(_mix([_noise(0.14, 0.7, 30.0, 2, 0.4), _tone(0.2, 160.0, 70.0, 0.6, 14.0)]))
		"impact_heavy":
			return _to_wav(_mix([_noise(0.25, 0.8, 16.0, 3, 0.5), _tone(0.5, 110.0, 38.0, 0.9, 6.0)]))
		"whoosh_down":
			return _to_wav(_noise(0.45, 0.4, 4.0, 4, 0.85))
		"freeze_tick":
			return _to_wav(_tone(0.06, 2600.0, 2300.0, 0.4, 50.0))
		"crate_smash":
			return _to_wav(_mix([_noise(0.4, 0.8, 9.0, 5, 0.2), _tone(0.12, 330.0, 180.0, 0.3, 20.0), _tone(0.2, 90.0, 60.0, 0.5, 12.0)]))
		"body_fall":
			return _to_wav(_mix([_tone(0.3, 80.0, 45.0, 0.8, 10.0), _noise(0.1, 0.4, 35.0, 6, 0.6)]))
		"slide_whistle":
			return _to_wav(_tone(0.9, 600.0, 1500.0, 0.35, 0.8))
		"groan":
			return _to_wav(_mix([_tone(0.8, 140.0, 105.0, 0.35, 1.5), _tone(0.8, 280.0, 210.0, 0.12, 1.5)]))
		"phone_buzz":
			var gap := PackedFloat32Array()
			gap.resize(int(0.1 * SR))
			var b := PackedFloat32Array()
			for i: int in 2:
				b.append_array(_tone(0.18, 175.0, 175.0, 0.5, 0.0))
				b.append_array(gap)
			return _to_wav(b)
	return _to_wav(_tone(0.08, 800.0, 800.0, 0.4, 20.0))
