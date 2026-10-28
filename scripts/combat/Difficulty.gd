# File: res://scripts/combat/Difficulty.gd
# Q6 difficulty (master plan 2026-10-29-quality-overhaul-and-phase-d-plan.md): "Thường" (default, hard) or "Dễ".
# GameFX loads / saves it (gameplay/difficulty = "normal" | "easy") and calls set_easy(); every system reads its numbers
# through pick() so the easy values live next to the normal ones:
#   var dmg: float = Difficulty.pick(22.0, 14.0)          # normal, easy
#   var attackers: int = int(Difficulty.pick(3, 2))
# Tests set Difficulty.set_easy(...) directly and restore it; they never touch the owner's settings file.
class_name Difficulty
extends RefCounted

static var easy: bool = false


static func set_easy(on: bool) -> void:
	easy = on


## The value for the current difficulty: `normal` on Thường, `easy_value` on Dễ.
static func pick(normal: Variant, easy_value: Variant) -> Variant:
	return easy_value if easy else normal


static func id() -> String:
	return "easy" if easy else "normal"
