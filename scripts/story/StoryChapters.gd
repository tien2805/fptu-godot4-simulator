# File: res://scripts/story/StoryChapters.gd
# Chapter select and cinematic gallery records (plan 2026-10-26-chapter-select.md), static helpers around two files:
#   user://story_unlocks.cfg  [unlocks] beats = [...], cines = [...]: every beat reached and every story cinematic started,
#                             across all playthroughs; it only grows (a rewind or a new story never removes anything);
#   user://story_chapters.cfg [chapters] <beat id> = var_to_str(StoryDirector.to_dict()): the full story state at the start
#                             of each replayable beat, the latest entry wins.
# A rewind backs the current save up to user://story_save_before_rewind.cfg, writes the beat's snapshot as the save and
# continues the story from it (the TIẾP TỤC path); restore_backup puts the backup back. Settings (Giảm hù dọa...) live in
# GameFX and are never part of a snapshot. Old saves (no unlock file yet) are seeded once (ensure_seeded).
# The real user:// files are never read or written headless: tests point the static paths at temp files.
# Beats added after players already had saves (INSERTED, e.g. the Day 2 drift duel d2_drift): an unlock file that
# reached the beat after one of them lists it unlocked, and its snapshot is derived from that next beat's snapshot (the
# same state, its own step, objective and time of day), so Chọn cảnh can rewind to it.
# Wave 3 ranks (plan 2026-10-30-w3-shared.md T9): the unlock file's [ranks] <beat id> = best letter mirrors every best
# rank ever recorded (record_ranks: only a better letter replaces one, it only grows); a rewind merges them back into the
# rewound state (merge_ranks) so it never loses a rank; chapters() rows carry "rank" ("" = none) for Chọn cảnh.
class_name StoryChapters
extends RefCounted

const UNLOCKS_PATH: String = "user://story_unlocks.cfg"
const CHAPTERS_PATH: String = "user://story_chapters.cfg"
const BACKUP_PATH: String = "user://story_save_before_rewind.cfg"
const REAL_SAVE_PATH: String = "user://story_save.cfg"
## Beat kinds listed in the chapter select (day starts are the dN_morning cine beats, choice beats are cine beats).
## Phase C: "lair" (a task inside the basement scene; its snapshot resumes at the marker that launches the scene).
const REPLAY_KINDS: Array[String] = ["cine", "video", "stage", "mission", "fight", "horror", "lair"]
const NEED_PLAY_LINE: String = "Chơi tới cảnh này một lần để mở"
## Beat -> the beat right after it, for beats inserted into the chain after release (old unlock files never saw them).
const INSERTED: Dictionary = {"d2_drift": "d2_bridge"}
## Story cinematics of the gallery, in story order: [slot, day, title].
const GALLERY: Array = [
	["cine_d0_wake", 0, "Tôi là ai, đây là đâu?"],
	["cine_d0_brief", 0, "Mr.T nhờ coi thi"],
	["cine_d0_exam", 0, "Bằng chứng đầu tiên"],
	["cine_d0_midnight", 0, "Nửa đêm ở BE6"],
	["ai_intro", 0, "TOANG!"],
	["cine_day_start", 1, "Một ngày mới"],
	["cine_d1_intro", 1, "Hẹn ở cổng trường"],
	["seg_d1_brawl", 1, "Ba shipper"],
	["cine_d1_corridor", 1, "Hành lang tối"],
	["cine_d1_choice", 1, "Phúc thú nhận"],
	["cine_d1_choice_cover", 1, "Bao che cho Phúc"],
	["cine_d1_choice_report", 1, "Báo cho Mr.T"],
	["cine_d1", 1, "Sói Xám"],
	["cine_d2_intro", 2, "Anh Duy dò đường Bầy Sói"],
	["seg_d2_boss", 2, "Sói Xám"],
	["cine_d2", 2, "Trói Sói Xám"],
	["cine_d3_intro", 3, "Đêm về bến container"],
	["cine_d3_mannequins", 3, "Container bí ẩn"],
	["seg_d3_boss", 3, "Xe nâng của Alexander"],
	["cine_d3", 3, "Tên dài nhất bến"],
	["cine_d4_intro", 4, "Nằm vùng căn tin"],
	["cine_d4_stare", 4, "Giờ đóng cửa"],
	["seg_d4_brawl", 4, "Bầy cừu"],
	["cine_d4", 4, "Dolly khai"],
	["cine_d5_intro", 5, "USB Za Mẫn Labs"],
	["cine_d5_monitors", 5, "Năm mươi màn hình"],
	["cine_d5_choice", 5, "Lời mời của Za Mẫn"],
	["cine_d5_choice_accept", 5, "Nhận lời"],
	["cine_d5_choice_refuse", 5, "Từ chối"],
	["seg_d5_boss", 5, "Katana mua trên mạng"],
	["cine_d5", 5, "Dòng tiền"],
	["end_c", 5, "Kết C: Kẻ phản diện mới"],
	# Day 7 (w4-day7)
	["cine_d7_intro", 7, "Còn 1 ngày"],
	["cine_d7_monologue", 7, "Mọi thứ đều nằm trong kế hoạch"],
	["seg_d7_phase2", 7, "Có điện rồi"],
	["seg_d7_finisher", 7, "Đòn chân kẹp cổ số 21"],
]

static var unlocks_path: String = UNLOCKS_PATH
static var chapters_path: String = CHAPTERS_PATH
static var backup_path: String = BACKUP_PATH
## The last restore_backup put back a finished story (ending C): it is restored but does not continue.
static var last_restore_finished: bool = false


## true for the owner's real files while running headless (bots and tests never touch them).
static func _guarded(path: String) -> bool:
	return DisplayServer.get_name() == "headless" and path in [UNLOCKS_PATH, CHAPTERS_PATH, BACKUP_PATH, REAL_SAVE_PATH]


static func _load(path: String) -> ConfigFile:
	var cfg := ConfigFile.new()
	if not _guarded(path) and FileAccess.file_exists(path):
		cfg.load(path)
	return cfg


# ---------------------------------------------------------------------------
# Beats
# ---------------------------------------------------------------------------
static func is_replayable(id: String) -> bool:
	return String(StoryMissions.beat(id).get("kind", "")) in REPLAY_KINDS


## The beat chain from the first beat, following "next".
static func chain() -> Array[String]:
	var out: Array[String] = []
	var cur: String = StoryMissions.first_beat()
	while cur != "" and not (cur in out):
		out.append(cur)
		cur = String(StoryMissions.beat(cur).get("next", ""))
	return out


static func day_header(day: int) -> String:
	return "Ngày %d · %s" % [day, StoryMissions.DAY_TITLES[clampi(day, 0, StoryMissions.DAY_TITLES.size() - 1)]]


# ---------------------------------------------------------------------------
# Unlocks
# ---------------------------------------------------------------------------
static func unlocked_beats() -> Array:
	var have: Array = _load(unlocks_path).get_value("unlocks", "beats", [])
	for id: String in INSERTED.keys():
		if not (id in have) and String(INSERTED[id]) in have:
			have.append(id)   # an old file reached the beat after it
	return have


static func unlocked_cines() -> Array:
	return _load(unlocks_path).get_value("unlocks", "cines", [])


static func is_beat_unlocked(id: String) -> bool:
	return id in unlocked_beats()


static func is_cine_unlocked(slot: String) -> bool:
	return slot in unlocked_cines()


## true when at least one chapter (replayable beat) is unlocked: the main menu button shows.
static func has_unlocks() -> bool:
	for id: Variant in unlocked_beats():
		if is_replayable(String(id)):
			return true
	return false


static func mark_beat(id: String) -> void:
	_add_unlocks([id], [])


static func mark_cine(slot: String) -> void:
	_add_unlocks([], [slot])


## Adds beats / slots to the unlock file; it is written only when something is new.
static func _add_unlocks(beats: Array, cines: Array) -> void:
	if _guarded(unlocks_path):
		return
	var cfg: ConfigFile = _load(unlocks_path)
	var changed: bool = false
	for pair: Array in [["beats", beats], ["cines", cines]]:
		var have: Array = cfg.get_value("unlocks", String(pair[0]), [])
		for v: Variant in pair[1]:
			if String(v) != "" and not (String(v) in have):
				have.append(String(v))
				changed = true
		cfg.set_value("unlocks", String(pair[0]), have)
	if changed or not FileAccess.file_exists(unlocks_path):
		cfg.save(unlocks_path)


# ---------------------------------------------------------------------------
# Wave 3 ranks
# ---------------------------------------------------------------------------
## Every best rank in the unlock file {beat id: letter}.
static func best_ranks() -> Dictionary:
	var cfg: ConfigFile = _load(unlocks_path)
	var out: Dictionary = {}
	if cfg.has_section("ranks"):
		for k: String in cfg.get_section_keys("ranks"):
			var l: String = String(cfg.get_value("ranks", k, ""))
			if l in StoryRank.LETTERS:
				out[k] = l
	return out


static func best_rank(id: String) -> String:
	return String(best_ranks().get(id, ""))


## Mirrors ranks {beat id: letter} into the unlock file: a letter is written only when it beats the stored one.
static func record_ranks(rk: Dictionary) -> void:
	if _guarded(unlocks_path) or rk.is_empty():
		return
	var cfg: ConfigFile = _load(unlocks_path)
	var changed: bool = false
	for k: Variant in rk.keys():
		var l: String = String(rk[k])
		if StoryRank.better(l, String(cfg.get_value("ranks", String(k), ""))):
			cfg.set_value("ranks", String(k), l)
			changed = true
	if changed:
		cfg.save(unlocks_path)


## The unlock file's best ranks merged into StoryDirector.ranks (the better letter wins).
static func merge_ranks(sd: Node) -> void:
	if sd == null or not ("ranks" in sd):
		return
	var cur: Dictionary = sd.get("ranks")
	var best: Dictionary = best_ranks()
	for k: Variant in best.keys():
		cur[k] = StoryRank.best_of(String(cur.get(k, "")), String(best[k]))
	sd.set("ranks", cur)


# ---------------------------------------------------------------------------
# Snapshots
# ---------------------------------------------------------------------------
static func snapshot(id: String) -> Dictionary:
	var v: Variant = str_to_var(String(_load(chapters_path).get_value("chapters", id, "")))
	if v is Dictionary and (v as Dictionary).has("step"):
		return v
	return derived_snapshot(id) if INSERTED.has(id) else {}


## An inserted beat's state rebuilt from the next beat's snapshot: nothing happens between them but the beat itself, so
## only the step, the objective and the time of day change. {} without that snapshot.
static func derived_snapshot(id: String) -> Dictionary:
	var nxt: Dictionary = snapshot(String(INSERTED.get(id, ""))) if INSERTED.has(id) else {}
	if nxt.is_empty():
		return {}
	var b: Dictionary = StoryMissions.beat(id)
	var d: Dictionary = nxt.duplicate(true)
	var who: String = String((d.get("protagonist", {}) as Dictionary).get("name", "")) if d.get("protagonist", {}) is Dictionary else ""
	if who == "":
		who = StoryUtil.DEFAULT_NAME
	d["step"] = id
	d["day"] = int(b.get("day", d.get("day", 0)))
	d["tod"] = String(b.get("tod", d.get("tod", "night")))
	d["objective"] = String(b.get("objective", "")).replace("{name}", who)
	d["spawn"] = null
	return d


static func save_snapshots(snaps: Dictionary) -> void:
	if _guarded(chapters_path) or snaps.is_empty():
		return
	var cfg: ConfigFile = _load(chapters_path)
	for id: Variant in snaps.keys():
		cfg.set_value("chapters", String(id), var_to_str(snaps[id]))
	cfg.save(chapters_path)


## StoryDirector._enter, after the step is set: the beat counts as reached; a replayable beat stores the state as it is
## at its start (the evidence and flags of the beats before it, its tod, objective and texts).
static func on_enter(sd: Node, id: String) -> void:
	if sd == null or _guarded(unlocks_path):
		return
	mark_beat(id)
	if is_replayable(id):
		save_snapshots({id: sd.call("to_dict")})


# ---------------------------------------------------------------------------
# Rewind
# ---------------------------------------------------------------------------
static func has_backup(sd: Node) -> bool:
	return sd != null and not _guarded(backup_path) and not (sd.call("read_save", backup_path) as Dictionary).is_empty()


static func _copy(from: String, to: String) -> bool:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(from)
	if bytes.is_empty():
		return false
	var f: FileAccess = FileAccess.open(to, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(bytes)
	f.close()
	return true


## Rewinds to beat `id`: the current save goes to the backup (the previous backup is overwritten), the beat's snapshot
## becomes the save and the story continues from it like TIẾP TỤC. false without a snapshot.
static func rewind(sd: Node, id: String) -> bool:
	var snap: Dictionary = snapshot(id)
	var save: String = String(sd.get("save_path")) if sd else ""
	if snap.is_empty() or save == "" or _guarded(save) or _guarded(backup_path):
		return false
	if not (sd.call("read_save", save) as Dictionary).is_empty():
		_copy(save, backup_path)
	sd.call("from_dict", snap)
	merge_ranks(sd)                          # a rewind never loses a rank
	sd.set("active", true)
	if not bool(sd.call("save_game")):
		return false
	return bool(sd.call("continue_story"))


## "QUAY VỀ TIẾN ĐỘ TRƯỚC KHI TUA": the backup becomes the save again (and is removed), then the story continues.
static func restore_backup(sd: Node) -> bool:
	if not has_backup(sd):
		return false
	var save: String = String(sd.get("save_path"))
	if _guarded(save) or not _copy(backup_path, save):
		return false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))
	last_restore_finished = String((sd.call("read_save", save) as Dictionary).get("ending", "")) != ""
	if last_restore_finished:
		sd.call("reset_state")   # a finished story (ending C) is back as the save; it does not continue (Chọn cảnh rewinds it)
		return true
	return bool(sd.call("continue_story"))


# ---------------------------------------------------------------------------
# Lists for the UI
# ---------------------------------------------------------------------------
## Every replayable beat of the chain in story order: {id, day, title, state: "open" | "need_play" | "locked", rank}.
static func chapters() -> Array[Dictionary]:
	var beats: Array = unlocked_beats()
	var snaps: ConfigFile = _load(chapters_path)
	var rk: Dictionary = best_ranks()
	var out: Array[Dictionary] = []
	for id: String in chain():
		var b: Dictionary = StoryMissions.beat(id)
		if not (String(b.get("kind", "")) in REPLAY_KINDS):
			continue
		var state: String = "locked"
		if id in beats:
			state = "open" if snaps.has_section_key("chapters", id) or (INSERTED.has(id) and not snapshot(id).is_empty()) else "need_play"
		out.append({"id": id, "day": int(b["day"]), "title": String(b["title"]), "state": state, "rank": String(rk.get(id, ""))})
	return out


## The gallery slots: {slot, day, title, unlocked}.
static func gallery() -> Array[Dictionary]:
	var have: Array = unlocked_cines()
	var out: Array[Dictionary] = []
	for row: Array in GALLERY:
		out.append({"slot": String(row[0]), "day": int(row[1]), "title": String(row[2]), "unlocked": String(row[0]) in have})
	return out


static func gallery_title(slot: String) -> String:
	for row: Array in GALLERY:
		if String(row[0]) == slot:
			return String(row[2])
	return slot


# ---------------------------------------------------------------------------
# Old saves
# ---------------------------------------------------------------------------
## Saves from before this feature have no unlock file: unlock the chain up to and including the save's beat (and the
## cinematics of the beats before it), store the save itself as that beat's snapshot and a best-effort snapshot for every
## earlier replayable beat. Does nothing once the unlock file exists. true when it seeded.
static func ensure_seeded(save: Dictionary) -> bool:
	if save.is_empty() or _guarded(unlocks_path) or _guarded(chapters_path) or FileAccess.file_exists(unlocks_path):
		return false
	var cur: String = StoryMissions.migrate(String(save.get("step", "")))
	var ch: Array[String] = chain()
	var idx: int = ch.find(cur)
	if idx < 0:
		_add_unlocks([cur], [])
		return true
	var beats: Array = ch.slice(0, idx + 1)
	var flags: Dictionary = save.get("flags", {}) if save.get("flags", {}) is Dictionary else {}
	var choices: Dictionary = save.get("choices", {}) if save.get("choices", {}) is Dictionary else {}
	var cines: Array = []
	for i: int in idx:
		for s: String in _beat_cines(StoryMissions.beat(ch[i]), choices):
			if not (s in cines):
				cines.append(s)
	var cb: Dictionary = StoryMissions.beat(cur)
	if cb.has("intro") and bool(flags.get("intro_" + String(cb["intro"]), false)):
		cines.append(String(cb["intro"]))
	_add_unlocks(beats, cines)
	var snaps: Dictionary = {}
	for i2: int in idx:
		if is_replayable(ch[i2]):
			snaps[ch[i2]] = best_effort(save, ch[i2])
	if is_replayable(cur):
		var own: Dictionary = save.duplicate(true)
		own["step"] = cur
		snaps[cur] = own
	save_snapshots(snaps)
	return true


## Cinematic slots a completed beat played: its slot (a branch tail only when the choice is known), intro and "after".
static func _beat_cines(b: Dictionary, choices: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if String(b.get("kind", "")) in ["cine", "video"]:
		var by: Dictionary = b.get("slot_by_choice", {})
		if by.is_empty():
			out.append(String(b.get("slot", "")))
		else:
			var key: String = String(choices.get(String(by.get("id", "")), ""))
			if key != "" and key != "id" and by.has(key):
				out.append(String(by[key]))
	for k: String in ["intro", "after"]:
		if b.has(k):
			out.append(String(b[k]))
	var known: Array[String] = []
	for row: Array in GALLERY:
		if String(row[0]) in out:
			known.append(String(row[0]))
	return known


## The state at the start of beat `id` rebuilt from a later save: the save's protagonist; the beat's day, tod, objective;
## the texts of the beats up to it; evidence, beat flags, intro flags and choices of the beats completed before it only
## (and only what the save has). A side marker's evidence (E2) counts only when its window closed before the beat, else
## the side is offered again (its flag is left out too). E5 and the d4 catch flags only after the horror beat.
static func best_effort(save: Dictionary, id: String) -> Dictionary:
	var ch: Array[String] = chain()
	var idx: int = ch.find(id)
	var b: Dictionary = StoryMissions.beat(id)
	var have: Array = save.get("evidence", [])
	var flags_now: Dictionary = save.get("flags", {}) if save.get("flags", {}) is Dictionary else {}
	var choices_now: Dictionary = save.get("choices", {}) if save.get("choices", {}) is Dictionary else {}
	var pr: Dictionary = (save.get("protagonist", {}) as Dictionary).duplicate(true) if save.get("protagonist", {}) is Dictionary else {}
	var who: String = String(pr.get("name", ""))
	if who == "":
		who = StoryUtil.DEFAULT_NAME
	var evidence: Array[String] = []
	var flags: Dictionary = {}
	var choices: Dictionary = {"phuc": "", "zaman_offer": "", "bribe": ""}
	var texts: Array[Dictionary] = []
	var sides_open: Array[String] = []   # side ids still offered at `id` or later
	for j: int in range(maxi(idx, 0), ch.size()):
		for sd2: Dictionary in StoryMissions.beat(ch[j]).get("side", []):
			sides_open.append(String(sd2.get("id", "")))
	var day: int = int(b.get("day", 0))
	for i: int in range(0, maxi(idx, 0) + 1):
		var bb: Dictionary = StoryMissions.beat(ch[i])
		var done: bool = i < idx
		for t: Array in bb.get("texts", []):
			texts.append({"from": String(t[0]), "text": String(t[1]).replace("{name}", who), "day": int(bb.get("day", 0)),
				"read": done})
		if not done:
			continue
		if bb.has("evidence") and String(bb["evidence"]) in have:
			evidence.append(String(bb["evidence"]))
		if bb.has("flag"):
			flags[String(bb["flag"])] = true
		for fk: Variant in (bb.get("flag_by_info", {}) as Dictionary).values():   # Phase C: d3_all_crates (E4)
			if bool(flags_now.get(String(fk), false)):
				flags[String(fk)] = true
		if bb.has("intro"):
			flags["intro_" + String(bb["intro"])] = true
		if bb.has("choice"):
			choices[String(bb["choice"])] = String(choices_now.get(String(bb["choice"]), ""))
		if String(bb.get("kind", "")) == "horror":
			if "E5" in have:
				evidence.append("E5")
			for k: String in ["d4_catches", "d4_caught"]:
				if flags_now.has(k):
					flags[k] = flags_now[k]
		for side: Dictionary in bb.get("side", []):
			var sid: String = String(side.get("id", ""))
			if sid in sides_open or not bool(flags_now.get(sid, false)) or flags.has(sid):
				continue
			flags[sid] = true
			if side.has("evidence") and String(side["evidence"]) in have:
				evidence.append(String(side["evidence"]))
	for f: Variant in flags_now.keys():
		var fs: String = String(f)
		if fs.begins_with("night_photo_d") and int(fs.substr(13)) < day:
			flags[fs] = flags_now[f]
	var ordered: Array[String] = []
	for e: String in StoryMissions.EVIDENCE_IDS:
		if e in evidence:
			ordered.append(e)
	return {"active": true, "day": day, "tod": String(b.get("tod", "morning")), "step": id, "evidence": ordered,
		"choices": choices, "flags": flags, "protagonist": pr, "texts": texts,
		"objective": String(b.get("objective", "")).replace("{name}", who), "spawn": null, "seeded": true}
