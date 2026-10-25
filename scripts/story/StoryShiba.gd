# File: res://scripts/story/StoryShiba.gd
# "Lu", Chú Bảy's shiba (spec B-D9): a low-poly dog built from boxes and spheres in code (no model, no texture). Feet on
# y = 0, facing -Z like the game characters, about 0.42 m at the shoulder and 0.62 m long.
# Motions (pose(motion, t) is a pure function of the motion time t, so cinematics can seek):
#   idle  breathing, tail wag, a little head tilt (loops)
#   walk  diagonal-pair trot (period WALK_PERIOD), body bob, tail up (loops; the caller moves the node)
#   bonk  head-butt: rears back, lunges forward with the head down at BONK_HIT, recovers by BONK_DUR (one-shot, then holds)
# Gameplay: play("walk") and the node animates itself in _process (PROCESS_MODE_PAUSABLE). Cinematics: the CineFX prop kind
# "shiba" builds one and CinePlayer calls cine_eval(s, opts) every frame with opts "anim": [[story s, motion], ...].
class_name StoryShiba
extends Node3D

const BONK_HIT: float = 0.32
const BONK_DUR: float = 0.75
const BONK_REACH: float = 0.24          # how far the head lunges forward (m) at the hit
const WALK_PERIOD: float = 0.42
const COL_FUR := Color("#D9883E")
const COL_CREAM := Color("#F6E7CC")
const COL_DARK := Color("#2A1E18")

var motion: String = "idle"
var t: float = 0.0
var body: Node3D
var head: Node3D
var tail: Node3D
var legs: Array[Node3D] = []            # front-left, front-right, back-left, back-right
var _base_head: Vector3


func _init() -> void:
	_build()
	pose("idle", 0.0)


func _build() -> void:
	var fur: StandardMaterial3D = CineFX._mat(COL_FUR, 0.9)
	var cream: StandardMaterial3D = CineFX._mat(COL_CREAM, 0.9)
	var dark: StandardMaterial3D = CineFX._mat(COL_DARK, 0.5)
	body = Node3D.new()
	body.name = "Body"
	body.position = Vector3(0.0, 0.3, 0.0)
	add_child(body)
	CineFX._box(body, "Torso", Vector3(0.24, 0.2, 0.46), Vector3.ZERO, fur)
	CineFX._box(body, "Belly", Vector3(0.2, 0.06, 0.38), Vector3(0.0, -0.09, 0.0), cream)
	CineFX._box(body, "Chest", Vector3(0.16, 0.14, 0.06), Vector3(0.0, -0.02, -0.24), cream)
	head = Node3D.new()
	head.name = "Head"
	_base_head = Vector3(0.0, 0.14, -0.27)
	head.position = _base_head
	body.add_child(head)
	CineFX._box(head, "Skull", Vector3(0.2, 0.17, 0.18), Vector3.ZERO, fur)
	CineFX._box(head, "Cheeks", Vector3(0.21, 0.07, 0.12), Vector3(0.0, -0.06, -0.03), cream)
	CineFX._box(head, "Snout", Vector3(0.1, 0.08, 0.11), Vector3(0.0, -0.035, -0.13), cream)
	CineFX._box(head, "Nose", Vector3(0.045, 0.035, 0.03), Vector3(0.0, -0.01, -0.19), dark)
	for sx: float in [-0.05, 0.05]:
		CineFX._box(head, "Eye", Vector3(0.025, 0.025, 0.012), Vector3(sx, 0.025, -0.092), dark)
		var ear: MeshInstance3D = CineFX._box(head, "Ear", Vector3(0.06, 0.08, 0.03), Vector3(sx * 1.4, 0.115, 0.01), fur,
			Vector3(0.0, 0.0, -signf(sx) * 0.25))
		ear.scale = Vector3(1.0, 1.0, 1.0)
		CineFX._box(ear, "Inner", Vector3(0.03, 0.05, 0.01), Vector3(0.0, -0.005, -0.016), cream)
	tail = Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0.0, 0.08, 0.22)
	body.add_child(tail)
	CineFX._box(tail, "Base", Vector3(0.07, 0.14, 0.07), Vector3(0.0, 0.07, 0.02), fur, Vector3(-0.5, 0.0, 0.0))
	CineFX._sphere(tail, "Curl", 0.06, Vector3(0.0, 0.15, -0.04), cream)
	var spots: Array[Vector3] = [Vector3(-0.08, -0.08, -0.17), Vector3(0.08, -0.08, -0.17), Vector3(-0.08, -0.08, 0.17), Vector3(0.08, -0.08, 0.17)]
	for i: int in spots.size():
		var leg := Node3D.new()
		leg.name = "Leg%d" % i
		leg.position = spots[i]
		body.add_child(leg)
		CineFX._box(leg, "Upper", Vector3(0.065, 0.16, 0.07), Vector3(0.0, -0.07, 0.0), fur)
		CineFX._box(leg, "Paw", Vector3(0.07, 0.05, 0.085), Vector3(0.0, -0.195, -0.008), cream)
		legs.append(leg)


## Pose at motion time tt (pure: the same motion and time always give the same pose).
func pose(m: String, tt: float) -> void:
	var tw: float = 0.0               # tail wag
	var bob: float = 0.0
	var lean: float = 0.0             # body pitch (+ = nose up)
	var fwd: float = 0.0              # body forward offset (m, along -Z)
	var head_pitch: float = 0.0       # + = nose up
	var swing: float = 0.0
	match m:
		"walk":
			var ph: float = tt / WALK_PERIOD * TAU
			swing = 0.55 * sin(ph)
			bob = 0.015 * absf(sin(ph))
			tw = 0.25 * sin(ph * 0.5)
			head_pitch = 0.05 * sin(ph)
		"bonk":
			var u: float = clampf(tt, 0.0, BONK_DUR)
			var rear: float = sin(clampf(u / (BONK_HIT * 0.6), 0.0, 1.0) * PI * 0.5) * (1.0 - _sm((u - BONK_HIT * 0.6) / (BONK_HIT * 0.4)))
			var lunge: float = _sm((u - BONK_HIT * 0.6) / (BONK_HIT * 0.4)) * (1.0 - _sm((u - BONK_HIT) / (BONK_DUR - BONK_HIT)))
			lean = 0.3 * rear - 0.18 * lunge
			fwd = -0.06 * rear + BONK_REACH * lunge
			head_pitch = 0.35 * rear - 0.55 * lunge
			bob = 0.04 * rear
			tw = 0.6 * sin(u * 30.0) * (1.0 - lunge)
		_:   # idle
			bob = 0.008 * sin(tt * TAU * 0.6)
			tw = 0.45 * sin(tt * 9.0)
			head_pitch = 0.06 * sin(tt * 1.3)
	body.position = Vector3(0.0, 0.3 + bob, -fwd)
	body.rotation = Vector3(lean, 0.0, 0.0)
	head.position = _base_head
	head.rotation = Vector3(head_pitch, 0.0, 0.08 * sin(tt * 1.7) if m == "idle" else 0.0)
	tail.rotation = Vector3(0.0, 0.0, tw)
	for i: int in legs.size():
		var diag: float = 1.0 if i == 0 or i == 3 else -1.0
		legs[i].rotation = Vector3(swing * diag, 0.0, 0.0)


## World-space point of the nose tip (bonk contact checks).
func nose_world() -> Vector3:
	var n: Node3D = head.find_child("Nose", false, false) as Node3D
	return n.global_position if n else head.global_position


func play(m: String) -> void:
	if m != motion:
		motion = m
		t = 0.0


func _process(delta: float) -> void:
	t += delta
	pose(motion, t)


## Timeline hook (CinePlayer): opts "anim" = [[story s, motion], ...] sorted; idle before the first key.
func cine_eval(s: float, opts: Dictionary) -> void:
	set_process(false)
	var m: String = "idle"
	var s0: float = 0.0
	for k: Variant in opts.get("anim", []):
		var a: Array = k
		if float(a[0]) <= s:
			m = String(a[1])
			s0 = float(a[0])
	pose(m, s - s0)


static func _sm(u: float) -> float:
	var x: float = clampf(u, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
