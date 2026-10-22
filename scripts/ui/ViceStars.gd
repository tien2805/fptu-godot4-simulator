# File: res://scripts/ui/ViceStars.gd
# Hàng 5 ngôi sao kiểu HUD thập niên 80 (Task VC-4, vẽ bằng code từ StarRow của tests/preview_vice_lookdev.gd).
# Chỉ gắn với thanh "GIẢNG VIÊN ĐỂ Ý" của Màn 3 (sao = floori(để ý / 20)); nơi khác ViceHUD ẩn hàng sao ở 0.
# set_filled(n): kẹp 0..5; số sao TĂNG -> nhấp nháy FLASH_S giây. align_right: sao đầy tiên lấp từ mép phải (góc trên
# phải) hoặc từ mép trái (góc trên trái). Không dùng GameFX / StageManager (lớp class_name được test --script nạp sớm).
class_name ViceStars
extends Control

const FLASH_S: float = 2.0
const FLASH_HZ: float = 6.0
const ON := Color("#FFD166")
const ON_FLASH := Color("#FFFFFF")
const OFF := Color(0.1, 0.06, 0.18, 0.55)
const INK := Color("#1B0F33")

var filled: int = 0
var align_right: bool = true
var flash_t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(flash_t > 0.0)


func set_filled(n: int) -> void:
	var v: int = clampi(n, 0, 5)
	if v > filled:
		flash_t = FLASH_S
		set_process(true)
	elif v == 0:
		flash_t = 0.0
	filled = v
	queue_redraw()


func is_flashing() -> bool:
	return flash_t > 0.0


func _process(delta: float) -> void:
	flash_t = maxf(0.0, flash_t - delta)
	if flash_t <= 0.0:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var cell: float = size.y
	var r: float = cell * 0.46
	var blink_on: bool = flash_t > 0.0 and int(flash_t * FLASH_HZ * 2.0) % 2 == 0
	for i: int in range(5):
		var cx: float = size.x - (i + 0.5) * cell if align_right else (i + 0.5) * cell
		var c := Vector2(cx, cell * 0.5)
		var pts := PackedVector2Array()
		for k: int in range(10):
			var rad: float = r if k % 2 == 0 else r * 0.45
			var a: float = -PI * 0.5 + k * PI / 5.0
			pts.append(c + Vector2(cos(a), sin(a)) * rad)
		var on: bool = i < filled
		draw_colored_polygon(pts, (ON_FLASH if blink_on else ON) if on else OFF)
		pts.append(pts[0])
		draw_polyline(pts, INK, 2.5, true)
