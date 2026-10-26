# File: res://scripts/combat/bike/BikeCameo.gd
# The Sói Xám cameo of the Day 2 chase (spec 2026-10-27, D2X-7), started by BikeChase (setup opt "cameo") after wave 2:
#   approach  he rides up from behind (out of view) on a grey tuned bike, CAMEO_REL m/s over the player, one lane over,
#             front wheel up (a wheelie) as he passes;
#   card      about 7 m ahead: the villain card freezes the frame (opts "card_fn": Callable(done: Callable), the story
#             shows StoryVillainCard and calls done; without it the HUD shows "SÓI XÁM - đầu đàn Bầy Sói" for 2.4 s);
#   taunt     "Muốn biết hàng về đâu thì lên cầu Rạch Hầm mà hỏi!" (a bubble over him and the HUD popup, CAMEO_TAUNT_S);
#   nitro     a blue flame (an emissive cone and CPUParticles3D) and he pulls away at CAMEO_AWAY m/s over the player;
#             45 m ahead `finished` (BikeChase starts wave 3), then he is hidden out of view and freed.
# He cannot be attacked (not a BikeChase biker). opts: "body_fn" (Callable(look) -> rigged Node3D, the story passes
# StoryCast "soi_xam"), "card_fn", "lat" (side offset, default the side with more room).
class_name BikeCameo
extends Node3D

signal finished

const REAR := Vector3(0.0, 0.0, 0.62)    # the rear wheel's contact point (the wheelie pivot)
const CARD_FALLBACK_S: float = 2.4

var ch: BikeChase
var opts: Dictionary = {}
var phase: String = ""
var along: float = -30.0
var lat: float = -1.6
var wheelie: float = 0.0
var floor_y: float = 0.0
var rider: Node3D
var body: Node3D
var flame: Node3D
var flame_fx: CPUParticles3D
var bubble: Label3D
var card_calls: int = 0
var _t: float = 0.0
var _frame: int = 0
var _done_sent: bool = false


func setup(chase: BikeChase, o: Dictionary) -> void:
	ch = chase
	opts = o


func begin() -> void:
	rider = Node3D.new()
	rider.name = "SoiXamBike"
	rider.top_level = true
	add_child(rider)
	PropBuilder.build_scooter(rider, Vector3.ZERO, 0.0, BikeCombatData.CAMEO_PAINT, {"baked": true, "name": "Scooter", "traffic_lamps": true})
	var sc: Node3D = rider.get_node_or_null("Scooter") as Node3D
	if sc:
		sc.scale = Vector3.ONE * 1.12
	var look: Dictionary = {"preset": "rider", "seed": 3131, "female": false, "body": "hoodie", "backpack": false, "glasses": false,
		"helmet_color": Color("#3A3D42"), "shirt_color": Color("#5F666E"), "clip": "ride", "rigged": true, "name": "SoiXam"}
	var bf: Callable = opts.get("body_fn", Callable())
	body = bf.call(look) if bf.is_valid() else CharacterBuilder.build(look)
	if body:
		body.name = "SoiXam"
		body.position = Vector3(0.0, 0.36, 0.16)
		rider.add_child(body)
		CharacterBuilder.set_param(body, "ride_shoulder", 1.2)
		CharacterBuilder.set_param(body, "ride_elbow", 0.28)
		CharacterBuilder.set_param(body, "ride_lean", 0.45)
		if not bf.is_valid():
			BikerEnemy.attach_wolf_helmet(body, BikeCombatData.EYE_COL)
	flame = Node3D.new()
	flame.name = "NitroFlame"
	flame.position = Vector3(0.18, 0.42, 1.0)
	rider.add_child(flame)
	var cone := MeshInstance3D.new()
	cone.name = "Cone"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.09
	cm.height = 0.7
	cm.radial_segments = 10
	cone.mesh = cm
	var fm: StandardMaterial3D = CineFX._glow_mat(BikeCombatData.NITRO_FLAME, 6.0)
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cone.material_override = fm
	cone.rotation.x = -PI * 0.5            # the tip points back (+Z)
	cone.position = Vector3(0.0, 0.0, 0.35)
	flame.add_child(cone)
	flame_fx = CPUParticles3D.new()
	flame_fx.name = "Sparks"
	flame_fx.amount = 24
	flame_fx.lifetime = 0.35
	flame_fx.direction = Vector3(0.0, 0.0, 1.0)
	flame_fx.spread = 12.0
	flame_fx.initial_velocity_min = 4.0
	flame_fx.initial_velocity_max = 8.0
	flame_fx.gravity = Vector3.ZERO
	flame_fx.scale_amount_min = 0.03
	flame_fx.scale_amount_max = 0.07
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	flame_fx.mesh = bm
	flame_fx.material_override = fm
	flame_fx.emitting = false
	flame.add_child(flame_fx)
	flame.visible = false
	bubble = Label3D.new()
	bubble.name = "Taunt"
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.font_size = 44
	bubble.pixel_size = 0.007
	bubble.outline_size = 10
	bubble.modulate = Color("#E8EDF2")
	bubble.position = Vector3(0.0, 2.5, 0.0)
	bubble.visible = false
	rider.add_child(bubble)
	if opts.has("lat"):
		lat = float(opts["lat"])
	else:
		lat = -1.6 if ch.lat_room(-1.0) >= ch.lat_room(1.0) else 1.6
	along = -30.0
	floor_y = ch.bike.global_position.y + BikeChase.BIKE_FLOOR_OFFSET
	phase = "approach"
	_place()
	ch.cue("engine_roar", rider.global_position, 2.0)


func tick(delta: float, rdt: float) -> void:
	if phase == "" or rider == null:
		return
	_frame += 1
	match phase:
		"approach":
			along += BikeCombatData.CAMEO_REL * delta
			wheelie = move_toward(wheelie, 0.42 if along > -10.0 else 0.0, delta * 1.5)
			if along >= 7.0:
				_show_card()
		"card":
			_t += rdt
			if not opts.get("card_fn", Callable()).is_valid() and _t >= CARD_FALLBACK_S:
				on_card_done()
		"taunt":
			_t += rdt
			wheelie = move_toward(wheelie, 0.0, delta * 1.2)
			if _t >= BikeCombatData.CAMEO_TAUNT_S:
				phase = "nitro"
				_t = 0.0
				bubble.visible = false
				flame.visible = true
				flame_fx.emitting = true
				ch.cue("dep_whoosh", rider.global_position, 2.0)
				ch.cue("engine_roar", rider.global_position, 4.0)
		"nitro":
			along += BikeCombatData.CAMEO_AWAY * delta
			wheelie = move_toward(wheelie, 0.25, delta * 2.0)
			if along >= 45.0 and not _done_sent:
				_done_sent = true
				finished.emit()
			if along >= 60.0 and (along >= 200.0 or not ch.in_view(rider.global_position + Vector3(0.0, 1.0, 0.0))):
				phase = "gone"
				rider.visible = false
				queue_free()
				return
	if _frame % BikeCombatData.RAY_EVERY == 0:
		var p: Vector2 = ch.target_at(along, lat)
		var y: Variant = ch.floor_at(Vector3(p.x, floor_y, p.y))
		if y is float:
			floor_y = lerpf(floor_y, float(y), 0.6)
	_place()


func _show_card() -> void:
	phase = "card"
	_t = 0.0
	card_calls += 1
	var cf: Callable = opts.get("card_fn", Callable())
	if cf.is_valid():
		cf.call(on_card_done)
	elif ch.hud:
		ch.hud.popup(BikeCombatData.T_CAMEO_NAME, Color("#B8C0C8"), CARD_FALLBACK_S)


## The card is over (the story's card_fn calls this): his taunt.
func on_card_done() -> void:
	if phase != "card":
		return
	phase = "taunt"
	_t = 0.0
	bubble.text = BikeCombatData.T_CAMEO_TAUNT
	bubble.visible = true
	if ch.hud:
		ch.hud.popup(BikeCombatData.T_CAMEO_TAUNT, Color("#E8EDF2"), BikeCombatData.CAMEO_TAUNT_S)


func _place() -> void:
	var p: Vector2 = ch.target_at(along, lat)
	var f: Vector2 = ch.p_fwd
	var yaw: float = atan2(-f.x, -f.y)
	var by := Basis(Vector3.UP, yaw)
	var bw := by * Basis(Vector3.RIGHT, wheelie)
	var ground := Vector3(p.x, floor_y, p.y)
	rider.global_transform = Transform3D(bw, ground + by * REAR - bw * REAR)


## Map position (tests).
func pos2() -> Vector2:
	return Vector2(rider.global_position.x, rider.global_position.z) if rider else Vector2.ZERO
