# Real music everywhere: Plan

Spec: `docs/superpowers/specs/2026-10-25-horror-polish-and-real-music-design.md`, scope **H-D8, H-D9** and their tests
from H-D10. Branch `real-music` (from main 62e5d16). The horror polish runs in parallel on another branch and owns
`scripts/horror/*`, the Day 1 missions and the story night events: this branch only reads the level API.

**Owner rule:** "tuyệt đối không xài nhạc code nữa". Every music source plays `user://music/<slot>.ogg|.mp3`; a missing
file is silence. Synthesized SFX (StoryAudio cues, WeaponAudio, GameFX UI/SFX bank, the absent bell) stay.

## Architecture

- **`MusicDirector`** (rewritten, still created by GameFX as `GameFX.music`): two `AudioStreamPlayer`s on a new bus
  `MusicBed` (send to `Music`, one `AudioEffectLowPassFilter`). `play(slot)` crossfades (1.2 s) to the slot's file,
  looping; same slot = no-op (a fading-out same slot fades back in); no file = the old track fades out, silence.
  `set_tension(t)` maps to volume (-4.5..0 dB) and the low-pass cutoff (3.5 kHz at 0, open 20 kHz from 0.6), smoothed.
  Statics shared with NightMusic / tests: `SLOTS`, `slot_file`, `load_slot` (CineAudio._load_file, loop on),
  `roam_slot(tod)` (`night` -> `roam_night`, every other preset incl. sunset -> `roam_day`), `tension_db`,
  `tension_cutoff`. Test seam `test_streams` (slot -> stream) so crossfade / resume tests need no owner file.
  The procedural synth (`STYLES`, `AudioStreamGenerator`) is deleted.
- **GameFX** `music_play(slot, tension)` / `music_tension` / `music_stop` keep their signatures; callers pass slots.
- **Callers:** MainMenu / CharacterCreator `menu`; FreeRoam on foot and on the bike `roam_day|roam_night` (new
  `FreeRoam.roam_music()`; `set_time_of_day` switches it while roam music plays); StoryRoam `_music(true)` uses it;
  RoadManager `stage1_race`, Stage2-6 / StageExtra their `stage*` slot; HUDManager / Stage6 tension unchanged.
- **Missions:** StoryRoam.start_mission plays `mission_<x>` (stakeout, chase, corridor, canteen; both fights
  `mission_fight`) via `StoryRoam.MISSION_MUSIC`; `_free_mission` (win, abort) returns to the roam slot. No edit in the
  mission scripts.
- **Cinematics:** CinePlayer loads the slot file or plays without music (ready at once); the worker-thread cue,
  `music_hits`, `CineAudio.synth_cue/synth_sting/MOODS` are deleted (`mood` stays a timeline field, unused). Beat sheets
  only change the header wording "no file = silence" (regenerated with `tools/cine_beats.gd`).
- **Replays:** CineReplay uses the slot file or silence; `sting()` and its cache are deleted.
- **Stage 4:** the rhythm keeps 85/110/135 BPM; a synthesized `drum` SFX (GameFX bank) hits on every beat (2 count-in
  beats + every note), accent on the first of each 4; the owner track `stage4_vovinam` plays underneath.
- **`NightMusic`** (new, `scripts/story/NightMusic.gd`, H-D9): `level` duck-typed (`stalkers[].state`, `kit.is_hidden()`,
  `doors_unlocked`, optional `alarm`, `state`). 10 Hz state: hidden (kit hidden, or level caught/released) > escape
  (`doors_unlocked`, `alarm`, `escaped`) > chase (CHASE/CHECK) > tense (SUSPICIOUS/SEARCH) > stealth. One player per
  track (`night_stealth|tense|chase|escape`), loaded lazily, looping; 1.2 s crossfade; an inactive track is paused at 0
  gain and resumes where it left off; hidden fades every track to silence. Attached by StoryNightEscape (one line +
  node) and, for the standalone run, as a child node in `scenes/story/NightBuilding.tscn` (NightBuilding.gd untouched).
- **Docs:** `docs/cinematics/music_suggestions.md` gets the full slot table (every slot, file name, track pick; also the
  slots found in code: Day 0 cines, choice tails, replays...). README: no built-in music, tracks go in `user://music`.

## Tasks

1. MusicDirector rewrite + GameFX doc line; callers (menu, roam, stages, story roam, missions).
2. CineAudio / CinePlayer / CineReplay / CinePreview / CineTimeline header: drop synthesized music; regenerate beat sheets.
3. Stage 4 drum beat.
4. NightMusic + StoryNightEscape hook + NightBuilding.tscn child.
5. Tests: new `tests/test_music_slots.gd` (slot resolution, no synth path static + runtime, crossfade, tension mapping,
   roam day/night, NightMusic with a fake level); rewrite `test_music`; update `test_cine_audio_fx`, `test_cine_player`,
   `test_cine_replay`, `test_story_cines`, `test_stage4_vovinam` (drum grid).
6. Docs; `--check-only`, affected tests, smoke, full regression; commit.

## Risks

- Owner files exist in `user://music` on this machine: every test accepts "file or silence" and never writes there.
- Large MP3 read on the main thread when a slot changes (~5 MB `get_file_as_bytes`, a few ms); OGG streams.
- The horror branch may rename stalker states or add `alarm`: NightMusic reads them with `get` / `in` checks.
