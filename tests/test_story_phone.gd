# File: res://tests/test_story_phone.gd
# Headless test of the story phone (spec A2-D7): threads per sender in SENDERS order with {name} substituted, the unread
# count drops when a thread is shown, evidence slots read "???" until owned, the missions tab shows day / objective / days
# left, player movement and camera input are blocked while it is open (block target controls_enabled) and restored on
# close, [Esc] and [P] close it, the game is not paused.
# Run:  godot --headless --path . --script tests/test_story_phone.gd
extends SceneTree

var fails: Array[String] = []
var frames: int = 0
var sd: Node
var phone: StoryPhone
var target: ThirdPersonController
var layer: CanvasLayer


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	print("--- TEST STORY PHONE ---")
	sd = (load("res://scripts/story/StoryDirector.gd") as Script).new()
	sd.name = "PhoneDirector"
	sd.set("nav_enabled", false)
	sd.set("save_path", "user://test_story_phone.cfg")
	root.add_child(sd)
	target = ThirdPersonController.new()
	target.capture_on_click = false
	root.add_child(target)
	layer = CanvasLayer.new()
	root.add_child(layer)
	phone = StoryPhone.new()
	phone.setup(sd, target)
	layer.add_child(phone)


func _process(_d: float) -> bool:
	frames += 1
	if frames < 2:
		return false
	_run()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_story_phone.cfg"))
	if fails.is_empty():
		print("✅ SUCCESS: STORY PHONE (threads, unread, evidence slots, missions, input block)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true


func _run() -> void:
	sd.call("new_story", {"female": true, "name": "Thảo Vy"})
	sd.call("complete_step", "d0_wake")          # Phúc's text
	sd.call("add_text", "Số lạ", "…")
	sd.call("add_text", "Mr.T", "{name} ơi, em lên phòng 311 nhé.")
	_check(int(sd.call("unread_count")) == 3, "three unread texts")
	_check(phone.thread_names() == PackedStringArray(["Mr.T", "Phúc", "Số lạ"]), "threads in SENDERS order: %s" % str(phone.thread_names()))
	_check(not phone.is_open() and not phone.visible and target.controls_enabled, "closed at start, controls on")
	phone.open()
	_check(phone.is_open() and phone.visible and not target.controls_enabled, "open blocks player input")
	_check(not paused, "the game is not paused by the phone")
	_check(phone.thread == "Mr.T" and int(sd.call("unread_count", "Mr.T")) == 0, "opens on the newest unread thread (Mr.T) and marks it read")
	_check(int(sd.call("unread_count")) == 2, "two unread left")
	var all_text: String = _texts(phone)
	_check(all_text.contains("Thảo Vy ơi, em lên phòng 311 nhé."), "Mr.T's text with {name} substituted")
	phone.select_thread("Phúc")
	_check(_texts(phone).contains("Ê!!! Thi EOS 8h đó, 7h05 rồi!!!") and int(sd.call("unread_count", "Phúc")) == 0, "Phúc's thread shown and read")
	phone.set_tab(1)
	var ev: PackedStringArray = phone.evidence_texts()
	_check(ev.size() == 7 and ev[0] == "E1 · ???" and ev[6] == "E7 · ???", "all evidence slots locked: %s" % str(ev))
	sd.call("add_evidence", "E1")
	phone.refresh()
	ev = phone.evidence_texts()
	_check(ev[0] == "E1 · " + StoryMissions.evidence_name("E1") and ev[1] == "E2 · ???", "E1 unlocked, E2 still ???")
	_check(_texts(phone).contains("🔒 E2 · ???") and _texts(phone).contains("📎 E1"), "evidence tab lists locked and owned slots")
	phone.set_tab(2)
	var mt: String = _texts(phone)
	_check(mt.contains("NGÀY 0 · THI EOS") and mt.contains(String(sd.get("objective"))), "missions tab: day chip + objective")
	sd.call("advance_day", 1)
	phone.refresh()
	_check(_texts(phone).contains("Còn 7 ngày"), "missions tab shows the days left on Day 1")
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	phone._input(esc)
	_check(not phone.is_open() and target.controls_enabled, "Esc closes and restores input")
	phone.open()
	var pk := InputEventKey.new()
	pk.physical_keycode = KEY_P
	pk.pressed = true
	phone._input(pk)
	_check(not phone.is_open() and target.controls_enabled, "P closes")
	target.controls_enabled = false
	phone.open()
	phone.close()
	_check(not target.controls_enabled, "close restores the previous input state (it was off)")
	target.controls_enabled = true


func _texts(n: Node) -> String:
	var out: PackedStringArray = []
	for l: Node in n.find_children("*", "Label", true, false):
		if not l.is_queued_for_deletion():
			out.append((l as Label).text)
	for b: Node in n.find_children("*", "Button", true, false):
		if not b.is_queued_for_deletion():
			out.append((b as Button).text)
	return "\n".join(out)
