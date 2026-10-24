# File: res://scripts/story/StoryMissions.gd
# Mission registry of the story "TOOL ĐEN" as data (spec A2-D3). Each beat:
#   day, title, kind (cine | stage | bed | call | video | day | locked), next (beat id, "" = end of the content so far),
#   objective (phone + HUD line, {name} substituted by StoryDirector), tod (FreeRoam time of day while the beat runs),
#   texts ([sender, text] sent when the beat starts), and per kind:
#   cine / video: slot (timeline / music slot), at (StoryRoam anchor the stage is searched around);
#   stage: stage (StageManager.StageID), anchor (marker), return (anchor of the return spot after a win), replay (short
#          replay music slot), evidence (granted on the win);
#   bed: anchor; call: days (N of "Mày còn N ngày").
# Day 0 is implemented; Days 1-7 have one locked placeholder each (no marker). Anchors are resolved by StoryRoam.
class_name StoryMissions
extends RefCounted

const FIRST: String = "d0_wake"
const KINDS: Array[String] = ["cine", "stage", "bed", "call", "video", "day", "locked"]
const DAY_TITLES: Array[String] = ["Phòng 311", "Shipper bóng đêm", "Bầy Sói", "Bến container", "Cừu nhân bản", "Hầm server",
	"Trà Sữa Lọ", "Học thật, đậu thật"]
const SENDERS: Array[String] = ["Mr.T", "Phúc", "Anh Duy", "Số lạ"]
const EVIDENCE_IDS: Array[String] = ["E1", "E2", "E3", "E4", "E5", "E6", "E7"]
const EVIDENCE: Dictionary = {
	"E1": "Ảnh tai nghe phát sáng xanh (phòng 311)",
	"E2": "Danh sách shipper giao tool",
	"E3": "Trang sổ dưới gầm cầu Rạch Hầm",
	"E4": "Bảng kê hàng container",
	"E5": "Danh sách thi hộ của Cừu Dolly",
	"E6": "Log giao dịch Lọ Thần 9.0",
	"E7": "Sổ cái Trà Sữa Lọ",
}
const LOCKED_SUFFIX: String = "sắp có trong bản cập nhật sau"

const BEATS: Dictionary = {
	"d0_wake": {"day": 0, "title": "Tôi là ai, đây là đâu?", "kind": "cine", "slot": "cine_d0_wake", "at": "be6_door",
		"tod": "morning", "next": "d0_race", "objective": "Dậy đi {name}! Sắp trễ giờ thi EOS rồi"},
	"d0_race": {"day": 0, "title": "Đua tới FPTU", "kind": "stage", "stage": 1, "anchor": "be6_plaza", "return": "room311",
		"replay": "seg_d0_race", "tod": "morning", "next": "d0_exam",
		"objective": "Phóng xe tới FPTU trước 07:30! Tới cột hồng trước sảnh BE6, bấm [E]",
		"texts": [["Phúc", "Ê!!! Thi EOS 8h đó, 7h05 rồi!!!"]]},
	"d0_exam": {"day": 0, "title": "Phòng 311", "kind": "stage", "stage": 7, "anchor": "room311", "return": "room311",
		"replay": "seg_d0_exam", "evidence": "E1", "tod": "morning", "next": "d0_exam_end",
		"objective": "Lên phòng 311 phụ Mr.T coi thi: cột hồng ở sân trong, bấm [E]",
		"texts": [["Mr.T", "{name} ơi, em lên phòng 311 phụ thầy coi thi nhé. Thấy gì lạ thì chụp lại giúp thầy."]]},
	"d0_exam_end": {"day": 0, "title": "Bằng chứng đầu tiên", "kind": "cine", "slot": "cine_d0_exam", "at": "room311",
		"tod": "morning", "next": "d0_bed", "objective": "Mr.T đang đợi ở sân trong"},
	"d0_bed": {"day": 0, "title": "Về BE6 ngủ", "kind": "bed", "anchor": "be6_bed", "tod": "sunset", "next": "d0_midnight",
		"objective": "Một ngày dài… Về BE6 đi ngủ: cột hồng trước sảnh, bấm [E]",
		"texts": [["Mr.T", "Cảm ơn em nhiều, {name}. Ảnh tai nghe thầy gửi Phòng Khảo thí rồi. Về nghỉ sớm nhé!"],
			["Phúc", "Tối nay tao qua BE6 ngủ ké nha mày. Có mì gói chưa?"]]},
	"d0_midnight": {"day": 0, "title": "Nửa đêm ở BE6", "kind": "cine", "slot": "cine_d0_midnight", "at": "be6_door",
		"tod": "night", "next": "d0_call", "objective": "Ngủ đi… nếu ngủ được"},
	"d0_call": {"day": 0, "title": "Cuộc gọi 3 giờ sáng", "kind": "call", "days": 7, "tod": "night", "next": "d0_intro",
		"objective": "Ai gọi giờ này?"},
	"d0_intro": {"day": 0, "title": "TOANG!", "kind": "video", "slot": "ai_intro", "at": "be6_door", "tod": "morning",
		"next": "d1_start", "objective": "Đọc email của Phòng Khảo thí…",
		"texts": [["Số lạ", "Mày… còn… 7 ngày…"]]},
	"d1_start": {"day": 1, "title": "Ngày 1", "kind": "day", "tod": "morning", "next": "d1_locked",
		"texts": [["Mr.T", "Thầy tin em. Tìm bằng chứng đi."]]},
}


## Beat by id: the table above, or a locked placeholder "d<N>_locked" for N 1..7; {} for an unknown id.
static func beat(id: String) -> Dictionary:
	if BEATS.has(id):
		var b: Dictionary = (BEATS[id] as Dictionary).duplicate(true)
		b["id"] = id
		return b
	if id.length() == 9 and id.begins_with("d") and id.ends_with("_locked"):
		var n: int = int(id.substr(1, 1))
		if n >= 1 and n <= 7:
			return {"id": id, "day": n, "title": DAY_TITLES[n], "kind": "locked", "next": "",
				"objective": locked_objective(n)}
	return {}


static func locked_objective(n: int) -> String:
	return "Ngày %d: %s – %s" % [n, DAY_TITLES[clampi(n, 0, 7)], LOCKED_SUFFIX]


static func first_beat() -> String:
	return FIRST


## Every beat id the registry knows (Day 0 table + placeholders 1-7).
static func all_ids() -> PackedStringArray:
	var out := PackedStringArray(BEATS.keys())
	for n: int in range(1, 8):
		out.append("d%d_locked" % n)
	return out


static func evidence_name(id: String) -> String:
	return String(EVIDENCE.get(id, "???"))
