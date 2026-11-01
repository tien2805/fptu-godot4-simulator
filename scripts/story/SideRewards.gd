# File: res://scripts/story/SideRewards.gd
# Rewards of the side activities and the story ranks (plan 2026-11-01-w4-endings.md T5e): helmet and jacket colours for
# the bike rider, with plain names, unlocked by the S-rank count (best rank S of each side activity in SideRecords plus
# each story mission with a best rank S in the unlock file). The choice is kept in the unlock file ([side_rewards]) and
# applied when the bike's rider is built (PlayerBike: apply_rider), so it shows from the next ride into the world. The
# phone's "Tủ đồ" tab lists them (StoryPhone).
class_name SideRewards
extends RefCounted

const SECTION: String = "side_rewards"
## {id, name, color, need (S ranks)}; the first of each list is the default and always open.
const HELMETS: Array = [
	{"id": "xanh_fpt", "name": "Xanh FPT", "color": Color("#0066CC"), "need": 0},
	{"id": "cam_fpt", "name": "Cam FPT", "color": Color("#F37021"), "need": 1},
	{"id": "den_nham", "name": "Đen nhám", "color": Color("#1C1D21"), "need": 3},
	{"id": "trang_sua", "name": "Trắng sữa", "color": Color("#EDE6D6"), "need": 5},
	{"id": "vang_kim", "name": "Vàng kim", "color": Color("#D4A62A"), "need": 8},
]
const JACKETS: Array = [
	{"id": "mac_dinh", "name": "Áo mặc định", "color": null, "need": 0},
	{"id": "do_do", "name": "Đỏ đô", "color": Color("#7A1F2B"), "need": 2},
	{"id": "xanh_reu", "name": "Xanh rêu", "color": Color("#4B5B32"), "need": 4},
	{"id": "tim_than", "name": "Tím than", "color": Color("#2E2A5A"), "need": 6},
	{"id": "hong_neon", "name": "Hồng neon", "color": Color("#FF4FA3"), "need": 9},
]


static func items(kind: String) -> Array:
	return HELMETS if kind == "helmet" else JACKETS


## S ranks so far: side activities + story missions.
static func s_count() -> int:
	var n: int = SideRecords.s_count()
	for l: Variant in StoryChapters.best_ranks().values():
		if String(l) == "S":
			n += 1
	return n


static func item(kind: String, id: String) -> Dictionary:
	for it: Dictionary in items(kind):
		if String(it["id"]) == id:
			return it
	return {}


static func is_unlocked(kind: String, id: String, n: int = -1) -> bool:
	var it: Dictionary = item(kind, id)
	return not it.is_empty() and (n if n >= 0 else s_count()) >= int(it["need"])


static func chosen(kind: String) -> String:
	var id: String = String(StoryChapters._load(StoryChapters.unlocks_path).get_value(SECTION, kind, ""))
	return id if is_unlocked(kind, id) else String(items(kind)[0]["id"])


## Picks an unlocked item; false when locked or unknown (or the real file in a headless run).
static func choose(kind: String, id: String) -> bool:
	if not is_unlocked(kind, id) or StoryChapters._guarded(StoryChapters.unlocks_path):
		return false
	var cfg: ConfigFile = StoryChapters._load(StoryChapters.unlocks_path)
	cfg.set_value(SECTION, kind, id)
	cfg.save(StoryChapters.unlocks_path)
	return true


## The rider's look: the chosen helmet colour, the chosen jacket colour as the shirt (the default jacket leaves it).
static func apply_rider(ro: Dictionary) -> void:
	ro["helmet_color"] = item("helmet", chosen("helmet"))["color"]
	var j: Variant = item("jacket", chosen("jacket"))["color"]
	if j is Color:
		ro["shirt_color"] = j


## Plain names of what opens between two S counts ("Mũ Cam FPT", "Áo Đỏ đô").
static func unlocked_between(before: int, after: int) -> Array[String]:
	var out: Array[String] = []
	for kind: String in ["helmet", "jacket"]:
		for it: Dictionary in items(kind):
			var need: int = int(it["need"])
			if need > before and need <= after:
				out.append(("Mũ " if kind == "helmet" else "Áo ") + String(it["name"]))
	return out


## The phone's "Tủ đồ" rows: [text, kind, id, unlocked, chosen].
static func rows() -> Array:
	var n: int = s_count()
	var out: Array = []
	for kind: String in ["helmet", "jacket"]:
		var cur: String = chosen(kind)
		for it: Dictionary in items(kind):
			var on: bool = n >= int(it["need"])
			var t: String = String(it["name"]) if on else "??? · cần %d hạng S" % int(it["need"])
			if String(it["id"]) == cur:
				t += " (đang dùng)"
			out.append([t, kind, String(it["id"]), on, String(it["id"]) == cur])
	return out
