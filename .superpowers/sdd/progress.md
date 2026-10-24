# Story Phase A2 - SDD ledger

| Task | Commit | Tests | Notes |
|---|---|---|---|
| Plan | (this commit) | - | docs/superpowers/plans/2026-10-24-story-phase-a2.md |
| 1 StoryDirector, StoryMissions, StoryUtil, save | 844101e | test_story_director | autoload after StageManager; evaluate_ending table |
| 2 Settings, sunset, StoryAudio | 13175c2 | test_story_audio, test_cine_timeline, test_cine_audio_fx, test_vice_style | 17 cues + call_hangup; CineAudio.sfx fallback |
| 3 Character creator | 3e4b5a5 | test_character_creator, test_character_builder, test_ps2_head, test_ps2_people | variant reaches PS2 head (vice only); player outfit fixed |
| 4 Main menu, pause settings | 51518e1 | test_main_menu, test_hud_bounds | pause Giảm hù dọa joins the style row (card < 720 px) |
