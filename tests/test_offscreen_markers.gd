# File: res://tests/test_offscreen_markers.gd
# T10 (plan 2026-10-30-w3-day3.md): OffscreenMarkers, the readability helper of the yard missions, on a bare scene (a
# camera at the origin looking down -z, a player node, a few targets):
#   A a goal in front of the camera: an on-screen diamond with its label and metres; the same goal behind the camera or
#     far to the side: an edge arrow on the screen border pointing its way;
#   B threats from threat_source: only the alerted ones; on screen only while at most chevrons_at are left (chevrons),
#     off screen always (edge arrows);
#   C set_on / untrack / a freed node; no emoji in any label; the layer hides with its HUD.
# Run:  godot --headless --path . --script tests/test_offscreen_markers.gd
extends SceneTree

class FakeGuard extends Node3D:
	var is_alerted: bool = false

var fails: Array[String] = []
var frames: int = 0
var phase: int = 0
var world: Node3D
var cam: Camera3D
var hud: CanvasLayer
var me: Node3D
var mk: OffscreenMarkers
var goal: Node3D
var guards: Array[FakeGuard] = []


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	print("--- TEST OFFSCREEN MARKERS ---")
	Engine.max_fps = 60
	world = Node3D.new()
	root.add_child(world)
	cam = Camera3D.new()
	world.add_child(cam)
	cam.current = true
	me = Node3D.new()
	world.add_child(me)
	goal = Node3D.new()
	world.add_child(goal)
	goal.position = Vector3(0.0, 0.0, -10.0)
	for k: int in 3:
		var g := FakeGuard.new()
		world.add_child(g)
		g.position = Vector3(float(k) * 2.0 - 2.0, 0.0, -12.0)
		guards.append(g)
	hud = CanvasLayer.new()
	root.add_child(hud)
	mk = OffscreenMarkers.make(hud, me)


func _guards() -> Array:
	var out: Array = []
	for g: FakeGuard in guards:
		if is_instance_valid(g):
			out.append(g)
	return out


func _process(_d: float) -> bool:
	frames += 1
	match phase:
		0:
			if frames < 3:
				return false
			# A: the goal in front
			mk.track(goal, "goal", "Container", 1.4)
			phase = 1
			frames = 0
		1:
			if frames < 2:
				return false
			_check(mk.onscreen_count == 1 and mk.edge_count == 0 and mk.shown_labels() == ["Container 10 m"], "A: a goal in front: one diamond, 'Container 10 m' (%s)" % str(mk.shown_labels()))
			goal.global_position = Vector3(0.0, 0.0, 10.0)   # behind the camera
			phase = 2
			frames = 0
		2:
			if frames < 2:
				return false
			_check(mk.edge_count == 1 and mk.onscreen_count == 0, "A: behind the camera: an edge arrow")
			var vs: Vector2 = mk.get_viewport().get_visible_rect().size
			var p: Vector2 = mk._pos[0]
			_check(p.y > vs.y * 0.5 and (p.x <= OffscreenMarkers.EDGE_INSET + 1.0 or p.y >= vs.y - OffscreenMarkers.EDGE_INSET - 1.0 or p.x >= vs.x - OffscreenMarkers.EDGE_INSET - 1.0), "A: the arrow sits on the border, toward the bottom (%s)" % str(p))
			goal.global_position = Vector3(60.0, 0.0, -10.0)  # far right, off screen
			phase = 3
			frames = 0
		3:
			if frames < 2:
				return false
			var vs3: Vector2 = mk.get_viewport().get_visible_rect().size
			_check(mk.edge_count == 1 and mk._dir[0].x > 0.5 and mk._pos[0].x >= vs3.x - OffscreenMarkers.EDGE_INSET - 1.0, "A: off to the right: the arrow on the right border, pointing right")
			goal.global_position = Vector3(0.0, 0.0, -10.0)
			# B: threats from a source, only the alerted ones
			mk.threat_source = _guards
			guards[0].is_alerted = true
			phase = 4
			frames = 0
		4:
			if frames < 20:
				return false
			_check(mk.chevron_count == 1, "B: one alerted guard in front (of 3): one chevron, the calm ones unmarked (%d)" % mk.chevron_count)
			guards[1].is_alerted = true
			guards[2].is_alerted = true
			phase = 5
			frames = 0
		5:
			if frames < 20:
				return false
			_check(mk.chevron_count == 0, "B: three on screen (more than chevrons_at): no chevrons over them")
			guards[2].global_position = Vector3(0.0, 0.0, 15.0)   # one behind the camera
			phase = 6
			frames = 0
		6:
			if frames < 20:
				return false
			_check(mk.edge_count >= 1 and mk.chevron_count == 0, "B: the one behind gets an edge arrow even with 3 left")
			guards[0].queue_free()
			guards[1].queue_free()
			phase = 7
			frames = 0
		7:
			if frames < 20:
				return false
			_check(mk.edge_count == 1, "B: freed guards drop out (the last one still marked)")
			# C: set_on / untrack / hidden HUD
			mk.set_on(goal, false)
			phase = 8
			frames = 0
		8:
			if frames < 2:
				return false
			_check(mk.onscreen_count == 0 and mk.is_tracked(goal) and not mk.is_on(goal), "C: set_on(false) hides the goal, still tracked")
			mk.set_on(goal, true)
			mk.untrack(goal)
			_check(not mk.is_tracked(goal), "C: untrack")
			for t: String in mk.shown_labels():
				for ch: String in t:
					_check(ch.unicode_at(0) < 0x2190 or (ch.unicode_at(0) >= 0x1E00 and ch.unicode_at(0) <= 0x1EFF), "C: plain text labels, no symbols (%s)" % t)
			hud.visible = false
			phase = 9
			frames = 0
		9:
			if frames < 2:
				return false
			_check(mk.edge_count == 0 and mk.onscreen_count == 0, "C: nothing drawn while the HUD is hidden")
			return _end()
	return false


func _end() -> bool:
	if fails.is_empty():
		print("✅ SUCCESS: OFFSCREEN MARKERS (goal diamond / edge arrows, alerted threats, chevrons for the last ones, set_on / untrack, hidden HUD)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true
