# File: res://scripts/cine/DialogueVoice.gd
# Gibberish blip voices for dialogue (master plan 2026-10-29 Q5, plan 2026-10-29-w2-story T2). No recorded or real voice:
# every voice is a synthesized SFX timbre, one per character. Vietnamese is one syllable per word, so a line "speaks" one
# blip per word as the subtitle types out; the blip's pitch contour follows the word's tone mark (ngang flat, sắc rising,
# huyền falling, hỏi / ngã dipping, nặng short and low), which makes the gibberish sound like Vietnamese.
#   PROFILES               voice id -> {wave, f0 (Hz), cps (typing speed, chars / s), blip (s), vib, breath, lp, gain}
#   voice_for(id, name, o) cast id / speaker name (+ actor opts: the protagonist's "female") -> voice id
#   warm(ids)              builds each voice's blip bank on its own WorkerThreadPool task (never blocks); bank(id) adopts
#                          finished tasks on the main thread and returns [] until the bank exists (callers stay silent)
#   blip(id, word)         the blip of `word` (tone contour x one of two pitch steps chosen by the word), null if not built
#   chars_at / fit_cps / word_starts / tone_of / new_words: pure typewriter maths shared by CinePlayer, the radio and
#                          the phone toast
# Buses: callers play blips on "SFX" (cinematics, radio) or "UI" (phone toasts), so the volume sliders apply.
class_name DialogueVoice
extends RefCounted

const SR: int = 22050
const TONES: int = 5            # 0 ngang, 1 sắc, 2 huyền, 3 hỏi / ngã, 4 nặng
const STEPS: Array[float] = [0.0, 3.0]   # semitones: two pitches per tone so repeated tones still vary
const FIT_U: float = 0.75       # a line finishes typing by this fraction of its on-screen duration
const MAX_CPS: float = 60.0
## wave: square | saw | tri | pulse | sine | nasal. f0: base pitch. cps: typing speed. blip: blip length (s).
## vib: vibrato depth (fraction). breath: noise mix. lp: one-pole low-pass (0 = none .. 0.9 = dull). gain: level.
const PROFILES: Dictionary = {
	"hero_m": {"wave": "square", "f0": 150.0, "cps": 26.0, "blip": 0.075, "vib": 0.0, "breath": 0.04, "lp": 0.55, "gain": 0.32},
	"hero_f": {"wave": "square", "f0": 265.0, "cps": 28.0, "blip": 0.07, "vib": 0.0, "breath": 0.04, "lp": 0.5, "gain": 0.3},
	"mr_t": {"wave": "tri", "f0": 118.0, "cps": 20.0, "blip": 0.1, "vib": 0.012, "breath": 0.02, "lp": 0.3, "gain": 0.5},
	"phuc": {"wave": "saw", "f0": 175.0, "cps": 34.0, "blip": 0.06, "vib": 0.0, "breath": 0.06, "lp": 0.6, "gain": 0.3},
	"linh": {"wave": "pulse", "f0": 300.0, "cps": 36.0, "blip": 0.055, "vib": 0.0, "breath": 0.02, "lp": 0.45, "gain": 0.28},
	"anh_duy": {"wave": "nasal", "f0": 125.0, "cps": 30.0, "blip": 0.07, "vib": 0.0, "breath": 0.1, "lp": 0.35, "gain": 0.34},
	"chu_bay": {"wave": "saw", "f0": 105.0, "cps": 16.0, "blip": 0.12, "vib": 0.03, "breath": 0.08, "lp": 0.7, "gain": 0.34},
	"soi_xam": {"wave": "saw", "f0": 82.0, "cps": 18.0, "blip": 0.11, "vib": 0.02, "breath": 0.22, "lp": 0.72, "gain": 0.4},
	"alexander": {"wave": "nasal", "f0": 160.0, "cps": 24.0, "blip": 0.085, "vib": 0.05, "breath": 0.03, "lp": 0.2, "gain": 0.34},
	"za_man": {"wave": "sine", "f0": 140.0, "cps": 32.0, "blip": 0.065, "vib": 0.0, "breath": 0.0, "lp": 0.1, "gain": 0.5},
	"thi_lo": {"wave": "pulse", "f0": 340.0, "cps": 30.0, "blip": 0.07, "vib": 0.04, "breath": 0.03, "lp": 0.3, "gain": 0.27},
	"van_lo": {"wave": "tri", "f0": 95.0, "cps": 19.0, "blip": 0.11, "vib": 0.025, "breath": 0.05, "lp": 0.45, "gain": 0.5},
	"dolly": {"wave": "sine", "f0": 230.0, "cps": 14.0, "blip": 0.14, "vib": 0.09, "breath": 0.12, "lp": 0.25, "gain": 0.45},
	"generic": {"wave": "tri", "f0": 140.0, "cps": 24.0, "blip": 0.08, "vib": 0.0, "breath": 0.05, "lp": 0.4, "gain": 0.45},
}
## Cast ids (StoryCast) and speaker names -> voice id.
const BY_ID: Dictionary = {"mr_t": "mr_t", "phuc": "phuc", "linh": "linh", "anh_duy": "anh_duy", "chu_bay": "chu_bay",
	"soi_xam": "soi_xam", "bay_soi": "soi_xam", "alexander": "alexander", "za_man": "za_man", "thi_lo": "thi_lo",
	"lum_thi_lo": "thi_lo", "van_lo": "van_lo", "lum_van_lo": "van_lo", "dolly": "dolly", "dolly_unmasked": "dolly",
	"dolly_disguised": "dolly", "clone": "dolly", "clone_masked": "dolly"}
const BY_NAME: Dictionary = {"Mr.T": "mr_t", "Phúc": "phuc", "Linh": "linh", "Anh Duy": "anh_duy", "Chú Bảy": "chu_bay",
	"Sói Xám": "soi_xam", "Bầy Sói": "soi_xam", "Alexander": "alexander", "Za Mẫn": "za_man", "Lùm Thị Lọ": "thi_lo",
	"Thị Lọ": "thi_lo", "Lùm Văn Lọ": "van_lo", "Văn Lọ": "van_lo", "Cừu Dolly": "dolly", "???": "dolly", "Nhân bản": "dolly"}
## Precomposed Vietnamese vowels by tone (lower case).
const T_SAC: String = "áắấéếíóốớúứý"
const T_HUYEN: String = "àằầèềìòồờùừỳ"
const T_HOI_NGA: String = "ảẳẩẻểỉỏổởủửỷãẵẫẽễĩõỗỡũữỹ"
const T_NANG: String = "ạặậẹệịọộợụựỵ"

static var _banks: Dictionary = {}   # voice id -> Array[AudioStreamWAV] (TONES * STEPS.size())
static var _tasks: Dictionary = {}   # voice id -> {"task": int, "box": [Array or null]}
static var builds: int = 0           # banks adopted from worker tasks (tests)


## The voice of a speaker: the protagonist by opts "female" (else the story's protagonist), a cast id, a speaker name,
## else "generic".
static func voice_for(actor_id: String, speaker: String = "", opts: Dictionary = {}) -> String:
	if actor_id == "hero" or actor_id == "player" or (speaker != "" and speaker == StoryUtil.hero_name() and actor_id == ""):
		var fem: Variant = opts.get("female", null)
		if fem == null:
			fem = bool(StoryUtil.hero_opts({}).get("female", false))
		return "hero_f" if bool(fem) else "hero_m"
	if BY_ID.has(actor_id):
		return String(BY_ID[actor_id])
	if BY_NAME.has(speaker):
		return String(BY_NAME[speaker])
	if PROFILES.has(actor_id):
		return actor_id
	return "generic"


static func profile(id: String) -> Dictionary:
	return PROFILES.get(id, PROFILES["generic"])


## Starts one worker task per voice whose bank is neither built nor pending. Returns the number of tasks started.
static func warm(ids: Array) -> int:
	_poll()
	var n: int = 0
	for v: Variant in ids:
		var id: String = String(v)
		if not PROFILES.has(id) or _banks.has(id) or _tasks.has(id):
			continue
		var box: Array = [null]
		_tasks[id] = {"task": WorkerThreadPool.add_task(_job(box, id)), "box": box}
		n += 1
	return n


static func _job(box: Array, id: String) -> Callable:
	return func() -> void: box[0] = synth_bank(id)


static func _poll() -> void:
	for id: String in _tasks.keys():
		var t: Dictionary = _tasks[id]
		if WorkerThreadPool.is_task_completed(int(t["task"])):
			WorkerThreadPool.wait_for_task_completion(int(t["task"]))
			_tasks.erase(id)
			if (t["box"] as Array)[0] != null:
				_banks[id] = (t["box"] as Array)[0]
				builds += 1


## The voice's blips (main thread). Empty until its warm task finished: never synthesizes here.
static func bank(id: String) -> Array:
	_poll()
	return _banks.get(id, [])


static func pending() -> bool:
	_poll()
	return not _tasks.is_empty()


static func is_built(id: String) -> bool:
	_poll()
	return _banks.has(id)


## Waits for every pending bank (tests and load screens only, never during play).
static func finish_all() -> void:
	for id: String in _tasks.keys():
		WorkerThreadPool.wait_for_task_completion(int((_tasks[id] as Dictionary)["task"]))
	_poll()


static func clear_cache() -> void:
	finish_all()
	_banks.clear()


## The blip of `word` for voice id (null while the bank is not built).
static func blip(id: String, word: String) -> AudioStream:
	var b: Array = bank(id)
	if b.is_empty():
		return null
	var step: int = absi(word.to_lower().hash()) % STEPS.size()
	return b[tone_of(word) * STEPS.size() + step]


# ---------------------------------------------------------------------------
# Typewriter maths (pure)
# ---------------------------------------------------------------------------
## Tone class of a Vietnamese word from its precomposed vowels: 0 ngang, 1 sắc, 2 huyền, 3 hỏi / ngã, 4 nặng.
static func tone_of(word: String) -> int:
	var w: String = word.to_lower()
	for i: int in w.length():
		var c: String = w[i]
		if T_SAC.contains(c):
			return 1
		if T_HUYEN.contains(c):
			return 2
		if T_HOI_NGA.contains(c):
			return 3
		if T_NANG.contains(c):
			return 4
	return 0


## Characters of `text` shown t seconds after the line started at cps characters per second.
static func chars_at(text: String, t: float, cps: float) -> int:
	if t <= 0.0:
		return 0
	return mini(text.length(), int(floor(t * cps)) + 1)


## Typing speed for a line on screen for dur seconds: the voice's own speed, faster when the line would not finish typing
## by FIT_U of its duration.
static func fit_cps(text: String, dur: float, cps: float) -> float:
	var need: float = float(text.length()) / maxf(dur * FIT_U, 0.05)
	return clampf(maxf(cps, need), 1.0, MAX_CPS)


## Index of the first character of every word (a letter or digit after a non-letter).
static func word_starts(text: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	var prev_word: bool = false
	for i: int in text.length():
		var c: String = text[i]
		var is_w: bool = _is_word_char(c)
		if is_w and not prev_word:
			out.append(i)
		prev_word = is_w
	return out


static func _is_word_char(c: String) -> bool:
	return c != "" and not (c in " \t\n.,!?;:\"'()[]-…/")


## Words whose first character became visible when the typed count went from n0 to n1 (each as its full word).
static func new_words(text: String, n0: int, n1: int) -> PackedStringArray:
	var out := PackedStringArray()
	if n1 <= n0:
		return out
	for st: int in word_starts(text):
		if st >= n0 and st < n1:
			var e: int = st
			while e < text.length() and _is_word_char(text[e]):
				e += 1
			out.append(text.substr(st, e - st))
	return out


# ---------------------------------------------------------------------------
# Synthesis (pure: no scene tree, no shared state; runs on worker threads)
# ---------------------------------------------------------------------------
## Every blip of a voice: tone-major, STEPS pitches each.
static func synth_bank(id: String) -> Array:
	var out: Array = []
	for tone: int in TONES:
		for st: float in STEPS:
			out.append(CineAudio._to_wav(synth_blip(id, tone, st)))
	return out


## One syllable: the voice's waveform along the tone's pitch contour, a quick attack, a decay, vibrato, breath noise and
## a one-pole low-pass; nặng is short with a glottal cut.
static func synth_blip(id: String, tone: int, semis: float = 0.0) -> PackedFloat32Array:
	var p: Dictionary = profile(id)
	var f0: float = float(p["f0"]) * pow(2.0, semis / 12.0)
	var dur: float = float(p["blip"]) * (0.6 if tone == 4 else (1.25 if tone == 3 else 1.0))
	var n: int = maxi(int(dur * SR), 16)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var wave: String = String(p["wave"])
	var vib: float = float(p["vib"])
	var breath: float = float(p["breath"])
	var lp: float = clampf(float(p["lp"]), 0.0, 0.95)
	var gain: float = float(p["gain"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id) + tone * 31 + int(semis * 7.0)
	var ph: float = 0.0
	var prev: float = 0.0
	for i: int in n:
		var t: float = float(i) / SR
		var u: float = float(i) / float(n)
		var f: float = f0 * _contour(tone, u) * (1.0 + vib * sin(TAU * 6.5 * t))
		ph += TAU * f / SR
		var v: float = _wave(wave, ph)
		v += rng.randf_range(-1.0, 1.0) * breath
		prev = lerpf(v, prev, lp)
		var env: float = minf(1.0, t / 0.006) * pow(1.0 - u, 1.4 if tone != 4 else 0.6)
		if tone == 4 and u > 0.8:
			env *= maxf(0.0, (1.0 - u) / 0.2)
		buf[i] = prev * env * gain
	return buf


static func _contour(tone: int, u: float) -> float:
	match tone:
		1:
			return lerpf(1.0, 1.28, u)
		2:
			return lerpf(0.94, 0.78, u)
		3:
			return 1.0 - 0.16 * sin(PI * minf(u / 0.7, 1.0)) + (0.12 * (u - 0.7) / 0.3 if u > 0.7 else 0.0)
		4:
			return lerpf(0.86, 0.8, u)
	return 1.0


static func _wave(wave: String, ph: float) -> float:
	var x: float = fposmod(ph, TAU) / TAU
	match wave:
		"square":
			return 0.7 if x < 0.5 else -0.7
		"saw":
			return (2.0 * x - 1.0) * 0.8
		"tri":
			return (1.0 - 4.0 * absf(x - 0.5)) * 0.9
		"pulse":
			return 0.7 if x < 0.25 else -0.3
		"nasal":
			return (sin(ph) + 0.6 * sin(2.0 * ph) + 0.45 * sin(3.0 * ph) + 0.3 * sin(5.0 * ph)) * 0.45
	return sin(ph) + 0.25 * sin(2.0 * ph)
