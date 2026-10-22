# File: res://tests/test_ps2_textures.gd
# Test headless texture mặt PS2: đủ 24 atlas 512x256 + tóc 128x128, ô "closed" khác ô "open" ở vùng mắt,
# viền mỗi ô là da trơn (khớp góc da dưới trái mà PS2Head.SKIN_UV lấy).
# Chạy:  godot --headless --path . --script tests/test_ps2_textures.gd
extends SceneTree

const TONES: Array[String] = ["a", "b", "c", "d"]
const CELL: int = 128

var done: bool = false


func _initialize() -> void:
	for t: String in TONES:
		for s: String in ["m", "f"]:
			for v: int in range(3):
				var name: String = "char_ps2_face_%s%s%d.png" % [t, s, v]
				var img: Image = _load(name)
				if not _check(img != null, "%s missing (run: python generate_character_textures.py --ps2-only)" % name):
					return
				if not _check(img.get_width() == 512 and img.get_height() == 256, "%s must be 512x256 (got %dx%d)" % [name, img.get_width(), img.get_height()]):
					return
				if not _check(FileAccess.file_exists("res://assets/textures/%s.import" % name), "%s.import stub missing" % name):
					return
				# eye window (left eye, x = -0.032 m, y = 0.125 m) differs between "open" (cell 0) and "closed" (cell 1)
				var ex: int = int((0.5 - 0.032 / 0.2) * CELL) - 6
				var ey: int = int((1.0 - 0.125 / 0.235) * CELL) - 3
				var diff: float = 0.0
				for y: int in range(6):
					for x: int in range(12):
						var a: Color = img.get_pixel(ex + x, ey + y)
						var b: Color = img.get_pixel(CELL + ex + x, ey + y)
						diff += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
				diff = diff / 72.0 * 255.0
				if not _check(diff > 20.0, "%s: closed cell must differ from open in the eye window (mean diff %.1f)" % [name, diff]):
					return
				# every cell border pixel matches the plain-skin corner of cell 0
				var skin: Color = img.get_pixel(2, CELL - 3)
				for c: int in range(8):
					var ox: int = (c % 4) * CELL
					var oy: int = (c / 4) * CELL
					for p: Vector2i in [Vector2i(1, 64), Vector2i(CELL - 2, 64), Vector2i(64, 1), Vector2i(64, CELL - 2)]:
						var px: Color = img.get_pixel(ox + p.x, oy + p.y)
						if not _check(absf(px.r - skin.r) < 0.06 and absf(px.g - skin.g) < 0.06 and absf(px.b - skin.b) < 0.06, "%s cell %d border pixel %s is not plain skin" % [name, c, p]):
							return
	var hair: Image = _load("char_ps2_hair.png")
	if not _check(hair != null and hair.get_width() == 128 and hair.get_height() == 128, "char_ps2_hair.png must exist at 128x128"):
		return
	print("✅ SUCCESS: PS2 FACE ATLASES (24) AND HAIR TEXTURE OK")
	quit(0)


func _load(name: String) -> Image:
	var path: String = "res://assets/textures/" + name
	if not FileAccess.file_exists(path):
		return null
	var img := Image.new()
	if img.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return null
	return img


func _check(ok: bool, msg: String) -> bool:
	if not ok and not done:
		done = true
		print("❌ FAILED: ", msg)
		quit(2)
	return ok
