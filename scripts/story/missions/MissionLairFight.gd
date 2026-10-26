# File: res://scripts/story/missions/MissionLairFight.gd
# Base of the Phase C lair missions on GunFight (plan 2026-10-26-phase-c-integration.md): the Day 3 yard (FreeRoam) and
# the Day 5 basement (StoryBasement) host them alike. armed (the Phase W pistol + shotgun, GunFight's loadout), the
# player's HP and "TOANG!" when it reaches 0 (retry() = GunFight.retry() at the wave checkpoint), the cover in the level's
# cover root, the guards in the StoryCast lair looks (sheep / wolf / fox masks), the crowd of FreeRoam hidden while it runs
# (an industrial yard at night; restored after), a leash (LEASH_M from the level centre: running off = "TOANG!"), and the
# short replay helper: a recorder from the last wave on, "blow" on the last knockout, REPLAY_AFTER s later the beat's
# replay slot (StoryStage), then done.
# opts: "level" (LairYard / LairBasement), "points" (the level's mission_points(task): world-space spots), "manual_replay",
# "seed". Subclasses build the waves in _start() through make_fight() / guard().
class_name MissionLairFight
extends StoryMission

const LEASH_M: float = 46.0
const T_DOWN: String = "Trúng đạn gục rồi!"
const T_RAN: String = "Bỏ chạy khỏi hang ổ rồi!"
const GUARD_IDS: Array[String] = ["guard_sheep", "guard_wolf", "guard_fox"]

var fight: GunFight
var level: Node3D
var pts: Dictionary = {}
var rec: CineReplayRecorder
var last_ko: Node3D = null
var replay_wait: float = -1.0
var won_info: Dictionary = {}
var _crowd: Dictionary = {}
var _leash_t: float = 0.0
## The mission's top panel (title, info, meter) stays visible, moved under GunHUD's panel (MissionCrates: the countdown
## and the crate counter); otherwise GunHUD shows everything and the panel is hidden.
var keep_top: bool = false


func _init() -> void:
	armed = true


func setup(r: Node3D, b: Dictionary, o: Dictionary = {}) -> void:
	super.setup(r, b, o)
	level = opts.get("level", null)
	pts = opts.get("points", {})


func begin() -> void:
	super.begin()
	if keep_top:
		var top: Control = hud.get_node_or_null("Top") as Control if hud else null
		if top:
			top.offset_top = GunHUD.TOP + GunHUD.PANEL.y + 10.0
	else:
		hide_top_panel()
	_quiet_crowd(true)


## A GunFight under this mission (cover: the level's cover root), its won / lost / enemy_ko wired.
func make_fight(o: Dictionary = {}) -> GunFight:
	fight = GunFight.new()
	fight.name = "Fight"
	add_child(fight)
	var fo: Dictionary = {"roam": roam, "seed": int(opts.get("seed", 3))}
	var cr: Variant = level.get("cover_root") if level else null
	if cr is Node3D:
		fo["cover_root"] = cr
	elif level:
		fo["cover_root"] = level
	for k: Variant in o.keys():
		fo[k] = o[k]
	fight.setup(fo)
	fight.won.connect(_on_fight_won)
	fight.lost.connect(_on_fight_lost)
	fight.enemy_ko.connect(_on_enemy_ko)
	fight.wave_started.connect(_on_wave_started)
	for a: Variant in pts.get("ammo", []):
		fight.add_ammo(a, WeaponData.Slot.PISTOL if fight.pickups.size() % 2 == 0 else WeaponData.Slot.SHOTGUN)
	return fight


## A gunman wave entry in a StoryCast lair look (index i picks the mask), at `at`, optional patrol and extra opts.
func guard(i: int, at: Vector3, patrol: Array = [], extra: Dictionary = {}) -> Dictionary:
	var id: String = GUARD_IDS[i % GUARD_IDS.size()]
	var o: Dictionary = {"body_fn": func(_look: Dictionary) -> Node3D: return StoryCast.build(id), "mask": "none"}
	for k: Variant in extra.keys():
		o[k] = extra[k]
	var d: Dictionary = {"at": at, "opts": o}
	if not patrol.is_empty():
		d["patrol"] = patrol
	return d


## A cyan ring on the floor at p (the sneak goal, the hack terminal): freed with the mission.
func goal_marker(p: Vector3, r: float = 1.4) -> Node3D:
	var root := Node3D.new()
	root.name = "Goal"
	add_child(root)
	root.global_position = p
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.25, 0.95, 1.0, 0.45)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.set_meta("vice_done", true)
	var ring: MeshInstance3D = CineFX._cyl(root, "Ring", r, r, 0.05, Vector3(0.0, 0.08, 0.0), m)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var beam: MeshInstance3D = CineFX._cyl(root, "Beam", 0.25, 0.25, 3.0, Vector3(0.0, 1.5, 0.0), m)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


func place_player(key: String = "start") -> void:
	if pts.has(key):
		teleport_player(pts[key], float(pts.get(key + "_yaw", 0.0)))


# ----- replay -----
## The recorder starts with the last wave (the player and its enemies).
func _on_wave_started(i: int) -> void:
	if fight and i == fight.waves.size() - 1 and String(beat.get("replay", "")) != "":
		if rec and is_instance_valid(rec):
			rec.queue_free()
		var nodes: Array = [player]
		for e: Variant in fight.enemies:
			nodes.append(e)
		rec = StoryStage.make_recorder(self, nodes)


func _on_enemy_ko(e: Node3D) -> void:
	last_ko = e
	if fight and fight.wave == fight.waves.size() - 1 and fight.alive().is_empty() and rec:
		rec.mark("blow")


func _on_fight_won() -> void:
	won_info = {"ko": fight.ko_total}
	if rec and String(beat.get("replay", "")) != "":
		replay_wait = StoryStage.REPLAY_AFTER
	else:
		finish(won_info)


func _on_fight_lost() -> void:
	fail(T_DOWN)


func _tick(dt: float) -> void:
	if replay_wait >= 0.0:
		replay_wait -= dt
		if replay_wait < 0.0:
			var focus: Node3D = last_ko if last_ko and is_instance_valid(last_ko) else player
			play_short_replay(rec, String(beat.get("replay", "")), focus, player, func() -> void: finish(won_info))
		return
	_leash_t -= dt
	if _leash_t <= 0.0 and pts.has("centre") and player:
		_leash_t = 0.5
		if flat(player.global_position, pts["centre"]) > float(pts.get("leash", LEASH_M)):
			fail(T_RAN)
	_lair_tick(dt)


## Subclass per-tick logic (not called while the replay waits).
func _lair_tick(_dt: float) -> void:
	pass


func _reset() -> void:
	replay_wait = -1.0
	last_ko = null
	if fight:
		fight.retry()


func _cleanup() -> void:
	if fight and is_instance_valid(fight):
		fight.stop()
		fight.queue_free()
	fight = null
	_quiet_crowd(false)


## FreeRoam's pedestrians off while the lair mission runs (on = hide), back after; nothing in a lair scene.
func _quiet_crowd(on: bool) -> void:
	var peds: Variant = roam.get("pedestrians") if roam else null
	if not (peds is Node) or not is_instance_valid(peds):
		return
	var n: Node = peds
	if on and _crowd.is_empty():
		_crowd = {"vis": (n as Node3D).visible if n is Node3D else true, "proc": n.process_mode}
		if n is Node3D:
			(n as Node3D).visible = false
		n.process_mode = Node.PROCESS_MODE_DISABLED
	elif not on and not _crowd.is_empty():
		if n is Node3D:
			(n as Node3D).visible = bool(_crowd["vis"])
		n.process_mode = _crowd["proc"]
		_crowd = {}


func hud_visible() -> bool:
	return state in ["running", "failed"] and replay == null
