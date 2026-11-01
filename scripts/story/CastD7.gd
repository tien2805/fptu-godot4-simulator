# File: res://scripts/story/CastD7.gd
# Day 7 cast (Phase D, plan 2026-11-01-w4-day7.md): Lùm Văn Lọ, the ring's boss and founder of "Lọ Academy - Học thật, đậu
# thật" (story spec section 3: white suit, pastel-pink shirt, gold chain, gold-rimmed glasses), and the villain cards of
# Day 7 (his first one, and the "return" cards of the floor bosses remixed from earlier days). Kept apart from StoryCast so
# the Day 6 / endings streams can edit that file freely; the ids here are "van_lo" (and the guards / returning villains
# stay StoryCast's).
#   CastD7.opts("van_lo")        CharacterBuilder opts (timeline actors)
#   CastD7.build("van_lo")       a rigged gameplay body with his gear (chain, glasses, pink collar)
#   CastD7.dress(tl, actor)      a timeline: his gear held on the bones
#   CastD7.villain_data(id)      StoryVillainCard data: "van_lo", "soi_xam_back", "alexander_back", "za_man_back"
#   CastD7.card_len(id)          its reading time (as StoryCast.card_len)
#   CastD7.RADIO                 the Day 7 radio chatter per beat (StoryRadio.lines falls back to it), RADIO_PREFIX the
#                                speaker label of Lọ on the tower's speakers
class_name CastD7
extends RefCounted

const WHITE_SUIT := Color("#F2EFE8")
const PINK := Color("#F6B8CF")
const GOLD := Color("#D4AF37")
const SPEAKER: String = "Lùm Văn Lọ"
const COLOR := Color("#E8C15A")
const RADIO_PREFIX: Dictionary = {"van_lo": "LÙM VĂN LỌ (loa)"}
## beat id -> [[t (mission seconds), speaker, line, dich], ...] (StoryRadio.SCRIPTS shape).
const RADIO: Dictionary = {
	"d7_parking": [
		[7.0, "anh_duy", "Hầm B3 là ring road một chiều, Bầy Sói đang farm vòng ở đó. Đá văng hết r lên tầng.", "Đá hết tụi nó ở hầm xe rồi đi lên."],
		[24.0, "van_lo", "Chào mừng tới Lọ Academy. Gửi xe miễn phí, lấy xe thì... hơi khó.", ""]],
	"d7_warehouse": [
		[22.0, "van_lo", "Alexander, em đã ký hợp đồng 12 tháng. Đừng làm thầy thất vọng.", ""]],
	"d7_servers": [
		[5.0, "anh_duy", "Za Mẫn đổi katana mới, hàng 49 nghìn freeship, gãy nhanh lắm.", "Kiếm dỏm, đỡ vài nhát là gãy."]],
	"d7_mannequins": [
		[24.0, "van_lo", "Ma-nơ-canh ở đây đứng im giỏi hơn sinh viên ngồi thi.", ""]],
	"d7_lasers": [
		[3.0, "anh_duy", "Laser bật theo chu kỳ, nháy trước khi bật. Canh nhịp mà qua.", "Đèn nháy là sắp bật, chờ tắt rồi đi."],
		[18.0, "van_lo", "Hệ thống an ninh này thầy mua bằng tiền bán đề năm ngoái.", ""]],
	"d7_boss1": [
		[6.0, "van_lo", "Bình cổ đó em. Bắn trúng cái nào là trừ vào học phí cái đó.", ""],
		[20.0, "anh_duy", "Bình vỡ là mất chỗ núp, đừng núp một chỗ lâu.", "Bình chỉ chắn được vài phát."]],
	"d7_boss2": [
		[3.0, "anh_duy", "Nó cắt điện cả tầng r. Bấm F bật đèn pin, rọi thẳng mặt nó.", "Bật đèn pin [F], rọi vào nó."],
		[11.0, "van_lo", "Trong bóng tối, ai cũng là học sinh cá biệt.", ""],
		[27.0, "anh_duy", "Có hai cầu dao trên tường, giữ E để bật lại điện.", "Bật hai cầu dao để có điện lại."]],
	"d7_boss3": [
		[3.0, "van_lo", "Lên tới đây rồi à. Thầy dạy em bài cuối.", ""],
		[16.0, "anh_duy", "Trời mưa sàn trơn, né là trượt xa hơn đó.", "Sàn ướt, né sẽ trượt dài."]],
	"d7_typing": [
		[2.0, "anh_duy", "A mở cổng vào hệ thống thi r, e kill hết process của Lọ Thần 10.0 đi!", "Gõ đúng tên tiến trình để xóa tool trước 08:00."],
		[30.0, "van_lo", "Bản 10.0 có AI đó em. AI của thầy học thật, đậu thật.", ""]],
}


static func opts(id: String = "van_lo", extra: Dictionary = {}) -> Dictionary:
	var o: Dictionary = {}
	match id:
		"van_lo":
			o = {"preset": "lecturer", "seed": 7979, "female": false, "body": "suit", "backpack": false, "glasses": false,
				"shirt_color": WHITE_SUIT, "trousers_color": WHITE_SUIT.darkened(0.06), "hair_style": "side_part",
				"hair_color": 0, "skin": 1, "height": 1.0, "width": 1.08, "body_width": 1.16}
		_:
			return {}
	o.merge(extra, true)
	return o


## The wearables: [kind, bone, offset, opts] (CinePropsD7 kinds).
static func gear(id: String = "van_lo") -> Array:
	if id != "van_lo":
		return []
	return [{"kind": "gold_glasses", "bone": "Head", "offset": Vector3(0.0, StoryCast.EYE_UP, StoryCast.EYE_FRONT), "opts": {}},
		{"kind": "pink_collar", "bone": "Neck", "offset": Vector3.ZERO, "opts": {}},
		{"kind": "gold_chain", "bone": "Chest", "offset": Vector3(0.0, 0.02, -0.16), "opts": {}}]


## Gameplay body (rigged, animated) with his gear on the bones.
static func build(id: String = "van_lo", extra: Dictionary = {}) -> Node3D:
	var o: Dictionary = opts(id, extra)
	if o.is_empty():
		return null
	o["rigged"] = true
	if not o.has("name"):
		o["name"] = "LumVanLo"
	var body: Node3D = CharacterBuilder.build(o)
	if body == null:
		return null
	body.set_meta("cast_id", id)
	_attach(body, gear(id))
	return body


## Timeline helper: every wearable held on `actor_id` during [s0, s1) (s1 < 0: the story end).
static func dress(tl: CineTimeline, actor_id: String, s0: float = 0.0, s1: float = -1.0) -> void:
	var e: float = s1 if s1 >= 0.0 else tl.story_end
	for g: Dictionary in gear():
		var o: Dictionary = (g["opts"] as Dictionary).duplicate()
		o["bone"] = String(g["bone"])
		o["offset"] = g["offset"]
		tl.hold(actor_id, s0, e, String(g["kind"]), o)


## StoryCast.attach_gear for a custom gear list (head gear on the head pivot, the rest on bone attachments).
static func _attach(body: Node3D, list: Array) -> Array:
	var out: Array = []
	var sk: Skeleton3D = body.get_meta("skeleton", null)
	var rs: float = maxf(body.scale.y, 0.01)
	var model: Node3D = body.get_node_or_null("Model") as Node3D
	var wk: float = maxf(model.scale.x, 0.01) if model else 1.0
	for g: Dictionary in list:
		var n: Node3D = CineFX.build_prop(String(g["kind"]), g["opts"])
		n.name = String(g["kind"]).to_pascal_case()
		var off: Vector3 = g["offset"]
		var bone: String = String(g["bone"])
		var head: Node3D = CharacterBuilder.get_pivot(body, "head") if bone == "Head" else null
		if head != null:
			var ps: Vector3 = head.scale * Vector3(rs * wk, rs, rs * wk)
			head.add_child(n)
			n.position = Vector3(off.x / ps.x, (off.y / rs + 0.045) / head.scale.y, off.z / ps.z)
			n.scale = Vector3.ONE / ps
		elif sk != null and sk.find_bone(bone) >= 0:
			var att := BoneAttachment3D.new()
			att.name = "Gear_" + bone.replace(".", "")
			att.bone_name = bone
			sk.add_child(att)
			var up := Node3D.new()
			up.name = "Upright"
			up.basis = sk.get_bone_global_rest(sk.find_bone(bone)).basis.orthonormalized().inverse() * Basis(Vector3.UP, PI)
			att.add_child(up)
			up.add_child(n)
			n.position = Vector3(off.x / (rs * wk), off.y / rs, off.z / (rs * wk))
			n.scale = Vector3(1.0 / (rs * wk), 1.0 / rs, 1.0 / (rs * wk))
		else:
			n.free()
			continue
		out.append(n)
	body.set_meta("gear", out)
	return out


## StoryVillainCard data (plain text). The "_back" cards are the floor bosses' return (Day 7 remixes).
static func villain_data(id: String) -> Dictionary:
	match id:
		"van_lo":
			return {"name": "Lùm Văn Lọ", "nick": "hiệu trưởng Lọ Academy", "joke": "Học thật, đậu thật. Tool thật.",
				"color": COLOR}
		"soi_xam_back":
			return {"name": "Sói Xám", "nick": "tái xuất · đã sửa pô", "joke": "Hú to gấp đôi, nợ gấp ba.",
				"color": Color("#8E9AA6")}
		"alexander_back":
			return {"name": "Alexander ABCXYZ", "nick": "tái xuất · xe nâng mới", "joke": "Xe nâng trả góp 0 %.",
				"color": Color("#16A39A"), "name_run": " DEFGH IJKLMN OPQRS TUVW XYZ ĐỆ NHẤT"}
		"za_man_back":
			return {"name": "Lê Minh Za Mẫn", "nick": "tái xuất · katana 49 nghìn", "joke": "Hàng freeship, bảo hành bằng niềm tin.",
				"color": Color("#8E6CC9")}
	return {}


static func card_len(id: String) -> float:
	var d: Dictionary = villain_data(id)
	var n: int = String(d.get("name", "")).length() + String(d.get("nick", "")).length() + String(d.get("joke", "")).length()
	var run: int = String(d.get("name_run", "")).length()
	return clampf(ceilf((0.06 * n + 0.02 * run) * 10.0 - 0.001) / 10.0, 3.0, 4.0)
