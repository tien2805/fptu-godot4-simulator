# File: res://scripts/story/missions/MissionShop.gd
# Day 6 shift behind the counter of Trà Sữa Lọ (lair task "shop", plan 2026-11-01-w4-day6.md T3; spec section 5 "Shipper
# infiltration"): the fast, funny order-matching mini-game. The player stands behind the counter in the pink shipper shirt,
# seen from a fixed shop camera (points.cam); sheep-masked customers (StoryCast "clone_masked") queue at the counter.
#   - Each order is a ticket (the order panel, top): size (M / L), tea (4 kinds), topping (4 kinds). Four ready cups stand
#     on the counter mats [1]-[4] (code-built milk_tea props, L cups bigger, a tag over each); one matches the ticket, the
#     other three differ in exactly one thing. [1]-[4] hands that cup over.
#   - The ticket timer (order_s: Thường 5.5 s / Dễ 9 s). Right: trust + gain + COMBO_STEP per combo level (up to
#     COMBO_CAP); wrong: - wrong_cost (Thường: less WRONG_RELIEF for each earlier THỬ LẠI, up to RELIEF_CAP, then Dễ's
#     cost: a failed shift makes the next one fairer, no long streaks); too slow: - late_cost (the customer stomps out). Tuned with tests/sim_day6.gd (T8:
#     the sloppy counter bot fails the Thường shift 1-3 times, a winning shift runs long enough for all five events).
#   - "Trust" (Thị Lọ's, the meter) starts at trust_start() (Thường 38 / Dễ TRUST_START); TRUST_WIN opens the back door (LairCanal.back_door_open) and
#     ends the shift; 0 = "BỊ LỘ" (the manager sees through the fake shipper; THỬ LẠI = a new shift).
#   - Something new every 15-20 s (EVENT_ORDER, one per gap, applied to the next ticket):
#       tam_tu    the meme customer: "Ít đường, ít đá, nhiều tâm tư." (any cup; he talks, a breather, the joke)
#       biker     a Bầy Sói biker revs up outside: "Như cũ!" (Phúc on the phone says what "như cũ" is; Dễ shows it)
#       rush      GIỜ CAO ĐIỂM: RUSH_N tickets on a shorter timer
#       intercom  Thị Lọ on the shop speaker: from now on "Hồng phấn" means strawberry (the tickets use the code word)
#       vip       a VIP orders two drinks at once (both cups, any order)
# Numbers through Difficulty.pick. Test hooks: serve(i), order, cups, trust, beats; opts.seed fixes the tickets; opts.bot
# ({"skill": 0..1, "react": [min, max]}) plays the counter for the sloppy-bot sims.
class_name MissionShop
extends StoryMission

const TRUST_START: float = 45.0               # Dễ's start (trust_start(): Thường lower)
const WRONG_RELIEF: float = 6.0
const RELIEF_CAP: int = 3
const TRUST_WIN: float = 100.0
const COMBO_CAP: int = 3
const COMBO_STEP: float = 1.0
const SIZES: Array[String] = ["M", "L"]
const TEAS: Array[String] = ["tra", "matcha", "khoai_mon", "dau"]
const TOPPINGS: Array[String] = ["pearl", "jelly", "pudding", "cheese"]
const TEA_NAMES: Dictionary = {"tra": "Trà truyền thống", "matcha": "Matcha", "khoai_mon": "Khoai môn", "dau": "Dâu"}
const TOP_NAMES: Dictionary = {"pearl": "Trân châu", "jelly": "Thạch", "pudding": "Pudding", "cheese": "Kem phô mai"}
const CODE_DAU: String = "Hồng phấn"
const USUAL: Dictionary = {"size": "L", "tea": "tra", "topping": "pearl"}
const EVENT_ORDER: Array[String] = ["tam_tu", "biker", "rush", "intercom", "vip"]
const FIRST_EVENT_S: float = 15.0
const EVENT_GAP: Vector2 = Vector2(15.0, 20.0)
const RUSH_N: int = 3
const CUP_SCALE: Dictionary = {"M": 2.2, "L": 2.9}
const QUEUE_N: int = 3
const QUEUE_GAP: float = 1.0
const WALK_MS: float = 2.2
const REACT_S: float = 0.75
const HAND_S: float = 0.25
const WIN_HOLD_S: float = 1.8
const TAM_TU_TALK_S: float = 2.2
const T_LO_REASON: String = "Khách bỏ về hết. Quản lý nhìn mày nghi ngờ: shipper gì mà pha sai hoài?"
const T_DOOR: String = "Thị Lọ tin mày rồi! Cửa sau mở."
const T_RUSH: String = "GIỜ CAO ĐIỂM!"
const HAPPY: Array[String] = ["Ngon!", "Đúng ý luôn!", "Cảm ơn nha.", "Chuẩn vị!"]
const ANGRY: Array[String] = ["Ủa, sai rồi!", "Tui gọi đâu phải ly này!", "Pha kiểu gì vậy?"]
const LATE: String = "Lâu quá, thôi khỏi!"
const GOLD := Color("#FFD34D")

var level: LairCanal
var pts: Dictionary = {}
var rng := RandomNumberGenerator.new()
var cam: Camera3D
var trust: float = TRUST_START
var combo: int = 0
var best_combo: int = 0
var served_ok: int = 0
var served_wrong: int = 0
var timeouts: int = 0
## The current ticket: {"kind": normal | tam_tu | biker | vip, "want": [cup dicts], "left": [cup dicts still to hand
## over], "t": seconds left, "len": its timer, "text": the ticket line} ({} between tickets).
var order: Dictionary = {}
## The four cups on the counter: [{"size", "tea", "topping"}] (index = key - 1).
var cups: Array = []
var cup_nodes: Array[Node3D] = []
var cup_tags: Array[Label3D] = []
var customers: Array[Dictionary] = []    # {"body", "path": Array[Vector3], "slot": int (-1 = leaving), "tag", "bubble"}
var biker: Dictionary = {}
var beats: Array[String] = []
var event_i: int = 0
var next_event_at: float = FIRST_EVENT_S
var pending: String = ""
var rush_left: int = 0
var codeword: bool = false
var won_t: float = -1.0
var gap_t: float = 0.0
var order_s: float = 6.0
var gain: float = 5.0
var wrong_cost: float = 15.0
var late_cost: float = 10.0
var _bubble_t: Dictionary = {}           # Label3D -> seconds left
var _hand: Dictionary = {}               # {"node", "from", "to", "t"} the cup flying over the counter
var _bot: Dictionary = {}
var _bot_t: float = -1.0
var panel: PanelContainer
var ticket_label: Label
var ticket_hint: Label
var ticket_bar: ProgressBar


func _start() -> void:
	level = opts.get("level") as LairCanal
	pts = opts.get("points", {})
	rng.seed = int(opts.get("seed", Time.get_ticks_usec()))
	order_s = float(Difficulty.pick(5.5, 9.0))
	gain = float(Difficulty.pick(2.0, 3.5))
	late_cost = float(Difficulty.pick(12.0, 8.0))
	_bot = opts.get("bot", {})
	if player:
		player.controls_enabled = false
	cam = Camera3D.new()
	cam.name = "ShopCam"
	cam.fov = 52.0
	add_child(cam)
	if pts.has("cam"):
		cam.global_transform = pts["cam"]
	cam.make_current()
	_build_ticket_panel()
	for i: int in QUEUE_N + 2:
		var b: Node3D = spawn_body("clone_masked", _door(), PI)
		customers.append({"body": b, "path": [], "slot": -1, "tag": _tag(b, "", GOLD, 2.25), "bubble": _tag(b, "", INK, 2.55)})
	var bb: Node3D = spawn_body("bay_soi", _door(), PI, {"seed": 3206})
	if bb:
		bb.visible = false
	biker = {"body": bb, "path": [], "slot": -1, "tag": _tag(bb, "BẦY SÓI", Color("#FF8A3C"), 2.3), "bubble": _tag(bb, "", INK, 2.6)}
	_fresh_shift()
	radio_as("phuc", "Khách gọi gì thì nhìn ly trên quầy, bấm [1] tới [4] đưa đúng ly. Nhanh tay lên mày!", "", 5.0)


## A new shift (start and THỬ LẠI): trust, the queue, the events, the cups.
func _fresh_shift() -> void:
	trust = trust_start()
	wrong_cost = wrong_cost_now()
	combo = 0
	best_combo = 0
	served_ok = 0
	served_wrong = 0
	timeouts = 0
	order = {}
	pending = ""
	event_i = 0
	next_event_at = FIRST_EVENT_S
	rush_left = 0
	codeword = false
	won_t = -1.0
	gap_t = 0.4
	_hand = {}
	beats.clear()
	beats.append("open")
	if level:
		level.back_door_open(false)
	teleport_player(pts.get("stand", Vector3.ZERO), float(pts.get("yaw", 0.0)))
	if player:
		player.controls_enabled = false
	for k: int in customers.size():
		var c: Dictionary = customers[k]
		c["slot"] = k if k < QUEUE_N else -1
		c["path"] = []
		var b: Node3D = c["body"]
		if b:
			b.visible = k < QUEUE_N
			b.global_position = _slot_pos(k) if k < QUEUE_N else _door()
			b.rotation.y = _face_counter()
		(c["tag"] as Label3D).text = ""
		(c["bubble"] as Label3D).visible = false
	if biker.get("body"):
		(biker["body"] as Node3D).visible = false
		biker["slot"] = -1
		biker["path"] = []
		biker.erase("stand_in")
	_clear_cups()
	_refresh_hud()


# ---------------------------------------------------------------------------
# Tick
# ---------------------------------------------------------------------------
func _tick(dt: float) -> void:
	_move_people(dt)
	_tick_bubbles(dt)
	_tick_hand(dt)
	if won_t >= 0.0:
		won_t += dt
		if won_t >= WIN_HOLD_S:
			finish({"orders": served_ok, "wrong": served_wrong, "late": timeouts, "best_combo": best_combo, "trust": trust})
		return
	if pending == "" and event_i < EVENT_ORDER.size() and clock >= next_event_at:
		pending = EVENT_ORDER[event_i]
		event_i += 1
		next_event_at = clock + rng.randf_range(EVENT_GAP.x, EVENT_GAP.y)
		_announce(pending)
	if order.is_empty():
		gap_t -= dt
		_fill_queue()
		var front: Dictionary = _front()
		if gap_t <= 0.0 and not front.is_empty() and (front["path"] as Array).is_empty():
			_new_order(front)
		return
	order["t"] = float(order["t"]) - dt
	if ticket_bar:
		ticket_bar.value = 100.0 * clampf(float(order["t"]) / maxf(float(order["len"]), 0.01), 0.0, 1.0)
	if float(order["t"]) <= 0.0:
		_late()
		return
	_bot_tick(dt)


## The event is announced as it comes due (the radio / the sound), its customer takes the next ticket.
func _announce(ev: String) -> void:
	beats.append(ev)
	match ev:
		"biker":
			play_cue("engine_roar", -6.0)
			radio_as("phuc", "Bầy Sói tới! Tụi nó gọi \"như cũ\" là ly L, trà truyền thống, trân châu. Nhớ nha!", "", 5.0)
		"rush":
			rush_left = RUSH_N
			popup(T_RUSH, 1.8, WARN)
			play_cue("school_bell", -10.0)
			radio_as("phuc", "Tan ca rồi, khách vô ào ào kìa. Lẹ tay lên!", "", 4.0)
		"intercom":
			codeword = true
			play_cue("static_burst", -8.0)
			radio_as("thi_lo", "Alo alo. Từ giờ khách gọi \"Hồng phấn\" là trà sữa dâu nha. Đừng hỏi tại sao!", "", 5.5)
		"tam_tu":
			pass
		"vip":
			popup("Khách VIP!", 1.4, GOLD)


func _new_order(c: Dictionary) -> void:
	var kind: String = "normal"
	var want: Array = []
	var len_s: float = order_s
	var text: String = ""
	var hint: String = "Bấm [1] - [4] đưa đúng ly"
	if pending in ["tam_tu", "biker", "vip"]:
		kind = pending
		pending = ""
	elif pending in ["rush", "intercom"]:
		pending = ""
	match kind:
		"tam_tu":
			cups = _random_cups(4)
			want = cups.duplicate()
			len_s = order_s + 6.0
			text = "Ít đường, ít đá, nhiều tâm tư."
			hint = "Ly nào cũng được... anh chỉ cần người nghe."
			_say(c, "Hôm nay anh buồn lắm em ơi...", TAM_TU_TALK_S)
		"biker":
			want = [USUAL.duplicate()]
			cups = _cups_for(want)
			text = "NHƯ CŨ"
			hint = "(Như cũ = ly L, Trà truyền thống, Trân châu)" if Difficulty.easy else "Như cũ là gì ta... Phúc vừa nói mà?"
			c = _swap_biker(c)
			_say(c, "Như cũ!", 1.6)
		"vip":
			var a: Dictionary = _random_cup()
			var b: Dictionary = _random_cup()
			while _same(a, b):
				b = _random_cup()
			want = [a, b]
			cups = _cups_for(want)
			len_s = order_s * 1.6
			text = "1) %s\n2) %s" % [_ticket(a), _ticket(b)]
			hint = "Khách VIP gọi hai ly: đưa đủ cả hai"
			(c["tag"] as Label3D).text = "VIP"
		_:
			var w: Dictionary = _random_cup()
			if codeword and not beats.has("code_used"):
				w["tea"] = "dau"   # the first ticket after the intercom uses the code word
				beats.append("code_used")
			want = [w]
			cups = _cups_for(want)
			text = _ticket(w)
			if rush_left > 0:
				rush_left -= 1
				len_s = order_s * float(Difficulty.pick(0.75, 0.85))
				hint = "GIỜ CAO ĐIỂM: còn %d ly gấp" % rush_left if rush_left > 0 else "Ly gấp cuối cùng!"
	order = {"kind": kind, "want": want, "left": want.duplicate(), "t": len_s, "len": len_s, "text": text, "cust": c}
	_place_cups()
	if ticket_label:
		ticket_label.text = text
		ticket_hint.text = hint
		ticket_bar.value = 100.0
		panel.visible = true
	_bot_t = -1.0


## The biker takes the front customer's place in the queue for one ticket (the sheep-masked one steps aside).
func _swap_biker(c: Dictionary) -> Dictionary:
	var bb: Node3D = biker.get("body")
	if bb == null:
		return c
	var mb: Node3D = c["body"]
	bb.global_position = mb.global_position
	bb.rotation.y = mb.rotation.y
	bb.visible = true
	mb.visible = false
	biker["slot"] = 0
	biker["path"] = []
	biker["stand_in"] = c
	c["slot"] = -2   # parked out of sight until the biker leaves
	return biker


# ---------------------------------------------------------------------------
# Serving
# ---------------------------------------------------------------------------
## [1]-[4]: hands cup i over (tests and the bot call it directly).
func serve(i: int) -> void:
	if state != "running" or order.is_empty() or won_t >= 0.0 or i < 0 or i >= cups.size() or cups[i] == null:
		return
	var cup: Dictionary = cups[i]
	var left: Array = order["left"]
	var hit: int = -1
	for k: int in left.size():
		if _same(left[k], cup):
			hit = k
			break
	_hand_over(i)
	if hit < 0:
		_wrong()
		return
	cups[i] = null
	left.remove_at(hit)
	if order["kind"] == "tam_tu" or left.is_empty():
		_right()
	else:
		play_cue("tray_clang", -10.0)


func _right() -> void:
	var c: Dictionary = order["cust"]
	var kind: String = String(order["kind"])
	served_ok += 1
	combo += 1
	best_combo = maxi(best_combo, combo)
	var bonus: float = 0.0
	match kind:
		"vip":
			bonus = 8.0
		"biker":
			bonus = 4.0
		"tam_tu":
			bonus = -1.0
	_add_trust(gain + bonus + float(mini(combo - 1, COMBO_CAP)) * COMBO_STEP)
	play_cue("tray_clang", -8.0)
	if kind == "tam_tu":
		_say(c, "Cảm ơn em đã lắng nghe.", 1.6)
		play_cue("ba_dum_tss", -10.0)
	else:
		_say(c, HAPPY[rng.randi() % HAPPY.size()], 1.2)
	if combo >= 3:
		popup("Combo x%d" % combo, 0.9, GOLD)
	_end_order()


func _wrong() -> void:
	var c: Dictionary = order["cust"]
	served_wrong += 1
	combo = 0
	_say(c, ANGRY[rng.randi() % ANGRY.size()], 1.2)
	play_cue("record_scratch", -8.0)
	popup("Sai ly! -%d" % int(wrong_cost), 1.0, WARN)
	_add_trust(-wrong_cost)
	_end_order()


func _late() -> void:
	var c: Dictionary = order["cust"]
	timeouts += 1
	combo = 0
	_say(c, LATE, 1.2)
	play_cue("bonk", -10.0)
	popup("Chậm quá! -%d" % int(late_cost), 1.0, WARN)
	_add_trust(-late_cost)
	_end_order()


func _add_trust(v: float) -> void:
	trust = clampf(trust + v, 0.0, TRUST_WIN)
	set_stat("orders", served_ok)
	set_stat("wrong", served_wrong + timeouts)
	set_stat("best_combo", best_combo)
	_refresh_hud()
	if trust <= 0.0:
		_clear_order_ui()
		fail(T_LO_REASON, T_LO)
	elif trust >= TRUST_WIN and won_t < 0.0:
		_win()


func _win() -> void:
	won_t = 0.0
	beats.append("door")
	if level:
		level.back_door_open(true)
	popup(T_DOOR, WIN_HOLD_S, GOLD)
	play_cue("success_fanfare", -6.0)
	radio("Trust full r, cửa sau unlock rồi đó e.", "Cửa sau mở rồi.", 4.0)


## The served (or angry) customer walks out, the queue steps up; a new ticket after a short gap.
func _end_order() -> void:
	var c: Dictionary = order.get("cust", {})
	order = {}
	_clear_order_ui()
	gap_t = REACT_S
	if c.is_empty() or state != "running":
		return
	c["slot"] = -1
	var b: Node3D = c["body"]
	var side: Vector3 = Vector3(1.3, 0.0, 0.0)
	c["path"] = [b.global_position + side, _door() + side]
	for k: Dictionary in _all_people():
		if int(k["slot"]) > 0:
			k["slot"] = int(k["slot"]) - 1
			k["path"] = [_slot_pos(int(k["slot"]))]
	_fill_queue()


## Free bodies (out of the door, not walking) join the empty places at the end of the queue.
func _fill_queue() -> void:
	var taken: Array[int] = []
	for k: Dictionary in _all_people():
		if int(k["slot"]) >= 0:
			taken.append(int(k["slot"]))
	for s: int in QUEUE_N:
		if s in taken:
			continue
		for k2: Dictionary in customers:
			var b2: Node3D = k2["body"]
			if int(k2["slot"]) == -1 and (k2["path"] as Array).is_empty() and b2 and not b2.visible:
				k2["slot"] = s
				b2.global_position = _door()
				b2.visible = true
				(k2["tag"] as Label3D).text = ""
				k2["path"] = [_slot_pos(s)]
				break


func _clear_order_ui() -> void:
	if panel:
		panel.visible = false


# ---------------------------------------------------------------------------
# People
# ---------------------------------------------------------------------------
func _all_people() -> Array[Dictionary]:
	var out: Array[Dictionary] = customers.duplicate()
	if not biker.is_empty():
		out.append(biker)
	return out


## The customer at the counter (slot 0), {} when nobody stands there yet.
func _front() -> Dictionary:
	for c: Dictionary in _all_people():
		if int(c["slot"]) == 0 and c["body"] != null and (c["body"] as Node3D).visible:
			return c
	return {}


func _move_people(dt: float) -> void:
	for c: Dictionary in _all_people():
		var b: Node3D = c["body"]
		if b == null or not b.visible:
			continue
		var path: Array = c["path"]
		if path.is_empty():
			CharacterBuilder.set_speed(b, 0.0)
			if int(c["slot"]) >= 0:
				b.rotation.y = lerp_angle(b.rotation.y, _face_counter(), minf(1.0, dt * 8.0))
			continue
		var to: Vector3 = path[0]
		var d: Vector3 = to - b.global_position
		d.y = 0.0
		var step: float = WALK_MS * dt * (1.4 if int(c["slot"]) == -1 else 1.0)
		if d.length() <= step:
			b.global_position = Vector3(to.x, b.global_position.y, to.z)
			path.pop_front()
			if path.is_empty() and int(c["slot"]) == -1:
				_left_shop(c)
			continue
		b.global_position += d.normalized() * step
		b.rotation.y = lerp_angle(b.rotation.y, yaw_of(d), minf(1.0, dt * 10.0))
		CharacterBuilder.set_speed(b, WALK_MS)


## Out of the door: the biker rides off (his stand-in comes back to the queue), the others wait outside for a free slot.
func _left_shop(c: Dictionary) -> void:
	var b: Node3D = c["body"]
	b.visible = false
	CharacterBuilder.set_speed(b, 0.0)
	if is_same(c, biker) and biker.has("stand_in"):
		var s: Dictionary = biker["stand_in"]
		biker.erase("stand_in")
		s["slot"] = -1
		s["path"] = []
		play_cue("engine_roar", -10.0)


func _say(c: Dictionary, text: String, secs: float) -> void:
	var l: Label3D = c.get("bubble")
	if l == null:
		return
	l.text = text
	l.visible = true
	_bubble_t[l] = secs


func _tick_bubbles(dt: float) -> void:
	for l: Variant in _bubble_t.keys():
		_bubble_t[l] = float(_bubble_t[l]) - dt
		if float(_bubble_t[l]) <= 0.0:
			if is_instance_valid(l):
				(l as Label3D).visible = false
			_bubble_t.erase(l)


func _tag(b: Node3D, text: String, col: Color, y: float) -> Label3D:
	var l := Label3D.new()
	l.name = "Tag"
	l.text = text
	l.font_size = 40
	l.pixel_size = 0.004
	l.modulate = col
	l.outline_size = 10
	l.outline_modulate = Color(0.06, 0.02, 0.1, 0.95)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = Vector3(0.0, y, 0.0)
	if b:
		b.add_child(l)
	else:
		add_child(l)
	return l


func _slot_pos(k: int) -> Vector3:
	var base: Vector3 = pts.get("counter", Vector3.ZERO)
	return base + (pts.get("queue_dir", Vector3.FORWARD) as Vector3) * QUEUE_GAP * float(k)


func _door() -> Vector3:
	return pts.get("door", Vector3(0.0, 0.0, -6.0))


## Customers at the counter face the staff side (the opposite of the queue direction).
func _face_counter() -> float:
	return yaw_of(-(pts.get("queue_dir", Vector3.FORWARD) as Vector3))


# ---------------------------------------------------------------------------
# Cups
# ---------------------------------------------------------------------------
func _random_cup() -> Dictionary:
	return {"size": SIZES[rng.randi() % SIZES.size()], "tea": TEAS[rng.randi() % TEAS.size()],
		"topping": TOPPINGS[rng.randi() % TOPPINGS.size()]}


func _random_cups(n: int) -> Array:
	var out: Array = []
	while out.size() < n:
		var c: Dictionary = _random_cup()
		var dup: bool = false
		for o: Dictionary in out:
			dup = dup or _same(o, c)
		if not dup:
			out.append(c)
	return out


static func _same(a: Variant, b: Variant) -> bool:
	if not (a is Dictionary and b is Dictionary):
		return false
	return a["size"] == b["size"] and a["tea"] == b["tea"] and a["topping"] == b["topping"]


## The four cups for the wanted ones: each wanted cup plus decoys that differ from a wanted cup in exactly one thing (size,
## tea or topping), never equal to a wanted cup or to each other; shuffled onto the mats.
func _cups_for(want: Array) -> Array:
	var out: Array = want.duplicate(true)
	var keys: Array[String] = ["size", "tea", "topping"]
	var guard: int = 0
	while out.size() < 4 and guard < 200:
		guard += 1
		var base: Dictionary = want[(out.size()) % want.size()]
		var d: Dictionary = base.duplicate()
		var key: String = keys[rng.randi() % keys.size()]
		var pool: Array[String] = SIZES if key == "size" else (TEAS if key == "tea" else TOPPINGS)
		d[key] = pool[rng.randi() % pool.size()]
		var dup: bool = false
		for o: Dictionary in out:
			dup = dup or _same(o, d)
		if not dup:
			out.append(d)
	while out.size() < 4:
		out.append(_random_cup())
	for i: int in range(out.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var t: Variant = out[i]
		out[i] = out[j]
		out[j] = t
	return out


## The ticket line of a cup: "Ly L, Matcha, Trân châu" (strawberry reads "Hồng phấn" after the intercom).
func _ticket(c: Dictionary) -> String:
	var tea: String = CODE_DAU if codeword and c["tea"] == "dau" else String(TEA_NAMES[c["tea"]])
	return "Ly %s, %s, %s" % [c["size"], tea, TOP_NAMES[c["topping"]]]


## The tag over a cup always names the real tea.
static func cup_tag(c: Dictionary) -> String:
	return "%s %s\n%s" % [c["size"], TEA_NAMES[c["tea"]], TOP_NAMES[c["topping"]]]


func _place_cups() -> void:
	_clear_cups()
	var spots: Array = pts.get("cups", [])
	for i: int in cups.size():
		var c: Dictionary = cups[i]
		var n: Node3D = CineFX.build_prop("milk_tea", {"tea": CinePropsD6.TEA_COLORS[c["tea"]], "topping": c["topping"]})
		n.name = "Cup%d" % (i + 1)
		add_child(n)
		n.global_position = spots[i] if i < spots.size() else Vector3(-1.5 + float(i), 1.0, 0.6)
		n.scale = Vector3.ONE * float(CUP_SCALE[c["size"]])
		cup_nodes.append(n)
		var tag := Label3D.new()
		tag.name = "CupTag"
		tag.text = cup_tag(c)
		tag.font_size = 30
		tag.pixel_size = 0.0032
		tag.outline_size = 8
		tag.modulate = INK
		tag.outline_modulate = Color(0.06, 0.02, 0.1, 0.95)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		add_child(tag)
		tag.global_position = n.global_position + Vector3(0.0, 0.62, 0.0)
		cup_tags.append(tag)


func _clear_cups() -> void:
	for n: Node3D in cup_nodes:
		if is_instance_valid(n):
			n.queue_free()
	for t: Label3D in cup_tags:
		if is_instance_valid(t):
			t.queue_free()
	cup_nodes.clear()
	cup_tags.clear()
	if not _hand.is_empty() and is_instance_valid(_hand.get("node")):
		(_hand["node"] as Node3D).queue_free()
	_hand = {}


## The chosen cup slides over the counter to the customer (and is gone); its tag goes with it.
func _hand_over(i: int) -> void:
	if i >= cup_nodes.size() or not is_instance_valid(cup_nodes[i]):
		return
	var n: Node3D = cup_nodes[i]
	if not _hand.is_empty() and is_instance_valid(_hand.get("node")):
		(_hand["node"] as Node3D).queue_free()
	var to: Vector3 = n.global_position + (pts.get("queue_dir", Vector3.FORWARD) as Vector3) * 0.55
	_hand = {"node": n, "from": n.global_position, "to": to, "t": 0.0}
	cup_nodes[i] = null
	if i < cup_tags.size() and is_instance_valid(cup_tags[i]):
		cup_tags[i].visible = false
	if player and player.model:
		CharacterBuilder.play(player.model, "wave", 0.35)


func _tick_hand(dt: float) -> void:
	if _hand.is_empty():
		return
	var n: Node3D = _hand["node"]
	if not is_instance_valid(n):
		_hand = {}
		return
	_hand["t"] = float(_hand["t"]) + dt
	var k: float = clampf(float(_hand["t"]) / HAND_S, 0.0, 1.0)
	n.global_position = (_hand["from"] as Vector3).lerp(_hand["to"], k)
	if k >= 1.0:
		n.queue_free()
		_hand = {}


# ---------------------------------------------------------------------------
# HUD
# ---------------------------------------------------------------------------
func _build_ticket_panel() -> void:
	panel = PanelContainer.new()
	panel.name = "Ticket"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -260.0
	panel.offset_right = 260.0
	panel.offset_top = 160.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.97, 0.9, 0.95)
	sb.border_color = PINK
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	hud.add_child(panel)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vb)
	var head: Label = _label("ĐƠN HÀNG", 14, Color("#9A3A6A"))
	head.add_theme_constant_override("outline_size", 0)
	vb.add_child(head)
	ticket_label = _label("", 26, Color("#2A1A22"))
	ticket_label.add_theme_constant_override("outline_size", 0)
	vb.add_child(ticket_label)
	ticket_bar = ProgressBar.new()
	ticket_bar.custom_minimum_size = Vector2(440.0, 10.0)
	ticket_bar.show_percentage = false
	ticket_bar.max_value = 100.0
	ticket_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = PINK
	fill.set_corner_radius_all(4)
	ticket_bar.add_theme_stylebox_override("fill", fill)
	vb.add_child(ticket_bar)
	ticket_hint = _label("", 15, Color("#6A3A52"))
	ticket_hint.add_theme_constant_override("outline_size", 0)
	vb.add_child(ticket_hint)
	panel.visible = false


func _refresh_hud() -> void:
	set_info("Niềm tin của Thị Lọ: %d / %d%s" % [int(trust), int(TRUST_WIN), "   Combo x%d" % combo if combo >= 2 else ""])
	set_meter(trust, "Niềm tin")
	set_prompt("[1] [2] [3] [4] đưa ly")


# ---------------------------------------------------------------------------
# Input, bot
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if state != "running" or not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if not k.pressed or k.echo:
		return
	var i: int = -1
	match k.physical_keycode:
		KEY_1, KEY_KP_1:
			i = 0
		KEY_2, KEY_KP_2:
			i = 1
		KEY_3, KEY_KP_3:
			i = 2
		KEY_4, KEY_KP_4:
			i = 3
	if i >= 0:
		serve(i)
		get_viewport().set_input_as_handled()


## The sloppy bot: reads the ticket after a random delay, picks right with probability skill (a code-word or "như cũ"
## ticket costs it some), else a decoy.
func _bot_tick(dt: float) -> void:
	if _bot.is_empty() or order.is_empty():
		return
	if _bot_t < 0.0:
		var r: Array = _bot.get("react", [1.2, 3.2])
		_bot_t = rng.randf_range(float(r[0]), float(r[1]))
		if order["kind"] == "biker" and not Difficulty.easy:
			_bot_t += 0.8
	_bot_t -= dt
	if _bot_t > 0.0:
		return
	_bot_t = -1.0
	var skill: float = float(_bot.get("skill", 0.85))
	if order["kind"] == "biker" and not Difficulty.easy:
		skill -= 0.15
	var want_i: int = -1
	var wrong_i: int = -1
	for i: int in cups.size():
		if cups[i] == null:
			continue
		var ok: bool = false
		for w: Dictionary in order["left"]:
			ok = ok or _same(w, cups[i])
		if ok and want_i < 0:
			want_i = i
		elif not ok and wrong_i < 0:
			wrong_i = i
	serve(want_i if rng.randf() < skill or wrong_i < 0 else wrong_i)


func _reset() -> void:
	_fresh_shift()


func trust_start() -> float:
	return float(Difficulty.pick(38.0, TRUST_START))


## This shift's wrong-cup cost: Thường 32 less WRONG_RELIEF per earlier fail (up to RELIEF_CAP: 14 like Dễ), Dễ 14.
func wrong_cost_now() -> float:
	return float(Difficulty.pick(32.0 - WRONG_RELIEF * float(mini(fails, RELIEF_CAP)), 14.0))


func _cleanup() -> void:
	_clear_cups()
	if panel:
		panel.visible = false
	if player and player.camera and is_instance_valid(player.camera):
		player.camera.make_current()
	if cam and is_instance_valid(cam):
		cam.current = false
