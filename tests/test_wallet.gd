# File: res://tests/test_wallet.gd
# Test headless ví Cóc Vàng (spec docs/superpowers/specs/2026-10-21-free-roam-design-proposal.md mục 1.1, bản tối thiểu
# của Task VC-4): thành viên của StageManager (không phải autoload mới) -> wallet: int, tín hiệu wallet_changed(total, delta),
# earn(amount, reason), spend(amount) -> bool (không cho âm ví), lưu khoá "wallet" trong mục [roam] của progress.cfg qua
# save_progress(path) / load_progress(path) (test dùng file tạm), thắng một màn được trả theo rank S 50 / A 30 / B 20 /
# C 10 (thua: 0), tiêu đề thẻ kết quả "QUA MÔN!" / "TRƯỢT MÔN" / "BỊ BẮT".
# Chạy:  godot --headless --path . --script tests/test_wallet.gd
extends SceneTree

var TMP_PATH: String = "user://test_wallet_progress_%d.cfg" % OS.get_process_id()

var sm: Node
var frames: int = 0
var events: Array = []


func _initialize() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	sm = root.get_node("StageManager")
	print("--- TEST VÍ CÓC VÀNG ---")


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("❌ FAILED: ", msg)
		_cleanup()
		quit(1)
	return ok


func _cleanup() -> void:
	var abs_path: String = ProjectSettings.globalize_path(TMP_PATH)
	if FileAccess.file_exists(TMP_PATH):
		DirAccess.remove_absolute(abs_path)


func _on_wallet(total: int, delta: int) -> void:
	events.append([total, delta])


func _process(_d: float) -> bool:
	frames += 1
	if frames != 3:
		return false
	if not _check("wallet" in sm and sm.has_signal("wallet_changed") and sm.has_method("earn") and sm.has_method("spend"), "StageManager has wallet, wallet_changed, earn(), spend()"):
		return true
	sm.set("wallet", 0)
	sm.connect("wallet_changed", _on_wallet)

	# earn
	sm.call("earn", 30, "test")
	if not _check(int(sm.get("wallet")) == 30, "earn(30) -> wallet 30 (got %d)" % int(sm.get("wallet"))):
		return true
	if not _check(events.size() == 1 and events[0] == [30, 30], "earn emits wallet_changed(30, 30) (got %s)" % str(events)):
		return true
	sm.call("earn", 0)
	sm.call("earn", -5)
	if not _check(int(sm.get("wallet")) == 30 and events.size() == 1, "earn(0) / earn(-5) change nothing and emit nothing"):
		return true

	# spend: không cho âm ví
	var ok: bool = sm.call("spend", 50)
	if not _check(not ok and int(sm.get("wallet")) == 30 and events.size() == 1, "spend(50) with 30 CV is refused (no overdraft, no signal)"):
		return true
	ok = sm.call("spend", 20)
	if not _check(ok and int(sm.get("wallet")) == 10, "spend(20) succeeds -> wallet 10"):
		return true
	if not _check(events.size() == 2 and events[1] == [10, -20], "spend emits wallet_changed(10, -20) (got %s)" % str(events)):
		return true
	ok = sm.call("spend", 0)
	if not _check(not ok and int(sm.get("wallet")) == 10, "spend(0) is refused"):
		return true

	# lưu / nạp lại qua file tạm (mục [roam], khoá "wallet"), kỷ lục màn giữ nguyên
	var best: Dictionary = sm.get("best_stats")
	best[2] = {"score": 900, "rank": "A", "wins": 2, "plays": 3}
	sm.call("save_progress", TMP_PATH)
	var cfg := ConfigFile.new()
	if not _check(cfg.load(TMP_PATH) == OK, "save_progress(path) writes the temp file"):
		return true
	if not _check(int(cfg.get_value("roam", "wallet", -1)) == 10, "progress file has [roam] wallet = 10 (got %s)" % str(cfg.get_value("roam", "wallet", -1))):
		return true
	sm.set("wallet", 999)
	(sm.get("best_stats") as Dictionary).clear()
	sm.call("load_progress", TMP_PATH)
	if not _check(int(sm.get("wallet")) == 10, "load_progress(path) restores wallet 10 (got %d)" % int(sm.get("wallet"))):
		return true
	var b2: Dictionary = (sm.get("best_stats") as Dictionary).get(2, {})
	if not _check(int(b2.get("score", 0)) == 900 and String(b2.get("rank", "")) == "A", "load_progress(path) keeps the stage records (got %s)" % str(b2)):
		return true
	sm.call("load_progress", ("user://test_wallet_missing_%d.cfg" % OS.get_process_id()))
	if not _check(int(sm.get("wallet")) == 0, "a missing progress file means an empty wallet"):
		return true

	# thắng một màn: S 50 / A 30 / B 20 / C 10, thua 0; kết quả mang số xu "coins"
	sm.set("wallet", 0)
	events.clear()
	var paid: Array = []
	for rank: String in ["S", "A", "B", "C"]:
		var before: int = int(sm.get("wallet"))
		var res: Dictionary = {"result": "win", "score": 100, "rank": rank, "detail": "test"}
		sm.call("report_stage_result", 2, res)
		paid.append(int(sm.get("wallet")) - before)
		if not _check(int(res.get("coins", -1)) == paid[paid.size() - 1], "result dict carries the coins paid for rank %s" % rank):
			return true
	if not _check(paid == [50, 30, 20, 10], "a win pays S 50 / A 30 / B 20 / C 10 (got %s)" % str(paid)):
		return true
	var w_before: int = int(sm.get("wallet"))
	var fail_res: Dictionary = {"result": "fail", "score": 0, "rank": "C", "detail": "test"}
	sm.call("report_stage_result", 2, fail_res)
	if not _check(int(sm.get("wallet")) == w_before and int(fail_res.get("coins", 0)) == 0, "a fail pays nothing"):
		return true
	if not _check(events.size() == 4 and events[3] == [110, 10], "each paid win emits wallet_changed (got %s)" % str(events)):
		return true

	# tiêu đề thẻ kết quả
	var t_win: String = sm.call("result_banner_title", {"result": "win"})
	var t_fail: String = sm.call("result_banner_title", {"result": "fail"})
	var t_caught: String = sm.call("result_banner_title", {"result": "fail", "caught": true})
	if not _check(t_win == "QUA MÔN!" and t_fail == "TRƯỢT MÔN" and t_caught == "BỊ BẮT", "result titles QUA MÔN! / TRƯỢT MÔN / BỊ BẮT (got %s / %s / %s)" % [t_win, t_fail, t_caught]):
		return true
	var coins_line: String = sm.call("coins_text", 30)
	if not _check(coins_line == "+30 Cóc Vàng", "coins line '+30 Cóc Vàng' (got '%s')" % coins_line):
		return true

	(sm.get("best_stats") as Dictionary).erase(2)
	_cleanup()
	print("✅ SUCCESS: WALLET OK (earn, no overdraft, signal, [roam] save/load, rank pay S50/A30/B20/C10)")
	quit(0)
	return true
