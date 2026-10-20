# File: res://scripts/RoadEvents.gd
# Sự kiện bất ngờ trên cung đường Vinhomes -> FPTU (Màn 1):
#   - Ổ gà Nguyễn Xiển (random), xe tải hỏng chắn làn trên D2, chó cô Ba chạy qua đường,
#   - Đèn đỏ bất ngờ ở ngã ba trước Cầu Trau Trảu (vượt = CSGT phạt, dừng đúng = thưởng),
#   - Mưa rào SHTP (50%) làm đường trơn, 5 cổng checkpoint có lời thoại hài.
# RoadManager tạo node này sau khi dựng đường; HUDManager nối các signal để cộng/trừ giờ.
class_name RoadEvents
extends Node3D

signal time_penalty(sec: float, msg: String)
signal time_bonus(sec: float, msg: String)
signal banner(text: String, color: Color, duration: float)
signal rain_changed(is_raining: bool)

const LIGHT_OFFSET: float = 778.0
const DOG_OFFSET: float = 470.0

var road_path: Path3D
var player_bike: CharacterBody3D
var curve: Curve3D
var track_len: float = 1.0

var checkpoints: Array[Dictionary] = []
var pothole_cooldowns: Dictionary = {}

# Chó chạy qua đường
var dog_root: Node3D
var dog_area: Area3D
var dog_state: int = 0 # 0 chờ, 1 đang chạy, 2 xong
var dog_t: float = 0.0
var dog_dir: float = 1.0
var dog_xform: Transform3D

# Đèn giao thông
var light_state: String = "off"
var light_timer: float = 0.0
var light_bulbs: Array[MeshInstance3D] = []
var light_penalized: bool = false
var light_rewarded: bool = false
var light_stop_hold: float = 0.0
var cop_bubble: Label3D

# Mưa
var rain_possible: bool = false
var is_raining: bool = false
var rain_done: bool = false
var rain_particles: CPUParticles3D
var world_env: WorldEnvironment

func setup(path: Path3D, bike: CharacterBody3D) -> void:
	road_path = path
	player_bike = bike
	curve = path.curve
	track_len = curve.get_baked_length()
	rain_possible = randf() < 0.5
	_build_potholes()
	_build_broken_trucks()
	_build_dog()
	_build_traffic_light()
	_build_checkpoints()
	_build_rain()

func _xform_at(offset: float) -> Transform3D:
	return curve.sample_baked_with_rotation(clampf(offset, 0.0, track_len - 0.1))

func _place(node: Node3D, offset: float, lateral: float, height: float = 0.25) -> Transform3D:
	var xf: Transform3D = _xform_at(offset)
	node.global_transform = xf
	node.global_position = xf.origin + xf.basis.x * lateral + Vector3(0.0, height, 0.0)
	return xf

# ---------------------------------------------------------------------------
# Ổ GÀ NGUYỄN XIỂN
# ---------------------------------------------------------------------------
func _build_potholes() -> void:
	var mat_hole := StandardMaterial3D.new()
	mat_hole.albedo_color = Color("#15181C")
	mat_hole.roughness = 1.0
	var mat_rim := StandardMaterial3D.new()
	mat_rim.albedo_color = Color("#5D4A2E")
	var offsets: Array[float] = []
	for i: int in range(7):
		offsets.append(randf_range(240.0, 750.0))
	offsets.sort()
	for off: float in offsets:
		var lateral: float = randf_range(-4.8, 4.8)
		var hole := Area3D.new()
		hole.add_to_group("pothole")
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.85
		cyl.height = 0.8
		cs.shape = cyl
		cs.position = Vector3(0.0, 0.3, 0.0)
		hole.add_child(cs)
		var m := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.9
		cm.bottom_radius = 0.9
		cm.height = 0.05
		m.mesh = cm
		m.material_override = mat_hole
		m.position = Vector3(0.0, 0.02, 0.0)
		hole.add_child(m)
		var rim := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.85
		tm.outer_radius = 1.05
		rim.mesh = tm
		rim.material_override = mat_rim
		rim.position = Vector3(0.0, 0.03, 0.0)
		hole.add_child(rim)
		add_child(hole)
		_place(hole, off, lateral, 0.26)
		hole.body_entered.connect(_on_pothole_entered.bind(hole))

func _on_pothole_entered(body: Node3D, hole: Area3D) -> void:
	if body != player_bike:
		return
	var now: float = Time.get_ticks_msec() * 0.001
	if pothole_cooldowns.has(hole) and now - float(pothole_cooldowns[hole]) < 1.5:
		return
	pothole_cooldowns[hole] = now
	if player_bike.has_method("hit_pothole"):
		player_bike.hit_pothole()
	emit_signal("banner", "🕳 Ổ GÀ NGUYỄN XIỂN! 'Đường này 3 năm chưa vá!'", Color("#FFA502"), 1.6)

# ---------------------------------------------------------------------------
# XE TẢI HỎNG CHẮN LÀN TRÊN ĐẠI LỘ D2
# ---------------------------------------------------------------------------
func _build_broken_trucks() -> void:
	var candidates: Array[float] = [1120.0, 1260.0, 1410.0]
	candidates.shuffle()
	for i: int in range(2):
		var off: float = candidates[i]
		var lateral: float = 3.4 if randf() < 0.6 else 1.4
		var truck := StaticBody3D.new()
		truck.add_to_group("traffic_obstacle")
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.4, 2.6, 7.0)
		cs.shape = box
		cs.position = Vector3(0.0, 1.3, 0.0)
		truck.add_child(cs)
		PlayerBike.attach_near_miss_tag(truck, Vector3(2.4, 2.6, 7.0), 1.3)

		var mat_cab := StandardMaterial3D.new()
		mat_cab.albedo_color = Color("#2E86DE")
		var mat_box := StandardMaterial3D.new()
		mat_box.albedo_color = Color("#DFE6E9")
		var cargo := MeshInstance3D.new()
		var cgm := BoxMesh.new()
		cgm.size = Vector3(2.4, 2.4, 5.0)
		cargo.mesh = cgm
		cargo.material_override = mat_box
		cargo.position = Vector3(0.0, 1.5, 1.0)
		truck.add_child(cargo)
		var cab := MeshInstance3D.new()
		var cbm := BoxMesh.new()
		cbm.size = Vector3(2.3, 1.9, 1.9)
		cab.mesh = cbm
		cab.material_override = mat_cab
		cab.position = Vector3(0.0, 1.2, -2.5)
		truck.add_child(cab)
		var mat_tire := StandardMaterial3D.new()
		mat_tire.albedo_color = Color("#111418")
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-2.2, 1.6, 2.6]:
				var w := MeshInstance3D.new()
				var wm := CylinderMesh.new()
				wm.top_radius = 0.5
				wm.bottom_radius = 0.5
				wm.height = 0.35
				w.mesh = wm
				w.material_override = mat_tire
				w.rotation_degrees = Vector3(0, 0, 90)
				w.position = Vector3(sx * 1.1, 0.5, sz)
				truck.add_child(w)
		# Tam giác cảnh báo + bảng chữ
		var tri := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.8, 0.7, 0.1)
		tri.mesh = pm
		var mat_tri := StandardMaterial3D.new()
		mat_tri.albedo_color = Color("#E74C3C")
		mat_tri.emission_enabled = true
		mat_tri.emission = Color("#E74C3C") * 0.6
		tri.material_override = mat_tri
		tri.position = Vector3(0.0, 0.4, 6.0)
		truck.add_child(tri)
		var lbl := Label3D.new()
		lbl.text = "⚠️ XE TẢI HỎNG GIỮA ĐƯỜNG\n'Chờ cứu hộ 2 tiếng rồi...'"
		lbl.font_size = 30
		lbl.outline_size = 10
		lbl.modulate = Color("#FFEAA7")
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.position = Vector3(0.0, 3.6, 0.0)
		truck.add_child(lbl)
		add_child(truck)
		_place(truck, off, lateral, 0.25)

# ---------------------------------------------------------------------------
# CHÓ CÔ BA CHẠY QUA ĐƯỜNG
# ---------------------------------------------------------------------------
func _build_dog() -> void:
	dog_root = Node3D.new()
	add_child(dog_root)
	dog_xform = _place(dog_root, DOG_OFFSET, -9.5, 0.25)
	dog_dir = 1.0 if randf() < 0.5 else -1.0
	if dog_dir < 0.0:
		dog_root.global_position = dog_xform.origin + dog_xform.basis.x * 9.5 + Vector3(0, 0.25, 0)

	var mat_fur := StandardMaterial3D.new()
	mat_fur.albedo_color = Color("#A0522D")
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.22
	cm.height = 0.9
	body.mesh = cm
	body.material_override = mat_fur
	body.rotation_degrees = Vector3(0, 0, 90)
	body.position = Vector3(0.0, 0.42, 0.0)
	dog_root.add_child(body)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.18
	hm.height = 0.36
	head.mesh = hm
	head.material_override = mat_fur
	head.position = Vector3(0.5 * dog_dir, 0.6, 0.0)
	dog_root.add_child(head)
	for lx: float in [-0.25, 0.25]:
		for lz: float in [-0.12, 0.12]:
			var leg := MeshInstance3D.new()
			var lm := CylinderMesh.new()
			lm.top_radius = 0.05
			lm.bottom_radius = 0.05
			lm.height = 0.35
			leg.mesh = lm
			leg.material_override = mat_fur
			leg.position = Vector3(lx, 0.18, lz)
			dog_root.add_child(leg)
	var lbl := Label3D.new()
	lbl.text = "🐕 GÂU GÂU!!"
	lbl.font_size = 30
	lbl.outline_size = 10
	lbl.modulate = Color("#FFFFFF")
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0.0, 1.3, 0.0)
	dog_root.add_child(lbl)

	dog_area = Area3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.3, 1.0, 0.8)
	cs.shape = box
	cs.position = Vector3(0.0, 0.45, 0.0)
	dog_area.add_child(cs)
	dog_root.add_child(dog_area)
	dog_area.body_entered.connect(_on_dog_hit)
	dog_root.visible = false

func _on_dog_hit(body: Node3D) -> void:
	if body != player_bike or dog_state != 1:
		return
	dog_state = 2
	if player_bike.has_method("hit_soft_obstacle"):
		player_bike.hit_soft_obstacle()
	emit_signal("time_penalty", 3.0, "🐕 ĐÂM TRÚNG CHÓ CÔ BA! Cô Ba đuổi theo chửi 3 giây... +3s PHẠT")
	GameFX.play_sfx("miss")
	var tw := create_tween()
	tw.tween_property(dog_root, "position:y", dog_root.position.y + 1.5, 0.3)
	tw.tween_property(dog_root, "position:y", dog_root.position.y, 0.3)

func _update_dog(delta: float, player_offset: float) -> void:
	if dog_state == 0:
		if player_offset > DOG_OFFSET - 48.0 and player_offset < DOG_OFFSET:
			dog_state = 1
			dog_t = 0.0
			dog_root.visible = true
			emit_signal("banner", "🐕 CHÓ CÔ BA LAO RA ĐƯỜNG! NÉ!!", Color("#FF4757"), 1.5)
			GameFX.play_sfx("alarm", -6.0)
	elif dog_state == 1:
		dog_t += delta / 2.4
		var lateral: float = lerpf(-9.5, 9.5, clampf(dog_t, 0.0, 1.0)) * dog_dir
		dog_root.global_position = dog_xform.origin + dog_xform.basis.x * lateral + Vector3(0.0, 0.25 + absf(sin(dog_t * 40.0)) * 0.12, 0.0)
		if dog_t >= 1.0:
			dog_state = 2
			dog_root.visible = false

# ---------------------------------------------------------------------------
# ĐÈN ĐỎ BẤT NGỜ TRƯỚC CẦU TRAU TRẢU
# ---------------------------------------------------------------------------
func _build_traffic_light() -> void:
	var root := Node3D.new()
	add_child(root)
	_place(root, LIGHT_OFFSET, 8.4, 0.0)

	var mat_pole := StandardMaterial3D.new()
	mat_pole.albedo_color = Color("#636E72")
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.12
	pm.bottom_radius = 0.15
	pm.height = 5.5
	pole.mesh = pm
	pole.material_override = mat_pole
	pole.position = Vector3(0.0, 2.75, 0.0)
	root.add_child(pole)
	var arm := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(5.5, 0.18, 0.18)
	arm.mesh = am
	arm.material_override = mat_pole
	arm.position = Vector3(-2.6, 5.4, 0.0)
	root.add_child(arm)
	var housing := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.6, 1.7, 0.5)
	housing.mesh = hm
	var mat_h := StandardMaterial3D.new()
	mat_h.albedo_color = Color("#1E272E")
	housing.material_override = mat_h
	housing.position = Vector3(-5.0, 4.6, 0.0)
	root.add_child(housing)
	light_bulbs.clear()
	for i: int in range(3):
		var bulb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.2
		sm.height = 0.4
		bulb.mesh = sm
		var mb := StandardMaterial3D.new()
		mb.albedo_color = Color("#2D3436")
		mb.emission_enabled = true
		mb.emission = Color.BLACK
		bulb.material_override = mb
		bulb.position = Vector3(-5.0, 5.1 - i * 0.5, 0.3)
		root.add_child(bulb)
		light_bulbs.append(bulb)

	# Anh CSGT đứng cạnh cột đèn (CharacterBuilder: đồng phục vàng, mũ kê-pi, tay chắp sau lưng)
	var cop: Node3D = CharacterBuilder.build({"preset": "cop", "seed": 113, "name": "Cop", "clip": "guard"})
	cop.position = Vector3(-1.2, 0.0, 3.0)
	cop.rotation.y = PI * 0.5
	root.add_child(cop)
	cop_bubble = Label3D.new()
	cop_bubble.text = "👮 CSGT: Đèn đỏ là dừng nha mấy đứa!"
	cop_bubble.font_size = 28
	cop_bubble.outline_size = 10
	cop_bubble.modulate = Color("#FFFFFF")
	cop_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cop_bubble.position = Vector3(0.0, 2.2, 0.0)
	cop.add_child(cop_bubble)

	# Vạch dừng trắng ngang đường
	var stop_line := MeshInstance3D.new()
	var slm := BoxMesh.new()
	slm.size = Vector3(13.6, 0.03, 0.6)
	stop_line.mesh = slm
	var mat_line := StandardMaterial3D.new()
	mat_line.albedo_color = Color.WHITE
	stop_line.material_override = mat_line
	add_child(stop_line)
	_place(stop_line, LIGHT_OFFSET - 1.5, 0.0, 0.27)

	_set_light("off")

func _set_light(state: String) -> void:
	light_state = state
	var colors: Array[Color] = [Color("#E74C3C"), Color("#F1C40F"), Color("#2ECC71")]
	var active: int = -1
	match state:
		"red": active = 0
		"yellow": active = 1
		"green": active = 2
	for i: int in range(light_bulbs.size()):
		var mb: StandardMaterial3D = light_bulbs[i].material_override as StandardMaterial3D
		if i == active:
			mb.albedo_color = colors[i]
			mb.emission = colors[i] * 1.6
		else:
			mb.albedo_color = Color("#2D3436")
			mb.emission = Color.BLACK

func _update_traffic_light(delta: float, player_offset: float) -> void:
	var speed: float = absf(float(player_bike.get("current_speed_ms")))
	match light_state:
		"off":
			if player_offset > LIGHT_OFFSET - 95.0:
				_set_light("green")
		"green":
			if player_offset > LIGHT_OFFSET - 62.0 and not light_penalized and not light_rewarded:
				_set_light("yellow")
				light_timer = 1.4
				emit_signal("banner", "🟡 ĐÈN VÀNG NGÃ BA TRAU TRẢU! CHUẨN BỊ DỪNG [S]!", Color("#F1C40F"), 1.4)
				GameFX.play_sfx("beep", -4.0)
		"yellow":
			light_timer -= delta
			if light_timer <= 0.0:
				_set_light("red")
				light_timer = 4.2
				emit_signal("banner", "🔴 ĐÈN ĐỎ! DỪNG TRƯỚC VẠCH – CSGT ĐANG NHÌN!", Color("#FF4757"), 1.6)
				GameFX.play_sfx("alarm", -3.0)
		"red":
			light_timer -= delta
			var dist_to_line: float = LIGHT_OFFSET - 1.5 - player_offset
			# Vượt đèn đỏ
			if dist_to_line < 0.0 and dist_to_line > -14.0 and speed > 2.5 and not light_penalized:
				light_penalized = true
				emit_signal("time_penalty", 4.0, "🚨 VƯỢT ĐÈN ĐỎ! CSGT HUÝT CÒI: 'Em ơi tấp vô lề!' +4s PHẠT")
				cop_bubble.text = "👮 TUÝT! Em ơi tấp vô lề!!"
				GameFX.play_sfx("alarm")
				GameFX.flash(Color("#E74C3C"), 0.4, 0.4)
				_set_light("green")
				light_state = "done"
				return
			# Dừng đúng luật
			if dist_to_line > -0.5 and dist_to_line < 30.0 and speed < 1.0:
				light_stop_hold += delta
			if light_timer <= 0.0:
				_set_light("green")
				light_state = "done"
				if light_stop_hold > 1.0 and not light_rewarded:
					light_rewarded = true
					emit_signal("time_bonus", 1.5, "✅ CHẤP HÀNH LUẬT GIAO THÔNG! CSGT gật đầu: +1.5s")
					cop_bubble.text = "👮 Ngoan! Đi đi em!"
					GameFX.play_sfx("success", -2.0)
				else:
					emit_signal("banner", "🟢 ĐÈN XANH! VÍT GA LÊN CẦU TRAU TRẢU!", Color("#2ECC71"), 1.2)
		_:
			pass

# ---------------------------------------------------------------------------
# CHECKPOINT CÓ LỜI THOẠI
# ---------------------------------------------------------------------------
func _build_checkpoints() -> void:
	var specs: Array = [
		[150.0, "🏁 RỜI VINHOMES! 'Nhớ đổ xăng chưa đó?!'", "VINHOMES ➔ NGUYỄN XIỂN"],
		[795.0, "🌉 QUA CẦU TRAU TRẢU RỒI! 'Vành Đai 3 xây 10 năm chưa xong!'", "CẦU TRAU TRẢU"],
		[1035.0, "🛣 ĐẠI LỘ D2 SHTP! 'Thẳng tắp, vít ga đi!'", "ĐẠI LỘ D2"],
		[1522.0, "🔄 BÙNG BINH KÌA! 'Đi VÒNG, đừng đi THẲNG!'", "BÙNG BINH D1-D2"],
		[1705.0, "🎓 HUTECH BÊN TRÁI – 'Đừng rẽ nhầm trường!' FPTU BÊN PHẢI!", "ĐƯỜNG D1 ➔ FPTU"]
	]
	var mat_post := StandardMaterial3D.new()
	mat_post.albedo_color = Color("#F37021")
	mat_post.emission_enabled = true
	mat_post.emission = Color("#F37021") * 0.4
	for s: Array in specs:
		var off: float = s[0]
		var gate := Node3D.new()
		add_child(gate)
		_place(gate, off, 0.0, 0.25)
		for side: float in [-1.0, 1.0]:
			var post := MeshInstance3D.new()
			var pm := CylinderMesh.new()
			pm.top_radius = 0.18
			pm.bottom_radius = 0.22
			pm.height = 6.0
			post.mesh = pm
			post.material_override = mat_post
			post.position = Vector3(side * 7.3, 3.0, 0.0)
			gate.add_child(post)
		var beam := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(15.0, 0.9, 0.3)
		beam.mesh = bm
		beam.material_override = mat_post
		beam.position = Vector3(0.0, 6.3, 0.0)
		gate.add_child(beam)
		var lbl := Label3D.new()
		lbl.text = "CHECKPOINT · " + str(s[2])
		lbl.font_size = 44
		lbl.outline_size = 12
		lbl.modulate = Color.WHITE
		lbl.position = Vector3(0.0, 6.3, 0.2)
		gate.add_child(lbl)
		checkpoints.append({"offset": off, "text": s[1], "done": false})

func _update_checkpoints(player_offset: float) -> void:
	for cp: Dictionary in checkpoints:
		if not cp["done"] and player_offset >= float(cp["offset"]):
			cp["done"] = true
			emit_signal("banner", cp["text"], Color("#F1C40F"), 2.4)
			GameFX.play_sfx("pop", -2.0)

# ---------------------------------------------------------------------------
# MƯA RÀO SHTP
# ---------------------------------------------------------------------------
func _build_rain() -> void:
	rain_particles = CPUParticles3D.new()
	rain_particles.emitting = false
	rain_particles.amount = 520
	rain_particles.lifetime = 1.1
	rain_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain_particles.emission_box_extents = Vector3(16.0, 1.0, 16.0)
	rain_particles.direction = Vector3(0.0, -1.0, 0.0)
	rain_particles.spread = 3.0
	rain_particles.initial_velocity_min = 14.0
	rain_particles.initial_velocity_max = 18.0
	rain_particles.gravity = Vector3(0.0, -18.0, 0.0)
	rain_particles.scale_amount_min = 0.5
	rain_particles.scale_amount_max = 0.9
	var bm := BoxMesh.new()
	bm.size = Vector3(0.03, 0.45, 0.03)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.85, 1.0, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.material = mat
	rain_particles.mesh = bm
	rain_particles.position = Vector3(0.0, 11.0, -6.0)
	player_bike.add_child(rain_particles)
	var scene_root: Node = get_tree().current_scene
	if scene_root:
		world_env = scene_root.get_node_or_null("WorldEnvironment") as WorldEnvironment

func _update_rain(player_offset: float) -> void:
	if not rain_possible or rain_done:
		return
	if not is_raining and player_offset > 1040.0 and player_offset < 1480.0:
		is_raining = true
		rain_particles.emitting = true
		if player_bike.has_method("set_rain"):
			player_bike.set_rain(true)
		emit_signal("rain_changed", true)
		emit_signal("banner", "🌧 MƯA RÀO SHTP BẤT CHỢT! ĐƯỜNG TRƠN – LÁI NHẸ TAY, DRIFT DỄ VĂNG!", Color("#74B9FF"), 2.6)
		GameFX.play_sfx("whoosh", -2.0, 0.6)
		if world_env and world_env.environment:
			var tw := create_tween()
			tw.tween_property(world_env.environment, "fog_density", 0.0045, 1.2)
	elif is_raining and player_offset >= 1480.0:
		is_raining = false
		rain_done = true
		rain_particles.emitting = false
		if player_bike.has_method("set_rain"):
			player_bike.set_rain(false)
		emit_signal("rain_changed", false)
		emit_signal("banner", "☀️ TẠNH MƯA RỒI! VÍT GA VÀO BÙNG BINH!", Color("#FDCB6E"), 1.6)
		if world_env and world_env.environment:
			var tw := create_tween()
			tw.tween_property(world_env.environment, "fog_density", 0.0006, 1.5)

# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if not curve or not player_bike:
		return
	var player_offset: float = curve.get_closest_offset(player_bike.global_position)
	_update_dog(delta, player_offset)
	_update_traffic_light(delta, player_offset)
	_update_checkpoints(player_offset)
	_update_rain(player_offset)
