# File: res://scripts/story/StoryUtil.gd
# Static bridge to the StoryDirector autoload for class_name scripts (spec A2-D1): autoloads only through
# get_node_or_null on the main loop's root, so tests run with --script work without the autoload.
class_name StoryUtil
extends RefCounted

const DEFAULT_NAME: String = "Bạn"


static func _root_node(n: String) -> Node:
	var ml: SceneTree = Engine.get_main_loop() as SceneTree
	if ml == null or ml.root == null:
		return null
	return ml.root.get_node_or_null(n)


static func director() -> Node:
	return _root_node("StoryDirector")


## true while a story is running (free roam in story mode, or a stage launched by a story beat).
static func story_active() -> bool:
	var sd: Node = director()
	return sd != null and bool(sd.get("active"))


## CharacterBuilder opts of the protagonist while a story is running, otherwise `fallback`.
static func hero_opts(fallback: Dictionary = {}) -> Dictionary:
	var sd: Node = director()
	if sd == null or not bool(sd.get("active")) or (sd.get("protagonist") as Dictionary).is_empty():
		return fallback
	var o: Dictionary = sd.call("protagonist_opts")
	o.erase("name")
	return o


static func hero_name() -> String:
	var sd: Node = director()
	if sd == null:
		return DEFAULT_NAME
	return String(sd.call("display_name"))


## Substitutes {name} with the protagonist's name ("Bạn" without a story).
static func fmt(text: String) -> String:
	return text.replace("{name}", hero_name())


## GameFX setting "Giảm hù dọa" (spec A2-D14); false without the autoload.
static func reduce_scares() -> bool:
	var fx: Node = _root_node("GameFX")
	return fx != null and bool(fx.get("reduce_scares"))


## StageManager.story_context (empty outside the story).
static func stage_context() -> Dictionary:
	var sm: Node = _root_node("StageManager")
	if sm == null:
		return {}
	var c: Variant = sm.get("story_context")
	return c if c is Dictionary else {}
