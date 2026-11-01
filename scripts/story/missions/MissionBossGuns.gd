# File: res://scripts/story/missions/MissionBossGuns.gd
# Day 7 boss, phase 1 "Phòng bình cổ" (plan 2026-11-01-w4-day7.md T1 / T2): the gunfight in the vase gallery. The twelve
# plinths with their antique vases are the low cover (LairTower: group "cover"). Wave 1: his guards; wave 2: Lùm Văn Lọ
# himself (a high-HP Gunman with CastD7's body, label "Lùm Văn Lọ") behind his desk with two more guards. His villain card
# (CastD7 "van_lo", flag van_lo_card) over the first frame, once. The last knockout is his: "blow", the beat's replay
# seg_d7_phase1 (MissionLairFight's recorder from the last wave), then done; the monologue cinematic follows ("Mọi thứ
# đều nằm trong kế hoạch": he gets up, the lights go out). Down = "TOANG!", retry at the wave checkpoint.
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

var card: StoryVillainCard = null
var lo: Gunman = null


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
	lo = null
	if fight and i == fight.waves.size() - 1:
		for e: Variant in fight.enemies:
			if e is Gunman and String((e as Gunman).label) == LO_LABEL:
				lo = e
		popup(T_LO_UP, 1.8, WARN)


## His knockout is the last one (the replay focuses on him).
func _on_enemy_ko(e: Node3D) -> void:
	super._on_enemy_ko(e)
	if e == lo:
		last_ko = e


func _cleanup() -> void:
	if card and is_instance_valid(card):
		card.queue_free()
	card = null
	super._cleanup()
