# File: res://tests/test_hud_bounds.gd
# Kiểm tra HUD không bị cắt: nạp menu + 7 màn + thế giới mở ở 3 độ phân giải cửa sổ (1280x720, 1920x1080, 2560x1440),
# chờ vài frame rồi duyệt mọi Control đang hiển thị; rect toàn cục phải nằm trong viewport (dung sai 1 px).
# Menu chính được kiểm khi đang mở bảng Hướng dẫn (bảng phím + khối "Nguồn dữ liệu bản đồ"), thế giới mở khi đang
# mở bản đồ [M].
# Task VC-4 (phong cách vice, mặc định):
#   - lượt chính chạy ở vice; trước khi mở lớp phủ, mọi ViceHUD trong cảnh (Màn 1, Màn 3, thế giới mở) bị ép hiện đủ
#     (5 sao + nhãn, tên khu vực dài nhất, tên xe, giờ) rồi kiểm cả trong viewport lẫn KHÔNG chồng lên panel / nút của
#     HUD màn (radar, cột ví, tên khu vực so với bảng thưởng / tốc độ / thông báo / dòng gợi ý...);
#   - lượt classic (1280x720) cho 3 cảnh có bố cục theo phong cách (Màn 1, Màn 3, thế giới mở);
#   - thẻ kết quả (1280x720, vice): mỗi màn gọi hàm thua và hàm thắng của chính nó, thẻ (kèm khối ViceResult "QUA MÔN!" /
#     "TRƯỢT MÔN" + "+N Cóc Vàng") phải nằm gọn trong viewport và không panel HUD nào (thêm bằng code sau .tscn) vẽ đè lên.
# Chạy:  godot --headless --path . --script tests/test_hud_bounds.gd
extends SceneTree

const SCENES: Array[String] = [
	"res://scenes/MainMenu.tscn",
	"res://scenes/Main.tscn",
	"res://scenes/Stage2_Parking.tscn",
	"res://scenes/Stage3_ClassroomFAP.tscn",
	"res://scenes/Stage4_Vovinam.tscn",
	"res://scenes/Stage5_Canteen.tscn",
	"res://scenes/Stage6_CapstoneBoss.tscn",
	"res://scenes/StageExtra_EOSExam.tscn",
	"res://scenes/FreeRoam.tscn"
]
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
## Cảnh có bố cục HUD đổi theo phong cách: kiểm thêm ở classic.
const CLASSIC_SCENES: Array[String] = ["res://scenes/Main.tscn", "res://scenes/Stage3_ClassroomFAP.tscn", "res://scenes/FreeRoam.tscn"]
## Hàm kết thúc của từng màn: [thua, thắng] (Màn 1 dùng màn hình ABSENT / PRESENT của HUD).
const END_CALLS: Dictionary = {
	"res://scenes/Main.tscn": ["HUD:_trigger_absent_screen", "HUD:_on_destination_reached"],
	"res://scenes/Stage2_Parking.tscn": ["_fail_stage", "_complete_stage"],
	"res://scenes/Stage3_ClassroomFAP.tscn": ["_fail_stage", "_complete_stage"],
	"res://scenes/Stage4_Vovinam.tscn": ["_fail_stage", "_complete_stage"],
	"res://scenes/Stage5_Canteen.tscn": ["_fail_stage", "_complete_stage"],
	"res://scenes/Stage6_CapstoneBoss.tscn": ["_lose", "_win"],
	"res://scenes/StageExtra_EOSExam.tscn": ["_fail_stage", "_complete_stage"],
}
const FAIL_REASON: String = "HẾT GIỜ! Lý do thua dài để thẻ kết quả xuống dòng: giảng viên đóng cửa, Wi-Fi trường thắng 1-0, hẹn gặp lại ở kỳ retake."
const LONG_AREA: String = "Cầu cạn Đường vành đai 3 Thành phố Hồ Chí Minh"
const SETTLE_FRAMES: int = 12
const RESULT_WAIT_MS: int = 2500     # thẻ kết quả mờ dần 0,5..1,1 s; Màn 6 hiện thẻ sau tween 1,2 s (slow-motion)

var jobs: Array = []                 # {"scene", "size", "style", "mode": "hud" | "fail" | "win"}
var job_i: int = -1
var frames: int = 0
var current: Node = null
var failures: Array[String] = []
var checked: int = 0
var overlap_checked: int = 0
var cards_checked: int = 0
var fx: Node
var t_end: int = 0


func _initialize() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	fx = root.get_node("GameFX")
	for sc: String in SCENES:
		for sz: Vector2i in SIZES:
			jobs.append({"scene": sc, "size": sz, "style": "vice", "mode": "hud"})
	for sc2: String in CLASSIC_SCENES:
		jobs.append({"scene": sc2, "size": SIZES[0], "style": "classic", "mode": "hud"})
	for sc3: String in END_CALLS.keys():
		jobs.append({"scene": sc3, "size": SIZES[0], "style": "vice", "mode": "fail"})
		jobs.append({"scene": sc3, "size": SIZES[0], "style": "vice", "mode": "win"})
	print("--- TEST HUD BOUNDS: %d jobs (%d scenes x %d resolutions vice, %d classic, %d result cards) ---" % [jobs.size(), SCENES.size(), SIZES.size(), CLASSIC_SCENES.size(), END_CALLS.size() * 2])


func _walk(n: Node, vp: Rect2, tag: String) -> void:
	if n is Control:
		var c: Control = n
		if c.is_visible_in_tree() and c.size.x > 2.0 and c.size.y > 2.0 and not (c is ScrollContainer):
			var r: Rect2 = c.get_global_rect()
			var tol: float = 1.0
			if r.position.x < vp.position.x - tol or r.position.y < vp.position.y - tol or r.end.x > vp.end.x + tol or r.end.y > vp.end.y + tol:
				failures.append("%s: %s rect=%s vp=%s" % [tag, c.get_path(), r, vp])
			checked += 1
	for ch: Node in n.get_children():
		# Không chui vào nội dung ScrollContainer (được phép tràn và cuộn)
		if n is ScrollContainer:
			continue
		_walk(ch, vp, tag)


## Ép mọi phần của các ViceHUD trong cảnh hiện ra (trường hợp xấu nhất về bố cục).
func _force_vice_hud(scene: Node) -> void:
	for h: Node in scene.find_children("*", "ViceHUD", true, false):
		var vh: ViceHUD = h as ViceHUD
		if vh.show_clock:
			vh.set_clock("23:00")
		vh.set_money(99999999, false)
		vh.set_stars(5, "GIẢNG VIÊN ĐỂ Ý")
		vh.show_area(LONG_AREA)
		vh.show_vehicle("Xe máy")


## Phần nhìn thấy của ViceHUD (radar, nhãn có chữ, hàng sao) không được chồng lên panel / nút đang hiện của HUD màn.
func _check_overlap(scene: Node, tag: String) -> void:
	var vice_rects: Array = []
	for h: Node in scene.find_children("*", "ViceHUD", true, false):
		var vh: ViceHUD = h as ViceHUD
		if not vh.visible:
			continue
		var parts: Array[Control] = [vh.clock_label, vh.money_label, vh.stars, vh.stars_label, vh.area_label, vh.vehicle_label]
		if vh.radar:
			parts.append(vh.radar)
		for c: Control in parts:
			if c.is_visible_in_tree() and c.size.x > 2.0 and (not (c is Label) or (c as Label).text != ""):
				vice_rects.append([c, c.get_global_rect()])
	if vice_rects.is_empty():
		return
	var host: Array = []
	_collect_host(scene, host)
	for v: Array in vice_rects:
		for hc: Control in host:
			overlap_checked += 1
			var hr: Rect2 = hc.get_global_rect()
			if (v[1] as Rect2).grow(-1.0).intersects(hr.grow(-1.0)):
				failures.append("%s: ViceHUD %s %s overlaps %s %s" % [tag, (v[0] as Control).name, v[1], hc.get_path(), hr])


func _collect_host(n: Node, out: Array) -> void:
	if n is ViceHUD:
		return
	if (n is PanelContainer or n is Button) and (n as Control).is_visible_in_tree() and (n as Control).size.x > 2.0:
		out.append(n)
		return
	for ch: Node in n.get_children():
		_collect_host(ch, out)


## Thẻ kết quả không bị panel nào của HUD màn vẽ đè: mọi Control nhìn thấy được nằm SAU nền phủ (cùng CanvasLayer) không
## được giao với thẻ (panel thêm bằng code sau .tscn từng vẽ đè thẻ ở Màn 1 / Màn 5).
func _check_card_on_top(banner: Node, tag: String) -> void:
	var card: Control = banner.get_parent() as Control
	var ov: Node = banner
	while ov and not (ov.get_parent() is CanvasLayer):
		ov = ov.get_parent()
	if card == null or ov == null:
		return
	var card_rect: Rect2 = card.get_global_rect()
	var layer: Node = ov.get_parent()
	for i: int in range(ov.get_index() + 1, layer.get_child_count()):
		var drawn: Array = []
		_collect_drawn(layer.get_child(i), drawn)
		for c: Control in drawn:
			if c.get_global_rect().intersects(card_rect):
				failures.append("%s: %s draws over the result card %s" % [tag, c.get_path(), card_rect])


func _collect_drawn(n: Node, out: Array) -> void:
	if not (n is Control) or not (n as Control).is_visible_in_tree():
		return
	var c: Control = n
	if c.size.x > 2.0 and c.size.y > 2.0:
		if c is PanelContainer or c is Button or c is ProgressBar or c is TextureRect or (c is Label and (c as Label).text != "") or (c is ColorRect and (c as ColorRect).color.a > 0.05):
			out.append(c)
	for ch: Node in n.get_children():
		_collect_drawn(ch, out)


func _end_call(scene: Node, spec: String) -> void:
	var target: Node = scene
	var method: String = spec
	if spec.contains(":"):
		target = scene.get_node(spec.get_slice(":", 0))
		method = spec.get_slice(":", 1)
	if method == "_fail_stage" or method == "_lose":
		target.call(method, FAIL_REASON)
	else:
		target.call(method)


func _process(_d: float) -> bool:
	frames += 1
	if current == null:
		job_i += 1
		if job_i >= jobs.size():
			print("  checked %d controls, %d ViceHUD/host overlap pairs, %d result cards" % [checked, overlap_checked, cards_checked])
			fx.call("set_art_style", "vice", false)
			if failures.is_empty():
				print("✅ SUCCESS: NO HUD ELEMENT IS CLIPPED AT ANY RESOLUTION (vice + classic, ViceHUD never overlaps the stage HUD, result cards fit)")
				quit(0)
			else:
				for f: String in failures:
					print("  ✗ ", f)
				print("❌ FAILED: %d clipped / overlapping controls" % failures.size())
				quit(1)
			return true
		var job: Dictionary = jobs[job_i]
		fx.call("set_art_style", String(job["style"]), false)
		root.size = job["size"]
		var packed: PackedScene = load(String(job["scene"]))
		current = packed.instantiate()
		root.add_child(current)
		frames = 0
		return false
	var job2: Dictionary = jobs[job_i]
	var size: Vector2i = job2["size"]
	var scene_name: String = String(job2["scene"]).get_file()
	var tag: String = "%s @%dx%d %s %s" % [scene_name, size.x, size.y, job2["style"], job2["mode"]]
	var vp: Rect2 = root.get_visible_rect()    # stretch canvas_items: viewport thiết kế = kích thước nội dung
	if String(job2["mode"]) == "hud":
		if frames == SETTLE_FRAMES - 6:
			_force_vice_hud(current)
		elif frames == SETTLE_FRAMES - 3:
			# HUD lúc chơi (ViceHUD đủ phần) trước khi mở lớp phủ
			_walk(current, vp, tag)
			_check_overlap(current, tag)
			# lớp phủ mở bằng phím / nút: bảng Hướng dẫn của menu, bản đồ [M] của thế giới mở
			if current.has_method("_show_guide"):
				current.call("_show_guide")
			elif current.has_method("toggle_map"):
				current.call("toggle_map")
		elif frames >= SETTLE_FRAMES:
			_walk(current, vp, tag + " overlay")
			_finish_job()
	else:
		var specs: Array = END_CALLS[String(job2["scene"])]
		if frames == SETTLE_FRAMES:
			_end_call(current, String(specs[0] if String(job2["mode"]) == "fail" else specs[1]))
			t_end = Time.get_ticks_msec()
		elif frames > SETTLE_FRAMES and Time.get_ticks_msec() - t_end >= RESULT_WAIT_MS:
			var banner: Node = current.find_child("ViceResult", true, false)
			if banner == null:
				failures.append("%s: no ViceResult banner on the result card" % tag)
			else:
				var texts: Array[String] = []
				for l: Node in banner.find_children("*", "Label", true, false):
					texts.append((l as Label).text)
				var want: String = "QUA MÔN!" if String(job2["mode"]) == "win" else "TRƯỢT MÔN"
				if not texts.has(want) or (String(job2["mode"]) == "win" and not str(texts).contains("Cóc Vàng")):
					failures.append("%s: result banner texts %s (want %s + coins on a win)" % [tag, str(texts), want])
				_check_card_on_top(banner, tag)
			_walk(current, vp, tag)
			cards_checked += 1
			_finish_job()
	return false


func _finish_job() -> void:
	current.queue_free()
	current = null
	Engine.time_scale = 1.0
	get_root().get_viewport().gui_release_focus()
	var sm: Node = root.get_node_or_null("StageManager")
	if sm:
		sm.set("typing_mode", false)
		sm.call("_hide_roam_return")
		(sm.get("best_stats") as Dictionary).clear()
