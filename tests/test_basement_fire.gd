# File: res://tests/test_basement_fire.gd
# W3 Day 5 T4 (plan 2026-10-30-w3-day5.md, D5W-1): the burning server countdown (MissionHack in the StoryBasement scene,
# no story running). Checks: the 90 s clock and the countdown text; breach 1 at 30 s and breach 2 at 60 s (3 guards on
# Thường, the preview cut, the guns); typing pauses with no decay and resumes at the desk; the fire stages at 60 / 30 /
# 10 s left from a fixed emitter pool; the gas at 0 and the retry state (full timer, stage 0, no breach); a win before 0
# with breach_clean; the emitters stopped after.
# Run:  godot --headless --path . --script tests/test_basement_fire.gd
extends SceneTree

const DT: float = 1.0 / 60.0
const BASEMENT: String = "res://scenes/story/StoryBasement.tscn"
var TMP: String = "user://test_basement_fire_%d.cfg" % OS.get_process_id()
var fails: Array[String] = []
var phase: int = 0
var frames: int = 0
var total: int = 0
var bs: StoryBasement
var m: MissionHack
var h: StoryHack
var snap: Dictionary = {}
var done_info: Dictionary = {}
var got_done: bool = false


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  FAIL ", msg)


func _initialize() -> void:
	print("--- TEST BASEMENT FIRE (D5W-1 burning countdown) ---")
	Engine.max_fps = 60
	Difficulty.set_easy(false)
	var sd: Node = root.get_node_or_null("StoryDirector")
	if sd:
		sd.set("save_path", TMP)
	StoryBasement.test_opts = {"missions": {"manual": true, "manual_replay": true, "seed": 3}, "capture_mouse": false, "go_roam": false}


func _next(p: int) -> void:
	phase = p
	frames = 0


func _ko_all() -> void:
	if m.fight == null:
		return
	for e: Variant in m.fight.alive():
		var n: int = 0
		while not (e as Gunman).is_defeated() and n < 10:
			(e as Gunman).take_hit({"kind": "bullet", "from": bs.player.global_position})
			n += 1


func _bullet_ys() -> Array:
	var out: Array = []
	for b: Dictionary in h.bullets:
		out.append(float(b["y"]))
	return out


func _process(_d: float) -> bool:
	frames += 1
	total += 1
	if total > 8000:
		_check(false, "timeout in phase %d" % phase)
		phase = 99
	if m and is_instance_valid(m) and m.state == "running" and m.replay == null:
		m.advance(DT)
	match phase:
		0:
			bs = (load(BASEMENT) as PackedScene).instantiate()
			root.add_child(bs)
			_next(1)
		1:
			if frames < 3:
				return false
			_check(bs.start_mission(StoryMissions.beat("d5_hack")), "the hack starts")
			m = bs.mission_node as MissionHack
			for c: Dictionary in m.done.get_connections():
				m.done.disconnect(c["callable"])
			m.done.connect(func(info: Dictionary) -> void:
				got_done = true
				done_info = info)
			h = m.hack
			_check(m is MissionLairFight and is_equal_approx(m.time_left, 90.0) and m.phase == "typing", "MissionHack (a MissionLairFight): the 90 s clock")
			_check(m.fire.stage == 0 and m.fire.emitting_count() == 1 and m.fire.fires.size() == 4 and m.fire.smokes.size() == 2, "fire stage 0 from a pool of 4 + 2 emitters")
			_check(m.countdown_label.text.ends_with("01:30"), "the countdown on screen: %s" % m.countdown_label.text)
			_check(h.active and h.visible and not bs.player.controls_enabled and bs.weapons.current == WeaponData.Slot.UNARMED, "typing at the desk, guns away")
			_next(2)
		2:
			if frames < 120:
				return false
			for b: Dictionary in h.bullets.duplicate():
				if not bool(b["dead"]):
					h.type_text(String(b["word"]))
			_check(h.kills > 0 and h.hp < StoryHack.MAX_HP, "typing makes progress")
			m.time_left = m.countdown_s - MissionHack.BREACH_AT[0] + 0.01
			_next(3)
		3:
			if frames < 3:
				return false
			_check(m.phase == "breach" and m.breaches_started == 1 and m.cuts == 1, "30 s in: breach 1, a preview cut on the door")
			_check(h.paused and not h.visible and bs.player.controls_enabled, "the terminal hides, typing paused, the player moves")
			_check(m.fight != null and m.fight.state == "running" and m.fight.alive().size() == 3 and bs.weapons.current == WeaponData.Slot.PISTOL, "3 guards on Thường, the guns out")
			_check(m.fire.stage == 1, "60 s left: fire stage 1")
			snap = {"hp": h.hp, "leaks": h.leaks, "ys": _bullet_ys(), "t": h.t}
			_next(4)
		4:
			if frames < 120:
				return false
			_check(is_equal_approx(h.hp, float(snap["hp"])) and h.leaks == int(snap["leaks"]) and _bullet_ys() == snap["ys"] and is_equal_approx(h.t, float(snap["t"])), "no decay while paused")
			_check(h.type_char("a") == "paused", "no typing while paused")
			_ko_all()
			_next(5)
		5:
			if m.phase != "return" and frames < 60:
				return false
			_check(m.phase == "return" and m.breaches_cleared == 1 and is_zero_approx(m.breach_dmg), "breach cleared: back to the desk, no damage")
			_check(m.return_to_desk() and m.phase == "typing" and not h.paused and h.visible and not bs.player.controls_enabled, "[E]: typing resumes")
			_check(is_equal_approx(h.hp, float(snap["hp"])) and bs.weapons.current == WeaponData.Slot.UNARMED, "progress kept, guns away again")
			m.time_left = m.countdown_s - MissionHack.BREACH_AT[1] + 0.01
			_next(6)
		6:
			if frames < 3:
				return false
			_check(m.phase == "breach" and m.breaches_started == 2 and m.cuts == 2, "60 s in: breach 2")
			var g: Gunman = m.fight.alive()[0]
			m.fight.hit_player(g, 10.0)
			_check(m.breach_dmg > 0.0, "damage in a breach is counted")
			_ko_all()
			_next(7)
		7:
			if m.phase != "return" and frames < 60:
				return false
			m.return_to_desk()
			m.time_left = 29.0
			_next(8)
		8:
			if frames < 3:
				return false
			_check(m.fire.stage == 2 and m.fire.emitting_count() == 5, "30 s left: stage 2 (3 fires, 2 smoke)")
			m.time_left = 9.5
			_next(9)
		9:
			if frames < 3:
				return false
			_check(m.fire.stage == 3 and m.fire.emitting_count() == 6 and m.fire.get_child_count() == 7, "10 s left: stage 3, still the same pool")
			m.time_left = 0.01
			_next(10)
		10:
			if frames < 3:
				return false
			_check(m.state == "failed" and m.gas_fired == 1 and m.fight == null, "at 0 the gas fires: TOANG!")
			m.retry()
			_check(m.state == "running" and is_equal_approx(m.time_left, m.countdown_s) and m.fire.stage == 0 and m.breaches_started == 0 \
				and m.phase == "typing" and is_equal_approx(h.hp, StoryHack.MAX_HP) and h.active and not h.paused, "retry: the typing from the start (full timer, stage 0, no breach)")
			_next(11)
		11:
			var n: int = 0
			while h.final_bullet.is_empty() and n < 400:
				h.step(0.4)
				for b: Dictionary in h.bullets.duplicate():
					if not bool(b["dead"]):
						h.type_text(String(b["word"]))
				n += 1
			_check(h.type_text(StoryHack.FINAL_COMMAND) == "won" and m.phase == "won" and bs.level.fire_on, "typed before 0: wiped, the room burns")
			_next(12)
		12:
			if m.replay != null:
				var k: int = 0
				while is_instance_valid(m) and m.replay != null and k < 1200:
					m.replay.step(DT)
					k += 1
			if not got_done:
				if frames > 600:
					_check(false, "the hack never finished")
					phase = 99
				return false
			_check(bool(done_info.get("breach_clean", false)) and int(done_info.get("kills", 0)) > 0, "done: breach_clean (no breach this run)")
			_check(m.fire.emitting_count() == 0 and not m.fire.light.visible, "the emitters stopped after")
			bs._free_mission()
			phase = 99
		99:
			return _end()
	return false


func _end() -> bool:
	StoryBasement.test_opts = {}
	if bs and is_instance_valid(bs):
		bs.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	if fails.is_empty():
		print("SUCCESS: basement fire (clock, breaches, pause without decay, stages, gas and retry, win, pool stopped)")
		quit(0)
	else:
		print("FAILED: %d check(s)" % fails.size())
		quit(1)
	return true
