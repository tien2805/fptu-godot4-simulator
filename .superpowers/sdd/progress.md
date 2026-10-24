# Story Phase A2 - SDD ledger

| Task | Commit | Tests | Notes |
|---|---|---|---|
| Plan | (this commit) | - | docs/superpowers/plans/2026-10-24-story-phase-a2.md |
| 1 StoryDirector, StoryMissions, StoryUtil, save | 844101e | test_story_director | autoload after StageManager; evaluate_ending table |
| 2 Settings, sunset, StoryAudio | 13175c2 | test_story_audio, test_cine_timeline, test_cine_audio_fx, test_vice_style | 17 cues + call_hangup; CineAudio.sfx fallback |
| 3 Character creator | 3e4b5a5 | test_character_creator, test_character_builder, test_ps2_head, test_ps2_people | variant reaches PS2 head (vice only); player outfit fixed |
| 4 Main menu, pause settings | 51518e1 | test_main_menu, test_hud_bounds | pause Giảm hù dọa joins the style row (card < 720 px) |
| 5 Phone, 3 a.m. call | b5fbc24 | test_story_phone, test_story_call | phone closes on P/Esc in _input before the pause key |
| 6 Day 0 cinematics | 20f49f5 | test_story_cines, test_cine_d1_brawl, test_cine_player, test_busted, test_cine_audio_fx | 4 slots + beat sheets; brawl test now picks its F9 slot |
| 7 StoryRoam + FreeRoam hook | d5c4142 | (test_story_day0) | cine_stage "at"; rider + busted hero = protagonist |
| 8 Stages in the story | 1e5b4de | test_story_stages, test_stage_extra_eos, test_stage1_race, test_free_roam | replays before the result; Stage 1 recorder created deferred |
| 9 Day 0 end to end | 5d4579d | test_story_day0 | fixes: HUD restore after call, story HUD hidden in cinematics (UIWatch), forward only the beat's stage, no hub [M] mid-mission |
| 10 Docs + regression | (this commit) | full regression: 61/64 + smoke; perf, free_roam, weapons_core fail identically on base f5ef496 (laptop on battery) | README Cốt truyện TOOL ĐEN, PLAN XVI, spec Status |
Agent report: 10 tasks done (ce0e94b..c0ed19b). Regression 61/64 + smoke green; test_mayhem_perf / test_free_roam / test_weapons_core fail identically on base f5ef496 with the laptop on battery (perf W1 3.60 vs base 3.90 ms) -> re-run on AC power. 4 area reviews dispatched (opus high, read-only): R1 = T1+T2+T4, R2 = T3+T5, R3 = T6, R4 = T7-T9; diffs .superpowers/sdd/review-A2-R*.diff.
Reviews: R1 Needs fixes (3 Imp: batch warm stall, overwrite confirm focus, day-beat text stamp), R2 Needs fixes (2 Imp: phone leaks roam input, phone can freeze controls), R3 Needs fixes (8 Imp: intro cards one-letter wrap, sheep hidden, held props hang, bench sit floats, Mr.T walks backward, short subs, undecodable video hangs, roam music under video), R4 Needs fixes (3 Imp: Ctrl/Shift+Tab hub in story, race finish after fail, [E] with phone/map open). Fix round sent to the implementer (all Importants + cheap minors).
| Fix round (R1-R4) | b6604b4, 87249cb | test_story_director, test_story_audio, test_main_menu, test_character_creator, test_story_phone, test_story_call, test_story_cines, test_story_stages, test_story_day0 | all 16 Importants fixed + listed Minors; per-cue warm tasks, phone owns the keyboard, hub/replay/marker guards, hold_up / sit_bench / nod poses, cards layout, video fallback |
| A2-D17 | aa336a8 | test_story_cines (6 slots), test_story_director, test_story_day0 | cine_d0_brief (mission intro once on [E], retry skips), cine_day_start template + StoryDayCard; d1_start -> d1_morning |
| Final regression | (this commit) | 60/60 tests + smoke green (a2_fix_logs), AC power (PowerOnline True); perf W1 1.92/1.95 and 2.48/2.48 ms, W2 2.10/2.11 and 2.76/2.77 ms | battery-only failures of the first round gone |
Fix round (implementer): b6604b4, 87249cb (all 16 Importants + listed minors), aa336a8 (A2-D17 cine_d0_brief + cine_day_start), d533374. Regression on AC power 60/60 + check + smoke; perf W1 1.92/1.95 and 2.48/2.48 ms, W2 2.10/2.11 and 2.76/2.77 ms. Controller spot-checked the fix diff + logs (no re-review per quota rule). Next: merge into main locally, re-import, regression on main, stop.
