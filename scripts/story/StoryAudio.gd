# File: res://scripts/story/StoryAudio.gd
# Meme and horror SFX of the story (spec A2-D9, story spec section 7), synthesized in code from the frozen CineAudio
# statics (_tone, _noise, _mix, _paste, _to_wav) plus small pure helpers below; no recorded sound, no copyrighted melody
# (every tune here is an original few-note figure). `slide_whistle` stays an A1 cue (CineAudio), not duplicated.
#   meme:   boom, sad_trombone, record_scratch, ba_dum_tss, bonk, dun_dun_duun, success_fanfare, toang_sting
#   horror: heartbeat, breath, whisper_bed, violin_screech, music_box, metal_creak, sheep_bleat_distorted, phone_ring_3am,
#           static_burst
# Owner override: user://sfx/<cue>.ogg | .mp3 | .wav (local only, never committed). LOOPS loop (owner files too).
# stream(cue) is main-thread only (static cache); synth(cue) is pure, so warm(cues) builds a list on a WorkerThreadPool task
# and poll() / stream() adopt the results on the main thread (a long cue never stalls a frame: Phase W lesson).
# cue_db(cue): extra gain, -6 dB for horror cues while "Giảm hù dọa" is on (A2-D14).
class_name StoryAudio
extends RefCounted

const SR: int = 22050
const MEME: Array[String] = ["boom", "sad_trombone", "record_scratch", "ba_dum_tss", "bonk", "dun_dun_duun", "success_fanfare", "toang_sting"]
const HORROR: Array[String] = ["heartbeat", "breath", "whisper_bed", "violin_screech", "music_box", "metal_creak",
	"sheep_bleat_distorted", "phone_ring_3am", "static_burst"]
const CUES: Array[String] = MEME + HORROR
## Extra cues used by the story UI only (not owner-facing).
const EXTRA: Array[String] = ["call_hangup"]
const LOOPS: Array[String] = ["heartbeat", "whisper_bed", "music_box", "phone_ring_3am"]
const REDUCED_DB: float = -6.0
## Expected lengths (s) [min, max] of the synthesized cues (tests).
const LENGTHS: Dictionary = {
	"boom": [1.2, 2.0], "sad_trombone": [2.0, 3.2], "record_scratch": [0.4, 1.0], "ba_dum_tss": [1.0, 1.8], "bonk": [0.25, 0.6],
	"dun_dun_duun": [2.2, 3.4], "success_fanfare": [1.4, 2.4], "toang_sting": [1.2, 2.2], "heartbeat": [0.8, 1.2],
	"breath": [2.0, 3.0], "whisper_bed": [5.0, 8.0], "violin_screech": [0.9, 1.6], "music_box": [2.5, 4.0],
	"metal_creak": [1.4, 2.4], "sheep_bleat_distorted": [0.9, 1.6], "phone_ring_3am": [2.5, 3.5], "static_burst": [0.6, 1.2],
	"call_hangup": [1.0, 1.8],
}

static var sfx_dir: String = "user://sfx/"
static var _cache: Dictionary = {}
static var _task: int = -1
static var _box: Dictionary = {}
static var _pending: PackedStringArray = []
static var warm_builds: int = 0


static func is_cue(cue: String) -> bool:
	return cue in CUES or cue in EXTRA


static func is_horror(cue: String) -> bool:
	return cue in HORROR


## Extra volume (dB) of a cue: horror cues -6 dB while "Giảm hù dọa" is on.
static func cue_db(cue: String) -> float:
	return REDUCED_DB if is_horror(cue) and StoryUtil.reduce_scares() else 0.0


## Owner file for a cue (sfx_dir/<cue>.ogg, .mp3, .wav) or "".
static func override_file(cue: String) -> String:
	for ext: String in [".ogg", ".mp3", ".wav"]:
		var p: String = sfx_dir + cue + ext
		if FileAccess.file_exists(p):
			return p
	return ""


## The cue's stream (owner file, else synthesized; cached). Main thread only.
static func stream(cue: String) -> AudioStream:
	poll()
	if _cache.has(cue):
		return _cache[cue]
	if _task >= 0 and cue in _pending:
		WorkerThreadPool.wait_for_task_completion(_task)   # only if asked for before the warm task finished
		_adopt()
		if _cache.has(cue):
			return _cache[cue]
	var st: AudioStream = null
	var f: String = override_file(cue)
	if f != "":
		st = _load_override(f)
	if st == null:
		st = synth(cue)
	_set_loop(st, cue in LOOPS)
	_cache[cue] = st
	return st


## One-shot version for timelines (CineAudio.sfx): a looping cue comes back with the loop off (shared sample data).
static func stream_once(cue: String) -> AudioStream:
	var st: AudioStream = stream(cue)
	if not (cue in LOOPS):
		return st
	var key: String = cue + "#once"
	if _cache.has(key):
		return _cache[key]
	var once: AudioStream = st.duplicate()
	if once is AudioStreamWAV:
		(once as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif once is AudioStreamOggVorbis:
		(once as AudioStreamOggVorbis).loop = false
	elif once is AudioStreamMP3:
		(once as AudioStreamMP3).loop = false
	_cache[key] = once
	return once


static func _load_override(p: String) -> AudioStream:
	if p.ends_with(".wav"):
		return AudioStreamWAV.load_from_file(p)
	return CineAudio._load_file(p)


static func _set_loop(st: AudioStream, on: bool) -> void:
	if not on or st == null:
		return
	if st is AudioStreamWAV:
		var w: AudioStreamWAV = st
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = w.data.size() / 2 if w.format == AudioStreamWAV.FORMAT_16_BITS and not w.stereo else int(w.get_length() * w.mix_rate)
	elif st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	elif st is AudioStreamMP3:
		(st as AudioStreamMP3).loop = true


static func is_cached(cue: String) -> bool:
	return _cache.has(cue)


static func clear_cache() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	_cache.clear()
	_box = {}
	_pending = PackedStringArray()


## Builds the cues that are neither cached nor overridden on a WorkerThreadPool task; returns at once. -1 = nothing to do.
static func warm(cues: Array) -> int:
	poll()
	if _task >= 0:
		return _task
	var todo := PackedStringArray()
	for c: Variant in cues:
		var cue: String = String(c)
		if is_cue(cue) and not _cache.has(cue) and override_file(cue) == "":
			todo.append(cue)
	if todo.is_empty():
		return -1
	_pending = todo
	_box = {}
	_task = WorkerThreadPool.add_task(_warm_job(_box, todo))
	return _task


## Worker job built in a static function: writes only into its own box.
static func _warm_job(box: Dictionary, todo: PackedStringArray) -> Callable:
	return func() -> void:
		for cue: String in todo:
			box[cue] = synth(cue)


## Adopts a finished warm task (main thread). true when nothing is pending any more.
static func poll() -> bool:
	if _task < 0:
		return true
	if not WorkerThreadPool.is_task_completed(_task):
		return false
	WorkerThreadPool.wait_for_task_completion(_task)
	_adopt()
	return true


static func _adopt() -> void:
	_task = -1
	for cue: String in _box.keys():
		if not _cache.has(cue):
			var st: AudioStream = _box[cue]
			_set_loop(st, cue in LOOPS)
			_cache[cue] = st
			warm_builds += 1
	_box = {}
	_pending = PackedStringArray()


static func warm_pending() -> bool:
	return _task >= 0


# ---------------------------------------------------------------------------
# Synthesis (pure: no scene tree, no shared state)
# ---------------------------------------------------------------------------
static func _silence(dur: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(dur * SR))
	return b


## A harmonic voice (sawtooth-like brass / string) with vibrato and an attack / release envelope.
static func _voice(dur: float, f0: float, f1: float, amp: float, harmonics: int, vib_hz: float, vib_depth: float, attack: float, release: float) -> PackedFloat32Array:
	var n: int = int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph: float = 0.0
	for i: int in n:
		var t: float = float(i) / SR
		var f: float = lerpf(f0, f1, t / dur) * (1.0 + vib_depth * sin(TAU * vib_hz * t))
		ph += TAU * f / SR
		var v: float = 0.0
		for h: int in range(1, harmonics + 1):
			v += sin(ph * h) / float(h)
		var env: float = minf(1.0, t / maxf(attack, 0.001)) * minf(1.0, (dur - t) / maxf(release, 0.001))
		out[i] = v * amp * env
	return out


## Soft clip (tanh-like) distortion in place.
static func _drive(buf: PackedFloat32Array, gain: float) -> PackedFloat32Array:
	for i: int in buf.size():
		var x: float = buf[i] * gain
		buf[i] = x / (1.0 + absf(x))
	return buf


## Echo: copies of the buffer at `delay` s, each `fb` quieter, `taps` times (the buffer grows to hold the tail).
static func _echo(buf: PackedFloat32Array, delay: float, fb: float, taps: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(buf.size() + int(delay * SR * taps))
	CineAudio._paste(out, buf, 0.0, 1.0)
	var g: float = 1.0
	for k: int in range(1, taps + 1):
		g *= fb
		CineAudio._paste(out, buf, delay * k, g)
	return out


static func _fade_tail(buf: PackedFloat32Array, dur: float) -> PackedFloat32Array:
	var nf: int = mini(int(dur * SR), buf.size())
	for i: int in nf:
		buf[buf.size() - 1 - i] *= float(i) / float(maxi(nf, 1))
	return buf


static func _note(semi: float, base: float = 261.63) -> float:
	return base * pow(2.0, semi / 12.0)


## The synthesized cue (AudioStreamWAV, mono 22.05 kHz). Unknown cue -> a short beep.
static func synth(cue: String) -> AudioStreamWAV:
	return CineAudio._to_wav(synth_samples(cue))


static func synth_samples(cue: String) -> PackedFloat32Array:
	match cue:
		"boom":   # deep reverb thud
			var thud: PackedFloat32Array = CineAudio._mix([CineAudio._tone(1.0, 72.0, 28.0, 0.95, 3.2), CineAudio._noise(0.35, 0.5, 9.0, 21, 0.92)])
			return _fade_tail(_echo(thud, 0.11, 0.42, 4), 0.25)
		"sad_trombone":   # wah, wah, wah, waaaah (four falling notes, the last one wobbling)
			var b: PackedFloat32Array = _silence(2.6)
			var notes: Array[float] = [-2.0, -3.0, -4.0]
			for k: int in 3:
				var f: float = _note(notes[k], 146.83)
				CineAudio._paste(b, _voice(0.42, f, f * 0.985, 0.32, 6, 5.0, 0.004, 0.04, 0.12), 0.05 + 0.48 * k, 1.0)
			var fl: float = _note(-5.0, 146.83)
			CineAudio._paste(b, _voice(1.05, fl, fl * 0.97, 0.34, 6, 6.5, 0.028, 0.05, 0.35), 1.5, 1.0)
			return b
		"record_scratch":   # back-and-forth scratch: noise with a fast pitch sweep
			var sc: PackedFloat32Array = CineAudio._mix([CineAudio._noise(0.62, 0.55, 3.0, 22, 0.55),
				CineAudio._tone(0.3, 900.0, 240.0, 0.35, 4.0)])
			CineAudio._paste(sc, CineAudio._tone(0.3, 260.0, 1100.0, 0.32, 3.0), 0.3, 1.0)
			return _fade_tail(sc, 0.08)
		"ba_dum_tss":   # two toms and a cymbal
			var bd: PackedFloat32Array = _silence(1.35)
			CineAudio._paste(bd, CineAudio._mix([CineAudio._tone(0.22, 190.0, 120.0, 0.7, 14.0), CineAudio._noise(0.05, 0.3, 60.0, 23, 0.3)]), 0.0, 1.0)
			CineAudio._paste(bd, CineAudio._mix([CineAudio._tone(0.26, 140.0, 85.0, 0.8, 12.0), CineAudio._noise(0.05, 0.3, 60.0, 24, 0.3)]), 0.2, 1.0)
			CineAudio._paste(bd, CineAudio._noise(0.9, 0.42, 4.5, 25, 0.0), 0.44, 1.0)
			return bd
		"bonk":   # hollow wooden knock
			return CineAudio._mix([CineAudio._tone(0.34, 620.0, 380.0, 0.6, 16.0), CineAudio._tone(0.2, 1480.0, 1100.0, 0.25, 26.0),
				CineAudio._noise(0.03, 0.4, 90.0, 26, 0.2)])
		"dun_dun_duun":   # dramatic brass stabs: two short, one long with a tremolo
			var dd: PackedFloat32Array = _silence(2.9)
			for k: int in 2:
				CineAudio._paste(dd, CineAudio._mix([_voice(0.34, 98.0, 98.0, 0.3, 7, 0.0, 0.0, 0.01, 0.1), _voice(0.34, 146.8, 146.8, 0.2, 7, 0.0, 0.0, 0.01, 0.1)]), 0.45 * k, 1.0)
			CineAudio._paste(dd, CineAudio._mix([_voice(1.9, 92.5, 90.0, 0.32, 7, 5.5, 0.01, 0.02, 0.8), _voice(1.9, 138.6, 135.0, 0.2, 7, 5.5, 0.01, 0.02, 0.8),
				CineAudio._tone(1.9, 46.0, 44.0, 0.4, 1.2)]), 0.92, 1.0)
			return dd
		"success_fanfare":   # rising major arpeggio and a held chord
			var sf: PackedFloat32Array = _silence(1.9)
			var arp: Array[float] = [0.0, 4.0, 7.0, 12.0]
			for k: int in 4:
				CineAudio._paste(sf, _voice(0.2, _note(arp[k], 523.25), _note(arp[k], 523.25), 0.22, 4, 0.0, 0.0, 0.01, 0.06), 0.13 * k, 1.0)
			for semi: float in [0.0, 4.0, 7.0]:
				CineAudio._paste(sf, _voice(1.2, _note(semi, 523.25), _note(semi, 523.25), 0.14, 4, 5.0, 0.004, 0.03, 0.5), 0.55, 1.0)
			return sf
		"toang_sting":   # stamp slam, a falling dissonant pair and a crash
			var ts: PackedFloat32Array = CineAudio._mix([CineAudio._tone(0.5, 110.0, 40.0, 0.9, 7.0), CineAudio._noise(0.15, 0.7, 25.0, 27, 0.3)])
			var tail: PackedFloat32Array = _silence(1.7)
			CineAudio._paste(tail, ts, 0.0, 1.0)
			CineAudio._paste(tail, _voice(1.3, 330.0, 180.0, 0.16, 5, 6.0, 0.02, 0.02, 0.5), 0.1, 1.0)
			CineAudio._paste(tail, _voice(1.3, 349.0, 190.0, 0.14, 5, 6.5, 0.02, 0.02, 0.5), 0.1, 1.0)
			CineAudio._paste(tail, CineAudio._noise(1.2, 0.28, 3.0, 28, 0.1), 0.05, 1.0)
			return tail
		"heartbeat":   # lub-dub, 0.9 s period (loops)
			var hb: PackedFloat32Array = _silence(0.9)
			CineAudio._paste(hb, CineAudio._tone(0.16, 62.0, 44.0, 0.9, 16.0), 0.0, 1.0)
			CineAudio._paste(hb, CineAudio._tone(0.14, 56.0, 40.0, 0.7, 18.0), 0.26, 1.0)
			return hb
		"breath":   # two shaky breaths (filtered noise in and out)
			var br: PackedFloat32Array = _silence(2.5)
			for k: int in 2:
				var nz: PackedFloat32Array = CineAudio._noise(1.0, 0.32, 0.0, 29 + k, 0.82)
				for i: int in nz.size():
					var u: float = float(i) / nz.size()
					nz[i] *= sin(PI * u) * (0.75 + 0.25 * sin(TAU * 7.0 * u))
				CineAudio._paste(br, nz, 0.15 + 1.15 * k, 1.0)
			return br
		"whisper_bed":   # breathy band noise swelling like murmurs over a faint drone (loops: 6 s, ends where it starts)
			var dur: float = 6.0
			var wb: PackedFloat32Array = CineAudio._noise(dur, 0.22, 0.0, 31, 0.55)
			var hi: PackedFloat32Array = CineAudio._noise(dur, 0.18, 0.0, 32, 0.0)
			var drone: PackedFloat32Array = CineAudio._mix([CineAudio._tone(dur, 55.0, 55.0, 0.08, 0.0), CineAudio._tone(dur, 82.4, 82.4, 0.05, 0.0)])
			for i: int in wb.size():
				var t: float = float(i) / SR
				var syl: float = maxf(0.0, sin(TAU * 2.0 / 3.0 * t * 2.0)) * (0.5 + 0.5 * sin(TAU * t / 6.0 * 3.0))
				wb[i] = (wb[i] - hi[i] * 0.6) * syl + drone[i]
			return wb
		"violin_screech":   # harsh high string stab with a fast wide vibrato
			var vs: PackedFloat32Array = CineAudio._mix([_voice(1.2, 1850.0, 2350.0, 0.2, 6, 11.0, 0.03, 0.005, 0.4),
				_voice(1.2, 1960.0, 2480.0, 0.16, 6, 12.5, 0.035, 0.005, 0.4), CineAudio._noise(1.2, 0.08, 2.0, 33, 0.0)])
			return _drive(vs, 1.6)
		"music_box":   # original eight-note minor figure, plucked (loops)
			var mb: PackedFloat32Array = _silence(3.2)
			var mel: Array[float] = [0.0, 3.0, 7.0, 12.0, 10.0, 7.0, 8.0, 3.0]
			for k: int in mel.size():
				var f: float = _note(mel[k], 659.25)
				CineAudio._paste(mb, CineAudio._mix([CineAudio._tone(0.6, f, f, 0.22, 5.0), CineAudio._tone(0.4, f * 3.0, f * 3.0, 0.05, 9.0)]), 0.4 * k, 1.0)
			return mb
		"metal_creak":   # slow grinding wobble of a door hinge
			var n: int = int(1.8 * SR)
			var mc := PackedFloat32Array()
			mc.resize(n)
			var rng := RandomNumberGenerator.new()
			rng.seed = 34
			var ph: float = 0.0
			for i: int in n:
				var t: float = float(i) / SR
				var f: float = 130.0 + 45.0 * sin(TAU * 0.7 * t) + rng.randf_range(-18.0, 18.0)
				ph += TAU * f / SR
				var grain: float = 1.0 if fmod(t * 38.0, 1.0) < 0.55 else 0.35
				mc[i] = (sin(ph) + 0.5 * sin(ph * 2.0) + 0.33 * sin(ph * 3.0)) * 0.22 * grain * minf(1.0, t * 6.0) * minf(1.0, (1.8 - t) * 3.0)
			return mc
		"sheep_bleat_distorted":   # "baa" with a goat-like vibrato, pitched down and overdriven
			var sb: PackedFloat32Array = _voice(1.25, 310.0, 240.0, 0.35, 8, 8.5, 0.07, 0.04, 0.4)
			return _drive(sb, 3.0)
		"phone_ring_3am":   # old-phone ring, slightly detuned: 1.6 s ring, 1.4 s silence (loops)
			var pr: PackedFloat32Array = _silence(3.0)
			var ring: PackedFloat32Array = CineAudio._mix([CineAudio._tone(1.6, 440.0, 436.0, 0.22, 0.0), CineAudio._tone(1.6, 480.0, 474.0, 0.22, 0.0)])
			for i: int in ring.size():
				var t: float = float(i) / SR
				ring[i] *= (0.55 + 0.45 * signf(sin(TAU * 20.0 * t))) * minf(1.0, t * 40.0) * minf(1.0, (1.6 - t) * 40.0)
			CineAudio._paste(pr, ring, 0.0, 1.0)
			return pr
		"static_burst":   # radio static with crackles
			var st: PackedFloat32Array = CineAudio._noise(0.9, 0.45, 1.5, 35, 0.0)
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = 36
			for k: int in 14:
				CineAudio._paste(st, CineAudio._noise(0.012, 0.9, 200.0, 37 + k, 0.0), rng2.randf_range(0.0, 0.85), 1.0)
			return _fade_tail(st, 0.15)
		"call_hangup":   # three busy beeps after the line goes dead
			var hu: PackedFloat32Array = _silence(1.4)
			for k: int in 3:
				CineAudio._paste(hu, CineAudio._mix([CineAudio._tone(0.25, 480.0, 480.0, 0.2, 0.0), CineAudio._tone(0.25, 620.0, 620.0, 0.2, 0.0)]), 0.45 * k, 1.0)
			return hu
	return CineAudio._tone(0.08, 800.0, 800.0, 0.4, 20.0)
