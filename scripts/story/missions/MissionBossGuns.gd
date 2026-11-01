# File: res://scripts/story/missions/MissionBossGuns.gd
# Day 7 boss, phase 1 "Phòng bình cổ" (plan 2026-11-01-w4-day7.md T1 / T2): the gunfight in the vase gallery. The twelve
# plinths with their antique vases are the low cover (LairTower: group "cover"). Wave 1: his guards; wave 2: Lùm Văn Lọ
# himself (a high-HP Gunman with CastD7's body, label "Lùm Văn Lọ") behind his desk with two more guards. His villain card
# (CastD7 "van_lo", flag van_lo_card) over the first frame, once. The last knockout is his: "blow", the beat's replay
# seg_d7_phase1 (MissionLairFight's recorder from the last wave), then done; the monologue cinematic follows ("Mọi thứ
# đều nằm trong kế hoạch": he gets up, the lights go out). Down = "TOANG!", retry at the wave checkpoint.
# T2, the signature:
#   - THE VASES ARE COVER WITH HP (vase_max: VASE_HP, Dễ VASE_HP_EASY). A guard's bullet stopped by a plinth chips it
#     (GUARD_CHIP; Gunman.shot "blocked", the same ray again finds the plinth); at half HP the vase cracks (its "Cracks",
#     a glass crack); at 0 it shatters: the vase gone, FxPool debris + the heavy Impact (punch, dust ring, sparks; no
#     hit-stop), a glass crack and a smash, and the plinth crumbles to a STUB_H stub (its collision box and column cut down,
#     bullets fly over it). Its cover slots are taken by the mission for good (gunmen and the player can no longer use them;
#     a player crouched there is pushed out), then GunFight.reprune(). The damage stays after the win (the monologue and the
#     blackout play in the same broken hall); THỬ LẠI restores every vase and plinth.
#   - HIS AIMED VOLLEY: while Lọ stands, every VOLLEY_EVERY s (first VOLLEY_FIRST_S after he shows up) a thin red beam runs
#     from his muzzle to the player (the telegraph, VOLLEY_TELE_S, Dễ VOLLEY_TELE_EASY: it follows the player for
#     VOLLEY_TRACK_K of it, then locks, thicker and brighter, with a click), a warning popup and his line; then VOLLEY_N
#     shots VOLLEY_GAP_S apart down the locked line: a player within VOLLEY_HIT_R of it (and in front of the first wall or
#     plinth) takes GunData.gunman_dmg() x VOLLEY_DMG_K each; a plinth in the line takes VOLLEY_CHIP each (a full volley
#     breaks one: stay in cover and lose it, or step out of the beam). Never damage before the telegraph ends.
#   - A preview cut to Lọ when he shows up (wave 2).
# Test hooks: start_volley() (the telegraph now), damage_vase(i, dmg, dir), cover_vases, volley_state, the counters.
# points: start (+ start_yaw), boss_at, waves [[at...], [at...]], ammo, centre, leash.
class_name MissionBossGuns
extends MissionLairFight

const CARD_FLAG: String = "van_lo_card"
const LO_LABEL: String = "Lùm Văn Lọ"
## His HP in Gunman units (GunData.GUNMAN_HP): Thường / Dễ.
const LO_HP_K: float = 6.0
const LO_HP_K_EASY: float = 4.5
const LO_ACCURACY: float = 1.15
const T_LO_UP: String = "Lùm Văn Lọ ra mặt!"
## T2: the vases.
const VASE_HP: float = 8.0
const VASE_HP_EASY: float = 12.0
const GUARD_CHIP: float = 1.0
const VOLLEY_CHIP: float = 2.0
const STUB_H: float = 0.35
const T_SHATTER: String = "Bình cổ vỡ! Chỗ nấp sập rồi!"
## T2: his aimed volley.
const VOLLEY_FIRST_S: float = 3.0
const VOLLEY_EVERY: float = 7.0
const VOLLEY_EVERY_EASY: float = 9.5
const VOLLEY_TELE_S: float = 1.0
const VOLLEY_TELE_EASY: float = 1.4
const VOLLEY_TRACK_K: float = 0.6
const VOLLEY_N: int = 4
const VOLLEY_GAP_S: float = 0.12
const VOLLEY_HIT_R: float = 0.6
const VOLLEY_DMG_K: float = 0.6
const BEAM_W: float = 0.025
const BEAM_W_LOCK: float = 0.055
const CUT_S: float = 0.6
const T_VOLLEY: String = "Lọ đang ngắm! Né khỏi tia đỏ!"
const VOLLEY_LINES: Array[String] = ["Đứng yên cho thầy chấm điểm.", "Nấp sau bình cổ? Bình đó của thầy đấy.",
	"Bài kiểm tra cuối: né đạn.", "Thầy bắn ít thôi, mà trúng."]

var card: StoryVillainCard = null
var lo: Gunman = null
## Per vase (LairTower.vases order): {"body", "vase", "cs", "size", "cs_y", "prop", "slots" (PackedInt32Array), "hp",
## "cracked", "broken"}.
var cover_vases: Array[Dictionary] = []
var vase_max: float = VASE_HP
var shattered: int = 0
var vase_hits: int = 0
var volley_state: String = "idle"            # idle | wait | tele | fire
var volley_t: float = 0.0
var volley_locked: bool = false
var volleys: int = 0
var volley_shots: int = 0
var volley_hits: int = 0
var cuts: int = 0
var aim_from: Vector3 = Vector3.ZERO
var aim_to: Vector3 = Vector3.ZERO
var beam: MeshInstance3D = null
var _beam_mat: StandardMaterial3D = null
var _body_i: Dictionary = {}                 # plinth body instance id -> vase index
var _next_volley: float = VOLLEY_FIRST_S
var _volley_n: int = 0
var _line_i: int = 0


func _init() -> void:
	armed = true


func _start() -> void:
	place_player()
	make_fight({"start_alerted": true})
	var w: Array = pts.get("waves", [[], []])
	var w1: Array = []
	var i: int = 0
	for at: Variant in (w[0] if w.size() > 0 else []):
		w1.append(guard(i, at))
		i += 1
	fight.add_wave(w1)
	var w2: Array = [{"at": pts.get("boss_at", Vector3.ZERO), "opts": lo_opts()}]
	for at2: Variant in (w[1] if w.size() > 1 else []):
		w2.append(guard(i, at2))
		i += 1
	fight.add_wave(w2)
	for c: String in ["glass_crack", "crate_smash", "freeze_tick"]:
		CineAudio.sfx(c)                     # warmed at the setup, never mid-fight
	_init_vases()
	_build_beam()
	fight.start()
	_show_card()


## Lọ's Gunman opts: his body, his name over his head, his HP.
static func lo_opts() -> Dictionary:
	return {"body_fn": func(_look: Dictionary) -> Node3D: return CastD7.build("van_lo"), "mask": "none", "label": LO_LABEL,
		"hp": GunData.GUNMAN_HP * float(Difficulty.pick(LO_HP_K, LO_HP_K_EASY)), "accuracy": LO_ACCURACY}


func _show_card() -> void:
	var sd: Node = StoryUtil.director()
	var flags: Dictionary = sd.get("flags") if sd else {}
	if bool(flags.get(CARD_FLAG, false)):
		return
	flags[CARD_FLAG] = true
	card = StoryVillainCard.show_for(self, CastD7.villain_data("van_lo"), CastD7.card_len("van_lo"))
	if bool(opts.get("manual_card", false)):
		card.manual = true
	card.finished.connect(func() -> void: card = null, CONNECT_ONE_SHOT)


func _on_wave_started(i: int) -> void:
	super._on_wave_started(i)
	if fight:
		for g: Variant in fight.gunmen:
			if g is Gunman and is_instance_valid(g) and not (g as Gunman).shot.is_connected(_on_guard_shot):
				(g as Gunman).shot.connect(_on_guard_shot)
	lo = null
	_volley_off()
	if fight and i == fight.waves.size() - 1:
		for e: Variant in fight.enemies:
			if e is Gunman and String((e as Gunman).label) == LO_LABEL:
				lo = e
		popup(T_LO_UP, 1.8, WARN)
		if lo:
			volley_state = "wait"
			volley_t = 0.0
			_next_volley = VOLLEY_FIRST_S
			_cut(lo)


## His knockout is the last one (the replay focuses on him).
func _on_enemy_ko(e: Node3D) -> void:
	super._on_enemy_ko(e)
	if e == lo:
		last_ko = e
		_volley_off()


func _lair_tick(dt: float) -> void:
	_tick_volley(dt)


func _cut(target: Node3D) -> void:
	if target == null or not target.is_inside_tree():
		return
	cuts += 1
	var cd: CameraDirector = CameraDirector.live()
	if cd:
		cd.preview_cut(target, CUT_S)


# ---------------------------------------------------------------------------
# The vases: cover with HP
# ---------------------------------------------------------------------------
func _init_vases() -> void:
	vase_max = float(Difficulty.pick(VASE_HP, VASE_HP_EASY))
	cover_vases.clear()
	_body_i.clear()
	var cv: CoverMap = fight.cover if fight else null
	for v: Variant in (level.get("vases") if level else []):
		var d: Dictionary = v
		var body: StaticBody3D = d.get("plinth")
		var vase: Node3D = d.get("node")
		if body == null or vase == null:
			continue
		var cs: CollisionShape3D = null
		var prop: Node3D = null
		for ch: Node in body.get_children():
			if ch is CollisionShape3D:
				cs = ch
			elif ch is Node3D and ch != vase and not (ch is MeshInstance3D):
				prop = ch
		var slots := PackedInt32Array()
		if cv:
			for s: int in cv.count():
				var b: int = cv.slot_box[s]
				if b >= 0 and flat(cv.box_c[b], body.global_position) < 0.2:
					slots.append(s)
		var bs: BoxShape3D = cs.shape as BoxShape3D if cs else null
		_body_i[body.get_instance_id()] = cover_vases.size()
		cover_vases.append({"body": body, "vase": vase, "cs": cs, "size": bs.size if bs else Vector3.ONE,
			"cs_y": cs.position.y if cs else 0.5, "prop": prop, "slots": slots, "hp": vase_max, "cracked": false,
			"broken": false})


## The vase index of a ray hit on a plinth (-1 = something else).
func vase_of(hit: Dictionary) -> int:
	if hit.is_empty():
		return -1
	var c: Variant = hit.get("collider")
	if not (c is Object) or not is_instance_valid(c):
		return -1
	return int(_body_i.get((c as Object).get_instance_id(), -1))


## dmg off vase i: "chip", "crack" (half HP), "shatter" (0) or "none" (already broken).
func damage_vase(i: int, dmg: float, dir: Vector3 = Vector3.FORWARD) -> String:
	if i < 0 or i >= cover_vases.size():
		return "none"
	var v: Dictionary = cover_vases[i]
	if bool(v["broken"]):
		return "none"
	var was: float = float(v["hp"])
	v["hp"] = maxf(0.0, was - dmg)
	vase_hits += 1
	var top: Vector3 = (v["body"] as Node3D).global_position + Vector3(0.0, CinePropsD7.PLINTH_H + 0.25, 0.0)
	var fx: WeaponFX = fight.fx if fight else null
	if float(v["hp"]) <= 0.0:
		_shatter(i, dir)
		return "shatter"
	Impact.particles(self, "dust", top - dir * 0.3, -dir, 0.45, fx)
	if not bool(v["cracked"]) and float(v["hp"]) <= vase_max * 0.5:
		_crack(v, true)
		Impact.sound(self, "glass_crack", top, -6.0)
		return "crack"
	return "chip"


func _crack(v: Dictionary, on: bool) -> void:
	v["cracked"] = on
	var cr: Node3D = (v["vase"] as Node3D).get_node_or_null("Cracks") as Node3D
	if cr:
		for ch: Node in cr.get_children():
			(ch as Node3D).visible = on


func _shatter(i: int, dir: Vector3) -> void:
	var v: Dictionary = cover_vases[i]
	v["broken"] = true
	shattered += 1
	add_stat("vases")
	var body: Node3D = v["body"]
	var top: Vector3 = body.global_position + Vector3(0.0, CinePropsD7.PLINTH_H + 0.25, 0.0)
	(v["vase"] as Node3D).visible = false
	var cs: CollisionShape3D = v["cs"]
	if cs and cs.shape is BoxShape3D:
		var sz: Vector3 = v["size"]
		(cs.shape as BoxShape3D).size = Vector3(sz.x, STUB_H, sz.z)
		cs.position.y = STUB_H * 0.5
	if v["prop"]:
		(v["prop"] as Node3D).scale = Vector3(1.0, STUB_H / CinePropsD7.PLINTH_H, 1.0)
	var fx: WeaponFX = fight.fx if fight else null
	Impact.hit(self, "heavy", {"pos": top, "dir": dir, "fx": fx, "no_hitstop": true, "no_sound": true, "punch_k": 0.6})
	Impact.particles(self, "debris", top, Vector3.UP, 1.4, fx)
	Impact.sound(self, "glass_crack", top, 2.0)
	Impact.sound(self, "crate_smash", top, -3.0)
	if fight:
		var slots: PackedInt32Array = v["slots"]
		if fight.cover_ctl and fight.cover_ctl.in_cover and slots.has(fight.cover_ctl.slot):
			fight.cover_ctl.leave()
		for s: int in slots:
			fight.taken[s] = self
		fight.reprune()
	popup(T_SHATTER, 1.4, WARN)


## Every vase and plinth whole again (THỬ LẠI), the mission's slots freed.
func _restore_vases() -> void:
	for v: Dictionary in cover_vases:
		v["hp"] = vase_max
		v["broken"] = false
		_crack(v, false)
		(v["vase"] as Node3D).visible = true
		var cs: CollisionShape3D = v["cs"]
		if cs and cs.shape is BoxShape3D:
			(cs.shape as BoxShape3D).size = v["size"]
			cs.position.y = float(v["cs_y"])
		if v["prop"]:
			(v["prop"] as Node3D).scale = Vector3.ONE
		if fight:
			for s: int in (v["slots"] as PackedInt32Array):
				if fight.taken.get(s) == self:
					fight.taken.erase(s)
	if fight:
		fight.reprune()


## A guard's bullet stopped by cover: the same ray again (one per shot) finds which plinth took it.
func _on_guard_shot(g: Gunman, result: String) -> void:
	if result != "blocked" or fight == null or not is_instance_valid(g) or state != "running":
		return
	var a: Vector3 = g.muzzle_pos()
	var tp: Vector3 = fight.player_target()
	var i: int = vase_of(fight.ray(a, tp))
	if i >= 0:
		damage_vase(i, GUARD_CHIP, (tp - a).normalized())


# ---------------------------------------------------------------------------
# His aimed volley
# ---------------------------------------------------------------------------
func tele_s() -> float:
	return float(Difficulty.pick(VOLLEY_TELE_S, VOLLEY_TELE_EASY))


func _build_beam() -> void:
	beam = MeshInstance3D.new()
	beam.name = "VolleyBeam"
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	beam.mesh = bm
	_beam_mat = CineFX._glow_mat(Color("#FF2030"), 2.0)
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.material_override = _beam_mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.top_level = true
	beam.visible = false
	add_child(beam)


## The telegraph now (the timer's call; tests call it directly).
func start_volley() -> bool:
	if lo == null or not is_instance_valid(lo) or lo.is_defeated() or fight == null or fight.state != "running":
		return false
	volleys += 1
	volley_state = "tele"
	volley_t = 0.0
	volley_locked = false
	_volley_n = 0
	aim_from = lo.muzzle_pos()
	aim_to = fight.player_target()
	_beam_mat.emission_energy_multiplier = 2.0
	_place_beam(BEAM_W)
	beam.visible = true
	Impact.sound(self, "freeze_tick", aim_from, -2.0)
	popup(T_VOLLEY, 1.2, WARN)
	radio_as("van_lo", VOLLEY_LINES[_line_i % VOLLEY_LINES.size()], "", 2.4)
	_line_i += 1
	return true


func _tick_volley(dt: float) -> void:
	if volley_state == "idle":
		return
	if lo == null or not is_instance_valid(lo) or lo.is_defeated() or fight == null or fight.state != "running":
		_volley_off()
		return
	volley_t += dt
	match volley_state:
		"wait":
			if volley_t >= _next_volley:
				start_volley()
		"tele":
			if not volley_locked:
				aim_from = lo.muzzle_pos()
				aim_to = fight.player_target()
				if volley_t >= tele_s() * VOLLEY_TRACK_K:
					volley_locked = true
					_beam_mat.emission_energy_multiplier = 4.0
					Impact.sound(self, "dry_click", aim_from, 0.0)
			_place_beam(BEAM_W_LOCK if volley_locked else BEAM_W)
			if volley_t >= tele_s():
				volley_state = "fire"
				volley_t = VOLLEY_GAP_S             # the first shot this tick
				beam.visible = false
				_tick_volley(0.0)
		"fire":
			if volley_t >= VOLLEY_GAP_S:
				volley_t = 0.0
				_volley_shot()
				_volley_n += 1
				if _volley_n >= VOLLEY_N:
					volley_state = "wait"
					volley_t = 0.0
					_next_volley = float(Difficulty.pick(VOLLEY_EVERY, VOLLEY_EVERY_EASY))


func _place_beam(w: float) -> void:
	var d: Vector3 = aim_to - aim_from
	var l: float = d.length()
	if l < 0.1:
		return
	var f: Vector3 = d / l
	var b := Basis.looking_at(f, Vector3.UP if absf(f.y) < 0.98 else Vector3.RIGHT)
	b.x *= w
	b.y *= w
	b.z *= l
	beam.global_transform = Transform3D(b, aim_from + d * 0.5)


## One bullet down the locked line: the player in it (before the first wall or plinth) is hit, else a plinth chips.
func _volley_shot() -> void:
	volley_shots += 1
	var fx: WeaponFX = fight.fx
	var dir: Vector3 = (aim_to - aim_from).normalized()
	var end: Vector3 = aim_from + dir * GunData.SHOT_RANGE
	if fx:
		fx.muzzle(aim_from, dir, 1.0)
	fight.play_cue("shot_pistol", aim_from, 0.0)
	var h: Dictionary = fight.ray(aim_from, end)
	var stop: Vector3 = end if h.is_empty() else h["position"]
	var pt: Vector3 = fight.player_target()
	var along: float = (pt - aim_from).dot(dir)
	var off: float = (aim_from + dir * along).distance_to(pt)
	if along > 0.0 and along <= aim_from.distance_to(stop) + 0.3 and off <= VOLLEY_HIT_R:
		GunData.tracer(fx, aim_from, pt)
		if fight.hit_player(lo, GunData.gunman_dmg() * VOLLEY_DMG_K) == "hit":
			volley_hits += 1
		return
	GunData.tracer(fx, aim_from, stop)
	if h.is_empty():
		return
	if fx:
		fx.impact(stop, h["normal"], false)
	var i: int = vase_of(h)
	if i >= 0:
		damage_vase(i, VOLLEY_CHIP, dir)


func _volley_off() -> void:
	volley_state = "idle"
	volley_t = 0.0
	volley_locked = false
	if beam:
		beam.visible = false


func _reset() -> void:
	_volley_off()
	_restore_vases()
	super._reset()


func _cleanup() -> void:
	_volley_off()
	if card and is_instance_valid(card):
		card.queue_free()
	card = null
	super._cleanup()
