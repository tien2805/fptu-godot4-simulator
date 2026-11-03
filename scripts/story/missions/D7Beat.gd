# File: res://scripts/story/missions/D7Beat.gd
# Day 7 floor beats (plan 2026-11-03-w5-day7.md T1): the readability rule's preview cut on a floor's hazard and, on the floors
# with a returning villain, the return beat. A child node of the mission that plays one beat at a time:
#   cut(target, opts)           a CameraDirector.preview_cut (CUT_S real seconds, slow motion) on target; "up" / "dist" for
#                               the low rooms (the deck, the servers, the showroom, the laser corridor). false when no director
#                               or another cut runs (the cut is skipped, never queued).
#   play(target, opts)          the beat: when `gate` (opts, a Callable -> bool) allows (the chase's own cameras free, the
#                               countdown over; tried for at most WAIT_S real seconds, then the cut is skipped), the cut on
#                               target; then, when opts "card" names a CastD7 villain card whose save flag "flag" is not set
#                               yet, the card over a FREEZE of the cut's last frame (the villain framed: a camera of this node
#                               holds the director camera's last transform while the card pauses the tree), then the camera
#                               of before. Emits card_shown(card) and finished (always, also with no cut and no card).
#   cancel()                    ends the beat at once (the mission's THỬ LẠI / cleanup): idle, the card freed, the camera
#                               of before; no `finished` (the mission resets its own state). A beat whose mission no
#                               longer runs (failed, done) cancels itself: no card over the fail screen, its flag unspent.
# Counters: cuts (the cuts that ran), cards. Tests: opts "manual_card" (the card is stepped by the test).
class_name D7Beat
extends Node

signal card_shown(card: StoryVillainCard)
signal finished

const CUT_S: float = 0.7
const WAIT_S: float = 2.5

var cuts: int = 0
var cards: int = 0
## idle | wait (the gate) | cut | card
var state: String = "idle"
var target: Node3D = null
var card: StoryVillainCard = null
var freeze_cam: Camera3D = null
var _opts: Dictionary = {}
var _wait_us: int = 0
var _cut_id: int = -1
var _prev_cam: Camera3D = null


func _init() -> void:
	name = "D7Beat"


## A preview cut on target (true when it runs).
func cut(t: Node3D, opts: Dictionary = {}) -> bool:
	var cd: CameraDirector = CameraDirector.live()
	if cd == null or t == null or not is_instance_valid(t) or not t.is_inside_tree() or cd.cutting():
		return false
	var vp: Viewport = get_viewport() if is_inside_tree() else null
	var prev: Camera3D = vp.get_camera_3d() if vp else null
	if not cd.preview_cut(t, float(opts.get("secs", CUT_S)), opts):
		return false
	_prev_cam = prev
	_cut_id = cd.cuts
	cuts += 1
	return true


## The beat (see the header). A beat already running is replaced.
func play(t: Node3D, opts: Dictionary = {}) -> void:
	target = t
	_opts = opts
	state = "wait"
	_wait_us = Time.get_ticks_usec()
	_try_cut()


func busy() -> bool:
	return state != "idle"


## Ends the beat now (see the header): idle, no target, the card (if any) freed, the frozen camera handed back.
func cancel() -> void:
	var c: StoryVillainCard = card
	card = null
	state = "idle"
	target = null
	_opts = {}
	if c != null and is_instance_valid(c):
		if c.finished.is_connected(_on_card_done):
			c.finished.disconnect(_on_card_done)
		c.queue_free()                         # its _exit_tree gives the pause state back
	_unfreeze()


## The owning mission still runs (a beat outside a mission: always).
func _live() -> bool:
	var m: StoryMission = get_parent() as StoryMission
	return m == null or m.state == "running"


func _try_cut() -> void:
	if not _live():
		cancel()
		return
	var gate: Callable = _opts.get("gate", Callable())
	var open: bool = not gate.is_valid() or bool(gate.call())
	if open and cut(target, _opts):
		state = "cut"
		return
	if open or float(Time.get_ticks_usec() - _wait_us) / 1e6 >= WAIT_S or target == null or not is_instance_valid(target):
		_after_cut(false)


func _process(_d: float) -> void:
	match state:
		"wait":
			_try_cut()
		"cut":
			var cd: CameraDirector = CameraDirector.live()
			if cd == null or not (cd.cut_kind == "preview" and cd.cuts == _cut_id):
				_after_cut(true)


## The cut is over (or skipped): the card when one is due, else done.
func _after_cut(had_cut: bool) -> void:
	if not _live():                            # the mission failed meanwhile: no card over its fail screen
		cancel()
		return
	var cid: String = String(_opts.get("card", ""))
	var flag: String = String(_opts.get("flag", ""))
	var flags: Dictionary = {}
	var sd: Node = StoryUtil.director()
	if sd:
		flags = sd.get("flags")
	if cid == "" or (flag != "" and bool(flags.get(flag, false))):
		_done()
		return
	if flag != "":
		flags[flag] = true
	var vp: Viewport = get_viewport() if is_inside_tree() else null
	if had_cut and vp and vp.get_camera_3d() == _prev_cam:   # the director handed back (nobody else took the screen)
		_freeze()
	card = StoryVillainCard.show_for(get_parent() if get_parent() else self, CastD7.villain_data(cid), CastD7.card_len(cid))
	if bool(_opts.get("manual_card", false)):
		card.manual = true
	cards += 1
	state = "card"
	card.finished.connect(_on_card_done, CONNECT_ONE_SHOT)
	card.tree_exiting.connect(_unfreeze, CONNECT_ONE_SHOT)
	card_shown.emit(card)


## Holds the director camera's last frame (the villain framed) while the card shows.
func _freeze() -> void:
	var cd: CameraDirector = CameraDirector.live()
	if cd == null or cd.cam == null or not is_instance_valid(cd.cam) or not is_inside_tree():
		return
	if freeze_cam == null:
		freeze_cam = Camera3D.new()
		freeze_cam.name = "FreezeCam"
		freeze_cam.top_level = true
		add_child(freeze_cam)
	freeze_cam.global_transform = cd.cam.global_transform
	freeze_cam.fov = cd.cam.fov
	freeze_cam.near = cd.cam.near
	freeze_cam.far = cd.cam.far
	freeze_cam.make_current()


func _unfreeze() -> void:
	if freeze_cam != null and is_instance_valid(freeze_cam) and freeze_cam.current:
		if _prev_cam != null and is_instance_valid(_prev_cam) and _prev_cam.is_inside_tree():
			_prev_cam.make_current()
		else:
			freeze_cam.clear_current(true)


func _on_card_done() -> void:
	_unfreeze()
	card = null
	_done()


func _done() -> void:
	state = "idle"
	finished.emit()


func _exit_tree() -> void:
	_unfreeze()
