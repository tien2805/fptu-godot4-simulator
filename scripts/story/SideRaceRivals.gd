# File: res://scripts/story/SideRaceRivals.gd
# The rivals of a free-roam side race (plan 2026-11-03-w5-side.md T1): 2-3 street racers on the Day 2 race tech. Each is a
# DriftRival in "calm" mode (no kicks, no blocks: he rides his own lane, drifts the tight corners, fires nitro on the
# straights) with his own look, name, scooter paint and pace. SideRace owns the node: setup(course, opts), place_grid(),
# go() at GO, then tick(dt, p_s, p_d, p_v, race_t) every frame with the player on the path.
# Rubber band per rival (the owner hated rivals off screen on Day 2): his speed factor eases off when he leads (from
# BAND_START_M down to band_far at BAND_FULL_M) and his lead is capped at LEAD_CAP_M (DriftRival.lead_cap: never faster
# than the player near it); behind the player he pushes (band_lead), and from CATCH_START_M behind he catches up hard
# (up to CATCH_BAND at CATCH_FULL_M, and at least the player's speed x CATCH_V_K); a rival left HOP_M behind and out of the
# camera's frame is put back HOP_TO_M behind (never seen). After the player's reset to a gate every rival beyond the
# window is put back in it (regroup()). Contact: side by side touching pushes both apart with sparks (no damage), riding into his back wheel caps
# the player's speed.
# Standings: standings(p_s, p_time) rows {name, s, done, time, player} sorted (finished first by time, then by progress);
# place_of_player(); near_rival() (the guide's marker: the rival just ahead of the player, else the nearest behind).
# Every tuned number goes through Difficulty.pick (read at setup).
class_name SideRaceRivals
extends Node3D

const T_STREET: Array[String] = ["Đua không em?", "Bám theo nè!", "Xe zin mà đòi đua?", "Nẹt pô nghe chơi!",
	"Đường này của tao!"]
const T_PACK: Array[String] = ["Bầy Sói không thua đâu!", "Theo kịp không cưng?", "Né đường cho đàn anh!",
	"Chậm như rùa!"]
## Per route: name, body (cast + cast_extra, or a CharacterBuilder rider look), scooter paint, underglow, pace factor.
const ROSTER: Dictionary = {
	"dua_cau": [
		{"name": "Tí Nẹt Pô", "look": {"preset": "rider", "seed": 611, "female": false, "body": "hoodie", "backpack": false,
			"shirt_color": Color("#B03A2E"), "helmet_color": Color("#E74C3C")}, "paint": Color("#C0392B"),
			"glow": Color("#FF5A3C"), "pace": 1.0, "taunts": "street"},
		{"name": "Bé Na Bốc Đầu", "look": {"preset": "rider", "seed": 622, "female": true, "body": "hoodie", "backpack": false,
			"shirt_color": Color("#E85BA8"), "helmet_color": Color("#F5B7D6")}, "paint": Color("#EDEDED"),
			"glow": Color("#FF4FA3"), "pace": 0.97, "taunts": "street"},
	],
	"dua_vong": [
		{"name": "Tèo Xe Độ", "look": {"preset": "rider", "seed": 633, "female": false, "body": "hoodie", "backpack": false,
			"shirt_color": Color("#1F6F50"), "helmet_color": Color("#2ECC71")}, "paint": Color("#1E8449"),
			"glow": Color("#3CFF7A"), "pace": 1.0, "taunts": "street"},
		{"name": "Cô Ba Drift", "look": {"preset": "rider", "seed": 644, "female": true, "body": "hoodie", "backpack": false,
			"shirt_color": Color("#5B2C83"), "helmet_color": Color("#9B59B6")}, "paint": Color("#6C3483"),
			"glow": Color("#B36BFF"), "pace": 0.98, "taunts": "street"},
		{"name": "Sói Còi", "cast": "bay_soi", "cast_extra": {"seed": 3211}, "paint": Color("#4A4F57"),
			"glow": Color("#FFB020"), "pace": 0.95, "taunts": "pack"},
	],
	"dua_gp": [
		{"name": "Sói Lẻ", "cast": "bay_soi", "cast_extra": {"seed": 3222}, "paint": Color("#5C626B"),
			"glow": Color("#FF2340"), "pace": 0.98, "taunts": "pack"},
		{"name": "Sói Ghẻ", "cast": "bay_soi", "cast_extra": {"seed": 3233}, "paint": Color("#3E434A"),
			"glow": Color("#FFB020"), "pace": 0.96, "taunts": "pack"},
		{"name": "Tí Nẹt Pô", "look": {"preset": "rider", "seed": 611, "female": false, "body": "hoodie", "backpack": false,
			"shirt_color": Color("#B03A2E"), "helmet_color": Color("#E74C3C")}, "paint": Color("#C0392B"),
			"glow": Color("#FF5A3C"), "pace": 0.93, "taunts": "street"},
	],
}
const LANES: Dictionary = {2: [-1.3, 1.3], 3: [-1.6, 0.0, 1.6]}
## Grid: the player at (0, +PLAYER_GRID_D); the rivals ahead in two columns.
const PLAYER_GRID_D: float = 1.2
const GRID: Array[Vector2] = [Vector2(4.0, -1.2), Vector2(8.0, 1.2), Vector2(12.0, -1.2)]
const BAND_START_M: float = 6.0
const BAND_FULL_M: float = 18.0
const LEAD_CAP_M: float = 22.0
const CATCH_START_M: float = 8.0
const CATCH_FULL_M: float = 24.0
const CATCH_BAND: float = 1.35
## Far behind (past CATCH_START_M) he also rides at least the player's speed x CATCH_V_K, whatever the corner; past HOP_M
## behind and out of the camera's frame (checked every HOP_CHECK_S) he is put back HOP_TO_M behind (never seen).
const CATCH_V_K: float = 1.12
const HOP_M: float = 36.0
const HOP_TO_M: float = 22.0
const HOP_CHECK_S: float = 0.25
## regroup(): a rival beyond this ahead / behind after the player's reset is put back near him.
const REGROUP_AHEAD_M: float = 24.0
const REGROUP_BEHIND_M: float = 30.0
const CONTACT_LAT: float = 0.95
const CONTACT_ALONG: float = 1.7
const CONTACT_CD: float = 0.8

var course: DriftCourse
var bike: Node3D = null
var rivals: Array[DriftRival] = []
## Finish time per rival (race seconds; -1 = not yet).
var finish_t: PackedFloat32Array = PackedFloat32Array()
var racing: bool = false
var contacts: int = 0
var regroups: int = 0
var hops: int = 0
var _hop_t: float = 0.0
## Difficulty-picked (setup).
var side_pace: float = 1.0
var band_far: float = 0.88
var band_lead: float = 1.06
var _contact_cd: PackedFloat32Array = PackedFloat32Array()
var _rows: Array[Dictionary] = []


static func roster(route_id: String) -> Array:
	return ROSTER.get(route_id, ROSTER["dua_cau"])


## opts: "route" (ROSTER key), "bike" (the player's bike: contact, ray exclude), "count" (at most the roster size).
func setup(c: DriftCourse, opts: Dictionary = {}) -> void:
	course = c
	name = "SideRaceRivals"
	bike = opts.get("bike", null)
	side_pace = float(Difficulty.pick(1.0, 0.9))
	band_far = float(Difficulty.pick(0.9, 0.78))
	band_lead = float(Difficulty.pick(1.06, 1.03))
	var ro: Array = roster(String(opts.get("route", "dua_cau")))
	var n: int = mini(int(opts.get("count", ro.size())), ro.size())
	var lanes: Array = LANES.get(n, [0.0, 0.0, 0.0])
	for i: int in n:
		var e: Dictionary = ro[i]
		var r := DriftRival.new()
		add_child(r)
		if bike:
			r.ray_exclude.append(bike.get_rid())
		var o: Dictionary = {"seed": 5100 + i * 37, "name": String(e["name"]), "paint": e["paint"], "glow": e["glow"], "calm": true,
			"lane": float(lanes[i]), "taunts": T_PACK if String(e.get("taunts", "")) == "pack" else T_STREET}
		if e.has("look"):
			o["look"] = e["look"]
		else:
			o["cast"] = String(e.get("cast", "bay_soi"))
			o["cast_extra"] = e.get("cast_extra", {})
		r.setup(course, o)
		r.name = "Rival%d" % i
		r.set_meta("pace_k", float(e.get("pace", 1.0)))
		rivals.append(r)
		_rows.append({"name": String(e["name"]), "s": 0.0, "done": false, "time": -1.0, "player": false})
	_rows.append({"name": "", "s": 0.0, "done": false, "time": -1.0, "player": true})
	finish_t.resize(n)
	finish_t.fill(-1.0)
	_contact_cd.resize(n)
	_contact_cd.fill(0.0)
	Impact.prepare(self)   # the contact sparks and thud warmed up now, never on the first touch mid-race


## Everyone on the grid, stopped, the race state reset.
func place_grid() -> void:
	racing = false
	finish_t.fill(-1.0)
	for i: int in rivals.size():
		var r: DriftRival = rivals[i]
		var g: Vector2 = GRID[i % GRID.size()]
		r.place_at(g.x, g.y)
		_tune(r)


func _tune(r: DriftRival) -> void:
	r.refresh_tuning()
	r.pace *= side_pace * float(r.get_meta("pace_k", 1.0))
	r.lead_cap = LEAD_CAP_M


## GO: every rival off the line (a launch burst).
func go() -> void:
	racing = true
	for r: DriftRival in rivals:
		r.start_race()


## The rubber band for one rival: g = his progress minus the player's (m).
func band_for(g: float) -> float:
	if g >= 0.0:
		return lerpf(1.0, band_far, clampf((g - BAND_START_M) / (BAND_FULL_M - BAND_START_M), 0.0, 1.0)) if g > BAND_START_M else 1.0
	if -g < CATCH_START_M:
		return band_lead
	return lerpf(band_lead, CATCH_BAND, clampf((-g - CATCH_START_M) / (CATCH_FULL_M - CATCH_START_M), 0.0, 1.0))


## Every frame: the player on the path (progress, lateral, speed) and the race clock (for the finish times).
func tick(dt: float, p_s: float, p_d: float, p_v: float, race_t: float) -> void:
	for i: int in rivals.size():
		var r: DriftRival = rivals[i]
		r.p_s = p_s
		r.p_d = p_d
		r.p_v = p_v
		var g: float = r.s - p_s
		if racing:
			var bf: float = band_for(g)
			if g < -CATCH_START_M and not r.finished:
				bf = maxf(bf, p_v * CATCH_V_K / maxf(course.speed_at(r.s + r.v * 0.35, true) * r.pace, 1.0))
			r.band = lerpf(r.band, bf, minf(1.0, dt * 3.0))
			r.fight = g < 12.0 and g > -12.0
		r.tick(dt, g)
		if racing and not r.finished and r.s >= course.length:
			r.finished = true
			finish_t[i] = race_t
		_contact_cd[i] -= dt
		if racing and bike != null and is_instance_valid(bike):
			_contact(i, r, p_s, p_d, p_v)
	_hop_t -= dt
	if racing and _hop_t <= 0.0:
		_hop_t = HOP_CHECK_S
		_hop_behind(p_s)


## A rival left HOP_M behind and out of the camera's frame is put back HOP_TO_M behind the player (he never sees it).
func _hop_behind(p_s: float) -> void:
	var vp: Viewport = get_viewport() if is_inside_tree() else null
	var cam: Camera3D = vp.get_camera_3d() if vp else null
	for r: DriftRival in rivals:
		if r.finished or r.s - p_s > -HOP_M:
			continue
		var head: Vector3 = r.global_position + Vector3(0.0, 1.2, 0.0)
		if cam != null and not cam.is_position_behind(head) and Rect2(Vector2.ZERO, vp.get_visible_rect().size).has_point(cam.unproject_position(head)):
			continue
		hops += 1
		r.s = maxf(p_s - HOP_TO_M, r.s)
		r.v = maxf(r.v, course.speed_at(r.s) * r.pace)


## Side by side touching: both pushed apart with sparks; riding into his back wheel caps the player's speed (DriftDuel).
func _contact(i: int, r: DriftRival, p_s: float, p_d: float, p_v: float) -> void:
	var along: float = r.s - p_s
	var lat: float = r.d - p_d
	if absf(along) < CONTACT_ALONG and absf(lat) < CONTACT_LAT and _contact_cd[i] <= 0.0:
		_contact_cd[i] = CONTACT_CD
		contacts += 1
		var sgn: float = -signf(lat) if lat != 0.0 else 1.0
		var rr: Vector2 = course.right(p_s) * sgn
		bike.global_position += Vector3(rr.x, 0.0, rr.y) * 0.35
		if "velocity" in bike:
			bike.set("velocity", (bike.get("velocity") as Vector3) + Vector3(rr.x, 0.0, rr.y) * 2.5)
		r.d_target = clampf(r.line_d - sgn * 1.0, -3.0, 3.0)
		var at: Vector3 = (bike.global_position + r.global_position) * 0.5 + Vector3(0.0, 0.5, 0.0)
		Impact.particles(self, "sparks", at, Vector3(0.0, 0.7, 0.0), 0.8)
		Impact.sound(self, "metal_slam", at, -8.0)
		if bike.has_method("add_camera_shake"):
			bike.call("add_camera_shake", 0.3)
	elif along > 0.4 and along < 2.2 and absf(lat) < 0.8 and "current_speed_ms" in bike and p_v > r.v:
		bike.set("current_speed_ms", maxf(r.v - 0.5, 0.0))


## After the player's reset to a gate: a rival far ahead or behind is put back near him (the lead he had, clamped), his
## speed held down, so nobody is lost off screen.
func regroup(p_s: float) -> void:
	for i: int in rivals.size():
		var r: DriftRival = rivals[i]
		if r.finished:
			continue
		var g: float = r.s - p_s
		if g > REGROUP_AHEAD_M or g < -REGROUP_BEHIND_M:
			regroups += 1
			r.s = clampf(p_s + clampf(g, -8.0, 6.0 + 4.0 * float(i)), 0.0, course.length - 1.0)
			r.v = minf(r.v, 6.0)
			r.band = 1.0


## Rows {name, s, done, time, player} sorted: finished first (by time), then by progress. p_time >= 0: the player is in.
func standings(p_s: float, p_time: float) -> Array[Dictionary]:
	for i: int in rivals.size():
		var row: Dictionary = _rows[i]
		row["s"] = rivals[i].s
		row["done"] = finish_t[i] >= 0.0
		row["time"] = finish_t[i]
	var pr: Dictionary = _rows[_rows.size() - 1]
	pr["s"] = p_s
	pr["done"] = p_time >= 0.0
	pr["time"] = p_time
	var out: Array[Dictionary] = _rows.duplicate()
	out.sort_custom(_before)
	return out


static func _before(a: Dictionary, b: Dictionary) -> bool:
	if bool(a["done"]) != bool(b["done"]):
		return bool(a["done"])
	if bool(a["done"]):
		return float(a["time"]) < float(b["time"])
	return float(a["s"]) > float(b["s"])


## The player's place now (1 = first): rivals finished, or ahead on the path while he is not finished.
func place_of_player(p_s: float, p_done: bool) -> int:
	var n: int = 1
	for i: int in rivals.size():
		if finish_t[i] >= 0.0 or (not p_done and rivals[i].s > p_s):
			n += 1
	return n


## The rival the guide marks: the nearest one ahead of the player, else the nearest behind (null with none left).
func near_rival(p_s: float) -> DriftRival:
	var best: DriftRival = null
	var best_g: float = INF
	var back: DriftRival = null
	var back_g: float = INF
	for r: DriftRival in rivals:
		if r.finished:
			continue
		var g: float = r.s - p_s
		if g >= 0.0 and g < best_g:
			best_g = g
			best = r
		elif g < 0.0 and -g < back_g:
			back_g = -g
			back = r
	return best if best != null else back


## The farthest any racing rival is from the player along the path (tests, sims).
func max_gap(p_s: float) -> float:
	var m: float = 0.0
	for r: DriftRival in rivals:
		if not r.finished:
			m = maxf(m, absf(r.s - p_s))
	return m
