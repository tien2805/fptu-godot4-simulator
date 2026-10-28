# File: res://tests/test_story_stages.gd
# Headless test of the story missions inside stages (spec A2-D10, A2-D11): with StageManager.story_context naming the
# Extra stage, the protagonist model replaces the proctor (badge "{name} · GIÁM THỊ PHỤ"), Mr.T (role mr_t, lecturer)
# stands at the front desk, a replay recorder tracks the protagonist and the six cheaters; the fifth confiscation marks the
# blow, plays the seg_d0_exam replay (the game pauses), then reports: StoryDirector completes d0_exam (E1, next beat,
# autosave), the card gets "QUA MÔN! Uy tín +" and the story buttons replace the stage's own; a fail gets "TOANG!" with
# THỬ LẠI (same context) + VỀ THẾ GIỚI MỞ. Outside the story the Extra stage is unchanged, and the Stage 1 bike rider is the
# protagonist only in the story.
# Run:  godot --headless --path . --script tests/test_story_stages.gd
extends SceneTree

var TMP: String = "user://test_story_stages_%d.cfg" % OS.get_process_id()
var fails: Array[String] = []
var frames: int = 0
var phase: int = 0
var sd: Node
var sm: Node
var stage: Node
var t0: int = 0
var paused_seen: bool = false


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	print("--- TEST STORY STAGES ---")
	Engine.max_fps = 60
	sd = root.get_node("StoryDirector")
	sm = root.get_node("StageManager")
	sd.set("save_path", TMP)
	sd.set("nav_enabled", false)


func _story_on() -> void:
	sd.call("new_story", {"female": true, "name": "Bảo Ngọc", "skin": 3, "hair_style": "long", "variant": 2, "hair_color": 2})
	sd.call("complete_step", "d0_wake")
	sd.call("complete_step", "d0_race")
	sd.call("launch_stage_beat", "d0_exam", Transform3D(Basis.IDENTITY, Vector3(1, 0, 2)), Transform3D(Basis.IDENTITY, Vector3(3, 0, 4)))


func _load_extra() -> Node:
	var n: Node = (load("res://scenes/StageExtra_EOSExam.tscn") as PackedScene).instantiate()
	root.add_child(n)
	current_scene = n
	return n


func _process(_d: float) -> bool:
	frames += 1
	match phase:
		0:
			_story_on()
			_check(String((sm.get("story_context") as Dictionary).get("beat", "")) == "d0_exam" and String(sd.get("last_nav")) == "stage:7", "launch sets the context and asks for the Extra stage")
			stage = _load_extra()
			phase = 1
			frames = 0
		1:
			if frames < 3:
				return false
			var pm: Node3D = stage.get("proctor_model")
			_check(bool(stage.get("story")) and pm != null and bool(pm.get_meta("female", false)) and int(pm.get_meta("skin_idx", -1)) == 3 and String(pm.get_meta("preset", "")) == "player",
				"the protagonist replaces the proctor model")
			var badge_ok: bool = false
			for l: Node in (stage.get("proctor") as Node).find_children("*", "Label3D", true, false):
				if (l as Label3D).text == "Bảo Ngọc · GIÁM THỊ PHỤ":
					badge_ok = true
			_check(badge_ok, "badge {name} · GIÁM THỊ PHỤ")
			var mt: Node3D = stage.get("mr_t")
			_check(mt != null and String(mt.get_meta("role", "")) == "mr_t" and String(mt.get_meta("preset", "")) == "lecturer", "Mr.T NPC at the front desk")
			var rec: CineReplayRecorder = stage.get("story_rec")
			_check(rec != null and rec.tracked().size() == 7, "recorder tracks the protagonist + 6 cheaters (%d)" % (rec.tracked().size() if rec else -1))
			phase = 2
			frames = 0
		2:
			if frames < 40:
				return false   # some footage
			var n: int = 0
			var stations: Array = stage.get("stations")
			for i: int in stations.size():
				if bool(stations[i]["is_cheater"]) and n < 5:
					stage.call("_book", i, false)
					n += 1
			_check(bool(stage.get("story_finishing")) and not bool(stage.get("is_stage_ended")), "the final catch starts the story finish (replay first)")
			t0 = Time.get_ticks_msec()
			phase = 3
		3:
			if paused:
				paused_seen = true
			if not bool(stage.get("is_stage_ended")):
				if Time.get_ticks_msec() - t0 > 15000:
					_check(false, "the replay never ended")
					return _end()
				return false
			_check(paused_seen, "the replay paused the game")
			_check(sd.call("has_evidence", "E1") and String(sd.get("step")) == "d0_exam_end", "win completes d0_exam: E1, next beat")
			_check(sd.get("spawn") is Transform3D and (sd.get("spawn") as Transform3D).origin.is_equal_approx(Vector3(1, 0, 2)), "return spot = win spot")
			_check(FileAccess.file_exists(TMP), "autosave after the mission win")
			var layer: CanvasLayer = sd.get("result_layer")
			var btns: Dictionary = sd.get("result_buttons")
			_check(layer != null and layer.visible and (btns["continue"] as Button).visible and not (btns["retry"] as Button).visible, "story card: TIẾP TỤC CỐT TRUYỆN")
			_check((sd.get("result_title") as Label).text == "QUA MÔN! Uy tín +", "story win title")
			var r: Dictionary = (sm.get("run_stats") as Dictionary).get(7, {})
			_check(String(r.get("story", "")) == "win" and String(sm.call("result_banner_title", r)) == "QUA MÔN! Uy tín +", "banner title QUA MÔN! Uy tín +")
			phase = 4
			frames = 0
		4:
			if frames < 2:
				return false
			for b: String in ["replay_btn", "menu_btn", "retry_btn"]:
				_check(not (stage.get(b) as Button).visible, "stage button %s replaced by the story buttons" % b)
			_check(not (sm.get("roam_return_layer") as CanvasLayer).visible, "no plain VỀ CAMPUS button in the story")
			(sd.get("result_buttons")["continue"] as Button).emit_signal("pressed")
			_check(String(sd.get("last_nav")) == "roam" and (sm.get("story_context") as Dictionary).is_empty() and not (sd.get("result_layer") as CanvasLayer).visible, "continue -> story free roam, context cleared")
			_fail_path()
			stage.queue_free()
			phase = 5
			frames = 0
		5:
			if frames < 2:
				return false
			sd.call("reset_state")
			sm.set("story_context", {})
			stage = _load_extra()
			phase = 6
			frames = 0
		6:
			if frames < 3:
				return false
			var pm2: Node3D = stage.get("proctor_model")
			_check(not bool(stage.get("story")) and String(pm2.get_meta("preset", "")) == "proctor" and stage.get("mr_t") == null and stage.get("story_rec") == null, "outside the story the Extra stage is unchanged")
			stage.queue_free()
			_bike()
			# Stage 1 in the story: recorder on bike + rider, the finish plays seg_d0_race before the result
			sd.call("new_story", {"female": false, "name": "Tài"})
			sd.call("complete_step", "d0_wake")
			sd.call("launch_stage_beat", "d0_race", null, null)
			stage = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
			root.add_child(stage)
			current_scene = stage
			phase = 7
			frames = 0
		7:
			if frames < 60:
				return false
			var hud: Node = stage.get_node("HUD")
			var rec1: CineReplayRecorder = hud.get("story_rec")
			_check(rec1 != null and rec1.tracked().size() == 2, "Stage 1 story recorder tracks the bike and the rider")
			paused_seen = false
			hud.call("_on_destination_reached")
			t0 = Time.get_ticks_msec()
			phase = 8
		8:
			if paused:
				paused_seen = true
			var hud2: Node = stage.get_node("HUD")
			if String(sd.get("step")) == "d0_race":
				if Time.get_ticks_msec() - t0 > 15000:
					_check(false, "Stage 1 replay never ended")
					return _end()
				return false
			_check(paused_seen and hud2.get("story_replay") == null, "the finish played the replay (game paused) before the result")
			_check(String(sd.get("step")) == "d0_exam" and (sd.get("result_layer") as CanvasLayer).visible, "race win reported after the replay: d0_exam + story card")
			stage.queue_free()
			return _end()
	return false


func _fail_path() -> void:
	# a fail while the context is set: TOANG!, THỬ LẠI keeps the context, VỀ THẾ GIỚI MỞ goes back beside the marker
	sd.call("reset_state")
	_story_on()
	var res: Dictionary = {"result": "fail", "score": 0, "rank": "C", "detail": "test"}
	sm.call("report_stage_result", 7, res)
	_check(String(res.get("story", "")) == "fail" and (sd.get("result_title") as Label).text == "TOANG!" and String(sm.call("result_banner_title", res)) == "TOANG!", "fail: TOANG!")
	var btns: Dictionary = sd.get("result_buttons")
	_check((btns["retry"] as Button).visible and (btns["roam"] as Button).visible and not (btns["continue"] as Button).visible, "fail: THỬ LẠI + VỀ THẾ GIỚI MỞ")
	_check(String(sd.get("step")) == "d0_exam" and not sd.call("has_evidence", "E1"), "fail keeps the beat")
	(btns["retry"] as Button).emit_signal("pressed")
	_check(String(sd.get("last_nav")) == "retry:7" and String((sm.get("story_context") as Dictionary).get("beat", "")) == "d0_exam", "THỬ LẠI: same stage, same context")
	sm.call("report_stage_result", 7, {"result": "fail", "score": 0, "rank": "C", "detail": "test"})
	(btns["roam"] as Button).emit_signal("pressed")
	_check(String(sd.get("last_nav")) == "roam" and (sd.get("spawn") as Transform3D).origin.is_equal_approx(Vector3(3, 0, 4)), "VỀ THẾ GIỚI MỞ: back beside the marker")
	_check(sm.get("roam_spawn") is Transform3D, "roam spawn set for the return")


func _bike() -> void:
	var ps: PackedScene = load("res://scenes/PlayerBike.tscn")
	var b0: Node = ps.instantiate()
	root.add_child(b0)
	var r0: Node3D = b0.get("rider_node")
	var default_female: bool = bool(r0.get_meta("female", false))
	b0.queue_free()
	sd.call("new_story", {"female": not default_female, "name": "X", "skin": 0})
	var b1: Node = ps.instantiate()
	root.add_child(b1)
	var r1: Node3D = b1.get("rider_node")
	_check(bool(r1.get_meta("female", false)) == (not default_female) and int(r1.get_meta("skin_idx", -1)) == 0 and String(r1.get_meta("preset", "")) == "rider",
		"Stage 1 rider = the protagonist (sex, skin, helmet preset) in the story")
	b1.queue_free()
	sd.call("reset_state")


func _end() -> bool:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	sm.set("story_context", {})
	sd.call("hide_result")
	if fails.is_empty():
		print("✅ SUCCESS: STORY STAGES (Extra in story: protagonist, Mr.T, replay, story card; fail/retry; unchanged outside; Stage 1 rider + finish replay)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true
