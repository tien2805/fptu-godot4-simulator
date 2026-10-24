# Story Phase A2 "Khung cốt truyện + Ngày 0": Implementation Plan

Spec: `docs/superpowers/specs/2026-10-24-story-phase-a2-framework-design.md` (A2-D1..A2-D16). Branch `story-a2`, base f5ef496.

**Goal.** Day 0 of "TOOL ĐEN" playable end to end from the main menu (creator → wake cinematic → Stage 1 race → Extra stage
in room 311 → exam-end cinematic → free roam → bed → midnight horror → 3 a.m. call → `ai_intro` → Day 1 morning "CÒN 7
NGÀY"), on a story framework (state, save/continue, mission registry, story layer in free roam, phone, call, SFX) that
Phases B-E extend with data and timelines.

**Architecture.**
- `StoryDirector` autoload (`scripts/story/StoryDirector.gd`, no class_name: it would hide the autoload) owns the state, the
  save slot, the beat progression and the story result card; it never builds world content.
- `StoryMissions` (static tables) describes every beat; `StoryUtil` (static) is the safe bridge for class_name scripts
  (`/root/StoryDirector` via `Engine.get_main_loop()`), protagonist opts, `{name}` formatting, "Giảm hù dọa".
- `StoryRoam` (child of FreeRoam in story mode) is the presentation layer: markers, objective, day chip, phone, call,
  beat runner chaining `FreeRoam.play_cinematic`. FreeRoam only gets a hook (`story_mode`, `story_roam`).
- Stages read `StageManager.story_context`; `report_stage_result` forwards to `StoryDirector.on_stage_result`.
- Audio: `StoryAudio` synthesizes the 17 cues with the frozen `CineAudio` statics; `CineAudio.sfx` falls back to it so
  timelines can use the new cues.

**Global constraints.** Pure GDScript, Godot 4.7.2; code-drawn UI only; Vietnamese text; fictional cast (Mr.T role
`mr_t`, Phúc, Anh Duy); protagonist only as `{name}`; no downloads; owner files only in `user://music|sfx|video`; never
stage `.import`; tests `_check()` + `quit(1)`; class_name scripts reach autoloads only through `get_node_or_null`;
story layer per-frame cost ≈ 0 (10 Hz checks, no per-frame allocation); `test_mayhem_perf` < 3 ms.

**Per task:** run the task's tests + `godot --headless --quit --check-only --path .` (after `--import` when a class_name is
added), commit, add a ledger line to `.superpowers/sdd/progress.md`.

---

## Task 1 – StoryDirector, StoryMissions, StoryUtil, save

Files: create `scripts/story/StoryDirector.gd`, `scripts/story/StoryMissions.gd`, `scripts/story/StoryUtil.gd`; modify
`project.godot` (autoload after StageManager); test `tests/test_story_director.gd`.

Produces:
- StoryDirector state vars `active, day, tod, step, evidence: Array[String], choices {phuc, zaman_offer, bribe},
  flags: Dictionary, protagonist: Dictionary, texts: Array[Dictionary] {from, text, day, read}, objective, spawn (Transform3D
  or null)`; signals `day_changed(day)`, `evidence_added(id)`, `objective_changed(text)`, `text_received(msg)`,
  `step_changed(step)`.
- `new_story(protagonist)`, `protagonist_opts() -> Dictionary`, `display_name()`, `fmt(text)`, `beat() -> Dictionary`,
  `set_step(id)`, `complete_step(id)` (grants evidence / texts of the beat, applies next beat's tod + objective, day
  advance for kind `day`, autosave), `add_evidence(id)`, `add_text(from, text)`, `unread_count()`, `mark_read(from)`,
  `set_objective(text)`, `days_left()`, `day_chip_text()`, `to_dict()/from_dict()`, `save_game(path)`, `load_game(path)
  -> bool`, `static read_save(path) -> Dictionary` (empty when missing, unreadable or newer version), `static
  evaluate_ending(state) -> String` (C, E, B, D, A, F), `save_path` (tests use a temp file), `nav_enabled` (tests: false
  records `last_nav` instead of changing scenes).
- StoryMissions: `BEATS` (Day 0: d0_wake, d0_race, d0_exam, d0_exam_end, d0_bed, d0_midnight, d0_call, d0_intro,
  d1_start; d1_locked..d7_locked), `beat(id)`, `first_beat()`, `DAY_TITLES`, `TEXT_SENDERS`, `EVIDENCE` (E1-E7 names).
- StoryUtil: `director()`, `story_active()`, `hero_opts(fallback)`, `hero_name()`, `fmt(text)`, `reduce_scares()`,
  `stage_context()`.

Tests (`test_story_director`): signals fire once per change; `fmt` substitutes `{name}`; save → load round trip equals
`to_dict()`; missing file / garbage / `version = 2` → `read_save` empty; Day-0 chain from `first_beat()` reaches
`d1_start` then `d1_locked`; every `next` exists; placeholders 1-7 have no anchor and "sắp có" objectives;
`evaluate_ending` truth table (C over everything, E < 4 evidence, B reported Phúc, D 4-6 or bribe, A, F with S ranks).

Acceptance: autoload registered; test green; check-only clean.

## Task 2 – Settings, sunset, StoryAudio

Files: modify `scripts/GameFX.gd` (`reduce_scares` saved as `story/reduce_scares`, `set_reduce_scares(on)`,
`build_story_settings(parent)` → CheckButton `ReduceScaresCheck` "Giảm hù dọa", synced by `sync_style_settings`, TOD preset
`sunset` (outdoor false, not in the [T] cycle)); create `scripts/story/StoryAudio.gd`; modify `scripts/cine/CineAudio.gd`
(`sfx()` falls back to StoryAudio cues), `scripts/cine/CineTimeline.gd` (validator accepts StoryAudio cues),
`scripts/cine/CinePlayer.gd` (adds `StoryAudio.cue_db(cue)`); test `tests/test_story_audio.gd`.

Produces: `StoryAudio.CUES` (17), `HORROR`, `LOOPS` (heartbeat, whisper_bed, music_box, phone_ring_3am),
`synth(cue) -> AudioStreamWAV` (pure, thread-safe), `stream(cue) -> AudioStream` (override `sfx_dir/<cue>.ogg|.mp3|.wav`,
cached), `cue_db(cue)` (-6 dB horror when reduce_scares), `warm(cues)` (WorkerThreadPool) + `poll()`, `sfx_dir` (tests).

Tests: every cue builds, length in its range, loop flags; override file in a temp dir wins; `warm()` returns < 16 ms and
`stream()` after completion < 2 ms; `cue_db` with reduce_scares; a timeline using `ba_dum_tss` validates.

## Task 3 – Character creator

Files: modify `scripts/CharacterBuilder.gd` (`variant` reaches PS2Head; preset `player` always jeans, white sneakers,
black backpack without changing the rng sequence); create `scenes/story/CharacterCreator.tscn`,
`scripts/story/CharacterCreator.gd`; test `tests/test_character_creator.gd`.

Produces: `CharacterCreator` (class_name) with `ROWS` (6), `opts: Dictionary`, `row`, `set_value(row, idx)`,
`step_value(dir)`, `randomize_opts(seed)`, `clean_name(text) -> String` (static: trim, default "Bạn", max 16),
`confirm()` (→ `StoryDirector.new_story`, then roam), `back()`, `preview: Node3D`, `rebuilds: int`. Turntable: drag
rotates, idle animation. Meta `no_pause`.

Tests: 6 rows; hair styles switch with sex; randomize stays in the tables; name rules; each change rebuilds only the
preview (counter + new instance, UI nodes unchanged); confirm stores opts in the director and writes the temp save.

## Task 4 – Main menu and pause settings

Files: modify `scripts/MainMenu.gd` (remove start / hub / journal / [M]; add `btn_continue` "▶ TIẾP TỤC – NGÀY N" only
with a valid save, `btn_story` "✚ CỐT TRUYỆN MỚI: TOOL ĐEN" with overwrite confirm "Ghi đè bản lưu Ngày N?", keep roam,
guide, settings + "Giảm hù dọa", quit), `scripts/StageManager.gd` (pause settings gain the checkbox; `_can_pause` honours
meta `no_pause`; pause hub button hidden in story; `go_to_main_menu` tells the director), `tests/test_main_menu.gd`.

Tests (updated `test_main_menu`): buttons present, continue hidden without a save and shown with one, new story with a
save opens the confirm, settings has `ReduceScaresCheck` in both menus, new story loads the creator scene.

## Task 5 – Phone and 3 a.m. call

Files: create `scripts/story/StoryPhone.gd` (Control), `scripts/story/StoryCall.gd` (CanvasLayer); tests
`tests/test_story_phone.gd`, `tests/test_story_call.gd`.

Produces: `StoryPhone.setup(director, block_target)`, `open()/close()/toggle()/is_open()`, `set_tab(i)` (0 Tin nhắn,
1 Bằng chứng, 2 Nhiệm vụ), `thread_names()`, `evidence_texts()`, signal `opened_changed(open)`; `StoryCall.start(n,
opts)` (manual, reduce_scares), `step(dt)`, `answer()`, `phase`, `subtitle`, `shake_used`, `flash_used`, signal
`finished(skipped)`.

Tests: phone threads per sender with `{name}` substituted, unread cleared when the thread is shown, evidence slots "???"
until owned, input blocked while open and restored on close, [P]/[Esc] close; call rings, auto-answers at 6 s, answer
early, typed subtitle reaches "…Mày… còn… 7 ngày…", ends ≈ 10 s after the answer, hold-Esc skip, reduce_scares → no
shake / flash.

## Task 6 – Day 0 cinematics

Files: modify `scripts/cine/CineFX.gd` (props `bench`, `backpack` (red glow via `glow_at`), `glasses`, `noodles`,
`photo`, `lamp` (flicker windows), `sheep_mask`, `face_mask`), `scripts/cine/CinePlayer.gd` (lamp flicker, seekable);
create timelines `cine_d0_wake` (8.0 s), `cine_d0_exam` (18.0 s), `cine_d0_midnight` (22.0 s), `ai_intro` (24.0 s) in
`scripts/cine/timelines/`; `scripts/story/StoryIntroCards.gd` (2D cards over `ai_intro`: email, TOANG stamp, Mr.T text,
countdown 7, title card), `scripts/story/StoryVideo.gd` (owner `.ogv` with fades + hold-Esc); beat sheets
`docs/cinematics/<slot>.txt` via `tools/cine_beats.gd`; test `tests/test_story_cines.gd`.

Timelines: hero = `StoryUtil.hero_opts`, lines with `{name}` already formatted; stage `{"landmark": ..., "tod": ...}` plus
`at` set by StoryRoam; `reduce_scares` drops `violin_screech` and the flicker at build time.

Tests: each slot validates, exact length, music slot = slot, beat sheet in sync, no gendered narration, cues exist,
reduce-scares variant drops the screech / flicker, StoryIntroCards states at sample times, StoryVideo picks `ai_intro_m|f`
only when the file exists.

## Task 7 – Story layer in free roam

Files: create `scripts/story/StoryRoam.gd`; modify `scripts/FreeRoam.gd` (hook: `story_mode`, `story_roam`, skip
hotspots, no [T], player opts, blips / map pins / hint from StoryRoam, `cine_stage` accepts `at`), `scripts/ui/ViceHUD.gd`
(`set_day(text, unread)`), `scripts/PlayerBike.gd` (rider sex + skin in story), `scripts/cine/timelines/wanted_busted.gd`
(hero opts in story).

Produces: `StoryRoam.setup(roam)`, `refresh()`, `markers` (id → Area-free marker Node3D), `active_marker`,
`start_marker(id) -> bool`, `hint_text()`, `blips()`, `map_pins()`, `objective_label`, `day_label`, `phone`, `call`,
`cine_opts` (tests), signal `step_started(id)`.

Tests: covered by Task 9 (`test_story_day0`) plus a free-play guard in that test (no StoryRoam when inactive).

## Task 8 – Story missions inside stages

Files: modify `scripts/StageManager.gd` (`story_context`, forwarding, story banner titles, skip roam-return in story),
`scripts/story/StoryDirector.gd` (`launch_stage_beat`, `on_stage_result`, result layer: "▶ TIẾP TỤC CỐT TRUYỆN" /
"↻ THỬ LẠI" + "🌏 VỀ THẾ GIỚI MỞ", hides the stage's own card buttons), `scripts/HUDManager.gd` (story replay
`seg_d0_race` before the result), `scripts/StageExtra_EOSExam.gd` (protagonist model, Mr.T NPC, intro text, replay
`seg_d0_exam`), create `scripts/story/StoryStage.gd` (recorder + replay helper); test `tests/test_story_stages.gd`.

Tests: Extra stage in a story context uses the protagonist model and a Mr.T NPC, recorder tracks the protagonist and the
cheaters, the final catch plays a replay then reports; outside the story the stage is unchanged; Stage 1 rider uses the
protagonist sex / skin; banner titles "QUA MÔN! Uy tín +" / "TOANG!".

## Task 9 – Day 0 end to end

Files: test `tests/test_story_day0.gd`; fixes found by it.

Test: new story (temp save) → FreeRoam story mode (crowd off) → wake cinematic auto-plays (manual steps) → Phúc text +
race marker → [E] → `story_context` → `report_stage_result` fail (TOANG, retry keeps context) then win (autosave, next
beat) → exam marker → win → E1 → exam-end cinematic → sunset, bed marker → bed → midnight (night) → call → `ai_intro`
fallback → Day 1, chip "NGÀY 1 · CÒN 7 NGÀY", morning, autosave → a fresh director loads the save and a second FreeRoam
continues on Day 1 at the saved spot; markers blocked while wanted; free play has no story layer.

## Task 10 – Docs and regression

README "Cốt truyện TOOL ĐEN", PLAN A2 section, spec Status line; full regression script, `test_mayhem_perf`; ledger.
