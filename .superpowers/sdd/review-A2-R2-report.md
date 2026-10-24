# Review A2-R2: plan Tasks 3 and 5 (creator, CharacterBuilder/PS2Head, phone, 3 a.m. call)

Scope: commits 3e4b5a5 and b5fbc24. The scope files are unchanged at HEAD c0ed19b. I also read the hosting code: StoryRoam, FreeRoam, WeaponDirector/RadialWheel, EmoteDirector, StageManager, ThirdPersonController, PlayerBike, StoryAudio and ViceStyle.

**Verdict: Needs fixes.** There are 2 Important items, both about the phone's input block (A2-D7).

## Important

1. **The phone blocks only movement and camera. Every other roam input still works.**
   - Where: `scripts/story/StoryPhone.gd:123-131, 277-283`; `scripts/FreeRoam.gd:1363` (`mayhem_blocked`) and `1728-1750`; `scripts/story/StoryRoam.gd:602-606`.
   - Why: `controls_enabled` only gates `ThirdPersonController` (`_read_input`, `_unhandled_input`). `StoryPhone._input` consumes only Esc and P. `mayhem_blocked()` does not know about the phone.
   - What still works with the phone open:
     - Middle mouse opens the weapon wheel (`RadialWheel._input`, `WeaponWheel` uses MOUSE_BUTTON_MIDDLE). It draws on layer 6, above the phone on layer 3.
     - B opens the emote wheel and can start an emote.
     - The mouse wheel over the phone's message list also cycles the weapon (`RadialWheel.scroll`).
     - R reloads, because `_reload_input` polls `Input.is_physical_key_pressed`.
     - F mounts the bike, and the bike then drives with the phone open because `PlayerBike` reads gas, brake and drift directly.
     - M opens the map over the phone.
     - E at a marker launches a stage, goes to bed, or starts the 3 a.m. call.
   - Knock-on effect: when E starts a cinematic or the call, the phone stays `_open`. UIWatch only hides the story `ui`, so the phone pops back up, still open, when that ends.
   - Fix:
     - (a) Add `or (story_roam != null and story_roam.phone != null and story_roam.phone.is_open())` to `FreeRoam.mayhem_blocked()`. That one condition blocks weapons, both wheels, the scroll cycle, reload and emotes.
     - (b) In `StoryPhone._input`, while open, call `set_input_as_handled()` on every pressed key event, not only Esc and P. StoryRoam is added to the tree after the wheels and FreeRoam, so its `_input` runs first. Leave mouse events alone so the tabs and the ScrollContainer still work.
     - (c) In StoryRoam, refuse [P] while `roam.mounted`.
     - (d) Optionally, have `StoryRoam._pause(true)` and `_play_cine` call `phone.close()`.

2. **The phone's save and restore of `controls_enabled` can freeze the player.**
   - Where: `scripts/story/StoryPhone.gd:129, 144` together with `scripts/FreeRoam.gd:923/964`.
   - How it happens: open the phone while riding, so `_controls_was = false`. Press F to dismount; `dismount_bike` sets `controls_enabled = true`. Close the phone; it restores `false`. The player is now on foot and cannot move until they mount and dismount again.
   - The reverse order also breaks: open the phone on foot, press F twice, and the player walks with the phone open.
   - Fix: Item 1's fixes (b) and (c) block F and refuse to open the phone on the bike, which removes both orders. Better still, `close()` should set `controls_enabled = not bool(roam.mounted)` instead of the snapshot.

## Minor

- `StoryPhone.gd:219` vs `:255`: `refresh()` computes the "Tin nhắn (n)" tab count before `_fill_messages` marks the thread read, so the count is stale right after opening.
- `StoryRoam.gd:351-353`: `_update_chip()` runs before `phone.refresh()` marks the open thread read, so the chip shows ✉1 for an already-read text until the phone closes.
- `StoryPhone.close()` leaves the mouse visible and does not restore the captured mode. One click is needed to re-capture. WeaponDirector's `_need_release` prevents an accidental shot, so this is cosmetic.
- `StoryCall.gd:103`: there is no "Giữ Esc để bỏ qua" hint. The skip bar appears only after Esc is already held, so the skip cannot be discovered.
- `StoryCall.gd:57`: layer 120 is the same as `StageManager.modal_layer` and `CinePreview`. Use 121, or note the intended order.
- `StoryCall.gd:137`: the `GameFXScript` const is declared mid-file, after `_build()` uses it. It works, but move it to the top with the other consts.
- `CharacterCreator.gd:310/325`, `CharacterBuilder.gd:215` and the classic rigged path: in the classic art style, `variant` is ignored by `_build_head`. The "Khuôn mặt" row rebuilds the model but nothing changes on screen. Hide the row or label it in classic style.
- `CharacterCreator` layout at 1280×720: my estimate of the column's height is about 644 px against 648 px available. That counts the panel and row styleboxes (14/8 content margins), 64 px rows and the 2-line subtitle. Any extra wrap pushes the button row off the bottom. Reduce the row padding or wrap the column in a ScrollContainer. The width is also about 4 px over at the button row (460 vs 456), so the panel grows slightly, which is harmless.
- `CharacterCreator.gd:408`: `clean_name` and `NAME_MAX` duplicate `StoryDirector.clean_name`. Call the StoryDirector one to keep a single rule.

## Verified OK

- **CharacterBuilder:** `variant` is only added to the opts when it is >= 0. `PS2Head:105` still draws `rng.randi_range(0, 2)` because GDScript evaluates the default argument eagerly. The `player` outfit override runs after every rng draw. `preset: "player"` is used only by protagonist models (TPC, Stage2/5 visuals, hero actors). NPC random draws are unchanged.
- **Preview rebuild:** each change calls `remove_child` and then `queue_free`, so nothing leaks. Holding a key does not rebuild repeatedly because echo is ignored. `ViceStyle._watch` re-styles the new preview.
- **Creator Esc:** the creator sets the `no_pause` meta, so `_can_pause` is false and Esc goes to `back()`. Typing M in the name field is blocked by `_is_text_input_focused`. Buttons have FOCUS_NONE, so there is no focus trap.
- **Call:** it takes about 10 s when answered at once. It auto-answers at 6 s. `phone_ring_3am` and `whisper_bed` loop (StoryAudio.LOOPS). The voice is synth cues only. "Giảm hù dọa" removes the shake and flash, and the cues are -6 dB through `cue_db`. `cinematic_active` blocks the pause menu, and `_exit_tree` clears it. The overlay sits above CineOverlay (110), and `_pause` hides the HUD.
- **Text rules:** fictional names only. No "Thầy Toàn" or "ToanHLM". No gendered narration. All icons are drawn in code or are emoji. Autoloads are reached with `get_node_or_null`, and GameFX through a preloaded script.
- **Per-frame cost:** trivial in all three scripts. Label `set_text` returns early when the text is unchanged.
