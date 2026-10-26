# Story Phase C: Bike Combat (C-D1): Implementation Plan

Spec: `docs/superpowers/specs/2026-10-26-story-phase-c-days-2-3-5-design.md`, decision **C-D1** and its tests from C-D13
(`test_bike_combat`, the bike-chase perf case). Branch `phase-c-bike`, base 291b403. Lair gunfights, sword duels,
cinematics and the Day 2 wiring are other agents' work: this branch never touches StoryMissions, StoryRoam,
StoryDirector or a timeline.

**Goal.** Road Rash style kicks from the player's bike against the Bầy Sói bikers, and one encounter node (`BikeChase`)
the integration agent drives for the Day 2 chase (5-6 bikers in 2 waves, then the `seg_d2_chase` replay).

## Where it runs: FreeRoam, on the real Nguyễn Xiển road

Chosen over the Stage 1 night road because:
- the corridor region builds every OSM way of Nguyễn Xiển whole (roads are not clipped to the 150 m corridor buffer):
  the south dual carriageway, the two-way part, the Rạch Hầm bridge (40 m, a 3 m hump with deck collision), so the bike
  can ride all of it;
- RoamTraffic already drives lanes on it (night: 30 % of the cars), so "keep up with traffic" is real traffic;
- the bridge duel, the horror beat and the ledger page are at the same real place: no scene switch, no load hitch, and
  StoryRoam (markers, phone, objective, fail card) stays in charge between beats;
- the FreeRoam PlayerBike rides free (no road path, no lane clamp), so the chase only needs its own route for the AI.

Default route (`BikeRoute.nguyen_xien(md)`): Nguyễn Xiển northbound from the south end of its dual carriageway, across
the Rạch Hầm bridge (at about 356 m), then the BE6 -> FPTU route onward (Nguyễn Văn Tăng) as run-off so a long fight never
hits a dead end; cut at 2.1 km. The integration can pass its own points or `route: []` (free mode).

## Architecture (new code in `scripts/combat/bike/`)

- `BikeCombatData` (static): every number and the Vietnamese texts (plain, no emoji; key glyphs only in control hints),
  the wolf-gang default look, the kick bone poses.
- `BikeRoute` (RefCounted): a polyline with arc length; `point(s)`, `tangent(s)`, `right(s)`, `world(s, d)`,
  `project(p, s_hint)` -> (s, d) with a search window around the last s (no jumps between close parallel legs);
  `nguyen_xien(md)` builds the default route from mapdata by road name, not id.
- `PlayerBikeCombat` (Node): the player's side on one PlayerBike. Q kicks left, E right (input events, consumed only
  while a chase runs and the player rides); wind-up 0.1 s, hit window 0.1-0.3 s, cooldown 0.55 s; reach 0.3-2.4 m to the
  side, +/-1.7 m along; one target per kick, else a miss. Stability 100: an enemy kick -20, a crash into traffic or a
  curb (PlayerBike.crash_occurred) -25, ramming the front biker -6; 0.6 s of invulnerability after a hit; +4/s after 5 s
  without damage. At 0 the player is knocked off (bike locked and laid on its side, stars). Kick leg pose as a bone layer
  over the rider (process priority 11, after the RigAnimator), a lean on non-rigged riders.
- `BikerEnemy` (Node3D): one Bầy Sói biker, analytic (no physics body): a baked dark scooter, a rigged rider with the wolf
  helmet (grey shell, ears, snout, red LED eyes; `body` / `body_fn` / `eye_color` opts override the look), a name label
  with short taunts. AI states APPROACH -> PACE (hold a slot) -> WINDUP (0.5 s telegraph: LED eyes flash, engine rev, HUD
  side warning) -> KICK (hit at 0.15 s, reach 1.75 m) -> RECOVER; BRAKE (the front biker brake-checks); WOBBLE (kicked:
  0.55 s, then CRASH, or RECOVER while hp is left); CRASH (the rider flies and tumbles in a comic arc, lands with a bounce
  and slides; the bike slides on its side with sparks); DOWN (stars, no gore); LEAVE (after `lost`: rides off); HOLD
  (ai off: tests). Motion: a kinematic follower of a target point (player velocity feed-forward, catch-up and accel
  limits), floor height from a 10 Hz ray (the bridge), traffic avoidance (pass on the free side or brake behind) and a
  crash when it touches a car anyway (a kicked biker wobbling into a car is a bonus knockdown).
- `BikeChase` (Node3D): the encounter API (below). Owns the PlayerBikeCombat and the BikeHUD; every physics frame it
  projects the player on the route (or uses the player's heading frame off the route / without one), assigns roles
  (FRONT box-in blocker, LEFT / RIGHT flankers, BACK reserves; a flank slot with no room on that side becomes BACK),
  hands out attack tokens (max 2, 0.8 s apart), ticks the bikers, runs the waves, the checkpoint / retry and the replay.
  Gives RoamTraffic the bikers as obstacles so cars brake for them.
- `BikeHUD` (CanvasLayer, CombatHUD styles): top centre "Độ vững xe" bar + number, "Bầy Sói còn: N", "Đợt i/n"; kick
  hints "[Q] Đạp trái · [E] Đạp phải" dimmed during the cooldown; a red edge arrow + "BÊN TRÁI" / "BÊN PHẢI" while a
  biker on that side winds up; centre popups (start line, "ĐẠP BAY!", "BỊ VÂY!", knocked off, win line).

## API (for the story integration)

    var chase := BikeChase.new(); roam.add_child(chase)
    chase.setup({"roam": roam,            # or "bike" (+ "player", "traffic") without FreeRoam
        "route": null,                    # default BikeRoute.nguyen_xien(roam.md); BikeRoute / points / [] (free mode)
        "start_s": 30.0, "place": true,   # put the rider at that route distance, facing along the route
        "max_attackers": 2, "auto_checkpoint": true,
        "start_line": "", "win_line": "", # Day 2: BikeCombatData.T_START_D2 / T_WIN_D2
        "replay_slot": "seg_d2_chase", "auto_replay": true, "manual_replay": false, "seed": 1})
    chase.add_wave([{"from": "behind" | "ahead", "lane": -1 | 0 | 1, "gap": 0.0, "delay": 0.0,
        "opts": {"label": "Sói Đen", "hp": 1, "eye_color": Color, "body": {...}, "body_fn": Callable, "aggression": 0.5}}])
    # BikeChase.day2_waves() returns the default Day 2 layout (3 + 3 bikers)
    chase.won / lost / biker_down(biker, cause) / wave_started(i) / wave_cleared(i)
    chase.start(); chase.checkpoint(); chase.retry(); chase.stop(); chase.alive(); chase.state

States: "idle" | "running" | "finishing" (last biker down: the recorder runs 0.8 s more, then the replay plays) |
"won" | "lost". `won` comes after the replay (at once without footage or with auto_replay false; then
`play_replay()` is public). `lost` (stability 0): the bikers ride off; show "TOANG!" and call `retry()` (back to the wave
checkpoint: the bike's transform at that wave's start, stability full, the wave again). `stop()` and freeing the chase
unlock and restore the bike, the hint and the traffic hook. The chase never changes the story state, the time of day,
the music or the camera, and never references an autoload by name.

## Shared files (surgical)

- `FreeRoam.gd`: `riding_hint` (replaces HINT_RIDING while set) and `dismount_refusal` (toggle_bike refuses to get off
  the bike with that hint while set). BikeChase sets both while it runs.
- `roam/RoamTraffic.gd`: `extra_obstacles_fn` (Callable -> Array of look-ahead obstacles, kind "biker"), appended in
  `_obstacles()`. Unset = unchanged behaviour.
- `PlayerBike.gd`: untouched (the chase reads `crash_occurred`, `current_speed_ms`, `is_controls_locked`,
  `visual_pivot`, `rider_node`, `add_camera_shake`).

## Replay

The recorder starts with the last wave and tracks the player bike, its visual pivot and rider, and each biker's bike
and rider (transforms + bone poses). The last fall marks "blow"; 0.8 s later `CineReplay` plays (StoryStage helper, 5 s,
slot `seg_d2_chase`: owner file or silence), focus = the fallen rider, other = the player bike; the BikeHUD hides.
The slot must be listed in `MusicDirector.REPLAY_SLOTS` by the integration (not touched here).

## Tests

- `tests/test_bike_combat.gd`: A (arena, synthetic straight route, real PlayerBike, no FreeRoam): data and text checks;
  route maths and the real Nguyễn Xiển route; kick hit (wobble -> crash -> tumble -> down, rider away from the slid
  bike, `biker_down`), misses (wrong side, too far, ahead, after the window), cooldown refusal, hp 2; the AI kick
  (telegraph >= 0.45 s before the hit, -20) and a dodge; traffic crash -25 with invulnerability; stability 0 -> knocked
  off -> `lost`, bikers leave; `retry()`; two waves, auto checkpoint, replay trigger and `won`; traffic avoidance and
  the traffic hook; AI pacing and box-in with 3 bikers; input refusals when not riding; `stop()` / free restore.
  B (FreeRoam, night, no crowd): start places and mounts the rider on Nguyễn Xiển, the hint and [F] refusal, bikers
  follow on the road and over the bridge deck, `stop()` restores [F].
- `tests/test_bike_perf.gd`: FreeRoam with the full crowd and traffic, the player riding Nguyễn Xiển on autopilot, 6
  AI bikers (god mode, tough), kicks every 0.6 s; chase-only and chase + crowd + traffic costs < 3 ms per physics frame,
  median and 5 %-trimmed mean (method of `test_combat_perf`).
- Run: both tests, `--check-only`, `smoke_all_stages`, `test_free_roam`, `test_roam_traffic`, `test_police_bikes`,
  `test_near_miss`, `test_stage1_race` (PlayerBike users), `test_combat_perf`, `test_mayhem_perf`.

## Tasks

1. Plan (this file), commit.
2. `BikeCombatData`, `BikeRoute`; FreeRoam + RoamTraffic hooks.
3. `PlayerBikeCombat`, `BikerEnemy` (look, AI, crash).
4. `BikeChase`, `BikeHUD`, replay.
5. `test_bike_combat`, `test_bike_perf`; run the list above; commit.
