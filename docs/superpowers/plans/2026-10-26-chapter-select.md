# Chapter select ("Chọn cảnh") and cinematic gallery ("Xem lại phim"): Plan

Owner request: "thêm tính năng chọn tua lại trong game". Branch `chapter-select` (from main 90a0468). Story framework:
`scripts/story/StoryDirector.gd`, `StoryMissions.gd`, `StoryRoam.gd` (specs 2026-10-24 phase A2, 2026-10-25 phase B).

## Files

- **New `scripts/story/StoryChapters.gd`** (class_name, static, RefCounted): the two record files and the rewind.
  - `user://story_unlocks.cfg`: `[unlocks] beats = [...]`, `cines = [...]`. Only grows; never touched by a rewind or a
    new story. `mark_beat(id)` / `mark_cine(slot)` write only when something is new.
  - `user://story_chapters.cfg`: `[chapters] <beat id> = var_to_str(StoryDirector.to_dict())`, the state at the start of
    the beat, latest wins. Replayable kinds: `cine`, `video`, `stage`, `mission`, `fight`, `horror` (day starts are
    the `dN_morning` cine beats; choice beats are cine beats). Skipped: `day`, `locked`, and also `bed` / `call` (not in
    the owner's list; they are hand-offs, not scenes).
  - `on_enter(sd, id)`: called from `StoryDirector._enter` after `set_step`: marks the beat, saves the snapshot.
  - `rewind(sd, id)`: copy the current save to `user://story_save_before_rewind.cfg` (overwrite), `sd.from_dict(snap)`,
    `sd.save_game()`, `sd.continue_story()` (same path as TIẾP TỤC: the beat runs fresh, markers, cinematics).
  - `restore_backup(sd)`: backup -> save, delete the backup, `continue_story()`.
  - `ensure_seeded(save)`: old saves (no unlock file yet): unlock the beat chain up to and including the current
    beat, the cinematic slots of the beats before it (+ the current beat's intro when its flag says it played), the
    current beat's snapshot = the save itself, earlier replayable beats get a best-effort snapshot (`seeded = true`):
    protagonist; day, tod, step, objective of the beat; texts of the beats up to it; evidence / beat flags / intro
    flags / choices of completed beats only (intersected with what the save has); side evidence (E2) only when its
    window closed before the beat (else the locker is offered again, consistent with its flag); E5 and the d4 catch
    flags only after `d4_escape`. A beat unlocked without a snapshot shows disabled: "Chơi tới cảnh này một lần để mở".
    Called from `StoryDirector.load_game` and `MainMenu._refresh_story_buttons`.
  - `GALLERY`: story cinematic slots with day and Vietnamese title; `chapters()` / `gallery()` list rows for the UI.
  - Paths are static vars (tests point them at temp files); the real paths are never read or written headless.
- **New `scripts/story/ChapterSelect.gd` + `scenes/story/ChapterSelect.tscn`**: full screen, two tabs "CHỌN CẢNH" /
  "XEM LẠI PHIM", list grouped by day ("Ngày 0 · Phòng 311"), locked rows "???" (days with nothing unlocked hidden),
  confirm "Tua về '<tên cảnh>'? Tiến độ hiện tại được lưu lại, có thể quay về.", "QUAY VỀ TIẾN ĐỘ TRƯỚC KHI TUA" (only
  with a backup), "QUAY LẠI" / Esc (main menu, or the story when opened from the pause menu). Mouse + keyboard (focus,
  follow_focus scroll). `no_pause` meta.
- **New `scripts/story/StoryGalleryPlayer.gd` + `scenes/story/StoryGalleryPlayer.tscn`**: like CinePreview (FreeRoam,
  crowd off); borrows StoryDirector for the playback (the save's protagonist, active so `StoryUtil.hero_opts` applies),
  restores its exact state after (a choice scene writes `choices`), never saves; owner music through CinePlayer; day card
  / intro cards like StoryRoam; back to the gallery tab.
- **Edits (surgical):** `StoryDirector._enter` (1 line) and `load_game` (1 line); `StoryRoam._start_cinematic` and
  `_play_video` (1 line each, mark the slot); `MainMenu` (button "CHỌN CẢNH" after CỐT TRUYỆN, visible with unlocks);
  `StageManager` (pause button "CHỌN CẢNH" in place of the hidden Campaign Hub button while the story runs,
  `go_to_chapter_select()` = `go_to_main_menu(scene)` with `ChapterSelect.from_story`).

## Tests (`tests/test_chapter_select.gd`, temp paths only)

Unlocks never shrink (rewind, new story); snapshots on entry (stage, day start, mission; none for day / bed / call);
latest wins; menu button only with unlocks and the menu fits 1280x720; rewind through the UI (confirm text, backup,
save replaced, FreeRoam: marker of the beat, day 1, night); cinematic beat plays after a rewind; restore; gallery rows,
playback returns to the gallery tab without touching the save; old-save seeding; pause entry only in story mode; no
emoji (no char >= U+2190) in the new texts. Light set: test_chapter_select, test_main_menu, test_hud_bounds,
test_story_director, test_story_day0, test_story_day1, test_story_cines, --check-only, smoke.
