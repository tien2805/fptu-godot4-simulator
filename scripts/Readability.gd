# File: res://scripts/Readability.gd
# Q3 readability (master plan 2026-10-29 Q3; plan docs/superpowers/plans/2026-10-29-q3-look.md Task 2).
#
# Fresnel rim: a subtle additive edge glow so enemies (red-orange) and pickups (yellow) read against busy night scenes.
#   rim(root, kind, shell) is called ONCE at build time by the enemy / pickup scripts (a single line each). Every
#   MeshInstance3D under root gets the shared rim material of its kind:
#     - overlay mode (default): as material_overlay (a second pass on the same skinned vertices, no extra skinning);
#     - shell mode: a child MeshInstance3D "RimShell" with the same mesh, skin and skeleton (for owners that use
#       material_overlay themselves: MeleeEnemy's hit flash would clear an overlay rim).
#   Label3D / Sprite3D / particles are skipped (only MeshInstance3D), as are meshes that already have an overlay and tiny
#   meshes (largest AABB side < MIN_SIZE: eyes, brows, buttons).
#   The shader is unshaded, additive, no depth write, no fog, fades out between 30 and 70 m; strength 0.55 (enemy) /
#   0.7 (pickup), power 3: a thin edge, never a solid outline.
#   Settings "Viền sáng nhân vật" (GameFX video/rim_light, default on) -> set_enabled(on): roots are in the group
#   "rim_target", so switching adds or removes the rim on everything alive; rim() while off only registers the root.
#
# Telegraph colour convention (Q3): red DANGER = a hazard / an attack, yellow PROMPT = a prompt or a pickup, cyan ZONE =
# a drift or nitro zone. telegraph_material(kind, energy) = an emissive material in that colour (CineFX._glow_mat look).
# Static only (class_name: compiled before autoloads in tests).
class_name Readability
extends RefCounted

const DANGER := Color(1.0, 0.18, 0.12)
const PROMPT := Color(1.0, 0.84, 0.2)
const ZONE := Color(0.25, 0.92, 1.0)
const GROUP: StringName = &"rim_target"
const SHELL_NAME: String = "RimShell"
const KINDS: Dictionary = {
	"enemy": {"col": Color(1.0, 0.36, 0.12), "strength": 0.55},
	"pickup": {"col": Color(1.0, 0.85, 0.22), "strength": 0.7},
}
const POWER: float = 3.0
const GROW: float = 0.004
const FADE_BEGIN: float = 30.0
const FADE_END: float = 70.0
## Meshes whose largest local AABB side is under this get no rim (tiny face parts; keeps the extra passes few).
const MIN_SIZE: float = 0.14

const RIM_SHADER: String = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled, shadows_disabled;

uniform vec4 rim_color : source_color = vec4(1.0, 0.36, 0.12, 1.0);
uniform float strength = 0.55;
uniform float power = 3.0;
uniform float grow = 0.004;
uniform float fade_begin = 30.0;
uniform float fade_end = 70.0;

void vertex() {
	VERTEX += NORMAL * grow;
}

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float edge = pow(1.0 - facing, power);
	float fade = 1.0 - smoothstep(fade_begin, fade_end, length(VERTEX));
	ALBEDO = rim_color.rgb;
	ALPHA = clamp(edge * strength * fade, 0.0, 1.0);
}
"""

static var _enabled: bool = true
static var _shader: Shader = null
static var _mats: Dictionary = {}


static func enabled() -> bool:
	return _enabled


static func shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = RIM_SHADER
	return _shader


## The shared rim material of a kind ("enemy" / "pickup"; unknown = enemy).
static func rim_material(kind: String = "enemy") -> ShaderMaterial:
	var k: String = kind if KINDS.has(kind) else "enemy"
	if _mats.has(k):
		return _mats[k]
	var d: Dictionary = KINDS[k]
	var m := ShaderMaterial.new()
	m.shader = shader()
	m.set_shader_parameter("rim_color", d["col"])
	m.set_shader_parameter("strength", float(d["strength"]))
	m.set_shader_parameter("power", POWER)
	m.set_shader_parameter("grow", GROW)
	m.set_shader_parameter("fade_begin", FADE_BEGIN)
	m.set_shader_parameter("fade_end", FADE_END)
	m.set_meta("vice_done", true)
	m.set_meta("rim_mat", k)
	_mats[k] = m
	return m


## Registers root for the rim and (while enabled) puts the rim on its meshes. Returns the number of meshes rimmed.
static func rim(root: Node, kind: String = "enemy", shell: bool = false) -> int:
	if root == null:
		return 0
	root.add_to_group(GROUP)
	root.set_meta("rim_kind", kind)
	root.set_meta("rim_shell", shell)
	return _attach(root) if _enabled else 0


## Removes the rim from root's meshes (the root stays registered).
static func unrim(root: Node) -> void:
	if root == null:
		return
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.has_meta("rim_shell_node"):
			continue
		if mi.material_overlay != null and mi.material_overlay.has_meta("rim_mat"):
			mi.material_overlay = null
		var sh: Node = mi.get_node_or_null(SHELL_NAME)
		if sh and sh.has_meta("rim_shell_node"):
			mi.remove_child(sh)
			sh.queue_free()


## Settings toggle: adds / removes the rim on every registered root alive.
static func set_enabled(on: bool) -> void:
	_enabled = on
	var ml: SceneTree = Engine.get_main_loop() as SceneTree
	if ml == null:
		return
	for n: Node in ml.get_nodes_in_group(GROUP):
		if on:
			_attach(n)
		else:
			unrim(n)


## Meshes of root carrying the rim (overlay or shell); tests and the render budget.
static func rimmed_count(root: Node) -> int:
	var c: int = 0
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.has_meta("rim_shell_node"):
			c += 1
		elif mi.material_overlay != null and mi.material_overlay.has_meta("rim_mat"):
			c += 1
	return c


static func telegraph_color(kind: String) -> Color:
	match kind:
		"prompt", "pickup":
			return PROMPT
		"zone", "drift", "nitro":
			return ZONE
	return DANGER


## An emissive material in the telegraph colour of a kind ("danger" / "prompt" / "zone").
static func telegraph_material(kind: String, energy: float = 3.0) -> StandardMaterial3D:
	var col: Color = telegraph_color(kind)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.set_meta("vice_done", true)
	return m


static func _attach(root: Node) -> int:
	var mat: ShaderMaterial = rim_material(String(root.get_meta("rim_kind", "enemy")))
	var shell: bool = bool(root.get_meta("rim_shell", false))
	var count: int = 0
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.has_meta("rim_shell_node") or mi.mesh == null or _tiny(mi):
			continue
		if shell:
			if mi.get_node_or_null(SHELL_NAME) == null:
				_add_shell(mi, mat)
			count += 1
		elif mi.material_overlay == null or mi.material_overlay == mat:
			mi.material_overlay = mat
			count += 1
	return count


## Eyes, brows, teeth, buttons...: too small for an edge to read, not worth a pass.
static func _tiny(mi: MeshInstance3D) -> bool:
	var sz: Vector3 = mi.get_aabb().size
	return maxf(sz.x, maxf(sz.y, sz.z)) < MIN_SIZE


static func _add_shell(mi: MeshInstance3D, mat: ShaderMaterial) -> void:
	var sh := MeshInstance3D.new()
	sh.name = SHELL_NAME
	sh.set_meta("rim_shell_node", true)
	sh.mesh = mi.mesh
	sh.skin = mi.skin
	sh.material_override = mat
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var sk: Node = mi.get_node_or_null(mi.skeleton) if not mi.skeleton.is_empty() else null
	mi.add_child(sh)
	if sk is Skeleton3D:
		sh.skeleton = sh.get_path_to(sk)
