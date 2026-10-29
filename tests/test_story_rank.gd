# File: res://tests/test_story_rank.gd
# Headless test of the Wave 3 ranks (plan 2026-10-30-w3-shared.md, W-3):
#   A  StoryRank scoring: the 19 ranked beats exist in StoryMissions; an unranked beat gives ""; the letter edges (85 / 65 /
#      45); perfect stats give S and the worst give C on every beat; linear criteria; a criterion that does not apply
#      passes its weight on; the optional objective (want / max / min); better() / best_of(); plain-text letters and labels.
#   B  StoryMission stats on a scripted run (manual clock, a fake host with combat.hp): time on the mission clock, every HP
#      drop summed into dmg (regeneration ignored), add_stat / set_stat, a fail counts and samples the last drop, a retry
#      keeps every stat, the stats give a letter.
#   C  The results card (StoryRankCard): off by default on a headless run; a manual run shows it without holding `done`
#      (info gains "rank"); a real run holds `done` until the card closes ([E] or the 2.5 s hold on real time); the card's
#      letter, criteria lines and "Kỷ lục" text are plain (no emoji, no star glyphs); skip_all = no card, no hold.
# Run:  godot --headless --path . --script tests/test_story_rank.gd
extends SceneTree

const RANKED: Array[String] = ["d1_stakeout", "d1_chase", "d1_brawl", "d1_corridor", "d2_chase", "d2_drift", "d2_bridge",
	"d2_duel", "d3_sneak", "d3_gunfight", "d3_crates", "d3_boss", "d4_canteen", "d4_brawl", "d4_escape", "d5_stealth",
	"d5_gunfight", "d5_hack", "d5_duel"]

var fails: Array[String] = []
var world: Node


class FakeCombat extends RefCounted:
	var hp: float = 100.0


class FakeHost extends Node3D:
	var player: ThirdPersonController = null
	var combat: FakeCombat = FakeCombat.new()
	var weapons: WeaponDirector = null
	var mounted: bool = false


class ProbeMission extends StoryMission:
	var resets: int = 0
	func _reset() -> void:
		resets += 1


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	print("--- TEST STORY RANK (W-3) ---")
	world = Node.new()
	world.name = "RankTestWorld"
	root.add_child(world)
	_part_a()
	_part_b()
	await _part_c()
	_end()


static func plain(s: String) -> bool:
	for i: int in s.length():
		var u: int = s.unicode_at(i)
		if u == 0x2026 or u == 0x2605 or u == 0x2606 or (u >= 0x2190 and u <= 0x2BFF) or u >= 0x1F000 or (u >= 0x2600 and u <= 0x27BF):
			return false
	return true


## Stats and info that meet every criterion of a beat.
static func perfect(id: String) -> Array:
	var m: Dictionary = StoryRank.MISSIONS[id]
	var st: Dictionary = {"time": 1.0, "dmg": 0.0, "fails": 0, "ko": 99}
	var info: Dictionary = {}
	if m.has("opt"):
		var o: Dictionary = m["opt"]
		info[String(o["key"])] = o["want"] if o.has("want") else (o["max"] if o.has("max") else o.get("min", true))
	return [st, info]


func _part_a() -> void:
	print("  [part] A scoring")
	_check(StoryRank.MISSIONS.size() == 19, "A: 19 ranked beats (%d)" % StoryRank.MISSIONS.size())
	for id: String in RANKED:
		_check(StoryRank.MISSIONS.has(id), "A: %s is ranked" % id)
		_check(StoryMissions.BEATS.has(id), "A: %s exists in StoryMissions" % id)
	for id2: String in StoryRank.MISSIONS.keys():
		_check(RANKED.has(id2), "A: %s is one of the plan's ranked beats" % id2)
	_check(StoryRank.report("d1_morning", {"time": 10.0}) == "" and StoryRank.evaluate("d0_wake", {}).is_empty(), "A: an unranked beat gives no letter")
	# letter edges
	_check(StoryRank.letter_of(85.0) == "S" and StoryRank.letter_of(84.9) == "A" and StoryRank.letter_of(65.0) == "A"
		and StoryRank.letter_of(64.9) == "B" and StoryRank.letter_of(45.0) == "B" and StoryRank.letter_of(44.9) == "C" and StoryRank.letter_of(0.0) == "C",
		"A: S >= 85, A >= 65, B >= 45, else C")
	# perfect and worst on every beat
	for id3: String in RANKED:
		var pi: Array = perfect(id3)
		var ev: Dictionary = StoryRank.evaluate(id3, pi[0], pi[1])
		_check(ev["letter"] == "S" and is_equal_approx(float(ev["score"]), 100.0), "A: %s perfect -> S 100 (%s %.1f)" % [id3, ev["letter"], float(ev["score"])])
		var worst: Dictionary = {"time": 9999.0, "dmg": 999.0, "fails": 9, "ko": 0}
		var winfo: Dictionary = {}
		var m: Dictionary = StoryRank.MISSIONS[id3]
		if m.has("opt"):
			var o: Dictionary = m["opt"]
			winfo[String(o["key"])] = (not o["want"]) if o.has("want") else (999 if o.has("max") else -999)
		var ew: Dictionary = StoryRank.evaluate(id3, worst, winfo)
		_check(ew["letter"] == "C" and is_equal_approx(float(ew["score"]), 0.0), "A: %s worst -> C 0 (%s %.1f)" % [id3, ew["letter"], float(ew["score"])])
		for l: Dictionary in ew["lines"]:
			_check(plain(String(l["label"])) and plain(String(l["value"])), "A: %s card text is plain (%s %s)" % [id3, l["label"], l["value"]])
	# linear criteria: d1_brawl time [45, 120], dmg [15, 70], fails [0, 2]
	var e1: Dictionary = StoryRank.evaluate("d1_brawl", {"time": 82.5, "dmg": 15.0, "fails": 1})
	var want1: float = 100.0 * (30.0 * 0.5 + 25.0 * 1.0 + 25.0 * 0.5) / 80.0
	_check(absf(float(e1["score"]) - want1) < 0.01, "A: half the time range, no damage over par, one retry -> %.1f (%.1f)" % [want1, float(e1["score"])])
	_check(int(e1["lines"].size()) == 3, "A: d1_brawl has no ko / optional line (%d lines)" % int(e1["lines"].size()))
	# a criterion that does not apply passes its weight on: dmg missing from the stats
	var e2: Dictionary = StoryRank.evaluate("d1_brawl", {"time": 10.0, "fails": 0})
	_check(is_equal_approx(float(e2["score"]), 100.0) and e2["letter"] == "S", "A: missing damage: time and retries carry the whole score (%.1f)" % float(e2["score"]))
	var e3: Dictionary = StoryRank.evaluate("d1_corridor", {"time": 160.0, "fails": 0})
	_check(absf(float(e3["score"]) - 100.0 * 25.0 / 55.0) < 0.01 and e3["letter"] == "B", "A: d1_corridor at par C, no retry -> %.1f B (%.1f %s)" % [100.0 * 25.0 / 55.0, float(e3["score"]), e3["letter"]])
	# missing optional info: no optional line
	var e4: Dictionary = StoryRank.evaluate("d3_sneak", {"time": 70.0, "fails": 0}, {})
	_check(int(e4["lines"].size()) == 2 and e4["letter"] == "S", "A: no done info: the optional objective does not apply")
	# the optional objective: want / max
	var s5: Dictionary = {"time": 70.0, "fails": 0}
	_check(StoryRank.report("d3_sneak", s5, {"spotted": false}) == "S" and StoryRank.report("d3_sneak", s5, {"spotted": true}) == "A",
		"A: d3_sneak spotted costs the optional 20 (S -> A)")
	_check(StoryRank.report("d4_canteen", {"time": 100.0, "fails": 0}, {"wrong": 0}) == "S"
		and StoryRank.report("d4_canteen", {"time": 100.0, "fails": 0}, {"wrong": 2}) == "A", "A: d4_canteen wrong <= 0 (max)")
	# ko and opt share the extra 20: d3_gunfight ko [6, 10]
	var e6: Dictionary = StoryRank.evaluate("d3_gunfight", {"time": 100.0, "dmg": 30.0, "fails": 0, "ko": 8})
	_check(absf(float(e6["score"]) - 100.0 * (30.0 + 25.0 + 25.0 + 20.0 * 0.5) / 100.0) < 0.01, "A: ko halfway between 6 and 10 -> 90 (%.1f)" % float(e6["score"]))
	# better / best_of
	_check(StoryRank.better("S", "A") and StoryRank.better("B", "C") and StoryRank.better("C", "") and not StoryRank.better("A", "A")
		and not StoryRank.better("", "C") and not StoryRank.better("B", "A"), "A: better() orders S > A > B > C > none")
	_check(StoryRank.best_of("B", "A") == "A" and StoryRank.best_of("", "C") == "C" and StoryRank.best_of("S", "S") == "S" and StoryRank.best_of("", "") == "",
		"A: best_of keeps the better letter")
	for L: String in StoryRank.LETTERS:
		_check(L.length() == 1 and L.unicode_at(0) < 128, "A: the letter %s is plain ASCII" % L)
	for k: String in StoryRank.LABELS.keys():
		_check(plain(String(StoryRank.LABELS[k])), "A: label %s is plain text" % k)
	for k2: String in StoryRank.OPT_LABELS.keys():
		_check(plain(String(StoryRank.OPT_LABELS[k2])), "A: optional label %s is plain text" % k2)


func _part_b() -> void:
	print("  [part] B stats")
	var host := FakeHost.new()
	host.name = "FakeHost"
	world.add_child(host)
	var m := ProbeMission.new()
	m.setup(host, {"id": "d1_brawl"}, {"manual": true})
	host.add_child(m)
	m.begin()
	_check(m.stats.get("time") == 0.0 and int(m.stats.get("fails")) == 0 and float(m.stats.get("dmg")) == 0.0, "B: a fresh run starts at zero (%s)" % str(m.stats))
	for i: int in 10:
		m.advance(0.5)
	_check(is_equal_approx(float(m.stats["time"]), 5.0), "B: time follows the mission clock (%.2f)" % float(m.stats["time"]))
	host.combat.hp = 80.0
	m.advance(0.1)
	host.combat.hp = 70.0
	m.advance(0.1)
	host.combat.hp = 100.0                   # regeneration: not damage, not a refund
	m.advance(0.1)
	host.combat.hp = 90.0
	m.advance(0.1)
	_check(is_equal_approx(float(m.stats["dmg"]), 40.0), "B: every HP drop adds up, regeneration ignored (%.1f)" % float(m.stats["dmg"]))
	m.add_stat("ko")
	m.add_stat("ko")
	m.add_stat("ko", 3)
	m.set_stat("custom", "x")
	_check(int(m.stats["ko"]) == 5 and m.stats["custom"] == "x", "B: add_stat / set_stat (%s)" % str(m.stats))
	host.combat.hp = 0.0                     # down: the fail samples the last drop
	m.fail("test")
	_check(m.state == "failed" and int(m.stats["fails"]) == 1 and is_equal_approx(float(m.stats["dmg"]), 130.0), "B: a fail counts and samples the last drop (%s)" % str(m.stats))
	m.advance(1.0)
	_check(is_equal_approx(float(m.stats["time"]), 5.4), "B: no time counted while failed (%.2f)" % float(m.stats["time"]))
	host.combat.hp = 100.0                   # the checkpoint revives
	m.retry()
	_check(m.resets == 1 and int(m.stats["fails"]) == 1 and int(m.stats["ko"]) == 5 and is_equal_approx(float(m.stats["dmg"]), 130.0)
		and is_equal_approx(float(m.stats["time"]), 5.4), "B: a retry keeps every stat (%s)" % str(m.stats))
	m.advance(1.0)
	host.combat.hp = 95.0
	m.advance(0.1)
	_check(is_equal_approx(float(m.stats["time"]), 6.5) and is_equal_approx(float(m.stats["dmg"]), 135.0), "B: after the retry the run goes on counting (%s)" % str(m.stats))
	var letter: String = StoryRank.report("d1_brawl", m.stats)
	_check(letter == "B", "B: the scripted run ranks B (one retry, 135 HP lost, 6.5 s) (%s, %.1f)" % [letter, float(StoryRank.evaluate("d1_brawl", m.stats)["score"])])
	m.finish({})
	_check(m.state == "done", "B: the run finishes")
	host.queue_free()


func _probe(manual_run: bool, id: String = "d1_brawl") -> Array:
	var host := FakeHost.new()
	host.name = "CardHost"
	world.add_child(host)
	var m := ProbeMission.new()
	m.setup(host, {"id": id, "title": "Ba shipper"}, {"manual": manual_run})
	host.add_child(m)
	m.begin()
	var got: Array = []
	m.done.connect(func(info: Dictionary) -> void: got.append(info))
	return [host, m, got]


func _part_c() -> void:
	print("  [part] C card")
	await process_frame   # nodes added from here on are ready at once (inside the main loop)
	_check(StoryRankCard.skip_all, "C: the card is off by default on a headless run (story tests keep their flow)")
	StoryRankCard.skip_all = false
	# manual run: the card shows, done is not held
	var r1: Array = _probe(true)
	var m1: ProbeMission = r1[1]
	m1.advance(30.0)
	m1.finish({"ko": 3})
	var got1: Array = r1[2]
	_check(got1.size() == 1 and String((got1[0] as Dictionary).get("rank", "")) == m1.rank and m1.rank != "", "C: a manual run emits done at once with the rank (%s)" % str(got1))
	var c1: StoryRankCard = m1.rank_card
	_check(c1 != null and c1.is_inside_tree() and c1.is_open and c1.letter == m1.rank, "C: the card shows the letter %s" % m1.rank)
	_check(c1.line_texts.size() == 3 and c1.line_texts[0].begins_with(StoryRank.LABELS["time"]), "C: one line per criterion (%s)" % str(c1.line_texts))
	var bad: Array[String] = []
	for t: String in c1.texts():
		if not plain(t):
			bad.append(t)
	_check(bad.is_empty(), "C: every card string is plain text (%s)" % str(bad))
	c1.step(StoryRankCard.HOLD_S + 0.1)
	_check(not c1.is_open, "C: the hold runs out")
	(r1[0] as Node).queue_free()
	# a real run: done waits for the card; [E] skips it
	var r2: Array = _probe(false)
	var m2: ProbeMission = r2[1]
	m2.finish({})
	var got2: Array = r2[2]
	_check(got2.is_empty() and m2.rank_card != null and m2.rank_card.is_open, "C: a real run holds done while the card shows")
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = KEY_E
	m2.rank_card._input(ev)
	_check(got2.size() == 1 and String((got2[0] as Dictionary).get("rank", "")) != "", "C: [E] closes the card and done follows (%s)" % str(got2))
	(r2[0] as Node).queue_free()
	# the hold on real time
	var r3: Array = _probe(false)
	var m3: ProbeMission = r3[1]
	m3.finish({})
	var got3: Array = r3[2]
	var w0: int = Time.get_ticks_msec()     # the hold runs on the wall clock (a slow motion never stretches it)
	while Time.get_ticks_msec() - w0 < 1200:
		await process_frame
	_check(got3.is_empty(), "C: still held after 1.2 s")
	while Time.get_ticks_msec() - w0 < 2800:
		await process_frame
	_check(got3.size() == 1, "C: done follows the 2.5 s hold on its own")
	(r3[0] as Node).queue_free()
	# best text
	var c4: StoryRankCard = StoryRankCard.make({"letter": "B", "lines": []}, "x", "A")
	var c5: StoryRankCard = StoryRankCard.make({"letter": "S", "lines": []}, "x", "A")
	_check(c4.best_text == StoryRankCard.T_BEST % "A" and c5.best_text == StoryRankCard.T_NEW_BEST, "C: \"Kỷ lục: A\" / \"Kỷ lục mới\" (%s / %s)" % [c4.best_text, c5.best_text])
	c4.free()
	c5.free()
	# skip_all: no card, no hold
	StoryRankCard.skip_all = true
	var r6: Array = _probe(false)
	var m6: ProbeMission = r6[1]
	m6.finish({})
	_check((r6[2] as Array).size() == 1 and m6.rank_card == null and m6.rank != "", "C: skip_all: no card, done at once, still ranked")
	(r6[0] as Node).queue_free()
	# an unranked beat: no card, no rank
	StoryRankCard.skip_all = false
	var r7: Array = _probe(false, "d1_morning")
	var m7: ProbeMission = r7[1]
	m7.finish({})
	_check((r7[2] as Array).size() == 1 and m7.rank_card == null and m7.rank == "" and not ((r7[2] as Array)[0] as Dictionary).has("rank"), "C: an unranked beat: no card")
	(r7[0] as Node).queue_free()
	StoryRankCard.skip_all = true
	await process_frame


func _end() -> void:
	if fails.is_empty():
		print("--- STORY RANK: SUCCESS ---")
		quit(0)
	else:
		print("--- STORY RANK: FAIL (%d) ---" % fails.size())
		quit(1)
