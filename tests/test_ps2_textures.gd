# File: res://tests/test_ps2_textures.gd
# Test headless texture mặt PS2: đủ 24 atlas 512x256 + tóc 128x128, ô "closed" khác ô "open" ở vùng mắt, mọi ô biểu cảm
# khác ô "open", viền mỗi ô là da trơn (PS2Head ánh xạ mặt sau đầu vào các cột viền da, u = 0.01 / 0.99 của ô),
# râu lún phún của nam biến thể 1 nhìn thấy được (vùng cằm tối hơn biến thể 0), tóc lặp được theo trục V.
# Chạy:  godot --headless --path . --script tests/test_ps2_textures.gd
extends SceneTree

const TONES: Array[String] = ["a", "b", "c", "d"]
const CELL: int = 128
const CELL_NAMES: Array[String] = ["open", "closed", "happy", "angry", "surprised", "done", "talk", "pain"]
## mean |RGB| difference (0..255 scale) that every expression cell must have against the "open" cell of its atlas
const MIN_CELL_DIFF: float = 0.2
## levels (0..255) that the male variant 1 jaw window must be darker than the variant 0 one: visible stubble
const MIN_STUBBLE_DARKER: float = 2.0

var done: bool = false
var atlases: Dictionary = {}


func _initialize() -> void:
	for t: String in TONES:
		for s: String in ["m", "f"]:
			for v: int in range(3):
				var name: String = "char_ps2_face_%s%s%d.png" % [t, s, v]
				var img: Image = _load(name)
				if not _check(img != null, "%s missing (run: python generate_character_textures.py --ps2-only)" % name):
					return
				atlases[name] = img
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
				# every expression cell differs from "open" (mean |RGB| difference over the whole cell)
				for c: int in range(1, 8):
					var cd: float = _cell_diff(img, c)
					if not _check(cd > MIN_CELL_DIFF, "%s: cell %d (%s) is not distinguishable from open (mean diff %.2f)" % [name, c, CELL_NAMES[c], cd]):
						return
	# stubble: the jaw window of the male variant 1 "open" cell is clearly darker than the male variant 0 one
	for t: String in TONES:
		var plain: Image = atlases["char_ps2_face_%sm0.png" % t]
		var stubbly: Image = atlases["char_ps2_face_%sm1.png" % t]
		var darker: float = (_window_luma(plain) - _window_luma(stubbly)) * 255.0
		if not _check(darker >= MIN_STUBBLE_DARKER, "tone %s: male variant 1 jaw window must be >= %.1f levels darker than variant 0 (stubble), got %.2f" % [t, MIN_STUBBLE_DARKER, darker]):
			return
	var hair: Image = _load("char_ps2_hair.png")
	if not _check(hair != null and hair.get_width() == 128 and hair.get_height() == 128, "char_ps2_hair.png must exist at 128x128"):
		return
	# the strands tile along V: the step from the last row back to the first row is tiny
	var seam: float = 0.0
	for x: int in range(128):
		seam += absf(hair.get_pixel(x, 127).r - hair.get_pixel(x, 0).r)
	seam = seam / 128.0 * 255.0
	if not _check(seam < 1.5, "char_ps2_hair.png must tile along V (wrap-around step %.2f/255)" % seam):
		return
	print("✅ SUCCESS: PS2 FACE ATLASES (24) AND HAIR TEXTURE OK")
	quit(0)


## Mean |RGB| difference (0..255 scale, averaged over the 3 channels and the whole cell) between cell c and cell 0.
func _cell_diff(img: Image, c: int) -> float:
	var ox: int = (c % 4) * CELL
	var oy: int = (c / 4) * CELL
	var sum: float = 0.0
	for y: int in range(CELL):
		for x: int in range(CELL):
			var a: Color = img.get_pixel(x, y)
			var b: Color = img.get_pixel(ox + x, oy + y)
			sum += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
	return sum / float(CELL * CELL * 3) * 255.0


## Mean luminance (0..1) of the jaw window of cell 0: x in [-0.04, 0.04] m, y in [0.02, 0.05] m (below the mouth line at
## y 0.058), mapped with the front projection u = 0.5 + x / 0.2, v = 1 - y / 0.235.
func _window_luma(img: Image) -> float:
	var x0: int = int((0.5 - 0.04 / 0.2) * CELL)
	var x1: int = int((0.5 + 0.04 / 0.2) * CELL)
	var y0: int = int((1.0 - 0.05 / 0.235) * CELL)
	var y1: int = int((1.0 - 0.02 / 0.235) * CELL)
	var sum: float = 0.0
	for y: int in range(y0, y1):
		for x: int in range(x0, x1):
			sum += img.get_pixel(x, y).get_luminance()
	return sum / float((x1 - x0) * (y1 - y0))


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
