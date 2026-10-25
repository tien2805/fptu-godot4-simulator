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
class_name StoryCast
extends RefCounted

const IDS: Array[String] = ["hero", "mr_t", "phuc", "linh", "chu_bay", "clone", "clone_masked", "dolly_disguised",
	"dolly_unmasked", "dolly", "courier_vang", "courier_do", "courier_xanh", "shiba"]
const MASKED: Array[String] = ["clone_masked", "dolly"]
const SHIBA_NAME: String = "Lu"
const CREAM := Color("#EADCBD")          # Dolly's wool cardigan / cuff
const CLONE_SHIRT := Color("#E9EEF2")
const CLONE_TROUSERS := Color("#4A5160")

const _SPEAKERS: Dictionary = {"hero": "", "mr_t": "Mr.T", "phuc": "Phúc", "linh": "Linh", "chu_bay": "Chú Bảy",
	"clone": "Nhân bản", "clone_masked": "Nhân bản", "dolly_disguised": "???", "dolly_unmasked": "Cừu Dolly", "dolly": "Cừu Dolly",
	"courier_vang": "Shipper Mũ Vàng", "courier_do": "Shipper Mũ Đỏ", "courier_xanh": "Shipper Mũ Xanh", "shiba": SHIBA_NAME}
const _COLORS: Dictionary = {"hero": Color("#F37021"), "mr_t": Color("#B98CFF"), "phuc": Color("#FF9A3C"), "linh": Color("#4FD1C5"),
	"chu_bay": Color("#7FB2E5"), "clone": Color("#D8DCE0"), "clone_masked": Color("#F4F1EA"), "dolly_disguised": Color("#D8DCE0"),
	"dolly_unmasked": Color("#F2D7A6"), "dolly": Color("#F2D7A6"), "courier_vang": Color("#F1C40F"), "courier_do": Color("#FF6B5A"),
	"courier_xanh": Color("#5DADE2"), "shiba": Color("#E8A25A")}


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


## Dolly's tells: a cream wool cuff on the left wrist and (keychain = true) a small sheep keychain at the right hip.
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
