# File: res://scripts/story/missions/MissionCrates.gd
# Day 3 "Đập thùng kính" (spec C-D7 beat 7): destroy the crates of smart glasses (the yard's SmartCrates, shoot or hit
# them; a counter) before Alexander comes back with his forklift (TIME_S). Four guards carry one more crate on their
# shoulders round a loop in a coffin-dance parody (the swaying walk), with the meme music slot meme_coffin_dance (owner
# file, else silence) while their crate is whole; break it and they drop everything and run off, the mission track comes
# back. Every crate is a GunFight external target, so the fight's loadout, HUD and targets do the work and its `won` =
# every crate broken -> the short replay seg_d3_crates on the last one -> done {"all": true} (flag d3_all_crates: the
# optional E4 manifest). Time up -> done {"all": false} ("Alexander quay lại rồi!"), no replay.
# points: start (+ start_yaw), crates (SmartCrate nodes), dance (loop points), centre, leash, gate, rack (+ rack_yaw).
# W3 T6 (plan 2026-10-30-w3-day3.md): signature = the coffin-dance crate: a preview cut on the four carriers at the start;
# breaking their crate = a slow-motion orbit on it (Impact.slowmo_orbit) while they drop everything and flee, the music
# back. Something new on the clock (Difficulty.pick): 2 guards from the gate (gate_at s: held outside, then alerted); a
# pallet rack of 3 more crates rolled out (rack_at s) that falls in a chain when its strap is shot; the dancers speed up
# (fast_at s); time_up_warn s before the end Alexander's horn and headlights at the gate in a preview cut. Every crate
# break: Impact light (heavy for the carried one and the strap), glass glint sparks and debris, the glasses' beep and
# "Xin chào, tôi là kính thông minh" floating once. The beat ends when every crate is broken (the gate guards need not be
# knocked out), or at the time up.
class_name MissionCrates
extends MissionLairFight

## A soft target for the rack's strap (the GunFight external enemy duck type): any hit cuts it -> the chain.
class RackStrap extends Node3D:
	signal ko(n: Node3D)
	var cut: bool = false
	var mesh: MeshInstance3D

	func is_defeated() -> bool:
		return cut

	func is_down() -> bool:
		return cut

	func hit_node() -> Node3D:
		return self

	func stand_down() -> void:
		pass

	func take_hit(info: Dictionary) -> String:
		if cut or not is_visible_in_tree() or String(info.get("kind", "")) == "scare":
			return "none"         # review fix: the hidden rack cannot be shot before it rolls out
		cut = true
		if mesh:
			mesh.visible = false
		ko.emit(self)
		return "knocked_out"

	func reset() -> void:
		cut = false
		if mesh:
			mesh.visible = true

## T9 (sloppy bot): at 90 s the bot had 45 s to spare on Thường; 55 s keeps every crate a race (Dễ keeps 90 s).
const TIME_S: float = 55.0
const TIME_S_EASY: float = 90.0
## Wave 3 integration: the gate guards' aim (Gunman "accuracy"), Thường / Dễ. The merged gun core (x2.0 accuracy, 16 HP a
## bullet on Thường) made the two of them kill the sloppy bot 3-11 times a run in what is a no-fail beat by design.
const GATE_ACC: Vector2 = Vector2(0.4, 1.0)
const DANCE_SPEED: float = 1.1
const SWAY_HZ: float = 0.9
const T_DROPPED: String = "Rơi hòm rồi! Chạy thôi!"
const T_TIME_UP: String = "Alexander lái xe nâng quay lại rồi!"
const MUSIC_MEME: String = "meme_coffin_dance"
const LAST_MARKED: int = 4

var crates: Array = []
var carried: SmartCrate
var dance: Node3D
var dancers: Array[Node3D] = []
var dance_pts: PackedVector3Array = PackedVector3Array()
var dance_s: float = 0.0
var dance_len: float = 0.0
var fleeing: float = -1.0
var time_left: float = TIME_S
## T8: the countdown through Difficulty (Thường TIME_S, Dễ longer).
var time_total: float = TIME_S
var meme_on: bool = false
## T6
var gate_at: float = 15.0
var rack_at: float = 30.0
var fast_at: float = 45.0
var time_up_warn: float = 20.0
var gate_on: bool = false
var rack: Node3D = null
var rack_crates: Array[SmartCrate] = []
var strap: RackStrap = null
var rack_on: bool = false
var chain_t: float = -1.0
var fast: bool = false
var time_up_cut: bool = false
var preview_cuts: int = 0
var hello_shown: bool = false
var all_done: bool = false
var _hello: Label3D = null
var _hello_t: float = -1.0
var _lights: Node3D = null
var _dance_speed: float = DANCE_SPEED
var markers: OffscreenMarkers = null
var _shown: Vector2i = Vector2i(-1, -1)   # (broken, seconds) on the info line: text rebuilt only when it changes


func _init() -> void:
	armed = true
	keep_top = true


func _start() -> void:
	gate_at = float(Difficulty.pick(10.0, 15.0))
	rack_at = float(Difficulty.pick(20.0, 30.0))
	fast_at = float(Difficulty.pick(30.0, 45.0))
	time_up_warn = float(Difficulty.pick(15.0, 20.0))
	place_player()
	crates = (pts.get("crates", []) as Array).duplicate()
	_build_dance()
	_build_rack()
	make_fight({"start_alerted": true})
	var wave: Array = []
	for c: Variant in crates:
		wave.append({"target": c})
	wave.append({"target": carried})
	if strap:
		wave.append({"target": strap})
	var g_spots: Array = pts.get("gate", [])
	for k: int in mini(2, g_spots.size()):
		var gd: Dictionary = guard(k, g_spots[k], [], {"ai": false, "alerted": false, "accuracy": float(Difficulty.pick(GATE_ACC.x, GATE_ACC.y))})
		gd["yaw"] = deg_to_rad(-90.0)
		wave.append(gd)
	fight.add_wave(wave)
	rec = null
	fight.start()
	for c2: Variant in crates:
		(c2 as SmartCrate).ko.connect(_on_crate_broken)
	carried.ko.connect(_on_crate_broken)
	_track_all()
	# T10: the coffin crate, the strap, the last crates and the gate guards stay findable (edge arrows off screen)
	markers = OffscreenMarkers.make(hud, player)
	markers.threat_source = fight.alive
	markers.track(carried, "prompt", "Hòm", 0.7)
	if strap:
		markers.track(strap, "prompt", "Dây đai", 3.2)
	for c3: Variant in crates:
		markers.track(c3, "prompt", "Thùng", 1.3)
	_reset_dance()
	_reset_events()
	radio("Hàng fake đó e, destroy hết đi, cái hòm mấy ông kia khiêng cũng tính nha.", "Phá hết các thùng kính, cả cái hòm đang khiêng.")
	MusicDirector.warm(["mission_gunfight"])   # the track that comes back when the carriers drop their crate


## T6: the pallet rack (3 more crates on shelves, a yellow strap across them), hidden until rack_at; the headlights.
func _build_rack() -> void:
	var at: Variant = pts.get("rack", null)
	if not (at is Vector3):
		return
	rack = Node3D.new()
	rack.name = "PalletRack"
	add_child(rack)
	rack.global_position = at
	rack.rotation.y = float(pts.get("rack_yaw", 0.0))
	var steel: StandardMaterial3D = CineFX._mat(Color("#2F5DA8"), 0.5)
	for sx: float in [-0.75, 0.75]:
		for sz: float in [-0.6, 0.6]:
			CineFX._box(rack, "Post", Vector3(0.08, 3.2, 0.08), Vector3(sx, 1.6, sz), steel)
	for h: float in [0.08, 1.12, 2.16]:
		CineFX._box(rack, "Shelf", Vector3(1.6, 0.06, 1.3), Vector3(0.0, h, 0.0), CineFX._mat(Color("#E07B39"), 0.6))
	for k: int in 3:
		var c := SmartCrate.new()
		c.setup({"carried": true, "name": "RackCrate%d" % k})
		rack.add_child(c)
		c.position = Vector3(0.0, 0.12 + 1.04 * k, 0.0)
		rack_crates.append(c)
		crates.append(c)
	strap = RackStrap.new()
	strap.name = "Strap"
	rack.add_child(strap)
	strap.position = Vector3(0.0, 0.0, 0.7)
	strap.mesh = CineFX._box(strap, "Band", Vector3(0.12, 3.0, 0.03), Vector3(0.0, 1.6, 0.0), CineFX._glow_mat(Color("#FFD23F"), 1.4))
	strap.ko.connect(_on_strap_cut)
	_lights = Node3D.new()
	_lights.name = "AlexanderHeadlights"
	add_child(_lights)
	var gs: Array = pts.get("gate", [])
	_lights.global_position = ((gs[0] as Vector3) + Vector3(-5.0, 0.0, 0.0)) if not gs.is_empty() else (at as Vector3)
	for sz2: float in [-0.6, 0.6]:
		var hl: MeshInstance3D = CineFX._box(_lights, "Headlight", Vector3(0.1, 0.3, 0.3), Vector3(0.6, 1.0, sz2), CineFX._glow_mat(Color("#FFF4C2"), 6.0))
		hl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _reset_events() -> void:
	gate_on = false
	rack_on = false
	chain_t = -1.0
	fast = false
	time_up_cut = false
	all_done = false
	_dance_speed = DANCE_SPEED
	if rack:
		rack.visible = false
	if strap:
		strap.reset()
	for c: SmartCrate in rack_crates:
		c.reset()
		c.dormant = true      # review fix: out of the fight (and of GunHUD's count) until the rack rolls out
	if _lights:
		_lights.visible = false
	_preview(dance)


func _preview(target: Node3D) -> void:
	preview_cuts += 1
	var d: CameraDirector = CameraDirector.live()
	if d != null and target != null and is_instance_valid(target) and target.is_inside_tree() and not d.cutting():
		d.preview_cut(target, 0.6)


## The two gate guards (the only gunmen of this fight).
func gate_guards() -> Array:
	var out: Array = []
	if fight == null:
		return out
	for g: Variant in fight.gunmen:
		if is_instance_valid(g):
			out.append(g)
	return out


## The clock events (T6): the gate guards, the rack, the dancers' speed-up, Alexander's headlights; the rack's chain.
func _events(dt: float) -> void:
	if not gate_on and clock >= gate_at:
		gate_on = true
		popup("2 bảo vệ từ cổng!", 1.6, WARN)
		radio("2 con guard spawn ở cổng kìa e, xử nhanh rồi đập tiếp.", "Hai bảo vệ vào từ cổng.", 3.5)
		for g: Variant in gate_guards():
			var gm: Gunman = g
			gm.ai = true
			gm.bind(fight)
			gm.alert(player.global_position if player else gm.global_position)
		var gg: Array = gate_guards()
		if not gg.is_empty():
			_preview(gg[0])      # T10: nothing important off screen without a look: the cut shows where they come in
	if not rack_on and clock >= rack_at and rack:
		rack_on = true
		rack.visible = true
		for rc: SmartCrate in rack_crates:
			rc.dormant = false
		popup("Kệ pallet: bắn dây đai cho đổ cả kệ!", 2.0)
		radio("Cái kệ kia có 3 thùng, bắn đứt dây đai là domino luôn e.", "Bắn dây vàng, cả kệ đổ.", 4.0)
		_preview(strap)
	if not fast and clock >= fast_at:
		fast = true
		_dance_speed = DANCE_SPEED * 1.7
		for b: Node3D in dancers:
			CharacterBuilder.set_speed(b, _dance_speed)
		popup("Nhạc lên! Tụi nó khiêng nhanh hơn!", 1.6)
	if not time_up_cut and time_left <= time_up_warn:
		time_up_cut = true
		if _lights:
			_lights.visible = true
		if fight:
			fight.play_cue("forklift_horn", _lights.global_position if _lights else player.global_position, 3.0)
		cues_played.append("forklift_horn")
		popup("Còn %d s! Alexander tới cổng rồi!" % int(time_up_warn), 2.0, WARN)
		_preview(_lights)
	if chain_t >= 0.0:
		chain_t += dt
		for k: int in rack_crates.size():
			var c: SmartCrate = rack_crates[rack_crates.size() - 1 - k]   # the top one first
			if not c.broken and chain_t >= 0.3 * float(k):
				c.smash(c.global_position + Vector3(0.0, 1.0, -1.0))
		if chain_t > 0.3 * float(rack_crates.size()):
			chain_t = -1.0


func _on_strap_cut(_s: Node3D) -> void:
	chain_t = 0.0
	Impact.hit(self, "heavy", {"pos": strap.global_position + Vector3(0.0, 1.6, 0.0), "dir": Vector3.DOWN})
	popup("Domino!", 1.4)


## Every crate break: an Impact hit, glass glint sparks and debris, the glasses greet the world once.
func _on_crate_broken(c: Node3D) -> void:
	var p: Vector3 = c.global_position + Vector3(0.0, 0.6, 0.0)
	var heavy: bool = c == carried
	var dir: Vector3 = WeaponMath.flat_dir(c.global_position - player.global_position) if player else Vector3.FORWARD
	Impact.hit(self, "heavy" if heavy else "light", {"pos": p, "dir": dir})
	Impact.particles(self, "sparks", p, Vector3.UP, 0.9)
	Impact.particles(self, "debris", p, Vector3.UP, 0.6)
	if not hello_shown:
		hello_shown = true
		YardSfx.play3d(self, "beep", p, -2.0)
		_hello = Label3D.new()
		_hello.name = "Hello"
		_hello.text = "Xin chào, tôi là kính thông minh"
		_hello.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_hello.font_size = 40
		_hello.outline_size = 10
		_hello.pixel_size = 0.006
		_hello.modulate = Color("#9FE8FF")
		add_child(_hello)
		_hello.global_position = p + Vector3(0.0, 0.8, 0.0)
		_hello_t = 0.0
	if heavy:
		Impact.slowmo_orbit(self, carried, Impact.ORBIT_S)   # the signature: the coffin crate breaks in slow motion


## The markers: the coffin crate while whole, the strap while the rack stands, every crate left once LAST_MARKED or
## fewer are left (before that the yard is full of them and the counter is enough).
func _markers_update() -> void:
	if markers == null:
		return
	markers.set_on(carried, not carried.broken and fleeing < 0.0)
	if strap:
		markers.set_on(strap, rack_on and not strap.cut)
	var left: int = total() - broken_count()
	for c: Variant in crates:
		var sc: SmartCrate = c
		var up: bool = not sc.broken and (not rack_crates.has(sc) or rack_on)
		markers.set_on(sc, up and left <= LAST_MARKED and not rack_crates.has(sc))


## Every crate counts: the yard's crates plus the carried one.
func total() -> int:
	return crates.size() + 1


func broken_count() -> int:
	var n: int = 0
	for c: Variant in crates:
		if (c as SmartCrate).broken:
			n += 1
	return n + (1 if carried and carried.broken else 0)


func _build_dance() -> void:
	dance_pts.clear()
	dance_len = 0.0
	for p: Variant in pts.get("dance", []):
		var q: Vector3 = p
		q.y = ground_y(q)
		dance_pts.append(q)
	if dance_pts.size() >= 2:
		dance_pts.append(dance_pts[0])   # a loop
		for i: int in range(1, dance_pts.size()):
			dance_len += flat(dance_pts[i - 1], dance_pts[i])
	dance = Node3D.new()
	dance.name = "CoffinDance"
	add_child(dance)
	for i: int in 4:
		var b: Node3D = StoryCast.build(GUARD_IDS[i % 3])
		if b == null:
			continue
		dance.add_child(b)
		b.position = Vector3(-0.42 if i % 2 == 0 else 0.42, 0.0, -0.55 if i < 2 else 0.55)
		dancers.append(b)
	carried = SmartCrate.new()
	carried.setup({"carried": true, "name": "CarriedCrate"})
	dance.add_child(carried)
	carried.position = Vector3(0.0, 1.62, 0.0)
	carried.whole.scale = Vector3(1.0, 0.9, 1.9)   # a long box on four shoulders (the visual only: a body is never scaled)
	carried.ko.connect(_on_carried_broken)


func _reset_dance() -> void:
	dance_s = 0.0
	fleeing = -1.0
	dance.visible = true
	for b: Node3D in dancers:
		b.visible = true
		b.position.y = 0.0
		CharacterBuilder.set_speed(b, DANCE_SPEED)
	_place_dance(0.0)
	_set_meme(true)
	time_total = float(Difficulty.pick(TIME_S, TIME_S_EASY))
	time_left = time_total
	_shown = Vector2i(-1, -1)
	_show_info()


## The recorder tracks the player, the dance and every crate's planks (the replay shows the last one breaking).
func _track_all() -> void:
	var nodes: Array = [player, dance]
	for c: Variant in crates + [carried]:
		for d: MeshInstance3D in (c as SmartCrate).debris:
			nodes.append(d)
	rec = StoryStage.make_recorder(self, nodes)


func _on_wave_started(_i: int) -> void:
	pass   # the recorder runs from the start (one wave)


func _on_enemy_ko(e: Node3D) -> void:
	if e is Gunman:
		return
	last_ko = e
	if broken_count() == total() and rec:
		rec.mark("blow")


func _on_fight_won() -> void:
	if all_done:
		return
	all_done = true
	for g: Variant in gate_guards():
		(g as Gunman).stand_down()
	won_info = {"all": true, "broken": broken_count()}
	_set_meme(false)
	if rec and String(beat.get("replay", "")) != "":
		replay_wait = StoryStage.REPLAY_AFTER
	else:
		finish(won_info)


func _on_carried_broken(_c: Node3D) -> void:
	popup(T_DROPPED, 2.0, WARN)
	fleeing = 0.0
	_set_meme(false)
	for b: Node3D in dancers:
		CharacterBuilder.set_speed(b, 4.5)


## The counter and the countdown in the top panel, rebuilt only when the shown numbers change (no per-frame strings).
func _show_info() -> void:
	var now := Vector2i(broken_count(), maxi(0, ceili(time_left)))
	if now == _shown:
		return
	_shown = now
	set_info("Thùng kính: %d / %d · Còn %d s" % [now.x, total(), now.y])
	_markers_update()
	set_meter(clampf(float(now.y) / time_total * 100.0, 0.0, 100.0))


func _set_meme(on: bool) -> void:
	if on == meme_on:
		return
	meme_on = on
	cues_played.append(MUSIC_MEME if on else "mission_gunfight")
	var fx: Node = get_node_or_null("/root/GameFX")
	if fx and fx.has_method("music_play"):
		fx.call("music_play", MUSIC_MEME if on else "mission_gunfight", 0.6)


func _lair_tick(dt: float) -> void:
	time_left -= dt
	_show_info()
	_events(dt)
	if _hello_t >= 0.0 and _hello:
		_hello_t += dt
		_hello.global_position.y += dt * 0.5
		_hello.modulate.a = clampf(1.0 - (_hello_t - 1.5) / 0.8, 0.0, 1.0)
		if _hello_t > 2.3:
			_hello.queue_free()
			_hello = null
			_hello_t = -1.0
	if not all_done and broken_count() == total():
		_on_fight_won()   # every crate broken: done, the gate guards need not be knocked out
		return
	if fleeing >= 0.0:
		fleeing += dt
		var away := Vector3(-1.0, 0.0, 0.3).normalized()
		dance.global_position += away * 4.5 * dt
		if fleeing > 3.5:
			dance.visible = false
	elif dance_len > 0.0:
		dance_s = fmod(dance_s + _dance_speed * dt, dance_len)
		_place_dance(clock)
	if time_left <= 0.0:
		popup(T_TIME_UP, 2.0, WARN)
		_set_meme(false)
		if fight:
			fight.stop()
		finish({"all": false, "broken": broken_count()})


## The dance at loop distance dance_s, facing along the loop, the coffin-dance sway (side to side, a little bob).
func _place_dance(t: float) -> void:
	if dance_pts.size() < 2:
		return
	var s: float = dance_s
	for i: int in range(1, dance_pts.size()):
		var seg: float = flat(dance_pts[i - 1], dance_pts[i])
		if s <= seg or i == dance_pts.size() - 1:
			var u: float = clampf(s / maxf(seg, 0.01), 0.0, 1.0)
			var p: Vector3 = dance_pts[i - 1].lerp(dance_pts[i], u)
			var dir: Vector3 = dance_pts[i] - dance_pts[i - 1]
			var yaw: float = yaw_of(dir)
			var side := Vector3(cos(yaw), 0.0, -sin(yaw))
			var sway: float = sin(t * TAU * SWAY_HZ) * 0.22
			dance.global_position = p + side * sway + Vector3(0.0, absf(sin(t * TAU * SWAY_HZ)) * 0.05, 0.0)
			dance.rotation.y = yaw + sin(t * TAU * SWAY_HZ) * 0.12
			return
		s -= seg


func _reset() -> void:
	super._reset()
	_reset_dance()
	_reset_events()


func _cleanup() -> void:
	_set_meme(false)
	super._cleanup()
