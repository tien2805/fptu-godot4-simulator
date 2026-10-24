# File: res://scripts/wanted/WantedDirector.gd
# Phase W wanted level (spec W-D6, section 4):
#   - heat comes from the weapons (WeaponDirector.mayhem -> add_heat) and from officers knocked out (+5, Task 8);
#   - 1 / 2 / 3 stars at 4 / 12 / 25 heat; stars only rise with heat (plan P4);
#   - every crime tells the officers where the player is (the search restarts there);
#   - the officers ("observers": Officer nodes from Task 8) look for the player: eyes 1.6 m, chest 1.3 m, within SIGHT_R,
#     RAYS_PER_TICK rays per physics frame round-robin;
#   - while none sees the player for 12 / 20 / 30 s (by stars) the level drops one star and the heat falls to that star's
#     threshold; below one star the heat fades at IDLE_DECAY / s;
#   - ViceHUD shows the stars (3 cells; classic style: the small row under the clock), the radar shows the search circle
#     (centre = last seen point, radius SEARCH_R) while nobody sees him. Entering BE6 changes nothing.
# state: "free" | "stamp" | "cutscene" | "service" (Tasks 10-11). Time-based logic runs in tick(delta) (tests call it with
# set_physics_process(false)). Autoloads are only reached through get_node_or_null.
# Hot path (performance gate): `target` is computed once per tick and read by the officers; the officers live in a typed
# list; the line-of-sight rays reuse one query whose exclusion list is rebuilt only when bodies change (and at most once
# per maintain); with no heat and no officers tick returns at once; spawns are spread one per physics frame.
class_name WantedDirector
extends Node3D

signal stars_changed(stars: int)
signal cleared
signal busted(catcher: String)
signal service_started(on_campus: bool)

const STAR_HEAT: Array[float] = [4.0, 12.0, 25.0]
const LOSE_S: Array[float] = [12.0, 20.0, 30.0]
const SEARCH_R: Array[float] = [30.0, 40.0, 50.0]
const OFFICER_KO_HEAT: float = 5.0
const IDLE_DECAY: float = 0.2
const SIGHT_R: float = 45.0
const RAYS_PER_TICK: int = 3
const EYE_Y: float = 1.6
const CHEST_Y: float = 1.3
const CIRCLE_AFTER_S: float = 0.5
const LABEL_CAMPUS: String = "BẢO VỆ ĐANG TÌM"
const LABEL_STREET: String = "CẢNH SÁT ĐANG TRUY"
const GUARDS: Array[int] = [2, 4, 6]
const SPAWN_MIN: float = 25.0
const SPAWN_MAX: float = 45.0
const DESPAWN_R: float = 110.0
const MAX_OFFICERS: int = 12
const SPAWNS_PER_MAINTAIN: int = 2
const MAINTAIN_S: float = 1.0
const GIVE_UP_DESPAWN_S: float = 20.0
const BIKES: Array[int] = [1, 2, 3]
const SECOND_WAVE_S: float = 30.0
const CATCH_R: float = 1.2
const CATCH_S: float = 1.5
const STUCK_REPLACE_S: float = 3.0       # an officer pinned this long out of view is replaced ...
const STUCK_FORCE_S: float = 8.0         # ... and after this long even in view
const BUSTED_TIMELINE: String = "res://scripts/cine/timelines/wanted_busted.gd"

var heat: float = 0.0
var stars: int = 0
var state: String = "free"
var player: ThirdPersonController
var roam: Node
var md: MapData
var traffic: RoamTraffic
var vice_hud: ViceHUD
var classic_stars: ViceStars
var is_campus_fn: Callable
var campus_poly: PackedVector2Array = PackedVector2Array()
var observers: Array = []
var last_seen: Vector3 = Vector3.ZERO
var seen: bool = false
var seen_t: float = 0.0
## Officer spawning (Tasks 8-9). Tests of the heat / decay logic switch it off.
var spawning: bool = true
## Tests: (role: String, near: Vector3) -> Variant (Vector3 or null) replaces the ring search for spawn points.
var spawn_fn: Callable
## false = officers never bust the player (Task 10 implements busting; tests and the performance gate switch it off).
var catch_enabled: bool = true
var officers_spawned: int = 0
var _maintain_t: float = 0.0
var _give_up_t: float = 0.0
var _rng := RandomNumberGenerator.new()
var three_star_t: float = 0.0
var second_wave: bool = false
var pending_bikes: Array[int] = []       # police bikes on their way (RoamTraffic indices)
var bikes_sent: int = 0
var catch_t: float = 0.0
var busts: int = 0
var catcher: String = ""
var bust_on_campus: bool = false
var cine_opts: Dictionary = {}           # extra play_cinematic opts (tests: {"manual": true, "music": false})
var stamp: BustedStamp = null
var stamp_manual: bool = false           # tests drive the stamp with stamp.step_real()
var service: CommunityService = null
var _ray_i: int = 0
var _sees: Dictionary = {}               # observer instance id -> latest line-of-sight result
## Where the officers look for the player this tick (target_pos() once per tick).
var target: Vector3 = Vector3.ZERO
var _officers: Array[Officer] = []
var _ex: Array[RID] = []
var _ex_dirty: bool = true
var _rq := PhysicsRayQueryParameters3D.new()
var _spawn_budget: int = 0
var _was_campus: int = -1                # -1 unknown, 0 street, 1 campus (HUD label)
var _catch_o: Officer = null
var officers_replaced: int = 0           # stuck officers replaced (tests)
## FreeRoam: the map is open (the classic star row hides like the ViceHUD).
var hud_hidden: bool = false


## opts: player, roam (FreeRoam: roam_position, find_free_spot, play_cinematic, bike), md (MapData: campus plot), traffic,
## vice_hud, classic_stars, is_campus_fn (tests: Vector3 -> bool). Call after add_child.
func setup(opts: Dictionary) -> void:
	player = opts.get("player")
	roam = opts.get("roam")
	md = opts.get("md")
	traffic = opts.get("traffic")
	if traffic:
		traffic.police_target_fn = target_pos
		traffic.police_arrived.connect(_on_police_arrived)
	vice_hud = opts.get("vice_hud")
	classic_stars = opts.get("classic_stars")
	is_campus_fn = opts.get("is_campus_fn", Callable())
	if md:
		var lm: Variant = md.landmark("campus_plot")
		if lm is Array:
			campus_poly = MapData.poly(lm)
	_rq.collide_with_areas = false
	target = target_pos()
	refresh_hud()


func _exit_tree() -> void:
	if state == "stamp":
		_set_cine_flag(false)            # FreeRoam left during the stamp: do not leave the pause menu locked


## Where the officers look for the player: the bike while riding (FreeRoam.roam_position), else the player.
func target_pos() -> Vector3:
	if roam and roam.has_method("roam_position"):
		return roam.call("roam_position")
	return player.global_position if player else Vector3.ZERO


func is_campus(p: Vector3) -> bool:
	if is_campus_fn.is_valid():
		return bool(is_campus_fn.call(p))
	return campus_poly.size() >= 3 and Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), campus_poly)


static func stars_for(h: float) -> int:
	var n: int = 0
	for i: int in STAR_HEAT.size():
		if h >= STAR_HEAT[i] - 1e-6:
			n = i + 1
	return n


## Heat from mayhem (WeaponDirector.mayhem). Ignored while busted / in community service. Every crime restarts the search
## at the player's position.
func add_heat(amount: float, _at: Vector3 = Vector3.ZERO, _cause: String = "") -> void:
	if state != "free" or amount <= 0.0:
		return
	heat += amount
	last_seen = target_pos()
	seen_t = 0.0
	var n: int = stars_for(heat)
	if n > stars:
		stars = n
		_on_stars_changed()


func add_observer(n: Node3D) -> void:
	if not observers.has(n):
		observers.append(n)
		_ex_dirty = true


func remove_observer(n: Node3D) -> void:
	observers.erase(n)
	_sees.erase(n.get_instance_id())
	_ex_dirty = true


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if state != "free":
		return
	if stars == 0 and heat <= 0.0 and observers.is_empty():
		return                               # idle (most of the game): nothing to do
	target = target_pos()
	_prune()
	if stars == 0:
		heat = maxf(0.0, heat - IDLE_DECAY * delta)
		seen = false
		_retire(delta)
		_update_search()
		return
	_give_up_t = 0.0
	if stars == 3:
		three_star_t += delta
		second_wave = second_wave or three_star_t >= SECOND_WAVE_S
	else:
		three_star_t = 0.0
		second_wave = false
	_maintain_t -= delta
	if _maintain_t <= 0.0:
		_maintain_t = MAINTAIN_S
		_maintain()
	if _spawn_budget > 0:
		_spawn_one()
	_los_step()
	if seen:
		seen_t = 0.0
		last_seen = target
	else:
		seen_t += delta
		if seen_t >= LOSE_S[stars - 1]:
			_drop_star()
	if stars > 0:
		_check_catch(delta)
	_update_search()


func _los_step() -> void:
	var n: int = observers.size()
	if n == 0:
		seen = false
		return
	if _ex_dirty or _ex.is_empty():
		_ex = _ray_exclusions()
		_rq.exclude = _ex
		_ex_dirty = false
	var chest: Vector3 = target + Vector3(0.0, CHEST_Y, 0.0)
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for k: int in mini(RAYS_PER_TICK, n):
		_ray_i = (_ray_i + 1) % n
		var o: Node3D = observers[_ray_i]
		var v: bool = _sight(o, chest, space)
		_sees[o.get_instance_id()] = v
		if "sees_player" in o:
			o.set("sees_player", v)
	seen = false
	for o2: Node3D in observers:
		if bool(_sees.get(o2.get_instance_id(), false)):
			seen = true
			break


## One line-of-sight ray of the round robin (the shared query, its exclusions already set).
func _sight(o: Node3D, chest: Vector3, space: PhysicsDirectSpaceState3D) -> bool:
	if o is Officer:
		if (o as Officer).is_down():
			return false
	elif o.has_method("is_down") and bool(o.call("is_down")):
		return false
	var eye: Vector3 = o.global_position + Vector3(0.0, EYE_Y, 0.0)
	if eye.distance_squared_to(chest) > SIGHT_R * SIGHT_R:
		return false
	_rq.from = eye
	_rq.to = chest
	return space.intersect_ray(_rq).is_empty()


## Line of sight from an observer's eyes to the player's chest within SIGHT_R (a knocked-out officer sees nothing). The
## officers, the player, the bike and the traffic do not block it; buildings and people do.
func can_see(o: Node3D, ex: Array[RID] = []) -> bool:
	if o.has_method("is_down") and bool(o.call("is_down")):
		return false
	var eye: Vector3 = o.global_position + Vector3(0.0, EYE_Y, 0.0)
	var chest: Vector3 = target_pos() + Vector3(0.0, CHEST_Y, 0.0)
	if eye.distance_to(chest) > SIGHT_R or not is_inside_tree():
		return false
	var rq := PhysicsRayQueryParameters3D.create(eye, chest)
	rq.exclude = ex if not ex.is_empty() else _ray_exclusions()
	rq.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(rq).is_empty()


func _ray_exclusions() -> Array[RID]:
	var ex: Array[RID] = []
	for ob: Variant in observers:
		if ob is CollisionObject3D:
			ex.append((ob as CollisionObject3D).get_rid())
	if player:
		ex.append(player.get_rid())
	if roam and roam.get("bike") is CollisionObject3D:
		ex.append((roam.get("bike") as CollisionObject3D).get_rid())
	if traffic:
		for b: Variant in traffic.bodies():
			ex.append((b as CollisionObject3D).get_rid())
	return ex


func _drop_star() -> void:
	stars -= 1
	heat = STAR_HEAT[stars - 1] if stars > 0 else 0.0
	seen_t = 0.0
	_on_stars_changed()
	if stars == 0:
		cleared.emit()


func _on_stars_changed() -> void:
	if stars == 0:
		three_star_t = 0.0
		second_wave = false
		_spawn_budget = 0
		catch_t = 0.0
		_release_bikes()                     # once, on the drop to 0 stars
	refresh_hud()
	stars_changed.emit(stars)


## Stars on ViceHUD (vice) or the classic row under the clock, with the campus / street label. Hidden while busted or in
## community service (state != "free") and, for the classic row, while the map is open.
func refresh_hud() -> void:
	var campus: bool = is_campus(target_pos())
	_was_campus = 1 if campus else 0
	var label: String = LABEL_CAMPUS if campus else LABEL_STREET
	var shown: int = stars if state == "free" else 0
	if vice_hud:
		vice_hud.set_stars(shown, label)
	if classic_stars:
		classic_stars.set_filled(shown)
		classic_stars.visible = shown > 0 and not hud_hidden and not ViceHUD.style_active()


## The search circle (x, z, radius) while nobody has seen the player for CIRCLE_AFTER_S; ZERO otherwise.
func search_area() -> Vector3:
	if state == "free" and stars > 0 and not seen and seen_t >= CIRCLE_AFTER_S:
		return Vector3(last_seen.x, last_seen.z, SEARCH_R[stars - 1])
	return Vector3.ZERO


func _update_search() -> void:
	if vice_hud and vice_hud.radar:
		vice_hud.radar.search = search_area()


func _prune() -> void:
	var gone: bool = false
	for i: int in range(observers.size() - 1, -1, -1):
		var o: Variant = observers[i]
		if not is_instance_valid(o) or not (o as Node).is_inside_tree():
			observers.remove_at(i)
			gone = true
	if not gone:
		return
	for i: int in range(_officers.size() - 1, -1, -1):
		if not is_instance_valid(_officers[i]) or not _officers[i].is_inside_tree():
			_officers.remove_at(i)
	var keep: Dictionary = {}
	for o2: Node3D in observers:
		var id: int = o2.get_instance_id()
		if _sees.has(id):
			keep[id] = _sees[id]
	_sees = keep
	_ex_dirty = true


## Empty the level (end of community service; tests).
func clear() -> void:
	heat = 0.0
	stars = 0
	seen = false
	seen_t = 0.0
	_on_stars_changed()                      # also resets the second wave and releases the bikes
	_update_search()
	cleared.emit()


## A copy of the live officers (safe to iterate while despawning).
func officers() -> Array:
	var out: Array = []
	for o: Officer in _officers:
		if is_instance_valid(o):
			out.append(o)
	return out


func count_role(role: String) -> int:
	var n: int = 0
	for o: Officer in _officers:
		if is_instance_valid(o) and o.role == role:
			n += 1
	return n


func search_radius() -> float:
	return SEARCH_R[clampi(stars, 1, 3) - 1]


## Spawn an officer (role "guard" | "mr_t" | "police") at `at` or at a free spot 25-45 m from the player, out of view when
## possible. null when the cap is reached or no spot is found.
func spawn_officer(role: String, at: Variant = null) -> Officer:
	if _officers.size() >= MAX_OFFICERS:
		return null
	var pos: Variant = at if at is Vector3 else _spawn_point(role)
	if not (pos is Vector3):
		return null
	var o := Officer.new()
	o.name = "Officer_%s_%d" % [role, officers_spawned]
	o.setup(role, self, player, 4000 + officers_spawned)
	o.position = (pos as Vector3) + Vector3(0.0, 0.05, 0.0)   # before add_child: never enter the tree at the origin
	add_child(o)
	o.knocked.connect(_on_officer_knocked)
	observers.append(o)
	_officers.append(o)
	_ex_dirty = true
	officers_spawned += 1
	if player and player.cam_ray:
		player.cam_ray.add_exception(o)
	var b: Variant = roam.get("bike") if roam else null
	if b is Node and (b as Node).get("spring_arm"):
		((b as Node).get("spring_arm") as SpringArm3D).add_excluded_object(o.get_rid())
	return o


func _on_officer_knocked(o: Officer) -> void:
	add_heat(OFFICER_KO_HEAT, o.global_position, "officer")


func _spawn_point(role: String) -> Variant:
	var near: Vector3 = target_pos()
	if spawn_fn.is_valid():
		return spawn_fn.call(role, near)
	for k: int in 12:
		var a: float = _rng.randf() * TAU
		var r: float = _rng.randf_range(SPAWN_MIN, SPAWN_MAX)
		var q: Vector3 = near + Vector3(cos(a) * r, 0.0, sin(a) * r)
		if k < 8 and _in_view(q):
			continue
		if roam and roam.has_method("find_free_spot"):
			var s: Variant = roam.call("find_free_spot", q, near.y, 3)
			if s is Vector3:
				return s
		else:
			return q
	return null


func _in_view(p: Vector3) -> bool:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam != null and cam.global_position.distance_to(p) < 120.0 and cam.is_position_in_frustum(p + Vector3(0.0, 1.0, 0.0))


## Once per MAINTAIN_S: officers far away and out of view leave; campus (inside the plot): guards up to GUARDS[stars] and
## Mr.T from 2 stars; streets and residential: police bikes up to BIKES[stars] (+3 for the second wave after 30 s at
## 3 stars), counting the ones on their way and the officers already off their bikes. At most SPAWNS_PER_MAINTAIN per call.
## Also: officers pinned for STUCK_REPLACE_S out of view (or STUCK_FORCE_S anywhere) are replaced, the campus / street
## HUD label follows the player across the plot border, and the exclusion list of the sight rays is refreshed. The spawns
## themselves happen one per physics frame (_spawn_one) so a maintain never costs two ring searches in one frame.
func _maintain() -> void:
	var p: Vector3 = target
	_ex_dirty = true
	for o: Officer in officers():
		var far: bool = WeaponMath.flat(o.global_position, p) > DESPAWN_R
		var stuck: bool = o.can_catch() and o.stuck_s >= STUCK_REPLACE_S
		if (far or stuck) and (o.stuck_s >= STUCK_FORCE_S or not _in_view(o.global_position)):
			if stuck and not far:
				officers_replaced += 1
			_despawn(o)
	_trim_surplus()
	var campus: int = 1 if is_campus(p) else 0
	if campus != _was_campus:
		refresh_hud()
	if spawning:
		_spawn_budget = SPAWNS_PER_MAINTAIN


## After a star drop: guards beyond GUARDS[stars] (and Mr.T below 2 stars) leave when out of view.
func _trim_surplus() -> void:
	var extra_g: int = count_role("guard") - GUARDS[stars - 1]
	var extra_t: int = count_role("mr_t") - (1 if stars >= 2 else 0)
	if extra_g <= 0 and extra_t <= 0:
		return
	for o: Officer in officers():
		if o.role == "guard" and extra_g > 0 and not _in_view(o.global_position):
			_despawn(o)
			extra_g -= 1
		elif o.role == "mr_t" and extra_t > 0 and not _in_view(o.global_position):
			_despawn(o)
			extra_t -= 1


## One spawn of the current maintain budget: campus guards up to GUARDS[stars], then Mr.T from 2 stars; streets:
## police bikes up to BIKES[stars] (+ the second wave), never more police than the free officer slots.
func _spawn_one() -> void:
	_spawn_budget -= 1
	if is_campus(target):
		if count_role("guard") < GUARDS[stars - 1]:
			if spawn_officer("guard") == null:
				_spawn_budget = 0
		elif stars >= 2 and count_role("mr_t") == 0:
			spawn_officer("mr_t")
			_spawn_budget = 0
		else:
			_spawn_budget = 0
		return
	_prune_pending()
	var police: int = count_role("police")
	var free_slots: int = MAX_OFFICERS - (_officers.size() - police)
	var want: int = mini(BIKES[stars - 1] + (BIKES[2] if second_wave else 0), free_slots)
	if police + pending_bikes.size() < want:
		if not _send_bike():
			_spawn_budget = 0
	else:
		_spawn_budget = 0


func _despawn(o: Officer) -> void:
	observers.erase(o)
	_officers.erase(o)
	_ex_dirty = true
	if _catch_o == o:
		_catch_o = null
		catch_t = 0.0
	if not is_instance_valid(o):
		return
	_sees.erase(o.get_instance_id())
	if player and player.cam_ray:
		player.cam_ray.remove_exception(o)
	var b: Variant = roam.get("bike") if roam else null
	if b is Node and (b as Node).get("spring_arm"):
		((b as Node).get("spring_arm") as SpringArm3D).remove_excluded_object(o.get_rid())
	o.queue_free()


## No stars: every officer gives up and walks away; those out of view vanish at once, the rest after GIVE_UP_DESPAWN_S.
func _retire(delta: float) -> void:
	var list: Array = officers()
	if list.is_empty():
		_give_up_t = 0.0
		return
	_give_up_t += delta
	for o: Officer in list:
		o.give_up()
		if _give_up_t >= GIVE_UP_DESPAWN_S or not _in_view(o.global_position):
			_despawn(o)


## A police bike from the traffic, or (no traffic / no lane spot) a police officer on foot (plan P9).
func _send_bike() -> bool:
	if traffic:
		var idx: int = traffic.spawn_police()
		if idx >= 0:
			pending_bikes.append(idx)
			bikes_sent += 1
			_ex_dirty = true                     # a police body may have just been built
			return true
	return spawn_officer("police") != null


func _prune_pending() -> void:
	for i: int in range(pending_bikes.size() - 1, -1, -1):
		if traffic == null or not traffic.is_police_riding(pending_bikes[i]):
			pending_bikes.remove_at(i)


func _on_police_arrived(idx: int, at: Vector3) -> void:
	pending_bikes.erase(idx)
	if state != "free" or stars == 0:
		if traffic:
			traffic.release_police()         # arrived after the level ended: nobody gets off, the rest stop
		return
	var spot: Variant = roam.call("find_free_spot", at, at.y, 3) if roam and roam.has_method("find_free_spot") else at
	var o: Officer = spawn_officer("police", spot if spot is Vector3 else at)
	if o:
		o.bike_idx = idx


func _release_bikes() -> void:
	pending_bikes.clear()
	if traffic:
		traffic.release_police()


## Busted (spec section 5): an officer able to grab stays within CATCH_R of the player for CATCH_S while the player is on his
## feet, or reaches a knocked-down player (the comic tackle). Never while riding (player hidden) or with catch_enabled off.
func _check_catch(delta: float) -> void:
	if not catch_enabled or player == null or not player.visible:
		catch_t = 0.0
		return
	var p: Vector3 = player.global_position
	var near: Officer = null
	var best: float = CATCH_R
	for o: Officer in _officers:
		if not is_instance_valid(o) or not o.can_catch():
			continue
		var d: float = WeaponMath.flat(o.global_position, p)
		if d <= best:
			best = d
			near = o
	if near == null:
		catch_t = 0.0
		_catch_o = null
		return
	if near != _catch_o:
		_catch_o = near                      # another officer took the closest slot: his own 1.5 s
		catch_t = 0.0
	if player.is_knocked_down():
		bust(near)
		return
	catch_t += delta
	if catch_t >= CATCH_S - 1e-6:
		bust(near)


## Freeze, "BỊ TÓM!" stamp, then the busted cutscene (A1 CinePlayer through FreeRoam.play_cinematic), then community service.
func bust(o: Officer) -> void:
	if state != "free":
		return
	state = "stamp"
	busts += 1
	catch_t = 0.0
	refresh_hud()                            # stars and search circle off during the stamp, cutscene and chore
	_update_search()
	catcher = o.role if o else "guard"
	bust_on_campus = is_campus(target_pos())
	busted.emit(catcher)
	_set_cine_flag(true)                 # Esc must not open the pause menu during the stamp
	if is_inside_tree():
		get_tree().paused = true
	stamp = BustedStamp.new()
	stamp.name = "BustedStamp"
	stamp.manual = stamp_manual
	add_child(stamp)
	stamp.done.connect(_on_stamp_done, CONNECT_ONE_SHOT)


func _on_stamp_done() -> void:
	stamp = null
	state = "cutscene"
	var tl: CineTimeline = (load(BUSTED_TIMELINE) as GDScript).new()
	tl.set("catcher", catcher)
	tl.build()
	var opts: Dictionary = cine_opts.duplicate()
	opts["xf"] = Transform3D(Basis(Vector3.UP, player.facing_yaw()), player.global_position)
	var cp: Variant = roam.call("play_cinematic", tl, opts) if roam and roam.has_method("play_cinematic") else null
	if cp == null:
		_set_cine_flag(false)
		if is_inside_tree():
			get_tree().paused = false
		_start_service()
		return
	roam.connect("cinematic_finished", _on_cine_done, CONNECT_ONE_SHOT)


func _on_cine_done(_slot: String, _skipped: bool) -> void:
	_start_service()


## Community service (spec section 5): officers leave, the chore starts where the catch happened (campus parking or the
## Nguyễn Xiển verge); weapons and the bike stay locked (state "service") until it is done.
func _start_service() -> void:
	_clear_officers()
	state = "service"
	service = CommunityService.new()
	service.name = "CommunityService"
	add_child(service)
	service.start(player, roam, md, bust_on_campus)
	service.completed.connect(_on_service_done, CONNECT_ONE_SHOT)
	service_started.emit(bust_on_campus)


## Chore done: the wanted level is cleared, the weapons are free again, the player stands beside his bike.
func _on_service_done() -> void:
	service = null
	state = "free"
	clear()                                  # refresh_hud: back to 0 stars shown
	if roam and roam.has_method("place_beside_bike"):
		roam.call("place_beside_bike")


func _clear_officers() -> void:
	for o: Officer in officers():
		_despawn(o)
	catch_t = 0.0
	_release_bikes()


func _set_cine_flag(on: bool) -> void:
	var sm: Node = get_node_or_null("/root/StageManager")
	if sm:
		sm.set("cinematic_active", on)
