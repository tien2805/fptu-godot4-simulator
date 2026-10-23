# Story Phase A1: Cinematic System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An in-engine, data-driven cinematic system: Mixamo mocap retargeted onto the game's people with CC0 and code fallbacks, a timeline player with speed ramps, a fixed real-time length and beat sheets, music slots, impact FX and short replays. It is proven by the 25 s `seg_d1_brawl` fight at the campus back gate.

**Architecture:**
- `CineRetarget` (from `proto-cine`) becomes source-generic (mixamo/ual1/ual2/native).
- `CineMoves` turns logical moves into the best available tier, with impact frames aligned in story time.
- `CineActor` drives one real game character purely from story time.
- `CineClock` maps real time to story time through analytic ramps, so a timeline's real length is exact and checkable.
- `CineTimeline` scripts (one per cinematic) feed `CinePlayer`, which owns the camera rigs (`CineShots`), the overlay (`CineOverlay`), audio (`CineAudio`) and FX (`CineFX`).
- `CineReplayRecorder` and `CineReplay` give the automatic short replays.

**Tech Stack:** Godot 4.7.2, pure GDScript, built-in ufbx FBX import, headless SceneTree tests.

**Spec:** `docs/superpowers/specs/2026-10-23-story-phase-a1-cinematics-design.md`. Decisions A1-D1 … A1-D24 there are binding. Parent: `docs/superpowers/specs/2026-10-22-story-tool-den-design.md` (sections 8.1, 8.3, S-D14).

## Global Constraints

**Code and assets**
- Pure GDScript, Godot 4.7.2 API; no C#, no plugins or addons. Keep folder structure, scene names and existing `class_name`s.
- Textures are made only in code (`Image`). Never use AI-generated images. A1 adds no PNG files.
- Fictional names only. Never a real person's likeness, voice or name. Couriers wear unbranded jackets.
- These never go in git:
  - owner music (`user://music/`) and SFX (`user://sfx/`);
  - raw Mixamo files (`assets/local/`, git-ignored; `export_presets.cfg` excludes `assets/local/*`).

**Script rules**
- `class_name` scripts never write the identifiers `GameFX` or `StageManager`. Reach autoloads through `get_node_or_null("/root/GameFX")` / `get_node_or_null("/root/StageManager")`.
- Nothing under `scripts/cine/` writes `Engine.time_scale` (A1-D6).
- Headless safety: `CPUParticles3D` only (never `GPUParticles3D`), no RenderingDevice work.
- Do not touch `scripts/MainMenu.gd`: the main-menu change is A2.

**Godot behaviour**
- Write files containing Vietnamese with the file tools, never bash heredocs. Python printing Vietnamese needs `PYTHONIOENCODING=utf-8`.
- After adding a `class_name` script:
  1. Run `godot --headless --import --path . > /tmp/a1_imp.log 2>&1`.
  2. Check the class appears in `.godot/global_script_class_cache.cfg`.
  3. Restore the `.import` line-ending churn: `git diff --name-only -- '*.import' | xargs -r git checkout --`.
  4. Commit each new script's `.gd.uid` file with it.
- Never pipe Godot output into `grep` or `head`. Redirect to a log, then grep the log.
- Exit code 139 right after a `SUCCESS` line is a known shutdown crash: re-run once.

**Tests**
- Headless runs at about 145 fps, so tests count physics frames, pin `Engine.max_fps = 60`, or use the manual `step(dt)` clocks.
- Use a `_check(ok, msg)` helper that prints and records. Never use `assert`.
- End with `✅ SUCCESS: …` and `quit(0)`, or `❌ FAILED: …` and `quit(1)`.
- Mixamo checks skip when the files are absent: `print("  SKIP (no Mixamo files in res://assets/local/mixamo/)")`. Tests never read `D:\`.
- No preview renders or screenshots. A task may add a preview script, but no agent runs it: the owner play-tests.

**Commits**
- After every task, run the full regression (command below). Commit only when it is green.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Never push, tag or release.

**Effort**
- Implementer effort **xhigh** for Tasks 1, 5 and 7; **high** for Tasks 2, 3, 4 and 6.
- One review per task, at effort high, with no re-review loops (owner quota rule).

Regression command used by every task (run from the worktree root; it prints one line per test):

```bash
L=/tmp/a1_logs; mkdir -p $L
godot --headless --quit --check-only --path . > $L/check.log 2>&1; echo "check exit=$? errors=$(grep -c ERROR $L/check.log)"
for t in $(ls tests/test_*.gd | xargs -n1 basename | sed 's/\.gd$//'); do
  godot --headless --path . --script tests/$t.gd > $L/$t.log 2>&1; rc=$?
  echo "$t exit=$rc :: $(grep -E 'SUCCESS|FAIL' $L/$t.log | tail -1)"
done
godot --headless --path . --script tests/smoke_all_stages.gd > $L/smoke.log 2>&1; echo "smoke exit=$? errors=$(grep -c 'SCRIPT ERROR\|^ERROR:' $L/smoke.log)"
```

---

## Branch setup (controller, before Task 1)

```bash
cd C:/Users/nguye/.gemini/antigravity-ide/scratch/fptu-godot4-simulator
git worktree add .claude/worktrees/story-a1 -b story-a1 main
cd .claude/worktrees/story-a1
godot --headless --import --path . > /tmp/a1_imp.log 2>&1
git diff --name-only -- '*.import' | xargs -r git checkout --
```

Run the regression once and record the baseline. All tests should pass on `b5bbb08`.

**How the prototype comes over (A1-D3).** Task 1 copies selected files from `proto-cine` commit `ec72795` with `git checkout ec72795 -- <paths>`. That commit's parent `54c6f18` is already in main, so the files apply cleanly. This is not a merge and not a cherry-pick. The WIP scene, `CineTimeWarp`, `CineAlley`, the preview PNGs and the report stay on `proto-cine`. Read them with `git show ec72795:scripts/cine/CineBrawl.gd` when porting FX or code poses.

## File map

| File | Status | Task | Responsibility |
|---|---|---|---|
| `.gitignore`, `export_presets.cfg` | modify | 1 | ignore and exclude `assets/local/` |
| `assets/models/quaternius/anim_library/*` | create (from `ec72795`) | 1 | UAL1/UAL2 CC0 libraries, licences, CREDITS |
| `scripts/cine/CineRetarget.gd` | create (from `ec72795`), rewrite | 1 | source-generic runtime retargeter |
| `tools/import_mixamo.bat`, `tools/mixamo_report.gd` | create | 1 | owner's one-shot copy, import and check |
| `tests/preview_cine_retarget.gd` | create (from `ec72795`), modify | 1 | contact-sheet preview (never run by agents) |
| `README.md` | modify | 1, 7 | owner notes: mocap, music folder, dev entry |
| `scripts/cine/CineMoves.gd` | create | 2 | move table, tier resolution, clip-time mapping, code poses |
| `scripts/cine/CineActor.gd` | create (from `ec72795`), rewrite | 2 | one character driven by story time |
| `scripts/cine/CineClock.gd` | create | 3 | analytic clock, presets, validator, beat rows |
| `scripts/cine/CineTimeline.gd` | create | 3 | data model, authoring helpers, validate, beat sheet, slot registry |
| `tools/cine_beats.gd` | create | 3 | writes `docs/cinematics/<slot>.txt` |
| `tests/support/cine_test_timeline.gd` | create | 3 | 6 s test timeline |
| `scripts/cine/CineAudio.gd` | create | 4 | music slots, synthesized cue and sting, gain rule, SFX bank |
| `scripts/cine/CineFX.gd` | create | 4 | sparks, dust, flash, debris, crate break, stars, props |
| `scripts/cine/CineShots.gd` | create | 5 | camera rigs and whip-pan |
| `scripts/cine/CineOverlay.gd` | create | 5 | letterbox, fade, subtitles, skip bar, tag, debug overlay |
| `scripts/cine/CinePlayer.gd` | create | 5 | plays a timeline |
| `scripts/StageManager.gd` | modify | 5 | `cinematic_active` blocks the Esc pause |
| `scripts/FreeRoam.gd` | modify | 5 | `cine_stage()`, `play_cinematic()`, F9, `cinematic_finished` |
| `scripts/cine/CinePreview.gd`, `scenes/dev/CinePreview.tscn` | create | 5 | dev preview scene |
| `scripts/cine/CineReplayRecorder.gd` | create | 6 | ring buffer, replay clock |
| `scripts/cine/CineReplay.gd` | create | 6 | plays a short replay |
| `scripts/cine/timelines/seg_d1_brawl.gd` | create | 7 | the first full cinematic |
| `docs/cinematics/seg_d1_brawl.txt` | create (generated) | 7 | beat sheet |
| `tests/test_cine_retarget.gd`, `test_cine_actor.gd`, `test_cine_clock.gd`, `test_cine_timeline.gd`, `test_cine_audio_fx.gd`, `test_cine_player.gd`, `test_cine_replay.gd`, `test_cine_d1_brawl.gd` | create | 1-7 | headless tests |

---

### Task 1: Mixamo pipeline and source-generic retargeter  [effort: xhigh]

**Files:**
- Create (from `ec72795`):
  - `assets/models/quaternius/anim_library/` (all files);
  - `scripts/cine/CineRetarget.gd(.uid)`;
  - `scripts/cine/CineActor.gd(.uid)`;
  - `tests/preview_cine_retarget.gd(.uid)`.
- Rewrite: `scripts/cine/CineRetarget.gd`.
- Modify: `.gitignore`, `export_presets.cfg` (`exclude_filter`), `tests/preview_cine_retarget.gd` (source mannequin lookup), `README.md`.
- Create: `tools/import_mixamo.bat`, `tools/mixamo_report.gd`, `tests/test_cine_retarget.gd`.

**Interfaces:**
- Consumes:
  - `CharacterBuilder.build(opts)` (meta `"skeleton"`, child `"Model"` holding the body `AnimationPlayer`);
  - `CharacterBuilder._bone_global_now(sk, b)`;
  - `CharacterBuilder._mark_bone_poses_dirty(sk)`.
- Produces (`class_name CineRetarget`, static):
  - Constants: `MIXAMO_DIR = "res://assets/local/mixamo/"`, `SOURCES`, `UAL_DIR`, `UAL_FILES`.
  - State: `static var disabled: PackedStringArray`.
  - Queries:
    - `available(src_id: String) -> bool`;
    - `source(src_id) -> Dictionary`;
    - `clips(src_id) -> PackedStringArray`;
    - `has_anim(src_id, anim) -> bool`;
    - `get_anim(src_id, anim) -> Animation`;
    - `anim_length(src_id, anim, bd := {}) -> float`;
    - `clip_name_of(file_name) -> String`;
    - `norm(bone_name) -> String`.
  - Binding and sampling:
    - `bind(sk: Skeleton3D, ap: AnimationPlayer) -> Dictionary`;
    - `sample(bd, src_id, anim, t: float, loop := false, root := {}) -> {"rot": {int: Quaternion}, "pos": {int: Vector3}}`, where `root = {"xz": bool, "y": bool, "ref": float}` strips hips displacement since clip time `ref`;
    - `sample_native(bd, anim, t, loop := false)`;
    - `blend(bd, a, b, w)`;
    - `apply(sk, bd, pose)`.

- [ ] **Step 1: Bring the prototype files over**

```bash
git checkout ec72795 -- assets/models/quaternius/anim_library scripts/cine/CineRetarget.gd scripts/cine/CineRetarget.gd.uid scripts/cine/CineActor.gd scripts/cine/CineActor.gd.uid tests/preview_cine_retarget.gd tests/preview_cine_retarget.gd.uid
git status --short
```

Expected status (all `A`):
- the 7 files under `anim_library/`: `CREDITS.md`, 2 `.glb`, 2 `.glb.import`, 2 licence files;
- the 6 script and `.uid` files.

- [ ] **Step 2: Ignore and exclude the local folder**

Append to `.gitignore`:

```
# Owner-local raw assets (Mixamo FBX etc.): never committed, never exported (spec A1-D1)
assets/local/
```

In `export_presets.cfg`, add `, assets/local/*` to the end of the `exclude_filter` value. The line becomes:

```
exclude_filter="tests/*, docs/*, reference_photos/*, reference_data/*, *.py, *.bat, *.md, *.zip, build/*, assets/icon/source_frog.png, assets/icon/cocvang_icon_256.png, assets/local/*"
```

- [ ] **Step 3: Write the failing test `tests/test_cine_retarget.gd`**

```gdscript
# File: res://tests/test_cine_retarget.gd
# Headless test of the source-generic CineRetarget (spec A1-D2, A1-D5): UAL and native always; Mixamo when the owner's files
# are in res://assets/local/mixamo/ (otherwise SKIP). Checks: no NaN, flat-foot ankle height, flips turn the body over,
# horizontal root-motion strip, disabled-source hook, name helpers, sample cost.
# Run:  godot --headless --path . --script tests/test_cine_retarget.gd
extends SceneTree

const MIXAMO_EXPECTED: Array[String] = ["Jab_Cross", "Hook_Punch", "Uppercut", "Elbow_Punch", "Punch_Combo", "Roundhouse_Kick",
	"Flying_Kick", "Hurricane_Kick", "Front_Kick", "Mma_Kick", "Knee_Kick", "Front_Flip", "Back_Flip", "Running_Jump", "Cartwheel",
	"Running_Slide", "Dodging", "Block", "Stand_To_Roll", "Head_Hit", "Stomach_Hit", "Flying_Back_Death", "Knocked_Out",
	"Falling_Back_Death", "Sweep_Fall", "Getting_Up", "Taunt", "Victory", "Fighting_Idle", "Sprint", "Jumping_Down"]

var fails: Array[String] = []
var sk: Skeleton3D
var bd: Dictionary


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _ankle_y() -> float:
	var y: float = 99.0
	for s: String in ["L", "R"]:
		var lo: Transform3D = CharacterBuilder._bone_global_now(sk, sk.find_bone("LowerLeg." + s))
		y = minf(y, (lo.origin + lo.basis.y.normalized() * CineRetarget.ANKLE_DOWN_SHIN).y)
	return y


func _body() -> Transform3D:
	return CharacterBuilder._bone_global_now(sk, sk.find_bone("Body"))


func _nan(p: Dictionary) -> bool:
	for q: Quaternion in (p["rot"] as Dictionary).values():
		if is_nan(q.x) or is_nan(q.w):
			return true
	return false


func _initialize() -> void:
	print("--- TEST CINE RETARGET ---")
	var body: Node3D = CharacterBuilder.build({"preset": "player", "seed": 7, "rigged": true, "animate": false})
	sk = body.get_meta("skeleton") as Skeleton3D
	var ap: AnimationPlayer = body.get_node("Model").find_child("AnimationPlayer", true, false) as AnimationPlayer
	bd = CineRetarget.bind(sk, ap)
	# --- helpers
	_check(CineRetarget.clip_name_of("07_Flying_Kick.fbx") == "Flying_Kick", "clip_name_of strips NN_")
	_check(CineRetarget.clip_name_of("Taunt.fbx") == "Taunt", "clip_name_of keeps plain names")
	_check(CineRetarget.norm("mixamorig_LeftArm") == "LeftArm" and CineRetarget.norm("mixamorig:Hips") == "Hips", "norm strips both prefixes")
	# --- UAL + native (always present)
	_check(CineRetarget.available("ual1") and CineRetarget.available("ual2"), "UAL libraries load")
	var p: Dictionary = CineRetarget.sample(bd, "ual1", "Idle", 0.5, true)
	_check((p["rot"] as Dictionary).size() >= 45 and not _nan(p), "ual1 Idle: >= 45 bones, no NaN (got %d)" % (p["rot"] as Dictionary).size())
	CineRetarget.apply(sk, bd, p)
	var ay: float = _ankle_y()
	_check(ay > 0.03 and ay < 0.17, "ual1 Idle ankle height %.3f in 0.03..0.17 (flat feet)" % ay)
	var pn: Dictionary = CineRetarget.sample(bd, "native", "Kick_Right", 0.4)
	_check((pn["rot"] as Dictionary).size() >= 40, "native Kick_Right samples (%d bones)" % (pn["rot"] as Dictionary).size())
	var t0: int = Time.get_ticks_usec()
	for i: int in 50:
		CineRetarget.sample(bd, "ual2", "Melee_Hook", float(i) * 0.009)
	var us_ual: float = float(Time.get_ticks_usec() - t0) / 50.0
	_check(us_ual < 600.0, "UAL sample %.0f us < 600" % us_ual)
	# --- disabled hook
	CineRetarget.disabled = PackedStringArray(["ual1"])
	_check(not CineRetarget.available("ual1") and not CineRetarget.has_anim("ual1", "Idle"), "disabled source reports missing")
	CineRetarget.disabled = PackedStringArray()
	_check(CineRetarget.available("ual1"), "re-enabled source is back")
	# --- Mixamo (optional)
	if not CineRetarget.available("mixamo"):
		print("  SKIP (no Mixamo files in res://assets/local/mixamo/)")
	else:
		var have: PackedStringArray = CineRetarget.clips("mixamo")
		print("  mixamo clips: %d" % have.size())
		for nm: String in MIXAMO_EXPECTED:
			if not have.has(nm):
				print("  note: mixamo clip %s missing (fallback tier will play)" % nm)
				continue
			var ln: float = CineRetarget.anim_length("mixamo", nm)
			for u: float in [0.0, 0.5, 1.0]:
				var pm: Dictionary = CineRetarget.sample(bd, "mixamo", nm, ln * u, false, {"xz": true, "ref": 0.0})
				_check(not _nan(pm), "mixamo %s @%.0f%% no NaN" % [nm, u * 100.0])
		if have.has("Fighting_Idle"):
			var lo_y: float = 99.0
			for i: int in 8:
				CineRetarget.apply(sk, bd, CineRetarget.sample(bd, "mixamo", "Fighting_Idle", float(i) * 0.4))
				lo_y = minf(lo_y, _ankle_y())
			_check(lo_y > 0.05 and lo_y < 0.16, "mixamo Fighting_Idle lowest ankle %.3f in 0.05..0.16" % lo_y)
		if have.has("Front_Flip"):
			var up_min: float = 1.0
			for i: int in 26:
				CineRetarget.apply(sk, bd, CineRetarget.sample(bd, "mixamo", "Front_Flip", float(i) * 0.064))
				up_min = minf(up_min, _body().basis.y.normalized().dot(Vector3.UP))
			_check(up_min < -0.8, "mixamo Front_Flip turns the body over (min up·UP %.2f)" % up_min)
		if have.has("Flying_Kick"):
			var keep_d: float = 0.0
			var strip_d: float = 0.0
			CineRetarget.apply(sk, bd, CineRetarget.sample(bd, "mixamo", "Flying_Kick", 0.0))
			var b0: Vector3 = _body().origin
			for i: int in 16:
				var tt: float = float(i) * 0.1
				CineRetarget.apply(sk, bd, CineRetarget.sample(bd, "mixamo", "Flying_Kick", tt))
				keep_d = maxf(keep_d, Vector2(_body().origin.x - b0.x, _body().origin.z - b0.z).length())
				CineRetarget.apply(sk, bd, CineRetarget.sample(bd, "mixamo", "Flying_Kick", tt, false, {"xz": true, "ref": 0.0}))
				strip_d = maxf(strip_d, Vector2(_body().origin.x - b0.x, _body().origin.z - b0.z).length())
			_check(keep_d > 1.5, "Flying_Kick keeps its 2 m travel without strip (%.2f)" % keep_d)
			_check(strip_d < 0.35, "Flying_Kick in place with xz strip (drift %.2f)" % strip_d)
		var t1: int = Time.get_ticks_usec()
		for i: int in 50:
			CineRetarget.sample(bd, "mixamo", have[0], float(i) * 0.02, false, {"xz": true, "ref": 0.0})
		var us_mx: float = float(Time.get_ticks_usec() - t1) / 50.0
		_check(us_mx < 600.0, "Mixamo sample %.0f us < 600" % us_mx)
	body.free()
	if fails.is_empty():
		print("✅ SUCCESS: CINE RETARGET (UAL, native%s)" % (", mixamo" if CineRetarget.available("mixamo") else ", mixamo skipped"))
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
```

- [ ] **Step 4: Run it and see it fail**

Run: `godot --headless --path . --script tests/test_cine_retarget.gd > /tmp/t1.log 2>&1; grep -E "SUCCESS|FAILED|Invalid|not found" /tmp/t1.log`

Expected: a script error. The prototype has no `available`, `clip_name_of` or `norm`.

- [ ] **Step 5: Replace `scripts/cine/CineRetarget.gd` with the source-generic version**

This exact code was verified on 2026-10-23 in a scratch project. It ran against the owner's 31 clips, both UAL libraries and the native clips of `men/Casual_2`. Results: k = 1.032, no NaN, Mixamo sample 0.24 ms, UAL sample 0.19 ms.

```gdscript
# File: res://scripts/cine/CineRetarget.gd
# Runtime retargeter for the cinematic system (spec 2026-10-23-story-phase-a1-cinematics-design.md, A1-D2).
# Sources: "mixamo" (owner's local FBX files, res://assets/local/mixamo/, git-ignored, optional), "ual1" / "ual2"
# (Quaternius Universal Animation Library, CC0, assets/models/quaternius/anim_library/) and "native" (the clips inside the
# game body file). Target: the game's Quaternius Modular body (bones Body/Hips/Torso/.../UpperArm.L/..., Foot.L/R are IK
# targets under Root).
# Math (per target bone b with source bone s, once per skeleton and source, see _bind_src()):
#     O_b = R_s⁻¹ · A_b · R_t          R = global rest rotation, A_b = model-frame rotation that moves the target bone from
#                                      its rest into the pose equivalent to the source rest (classes delta/yaw/dir/leg/foot)
#     G_t(t) = G_s(t) · O_b            every frame; globals converted to locals parent-first
# Body position: target hip-joint midpoint = source hip-joint midpoint × k (leg-length ratio) + rest offset. Feet follow the
# shin's ankle rigidly (as CharacterBuilder._apply_bone_pose does) with the source foot's orientation.
# Root motion (A1-D5): sample(..., root) can remove the source hips' horizontal ("xz") and/or vertical ("y") displacement
# relative to clip time root["ref"], so travel comes from timeline keys instead.
# Verified on the owner's 31 Mixamo clips (Godot 4.7.2 ufbx import: bones "mixamorig_*", metres, Y along the bone, +Z
# forward, identical T-pose rest in every file): k = 1.032, standing ankle heights match the source within 2 cm.
class_name CineRetarget
extends RefCounted

const UAL_DIR: String = "res://assets/models/quaternius/anim_library/"
const UAL_FILES: Dictionary = {"ual1": "ual1_AnimationLibrary_Godot_Standard.glb", "ual2": "ual2_UAL2_Standard.glb"}
const MIXAMO_DIR: String = "res://assets/local/mixamo/"
const MIXAMO_REST: String = "Y_Bot_TPose"
const SOURCES: Array[String] = ["mixamo", "ual1", "ual2"]
const COL: Dictionary = {"ual1": 1, "ual2": 2, "mixamo": 3}
const ANKLE_DOWN_SHIN: float = 0.42   # = CharacterBuilder.ANKLE_DOWN_SHIN

## Test hook: sources listed here are treated as missing (tests force the fallback tiers).
static var disabled: PackedStringArray = []
static var _src: Dictionary = {}       # source id -> data ({} = not available)
static var _map_cache: Array = []


## Bone table: [target, ual1, ual2, mixamo (prefix stripped), class]. Fingers generated.
static func bone_map() -> Array:
	if not _map_cache.is_empty():
		return _map_cache
	var m: Array = [
		["Body", "DEF-hips", "pelvis", "Hips", "yaw"], ["Hips", "DEF-hips", "pelvis", "Hips", "yaw"],
		["Abdomen", "DEF-spine.001", "spine_01", "Spine", "yaw"], ["Torso", "DEF-spine.002", "spine_02", "Spine1", "delta"],
		["Chest", "DEF-spine.003", "spine_03", "Spine2", "delta"], ["Neck", "DEF-neck", "neck_01", "Neck", "delta"],
		["Head", "DEF-head", "Head", "Head", "delta"],
	]
	for s: String in ["L", "R"]:
		var l: String = s.to_lower()
		var side: String = "Left" if s == "L" else "Right"
		m.append(["Shoulder." + s, "DEF-shoulder." + s, "clavicle_" + l, side + "Shoulder", "delta"])
		m.append(["UpperArm." + s, "DEF-upper_arm." + s, "upperarm_" + l, side + "Arm", "dir"])
		m.append(["LowerArm." + s, "DEF-forearm." + s, "lowerarm_" + l, side + "ForeArm", "dir"])
		m.append(["Wrist." + s, "DEF-hand." + s, "hand_" + l, side + "Hand", "dir"])
		for f: Array in [["Index", "f_index", "index"], ["Middle", "f_middle", "middle"], ["Ring", "f_ring", "ring"], ["Pinky", "f_pinky", "pinky"]]:
			for i: int in range(1, 4):
				m.append(["%s%d.%s" % [f[0], i, s], "DEF-%s.%02d.%s" % [f[1], i, s], "%s_%02d_%s" % [f[2], i, l], "%sHand%s%d" % [side, f[0], i], "dir"])
		for i: int in range(1, 4):
			m.append(["Thumb%d.%s" % [i, s], "DEF-thumb.%02d.%s" % [i, s], "thumb_%02d_%s" % [i, l], "%sHandThumb%d" % [side, i], "dir"])
		m.append(["UpperLeg." + s, "DEF-thigh." + s, "thigh_" + l, side + "UpLeg", "leg"])
		m.append(["LowerLeg." + s, "DEF-shin." + s, "calf_" + l, side + "Leg", "leg"])
		m.append(["Foot." + s, "DEF-foot." + s, "foot_" + l, side + "Foot", "foot"])
	_map_cache = m
	return m


## Mixamo bone / track names come through Godot's FBX import as "mixamorig_Hips" (older exports "mixamorig:Hips").
static func norm(n: String) -> String:
	return n.trim_prefix("mixamorig_").trim_prefix("mixamorig:")


# ===========================================================================
# SOURCES
# ===========================================================================
static func available(src_id: String) -> bool:
	if disabled.has(src_id):
		return false
	return not source(src_id).is_empty()


## Source data, loaded once: {"n", "parent", "idx", "rest_local", "rest_global", "order", "anims": {name: Animation},
## "files": {name: path} (mixamo, loaded lazily), "tracks": {}}. {} when the source is missing.
static func source(src_id: String) -> Dictionary:
	if _src.has(src_id):
		return _src[src_id]
	var d: Dictionary = {}
	if src_id == "mixamo":
		d = _load_mixamo()
	elif UAL_FILES.has(src_id):
		d = _load_ual(src_id)
	_src[src_id] = d
	return d


static func _load_ual(src_id: String) -> Dictionary:
	var path: String = UAL_DIR + String(UAL_FILES[src_id])
	if not ResourceLoader.exists(path):
		return {}
	var inst: Node = (load(path) as PackedScene).instantiate()
	var sk: Skeleton3D = inst.find_child("Skeleton3D", true, false) as Skeleton3D
	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if sk == null or ap == null:
		inst.free()
		return {}
	var d: Dictionary = {"anims": {}, "files": {}, "tracks": {}}
	for a: String in ap.get_animation_list():
		d["anims"][a] = ap.get_animation(a)
	_read_skeleton(sk, d)
	inst.free()
	return d


## One FBX per clip; clip name = file stem without its "NN_" prefix ("07_Flying_Kick.fbx" -> "Flying_Kick").
## The rest skeleton comes from Y_Bot_TPose (or the first clip: every Mixamo export of one character shares it).
static func _load_mixamo() -> Dictionary:
	if not DirAccess.dir_exists_absolute(MIXAMO_DIR):
		return {}
	var files: Dictionary = {}
	for f: String in ResourceLoader.list_directory(MIXAMO_DIR):
		if not f.to_lower().ends_with(".fbx"):
			continue
		files[clip_name_of(f)] = MIXAMO_DIR + f
	if files.is_empty():
		return {}
	var rest_path: String = String(files.get(MIXAMO_REST, files.values()[0]))
	var ps: PackedScene = load(rest_path) as PackedScene
	if ps == null:
		return {}
	var inst: Node = ps.instantiate()
	var sk: Skeleton3D = inst.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null:
		inst.free()
		return {}
	var d: Dictionary = {"anims": {}, "files": files, "tracks": {}}
	_read_skeleton(sk, d)
	inst.free()
	files.erase(MIXAMO_REST)
	if not (d["idx"] as Dictionary).has("Hips"):
		push_warning("CineRetarget: %s has no mixamorig Hips bone; Mixamo source disabled" % rest_path)
		return {}
	return d


static func clip_name_of(file_name: String) -> String:
	var stem: String = file_name.get_file().get_basename()
	if stem.length() > 3 and stem[2] == "_" and stem.substr(0, 2).is_valid_int():
		return stem.substr(3)
	return stem


## Clip names of a source (sorted).
static func clips(src_id: String) -> PackedStringArray:
	var d: Dictionary = source(src_id)
	var out: PackedStringArray = []
	if d.is_empty():
		return out
	for k: String in (d["anims"] as Dictionary).keys():
		out.append(k)
	for k2: String in (d["files"] as Dictionary).keys():
		if not out.has(k2):
			out.append(k2)
	out.sort()
	return out


static func has_anim(src_id: String, anim_name: String) -> bool:
	if not available(src_id):
		return false
	var d: Dictionary = source(src_id)
	return (d["anims"] as Dictionary).has(anim_name) or (d["files"] as Dictionary).has(anim_name)


## Animation of a source (Mixamo files load on first use: the longest animation in the file, "mixamo_com").
static func get_anim(src_id: String, anim_name: String) -> Animation:
	var d: Dictionary = source(src_id)
	if d.is_empty():
		return null
	if (d["anims"] as Dictionary).has(anim_name):
		return d["anims"][anim_name]
	if not (d["files"] as Dictionary).has(anim_name):
		return null
	var ps: PackedScene = load(String(d["files"][anim_name])) as PackedScene
	var best: Animation = null
	if ps:
		var inst: Node = ps.instantiate()
		var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			for a: String in ap.get_animation_list():
				var an: Animation = ap.get_animation(a)
				if best == null or an.length > best.length:
					best = an
		inst.free()
	d["anims"][anim_name] = best
	return best


static func anim_length(src_id: String, anim_name: String, bd: Dictionary = {}) -> float:
	if src_id == "native":
		var a0: Animation = (bd["native"]["anims"] as Dictionary).get(anim_name)
		return a0.length if a0 else 0.0
	var a: Animation = get_anim(src_id, anim_name)
	return a.length if a else 0.0


static func _read_skeleton(sk: Skeleton3D, d: Dictionary) -> void:
	var n: int = sk.get_bone_count()
	var parent: PackedInt32Array = []
	var names: Dictionary = {}
	var rest_local: Array[Transform3D] = []
	var rest_global: Array[Transform3D] = []
	for b: int in n:
		parent.append(sk.get_bone_parent(b))
		names[norm(sk.get_bone_name(b))] = b
		rest_local.append(sk.get_bone_rest(b))
		rest_global.append(sk.get_bone_global_rest(b))
	d["n"] = n
	d["parent"] = parent
	d["idx"] = names
	d["rest_local"] = rest_local
	d["rest_global"] = rest_global
	d["order"] = _parent_first(parent)


static func _parent_first(parent: PackedInt32Array) -> PackedInt32Array:
	var order: PackedInt32Array = []
	var done: Dictionary = {}
	while order.size() < parent.size():
		for b: int in parent.size():
			if done.has(b):
				continue
			if parent[b] < 0 or done.has(parent[b]):
				order.append(b)
				done[b] = true
	return order


## Bone index -> [rotation track, position track] of an animation (cached per source and clip).
static func _tracks_of(d: Dictionary, anim_name: String, a: Animation) -> Dictionary:
	var cache: Dictionary = d["tracks"]
	if cache.has(anim_name):
		return cache[anim_name]
	var idx: Dictionary = d["idx"]
	var out: Dictionary = {}
	for t: int in a.get_track_count():
		var bone: String = norm(String(a.track_get_path(t).get_concatenated_subnames()))
		if not idx.has(bone):
			continue
		var b: int = idx[bone]
		var e: Array = out.get(b, [-1, -1])
		match a.track_get_type(t):
			Animation.TYPE_ROTATION_3D:
				e[0] = t
			Animation.TYPE_POSITION_3D:
				e[1] = t
		out[b] = e
	cache[anim_name] = out
	return out


## Source globals (skeleton space) at clip time tt.
static func _src_globals(src: Dictionary, a: Animation, tracks: Dictionary, tt: float) -> Array[Transform3D]:
	var n: int = src["n"]
	var sp: PackedInt32Array = src["parent"]
	var srl: Array = src["rest_local"]
	var sg: Array[Transform3D] = []
	sg.resize(n)
	for b: int in src["order"]:
		var loc: Transform3D = srl[b]
		if tracks.has(b):
			var e: Array = tracks[b]
			if e[0] >= 0:
				loc.basis = Basis(a.rotation_track_interpolate(e[0], tt))
			if e[1] >= 0:
				loc.origin = a.position_track_interpolate(e[1], tt)
		sg[b] = sg[sp[b]] * loc if sp[b] >= 0 else loc
	return sg


## Position of one source bone (skeleton space) at clip time tt: walks the parent chain only.
static func _src_bone_pos(src: Dictionary, a: Animation, tracks: Dictionary, bone: int, tt: float) -> Vector3:
	var xf := Transform3D.IDENTITY
	var b: int = bone
	var sp: PackedInt32Array = src["parent"]
	while b >= 0:
		var loc: Transform3D = src["rest_local"][b]
		if tracks.has(b):
			var e: Array = tracks[b]
			if e[0] >= 0:
				loc.basis = Basis(a.rotation_track_interpolate(e[0], tt))
			if e[1] >= 0:
				loc.origin = a.position_track_interpolate(e[1], tt)
		xf = loc * xf
		b = sp[b]
	return xf.origin


# ===========================================================================
# BINDING TO A TARGET SKELETON
# ===========================================================================
## Retarget data for one target skeleton. ap: the body file's own AnimationPlayer (native clips). Source bindings are made
## lazily on the first sample of each source (_ensure_src).
static func bind(sk: Skeleton3D, ap: AnimationPlayer) -> Dictionary:
	var t: Dictionary = {}
	_read_skeleton(sk, t)
	var rest_rot: Array[Quaternion] = []
	var rest_pos: Array[Vector3] = []
	for b: int in t["n"]:
		rest_rot.append((t["rest_local"][b] as Transform3D).basis.get_rotation_quaternion())
		rest_pos.append((t["rest_local"][b] as Transform3D).origin)
	t["rest_rot"] = rest_rot
	t["rest_pos"] = rest_pos
	var nat: Dictionary = {"anims": {}, "idx": t["idx"], "tracks": {}}
	if ap:
		for a: String in ap.get_animation_list():
			nat["anims"][a] = ap.get_animation(a)
	t["native"] = nat
	return t


static func _ensure_src(t: Dictionary, src_id: String) -> Dictionary:
	if t.has(src_id):
		return t[src_id]
	var src: Dictionary = source(src_id)
	var d: Dictionary = {} if src.is_empty() else _bind_src(t, src, int(COL[src_id]))
	t[src_id] = d
	return d


static func _bind_src(t: Dictionary, src: Dictionary, col: int) -> Dictionary:
	var tidx: Dictionary = t["idx"]
	var sidx: Dictionary = src["idx"]
	var tg: Array = t["rest_global"]
	var sg: Array = src["rest_global"]
	var maps: Array = []        # [target bone, source bone, O (Basis)]
	for row: Array in bone_map():
		if not (tidx.has(row[0]) and sidx.has(row[col])):
			continue
		var tb: int = tidx[row[0]]
		var sb: int = sidx[row[col]]
		var rt: Basis = (tg[tb] as Transform3D).basis.orthonormalized()
		var rs: Basis = (sg[sb] as Transform3D).basis.orthonormalized()
		var a: Basis = _align(String(row[4]), String(row[0]), rt, rs, t)
		maps.append([tb, sb, (rs.inverse() * a * rt).orthonormalized()])
	var d: Dictionary = {"maps": maps}
	var tl: int = tidx["UpperLeg.L"]
	var tr: int = tidx["UpperLeg.R"]
	var sl: int = sidx[_src_name("UpperLeg.L", col)]
	var sr: int = sidx[_src_name("UpperLeg.R", col)]
	var mid_t: Vector3 = ((tg[tl] as Transform3D).origin + (tg[tr] as Transform3D).origin) * 0.5
	var mid_s: Vector3 = ((sg[sl] as Transform3D).origin + (sg[sr] as Transform3D).origin) * 0.5
	var knee_t: Vector3 = (tg[tidx["LowerLeg.L"]] as Transform3D).origin
	var ankle_t: Vector3 = _ankle_rest(t, "L")
	var len_t: float = knee_t.distance_to((tg[tl] as Transform3D).origin) + ANKLE_DOWN_SHIN + ankle_t.y
	var s_shin: Vector3 = (sg[sidx[_src_name("LowerLeg.L", col)]] as Transform3D).origin
	var s_foot: Vector3 = (sg[sidx[_src_name("Foot.L", col)]] as Transform3D).origin
	var len_s: float = s_shin.distance_to((sg[sl] as Transform3D).origin) + s_foot.distance_to(s_shin) + s_foot.y
	var k: float = len_t / len_s
	d["k"] = k
	d["src_thighs"] = [sl, sr]
	d["src_hips"] = sidx[_src_name("Body", col)]
	d["hip_off"] = Vector3(mid_t.x - k * mid_s.x, 0.0, mid_t.z - k * mid_s.z)
	var body: int = tidx["Body"]
	d["body"] = body
	d["hip_c"] = (tg[body] as Transform3D).basis.orthonormalized().inverse() * (mid_t - (tg[body] as Transform3D).origin)
	return d


static func _src_name(target: String, col: int) -> String:
	for row: Array in bone_map():
		if row[0] == target:
			return String(row[col])
	return ""


## Target ankle at rest (skeleton space): ANKLE_DOWN_SHIN along the shin's Y axis from the knee.
static func _ankle_rest(t: Dictionary, s: String) -> Vector3:
	var lo: Transform3D = t["rest_global"][t["idx"]["LowerLeg." + s]]
	return lo.origin + lo.basis.y.normalized() * ANKLE_DOWN_SHIN


## A_b: model-frame rotation taking the target bone from its rest to the pose equivalent to the source rest.
static func _align(mode: String, tname: String, rt: Basis, rs: Basis, t: Dictionary) -> Basis:
	match mode:
		"yaw":
			var ft := Vector3(rt.z.x, 0.0, rt.z.z).normalized()
			var fs := Vector3(rs.z.x, 0.0, rs.z.z).normalized()
			return Basis(Quaternion(ft, fs))
		"dir":
			return Basis(Quaternion(rt.y.normalized(), rs.y.normalized()))
		"leg":
			var s: String = tname.substr(tname.length() - 1)
			var ft1: Basis = _frame(rt.y, _knee_dir_rest(t, s))
			var fs1: Basis = _frame(rs.y, Vector3(0.0, 0.0, 1.0))
			return fs1 * ft1.inverse()
		"foot":
			var ft2: Basis = _frame_fwd(Vector3(rt.y.x, 0.0, rt.y.z))
			var fs2: Basis = _frame_fwd(Vector3(rs.y.x, 0.0, rs.y.z))
			return fs2 * ft2.inverse()
	return Basis.IDENTITY


static func _knee_dir_rest(t: Dictionary, s: String) -> Vector3:
	var hip: Vector3 = (t["rest_global"][t["idx"]["UpperLeg." + s]] as Transform3D).origin
	var knee: Vector3 = (t["rest_global"][t["idx"]["LowerLeg." + s]] as Transform3D).origin
	var ankle: Vector3 = _ankle_rest(t, s)
	var axis: Vector3 = (ankle - hip).normalized()
	var off: Vector3 = (knee - hip) - axis * (knee - hip).dot(axis)
	if off.length() < 0.02:
		return Vector3(0.0, 0.0, 1.0)
	return off.normalized()


static func _frame(y: Vector3, z_hint: Vector3) -> Basis:
	var yy: Vector3 = y.normalized()
	var x: Vector3 = yy.cross(z_hint).normalized()
	var z: Vector3 = x.cross(yy).normalized()
	return Basis(x, yy, z)


static func _frame_fwd(fwd: Vector3) -> Basis:
	var z: Vector3 = fwd.normalized()
	var x: Vector3 = Vector3.UP.cross(z).normalized()
	return Basis(x, Vector3.UP, z)


# ===========================================================================
# SAMPLING
# ===========================================================================
## Local pose of the target skeleton for clip anim_name of source src_id at clip time t (seconds).
## root: {"xz": bool, "y": bool, "ref": float} removes the source hips' displacement since clip time ref.
## Returns {"rot": {bone: Quaternion}, "pos": {bone: Vector3}}; {} pose parts = rest. Empty dicts if the clip is missing.
static func sample(bd: Dictionary, src_id: String, anim_name: String, t: float, loop: bool = false, root: Dictionary = {}) -> Dictionary:
	if src_id == "native":
		return sample_native(bd, anim_name, t, loop)
	var ld: Dictionary = _ensure_src(bd, src_id)
	var a: Animation = get_anim(src_id, anim_name)
	if ld.is_empty() or a == null:
		return {"rot": {}, "pos": {}}
	var src: Dictionary = source(src_id)
	var tt: float = _clip_time(a, t, loop)
	var tracks: Dictionary = _tracks_of(src, anim_name, a)
	var sg: Array[Transform3D] = _src_globals(src, a, tracks, tt)
	var tg_rot: Dictionary = {}
	for m: Array in ld["maps"]:
		tg_rot[m[0]] = sg[m[1]].basis.orthonormalized() * (m[2] as Basis)
	var th: Array = ld["src_thighs"]
	var mid_s: Vector3 = (sg[th[0]].origin + sg[th[1]].origin) * 0.5
	var strip_xz: bool = bool(root.get("xz", false))
	var strip_y: bool = bool(root.get("y", false))
	if strip_xz or strip_y:
		var h: int = ld["src_hips"]
		var ref: Vector3 = _src_bone_pos(src, a, tracks, h, _clip_time(a, float(root.get("ref", 0.0)), loop))
		var dlt: Vector3 = sg[h].origin - ref
		mid_s -= Vector3(dlt.x if strip_xz else 0.0, dlt.y if strip_y else 0.0, dlt.z if strip_xz else 0.0)
	var k: float = ld["k"]
	var mid_t: Vector3 = mid_s * k + (ld["hip_off"] as Vector3)
	var body: int = ld["body"]
	var body_basis: Basis = tg_rot.get(body, (bd["rest_global"][body] as Transform3D).basis)
	var body_pos: Vector3 = mid_t - body_basis * (ld["hip_c"] as Vector3)
	var tn: int = bd["n"]
	var tp: PackedInt32Array = bd["parent"]
	var trl: Array = bd["rest_local"]
	var cur: Array[Transform3D] = []
	cur.resize(tn)
	var out_rot: Dictionary = {}
	var out_pos: Dictionary = {}
	var feet: Dictionary = {}
	for b: int in bd["order"]:
		var pg: Transform3D = cur[tp[b]] if tp[b] >= 0 else Transform3D.IDENTITY
		var loc: Transform3D = trl[b]
		if b == body:
			loc = pg.affine_inverse() * Transform3D(body_basis, body_pos)
			out_pos[b] = loc.origin
			out_rot[b] = loc.basis.get_rotation_quaternion()
		elif tg_rot.has(b):
			var nm: String = _name_of(bd, b)
			if nm.begins_with("Foot."):
				feet[nm.substr(5)] = b
			else:
				loc.basis = pg.basis.orthonormalized().inverse() * (tg_rot[b] as Basis)
				out_rot[b] = loc.basis.get_rotation_quaternion()
		cur[b] = pg * loc
	for s: String in feet.keys():
		var fb: int = feet[s]
		var lb: int = bd["idx"]["LowerLeg." + s]
		var l0: Transform3D = bd["rest_global"][lb]
		var a_rest: Vector3 = _ankle_rest(bd, s)
		var a_now: Vector3 = cur[lb] * (l0.affine_inverse() * a_rest)
		var f0: Transform3D = bd["rest_global"][fb]
		var fbasis: Basis = tg_rot[fb]
		var forigin: Vector3 = a_now + fbasis * (f0.basis.orthonormalized().inverse() * (f0.origin - a_rest))
		var pf: int = tp[fb]
		var pgf: Transform3D = cur[pf] if pf >= 0 else Transform3D.IDENTITY
		var locf: Transform3D = pgf.affine_inverse() * Transform3D(fbasis, forigin)
		out_rot[fb] = locf.basis.get_rotation_quaternion()
		out_pos[fb] = locf.origin
	return {"rot": out_rot, "pos": out_pos}


static func _name_of(bd: Dictionary, b: int) -> String:
	if not bd.has("names"):
		var arr: PackedStringArray = []
		arr.resize(bd["n"])
		for nm: String in (bd["idx"] as Dictionary).keys():
			arr[bd["idx"][nm]] = nm
		bd["names"] = arr
	return (bd["names"] as PackedStringArray)[b]


static func _clip_time(a: Animation, t: float, loop: bool) -> float:
	if loop and a.length > 0.0:
		return fposmod(t, a.length)
	return clampf(t, 0.0, a.length)


## Clip inside the body file: tracks already match the skeleton.
static func sample_native(bd: Dictionary, anim_name: String, t: float, loop: bool = false) -> Dictionary:
	var nat: Dictionary = bd["native"]
	var a: Animation = (nat["anims"] as Dictionary).get(anim_name)
	if a == null:
		return {"rot": {}, "pos": {}}
	var tt: float = _clip_time(a, t, loop)
	var tracks: Dictionary = _tracks_of(nat, anim_name, a)
	var out_rot: Dictionary = {}
	var out_pos: Dictionary = {}
	for b: int in tracks.keys():
		var e: Array = tracks[b]
		if e[0] >= 0:
			out_rot[b] = a.rotation_track_interpolate(e[0], tt)
		if e[1] >= 0:
			out_pos[b] = a.position_track_interpolate(e[1], tt)
	return {"rot": out_rot, "pos": out_pos}


## Blend two local poses (w = 0 -> a, 1 -> b); missing bones use the rest pose.
static func blend(bd: Dictionary, a: Dictionary, b: Dictionary, w: float) -> Dictionary:
	if w <= 0.0:
		return a
	if w >= 1.0:
		return b
	var rr: Array = bd["rest_rot"]
	var rp: Array = bd["rest_pos"]
	var out_rot: Dictionary = {}
	var out_pos: Dictionary = {}
	var ar: Dictionary = a["rot"]
	var br: Dictionary = b["rot"]
	for k: int in ar.keys():
		out_rot[k] = (ar[k] as Quaternion).slerp(br.get(k, rr[k]), w)
	for k: int in br.keys():
		if not ar.has(k):
			out_rot[k] = (rr[k] as Quaternion).slerp(br[k], w)
	var ap_: Dictionary = a["pos"]
	var bp: Dictionary = b["pos"]
	for k: int in ap_.keys():
		out_pos[k] = (ap_[k] as Vector3).lerp(bp.get(k, rp[k]), w)
	for k: int in bp.keys():
		if not ap_.has(k):
			out_pos[k] = (rp[k] as Vector3).lerp(bp[k], w)
	return {"rot": out_rot, "pos": out_pos}


## Write a pose to the skeleton: every bone (bones without a key go to rest).
static func apply(sk: Skeleton3D, bd: Dictionary, pose: Dictionary) -> void:
	var rr: Array = bd["rest_rot"]
	var rp: Array = bd["rest_pos"]
	var pr: Dictionary = pose["rot"]
	var pp: Dictionary = pose["pos"]
	for b: int in bd["n"]:
		sk.set_bone_pose_rotation(b, pr.get(b, rr[b]))
		sk.set_bone_pose_position(b, pp.get(b, rp[b]))
	CharacterBuilder._mark_bone_poses_dirty(sk)
```

The prototype `CineActor` still calls `CineRetarget.bind`, `sample(bd, lib, anim, t, loop)` and `anim_length`. All three keep their signatures, so it compiles until Task 2 rewrites it.

In `tests/preview_cine_retarget.gd`, replace the mannequin lookup `CineRetarget.LIB_DIR + String(CineRetarget.LIB_FILES[lib_name])` with `CineRetarget.UAL_DIR + String(CineRetarget.UAL_FILES[lib_name])`. Guard it with `if CineRetarget.UAL_FILES.has(lib_name):`. Mixamo and native clips show only the game character. Update the header comment so `CLIPS="mixamo:Flying_Kick,ual2:Melee_Hook"` is a valid example. Do not run the preview.

- [ ] **Step 6: Import, then run the test without Mixamo files**

Run:

```bash
godot --headless --import --path . > /tmp/a1_imp.log 2>&1; grep -c "class_name\|CineRetarget" .godot/global_script_class_cache.cfg
git diff --name-only -- '*.import' | xargs -r git checkout --
godot --headless --path . --script tests/test_cine_retarget.gd > /tmp/t1.log 2>&1; grep -E "SKIP|SUCCESS|FAILED|✗" /tmp/t1.log
```

Expected: `SKIP (no Mixamo files …)`, then `✅ SUCCESS: CINE RETARGET (UAL, native, mixamo skipped)`.

- [ ] **Step 7: Write the owner's helper `tools/import_mixamo.bat`**

```bat
@echo off
chcp 65001 >nul
cd /d "%~dp0\.."
echo ============================================================
echo   MIXAMO MOCAP CHO CINEMATIC (chi tren may nay, khong commit)
echo ============================================================
set "SRC=%~1"
if "%SRC%"=="" set "SRC=D:\mixamo_fight"
if not exist "%SRC%\*.fbx" (
    echo [LOI] Khong thay file .fbx trong "%SRC%".
    echo       Cach dung: tools\import_mixamo.bat [thu muc chua file .fbx]
    pause
    exit /b 1
)
if not exist assets\local\mixamo mkdir assets\local\mixamo
echo [1/3] Chep file FBX tu "%SRC%" vao assets\local\mixamo ...
copy /Y "%SRC%\*.fbx" assets\local\mixamo\ >nul
echo [2/3] Godot import FBX (ufbx co san)...
godot --headless --import --path . > assets\local\mixamo_import.log 2>&1
echo [3/3] Kiem tra retarget...
godot --headless --path . --script tools/mixamo_report.gd
echo Xong. Thu muc assets\local\ da duoc .gitignore va loai khoi ban export.
pause
```

- [ ] **Step 8: Write `tools/mixamo_report.gd`**

```gdscript
# File: res://tools/mixamo_report.gd
# Owner tool (run by tools/import_mixamo.bat): lists the Mixamo clips found in res://assets/local/mixamo/, the expected ones
# that are missing, and checks every clip retargets onto a game body without NaN.
# Run:  godot --headless --path . --script tools/mixamo_report.gd
extends SceneTree

const EXPECTED: Array[String] = ["Jab_Cross", "Hook_Punch", "Uppercut", "Elbow_Punch", "Punch_Combo", "Roundhouse_Kick",
	"Flying_Kick", "Hurricane_Kick", "Front_Kick", "Mma_Kick", "Knee_Kick", "Front_Flip", "Back_Flip", "Running_Jump", "Cartwheel",
	"Running_Slide", "Dodging", "Block", "Stand_To_Roll", "Head_Hit", "Stomach_Hit", "Flying_Back_Death", "Knocked_Out",
	"Falling_Back_Death", "Sweep_Fall", "Getting_Up", "Taunt", "Victory", "Fighting_Idle", "Sprint", "Jumping_Down"]


func _initialize() -> void:
	if not CineRetarget.available("mixamo"):
		print("MIXAMO REPORT: khong co file nao trong %s (game van chay voi clip CC0 / tu dung)." % CineRetarget.MIXAMO_DIR)
		quit(1)
		return
	var body: Node3D = CharacterBuilder.build({"preset": "player", "seed": 1, "rigged": true, "animate": false})
	var sk: Skeleton3D = body.get_meta("skeleton") as Skeleton3D
	var ap: AnimationPlayer = body.get_node("Model").find_child("AnimationPlayer", true, false) as AnimationPlayer
	var bd: Dictionary = CineRetarget.bind(sk, ap)
	var have: PackedStringArray = CineRetarget.clips("mixamo")
	var bad: int = 0
	for nm: String in have:
		var ln: float = CineRetarget.anim_length("mixamo", nm)
		var p: Dictionary = CineRetarget.sample(bd, "mixamo", nm, ln * 0.5)
		var ok: bool = (p["rot"] as Dictionary).size() >= 45
		for q: Quaternion in (p["rot"] as Dictionary).values():
			ok = ok and not is_nan(q.x)
		bad += 0 if ok else 1
		print("  %-20s %5.2f s  %s" % [nm, ln, "OK" if ok else "LOI"])
	var missing: Array[String] = []
	for nm: String in EXPECTED:
		if not have.has(nm):
			missing.append(nm)
	if not missing.is_empty():
		print("  Thieu (se dung clip du phong): ", ", ".join(missing))
	print("MIXAMO REPORT: %d clip, %d thieu, %d loi, k = %.3f" % [have.size(), missing.size(), bad, float(bd["mixamo"]["k"]) if bd.has("mixamo") else 0.0])
	body.free()
	quit(0 if bad == 0 else 1)
```

- [ ] **Step 9: Exercise the Mixamo branch on this machine (the files stay git-ignored)**

Run (Git Bash; it copies the owner's files into the worktree's ignored folder):

```bash
mkdir -p assets/local/mixamo && cp /d/mixamo_fight/*.fbx assets/local/mixamo/
godot --headless --import --path . > /tmp/a1_imp.log 2>&1
git diff --name-only -- '*.import' | xargs -r git checkout --
godot --headless --path . --script tools/mixamo_report.gd > /tmp/mr.log 2>&1; grep -E "MIXAMO REPORT|LOI|Thieu" /tmp/mr.log
godot --headless --path . --script tests/test_cine_retarget.gd > /tmp/t1.log 2>&1; grep -E "mixamo clips|SUCCESS|FAILED|✗" /tmp/t1.log
git status --short assets/
```

Expected:
- `MIXAMO REPORT: 31 clip, 0 thieu, 0 loi, k = 1.03x`;
- the test prints `mixamo clips: 31` and `✅ SUCCESS: CINE RETARGET (UAL, native, mixamo)`;
- `git status` shows nothing under `assets/local/`.

If `D:\mixamo_fight` is not present, skip this step and note it in the task report.

- [ ] **Step 10: README owner notes**

Add a section `## Cinematic: mocap Mixamo và nhạc (tùy chọn)` to `README.md`. It says:
- Mocap: run `tools\import_mixamo.bat` (default source `D:\mixamo_fight`, or pass a folder). The files are copied into `assets\local\mixamo\`, which is ignored by git and excluded from builds. Without them, the game uses the CC0 Quaternius clips or code poses.
- Music: put `<slot>.ogg` or `<slot>.mp3` in the game's user folder `music\`. The exact path is printed by `godot --headless --path . --script tools/cine_beats.gd` (Task 3) and shown by the preview scene (Task 5). Slot names are in `docs/superpowers/specs/2026-10-22-story-tool-den-design.md` section 8.3. A file longer than the cinematic fades out over the last 0.5 s; without a file, synthesized music plays.

Write it with the file tools (Vietnamese text).

- [ ] **Step 11: Full regression, then commit**

Run the regression command. Expected: check 0 errors, every test `SUCCESS`, smoke 0 errors.

```bash
git add .gitignore export_presets.cfg README.md assets/models/quaternius/anim_library scripts/cine/CineRetarget.gd scripts/cine/CineRetarget.gd.uid scripts/cine/CineActor.gd scripts/cine/CineActor.gd.uid tests/preview_cine_retarget.gd tests/preview_cine_retarget.gd.uid tools/import_mixamo.bat tools/mixamo_report.gd tools/mixamo_report.gd.uid tests/test_cine_retarget.gd tests/test_cine_retarget.gd.uid
git commit -m "feat(cine): source-generic retargeter with optional local Mixamo mocap (ported from proto-cine ec72795 by path checkout), owner import helper, assets/local ignored and excluded from export

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Moves, tiers and the story-time actor  [effort: high]

**Files:**
- Create: `scripts/cine/CineMoves.gd`, `tests/test_cine_actor.gd`.
- Rewrite: `scripts/cine/CineActor.gd`.

**Interfaces:**
- Consumes:
  - `CineRetarget` (Task 1);
  - `CharacterBuilder.build/_apply_bone_pose/_char_rot_local/_bone_global_now/_base_of/get_pivot/BONE_OF`;
  - `PS2Head.cell_offset(cell)`, `PS2Head.CELLS`.
- Produces (`class_name CineMoves`, static):
  - `TIERS = ["mixamo", "ual", "native", "code"]`;
  - `static var max_tier: int = 0`;
  - `MOVES: Dictionary`;
  - `has_move(name) -> bool`;
  - `is_strike(name) -> bool`;
  - `tier_index(t: String) -> int`;
  - `resolve(name, bd) -> Dictionary`. Keys: `move, t, a, tier, from, hit, to, arc, spin (Vector3 deg), add, yaw, dur, hit_u, loop, air, root_y, hold_spin`; `{}` if unknown;
  - `clip_time(res, x: float, dur: float, loop: bool) -> float`;
  - `code_pose(pose: String, u: float) -> Dictionary`.
- Produces (`class_name CineActor extends Node3D`):
  - `setup(opts: Dictionary) -> void`;
  - `display_name: String`;
  - `move(s, move_name, opts := {}) -> Dictionary`, where opts may hold `dur`, `fade`, `loop`;
  - `strike(s_hit, move_name, opts := {}) -> Dictionary`;
  - `key(s, pos: Vector3, yaw: float, spin_euler := Vector3.ZERO, mode := "smooth", arc := 0.0)`;
  - `override(s0, s1, pose: Callable, fade_in := 0.08, fade_out := 0.12, mode := "abs")`;
  - `expr(s, cell)`;
  - `look(s0, s1, target: Variant)`, where target is a `Node3D` or a parent-local `Vector3`;
  - `show_at(s, visible)`;
  - `evaluate(s)`;
  - `bone_world(bone) -> Vector3`;
  - `active_move(s) -> Dictionary`;
  - `sk`, `bd`, `body`, `spin`.

- [ ] **Step 1: Write the failing test `tests/test_cine_actor.gd`**

```gdscript
# File: res://tests/test_cine_actor.gd
# Headless test of CineMoves + CineActor (spec A1-D4, A1-D5, A1-D21, A1-D22): tier resolution under every cap, impact frame
# alignment, piecewise clip-time mapping, reversed windows, pure function of story time, root keys and arcs, airborne
# extras for code-tier flips and kicks, look-at, expression cells, visibility, evaluate cost.
# Run:  godot --headless --path . --script tests/test_cine_actor.gd
extends SceneTree

var fails: Array[String] = []
var world: Node3D


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _actor(seed: int) -> CineActor:
	var a := CineActor.new()
	world.add_child(a)
	a.setup({"preset": "player", "seed": seed})
	return a


func _initialize() -> void:
	print("--- TEST CINE ACTOR ---")
	CharacterBuilder.ps2 = true          # PS2 head with expression cells (vice style)
	world = Node3D.new()
	root.add_child(world)
	# --- clip_time mapping
	var res := {"from": 0.0, "hit": 0.4, "to": 1.0, "hit_u": 0.5}
	_check(absf(CineMoves.clip_time(res, 1.0, 2.0, false) - 0.4) < 1e-6, "impact maps to the clip's hit frame")
	_check(absf(CineMoves.clip_time(res, 0.5, 2.0, false) - 0.2) < 1e-6, "first half linear to the hit")
	_check(absf(CineMoves.clip_time(res, 1.5, 2.0, false) - 0.7) < 1e-6, "second half linear from the hit")
	var rev := {"from": 1.2, "hit": -1.0, "to": 0.0, "hit_u": -1.0}
	_check(absf(CineMoves.clip_time(rev, 0.0, 1.0, false) - 1.2) < 1e-6 and absf(CineMoves.clip_time(rev, 1.0, 1.0, false)) < 1e-6, "from > to plays backwards")
	var lp := {"from": 0.5, "hit": -1.0, "to": 1.5, "hit_u": -1.0}
	_check(absf(CineMoves.clip_time(lp, 2.25, 9.0, true) - 0.75) < 1e-6, "loops wrap inside [from, to] at natural speed")
	# --- every move resolves under every cap, impact frames align
	var a: CineActor = _actor(11)
	for cap: int in [0, 1, 2, 3]:
		CineMoves.max_tier = cap
		for mv: String in CineMoves.MOVES.keys():
			var r: Dictionary = CineMoves.resolve(mv, a.bd)
			_check(not r.is_empty(), "move %s resolves at cap %d" % [mv, cap])
			if r.is_empty():
				continue
			if cap == 0 and r["tier"] == "mixamo":
				_check(CineRetarget.available("mixamo"), "mixamo tier only with files")
			if CineMoves.is_strike(mv) and r["tier"] != "code":
				var x_hit: float = float(r["hit_u"]) * float(r["dur"])
				_check(absf(CineMoves.clip_time(r, x_hit, float(r["dur"]), false) - float(r["hit"])) < 1e-5, "%s impact frame aligned (%s)" % [mv, r["tier"]])
	CineMoves.max_tier = 3
	_check(CineMoves.resolve("flying_kick", a.bd)["tier"] == "code", "cap 3: flying kick uses the code pose")
	_check(CineMoves.resolve("jab", a.bd)["tier"] == "native", "cap 3: a move without a code entry falls back to its last tier")
	CineMoves.max_tier = 1
	_check(CineMoves.resolve("jab", a.bd)["tier"] == "ual", "cap 1: jab from UAL")
	CineMoves.max_tier = 0
	# --- pure function of story time
	a.move(0.0, "fight_idle")
	a.strike(1.0, "jab")
	a.strike(2.0, "hit_head")
	a.key(0.0, Vector3.ZERO, 0.0)
	a.key(2.0, Vector3(0.0, 0.0, 2.0), 0.0)
	a.key(3.0, Vector3(0.0, 0.0, 4.0), 0.0, Vector3.ZERO, "linear", 1.0)
	a.evaluate(2.3)
	var h1: Vector3 = a.bone_world("Head")
	a.evaluate(0.7)
	a.evaluate(2.3)
	_check(h1.distance_to(a.bone_world("Head")) < 1e-4, "evaluate(s) is a pure function of s")
	a.evaluate(2.5)
	_check(absf(a.position.y - 1.0) < 1e-4 and absf(a.position.z - 3.0) < 1e-4, "arc key: parabola apex 1.0 m at mid-span (y %.3f z %.3f)" % [a.position.y, a.position.z])
	var st: Dictionary = a.active_move(1.0)
	_check(st.get("move", "") == "jab" and absf(float(st["s"]) - (1.0 - 0.55 * 0.45)) < 1e-6, "strike starts so the impact lands on s_hit")
	# --- code-tier extras: flying kick is airborne, front flip turns over
	CineMoves.max_tier = 3
	var b: CineActor = _actor(12)
	b.key(0.0, Vector3(3.0, 0.0, 0.0), 0.0)
	b.move(0.0, "fight_idle")
	b.evaluate(0.0)
	var hips0: float = b.bone_world("Hips").y
	b.strike(2.0, "flying_kick")
	b.evaluate(2.0 - 0.55 + 0.375)     # middle of the air window [0.15, 0.6]
	_check(b.bone_world("Hips").y - hips0 > 0.5, "code flying kick lifts the body (%.2f m)" % (b.bone_world("Hips").y - hips0))
	var c: CineActor = _actor(13)
	c.key(0.0, Vector3(-3.0, 0.0, 0.0), 0.0)
	c.strike(2.0, "front_flip")
	var mv_c: Dictionary = c.active_move(2.0)
	c.evaluate(2.0)
	var up: float = c.spin.global_transform.basis.y.normalized().dot(Vector3.UP)
	_check(up < 0.0, "code front flip is upside down at the apex (up·UP %.2f)" % up)
	c.evaluate(float(mv_c["s"]) + float(mv_c["dur"]) + 0.01)
	_check(c.spin.global_transform.basis.y.normalized().dot(Vector3.UP) > 0.99, "upright again after the flip")
	CineMoves.max_tier = 0
	# --- look-at, expression, visibility
	var d: CineActor = _actor(14)
	d.move(0.0, "fight_idle")
	d.key(0.0, Vector3(0.0, 0.0, -6.0), 0.0)
	d.evaluate(0.5)
	var fwd0: Vector3 = (d.bone_world("Head") - d.bone_world("Neck")).normalized()
	var head_basis0: Basis = d.sk.global_transform.basis * CharacterBuilder._bone_global_now(d.sk, d.sk.find_bone("Head")).basis
	d.look(1.0, 5.0, Vector3(-3.0, 1.5, -6.0))   # to the actor's left (actor faces -Z)
	d.evaluate(3.0)
	var head_basis1: Basis = d.sk.global_transform.basis * CharacterBuilder._bone_global_now(d.sk, d.sk.find_bone("Head")).basis
	var turn: float = rad_to_deg(head_basis0.get_rotation_quaternion().angle_to(head_basis1.get_rotation_quaternion()))
	_check(turn > 25.0 and turn < 75.0, "look-at turns the head 25-75° (%.0f°)" % turn)
	_check(fwd0.length() > 0.5, "neck/head bones found")
	d.expr(4.0, "angry")
	d.evaluate(4.5)
	if d.face_mat:
		_check(d.face_mat.uv1_offset.is_equal_approx(PS2Head.cell_offset("angry")), "expression cell switches")
	d.show_at(6.0, false)
	d.evaluate(6.5)
	_check(not d.visible, "show_at hides the actor")
	d.evaluate(5.0)
	_check(d.visible, "and is visible before that")
	# --- cost
	var t0: int = Time.get_ticks_usec()
	for i: int in 60:
		a.evaluate(float(i) * 0.05)
	var ms: float = float(Time.get_ticks_usec() - t0) / 60000.0
	_check(ms < 2.5, "evaluate %.2f ms < 2.5" % ms)
	if fails.is_empty():
		print("✅ SUCCESS: CINE ACTOR (tiers, alignment, pure evaluation, arcs, extras, look, cells)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
```

- [ ] **Step 2: Run it and see it fail**

Run: `godot --headless --path . --script tests/test_cine_actor.gd > /tmp/t2.log 2>&1; grep -E "SUCCESS|FAILED|Identifier" /tmp/t2.log`

Expected: `Identifier "CineMoves" not declared`.

- [ ] **Step 3: Write `scripts/cine/CineMoves.gd`**

The move table holds the initial values from the 2026-10-23 probe (spec section 5). The Mixamo `hit` values are the reach peaks of the striking hand or foot. The probe confirmed that the jab, cross, roundhouse, MMA and flying-kick strikes travel along the clip's +Z (within 7°), so Mixamo `yaw` is 0. Task 7 tunes the windows by eye. Resolution and mapping are complete code.

```gdscript
# File: res://scripts/cine/CineMoves.gd
# Logical moves for cinematics (spec A1-D4, A1-D22). A move has a fixed STORY duration and an impact fraction hit_u; at run
# time it resolves to the best available tier (Mixamo -> UAL -> native body clip -> code pose). Each tier's clip window
# [from, hit, to] is mapped piecewise-linearly onto the move so its impact frame lands at story time start + hit_u·dur:
# blocking, timing and the beat sheet are the same whichever tier plays. Entry extras ("arc" metres, "spin" degrees per axis)
# add the airborne height / rotation a tier lacks over the move's "air" window; "add" layers an additive code pose; "yaw"
# turns the actor while that entry plays. to = -1 -> full clip; from > to -> backwards.
class_name CineMoves
extends RefCounted

const TIERS: Array[String] = ["mixamo", "ual", "native", "code"]
## Test hook: best tier allowed (index into TIERS). If no entry passes the cap, the last available entry is used.
static var max_tier: int = 0

const MOVES: Dictionary = {
	"fight_idle": {"dur": 3.3, "loop": true, "src": [
		{"t": "mixamo", "a": "Fighting_Idle", "from": 0.0, "to": 3.3}, {"t": "ual1", "a": "Idle"},
		{"t": "native", "a": "Idle"}, {"t": "code", "a": "stance"}]},
	"taunt": {"dur": 1.6, "src": [
		{"t": "mixamo", "a": "Taunt"}, {"t": "ual2", "a": "Idle_No"}, {"t": "native", "a": "Wave"}, {"t": "code", "a": "taunt"}]},
	"sprint": {"dur": 0.533, "loop": true, "src": [
		{"t": "mixamo", "a": "Sprint"}, {"t": "ual1", "a": "Sprint"}, {"t": "native", "a": "Run"}]},
	"jog": {"dur": 0.8, "loop": true, "src": [{"t": "ual1", "a": "Jog_Fwd"}, {"t": "native", "a": "Run"}]},
	"walk": {"dur": 1.0, "loop": true, "src": [{"t": "ual1", "a": "Walk"}, {"t": "native", "a": "Walk"}]},
	"flying_kick": {"dur": 1.0, "hit_u": 0.55, "air": [0.15, 0.6], "src": [
		{"t": "mixamo", "a": "Flying_Kick", "from": 0.0, "hit": 0.53, "to": 1.1},
		{"t": "code", "a": "flying_kick", "arc": 0.9}]},
	"jab": {"dur": 0.45, "hit_u": 0.55, "src": [
		{"t": "mixamo", "a": "Jab_Cross", "from": 0.15, "hit": 0.40, "to": 0.55},
		{"t": "ual1", "a": "Punch_Jab", "from": 0.0, "hit": 0.22, "to": 0.6},
		{"t": "native", "a": "Punch_Left", "from": 0.0, "hit": 0.35, "to": 0.83}]},
	"cross": {"dur": 0.5, "hit_u": 0.5, "src": [
		{"t": "mixamo", "a": "Jab_Cross", "from": 0.50, "hit": 0.67, "to": 0.95},
		{"t": "ual1", "a": "Punch_Cross", "from": 0.1, "hit": 0.3, "to": 0.7},
		{"t": "native", "a": "Punch_Right", "from": 0.0, "hit": 0.35, "to": 0.83}]},
	"hook": {"dur": 0.7, "hit_u": 0.55, "src": [
		{"t": "mixamo", "a": "Hook_Punch", "from": 0.6, "hit": 1.0, "to": 1.4},
		{"t": "ual2", "a": "Melee_Hook", "from": 0.0, "hit": 0.25, "to": 0.47},
		{"t": "native", "a": "Punch_Right", "from": 0.0, "hit": 0.35, "to": 0.83}]},
	"uppercut": {"dur": 0.8, "hit_u": 0.5, "src": [
		{"t": "mixamo", "a": "Uppercut", "from": 0.2, "hit": 0.53, "to": 0.95},
		{"t": "ual1", "a": "Punch_Cross", "from": 0.1, "hit": 0.3, "to": 0.7, "add": "uppercut"},
		{"t": "native", "a": "Punch_Left", "from": 0.0, "hit": 0.35, "to": 0.83, "add": "uppercut"}]},
	"roundhouse": {"dur": 1.0, "hit_u": 0.5, "src": [
		{"t": "mixamo", "a": "Roundhouse_Kick", "from": 0.6, "hit": 1.07, "to": 1.6},
		{"t": "native", "a": "Kick_Right", "from": 0.1, "hit": 0.45, "to": 0.93, "add": "spin_kick"},
		{"t": "code", "a": "spin_kick"}]},
	"hurricane_kick": {"dur": 1.2, "hit_u": 0.5, "air": [0.05, 0.95], "src": [
		{"t": "mixamo", "a": "Hurricane_Kick", "from": 0.1, "hit": 0.9, "to": 1.7, "arc": 0.35},
		{"t": "code", "a": "spin_kick", "arc": 0.7, "spin": Vector3(0.0, -540.0, 0.0)}]},
	"front_flip": {"dur": 1.2, "hit_u": 0.45, "air": [0.15, 0.85], "src": [
		{"t": "mixamo", "a": "Front_Flip", "from": 0.35, "hit": 0.85, "to": 1.55},
		{"t": "code", "a": "tuck", "arc": 1.4, "spin": Vector3(-360.0, 0.0, 0.0)}]},
	"dodge": {"dur": 0.8, "hit_u": 0.45, "src": [
		{"t": "mixamo", "a": "Dodging", "from": 0.0, "hit": 0.5, "to": 1.2}, {"t": "code", "a": "dodge_lean"}]},
	"block": {"dur": 0.8, "hit_u": 0.4, "src": [
		{"t": "mixamo", "a": "Block", "from": 0.1, "hit": 0.45, "to": 1.2},
		{"t": "ual2", "a": "Sword_Block", "from": 0.0, "hit": 0.2, "to": -1.0}, {"t": "code", "a": "block"}]},
	"knee_strike": {"dur": 0.9, "hit_u": 0.5, "air": [0.2, 0.6], "src": [
		{"t": "mixamo", "a": "Knee_Kick", "from": 0.2, "hit": 0.6, "to": 1.0, "arc": 0.25},
		{"t": "native", "a": "Kick_Left", "from": 0.1, "hit": 0.45, "to": 0.93, "add": "knee", "arc": 0.4},
		{"t": "code", "a": "knee", "arc": 0.4}]},
	"hit_head": {"dur": 0.6, "hit_u": 0.1, "src": [
		{"t": "mixamo", "a": "Head_Hit", "from": 0.0, "hit": 0.12, "to": 1.0},
		{"t": "ual1", "a": "Hit_Head", "from": 0.0, "hit": 0.06, "to": -1.0},
		{"t": "native", "a": "HitRecieve", "from": 0.0, "hit": 0.06, "to": -1.0}]},
	"hit_stomach": {"dur": 0.6, "hit_u": 0.1, "src": [
		{"t": "mixamo", "a": "Stomach_Hit", "from": 0.0, "hit": 0.1, "to": 1.0},
		{"t": "ual1", "a": "Hit_Chest", "from": 0.0, "hit": 0.06, "to": -1.0},
		{"t": "native", "a": "HitRecieve_2", "from": 0.0, "hit": 0.06, "to": -1.0}]},
	"launched_back": {"dur": 1.6, "hit_u": 0.05, "air": [0.05, 0.55], "src": [
		{"t": "mixamo", "a": "Flying_Back_Death", "from": 0.2, "hit": 0.3, "to": 2.0},
		{"t": "ual2", "a": "Hit_Knockback", "from": 0.0, "hit": 0.04, "to": -1.0, "arc": 0.8},
		{"t": "native", "a": "Death", "from": 0.0, "hit": 0.05, "to": -1.0, "arc": 0.8}]},
	"knocked_out": {"dur": 2.0, "hit_u": 0.05, "src": [
		{"t": "mixamo", "a": "Knocked_Out", "from": 0.6, "hit": 0.7, "to": 4.9},
		{"t": "ual1", "a": "Death01", "from": 0.0, "hit": 0.05, "to": -1.0},
		{"t": "native", "a": "Death", "from": 0.0, "hit": 0.05, "to": -1.0}]},
	"sweep_fall": {"dur": 1.4, "hit_u": 0.35, "src": [
		{"t": "mixamo", "a": "Sweep_Fall", "from": 0.5, "hit": 1.0, "to": 2.5},
		{"t": "native", "a": "Death", "from": 0.0, "hit": 0.2, "to": -1.0}]},
	"slip_fall": {"dur": 1.2, "hit_u": 0.3, "src": [
		{"t": "mixamo", "a": "Sweep_Fall", "from": 0.6, "hit": 1.0, "to": 2.5},
		{"t": "native", "a": "Death", "from": 0.0, "hit": 0.2, "to": -1.0}]},
	"lie": {"dur": 1.0, "loop": true, "src": [
		{"t": "mixamo", "a": "Knocked_Out", "from": 4.9, "to": 4.93},
		{"t": "ual1", "a": "Death01", "from": 1.24, "to": 1.25}, {"t": "native", "a": "Death", "from": 1.05, "to": 1.066}]},
	"get_up": {"dur": 2.0, "src": [
		{"t": "mixamo", "a": "Getting_Up", "from": 4.0, "to": 8.33},
		{"t": "ual2", "a": "LayToIdle"}, {"t": "native", "a": "Death", "from": 1.066, "to": 0.0}]},
	"victory": {"dur": 2.0, "src": [
		{"t": "mixamo", "a": "Victory", "from": 0.5, "to": 2.5}, {"t": "ual2", "a": "Yes"},
		{"t": "native", "a": "Wave"}, {"t": "code", "a": "victory"}]},
	"scissor_takedown": {"dur": 1.1, "hit_u": 0.6, "air": [0.1, 0.65], "src": [
		{"t": "code", "a": "scissor", "arc": 0.8, "spin": Vector3(0.0, 0.0, -80.0)}]},
}


static func has_move(move_name: String) -> bool:
	return MOVES.has(move_name)


static func is_strike(move_name: String) -> bool:
	return MOVES.has(move_name) and float((MOVES[move_name] as Dictionary).get("hit_u", -1.0)) >= 0.0


static func tier_index(t: String) -> int:
	match t:
		"mixamo":
			return 0
		"ual1", "ual2":
			return 1
		"native":
			return 2
	return 3


static func _entry_ok(e: Dictionary, bd: Dictionary) -> bool:
	match String(e["t"]):
		"code":
			return true
		"native":
			return bd.has("native") and (bd["native"]["anims"] as Dictionary).has(String(e["a"]))
	return CineRetarget.has_anim(String(e["t"]), String(e["a"]))


## The entry a move plays for this skeleton (bd = CineRetarget.bind()), flattened with the move's fields.
static func resolve(move_name: String, bd: Dictionary) -> Dictionary:
	if not MOVES.has(move_name):
		return {}
	var m: Dictionary = MOVES[move_name]
	var pick: Dictionary = {}
	var last_ok: Dictionary = {}
	for e: Dictionary in m["src"]:
		if not _entry_ok(e, bd):
			continue
		last_ok = e
		if pick.is_empty() and tier_index(String(e["t"])) >= max_tier:
			pick = e
	if pick.is_empty():
		pick = last_ok
	if pick.is_empty():
		return {}
	var r: Dictionary = {"move": move_name, "t": String(pick["t"]), "a": String(pick["a"]),
		"tier": TIERS[tier_index(String(pick["t"]))],
		"from": float(pick.get("from", 0.0)), "hit": float(pick.get("hit", -1.0)), "to": float(pick.get("to", -1.0)),
		"arc": float(pick.get("arc", 0.0)), "spin": pick.get("spin", Vector3.ZERO), "add": String(pick.get("add", "")),
		"yaw": float(pick.get("yaw", 0.0)), "hold_spin": bool(pick.get("hold_spin", false)),
		"dur": float(m["dur"]), "hit_u": float(m.get("hit_u", -1.0)), "loop": bool(m.get("loop", false)),
		"air": m.get("air", []), "root_y": String(m.get("root_y", "keep"))}
	if r["t"] != "code" and float(r["to"]) < 0.0:
		r["to"] = CineRetarget.anim_length(String(r["t"]), String(r["a"]), bd)
	return r


## Clip seconds for story offset x (story seconds since the move started) of a resolved move played over dur story seconds.
## Strikes map [from, hit] onto [0, hit_u·dur] and [hit, to] onto [hit_u·dur, dur]; loops play at natural speed inside
## [from, to]; from > to plays backwards.
static func clip_time(res: Dictionary, x: float, dur: float, loop: bool) -> float:
	var a: float = res["from"]
	var b: float = res["to"]
	if loop:
		var span: float = absf(b - a)
		var dir: float = 1.0 if b >= a else -1.0
		return a + dir * (fposmod(x, span) if span > 0.0 else 0.0)
	var u: float = clampf(x / dur, 0.0, 1.0) if dur > 0.0 else 1.0
	var h: float = res["hit"]
	var hu: float = res["hit_u"]
	if h >= 0.0 and hu > 0.0 and hu < 1.0:
		if u <= hu:
			return lerpf(a, h, u / hu)
		return lerpf(h, b, (u - hu) / (1.0 - hu))
	return lerpf(a, b, u)


static func _sm(u: float) -> float:
	var x: float = clampf(u, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## Code poses {CharacterBuilder joint: Euler (character frame, rad)} applied with CharacterBuilder._apply_bone_pose on the
## neutral standing base; u = progress 0..1 through the move (loops: phase). flying_kick, spin_kick and scissor are the
## prototype's (git show ec72795:scripts/cine/CineBrawl.gd) – retune the leg angles on the neutral base by eye in Task 7.
static func code_pose(pose: String, u: float) -> Dictionary:
	match pose:
		"stance":
			var br: float = sin(u * TAU) * 0.03
			return {"thigh_l": Vector3(0.25, 0.0, 0.08), "knee_l": Vector3(-0.45, 0.0, 0.0), "thigh_r": Vector3(-0.1, 0.0, -0.08),
				"knee_r": Vector3(-0.35, 0.0, 0.0), "torso": Vector3(0.12 + br, 0.35, 0.0), "head": Vector3(-0.08, -0.3, 0.0),
				"shoulder_l": Vector3(1.0, 0.0, -0.35), "elbow_l": Vector3(1.9, 0.0, 0.0),
				"shoulder_r": Vector3(0.8, 0.0, 0.4), "elbow_r": Vector3(2.1, 0.0, 0.0)}
		"taunt":
			var w: float = sin(u * TAU * 2.0)
			return {"torso": Vector3(-0.1, 0.0, 0.0), "shoulder_r": Vector3(1.4 + 0.3 * w, 0.0, 0.5), "elbow_r": Vector3(1.6, 0.0, 0.0),
				"shoulder_l": Vector3(0.9, 0.0, -0.4), "elbow_l": Vector3(2.0, 0.0, 0.0), "head": Vector3(-0.15, 0.0, 0.1 * w)}
		"flying_kick":
			var e: float = _sm(u / 0.86)
			return {"thigh_r": Vector3(lerpf(1.05, 1.62, e), 0.0, -0.08), "knee_r": Vector3(lerpf(-1.9, -0.02, e), 0.0, 0.0),
				"foot_r": Vector3(lerpf(0.4, -0.25, e), 0.0, 0.0), "thigh_l": Vector3(lerpf(0.9, 0.75, e), 0.0, 0.18),
				"knee_l": Vector3(-2.1, 0.0, 0.0), "torso": Vector3(lerpf(-0.1, 0.38, e), lerpf(0.0, 0.25, e), 0.0),
				"head": Vector3(lerpf(0.0, -0.3, e), 0.0, 0.0),
				"shoulder_l": Vector3(lerpf(0.9, 0.35, e), 0.0, lerpf(0.0, -0.95, e)), "elbow_l": Vector3(lerpf(1.6, 0.7, e), 0.0, 0.0),
				"shoulder_r": Vector3(lerpf(0.9, -0.55, e), 0.0, lerpf(0.0, 0.75, e)), "elbow_r": Vector3(lerpf(1.6, 0.5, e), 0.0, 0.0)}
		"spin_kick":
			var e2: float = _sm(u / 0.8)
			return {"thigh_r": Vector3(lerpf(0.9, 1.5, e2), 0.0, lerpf(-0.2, -0.95, e2)), "knee_r": Vector3(lerpf(-1.6, -0.05, e2), 0.0, 0.0),
				"torso": Vector3(lerpf(0.0, 0.32, e2), 0.0, lerpf(0.0, 0.42, e2)), "head": Vector3(0.0, 0.0, lerpf(0.0, -0.35, e2)),
				"shoulder_l": Vector3(0.6, 0.0, lerpf(0.3, -0.8, e2)), "elbow_l": Vector3(1.4, 0.0, 0.0),
				"shoulder_r": Vector3(0.3, 0.0, lerpf(-0.3, 0.9, e2)), "elbow_r": Vector3(1.0, 0.0, 0.0)}
		"scissor":
			var open_k: float = _sm(u / 0.4)
			var close_k: float = _sm((u - 0.42) / 0.3)
			var spread: float = open_k * (1.0 - 0.75 * close_k)
			return {"thigh_r": Vector3(0.2 + 1.35 * spread, 0.0, -0.1), "knee_r": Vector3(-0.15, 0.0, 0.0),
				"thigh_l": Vector3(0.2 - 0.95 * spread, 0.0, 0.1), "knee_l": Vector3(-0.35 - 0.4 * close_k, 0.0, 0.0),
				"torso": Vector3(-0.15, 0.0, 0.0), "head": Vector3(0.0, -0.4, 0.0),
				"shoulder_l": Vector3(1.6, 0.0, -0.4), "elbow_l": Vector3(0.3, 0.0, 0.0),
				"shoulder_r": Vector3(1.9, 0.0, 0.5), "elbow_r": Vector3(0.25, 0.0, 0.0)}
		"tuck":
			var k: float = sin(clampf(u, 0.0, 1.0) * PI)
			return {"thigh_l": Vector3(1.9 * k, 0.0, 0.1), "thigh_r": Vector3(1.9 * k, 0.0, -0.1), "knee_l": Vector3(-2.2 * k, 0.0, 0.0),
				"knee_r": Vector3(-2.2 * k, 0.0, 0.0), "torso": Vector3(0.5 * k, 0.0, 0.0), "head": Vector3(0.4 * k, 0.0, 0.0),
				"shoulder_l": Vector3(1.2 * k, 0.0, -0.2), "shoulder_r": Vector3(1.2 * k, 0.0, 0.2),
				"elbow_l": Vector3(1.4 * k, 0.0, 0.0), "elbow_r": Vector3(1.4 * k, 0.0, 0.0)}
		"dodge_lean":
			var k2: float = sin(clampf(u, 0.0, 1.0) * PI)
			return {"torso": Vector3(-0.45 * k2, 0.0, 0.25 * k2), "head": Vector3(-0.2 * k2, 0.0, 0.0),
				"knee_l": Vector3(-0.5 * k2, 0.0, 0.0), "knee_r": Vector3(-0.5 * k2, 0.0, 0.0),
				"shoulder_l": Vector3(1.1, 0.0, -0.4), "elbow_l": Vector3(2.0, 0.0, 0.0), "shoulder_r": Vector3(1.1, 0.0, 0.4), "elbow_r": Vector3(2.0, 0.0, 0.0)}
		"block":
			var k3: float = _sm(u / 0.3) * (1.0 - _sm((u - 0.7) / 0.3))
			return {"shoulder_l": Vector3(1.5 * k3 + 0.6, 0.0, -0.2), "elbow_l": Vector3(2.2, 0.0, 0.0),
				"shoulder_r": Vector3(1.5 * k3 + 0.6, 0.0, 0.2), "elbow_r": Vector3(2.2, 0.0, 0.0),
				"torso": Vector3(-0.15 * k3, 0.0, 0.0), "head": Vector3(0.2 * k3, 0.0, 0.0)}
		"knee":
			var k4: float = sin(clampf(u, 0.0, 1.0) * PI)
			return {"thigh_r": Vector3(1.7 * k4, 0.0, 0.0), "knee_r": Vector3(-2.2 * k4, 0.0, 0.0),
				"torso": Vector3(-0.25 * k4, 0.0, 0.0), "shoulder_l": Vector3(1.3, 0.0, -0.3), "shoulder_r": Vector3(1.3, 0.0, 0.3),
				"elbow_l": Vector3(1.5, 0.0, 0.0), "elbow_r": Vector3(1.5, 0.0, 0.0)}
		"uppercut":   # additive on a punch clip: drive the fist upward through the impact
			var k5: float = sin(clampf(u, 0.0, 1.0) * PI)
			return {"shoulder_l": Vector3(0.9 * k5, 0.0, 0.0), "elbow_l": Vector3(0.6 * k5, 0.0, 0.0), "torso": Vector3(-0.2 * k5, 0.0, 0.15 * k5)}
		"victory":
			var k6: float = _sm(u / 0.25)
			return {"shoulder_r": Vector3(2.9 * k6, 0.0, 0.3), "elbow_r": Vector3(0.3, 0.0, 0.0),
				"shoulder_l": Vector3(0.3, 0.0, -0.3), "torso": Vector3(-0.1 * k6, 0.0, 0.0), "head": Vector3(-0.25 * k6, 0.0, 0.0)}
	return {}
```

- [ ] **Step 4: Rewrite `scripts/cine/CineActor.gd`**

Keep the prototype's structure: `setup`, `key`, `override`, `expr`, `_eval_transform`, `ease_u`, `_add_pose`, `_eval_expr` and `bone_world` stay the same. Replace `clip()` with `move()`/`strike()` and add look-at, visibility and extras. Complete code:

```gdscript
# File: res://scripts/cine/CineActor.gd
# One cinematic actor (spec A1-D21): a real game character (CharacterBuilder rigged body, animate=false) driven purely by
# STORY time s, so any frame can be evaluated in any order:
#   • move / strike: logical moves (CineMoves) resolved to the best tier, crossfaded; strike places the move so its impact
#     frame lands on s_hit; code tiers and "add" layers go on top through CharacterBuilder._apply_bone_pose / _char_rot_local;
#   • key: ground position + yaw (accumulated, may exceed a turn) + spin about the hip-height pivot, per-segment easing and
#     parabolic "arc"; the active move's extras (arc, spin, yaw) are added over its air window;
#   • override: timeline poses (abs / add); look: head + neck turn toward a node or a point; expr: PS2 face cell; show_at.
class_name CineActor
extends Node3D

const PIVOT_Y: float = 0.95
const LOOK_YAW_MAX: float = 1.22     # 70°
const LOOK_PITCH_MAX: float = 0.52   # 30°
const LOOK_FADE: float = 0.25

var body: Node3D
var sk: Skeleton3D
var bd: Dictionary
var spin: Node3D
var face_mat: StandardMaterial3D
var display_name: String = ""
var moves: Array[Dictionary] = []      # {s, dur, fade, loop, res}
var overrides: Array[Dictionary] = []
var keys: Array[Dictionary] = []
var exprs: Array[Dictionary] = []
var looks: Array[Dictionary] = []
var shows: Array[Dictionary] = []
var last_s: float = 0.0
var _base_pose: Dictionary = {}


## Build the character (CharacterBuilder.build opts; always rigged, animate=false so no animator writes the bones).
func setup(opts: Dictionary) -> void:
	var o: Dictionary = opts.duplicate()
	o["rigged"] = true
	o["animate"] = false
	spin = Node3D.new()
	spin.name = "Spin"
	spin.position = Vector3(0.0, PIVOT_Y, 0.0)
	add_child(spin)
	body = CharacterBuilder.build(o)
	body.position = Vector3(0.0, -PIVOT_Y, 0.0)
	spin.add_child(body)
	sk = body.get_meta("skeleton") as Skeleton3D
	var ap: AnimationPlayer = body.get_node("Model").find_child("AnimationPlayer", true, false) as AnimationPlayer
	bd = CineRetarget.bind(sk, ap)
	# neutral standing base as a full pose (code tier and "no move" pose)
	var nb: Dictionary = CharacterBuilder._base_of(sk)
	var rot: Dictionary = {}
	var pos: Dictionary = {}
	for b: int in sk.get_bone_count():
		var l: Transform3D = nb["local"][b] if not nb.is_empty() else sk.get_bone_rest(b)
		rot[b] = l.basis.get_rotation_quaternion()
		pos[b] = l.origin
	_base_pose = {"rot": rot, "pos": pos}
	# own face material (the PS2 face material is shared per skin tone)
	var face: MeshInstance3D = CharacterBuilder.get_pivot(body, "face_mesh") as MeshInstance3D
	if face and face.material_override is StandardMaterial3D:
		face_mat = (face.material_override as StandardMaterial3D).duplicate()
		face.material_override = face_mat


# ---------------------------------------------------------------------------
# Script
# ---------------------------------------------------------------------------
## Start move_name at story time s. opts: dur (story s, default the move's), fade (crossfade from the previous move), loop.
func move(s: float, move_name: String, opts: Dictionary = {}) -> Dictionary:
	var res: Dictionary = CineMoves.resolve(move_name, bd)
	if res.is_empty():
		push_warning("CineActor %s: unknown move %s" % [name, move_name])
		return {}
	moves.append({"s": s, "dur": float(opts.get("dur", res["dur"])), "fade": float(opts.get("fade", 0.12)),
		"loop": bool(opts.get("loop", res["loop"])), "res": res, "move": move_name})
	moves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) < float(b["s"]))
	return res


## Start move_name so its impact frame lands on story time s_hit.
func strike(s_hit: float, move_name: String, opts: Dictionary = {}) -> Dictionary:
	var res: Dictionary = CineMoves.resolve(move_name, bd)
	if res.is_empty():
		push_warning("CineActor %s: unknown move %s" % [name, move_name])
		return {}
	var dur: float = float(opts.get("dur", res["dur"]))
	return move(s_hit - maxf(float(res["hit_u"]), 0.0) * dur, move_name, opts)


## Position / yaw at s. mode: easing of the segment ENDING at this key; arc: extra parabolic height (m) of that segment.
func key(s: float, pos: Vector3, yaw: float, spin_euler: Vector3 = Vector3.ZERO, mode: String = "smooth", arc: float = 0.0) -> void:
	keys.append({"s": s, "pos": pos, "yaw": yaw, "spin": spin_euler, "mode": mode, "arc": arc})
	keys.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) < float(b["s"]))


func override(s0: float, s1: float, pose: Callable, fade_in: float = 0.08, fade_out: float = 0.12, mode: String = "abs") -> void:
	overrides.append({"s0": s0, "s1": s1, "pose": pose, "fi": fade_in, "fo": fade_out, "mode": mode})


func expr(s: float, cell: String) -> void:
	exprs.append({"s": s, "e": cell})
	exprs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) < float(b["s"]))


## Turn head and neck toward target (Node3D, or a Vector3 in the parent's space) during [s0, s1].
func look(s0: float, s1: float, target: Variant) -> void:
	looks.append({"s0": s0, "s1": s1, "t": target})


func show_at(s: float, on: bool) -> void:
	shows.append({"s": s, "v": on})
	shows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) < float(b["s"]))


## The move cue playing at s ({} before the first one).
func active_move(s: float) -> Dictionary:
	var cur: Dictionary = {}
	for c: Dictionary in moves:
		if float(c["s"]) <= s:
			cur = c
	return cur


# ---------------------------------------------------------------------------
# Evaluation at story time s
# ---------------------------------------------------------------------------
func evaluate(s: float) -> void:
	last_s = s
	var vis: bool = true
	for x: Dictionary in shows:
		if float(x["s"]) <= s:
			vis = bool(x["v"])
	visible = vis
	_eval_transform(s)
	_eval_pose(s)
	_eval_look(s)
	_eval_expr(s)


func _eval_transform(s: float) -> void:
	if not keys.is_empty():
		var k0: Dictionary = keys[0]
		var k1: Dictionary = keys[0]
		for i: int in keys.size():
			if float(keys[i]["s"]) <= s:
				k0 = keys[i]
				k1 = keys[mini(i + 1, keys.size() - 1)]
		if s < float(keys[0]["s"]):
			k1 = k0
		var u: float = 0.0
		var span: float = float(k1["s"]) - float(k0["s"])
		if span > 0.0001:
			u = clampf((s - float(k0["s"])) / span, 0.0, 1.0)
		var e: float = ease_u(u, String(k1["mode"]))
		var p: Vector3 = (k0["pos"] as Vector3).lerp(k1["pos"], e)
		var arc: float = float(k1["arc"])
		if arc != 0.0:
			p = (k0["pos"] as Vector3).lerp(k1["pos"], u)
			p.y += 4.0 * arc * u * (1.0 - u)
		position = p
		rotation.y = lerpf(float(k0["yaw"]), float(k1["yaw"]), e)
		spin.rotation = (k0["spin"] as Vector3).lerp(k1["spin"], e)
	# extras of the move playing now (A1-D4)
	var c: Dictionary = active_move(s)
	if c.is_empty():
		return
	var res: Dictionary = c["res"]
	rotation.y += deg_to_rad(float(res["yaw"]))
	var air: Array = res["air"]
	if air.size() < 2:
		return
	var uu: float = (s - float(c["s"])) / maxf(float(c["dur"]), 0.0001)
	var u0: float = air[0]
	var u1: float = air[1]
	var spin_deg: Vector3 = res["spin"]
	if uu >= u0 and uu <= u1:
		var a: float = (uu - u0) / maxf(u1 - u0, 0.0001)
		position.y += 4.0 * float(res["arc"]) * a * (1.0 - a)
		spin.rotation += spin_deg * (PI / 180.0) * (a * a * (3.0 - 2.0 * a))
	elif uu > u1 and uu <= 1.0 and absf(spin_deg.x) + absf(spin_deg.y) + absf(spin_deg.z) < 300.0:
		var back: float = (uu - u1) / maxf(1.0 - u1, 0.0001)
		var keep: float = 1.0 if bool(res["hold_spin"]) else 1.0 - back * back * (3.0 - 2.0 * back)
		spin.rotation += spin_deg * (PI / 180.0) * keep


static func ease_u(u: float, mode: String) -> float:
	match mode:
		"linear":
			return u
		"in":
			return u * u
		"out":
			return 1.0 - (1.0 - u) * (1.0 - u)
		"step":
			return 0.0 if u < 1.0 else 1.0
	return u * u * (3.0 - 2.0 * u)


## {"pose": local pose, "code": code pose or {}, "add": additive code pose or {}} of one move cue at s.
func _cue_pose(c: Dictionary, s: float) -> Dictionary:
	var res: Dictionary = c["res"]
	var x: float = s - float(c["s"])
	var dur: float = c["dur"]
	var u: float = clampf(x / dur, 0.0, 1.0) if dur > 0.0 else 1.0
	var out: Dictionary = {"pose": _base_pose, "code": {}, "add": {}}
	if String(res["t"]) == "code":
		out["code"] = CineMoves.code_pose(String(res["a"]), fposmod(x / dur, 1.0) if bool(c["loop"]) else u)
	else:
		var t: float = CineMoves.clip_time(res, x, dur, bool(c["loop"]))
		if String(res["t"]) == "native":
			out["pose"] = CineRetarget.sample_native(bd, String(res["a"]), t)
		else:
			out["pose"] = CineRetarget.sample(bd, String(res["t"]), String(res["a"]), t, false,
				{"xz": true, "y": String(res["root_y"]) == "strip", "ref": float(res["from"])})
	if String(res["add"]) != "":
		out["add"] = CineMoves.code_pose(String(res["add"]), u)
	return out


func _eval_pose(s: float) -> void:
	if moves.is_empty():
		CineRetarget.apply(sk, bd, _base_pose)
		return
	var i: int = 0
	for j: int in moves.size():
		if float(moves[j]["s"]) <= s:
			i = j
	var cur: Dictionary = _cue_pose(moves[i], s)
	var prev: Dictionary = {}
	var w: float = 1.0
	var dt: float = s - float(moves[i]["s"])
	var fade: float = moves[i]["fade"]
	if i > 0 and dt >= 0.0 and dt < fade and fade > 0.0:
		prev = _cue_pose(moves[i - 1], s)
		var x: float = clampf(dt / fade, 0.0, 1.0)
		w = x * x * (3.0 - 2.0 * x)
	var pose: Dictionary = cur["pose"] if prev.is_empty() else CineRetarget.blend(bd, prev["pose"], cur["pose"], w)
	CineRetarget.apply(sk, bd, pose)
	if not prev.is_empty() and not (prev["code"] as Dictionary).is_empty():
		CharacterBuilder._apply_bone_pose(sk, prev["code"], 1.0 - w)
	if not (cur["code"] as Dictionary).is_empty():
		CharacterBuilder._apply_bone_pose(sk, cur["code"], w)
	if not prev.is_empty():
		_add_pose(prev["add"], 1.0 - w)
	_add_pose(cur["add"], w)
	for o: Dictionary in overrides:
		var s0: float = o["s0"]
		var s1: float = o["s1"]
		var fi: float = o["fi"]
		var fo: float = o["fo"]
		if s < s0 - fi or s > s1 + fo:
			continue
		var w2: float = 1.0
		if s < s0 and fi > 0.0:
			w2 = (s - (s0 - fi)) / fi
		elif s > s1 and fo > 0.0:
			w2 = 1.0 - (s - s1) / fo
		w2 = clampf(w2, 0.0, 1.0)
		w2 = w2 * w2 * (3.0 - 2.0 * w2)
		var uo: float = clampf((s - s0) / maxf(s1 - s0, 0.0001), 0.0, 1.0)
		var cpose: Dictionary = (o["pose"] as Callable).call(uo)
		if String(o["mode"]) == "add":
			_add_pose(cpose, w2)
		else:
			CharacterBuilder._apply_bone_pose(sk, cpose, w2)


## Additive rotation (character-frame Euler × w) on the current pose – same operation as RigAnimator._add_rot.
func _add_pose(cpose: Dictionary, w: float) -> void:
	if cpose.is_empty() or w <= 0.0:
		return
	for k: String in cpose.keys():
		if not CharacterBuilder.BONE_OF.has(k):
			continue
		var b: int = sk.find_bone(String(CharacterBuilder.BONE_OF[k]))
		if b < 0:
			continue
		var r: Basis = CharacterBuilder._char_rot_local(sk, b, (cpose[k] as Vector3) * w)
		sk.set_bone_pose_rotation(b, (r * Basis(sk.get_bone_pose_rotation(b))).get_rotation_quaternion())
	CharacterBuilder._mark_bone_poses_dirty(sk)


func _eval_look(s: float) -> void:
	for l: Dictionary in looks:
		var s0: float = l["s0"]
		var s1: float = l["s1"]
		if s < s0 - LOOK_FADE or s > s1 + LOOK_FADE:
			continue
		var w: float = clampf(minf((s - (s0 - LOOK_FADE)) / LOOK_FADE, ((s1 + LOOK_FADE) - s) / LOOK_FADE), 0.0, 1.0)
		var tp: Vector3
		if l["t"] is Node3D:
			var n: Node3D = l["t"]
			tp = (n as CineActor).bone_world("Head") if n is CineActor else n.global_position + Vector3(0.0, 1.5, 0.0)
		else:
			var parent3d: Node3D = get_parent() as Node3D
			tp = parent3d.to_global(l["t"]) if parent3d else (l["t"] as Vector3)
		var head: Vector3 = bone_world("Head")
		var d: Vector3 = tp - head
		var fwd: Vector3 = -global_transform.basis.z   # characters face -Z
		var yaw: float = clampf(Vector2(fwd.x, fwd.z).angle_to(Vector2(d.x, d.z)) * -1.0, -LOOK_YAW_MAX, LOOK_YAW_MAX)
		var pitch: float = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -LOOK_PITCH_MAX, LOOK_PITCH_MAX)
		_add_pose({"neck": Vector3(-pitch * 0.4, yaw * 0.4, 0.0), "head": Vector3(-pitch * 0.6, yaw * 0.6, 0.0)}, w)


func _eval_expr(s: float) -> void:
	if face_mat == null or exprs.is_empty():
		return
	var e: String = "open"
	for x: Dictionary in exprs:
		if float(x["s"]) <= s:
			e = String(x["e"])
	face_mat.uv1_offset = PS2Head.cell_offset(e if e in PS2Head.CELLS else "open")


## Current global position of a bone (after evaluate) – for FX at hands / feet and contact checks.
func bone_world(bone: String) -> Vector3:
	var b: int = sk.find_bone(bone)
	if b < 0:
		return global_position
	return sk.global_transform * CharacterBuilder._bone_global_now(sk, b).origin
```

**Sign checks.** If the look-at turns the wrong way, flip the sign of `yaw` and/or `pitch` in `_eval_look` until the test passes. `CharacterBuilder._char_rot_local` already mirrors x/z for `MODEL_YAW`. Do not rotate the model to compensate.

- [ ] **Step 5: Import and run the test until it passes**

Run:

```bash
godot --headless --import --path . > /tmp/a1_imp.log 2>&1; grep -c "CineMoves" .godot/global_script_class_cache.cfg
git diff --name-only -- '*.import' | xargs -r git checkout --
godot --headless --path . --script tests/test_cine_actor.gd > /tmp/t2.log 2>&1; grep -E "SUCCESS|FAILED|✗" /tmp/t2.log
```

Expected: `✅ SUCCESS: CINE ACTOR (…)`.

**Initial-window fixes.** If a UAL or native window fails the alignment check (for example `to = -1` resolving below `hit`), fix the window in `MOVES`. Use real clip lengths from `CineRetarget.anim_length`.

- [ ] **Step 6: Full regression, then commit**

```bash
git add scripts/cine/CineMoves.gd scripts/cine/CineMoves.gd.uid scripts/cine/CineActor.gd tests/test_cine_actor.gd tests/test_cine_actor.gd.uid
git commit -m "feat(cine): logical moves with Mixamo/UAL/native/code tiers aligned on the impact frame, story-time actor with move extras, look-at and visibility cues

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Cinematic clock, timeline model, validator and beat sheets  [effort: high]

**Files:**
- Create:
  - `scripts/cine/CineClock.gd`, `scripts/cine/CineTimeline.gd`;
  - `tools/cine_beats.gd`;
  - `tests/support/cine_test_timeline.gd`;
  - `tests/test_cine_clock.gd`, `tests/test_cine_timeline.gd`;
  - `scripts/cine/timelines/.gitkeep`.

**Interfaces:**
- Consumes: `CineMoves.has_move/is_strike/MOVES` (Task 2).
- Produces (`class_name CineClock`):
  - `PRESETS`, `TOL`, `TAIL_MIN`, `TAIL_MAX`;
  - `var length, story_end, base, tail_rule, ramps`;
  - `add(name, s, preset := "medium", over := {})`, `build()`;
  - `story_at(r) -> float`, `speed_at(r) -> float`, `real_at(s) -> float`, `real_duration() -> float`;
  - `ramp(name) -> Dictionary`, which holds `s, s0, s1, r0, r_hit, r1, k, freeze, …`;
  - `validate() -> PackedStringArray`;
  - `beat_rows() -> Array[Dictionary]`.
- Produces (`class_name CineTimeline`):
  - Constants: `TIMELINE_DIR`, `RIGS`, `FX_KINDS`, `TRANSLATED_SPEAKERS`.
  - Fields: `slot, length, story_end, music_slot, mood, fade_in, fade_out, letterbox, stage, clock, actors, cues, shots, subs, sfx, fx, props`.
  - Overridable `build()`.
  - Registry: `static slots() -> PackedStringArray`, `static load_slot(slot) -> CineTimeline` (`null` if missing).
  - Authoring:
    - `actor(id, opts, speaker := "", color := Color.WHITE)`;
    - `hit(name, s, preset, what, over := {})`;
    - `move(actor_id, s, move_name, opts := {})`;
    - `strike(actor_id, at: Variant, move_name, opts := {})`;
    - `key(actor_id, s, pos, yaw_deg, opts := {})`;
    - `expr`, `look`, `show`;
    - `shot(id, s, rig, what, params := {})`;
    - `sub(r, dur, speaker, text, tr := "")`;
    - `sfx_at(at, cue, db := 0.0)`;
    - `fx_at(at, kind, where, params := {})`;
    - `prop(id, kind, pos, yaw_deg := 0.0, opts := {})`.
  - Utilities: `static face(from, to) -> float` (degrees), `story_time(at) -> float`, `speaker_name(id) -> String`, `validate() -> PackedStringArray`, `beat_sheet() -> String`.

- [ ] **Step 1: Write the failing clock test `tests/test_cine_clock.gd`**

This exact file passes against the `CineClock` below. Both were verified together on 2026-10-23.

```gdscript
# File: res://tests/test_cine_clock.gd
# Headless test of CineClock (analytic slow-motion ramps) and its validator: closed-form spans, monotonic story time,
# real <-> story round trips, freezes, the seg_d1_brawl ramp set landing on exactly 25.000 s, validator failures.
# Run:  godot --headless --path . --script tests/test_cine_clock.gd
extends SceneTree

var fails: Array[String] = []


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _d1_clock() -> CineClock:
	var c := CineClock.new()
	c.length = 25.0
	c.story_end = 16.49325
	c.add("H1", 2.40, "heavy")
	c.add("A1", 3.70, "accent")
	c.add("H2", 4.25, "light")
	c.add("H3", 4.70, "light")
	c.add("H4", 5.30, "medium")
	c.add("A2", 6.60, "accent")
	c.add("H5", 7.60, "heavy")
	c.add("H6", 8.40, "medium")
	c.add("A3", 10.30, "accent")
	c.add("H7", 11.40, "medium")
	c.add("H8", 12.525, "finisher")
	return c


func _initialize() -> void:
	print("--- TEST CINE CLOCK ---")
	# 1. one heavy ramp: exact spans
	var c := CineClock.new()
	c.length = 10.0
	c.add("X", 5.0, "heavy")
	c.build()
	var p: Dictionary = c.ramp("X")
	_check(is_equal_approx(float(p["s0"]), 5.0 - 0.16875), "heavy pre span 0.16875 (got %.5f)" % (5.0 - float(p["s0"])))
	_check(is_equal_approx(float(p["s1"]), 5.0 + 0.3875), "heavy post span 0.3875")
	_check(absf(float(p["r_hit"]) - (float(p["r0"]) + 0.45)) < 1e-9, "impact = ramp start + ri + hp")
	_check(absf(c.real_at(5.0) - float(p["r_hit"])) < 1e-6, "real_at(impact) = freeze start")
	_check(absf(c.story_at(float(p["r_hit"]) + 0.09) - 5.0) < 1e-9, "story frozen inside the freeze")
	_check(c.speed_at(float(p["r_hit"]) + 0.09) == 0.0, "speed 0 in the freeze")
	_check(absf(c.speed_at(float(p["r_hit"]) + 0.5) - 0.25) < 1e-9, "speed k in the post hold")
	_check(absf(c.speed_at(1.0) - 1.0) < 1e-9, "speed 1 before the ramp")
	# extra real time of a heavy ramp = 1.17375 s -> story 8.82625 lasts 10 s
	c.story_end = 10.0 - 1.17375
	_check(absf(c.real_duration() - 10.0) < 1e-6, "real duration = story_end + extra (got %.6f)" % c.real_duration())
	# 2. monotonic story time + round trip over the d1 ramp set
	var d1: CineClock = _d1_clock()
	var errs: PackedStringArray = d1.validate()
	_check(errs.is_empty(), "d1 ramp set valid: %s" % str(errs))
	_check(absf(d1.real_duration() - 25.0) < 0.0005, "d1 real duration 25.000 (got %.5f)" % d1.real_duration())
	_check(absf(d1.story_at(25.0) - 16.49325) < 0.0005, "story_at(25) = story_end")
	var prev: float = -1.0
	var mono: bool = true
	var trip: float = 0.0
	var r: float = 0.0
	while r <= 25.0:
		var s: float = d1.story_at(r)
		if s < prev - 1e-9:
			mono = false
		prev = s
		if d1.speed_at(r) > 0.0:
			trip = maxf(trip, absf(d1.real_at(s) - r))
		r += 1.0 / 240.0
	_check(mono, "story time never decreases")
	_check(trip < 1e-4, "real_at(story_at(r)) == r outside freezes (max err %.6f)" % trip)
	var expect: Dictionary = {"H1": 2.68125, "A1": 5.09125, "H4": 7.975, "H6": 13.548, "A3": 16.2315, "H8": 19.950}
	for nm: String in expect.keys():
		_check(absf(float(d1.ramp(nm)["r_hit"]) - float(expect[nm])) < 0.002, "%s real impact %.3f (got %.4f)" % [nm, float(expect[nm]), float(d1.ramp(nm)["r_hit"])])
	_check(absf(float(d1.ramp("H8")["r1"]) - 21.5005) < 0.002, "last ramp ends at 21.500 -> 3.5 s tail")
	# integrate speed numerically: must match story_at (catches a wrong closed form)
	var acc: float = 0.0
	var dt: float = 1.0 / 2000.0
	var t: float = 0.0
	while t < 25.0:
		acc += d1.speed_at(t + dt * 0.5) * dt
		t += dt
	_check(absf(acc - d1.story_at(25.0)) < 0.002, "∫speed dr = story_at (%.5f vs %.5f)" % [acc, d1.story_at(25.0)])
	# 3. validator failures
	var bad := _d1_clock()
	bad.story_end = 16.0
	var e1: PackedStringArray = bad.validate()
	_check(e1.size() >= 1 and String(e1[0]).contains("set story_end to 16.49325"), "wrong length reports the fix: %s" % str(e1))
	var ov := _d1_clock()
	ov.add("X", 4.40, "light")   # overlaps H2/H3
	_check(not ov.validate().is_empty(), "overlapping ramps rejected")
	var slow := CineClock.new()
	slow.length = 6.0
	slow.add("Z", 1.0, "heavy", {"k": 0.1})
	slow.story_end = 6.0 - 1.17375
	_check(str(slow.validate()).contains("outside 0.25-0.40"), "k = 0.1 rejected")
	var tail := CineClock.new()
	tail.length = 6.0
	tail.add("T", 3.5, "light")
	tail.story_end = 6.0 - 0.385
	_check(str(tail.validate()).contains("tail"), "tail shorter than 3 s rejected")
	# 4. base speed 0.5 (replays): duration formula
	var rp := CineClock.new()
	rp.base = 0.5
	rp.tail_rule = false
	rp.length = 5.0
	rp.add("F", 1.0, "heavy")
	rp.build()
	var q: Dictionary = rp.ramp("F")
	var story_spans: float = float(q["s1"]) - float(q["s0"])
	rp.story_end = 1.0 + 0.3875 + 0.4   # anything after the ramp
	var want: float = (rp.story_end - story_spans) / 0.5 + 1.73
	_check(absf(rp.real_duration() - want) < 1e-5, "base 0.5 real duration (%.5f vs %.5f)" % [rp.real_duration(), want])
	if fails.is_empty():
		print("✅ SUCCESS: CINE CLOCK (analytic ramps, round trips, d1 = 25.000 s, validator)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
```

Run: `godot --headless --path . --script tests/test_cine_clock.gd > /tmp/t3.log 2>&1; grep -E "SUCCESS|FAILED|Identifier" /tmp/t3.log`

Expected: `Identifier "CineClock" not declared`.

- [ ] **Step 2: Write `scripts/cine/CineClock.gd` (complete; verified with the test above)**

This is how the fixed real length is guaranteed. Every ramp has an exact real span and story span, so the real length of a timeline is `(story_end − Σ story spans)/base + Σ real spans`, with no numeric integration. `validate()` compares that against the slot length and prints the `story_end` that would fix a mismatch.

```gdscript
# File: res://scripts/cine/CineClock.gd
# Cinematic clock (A1-D6, A1-D7): maps REAL time r (seconds of video: music, subtitles, camera motion, the fixed slot length)
# to STORY time s (seconds inside the scene: actors, FX, cue times) through analytic slow-motion ramps.
# A ramp sits around an impact at story time `s` and is defined by REAL-time durations:
#   ri  speed base -> k (smoothstep)   hp  hold k   freeze  speed 0   hq  hold k   ro  speed k -> base (smoothstep)
# so every ramp has an exact real span (ri + hp + freeze + hq + ro) and an exact story span
#   pre  = ri·(base + k)/2 + hp·k        (story seconds before the impact)
#   post = hq·k + ro·(k + base)/2        (story seconds after the impact)
# (∫₀¹ smoothstep = 1/2). Between ramps the clock runs at `base` (1 for cinematics). Hence the real length of a timeline is
#   real = (story_end − Σ(pre + post)) / base + Σ real_span
# exactly, and validate() checks it against the declared slot length (A1-D8). The impact's real time is the start of its
# freeze. Playback only needs story_at(r) (closed form); real_at(s) inverts with bisection inside smooth ramps.
class_name CineClock
extends RefCounted

const PRESETS: Dictionary = {
	"light":    {"k": 0.40, "freeze": 0.10, "ri": 0.10, "hp": 0.10, "hq": 0.25, "ro": 0.15},
	"medium":   {"k": 0.30, "freeze": 0.14, "ri": 0.12, "hp": 0.20, "hq": 0.50, "ro": 0.22},
	"heavy":    {"k": 0.25, "freeze": 0.18, "ri": 0.15, "hp": 0.30, "hq": 0.80, "ro": 0.30},
	"finisher": {"k": 0.25, "freeze": 0.20, "ri": 0.20, "hp": 0.45, "hq": 1.00, "ro": 0.35},
	"accent":   {"k": 0.30, "freeze": 0.00, "ri": 0.12, "hp": 0.25, "hq": 0.35, "ro": 0.25},
}
const TOL: float = 0.0005          # real-length tolerance (s)
const TAIL_MIN: float = 3.0        # last seconds at base speed (A1-D8)
const TAIL_MAX: float = 4.0
enum Seg { ONE, IN, HOLD, FREEZE, OUT }

var length: float = 25.0           # declared real length (the slot length)
var story_end: float = 0.0         # declared story length
var base: float = 1.0              # speed between ramps (replays use 0.5)
var tail_rule: bool = true         # replays switch the 3-4 s tail rule off
var ramps: Array[Dictionary] = []  # sorted by s: {name, preset, s, k, freeze, ri, hp, hq, ro, s0, s1, r0, r_hit, r1}
var _segs: Array = []              # [r0, dur, s0, Seg, k]


## Add a ramp around the impact at story time s. over: per-ramp overrides of the preset values (extra keys are kept).
func add(name: String, s: float, preset: String = "medium", over: Dictionary = {}) -> void:
	var p: Dictionary = (PRESETS[preset] as Dictionary).duplicate()
	p.merge(over, true)
	p["name"] = name
	p["preset"] = preset
	p["s"] = s
	ramps.append(p)
	_segs.clear()


static func _I(u: float) -> float:   # ∫₀ᵘ smoothstep
	return u * u * u - u * u * u * u * 0.5


static func _S(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


## Sort the ramps and build the real-time segment list. Called lazily by the queries.
func build() -> void:
	ramps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) < float(b["s"]))
	_segs.clear()
	var r: float = 0.0
	var s: float = 0.0
	var b: float = base
	for p: Dictionary in ramps:
		var k: float = p["k"]
		var pre: float = float(p["ri"]) * (b + k) * 0.5 + float(p["hp"]) * k
		var post: float = float(p["hq"]) * k + float(p["ro"]) * (k + b) * 0.5
		p["s0"] = float(p["s"]) - pre
		p["s1"] = float(p["s"]) + post
		var gap: float = maxf(float(p["s0"]) - s, 0.0)
		_segs.append([r, gap / b, s, Seg.ONE, b])
		r += gap / b
		s = p["s0"]
		p["r0"] = r
		for part: Array in [[Seg.IN, float(p["ri"])], [Seg.HOLD, float(p["hp"])], [Seg.FREEZE, float(p["freeze"])], [Seg.HOLD, float(p["hq"])], [Seg.OUT, float(p["ro"])]]:
			var d: float = part[1]
			if d <= 0.0:
				continue
			if part[0] == Seg.FREEZE:
				p["r_hit"] = r
			_segs.append([r, d, s, part[0], k])
			r += d
			s += _story_span(part[0], d, k, b)
		if float(p["freeze"]) <= 0.0:
			p["r_hit"] = float(p["r0"]) + float(p["ri"]) + float(p["hp"])
		p["r1"] = r
	_segs.append([r, INF, s, Seg.ONE, b])


static func _story_span(seg: int, d: float, k: float, b: float) -> float:
	match seg:
		Seg.ONE:
			return d * b
		Seg.IN, Seg.OUT:
			return d * (b + k) * 0.5
		Seg.HOLD:
			return d * k
	return 0.0


func _ensure() -> void:
	if _segs.is_empty():
		build()


## Story time at real time r (closed form).
func story_at(r: float) -> float:
	_ensure()
	if r <= 0.0:
		return 0.0
	for g: Array in _segs:
		var r0: float = g[0]
		var d: float = g[1]
		if r > r0 + d:
			continue
		var dt: float = r - r0
		var s0: float = g[2]
		var k: float = g[4]
		match int(g[3]):
			Seg.ONE:
				return s0 + dt * base
			Seg.HOLD:
				return s0 + dt * k
			Seg.FREEZE:
				return s0
			Seg.IN:
				var u: float = dt / d
				return s0 + d * (base * u + (k - base) * _I(u))
			Seg.OUT:
				var u2: float = dt / d
				return s0 + d * (k * u2 + (base - k) * _I(u2))
	return 0.0


## Speed ds/dr at real time r (0 during a freeze).
func speed_at(r: float) -> float:
	_ensure()
	for g: Array in _segs:
		var r0: float = g[0]
		var d: float = g[1]
		if r > r0 + d:
			continue
		var k: float = g[4]
		match int(g[3]):
			Seg.ONE:
				return base
			Seg.HOLD:
				return k
			Seg.FREEZE:
				return 0.0
			Seg.IN:
				return base + (k - base) * _S(clampf((r - r0) / d, 0.0, 1.0))
			Seg.OUT:
				return k + (base - k) * _S(clampf((r - r0) / d, 0.0, 1.0))
	return base


## Real time at story time s (an impact's story time maps to the start of its freeze).
func real_at(s: float) -> float:
	_ensure()
	if s <= 0.0:
		return 0.0
	for g: Array in _segs:
		var r0: float = g[0]
		var d: float = g[1]
		var s0: float = g[2]
		var k: float = g[4]
		var seg: int = g[3]
		if seg == Seg.FREEZE:
			continue
		var span: float = INF if d == INF else _story_span(seg, d, k, base)
		if s > s0 + span + 1e-9:
			continue
		match seg:
			Seg.ONE:
				return r0 + (s - s0) / base
			Seg.HOLD:
				return r0 + (s - s0) / k
			_:
				var lo: float = 0.0
				var hi: float = 1.0
				for i: int in 40:
					var m: float = (lo + hi) * 0.5
					var sm: float = d * (base * m + (k - base) * _I(m)) if seg == Seg.IN else d * (k * m + (base - k) * _I(m))
					if s0 + sm < s:
						lo = m
					else:
						hi = m
				return r0 + d * hi
	return 0.0


## Real duration of the declared story (analytic through the segments).
func real_duration() -> float:
	return real_at(story_end)


func ramp(name: String) -> Dictionary:
	_ensure()
	for p: Dictionary in ramps:
		if String(p["name"]) == name:
			return p
	return {}


## Errors (empty = valid): real length, overlaps, ranges, tail at base speed.
func validate() -> PackedStringArray:
	build()
	var err: PackedStringArray = []
	var prev_s1: float = 0.0
	var prev_name: String = "start"
	for p: Dictionary in ramps:
		var nm: String = p["name"]
		var k: float = p["k"]
		var fr: float = p["freeze"]
		if float(p["s0"]) < prev_s1 - 1e-6:
			err.append("%s: ramp starts at story %.4f before %s ends at %.4f" % [nm, float(p["s0"]), prev_name, prev_s1])
		if fr > 0.0 and (k < 0.25 - 1e-6 or k > 0.40 + 1e-6):
			err.append("%s: impact speed %.3f outside 0.25-0.40" % [nm, k])
		if fr > 0.0 and (fr < 0.10 - 1e-6 or fr > 0.20 + 1e-6):
			err.append("%s: freeze %.3f s outside 0.10-0.20" % [nm, fr])
		if fr <= 0.0 and (k < 0.2 - 1e-6 or k > 0.6 + 1e-6):
			err.append("%s: accent speed %.3f outside 0.20-0.60" % [nm, k])
		prev_s1 = p["s1"]
		prev_name = nm
	if story_end < prev_s1 - 1e-6:
		err.append("story_end %.4f is before the last ramp ends (%.4f)" % [story_end, prev_s1])
	var real: float = real_duration()
	if absf(real - length) > TOL:
		err.append("real length %.4f s != slot %.4f s: set story_end to %.5f" % [real, length, story_end + (length - real) * base])
	if tail_rule and not ramps.is_empty():
		var tail: float = length - float(ramps[ramps.size() - 1]["r1"])
		if tail < TAIL_MIN - 1e-6 or tail > TAIL_MAX + 1e-6:
			err.append("tail at normal speed %.3f s outside %.1f-%.1f s" % [tail, TAIL_MIN, TAIL_MAX])
	return err


## Beat rows in real seconds, sorted: {name, preset, s, k, freeze, r_hit, r_freeze_end, r_start, r_end, what}.
func beat_rows() -> Array[Dictionary]:
	_ensure()
	var rows: Array[Dictionary] = []
	for p: Dictionary in ramps:
		rows.append({"name": p["name"], "preset": p["preset"], "s": p["s"], "k": p["k"], "freeze": p["freeze"],
			"r_hit": p["r_hit"], "r_freeze_end": float(p["r_hit"]) + float(p["freeze"]), "r_start": p["r0"], "r_end": p["r1"],
			"what": String(p.get("what", ""))})
	return rows
```

Import, check `CineClock` is in the class cache, and run the clock test. Expected: `✅ SUCCESS: CINE CLOCK (…)`.

- [ ] **Step 3: Write the test timeline `tests/support/cine_test_timeline.gd`**

One light hit at story 1.6 gives a ramp ending at real 2.19, a tail of 3.81 s, and story_end 6.0 − 0.385 = 5.615.

```gdscript
# File: res://tests/support/cine_test_timeline.gd
# 6 s test timeline for test_cine_timeline / test_cine_player: two actors, one light hit, two shots, an Anh Duy subtitle with
# its "Dịch:" line, one SFX, one FX, one prop.
extends CineTimeline


func build() -> void:
	slot = "test_slot"
	length = 6.0
	story_end = 5.615
	mood = "punchy"
	stage = {"landmark": "campus_west_gate", "near": 30.0, "size": Vector2(10.0, 8.0), "tod": "night"}
	actor("hero", {"preset": "player", "seed": 3}, "Bạn", Color("#F37021"))
	actor("dummy", {"preset": "rider", "seed": 4, "backpack": false, "shirt_color": Color("#1E8C8C")}, "Anh Duy", Color("#9B59B6"))
	hit("H1", 1.6, "light", "jab -> dummy")
	key("hero", 0.0, Vector3(-1.5, 0.0, 0.0), -90.0)
	key("hero", 1.6, Vector3(-0.55, 0.0, 0.0), -90.0)
	move("hero", 0.0, "fight_idle")
	strike("hero", "H1", "jab")
	move("hero", 2.2, "fight_idle")
	key("dummy", 0.0, Vector3(0.3, 0.0, 0.0), 90.0)
	move("dummy", 0.0, "fight_idle")
	strike("dummy", "H1", "hit_head")
	move("dummy", 2.2, "fight_idle")
	expr("dummy", 1.6, "pain")
	look("hero", 3.0, 5.6, "dummy")
	shot("S1", 0.0, "static", "two-shot", {"pos": Vector3(0.0, 1.5, 4.0), "look": Vector3(-0.3, 1.1, 0.0), "fov": 45.0})
	shot("S2", 1.4, "orbit", "orbit on the jab", {"center": Vector3(-0.2, 1.2, 0.0), "radius": 3.0, "deg_from": 20.0, "deg_to": 80.0, "height": 0.6, "fov": 45.0})
	sub(3.0, 1.5, "dummy", "Ok e, a check log r, deploy hotfix lên prod, gg.", "Dịch: Anh ổn, em cứ yên tâm.")
	sfx_at("H1", "groan", -4.0)
	fx_at("H1", "sparks", "dummy:Head", {"power": 0.5})
	prop("crates", "crate_stack", Vector3(1.8, 0.0, -1.5), 15.0)
```

- [ ] **Step 4: Write the failing timeline test `tests/test_cine_timeline.gd`**

```gdscript
# File: res://tests/test_cine_timeline.gd
# Headless test of CineTimeline: the test timeline validates, its beat sheet has the exact real times, and the validator
# catches a wrong story_end, a missing strike, an unknown move, an untranslated Anh Duy line, a shot not starting at 0 and a
# cue after the story end. Slot registry tolerates missing slots.
# Run:  godot --headless --path . --script tests/test_cine_timeline.gd
extends SceneTree

const TL_SCRIPT: String = "res://tests/support/cine_test_timeline.gd"
var fails: Array[String] = []


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _tl() -> CineTimeline:
	var tl: CineTimeline = (load(TL_SCRIPT) as GDScript).new()
	tl.build()
	return tl


func _initialize() -> void:
	print("--- TEST CINE TIMELINE ---")
	var tl: CineTimeline = _tl()
	var errs: PackedStringArray = tl.validate()
	_check(errs.is_empty(), "test timeline valid: %s" % str(errs))
	var sheet: String = tl.beat_sheet()
	_check(sheet == _tl().beat_sheet(), "beat sheet is deterministic")
	_check(sheet.contains("Real length: 6.000 s"), "header has the real length")
	_check(sheet.contains("tail 3.810 s"), "header has the tail (3.810 s)")
	var h1_row: String = ""
	for line: String in sheet.split("\n"):
		if line.begins_with("H1 "):
			h1_row = line
	_check(h1_row.contains("1.690") and h1_row.contains("1.790"), "H1 real impact 1.690, freeze end 1.790: '%s'" % h1_row)
	_check(sheet.contains("SHOT S2") and sheet.contains("1.400"), "shot S2 at real 1.400")
	_check(sheet.contains("Dịch: Anh ổn"), "subtitle translation line listed")
	_check(is_equal_approx(CineTimeline.face(Vector3.ZERO, Vector3(1.0, 0.0, 0.0)), -90.0), "face(+X) = -90° (characters face -Z)")
	# validator failures
	var a: CineTimeline = _tl()
	a.story_end = 5.0
	_check(str(a.validate()).contains("set story_end to 5.61500"), "wrong story_end reported with the fix")
	var b: CineTimeline = _tl()
	b.cues.assign(b.cues.filter(func(c: Dictionary) -> bool: return String(c["type"]) != "strike"))
	_check(str(b.validate()).contains("H1 has no strike"), "impact ramp without a strike rejected")
	var c2: CineTimeline = _tl()
	c2.move("hero", 3.0, "moonwalk")
	_check(str(c2.validate()).contains("unknown move moonwalk"), "unknown move rejected")
	var d: CineTimeline = _tl()
	d.sub(4.6, 1.0, "dummy", "Ping prod đi e.")
	_check(str(d.validate()).contains("needs a translation"), "Anh Duy line without Dịch rejected")
	var e: CineTimeline = _tl()
	e.shots[0]["s"] = 0.2
	_check(str(e.validate()).contains("first shot"), "first shot must start at 0")
	var f: CineTimeline = _tl()
	f.expr("hero", 9.0, "happy")
	_check(str(f.validate()).contains("outside the story"), "cue after story_end rejected")
	# registry
	_check(CineTimeline.load_slot("no_such_slot") == null, "load_slot of a missing slot returns null")
	_check(CineTimeline.slots() is PackedStringArray, "slots() lists the timelines folder")
	if fails.is_empty():
		print("✅ SUCCESS: CINE TIMELINE (validator, beat sheet, registry)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
```

Run it. Expected: `Identifier "CineTimeline" not declared`.

**Speaker rule.** Anh Duy's translation is enforced by the speaker name, which `actor()` sets. The test timeline names its dummy "Anh Duy" on purpose, so the rule is exercised.

- [ ] **Step 5: Write `scripts/cine/CineTimeline.gd` (complete)**

```gdscript
# File: res://scripts/cine/CineTimeline.gd
# Data model of one cinematic (spec A1-D8, A1-D9, A1-D10). Each cinematic is a script
# res://scripts/cine/timelines/<slot>.gd that extends CineTimeline and fills it in build() with the helpers below.
# Times: actor cues, shots, FX and SFX in STORY seconds (a hit name may stand for its story time); subtitles in REAL seconds.
# Positions are stage-local (X right, -Z forward along the road, ground y = 0); yaw in degrees, characters face -Z at 0.
class_name CineTimeline
extends RefCounted

const TIMELINE_DIR: String = "res://scripts/cine/timelines/"
const RIGS: Array[String] = ["static", "dolly", "orbit", "low_hero", "track", "crane"]
const FX_KINDS: Array[String] = ["sparks", "dust", "flash", "debris", "crate", "stars"]
const TRANSLATED_SPEAKERS: Array[String] = ["Anh Duy"]

var slot: String = ""
var length: float = 25.0
var story_end: float = 0.0
var music_slot: String = ""
var mood: String = "punchy"
var fade_in: float = 0.5
var fade_out: float = 0.5
var letterbox: bool = true
var stage: Dictionary = {}
var clock: CineClock = CineClock.new()
var actors: Dictionary = {}            # id -> {"opts", "name", "color"}
var cues: Array[Dictionary] = []       # {"type": move|strike|key|expr|look|show, "actor", "s", ...}
var shots: Array[Dictionary] = []      # {"id", "s", "rig", "what", "params"}
var subs: Array[Dictionary] = []       # {"r", "dur", "speaker", "text", "tr"}
var sfx: Array[Dictionary] = []        # {"at", "cue", "db"}
var fx: Array[Dictionary] = []         # {"at", "kind", "where", "params"}
var props: Array[Dictionary] = []      # {"id", "kind", "pos", "yaw", "opts"}
var _last_yaw: Dictionary = {}         # actor -> last keyed yaw (keeps yaw continuous)


## Filled by each timeline script.
func build() -> void:
	pass


static func slots() -> PackedStringArray:
	var out: PackedStringArray = []
	if not DirAccess.dir_exists_absolute(TIMELINE_DIR):
		return out
	for f: String in ResourceLoader.list_directory(TIMELINE_DIR):
		if f.ends_with(".gd"):
			out.append(f.get_basename())
	out.sort()
	return out


static func load_slot(slot_name: String) -> CineTimeline:
	var path: String = TIMELINE_DIR + slot_name + ".gd"
	if not ResourceLoader.exists(path):
		return null
	var tl: CineTimeline = (load(path) as GDScript).new()
	tl.build()
	if tl.music_slot == "":
		tl.music_slot = tl.slot
	return tl


## Yaw in degrees for an actor at `from` to face `to` (characters face -Z at yaw 0).
static func face(from: Vector3, to: Vector3) -> float:
	var d: Vector3 = to - from
	return rad_to_deg(atan2(-d.x, -d.z))


# ---------------------------------------------------------------------------
# Authoring helpers
# ---------------------------------------------------------------------------
func actor(id: String, opts: Dictionary, speaker: String = "", color: Color = Color.WHITE) -> void:
	actors[id] = {"opts": opts, "name": speaker if speaker != "" else id, "color": color}


func hit(name: String, s: float, preset: String, what: String, over: Dictionary = {}) -> void:
	var o: Dictionary = over.duplicate()
	o["what"] = what
	clock.add(name, s, preset, o)


func move(actor_id: String, s: float, move_name: String, opts: Dictionary = {}) -> void:
	cues.append({"type": "move", "actor": actor_id, "s": s, "move": move_name, "opts": opts})


## The move's impact frame lands on `at` (a hit name or a story time).
func strike(actor_id: String, at: Variant, move_name: String, opts: Dictionary = {}) -> void:
	cues.append({"type": "strike", "actor": actor_id, "at": at, "s": -1.0, "move": move_name, "opts": opts})


## opts: "mode" (easing of the segment ending here), "arc" (m), "spin" (Vector3 degrees). Yaw stays continuous.
func key(actor_id: String, s: float, pos: Vector3, yaw_deg: float, opts: Dictionary = {}) -> void:
	var y: float = yaw_deg
	if _last_yaw.has(actor_id):
		var prev: float = _last_yaw[actor_id]
		y = prev + wrapf(yaw_deg - prev, -180.0, 180.0)
	_last_yaw[actor_id] = y
	cues.append({"type": "key", "actor": actor_id, "s": s, "pos": pos, "yaw": y, "opts": opts})


func expr(actor_id: String, s: float, cell: String) -> void:
	cues.append({"type": "expr", "actor": actor_id, "s": s, "cell": cell})


## target: another actor id or a stage-local Vector3.
func look(actor_id: String, s0: float, s1: float, target: Variant) -> void:
	cues.append({"type": "look", "actor": actor_id, "s": s0, "s1": s1, "target": target})


func show(actor_id: String, s: float, on: bool) -> void:
	cues.append({"type": "show", "actor": actor_id, "s": s, "on": on})


func shot(id: String, s: float, rig: String, what: String, params: Dictionary = {}) -> void:
	shots.append({"id": id, "s": s, "rig": rig, "what": what, "params": params})


func sub(r: float, dur: float, speaker: String, text: String, tr: String = "") -> void:
	subs.append({"r": r, "dur": dur, "speaker": speaker, "text": text, "tr": tr})


func sfx_at(at: Variant, cue: String, db: float = 0.0) -> void:
	sfx.append({"at": at, "cue": cue, "db": db})


## where: "actor:Bone", "actor", a prop id (kind "crate") or a stage-local Vector3.
func fx_at(at: Variant, kind: String, where: Variant, params: Dictionary = {}) -> void:
	fx.append({"at": at, "kind": kind, "where": where, "params": params})


func prop(id: String, kind: String, pos: Vector3, yaw_deg: float = 0.0, opts: Dictionary = {}) -> void:
	props.append({"id": id, "kind": kind, "pos": pos, "yaw": yaw_deg, "opts": opts})


## Story time of `at`: a hit name -> its ramp's story time, a number -> itself, otherwise -1.
func story_time(at: Variant) -> float:
	if at is String:
		var p: Dictionary = clock.ramp(String(at))
		return float(p["s"]) if not p.is_empty() else -1.0
	if at is float or at is int:
		return float(at)
	return -1.0


func speaker_name(id: String) -> String:
	return String(actors[id]["name"]) if actors.has(id) else id


# ---------------------------------------------------------------------------
# Validation (A1-D8)
# ---------------------------------------------------------------------------
func validate() -> PackedStringArray:
	var err: PackedStringArray = []
	if slot == "":
		err.append("slot is empty")
	clock.length = length
	clock.story_end = story_end
	err.append_array(clock.validate())
	var struck: Dictionary = {}
	for c: Dictionary in cues:
		var aid: String = c["actor"]
		if not actors.has(aid):
			err.append("cue at %.3f: unknown actor %s" % [float(c["s"]), aid])
			continue
		var s: float = float(c["s"])
		if c["type"] == "move" or c["type"] == "strike":
			var mv: String = c["move"]
			if not CineMoves.has_move(mv):
				err.append("%s: unknown move %s" % [aid, mv])
				continue
			var dur: float = float((c["opts"] as Dictionary).get("dur", CineMoves.MOVES[mv]["dur"]))
			if c["type"] == "strike":
				if not CineMoves.is_strike(mv):
					err.append("%s: %s is not a strike move" % [aid, mv])
					continue
				var sh: float = story_time(c["at"])
				if sh < 0.0:
					err.append("%s: strike at unknown hit %s" % [aid, str(c["at"])])
					continue
				if c["at"] is String:
					struck[String(c["at"])] = true
				s = sh - float(CineMoves.MOVES[mv]["hit_u"]) * dur
		if s < -1e-6 or s > story_end + 1e-6:
			err.append("%s %s at story %.3f is outside the story (0..%.3f)" % [aid, String(c["type"]), s, story_end])
		if c["type"] == "look":
			var tg: Variant = c["target"]
			if tg is String and not actors.has(String(tg)):
				err.append("%s: look target %s unknown" % [aid, String(tg)])
	for p: Dictionary in clock.ramps:
		if float(p["freeze"]) > 0.0 and not struck.has(String(p["name"])):
			err.append("%s has no strike cue" % String(p["name"]))
	if shots.is_empty():
		err.append("no shots")
	else:
		if absf(float(shots[0]["s"])) > 1e-6:
			err.append("first shot starts at %.3f, must start at 0" % float(shots[0]["s"]))
		for i: int in shots.size():
			var sh2: Dictionary = shots[i]
			if not RIGS.has(String(sh2["rig"])):
				err.append("shot %s: unknown rig %s" % [String(sh2["id"]), String(sh2["rig"])])
			if i > 0 and float(sh2["s"]) <= float(shots[i - 1]["s"]):
				err.append("shot %s does not start after %s" % [String(sh2["id"]), String(shots[i - 1]["id"])])
			if float(sh2["s"]) >= story_end:
				err.append("shot %s starts after the story end" % String(sh2["id"]))
	for sb: Dictionary in subs:
		if float(sb["r"]) < 0.0 or float(sb["r"]) + float(sb["dur"]) > length + 1e-6:
			err.append("subtitle '%s' outside 0..%.3f s" % [String(sb["text"]), length])
		if TRANSLATED_SPEAKERS.has(speaker_name(String(sb["speaker"]))) and String(sb["tr"]) == "":
			err.append("subtitle '%s' by %s needs a translation (Dịch:)" % [String(sb["text"]), speaker_name(String(sb["speaker"]))])
	var prop_ids: Dictionary = {}
	for pr: Dictionary in props:
		if prop_ids.has(pr["id"]):
			err.append("duplicate prop id %s" % String(pr["id"]))
		prop_ids[pr["id"]] = true
	for e: Dictionary in sfx + fx:
		var st: float = story_time(e["at"])
		if st < 0.0 or st > story_end + 1e-6:
			err.append("%s at %s is outside the story" % [String(e.get("cue", e.get("kind", "?"))), str(e["at"])])
	for e2: Dictionary in fx:
		if not FX_KINDS.has(String(e2["kind"])):
			err.append("unknown fx kind %s" % String(e2["kind"]))
		elif String(e2["kind"]) == "crate" and not prop_ids.has(e2["where"]):
			err.append("crate fx needs a prop id, got %s" % str(e2["where"]))
	if not stage.is_empty() and not stage.has("landmark"):
		err.append("stage needs a landmark")
	return err


# ---------------------------------------------------------------------------
# Beat sheet (A1-D9): every time in REAL seconds
# ---------------------------------------------------------------------------
func beat_sheet() -> String:
	clock.length = length
	clock.story_end = story_end
	clock.build()
	var ms: String = music_slot if music_slot != "" else slot
	var last_r1: float = float(clock.ramps[clock.ramps.size() - 1]["r1"]) if not clock.ramps.is_empty() else 0.0
	var L: PackedStringArray = []
	L.append("# %s - beat sheet (generated by tools/cine_beats.gd from scripts/cine/timelines/%s.gd; do not edit)" % [slot, slot])
	L.append("# Real length: %.3f s. Story length: %.3f s. Normal speed from %.3f to %.3f (tail %.3f s)." % [length, story_end, last_r1, length, length - last_r1])
	L.append("# Music slot %s: user://music/%s.ogg or .mp3 starts at 0.000; a longer file fades out %.3f-%.3f; no file = synthesized cue." % [ms, ms, maxf(length - 0.5, 0.0), length])
	L.append("#")
	L.append("# id   kind      real_hit  freeze_end  slowmo_from  slowmo_to  speed  story_s  what")
	for row: Dictionary in clock.beat_rows():
		L.append("%-4s %-9s %8.3f %11.3f %12.3f %10.3f %6.2f %8.3f  %s" % [String(row["name"]), String(row["preset"]), float(row["r_hit"]),
			float(row["r_freeze_end"]), float(row["r_start"]), float(row["r_end"]), float(row["k"]), float(row["s"]), String(row["what"])])
	L.append("#")
	L.append("# Shots (real start, rig, what)")
	for sh: Dictionary in shots:
		L.append("SHOT %-4s %8.3f  %-8s  %s" % [String(sh["id"]), clock.real_at(float(sh["s"])), String(sh["rig"]), String(sh["what"])])
	L.append("#")
	L.append("# Subtitles (real start - end, speaker: line)")
	for sb: Dictionary in subs:
		var line: String = "SUB %8.3f - %6.3f  %s: %s" % [float(sb["r"]), float(sb["r"]) + float(sb["dur"]), speaker_name(String(sb["speaker"])), String(sb["text"])]
		if String(sb["tr"]) != "":
			line += "  /  " + String(sb["tr"])
		L.append(line)
	return "\n".join(L) + "\n"
```

- [ ] **Step 6: Write `tools/cine_beats.gd`**

```gdscript
# File: res://tools/cine_beats.gd
# Writes docs/cinematics/<slot>.txt for every timeline in scripts/cine/timelines/ (refuses invalid ones) and prints the
# owner's music folder.
# Run:  godot --headless --path . --script tools/cine_beats.gd
extends SceneTree


func _initialize() -> void:
	var dir: String = ProjectSettings.globalize_path("res://docs/cinematics/")
	DirAccess.make_dir_recursive_absolute(dir)
	var n: int = 0
	var bad: int = 0
	for s: String in CineTimeline.slots():
		var tl: CineTimeline = CineTimeline.load_slot(s)
		var errs: PackedStringArray = tl.validate()
		if not errs.is_empty():
			print("INVALID %s: %s" % [s, str(errs)])
			bad += 1
			continue
		var f: FileAccess = FileAccess.open(dir + s + ".txt", FileAccess.WRITE)
		f.store_string(tl.beat_sheet())
		f.close()
		n += 1
		print("wrote docs/cinematics/%s.txt" % s)
	print("music folder: %s  (<slot>.ogg or <slot>.mp3)" % ProjectSettings.globalize_path("user://music/"))
	print("BEATS WRITTEN %d (invalid %d)" % [n, bad])
	quit(1 if bad > 0 else 0)
```

Create the empty timelines folder marker: `scripts/cine/timelines/.gitkeep`.

- [ ] **Step 7: Import, run both tests and the tool**

```bash
godot --headless --import --path . > /tmp/a1_imp.log 2>&1; grep -c "CineTimeline\|CineClock" .godot/global_script_class_cache.cfg
git diff --name-only -- '*.import' | xargs -r git checkout --
godot --headless --path . --script tests/test_cine_clock.gd > /tmp/t3a.log 2>&1; grep -E "SUCCESS|FAILED|✗" /tmp/t3a.log
godot --headless --path . --script tests/test_cine_timeline.gd > /tmp/t3b.log 2>&1; grep -E "SUCCESS|FAILED|✗" /tmp/t3b.log
godot --headless --path . --script tools/cine_beats.gd > /tmp/cb.log 2>&1; grep -E "BEATS|music folder" /tmp/cb.log
```

Expected:
- both tests `SUCCESS`;
- the tool prints `BEATS WRITTEN 0 (invalid 0)` and the music folder path.

- [ ] **Step 8: Full regression, then commit**

```bash
git add scripts/cine/CineClock.gd scripts/cine/CineClock.gd.uid scripts/cine/CineTimeline.gd scripts/cine/CineTimeline.gd.uid scripts/cine/timelines/.gitkeep tools/cine_beats.gd tools/cine_beats.gd.uid tests/support/cine_test_timeline.gd tests/support/cine_test_timeline.gd.uid tests/test_cine_clock.gd tests/test_cine_clock.gd.uid tests/test_cine_timeline.gd tests/test_cine_timeline.gd.uid
git commit -m "feat(cine): analytic slow-motion clock with exact real length, timeline model with validator and generated beat sheets

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Music slots, SFX and impact FX  [effort: high]

**Files:**
- Create: `scripts/cine/CineAudio.gd`, `scripts/cine/CineFX.gd`, `tests/test_cine_audio_fx.gd`.

**Interfaces:**
- Consumes: `CineActor.bone_world` (Task 2), for stars.
- Produces (`class_name CineAudio`, static):
  - Constants: `MUSIC_DIR = "user://music/"`, `SFX_DIR = "user://sfx/"`, `SR = 22050`, `SFX_CUES: Array[String]`, `MOODS: Dictionary`.
  - Loading:
    - `music_file(slot) -> String` (`""` if none);
    - `load_music(slot) -> AudioStream` (`null` if none);
    - `stream_length(st: AudioStream) -> float`.
  - `music_gain(r, length, stream_len) -> float`.
  - Synthesis:
    - `synth_cue(length, hits: Array[Dictionary], mood := "punchy") -> AudioStreamWAV`, where a hit is `{r, preset, freeze, r_start, r_end}`;
    - `synth_sting(length, r_hit) -> AudioStreamWAV`.
  - `sfx(cue) -> AudioStream` (cached; `user://sfx/<cue>.ogg` first).
- Produces (`class_name CineFX extends Node3D`):
  - `burst(kind, pos: Vector3, dir: Vector3, power: float, s: float)`, kind `sparks|dust|flash|debris`;
  - `crate_break(prop: Node3D, dir, power, s)`;
  - `stars(actor: Node3D, s0, s1)`;
  - `update(s: float, speed: float)`;
  - `live_count() -> int`;
  - static `build_prop(kind, opts := {}) -> Node3D`, kind `crate_stack|scooter|banana|phone`;
  - static `set_prop_glow(prop: Node3D, on: bool)`;
  - static `radial_texture(size := 64, power := 2.0) -> ImageTexture`.

- [ ] **Step 1: Write the failing test `tests/test_cine_audio_fx.gd`**

```gdscript
# File: res://tests/test_cine_audio_fx.gd
# Headless test of CineAudio (slot loader, gain rule, synthesized cue/sting/SFX) and CineFX (particles follow the clock speed,
# analytic debris freezes with story time, crate break, stars, props, code textures, no GPU particles).
# Run:  godot --headless --path . --script tests/test_cine_audio_fx.gd
extends SceneTree

var fails: Array[String] = []


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _rms(w: AudioStreamWAV, t0: float, t1: float) -> float:
	var d: PackedByteArray = w.data
	var a: int = int(t0 * CineAudio.SR)
	var b: int = mini(int(t1 * CineAudio.SR), d.size() / 2)
	var acc: float = 0.0
	for i: int in range(a, b):
		var v: float = float(d.decode_s16(i * 2)) / 32767.0
		acc += v * v
	return sqrt(acc / maxf(float(b - a), 1.0))


func _initialize() -> void:
	print("--- TEST CINE AUDIO + FX ---")
	# --- gain rule (A1-D13)
	_check(is_equal_approx(CineAudio.music_gain(24.0, 25.0, 30.0), 1.0), "longer file: full volume before the last 0.5 s")
	_check(absf(CineAudio.music_gain(24.75, 25.0, 30.0) - 0.5) < 1e-6, "longer file: half way through the fade at 24.75")
	_check(CineAudio.music_gain(25.0, 25.0, 30.0) == 0.0, "longer file: silent at the end")
	_check(is_equal_approx(CineAudio.music_gain(24.9, 25.0, 20.0), 1.0), "shorter file: no fade")
	_check(CineAudio.music_file("a1_no_such_slot") == "" and CineAudio.load_music("a1_no_such_slot") == null, "missing slot file -> synthesized cue")
	# --- synthesized cue: exact length, accents on the hits, silent end
	var hits: Array[Dictionary] = [
		{"r": 2.681, "preset": "heavy", "freeze": 0.18, "r_start": 2.231, "r_end": 3.961},
		{"r": 7.975, "preset": "medium", "freeze": 0.14, "r_start": 7.655, "r_end": 8.835},
		{"r": 19.950, "preset": "finisher", "freeze": 0.2, "r_start": 19.300, "r_end": 21.500}]
	var t0: int = Time.get_ticks_msec()
	var cue: AudioStreamWAV = CineAudio.synth_cue(25.0, hits, "punchy")
	var ms: int = Time.get_ticks_msec() - t0
	_check(cue != null and cue.mix_rate == CineAudio.SR and cue.format == AudioStreamWAV.FORMAT_16_BITS, "cue is 22.05 kHz 16-bit")
	_check(absi(cue.data.size() - 25 * CineAudio.SR * 2) <= 4, "cue is exactly 25.000 s (%d bytes)" % cue.data.size())
	_check(ms < 3000, "cue synthesized in %d ms < 3000" % ms)
	for h: Dictionary in hits:
		var at: float = float(h["r"])
		var peak: float = _rms(cue, at, at + 0.06)
		var before: float = _rms(cue, at - 1.45, at - 0.45)   # 1 s of grid before the riser
		_check(peak > 2.0 * before + 0.01, "accent at %.3f (rms %.3f vs %.3f before)" % [at, peak, before])
	_check(_rms(cue, 24.99, 25.0) < 0.02, "cue faded out at the end")
	var sting: AudioStreamWAV = CineAudio.synth_sting(5.0, 2.75)
	_check(absi(sting.data.size() - 5 * CineAudio.SR * 2) <= 4, "sting is exactly 5.000 s")
	for c: String in CineAudio.SFX_CUES:
		var st: AudioStream = CineAudio.sfx(c)
		var ln: float = CineAudio.stream_length(st)
		_check(st != null and ln > 0.04 and ln < 2.5, "sfx %s synthesized (%.2f s)" % [c, ln])
	# --- FX follow the clock
	var world := Node3D.new()
	root.add_child(world)
	var fx := CineFX.new()
	world.add_child(fx)
	fx.burst("sparks", Vector3(0.0, 1.2, 0.0), Vector3(1.0, 0.3, 0.0), 1.0, 2.0)
	fx.burst("dust", Vector3.ZERO, Vector3.UP, 1.0, 2.0)
	fx.burst("flash", Vector3(0.0, 1.2, 0.0), Vector3.UP, 1.0, 2.0)
	fx.burst("debris", Vector3(0.0, 1.0, 0.0), Vector3(1.0, 0.5, 0.0), 1.0, 2.0)
	_check(fx.live_count() >= 4, "bursts spawned (%d live)" % fx.live_count())
	fx.update(2.05, 0.0)
	var parts: Array[Node] = fx.find_children("*", "CPUParticles3D", true, false)
	_check(parts.size() >= 2, "sparks and dust are CPUParticles3D")
	var frozen: bool = true
	for p: Node in parts:
		frozen = frozen and is_equal_approx((p as CPUParticles3D).speed_scale, 0.0)
	_check(frozen, "particles stop while the clock is frozen")
	fx.update(2.1, 0.5)
	_check(is_equal_approx((parts[0] as CPUParticles3D).speed_scale, 0.5), "particles run at the clock speed")
	var chunks: Array[Node] = fx.find_children("Debris*", "Node3D", true, false)
	_check(not chunks.is_empty(), "debris chunks exist")
	if not chunks.is_empty():
		var ch: Node3D = chunks[0] as Node3D
		fx.update(2.2, 1.0)
		var p1: Vector3 = ch.position
		fx.update(2.2, 0.0)
		_check(ch.position.is_equal_approx(p1), "debris position is a function of story time")
		fx.update(6.0, 1.0)
		_check(ch.position.y > -0.01 and ch.position.y < 0.2, "debris rests on the ground (y %.3f)" % ch.position.y)
	_check(fx.find_children("*", "GPUParticles3D", true, false).is_empty(), "no GPUParticles3D")
	# --- crate break, stars, props, texture
	var crates: Node3D = CineFX.build_prop("crate_stack")
	world.add_child(crates)
	var intact: Array = crates.get_meta("crates", [])
	_check(intact.size() >= 3, "crate stack has >= 3 crates")
	var before_n: int = fx.live_count()
	fx.crate_break(crates, Vector3(-1.0, 0.2, -1.0), 1.0, 8.4)
	var hidden: bool = true
	for c2: Node3D in intact:
		hidden = hidden and not c2.visible
	_check(hidden, "crate break hides the intact crates")
	_check(fx.live_count() >= before_n + 8, "crate break launches >= 8 planks")
	var dummy := Node3D.new()
	world.add_child(dummy)
	fx.stars(dummy, 9.0, 12.0)
	fx.update(10.0, 1.0)
	var star_nodes: Array[Node] = fx.find_children("Star*", "Node3D", true, false)
	_check(star_nodes.size() >= 3 and (star_nodes[0] as Node3D).visible, "three stars orbit during their window")
	fx.update(12.5, 1.0)
	_check(not (star_nodes[0] as Node3D).visible, "stars gone after their window")
	for k: String in ["crate_stack", "scooter", "banana", "phone"]:
		var n: Node3D = CineFX.build_prop(k)
		_check(n != null and not n.find_children("*", "MeshInstance3D", true, false).is_empty(), "prop %s built from code" % k)
		if k == "phone":
			CineFX.set_prop_glow(n, true)
			var scr: StandardMaterial3D = n.get_meta("screen_mat")
			_check(scr.emission_enabled, "phone screen glows")
		n.free()
	var tex: ImageTexture = CineFX.radial_texture(64, 2.0)
	var img: Image = tex.get_image()
	_check(img.get_pixel(32, 32).a > 0.9 and img.get_pixel(1, 1).a < 0.05, "radial texture is code-made (bright centre, clear edge)")
	if fails.is_empty():
		print("✅ SUCCESS: CINE AUDIO + FX (slots, gain, synth cue/sting/sfx, clock-driven FX, props)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
```

Run it. Expected: `Identifier "CineAudio" not declared`.

- [ ] **Step 2: Write `scripts/cine/CineAudio.gd`**

The loader, the gain rule and the paste-based synthesis are complete code below. Voice shapes are free to tune.

```gdscript
# File: res://scripts/cine/CineAudio.gd
# Cinematic audio (spec A1-D13, A1-D14). Music slots: user://music/<slot>.ogg, then .mp3 (owner files, outside the project:
# never committed or exported); without a file a cue is synthesized offline to the exact real length with accents on the
# timeline's real impact times. A longer file fades to silence over the last 0.5 s (music_gain). SFX: user://sfx/<cue>.ogg
# overrides, otherwise the synthesized A1 cues below. Synthesis pastes short precomputed voice tables into one buffer so a
# 25 s cue costs about a million sample adds.
class_name CineAudio
extends RefCounted

const MUSIC_DIR: String = "user://music/"
const SFX_DIR: String = "user://sfx/"
const SR: int = 22050
const FADE_OUT: float = 0.5
const SFX_CUES: Array[String] = ["impact_light", "impact_medium", "impact_heavy", "whoosh_down", "freeze_tick", "crate_smash",
	"body_fall", "slide_whistle", "groan", "phone_buzz"]
const MOODS: Dictionary = {
	"punchy": {"bpm": 118.0, "root": 55.0, "minor": true},
	"heavy": {"bpm": 96.0, "root": 49.0, "minor": true},
	"playful": {"bpm": 124.0, "root": 65.4, "minor": false},
	"eerie": {"bpm": 84.0, "root": 46.2, "minor": true},
}
static var _sfx_cache: Dictionary = {}


static func music_file(slot: String) -> String:
	for ext: String in [".ogg", ".mp3"]:
		var p: String = MUSIC_DIR + slot + ext
		if FileAccess.file_exists(p):
			return p
	return ""


static func load_music(slot: String) -> AudioStream:
	var p: String = music_file(slot)
	if p == "":
		return null
	return _load_file(p)


static func _load_file(p: String) -> AudioStream:
	if p.ends_with(".ogg"):
		return AudioStreamOggVorbis.load_from_file(p)
	if p.ends_with(".mp3"):
		var s := AudioStreamMP3.new()
		s.data = FileAccess.get_file_as_bytes(p)
		return s if s.data.size() > 0 else null
	return null


static func stream_length(st: AudioStream) -> float:
	return st.get_length() if st else 0.0


## Music volume (linear) at real time r for a cinematic of `length` s and a stream of stream_len s (A1-D13).
static func music_gain(r: float, length: float, stream_len: float) -> float:
	if stream_len <= length + 1e-6:
		return 1.0
	if r >= length:
		return 0.0
	return clampf((length - r) / FADE_OUT, 0.0, 1.0)


# ---------------------------------------------------------------------------
# Synthesis helpers
# ---------------------------------------------------------------------------
static func _tone(dur: float, f0: float, f1: float, amp: float, decay: float) -> PackedFloat32Array:
	var n: int = int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph: float = 0.0
	for i: int in n:
		var t: float = float(i) / SR
		var f: float = lerpf(f0, f1, t / dur)
		ph += TAU * f / SR
		out[i] = sin(ph) * amp * exp(-decay * t)
	return out


static func _noise(dur: float, amp: float, decay: float, seed: int, lp: float = 0.0) -> PackedFloat32Array:
	var n: int = int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var prev: float = 0.0
	for i: int in n:
		var v: float = rng.randf_range(-1.0, 1.0)
		prev = lerpf(v, prev, lp)
		out[i] = prev * amp * exp(-decay * float(i) / SR)
	return out


static func _paste(buf: PackedFloat32Array, voice: PackedFloat32Array, at: float, gain: float) -> void:
	var o: int = int(at * SR)
	var n: int = mini(voice.size(), buf.size() - o)
	for i: int in range(maxi(0, -o), n):
		buf[o + i] += voice[i] * gain


static func _to_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i: int in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = data
	return w


static func _in_windows(t: float, hits: Array[Dictionary]) -> bool:
	for h: Dictionary in hits:
		if t >= float(h.get("r_start", h["r"])) and t <= float(h.get("r_end", h["r"])):
			return true
	return false


## Default cue for a slot: tempo grid (kick + bass + hats, ducked to 40 % inside slow-motion windows), 0.3 s riser before
## heavy/finisher impacts, a boom + noise burst on every impact, a tick on every freeze, an outro hit when the 1x tail starts,
## FADE_OUT at the end. Exactly `length` seconds.
static func synth_cue(length: float, hits: Array[Dictionary], mood: String = "punchy") -> AudioStreamWAV:
	var m: Dictionary = MOODS.get(mood, MOODS["punchy"])
	var buf := PackedFloat32Array()
	buf.resize(int(round(length * SR)))
	var beat: float = 60.0 / float(m["bpm"])
	var kick: PackedFloat32Array = _tone(0.22, 120.0, 45.0, 0.55, 14.0)
	var hat: PackedFloat32Array = _noise(0.03, 0.12, 90.0, 7, 0.0)
	var degrees: Array[int] = [0, 0, 3 if bool(m["minor"]) else 4, 5, 7, 5, 3 if bool(m["minor"]) else 4, 0]
	var bass: Dictionary = {}
	for d: int in degrees:
		if not bass.has(d):
			bass[d] = _tone(beat * 0.45, float(m["root"]) * pow(2.0, d / 12.0), float(m["root"]) * pow(2.0, d / 12.0), 0.22, 3.0)
	var t: float = 0.0
	var step: int = 0
	while t < length:
		var g: float = 0.4 if _in_windows(t, hits) else 1.0
		if step % 2 == 0:
			_paste(buf, kick, t, g)
		_paste(buf, bass[degrees[(step / 2) % degrees.size()]], t, g)
		_paste(buf, hat, t + beat * 0.25, g * 0.8)
		t += beat * 0.5
		step += 1
	var boom: PackedFloat32Array = _tone(0.6, 90.0, 40.0, 0.9, 6.0)
	var burst: PackedFloat32Array = _noise(0.12, 0.6, 30.0, 11, 0.2)
	var tick: PackedFloat32Array = _tone(0.05, 2400.0, 2200.0, 0.35, 60.0)
	var riser: PackedFloat32Array = _noise(0.3, 0.25, -6.0, 13, 0.6)
	var last_end: float = 0.0
	for h: Dictionary in hits:
		var r: float = h["r"]
		var pre: String = h.get("preset", "medium")
		var g2: float = {"light": 0.45, "medium": 0.7, "heavy": 1.0, "finisher": 1.0, "accent": 0.3}.get(pre, 0.7)
		if pre == "heavy" or pre == "finisher":
			_paste(buf, riser, r - 0.3, 1.0)
		_paste(buf, boom, r, g2)
		_paste(buf, burst, r, g2)
		if float(h.get("freeze", 0.0)) > 0.0:
			_paste(buf, tick, r, 1.0)
		last_end = maxf(last_end, float(h.get("r_end", r)))
	if last_end > 0.0 and last_end < length - 0.2:
		_paste(buf, boom, last_end, 0.6)
	var nf: int = mini(int(FADE_OUT * SR), buf.size())
	for i: int in nf:
		buf[buf.size() - 1 - i] *= float(i) / float(nf)
	return _to_wav(buf)


## Short replay sting: the cue's voices for `length` s with one heavy impact at r_hit.
static func synth_sting(length: float, r_hit: float) -> AudioStreamWAV:
	var hits: Array[Dictionary] = [{"r": r_hit, "preset": "heavy", "freeze": 0.18, "r_start": r_hit - 0.45, "r_end": r_hit + 1.28}]
	return synth_cue(length, hits, "punchy")


## A1 SFX cue: user://sfx/<cue>.ogg if present, else synthesized (cached).
static func sfx(cue: String) -> AudioStream:
	if _sfx_cache.has(cue):
		return _sfx_cache[cue]
	var st: AudioStream = null
	if FileAccess.file_exists(SFX_DIR + cue + ".ogg"):
		st = _load_file(SFX_DIR + cue + ".ogg")
	if st == null:
		st = _synth_sfx(cue)
	_sfx_cache[cue] = st
	return st


static func _mix(parts: Array) -> PackedFloat32Array:
	var n: int = 0
	for p: PackedFloat32Array in parts:
		n = maxi(n, p.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for p2: PackedFloat32Array in parts:
		for i: int in p2.size():
			out[i] += p2[i]
	return out


static func _synth_sfx(cue: String) -> AudioStreamWAV:
	match cue:
		"impact_light":
			return _to_wav(_mix([_noise(0.08, 0.6, 45.0, 1, 0.3), _tone(0.1, 220.0, 140.0, 0.4, 25.0)]))
		"impact_medium":
			return _to_wav(_mix([_noise(0.14, 0.7, 30.0, 2, 0.4), _tone(0.2, 160.0, 70.0, 0.6, 14.0)]))
		"impact_heavy":
			return _to_wav(_mix([_noise(0.25, 0.8, 16.0, 3, 0.5), _tone(0.5, 110.0, 38.0, 0.9, 6.0)]))
		"whoosh_down":
			return _to_wav(_noise(0.45, 0.4, 4.0, 4, 0.85))
		"freeze_tick":
			return _to_wav(_tone(0.06, 2600.0, 2300.0, 0.4, 50.0))
		"crate_smash":
			return _to_wav(_mix([_noise(0.4, 0.8, 9.0, 5, 0.2), _tone(0.12, 330.0, 180.0, 0.3, 20.0), _tone(0.2, 90.0, 60.0, 0.5, 12.0)]))
		"body_fall":
			return _to_wav(_mix([_tone(0.3, 80.0, 45.0, 0.8, 10.0), _noise(0.1, 0.4, 35.0, 6, 0.6)]))
		"slide_whistle":
			return _to_wav(_tone(0.9, 600.0, 1500.0, 0.35, 0.8))
		"groan":
			return _to_wav(_mix([_tone(0.8, 140.0, 105.0, 0.35, 1.5), _tone(0.8, 280.0, 210.0, 0.12, 1.5)]))
		"phone_buzz":
			var gap := PackedFloat32Array()
			gap.resize(int(0.1 * SR))
			var b := PackedFloat32Array()
			for i: int in 2:
				b.append_array(_tone(0.18, 175.0, 175.0, 0.5, 0.0))
				b.append_array(gap)
			return _to_wav(b)
	return _to_wav(_tone(0.08, 800.0, 800.0, 0.4, 20.0))
```

- [ ] **Step 3: Write `scripts/cine/CineFX.gd`**

Write it to these exact rules. The prototype's particle and star code is a starting point: `git show ec72795:scripts/cine/CineBrawl.gd`, functions `_particles`, `_sparks`, `_dust`, `_star_mesh` and `_update_debris`.

**`radial_texture(size, power)`** (static, cached per argument pair):
- `Image.create(size, size, false, Image.FORMAT_RGBA8)`;
- alpha = `pow(clamp(1 - d, 0, 1), power)`, where `d` = distance from the centre / (size/2);
- RGB white;
- returned as an `ImageTexture`.

**Particle material** (sparks and dust): `StandardMaterial3D` with
- `shading_mode = UNSHADED`;
- `billboard_mode = BILLBOARD_PARTICLES`;
- `vertex_color_use_as_albedo = true`;
- `albedo_texture = radial_texture(64, 2.0)`;
- transparency `ALPHA`;
- sparks only: `blend_mode = BLEND_MODE_ADD`.

The draw mesh is a `QuadMesh` of 1 m.

**`burst("sparks", pos, dir, power, s)`:** a `CPUParticles3D` with
- `one_shot`, `explosiveness = 1`, `emitting = true`;
- `amount = max(8, int(28 · power))`, `lifetime = 0.45`;
- `direction = dir`, `spread = 55°`, velocity 4–9 m/s × power;
- gravity (0, −9.8, 0);
- `scale_amount` 0.035–0.08;
- colour ramp white → `#FFB040` → transparent.

**`burst("dust", …)`:** a `CPUParticles3D` with
- emission shape `RING`, radius 0.35 (inner 0.1), axis Y;
- `direction = (1, 0, 0)`, `spread = 180°`, `flatness = 1`;
- velocity 1.2–2.6 × power, damping 2.5, gravity (0, −0.5, 0), lifetime 1.2;
- `amount = max(8, int(20 · power))`;
- scale 0.3–0.7, growing through `scale_amount_curve`;
- colour `#B9AE9A` with alpha 0.55 → 0.

**`burst("flash", …)`:** a `MeshInstance3D` named `Flash` with
- a `QuadMesh` billboard and an additive unshaded radial-texture material;
- size 1.2 × power;
- driven by story time: alpha 1 → 0 and scale 0.6 → 1.0 over 0.12 story s, then freed.

**Node names.** Every spawned node takes a running serial (`"Debris%d" % _serial`, `"Star%d"`, `"Flash%d"`), so names stay unique and the tests can find them with `find_children("Debris*", "Node3D", true, false)`.

**`burst("debris", …)`:** `max(4, int(8 · power))` nodes named `Debris<serial>`, each a `MeshInstance3D` holding a `BoxMesh` of 0.04–0.12 m. Colours: dark asphalt `#2E2E33` or wood `#8A6A43`. The RNG is seeded from `hash(pos)`, so the result is deterministic.
- **Spawn values:** each chunk stores `p0`; velocity `v = dir.normalized() · U(2, 5) · power + (0, U(2, 4), 0)` plus a random 1 m/s jitter; angular velocity `w` in rad/s; and `s0 = s`.
- **Pure function of `t = s − s0`.** Precompute the first ground contact `tg`, where `y(t) = rest_y = 0.03` (root of `p0.y + v.y·t − 4.9·t² = rest_y`).
  - After `tg`: a second arc with `v' = (0.35·v.x, −0.3·v.y_at_contact, 0.35·v.z)` and contact `tg2`.
  - After `tg2`: rest at `y = rest_y`.
  - Rotation = `w · min(t, tg2)`.
- Positions are in the `CineFX` node's local space; the player parents `CineFX` under the stage.

**`crate_break(prop, dir, power, s)`:**
1. Hides every node in `prop.get_meta("crates")`.
2. Spawns `prop.get_meta("planks", 10)` debris chunks shaped as planks: `BoxMesh` 0.55 × 0.07 × 0.02 in the crate colour, from the crates' global positions, with velocity `dir · U(1.5, 4) · power` plus upward 1.5–3.5.
3. Spawns a dust burst at the stack base.

**`stars(actor, s0, s1)`:** three nodes named `Star<serial>`, each a `MeshInstance3D` with a 5-point star `ArrayMesh` (outer radius 0.07, inner 0.03, depth 0.015) and a yellow emissive unshaded material.
- Each frame: position = `actor.bone_world("Head") + (0, 0.28, 0) + orbit(radius 0.22, angle = 4 rad per story second + i·TAU/3)`.
- Visible only for s in [s0, s1]. When the actor is not a `CineActor`, use `global_position + (0, 1.9, 0)`.

**`update(s, speed)`:**
- Every live `CPUParticles3D` gets `speed_scale = speed / maxf(Engine.time_scale, 0.01)`. Particles therefore freeze in freezes and run slow in slow motion.
- Debris, flash and stars are evaluated at `s`.
- Particles are freed when `s − s0 > lifetime + 2`, and flashes after their 0.12 s.
- Debris chunks stay at rest on the ground until the `CineFX` node is freed: they are part of the aftermath.
- Stars are hidden outside their window, not freed.

**`live_count()`:** the number of live particle systems, debris chunks, flashes and stars.

**Props** (`build_prop`, all plain code meshes and colours):
- `crate_stack`: three crates of 0.62 m (two on the ground, one on top, slightly rotated), wood `#9A7448` with darker `#6E5232` edge boxes. Meta `crates` = the three crate nodes, `planks` = 10.
- `scooter`: about 1.8 m long. A box body, two cylinder wheels (r 0.22), a seat, handlebars and an unbranded teal delivery box (0.45 m) on the back.
- `banana`: three thin yellow capsules splayed on the ground, about 0.18 m.
- `phone`: a black box 0.075 × 0.008 × 0.15 with a screen quad. Meta `screen_mat` = a `StandardMaterial3D` with `emission_enabled = false` and emission colour `#BFE3FF`.

**`set_prop_glow(prop, on)`:** sets `screen_mat.emission_enabled = on` and `emission_energy_multiplier = 2.0`.

- [ ] **Step 4: Import, run the test until it passes**

```bash
godot --headless --import --path . > /tmp/a1_imp.log 2>&1; grep -c "CineAudio\|CineFX" .godot/global_script_class_cache.cfg
git diff --name-only -- '*.import' | xargs -r git checkout --
godot --headless --path . --script tests/test_cine_audio_fx.gd > /tmp/t4.log 2>&1; grep -E "SUCCESS|FAILED|✗" /tmp/t4.log
```

Expected: `✅ SUCCESS: CINE AUDIO + FX (…)`.

- [ ] **Step 5: Full regression, then commit**

```bash
git add scripts/cine/CineAudio.gd scripts/cine/CineAudio.gd.uid scripts/cine/CineFX.gd scripts/cine/CineFX.gd.uid tests/test_cine_audio_fx.gd tests/test_cine_audio_fx.gd.uid
git commit -m "feat(cine): music slot loader with exact-length synthesized default cue and fade rule, A1 SFX bank, clock-driven code-built impact FX and set-dressing props

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Cinematic player, camera rigs, overlay and FreeRoam integration  [effort: xhigh]

**Files:**
- Create:
  - `scripts/cine/CineShots.gd`, `scripts/cine/CineOverlay.gd`, `scripts/cine/CinePlayer.gd`;
  - `scripts/cine/CinePreview.gd`, `scenes/dev/CinePreview.tscn`;
  - `tests/test_cine_player.gd`.
- Modify: `scripts/StageManager.gd` (`cinematic_active`), `scripts/FreeRoam.gd` (cinematic hosting and F9).

**Interfaces:**
- Consumes:
  - Tasks 1-4;
  - `FreeRoam`: `md`, `player`, `bike`, `pedestrians`, `traffic`, `set_time_of_day()`, `tod_preset`, `flash_hint()`, `roam_position()`, and the HUD holders `hint_holder`, `tod_holder`, `stats_holder`, `vice_hud`, `stamina_bar`.
- Produces (`class_name CineShots`, static):
  - `eval(shot: Dictionary, u: float, ctx: Dictionary) -> {"pos": Vector3, "look": Vector3, "fov": float}`, in stage space;
  - `whip(r, shot_r0, shot_r1, rows: Array[Dictionary], enabled := true) -> {"yaw": float (deg), "fov": float, "shake": Vector3}`.
- Produces (`class_name CineOverlay extends CanvasLayer`):
  - `set_letterbox(f)`, `set_fade(a)`;
  - `show_sub(speaker, color, text, tr)`, `hide_sub()`;
  - `set_skip(progress)` (< 0 hides), `set_tag(text)`;
  - `set_debug(on)`, `update_debug(text, beats: PackedFloat32Array, length, r)`;
  - accessors `letterbox_fraction()`, `fade_alpha()`, `sub_visible()`, `sub_text()`, `debug_text()`.
- Produces (`class_name CinePlayer extends Node3D`):
  - `signal finished(skipped: bool)`;
  - `setup(tl, stage_xf := Transform3D.IDENTITY, opts := {}) -> PackedStringArray`, opts `{manual, debug}`;
  - `start()`, `step(dt)`, `seek(r)`, `is_ready() -> bool`;
  - `set_debug(on)`;
  - state: `r`, `s`, `current_shot`, `actors`, `prop_nodes`, `camera`, `overlay`, `fx`, `music`;
  - test hook `force_skip_hold`;
  - stats `frame_ms_total`, `frames`.
- Produces (`FreeRoam`):
  - `signal cinematic_finished(slot: String, skipped: bool)`;
  - `cine_stage(stage: Dictionary) -> Variant` (`Transform3D` or `null`);
  - `play_cinematic(tl: CineTimeline, opts := {}) -> CinePlayer`;
  - `_play_next_cinematic() -> CinePlayer`;
  - `cine_player`.
- Produces (`StageManager`): `var cinematic_active: bool`. While it is true, `_can_pause()` returns false.

- [ ] **Step 1: Write the failing test `tests/test_cine_player.gd`**

```gdscript
# File: res://tests/test_cine_player.gd
# Headless test of CinePlayer with the 6 s test timeline. Part A, empty world: refuses an invalid timeline; plays exactly
# 6.000 s (360 manual steps of 1/60); music starts on the first frame; letterbox, fades, subtitle with its Dịch line, shots
# switch by story time; the clock ignores Engine.time_scale; hold-Esc skip; debug overlay; frame cost.
# Part B, FreeRoam (crowd off): stage found near the west gate, play_cinematic pauses the tree, hides the player and
# restores everything when done.
# Run:  godot --headless --path . --script tests/test_cine_player.gd
extends SceneTree

const TL_SCRIPT: String = "res://tests/support/cine_test_timeline.gd"
var fails: Array[String] = []
var phase: int = 0
var frames: int = 0
var world: Node3D
var fr: Node
var p: CinePlayer
var finished_args: Array = []
var real_t0: int = 0
var r0: float = 0.0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _tl() -> CineTimeline:
	var tl: CineTimeline = (load(TL_SCRIPT) as GDScript).new()
	tl.build()
	return tl


func _on_finished(skipped: bool) -> void:
	finished_args.append(skipped)


func _initialize() -> void:
	print("--- TEST CINE PLAYER ---")
	world = Node3D.new()
	root.add_child(world)
	var bad: CineTimeline = _tl()
	bad.story_end = 4.0
	var pb := CinePlayer.new()
	world.add_child(pb)
	_check(not pb.setup(bad).is_empty() and pb.actors.is_empty(), "invalid timeline refused, nothing built")
	pb.queue_free()
	p = CinePlayer.new()
	world.add_child(p)
	_check(p.setup(_tl(), Transform3D.IDENTITY, {"manual": true}).is_empty(), "test timeline sets up")
	p.finished.connect(_on_finished)
	p.start()


func _process(_d: float) -> bool:
	frames += 1
	match phase:
		0:   # wait for the synthesized cue (worker thread)
			if p.is_ready():
				phase = 1
			elif frames > 600:
				_check(false, "music never became ready")
				return _end()
		1:
			var steps: int = 0
			var saw_sub: bool = false
			var saw_dich: bool = false
			while finished_args.is_empty() and steps < 400:
				p.step(1.0 / 60.0)
				steps += 1
				if steps == 1:
					_check(p.music.playing, "music starts on the first frame")
					_check(p.overlay.fade_alpha() > 0.9, "starts black")
				if steps == 12:
					_check(p.overlay.letterbox_fraction() > 0.3 and p.overlay.letterbox_fraction() < 0.7, "letterbox sliding in at 0.2 s")
				if steps == 30:
					_check(p.overlay.fade_alpha() < 0.05 and is_equal_approx(p.overlay.letterbox_fraction(), 1.0), "faded in, bars in place at 0.5 s")
				if steps == 60:
					_check(p.current_shot == "S1", "shot S1 at 1.0 s (got %s)" % p.current_shot)
				if steps == 120:
					_check(p.current_shot == "S2", "shot S2 at 2.0 s (got %s)" % p.current_shot)
					_check(absf(p.s - p.timeline.clock.story_at(2.0)) < 1e-4, "story time = clock.story_at(r)")
				if steps == 210:
					saw_sub = p.overlay.sub_visible()
					saw_dich = p.overlay.sub_text().contains("Dịch:")
				if steps == 300:
					_check(not p.overlay.sub_visible(), "subtitle hidden after its window")
				if steps == 345:
					_check(absf(p.overlay.fade_alpha() - 0.5) < 0.1, "fading out over the last 0.5 s")
			_check(saw_sub and saw_dich, "Anh Duy subtitle with its Dịch line at 3.5 s")
			_check(absi(steps - 360) <= 1, "plays exactly 6.000 s (%d steps of 1/60)" % steps)
			_check(finished_args == [false], "finished(false) once")
			_check(p.frame_ms_total / maxf(float(p.frames), 1.0) < 8.0, "frame update %.2f ms < 8" % (p.frame_ms_total / maxf(float(p.frames), 1.0)))
			p.queue_free()
			# real-time clock ignores Engine.time_scale
			Engine.time_scale = 0.5
			p = CinePlayer.new()
			world.add_child(p)
			p.setup(_tl())
			p.start()
			real_t0 = 0
			phase = 2
		2:
			if real_t0 == 0:
				if p.is_ready() and p.r > 0.0:
					real_t0 = Time.get_ticks_msec()
					r0 = p.r
					frames = 0
			elif frames > 40:
				var real_s: float = float(Time.get_ticks_msec() - real_t0) / 1000.0
				_check(real_s > 0.2 and absf((p.r - r0) - real_s) < 0.1, "r follows real time with time_scale 0.5 (dr %.2f, real %.2f)" % [p.r - r0, real_s])
				Engine.time_scale = 1.0
				p.queue_free()
				# hold-Esc skip
				finished_args.clear()
				p = CinePlayer.new()
				world.add_child(p)
				p.setup(_tl(), Transform3D.IDENTITY, {"manual": true})
				p.finished.connect(_on_finished)
				p.start()
				phase = 3
		3:
			if p.is_ready():
				p.set_debug(true)
				p.step(1.0 / 60.0)
				_check(p.overlay.debug_text().contains("r=") and p.overlay.debug_text().contains("s="), "debug overlay shows r and s")
				p.force_skip_hold = true
				var n: int = 0
				while finished_args.is_empty() and n < 200:
					p.step(1.0 / 60.0)
					n += 1
				_check(finished_args == [true], "hold Esc skips (finished(true))")
				_check(n >= 60 and n <= 70, "skip after 0.8 s hold + 0.25 s fade (%d steps)" % n)
				p.queue_free()
				phase = 4
				frames = 0
		4:   # Part B: FreeRoam
			var ps: PackedScene = load("res://scenes/FreeRoam.tscn")
			fr = ps.instantiate()
			fr.set("crowd_enabled", false)
			root.add_child(fr)
			phase = 5
			frames = 0
		5:
			if frames < 3:
				return false
			var tl: CineTimeline = _tl()
			var xf: Variant = fr.call("cine_stage", tl.stage)
			_check(xf is Transform3D, "clear stage found near the west gate")
			if xf is Transform3D:
				var lm: Array = fr.get("md").landmark("campus_west_gate")
				var d: float = Vector2((xf as Transform3D).origin.x - float(lm[0]), (xf as Transform3D).origin.z - float(lm[1])).length()
				_check(d < 40.0, "stage within 40 m of the landmark (%.1f m)" % d)
			var tod0: String = fr.get("tod_preset")
			finished_args.clear()
			var cp: CinePlayer = fr.call("play_cinematic", tl, {"manual": true})
			_check(cp != null, "play_cinematic returns the player")
			if cp == null:
				return _end()
			cp.finished.connect(_on_finished)
			_check(paused, "tree paused during the cinematic")
			_check(not (fr.get("player") as Node3D).visible, "roam player hidden")
			while not cp.is_ready():
				OS.delay_msec(20)
			var n2: int = 0
			while finished_args.is_empty() and n2 < 400:
				cp.step(1.0 / 60.0)
				n2 += 1
			_check(not paused, "tree unpaused after the cinematic")
			_check((fr.get("player") as Node3D).visible, "roam player visible again")
			_check(fr.get("tod_preset") == tod0, "time of day restored")
			_check(fr.get("cine_player") == null, "player slot cleared")
			if CineTimeline.slots().is_empty():
				_check(fr.call("_play_next_cinematic") == null, "F9 with no timelines is a no-op")
			return _end()
	return false


func _end() -> bool:
	if fails.is_empty():
		print("✅ SUCCESS: CINE PLAYER (exact length, overlay, shots, real clock, skip, FreeRoam hosting)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true
```

**`is_ready()` in a busy-wait.** The `while not cp.is_ready()` loop polls the worker-thread task and must not depend on the scene tree. `is_ready()` calls `WorkerThreadPool.is_task_completed`.

Run it. Expected: `Identifier "CinePlayer" not declared`.

- [ ] **Step 2: `StageManager.cinematic_active`**

In `scripts/StageManager.gd`, next to `var hub_key_blocked`, add:

```gdscript
var cinematic_active: bool = false   # cinematic / replay đang chạy: ESC là "giữ để bỏ qua", không mở menu tạm dừng (spec A1-D16)
```

Make the first line of `_can_pause()` read `if cinematic_active: return false`. Write it with the file tools, since the comment is Vietnamese.

- [ ] **Step 3: Write `scripts/cine/CineShots.gd` (complete)**

```gdscript
# File: res://scripts/cine/CineShots.gd
# Camera rigs of the cinematic player (spec A1-D11). eval() returns the camera of a shot at REAL progress u (0..1) inside the
# shot, so bullet-time orbits keep moving through freezes; positions are stage-local. whip() adds the whip-pan (yaw pulse),
# FOV punch and freeze shake of every impact inside the shot. Rig params:
#   static   pos, look, fov                  dolly / crane  from, to, look_from, look_to, fov (crane eases out)
#   orbit    center | center_actor (+center_y), radius, deg_from, deg_to, height | height_from..height_to, fov
#            (camera at center + (sin a·r, 0, cos a·r), y = height; constant angular speed)
#   low_hero actor, side_deg, dist, fov      (0.25 m above ground in front-side of the actor, looking up at its chest)
#   track    actor, offset, look (offset from the actor or from look_actor), fov
class_name CineShots
extends RefCounted

const WHIP_DEG: Dictionary = {"light": 6.0, "medium": 9.0, "heavy": 12.0, "finisher": 12.0, "accent": 4.0}
const FOV_PUNCH: Dictionary = {"light": -2.0, "medium": -4.0, "heavy": -7.0, "finisher": -8.0, "accent": 0.0}


static func _apos(ctx: Dictionary, id: String) -> Vector3:
	var a: Node3D = (ctx["actors"] as Dictionary).get(id)
	return a.position if a else Vector3.ZERO


static func eval(shot: Dictionary, u: float, ctx: Dictionary) -> Dictionary:
	var p: Dictionary = shot["params"]
	var e: float = u * u * (3.0 - 2.0 * u)
	var fov: float = float(p.get("fov", 50.0))
	match String(shot["rig"]):
		"static":
			return {"pos": p["pos"], "look": p["look"], "fov": fov}
		"dolly", "crane":
			var ee: float = e if String(shot["rig"]) == "dolly" else 1.0 - (1.0 - u) * (1.0 - u)
			return {"pos": (p["from"] as Vector3).lerp(p["to"], ee), "look": (p["look_from"] as Vector3).lerp(p["look_to"], ee), "fov": fov}
		"orbit":
			var c: Vector3 = p["center"] if p.has("center") else _apos(ctx, String(p["center_actor"])) + Vector3(0.0, float(p.get("center_y", 1.2)), 0.0)
			var a: float = deg_to_rad(lerpf(float(p["deg_from"]), float(p["deg_to"]), u))
			var h: float = float(p["height"]) if p.has("height") else lerpf(float(p.get("height_from", 1.2)), float(p.get("height_to", 1.2)), e)
			var r: float = p["radius"]
			return {"pos": Vector3(c.x + sin(a) * r, h, c.z + cos(a) * r), "look": c, "fov": fov}
		"low_hero":
			var act: Node3D = (ctx["actors"] as Dictionary).get(String(p["actor"]))
			var ap: Vector3 = act.position if act else Vector3.ZERO
			var yaw: float = (act.rotation.y if act else 0.0) + deg_to_rad(float(p.get("side_deg", 30.0)))
			var dir := Vector3(-sin(yaw), 0.0, -cos(yaw))
			var dist: float = float(p.get("dist", 2.2)) * (1.0 - 0.1 * e)
			return {"pos": ap + dir * dist + Vector3(0.0, 0.25, 0.0), "look": ap + Vector3(0.0, 1.25, 0.0), "fov": fov}
		"track":
			var base: Vector3 = _apos(ctx, String(p["actor"]))
			var look_base: Vector3 = _apos(ctx, String(p["look_actor"])) if p.has("look_actor") else base
			return {"pos": base + (p["offset"] as Vector3), "look": look_base + (p.get("look", Vector3(0.0, 1.2, 0.0)) as Vector3), "fov": fov}
	return {"pos": Vector3(0.0, 2.0, 5.0), "look": Vector3.ZERO, "fov": fov}


## Whip-pan of the impacts inside [shot_r0, shot_r1): yaw pulse (deg, alternating sides), FOV punch, freeze shake (m).
static func whip(r: float, shot_r0: float, shot_r1: float, rows: Array[Dictionary], enabled: bool = true) -> Dictionary:
	var out: Dictionary = {"yaw": 0.0, "fov": 0.0, "shake": Vector3.ZERO}
	if not enabled:
		return out
	var side: float = 1.0
	for row: Dictionary in rows:
		var rh: float = row["r_hit"]
		if rh < shot_r0 or rh >= shot_r1:
			continue
		var dt: float = r - rh
		var pre: String = row["preset"]
		if dt > -0.15 and dt < 0.3:
			out["yaw"] = float(out["yaw"]) + side * float(WHIP_DEG.get(pre, 6.0)) * exp(-pow(dt / 0.06, 2.0))
		if dt >= 0.0 and dt < 0.8:
			out["fov"] = float(out["fov"]) + float(FOV_PUNCH.get(pre, 0.0)) * exp(-dt / 0.25)
		var fr: float = row["freeze"]
		if dt >= 0.0 and dt <= fr:
			var amp: float = 0.012 if pre == "light" else 0.02
			out["shake"] = Vector3(sin(r * 97.0), sin(r * 131.0 + 1.3), 0.0) * amp
		side = -side
	return out
```

- [ ] **Step 4: Write `scripts/cine/CineOverlay.gd`**

A `CanvasLayer` with layer 110 and `process_mode = PROCESS_MODE_ALWAYS`. Build these controls in `_init`/`_ready`:

**Letterbox bars:** two `ColorRect`s, colour `#000000`. Each frame (`_process`), size them from the viewport so the picture is 2.39:1. With a 1280×720 viewport, each bar is `(720 − 1280/2.39)/2 ≈ 92` px. Scale the bar height by the letterbox fraction `f`, so they slide in from the edges.

**Fade:** a full-rect black `ColorRect`, with `modulate.a` = fade alpha.

**Subtitles:** a bottom-centre `VBoxContainer`, inside the bottom bar area and above it by 8 px.
- A `RichTextLabel` with BBCode, `fit_content`, font size 26: `[color=#RRGGBB]Speaker:[/color] text`.
- A `Label` for the translation: size 20, colour `#D8D8D8`, the text exactly as given (it starts with "Dịch:"). Hidden when empty.
- `sub_text()` returns `speaker: text` plus, when present, `\n` and the translation line.

**Skip bar:** at top right, a `Label` "Giữ ESC để bỏ qua" and a 120 px `ProgressBar` (0..1, no percentage).

**Tag:** a top-left `Label`, size 22, colour `#FFD84A`, empty by default (the replay sets "▶ REPLAY").

**Debug:**
- a `Label` (monospace system font size 14, colour `#9CFF9C`) at top left under the tag, showing `debug_text()`;
- a `Control` strip (full width, 14 px, above the bottom bar) whose `_draw` paints a dark band, a white tick per beat time and a red playhead at `r/length`.

**Fonts:** when `get_node_or_null("/root/GameFX")` exists, use its `vice_font()` in vice style (`GameFX.is_vice_ui()`) for the subtitle and tag. Otherwise use the default font. Every accessor named in the interface returns the live value.

- [ ] **Step 5: Write `scripts/cine/CinePlayer.gd`**

Complete structure and behaviour below. Keep the names: tests and Task 7 use them.

```gdscript
# File: res://scripts/cine/CinePlayer.gd
# Plays one CineTimeline (spec section 9): builds the actors (real game models) under a stage node placed at stage_xf, the
# props, a Camera3D, the overlay, the FX node and the audio players; music (owner file or synthesized cue built on a worker
# thread) starts on the first frame; every frame: r (REAL, from Time.get_ticks_usec or step(dt), never Engine.time_scale)
# -> s = clock.story_at(r) -> actors, story-time events (SFX, FX, prop glow), FX speed, camera (shot at real progress +
# whip), overlay (letterbox, fades, subtitle at r, skip bar, debug), music gain. Ends at r = length (exact) or after a
# hold-Esc skip; emits finished(skipped). PROCESS_MODE_ALWAYS: runs while the host pauses the tree.
class_name CinePlayer
extends Node3D

signal finished(skipped: bool)

const ESC_HOLD: float = 0.8
const SKIP_FADE: float = 0.25
const LETTERBOX_IN: float = 0.4
const SFX_POOL: int = 6
const AUTO_SFX: Dictionary = {"light": "impact_light", "medium": "impact_medium", "heavy": "impact_heavy", "finisher": "impact_heavy"}

var timeline: CineTimeline
var stage_xf: Transform3D = Transform3D.IDENTITY
var manual: bool = false
var force_skip_hold: bool = false
var debug: bool = false
var r: float = 0.0
var s: float = 0.0
var current_shot: String = ""
var stage: Node3D
var camera: Camera3D
var overlay: CineOverlay
var fx: CineFX
var actors: Dictionary = {}
var prop_nodes: Dictionary = {}
var music: AudioStreamPlayer
var music_len: float = 0.0
var frame_ms_total: float = 0.0
var frames: int = 0
var _sfx: Array[AudioStreamPlayer] = []
var _sfx_i: int = 0
var _events: Array[Dictionary] = []
var _ev_i: int = 0
var _rows: Array[Dictionary] = []
var _beats := PackedFloat32Array()
var _shot_r: PackedFloat32Array = []      # real start of each shot
var _task: int = -1
var _synth: AudioStreamWAV = null
var _music_ready: bool = false
var _playing: bool = false
var _done: bool = false
var _seeking: bool = false
var _hold: float = 0.0
var _skipping: float = -1.0
var _last_us: int = 0
```

The functions, in order, with exact behaviour:

**`setup(tl, xf, opts) -> PackedStringArray`:**
1. `errs = tl.validate()`. If it is not empty, `push_error` with the slot and errors, build nothing, and return `errs`.
2. Otherwise store `timeline`, `stage_xf` and `manual = opts.manual`. Set `debug = opts.get("debug", OS.get_environment("CINE_DEBUG") == "1")` and `process_mode = PROCESS_MODE_ALWAYS`.
3. Create `stage` (a `Node3D` named "Stage", `transform = xf`) as a child.
4. For each actor id: `CineActor.new()`, name = id, `stage.add_child`, `setup(opts)`, `display_name = name`. Store it in `actors`.
5. For each prop: `CineFX.build_prop(kind, opts)`, position and yaw (degrees to radians), `stage.add_child`. Store it in `prop_nodes`.
6. `_dispatch_cues()`.
7. Create `fx = CineFX.new()` under `stage`, `camera` (`near 0.05`, `far 800`) and `overlay` (with `set_debug(debug)`).
8. Create `music` (bus "Music") and `SFX_POOL` SFX players (bus "SFX").
9. `_rows = tl.clock.beat_rows()`. Fill `_beats` with each row's `r_hit` and `_shot_r` with `tl.clock.real_at(shot.s)` per shot.
10. `_build_events()`, then `_prepare_music()`.
11. `_seeking = true; _update(0.0); _seeking = false; overlay.set_fade(1.0)`.
12. Return `[]`.

**`_dispatch_cues()`:** for each `timeline.cues` entry, call the actor:
- `move`: `a.move(s, move, opts)`;
- `strike`: `a.strike(timeline.story_time(at), move, opts)`;
- `key`: `a.key(s, pos, deg_to_rad(yaw), opts.spin (deg Vector3) × PI/180, opts.mode ("smooth"), opts.arc (0))`;
- `expr`: `a.expr(s, cell)`;
- `look`: `a.look(s, s1, actors[target] if target is String else target)`. A `Vector3` target is stage-local, and `CineActor` uses its parent's (the stage's) `to_global`.
- `show`: `a.show_at(s, on)`.

**`_build_events()`:** build a story-time list sorted by `s`.
- From `timeline.sfx`: `{s: story_time(at), kind: "sfx", cue, db}`.
- From `timeline.fx`: `{s, kind: "fx", fx: <the entry>}`.
- From props with `opts.glow_at`: `{s, kind: "glow", id}`.
- Automatic, per ramp:
  - `whoosh_down` at the ramp's `s0` for heavy and finisher;
  - `AUTO_SFX[preset]` at `s` for impact presets;
  - `freeze_tick` at `s` when `freeze > 0`.

**`_prepare_music()`:**
1. `st = CineAudio.load_music(timeline.music_slot if non-empty else timeline.slot)`.
2. With a file: `music.stream = st`, `music_len = CineAudio.stream_length(st)`, `_music_ready = true`.
3. Without one: build `hits` from `_rows` (`{r: r_hit, preset, freeze, r_start, r_end}`) and capture `L` and `mood` in locals. Start `_task = WorkerThreadPool.add_task(func() -> void: _synth = CineAudio.synth_cue(L, hits, mood))`.

**`is_ready() -> bool`:** `_poll_music()`, then return `_music_ready`.

**`_poll_music()`:** if `_task >= 0` and `WorkerThreadPool.is_task_completed(_task)`:
1. `WorkerThreadPool.wait_for_task_completion(_task)`, then `_task = -1`.
2. `music.stream = _synth`, `music_len = timeline.length`, `_music_ready = true`.

**`start()`:** `_playing = true`, `_last_us = Time.get_ticks_usec()`, `r = 0`, `_set_flag(true)`, `camera.make_current()`.

**`_process(_d)`:** if not `manual` and `_playing` and not `_done`:
1. `now = Time.get_ticks_usec()`, `dt = (now − _last_us)/1e6`, `_last_us = now`.
2. While the music is not ready, call `_poll_music()`, keep `r = 0` and return. This is the fade-in hold: the screen stays black.
3. Otherwise `step(minf(dt, 0.1))`.

**`step(dt)`:**
1. Return if `_done`. If the music is not ready: `_poll_music()`; if it is still not ready, return.
2. If `r == 0` and not `music.playing` and `music.stream`: `music.play()`.
3. `t0 = Time.get_ticks_usec()`, `_skip_logic(dt)`, `r = minf(r + dt, timeline.length)`, `_update(r)`.
4. Add the elapsed ms to `frame_ms_total`; `frames += 1`.
5. If `r >= timeline.length − 1e-9` or (`_skipping >= SKIP_FADE`): `_finish(_skipping >= 0.0)`.

**`seek(rr)`** (debug and tests): `r = rr`; set `_ev_i` to the first event with `s > story_at(rr)`; `_seeking = true; _update(rr); _seeking = false`.

**`_update(rr)`:**
1. `s = clock.story_at(rr)`, `speed = clock.speed_at(rr)`.
2. `a.evaluate(s)` for every actor.
3. If not `_seeking`: `_fire_events(s)`.
4. `fx.update(s, speed)`, `_update_camera(rr)`, `_update_overlay(rr)`.
5. If `music.stream`: `music.volume_db = linear_to_db(maxf(CineAudio.music_gain(rr, timeline.length, music_len), 0.0001))`.

**`_fire_events(s)`:** while `_ev_i < size` and `_events[_ev_i].s <= s + 1e-9`, handle the event and advance:
- `sfx`: `_play_sfx(cue, db)` on the next pool player (`stream = CineAudio.sfx(cue)`).
- `fx`: resolve `where`:
  - `"id:Bone"` → `actors[id].bone_world(Bone)`;
  - `"id"` → the actor (stars) or prop (crate);
  - `Vector3` → `stage.to_global`.

  `dir` = `stage.global_transform.basis * params.get("dir", Vector3(0, 0.6, 0))`, `power = params.get("power", 1.0)`. Then:
  - `crate` → `fx.crate_break(prop, dir, power, s)`;
  - `stars` → `fx.stars(actor, s, params.get("until", s + 4.0))`;
  - otherwise → `fx.burst(kind, pos, dir, power, s)`. `fx` is under `stage`, so convert `pos` with `fx.to_local(pos)` inside `CineFX` when storing `p0`.
- `glow`: `CineFX.set_prop_glow(prop_nodes[id], true)`.

**`_update_camera(rr)`:**
1. Shot index `i` = the last shot with `shot.s <= s`; `current_shot = shot.id`.
2. `r0 = _shot_r[i]`; `r1 = _shot_r[i+1]`, or `timeline.length` for the last shot; `u = clampf((rr − r0)/maxf(r1 − r0, 0.001), 0, 1)`.
3. `c = CineShots.eval(shot, u, {"actors": actors})` and `w = CineShots.whip(rr, r0, r1, _rows, shot.params.get("whip", true))`.
4. World values: `pos_w = stage_xf * (c.pos + w.shake)`, `look_w = stage_xf * c.look`.
5. If `(look_w − pos_w).length() > 0.01`, set `camera.global_transform = Transform3D(Basis.looking_at(look_w − pos_w, Vector3.UP), pos_w)`. Then rotate the basis about world `Vector3.UP` by `deg_to_rad(w.yaw)`.
6. `camera.fov = c.fov + w.fov`.

**`_update_overlay(rr)`:**
1. `overlay.set_letterbox(clampf(rr / LETTERBOX_IN, 0, 1) if timeline.letterbox else 0.0)`.
2. Fade alpha = the maximum of:
   - fade-in, `1 − rr/fade_in` (when `fade_in > 0`);
   - fade-out, `(rr − (length − fade_out))/fade_out` (when `fade_out > 0`);
   - skip, `_skipping/SKIP_FADE`;

   clamped to 0..1.
3. Subtitle: the first `sub` with `r ≤ rr < r + dur` → `overlay.show_sub(timeline.speaker_name(speaker), actor colour or WHITE, text, tr)`; none → `hide_sub()`.
4. `overlay.set_skip(_hold / ESC_HOLD if _hold > 0.0 and _skipping < 0.0 else -1.0)`.
5. If `debug`: `overlay.update_debug("r=%.3f  s=%.3f  x%.2f  shot %s  next %s" % [rr, s, speed, current_shot, <name and real time of the next ramp>], _beats, length, rr)`.

**`_skip_logic(dt)`:**
- If `_skipping >= 0`: `_skipping += dt`, then return.
- Otherwise `held = force_skip_hold or Input.is_physical_key_pressed(KEY_ESCAPE)`; `_hold = _hold + dt if held else 0.0`; if `_hold >= ESC_HOLD`: `_skipping = 0.0`.

**`_finish(skipped)`:** `_done = true; _playing = false; music.stop(); _set_flag(false); finished.emit(skipped)`. The host frees the player.

**`_set_flag(on)`:** `var sm := get_node_or_null("/root/StageManager"); if sm: sm.set("cinematic_active", on)`.

**`set_debug(on)`:** `debug = on; overlay.set_debug(on)`.

**`_unhandled_input(event)`:** F10 pressed → `set_debug(not debug)` and mark the event handled.

- [ ] **Step 6: FreeRoam hosting and F9**

Add to `scripts/FreeRoam.gd`. Write it with the file tools: the hint text is Vietnamese. Also add one line to the file's header comment: `#   - Cinematic (spec A1): cine_stage() / play_cinematic(); [F9] (bản debug) phát lần lượt các timeline.`

```gdscript
signal cinematic_finished(slot: String, skipped: bool)

var cine_player: CinePlayer = null
var _cine_saved: Dictionary = {}
var _cine_slot_i: int = -1


## Clear, flat stage frame for a cinematic near a landmark (spec A1-D19). stage: {"landmark", "near" (m), "size" (Vector2 m),
## "yaw_deg" (preferred), "fallback" (second landmark)}. Rings every 2 m out to `near`, 4 yaws (box symmetric), floor = 5
## downward rays agreeing within 0.15 m, box (size.x × 1.8 × size.y) 0.25 m above the floor must touch nothing except the
## player, the bike, pedestrians and traffic. Returns Transform3D (origin on the floor) or null.
func cine_stage(stage: Dictionary) -> Variant:
	var size: Vector2 = stage.get("size", Vector2(14.0, 10.0))
	var near: float = float(stage.get("near", 30.0))
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, 1.8, size.y)
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var excl: Array[RID] = _cine_exclusions()
	var names: Array[String] = [String(stage.get("landmark", ""))]
	if stage.has("fallback"):
		names.append(String(stage["fallback"]))
	for lk: String in names:
		var lm: Variant = md.landmark(lk)
		if not (lm is Array and (lm as Array).size() >= 2):
			continue
		var c := Vector2(float(lm[0]), float(lm[1]))
		var ring: float = 0.0
		while ring <= near:
			var steps: int = 1 if ring == 0.0 else int(ceil(TAU * ring / 2.0))
			for i: int in steps:
				var a: float = TAU * float(i) / float(steps)
				var pt: Vector2 = c + Vector2(cos(a), sin(a)) * ring
				for yi: int in 4:
					var yaw: float = deg_to_rad(float(stage.get("yaw_deg", 0.0)) + 45.0 * float(yi))
					var xf: Variant = _cine_try(space, box, excl, pt, yaw, size)
					if xf != null:
						return xf
			ring += 2.0
	return null


func _cine_try(space: PhysicsDirectSpaceState3D, box: BoxShape3D, excl: Array[RID], pt: Vector2, yaw: float, size: Vector2) -> Variant:
	var basis := Basis(Vector3.UP, yaw)
	var ys: Array[float] = []
	for o: Vector2 in [Vector2.ZERO, Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5)]:
		var off: Vector3 = basis * Vector3(o.x * size.x, 0.0, o.y * size.y)
		var q := PhysicsRayQueryParameters3D.create(Vector3(pt.x, 20.0, pt.y) + off, Vector3(pt.x, -5.0, pt.y) + off)
		q.exclude = excl
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			return null
		ys.append((hit["position"] as Vector3).y)
	if ys.max() - ys.min() > 0.15:
		return null
	var sq := PhysicsShapeQueryParameters3D.new()
	sq.shape = box
	sq.transform = Transform3D(basis, Vector3(pt.x, ys[0] + 0.25 + 0.9, pt.y))
	sq.exclude = excl
	if not space.intersect_shape(sq, 1).is_empty():
		return null
	return Transform3D(basis, Vector3(pt.x, ys[0], pt.y))


func _cine_exclusions() -> Array[RID]:
	var out: Array[RID] = []
	if player:
		out.append(player.get_rid())
	if bike:
		out.append(bike.get_rid())
	if pedestrians:
		for p: Node in pedestrians.pedestrians():
			if p is CollisionObject3D:
				out.append((p as CollisionObject3D).get_rid())
	if traffic:
		for b: Node in traffic.bodies():
			if b is CollisionObject3D:
				out.append((b as CollisionObject3D).get_rid())
	return out


## Play a cinematic at its stage: pauses the game (game clock frozen), hides the roam player / bike / HUD / crowd / traffic,
## switches the time of day, and restores everything on finished. opts go to CinePlayer.setup (manual, debug).
func play_cinematic(tl: CineTimeline, opts: Dictionary = {}) -> CinePlayer:
	if tl == null or cine_player != null:
		return null
	var xf: Variant = cine_stage(tl.stage) if not tl.stage.is_empty() else Transform3D(Basis.IDENTITY, roam_position())
	if xf == null:
		flash_hint("Không tìm được chỗ trống để diễn cinematic %s" % tl.slot)
		return null
	var p := CinePlayer.new()
	p.name = "CinePlayer"
	add_child(p)
	if not p.setup(tl, xf, opts).is_empty():
		p.queue_free()
		return null
	_cine_saved = {"tod": tod_preset, "vis": {}, "proc": {}}
	for n: Node in [player, bike, hint_holder, tod_holder, stats_holder, vice_hud, stamina_bar, pedestrians, traffic]:
		if n and "visible" in n:
			_cine_saved["vis"][n] = n.visible
			n.visible = false
	for n2: Node in [pedestrians, traffic]:
		if n2:
			_cine_saved["proc"][n2] = n2.process_mode
			n2.process_mode = Node.PROCESS_MODE_DISABLED
	set_time_of_day(String(tl.stage.get("tod", tod_preset)))
	get_tree().paused = true
	cine_player = p
	p.finished.connect(_on_cine_finished.bind(tl.slot), CONNECT_ONE_SHOT)
	p.start()
	return p


func _on_cine_finished(skipped: bool, slot: String) -> void:
	for n: Node in (_cine_saved.get("vis", {}) as Dictionary).keys():
		if is_instance_valid(n):
			n.visible = _cine_saved["vis"][n]
	for n2: Node in (_cine_saved.get("proc", {}) as Dictionary).keys():
		if is_instance_valid(n2):
			n2.process_mode = _cine_saved["proc"][n2]
	set_time_of_day(String(_cine_saved.get("tod", tod_preset)))
	get_tree().paused = false
	if player and player.camera:
		player.camera.make_current()
	if cine_player:
		cine_player.queue_free()
	cine_player = null
	cinematic_finished.emit(slot, skipped)


## [F9] (debug builds): play the next timeline in scripts/cine/timelines/.
func _play_next_cinematic() -> CinePlayer:
	var all: PackedStringArray = CineTimeline.slots()
	if all.is_empty():
		flash_hint("Chưa có cinematic nào (scripts/cine/timelines/)")
		return null
	_cine_slot_i = (_cine_slot_i + 1) % all.size()
	return play_cinematic(CineTimeline.load_slot(all[_cine_slot_i]))
```

In `_unhandled_input`, add a match arm:

```gdscript
		KEY_F9:
			if OS.is_debug_build() and cine_player == null:
				_play_next_cinematic()
				get_viewport().set_input_as_handled()
```

**Check first.** `FreeRoam.set_time_of_day` returns early when the preset is unchanged, so restoring the same preset is a no-op. Check that `player.camera` exists on `ThirdPersonController`; `FreeRoam._ready` already calls `player.camera.make_current()`.

- [ ] **Step 7: Dev preview scene**

Write `scripts/cine/CinePreview.gd` (no `class_name`):
1. `_ready`: `slot = OS.get_environment("CINE_SLOT")`, defaulting to `"seg_d1_brawl"`.
2. Instantiate `res://scenes/FreeRoam.tscn`, `set("crowd_enabled", false)`, `add_child`, then `call_deferred("_play")`.
3. `_play`: `tl = CineTimeline.load_slot(slot)`.
   - If it is `null`, show a centred `Label` "Không có cinematic <slot>".
   - Otherwise `player = freeroam.play_cinematic(tl, {"debug": OS.get_environment("CINE_DEBUG") == "1"})` and connect `finished` to show the help label.
4. The help label (`CanvasLayer`, bottom-left) reads "R: xem lại · F10: debug · nhạc: <music folder>/<slot>.ogg|.mp3 (<có file / nhạc tổng hợp>)". The music folder comes from `ProjectSettings.globalize_path(CineAudio.MUSIC_DIR)` and `CineAudio.music_file(tl.music_slot)`.
5. `_unhandled_input`: R while no cinematic plays → `_play()`.

Write `scenes/dev/CinePreview.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/cine/CinePreview.gd" id="1_prev"]

[node name="CinePreview" type="Node3D"]
script = ExtResource("1_prev")
```

The owner runs it with `godot --path . res://scenes/dev/CinePreview.tscn`. Agents never run it.

- [ ] **Step 8: Import, run the test until it passes**

```bash
godot --headless --import --path . > /tmp/a1_imp.log 2>&1; grep -c "CinePlayer\|CineShots\|CineOverlay" .godot/global_script_class_cache.cfg
git diff --name-only -- '*.import' | xargs -r git checkout --
godot --headless --path . --script tests/test_cine_player.gd > /tmp/t5.log 2>&1; grep -E "SUCCESS|FAILED|✗" /tmp/t5.log
```

Expected: `✅ SUCCESS: CINE PLAYER (…)`.

**Fallback landmark.** If the west-gate stage search fails, print the candidates in a scratch run and add `"fallback": "campus_parking_center"` to the test timeline's stage. Report it: Task 7 needs the same answer.

- [ ] **Step 9: Full regression, then commit**

Also confirm that `tests/test_free_roam.gd`, `tests/test_main_menu.gd` and smoke are unchanged. `MainMenu.gd` is not touched.

```bash
git add scripts/cine/CineShots.gd scripts/cine/CineShots.gd.uid scripts/cine/CineOverlay.gd scripts/cine/CineOverlay.gd.uid scripts/cine/CinePlayer.gd scripts/cine/CinePlayer.gd.uid scripts/cine/CinePreview.gd scripts/cine/CinePreview.gd.uid scenes/dev/CinePreview.tscn scripts/StageManager.gd scripts/FreeRoam.gd tests/test_cine_player.gd tests/test_cine_player.gd.uid
git commit -m "feat(cine): timeline player (real-time clock, camera rigs with whip-pan, letterbox/fades/subtitles/skip/debug overlay, music on frame 0), FreeRoam stage search and hosting, F9 and dev preview scene; Esc never pauses during a cinematic

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Short replay system  [effort: high]

**Files:**
- Create: `scripts/cine/CineReplayRecorder.gd`, `scripts/cine/CineReplay.gd`, `tests/test_cine_replay.gd`.

**Interfaces:**
- Consumes: `CineClock` (Task 3), `CineAudio` (Task 4), `CineOverlay` and `CineShots.whip` (Task 5).
- Produces (`class_name CineReplayRecorder extends Node`):
  - `RATE = 30.0`, `window := 8.0`;
  - state `clock`, `recording`, `marks`;
  - `track(node)`, `tracked() -> Array[Node3D]`;
  - `mark(name := "blow")`, `capture()`, `frame_count()`;
  - `oldest_time()`, `newest_time()`, `transform_at(node, t)`, `apply_at(t)`;
  - `snapshot() -> Dictionary`, `restore(snap)`;
  - static `replay_clock(L, f, after, base := 0.5, preset := "heavy", focus_u := 0.55) -> {"clock": CineClock, "t0": float}`.
- Produces (`class_name CineReplay extends Node3D`):
  - `signal finished`;
  - `start(rec, opts := {}) -> bool`, opts `length` (clamped 4-6, default 5), `slot`, `focus`, `other`, `mark` ("blow"), `base` (0.5), `pause` (true), `manual` (false);
  - `step(dt)`;
  - state `length`, `r`, `clock`, `t0`, `phase_shot` ("orbit" | "low" | "wide"), `camera`, `overlay`;
  - test hook `force_skip_hold`.

  It frees itself after `finished`. Phase B calls it as `var rp := CineReplay.new(); add_child(rp); rp.start(recorder, {"slot": "seg_d1_chase", "focus": player_body, "other": enemy})`, 0.8 s after `recorder.mark("blow")`.

- [ ] **Step 1: Write the failing test `tests/test_cine_replay.gd`**

```gdscript
# File: res://tests/test_cine_replay.gd
# Headless test of the short replay (spec A1-D18) with scripted actors (combat arrives in Phase B): the recorder keeps the
# last seconds of transforms and bone poses; a 5 s replay lasts exactly 300 steps of 1/60, pauses the game, shows the actor
# where it was at the blow when the slow-motion impact plays, cuts orbit -> low -> wide, then restores the live state, the
# camera and the pause; length clamps to 4-6 s; hold-Esc skips; no footage -> no replay.
# Run:  godot --headless --path . --script tests/test_cine_replay.gd
extends SceneTree

var fails: Array[String] = []
var frames: int = 0
var world: Node3D
var a: Node3D
var b: Node3D
var cam: Camera3D
var rec: CineReplayRecorder
var pos_mark: Vector3
var done: bool = false


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	print("--- TEST CINE REPLAY ---")
	Engine.max_fps = 60
	world = Node3D.new()
	root.add_child(world)
	a = CharacterBuilder.build({"preset": "player", "seed": 21, "rigged": true})
	b = CharacterBuilder.build({"preset": "rider", "seed": 22, "rigged": true})
	world.add_child(a)
	world.add_child(b)
	b.position = Vector3(6.0, 0.0, 0.0)
	cam = Camera3D.new()
	cam.name = "GameCam"
	world.add_child(cam)
	cam.position = Vector3(0.0, 3.0, 8.0)
	cam.make_current()
	rec = CineReplayRecorder.new()
	world.add_child(rec)
	rec.track(a)
	rec.track(b)
	CharacterBuilder.set_speed(a, 3.0)


func _physics_process(_d: float) -> bool:
	if done:
		return true
	frames += 1
	if frames <= 168:
		a.position.x += 3.0 / 60.0           # scripted runner (physics frames are 1/60 s)
	if frames == 120:
		rec.mark("blow")
		pos_mark = a.global_position
	if frames == 169:
		_run_replays()
		done = true
		if fails.is_empty():
			print("✅ SUCCESS: CINE REPLAY (exact length, pause, recorded poses, shots, restore, clamp, skip)")
			quit(0)
		else:
			print("❌ FAILED: %d issues" % fails.size())
			quit(1)
	return false


func _run_replays() -> void:
	_check(rec.frame_count() >= 60, "recorder holds frames (%d)" % rec.frame_count())
	var live_pos: Vector3 = a.global_position
	var sk: Skeleton3D = a.get_meta("skeleton") as Skeleton3D
	var arm: int = sk.find_bone("UpperArm.L")
	var live_arm: Quaternion = sk.get_bone_pose_rotation(arm)
	var rec_clock0: float = rec.clock
	var rp := CineReplay.new()
	root.add_child(rp)
	var ok: bool = rp.start(rec, {"length": 5.0, "manual": true, "focus": a, "other": b})
	_check(ok, "replay starts")
	_check(paused, "game paused during the replay")
	_check(get_root().get_viewport().get_camera_3d() == rp.camera, "replay camera is current")
	var r_hit: float = float(rp.clock.ramp("focus")["r_hit"])
	var shots: Dictionary = {}
	var at_hit: float = -1.0
	var ended: Array = [false]
	rp.finished.connect(func() -> void: ended[0] = true)
	var n: int = 0
	while not ended[0] and n < 400:
		var before: float = rp.r
		rp.step(1.0 / 60.0)
		n += 1
		shots[rp.phase_shot] = true
		if before < r_hit and rp.r >= r_hit:
			at_hit = a.global_position.distance_to(pos_mark)
	_check(absi(n - 300) <= 1, "5 s replay = 300 steps (%d)" % n)
	_check(absf(r_hit - 2.75) < 0.01, "impact at 55 %% of the length (%.3f s)" % r_hit)
	_check(at_hit >= 0.0 and at_hit < 0.1, "actor at its recorded blow position when the impact plays (%.3f m)" % at_hit)
	_check(shots.has("orbit") and shots.has("low") and shots.has("wide"), "orbit, low and wide shots used: %s" % str(shots.keys()))
	_check(not paused, "game unpaused after the replay")
	_check(a.global_position.distance_to(live_pos) < 1e-3, "live position restored")
	_check(sk.get_bone_pose_rotation(arm).is_equal_approx(live_arm), "live bone pose restored")
	_check(get_root().get_viewport().get_camera_3d() == cam, "game camera current again")
	_check(is_equal_approx(rec.clock, rec_clock0), "recorder did not record while paused")
	var rp2 := CineReplay.new()
	root.add_child(rp2)
	rp2.start(rec, {"length": 9.0, "manual": true})
	_check(is_equal_approx(rp2.length, 6.0), "length clamps to 6 s")
	rp2.force_skip_hold = true
	var ended2: Array = [false]
	rp2.finished.connect(func() -> void: ended2[0] = true)
	var m: int = 0
	while not ended2[0] and m < 200:
		rp2.step(1.0 / 60.0)
		m += 1
	_check(ended2[0] and m <= 52, "hold Esc skips the replay (%d steps)" % m)
	var empty := CineReplayRecorder.new()
	root.add_child(empty)
	var rp3 := CineReplay.new()
	root.add_child(rp3)
	_check(not rp3.start(empty, {"manual": true}), "no footage -> no replay")
	_check(not paused, "and the game is not paused")
```

Run it. Expected: `Identifier "CineReplayRecorder" not declared`.

- [ ] **Step 2: Write `scripts/cine/CineReplayRecorder.gd` (complete; verified 2026-10-23)**

Verification ran in a scratch project with a rigged body: interpolated transform and bone pose at the mark, snapshot and restore, and `replay_clock` giving exactly 5.000 s even with only 0.05 s of footage after the mark.

```gdscript
# File: res://scripts/cine/CineReplayRecorder.gd
# Short-replay recorder (A1-D18): a ring buffer of the last `window` seconds of GAME time at RATE Hz holding, per tracked
# actor, its global transform and (rigged characters) every bone's local pose (rotation + position, 7 floats per bone).
# Runs with the game (PROCESS_MODE_PAUSABLE): it stops recording while a replay pauses the tree. mark() stamps an event
# ("blow") the replay centres on. apply_at(t) puts every tracked actor back where it was at recorder time t (interpolated
# between the two nearest frames, clamped to the recorded range); snapshot()/restore() keep the live state around a replay.
class_name CineReplayRecorder
extends Node

const RATE: float = 30.0

@export var window: float = 8.0
var clock: float = 0.0                 # recorder time = accumulated game seconds since the recorder started
var recording: bool = true
var marks: Dictionary = {}             # name -> recorder time
var _actors: Array[Dictionary] = []    # {node: Node3D, sk: Skeleton3D or null, n: bone count}
var _cap: int = 0
var _head: int = 0                     # next write slot
var _count: int = 0
var _times: PackedFloat64Array = []
var _xf: Array = []                    # slot -> Array[Transform3D] (index = actor index; may be shorter for old frames)
var _pose: Array = []                  # slot -> Array[PackedFloat32Array]
var _acc: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_alloc()


func _alloc() -> void:
	_cap = int(ceil(window * RATE)) + 2
	_times.resize(_cap)
	_xf.resize(_cap)
	_pose.resize(_cap)
	_head = 0
	_count = 0


## Track an actor. Rigged CharacterBuilder bodies are found through the "skeleton" meta; any Node3D works (transform only).
func track(node: Node3D) -> void:
	for a: Dictionary in _actors:
		if a["node"] == node:
			return
	var sk: Skeleton3D = node.get_meta("skeleton", null) as Skeleton3D if node.has_meta("skeleton") else null
	_actors.append({"node": node, "sk": sk, "n": sk.get_bone_count() if sk else 0})


func tracked() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for a: Dictionary in _actors:
		if is_instance_valid(a["node"]):
			out.append(a["node"])
	return out


func mark(name: String = "blow") -> void:
	marks[name] = clock


func _process(delta: float) -> void:
	if not recording:
		return
	clock += delta
	_acc += delta
	if _acc >= 1.0 / RATE:
		_acc = fmod(_acc, 1.0 / RATE)
		capture()


## Record one frame now at the current recorder time.
func capture() -> void:
	if _cap == 0:
		_alloc()
	var g: Array = _grab()
	_times[_head] = clock
	_xf[_head] = g[0]
	_pose[_head] = g[1]
	_head = (_head + 1) % _cap
	_count = mini(_count + 1, _cap)


## Current state of every tracked actor: [Array[Transform3D], Array[PackedFloat32Array]].
func _grab() -> Array:
	var xs: Array[Transform3D] = []
	var ps: Array[PackedFloat32Array] = []
	for a: Dictionary in _actors:
		var node: Node3D = a["node"] if is_instance_valid(a["node"]) else null
		xs.append(node.global_transform if node and node.is_inside_tree() else Transform3D.IDENTITY)
		var pose := PackedFloat32Array()
		var sk: Skeleton3D = a["sk"] if node else null
		if sk and is_instance_valid(sk):
			pose.resize(int(a["n"]) * 7)
			for b: int in int(a["n"]):
				var q: Quaternion = sk.get_bone_pose_rotation(b)
				var p: Vector3 = sk.get_bone_pose_position(b)
				var o: int = b * 7
				pose[o] = q.x
				pose[o + 1] = q.y
				pose[o + 2] = q.z
				pose[o + 3] = q.w
				pose[o + 4] = p.x
				pose[o + 5] = p.y
				pose[o + 6] = p.z
		ps.append(pose)
	return [xs, ps]


func frame_count() -> int:
	return _count


func _slot(i: int) -> int:   # i = 0 oldest .. _count - 1 newest
	return (_head - _count + i + _cap) % _cap


func oldest_time() -> float:
	return _times[_slot(0)] if _count > 0 else clock


func newest_time() -> float:
	return _times[_slot(_count - 1)] if _count > 0 else clock


## [slot a, slot b, weight] of the frames around recorder time t (clamped to the recorded range).
func _bracket(t: float) -> Array:
	if _count == 0:
		return []
	if t <= oldest_time():
		return [_slot(0), _slot(0), 0.0]
	if t >= newest_time():
		return [_slot(_count - 1), _slot(_count - 1), 0.0]
	var lo: int = 0
	var hi: int = _count - 1
	while hi - lo > 1:
		var mid: int = (lo + hi) >> 1
		if _times[_slot(mid)] <= t:
			lo = mid
		else:
			hi = mid
	var a: int = _slot(lo)
	var b: int = _slot(hi)
	var span: float = _times[b] - _times[a]
	return [a, b, 0.0 if span <= 0.0 else (t - _times[a]) / span]


## Global transform of tracked actor `node` at recorder time t (identity when unknown).
func transform_at(node: Node3D, t: float) -> Transform3D:
	var i: int = _index_of(node)
	var br: Array = _bracket(t)
	if i < 0 or br.is_empty():
		return Transform3D.IDENTITY
	var xa: Array = _xf[br[0]]
	var xb: Array = _xf[br[1]]
	if i >= xa.size() or i >= xb.size():
		return node.global_transform
	return (xa[i] as Transform3D).interpolate_with(xb[i], float(br[2]))


func _index_of(node: Node3D) -> int:
	for i: int in _actors.size():
		if _actors[i]["node"] == node:
			return i
	return -1


## Put every tracked actor back where it was at recorder time t.
func apply_at(t: float) -> void:
	var br: Array = _bracket(t)
	if br.is_empty():
		return
	_apply_slots(br[0], br[1], float(br[2]))


func _apply_slots(sa: int, sb: int, w: float) -> void:
	_apply_frames(_xf[sa], _xf[sb], _pose[sa], _pose[sb], w)


func _apply_frames(xa: Array, xb: Array, pa: Array, pb: Array, w: float) -> void:
	for i: int in _actors.size():
		var a: Dictionary = _actors[i]
		if not is_instance_valid(a["node"]) or i >= xa.size() or i >= xb.size():
			continue
		var node: Node3D = a["node"]
		if node.is_inside_tree():
			node.global_transform = (xa[i] as Transform3D).interpolate_with(xb[i], w)
		var sk: Skeleton3D = a["sk"]
		if sk == null or not is_instance_valid(sk) or i >= pa.size() or i >= pb.size():
			continue
		var fa: PackedFloat32Array = pa[i]
		var fb: PackedFloat32Array = pb[i]
		if fa.size() != int(a["n"]) * 7 or fb.size() != fa.size():
			continue
		for b: int in int(a["n"]):
			var o: int = b * 7
			var qa := Quaternion(fa[o], fa[o + 1], fa[o + 2], fa[o + 3])
			var qb := Quaternion(fb[o], fb[o + 1], fb[o + 2], fb[o + 3])
			sk.set_bone_pose_rotation(b, qa.slerp(qb, w))
			sk.set_bone_pose_position(b, Vector3(fa[o + 4], fa[o + 5], fa[o + 6]).lerp(Vector3(fb[o + 4], fb[o + 5], fb[o + 6]), w))


## Live state of every tracked actor (taken right before a replay; the ring buffer is not touched).
func snapshot() -> Dictionary:
	var g: Array = _grab()
	return {"xf": g[0], "pose": g[1]}


func restore(snap: Dictionary) -> void:
	if not snap.is_empty():
		_apply_frames(snap["xf"], snap["xf"], snap["pose"], snap["pose"], 0.0)


## Clock and window for a replay of REAL length L around recorder time f (A1-D18). The replay runs at `base` speed with
## one ramp (preset) at f placed at focus_u·L real seconds; the footage after f is limited to what was recorded (`after`),
## the rest of L goes before f. Story time s maps to recorder time t0 + s. Returns {"clock": CineClock, "t0": float}.
static func replay_clock(L: float, f: float, after: float, base: float = 0.5, preset: String = "heavy", focus_u: float = 0.55) -> Dictionary:
	var c := CineClock.new()
	c.length = L
	c.base = base
	c.tail_rule = false
	var p: Dictionary = CineClock.PRESETS[preset]
	var k: float = p["k"]
	var pre: float = float(p["ri"]) * (base + k) * 0.5 + float(p["hp"]) * k
	var post: float = float(p["hq"]) * k + float(p["ro"]) * (k + base) * 0.5
	var real_span: float = float(p["ri"]) + float(p["hp"]) + float(p["freeze"]) + float(p["hq"]) + float(p["ro"])
	var real_after_ideal: float = L * (1.0 - focus_u) - (float(p["freeze"]) + float(p["hq"]) + float(p["ro"]))
	var gap_post: float = clampf(minf(real_after_ideal * base, after - post), 0.0, INF)
	var gap_pre: float = maxf((L - real_span - gap_post / base) * base, 0.0)
	var s_focus: float = gap_pre + pre
	c.add("focus", s_focus, preset)
	c.story_end = s_focus + post + gap_post
	return {"clock": c, "t0": f - s_focus}
```

**Why the impact lands at 2.75 s.** With L = 5 and `focus_u` 0.55, the heavy ramp's real time before the impact is `ri + hp = 0.45` s. `gap_pre` is chosen so that `gap_pre/base + 0.45 = 2.75` whenever enough footage exists after the mark. The test records 0.8 s after the mark, which is enough, so the test expects 2.75.

**Corner case.** If less footage exists after the mark, `gap_post` shrinks, `gap_pre` grows, and the impact moves later. L stays exact.

- [ ] **Step 3: Write `scripts/cine/CineReplay.gd`**

Exact behaviour:

**`start(rec, opts) -> bool`:**
1. Return `false` (doing nothing) if `rec.frame_count() < 2`.
2. Set `length = clampf(opts.length or 5.0, 4.0, 6.0)`, `manual`, `_pause = opts.get("pause", true)`, and `f = rec.marks.get(opts.get("mark", "blow"), rec.newest_time())`.
3. `rc = CineReplayRecorder.replay_clock(length, f, rec.newest_time() − f, opts.get("base", 0.5))`; take `clock` and `t0` from it.
4. `focus = opts.focus or rec.tracked()[0]`; `other = opts.other or the second tracked actor`, if any.
5. `_impact` = the focus position at `f`, from `rec.transform_at(focus, f).origin`, midpointed with `other`'s position at `f` when there is one. `_side` = a horizontal unit vector perpendicular to `other − focus`, or `Vector3.RIGHT` when there is no other actor.
6. Set `process_mode = PROCESS_MODE_ALWAYS` and `_snap = rec.snapshot()`.
7. Remember `_prev_cam = get_viewport().get_camera_3d()`. Create `camera` and make it current. Create `overlay` (`set_tag("▶ REPLAY")`).
8. Music: `st = CineAudio.load_music(opts.slot)` when `slot != ""`. `music.stream = st`, or else `CineAudio.synth_sting(length, clock.ramp("focus").r_hit)`; `_music_len` = the stream length, or `length`. Use bus "Music".
9. `_was_paused = get_tree().paused`. If `_pause`: `get_tree().paused = true`.
10. Set `StageManager.cinematic_active = true` through `get_node_or_null`.
11. `r = 0`, `_last_us = Time.get_ticks_usec()`, `music.play()`, `_apply(0.0)`. Return `true`.

**`_process`:** the same real-time stepping as `CinePlayer`: ticks, `minf(dt, 0.1)`. Skipped when `manual`.

**`step(dt)`:**
1. Skip logic. If `force_skip_hold` or Esc has been held for 0.8 s real, `_finish()` immediately.
2. `r = minf(r + dt, length)`, `_apply(r)`.
3. If `r >= length − 1e-9`: `_finish()`.

**`_apply(rr)`:**
1. `s = clock.story_at(rr)`, `rec.apply_at(t0 + s)`.
2. Camera, with `ramp = clock.ramp("focus")`:
   - `rr < ramp.r0` → `phase_shot = "orbit"`. Centre = `focus.global_position + (0, 1.1, 0)`, radius 3.6, height +0.4. Angle from `atan2(_side.x, _side.z)` to that +60°, linear in `rr/ramp.r0`.
   - `rr < ramp.r1` → `"low"`. Position = `_impact + _side · 2.0 + (0, 0.3, 0)`, looking at `_impact + (0, 1.0, 0)`. Add `CineShots.whip(rr, ramp.r0, ramp.r1, clock.beat_rows())` yaw and FOV.
   - otherwise → `"wide"`. Pull back along `_side` from 3 m to 6 m and rise from 2.2 m to 3.0 m, looking at `_impact + (0, 0.9, 0)`.
3. Wall avoidance: ray from the look target to the camera position, excluding every tracked `CollisionObject3D` (only when `get_world_3d()` has a space). On a hit, put the camera at `hit − dir · 0.3`.
4. `overlay.set_letterbox(clampf(rr / 0.4, 0, 1))`. Fade = max(`1 − rr/0.25`, `(rr − (length − 0.3))/0.3`), clamped to 0..1.
5. `music.volume_db = linear_to_db(maxf(CineAudio.music_gain(rr, length, _music_len), 0.0001))`.

**`_finish()`:** runs once.
1. `music.stop()`, `rec.restore(_snap)`.
2. If `_prev_cam` is valid: `_prev_cam.make_current()`.
3. `get_tree().paused = _was_paused`, `cinematic_active = false`.
4. `finished.emit()`, then `queue_free()` (deferred).

- [ ] **Step 4: Import, run the test until it passes**

```bash
godot --headless --import --path . > /tmp/a1_imp.log 2>&1; grep -c "CineReplay" .godot/global_script_class_cache.cfg
git diff --name-only -- '*.import' | xargs -r git checkout --
godot --headless --path . --script tests/test_cine_replay.gd > /tmp/t6.log 2>&1; grep -E "SUCCESS|FAILED|✗" /tmp/t6.log
```

Expected: `✅ SUCCESS: CINE REPLAY (…)`.

- [ ] **Step 5: Full regression, then commit**

```bash
git add scripts/cine/CineReplayRecorder.gd scripts/cine/CineReplayRecorder.gd.uid scripts/cine/CineReplay.gd scripts/cine/CineReplay.gd.uid tests/test_cine_replay.gd tests/test_cine_replay.gd.uid
git commit -m "feat(cine): short replay system - game-time ring buffer of transforms and bone poses, fixed-length slow-motion replay with automatic orbit/low/wide shots and a music sting, live state restored

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: `seg_d1_brawl`, the first full cinematic (25.000 s)  [effort: xhigh]

**Files:**
- Create:
  - `scripts/cine/timelines/seg_d1_brawl.gd`;
  - `docs/cinematics/seg_d1_brawl.txt` (generated);
  - `tests/test_cine_d1_brawl.gd`.
- Modify: `README.md` (dev entry). Tune if needed: `scripts/cine/CineMoves.gd` windows, `scripts/cine/CineFX.gd` props.
- Remove: `scripts/cine/timelines/.gitkeep`.

**Interfaces:**
- Consumes: everything from Tasks 1-6.
- Produces:
  - the slot `seg_d1_brawl` (found by `CineTimeline.slots()`, played by F9 and the preview scene);
  - the beat sheet file.

**How the 25 s beat sheet is authored, and why the length is exact:**
1. Pick the impacts and their presets. Lay out their story times so the ramps do not overlap (each ramp's story window is `[s − pre, s + post]`).
2. Sum each ramp's `extra = real span − story span`. Here: 2 heavy × 1.17375 + 3 medium × 0.749 + 2 light × 0.385 + 3 accent × 0.5495 + 1 finisher × 1.49375 = **8.50675 s**.
3. `story_end = 25.000 − 8.50675 = 16.49325`.
4. Place the last ramp so the normal-speed tail is 3–4 s. H8 at story 12.525 ends at story 12.99375, so the tail is 16.49325 − 12.99375 = **3.4995 s**.
5. `CineClock.validate()` confirms 25.000 ± 0.0005 s and the tail rule. `tools/cine_beats.gd` writes the real times for the owner's music edit.

**Beat table** (real times from the analytic clock, checked by `tests/test_cine_clock.gd`):

| id | preset | story s | real impact | freeze end | slow-mo real window | what |
|---|---|---|---|---|---|---|
| H1 | heavy | 2.400 | 2.681 | 2.861 | 2.231–3.961 | flying kick → Mũ Vàng launched past the scooter |
| A1 | accent | 3.700 | 5.091 | – | 4.721–5.691 | dodge under Mũ Đỏ's hook (near miss) |
| H2 | light | 4.250 | 6.063 | 6.163 | 5.863–6.563 | jab → Mũ Đỏ |
| H3 | light | 4.700 | 6.898 | 6.998 | 6.698–7.398 | cross → Mũ Đỏ |
| H4 | medium | 5.300 | 7.975 | 8.115 | 7.655–8.835 | uppercut → Mũ Đỏ launched to the kerb |
| A2 | accent | 6.600 | 10.059 | – | 9.689–10.659 | front flip over the charging Mũ Xanh (apex) |
| H5 | heavy | 7.600 | 11.673 | 11.853 | 11.223–12.953 | roundhouse → Mũ Xanh flies at the crates |
| H6 | medium | 8.400 | 13.548 | 13.688 | 13.228–14.408 | Mũ Xanh smashes the crate stack |
| A3 | accent | 10.300 | 16.232 | – | 15.861–16.831 | block Mũ Vàng's flying knee |
| H7 | medium | 11.400 | 17.846 | 17.986 | 17.526–18.706 | hurricane kick → Mũ Vàng |
| H8 | finisher | 12.525 | 19.950 | 20.150 | 19.300–21.500 | Vovinam scissor takedown → Mũ Vàng slammed down |
| – | tail 1× | 12.994–16.493 | 21.500–25.000 | | | stars, Mũ Đỏ slips on the banana (r 23.26), the phone buzzes (r 23.91), the protagonist looks at it |

**Shot list** (story start → real start). Positions are initial values, tuned by numbers in this task and by the owner in the preview:

| id | story s | real s | rig | what |
|---|---|---|---|---|
| S1 | 0.000 | 0.000 | dolly | wide establishing: three couriers block the road at the back gate, night |
| S2 | 1.700 | 1.700 | track | low behind the protagonist on the run-up |
| S3 | 2.23125 | 2.231 | orbit | bullet-time orbit around the flying kick (whip at H1) |
| S4 | 3.250 | 4.424 | static | side medium: Mũ Đỏ's hook misses |
| S5 | 4.000 | 5.723 | track | over the shoulder: jab and cross |
| S6 | 5.050 | 7.543 | low_hero | low angle: the uppercut launches Mũ Đỏ |
| S7 | 5.950 | 9.192 | orbit | rising orbit: front flip over Mũ Xanh |
| S8 | 7.300 | 11.092 | static | wide side: roundhouse, Mũ Xanh flies at the crates |
| S9 | 8.150 | 13.115 | static | crate close-up: the stack shatters |
| S10 | 8.850 | 14.564 | dolly | Mũ Vàng gets up angry, charges, the flying knee is blocked |
| S11 | 10.900 | 17.164 | orbit | orbit: hurricane kick |
| S12 | 11.950 | 18.963 | crane | low extreme, crane up: the scissor takedown |
| S13 | 13.150 | 21.657 | dolly | tail: aftermath, banana slip, the phone buzzes |

- [ ] **Step 1: Write the failing test `tests/test_cine_d1_brawl.gd`**

```gdscript
# File: res://tests/test_cine_d1_brawl.gd
# Headless test of seg_d1_brawl: valid, exactly 25.000 s, the beat table and shot starts above, committed beat sheet in sync,
# plays 1500 steps of 1/60 with every tier available (UAL cap), contacts within 0.6 m on every tier (Mixamo when present),
# a clear stage at the campus west gate, F9 plays it inside FreeRoam and a hold-Esc skip restores the world.
# Run:  godot --headless --path . --script tests/test_cine_d1_brawl.gd
extends SceneTree

const IMPACTS: Dictionary = {"H1": 2.681, "A1": 5.091, "H2": 6.063, "H3": 6.898, "H4": 7.975, "A2": 10.059, "H5": 11.673,
	"H6": 13.548, "A3": 16.232, "H7": 17.846, "H8": 19.950}
const SHOTS: Dictionary = {"S1": 0.0, "S2": 1.7, "S3": 2.231, "S4": 4.424, "S5": 5.723, "S6": 7.543, "S7": 9.192, "S8": 11.092,
	"S9": 13.115, "S10": 14.564, "S11": 17.164, "S12": 18.963, "S13": 21.657}
const GROUPS: Dictionary = {"hands": ["Wrist.L", "Wrist.R"], "feet": ["Foot.L", "Foot.R"], "knees": ["LowerLeg.L", "LowerLeg.R"]}

var fails: Array[String] = []
var phase: int = 0
var frames: int = 0
var world: Node3D
var p: CinePlayer
var tl: CineTimeline
var fr: Node
var ended: Array = []


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _points(pl: CinePlayer, spec: String) -> Array[Vector3]:
	var parts: PackedStringArray = spec.split(":")
	var out: Array[Vector3] = []
	if parts[0] == "prop":
		out.append((pl.prop_nodes[parts[1]] as Node3D).global_position + Vector3(0.0, 0.6, 0.0))
		return out
	var a: CineActor = pl.actors[parts[0]]
	for bone: String in GROUPS.get(parts[1], [parts[1]]):
		out.append(a.bone_world(bone))
	return out


func _contacts(label: String) -> void:
	for row: Dictionary in tl.clock.ramps:
		if not row.has("att"):
			continue
		p.seek(float(row["r_hit"]))
		var best: float = 99.0
		for x: Vector3 in _points(p, String(row["att"])):
			for y: Vector3 in _points(p, String(row["tgt"])):
				best = minf(best, x.distance_to(y))
		print("  contact %s %-3s %.2f m" % [label, String(row["name"]), best])
		_check(best < 0.6, "%s: %s contact %.2f m < 0.6" % [label, String(row["name"]), best])


func _initialize() -> void:
	print("--- TEST CINE seg_d1_brawl ---")
	tl = CineTimeline.load_slot("seg_d1_brawl")
	_check(tl != null, "timeline loads")
	if tl == null:
		_end()
		return
	var errs: PackedStringArray = tl.validate()
	_check(errs.is_empty(), "valid: %s" % str(errs))
	_check(is_equal_approx(tl.length, 25.0) and absf(tl.clock.real_duration() - 25.0) < 0.0005, "exactly 25.000 s (%.5f)" % tl.clock.real_duration())
	var freezes: int = 0
	for row: Dictionary in tl.clock.ramps:
		freezes += 1 if float(row["freeze"]) > 0.0 else 0
	_check(tl.clock.ramps.size() == 11 and freezes == 8, "8 impacts + 3 accents")
	var tail: float = 25.0 - float(tl.clock.ramps[tl.clock.ramps.size() - 1]["r1"])
	_check(tail >= 3.0 and tail <= 4.0, "normal-speed tail %.3f s in 3-4" % tail)
	for nm: String in IMPACTS.keys():
		_check(absf(float(tl.clock.ramp(nm)["r_hit"]) - float(IMPACTS[nm])) < 0.002, "%s real impact %.3f" % [nm, float(IMPACTS[nm])])
	for sh: Dictionary in tl.shots:
		_check(absf(tl.clock.real_at(float(sh["s"])) - float(SHOTS[String(sh["id"])])) < 0.002, "shot %s real start %.3f" % [String(sh["id"]), float(SHOTS[String(sh["id"])])])
	var committed: String = FileAccess.get_file_as_string("res://docs/cinematics/seg_d1_brawl.txt").replace("\r\n", "\n")
	_check(committed == tl.beat_sheet(), "docs/cinematics/seg_d1_brawl.txt is in sync (run tools/cine_beats.gd)")
	world = Node3D.new()
	root.add_child(world)
	CineMoves.max_tier = 1
	p = CinePlayer.new()
	world.add_child(p)
	_check(p.setup(tl, Transform3D.IDENTITY, {"manual": true}).is_empty(), "sets up in an empty world")
	p.finished.connect(func(sk: bool) -> void: ended.append(sk))
	p.start()


func _process(_d: float) -> bool:
	frames += 1
	match phase:
		0:
			if not p.is_ready():
				return frames > 900 and _fail_end("music never ready")
			var n: int = 0
			while ended.is_empty() and n < 1600:
				p.step(1.0 / 60.0)
				n += 1
			_check(absi(n - 1500) <= 1 and ended == [false], "plays 1500 steps of 1/60 (%d)" % n)
			_check(p.frame_ms_total / maxf(float(p.frames), 1.0) < 8.0, "frame update %.2f ms < 8 (4 actors)" % (p.frame_ms_total / maxf(float(p.frames), 1.0)))
			_contacts("ual")
			p.queue_free()
			var caps: Array[int] = [3]
			if CineRetarget.available("mixamo"):
				caps.push_front(0)
			else:
				print("  SKIP mixamo contacts (no Mixamo files in res://assets/local/mixamo/)")
			for cap: int in caps:
				CineMoves.max_tier = cap
				p = CinePlayer.new()
				world.add_child(p)
				p.setup(tl, Transform3D.IDENTITY, {"manual": true})
				_contacts("mixamo" if cap == 0 else "code")
				p.queue_free()
			CineMoves.max_tier = 0
			var ps: PackedScene = load("res://scenes/FreeRoam.tscn")
			fr = ps.instantiate()
			fr.set("crowd_enabled", false)
			root.add_child(fr)
			frames = 0
			phase = 1
		1:
			if frames < 3:
				return false
			var xf: Variant = fr.call("cine_stage", tl.stage)
			_check(xf is Transform3D, "clear 14 x 10 m stage near the west gate (or the parking fallback)")
			ended.clear()
			fr.connect("cinematic_finished", func(slot: String, sk: bool) -> void: ended.append([slot, sk]))
			var cp: CinePlayer = fr.call("_play_next_cinematic")
			_check(cp != null and cp.timeline.slot == "seg_d1_brawl", "F9 plays seg_d1_brawl")
			if cp == null:
				return _end()
			_check(paused, "game paused during the cinematic")
			cp.force_skip_hold = true
			frames = 0
			phase = 2
		2:
			if not ended.is_empty():
				_check(ended[0] == ["seg_d1_brawl", true], "skip finished the cinematic: %s" % str(ended))
				_check(not paused and (fr.get("player") as Node3D).visible, "world restored")
				return _end()
			if frames > 2000:
				return _fail_end("skip never finished")
	return false


func _fail_end(msg: String) -> bool:
	_check(false, msg)
	return _end()


func _end() -> bool:
	if fails.is_empty():
		print("✅ SUCCESS: CINE seg_d1_brawl (25.000 s, beat sheet, tiers, contacts, FreeRoam)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true
```

Run it. Expected: `timeline loads` fails (the slot does not exist yet).

- [ ] **Step 2: Write `scripts/cine/timelines/seg_d1_brawl.gd`**

The timing values are final. Positions, shot parameters and expressions are initial values for Step 4 to tune. Write the file with the file tools: it contains Vietnamese.

```gdscript
# File: res://scripts/cine/timelines/seg_d1_brawl.gd
# seg_d1_brawl (25.000 s, spec 2026-10-23-story-phase-a1-cinematics-design.md section 13, plan Task 7 beat + shot tables):
# Day 1, the protagonist against three fictional couriers at the road edge outside the campus west gate, night.
# Stage-local positions (X right, -Z forward along the road, ground y = 0); yaw in degrees (characters face -Z at 0).
# story_end = 25 - Σ extra (8.50675) = 16.49325; the last ramp (H8) ends at story 12.99375 -> 3.4995 s tail at 1x.
extends CineTimeline

const H0 := Vector3(-5.5, 0.0, 0.4)
const C1_0 := Vector3(-1.0, 0.0, 0.2)
const C2_0 := Vector3(0.9, 0.0, -1.3)
const C3_0 := Vector3(1.8, 0.0, 1.5)
const C1_DOWN := Vector3(2.4, 0.0, 0.6)
const C2_DOWN := Vector3(-0.3, 0.0, -2.6)
const C3_STOP := Vector3(-0.45, 0.0, 0.45)
const C3_DOWN := Vector3(-2.95, 0.0, -2.6)
const CRATES := Vector3(-3.3, 0.0, -3.0)
const SCOOTER := Vector3(3.2, 0.0, -0.9)
const BANANA := Vector3(1.0, 0.0, -1.6)
const PHONE := Vector3(2.9, 0.0, 0.2)


func build() -> void:
	slot = "seg_d1_brawl"
	length = 25.0
	story_end = 16.49325
	mood = "punchy"
	fade_in = 0.5
	fade_out = 0.5   # A2 sets 0 when this segment flows straight into cine_d1 (spec 8.1)
	stage = {"landmark": "campus_west_gate", "near": 30.0, "size": Vector2(14.0, 10.0), "tod": "night", "fallback": "campus_parking_center"}
	_cast()
	_hits()
	_props()
	_hero()
	_c1()
	_c2()
	_c3()
	_shots()
	_fx_sfx()
	_subs()


func _cast() -> void:
	actor("hero", {"preset": "player", "seed": 2805, "female": false, "hair_style": "spiky", "name": "Hero"}, "Bạn", Color("#F37021"))
	actor("c1", {"preset": "rider", "seed": 101, "female": false, "body": "hoodie", "backpack": false, "shirt_color": Color("#C9A227"),
		"helmet_color": Color("#F1C40F"), "name": "ShipperMuVang"}, "Shipper Mũ Vàng", Color("#F1C40F"))
	actor("c2", {"preset": "rider", "seed": 102, "female": false, "body": "hoodie", "backpack": false, "shirt_color": Color("#8E2A2A"),
		"helmet_color": Color("#E74C3C"), "name": "ShipperMuDo"}, "Shipper Mũ Đỏ", Color("#FF6B5A"))
	actor("c3", {"preset": "rider", "seed": 103, "female": false, "body": "hoodie", "backpack": false, "shirt_color": Color("#1E8C8C"),
		"helmet_color": Color("#3498DB"), "name": "ShipperMuXanh"}, "Shipper Mũ Xanh", Color("#5DADE2"))


func _hits() -> void:
	hit("H1", 2.40, "heavy", "flying kick -> Shipper Mũ Vàng launched past the scooter", {"att": "hero:feet", "tgt": "c1:Chest"})
	hit("A1", 3.70, "accent", "dodge under Shipper Mũ Đỏ's hook (near miss)")
	hit("H2", 4.25, "light", "jab -> Shipper Mũ Đỏ", {"att": "hero:hands", "tgt": "c2:Head"})
	hit("H3", 4.70, "light", "cross -> Shipper Mũ Đỏ", {"att": "hero:hands", "tgt": "c2:Chest"})
	hit("H4", 5.30, "medium", "uppercut -> Shipper Mũ Đỏ launched to the kerb", {"att": "hero:hands", "tgt": "c2:Head"})
	hit("A2", 6.60, "accent", "front flip over the charging Shipper Mũ Xanh (apex)")
	hit("H5", 7.60, "heavy", "roundhouse -> Shipper Mũ Xanh flies at the crates", {"att": "hero:feet", "tgt": "c3:Chest"})
	hit("H6", 8.40, "medium", "Shipper Mũ Xanh smashes the crate stack", {"att": "c3:Hips", "tgt": "prop:crates"})
	hit("A3", 10.30, "accent", "block Shipper Mũ Vàng's flying knee", {"att": "c1:knees", "tgt": "hero:hands"})
	hit("H7", 11.40, "medium", "hurricane kick -> Shipper Mũ Vàng", {"att": "hero:feet", "tgt": "c1:Head"})
	hit("H8", 12.525, "finisher", "Vovinam scissor takedown -> Shipper Mũ Vàng slammed down", {"att": "hero:feet", "tgt": "c1:Chest"})


func _props() -> void:
	prop("crates", "crate_stack", CRATES, 20.0)
	prop("scooter", "scooter", SCOOTER, -70.0)
	prop("banana", "banana", BANANA, 35.0)
	prop("phone", "phone", PHONE, 30.0, {"glow_at": 15.4})


func _hero() -> void:
	var y0: float = face(H0, C1_0)
	key("hero", 0.0, H0, y0)
	move("hero", 0.0, "fight_idle")
	expr("hero", 0.4, "angry")
	key("hero", 1.20, H0, y0)
	move("hero", 1.20, "sprint")
	key("hero", 1.85, Vector3(-3.9, 0.0, 0.32), y0, {"mode": "in"})
	strike("hero", "H1", "flying_kick")
	key("hero", 2.40, Vector3(-1.85, 0.0, 0.25), y0, {"mode": "linear"})
	key("hero", 2.85, Vector3(-1.45, 0.0, 0.25), y0, {"mode": "out"})
	move("hero", 2.85, "fight_idle", {"fade": 0.2})
	var p1 := Vector3(-1.4, 0.0, 0.2)
	key("hero", 3.20, p1, face(p1, Vector3(-0.55, 0.0, -0.35)))
	var p_dodge := Vector3(-1.5, 0.0, 0.3)
	strike("hero", "A1", "dodge")
	key("hero", 3.70, p_dodge, face(p_dodge, Vector3(-0.6, 0.0, -0.3)))
	var p_jab := Vector3(-1.30, 0.0, 0.12)
	strike("hero", "H2", "jab")
	key("hero", 4.25, p_jab, face(p_jab, Vector3(-0.55, 0.0, -0.3)))
	var p_cross := Vector3(-1.15, 0.0, 0.05)
	strike("hero", "H3", "cross")
	key("hero", 4.70, p_cross, face(p_cross, Vector3(-0.42, 0.0, -0.42)))
	var p_up := Vector3(-1.05, 0.0, 0.0)
	strike("hero", "H4", "uppercut")
	key("hero", 5.30, p_up, face(p_up, Vector3(-0.35, 0.0, -0.5)))
	move("hero", 5.70, "fight_idle", {"fade": 0.2})
	var p_flip := Vector3(-1.15, 0.0, 0.35)
	var p_land := Vector3(0.45, 0.0, 0.95)
	var y_flip: float = face(p_flip, p_land)
	key("hero", 5.95, p_flip, face(p_flip, C3_0))
	strike("hero", "A2", "front_flip")
	key("hero", 6.06, p_flip, y_flip)
	key("hero", 6.60, Vector3(-0.15, 0.0, 0.75), y_flip, {"mode": "linear"})
	key("hero", 7.20, p_land, y_flip, {"mode": "linear"})
	var p_rh := Vector3(0.35, 0.0, 0.9)
	strike("hero", "H5", "roundhouse")
	key("hero", 7.38, p_rh, face(p_rh, C3_STOP))
	key("hero", 7.60, p_rh, face(p_rh, C3_STOP))
	move("hero", 8.10, "fight_idle", {"fade": 0.2})
	var p_wait := Vector3(0.4, 0.0, 0.9)
	key("hero", 8.60, p_wait, face(p_wait, C1_DOWN))
	var p_block := Vector3(0.35, 0.0, 0.85)
	strike("hero", "A3", "block")
	key("hero", 10.30, p_block, face(p_block, Vector3(1.05, 0.0, 0.75)))
	var y_h7: float = face(p_block, Vector3(1.45, 0.0, 0.7))
	strike("hero", "H7", "hurricane_kick")
	key("hero", 10.80, p_block, y_h7)
	key("hero", 11.40, Vector3(0.9, 0.0, 0.7), y_h7, {"mode": "linear"})
	var p_h8 := Vector3(1.2, 0.0, 0.6)
	var y_h8: float = face(p_h8, Vector3(2.4, 0.0, 0.5))
	key("hero", 11.95, p_h8, y_h8, {"mode": "out"})
	strike("hero", "H8", "scissor_takedown")
	key("hero", 12.525, Vector3(1.95, 0.0, 0.55), y_h8, {"mode": "linear"})
	key("hero", 12.965, Vector3(2.15, 0.0, 0.85), y_h8, {"mode": "in"})
	move("hero", 12.965, "get_up", {"dur": 1.0, "fade": 0.2})
	expr("hero", 13.9, "happy")
	var p_end := Vector3(2.0, 0.0, 0.95)
	key("hero", 13.965, p_end, face(p_end, Vector3(3.5, 0.0, 4.0)))
	move("hero", 13.965, "fight_idle", {"fade": 0.25})
	move("hero", 14.20, "victory", {"dur": 1.2})
	move("hero", 15.40, "fight_idle", {"fade": 0.3})
	look("hero", 15.45, 16.49, PHONE)
	expr("hero", 15.5, "surprised")


func _c1() -> void:
	var y_c1: float = face(C1_0, H0)
	key("c1", 0.0, C1_0, y_c1)
	move("c1", 0.0, "taunt")
	expr("c1", 0.0, "happy")
	move("c1", 1.60, "fight_idle", {"fade": 0.2})
	strike("c1", "H1", "launched_back")
	key("c1", 2.40, C1_0, y_c1)
	key("c1", 3.25, C1_DOWN, y_c1, {"mode": "linear", "arc": 1.1})
	expr("c1", 2.40, "pain")
	move("c1", 3.92, "lie")
	key("c1", 9.00, C1_DOWN, y_c1)
	move("c1", 8.40, "get_up", {"dur": 1.2})
	expr("c1", 9.20, "angry")
	var y_back: float = face(C1_DOWN, Vector3(0.35, 0.0, 0.85))
	key("c1", 9.40, C1_DOWN, y_back)
	move("c1", 9.60, "sprint")
	strike("c1", "A3", "knee_strike")
	key("c1", 10.30, Vector3(1.05, 0.0, 0.75), y_back, {"mode": "linear"})
	strike("c1", "H7", "hit_head")
	key("c1", 11.40, Vector3(1.45, 0.0, 0.7), y_back)
	key("c1", 11.90, Vector3(1.9, 0.0, 0.55), y_back, {"mode": "out"})
	strike("c1", "H8", "sweep_fall")
	expr("c1", 12.5, "pain")
	key("c1", 12.525, Vector3(2.4, 0.0, 0.5), y_back)
	key("c1", 13.00, Vector3(2.55, 0.0, 0.45), y_back, {"mode": "out"})
	move("c1", 13.435, "lie")


func _c2() -> void:
	var y_c2: float = face(C2_0, H0)
	key("c2", 0.0, C2_0, y_c2)
	move("c2", 0.0, "fight_idle")
	expr("c2", 0.3, "angry")
	var p_hook := Vector3(-0.6, 0.0, -0.3)
	var y_hook: float = face(p_hook, Vector3(-1.5, 0.0, 0.3))
	key("c2", 2.90, C2_0, y_c2)
	move("c2", 2.90, "jog")
	key("c2", 3.35, Vector3(-0.55, 0.0, -0.35), y_hook, {"mode": "linear"})
	strike("c2", "A1", "hook")
	key("c2", 3.70, p_hook, y_hook)
	strike("c2", "H2", "hit_head")
	expr("c2", 4.25, "pain")
	key("c2", 4.25, Vector3(-0.55, 0.0, -0.3), y_hook)
	key("c2", 4.60, Vector3(-0.42, 0.0, -0.42), y_hook, {"mode": "out"})
	strike("c2", "H3", "hit_stomach")
	key("c2", 4.70, Vector3(-0.42, 0.0, -0.42), y_hook)
	key("c2", 5.00, Vector3(-0.35, 0.0, -0.5), y_hook, {"mode": "out"})
	strike("c2", "H4", "launched_back")
	key("c2", 5.30, Vector3(-0.35, 0.0, -0.5), y_hook)
	key("c2", 6.15, C2_DOWN, y_hook, {"mode": "linear", "arc": 1.5})
	move("c2", 6.82, "lie")
	key("c2", 13.00, C2_DOWN, y_hook)
	move("c2", 13.20, "get_up", {"dur": 1.0})
	expr("c2", 13.6, "done")
	var y_away: float = face(C2_DOWN, BANANA)
	key("c2", 14.20, C2_DOWN, y_away)
	move("c2", 14.20, "walk")
	strike("c2", 14.95, "slip_fall")
	expr("c2", 14.95, "surprised")
	key("c2", 14.95, BANANA, y_away, {"mode": "linear"})
	key("c2", 15.40, BANANA + Vector3(0.4, 0.0, 0.2), y_away, {"mode": "out"})
	expr("c2", 15.4, "pain")
	move("c2", 15.79, "lie")


func _c3() -> void:
	var y_c3: float = face(C3_0, H0)
	key("c3", 0.0, C3_0, y_c3)
	move("c3", 0.0, "fight_idle")
	expr("c3", 0.3, "angry")
	var y_run: float = face(C3_0, Vector3(-1.15, 0.0, 0.35))
	key("c3", 5.20, C3_0, y_c3)
	move("c3", 5.20, "sprint")
	key("c3", 5.45, C3_0 + Vector3(-0.2, 0.0, -0.1), y_run)
	key("c3", 6.60, Vector3(-0.35, 0.0, 0.55), y_run, {"mode": "linear"})
	key("c3", 6.95, C3_STOP, y_run, {"mode": "out"})
	move("c3", 6.95, "fight_idle", {"fade": 0.2})
	expr("c3", 7.0, "surprised")
	var y_turn: float = face(C3_STOP, Vector3(0.35, 0.0, 0.9))
	key("c3", 7.30, C3_STOP, y_turn)
	strike("c3", "H5", "launched_back")
	expr("c3", 7.6, "pain")
	key("c3", 7.60, C3_STOP, y_turn)
	key("c3", 8.40, C3_DOWN, y_turn, {"mode": "linear", "arc": 0.9})
	strike("c3", "H6", "knocked_out")
	key("c3", 8.90, C3_DOWN + Vector3(0.2, 0.0, 0.3), y_turn, {"mode": "out"})
	expr("c3", 9.0, "done")
	move("c3", 10.30, "lie")


func _shots() -> void:
	shot("S1", 0.0, "dolly", "wide establishing: three couriers block the road at the back gate, night",
		{"from": Vector3(6.5, 1.7, 6.0), "to": Vector3(5.0, 1.35, 4.4), "look_from": Vector3(-1.5, 1.0, 0.0), "look_to": Vector3(-1.2, 1.0, 0.2), "fov": 50.0})
	shot("S2", 1.70, "track", "low behind the protagonist on the run-up",
		{"actor": "hero", "offset": Vector3(-1.7, 0.55, 1.3), "look": Vector3(2.6, 1.0, -0.1), "fov": 58.0})
	shot("S3", 2.23125, "orbit", "bullet-time orbit around the flying kick",
		{"center": Vector3(-1.4, 1.1, 0.22), "radius": 3.2, "deg_from": 200.0, "deg_to": 285.0, "height": 0.9, "fov": 45.0})
	shot("S4", 3.25, "static", "side medium: Mũ Đỏ's hook misses",
		{"pos": Vector3(-1.0, 1.4, 3.6), "look": Vector3(-1.0, 1.1, -0.2), "fov": 42.0})
	shot("S5", 4.00, "track", "over the shoulder: jab and cross",
		{"actor": "hero", "offset": Vector3(-0.65, 1.55, 1.05), "look_actor": "c2", "look": Vector3(0.0, 1.35, 0.0), "fov": 38.0})
	shot("S6", 5.05, "low_hero", "low angle: the uppercut launches Mũ Đỏ", {"actor": "hero", "side_deg": 35.0, "dist": 2.2, "fov": 50.0})
	shot("S7", 5.95, "orbit", "rising orbit: front flip over Mũ Xanh",
		{"center_actor": "hero", "center_y": 1.4, "radius": 3.8, "deg_from": 120.0, "deg_to": 60.0, "height_from": 1.0, "height_to": 2.4, "fov": 50.0})
	shot("S8", 7.30, "static", "wide side: roundhouse, Mũ Xanh flies at the crates",
		{"pos": Vector3(1.2, 1.5, 4.8), "look": Vector3(-1.4, 0.9, -1.2), "fov": 52.0})
	shot("S9", 8.15, "static", "crate close-up: the stack shatters",
		{"pos": Vector3(-1.5, 0.7, -0.7), "look": Vector3(-3.1, 0.6, -2.8), "fov": 40.0})
	shot("S10", 8.85, "dolly", "Mũ Vàng gets up angry, charges, the flying knee is blocked",
		{"from": Vector3(4.2, 1.2, 2.6), "to": Vector3(3.0, 1.25, 2.9), "look_from": Vector3(2.4, 0.8, 0.6), "look_to": Vector3(0.7, 1.2, 0.8), "fov": 45.0})
	shot("S11", 10.90, "orbit", "orbit: hurricane kick",
		{"center_actor": "hero", "center_y": 1.3, "radius": 3.0, "deg_from": 300.0, "deg_to": 390.0, "height": 1.2, "fov": 46.0})
	shot("S12", 11.95, "crane", "low extreme, crane up: the scissor takedown",
		{"from": Vector3(0.9, 0.3, 2.6), "to": Vector3(0.9, 2.9, 3.0), "look_from": Vector3(1.9, 0.6, 0.5), "look_to": Vector3(2.3, 0.4, 0.6), "fov": 48.0})
	shot("S13", 13.15, "dolly", "tail: aftermath, banana slip, the phone buzzes",
		{"from": Vector3(4.2, 2.4, 6.2), "to": Vector3(3.2, 1.8, 4.6), "look_from": Vector3(0.6, 0.6, -0.6), "look_to": Vector3(1.6, 0.5, -0.2), "fov": 50.0})


func _fx_sfx() -> void:
	fx_at("H1", "sparks", "c1:Chest", {"power": 1.0})
	fx_at("H1", "flash", "c1:Chest", {"power": 1.0})
	fx_at(3.25, "dust", "c1:Hips", {"power": 0.8})
	fx_at("H2", "sparks", "c2:Head", {"power": 0.4})
	fx_at("H3", "sparks", "c2:Chest", {"power": 0.4})
	fx_at("H4", "sparks", "c2:Head", {"power": 0.8})
	fx_at("H4", "flash", "c2:Head", {"power": 0.6})
	fx_at(6.15, "dust", "c2:Hips", {"power": 0.7})
	fx_at("H5", "sparks", "c3:Chest", {"power": 1.0})
	fx_at("H5", "flash", "c3:Chest", {"power": 1.0})
	fx_at("H6", "crate", "crates", {"power": 1.0, "dir": Vector3(-0.6, 0.3, -0.7)})
	fx_at("H6", "dust", "c3:Hips", {"power": 1.0})
	fx_at("H6", "debris", "c3:Hips", {"power": 0.6})
	fx_at("A3", "sparks", "hero:LowerArm.L", {"power": 0.3})
	fx_at("H7", "sparks", "c1:Head", {"power": 0.8})
	fx_at("H8", "dust", "c1:Hips", {"power": 1.2})
	fx_at("H8", "debris", "c1:Hips", {"power": 0.5})
	fx_at("H8", "flash", "c1:Chest", {"power": 1.2})
	fx_at(9.0, "stars", "c3", {"until": 16.49})
	fx_at(13.5, "stars", "c1", {"until": 16.49})
	fx_at(15.45, "stars", "c2", {"until": 16.49})
	sfx_at("H6", "crate_smash", 0.0)
	sfx_at(3.25, "body_fall", -2.0)
	sfx_at(6.15, "body_fall", -2.0)
	sfx_at(12.95, "body_fall", 0.0)
	sfx_at(13.6, "groan", -4.0)
	sfx_at(14.75, "slide_whistle", -2.0)
	sfx_at(15.3, "body_fall", -3.0)
	sfx_at(15.4, "phone_buzz", -4.0)
	sfx_at(15.95, "phone_buzz", -4.0)


func _subs() -> void:
	sub(21.80, 1.30, "c2", "Ui da… shipper cũng là người mà…")
	sub(23.25, 0.75, "c2", "Ơ… vỏ chuối?!")
	sub(24.05, 0.95, "hero", "Điện thoại của ai rung kìa?")
```

Delete `scripts/cine/timelines/.gitkeep`.

- [ ] **Step 3: Generate the beat sheet**

```bash
godot --headless --path . --script tools/cine_beats.gd > /tmp/cb.log 2>&1; grep -E "wrote|BEATS|INVALID|music folder" /tmp/cb.log
```

Expected:
- `wrote docs/cinematics/seg_d1_brawl.txt`;
- `BEATS WRITTEN 1 (invalid 0)`.

Open the file with the Read tool and check that it shows the beat table and shot list above.

- [ ] **Step 4: Run the test and tune by numbers until it passes (no renders)**

Run: `godot --headless --path . --script tests/test_cine_d1_brawl.gd > /tmp/t7.log 2>&1; grep -E "contact|SKIP|SUCCESS|FAILED|✗" /tmp/t7.log`

Tuning rules:
- Timing values (hit story times, presets, `story_end`) are final. Do not change them, or the beat table, the clock test and the owner's music edit drift.
- **Contact > 0.6 m on a tier.** Move the victim's root key at that hit along the attacker→victim line, or adjust that tier's window `hit` in `CineMoves.MOVES` so the striking limb is extended at the impact. Example: the code `flying_kick` extends the right leg, the Mixamo clip the left. Re-run.
- **Actors and props** must stay inside the 14 × 10 m stage box: |x| ≤ 7, |z| ≤ 5.
- **Getting stuck:** if the stage search picks the parking fallback in the test world, keep it. Report which landmark won.
- Use `CINE_SEEK`-style probes in a scratch script if needed: `CinePlayer.seek(r)`, then print `bone_world` values. Never write images.

Expected:
- `✅ SUCCESS: CINE seg_d1_brawl (…)`;
- contact lines printed for `ual` and `code`, and `mixamo` when the files are present.

- [ ] **Step 5: README dev entry**

In the README cinematic section from Task 1, add how to watch it:
- in FreeRoam, press **F9** (debug builds only);
- or run `godot --path . res://scenes/dev/CinePreview.tscn`, optionally with `CINE_DEBUG=1` for the beat overlay. R replays, F10 toggles the overlay.
- The music file for this cinematic is `seg_d1_brawl.ogg` or `.mp3` in the music folder.
- Beat times are in `docs/cinematics/seg_d1_brawl.txt`.

Write it with the file tools.

- [ ] **Step 6: Full regression, then commit**

```bash
git rm -q scripts/cine/timelines/.gitkeep
git add scripts/cine/timelines/seg_d1_brawl.gd scripts/cine/timelines/seg_d1_brawl.gd.uid docs/cinematics/seg_d1_brawl.txt tests/test_cine_d1_brawl.gd tests/test_cine_d1_brawl.gd.uid README.md scripts/cine/CineMoves.gd scripts/cine/CineFX.gd
git commit -m "feat(cine): seg_d1_brawl - 25.000 s choreographed slow-motion fight at the campus back gate (8 impacts, 3 accents, 13 shots, 3.5 s tail), generated beat sheet, F9 / preview entry

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## After Task 7 (controller)

1. **Final whole-branch review** at effort high (`superpowers:requesting-code-review`). One round, no re-review loop.
2. **Finish the branch** with `superpowers:finishing-a-development-branch`.
   - The owner's standing rule is a local merge into main when the final review is green, with no push: `git checkout main && git merge --no-ff story-a1`.
   - Then on main:
     1. `godot --headless --import --path .` (twelve new `class_name`s);
     2. restore the `.import` churn;
     3. the full regression;
     4. one `tools/import_mixamo.bat`-equivalent copy, so the owner's checkout has mocap (the folder is ignored).
3. **Tell the owner:**
   - how to watch the cinematic (F9 or the preview scene);
   - where to put `seg_d1_brawl.ogg`, and the 25.000 s beat sheet path;
   - that A2 (story framework, character creator, Day 0, the main-menu change) is next.

## Self-review (spec coverage)

| Spec item | Task |
|---|---|
| A1-D1 local Mixamo folder, gitignore, export exclusion, helper, missing-file fallback | 1 (and tiers in 2) |
| A1-D2 source-generic retarget, bone map, name normalisation | 1 |
| A1-D3 path checkout from `ec72795` | 1, Step 1 |
| A1-D4 / A1-D22 moves, tiers, impact alignment, extras, code poses | 2 |
| A1-D5 root-motion strip | 1 (`sample` root), 2 (`root_y`) |
| A1-D6 two clocks, no `Engine.time_scale`, tree paused in FreeRoam | 3, 5 |
| A1-D7 / A1-D8 analytic ramps and validator | 3 |
| A1-D9 / A1-D10 beat sheet tool and per-cinematic scripts | 3, 7 |
| A1-D11 camera rigs and whip-pan | 5 |
| A1-D12 subtitles with Dịch | 3 (validation), 5 (overlay) |
| A1-D13 / A1-D14 music slots, synthesized cue, fade rule, SFX | 4, 5 |
| A1-D15 impact FX | 4 |
| A1-D16 / A1-D17 skip, pause block, letterbox, fades | 5 |
| A1-D18 replays | 6 |
| A1-D19 / A1-D20 `seg_d1_brawl` staging and dev entry | 5 (F9, preview), 7 |
| A1-D21 real game models | 2 |
| A1-D23 budgets | 1, 2, 4, 5, 7 tests |
| Deferred A2 list, main menu untouched | Global Constraints |
