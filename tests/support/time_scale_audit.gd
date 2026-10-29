# File: res://tests/support/time_scale_audit.gd
# Wave 3 integration (plan docs/superpowers/plans/2026-10-30-w3-shared.md, Integration step 4): a time-scale audit for the
# story tests and the tuning harnesses. Added under the root, it looks at every physics frame after the other nodes
# (processing always, so a tree pause counts too):
#   orphans    frames with Engine.time_scale != 1 and no valid RadialWheel.scale_owner (a write outside the protocol, or a
#              scale left behind by an owner that let go);
#   held_max   the longest run of frames one owner kept the time scale (real seconds), and who;
#   by_class   frames owned per owner class (BulletTime, Impact, CameraDirector, SwordDuel, ...).
# report() -> String; clean(max_hold_s) -> bool: no orphan frame, no hold longer than max_hold_s, and right now the scale
# is 1 with no owner.
extends Node

var frames: int = 0
var orphans: int = 0
var orphan_first: String = ""
var held_max: float = 0.0
var held_by: String = ""
var by_class: Dictionary = {}
var _cur: Object = null
var _cur_n: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 1000          # after every gameplay node of the frame


static func name_of(o: Object) -> String:
	if o == null or not is_instance_valid(o):
		return "-"
	var sc: Script = o.get_script() as Script
	var g: String = String(sc.get_global_name()) if sc != null else ""
	return g if g != "" else o.get_class()


func _physics_process(_d: float) -> void:
	frames += 1
	var o: Object = RadialWheel.scale_owner
	var valid: bool = o != null and is_instance_valid(o)
	if not valid and not is_equal_approx(Engine.time_scale, 1.0):
		orphans += 1
		if orphan_first == "":
			orphan_first = "frame %d scale %.2f" % [frames, Engine.time_scale]
	if valid:
		var n: String = name_of(o)
		by_class[n] = int(by_class.get(n, 0)) + 1
		if o == _cur:
			_cur_n += 1
		else:
			_cur = o
			_cur_n = 1
		var s: float = float(_cur_n) / float(maxi(1, Engine.physics_ticks_per_second))
		if s > held_max:
			held_max = s
			held_by = n
	else:
		_cur = null
		_cur_n = 0


func clean(max_hold_s: float) -> bool:
	var o: Object = RadialWheel.scale_owner
	return orphans == 0 and held_max <= max_hold_s and is_equal_approx(Engine.time_scale, 1.0) and (o == null or not is_instance_valid(o))


func report() -> String:
	var parts: PackedStringArray = []
	for k: String in by_class.keys():
		parts.append("%s %.1f s" % [k, float(by_class[k]) / float(maxi(1, Engine.physics_ticks_per_second))])
	return "time-scale audit: %d frames, orphan frames %d%s, longest hold %.2f s (%s), owned {%s}, now scale %.2f owner %s" % [frames,
		orphans, (" (first " + orphan_first + ")") if orphan_first != "" else "", held_max, held_by, ", ".join(parts), Engine.time_scale,
		name_of(RadialWheel.scale_owner)]
