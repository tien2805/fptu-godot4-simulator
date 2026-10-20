# File: res://scripts/MusicDirector.gd
# NHẠC NỀN THỦ TỤC, THÍCH ỨNG (không file nhạc ngoài): bộ tổng hợp 5 giọng (kick, snare, hi-hat, bass, pad, lead)
# chạy real-time qua AudioStreamGenerator 22.05 kHz, sequencer 16 bước, mỗi màn một "style" (nhịp, giọng, vòng hợp âm,
# pattern). `tension` 0..1 (tốc độ, chuỗi near-miss, máu boss…) làm nhạc dồn hơn: hi-hat dày, bass sáng, lead xuất hiện,
# nhịp nhanh hơn (capstone). Đi qua bus "Music" (âm lượng trong Cài đặt). GameFX tạo 1 node này lúc khởi động:
#   GameFX.music_play("ride") · GameFX.music_tension(0.7) · GameFX.music_stop()
class_name MusicDirector
extends Node

const SR: float = 22050.0
const MAJOR: Array[int] = [0, 2, 4, 5, 7, 9, 11]
const MINOR: Array[int] = [0, 2, 3, 5, 7, 8, 10]

## style → {bpm, root(Hz), minor, chords(bậc 0-based), bass(16 bước: -1 nghỉ / 0 gốc / 1 quãng 5 / 2 quãng 8), kick, snare, hat, lead_arp, gains}
const STYLES: Dictionary = {
	"menu":      {"bpm": 92.0,  "root": 220.0,  "minor": false, "chords": [0, 5, 3, 4], "bass": [0, -1, -1, -1, 1, -1, -1, -1, 0, -1, -1, -1, 2, -1, 1, -1],
				  "kick": [1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0], "snare": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "hat": [0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0],
				  "lead": [0, -1, 2, -1, 4, -1, 2, -1, -1, -1, 7, -1, 4, -1, -1, -1], "pad": 0.16, "lead_gain": 0.05, "bass_gain": 0.16, "drum_gain": 0.35},
	"ride":      {"bpm": 128.0, "root": 164.81, "minor": true,  "chords": [0, 0, 5, 3], "bass": [0, 0, 2, 0, 0, 0, 2, 0, 0, 0, 2, 0, 1, 0, 2, 1],
				  "kick": [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0], "snare": [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0], "hat": [0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0],
				  "lead": [0, 2, 4, 7, 4, 2, 0, 2, 4, 7, 9, 7, 4, 2, 0, -1], "pad": 0.1, "lead_gain": 0.12, "bass_gain": 0.26, "drum_gain": 0.55},
	"parking":   {"bpm": 112.0, "root": 196.0,  "minor": false, "chords": [0, 3, 4, 0], "bass": [0, -1, 0, 1, -1, 0, -1, 2, 0, -1, 0, 1, -1, 2, 1, -1],
				  "kick": [1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0], "snare": [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1], "hat": [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0],
				  "lead": [4, -1, 2, -1, 0, -1, -1, -1, 4, -1, 5, -1, 4, -1, 2, -1], "pad": 0.1, "lead_gain": 0.09, "bass_gain": 0.22, "drum_gain": 0.45},
	"classroom": {"bpm": 84.0,  "root": 174.61, "minor": false, "chords": [1, 4, 0, 5], "bass": [0, -1, -1, -1, -1, -1, 1, -1, 0, -1, -1, -1, 2, -1, -1, -1],
				  "kick": [1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0], "snare": [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0], "hat": [0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0],
				  "lead": [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1], "pad": 0.2, "lead_gain": 0.0, "bass_gain": 0.14, "drum_gain": 0.28, "vinyl": 0.02},
	"vovinam":   {"bpm": 140.0, "root": 146.83, "minor": true,  "chords": [0, 0, 3, 4], "bass": [0, -1, 0, -1, -1, 0, -1, -1, 0, -1, 0, -1, 1, -1, 1, 1],
				  "kick": [1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0], "snare": [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0], "hat": [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
				  "lead": [0, -1, -1, 2, -1, -1, 4, -1, 0, -1, -1, 2, -1, 7, -1, -1], "pad": 0.06, "lead_gain": 0.1, "bass_gain": 0.24, "drum_gain": 0.6},
	"canteen":   {"bpm": 118.0, "root": 261.63, "minor": false, "chords": [0, 1, 4, 3], "bass": [0, -1, -1, 1, -1, -1, 0, -1, 2, -1, -1, 1, -1, -1, 0, -1],
				  "kick": [1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0], "snare": [0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0], "hat": [1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1],
				  "lead": [4, -1, 2, 4, -1, 5, -1, 4, -1, 2, -1, 0, -1, -1, 2, -1], "pad": 0.12, "lead_gain": 0.08, "bass_gain": 0.2, "drum_gain": 0.4},
	"capstone":  {"bpm": 100.0, "root": 130.81, "minor": true,  "chords": [0, 5, 3, 6], "bass": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
				  "kick": [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0], "snare": [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0], "hat": [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0],
				  "lead": [0, -1, -1, -1, 3, -1, -1, -1, 2, -1, -1, -1, 7, -1, 5, -1], "pad": 0.14, "lead_gain": 0.11, "bass_gain": 0.28, "drum_gain": 0.55, "tempo_tension": 32.0},
	"exam":      {"bpm": 90.0,  "root": 246.94, "minor": true,  "chords": [0, 0, 5, 5], "bass": [0, -1, -1, -1, -1, -1, -1, -1, 1, -1, -1, -1, -1, -1, -1, -1],
				  "kick": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "snare": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "hat": [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0],
				  "lead": [-1, -1, 4, -1, -1, -1, -1, -1, -1, -1, 2, -1, -1, -1, -1, -1], "pad": 0.15, "lead_gain": 0.06, "bass_gain": 0.14, "drum_gain": 0.3, "heartbeat": true}
}

var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var style_name: String = ""
var st: Dictionary = {}
var tension: float = 0.0
var _tension_cur: float = 0.0
var _master_gain: float = 0.0
var _target_gain: float = 0.0

# sequencer
var _t_step: float = 0.0
var _step: int = -1
var _bar: int = 0
var _chord_notes: Array[float] = [0.0, 0.0, 0.0]
# giọng
var _kick_t: float = 9.0
var _snare_t: float = 9.0
var _hat_t: float = 9.0
var _bass_f: float = 0.0
var _bass_t: float = 9.0
var _bass_ph: float = 0.0
var _bass_lp: float = 0.0
var _lead_f: float = 0.0
var _lead_t: float = 9.0
var _lead_ph: float = 0.0
var _pad_ph: Array[float] = [0.0, 0.0, 0.0]
var _pad_target: Array[float] = [0.0, 0.0, 0.0]
var _pad_cur: Array[float] = [0.0, 0.0, 0.0]
var _kick_ph: float = 0.0
var _noise_prev: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	player.bus = "Music"
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = SR
	gen.buffer_length = 0.25
	player.stream = gen
	player.volume_db = -6.0
	add_child(player)
	_rng.seed = 2026

func play(style: String) -> void:
	if not STYLES.has(style):
		return
	if style == style_name and player.playing:
		return
	style_name = style
	st = STYLES[style]
	_step = -1
	_t_step = 0.0
	_bar = 0
	_target_gain = 1.0
	if not player.playing:
		player.play()
		playback = player.get_stream_playback() as AudioStreamGeneratorPlayback
		_master_gain = 0.0

func stop(fade: bool = true) -> void:
	_target_gain = 0.0
	if not fade:
		_master_gain = 0.0
		player.stop()
		style_name = ""

func set_tension(v: float) -> void:
	tension = clampf(v, 0.0, 1.0)

func _process(delta: float) -> void:
	if playback == null or st.is_empty() or not player.playing:
		return
	_tension_cur = lerpf(_tension_cur, tension, minf(1.0, delta * 1.5))
	_master_gain = move_toward(_master_gain, _target_gain, delta * (0.6 if _target_gain > _master_gain else 1.2))
	if _master_gain <= 0.001 and _target_gain <= 0.0:
		player.stop()
		style_name = ""
		return
	var n: int = mini(playback.get_frames_available(), 4096)
	if n <= 0:
		return
	var buf := PackedVector2Array()
	buf.resize(n)
	var bpm: float = float(st["bpm"]) + float(st.get("tempo_tension", 0.0)) * _tension_cur
	var step_len: float = 60.0 / bpm / 4.0
	var dt: float = 1.0 / SR
	var drum_gain: float = float(st["drum_gain"])
	var bass_gain: float = float(st["bass_gain"])
	var pad_gain: float = float(st["pad"])
	var lead_gain: float = float(st["lead_gain"]) * clampf((_tension_cur - 0.15) / 0.5, 0.0, 1.0)
	var vinyl: float = float(st.get("vinyl", 0.0))
	var heartbeat: bool = bool(st.get("heartbeat", false))
	var lp_coef: float = clampf(0.08 + 0.3 * _tension_cur, 0.05, 0.45)
	for i: int in range(n):
		# --- sequencer
		_t_step += dt
		if _t_step >= step_len or _step < 0:
			_t_step = 0.0 if _step >= 0 else _t_step
			_step = (_step + 1) % 16
			if _step == 0:
				_bar += 1
				_set_chord(_bar)
			_trigger_step(_step, heartbeat)
		# --- kick: sin quét tần số 110→42 Hz, decay 0.28 s
		var kick: float = 0.0
		if _kick_t < 0.35:
			var kf: float = 42.0 + 70.0 * exp(-_kick_t * 22.0)
			_kick_ph += kf * dt
			kick = sin(_kick_ph * TAU) * exp(-_kick_t * 9.0)
			_kick_t += dt
		# --- snare / hat: nhiễu
		var noise: float = _rng.randf_range(-1.0, 1.0)
		var hp: float = noise - _noise_prev
		_noise_prev = noise
		var snare: float = 0.0
		if _snare_t < 0.2:
			snare = (noise * 0.6 + sin(_snare_t * 185.0 * TAU) * 0.4) * exp(-_snare_t * 18.0)
			_snare_t += dt
		var hat: float = 0.0
		if _hat_t < 0.08:
			hat = hp * 0.5 * exp(-_hat_t * 60.0)
			_hat_t += dt
		# --- bass: răng cưa qua lọc 1 cực
		var bass: float = 0.0
		if _bass_t < step_len * 1.7 and _bass_f > 0.0:
			_bass_ph = fmod(_bass_ph + _bass_f * dt, 1.0)
			var saw: float = 2.0 * _bass_ph - 1.0
			_bass_lp += (saw - _bass_lp) * lp_coef
			bass = _bass_lp * (1.0 if _bass_t < step_len * 0.9 else maxf(0.0, 1.0 - (_bass_t - step_len * 0.9) / (step_len * 0.8)))
			_bass_t += dt
		# --- pad: 3 sin + họa âm, glide giữa hợp âm
		var pad: float = 0.0
		for k: int in range(3):
			_pad_cur[k] += (_pad_target[k] - _pad_cur[k]) * 0.00008
			_pad_ph[k] = fmod(_pad_ph[k] + _pad_cur[k] * dt, 1.0)
			pad += sin(_pad_ph[k] * TAU) + 0.25 * sin(_pad_ph[k] * TAU * 2.0)
		pad *= 0.33
		# --- lead: sin + họa âm 3, decay
		var lead: float = 0.0
		if _lead_t < 0.4 and _lead_f > 0.0:
			_lead_ph = fmod(_lead_ph + _lead_f * dt, 1.0)
			lead = (sin(_lead_ph * TAU) + 0.3 * sin(_lead_ph * TAU * 3.0)) * exp(-_lead_t * 7.0)
			_lead_t += dt
		var s: float = (kick * 1.0 + snare * 0.6 + hat * (0.35 + 0.35 * _tension_cur)) * drum_gain
		s += bass * bass_gain + pad * pad_gain + lead * lead_gain
		if vinyl > 0.0:
			s += noise * vinyl * (1.0 if _rng.randf() < 0.002 else 0.15)
		s *= _master_gain
		s = s / (1.0 + absf(s)) # soft clip
		buf[i] = Vector2(s, s)
	playback.push_buffer(buf)

func _scale() -> Array[int]:
	return MINOR if bool(st["minor"]) else MAJOR

func _degree_freq(deg: int, octave: int = 0) -> float:
	var sc: Array[int] = _scale()
	var oct: int = octave + int(floor(float(deg) / 7.0))
	var d: int = ((deg % 7) + 7) % 7
	return float(st["root"]) * pow(2.0, (float(sc[d]) + 12.0 * float(oct)) / 12.0)

func _set_chord(bar: int) -> void:
	var chords: Array = st["chords"]
	var deg: int = int(chords[bar % chords.size()])
	_pad_target[0] = _degree_freq(deg, 0)
	_pad_target[1] = _degree_freq(deg + 2, 0)
	_pad_target[2] = _degree_freq(deg + 4, 0)
	if _pad_cur[0] == 0.0:
		for k: int in range(3):
			_pad_cur[k] = _pad_target[k]

func _trigger_step(step: int, heartbeat: bool) -> void:
	var kick_pat: Array = st["kick"]
	var snare_pat: Array = st["snare"]
	var hat_pat: Array = st["hat"]
	var bass_pat: Array = st["bass"]
	var lead_pat: Array = st["lead"]
	var chords: Array = st["chords"]
	var deg: int = int(chords[_bar % chords.size()])
	if int(kick_pat[step]) == 1 or (heartbeat and _tension_cur > 0.4 and (step == 0 or step == 3)):
		_kick_t = 0.0
		_kick_ph = 0.0
	if int(snare_pat[step]) == 1:
		_snare_t = 0.0
	# hi-hat dày hơn khi căng: thêm nốt lẻ 16
	if int(hat_pat[step]) == 1 or (_tension_cur > 0.55 and step % 2 == 1) or (_tension_cur > 0.85):
		_hat_t = 0.0
	var b: int = int(bass_pat[step])
	if b >= 0 or (_tension_cur > 0.7 and step % 2 == 0):
		var bb: int = maxi(b, 0)
		_bass_f = _degree_freq(deg + (4 if bb == 1 else 0), -1 + (1 if bb == 2 else 0))
		_bass_t = 0.0
	var l: int = int(lead_pat[step])
	if l >= 0 and _tension_cur > 0.15:
		_lead_f = _degree_freq(deg + l, 1)
		_lead_t = 0.0
