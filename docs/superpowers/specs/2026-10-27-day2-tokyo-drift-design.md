# Ngày 2 "Tokyo Drift": design

Date: 2026-10-27.

**Owner feedback** after playing Phase C: "các màn trong phase này chưa đủ thú vị, chưa đủ wow ... dễ và nhàm chán quá, nhất là đoạn đua xe mà tôi kỳ vọng. đoạn đó có tokyo drift đúng không".

**The owner picked every Day 2 idea:**
- Tokyo Drift and a film-style opening;
- drift with nitro and a 360 spin kick;
- road set pieces and harder enemies;
- a drift race against Sói Xám.

**Order:** "làm ngày 2 trước nhưng chuẩn bị plan cho việc sửa những ngày còn lại". Days 3 and 5 and the shared items are planned only, in `2026-10-27-phase-c-wow-days-3-5-design.md`.

**Parents:**
- Phase C spec `2026-10-26-story-phase-c-days-2-3-5-design.md` (C-D1, C-D6);
- owner bike spec `2026-10-26-owner-bike-and-night-lights-design.md`.

## 0. What is wrong now (measured)

- **Too short.** The chase is 850 m southbound from Nguyễn Văn Tăng to the Rạch Hầm bridge, about 40 s at the chase cap of 22.5 m/s.
- **Too easy.** There are 2 waves of 3 identical riders, with at most 2 attacking at once, and an enemy kick costs 20 of 100 stability.
- **No music while riding.** The slot `mission_bike_chase` waits for "Gas Gas Gas", which the owner has not downloaded. Tokyo Drift (`seg_d2_chase`, the owner's full 243 s file) plays only in the 5 s replay at the end.
- **Nothing happens on the road**, and drifting has no use.

**Target:**
- a chase of about 2 minutes, plus a drift duel of about 1 minute;
- something new every 15-20 s;
- an attentive first-time player fails 1-2 times.

## 1. Decisions

### D2X-1 Route

The chase runs the Stage 1 real route (`md.route_points(0.0)`) from Anh Duy's corner at BE6 (the `d2_chase` marker `duy_corner`) to the Rạch Hầm bridge.

- **Length:** 2389 m to the bridge middle (measured 2026-10-27 with `BikeRoute.from_points` and `find_bridge_s`).
- **Real sharp turns** (62-94° within 30 m), on the Vinhomes roads, Cầu Vồng 5 and the turn onto Nguyễn Xiển: s ≈ 480, 580, 745/790, 890/945, 1255, 1400 and 2250.
- **End:** the chase ends 30 m past the bridge middle, as now.
- **Code:** `MissionBikeChase.day2_route` changes to this route. The bridge anchors (`bridge_road`, `bridge_bank`) stay.

### D2X-2 Speed

| Who | Values |
|---|---|
| Chase profile | max 27.8 m/s (100 km/h), slipstream 30.6 m/s |
| Nitro (D2X-8) | +8 m/s on top of the profile max |
| Bikers | top speed raised to about 32 m/s so they keep up; heavies are slower |

The owner profile is restored on stop, exit, lost and retry, as now.

### D2X-3 Film opening and music

**Music:**
- `mission_bike_chase` plays Tokyo Drift. Claude installs a local copy of the owner's file as `user://music/mission_bike_chase.ogg`, outside the repo.
- The track starts at 0 when the chase starts. The file opens on the hook "I wonder if you know how they live in Tokyo".

**Opening:**
- **Slow motion from 0 to `OPEN_DROP_S`:** about 0.35×, the music at normal speed.
  - The camera sits low behind the bike, with letterbox bars.
  - The line "Tới công chuyện luôn!" shows.
  - The player can already steer.
- **`OPEN_DROP_S`:** the first strong downbeat after the hook line, found in the owner's file with `<scratchpad>/beatfit/peaks.py`. Default 4.0 s, kept as a tunable constant.
- **At the drop:**
  - time snaps back to normal, with a camera shake;
  - wave 1 bursts out of the side roads, LED eyes flaring and horns blaring.

**Replay:** the replay after the last biker must not restart the song. It uses no slot of its own, so the chase track keeps playing under it.

**Wave 3:** if `user://music/mission_bike_chase_b` exists, crossfade to it (suggestion for the owner: "Gas Gas Gas" – Manuel). Otherwise Tokyo Drift continues.

**No file at all:** silence (no code music). The opening still runs on the constant.

**Time scale:** every slow motion restores the time scale on stop, retry, lost, exit and scene change. Tests check that it is never left below 1.

### D2X-4 Waves and enemy types

**Waves:**
- 3 waves, 12-14 vehicles in total.
- Up to 3 attackers at once (4 in wave 3), with attacks at least 0.6 s apart.
- Every type has a clear silhouette and a readable telegraph.

| Type | Look | Attack | Counter |
|---|---|---|---|
| rider | as now | flank and kick, 22 dmg | kick |
| stick | raised wooden stick | swing after a 0.5 s wind-up (stick up, whoosh), 25 dmg | brake or steer out; a kick during the wind-up interrupts it |
| thrower | 2 on one bike | the pillion throws a helmet in an arc, red road marker 0.8 s before it lands, 15 dmg | steer out of the marker; a kick drops both |
| heavy | bigger loud tuned bike | shoulder ram, 30 dmg | 3 kicks, or one nitro ram |
| pickup | the gang's pickup truck, cannot be kicked | side ram telegraphed by horn and headlight flash 1.0 s, 35 dmg | dodge; it hits a pole or traffic: takedown |

**Suggested layout:**
- **W1** (Vinhomes turns): 3 riders and 1 stick.
- **W2** (Cầu Vồng 5, Nguyễn Xiển): 2 riders, 1 stick, 1 thrower and 1 heavy.
- **W3** (after the cameo, to the bridge): 2 riders, 1 heavy, 1 thrower and the pickup.

**Damage and stability:**
- Traffic collisions cost 15-25 by speed.
- Stability is 100, with no regeneration. A cleared wave gives back 25.
- Each wave is a checkpoint, as now.

**Balance:** with normal play, the chase is winnable before the bridge. Escaping riders still end it as now.

### D2X-5 Takedowns

**Triggers:** a biker crashing into scenery, traffic, a pole or a melon, a nitro ram, a spin kick hitting 2 riders, or an air kick.

**Effect:**
- 0.5 s of slow motion and a quick side camera cut;
- a popup that rotates through "TAKEDOWN!", "BAY MÀU!" and "ĐI ĐÂU VỘI THẾ EM?";
- a takedown counter in the chase HUD;
- comic tumbles and stars only.

**Fairness:**
- at most one takedown slow motion every 3 s;
- none while 2 or more attackers are winding up near the player.

Each takedown adds 15 nitro charge (D2X-8).

### D2X-6 Set pieces

Set pieces come one every 15-20 s. They are a data list keyed by route distance; each has a telegraph, and each re-arms on retry.

1. **Watermelon truck** (Vinhomes or Cầu Vồng 5).
   - A truck ahead hits a bump, its tailgate drops, and 20-30 watermelons roll and bounce across the lanes for about 5 s.
   - The melons are pooled and kinematic or animated, not a RigidBody swarm.
   - A melon hit costs 10, plus a wobble and a comic splash of green and pink chunks.
   - Bikers who hit melons crash (takedown).
2. **Barrier and pipe** (construction on Nguyễn Xiển).
   - A half-lowered barrier arm or a hanging pipe crosses the road at chest height.
   - Warning signs stand 80 m before it, with the prompt "[CTRL] CÚI XUỐNG".
   - Holding Ctrl ducks flat (D2X-9). Not ducking knocks the player off: fail, back to the checkpoint.
   - A slow gap by the curb exists for players who brake.
3. **Wrong way.**
   - Road works close the player's carriageway for about 250 m, marked by cones and flashing arrows.
   - The route forces the player across a median gap into oncoming traffic, and the bikers follow.
   - Near misses give 8 nitro charge each.
4. **Sand ramp** (by a construction site).
   - A marked sand ramp in one lane. Hitting it above 20 m/s starts a scripted jump of about 1.2 s, slowed to 0.4× in the air. The landing is always safe.
   - A biker alongside is airborne too. A kick in the air is an "AIR KICK" takedown.
   - The ramp is optional.
5. **Police** (wave 3).
   - 2 police vehicles with sirens join for about 25 s and ram bikers and the player alike.
   - No stars and no arrests. They drop back before the bridge.
   - They reuse the Phase W police models without the WantedDirector.
6. **Forced drift corners.**
   - 3-4 of the real Vinhomes turns become drift zones, marked with chevrons and the prompt "DRIFT!".
   - Taking one fast without drifting runs wide into the curb: 10 damage and a slowdown.
   - Drifting through a zone fills nitro 1.5× faster.

### D2X-7 Sói Xám cameo

**When:** after wave 2, on Nguyễn Xiển (around s ≈ 1400-1600).

**What happens:**
1. Sói Xám rides up from behind on a grey tuned bike: his StoryCast look on a scripted rider that cannot be attacked.
2. He wheelies past.
3. The villain card "Sói Xám – đầu đàn Bầy Sói" freezes the frame. This is his first appearance, so the card moves here from MissionBridge, which no longer shows it.
4. He taunts: "Muốn biết hàng về đâu thì lên cầu Rạch Hầm mà hỏi!"
5. He fires his nitro (blue flame) and pulls away.
6. Wave 3 starts with the music switch (D2X-3).

### D2X-8 Drift meter and nitro

**Charge** (`drift_charge`, 0-100):
- about 25 per second while drifting, 1.5× in a drift zone;
- +15 per takedown;
- +8 per near miss.

**Firing:**
- Shift fires nitro when the charge is at least 34.
- It spends the whole charge for 3 s × charge/100.

**While nitro runs:**
- +8 m/s above the profile max and stronger acceleration;
- a blue exhaust flame (CPUParticles3D plus an emissive cone), FOV +8 and a synthesized whoosh.

**Nitro ram:** touching a biker during nitro is a takedown (the heavy included). The pickup is immune.

**The existing drift release boost** (+4 m/s for 1 s) stays.

**Where nitro is on:** free roam on the owner's bike, the chase and the duel. Stage 1 and Stage 2 never turn it on.

**Gauge:** a small gauge shows whenever nitro is enabled and the bike is ridden. It is a self-contained control created by the bike side, so the chase gets it with no BikeHUD change.

### D2X-9 Spin kick and duck

**Spin kick:** Q or E while drifting.
- The rider spins and hits every biker within 3.6 m on both sides, up to 2.
- A 0.15 s hit-stop, then a 1.2 s cooldown.
- It uses the normal kick hit path.

**Duck:** hold Ctrl while riding.
- The rider lies flat on the tank: steering -10 %, a little less drag.
- The barrier set piece reads it through `is_ducking()`.

### D2X-10 Drift duel with Sói Xám

A new beat, `d2_drift`, between `d2_chase` and `d2_bridge`.

**Start:**
1. After the replay, a fade.
2. The bridge deck is empty (traffic cleared nearby), and Sói Xám waits beside his bike: "Đua một vòng. Thắng thì tao nói hàng về đâu."
3. A 3-2-1 countdown, with headlights.

**Course:**
- About 1.2-1.6 km and 50-75 s, on real roads by the bridge plus cones and barriers.
- Example: off the bridge along Nguyễn Văn Tăng through the real 114° turn (s ≈ 2685 on the route), cone chicanes, a hairpin U-turn around a cone island, then back to finish on the bridge.
- At least 5 drift zones.
- Barriers stop shortcuts. Leaving the course resets the player to the last gate.

**Rules ("bám đuôi"):**
- **Sói Xám leads.** He is a route-following rider with visible drifts. He is rubber-banded: never more than about 35 m ahead unless the player crashes.
- **The gap:**

  | Gap | Effect |
  |---|---|
  | ≤ 12 m | drift points ×2, "BÁM ĐUÔI!" |
  | 12-35 m | normal |
  | > 40 m for 3 s | lose |

- **Points:** drift time × speed inside zones.
- **Win:** finish with at least the target points (tunable), or overtake him and stay ahead for 4 s ("VƯỢT MẶT!", an instant win).
- **Lose:** quick retry at the duel start, with a fade of 0.5 s at most.

**Music:**
- slot `race_d2_drift`. Claude installs a local copy of the owner's "Deja Vu" there; "Running in the 90s" – Max Coveri is the alternative suggestion.
- Without the file, the chase track keeps playing.

**End:**
1. He loses: "Hự... được, xuống gầm cầu tao nói."
2. He rides down into the fog under the bridge.
3. A fade, then `d2_bridge`. The horror beat stays: the fog, the howl, his pack's LED eyes in the dark, his ringtone gag.
4. Then the unchanged fist duel.

**Saves:** Chọn cảnh lists the new beat and can rewind to it. Saves sitting at `d2_bridge` or later stay valid.

### D2X-11 Text

- Vietnamese, plain, no emoji.
- Kept memes: "Tới công chuyện luôn!" at the opening, and "Đỉnh nóc kịch trần bay phấp phới" when the chase is won.

### D2X-12 Perf

- `test_bike_perf` "chase + crowd + traffic", now with set pieces, melons and police, stays under 3 ms (today 1.97 ms).
- The drift duel gets a case too.
- No per-frame allocation, and pooled props.

### D2X-13 Tests

**Agent A:**
- `test_bike_combat` extended:
  - each enemy type's telegraph and counter;
  - the attacker caps;
  - the takedown slow-motion rate limit;
  - set pieces trigger at their distance and re-arm on retry;
  - the barrier against a ducking stub;
  - the police event;
  - the time scale restored.
- the chase part of `test_story_day2` (route BE6 → bridge, the cameo card, the music slots);
- `test_bike_perf`.

**Agent B:**
- `test_bike_nitro`:
  - charge sources and the Shift gate;
  - nitro speed and duration;
  - the ram flag;
  - the spin kick hitting both sides;
  - duck;
  - nitro off in Stage 1 and Stage 2.
- `test_drift_duel`: gates, losing on the gap, winning on points, winning by overtaking, retry and the music fallback.
- the drift part of `test_story_day2`;
- `test_chapter_select` with the new beat.

## 2. Work split

Two agents in parallel worktrees from main, effort xhigh (combat).

### Agent A "d2x-chase": D2X-1 to D2X-7, D2X-11, D2X-12

**Owns:**
- `scripts/combat/bike/BikeChase.gd`, `BikerEnemy.gd`, `BikeCombatData.gd`, `BikeRoute.gd` and `BikeHUD.gd`;
- new set-piece files under `scripts/combat/bike/`;
- `scripts/story/missions/MissionBikeChase.gd` and `MissionBridge.gd`;
- its tests.

### Agent B "d2x-drift": D2X-8 to D2X-10

**Owns:**
- `scripts/PlayerBike.gd`, `scripts/combat/bike/PlayerBikeCombat.gd`, the new nitro gauge;
- new `scripts/combat/bike/DriftDuel.gd` and the rival rider;
- new `scripts/story/missions/MissionDriftDuel.gd`;
- `scripts/story/StoryMissions.gd`, `StoryRoam.gd`, the FreeRoam riding hint and the chapter-select beat list;
- its tests.

### Interfaces

Both agents code against these. A guards each with `has_method` and stubs them in its tests.

- `PlayerBike.set_nitro_enabled(on: bool)`
- `PlayerBike.nitro_active() -> bool`
- `PlayerBike.drift_charge: float` (0-100)
- `PlayerBike.add_drift_charge(points: float)`
- signals `nitro_started` and `nitro_ended`
- `PlayerBike.is_ducking() -> bool`
- `apply_speed_profile` unchanged
- `PlayerBikeCombat`: the spin kick reports each target through the existing kick hit path and signal, with side 0 meaning a spin.

### Shared files and merge

- Neither agent edits the other's files.
- `test_story_day2`: A edits the chase part and B adds the drift part. Claude resolves the conflict at merge.

**After both finish:**
1. One read-only review per branch (effort high), then one fix round.
2. Merge both into branch `d2x` and run the combined tests and the perf gates on AC power.
3. Merge into main with `--no-ff`.
