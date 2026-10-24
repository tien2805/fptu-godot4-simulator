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
