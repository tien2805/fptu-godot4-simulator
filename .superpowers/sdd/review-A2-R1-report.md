# Review A2-R1 (plan Tasks 1, 2, 4: commits 844101e, 13175c2, 51518e1; files read at HEAD c0ed19b)

**Verdict: Needs fixes**

## Important

1. **The warm task stalls the main thread when the first beat runs** (spec A2-D9: "play never stalls the main thread for more than 16 ms").
   `scripts/story/StoryAudio.gd:68-70`: when `stream()` is called for a cue that is still in `_pending`, it calls `wait_for_task_completion(_task)` on the *whole* batch.
   - Scenario: StoryRoam `_ready` (`StoryRoam.gd:72`) warms 15 cues in one task, and `run_step` fires 0.5 s later (`RUN_DELAY`). This happens on a new story, on Continue, and on the return from a stage.
   - A cine beat (d0_wake, d0_exam_end, d0_midnight) then makes `CinePlayer.gd:189-191` pre-synthesize every sfx through `CineAudio.sfx` -> `StoryAudio.stream_once` -> `stream`. These cues are record_scratch, dun_dun_duun, success_fanfare, heartbeat, whisper_bed and the rest, all of which are in the warm list.
   - The same happens to `phone_ring_3am` in `StoryCall._play_loop` when Continue lands on d0_call.
   - The batch is about 4-5 M inner per-sample GDScript iterations: whisper_bed has 6 s of noise ×2, and dun_dun_duun / success_fanfare / violin_screech run 4-7 harmonics. That is roughly 1-3 s on a worker (my estimate, not measured), so the main thread freezes for whatever part of the batch is left.
   - Fix: give each cue its own task (`_tasks[cue] = WorkerThreadPool.add_task(...)`, each writing its own box) so that `stream()` waits for at most one cue, and put the current beat's cues first. Also, in `StoryRoam.run_step`, re-arm `_run_t = 0.1` while `not StoryAudio.poll()`, with a cap of about 3 s.
2. **The overwrite confirm cannot be reached by keyboard** (`scripts/MainMenu.gd:494-504`). `_on_story_pressed` shows ConfirmPanel, but focus stays on `btn_story` behind the dim.
   - Up/Down still move through the hidden main buttons, and Enter re-opens the confirm.
   - Enter on TIẾP TỤC starts `continue_story` while the modal is still open.
   - The menu advertises "↑↓ + Enter".
   - Fix: `confirm_panel.find_child("ConfirmNo", true, false).call_deferred("grab_focus")` when the panel is shown (No is the safe default). `_hide_modals` already returns focus.
3. **Texts sent by a "day" beat are stamped with the previous day** (`scripts/story/StoryDirector.gd:138-146`). `_enter` adds the beat's texts before it calls `advance_day`.
   - So d1_start's "Thầy tin em. Tìm bằng chứng đi." gets `"day": 0`, and the phone shows it under "Ngày 0" (`StoryPhone.gd:274`).
   - Fix: in `_enter`, call `advance_day(int(b["day"]))` before the texts loop when `kind == "day"`.

## Minor
- `StoryDirector.gd:145`: the day-beat `save_game()` writes a transient state with `step = "d1_start"`. No runner handles kind "day", so a crash before `complete_step`'s own save would soft-lock that save. Drop this save, or move it after `_enter(next)`.
- `StoryDirector.gd:221-222`: `from_dict` appends evidence unfiltered and without dedup. An edited or corrupt save can inflate the count that `evaluate_ending` uses. Filter it against `EVIDENCE_IDS` and skip duplicates.
- `GameFX.gd:846`: the classic-style `sunset` preset has `"outdoor": false`, but ViceStyle treats sunset as outdoor (`ViceStyle.gd:120`). In Classic at high quality, free roam at sunset gets the indoor SDFGI settings (4 cascades, 0.12 m cells).
- `MainMenu.gd:488-491`: the success sfx and white flash play before `continue_story` can fail. Check the result first.
- `StoryAudio.gd:137-151`: `warm()` called while a task is running drops the new list silently. That is harmless today because there is only one caller.
- Verified OK:
  - `evaluate_ending` matches story spec 6 in order (C, E, B, D, A, F), and F uses StageID 3, 6, 7 (7 = Extra EOS).
  - The version guard refuses any version other than 1, a missing step and an unknown beat.
  - Transform3D and the typed `Array[String]` / `Array[Dictionary]` survive `var_to_str` / `str_to_var`.
  - Saves are blocked in headless mode only for the real path.
  - Autosave happens on creator confirm, on each win, on each day advance and on `go_to_main_menu`.
  - Continue is hidden when there is no save or the save is invalid, and it refreshes if the load fails.
  - The overwrite only happens on creator confirm, so backing out of the creator keeps the old save.
- Warm thread safety is OK:
  - `synth` is pure (local arrays and RNG; the AudioStreamWAV is built off-thread, with no Node or server access).
  - The worker writes only into its own box.
  - The box is adopted only after `wait_for_task_completion`.
  - `clear_cache` waits before resetting.
- Signals are OK: StoryRoam disconnects in `_exit_tree`, and the settings toggles connect once per panel.
- Project rules are OK:
  - No `.import` files in the 3 commits.
  - Only "Mr.T" is used.
  - Owner files live only under `user://` (sfx, story_save.cfg, settings.cfg).
  - StoryUtil and MainMenu reach StoryDirector through `get_node_or_null`.
  - All melodies are original few-note figures.
