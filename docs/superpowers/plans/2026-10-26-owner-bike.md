# Owner's bike (Agent A): plan

Spec: `docs/superpowers/specs/2026-10-26-owner-bike-and-night-lights-design.md`, OB-D1 to OB-D5, the
`tests/test_owner_bike.gd` part of OB-D7 and the README part of OB-D8. Branch `owner-bike-a`. Agent B owns
`PropBuilder.gd` and `RoamTraffic.gd`; this plan does not touch them.

## Tasks

### T1 Model (OB-D1): `scripts/OwnerBikeBuilder.gd` (new, `class_name OwnerBikeBuilder`)
- `build(root, front, rear, bar) -> Dictionary`: builds the silver and black underbone on the PlayerBike pivots
  (VisualPivot, FrontWheel, RearWheel, HandlebarPivot), so the wheels spin and the handlebar steers as before.
- Parts are named nodes: `Cowl`, `HeadlampLens` (two tiers), `Visor`, `LegShieldV`, `PositionLampL/R`, `EmblemDisc`
  (plain), `FrontFender`, `Caliper`, `Seat`, `Muffler`, `TailLight`, `Plate` (Label3D, fake `FPTU 28.05`), `StrobeRed`,
  `StrobeBlue`, wheels `Wheel` (tyre torus first, 5-spoke rim, front disc on the left side, as in the photo).
- Light materials are made per build (never the cached `PropBuilder.lens`, which traffic shares) and tagged
  `vice_done` so ViceStyle leaves them alone. The dictionary returns them: `headlamp_mat`, `tail_mat`,
  `strobe_red_mat`, `strobe_blue_mat`, plus the anchor positions `headlamp_pos` (bar space) and `strobe_pos`.
- No brand text or logo anywhere; the only Label3D is the plate.

### T2 Lights (OB-D5): `scripts/PlayerBike.gd`
- Headlight `SpotLight3D` "Headlight" on the HandlebarPivot pointing along -Z (the bug: it had yaw 180). Low beam 40 m,
  30 degrees, energy 3; high beam 70 m, 20 degrees, energy 5; soft edge, no shadow.
- `[L]` (input action `high_beam`, added by `_ensure_input_map`) calls `toggle_high_beam()`.
- `set_time_of_day(preset)`: the SpotLight is on for night, sunset and dawn; the CineFX haze cone (without its dust) is
  shown only at night. Without a call (Stage 1, Stage 2) the bike reads the scene's `visual_preset` meta once, deferred,
  so the Stage 1 dawn run gets the beam and the Stage 2 morning does not.
- Lens and tail meshes always glow. Tail brighter while braking.
- Strobe: `strobe_state(t)` static, 1.2 s cycle (3 red flashes, then 3 blue). Updated in `_process` only when the state
  changes (material energy and one OmniLight3D colour, no allocation). The OmniLight (4 m, no shadow) is shown only at
  dark presets. `NOTIFICATION_DISABLED` (the parked bike in FreeRoam) turns the strobe off and stops the horn melody.

### T3 Speed (OB-D2)
- PlayerBike constants `STAGE_PROFILE` (22.5 / 27 / 13.5, drag 0.015, the current values) and `OWNER_PROFILE`
  (33.3 / 36.1, accel 15, drag 0.0105); `apply_speed_profile(p)`, `speed_profile()`.
- FreeRoam `_build_bike()` applies `OWNER_PROFILE` (free roam and story roam). Stage 1 and Stage 2 keep the exports.
- Acceleration note: with the existing quadratic drag the old bike already reached 81 km/h in about 2.2 s, so a literal
  "0 to 100 in 5 s" would make the new bike slower off the line than the old one. The profile keeps it never slower than
  before: about 1.7 s to 81 km/h, 2.4 s to 100 km/h, 3.5 s to 120 km/h.
- Camera FOV and shake already scale with `speed / max_speed_ms`, and the yaw rate is capped by the same ratio, so the
  turn radius at 120 km/h is about 15 m. Collisions use `move_and_slide` (shape cast), so no tunnelling at 33 m/s
  (tested against a 0.1 m wall).

### T4 BikeChase balance (OB-D2)
- The bikers top out at `BikeCombatData.MAX_SPEED` 31 m/s and close in at most 8 m/s faster than the player. At 33.3 m/s
  the player would simply outrun every wave and the fight would never happen.
- Decision: the chase caps the player. `BikeChase._set_hooks(true)` saves the bike's profile and applies
  `PlayerBike.STAGE_PROFILE`; `_set_hooks(false)` (stop, lost, freed, won) restores it. The chase keeps the timing and
  AI it was tuned and tested with; raising the bikers to 40+ m/s would push the kick windows, the traffic avoidance and
  the replay past their tuning. The chase hint gains `[L] đèn xa`.

### T5 Exhaust sound (OB-D3)
- `PlayerBike.sfx_dir` (static, default `user://sfx/`), files `bike_exhaust` and `bike_horn` (`.ogg`, `.mp3`, `.wav`).
- `warm_owner_sfx()` starts one WorkerThreadPool task per file; a static cache keeps the streams. The bike polls in
  `_process` and swaps the engine stream when the loop is ready. Tests point `sfx_dir` at an empty temp folder.
- Owner loop curve: pitch 0.62 idle, 1.0 at 70 % of top speed, 1.18 at top, +0.06 under throttle; volume -10 dB idle to
  +4 dB under throttle. Without the file the old wav and curve play.

### T6 Horn and crowd (OB-D4)
- `horn_tap()` (called on the `horn` action; Stage 2 keeps reading the action for its rival): with the owner melody, a
  tap plays from the start and a tap while it plays stops it with a 0.15 s fade; without it the old short wav plays.
- The melody time is counted by the bike (`melody_left`), not the audio driver, so headless tests are exact.
- Music: `MusicDirector.duck_target` set to -8 dB while the melody plays (only when nothing else ducks), released after.
- `horn_targets_fn` (FreeRoam sets it to `pedestrians.pedestrians`): every 0.5 s, real Pedestrians within 14 m with
  `can_react_emote()` call `react_emote("clap", bike_pos, max(1, melody_left))`. An early stop calls the new
  `Pedestrian.end_react()` on the bike's dancers at once.

### T7 FreeRoam
- `_build_bike()`: `OWNER_PROFILE`. `_build_pedestrians()`: `bike.horn_targets_fn`. `set_time_of_day()`: one line
  `bike.set_time_of_day(key)`. `HINT_RIDING` gains `[L] đèn xa`.

### T8 Tests and docs
- `tests/test_owner_bike.gd`: parts and no brand text; beam along -Z; [L] toggle; SpotLight follows the time of day;
  strobe alternates and is off when parked; brake light; speed caps (owner 33.3, Stage 1 scene 22.5, FreeRoam
  `_build_bike` applies the owner profile, the chase cap and restore); no tunnelling; temp sfx folder fallbacks and an
  owner override built in the temp folder; horn tap / second tap; pedestrians within 14 m cheer, beyond do not, dancers
  stop after an early stop.
- Run: the new test, `--check-only`, `smoke_all_stages`, `test_stage1_race`, `test_near_miss`, `test_wheel_spin`,
  `test_free_roam`, `test_pedestrians`, `test_emotes`, `test_bike_combat`, `test_story_stages`.
- README: controls `[H] còi nhạc`, `[L] đèn xa`, the owner files `user://sfx/bike_exhaust` and `user://sfx/bike_horn`.
