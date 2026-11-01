# File: res://scripts/story/missions/MissionTowerTyping.gd
# Day 7, the typing showdown "Học thật, đậu thật" (plan 2026-11-01-w4-day7.md T1): at the exam-system rack in the
# penthouse, Anh Duy opens a door into the exam system and the player wipes "Lọ Thần 10.0" before 08:00. StoryHack (the
# Stage 6 typing engine's story mode) with the Day 7 pools (WORDS), the final command FINAL_COMMAND and the tool's name;
# the 08:00 clock (Day7Clock, ticked by StoryTower on this mission's clock) is the only timer. Leaks = "TOANG!" (the exam
# answers went out); THỬ LẠI = a fresh run at the desk. The win: done {"kills", "leaks", "max_combo"}; its next beat
# (d7_ending) belongs to the endings.
# opts: "points" (spot, spot_yaw), "manual" also steps StoryHack (tests: hack.manual), "seed".
class_name MissionTowerTyping
extends StoryMission

const TOOL_NAME: String = "Lọ Thần 10.0"
const FINAL_COMMAND: String = "sudo rm -rf lothan10"
const WORDS: Array = [
	["aibot", "cheat", "proxy", "relay", "dumps", "keylog", "ghost", "token"],
	["autosolve", "earpiece", "lothan10", "backdoor", "copypaste", "injector", "webcamfx", "sniffer"],
	["answerbank", "deepfake", "remotedesk", "screenshare", "voicegpt", "mirrorexam", "keystrokes", "proctorbypass"],
]
## Integrity to wipe (x StoryHack.MAX_HP) and the pace (Thường / Dễ): provisional until the T5 sloppy-bot tuning.
const LOAD: float = 1.2
const LOAD_EASY: float = 1.0
const PACE: float = 0.7
const PACE_EASY: float = 0.56
const T_LEAKED: String = "Lọ Thần 10.0 kịp gửi đề ra ngoài!"
const T_WIPED: String = "Lọ Thần 10.0 đã bị xóa sạch!"

var pts: Dictionary = {}
var hack: StoryHack


func setup(r: Node3D, b: Dictionary, o: Dictionary = {}) -> void:
	super.setup(r, b, o)
	pts = opts.get("points", {})


func _start() -> void:
	hide_top_panel()
	hack = StoryHack.new()
	hack.words = WORDS
	hack.final_command = FINAL_COMMAND
	hack.tool_name = TOOL_NAME
	add_child(hack)
	hack.manual = manual
	hack.won.connect(_on_won)
	hack.lost.connect(_on_lost)
	failed.connect(_on_failed)
	_fresh_run()


func _fresh_run() -> void:
	if pts.has("spot"):
		teleport_player(pts["spot"], float(pts.get("spot_yaw", 0.0)))
	if player:
		player.controls_enabled = false
	hack.hp_max = StoryHack.MAX_HP * float(Difficulty.pick(LOAD, LOAD_EASY))
	hack.pace = float(Difficulty.pick(PACE, PACE_EASY))
	hack.start(int(opts.get("seed", 7)) + retries)


func _tick(dt: float) -> void:
	if manual and hack and hack.active:
		hack.step(dt)


func _on_won() -> void:
	popup(T_WIPED, 2.0)
	play_cue("success_fanfare", -8.0)
	finish({"kills": hack.kills, "leaks": hack.leaks, "max_combo": hack.max_combo})


func _on_lost() -> void:
	fail(T_LEAKED)


## Any fail (the leaks, or 08:00 from the tower's clock): the terminal stops under the card.
func _on_failed(_title: String, _reason: String) -> void:
	if hack and hack.active:
		hack.paused = true


func _reset() -> void:
	_fresh_run()


func _cleanup() -> void:
	if hack and is_instance_valid(hack):
		hack.stop()
