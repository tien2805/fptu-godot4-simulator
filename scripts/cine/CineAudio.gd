# File: res://scripts/cine/CineAudio.gd
# Cinematic audio (spec A1-D13, A1-D14, H-D8). Music slots: user://music/<slot>.ogg, then .mp3 (owner files, outside the
# project: never committed or exported); without a file the cinematic plays without music (no code music, H-D8). A longer
# file fades to silence over the last 0.5 s (music_gain). SFX: user://sfx/<cue>.ogg overrides, otherwise the synthesized A1
# cues below (sound effects, not music). Synthesis pastes short precomputed voice tables into one buffer.
# Threading: the voice helpers (_tone, _noise, _paste, _mix, _to_wav) are pure (no scene tree, no shared mutable state).
# sfx() keeps a static cache and is main-thread only.
class_name CineAudio
extends RefCounted

const MUSIC_DIR: String = "user://music/"
const SFX_DIR: String = "user://sfx/"
const SR: int = 22050
const FADE_OUT: float = 0.5
const SFX_CUES: Array[String] = ["impact_light", "impact_medium", "impact_heavy", "whoosh_down", "freeze_tick", "crate_smash",
	"body_fall", "slide_whistle", "groan", "phone_buzz", "engine_roar", "neck_crack", "helmet_clonk",
	# story Phase B: canteen brawl and Day 1 / Day 4 discovery beats
	"tray_clang", "pot_clonk", "chair_smash", "burp", "fluoro_buzz",
	# story Phase C: Days 2, 3, 5 (synthesized SFX; the ringtone is a phone ringtone, not music: spec C-D6)
	"party_horn", "wolf_howl", "ringtone_synth", "door_bang", "keyboard_clack", "glass_crack", "sword_clang", "blade_snap",
	"fire_crackle", "evil_laugh", "applause", "chain_rattle"]
static var _sfx_cache: Dictionary = {}


## A slot without its own owner file plays its parent slot's file (then silence): the choice tails reuse cine_d1_choice.
const SLOT_FALLBACK: Dictionary = {"cine_d1_choice_cover": "cine_d1_choice", "cine_d1_choice_report": "cine_d1_choice",
	"cine_d5_choice_accept": "cine_d5_choice", "cine_d5_choice_refuse": "cine_d5_choice"}


static func music_file(slot: String) -> String:
	for ext: String in [".ogg", ".mp3"]:
		var p: String = MUSIC_DIR + slot + ext
		if FileAccess.file_exists(p):
			return p
	if SLOT_FALLBACK.has(slot):
		return music_file(String(SLOT_FALLBACK[slot]))
	return ""


static func load_music(slot: String) -> AudioStream:
	if MusicDirector.test_streams.has(slot):
		return MusicDirector.test_streams[slot]   # tests only
	var p: String = music_file(slot)
	if p == "":
		return null
	return _load_file(p)


## Shared with Phase W (called by name from its scripts): signature frozen, do not rename.
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
## Shared with Phase W (called by name from its scripts): signature frozen, do not rename.
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


## Shared with Phase W (called by name from its scripts): signature frozen, do not rename.
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


## Shared with Phase W (called by name from its scripts): signature frozen, do not rename.
static func _paste(buf: PackedFloat32Array, voice: PackedFloat32Array, at: float, gain: float) -> void:
	var o: int = int(at * SR)
	var n: int = mini(voice.size(), buf.size() - o)
	for i: int in range(maxi(0, -o), n):
		buf[o + i] += voice[i] * gain


## Shared with Phase W (called by name from its scripts): signature frozen, do not rename.
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


## A1 SFX cue: user://sfx/<cue>.ogg if present, else synthesized (cached).
static func sfx(cue: String) -> AudioStream:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id(), "CineAudio.sfx() is main-thread only (static cache)")
	if StoryAudio.is_cue(cue):
		return StoryAudio.stream_once(cue)   # A2-D9: the story's meme / horror cues (own cache, owner overrides, loops)
	if _sfx_cache.has(cue):
		return _sfx_cache[cue]
	var st: AudioStream = null
	if FileAccess.file_exists(SFX_DIR + cue + ".ogg"):
		st = _load_file(SFX_DIR + cue + ".ogg")
	if st == null:
		st = _synth_sfx(cue)
	_sfx_cache[cue] = st
	return st


## Shared with Phase W (called by name from its scripts): signature frozen, do not rename.
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
		"engine_roar":
			return _to_wav(_engine(1.6))
		"neck_crack":   # two dry knuckle-crack clicks
			var c1: PackedFloat32Array = _mix([_noise(0.03, 0.7, 120.0, 8, 0.1), _tone(0.03, 1900.0, 1500.0, 0.25, 110.0)])
			var pause := PackedFloat32Array()
			pause.resize(int(0.07 * SR))
			var c2: PackedFloat32Array = _mix([_noise(0.03, 0.55, 120.0, 9, 0.1), _tone(0.03, 1700.0, 1300.0, 0.2, 110.0)])
			c1.append_array(pause)
			c1.append_array(c2)
			return _to_wav(c1)
		"tray_clang":   # thin steel tray: bright ringing partials over a short noise hit
			return _to_wav(_mix([_tone(0.6, 1320.0, 1290.0, 0.32, 5.0), _tone(0.6, 2210.0, 2170.0, 0.18, 6.5), _tone(0.5, 3480.0, 3420.0, 0.1, 9.0),
				_noise(0.06, 0.5, 70.0, 12, 0.2)]))
		"pot_clonk":    # empty steel pot on a head: low hollow bong with a long ring
			return _to_wav(_mix([_tone(0.9, 330.0, 318.0, 0.5, 3.5), _tone(0.9, 787.0, 770.0, 0.22, 4.5), _tone(0.3, 140.0, 90.0, 0.35, 14.0),
				_noise(0.05, 0.4, 70.0, 13, 0.3)]))
		"chair_smash":  # plastic chair cracking apart: cracks over a dull body hit
			return _to_wav(_mix([_noise(0.35, 0.75, 10.0, 14, 0.1), _tone(0.18, 260.0, 150.0, 0.35, 16.0), _tone(0.25, 95.0, 60.0, 0.45, 10.0)]))
		"burp":         # a long comic burp: a low wobbling voice with a rough edge
			var bn: int = int(0.75 * SR)
			var bb := PackedFloat32Array()
			bb.resize(bn)
			var ph: float = 0.0
			for i: int in bn:
				var tt: float = float(i) / SR
				var f: float = 92.0 + 18.0 * sin(tt * 23.0) - 30.0 * tt
				ph += TAU * f / SR
				var env: float = smoothstep(0.0, 0.05, tt) * (1.0 - smoothstep(0.55, 0.75, tt))
				bb[i] = (sin(ph) + 0.45 * sin(ph * 2.0) + 0.25 * signf(sin(ph * 3.0))) * 0.3 * env
			return _to_wav(_mix([bb, _noise(0.75, 0.06, 2.0, 15, 0.7)]))
		"fluoro_buzz":  # a tube lamp stuttering: mains buzz chopped on and off
			var fn: int = int(0.8 * SR)
			var fb := PackedFloat32Array()
			fb.resize(fn)
			for i: int in fn:
				var tt2: float = float(i) / SR
				var gate: float = 1.0 if fmod(tt2 * 13.0, 1.0) < 0.55 and fmod(tt2 * 3.0, 1.0) < 0.8 else 0.0
				fb[i] = (sin(TAU * 100.0 * tt2) * 0.3 + sin(TAU * 200.0 * tt2) * 0.15 + sin(TAU * 300.0 * tt2) * 0.08) * gate
			return _to_wav(fb)
		"helmet_clonk": # hollow plastic shell knock
			return _to_wav(_mix([_tone(0.22, 520.0, 430.0, 0.55, 18.0), _tone(0.22, 1180.0, 1010.0, 0.2, 24.0), _noise(0.05, 0.45, 60.0, 10, 0.3)]))
		"party_horn":   # a paper party horn: a buzzy blat that unrolls and wobbles
			return _to_wav(_buzz(0.7, 440.0, 470.0, 0.35, 9.0))
		"wolf_howl":    # a rising, then falling howl (sine glide with vibrato)
			var hn: int = int(1.8 * SR)
			var hw := PackedFloat32Array()
			hw.resize(hn)
			var hp: float = 0.0
			for i: int in hn:
				var ht: float = float(i) / SR
				var hu: float = ht / 1.8
				var hf: float = 330.0 + 260.0 * sin(clampf(hu * 1.6, 0.0, 1.0) * PI * 0.5) - 180.0 * smoothstep(0.6, 1.0, hu) + 6.0 * sin(ht * 31.0)
				hp += TAU * hf / SR
				hw[i] = (sin(hp) + 0.3 * sin(hp * 2.0)) * 0.3 * smoothstep(0.0, 0.15, hu) * (1.0 - smoothstep(0.8, 1.0, hu))
			return _to_wav(hw)
		"ringtone_synth":   # Sói Xám's cheesy synth ringtone: a square-wave arpeggio, twice
			var rb := PackedFloat32Array()
			rb.resize(int(1.7 * SR))
			var notes: Array[float] = [659.0, 784.0, 988.0, 1319.0, 988.0, 784.0]
			for rep2: int in 2:
				for k: int in notes.size():
					_paste(rb, _square(0.11, notes[k], 0.22), 0.85 * rep2 + 0.13 * k, 1.0)
			return _to_wav(rb)
		"door_bang":    # a steel container door slamming open: a low clang with a rattle
			return _to_wav(_mix([_tone(0.9, 120.0, 95.0, 0.6, 4.0), _tone(0.7, 410.0, 395.0, 0.25, 5.0), _noise(0.25, 0.6, 12.0, 21, 0.3)]))
		"keyboard_clack":   # fast typing: a run of short clicks
			var kb := PackedFloat32Array()
			kb.resize(int(0.9 * SR))
			for k2: int in 11:
				_paste(kb, _mix([_noise(0.02, 0.5, 160.0, 30 + k2, 0.1), _tone(0.02, 2400.0 + 90.0 * (k2 % 4), 2000.0, 0.15, 150.0)]), 0.075 * k2 + 0.012 * (k2 % 3), 1.0)
			return _to_wav(kb)
		"glass_crack":  # a mirror cracking: bright noise tick, high ringing shards
			return _to_wav(_mix([_noise(0.12, 0.7, 30.0, 22, 0.0), _tone(0.5, 3100.0, 2900.0, 0.18, 8.0), _tone(0.5, 4300.0, 4100.0, 0.12, 9.0)]))
		"sword_clang":  # steel on steel (or on a wooden staff): a ringing strike
			return _to_wav(_mix([_tone(0.8, 1650.0, 1600.0, 0.35, 4.0), _tone(0.8, 2470.0, 2430.0, 0.2, 5.0), _noise(0.05, 0.6, 80.0, 23, 0.1)]))
		"blade_snap":   # the cheap katana snapping: a sharp crack and a falling ping
			return _to_wav(_mix([_noise(0.06, 0.8, 70.0, 24, 0.0), _tone(0.6, 2200.0, 900.0, 0.3, 4.0)]))
		"fire_crackle": # burning server room: pops over a low roar
			var fc: PackedFloat32Array = _noise(2.0, 0.12, 0.0, 25, 0.95)
			var frng := RandomNumberGenerator.new()
			frng.seed = 26
			for k3: int in 14:
				_paste(fc, _noise(0.02, 0.6, 120.0, 40 + k3, 0.1), frng.randf_range(0.0, 1.95), 1.0)
			return _to_wav(fc)
		"evil_laugh":   # a comic villain laugh on tinny speakers: "ha ha ha" voiced bursts falling in pitch
			var lb := PackedFloat32Array()
			lb.resize(int(1.6 * SR))
			for k4: int in 6:
				_paste(lb, _mix([_buzz(0.16, 260.0 - 14.0 * k4, 220.0 - 14.0 * k4, 0.3, 6.0), _noise(0.16, 0.08, 10.0, 50 + k4, 0.6)]), 0.22 * k4, 1.0)
			return _to_wav(lb)
		"applause":     # a room clapping: many short noise claps
			var ab := PackedFloat32Array()
			ab.resize(int(2.2 * SR))
			var arng := RandomNumberGenerator.new()
			arng.seed = 27
			for k5: int in 90:
				_paste(ab, _noise(0.025, arng.randf_range(0.15, 0.35), 90.0, 60 + k5, 0.2), arng.randf_range(0.0, 2.1) * (1.0 - 0.1 * float(k5 % 3)), 1.0)
			return _to_wav(ab)
		"chain_rattle": # a chain rattling: metal ticks
			var cb := PackedFloat32Array()
			cb.resize(int(0.6 * SR))
			for k6: int in 9:
				_paste(cb, _tone(0.05, 2900.0 + 230.0 * (k6 % 3), 2600.0, 0.18, 60.0), 0.06 * k6, 1.0)
			return _to_wav(cb)
	return _to_wav(_tone(0.08, 800.0, 800.0, 0.4, 20.0))


## Buzzy voice (sawtooth-ish with vibrato): party horn, the tinny laugh.
static func _buzz(dur: float, f0: float, f1: float, amp: float, vib: float) -> PackedFloat32Array:
	var n: int = int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph: float = 0.0
	for i: int in n:
		var t: float = float(i) / SR
		var f: float = lerpf(f0, f1, t / dur) * (1.0 + 0.03 * sin(t * TAU * vib))
		ph += f / SR
		var saw: float = 2.0 * (ph - floor(ph)) - 1.0
		var env: float = smoothstep(0.0, 0.02, t) * (1.0 - smoothstep(dur * 0.8, dur, t))
		out[i] = saw * amp * env
	return out


static func _square(dur: float, f: float, amp: float) -> PackedFloat32Array:
	var n: int = int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var t: float = float(i) / SR
		out[i] = (1.0 if fmod(t * f, 1.0) < 0.5 else -1.0) * amp * (1.0 - t / dur)
	return out


## Distant motorbike engines revving up: two detuned pulsing low voices (firing rate rising) plus filtered noise, faded in
## and out (seg_d1_brawl tail: more couriers coming).
static func _engine(dur: float) -> PackedFloat32Array:
	var n: int = int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var nz: PackedFloat32Array = _noise(dur, 0.12, 0.0, 7, 0.92)
	var ph1: float = 0.0
	var ph2: float = 0.0
	for i: int in n:
		var t: float = float(i) / SR
		var u: float = t / dur
		var f: float = lerpf(38.0, 92.0, smoothstep(0.0, 0.7, u))
		ph1 += TAU * f / SR
		ph2 += TAU * f * 1.51 / SR
		var pulse: float = 0.55 + 0.45 * sin(ph1 * 0.5)
		var env: float = smoothstep(0.0, 0.25, u) * (1.0 - smoothstep(0.75, 1.0, u))
		out[i] = (sin(ph1) * 0.32 + sin(ph2) * 0.16 + nz[i]) * pulse * env
	return out
