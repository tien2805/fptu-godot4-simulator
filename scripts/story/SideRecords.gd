# File: res://scripts/story/SideRecords.gd
# Best results of the free-roam side activities (plan 2026-11-01-w4-endings.md T5), kept in the unlock file
# (StoryChapters.unlocks_path, section [side]) the way the mission ranks are: one key per activity id with
# {"rank": "S".."C", "time": seconds (races / runs: lower is better), "score": points (higher is better), "runs": count}.
# A result replaces the stored best when its rank is better, or the same rank with a better time / score. Never touches
# the story save; headless runs on the real file are refused (StoryChapters._guarded).
class_name SideRecords
extends RefCounted

const SECTION: String = "side"


static func best(id: String) -> Dictionary:
	var v: Variant = StoryChapters._load(StoryChapters.unlocks_path).get_value(SECTION, id, {})
	return (v as Dictionary).duplicate() if v is Dictionary else {}


static func all() -> Dictionary:
	var cfg: ConfigFile = StoryChapters._load(StoryChapters.unlocks_path)
	var out: Dictionary = {}
	if cfg.has_section(SECTION):
		for k: String in cfg.get_section_keys(SECTION):
			var v: Variant = cfg.get_value(SECTION, k, {})
			if v is Dictionary:
				out[k] = v
	return out


## true when `res` beats `old` (rank first, then time lower / score higher).
static func beats(res: Dictionary, old: Dictionary) -> bool:
	if old.is_empty():
		return true
	var r: String = String(res.get("rank", ""))
	var o: String = String(old.get("rank", ""))
	if r != o:
		return StoryRank.better(r, o)
	if res.has("time") and old.has("time"):
		return float(res["time"]) < float(old["time"])
	return int(res.get("score", 0)) > int(old.get("score", 0))


## Stores `res` ({"rank", "time" | "score"}) for `id` when it is a new best; counts the run either way. true = new best.
static func record(id: String, res: Dictionary) -> bool:
	if StoryChapters._guarded(StoryChapters.unlocks_path) or id == "":
		return false
	var cfg: ConfigFile = StoryChapters._load(StoryChapters.unlocks_path)
	var old: Variant = cfg.get_value(SECTION, id, {})
	var od: Dictionary = (old as Dictionary) if old is Dictionary else {}
	var runs: int = int(od.get("runs", 0)) + 1
	var nb: bool = beats(res, od)
	var keep: Dictionary = res.duplicate() if nb else od.duplicate()
	keep["runs"] = runs
	cfg.set_value(SECTION, id, keep)
	cfg.save(StoryChapters.unlocks_path)
	return nb


## How many side activities hold a best rank of S.
static func s_count() -> int:
	var n: int = 0
	for v: Variant in all().values():
		if String((v as Dictionary).get("rank", "")) == "S":
			n += 1
	return n
