# File: res://scripts/story/SideVovinam.gd
# Free-roam Vovinam street fights (plan 2026-11-01-w4-endings.md T5d), on the Phase B melee tech: a MeleeFight on foot,
# bare hands, against a street club in blue Vovinam uniforms, wave after wave, the last one with its master. The traffic is
# parked while it runs (a street fight stops the road), given back after. Won: the rank by the time per opponent and the
# HP left. Knocked out: given up (no retry: try again from the ring).
#   vo_hem   "Lò võ đầu hẻm": three students, then the "Võ sư Ba Đòn" (hp x2.5), on Đỗ Thế Diện (Dễ: two, then hp x2).
#   vo_cau   "Thách đấu dưới chân cầu": three students, then two, then the "Võ sư Lưỡng Long" (hp x2.5), on Nguyễn Văn Tăng.
# API: like SideRace: setup({"roam", "id"}), start(), advance(dt) (auto_tick false in tests), stop(); fight (MeleeFight);
#   signals started(id), finished(id, result {"rank", "time", "hp", "kos"}), failed(id, reason "ko").
class_name SideVovinam
extends Node3D

signal started(id: String)
signal finished(id: String, result: Dictionary)
signal failed(id: String, reason: String)

const GameFXScript = preload("res://scripts/GameFX.gd")
const BLUE := Color("#1F4FA3")
const FIGHTS: Dictionary = {
	"vo_hem": {"title": "Lò võ đầu hẻm", "at": Vector2(1774.0, -17.0),
		"waves": [[["Môn sinh Tí", 1.0], ["Môn sinh Tèo", 1.0], ["Môn sinh Tũn", 1.0]], [["Võ sư Ba Đòn", 2.5]]],
		"waves_easy": [[["Môn sinh Tí", 1.0], ["Môn sinh Tèo", 1.0]], [["Võ sư Ba Đòn", 2.0]]]},
	"vo_cau": {"title": "Thách đấu dưới chân cầu", "at": Vector2(1905.0, -44.0),
		"waves": [[["Môn sinh Lực", 1.0], ["Môn sinh Lượng", 1.0], ["Môn sinh Lì", 1.0]], [["Môn sinh Gắt", 1.2], ["Môn sinh Gỏn", 1.2]],
			[["Võ sư Lưỡng Long", 2.5]]]},
}
const ORDER: Array[String] = ["vo_hem", "vo_cau"]
## w5-side T5b (tests/sim_side_vovinam.gd, the sloppy melee bot): on Thường the club fights like a trained one (CombatData
## "clone" stats overridden: quicker, more often, harder, a guard; the master more so, an opponent with hp_scale >= 2),
## harder to stagger, HP_K more hp, and the player's HP regenerates only after REGEN_DELAY s; Dễ: the plain clone, 4 s.
## Sloppy-bot fails (10 seeds): Thường vo_hem 1.0, vo_cau 2.4 mean; Dễ 0 on every seed.
const STUDENT: Dictionary = {"light_dmg": 14.0, "heavy_dmg": 30.0, "windup": 0.24, "think": Vector2(0.35, 0.9), "cooldown": Vector2(0.5, 1.2),
	"heavy_chance": 0.35, "block_chance": 0.3, "chain": 2, "stagger_max": 75.0}
const MASTER: Dictionary = {"light_dmg": 16.0, "heavy_dmg": 34.0, "windup": 0.22, "think": Vector2(0.3, 0.8), "cooldown": Vector2(0.5, 1.1),
	"heavy_chance": 0.4, "block_chance": 0.35, "dodge_chance": 0.25, "chain": 3, "stagger_max": 110.0}
const ATTACKERS: Array[int] = [2, 2]
const HP_K: Array[float] = [1.4, 1.0]
const REGEN_DELAY: Array[float] = [10.0, CombatData.REGEN_DELAY]
const START_LINE: String = "Vovinam đường phố, nghiêm!"
const RING_M: float = 4.5
## Rank: seconds per opponent at most / HP left at least.
const RANK_T: Dictionary = {"S": 9.0, "A": 13.0, "B": 18.0}
const RANK_HP: Dictionary = {"S": 60.0, "A": 35.0, "B": 0.0}

const HUD_S: float = 0.1
var _hud_t: float = 0.0   # HUD refresh countdown (_hud_tick)
var id: String = ""
var roam: Node = null
var fight: MeleeFight = null
var auto_tick: bool = true
## idle | running | done | failed
var state: String = "idle"
var t: float = 0.0
var kos: int = 0
var total: int = 0
var result: Dictionary = {}
var hud: CanvasLayer = null
var top_label: Label = null
var _traffic_off: bool = false
## The roam's own PlayerCombat and its regen delay before the fight (given back in stop(), on every exit).
var _combat_ref: PlayerCombat = null
var _regen_was: float = CombatData.REGEN_DELAY


static func title(fid: String) -> String:
	return String((FIGHTS.get(fid, {}) as Dictionary).get("title", fid))


static func start_at(fid: String) -> Vector2:
	return (FIGHTS.get(fid, {}) as Dictionary).get("at", Vector2.ZERO)


static func rank_for(sec: float, opponents: int, hp: float) -> String:
	var per: float = sec / maxf(float(opponents), 1.0)
	for l: String in ["S", "A", "B"]:
		if per <= float(RANK_T[l]) and hp >= float(RANK_HP[l]):
			return l
	return "C"


## The waves for the current difficulty (Dễ: "waves_easy" when the fight has them).
static func waves_of(fid: String) -> Array:
	var f: Dictionary = FIGHTS.get(fid, {})
	return f.get("waves_easy", f.get("waves", [])) if Difficulty.easy else f.get("waves", [])


## The stats over the clone's for the current difficulty ({} on Dễ).
static func stats_for(master: bool) -> Dictionary:
	if Difficulty.easy:
		return {}
	return (MASTER if master else STUDENT).duplicate()


func setup(opts: Dictionary) -> void:
	roam = opts.get("roam", null)
	id = String(opts.get("id", "vo_hem"))
	name = "SideVovinam_" + id


func start() -> void:
	var f: Dictionary = FIGHTS.get(id, {})
	if f.is_empty() or roam == null:
		_fail("no_course")
		return
	if bool(roam.get("mounted")) and roam.has_method("dismount_bike"):
		roam.call("dismount_bike")
	var pl: Node3D = roam.get("player")
	var c: Vector3 = pl.global_position if pl else Vector3.ZERO
	var fwd: Vector3 = -pl.global_transform.basis.z if pl else Vector3.FORWARD
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 0.01 else Vector3.FORWARD
	var side: Vector3 = fwd.cross(Vector3.UP).normalized()
	fight = MeleeFight.new()
	fight.name = "VovinamFight"
	add_child(fight)
	fight.setup({"roam": roam, "force_unarmed": true, "max_attackers": int(Difficulty.pick(ATTACKERS[0], ATTACKERS[1])), "start_line": START_LINE,
		"seed": hash(id) & 0xFFFF})
	var k: int = 0
	for w: Array in waves_of(id):
		var spawns: Array = []
		for i: int in w.size():
			var e: Array = w[i]
			var lat: float = (float(i) - (w.size() - 1) * 0.5) * 2.2
			spawns.append({"archetype": "clone", "at": c + fwd * RING_M + side * lat,
				"opts": {"label": String(e[0]), "hp_scale": float(e[1]) * float(Difficulty.pick(HP_K[0], HP_K[1])), "stats": stats_for(float(e[1]) >= 2.0),
					"body": {"shirt_color": BLUE, "trousers_color": BLUE, "seed": 4100 + k}}})
			k += 1
		fight.add_wave(spawns)
	total = k
	fight.enemy_ko.connect(func(_e: MeleeEnemy) -> void: kos += 1)
	fight.enemy_fled.connect(func(_e: MeleeEnemy) -> void: kos += 1)
	fight.won.connect(_on_won)
	fight.lost.connect(func() -> void: _fail("ko"))
	_traffic(false)
	state = "running"
	t = 0.0
	_build_hud()
	fight.start()
	if fight.combat:
		_combat_ref = fight.combat
		_regen_was = fight.combat.regen_delay
		fight.combat.regen_delay = float(Difficulty.pick(REGEN_DELAY[0], REGEN_DELAY[1]))
	started.emit(id)


func advance(dt: float) -> void:
	if state != "running":
		return
	t += dt
	_hud_tick(dt)


func player_hp() -> float:
	var cb: Variant = fight.get("combat") if fight else null
	return float((cb as Object).get("hp")) if cb != null and is_instance_valid(cb) else 0.0


func _on_won() -> void:
	if state != "running":
		return
	state = "done"
	var hp: float = player_hp()
	result = {"rank": rank_for(t, total, hp), "time": snappedf(t, 0.1), "hp": int(round(hp)), "kos": kos}
	finished.emit(id, result)


func _fail(reason: String) -> void:
	if state in ["done", "failed"]:
		return
	state = "failed"
	failed.emit(id, reason)


func stop() -> void:
	if fight and is_instance_valid(fight):
		fight.stop()
		fight.queue_free()
	fight = null
	if _combat_ref and is_instance_valid(_combat_ref):
		_combat_ref.regen_delay = _regen_was
	_combat_ref = null
	_traffic(true)
	if hud:
		hud.queue_free()
		hud = null
	if state == "running":
		state = "idle"


## Parks the road traffic for the fight (RoamTraffic._park, as DriftDuel does) and gives it back.
func _traffic(run: bool) -> void:
	var tr: Variant = roam.get("traffic") if roam else null
	if tr == null or not is_instance_valid(tr):
		return
	var traffic: RoamTraffic = tr
	if not run and not _traffic_off:
		_traffic_off = true
		for v: Variant in traffic.vehicles:
			var veh: RoamTraffic.Vehicle = v
			if veh.active:
				traffic.call("_park", veh)
		traffic.set_physics_process(false)
	elif run and _traffic_off:
		_traffic_off = false
		traffic.set_physics_process(true)


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "VovinamHUD"
	hud.layer = 40
	add_child(hud)
	top_label = GameFXScript.make_label("", 22, Color("#6FA8FF"))
	top_label.name = "Top"
	top_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top_label.position.y = 18.0
	hud.add_child(top_label)
	_hud_text()



## The HUD line at HUD_S (about 10 Hz), not every frame (the first call shows it at once).
func _hud_tick(dt: float) -> void:
	_hud_t -= dt
	if _hud_t > 0.0:
		return
	_hud_t = HUD_S
	_hud_text()


func _hud_text() -> void:
	if top_label:
		top_label.text = "%s   %s   Hạ %d/%d" % [title(id).to_upper(), SideRace.time_text(t), kos, total]


func texts() -> Array[String]:
	var out: Array[String] = []
	if top_label:
		out.append(top_label.text)
	return out


func _process(delta: float) -> void:
	if auto_tick:
		advance(delta)


func _exit_tree() -> void:
	stop()
