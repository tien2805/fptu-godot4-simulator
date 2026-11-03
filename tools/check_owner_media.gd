# File: res://tools/check_owner_media.gd
# Phase E owner kit (plan 2026-11-03-w5-complete.md T7, docs/PHASE_E_OWNER_KIT.md): lists which of the owner's local media
# files the game finds in user:// and which are missing. Read-only: it only checks that files exist and lists the three
# folders; it never writes, moves or deletes anything, and it never opens the save or the settings.
#   video/  the six AI clips <clip>_m.ogv / <clip>_f.ogv (StoryVideo); missing = the in-engine fallback cinematic plays
#   music/  every music slot of MusicDirector.all_slots() as <slot>.ogg or .mp3 (CineAudio.music_file, with the
#           SLOT_FALLBACK parents); missing = silence
#   sfx/    every overridable sound cue; missing = the synthesized sound (owner-only lines: silence)
# Files in the three folders the game never reads are listed too (a typo in a name or an extension its reader skips, e.g.
# boss_d2.wav, is the usual reason a file "does nothing"); a missing slot / cue row names such a file as a hint.
# Run (from the project folder):
#   godot --headless --path . --script tools/check_owner_media.gd            (everything)
#   godot --headless --path . --script tools/check_owner_media.gd -- --missing   (only what is missing)
extends SceneTree

const CLIPS: Array[String] = ["ai_intro", "ai_reveal", "ai_true_end"]
## Owner-only sounds (no synthesized fallback: silence without the file).
const OWNER_ONLY: Array[String] = ["dolly_wc_full"]
## The loa kẹo kéo's song (WeaponAudio.owner_file: .ogg / .mp3 only; without it the weapon plays its synthesized bolero).
const LOA: String = "loa_keo_keo"
const MUSIC_EXTS: Array[String] = [".ogg", ".mp3"]
## Extensions people try that the game never reads (hints on the rows).
const OTHER_EXTS: Array[String] = [".wav", ".flac", ".m4a", ".aac", ".wma", ".opus"]

var only_missing: bool = false
var known_music: Dictionary = {}
var known_sfx: Dictionary = {}
var missing: int = 0


func _initialize() -> void:
	only_missing = OS.get_cmdline_user_args().has("--missing")
	print("=== KIỂM TRA FILE CỦA CHỦ GAME ===")
	print("Thư mục: ", ProjectSettings.globalize_path("user://"))
	_video()
	_music()
	_sfx()
	_strays()
	print("")
	print("Tổng: %d mục chưa có (video thiếu = cảnh dựng sẵn trong game; nhạc thiếu = im lặng). SFX [TỰ TẠO] không cần file." % missing)
	quit(0)


func _line(ok: bool, text: String) -> void:
	if not ok:
		missing += 1
	if ok and only_missing:
		return
	print("  [%s] %s" % ["CÓ  " if ok else "THIẾU", text])


func _video() -> void:
	print("")
	print("--- VIDEO AI (video/<clip>_m.ogv = nhân vật nam, _f.ogv = nhân vật nữ; Theora .ogv) ---")
	for c: String in CLIPS:
		for sex: String in ["_m", "_f"]:
			var name: String = c + sex + ".ogv"
			var ok: bool = FileAccess.file_exists(StoryVideo.video_dir + name)
			var note: String = ""
			if not ok:
				for ext: String in [".mp4", ".webm", ".mov", ".mkv"]:
					if FileAccess.file_exists(StoryVideo.video_dir + c + sex + ext):
						note = "  (có %s%s: Godot chỉ đọc .ogv, đổi bằng ffmpeg)" % [c + sex, ext]
			_line(ok, "video/" + name + note)


func _music() -> void:
	print("")
	print("--- NHẠC (music/<slot>.ogg hoặc .mp3) ---")
	for s: String in MusicDirector.all_slots():
		known_music[s] = true
		var own: String = ""
		for ext: String in [".ogg", ".mp3"]:
			if own == "" and FileAccess.file_exists(CineAudio.MUSIC_DIR + s + ext):
				own = s + ext
		if own != "":
			_line(true, "music/" + own)
			continue
		var hint: String = _wrong_ext(CineAudio.MUSIC_DIR, s, MUSIC_EXTS)
		var f: String = CineAudio.music_file(s)
		if f != "" and hint == "":
			if not only_missing:
				print("  [MƯỢN] music/%s.ogg -> dùng %s (có thể thêm file riêng)" % [s, f.get_file()])
			continue
		_line(false, "music/%s.ogg%s" % [s, hint])


func _sfx() -> void:
	print("")
	print("--- SFX (sfx/<tên>; không có file = [TỰ TẠO], âm do game tự tạo, vẫn chạy tốt) ---")
	var groups: Array = [
		["Story (meme, kinh dị, chi tiết)", Array(StoryAudio.CUES) + Array(StoryAudio.POLISH), [".ogg", ".mp3", ".wav"]],
		["Cảnh phim", Array(CineAudio.SFX_CUES), [".ogg"]],
		["Đòn đánh", Array(ImpactAudio.CUES), [".ogg", ".mp3"]],
		["Kiếm, gậy", Array(SwordAudio.CUES), [".ogg", ".mp3"]],
		["Vũ khí", Array(WeaponAudio.CUES), [".ogg", ".mp3"]],
		["Súng, xe nâng", Array(GunAudio.CUES), [".ogg"]],
		["Xe máy", [PlayerBike.SFX_EXHAUST, PlayerBike.SFX_HORN, PlayerBike.SFX_REV], [".ogg", ".mp3", ".wav"]],
		["Loa kẹo kéo (vũ khí; thiếu = game dùng bolero tự tạo)", [LOA], [".ogg", ".mp3"]],
		["Chỉ có khi chủ game thêm (thiếu = im lặng)", OWNER_ONLY, [".ogg", ".mp3", ".wav"]],
	]
	for g: Array in groups:
		print(" ", g[0], " (", "/".join(PackedStringArray(g[2])), "):")
		for cue: Variant in g[1]:
			var c: String = String(cue)
			var exts: Array = known_sfx.get(c, [])
			for e: Variant in g[2]:
				if not (String(e) in exts):
					exts.append(String(e))
			known_sfx[c] = exts
			var have: String = ""
			for ext: Variant in g[2]:
				if have == "" and FileAccess.file_exists(CineAudio.SFX_DIR + c + String(ext)):
					have = c + String(ext)
			var note: String = _wrong_ext(CineAudio.SFX_DIR, c, g[2]) if have == "" else ""
			if have == "" and c == LOA:
				note += "  (game dùng bolero tự tạo)"
			if have != "" or c in OWNER_ONLY:
				_line(have != "", "sfx/" + (have if have != "" else c) + note)
			elif not only_missing:
				print("  [TỰ TẠO] sfx/%s%s" % [c, note])


## Files in video/, music/, sfx/ the game never reads: a name that matches no clip, slot or cue, or a known name with an
## extension its reader skips (sfx/dolly_wc_1..5 land here too: only dolly_wc_full is read).
func _strays() -> void:
	print("")
	print("--- FILE GAME KHÔNG ĐỌC (sai tên hoặc sai đuôi) ---")
	var n: int = 0
	for pair: Array in [["video/", {}], ["music/", known_music], ["sfx/", known_sfx]]:
		var dir: DirAccess = DirAccess.open("user://" + String(pair[0]))
		if dir == null:
			print("  (chưa có thư mục %s)" % String(pair[0]))
			continue
		for f: String in dir.get_files():
			if f.ends_with(".import") or f.begins_with("."):
				continue
			var base: String = f.get_basename()
			var ok: bool
			var why: String = ""
			var ext: String = "." + f.get_extension().to_lower()
			if String(pair[0]) == "video/":
				ok = ext == ".ogv" and StoryVideo.clip_of(f) in CLIPS and (base.ends_with("_m") or base.ends_with("_f"))
			elif String(pair[0]) == "sfx/":
				ok = (pair[1] as Dictionary).has(base) and ext in ((pair[1] as Dictionary)[base] as Array)
				if (pair[1] as Dictionary).has(base) and not ok:
					why = "  (game chỉ đọc %s)" % "/".join(PackedStringArray((pair[1] as Dictionary)[base]))
			else:
				ok = (pair[1] as Dictionary).has(base) and ext in MUSIC_EXTS
				if (pair[1] as Dictionary).has(base) and not ok:
					why = "  (game chỉ đọc .ogg/.mp3)"
			if not ok:
				n += 1
				print("  %s%s%s" % [String(pair[0]), f, why])
	if n == 0:
		print("  (không có)")


## " (có <name><ext> nhưng game chỉ đọc ...)" when the folder holds the name with an extension this slot / cue never reads.
func _wrong_ext(dir: String, name: String, reads: Array) -> String:
	for ext: String in [".ogg", ".mp3", ".wav"] + OTHER_EXTS:
		if not (ext in reads) and FileAccess.file_exists(dir + name + ext):
			return "  (có %s%s nhưng game chỉ đọc %s)" % [name, ext, "/".join(PackedStringArray(reads))]
	return ""
