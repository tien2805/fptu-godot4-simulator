# File: res://tests/test_tower_boss.gd
# Headless test of the Day 7 final boss's signature (plan 2026-11-01-w4-day7.md T2), played in the real tower
# (StoryTower + LairTower, the player stack, the director at d7_boss1):
#   phase 1, the vase gallery: the twelve plinths are cover with HP; a guard's bullets stopped by a plinth chip it (no
#     damage to the player), it cracks at half and shatters at 0 (vase gone, debris, the stub's collider cut down, its
#     slots taken, the player pushed out of cover), and a bullet then flies over the stub and hits; Lọ shows up with a
#     preview cut; his aimed volley: the red beam tracks, locks, and only then the shots (no damage during the telegraph);
#     standing in the beam costs exactly 4 hits, stepping out after the lock costs nothing, crouching behind a plinth
#     costs the plinth; THỬ LẠI mends every vase and plinth; the damage stays after the win.
#   phase 2, the blackout: a preview cut to the first breaker; Lọ's wind-up (the telegraph: a whole vase cracks, the
#     nearest speaker pulses with his line) comes WIND_S before his lunge lands; the cracks go one by one and never on a
#     vase phase 1 broke; the speaker pulse fades out; the flashlight on him for LIT_S staggers him; "Giảm hù dọa" (read
#     again on THỬ LẠI): slower stalking, a longer wind-up, a softer hit, no laugh, a smaller pulse; the breakers take HOLD_S.
#   phase 3, the roof: a preview cut to him; the rain makes his lunges overshoot; every hit lands TELL_S after its glint
#     (white slash, red lunge), never before; the QTE at 0 HP: a miss (the window runs out: "Hụt!", 10 % HP back, the
#     duel goes on) and a pass with the Day 7 prompts in order ([Q] GẠT KIẾM, [Chuột trái] BẬT NHẢY, [E] KẸP CỔ SỐ 21) ->
#     "Đòn chân kẹp cổ số 21!", done with qte_clean false, the step moves on.
# Run:  godot --headless --path . --script tests/test_tower_boss.gd
extends SceneTree

const TimeAudit: Script = preload("res://tests/support/time_scale_audit.gd")

var TMP: String = "user://test_tower_boss_%d.cfg" % OS.get_process_id()
var TMP_U: String = "user://test_tower_boss_unlocks_%d.cfg" % OS.get_process_id()
var TMP_C: String = "user://test_tower_boss_chapters_%d.cfg" % OS.get_process_id()
var TMP_B: String = "user://test_tower_boss_backup_%d.cfg" % OS.get_process_id()
const DT: float = 1.0 / 60.0
const TOWER: String = "res://scenes/story/StoryTower.tscn"
var fails: Array[String] = []
var frames: int = 0
var total: int = 0
var phase: int = 0
var sd: Node
var sm: Node
var tw: StoryTower
var m: StoryMission
var mark: Dictionary = {}
var audit: Node = null
var fx: Node = null


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	print("--- TEST TOWER BOSS (Lùm Văn Lọ: the vase cover, the volley, the blackout, the rooftop QTE) ---")
	Engine.max_fps = 60
	sd = root.get_node("StoryDirector")
	sm = root.get_node("StageManager")
	sd.set("save_path", TMP)
	sd.set("nav_enabled", false)
	for p: String in [TMP, TMP_U, TMP_C, TMP_B]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	StoryChapters.unlocks_path = TMP_U
	StoryChapters.chapters_path = TMP_C
	StoryChapters.backup_path = TMP_B
	StoryTower.test_opts = {"missions": {"manual": true, "manual_replay": true, "manual_card": true, "seed": 3},
		"cine": {"manual": true, "music": false}, "capture_mouse": false}
	fx = root.get_node_or_null("GameFX")
	if fx:
		fx.set("reduce_scares", false)
	audit = TimeAudit.new()
	audit.name = "TimeScaleAudit"
	root.add_child(audit)


func _next(p: int) -> void:
	phase = p
	frames = 0


func _wait_mission(cls: String, cap: int = 150) -> StoryMission:
	var mn: StoryMission = tw.mission_node if tw else null
	if mn != null and is_instance_valid(mn) and String(mn.get_script().get_global_name()) == cls:
		return mn
	if frames > cap:
		_check(false, "%s did not start in the tower (step %s)" % [cls, String(sd.get("step"))])
		phase = 999
	return null


func _fail_shown(what: String, cap: int = 90) -> bool:
	if tw.fail_ui and tw.fail_ui.visible:
		return true
	if frames > cap:
		_check(false, "%s but no fail card" % what)
		phase = 999
	return false


func _at_step(id: String, what: String, cap: int = 1500) -> bool:
	if String(sd.get("step")) == id:
		return true
	if frames > cap:
		_check(false, "%s (step %s)" % [what, String(sd.get("step"))])
		phase = 999
	return false


func _timeout(cap: int, what: String) -> bool:
	if frames > cap:
		_check(false, what)
		phase = 999
		return true
	return false


func _finish_cine_in(host: Node) -> String:
	var cp: CinePlayer = host.get("cine_player")
	if cp == null:
		return ""
	var slot: String = cp.timeline.slot
	var n: int = 0
	while host.get("cine_player") != null and n < 6000:
		cp.step(DT)
		n += 1
	_check(host.get("cine_player") == null, "%s finished" % slot)
	return slot


func _step_card(mn: Object) -> void:
	var n: int = 0
	while mn.get("card") != null and n < 600:
		(mn.get("card") as StoryVillainCard).step(DT)
		n += 1


func _step_replay(mn: StoryMission) -> bool:
	if mn == null or not is_instance_valid(mn) or mn.replay == null:
		return false
	var n: int = 0
	while is_instance_valid(mn) and mn.replay != null and n < 1200:
		mn.replay.step(DT)
		n += 1
	return true


## Every standing gunman frozen (no AI shots in the measured windows).
func _freeze(f: GunFight) -> void:
	for g: Variant in f.gunmen:
		if g is Gunman and is_instance_valid(g) and not (g as Gunman).is_defeated():
			(g as Gunman).ai = false
			(g as Gunman).call("_cancel_shot")
			(g as Gunman).call("_enter", Gunman.St.HOLD)


func _ko_all(f: GunFight, hits: int = 80) -> void:
	for e: Variant in f.alive():
		if e is Gunman:
			var n: int = 0
			while not (e as Gunman).is_defeated() and n < hits:
				(e as Gunman).take_hit({"kind": "bullet", "from": tw.player.global_position})
				n += 1


## A plinth slot that hides the player from `shooter` (its bullet ray at the crouched player hits that plinth, and past the
## plinth the line is clear): the player enters it (Ctrl held). [slot, vase index] or [-1, -1].
func _hide_from(mg: MissionBossGuns, shooter: Gunman) -> Array:
	var f: GunFight = mg.fight
	f.cover_ctl.hold_override = true
	for vi: int in mg.cover_vases.size():
		var v: Dictionary = mg.cover_vases[vi]
		if bool(v["broken"]):
			continue
		for s: int in (v["slots"] as PackedInt32Array):
			if f.taken.has(s) or not f.cover.protects(s, shooter.global_position):
				continue
			f.cover_ctl.enter(s)
			var a: Vector3 = shooter.muzzle_pos()
			var tp: Vector3 = f.player_target()
			var h: Dictionary = f.ray(a, tp)
			if mg.vase_of(h) == vi and f.cover_ctl.hidden():
				var past: Vector3 = (h["position"] as Vector3) + (a - tp).normalized() * 1.2
				if f.clear_line(past, a):
					return [s, vi]
			f.cover_ctl.leave()
	f.cover_ctl.hold_override = false
	return [-1, -1]


func _crack_vis(vase: Node3D) -> bool:
	var cr: Node3D = vase.get_node_or_null("Cracks") as Node3D
	return cr != null and (cr.get_child(0) as Node3D).visible


func _rings_lit() -> int:
	var n: int = 0
	for s: Node3D in tw.level.speakers:
		if (s.get_node("Ring") as Node3D).visible:
			n += 1
	return n


func _process(_d: float) -> bool:
	frames += 1
	total += 1
	if total > 40000:
		_check(false, "timeout in phase %d" % phase)
		phase = 999
	if phase == 999:
		return _end()
	if tw and is_instance_valid(tw) and tw.mission_node and is_instance_valid(tw.mission_node) and tw.mission_node.state == "running" \
			and tw.mission_node.replay == null and not paused:
		tw.mission_node.advance(DT)
	match phase:
		0:
			sd.call("new_story", {"female": false, "name": "Minh", "variant": 0, "hair_style": "short", "hair_color": 1, "skin": 1})
			sd.set("day", 7)
			sd.call("_enter", "d7_boss1")
			_check(String(sd.get("step")) == "d7_boss1", "the director at d7_boss1")
			tw = (load(TOWER) as PackedScene).instantiate()
			root.add_child(tw)
			_next(1)
		# ===== phase 1: the vase gallery =====
		1:
			m = _wait_mission("MissionBossGuns")
			if m == null:
				return false
			var mg: MissionBossGuns = m
			_step_card(mg)
			var f: GunFight = mg.fight
			f.cover_ctl.hold_override = false
			_check(mg.cover_vases.size() == 12 and is_equal_approx(mg.vase_max, MissionBossGuns.VASE_HP), "twelve vase plinths with %.0f HP each (Thường)" % mg.vase_max)
			var all_slots: Dictionary = {}
			var ok_v: bool = true
			for v: Dictionary in mg.cover_vases:
				ok_v = ok_v and (v["slots"] as PackedInt32Array).size() >= 2 and v["cs"] != null and v["prop"] != null and is_equal_approx(float(v["hp"]), mg.vase_max)
				for s: int in (v["slots"] as PackedInt32Array):
					ok_v = ok_v and not all_slots.has(s) and f.cover.slot_box[s] >= 0
					all_slots[s] = true
			_check(ok_v, "every plinth: its own cover slots, its collider and its column")
			_check(mg.volley_state == "idle" and mg.lo == null, "no volley before Lọ shows up")
			_freeze(f)
			mark["hp0"] = tw.combat.hp
			_next(2)
		2:
			if frames < 3:
				return false
			var mg: MissionBossGuns = m
			var f: GunFight = mg.fight
			var g: Gunman = null
			var hid: Array = [-1, -1]
			for e: Variant in f.gunmen:
				if e is Gunman and not (e as Gunman).is_defeated():
					hid = _hide_from(mg, e)
					if int(hid[0]) >= 0:
						g = e
						break
			_check(g != null, "a plinth hides the player from a guard (cover found)")
			if g == null:
				phase = 999
				return false
			var vi: int = int(hid[1])
			var v: Dictionary = mg.cover_vases[vi]
			mark["vi"] = vi
			mark["slot"] = int(hid[0])
			mark["g"] = g
			var hp: float = tw.combat.hp
			var res: Array[String] = []
			g.shot.connect(func(_g: Gunman, r: String) -> void: res.append(r))
			for k: int in 3:
				g.call("_fire")
			_check(res == ["blocked", "blocked", "blocked"] and is_equal_approx(tw.combat.hp, hp), "three guard bullets stopped by the plinth, no damage")
			_check(is_equal_approx(float(v["hp"]), mg.vase_max - 3.0 * MissionBossGuns.GUARD_CHIP) and mg.vase_hits == 3 and not bool(v["cracked"]), "each one chips the plinth (%.1f HP left)" % float(v["hp"]))
			_check(not _crack_vis(v["vase"]), "no cracks above half HP")
			g.call("_fire")
			_check(bool(v["cracked"]) and _crack_vis(v["vase"]) and (v["vase"] as Node3D).visible, "half HP: the vase cracks")
			var clk: Impact = Impact.clock(mg)
			var fx0: int = clk.fx_log.size() if clk else 0
			while not bool(v["broken"]) and res.size() < 20:
				g.call("_fire")
			f.cover_ctl.hold_override = false
			_check(res.size() == 8 and res.count("blocked") == 8 and is_equal_approx(tw.combat.hp, hp), "eight bullets shatter it (%d), all stopped" % res.size())
			_check(bool(v["broken"]) and mg.shattered == 1 and not (v["vase"] as Node3D).visible, "0 HP: the vase shatters")
			var cs: CollisionShape3D = v["cs"]
			_check(is_equal_approx((cs.shape as BoxShape3D).size.y, MissionBossGuns.STUB_H) and is_equal_approx((v["prop"] as Node3D).scale.y, MissionBossGuns.STUB_H / CinePropsD7.PLINTH_H), "the plinth crumbles to a %.2f m stub" % MissionBossGuns.STUB_H)
			var taken_ok: bool = true
			for s: int in (v["slots"] as PackedInt32Array):
				taken_ok = taken_ok and f.taken.get(s) == mg
			_check(taken_ok and not f.cover_ctl.in_cover, "its cover slots are gone, the player pushed out of cover")
			_check(not (v["slots"] as PackedInt32Array).has(f.cover.nearest(tw.player.global_position, 3.0, f.taken, tw.player)), "the next cover offered is another plinth")
			var kinds: Array = clk.fx_log.slice(fx0) if clk else []
			_check(kinds.has("debris") and kinds.has("dust_ring"), "the shatter: debris and the heavy Impact dust (%s)" % str(kinds))
			_check(mg.popup_label.text == MissionBossGuns.T_SHATTER, "Bình cổ vỡ! Chỗ nấp sập rồi!")
			mark["res"] = res
			_next(3)
		3:
			if frames < 3:
				return false
			# a bullet now flies over the stub at the crouch height, and the guard's shot lands
			var mg: MissionBossGuns = m
			var f: GunFight = mg.fight
			var g: Gunman = mark["g"]
			var crouch: Vector3 = tw.player.global_position + Vector3(0.0, 0.65, 0.0)
			_check(mg.vase_of(f.ray(g.muzzle_pos(), crouch)) != int(mark["vi"]), "the line over the stub is open at the crouch height")
			var res: Array = mark["res"]
			var hp: float = tw.combat.hp
			g.accuracy_override = 1.0
			g.call("_fire")
			_check(String(res.back()) == "hit" and tw.combat.hp < hp, "no cover left: the next bullet hits (%s)" % String(res.back()))
			_ko_all(f)
			_next(4)
		4:
			var mg: MissionBossGuns = m
			if mg.lo == null:
				_timeout(400, "wave 2 (Lọ) did not come")
				return false
			_check(mg.cuts == 1, "a preview cut to Lọ when he shows up")
			_check(mg.volley_state == "wait" and mg.popup_label.text == MissionBossGuns.T_LO_UP, "Lùm Văn Lọ ra mặt! (the volley timer runs)")
			_freeze(mg.fight)
			tw.combat.regen_delay = 999.0
			tw.combat.revive()
			# out in the open, in his line
			var spot: Vector3 = Vector3.INF
			for dx: float in [0.0, 1.5, -1.5, 6.0, -6.0]:
				var p: Vector3 = (mg.pts["boss_at"] as Vector3) + Vector3(dx, 0.0, 11.0)
				tw.player.teleport(p, 0.0)
				if mg.fight.clear_line(mg.lo.muzzle_pos(), p + Vector3(0.0, GunData.TARGET_STAND_Y, 0.0)):
					spot = p
					break
			_check(spot != Vector3.INF, "a spot in the open in Lọ's line")
			mark["spot"] = spot
			mark["lo_f"] = total
			_next(5)
		5:
			# the first volley by itself, VOLLEY_FIRST_S after he shows up: the telegraph, then the shots
			var mg: MissionBossGuns = m
			if mg.volley_state == "tele" and not mark.has("tele_f"):
				mark["tele_f"] = total
				mark["hp_t"] = tw.combat.hp
				var waited: float = float(total - int(mark["lo_f"])) * DT
				_check(absf(waited - MissionBossGuns.VOLLEY_FIRST_S) < 0.15 and mg.volleys == 1, "the first volley %.2f s after he shows up" % waited)
				_check(mg.beam.visible and mg.popup_label.text == MissionBossGuns.T_VOLLEY and mg.cues_played.has("radio"), "the telegraph: the red beam, the warning, his line")
				_check(not mg.volley_locked and absf(mg.beam.global_transform.basis.x.length() - MissionBossGuns.BEAM_W) < 0.002, "the beam tracks first (thin)")
			if mark.has("tele_f") and mg.volley_shots == 0:
				if not is_equal_approx(tw.combat.hp, float(mark["hp_t"])):
					mark["early_dmg"] = true
				if mg.volley_locked and not mark.has("lock_f"):
					mark["lock_f"] = total
					_check(absf(mg.beam.global_transform.basis.x.length() - MissionBossGuns.BEAM_W_LOCK) < 0.002, "then it locks (thick)")
			if mg.volley_shots > 0 and not mark.has("shot_f"):
				mark["shot_f"] = total
			if mg.volley_state == "wait" and mark.has("shot_f"):
				var tele_frames: int = int(mark["shot_f"]) - int(mark["tele_f"])
				var lock_frames: int = int(mark.get("lock_f", 0)) - int(mark["tele_f"])
				_check(not mark.has("early_dmg"), "no damage during the telegraph")
				_check(tele_frames >= roundi(mg.tele_s() * 60.0) - 1 and tele_frames >= 30, "the shots come %d frames after the beam (>= %.1f s)" % [tele_frames, mg.tele_s()])
				_check(lock_frames >= roundi(mg.tele_s() * MissionBossGuns.VOLLEY_TRACK_K * 60.0) - 1 and lock_frames < tele_frames, "the lock %d frames in" % lock_frames)
				var dmg: float = GunData.gunman_dmg() * MissionBossGuns.VOLLEY_DMG_K
				_check(mg.volley_shots == MissionBossGuns.VOLLEY_N and mg.volley_hits == MissionBossGuns.VOLLEY_N, "standing in the beam: %d of %d shots hit" % [mg.volley_hits, mg.volley_shots])
				_check(absf(tw.combat.hp - (float(mark["hp_t"]) - dmg * MissionBossGuns.VOLLEY_N)) < 0.01, "4 x %.1f HP (%.1f left)" % [dmg, tw.combat.hp])
				_check(not mg.beam.visible, "the beam is gone after the shots")
				tw.combat.revive()
				mark["hp_d"] = tw.combat.hp
				mark["hits_d"] = mg.volley_hits
				_check(mg.start_volley(), "a second volley (dodge test)")
				_next(6)
				return false
			_timeout(500, "the first volley did not finish (state %s)" % mg.volley_state)
		6:
			# stepping out of the beam after the lock: every shot misses
			var mg: MissionBossGuns = m
			if mg.volley_locked and not mark.has("dodged"):
				mark["dodged"] = true
				tw.player.teleport((mark["spot"] as Vector3) + Vector3(2.5, 0.0, 0.0), 0.0)
			if mg.volley_state == "wait":
				_check(mark.has("dodged") and mg.volley_shots == 2 * MissionBossGuns.VOLLEY_N, "the dodge volley fired (%d shots)" % mg.volley_shots)
				_check(mg.volley_hits == int(mark["hits_d"]) and is_equal_approx(tw.combat.hp, float(mark["hp_d"])), "out of the locked beam: no hit")
				var hid: Array = _hide_from(mg, mg.lo)
				_check(int(hid[0]) >= 0, "a plinth between Lọ and the player")
				mark["vi2"] = int(hid[1])
				mark["slot2"] = int(hid[0])
				mark["sh2"] = mg.shattered
				mark["vh2"] = mg.vase_hits
				_check(mg.start_volley(), "a third volley (cover test)")
				_next(7)
				return false
			_timeout(300, "the dodge volley did not finish")
		7:
			# crouched behind a plinth: the volley costs the plinth, not HP
			var mg: MissionBossGuns = m
			if mg.shattered > int(mark["sh2"]):
				mg.fight.cover_ctl.hold_override = false
			if mg.volley_state == "wait":
				mg.fight.cover_ctl.hold_override = false
				var v2: Dictionary = mg.cover_vases[int(mark["vi2"])]
				_check(mg.vase_hits - int(mark["vh2"]) == MissionBossGuns.VOLLEY_N and bool(v2["broken"]) and mg.shattered == int(mark["sh2"]) + 1, "four volley shots break the plinth in front (%d chips)" % (mg.vase_hits - int(mark["vh2"])))
				_check(mg.volley_hits == int(mark["hits_d"]) and is_equal_approx(tw.combat.hp, float(mark["hp_d"])), "the plinth took the volley, not the player")
				_check(not mg.fight.cover_ctl.in_cover, "pushed out of the broken cover")
				_check(is_equal_approx(mg._next_volley, MissionBossGuns.VOLLEY_EVERY), "the next volley in %.1f s" % mg._next_volley)
				mg.fight.combat.receive_attack(mg.lo, {"damage": 999.0})
				_next(8)
				return false
			_timeout(300, "the cover volley did not finish")
		8:
			if not _fail_shown("down in the gallery"):
				return false
			var mg: MissionBossGuns = m
			_check(mg.shattered >= 2, "two plinths broken before THỬ LẠI")
			tw.fail_ui.press_retry()
			var ok: bool = true
			for v: Dictionary in mg.cover_vases:
				var cs: CollisionShape3D = v["cs"]
				ok = ok and not bool(v["broken"]) and not bool(v["cracked"]) and is_equal_approx(float(v["hp"]), mg.vase_max) \
					and (v["vase"] as Node3D).visible and not _crack_vis(v["vase"]) and is_equal_approx((cs.shape as BoxShape3D).size.y, CinePropsD7.PLINTH_H) \
					and (v["prop"] as Node3D).scale.is_equal_approx(Vector3.ONE)
				for s: int in (v["slots"] as PackedInt32Array):
					ok = ok and mg.fight.taken.get(s) != mg
			_check(ok, "THỬ LẠI: every vase and plinth whole again, their slots free")
			_check(mg.fight.state == "running" and mg.fight.wave == 1 and mg.lo != null and mg.volley_state == "wait" and not mg.beam.visible, "retry at Lọ's wave, the volley timer reset")
			_freeze(mg.fight)
			_next(9)
		9:
			if frames < 3:
				return false
			var mg: MissionBossGuns = m
			var f: GunFight = mg.fight
			var crouch: Vector3 = f.cover.pos[int(mark["slot2"])] + Vector3(0.0, 0.65, 0.0)
			_check(mg.vase_of(f.ray(mg.lo.muzzle_pos(), crouch)) == int(mark["vi2"]), "the mended plinth stops bullets again")
			# a vase broken before the win stays broken (the monologue and the blackout play in the same hall)
			_freeze(f)
			var k: int = -1
			for i: int in mg.cover_vases.size():
				if flat_d((mg.cover_vases[i]["body"] as Node3D).global_position, mg.pts["boss_at"]) < 9.0:
					k = i
			mark["k"] = k
			_check(k >= 0 and mg.damage_vase(k, 99.0) == "shatter", "a vase near his desk shatters")
			mark["k_node"] = mg.cover_vases[k]["vase"]
			mark["k_cs"] = mg.cover_vases[k]["cs"]
			_ko_all(f)
			_next(10)
		10:
			var mg: MissionBossGuns = m as MissionBossGuns if is_instance_valid(m) else null
			if mg and _step_replay(mg):
				mark["replay1"] = true
			if tw.cine_player == null:
				_timeout(900, "the monologue did not start")
				return false
			_check(mark.has("replay1") and String(sd.get("step")) == "d7_monologue", "Lọ beaten: the replay, then the monologue")
			_check(not (mark["k_node"] as Node3D).visible and is_equal_approx(((mark["k_cs"] as CollisionShape3D).shape as BoxShape3D).size.y, MissionBossGuns.STUB_H), "the broken vase stays broken after the win")
			_finish_cine_in(tw)
			_next(11)
		# ===== phase 2: the blackout =====
		11:
			m = _wait_mission("MissionBossDark")
			if m == null:
				return false
			var md: MissionBossDark = m
			_check(md.cuts == 1, "a preview cut to the first breaker as the lights die")
			_check(not md.gentle and not md.flashlight.gentle, "Giảm hù dọa off")
			tw.combat.revive()
			md.lit_override = 0
			md.lo.global_position = tw.player.global_position + Vector3(0.0, 0.0, -2.6)
			mark["hp2"] = tw.combat.hp
			mark["laughs"] = md.cues_played.count("evil_laugh")
			_next(12)
		12:
			var md: MissionBossDark = m
			if md.lo_state == "wind" and not mark.has("wind_f"):
				mark["wind_f"] = total
				_check(md.cracks == 1 and md._cracked.size() == 1 and _crack_vis(md._cracked[0]), "the telegraph: a whole vase cracks")
				_check(md.pulses == 1 and md.ring != null and md.ring.visible and _rings_lit() == 1, "his voice from one speaker: its ring pulses")
				_check(md.cues_played.has("glass_crack") and md.cues_played.has("radio") and md.radio_panel.visible, "the crack sound and his line as a subtitle")
				_check(is_equal_approx(tw.combat.hp, float(mark["hp2"])), "no damage at the telegraph")
				mark["ring_max"] = 1.0
			if mark.has("wind_f") and md.hits == 0:
				if not is_equal_approx(tw.combat.hp, float(mark["hp2"])):
					mark["early2"] = true
				if md.ring:
					mark["ring_max"] = maxf(float(mark["ring_max"]), md.ring.scale.x)
			if md.hits >= 1:
				var wf: int = total - int(mark.get("wind_f", total))
				_check(mark.has("wind_f") and not mark.has("early2"), "nothing hurts during the wind-up")
				_check(wf >= roundi(MissionBossDark.WIND_S * 60.0) - 1, "the lunge lands %d frames after the telegraph (>= %.1f s)" % [wf, MissionBossDark.WIND_S])
				_check(absf(tw.combat.hp - (float(mark["hp2"]) - MissionBossDark.HIT_DMG)) < 0.01, "his lunge costs %.0f HP" % MissionBossDark.HIT_DMG)
				_check(float(mark["ring_max"]) > 1.1, "the ring beats with his voice (x%.2f)" % float(mark["ring_max"]))
				_check(md.cues_played.count("evil_laugh") > int(mark["laughs"]), "the laugh (Giảm hù dọa off)")
				mark["hit_f"] = total
				_next(13)
				return false
			_timeout(300, "Lọ's lunge did not land (state %s)" % md.lo_state)
		13:
			var md: MissionBossDark = m
			if total - int(mark["hit_f"]) < roundi((MissionBossDark.PULSE_S + 0.1) * 60.0):
				return false
			_check(md.ring == null and _rings_lit() == 0, "the pulse fades out: the speakers dark again")
			var sp_ok: bool = true
			for s: Node3D in tw.level.speakers:
				sp_ok = sp_ok and (s.get_node("Ring") as Node3D).scale.is_equal_approx(Vector3.ONE)
			_check(sp_ok, "the rings back to their size")
			# the cracks go one by one, never on the vase phase 1 broke
			var lo_at: Vector3 = md.lo.global_position
			var st: String = md.lo_state
			md.lo.global_position = (mark["k_node"] as Node3D).global_position + Vector3(0.4, 0.0, 0.0)
			md._telegraph()
			md._telegraph()
			var c: Array[Node3D] = md._cracked
			_check(c.size() == 3 and c[1] != c[2] and c[1] != c[0] and c[2] != c[0], "one more vase cracks per telegraph")
			_check(not c.has(mark["k_node"]) and _crack_vis(c[1]) and _crack_vis(c[2]), "never the vase phase 1 shattered")
			md.lo.global_position = lo_at
			md.lo_state = st
			_next(14)
		14:
			# the flashlight on him for LIT_S staggers him
			var md: MissionBossDark = m
			if md.lo_state == "stalk" and md.lit_override != 1:
				md.lit_override = 1
				mark["lit_f"] = total
				mark["hp4"] = tw.combat.hp
			if md.staggers >= 1:
				var lf: int = total - int(mark["lit_f"])
				_check(lf >= roundi(MissionBossDark.LIT_S * 60.0) - 1, "lit for %d frames before the stagger (>= %.1f s)" % [lf, MissionBossDark.LIT_S])
				_check(md.lo_state == "stagger" and md.popup_label.text == MissionBossDark.T_STAGGER and is_equal_approx(tw.combat.hp, float(mark["hp4"])), "the beam staggers him")
				# "Giảm hù dọa" switched on before THỬ LẠI
				if fx:
					fx.set("reduce_scares", true)
				tw.combat.receive_attack(md.lo, {"damage": 999.0})
				_next(15)
				return false
			_timeout(600, "the flashlight did not stagger Lọ (state %s)" % md.lo_state)
		15:
			if not _fail_shown("down in the blackout"):
				return false
			tw.fail_ui.press_retry()
			var md: MissionBossDark = m
			_check(md.gentle and md.flashlight.gentle, "THỬ LẠI reads Giảm hù dọa again: gentle")
			_check(LookPresets.active(tw) == MissionBossDark.LOOK_GENTLE and md.look_on == MissionBossDark.LOOK_GENTLE and not tw.looks.has(MissionBossDark.LOOK), "gentle: the lighter blackout look, the dark one taken off")
			_check(md._cracked.is_empty(), "the failed try's cracks forgotten")
			var mended: bool = true
			for v: Dictionary in tw.level.vases:
				if (v["node"] as Node3D).visible:
					mended = mended and not _crack_vis(v["node"])
			_check(mended, "THỬ LẠI mends the cracks of the failed try")
			md.lit_override = 0
			md.lo.global_position = tw.player.global_position + Vector3(0.0, 0.0, -4.4)
			mark["lo15"] = md.lo.global_position
			mark["hp5"] = tw.combat.hp
			mark["laughs5"] = md.cues_played.count("evil_laugh")
			mark.erase("wind_f")
			mark.erase("ring_max")
			_next(16)
		16:
			var md: MissionBossDark = m
			if frames == 31:
				var walked: float = Vector2(md.lo.global_position.x - (mark["lo15"] as Vector3).x, md.lo.global_position.z - (mark["lo15"] as Vector3).z).length()
				_check(absf(walked - MissionBossDark.STALK_MS_GENTLE * 0.5) < 0.06, "gentle: he stalks slower (%.2f m in 0.5 s)" % walked)
			if md.lo_state == "wind" and not mark.has("wind_f"):
				mark["wind_f"] = total
				mark["ring_max"] = 1.0
			if mark.has("wind_f") and md.ring:
				mark["ring_max"] = maxf(float(mark["ring_max"]), md.ring.scale.x)
			if md.hits >= 2:
				var wf: int = total - int(mark["wind_f"])
				_check(wf >= roundi(MissionBossDark.WIND_S_GENTLE * 60.0) - 1, "gentle: a longer wind-up (%d frames)" % wf)
				_check(absf(tw.combat.hp - (float(mark["hp5"]) - MissionBossDark.HIT_DMG_GENTLE)) < 0.01, "gentle: a softer hit (%.0f HP)" % MissionBossDark.HIT_DMG_GENTLE)
				_check(md.cues_played.count("evil_laugh") == int(mark["laughs5"]), "gentle: no laugh")
				_check(float(mark["ring_max"]) <= 1.0 + MissionBossDark.PULSE_AMP_GENTLE + 0.01, "gentle: a smaller pulse (x%.2f)" % float(mark["ring_max"]))
				if fx:
					fx.set("reduce_scares", false)
				md.lit_override = 1
				md.hold_override = true
				tw.player.teleport(md.pts["breakers"][0], 0.0)
				mark["br_f"] = total
				_next(17)
				return false
			_timeout(600, "the gentle lunge did not land (state %s)" % md.lo_state)
		17:
			var md: MissionBossDark = m as MissionBossDark if is_instance_valid(m) else null
			if md and md.state == "running":
				if md.restored[0] and not mark.has("br0"):
					mark["br0"] = true
					var hf: int = total - int(mark["br_f"])
					_check(hf >= roundi(MissionBossDark.HOLD_S * 60.0) - 1, "a breaker takes HOLD_S of [E] (%d frames)" % hf)
					tw.player.teleport(md.pts["breakers"][1], 0.0)
			if not _at_step("d7_boss3", "the power did not come back", 1500):   # two HOLD_S holds
				return false
			_check(mark.has("br0") and tw.level.power_on, "both breakers: the power back")
			_check(_finish_cine_in(tw) == "seg_d7_phase2", "the power back: seg_d7_phase2 (d7_boss2's after) plays before the roof")
			_next(18)
		# ===== phase 3: the roof =====
		18:
			m = _wait_mission("MissionBossSaber")
			if m == null:
				return false
			var mb: MissionBossSaber = m
			var boss: KatanaBoss = mb.duel.boss
			_check(mb.cuts == 1, "a preview cut to Lọ on the helipad")
			_check(is_equal_approx(boss.lunge_k, 1.2), "the rain: his lunges overshoot (x%.1f)" % boss.lunge_k)
			mb.duel.won.connect(func() -> void: mark["finish_popup"] = mb.popup_label.text if mb.popup_label else "")
			mb.done.connect(func(info: Dictionary) -> void: mark["done3"] = info)
			_next(19)
		19:
			var mb: MissionBossSaber = m
			var boss: KatanaBoss = mb.duel.boss
			if frames < 40 or not boss.is_hostile():
				_timeout(400, "Lọ never turned hostile on the roof")
				return false
			var to: Vector3 = tw.player.global_position - boss.global_position
			to.y = 0.0
			to = to.normalized() if to.length() > 0.1 else Vector3.BACK
			tw.player.teleport(boss.global_position + to * 1.5, atan2(to.x, to.z))
			mark["h0"] = boss.hit_log.size()
			mark["t0"] = boss.tells.size()
			mark["hp3"] = tw.combat.hp
			boss.force_pattern("slash_r")
			_next(20)
		20:
			var mb: MissionBossSaber = m
			var boss: KatanaBoss = mb.duel.boss
			if boss.hit_log.size() <= int(mark["h0"]):
				if not is_equal_approx(tw.combat.hp, float(mark["hp3"])):
					mark["early3"] = true
				_timeout(240, "the forced slash never resolved")
				return false
			_check(_told(boss, int(mark["t0"]), "slash_r", false), "a white glint tells the slash")
			_check(not mark.has("early3"), "no damage before the slash lands")
			mark["h1"] = boss.hit_log.size()
			mark["t1"] = boss.tells.size()
			boss.force_pattern("lunge")
			_next(21)
		21:
			var mb: MissionBossSaber = m
			var boss: KatanaBoss = mb.duel.boss
			if boss.hit_log.size() <= int(mark["h1"]):
				_timeout(240, "the forced lunge never resolved")
				return false
			_check(_told(boss, int(mark["t1"]), "lunge", true), "a red glint tells the lunge (unblockable)")
			# every hit of the run came TELL_S after its own tell
			var ok: bool = true
			for h: Dictionary in boss.hit_log.slice(int(mark["h0"])):
				var lead: float = -1.0
				for tl: Dictionary in boss.tells:
					if String(tl["step"]) == String(h["step"]) and float(tl["t"]) <= float(h["t"]) + 1e-4:
						lead = float(h["t"]) - float(tl["t"])
				ok = ok and absf(lead - SwordData.tell_s()) <= 0.03
			_check(ok, "every hit lands %.2f s after its glint" % SwordData.tell_s())
			tw.combat.revive()
			_check(boss.take_strike({"kind": "slash1", "dmg": boss.hp + 1.0, "stagger": 0.0, "from": tw.player.global_position}) == "ko", "the last hit lands")
			_next(22)
		22:
			# the QTE miss: the window runs out
			var mb: MissionBossSaber = m
			var d: SwordDuel = mb.duel
			if frames == 2:
				_check(d.in_qte and d.qte_attempts == 1 and d.qte.label.text == "[Q] GẠT KIẾM", "0 HP: the QTE, [Q] GẠT KIẾM first")
			if frames > 2 and not d.in_qte:
				_check(d.qte.results == ["late"] and d.combat.hud.popup_text == SwordDuel.T_QTE_MISS, "no key: the window runs out, Hụt!")
				_check(is_equal_approx(d.boss.hp, d.boss.max_hp * SwordDuel.QTE_RECOVER) and d.state == "running" and mb.state == "running", "a miss: 10 %% HP back, the duel goes on")
				_check(is_equal_approx(Engine.time_scale, 1.0), "the time scale back after the miss")
				_next(23)
				return false
			_timeout(1500, "the QTE window never ran out")
		23:
			var mb: MissionBossSaber = m
			var d: SwordDuel = mb.duel
			if frames < 5:
				return false
			_check(d.boss.take_strike({"kind": "slash1", "dmg": d.boss.hp + 1.0, "stagger": 0.0, "from": tw.player.global_position}) == "ko" and d.in_qte and d.qte_attempts == 2, "0 HP again: the QTE again")
			var labels: Array[String] = [d.qte.label.text]
			_check(d.qte.press("q") == "hit", "[Q] in time")
			labels.append(d.qte.label.text)
			_check(d.qte.press("lmb") == "hit", "[Chuột trái] in time")
			labels.append(d.qte.label.text)
			_check(labels == ["[Q] GẠT KIẾM", "[Chuột trái] BẬT NHẢY", "[E] KẸP CỔ SỐ 21"], "the Day 7 prompts in order (%s)" % str(labels))
			_check(d.qte.press("e") == "hit", "[E]: the scissor takedown")
			_next(24)
		24:
			if not _at_step("d7_typing", "the rooftop duel was not won", 1200):
				return false
			_check(String(mark.get("finish_popup", "")) == MissionBossSaber.T_FINISH, "Đòn chân kẹp cổ số 21!")
			var info: Dictionary = mark.get("done3", {})
			_check(info.has("qte_clean") and not bool(info["qte_clean"]), "done: qte_clean false after a miss")
			_check(is_equal_approx(Engine.time_scale, 1.0) and tw.looks.is_empty(), "the time scale and the look restored")
			phase = 999
	return false


## A tell of `step` (red or white) logged since index `from`.
func _told(boss: KatanaBoss, from: int, step: String, red: bool) -> bool:
	for tl: Dictionary in boss.tells.slice(from):
		if String(tl["step"]) == step and bool(tl["red"]) == red:
			return true
	print("    tells since %d: %s" % [from, str(boss.tells.slice(from))])
	return false


static func flat_d(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _end() -> bool:
	if audit:
		print("  ", audit.call("report"))
		_check(bool(audit.call("clean", 6.0)), "the time scale stayed in the owner protocol (%s)" % String(audit.call("report")))
	if fx:
		fx.set("reduce_scares", false)
	if tw and is_instance_valid(tw):
		tw.queue_free()
	paused = false
	for p: String in [TMP, TMP_U, TMP_C, TMP_B]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	StoryChapters.unlocks_path = StoryChapters.UNLOCKS_PATH
	StoryChapters.chapters_path = StoryChapters.CHAPTERS_PATH
	StoryChapters.backup_path = StoryChapters.BACKUP_PATH
	StoryTower.test_opts = {}
	sm.set("story_context", {})
	sd.call("hide_result")
	sd.call("reset_state")
	sd.set("save_path", "user://story_save.cfg")
	if fails.is_empty():
		print("✅ SUCCESS: TOWER BOSS (vase cover chips / cracks / shatters / crumbles + reprune, the volley telegraph, dodge and cover, retry mends; the blackout telegraph, cracks, pulse, light stagger, gentle; the rooftop tells, QTE miss and pass)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true
