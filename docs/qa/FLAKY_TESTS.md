# Flaky tests ledger

Known tests that sometimes fail with no code change. Before calling a red test a regression, find it here and apply its
rerun rule. A test that fails the same way when re-run alone is a real failure, whatever this ledger says.

How to re-run: `bash tools/rerun_failed.sh <logdir>` re-runs every failed test of a regression log directory (the one
`w_regress.sh` writes: one `<test>.log` per test) one at a time and prints FLAKY or REAL for each. It does not re-run the
perf gates (see below). By hand: `godot --headless --path . --script tests/<test>.gd > <log> 2>&1`, then grep the log
for `SUCCESS`, `FAIL`, `SCRIPT ERROR` and `ERROR:`. Never pipe Godot output into grep.

General rules:

- Run one Godot test at a time when you judge a failure. Other Godot processes on the machine (another agent's tests,
  an editor import) are the most common cause of every entry below.
- One failure in one run is "suspected", not "flaky". It becomes "flaky" here only after it passed alone on a re-run.
- Record a new flake in this file: the test, the failing check text, the run conditions (parallel or alone, AC or
  battery), and the result alone.

## Not failures

| What you see | Why | Rule |
|---|---|---|
| Exit code 139 after the log printed `SUCCESS` | The known crash on exit of Godot 4.7.2 (also seen on the first `--import` of a fresh project). The test already passed. | Count it as a pass. Exit 139 without `SUCCESS` in the log is a real crash: re-run once alone; if it crashes again, it is real. |
| `ERROR: File 'user://test_story_video_<pid>/ai_intro_f.ogv' has no video stream.` (from `video_stream_theora.cpp`) | `tests/test_story_cines.gd` (`_video`, the fake file at line 322) and `tests/test_story_endings.gd` (line 271) write a text file named `.ogv` to check that StoryVideo only picks a file that exists. Theora then fails to open it. | Expected. Do not count these lines when grepping for `ERROR:`. Any other `ERROR:` line in those logs still counts. |

## Flaky tests

### test_music_slots: the warm-cache checks

- **Symptom.** Under CPU load, about three checks of `_warm_cache()` (`tests/test_music_slots.gd:340-375`) fail
  together: "both slots warmed", "the loads ran off the main thread" and "the cached stream is reused on the next play"
  (the off-main-thread load and the cached reuse). Run alone, the test passes.
- **Cause.** `warm()` starts two WorkerThreadPool tasks and the test waits at most 3000 ms of wall-clock time
  (line 350) for both. When other Godot processes keep every core busy, the tasks do not finish in time, so the test
  goes on with the slots still pending and the counters it checks next (the thread list, `main_thread_loads`, the
  cached stream) are not what a finished warm gives.
- **Flake or real.** Flake: only checks inside `_warm_cache()` fail, the rest of the file passes, and the test passes
  alone. Real: it fails alone; or any other check fails (slot catalogue, no-synth scan, crossfades, NightMusic); or
  "warm starts one task per slot, once" fails (that one has no timing).
- **Rerun rule.** Re-run alone, up to 2 times. Passes once alone: flake.

### test_story_day4: the bun checks of the canteen fight

- **Symptom.** Failed once on "behind the flipped table the bun is blocked (N thrown, N blocked)" and "in the open the bun
  splats the player (N hits, hp A -> B)" (`_food_fight_throws`, `tests/test_story_day4.gd:399-425`), then passed alone.
- **Cause (suspected, one failure seen).** Whether a bun is blocked is decided by a physics ray at throw time
  (`ArenaDressing._throw`, `scripts/story/missions/ArenaDressing.gd:398-405`) against the live physics space. During the
  30-frame wait after the flip, wave 2 (Cừu Dolly and two clones) keeps fighting on real frames and the flip tween runs
  on real time, while the check loop itself calls `mf.advance(0.05)` with no physics frame in between. An enemy crossing
  the thrower-to-player line, or the table not yet at its flipped pose in the physics space, changes the result.
- **Flake or real.** Read the counts in the message. Flake: it fails once, the counts look like a near miss (for example
  1 thrown, 0 blocked), and it passes alone. Real: it fails alone; or "0 thrown" (the thrower never threw: the
  thrower state machine is broken); or the wave-2 or flip checks just before it fail too.
- **Rerun rule.** Re-run alone, up to 2 times. Fix direction if it repeats: keep the wave-2 enemies away from the
  thrower line during the bun checks, and wait one physics frame after each teleport before the throw.

### The perf gates

`test_bike_perf`, `test_canal_perf`, `test_combat_perf`, `test_gunfight_perf`, `test_horror_perf`, `test_lair_perf`,
`test_mayhem_perf`, `test_sword_perf`, `test_tower_perf` (each has `GATE_MS = 3.0`).

- **Symptom.** The median or the 5 %-trimmed mean of a measured window goes over 3 ms per physics frame. Also the
  `test_mayhem_perf` setup check "3 stars with officers chasing (N)".
- **Cause.** The gates time the script cost with `Time.get_ticks_usec()` (wall clock). Other Godot processes running at
  the same time, or the laptop on battery (lower clocks), inflate every frame.
- **Flake or real.** Real: run alone, on AC power, with no other Godot process, it is still over 3 ms by the median or
  the trimmed mean, twice. Flake: alone on AC it is under 3 ms.
- **Rerun rule.** Never judge a perf gate from a parallel run. Run it alone, on AC power, with no other Godot process,
  and report the numbers with the power state
  (`Get-CimInstance -Namespace root/wmi -ClassName BatteryStatus`, `PowerOnline` must be True). `tools/rerun_failed.sh`
  lists failed perf gates but does not re-run them.

### test_weapons_core: part B under load

- **Symptom.** Part B (FreeRoam with the crowd off: the wheel on foot, blocked on the bike and during a cinematic, the
  weapon HUD hidden on the bike) fails when the machine is loaded. Listed in the agent rules; the failing check text
  was not recorded.
- **Cause.** Not known. Part B counts physics frames in FreeRoam, which takes the longest to load of all scenes.
- **Flake or real.** Real: it fails alone, or part A fails.
- **Rerun rule.** Re-run alone, up to 2 times. Record the failing check text here next time.

### test_bullet_time, test_camera_director, test_melee_combat: under a full parallel regression (2026-11-09)

- **Symptom.** All three failed in the Wave 6 full regression, which ran on battery while another Godot test run was
  going. All three passed alone right after, on the same commit (wave6 74eb2c7), and on main.
  - test_bullet_time: "M: a repeated focus_muffle(true) changes nothing (1.00)".
  - test_camera_director: "shake moves the player's camera (0.0000 rad)".
  - test_melee_combat: "the clones keep attacking and hurting (3 attacks, hp 97)".
- **Cause.** Wall-clock timing:
  - the muffle slides over MUFFLE_TIME real seconds;
  - the shake and the clones' attacks are sampled over a fixed real-time window.
  Wave 6 does not touch MusicDirector, BulletTime, the camera director or the melee code.
- **Flake or real.** A flake if it passes alone. Real if it fails alone, or fails with a different check text.
- **Rerun rule.** Re-run alone, up to 2 times.

## Timing-sensitive checks (not yet seen failing)

These checks compare wall-clock time to a fixed budget. None has been recorded as flaky, but they fail the same way as
the perf gates on a loaded machine. If one fails in a parallel run, re-run the test alone before calling it real, then
add it to the section above.

| Test | Check | Budget |
|---|---|---|
| `test_camera_framing` | one on-foot camera update (line 257) | < 400 us |
| `test_cine_actor` | timeline evaluate (line 396) | < 2.5 ms |
| `test_cine_player` | CinePlayer frame update (line 155) | < 8 ms |
| `test_cine_d1_brawl`, `test_cine_d4_brawl` | frame update with 4 / 5 actors (lines 471 / 374) | < 8 ms |
| `test_cine_retarget` | UAL and Mixamo sample (lines 96, 147) | < 600 us |
| `test_cine_transition` | baked stage lookup (line 156), budgeted search (line 191), prepare (line 357) | < 20 ms, < 250 ms, < 20 ms |
| `test_crowd_impostors` | baking 24 variants (line 72) | < 8 s |
| `test_dialogue_voice` | `warm()` returns (line 72) | < 20 ms |
| `test_drift_duel` | race tick median (line 668) | < 0.6 ms |
| `test_free_roam` | `FreeRoam._ready` build (line 111), dynamic map redraw (line 829) | < 15 s, < 2 ms |
| `test_pedestrians` | walk graph build (line 687) | < 1.5 s |
| `test_ps2_people` | one PS2 character build (line 316) | < 15 ms |
| `test_roam_traffic` | 25 vehicles per physics frame (line 475) | < 1.5 ms |
| `test_side_activities` | race and chase tick (line 391) | mean < 0.5 ms, max < 3 ms |
| `test_story_audio` | `warm()` returns (line 53), cues from the warm cache (line 70) | < 16 ms, worst < 2 ms |
| `test_vice_hud` | radar `_draw` (line 317) | < 2000 us |
| `test_weapons_funny` | synthesis (line 77), equip and scroll (line 134) | < 1.5 s, < 25 ms |

`test_story_audio` also warms on worker threads, like `test_music_slots`, so its warm checks are the most likely to
flake next.
