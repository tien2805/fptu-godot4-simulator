# File: res://scripts/TypingCore.gd
# The rules of the Stage 6 typing engine (Màn 6 "Capstone 23:59"), shared by the stage and its Phase C story mode StoryHack
# (spec C-D8 beat 6: the error words become Lọ Thần's processes). A "bullet" is a Dictionary {"word", "lane", "y" (0 top ..
# 1 bottom), "dead"}; typing locks the lowest live bullet whose word starts with what was typed, a full word destroys it.
#   find_prefix(pool, prefix, alive)  the lowest live bullet (largest y) whose word starts with prefix (lower case), {} if none
#   mult(combo)                       damage multiplier: x1, x2 from combo 6, x3 from combo 12
#   damage(word, by_typing, m)        word length x 6 x multiplier when typed (x 4, no multiplier, otherwise)
class_name TypingCore
extends RefCounted


static func find_prefix(pool: Array, prefix: String, alive: Callable) -> Dictionary:
	var best: Dictionary = {}
	var best_y: float = -1.0
	for v: Variant in pool:
		var b: Dictionary = v
		if not bool(alive.call(b)):
			continue
		if str(b["word"]).to_lower().begins_with(prefix) and float(b["y"]) > best_y:
			best_y = float(b["y"])
			best = b
	return best


static func mult(combo: int) -> int:
	return 1 + mini(combo / 6, 2)


static func damage(word: String, by_typing: bool, m: int) -> int:
	return word.length() * (6 if by_typing else 4) * (m if by_typing else 1)
