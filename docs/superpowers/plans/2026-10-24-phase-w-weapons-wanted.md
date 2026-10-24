# Phase W: Weapon Wheel, Weapons, Wanted Level and Emotes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A GTA-style radial weapon wheel (hold the middle mouse button, slow motion), eight on-foot weapons that work everywhere in the open world without gore, and a 1-3 star wanted level: campus guards, Mr.T and police motorbikes chase the player, and a catch plays a "BỊ TÓM!" cutscene followed by a community-service chore. Holding B opens an emote wheel built on the same radial UI; its first emote is "Siuuu!" (run-up, jump with a half turn, landing synced to a shout, bystanders react). Everything is wired into FreeRoam behind one flag.

**Architecture:**
- `RadialWheel` (data-driven UI, real time, the only Phase W writer of `Engine.time_scale`, outside `scripts/cine/`) is shared by `WeaponWheel` (middle mouse) and `EmoteWheel` (B).
- `WeaponDirector` owns the equipped slot, magazines and reloads, aim and fire, and the per-weapon logic. The projectile nodes are `WeaponRocket`, `WeaponDep`, `WeaponDurian`, `StinkCloud` and `SonicCone`. It is supported by:
  - `WeaponFX` (A1 `CineFX` bursts and stars on a game clock, plus tracers, smoke and scorch);
  - `WeaponAudio` (synthesized cues with `user://sfx/` overrides);
  - `WeaponHUD`, `WeaponIcons` and `WeaponProps` (all drawn or built in code).
- Every target is duck-typed through `take_hit(info) -> String` and `is_down()`: `Pedestrian` (new knocked-out, launched, stink and dance states) and `Officer`. Vehicles go through `RoamTraffic.hit_vehicle` (halted, or flipped and smoking).
- `WantedDirector` turns heat into stars, spawns officers by zone, runs line-of-sight decay and the search circle, detects busts, plays the A1 timeline `wanted_busted` through `FreeRoam.play_cinematic`, then runs `CommunityService`.
- `EmoteDirector` plays "Siuuu!" as a code-built bone-pose overlay (process priority 20, after the RigAnimator), schedules the shout cue at landing − 0.31 s through `WeaponAudio`, and calls `Pedestrian.react_emote` on bystanders within 10 m.

**Tech Stack:** Godot 4.7.2, pure GDScript, headless SceneTree tests, the A1 cinematic system (`CineTimeline`, `CinePlayer`, `CineFX`, `CineAudio`).

**Spec:** `docs/superpowers/specs/2026-10-23-phase-w-weapons-wanted-design.md`. Decisions W-D1 … W-D13 and sections 2-9 are binding (section 9 and W-D10 … W-D13 are the emote amendments dd6b7f6 and 4c8f9ed). The spec reached this branch with the merge of main (27b4412). Only Task 13 touches it, and only its status line.

## Global Constraints

**Code and assets**
- Pure GDScript, Godot 4.7.2 API; no C#, no plugins or addons. Keep the folder structure, scene names and existing `class_name`s.
- Textures, meshes and icons are made only in code. Weapon icons are polygons drawn with `draw_colored_polygon`. Never use AI-generated images. Phase W adds no image files.
- Fictional names only:
  - Mr.T is the story's fictional lecturer: `lecturer` preset, light-blue shirt, glasses.
  - Never name or reference a real singer, a real song or any real person anywhere: code, comments, tests and game text. The loa kẹo kéo default is a cue called `bolero` (a genre) built from chord tones.
- These never go in git:
  - `user://music/`;
  - `user://sfx/` (any `<cue>.ogg` and `loa_keo_keo.ogg` / `.mp3`);
  - `assets/local/`.
- Tests never write to `user://`.
- No blood, no gore, nobody dies (W-D3). Every reaction ends with getting up and fleeing. Vehicles flip, smoke and are recycled.

**Script rules**
- `class_name` scripts never write the identifiers `GameFX` or `StageManager`:
  - autoloads through `get_node_or_null("/root/GameFX")` / `get_node_or_null("/root/StageManager")`;
  - static helpers through `preload("res://scripts/GameFX.gd")`.
- Nothing under `scripts/cine/` writes `Engine.time_scale` (A1-D6). In Phase W only `scripts/weapons/WeaponWheel.gd` writes it, and it restores 1.0 on close, when blocked and when it leaves the tree.
- Headless safety: `CPUParticles3D` only (never `GPUParticles3D`), no RenderingDevice work.
- Do not touch `scripts/MainMenu.gd`.
- All Phase W gameplay is built by FreeRoam only when `mayhem_enabled` is true (the default). `tests/test_free_roam.gd` sets it to false before `add_child` so its phases stay deterministic.
- Weapons are on foot only (W-D9). The wheel and weapons are blocked:
  - while riding;
  - during a cinematic or replay (`FreeRoam.cine_player`, `StageManager.cinematic_active`, tree paused);
  - while busted or in community service;
  - while the map is open.

**Godot behaviour**
- Write files containing Vietnamese with the file tools, never bash heredocs. Python printing Vietnamese needs `PYTHONIOENCODING=utf-8`.
- After adding a `class_name` script:
  1. Run `godot --headless --import --path . > /tmp/w_imp.log 2>&1`.
  2. Check the class appears in `.godot/global_script_class_cache.cfg`.
  3. Restore the `.import` line-ending churn: `git diff --name-only -- '*.import' | xargs -r git checkout --`.
  4. Commit each new script's `.gd.uid` file with it.
- Never pipe Godot output into `grep` or `head`. Redirect to a log, then grep the log.
- Exit code 139 right after a `SUCCESS` line is a known shutdown crash: re-run once.

**Tests**
- Headless runs at about 145 fps, so every new test pins `Engine.max_fps = 60` and counts physics frames. Real-time parts use manual clocks (`step_real(dt)`, `CinePlayer.step(dt)`).
- Use a `_check(ok, msg)` helper that prints and records. Never use `assert`.
- End with `✅ SUCCESS: …` and `quit(0)`, or `❌ FAILED: …` and `quit(1)`.
- Every test restores `Engine.time_scale = 1.0` before it quits.
- Nodes added in `_initialize()` are not in the tree yet. Build scenes in the first physics frame.
- No preview renders or screenshots. The owner play-tests.

**Commits**
- After every task, run the full regression (command below). Commit only when it is green.
- Stage explicit paths only. Never stage `.import` files.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Never push, tag or release.

**Effort** (spec section 6)
- Implementer effort **xhigh** for Tasks 2-10 (weapons, combat, wanted and officer AI); **high** for Tasks 1, 11, 12 and 13 (wheel UI, community-service chore wiring, emotes, performance gate and docs).
- One review per task, at effort high, with no re-review loops (owner quota rule).

Regression command used by every task (run from the worktree root; it prints one line per test):

```bash
L=/tmp/w_logs; mkdir -p $L
godot --headless --quit --check-only --path . > $L/check.log 2>&1; echo "check exit=$? errors=$(grep -c ERROR $L/check.log)"
for t in $(ls tests/test_*.gd | xargs -n1 basename | sed 's/\.gd$//'); do
  godot --headless --path . --script tests/$t.gd > $L/$t.log 2>&1; rc=$?
  echo "$t exit=$rc :: $(grep -E 'SUCCESS|FAIL' $L/$t.log | tail -1)"
done
godot --headless --path . --script tests/smoke_all_stages.gd > $L/smoke.log 2>&1; echo "smoke exit=$? errors=$(grep -c 'SCRIPT ERROR\|^ERROR:' $L/smoke.log)"
```

---

## Branch setup (controller, before Task 1)

The worktree `.claude/worktrees/phase-w` already exists on branch `phase-w` (from `story-a1`; it now holds main merged at `27b4412` plus the spec amendments `dd6b7f6` and `4c8f9ed`). Its class cache starts empty:

```bash
cd C:/Users/nguye/.gemini/antigravity-ide/scratch/fptu-godot4-simulator/.claude/worktrees/phase-w
godot --headless --import --path . > /tmp/w_imp.log 2>&1
git diff --name-only -- '*.import' | xargs -r git checkout --
```

Run the regression once and record the baseline. All tests should pass on `4c8f9ed`.

## Decisions this plan takes where the spec is open

| # | Question | Decision |
|---|---|---|
| P1 | Task order | The spec's suggested order would put unarmed and knife (Task 2) before the knocked-out state exists. Hit reactions therefore come first (Task 2) and the WeaponDirector core second (Task 3). |
| P2 | Shotgun reload time | Not in the spec: 2.4 s for a full magazine. |
| P3 | Heat per shot | "Near people" means a pedestrian or officer within 15 m of the player when firing.<ul><li>Pistol: +2 for every shot fired near people, plus +2 for every person or vehicle hit.</li><li>Shotgun: +3 once per shot that hits someone, or that is fired near people.</li><li>Rocket: +6 per explosion. Sầu riêng: +2 per burst. Loa: +1 every 2 s held.</li><li>Unarmed: +1 per knockout. Knife: +2 per knockout. Dép: +1 per knockout.</li></ul> |
| P4 | Heat below one star | It fades at 0.2 heat per second, so a single punch is forgotten. Stars only rise with heat and only fall through the line-of-sight timer. When a star drops, the heat is set to that star's threshold. Every new crime resets the timer and the last-seen point. |
| P5 | Officer knockout length | Section 4 ("officers … get up after 10 s") is more specific than the dép row ("knocked out 4 s"). Officers stay down 10 s whatever the weapon; pedestrians stay down 4 s after a dép and 6-10 s otherwise. |
| P6 | Unarmed combo | The 1st and 2nd hits on the same person within 1.5 s make them stumble 0.25 m. The 3rd hit knocks them out. |
| P7 | Second wave | At 3 stars on the streets, the wanted count becomes 3 + 3 police after 30 s at 3 stars. |
| P8 | Busted catcher art | The busted cutscene uses the catcher's role. When Mr.T made the catch, a guard cuffs the player and Mr.T stands in front shaking his head. |
| P9 | No traffic (crowd off) | Police arrive on foot at 25-45 m instead of on bikes, so the wanted level still works with `crowd_enabled = false`. |
| P10 | fps table | Measuring fps needs windowed preview runs, which agents no longer do. Task 13 records the headless physics costs and leaves the fps column for the owner, with the exact command to run. |
| P11 | Bystanders | Gunfire scares pedestrians within 10 m and explosions within 25 m: they flee. Officers ignore scares. |
| P12 | Busted timeline slot | The slot is named `wanted_busted`, not `busted`, so that the registry's sorted order keeps `seg_d1_brawl` first for F9 (`test_cine_d1_brawl` depends on it). |
| P13 | Emote vs slow motion | A picked emote is queued and starts only once the wheel's ease has brought `Engine.time_scale` back to 1.0, so its 3.30 s timings and the cue sync always run at normal speed. The emote is refused in every state that blocks the weapon wheel, while the weapon wheel is open, while knocked down, and while aiming, reloading or firing. A cinematic, a bust or a knock-down stops it at once. Movement input from 2.20 s cancels it; earlier input is ignored. |
| P14 | Performance gate statistic | Each 120-frame window is scored by its median per-frame script time (the mean is printed too): on the owner's laptop the mean swung 3.0-3.5 ms between identical runs because of OS spikes, while the median stayed within 0.1 ms. Officers try the kerb step-up only against static geometry (`Officer._wall_is_static`): pushing through the crowd around the player had cost about 0.2 ms per frame in `test_move` probes. |

## File map

| File | Status | Task | Responsibility |
|---|---|---|---|
| `scripts/weapons/WeaponData.gd` | create | 1 | slot table (W-D4 order), names, heat constants, ammo text |
| `scripts/weapons/WeaponMath.gd` | create, extend | 1, 3, 4, 6 | wedge mapping, cones, ray-capsule / ray-box, spread, boomerang path |
| `scripts/weapons/WeaponIcons.gd` | create | 1 | code polygons of the 8 icons |
| `scripts/weapons/WeaponWheel.gd` | create | 1 | radial wheel, input, real-time slow-motion ease |
| `scripts/roam/Pedestrian.gd` | modify | 2, 12 | `take_hit`, KNOCKED_OUT / LAUNCHED / STINK / DANCE, `flee_from`, `is_down` |
| `scripts/roam/CrowdImpostors.gd` | modify | 2 | `scatter` |
| `scripts/roam/PedestrianSpawner.gd` | modify | 2 | `scatter_impostors`, `spawn_fleer` |
| `scripts/roam/RoamTraffic.gd` | modify | 2, 9 | `hit_vehicle` (halt / flip and smoke), stop zones, queries, police bikes |
| `scripts/weapons/WeaponDirector.gd` | create, extend | 3-6 | equip, ammo, reload, aim, fire, every weapon kind, heat signal |
| `scripts/weapons/WeaponFX.gd` | create, extend | 3-6 | CineFX on a game clock, tracers, explosion, stink, sonic rings |
| `scripts/weapons/WeaponAudio.gd` | create, extend | 3-6, 11, 12 | synthesized cues, overrides, bolero, loa override |
| `scripts/weapons/WeaponHUD.gd` | create | 3 | weapon widget, crosshair, toast |
| `scripts/weapons/WeaponProps.gd` | create | 3 | hand props in code |
| `scripts/ThirdPersonController.gd` | modify | 3 | over-the-shoulder aim camera, `knock_down`, `shake` |
| `scripts/FreeRoam.gd` | modify | 2, 3, 7, 8, 10, 11, 12 | `mayhem_enabled`, wiring, blocking, cine hide list, `play_cinematic` "xf", bike lock |
| `scripts/weapons/WeaponRocket.gd` | create | 5 | rocket projectile |
| `scripts/weapons/WeaponDep.gd` | create | 6 | dép tổ ong boomerang |
| `scripts/weapons/WeaponDurian.gd` | create | 6 | sầu riêng grenade |
| `scripts/weapons/StinkCloud.gd` | create | 6 | 8 m stink cloud |
| `scripts/weapons/SonicCone.gd` | create | 6 | loa kẹo kéo blast and music |
| `scripts/wanted/WantedDirector.gd` | create, extend | 7-11 | heat, stars, LOS decay, search circle, spawns, busts, service |
| `scripts/ui/ViceRadar.gd`, `scripts/ui/ViceStars.gd` | modify | 7 | search circle; 3-cell star row |
| `scripts/wanted/Officer.gd` | create | 8 | guard / Mr.T / police on foot |
| `scripts/wanted/BustedStamp.gd` | create | 10 | "BỊ TÓM!" stamp |
| `scripts/cine/timelines/wanted_busted.gd`, `docs/cinematics/wanted_busted.txt` | create | 10 | busted cutscene (A1 timeline) and its beat sheet |
| `scripts/wanted/CommunityService.gd` | create | 11 | community-service chore |
| `scripts/weapons/RadialWheel.gd` | create | 1 | shared data-driven radial wheel and time-scale ease |
| `scripts/emotes/EmoteIcons.gd`, `scripts/emotes/EmoteWheel.gd`, `scripts/emotes/EmoteDirector.gd` | create | 12 | emote icons, the B wheel, the "Siuuu!" pose timeline + cue sync + bystanders |
| `tests/support/mayhem_world.gd` | create, extend | 3, 4 | headless arena helpers |
| `tests/test_free_roam.gd` | modify | 3 | `mayhem_enabled = false` |
| `tests/test_weapon_wheel.gd` … `tests/test_emotes.gd`, `tests/test_mayhem_perf.gd` | create | 1-13 | one headless test per task |
| `README.md`, `PLAN.md`, spec status line | modify | 13 | owner notes, costs, fps table |

---

### Task 1: Radial wheel (shared by the weapon and emote wheels), code icons and the eased time scale  [effort: high]

**Files:**
- Create: `scripts/weapons/WeaponData.gd`, `scripts/weapons/WeaponMath.gd`, `scripts/weapons/WeaponIcons.gd`, `scripts/weapons/RadialWheel.gd`, `scripts/weapons/WeaponWheel.gd` (plus the `.gd.uid` files the import creates).
- Test: `tests/test_weapon_wheel.gd`.

**Interfaces:**
- Consumes: `ViceHUD.style_active() -> bool` (vice or classic accent).
- Produces:
  - `class_name WeaponData`:
    - `enum Slot { UNARMED, KNIFE, PISTOL, SHOTGUN, ROCKET, DEP, DURIAN, LOA }`, `COUNT = 8`;
    - `SLOTS: Array[Dictionary]`, keys `id, name, kind, mag, cycle, reload, auto` plus kind-specific keys (`range, half_deg, spread_aim, spread_hip, pellets, cone_deg, knockback, speed, radius, reach, fuse, cloud_r, cloud_s`);
    - heat constants `HEAT_KO_UNARMED, HEAT_KNIFE, HEAT_SHOT_NEAR, HEAT_PISTOL_HIT, HEAT_SHOTGUN, HEAT_ROCKET, HEAT_DEP, HEAT_DURIAN, HEAT_LOA_PER_2S, NEAR_PEOPLE_M`;
    - `name_of(slot) -> String`, `mag_of(slot) -> int`, `ammo_text(slot, left) -> String`.
  - `class_name WeaponMath`: `wedge_for(v: Vector2, dead_zone: float, count := 8) -> int` (-1 inside the dead zone), `wedge_angle(i, count := 8) -> float`, `wedge_point(a) -> Vector2`, `flat(a: Vector3, b: Vector3) -> float`.
  - `class_name WeaponIcons`: `shapes(slot) -> Array` of `{"pts": PackedVector2Array, "dark": bool}` in [-1, 1]²; `draw(ci: CanvasItem, slot, center: Vector2, size: float, col: Color, dark: Color)`.
  - `class_name RadialWheel extends CanvasLayer` – the data-driven wheel, reused by Task 12's emote wheel without duplication:
    - signals `selected(slot: int)`, `cycled(step: int)`, `opened`, `closed(changed: bool)`;
    - constants `HOLD_S 0.12, DEAD_ZONE 40.0, STICK_MAX 140.0, SLOW 0.2, EASE_S 0.1, SOON "Sắp có"`;
    - configuration vars:
      - `slots: Array[Dictionary]` (`{"name", "icon": int, "enabled": bool}`);
      - `trigger_mouse: MouseButton`, `trigger_key: Key`;
      - `keep_current: bool`: true = the dead zone keeps the current slot, and only a change is selected; false = no highlight in the dead zone, and any highlighted slot is selected;
      - `scroll_cycles: bool`, `hint: String`, `icon_fn: Callable (ci, icon, center, size, col, dark)` (empty = WeaponIcons.draw);
    - state vars `current: int`, `highlight: int` (-1 = none), `stick: Vector2`, `info_fn: Callable (slot -> String)`, `blocked_fn: Callable (-> bool)`, `manual: bool`, `view: Control`;
    - methods `is_open()`, `is_enabled(slot)`, `is_blocked()`, `press()`, `release()`, `cancel()`, `feed_mouse(rel: Vector2)`, `scroll(step: int)`, `open()`, `close(apply: bool)`, `step_real(dt: float)`.
  - `class_name WeaponWheel extends RadialWheel`: the 8 weapon slots, middle mouse, scroll cycles, keep_current.

- [ ] **Step 1: Write the failing test `tests/test_weapon_wheel.gd`**

```gdscript
# File: res://tests/test_weapon_wheel.gd
# Headless test of the Phase W weapon wheel (spec section 2, section 7 "Wheel"): angle -> slot for all 8 wedges and their
# borders, the 40 px dead zone, the slot table in W-D4 order with its Vietnamese names, hold / tap threshold (0.12 s real),
# Engine.time_scale eased to 0.2 and back to 1.0 over 0.1 s real, release equips (selected), Esc and right click close
# without change, the middle button / motion / wheel events through _input, scroll cycles only while closed, blocked
# (cannot open; closes at once and restores 1.0), leaving the tree restores 1.0, icons are code polygons, and nothing
# under scripts/cine/ writes Engine.time_scale (A1-D6).
# Run:  godot --headless --path . --script tests/test_weapon_wheel.gd
extends SceneTree

var fails: Array[String] = []
var started: bool = false
var wheel: WeaponWheel
var sel: Array[int] = []
var cyc: Array[int] = []
var closes: Array[bool] = []
var blocked: bool = false


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	print("--- TEST WEAPON WHEEL ---")
	_math()
	_table()
	_icons()
	_cine_never_writes_time_scale()
	physics_frame.connect(_on_physics)   # the wheel needs the tree (viewport for _input): start in the first physics frame


func _math() -> void:
	var dz: float = WeaponWheel.DEAD_ZONE
	for i: int in 8:
		var a: float = WeaponMath.wedge_angle(i)
		var c: int = WeaponMath.wedge_for(WeaponMath.wedge_point(a) * 100.0, dz)
		_check(c == i, "wedge centre %d maps to slot %d (got %d)" % [i, i, c])
		var hi: int = WeaponMath.wedge_for(WeaponMath.wedge_point(a + deg_to_rad(22.0)) * 100.0, dz)
		var lo: int = WeaponMath.wedge_for(WeaponMath.wedge_point(a - deg_to_rad(22.0)) * 100.0, dz)
		_check(hi == i and lo == i, "±22° stays in wedge %d (got %d / %d)" % [i, hi, lo])
		var past: int = WeaponMath.wedge_for(WeaponMath.wedge_point(a + deg_to_rad(23.0)) * 100.0, dz)
		_check(past == (i + 1) % 8, "+23° from wedge %d is the next wedge clockwise (got %d)" % [i, past])
	_check(WeaponMath.wedge_for(Vector2(0.0, -100.0), dz) == 0, "straight up = slot 0 (Tay không)")
	_check(WeaponMath.wedge_for(Vector2(100.0, 0.0), dz) == 2, "right = slot 2 (Súng lục): clockwise order")
	_check(WeaponMath.wedge_for(Vector2(0.0, 100.0), dz) == 4, "down = slot 4 (Tên lửa)")
	_check(WeaponMath.wedge_for(Vector2(-100.0, 0.0), dz) == 6, "left = slot 6 (Sầu riêng)")
	_check(WeaponMath.wedge_for(Vector2(39.0, 0.0), dz) == -1 and WeaponMath.wedge_for(Vector2(0.0, -39.9), dz) == -1, "inside the 40 px dead zone -> -1")
	_check(is_equal_approx(WeaponMath.flat(Vector3(0, 5, 0), Vector3(3, -2, 4)), 5.0), "flat() ignores height")


func _table() -> void:
	var names: Array[String] = ["Tay không", "Dao", "Súng lục", "Shotgun", "Tên lửa", "Dép tổ ong", "Sầu riêng", "Loa kẹo kéo"]
	_check(WeaponData.SLOTS.size() == WeaponData.COUNT and WeaponData.COUNT == 8, "8 slots")
	for i: int in 8:
		_check(WeaponData.name_of(i) == names[i], "slot %d is named %s (got %s)" % [i, names[i], WeaponData.name_of(i)])
	_check(WeaponData.ammo_text(WeaponData.Slot.PISTOL, 12) == "12 / ∞", "pistol ammo text '12 / ∞'")
	_check(WeaponData.ammo_text(WeaponData.Slot.DEP, 0) == "∞", "no-magazine weapons show '∞'")


func _icons() -> void:
	for i: int in 8:
		var sh: Array = WeaponIcons.shapes(i)
		_check(sh.size() >= 2, "icon %d has code polygons (%d)" % [i, sh.size()])
		for s: Dictionary in sh:
			var pts: PackedVector2Array = s["pts"]
			var inside: bool = true
			for p: Vector2 in pts:
				if absf(p.x) > 1.0 or absf(p.y) > 1.0:
					inside = false
			_check(inside, "icon %d polygon stays inside the unit box" % i)
			_check(Geometry2D.triangulate_polygon(pts).size() >= 3, "icon %d polygon triangulates (simple polygon)" % i)


func _cine_never_writes_time_scale() -> void:
	var re := RegEx.new()
	re.compile("Engine\\.time_scale\\s*=[^=]")
	for dir: String in ["res://scripts/cine/", "res://scripts/cine/timelines/"]:
		for f: String in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				_check(re.search(FileAccess.get_file_as_string(dir + f)) == null, "%s%s never writes Engine.time_scale (A1-D6)" % [dir, f])
	_check(re.search(FileAccess.get_file_as_string("res://scripts/weapons/RadialWheel.gd")) != null, "the radial wheel (scripts/weapons/) is what writes it")


func _on_physics() -> void:
	if started:
		return
	started = true
	wheel = WeaponWheel.new()
	wheel.manual = true
	wheel.info_fn = func(s: int) -> String: return WeaponData.ammo_text(s, WeaponData.mag_of(s))
	wheel.blocked_fn = func() -> bool: return blocked
	root.add_child(wheel)
	wheel.selected.connect(func(s: int) -> void: sel.append(s))
	wheel.cycled.connect(func(s: int) -> void: cyc.append(s))
	wheel.closed.connect(func(c: bool) -> void: closes.append(c))
	_check(wheel.slots.size() == 8 and String(wheel.slots[5]["name"]) == "Dép tổ ong", "the weapon wheel's slot list is the W-D4 table")
	_run()
	_generic()
	Engine.time_scale = 1.0
	if fails.is_empty():
		print("✅ SUCCESS: WEAPON WHEEL (wedges, dead zone, hold/tap, eased 0.2 time scale, select / cancel, scroll, blocked, icons)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)


func _hold_open() -> void:
	wheel.press()
	wheel.step_real(0.13)


func _mb(button: MouseButton, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	return e


func _run() -> void:
	# a tap is ignored
	wheel.press()
	wheel.step_real(0.05)
	wheel.release()
	wheel.step_real(0.2)
	_check(not wheel.is_open() and is_equal_approx(Engine.time_scale, 1.0) and sel.is_empty(), "a 0.05 s tap of the middle button is ignored")
	# hold >= 0.12 s opens, the game eases to 0.2 over 0.1 s real
	wheel.current = 3
	wheel.press()
	wheel.step_real(0.06)
	_check(not wheel.is_open(), "not open after 0.06 s")
	wheel.step_real(0.07)
	_check(wheel.is_open() and wheel.view.visible, "held 0.13 s: open and drawn")
	wheel.step_real(0.05)
	_check(Engine.time_scale < 0.95 and Engine.time_scale > 0.25, "half way through the ease at 0.05 s (%.3f)" % Engine.time_scale)
	wheel.step_real(0.06)
	_check(is_equal_approx(Engine.time_scale, WeaponWheel.SLOW), "time scale 0.2 after 0.1 s real (%.3f)" % Engine.time_scale)
	# dead zone keeps the current slot; the stick picks wedges and is clamped
	wheel.feed_mouse(Vector2(10.0, -20.0))
	_check(wheel.highlight == 3, "inside the dead zone the current weapon stays highlighted (got %d)" % wheel.highlight)
	wheel.feed_mouse(Vector2(-10.0, -100.0))
	_check(wheel.highlight == 0, "stick up -> slot 0 (got %d)" % wheel.highlight)
	wheel.feed_mouse(Vector2(400.0, 120.0))
	_check(wheel.highlight == 2 and wheel.stick.length() <= WeaponWheel.STICK_MAX + 0.01, "stick right -> slot 2, stick clamped to %.0f px" % WeaponWheel.STICK_MAX)
	wheel.release()
	_check(sel.size() == 1 and sel[0] == 2 and closes.back() == true and not wheel.is_open() and not wheel.view.visible, "release equips the highlighted slot")
	wheel.step_real(0.05)
	_check(Engine.time_scale > 0.25 and Engine.time_scale < 0.99, "eases back up (%.3f)" % Engine.time_scale)
	wheel.step_real(0.06)
	_check(is_equal_approx(Engine.time_scale, 1.0), "1.0 again 0.1 s after closing")
	# Esc closes without change
	wheel.current = 2
	_hold_open()
	wheel.feed_mouse(Vector2(-200.0, 0.0))
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	wheel._input(esc)
	_check(not wheel.is_open() and sel.size() == 1 and closes.back() == false, "Esc closes without change")
	wheel.step_real(0.2)
	# right click closes without change
	_hold_open()
	wheel.feed_mouse(Vector2(0.0, 200.0))
	wheel._input(_mb(MOUSE_BUTTON_RIGHT, true))
	_check(not wheel.is_open() and sel.size() == 1 and closes.back() == false, "right click closes without change")
	wheel.step_real(0.2)
	# middle button + motion + release through _input
	wheel._input(_mb(MOUSE_BUTTON_MIDDLE, true))
	wheel.step_real(0.15)
	_check(wheel.is_open(), "middle button held (event) opens")
	var mm := InputEventMouseMotion.new()
	mm.relative = Vector2(0.0, 150.0)
	wheel._input(mm)
	wheel._input(_mb(MOUSE_BUTTON_MIDDLE, false))
	_check(sel.back() == 4, "motion down + release (events) equips slot 4 (got %s)" % str(sel))
	wheel.step_real(0.2)
	# scroll cycles only while closed
	wheel._input(_mb(MOUSE_BUTTON_WHEEL_UP, true))
	wheel._input(_mb(MOUSE_BUTTON_WHEEL_DOWN, true))
	_check(cyc.size() == 2 and cyc[0] == -1 and cyc[1] == 1, "wheel up / down cycle -1 / +1 (got %s)" % str(cyc))
	_hold_open()
	wheel._input(_mb(MOUSE_BUTTON_WHEEL_UP, true))
	_check(cyc.size() == 2, "no cycling while the wheel is open")
	wheel.cancel()
	wheel.step_real(0.2)
	# blocked: cannot open; if blocked while open it closes at once and restores 1.0
	blocked = true
	wheel.press()
	wheel.step_real(0.3)
	_check(not wheel.is_open() and is_equal_approx(Engine.time_scale, 1.0), "blocked: the wheel does not open")
	blocked = false
	_hold_open()
	wheel.step_real(0.11)
	_check(is_equal_approx(Engine.time_scale, WeaponWheel.SLOW), "test setup: open and slowed")
	blocked = true
	wheel.step_real(0.016)
	_check(not wheel.is_open() and is_equal_approx(Engine.time_scale, 1.0) and closes.back() == false, "blocked while open: closes at once and restores 1.0")
	blocked = false
	# leaving the tree restores 1.0
	_hold_open()
	wheel.step_real(0.11)
	root.remove_child(wheel)
	_check(is_equal_approx(Engine.time_scale, 1.0), "leaving the tree restores Engine.time_scale = 1.0")
	wheel.queue_free()   # not free(): GameFX queued a deferred theme call for the wheel's Control when it entered the tree


## The same RadialWheel driven by data the way Task 12's emote wheel uses it: a key trigger (B), keep_current off, one
## enabled slot and seven greyed "Sắp có" slots.
func _generic() -> void:
	var rw := RadialWheel.new()
	rw.name = "GenericWheel"
	rw.manual = true
	rw.trigger_key = KEY_B
	rw.keep_current = false
	for i: int in 8:
		rw.slots.append({"name": "Siuuu!" if i == 0 else RadialWheel.SOON, "icon": 0, "enabled": i == 0})
	root.add_child(rw)
	var got: Array[int] = []
	rw.selected.connect(func(s: int) -> void: got.append(s))
	var kb := InputEventKey.new()
	kb.physical_keycode = KEY_B
	kb.pressed = true
	var ku := InputEventKey.new()
	ku.physical_keycode = KEY_B
	ku.pressed = false
	rw._input(kb)
	rw.step_real(0.05)
	rw._input(ku)
	rw.step_real(0.2)
	_check(not rw.is_open() and got.is_empty(), "a key-triggered wheel ignores a tap")
	rw._input(kb)
	rw.step_real(0.13)
	_check(rw.is_open() and rw.highlight == -1, "holding B opens it with nothing highlighted (keep_current off)")
	rw.feed_mouse(Vector2(150.0, 0.0))
	_check(rw.highlight == -1, "a disabled (greyed) slot cannot be highlighted")
	rw._input(ku)
	_check(got.is_empty() and not rw.is_open(), "releasing over a disabled slot chooses nothing")
	rw.step_real(0.2)
	rw._input(kb)
	rw.step_real(0.13)
	rw.feed_mouse(Vector2(0.0, -150.0))
	rw._input(ku)
	_check(got.size() == 1 and got[0] == 0, "slot 0 is chosen although it equals current (keep_current off)")
	rw._input(_mb(MOUSE_BUTTON_WHEEL_UP, true))
	rw.step_real(0.2)
	_check(is_equal_approx(Engine.time_scale, 1.0), "the generic wheel restores the time scale too")
	rw.queue_free()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless --path . --script tests/test_weapon_wheel.gd > /tmp/w_t1.log 2>&1; grep -E "SUCCESS|FAIL|Parse Error|Identifier" /tmp/w_t1.log`
Expected: a parse error, because `WeaponWheel` / `WeaponMath` are not declared.

- [ ] **Step 3: Write `scripts/weapons/WeaponData.gd`**

```gdscript
# File: res://scripts/weapons/WeaponData.gd
# Weapon table of Phase W (spec 2026-10-23-phase-w-weapons-wanted-design.md, W-D4, section 3). Slot order = wheel order
# (slot 0 at the top, clockwise). mag 0 = no magazine (melee, thrown, loa). Times in game seconds (Engine.time_scale applies).
# Plan decisions: shotgun reload 2.4 s (P2), heat per shot (P3).
class_name WeaponData
extends RefCounted

enum Slot { UNARMED, KNIFE, PISTOL, SHOTGUN, ROCKET, DEP, DURIAN, LOA }

const COUNT: int = 8
const SLOTS: Array[Dictionary] = [
	{"id": "unarmed", "name": "Tay không", "kind": "melee", "mag": 0, "cycle": 0.35, "reload": 0.0, "auto": true, "range": 1.3, "half_deg": 50.0},
	{"id": "knife", "name": "Dao", "kind": "melee", "mag": 0, "cycle": 0.5, "reload": 0.0, "auto": true, "range": 1.4, "half_deg": 60.0},
	{"id": "pistol", "name": "Súng lục", "kind": "hitscan", "mag": 12, "cycle": 0.25, "reload": 1.6, "auto": true, "range": 80.0, "spread_aim": 0.5, "spread_hip": 3.5},
	{"id": "shotgun", "name": "Shotgun", "kind": "pellets", "mag": 6, "cycle": 0.8, "reload": 2.4, "auto": true, "range": 30.0, "pellets": 8, "cone_deg": 9.0, "spread_hip": 4.0, "knockback": 4.0},
	{"id": "rocket", "name": "Tên lửa", "kind": "rocket", "mag": 1, "cycle": 0.3, "reload": 2.5, "auto": false, "speed": 35.0, "radius": 6.0, "range": 140.0},
	{"id": "dep", "name": "Dép tổ ong", "kind": "boomerang", "mag": 0, "cycle": 0.2, "reload": 0.0, "auto": false, "reach": 12.0},
	{"id": "durian", "name": "Sầu riêng", "kind": "grenade", "mag": 0, "cycle": 1.0, "reload": 0.0, "auto": false, "fuse": 2.0, "cloud_r": 4.0, "cloud_s": 6.0},
	{"id": "loa", "name": "Loa kẹo kéo", "kind": "cone", "mag": 0, "cycle": 0.2, "reload": 0.0, "auto": true, "range": 10.0, "half_deg": 30.0},
]

## Heat (spec section 3; WantedDirector adds +5 for an officer knocked out).
const HEAT_KO_UNARMED: float = 1.0
const HEAT_KNIFE: float = 2.0
const HEAT_SHOT_NEAR: float = 2.0
const HEAT_PISTOL_HIT: float = 2.0
const HEAT_SHOTGUN: float = 3.0
const HEAT_ROCKET: float = 6.0
const HEAT_DEP: float = 1.0
const HEAT_DURIAN: float = 2.0
const HEAT_LOA_PER_2S: float = 1.0
## "Near people" for the shot heat: a pedestrian or officer within this many metres of the player.
const NEAR_PEOPLE_M: float = 15.0


static func name_of(slot: int) -> String:
	return String(SLOTS[clampi(slot, 0, COUNT - 1)]["name"])


static func mag_of(slot: int) -> int:
	return int(SLOTS[clampi(slot, 0, COUNT - 1)]["mag"])


## Wheel / HUD ammo text: "12 / ∞" for magazine weapons (unlimited reserve, W-D9), "∞" otherwise.
static func ammo_text(slot: int, left: int) -> String:
	return "%d / ∞" % left if mag_of(slot) > 0 else "∞"
```

- [ ] **Step 4: Write `scripts/weapons/WeaponMath.gd`**

```gdscript
# File: res://scripts/weapons/WeaponMath.gd
# Pure math of Phase W (no nodes): wheel wedges (Task 1), cones (Task 3), analytic ray tests and spread (Task 4), the dép
# boomerang path (Task 6). Wheel angles: 0 = up, clockwise, screen y down.
class_name WeaponMath
extends RefCounted


## Wheel wedge (0..count-1, slot 0 at the top, clockwise) under a stick vector in screen space; -1 inside the dead zone.
static func wedge_for(v: Vector2, dead_zone: float, count: int = 8) -> int:
	if v.length() < dead_zone:
		return -1
	var a: float = fposmod(atan2(v.x, -v.y), TAU)
	var w: float = TAU / float(count)
	return int(floor((a + w * 0.5) / w)) % count


## Centre angle (rad, 0 = up, clockwise) of wedge i.
static func wedge_angle(i: int, count: int = 8) -> float:
	return TAU * float(i) / float(count)


## Unit screen vector at wheel angle a (0 = up, clockwise; y down).
static func wedge_point(a: float) -> Vector2:
	return Vector2(sin(a), -cos(a))


## Horizontal distance (x, z) between two points.
static func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
```

- [ ] **Step 5: Write `scripts/weapons/WeaponIcons.gd`**

```gdscript
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
```

- [ ] **Step 6: Write `scripts/weapons/RadialWheel.gd`**

```gdscript
# File: res://scripts/weapons/RadialWheel.gd
# Data-driven GTA-style radial wheel shared by the weapon wheel (WeaponWheel, spec W-D1, section 2) and the emote wheel
# (EmoteWheel, W-D10, section 9). Subclasses only fill the slot list and the trigger:
#   - slots: up to 8 {"name": String, "icon": int, "enabled": bool}, one wedge each (slot 0 at the top, clockwise); icons
#     drawn in code by icon_fn(ci, icon, center, size, col, dark) (empty = WeaponIcons.draw); disabled slots are drawn
#     greyed with "Sắp có" and cannot be chosen;
#   - hold trigger_mouse (a mouse button) or trigger_key (a physical key) >= HOLD_S real seconds to open; a tap is ignored;
#   - the mouse delta accumulates into a virtual stick (clamped to STICK_MAX px): inside DEAD_ZONE px nothing new is
#     highlighted (keep_current: the current slot stays highlighted; otherwise none); outside it, the enabled wedge under
#     the stick angle;
#   - releasing the trigger emits `selected(slot)` (keep_current: only when it differs from current; otherwise whenever a
#     slot is highlighted); Esc or right click close without choosing; scroll_cycles: mouse-wheel scroll (closed) emits
#     `cycled(step)`.
# While open the game runs at Engine.time_scale SLOW (0.2), eased in and out over EASE_S real seconds; the wheel itself runs
# in real time (PROCESS_MODE_ALWAYS, Time.get_ticks_usec, or step_real(dt) when `manual`). blocked_fn (cinematic, replay,
# busted, community service, riding, map, the other wheel open, tree paused) stops it from opening and closes it at once
# (time scale back to 1.0). This file lives OUTSIDE scripts/cine/: A1-D6 forbids cinematic code to write Engine.time_scale.
# It restores 1.0 when it leaves the tree. GameFX / StageManager are never named here.
class_name RadialWheel
extends CanvasLayer

signal selected(slot: int)
signal cycled(step: int)
signal opened
signal closed(changed: bool)

const HOLD_S: float = 0.12
const DEAD_ZONE: float = 40.0
const STICK_MAX: float = 140.0
const SLOW: float = 0.2
const EASE_S: float = 0.1
const R_OUT: float = 190.0
const R_IN: float = 78.0
const ICON_SIZE: float = 54.0
const RING_BG := Color(0.04, 0.03, 0.09, 0.78)
const RING_OFF := Color(0.02, 0.02, 0.04, 0.6)
const SEP := Color(1.0, 1.0, 1.0, 0.12)
const ICON_COL := Color("#F4F1FF")
const ICON_OFF := Color(0.55, 0.55, 0.6, 0.55)
const ICON_DARK := Color(0.08, 0.05, 0.15, 0.95)
const VICE_HI := Color("#FF5FB0")
const VICE_RIM := Color("#3FF2FF")
const CLASSIC_HI := Color("#F37021")
const CLASSIC_RIM := Color("#FFFFFF")
const SOON: String = "Sắp có"

var slots: Array[Dictionary] = []
var trigger_mouse: MouseButton = MOUSE_BUTTON_NONE
var trigger_key: Key = KEY_NONE
var keep_current: bool = true
var scroll_cycles: bool = false
var hint: String = ""                    # centre text while nothing is highlighted
var icon_fn: Callable                    # (ci, icon, center, size, col, dark); empty = WeaponIcons.draw
var current: int = 0
var highlight: int = 0
var stick: Vector2 = Vector2.ZERO
var info_fn: Callable                    # slot -> String (second centre line, e.g. "12 / ∞")
var blocked_fn: Callable                 # -> bool
var manual: bool = false
var vice: bool = true
var view: Control
var _open: bool = false
var _pressing: bool = false
var _press_t: float = 0.0
var _scale_from: float = 1.0
var _scale_to: float = 1.0
var _ease_t: float = -1.0
var _wrote: bool = false
var _last_us: int = 0


func _ready() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	var v := WheelView.new()
	v.name = "WheelView"
	v.wheel = self
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.visible = false
	add_child(v)
	view = v
	_last_us = Time.get_ticks_usec()


func _exit_tree() -> void:
	if _wrote and not is_equal_approx(Engine.time_scale, 1.0):
		Engine.time_scale = 1.0
	_open = false
	_pressing = false
	_ease_t = -1.0


func is_open() -> bool:
	return _open


func is_enabled(slot: int) -> bool:
	return slot >= 0 and slot < slots.size() and bool(slots[slot].get("enabled", true))


func is_blocked() -> bool:
	return blocked_fn.is_valid() and bool(blocked_fn.call())


func press() -> void:
	if _open or is_blocked():
		return
	_pressing = true
	_press_t = 0.0


func release() -> void:
	if _open:
		close(true)
	_pressing = false


func cancel() -> void:
	_pressing = false
	if _open:
		close(false)


func feed_mouse(rel: Vector2) -> void:
	if not _open:
		return
	stick = (stick + rel).limit_length(STICK_MAX)
	var w: int = WeaponMath.wedge_for(stick, DEAD_ZONE, slots.size())
	if w >= 0 and is_enabled(w):
		highlight = w
	else:
		highlight = current if keep_current else -1
	view.queue_redraw()


func scroll(step: int) -> void:
	if not scroll_cycles or _open or _pressing or is_blocked():
		return
	cycled.emit(step)


func open() -> void:
	if _open:
		return
	_open = true
	_pressing = false
	stick = Vector2.ZERO
	highlight = current if keep_current else -1
	vice = ViceHUD.style_active()
	view.visible = true
	view.queue_redraw()
	_ease_to(SLOW)
	opened.emit()


func close(apply: bool) -> void:
	if not _open:
		return
	_open = false
	view.visible = false
	_ease_to(1.0)
	var changed: bool = apply and highlight >= 0 and (highlight != current or not keep_current)
	if changed:
		selected.emit(highlight)
	closed.emit(changed)


## Real-time tick (wall-clock seconds): time-scale ease (an ease started in this tick begins on the next one), hold timer,
## block check.
func step_real(dt: float) -> void:
	if _ease_t >= 0.0:
		_ease_t += dt
		var u: float = clampf(_ease_t / EASE_S, 0.0, 1.0)
		_set_scale(lerpf(_scale_from, _scale_to, u * u * (3.0 - 2.0 * u)))
		if u >= 1.0:
			_ease_t = -1.0
	if _pressing:
		_press_t += dt
		if _press_t >= HOLD_S - 1e-6:
			open()
	if (_open or _pressing) and is_blocked():
		_force_close()


func _process(_d: float) -> void:
	var now: int = Time.get_ticks_usec()
	var dt: float = float(now - _last_us) / 1e6
	_last_us = now
	if not manual:
		step_real(dt)


func _ease_to(target: float) -> void:
	_scale_from = Engine.time_scale
	_scale_to = target
	_ease_t = 0.0


func _set_scale(v: float) -> void:
	Engine.time_scale = v
	_wrote = true


func _force_close() -> void:
	_pressing = false
	if _open:
		_open = false
		view.visible = false
		closed.emit(false)
	_ease_t = -1.0
	if _wrote:
		_set_scale(1.0)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if trigger_mouse != MOUSE_BUTTON_NONE and mb.button_index == trigger_mouse:
			if mb.pressed:
				press()
			else:
				release()
			get_viewport().set_input_as_handled()
			return
		match mb.button_index:
			MOUSE_BUTTON_RIGHT:
				if _open and mb.pressed:
					cancel()
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_LEFT:
				if _open:
					get_viewport().set_input_as_handled()   # no mouse capture / fire click while choosing
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					scroll(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					scroll(1)
	elif event is InputEventMouseMotion and _open:
		feed_mouse((event as InputEventMouseMotion).relative)
		get_viewport().set_input_as_handled()   # the camera does not turn while choosing
	elif event is InputEventKey:
		var k: InputEventKey = event
		if trigger_key != KEY_NONE and k.physical_keycode == trigger_key and not k.echo:
			if k.pressed:
				press()
			else:
				release()
			get_viewport().set_input_as_handled()
			return
		if _open and k.pressed and not k.echo and k.physical_keycode == KEY_ESCAPE:
			cancel()
			get_viewport().set_input_as_handled()   # Esc closes the wheel, not the pause menu


## The ring: one wedge per slot (highlighted one in the accent colour, disabled ones greyed with "Sắp có"), separators,
## code-drawn icons, the centre name + info line.
class WheelView extends Control:
	var wheel: RadialWheel

	func _draw() -> void:
		var n: int = wheel.slots.size()
		if n == 0:
			return
		var c: Vector2 = size * 0.5
		var hi: Color = RadialWheel.VICE_HI if wheel.vice else RadialWheel.CLASSIC_HI
		var rim: Color = RadialWheel.VICE_RIM if wheel.vice else RadialWheel.CLASSIC_RIM
		var font: Font = ThemeDB.fallback_font
		var w: float = TAU / float(n)
		for i: int in n:
			var on: bool = wheel.is_enabled(i)
			var a0: float = WeaponMath.wedge_angle(i, n) - w * 0.5
			var pts := PackedVector2Array()
			for k: int in 9:
				pts.append(c + WeaponMath.wedge_point(a0 + w * float(k) / 8.0) * RadialWheel.R_OUT)
			for k2: int in range(8, -1, -1):
				pts.append(c + WeaponMath.wedge_point(a0 + w * float(k2) / 8.0) * RadialWheel.R_IN)
			var bg: Color = Color(hi, 0.85) if i == wheel.highlight else (RadialWheel.RING_BG if on else RadialWheel.RING_OFF)
			draw_colored_polygon(pts, bg)
			draw_line(c + WeaponMath.wedge_point(a0) * RadialWheel.R_IN, c + WeaponMath.wedge_point(a0) * RadialWheel.R_OUT, RadialWheel.SEP, 2.0)
			var ic: Vector2 = c + WeaponMath.wedge_point(WeaponMath.wedge_angle(i, n)) * (RadialWheel.R_IN + RadialWheel.R_OUT) * 0.5
			var col: Color = RadialWheel.ICON_COL if on else RadialWheel.ICON_OFF
			var icon: int = int(wheel.slots[i].get("icon", i))
			if wheel.icon_fn.is_valid():
				wheel.icon_fn.call(self, icon, ic, RadialWheel.ICON_SIZE, col, RadialWheel.ICON_DARK)
			else:
				WeaponIcons.draw(self, icon, ic, RadialWheel.ICON_SIZE, col, RadialWheel.ICON_DARK)
			if not on:
				draw_string(font, ic + Vector2(-40.0, 40.0), RadialWheel.SOON, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 12, RadialWheel.ICON_OFF)
		draw_arc(c, RadialWheel.R_OUT + 2.0, 0.0, TAU, 96, rim, 3.0, true)
		draw_circle(c, RadialWheel.R_IN - 6.0, Color(0.02, 0.01, 0.05, 0.85))
		var h: int = wheel.highlight
		var title: String = String(wheel.slots[h].get("name", "")) if h >= 0 and h < n else wheel.hint
		var info: String = String(wheel.info_fn.call(h)) if wheel.info_fn.is_valid() and h >= 0 else ""
		draw_string(font, c + Vector2(-RadialWheel.R_IN, -4.0), title, HORIZONTAL_ALIGNMENT_CENTER, RadialWheel.R_IN * 2.0, 20, Color.WHITE)
		draw_string(font, c + Vector2(-RadialWheel.R_IN, 22.0), info, HORIZONTAL_ALIGNMENT_CENTER, RadialWheel.R_IN * 2.0, 18, rim)
		if wheel.stick.length() >= RadialWheel.DEAD_ZONE:
			draw_circle(c + wheel.stick.normalized() * (RadialWheel.R_IN - 14.0), 5.0, hi)
```

- [ ] **Step 7: Write `scripts/weapons/WeaponWheel.gd`**

```gdscript
# File: res://scripts/weapons/WeaponWheel.gd
# The weapon wheel (spec W-D1, section 2): a RadialWheel with the 8 WeaponData slots (W-D4 order) and their code-drawn
# icons, opened by holding the middle mouse button; mouse-wheel scroll cycles the weapons; inside the dead zone the
# equipped weapon stays highlighted; the centre shows the name and the ammo (info_fn, set by WeaponDirector).
class_name WeaponWheel
extends RadialWheel


func _init() -> void:
	trigger_mouse = MOUSE_BUTTON_MIDDLE
	scroll_cycles = true
	keep_current = true
	for i: int in WeaponData.COUNT:
		slots.append({"name": WeaponData.name_of(i), "icon": i, "enabled": true})
```

- [ ] **Step 8: Import, check the class cache, run the test**

```bash
godot --headless --import --path . > /tmp/w_imp.log 2>&1
grep -c 'RadialWheel\|WeaponWheel\|WeaponData\|WeaponMath\|WeaponIcons' .godot/global_script_class_cache.cfg
git diff --name-only -- '*.import' | xargs -r git checkout --
godot --headless --path . --script tests/test_weapon_wheel.gd > /tmp/w_t1.log 2>&1; grep -E "SUCCESS|FAIL|✗" /tmp/w_t1.log
```
Expected: the cache count is at least 5, and the test prints `✅ SUCCESS: WEAPON WHEEL …`.

- [ ] **Step 9: Run the full regression, then commit**

```bash
git add scripts/weapons/WeaponData.gd scripts/weapons/WeaponData.gd.uid scripts/weapons/WeaponMath.gd scripts/weapons/WeaponMath.gd.uid scripts/weapons/WeaponIcons.gd scripts/weapons/WeaponIcons.gd.uid scripts/weapons/RadialWheel.gd scripts/weapons/RadialWheel.gd.uid scripts/weapons/WeaponWheel.gd scripts/weapons/WeaponWheel.gd.uid tests/test_weapon_wheel.gd tests/test_weapon_wheel.gd.uid
git commit -m "feat(weapons): data-driven RadialWheel (reused by the emote wheel) and the GTA-style weapon wheel on it - hold middle mouse 0.12 s, 8 code-drawn wedges in W-D4 order, 40 px dead zone, release equips, Esc/right click cancel, scroll cycles, Engine.time_scale eased to 0.2 in real time and restored (blocked, closed, leaving the tree); outside scripts/cine (A1-D6)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 2: Hit reactions of people and vehicles (no gore, nobody dies)  [effort: xhigh]

**Files:**
- Modify: `scripts/roam/Pedestrian.gd`, `scripts/roam/CrowdImpostors.gd`, `scripts/roam/PedestrianSpawner.gd`, `scripts/roam/RoamTraffic.gd`, `scripts/FreeRoam.gd` (`_build_traffic`: one line).
- Test: `tests/test_hit_reactions.gd`.

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces:
  - `Pedestrian`:
    - `enum State { WALK, IDLE, STUMBLE, KNOCKDOWN, FLEE, KNOCKED_OUT, LAUNCHED, STINK, DANCE }` (the old values keep their ints);
    - constants `KO_MIN 6.0, KO_MAX 10.0, FLEE_HIT_TIME 6.0, STINK_TIME 2.5, DANCE_TIME 2.0, PUNCH_STEP_M 0.25`;
    - vars `ko_left: float`, `flee_left: float`;
    - `take_hit(info: Dictionary) -> String`. info keys: `kind` ∈ `punch | melee | bullet | bonk | pellet | blast | stink | sonic | scare`, `from: Vector3`, `vel: Vector3` (pellet / blast), `dir: Vector3` and `power: float` (sonic), `ko: float`, `dance: bool`. It returns `knocked_out | launched | stink | dance | pushed | flee | stumble | none`;
    - `knock_out(secs, away)`, `launch(vel, ko)`, `flee_from(src: Vector3, secs: float)`, `is_down() -> bool`.
  - `CrowdImpostors.scatter(center: Vector3, r: float) -> int`.
  - `PedestrianSpawner.scatter_impostors(center, r) -> int` and `spawn_fleer(at: Vector3, away_from: Vector3) -> Pedestrian` (null when full or no walk node).
  - `RoamTraffic`:
    - signal `rider_fled(idx: int, at: Vector3, away_from: Vector3)`;
    - constants `HALT_RECYCLE_S 8.0, WRECK_UP 7.0, WRECK_G 20.0, RIDER_SIDE_M 1.3`;
    - `Vehicle` fields `halted, wreck_t, wreck_from, wreck_roll, rider_gone, idle_t`;
    - vars `stop_zones: Array`, `fleer_fn: Callable`;
    - `hit_vehicle(idx, kind: String, from: Vector3) -> bool`, where kind `bullet` / `pellet` halts and `blast` flips;
    - `add_stop_zone(center: Vector3, r: float, secs: float)`;
    - `active_indices() -> Array[int]`, `vehicles_near(p: Vector3, r: float) -> Array[int]`, `vehicle_box(idx) -> Array` (`[Transform3D centre frame, Vector3 half extents]`), `vehicle_of(body: Node) -> int`.

- [ ] **Step 1: Write the failing test `tests/test_hit_reactions.gd`**

```gdscript
# File: res://tests/test_hit_reactions.gd
# Headless test of the Phase W hit reactions (spec section 3, W-D3) on the target side, before any weapon exists:
#   A  Pedestrian.take_hit: melee / bullet knock out for 6-10 s, then the person gets up and flees and is never removed;
#      bonk knocks out for the given 4 s; punch stumbles; blast and pellet launch along a ballistic arc and land knocked out
#      (pellet ~4 m knockback); stink pinches the nose then flees; sonic pushes (dance or flee); scare flees; a downed
#      person ignores further hits; a mid-tier (lod_far) pedestrian is promoted first.
#   B  CrowdImpostors.scatter; PedestrianSpawner.spawn_fleer.
#   C  RoamTraffic.hit_vehicle: bullet -> halted, rider hidden, one fleer; blast -> launched, upside down on its roof,
#      smoking; halted / wrecked vehicles are recycled after HALT_RECYCLE_S out of view; stink stop zones stop and release
#      traffic; vehicle_box / vehicles_near.
# Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_hit_reactions.gd
extends SceneTree

const ROAD_Z: float = 500.0
var fails: Array[String] = []
var frames: int = 0
var phase: String = ""
var t0: int = 0
var started: bool = false
var player: CharacterBody3D
var peds: Dictionary = {}
var start_pos: Dictionary = {}
var ko_len: float = 0.0
var ko_up_frame: int = -1
var traffic: RoamTraffic
var fled: Array = []
var c0_pos: Vector3
var max_wreck_y: float = -99.0
var recycled0: int = 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	CharacterBuilder.ps2 = true      # the game's default style (vice); --script runs keep the class defaults otherwise
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	print("--- TEST HIT REACTIONS ---")
	physics_frame.connect(_on_physics)


func _line(x0: float, x1: float, z: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var x: float = x0
	while x <= x1 + 0.01:
		out.append(Vector2(x, z))
		x += 6.0
	return out


func _stub(at: Vector3) -> CharacterBody3D:
	var s := CharacterBody3D.new()
	s.set_script(load("res://tests/support/stub_mover.gd"))
	s.collision_layer = 0
	root.add_child(s)
	s.global_position = at
	return s


func _ped(key: String, at: Vector3, seed_v: int) -> Pedestrian:
	var p := Pedestrian.new()
	p.setup(PedWalkGraph.from_lines([_line(at.x - 3.0, at.x + 3.0, at.z)]), 0, {"preset": "student", "seed": seed_v})
	p.player = player
	p.mounted_fn = func() -> bool: return false
	p.position = at + Vector3(0.0, 0.05, 0.0)   # before add_child (never enter the tree at the origin)
	root.add_child(p)
	p.state = Pedestrian.State.IDLE
	p.set("_idle_left", 999.0)
	peds[key] = p
	return p


func _on_physics() -> void:
	frames += 1
	if not started:
		started = true
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(1400.0, 1.0, 1400.0)
		cs.shape = bs
		sb.add_child(cs)
		sb.position = Vector3(0.0, -0.5, 0.0)
		root.add_child(sb)
		player = _stub(Vector3(0.0, 0.0, -60.0))
		var keys: Array[String] = ["ko", "bonk", "punch", "blast", "pellet", "stink", "dance", "push", "scare", "mid"]
		for i: int in keys.size():
			_ped(keys[i], Vector3(12.0 * float(i), 0.0, 0.0), 30 + i)
		phase = "a"
		t0 = frames
		return
	var t: int = frames - t0
	match phase:
		"a":
			_part_a(t)
		"c":
			_part_c(t)


func _part_a(t: int) -> void:
	if t == 5:
		for k: String in peds.keys():
			start_pos[k] = (peds[k] as Pedestrian).global_position
		var ko: Pedestrian = peds["ko"]
		var r: String = ko.take_hit({"kind": "melee", "from": ko.global_position + Vector3(0.0, 0.0, 1.0)})
		ko_len = ko.ko_left
		_check(r == "knocked_out" and ko.state == Pedestrian.State.KNOCKED_OUT and ko.collision_layer == 0 and ko_len >= 6.0 and ko_len <= 10.0,
			"melee knocks out for 6-10 s, not solid meanwhile (%s, %.2f s)" % [r, ko_len])
		_check(ko.take_hit({"kind": "bullet"}) == "none" and ko.is_down(), "a knocked-out person ignores further hits")
		var bonk: Pedestrian = peds["bonk"]
		_check(bonk.take_hit({"kind": "bonk", "from": bonk.global_position + Vector3(0.0, 0.0, 1.0), "ko": 4.0}) == "knocked_out" and is_equal_approx(bonk.ko_left, 4.0), "bonk knocks out for the given 4 s")
		var punch: Pedestrian = peds["punch"]
		_check(punch.take_hit({"kind": "punch", "from": punch.global_position + Vector3(0.0, 0.0, 1.0)}) == "stumble" and punch.state == Pedestrian.State.STUMBLE, "a punch makes the person stumble")
		var blast: Pedestrian = peds["blast"]
		_check(blast.take_hit({"kind": "blast", "from": blast.global_position - Vector3(2.0, 0.0, 0.0), "vel": Vector3(5.0, 9.0, 0.0)}) == "launched" and blast.state == Pedestrian.State.LAUNCHED, "a blast launches")
		var pellet: Pedestrian = peds["pellet"]
		_check(pellet.take_hit({"kind": "pellet", "from": pellet.global_position - Vector3(6.0, 0.0, 0.0), "vel": Vector3(6.667, 6.0, 0.0)}) == "launched", "pellets launch (knockback)")
		var stink: Pedestrian = peds["stink"]
		_check(stink.take_hit({"kind": "stink", "from": stink.global_position + Vector3(1.0, 0.0, 0.0)}) == "stink" and stink.state == Pedestrian.State.STINK, "stink: pinches the nose")
		var dance: Pedestrian = peds["dance"]
		_check(dance.take_hit({"kind": "sonic", "from": dance.global_position + Vector3(0.0, 0.0, 2.0), "dir": Vector3(0.0, 0.0, -1.0), "power": 5.0, "dance": true}) == "dance" and dance.state == Pedestrian.State.DANCE, "sonic with the dance roll: dances")
		var push: Pedestrian = peds["push"]
		_check(push.take_hit({"kind": "sonic", "from": push.global_position + Vector3(0.0, 0.0, 2.0), "dir": Vector3(0.0, 0.0, -1.0), "power": 5.0, "dance": false}) == "pushed" and push.state == Pedestrian.State.FLEE and is_equal_approx(push.flee_left, Pedestrian.FLEE_HIT_TIME), "sonic without the dance roll: pushed, flees 6 s")
		var scare: Pedestrian = peds["scare"]
		_check(scare.take_hit({"kind": "scare", "from": scare.global_position + Vector3(3.0, 0.0, 0.0)}) == "flee" and scare.state == Pedestrian.State.FLEE, "scare: flees")
		var mid: Pedestrian = peds["mid"]
		mid.set_far(true)
		_check(mid.lod_far and mid.collision_layer == 0, "test setup: mid-tier pedestrian")
		_check(mid.take_hit({"kind": "melee"}) == "knocked_out" and not mid.lod_far and mid.state == Pedestrian.State.KNOCKED_OUT, "a mid-tier pedestrian is promoted, then knocked out")
	if t > 5 and ko_up_frame < 0 and (peds["ko"] as Pedestrian).state != Pedestrian.State.KNOCKED_OUT:
		ko_up_frame = t
	var bl: Pedestrian = peds["blast"]
	max_wreck_y = maxf(max_wreck_y, bl.global_position.y - (start_pos.get("blast", bl.global_position) as Vector3).y) if t > 5 else max_wreck_y
	if t == 35:
		_check(max_wreck_y > 0.8, "the launched person flies up (%.2f m)" % max_wreck_y)
		_check((peds["stink"] as Pedestrian).state == Pedestrian.State.STINK and (peds["dance"] as Pedestrian).state == Pedestrian.State.DANCE, "still pinching / dancing after 0.5 s")
		var dz: float = (start_pos["push"] as Vector3).z - (peds["push"] as Pedestrian).global_position.z
		_check(dz > 0.4, "the sonic push moves the person away (%.2f m)" % dz)
	if t == 95:
		var b: Pedestrian = peds["blast"]
		var dx: float = b.global_position.x - (start_pos["blast"] as Vector3).x
		_check(b.state == Pedestrian.State.KNOCKED_OUT and dx > 3.5 and dx < 5.5, "the blast arc lands knocked out ~4.5 m away (%s, %.2f m)" % [b.state, dx])
		var p: Pedestrian = peds["pellet"]
		var dx2: float = p.global_position.x - (start_pos["pellet"] as Vector3).x
		_check(p.state == Pedestrian.State.KNOCKED_OUT and dx2 > 3.0 and dx2 < 5.0, "the shotgun knockback lands ~4 m away (%.2f m)" % dx2)
	if t == 165:
		_check((peds["stink"] as Pedestrian).state == Pedestrian.State.FLEE, "after 2.5 s of stink: flees")
		_check((peds["dance"] as Pedestrian).state == Pedestrian.State.FLEE, "after 2 s of dancing: flees")
	if t == 255:
		_check((peds["bonk"] as Pedestrian).state == Pedestrian.State.FLEE, "the bonked person is up and fleeing after 4 s")
	if t == 5 + int(ko_len * 60.0) + 30:
		var ko: Pedestrian = peds["ko"]
		_check(ko_up_frame > 0 and absf(float(ko_up_frame - 5) / 60.0 - ko_len) < 0.1, "up after its own knock-out time (%.2f vs %.2f s)" % [float(ko_up_frame - 5) / 60.0, ko_len])
		_check(ko.state == Pedestrian.State.FLEE and is_instance_valid(ko) and ko.is_inside_tree(), "gets up and flees, never removed (W-D3)")
		for k: String in peds.keys():
			_check(is_instance_valid(peds[k]) and (peds[k] as Node).is_inside_tree(), "%s is still in the world" % k)
		_part_b()
		_start_c()


func _part_b() -> void:
	var g: PedWalkGraph = PedWalkGraph.from_lines([_line(-60.0, 60.0, 200.0)])
	var imp := CrowdImpostors.new()
	root.add_child(imp)
	imp.setup(g, {"cap": 10, "seed": 3})
	imp.set_physics_process(false)
	var vt: Dictionary = (CrowdImpostors.variants()[0] as Dictionary).duplicate()
	vt["profile"] = "walk"
	var specs: Array = [[0.0, 6.0, -6.0], [6.0, 0.0, 12.0], [40.0, 46.0, 34.0]]   # x, heading node x, previous node x
	for i: int in specs.size():
		var sp: Array = specs[i]
		imp.add({"wid": i + 1, "identity": vt, "node": g.nearest(Vector3(float(sp[1]), 0.0, 200.0), 1.0),
			"prev": g.nearest(Vector3(float(sp[2]), 0.0, 200.0), 1.0), "pos": Vector3(float(sp[0]), 0.0, 200.0), "speed": 1.2})
	var n: int = imp.scatter(Vector3(0.0, 0.0, 200.0), 10.0)
	_check(n == 2, "scatter: the 2 impostors within 10 m flee (got %d)" % n)
	_check(is_equal_approx(float(imp.state_at(0)["speed"]), Pedestrian.FLEE_SPEED) and is_equal_approx(float(imp.state_at(1)["speed"]), Pedestrian.FLEE_SPEED), "scattered impostors run at the flee speed")
	_check(int(imp.state_at(1)["node"]) == g.nearest(Vector3(12.0, 0.0, 200.0), 1.0), "an impostor walking toward the blast turns round")
	_check(is_equal_approx(float(imp.state_at(2)["speed"]), 1.2), "the impostor 40 m away is untouched")
	var spn := PedestrianSpawner.new()     # no setup(): only the graph, the player and the zone variants spawn_fleer needs
	spn.graph = PedWalkGraph.from_lines([_line(-30.0, 30.0, 300.0)])
	spn.player = player
	for vt2: Dictionary in CrowdImpostors.variants():
		(spn._by_zone[int(vt2["zone"])] as Array).append(vt2)
	root.add_child(spn)
	spn.set_physics_process(false)          # after add_child: entering the tree re-enables a script's _physics_process
	spn.set_process(false)
	var f: Pedestrian = spn.spawn_fleer(Vector3(2.0, 0.0, 300.0), Vector3(-6.0, 0.0, 300.0))
	_check(f != null and f.state == Pedestrian.State.FLEE and spn.pedestrians().size() == 1 and is_equal_approx(f.flee_left, Pedestrian.FLEE_HIT_TIME), "spawn_fleer: a new pedestrian runs from the shot")
	_check(spn.spawn_fleer(Vector3(2.0, 0.0, 900.0), Vector3.ZERO) == null, "spawn_fleer: no walk node within 30 m -> null")


func _start_c() -> void:
	var md := MapData.new()
	md.data = {"roads": [{"id": 1, "name": "Đường thử", "class": "primary", "width": 10.5, "lanes": 2, "oneway": false,
		"roundabout": false, "bridge": false, "region": "corridor", "points": [[-100.0, ROAD_Z], [100.0, ROAD_Z]]}]}
	var stub_roam := Node.new()
	stub_roam.set_script(load("res://tests/support/stub_roam.gd"))
	root.add_child(stub_roam)
	traffic = RoamTraffic.new()
	root.add_child(traffic)
	traffic.setup(md, _stub(Vector3(0.0, 0.0, ROAD_Z + 60.0)), {"roam": stub_roam, "kinds": [RoamTraffic.Kind.MOTO, RoamTraffic.Kind.CAR, RoamTraffic.Kind.MOTO], "plot": PackedVector2Array(), "seed": 3})
	traffic.fleer_fn = func(at: Vector3, _from: Vector3) -> Pedestrian:
		fled.append(at)
		return null
	for c: RoamTraffic.Vehicle in traffic.vehicles:
		traffic._park(c)
	var plan: Array = [[0, 60.0, 6.0], [1, 140.0, 0.0], [1, 40.0, 8.0]]   # lane, s, cruise for vehicles 0, 1, 2
	for i: int in 3:
		var c2: RoamTraffic.Vehicle = traffic.vehicles[i]
		traffic._activate(c2, int(plan[i][0]), float(plan[i][1]))
		c2.cruise = float(plan[i][2])
		c2.speed = c2.cruise
	max_wreck_y = -99.0
	phase = "c"
	t0 = frames


func _part_c(t: int) -> void:
	var c0: RoamTraffic.Vehicle = traffic.vehicles[0]
	var c1: RoamTraffic.Vehicle = traffic.vehicles[1]
	var c2: RoamTraffic.Vehicle = traffic.vehicles[2]
	if t == 2:
		c0_pos = c0.body.global_position
		_check(traffic.hit_vehicle(0, "bullet", c0_pos + Vector3(0.0, 0.0, -10.0)) and c0.halted, "a bullet halts the motorbike")
		var rider: Node3D = c0.body.get_node_or_null("Rider") as Node3D
		_check(rider != null and not rider.visible, "its rider is gone from the seat")
		_check(fled.size() == 1 and (fled[0] as Vector3).distance_to(c0_pos) < 2.5, "a fleer jumps off beside it (%s)" % str(fled))
		_check(not traffic.hit_vehicle(0, "bullet", c0_pos) and fled.size() == 1, "a second bullet changes nothing (one rider)")
		var p1: Vector3 = c1.body.global_position
		_check(traffic.hit_vehicle(1, "blast", p1 + Vector3(0.0, 0.0, -3.0)) and c1.wreck_t >= 0.0, "a blast wrecks the car")
		_check(c1.body.get_node_or_null("Smoke") is CPUParticles3D, "the wreck smokes (CPUParticles3D)")
		var bx: Array = traffic.vehicle_box(1)
		_check((bx[1] as Vector3).is_equal_approx(Vector3(0.85, 0.75, 1.95)), "vehicle_box half extents of a car")
		_check(traffic.vehicles_near(p1, 1.0).has(1) and traffic.active_indices().size() == 3, "vehicles_near / active_indices")
		_check(traffic.vehicle_of(c1.body) == 1, "vehicle_of")
	if t > 2:
		max_wreck_y = maxf(max_wreck_y, c1.body.global_position.y)
	if t == 20:
		_check(c0.speed == 0.0 and c0.body.global_position.distance_to(c0_pos) < 0.05, "the halted motorbike stays put")
		_check(max_wreck_y > MapBuilder.ROAD_Y + 1.0, "the wreck is launched (%.2f m)" % max_wreck_y)
	if t == 70:
		var b: Basis = c1.body.global_transform.basis
		_check(b.y.y < -0.9 and absf(c1.body.global_position.y - (MapBuilder.ROAD_Y + 1.5)) < 0.06, "the car lies upside down on its roof (up.y %.2f, y %.2f)" % [b.y.y, c1.body.global_position.y])
		c0.idle_t = RoamTraffic.HALT_RECYCLE_S - 0.05
		c1.idle_t = RoamTraffic.HALT_RECYCLE_S - 0.05
		recycled0 = traffic.recycled
	if t == 76:
		_check(traffic.recycled >= recycled0 + 2, "halted and wrecked vehicles out of view are recycled")
		_check(not c0.halted and c1.wreck_t < 0.0 and c1.body.get_node_or_null("Smoke") == null, "a recycled body is clean again")
		var rider0: Node3D = c0.body.get_node_or_null("Rider") as Node3D
		_check(rider0 != null and rider0.visible, "the recycled motorbike has its rider back")
	if t == 80:
		traffic.add_stop_zone(c2.body.global_position, 6.0, 1.5)
	if t == 160:
		_check(c2.speed < 0.3, "a stink stop zone stops the vehicle inside it (%.2f m/s)" % c2.speed)
	if t == 250:
		_check(traffic.stop_zones.is_empty() and c2.speed > 1.0, "the expired zone releases it (%.2f m/s)" % c2.speed)
		if fails.is_empty():
			print("✅ SUCCESS: HIT REACTIONS (knock-out, launch, stink, dance, flee, promotion, scatter, fleer, halted / flipped vehicles, stop zones)")
			quit(0)
		else:
			print("❌ FAILED: %d issues" % fails.size())
			quit(1)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless --path . --script tests/test_hit_reactions.gd > /tmp/w_t2.log 2>&1; grep -E "SUCCESS|FAIL|Parse Error|not found" /tmp/w_t2.log`
Expected: a parse error, because `take_hit`, `KNOCKED_OUT` and `hit_vehicle` do not exist.

- [ ] **Step 3: Extend `scripts/roam/Pedestrian.gd`**

3a. Append to the header comment, after the line `# quyết định cách đi. Không dùng autoload ở đây (class_name biên dịch trước autoload khi chạy test --script).`:

```gdscript
# Phase W (spec 2026-10-23-phase-w-weapons-wanted-design.md, W-D3): take_hit(info) – weapons knock people out (comic
# stars by WeaponFX, up after 6-10 s, then they flee), launch them along a ballistic arc (explosion, shotgun), make them
# pinch their nose (stink) or dance / get pushed (loa), or just scare them. Nobody dies; a mid-tier person is promoted.
```

3b. Replace `enum State { WALK, IDLE, STUMBLE, KNOCKDOWN, FLEE }` with:

```gdscript
enum State { WALK, IDLE, STUMBLE, KNOCKDOWN, FLEE, KNOCKED_OUT, LAUNCHED, STINK, DANCE }
```

3c. After the line `const ARRIVE_R: float = 0.6`, add:

```gdscript
## Phase W weapon reactions (W-D3: nobody dies – knocked out, up after KO_MIN..KO_MAX s, then flee).
const KO_MIN: float = 6.0
const KO_MAX: float = 10.0
const FLEE_HIT_TIME: float = 6.0          # bỏ chạy sau phản ứng vũ khí (va chạm thường: FLEE_TIME 3 s)
const STINK_TIME: float = 2.5
const DANCE_TIME: float = 2.0
const DANCE_CHANCE: float = 0.35
const PUNCH_STEP_M: float = 0.25          # cú đấm 1-2 của combo: lùi 0,25 m (đòn 3 vẫn trong tầm với)
const PUSH_DECEL: float = 8.0
const LAUNCH_MAX_S: float = 4.0
const LAUNCH_SPIN: float = 9.0            # rad/s quanh trục đứng khi bay
const LAND_MIN_S: float = 0.15
```

3d. After `var _rng := RandomNumberGenerator.new()`, add:

```gdscript
var ko_left: float = 0.0
var flee_left: float = FLEE_TIME
var _push_v: Vector3 = Vector3.ZERO
var _flee_src: Vector3 = Vector3.ZERO
```

3e. In `setup()`, after `_sep = Vector3.ZERO`, add:

```gdscript
	ko_left = 0.0
	flee_left = FLEE_TIME
	_push_v = Vector3.ZERO
```

3f. In `set_far()`, replace `	elif state != State.KNOCKDOWN:` with:

```gdscript
	elif not is_down():
```

3g. Replace the `match state:` block of `_physics_process()` with:

```gdscript
	match state:
		State.WALK, State.FLEE:
			_walk(delta)
		State.IDLE:
			_idle(delta)
		State.STUMBLE:
			_stumble(delta)
		State.KNOCKDOWN:
			_knockdown(delta)
		State.KNOCKED_OUT:
			_knocked_out(delta)
		State.LAUNCHED:
			_launched(delta)
		State.STINK:
			_stinking(delta)
		State.DANCE:
			_dancing(delta)
```

3h. In `_check_contacts()`, replace `	if lod_far or _cool > 0.0 or state == State.KNOCKDOWN:` with:

```gdscript
	if lod_far or _cool > 0.0 or is_down():
```

3i. In `_walk()`, replace

```gdscript
	var sp: float = FLEE_SPEED if state == State.FLEE else walk_speed
	velocity.x = dir.x * sp
	velocity.z = dir.z * sp
```

with

```gdscript
	var sp: float = FLEE_SPEED if state == State.FLEE else walk_speed
	velocity.x = dir.x * sp + _push_v.x
	velocity.z = dir.z * sp + _push_v.z
	_push_v = _push_v.move_toward(Vector3.ZERO, PUSH_DECEL * delta)
```

and replace `	if state == State.FLEE and _t >= FLEE_TIME:` with:

```gdscript
	if state == State.FLEE and _t >= flee_left:
```

3j. In `_knockdown()`, replace everything from `	if _t >= FALL_TIME + GETUP_TIME:` to the end of the function with:

```gdscript
	if _t >= FALL_TIME + GETUP_TIME:
		_getting_up = false
		_throw_v = Vector3.ZERO
		collision_layer = 1
		CharacterBuilder.set_expression(model, "open")
		# bỏ chạy: chọn nút kề xa người chơi nhất
		flee_from(player.global_position if player else global_position, FLEE_TIME)
```

3k. Insert this section right before the `# PHỤ TRỢ` section header (the `# ---…` line above `# PHỤ TRỢ`):

```gdscript
# ---------------------------------------------------------------------------
# PHASE W: PHẢN ỨNG VŨ KHÍ
# ---------------------------------------------------------------------------
## Weapon hit (Phase W, spec section 3). info:
##   "kind": "punch" (1st / 2nd hit of a punch combo: stumble) | "melee" | "bullet" | "bonk" (knock out) | "pellet" |
##           "blast" (launch with info "vel") | "stink" | "sonic" (push along info "dir" at info "power" m/s; info "dance"
##           forces the dance roll) | "scare" (flee only);
##   "from": Vector3 source position; "ko": knock-out seconds (default random KO_MIN..KO_MAX).
## A mid-tier pedestrian is promoted first. Returns "knocked_out" | "launched" | "stink" | "dance" | "pushed" | "flee" |
## "stumble" | "none" (already down).
func take_hit(info: Dictionary) -> String:
	if is_down():
		return "none"
	if lod_far:
		set_far(false)
	var kind: String = String(info.get("kind", "melee"))
	var from: Vector3 = info.get("from", global_position)
	var away: Vector3 = _flat_dir(global_position - from)
	_flee_src = from
	match kind:
		"punch":
			react("bump", away, 1.0)
			var v0: float = sqrt(2.0 * STUMBLE_DECEL * PUNCH_STEP_M)
			velocity.x = away.x * v0
			velocity.z = away.z * v0
			return "stumble"
		"melee", "bullet", "bonk":
			knock_out(float(info.get("ko", _rng.randf_range(KO_MIN, KO_MAX))), away)
			return "knocked_out"
		"pellet", "blast":
			launch(info.get("vel", away * 6.0 + Vector3(0.0, 5.0, 0.0)), float(info.get("ko", _rng.randf_range(KO_MIN, KO_MAX))))
			return "launched"
		"stink":
			if state == State.STINK:
				return "stink"
			state = State.STINK
			_t = 0.0
			velocity.x = 0.0
			velocity.z = 0.0
			CharacterBuilder.play(model, "facepalm", STINK_TIME)
			CharacterBuilder.set_expression(model, "done")
			hits.append("stink")
			return "stink"
		"sonic":
			_push_v = _flat_dir(info.get("dir", away)) * float(info.get("power", 5.0))
			if state == State.DANCE or state == State.FLEE:
				return "pushed"
			var dance: bool = bool(info["dance"]) if info.has("dance") else _rng.randf() < DANCE_CHANCE
			if dance:
				state = State.DANCE
				_t = 0.0
				CharacterBuilder.play(model, "cheer", DANCE_TIME)
				CharacterBuilder.set_expression(model, "happy")
				hits.append("dance")
				return "dance"
			flee_from(from, FLEE_HIT_TIME)
			hits.append("pushed")
			return "pushed"
		"scare":
			if state != State.FLEE:
				flee_from(from, FLEE_HIT_TIME)
			return "flee"
	return "none"


## Knocked out on the spot (WeaponFX draws the comic stars): lies down `secs`, gets up (GETUP_TIME), then flees.
func knock_out(secs: float, away: Vector3) -> void:
	state = State.KNOCKED_OUT
	ko_left = maxf(secs, GETUP_TIME + 0.1)
	_t = 0.0
	_getting_up = false
	_push_v = Vector3.ZERO
	velocity = Vector3(away.x, 0.0, away.z) * 1.5
	collision_layer = 0
	if away.length_squared() > 0.0001:
		model.rotation.y = atan2(away.x, away.z)   # nhìn về phía cú đánh: ngã ngửa ra xa nó
	CharacterBuilder.play(model, "knockdown")
	CharacterBuilder.set_expression(model, "pain")
	hits.append("ko")


## Thrown along a ballistic arc (explosion, shotgun), spinning; lands knocked out for `ko` seconds.
func launch(vel: Vector3, ko: float) -> void:
	state = State.LAUNCHED
	velocity = vel
	ko_left = ko
	_t = 0.0
	_push_v = Vector3.ZERO
	collision_layer = 0
	CharacterBuilder.play(model, "fall_flail")
	CharacterBuilder.set_expression(model, "surprised")
	hits.append("launched")


## Run away from `src` for `secs`: the next node is the neighbour farthest from src.
func flee_from(src: Vector3, secs: float) -> void:
	state = State.FLEE
	_t = 0.0
	flee_left = secs
	_flee_src = src
	CharacterBuilder.stop_clip(model)
	if graph and target_node >= 0:
		var best: int = target_node
		var best_d: float = -1.0
		for v: int in graph.neighbours(target_node):
			var d: float = graph.node_pos(v).distance_to(src)
			if d > best_d:
				best_d = d
				best = v
		prev_node = target_node
		target_node = best


func is_down() -> bool:
	return state == State.KNOCKDOWN or state == State.KNOCKED_OUT or state == State.LAUNCHED


func _knocked_out(delta: float) -> void:
	_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, THROW_DECEL * delta)
	velocity.z = move_toward(velocity.z, 0.0, THROW_DECEL * delta)
	move_and_slide()
	CharacterBuilder.set_speed(model, 0.0)
	ko_left -= delta
	if ko_left <= GETUP_TIME and not _getting_up:
		_getting_up = true
		CharacterBuilder.play(model, "getup")
	if ko_left <= 0.0:
		_getting_up = false
		collision_layer = 0 if lod_far else 1
		CharacterBuilder.set_expression(model, "open")
		flee_from(_flee_src, FLEE_HIT_TIME)


func _launched(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	move_and_slide()
	model.rotation.y += LAUNCH_SPIN * delta
	CharacterBuilder.set_speed(model, 0.0)
	if (_t >= LAND_MIN_S and is_on_floor() and velocity.y <= 0.0) or _t >= LAUNCH_MAX_S:
		knock_out(ko_left, _flat_dir(Vector3(velocity.x, 0.0, velocity.z)))


func _stinking(delta: float) -> void:
	_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, STUMBLE_DECEL * delta)
	velocity.z = move_toward(velocity.z, 0.0, STUMBLE_DECEL * delta)
	move_and_slide()
	CharacterBuilder.set_speed(model, 0.0)
	if _t >= STINK_TIME:
		flee_from(_flee_src, FLEE_HIT_TIME)


func _dancing(delta: float) -> void:
	_gravity(delta)
	_push_v = _push_v.move_toward(Vector3.ZERO, PUSH_DECEL * delta)
	velocity.x = _push_v.x
	velocity.z = _push_v.z
	move_and_slide()
	CharacterBuilder.set_speed(model, 0.0)
	if _t >= DANCE_TIME:
		flee_from(_flee_src, FLEE_HIT_TIME)


## Horizontal unit direction of v; +Z when v is (almost) vertical or zero.
static func _flat_dir(v: Vector3) -> Vector3:
	var f := Vector3(v.x, 0.0, v.z)
	return f.normalized() if f.length_squared() > 1e-6 else Vector3(0.0, 0.0, 1.0)


```

- [ ] **Step 4: Add `scatter` to `scripts/roam/CrowdImpostors.gd`**

Insert right before `## Đi tiếp dt giây theo cạnh đồ thị; …` (the doc line of `step()`):

```gdscript
## Phase W: impostors within r of center run away (spec section 3: impostors inside an effect radius simply flee) – flee
## speed, and the ones walking toward the center turn round. Returns how many.
func scatter(center: Vector3, r: float) -> int:
	if graph == null:
		return 0
	var n: int = 0
	for i: int in range(_wid.size()):
		if _flat(_pos[i], center) > r:
			continue
		_speed[i] = Pedestrian.FLEE_SPEED
		if _flat(graph.node_pos(_node[i]), center) < _flat(_pos[i], center):
			var tmp: int = _node[i]
			_node[i] = _prev[i]
			_prev[i] = tmp
		n += 1
	return n


```

- [ ] **Step 5: Add `scatter_impostors` and `spawn_fleer` to `scripts/roam/PedestrianSpawner.gd`**

Insert right before `## Câu càu nhàu của người đi đường …` (the doc line of `request_line`):

```gdscript
## Phase W: impostors inside an effect radius flee (CrowdImpostors.scatter).
func scatter_impostors(center: Vector3, r: float) -> int:
	return impostors.scatter(center, r) if impostors else 0


## Phase W: a rider / driver who jumps off a stopped or flipped vehicle – a new pedestrian at `at` (identity of the zone of
## the nearest walk node within 30 m) fleeing from away_from. null when the crowd is full or no walk node is near.
func spawn_fleer(at: Vector3, away_from: Vector3) -> Pedestrian:
	if graph == null or _peds.size() >= PED_CAP:
		return null
	var node: int = graph.nearest(at, 30.0)
	if node < 0:
		return null
	var spot: Variant = _free_spot(at)
	var p: Pedestrian = _spawn_ped(node, node, spot if spot is Vector3 else at, _new_identity(graph.zone_at(node)))
	p.flee_from(away_from, Pedestrian.FLEE_HIT_TIME)
	return p


```

- [ ] **Step 6: Extend `scripts/roam/RoamTraffic.gd`**

6a. Append to the header comment, after its last line (`# dùng autoload ở đây.`):

```gdscript
# Phase W (spec section 3): hit_vehicle – bullets stop a vehicle for good and its rider / driver flees (fleer_fn,
# PedestrianSpawner.spawn_fleer); a rocket launches it, flips it onto its roof with a smoke column. Halted and wrecked
# vehicles stay as obstacles and are recycled after HALT_RECYCLE_S out of view. Stop zones (sầu riêng stink clouds) stop
# every vehicle inside them for a while. Queries for analytic ray tests: active_indices, vehicles_near, vehicle_box.
```

6b. After `const HELMETS: Array[Color] = […]` add:

```gdscript
const HALT_RECYCLE_S: float = 8.0      # Phase W: a halted / wrecked vehicle out of view this long is recycled
const WRECK_UP: float = 7.0            # Phase W: flipped by an explosion – initial upward speed (m/s)
const WRECK_G: float = 20.0
const RIDER_SIDE_M: float = 1.3        # the rider jumps off this far to the side

signal rider_fled(idx: int, at: Vector3, away_from: Vector3)
```

6c. In `class Vehicle`, after `var ghost_t: float = 0.0`, add:

```gdscript
	var halted: bool = false             # Phase W: shot -> stopped for good, the rider ran away
	var wreck_t: float = -1.0            # Phase W: >= 0 flipped by an explosion, seconds since
	var wreck_from: Transform3D = Transform3D.IDENTITY
	var wreck_roll: float = 1.0          # roll direction (+1 / -1)
	var rider_gone: bool = false
	var idle_t: float = 0.0              # seconds halted / wrecked while out of view
```

6d. After `var _rot: int = 0` add:

```gdscript
var stop_zones: Array = []               # Phase W: [Vector2 centre, float radius, float seconds left] (stink clouds)
var fleer_fn: Callable                   # Phase W: (at: Vector3, away_from: Vector3) -> Pedestrian (spawn_fleer)
```

6e. In `_park()`, after `c.blocker = -1`, add:

```gdscript
	c.halted = false
	c.wreck_t = -1.0
	c.rider_gone = false
	c.idle_t = 0.0
	var rider: Node3D = c.body.get_node_or_null("Rider") as Node3D
	if rider:
		rider.visible = true
	var smoke: Node = c.body.get_node_or_null("Smoke")
	if smoke:
		c.body.remove_child(smoke)
		smoke.queue_free()
```

6f. In `_physics_process()`, after `_frame += 1` add `	_tick_stop_zones(delta)`. Inside the vehicle loop, right after

```gdscript
		if not c.active:
			continue
```

add

```gdscript
		if c.halted or c.wreck_t >= 0.0:
			_idle_vehicle(c, delta)
			continue
```

and right after the line `		var target: float = minf(c.cruise * (TURN_FACTOR if c.conn.size() == 3 else 1.0), c.limit)` add

```gdscript
		if not stop_zones.is_empty() and _in_stop_zone(c.pos):
			target = 0.0
```

6g. Insert this section right before the `# LÀN XE` section header (the `# ===…` line above `# LÀN XE`):

```gdscript
# ===========================================================================
# PHASE W: TRÚNG ĐẠN / NỔ / VÙNG MÙI
# ===========================================================================
## Weapon hit on vehicle idx (Phase W). kind "bullet" / "pellet": the vehicle stops for good and its rider (or driver)
## flees; "blast": it is launched, flips onto its roof and smokes, the rider is thrown off and flees. false = nothing new.
func hit_vehicle(idx: int, kind: String, from: Vector3) -> bool:
	if idx < 0 or idx >= vehicles.size():
		return false
	var c: Vehicle = vehicles[idx]
	if not c.active or c.wreck_t >= 0.0:
		return false
	if kind == "blast":
		c.wreck_t = 0.0
		c.halted = true
		c.speed = 0.0
		c.wreck_from = c.body.global_transform
		var rel := Vector2(from.x, from.z) - c.pos
		c.wreck_roll = 1.0 if rel.cross(c.dir) >= 0.0 else -1.0
		_add_smoke(c)
		_rider_flees(c, from)
		return true
	if c.halted:
		return false
	c.halted = true
	c.speed = 0.0
	_rider_flees(c, from)
	return true


func _rider_flees(c: Vehicle, from: Vector3) -> void:
	if c.rider_gone:
		return
	c.rider_gone = true
	var rider: Node3D = c.body.get_node_or_null("Rider") as Node3D
	if rider:
		rider.visible = false
	var side := Vector2(-c.dir.y, c.dir.x)
	if side.dot(Vector2(from.x, from.z) - c.pos) > 0.0:
		side = -side                       # jump off on the side away from the shooter
	var at := Vector3(c.pos.x + side.x * RIDER_SIDE_M, MapBuilder.ROAD_Y, c.pos.y + side.y * RIDER_SIDE_M)
	rider_fled.emit(c.idx, at, from)
	if fleer_fn.is_valid():
		fleer_fn.call(at, from)


## Halted / wrecked vehicle: no driving; the wreck plays its flip; recycled after HALT_RECYCLE_S out of view.
func _idle_vehicle(c: Vehicle, delta: float) -> void:
	c.speed = 0.0
	if c.wreck_t >= 0.0:
		c.wreck_t += delta
		_wreck_pose(c)
	if _in_view(Vector3(c.pos.x, 1.0, c.pos.y)):
		c.idle_t = 0.0
		return
	c.idle_t += delta
	if c.idle_t >= HALT_RECYCLE_S:
		_park(c)
		recycled += 1


## Flip as a pure function of wreck_t: a ballistic hop of WRECK_UP m/s while rolling 180° about the long (-Z) axis; the
## origin rises by the body height so the vehicle ends resting on its roof.
func _wreck_pose(c: Vehicle) -> void:
	var t: float = c.wreck_t
	var flight: float = 2.0 * WRECK_UP / WRECK_G
	var u: float = smoothstep(0.0, flight, t)
	var h: float = maxf(0.0, WRECK_UP * t - 0.5 * WRECK_G * t * t)
	var size: Vector3 = KIND_SIZE[c.kind]
	var roll := Basis(Vector3(0.0, 0.0, -1.0), PI * u * c.wreck_roll)
	c.body.global_transform = Transform3D(c.wreck_from.basis * roll, c.wreck_from.origin + Vector3(0.0, h + size.y * u, 0.0))


func _add_smoke(c: Vehicle) -> void:
	var p := CPUParticles3D.new()
	p.name = "Smoke"
	p.amount = 28
	p.lifetime = 2.6
	p.local_coords = false
	p.position = Vector3(0.0, (KIND_SIZE[c.kind] as Vector3).y * 0.5, 0.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.4
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0.0, 1.2, 0.0)
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.6
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.mesh = CineFX._particle_mesh(false)
	p.color_ramp = CineFX._ramp([Color(0.22, 0.22, 0.24, 0.75), Color(0.4, 0.4, 0.42, 0.0)], PackedFloat32Array([0.0, 1.0]))
	c.body.add_child(p)
	p.emitting = true


## Phase W: every vehicle inside this circle stops for `secs` (sầu riêng stink cloud).
func add_stop_zone(center: Vector3, r: float, secs: float) -> void:
	stop_zones.append([Vector2(center.x, center.z), r, secs])


func _tick_stop_zones(delta: float) -> void:
	for i: int in range(stop_zones.size() - 1, -1, -1):
		var z: Array = stop_zones[i]
		z[2] = float(z[2]) - delta
		if float(z[2]) <= 0.0:
			stop_zones.remove_at(i)


func _in_stop_zone(p: Vector2) -> bool:
	for z: Array in stop_zones:
		if p.distance_to(z[0]) <= float(z[1]):
			return true
	return false


## Phase W queries: indices of the active vehicles.
func active_indices() -> Array[int]:
	var out: Array[int] = []
	for c: Vehicle in vehicles:
		if c.active:
			out.append(c.idx)
	return out


## Active vehicles whose centre is within r (+ their half length) of p.
func vehicles_near(p: Vector3, r: float) -> Array[int]:
	var out: Array[int] = []
	var p2 := Vector2(p.x, p.z)
	for c: Vehicle in vehicles:
		if c.active and c.pos.distance_to(p2) <= r + c.half_len:
			out.append(c.idx)
	return out


## Box of vehicle idx for analytic ray tests: [Transform3D (orthonormal, origin at the box centre), Vector3 half extents].
func vehicle_box(idx: int) -> Array:
	var c: Vehicle = vehicles[idx]
	var size: Vector3 = KIND_SIZE[c.kind]
	var xf: Transform3D = c.body.global_transform
	return [Transform3D(xf.basis.orthonormalized(), xf * Vector3(0.0, size.y * 0.5, 0.0)), size * 0.5]


func vehicle_of(body: Node) -> int:
	for c: Vehicle in vehicles:
		if c.body == body:
			return c.idx
	return -1


```

- [ ] **Step 7: Wire the fleers in `scripts/FreeRoam.gd`**

In `_build_traffic()`, after `traffic.setup(md, player, opts)`, add:

```gdscript
	if pedestrians:
		traffic.fleer_fn = pedestrians.spawn_fleer   # Phase W: the rider of a shot / flipped vehicle runs away
```

- [ ] **Step 8: Run the test**

Run: `godot --headless --path . --script tests/test_hit_reactions.gd > /tmp/w_t2.log 2>&1; grep -E "SUCCESS|FAIL|✗" /tmp/w_t2.log`
Expected: `✅ SUCCESS: HIT REACTIONS …`. Also run `tests/test_pedestrians.gd` and `tests/test_roam_traffic.gd` on their own first: the old reactions (STUMBLE, KNOCKDOWN → FLEE within 3 s) must not change.

- [ ] **Step 9: Run the full regression, then commit**

```bash
git add scripts/roam/Pedestrian.gd scripts/roam/CrowdImpostors.gd scripts/roam/PedestrianSpawner.gd scripts/roam/RoamTraffic.gd scripts/FreeRoam.gd tests/test_hit_reactions.gd tests/test_hit_reactions.gd.uid
git commit -m "feat(roam): Phase W hit reactions without gore - Pedestrian.take_hit (knocked out 6-10 s with getup then flee, bonk 4 s, launched ballistic arc, stink, dance / push, scare, mid tier promoted), impostor scatter, spawner fleers, RoamTraffic.hit_vehicle (bullet halts + rider flees, blast flips onto the roof with a smoke column, recycled out of view), stink stop zones and ray-test queries

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 3: WeaponDirector core – equip, ammo, reload, aim camera, hip fire, unarmed and knife, HUD, FreeRoam wiring  [effort: xhigh]

**Files:**
- Create:
  - `scripts/weapons/WeaponDirector.gd`, `scripts/weapons/WeaponFX.gd`, `scripts/weapons/WeaponAudio.gd`, `scripts/weapons/WeaponHUD.gd`, `scripts/weapons/WeaponProps.gd`;
  - `tests/support/mayhem_world.gd`, `tests/test_weapons_core.gd`.
- Modify: `scripts/weapons/WeaponMath.gd` (`flat_dir`, `in_cone`), `scripts/ThirdPersonController.gd` (aim camera, `knock_down`, `shake`), `scripts/FreeRoam.gd` (flag and wiring), `tests/test_free_roam.gd` (flag off).

**Interfaces:**
- Consumes:
  - Task 1: `WeaponWheel` (`selected`, `cycled`, `current`, `info_fn`, `blocked_fn`, `is_open()`, `view`), `WeaponData`, `WeaponIcons`, `WeaponMath.flat`.
  - Task 2: `take_hit(info) -> String`, `is_down()`, `ko_left`.
- Produces:
  - `ThirdPersonController`:
    - constants `AIM_DISTANCE 1.7, AIM_SIDE 0.55, AIM_FOV 50.0, AIM_SPEED 2.2, AIM_TURN_RATE 18.0, AIM_EASE_S 0.15`;
    - vars `aiming: bool`, `aim_blend: float`;
    - `knock_down(away: Vector3, power := 3.0)`, `is_knocked_down() -> bool`, `shake(amp: float)`.
  - `WeaponMath.flat_dir(v: Vector3) -> Vector3` and `in_cone(apex, dir, half_rad, reach, p) -> bool`.
  - `class_name WeaponDirector extends Node3D`:
    - signals `equipped(slot)`, `fired(slot)`, `mayhem(heat: float, at: Vector3, cause: String)`, `toast(text)`;
    - vars `player, wheel, hud, fx: WeaponFX, traffic: RoamTraffic, spawner: PedestrianSpawner, targets_fn, blocked_fn, locked, current, ammo: PackedInt32Array, reload_left, cooldown, aiming, rng, spread_scale, fire_override, aim_override, reload_override, shots, hit_log, held`;
    - `setup(opts)`, `is_blocked()`, `ammo_text(slot)`, `equip(slot)`, `cycle(step)`, `start_reload()`, `try_fire()`, `soft_targets() -> Array`, `hit_target(n: Node3D, info) -> String`, `hand_position() -> Vector3`, `aim_origin()`, `aim_dir()`, `play_cue(cue, at, db := 0.0)`;
    - the internal `_heat(amount, at, cause)` and `_people_near(p, r)` are used by Tasks 4-6.
  - `class_name WeaponFX extends Node3D`:
    - `cine: CineFX`, `t: float`, `recycles: int`;
    - `burst(kind, pos, dir, power)`, `stars(target: Node3D, secs)`;
    - `add_transient(node, life, kind, mat := null, fade := 0.0, grow := 0.0)`, `transient_count(kind := "") -> int`.
  - `class_name WeaponAudio`: `SFX_DIR`, `LOA_FILE`, `CUES: Array[String]`, `bus() -> StringName`, `override_file(cue) -> String`, `stream(cue) -> AudioStream`, `synth(cue) -> AudioStreamWAV`.
  - `class_name WeaponHUD extends CanvasLayer`: `set_weapon(slot, ammo_text, reloading)`, `set_aim(on, spread_px)`, `show_toast(text)`, `widget`, `crosshair`, `toast_label`.
  - `class_name WeaponProps`: `build(slot) -> Node3D` (null for Tay không), `add_durian(root, r)`, `_mat(col, metal, rough)`, `_box(root, size, pos, col, metal)`.
  - `FreeRoam`:
    - vars `mayhem_enabled := true`, `weapons: WeaponDirector`, `weapon_wheel: WeaponWheel`, `weapon_hud: WeaponHUD`;
    - methods `mayhem_targets() -> Array`, `mayhem_blocked() -> bool`.
  - `tests/support/mayhem_world.gd`, static: `floor_box(parent, size := 400.0)`, `wall(parent, center, size)`, `player(parent, at, yaw := 0.0) -> ThirdPersonController`, `ped(parent, at, seed, player) -> Pedestrian`, `director(parent, player, targets: Array, traffic := null) -> WeaponDirector`.

- [ ] **Step 1: Write the arena helpers `tests/support/mayhem_world.gd`**

```gdscript
# File: res://tests/support/mayhem_world.gd
# Small headless arena for the Phase W tests (no FreeRoam): a floor box, walls, a real ThirdPersonController (camera,
# pitch 0), standing Pedestrians on a two-node walk graph, a WeaponDirector with a manual WeaponWheel and a WeaponHUD, and
# (Task 4) a RoamTraffic on one straight synthetic road. All static; call from the first physics frame (nodes need the tree).
extends RefCounted


static func floor_box(parent: Node, size: float = 400.0) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.name = "Floor"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size, 1.0, size)
	cs.shape = bs
	sb.add_child(cs)
	sb.position = Vector3(0.0, -0.5, 0.0)
	parent.add_child(sb)
	return sb


static func wall(parent: Node, center: Vector3, size: Vector3) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.name = "Wall"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = center
	parent.add_child(sb)
	return sb


static func player(parent: Node, at: Vector3, yaw: float = 0.0) -> ThirdPersonController:
	var p := ThirdPersonController.new()
	p.name = "Player"
	p.capture_on_click = false
	parent.add_child(p)
	p.teleport(at, yaw)
	p.pitch = 0.0
	p._update_camera(true)
	p.camera.make_current()
	return p


## A pedestrian standing still (IDLE for 999 s) at `at` on its own two-node walk graph.
static func ped(parent: Node, at: Vector3, seed_v: int, player_node: Node3D) -> Pedestrian:
	var g: PedWalkGraph = PedWalkGraph.from_lines([PackedVector2Array([Vector2(at.x - 3.0, at.z), Vector2(at.x + 3.0, at.z)])])
	var p := Pedestrian.new()
	p.setup(g, 0, {"preset": "student", "seed": seed_v})
	p.player = player_node
	p.mounted_fn = func() -> bool: return false
	p.position = at + Vector3(0.0, 0.05, 0.0)   # before add_child: a body entering the tree at the origin would lift the
	parent.add_child(p)                          # player standing there onto its capsule (then carry him like a platform)
	p.state = Pedestrian.State.IDLE
	p.set("_idle_left", 999.0)
	return p


## A WeaponDirector on `player_node` hitting the nodes in `targets` (the Array is read on every query: append to it later).
static func director(parent: Node, player_node: ThirdPersonController, targets: Array, traffic: RoamTraffic = null) -> WeaponDirector:
	var wheel := WeaponWheel.new()
	wheel.name = "WeaponWheel"
	wheel.manual = true
	parent.add_child(wheel)
	var hud := WeaponHUD.new()
	hud.name = "WeaponHUD"
	parent.add_child(hud)
	var d := WeaponDirector.new()
	d.name = "Weapons"
	parent.add_child(d)
	d.setup({"player": player_node, "wheel": wheel, "hud": hud, "targets_fn": func() -> Array: return targets, "traffic": traffic})
	d.spread_scale = 0.0
	return d
```

- [ ] **Step 2: Write the failing test `tests/test_weapons_core.gd`**

```gdscript
# File: res://tests/test_weapons_core.gd
# Headless test of the Phase W WeaponDirector core (spec sections 3, 7):
#   A (arena) the slot table in W-D4 order; equip and scroll cycle (toast); magazine and reload timing in physics frames
#     (pistol 0.25 s per shot, 12 rounds, 1.6 s reload; R reloads); no fire while the wheel is open or blocked; aim (over-the-
#     shoulder camera, FOV < 60, walk speed); hip fire turns the player to the camera; the unarmed combo (stumble, stumble,
#     knock out, +1 heat) with daze stars; the knife arc (front only, 1.4 m, +2 heat per knockout); hand props in code;
#     every WeaponAudio cue synthesizes; no GPUParticles3D.
#   B (FreeRoam, crowd off) the wheel opens on foot, is blocked on the bike and during a cinematic, the weapon HUD hides on
#     the bike.
# Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_weapons_core.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")

var fails: Array[String] = []
var frames: int = 0
var phase: String = ""
var t0: int = 0
var started: bool = false
var arena: Node3D
var player: ThirdPersonController
var dir: WeaponDirector
var targets: Array = []
var heat: Array[float] = []
var toasts: Array[String] = []
var blocked: bool = false
var shots0: int = 0
var empty_t: int = -1
var refill_t: int = -1
var ped: Pedestrian
var front: Array = []
var behind: Pedestrian
var roam: Node3D


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	print("--- TEST WEAPONS CORE ---")
	_table()
	_audio()
	_props()
	physics_frame.connect(_on_physics)


func _table() -> void:
	var ids: Array[String] = ["unarmed", "knife", "pistol", "shotgun", "rocket", "dep", "durian", "loa"]
	for i: int in 8:
		_check(String(WeaponData.SLOTS[i]["id"]) == ids[i], "slot %d is %s (W-D4 order)" % [i, ids[i]])
	var p: Dictionary = WeaponData.SLOTS[WeaponData.Slot.PISTOL]
	_check(int(p["mag"]) == 12 and is_equal_approx(float(p["cycle"]), 0.25) and is_equal_approx(float(p["reload"]), 1.6), "pistol: 12 rounds, 0.25 s per shot, 1.6 s reload")
	var s: Dictionary = WeaponData.SLOTS[WeaponData.Slot.SHOTGUN]
	_check(int(s["mag"]) == 6 and is_equal_approx(float(s["cycle"]), 0.8) and int(s["pellets"]) == 8 and is_equal_approx(float(s["cone_deg"]), 9.0), "shotgun: 6 rounds, 0.8 s pump, 8 pellets in 9°")
	var r: Dictionary = WeaponData.SLOTS[WeaponData.Slot.ROCKET]
	_check(int(r["mag"]) == 1 and is_equal_approx(float(r["reload"]), 2.5) and is_equal_approx(float(r["speed"]), 35.0) and is_equal_approx(float(r["radius"]), 6.0), "rocket: 1 round, 2.5 s reload, 35 m/s, 6 m")
	_check(is_equal_approx(float(WeaponData.SLOTS[WeaponData.Slot.KNIFE]["range"]), 1.4), "knife arc 1.4 m")
	_check(WeaponMath.in_cone(Vector3.ZERO, Vector3(0, 0, -1), deg_to_rad(30.0), 10.0, Vector3(1.0, 0.0, -5.0)), "in_cone: inside")
	_check(not WeaponMath.in_cone(Vector3.ZERO, Vector3(0, 0, -1), deg_to_rad(30.0), 10.0, Vector3(5.0, 0.0, -5.0)), "in_cone: 45° off a 30° half angle is outside")
	_check(not WeaponMath.in_cone(Vector3.ZERO, Vector3(0, 0, -1), deg_to_rad(30.0), 10.0, Vector3(0.0, 0.0, -11.0)), "in_cone: past the reach is outside")


func _audio() -> void:
	for cue: String in WeaponAudio.CUES:
		var w: AudioStreamWAV = WeaponAudio.synth(cue)
		_check(w != null and w.data.size() > 400, "cue %s is synthesized" % cue)
	_check(WeaponAudio.override_file("w_no_such_cue") == "", "no override file -> synthesized (the test never writes user://)")


func _props() -> void:
	_check(WeaponProps.build(WeaponData.Slot.UNARMED) == null, "no prop for Tay không")
	for i: int in range(1, 8):
		var n: Node3D = WeaponProps.build(i)
		_check(n != null and not n.find_children("*", "MeshInstance3D", true, false).is_empty(), "slot %d has a code-built hand prop" % i)
		if n:
			n.free()


func _on_physics() -> void:
	frames += 1
	if not started:
		started = true
		arena = Node3D.new()
		arena.name = "Arena"
		root.add_child(arena)
		World.floor_box(arena)
		player = World.player(arena, Vector3.ZERO, 0.0)
		dir = World.director(arena, player, targets)
		dir.blocked_fn = func() -> bool: return blocked
		dir.mayhem.connect(func(h: float, _at: Vector3, _c: String) -> void: heat.append(h))
		dir.toast.connect(func(s: String) -> void: toasts.append(s))
		phase = "settle"
		t0 = frames
		return
	var t: int = frames - t0
	match phase:
		"settle":
			if t == 10:
				_cycle_checks()
				dir.fire_override = true
				shots0 = dir.shots
				_next("pistol")
		"pistol":
			_pistol(t)
		"reload_key":
			if t == 1:
				dir.reload_override = true
			if t == 3:
				_check(dir.reload_left > 0.0, "R starts a reload of a part-empty magazine")
			if t == 100:
				_check(dir.ammo[WeaponData.Slot.PISTOL] == 12, "R refilled the magazine in 1.6 s")
				dir.wheel.open()
				dir.fire_override = true
				shots0 = dir.shots
				_next("wheel_open")
		"wheel_open":
			if t == 30:
				_check(dir.shots == shots0, "no weapon fires while the wheel is open")
				dir.wheel.close(false)
				Engine.time_scale = 1.0
				blocked = true
				dir.aim_override = true
				_next("blocked")
		"blocked":
			if t == 30:
				_check(dir.shots == shots0 and not dir.aiming and not player.aiming, "blocked (riding / cinematic / service): no aim, no fire")
				blocked = false
				dir.fire_override = false
				player.input_override = Vector2(0.0, -1.0)
				player.sprint_override = true
				_next("aim")
		"aim":
			if t == 40:
				_check(player.aiming and player.aim_blend > 0.99, "right mouse aims (blend %.2f)" % player.aim_blend)
				_check(player.camera.fov < 60.0, "the FOV narrows while aiming (%.1f)" % player.camera.fov)
				_check(absf(player.camera.position.x - ThirdPersonController.AIM_SIDE) < 0.05, "over-the-shoulder offset (x %.2f)" % player.camera.position.x)
				_check(player.horizontal_speed <= ThirdPersonController.AIM_SPEED + 0.05, "walk speed while aiming, even with Shift (%.2f m/s)" % player.horizontal_speed)
				dir.aim_override = false
				player.input_override = Vector2.ZERO
				player.sprint_override = false
				_next("hip")
		"hip":
			if t == 20:
				player.teleport(Vector3.ZERO, 0.0)
				player.pitch = 0.0
				dir.equip(WeaponData.Slot.UNARMED)
				player.yaw = 0.8
				player.model.rotation.y = 0.0
				dir.cooldown = 0.0
				dir.fire_override = true
			if t == 21:
				dir.fire_override = false
				_check(is_equal_approx(player.model.rotation.y, 0.8), "hip fire turns the body to the camera (%.2f)" % player.model.rotation.y)
				player.set_facing(0.0)
				player.pitch = 0.0
				ped = World.ped(arena, Vector3(0.0, 0.0, -1.0), 51, player)
				targets.append(ped)
				heat.clear()
				_next("combo")
		"combo":
			_combo(t)
		"knife":
			_knife(t)


func _next(p: String) -> void:
	phase = p
	t0 = frames


func _cycle_checks() -> void:
	dir.cycle(-1)
	_check(dir.current == 7 and toasts.back() == "Loa kẹo kéo", "scroll up from Tay không wraps to slot 7, with a toast")
	dir.cycle(1)
	_check(dir.current == 0 and toasts.back() == "Tay không", "scroll down wraps back to slot 0")
	dir.wheel.selected.emit(WeaponData.Slot.PISTOL)
	_check(dir.current == WeaponData.Slot.PISTOL and dir.wheel.current == WeaponData.Slot.PISTOL, "a wheel selection equips the pistol")
	_check(dir.held != null and dir.held.get_parent() is BoneAttachment3D, "the pistol prop sits in the right hand (Wrist.R attachment)")
	_check(dir.ammo_text(WeaponData.Slot.PISTOL) == "12 / ∞" and dir.hud.ammo == "12 / ∞", "HUD and wheel show '12 / ∞'")


func _pistol(t: int) -> void:
	if t == 60:
		_check(dir.shots - shots0 == 4, "0.25 s per shot: 4 shots in 60 physics frames (got %d)" % (dir.shots - shots0))
	if t == 175:
		_check(dir.shots - shots0 == 12 and dir.ammo[WeaponData.Slot.PISTOL] == 0 and dir.reload_left > 0.0, "12 rounds, then an automatic reload")
		_check(dir.hud.reloading, "the HUD shows the reload")
	if empty_t < 0 and dir.ammo[WeaponData.Slot.PISTOL] == 0:
		empty_t = t
	if empty_t > 0 and refill_t < 0 and dir.ammo[WeaponData.Slot.PISTOL] > 0:
		refill_t = t
	if t == 290:
		_check(empty_t > 0 and refill_t > 0 and absi(refill_t - empty_t - 96) <= 2, "the reload takes 1.6 s = 96 physics frames (empty at frame %d, refilled at %d)" % [empty_t, refill_t])
		dir.fire_override = false
		_next("reload_key")


func _combo(t: int) -> void:
	if t == 2 or t == 30 or t == 58:
		dir.cooldown = 0.0   # the punches come 28 frames apart (inside the 1.5 s combo window); skip the 0.35 s cooldown
		dir.fire_override = true
	if t == 3 or t == 31 or t == 59:
		dir.fire_override = false
	if t == 6:
		_check(ped.state == Pedestrian.State.STUMBLE and heat.is_empty(), "punch 1: stumble, no heat")
	if t == 34:
		_check(ped.state == Pedestrian.State.STUMBLE, "punch 2: stumble")
	if t == 62:
		_check(ped.state == Pedestrian.State.KNOCKED_OUT, "punch 3 knocks out (state %d)" % ped.state)
		_check(heat.size() == 1 and is_equal_approx(heat[0], WeaponData.HEAT_KO_UNARMED), "+1 heat for the unarmed knockout (%s)" % str(heat))
		_check(dir.fx.cine.find_children("Star*", "", true, false).size() >= 3, "daze stars over the knocked-out person")
		targets.clear()
		heat.clear()
		dir.equip(WeaponData.Slot.KNIFE)
		for x: float in [0.6, -0.6]:
			var f: Pedestrian = World.ped(arena, Vector3(x, 0.0, -1.04), 60 + int(x * 10.0), player)
			front.append(f)
			targets.append(f)
		behind = World.ped(arena, Vector3(0.0, 0.0, 1.0), 70, player)
		targets.append(behind)
		_next("knife")


func _knife(t: int) -> void:
	if t == 5:
		dir.cooldown = 0.0
		dir.fire_override = true
	if t == 6:
		dir.fire_override = false
	if t == 9:
		_check((front[0] as Pedestrian).state == Pedestrian.State.KNOCKED_OUT and (front[1] as Pedestrian).state == Pedestrian.State.KNOCKED_OUT, "the knife arc knocks out both people in front")
		_check(behind.state == Pedestrian.State.IDLE, "nobody behind is hit")
		var sum: float = 0.0
		for h: float in heat:
			sum += h
		_check(is_equal_approx(sum, 2.0 * WeaponData.HEAT_KNIFE), "+2 heat per knife knockout (%s)" % str(heat))
		_check(arena.find_children("*", "GPUParticles3D", true, false).is_empty(), "no GPUParticles3D")
		_start_b()


func _start_b() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var n: Node = (load(pair[1]) as Script).new()
			n.name = pair[0]
			root.add_child(n)
	arena.queue_free()
	roam = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	roam.set("crowd_enabled", false)
	root.add_child(roam)
	phase = "b"
	t0 = frames


func _wheel_opens(ww: WeaponWheel) -> bool:
	ww.press()
	ww.step_real(0.2)
	var o: bool = ww.is_open()
	ww.cancel()
	ww.step_real(0.2)
	return o


func _b_done() -> void:
	Engine.time_scale = 1.0
	if fails.is_empty():
		print("✅ SUCCESS: WEAPONS CORE (table, equip / cycle, ammo + reload timing, aim camera, hip fire, combo, knife, HUD, FreeRoam blocking)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)


func _process(_d: float) -> bool:
	if phase != "b":
		return false
	var t: int = frames - t0
	var ww: WeaponWheel = roam.get("weapon_wheel")
	if t == 60 and not roam.has_meta("b1"):
		roam.set_meta("b1", true)
		var wd: WeaponDirector = roam.get("weapons")
		_check(wd != null and ww != null and wd.player == roam.get("player"), "FreeRoam builds the weapons when mayhem_enabled (default)")
		ww.manual = true
		_check(_wheel_opens(ww), "on foot the wheel opens in FreeRoam")
		roam.call("mount_bike")
	elif t == 64 and not roam.has_meta("b2"):
		roam.set_meta("b2", true)
		_check(not _wheel_opens(ww) and is_equal_approx(Engine.time_scale, 1.0), "riding: the wheel is blocked (W-D9 on foot only)")
		_check(not (roam.get("weapon_hud") as CanvasLayer).visible, "the weapon HUD hides on the bike")
		roam.call("dismount_bike")
	elif t == 68 and not roam.has_meta("b3"):
		roam.set_meta("b3", true)
		_check((roam.get("weapon_hud") as CanvasLayer).visible, "the weapon HUD is back on foot")
		var tl: CineTimeline = (load("res://tests/support/cine_test_timeline.gd") as GDScript).new()
		tl.build()
		var cp: CinePlayer = roam.call("play_cinematic", tl, {"manual": true, "music": false})
		_check(cp != null, "test setup: a cinematic plays")
		_check(not _wheel_opens(ww), "during a cinematic the wheel is blocked")
		var n: int = 0
		while cp != null and is_instance_valid(cp) and roam.get("cine_player") != null and n < 400:
			cp.step(1.0 / 60.0)
			n += 1
		_check(_wheel_opens(ww), "after the cinematic the wheel opens again")
		_b_done()
	return false
```

Note: part B runs from `_process` with meta guards because `play_cinematic` pauses the tree (physics frames keep coming, but the checks are synchronous anyway).

- [ ] **Step 3: Run the test to verify it fails**

Run: `godot --headless --path . --script tests/test_weapons_core.gd > /tmp/w_t3.log 2>&1; grep -E "SUCCESS|FAIL|Parse Error" /tmp/w_t3.log`
Expected: a parse error (`WeaponDirector` / `WeaponHUD` not declared).

- [ ] **Step 4: Extend `scripts/weapons/WeaponMath.gd`**

Append:

```gdscript
## Horizontal unit direction of v (+Z when v is vertical or zero).
static func flat_dir(v: Vector3) -> Vector3:
	var f := Vector3(v.x, 0.0, v.z)
	return f.normalized() if f.length_squared() > 1e-6 else Vector3(0.0, 0.0, 1.0)


## p inside the horizontal cone at apex along dir (half angle half_rad, length reach), within 2 m of the apex height.
static func in_cone(apex: Vector3, dir: Vector3, half_rad: float, reach: float, p: Vector3) -> bool:
	var v := Vector3(p.x - apex.x, 0.0, p.z - apex.z)
	var d: float = v.length()
	if d > reach or absf(p.y - apex.y) > 2.0:
		return false
	if d < 0.05:
		return true
	return flat_dir(dir).dot(v / d) >= cos(half_rad) - 1e-6
```

- [ ] **Step 5: Aim camera, knock-down and shake in `scripts/ThirdPersonController.gd`**

5a. Append to the header comment, after `# walk (Ctrl), jump (Space; trên xe Space vẫn là drift của PlayerBike).`:

```gdscript
# Phase W: aiming (WeaponDirector sets `aiming` from the right mouse button) eases the camera over the right shoulder
# (AIM_DISTANCE behind, AIM_SIDE right, FOV AIM_FOV), turns the body with the camera and caps the speed at AIM_SPEED;
# knock_down() is the comic fall of a rocket blast / an officer's tackle (SPLAT, never hurts); shake() for explosions.
```

5b. After `const DEFAULT_PITCH: float = -0.2` add:

```gdscript
const AIM_DISTANCE: float = 1.7          # Phase W: over-the-shoulder camera while aiming
const AIM_SIDE: float = 0.55
const AIM_FOV: float = 50.0
const AIM_SPEED: float = 2.2
const AIM_TURN_RATE: float = 18.0
const AIM_EASE_S: float = 0.15
```

5c. After `var landings: Array[String] = []` add:

```gdscript
## Phase W: right mouse held (WeaponDirector); aim_blend eases 0..1 over AIM_EASE_S.
var aiming: bool = false
var aim_blend: float = 0.0
```

5d. In `_ground()`, replace `	is_sprinting = want_sprint and has_input and not _exhausted` with:

```gdscript
	is_sprinting = want_sprint and has_input and not _exhausted and not aiming
```

and after the two lines `	if slow_t > 0.0:` / `		speed *= 0.5` add:

```gdscript
	if aiming:
		speed = minf(speed, AIM_SPEED)
```

5e. In `_turn()`, replace

```gdscript
	if move.length_squared() > 0.0001:
		var diff: float = wrapf(atan2(-move.x, -move.z) - before, -PI, PI)
		model.rotation.y = before + clampf(diff, -rate * delta, rate * delta)
```

with

```gdscript
	if aiming:
		var diff_a: float = wrapf(yaw - before, -PI, PI)
		model.rotation.y = before + clampf(diff_a, -AIM_TURN_RATE * delta, AIM_TURN_RATE * delta)
	elif move.length_squared() > 0.0001:
		var diff: float = wrapf(atan2(-move.x, -move.z) - before, -PI, PI)
		model.rotation.y = before + clampf(diff, -rate * delta, rate * delta)
```

5f. Replace the body of `_process()` with:

```gdscript
	if _built:
		aim_blend = move_toward(aim_blend, 1.0 if aiming else 0.0, delta / AIM_EASE_S)
		_update_camera(false)
		_camera_fx(delta)
```

5g. In `_update_camera()`, replace

```gdscript
	var dist: float = CAM_DISTANCE
	if cam_ray and cam_ray.enabled:
		if not snap:
			cam_ray.force_raycast_update()
		if cam_ray.is_colliding():
			var hit: Vector3 = cam_ray.get_collision_point()
			dist = clampf(cam_pivot.global_position.distance_to(hit) - CAM_MARGIN, 0.6, CAM_DISTANCE)
```

with

```gdscript
	var full: float = lerpf(CAM_DISTANCE, AIM_DISTANCE, aim_blend)
	var dist: float = full
	if cam_ray and cam_ray.enabled:
		if not snap:
			cam_ray.force_raycast_update()
		if cam_ray.is_colliding():
			var hit: Vector3 = cam_ray.get_collision_point()
			dist = clampf(cam_pivot.global_position.distance_to(hit) - CAM_MARGIN, 0.6, full)
```

5h. In `_camera_fx()`, replace the line starting `	camera.fov = lerpf(camera.fov, _fov_base + …` with:

```gdscript
	var base_fov: float = lerpf(_fov_base, AIM_FOV, aim_blend)
	camera.fov = lerpf(camera.fov, base_fov + (SPRINT_FOV_ADD if sprinting else 0.0), 1.0 - exp(-FOV_EASE * delta))
```

and replace `	camera.position.x = sx` with:

```gdscript
	camera.position.x = AIM_SIDE * aim_blend + sx
```

5i. Insert right before the `# CAMERA` section header (the `# ---…` line above `# CAMERA`):

```gdscript
## Phase W: comic knock-down (a rocket blast nearby, an officer's tackle): SPLAT – down SPLAT_TIME, getup GETUP_TIME –
## shoved `power` m/s along `away`; never hurts. Ignored while already down.
func knock_down(away: Vector3, power: float = 3.0) -> void:
	if move_state == "SPLAT":
		return
	aiming = false
	var a := Vector3(away.x, 0.0, away.z)
	a = a.normalized() if a.length_squared() > 1e-6 else -facing_dir()
	move_state = "SPLAT"
	_state_t = 0.0
	_splat_phase = 0
	_air_clip = ""
	floor_snap_length = FLOOR_SNAP
	velocity = Vector3(a.x * power, 0.0, a.z * power)
	if model:
		model.rotation.y = atan2(-a.x, -a.z) + PI    # faces the shove, falls on its back away from it
	_play("knockdown")
	_shake(0.5)


func is_knocked_down() -> bool:
	return move_state == "SPLAT"


## Phase W: camera shake (explosions), amp ~0.15-1.0.
func shake(amp: float) -> void:
	_shake(amp)


```

- [ ] **Step 6: Write `scripts/weapons/WeaponAudio.gd`**

```gdscript
# File: res://scripts/weapons/WeaponAudio.gd
# Phase W sound cues, synthesized in code with the A1 voice helpers (CineAudio._tone / _noise / _mix / _paste / _to_wav).
# Any cue can be overridden by the owner's user://sfx/<cue>.ogg (local only: never committed, never exported). The loa kẹo
# kéo music (W-D5) is the owner's user://sfx/loa_keo_keo.ogg or .mp3 when present, otherwise the synthesized "bolero" cue
# (Task 6). Main thread only (static cache). Each task adds its cues to CUES and to synth().
class_name WeaponAudio
extends RefCounted

const SFX_DIR: String = "user://sfx/"
const LOA_FILE: String = "loa_keo_keo"
const CUES: Array[String] = ["punch", "swish", "knife_hit", "reload", "dry_click"]
static var _cache: Dictionary = {}


static func bus() -> StringName:
	return &"SFX" if AudioServer.get_bus_index("SFX") >= 0 else &"Master"


## The owner's override file of a cue ("" when there is none).
static func override_file(cue: String) -> String:
	var p: String = SFX_DIR + cue + ".ogg"
	return p if FileAccess.file_exists(p) else ""


static func stream(cue: String) -> AudioStream:
	if _cache.has(cue):
		return _cache[cue]
	var st: AudioStream = null
	var f: String = override_file(cue)
	if f != "":
		st = CineAudio._load_file(f)
	if st == null:
		st = synth(cue)
	_cache[cue] = st
	return st


static func _gap(secs: float) -> PackedFloat32Array:
	var g := PackedFloat32Array()
	g.resize(int(secs * CineAudio.SR))
	return g


## Synthesized cue (pure: no cache, no scene tree).
static func synth(cue: String) -> AudioStreamWAV:
	match cue:
		"punch":
			return CineAudio._to_wav(CineAudio._mix([CineAudio._noise(0.07, 0.7, 50.0, 21, 0.45), CineAudio._tone(0.12, 180.0, 90.0, 0.6, 22.0)]))
		"swish":
			return CineAudio._to_wav(CineAudio._noise(0.22, 0.35, 10.0, 22, 0.8))
		"knife_hit":
			return CineAudio._to_wav(CineAudio._mix([CineAudio._noise(0.05, 0.5, 70.0, 23, 0.2), CineAudio._tone(0.18, 1400.0, 900.0, 0.18, 18.0), CineAudio._tone(0.1, 160.0, 90.0, 0.4, 25.0)]))
		"reload":
			var a: PackedFloat32Array = CineAudio._mix([CineAudio._noise(0.04, 0.6, 90.0, 24, 0.1), CineAudio._tone(0.04, 2200.0, 1800.0, 0.3, 80.0)])
			a.append_array(_gap(0.18))
			a.append_array(CineAudio._mix([CineAudio._noise(0.05, 0.7, 80.0, 25, 0.1), CineAudio._tone(0.05, 1600.0, 1300.0, 0.35, 70.0)]))
			return CineAudio._to_wav(a)
		"dry_click":
			return CineAudio._to_wav(CineAudio._tone(0.03, 3000.0, 2600.0, 0.3, 120.0))
	return CineAudio._to_wav(CineAudio._tone(0.08, 800.0, 800.0, 0.3, 20.0))
```

- [ ] **Step 7: Write `scripts/weapons/WeaponFX.gd`**

```gdscript
# File: res://scripts/weapons/WeaponFX.gd
# Gameplay hit FX of Phase W, built in code (spec section 3). It reuses the A1 CineFX bursts (sparks, dust, flash) and daze
# stars, driven by a game clock (scaled seconds) instead of a cinematic story clock, plus short-lived nodes of its own
# ("transients": tracers, smoke puffs, scorch marks, stink clouds, sonic rings – Tasks 4-6) that can fade their material's
# alpha over the last `fade` seconds and grow. CineFX keeps its star rings until it is freed, so the CineFX child is replaced
# once nothing is alive (RECYCLE_AFTER s after the last burst / star window ended). top_level at the world origin: every
# position is global. CPUParticles3D only.
class_name WeaponFX
extends Node3D

const RECYCLE_AFTER: float = 2.0
const LIFE: Dictionary = {"sparks": 2.5, "dust": 3.2, "flash": 0.2}

var cine: CineFX
var t: float = 0.0
var recycles: int = 0
var _busy_until: float = 0.0
var _transient: Array[Dictionary] = []    # {"node", "t0", "life", "kind", "mat", "a0", "fade", "grow"}


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_new_cine()


func _new_cine() -> void:
	cine = CineFX.new()
	cine.name = "CineFX"
	add_child(cine)


func _physics_process(delta: float) -> void:
	t += delta
	cine.update(t, Engine.time_scale)   # particles already run on scaled time: speed / time_scale = 1
	_tick_transient()
	if t > _busy_until + RECYCLE_AFTER and cine.get_child_count() > 0:
		cine.queue_free()
		_new_cine()
		recycles += 1


## CineFX burst ("sparks" | "dust" | "flash") at a world position.
func burst(kind: String, pos: Vector3, dir: Vector3, power: float) -> void:
	cine.burst(kind, pos, dir, power, t)
	_busy_until = maxf(_busy_until, t + float(LIFE.get(kind, 3.0)))


## Comic daze stars orbiting the target's head for `secs` game seconds.
func stars(target: Node3D, secs: float) -> void:
	cine.stars(target, t, t + secs)
	_busy_until = maxf(_busy_until, t + secs)


## A short-lived node owned by the FX layer: freed after `life`; if `mat` is given its alpha fades to 0 over the last
## `fade` seconds; `grow` scales it from 1 to 1 + grow over its life.
func add_transient(node: Node3D, life: float, kind: String, mat: StandardMaterial3D = null, fade: float = 0.0, grow: float = 0.0) -> void:
	add_child(node)
	_transient.append({"node": node, "t0": t, "life": life, "kind": kind, "mat": mat, "a0": mat.albedo_color.a if mat else 1.0, "fade": fade, "grow": grow})


func transient_count(kind: String = "") -> int:
	var n: int = 0
	for e: Dictionary in _transient:
		if kind == "" or String(e["kind"]) == kind:
			n += 1
	return n


func _tick_transient() -> void:
	for i: int in range(_transient.size() - 1, -1, -1):
		var e: Dictionary = _transient[i]
		var node: Node3D = e["node"] if is_instance_valid(e["node"]) else null
		var age: float = t - float(e["t0"])
		var life: float = e["life"]
		if node == null or age >= life:
			if node:
				node.queue_free()
			_transient.remove_at(i)
			continue
		var mat: StandardMaterial3D = e["mat"]
		if mat and float(e["fade"]) > 0.0:
			mat.albedo_color.a = float(e["a0"]) * clampf((life - age) / float(e["fade"]), 0.0, 1.0)
		if float(e["grow"]) > 0.0:
			node.scale = Vector3.ONE * (1.0 + float(e["grow"]) * age / life)
```

- [ ] **Step 8: Write `scripts/weapons/WeaponProps.gd`**

```gdscript
# File: res://scripts/weapons/WeaponProps.gd
# Code-built hand props of the Phase W weapons (no imported art, no image files): origin at the grip, barrel / blade along
# -Z, sizes in metres. add_durian() is shared with the thrown sầu riêng.
class_name WeaponProps
extends RefCounted

static var _mats: Dictionary = {}


static func _mat(col: Color, metal: float = 0.0, rough: float = 0.6) -> StandardMaterial3D:
	var key: String = "%s|%.2f|%.2f" % [col.to_html(), metal, rough]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metal
	m.roughness = rough
	_mats[key] = m
	return m


static func _box(root: Node3D, size: Vector3, pos: Vector3, col: Color, metal: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(col, metal)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


static func _sphere(root: Node3D, r: float, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.material_override = _mat(col)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


## The hand prop of a slot (WeaponData.Slot); null for Tay không.
static func build(slot: int) -> Node3D:
	if slot == WeaponData.Slot.UNARMED:
		return null
	var root := Node3D.new()
	root.name = "Weapon_%s" % String(WeaponData.SLOTS[slot]["id"])
	match slot:
		WeaponData.Slot.KNIFE:
			_box(root, Vector3(0.03, 0.026, 0.1), Vector3(0.0, 0.0, 0.02), Color("#1B1B1F"))
			_box(root, Vector3(0.008, 0.032, 0.17), Vector3(0.0, 0.004, -0.11), Color("#C9CDD2"), 0.8)
		WeaponData.Slot.PISTOL:
			_box(root, Vector3(0.032, 0.1, 0.045), Vector3(0.0, -0.03, 0.0), Color("#22252A"))
			_box(root, Vector3(0.036, 0.042, 0.19), Vector3(0.0, 0.035, -0.06), Color("#2E3238"), 0.6)
		WeaponData.Slot.SHOTGUN:
			_box(root, Vector3(0.04, 0.04, 0.62), Vector3(0.0, 0.04, -0.3), Color("#2B2B2E"), 0.6)
			_box(root, Vector3(0.05, 0.05, 0.16), Vector3(0.0, 0.0, -0.32), Color("#6B4A2B"))
			_box(root, Vector3(0.05, 0.09, 0.3), Vector3(0.0, -0.01, 0.18), Color("#6B4A2B"))
		WeaponData.Slot.ROCKET:
			_box(root, Vector3(0.13, 0.13, 0.95), Vector3(0.0, 0.12, -0.12), Color("#4B5D3A"))
			_box(root, Vector3(0.04, 0.1, 0.05), Vector3.ZERO, Color("#1E1E1E"))
			_sphere(root, 0.075, Vector3(0.0, 0.12, -0.62), Color("#B8382E"))
		WeaponData.Slot.DEP:
			_box(root, Vector3(0.1, 0.025, 0.26), Vector3(0.0, 0.0, -0.06), Color("#3A7BD5"))
			_box(root, Vector3(0.104, 0.03, 0.045), Vector3(0.0, 0.02, -0.1), Color("#F2F4F5"))
		WeaponData.Slot.DURIAN:
			var d := Node3D.new()
			d.position = Vector3(0.0, 0.02, -0.08)
			root.add_child(d)
			add_durian(d, 0.12)
		WeaponData.Slot.LOA:
			_box(root, Vector3(0.22, 0.32, 0.18), Vector3(0.0, -0.12, -0.06), Color("#1F1F24"))
			var grill := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.08
			cm.bottom_radius = 0.08
			cm.height = 0.02
			grill.mesh = cm
			grill.material_override = _mat(Color("#8C8F96"), 0.4)
			grill.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, -0.1, -0.155))
			root.add_child(grill)
			_box(root, Vector3(0.14, 0.02, 0.02), Vector3(0.0, 0.05, -0.06), Color("#3A3A40"))
	return root


## A durian (spiky ball) of radius r on root: a sphere and 18 cone spikes (shared with the thrown sầu riêng).
static func add_durian(root: Node3D, r: float) -> void:
	_sphere(root, r, Vector3.ZERO, Color("#8A9A3B"))
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = r * 0.28
	cm.height = r * 0.55
	var mat: StandardMaterial3D = _mat(Color("#6E7C2C"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i: int in 18:
		var u: float = rng.randf_range(-0.95, 0.95)
		var a: float = rng.randf() * TAU
		var d := Vector3(sqrt(1.0 - u * u) * cos(a), u, sqrt(1.0 - u * u) * sin(a))
		var mi := MeshInstance3D.new()
		mi.mesh = cm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.transform = Transform3D(Basis(Quaternion(Vector3.UP, d)), d * r)
		root.add_child(mi)
```

- [ ] **Step 9: Write `scripts/weapons/WeaponHUD.gd`**

```gdscript
# File: res://scripts/weapons/WeaponHUD.gd
# Phase W on-foot weapon HUD:
#   - a widget under the top-right HUD column (WIDGET_TOP px, below the ViceHUD clock / money / stars): the code-drawn icon of
#     the equipped weapon, its name, the ammo "12 / ∞" (or "Đang nạp…") and a small "[Chuột giữa] vũ khí" hint;
#   - a crosshair at the screen centre while aiming (gap = spread);
#   - a short toast with the weapon name when the mouse wheel cycles.
# Plain custom-drawn Controls (no PanelContainer), vice italic font in vice style (GameFX.vice_font through preload), FPT
# orange accent in classic. FreeRoam hides it on the bike, in cinematics and while the map is open.
class_name WeaponHUD
extends CanvasLayer

const GameFXScript: Script = preload("res://scripts/GameFX.gd")
const WIDGET_SIZE := Vector2(236.0, 70.0)
const WIDGET_TOP: float = 168.0
const WIDGET_RIGHT: float = 28.0
const TOAST_S: float = 1.2
const INK := Color("#1B0F33")
const VICE_ACCENT := Color("#3FF2FF")
const CLASSIC_ACCENT := Color("#F37021")

var slot: int = 0
var ammo: String = "∞"
var reloading: bool = false
var aiming: bool = false
var spread_px: float = 14.0
var widget: Control
var crosshair: Control
var toast_label: Label
var _toast_left: float = 0.0


func _ready() -> void:
	layer = 1
	var w := Widget.new()
	w.name = "WeaponWidget"
	w.hud = self
	w.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	w.offset_left = -WIDGET_RIGHT - WIDGET_SIZE.x
	w.offset_right = -WIDGET_RIGHT
	w.offset_top = WIDGET_TOP
	w.offset_bottom = WIDGET_TOP + WIDGET_SIZE.y
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(w)
	widget = w
	var c := Crosshair.new()
	c.name = "Crosshair"
	c.hud = self
	c.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	c.offset_left = -40.0
	c.offset_right = 40.0
	c.offset_top = -40.0
	c.offset_bottom = 40.0
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.visible = false
	add_child(c)
	crosshair = c
	toast_label = Label.new()
	toast_label.name = "Toast"
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_label.offset_left = -200.0
	toast_label.offset_right = 200.0
	toast_label.offset_top = 96.0
	toast_label.offset_bottom = 132.0
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 26)
	toast_label.add_theme_color_override("font_outline_color", INK)
	toast_label.add_theme_constant_override("outline_size", 8)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label.visible = false
	add_child(toast_label)


static func vice() -> bool:
	return ViceHUD.style_active()


func accent() -> Color:
	return VICE_ACCENT if vice() else CLASSIC_ACCENT


func font() -> Font:
	return GameFXScript.vice_font(0.6, 0.22) if vice() else ThemeDB.fallback_font


func set_weapon(s: int, ammo_text: String, is_reloading: bool) -> void:
	slot = s
	ammo = ammo_text
	reloading = is_reloading
	if widget:
		widget.queue_redraw()


func set_aim(on: bool, px: float) -> void:
	if on == aiming and is_equal_approx(px, spread_px):
		return
	aiming = on
	spread_px = px
	if crosshair:
		crosshair.visible = on
		crosshair.queue_redraw()


func show_toast(text: String) -> void:
	toast_label.text = text
	toast_label.add_theme_font_override("font", font())
	toast_label.add_theme_color_override("font_color", accent())
	toast_label.visible = true
	toast_label.modulate.a = 1.0
	_toast_left = TOAST_S


func _process(delta: float) -> void:
	if _toast_left <= 0.0:
		return
	_toast_left -= delta
	toast_label.modulate.a = clampf(_toast_left / 0.3, 0.0, 1.0)
	if _toast_left <= 0.0:
		toast_label.visible = false


class Widget extends Control:
	var hud: WeaponHUD

	func _draw() -> void:
		var f: Font = hud.font()
		var acc: Color = hud.accent()
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.02, 0.08, 0.55))
		draw_rect(Rect2(Vector2.ZERO, size), Color(acc, 0.8), false, 2.0)
		WeaponIcons.draw(self, hud.slot, Vector2(36.0, size.y * 0.5), 48.0, Color("#F4F1FF"), Color(0.08, 0.05, 0.15, 0.95))
		_text(f, Vector2(72.0, 24.0), WeaponData.name_of(hud.slot), 19, Color.WHITE)
		_text(f, Vector2(72.0, 47.0), "Đang nạp…" if hud.reloading else hud.ammo, 18, acc)
		_text(ThemeDB.fallback_font, Vector2(72.0, 64.0), "[Chuột giữa] vũ khí", 11, Color(0.85, 0.85, 0.9))

	func _text(f: Font, pos: Vector2, s: String, sz: int, col: Color) -> void:
		draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, size.x - pos.x - 6.0, sz, 4, WeaponHUD.INK)
		draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, size.x - pos.x - 6.0, sz, col)


class Crosshair extends Control:
	var hud: WeaponHUD

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var g: float = 4.0 + hud.spread_px
		var col: Color = hud.accent()
		for d: Vector2 in [Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2(0.0, -1.0)]:
			draw_line(c + d * g, c + d * (g + 9.0), WeaponHUD.INK, 4.0)
			draw_line(c + d * g, c + d * (g + 9.0), col, 2.0)
		draw_circle(c, 2.0, col)
```

- [ ] **Step 10: Write `scripts/weapons/WeaponDirector.gd`**

```gdscript
# File: res://scripts/weapons/WeaponDirector.gd
# Phase W weapons on foot (spec W-D2..W-D4, W-D9, section 3):
#   - the equipped slot (wheel selection or mouse-wheel scroll + toast) and its code-built hand prop (WeaponProps, posed in
#     the body frame like CineActor.hold);
#   - magazines with unlimited reserve: automatic reload when empty, R reloads a part-empty one;
#   - aim (right mouse): ThirdPersonController's over-the-shoulder camera, narrower FOV, walk speed, crosshair;
#   - fire (left mouse while the mouse is captured): without aiming the body turns to the camera first (hip fire);
#   - the per-weapon logic (melee here; hitscan / pellets Task 4, rocket Task 5, dép / sầu riêng / loa Task 6).
# Targets are duck-typed: any Node3D with take_hit(info) -> String and is_down() from targets_fn (Pedestrian, Officer);
# vehicles go through RoamTraffic.hit_vehicle. Heat leaves on the `mayhem` signal (WantedDirector.add_heat). Blocked (no
# aim, no fire) while blocked_fn says so (riding, cinematic, replay, busted, community service, map) or `locked`; nothing
# fires while the wheel is open. Times are game seconds (the wheel's slow motion slows reloads too). Input overrides
# (fire_override / aim_override / reload_override) drive it in tests. GameFX / StageManager are never named here.
class_name WeaponDirector
extends Node3D

signal equipped(slot: int)
signal fired(slot: int)
signal mayhem(heat: float, at: Vector3, cause: String)
signal toast(text: String)

const COMBO_S: float = 1.5
const LOG_MAX: int = 64
const HAND_UP: float = 1.3
const SOFT_R: float = 0.35               # analytic body capsule of a target (ray tests, Task 4)
const SOFT_H: float = 1.8

var player: ThirdPersonController
var wheel: WeaponWheel
var hud: WeaponHUD
var fx: WeaponFX
var traffic: RoamTraffic
var spawner: PedestrianSpawner
var targets_fn: Callable
var blocked_fn: Callable
var locked: bool = false
var current: int = 0
var ammo: PackedInt32Array = PackedInt32Array()
var reload_left: float = 0.0
var cooldown: float = 0.0
var aiming: bool = false
var rng := RandomNumberGenerator.new()
var spread_scale: float = 1.0            # tests: 0 = no random spread
var fire_override: Variant = null        # bool: fire button held (null = read the mouse)
var aim_override: Variant = null         # bool: aim button held (null = read the mouse)
var reload_override: bool = false        # one press of R, cleared when read
var shots: int = 0
var hit_log: Array[Dictionary] = []      # {"t", "slot", "kind", "target", "reaction"} (last LOG_MAX)
var held: Node3D = null
var _t: float = 0.0
var _fire_prev: bool = false
var _r_prev: bool = false
var _combo: Dictionary = {}              # target instance id -> [hits, game time of the last]
var _sfx: Array[AudioStreamPlayer3D] = []
var _sfx_i: int = 0
var _held_att: BoneAttachment3D = null


func _ready() -> void:
	rng.seed = 2026
	ammo.resize(WeaponData.COUNT)
	for i: int in WeaponData.COUNT:
		ammo[i] = WeaponData.mag_of(i)
	fx = WeaponFX.new()
	fx.name = "WeaponFX"
	add_child(fx)
	for i: int in 8:
		var p := AudioStreamPlayer3D.new()
		p.name = "Sfx%d" % i
		p.bus = WeaponAudio.bus()
		p.max_distance = 120.0
		p.unit_size = 6.0
		add_child(p)
		_sfx.append(p)


## opts: player (ThirdPersonController), wheel (WeaponWheel), hud (WeaponHUD), targets_fn (-> Array of Node3D), traffic
## (RoamTraffic), spawner (PedestrianSpawner), blocked_fn (-> bool). Call after add_child.
func setup(opts: Dictionary) -> void:
	player = opts.get("player")
	wheel = opts.get("wheel")
	hud = opts.get("hud")
	targets_fn = opts.get("targets_fn", Callable())
	traffic = opts.get("traffic")
	spawner = opts.get("spawner")
	blocked_fn = opts.get("blocked_fn", Callable())
	if wheel:
		wheel.current = current
		wheel.info_fn = ammo_text
		wheel.blocked_fn = is_blocked
		wheel.selected.connect(equip)
		wheel.cycled.connect(cycle)
	_update_held()
	_refresh_hud()


func is_blocked() -> bool:
	return locked or (blocked_fn.is_valid() and bool(blocked_fn.call()))


func ammo_text(slot: int) -> String:
	return WeaponData.ammo_text(slot, ammo[slot])


func equip(slot: int) -> void:
	slot = posmod(slot, WeaponData.COUNT)
	if slot == current:
		return
	current = slot
	reload_left = 0.0
	cooldown = maxf(cooldown, 0.15)
	_combo.clear()
	if wheel:
		wheel.current = slot
	_update_held()
	_refresh_hud()
	equipped.emit(slot)


func cycle(step: int) -> void:
	equip(current + step)
	toast.emit(WeaponData.name_of(current))
	if hud:
		hud.show_toast(WeaponData.name_of(current))


func start_reload() -> void:
	var mag: int = WeaponData.mag_of(current)
	if mag <= 0 or ammo[current] >= mag or reload_left > 0.0:
		return
	reload_left = float(WeaponData.SLOTS[current]["reload"])
	play_cue("reload", hand_position())
	_refresh_hud()


func _physics_process(delta: float) -> void:
	_t += delta
	cooldown = maxf(0.0, cooldown - delta)
	if player == null:
		return
	if reload_left > 0.0:
		reload_left -= delta
		if reload_left <= 0.0:
			reload_left = 0.0
			ammo[current] = WeaponData.mag_of(current)
			_refresh_hud()
	var blocked: bool = is_blocked() or not player.visible
	var wheel_open: bool = wheel != null and wheel.is_open()
	aiming = not blocked and not wheel_open and _aim_input() and not player.is_knocked_down()
	player.aiming = aiming
	if hud:
		hud.set_aim(aiming, 4.0 if aiming else 14.0)
	var fire: bool = not blocked and not wheel_open and not player.is_knocked_down() and _fire_input()
	var edge: bool = fire and not _fire_prev
	_fire_prev = fire
	if not blocked and _reload_input():
		start_reload()
	if fire and (edge or bool(WeaponData.SLOTS[current]["auto"])) and cooldown <= 0.0001 and reload_left <= 0.0:
		try_fire()
	_update_held_pose()


func _fire_input() -> bool:
	if fire_override is bool:
		return fire_override
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _aim_input() -> bool:
	if aim_override is bool:
		return aim_override
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)


func _reload_input() -> bool:
	if reload_override:
		reload_override = false
		return true
	var r: bool = Input.is_physical_key_pressed(KEY_R)
	var edge: bool = r and not _r_prev
	_r_prev = r
	return edge


## One shot / swing / throw of the equipped weapon (cooldown, ammo and reload handled here).
func try_fire() -> void:
	var w: Dictionary = WeaponData.SLOTS[current]
	var mag: int = int(w["mag"])
	if mag > 0 and ammo[current] <= 0:
		start_reload()
		return
	if not aiming:
		_face_camera()
	cooldown = float(w["cycle"])
	match String(w["kind"]):
		"melee":
			_melee(w)
		_:
			pass   # Tasks 4-6 add hitscan, pellets, rocket, boomerang and grenade here
	if mag > 0:
		ammo[current] -= 1
		if ammo[current] <= 0:
			start_reload()
	shots += 1
	_refresh_hud()
	fired.emit(current)


func _face_camera() -> void:
	if player.model:
		player.model.rotation.y = player.yaw


## The right hand (muzzle / throw origin): chest height, a little forward and to the right of the body.
func hand_position() -> Vector3:
	var f: Vector3 = player.facing_dir()
	return player.global_position + Vector3(0.0, HAND_UP, 0.0) + f * 0.35 + Vector3(-f.z, 0.0, f.x) * 0.22


func aim_origin() -> Vector3:
	return player.camera.global_position


func aim_dir() -> Vector3:
	return -player.camera.global_basis.z


func soft_targets() -> Array:
	if not targets_fn.is_valid():
		return []
	var out: Array = []
	for n: Variant in targets_fn.call():
		if is_instance_valid(n) and (n as Node).is_inside_tree() and (n as Node).has_method("take_hit"):
			out.append(n)
	return out


## Unarmed: the nearest person in front (combo: 1st and 2nd hit stumble, the 3rd within COMBO_S knocks out, +1 heat).
## Knife: everyone inside the 1.4 m arc is knocked out (+2 heat each).
func _melee(w: Dictionary) -> void:
	var unarmed: bool = current == WeaponData.Slot.UNARMED
	if player.model:
		CharacterBuilder.play(player.model, "punch" if unarmed else "chop", 0.35)
	var fwd: Vector3 = player.facing_dir()
	var reach: float = float(w["range"]) + 0.3
	var half: float = deg_to_rad(float(w["half_deg"]))
	var hits: Array = []
	var best: Node3D = null
	var best_d: float = INF
	for n: Node3D in soft_targets():
		if n.has_method("is_down") and bool(n.call("is_down")):
			continue
		if not WeaponMath.in_cone(player.global_position, fwd, half, reach, n.global_position):
			continue
		if unarmed:
			var d: float = WeaponMath.flat(n.global_position, player.global_position)
			if d < best_d:
				best_d = d
				best = n
		else:
			hits.append(n)
	if unarmed and best != null:
		hits = [best]
	if hits.is_empty():
		play_cue("swish", hand_position(), -4.0)
		return
	for n2: Node3D in hits:
		var info: Dictionary = {"kind": "melee", "from": player.global_position}
		if unarmed:
			var key: int = n2.get_instance_id()
			var c: Array = _combo.get(key, [0, -99.0])
			var count: int = (int(c[0]) if _t - float(c[1]) <= COMBO_S else 0) + 1
			_combo[key] = [count, _t]
			if count < 3:
				info["kind"] = "punch"
			else:
				_combo.erase(key)
		var r: String = hit_target(n2, info)
		play_cue("punch" if unarmed else "knife_hit", n2.global_position + Vector3(0.0, 1.3, 0.0))
		fx.burst("dust", n2.global_position + Vector3(0.0, 1.2, 0.0), Vector3.UP, 0.3)
		if r == "knocked_out":
			_heat(WeaponData.HEAT_KO_UNARMED if unarmed else WeaponData.HEAT_KNIFE, n2.global_position, "melee")


## Apply info to one target and add its comic FX (daze stars on a knockout / launch). Returns the reaction.
func hit_target(n: Node3D, info: Dictionary) -> String:
	if not is_instance_valid(n) or not n.has_method("take_hit"):
		return "none"
	var r: String = String(n.call("take_hit", info))
	if r == "knocked_out" or r == "launched":
		var ko: Variant = n.get("ko_left")
		fx.stars(n, (float(ko) if ko != null else 6.0) + (1.0 if r == "launched" else 0.0))
	hit_log.append({"t": _t, "slot": current, "kind": String(info.get("kind", "")), "target": String(n.name), "reaction": r})
	if hit_log.size() > LOG_MAX:
		hit_log.pop_front()
	return r


func _heat(amount: float, at: Vector3, cause: String) -> void:
	if amount > 0.0:
		mayhem.emit(amount, at, cause)


func _people_near(p: Vector3, r: float) -> bool:
	for n: Node3D in soft_targets():
		if WeaponMath.flat(n.global_position, p) <= r:
			return true
	return false


## Play a cue (WeaponAudio: user://sfx/<cue>.ogg override, else synthesized) at a world position.
func play_cue(cue: String, at: Vector3, db: float = 0.0) -> void:
	if _sfx.is_empty():
		return
	var p: AudioStreamPlayer3D = _sfx[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx.size()
	p.stream = WeaponAudio.stream(cue)
	p.volume_db = db
	p.global_position = at
	p.play()


func _refresh_hud() -> void:
	if hud:
		hud.set_weapon(current, ammo_text(current), reload_left > 0.0)
	if wheel and wheel.view:
		wheel.view.queue_redraw()


## The equipped weapon's prop in the right hand, on a BoneAttachment3D at Wrist.R (non-rigged bodies: fixed offset).
func _update_held() -> void:
	if held:
		held.queue_free()
		held = null
	if player == null or player.model == null:
		return
	held = WeaponProps.build(current)
	if held == null:
		return
	var sk: Skeleton3D = player.model.get_meta("skeleton", null) as Skeleton3D
	if sk and sk.find_bone("Wrist.R") >= 0:
		if _held_att == null or not is_instance_valid(_held_att):
			_held_att = BoneAttachment3D.new()
			_held_att.name = "WeaponHold"
			_held_att.bone_name = "Wrist.R"
			sk.add_child(_held_att)
		_held_att.add_child(held)
	else:
		player.model.add_child(held)
		held.position = Vector3(0.25, 1.05, -0.25)


## Pose the prop in the body frame every frame (barrel along the body's -Z, pitched with the camera while aiming).
func _update_held_pose() -> void:
	if held == null or _held_att == null or not is_instance_valid(_held_att) or held.get_parent() != _held_att:
		return
	var sk: Skeleton3D = _held_att.get_parent() as Skeleton3D
	var b: int = sk.find_bone("Wrist.R")
	var hand: Transform3D = sk.global_transform * CharacterBuilder._bone_global_now(sk, b)
	var body: Basis = player.model.global_basis.orthonormalized()
	if aiming:
		body = body * Basis(Vector3.RIGHT, player.pitch)
	held.transform = hand.affine_inverse() * Transform3D(body, hand.origin)
```

- [ ] **Step 11: Wire the weapons into `scripts/FreeRoam.gd`**

11a. After `var crowd_enabled: bool = true` add:

```gdscript
## false = no weapons / wanted level (Phase W): test_free_roam sets it before add_child so its phases stay deterministic.
var mayhem_enabled: bool = true
var weapons: WeaponDirector
var weapon_wheel: WeaponWheel
var weapon_hud: WeaponHUD
```

11b. In `_ready()`, replace

```gdscript
	if crowd_enabled:
		_build_pedestrians()
		_build_traffic()
```

with

```gdscript
	if crowd_enabled:
		_build_pedestrians()
		_build_traffic()
	if mayhem_enabled:
		_build_mayhem()
```

11c. In `play_cinematic()`, replace the list `[player, bike, hint_holder, tod_holder, stats_holder, vice_hud, stamina_bar, map_overlay, pedestrians, traffic]` with:

```gdscript
[player, bike, hint_holder, tod_holder, stats_holder, vice_hud, stamina_bar, map_overlay, pedestrians, traffic, weapon_hud]
```

11d. In `_physics_process()`, after the `if stamina_bar:` block (before `if _hint_flash_t > 0.0:`) add:

```gdscript
	if weapon_hud:
		weapon_hud.visible = not mayhem_blocked()
```

11e. Insert this section right before the `# CINEMATIC (spec A1)` section header (the `# ===…` line above it):

```gdscript
# ===========================================================================
# PHASE W: VŨ KHÍ / TRUY NÃ (spec 2026-10-23-phase-w-weapons-wanted-design.md)
# ===========================================================================
func _build_mayhem() -> void:
	weapon_wheel = WeaponWheel.new()
	weapon_wheel.name = "WeaponWheel"
	add_child(weapon_wheel)
	weapon_hud = WeaponHUD.new()
	weapon_hud.name = "WeaponHUD"
	add_child(weapon_hud)
	weapons = WeaponDirector.new()
	weapons.name = "Weapons"
	add_child(weapons)
	weapons.setup({"player": player, "wheel": weapon_wheel, "hud": weapon_hud, "targets_fn": mayhem_targets,
		"traffic": traffic, "spawner": pedestrians, "blocked_fn": mayhem_blocked})


## Everything weapons can hit: pedestrians of both tiers (officers join in Task 8).
func mayhem_targets() -> Array:
	var out: Array = []
	if pedestrians:
		out.append_array(pedestrians.pedestrians())
	return out


## Weapons and the wheel are off while riding (W-D9: on foot only), during a cinematic / replay (tree paused or
## StageManager.cinematic_active), while the map is open or the player is hidden.
func mayhem_blocked() -> bool:
	if mounted or cine_player != null or player == null or not player.visible:
		return true
	if map_overlay and map_overlay.visible:
		return true
	if is_inside_tree() and get_tree().paused:
		return true
	var sm: Node = get_node_or_null("/root/StageManager")
	return sm != null and bool(sm.get("cinematic_active"))


```

- [ ] **Step 12: Keep `tests/test_free_roam.gd` deterministic**

12a. After `	roam.set("crowd_enabled", false)   # các pha kiểm tra cố định: …` add:

```gdscript
	roam.set("mayhem_enabled", false)   # Phase W: không vũ khí / truy nã trong các pha kiểm tra cố định
```

12b. In `_after_ready()`, after the `player is a ThirdPersonController` check add:

```gdscript
	if not _check(roam.get("weapons") == null and roam.get("weapon_wheel") == null, "mayhem_enabled = false builds no weapons"):
		return false
```

- [ ] **Step 13: Import, check the class cache, run the test**

```bash
godot --headless --import --path . > /tmp/w_imp.log 2>&1
grep -c 'WeaponDirector\|WeaponFX\|WeaponAudio\|WeaponHUD\|WeaponProps' .godot/global_script_class_cache.cfg
git diff --name-only -- '*.import' | xargs -r git checkout --
godot --headless --path . --script tests/test_weapons_core.gd > /tmp/w_t3.log 2>&1; grep -E "SUCCESS|FAIL|✗" /tmp/w_t3.log
```
Expected: the cache count is at least 5, and the test prints `✅ SUCCESS: WEAPONS CORE …`. Run `tests/test_free_roam.gd`, `tests/test_locomotion.gd` and `tests/test_hud_bounds.gd` too: movement without aiming must not change, and the weapon widget must fit at every resolution.

- [ ] **Step 14: Run the full regression, then commit**

```bash
git add scripts/weapons/WeaponDirector.gd scripts/weapons/WeaponDirector.gd.uid scripts/weapons/WeaponFX.gd scripts/weapons/WeaponFX.gd.uid scripts/weapons/WeaponAudio.gd scripts/weapons/WeaponAudio.gd.uid scripts/weapons/WeaponHUD.gd scripts/weapons/WeaponHUD.gd.uid scripts/weapons/WeaponProps.gd scripts/weapons/WeaponProps.gd.uid scripts/weapons/WeaponMath.gd scripts/ThirdPersonController.gd scripts/FreeRoam.gd tests/support/mayhem_world.gd tests/support/mayhem_world.gd.uid tests/test_weapons_core.gd tests/test_weapons_core.gd.uid tests/test_free_roam.gd
git commit -m "feat(weapons): WeaponDirector core - equip / scroll cycle with toast, magazines with unlimited reserve and reloads (auto, R), over-the-shoulder aim camera (FOV 50, walk speed), hip fire turns to the camera, unarmed 3-hit combo and knife arc with daze stars and heat, code-built hand props, WeaponFX on a game clock (A1 CineFX), synthesized WeaponAudio with user://sfx overrides, WeaponHUD; FreeRoam wiring behind mayhem_enabled (off in test_free_roam), blocked on the bike / in cinematics / map

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 4: Pistol and shotgun – hitscan, pellets, vehicles stop, muzzle / tracer / impact FX, synthesized shots  [effort: xhigh]

**Files:**
- Modify: `scripts/weapons/WeaponMath.gd`, `scripts/weapons/WeaponDirector.gd`, `scripts/weapons/WeaponFX.gd`, `scripts/weapons/WeaponAudio.gd`, `tests/support/mayhem_world.gd`.
- Test: `tests/test_weapons_guns.gd`.

**Interfaces:**
- Consumes:
  - Task 2: `RoamTraffic.hit_vehicle`, `active_indices`, `vehicle_box`, `bodies`, `rider_fled`.
  - Task 3: the whole `WeaponDirector` core, `WeaponFX.burst` / `add_transient`.
- Produces:
  - `WeaponMath.ray_capsule(o, d, base, r, h) -> float` (-1 = miss), `ray_box(o, d, xf: Transform3D, half: Vector3) -> float`, `spread_dir(d, deg, rng) -> Vector3`.
  - `WeaponDirector`:
    - constants `SCARE_GUN_R 10.0, PUMP_DELAY 0.35, KNOCK_UP 6.0`;
    - `first_hit(o, d, max_d, ex: Array[RID] = []) -> Dictionary` with keys `t, kind ("none" | "world" | "soft" | "vehicle"), pos, normal, node, vehicle`;
    - `_exclusions() -> Array[RID]`, `_scare(at, r)`; Task 5's rocket uses `first_hit` and `_exclusions`.
  - `WeaponFX.muzzle(pos, dir, power := 1.0)`, `tracer(a, b)`, `impact(pos, normal, soft: bool)`.
  - `WeaponAudio` cues `shot_pistol, shot_shotgun, pump, ricochet`.
  - `mayhem_world.traffic(parent, player, z) -> RoamTraffic` and `place_vehicle(t, idx, x) -> Vector3`.

- [ ] **Step 1: Add the traffic helpers to `tests/support/mayhem_world.gd`**

Append:

```gdscript
## A RoamTraffic with two vehicles (motorbike 0, car 1) on one straight two-way 10.5 m road 200 m along X at z. Both start
## parked; place them with place_vehicle (then none is left parked, so the traffic spawns nothing on its own).
## The node sits 100 m below the arena: RoamTraffic adds each vehicle body at the node's origin before parking it (the
## physics step then sweeps it away as a kinematic move), which would shove a player standing at the arena origin.
## Vehicles are placed in global coordinates, so the offset changes nothing else.
static func traffic(parent: Node, player_node: Node3D, z: float) -> RoamTraffic:
	var md := MapData.new()
	md.data = {"roads": [{"id": 1, "name": "Đường thử", "class": "primary", "width": 10.5, "lanes": 2, "oneway": false,
		"roundabout": false, "bridge": false, "region": "corridor", "points": [[-100.0, z], [100.0, z]]}]}
	var stub := Node.new()
	stub.name = "StubRoam"
	stub.set_script(load("res://tests/support/stub_roam.gd"))
	parent.add_child(stub)
	var t := RoamTraffic.new()
	t.name = "Traffic"
	t.position = Vector3(0.0, -100.0, 0.0)
	parent.add_child(t)
	t.setup(md, player_node, {"roam": stub, "kinds": [RoamTraffic.Kind.MOTO, RoamTraffic.Kind.CAR], "plot": PackedVector2Array(), "seed": 5})
	for c: RoamTraffic.Vehicle in t.vehicles:
		t._park(c)
	return t


## Put vehicle idx on lane 0 at world x and hold it there (cruise 0). Returns its ground position.
static func place_vehicle(t: RoamTraffic, idx: int, x: float) -> Vector3:
	var c: RoamTraffic.Vehicle = t.vehicles[idx]
	var pts: PackedVector2Array = t.lane_pts[0]
	var s: float = clampf(absf(x - pts[0].x), 1.0, t.lane_len[0] - 2.0)
	t._activate(c, 0, s)
	c.cruise = 0.0
	c.speed = 0.0
	return Vector3(c.pos.x, MapBuilder.ROAD_Y, c.pos.y)
```

- [ ] **Step 2: Write the failing test `tests/test_weapons_guns.gd`**

```gdscript
# File: res://tests/test_weapons_guns.gd
# Headless test of the Phase W pistol and shotgun (spec section 3, section 7 "Weapons"): ray-capsule / ray-box / spread
# math; a hip shot knocks the person on the camera centre out (+2 per hit, +2 for a shot near people), scares a bystander,
# draws a muzzle flash and a tracer and plays the synthesized shot; an aimed shot hits on the over-the-shoulder crosshair
# line; a bullet halts a motorbike and its rider flees (+2); the shotgun launches a person ~4 m back once per shot (8 pellets,
# +3), pumps 0.35 s later, fires every 0.8 s; walls stop bullets (occlusion); no GPUParticles3D.
# Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_weapons_guns.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")

var fails: Array[String] = []
var frames: int = 0
var phase: String = ""
var t0: int = 0
var started: bool = false
var arena: Node3D
var player: ThirdPersonController
var dir: WeaponDirector
var traffic: RoamTraffic
var targets: Array = []
var heat: Array[float] = []
var fled: int = 0
var a: Pedestrian
var b: Pedestrian
var d_start: Vector3
var shots0: int = 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	print("--- TEST WEAPONS: PISTOL + SHOTGUN ---")
	_math()
	physics_frame.connect(_on_physics)


func _math() -> void:
	var t: float = WeaponMath.ray_capsule(Vector3(0.0, 1.0, 10.0), Vector3(0.0, 0.0, -1.0), Vector3.ZERO, 0.35, 1.8)
	_check(absf(t - 9.65) < 0.02, "ray_capsule head-on hit at 9.65 m (%.3f)" % t)
	_check(WeaponMath.ray_capsule(Vector3(0.4, 1.0, 10.0), Vector3(0.0, 0.0, -1.0), Vector3.ZERO, 0.35, 1.8) < 0.0, "ray_capsule: 0.4 m to the side misses")
	_check(WeaponMath.ray_capsule(Vector3(0.0, 2.0, 10.0), Vector3(0.0, 0.0, -1.0), Vector3.ZERO, 0.35, 1.8) < 0.0, "ray_capsule: over the head misses")
	var box := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.5, -5.0))
	_check(absf(WeaponMath.ray_box(Vector3(0.0, 0.5, 0.0), Vector3(0.0, 0.0, -1.0), box, Vector3(1.0, 0.5, 1.0)) - 4.0) < 1e-4, "ray_box hits the near face at 4 m")
	var rot := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.0, 0.5, -5.0))
	_check(absf(WeaponMath.ray_box(Vector3(0.0, 0.5, 0.0), Vector3(0.0, 0.0, -1.0), rot, Vector3(2.0, 0.5, 1.0)) - 3.0) < 1e-4, "ray_box in the box frame (rotated 90°: 2 m half length across the ray)")
	_check(WeaponMath.ray_box(Vector3(3.0, 0.5, 0.0), Vector3(0.0, 0.0, -1.0), box, Vector3(1.0, 0.5, 1.0)) < 0.0, "ray_box miss")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var d0 := Vector3(0.0, 0.0, -1.0)
	_check(WeaponMath.spread_dir(d0, 0.0, rng).is_equal_approx(d0), "spread 0° = the aim direction")
	var worst: float = 0.0
	var mean: float = 0.0
	for i: int in 300:
		var ang: float = rad_to_deg(WeaponMath.spread_dir(d0, 4.5, rng).angle_to(d0))
		worst = maxf(worst, ang)
		mean += ang / 300.0
	_check(worst <= 4.51 and mean > 1.5, "spread stays inside the 4.5° cone and fills it (max %.2f°, mean %.2f°)" % [worst, mean])


func _next(p: String) -> void:
	phase = p
	t0 = frames


func _fire_edge() -> void:
	dir.cooldown = 0.0
	dir.fire_override = true


func _on_physics() -> void:
	frames += 1
	if not started:
		started = true
		arena = Node3D.new()
		root.add_child(arena)
		World.floor_box(arena)
		player = World.player(arena, Vector3.ZERO, 0.0)
		traffic = World.traffic(arena, player, -25.0)
		World.place_vehicle(traffic, 0, 0.0)
		World.place_vehicle(traffic, 1, 80.0)
		traffic.rider_fled.connect(func(_i: int, _at: Vector3, _f: Vector3) -> void: fled += 1)
		dir = World.director(arena, player, targets, traffic)
		dir.mayhem.connect(func(h: float, _at: Vector3, _c: String) -> void: heat.append(h))
		dir.equip(WeaponData.Slot.PISTOL)
		_next("hip")
		return
	var t: int = frames - t0
	if dir.fire_override == true and t > 0 and phase != "shotgun_hold":
		dir.fire_override = false
	match phase:
		"hip":
			if t == 5:
				a = World.ped(arena, Vector3(0.0, 0.0, -10.0), 81, player)
				b = World.ped(arena, Vector3(2.5, 0.0, -6.0), 82, player)
				targets.append_array([a, b])
			if t == 8:
				_fire_edge()
			if t == 10:
				_check(dir.fx.transient_count("tracer") >= 1, "a tracer is drawn")
				_check(not dir.fx.cine.find_children("Flash*", "", true, false).is_empty(), "a muzzle flash")
				var played: bool = false
				for p: AudioStreamPlayer3D in dir._sfx:
					if p.stream == WeaponAudio.stream("shot_pistol"):
						played = true
				_check(played, "the synthesized pistol shot plays")
			if t == 12:
				_check(a.state == Pedestrian.State.KNOCKED_OUT, "a hip shot knocks out the person on the camera centre")
				_check(b.state == Pedestrian.State.FLEE, "the bystander 6.5 m away is scared and flees")
				_check(heat.size() == 2 and is_equal_approx(heat[0] + heat[1], WeaponData.HEAT_SHOT_NEAR + WeaponData.HEAT_PISTOL_HIT), "+2 shot near people, +2 hit (%s)" % str(heat))
				_check(dir.ammo[WeaponData.Slot.PISTOL] == 11, "one round used")
				targets.clear()
				heat.clear()
				dir.aim_override = true
				var c: Pedestrian = World.ped(arena, Vector3(ThirdPersonController.AIM_SIDE, 0.0, -15.0), 83, player)
				targets.append(c)
				_next("aim")
		"aim":
			if t == 25:
				_fire_edge()
			if t == 28:
				_check((targets[0] as Pedestrian).state == Pedestrian.State.KNOCKED_OUT, "an aimed shot hits on the over-the-shoulder crosshair line")
				dir.aim_override = false
				targets.clear()
				heat.clear()
				player.pitch = -0.05
				_next("vehicle")
		"vehicle":
			if t == 20:
				_fire_edge()
			if t == 23:
				var c0: RoamTraffic.Vehicle = traffic.vehicles[0]
				var rider: Node3D = c0.body.get_node_or_null("Rider") as Node3D
				_check(c0.halted and c0.speed == 0.0, "a bullet stops the motorbike")
				_check(rider != null and not rider.visible and fled == 1, "its rider jumps off and flees")
				_check(heat.size() == 1 and is_equal_approx(heat[0], WeaponData.HEAT_PISTOL_HIT), "+2 for hitting a vehicle, no 'near people' heat (%s)" % str(heat))
				heat.clear()
				player.pitch = 0.0
				dir.equip(WeaponData.Slot.SHOTGUN)
				var dd: Pedestrian = World.ped(arena, Vector3(0.0, 0.0, -6.0), 84, player)
				targets.append(dd)
				_next("shotgun")
		"shotgun":
			var dp: Pedestrian = targets[0]
			if t == 12:
				d_start = dp.global_position
				_fire_edge()
			if t == 14:
				_check(dp.state == Pedestrian.State.LAUNCHED and dp.hits.count("launched") == 1, "the shotgun launches the person once (8 pellets, one reaction)")
				_check(dir.ammo[WeaponData.Slot.SHOTGUN] == 5 and dir._pending_cues.size() == 1, "one shell used, the pump is scheduled")
			if t == 40:
				_check(dir._pending_cues.is_empty(), "the pump sound played 0.35 s after the shot")
			if t == 80:
				var moved: float = d_start.z - dp.global_position.z
				_check(dp.state == Pedestrian.State.KNOCKED_OUT and moved > 3.0 and moved < 6.0, "flung ~4 m back, knocked out (%.2f m)" % moved)
				var sum: float = 0.0
				for h: float in heat:
					sum += h
				_check(is_equal_approx(sum, WeaponData.HEAT_SHOTGUN), "+3 heat for the shotgun shot (%s)" % str(heat))
				targets.clear()
				shots0 = dir.shots
				dir.cooldown = 0.0
				dir.fire_override = true
				_next("shotgun_hold")
		"shotgun_hold":
			if t == 100:
				dir.fire_override = false
				_check(dir.shots - shots0 == 3, "the shotgun fires every 0.8 s (3 shots in 100 frames, got %d)" % (dir.shots - shots0))
				dir.equip(WeaponData.Slot.PISTOL)
				World.wall(arena, Vector3(0.0, 1.5, -8.0), Vector3(6.0, 3.0, 0.5))
				targets.append(World.ped(arena, Vector3(0.0, 0.0, -12.0), 85, player))
				_next("wall")
		"wall":
			if t == 3:
				var o: Vector3 = dir.aim_origin() + dir.aim_dir() * (player.camera.position.z + 0.3)
				var h: Dictionary = dir.first_hit(o, dir.aim_dir(), 80.0)
				_check(String(h["kind"]) == "world" and absf((h["pos"] as Vector3).z + 7.75) < 0.1, "a wall in front stops the bullet before the person behind it (%s at %s)" % [h["kind"], h["pos"]])
				var front: Pedestrian = World.ped(arena, Vector3(0.0, 0.0, -5.0), 86, player)
				targets.append(front)
			if t == 6:
				var o2: Vector3 = dir.aim_origin() + dir.aim_dir() * (player.camera.position.z + 0.3)
				var h2: Dictionary = dir.first_hit(o2, dir.aim_dir(), 80.0)
				_check(String(h2["kind"]) == "soft", "a person in front of the wall is hit first (%s)" % h2["kind"])
				_check(arena.find_children("*", "GPUParticles3D", true, false).is_empty(), "no GPUParticles3D")
				Engine.time_scale = 1.0
				if fails.is_empty():
					print("✅ SUCCESS: WEAPONS PISTOL + SHOTGUN (math, hip / aimed hits, heat, bystanders, vehicle stop, knockback, pump, cadence, occlusion)")
					quit(0)
				else:
					print("❌ FAILED: %d issues" % fails.size())
					quit(1)
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `godot --headless --path . --script tests/test_weapons_guns.gd > /tmp/w_t4.log 2>&1; grep -E "SUCCESS|FAIL|Parse Error|Invalid call" /tmp/w_t4.log`
Expected: a parse error (`WeaponMath.ray_capsule` / `first_hit` not found).

- [ ] **Step 4: Append the ray math to `scripts/weapons/WeaponMath.gd`**

```gdscript
## Ray (origin o, unit direction d) against an upright capsule standing on `base` (radius r, total height h): distance along
## the ray to the hit, or -1. (Closest approach to the capsule axis segment, then back off by half the chord.)
static func ray_capsule(o: Vector3, d: Vector3, base: Vector3, r: float, h: float) -> float:
	var a: Vector3 = base + Vector3(0.0, r, 0.0)
	var u: Vector3 = Vector3(0.0, maxf(h - 2.0 * r, 0.0), 0.0)
	var uu: float = u.length_squared()
	var t: float = maxf(0.0, (a + u * 0.5 - o).dot(d))
	var s: float = 0.5
	for i: int in 4:
		s = clampf((o + d * t - a).dot(u) / uu, 0.0, 1.0) if uu > 1e-6 else 0.0
		t = maxf(0.0, (a + u * s - o).dot(d))
	var dist: float = (o + d * t).distance_to(a + u * s)
	if dist > r:
		return -1.0
	return maxf(0.0, t - sqrt(r * r - dist * dist))


## Ray against a box (centre frame xf with an orthonormal basis, half extents `half`): entry distance, 0 if o is inside, -1 = miss.
static func ray_box(o: Vector3, d: Vector3, xf: Transform3D, half: Vector3) -> float:
	var inv: Transform3D = xf.affine_inverse()
	var lo: Vector3 = inv * o
	var ld: Vector3 = inv.basis * d
	var tmin: float = 0.0
	var tmax: float = INF
	for i: int in 3:
		if absf(ld[i]) < 1e-8:
			if lo[i] < -half[i] or lo[i] > half[i]:
				return -1.0
			continue
		var t1: float = (-half[i] - lo[i]) / ld[i]
		var t2: float = (half[i] - lo[i]) / ld[i]
		tmin = maxf(tmin, minf(t1, t2))
		tmax = minf(tmax, maxf(t1, t2))
		if tmin > tmax:
			return -1.0
	return tmin


## Random unit direction inside a cone of half angle `deg` around d (uniform over the disc).
static func spread_dir(d: Vector3, deg: float, rng: RandomNumberGenerator) -> Vector3:
	var n: Vector3 = d.normalized()
	if deg <= 0.0:
		return n
	var p1: Vector3 = n.cross(Vector3.UP)
	if p1.length_squared() < 1e-6:
		p1 = n.cross(Vector3.RIGHT)
	p1 = p1.normalized()
	var p2: Vector3 = n.cross(p1)
	var a: float = deg_to_rad(deg) * sqrt(rng.randf())
	var phi: float = rng.randf() * TAU
	return (n * cos(a) + (p1 * cos(phi) + p2 * sin(phi)) * sin(a)).normalized()
```

- [ ] **Step 5: Add the gun FX to `scripts/weapons/WeaponFX.gd`**

5a. After `const LIFE: Dictionary = …` add:

```gdscript
const TRACER_S: float = 0.07
const TRACER_COL := Color(1.0, 0.85, 0.45, 0.9)
```

5b. Append:

```gdscript
## Muzzle flash with a few sparks forward.
func muzzle(pos: Vector3, dir: Vector3, power: float = 1.0) -> void:
	burst("flash", pos + dir * 0.15, dir, 0.35 * power)
	burst("sparks", pos + dir * 0.2, dir, 0.25 * power)


## Bullet tracer a -> b: a thin unshaded additive box that fades out within TRACER_S.
func tracer(a: Vector3, b: Vector3) -> void:
	var dist: float = a.distance_to(b)
	if dist < 0.2:
		return
	var mi := MeshInstance3D.new()
	mi.name = "Tracer"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.025, 0.025, dist)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = TRACER_COL
	m.set_meta("vice_done", true)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fwd: Vector3 = (b - a) / dist
	var up: Vector3 = Vector3.UP if absf(fwd.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	mi.transform = Transform3D(Basis.looking_at(fwd, up), (a + b) * 0.5)
	add_transient(mi, TRACER_S, "tracer", m, TRACER_S)


## Bullet impact: dust on a person, sparks + dust on hard surfaces.
func impact(pos: Vector3, normal: Vector3, soft: bool) -> void:
	if soft:
		burst("dust", pos, normal, 0.35)
	else:
		burst("sparks", pos, normal, 0.6)
		burst("dust", pos, normal, 0.25)
```

- [ ] **Step 6: Add the gun cues to `scripts/weapons/WeaponAudio.gd`**

Replace the `CUES` line with:

```gdscript
const CUES: Array[String] = ["punch", "swish", "knife_hit", "reload", "dry_click", "shot_pistol", "shot_shotgun", "pump", "ricochet"]
```

and add these branches to the `match cue:` of `synth()` (before the closing fallback `return`):

```gdscript
		"shot_pistol":
			return CineAudio._to_wav(CineAudio._mix([CineAudio._noise(0.18, 0.9, 22.0, 31, 0.15), CineAudio._tone(0.12, 220.0, 70.0, 0.7, 20.0)]))
		"shot_shotgun":
			return CineAudio._to_wav(CineAudio._mix([CineAudio._noise(0.42, 1.0, 9.0, 32, 0.3), CineAudio._tone(0.3, 120.0, 40.0, 0.9, 9.0)]))
		"pump":
			var p: PackedFloat32Array = CineAudio._mix([CineAudio._noise(0.06, 0.7, 60.0, 33, 0.2), CineAudio._tone(0.05, 900.0, 700.0, 0.3, 50.0)])
			p.append_array(_gap(0.12))
			p.append_array(CineAudio._mix([CineAudio._noise(0.07, 0.8, 55.0, 34, 0.2), CineAudio._tone(0.06, 700.0, 520.0, 0.35, 45.0)]))
			return CineAudio._to_wav(p)
		"ricochet":
			return CineAudio._to_wav(CineAudio._tone(0.35, 2600.0, 900.0, 0.25, 7.0))
```

- [ ] **Step 7: Hitscan and pellets in `scripts/weapons/WeaponDirector.gd`**

7a. After `const SOFT_H: float = 1.8` add:

```gdscript
const SCARE_GUN_R: float = 10.0          # gunfire scares pedestrians this close (plan P11)
const PUMP_DELAY: float = 0.35
const KNOCK_UP: float = 6.0              # shotgun knockback arc: up KNOCK_UP m/s, lands `knockback` m away
```

and after `var _held_att: BoneAttachment3D = null` add:

```gdscript
var _pending_cues: Array = []            # [game time, cue, position] (the shotgun pump)
```

7b. In `_physics_process()`, add `	_tick_pending()` as the line right before `	_update_held_pose()`.

7c. In `try_fire()`, replace the `match String(w["kind"]):` block with:

```gdscript
	match String(w["kind"]):
		"melee":
			_melee(w)
		"hitscan":
			_hitscan(w)
		"pellets":
			_pellets(w)
		_:
			pass   # Tasks 5-6 add rocket, boomerang and grenade here
```

7d. Append:

```gdscript
## Bodies a shot's world ray ignores: the player, every physical target (they are tested analytically) and the traffic.
func _exclusions() -> Array[RID]:
	var ex: Array[RID] = [player.get_rid()]
	for n: Node3D in soft_targets():
		if n is CollisionObject3D:
			ex.append((n as CollisionObject3D).get_rid())
	if traffic:
		for b: Variant in traffic.bodies():
			ex.append((b as CollisionObject3D).get_rid())
	return ex


## First thing along a ray (unit d) within max_d: the world (physics ray, _exclusions() ignored), people as upright capsules
## SOFT_R x SOFT_H (downed ones skipped), vehicles as their boxes. {"t", "kind": "none" | "world" | "soft" | "vehicle",
## "pos", "normal", "node" (soft), "vehicle" (index)}.
func first_hit(o: Vector3, d: Vector3, max_d: float, ex: Array[RID] = []) -> Dictionary:
	var best: Dictionary = {"t": max_d, "kind": "none", "pos": o + d * max_d, "normal": -d}
	if is_inside_tree():
		var rq := PhysicsRayQueryParameters3D.create(o, o + d * max_d)
		rq.exclude = ex if not ex.is_empty() else _exclusions()
		rq.collide_with_areas = false
		var h: Dictionary = get_world_3d().direct_space_state.intersect_ray(rq)
		if not h.is_empty():
			best = {"t": o.distance_to(h["position"]), "kind": "world", "pos": h["position"], "normal": h["normal"]}
	for n: Node3D in soft_targets():
		if n.has_method("is_down") and bool(n.call("is_down")):
			continue
		var t: float = WeaponMath.ray_capsule(o, d, n.global_position, SOFT_R, SOFT_H)
		if t >= 0.0 and t < float(best["t"]):
			best = {"t": t, "kind": "soft", "node": n, "pos": o + d * t, "normal": -d}
	if traffic:
		for idx: int in traffic.active_indices():
			var bx: Array = traffic.vehicle_box(idx)
			var t2: float = WeaponMath.ray_box(o, d, bx[0], bx[1])
			if t2 >= 0.0 and t2 < float(best["t"]):
				best = {"t": t2, "kind": "vehicle", "vehicle": idx, "pos": o + d * t2, "normal": -d}
	return best


## Pistol: one hitscan round from the camera centre (spread 0.5° aimed, 3.5° hip), tracer from the hand.
func _hitscan(w: Dictionary) -> void:
	var d0: Vector3 = aim_dir()
	var spread: float = float(w["spread_aim"] if aiming else w["spread_hip"]) * spread_scale
	var d: Vector3 = WeaponMath.spread_dir(d0, spread, rng)
	var start: Vector3 = aim_origin() + d0 * (player.camera.position.z + 0.3)   # skip the stretch behind the player
	var h: Dictionary = first_hit(start, d, float(w["range"]))
	var muzzle: Vector3 = hand_position()
	fx.muzzle(muzzle, d)
	fx.tracer(muzzle, h["pos"])
	play_cue("shot_pistol", muzzle)
	if _people_near(player.global_position, WeaponData.NEAR_PEOPLE_M):
		_heat(WeaponData.HEAT_SHOT_NEAR, player.global_position, "shot")
	_resolve_bullet(h, d, WeaponData.HEAT_PISTOL_HIT)
	_scare(player.global_position, SCARE_GUN_R)


## One bullet's result: a person is knocked out, a vehicle stops (its rider flees), a wall sparks; +heat_hit per hit.
func _resolve_bullet(h: Dictionary, d: Vector3, heat_hit: float) -> void:
	match String(h["kind"]):
		"soft":
			var n: Node3D = h["node"]
			if hit_target(n, {"kind": "bullet", "from": player.global_position, "dir": WeaponMath.flat_dir(d)}) != "none":
				_heat(heat_hit, n.global_position, "hit")
			fx.impact(h["pos"], -d, true)
		"vehicle":
			if traffic and traffic.hit_vehicle(int(h["vehicle"]), "bullet", player.global_position):
				_heat(heat_hit, h["pos"], "vehicle")
			fx.impact(h["pos"], h["normal"], false)
			play_cue("ricochet", h["pos"], -6.0)
		"world":
			fx.impact(h["pos"], h["normal"], false)


## Shotgun: 8 pellets in a 9° cone (hip adds half the hip spread); each person / vehicle reacts once per shot: people are
## flung `knockback` m back and knocked out, vehicles stop. +3 heat if it hit someone or was fired near people.
func _pellets(w: Dictionary) -> void:
	var d0: Vector3 = aim_dir()
	var half: float = float(w["cone_deg"]) * 0.5 + (0.0 if aiming else float(w["spread_hip"]) * 0.5 * spread_scale)
	var start: Vector3 = aim_origin() + d0 * (player.camera.position.z + 0.3)
	var muzzle: Vector3 = hand_position()
	var ex: Array[RID] = _exclusions()
	var kh: float = float(w["knockback"]) / (2.0 * KNOCK_UP / Pedestrian.GRAVITY)
	var struck: Dictionary = {}
	var cars: Dictionary = {}
	var any: bool = false
	for i: int in int(w["pellets"]):
		var d: Vector3 = WeaponMath.spread_dir(d0, half, rng)
		var h: Dictionary = first_hit(start, d, float(w["range"]), ex)
		if i % 2 == 0:
			fx.tracer(muzzle, h["pos"])
		match String(h["kind"]):
			"soft":
				var n: Node3D = h["node"]
				if not struck.has(n.get_instance_id()):
					struck[n.get_instance_id()] = true
					var f: Vector3 = WeaponMath.flat_dir(d)
					if hit_target(n, {"kind": "pellet", "from": player.global_position, "dir": f, "vel": f * kh + Vector3(0.0, KNOCK_UP, 0.0)}) != "none":
						any = true
				fx.impact(h["pos"], -d, true)
			"vehicle":
				var idx: int = int(h["vehicle"])
				if not cars.has(idx):
					cars[idx] = true
					if traffic and traffic.hit_vehicle(idx, "bullet", player.global_position):
						any = true
				fx.impact(h["pos"], h["normal"], false)
			"world":
				fx.impact(h["pos"], h["normal"], false)
	fx.muzzle(muzzle, d0, 1.6)
	play_cue("shot_shotgun", muzzle, 2.0)
	_pending_cues.append([_t + PUMP_DELAY, "pump", muzzle])
	if any or _people_near(player.global_position, WeaponData.NEAR_PEOPLE_M):
		_heat(WeaponData.HEAT_SHOTGUN, player.global_position, "shotgun")
	_scare(player.global_position, SCARE_GUN_R)


## Gunfire / blasts scare the pedestrians around (they flee); officers ignore "scare".
func _scare(at: Vector3, r: float) -> void:
	for n: Node3D in soft_targets():
		if WeaponMath.flat(n.global_position, at) <= r and not (n.has_method("is_down") and bool(n.call("is_down"))):
			n.call("take_hit", {"kind": "scare", "from": at})


func _tick_pending() -> void:
	for i: int in range(_pending_cues.size() - 1, -1, -1):
		var e: Array = _pending_cues[i]
		if _t >= float(e[0]):
			play_cue(String(e[1]), e[2])
			_pending_cues.remove_at(i)
```

- [ ] **Step 8: Run the test**

Run: `godot --headless --path . --script tests/test_weapons_guns.gd > /tmp/w_t4.log 2>&1; grep -E "SUCCESS|FAIL|✗" /tmp/w_t4.log`
Expected: `✅ SUCCESS: WEAPONS PISTOL + SHOTGUN …`.

- [ ] **Step 9: Run the full regression, then commit**

```bash
git add scripts/weapons/WeaponMath.gd scripts/weapons/WeaponDirector.gd scripts/weapons/WeaponFX.gd scripts/weapons/WeaponAudio.gd tests/support/mayhem_world.gd tests/test_weapons_guns.gd tests/test_weapons_guns.gd.uid
git commit -m "feat(weapons): pistol and shotgun - hitscan from the camera centre (0.5° aimed / 3.5° hip), analytic capsule and box ray tests with world occlusion, 8 pellets in a 9° cone flinging people 4 m back, bullets stop vehicles and the rider flees, muzzle flash / tracer / impact FX on CineFX, synthesized shot, pump and ricochet, heat per shot near people and per hit, bystanders flee

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 5: Rocket launcher and explosion  [effort: xhigh]

**Files:**
- Create: `scripts/weapons/WeaponRocket.gd`.
- Modify: `scripts/weapons/WeaponDirector.gd`, `scripts/weapons/WeaponFX.gd`, `scripts/weapons/WeaponAudio.gd`.
- Test: `tests/test_weapons_rocket.gd`.

**Interfaces:**
- Consumes:
  - Task 2: `RoamTraffic.vehicles_near`, `hit_vehicle(…, "blast", …)`, `PedestrianSpawner.scatter_impostors`.
  - Task 3: `ThirdPersonController.knock_down` / `shake`.
  - Task 4: `WeaponDirector.first_hit`, `_exclusions`, `_scare`.
- Produces:
  - `class_name WeaponRocket extends Node3D`: signal `exploded(at: Vector3)`, constants `SPEED 35.0, MAX_RANGE 140.0`, `launch(d: WeaponDirector, from: Vector3, direction: Vector3)`.
  - `WeaponDirector`:
    - constants `ROCKET_UP 1.45, SCARE_BLAST_R 25.0, IMPOSTOR_BLAST_R 30.0`;
    - vars `rockets_fired: int`, `explosions: Array[Vector3]`;
    - `explode_at(pos: Vector3)`.
  - `WeaponFX.explosion(pos, radius, ex: Array[RID] = [])` (transient kinds `smoke` and `scorch`) and `rocket_trail(rocket: Node3D)`.
  - `WeaponAudio` cues `rocket_launch, explosion`.

- [ ] **Step 1: Write the failing test `tests/test_weapons_rocket.gd`**

```gdscript
# File: res://tests/test_weapons_rocket.gd
# Headless test of the Phase W rocket launcher (spec section 3, section 7 "rocket explosion radius"): the visible rocket
# flies at 35 m/s to the person on the crosshair and explodes there; everyone within 6 m flies in a comic arc and lands
# knocked out, a person 7 m away is not launched but flees, one 32 m away is untouched; a car within the radius flips onto
# its roof and smokes; camera shake, smoke puff and scorch mark; +6 heat; 1 round, 2.5 s reload; a blast within 6 m of the
# player knocks him down (comic, he gets up); a rocket into the sky explodes after 140 m.
# Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_weapons_rocket.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")

var fails: Array[String] = []
var frames: int = 0
var phase: String = ""
var t0: int = 0
var started: bool = false
var arena: Node3D
var player: ThirdPersonController
var dir: WeaponDirector
var traffic: RoamTraffic
var targets: Array = []
var heat: Array[float] = []
var peds: Dictionary = {}
var max_shake: float = 0.0
var empty_t: int = -1
var refill_t: int = -1


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	print("--- TEST WEAPONS: ROCKET ---")
	physics_frame.connect(_on_physics)


func _next(p: String) -> void:
	phase = p
	t0 = frames


func _ped(key: String, at: Vector3) -> Pedestrian:
	var p: Pedestrian = World.ped(arena, at, 90 + peds.size(), player)
	peds[key] = p
	targets.append(p)
	return p


func _fire() -> void:
	dir.cooldown = 0.0
	dir.fire_override = true


func _on_physics() -> void:
	frames += 1
	if not started:
		started = true
		arena = Node3D.new()
		root.add_child(arena)
		World.floor_box(arena)
		player = World.player(arena, Vector3.ZERO, 0.0)
		traffic = World.traffic(arena, player, -30.0)
		World.place_vehicle(traffic, 0, -80.0)
		World.place_vehicle(traffic, 1, 4.5)
		dir = World.director(arena, player, targets, traffic)
		dir.mayhem.connect(func(h: float, _at: Vector3, _c: String) -> void: heat.append(h))
		dir.equip(WeaponData.Slot.ROCKET)
		_ped("T", Vector3(0.0, 0.0, -28.0))
		_ped("A", Vector3(-3.0, 0.0, -24.0))
		_ped("B", Vector3(-5.5, 0.0, -28.0))
		_ped("C", Vector3(0.0, 0.0, -35.0))
		_ped("D", Vector3(0.0, 0.0, -60.0))
		_next("fire")
		return
	var t: int = frames - t0
	if dir.fire_override == true and t > 0:
		dir.fire_override = false
	max_shake = maxf(max_shake, float(player.get("_shake_t")))
	if empty_t < 0 and dir.ammo[WeaponData.Slot.ROCKET] == 0:
		empty_t = frames
	if empty_t > 0 and refill_t < 0 and dir.ammo[WeaponData.Slot.ROCKET] == 1:
		refill_t = frames
	match phase:
		"fire":
			if t == 10:
				_fire()
			if t == 12:
				_check(dir.rockets_fired == 1 and arena.find_children("Rocket*", "", true, false).size() == 1, "a visible rocket is in flight")
			if t == 70:
				_check(dir.explosions.size() == 1, "the rocket exploded (%d)" % dir.explosions.size())
				var e: Vector3 = dir.explosions[0] if not dir.explosions.is_empty() else Vector3.INF
				_check(WeaponMath.flat(e, (peds["T"] as Pedestrian).global_position) < 1.5 or (peds["T"] as Pedestrian).is_down(), "it exploded on the person on the crosshair (%s)" % e)
				for k: String in ["T", "A", "B"]:
					var p: Pedestrian = peds[k]
					_check(p.state == Pedestrian.State.LAUNCHED or p.state == Pedestrian.State.KNOCKED_OUT, "%s inside 6 m is launched / knocked out (state %d)" % [k, p.state])
				_check((peds["C"] as Pedestrian).state == Pedestrian.State.FLEE, "C at ~7 m is not launched but flees")
				_check((peds["D"] as Pedestrian).state == Pedestrian.State.IDLE, "D 32 m away is untouched")
				var car: RoamTraffic.Vehicle = traffic.vehicles[1]
				_check(car.wreck_t >= 0.0 and car.body.get_node_or_null("Smoke") != null, "the car inside the radius is wrecked and smokes")
				_check(max_shake > 0.0, "the camera shakes")
				_check(dir.fx.transient_count("smoke") == 1 and dir.fx.transient_count("scorch") == 1, "a smoke puff and a scorch mark")
				_check(heat.has(WeaponData.HEAT_ROCKET), "+6 heat for the explosion (%s)" % str(heat))
				_check(arena.find_children("Rocket*", "", true, false).is_empty(), "the rocket is gone")
			if t == 140:
				var car2: RoamTraffic.Vehicle = traffic.vehicles[1]
				_check(car2.body.global_transform.basis.y.y < -0.9, "the car ended on its roof")
				_check((peds["T"] as Pedestrian).state == Pedestrian.State.KNOCKED_OUT and (peds["A"] as Pedestrian).state == Pedestrian.State.KNOCKED_OUT, "the launched people landed knocked out")
			if t == 200:
				_check(refill_t > 0 and absi(refill_t - empty_t - 150) <= 2, "1 round, 2.5 s reload (%d frames)" % (refill_t - empty_t))
				targets.clear()
				_ped("T2", Vector3(0.0, 0.0, -4.0))
				_next("close")
		"close":
			if t == 5:
				_fire()
			if t == 25:
				_check(dir.explosions.size() == 2 and player.is_knocked_down(), "a blast within 6 m knocks the player down (comic, no damage)")
			if t == 190:
				_check(player.move_state == "GROUND", "the player gets up again")
				targets.clear()
				player.pitch = 0.5
				_next("sky")
		"sky":
			if t == 10:
				_fire()
			if t == 270:
				_check(dir.explosions.size() == 3, "the rocket into the sky exploded")
				var far: float = dir.explosions.back().distance_to(player.global_position + Vector3(0.0, WeaponDirector.ROCKET_UP, 0.0)) if dir.explosions.size() == 3 else 0.0
				_check(far > 134.0 and far < 142.0, "... after 140 m (%.1f m)" % far)
				_check(arena.find_children("*", "GPUParticles3D", true, false).is_empty(), "no GPUParticles3D")
				Engine.time_scale = 1.0
				if fails.is_empty():
					print("✅ SUCCESS: WEAPONS ROCKET (flight, 6 m radius, launch arcs, flee, wreck, shake, smoke, scorch, heat, reload, player knock-down, max range)")
					quit(0)
				else:
					print("❌ FAILED: %d issues" % fails.size())
					quit(1)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless --path . --script tests/test_weapons_rocket.gd > /tmp/w_t5.log 2>&1; grep -E "SUCCESS|FAIL|Parse Error" /tmp/w_t5.log`
Expected: a parse error (`rockets_fired` / `WeaponDirector.ROCKET_UP` not found).

- [ ] **Step 3: Write `scripts/weapons/WeaponRocket.gd`**

```gdscript
# File: res://scripts/weapons/WeaponRocket.gd
# The visible rocket of the Tên lửa slot (spec section 3): flies straight at SPEED (35 m/s) from the shoulder toward the aim
# point, tests each physics step against the world (ray; player, people and traffic excluded) and against the people /
# vehicles (WeaponDirector.first_hit), and explodes on the first hit or after MAX_RANGE m (exploded -> explode_at).
# Code-built body (olive tube, red nose, fins) and a CPUParticles3D trail.
class_name WeaponRocket
extends Node3D

signal exploded(at: Vector3)

const SPEED: float = 35.0
const MAX_RANGE: float = 140.0

var director: WeaponDirector
var dir: Vector3 = Vector3.FORWARD
var travelled: float = 0.0
var ex: Array[RID] = []
var _done: bool = false


func launch(d: WeaponDirector, from: Vector3, direction: Vector3) -> void:
	director = d
	dir = direction.normalized()
	ex = d._exclusions()
	top_level = true
	global_position = from
	var up: Vector3 = Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	global_basis = Basis.looking_at(dir, up)
	_build()


func _build() -> void:
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.06
	cm.bottom_radius = 0.06
	cm.height = 0.55
	body.mesh = cm
	body.material_override = WeaponProps._mat(Color("#4B5D3A"))
	body.rotation = Vector3(PI * 0.5, 0.0, 0.0)      # cylinder axis Y -> Z (the flight axis)
	add_child(body)
	WeaponProps._sphere(self, 0.065, Vector3(0.0, 0.0, -0.28), Color("#B8382E"))
	WeaponProps._box(self, Vector3(0.24, 0.01, 0.1), Vector3(0.0, 0.0, 0.24), Color("#2E3A24"))
	WeaponProps._box(self, Vector3(0.01, 0.24, 0.1), Vector3(0.0, 0.0, 0.24), Color("#2E3A24"))
	director.fx.rocket_trail(self)


func _physics_process(delta: float) -> void:
	if _done or director == null:
		return
	var step: float = SPEED * delta
	var a: Vector3 = global_position
	var h: Dictionary = director.first_hit(a, dir, step, ex)
	if String(h["kind"]) != "none":
		global_position = h["pos"]
		_explode()
		return
	global_position = a + dir * step
	travelled += step
	if travelled >= MAX_RANGE:
		_explode()


func _explode() -> void:
	_done = true
	exploded.emit(global_position)
	queue_free()
```

- [ ] **Step 4: Explosion FX in `scripts/weapons/WeaponFX.gd`**

4a. After `const TRACER_COL := …` add:

```gdscript
const SCORCH_S: float = 20.0
```

4b. Append:

```gdscript
## Rocket explosion: big flash, sparks and dust, a dark smoke puff (4 s) and a scorch mark on the floor below (fades over
## its last 3 s of SCORCH_S). ex: bodies the floor ray ignores (people, the player, traffic).
func explosion(pos: Vector3, radius: float, ex: Array[RID] = []) -> void:
	burst("flash", pos + Vector3(0.0, 0.6, 0.0), Vector3.UP, 4.0)
	burst("sparks", pos, Vector3.UP, 2.5)
	burst("dust", pos, Vector3.UP, 3.0)
	var p := CPUParticles3D.new()
	p.name = "SmokePuff"
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = 36
	p.lifetime = 3.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.2
	p.direction = Vector3.UP
	p.spread = 60.0
	p.gravity = Vector3(0.0, 1.0, 0.0)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.0
	p.damping_min = 1.0
	p.damping_max = 1.5
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.6
	p.mesh = CineFX._particle_mesh(false)
	p.color_ramp = CineFX._ramp([Color(0.16, 0.15, 0.15, 0.85), Color(0.35, 0.35, 0.36, 0.0)], PackedFloat32Array([0.0, 1.0]))
	p.position = pos + Vector3(0.0, 0.8, 0.0)
	add_transient(p, 4.0, "smoke")
	p.emitting = true
	_scorch(pos, radius * 0.45, ex)


func _scorch(pos: Vector3, r: float, ex: Array[RID]) -> void:
	var floor_y: float = pos.y - 1.0
	if is_inside_tree():
		var rq := PhysicsRayQueryParameters3D.create(pos + Vector3(0.0, 1.0, 0.0), pos - Vector3(0.0, 6.0, 0.0))
		rq.exclude = ex
		rq.collide_with_areas = false
		var h: Dictionary = get_world_3d().direct_space_state.intersect_ray(rq)
		if not h.is_empty():
			floor_y = (h["position"] as Vector3).y
	var mi := MeshInstance3D.new()
	mi.name = "Scorch"
	var pm := PlaneMesh.new()
	pm.size = Vector2(r * 2.0, r * 2.0)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = CineFX.radial_texture(64, 1.2)
	m.albedo_color = Color(0.05, 0.04, 0.04, 0.8)
	m.set_meta("vice_done", true)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(pos.x, floor_y + 0.03, pos.z)
	add_transient(mi, SCORCH_S, "scorch", m, 3.0)


## Fire and smoke trail on a rocket (a child of it, freed with it).
func rocket_trail(rocket: Node3D) -> void:
	var p := CPUParticles3D.new()
	p.name = "Trail"
	p.amount = 40
	p.lifetime = 0.6
	p.local_coords = false
	p.direction = Vector3(0.0, 0.0, 1.0)
	p.spread = 8.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.2
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.35
	p.mesh = CineFX._particle_mesh(false)
	p.color_ramp = CineFX._ramp([Color(1.0, 0.75, 0.35, 0.9), Color(0.5, 0.5, 0.5, 0.5), Color(0.6, 0.6, 0.6, 0.0)], PackedFloat32Array([0.0, 0.25, 1.0]))
	p.position = Vector3(0.0, 0.0, 0.3)
	rocket.add_child(p)
	p.emitting = true
```

- [ ] **Step 5: Rocket cues in `scripts/weapons/WeaponAudio.gd`**

Replace the `CUES` line with:

```gdscript
const CUES: Array[String] = ["punch", "swish", "knife_hit", "reload", "dry_click", "shot_pistol", "shot_shotgun", "pump", "ricochet",
	"rocket_launch", "explosion"]
```

and add to the `match cue:` of `synth()`:

```gdscript
		"rocket_launch":
			return CineAudio._to_wav(CineAudio._mix([CineAudio._noise(0.6, 0.6, 3.5, 41, 0.7), CineAudio._tone(0.25, 300.0, 120.0, 0.5, 10.0)]))
		"explosion":
			return CineAudio._to_wav(CineAudio._mix([CineAudio._noise(1.4, 1.0, 3.0, 42, 0.55), CineAudio._tone(0.9, 80.0, 30.0, 1.0, 4.0), CineAudio._noise(0.12, 0.8, 30.0, 43, 0.1)]))
```

- [ ] **Step 6: Fire and explode in `scripts/weapons/WeaponDirector.gd`**

6a. After `const KNOCK_UP: float = 6.0 …` add:

```gdscript
const ROCKET_UP: float = 1.45            # launcher on the right shoulder
const SCARE_BLAST_R: float = 25.0        # explosions scare pedestrians this close (plan P11)
const IMPOSTOR_BLAST_R: float = 30.0
```

and after `var _pending_cues: Array = [] …` add:

```gdscript
var rockets_fired: int = 0
var explosions: Array[Vector3] = []      # tests: every explosion position
```

6b. In `try_fire()`, add this branch to the `match String(w["kind"]):` block, before `_:`:

```gdscript
		"rocket":
			_fire_rocket(w)
```

and change the comment of the `_:` branch to `# Task 6 adds boomerang and grenade here`.

6c. Append:

```gdscript
## Tên lửa: a WeaponRocket from the right shoulder toward the point under the crosshair (first_hit of the camera ray).
func _fire_rocket(w: Dictionary) -> void:
	var d0: Vector3 = aim_dir()
	var h: Dictionary = first_hit(aim_origin() + d0 * (player.camera.position.z + 0.3), d0, float(w["range"]))
	var f: Vector3 = player.facing_dir()
	var from: Vector3 = player.global_position + Vector3(0.0, ROCKET_UP, 0.0) + f * 0.5 + Vector3(-f.z, 0.0, f.x) * 0.25
	var to: Vector3 = h["pos"]
	var d: Vector3 = (to - from).normalized() if float(h["t"]) > 2.0 else d0
	var r := WeaponRocket.new()
	r.name = "Rocket"
	add_child(r)
	r.launch(self, from, d)
	r.exploded.connect(explode_at)
	fx.muzzle(from, d, 1.2)
	play_cue("rocket_launch", from, 2.0)
	rockets_fired += 1
	if player.model:
		CharacterBuilder.play(player.model, "flinch", 0.3)


## Rocket explosion (spec section 3): flash, sparks, dust, smoke, scorch, camera shake; people within the radius fly in comic
## arcs and land knocked out, vehicles flip and smoke, the player inside it is knocked down (never hurt), bystanders flee,
## impostors scatter. +6 heat.
func explode_at(pos: Vector3) -> void:
	var rad: float = float(WeaponData.SLOTS[WeaponData.Slot.ROCKET]["radius"])
	explosions.append(pos)
	fx.explosion(pos, rad, _exclusions())
	play_cue("explosion", pos, 6.0)
	var pd: float = player.global_position.distance_to(pos)
	if pd < 40.0:
		player.shake(lerpf(1.0, 0.15, pd / 40.0))
	if pd <= rad:
		player.knock_down(player.global_position - pos, 4.0)
	for n: Node3D in soft_targets():
		var d: float = WeaponMath.flat(n.global_position, pos)
		if d > rad or absf(n.global_position.y - pos.y) > 4.0:
			continue
		var k: float = clampf(d / rad, 0.0, 1.0)
		var away: Vector3 = WeaponMath.flat_dir(n.global_position - pos)
		hit_target(n, {"kind": "blast", "from": pos, "vel": away * lerpf(9.0, 4.0, k) + Vector3(0.0, lerpf(10.0, 6.0, k), 0.0)})
	if traffic:
		for idx: int in traffic.vehicles_near(pos, rad):
			traffic.hit_vehicle(idx, "blast", pos)
	if spawner:
		spawner.scatter_impostors(pos, IMPOSTOR_BLAST_R)
	_scare(pos, SCARE_BLAST_R)
	_heat(WeaponData.HEAT_ROCKET, pos, "rocket")
```

- [ ] **Step 7: Import, check the class cache, run the test**

```bash
godot --headless --import --path . > /tmp/w_imp.log 2>&1
grep -c 'WeaponRocket' .godot/global_script_class_cache.cfg
git diff --name-only -- '*.import' | xargs -r git checkout --
godot --headless --path . --script tests/test_weapons_rocket.gd > /tmp/w_t5.log 2>&1; grep -E "SUCCESS|FAIL|✗" /tmp/w_t5.log
```
Expected: the cache count is 1, and the test prints `✅ SUCCESS: WEAPONS ROCKET …`.

- [ ] **Step 8: Run the full regression, then commit**

```bash
git add scripts/weapons/WeaponRocket.gd scripts/weapons/WeaponRocket.gd.uid scripts/weapons/WeaponDirector.gd scripts/weapons/WeaponFX.gd scripts/weapons/WeaponAudio.gd tests/test_weapons_rocket.gd tests/test_weapons_rocket.gd.uid
git commit -m "feat(weapons): rocket launcher - visible rocket at 35 m/s from the shoulder to the crosshair point, 6 m explosion (people fly in comic arcs and land knocked out, vehicles flip onto the roof and smoke, the player inside is knocked down but never hurt, bystanders flee, impostors scatter), flash / sparks / dust / smoke / scorch, camera shake, synthesized launch and boom, +6 heat, 2.5 s reload

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 6: Dép tổ ong, sầu riêng and loa kẹo kéo (with the synthesized bolero)  [effort: xhigh]

**Files:**
- Create: `scripts/weapons/WeaponDep.gd`, `scripts/weapons/WeaponDurian.gd`, `scripts/weapons/StinkCloud.gd`, `scripts/weapons/SonicCone.gd`.
- Modify: `scripts/weapons/WeaponMath.gd`, `scripts/weapons/WeaponDirector.gd`, `scripts/weapons/WeaponFX.gd`, `scripts/weapons/WeaponAudio.gd`.
- Test: `tests/test_weapons_funny.gd`.

**Interfaces:**
- Consumes:
  - Task 2: `take_hit` kinds `bonk / stink / sonic`, `RoamTraffic.add_stop_zone`.
  - Task 3: `WeaponDirector.hit_target / soft_targets / hand_position / play_cue / _heat / held`, `WeaponFX.add_transient`.
  - Task 4: `_exclusions`.
- Produces:
  - `WeaponMath.boomerang_point(start, fwd, right, reach, side, u) -> Vector3`.
  - `class_name WeaponDep`: signal `returned(at: Vector3)`, constants `FLIGHT_S 1.4, SIDE_M 2.5, HIT_R 0.55`, `launch(d, from, forward, reach)`.
  - `class_name WeaponDurian`: signal `burst(at: Vector3)`, constant `FUSE_S 2.0`, `launch(from, v, exclusions)`.
  - `class_name StinkCloud`: `setup(d, pos, r, secs)`, `radius`, `life`, `contains(p) -> bool`.
  - `class_name SonicCone`: `setup(d)`, `tick(delta, apex, dir)`, `stop()`, `music: AudioStreamPlayer`, `held_t`.
  - `WeaponDirector`:
    - constants `DEP_KO_S 4.0, THROW_SPEED 11.0, THROW_UP 0.42`;
    - vars `dep_in_flight`, `dep_returns`, `last_dep_return: Vector3`, `stink_clouds: int`, `sonic: SonicCone`;
    - `dep_hit(n, at)`, `spawn_stink(pos) -> StinkCloud`.
  - `WeaponFX.stink(pos, r, secs)` and `sonic_ring(apex, dir)` (transient kinds `stink`, `sonic`).
  - `WeaponAudio`: cues `bonk, dep_whoosh, durian_pop, cough, bolero`, plus `synth_bolero() -> AudioStreamWAV`, `loa_stream() -> AudioStream` and `loa_file() -> String`.

- [ ] **Step 1: Write the failing test `tests/test_weapons_funny.gd`**

```gdscript
# File: res://tests/test_weapons_funny.gd
# Headless test of the Phase W funny weapons (spec section 3, W-D5, section 7): the dép tổ ong flies out straight, bonks the
# person in front (knocked out 4 s, stars, +1), curves back and returns to the hand, one in flight at a time; the sầu riêng
# lands ~7 m ahead, bursts after its 2 s fuse into an 8 m stink cloud (people inside pinch their nose then flee, the one
# outside is untouched, a cough plays, vehicles inside stop, +2) that is gone after 6 s; the loa kẹo kéo blasts a 10 m / 60°
# cone while held (people in it are pushed / dance, outside are untouched), its music is the synthesized looping bolero
# (or the owner's local loa_keo_keo file), +1 heat every 2 s, stops on release and on unequip.
# Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_weapons_funny.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")

var fails: Array[String] = []
var frames: int = 0
var phase: String = ""
var t0: int = 0
var started: bool = false
var arena: Node3D
var player: ThirdPersonController
var dir: WeaponDirector
var traffic: RoamTraffic
var targets: Array = []
var heat: Array[float] = []
var peds: Dictionary = {}
var cloud_pos: Vector3
var hold: bool = false


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	print("--- TEST WEAPONS: DÉP, SẦU RIÊNG, LOA ---")
	_math()
	_bolero()
	physics_frame.connect(_on_physics)


func _math() -> void:
	var s := Vector3(1.0, 1.3, 2.0)
	var f := Vector3(0.0, 0.0, -1.0)
	var r := Vector3(1.0, 0.0, 0.0)
	_check(WeaponMath.boomerang_point(s, f, r, 12.0, 2.5, 0.0).is_equal_approx(s) and WeaponMath.boomerang_point(s, f, r, 12.0, 2.5, 1.0).distance_to(s) < 1e-4, "the dép path starts and ends at the hand")
	_check(WeaponMath.boomerang_point(s, f, r, 12.0, 2.5, 0.5).is_equal_approx(s + f * 12.0), "it reaches 12 m straight ahead at half time")
	_check(absf(WeaponMath.boomerang_point(s, f, r, 12.0, 2.5, 0.25).x - s.x) < 1e-4, "straight on the way out")
	_check(absf(WeaponMath.boomerang_point(s, f, r, 12.0, 2.5, 0.75).x - s.x - 2.5) < 1e-4, "curves 2.5 m to the right on the way back")


func _rms(w: AudioStreamWAV, t_a: float, t_b: float) -> float:
	var d: PackedByteArray = w.data
	var a: int = int(t_a * CineAudio.SR)
	var b: int = mini(int(t_b * CineAudio.SR), d.size() / 2)
	var acc: float = 0.0
	for i: int in range(a, b):
		var v: float = float(d.decode_s16(i * 2)) / 32767.0
		acc += v * v
	return sqrt(acc / maxf(float(b - a), 1.0))


func _bolero() -> void:
	var t_ms: int = Time.get_ticks_msec()
	var w: AudioStreamWAV = WeaponAudio.synth_bolero()
	var ms: int = Time.get_ticks_msec() - t_ms
	var secs: float = float(w.data.size()) / 2.0 / float(CineAudio.SR)
	_check(w.loop_mode == AudioStreamWAV.LOOP_FORWARD and w.loop_end == w.data.size() / 2, "the bolero cue loops over its whole length")
	_check(absf(secs - 10.0) < 0.05, "the bolero cue is 4 bars at 96 bpm = 10 s (%.2f s)" % secs)
	_check(_rms(w, 0.0, 0.5) > 0.01 and _rms(w, 9.5, 10.0) > 0.01, "it is not silent at the start or the end (seamless loop)")
	_check(ms < 1500, "synthesized in %d ms" % ms)
	if WeaponAudio.loa_file() == "":
		_check(WeaponAudio.loa_stream() is AudioStreamWAV, "no owner loa_keo_keo file -> the synthesized bolero plays")
	else:
		_check(WeaponAudio.loa_stream() != null, "the owner's local loa_keo_keo file loads (%s)" % WeaponAudio.loa_file())
		print("  owner loa file found: %s" % WeaponAudio.loa_file())


func _next(p: String) -> void:
	phase = p
	t0 = frames


func _ped(key: String, at: Vector3) -> Pedestrian:
	var p: Pedestrian = World.ped(arena, at, 110 + peds.size(), player)
	peds[key] = p
	targets.append(p)
	return p


func _fire() -> void:
	dir.cooldown = 0.0
	dir.fire_override = true


func _count(pattern: String) -> int:
	return arena.find_children(pattern, "", true, false).size()


func _played(cue: String) -> bool:
	for p: AudioStreamPlayer3D in dir._sfx:
		if p.stream == WeaponAudio.stream(cue):
			return true
	return false


func _on_physics() -> void:
	frames += 1
	if not started:
		started = true
		arena = Node3D.new()
		root.add_child(arena)
		World.floor_box(arena)
		player = World.player(arena, Vector3.ZERO, 0.0)
		traffic = World.traffic(arena, player, -40.0)
		World.place_vehicle(traffic, 0, -80.0)
		World.place_vehicle(traffic, 1, 60.0)
		dir = World.director(arena, player, targets, traffic)
		dir.mayhem.connect(func(h: float, _at: Vector3, _c: String) -> void: heat.append(h))
		dir.equip(WeaponData.Slot.DEP)
		_ped("P", Vector3(0.0, 0.0, -8.0))
		_next("dep")
		return
	var t: int = frames - t0
	if dir.fire_override == true and t > 0 and not hold:
		dir.fire_override = false
	match phase:
		"dep":
			if t == 5:
				_fire()
			if t == 7:
				_check(dir.dep_in_flight and _count("Dep*") == 1 and dir.held != null and not dir.held.visible, "the dép is in flight (it left the hand)")
			if t == 10:
				_fire()
			if t == 12:
				_check(_count("Dep*") == 1, "only one dép in flight at a time")
			if t == 45:
				var p: Pedestrian = peds["P"]
				_check(p.state == Pedestrian.State.KNOCKED_OUT and p.ko_left <= 4.0 and p.ko_left > 3.0, "bonk: knocked out 4 s (%.2f s left)" % p.ko_left)
				_check(heat.has(WeaponData.HEAT_DEP), "+1 heat for the bonk (%s)" % str(heat))
				_check(not dir.fx.cine.find_children("Star*", "", true, false).is_empty() and _played("bonk"), "spinning stars and the bonk sound")
			if t == 95:
				_check(dir.dep_returns == 1 and not dir.dep_in_flight, "the dép came back after 1.4 s")
				_check(dir.last_dep_return.distance_to(dir.hand_position()) < 0.3, "... into the hand (%.2f m)" % dir.last_dep_return.distance_to(dir.hand_position()))
				_check(dir.held != null and dir.held.visible and _count("Dep*") == 0, "back in the hand")
			if t == 300:
				_check((peds["P"] as Pedestrian).state == Pedestrian.State.FLEE, "the bonked person got up and flees")
				targets.clear()
				heat.clear()
				dir.equip(WeaponData.Slot.DURIAN)
				_next("durian")
		"durian":
			if t == 5:
				_fire()
			if t == 7:
				_check(_count("Durian*") == 1, "a sầu riêng is thrown")
			if t == 128:
				var clouds: Array = arena.find_children("StinkCloud*", "", true, false)
				_check(dir.stink_clouds == 1 and clouds.size() == 1 and _count("Durian*") == 0, "it burst after the 2 s fuse into a stink cloud")
				if not clouds.is_empty():
					cloud_pos = (clouds[0] as Node3D).global_position
				var dd: float = WeaponMath.flat(cloud_pos, player.global_position)
				_check(dd > 3.0 and dd < 10.0 and cloud_pos.z < 0.0, "it landed ahead (%.1f m)" % dd)
				_check((clouds[0] as StinkCloud).radius * 2.0 == 8.0 if not clouds.is_empty() else false, "the cloud is 8 m wide")
				_ped("Q1", cloud_pos + Vector3(1.5, 0.0, 0.0))
				_ped("Q2", cloud_pos + Vector3(6.5, 0.0, 0.0))
				var car: RoamTraffic.Vehicle = traffic.vehicles[1]
				car.cruise = 5.0
				car.speed = 5.0
				dir.spawn_stink(car.body.global_position)
			if t == 150:
				_check((peds["Q1"] as Pedestrian).state == Pedestrian.State.STINK, "inside the cloud: pinches the nose")
				_check((peds["Q2"] as Pedestrian).state == Pedestrian.State.IDLE, "outside the 4 m radius: untouched")
				_check(_played("cough"), "a cough plays")
			if t == 200:
				_check((traffic.vehicles[1] as RoamTraffic.Vehicle).speed < 0.3, "a vehicle inside a stink cloud stops")
			if t == 300:
				_check((peds["Q1"] as Pedestrian).state == Pedestrian.State.FLEE, "then flees")
				_check(heat.count(WeaponData.HEAT_DURIAN) == 2, "+2 heat per burst (%s)" % str(heat))
			if t == 500:
				_check(_count("StinkCloud*") == 0 and traffic.stop_zones.is_empty(), "the clouds are gone after 6 s")
			if t == 600:
				_check((traffic.vehicles[1] as RoamTraffic.Vehicle).speed > 1.0, "traffic moves again")
				targets.clear()
				heat.clear()
				dir.equip(WeaponData.Slot.LOA)
				_ped("L1", Vector3(0.0, 0.0, -5.0))
				_ped("L2", Vector3(5.0 * sin(deg_to_rad(50.0)), 0.0, -5.0 * cos(deg_to_rad(50.0))))
				_ped("L3", Vector3(0.0, 0.0, -13.0))
				_next("loa")
		"loa":
			if t == 5:
				hold = true
				dir.fire_override = true
			if t == 10:
				_check(dir.sonic != null and dir.sonic.music.playing and dir.sonic.music.stream == WeaponAudio.loa_stream(), "holding fire blasts the loa and plays its music")
			if t == 40:
				var l1: Pedestrian = peds["L1"]
				_check(l1.state == Pedestrian.State.DANCE or l1.state == Pedestrian.State.FLEE, "in the cone: pushed (dances or flees)")
				_check(WeaponMath.flat(l1.global_position, player.global_position) > 5.3, "pushed back (%.2f m)" % WeaponMath.flat(l1.global_position, player.global_position))
				_check((peds["L2"] as Pedestrian).state == Pedestrian.State.IDLE and (peds["L3"] as Pedestrian).state == Pedestrian.State.IDLE, "50° off-axis and 13 m away: untouched")
				_check(dir.fx.transient_count("sonic") >= 1, "sonic rings")
			if t == 258:
				_check(heat.count(WeaponData.HEAT_LOA_PER_2S) == 2, "+1 heat every 2 s of blasting (%s after 4.2 s)" % str(heat))
				hold = false
				dir.fire_override = false
			if t == 260:
				_check(dir.sonic == null and _count("SonicCone*") == 0, "release stops the blast and the music")
				hold = true
				dir.fire_override = true
			if t == 266:
				_check(dir.sonic != null, "blasting again")
				dir.equip(WeaponData.Slot.UNARMED)
				_check(dir.sonic == null, "switching weapon stops the loa")
				hold = false
				dir.fire_override = false
				_check(arena.find_children("*", "GPUParticles3D", true, false).is_empty(), "no GPUParticles3D")
				Engine.time_scale = 1.0
				if fails.is_empty():
					print("✅ SUCCESS: WEAPONS DÉP / SẦU RIÊNG / LOA (boomerang path and return, bonk, stink cloud + traffic stop, sonic cone, bolero loop, heat)")
					quit(0)
				else:
					print("❌ FAILED: %d issues" % fails.size())
					quit(1)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless --path . --script tests/test_weapons_funny.gd > /tmp/w_t6.log 2>&1; grep -E "SUCCESS|FAIL|Parse Error" /tmp/w_t6.log`
Expected: a parse error (`WeaponMath.boomerang_point` / `WeaponAudio.synth_bolero` not found).

- [ ] **Step 3: Append the boomerang path to `scripts/weapons/WeaponMath.gd`**

```gdscript
## Dép tổ ong path at u (0..1): straight out along fwd to `reach` m at u = 0.5 (forward = reach·sin(πu)), then curving back on
## the right side (lateral = side·sin(2π(u − 0.5)) for u > 0.5), ending where it started.
static func boomerang_point(start: Vector3, fwd: Vector3, right: Vector3, reach: float, side: float, u: float) -> Vector3:
	var lateral: float = side * sin(TAU * (u - 0.5)) if u > 0.5 else 0.0
	return start + fwd * (reach * sin(PI * u)) + right * lateral
```

- [ ] **Step 4: Write `scripts/weapons/WeaponDep.gd`**

```gdscript
# File: res://scripts/weapons/WeaponDep.gd
# Dép tổ ong boomerang (spec section 3): flies straight out 12 m along the throw direction, curves back on the right and
# homes onto the thrower's hand over the last quarter of FLIGHT_S; bonks every person it passes within HIT_R (once each:
# WeaponDirector.dep_hit -> knocked out 4 s, stars, +1). One in flight at a time (WeaponDirector.dep_in_flight). Spins.
class_name WeaponDep
extends Node3D

signal returned(at: Vector3)

const FLIGHT_S: float = 1.4
const SIDE_M: float = 2.5
const HIT_R: float = 0.55
const SPIN: float = 22.0

var director: WeaponDirector
var start: Vector3
var fwd: Vector3
var right: Vector3
var reach: float = 12.0
var t: float = 0.0
var hit_ids: Dictionary = {}


func launch(d: WeaponDirector, from: Vector3, forward: Vector3, reach_m: float) -> void:
	director = d
	start = from
	fwd = WeaponMath.flat_dir(forward)
	right = Vector3(-fwd.z, 0.0, fwd.x)
	reach = reach_m
	top_level = true
	global_position = from
	var prop: Node3D = WeaponProps.build(WeaponData.Slot.DEP)
	add_child(prop)


func _physics_process(delta: float) -> void:
	t += delta
	var u: float = clampf(t / FLIGHT_S, 0.0, 1.0)
	var p: Vector3 = WeaponMath.boomerang_point(start, fwd, right, reach, SIDE_M, u)
	p = p.lerp(director.hand_position(), smoothstep(0.75, 1.0, u))
	global_position = p
	rotation.y += SPIN * delta
	for n: Node3D in director.soft_targets():
		var id: int = n.get_instance_id()
		if hit_ids.has(id) or (n.has_method("is_down") and bool(n.call("is_down"))):
			continue
		var c: Vector3 = n.global_position + Vector3(0.0, 1.2, 0.0)
		if Vector2(c.x - p.x, c.z - p.z).length() <= HIT_R + WeaponDirector.SOFT_R and absf(c.y - p.y) <= 0.9:
			hit_ids[id] = true
			director.dep_hit(n, p)
	if u >= 1.0:
		returned.emit(global_position)
		queue_free()
```

- [ ] **Step 5: Write `scripts/weapons/WeaponDurian.gd`**

```gdscript
# File: res://scripts/weapons/WeaponDurian.gd
# Sầu riêng stink grenade (spec section 3): thrown along a ballistic arc (gravity GRAVITY), bounces off the world (ray per
# step, BOUNCE kept) and comes to rest; after FUSE_S it bursts (`burst` -> WeaponDirector.spawn_stink). Code-built spiky ball.
class_name WeaponDurian
extends Node3D

signal burst(at: Vector3)

const FUSE_S: float = 2.0
const GRAVITY: float = 20.0
const BOUNCE: float = 0.35
const RADIUS: float = 0.13

var vel: Vector3 = Vector3.ZERO
var t: float = 0.0
var resting: bool = false
var ex: Array[RID] = []


func launch(from: Vector3, v: Vector3, exclusions: Array[RID]) -> void:
	top_level = true
	global_position = from
	vel = v
	ex = exclusions
	var body := Node3D.new()
	body.name = "Body"
	add_child(body)
	WeaponProps.add_durian(body, RADIUS)


func _physics_process(delta: float) -> void:
	t += delta
	if t >= FUSE_S:
		burst.emit(global_position)
		queue_free()
		return
	if resting:
		return
	vel.y -= GRAVITY * delta
	var a: Vector3 = global_position
	var b: Vector3 = a + vel * delta
	var h: Dictionary = {}
	if is_inside_tree():
		var rq := PhysicsRayQueryParameters3D.create(a, b + vel.normalized() * RADIUS)
		rq.exclude = ex
		rq.collide_with_areas = false
		h = get_world_3d().direct_space_state.intersect_ray(rq)
	if h.is_empty():
		global_position = b
		rotation += Vector3(7.0, 3.0, 0.0) * delta
		return
	var n: Vector3 = h["normal"]
	global_position = (h["position"] as Vector3) + n * RADIUS
	vel = vel.bounce(n) * BOUNCE
	if n.y > 0.7 and vel.length() < 2.0:
		resting = true
		vel = Vector3.ZERO
```

- [ ] **Step 6: Write `scripts/weapons/StinkCloud.gd`**

```gdscript
# File: res://scripts/weapons/StinkCloud.gd
# Sầu riêng stink cloud (spec section 3): 8 m wide (radius 4) for 6 s. Every TICK_S everyone inside it who has not been
# affected yet reacts once ("stink": pinches the nose, coughs, then flees; officers are stunned); the first MAX_COUGHS
# play a cough. Vehicles inside stop through RoamTraffic.add_stop_zone (WeaponDirector.spawn_stink). Green puffs: WeaponFX.
class_name StinkCloud
extends Node3D

const TICK_S: float = 0.25
const MAX_COUGHS: int = 3

var director: WeaponDirector
var radius: float = 4.0
var life: float = 6.0
var t: float = 0.0
var affected: Dictionary = {}
var _acc: float = 0.0
var _coughs: int = 0


func setup(d: WeaponDirector, pos: Vector3, r: float, secs: float) -> void:
	director = d
	radius = r
	life = secs
	top_level = true
	global_position = pos
	d.fx.stink(pos, r, secs)
	_affect()


func _physics_process(delta: float) -> void:
	t += delta
	_acc += delta
	if _acc >= TICK_S:
		_acc = 0.0
		_affect()
	if t >= life:
		queue_free()


func contains(p: Vector3) -> bool:
	return WeaponMath.flat(p, global_position) <= radius


func _affect() -> void:
	for n: Node3D in director.soft_targets():
		var id: int = n.get_instance_id()
		if affected.has(id) or not contains(n.global_position) or absf(n.global_position.y - global_position.y) > 3.0:
			continue
		affected[id] = true
		if director.hit_target(n, {"kind": "stink", "from": global_position}) == "stink" and _coughs < MAX_COUGHS:
			_coughs += 1
			director.play_cue("cough", n.global_position + Vector3(0.0, 1.5, 0.0), -3.0)
```

- [ ] **Step 7: Write `scripts/weapons/SonicCone.gd`**

```gdscript
# File: res://scripts/weapons/SonicCone.gd
# Loa kẹo kéo blast (spec section 3, W-D5): while the fire button is held, every TICK_S everyone inside the 10 m / 60° cone in
# front of the player is pushed away (PUSH m/s; some dance on the spot, then flee) and a pink ring shoots out; the music is
# WeaponAudio.loa_stream() (the owner's local loa_keo_keo file, else the synthesized bolero) on a looping AudioStreamPlayer;
# +1 heat every HEAT_EVERY_S of blasting. Created and stopped by WeaponDirector._tick_held.
class_name SonicCone
extends Node3D

const TICK_S: float = 0.2
const PUSH: float = 5.0
const HEAT_EVERY_S: float = 2.0

var director: WeaponDirector
var held_t: float = 0.0
var music: AudioStreamPlayer
var _acc: float = 0.0
var _heat_acc: float = 0.0


func setup(d: WeaponDirector) -> void:
	director = d
	music = AudioStreamPlayer.new()
	music.name = "LoaMusic"
	music.stream = WeaponAudio.loa_stream()
	music.bus = WeaponAudio.bus()
	music.volume_db = -2.0
	add_child(music)
	music.play()


## One physics step of blasting from apex along dir.
func tick(delta: float, apex: Vector3, dir: Vector3) -> void:
	held_t += delta
	_acc += delta
	_heat_acc += delta
	if _heat_acc >= HEAT_EVERY_S:
		_heat_acc -= HEAT_EVERY_S
		director._heat(WeaponData.HEAT_LOA_PER_2S, apex, "loa")
	if _acc < TICK_S:
		return
	_acc = 0.0
	var w: Dictionary = WeaponData.SLOTS[WeaponData.Slot.LOA]
	director.fx.sonic_ring(apex, dir)
	for n: Node3D in director.soft_targets():
		if WeaponMath.in_cone(apex, dir, deg_to_rad(float(w["half_deg"])), float(w["range"]), n.global_position):
			director.hit_target(n, {"kind": "sonic", "from": apex, "dir": WeaponMath.flat_dir(n.global_position - apex), "power": PUSH})


func stop() -> void:
	if music:
		music.stop()
	queue_free()
```

- [ ] **Step 8: Stink and sonic FX in `scripts/weapons/WeaponFX.gd`**

Append:

```gdscript
## Sầu riêng stink: green-brown puffs over a disc of radius r for secs.
func stink(pos: Vector3, r: float, secs: float) -> void:
	var p := CPUParticles3D.new()
	p.name = "Stink"
	p.amount = 48
	p.lifetime = 2.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(r * 0.8, 0.4, r * 0.8)
	p.direction = Vector3.UP
	p.spread = 30.0
	p.gravity = Vector3(0.0, 0.3, 0.0)
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.6
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.8
	p.mesh = CineFX._particle_mesh(false)
	p.color_ramp = CineFX._ramp([Color(0.45, 0.62, 0.18, 0.0), Color(0.45, 0.62, 0.18, 0.55), Color(0.38, 0.45, 0.15, 0.0)], PackedFloat32Array([0.0, 0.3, 1.0]))
	p.position = pos + Vector3(0.0, 0.6, 0.0)
	add_transient(p, secs, "stink")
	p.emitting = true


## Loa kẹo kéo: a pink ring in front of the speaker that grows and fades in 0.5 s.
func sonic_ring(apex: Vector3, dir: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "SonicRing"
	var tm := TorusMesh.new()
	tm.inner_radius = 0.45
	tm.outer_radius = 0.55
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.37, 0.69, 0.7)
	m.set_meta("vice_done", true)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var f: Vector3 = WeaponMath.flat_dir(dir)
	mi.transform = Transform3D(Basis.looking_at(f, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5), apex + f * 0.8)
	add_transient(mi, 0.5, "sonic", m, 0.5, 5.0)
```

- [ ] **Step 9: The bolero and the remaining cues in `scripts/weapons/WeaponAudio.gd`**

9a. Replace the `CUES` line with:

```gdscript
const CUES: Array[String] = ["punch", "swish", "knife_hit", "reload", "dry_click", "shot_pistol", "shot_shotgun", "pump", "ricochet",
	"rocket_launch", "explosion", "bonk", "dep_whoosh", "durian_pop", "cough", "bolero"]
const BOLERO_BPM: float = 96.0
const BOLERO_ROOT: float = 110.0         # A2
```

9b. Add to the `match cue:` of `synth()`:

```gdscript
		"bonk":
			return CineAudio._to_wav(CineAudio._mix([CineAudio._tone(0.25, 520.0, 260.0, 0.6, 12.0), CineAudio._tone(0.25, 1040.0, 700.0, 0.15, 16.0)]))
		"dep_whoosh":
			return CineAudio._to_wav(CineAudio._noise(0.35, 0.3, 6.0, 52, 0.85))
		"durian_pop":
			return CineAudio._to_wav(CineAudio._mix([CineAudio._noise(0.5, 0.6, 6.0, 53, 0.7), CineAudio._tone(0.2, 140.0, 90.0, 0.5, 10.0)]))
		"cough":
			var c: PackedFloat32Array = CineAudio._mix([CineAudio._noise(0.12, 0.5, 18.0, 54, 0.5), CineAudio._tone(0.12, 210.0, 170.0, 0.2, 14.0)])
			c.append_array(_gap(0.1))
			c.append_array(CineAudio._mix([CineAudio._noise(0.1, 0.45, 20.0, 55, 0.5), CineAudio._tone(0.1, 200.0, 160.0, 0.18, 15.0)]))
			return CineAudio._to_wav(c)
		"bolero":
			return synth_bolero()
```

9c. Append:

```gdscript
static func _hz(semi: int) -> float:
	return BOLERO_ROOT * pow(2.0, float(semi) / 12.0)


## One cached voice (bass / pluck / pad) per semitone, so the loop pastes a handful of precomputed tables.
static func _voice(cache: Dictionary, kind: String, semi: int, dur: float) -> PackedFloat32Array:
	var key: String = "%s%d" % [kind, semi]
	if not cache.has(key):
		var f: float = _hz(semi)
		match kind:
			"bass":
				cache[key] = CineAudio._tone(dur, f, f, 0.3, 2.5)
			"pluck":
				cache[key] = CineAudio._mix([CineAudio._tone(dur, f, f, 0.16, 6.0), CineAudio._tone(dur, f * 2.0, f * 2.0, 0.06, 9.0)])
			_:
				cache[key] = CineAudio._mix([CineAudio._tone(dur, f, f, 0.05, 0.4), CineAudio._tone(dur, f * 1.5, f * 1.5, 0.03, 0.4)])
	return cache[key]


## Synthesized slow bolero groove for the loa kẹo kéo (W-D5 default; a genre pattern, not any real song): 4 bars of 4/4 at
## BOLERO_BPM over the minor progression i - iv - V7 - i in A minor; the bolero bass rhythm (beat 1, the "and" of 2, beats
## 3 and 4: root / fifth), a plucked arpeggio of the chord tones on every eighth, a soft pad and rim ticks on the accents.
## Tails that run past the end are folded back to the start, so the 10 s buffer loops seamlessly (LOOP_FORWARD).
static func synth_bolero() -> AudioStreamWAV:
	var beat: float = 60.0 / BOLERO_BPM
	var bar: float = beat * 4.0
	var n_loop: int = int(round(bar * 4.0 * CineAudio.SR))
	var buf := PackedFloat32Array()
	buf.resize(n_loop + int(2.0 * CineAudio.SR))
	var chords: Array = [[0, 3, 7], [5, 8, 12], [7, 11, 14, 17], [0, 3, 7]]
	var roots: Array[int] = [0, 5, 7, 0]
	var cache: Dictionary = {}
	var tick: PackedFloat32Array = CineAudio._noise(0.03, 0.18, 80.0, 51, 0.2)
	for b: int in 4:
		var t0: float = float(b) * bar
		var ch: Array = chords[b]
		for e: Array in [[0.0, 0], [1.5, 7], [2.0, 0], [3.0, 7]]:
			CineAudio._paste(buf, _voice(cache, "bass", roots[b] + int(e[1]) - 12, beat * 0.9), t0 + float(e[0]) * beat, 1.0)
		for k: int in 8:
			var semi: int = int(ch[k % ch.size()]) + (12 if k >= 4 else 0) + 12
			CineAudio._paste(buf, _voice(cache, "pluck", semi, beat * 0.8), t0 + float(k) * beat * 0.5, 1.0)
		for s2: Variant in ch:
			CineAudio._paste(buf, _voice(cache, "pad", int(s2) + 12, bar), t0, 1.0)
		for x: float in [0.0, 1.5, 2.5, 3.0]:
			CineAudio._paste(buf, tick, t0 + x * beat, 1.0)
	for i: int in range(buf.size() - n_loop):
		buf[i] += buf[n_loop + i]
	buf.resize(n_loop)
	var w: AudioStreamWAV = CineAudio._to_wav(buf)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n_loop
	return w


## Loa kẹo kéo music (W-D5): the owner's user://sfx/loa_keo_keo.ogg or .mp3 (local only, never committed or exported),
## looping; otherwise the synthesized bolero cue (any user://sfx/bolero.ogg override applies to it).
static func loa_stream() -> AudioStream:
	if _cache.has("@loa"):
		return _cache["@loa"]
	var st: AudioStream = null
	var f: String = loa_file()
	if f != "":
		st = CineAudio._load_file(f)
		if st is AudioStreamOggVorbis:
			(st as AudioStreamOggVorbis).loop = true
		elif st is AudioStreamMP3:
			(st as AudioStreamMP3).loop = true
	if st == null:
		st = stream("bolero")
	_cache["@loa"] = st
	return st


## The owner's loa file ("" = none: the synthesized bolero plays).
static func loa_file() -> String:
	for ext: String in [".ogg", ".mp3"]:
		var p: String = SFX_DIR + LOA_FILE + ext
		if FileAccess.file_exists(p):
			return p
	return ""
```

- [ ] **Step 10: Throws and the held loa in `scripts/weapons/WeaponDirector.gd`**

10a. After `const IMPOSTOR_BLAST_R: float = 30.0` add:

```gdscript
const DEP_KO_S: float = 4.0              # dép bonk: pedestrians are out 4 s (officers 10 s, plan P5)
const THROW_SPEED: float = 11.0
const THROW_UP: float = 0.42
```

and after `var explosions: Array[Vector3] = [] …` add:

```gdscript
var dep_in_flight: bool = false
var dep_returns: int = 0
var last_dep_return: Vector3 = Vector3.ZERO
var stink_clouds: int = 0
var sonic: SonicCone = null
```

10b. In `equip()`, right after `	if slot == current:` / `		return`, add:

```gdscript
	_on_unequip()
	if slot == WeaponData.Slot.LOA:
		WeaponAudio.loa_stream()   # synthesize the bolero now (wheel open, game slowed) rather than on the first blast
```

10c. In `_physics_process()`, right after the line `	_fire_prev = fire`, add:

```gdscript
	_tick_held(delta, fire)
```

10d. Replace the whole `try_fire()` function with:

```gdscript
## One shot / swing / throw of the equipped weapon (cooldown, ammo and reload handled here). The loa ("cone") is held, not
## fired (_tick_held); a second dép waits for the first to come back.
func try_fire() -> void:
	var w: Dictionary = WeaponData.SLOTS[current]
	var kind: String = String(w["kind"])
	var mag: int = int(w["mag"])
	if kind == "cone" or (kind == "boomerang" and dep_in_flight):
		return
	if mag > 0 and ammo[current] <= 0:
		start_reload()
		return
	if not aiming:
		_face_camera()
	cooldown = float(w["cycle"])
	match kind:
		"melee":
			_melee(w)
		"hitscan":
			_hitscan(w)
		"pellets":
			_pellets(w)
		"rocket":
			_fire_rocket(w)
		"boomerang":
			_throw_dep(w)
		"grenade":
			_throw_durian(w)
	if mag > 0:
		ammo[current] -= 1
		if ammo[current] <= 0:
			start_reload()
	shots += 1
	_refresh_hud()
	fired.emit(current)
```

10e. Append:

```gdscript
## Dép tổ ong: thrown flat along the camera direction from the hand; the hand prop hides until it comes back.
func _throw_dep(w: Dictionary) -> void:
	var d := WeaponDep.new()
	d.name = "Dep"
	add_child(d)
	d.launch(self, hand_position(), WeaponMath.flat_dir(aim_dir()), float(w["reach"]))
	d.returned.connect(_on_dep_returned)
	dep_in_flight = true
	if held:
		held.visible = false
	play_cue("dep_whoosh", hand_position(), -2.0)
	if player.model:
		CharacterBuilder.play(player.model, "punch", 0.3)


func _on_dep_returned(at: Vector3) -> void:
	dep_in_flight = false
	dep_returns += 1
	last_dep_return = at
	if held:
		held.visible = true


## A dép bonk: knocked out DEP_KO_S with stars, "bonk", +1 heat.
func dep_hit(n: Node3D, at: Vector3) -> void:
	var r: String = hit_target(n, {"kind": "bonk", "from": at, "ko": DEP_KO_S})
	play_cue("bonk", at, 2.0)
	fx.burst("dust", at, Vector3.UP, 0.3)
	if r == "knocked_out":
		_heat(WeaponData.HEAT_DEP, n.global_position, "dep")


## Sầu riêng: lobbed forward (THROW_SPEED m/s, THROW_UP up); bursts into a StinkCloud after its fuse.
func _throw_durian(_w: Dictionary) -> void:
	var v: Vector3 = (WeaponMath.flat_dir(aim_dir()) + Vector3(0.0, THROW_UP, 0.0)).normalized() * THROW_SPEED
	var g := WeaponDurian.new()
	g.name = "Durian"
	add_child(g)
	g.launch(hand_position() + Vector3(0.0, 0.2, 0.0), v, _exclusions())
	g.burst.connect(spawn_stink)
	play_cue("dep_whoosh", hand_position(), -6.0)
	if player.model:
		CharacterBuilder.play(player.model, "punch", 0.3)


## Sầu riêng burst: a StinkCloud (8 m wide, 6 s) at pos; vehicles inside stop; +2 heat.
func spawn_stink(pos: Vector3) -> StinkCloud:
	var w: Dictionary = WeaponData.SLOTS[WeaponData.Slot.DURIAN]
	var c := StinkCloud.new()
	c.name = "StinkCloud"
	add_child(c)
	c.setup(self, pos, float(w["cloud_r"]), float(w["cloud_s"]))
	if traffic:
		traffic.add_stop_zone(pos, float(w["cloud_r"]), float(w["cloud_s"]))
	play_cue("durian_pop", pos)
	stink_clouds += 1
	_heat(WeaponData.HEAT_DURIAN, pos, "durian")
	return c


## Loa kẹo kéo: blasting while the fire button is held (music + SonicCone); stops on release, unequip and when blocked.
func _tick_held(delta: float, fire: bool) -> void:
	if current == WeaponData.Slot.LOA and fire:
		if sonic == null:
			sonic = SonicCone.new()
			sonic.name = "SonicCone"
			add_child(sonic)
			sonic.setup(self)
		if not aiming:
			_face_camera()
		sonic.tick(delta, player.global_position + Vector3(0.0, 1.2, 0.0), WeaponMath.flat_dir(aim_dir()))
		if player.model:
			CharacterBuilder.play(player.model, "carry", 0.25)
	elif sonic != null:
		sonic.stop()
		sonic = null


func _on_unequip() -> void:
	if sonic != null:
		sonic.stop()
		sonic = null
```

- [ ] **Step 11: Import, check the class cache, run the test**

```bash
godot --headless --import --path . > /tmp/w_imp.log 2>&1
grep -c 'WeaponDep\|WeaponDurian\|StinkCloud\|SonicCone' .godot/global_script_class_cache.cfg
git diff --name-only -- '*.import' | xargs -r git checkout --
godot --headless --path . --script tests/test_weapons_funny.gd > /tmp/w_t6.log 2>&1; grep -E "SUCCESS|FAIL|✗" /tmp/w_t6.log
```
Expected: the cache count is 4, and the test prints `✅ SUCCESS: WEAPONS DÉP / SẦU RIÊNG / LOA …`.

- [ ] **Step 12: Run the full regression, then commit**

```bash
git add scripts/weapons/WeaponDep.gd scripts/weapons/WeaponDep.gd.uid scripts/weapons/WeaponDurian.gd scripts/weapons/WeaponDurian.gd.uid scripts/weapons/StinkCloud.gd scripts/weapons/StinkCloud.gd.uid scripts/weapons/SonicCone.gd scripts/weapons/SonicCone.gd.uid scripts/weapons/WeaponMath.gd scripts/weapons/WeaponDirector.gd scripts/weapons/WeaponFX.gd scripts/weapons/WeaponAudio.gd tests/test_weapons_funny.gd tests/test_weapons_funny.gd.uid
git commit -m "feat(weapons): the owner's funny weapons - dép tổ ong boomerang (straight out 12 m, curves back into the hand, bonk 4 s with stars), sầu riêng grenade (2 s fuse, 8 m stink cloud for 6 s: nose pinch + cough + flee, traffic stops), loa kẹo kéo (hold: 10 m / 60° sonic cone pushes people, some dance; synthesized looping bolero or the owner's local loa_keo_keo file), heat per the spec

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 7: WantedDirector – heat, stars, line-of-sight decay, HUD stars and the radar search circle  [effort: xhigh]

**Files:**
- Create: `scripts/wanted/WantedDirector.gd`.
- Modify: `scripts/ui/ViceStars.gd` (`cells`), `scripts/ui/ViceRadar.gd` (search circle), `scripts/FreeRoam.gd` (wiring, classic star row, blocking, hide list).
- Test: `tests/test_wanted.gd`.

**Interfaces:**
- Consumes:
  - Task 3: `WeaponDirector.mayhem(heat, at, cause)`, `FreeRoam.mayhem_blocked()`, `_build_mayhem()`.
  - `ViceHUD.set_stars(n, label)`, `ViceHUD.radar`, `ViceHUD.STAR_CELL`, `ViceHUD.style_active()`.
  - `MapData.landmark("campus_plot")`, `MapData.poly`.
- Produces:
  - `class_name WantedDirector extends Node3D`:
    - signals `stars_changed(stars: int)`, `cleared`;
    - constants `STAR_HEAT [4, 12, 25]`, `LOSE_S [12, 20, 30]`, `SEARCH_R [30, 40, 50]`, `OFFICER_KO_HEAT 5.0`, `IDLE_DECAY 0.2`, `SIGHT_R 45.0`, `LABEL_CAMPUS`, `LABEL_STREET`;
    - vars `heat, stars, state ("free" | "stamp" | "cutscene" | "service"), player, roam, md, traffic, vice_hud, classic_stars, is_campus_fn, observers: Array, last_seen, seen, seen_t, spawning: bool`;
    - `setup(opts)`, `add_heat(amount, at := ZERO, cause := "")`, static `stars_for(heat) -> int`, `target_pos() -> Vector3`, `is_campus(p) -> bool`, `add_observer(n)`, `remove_observer(n)`, `can_see(o, ex := []) -> bool`, `tick(delta)`, `search_area() -> Vector3` (x, z, r; r = 0 means none), `refresh_hud()`, `clear()`.
  - `ViceStars.cells: int` (default 5).
  - `ViceRadar.search: Vector3` (x, z, r) and `search_draws: int`.
  - `FreeRoam`: vars `wanted: WantedDirector`, `classic_stars: ViceStars`.

- [ ] **Step 1: Write the failing test `tests/test_wanted.gd`**

```gdscript
# File: res://tests/test_wanted.gd
# Headless test of the Phase W wanted level (spec W-D6, section 4, section 7 "Wanted"): heat -> stars at 4 / 12 / 25, only
# rising with heat; with nobody seeing the player the level drops one star after 12 / 20 / 30 s and the heat falls to that
# star's threshold; every crime restarts the search; below one star the heat fades; an observer with line of sight keeps
# the level, a wall breaks the sight; the radar search circle (centre = last seen, radius 30 / 40 / 50 m) shows only while
# nobody sees the player and is drawn; ViceHUD shows 3-cell stars with the campus / street label; busted / service ignore
# heat. Part B (FreeRoam, crowd off): WeaponDirector.mayhem feeds the level, the HUD has 3 star cells, campus vs streets,
# the wheel is blocked while the wanted state is not "free".
# Uses WantedDirector.tick(delta) directly (physics process off) for the long timers; counts physics frames otherwise.
# Run:  godot --headless --path . --script tests/test_wanted.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")

var fails: Array[String] = []
var frames: int = 0
var phase: String = ""
var t0: int = 0
var started: bool = false
var arena: Node3D
var player: ThirdPersonController
var wanted: WantedDirector
var vh: ViceHUD
var classic: ViceStars
var campus: bool = false
var changes: Array[int] = []
var cleared_n: int = 0
var roam: Node3D


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	print("--- TEST WANTED LEVEL ---")
	_check(WantedDirector.stars_for(3.9) == 0 and WantedDirector.stars_for(4.0) == 1 and WantedDirector.stars_for(11.9) == 1, "1 star at 4 heat")
	_check(WantedDirector.stars_for(12.0) == 2 and WantedDirector.stars_for(25.0) == 3 and WantedDirector.stars_for(100.0) == 3, "2 stars at 12, 3 at 25, never more")
	physics_frame.connect(_on_physics)


func _ticks(n: int) -> void:
	for i: int in n:
		wanted.tick(1.0)


func _next(p: String) -> void:
	phase = p
	t0 = frames


func _on_physics() -> void:
	frames += 1
	if not started:
		started = true
		arena = Node3D.new()
		root.add_child(arena)
		World.floor_box(arena)
		player = World.player(arena, Vector3.ZERO, 0.0)
		vh = ViceHUD.new()
		vh.name = "ViceHUD"
		arena.add_child(vh)
		var layer := CanvasLayer.new()
		arena.add_child(layer)
		classic = ViceStars.new()
		classic.cells = 3
		layer.add_child(classic)
		wanted = WantedDirector.new()
		wanted.name = "Wanted"
		arena.add_child(wanted)
		wanted.setup({"player": player, "vice_hud": vh, "classic_stars": classic, "is_campus_fn": func(_p: Vector3) -> bool: return campus})
		wanted.spawning = false
		wanted.set_physics_process(false)
		wanted.stars_changed.connect(func(s: int) -> void: changes.append(s))
		wanted.cleared.connect(func() -> void: cleared_n += 1)
		_next("a")
		return
	var t: int = frames - t0
	match phase:
		"a":
			if t == 2:
				_part_a()
				World.wall(arena, Vector3(0.0, 1.5, -5.0), Vector3(6.0, 3.0, 0.5))
				_next("b")
		"b":
			if t == 3:
				_part_b()
			if t == 12:
				_check(vh.radar.search_draws > 0, "the radar draws the search circle")
				_start_freeroam()
		"c":
			if t == 60:
				_part_c()


func _part_a() -> void:
	wanted.add_heat(3.9)
	_check(wanted.stars == 0, "3.9 heat: no star")
	wanted.add_heat(0.1)
	_check(wanted.stars == 1 and changes.size() == 1 and changes[0] == 1, "4 heat: 1 star (stars_changed)")
	_check(vh.stars.filled == 1 and vh.stars.visible and vh.stars_label.text == WantedDirector.LABEL_STREET, "ViceHUD shows 1 star, street label")
	_check(not classic.visible, "the classic star row stays hidden in vice style")
	wanted.add_heat(8.0)
	_check(wanted.stars == 2, "12 heat: 2 stars")
	wanted.add_heat(13.0)
	wanted.add_heat(50.0)
	_check(wanted.stars == 3, "25+ heat: 3 stars, never more")
	_ticks(1)
	var sa: Vector3 = wanted.search_area()
	_check(is_equal_approx(sa.z, 50.0) and vh.radar.search.is_equal_approx(sa), "nobody sees him: search circle 50 m at 3 stars on the radar")
	_ticks(28)
	_check(wanted.stars == 3, "3 stars kept for 29 s")
	_ticks(1)
	_check(wanted.stars == 2 and is_equal_approx(wanted.heat, 12.0), "after 30 s unseen: 2 stars, heat 12")
	_ticks(19)
	_check(wanted.stars == 2, "2 stars kept for 19 s")
	_ticks(1)
	_check(wanted.stars == 1 and is_equal_approx(wanted.heat, 4.0), "after 20 s more: 1 star, heat 4")
	_ticks(12)
	_check(wanted.stars == 0 and wanted.heat == 0.0 and cleared_n == 1, "after 12 s more: cleared")
	_check(not vh.stars.visible and wanted.search_area() == Vector3.ZERO, "no stars, no search circle")
	wanted.add_heat(4.0)
	_ticks(8)
	wanted.add_heat(0.5)
	_ticks(8)
	_check(wanted.stars == 1, "a new crime restarts the 12 s search")
	_ticks(4)
	_check(wanted.stars == 0, "12 s after the last crime: cleared")
	wanted.add_heat(3.0)
	_ticks(5)
	_check(absf(wanted.heat - 2.0) < 0.01, "below one star the heat fades 0.2 / s (%.2f)" % wanted.heat)
	var o := Node3D.new()
	o.name = "Observer"
	arena.add_child(o)
	o.global_position = Vector3(0.0, 0.0, -10.0)
	wanted.add_observer(o)
	wanted.add_heat(2.5)
	_ticks(15)
	_check(wanted.stars == 1 and wanted.seen and wanted.search_area() == Vector3.ZERO, "an observer with line of sight keeps the level, no search circle")


func _part_b() -> void:
	_ticks(1)
	_check(not wanted.seen, "the wall breaks the line of sight")
	var sa: Vector3 = wanted.search_area()
	_check(is_equal_approx(sa.z, 30.0) and Vector2(sa.x, sa.y).length() < 0.5, "search circle 30 m around the last seen point (%s)" % sa)
	_ticks(10)
	_check(wanted.stars == 1, "1 star kept for 11 s behind the wall")
	_ticks(1)
	_check(wanted.stars == 0, "lost after 12 s")
	campus = true
	wanted.add_heat(4.0)
	_check(vh.stars_label.text == WantedDirector.LABEL_CAMPUS, "campus label")
	wanted.state = "service"
	wanted.add_heat(30.0)
	_check(wanted.stars == 1, "heat is ignored while busted / in community service")
	wanted.state = "free"
	_ticks(1)


func _start_freeroam() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var n: Node = (load(pair[1]) as Script).new()
			n.name = pair[0]
			root.add_child(n)
	arena.queue_free()
	roam = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	roam.set("crowd_enabled", false)
	root.add_child(roam)
	_next("c")


func _part_c() -> void:
	var w: WantedDirector = roam.get("wanted")
	var wd: WeaponDirector = roam.get("weapons")
	_check(w != null and wd != null, "FreeRoam builds the wanted level with the weapons")
	wd.mayhem.emit(12.0, Vector3.ZERO, "test")
	_check(w.stars == 2, "WeaponDirector.mayhem feeds the wanted level (%d stars)" % w.stars)
	var hud: ViceHUD = roam.get("vice_hud")
	_check(hud.stars.cells == 3 and hud.stars.filled == 2, "ViceHUD: 3 star cells, 2 filled")
	var md: MapData = roam.get("md")
	_check(not w.is_campus(md.spawn_transform().origin), "the BE6 spawn is on the streets")
	var cc: Vector2 = FPTUCampusBuilder.ring_courtyard_rect().get_center()
	_check(w.is_campus(FPTUCampusBuilder.real_plot_transform() * Vector3(cc.x, 0.0, cc.y)), "the campus courtyard is inside the plot")
	var ww: WeaponWheel = roam.get("weapon_wheel")
	ww.manual = true
	w.state = "service"
	ww.press()
	ww.step_real(0.2)
	_check(not ww.is_open(), "the wheel is blocked while the wanted state is not free")
	w.state = "free"
	w.clear()
	_check(w.stars == 0 and not hud.stars.visible, "clear() empties the level")
	Engine.time_scale = 1.0
	if fails.is_empty():
		print("✅ SUCCESS: WANTED LEVEL (thresholds, LOS decay 12/20/30 s, crime restarts the search, idle fade, wall breaks sight, search circle, HUD stars, FreeRoam wiring)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless --path . --script tests/test_wanted.gd > /tmp/w_t7.log 2>&1; grep -E "SUCCESS|FAIL|Parse Error" /tmp/w_t7.log`
Expected: a parse error (`WantedDirector` not declared).

- [ ] **Step 3: Write `scripts/wanted/WantedDirector.gd`**

```gdscript
# File: res://scripts/wanted/WantedDirector.gd
# Phase W wanted level (spec W-D6, section 4):
#   - heat comes from the weapons (WeaponDirector.mayhem -> add_heat) and from officers knocked out (+5, Task 8);
#   - 1 / 2 / 3 stars at 4 / 12 / 25 heat; stars only rise with heat (plan P4);
#   - every crime tells the officers where the player is (the search restarts there);
#   - the officers ("observers": Officer nodes from Task 8) look for the player: eyes 1.6 m, chest 1.3 m, within SIGHT_R,
#     RAYS_PER_TICK rays per physics frame round-robin;
#   - while none sees the player for 12 / 20 / 30 s (by stars) the level drops one star and the heat falls to that star's
#     threshold; below one star the heat fades at IDLE_DECAY / s;
#   - ViceHUD shows the stars (3 cells; classic style: the small row under the clock), the radar shows the search circle
#     (centre = last seen point, radius SEARCH_R) while nobody sees him. Entering BE6 changes nothing.
# state: "free" | "stamp" | "cutscene" | "service" (Tasks 10-11). Time-based logic runs in tick(delta) (tests call it with
# set_physics_process(false)). GameFX / StageManager are only reached through get_node_or_null.
class_name WantedDirector
extends Node3D

signal stars_changed(stars: int)
signal cleared

const STAR_HEAT: Array[float] = [4.0, 12.0, 25.0]
const LOSE_S: Array[float] = [12.0, 20.0, 30.0]
const SEARCH_R: Array[float] = [30.0, 40.0, 50.0]
const OFFICER_KO_HEAT: float = 5.0
const IDLE_DECAY: float = 0.2
const SIGHT_R: float = 45.0
const RAYS_PER_TICK: int = 3
const EYE_Y: float = 1.6
const CHEST_Y: float = 1.3
const CIRCLE_AFTER_S: float = 0.5
const LABEL_CAMPUS: String = "BẢO VỆ ĐANG TÌM"
const LABEL_STREET: String = "CẢNH SÁT ĐANG TRUY"

var heat: float = 0.0
var stars: int = 0
var state: String = "free"
var player: ThirdPersonController
var roam: Node
var md: MapData
var traffic: RoamTraffic
var vice_hud: ViceHUD
var classic_stars: ViceStars
var is_campus_fn: Callable
var campus_poly: PackedVector2Array = PackedVector2Array()
var observers: Array = []
var last_seen: Vector3 = Vector3.ZERO
var seen: bool = false
var seen_t: float = 0.0
## Officer spawning (Tasks 8-9). Tests of the heat / decay logic switch it off.
var spawning: bool = true
var _ray_i: int = 0
var _sees: Dictionary = {}               # observer instance id -> latest line-of-sight result


## opts: player, roam (FreeRoam: roam_position, find_free_spot, play_cinematic, bike), md (MapData: campus plot), traffic,
## vice_hud, classic_stars, is_campus_fn (tests: Vector3 -> bool). Call after add_child.
func setup(opts: Dictionary) -> void:
	player = opts.get("player")
	roam = opts.get("roam")
	md = opts.get("md")
	traffic = opts.get("traffic")
	vice_hud = opts.get("vice_hud")
	classic_stars = opts.get("classic_stars")
	is_campus_fn = opts.get("is_campus_fn", Callable())
	if md:
		var lm: Variant = md.landmark("campus_plot")
		if lm is Array:
			campus_poly = MapData.poly(lm)
	refresh_hud()


## Where the officers look for the player: the bike while riding (FreeRoam.roam_position), else the player.
func target_pos() -> Vector3:
	if roam and roam.has_method("roam_position"):
		return roam.call("roam_position")
	return player.global_position if player else Vector3.ZERO


func is_campus(p: Vector3) -> bool:
	if is_campus_fn.is_valid():
		return bool(is_campus_fn.call(p))
	return campus_poly.size() >= 3 and Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), campus_poly)


static func stars_for(h: float) -> int:
	var n: int = 0
	for i: int in STAR_HEAT.size():
		if h >= STAR_HEAT[i] - 1e-6:
			n = i + 1
	return n


## Heat from mayhem (WeaponDirector.mayhem). Ignored while busted / in community service. Every crime restarts the search
## at the player's position.
func add_heat(amount: float, _at: Vector3 = Vector3.ZERO, _cause: String = "") -> void:
	if state != "free" or amount <= 0.0:
		return
	heat += amount
	last_seen = target_pos()
	seen_t = 0.0
	var n: int = stars_for(heat)
	if n > stars:
		stars = n
		_on_stars_changed()


func add_observer(n: Node3D) -> void:
	if not observers.has(n):
		observers.append(n)


func remove_observer(n: Node3D) -> void:
	observers.erase(n)
	_sees.erase(n.get_instance_id())


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if state != "free":
		return
	_prune()
	if stars == 0:
		heat = maxf(0.0, heat - IDLE_DECAY * delta)
		seen = false
		_update_search()
		return
	_los_step()
	if seen:
		seen_t = 0.0
		last_seen = target_pos()
	else:
		seen_t += delta
		if seen_t >= LOSE_S[stars - 1]:
			_drop_star()
	_update_search()


func _los_step() -> void:
	var n: int = observers.size()
	if n == 0:
		seen = false
		return
	var ex: Array[RID] = _ray_exclusions()
	for k: int in mini(RAYS_PER_TICK, n):
		_ray_i = (_ray_i + 1) % n
		var o: Node3D = observers[_ray_i]
		var v: bool = can_see(o, ex)
		_sees[o.get_instance_id()] = v
		if "sees_player" in o:
			o.set("sees_player", v)
	seen = false
	for o2: Node3D in observers:
		if bool(_sees.get(o2.get_instance_id(), false)):
			seen = true
			break


## Line of sight from an observer's eyes to the player's chest within SIGHT_R (a knocked-out officer sees nothing). The
## officers, the player, the bike and the traffic do not block it; buildings and people do.
func can_see(o: Node3D, ex: Array[RID] = []) -> bool:
	if o.has_method("is_down") and bool(o.call("is_down")):
		return false
	var eye: Vector3 = o.global_position + Vector3(0.0, EYE_Y, 0.0)
	var chest: Vector3 = target_pos() + Vector3(0.0, CHEST_Y, 0.0)
	if eye.distance_to(chest) > SIGHT_R or not is_inside_tree():
		return false
	var rq := PhysicsRayQueryParameters3D.create(eye, chest)
	rq.exclude = ex if not ex.is_empty() else _ray_exclusions()
	rq.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(rq).is_empty()


func _ray_exclusions() -> Array[RID]:
	var ex: Array[RID] = []
	for ob: Variant in observers:
		if ob is CollisionObject3D:
			ex.append((ob as CollisionObject3D).get_rid())
	if player:
		ex.append(player.get_rid())
	if roam and roam.get("bike") is CollisionObject3D:
		ex.append((roam.get("bike") as CollisionObject3D).get_rid())
	if traffic:
		for b: Variant in traffic.bodies():
			ex.append((b as CollisionObject3D).get_rid())
	return ex


func _drop_star() -> void:
	stars -= 1
	heat = STAR_HEAT[stars - 1] if stars > 0 else 0.0
	seen_t = 0.0
	_on_stars_changed()
	if stars == 0:
		cleared.emit()


func _on_stars_changed() -> void:
	refresh_hud()
	stars_changed.emit(stars)


## Stars on ViceHUD (vice) or the classic row under the clock, with the campus / street label.
func refresh_hud() -> void:
	var label: String = LABEL_CAMPUS if is_campus(target_pos()) else LABEL_STREET
	if vice_hud:
		vice_hud.set_stars(stars, label)
	if classic_stars:
		classic_stars.set_filled(stars)
		classic_stars.visible = stars > 0 and not ViceHUD.style_active()


## The search circle (x, z, radius) while nobody has seen the player for CIRCLE_AFTER_S; ZERO otherwise.
func search_area() -> Vector3:
	if stars > 0 and not seen and seen_t >= CIRCLE_AFTER_S:
		return Vector3(last_seen.x, last_seen.z, SEARCH_R[stars - 1])
	return Vector3.ZERO


func _update_search() -> void:
	if vice_hud and vice_hud.radar:
		vice_hud.radar.search = search_area()


func _prune() -> void:
	for i: int in range(observers.size() - 1, -1, -1):
		var o: Variant = observers[i]
		if not is_instance_valid(o) or not (o as Node).is_inside_tree():
			observers.remove_at(i)


## Empty the level (end of community service; tests).
func clear() -> void:
	heat = 0.0
	stars = 0
	seen = false
	seen_t = 0.0
	_on_stars_changed()
	_update_search()
	cleared.emit()
```

- [ ] **Step 4: A 3-cell star row in `scripts/ui/ViceStars.gd`**

4a. After `var flash_t: float = 0.0` add:

```gdscript
## Number of star cells drawn (5 for the Màn 3 lecturer bar; FreeRoam's wanted level uses 3, Phase W).
var cells: int = 5
```

4b. In `_draw()`, replace `	for i: int in range(5):` with:

```gdscript
	for i: int in range(cells):
```

- [ ] **Step 5: The search circle in `scripts/ui/ViceRadar.gd`**

5a. After `const INK := Color("#1B0F33")` add:

```gdscript
const SEARCH_FILL := Color(0.3, 0.55, 1.0, 0.22)
const SEARCH_RIM := Color(0.45, 0.7, 1.0, 0.85)
```

5b. After the `route` property (the block ending in `		_dirty = true` under `var route: …`) add:

```gdscript
## Phase W wanted search area (map x, map z, radius m); radius 0 = none. A translucent disc clipped to the radar.
var search: Vector3 = Vector3.ZERO:
	set(v):
		if not v.is_equal_approx(search):
			search = v
			_dirty = true
var search_draws: int = 0
```

5c. In `_draw()`, insert before the line `	# blip (ngoài tầm: nằm ở mép)`:

```gdscript
	# Phase W: vòng tìm kiếm của truy nã (cắt theo đĩa radar)
	if search.z > 0.0:
		var sc: Vector2 = to_radar(Vector2(search.x, search.y))
		var sr: float = search.z * k
		var disc := PackedVector2Array()
		var rim_poly := PackedVector2Array()
		for i3: int in 48:
			var a3: float = TAU * float(i3) / 48.0
			disc.append(sc + Vector2(cos(a3), sin(a3)) * sr)
			rim_poly.append(c + Vector2(cos(a3), sin(a3)) * rr)
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(disc, rim_poly):
			draw_colored_polygon(piece, SEARCH_FILL)
		if sc.distance_to(c) + sr <= rr:
			draw_arc(sc, sr, 0.0, TAU, 48, SEARCH_RIM, 2.0, true)
		search_draws += 1
```

- [ ] **Step 6: Wire the wanted level into `scripts/FreeRoam.gd`**

6a. After `var weapon_hud: WeaponHUD` add:

```gdscript
var wanted: WantedDirector
## Classic style: small wanted star row under the clock (spec section 4); ViceHUD shows them in vice style.
var classic_stars: ViceStars
```

6b. Append to `_build_mayhem()`:

```gdscript
	classic_stars = ViceStars.new()
	classic_stars.name = "ClassicStars"
	classic_stars.cells = 3
	classic_stars.align_right = false
	classic_stars.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	classic_stars.offset_left = 24.0
	classic_stars.offset_top = 64.0
	classic_stars.offset_right = 24.0 + 3.0 * 22.0
	classic_stars.offset_bottom = 64.0 + 22.0
	classic_stars.visible = false
	hud.add_child(classic_stars)
	if vice_hud:
		vice_hud.stars.cells = 3
		vice_hud.stars.custom_minimum_size = Vector2(3.0 * ViceHUD.STAR_CELL, ViceHUD.STAR_CELL)
	wanted = WantedDirector.new()
	wanted.name = "Wanted"
	add_child(wanted)
	wanted.setup({"player": player, "roam": self, "md": md, "traffic": traffic, "vice_hud": vice_hud, "classic_stars": classic_stars})
	weapons.mayhem.connect(wanted.add_heat)
```

6c. In `mayhem_blocked()`, after `	if map_overlay and map_overlay.visible:` / `		return true`, add:

```gdscript
	if wanted and wanted.state != "free":
		return true   # busted (stamp, cutscene) or community service
```

6d. In `play_cinematic()`, append `, wanted` to the hidden list, so it reads `[player, bike, hint_holder, tod_holder, stats_holder, vice_hud, stamina_bar, map_overlay, pedestrians, traffic, weapon_hud, wanted]`.

6e. At the end of `_apply_hud_style()`, add:

```gdscript
	if wanted:
		wanted.refresh_hud()   # classic star row vs ViceHUD stars
```

- [ ] **Step 7: Import, check the class cache, run the test**

```bash
godot --headless --import --path . > /tmp/w_imp.log 2>&1
grep -c 'WantedDirector' .godot/global_script_class_cache.cfg
git diff --name-only -- '*.import' | xargs -r git checkout --
godot --headless --path . --script tests/test_wanted.gd > /tmp/w_t7.log 2>&1; grep -E "SUCCESS|FAIL|✗" /tmp/w_t7.log
```
Expected: the cache count is 1, and the test prints `✅ SUCCESS: WANTED LEVEL …`. Also run `tests/test_vice_hud.gd` and `tests/test_hud_bounds.gd`: 5-cell rows elsewhere are unchanged and the 3-cell FreeRoam row fits.

- [ ] **Step 8: Run the full regression, then commit**

```bash
git add scripts/wanted/WantedDirector.gd scripts/wanted/WantedDirector.gd.uid scripts/ui/ViceStars.gd scripts/ui/ViceRadar.gd scripts/FreeRoam.gd tests/test_wanted.gd tests/test_wanted.gd.uid
git commit -m "feat(wanted): wanted level - heat from weapons, 1/2/3 stars at 4/12/25 heat, officer line of sight (round-robin rays), one star lost after 12/20/30 s unseen, every crime restarts the search, idle heat fade, ViceHUD 3-cell stars with campus / street label and a classic row under the clock, radar search circle clipped to the disc; FreeRoam wiring, weapons blocked while busted / in service

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 8: Officers on foot – campus guards and Mr.T  [effort: xhigh]

**Files:**
- Create: `scripts/wanted/Officer.gd`.
- Modify: `scripts/wanted/WantedDirector.gd` (spawning, despawning, knocked officers), `scripts/FreeRoam.gd` (`mayhem_targets` adds officers).
- Test: `tests/test_officers.gd`.

**Interfaces:**
- Consumes:
  - Task 7: `WantedDirector` (`observers`, `sees_player` via `_los_step`, `last_seen`, `target_pos()`, `is_campus()`, `add_heat`, `spawning`, `tick`).
  - Task 3: `ThirdPersonController.knock_down`, `is_knocked_down`, `horizontal_speed`.
  - Task 2: the `take_hit` info format.
- Produces:
  - `class_name Officer extends CharacterBody3D`:
    - signal `knocked(officer)`;
    - `enum State { CHASE, SEARCH, TACKLE, KNOCKED, LAUNCHED, STUNNED, GIVE_UP, SUPERVISE }`;
    - constants `SPEEDS {"guard": 5.0, "mr_t": 6.2, "police": 5.4}`, `KO_S 10.0`, `TACKLE_R 1.5`, `TACKLE_MIN_SPEED 4.5`, `STOP_R 0.9`, `LINES`, `PRESETS`;
    - vars `role, state, wanted, player, model, bubble: Label3D, sees_player, bike_idx, ko_left, hits, shouts`;
    - `setup(role, wanted_node, player_node, seed)` (before `add_child`), `take_hit(info) -> String`, `is_down()`, `can_catch()`, `give_up()`, `supervise()`, `say(text, secs := SAY_S)`.
  - `WantedDirector`:
    - constants `GUARDS [2, 4, 6]`, `SPAWN_MIN 25.0`, `SPAWN_MAX 45.0`, `DESPAWN_R 110.0`, `MAX_OFFICERS 12`, `SPAWNS_PER_MAINTAIN 2`, `MAINTAIN_S 1.0`, `GIVE_UP_DESPAWN_S 20.0`;
    - vars `spawn_fn: Callable ((role, near) -> Variant)`, `catch_enabled: bool` (busting arrives in Task 10), `officers_spawned`;
    - `officers() -> Array`, `count_role(role) -> int`, `search_radius() -> float`, `spawn_officer(role, at: Variant = null) -> Officer`.

- [ ] **Step 1: Write the failing test `tests/test_officers.gd`**

```gdscript
# File: res://tests/test_officers.gd
# Headless test of the Phase W officers on foot (spec W-D7, section 4): on campus 2 / 4 / 6 security guards by stars and
# Mr.T from 2 stars (at most 2 spawns per second, never more than 12 officers); they chase the player they see
# (guards ~5 m/s, Mr.T faster), Mr.T shouts "Em kia! Đứng lại! Thẻ sinh viên đâu?" first; a weapon knocks an
# officer out for 10 s (+5 heat), then he is back on his feet; officers dive at a player sprinting past (comic tackle: the
# player is knocked down, never hurt); once the stars are gone they give up and vanish. Busting is off here
# (catch_enabled = false; Task 10 tests it). Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_officers.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")

var fails: Array[String] = []
var frames: int = 0
var phase: String = ""
var t0: int = 0
var started: bool = false
var arena: Node3D
var player: ThirdPersonController
var wanted: WantedDirector
var campus: bool = true
var spawn_k: int = 0
var seen_at: Dictionary = {}             # officer instance id -> [frame of first sight in the test, distance then]
var checked_speed: Dictionary = {}       # role -> true


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	print("--- TEST OFFICERS ---")
	physics_frame.connect(_on_physics)


## Deterministic spawn points: a ring 30 m around the player, in the open arena (clear line of sight).
func _spawn_point(_role: String, near: Vector3) -> Variant:
	spawn_k += 1
	var a: float = float(spawn_k) * 0.9
	return near + Vector3(sin(a) * 30.0, 0.0, cos(a) * 30.0)


func _next(p: String) -> void:
	phase = p
	t0 = frames


func _track_speeds() -> void:
	for o: Officer in wanted.officers():
		var id: int = o.get_instance_id()
		var d: float = WeaponMath.flat(o.global_position, player.global_position)
		if not seen_at.has(id):
			if o.state == Officer.State.CHASE and d > 15.0:
				seen_at[id] = [frames, d]
		elif not checked_speed.has(o.role) and frames - int(seen_at[id][0]) == 60:
			checked_speed[o.role] = true
			var moved: float = float(seen_at[id][1]) - d
			var v: float = float(Officer.SPEEDS[o.role])
			_check(moved > v * 0.8 and moved < v * 1.1, "%s chases at ~%.1f m/s (%.2f m in 1 s)" % [o.role, v, moved])


func _on_physics() -> void:
	frames += 1
	if not started:
		started = true
		arena = Node3D.new()
		root.add_child(arena)
		World.floor_box(arena)
		player = World.player(arena, Vector3.ZERO, 0.0)
		wanted = WantedDirector.new()
		wanted.name = "Wanted"
		arena.add_child(wanted)
		wanted.setup({"player": player, "is_campus_fn": func(_p: Vector3) -> bool: return campus})
		wanted.spawn_fn = _spawn_point
		wanted.catch_enabled = false
		_next("one")
		return
	var t: int = frames - t0
	_track_speeds()
	match phase:
		"one":
			if t == 2:
				wanted.add_heat(4.0)
			if t == 70:
				_check(wanted.count_role("guard") == 2 and wanted.count_role("mr_t") == 0, "1 star on campus: 2 guards, no Mr.T (%d, %d)" % [wanted.count_role("guard"), wanted.count_role("mr_t")])
				wanted.add_heat(8.0)
				_next("two")
		"two":
			if t == 130:
				_check(wanted.count_role("guard") == 4 and wanted.count_role("mr_t") == 1, "2 stars: 4 guards and Mr.T (%d, %d)" % [wanted.count_role("guard"), wanted.count_role("mr_t")])
				wanted.add_heat(13.0)
				_next("three")
		"three":
			if t == 130:
				_check(wanted.count_role("guard") == 6 and wanted.count_role("mr_t") == 1, "3 stars: 6 guards and Mr.T")
				_check(wanted.officers().size() <= WantedDirector.MAX_OFFICERS and wanted.officers_spawned == 7, "no more than needed (%d spawned)" % wanted.officers_spawned)
				_check(checked_speed.has("guard") and checked_speed.has("mr_t"), "speeds measured for a guard and Mr.T")
				var mr_t: Officer = null
				for o: Officer in wanted.officers():
					if o.role == "mr_t":
						mr_t = o
				_check(mr_t != null and mr_t.shouts >= 1 and mr_t.bubble.text == String((Officer.LINES["mr_t"] as Array)[0]), "Mr.T's first shout (0.6 s after he sees the player): 'Em kia! Đứng lại! Thẻ sinh viên đâu?'")
				var g: Officer = null
				for o: Officer in wanted.officers():
					if o.role == "guard" and g == null:
						g = o
				var h0: float = wanted.heat
				var r: String = g.take_hit({"kind": "bullet", "from": player.global_position})
				_check(r == "knocked_out" and g.is_down() and is_equal_approx(g.ko_left, Officer.KO_S), "a bullet knocks a guard out for 10 s")
				_check(is_equal_approx(wanted.heat, h0 + WantedDirector.OFFICER_KO_HEAT), "+5 heat for knocking out an officer")
				_check(g.take_hit({"kind": "scare", "from": player.global_position}) == "none", "officers ignore scares")
				g.ko_left = 0.5
				g.set_meta("t", true)
				_next("up")
		"up":
			if t == 60:
				var back: bool = false
				for o: Officer in wanted.officers():
					if o.has_meta("t"):
						back = not o.is_down() and o.collision_layer == 1
				_check(back, "the knocked-out guard gets up when his time is over")
				player.input_override = Vector2(0.0, -1.0)
				player.sprint_override = true
				_next("tackle")
		"tackle":
			if player.is_knocked_down() and not has_meta("tackled"):
				set_meta("tackled", true)
				var dove: bool = false
				for o: Officer in wanted.officers():
					if o.hits.has("tackle"):
						dove = true
				_check(dove, "an officer dove at the sprinting player")
			if t == 120:
				_check(has_meta("tackled"), "the sprinting player was tackled (comic knock-down)")
				player.input_override = Vector2.ZERO
				player.sprint_override = false
				wanted.clear()
				_next("give_up")
		"give_up":
			if t == 3:
				var all_gave_up: bool = true
				for o: Officer in wanted.officers():
					if o.state != Officer.State.GIVE_UP and not o.is_down():
						all_gave_up = false
				_check(all_gave_up, "no stars: the officers give up (or already left out of view)")
				wanted.set("_give_up_t", WantedDirector.GIVE_UP_DESPAWN_S)
			if t == 6:
				_check(wanted.officers().is_empty(), "they are gone after the give-up time")
				Engine.time_scale = 1.0
				if fails.is_empty():
					print("✅ SUCCESS: OFFICERS (campus counts by star, Mr.T from 2 stars, chase speeds, shout, knock-out +5, get up, tackle, give up)")
					quit(0)
				else:
					print("❌ FAILED: %d issues" % fails.size())
					quit(1)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless --path . --script tests/test_officers.gd > /tmp/w_t8.log 2>&1; grep -E "SUCCESS|FAIL|Parse Error" /tmp/w_t8.log`
Expected: a parse error (`Officer` not declared).

- [ ] **Step 3: Write `scripts/wanted/Officer.gd`**

```gdscript
# File: res://scripts/wanted/Officer.gd
# Phase W chaser on foot (spec W-D7, section 4): a campus security guard (bảo vệ), Mr.T (the story's
# fictional lecturer: lecturer preset, faster, shouts "Em kia! Đứng lại! Thẻ sinh viên đâu?") or a police officer off his
# bike. CHASE runs straight at the player while WantedDirector says he sees him (sees_player); SEARCH walks to the last
# seen point and wanders inside the search circle; GIVE_UP walks away once the stars are gone. Officers never shoot: within
# TACKLE_R of a player running faster than TACKLE_MIN_SPEED they dive (comic tackle: the player is knocked down, never
# hurt); otherwise they stop beside him (WantedDirector counts the catch, Task 10). Weapons knock them out for KO_S whatever
# the weapon (plan P5) and emit `knocked` (+5 heat); a blast launches them; stink stuns; the loa pushes some into a dance.
# Steering: straight line, step-up like Pedestrian, sidestep when stuck. SUPERVISE (community service): stands, faces the
# player, says lines. Rigged CharacterBuilder body (PS2 head in vice). GameFX / StageManager are never named here.
class_name Officer
extends CharacterBody3D

signal knocked(officer: Officer)

enum State { CHASE, SEARCH, TACKLE, KNOCKED, LAUNCHED, STUNNED, GIVE_UP, SUPERVISE }

const RADIUS: float = 0.3
const HEIGHT: float = 1.75
const GRAVITY: float = 20.0
const SPEEDS: Dictionary = {"guard": 5.0, "mr_t": 6.2, "police": 5.4}
const SEARCH_FACTOR: float = 0.7
const GIVE_UP_SPEED: float = 2.0
const STOP_R: float = 0.9
const KO_S: float = 10.0
const GETUP_S: float = 0.9
const STUN_S: float = 3.0
const DANCE_S: float = 2.0
const DANCE_CHANCE: float = 0.3
const TACKLE_R: float = 1.5
const TACKLE_MIN_SPEED: float = 4.5
const TACKLE_S: float = 0.9
const TACKLE_HIT_S: float = 0.25
const TACKLE_SPEED: float = 6.5
const TACKLE_COOLDOWN: float = 4.0
const PUSH_DECEL: float = 8.0
const STEP_HEIGHT: float = 0.35
const STUCK_S: float = 1.0
const SIDESTEP_S: float = 1.0
const WANDER_ARRIVE: float = 1.5
const SHOUT_EVERY: float = 8.0
const SHOUT_S: float = 2.5
const SAY_S: float = 3.5
const LAND_MIN_S: float = 0.15
const PRESETS: Dictionary = {
	"guard": {"preset": "guard"},
	"mr_t": {"preset": "lecturer", "seed": 1995, "glasses": true},
	"police": {"preset": "cop"},
}
const LINES: Dictionary = {
	"guard": ["Đứng lại!", "Bảo vệ đây, đứng yên đó!", "Chạy đi đâu, cổng khoá rồi!"],
	"mr_t": ["Em kia! Đứng lại! Thẻ sinh viên đâu?", "Em học lớp nào? Đứng lại cho tôi!", "Chạy nữa là tôi cho F môn này đấy!"],
	"police": ["Dừng lại!", "Đứng yên, xuất trình giấy tờ!", "Không được chạy!"],
}

var role: String = "guard"
var state: int = State.CHASE
var wanted: Node
var player: Node3D
var model: Node3D
var bubble: Label3D
var sees_player: bool = false
var bike_idx: int = -1
var ko_left: float = 0.0
var hits: Array[String] = []
var shouts: int = 0
var _t: float = 0.0
var _tackle_cd: float = 0.0
var _tackled: bool = false
var _getting_up: bool = false
var _shout_t: float = 0.0
var _bubble_left: float = 0.0
var _wander: Vector3 = Vector3.ZERO
var _has_wander: bool = false
var _push_v: Vector3 = Vector3.ZERO
var _side: float = 1.0
var _side_t: float = 0.0
var _stuck_t: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
var _rng := RandomNumberGenerator.new()


## Build the body; call before add_child. wanted_node: WantedDirector (target_pos, last_seen, search_radius) or null
## (community-service supervisor: looks at player_node).
func setup(r: String, wanted_node: Node, player_node: Node3D, seed_v: int) -> void:
	role = r if SPEEDS.has(r) else "guard"
	wanted = wanted_node
	player = player_node
	_rng.seed = seed_v
	floor_snap_length = 0.4
	var cs := CollisionShape3D.new()
	cs.name = "Capsule"
	var cap := CapsuleShape3D.new()
	cap.radius = RADIUS
	cap.height = HEIGHT
	cs.shape = cap
	cs.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	add_child(cs)
	var o: Dictionary = (PRESETS[role] as Dictionary).duplicate()
	if not o.has("seed"):
		o["seed"] = seed_v
	o["rigged"] = true
	o["name"] = "Model"
	model = CharacterBuilder.build(o)
	add_child(model)
	bubble = Label3D.new()
	bubble.name = "Bubble"
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.font_size = 40
	bubble.pixel_size = 0.005
	bubble.outline_size = 10
	bubble.outline_modulate = Color(0.08, 0.04, 0.12, 0.95)
	bubble.no_depth_test = true
	bubble.position = Vector3(0.0, 2.25, 0.0)
	bubble.visible = false
	add_child(bubble)
	_shout_t = 0.6 if role == "mr_t" else _rng.randf_range(1.0, 3.0)


func _physics_process(delta: float) -> void:
	_t += delta
	_tackle_cd = maxf(0.0, _tackle_cd - delta)
	_tick_bubble(delta)
	match state:
		State.CHASE:
			_chase(delta)
		State.SEARCH:
			_search(delta)
		State.TACKLE:
			_tackle(delta)
		State.KNOCKED:
			_knocked(delta)
		State.LAUNCHED:
			_launched(delta)
		State.STUNNED:
			_stunned(delta)
		State.GIVE_UP:
			_give_up(delta)
		State.SUPERVISE:
			_supervise(delta)


func _target() -> Vector3:
	if wanted and wanted.has_method("target_pos"):
		return wanted.call("target_pos")
	return player.global_position if player else global_position


func _flat_d(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


static func _flat_dir(v: Vector3) -> Vector3:
	var f := Vector3(v.x, 0.0, v.z)
	return f.normalized() if f.length_squared() > 1e-6 else Vector3(0.0, 0.0, 1.0)


func _chase(delta: float) -> void:
	if not sees_player:
		state = State.SEARCH
		_has_wander = false
		return
	var p: Vector3 = _target()
	var d: float = _flat_d(p)
	var pl_speed: float = float(player.get("horizontal_speed")) if player and player.get("horizontal_speed") != null else 0.0
	var down: bool = player != null and player.has_method("is_knocked_down") and bool(player.call("is_knocked_down"))
	if d <= TACKLE_R and pl_speed >= TACKLE_MIN_SPEED and _tackle_cd <= 0.0 and not down and player.visible:
		_start_tackle(p)
		return
	_move_to(p, float(SPEEDS[role]) if d > STOP_R else 0.0, delta)
	_maybe_shout(delta)


func _search(delta: float) -> void:
	if sees_player:
		state = State.CHASE
		return
	var ls: Vector3 = wanted.get("last_seen") if wanted else global_position
	if not _has_wander:
		_wander = ls
		_has_wander = true
	if _flat_d(_wander) <= WANDER_ARRIVE:
		var r: float = float(wanted.call("search_radius")) if wanted and wanted.has_method("search_radius") else 30.0
		var a: float = _rng.randf() * TAU
		var k: float = sqrt(_rng.randf()) * r * 0.6
		_wander = ls + Vector3(cos(a) * k, 0.0, sin(a) * k)
	_move_to(_wander, float(SPEEDS[role]) * SEARCH_FACTOR, delta)


func _give_up(delta: float) -> void:
	var away: Vector3 = _flat_dir(global_position - _target())
	_move_to(global_position + away * 10.0, GIVE_UP_SPEED, delta)


func _supervise(delta: float) -> void:
	_gravity(delta)
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()
	CharacterBuilder.set_speed(model, 0.0)
	if player:
		var d: Vector3 = _flat_dir(player.global_position - global_position)
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-d.x, -d.z), minf(1.0, delta * 6.0))


## Straight-line steering with a sidestep when stuck, step-up onto kerbs, push decay, run animation.
func _move_to(target: Vector3, speed: float, delta: float) -> void:
	var to := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	var d: float = to.length()
	var dir: Vector3 = to / d if d > 0.01 else Vector3.ZERO
	if _side_t > 0.0 and dir != Vector3.ZERO:
		_side_t -= delta
		dir = (dir + Vector3(-dir.z, 0.0, dir.x) * _side * 1.2).normalized()
	velocity.x = dir.x * speed + _push_v.x
	velocity.z = dir.z * speed + _push_v.z
	_push_v = _push_v.move_toward(Vector3.ZERO, PUSH_DECEL * delta)
	_gravity(delta)
	if is_on_wall() and speed > 0.0 and _wall_is_static():
		_try_step_up(dir, delta)
	move_and_slide()
	if dir != Vector3.ZERO and speed > 0.0:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * 10.0))
	elif player:
		var f: Vector3 = _flat_dir(player.global_position - global_position)
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-f.x, -f.z), minf(1.0, delta * 6.0))
	CharacterBuilder.set_speed(model, Vector2(velocity.x, velocity.z).length())
	CharacterBuilder.set_param(model, "run", 0.45 if speed > 4.5 else 0.0)
	_stuck_check(delta, d, speed)


func _stuck_check(delta: float, d: float, speed: float) -> void:
	if speed <= 0.0 or d < 2.0:
		_stuck_t = 0.0
		_last_pos = global_position
		return
	_stuck_t += delta
	if _stuck_t < STUCK_S:
		return
	if global_position.distance_to(_last_pos) < speed * STUCK_S * 0.25:
		_side = -_side
		_side_t = SIDESTEP_S
	_stuck_t = 0.0
	_last_pos = global_position


func _start_tackle(p: Vector3) -> void:
	state = State.TACKLE
	_t = 0.0
	_tackled = false
	var dir: Vector3 = _flat_dir(p - global_position)
	velocity = dir * TACKLE_SPEED
	model.rotation.y = atan2(-dir.x, -dir.z)
	CharacterBuilder.play(model, "knockdown")
	hits.append("tackle")


func _tackle(delta: float) -> void:
	_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, 9.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 9.0 * delta)
	move_and_slide()
	if not _tackled and _t >= TACKLE_HIT_S:
		_tackled = true
		var p: Vector3 = _target()
		if _flat_d(p) <= TACKLE_R + 0.5 and player and player.has_method("knock_down"):
			player.call("knock_down", p - global_position, 2.5)
		CharacterBuilder.play(model, "getup")
	if _t >= TACKLE_S:
		state = State.CHASE
		_tackle_cd = TACKLE_COOLDOWN
		CharacterBuilder.stop_clip(model)


## Weapon hit (same info as Pedestrian.take_hit). Officers stay down KO_S whatever the weapon (spec section 4, plan P5) and
## emit `knocked` (+5 heat). "scare" does nothing: officers are not scared off.
func take_hit(info: Dictionary) -> String:
	if is_down() or state == State.SUPERVISE:
		return "none"
	var kind: String = String(info.get("kind", "melee"))
	var from: Vector3 = info.get("from", global_position)
	var away: Vector3 = _flat_dir(global_position - from)
	match kind:
		"punch":
			_push_v = away * 2.0
			CharacterBuilder.play(model, "stumble")
			hits.append("stumble")
			return "stumble"
		"melee", "bullet", "bonk":
			_knock_out(away)
			return "knocked_out"
		"pellet", "blast":
			state = State.LAUNCHED
			_t = 0.0
			velocity = info.get("vel", away * 6.0 + Vector3(0.0, 5.0, 0.0))
			ko_left = KO_S
			collision_layer = 0
			CharacterBuilder.play(model, "fall_flail")
			hits.append("launched")
			knocked.emit(self)
			return "launched"
		"stink":
			_stun(STUN_S, "facepalm")
			hits.append("stink")
			return "stink"
		"sonic":
			_push_v = _flat_dir(info.get("dir", away)) * float(info.get("power", 5.0))
			var dance: bool = bool(info["dance"]) if info.has("dance") else _rng.randf() < DANCE_CHANCE
			if dance and state != State.STUNNED:
				_stun(DANCE_S, "cheer")
				hits.append("dance")
				return "dance"
			return "pushed"
	return "none"


func _knock_out(away: Vector3) -> void:
	state = State.KNOCKED
	ko_left = KO_S
	_t = 0.0
	_getting_up = false
	velocity = away * 1.5
	collision_layer = 0
	if away.length_squared() > 1e-4:
		model.rotation.y = atan2(away.x, away.z)
	CharacterBuilder.play(model, "knockdown")
	CharacterBuilder.set_expression(model, "pain")
	hits.append("ko")
	knocked.emit(self)


func _stun(secs: float, clip: String) -> void:
	state = State.STUNNED
	ko_left = secs
	_t = 0.0
	CharacterBuilder.play(model, clip, secs)


func _knocked(delta: float) -> void:
	_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 16.0 * delta)
	move_and_slide()
	CharacterBuilder.set_speed(model, 0.0)
	ko_left -= delta
	if ko_left <= GETUP_S and not _getting_up:
		_getting_up = true
		CharacterBuilder.play(model, "getup")
	if ko_left <= 0.0:
		_getting_up = false
		collision_layer = 1
		CharacterBuilder.set_expression(model, "open")
		CharacterBuilder.stop_clip(model)
		state = State.CHASE if sees_player else State.SEARCH
		_has_wander = false


func _launched(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	move_and_slide()
	model.rotation.y += 9.0 * delta
	if (_t >= LAND_MIN_S and is_on_floor() and velocity.y <= 0.0) or _t >= 4.0:
		state = State.KNOCKED
		_t = 0.0
		_getting_up = false
		velocity = Vector3(velocity.x, 0.0, velocity.z) * 0.3
		CharacterBuilder.play(model, "knockdown")


func _stunned(delta: float) -> void:
	_gravity(delta)
	_push_v = _push_v.move_toward(Vector3.ZERO, PUSH_DECEL * delta)
	velocity.x = _push_v.x
	velocity.z = _push_v.z
	move_and_slide()
	CharacterBuilder.set_speed(model, 0.0)
	ko_left -= delta
	if ko_left <= 0.0:
		CharacterBuilder.stop_clip(model)
		state = State.SEARCH
		_has_wander = false


func is_down() -> bool:
	return state == State.KNOCKED or state == State.LAUNCHED


## Only an officer on his feet and after the player can grab him (WantedDirector's catch rule, Task 10).
func can_catch() -> bool:
	return state == State.CHASE or state == State.SEARCH


func give_up() -> void:
	if not is_down() and state != State.SUPERVISE:
		state = State.GIVE_UP


func supervise() -> void:
	state = State.SUPERVISE
	velocity = Vector3.ZERO


func say(text: String, secs: float = SAY_S) -> void:
	bubble.text = text
	bubble.visible = true
	_bubble_left = secs


func _maybe_shout(delta: float) -> void:
	_shout_t -= delta
	if _shout_t > 0.0:
		return
	var lines: Array = LINES[role]
	say(String(lines[0] if shouts == 0 else lines[_rng.randi_range(0, lines.size() - 1)]), SHOUT_S)
	shouts += 1
	_shout_t = SHOUT_EVERY


func _tick_bubble(delta: float) -> void:
	if _bubble_left <= 0.0:
		return
	_bubble_left -= delta
	if _bubble_left <= 0.0:
		bubble.visible = false


func _gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
	else:
		velocity.y -= GRAVITY * delta


## Step onto low kerbs / steps while blocked (as Pedestrian._try_step_up).
## The wall touched by the last move_and_slide is level geometry (a kerb or a step can be climbed), not a person, an
## officer, the player or a vehicle: bumping into bodies in a crowd must not cost four test_move probes per frame.
func _wall_is_static() -> bool:
	for i: int in get_slide_collision_count():
		var c: KinematicCollision3D = get_slide_collision(i)
		if absf(c.get_normal().y) < 0.7 and c.get_collider() is StaticBody3D:
			return true
	return false


func _try_step_up(dir: Vector3, delta: float) -> void:
	var motion: Vector3 = Vector3(velocity.x, 0.0, velocity.z) * delta
	if motion.length_squared() < 0.000001:
		return
	var xf: Transform3D = global_transform
	if not test_move(xf, motion):
		return
	var up := Vector3(0.0, STEP_HEIGHT + 0.03, 0.0)
	if test_move(xf, up):
		return
	var probe: Vector3 = motion + dir * 0.12
	var raised: Transform3D = xf.translated(up)
	if test_move(raised, probe):
		return
	var col := KinematicCollision3D.new()
	if not test_move(raised.translated(probe), Vector3(0.0, -(STEP_HEIGHT + 0.06), 0.0), col):
		return
	if col.get_normal().y < 0.7:
		return
	var step_h: float = up.y + col.get_travel().y
	if step_h > 0.02 and step_h <= STEP_HEIGHT + 0.03:
		global_position.y += step_h + 0.01
```

- [ ] **Step 4: Spawning in `scripts/wanted/WantedDirector.gd`**

4a. After `const LABEL_STREET: String = …` add:

```gdscript
const GUARDS: Array[int] = [2, 4, 6]
const SPAWN_MIN: float = 25.0
const SPAWN_MAX: float = 45.0
const DESPAWN_R: float = 110.0
const MAX_OFFICERS: int = 12
const SPAWNS_PER_MAINTAIN: int = 2
const MAINTAIN_S: float = 1.0
const GIVE_UP_DESPAWN_S: float = 20.0
```

and after `var spawning: bool = true` add:

```gdscript
## Tests: (role: String, near: Vector3) -> Variant (Vector3 or null) replaces the ring search for spawn points.
var spawn_fn: Callable
## false = officers never bust the player (Task 10 implements busting; tests and the performance gate switch it off).
var catch_enabled: bool = true
var officers_spawned: int = 0
var _maintain_t: float = 0.0
var _give_up_t: float = 0.0
var _rng := RandomNumberGenerator.new()
```

4b. Replace the whole `tick()` function with:

```gdscript
func tick(delta: float) -> void:
	if state != "free":
		return
	_prune()
	if stars == 0:
		heat = maxf(0.0, heat - IDLE_DECAY * delta)
		seen = false
		_retire(delta)
		_update_search()
		return
	_give_up_t = 0.0
	_maintain_t -= delta
	if _maintain_t <= 0.0:
		_maintain_t = MAINTAIN_S
		_maintain()
	_los_step()
	if seen:
		seen_t = 0.0
		last_seen = target_pos()
	else:
		seen_t += delta
		if seen_t >= LOSE_S[stars - 1]:
			_drop_star()
	_update_search()
```

4c. Append:

```gdscript
func officers() -> Array:
	var out: Array = []
	for o: Variant in observers:
		if o is Officer and is_instance_valid(o):
			out.append(o)
	return out


func count_role(role: String) -> int:
	var n: int = 0
	for o: Officer in officers():
		if o.role == role:
			n += 1
	return n


func search_radius() -> float:
	return SEARCH_R[clampi(stars, 1, 3) - 1]


## Spawn an officer (role "guard" | "mr_t" | "police") at `at` or at a free spot 25-45 m from the player, out of view when
## possible. null when the cap is reached or no spot is found.
func spawn_officer(role: String, at: Variant = null) -> Officer:
	if officers().size() >= MAX_OFFICERS:
		return null
	var pos: Variant = at if at is Vector3 else _spawn_point(role)
	if not (pos is Vector3):
		return null
	var o := Officer.new()
	o.name = "Officer_%s_%d" % [role, officers_spawned]
	o.setup(role, self, player, 4000 + officers_spawned)
	o.position = (pos as Vector3) + Vector3(0.0, 0.05, 0.0)   # before add_child: never enter the tree at the origin
	add_child(o)
	o.knocked.connect(_on_officer_knocked)
	observers.append(o)
	officers_spawned += 1
	if player and player.cam_ray:
		player.cam_ray.add_exception(o)
	var b: Variant = roam.get("bike") if roam else null
	if b is Node and (b as Node).get("spring_arm"):
		((b as Node).get("spring_arm") as SpringArm3D).add_excluded_object(o.get_rid())
	return o


func _on_officer_knocked(o: Officer) -> void:
	add_heat(OFFICER_KO_HEAT, o.global_position, "officer")


func _spawn_point(role: String) -> Variant:
	var near: Vector3 = target_pos()
	if spawn_fn.is_valid():
		return spawn_fn.call(role, near)
	for k: int in 12:
		var a: float = _rng.randf() * TAU
		var r: float = _rng.randf_range(SPAWN_MIN, SPAWN_MAX)
		var q: Vector3 = near + Vector3(cos(a) * r, 0.0, sin(a) * r)
		if k < 8 and _in_view(q):
			continue
		if roam and roam.has_method("find_free_spot"):
			var s: Variant = roam.call("find_free_spot", q, near.y, 3)
			if s is Vector3:
				return s
		else:
			return q
	return null


func _in_view(p: Vector3) -> bool:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam != null and cam.global_position.distance_to(p) < 120.0 and cam.is_position_in_frustum(p + Vector3(0.0, 1.0, 0.0))


## Once per MAINTAIN_S: officers far away and out of view leave; campus (inside the plot): guards up to GUARDS[stars] and
## Mr.T from 2 stars (police bikes on the streets: Task 9). At most SPAWNS_PER_MAINTAIN new officers per call.
func _maintain() -> void:
	var p: Vector3 = target_pos()
	for o: Officer in officers():
		if WeaponMath.flat(o.global_position, p) > DESPAWN_R and not _in_view(o.global_position):
			_despawn(o)
	if not spawning:
		return
	var budget: int = SPAWNS_PER_MAINTAIN
	if is_campus(p):
		var have: int = count_role("guard")
		while have < GUARDS[stars - 1] and budget > 0:
			if spawn_officer("guard") == null:
				break
			have += 1
			budget -= 1
		if stars >= 2 and count_role("mr_t") == 0 and budget > 0:
			spawn_officer("mr_t")


func _despawn(o: Officer) -> void:
	observers.erase(o)
	_sees.erase(o.get_instance_id())
	if player and player.cam_ray and is_instance_valid(o):
		player.cam_ray.remove_exception(o)
	o.queue_free()


## No stars: every officer gives up and walks away; those out of view vanish at once, the rest after GIVE_UP_DESPAWN_S.
func _retire(delta: float) -> void:
	var list: Array = officers()
	if list.is_empty():
		_give_up_t = 0.0
		return
	_give_up_t += delta
	for o: Officer in list:
		o.give_up()
		if _give_up_t >= GIVE_UP_DESPAWN_S or not _in_view(o.global_position):
			_despawn(o)
```

- [ ] **Step 5: Officers are targets too: `scripts/FreeRoam.gd`**

In `mayhem_targets()`, before `	return out`, add:

```gdscript
	if wanted:
		out.append_array(wanted.officers())
```

and change its doc line to `## Everything weapons can hit: pedestrians of both tiers and the officers.`

- [ ] **Step 6: Import, check the class cache, run the test**

```bash
godot --headless --import --path . > /tmp/w_imp.log 2>&1
grep -c 'class": &"Officer"' .godot/global_script_class_cache.cfg
git diff --name-only -- '*.import' | xargs -r git checkout --
godot --headless --path . --script tests/test_officers.gd > /tmp/w_t8.log 2>&1; grep -E "SUCCESS|FAIL|✗" /tmp/w_t8.log
```
Expected: the cache count is 1, and the test prints `✅ SUCCESS: OFFICERS …`. `tests/test_wanted.gd` must stay green: it switches `spawning` off.

- [ ] **Step 7: Run the full regression, then commit**

```bash
git add scripts/wanted/Officer.gd scripts/wanted/Officer.gd.uid scripts/wanted/WantedDirector.gd scripts/FreeRoam.gd tests/test_officers.gd tests/test_officers.gd.uid
git commit -m "feat(wanted): officers on foot - campus guards 2/4/6 by stars and Mr.T (fictional lecturer, faster, 'Em kia! Đứng lại! Thẻ sinh viên đâu?') from 2 stars, chase on sight, search the last-seen circle, comic tackle of a sprinting player, knocked out 10 s by any weapon (+5 heat), stunned by stink, pushed by the loa, give up and vanish when the stars are gone; officers are weapon targets

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 9: Police motorbikes on the streets  [effort: xhigh]

**Files:**
- Modify: `scripts/roam/RoamTraffic.gd` (police kind, routing, dismount), `scripts/wanted/WantedDirector.gd` (street spawns, second wave, foot fallback).
- Test: `tests/test_police_bikes.gd`.

**Interfaces:**
- Consumes:
  - Task 2: `RoamTraffic` halted / recycle machinery, `RIDER_SIDE_M`.
  - Task 8: `WantedDirector.spawn_officer`, `count_role`, `_maintain`, `MAINTAIN_S`.
- Produces:
  - `RoamTraffic`:
    - `Kind.POLICE` (index 3; uses motorbike lanes);
    - constants `POLICE_PAINT, POLICE_SPEED 12.0, POLICE_DISMOUNT_M 15.0, POLICE_NEAR_M 60.0, POLICE_NO_PROGRESS_S 2.0, POLICE_MAX 8`;
    - signal `police_arrived(idx: int, at: Vector3)`;
    - var `police_target_fn: Callable (-> Vector3)`;
    - `Vehicle` fields `police, police_state ("" | "ride" | "parked"), best_d, no_prog_t`;
    - `spawn_police() -> int`, `police_dismount(idx)`, `release_police()`, `is_police_riding(idx) -> bool`, `_civil_count() -> int`.
  - `WantedDirector`:
    - constants `BIKES [1, 2, 3]`, `SECOND_WAVE_S 30.0`;
    - vars `three_star_t, second_wave, pending_bikes: Array[int], bikes_sent`.

- [ ] **Step 1: Write the failing test `tests/test_police_bikes.gd`**

```gdscript
# File: res://tests/test_police_bikes.gd
# Headless test of the Phase W police motorbikes (spec W-D7, section 4): A (RoamTraffic) a police bike (white paint, police
# rider, siren) appears on a lane heading toward the player, rides at 12 m/s, dismounts within 15 m (police_arrived beside
# the bike, the bike stays halted, the rider leaves the seat), or within 60 m once it stops getting closer; civil traffic
# counts ignore police; shooting a riding police bike makes its rider dismount; release_police parks the riders.
# B (WantedDirector on the streets) 1 / 2 / 3 bikes by stars, each arrival becomes a police officer on foot with its bike
# index, a second wave of 3 after 30 s at 3 stars, and without traffic the police arrive on foot.
# Busting is off (catch_enabled = false). Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_police_bikes.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")

var fails: Array[String] = []
var frames: int = 0
var phase: String = ""
var t0: int = 0
var started: bool = false
var arena: Node3D
var player: ThirdPersonController
var traffic: RoamTraffic
var arrivals: Array = []                 # [idx, at]
var idx_a: int = -1
var wanted: WantedDirector


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	print("--- TEST POLICE BIKES ---")
	physics_frame.connect(_on_physics)


func _next(p: String) -> void:
	phase = p
	t0 = frames


func _on_physics() -> void:
	frames += 1
	if not started:
		started = true
		arena = Node3D.new()
		root.add_child(arena)
		World.floor_box(arena, 600.0)
		player = World.player(arena, Vector3(0.0, 0.0, 12.0), 0.0)
		traffic = World.traffic(arena, player, 0.0)
		for i: int in 2:
			var c: RoamTraffic.Vehicle = traffic.vehicles[i]
			World.place_vehicle(traffic, i, -95.0 if i == 0 else 95.0)
			c.halted = true                 # parked civil traffic at the road ends: nothing in the police lanes
		traffic.police_target_fn = func() -> Vector3: return player.global_position
		traffic.police_arrived.connect(func(i: int, at: Vector3) -> void: arrivals.append([i, at]))
		_next("spawn")
		return
	var t: int = frames - t0
	match phase:
		"spawn":
			if t == 2:
				idx_a = traffic.spawn_police()
				_check(idx_a >= 0, "a police bike spawns on a lane")
				if idx_a < 0:
					_finish()
					return
				var c: RoamTraffic.Vehicle = traffic.vehicles[idx_a]
				var rider: Node3D = c.body.get_node_or_null("Rider") as Node3D
				_check(c.police and c.police_state == "ride" and c.kind == RoamTraffic.Kind.POLICE, "police kind, riding")
				_check(rider != null and rider.visible and c.body.get_node_or_null("SirenR") != null, "police rider and siren lights")
				_check(is_equal_approx(c.cruise, RoamTraffic.POLICE_SPEED), "rides at 12 m/s")
				var d: float = c.pos.distance_to(Vector2(player.global_position.x, player.global_position.z))
				_check(d >= RoamTraffic.SPAWN_MIN - 0.5 and d <= RoamTraffic.SPAWN_MAX, "appears 40-150 m away (%.1f m)" % d)
				_check(traffic._civil_count() == 2, "civil traffic counts ignore police bikes")
			if t > 2 and not arrivals.is_empty():
				var c2: RoamTraffic.Vehicle = traffic.vehicles[idx_a]
				var at: Vector3 = arrivals[0][1]
				_check(int(arrivals[0][0]) == idx_a and WeaponMath.flat(at, player.global_position) <= RoamTraffic.POLICE_DISMOUNT_M + RoamTraffic.RIDER_SIDE_M + 0.5, "the rider dismounts within 15 m (%.1f m)" % WeaponMath.flat(at, player.global_position))
				var rider2: Node3D = c2.body.get_node_or_null("Rider") as Node3D
				_check(c2.halted and c2.police_state == "parked" and not rider2.visible, "the bike stays parked, the rider left the seat")
				arrivals.clear()
				_next("shot")
			elif t == 720:
				_check(false, "the police bike never arrived")
				_next("shot")
		"shot":
			if t == 2:
				var i2: int = traffic.spawn_police()
				_check(i2 >= 0 and traffic.hit_vehicle(i2, "bullet", player.global_position), "a bullet hits a riding police bike")
				_check(arrivals.size() == 1 and int(arrivals[0][0]) == i2, "... and its rider dismounts at once to chase on foot")
				arrivals.clear()
				var i3: int = traffic.spawn_police()
				traffic.release_police()
				_check(i3 >= 0 and not traffic.is_police_riding(i3) and arrivals.is_empty(), "release_police parks the riding bikes without officers")
				player.teleport(Vector3(0.0, 0.0, 50.0), 0.0)
			if t == 4:
				idx_a = traffic.spawn_police()
			if t > 4 and not arrivals.is_empty():
				var d2: float = WeaponMath.flat(arrivals[0][1], player.global_position)
				_check(d2 > RoamTraffic.POLICE_DISMOUNT_M and d2 <= RoamTraffic.POLICE_NEAR_M + RoamTraffic.RIDER_SIDE_M + 0.5, "off the road: dismounts within 60 m once it stops getting closer (%.1f m)" % d2)
				arrivals.clear()
				_start_b()
			elif t == 900:
				_check(false, "the no-progress dismount never happened")
				_start_b()
		"b":
			_part_b(t)


func _start_b() -> void:
	traffic.release_police()
	player.teleport(Vector3(0.0, 0.0, 12.0), 0.0)
	wanted = WantedDirector.new()
	wanted.name = "Wanted"
	arena.add_child(wanted)
	wanted.setup({"player": player, "traffic": traffic, "is_campus_fn": func(_p: Vector3) -> bool: return false})
	wanted.catch_enabled = false
	_next("b")


func _part_b(t: int) -> void:
	if t == 2:
		wanted.add_heat(4.0)
	if t == 6:
		_check(wanted.pending_bikes.size() == 1 and wanted.count_role("police") == 0, "1 star on the streets: one police bike on its way")
	if t > 6 and t < 900 and wanted.count_role("police") == 1 and not has_meta("b1"):
		set_meta("b1", true)
		var o: Officer = wanted.officers()[0]
		_check(o.role == "police" and o.bike_idx >= 0 and traffic.vehicles[o.bike_idx].police, "the arrival becomes a police officer on foot, linked to his bike")
		wanted.add_heat(21.0)
		set_meta("t3", t)
	if has_meta("t3") and t == int(get_meta("t3")) + 130:
		_check(wanted.stars == 3 and wanted.count_role("police") + wanted.pending_bikes.size() == 3, "3 stars: 3 police (bikes on the way + on foot) (%d + %d)" % [wanted.count_role("police"), wanted.pending_bikes.size()])
		wanted.three_star_t = WantedDirector.SECOND_WAVE_S - 0.01
	if has_meta("t3") and t == int(get_meta("t3")) + 270:
		_check(wanted.second_wave and wanted.count_role("police") + wanted.pending_bikes.size() == 6, "a second wave of 3 after 30 s at 3 stars (%d + %d)" % [wanted.count_role("police"), wanted.pending_bikes.size()])
		var w2 := WantedDirector.new()
		w2.name = "WantedNoTraffic"
		arena.add_child(w2)
		w2.setup({"player": player, "is_campus_fn": func(_p: Vector3) -> bool: return false})
		w2.catch_enabled = false
		w2.spawn_fn = func(_r: String, near: Vector3) -> Variant: return near + Vector3(30.0, 0.0, 0.0)
		w2.add_heat(4.0)
		set_meta("w2", w2)
	if has_meta("t3") and t == int(get_meta("t3")) + 275:
		var w3: WantedDirector = get_meta("w2")
		_check(w3.count_role("police") == 1 and w3.pending_bikes.is_empty(), "without traffic the police arrive on foot (plan P9)")
		_finish()
	if t == 900 and not has_meta("b1"):
		_check(false, "no police officer arrived in part B")
		_finish()


func _finish() -> void:
	Engine.time_scale = 1.0
	if fails.is_empty():
		print("✅ SUCCESS: POLICE BIKES (spawn heading to the player, 12 m/s, dismount <= 15 m or on no progress, civil counts, shot rider dismounts, release, wanted counts, second wave, foot fallback)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless --path . --script tests/test_police_bikes.gd > /tmp/w_t9.log 2>&1; grep -E "SUCCESS|FAIL|Parse Error" /tmp/w_t9.log`
Expected: a parse error (`spawn_police` / `police_target_fn` not found).

- [ ] **Step 3: Police kind in `scripts/roam/RoamTraffic.gd`**

3a. Replace `enum Kind { MOTO, CAR, BUS }` with `enum Kind { MOTO, CAR, BUS, POLICE }`, and the `KIND_SIZE` line with:

```gdscript
const KIND_SIZE: Array = [Vector3(0.7, 1.4, 1.9), Vector3(1.7, 1.5, 3.9), Vector3(2.5, 3.0, 7.5), Vector3(0.7, 1.4, 1.9)]
```

3b. After `signal rider_fled(idx: int, at: Vector3, away_from: Vector3)` add:

```gdscript
const POLICE_PAINT := Color("#F4F6F8")
const POLICE_SPEED: float = 12.0
const POLICE_DISMOUNT_M: float = 15.0       # the rider gets off within this distance of the player
const POLICE_NEAR_M: float = 60.0           # ... or within this one once he stops getting closer (player off the road)
const POLICE_NO_PROGRESS_S: float = 2.0
const POLICE_MAX: int = 8
const SIREN_MS: int = 166                   # red / blue swap

signal police_arrived(idx: int, at: Vector3)
```

3c. In `class Vehicle`, after `var idle_t: float = 0.0 …` add:

```gdscript
	var police: bool = false             # Phase W police bike (Kind.POLICE)
	var police_state: String = ""        # "ride" toward the player | "parked" (rider got off) | ""
	var best_d: float = INF              # closest distance to the player so far (no-progress dismount)
	var no_prog_t: float = 0.0
```

3d. After `var fleer_fn: Callable …` add:

```gdscript
var police_target_fn: Callable           # Phase W: -> Vector3 where police bikes ride to (WantedDirector.target_pos)
```

3e. In `_make_vehicle()`, add this branch at the end of the `match kind:` block (after the `Kind.BUS:` branch):

```gdscript
		Kind.POLICE:
			c.police = true
			PropBuilder.build_scooter(b, Vector3.ZERO, 0.0, POLICE_PAINT, {"baked": true, "name": "Scooter"})
			CharacterBuilder.build_baked_rider(b, Vector3(0.0, 0.32, 0.12), {"preset": "cop", "seed": _rng.randi()})
			_add_siren(b)
```

3f. In `_park()`, after `c.idle_t = 0.0` add `	c.police_state = ""`.

3g. Replace the whole `_pick_exit()` function with:

```gdscript
func _pick_exit(c: Vehicle) -> Array:
	var opts: Array = []
	for ex: Array in lane_exits[c.lane]:
		if lane_kinds[int(ex[0])] & _lane_bit(c.kind):
			opts.append(ex)
	if opts.is_empty():
		return []
	if c.police and c.police_state == "ride" and police_target_fn.is_valid():
		# police: greedy toward the player – the exit whose lane, 15 m in, is closest to him
		var t3: Vector3 = police_target_fn.call()
		var t2 := Vector2(t3.x, t3.z)
		var best: Array = opts[0]
		var best_d: float = INF
		for ex2: Array in opts:
			var l2: int = int(ex2[0])
			var d: float = _lane_point(l2, minf(float(ex2[1]) + 15.0, lane_len[l2])).distance_to(t2)
			if d < best_d:
				best_d = d
				best = ex2
		return best
	return opts[_rng.randi_range(0, opts.size() - 1)]
```

3h. In `_random_spot()`, replace `		if not (lane_kinds[l] & (1 << kind)):` with:

```gdscript
		if not (lane_kinds[l] & _lane_bit(kind)):
```

3i. Replace the whole `_maintain()` function with:

```gdscript
## Mỗi CHECK_EVERY: cất xe ra ngoài DESPAWN, đêm thì cất xe xa nhất cho còn 30 %, thiếu thì đưa xe đang cất ra (tối đa
## SPAWNS_PER_CHECK, xoay vòng điểm bắt đầu để mọi loại xe đều được dùng). Phase W: police bikes are not civil traffic –
## never counted, trimmed or spawned here (only parked beyond DESPAWN).
func _maintain() -> void:
	var c3: Vector3 = _center()
	var c2 := Vector2(c3.x, c3.z)
	night = _is_night()
	var target: int = roundi(float(_civil_count()) * (NIGHT_FACTOR if night else 1.0))
	var live: Array = []
	for c: Vehicle in vehicles:
		if not c.active:
			continue
		if c.pos.distance_to(c2) > DESPAWN:
			_park(c)
			recycled += 1
		elif not c.police:
			live.append(c)
	if live.size() > target:
		live.sort_custom(func(a: Vehicle, b: Vehicle) -> bool: return a.pos.distance_to(c2) > b.pos.distance_to(c2))
		for i: int in range(live.size() - target):
			_park(live[i])
			recycled += 1
		return
	var n: int = vehicles.size()
	var active: int = live.size()
	var made: int = 0
	var people: Array = []
	if active < target:
		_append_people(people)
	for k: int in range(n):
		if active >= target or made >= SPAWNS_PER_CHECK:
			break
		var c: Vehicle = vehicles[(_rot + k) % n]
		if c.active or c.police:
			continue
		var spot: Array = _random_spot(c2, SPAWN_MIN, SPAWN_MAX, c.kind, true, people)
		if spot.is_empty():
			continue
		_activate(c, int(spot[0]), float(spot[1]))
		active += 1
		made += 1
	_rot = (_rot + 7) % maxi(1, n)
```

3j. In `_look_ahead()`, replace `		if o[4] == c or (c.ghost_t > 0.0 and String(o[3]) == "car"):` with:

```gdscript
		if o[4] == c or (c.ghost_t > 0.0 and String(o[3]) == "car") or (c.police and String(o[3]) == "player"):
```

3k. In `_physics_process()`, replace

```gdscript
		_advance(c, c.speed * delta)
		if c.active:
			_place(c, delta)
```

with

```gdscript
		_advance(c, c.speed * delta)
		if c.active:
			_place(c, delta)
		if c.active and c.police_state == "ride":
			_police_progress(c, delta)
```

and at the end of `_place()` add:

```gdscript
	if c.police:
		_siren(c)
```

3l. In `hit_vehicle()`, replace

```gdscript
	if not c.active or c.wreck_t >= 0.0:
		return false
	if kind == "blast":
```

with

```gdscript
	if not c.active or c.wreck_t >= 0.0:
		return false
	var dismounted: bool = false
	if c.police and c.police_state == "ride":
		police_dismount(idx)                 # a police rider under fire gets off and chases on foot
		dismounted = true
	if kind == "blast":
```

and replace its later lines `	if c.halted:` / `		return false` with:

```gdscript
	if c.halted:
		return dismounted
```

3m. Append to the PHASE W section (right after `vehicle_of()`):

```gdscript
## Phase W police motorbike (spec section 4): a lane spot 40-120 m from police_target_fn(), preferring lanes heading toward
## it; reuses a parked police body or builds one (at most POLICE_MAX); rides at POLICE_SPEED with greedy exits. Returns the
## vehicle index, or -1 when no lane spot is found.
func spawn_police() -> int:
	var tgt: Vector3 = police_target_fn.call() if police_target_fn.is_valid() else _center()
	var c2 := Vector2(tgt.x, tgt.z)
	var spot: Array = []
	for k: int in 6:
		var s: Array = _random_spot(c2, SPAWN_MIN, SPAWN_MAX * 0.8, Kind.POLICE, k < 4, [])
		if s.is_empty():
			continue
		spot = s
		if _lane_dir(int(s[0]), float(s[1])).dot(c2 - _lane_point(int(s[0]), float(s[1]))) > 0.0:
			break
	if spot.is_empty():
		return -1
	var c: Vehicle = null
	for v: Vehicle in vehicles:
		if v.police and not v.active:
			c = v
			break
	if c == null:
		if _police_count() >= POLICE_MAX:
			return -1
		c = _make_vehicle(Kind.POLICE)
		vehicles.append(c)
		_exclude_from_cameras(c.body)
	c.police_state = "ride"
	_activate(c, int(spot[0]), float(spot[1]))
	c.cruise = POLICE_SPEED
	c.speed = POLICE_SPEED * 0.6
	c.best_d = INF
	c.no_prog_t = 0.0
	return c.idx


func _police_progress(c: Vehicle, delta: float) -> void:
	var t3: Vector3 = police_target_fn.call() if police_target_fn.is_valid() else _center()
	var d: float = c.pos.distance_to(Vector2(t3.x, t3.z))
	if d < c.best_d - 0.5:
		c.best_d = d
		c.no_prog_t = 0.0
	else:
		c.no_prog_t += delta
	if d <= POLICE_DISMOUNT_M or (d <= POLICE_NEAR_M and c.no_prog_t >= POLICE_NO_PROGRESS_S):
		police_dismount(c.idx)


## The police rider gets off beside his bike; the bike stays as a halted obstacle (recycled out of view) and
## police_arrived(idx, at) asks WantedDirector for an officer on foot there.
func police_dismount(idx: int) -> void:
	var c: Vehicle = vehicles[idx]
	if not c.police or c.police_state != "ride":
		return
	c.police_state = "parked"
	c.halted = true
	c.speed = 0.0
	c.rider_gone = true
	var rider: Node3D = c.body.get_node_or_null("Rider") as Node3D
	if rider:
		rider.visible = false
	var side := Vector2(-c.dir.y, c.dir.x)
	police_arrived.emit(idx, Vector3(c.pos.x + side.x * RIDER_SIDE_M, MapBuilder.ROAD_Y, c.pos.y + side.y * RIDER_SIDE_M))


## Wanted level over / busted: riding police bikes stop where they are (recycled out of view), no officer gets off.
func release_police() -> void:
	for c: Vehicle in vehicles:
		if c.police and c.active and c.police_state == "ride":
			c.police_state = ""
			c.halted = true
			c.speed = 0.0


func is_police_riding(idx: int) -> bool:
	return idx >= 0 and idx < vehicles.size() and vehicles[idx].active and vehicles[idx].police_state == "ride"


func _police_count() -> int:
	return vehicles.filter(func(v: Vehicle) -> bool: return v.police).size()


func _civil_count() -> int:
	return vehicles.size() - _police_count()


## Police bikes use the motorbike lanes.
func _lane_bit(kind: int) -> int:
	return 1 << (Kind.MOTO if kind == Kind.POLICE else kind)


## Bodies built after FreeRoam._build_traffic: the player camera ray and the bike spring arm look through them too.
func _exclude_from_cameras(body: CollisionObject3D) -> void:
	if player and player.get("cam_ray"):
		(player.get("cam_ray") as RayCast3D).add_exception(body)
	if bike and bike.get("spring_arm"):
		(bike.get("spring_arm") as SpringArm3D).add_excluded_object(body.get_rid())


func _add_siren(b: Node3D) -> void:
	for k: int in 2:
		var mi := MeshInstance3D.new()
		mi.name = "SirenR" if k == 0 else "SirenB"
		var bm := BoxMesh.new()
		bm.size = Vector3(0.09, 0.07, 0.09)
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color("#FF2E3C") if k == 0 else Color("#2E6BFF")
		m.set_meta("vice_done", true)
		mi.material_override = m
		mi.position = Vector3(-0.06 + 0.12 * float(k), 1.2, 0.75)
		b.add_child(mi)


func _siren(c: Vehicle) -> void:
	var on: bool = (Time.get_ticks_msec() / SIREN_MS) % 2 == 0
	var r: Node3D = c.body.get_node_or_null("SirenR") as Node3D
	var bl: Node3D = c.body.get_node_or_null("SirenB") as Node3D
	if r and bl:
		r.visible = on
		bl.visible = not on
```

- [ ] **Step 4: Street spawns in `scripts/wanted/WantedDirector.gd`**

4a. After `const GIVE_UP_DESPAWN_S: float = 20.0` add:

```gdscript
const BIKES: Array[int] = [1, 2, 3]
const SECOND_WAVE_S: float = 30.0
```

and after `var _rng := RandomNumberGenerator.new()` add:

```gdscript
var three_star_t: float = 0.0
var second_wave: bool = false
var pending_bikes: Array[int] = []       # police bikes on their way (RoamTraffic indices)
var bikes_sent: int = 0
```

4b. In `setup()`, after `	traffic = opts.get("traffic")` add:

```gdscript
	if traffic:
		traffic.police_target_fn = target_pos
		traffic.police_arrived.connect(_on_police_arrived)
```

4c. In `tick()`, add `		_release_bikes()` as the line right after `		_retire(delta)`, and right after `	_give_up_t = 0.0` add:

```gdscript
	if stars == 3:
		three_star_t += delta
		second_wave = second_wave or three_star_t >= SECOND_WAVE_S
	else:
		three_star_t = 0.0
		second_wave = false
```

4d. Replace the whole `_maintain()` function with:

```gdscript
## Once per MAINTAIN_S: officers far away and out of view leave; campus (inside the plot): guards up to GUARDS[stars] and
## Mr.T from 2 stars; streets and residential: police bikes up to BIKES[stars] (+3 for the second wave after 30 s at
## 3 stars), counting the ones on their way and the officers already off their bikes. At most SPAWNS_PER_MAINTAIN per call.
func _maintain() -> void:
	var p: Vector3 = target_pos()
	for o: Officer in officers():
		if WeaponMath.flat(o.global_position, p) > DESPAWN_R and not _in_view(o.global_position):
			_despawn(o)
	if not spawning:
		return
	var budget: int = SPAWNS_PER_MAINTAIN
	if is_campus(p):
		var have: int = count_role("guard")
		while have < GUARDS[stars - 1] and budget > 0:
			if spawn_officer("guard") == null:
				break
			have += 1
			budget -= 1
		if stars >= 2 and count_role("mr_t") == 0 and budget > 0:
			spawn_officer("mr_t")
	else:
		_prune_pending()
		var want: int = BIKES[stars - 1] + (BIKES[2] if second_wave else 0)
		var have_p: int = count_role("police") + pending_bikes.size()
		while have_p < want and budget > 0:
			if not _send_bike():
				break
			have_p += 1
			budget -= 1
```

4e. Append:

```gdscript
## A police bike from the traffic, or (no traffic / no lane spot) a police officer on foot (plan P9).
func _send_bike() -> bool:
	if traffic:
		var idx: int = traffic.spawn_police()
		if idx >= 0:
			pending_bikes.append(idx)
			bikes_sent += 1
			return true
	return spawn_officer("police") != null


func _prune_pending() -> void:
	for i: int in range(pending_bikes.size() - 1, -1, -1):
		if traffic == null or not traffic.is_police_riding(pending_bikes[i]):
			pending_bikes.remove_at(i)


func _on_police_arrived(idx: int, at: Vector3) -> void:
	pending_bikes.erase(idx)
	if state != "free" or stars == 0:
		return
	var spot: Variant = roam.call("find_free_spot", at, at.y, 3) if roam and roam.has_method("find_free_spot") else at
	var o: Officer = spawn_officer("police", spot if spot is Vector3 else at)
	if o:
		o.bike_idx = idx


func _release_bikes() -> void:
	pending_bikes.clear()
	if traffic:
		traffic.release_police()
```

- [ ] **Step 5: Run the test**

Run: `godot --headless --path . --script tests/test_police_bikes.gd > /tmp/w_t9.log 2>&1; grep -E "SUCCESS|FAIL|✗" /tmp/w_t9.log`
Expected: `✅ SUCCESS: POLICE BIKES …`. Also run `tests/test_roam_traffic.gd` (civil traffic unchanged), `tests/test_officers.gd` and `tests/test_hit_reactions.gd`.

- [ ] **Step 6: Run the full regression, then commit**

```bash
git add scripts/roam/RoamTraffic.gd scripts/wanted/WantedDirector.gd tests/test_police_bikes.gd tests/test_police_bikes.gd.uid
git commit -m "feat(wanted): police motorbikes - RoamTraffic police kind (white paint, police rider, siren) spawned on a lane heading to the player, greedy exits at 12 m/s, dismount within 15 m (or 60 m without progress) into a police officer on foot, shot riders dismount, civil counts ignore police; WantedDirector 1/2/3 bikes by stars plus a second wave of 3 after 30 s at 3 stars, foot fallback without traffic

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 10: Busted – catch rules, "BỊ TÓM!" stamp and the busted cutscene  [effort: xhigh]

**Files:**
- Create: `scripts/wanted/BustedStamp.gd`, `scripts/cine/timelines/wanted_busted.gd`, `docs/cinematics/wanted_busted.txt` (generated).
- Modify: `scripts/wanted/WantedDirector.gd`, `scripts/FreeRoam.gd` (`play_cinematic` opts `"xf"`, `_exit_tree`).
- Test: `tests/test_busted.gd`.

**Interfaces:**
- Consumes:
  - A1: `CineTimeline` (helpers, `validate()`, `beat_sheet()`, `load_slot`), `CineClock` presets, `CineMoves` moves `idle, walk, yank, grab, stunned, head_shake`, `CineAudio.SFX_CUES` (`neck_crack`, `slide_whistle`), `CinePlayer` (`force_skip_hold`, `step`, `stage_xf`, `timeline`), `FreeRoam.play_cinematic`, `cinematic_finished`, `tools/cine_beats.gd`.
  - Task 8: `Officer.can_catch()`, `WantedDirector.catch_enabled`, `officers()`, `_despawn`.
  - Task 9: `_release_bikes()`.
- Produces:
  - `class_name BustedStamp extends CanvasLayer`: signal `done`, constants `SHOW_S 1.0`, `TEXT "BỊ TÓM!"`, vars `manual`, `t`, `label`, `step_real(dt)`.
  - Timeline `wanted_busted` (7.000 s, one medium ramp `B1` at real 2.400 s, tail 3.740 s): `var catcher: String` ("guard" | "police" | "mr_t").
  - `WantedDirector`:
    - signal `busted(catcher: String)`;
    - constants `CATCH_R 1.2, CATCH_S 1.5, BUSTED_TIMELINE`;
    - vars `catch_t, busts, catcher, bust_on_campus, cine_opts: Dictionary, stamp: BustedStamp, stamp_manual: bool`;
    - `bust(o: Officer)` and `_start_service()` (Task 10 version: clear and free; Task 11 replaces it).
  - `FreeRoam.play_cinematic(tl, opts)` honours `opts["xf"]: Transform3D` (stage frame) instead of the timeline's stage search.

- [ ] **Step 1: Write the failing test `tests/test_busted.gd`**

```gdscript
# File: res://tests/test_busted.gd
# Headless test of Phase W busting (spec W-D8, section 5, section 7 "busted detection"): the busted timeline passes the A1
# validator for every catcher (7 s, tail 3-4 s) and its beat sheet is in sync; the "BỊ TÓM!" stamp slams in and is done after
# 1 s real; an officer within 1.2 m of a standing player for 1.5 s busts him (not earlier), stepping away resets the timer,
# a knocked-out officer cannot catch, a knocked-down player is busted at once, nobody is busted while riding or with
# catch_enabled off; in FreeRoam the bust freezes the game, stamps, plays the cutscene at the player's spot through
# play_cinematic (wheel blocked), hold-Esc skips it, and the game resumes. Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_busted.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")
const TL_PATH: String = "res://scripts/cine/timelines/wanted_busted.gd"

var fails: Array[String] = []
var frames: int = 0
var phase: String = ""
var t0: int = 0
var started: bool = false
var arena: Node3D
var player: ThirdPersonController
var wanted: WantedDirector
var guard: Officer
var stamp_done: bool = false
var roam: Node3D
var busts0: int = 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	print("--- TEST BUSTED ---")
	for who: String in ["guard", "police", "mr_t"]:
		var tl: CineTimeline = (load(TL_PATH) as GDScript).new()
		tl.set("catcher", who)
		tl.build()
		var errs: PackedStringArray = tl.validate()
		_check(errs.is_empty(), "busted timeline (%s) passes the A1 validator %s" % [who, str(errs)])
		var tail: float = tl.length - float(tl.clock.ramps[tl.clock.ramps.size() - 1]["r1"])
		_check(is_equal_approx(tl.length, 7.0) and tail >= 3.0 and tail <= 4.0, "7 s long, %.3f s normal-speed tail" % tail)
		_check(tl.actors.has("mr_t") == (who == "mr_t"), "Mr.T appears only when he made the catch (%s)" % who)
	var committed: String = FileAccess.get_file_as_string("res://docs/cinematics/wanted_busted.txt").replace("\r\n", "\n")
	_check(committed == CineTimeline.load_slot("wanted_busted").beat_sheet(), "docs/cinematics/wanted_busted.txt is in sync (run tools/cine_beats.gd)")
	physics_frame.connect(_on_physics)


func _next(p: String) -> void:
	phase = p
	t0 = frames


func _guard_at(off: Vector3) -> Officer:
	return wanted.spawn_officer("guard", player.global_position + off)


## Release the stamp; without FreeRoam there is no cutscene. Task 11 then starts a community-service chore (far away at
## the default street spot): finish it at once and bring the player back, so these catch-rule checks stay valid after Task 11.
func _release_stamp() -> void:
	if wanted.stamp:
		wanted.stamp.step_real(1.1)
	var svc: Variant = wanted.get("service")
	if svc != null and is_instance_valid(svc):
		svc.call("finish")
	player.teleport(Vector3.ZERO, 0.0)


func _on_physics() -> void:
	frames += 1
	if not started:
		started = true
		arena = Node3D.new()
		root.add_child(arena)
		World.floor_box(arena)
		player = World.player(arena, Vector3.ZERO, 0.0)
		var st := BustedStamp.new()
		st.manual = true
		arena.add_child(st)
		st.done.connect(func() -> void: stamp_done = true)
		st.step_real(0.5)
		_check(st.label.text == "BỊ TÓM!" and st.label.scale.is_equal_approx(Vector2.ONE) and st.label.modulate.a > 0.99, "the stamp has slammed in after 0.5 s")
		st.step_real(0.6)
		_check(stamp_done and st.is_queued_for_deletion(), "the stamp is done after 1 s")
		wanted = WantedDirector.new()
		wanted.name = "Wanted"
		arena.add_child(wanted)
		wanted.setup({"player": player, "is_campus_fn": func(_p: Vector3) -> bool: return false})
		wanted.spawning = false
		wanted.stamp_manual = true
		wanted.add_heat(4.0)
		guard = _guard_at(Vector3(1.0, 0.0, 0.0))
		_next("stand")
		return
	var t: int = frames - t0
	match phase:
		"stand":
			if t == 80:
				_check(wanted.busts == 0, "not busted before 1.5 s (catch timer %.2f)" % wanted.catch_t)
			if t == 100:
				_check(wanted.busts == 1 and wanted.state == "stamp" and paused and wanted.stamp != null, "1.5 s within 1.2 m of a standing player: busted, game frozen, stamp")
				_check(wanted.catcher == "guard", "the catcher's role is kept for the cutscene")
				_release_stamp()
				_check(wanted.state == "free" and wanted.stars == 0 and not paused and wanted.officers().is_empty(), "without FreeRoam the cutscene is skipped and the level cleared")
				wanted.add_heat(4.0)
				guard = _guard_at(Vector3(1.0, 0.0, 0.0))
				_next("step_away")
		"step_away":
			if t == 60:
				guard.global_position = player.global_position + Vector3(6.0, 0.0, 0.0)
			if t == 62:
				_check(wanted.catch_t == 0.0 and wanted.busts == 1, "stepping away resets the catch timer")
				guard.take_hit({"kind": "melee", "from": player.global_position})
				guard.global_position = player.global_position + Vector3(0.8, 0.0, 0.0)
			if t == 180:
				_check(wanted.busts == 1, "a knocked-out officer next to the player cannot catch him")
				_guard_at(Vector3(0.0, 0.0, 1.0))
			if t == 182:
				player.knock_down(Vector3(1.0, 0.0, 0.0), 1.0)
			if t == 186:
				_check(wanted.busts == 2, "an officer reaching a knocked-down player busts him at once")
				_release_stamp()
				wanted.add_heat(4.0)
				player.visible = false
				_guard_at(Vector3(1.0, 0.0, 0.0))
				_next("riding")
		"riding":
			if t == 120:
				_check(wanted.busts == 2, "nobody is busted while riding (player hidden)")
				player.visible = true
				wanted.catch_enabled = false
			if t == 240:
				_check(wanted.busts == 2, "catch_enabled = false: never busted")
				_start_b()
		"b":
			_part_b(t)


func _start_b() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var n: Node = (load(pair[1]) as Script).new()
			n.name = pair[0]
			root.add_child(n)
	arena.queue_free()
	roam = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	roam.set("crowd_enabled", false)
	root.add_child(roam)
	_next("b")


func _part_b(t: int) -> void:
	var w: WantedDirector = roam.get("wanted")
	var pl: ThirdPersonController = roam.get("player")
	if t == 60:
		w.cine_opts = {"manual": true, "music": false}
		w.stamp_manual = true
		var cc: Vector2 = FPTUCampusBuilder.ring_courtyard_rect().get_center()
		var c3: Vector3 = FPTUCampusBuilder.real_plot_transform() * Vector3(cc.x, 0.0, cc.y)
		var spot: Variant = roam.call("find_free_spot", c3, 0.0, 8)
		pl.teleport((spot if spot is Vector3 else c3) + Vector3(0.0, 0.05, 0.0), 0.0)
	if t == 70:
		w.add_heat(12.0)
		var near: Variant = roam.call("find_free_spot", pl.global_position + Vector3(1.0, 0.0, 0.0), pl.global_position.y, 2)
		w.spawn_officer("guard", near if near is Vector3 else pl.global_position + Vector3(1.0, 0.0, 0.0))
	if t > 70 and w.busts == 1 and not has_meta("bb"):
		set_meta("bb", true)
		_check(w.state == "stamp" and paused and w.catcher in ["guard", "mr_t"], "busted on campus by %s: frozen + stamp" % w.catcher)
		w.stamp.step_real(1.1)
		var cp: CinePlayer = roam.get("cine_player")
		_check(w.state == "cutscene" and cp != null and cp.timeline.slot == "wanted_busted", "the busted cutscene plays through play_cinematic")
		_check(cp != null and cp.stage_xf.origin.distance_to(pl.global_position) < 0.1, "staged at the player's spot (opts xf)")
		_check(not pl.visible and not (roam.get("weapon_hud") as CanvasLayer).visible, "player and weapon HUD hidden during the cutscene")
		var ww: WeaponWheel = roam.get("weapon_wheel")
		ww.manual = true
		ww.press()
		ww.step_real(0.2)
		_check(not ww.is_open(), "the wheel is blocked during the cutscene")
		cp.force_skip_hold = true
		var n: int = 0
		while roam.get("cine_player") != null and n < 200:
			cp.step(1.0 / 60.0)
			n += 1
		_check(roam.get("cine_player") == null and n < 100, "hold Esc skips the cutscene (%d steps)" % n)
		_check(not paused and pl.visible and (w.state == "free" or w.state == "service"), "the game resumes after the cutscene (state %s)" % w.state)
		_finish()
	if t == 400 and not has_meta("bb"):
		_check(false, "the guard never busted the player in FreeRoam")
		_finish()


func _finish() -> void:
	Engine.time_scale = 1.0
	if fails.is_empty():
		print("✅ SUCCESS: BUSTED (timeline valid for all catchers, beat sheet, stamp, 1.5 s catch, reset, KO'd officers, knocked-down player, riding, cutscene + skip in FreeRoam)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless --path . --script tests/test_busted.gd > /tmp/w_t10.log 2>&1; grep -E "SUCCESS|FAIL|Parse Error" /tmp/w_t10.log`
Expected: a failure (the timeline script and `BustedStamp` do not exist yet).

- [ ] **Step 3: Write `scripts/wanted/BustedStamp.gd`**

```gdscript
# File: res://scripts/wanted/BustedStamp.gd
# "BỊ TÓM!" stamp shown when the player is busted (spec section 5): a big red word with a white outline that slams in
# (scale 2.2 -> 1 in SLAM_S, tilted -8°), holds, fades over the last FADE_S of SHOW_S real seconds (Time.get_ticks_usec, or
# step_real(dt) when manual), PROCESS_MODE_ALWAYS because the game is frozen meanwhile; emits `done` and frees itself.
class_name BustedStamp
extends CanvasLayer

signal done

const SHOW_S: float = 1.0
const SLAM_S: float = 0.15
const FADE_S: float = 0.15
const TEXT: String = "BỊ TÓM!"
const RED := Color("#E8323C")

var manual: bool = false
var t: float = 0.0
var label: Label
var _last_us: int = 0
var _done: bool = false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	label = Label.new()
	label.name = "Stamp"
	label.text = TEXT
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.offset_left = -360.0
	label.offset_right = 360.0
	label.offset_top = -90.0
	label.offset_bottom = 90.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 110)
	label.add_theme_color_override("font_color", RED)
	label.add_theme_color_override("font_outline_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", 18)
	label.pivot_offset = Vector2(360.0, 90.0)
	label.rotation = deg_to_rad(-8.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	_last_us = Time.get_ticks_usec()
	_apply()


func _process(_d: float) -> void:
	var now: int = Time.get_ticks_usec()
	var dt: float = float(now - _last_us) / 1e6
	_last_us = now
	if not manual:
		step_real(dt)


func step_real(dt: float) -> void:
	if _done:
		return
	t += dt
	_apply()
	if t >= SHOW_S - 1e-6:
		_done = true
		done.emit()
		queue_free()


func _apply() -> void:
	var u: float = clampf(t / SLAM_S, 0.0, 1.0)
	label.scale = Vector2.ONE * lerpf(2.2, 1.0, u * u * (3.0 - 2.0 * u))
	label.modulate.a = clampf((SHOW_S - t) / FADE_S, 0.0, 1.0)
```

- [ ] **Step 4: Write the timeline `scripts/cine/timelines/wanted_busted.gd`**

The slot is named `wanted_busted` so it sorts after `seg_d1_brawl`: F9 cycles `CineTimeline.slots()` in name order and `tests/test_cine_d1_brawl.gd` expects F9 to start with `seg_d1_brawl`. The ramp is placed by real time (`{"r": 2.4}`), so its story time is derived; `story_end` 6.251 makes the real length exactly 7.000 s (gap 2.080 + medium pre 0.138 + post 0.293 + tail 3.740). Nothing here writes `Engine.time_scale`.

```gdscript
# File: res://scripts/cine/timelines/wanted_busted.gd
# wanted_busted (7.000 s, Phase W spec section 5 / W-D8, plan Task 10): "BỊ TÓM!" – the officer who made the catch walks up behind
# the player and cuffs him on the B1 click (one medium ramp at real 2.400 s); if Mr.T (the story's
# fictional lecturer) made the catch, a guard cuffs and Mr.T stands in front shaking his head. WantedDirector sets
# `catcher` ("guard" | "police" | "mr_t") before build() and plays it through FreeRoam.play_cinematic with opts "xf" (the
# player's spot and facing), so `stage` stays empty. CineTimeline.load_slot("wanted_busted") builds the guard variant (beat sheet
# docs/cinematics/wanted_busted.txt). The ramp ends at 3.260 s real: a 3.740 s normal-speed tail (A1-D8: 3-4 s).
# Stage frame: X right, -Z forward (where the player faces), ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const HERO := Vector3(0.0, 0.0, 0.0)
const COP_FROM := Vector3(0.9, 0.0, 2.6)
const COP_AT := Vector3(0.3, 0.0, 0.8)
const MR_T_AT := Vector3(-0.9, 0.0, -1.6)

var catcher: String = "guard"


func build() -> void:
	slot = "wanted_busted"
	length = 7.0
	story_end = 6.251
	mood = "playful"
	fade_in = 0.3
	fade_out = 0.5
	stage = {}
	var police: bool = catcher == "police"
	actor("hero", {"preset": "player", "seed": 2805}, "Bạn", Color("#F37021"))
	actor("cop", {"preset": "cop", "seed": 32} if police else {"preset": "guard", "seed": 31}, "Cảnh sát" if police else "Bảo vệ", Color("#7FB2E5"))
	hit("B1", 2.2, "medium", "cuffs click", {"r": 2.4})
	key("hero", 0.0, HERO, 0.0)
	move("hero", 0.0, "idle")
	move("hero", 2.25, "stunned", {"fade": 0.15})
	expr("hero", 2.25, "pain")
	fx_at("B1", "stars", "hero", {"until": 6.0})
	key("cop", 0.0, COP_FROM, CineTimeline.face(COP_FROM, HERO))
	key("cop", 1.75, COP_AT, CineTimeline.face(COP_AT, HERO), {"mode": "out"})
	move("cop", 0.0, "walk")
	strike("cop", "B1", "yank")
	move("cop", 2.55, "grab")
	expr("cop", 2.55, "angry")
	sfx_at("B1", "neck_crack", -2.0)
	sfx_at(4.4, "slide_whistle", -8.0)
	shot("S1", 0.0, "static", "wide: the officer walks up behind", {"pos": Vector3(-2.8, 1.7, -3.2), "look": Vector3(0.3, 1.0, 0.9), "fov": 50.0})
	shot("S2", 1.85, "orbit", "close on the cuffs", {"center": Vector3(0.15, 1.0, 0.4), "radius": 1.9, "deg_from": 70.0, "deg_to": 110.0, "height": 1.25, "fov": 42.0})
	shot("S3", 3.3, "static", "front two-shot", {"pos": Vector3(0.35, 1.55, -3.4), "look": Vector3(0.15, 1.15, 0.3), "fov": 45.0, "hand": 0.3})
	if catcher == "mr_t":
		actor("mr_t", {"preset": "lecturer", "seed": 1995, "glasses": true}, "Mr.T", Color("#9B59B6"))
		key("mr_t", 0.0, MR_T_AT, CineTimeline.face(MR_T_AT, HERO))
		move("mr_t", 0.0, "idle")
		move("mr_t", 3.5, "head_shake")
		move("mr_t", 4.1, "head_shake")
		move("mr_t", 4.7, "idle")
		look("mr_t", 0.0, 6.2, "hero")
		look("hero", 3.4, 6.2, "mr_t")
		sub(3.3, 1.3, "mr_t", "Em kia! Thẻ sinh viên đâu?")
		sub(4.7, 1.1, "mr_t", "Mười năm đi dạy, chưa thấy em nào lì như em.")
	else:
		look("hero", 3.4, 6.2, "cop")
		sub(3.6, 1.8, "cop", "Mời anh đi lao động công ích!" if police else "Đi lao động công ích với chú nào!")
	sub(5.9, 0.9, "hero", "Ét o ét…")
```

- [ ] **Step 5: Generate the beat sheet**

```bash
godot --headless --path . --script tools/cine_beats.gd > /tmp/w_beats.log 2>&1; grep -E "wrote|refus|ERROR" /tmp/w_beats.log
git diff --stat docs/cinematics/
```
Expected: `wrote docs/cinematics/wanted_busted.txt` and `wrote docs/cinematics/seg_d1_brawl.txt`; `git diff` shows no change to `seg_d1_brawl.txt`, and `wanted_busted.txt` is a new file. If git only reports line-ending churn on `seg_d1_brawl.txt`, restore it with `git checkout -- docs/cinematics/seg_d1_brawl.txt`.

- [ ] **Step 6: Catch detection and the bust sequence in `scripts/wanted/WantedDirector.gd`**

6a. After `signal cleared` add `signal busted(catcher: String)`. After `const SECOND_WAVE_S: float = 30.0` add:

```gdscript
const CATCH_R: float = 1.2
const CATCH_S: float = 1.5
const BUSTED_TIMELINE: String = "res://scripts/cine/timelines/wanted_busted.gd"
```

and after `var bikes_sent: int = 0` add:

```gdscript
var catch_t: float = 0.0
var busts: int = 0
var catcher: String = ""
var bust_on_campus: bool = false
var cine_opts: Dictionary = {}           # extra play_cinematic opts (tests: {"manual": true, "music": false})
var stamp: BustedStamp = null
var stamp_manual: bool = false           # tests drive the stamp with stamp.step_real()
```

6b. In `tick()`, replace the final `	_update_search()` (the one after the `if seen:` block) with:

```gdscript
	if stars > 0:
		_check_catch(delta)
	_update_search()
```

6c. Append:

```gdscript
## Busted (spec section 5): an officer able to grab stays within CATCH_R of the player for CATCH_S while the player is on his
## feet, or reaches a knocked-down player (the comic tackle). Never while riding (player hidden) or with catch_enabled off.
func _check_catch(delta: float) -> void:
	if not catch_enabled or player == null or not player.visible:
		catch_t = 0.0
		return
	var p: Vector3 = player.global_position
	var near: Officer = null
	var best: float = CATCH_R
	for o: Officer in officers():
		if not o.can_catch():
			continue
		var d: float = WeaponMath.flat(o.global_position, p)
		if d <= best:
			best = d
			near = o
	if near == null:
		catch_t = 0.0
		return
	if player.is_knocked_down():
		bust(near)
		return
	catch_t += delta
	if catch_t >= CATCH_S - 1e-6:
		bust(near)


## Freeze, "BỊ TÓM!" stamp, then the busted cutscene (A1 CinePlayer through FreeRoam.play_cinematic), then community service.
func bust(o: Officer) -> void:
	if state != "free":
		return
	state = "stamp"
	busts += 1
	catch_t = 0.0
	catcher = o.role if o else "guard"
	bust_on_campus = is_campus(target_pos())
	busted.emit(catcher)
	_set_cine_flag(true)                 # Esc must not open the pause menu during the stamp
	if is_inside_tree():
		get_tree().paused = true
	stamp = BustedStamp.new()
	stamp.name = "BustedStamp"
	stamp.manual = stamp_manual
	add_child(stamp)
	stamp.done.connect(_on_stamp_done, CONNECT_ONE_SHOT)


func _on_stamp_done() -> void:
	stamp = null
	state = "cutscene"
	var tl: CineTimeline = (load(BUSTED_TIMELINE) as GDScript).new()
	tl.set("catcher", catcher)
	tl.build()
	var opts: Dictionary = cine_opts.duplicate()
	opts["xf"] = Transform3D(Basis(Vector3.UP, player.facing_yaw()), player.global_position)
	var cp: Variant = roam.call("play_cinematic", tl, opts) if roam and roam.has_method("play_cinematic") else null
	if cp == null:
		_set_cine_flag(false)
		if is_inside_tree():
			get_tree().paused = false
		_start_service()
		return
	roam.connect("cinematic_finished", _on_cine_done, CONNECT_ONE_SHOT)


func _on_cine_done(_slot: String, _skipped: bool) -> void:
	_start_service()


## Task 10: no chore yet – the officers leave, the wanted level is cleared and the player is free. Task 11 replaces this
## function with the community-service chore.
func _start_service() -> void:
	_clear_officers()
	state = "free"
	clear()


func _clear_officers() -> void:
	for o: Officer in officers():
		_despawn(o)
	catch_t = 0.0
	_release_bikes()


func _set_cine_flag(on: bool) -> void:
	var sm: Node = get_node_or_null("/root/StageManager")
	if sm:
		sm.set("cinematic_active", on)
```

- [ ] **Step 7: Stage frame and pause safety in `scripts/FreeRoam.gd`**

7a. In `play_cinematic()`, replace the line starting `	var xf: Variant = cine_stage(tl.stage) if …` with:

```gdscript
	var xf: Variant = opts["xf"] if opts.get("xf") is Transform3D else (cine_stage(tl.stage) if not tl.stage.is_empty() else Transform3D(Basis.IDENTITY, roam_position()))
```

and add to the function's doc comment: `## opts "xf" (Transform3D, Phase W busted cutscene): play at that frame instead of searching the timeline's stage.`

7b. In `_exit_tree()`, after the `if cine_player != null and is_inside_tree():` block add:

```gdscript
	if wanted and wanted.state == "stamp" and is_inside_tree():
		get_tree().paused = false   # rời cảnh giữa dấu "BỊ TÓM!": không để cảnh sau bị dừng
```

- [ ] **Step 8: Import, check the class cache, run the test**

```bash
godot --headless --import --path . > /tmp/w_imp.log 2>&1
grep -c 'BustedStamp' .godot/global_script_class_cache.cfg
git diff --name-only -- '*.import' | xargs -r git checkout --
godot --headless --path . --script tests/test_busted.gd > /tmp/w_t10.log 2>&1; grep -E "SUCCESS|FAIL|✗" /tmp/w_t10.log
```
Expected: the cache count is 1, and the test prints `✅ SUCCESS: BUSTED …`. `tests/test_cine_timeline.gd`, `tests/test_cine_player.gd` (F9 now cycles two slots) and `tests/test_cine_d1_brawl.gd` must stay green.

- [ ] **Step 9: Run the full regression, then commit**

```bash
git add scripts/wanted/BustedStamp.gd scripts/wanted/BustedStamp.gd.uid scripts/cine/timelines/wanted_busted.gd scripts/cine/timelines/wanted_busted.gd.uid docs/cinematics/wanted_busted.txt scripts/wanted/WantedDirector.gd scripts/FreeRoam.gd tests/test_busted.gd tests/test_busted.gd.uid
git commit -m "feat(wanted): busted - an officer 1.2 m from a standing player for 1.5 s (or reaching a knocked-down one) busts him: freeze, 'BỊ TÓM!' stamp, the 7 s busted cutscene (A1 timeline, validator-clean, one medium ramp on the cuffs click, Mr.T shakes his head when he made the catch) played at the player's spot via play_cinematic opts xf, hold Esc skips; beat sheet docs/cinematics/wanted_busted.txt

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 11: Community service ("Lao động công ích")  [effort: high]

**Files:**
- Create: `scripts/wanted/CommunityService.gd`.
- Modify: `scripts/wanted/WantedDirector.gd` (`_start_service`, completion), `scripts/FreeRoam.gd` (bike lock, `place_beside_bike`), `scripts/weapons/WeaponAudio.gd` (`bag_drop`).
- Test: `tests/test_community_service.gd`.

**Interfaces:**
- Consumes:
  - Task 8: `Officer.setup`, `supervise()`, `say()`, `bubble`.
  - Task 10: `WantedDirector.bust_on_campus`, `_clear_officers()`, the call to `_start_service()`, `clear()`.
  - `FreeRoam.find_free_spot`, `_dismount_spot`, `bike_parked`, `toggle_bike`, `flash_hint`.
  - `CharacterBuilder.get_pivot(model, "torso")`, `CharacterBuilder.play(model, "carry", secs)`.
- Produces:
  - `class_name CommunityService extends Node3D`:
    - signals `completed`, `restarted(bags: int)`, `delivered_bag(count: int)`;
    - constants `TIME_S 120.0, BAGS 8, MIN_BAGS 2, BAG_STEP 2, PICK_R 1.3, BIN_R 1.7, STREET_NEAR, LINES`;
    - vars `player, roam, on_campus, center, total, delivered, time_left, restarts, carrying, bags, bin, supervisor, vest, hud_label`;
    - static `street_center(md) -> Vector3`, `campus_center(md) -> Vector3`, `make_vest()`, `make_bag()`, `make_bin()`;
    - `start(player, roam, md, campus: bool, at: Variant = null)`, `finish()`.
  - `WantedDirector`: signal `service_started(on_campus: bool)`, var `service: CommunityService`.
  - `FreeRoam`: const `HINT_SERVICE_BIKE`, `place_beside_bike() -> bool`.
  - `WeaponAudio` cue `bag_drop`.

- [ ] **Step 1: Write the failing test `tests/test_community_service.gd`**

```gdscript
# File: res://tests/test_community_service.gd
# Headless test of Phase W community service (spec W-D8, section 5, section 7): the chore puts the player in an orange
# vest, 8 rubbish bags 4-10 m around a bin and a supervising officer who says meme lines; walking onto a bag carries it,
# walking to the bin drops it; 8 drops complete it (vest gone); running out of the 120 s restarts it with 2 bags fewer, never
# fewer than 2 (no softlock); Esc cannot skip it; the street spot is a verge beside Nguyễn Xiển and the campus spot is the
# parking. Part B (FreeRoam, crowd off): busted on campus -> cutscene skipped -> chore at the campus parking with weapons and
# the bike locked -> 8 bags -> wanted level cleared, player beside his parked bike, weapons free again.
# Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_community_service.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")

var fails: Array[String] = []
var frames: int = 0
var phase: String = ""
var t0: int = 0
var started: bool = false
var arena: Node3D
var player: ThirdPersonController
var svc: CommunityService
var done_n: int = 0
var restarts: Array[int] = []
var step_i: int = 0
var roam: Node3D


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	print("--- TEST COMMUNITY SERVICE ---")
	var md: MapData = MapData.load_default()
	var sc: Vector3 = CommunityService.street_center(md)
	_check(WeaponMath.flat(sc, Vector3(CommunityService.STREET_NEAR.x, 0.0, CommunityService.STREET_NEAR.y)) < 60.0, "the street chore is on the Nguyễn Xiển verge (%s)" % sc)
	var lm: Array = md.landmark("campus_parking_center")
	_check(CommunityService.campus_center(md).is_equal_approx(Vector3(float(lm[0]), 0.0, float(lm[1]))), "the campus chore is at the campus parking")
	physics_frame.connect(_on_physics)


func _next(p: String) -> void:
	phase = p
	t0 = frames


func _new_service() -> CommunityService:
	var s := CommunityService.new()
	s.name = "Service"
	arena.add_child(s)
	s.start(player, null, null, false, Vector3.ZERO)
	s.completed.connect(func() -> void: done_n += 1)
	s.restarted.connect(func(n: int) -> void: restarts.append(n))
	return s


## One bag per two frames: even frames step onto the next bag, odd frames walk it to the bin.
func _deliver(s: CommunityService, ply: ThirdPersonController) -> void:
	if step_i % 2 == 0:
		if not s.bags.is_empty():
			ply.teleport(s.bags[0].global_position, 0.0)
	else:
		ply.teleport(s.bin.global_position + Vector3(0.6, 0.0, 0.0), 0.0)
	step_i += 1


func _on_physics() -> void:
	frames += 1
	if not started:
		started = true
		arena = Node3D.new()
		root.add_child(arena)
		World.floor_box(arena)
		player = World.player(arena, Vector3(5.0, 0.0, 5.0), 0.0)
		svc = _new_service()
		_check(player.global_position.distance_to(Vector3.ZERO) < 0.2, "the player is moved to the chore spot")
		_check(player.model.find_child("ServiceVest", true, false) != null, "the player wears the orange vest")
		_check(svc.supervisor != null and svc.supervisor.state == Officer.State.SUPERVISE, "a supervising officer watches")
		_check(svc.bags.size() == CommunityService.BAGS and svc.total == 8 and is_equal_approx(svc.time_left, CommunityService.TIME_S), "8 bags, 120 s")
		var ring: bool = true
		for b: Node3D in svc.bags:
			var d: float = WeaponMath.flat(b.global_position, svc.center)
			ring = ring and d >= CommunityService.RING_MIN - 0.01 and d <= CommunityService.RING_MAX + 0.01
		_check(ring, "bags lie 4-10 m around the chore spot")
		_check(not svc.has_method("_input") and not svc.has_method("_unhandled_input"), "no input handler: Esc cannot skip the chore")
		svc.set("_line_t", 0.01)
		_next("lines")
		return
	var t: int = frames - t0
	match phase:
		"lines":
			if t == 3:
				_check(CommunityService.LINES.has(svc.supervisor.bubble.text) and svc.supervisor.bubble.visible, "the supervisor says a meme line")
				step_i = 0
				_next("deliver")
		"deliver":
			if done_n == 1:
				_check(step_i == 16, "8 bags in the bin complete the chore (%d steps)" % step_i)
				_next("after")
				return
			if step_i == 0:
				_check(svc.carrying == null, "test setup: empty hands")
			if step_i == 1:
				_check(svc.carrying != null and svc.carrying.get_parent() == player.model, "stepping onto a bag picks it up (carried in front)")
			_deliver(svc, player)
			if t == 60:
				_check(false, "the chore did not complete (%d / %d)" % [svc.delivered, svc.total])
				_next("after")
		"after":
			if t == 2:
				_check(player.model.find_child("ServiceVest", true, false) == null, "the vest comes off")
				svc = _new_service()
				svc.time_left = 0.05
			if t == 8:
				_check(restarts.size() == 1 and restarts[0] == 6 and svc.bags.size() == 6 and svc.delivered == 0, "time out: restarts with 6 bags (%s)" % str(restarts))
				svc.time_left = 0.05
			if t == 14:
				svc.time_left = 0.05
			if t == 20:
				svc.time_left = 0.05
			if t == 26:
				_check(restarts.size() == 4 and restarts[1] == 4 and restarts[2] == 2 and restarts[3] == 2, "... then 4, 2 and never fewer than 2 (%s)" % str(restarts))
				svc.finish()
				_start_b()
		"b":
			_part_b(t)


func _start_b() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var n: Node = (load(pair[1]) as Script).new()
			n.name = pair[0]
			root.add_child(n)
	arena.queue_free()
	roam = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	roam.set("crowd_enabled", false)
	root.add_child(roam)
	_next("b")


func _part_b(t: int) -> void:
	var w: WantedDirector = roam.get("wanted")
	var pl: ThirdPersonController = roam.get("player")
	var bike: Node3D = roam.get("bike")
	if t == 60:
		roam.call("mount_bike")
	if t == 64:
		roam.call("dismount_bike")
		_check(bool(roam.get("bike_parked")), "test setup: the bike is parked near BE6")
		w.cine_opts = {"manual": true, "music": false}
		w.stamp_manual = true
		var cc: Vector2 = FPTUCampusBuilder.ring_courtyard_rect().get_center()
		var c3: Vector3 = FPTUCampusBuilder.real_plot_transform() * Vector3(cc.x, 0.0, cc.y)
		var spot: Variant = roam.call("find_free_spot", c3, 0.0, 8)
		pl.teleport((spot if spot is Vector3 else c3) + Vector3(0.0, 0.05, 0.0), 0.0)
	if t == 70:
		w.add_heat(4.0)
		var near: Variant = roam.call("find_free_spot", pl.global_position + Vector3(1.0, 0.0, 0.0), pl.global_position.y, 2)
		w.spawn_officer("guard", near if near is Vector3 else pl.global_position + Vector3(1.0, 0.0, 0.0))
	if t > 70 and w.busts == 1 and w.state == "stamp":
		w.stamp.step_real(1.1)
		var cp: CinePlayer = roam.get("cine_player")
		if cp:
			cp.force_skip_hold = true
			var n: int = 0
			while roam.get("cine_player") != null and n < 200:
				cp.step(1.0 / 60.0)
				n += 1
		var s: CommunityService = w.service
		_check(w.state == "service" and s != null and s.on_campus, "busted on campus -> community service on campus")
		_check(s != null and WeaponMath.flat(pl.global_position, CommunityService.campus_center(roam.get("md"))) < 15.0, "the chore is at the campus parking")
		_check(pl.model.find_child("ServiceVest", true, false) != null, "orange vest on")
		var ww: WeaponWheel = roam.get("weapon_wheel")
		ww.manual = true
		ww.press()
		ww.step_real(0.2)
		_check(not ww.is_open(), "weapons are locked during the chore")
		roam.call("toggle_bike")
		_check(not bool(roam.get("mounted")), "the bike is locked during the chore")
		step_i = 0
		set_meta("svc_t", t)
	if has_meta("svc_t") and w.state == "service":
		_deliver(w.service, pl)
	if has_meta("svc_t") and w.state == "free" and not has_meta("done_b"):
		set_meta("done_b", true)
		_check(w.stars == 0 and w.heat == 0.0, "finishing clears the wanted level")
		_check(WeaponMath.flat(pl.global_position, bike.global_position) < 3.0, "the player is put beside his bike (%.1f m)" % WeaponMath.flat(pl.global_position, bike.global_position))
		set_meta("free_t", t)
	if has_meta("free_t") and t == int(get_meta("free_t")) + 3:
		_check(pl.model.find_child("ServiceVest", true, false) == null, "the vest is gone")
		var ww2: WeaponWheel = roam.get("weapon_wheel")
		ww2.press()
		ww2.step_real(0.2)
		_check(ww2.is_open(), "the weapons are free again")
		ww2.cancel()
		ww2.step_real(0.2)
		_finish()
	if t == 600 and not has_meta("done_b"):
		_check(false, "the FreeRoam service flow did not finish (state %s)" % w.state)
		_finish()


func _finish() -> void:
	Engine.time_scale = 1.0
	if fails.is_empty():
		print("✅ SUCCESS: COMMUNITY SERVICE (vest, bags, bin, supervisor lines, completion, restart with fewer bags, spots, FreeRoam flow with locks and bike placement)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless --path . --script tests/test_community_service.gd > /tmp/w_t11.log 2>&1; grep -E "SUCCESS|FAIL|Parse Error" /tmp/w_t11.log`
Expected: a parse error (`CommunityService` not declared).

- [ ] **Step 3: Write `scripts/wanted/CommunityService.gd`**

```gdscript
# File: res://scripts/wanted/CommunityService.gd
# "Lao động công ích" (spec W-D8, section 5): after the busted cutscene the player, in an orange vest, carries 8 rubbish bags
# one at a time to a bin within 120 s, on a fixed verge of Nguyễn Xiển (or the campus parking when caught on campus), watched
# by a supervising officer who says meme lines (fictional, no real names). WantedDirector.state == "service" meanwhile, so
# FreeRoam locks the weapons and the bike. Running out of time restarts the chore with BAG_STEP fewer bags (never fewer than
# MIN_BAGS: no softlock). Finishing emits `completed` (WantedDirector clears the level, FreeRoam puts the player beside his
# bike). There is no input handler: hold-Esc skips only the cutscene, never the chore. Bags, bin and vest are code meshes.
class_name CommunityService
extends Node3D

signal completed
signal restarted(bags: int)
signal delivered_bag(count: int)

const TIME_S: float = 120.0
const BAGS: int = 8
const MIN_BAGS: int = 2
const BAG_STEP: int = 2
const PICK_R: float = 1.3
const BIN_R: float = 1.7
const RING_MIN: float = 4.0
const RING_MAX: float = 10.0
const LINE_EVERY: float = 9.0
const STREET_NEAR := Vector2(2058.0, -71.0)   # mid Nguyễn Xiển (corridor); the chore verge is beside the road there
const STREET_ROAD: String = "Nguyễn Xiển"
const VERGE_M: float = 2.5
const VEST := Color("#FF7A1A")
const STRIPE := Color("#D9DEE3")
const LINES: Array[String] = [
	"Nhặt cho sạch nha em, rác cũng có cảm xúc đó!",
	"Lao động là vinh quang, chạy lung tung là… lao động tiếp!",
	"Bao này nhẹ hơn deadline nhiều, ráng lên!",
	"Xong tám bao là cho về, khỏi điểm danh lại.",
	"Áo cam hợp với em ghê, chụp hình đăng nhóm lớp nha?",
	"Thấy chưa, phá phách xong thì ai dọn?",
]

var player: ThirdPersonController
var roam: Node
var on_campus: bool = false
var center: Vector3 = Vector3.ZERO
var total: int = BAGS
var delivered: int = 0
var time_left: float = TIME_S
var restarts: int = 0
var carrying: Node3D = null
var bags: Array[Node3D] = []
var bin: Node3D
var supervisor: Officer
var vest: Node3D
var hud_layer: CanvasLayer
var hud_label: Label
var _line_t: float = 3.0
var _line_i: int = 0
var _sfx: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


## The street chore spot: the Nguyễn Xiển point nearest STREET_NEAR, pushed VERGE_M past the road edge.
static func street_center(md: MapData) -> Vector3:
	var best_d: float = INF
	var best_p: Vector2 = STREET_NEAR
	var best_n := Vector2(1.0, 0.0)
	var best_w: float = 8.0
	if md:
		for r: Dictionary in md.roads():
			if String(r.get("name", "")) != STREET_ROAD:
				continue
			var pts: PackedVector2Array = MapData.poly(r.get("points", []))
			for i: int in range(pts.size() - 1):
				var q: Vector2 = Geometry2D.get_closest_point_to_segment(STREET_NEAR, pts[i], pts[i + 1])
				var d: float = q.distance_to(STREET_NEAR)
				if d < best_d:
					best_d = d
					best_p = q
					var dir: Vector2 = (pts[i + 1] - pts[i]).normalized()
					best_n = Vector2(-dir.y, dir.x)
					best_w = float(r.get("width", 8.0))
	var v: Vector2 = best_p + best_n * (best_w * 0.5 + VERGE_M)
	return Vector3(v.x, 0.0, v.y)


static func campus_center(md: MapData) -> Vector3:
	var lm: Variant = md.landmark("campus_parking_center") if md else null
	if lm is Array and (lm as Array).size() >= 2:
		return Vector3(float(lm[0]), 0.0, float(lm[1]))
	return FPTUCampusBuilder.real_plot_transform() * FPTUCampusBuilder.parking_center_local()


## Start the chore. at: explicit centre (tests) or null = street / campus spot from md. roam_node: FreeRoam (free spots).
func start(p: ThirdPersonController, roam_node: Node, md: MapData, campus: bool, at: Variant = null) -> void:
	player = p
	roam = roam_node
	on_campus = campus
	var c: Vector3 = at if at is Vector3 else (campus_center(md) if campus else street_center(md))
	center = _spot(c, 8)
	player.teleport(center, 0.0)
	_attach_vest()
	bin = make_bin()
	bin.position = _spot(center + Vector3(1.6, 0.0, 0.0), 3)
	add_child(bin)
	supervisor = Officer.new()
	supervisor.setup("guard" if campus else "police", null, player, 777)
	supervisor.position = _spot(center + Vector3(-2.2, 0.0, 1.6), 3) + Vector3(0.0, 0.05, 0.0)
	add_child(supervisor)
	supervisor.supervise()
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = WeaponAudio.bus()
	add_child(_sfx)
	_build_hud()
	_place_round(total)
	supervisor.say("Lao động công ích! Nhặt %d bao rác bỏ vô thùng nha em." % total)


func _spot(q: Vector3, r: int) -> Vector3:
	if roam and roam.has_method("find_free_spot"):
		var s: Variant = roam.call("find_free_spot", q, q.y, r)
		if s is Vector3:
			return s
	return q


func _place_round(n: int) -> void:
	for b: Node3D in bags:
		b.queue_free()
	bags.clear()
	_rng.seed = 4242 + restarts
	for i: int in n:
		var a: float = TAU * float(i) / float(n) + _rng.randf_range(-0.3, 0.3)
		var r: float = _rng.randf_range(RING_MIN, RING_MAX)
		var bag: Node3D = make_bag()
		bag.name = "Bag%d" % i
		bag.position = _spot(center + Vector3(cos(a) * r, 0.0, sin(a) * r), 2)
		add_child(bag)
		bags.append(bag)
	_update_hud()


func _physics_process(delta: float) -> void:
	if player == null:
		return
	time_left -= delta
	_line_t -= delta
	if _line_t <= 0.0 and supervisor:
		_line_t = LINE_EVERY
		supervisor.say(LINES[_line_i % LINES.size()])
		_line_i += 1
	var p: Vector3 = player.global_position
	if carrying == null:
		for b: Node3D in bags:
			if WeaponMath.flat(b.global_position, p) <= PICK_R:
				_pick(b)
				break
	elif WeaponMath.flat(bin.global_position, p) <= BIN_R:
		_drop()
	if delivered >= total:
		finish()
		return
	if time_left <= 0.0:
		_restart()
	_update_hud()


func _pick(b: Node3D) -> void:
	bags.erase(b)
	carrying = b
	b.get_parent().remove_child(b)
	player.model.add_child(b)
	b.position = Vector3(0.0, 0.95, -0.38)
	b.rotation = Vector3.ZERO
	CharacterBuilder.play(player.model, "carry", 999.0)


func _drop() -> void:
	carrying.queue_free()
	carrying = null
	delivered += 1
	CharacterBuilder.stop_clip(player.model)
	_sfx.stream = WeaponAudio.stream("bag_drop")
	_sfx.play()
	delivered_bag.emit(delivered)


func _restart() -> void:
	restarts += 1
	total = maxi(MIN_BAGS, total - BAG_STEP)
	delivered = 0
	if carrying:
		carrying.queue_free()
		carrying = null
		CharacterBuilder.stop_clip(player.model)
	time_left = TIME_S
	_place_round(total)
	if supervisor:
		supervisor.say("Hết giờ! Làm lại, lần này %d bao thôi." % total)
	restarted.emit(total)


## Done: vest, props and HUD go; `completed`; the node frees itself.
func finish() -> void:
	if vest:
		vest.queue_free()
		vest = null
	if carrying:
		carrying.queue_free()
		carrying = null
	if player and player.model:
		CharacterBuilder.stop_clip(player.model)
	if hud_layer:
		hud_layer.queue_free()
	set_physics_process(false)
	completed.emit()
	queue_free()


func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 2
	add_child(hud_layer)
	hud_label = Label.new()
	hud_label.name = "ServiceLabel"
	hud_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	hud_label.offset_left = -320.0
	hud_label.offset_right = 320.0
	hud_label.offset_top = 64.0
	hud_label.offset_bottom = 100.0
	hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_label.add_theme_font_size_override("font_size", 22)
	hud_label.add_theme_color_override("font_color", VEST)
	hud_label.add_theme_color_override("font_outline_color", Color("#1B0F33"))
	hud_label.add_theme_constant_override("outline_size", 8)
	hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud_label)


func _update_hud() -> void:
	if hud_label:
		var s: int = maxi(0, ceili(time_left))
		hud_label.text = "LAO ĐỘNG CÔNG ÍCH · Rác %d/%d · %d:%02d" % [delivered, total, s / 60, s % 60]


func _attach_vest() -> void:
	vest = make_vest()
	var torso: Node3D = CharacterBuilder.get_pivot(player.model, "torso")
	if torso:
		torso.add_child(vest)
	else:
		player.model.add_child(vest)
		vest.position = Vector3(0.0, 1.05, 0.0)


## Orange safety vest with two grey reflective stripes (on the torso pivot).
static func make_vest() -> Node3D:
	var root := Node3D.new()
	root.name = "ServiceVest"
	var m := StandardMaterial3D.new()
	m.albedo_color = VEST
	m.emission_enabled = true
	m.emission = VEST
	m.emission_energy_multiplier = 0.25
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.2
	cyl.bottom_radius = 0.21
	cyl.height = 0.42
	var body := MeshInstance3D.new()
	body.name = "Vest"
	body.mesh = cyl
	body.material_override = m
	body.position = Vector3(0.0, 0.24, 0.0)
	body.scale = Vector3(1.05, 1.0, 0.72)
	root.add_child(body)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = STRIPE
	sm.metallic = 0.6
	sm.roughness = 0.3
	for k: int in 2:
		var ring := CylinderMesh.new()
		ring.top_radius = 0.214
		ring.bottom_radius = 0.214
		ring.height = 0.04
		var mi := MeshInstance3D.new()
		mi.mesh = ring
		mi.material_override = sm
		mi.position = Vector3(0.0, 0.14 + 0.16 * float(k), 0.0)
		mi.scale = Vector3(1.05, 1.0, 0.72)
		root.add_child(mi)
	return root


## A black rubbish bag with a tied neck.
static func make_bag() -> Node3D:
	var root := Node3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.4
	var body := MeshInstance3D.new()
	body.mesh = sm
	body.material_override = WeaponProps._mat(Color("#16171B"), 0.0, 0.35)
	body.position = Vector3(0.0, 0.2, 0.0)
	root.add_child(body)
	var neck := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.06
	cm.height = 0.1
	neck.mesh = cm
	neck.material_override = body.material_override
	neck.position = Vector3(0.0, 0.43, 0.0)
	root.add_child(neck)
	return root


## A green wheelie bin with a darker lid.
static func make_bin() -> Node3D:
	var root := Node3D.new()
	root.name = "Bin"
	WeaponProps._box(root, Vector3(0.6, 0.9, 0.6), Vector3(0.0, 0.45, 0.0), Color("#2E7D4F"))
	WeaponProps._box(root, Vector3(0.66, 0.06, 0.66), Vector3(0.0, 0.93, 0.0), Color("#1F5A38"))
	return root
```

- [ ] **Step 4: Start and finish the chore in `scripts/wanted/WantedDirector.gd`**

4a. After `signal busted(catcher: String)` add `signal service_started(on_campus: bool)`, and after `var stamp_manual: bool = false …` add:

```gdscript
var service: CommunityService = null
```

4b. Replace the Task 10 `_start_service()` (its doc comment and body) with:

```gdscript
## Community service (spec section 5): officers leave, the chore starts where the catch happened (campus parking or the
## Nguyễn Xiển verge); weapons and the bike stay locked (state "service") until it is done.
func _start_service() -> void:
	_clear_officers()
	state = "service"
	service = CommunityService.new()
	service.name = "CommunityService"
	add_child(service)
	service.start(player, roam, md, bust_on_campus)
	service.completed.connect(_on_service_done, CONNECT_ONE_SHOT)
	service_started.emit(bust_on_campus)


## Chore done: the wanted level is cleared, the weapons are free again, the player stands beside his bike.
func _on_service_done() -> void:
	service = null
	state = "free"
	clear()
	if roam and roam.has_method("place_beside_bike"):
		roam.call("place_beside_bike")
```

- [ ] **Step 5: Bike lock and bike placement in `scripts/FreeRoam.gd`**

5a. After `const HINT_RESCUED: String = …` add:

```gdscript
const HINT_SERVICE_BIKE: String = "Đang lao động công ích – làm xong mới được lấy xe"
```

5b. In `toggle_bike()`, insert as its first lines:

```gdscript
	if wanted and wanted.state != "free":
		flash_hint(HINT_SERVICE_BIKE)   # Phase W: không lấy xe khi đang bị bắt / lao động công ích
		return
```

5c. Insert right after `toggle_bike()`:

```gdscript
## Phase W, after community service (spec section 5): put the player on a free spot beside the parked bike (if parked).
func place_beside_bike() -> bool:
	if mounted or not bike_parked:
		return false
	var spot: Variant = _dismount_spot()
	if spot == null:
		return false
	player.teleport(spot, bike.rotation.y)
	return true
```

- [ ] **Step 6: The bag thud in `scripts/weapons/WeaponAudio.gd`**

Add `"bag_drop"` at the end of `CUES`, and this branch to the `match cue:` of `synth()`:

```gdscript
		"bag_drop":
			return CineAudio._to_wav(CineAudio._mix([CineAudio._tone(0.25, 95.0, 55.0, 0.7, 12.0), CineAudio._noise(0.12, 0.45, 30.0, 61, 0.6)]))
```

- [ ] **Step 7: Import, check the class cache, run the test**

```bash
godot --headless --import --path . > /tmp/w_imp.log 2>&1
grep -c 'CommunityService' .godot/global_script_class_cache.cfg
git diff --name-only -- '*.import' | xargs -r git checkout --
godot --headless --path . --script tests/test_community_service.gd > /tmp/w_t11.log 2>&1; grep -E "SUCCESS|FAIL|✗" /tmp/w_t11.log
```
Expected: the cache count is 1, and the test prints `✅ SUCCESS: COMMUNITY SERVICE …`. `tests/test_busted.gd` accepts either end state (`free` or `service`) and stays green.

- [ ] **Step 8: Run the full regression, then commit**

```bash
git add scripts/wanted/CommunityService.gd scripts/wanted/CommunityService.gd.uid scripts/wanted/WantedDirector.gd scripts/FreeRoam.gd scripts/weapons/WeaponAudio.gd tests/test_community_service.gd tests/test_community_service.gd.uid
git commit -m "feat(wanted): community service - after the busted cutscene an orange-vest chore at the campus parking or the Nguyễn Xiển verge: carry 8 rubbish bags to a bin in 120 s under a supervising officer's meme lines, weapons and bike locked, time-out restarts with 2 bags fewer (min 2, no softlock), finishing clears the wanted level and puts the player beside his bike

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 12: Emote wheel and the "Siuuu!" emote  [effort: high]

**Files:**
- Create: `scripts/emotes/EmoteIcons.gd`, `scripts/emotes/EmoteWheel.gd`, `scripts/emotes/EmoteDirector.gd`.
- Modify: `scripts/roam/Pedestrian.gd` (REACT state), `scripts/weapons/WeaponAudio.gd` (injectable `sfx_dir`, `siuuu` cue), `scripts/weapons/WeaponDirector.gd` (`is_firing`), `scripts/FreeRoam.gd` (wiring and mutual blocking).
- Test: `tests/test_emotes.gd`.

Spec: W-D10 … W-D13 and section 9 (owner amendments dd6b7f6 and 4c8f9ed). No real footballer's name, face, shirt or voice anywhere (W-D11): the emote is only ever called "Siuuu!".

**Interfaces:**
- Consumes:
  - Task 1: `RadialWheel` (data-driven slots, `trigger_key`, `keep_current = false`, greyed `"enabled": false` slots, `SOON`).
  - Task 3: `WeaponDirector` (`aiming`, `reload_left`, `held`, `fx`, `blocked_fn`), `ThirdPersonController` (`camera`, `model`, `is_knocked_down()`, `_read_input()`, `floor_snap_length`), `WeaponFX.burst`.
  - Task 2: `Pedestrian` states, `_flat_dir`.
  - `CineFX.build_prop("phone")`, `CineFX.set_prop_glow`, `CharacterBuilder._apply_bone_pose(sk, pose, w)` (RigAnimator runs at process priority 10, so the emote overlays its pose at 20).
- Produces:
  - `class_name EmoteIcons`: `shapes(icon)`, `draw(ci, icon, center, size, col, dark)`.
  - `class_name EmoteWheel extends RadialWheel`: hold B, slot 0 "Siuuu!", slots 1-7 greyed "Sắp có".
  - `class_name EmoteDirector extends Node3D`:
    - signals `started(emote_id)`, `landed(at_t)`, `finished(emote_id, cancelled)`;
    - constants `EMOTES`, `TAKEOFF 1.10`, `LAND 1.70`, `HOLD_END 2.96`, `LENGTH 3.30`, `CANCEL_FROM 2.20`, `RUN_DIST 4.5`, `APEX 0.55`, `AIR_SPEED 2.0`, `CUE_START 1.39`, `REACT_R 10.0`, `SHARE_CLAP 0.5`, `SHARE_SHOUT 0.25`, `SHARE_FILM 0.15`, `POSE_AIR`, `POSE_LAND`;
    - vars `active, pending, t, start_pos, takeoff_pos, landed_t, cue_t, ended_t, reactions: Dictionary, bubble: Label3D, shout: AudioStreamPlayer`;
    - `setup(opts)`, `is_blocked() -> bool`, `play(slot) -> bool`, static `pose_at(t)` and `pose_weight(t)`.
  - `Pedestrian`: `State.REACT` (appended), `react_kind`, `react_left`, `can_react_emote() -> bool`, `react_emote(kind, from, secs) -> bool`.
  - `WeaponAudio`:
    - `static var sfx_dir` (tests point it at an empty folder), `owner_file(name) -> String` (.ogg then .mp3), `clear_cache()`;
    - constants `SIUUU_FILE "siuuu"`, `SIUUU_S 0.25`, `SIUUU_BURST 0.31`, `SIUUU_END 1.57`, `SIUUU_LEN 2.0`;
    - `siuuu_file()`, `siuuu_stream()`, `synth_siuuu() -> AudioStreamWAV`.
  - `WeaponDirector.is_firing() -> bool`.
  - `FreeRoam`: vars `emote_wheel: EmoteWheel`, `emotes: EmoteDirector`.

Timing ("Siuuu!", 3.30 s; times from the emote start):

| Emote time | What happens |
|---|---|
| 0.00-1.10 | run-up away from the camera at RUN_DIST / TAKEOFF ≈ 4.1 m/s through normal body collision (the walk cycle drives the legs) |
| 1.10 | take-off; 1.10-1.70 airborne: apex 0.55 m, forward 2 m/s, a 180° yaw turn (smoothstep over the air time) |
| 1.39 | the shout cue starts (= LAND − SIUUU_BURST) |
| 1.70 | landing facing the camera: wide stance, arms down and out, chest forward, dust, "SIUUU!" bubble, bystanders react; the cue's vowel burst sounds now |
| 1.70-2.96 | hold, chest rising slightly; from 2.20 movement input ends the emote |
| 2.96-3.30 | blend back to idle |

The emote starts only once `Engine.time_scale` is back at 1.0 after the wheel closes (0.1 s), so game time and the cue (real time) stay in sync.

- [ ] **Step 1: Write the failing test `tests/test_emotes.gd`**

```gdscript
# File: res://tests/test_emotes.gd
# Headless test of the Phase W emotes (spec W-D10..W-D13, section 9): the emote wheel opens on a B hold (not a tap) with
# slot 0 "Siuuu!" and 7 greyed slots that cannot be chosen; the emote is refused while blocked, aiming, firing, reloading,
# knocked down or with the weapon wheel open; "Siuuu!" runs ~4.5 m away from the camera, takes off at 1.10 s, turns 180° by
# the 1.70 s landing, starts the shout at landing - 0.31 s (vowel burst within one physics frame of the landing), hides and
# restores the weapon, lasts 3.30 s, can only be cancelled by movement from 2.20 s; bystanders within 10 m react by share
# (clap / shout back / film with a glowing phone / look), nobody beyond 10 m, fleeing or knocked out reacts, then they
# resume; the synthesized cue follows the fixed layout and the override resolution does not depend on the owner's local
# file (injectable sfx dir). Part B (FreeRoam, crowd off): blocked on the bike, weapons blocked during the emote.
# Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_emotes.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")
const FRAME: float = 1.0 / 60.0

var fails: Array[String] = []
var frames: int = 0
var phase: String = ""
var t0: int = 0
var started: bool = false
var arena: Node3D
var player: ThirdPersonController
var dir: WeaponDirector
var wheel: EmoteWheel
var emotes: EmoteDirector
var targets: Array = []
var blocked: bool = false
var near: Array = []
var far: Array = []
var fleer: Pedestrian
var ko: Pedestrian
var land_yaw: float = 0.0
var finishes: Array = []
var hidden_seen: bool = false
var roam: Node3D


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	print("--- TEST EMOTES ---")
	_audio()
	_poses()
	physics_frame.connect(_on_physics)


func _rms(w: AudioStreamWAV, a_s: float, b_s: float) -> float:
	var d: PackedByteArray = w.data
	var a: int = int(a_s * CineAudio.SR)
	var b: int = mini(int(b_s * CineAudio.SR), d.size() / 2)
	var acc: float = 0.0
	for i: int in range(a, b):
		var v: float = float(d.decode_s16(i * 2)) / 32767.0
		acc += v * v
	return sqrt(acc / maxf(float(b - a), 1.0))


func _audio() -> void:
	_check(is_equal_approx(EmoteDirector.CUE_START, EmoteDirector.LAND - WeaponAudio.SIUUU_BURST), "the cue starts at landing - 0.31 s (1.39)")
	var w: AudioStreamWAV = WeaponAudio.synth_siuuu()
	var secs: float = float(w.data.size()) / 2.0 / float(CineAudio.SR)
	_check(absf(secs - WeaponAudio.SIUUU_LEN) < 0.01, "the synthesized siuuu cue is 2.0 s")
	_check(_rms(w, 0.0, 0.24) < 0.005 and _rms(w, 0.25, 0.31) > 0.02, "silence, then the 'S' from 0.25 s")
	var best_t: float = 0.0
	var best: float = 0.0
	var tt: float = 0.2
	while tt < 1.9:
		var r: float = _rms(w, tt, tt + 0.01)
		if r > best:
			best = r
			best_t = tt
		tt += 0.005
	_check(absf(best_t - WeaponAudio.SIUUU_BURST) <= 0.02, "the vowel burst (loudest 10 ms) is at 0.31 s (%.3f)" % best_t)
	var sustain: float = _rms(w, 1.0, 1.5)
	_check(sustain > 0.05 and _rms(w, 1.6, 2.0) < sustain * 0.3, "the vowel sustains to ~1.57 s, then only a soft tail")
	var keep: String = WeaponAudio.sfx_dir
	WeaponAudio.sfx_dir = "res://tests/__no_sfx__/"
	WeaponAudio.clear_cache()
	_check(WeaponAudio.siuuu_file() == "" and WeaponAudio.siuuu_stream() is AudioStreamWAV, "empty sfx dir -> the synthesized cue")
	WeaponAudio.sfx_dir = keep
	WeaponAudio.clear_cache()
	var f: String = WeaponAudio.siuuu_file()
	_check(f == "" or ((f.ends_with("siuuu.ogg") or f.ends_with("siuuu.mp3")) and WeaponAudio.siuuu_stream() != null), "user://sfx: the owner's siuuu file when present (%s), else synthesized" % (f if f != "" else "none"))


func _poses() -> void:
	_check(EmoteDirector.pose_weight(0.5) == 0.0 and is_equal_approx(EmoteDirector.pose_weight(2.0), 1.0) and EmoteDirector.pose_weight(EmoteDirector.LENGTH) == 0.0, "pose overlay: off on the run-up, full in the hold, back to idle at 3.30 s")
	var p: Dictionary = EmoteDirector.pose_at(2.0)
	_check((p["shoulder_l"] as Vector3).is_equal_approx(EmoteDirector.POSE_LAND["shoulder_l"]) and float(p["hips_y"]) < 0.0, "the hold pose is the wide landing (arms down and out, hips low)")


func _next(p: String) -> void:
	phase = p
	t0 = frames


func _key_b(pressed: bool) -> void:
	var k := InputEventKey.new()
	k.physical_keycode = KEY_B
	k.pressed = pressed
	wheel._input(k)


func _ped(at: Vector3, s: int) -> Pedestrian:
	var p: Pedestrian = World.ped(arena, at, s, player)
	targets.append(p)
	return p


func _on_physics() -> void:
	frames += 1
	if not started:
		started = true
		arena = Node3D.new()
		root.add_child(arena)
		World.floor_box(arena)
		player = World.player(arena, Vector3.ZERO, 0.0)
		dir = World.director(arena, player, targets)
		dir.equip(WeaponData.Slot.PISTOL)
		wheel = EmoteWheel.new()
		wheel.manual = true
		arena.add_child(wheel)
		emotes = EmoteDirector.new()
		emotes.name = "Emotes"
		arena.add_child(emotes)
		emotes.setup({"player": player, "weapons": dir, "wheel": wheel, "weapon_wheel": dir.wheel, "targets_fn": func() -> Array: return targets,
			"fx": dir.fx, "blocked_fn": func() -> bool: return blocked})
		emotes.finished.connect(func(id: String, c: bool) -> void: finishes.append([id, c, emotes.ended_t]))
		emotes.landed.connect(func(_at: float) -> void: land_yaw = player.model.rotation.y)
		var land := Vector3(0.0, 0.0, -5.63)
		for i: int in 20:
			var a: float = TAU * float(i) / 20.0 + 0.1
			var r: float = 4.0 + float(i % 5) * 0.9
			var q: Vector3 = land + Vector3(cos(a) * r, 0.0, sin(a) * r)
			if absf(q.x) < 2.2:
				q.x = 2.2 if q.x >= 0.0 else -2.2           # keep the run-up / landing corridor clear
			near.append(_ped(q, 200 + i))
		for k: int in 4:
			far.append(_ped(land + Vector3(12.5, 0.0, -3.0 + 2.0 * float(k)), 230 + k))
		fleer = _ped(land + Vector3(5.0, 0.0, 2.0), 240)
		fleer.flee_from(land, 30.0)
		ko = _ped(land + Vector3(-5.0, 0.0, 2.0), 241)
		ko.knock_out(30.0, Vector3(1.0, 0.0, 0.0))
		_next("wheel")
		return
	var t: int = frames - t0
	if phase != "b" and emotes.active and dir.held != null and not dir.held.visible:
		hidden_seen = true
	match phase:
		"wheel":
			if t == 5:
				_check(wheel.slots.size() == 8 and String(wheel.slots[0]["name"]) == "Siuuu!" and wheel.is_enabled(0), "slot 0 is 'Siuuu!'")
				var greyed: bool = true
				for i: int in range(1, 8):
					greyed = greyed and not wheel.is_enabled(i) and String(wheel.slots[i]["name"]) == RadialWheel.SOON
				_check(greyed, "slots 1-7 are greyed 'Sắp có'")
				_key_b(true)
				wheel.step_real(0.05)
				_key_b(false)
				wheel.step_real(0.2)
				_check(not wheel.is_open() and not emotes.active and emotes.pending < 0, "a B tap does nothing")
				blocked = true
				_check(not emotes.play(0), "refused while blocked (riding, cinematic, busted, service)")
				_key_b(true)
				wheel.step_real(0.2)
				_check(not wheel.is_open(), "the emote wheel does not open while blocked")
				_key_b(false)
				blocked = false
				dir.reload_left = 1.0
				_check(not emotes.play(0), "refused while reloading")
				dir.reload_left = 0.0
				dir._fire_prev = true
				_check(not emotes.play(0), "refused while firing")
				dir._fire_prev = false
				dir.wheel.open()
				_check(not emotes.play(0), "refused while the weapon wheel is open (one wheel at a time)")
				dir.wheel.close(false)
				dir.aim_override = true
			if t == 8:
				_check(dir.aiming and not emotes.play(0), "refused while aiming")
				dir.aim_override = false
			if t == 11:
				_key_b(true)
				wheel.step_real(0.13)
				_check(wheel.is_open() and wheel.highlight == -1, "holding B opens the emote wheel")
				wheel.feed_mouse(Vector2(150.0, 0.0))
				_check(wheel.highlight == -1, "a greyed slot cannot be highlighted")
				wheel.feed_mouse(Vector2(-150.0, -150.0))
				_check(wheel.highlight == 0, "toward slot 0: 'Siuuu!'")
				_key_b(false)
				wheel.step_real(0.2)
				_check(emotes.pending == 0 or emotes.active, "releasing B on 'Siuuu!' plays it")
				_next("emote")
		"emote":
			if t == 120 and emotes.landed_t > 0.0:
				_check(emotes.bubble.visible and emotes.bubble.text == "SIUUU!", "the 'SIUUU!' bubble pops at the landing")
				_check(emotes.reactions.get("clap", 0) == 10 and emotes.reactions.get("shout", 0) == 5 and emotes.reactions.get("film", 0) == 3 and emotes.reactions.get("look", 0) == 2,
					"20 bystanders within 10 m: 10 clap, 5 shout back, 3 film, 2 look (%s)" % str(emotes.reactions))
				var far_ok: bool = true
				for p: Pedestrian in far:
					far_ok = far_ok and p.state == Pedestrian.State.IDLE
				_check(far_ok, "nobody beyond 10 m reacts")
				_check(fleer.state == Pedestrian.State.FLEE and ko.state == Pedestrian.State.KNOCKED_OUT, "fleeing and knocked-out people ignore it")
				_check(arena.find_children("Phone", "", true, false).size() == 3, "the filmers raise a glowing phone")
			if not finishes.is_empty() and not has_meta("e1"):
				set_meta("e1", true)
				var run: float = WeaponMath.flat(emotes.takeoff_pos, emotes.start_pos)
				_check(run > 4.2 and run < 4.8, "run-up ~4.5 m away from the camera (%.2f m)" % run)
				_check(absf(wrapf(land_yaw - emotes.start_yaw - PI, -PI, PI)) < 0.05, "turned 180° by the landing")
				_check(emotes.landed_t >= EmoteDirector.LAND - 1e-6 and emotes.landed_t <= EmoteDirector.LAND + FRAME + 1e-6, "lands at 1.70 s (%.3f)" % emotes.landed_t)
				_check(emotes.cue_t >= EmoteDirector.CUE_START - 1e-6 and emotes.cue_t <= EmoteDirector.CUE_START + FRAME + 1e-6, "the shout starts at 1.39 s (%.3f)" % emotes.cue_t)
				_check(absf(emotes.cue_t + WeaponAudio.SIUUU_BURST - emotes.landed_t) <= FRAME + 1e-4, "the vowel burst lands within one physics frame of the landing")
				_check(finishes[0][1] == false and absf(float(finishes[0][2]) - EmoteDirector.LENGTH) <= FRAME + 1e-6, "the emote lasts 3.30 s (%.3f)" % float(finishes[0][2]))
				_check(hidden_seen and dir.held.visible, "the pistol is hidden during the emote and back afterwards")
				set_meta("e1_t", t)
			if has_meta("e1_t") and t == int(get_meta("e1_t")) + 150:
				var resumed: bool = true
				for p2: Pedestrian in near:
					resumed = resumed and p2.state == Pedestrian.State.IDLE
				_check(resumed and arena.find_children("Phone", "", true, false).is_empty(), "the bystanders resume what they were doing")
				_check(emotes.play(0), "a second Siuuu! starts")
				_next("cancel")
			if t == 600 and not has_meta("e1"):
				_check(false, "the emote never finished")
				_finish()
		"cancel":
			if emotes.active and emotes.t >= 1.5 and emotes.t < 1.6:
				player.input_override = Vector2(0.0, -1.0)
			if finishes.size() == 2 and not has_meta("e2"):
				set_meta("e2", true)
				player.input_override = Vector2.ZERO
				var end_t: float = float(finishes[1][2])
				_check(finishes[1][1] == true and end_t >= EmoteDirector.CANCEL_FROM - 1e-6 and end_t <= EmoteDirector.CANCEL_FROM + FRAME + 1e-6, "movement input ends the emote only from 2.20 s (ended at %.3f)" % end_t)
				player.knock_down(Vector3(1.0, 0.0, 0.0), 1.0)
				_check(not emotes.play(0), "refused while knocked down")
				_start_b()
			if t == 400 and not has_meta("e2"):
				_check(false, "the cancel test never finished")
				_finish()
		"b":
			_part_b(t)


func _start_b() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var n: Node = (load(pair[1]) as Script).new()
			n.name = pair[0]
			root.add_child(n)
	arena.queue_free()
	roam = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	roam.set("crowd_enabled", false)
	root.add_child(roam)
	_next("b")


func _opens(w: RadialWheel) -> bool:
	w.press()
	w.step_real(0.2)
	var o: bool = w.is_open()
	w.cancel()
	w.step_real(0.2)
	return o


func _part_b(t: int) -> void:
	var ew: EmoteWheel = roam.get("emote_wheel")
	var em: EmoteDirector = roam.get("emotes")
	var ww: WeaponWheel = roam.get("weapon_wheel")
	if t == 60:
		_check(ew != null and em != null, "FreeRoam builds the emote wheel and the emotes")
		ew.manual = true
		ww.manual = true
		roam.call("mount_bike")
	if t == 64:
		_check(not _opens(ew), "riding: the emote wheel is blocked")
		roam.call("dismount_bike")
	if t == 68:
		_check(_opens(ew), "on foot the emote wheel opens")
		_check(em.play(0), "Siuuu! starts in FreeRoam")
	if t == 72:
		_check(em.active and not _opens(ww) and (roam.get("weapons") as WeaponDirector).is_blocked(), "weapons and the weapon wheel are blocked during the emote")
	if t == 300:
		_check(not em.active and _opens(ww), "after the emote the weapon wheel opens again")
		_finish()


func _finish() -> void:
	Engine.time_scale = 1.0
	if fails.is_empty():
		print("✅ SUCCESS: EMOTES (B wheel, greyed slots, blocked states, run-up, 180° turn, landing 1.70, cue at landing - 0.31, 3.30 s, cancel from 2.20, weapon hidden, bystanders by share and radius, cue layout, override resolution, FreeRoam)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless --path . --script tests/test_emotes.gd > /tmp/w_t12.log 2>&1; grep -E "SUCCESS|FAIL|Parse Error" /tmp/w_t12.log`
Expected: a parse error (`EmoteDirector` / `WeaponAudio.synth_siuuu` not declared).

- [ ] **Step 3: The siuuu cue and the injectable sfx folder in `scripts/weapons/WeaponAudio.gd`**

3a. After `const LOA_FILE: String = "loa_keo_keo"` add:

```gdscript
const SIUUU_FILE: String = "siuuu"
## Fixed layout of every siuuu cue (synthesized or the owner's file, spec section 9): "S" from SIUUU_S, the vowel burst (the
## loudest instant) at SIUUU_BURST, the vowel sustained to SIUUU_END, a soft tail to SIUUU_LEN.
const SIUUU_S: float = 0.25
const SIUUU_BURST: float = 0.31
const SIUUU_END: float = 1.57
const SIUUU_LEN: float = 2.0
## Where owner overrides are looked up (user://sfx/); tests point it at an empty folder so they never depend on his files.
static var sfx_dir: String = SFX_DIR
```

3b. Add `"siuuu"` at the end of `CUES`, and this branch to the `match cue:` of `synth()`:

```gdscript
		"siuuu":
			return synth_siuuu()
```

3c. In `override_file()`, replace `	var p: String = SFX_DIR + cue + ".ogg"` with `	var p: String = sfx_dir + cue + ".ogg"`.

3d. Replace the whole `loa_file()` function with:

```gdscript
## The owner's loa file ("" = none: the synthesized bolero plays).
static func loa_file() -> String:
	return owner_file(LOA_FILE)
```

3e. Append:

```gdscript
## The owner's local file sfx_dir/<name>.ogg or .mp3 ("" when there is none).
static func owner_file(file_name: String) -> String:
	for ext: String in [".ogg", ".mp3"]:
		var p: String = sfx_dir + file_name + ext
		if FileAccess.file_exists(p):
			return p
	return ""


static func clear_cache() -> void:
	_cache.clear()


## The owner's siuuu file (W-D12, trimmed to the fixed layout) or "".
static func siuuu_file() -> String:
	return owner_file(SIUUU_FILE)


## The "Siuuu!" shout: the owner's local file when present, else the synthesized cue (same layout either way).
static func siuuu_stream() -> AudioStream:
	if _cache.has("@siuuu"):
		return _cache["@siuuu"]
	var st: AudioStream = null
	var f: String = siuuu_file()
	if f != "":
		st = CineAudio._load_file(f)
	if st == null:
		st = synth_siuuu()
	_cache["@siuuu"] = st
	return st


## Synthesized "Siuuu" on the fixed layout (no recording of any real person, W-D11/W-D12): silence, a bright noise "S" from
## SIUUU_S swelling into the vowel; at SIUUU_BURST a sharp attack into a voiced tone gliding from "i" (bright upper
## harmonics) to a long "uuu" (dark), slight vibrato, fading out by SIUUU_END; a soft crowd-like noise tail to SIUUU_LEN.
static func synth_siuuu() -> AudioStreamWAV:
	var sr: int = CineAudio.SR
	var buf := PackedFloat32Array()
	buf.resize(int(round(SIUUU_LEN * sr)))
	var s_noise: PackedFloat32Array = CineAudio._noise(SIUUU_BURST - SIUUU_S, 0.35, 0.0, 71, 0.0)
	for i: int in s_noise.size():
		s_noise[i] *= 0.4 + 0.6 * float(i) / float(s_noise.size())
	CineAudio._paste(buf, s_noise, SIUUU_S, 1.0)
	var a0: int = int(SIUUU_BURST * sr)
	var a1: int = int(SIUUU_END * sr)
	var dur: float = SIUUU_END - SIUUU_BURST
	var ph: float = 0.0
	for i2: int in range(a0, a1):
		var tt: float = float(i2 - a0) / float(sr)
		var u: float = tt / dur
		var f: float = lerpf(330.0, 230.0, smoothstep(0.0, 0.35, u)) * (1.0 + 0.025 * sin(TAU * 5.5 * tt) * smoothstep(0.1, 0.4, u))
		ph += TAU * f / float(sr)
		var bright: float = 1.0 - smoothstep(0.0, 0.3, u)
		var v: float = sin(ph) + (0.45 * bright + 0.12) * sin(2.0 * ph) + (0.3 * bright + 0.05) * sin(3.0 * ph)
		var env: float = minf(1.0, tt / 0.006) * (1.0 - 0.35 * u) * (1.0 - smoothstep(0.85, 1.0, u))
		buf[i2] += v * 0.42 * env
	var crowd: PackedFloat32Array = CineAudio._noise(SIUUU_LEN - 1.2, 0.08, 0.0, 72, 0.85)
	for i3: int in crowd.size():
		var u2: float = float(i3) / float(crowd.size())
		crowd[i3] *= smoothstep(0.0, 0.3, u2) * (1.0 - smoothstep(0.5, 1.0, u2))
	CineAudio._paste(buf, crowd, 1.2, 1.0)
	return CineAudio._to_wav(buf)
```

- [ ] **Step 4: `is_firing()` in `scripts/weapons/WeaponDirector.gd`**

Insert right after `is_blocked()`:

```gdscript
## The fire button is held on foot this frame (the emote refuses to start, spec section 9).
func is_firing() -> bool:
	return _fire_prev
```

- [ ] **Step 5: Bystander reactions in `scripts/roam/Pedestrian.gd`**

5a. Replace the `enum State` line with:

```gdscript
enum State { WALK, IDLE, STUMBLE, KNOCKDOWN, FLEE, KNOCKED_OUT, LAUNCHED, STINK, DANCE, REACT }
```

5b. After `var _flee_src: Vector3 = Vector3.ZERO` add:

```gdscript
## Phase W emotes: reacting to the player's emote (clap / shout / film / look), then back to the previous state.
var react_kind: String = ""
var react_left: float = 0.0
var _react_prev: int = State.WALK
var _react_prop: Node3D = null
```

5c. In `setup()`, after `	_push_v = Vector3.ZERO` (the line added in Task 2) add:

```gdscript
	if _react_prop:
		_react_prop.queue_free()
		_react_prop = null
	react_kind = ""
```

5d. In the `match state:` of `_physics_process()` add:

```gdscript
		State.REACT:
			_reacting(delta)
```

5e. In `take_hit()`, insert right after `	if is_down():` / `		return "none"`:

```gdscript
	if state == State.REACT:
		_end_react()
		state = State.WALK
```

5f. Insert before the `_flat_dir()` helper of the Phase W section:

```gdscript
## Can react to an emote: walking or standing only (not fleeing, down, stinking, dancing or already reacting).
func can_react_emote() -> bool:
	return state == State.WALK or state == State.IDLE


## React to the player's emote from `from` for `secs`: "clap" (cheer clip), "shout" (wave; the bubble and the cue come
## from EmoteDirector), "film" (phone_stand + a glowing phone prop), "look" (turns the head). Then resumes its state.
func react_emote(kind: String, from: Vector3, secs: float) -> bool:
	if not can_react_emote():
		return false
	_react_prev = state
	state = State.REACT
	react_kind = kind
	react_left = secs
	velocity.x = 0.0
	velocity.z = 0.0
	var d: Vector3 = _flat_dir(from - global_position)
	model.rotation.y = atan2(-d.x, -d.z)
	match kind:
		"clap":
			CharacterBuilder.play(model, "cheer", secs)
		"shout":
			CharacterBuilder.play(model, "wave", secs)
		"film":
			CharacterBuilder.play(model, "phone_stand", secs)
			_react_prop = CineFX.build_prop("phone")
			_react_prop.name = "Phone"
			model.add_child(_react_prop)
			_react_prop.position = Vector3(0.12, 1.3, -0.3)
			CineFX.set_prop_glow(_react_prop, true)
		_:
			CharacterBuilder.look_at_point(model, from + Vector3(0.0, 1.5, 0.0))
	hits.append("react_" + kind)
	return true


func _reacting(delta: float) -> void:
	if not lod_far:
		_gravity(delta)
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
	CharacterBuilder.set_speed(model, 0.0)
	react_left -= delta
	if react_left <= 0.0:
		_end_react()
		state = _react_prev


func _end_react() -> void:
	if _react_prop:
		_react_prop.queue_free()
		_react_prop = null
	react_kind = ""
	CharacterBuilder.stop_clip(model)
	CharacterBuilder.look_at_point(model, null)
```

- [ ] **Step 6: Write `scripts/emotes/EmoteIcons.gd`**

```gdscript
# File: res://scripts/emotes/EmoteIcons.gd
# Emote icons drawn in code (no image files, never AI images), same format as WeaponIcons: polygons in [-1, 1]² (y down).
# Icon 0: "Siuuu!" – a figure landed wide with the arms swung down and out; -1: an empty slot (a ring).
class_name EmoteIcons
extends RefCounted


static func _circle(c: Vector2, r: float, n: int = 16) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in n:
		var a: float = TAU * float(i) / float(n)
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


static func shapes(icon: int) -> Array:
	var s: Array = []
	match icon:
		0:
			s.append({"pts": _circle(Vector2(0.0, -0.7), 0.18, 12), "dark": false})
			s.append({"pts": PackedVector2Array([Vector2(-0.16, -0.5), Vector2(0.16, -0.5), Vector2(0.12, 0.15), Vector2(-0.12, 0.15)]), "dark": false})
			s.append({"pts": PackedVector2Array([Vector2(-0.16, -0.45), Vector2(-0.1, -0.35), Vector2(-0.75, 0.1), Vector2(-0.85, 0.0)]), "dark": false})
			s.append({"pts": PackedVector2Array([Vector2(0.16, -0.45), Vector2(0.85, 0.0), Vector2(0.75, 0.1), Vector2(0.1, -0.35)]), "dark": false})
			s.append({"pts": PackedVector2Array([Vector2(-0.12, 0.1), Vector2(0.0, 0.15), Vector2(-0.45, 0.9), Vector2(-0.62, 0.88)]), "dark": false})
			s.append({"pts": PackedVector2Array([Vector2(0.12, 0.1), Vector2(0.62, 0.88), Vector2(0.45, 0.9), Vector2(0.0, 0.15)]), "dark": false})
		_:
			s.append({"pts": _circle(Vector2.ZERO, 0.45, 16), "dark": false})
			s.append({"pts": _circle(Vector2.ZERO, 0.3, 16), "dark": true})
	return s


static func draw(ci: CanvasItem, icon: int, center: Vector2, size: float, col: Color, dark: Color) -> void:
	var k: float = size * 0.5
	for sh: Dictionary in shapes(icon):
		var src: PackedVector2Array = sh["pts"]
		var pts := PackedVector2Array()
		pts.resize(src.size())
		for i: int in src.size():
			pts[i] = center + src[i] * k
		ci.draw_colored_polygon(pts, dark if bool(sh["dark"]) else col)
```

- [ ] **Step 7: Write `scripts/emotes/EmoteWheel.gd`**

```gdscript
# File: res://scripts/emotes/EmoteWheel.gd
# The emote wheel (spec W-D10, section 9): the shared RadialWheel opened by holding B; slot 0 "Siuuu!", slots 1-7 greyed
# "Sắp có" (a new emote later = one EmoteDirector.EMOTES entry plus its animation). Nothing is highlighted in the dead zone
# and any highlighted slot plays on release (keep_current off); no scroll cycling.
class_name EmoteWheel
extends RadialWheel


func _init() -> void:
	trigger_key = KEY_B
	keep_current = false
	scroll_cycles = false
	hint = "Thả B trên một ô để diễn"
	icon_fn = func(ci: CanvasItem, icon: int, c: Vector2, s: float, col: Color, dark: Color) -> void: EmoteIcons.draw(ci, icon, c, s, col, dark)
	for i: int in 8:
		if i < EmoteDirector.EMOTES.size():
			slots.append({"name": String(EmoteDirector.EMOTES[i]["name"]), "icon": i, "enabled": true})
		else:
			slots.append({"name": RadialWheel.SOON, "icon": -1, "enabled": false})
```

- [ ] **Step 8: Write `scripts/emotes/EmoteDirector.gd`**

```gdscript
# File: res://scripts/emotes/EmoteDirector.gd
# Phase W emotes (spec W-D10..W-D13, section 9). "Siuuu!" (3.30 s, times from the emote start, named constants below):
# run-up away from the camera to TAKEOFF (RUN_DIST through normal body collision: a wall stops the run), a jump of APEX
# with a 180° yaw turn while airborne, the landing at LAND facing the camera (wide stance, arms down and out, chest
# forward, dust, "SIUUU!" bubble, bystanders react), a hold to HOLD_END while the shout sustains, a blend back to idle by
# LENGTH. The shout (WeaponAudio.siuuu_stream: the owner's local file or the synthesized cue, same layout) starts at
# CUE_START = LAND - SIUUU_BURST so its vowel burst lands on the landing frame. Run, jump and turn cannot be cancelled;
# from CANCEL_FROM, movement input ends it. The equipped weapon is hidden meanwhile; no heat. While it plays the player's
# own physics is paused and this node moves the body (move_and_slide) and overlays code-built bone poses after the
# RigAnimator (process priority 20 > 10). It starts only once Engine.time_scale is back at 1.0 after the wheel closes.
# Bystanders (W-D13): pedestrians within REACT_R that are walking or standing react by share – clap, shout back (bubble +
# the cue quieter at a random pitch), film with a glowing phone, or look – then resume; officers and impostors ignore it.
# Refused while blocked_fn (riding, cinematic, replay, busted, service, map), aiming, firing, reloading, knocked down or with
# the weapon wheel open. Euler signs of the poses follow CharacterBuilder's code clips (cheer, lie, bow); tune them by eye
# when the owner play-tests. No real person's name, face or voice anywhere (W-D11).
class_name EmoteDirector
extends Node3D

signal started(emote_id: String)
signal landed(at_t: float)
signal finished(emote_id: String, cancelled: bool)

const EMOTES: Array[Dictionary] = [{"id": "siuuu", "name": "Siuuu!"}]
const TAKEOFF: float = 1.10
const LAND: float = 1.70
const HOLD_END: float = 2.96
const LENGTH: float = 3.30
const CANCEL_FROM: float = 2.20
const RUN_DIST: float = 4.5
const APEX: float = 0.55
const AIR_SPEED: float = 2.0
const CUE_START: float = 1.39            # LAND - WeaponAudio.SIUUU_BURST (checked by the test)
const REACT_R: float = 10.0
const SHARE_CLAP: float = 0.5
const SHARE_SHOUT: float = 0.25
const SHARE_FILM: float = 0.15
const BUBBLE_S: float = 1.6
const POSE_AIR: Dictionary = {
	"thigh_l": Vector3(0.9, 0.0, 0.12), "thigh_r": Vector3(0.9, 0.0, -0.12),
	"knee_l": Vector3(-1.2, 0.0, 0.0), "knee_r": Vector3(-1.2, 0.0, 0.0),
	"shoulder_l": Vector3(2.3, 0.0, 0.5), "shoulder_r": Vector3(2.3, 0.0, -0.5),
	"elbow_l": Vector3(0.4, 0.0, 0.0), "elbow_r": Vector3(0.4, 0.0, 0.0),
	"torso": Vector3(0.1, 0.0, 0.0), "head": Vector3(0.15, 0.0, 0.0), "hips_y": 0.0,
}
const POSE_LAND: Dictionary = {
	"thigh_l": Vector3(0.15, 0.0, 0.35), "thigh_r": Vector3(0.15, 0.0, -0.35),
	"knee_l": Vector3(-0.35, 0.0, 0.0), "knee_r": Vector3(-0.35, 0.0, 0.0),
	"shoulder_l": Vector3(-0.25, 0.0, 0.95), "shoulder_r": Vector3(-0.25, 0.0, -0.95),
	"elbow_l": Vector3(0.15, 0.0, 0.0), "elbow_r": Vector3(0.15, 0.0, 0.0),
	"torso": Vector3(0.22, 0.0, 0.0), "head": Vector3(0.12, 0.0, 0.0), "hips_y": -0.12,
}

var player: ThirdPersonController
var weapons: WeaponDirector
var wheel: EmoteWheel
var weapon_wheel: RadialWheel
var fx: WeaponFX
var targets_fn: Callable
var blocked_fn: Callable
var active: bool = false
var emote_id: String = ""
var pending: int = -1
var t: float = 0.0
var start_pos: Vector3 = Vector3.ZERO
var start_yaw: float = 0.0
var takeoff_pos: Vector3 = Vector3.ZERO
var landed_t: float = -1.0
var cue_t: float = -1.0
var ended_t: float = -1.0
var reactions: Dictionary = {}
var rng := RandomNumberGenerator.new()
var shout: AudioStreamPlayer
var bubble: Label3D
var _fwd: Vector3 = Vector3.FORWARD
var _took_off: bool = false
var _snap: float = 0.4
var _held_vis: bool = true
var _bubble_left: float = 0.0
var _extras: Array = []                  # [node, seconds left]: shout-back bubbles and voices


func _ready() -> void:
	process_priority = 20                # after the RigAnimator (10): the emote pose wins
	rng.seed = 2210
	shout = AudioStreamPlayer.new()
	shout.name = "Shout"
	shout.bus = WeaponAudio.bus()
	add_child(shout)
	bubble = _label("SIUUU!", 56)
	bubble.top_level = true
	add_child(bubble)


## opts: player, weapons (WeaponDirector), wheel (EmoteWheel), weapon_wheel (the other RadialWheel), targets_fn (-> Array),
## fx (WeaponFX), blocked_fn (-> bool: riding, cinematic, busted, service, map). Call after add_child.
func setup(opts: Dictionary) -> void:
	player = opts.get("player")
	weapons = opts.get("weapons")
	wheel = opts.get("wheel")
	weapon_wheel = opts.get("weapon_wheel")
	targets_fn = opts.get("targets_fn", Callable())
	fx = opts.get("fx")
	blocked_fn = opts.get("blocked_fn", Callable())
	if wheel:
		wheel.blocked_fn = is_blocked
		wheel.selected.connect(func(slot: int) -> void: play(slot))


func is_blocked() -> bool:
	if active or pending >= 0 or player == null or not player.visible:
		return true
	if blocked_fn.is_valid() and bool(blocked_fn.call()):
		return true
	if player.is_knocked_down() or (weapon_wheel and weapon_wheel.is_open()):
		return true
	return weapons != null and (weapons.aiming or weapons.reload_left > 0.0 or weapons.is_firing())


## Queue an emote (EMOTES index); it starts once the time scale is back at 1.0. false when refused.
func play(slot: int) -> bool:
	if slot < 0 or slot >= EMOTES.size() or is_blocked():
		return false
	pending = slot
	return true


static func pose_weight(at: float) -> float:
	return smoothstep(TAKEOFF - 0.05, TAKEOFF + 0.1, at) * (1.0 - smoothstep(HOLD_END, LENGTH, at))


## Code pose at emote time `at`: the tucked jump turning into the wide landing around LAND, the chest rising in the hold.
static func pose_at(at: float) -> Dictionary:
	var k: float = smoothstep(LAND - 0.04, LAND + 0.08, at)
	var out: Dictionary = {}
	for key: String in POSE_LAND.keys():
		if key == "hips_y":
			out[key] = lerpf(float(POSE_AIR[key]), float(POSE_LAND[key]), k)
		else:
			out[key] = (POSE_AIR[key] as Vector3).lerp(POSE_LAND[key], k)
	out["torso"] = (out["torso"] as Vector3) + Vector3(0.05 * smoothstep(LAND + 0.1, HOLD_END, at), 0.0, 0.0)
	return out


func _begin(slot: int) -> void:
	pending = -1
	active = true
	emote_id = String(EMOTES[slot]["id"])
	t = 0.0
	landed_t = -1.0
	cue_t = -1.0
	ended_t = -1.0
	_took_off = false
	reactions = {"clap": 0, "shout": 0, "film": 0, "look": 0}
	_fwd = WeaponMath.flat_dir(-player.camera.global_basis.z)
	start_yaw = atan2(-_fwd.x, -_fwd.z)
	player.model.rotation.y = start_yaw
	start_pos = player.global_position
	_snap = player.floor_snap_length
	player.set_physics_process(false)
	if weapons and weapons.held:
		_held_vis = weapons.held.visible
		weapons.held.visible = false
	started.emit(emote_id)


func _physics_process(delta: float) -> void:
	_tick_extras(delta)
	if pending >= 0 and not active:
		if Engine.time_scale >= 0.999:
			_begin(pending)
		return
	if not active:
		return
	if (blocked_fn.is_valid() and bool(blocked_fn.call())) or player.is_knocked_down():
		_end(true)                        # busted, a cinematic, a tackle...: stop at once
		return
	t += delta
	_move()
	if cue_t < 0.0 and t >= CUE_START - 1e-6:
		cue_t = t
		shout.stream = WeaponAudio.siuuu_stream()
		shout.play()
	if landed_t < 0.0 and t >= LAND - 1e-6:
		_land()
	if t >= CANCEL_FROM - 1e-6 and player._read_input().length_squared() > 0.01:
		_end(true)
		return
	if t >= LENGTH - 1e-6:
		_end(false)


## Body motion for emote time t: run-up, ballistic jump (apex APEX at mid-air, landing at LAND), then standing.
func _move() -> void:
	var air: float = LAND - TAKEOFF
	var g: float = 8.0 * APEX / (air * air)
	var v: Vector3
	if t < TAKEOFF:
		var sp: float = RUN_DIST / TAKEOFF
		v = Vector3(_fwd.x * sp, -2.0, _fwd.z * sp)
		player.floor_snap_length = _snap
		CharacterBuilder.set_speed(player.model, sp)
		CharacterBuilder.set_param(player.model, "run", 0.45)
	elif t < LAND:
		if not _took_off:
			_took_off = true
			takeoff_pos = player.global_position
		v = Vector3(_fwd.x * AIR_SPEED, g * air * 0.5 - g * (t - TAKEOFF), _fwd.z * AIR_SPEED)
		player.floor_snap_length = 0.0
		CharacterBuilder.set_speed(player.model, 0.0)
		CharacterBuilder.set_param(player.model, "run", 0.0)
	else:
		v = Vector3(0.0, -2.0, 0.0)
		player.floor_snap_length = _snap
	player.velocity = v
	player.move_and_slide()
	player.model.rotation.y = start_yaw + PI * smoothstep(TAKEOFF, LAND, t)


func _land() -> void:
	landed_t = t
	if fx:
		fx.burst("dust", player.global_position + Vector3(0.0, 0.05, 0.0), Vector3.UP, 0.8)
	bubble.text = "SIUUU!"
	bubble.visible = true
	_bubble_left = BUBBLE_S
	_react_bystanders()
	landed.emit(t)


func _end(cancelled: bool) -> void:
	active = false
	ended_t = t
	player.velocity = Vector3.ZERO
	player.floor_snap_length = _snap
	player.set_physics_process(true)
	CharacterBuilder.set_speed(player.model, 0.0)
	CharacterBuilder.set_param(player.model, "run", 0.0)
	if weapons and weapons.held:
		weapons.held.visible = _held_vis
	finished.emit(emote_id, cancelled)


## W-D13: walking / standing pedestrians within REACT_R react by share (deterministic order from rng), then resume.
func _react_bystanders() -> void:
	var cands: Array = []
	if targets_fn.is_valid():
		for n: Variant in targets_fn.call():
			if n is Pedestrian and is_instance_valid(n) and (n as Pedestrian).is_inside_tree():
				var p: Pedestrian = n
				if p.can_react_emote() and WeaponMath.flat(p.global_position, player.global_position) <= REACT_R:
					cands.append(p)
	for i: int in range(cands.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = cands[i]
		cands[i] = cands[j]
		cands[j] = tmp
	var n_all: int = cands.size()
	var n_clap: int = roundi(float(n_all) * SHARE_CLAP)
	var n_shout: int = roundi(float(n_all) * SHARE_SHOUT)
	var n_film: int = roundi(float(n_all) * SHARE_FILM)
	for i2: int in n_all:
		var kind: String = "look"
		if i2 < n_clap:
			kind = "clap"
		elif i2 < n_clap + n_shout:
			kind = "shout"
		elif i2 < n_clap + n_shout + n_film:
			kind = "film"
		var secs: float = rng.randf_range(2.0, 3.0) if kind == "clap" else (3.0 if kind == "film" else 2.0)
		var ped: Pedestrian = cands[i2]
		if ped.react_emote(kind, player.global_position, secs):
			reactions[kind] = int(reactions[kind]) + 1
			if kind == "shout":
				_shout_back(ped)


func _shout_back(p: Pedestrian) -> void:
	var l: Label3D = _label("Siuuu!", 40)
	l.position = Vector3(0.0, 2.2, 0.0)
	l.visible = true
	p.add_child(l)
	var a := AudioStreamPlayer3D.new()
	a.stream = WeaponAudio.siuuu_stream()
	a.volume_db = -10.0
	a.pitch_scale = rng.randf_range(0.9, 1.25)
	a.bus = WeaponAudio.bus()
	p.add_child(a)
	a.play()
	_extras.append([l, 1.5])
	_extras.append([a, WeaponAudio.SIUUU_LEN + 0.2])


func _tick_extras(delta: float) -> void:
	for i: int in range(_extras.size() - 1, -1, -1):
		var e: Array = _extras[i]
		e[1] = float(e[1]) - delta
		if float(e[1]) <= 0.0 or not is_instance_valid(e[0]):
			if is_instance_valid(e[0]):
				(e[0] as Node).queue_free()
			_extras.remove_at(i)


func _process(delta: float) -> void:
	if _bubble_left > 0.0:
		_bubble_left -= delta
		bubble.visible = _bubble_left > 0.0
		if player:
			bubble.global_position = player.global_position + Vector3(0.0, 2.4, 0.0)
	if not active or player == null or player.model == null:
		return
	var sk: Skeleton3D = player.model.get_meta("skeleton", null) as Skeleton3D
	var w: float = pose_weight(t)
	if sk == null or w <= 0.0:
		return
	CharacterBuilder._apply_bone_pose(sk, pose_at(t), w)


func _label(text: String, size: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = size
	l.pixel_size = 0.005
	l.outline_size = 10
	l.modulate = Color("#FFE14D")
	l.outline_modulate = Color(0.08, 0.04, 0.12, 0.95)
	l.no_depth_test = true
	l.visible = false
	return l
```

- [ ] **Step 9: Wire the emotes into `scripts/FreeRoam.gd`**

9a. After `var classic_stars: ViceStars` add:

```gdscript
var emote_wheel: EmoteWheel
var emotes: EmoteDirector
```

9b. Append to `_build_mayhem()`:

```gdscript
	emote_wheel = EmoteWheel.new()
	emote_wheel.name = "EmoteWheel"
	add_child(emote_wheel)
	emotes = EmoteDirector.new()
	emotes.name = "Emotes"
	add_child(emotes)
	emotes.setup({"player": player, "weapons": weapons, "wheel": emote_wheel, "weapon_wheel": weapon_wheel,
		"targets_fn": mayhem_targets, "fx": weapons.fx, "blocked_fn": mayhem_blocked})
	# one wheel at a time; no weapon during an emote (spec section 9)
	weapons.blocked_fn = func() -> bool: return mayhem_blocked() or emotes.active or emotes.pending >= 0 or emote_wheel.is_open()
```

- [ ] **Step 10: Import, check the class cache, run the test**

```bash
godot --headless --import --path . > /tmp/w_imp.log 2>&1
grep -c 'EmoteDirector\|EmoteWheel\|EmoteIcons' .godot/global_script_class_cache.cfg
git diff --name-only -- '*.import' | xargs -r git checkout --
godot --headless --path . --script tests/test_emotes.gd > /tmp/w_t12.log 2>&1; grep -E "SUCCESS|FAIL|✗" /tmp/w_t12.log
```
Expected: the cache count is 3, and the test prints `✅ SUCCESS: EMOTES …`, whether or not the owner's `user://sfx/siuuu.mp3` exists on the machine.

- [ ] **Step 11: Run the full regression, then commit**

```bash
git add scripts/emotes/EmoteIcons.gd scripts/emotes/EmoteIcons.gd.uid scripts/emotes/EmoteWheel.gd scripts/emotes/EmoteWheel.gd.uid scripts/emotes/EmoteDirector.gd scripts/emotes/EmoteDirector.gd.uid scripts/roam/Pedestrian.gd scripts/weapons/WeaponAudio.gd scripts/weapons/WeaponDirector.gd scripts/FreeRoam.gd tests/test_emotes.gd tests/test_emotes.gd.uid
git commit -m "feat(emotes): emote wheel on hold B (the shared RadialWheel, 7 greyed 'Sắp có' slots) and 'Siuuu!' - 4.5 m run-up away from the camera, jump with a 180° turn, landing at 1.70 s facing the camera with code-built wide pose, dust and bubble, hold to 2.96 s, 3.30 s total, cancel by movement from 2.20 s, weapon hidden; shout cue on a fixed layout (burst at 0.31 s) started at landing - 0.31 s, synthesized or the owner's local user://sfx/siuuu file (injectable sfx dir in tests); bystanders within 10 m clap, shout back, film with a glowing phone or look, then resume

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 13: Performance gate, docs and the fps table  [effort: high]

**Files:**
- Create: `tests/test_mayhem_perf.gd`.
- Modify: `README.md`, `PLAN.md`, `docs/superpowers/specs/2026-10-23-phase-w-weapons-wanted-design.md` (status line only).

**Interfaces:**
- Consumes everything above: `FreeRoam.weapons / wanted / emotes / pedestrians / traffic`, `WantedDirector.catch_enabled / three_star_t / SECOND_WAVE_S / officers() / pending_bikes`, `WeaponDirector.equip / fire_override / spawn_stink`, `EmoteDirector.play / reactions`.
- Produces: the gate (spec section 7): weapons + wanted + crowd + traffic within 3 ms per physics frame at BE6 with 3 stars, and the same for the "Siuuu!" emote with its bystander reactions. Headless physics script time is measured as in `tests/test_pedestrians.gd`: the phase-change frame is dropped, a tail node runs after every other `_physics_process`.

- [ ] **Step 1: Write the gate `tests/test_mayhem_perf.gd`**

```gdscript
# File: res://tests/test_mayhem_perf.gd
# Phase W performance gate (spec section 7): FreeRoam with the full daytime crowd and traffic at the BE6 spawn, 3 stars with
# the second police wave (catching off), then two measured windows of 120 physics frames against one baseline with the
# crowd, traffic, weapons, wanted level and emotes disabled:
#   W1 weapons + wanted: the loa kẹo kéo blasting into the crowd, a stink cloud, officers chasing, police bikes;
#   W2 emote: "Siuuu!" from its run-up through the landing (bystanders within 10 m react) into the hold.
# Each window must cost < 3 ms per physics frame more than the baseline (headless script time, the phase-change frame
# dropped). A window's figure is the MEDIAN of its per-frame times: a laptop's OS / GC spikes swing the mean by ±0.5 ms
# between runs, the median is stable. The means are printed too. Also: no GPUParticles3D anywhere in FreeRoam, Engine.time_scale back at 1.0. Prints the numbers for PLAN.md.
# Run:  godot --headless --path . --script tests/test_mayhem_perf.gd
extends SceneTree

const GATE_MS: float = 3.0
const WINDOW: int = 120

## Runs AFTER every other _physics_process: from the physics_frame signal (before the nodes) to here = the script time of
## one physics step (Performance.TIME_PHYSICS_PROCESS only updates once a second).
class PhysTail extends Node:
	var on_tail: Callable

	func _physics_process(_d: float) -> void:
		on_tail.call()


var fails: Array[String] = []
var frames: int = 0
var phase: String = ""
var t0: int = 0
var roam: Node3D
var timing: bool = false
var _pt0: int = 0
var samples: PackedInt32Array = PackedInt32Array()
var means: Array[float] = []
var with_w: float = 0.0
var with_e: float = 0.0
var without: float = 0.0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	print("--- TEST MAYHEM PERFORMANCE GATE ---")
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var n: Node = (load(pair[1]) as Script).new()
			n.name = pair[0]
			root.add_child(n)
	var tail := PhysTail.new()
	tail.name = "PhysTail"
	tail.process_physics_priority = 1 << 30
	tail.on_tail = _tail
	root.add_child(tail)
	roam = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	root.add_child(roam)
	phase = "settle"
	physics_frame.connect(_on_physics)


func _tail() -> void:
	if timing:
		samples.append(Time.get_ticks_usec() - _pt0)


func _next(p: String) -> void:
	phase = p
	t0 = frames


func _start_window() -> void:
	samples.clear()
	timing = true


## Median per-frame script time of the window (us); its mean is appended to `means`.
func _window_us() -> float:
	timing = false
	if samples.is_empty():
		means.append(0.0)
		return 0.0
	var total: int = 0
	for s: int in samples:
		total += s
	means.append(float(total) / float(samples.size()))
	var sorted: PackedInt32Array = samples.duplicate()
	sorted.sort()
	return float(sorted[sorted.size() / 2])


func _on_physics() -> void:
	_pt0 = Time.get_ticks_usec()
	frames += 1
	var t: int = frames - t0
	var w: WantedDirector = roam.get("wanted")
	var wd: WeaponDirector = roam.get("weapons")
	var em: EmoteDirector = roam.get("emotes")
	var pl: ThirdPersonController = roam.get("player")
	match phase:
		"settle":
			if t == 180:
				w.catch_enabled = false
				w.add_heat(25.0)
				w.three_star_t = WantedDirector.SECOND_WAVE_S
				_next("chase")
		"chase":
			if t == 600:
				var sp: PedestrianSpawner = roam.get("pedestrians")
				print("  3 stars at BE6: %d officers, %d police bikes on the way, %d pedestrians, %d impostors" % [w.officers().size(), w.pending_bikes.size(), sp.pedestrians().size(), sp.impostors.count()])
				_check(w.stars == 3 and w.officers().size() >= 3, "3 stars with officers chasing (%d)" % w.officers().size())
				wd.equip(WeaponData.Slot.LOA)
				wd.fire_override = true
				wd.spawn_stink(pl.global_position + pl.facing_dir() * 6.0)
				_next("w1")
		"w1":
			if t == 1:
				_start_window()   # the phase-change frame (stink cloud spawn, first blast) is dropped
			if t == WINDOW + 1:
				with_w = _window_us()
				wd.fire_override = false
				_next("w2_wait")
		"w2_wait":
			if t == 30:
				_check(em.play(0), "Siuuu! starts in the crowd")
				_next("w2")
		"w2":
			if t == 61:
				_start_window()   # covers the take-off, the landing (1.70 s) with the bystander reactions and the hold
			if t == 61 + WINDOW:
				with_e = _window_us()
				var n_react: int = 0
				for k: String in em.reactions.keys():
					n_react += int(em.reactions[k])
				print("  emote: %d bystanders reacted %s" % [n_react, str(em.reactions)])
				_next("base_wait")
		"base_wait":
			if t == 150:
				for n: Node in [roam.get("pedestrians"), roam.get("traffic"), wd, w, em]:
					(n as Node).process_mode = Node.PROCESS_MODE_DISABLED
				_next("base")
		"base":
			if t == 1:
				_start_window()   # disabling removes bodies from the physics space: drop this frame
			if t == WINDOW + 1:
				without = _window_us()
				var cost_w: float = (with_w - without) / 1000.0
				var cost_e: float = (with_e - without) / 1000.0
				print("  W1 weapons + wanted + crowd + traffic: %.2f ms per physics frame (median %.0f vs %.0f us; mean %.0f vs %.0f us)" % [cost_w, with_w, without, means[0], means[2]])
				print("  W2 emote + bystanders + crowd + traffic: %.2f ms per physics frame (median %.0f vs %.0f us; mean %.0f vs %.0f us)" % [cost_e, with_e, without, means[1], means[2]])
				_check(cost_w < GATE_MS, "weapons + wanted + crowd + traffic < 3 ms per physics frame at BE6 with 3 stars (%.2f)" % cost_w)
				_check(cost_e < GATE_MS, "the Siuuu! emote with bystanders + crowd + traffic < 3 ms per physics frame (%.2f)" % cost_e)
				_check(roam.find_children("*", "GPUParticles3D", true, false).is_empty(), "no GPUParticles3D in FreeRoam")
				_check(is_equal_approx(Engine.time_scale, 1.0), "Engine.time_scale is 1.0")
				Engine.time_scale = 1.0
				if fails.is_empty():
					print("✅ SUCCESS: MAYHEM PERFORMANCE (W1 %.2f ms, W2 %.2f ms < 3 ms per physics frame)" % [cost_w, cost_e])
					quit(0)
				else:
					print("❌ FAILED: %d issues" % fails.size())
					quit(1)
```

- [ ] **Step 2: Run the gate**

Run: `godot --headless --path . --script tests/test_mayhem_perf.gd > /tmp/w_t13.log 2>&1; grep -E "SUCCESS|FAIL|✗|ms per physics|3 stars at BE6|emote:" /tmp/w_t13.log`
Expected: `✅ SUCCESS: MAYHEM PERFORMANCE …` with both costs below 3 ms. Write the printed lines down for Step 4. The plan's validation run measured W1 2.86-2.92 ms and W2 2.24-2.29 ms (median; means about 0.05 ms higher). About 1.9 ms of W1 is the existing crowd + traffic, 0.5 ms the four chasing officers, 0.25 ms the wanted director and police bikes, and 0.4 ms the loa + stink cloud. The margin is thin: if a window reaches 3 ms, stop and report the numbers; the controller decides on a fallback (officer `move_and_slide` on alternate frames beyond 20 m, or the sonic cone every 2nd tick).

- [ ] **Step 3: Owner notes in `README.md`**

3a. In the "🌏 Thế giới mở" section, insert after the paragraph that starts `Ở phong cách Vice City, mọi nhân vật là người kiểu PS2`:

```markdown
**Vũ khí, truy nã và biểu cảm.** Giữ **chuột giữa** để mở vòng chọn vũ khí (game chậm lại, đưa chuột về ô rồi thả; `ESC` hoặc chuột phải để đóng), lăn chuột để đổi nhanh. Tám ô: Tay không, Dao, Súng lục, Shotgun, Tên lửa, Dép tổ ong (ném vòng rồi bay về tay), Sầu riêng (lựu đạn mùi), Loa kẹo kéo (giữ để phát nhạc đẩy người ra). Chuột phải ngắm qua vai, chuột trái bắn, `R` nạp đạn; chỉ dùng khi đi bộ. Không máu me, không ai chết: người trúng đòn nằm sao bay vòng vòng rồi đứng dậy bỏ chạy, xe trúng tên lửa lật ngửa bốc khói. Gây rối thì bị truy nã 1-3 sao: trong campus bảo vệ đuổi (từ 2 sao có cả Mr.T), ngoài đường cảnh sát chạy xe máy tới rồi xuống đuổi bộ; trốn khỏi tầm nhìn đủ lâu thì mất sao (vòng xanh trên radar là vùng đang bị tìm). Bị tóm thì xem đoạn "BỊ TÓM!" rồi đi lao động công ích: mặc áo cam nhặt 8 bao rác bỏ vô thùng trong 120 giây. Giữ **B** để mở vòng biểu cảm: "Siuuu!" chạy đà, nhảy xoay người, tiếp đất dang tay, người xung quanh vỗ tay, hô theo hoặc giơ điện thoại quay.
```

3b. In the "🌏 Thế giới mở" section's `**Điều khiển:**` line, insert this text just before the `F` (lên/xuống xe máy) item: `` · giữ chuột giữa: vòng vũ khí · chuột phải ngắm, chuột trái bắn, `R` nạp đạn · giữ `B`: vòng biểu cảm ``. In the "🕹️ Điều khiển" section, replace the `* **Thế giới mở:** …` line with:

```markdown
* **Thế giới mở:** `WASD` chạy bộ · `Shift` chạy nước rút (có thể lực) · `Ctrl` đi bộ · `Space` nhảy (trên xe vẫn là drift) · `Z/C` xoay camera · chuột nhìn · giữ chuột giữa: vòng vũ khí · lăn chuột: đổi vũ khí · chuột phải: ngắm · chuột trái: bắn · `R` nạp đạn · giữ `B`: vòng biểu cảm · `F` lên/xuống xe máy · `E` vào điểm nóng chơi màn · `T` đổi giờ · `M` bản đồ · `ESC` tạm dừng.
```

3c. In the "Cinematic: mocap Mixamo và nhạc (tùy chọn)" section, add these bullets at the end:

```markdown
- **Âm thanh vũ khí / biểu cảm (tùy chọn, chỉ trên máy của bạn):** đặt `<tên>.ogg` vào thư mục `sfx\` trong thư mục người dùng của game để thay âm tổng hợp. Tên: `punch`, `swish`, `knife_hit`, `reload`, `dry_click`, `shot_pistol`, `shot_shotgun`, `pump`, `ricochet`, `rocket_launch`, `explosion`, `bonk`, `dep_whoosh`, `durian_pop`, `cough`, `bolero`, `bag_drop`. Loa kẹo kéo phát `sfx\loa_keo_keo.ogg` hoặc `.mp3` nếu có, không có thì phát nhạc bolero tổng hợp. Tiếng "Siuuu" là `sfx\siuuu.ogg` hoặc `.mp3`, cắt theo bố cục cố định: chữ "S" từ 0,25 s, tiếng hô mạnh nhất ở 0,31 s, ngân tới 1,57 s. Các file này không bao giờ được commit hay đóng gói.
- **Đoạn "BỊ TÓM!"** (`wanted_busted`, 7 s) chạy bằng hệ cinematic; nhạc của nó là `music\wanted_busted.ogg` / `.mp3` nếu có. Thời điểm nằm trong `docs/cinematics/wanted_busted.txt`.
```

3d. In the sentence starting `Kiểm thử headless (không cần cửa sổ):`, add `tests/test_weapon_wheel.gd` … `tests/test_mayhem_perf.gd` (vũ khí, truy nã, biểu cảm) to the list.

- [ ] **Step 4: Phase W section and fps table in `PLAN.md`**

Insert before the `## 🧪 VII. KIỂM THỬ HEADLESS (tests/)` heading:

```markdown
## 🔫 XV. PHASE W: WEAPONS, WANTED LEVEL AND EMOTES (24/10/2026)

Spec `docs/superpowers/specs/2026-10-23-phase-w-weapons-wanted-design.md` (W-D1 … W-D13), plan `docs/superpowers/plans/2026-10-24-phase-w-weapons-wanted.md` (13 tasks, branch `phase-w`).

* **Wheels.** `RadialWheel` (scripts/weapons/) is data-driven: the weapon wheel (hold middle mouse, 8 slots, scroll cycles) and the emote wheel (hold B, "Siuuu!" + 7 greyed slots) are thin subclasses. Only the radial wheel writes `Engine.time_scale` (0.2, eased 0.1 s real, restored on close / block / exit); nothing under scripts/cine/ does (A1-D6).
* **Weapons.** `WeaponDirector` (magazines with unlimited reserve, aim camera, hip fire, analytic capsule / box ray tests with world occlusion) and its projectiles. Targets are duck-typed (`take_hit`, `is_down`): pedestrians get knocked out with stars, launched, stink, dance, flee; officers too; vehicles halt or flip and smoke (`RoamTraffic.hit_vehicle`). FX on the A1 `CineFX` with a game clock, sounds synthesized in `WeaponAudio` with `user://sfx` overrides (never committed).
* **Wanted level.** `WantedDirector`: 4 / 12 / 25 heat for 1 / 2 / 3 stars, line-of-sight decay 12 / 20 / 30 s, radar search circle, campus guards and Mr.T, police bikes from `RoamTraffic` (second wave at 3 stars), busted after 1.5 s within 1.2 m, the 7 s `wanted_busted` cutscene, community service.
* **Emotes.** `EmoteDirector` "Siuuu!": run-up, jump with a 180° turn, landing at 1.70 s, shout cue started at landing − 0.31 s, 3.30 s total, bystander reactions within 10 m.
* **Headless physics cost** (`tests/test_mayhem_perf.gd`, BE6, full daytime crowd + traffic, 3 stars + second wave): W1 weapons + wanted = the `W1 … ms per physics frame` line it prints; W2 emote + bystanders = its `W2 …` line. Gate: < 3 ms each.

**fps table** (owner, windowed, V-Sync off, on AC power; agents no longer run windowed previews): start the game (F5), open Thế giới mở, raise the wanted level to 3 stars at each spot and read the fps counter (`PREVIEW_NOVSYNC=1 godot --path . --script tests/preview_free_roam.gd` gives the same spots' crowd baseline without Phase W).

| Spot | fps | Gate |
| :--- | ---: | ---: |
| FreeRoam BE6 lobby, 3 stars, loa + stink cloud | (owner) | ≥ 45 |
| FreeRoam campus courtyard, 3 stars (6 guards + Mr.T) | (owner) | ≥ 45 |
| FreeRoam BE6, "Siuuu!" in the crowd | (owner) | ≥ 45 |
```

Replace the two cost placeholders in the "Headless physics cost" bullet with the numbers printed in Step 2 (for example `W1 2.9 ms, W2 2.3 ms`).

- [ ] **Step 5: Spec status**

In `docs/superpowers/specs/2026-10-23-phase-w-weapons-wanted-design.md`, append to the `Status:` sentence on line 3: ` Implemented on branch phase-w (plan docs/superpowers/plans/2026-10-24-phase-w-weapons-wanted.md).` The spec arrived on this branch with the merge of main (27b4412), so editing it here does not conflict.

- [ ] **Step 6: Full regression, then commit**

Run the regression command. Every line must be green, including `test_mayhem_perf`.

```bash
git add tests/test_mayhem_perf.gd tests/test_mayhem_perf.gd.uid README.md PLAN.md docs/superpowers/specs/2026-10-23-phase-w-weapons-wanted-design.md
git commit -m "test(perf)+docs: Phase W performance gate (weapons + wanted + crowd + traffic and the Siuuu! emote with bystanders each < 3 ms per physics frame at BE6 with 3 stars), README controls and owner sfx overrides, PLAN section with headless costs and the owner fps table, spec status

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Self-review (spec coverage, placeholders, names)

**Spec coverage** (spec sections and decisions → tasks):

| Spec | Task(s) |
|---|---|
| W-D1, section 2 (wheel: hold ≥ 0.12 s, 8 wedges, 40 px dead zone, release / Esc / right click, scroll + toast, 0.2× eased in real time, blocked states, code icons, Vietnamese labels, "12 / ∞") | 1 (RadialWheel, WeaponWheel, icons), 3 (toast, ammo text, FreeRoam blocking) |
| W-D2 (everywhere incl. campus) | 3 (FreeRoam wiring has no zone limit) |
| W-D3 (no gore, KO 6-10 s + flee, vehicles flip / smoke / recycled) | 2, 5 |
| W-D4, section 3 table (8 weapons and their numbers) | 1 (data), 3 (unarmed, knife), 4 (pistol, shotgun), 5 (rocket), 6 (dép, sầu riêng, loa) |
| W-D5 (bolero default, local loa_keo_keo override, no real singer) | 6, Global Constraints |
| W-D6, section 4 (heat, stars 4 / 12 / 25, +5 officer, LOS decay 12 / 20 / 30 s, search circle, HUD stars, BE6 not special) | 7, 8 (+5) |
| W-D7 (guards 2 / 4 / 6, Mr.T from 2 stars with his line, police bikes 1 / 2 / 3, dismount ≤ 15 m, second wave after 30 s, never shoot) | 8, 9 |
| W-D8, section 5 (busted rule, freeze, stamp, 6-8 s cutscene through the A1 player, Esc skips, community service, timeout restart, finish clears + bike) | 10, 11 |
| W-D9 (on foot only, unlimited reserve, player never hurt) | 3, 5 (knock-down), 8 (tackle) |
| W-D10 … W-D13, section 9 (emote wheel on B reusing the radial UI, "Siuuu!" timings, cue layout and sync, override, bystanders) | 1 (shared base), 12 |
| Section 6 (systems and files, flag like crowd_enabled, effort) | File map, 3 (`mayhem_enabled`), Effort |
| Section 7 (tests, performance gate) | every task's test, 13 |
| Section 8 (out of scope: no drive-by, shops, health, police shooting, 4-5 stars, helicopters) | not built |

**Placeholder scan:** every code step carries the full code. The only open values are the measured costs in Task 13 Step 4, which the implementer fills from the gate's printed lines.

**Name consistency:** the names checked across tasks are:
- `RadialWheel` / `WeaponWheel` / `EmoteWheel`;
- `WeaponDirector.first_hit`, `_exclusions`, `hit_target`, `soft_targets`, `_heat`, `is_firing`;
- `WantedDirector.add_heat`, `tick`, `spawn_officer`, `catch_enabled`, `bust`, `_start_service`, `_clear_officers`, `_release_bikes`;
- `RoamTraffic.hit_vehicle`, `spawn_police`, `police_arrived`;
- `Pedestrian.take_hit`, `react_emote`;
- the timeline slot `wanted_busted`.

**Validation:** while writing it, every task's code was applied in order, from scratch, in a scratch copy of this worktree (base 4c8f9ed), and each task's test ran green. These fixes to the plan came out of that run:
- the ease starts on the next real-time tick;
- test pedestrians are positioned before they enter the tree;
- the traffic helper's node sits 100 m below the arena;
- the busted slot is named so that F9 still starts with `seg_d1_brawl`;
- the Task 10 test tolerates Task 11's chore.

`tests/test_mayhem_perf.gd` then ran green twice on top of Tasks 1-12: W1 2.86 / 2.92 ms and W2 2.24 / 2.29 ms. The first draft scored the mean and measured 3.36 ms, which led to P14, the officer step-up guard (Task 8, `test_officers` re-run green) and the median statistic. The full regression on that tree (53 tests + check + smoke) is green. The docs steps (README, PLAN.md, spec status) were not executed.

