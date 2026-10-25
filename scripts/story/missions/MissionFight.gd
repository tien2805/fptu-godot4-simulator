# File: res://scripts/story/missions/MissionFight.gd
# The Phase B story brawls on MeleeFight (spec B-D1 / B-D2, B-D5 beat 5, B-D7 beat 6), forced unarmed:
#   d1  three couriers (Mũ Đỏ, Mũ Xanh, Mũ Vàng) at the west gate, start line "Gét gô!";
#   d4  sheep-masked clones in two waves in front of the canteen, Cừu Dolly joins the second and flees at 30 % HP.
# The player and the enemies stand around the beat's anchor (free spots). MeleeFight `won` = done (the beat's "after"
# cinematic follows), `lost` (the player down) = fail "TOANG!"; retry() = MeleeFight.retry() from its checkpoint (the
# wave in progress, full HP); abort() stops the fight.
class_name MissionFight
extends StoryMission

const RING_M: float = 5.5
const T_DOWN: String = "Bị hạ đo ván rồi!"
const D1_LINE: String = "Gét gô!"
const D4_LINE: String = "Bầy cừu xông lên!"

var fight: MeleeFight
var centre: Vector3 = Vector3.ZERO
var kind: String = "d1"


## Fight centre: opts "centre" (Vector3, tests / StoryRoam: the beat anchor), else the player's spot.
func _start() -> void:
	kind = String(beat.get("fight", "d1"))
	var c: Variant = opts.get("centre", null)
	centre = c if c is Vector3 else (player.global_position if player else Vector3.ZERO)
	var face: Variant = opts.get("face", null)
	var yaw: float = float(face) if face != null else (player.facing_yaw() if player else 0.0)
	teleport_player(free_spot(centre), yaw)
	fight = MeleeFight.new()
	fight.name = "Fight"
	add_child(fight)
	fight.setup({"roam": roam, "force_unarmed": true, "max_attackers": 2, "auto_checkpoint": true,
		"start_line": D1_LINE if kind == "d1" else D4_LINE, "seed": int(opts.get("seed", 11))})
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	if kind == "d1":
		fight.add_wave(_ring([["courier", "courier_do", "Mũ Đỏ"], ["courier", "courier_xanh", "Mũ Xanh"],
			["courier", "courier_vang", "Mũ Vàng"]], fwd))
	else:
		fight.add_wave(_ring([["clone", "clone_masked", "Nhân bản"], ["clone", "clone_masked", "Nhân bản"],
			["clone", "clone_masked", "Nhân bản"], ["clone", "clone_masked", "Nhân bản"]], fwd))
		fight.add_wave(_ring([["dolly", "dolly", "Cừu Dolly"], ["clone", "clone_masked", "Nhân bản"],
			["clone", "clone_masked", "Nhân bản"]], fwd))
	fight.won.connect(_on_won)
	fight.lost.connect(_on_lost)
	fight.start()
	set_info(_info())


## Spawns spread on an arc in front of the player: [archetype, cast id, label] each.
func _ring(list: Array, fwd: Vector3) -> Array:
	var out: Array = []
	var n: int = list.size()
	for i: int in n:
		var a: float = (float(i) - float(n - 1) * 0.5) * 0.7
		var dir: Vector3 = fwd.rotated(Vector3.UP, a)
		var at: Vector3 = free_spot(centre + dir * RING_M, 4)
		var cast_id: String = String(list[i][1])
		out.append({"archetype": String(list[i][0]), "at": at,
			"opts": {"label": String(list[i][2]), "body_fn": func(_look: Dictionary) -> Node3D: return StoryCast.build(cast_id),
				"seed": 100 + i}})
	return out


func _info() -> String:
	if fight == null:
		return ""
	return "Đợt %d/%d · Còn %d đối thủ" % [fight.wave + 1, fight.waves.size(), fight.alive().size()]


func _tick(_dt: float) -> void:
	if fight and int(clock * 10.0) % 3 == 0:
		set_info(_info())


func _on_won() -> void:
	finish({"ko": fight.ko_total})


func _on_lost() -> void:
	fail(T_DOWN)


func _reset() -> void:
	if fight:
		fight.retry()


func _cleanup() -> void:
	if fight and is_instance_valid(fight):
		fight.stop()
		fight.queue_free()
	fight = null
