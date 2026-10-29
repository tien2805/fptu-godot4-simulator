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
  Variant, "roam" (radar), "targets": Array (the owner's live array of enemies), "boss": Node3D (Sói Xám), "panel_half_w"})`,
  `set_active(on)`, `set_hud_visible(on)`; static `find_turns(path, length)` -> [[s_apex, dir (+1 right), deg, s_in], ...].
  - on the road: pooled glowing chevrons (one MultiMesh, about 19) every CHEV_STEP m from CHEV_NEAR to CHEV_FAR ahead along
    the path, fading in near the bike and out at the far end; heights by a cached, throttled floor ray per slot;
  - HUD (`GuideHUD`, its own CanvasLayer): the next-turn panel beside the top panel ("RẼ TRÁI 80 m", "CUA GẮT PHẢI", a
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
  - spawns: "behind" at most BEHIND_M (11 m) back, "ahead" spawns become "behind"; each arrival honks (positional) and shows
    its edge arrow; MAX_ALIVE (4, Dễ 3) riders at once, the rest wait;
  - the guide, the radar, and the combat framing while a biker is within COMBAT_CAM_M.
- **PlayerBikeCombat**: kick assist: Q / E pick the nearest kickable target on that side within ASSIST_LAT (3.5 m) and
  +/-ASSIST_ALONG (3.5 m); the target is pulled in (`magnet(to, k)` on BikerEnemy / DriftRival) through the wind-up so the
  leg connects. The counter-kick timing is unchanged.
- **DriftDuel / DriftRival**: the band caps his lead at RIVAL_LEASH_M (30 m: speed held to the player's, then a hard
  clamp), and he eases off when out of sight for RIVAL_HIDDEN_S; the guide with the boss marker; combat framing while he is
  within COMBAT_CAM_M; `rival_hidden_max` telemetry.

## Tasks

- [x] **T0 Plan** (this file).
- [ ] **T1 Camera**: CameraRules constants, BikeCamRig.set_combat_framing. Test: the eased offsets (test_d2_guidance).
- [ ] **T2 Radar**: ViceRadar guide_route + extra_blips (cached near segments like the route).
- [ ] **T3 RouteGuide**: turns, chevrons, GuideHUD (turn panel, edge arrows, boss marker), radar feed, metrics.
- [ ] **T4 Chase AI**: leash, slots in reach, hold window, sticky roles, soft separation, spawns behind with a honk, MAX_ALIVE,
  wave layout; BikeChase wires the guide and the combat framing.
- [ ] **T5 Kick assist**: PlayerBikeCombat assist zone + magnetism; BikerEnemy / DriftRival magnet().
- [ ] **T6 Race**: DriftDuel / DriftRival leash and hidden rule, the guide with the boss marker, combat framing.
- [ ] **T7 Sims**: measurements (on-screen share, max distance ahead / behind, turn arrows shown before each turn, Sói Xám's
  longest hidden stretch) in `sim_bike_chase_d2.gd` and `sim_drift_race.gd`; re-tune (Thường 1-3 fails, Dễ at most 1).
- [ ] **T8 Tests**: new `test_d2_guidance`; update `test_bike_combat`, `test_drift_duel`, `test_story_day2`; smoke,
  `--check-only`, `test_bike_perf` alone on AC power (< 3 ms).

## Results

(filled in by T7 / T8)
