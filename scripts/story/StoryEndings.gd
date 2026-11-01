# File: res://scripts/story/StoryEndings.gd
# The six endings of "TOOL ĐEN" as data (story spec section 6, plan 2026-11-01-w4-endings.md T1-T3), and the rows of the end
# summary screen. StoryDirector.evaluate_ending picks the letter; this file says what it plays and how it reads.
#   ENDINGS[x] = {"title", "slots" (played in order by StoryEndingRunner and the ending gallery), "line" (one plain line for
#   the summary)}. A slot listed in VIDEO_SLOTS is the owner's AI clip (StoryVideo: user://video/<slot>_m|f.ogv) when the
#   file exists, else its in-engine fallback timeline of the same name (the ai_intro pattern).
#   A = end_a then ai_true_end; F = ending A plus the scholarship scene end_f; C = end_c (Day 5, beat d5_end_c, unchanged).
# summary(state, ranks) -> {"ending", "title", "choices": [[label, value]], "evidence": [[id, name, found]], "ranks":
#   [[title, letter]]}: plain Vietnamese, no emoji; a missing evidence piece reads MISSING_LINE.
class_name StoryEndings
extends RefCounted

const IDS: Array[String] = ["A", "B", "C", "D", "E", "F"]
const VIDEO_SLOTS: Array[String] = ["ai_true_end"]
const ENDINGS: Dictionary = {
	"A": {"title": "Kết A: Minh oan trọn vẹn", "slots": ["end_a", "ai_true_end"],
		"line": "Đủ bảy bằng chứng, giữ được bạn, không nhận một đồng. Buổi kỷ luật thành buổi khen thưởng."},
	"B": {"title": "Kết B: Thắng nhưng mất bạn", "slots": ["end_b"],
		"line": "Được minh oan, nhưng Phúc bị đình chỉ vì bị báo lên."},
	"C": {"title": "Kết C: Kẻ phản diện mới", "slots": ["end_c"],
		"line": "Nhận lời Za Mẫn, thành CEO Lọ Thần 10.0. Câu chuyện dừng ở Ngày 5."},
	"D": {"title": "Kết D: Minh oan nửa vời", "slots": ["end_d"],
		"line": "Án đình chỉ giảm còn cảnh cáo. Lùm Văn Lọ lên trực thăng chạy mất."},
	"E": {"title": "Kết E: Còn cái nịt", "slots": ["end_e"],
		"line": "Chưa đủ bằng chứng. Bị đuổi học, còn đúng cái nịt."},
	"F": {"title": "Kết F: Học thật, đậu thật", "slots": ["end_a", "ai_true_end", "end_f"],
		"line": "Kết A, thêm hạng S ở cả ba màn học. Mr.T trao học bổng."},
}
const MISSING_LINE: String = "Chưa tìm thấy"
const NO_RANK: String = "-"
const CHOICE_ROWS: Array = [
	["phuc", "Lựa chọn 1: Phúc", {"cover": "Bao che cho Phúc", "report": "Báo Phúc cho Mr.T"}],
	["zaman_offer", "Lựa chọn 2: lời mời của Za Mẫn", {"accept": "Nhận lời", "refuse": "Từ chối"}],
	["bribe", "Lựa chọn 3: túi tiền của Thị Lọ", {"take": "Nhận tiền", "refuse": "Từ chối"}],
]
const NOT_ASKED: String = "Chưa tới"


static func has(x: String) -> bool:
	return ENDINGS.has(x)


## The slots ending x plays, in order ([] for an unknown letter).
static func slots(x: String) -> Array[String]:
	var out: Array[String] = []
	for s: Variant in (ENDINGS.get(x, {}) as Dictionary).get("slots", []):
		out.append(String(s))
	return out


static func title(x: String) -> String:
	return String((ENDINGS.get(x, {}) as Dictionary).get("title", "Kết thúc"))


static func line(x: String) -> String:
	return String((ENDINGS.get(x, {}) as Dictionary).get("line", ""))


static func is_video(slot: String) -> bool:
	return slot in VIDEO_SLOTS


## Every slot of every ending, once each (tests, the music doc).
static func all_slots() -> Array[String]:
	var out: Array[String] = []
	for x: String in IDS:
		for s: String in slots(x):
			if not (s in out):
				out.append(s)
	return out


## The rows of the end summary for a finished (or finishing) story state {evidence, choices} and ranks {beat id: letter}.
static func summary(x: String, state: Dictionary, ranks: Dictionary) -> Dictionary:
	var ch: Dictionary = state.get("choices", {}) if state.get("choices", {}) is Dictionary else {}
	var have: Array = state.get("evidence", []) if state.get("evidence", []) is Array else []
	var choices: Array = []
	for row: Array in CHOICE_ROWS:
		var key: String = String(ch.get(String(row[0]), ""))
		choices.append([String(row[1]), String((row[2] as Dictionary).get(key, NOT_ASKED))])
	var ev: Array = []
	for id: String in StoryMissions.EVIDENCE_IDS:
		ev.append([id, StoryMissions.evidence_name(id), id in have])
	var rk: Array = []
	for bid: Variant in StoryRank.MISSIONS.keys():
		var b: Dictionary = StoryMissions.beat(String(bid))
		var t: String = String(b.get("title", String(bid)))
		var letter: String = String(ranks.get(String(bid), ""))
		rk.append(["Ngày %d · %s" % [int(b.get("day", 0)), t], letter if letter != "" else NO_RANK])
	return {"ending": x, "title": title(x), "line": line(x), "choices": choices, "evidence": ev, "ranks": rk,
		"found": ev.filter(func(e: Array) -> bool: return bool(e[2])).size()}


## Lùm Văn Lọ for the ending cinematics: StoryCast's look when the Day 7 stream adds one ("van_lo"), else this one (story
## spec 3.3: white suit, pastel-pink shirt, gold-rimmed glasses, slicked hair).
static func van_lo_opts() -> Dictionary:
	if StoryCast.has("van_lo"):
		return StoryCast.opts("van_lo")
	return {"preset": "student_m", "seed": 9191, "body": "casual", "backpack": false, "glasses": true,
		"shirt_color": Color("#F4F1EA"), "trousers_color": Color("#F4F1EA"), "hair_style": "side_part", "hair_color": 0,
		"skin": 1, "height": 1.0, "width": 1.08, "body_width": 1.16}


const VAN_LO_NAME: String = "Lùm Văn Lọ"
const VAN_LO_COLOR := Color("#FF8FC8")
