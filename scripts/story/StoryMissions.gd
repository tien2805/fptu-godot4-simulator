# File: res://scripts/story/StoryMissions.gd
# Mission registry of the story "TOOL ĐEN" as data (spec A2-D3). Each beat:
#   day, title, kind (cine | stage | bed | call | video | day | locked), next (beat id, "" = end of the content so far),
#   objective (phone + HUD line, {name} substituted by StoryDirector), tod (FreeRoam time of day while the beat runs),
#   texts ([sender, text] sent when the beat starts), and per kind:
#   cine / video: slot (timeline / music slot), at (StoryRoam anchor the stage is searched around);
#   stage: optional intro (mission-intro cinematic played on [E] before the stage, once; A2-D17);
#   stage: stage (StageManager.StageID), anchor (marker), return (anchor of the return spot after a win), replay (short
#          replay music slot), evidence (granted on the win);
#   bed: anchor; call: days (N of "Mày còn N ngày").
# Phase B (plan 2026-10-25-phase-b-integration.md) adds:
#   mission: mission (StoryRoam mission id: stakeout | chase | corridor | canteen), anchor (marker / start spot);
#   fight: fight (d1 | d4, MeleeFight), anchor; horror: anchor (marker), replay (seg_d4_escape), scene (Night Building);
#   optional on mission / fight: intro (cinematic played once on [E]), auto (starts right after the previous beat when it
#   was entered live, otherwise a marker at anchor), after (cinematic played on the win before the next beat), replay;
#   cine + anchor: the cinematic waits for [E] at a marker; slot_by_choice {"id", <key>: slot}: a branch tail;
#   side: optional side markers [{id, anchor, title, need (flag), evidence, line}] shown while the beat runs (E2 locker);
#   flag: set on the win (d1_key: Mũ Đỏ drops the locker key); placeholder: bed beat of a day that is not built yet.
# Day 0, Day 1 and Day 4 are implemented, Days 2-3 are sleepable placeholders, Day 5 ends on a locked placeholder; old
# saves at d1_locked..d4_locked resume at that day's first beat (migrate). Anchors are resolved by StoryRoam.
class_name StoryMissions
extends RefCounted

const FIRST: String = "d0_wake"
const KINDS: Array[String] = ["cine", "stage", "bed", "call", "video", "day", "locked", "mission", "fight", "horror"]
const MISSIONS: Array[String] = ["stakeout", "chase", "corridor", "canteen"]
const FIGHTS: Array[String] = ["d1", "d4"]
## A2 saves stopped at the Day 1 placeholder: they resume at the day's first playable beat (B-D6: old saves keep working).
const MIGRATE: Dictionary = {"d1_locked": "d1_stakeout", "d2_locked": "d2_wait", "d3_locked": "d3_wait", "d4_locked": "d4_canteen"}
const HORROR_SCENE: String = "res://scenes/story/StoryNightEscape.tscn"
const PLACEHOLDER_SUFFIX: String = "Về BE6 ngủ để sang ngày tiếp."
const DAY_TITLES: Array[String] = ["Phòng 311", "Shipper bóng đêm", "Bầy Sói", "Bến container", "Cừu nhân bản", "Hầm server",
	"Trà Sữa Lọ", "Học thật, đậu thật"]
const SENDERS: Array[String] = ["Mr.T", "Phúc", "Linh", "Anh Duy", "Số lạ"]
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
## E2 (B-D5 beat 7, optional): the locker key Mũ Đỏ dropped in the brawl opens a campus locker with the courier list.
const LOCKER_SIDE: Dictionary = {"id": "d1_locker", "anchor": "locker", "title": "Tủ đồ của Mũ Đỏ (tùy chọn)",
	"need": "d1_key", "evidence": "E2", "line": "Chìa khóa của Mũ Đỏ mở được tủ này… bên trong là danh sách shipper!"}

const BEATS: Dictionary = {
	"d0_wake": {"day": 0, "title": "Tôi là ai, đây là đâu?", "kind": "cine", "slot": "cine_d0_wake", "at": "be6_door",
		"tod": "morning", "next": "d0_race", "objective": "Dậy đi {name}! Sắp trễ giờ thi EOS rồi"},
	"d0_race": {"day": 0, "title": "Đua tới FPTU", "kind": "stage", "stage": 1, "anchor": "be6_plaza", "return": "room311",
		"replay": "seg_d0_race", "tod": "morning", "next": "d0_exam",
		"objective": "Phóng xe tới FPTU trước 07:30! Tới cột hồng trước sảnh BE6, bấm [E]",
		"texts": [["Phúc", "Ê!!! Thi EOS 8h đó, 7h05 rồi!!!"]]},
	"d0_exam": {"day": 0, "title": "Phòng 311", "kind": "stage", "stage": 7, "anchor": "room311", "return": "room311",
		"replay": "seg_d0_exam", "evidence": "E1", "intro": "cine_d0_brief", "tod": "morning", "next": "d0_exam_end",
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
		"texts": [["Số lạ", "Mày… còn… 7 ngày…"], ["Mr.T", "Thầy tin em. Tìm bằng chứng đi."]]},
	"d1_start": {"day": 1, "title": "Ngày 1", "kind": "day", "tod": "morning", "next": "d1_morning"},
	# day start (A2-D17): the parameterized cine_day_start with the day's first text; later days add dN_start / dN_morning
	"d1_morning": {"day": 1, "title": "Sáng Ngày 1", "kind": "cine", "slot": "cine_day_start", "at": "be6_door",
		"tod": "morning", "next": "d1_stakeout", "objective": "Ngày mới… còn 7 ngày để minh oan",
		"texts": [["Phúc", "Ê, tao nghe chuyện rồi… tối nay gặp ở campus nhé."]]},
	# ----- Day 1 "Shipper bóng đêm" (B-D5), night on the real map -----
	"d1_stakeout": {"day": 1, "title": "Rình bãi xe", "kind": "mission", "mission": "stakeout", "anchor": "campus_gate",
		"intro": "cine_d1_intro", "tod": "night", "next": "d1_chase",
		"objective": "Tối nay Mr.T hẹn ở cổng chính FPTU: cột hồng trước cổng, bấm [E]",
		"texts": [["Mr.T", "{name}, 8 giờ tối ra cổng chính trường gặp thầy. Có vụ shipper giao tool."]]},
	"d1_chase": {"day": 1, "title": "Đuổi theo Mũ Đỏ", "kind": "mission", "mission": "chase", "anchor": "chase_start",
		"auto": true, "replay": "seg_d1_chase", "tod": "night", "next": "d1_brawl",
		"objective": "Shipper Mũ Đỏ bỏ chạy! Bám theo, đừng để cách quá 25 m"},
	"d1_brawl": {"day": 1, "title": "Ba shipper", "kind": "fight", "fight": "d1", "anchor": "west_gate", "auto": true,
		"after": "seg_d1_brawl", "flag": "d1_key", "tod": "night", "next": "d1_corridor",
		"win_line": "Mũ Đỏ đánh rơi một chiếc chìa khóa tủ đồ. Tủ ở sân trong, ghé mở thử không?",
		"objective": "Ba shipper chặn đường! Hạ hết bọn nó bằng tay không"},
	"d1_corridor": {"day": 1, "title": "Hành lang tối", "kind": "mission", "mission": "corridor", "anchor": "corridor",
		"after": "cine_d1_corridor", "tod": "night", "next": "d1_choice",
		"objective": "Phúc hẹn ở sân trong. Đi qua hành lang tầng trệt: cột hồng ở sân trong, bấm [E]",
		"texts": [["Phúc", "Tao đang ở sân trong, qua hành lang tầng trệt nha. Có chuyện muốn nói."]]},
	"d1_choice": {"day": 1, "title": "Phúc thú nhận", "kind": "cine", "slot": "cine_d1_choice", "at": "", "anchor": "bench", "choice": "phuc",
		"tod": "night", "next": "d1_choice_tail", "side": [LOCKER_SIDE],
		"objective": "Phúc đang ngồi ghế đá ở sân trong: cột hồng, bấm [E]"},
	"d1_choice_tail": {"day": 1, "title": "Lựa chọn 1", "kind": "cine", "slot": "cine_d1_choice_cover", "at": "",
		"slot_by_choice": {"id": "phuc", "cover": "cine_d1_choice_cover", "report": "cine_d1_choice_report"},
		"tod": "night", "next": "d1_end", "objective": "Phúc…"},
	"d1_end": {"day": 1, "title": "Sói Xám", "kind": "cine", "slot": "cine_d1", "at": "", "tod": "night", "next": "d1_bed",
		"objective": "Điện thoại của shipper có tin nhắn lạ…"},
	"d1_bed": {"day": 1, "title": "Về BE6 ngủ", "kind": "bed", "anchor": "be6_bed", "tod": "night", "next": "d1_call",
		"side": [LOCKER_SIDE], "objective": "Khuya rồi. Về BE6 đi ngủ: cột hồng trước sảnh, bấm [E]",
		"texts": [["Mr.T", "Sói Xám, Nguyễn Xiển… thầy ghi lại rồi. Em về nghỉ đi, {name}."]]},
	"d1_call": {"day": 1, "title": "Cuộc gọi 3 giờ sáng", "kind": "call", "days": 6, "tod": "night", "next": "d2_start",
		"objective": "Lại là số lạ…"},
	# ----- Days 2 and 3: placeholders (B-D6) -----
	"d2_start": {"day": 2, "title": "Ngày 2", "kind": "day", "tod": "morning", "next": "d2_morning"},
	"d2_morning": {"day": 2, "title": "Sáng Ngày 2", "kind": "cine", "slot": "cine_day_start", "at": "be6_door",
		"tod": "morning", "next": "d2_wait", "objective": "Ngày mới… còn 6 ngày",
		"texts": [["Phúc", "Hôm nay tao lo vụ Bầy Sói, mày nghỉ đi."]]},
	"d2_wait": {"day": 2, "title": "Về BE6 ngủ", "kind": "bed", "anchor": "be6_bed", "tod": "sunset", "next": "d2_call",
		"placeholder": true, "objective": ""},
	"d2_call": {"day": 2, "title": "Cuộc gọi 3 giờ sáng", "kind": "call", "days": 5, "tod": "night", "next": "d3_start",
		"objective": "Lại là số lạ…"},
	"d3_start": {"day": 3, "title": "Ngày 3", "kind": "day", "tod": "morning", "next": "d3_morning"},
	"d3_morning": {"day": 3, "title": "Sáng Ngày 3", "kind": "cine", "slot": "cine_day_start", "at": "be6_door",
		"tod": "morning", "next": "d3_wait", "objective": "Ngày mới… còn 5 ngày",
		"texts": [["Mr.T", "Thầy đang xem bảng kê container, em chờ nhé."]]},
	"d3_wait": {"day": 3, "title": "Về BE6 ngủ", "kind": "bed", "anchor": "be6_bed", "tod": "sunset", "next": "d3_call",
		"placeholder": true, "objective": ""},
	"d3_call": {"day": 3, "title": "Cuộc gọi 3 giờ sáng", "kind": "call", "days": 4, "tod": "night", "next": "d4_start",
		"objective": "Lại là số lạ…"},
	# ----- Day 4 "Cừu nhân bản" (B-D7) -----
	"d4_start": {"day": 4, "title": "Ngày 4", "kind": "day", "tod": "morning", "next": "d4_morning"},
	"d4_morning": {"day": 4, "title": "Sáng Ngày 4", "kind": "cine", "slot": "cine_day_start", "at": "be6_door",
		"tod": "morning", "next": "d4_canteen", "objective": "Ngày mới… còn 4 ngày",
		"texts": [["Linh", "Tao là Linh, bạn Phúc. Trưa ra căn tin nhé."]]},
	"d4_canteen": {"day": 4, "title": "Nằm vùng căn tin", "kind": "mission", "mission": "canteen", "anchor": "canteen",
		"intro": "cine_d4_intro", "tod": "noon", "next": "d4_stare",
		"objective": "Linh đợi ở căn tin: cột hồng trước căn tin, bấm [E]"},
	"d4_stare": {"day": 4, "title": "Giờ đóng cửa", "kind": "cine", "slot": "cine_d4_stare", "at": "", "tod": "sunset",
		"next": "d4_brawl", "objective": "Căn tin im phăng phắc…"},
	"d4_brawl": {"day": 4, "title": "Bầy cừu", "kind": "fight", "fight": "d4", "anchor": "canteen", "auto": true,
		"after": "seg_d4_brawl", "tod": "sunset", "next": "d4_escape",
		"objective": "Bầy nhân bản xông tới! Hạ chúng, đừng để Dolly thoát"},
	"d4_escape": {"day": 4, "title": "Thoát khỏi tòa nhà", "kind": "horror", "anchor": "lobby", "replay": "seg_d4_escape",
		"scene": HORROR_SCENE, "tod": "night", "next": "d4_end",
		"objective": "Dolly chạy vào tòa nhà! Theo vào: cột hồng trước sảnh, bấm [E]"},
	"d4_end": {"day": 4, "title": "Dolly khai", "kind": "cine", "slot": "cine_d4", "at": "", "tod": "night", "next": "d4_bed",
		"objective": "Dolly bị dồn vào góc…"},
	"d4_bed": {"day": 4, "title": "Về BE6 ngủ", "kind": "bed", "anchor": "be6_bed", "tod": "night", "next": "d4_call",
		"objective": "Có lịch thi hộ và địa chỉ server rồi. Về BE6 ngủ: cột hồng trước sảnh, bấm [E]",
		"texts": [["Linh", "Mai tính tiếp vụ server. Ngủ ngon nha {name}."]]},
	"d4_call": {"day": 4, "title": "Cuộc gọi 3 giờ sáng", "kind": "call", "days": 3, "tod": "night", "next": "d5_start",
		"objective": "Lại là số lạ…"},
	"d5_start": {"day": 5, "title": "Ngày 5", "kind": "day", "tod": "morning", "next": "d5_morning"},
	"d5_morning": {"day": 5, "title": "Sáng Ngày 5", "kind": "cine", "slot": "cine_day_start", "at": "be6_door",
		"tod": "morning", "next": "d5_locked", "objective": "Ngày mới… còn 3 ngày",
		"texts": [["Mr.T", "Lịch thi hộ có rồi. Hôm nay mình tính tiếp."]]},
}


## Beat by id: the table above, or a locked placeholder "d<N>_locked" for N 1..7; {} for an unknown id.
static func beat(id: String) -> Dictionary:
	if BEATS.has(id):
		var b: Dictionary = (BEATS[id] as Dictionary).duplicate(true)
		b["id"] = id
		if bool(b.get("placeholder", false)):
			b["objective"] = placeholder_objective(int(b["day"]))
		return b
	if id.length() == 9 and id.begins_with("d") and id.ends_with("_locked"):
		var n: int = int(id.substr(1, 1))
		if n >= 1 and n <= 7:
			return {"id": id, "day": n, "title": DAY_TITLES[n], "kind": "locked", "next": "",
				"objective": locked_objective(n)}
	return {}


static func locked_objective(n: int) -> String:
	return "Ngày %d: %s – %s" % [n, DAY_TITLES[clampi(n, 0, 7)], LOCKED_SUFFIX]


## B-D6: "Ngày N: <title> – sắp có trong bản cập nhật sau. Về BE6 ngủ để sang ngày tiếp."
static func placeholder_objective(n: int) -> String:
	return "%s. %s" % [locked_objective(n), PLACEHOLDER_SUFFIX]


## The beat an old save's step resumes at (A2 saves at dN_locked of a day that is now playable); `id` otherwise.
static func migrate(id: String) -> String:
	return String(MIGRATE.get(id, id))


static func first_beat() -> String:
	return FIRST


## Every beat id the registry knows (the table + placeholders 1-7).
static func all_ids() -> PackedStringArray:
	var out := PackedStringArray(BEATS.keys())
	for n: int in range(1, 8):
		out.append("d%d_locked" % n)
	return out


## [sender, text] of day N's first text (the dN_morning beat), ["Phúc", ""] when the day has none yet.
static func day_start_text(n: int) -> Array:
	var b: Dictionary = beat("d%d_morning" % n)
	var t: Array = b.get("texts", [])
	return t[0] if not t.is_empty() else ["Phúc", ""]


static func evidence_name(id: String) -> String:
	return String(EVIDENCE.get(id, "???"))
