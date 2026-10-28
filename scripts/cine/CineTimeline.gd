# File: res://scripts/cine/CineTimeline.gd
# Data model of one cinematic (spec A1-D8, A1-D9, A1-D10). Each cinematic is a script
# res://scripts/cine/timelines/<slot>.gd that extends CineTimeline and fills it in build() with the helpers below.
# Times: actor cues, shots, FX and SFX in STORY seconds (a hit name may stand for its story time); subtitles in REAL seconds.
# Positions are stage-local (X right, -Z forward along the road, ground y = 0); yaw in degrees, characters face -Z at 0.
class_name CineTimeline
extends RefCounted

const TIMELINE_DIR: String = "res://scripts/cine/timelines/"
const RIGS: Array[String] = ["static", "dolly", "orbit", "low_hero", "track", "crane", "two_shot", "ots", "dutch", "push_in"]
const FX_KINDS: Array[String] = ["sparks", "dust", "flash", "debris", "crate", "stars"]
const TRANSLATED_SPEAKERS: Array[String] = ["Anh Duy"]
const PARTS: Array[String] = ["helmet"]
## Phase B 2D card layers (CinePlayer builds them): StoryVillainCard, StoryScreenCard.
const CARD_KINDS: Array[String] = ["villain", "screen"]
## Q5 stings that may close a day on its cliffhanger (StoryAudio / CineAudio cues; owner files override them).
const STINGS: Array[String] = ["cliff_sting", "dun_dun_duun", "toang_sting", "sub_boom"]

var slot: String = ""
var length: float = 25.0
var story_end: float = 0.0
var music_slot: String = ""
var mood: String = "punchy"   # A1 cue mood; unused since H-D8 (no code music), kept so timelines stay unchanged
var fade_in: float = 0.5
var fade_out: float = 0.5
var letterbox: bool = true
## {landmark, near, size, tod, yaw_deg, offset, fallback, at, exposure, ambient}; Phase B adds "drop_set": true (or
## CinePlayer.setup / FreeRoam.play_cinematic opt "drop_set") to leave out the carried set dressing (props with opts
## "set": true) when the scene is staged inside the real building or the Night Building.
var stage: Dictionary = {}
var clock: CineClock = CineClock.new()
var actors: Dictionary = {}            # id -> {"opts", "name", "color"}
var cues: Array[Dictionary] = []       # {"type": move|strike|key|expr|look|show, "actor", "s", ...}
var shots: Array[Dictionary] = []      # {"id", "s", "rig", "what", "params"}
var subs: Array[Dictionary] = []       # {"r", "dur", "speaker", "text", "tr"}
var sfx: Array[Dictionary] = []        # {"at", "cue", "db"}
var fx: Array[Dictionary] = []         # {"at", "kind", "where", "params"}
var props: Array[Dictionary] = []      # {"id", "kind", "pos", "yaw", "opts"}
var punches: Array[Dictionary] = []    # {"at", "preset"}: camera punch-in / whip on a non-ramp hit
var scare_hits: Array[Dictionary] = [] # {"at", "opts"}: jump scare v2 marks (CineScare): duck before, hit at, twitch
var cards: Array[Dictionary] = []      # {"kind", "r", "dur", "data"}: 2D card layers on REAL time (Phase B)
var choice_def: Dictionary = {}        # {"r", "id", "prompt", "options", "honest", "timeout_line", ...}: StoryChoice (Phase B)
var jokes: Array[Dictionary] = []      # {"r", "what"}: Q5 pacing marks, one joke beat per dialogue scene (REAL time)
var cliff_r: float = -1.0              # Q5: real time of the day-end cliffhanger line (-1 = none); a sting follows it
var _last_yaw: Dictionary = {}         # actor -> last keyed yaw (keeps yaw continuous)


## Filled by each timeline script.
func build() -> void:
	pass


static func slots() -> PackedStringArray:
	var out: PackedStringArray = []
	if not DirAccess.dir_exists_absolute(TIMELINE_DIR):
		return out
	for f: String in ResourceLoader.list_directory(TIMELINE_DIR):
		if f.ends_with(".gd"):
			out.append(f.get_basename())
	out.sort()
	return out


static func load_slot(slot_name: String) -> CineTimeline:
	var path: String = TIMELINE_DIR + slot_name + ".gd"
	if not ResourceLoader.exists(path):
		return null
	var tl: CineTimeline = (load(path) as GDScript).new()
	tl.build()
	if tl.music_slot == "":
		tl.music_slot = tl.slot
	return tl


## Map point (Vector2 x, z) of a campus-plot local point (FPTUCampusBuilder u, v): the explicit stage "at" of story timelines.
static func campus_at(local: Vector3) -> Vector2:
	var w: Vector3 = FPTUCampusBuilder.real_plot_transform() * local
	return Vector2(w.x, w.z)


## Map yaw (degrees) of a campus-plot local yaw (degrees): stage yaw_deg for a direction given in plot coordinates.
static func campus_yaw(local_yaw_deg: float) -> float:
	return local_yaw_deg + FPTUCampusBuilder.REAL_ROT_Y_DEG


## Stage of the Day 4 canteen slots (cine_d4_intro, cine_d4_stare, seg_d4_brawl share it for continuity): the canteen
## hall itself has no clear box (columns, building meshes: FreeRoam.cine_clutter), so the nearest clear spot is used, on
## the courtyard side in front of the canteen (map point measured with FreeRoam.cine_stage: ring 0 at yaw 271). The
## scenes carry their own furniture; staged inside a real hall, pass "xf" and "drop_set" to play_cinematic.
static func canteen_stage(size: Vector2, tod: String) -> Dictionary:
	return {"landmark": "campus_parking_center", "at": Vector2(-31.17, -4.51), "near": 24.0, "size": size, "tod": tod,
		"yaw_deg": 271.0}


## Phase C stages (spec C-D5 / C-D9): explicit map points measured with FreeRoam.cine_stage (ring 0 at these sizes), each
## with a landmark fallback; the lair scenes carry their own set dressing (props with "set": true, see drop_set):
##   "duy_room"  Anh Duy's corner by the BE6 lobby of The Beverly (8 x 8)
##   "bridge"    the bank under / beside the real Rạch Hầm bridge (14 x 10; the deck overhead is carried)
##   "drive"     the road south of the Rạch Hầm bridge, heading to it (7 x 26)
##   "yard"      the container yard by the canal east of the bridge (14 x 12; containers carried)
##   "server"    the server basement under The Beverly tower (14 x 10; staged beside BE6 with carried walls: integration
##               passes "xf" and "drop_set" inside the real basement scene)
const PHASE_C_STAGES: Dictionary = {
	"duy_room": {"at": Vector2(3895.0, -424.0), "size": Vector2(8.0, 8.0), "yaw_deg": 21.0, "landmark": "be6_center"},
	"bridge": {"at": Vector2(2145.0, 150.0), "size": Vector2(14.0, 10.0), "yaw_deg": 0.0, "landmark": "be6_center"},
	"drive": {"at": Vector2(2113.2, 110.87), "size": Vector2(7.0, 26.0), "yaw_deg": 195.6, "landmark": "be6_center"},
	"yard": {"at": Vector2(2180.0, 160.0), "size": Vector2(14.0, 12.0), "yaw_deg": 0.0, "landmark": "be6_center"},
	"server": {"at": Vector2(3930.0, -440.0), "size": Vector2(14.0, 10.0), "yaw_deg": 21.0, "landmark": "be6_center"},
}


static func phase_c_stage(place: String, tod: String = "night") -> Dictionary:
	var d: Dictionary = (PHASE_C_STAGES[place] as Dictionary).duplicate()
	d["near"] = 30.0
	d["tod"] = tod
	d["exposure"] = 1.4
	d["ambient"] = 1.7
	return d


## Yaw in degrees for an actor at `from` to face `to` (characters face -Z at yaw 0).
static func face(from: Vector3, to: Vector3) -> float:
	var d: Vector3 = to - from
	return rad_to_deg(atan2(-d.x, -d.z))


# ---------------------------------------------------------------------------
# Authoring helpers
# ---------------------------------------------------------------------------
func actor(id: String, opts: Dictionary, speaker: String = "", color: Color = Color.WHITE) -> void:
	actors[id] = {"opts": opts, "name": speaker if speaker != "" else id, "color": color}


## over: per-ramp overrides of the preset; {"r": 6.15} places the impact at REAL 6.150 s (s then only orders the hits).
func hit(name: String, s: float, preset: String, what: String, over: Dictionary = {}) -> void:
	var o: Dictionary = over.duplicate()
	o["what"] = what
	clock.add(name, s, preset, o)


func move(actor_id: String, s: float, move_name: String, opts: Dictionary = {}) -> void:
	cues.append({"type": "move", "actor": actor_id, "s": s, "move": move_name, "opts": opts})


## The move's impact frame lands on `at` (a hit name or a story time).
func strike(actor_id: String, at: Variant, move_name: String, opts: Dictionary = {}) -> void:
	cues.append({"type": "strike", "actor": actor_id, "at": at, "s": -1.0, "move": move_name, "opts": opts})


## opts: "mode" (easing of the segment ending here), "arc" (m), "spin" (Vector3 degrees). Yaw stays continuous.
func key(actor_id: String, s: float, pos: Vector3, yaw_deg: float, opts: Dictionary = {}) -> void:
	var y: float = yaw_deg
	if _last_yaw.has(actor_id):
		var prev: float = _last_yaw[actor_id]
		y = prev + wrapf(yaw_deg - prev, -180.0, 180.0)
	_last_yaw[actor_id] = y
	cues.append({"type": "key", "actor": actor_id, "s": s, "pos": pos, "yaw": y, "opts": opts})


func expr(actor_id: String, s: float, cell: String) -> void:
	cues.append({"type": "expr", "actor": actor_id, "s": s, "cell": cell})


## target: another actor id or a stage-local Vector3.
func look(actor_id: String, s0: float, s1: float, target: Variant) -> void:
	cues.append({"type": "look", "actor": actor_id, "s": s0, "s1": s1, "target": target})


func show(actor_id: String, s: float, on: bool) -> void:
	cues.append({"type": "show", "actor": actor_id, "s": s, "on": on})


## The actor holds a prop (CineFX kind) in the hand during story [s0, s1). opts: "bone" (default Wrist.R), "mid" (second bone:
## two-handed), "offset" (m) / "rot" (deg) in the actor's frame, plus the prop's own build options (e.g. "color").
func hold(actor_id: String, s0: float, s1: float, kind: String, opts: Dictionary = {}) -> void:
	cues.append({"type": "hold", "actor": actor_id, "s": s0, "s1": s1, "kind": kind, "opts": opts})


## Hide (on = false) or show a body part of the actor from story time s on (CineActor.part_show: "helmet").
func part(actor_id: String, s: float, part_name: String, on: bool) -> void:
	cues.append({"type": "part", "actor": actor_id, "s": s, "part": part_name, "on": on})


## Camera punch-in (FOV) and whip-pan on a hit without a slow-motion ramp; preset sets the strength (CineShots.WHIP_DEG keys).
func punch(at: Variant, preset: String = "medium") -> void:
	punches.append({"at": at, "preset": preset})


## Jump scare v2 at story time `at` (CinePlayer's CineScare): the music and the other SFX duck over the 0.4 s before it, a
## sharp inhale, then at the hit the screen hit (white frame, red frames, RGB-split + noise overlay, red vignette, shake),
## the FOV punch-in and the +8 dB layered sting with the sub boom; opts "twitch": an actor that twitches through the
## "hold" (default 0.5 s). The face itself is the timeline's own actor, snapped in by its keys. "Giảm hù dọa": a soft sting.
func scare_hit(at: Variant, opts: Dictionary = {}) -> void:
	scare_hits.append({"at": at, "opts": opts})


## A 2D card layer on REAL time [r, r + dur): kind "villain" (StoryVillainCard data) or "screen" (StoryScreenCard data).
func card(kind: String, r: float, dur: float, data: Dictionary = {}) -> void:
	cards.append({"kind": kind, "r": r, "dur": dur, "data": data})


## Villain intro card: a "card" clock ramp named `name` freezes story time for `dur` real seconds from real time r (a pure
## freeze frame: no slow-down, no strike) and StoryVillainCard shows over it (data: name, nick, joke, color, pointer).
func villain(name: String, r: float, dur: float, data: Dictionary) -> void:
	hit(name, 0.0, "card", "villain card: %s" % String(data.get("name", "?")), {"r": r, "freeze": dur})
	card("villain", r, dur, data)


## Choice scene at REAL time r (one per timeline): CinePlayer holds its clock there and opens StoryChoice with def (see
## StoryChoice.gd: id, title, prompt, options [{key, label}] x 2, honest, timeout_line), emits choice_made, then plays on.
func choice(r: float, def: Dictionary) -> void:
	choice_def = def.duplicate()
	choice_def["r"] = r


## Q5 pacing: the scene's joke beat at REAL time r (listed in the beat sheet, checked by tests/test_story_framing.gd).
func joke(r: float, what: String) -> void:
	jokes.append({"r": r, "what": what})


## Q5 day end: the subtitle starting at REAL time r is the cliffhanger line; a sting (STINGS) must play from it to the end.
func cliffhanger(r: float) -> void:
	cliff_r = r


func shot(id: String, s: float, rig: String, what: String, params: Dictionary = {}) -> void:
	shots.append({"id": id, "s": s, "rig": rig, "what": what, "params": params})


# Q1 camera director shot helpers (CineShots documents the opts; each frames its subjects' head and torso inside the
# letterboxed safe area). A timeline may use these instead of raw positions.
## Two-shot of actors a and b from the side of the a->b line (opts: side, dist, height, look_y, fov, push, hand, whip).
func two_shot(id: String, s: float, a: String, b: String, opts: Dictionary = {}) -> void:
	shot(id, s, "two_shot", "two-shot %s + %s" % [a, b], _with({"a": a, "b": b}, opts))


## Over the shoulder of `over` onto `at` (opts: side, back, height, look_y, fov).
func ots_shot(id: String, s: float, over: String, at: String, opts: Dictionary = {}) -> void:
	shot(id, s, "ots", "over %s onto %s" % [over, at], _with({"over": over, "at": at}, opts))


## Low hero angle on an actor (the low_hero rig; opts: side_deg, dist, fov).
func hero_shot(id: String, s: float, actor_id: String, opts: Dictionary = {}) -> void:
	shot(id, s, "low_hero", "hero %s" % actor_id, _with({"actor": actor_id, "fov": 50.0}, opts))


## Dutch angle for a villain (opts: roll, side_deg, dist, height, look_y, fov, push).
func dutch_shot(id: String, s: float, actor_id: String, opts: Dictionary = {}) -> void:
	shot(id, s, "dutch", "dutch %s" % actor_id, _with({"actor": actor_id}, opts))


## Push-in on an actor's face (opts: from, to, side_deg, height, look_y, fov).
func push_in(id: String, s: float, actor_id: String, opts: Dictionary = {}) -> void:
	shot(id, s, "push_in", "push-in %s" % actor_id, _with({"actor": actor_id}, opts))


static func _with(base: Dictionary, opts: Dictionary) -> Dictionary:
	var d: Dictionary = base.duplicate()
	for k: Variant in opts.keys():
		d[k] = opts[k]
	return d


func sub(r: float, dur: float, speaker: String, text: String, tr: String = "") -> void:
	subs.append({"r": r, "dur": dur, "speaker": speaker, "text": text, "tr": tr})


func sfx_at(at: Variant, cue: String, db: float = 0.0) -> void:
	sfx.append({"at": at, "cue": cue, "db": db})


## where: "actor:Bone", "actor", a prop id (kind "crate") or a stage-local Vector3.
func fx_at(at: Variant, kind: String, where: Variant, params: Dictionary = {}) -> void:
	fx.append({"at": at, "kind": kind, "where": where, "params": params})


func prop(id: String, kind: String, pos: Vector3, yaw_deg: float = 0.0, opts: Dictionary = {}) -> void:
	props.append({"id": id, "kind": kind, "pos": pos, "yaw": yaw_deg, "opts": opts})


## Story time of `at`: a hit name -> its ramp's story time, a number -> itself, otherwise -1.
func story_time(at: Variant) -> float:
	if at is String:
		var p: Dictionary = clock.ramp(String(at))
		return float(p["s"]) if not p.is_empty() else -1.0
	if at is float or at is int:
		return float(at)
	return -1.0


func speaker_name(id: String) -> String:
	return String(actors[id]["name"]) if actors.has(id) else id


# ---------------------------------------------------------------------------
# Validation (A1-D8)
# ---------------------------------------------------------------------------
func validate() -> PackedStringArray:
	var err: PackedStringArray = []
	if slot == "":
		err.append("slot is empty")
	clock.length = length
	clock.story_end = story_end
	err.append_array(clock.validate())
	var struck: Dictionary = {}
	for c: Dictionary in cues:
		var aid: String = c["actor"]
		if not actors.has(aid):
			err.append("cue at %.3f: unknown actor %s" % [float(c["s"]), aid])
			continue
		var s: float = float(c["s"])
		if c["type"] == "move" or c["type"] == "strike":
			var mv: String = c["move"]
			if not CineMoves.has_move(mv):
				err.append("%s: unknown move %s" % [aid, mv])
				continue
			var dur: float = float((c["opts"] as Dictionary).get("dur", CineMoves.MOVES[mv]["dur"]))
			if c["type"] == "strike":
				if not CineMoves.is_strike(mv):
					err.append("%s: %s is not a strike move" % [aid, mv])
					continue
				var sh: float = story_time(c["at"])
				if sh < 0.0:
					err.append("%s: strike at unknown hit %s" % [aid, str(c["at"])])
					continue
				if c["at"] is String:
					struck[String(c["at"])] = true
				s = sh - float(CineMoves.MOVES[mv]["hit_u"]) * dur
		if s < -1e-6 or s > story_end + 1e-6:
			err.append("%s %s at story %.3f is outside the story (0..%.3f)" % [aid, String(c["type"]), s, story_end])
		if c["type"] == "look":
			var tg: Variant = c["target"]
			if tg is String and not actors.has(String(tg)):
				err.append("%s: look target %s unknown" % [aid, String(tg)])
		if c["type"] == "hold":
			if not CineFX.PROP_KINDS.has(String(c["kind"])):
				err.append("%s: hold of unknown prop kind %s" % [aid, String(c["kind"])])
			if float(c["s1"]) <= s or float(c["s1"]) > story_end + 1e-6:
				err.append("%s: hold window %.3f-%.3f is empty or past the story end" % [aid, s, float(c["s1"])])
		if c["type"] == "part" and String(c["part"]) not in PARTS:
			err.append("%s: unknown part %s" % [aid, String(c["part"])])
	for p: Dictionary in clock.ramps:
		if float(p["freeze"]) > 0.0 and String(p["preset"]) != "card" and not struck.has(String(p["name"])):
			err.append("%s has no strike cue" % String(p["name"]))
	if shots.is_empty():
		err.append("no shots")
	else:
		if absf(float(shots[0]["s"])) > 1e-6:
			err.append("first shot starts at %.3f, must start at 0" % float(shots[0]["s"]))
		for i: int in shots.size():
			var sh2: Dictionary = shots[i]
			if not RIGS.has(String(sh2["rig"])):
				err.append("shot %s: unknown rig %s" % [String(sh2["id"]), String(sh2["rig"])])
			for key: String in CineShots.HELPER_ACTORS.get(String(sh2["rig"]), []):
				if not actors.has(String((sh2["params"] as Dictionary).get(key, ""))):
					err.append("shot %s: %s names no actor" % [String(sh2["id"]), key])
			if i > 0 and float(sh2["s"]) <= float(shots[i - 1]["s"]):
				err.append("shot %s does not start after %s" % [String(sh2["id"]), String(shots[i - 1]["id"])])
			if float(sh2["s"]) >= story_end:
				err.append("shot %s starts after the story end" % String(sh2["id"]))
	for sb: Dictionary in subs:
		if float(sb["r"]) < 0.0 or float(sb["r"]) + float(sb["dur"]) > length + 1e-6:
			err.append("subtitle '%s' outside 0..%.3f s" % [String(sb["text"]), length])
		if TRANSLATED_SPEAKERS.has(speaker_name(String(sb["speaker"]))) and String(sb["tr"]) == "":
			err.append("subtitle '%s' by %s needs a translation (Dịch:)" % [String(sb["text"]), speaker_name(String(sb["speaker"]))])
	var prop_ids: Dictionary = {}
	for pr: Dictionary in props:
		if prop_ids.has(pr["id"]):
			err.append("duplicate prop id %s" % String(pr["id"]))
		prop_ids[pr["id"]] = true
	for pu: Dictionary in punches:
		var sp: float = story_time(pu["at"])
		if sp < 0.0 or sp > story_end + 1e-6:
			err.append("punch at %s is outside the story" % str(pu["at"]))
		if not CineShots.WHIP_DEG.has(String(pu["preset"])):
			err.append("punch at %s: unknown preset %s" % [str(pu["at"]), String(pu["preset"])])
	for sh3: Dictionary in scare_hits:
		var sst: float = story_time(sh3["at"])
		if sst < 0.0 or sst > story_end + 1e-6:
			err.append("scare_hit at %s is outside the story" % str(sh3["at"]))
		elif clock.real_at(sst) < CineScare.DUCK_S - 1e-6:
			err.append("scare_hit at %s leaves no room for the %.1f s duck before it" % [str(sh3["at"]), CineScare.DUCK_S])
		var tw: String = String((sh3["opts"] as Dictionary).get("twitch", ""))
		if tw != "" and not actors.has(tw):
			err.append("scare_hit at %s: twitch actor %s unknown" % [str(sh3["at"]), tw])
	for pr2: Dictionary in props:
		if not CineFX.PROP_KINDS.has(String(pr2["kind"])):
			err.append("prop %s: unknown kind %s" % [String(pr2["id"]), String(pr2["kind"])])
	for e: Dictionary in sfx + fx:
		var st: float = story_time(e["at"])
		if st < 0.0 or st > story_end + 1e-6:
			err.append("%s at %s is outside the story" % [String(e.get("cue", e.get("kind", "?"))), str(e["at"])])
	for e1: Dictionary in sfx:
		if not CineAudio.SFX_CUES.has(String(e1["cue"])) and not StoryAudio.is_cue(String(e1["cue"])):
			err.append("unknown sfx cue %s (known: %s, %s)" % [String(e1["cue"]), ", ".join(CineAudio.SFX_CUES), ", ".join(StoryAudio.CUES)])
	for e2: Dictionary in fx:
		if not FX_KINDS.has(String(e2["kind"])):
			err.append("unknown fx kind %s" % String(e2["kind"]))
		elif String(e2["kind"]) == "crate" and not prop_ids.has(e2["where"]):
			err.append("crate fx needs a prop id, got %s" % str(e2["where"]))
		var wh: Variant = e2["where"]
		if wh is String:
			# "actor:Bone" or "actor" must name an existing actor; a bare id may also be a prop (plan review Minor 9)
			var who: String = String(wh).get_slice(":", 0)
			if not actors.has(who) and (String(wh).contains(":") or not prop_ids.has(who)):
				err.append("%s fx at %s: unknown actor %s" % [String(e2["kind"]), str(e2["at"]), who])
		elif not wh is Vector3:
			err.append("%s fx at %s: where must be an actor, a prop id or a Vector3" % [String(e2["kind"]), str(e2["at"])])
	if not stage.is_empty() and not stage.has("landmark"):
		err.append("stage needs a landmark")
	for cd: Dictionary in cards:
		if not CARD_KINDS.has(String(cd["kind"])):
			err.append("unknown card kind %s" % String(cd["kind"]))
		if float(cd["r"]) < 0.0 or float(cd["dur"]) <= 0.0 or float(cd["r"]) + float(cd["dur"]) > length + 1e-6:
			err.append("%s card at %.3f (+%.3f) outside 0..%.3f s" % [String(cd["kind"]), float(cd["r"]), float(cd["dur"]), length])
	for p2: Dictionary in clock.ramps:
		var has_card: bool = cards.any(func(cd2: Dictionary) -> bool: return String(cd2["kind"]) == "villain" and absf(float(cd2["r"]) - float(p2["r_hit"])) < 0.001)
		if String(p2["preset"]) == "card" and not has_card:
			err.append("%s: card freeze without a villain card at real %.3f" % [String(p2["name"]), float(p2["r_hit"])])
	for jk: Dictionary in jokes:
		if float(jk["r"]) < 0.0 or float(jk["r"]) > length + 1e-6:
			err.append("joke '%s' at %.3f outside 0..%.3f s" % [String(jk["what"]), float(jk["r"]), length])
	if cliff_r >= 0.0:
		if not subs.any(func(sb: Dictionary) -> bool: return absf(float(sb["r"]) - cliff_r) < 0.001):
			err.append("cliffhanger at %.3f: no subtitle starts there" % cliff_r)
		var stung: bool = false
		for e3: Dictionary in sfx:
			var rr3: float = clock.real_at(story_time(e3["at"])) if story_time(e3["at"]) >= 0.0 else -1.0
			if STINGS.has(String(e3["cue"])) and rr3 >= cliff_r - 0.5 and rr3 <= length:
				stung = true
		if not stung:
			err.append("cliffhanger at %.3f: no sting (%s) after it" % [cliff_r, ", ".join(STINGS)])
	if not choice_def.is_empty():
		var opts: Array = choice_def.get("options", [])
		var keys: Array = opts.map(func(o: Dictionary) -> String: return String(o.get("key", "")))
		if String(choice_def.get("id", "")) == "" or opts.size() != 2 or keys.has(""):
			err.append("choice needs an id and two options with keys")
		elif not keys.has(String(choice_def.get("honest", ""))):
			err.append("choice honest option %s is not one of %s" % [String(choice_def.get("honest", "")), str(keys)])
		if float(choice_def["r"]) < 0.0 or float(choice_def["r"]) > length + 1e-6:
			err.append("choice at %.3f outside 0..%.3f s" % [float(choice_def["r"]), length])
	return err


# ---------------------------------------------------------------------------
# Beat sheet (A1-D9): every time in REAL seconds
# ---------------------------------------------------------------------------
func beat_sheet() -> String:
	clock.length = length
	clock.story_end = story_end
	clock.build()
	var ms: String = music_slot if music_slot != "" else slot
	var last_r1: float = float(clock.ramps[clock.ramps.size() - 1]["r1"]) if not clock.ramps.is_empty() else 0.0
	var L: PackedStringArray = []
	L.append("# %s - beat sheet (generated by tools/cine_beats.gd from scripts/cine/timelines/%s.gd; do not edit)" % [slot, slot])
	L.append("# Real length: %.3f s. Story length: %.3f s. Normal speed from %.3f to %.3f (tail %.3f s)." % [length, story_end, last_r1, length, length - last_r1])
	L.append("# Music slot %s: user://music/%s.ogg or .mp3 starts at 0.000; a longer file fades out %.3f-%.3f; no file = no music." % [ms, ms, maxf(length - 0.5, 0.0), length])
	L.append("#")
	L.append("# id   kind      real_hit  freeze_end  slowmo_from  slowmo_to  speed  story_s  what")
	for row: Dictionary in clock.beat_rows():
		L.append("%-4s %-9s %8.3f %11.3f %12.3f %10.3f %6.2f %8.3f  %s" % [String(row["name"]), String(row["preset"]), float(row["r_hit"]),
			float(row["r_freeze_end"]), float(row["r_start"]), float(row["r_end"]), 0.0 if String(row["preset"]) == "card" else float(row["k"]),
			float(row["s"]), String(row["what"]) + (" (freeze frame)" if String(row["preset"]) == "card" else "")])
	L.append("#")
	L.append("# Shots (real start, rig, what)")
	for sh: Dictionary in shots:
		L.append("SHOT %-4s %8.3f  %-8s  %s" % [String(sh["id"]), clock.real_at(float(sh["s"])), String(sh["rig"]), String(sh["what"])])
	L.append("#")
	L.append("# Subtitles (real start - end, speaker: line)")
	for sb: Dictionary in subs:
		var line: String = "SUB %8.3f - %6.3f  %s: %s" % [float(sb["r"]), float(sb["r"]) + float(sb["dur"]), speaker_name(String(sb["speaker"])), String(sb["text"])]
		if String(sb["tr"]) != "":
			line += "  /  " + String(sb["tr"])
		L.append(line)
	if not scare_hits.is_empty():
		L.append("#")
		L.append("# Jump scares v2 (real hit, duck from, twitching actor)")
		for sh4: Dictionary in scare_hits:
			var rh: float = clock.real_at(story_time(sh4["at"]))
			L.append("SCARE %8.3f  duck %6.3f  %s" % [rh, rh - CineScare.DUCK_S, String((sh4["opts"] as Dictionary).get("twitch", "-"))])
	if not cards.is_empty():
		L.append("#")
		L.append("# Cards (real start - end, kind: what)")
		for cd: Dictionary in cards:
			var dd: Dictionary = cd["data"]
			var what: String = String(dd.get("name", ""))
			if String(cd["kind"]) == "screen":
				what = "%s %s" % [String(dd.get("kind", "")), String(dd.get("text", dd.get("place", "")))]
			L.append("CARD %8.3f - %6.3f  %s: %s" % [float(cd["r"]), float(cd["r"]) + float(cd["dur"]), String(cd["kind"]), what.strip_edges()])
	if not jokes.is_empty() or cliff_r >= 0.0:
		L.append("#")
		L.append("# Pacing (Q5): joke beats and the day-end cliffhanger (real time)")
		for jk2: Dictionary in jokes:
			L.append("JOKE %8.3f  %s" % [float(jk2["r"]), String(jk2["what"])])
		if cliff_r >= 0.0:
			L.append("CLIFF %7.3f" % cliff_r)
	if not choice_def.is_empty():
		L.append("#")
		var labels: PackedStringArray = []
		for o: Dictionary in choice_def.get("options", []):
			labels.append("%s = %s" % [String(o.get("key", "")), String(o.get("label", ""))])
		L.append("CHOICE %6.3f  %s: %s  (timeout %.0f s -> %s)" % [float(choice_def["r"]), String(choice_def.get("id", "")), " | ".join(labels),
			StoryChoice.TIMEOUT, String(choice_def.get("honest", ""))])
	return "\n".join(L) + "\n"
