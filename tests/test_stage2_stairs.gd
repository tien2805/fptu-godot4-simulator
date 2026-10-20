# File: res://tests/test_stage2_stairs.gd
# Test headless cho Pha 2 Màn 2 (auto-runner theo Path3D):
#   - Khởi tạo scene, nhảy thẳng vào pha 2.
#   - Một "bot" đơn giản né chướng ngại (đổi làn / nhảy / trượt) giống người chơi trung bình.
#   - Runner phải chạy hết tuyến và màn phải kết thúc THẮNG; không có lỗi script trong quá trình.
# Chạy:  godot --headless --path . --script tests/test_stage2_stairs.gd
extends SceneTree

var stage: Node3D
var frames: int = 0
var started: bool = false
const MAX_FRAMES: int = 60 * 70

func _initialize() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	var packed: PackedScene = load("res://scenes/Stage2_Parking.tscn")
	stage = packed.instantiate()
	root.add_child(stage)
	Engine.time_scale = 6.0
	print("--- TEST MÀN 2 PHA 2: AUTO-RUNNER THEO PATH3D (BOT NÉ CHƯỚNG NGẠI) ---")
	stage.call_deferred("_scan_student_card")
	stage.call_deferred("_start_phase_2_stairs_climb")
	started = true

func _bot_dodge() -> void:
	var progress: float = stage.get("run_progress")
	var lane: int = stage.get("lane")
	var obstacles: Array = stage.get("obstacles")
	var nearest: Dictionary = {}
	var nearest_dp: float = 999.0
	for ob: Dictionary in obstacles:
		if ob["hit"]:
			continue
		var dp: float = float(ob["progress"]) - progress
		if dp > 0.2 and dp < 4.5 and dp < nearest_dp:
			nearest_dp = dp
			nearest = ob
	if nearest.is_empty():
		return
	var lanes: Array = nearest["lanes"]
	if not (lane in lanes):
		return
	if nearest["low"] and nearest_dp < 2.2:
		if float(stage.get("jump_t")) < 0.0 and float(stage.get("slide_t")) < 0.0:
			stage.set("jump_t", 0.0)
	elif nearest["high"] and nearest_dp < 1.8:
		if float(stage.get("slide_t")) < 0.0 and float(stage.get("jump_t")) < 0.0:
			stage.set("slide_t", 0.0)
	elif lanes.size() < 3:
		for cand: int in [lane - 1, lane + 1, lane - 2, lane + 2]:
			if cand >= -1 and cand <= 1 and not (cand in lanes):
				stage.set("lane", cand)
				break

func _process(_delta: float) -> bool:
	if not started or stage == null:
		return false
	frames += 1
	if frames == 5:
		print("  run_length = %.1f m, obstacles = %d, runner at %s" % [stage.get("run_length"), (stage.get("obstacles") as Array).size(), str(stage.get("runner_body").global_position)])
	if frames > 5:
		_bot_dodge()
	if frames % 300 == 0:
		print("  frame %d: progress %.1f / %.1f, stumbles %d, dodges %d, time_left %.1f" % [frames, stage.get("run_progress"), stage.get("run_length"), stage.get("stumbles"), stage.get("dodges"), stage.get("time_left")])
	if stage.get("is_stage_ended"):
		var won: bool = stage.get("has_won")
		print("  Kết thúc sau %d frame: has_won=%s, progress=%.1f, stumbles=%d, dodges=%d, time_left=%.1f" % [frames, str(won), stage.get("run_progress"), stage.get("stumbles"), stage.get("dodges"), stage.get("time_left")])
		if won:
			print("✅ SUCCESS: BOT REACHED LAB 402 – PATH RUNNER HAS NO PHYSICS STALLS")
			quit(0)
		else:
			print("❌ FAILED: stage ended without win")
			quit(1)
		return true
	if frames >= MAX_FRAMES:
		print("❌ FAILED: timeout, progress=%.1f" % stage.get("run_progress"))
		quit(1)
		return true
	return false
