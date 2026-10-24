# File: res://scripts/cine/CineTimeline.gd
# Data model of one cinematic (spec A1-D8, A1-D9, A1-D10). Each cinematic is a script
# res://scripts/cine/timelines/<slot>.gd that extends CineTimeline and fills it in build() with the helpers below.
# Times: actor cues, shots, FX and SFX in STORY seconds (a hit name may stand for its story time); subtitles in REAL seconds.
# Positions are stage-local (X right, -Z forward along the road, ground y = 0); yaw in degrees, characters face -Z at 0.
class_name CineTimeline
extends RefCounted

const TIMELINE_DIR: String = "res://scripts/cine/timelines/"
const RIGS: Array[String] = ["static", "dolly", "orbit", "low_hero", "track", "crane"]
const FX_KINDS: Array[String] = ["sparks", "dust", "flash", "debris", "crate", "stars"]
const TRANSLATED_SPEAKERS: Array[String] = ["Anh Duy"]
const PARTS: Array[String] = ["helmet"]

var slot: String = ""
var length: float = 25.0
var story_end: float = 0.0
var music_slot: String = ""
var mood: String = "punchy"
var fade_in: float = 0.5
var fade_out: float = 0.5
var letterbox: bool = true
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


func shot(id: String, s: float, rig: String, what: String, params: Dictionary = {}) -> void:
	shots.append({"id": id, "s": s, "rig": rig, "what": what, "params": params})


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
		if float(p["freeze"]) > 0.0 and not struck.has(String(p["name"])):
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
	for pr2: Dictionary in props:
		if not CineFX.PROP_KINDS.has(String(pr2["kind"])):
			err.append("prop %s: unknown kind %s" % [String(pr2["id"]), String(pr2["kind"])])
	for e: Dictionary in sfx + fx:
		var st: float = story_time(e["at"])
		if st < 0.0 or st > story_end + 1e-6:
			err.append("%s at %s is outside the story" % [String(e.get("cue", e.get("kind", "?"))), str(e["at"])])
	for e1: Dictionary in sfx:
		if not CineAudio.SFX_CUES.has(String(e1["cue"])):
			err.append("unknown sfx cue %s (known: %s)" % [String(e1["cue"]), ", ".join(CineAudio.SFX_CUES)])
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
	L.append("# Music slot %s: user://music/%s.ogg or .mp3 starts at 0.000; a longer file fades out %.3f-%.3f; no file = synthesized cue." % [ms, ms, maxf(length - 0.5, 0.0), length])
	L.append("#")
	L.append("# id   kind      real_hit  freeze_end  slowmo_from  slowmo_to  speed  story_s  what")
	for row: Dictionary in clock.beat_rows():
		L.append("%-4s %-9s %8.3f %11.3f %12.3f %10.3f %6.2f %8.3f  %s" % [String(row["name"]), String(row["preset"]), float(row["r_hit"]),
			float(row["r_freeze_end"]), float(row["r_start"]), float(row["r_end"]), float(row["k"]), float(row["s"]), String(row["what"])])
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
	return "\n".join(L) + "\n"
