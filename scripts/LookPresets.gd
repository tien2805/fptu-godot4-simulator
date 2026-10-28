# File: res://scripts/LookPresets.gd
# Q3 look presets (master plan 2026-10-29 section Q3; plan docs/superpowers/plans/2026-10-29-q3-look.md, Task 1): per scene
# and per mission lighting, grading, fog and glow, layered ON TOP of ViceStyle and the GameFX quality levels.
#
# How it layers (never fights ViceStyle):
#   - each "env owner" (FreeRoam, a lair scene...) keeps a base layer (set_base) and a stack of pushed presets (apply /
#     restore) in metas; the top of the stack wins, else the base, else no preset;
#   - rendering puts a SHALLOW copy of the owner's base Environment (the one ViceStyle or the scene built: sky and LUT stay
#     shared) on the owner's first WorldEnvironment, with the preset values written over it; no preset = the base
#     environment comes back as it was;
#   - when the scene rebuilds its environment (ViceStyle.apply at a time-of-day or quality change), GameFX
#     .upgrade_scene_visuals calls refresh(owner): the new environment becomes the base and the active preset is written
#     over it again;
#   - key light = the owner's first DirectionalLight3D (colour, energy, shadow opacity; the direction stays the scene's);
#     its own values are kept in a meta and come back when no preset sets a key; fill light = a shadowless
#     DirectionalLight3D "LookFill" made under the owner on demand, hidden when the preset has no fill.
# Values are conservative on purpose (nobody looks at renders before the owner): glow only for emissives (HDR threshold
# >= 1.25 at night, 2.4 by day), exposure within +-0.1 of the ViceStyle look, fog close to the look's own.
# Quality 0 (GameFX THẤP) drops the two widest glow levels (cheaper blur).
# Static only; the GameFX autoload is reached through the root (class_name scripts compile before autoloads in tests).
class_name LookPresets
extends RefCounted

const FILL_NAME: String = "LookFill"

## exposure: tonemap exposure; glow / glow_strength / thr / cap / bloom: glow intensity, strength, HDR threshold, HDR
## luminance cap, bloom; fog / fog_begin / fog_end / fog_density: depth fog colour, begin, end (m) and density at the end;
## brightness / contrast / sat: adjustments; amb / amb_col: ambient energy and colour; key: {col, energy, shadow}
## (shadow = shadow opacity); fill: {col, energy, elev, azim} (degrees, no shadows).
const PRESETS: Dictionary = {
	# Free roam at night (and Day 2 outside the chase): warm sodium fill under the moon, violet haze, neon and lamp heads
	# glow (threshold 1.4 < their emission, > lit asphalt and lane paint).
	"night_city": {"exposure": 1.05, "glow": 0.7, "glow_strength": 1.0, "thr": 1.4, "cap": 3.0, "bloom": 0.0,
		"fog": Color("#33204f"), "fog_begin": 35.0, "fog_end": 650.0, "fog_density": 0.85,
		"brightness": 1.0, "contrast": 1.05, "sat": 1.12, "amb": 0.32, "amb_col": Color("#4f3f8f"),
		"key": {"col": Color("#8ea6ff"), "energy": 0.32, "shadow": 0.5},
		"fill": {"col": Color("#ffb36b"), "energy": 0.1, "elev": 22.0, "azim": 30.0}},
	# Day 2 chase and duel: cyan key, magenta back fill, stronger glow on headlights and LED eyes (threshold 1.25).
	"tokyo_drift": {"exposure": 1.08, "glow": 0.85, "glow_strength": 1.05, "thr": 1.25, "cap": 4.0, "bloom": 0.0,
		"fog": Color("#2a1450"), "fog_begin": 30.0, "fog_end": 550.0, "fog_density": 0.85,
		"brightness": 1.0, "contrast": 1.08, "sat": 1.22, "amb": 0.3, "amb_col": Color("#3d3a9a"),
		"key": {"col": Color("#7fd4ff"), "energy": 0.3, "shadow": 0.5},
		"fill": {"col": Color("#ff4fd0"), "energy": 0.12, "elev": 15.0, "azim": 20.0}},
	# Day 3 container yard: orange sodium floodlight fill, grey-blue sea haze closer in.
	"port_night": {"exposure": 1.02, "glow": 0.65, "glow_strength": 1.0, "thr": 1.45, "cap": 3.0, "bloom": 0.0,
		"fog": Color("#3a3046"), "fog_begin": 25.0, "fog_end": 450.0, "fog_density": 0.9,
		"brightness": 1.0, "contrast": 1.06, "sat": 1.08, "amb": 0.3, "amb_col": Color("#56487a"),
		"key": {"col": Color("#9fb0ff"), "energy": 0.28, "shadow": 0.5},
		"fill": {"col": Color("#ffa04a"), "energy": 0.16, "elev": 35.0, "azim": 120.0}},
	# Day 5 basement (no sun of its own): red emergency haze, a faint blue screen-glow fill from the monitor wall side.
	"server_red": {"exposure": 1.0, "glow": 0.75, "glow_strength": 1.0, "thr": 1.3, "cap": 3.0, "bloom": 0.0,
		"fog": Color("#3a0a10"), "fog_begin": 4.0, "fog_end": 45.0, "fog_density": 0.4,
		"brightness": 1.0, "contrast": 1.1, "sat": 1.05, "amb": 0.5, "amb_col": Color("#5a4458"),
		"fill": {"col": Color("#6f8cff"), "energy": 0.12, "elev": 10.0, "azim": 0.0}},
	# Phase D Day 6: blue water night, warm festival fill.
	"canal_night": {"exposure": 1.05, "glow": 0.75, "glow_strength": 1.0, "thr": 1.35, "cap": 3.0, "bloom": 0.0,
		"fog": Color("#2a2a55"), "fog_begin": 30.0, "fog_end": 600.0, "fog_density": 0.85,
		"brightness": 1.0, "contrast": 1.04, "sat": 1.15, "amb": 0.3, "amb_col": Color("#4a4a95"),
		"key": {"col": Color("#9ab8ff"), "energy": 0.3, "shadow": 0.5},
		"fill": {"col": Color("#ffcf7a"), "energy": 0.12, "elev": 20.0, "azim": 160.0}},
	# Phase D Day 7: gold and black, dramatic contrast (the blackout is the scene's own flashlight and lightning).
	"penthouse": {"exposure": 0.98, "glow": 0.6, "glow_strength": 1.0, "thr": 1.5, "cap": 3.0, "bloom": 0.0,
		"fog": Color("#1a1410"), "fog_begin": 20.0, "fog_end": 300.0, "fog_density": 0.6,
		"brightness": 1.0, "contrast": 1.15, "sat": 1.0, "amb": 0.35, "amb_col": Color("#6b5a3a"),
		"key": {"col": Color("#ffd68a"), "energy": 0.6, "shadow": 0.6},
		"fill": {"col": Color("#2a2a40"), "energy": 0.1, "elev": 25.0, "azim": 200.0}},
	# Campus / free roam by day (Days 1 and 4): warm sun, softer shadows (a cool sky fill lifts them), a slight bloom.
	# Threshold stays 2.4 like ViceStyle's day look (lower puts halos on sunlit lane paint).
	"campus_day": {"exposure": 1.16, "glow": 0.5, "glow_strength": 1.0, "thr": 2.4, "cap": 12.0, "bloom": 0.04,
		"fog": Color("#e2eef0"), "fog_begin": 140.0, "fog_end": 1800.0, "fog_density": 0.9,
		"brightness": 1.02, "contrast": 1.0, "sat": 1.18, "amb": 1.1, "amb_col": Color("#d2e2e6"),
		"key": {"col": Color("#fff0d4"), "energy": 1.5, "shadow": 0.62},
		"fill": {"col": Color("#bcd8ff"), "energy": 0.15, "elev": 35.0, "azim": -30.0}},
}

## FreeRoam base preset per time of day (GameFX.TOD_PRESETS keys): night = night_city, morning / noon = campus_day; dawn and
## sunset keep ViceStyle's own look.
const ROAM_TOD: Dictionary = {"night": "night_city", "morning": "campus_day", "noon": "campus_day"}


static func names() -> Array:
	return PRESETS.keys()


static func has(name: String) -> bool:
	return PRESETS.has(name)


static func for_roam_tod(tod: String) -> String:
	return String(ROAM_TOD.get(tod, ""))


## Pushes `name` on the owner's stack and renders it (unknown names are ignored).
static func apply(name: String, env_owner: Node) -> void:
	if env_owner == null or not PRESETS.has(name):
		return
	var st: Array = (env_owner.get_meta("look_stack", []) as Array).duplicate()
	st.append(name)
	env_owner.set_meta("look_stack", st)
	_render(env_owner)


## Pops the last `name` from the owner's stack ("" = the top) and renders what is below.
static func restore(env_owner: Node, name: String = "") -> void:
	if env_owner == null or not is_instance_valid(env_owner):
		return
	var st: Array = (env_owner.get_meta("look_stack", []) as Array).duplicate()
	if st.is_empty():
		return
	var i: int = st.size() - 1 if name == "" else st.rfind(name)
	if i < 0:
		return
	st.remove_at(i)
	env_owner.set_meta("look_stack", st)
	_render(env_owner)


## The owner's base layer ("" = none), rendered at once when it changes.
static func set_base(env_owner: Node, name: String) -> void:
	if env_owner == null:
		return
	var n: String = name if PRESETS.has(name) else ""
	if String(env_owner.get_meta("look_base", "")) == n and env_owner.has_meta("look_rendered"):
		return
	env_owner.set_meta("look_base", n)
	_render(env_owner)


## Re-renders after the scene rebuilt its environment (GameFX.upgrade_scene_visuals). Nothing to do for an owner that
## never had a preset.
static func refresh(env_owner: Node) -> void:
	if env_owner == null or not env_owner.has_meta("look_rendered"):
		return
	_render(env_owner)


## The preset in effect on the owner ("" = none).
static func active(env_owner: Node) -> String:
	if env_owner == null:
		return ""
	var st: Array = env_owner.get_meta("look_stack", [])
	if not st.is_empty():
		return String(st[st.size() - 1])
	return String(env_owner.get_meta("look_base", ""))


## The fill light of the owner (null before a preset with a fill was rendered).
static func fill_light(env_owner: Node) -> DirectionalLight3D:
	return env_owner.get_node_or_null(FILL_NAME) as DirectionalLight3D if env_owner else null


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------
static func _render(owner: Node) -> void:
	var name: String = active(owner)
	var p: Dictionary = PRESETS.get(name, {})
	owner.set_meta("look_rendered", true)
	var we: WorldEnvironment = _world_env(owner)
	if we:
		var cur: Environment = we.environment
		var ours: Environment = _meta(owner, "look_env") as Environment
		var base: Environment = _meta(owner, "look_base_env") as Environment
		if cur != ours or base == null:
			base = cur                                   # the scene (ViceStyle) built a new environment: it is the base now
		if p.is_empty() or base == null:
			if ours != null and cur == ours and base != null:
				we.environment = base
			_drop_meta(owner, ["look_env", "look_base_env"])
		else:
			var e: Environment = base.duplicate(false) as Environment
			_write_env(e, p, _quality())
			we.environment = e
			owner.set_meta("look_env", e)
			owner.set_meta("look_base_env", base)
	_write_key(_key_light(owner), p.get("key", {}))
	_write_fill(owner, p.get("fill", {}))


static func _write_env(e: Environment, p: Dictionary, q: int) -> void:
	e.tonemap_exposure = float(p["exposure"])
	e.glow_enabled = true
	e.glow_intensity = float(p["glow"])
	e.glow_strength = float(p["glow_strength"])
	e.glow_hdr_threshold = float(p["thr"])
	e.glow_hdr_luminance_cap = float(p["cap"])
	e.glow_bloom = float(p["bloom"])
	if q <= 0:
		e.set_glow_level(3, 0.0)
		e.set_glow_level(4, 0.0)
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_light_color = p["fog"]
	e.fog_depth_begin = float(p["fog_begin"])
	e.fog_depth_end = float(p["fog_end"])
	e.fog_density = float(p["fog_density"])
	e.adjustment_enabled = true
	e.adjustment_brightness = float(p["brightness"])
	e.adjustment_contrast = float(p["contrast"])
	e.adjustment_saturation = float(p["sat"])
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = p["amb_col"]
	e.ambient_light_energy = float(p["amb"])


## Key light: k empty = the light's own values back. Its own values are re-read whenever someone else changed the light
## since the last write (ViceStyle._apply_sun at a time-of-day change).
static func _write_key(key: DirectionalLight3D, k: Dictionary) -> void:
	if key == null:
		return
	var wrote: Dictionary = key.get_meta("look_key_set", {})
	if wrote.is_empty() or not _key_matches(key, wrote):
		key.set_meta("look_key_base", _read_key(key))
	var base: Dictionary = key.get_meta("look_key_base", {})
	if k.is_empty():
		if not wrote.is_empty() and _key_matches(key, wrote) and not base.is_empty():
			key.light_color = base["col"]
			key.light_energy = float(base["energy"])
			key.shadow_opacity = float(base["shadow"])
		for m: String in ["look_key_set", "look_key_base"]:
			if key.has_meta(m):
				key.remove_meta(m)
		return
	key.light_color = k["col"]
	key.light_energy = float(k["energy"])
	key.shadow_opacity = float(k.get("shadow", key.shadow_opacity))
	key.set_meta("look_key_set", _read_key(key))


static func _read_key(key: DirectionalLight3D) -> Dictionary:
	return {"col": key.light_color, "energy": key.light_energy, "shadow": key.shadow_opacity}


static func _key_matches(key: DirectionalLight3D, d: Dictionary) -> bool:
	return key.light_color.is_equal_approx(d["col"]) and is_equal_approx(key.light_energy, float(d["energy"])) \
		and is_equal_approx(key.shadow_opacity, float(d["shadow"]))


static func _write_fill(owner: Node, f: Dictionary) -> void:
	var fill: DirectionalLight3D = owner.get_node_or_null(FILL_NAME) as DirectionalLight3D
	if f.is_empty():
		if fill:
			fill.visible = false
		return
	if fill == null:
		if not (owner is Node3D):
			return
		fill = DirectionalLight3D.new()
		fill.name = FILL_NAME
		fill.set_meta("look_fill", true)
		fill.shadow_enabled = false
		fill.light_specular = 0.0          # a fill lifts shadows; no second highlight
		fill.light_indirect_energy = 0.0
		owner.add_child(fill)
	fill.visible = true
	fill.light_color = f["col"]
	fill.light_energy = float(f["energy"])
	fill.rotation_degrees = Vector3(-float(f.get("elev", 30.0)), float(f.get("azim", 0.0)), 0.0)


# ---------------------------------------------------------------------------
# Lookups
# ---------------------------------------------------------------------------
## The owner's WorldEnvironment: a direct child named "WorldEnvironment" (FreeRoam, the lair scenes), else the first one
## in the tree (cached in a meta while valid).
static func _world_env(owner: Node) -> WorldEnvironment:
	var c: Variant = _meta(owner, "look_we")
	if is_instance_valid(c) and c is WorldEnvironment:
		return c
	var we: WorldEnvironment = owner.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we == null:
		we = _find_first(owner, "WorldEnvironment", false) as WorldEnvironment
	if we:
		owner.set_meta("look_we", we)
	return we


static func _key_light(owner: Node) -> DirectionalLight3D:
	var c: Variant = _meta(owner, "look_key")
	if is_instance_valid(c) and c is DirectionalLight3D:
		return c
	var k: DirectionalLight3D = owner.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if k == null or k.has_meta("look_fill"):
		k = _find_first(owner, "DirectionalLight3D", true) as DirectionalLight3D
	if k:
		owner.set_meta("look_key", k)
	return k


static func _find_first(node: Node, cls: String, skip_fill: bool) -> Node:
	if node.is_class(cls) and not (skip_fill and node.has_meta("look_fill")):
		return node
	for c: Node in node.get_children():
		var r: Node = _find_first(c, cls, skip_fill)
		if r:
			return r
	return null


static func _meta(owner: Node, key: String) -> Variant:
	return owner.get_meta(key) if owner.has_meta(key) else null


static func _drop_meta(owner: Node, keys: Array) -> void:
	for k: String in keys:
		if owner.has_meta(k):
			owner.remove_meta(k)


static func _quality() -> int:
	var ml: SceneTree = Engine.get_main_loop() as SceneTree
	if ml and ml.root:
		var g: Node = ml.root.get_node_or_null("GameFX")
		if g:
			return int(g.get("visual_quality"))
	return 2
