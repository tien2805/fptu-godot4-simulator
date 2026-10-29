# File: res://scripts/story/missions/MissionBasementGunfight.gd
# Day 5 gunfight in the server hall (lair task "gunfight"; plan 2026-10-30-w3-day5.md T3): MissionGunfight in the basement
# with its signature, THE RACK DOMINO. One rack per hall row carries a red "KHÔNG ĐƯỢC ĐỤNG" label (LairBasement); its
# DominoTarget is a soft target of the weapons (StoryBasement.extra_targets). Shooting it tips the row onto its aisle like
# dominoes, in slow motion (Impact.clock().slowmo, the scale owner protocol), and every gunman under a landing segment
# (LairBasement.row_footprint + reach_m) is knocked out (a finisher-tier Impact with sparks); the fallen segments become low
# cover (GunFight.cover.add_box + reprune()). A retry stands up again the rows that fell during the failed wave.
# Waves (Difficulty.pick, T8 tuned against the sloppy gun bot): Thường 3 (WAVES), Dễ 2 (WAVES_EASY), SHOOTERS at once:
#   wave 1 down the stairs (a preview cut on the first guard), Anh Duy's label hint;
#   wave 2 through the side door kicked open (a preview cut on the door), its last guard with the pallet shield (Gunman
#   "kind": "shield", the shared stream's: before the merge an ordinary gunman);
#   wave 3 (Thường) from both ends: the stairs and, behind the player, the server room (T8: a crossfire; "Sau lưng!", a
#     preview cut on the first guard out of the room, Anh Duy's warning);
#   Za Mẫn taunts from the monitor wall between waves (radio_as "za_man", jokes).
# beats / cuts / dominoes / domino_kos: logs for the tests.
class_name MissionBasementGunfight
extends MissionGunfight

const CUT_S: float = 0.6
const DOMINO_SLOW: float = 0.35
const DOMINO_SLOW_S: float = 1.1
const HINT_AT_S: float = 5.5
## T8 (sim_day5): gunmen per wave and shooting tokens, Thường / Dễ.
const WAVES: Array[int] = [5, 5, 6]
const WAVES_EASY: Array[int] = [3, 4]
const SHOOTERS: int = 4
static var GUARD_OPTS: Dictionary = {}
const SHOOTERS_EASY: int = 3
const T_DOMINO: String = "Đổ dây chuyền!"
const T_BEHIND: String = "Sau lưng!"
const TAUNTS: Array[String] = ["Bảo vệ của anh đi làm theo ca, ca sau đông hơn đó em.",
	"Mấy tủ đó anh mua trả góp đó! Bắn nhẹ thôi!"]

var reach_m: float = 0.3
var wave_sizes: Array = []
var cuts: int = 0
var dominoes: int = 0
var domino_kos: int = 0
var beats: Array[String] = []
var cover_rows: Dictionary = {}          # row -> PackedInt32Array of the cover slots its fallen segments added
var door_marker: Node3D = null
var _wave_fallen: Dictionary = {}        # wave index -> rows already lying when that wave first started
var _hinted: bool = false
var _want_slow: bool = false             # the domino's slow motion waits for a director cut to hand the scale back
## T9 readability: every off-screen gunman as an edge chevron, a ping over the hidden ones when none is in sight for a while.
var guide: BasementGuide = null


func _start() -> void:
	reach_m = float(Difficulty.pick(0.3, 0.8))
	wave_sizes = Difficulty.pick(WAVES, WAVES_EASY)
	place_player()
	make_fight({"start_alerted": true, "max_shooters": int(Difficulty.pick(SHOOTERS, SHOOTERS_EASY)),
		"nav": level.call("nav_graph") if level and level.has_method("nav_graph") else null})
	var spots: Array = [pts.get("waves", [[]])[0], pts.get("wave_door", []), pts.get("wave_ends", [])]
	var i: int = 0
	for wi: int in wave_sizes.size():
		var wave: Array = []
		var src: Array = spots[wi]
		var n: int = mini(int(wave_sizes[wi]), src.size())
		for k: int in n:
			var extra: Dictionary = {"kind": "shield"} if wi == 1 and k == n - 1 else {}
			for key: Variant in GUARD_OPTS.keys():
				extra[key] = GUARD_OPTS[key]
			wave.append(guard(i, src[k], [], extra))
			i += 1
		fight.add_wave(wave)
	if pts.has("door"):
		door_marker = Node3D.new()
		door_marker.name = "DoorMark"
		add_child(door_marker)
		door_marker.global_position = pts["door"] + Vector3(0.0, 1.0, 0.0)
	if level:
		for pair: Array in [["domino_shot", _on_domino_shot], ["rack_landed", _on_rack_landed], ["row_fallen", _on_row_fallen]]:
			if level.has_signal(String(pair[0])) and not level.is_connected(String(pair[0]), pair[1]):
				level.connect(String(pair[0]), pair[1])
	_register_targets(true)
	fight.wave_cleared.connect(_on_wave_cleared)
	guide = BasementGuide.new()
	add_child(guide)
	guide.setup(self)
	guide.watch(fight)
	fight.start()
	radio("Guard spawn ở cầu thang kìa e, dùng cover đi, đừng face tank.", "Núp sau tủ máy mà bắn.")


## The labels as soft targets of the weapons (through the host's extra_targets).
func _register_targets(on: bool) -> void:
	if roam == null or not ("extra_targets" in roam):
		return
	var out: Array = []
	if on and level and "racks" in level:
		for r: Variant in level.get("racks"):
			out.append((r as Dictionary)["target"])
	roam.set("extra_targets", out)


func _on_wave_started(i: int) -> void:
	super._on_wave_started(i)
	if level and "racks" in level and not _wave_fallen.has(i):
		_wave_fallen[i] = level.call("fallen_rows")
	var target: Node3D = null
	match i:
		0:
			beats.append("stairs")
			target = fight.gunmen[0] as Node3D if not fight.gunmen.is_empty() else null
		1:
			beats.append("door")
			if level and level.has_method("kick_door"):
				level.call("kick_door")
			play_cue("locker_slam", -2.0)
			target = door_marker
		_:
			beats.append("both_ends")
			var ri: int = LairBasement.WAVE_ENDS_ROOM
			target = fight.gunmen[ri] as Node3D if fight.gunmen.size() > ri else _nearest_label()
			popup(T_BEHIND, 1.8, WARN)
			radio("Có đứa từ phòng máy sau lưng e kìa! Đổi cover lẹ!", "Phía sau! Bảo vệ ra từ phòng máy.", 4.0)
	_cut(target)


func _cut(target: Node3D) -> void:
	if target == null or not target.is_inside_tree():
		return
	cuts += 1
	var cd: CameraDirector = CameraDirector.live()
	if cd:
		cd.preview_cut(target, CUT_S)


## The standing labelled rack nearest the player (the domino ahead), or null.
func _nearest_label() -> Node3D:
	if level == null or not ("racks" in level) or player == null:
		return null
	var best: Node3D = null
	var bd: float = INF
	for r: Variant in level.get("racks"):
		var rd: Dictionary = r
		if float(rd["t"]) >= 0.0:
			continue
		var tg: Node3D = rd["target"]
		var d: float = flat(tg.global_position, player.global_position)
		if d < bd:
			bd = d
			best = tg
	return best


func _on_wave_cleared(i: int) -> void:
	if state == "running" and fight and i < fight.waves.size() - 1:
		beats.append("taunt")
		radio_as("za_man", TAUNTS[mini(i, TAUNTS.size() - 1)], "", 4.0)


# ----- the domino -----
func _on_domino_shot(_row: int) -> void:
	if state != "running":
		return
	dominoes += 1
	if not beats.has("domino"):
		beats.append("domino")
	_want_slow = not Impact.clock(self).slowmo(DOMINO_SLOW, DOMINO_SLOW_S, self)
	popup(T_DOMINO, 1.6)
	play_cue("metal_creak", -3.0)


## A segment hits the floor: every standing gunman under it is knocked out.
func _on_rack_landed(row: int, seg: int) -> void:
	if state != "running" or fight == null:
		return
	var rd: Dictionary = level.get("racks")[row]
	var segs: Array = rd["segs"]
	var sl: float = (float(rd["z1"]) - float(rd["z0"])) / float(segs.size())
	var fp: Rect2 = level.call("row_footprint", row, reach_m)
	var z0: float = float(rd["z0"]) + sl * seg - reach_m
	var z1: float = z0 + sl + reach_m * 2.0
	var at: Vector3 = (segs[seg] as Node3D).global_position + Vector3(float(rd["dir"]) * 1.1, 0.4, 0.0)
	Impact.particles(self, "sparks", at, Vector3.UP, 0.7)
	Impact.sound(self, "metal_slam", at, -4.0)
	Impact.shake(self, 0.22)
	for e: Variant in fight.alive():
		var g: Gunman = e as Gunman
		if g == null:
			continue
		var lp: Vector3 = level.to_local(g.global_position)
		if lp.x < fp.position.x or lp.x > fp.end.x or lp.z < z0 or lp.z > z1:
			continue
		if g.take_hit({"kind": "blast", "from": at}) == "knocked_out":
			domino_kos += 1
			Impact.hit(self, "finisher", {"pos": g.global_position + Vector3(0.0, 1.2, 0.0), "dir": Vector3(float(rd["dir"]), 0.0, 0.0),
				"no_hitstop": true})


## The row lies in the aisle: its segments are low cover now.
func _on_row_fallen(row: int) -> void:
	if fight == null or fight.cover == null:
		return
	_want_slow = false
	if not cover_rows.has(row):
		var ids := PackedInt32Array()
		for k: int in (level.get("racks")[row]["segs"] as Array).size():
			var c: Array = level.call("seg_cover", row, k)
			var first: int = fight.cover.count()
			var added: int = fight.cover.add_box(c[0], c[1])
			for j: int in added:
				ids.append(first + j)
		cover_rows[row] = ids
	_sync_cover()
	fight.reprune()


## The fallen rows' slots are offered, the standing rows' slots (after a retry) are held by the mission.
func _sync_cover() -> void:
	if fight == null:
		return
	var down: Array = level.call("fallen_rows") if level else []
	for row: Variant in cover_rows.keys():
		for id: int in cover_rows[row]:
			if int(row) in down:
				if fight.taken.get(id) == self:
					fight.taken.erase(id)
			elif not fight.taken.has(id):
				fight.taken[id] = self


func _lair_tick(dt: float) -> void:
	super._lair_tick(dt)
	if _want_slow and Impact.clock(self).slowmo(DOMINO_SLOW, DOMINO_SLOW_S, self):
		_want_slow = false
	if not _hinted and clock >= HINT_AT_S:
		_hinted = true
		radio("Thấy tủ rack dán nhãn đỏ k e? Bắn nó, cả hàng domino đè lên guard luôn.", "Bắn tủ dán nhãn đỏ cho cả hàng đổ đè bảo vệ.", 5.0)


func _reset() -> void:
	if fight and level and level.has_method("reset_racks"):
		level.call("reset_racks", _wave_fallen.get(fight.wave, []))
		_sync_cover()
	if fight and fight.wave <= 1 and level and level.has_method("reset_door"):
		level.call("reset_door")
	Impact.clock(self).end_slowmo(self)
	_want_slow = false
	super._reset()


func _cleanup() -> void:
	if is_inside_tree():
		Impact.clock(self).end_slowmo(self)
	if level:
		for pair: Array in [["domino_shot", _on_domino_shot], ["rack_landed", _on_rack_landed], ["row_fallen", _on_row_fallen]]:
			if level.is_connected(String(pair[0]), pair[1]):
				level.disconnect(String(pair[0]), pair[1])
		if state != "done":
			if level.has_method("reset_racks"):
				level.call("reset_racks", [])
			if level.has_method("reset_door"):
				level.call("reset_door")
	_register_targets(false)
	super._cleanup()
