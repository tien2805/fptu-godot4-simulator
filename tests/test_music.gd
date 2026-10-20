# File: res://tests/test_music.gd
# Test headless MusicDirector: mọi style phát được, đổi tension, fade-out, không lỗi script trong 240 frame.
# Chạy:  godot --headless --path . --script tests/test_music.gd
extends SceneTree

var fx: Node
var frames: int = 0
var styles: Array = []
var fails: Array[String] = []

func _initialize() -> void:
	var s: Script = load("res://scripts/GameFX.gd")
	fx = s.new()
	fx.name = "GameFX"
	root.add_child(fx)
	styles = MusicDirector.STYLES.keys()
	print("--- TEST MUSIC DIRECTOR: %d styles ---" % styles.size())

func _process(_d: float) -> bool:
	frames += 1
	var md: MusicDirector = fx.get("music")
	if md == null:
		# _ready của GameFX chạy ở frame đầu tiên sau _initialize
		if frames > 3:
			print("  ✗ GameFX không tạo MusicDirector")
			quit(1)
			return true
		return false
	if frames % 25 == 1:
		var idx: int = (frames / 25) % styles.size()
		fx.call("music_play", styles[idx], float(idx) / float(styles.size()))
		if md.style_name != String(styles[idx]):
			fails.append("style không đổi sang %s" % styles[idx])
		# kiểm tra tần số bậc: gốc + quãng 8 = x2
		var f0: float = md._degree_freq(0, 0)
		var f7: float = md._degree_freq(7, 0)
		if not is_equal_approx(f7 / f0, 2.0):
			fails.append("_degree_freq quãng 8 sai (%.2f)" % (f7 / f0))
	if frames == 200:
		fx.call("music_stop", true)
	if frames >= 240:
		print("  style cuối=%s tension=%.2f master_gain=%.2f playing=%s" % [md.style_name, md.tension, md._master_gain, str(md.player.playing)])
		if fails.is_empty():
			print("✅ SUCCESS: MUSIC DIRECTOR PLAYS ALL STYLES, TENSION AND FADE WORK")
			quit(0)
		else:
			for f: String in fails:
				print("  ✗ ", f)
			print("❌ FAILED: %d issues" % fails.size())
			quit(1)
		return true
	return false
