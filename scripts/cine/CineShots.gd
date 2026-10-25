# File: res://scripts/cine/CineShots.gd
# Camera rigs of the cinematic player (spec A1-D11). eval() returns the camera of a shot at REAL progress u (0..1) inside the
# shot, so bullet-time orbits keep moving through freezes; positions are stage-local. whip() adds the whip-pan (yaw pulse),
# FOV punch and freeze shake of every impact inside the shot. Rig params:
#   static   pos, look, fov                  dolly / crane  from, to, look_from, look_to, fov (crane eases out)
#   orbit    center | center_actor (+center_y), radius, deg_from, deg_to, height | height_from..height_to, fov
#            (camera at center + (sin a·r, 0, cos a·r), y = height; constant angular speed)
#   low_hero actor, side_deg, dist, fov      (0.25 m above ground in front-side of the actor, looking up at its chest)
#   track    actor, offset, look (offset from the actor or from look_actor), fov
# Every rig also takes "hand" (handheld feel, 0 = locked off, 1 = a tight handheld operator; see handheld()) and "whip"
# (false = no whip / punch-in on the hits inside the shot).
class_name CineShots
extends RefCounted

const WHIP_DEG: Dictionary = {"light": 6.0, "medium": 9.0, "heavy": 12.0, "finisher": 12.0, "accent": 4.0, "card": 0.0}
const FOV_PUNCH: Dictionary = {"light": -2.0, "medium": -4.0, "heavy": -7.0, "finisher": -8.0, "accent": 0.0, "card": 0.0}


static func _apos(ctx: Dictionary, id: String) -> Vector3:
	var a: Node3D = (ctx["actors"] as Dictionary).get(id)
	return a.position if a else Vector3.ZERO


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
