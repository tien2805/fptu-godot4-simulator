# File: res://scripts/story/StoryCast.gd
# The story cast in one place (spec B-D9, story spec section 3): CharacterBuilder opts for every fictional character, the
# speaker name and subtitle colour, and a gameplay builder. Cinematics use opts() in CineTimeline.actor(); gameplay (combat
# enemies, canteen clones, the gate guard) uses build(). All looks are code-built on the PS2 rigged people.
#
#   StoryCast.opts("linh")                 -> {"preset": "student_f", "hair_style": "ponytail", ...}  (rigged body opts)
#   StoryCast.opts("clone", {"seed": 9})   -> extra keys override (here: still the same face, the seed is ignored for clones)
#   StoryCast.build("clone_masked")        -> Node3D: rigged, animated body with the sheep mask on its head bone
#   StoryCast.build("shiba")               -> StoryShiba (code-built dog; play("idle" | "walk" | "bonk"))
#   StoryCast.speaker("chu_bay")           -> "Chú Bảy";  StoryCast.color("dolly") -> subtitle colour
#   StoryCast.masked("dolly")              -> true (cinematics hold a "sheep_mask" prop on the Head bone instead)
#
# Ids:
#   hero            the protagonist (StoryUtil.hero_opts while a story runs, else the default player look)
#   mr_t, phuc      as in the Day 0 timelines (lecturer with glasses; student_m, spiky hair)
#   linh            student_f, ponytail, glasses, crisp navy shirt: sharp and fast
#   chu_bay         campus gate guard: guard preset (light-blue uniform, navy cap); owner of the shiba "Lu"
#   clone           ONE identical student look (same face, hair, outfit, height for every clone)
#   clone_masked    the clone with the white sheep mask (fights, stalkers)
#   dolly_disguised Cừu Dolly hiding among the clones: the clone look plus her tells (cream wool cuff, sheep keychain)
#   dolly_unmasked  Cừu Dolly in her cream wool cardigan, no mask (cine_d4: cornered and unmasked)
#   dolly           Cừu Dolly in the cardigan with the sheep mask (villain card, brawl, mini-boss)
#   courier_vang, courier_do, courier_xanh   the seg_d1_brawl couriers (helmet in the name colour, muted jacket)
#   shiba           Chú Bảy's dog (StoryShiba, not a CharacterBuilder body; opts() returns {})
# Phase C (spec C-D10; the wearables are CinePropsC kinds, listed by gear(id), held on bones in cinematics through
# dress(tl, actor, id) and attached to the body by build(id)):
#   soi_xam         Sói Xám, leader of the Bầy Sói: grey wolf-head helmet with red LED eyes, grey leather jacket
#   bay_soi         a Bầy Sói biker: black jacket, wolf helmet with amber LED eyes (extra "seed" varies the face and build)
#   alexander       Alexander ABCXYZ: teal Hawaiian shirt with flowers, gold sunglasses, slicked side-parted hair, cream
#                   slacks; the cigar-shaped vape is a hand prop (hand_props)
#   za_man          Lê Minh Za Mẫn: black turtleneck, round glasses, man bun, white sneakers
#   anh_duy         Anh Duy "Deploy": big belly, faded FPT-orange hoodie, over-ear headphones, a key lanyard; the energy drink
#                   is a hand prop (hand_props)
#   guard_sheep, guard_wolf, guard_fox   lair guards in black with a sheep / wolf / fox mask
#   mannequins      the smart-glasses mannequin crowd (CineCrowd, not a body; opts() returns {}; build() lays out
#                   extra "cols" x "rows")
#   StoryCast.villain_data("soi_xam" | "alexander" | "za_man") -> StoryVillainCard data (timeline cards or show_for)
class_name StoryCast
extends RefCounted

const IDS: Array[String] = ["hero", "mr_t", "phuc", "linh", "chu_bay", "clone", "clone_masked", "dolly_disguised",
	"dolly_unmasked", "dolly", "courier_vang", "courier_do", "courier_xanh", "shiba",
	"soi_xam", "bay_soi", "alexander", "za_man", "anh_duy", "guard_sheep", "guard_wolf", "guard_fox", "mannequins"]
## Phase C ids (spec C-D10).
const PHASE_C: Array[String] = ["soi_xam", "bay_soi", "alexander", "za_man", "anh_duy", "guard_sheep", "guard_wolf", "guard_fox",
	"mannequins"]
## Ids whose body is not a CharacterBuilder person.
const NOT_PEOPLE: Array[String] = ["shiba", "mannequins"]
## Ids wearing a wolf helmet over a rider body (the rider's own helmet is hidden).
const WOLF_HELMET: Array[String] = ["soi_xam", "bay_soi"]
const SOI_GREY := Color("#5E6268")
const ALEX_SHIRT := Color("#16A39A")
const ZA_BLACK := Color("#141416")
const DUY_HOODIE := Color("#C98A5A")
const GUARD_BLACK := Color("#131316")
## Eye level of the head gear (glasses) above / in front of the Head bone, measured on the PS2 heads (tests: within 2 cm of
## the built-in glasses frame).
const EYE_UP: float = 0.105
const EYE_FRONT: float = -0.128
const MASKED: Array[String] = ["clone_masked", "dolly"]
const SHIBA_NAME: String = "Lu"
const CREAM := Color("#EADCBD")          # Dolly's wool cardigan / cuff
const CLONE_SHIRT := Color("#E9EEF2")
const CLONE_TROUSERS := Color("#4A5160")

const _SPEAKERS: Dictionary = {"hero": "", "mr_t": "Mr.T", "phuc": "Phúc", "linh": "Linh", "chu_bay": "Chú Bảy",
	"clone": "Nhân bản", "clone_masked": "Nhân bản", "dolly_disguised": "???", "dolly_unmasked": "Cừu Dolly", "dolly": "Cừu Dolly",
	"courier_vang": "Shipper Mũ Vàng", "courier_do": "Shipper Mũ Đỏ", "courier_xanh": "Shipper Mũ Xanh", "shiba": SHIBA_NAME,
	"soi_xam": "Sói Xám", "bay_soi": "Bầy Sói", "alexander": "Alexander", "za_man": "Za Mẫn", "anh_duy": "Anh Duy",
	"guard_sheep": "Bảo vệ", "guard_wolf": "Bảo vệ", "guard_fox": "Bảo vệ", "mannequins": "Ma-nơ-canh"}
const _COLORS: Dictionary = {"hero": Color("#F37021"), "mr_t": Color("#B98CFF"), "phuc": Color("#FF9A3C"), "linh": Color("#4FD1C5"),
	"chu_bay": Color("#7FB2E5"), "clone": Color("#D8DCE0"), "clone_masked": Color("#F4F1EA"), "dolly_disguised": Color("#D8DCE0"),
	"dolly_unmasked": Color("#F2D7A6"), "dolly": Color("#F2D7A6"), "courier_vang": Color("#F1C40F"), "courier_do": Color("#FF6B5A"),
	"courier_xanh": Color("#5DADE2"), "shiba": Color("#E8A25A"), "soi_xam": Color("#B8C0C8"), "bay_soi": Color("#9AA3AD"),
		"alexander": Color("#3FE0D0"), "za_man": Color("#C9A0FF"), "anh_duy": Color("#5BD38A"), "guard_sheep": Color("#D0D3D6"),
		"guard_wolf": Color("#D0D3D6"), "guard_fox": Color("#D0D3D6"), "mannequins": Color("#E8E1D6")}


static func has(id: String) -> bool:
	return id in IDS


## CharacterBuilder opts (rigged body) of a cast id; `extra` keys override. {} for "shiba" or an unknown id.
static func opts(id: String, extra: Dictionary = {}) -> Dictionary:
	var o: Dictionary = {}
	match id:
		"hero":
			o = StoryUtil.hero_opts({"preset": "player", "seed": 2805})
		"mr_t":
			o = {"preset": "lecturer", "seed": 1995, "glasses": true}
		"phuc":
			o = {"preset": "student_m", "seed": 77, "hair_style": "spiky"}
		"linh":
			o = {"preset": "student_f", "seed": 4242, "hair_style": "ponytail", "hair_color": 0, "skin": 1, "glasses": true,
				"shirt_color": Color("#22324F"), "trousers_color": Color("#2A2A30"), "height": 1.0, "backpack": false}
		"chu_bay":
			o = {"preset": "guard", "seed": 7007, "skin": 2, "hair_color": 4, "height": 0.97, "width": 1.06}
		"clone", "clone_masked", "dolly_disguised":
			o = _clone_base()
		"dolly", "dolly_unmasked":
			o = _clone_base()
			o["shirt_color"] = CREAM
		"courier_vang":
			o = {"preset": "rider", "seed": 101, "female": false, "body": "hoodie", "backpack": false, "shirt_color": Color("#C9A227"),
				"helmet_color": Color("#F1C40F")}
		"courier_do":
			o = {"preset": "rider", "seed": 102, "female": false, "body": "hoodie", "backpack": false, "shirt_color": Color("#8E2A2A"),
				"helmet_color": Color("#E74C3C")}
		"courier_xanh":
			o = {"preset": "rider", "seed": 103, "female": false, "body": "hoodie", "backpack": false, "shirt_color": Color("#1E8C8C"),
				"helmet_color": Color("#3498DB")}
		"soi_xam":
			o = {"preset": "rider", "seed": 3131, "female": false, "body": "hoodie", "backpack": false, "glasses": false,
				"shirt_color": SOI_GREY, "trousers_color": Color("#17181C"), "helmet_color": Color("#3A3D42"), "height": 1.03,
				"body_width": 1.06, "skin": 2, "hair_color": 0, "hair_style": "short"}
		"bay_soi":
			o = {"preset": "rider", "seed": 3200, "female": false, "body": "hoodie", "backpack": false, "glasses": false,
				"shirt_color": Color("#25282E"), "trousers_color": Color("#1B1C20"), "helmet_color": Color("#25282E"),
				"hair_style": "short"}
		"alexander":
			o = {"preset": "student_m", "seed": 4545, "body": "casual", "backpack": false, "glasses": false, "shirt_color": ALEX_SHIRT,
				"trousers_color": Color("#E8DCC0"), "hair_style": "side_part", "hair_color": 0, "skin": 1, "height": 0.97,
				"width": 1.06, "body_width": 1.12}
		"za_man":
			o = {"preset": "student_m", "seed": 6161, "body": "casual", "backpack": false, "glasses": false, "shirt_color": ZA_BLACK,
				"trousers_color": Color("#2A2A30"), "hair_style": "bun", "hair_color": 0, "skin": 0, "height": 1.02,
				"width": 0.98, "body_width": 0.95}
		"anh_duy":
			o = {"preset": "student_m", "seed": 7272, "body": "casual", "backpack": false, "glasses": false, "shirt_color": DUY_HOODIE,
				"trousers_color": Color("#3A3F4A"), "hair_style": "short", "hair_color": 1, "skin": 2, "height": 0.96,
				"width": 1.14, "body_width": 1.3}
		"guard_sheep", "guard_wolf", "guard_fox":
			o = {"preset": "student_m", "seed": {"guard_sheep": 8101, "guard_wolf": 8202, "guard_fox": 8303}[id], "body": "casual",
				"backpack": false, "glasses": false, "shirt_color": GUARD_BLACK, "trousers_color": GUARD_BLACK, "hair_style": "short",
				"height": 1.0, "body_width": 1.04}
		_:
			return {}
	o.merge(extra, true)
	if id.begins_with("clone") or id.begins_with("dolly"):
		o["seed"] = 5150   # identical face, hair and build whatever the caller passes
	return o


## One identical student look for every clone (all build values pinned, so no random draw differs).
static func _clone_base() -> Dictionary:
	return {"preset": "student_f", "seed": 5150, "female": true, "skin": 1, "hair_color": 1, "hair_style": "bob", "variant": 2,
		"height": 0.98, "width": 1.0, "body_width": 1.0, "glasses": false, "backpack": false, "shirt_color": CLONE_SHIRT,
		"trousers_color": CLONE_TROUSERS}


static func speaker(id: String) -> String:
	if id == "hero":
		return StoryUtil.hero_name()
	return String(_SPEAKERS.get(id, id))


static func color(id: String) -> Color:
	return _COLORS.get(id, Color.WHITE)


static func masked(id: String) -> bool:
	return id in MASKED


## Gameplay body: CharacterBuilder.build(opts(id) + extra) (rigged, animated unless extra says otherwise) with the sheep mask
## (masked ids) and Dolly's tells (dolly_disguised) attached; a StoryShiba for "shiba"; null for an unknown id.
static func build(id: String, extra: Dictionary = {}) -> Node3D:
	if id == "shiba":
		var dog := StoryShiba.new()
		dog.name = "Shiba"
		return dog
	if id == "mannequins":
		var crowd := CineCrowd.new()
		crowd.layout_grid(Vector3.ZERO, int(extra.get("cols", 6)), int(extra.get("rows", 8)), float(extra.get("dx", 0.6)), float(extra.get("dz", 0.6)))
		crowd.set_meta("cast_id", id)
		return crowd
	if not has(id):
		return null
	var o: Dictionary = opts(id, extra)
	o["rigged"] = true
	if not o.has("name"):
		o["name"] = id.to_pascal_case()
	var body: Node3D = CharacterBuilder.build(o)
	if body == null:
		return null
	body.set_meta("cast_id", id)
	if masked(id):
		attach_mask(body)
	if id == "dolly_disguised":
		attach_tells(body)
	if id == "dolly" or id == "dolly_unmasked":
		attach_tells(body, false)   # the cuff stays (it is her cardigan's), the keychain is gone
	if id in PHASE_C:
		attach_gear(body, id)
	return body


## The white sheep mask on the body's head pivot (it follows the head, scaled with it). Returns the mask node.
static func attach_mask(body: Node3D) -> Node3D:
	var head: Node3D = CharacterBuilder.get_pivot(body, "head")
	if head == null:
		return null
	var m: Node3D = CineFX.build_prop("sheep_mask")
	m.name = "SheepMask"
	head.add_child(m)
	var hs: float = maxf(head.scale.y, 0.01)
	m.position = Vector3(0.0, 0.1 / hs, 0.0)
	m.scale = Vector3.ONE / hs * 1.02
	body.set_meta("sheep_mask", m)
	return m


## Dolly's tells: a cream wool cuff on the left wrist and (keychain = true) a small sheep keychain at the right front hip (x -0.16 in the Hips bone frame of the +Z-facing model: measured on the Wrist.R side).
static func attach_tells(body: Node3D, keychain: bool = true) -> void:
	var wool: StandardMaterial3D = CineFX._mat(CREAM, 1.0)
	var hl: Node3D = CharacterBuilder.get_pivot(body, "hand_l")
	if hl:
		var cuff := MeshInstance3D.new()
		cuff.name = "WoolCuff"
		var tm := TorusMesh.new()
		tm.inner_radius = 0.032
		tm.outer_radius = 0.058
		tm.rings = 12
		tm.ring_segments = 6
		cuff.mesh = tm
		cuff.material_override = wool
		cuff.position = Vector3(0.0, -0.03, 0.0)
		hl.add_child(cuff)
		body.set_meta("wool_cuff", cuff)
	if not keychain:
		return
	var hips: Node3D = CharacterBuilder.get_pivot(body, "hips")
	if hips == null:
		return
	var kc := Node3D.new()
	kc.name = "SheepKeychain"
	hips.add_child(kc)
	kc.position = Vector3(-0.16, -0.06, 0.06)
	CineFX._sphere(kc, "Wool", 0.03, Vector3(0.0, -0.05, 0.0), CineFX._mat(Color("#F4F1EA"), 1.0))
	CineFX._sphere(kc, "Face", 0.016, Vector3(0.0, -0.045, 0.026), CineFX._mat(Color("#2B2622"), 0.7))
	CineFX._box(kc, "Ring", Vector3(0.006, 0.04, 0.006), Vector3(0.0, -0.01, 0.0), CineFX._mat(Color("#C9C9C9"), 0.3))
	body.set_meta("sheep_keychain", kc)


# ---------------------------------------------------------------------------
# Phase C gear (spec C-D10)
# ---------------------------------------------------------------------------
## Wearables of a Phase C id: [{kind, bone, offset (m, actor frame, from the bone), opts}, ...]. Hand props (the vape, the
## energy drink) are listed by hand_props(id): cinematics hold them only where the scene wants them.
static func gear(id: String) -> Array:
	var head := Vector3(0.0, 0.06, 0.0)    # the head centre above the Head bone (as the sheep mask)
	var eyes := Vector3(0.0, EYE_UP, EYE_FRONT)
	match id:
		"soi_xam":
			return [{"kind": "wolf_helmet", "bone": "Head", "offset": head, "opts": {"led": Color("#FF2A2A")}}]
		"bay_soi":
			return [{"kind": "wolf_helmet", "bone": "Head", "offset": head, "opts": {"led": Color("#FFB020"), "color": Color("#5C6168")}}]
		"alexander":
			return [{"kind": "gold_shades", "bone": "Head", "offset": eyes, "opts": {}},
				{"kind": "hawaii_print", "bone": "Chest", "offset": Vector3.ZERO, "opts": {"depth": -0.175}}]
		"za_man":
			return [{"kind": "round_glasses", "bone": "Head", "offset": eyes, "opts": {}},
				{"kind": "turtleneck", "bone": "Neck", "offset": Vector3.ZERO, "opts": {}}]
		"anh_duy":
			return [{"kind": "headphones", "bone": "Head", "offset": head + Vector3(0.0, 0.0, 0.01), "opts": {}},
				{"kind": "belly", "bone": "Chest", "offset": Vector3(0.0, -0.36, -0.16), "opts": {"color": DUY_HOODIE.darkened(0.04)}},
				{"kind": "key_lanyard", "bone": "Chest", "offset": Vector3(0.0, 0.0, -0.2), "opts": {}}]
		"guard_sheep":
			return [{"kind": "sheep_mask", "bone": "Head", "offset": head, "opts": {}}]
		"guard_wolf":
			return [{"kind": "wolf_mask", "bone": "Head", "offset": head, "opts": {}}]
		"guard_fox":
			return [{"kind": "fox_mask", "bone": "Head", "offset": head, "opts": {}}]
	return []


## Hand props that belong to a character (gameplay attaches them to the right hand; cinematics hold them where wanted).
static func hand_props(id: String) -> Array:
	match id:
		"alexander":
			return [{"kind": "cigar_vape", "bone": "Wrist.R", "offset": Vector3(0.0, -0.02, -0.05), "opts": {}}]
		"anh_duy":
			return [{"kind": "energy_drink", "bone": "Wrist.R", "offset": Vector3(0.0, -0.03, -0.06), "opts": {}}]
	return []


## Timeline helper: hold every wearable of `id` on `actor` during story [s0, s1) (s1 < 0: the story end), and hide the rider's
## own helmet under a wolf helmet. opts_over: per-kind option overrides (e.g. {"wolf_helmet": {"led_on": false}}).
static func dress(tl: CineTimeline, actor_id: String, id: String, s0: float = 0.0, s1: float = -1.0, opts_over: Dictionary = {}) -> void:
	var e: float = s1 if s1 >= 0.0 else tl.story_end
	for g: Dictionary in gear(id):
		var o: Dictionary = (g["opts"] as Dictionary).duplicate()
		o.merge(opts_over.get(String(g["kind"]), {}), true)
		o["bone"] = String(g["bone"])
		o["offset"] = g["offset"]
		tl.hold(actor_id, s0, e, String(g["kind"]), o)
	if id in WOLF_HELMET:
		tl.part(actor_id, s0, "helmet", false)


## Gameplay: the wearables (and hand props) of `id` on a built body; head gear on the head pivot (like attach_mask), the
## rest on bone attachments turned upright into the character frame. Sets meta "gear" (the nodes).
static func attach_gear(body: Node3D, id: String) -> Array:
	var out: Array = []
	if id in WOLF_HELMET:
		for mi: Node in body.find_children("*", "MeshInstance3D", true, false):
			if mi.has_meta("helmet_part"):
				(mi as MeshInstance3D).visible = false
	var sk: Skeleton3D = body.get_meta("skeleton", null)
	var rs: float = maxf(body.scale.y, 0.01)
	var model: Node3D = body.get_node_or_null("Model") as Node3D   # CharacterBuilder scales it (body_width, 1, body_width)
	var wk: float = maxf(model.scale.x, 0.01) if model else 1.0
	for g: Dictionary in gear(id) + hand_props(id):
		var n: Node3D = CineFX.build_prop(String(g["kind"]), g["opts"])
		n.name = String(g["kind"]).to_pascal_case()
		var off: Vector3 = g["offset"]
		var bone: String = String(g["bone"])
		var head: Node3D = CharacterBuilder.get_pivot(body, "head") if bone == "Head" else null
		if head != null:
			var ps: Vector3 = head.scale * Vector3(rs * wk, rs, rs * wk)   # world scale of the head pivot
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


## StoryVillainCard data for the Phase C villains (timeline cards and StoryVillainCard.show_for in gameplay); the card
## reads in card_len(id) s (0.06 s per character of name + nick + joke, at least 3 s; every card fits a timeline "card"
## freeze of at most 4 s). Alexander's carries "name_run" (the endless rest of his name, run off the band then shrunk to
## fit: StoryVillainCard). Integration, gameplay:
##   StoryVillainCard.show_for(self, StoryCast.villain_data("soi_xam"), StoryCast.card_len("soi_xam"))   # before the duel
##   StoryVillainCard.show_for(self, StoryCast.villain_data("za_man"), StoryCast.card_len("za_man"))     # after "Từ chối"
static func villain_data(id: String) -> Dictionary:
	match id:
		"soi_xam":
			return {"name": "Sói Xám", "nick": "đầu đàn Bầy Sói", "joke": "Hú to, nhạc chuông to hơn.",
				"color": Color("#8E9AA6")}
		"alexander":
			return {"name": "Alexander ABCXYZ", "nick": "trùm bến container", "joke": "Tên dài hơn hợp đồng.",
				"color": Color("#16A39A"), "name_run": " DEFGH IJKLMN OPQRS TUVW XYZ ĐỆ NHẤT"}
		"za_man":
			return {"name": "Lê Minh Za Mẫn", "nick": "CTO · đang pivot", "joke": "Kiếm mua trên mạng.",
				"color": Color("#8E6CC9")}
	return {}


static func card_len(id: String) -> float:
	var d: Dictionary = villain_data(id)
	var n: int = String(d.get("name", "")).length() + String(d.get("nick", "")).length() + String(d.get("joke", "")).length()
	return maxf(3.0, ceilf((0.06 * n) * 10.0) / 10.0)
