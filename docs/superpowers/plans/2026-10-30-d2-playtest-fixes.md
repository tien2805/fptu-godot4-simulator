# Plan: Day 2 playtest fixes (branch d2fix, from main ed4b624)

Owner playtest of the chase "Bầy Sói" and the race "Đua với Sói Xám": "làm game tệ quá, lũ xe cứ chạy loạn lên, tôi còn chả
tìm thấy chúng để đá nữa" and "phải có chỉ đường dễ nhìn hơn hoặc đường trên map chứ". Problems picked: enemies OFF SCREEN
and enemies RUN OFF (too far ahead or behind). Quality bar: a first-time player must ALWAYS see where to go and where the
enemies are. Kept unchanged: the Tokyo Drift opening (drop at 4.15 s from the playback position), the real-rev countdown
and Deja Vu on GO, the chase music through the replay.

**Resume rule:** a later agent resumes from the first unchecked task and the commits on `d2fix`.

## Interfaces

- **New `RouteGuide`** (`scripts/combat/bike/RouteGuide.gd`, Node3D, owned by BikeChase and DriftDuel):
  `setup({"path": BikeRoute | DriftCourse, "bike", "s_fn": Callable -> player s, "end_s", "floor_fn": Callable(Vector3) ->
  Variant, "roam" (radar), "targets": Array (the owner's live array of enemies), "boss": Node3D (Sói Xám), "occlude_rids"})`,
  `set_active(on)`, `set_hud_visible(on)`; static `find_turns(path, length)` -> [[s_apex, dir (+1 right), deg, s_in], ...].
  - on the road: pooled glowing chevrons (one MultiMesh, about 19) every CHEV_STEP m from CHEV_NEAR to CHEV_FAR ahead along
    the path, fading in near the bike and out at the far end; heights by a cached, throttled floor ray per slot;
  - HUD (`GuideHUD`, its own CanvasLayer): the next-turn panel top left, above the radar ("RẼ TRÁI 80 m", "CUA GẮT PHẢI", a
    drawn bent arrow, "RỒI RẼ ..." for a second turn close behind) shown from TURN_SHOW_M before each turn; a red edge arrow
    for every active enemy off screen or behind the camera (sized by distance, pulsing while it closes in); a marker over
    Sói Xám with his name and distance, and his edge arrow;
  - radar: the course on ViceRadar (`guide_route`) and a red dot per enemy (`extra_blips`, pooled, 10 Hz);
  - metrics: `onscreen_t` / `combat_t` (time at least one active enemy is on screen / time with one active), `turns_shown`
    (per turn: the farthest distance the arrow showed it from), `arrows_drawn`, `boss_hidden_max`.
- **ViceRadar**: `guide_route: PackedVector2Array` (drawn over the roads instead of the BE6 route while set) and
  `extra_blips: Array[Dictionary]` (drawn after the blips).
- **BikeCamRig**: `set_combat_framing(on)`: eased (BIKE_COMBAT_EASE_S) +BIKE_COMBAT_UP height, +BIKE_COMBAT_DIST distance,
  +BIKE_COMBAT_FOV FOV (CameraRules); `combat_k` for tests.
- **BikeChase / BikerEnemy / BikeCombatData** (chase AI):
  - leash: every active biker within LEASH_AHEAD (20 m) ahead / LEASH_BEHIND (12 m) behind the player: targets clamped,
    the speed limited toward the band, a top speed that can always catch the player, a hard clamp as the last resort;
    `max_ahead` / `max_behind` / `max_dist` telemetry;
  - flank slots inside kick reach (`slot_lat` 2.2-2.4 m) held for HOLD_MIN..HOLD_MAX s (counted only while settled in the
    slot) before the wind-up; sticky roles with hysteresis (a slot unfit for ROLE_UNFIT_S before its holder leaves);
    separation as a soft correction (no jitter); BACK reserves closer;
  - spawns: "behind" BEHIND_M (6.5 m, just behind the camera, never past BEHIND_MAX) back, arriving ARRIVE_REL faster than
    the player; "ahead" spawns become "behind"; each arrival honks (positional) and shows its edge arrow; MAX_ALIVE (4, Dễ 3)
    riders at once, the rest wait;
  - the guide, the radar, and the combat framing while a biker is within COMBAT_CAM_M.
- **PlayerBikeCombat**: kick assist: Q / E pick the nearest kickable target on that side within ASSIST_LAT (3.5 m) and
  +/-ASSIST_ALONG (3.5 m); the target is pulled in (`magnet(to, k)` on BikerEnemy / DriftRival) through the wind-up so the
  leg connects. The counter-kick timing is unchanged.
- **DriftDuel / DriftRival**: the band caps his lead at RIVAL_LEASH_M (30 m: speed held to the player's, then a hard
  clamp), and he eases off when out of sight for RIVAL_HIDDEN_S; the guide with the boss marker; combat framing while he is
  within COMBAT_CAM_M; `rival_hidden_max` telemetry.

## Tasks

- [x] **T0 Plan** (this file).
- [x] **T1 Camera**: CameraRules constants, BikeCamRig.set_combat_framing. Test: the eased offsets (test_d2_guidance).
- [x] **T2 Radar**: ViceRadar guide_route + extra_blips (cached near segments like the route).
- [x] **T3 RouteGuide**: turns, chevrons, GuideHUD (turn panel, edge arrows, boss marker), radar feed, metrics.
- [x] **T4 Chase AI**: leash, slots in reach, hold window, sticky roles, soft separation, spawns behind with a honk, MAX_ALIVE,
  wave layout; BikeChase wires the guide and the combat framing.
- [x] **T5 Kick assist**: PlayerBikeCombat assist zone + magnetism; BikerEnemy / DriftRival magnet().
- [x] **T6 Race**: DriftDuel / DriftRival leash and hidden rule, the guide with the boss marker, combat framing.
- [x] **T7 Sims**: measurements (on-screen share, max distance ahead / behind, turn arrows shown before each turn, Sói Xám's
  longest hidden stretch) in `sim_bike_chase_d2.gd` and `sim_drift_race.gd`; re-tune (Thường 1-3 fails, Dễ at most 1).
- [x] **T8 Tests**: new `test_d2_guidance`; update `test_bike_combat`, `test_drift_duel`, `test_story_day2`; smoke,
  `--check-only`, `test_bike_perf` alone on AC power (< 3 ms).

## Results

Sims: `tests/sim_bike_chase_d2.gd -- sloppy <seed> <runs> <normal|easy>` and `tests/sim_drift_race.gd -- <normal|easy> <seed>
<missions>` (FreeRoam at night, `--fixed-fps 60`). "On screen" = at least one active biker inside the current camera's frame
(within 160 m) over the combat time (running, not the opening or the cameo, a biker active); the leash band is 20 m ahead /
12 m behind; a turn counts as announced when the panel showed it at least 40 m before.

**Baseline** (ed4b624, Thường, seeds 1-3): on screen 45 / 63 / 64 %, the longest stretch with no biker on screen 9.4 s,
bikers up to 31.8 m behind and 21.7 m ahead, 23-30 s per run past the band; fails 0, 1, 2. No turn arrows, no route.

**Chase tuning** (Thường, sloppy bot)

| Round | Change | Fails per run | On screen (worst run) |
|---|---|---|---|
| 1 | leash, slots in reach, the hold window, MAX_ALIVE, spawns 10 m back | 0, 0, 0, 0 (3-4 enemy attacks a run: the bot kicks them in the hold) | 65 % |
| 2 | reserves in a second row ahead, W3 riders 2 hp and its heavy 4, refill 10 | 0, 1, 0, 0 | 67 % |
| 3 | spawns 7.5 m back, faster approach, the pickup waits 4.5 m back, a kicked rider re-holds 1.5 s | 0, 0, 3, 0 | 78 % |
| 4 | damage rider 26, stick 28, pickup 40; spawns 6.5 m back | 2, 1, 1, 1, 0, 0 | 72 % |
| 5 | throwers spawn on a side lane, arrivals at +6 m/s | 1, 2, 1, 1, 0, 1, 0, 0 | 83 % |
| 6 | refill 5, the pickup gives up after 3 dodges | 1, 2, 1, 1, 0, 1, 0, 0 | 84 % |
| 7 | W2 heavy 4 hp (reverted) | 1, 0, 0, 0, 0, 0, 0, 0 | 80 % |
| 8 | the pickup rams 4 times (reverted: one run 19 fails) | 2, 0, 0, 0, 3, 19, 0, 3 | 84 % |
| **final** | = round 6 | **1, 2, 1, 1, 0, 1, 0, 0** (avg 0.75, 5 of 8 in 1-3, max 2); Dễ **0, 0, 0, 0** | **84-92 %** (Dễ 81-87 %) |

Final chase measurements (8 Thường runs): on screen 84, 92, 88, 90, 86, 87, 87, 84 % of the combat time; the longest stretch
with no biker on screen 0.6-3.0 s (an arrival from behind, shown by its edge arrow and horn); furthest ahead 10.1 m, behind
12.0 m (the clamp), never past the band (0.0 s); the turn panel announced 10 of 10 turns (11 of 11 on a run past the
last one) at least 40 m before, every run.

**Race tuning** (sloppy bot)

| Round | Change | Thường fails | His max lead / longest out of sight while ahead |
|---|---|---|---|
| 1 | band to band_far at 30 m (was 60), lead cap 30 m (hard clamp), out of sight 1.2 s: x0.85 | 1, 2, 2, 2 (Dễ 0 x4) | 30.0 m / 1.8 s |
| 2 | the cap only while the player rides at 6 m/s or more, never pulled back (a stopped rider must still lose) | 1, 2, 3, 3, 1, 2 | 91 m (the bot crawls tight corners at 5 m/s) / 3.6 s |
| **final** | the cap unless the player has stopped (2 m/s), past the cap x0.75, out of sight 1.0 s: x0.7 | **1, 2, 2, 2, 0, 2** (avg 1.5, 5 of 6 on target); Dễ **0, 0, 0, 0** | **30.0 m / 1.8 s** (Dễ 30.0 m / 1.3 s) |

The turn panel announced every turn of every race attempt (8-20 per mission). test_drift_duel's good bot still wins (72.9 s)
and the stopped bot is still beaten (95 s).

**Tests** (this branch): test_d2_guidance (new), test_bike_combat, test_drift_duel, test_story_day2, test_bike_feel,
test_bike_nitro, test_camera_director, test_camera_framing, test_vice_hud, test_hud_bounds, test_owner_bike,
test_readability: all SUCCESS; smoke_all_stages: all scenes OK, 0 errors; `--check-only`: 0 errors.

**Perf** (test_bike_perf alone, AC power, 6 bikers with set pieces, the guide on): chase 1.17 / 1.14 ms and chase + crowd +
traffic 2.89 / 2.94 ms (median / trimmed mean); a second run 1.06 / 1.06 and 2.77 / 2.81 ms; the same test with the guide
off 1.07 / 1.06 and 2.80 / 2.83 ms (the guide's cost is in the noise). All under 3 ms.

Known gaps:
- Thường chase: 3 of 8 sloppy-bot runs have no fail (the bot kicks most riders inside their hold window; the fails come
  from the W3 pickup, the heavy's rams and the set pieces). Making the riders harder again would undo the owner's ask.
- The radar route and red dots show in the vice art style (the default); the classic style has no radar.
- The turn panel announces real turns (35 degrees or more over 30 m); a junction the route goes straight through gets
  no arrow (the chevrons on the road show the way there).
- No screenshots (owner rule): the look of the chevrons, the panel and the arrows is unseen.
