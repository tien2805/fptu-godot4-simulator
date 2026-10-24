# File: res://scripts/weapons/SonicCone.gd
# Loa kẹo kéo blast (spec section 3, W-D5): while the fire button is held, every TICK_S everyone inside the 10 m / 60° cone in
# front of the player is pushed away (PUSH m/s; some dance on the spot, then flee) and a pink ring shoots out; the music is
# WeaponAudio.loa_stream() (the owner's local loa_keo_keo file, else the synthesized bolero) on a looping AudioStreamPlayer;
# +1 heat every HEAT_EVERY_S of blasting. Created and stopped by WeaponDirector._tick_held.
class_name SonicCone
extends Node3D

const TICK_S: float = 0.2
const PUSH: float = 5.0
const HEAT_EVERY_S: float = 2.0

var director: WeaponDirector
var held_t: float = 0.0
var music: AudioStreamPlayer
var _acc: float = 0.0
var _heat_acc: float = 0.0


func setup(d: WeaponDirector) -> void:
	director = d
	music = AudioStreamPlayer.new()
	music.name = "LoaMusic"
	music.stream = WeaponAudio.loa_stream()
	music.bus = WeaponAudio.bus()
	music.volume_db = -2.0
	add_child(music)
	music.play()


## One physics step of blasting from apex along dir.
func tick(delta: float, apex: Vector3, dir: Vector3) -> void:
	held_t += delta
	_acc += delta
	_heat_acc += delta
	if _heat_acc >= HEAT_EVERY_S:
		_heat_acc -= HEAT_EVERY_S
		director._heat(WeaponData.HEAT_LOA_PER_2S, apex, "loa")
	if _acc < TICK_S:
		return
	_acc = 0.0
	var w: Dictionary = WeaponData.SLOTS[WeaponData.Slot.LOA]
	director.fx.sonic_ring(apex, dir)
	for n: Node3D in director.soft_targets():
		if WeaponMath.in_cone(apex, dir, deg_to_rad(float(w["half_deg"])), float(w["range"]), n.global_position):
			director.hit_target(n, {"kind": "sonic", "from": apex, "dir": WeaponMath.flat_dir(n.global_position - apex), "power": PUSH})


func stop() -> void:
	if music:
		music.stop()
	queue_free()
