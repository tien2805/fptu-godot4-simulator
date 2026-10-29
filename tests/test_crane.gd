# File: res://tests/test_crane.gd
# W3 Day 3 T4 (plan 2026-10-30-w3-day3.md): the yard's container crane (YardCrane) in the real yard (FreeRoam +
# LairYard + a GunFight on the yard's cover with held gunmen):
#   A the ladder prompt, [E] climb (1.2 s), the cabin (player up there, controls off, the cabin camera current, framing the
#     hook and the footprint, META_FX), WASD moves the trolley / gantry at 2.5 m/s (the player rides along);
#   B a drop: the rattle, a 0.6 s fall, the gunmen in the footprint knocked out (only them), the container stays as cover:
#     new slots offered to the player and the gunmen; drops_left; the next container on the hook;
#   C [F] leaves (the gameplay camera back, controls back); Dễ: cabin accuracy x0.6 while up there;
#   D retry: reset() puts the drops back, removes the dropped containers and holds their slots.
# Run:  godot --headless --path . --script tests/test_crane.gd
extends SceneTree

const DT: float = 1.0 / 60.0
var fails: Array[String] = []
var frames: int = 0
var phase: int = 0
var fr: Node3D
var yard: LairYard
var fight: GunFight
var crane: YardCrane


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	print("--- TEST CRANE (W3 Day 3 T4) ---")
	Engine.max_fps = 60
	Difficulty.set_easy(false)


func _player() -> ThirdPersonController:
	return fr.get("player")


func _step(secs: float) -> void:
	for i: int in int(round(secs / DT)):
		crane.step(DT)


func _process(_d: float) -> bool:
	frames += 1
	if frames > 3000:
		_check(false, "timeout in phase %d" % phase)
		return _end()
	match phase:
		0:
			fr = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
			fr.set("crowd_enabled", false)
			root.add_child(fr)
			phase = 1
			frames = 0
		1:
			if frames < 20:
				return false
			fr.call("set_time_of_day", "night")
			yard = LairYard.new()
			yard.build_in(fr)
			(fr.get("combat") as PlayerCombat).god = true
			fight = GunFight.new()
			fight.name = "CraneFight"
			fr.add_child(fight)
			fight.setup({"roam": fr, "cover_root": yard.cover_root, "seed": 4})
			var w: Array = []
			# two under the first drop spot (gantry z 5, trolley x 0), one 6 m off it
			for p: Vector3 in [Vector3(-1.0, 0.0, 5.0), Vector3(1.5, 0.0, 5.4), Vector3(0.0, 0.0, 11.0)]:
				w.append({"at": yard.world(p), "opts": {"ai": false, "mask": "none"}})
			fight.add_wave(w)
			fight.start()
			crane = YardCrane.new()
			fr.add_child(crane)
			crane.setup(yard.global_transform, fight, 3, 5.0, 0.0)
			_player().teleport(yard.world(Vector3(-14.0, 0.0, 9.0)), 0.0)
			phase = 2
			frames = 0
		2:
			if frames < 3:
				return false
			var p: ThirdPersonController = _player()
			var game_cam: Camera3D = fr.get_viewport().get_camera_3d()
			# A
			crane.step(DT)
			_check(crane.hint() == "" and crane.state == "idle" and crane.drops_left == 3, "away from the ladder: no prompt, 3 drops")
			p.teleport(crane.ladder_foot(), 0.0)
			crane.step(DT)
			_check(crane.hint() == YardCrane.T_LADDER, "at the ladder: [E] leo lên cần cẩu")
			_check(crane.enter(p) and crane.state == "climb" and not p.controls_enabled, "[E]: the climb starts, no control")
			_step(0.6)
			_check(crane.state == "climb", "still climbing at 0.6 s")
			_step(0.65)
			_check(crane.in_cabin() and p.global_position.y > yard.global_position.y + 5.5, "after 1.2 s: in the cabin, up high (%.1f m)" % (p.global_position.y - yard.global_position.y))
			_check(crane.cam.current and crane.cam.has_meta(CameraDirector.META_FX), "the cabin camera is current and takes the director's fx")
			_check(CameraFraming.in_safe(crane.cam, crane.hook_pos(), 0.05) and CameraFraming.in_safe(crane.cam, crane.footprint_centre(), 0.05), "the cabin camera frames the hook and the footprint")
			_check(crane.hint() == YardCrane.T_CABIN, "the cabin prompt")
			var x0: float = crane.trolley_x
			var z0: float = crane.gantry_z
			crane.move_override = Vector2(1.0, 0.0)
			_step(1.0)
			_check(absf(crane.trolley_x - x0 - 2.5) < 0.1, "D: the trolley moves 2.5 m/s (%.2f)" % (crane.trolley_x - x0))
			crane.move_override = Vector2(0.0, 1.0)
			var py: Vector3 = p.global_position
			_step(0.4)
			_check(absf(crane.gantry_z - z0 - 1.0) < 0.1 and p.global_position.distance_to(crane.cabin_spot()) < 0.3 and p.global_position.distance_to(py) > 0.5, "S: the gantry rolls, the cabin and the player with it")
			crane.move_override = Vector2(-1.0, -1.0)
			_step(1.0)
			crane.move_override = Vector2(-1.0, 0.0)
			_step(0.6)
			crane.move_override = Vector2.ZERO
			crane.trolley_x = 0.0
			crane.gantry_z = 5.0
			crane._place()
			crane.step(DT)
			# B
			var slots0: int = fight.cover.count()
			var g_in: Array = [fight.gunmen[0], fight.gunmen[1]]
			var g_out: Gunman = fight.gunmen[2]
			_check(crane.footprint_has((g_in[0] as Gunman).feet()) and crane.footprint_has((g_in[1] as Gunman).feet()) and not crane.footprint_has(g_out.feet()), "the footprint covers the two under the hook only")
			_check(crane.drop(), "[E]: drop")
			_check(not crane.drop(), "one drop at a time")
			_step(0.6)
			_check(crane.drops_left == 3 and not (g_in[0] as Gunman).is_defeated(), "the rattle, then still falling at 0.6 s")
			_step(0.35)
			_check(crane.drops_left == 2 and crane.drops_done == 1, "landed after the rattle + a 0.6 s fall")
			_check((g_in[0] as Gunman).is_defeated() and (g_in[1] as Gunman).is_defeated() and not g_out.is_defeated() and crane.kos_total == 2, "the gunmen in the footprint are knocked out, the one outside is not")
			_check(crane.landed.size() == 1 and crane.landed[0].is_in_group("cover"), "the container stays on the floor as cover")
			var added: int = fight.cover.count() - slots0
			_check(added >= 6, "new cover slots round the container (%d)" % added)
			var c: Vector3 = crane.landed[0].global_position
			var near: int = fight.cover.nearest(c, 5.0, fight.taken)
			_check(near >= slots0, "the player's cover search finds a slot of the new container (%d)" % near)
			var cand: PackedInt32Array = fight.cover.candidates(c + Vector3(0.0, 0.0, -12.0), c + Vector3(0.0, 0.0, 4.0), 12.0, fight.taken, null, 2.0, GunData.GUNMAN_COVER_MAX_H)
			var new_for_g: bool = false
			for i: int in cand:
				new_for_g = new_for_g or i >= slots0
			_check(new_for_g, "the gunmen's cover search offers its slots too (low enough: %.1f m)" % YardCrane.CONT_H)
			_step(YardCrane.RELOAD_S + 0.1)
			_check(crane.hook_box != null and crane.footprint.visible, "the next container on the hook")
			crane.drop()
			_step(1.0)
			crane.step(DT)
			_step(YardCrane.RELOAD_S + 0.1)
			crane.drop()
			_step(1.0)
			_check(crane.drops_left == 0 and not crane.drop() and crane.hint() == YardCrane.T_EMPTY, "3 drops in all")
			# C
			crane.leave()
			_check(crane.state == "idle" and p.controls_enabled and not crane.cam.current and fr.get_viewport().get_camera_3d() == game_cam, "[F]: down, the gameplay camera and control back")
			# D
			crane.reset()
			_check(crane.drops_left == 3 and crane.hook_box != null, "retry: the drops back on the hook")
			_check(fight.taken.get(slots0) == crane, "retry: the gone container's slots are held (no cover in thin air)")
			# Dễ: cabin accuracy
			Difficulty.set_easy(true)
			var c2 := YardCrane.new()
			fr.add_child(c2)
			c2.setup(yard.global_transform, fight, 1)
			var acc0: float = g_out.accuracy_k
			p.teleport(c2.ladder_foot(), 0.0)
			c2.enter(p)
			for k: int in 80:
				c2.step(DT)
			_check(c2.in_cabin() and is_equal_approx(g_out.accuracy_k, acc0 * 0.55), "Dễ: the gunmen aim x0.55 at the cabin (Thường x0.75, T9)")
			c2.leave()
			_check(is_equal_approx(g_out.accuracy_k, acc0), "Dễ: their aim back after the cabin")
			Difficulty.set_easy(false)
			return _end()
	return false


func _end() -> bool:
	Difficulty.set_easy(false)
	if fails.is_empty():
		print("✅ SUCCESS: CRANE (climb, cabin camera framing, trolley / gantry, drop KOs in the footprint only, cover slots, 3 drops, leave, retry, Dễ aim)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true
