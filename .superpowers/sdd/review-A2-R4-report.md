# Review A2-R4: StoryRoam, FreeRoam hook, story stages, Day 0 e2e (d5c4142..187311a, HEAD c0ed19b)

**Verdict: Needs fixes** (3 Important; I found no hard soft-lock)

## Verified OK
- Retry keeps the context and roam_spawn (`change_stage(id, true)`). A fail followed by VỀ THẾ GIỚI MỞ spawns at fail_xf with the marker kept. A win followed by TIẾP TỤC spawns at win_xf on the next beat. Leaving for the menu clears the context and saves.
- Continue on every Day 0 step works: tod comes from the save (FreeRoam._ready, then refresh), markers come from `_rebuild_markers`, the objective is shown again, and cine/call/video beats re-run after RUN_DELAY. The bed clears spawn so the game resumes at BE6.
- Autosave spawn is safe: `_apply_spawn` runs `find_free_spot` again (it rejects water and mid-air) and falls back to BE6.
- The [E] marker is blocked while wanted, during service, when mounted, and during cines, the call and the video (the paused tree stops StoryRoam input). A double [E] is absorbed by the stage transition, or by `complete_step` refusing a stale id.
- The busted cine and story cines never overlap (`cine_player` retry, ONE_SHOT connects). Story cines cannot start mid-chase.
- Replays never touch `Engine.time_scale`. The pause state is restored in `_release` and also in `_exit_tree`. Esc is blocked through `cinematic_active`.
- Story result buttons are built once. Card buttons are hidden deferred, after the stage shows them. Forwarding happens only for the beat's own stage.
- Free play is unchanged: no StoryRoam, hotspots are built, [T] cycles. `hero_opts()` returns the fallback, `result_banner_title` stays the same without a "story" key, and M/report paths are gated by an empty context.
- Cost: marker checks run at 10 Hz. UIWatch does one property read per frame with no allocation. Blips and hints update at the HUD rate (0.2 s).
- Names: only Mr.T appears. StoryRoam/StoryStage/StoryUtil reach autoloads through get_node_or_null.

## Important
1. **StageManager.gd:318-320: Ctrl/Shift+Tab still opens the Campaign Hub in story roam and mid story mission.** 187311a blocked [M] and the pause hub button, but the TAB branch only checks `cinematic_active`.
   - Scenario: in story roam or on a story fail card, Ctrl+Tab, then Play another stage. The player leaves the story with `StoryDirector.active` still true: the protagonist rider appears in free-play stages and the pause hub stays hidden. The stale `story_context` keeps blocking [M]. The story result layer (autoload, layer 117) stays visible over the new stage, and THỬ LẠI jumps back into the story stage. The roam spot is never saved.
   - Fix: put one guard inside `toggle_stage_select()`/`open_stage_select()`: return when `not story_context.is_empty()` or StoryDirector.active. Or add the same condition to the TAB branch.
2. **HUDManager.gd:486-491: `_on_destination_reached` has no `is_game_ended` guard. This allows a replay after a fail.**
   - Scenario: the 300 s timer runs out within about 10 m of the line (controls are locked but the bike brakes at 26 m/s² and rolls on, RoadManager keeps checking). `_trigger_absent_screen` reports a fail and the story card shows TOANG!. The bike then crosses, so seg_d0_race plays (the tree pauses and the TOANG! buttons stay clickable on top), then a win is reported and the beat advances.
   - The bug was already in free play (double report), but the story replay and beat progression make it worse.
   - Fix: add `if is_game_ended: return` as the first line of `_on_destination_reached`.
3. **StoryRoam.gd:525 (`start_marker`): [E] is not blocked while the phone or map is open.** The phone only consumes P/Esc, and [P] already checks the map.
   - Scenario: open the phone at the bed and press [E]. The midnight cine, call and ai_intro all play with the phone logically open (hidden by UIWatch, still eating Esc). On Day 1 the phone pops back open with player controls disabled. A stage beat launched with the map or phone open has a smaller version of the same problem.
   - Fix: in `start_marker`, return false when `phone.is_open()` or `map_overlay.visible`. Or close the phone in `run_step` before `_play_cine`/`_start_call`.

## Minor
- StoryRoam.gd:518 `hint_text()` deep-duplicates the beat dict on every HUD tick inside a marker. Cache the kind/title in `_rebuild_markers`.
- FreeRoam.gd:1249: in story mode on foot, the generic hint replaces the "[F] lên xe máy" and "xe máy cách N m" hints. It also rebuilds the string on every tick (make it a const).
- StoryRoam.gd:476 + StoryVideo `_exit_tree`: closing the window mid-video emits finished(true), so `complete_step` saves Day 1 and the intro counts as seen.
- StoryDirector.gd:336: leaving for the menu during community service saves the chore spot. Continue then drops the chore (the bike stays at BE6).
- StoryRoam.gd:230 `player_xf()` uses the hidden walker's yaw when mounted, not the bike's.
- HUDManager.gd:121 and StageExtra_EOSExam.gd:105 add direct `StageManager.StageID` autoload refs in class_name scripts. This matches those files, but use the enum through a preloaded script (as FreeRoam's StageManagerScript does) or literals.
- StoryRoam `_on_text`: two texts in one beat (d0_bed) overwrite each other's toast. Only the last one shows.
- `launch_stage_beat` sets spawn = fail_xf without saving, so a window close mid-stage resumes at the previously saved spot. This is harmless for Day 0.
