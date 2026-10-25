# Horror polish (H-D1 to H-D7): Implementation Plan

Spec: `docs/superpowers/specs/2026-10-25-horror-polish-and-real-music-design.md` (H-D1 to H-D7, their tests from H-D10).
Branch `horror-polish`, base 62e5d16. A parallel branch owns the music side (H-D8, H-D9: MusicDirector, CineAudio music,
CineReplay stings, the `NightMusic` node in `StoryNightEscape.gd`), so this branch never touches those files and adds no
music. Synthesized SFX are fine (StoryAudio).

**Global constraints.** Pure GDScript, Godot 4.7.2, no plugins, CPUParticles3D only, code-built models; no dynamic light
in the Night Building except the flashlight (SOS = emissive energy and colour); plain Vietnamese UI text, no emoji or
decorative symbols; fictional names; no gore; class_name scripts reach autoloads only through `get_node_or_null`
(`StoryUtil`); every scare honours "Giảm hù dọa" and the ScareDirector budget; `test_horror_perf` < 3 ms.

**API kept for the music side.** `NightBuilding.state`, `doors_unlocked`, `kit.is_hidden()` / `kit.hidden_spot`,
`stalkers[i].state` keep their names. New, documented in the NightBuilding header: `alarm` (bool) and signal
`alarm_started`, `dolly` (the Dolly stalker), `kit.breath_held`.

## Task 1 – New SFX cues (StoryAudio)

Files: `scripts/story/StoryAudio.gd`, `tests/test_story_audio.gd`.
- A `POLISH` cue list (not in `CUES`, so the 17 owner cues stay): `dolly_hum` (hummed music-box figure, loops),
  `gasp`, `alarm_siren` (loops), `cat_meow`, `bin_crash`, `locker_slam`, `rustle`. All count as horror cues (-6 dB with
  "Giảm hù dọa"), all have owner overrides like the others.
- Test: each synthesizes within its length range, loop flags right.

## Task 2 – Dolly hunts (H-D1)

Files: `scripts/horror/HorrorStalker.gd`, `scripts/horror/NightBuilding.gd`.
- `HorrorStalker.speed_mult` (Dolly 1.12), `make_dolly()`: StoryCast `dolly` look (cream cardigan, cuff), the sheep mask,
  a positional `AudioStreamPlayer3D` hum loop (`dolly_hum`, max 32 m, -6 dB reduced), `set_hum(on)`.
- NightBuilding: a seeded one of the four stalkers is Dolly (`dolly`); the hum stops on release / escape.
- Tests: one Dolly among four, the look and speed, the hum player (looping stream, positional, quieter when reduced).

## Task 3 – Staged catch scares (H-D2)

Files: `scripts/horror/ScareDirector.gd`, `scripts/horror/NightBuilding.gd`, `scripts/horror/HorrorHUD.gd`.
- `play_catch_scare(spot_kind)`: "desk" (face lowers upside down from above), "locker" (face at the slats, then the door
  yank clears the slats and the face pushes in), "stall" (camera tilts up, the face rises over the partition), "open" (the
  face lunges at the camera); 1.2 s, camera-relative each frame, a sting per kind; signal `catch_beat(name)`.
- Reduced: soft sting (metal_creak), a fade to dark, no face, no screech, no shake.
- NightBuilding passes the hidden spot's kind, clears the peek overlay on the yank, shows the caught card after the scare.
- Tests: each kind (face shown, motion relative to the camera, upside down for the desk, cues), each reduced variant.

## Task 4 – Heartbeat and edge pulse (H-D3)

Files: `scripts/horror/ScareDirector.gd`.
- `heart_bpm_for(dist, reduced)`: off beyond 14 m, 70 BPM at 14 m to 160 BPM within 2 m (reduced: capped at 110), beats
  scheduled one by one (not pitch-shifted), volume rises as the hunter nears (+3 dB hidden, -6 dB reduced).
- A screen-edge pulse (code-built radial gradient) on every beat while hidden.
- Tests: the BPM curve, the cap, beats counted over time, the pulse only while hidden.

## Task 5 – Hold breath (H-D4)

Files: `scripts/horror/HorrorKit.gd`, `scripts/horror/HorrorStalker.gd`, `scripts/horror/HorrorHUD.gd`, `NightBuilding.gd`.
- Shift while hidden holds breath: `breath_left` 0..6 s, refills 1 s per s; `breath_held`.
- A hunter within 3 m of the spot for 0.5 s hears the breathing unless it is held; running out, or releasing within 2 m,
  gasps: the nearest hunter `investigate_spot(spot)` (CHECK, catches if the player is still inside).
- HUD: breath bar and "Giữ Shift: nín thở" while hidden; the breath loop is silent while held.
- Tests: drain and refill, heard at 3 m, held = not heard, gasp on empty and on release near, the check and catch.

## Task 6 – SOS lights, alarm and the escape sprint (H-D5)

Files: `scripts/horror/SosLights.gd` (new), `NightBuildingMap.gd` (exposes `corridor_lights`), `NightBuilding.gd`,
`ScareDirector.gd` (`drop_light_groups`).
- `SosLights`: the pattern as data (dot 0.2, dash 0.6, gap 0.2, letter gap 0.6, word gap 1.4: 6.8 s loop), `is_on_at(t)`;
  drives the corridor emissive materials red; reduced: a slow red pulse, never dark.
- Third fuse: `alarm = true`, `alarm_started`, the `alarm_siren` loop, every hunter `rush(player)` (re-issued every 1.5 s,
  one per physics frame; held for 3 s after a retry), the open doors.
- Tests: the timing pattern, the lights following it, the reduced pulse, the alarm flag and siren, hunters rushing.

## Task 7 – Fake-outs (H-D6)

Files: `scripts/horror/HorrorFakeouts.gd` (new: coat and cat props), `NightBuilding.gd`, `ScareDirector.gd`
(`try_fake_out`, `fake_budget`, `fake_gap_s`).
- Seeded 1-2 per run: a coat-on-hook silhouette in a classroom (flashlight catches it: sting, then "... cái áo khoác.");
  a code-built cat by a corridor bin (player near: the bin falls, a meow, the cat runs; the hunters within 18 m hear it).
- Tests: seeded count 1-2, the budget, the coat trigger only when lit, the cat noise event.

## Task 8 – Other night scenes (H-D7)

Files: `scripts/story/missions/MissionStakeout.gd`, `MissionCorridor.gd`, `scripts/story/StoryNightEvents.gd` (new),
`scripts/story/StoryRoam.gd` (adds the node; nothing else).
- Stake-out: at 18 s a rustle behind, then Lu trots up from behind (fake-out, once per mission).
- Corridor: at 40 % a locker bursts open and a sheep mask falls out (before the blackout).
- Free roam at night (Day 1+, story night, no mission, no cinematic, no busy beat, not wanted): one event per 3 min at
  most: a far sheep figure under a lamp (gone within 25 m or out of view), the "Số lạ" photo text (once per day), rarely a
  clone sprinting across in the bike headlight.
- Tests: Day 1 events in `test_story_day1`; cadence, the no-mission / no-cinematic / day rule, the figure vanish rule in
  `test_story_director`.

## Task 9 – Verification

`test_horror_toolkit`, `test_night_building`, `test_horror_perf` (< 3 ms), `test_story_day1`, `test_story_day4`,
`test_story_director`, `test_story_audio`, `--check-only`, smoke.
