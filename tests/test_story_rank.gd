# File: res://tests/test_story_rank.gd
# Headless test of the Wave 3 ranks (plan 2026-10-30-w3-shared.md, W-3):
#   A  StoryRank scoring: the 19 ranked beats exist in StoryMissions; an unranked beat gives ""; the letter edges (85 / 65 /
#      45); perfect stats give S and the worst give C on every beat; linear criteria; a criterion that does not apply
#      passes its weight on; the optional objective (want / max / min); better() / best_of(); plain-text letters and labels.
# Run:  godot --headless --path . --script tests/test_story_rank.gd
extends SceneTree

const RANKED: Array[String] = ["d1_stakeout", "d1_chase", "d1_brawl", "d1_corridor", "d2_chase", "d2_drift", "d2_bridge",
	"d2_duel", "d3_sneak", "d3_gunfight", "d3_crates", "d3_boss", "d4_canteen", "d4_brawl", "d4_escape", "d5_stealth",
	"d5_gunfight", "d5_hack", "d5_duel"]

var fails: Array[String] = []


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	print("--- TEST STORY RANK (W-3) ---")
	_part_a()
	_end()


static func plain(s: String) -> bool:
	for i: int in s.length():
		var u: int = s.unicode_at(i)
		if u == 0x2026 or u == 0x2605 or u == 0x2606 or (u >= 0x2190 and u <= 0x2BFF) or u >= 0x1F000 or (u >= 0x2600 and u <= 0x27BF):
			return false
	return true


## Stats and info that meet every criterion of a beat.
static func perfect(id: String) -> Array:
	var m: Dictionary = StoryRank.MISSIONS[id]
	var st: Dictionary = {"time": 1.0, "dmg": 0.0, "fails": 0, "ko": 99}
	var info: Dictionary = {}
	if m.has("opt"):
		var o: Dictionary = m["opt"]
		info[String(o["key"])] = o["want"] if o.has("want") else (o["max"] if o.has("max") else o.get("min", true))
	return [st, info]


func _part_a() -> void:
	print("  [part] A scoring")
	_check(StoryRank.MISSIONS.size() == 19, "A: 19 ranked beats (%d)" % StoryRank.MISSIONS.size())
	for id: String in RANKED:
		_check(StoryRank.MISSIONS.has(id), "A: %s is ranked" % id)
		_check(StoryMissions.BEATS.has(id), "A: %s exists in StoryMissions" % id)
	for id2: String in StoryRank.MISSIONS.keys():
		_check(RANKED.has(id2), "A: %s is one of the plan's ranked beats" % id2)
	_check(StoryRank.report("d1_morning", {"time": 10.0}) == "" and StoryRank.evaluate("d0_wake", {}).is_empty(), "A: an unranked beat gives no letter")
	# letter edges
	_check(StoryRank.letter_of(85.0) == "S" and StoryRank.letter_of(84.9) == "A" and StoryRank.letter_of(65.0) == "A"
		and StoryRank.letter_of(64.9) == "B" and StoryRank.letter_of(45.0) == "B" and StoryRank.letter_of(44.9) == "C" and StoryRank.letter_of(0.0) == "C",
		"A: S >= 85, A >= 65, B >= 45, else C")
	# perfect and worst on every beat
	for id3: String in RANKED:
		var pi: Array = perfect(id3)
		var ev: Dictionary = StoryRank.evaluate(id3, pi[0], pi[1])
		_check(ev["letter"] == "S" and is_equal_approx(float(ev["score"]), 100.0), "A: %s perfect -> S 100 (%s %.1f)" % [id3, ev["letter"], float(ev["score"])])
		var worst: Dictionary = {"time": 9999.0, "dmg": 999.0, "fails": 9, "ko": 0}
		var winfo: Dictionary = {}
		var m: Dictionary = StoryRank.MISSIONS[id3]
		if m.has("opt"):
			var o: Dictionary = m["opt"]
			winfo[String(o["key"])] = (not o["want"]) if o.has("want") else (999 if o.has("max") else -999)
		var ew: Dictionary = StoryRank.evaluate(id3, worst, winfo)
		_check(ew["letter"] == "C" and is_equal_approx(float(ew["score"]), 0.0), "A: %s worst -> C 0 (%s %.1f)" % [id3, ew["letter"], float(ew["score"])])
		for l: Dictionary in ew["lines"]:
			_check(plain(String(l["label"])) and plain(String(l["value"])), "A: %s card text is plain (%s %s)" % [id3, l["label"], l["value"]])
	# linear criteria: d1_brawl time [45, 120], dmg [15, 70], fails [0, 2]
	var e1: Dictionary = StoryRank.evaluate("d1_brawl", {"time": 82.5, "dmg": 15.0, "fails": 1})
	var want1: float = 100.0 * (30.0 * 0.5 + 25.0 * 1.0 + 25.0 * 0.5) / 80.0
	_check(absf(float(e1["score"]) - want1) < 0.01, "A: half the time range, no damage over par, one retry -> %.1f (%.1f)" % [want1, float(e1["score"])])
	_check(int(e1["lines"].size()) == 3, "A: d1_brawl has no ko / optional line (%d lines)" % int(e1["lines"].size()))
	# a criterion that does not apply passes its weight on: dmg missing from the stats
	var e2: Dictionary = StoryRank.evaluate("d1_brawl", {"time": 10.0, "fails": 0})
	_check(is_equal_approx(float(e2["score"]), 100.0) and e2["letter"] == "S", "A: missing damage: time and retries carry the whole score (%.1f)" % float(e2["score"]))
	var e3: Dictionary = StoryRank.evaluate("d1_corridor", {"time": 160.0, "fails": 0})
	_check(absf(float(e3["score"]) - 100.0 * 25.0 / 55.0) < 0.01 and e3["letter"] == "B", "A: d1_corridor at par C, no retry -> %.1f B (%.1f %s)" % [100.0 * 25.0 / 55.0, float(e3["score"]), e3["letter"]])
	# missing optional info: no optional line
	var e4: Dictionary = StoryRank.evaluate("d3_sneak", {"time": 70.0, "fails": 0}, {})
	_check(int(e4["lines"].size()) == 2 and e4["letter"] == "S", "A: no done info: the optional objective does not apply")
	# the optional objective: want / max
	var s5: Dictionary = {"time": 70.0, "fails": 0}
	_check(StoryRank.report("d3_sneak", s5, {"spotted": false}) == "S" and StoryRank.report("d3_sneak", s5, {"spotted": true}) == "A",
		"A: d3_sneak spotted costs the optional 20 (S -> A)")
	_check(StoryRank.report("d4_canteen", {"time": 100.0, "fails": 0}, {"wrong": 0}) == "S"
		and StoryRank.report("d4_canteen", {"time": 100.0, "fails": 0}, {"wrong": 2}) == "A", "A: d4_canteen wrong <= 0 (max)")
	# ko and opt share the extra 20: d3_gunfight ko [6, 10]
	var e6: Dictionary = StoryRank.evaluate("d3_gunfight", {"time": 100.0, "dmg": 30.0, "fails": 0, "ko": 8})
	_check(absf(float(e6["score"]) - 100.0 * (30.0 + 25.0 + 25.0 + 20.0 * 0.5) / 100.0) < 0.01, "A: ko halfway between 6 and 10 -> 90 (%.1f)" % float(e6["score"]))
	# better / best_of
	_check(StoryRank.better("S", "A") and StoryRank.better("B", "C") and StoryRank.better("C", "") and not StoryRank.better("A", "A")
		and not StoryRank.better("", "C") and not StoryRank.better("B", "A"), "A: better() orders S > A > B > C > none")
	_check(StoryRank.best_of("B", "A") == "A" and StoryRank.best_of("", "C") == "C" and StoryRank.best_of("S", "S") == "S" and StoryRank.best_of("", "") == "",
		"A: best_of keeps the better letter")
	for L: String in StoryRank.LETTERS:
		_check(L.length() == 1 and L.unicode_at(0) < 128, "A: the letter %s is plain ASCII" % L)
	for k: String in StoryRank.LABELS.keys():
		_check(plain(String(StoryRank.LABELS[k])), "A: label %s is plain text" % k)
	for k2: String in StoryRank.OPT_LABELS.keys():
		_check(plain(String(StoryRank.OPT_LABELS[k2])), "A: optional label %s is plain text" % k2)


func _end() -> void:
	if fails.is_empty():
		print("--- STORY RANK: SUCCESS ---")
		quit(0)
	else:
		print("--- STORY RANK: FAIL (%d) ---" % fails.size())
		quit(1)
