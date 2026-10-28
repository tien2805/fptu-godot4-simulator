# File: res://tests/test_readability.gd
# Headless test of the Q3 readability layer (plan 2026-10-29-q3-look.md Task 2):
#   A: the rim shader compiles (its 6 uniforms are listed; a compile error leaves the list empty + "SHADER ERROR");
#   B: overlay mode on a rigged CharacterBuilder body: every mesh carries the shared enemy rim, a Label3D is untouched,
#      an existing overlay is kept;
#   C: shell mode: a "RimShell" child per mesh with the same mesh / skin and a skeleton path that resolves, no overlay;
#   D: the real enemy builds: MeleeEnemy (shells: its hit flash owns material_overlay), Gunman, BikerEnemy, AmmoPickup
#      (yellow pickup rim); the extra passes per enemy stay within a budget (8 / 12 / 14);
#   E: the settings toggle: off removes every rim (overlays and shells), rim() while off only registers, on puts them back;
#   F: GameFX "Viền sáng nhân vật": the CheckButton in a settings panel and in the pause settings, toggling it switches
#      Readability and saves video/rim_light to a TEMP settings path (the owner's settings are never touched);
#   G: telegraph colours: red danger, yellow prompt, cyan zone.
# Run: godot --headless --path . --script tests/test_readability.gd
extends SceneTree

var TMP_SETTINGS: String = "user://test_readability_settings_%d.cfg" % OS.get_process_id()

var done: bool = false
var frame: int = 0
var holder: Node3D


func _initialize() -> void:
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	frame += 1
	if done or frame != 2:
		return
	holder = Node3D.new()
	root.add_child(holder)
	for part: Callable in [_part_a, _part_b, _part_c, _part_d, _part_e, _part_f, _part_g]:
		if not part.call():
			return
	done = true
	Readability.set_enabled(true)
	print("SUCCESS: rim shader compiles, enemies and pickups get the rim (overlay / shell), the settings toggle switches it")
	quit(0)


func _check(ok: bool, msg: String) -> bool:
	if not ok and not done:
		done = true
		print("FAILED: ", msg)
		quit(1)
	return ok


func _meshes(n: Node) -> Array:
	var out: Array = []
	for m: Node in n.find_children("*", "MeshInstance3D", true, false):
		if not m.has_meta("rim_shell_node") and (m as MeshInstance3D).mesh != null and not Readability._tiny(m as MeshInstance3D):
			out.append(m)
	return out


func _body() -> Node3D:
	var b: Node3D = CharacterBuilder.build({"rigged": true, "seed": 11, "name": "Body"})
	holder.add_child(b)
	return b


# ---------------------------------------------------------------------------
func _part_a() -> bool:
	var u: Array = Readability.shader().get_shader_uniform_list()
	var names: Array = []
	for d: Dictionary in u:
		names.append(String(d["name"]))
	for n: String in ["rim_color", "strength", "power", "grow", "fade_begin", "fade_end"]:
		if not _check(names.has(n), "rim shader did not compile (uniform %s missing; got %s)" % [n, str(names)]):
			return false
	var m: ShaderMaterial = Readability.rim_material("enemy")
	if not _check(m == Readability.rim_material("enemy") and m != Readability.rim_material("pickup"), "rim materials not shared per kind"):
		return false
	if not _check(float(m.get_shader_parameter("strength")) <= 0.75, "rim too strong for 'subtle'"):
		return false
	print("  A: rim shader compiles, %d uniforms" % names.size())
	return true


func _part_b() -> bool:
	var b: Node3D = _body()
	var lbl := Label3D.new()
	lbl.text = "x"
	b.add_child(lbl)
	var keep := MeshInstance3D.new()
	keep.mesh = BoxMesh.new()
	var own := StandardMaterial3D.new()
	keep.material_overlay = own
	b.add_child(keep)
	var ms: Array = _meshes(b)
	var n: int = Readability.rim(b, "enemy")
	if not _check(ms.size() >= 2 and n == ms.size() - 1, "overlay rim count %d for %d meshes" % [n, ms.size()]):
		return false
	for mi: MeshInstance3D in ms:
		if mi == keep:
			continue
		if not _check(mi.material_overlay == Readability.rim_material("enemy"), "mesh %s without the rim overlay" % mi.name):
			return false
	if not _check(keep.material_overlay == own and lbl.material_overlay == null, "existing overlay / Label3D changed"):
		return false
	if not _check(b.is_in_group(Readability.GROUP), "root not registered"):
		return false
	print("  B: overlay rim on %d meshes" % n)
	return true


func _part_c() -> bool:
	var b: Node3D = _body()
	var ms: Array = _meshes(b)
	var n: int = Readability.rim(b, "enemy", true)
	if not _check(n == ms.size() and Readability.rimmed_count(b) == ms.size(), "shell rim count %d / %d" % [n, ms.size()]):
		return false
	var skinned: int = 0
	for mi: MeshInstance3D in ms:
		var sh: MeshInstance3D = mi.get_node_or_null(Readability.SHELL_NAME) as MeshInstance3D
		if not _check(sh != null and sh.mesh == mi.mesh and sh.skin == mi.skin and sh.material_override == Readability.rim_material("enemy"), "shell of %s wrong" % mi.name):
			return false
		if not _check(mi.material_overlay == null and sh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "shell mode touched the overlay / casts shadows"):
			return false
		if mi.get_node_or_null(mi.skeleton) is Skeleton3D:
			skinned += 1
			if not _check(sh.get_node_or_null(sh.skeleton) == mi.get_node_or_null(mi.skeleton), "shell of %s does not follow the skeleton" % mi.name):
				return false
	if not _check(skinned >= 1, "no skinned mesh in a rigged body"):
		return false
	Readability.rim(b, "enemy", true)   # twice: no second shell
	for mi: MeshInstance3D in ms:
		var c: int = 0
		for ch: Node in mi.get_children():
			if ch.has_meta("rim_shell_node"):
				c += 1
		if not _check(c == 1, "rim twice made %d shells" % c):
			return false
	print("  C: shell rim on %d meshes (%d skinned)" % [n, skinned])
	return true


func _part_d() -> bool:
	var me := MeleeEnemy.new()
	me.setup("clone", {"seed": 3, "ai": false, "label": "Thử"})
	holder.add_child(me)
	if not _check(me.body.is_in_group(Readability.GROUP) and Readability.rimmed_count(me.body) >= 2, "MeleeEnemy without the shell rim"):
		return false
	var sh: Node = me.body.find_child(Readability.SHELL_NAME, true, false)
	if not _check(sh != null and not me._meshes.has(sh), "MeleeEnemy shells must stay out of its flash list"):
		return false
	var g := Gunman.new()
	g.setup({"seed": 4, "ai": false})
	holder.add_child(g)
	if not _check(Readability.rimmed_count(g.body) >= 2, "Gunman without the rim"):
		return false
	var be := BikerEnemy.new()
	be.setup({"kind": "rider", "seed": 5, "ai": false})
	holder.add_child(be)
	if not _check(Readability.rimmed_count(be) >= 2, "BikerEnemy without the rim"):
		return false
	var ap := AmmoPickup.new()
	holder.add_child(ap)
	if not _check(Readability.rimmed_count(ap) >= 1, "AmmoPickup without the rim"):
		return false
	for mi: MeshInstance3D in _meshes(ap):
		if mi.material_overlay != null and not _check(mi.material_overlay == Readability.rim_material("pickup"), "pickup rim not yellow"):
			return false
	# render budget: extra rim passes per enemy stay few (tiny face meshes are skipped)
	if not _check(Readability.rimmed_count(me.body) <= 8 and Readability.rimmed_count(g.body) <= 12 and Readability.rimmed_count(be) <= 14, "too many rim passes per enemy"):
		return false
	print("  D: MeleeEnemy %d, Gunman %d, BikerEnemy %d, AmmoPickup %d rimmed meshes" % [Readability.rimmed_count(me.body),
		Readability.rimmed_count(g.body), Readability.rimmed_count(be), Readability.rimmed_count(ap)])
	return true


func _total_rimmed() -> int:
	var c: int = 0
	for n: Node in get_nodes_in_group(Readability.GROUP):
		c += Readability.rimmed_count(n)
	return c


func _part_e() -> bool:
	var before: int = _total_rimmed()
	Readability.set_enabled(false)
	if not _check(_total_rimmed() == 0 and not Readability.enabled(), "toggle off left %d rims" % _total_rimmed()):
		return false
	var b: Node3D = _body()
	if not _check(Readability.rim(b, "enemy") == 0 and b.is_in_group(Readability.GROUP), "rim() while off must only register"):
		return false
	Readability.set_enabled(true)
	var after: int = _total_rimmed()
	if not _check(after >= before + 2, "toggle on: %d rims, before %d" % [after, before]):
		return false
	# unrim (knockout / crash): shell and overlay removed, and the setting toggled again does not bring it back
	var me: MeleeEnemy = null
	for n: Node in get_nodes_in_group(Readability.GROUP):
		if n.get_parent() is MeleeEnemy:
			me = n.get_parent() as MeleeEnemy
	if not _check(me != null, "no rimmed MeleeEnemy for unrim"):
		return false
	Readability.unrim(me.body)
	Readability.unrim(b)
	if not _check(Readability.rimmed_count(me.body) == 0 and me.body.find_child(Readability.SHELL_NAME, true, false) == null and Readability.rimmed_count(b) == 0, "unrim left a rim"):
		return false
	Readability.set_enabled(false)
	Readability.set_enabled(true)
	if not _check(Readability.rimmed_count(me.body) == 0 and Readability.rimmed_count(b) == 0 and not b.is_in_group(Readability.GROUP), "an unrimmed root came back with the toggle"):
		return false
	print("  E: toggle off -> 0 rims, on -> %d; unrim (shell + overlay) stays off" % after)
	return true


func _part_f() -> bool:
	var fx: Node = root.get_node_or_null("GameFX")
	if not _check(fx != null, "GameFX autoload missing"):
		return false
	var path0: String = String(fx.get("settings_path"))
	var rim0: bool = bool(fx.get("rim_light"))
	fx.set("settings_path", TMP_SETTINGS)
	var box := VBoxContainer.new()
	var cl := CanvasLayer.new()
	holder.add_child(cl)
	cl.add_child(box)
	fx.call("build_style_settings", box)
	var chk: CheckButton = box.find_child("RimLightCheck", true, false) as CheckButton
	var ok: bool = chk != null and chk.text == "Viền sáng nhân vật" and chk.button_pressed == rim0
	if not _check(ok, "settings panel: RimLightCheck missing or out of sync"):
		fx.set("settings_path", path0)
		return false
	chk.button_pressed = not rim0
	var cfg := ConfigFile.new()
	var loaded: int = cfg.load(TMP_SETTINGS)
	var saved: bool = bool(cfg.get_value("video", "rim_light", rim0))
	var switched: bool = bool(fx.get("rim_light")) == (not rim0) and Readability.enabled() == (not rim0)
	chk.button_pressed = rim0
	fx.set("settings_path", path0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_SETTINGS))
	if not _check(loaded == OK and saved == (not rim0) and switched, "toggle did not switch / save video/rim_light (loaded %d saved %s)" % [loaded, str(saved)]):
		return false
	if not _check(Readability.enabled() == rim0, "toggle back failed"):
		return false
	var sm: Node = root.get_node_or_null("StageManager")
	var psb: Node = sm.get("pause_settings_box") if sm else null
	if not _check(psb != null and psb.find_child("RimLightCheck", true, false) != null, "pause settings without RimLightCheck"):
		return false
	print("  F: settings toggle (panel + pause), saved to a temp path")
	return true


func _part_g() -> bool:
	if not _check(Readability.telegraph_color("danger").r > 0.9 and Readability.telegraph_color("danger").g < 0.3, "danger not red"):
		return false
	if not _check(Readability.telegraph_color("prompt").g > 0.7 and Readability.telegraph_color("prompt").b < 0.4, "prompt not yellow"):
		return false
	if not _check(Readability.telegraph_color("zone").b > 0.9 and Readability.telegraph_color("zone").r < 0.4, "zone not cyan"):
		return false
	var m: StandardMaterial3D = Readability.telegraph_material("zone", 2.0)
	if not _check(m.emission_enabled and m.emission.is_equal_approx(Readability.ZONE) and m.has_meta("vice_done"), "telegraph material"):
		return false
	print("  G: telegraph colours")
	return true
