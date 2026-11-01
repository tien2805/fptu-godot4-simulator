# File: res://scripts/story/SideTakedown.gd
# Free-roam takedown challenges (plan 2026-11-01-w4-endings.md T5b), on the Day 2 bike combat: a BikeChase in free mode
# (no route: the bikers work in the player's heading frame, wherever the player rides) with the Bầy Sói leftovers in
# waves; the player kicks them off their scooters (Q / E, PlayerBikeCombat, takedowns as in the chase). All of them down
# within TIME_LIMIT_S: the rank by the time (RANK_PER_WAVE x the waves). Knocked off the bike, or the time runs out: given
# up. No replay, no story state touched (StorySideActivities records the result).
#   td_soi  "Bầy Sói tàn dư": one wave of 3 riders, from Nguyễn Xiển / Đường Số 21.
#   td_bay  "Cả bầy đuổi theo": 3 riders, then a stick rider, a thrower and a heavy, on Nguyễn Văn Tăng.
# API: like SideRace: setup({"roam", "id"}), start(), advance(dt) (auto_tick false in tests), stop(); chase (BikeChase);
#   signals started(id), finished(id, result {"rank", "time", "takedowns", "downed"}), failed(id, reason "knocked" | "time").
class_name SideTakedown
extends Node3D

signal started(id: String)
signal finished(id: String, result: Dictionary)
signal failed(id: String, reason: String)

const GameFXScript = preload("res://scripts/GameFX.gd")
const CHALLENGES: Dictionary = {
	"td_soi": {"title": "Bầy Sói tàn dư", "at": Vector2(2081.7, 12.8), "waves": [["rider", "rider", "rider"]]},
	"td_bay": {"title": "Cả bầy đuổi theo", "at": Vector2(1825.0, 24.0), "waves": [["rider", "rider", "rider"], ["stick", "thrower", "heavy"]]},
}
const ORDER: Array[String] = ["td_soi", "td_bay"]
const TIME_LIMIT_S: float = 180.0
## Seconds per wave for the rank (all of them down by then).
const RANK_PER_WAVE: Dictionary = {"S": 30.0, "A": 45.0, "B": 65.0}
const START_LINE: String = "Hạ hết cả bầy!"
const WIN_LINE: String = "Sạch bóng Bầy Sói!"
const NAMES: Array[String] = ["Sói Lẻ", "Sói Còi", "Sói Ghẻ", "Sói Gậy", "Sói Ném", "Sói Bự"]

const HUD_S: float = 0.1
var _hud_t: float = 0.0   # HUD refresh countdown (_hud_tick)
var id: String = ""
var roam: Node = null
var chase: BikeChase = null
var auto_tick: bool = true
## idle | running | done | failed
var state: String = "idle"
var t: float = 0.0
var downed: int = 0
var total: int = 0
var result: Dictionary = {}
var hud: CanvasLayer = null
var top_label: Label = null


static func title(cid: String) -> String:
	return String((CHALLENGES.get(cid, {}) as Dictionary).get("title", cid))


static func start_at(cid: String) -> Vector2:
	return (CHALLENGES.get(cid, {}) as Dictionary).get("at", Vector2.ZERO)


static func rank_for(sec: float, waves: int) -> String:
	for l: String in ["S", "A", "B"]:
		if sec <= float(RANK_PER_WAVE[l]) * waves:
			return l
	return "C"


func setup(opts: Dictionary) -> void:
	roam = opts.get("roam", null)
	id = String(opts.get("id", "td_soi"))
	name = "SideTakedown_" + id


func start() -> void:
	var c: Dictionary = CHALLENGES.get(id, {})
	if c.is_empty() or roam == null:
		_fail("no_course")
		return
	chase = BikeChase.new()
	chase.name = "TakedownChase"
	add_child(chase)
	chase.setup({"roam": roam, "route": [], "place": false, "auto_replay": false, "replay_slot": "", "start_line": START_LINE,
		"win_line": WIN_LINE, "auto_checkpoint": false, "seed": hash(id) & 0xFFFF})
	var k: int = 0
	for w: Array in c["waves"]:
		var spawns: Array = []
		for i: int in w.size():
			spawns.append({"from": "behind", "lane": [-1, 1, 0][i % 3], "delay": 0.6 * i,
				"opts": {"kind": String(w[i]), "label": NAMES[k % NAMES.size()], "aggression": 0.45}})
			k += 1
		chase.add_wave(spawns)
	total = k
	chase.biker_down.connect(func(_b: BikerEnemy, _c: String) -> void: downed += 1)
	chase.won.connect(_on_won)
	chase.lost.connect(func() -> void: _fail("knocked"))
	state = "running"
	t = 0.0
	_build_hud()
	_mount_here()
	chase.start()
	started.emit(id)


## On foot at the start: the parked bike comes to the player (the challenge starts here), then mounted.
func _mount_here() -> void:
	if bool(roam.get("mounted")):
		return
	var b: Node3D = roam.get("bike")
	var pl: Node3D = roam.get("player")
	if b and pl and bool(roam.get("bike_parked")):
		b.global_position = pl.global_position - Vector3(0.0, SideRace.BIKE_FLOOR_OFFSET, 0.0)
		b.rotation = Vector3(0.0, pl.rotation.y, 0.0)
	if roam.has_method("mount_bike"):
		roam.call("mount_bike")


func advance(dt: float) -> void:
	if state != "running":
		return
	t += dt
	if t >= TIME_LIMIT_S:
		_fail("time")
		return
	_hud_tick(dt)


func _on_won() -> void:
	if state != "running":
		return
	state = "done"
	var waves: int = ((CHALLENGES[id] as Dictionary)["waves"] as Array).size()
	result = {"rank": rank_for(t, waves), "time": snappedf(t, 0.1), "takedowns": chase.takedowns if chase else 0, "downed": downed}
	finished.emit(id, result)


func _fail(reason: String) -> void:
	if state in ["done", "failed"]:
		return
	state = "failed"
	failed.emit(id, reason)


func stop() -> void:
	if chase and is_instance_valid(chase):
		chase.stop()
		chase.queue_free()
	chase = null
	if hud:
		hud.queue_free()
		hud = null
	if state == "running":
		state = "idle"


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "TakedownHUD"
	hud.layer = 40
	add_child(hud)
	top_label = GameFXScript.make_label("", 22, Color("#FF6B6B"))
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
		top_label.text = "%s   %s   Hạ gục %d/%d" % [title(id).to_upper(), SideRace.time_text(t), downed, total]


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
