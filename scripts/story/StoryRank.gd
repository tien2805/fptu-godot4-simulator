# File: res://scripts/story/StoryRank.gd
# Wave 3 ranks S / A / B / C (spec 2026-10-27 W-3, plan docs/superpowers/plans/2026-10-30-w3-shared.md T6): static data
# and scoring, plain text only (the letters "S", "A", "B", "C"; no emoji or star glyphs).
#
# ===== API =====
#   StoryRank.report(beat_id, stats, info := {}) -> String   "S" | "A" | "B" | "C", "" for an unranked beat
#   StoryRank.evaluate(beat_id, stats, info := {}) -> Dictionary   {"letter", "score" (0..100), "lines": [{"key",
#       "label", "value" (text), "k" (0..1), "weight"}]} ({} for an unranked beat): the results card reads it
#   StoryRank.best(beat_id) -> String     the best letter recorded (StoryDirector.ranks or the chapter unlock file)
#   StoryRank.better(a, b) -> bool        letter a beats b ("" loses to every letter)
#   StoryRank.MISSIONS                    thresholds per ranked beat id (22 beats of Days 1-6; Day 0 stages keep their own)
# ===============
# Stats (StoryMission.stats; T7 fills them): "time" (s on the mission clock, failed attempts included), "dmg" (HP lost),
# "fails" (retries), "ko" (takedowns where the mission counts them). info = the mission's done info (the optional
# objective reads it).
# Criteria per beat (each scored 0..1, then weighted): time [par S, par C] (s: at or under par S = 1, at or over par C = 0,
# linear between) weight 30; dmg [S, C] (HP) weight 25; fails [S, C] (default [0, 2]: one retry = half) weight 25; the
# optional objective and ko share weight 20 (10 each when both apply): ko [C, S] (at or above S = 1), opt {"key", "want"}
# (equal), {"key", "max"} (at most) or {"key", "min"} (at least). A criterion the beat does not list, or whose value is
# missing from the stats / info, does not apply: its weight goes to the others (the total is renormalised).
# Score = 100 * sum(w * k) / sum(w); S >= 85, A >= 65, B >= 45, else C.
# Thresholds: the stake-out, the foot chase, the canteen, the bike chase and the drift race calibrated by T10 (the
# sloppy-bot harnesses, table in the plan; the bike chase re-calibrated on wave3 after d2fix); the brawls, the corridor,
# the bridge and the escape have no harness yet (provisional); Days 3 and 5 set on wave3 from sim_day3 / sim_day5 (the
# day plans' integration tables); Day 6 from sim_day6 (plan 2026-11-01-w4-day6.md T8; the boat's "dmg" is the hull lost).
class_name StoryRank
extends RefCounted

const LETTERS: Array[String] = ["S", "A", "B", "C"]
const S_AT: float = 85.0
const A_AT: float = 65.0
const B_AT: float = 45.0
const W_TIME: float = 30.0
const W_DMG: float = 25.0
const W_FAILS: float = 25.0
const W_EXTRA: float = 20.0
const FAILS_DEFAULT: Array = [0, 2]
## Card labels (Vietnamese, plain text).
const LABELS: Dictionary = {"time": "Thời gian", "dmg": "Máu mất", "fails": "Thử lại", "ko": "Hạ gục", "opt": "Mục tiêu phụ"}
const OPT_LABELS: Dictionary = {"seen": "Không bị để ý", "shortcut": "Đi đường tắt", "spotted": "Không bị phát hiện",
	"all": "Đập hết thùng", "wrong": "Không giao nhầm món", "leaks": "Không để lọt dữ liệu",
	"breach_clean": "Chặn đột kích không mất máu", "qte_clean": "Kết liễu ngay lần đầu", "domino": "Đổ tủ đè bảo vệ",
	"crane": "Dùng cần cẩu hạ địch", "noticed": "Không để bảo vệ nghi ngờ",
	"staggers": "Rọi đèn chói mắt Lọ"}   # Day 7 (w4-day7)
const T_YES: String = "Đạt"
const T_NO: String = "Chưa"

## Per ranked beat: "time" [par S, par C] s, "dmg" [S, C] HP, "fails" [S, C], "ko" [C, S], "opt" {key, want | max | min}.
const MISSIONS: Dictionary = {
	# Day 1 (T10 calibration)
	"d1_stakeout": {"time": [30.0, 90.0], "opt": {"key": "seen", "max": 0}},
	"d1_chase": {"time": [55.0, 110.0], "opt": {"key": "shortcut", "want": true}},
	"d1_brawl": {"time": [45.0, 120.0], "dmg": [15.0, 70.0]},
	"d1_corridor": {"time": [70.0, 160.0]},
	# Day 2
	"d2_chase": {"time": [100.0, 150.0], "fails": [0.0, 1.5], "ko": [0, 10]},   # re-calibrated on wave3 after d2fix (fewer takedowns)
	"d2_drift": {"time": [70.0, 160.0], "ko": [2, 8]},
	"d2_bridge": {"time": [70.0, 170.0]},
	"d2_duel": {"time": [50.0, 130.0], "dmg": [15.0, 70.0]},
	# Day 3 (set on wave3 from the sim_day3 re-tune on the merged gun core; table in the day3 plan)
	"d3_sneak": {"time": [60.0, 180.0], "dmg": [0.0, 200.0], "opt": {"key": "spotted", "want": false}},
	"d3_gunfight": {"time": [150.0, 350.0], "dmg": [50.0, 400.0], "opt": {"key": "crane", "want": true}},
	"d3_crates": {"time": [30.0, 70.0], "dmg": [0.0, 120.0], "opt": {"key": "all", "want": true}},
	"d3_boss": {"time": [80.0, 200.0], "dmg": [80.0, 400.0], "opt": {"key": "crane", "want": true}},
	# Day 4
	"d4_canteen": {"time": [35.0, 150.0], "opt": {"key": "wrong", "max": 0}},
	"d4_brawl": {"time": [45.0, 120.0], "dmg": [15.0, 70.0]},
	"d4_escape": {"fails": [0.0, 4.0]},   # the catches only (no time across a Continue): 0 S, 1 A, 2 B, 3+ C
	# Day 5 (set on wave3 from the sim_day5 re-tune on the merged gun core; table in the day5 plan)
	"d5_stealth": {"time": [75.0, 180.0], "dmg": [0.0, 150.0], "opt": {"key": "spotted", "want": false}},
	"d5_gunfight": {"time": [120.0, 300.0], "dmg": [40.0, 300.0], "opt": {"key": "domino", "min": 1}},
	"d5_hack": {"time": [110.0, 200.0], "dmg": [0.0, 40.0], "opt": {"key": "breach_clean", "want": true}},
	"d5_duel": {"time": [35.0, 110.0], "dmg": [20.0, 200.0], "opt": {"key": "qte_clean", "want": true}},
	# Day 6 (set from sim_day6, T8 table in the day6 plan; "dmg" of the boat = the hull lost, failed attempts included)
	"d6_shop": {"time": [50.0, 150.0], "opt": {"key": "wrong", "max": 0}},
	"d6_backroom": {"time": [25.0, 90.0], "fails": [0.0, 4.0], "opt": {"key": "noticed", "want": false}},   # ~20 s a try
	"d6_boat": {"time": [66.0, 95.0], "dmg": [30.0, 160.0], "ko": [3, 8]},
	# Day 7 (w4-day7): provisional pars until sim_day7 (plan 2026-11-01-w4-day7.md T5)
	"d7_parking": {"time": [90.0, 170.0], "fails": [0.0, 1.5], "ko": [0, 8]},
	"d7_warehouse": {"time": [80.0, 200.0], "dmg": [80.0, 400.0]},
	"d7_servers": {"time": [30.0, 100.0], "dmg": [20.0, 200.0], "opt": {"key": "qte_clean", "want": true}},
	"d7_mannequins": {"time": [60.0, 160.0], "dmg": [0.0, 150.0], "opt": {"key": "spotted", "want": false}},
	"d7_lasers": {"time": [35.0, 90.0], "fails": [0.0, 3.0]},
	"d7_boss1": {"time": [90.0, 240.0], "dmg": [40.0, 300.0]},
	"d7_boss2": {"time": [50.0, 150.0], "dmg": [0.0, 100.0], "opt": {"key": "staggers", "min": 2}},
	"d7_boss3": {"time": [45.0, 130.0], "dmg": [20.0, 200.0], "opt": {"key": "qte_clean", "want": true}},
	"d7_typing": {"time": [70.0, 160.0], "opt": {"key": "leaks", "max": 0}},
}


static func is_ranked(beat_id: String) -> bool:
	return MISSIONS.has(beat_id)


## The letter for a finished beat ("" when the beat is not ranked).
static func report(beat_id: String, stats: Dictionary, info: Dictionary = {}) -> String:
	var ev: Dictionary = evaluate(beat_id, stats, info)
	return String(ev.get("letter", ""))


## The letter of a score 0..100.
static func letter_of(score: float) -> String:
	if score >= S_AT - 1e-4:
		return "S"
	if score >= A_AT - 1e-4:
		return "A"
	if score >= B_AT - 1e-4:
		return "B"
	return "C"


## The full evaluation (the results card's lines). {} for an unranked beat.
static func evaluate(beat_id: String, stats: Dictionary, info: Dictionary = {}) -> Dictionary:
	if not MISSIONS.has(beat_id):
		return {}
	var m: Dictionary = MISSIONS[beat_id]
	var lines: Array = []
	if m.has("time") and stats.has("time"):
		var t: float = float(stats["time"])
		lines.append({"key": "time", "label": LABELS["time"], "value": _clock(t), "k": _down(t, m["time"]), "weight": W_TIME})
	if m.has("dmg") and stats.has("dmg"):
		var d: float = float(stats["dmg"])
		lines.append({"key": "dmg", "label": LABELS["dmg"], "value": str(roundi(d)), "k": _down(d, m["dmg"]), "weight": W_DMG})
	var f: int = int(stats.get("fails", 0))
	lines.append({"key": "fails", "label": LABELS["fails"], "value": str(f), "k": _down(float(f), m.get("fails", FAILS_DEFAULT)), "weight": W_FAILS})
	var extra: Array = []
	if m.has("ko") and stats.has("ko"):
		var ko: float = float(stats["ko"])
		var kr: Array = m["ko"]
		extra.append({"key": "ko", "label": LABELS["ko"], "value": str(roundi(ko)), "k": _up(ko, kr)})
	if m.has("opt"):
		var o: Dictionary = m["opt"]
		var key: String = String(o.get("key", ""))
		if info.has(key):
			var ok: bool = _opt_met(o, info[key])
			extra.append({"key": "opt", "label": String(OPT_LABELS.get(key, LABELS["opt"])), "value": T_YES if ok else T_NO, "k": 1.0 if ok else 0.0})
	for e: Dictionary in extra:
		e["weight"] = W_EXTRA / float(extra.size())
		lines.append(e)
	var wsum: float = 0.0
	var acc: float = 0.0
	for l: Dictionary in lines:
		wsum += float(l["weight"])
		acc += float(l["weight"]) * float(l["k"])
	var score: float = 100.0 * acc / wsum if wsum > 0.0 else 0.0
	return {"letter": letter_of(score), "score": score, "lines": lines}


## A value where less is better: [good, bad] -> 1 at or under good, 0 at or over bad.
static func _down(v: float, r: Variant) -> float:
	var a: Array = r
	var good: float = float(a[0])
	var bad: float = float(a[1])
	if bad <= good:
		return 1.0 if v <= good else 0.0
	return clampf((bad - v) / (bad - good), 0.0, 1.0)


## A value where more is better: [bad, good] -> 0 at or under bad, 1 at or over good.
static func _up(v: float, r: Array) -> float:
	var bad: float = float(r[0])
	var good: float = float(r[1])
	if good <= bad:
		return 1.0 if v >= good else 0.0
	return clampf((v - bad) / (good - bad), 0.0, 1.0)


static func _opt_met(o: Dictionary, v: Variant) -> bool:
	if o.has("want"):
		return v == o["want"]
	if o.has("max"):
		return float(v) <= float(o["max"]) + 1e-6
	if o.has("min"):
		return float(v) >= float(o["min"]) - 1e-6
	return bool(v)


## "1:05" (minutes:seconds).
static func _clock(t: float) -> String:
	var s: int = maxi(0, roundi(t))
	return "%d:%02d" % [s / 60, s % 60]


## true when letter a beats b ("" loses to every letter, equal letters do not beat each other).
static func better(a: String, b: String) -> bool:
	var ia: int = LETTERS.find(a)
	if ia < 0:
		return false
	var ib: int = LETTERS.find(b)
	return ib < 0 or ia < ib


## The best of two letters ("" when neither is a letter).
static func best_of(a: String, b: String) -> String:
	return a if better(a, b) or (LETTERS.has(a) and a == b) else (b if LETTERS.has(b) else "")


## The best letter recorded for a beat: StoryDirector.ranks (this save) or the chapter unlock file (every playthrough).
static func best(beat_id: String) -> String:
	var ml: MainLoop = Engine.get_main_loop()
	var tree: SceneTree = ml as SceneTree
	var sd: Node = tree.root.get_node_or_null("StoryDirector") if tree != null else null
	var r: String = ""
	if sd != null and "ranks" in sd:
		r = String((sd.get("ranks") as Dictionary).get(beat_id, ""))
	return best_of(r, StoryChapters.best_rank(beat_id))
