# Review A2-R3 (commit 20f49f5): Day 0 cinematics, intro cards, owner video

**Verdict: Needs fixes**

Method: read the code. Shot framing was computed by projecting the subjects through each static camera, with the 2.39:1 letterbox (visible |y| <= 0.744 of the half-height). Godot was not run.

## Important
1. **StoryIntroCards.gd:74 (also :114, :132, :152-154).** The stamp, countdown and title will render as one letter per line. `_lbl` turns on AUTOWRAP_WORD_SMART for every label, and a Godot 4 autowrap Label reports a minimum width of 1 px. "TOANG!" and "CÒN N NGÀY" sit straight in CenterContainers. "TOOL ĐEN" and "7 ngày minh oan" sit in a VBox whose only other child, the pastel strip, has min width 0, so the strip is invisible too. The email and Mr.T boxes are fine because they have custom_minimum_size.x. Fix: add an `autowrap` parameter to `_lbl` and turn it on only for the email and Mr.T text, or give these labels and `tvb` a custom_minimum_size.x of about 900. Add a test that `stamp.size.x > 200` after one frame.
2. **cine_d0_exam.gd:16 + :83/:84.** The sheep is hidden behind the hero's head. From S6/S7 at (1.6,1.6,-3.8), the line to SHEEP (-2.4,0,5.4) passes 5 cm from the hero at z=0, at head height. On screen the hero's face is at x+0.02/y+0.07 and the sheep's face at x+0.04/y+0.09. So the 1.5 s horror beat sits behind the head of an actor 4 m from the camera, and the figure 10 m away is fully covered. Fix: SHEEP = (-3.4,0,5.4). It then passes 0.47 m from the hero, 0.27 m from Mr.T and 1.3 m from Phúc. Or raise the S6/S7 camera to y ≈ 2.3.
3. **Held props hang from idle arms** (exam:38 photo, wake:25 and ai_intro:26 phone). `hold` only attaches the prop to Wrist.R, and idle keeps the arm down. In exam S2 the E1 photo hangs at Mr.T's hip, at the bottom edge of the frame (y -0.65). Wake S3 ("Phúc's text") has the back of the head at the top edge (y+0.72) and the phone at the bottom edge (y-0.73). The hero's looks at (0.1,1.05,-0.45) stare at empty air. Fix: add a looping code pose `hold_up` to CineMoves (about shoulder_r (0.9,0,0.15), elbow_r (1.7,0,0)) and play it during each hold window.
4. **cine_d0_midnight.gd:12/:37/:47/:79.** The "slumped" sit raised by 0.42 m floats. It is getup's floor-sit key: pivot 0.27 m above the key, body pitched back 0.3, thighs 1.7, knees -1.0, hands reaching back. On the bench the knees end up about 0.88 m high and the ankles about 0.63 m, sticking 0.8 m forward into the air in front of the seat. The arms reach back through the backrest (z 0.24). The glasses on Wrist.R (15.2-22) end up behind the backrest, so S5 "close: glasses" frames empty space at (-0.1,0.85,-0.15). The head also lolls like a KO. Fix: a `sit_bench` code pose with the key at y 0: body_y ≈ -0.43, pitch about 0.05, thighs about 1.55, knees about -1.55, hands in the lap. Then use `hold_up` from 15.2.
5. **cine_d0_exam.gd:70-71.** Mr.T walks backwards. His yaw goes from 180° at 14.0 to 61.8° at 17.6 during a single walk segment with "in" easing. That is 118° spread over 3.6 s, so for the first ~1.5 s of the S8 wide shot he walks backward or sideways. Fix: add `key("mr_t", 14.35, MR_T, face(MR_T, MR_T_EXIT))` before he starts moving.
6. **Subtitles under 0.06 s/char.** exam:86 (52 chars, 2.7 s, needs 3.12 s), exam:87 (45+ chars with {name}, 2.0 s, needs 2.7-3.4 s), exam:90 (52 chars, 2.8 s, needs 3.12 s), ai_intro:47 (47 chars, 2.6 s, needs 2.82 s). Suggested retimes: 0.4 for 3.1 s; 3.6 for 3.4 s; 13.4 for 3.2 s and move "…" to 16.7 for 1.0 s; 14.5 for 2.9 s. Then regenerate the beat sheets.
7. **StoryVideo.gd:33-56.** A file that exists but cannot be decoded is never caught. `play_file` only checks `file_exists`, then calls `play()` and returns true. Nothing confirms that playback started, and there is no watchdog. If Theora cannot decode the file, `finished` never arrives, and the game sits paused on a black screen with no hint until someone holds Esc. It also never falls back to `ai_intro`. Fix: after `play()`, return false when `not player.is_playing()` or `get_stream_length() <= 0`. Also end the video if `stream_position` has not moved after 1.5 s, and have StoryRoam run `_play_cine` in that case.
8. **StoryRoam.gd:458/476 (video path).** The roam music plays under the owner's clip. GameFX music is PROCESS_MODE_ALWAYS, and roam plays "menu" on it. `play_cinematic` stops it, but `_play_video` does not. Fix: call `music_stop(true)` in `_play_video` and `music_play("menu", 0.15)` in `_on_video_done`.

## Minor
- ai_intro: the Mr.T text card (8-12) covers the hero's mouth and chin for all of S3 "close: the face", and the countdown (12.6-17) covers the lower face in S4. Move both cards to the upper third or the side.
- ai_intro:31: nothing plays between head_shake (12.4-13.0) and victory at 17.6, so the pose freezes for 4.6 s. Add `move idle` at 13.0.
- midnight S2: the face is at y+0.66 against a visible limit of 0.744, so the head top is cut by the bar. Look at y ≈ 1.15 instead.
- midnight S3: the red seam (y 0.875) is above the visible frame (y+0.81). Look at (0.45,0.72,0).
- midnight: Phúc rises through the ground 0.8 m behind the backrest (z 1.05 vs 0.24). At 9.0 he pops in through the gap between seat and backrest. Put him at z ≈ 0.45.
- midnight:60 / CineActor.gd:557: held props take the spin basis, not the Head bone's. Phúc's look at the seated hero (~17° down and sideways) pushes his brow through the 2.5 cm face mask. Either let Head holds follow the bone, or drop that look.
- The sheep muzzle ends at Head +0.013, so the PS2 chin and mouth show below it.
- exam:38: the photo hold starts at 0.5 and pops into Mr.T's hand on camera in S1. Start it at 0.0.
- exam: cine_stage needs a clear 13x12 box, so nothing guarantees a wall or "corridor opening" behind the sheep. The fallback can also rotate the stage yaw by 45-135°.
- wake: the sprint covers 2.8 m in 1.3 s with ease-out, so the feet skate. Use jog. Wake sub :52 is 1.8 s for 31 chars; give it 1.9 s.
- StoryIntroCards.gd:160: `email_body.text` is reformatted and reassigned every frame, which forces a relayout each frame. Set it once.
- CineFX.gd:898: `set_lamp` toggles `emission_enabled`, which switches shader variants, so the first flicker may hitch. Toggle `emission_energy_multiplier` instead.
- StoryVideo: it hard-cuts from black back to the game, `expand=true` stretches clips that are not 16:9, there is no skip hint, and the test never exercises `play_file`.

## Checked and OK
- Beat sheets match the timelines (shots, subtitles, lengths).
- Music slot = slot, with a 0.5 s fade on longer files; `eerie` and `playful` moods exist.
- The calm variant drops the screech, the punch and the flicker, and its horror cues are 6 dB quieter.
- `{name}` goes through `StoryUtil.fmt`.
- Props, lamp and cards are freed with the CinePlayer and `_on_cine_done`; time scale is untouched.
- Cards use canvas_items stretch from 1280x720, so they scale to 4K; layer 105 sits under the 110 letterbox, fade and subtitles, which is fine for centred cards.
- `stream_once` makes a one-shot copy of looping cues.
- Mr.T only; no Thầy Toàn or ToanHLM; all cues synthesized; no gore.
