# File: res://scripts/combat/guns/GunAudio.gd
# Synthesized SFX of the Phase C gunfights and the forklift boss (no music): the forklift's two-tone horn, its hydraulic
# lift whine, the overheating steam hiss, Alexander's party horn and the bullet-time heartbeat (a looping lub-dub, Wave 3). Built with the A1 voice helpers (CineAudio._tone /
# _noise / _mix / _to_wav); the owner's user://sfx/<cue>.ogg overrides any of them (local only). Main thread only (static
# cache); warm() fills it at load so a fight never synthesizes mid-frame.
class_name GunAudio
extends RefCounted

const CUES: Array[String] = ["forklift_horn", "forklift_lift", "steam_hiss", "party_horn", "heartbeat"]
static var _cache: Dictionary = {}


static func warm() -> void:
	for c: String in CUES:
		stream(c)


static func stream(cue: String) -> AudioStream:
	if _cache.has(cue):
		return _cache[cue]
	var st: AudioStream = null
	var f: String = WeaponAudio.sfx_dir + cue + ".ogg"
	if FileAccess.file_exists(f):
		st = CineAudio._load_file(f)
	if st == null:
		st = _synth(cue)
	_cache[cue] = st
	return st


static func _synth(cue: String) -> AudioStreamWAV:
	var sr: int = CineAudio.SR
	match cue:
		"forklift_horn":         # two short square-ish honks
			var b := PackedFloat32Array()
			for i: int in 2:
				b.append_array(CineAudio._mix([CineAudio._tone(0.16, 415.0, 415.0, 0.45, 2.0), CineAudio._tone(0.16, 830.0, 830.0, 0.2, 2.0),
					CineAudio._tone(0.16, 1245.0, 1245.0, 0.1, 2.0)]))
				var gap := PackedFloat32Array()
				gap.resize(int(0.08 * sr))
				b.append_array(gap)
			return CineAudio._to_wav(b)
		"forklift_lift":         # hydraulic whine rising
			return CineAudio._to_wav(CineAudio._mix([CineAudio._tone(0.9, 180.0, 420.0, 0.25, 0.5), CineAudio._noise(0.9, 0.08, 0.5, 31, 0.85)]))
		"steam_hiss":            # long filtered noise burst
			return CineAudio._to_wav(CineAudio._noise(1.6, 0.4, 1.2, 37, 0.35))
		"heartbeat":             # lub-dub, 0.8 s, looping (bullet time; an SFX, not music)
			var hb := PackedFloat32Array()
			hb.resize(int(0.8 * sr))
			var lub: PackedFloat32Array = CineAudio._mix([CineAudio._tone(0.12, 72.0, 44.0, 0.85, 22.0), CineAudio._noise(0.05, 0.12, 40.0, 41, 0.9)])
			var dub: PackedFloat32Array = CineAudio._tone(0.1, 64.0, 40.0, 0.6, 26.0)
			for i3: int in lub.size():
				hb[i3] += lub[i3]
			var off: int = int(0.2 * sr)
			for i4: int in dub.size():
				if off + i4 < hb.size():
					hb[off + i4] += dub[i4]
			var w: AudioStreamWAV = CineAudio._to_wav(hb)
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = hb.size()
			return w
		"party_horn":            # a paper party blower: a buzzy rising note
			var p := PackedFloat32Array()
			p.resize(int(0.7 * sr))
			var ph: float = 0.0
			for i2: int in p.size():
				var t: float = float(i2) / sr
				ph += TAU * lerpf(300.0, 520.0, minf(t / 0.3, 1.0)) / sr
				p[i2] = (0.5 if fmod(ph, TAU) < PI else -0.5) * 0.35 * minf(1.0, (0.7 - t) * 6.0)
			return CineAudio._to_wav(p)
	return CineAudio._to_wav(CineAudio._tone(0.08, 800.0, 800.0, 0.4, 20.0))
