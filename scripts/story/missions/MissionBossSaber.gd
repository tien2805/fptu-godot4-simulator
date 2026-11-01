# File: res://scripts/story/missions/MissionBossSaber.gd
# Day 7 boss, phase 3 "Sân thượng" (plan 2026-11-01-w4-day7.md T1 / T2): the rooftop duel in the rain under the
# helicopter's searchlight (LairTower's roof: the rain emitters, the rotor, the sweeping SpotLight). SwordDuel with the
# Day 7 additive opts: "rain" (wet for the whole run: the puddles, the longer dodge slide, his overshooting lunges, the
# rain loop; no sprinkler heads, cut or popup), "look" ("rooftop_rain" on the host), "qte_prompts" (QTE_PROMPTS: [Q] gạt
# kiếm, [Chuột trái] bật nhảy, [E] the scissor takedown "Đòn chân kẹp cổ số 21"). Lùm Văn Lọ is the KatanaBoss (CastD7's
# body, label "Lùm Văn Lọ", more HP than Za Mẫn). The QTE at 0 HP; a pass = the snap finale and `won`: done
# {"phase", "qte_clean"} (StoryTower then plays the beat's "after" finisher). Down = "TOANG!" -> retry() = a fresh Lọ.
# T2: a preview cut to him on the helipad when the duel opens (cuts), the QTE prompts as above (test_tower_boss: a miss
# and a pass through the real duel).
# opts: "points" (start, start_yaw, boss_at, boss_yaw), "seed".
class_name MissionBossSaber
extends StoryMission

const T_DOWN: String = "Bị Lọ chém gục trên sân thượng!"
const START_LINE: String = "Bài cuối: kiếm thuật dưới mưa."
const LOOK: String = "rooftop_rain"
const LO_HP_K: float = 1.2
const QTE_PROMPTS: Array = [{"key": "q", "label": "[Q] GẠT KIẾM"}, {"key": "lmb", "label": "[Chuột trái] BẬT NHẢY"},
	{"key": "e", "label": "[E] KẸP CỔ SỐ 21"}]
const T_FINISH: String = "Đòn chân kẹp cổ số 21!"
const CUT_S: float = 0.6

var duel: SwordDuel
var pts: Dictionary = {}
var guide: BasementGuide = null
var cuts: int = 0


func setup(r: Node3D, b: Dictionary, o: Dictionary = {}) -> void:
	super.setup(r, b, o)
	pts = opts.get("points", {})


func _start() -> void:
	hide_top_panel()
	if pts.has("start"):
		teleport_player(pts["start"], float(pts.get("start_yaw", 0.0)))
	duel = SwordDuel.new()
	duel.name = "Duel"
	add_child(duel)
	var o: Dictionary = {"roam": roam, "start_line": START_LINE, "seed": int(opts.get("seed", 7)), "rain": true,
		"look": LOOK, "qte_prompts": QTE_PROMPTS,
		"boss": {"label": "Lùm Văn Lọ", "body_fn": func(_look: Dictionary) -> Node3D: return CastD7.build("van_lo"),
			"hp_scale": float(Difficulty.pick(SwordData.HP_SCALE, SwordData.HP_SCALE_EASY)) * LO_HP_K}}
	if pts.has("boss_at"):
		o["at"] = pts["boss_at"]
	if pts.has("boss_yaw"):
		o["yaw"] = float(pts["boss_yaw"])
	duel.setup(o)
	guide = BasementGuide.new()
	add_child(guide)
	guide.setup(self)
	guide.hide_fn = func() -> bool: return duel == null or not is_instance_valid(duel) or duel.in_qte
	duel.won.connect(_on_won)
	duel.lost.connect(_on_lost)
	duel.start()
	_cut(duel.boss)


func _cut(target: Node3D) -> void:
	if target == null or not target.is_inside_tree():
		return
	cuts += 1
	var cd: CameraDirector = CameraDirector.live()
	if cd:
		cd.preview_cut(target, CUT_S)


func _tick(_dt: float) -> void:
	if guide and duel and guide.extra != duel.boss:
		guide.watch_node(duel.boss)


func _on_won() -> void:
	popup(T_FINISH, 1.6)
	finish({"phase": duel.phase, "qte_clean": duel.qte_clean})


func _on_lost() -> void:
	fail(T_DOWN)


func _reset() -> void:
	if duel:
		duel.retry()


func _cleanup() -> void:
	if duel and is_instance_valid(duel):
		duel.stop()
		duel.queue_free()
	duel = null
