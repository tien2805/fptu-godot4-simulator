# File: res://scripts/story/missions/MissionFight.gd
# The Phase B story brawls on MeleeFight (spec B-D1 / B-D2, B-D5 beat 5, B-D7 beat 6), forced unarmed:
#   d1  three couriers (Mũ Đỏ, Mũ Xanh, Mũ Vàng) at the west gate, start line "Gét gô!";
#   d4  sheep-masked clones in two waves in front of the canteen, Cừu Dolly joins the second and flees at 30 % HP;
#   d2  (Phase C, spec C-D6 beat 6 / C-D4) Sói Xám alone on the bank under the Rạch Hầm bridge: the soi_xam mini-boss
#       archetype (fast 4-hit chains, LED-eye glow before every attack, a howl buff at 50 %, the boss bar).
# The player and the enemies stand around the beat's anchor (free spots). MeleeFight `won` = done (the beat's "after"
# cinematic follows), `lost` (the player down) = fail "TOANG!"; retry() = MeleeFight.retry() from its checkpoint (the
# wave in progress, full HP); abort() stops the fight.
# Wave 2 (plan 2026-10-29-w2-early.md Task 6): d1 and d4 get an ArenaDressing (parked bikes and a vendor table to slam
# into, helmets and lids / trays and chairs on the floor through the MeleeFight "props" option; d4: [E] flips a canteen
# table, food throwers in wave 2) and one escalation beat each: d1 calls in reinforcements (two more couriers on Thường,
# one on Dễ, a preview cut on them), d4 turns into the food fight at wave 2.
class_name MissionFight
extends StoryMission

const RING_M: float = 5.5
const T_DOWN: String = "Bị hạ đo ván rồi!"
const D1_LINE: String = "Gét gô!"
const D4_LINE: String = "Bầy cừu xông lên!"
const D2_LINE: String = "Đầu đàn thì sao? Vào đây!"
const D1_BACKUP_LINE: String = "Gọi thêm anh em! Mũ Tím, Mũ Cam, vô!"

var fight: MeleeFight
var centre: Vector3 = Vector3.ZERO
var kind: String = "d1"
var arena: ArenaDressing
var escalated: bool = false


## Reinforcements of the d1 escalation (Thường 2, Dễ 1).
static func d1_backup() -> int:
	return int(Difficulty.pick(2, 1))


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
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var props: Array = ArenaDressing.props_for(kind, centre, fwd) if kind in ["d1", "d4"] else []
	for pd: Dictionary in props:
		pd["at"] = _floor(free_spot(pd["at"], 3))
	fight.setup({"roam": roam, "force_unarmed": true, "max_attackers": 2, "auto_checkpoint": true,
		"start_line": {"d1": D1_LINE, "d2": D2_LINE}.get(kind, D4_LINE), "seed": int(opts.get("seed", 11)), "props": props})
	if kind in ["d1", "d4"]:
		arena = ArenaDressing.new()
		add_child(arena)
		arena.setup(kind, self, fight, centre, fwd)
	if kind == "d2":
		fight.add_wave(_ring([["soi_xam", "soi_xam", "Sói Xám"]], fwd))
	elif kind == "d1":
		fight.add_wave(_ring([["courier", "courier_do", "Mũ Đỏ"], ["courier", "courier_xanh", "Mũ Xanh"],
			["courier", "courier_vang", "Mũ Vàng"]], fwd))
		var backup: Array = [["courier", "courier_xanh", "Mũ Tím"], ["courier", "courier_vang", "Mũ Cam"]]
		fight.add_wave(_ring(backup.slice(0, d1_backup()), -fwd))
	else:
		fight.add_wave(_ring([["clone", "clone_masked", "Nhân bản"], ["clone", "clone_masked", "Nhân bản"],
			["clone", "clone_masked", "Nhân bản"], ["clone", "clone_masked", "Nhân bản"]], fwd))
		fight.add_wave(_ring([["dolly", "dolly", "Cừu Dolly"], ["clone", "clone_masked", "Nhân bản"],
			["clone", "clone_masked", "Nhân bản"]], fwd))
	fight.won.connect(_on_won)
	fight.lost.connect(_on_lost)
	fight.wave_started.connect(_on_wave)
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


func _floor(p: Vector3) -> Vector3:
	return Vector3(p.x, ground_y(p), p.z)


## The escalation beat at wave 2: d1 reinforcements (a line, a preview cut), d4 the food fight. Every enemy's slam into a
## table splashes soup (ArenaDressing.on_slammed).
func _on_wave(i: int) -> void:
	if arena:
		for e: Variant in fight.enemies:
			var me: MeleeEnemy = e
			if not me.slammed.is_connected(arena.on_slammed):
				me.slammed.connect(arena.on_slammed)
	if i < 1 or escalated:
		return
	escalated = true
	if kind == "d1":
		popup(D1_BACKUP_LINE, 2.2, WARN)
		cues_played.append("backup")
		var first: Variant = fight.enemies[0] if not fight.enemies.is_empty() else null
		var d: CameraDirector = CameraDirector.live()
		if first != null and d != null and (first as Node3D).is_inside_tree():
			d.preview_cut(first as Node3D, 0.6)
		if arena:
			arena.cuts += 1
	elif kind == "d4" and arena:
		arena.start_food_fight()


func _tick(dt: float) -> void:
	if arena:
		arena.tick(dt)
		if kind == "d4" and arena.flip_target() >= 0:
			set_prompt(ArenaDressing.T_FLIP)
		else:
			set_prompt("")
	if fight and int(clock * 10.0) % 3 == 0:
		set_info(_info())


func _unhandled_input(event: InputEvent) -> void:
	if state != "running" or arena == null or not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if k.pressed and not k.echo and k.physical_keycode == KEY_E and arena.try_flip():
		get_viewport().set_input_as_handled()


func _on_won() -> void:
	finish({"ko": fight.ko_total})


func _on_lost() -> void:
	fail(T_DOWN)


func _reset() -> void:
	if arena:
		arena.reset()
	if fight:
		fight.retry()
	if fight and fight.wave < 1:
		escalated = false
	elif fight and kind == "d4" and arena:
		arena.start_food_fight()   # retry from the food-fight wave: the throwers are back


func _cleanup() -> void:
	if arena and is_instance_valid(arena):
		arena.stop_food_fight()
		arena.queue_free()
	arena = null
	if fight and is_instance_valid(fight):
		fight.stop()
		fight.queue_free()
	fight = null
