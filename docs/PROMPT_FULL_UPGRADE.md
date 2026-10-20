# PROMPT: Full-spectrum upgrade of FPTU Student Simulator (gameplay, visuals, audio, UX, performance, code, release)

> Paste everything below to the person or AI agent who will do the work. Text in [square brackets] is yours to edit.

---

## 1. Your role

You are a one-person senior studio: **Technical Director, Lead Game Designer, Art Director and Audio Designer** rolled into one, with 10+ years shipping polished indie games in Godot. You own this game end to end for the next [2 weeks]. You do not ask for permission to do ordinary engineering work; you do ask before anything public or irreversible (pushing to GitHub, tagging releases, deleting player data). You measure before and after, you look at what you render, and you never report something as done without running the verification commands.

## 2. The game and where everything is

**FPTU Student Simulator: Đường Đến Trường** – a comedic 3D game about one day of a student at FPT University Ho Chi Minh City. Godot 4.7, pure GDScript, no plugins. Seven stages (motorbike race, parking + campus run, FAP roll call survival, Vovinam rhythm, canteen tray carrying + 7-Eleven shopping, Capstone typing boss, exam-proctor extra) all set inside a faithful reconstruction of the real campus. There is a main menu, a Campaign Hub, ranks, saved records, cross-stage inventory, three graphics quality levels, a Windows export pipeline and a GitHub Actions release workflow.

Repository: [C:\path\to\fptu-godot4-simulator] (git, branch `main`, remote `origin` on GitHub).

**Read in this order before touching anything**
1. `README.md` – player-facing overview and controls.
2. `PLAN.md` – design document, per-stage mechanics, file tree, test matrix, release pipeline.
3. `docs/GAME_DESIGN_REVIEW_2026-10-20.md` – the design review with a 12-item prioritized change list and three detailed specs. Treat it as the gameplay backlog.
4. `scripts/GameFX.gd`, `scripts/StageManager.gd`, `scripts/FPTUCampusBuilder.gd` – shared systems (juice, HUD helpers, render presets, settings; stage flow, hub, records; the whole campus and interior builder).
5. One stage script end to end (`scripts/Stage2_Parking.gd` is the most complete example), then skim the others.
6. `tests/` – smoke test, one bot test per stage, main-menu test, preview renderers.

**Run before you change anything, and record the baseline numbers**
```
godot --headless --quit --check-only --path .
godot --headless --path . --script tests/smoke_all_stages.gd
for t in tests/test_*.gd: godot --headless --path . --script $t        (9 bot tests, all must print SUCCESS)
godot --path . --script tests/preview_campus.gd                         (needs a window; PNGs to user://preview)
godot --path . --script tests/preview_stage2.gd
PREVIEW_HUD=1 godot --path . --script tests/preview_stages.gd
```
Record: bot time margins per stage, frame time of each preview shot at quality High/Medium/Low (add a frame-time print to the preview scripts if missing), export size, cold-start time of the exported exe.

## 3. Hard constraints (never violate)

1. Godot 4.7, GDScript only, no C#, no plugins, no purchased or downloaded assets.
2. **No AI-generated images, audio or music.** Textures are drawn by code (Pillow scripts in the repo) or cropped from real licensed photos already in `reference_photos/`. Audio is synthesized by code (see `GameFX._synth`) or recorded by a human.
3. Keep folder structure, scene file names, every stage `class_name`, and the facade texture `fptu_alpha_facade.png`. New scenes and scripts are welcome; renaming existing ones is not.
4. The campus stays architecturally faithful to the real one.
5. All existing tests stay green at every commit; new systems get new tests. The smoke runner must stay free of any `ERROR:` line.
6. Phases stay 45–90 s; the whole day under 15 minutes.
7. HUD uses anchors/containers; UI must be fully visible at 1280x720 and scale correctly at 1920x1080 and 2560x1440.
8. Humor stays authentic to FPT student culture and never targets real individuals.
9. Commit after every milestone with a descriptive message. **Never `git push`, never create tags or releases, never delete `user://` files without explicit confirmation from the owner.**
10. Do not pipe Godot output through `head` (it reports a fake crash); grep logs for `ERROR:` and `SCRIPT ERROR`, not only the latter.

## 4. What "upgraded in every aspect" means (measurable targets)

| Area | Target |
| :-- | :-- |
| First impression | A new player understands the first stage's three core mechanics (drift, slipstream, near-miss) within 10 s without reading text; the first exciting moment happens before second 15. |
| Difficulty | Each stage: first-time human loss rate 30–50%; bots win with 5–9 s to spare (not 10+). |
| Visuals | **Owner addendum 2026-10-20: people and objects must read as real people and real objects, not blocks.** No capsule-and-sphere characters remain; every character has a head with a face and hair, neck, shoulders, torso with a real shirt silhouette (collar, sleeves), two-segment arms with hands, two-segment legs with shoes, outfit color code and at least idle/walk/react animations. Every hero prop (motorbike, F-Bus, desk, chair, monitor, tray, food, kiosk, shelf, tree, lamp) is a multi-part model with rounded/bevelled silhouettes and material variety (metal, plastic, fabric, wood, skin), never a single box. Each stage has its own time-of-day lighting; 60 FPS at High on an RTX 4050 laptop, 30 FPS at Low on an Intel Iris integrated GPU. |
| Audio | Every stage has adaptive procedurally generated music that reacts to tension; a mixer with Master/Music/SFX buses; no clipping. |
| UX | Pause menu, settings (volume, key remap, text size, colorblind-safe lane colors), controller support, loading/transition cards, quit confirmation; zero HUD element ever clipped. |
| Meta | End-of-day summary with GPA and title, achievements, a seeded daily challenge, best records visible in the menu. |
| Stability | The exported exe cold-starts in under 10 s on first run, writes a crash-safe log to `user://logs`, never shows a black screen longer than 2 s. |
| Code | Zero GDScript warnings at `--check-only`; duplicated character/obstacle/UI builders merged into shared modules; every stage script under 1,200 lines; PLAN.md and README.md describe the shipped state. |
| Release | `v1.1.0` built by CI with a changelog, tested exe, updated screenshots in `docs/preview/`. |

## 5. Workstreams and acceptance criteria

### A. Gameplay and pacing
Implement the review backlog in its priority order: #1 near-miss front-loading and chain multiplier, #2 keyboard shop, #3 day summary (GPA), #4 action-based onboarding, #5 transition cards, #6 canteen fairness and order board, #7 WarioWare-style survival, #8 split-information roll call, #9 rubber-band rival and mid-run event, #10 wave-transition picks and word shapes, #11 call-and-response Vovinam and tell-based finisher, #12 proctor suspicion and dossier. Follow the three detailed specs exactly; write specs of the same depth for the rest before coding them. Re-tune every stage after changes using the bots, then write down the new margins.

*Done when:* all 12 items are in, every bot test updated and green, bot margins 5–9 s, PLAN.md section IV rewritten.

### B. Visuals
1. **Characters** (owner priority, added 2026-10-20: "người và đồ vật giống thật hơn thay vì chỉ là các khối hình"): build `scripts/CharacterBuilder.gd` that assembles a believable stylized person from procedural geometry (SurfaceTool/ArrayMesh lathe and bevelled shapes are allowed, not only primitives): head with jaw shape, eyes with whites/iris, eyebrows, mouth, ears, hair cap in several styles, neck, shoulders, torso with a real shirt silhouette (collar, short sleeves, hem), two-segment arms with elbows and hands, two-segment legs with knees, trousers/skirt, shoes; outfit presets: orange FPT student shirt, lecturer (shirt + lanyard), security guard, Vovinam uniform with belt, canteen cook with apron and cap, proctor with badge. Skin tones, hair colors and heights vary per instance from a seed. Procedural cloth/skin textures are generated by `generate_textures.py` (Pillow, code-drawn, no AI images). Add a procedural animation layer: idle breathing and weight shift, walk/run cycle driven by speed (arm swing, leg stride, body bob), head look-at, sit/type/eat poses, and reaction clips (flinch, cheer, facepalm, sleepy nod, phone-hide). Replace every capsule NPC in all seven stages and the menu, including the player on the bike (leaning with steering, head turning toward the camera look direction).
1b. **Props**: build `scripts/PropBuilder.gd` with multi-part models: motorbike (frame tubes, fork, wheels with tyres + rims + hub, seat, tank, handlebars, mirrors, headlight, tail light, exhaust, licence plate), F-Bus (rounded body, wheel arches, windows with frames, doors, mirrors), classroom desk + chair (legs, apron, backrest, seat cushion), lecturer podium, monitor/laptop (bezel, stand, keyboard keys, glowing screen), canteen tray with bowls/plates/food items, Passio kiosk and 7-Eleven shelves with stocked goods, trees with trunk flare and layered canopy, campus lamps, benches, planters, motorbike helmets. Use MultiMesh where there are many copies. Replace every single-box prop in all stages and the menu.
2. **Campus life**: crowds walking the courtyard and lobby at 07:30 and 11:30, parked bikes with riders arriving, flags and planters swaying, birds over the pond, the sawtooth canopy casting real shadows. Keep draw calls in check with MultiMesh.
3. **Lighting per stage**: 07:05 low golden sun with long shadows, 07:30 cool interior with sun shafts, 09:30 harsh noon, 11:30 bright with heat haze, 23:00 night with monitor glow (already present) plus campus lamps, Extra 08:00 neutral. Tune `GameFX.upgrade_scene_visuals` presets accordingly.
4. **Readability**: lanes, hazards and interactables share a consistent color language; add a colorblind-safe alternative palette.
5. **UI theme**: one `Theme` resource built in code (panels, buttons, bars, fonts sizes) so all stages look like one product.

*Done when:* preview renders of every stage and the menu are re-captured and visually inspected; no primitive-only characters remain; frame-time targets hold at all three quality levels.

### C. Audio
1. Write `scripts/MusicGen.gd`: a code-only music generator (chip-style synth voices rendered to AudioStreamWAV at load) with per-stage parameters: BPM, key, chord loop, drum pattern, and an **intensity** input (0–1) that adds layers. Stage scripts feed intensity from tension (time left, chain, boss HP).
2. SFX pass: every player action, hit, pickup and UI interaction has a distinct sound; near-miss and combo sounds rise in pitch with the chain.
3. Audio buses Master/Music/SFX/UI with limiter; settings sliders persisted in `user://settings.cfg`.

*Done when:* music plays in all stages and the menu, reacts within 1 s to intensity changes, settings persist, no clipping in a 10-minute capture.

### D. UX and accessibility
Pause menu on ESC (resume, settings, controls, hub, quit to menu), key remapping stored in settings, controller support via InputMap with on-screen prompts switching automatically, text size option (medium/large), colorblind palette toggle, transition cards between stages, quit confirmation, "what to do now" hint that appears only after 6 s of inactivity.

*Done when:* the whole game is playable with keyboard only, with controller only, and the HUD check script passes at 1280x720, 1920x1080, 2560x1440 (write `tests/test_hud_bounds.gd`: instantiate each scene at each resolution and assert every visible Control's global rect lies inside the viewport).

### E. Performance and stability
Profile each stage at High/Medium/Low; cut the worst offenders (expected: MultiMesh grass count, SDFGI cascades, shadow distance, OmniLight counts in interiors). Add shader warm-up on the menu (instantiate a hidden sample of each material) so stage loads do not stutter. Add a crash-safe logger (flush on every stage change). Make first launch on a fresh machine robust: verify the exported exe starts with an empty `user://`.

*Done when:* frame-time targets are met and documented; the exported exe starts cleanly from an empty user folder in under 10 s.

### F. Code quality
Extract shared code: `StageBase.gd` (timers, result modal, report_stage_result, pause integration) that stage scripts extend without changing their `class_name`; `CharacterBuilder.gd`; `ObstacleFactory.gd`; `UiTheme.gd`. Enforce static typing, remove dead code, zero warnings. Update PLAN.md file tree.

*Done when:* `--check-only` shows no warnings, no stage script exceeds 1,200 lines, smoke and bots green.

### G. Testing and tooling
Keep all bots green; add `tests/test_day_summary.gd`, `tests/test_hud_bounds.gd`, `tests/test_music_gen.gd`, `tests/test_settings.gd`. Add `tests/balance_report.gd` that runs every bot and prints a one-table report of margins. Extend the GitHub workflow with a `test` job on every push that runs check, smoke and all bots; the `release` job depends on it.

*Done when:* CI runs tests on push; the balance report exists and is referenced in PLAN.md.

### H. Content and release
Day summary with GPA and titles, 12–16 achievements with code-drawn badges, seeded daily challenge (date-based seed shared by all players, separate record), changelog `CHANGELOG.md`, bump `application/product_version` to 1.1.0, refresh README screenshots, prepare release notes. Stop before tagging: the owner tags and pushes.

## 6. Order of work (milestones)

- **M1 – Quick wins (day 1–2):** review items #1, #2, #5; pause menu; audio buses + volume settings; HUD bounds test; baseline numbers recorded. Commit.
- **M2 – Feel (day 3–6):** realistic characters + props (B.1, B.1b, owner priority) + animations in all stages and the menu; per-stage lighting; music generator with two stages wired; items #4, #6. Re-render previews and compare side by side with the v1.0.0 previews. Commit.
- **M3 – Systems (day 7–10):** day summary, achievements, daily challenge; items #3, #7, #8, #9; controller support; key remap; CI test job. Commit.
- **M4 – Polish and release candidate (day 11–14):** items #10, #11, #12; music in all stages; performance pass; code extraction; docs; changelog; version bump; full test run; local export via `build_windows.bat`; run the exe from an empty user folder. Commit. Ask the owner to tag `v1.1.0`.

If time runs short, cut from the bottom of each workstream, never from tests or stability.

## 7. Working method

- **Reproduce, then fix.** For any bug or feel problem, build a tiny headless or windowed script that reproduces it (simulate keys with `Input.parse_input_event`, capture the window with the existing preview approach) before changing code.
- **Look at your output.** After any visual change, re-render the relevant preview and inspect the PNG. After any audio change, write a 10-second WAV to `user://` and inspect peak levels in a script.
- **Numbers over adjectives.** Every tuning change states old value, new value, reason, and the bot margin before and after.
- **One concern per commit**, message in the imperative, body listing what changed and how it was verified.
- **Keep docs alive.** PLAN.md is the single source of truth for mechanics and parameters; update it in the same commit as the code.
- **Ask only when blocked** on something only the owner can decide: publishing, deleting data, spending money, changing the art direction away from the real campus.

## 8. Reporting format (at the end of each milestone)

```
MILESTONE Mx – <name>
Done: bullet list with file paths
Verification: commands run and their key output lines (SUCCESS lines, margins, frame times)
Before → after numbers: table
Screenshots: paths under docs/preview/
Deviations from this brief and why:
Risks and open questions for the owner:
Next milestone plan:
```

## 9. Calibration example (expected depth of a change)

"Stage 1 oncoming traffic now spawns in six clusters at 180/320/480/640/900/1250 m (was: all after ~1100 m). Near-miss bonus is 0.5/0.75/1.0 s by chain length with a 6 s chain timer and the existing 8 s cap. Added a center-top chain panel (PanelContainer, CENTER_TOP, margin 92) with a 10 px timer bar and a 56 px 'SÁT NÚT x3!' label, hit-stop 0.04 s at chain ≥ 3, whoosh pitch 1.0/1.15/1.3. Bot `test_stage1_race.gd`: first near-miss at 12.4 s (was 57 s), 7 near-misses, longest chain 3, finish 90.1 s, 0 crashes. Rank S threshold raised 1100 → 1250. Preview `docs/preview/01_driver_view_d1.png` re-captured. PLAN.md section III.2 updated."

---

[Optional first instruction for the recipient: "Start with Section 2: read, run the baseline, and send me the baseline table and your M1 plan before writing code."]
