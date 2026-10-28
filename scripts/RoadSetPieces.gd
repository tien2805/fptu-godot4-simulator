# File: res://scripts/RoadSetPieces.gd
# Stage 1 set pieces of the Wave 2 content pass (master plan 2026-10-29 Q4b, plan 2026-10-29-w2-early.md Task 2), built
# by RoadEvents.setup on the real BE6 -> FPTU route (RoadManager.route_marks offsets) and run in the story Day 0 race and
# the standalone stage alike:
#   - BUS CUT-IN (between Hải Đăng and Cầu Vồng 5): a bus waits at the right kerb; BUS_BLINK_M before it the amber
#     blinkers flash and it honks (the telegraph, about 2 s at full speed), at bus_trigger_m() it pulls into the lane
#     (preview cut on it), rolls ahead BUS_DRIVE_M and goes back to the kerb. It is a slipstream vehicle while it drives.
#   - FLOODED STREET "đường ngập" (the signature, near the end of Nguyễn Văn Tăng): FLOOD_LEN m of murky animated water
#     over the carriageway, deeper along both kerbs (DEEP_W m, darker), four ranks of stalled bikes with one gap each at
#     alternating sides (the lane to pick), a warning sign and a preview cut before it. In the water the bike's speed is
#     pulled down to flood_cap() (the deep pockets lower), it throws spray behind (speed-scaled particles) and a splash
#     burst on the way in and on every deep pocket.
#   - TRAFFIC JAM at the start of Nguyễn Văn Tăng (the wide part, before the rain and the trucks): JAM_RANKS ranks of
#     stopped cars (brake lights on) across the road, a narrow kerb squeeze on the right of every rank and an inner gap in
#     the first and last rank (the weave); honking on the way in.
# Every tuned number goes through Difficulty.pick(normal, easy) (Thường / Dễ). Banners go out through RoadEvents.banner.
# Tests read the public state: bus_state, bus_at, flood_from / flood_to, in_flood, deep, jam_from / jam_to, cuts, ranks.
class_name RoadSetPieces
extends Node3D

const BUS_BLINK_M: float = 95.0
const BUS_PULL_S: float = 1.8
const BUS_DRIVE_M: float = 120.0
const BUS_BACK_S: float = 2.2
const BUS_KERB_GAP: float = 1.45            # bus centre this far inside the right kerb while parked
const FLOOD_LEN: float = 180.0
const FLOOD_STEP: float = 4.0
const DEEP_W: float = 1.5
const FLOOD_RANKS: Array[float] = [32.0, 72.0, 112.0, 150.0]
const FLOOD_GAP_SIDE: Array[float] = [0.45, -0.45, 0.15, -0.2]   # gap centre as a fraction of the half width
const STALL_STEP: float = 1.05               # m between stalled bike centres in a rank
const WATER_DECEL: float = 15.0              # m/s^2 the water pulls the speed down to the cap
const JAM_RANKS: int = 3
const JAM_STEP: float = 30.0
const JAM_GAP_AFTER: Array[int] = [0, -1, 0]   # the rank's inner gap after this car (from the right; -1 = only the kerb lane)
const CAR_SPACE: float = 0.3
const CAR_W: float = 1.7
const CAR_L: float = 3.9
const PREVIEW_S: float = 0.6
const WATER_Y: float = 0.29                  # water surface above the route curve (the road top is ~0.25)
const COL_FLOOD := Color("#74B9FF")
const COL_BUS := Color("#FFB300")
const COL_JAM := Color("#FF7F50")
const WATER_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;
uniform vec4 shallow : source_color = vec4(0.46, 0.43, 0.33, 0.8);
uniform vec4 deep_col : source_color = vec4(0.17, 0.2, 0.19, 0.92);
varying float depth_v;
varying vec3 wpos;
void vertex() {
	depth_v = COLOR.r;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float t = TIME;
	float a = sin(wpos.x * 1.7 + t * 1.3);
	float b = sin(wpos.z * 2.3 - t * 1.1);
	float c = sin((wpos.x + wpos.z) * 3.1 + t * 2.1);
	vec4 col = mix(shallow, deep_col, depth_v);
	ALBEDO = col.rgb * (0.9 + 0.06 * (a + b) + 0.04 * c);
	ALPHA = col.a;
	ROUGHNESS = 0.06;
	SPECULAR = 0.75;
	vec3 n_world = normalize(vec3(0.09 * cos(wpos.x * 1.7 + t * 1.3) + 0.05 * c, 1.0, 0.09 * cos(wpos.z * 2.3 - t * 1.1)));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
}
"""

var curve: Curve3D
var track_len: float = 1.0
var bike: CharacterBody3D
var road_manager: Node = null
var events: Node = null
var marks: Dictionary = {}
var cuts: int = 0
var ranks: Array = []                         # flood ranks: [{"offset", "gap" (lateral centre), "free" (m)}]
# bus
var bus_at: float = 1150.0
var bus_state: String = "wait"                # wait | blink | pull | drive | back | done
var bus: AnimatableBody3D
var bus_s: float = 0.0
var bus_lat: float = 0.0
var bus_lat_from: float = 0.0
var bus_lat_to: float = 0.0
var bus_t: float = 0.0
var bus_v: float = 0.0
var _blinkers: Array[MeshInstance3D] = []
var _blink_t: float = 0.0
# flood
var flood_from: float = 3940.0
var flood_to: float = 4120.0
var in_flood: bool = false
var deep: bool = false
var flood_entries: int = 0
var deep_splashes: int = 0
var flood_marker: Node3D
var spray: CPUParticles3D
var splash: CPUParticles3D
var _flood_warned: bool = false
var _flood_cut: bool = false
# jam
var jam_from: float = 4360.0
var jam_to: float = 4430.0
var jam_cars: Array[Node3D] = []
var _jam_warned: bool = false


func setup(path: Path3D, bike_body: CharacterBody3D, manager: Node, ev: Node) -> void:
	curve = path.curve
	track_len = curve.get_baked_length()
	bike = bike_body
	road_manager = manager
	events = ev
	if manager:
		var m: Variant = manager.get("route_marks")
		if m is Dictionary:
			marks = m
	var hd: float = _mark("hai_dang_end", 150.0)
	var cv5: float = _mark("cau_vong_5_start", 470.0)
	bus_at = lerpf(hd, cv5, 0.62) if cv5 > hd + 200.0 else hd + 260.0
	var nvt_end: float = _mark("nvt_end", -1.0)
	flood_from = (nvt_end - 260.0) if nvt_end > 0.0 else _mark("nvt_start", 1035.0) + 1150.0
	flood_to = flood_from + FLOOD_LEN
	jam_from = _mark("nvt_start", 1035.0) + 150.0         # the wide (8 m) Nguyễn Văn Tăng, before the rain and the trucks
	jam_to = jam_from + JAM_STEP * float(JAM_RANKS - 1) + CAR_L
	_build_bus()
	_build_flood()
	_build_jam()


## Difficulty-tuned numbers (Thường, Dễ).
static func bus_trigger_m() -> float:
	return float(Difficulty.pick(40.0, 58.0))     # pulls out this far ahead of the bike (Dễ: more time to react)


static func bus_speed() -> float:
	return float(Difficulty.pick(7.5, 9.0))


static func water_k() -> float:
	return float(Difficulty.pick(0.5, 0.62))      # cap = max speed x this in the water


static func deep_k() -> float:
	return float(Difficulty.pick(0.3, 0.44))      # ... and in a deep kerb pocket


static func stall_gap() -> float:
	return float(Difficulty.pick(2.0, 2.7))       # free width (m, edge to edge) of a rank's gap


static func jam_squeeze() -> float:
	return float(Difficulty.pick(1.5, 2.0))       # kerb lane (m) between the last car and the kerb


static func jam_gap() -> float:
	return float(Difficulty.pick(1.8, 2.4))       # free width of a rank's inner gap


func _mark(key: String, fallback: float) -> float:
	var v: float = float(marks.get(key, -1.0))
	return v if v >= 0.0 else fallback


func _hw(offset: float) -> float:
	if road_manager and road_manager.has_method("half_width_at"):
		return float(road_manager.call("half_width_at", offset))
	return 7.0


func _xf(offset: float) -> Transform3D:
	return curve.sample_baked_with_rotation(clampf(offset, 0.0, track_len - 0.1))


func _at(offset: float, lateral: float, up: float = 0.25) -> Vector3:
	var xf: Transform3D = _xf(offset)
	return xf.origin + xf.basis.x * lateral + Vector3(0.0, up, 0.0)


func _banner(text: String, col: Color, secs: float) -> void:
	if events:
		events.emit_signal("banner", text, col, secs)


func _sfx(cue: String, db: float = 0.0, pitch: float = 1.0) -> void:
	var fx: Node = get_node_or_null("/root/GameFX")
	if fx and fx.has_method("play_sfx"):
		fx.call("play_sfx", cue, db, pitch)


## A director preview cut on `target` (readability rule); counted even without a director (tests).
func _preview(target: Node3D) -> void:
	cuts += 1
	var d: CameraDirector = CameraDirector.live()
	if d != null and target != null and target.is_inside_tree():
		d.preview_cut(target, PREVIEW_S)


func _shake(amount: float) -> void:
	if bike and bike.has_method("add_camera_shake"):
		bike.call("add_camera_shake", amount)


static func _lens(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m


static func _box_mesh(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _sign(parent: Node3D, text: String, col: Color, y: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 40
	l.outline_size = 12
	l.modulate = col
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(0.0, y, 0.0)
	parent.add_child(l)
	return l


# ---------------------------------------------------------------------------
# BUS CUT-IN
# ---------------------------------------------------------------------------
func _build_bus() -> void:
	bus = AnimatableBody3D.new()
	bus.name = "CutInBus"
	bus.sync_to_physics = false
	bus.add_to_group("traffic_obstacle")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.5, 2.8, 7.5)
	cs.shape = bs
	cs.position = Vector3(0.0, 1.4, 0.0)
	bus.add_child(cs)
	add_child(bus)
	PropBuilder.build_bus(bus, true, true)
	PlayerBike.attach_near_miss_tag(bus, Vector3(2.5, 2.8, 7.5), 1.4)
	var amber: StandardMaterial3D = _lens(COL_BUS, 3.0)
	for z: float in [-3.6, 3.6]:   # left side, front and rear: the side it pulls toward
		var b: MeshInstance3D = _box_mesh(bus, Vector3(0.08, 0.2, 0.34), Vector3(-1.29, 0.95, z), amber)
		b.visible = false
		_blinkers.append(b)
	_reset_bus()


func _reset_bus() -> void:
	bus_state = "wait"
	bus_s = bus_at
	bus_lat = _hw(bus_at) - BUS_KERB_GAP
	bus_v = 0.0
	_place_bus(0.0)
	for b: MeshInstance3D in _blinkers:
		b.visible = false


func _place_bus(yaw_off: float) -> void:
	var xf: Transform3D = _xf(bus_s)
	var basis: Basis = xf.basis * Basis(Vector3.UP, yaw_off)
	bus.global_transform = Transform3D(basis, xf.origin + xf.basis.x * bus_lat + Vector3(0.0, 0.25, 0.0))


func _tick_bus(dt: float, off: float) -> void:
	var yaw_off: float = 0.0
	match bus_state:
		"wait":
			if off > bus_at - BUS_BLINK_M and off < bus_at:
				bus_state = "blink"
				_sfx("beep", -5.0, 0.6)
		"blink":
			if off > bus_at - bus_trigger_m():
				bus_state = "pull"
				bus_t = 0.0
				bus_lat_from = bus_lat
				bus_lat_to = _hw(bus_at) * 0.05
				bus.add_to_group("slipstream_vehicle")
				_preview(bus)
				_sfx("beep", -2.0, 0.55)
				_banner("XE BUÝT TẠT ĐẦU! 'Buýt là vua đường phố!' VƯỢT TRÁI HOẶC NÚP GIÓ!", COL_BUS, 2.0)
			elif off > bus_at + 10.0:
				bus_state = "done"            # the bike passed it before it moved
		"pull":
			bus_t += dt
			var u: float = clampf(bus_t / BUS_PULL_S, 0.0, 1.0)
			var e: float = u * u * (3.0 - 2.0 * u)
			bus_v = bus_speed() * u
			bus_s += bus_v * dt
			bus_lat = lerpf(bus_lat_from, bus_lat_to, e)
			yaw_off = -sin(u * PI) * 0.18   # the nose swings out
			if u >= 1.0:
				bus_state = "drive"
		"drive":
			bus_v = bus_speed()
			bus_s += bus_v * dt
			bus_lat = bus_lat_to
			if bus_s > bus_at + BUS_DRIVE_M:
				bus_state = "back"
				bus_t = 0.0
				bus_lat_from = bus_lat
				bus_lat_to = _hw(bus_s) - BUS_KERB_GAP
		"back":
			bus_t += dt
			var u2: float = clampf(bus_t / BUS_BACK_S, 0.0, 1.0)
			bus_v = bus_speed() * (1.0 - u2)
			bus_s += bus_v * dt
			bus_lat = lerpf(bus_lat_from, bus_lat_to, u2 * u2 * (3.0 - 2.0 * u2))
			yaw_off = sin(u2 * PI) * 0.12
			if u2 >= 1.0:
				bus_state = "done"
				bus.remove_from_group("slipstream_vehicle")
		_:
			return
	if bus_state in ["blink", "pull", "back"]:
		_blink_t += dt
		var on: bool = fmod(_blink_t, 0.4) < 0.2
		for b: MeshInstance3D in _blinkers:
			b.visible = on
	else:
		for b: MeshInstance3D in _blinkers:
			b.visible = false
	_place_bus(yaw_off)


# ---------------------------------------------------------------------------
# FLOODED STREET
# ---------------------------------------------------------------------------
func _build_flood() -> void:
	var root := Node3D.new()
	root.name = "Flood"
	add_child(root)
	# the water: rows every FLOOD_STEP m, four points across (kerb, deep edge, deep edge, kerb), depth in COLOR.r
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: int = int(ceil(FLOOD_LEN / FLOOD_STEP)) + 1
	var cols: int = 4
	for r: int in rows:
		var o: float = flood_from + minf(float(r) * FLOOD_STEP, FLOOD_LEN)
		var hw: float = _hw(o)
		var lats: Array[float] = [-hw - 0.3, -hw + DEEP_W, hw - DEEP_W, hw + 0.3]
		var depth: Array[float] = [1.0, 0.0, 0.0, 1.0]
		for c: int in cols:
			st.set_color(Color(depth[c], 0.0, 0.0, 1.0))
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(float(c) / 3.0, float(r) / float(rows - 1)))
			st.add_vertex(_at(o, lats[c], WATER_Y))
	for r: int in rows - 1:
		for c: int in cols - 1:
			var i0: int = r * cols + c
			var i1: int = i0 + 1
			var i2: int = i0 + cols
			var i3: int = i2 + 1
			st.add_index(i0)
			st.add_index(i2)
			st.add_index(i1)
			st.add_index(i1)
			st.add_index(i2)
			st.add_index(i3)
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = st.commit()
	water.top_level = true
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sh := Shader.new()
	sh.code = WATER_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_meta("vice_done", true)
	water.material_override = mat
	root.add_child(water)
	water.global_transform = Transform3D.IDENTITY
	# warning sign at the right kerb before the water
	var sign_root := Node3D.new()
	root.add_child(sign_root)
	sign_root.global_position = _at(flood_from - 70.0, _hw(flood_from - 70.0) + 1.2, 0.25)
	var pole_m := StandardMaterial3D.new()
	pole_m.albedo_color = Color("#636E72")
	_box_mesh(sign_root, Vector3(0.1, 2.2, 0.1), Vector3(0.0, 1.1, 0.0), pole_m)
	_box_mesh(sign_root, Vector3(1.2, 0.9, 0.06), Vector3(0.0, 2.3, 0.0), _lens(Color("#F1C40F"), 0.8))
	_sign(sign_root, "ĐƯỜNG NGẬP\nĐI CHẬM", Color("#FFE66D"), 3.3)
	# stalled bikes, one gap per rank
	var gap_free: float = stall_gap()
	var bike_mats: Array[Color] = [Color("#C8CCD2"), Color("#D63031"), Color("#0984E3"), Color("#2D3436"), Color("#FDCB6E")]
	var k: int = 0
	for ri: int in FLOOD_RANKS.size():
		var o: float = flood_from + FLOOD_RANKS[ri]
		var hw: float = _hw(o)
		var g: float = clampf(FLOOD_GAP_SIDE[ri] * hw, -hw + DEEP_W + gap_free * 0.5, hw - DEEP_W - gap_free * 0.5)
		ranks.append({"offset": o, "gap": g, "free": gap_free})
		var half_gap: float = gap_free * 0.5 + 0.35   # bike centres stay this far from the gap centre
		var lat: float = -hw + 0.4
		var rider_done: bool = false
		while lat <= hw - 0.4:
			if absf(lat - g) >= half_gap:
				var jitter: float = float((k * 37) % 7) * 0.08 - 0.24
				_stalled_bike(root, o + jitter, lat, bike_mats[k % bike_mats.size()], (float(k % 5) - 2.0) * 0.12, not rider_done and absf(lat - g) < half_gap + 1.2)
				if absf(lat - g) < half_gap + 1.2:
					rider_done = true
				k += 1
			lat += STALL_STEP
	flood_marker = Node3D.new()
	flood_marker.name = "FloodMarker"
	root.add_child(flood_marker)
	flood_marker.global_position = _at(ranks[0]["offset"], float(ranks[0]["gap"]), 0.25)
	_build_spray()


func _stalled_bike(root: Node3D, o: float, lat: float, col: Color, yaw: float, rider: bool) -> void:
	var body := StaticBody3D.new()
	body.name = "StalledBike"
	body.add_to_group("traffic_obstacle")
	body.add_to_group("stalled_bike")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.7, 1.1, 1.9)
	cs.shape = bs
	cs.position = Vector3(0.0, 0.55, 0.0)
	body.add_child(cs)
	var vis: Node3D = CineFX.build_prop("scooter", {"color": col})
	body.add_child(vis)
	root.add_child(body)
	var xf: Transform3D = _xf(o)
	body.global_transform = Transform3D(xf.basis * Basis(Vector3.UP, yaw), _at(o, lat, 0.25))
	PlayerBike.attach_near_miss_tag(body, Vector3(0.7, 1.1, 1.9), 0.55)
	if rider:   # the owner pushing the drowned bike, trousers rolled up
		var p: Node3D = CharacterBuilder.build({"preset": "casual", "seed": 900 + int(o) % 97, "name": "StalledRider"})
		body.add_child(p)
		p.position = Vector3(0.55, 0.0, 0.2)
		p.rotation.y = PI * 0.08
		_sign(p, ["Chết máy rồi!", "Ngập tới yên luôn...", "Đẩy bộ thôi!"][int(o) % 3], Color("#DFE6E9"), 2.15).font_size = 28


func _build_spray() -> void:
	var dot := QuadMesh.new()
	dot.size = Vector2(0.16, 0.16)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.82, 0.88, 0.92, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.set_meta("vice_done", true)
	dot.material = m
	spray = CPUParticles3D.new()
	spray.name = "FloodSpray"
	spray.emitting = false
	spray.amount = 64
	spray.lifetime = 0.7
	spray.local_coords = false
	spray.mesh = dot
	spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	spray.emission_box_extents = Vector3(0.45, 0.05, 0.15)
	spray.direction = Vector3(0.0, 0.8, 1.0)   # up and back (the bike faces -Z)
	spray.spread = 38.0
	spray.gravity = Vector3(0.0, -9.8, 0.0)
	spray.initial_velocity_min = 2.0
	spray.initial_velocity_max = 4.0
	spray.scale_amount_min = 0.7
	spray.scale_amount_max = 1.6
	spray.position = Vector3(0.0, 0.15, 0.75)
	bike.add_child(spray)
	splash = CPUParticles3D.new()
	splash.name = "FloodSplash"
	splash.emitting = false
	splash.one_shot = true
	splash.explosiveness = 0.95
	splash.amount = 40
	splash.lifetime = 0.9
	splash.local_coords = false
	splash.mesh = dot
	splash.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	splash.emission_sphere_radius = 0.5
	splash.direction = Vector3.UP
	splash.spread = 70.0
	splash.gravity = Vector3(0.0, -9.8, 0.0)
	splash.initial_velocity_min = 3.0
	splash.initial_velocity_max = 6.5
	splash.scale_amount_min = 1.0
	splash.scale_amount_max = 2.2
	splash.position = Vector3(0.0, 0.2, -0.2)
	bike.add_child(splash)


func _burst() -> void:
	if splash:
		splash.restart()
		splash.emitting = true


## The speed cap (m/s) in the water at this spot: lower in a deep kerb pocket.
func flood_cap(is_deep: bool = false) -> float:
	var top: float = float(bike.get("max_speed_ms")) if bike else 22.5
	return top * (deep_k() if is_deep else water_k())


func _tick_flood(dt: float, off: float, lat: float) -> void:
	if not _flood_warned and off > flood_from - 110.0 and off < flood_from:
		_flood_warned = true
		_banner("PHÍA TRƯỚC NGẬP NẶNG! 'Mưa 15 phút, đường thành sông!' CHỌN KHE GIỮA XE CHẾT MÁY, NÉ SÁT LỀ!", COL_FLOOD, 2.6)
	if not _flood_cut and off > flood_from - 60.0 and off < flood_from:
		_flood_cut = true
		_preview(flood_marker)
	var hw: float = _hw(off)
	var inside: bool = off >= flood_from and off <= flood_to and absf(lat) <= hw + 0.6
	if inside and not in_flood:
		flood_entries += 1
		_burst()
		_shake(0.35)
		_sfx("whoosh", -2.0, 0.45)
		_banner("ĐƯỜNG NGẬP! Bánh xe rẽ sóng...", COL_FLOOD, 1.4)
	elif not inside and in_flood and off > flood_to:
		_banner("THOÁT KHỎI 'SÔNG' NGUYỄN VĂN TĂNG! VÍT GA!", Color("#2ECC71"), 1.4)
	in_flood = inside
	var was_deep: bool = deep
	deep = inside and absf(lat) > hw - DEEP_W
	if deep and not was_deep:
		deep_splashes += 1
		_burst()
		_shake(0.3)
		_sfx("whoosh", -3.0, 0.4)
	var speed: float = absf(float(bike.get("current_speed_ms")))
	if inside:
		var cap: float = flood_cap(deep)
		var cur: float = float(bike.get("current_speed_ms"))
		if cur > cap:
			bike.set("current_speed_ms", move_toward(cur, cap, WATER_DECEL * dt))
	var spraying: bool = inside and speed > 1.5
	if spray.emitting != spraying:
		spray.emitting = spraying
	if spraying:
		spray.initial_velocity_min = 1.5 + speed * 0.18
		spray.initial_velocity_max = 2.5 + speed * 0.32


# ---------------------------------------------------------------------------
# TRAFFIC JAM
# ---------------------------------------------------------------------------
func _build_jam() -> void:
	var root := Node3D.new()
	root.name = "Jam"
	add_child(root)
	var squeeze: float = jam_squeeze()
	var gap_free: float = jam_gap()
	var paints: Array[Color] = [Color("#DFE6E9"), Color("#2D3436"), Color("#C0392B"), Color("#2980B9"), Color("#BDC3C7"), Color("#27AE60")]
	var k: int = 0
	for ri: int in JAM_RANKS:
		var o: float = jam_from + JAM_STEP * float(ri)
		var hw: float = _hw(o)
		var right: float = hw - squeeze                    # right edge of the next car, filled from the kerb lane leftwards
		var n: int = 0
		while right - CAR_W >= -hw - 0.45:
			var x: float = right - CAR_W * 0.5
			_jam_car(root, o + float((k * 13) % 5) * 0.3, x, paints[k % paints.size()], (float(k % 3) - 1.0) * 0.05)
			k += 1
			right -= CAR_W + (gap_free if n == JAM_GAP_AFTER[ri] else CAR_SPACE)
			n += 1
	var hn := Node3D.new()
	root.add_child(hn)
	hn.global_position = _at(jam_from - 6.0, 0.0, 0.25)
	_sign(hn, "KẸT XE!", COL_JAM, 3.2)


func _jam_car(root: Node3D, o: float, lat: float, col: Color, yaw: float) -> void:
	var body := StaticBody3D.new()
	body.name = "JamCar"
	body.add_to_group("traffic_obstacle")
	body.add_to_group("jam_car")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(CAR_W, 1.5, CAR_L)
	cs.shape = bs
	cs.position = Vector3(0.0, 0.75, 0.0)
	body.add_child(cs)
	PropBuilder.build_car(body, col, true)
	root.add_child(body)
	var xf: Transform3D = _xf(o)
	body.global_transform = Transform3D(xf.basis * Basis(Vector3.UP, yaw), _at(o, lat, 0.25))
	PlayerBike.attach_near_miss_tag(body, Vector3(CAR_W, 1.5, CAR_L), 0.75)
	# brake lights on: everyone is stopped
	var red: StandardMaterial3D = _lens(Color("#FF3B30"), 2.2)
	for sx: float in [-0.62, 0.62]:
		_box_mesh(body, Vector3(0.3, 0.14, 0.05), Vector3(sx, 0.85, CAR_L * 0.5 + 0.02), red)
	jam_cars.append(body)


func _tick_jam(off: float) -> void:
	if not _jam_warned and off > jam_from - 90.0 and off < jam_from:
		_jam_warned = true
		_sfx("beep", -6.0, 0.8)
		_banner("KẸT XE ĐẦU NGUYỄN VĂN TĂNG! LUỒN KHE HOẶC LÁCH SÁT LỀ PHẢI!", COL_JAM, 2.2)


# ---------------------------------------------------------------------------
## Called by RoadEvents._process with the bike's route offset (one closest-offset search per frame for both).
func tick(dt: float, off: float) -> void:
	if curve == null or bike == null or not is_instance_valid(bike):
		return
	var xf: Transform3D = _xf(off)
	var lat: float = (bike.global_position - xf.origin).dot(xf.basis.x)
	_tick_bus(dt, off)
	_tick_flood(dt, off, lat)
	_tick_jam(off)
