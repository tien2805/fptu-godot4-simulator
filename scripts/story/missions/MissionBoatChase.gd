# File: res://scripts/story/missions/MissionBoatChase.gd
# Day 6 speedboat chase (lair task "boat", plan 2026-11-01-w4-day6.md T4): Thị Lọ grabbed the cash and ran for her pink
# speedboat; the player takes the moored one and chases her down the Rạch Hầm canal (BoatChase on the LairCanal course).
# The player's walking body is hidden (the protagonist drives the boat in the pink shipper shirt) and the chase camera
# takes over; the beat's "after" cinematic seg_d6_chase follows the win.
#   - HUD (the mission's top panel): the gap to Thị Lọ, the rams in the finale ("Húc: 1 / 3"), the hull as the meter;
#     prompts by priority: "CÚI! [CTRL]" before a low bridge, the ram line in the finale, the kick keys while a jet ski
#     rides alongside; short popups on every hit ("Cốp! Quên cúi đầu...", "Dính lưới!", ...).
#   - Guidance (OffscreenMarkers): Thị Lọ always (an edge arrow with her distance when off screen), every jet ski that is
#     still a threat, and the next set piece within HAZARD_AHEAD m (Cầu thấp / Lưới / Dốc ghe / Sà lan pháo).
#   - Fails: the hull at 0 ("Cano nát bét rồi.") or Thị Lọ getting away ("Thị Lọ chạy mất tiêu rồi."): "TOANG!", THỬ LẠI =
#     BoatChase.retry() at the last checkpoint.
# Keys: [W] / [S] throttle, [A] / [D] steer, [CTRL] duck, [Q] / [E] kick left / right. opts.input (tests): a Dictionary
# handed to BoatChase.input_override.
class_name MissionBoatChase
extends StoryMission

const HAZARD_AHEAD: float = 220.0
const DUCK_PROMPT_M: float = 55.0
const HAZARD_LABELS: Dictionary = {"bridge": "Cầu thấp", "net": "Lưới", "ramp": "Dốc ghe", "barge": "Sà lan pháo"}
const HIT_LINES: Dictionary = {"bridge": BoatData.T_BONK, "net": BoatData.T_NET, "wall": BoatData.T_WALL,
	"barge": "Đụng sà lan!", "ski": "Bị húc!"}

var level: LairCanal
var pts: Dictionary = {}
var chase: BoatChase
var markers: OffscreenMarkers
var hazard_mark: Node3D
var hazard_kind: String = ""
var _events: Array = []


func _start() -> void:
	level = opts.get("level") as LairCanal
	pts = opts.get("points", {})
	chase = BoatChase.new()
	add_child(chase)
	var ro: Dictionary = (player.character_opts as Dictionary).duplicate() if player else {}
	chase.setup(level, {"seed": int(opts.get("seed", 1)), "rider_opts": ro})
	if opts.has("input"):
		chase.input_override = opts["input"]
	chase.lost.connect(_on_lost)
	chase.won.connect(_on_won)
	chase.hazard_hit.connect(_on_hazard)
	chase.ski_down.connect(_on_ski_down)
	chase.rammed.connect(_on_rammed)
	chase.wave_started.connect(_on_wave)
	chase.finale_started.connect(_on_finale)
	chase.checkpoint_passed.connect(func(_i: int) -> void: mark_ko_checkpoint())
	if player:
		player.visible = false
		player.controls_enabled = false
	markers = OffscreenMarkers.make(hud, chase.boat)
	markers.track(chase.rival, "threat", "Thị Lọ", 2.4)
	for sk: JetSki in chase.skis:
		markers.track(sk, "threat", "Bầy Sói", 2.2)
		markers.set_on(sk, false)
	hazard_mark = Node3D.new()
	hazard_mark.name = "NextHazard"
	add_child(hazard_mark)
	markers.track(hazard_mark, "prompt", "", 0.0)
	markers.set_on(hazard_mark, false)
	for e: Dictionary in level.course_events():
		_events.append(e)
	_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) < float(b["s"]))
	chase.start()
	popup("Đuổi theo Thị Lọ!", 1.8, PINK)
	radio("Con cano hồng là của Thị Lọ, bám theo nó, đừng để mất dấu. Cầu thấp nhớ cúi nha e.", "Bám theo Thị Lọ, qua cầu thấp thì cúi đầu.", 5.5)
	_refresh()


func _tick(dt: float) -> void:
	chase.step(dt)
	for sk: JetSki in chase.skis:
		markers.set_on(sk, sk.is_threat())
	_place_hazard_mark()
	set_stat("hull", int(chase.boat.hull))
	set_stat("hits", chase.hazard_hits)
	_refresh()


func focus_point() -> Vector3:
	return chase.boat.global_position if chase and chase.boat else Vector3.ZERO


func _refresh() -> void:
	if chase == null:
		return
	var gap: int = int(round(chase.rival.s - chase.boat.s))
	var line: String = "Thị Lọ: %d m" % maxi(gap, 0)
	if chase.finale:
		line += "   Húc: %d / %d" % [chase.rival.rams, BoatData.rams_needed()]
	set_info(line)
	set_meter(chase.boat.hull, "Thân cano")
	set_prompt(_prompt())


func _prompt() -> String:
	var b: PlayerBoat = chase.boat
	for bs: float in LairCanal.BRIDGES:
		if bs - b.s > -1.0 and bs - b.s < DUCK_PROMPT_M:
			return BoatData.T_DUCK
	if chase.finale and not chase.rival.crashed:
		return BoatData.T_RAM
	for sk: JetSki in chase.skis:
		if sk.is_threat() and absf(sk.s - b.s) < 6.0 and absf(sk.d - b.d) < 4.5:
			return BoatData.T_KICK
	return ""


## The next set piece ahead within HAZARD_AHEAD m gets the prompt marker (its name and distance).
func _place_hazard_mark() -> void:
	var b: PlayerBoat = chase.boat
	var next: Dictionary = {}
	for e: Dictionary in _events:
		if float(e["s"]) > b.s + 2.0:
			next = e
			break
	if next.is_empty() or float(next["s"]) - b.s > HAZARD_AHEAD:
		markers.set_on(hazard_mark, false)
		hazard_kind = ""
		return
	var kind: String = String(next["kind"])
	var dd: float = 0.0
	match kind:
		"net":
			dd = float(next.get("side", 1.0)) * 6.0
		"ramp":
			dd = LairCanal.RAMP_D
		"barge":
			dd = LairCanal.BARGE_D
	hazard_mark.global_position = level.course_pos(float(next["s"]), dd, 2.6)
	if kind != hazard_kind:
		hazard_kind = kind
		markers.track(hazard_mark, "prompt", String(HAZARD_LABELS.get(kind, "")), 0.0)
	markers.set_on(hazard_mark, true)


func _on_hazard(kind: String) -> void:
	popup(String(HIT_LINES.get(kind, "")), 1.2, WARN)


func _on_ski_down(_sk: JetSki, cause: String) -> void:
	if cause == "finale":
		return                               # swept away with her crash: no takedown
	add_stat("ko")
	if cause == "kick":
		popup("Bay màu!", 0.9, PINK)
	elif cause in ["net", "wall", "barge"]:
		popup("Bầy Sói ăn %s!" % {"net": "lưới", "wall": "trụ cầu", "barge": "sà lan"}[cause], 1.0, PINK)


func _on_wave(i: int) -> void:
	if i == 0:
		radio("Bầy Sói chạy jet ski áp sát hai bên kìa. Q đá trái, E đá phải.", "Jet ski hai bên: Q đá trái, E đá phải.", 4.5)
	else:
		popup("Bầy Sói tới!", 1.2, WARN)


func _on_finale() -> void:
	popup("Bả đuối rồi! Húc vào bờ!", 1.8, PINK)
	radio("Cano bả hết xăng r, ram nó vô bờ phải đi e.", "Bà ta sắp hết xăng, húc thuyền bà ta vào bờ phải.", 4.5)


func _on_rammed(n: int) -> void:
	popup("Húc %d / %d!" % [n, BoatData.rams_needed()], 1.0, PINK)


func _on_lost(reason: String) -> void:
	fail(reason, T_TOANG)


func _on_won() -> void:
	finish({"hull": int(chase.boat.hull), "kos": chase.kos, "hits": chase.hazard_hits})


func _reset() -> void:
	chase.retry()
	if player:
		player.visible = false
		player.controls_enabled = false


func _unhandled_input(event: InputEvent) -> void:
	if state != "running" or not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if not k.pressed or k.echo:
		return
	if k.physical_keycode == KEY_Q:
		chase.kick(-1)
		get_viewport().set_input_as_handled()
	elif k.physical_keycode == KEY_E:
		chase.kick(1)
		get_viewport().set_input_as_handled()


func _cleanup() -> void:
	if chase and is_instance_valid(chase):
		chase.stop()
	if markers and is_instance_valid(markers):
		markers.clear()
	if player and is_instance_valid(player):
		player.visible = true
		if player.camera:
			player.camera.make_current()
