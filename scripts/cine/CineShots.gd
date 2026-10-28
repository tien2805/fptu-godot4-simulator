# File: res://scripts/cine/CineShots.gd
# Camera rigs of the cinematic player (spec A1-D11). eval() returns the camera of a shot at REAL progress u (0..1) inside the
# shot, so bullet-time orbits keep moving through freezes; positions are stage-local. whip() adds the whip-pan (yaw pulse),
# FOV punch and freeze shake of every impact inside the shot. Rig params:
#   static   pos, look, fov                  dolly / crane  from, to, look_from, look_to, fov (crane eases out)
#   orbit    center | center_actor (+center_y), radius, deg_from, deg_to, height | height_from..height_to, fov
#            (camera at center + (sin a·r, 0, cos a·r), y = height; constant angular speed)
#   low_hero actor, side_deg, dist, fov      (0.25 m above ground in front-side of the actor, looking up at its chest)
#   track    actor, offset, look (offset from the actor or from look_actor), fov
# Q1 camera director shot helpers (spec 2026-10-29 Q1; CineTimeline.two_shot / ots_shot / hero_shot / dutch_shot /
# push_in name them): they frame head, chest and hips of their subjects inside the letterboxed 8 % safe area
# (tests/test_camera_director.gd part S). Positions follow the actors as they move.
#   two_shot a, b, side (+1: camera on the right of the a->b line), dist (0 = fit both: two_shot_dist), height 1.45,
#            look_y 1.3, fov 40, push (0..1 of the distance over the shot, never closer than medium_min_dist)
#   ots      over, at, side (+1: over the right shoulder of `over`), back 1.1, height 1.6, look_y 1.3, fov 42 (the camera
#            moves out sideways for close actors so the face stays OTS_CLEAR beside the foreground head)
#   dutch    actor, roll (deg, default 14; villains), side_deg 25 (off the actor's facing), dist 2.8, height 1.15, look_y 1.3,
#            fov 45, push 0.1
#   push_in  actor, from 4.2, to 2.2 (m in front of the actor; never closer than medium_min_dist), side_deg 0, height 1.5,
#            look_y 1.3, fov 40 (eased dolly ending on a medium close-up)
#   low_hero (above) is the hero angle: CineTimeline.hero_shot.
# A rig may return "roll" (deg, about the view axis); CinePlayer applies it.
# Every rig also takes "hand" (handheld feel, 0 = locked off, 1 = a tight handheld operator; see handheld()) and "whip"
# (false = no whip / punch-in on the hits inside the shot).
class_name CineShots
extends RefCounted

const WHIP_DEG: Dictionary = {"light": 6.0, "medium": 9.0, "heavy": 12.0, "finisher": 12.0, "accent": 4.0, "card": 0.0}
const FOV_PUNCH: Dictionary = {"light": -2.0, "medium": -4.0, "heavy": -7.0, "finisher": -8.0, "accent": 0.0, "card": 0.0}
const ASPECT: float = 16.0 / 9.0
const SAFE: float = 0.08
const BODY_MARGIN: float = 0.55          # m beside each actor of a two-shot (shoulders, a raised arm)
const LETTERBOX_BAND: float = 0.744      # picture height left between the 2.39:1 bars at 16:9
const BODY_HALF_H: float = 0.45          # m above / below look_y a medium shot keeps (head centre .. hips)
const OTS_CLEAR: float = 0.32            # m the view to the subject's face passes beside the foreground head
## Rigs of the Q1 shot helpers and their actor params (CineTimeline.validate checks them).
const HELPER_ACTORS: Dictionary = {"two_shot": ["a", "b"], "ots": ["over", "at"], "dutch": ["actor"], "push_in": ["actor"]}


static func _apos(ctx: Dictionary, id: String) -> Vector3:
	var a: Node3D = (ctx["actors"] as Dictionary).get(id)
	return a.position if a else Vector3.ZERO


static func _ayaw(ctx: Dictionary, id: String) -> float:
	var a: Node3D = (ctx["actors"] as Dictionary).get(id)
	return a.rotation.y if a else 0.0


## Horizontal half-extent (tan) of the 8 % safe area at a vertical fov (deg), 16:9.
static func safe_tan_h(fov: float) -> float:
	return tan(deg_to_rad(fov) * 0.5) * ASPECT * (1.0 - 2.0 * SAFE)


## Closest a medium shot comes at a vertical fov (deg): BODY_HALF_H above and below the look point inside the
## letterboxed safe area.
static func medium_min_dist(fov: float) -> float:
	return BODY_HALF_H / (tan(deg_to_rad(fov) * 0.5) * LETTERBOX_BAND * (1.0 - 2.0 * SAFE)) + 0.2


## Two-shot distance that keeps both actors (sep m apart) plus BODY_MARGIN inside the safe area (and the medium minimum).
static func two_shot_dist(sep: float, fov: float) -> float:
	return maxf(medium_min_dist(fov), (sep * 0.5 + BODY_MARGIN) / safe_tan_h(fov) + 0.3)


static func eval(shot: Dictionary, u: float, ctx: Dictionary) -> Dictionary:
	var p: Dictionary = shot["params"]
	var e: float = u * u * (3.0 - 2.0 * u)
	var fov: float = float(p.get("fov", 50.0))
	match String(shot["rig"]):
		"static":
			return {"pos": p["pos"], "look": p["look"], "fov": fov}
		"dolly", "crane":
			var ee: float = e if String(shot["rig"]) == "dolly" else 1.0 - (1.0 - u) * (1.0 - u)
			return {"pos": (p["from"] as Vector3).lerp(p["to"], ee), "look": (p["look_from"] as Vector3).lerp(p["look_to"], ee), "fov": fov}
		"orbit":
			var c: Vector3 = p["center"] if p.has("center") else _apos(ctx, String(p["center_actor"])) + Vector3(0.0, float(p.get("center_y", 1.2)), 0.0)
			var a: float = deg_to_rad(lerpf(float(p["deg_from"]), float(p["deg_to"]), u))
			var h: float = float(p["height"]) if p.has("height") else lerpf(float(p.get("height_from", 1.2)), float(p.get("height_to", 1.2)), e)
			var r: float = p["radius"]
			return {"pos": Vector3(c.x + sin(a) * r, h, c.z + cos(a) * r), "look": c, "fov": fov}
		"low_hero":
			var act: Node3D = (ctx["actors"] as Dictionary).get(String(p["actor"]))
			var ap: Vector3 = act.position if act else Vector3.ZERO
			var yaw: float = (act.rotation.y if act else 0.0) + deg_to_rad(float(p.get("side_deg", 30.0)))
			var dir := Vector3(-sin(yaw), 0.0, -cos(yaw))
			var dist: float = float(p.get("dist", 2.2)) * (1.0 - 0.1 * e)
			return {"pos": ap + dir * dist + Vector3(0.0, 0.25, 0.0), "look": ap + Vector3(0.0, 1.25, 0.0), "fov": fov}
		"track":
			var base: Vector3 = _apos(ctx, String(p["actor"]))
			var look_base: Vector3 = _apos(ctx, String(p["look_actor"])) if p.has("look_actor") else base
			return {"pos": base + (p["offset"] as Vector3), "look": look_base + (p.get("look", Vector3(0.0, 1.2, 0.0)) as Vector3), "fov": fov}
		"two_shot":
			var fa: float = float(p.get("fov", 40.0))
			var pa: Vector3 = _apos(ctx, String(p["a"]))
			var pb: Vector3 = _apos(ctx, String(p["b"]))
			var ab := Vector3(pb.x - pa.x, 0.0, pb.z - pa.z)
			var sep: float = ab.length()
			var along: Vector3 = ab / sep if sep > 0.01 else Vector3.RIGHT
			var perp := Vector3(-along.z, 0.0, along.x) * (-1.0 if float(p.get("side", 1.0)) >= 0.0 else 1.0)
			var d2: float = float(p.get("dist", 0.0))
			if d2 <= 0.0:
				d2 = two_shot_dist(sep, fa)
			d2 = maxf(d2 * (1.0 - float(p.get("push", 0.0)) * e), medium_min_dist(fa))
			var mid: Vector3 = (pa + pb) * 0.5
			return {"pos": mid + perp * d2 + Vector3(0.0, float(p.get("height", 1.45)), 0.0), "look": mid + Vector3(0.0, float(p.get("look_y", 1.3)), 0.0), "fov": fa}
		"ots":
			var fo: float = float(p.get("fov", 42.0))
			var po: Vector3 = _apos(ctx, String(p["over"]))
			var pt: Vector3 = _apos(ctx, String(p["at"]))
			var dir := Vector3(pt.x - po.x, 0.0, pt.z - po.z)
			dir = dir.normalized() if dir.length_squared() > 1e-4 else Vector3.FORWARD
			var rt := Vector3(-dir.z, 0.0, dir.x) * (1.0 if float(p.get("side", 1.0)) >= 0.0 else -1.0)
			var sep_o: float = maxf(Vector2(pt.x - po.x, pt.z - po.z).length(), 0.5)
			var back: float = maxf(float(p.get("back", 1.1)), medium_min_dist(fo) - sep_o)   # the subject never closer than a medium
			var lat: float = maxf(0.45, OTS_CLEAR * (sep_o + back) / sep_o)   # close actors: wider, so the face stays clear
			var cam_p: Vector3 = po - dir * back + rt * lat + Vector3(0.0, float(p.get("height", 1.6)), 0.0)
			return {"pos": cam_p, "look": pt + Vector3(0.0, float(p.get("look_y", 1.3)), 0.0) - rt * 0.2, "fov": fo}
		"dutch":
			var fd: float = float(p.get("fov", 45.0))
			var ad: Vector3 = _apos(ctx, String(p["actor"]))
			var yd: float = _ayaw(ctx, String(p["actor"])) + deg_to_rad(float(p.get("side_deg", 25.0)))
			var dd: float = float(p.get("dist", 2.8)) * (1.0 - float(p.get("push", 0.1)) * e)
			return {"pos": ad + Vector3(-sin(yd), 0.0, -cos(yd)) * dd + Vector3(0.0, float(p.get("height", 1.15)), 0.0),
				"look": ad + Vector3(0.0, float(p.get("look_y", 1.3)), 0.0), "fov": fd, "roll": float(p.get("roll", 14.0))}
		"push_in":
			var fp: float = float(p.get("fov", 40.0))
			var ap2: Vector3 = _apos(ctx, String(p["actor"]))
			var yp: float = _ayaw(ctx, String(p["actor"])) + deg_to_rad(float(p.get("side_deg", 0.0)))
			var dp: float = maxf(lerpf(float(p.get("from", 4.2)), float(p.get("to", 2.2)), e), medium_min_dist(fp))
			return {"pos": ap2 + Vector3(-sin(yp), 0.0, -cos(yp)) * dp + Vector3(0.0, float(p.get("height", 1.5)), 0.0),
				"look": ap2 + Vector3(0.0, float(p.get("look_y", 1.3)), 0.0), "fov": fp}
	return {"pos": Vector3(0.0, 2.0, 5.0), "look": Vector3.ZERO, "fov": fov}


## Whip-pan of the impacts inside [shot_r0, shot_r1): yaw pulse (deg, alternating sides), FOV punch, freeze shake (m).
static func whip(r: float, shot_r0: float, shot_r1: float, rows: Array[Dictionary], enabled: bool = true) -> Dictionary:
	var out: Dictionary = {"yaw": 0.0, "fov": 0.0, "shake": Vector3.ZERO}
	if not enabled:
		return out
	var side: float = 1.0
	for row: Dictionary in rows:
		var rh: float = row["r_hit"]
		if rh < shot_r0 or rh >= shot_r1:
			continue
		var dt: float = r - rh
		var pre: String = row["preset"]
		if dt > -0.15 and dt < 0.3:
			out["yaw"] = float(out["yaw"]) + side * float(WHIP_DEG.get(pre, 6.0)) * exp(-pow(dt / 0.06, 2.0))
		if dt >= 0.0 and dt < 0.8:
			out["fov"] = float(out["fov"]) + float(FOV_PUNCH.get(pre, 0.0)) * exp(-dt / 0.25)
		var fr: float = row["freeze"]
		if dt >= 0.0 and dt <= fr and pre != "card":
			var amp: float = 0.012 if pre == "light" else 0.02
			out["shake"] = Vector3(sin(r * 97.0), sin(r * 131.0 + 1.3), 0.0) * amp
		side = -side
	return out


## Handheld camera noise at story time s: {"pos": m (camera frame), "rot": deg (pitch, yaw, roll)}. Sums of incommensurate
## sines of s, so it is deterministic and seekable, crawls in slow motion and holds still in a freeze; amp 1 ~ 1.5 cm / 0.6°.
static func handheld(s: float, amp: float) -> Dictionary:
	if amp <= 0.0:
		return {"pos": Vector3.ZERO, "rot": Vector3.ZERO}
	var pos := Vector3(sin(s * 1.7 + 0.3) * 0.6 + sin(s * 4.3 + 1.1) * 0.4,
		sin(s * 2.3 + 2.0) * 0.6 + sin(s * 5.1 + 0.7) * 0.4,
		sin(s * 1.3 + 0.9) * 0.5) * (0.015 * amp)
	var rot := Vector3(sin(s * 2.1 + 0.5) * 0.6 + sin(s * 5.7 + 2.2) * 0.4,
		sin(s * 1.9 + 1.4) * 0.6 + sin(s * 4.9 + 0.2) * 0.4,
		sin(s * 1.1 + 2.6) * 0.5) * (0.6 * amp)
	return {"pos": pos, "rot": rot}
