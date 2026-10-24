# File: res://scripts/emotes/EmoteIcons.gd
# Emote icons drawn in code (no image files, never AI images), same format as WeaponIcons: polygons in [-1, 1]² (y down).
# Icon 0: "Siuuu!" – a figure landed wide with the arms swung down and out; -1: an empty slot (a ring).
class_name EmoteIcons
extends RefCounted


static func _circle(c: Vector2, r: float, n: int = 16) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in n:
		var a: float = TAU * float(i) / float(n)
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


static func shapes(icon: int) -> Array:
	var s: Array = []
	match icon:
		0:
			s.append({"pts": _circle(Vector2(0.0, -0.7), 0.18, 12), "dark": false})
			s.append({"pts": PackedVector2Array([Vector2(-0.16, -0.5), Vector2(0.16, -0.5), Vector2(0.12, 0.15), Vector2(-0.12, 0.15)]), "dark": false})
			s.append({"pts": PackedVector2Array([Vector2(-0.16, -0.45), Vector2(-0.1, -0.35), Vector2(-0.75, 0.1), Vector2(-0.85, 0.0)]), "dark": false})
			s.append({"pts": PackedVector2Array([Vector2(0.16, -0.45), Vector2(0.85, 0.0), Vector2(0.75, 0.1), Vector2(0.1, -0.35)]), "dark": false})
			s.append({"pts": PackedVector2Array([Vector2(-0.12, 0.1), Vector2(0.0, 0.15), Vector2(-0.45, 0.9), Vector2(-0.62, 0.88)]), "dark": false})
			s.append({"pts": PackedVector2Array([Vector2(0.12, 0.1), Vector2(0.62, 0.88), Vector2(0.45, 0.9), Vector2(0.0, 0.15)]), "dark": false})
		_:
			s.append({"pts": _circle(Vector2.ZERO, 0.45, 16), "dark": false})
			s.append({"pts": _circle(Vector2.ZERO, 0.3, 16), "dark": true})
	return s


static func draw(ci: CanvasItem, icon: int, center: Vector2, size: float, col: Color, dark: Color) -> void:
	var k: float = size * 0.5
	for sh: Dictionary in shapes(icon):
		var src: PackedVector2Array = sh["pts"]
		var pts := PackedVector2Array()
		pts.resize(src.size())
		for i: int in src.size():
			pts[i] = center + src[i] * k
		ci.draw_colored_polygon(pts, dark if bool(sh["dark"]) else col)
