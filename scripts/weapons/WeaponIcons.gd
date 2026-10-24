# File: res://scripts/weapons/WeaponIcons.gd
# Weapon icons drawn in code (spec section 2: no image files, never AI images). Each slot is a list of simple polygons in a
# unit box [-1, 1]² (y down); "dark" parts are drawn in the detail colour. Used by WeaponWheel and WeaponHUD.
class_name WeaponIcons
extends RefCounted

static var _cache: Dictionary = {}


static func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


static func _circle(c: Vector2, r: float, n: int = 16) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in n:
		var a: float = TAU * float(i) / float(n)
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


static func _ellipse(c: Vector2, rx: float, ry: float, rot: float, n: int = 18) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in n:
		var a: float = TAU * float(i) / float(n)
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return out


## [{"pts": PackedVector2Array, "dark": bool}] of one slot (WeaponData.Slot order).
static func shapes(slot: int) -> Array:
	if _cache.has(slot):
		return _cache[slot]
	var s: Array = []
	match slot:
		0:   # Tay không: a fist
			s.append({"pts": _rect(-0.6, -0.15, 0.6, 0.7), "dark": false})
			for k: int in 4:
				var x0: float = -0.6 + float(k) * 0.3
				s.append({"pts": _rect(x0 + 0.02, -0.62, x0 + 0.28, -0.1), "dark": false})
			s.append({"pts": PackedVector2Array([Vector2(-0.85, 0.0), Vector2(-0.55, -0.12), Vector2(-0.18, 0.25), Vector2(-0.5, 0.42)]), "dark": false})
			s.append({"pts": _rect(-0.55, 0.3, 0.55, 0.36), "dark": true})
		1:   # Dao: a knife pointing right
			s.append({"pts": _rect(-0.95, -0.12, -0.32, 0.18), "dark": false})
			s.append({"pts": _rect(-0.34, -0.28, -0.22, 0.34), "dark": false})
			s.append({"pts": PackedVector2Array([Vector2(-0.22, -0.16), Vector2(0.55, -0.16), Vector2(0.95, 0.04), Vector2(0.55, 0.16), Vector2(-0.22, 0.16)]), "dark": false})
			s.append({"pts": _rect(-0.15, -0.04, 0.55, 0.0), "dark": true})
		2:   # Súng lục: a pistol
			s.append({"pts": _rect(-0.8, -0.48, 0.85, -0.12), "dark": false})
			s.append({"pts": PackedVector2Array([Vector2(-0.78, -0.12), Vector2(-0.3, -0.12), Vector2(-0.12, 0.78), Vector2(-0.64, 0.78)]), "dark": false})
			s.append({"pts": _rect(-0.3, -0.12, 0.08, -0.02), "dark": false})
			s.append({"pts": _rect(0.0, -0.02, 0.08, 0.22), "dark": false})
			s.append({"pts": _rect(-0.6, -0.4, 0.75, -0.32), "dark": true})
		3:   # Shotgun
			s.append({"pts": _rect(-0.2, -0.26, 0.98, -0.08), "dark": false})
			s.append({"pts": _rect(0.15, -0.08, 0.6, 0.06), "dark": false})
			s.append({"pts": _rect(-0.55, -0.32, -0.15, 0.06), "dark": false})
			s.append({"pts": PackedVector2Array([Vector2(-0.55, -0.3), Vector2(-0.98, -0.1), Vector2(-0.98, 0.32), Vector2(-0.55, 0.06)]), "dark": false})
			s.append({"pts": _rect(0.2, -0.04, 0.55, 0.0), "dark": true})
		4:   # Tên lửa: a launcher with its rocket head
			s.append({"pts": _rect(-0.95, -0.2, 0.62, 0.16), "dark": false})
			s.append({"pts": PackedVector2Array([Vector2(0.62, -0.28), Vector2(0.98, -0.02), Vector2(0.62, 0.24)]), "dark": false})
			s.append({"pts": _rect(-0.2, 0.16, 0.0, 0.58), "dark": false})
			s.append({"pts": _rect(-0.52, -0.36, -0.3, -0.2), "dark": false})
			s.append({"pts": _rect(-0.9, -0.08, 0.55, 0.04), "dark": true})
		5:   # Dép tổ ong: a sandal with honeycomb holes
			s.append({"pts": _ellipse(Vector2(0.0, 0.05), 0.46, 0.9, 0.35), "dark": false})
			s.append({"pts": PackedVector2Array([Vector2(-0.62, -0.42), Vector2(0.38, -0.78), Vector2(0.5, -0.5), Vector2(-0.5, -0.14)]), "dark": true})
			for hp: Vector2 in [Vector2(-0.12, 0.05), Vector2(0.14, 0.15), Vector2(0.02, 0.38), Vector2(-0.24, 0.3), Vector2(0.24, 0.42), Vector2(-0.08, 0.6)]:
				s.append({"pts": _circle(hp, 0.08, 6), "dark": true})
		6:   # Sầu riêng: a spiky durian with its stem
			var spikes := PackedVector2Array()
			for i: int in 24:
				var a: float = TAU * float(i) / 24.0
				var r: float = 0.82 if i % 2 == 0 else 0.62
				spikes.append(Vector2(cos(a), sin(a)) * r + Vector2(0.0, 0.06))
			s.append({"pts": spikes, "dark": false})
			s.append({"pts": _rect(-0.07, -0.98, 0.07, -0.7), "dark": true})
			s.append({"pts": _circle(Vector2(-0.22, -0.18), 0.12, 8), "dark": true})
		7:   # Loa kẹo kéo: a trolley speaker with its handle
			s.append({"pts": _rect(-0.6, -0.58, 0.6, 0.82), "dark": false})
			s.append({"pts": PackedVector2Array([Vector2(-0.36, -0.58), Vector2(-0.36, -0.9), Vector2(0.36, -0.9), Vector2(0.36, -0.58),
				Vector2(0.22, -0.58), Vector2(0.22, -0.76), Vector2(-0.22, -0.76), Vector2(-0.22, -0.58)]), "dark": false})
			s.append({"pts": _circle(Vector2(0.0, 0.28), 0.38, 18), "dark": true})
			s.append({"pts": _circle(Vector2(0.0, -0.3), 0.14, 10), "dark": true})
	_cache[slot] = s
	return s


## Draw a slot's icon centred at `center`, `size` px wide.
static func draw(ci: CanvasItem, slot: int, center: Vector2, size: float, col: Color, dark: Color) -> void:
	var k: float = size * 0.5
	for sh: Dictionary in shapes(slot):
		var src: PackedVector2Array = sh["pts"]
		var pts := PackedVector2Array()
		pts.resize(src.size())
		for i: int in src.size():
			pts[i] = center + src[i] * k
		ci.draw_colored_polygon(pts, dark if bool(sh["dark"]) else col)
