# Owner's bike, Subaru horn and night lights: design

Date: 2026-10-26. Owner request (during the Phase C regression): "tôi muốn đổi xe trong game ... làm xe nhanh hơn và có đèn đi ban đêm". Owner answers:
- "tôi muốn lái xe riêng do tôi cung cấp ảnh và âm thanh pô"
- "tốc độ khoảng 120km/h", "chỉ xe tôi lái thôi"
- "đít xe phải có đèn nháy xanh đỏ"
- "còi subaru đánh theo nhạc trong file này ... khi mà bấm kèn subaru thì những người đứng gần sẽ giơ 2 tay lên trời đứng nhảy nhảy"
- Lights: the player's bike and the traffic.

Reference photo: an underbone (xe số) in silver and black, seen from the front three-quarter view. It has:
- a handlebar cowl headlight;
- a black center V panel on the leg shield, with two small red lamps;
- a silver front fender;
- a front disc brake and 5-spoke alloy wheels;
- a long black seat;
- a long black aftermarket muffler on the right side.

The photo is kept outside the repo; agents get its description from this spec.

## Decisions

### OB-D1 Model

`PlayerBike` gets the owner's bike instead of the scooter. The model is built in code (PropBuilder style). There are no AI images, no brand text or logo, and the license plate is fake (`FPTU 28.05`).

**Parts:**
- **Handlebar cowl:** silver-white. A clear two-tier multi-reflector headlight lens, a black top visor, clear turn signals at the cowl sides and black grips. No mirrors (the photo has none).
- **Leg shield and front end:**
  - silver side panels;
  - a black center V panel holding two small red position lamps on either side of a plain dark disc where the emblem was;
  - a silver front fender, chrome fork, front disc and caliper.
- **Wheels:** 5-spoke silver alloy rims, narrow black tires. The wheel and handlebar pivots of the scene stay as they are, so the wheels spin and the handlebar steers as before.
- **Body:** silver flank panels with a black stripe, a black frame and underbody, a dark grey engine and chrome foot pegs.
- **Seat:** a long black seat with no text.
- **Exhaust:** a long black muffler on the right, tilted slightly up at the end.
- **Rear:**
  - a red tail light;
  - the fake plate;
  - a strobe bar under the tail: one blue and one red LED strip (see OB-D5).
- **Rider:** unchanged (the protagonist from `StoryUtil.hero_opts`).

**Scope:**
- The model applies everywhere `PlayerBike` is used: Stage 1 race, Stage 2 parking, free roam, story roam and the Phase C bike chase if it uses `PlayerBike`.
- Cinematic scooter props (`CineFX.build_prop("scooter")`) are unchanged in this phase. Using this bike in cinematics is a follow-up.

### OB-D2 Speed: player bike only

- **Free roam and story roam** (set by `FreeRoam` on its bike):
  - `max_speed_ms` 33.3 (120 km/h);
  - slipstream max 36.1 (130 km/h);
  - `engine_accel` raised so 0 to 100 km/h takes about 5 s.
- **Stage 1 race and Stage 2 parking** keep their current values. Stage 1 is tuned to its 90 s clock.
- **Traffic:** unchanged.
- **Camera and controls:** the camera FOV and shake scale with the new max. Steering stays controllable at 120 km/h.
- **Collisions:** no tunnelling through walls, traffic or the canal guard at 33 m/s. Test this.
- **Phase C bike chase:** check its balance against the faster bike. Either the chase caps the player at its own top speed or the enemy bikers keep up. Pick whichever keeps the fight fun and document it in the plan.

### OB-D3 Exhaust sound (owner file)

`user://sfx/bike_exhaust.ogg` (else `.mp3`, else `.wav`; local only, never committed or exported). It is already installed: a 6.2 s seamless loop cut from the steady loud part of the owner's clip.

- **Loop and pitch:** the engine player loops it with this pitch curve:
  - 0.62 at idle;
  - 1.0 at about 70% of top speed;
  - 1.18 at top speed;
  - +0.06 under throttle.
- **Volume:** -10 dB at idle, +4 dB under throttle.
- **Fallback:** without the file, the current `res://assets/audio/bike_engine_loop.wav` plays with the current curve.
- **Loading:** load the file once on a worker thread. A short cache is fine, as in StoryAudio / MusicDirector.
- **Tests:** point the sfx folder at an empty temp folder, so they never depend on the owner's files.

### OB-D4 Subaru horn and the dancing crowd

**File:** `user://sfx/bike_horn.ogg` (else `.mp3`, else `.wav`; local only). It is already installed: the 19.2 s horn melody, trimmed.

**Controls** (`horn` action, H or B):
- A tap plays the melody from the start.
- A tap while it plays stops it, with a 0.15 s fade.
- Without the file, the current short `bike_horn.wav` plays as before.
- The Stage 2 rival-horn logic still triggers on the tap.

**Music:** roam music ducks by about 8 dB while the melody plays, through MusicDirector's duck.

**The dancing crowd:**
- Every 0.5 s while the melody plays, real pedestrians (not crowd impostors) within 14 m of the bike react, but only if `can_react_emote()` returns true.
- They call `Pedestrian.react_emote("clap", bike_pos, secs)`, where `secs` = the melody time left (at least 1 s). That plays the cheer clip: both arms up, bouncing on the knees.
- People who walk into the radius later join in.
- When the melody stops early, the dancers stop within 0.5 s. Add a small `end_react()` on Pedestrian if needed.

**Not affected:** officers, story cast, enemies, and people who are fleeing, down or already reacting.

### OB-D5 Player bike lights

- **Headlight fix:** the beam must point forward. The current SpotLight3D in `_build_procedural_bike_and_seated_rider` has `rotation_degrees.y = 180`, so it shines backward.
- **Beams:**

  | Beam | Range | Angle | Energy |
  |---|---|---|---|
  | Low (default) | about 40 m | about 30° | about 3 |
  | High | about 70 m | about 20° | about 5 |

  Both beams have a soft edge (`spot_angle_attenuation`) and no shadows. **[L]** toggles low and high. The riding hint gains "[L] đèn xa". Plain text, no emoji.
- **Day and night:**
  - The lens and tail meshes are always lit, like an always-on headlight.
  - The real SpotLight3D is on only for the dark presets: night, sunset and dawn.
  - At night a faint additive haze cone sits in the beam. Reuse the CineFX headlight haze if it fits.
- **Tail and brake:** a red emissive tail light that is brighter while braking.
- **Strobe bar:**
  - The blue and red strips flash in a police pattern: about 3 quick red flashes, then 3 quick blue flashes, about 1.2 s per cycle.
  - They flash while the bike is ridden and are off when it is parked.
  - At dark presets, one small OmniLight3D (range about 4 m, no shadow, low energy) follows the active colour to splash the road.
  - Emissive flashing only, with no full-screen flashes.
- **Perf:** no per-frame allocation. The flash is a timer plus material energy changes on shared materials.

### OB-D6 Traffic lamps at night

- **Lamps:** every traffic MOTO, CAR and BUS (police included) gets white headlamps and red tail lamps. Police siren lamps stay as they are.
- **Day and night:** lamps are lit at dark presets (night, sunset, dawn) and dim by day.
- **How:** use shared lens materials switched once per time-of-day change, at no per-vehicle cost.
- **Light pool:** optionally a soft additive unshaded light pool on the road ahead of near-LOD cars and buses at night.
- **Perf:** no real lights on traffic. `test_mayhem_perf` stays under 3 ms.

### OB-D7 Tests

**`tests/test_owner_bike.gd`:**
- The model parts exist and contain no brand text.
- The headlight points forward: the beam direction in bike space is -Z.
- [L] toggles the beam.
- The SpotLight follows the time of day.
- The strobe alternates red and blue, and is off when the bike is parked.
- The brake light brightens while braking.
- Speed caps: free roam 33.3 m/s; Stage 1 still 22.5 m/s.
- No tunnelling through a wall at top speed.
- Owner overrides use a temp sfx folder, and the fallbacks work without files.
- The horn: a tap plays, a second tap stops.
- Pedestrians within 14 m cheer, people outside it do not, and the dancers stop after an early stop.

**`tests/test_traffic_lamps.gd`:** lamps are lit at night, dim by day, and use shared materials.

**Existing tests:**
- Run the existing tests that touch PlayerBike, FreeRoam, RoamTraffic and Pedestrian.
- Run the perf gates on AC power.

### OB-D8 Docs

- **README:** add the controls, "[H] còi nhạc" and "[L] đèn xa", and note the owner files `user://sfx/bike_exhaust` and `user://sfx/bike_horn`.
- **`docs/cinematics/music_to_download.md`:** note that both bike files are installed.

## Order

1. Start after Phase C merges into main, because Phase C touches FreeRoam and RoamTraffic.
2. Work on branch `owner-bike`, with two agents in parallel:
   - Agent A, effort high: OB-D1 to D5 plus the tests. The model goes in a new `scripts/OwnerBikeBuilder.gd`, so PropBuilder stays Agent B's file. Agent A also changes PlayerBike, FreeRoam and Pedestrian.
   - Agent B, effort high: OB-D6, on RoamTraffic and PropBuilder lamps.
3. One review each, then a fix round.
4. Merge, run light tests and the perf gates on AC, then merge into main with `--no-ff`.
