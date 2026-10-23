# Vice People and GTA-style Movement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** PS2-era Vice City-like people (realistic proportions, low-poly heads with painted faces) in the vice art style, GTA-style on-foot movement for the FreeRoam player, and a dense FreeRoam crowd (three tiers: physics, no-physics, MultiMesh impostors) that reacts to bumps and bike hits, plus ambient traffic.

**Architecture:** `CharacterBuilder` gains a `ps2` mode (set by GameFX for the vice style) that builds every preset on the Quaternius rigged body with a new code-built `PS2Head` (faceted mesh, Pillow face atlas with 8 expression cells switched through `uv1_offset`). `RigAnimator` gets a locomotion layer (sprint overlay, lean, idle fidgets) and new clips (jump, fall, land, skid, stumble, knockdown, get-up). `ThirdPersonController` becomes a small movement state machine. Five new FreeRoam classes add the crowd and the traffic: `PedWalkGraph` (walk network from MapData, with campus/residential/road zones), `Pedestrian` (CharacterBody3D with walk profiles and reactions), `CrowdImpostors` (far tier: 24 baked variants drawn as MultiMeshes), `PedestrianSpawner` (three tiers by distance, zone densities, night scaling, identity-keeping promotion/demotion, pool, speech bubbles) and `RoamTraffic` (motorbikes, cars and buses on right-hand lanes with look-ahead stopping).

**Tech Stack:** Godot 4.7.2, pure GDScript, Pillow/numpy (code-drawn textures), headless SceneTree tests, windowed preview scripts.

**Spec:** `docs/superpowers/specs/2026-10-22-vice-people-and-movement-design.md` (owner-approved). Owner decisions P-D1..P-D8 there are binding.

## Global Constraints

- Pure GDScript, Godot 4.2+ API; no C#, no plugins or addons; keep folder structure, scene names and `class_name`s.
- No AI-generated images; textures only drawn by code (Pillow); every new PNG gets an `.import` stub with `importer="keep"` and is loaded through `CharacterBuilder._tex()` (FileAccess) so exported builds work.
- Style homage only: no Rockstar assets, fonts, logos, names. Never a real person's likeness. Pedestrian lines are fictional and mild.
- `class_name` scripts never write the identifiers `GameFX` or `StageManager` (`CharacterBuilder.gd`, `PS2Head.gd`, `PedWalkGraph.gd`, `Pedestrian.gd`, `CrowdImpostors.gd`, `PedestrianSpawner.gd`, `RoamTraffic.gd`, `PropBuilder.gd`, `ThirdPersonController.gd`, `MapBuilder.gd`, `MapData.gd`, `FPTUCampusBuilder.gd`). Read settings through `get_node_or_null("/root/GameFX")`.
- Models change only in vice (`CharacterBuilder.ps2 == true`); classic characters stay exactly as today (P-D2). Movement and pedestrians apply in both styles (P-D3). Clothing unchanged (P-D8).
- Controls (P-D4): jog by default; hold Shift = sprint with 6 s stamina; hold Ctrl = walk; Space = jump on foot (Space stays "drift" on the bike); F, E, T, M, Z, C, Esc unchanged.
- Falls never hurt (P-D5): < 2.5 m soft landing, 2.5..6 m roll, > 6 m splat 1.5 s then get up. Hitting pedestrians has no penalty (P-D6). Pedestrians only in FreeRoam (P-D7).
- Performance gates (RTX 4050, 1280x720, quality 2, V-Sync off): FreeRoam with full daytime density (three crowd tiers + ambient traffic) >= 45 fps at the BE6 spawn, the campus main gate and on Nguyễn Xiển; every stage >= 45 fps; building one character < 15 ms after the first.
- Headless safety: no RenderingDevice work when `DisplayServer.get_name() == "headless"`.
- Test hygiene: never pipe Godot output through `head`/`grep` directly (redirect to a log, then grep); a failed `assert` inside `_initialize` hangs `--script` runs, so tests use a `_check(cond, msg)` helper that prints and calls `quit(2)`; if Godot exits 139 right after a SUCCESS line, re-run once (known shutdown crash).
- A fresh git worktree has no `.godot` cache: run `godot --headless --import --path .` before any test, and again after adding a new `class_name` script; confirm the class appears in `.godot/global_script_class_cache.cfg`. Do the same on main after every merge.
- Write files that contain Vietnamese text with the file tools, never bash heredocs. Python printing Vietnamese needs `PYTHONIOENCODING=utf-8`.
- Full regression after every task: `godot --headless --quit --check-only --path .` (0 `ERROR`), `tests/smoke_all_stages.gd` (0 `ERROR:` / `SCRIPT ERROR`), and every `tests/test_*.gd` (list: `ls tests/test_*.gd`). Commit after every green task; commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never push, tag or release.
- Scheduling: Tasks 1-7 only touch character, controller and texture files and may run before the VC-2/VC-4 branches merge. Tasks 8-14 (Tasks 8, 12 and 13 edit `scripts/FreeRoam.gd`) must start after VC-2 and VC-4 are merged into main (merged 2026-10-22).

Regression command used by every task (run from the repo root; it prints one line per test):

```bash
L=/tmp/vpm_logs; mkdir -p $L
godot --headless --quit --check-only --path . > $L/check.log 2>&1; echo "check exit=$? errors=$(grep -c ERROR $L/check.log)"
for t in $(ls tests/test_*.gd | xargs -n1 basename | sed 's/\.gd$//'); do
  godot --headless --path . --script tests/$t.gd > $L/$t.log 2>&1; rc=$?
  echo "$t exit=$rc :: $(grep -E 'SUCCESS|FAIL' $L/$t.log | tail -1)"
done
godot --headless --path . --script tests/smoke_all_stages.gd > $L/smoke.log 2>&1; echo "smoke exit=$? errors=$(grep -c 'SCRIPT ERROR\|^ERROR:' $L/smoke.log)"
```

---

## File map

| File | Status | Responsibility |
|---|---|---|
| `generate_character_textures.py` | modify | PS2 face atlases (`char_ps2_face_<tone><sex><variant>.png`) and hair strands (`char_ps2_hair.png`) |
| `scripts/characters/PS2Head.gd` | create | Faceted head mesh, face atlas material and expression cells, hair shells, PS2 glasses |
| `scripts/CharacterBuilder.gd` | modify | `ps2` mode, rigged-for-all routing, PS2 head on rigged and code bodies, attach pivots, face-cell blink and expressions, rigged `pose()`/`bake()`, PS2 baked riders, new clips, RigAnimator locomotion layer, static `stride` clip (crowd impostors), standing `phone_stand` clip (pedestrians) |
| `scripts/GameFX.gd` | modify (1 function) | `_apply_art_style_statics()` sets `CharacterBuilder.ps2` and head scale |
| `scripts/ThirdPersonController.gd` | modify | Movement state machine, stamina, jump/landing, lean, camera FOV/bob/shake, `walk`/`jump` actions |
| `scripts/roam/PedWalkGraph.gd` | create | Walk network from MapData with campus/residential/road zones and spatial queries |
| `scripts/roam/Pedestrian.gd` | create | Pedestrian body, walk profiles and identity, wandering, mid tier without physics, contact detection, reactions, lines |
| `scripts/roam/CrowdImpostors.gd` | create | Far crowd tier: 24 fixed variants baked in a stride pose, one MultiMesh each, gliding along the walk graph |
| `scripts/roam/PedestrianSpawner.gd` | create | Three crowd tiers, zone densities, night scaling, identity-keeping promotion/demotion, pool, speech bubble, hit consequences |
| `scripts/roam/RoamTraffic.gd` | create | Ambient vehicles on right-hand lanes of MapData carriageways, Bezier turns, look-ahead stopping, recycling, night scaling |
| `scripts/PropBuilder.gd` | modify (1 function) | `build_car()` hatchback for ambient traffic |
| `scripts/FreeRoam.gd` | modify | Stamina bar and hint text, `crowd_enabled`, crowd spawner and traffic wiring |
| `tests/test_ps2_textures.gd`, `tests/test_ps2_head.gd`, `tests/test_ps2_people.gd`, `tests/test_locomotion_anim.gd`, `tests/test_locomotion.gd`, `tests/test_pedestrians.gd`, `tests/test_crowd_impostors.gd`, `tests/test_roam_traffic.gd` | create | Headless tests |
| `tests/support/stub_mover.gd`, `tests/support/stub_roam.gd` | create | Test stubs (player / bike speed, FreeRoam flags) |
| `tests/test_free_roam.gd` | modify | Jump checks near water guards; builds FreeRoam with `crowd_enabled = false` |
| `tests/preview_people.gd`, `tests/preview_movement.gd`, `tests/preview_peds.gd` | create | Windowed previews |
| `README.md`, `PLAN.md`, `docs/superpowers/plans/2026-10-22-vice-city-art-direction.md`, the spec | modify | Docs |

---

### Task 1: PS2 face atlases and hair texture

**Files:**
- Modify: `generate_character_textures.py` (new section before `if __name__ == "__main__":`, new calls in the main block)
- Create: `tests/test_ps2_textures.gd`
- Create (generated): `assets/textures/char_ps2_face_{a,b,c,d}{m,f}{0,1,2}.png` (24 files) + `.import` stubs, `assets/textures/char_ps2_hair.png` + `.import`

**Interfaces:**
- Produces: atlas layout used by Task 2: 512×256 px, 4 columns × 2 rows of 128×128 cells in the order `["open", "closed", "happy", "angry", "surprised", "done", "talk", "pain"]`. Inside a cell the face is projected from the front: `u = 0.5 + x / 0.2`, `v = 1 - y / 0.235` (x, y in metres in head space: origin at the chin, -Z forward). A 3 px plain-skin border surrounds every cell.

- [ ] **Step 1: Write the failing test**

Create `tests/test_ps2_textures.gd`:

```gdscript
# File: res://tests/test_ps2_textures.gd
# Test headless texture mặt PS2: đủ 24 atlas 512x256 + tóc 128x128, ô "closed" khác ô "open" ở vùng mắt,
# viền mỗi ô là da trơn (khớp góc da dưới trái mà PS2Head.SKIN_UV lấy).
# Chạy:  godot --headless --path . --script tests/test_ps2_textures.gd
extends SceneTree

const TONES: Array[String] = ["a", "b", "c", "d"]
const CELL: int = 128

var done: bool = false


func _initialize() -> void:
	for t: String in TONES:
		for s: String in ["m", "f"]:
			for v: int in range(3):
				var name: String = "char_ps2_face_%s%s%d.png" % [t, s, v]
				var img: Image = _load(name)
				if not _check(img != null, "%s missing (run: python generate_character_textures.py --ps2-only)" % name):
					return
				if not _check(img.get_width() == 512 and img.get_height() == 256, "%s must be 512x256 (got %dx%d)" % [name, img.get_width(), img.get_height()]):
					return
				if not _check(FileAccess.file_exists("res://assets/textures/%s.import" % name), "%s.import stub missing" % name):
					return
				# eye window (left eye, x = -0.032 m, y = 0.125 m) differs between "open" (cell 0) and "closed" (cell 1)
				var ex: int = int((0.5 - 0.032 / 0.2) * CELL) - 6
				var ey: int = int((1.0 - 0.125 / 0.235) * CELL) - 3
				var diff: float = 0.0
				for y: int in range(6):
					for x: int in range(12):
						var a: Color = img.get_pixel(ex + x, ey + y)
						var b: Color = img.get_pixel(CELL + ex + x, ey + y)
						diff += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
				diff = diff / 72.0 * 255.0
				if not _check(diff > 20.0, "%s: closed cell must differ from open in the eye window (mean diff %.1f)" % [name, diff]):
					return
				# every cell border pixel matches the plain-skin corner of cell 0
				var skin: Color = img.get_pixel(2, CELL - 3)
				for c: int in range(8):
					var ox: int = (c % 4) * CELL
					var oy: int = (c / 4) * CELL
					for p: Vector2i in [Vector2i(1, 64), Vector2i(CELL - 2, 64), Vector2i(64, 1), Vector2i(64, CELL - 2)]:
						var px: Color = img.get_pixel(ox + p.x, oy + p.y)
						if not _check(absf(px.r - skin.r) < 0.06 and absf(px.g - skin.g) < 0.06 and absf(px.b - skin.b) < 0.06, "%s cell %d border pixel %s is not plain skin" % [name, c, p]):
							return
	var hair: Image = _load("char_ps2_hair.png")
	if not _check(hair != null and hair.get_width() == 128 and hair.get_height() == 128, "char_ps2_hair.png must exist at 128x128"):
		return
	print("✅ SUCCESS: PS2 FACE ATLASES (24) AND HAIR TEXTURE OK")
	quit(0)


func _load(name: String) -> Image:
	var path: String = "res://assets/textures/" + name
	if not FileAccess.file_exists(path):
		return null
	var img := Image.new()
	if img.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return null
	return img


func _check(ok: bool, msg: String) -> bool:
	if not ok and not done:
		done = true
		print("❌ FAILED: ", msg)
		quit(2)
	return ok
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless --path . --script tests/test_ps2_textures.gd > /tmp/t1.log 2>&1; grep -E "SUCCESS|FAILED" /tmp/t1.log`
Expected: `❌ FAILED: char_ps2_face_am0.png missing (run: python generate_character_textures.py --ps2-only)`

- [ ] **Step 3: Implement the generator**

In `generate_character_textures.py` add `import sys` to the imports line (`import os, math, random, sys`), then insert this section just before `if __name__ == "__main__":`:

```python
# ---------------------------------------------------------------- MẶT PS2 (đầu low-poly kiểu PS2, phong cách Vice City)
# Atlas 512x256 = 4 x 2 ô 128x128 theo PS2_CELLS (khớp PS2Head.CELLS). Mỗi ô chiếu phẳng mặt trước:
#   u = 0.5 + x / PS2_FACE_SPAN, v = 1 - y / PS2_HEAD_H (x, y theo mét trong hệ đầu: gốc ở cằm, -Z phía trước).
# Viền 3 px mỗi ô là da trơn: mặt sau đầu (PS2Head lấy cột mép ô) và lọc texture giữa các ô không lộ đường nối.
PS2_CELLS = ["open", "closed", "happy", "angry", "surprised", "done", "talk", "pain"]
PS2_HEAD_H = 0.235
PS2_FACE_SPAN = 0.2
PS2_CELL = 128
PS2_SS = 4  # vẽ ở 4x rồi thu nhỏ LANCZOS cho nét kiểu vẽ tay


def _ps2_px(x, y):
    n = PS2_CELL * PS2_SS
    return ((0.5 + x / PS2_FACE_SPAN) * n, (1.0 - y / PS2_HEAD_H) * n)


def _ps2_cell(tone_key, sex, variant, expr):
    n = PS2_CELL * PS2_SS
    S = PS2_SS
    base = np.array(TONES[tone_key], dtype=np.float32)
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    u = xx / n - 0.5
    v = yy / n
    shade = 1.0 - 0.10 * np.clip((v - 0.62) / 0.38, 0, 1)            # hàm hơi tối
    shade *= 1.0 - 0.16 * np.clip((np.abs(u) - 0.18) / 0.32, 0, 1)   # hai bên má tối (ánh sáng nướng sẵn kiểu PS2)
    shade *= 1.0 + 0.05 * np.clip((0.40 - v) / 0.40, 0, 1)           # trán sáng
    arr = base[None, None, :] * shade[:, :, None]
    arr += ((noise(n, n, 3, 0.6, 11 + variant) - 0.5) * 8.0)[:, :, None]
    im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(im, "RGBA")
    skin = tuple(int(c) for c in base)
    dark = tuple(int(c * 0.55) for c in base)
    line = (40, 26, 20, 255)

    def P(x, y):
        return _ps2_px(x, y)

    def ell(cx, cy, rx, ry, **kw):
        x0, y0 = P(cx - rx, cy + ry)
        x1, y1 = P(cx + rx, cy - ry)
        d.ellipse([x0, y0, x1, y1], **kw)

    # tai (gần mép ô, x = +-0.086)
    for sx in (-1, 1):
        ell(sx * 0.086, 0.125, 0.009, 0.024, fill=dark + (70,))
        d.line([P(sx * 0.086, 0.14), P(sx * 0.083, 0.11)], fill=dark + (120,), width=S * 2)
    # mũi: bóng hai bên, lỗ mũi, điểm sáng đầu mũi
    for sx in (-1, 1):
        d.line([P(sx * 0.010, 0.128), P(sx * 0.013, 0.096)], fill=dark + (60,), width=S * 3)
        ell(sx * 0.0085, 0.089, 0.0035, 0.0022, fill=dark + (170,))
    ell(0.0, 0.097, 0.006, 0.004, fill=(255, 255, 255, 40))
    # râu lún phún (nam, biến thể 1) / ria mép + rãnh má (nam, biến thể 2)
    if sex == "m" and variant == 1:
        rng = random.Random(77 + ord(tone_key))
        for _ in range(900):
            x = rng.uniform(-0.05, 0.05)
            y = rng.uniform(0.008, 0.075)
            if abs(x) < 0.02 and 0.066 < y < 0.075:
                continue
            if (x / 0.055) ** 2 + ((y - 0.035) / 0.045) ** 2 > 1.0:
                continue
            d.point(P(x, y), fill=(40, 30, 26, 70))
    if sex == "m" and variant == 2:
        d.line([P(-0.017, 0.071), P(0.0, 0.074), P(0.017, 0.071)], fill=(46, 32, 24, 200), width=S * 3)
        d.line([P(-0.024, 0.098), P(-0.021, 0.064)], fill=dark + (55,), width=S * 2)
        d.line([P(0.024, 0.098), P(0.021, 0.064)], fill=dark + (55,), width=S * 2)
    # lông mày theo biểu cảm
    brow_w = S * (4 if sex == "m" else 2) + (S * 2 if (sex == "m" and variant == 1) else 0)
    for sx in (-1, 1):
        inner, outer = (sx * 0.013, 0.145), (sx * 0.047, 0.147)
        if expr == "angry":
            inner, outer = (sx * 0.013, 0.137), (sx * 0.047, 0.152)
        elif expr == "surprised":
            inner, outer = (sx * 0.013, 0.156), (sx * 0.047, 0.157)
        elif expr == "pain":
            inner, outer = (sx * 0.013, 0.153), (sx * 0.047, 0.142)
        elif expr == "done":
            inner, outer = (sx * 0.013, 0.141), (sx * 0.047, 0.142)
        mid = ((inner[0] + outer[0]) / 2, max(inner[1], outer[1]) + 0.003)
        d.line([P(*inner), P(*mid), P(*outer)], fill=(44, 30, 22, 235), width=brow_w, joint="curve")
    # mắt
    ey = 0.125
    for sx in (-1, 1):
        ex = sx * 0.032
        if expr == "closed":
            d.arc([*P(ex - 0.012, ey + 0.004), *P(ex + 0.012, ey - 0.006)], 10, 170, fill=line, width=S * 2)
            continue
        if expr == "happy":
            d.arc([*P(ex - 0.012, ey + 0.002), *P(ex + 0.012, ey - 0.010)], 190, 350, fill=line, width=S * 2)
            continue
        if expr == "pain":
            d.line([P(ex - 0.012 * sx, ey + 0.004), P(ex + 0.010 * sx, ey), P(ex - 0.012 * sx, ey - 0.004)], fill=line, width=S * 2)
            continue
        rx, ry = 0.0125, 0.0055
        if expr == "surprised":
            ry = 0.0085
        if expr == "angry":
            ry = 0.0042
        ell(ex, ey, rx, ry, fill=(246, 242, 238, 255))
        ir = 0.0048 if expr != "surprised" else 0.0036
        ell(ex, ey - 0.0005, ir, ir, fill=(78, 50, 30, 255))
        ell(ex, ey - 0.0005, ir * 0.45, ir * 0.45, fill=(14, 10, 8, 255))
        ell(ex - 0.0018, ey + 0.0018, 0.0012, 0.0012, fill=(255, 255, 255, 220))
        d.arc([*P(ex - rx - 0.001, ey + ry + 0.001), *P(ex + rx + 0.001, ey - ry - 0.001)], 190, 350, fill=line, width=S * (3 if sex == "f" else 2))
        if expr == "done":
            x0, y0 = P(ex - rx - 0.001, ey + ry + 0.002)
            x1, y1 = P(ex + rx + 0.001, ey)
            d.rectangle([x0, y0, x1, y1], fill=skin + (255,))
            d.line([P(ex - rx, ey), P(ex + rx, ey)], fill=line, width=S * 2)
        if sex == "f" and variant == 2:
            d.line([P(ex + sx * rx, ey + 0.001), P(ex + sx * (rx + 0.006), ey + 0.005)], fill=line, width=S * 2)
    # miệng
    my = 0.058
    lip = tuple(int(c) for c in (base * np.array([0.78, 0.55, 0.55])))
    if sex == "f":
        lip = (176, 70, 84) if variant != 1 else (196, 42, 60)
    mw = 0.016 if sex == "m" else 0.0145
    if expr == "happy":
        d.chord([*P(-mw - 0.002, my + 0.006), *P(mw + 0.002, my - 0.010)], 0, 180, fill=(110, 40, 46, 255))
        d.chord([*P(-mw + 0.001, my + 0.005), *P(mw - 0.001, my - 0.002)], 0, 180, fill=(248, 246, 240, 255))
    elif expr == "angry":
        d.arc([*P(-mw, my + 0.002), *P(mw, my - 0.012)], 200, 340, fill=lip + (255,), width=S * 3)
    elif expr == "surprised":
        ell(0.0, my - 0.002, 0.0065, 0.008, fill=(80, 30, 34, 255))
    elif expr == "talk":
        ell(0.0, my - 0.001, mw * 0.8, 0.0055, fill=(80, 30, 34, 255))
        x0, y0 = P(-mw * 0.7, my + 0.004)
        x1, y1 = P(mw * 0.7, my + 0.0015)
        d.rectangle([x0, y0, x1, y1], fill=(246, 244, 236, 255))
    elif expr == "pain":
        x0, y0 = P(-mw, my + 0.004)
        x1, y1 = P(mw, my - 0.005)
        d.rectangle([x0, y0, x1, y1], fill=(246, 244, 236, 255))
        d.rectangle([x0, y0, x1, y1], outline=(100, 40, 44, 255), width=S * 2)
        d.line([P(-mw, my - 0.0005), P(mw, my - 0.0005)], fill=(150, 120, 110, 255), width=S)
    else:  # open, closed, done
        d.line([P(-mw, my), P(0.0, my - 0.0015), P(mw, my)], fill=lip + (255,), width=S * 3)
        ell(0.0, my - 0.0045, mw * 0.6, 0.0022, fill=lip + (120,))
    if expr == "done":
        d.polygon([P(0.07, 0.17), P(0.074, 0.155), P(0.066, 0.155)], fill=(130, 190, 240, 230))
    # viền da trơn
    m = 3 * S
    d.rectangle([0, 0, n - 1, m], fill=skin + (255,))
    d.rectangle([0, n - 1 - m, n - 1, n - 1], fill=skin + (255,))
    d.rectangle([0, 0, m, n - 1], fill=skin + (255,))
    d.rectangle([n - 1 - m, 0, n - 1, n - 1], fill=skin + (255,))
    return im.resize((PS2_CELL, PS2_CELL), Image.Resampling.LANCZOS)


def make_ps2_face_atlas(tone_key, sex, variant):
    atlas = Image.new("RGB", (PS2_CELL * 4, PS2_CELL * 2))
    for i, expr in enumerate(PS2_CELLS):
        atlas.paste(_ps2_cell(tone_key, sex, variant, expr), ((i % 4) * PS2_CELL, (i // 4) * PS2_CELL))
    save(atlas, "char_ps2_face_%s%s%d.png" % (tone_key, sex, variant))


def make_ps2_hair():
    """Sợi tóc xám (nhân albedo_color tóc), dọc theo trục V – lặp được."""
    W = H = 128
    rng = np.random.default_rng(91)
    cols = rng.random(W).astype(np.float32)
    strands = np.tile(cols[None, :], (H, 1))
    strands = np.asarray(Image.fromarray((strands * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(0.6)), dtype=np.float32) / 255.0
    n = noise(W, H, 3, 0.55, 93)
    val = 0.72 + 0.22 * strands + 0.12 * (n - 0.5)
    save(Image.fromarray(np.clip(val * 255, 0, 255).astype(np.uint8), "L").convert("RGB"), "char_ps2_hair.png")


def make_ps2_all():
    for t in TONES:
        for s in ("m", "f"):
            for v in range(3):
                make_ps2_face_atlas(t, s, v)
    make_ps2_hair()
```

Replace the main block with:

```python
if __name__ == "__main__":
    print("Generating character textures ->", OUT_DIR)
    if "--ps2-only" not in sys.argv:
        for t in TONES:
            for s in ("m", "f"):
                for ex in EXPRESSIONS:
                    make_face(t, s, ex)
        make_cloth_folds()
        make_logo_patch()
        make_shirt_fpt()
        make_cloth_normal()
        make_denim()
        make_hair_normal()
        make_skin_normal()
    make_ps2_all()
    print("DONE")
```

Run: `PYTHONIOENCODING=utf-8 python generate_character_textures.py --ps2-only`
Expected: 25 `wrote char_ps2_...` lines then `DONE`. Open `assets/textures/char_ps2_face_bm0.png` and `char_ps2_face_cf2.png` with the Read tool: 8 readable faces per atlas (neutral, closed, smiling with teeth, angry brows, surprised O mouth, half-lidded with a sweat drop, talking, pained grimace), skin borders, no feature crossing a cell edge.

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot --headless --path . --script tests/test_ps2_textures.gd > /tmp/t1.log 2>&1; grep -E "SUCCESS|FAILED" /tmp/t1.log`
Expected: `✅ SUCCESS: PS2 FACE ATLASES (24) AND HAIR TEXTURE OK`

- [ ] **Step 5: Regression and commit**

Run the regression command (Global Constraints). Expected: every line `exit=0` with a SUCCESS message, check and smoke 0 errors. Then:

```bash
git add generate_character_textures.py tests/test_ps2_textures.gd assets/textures/char_ps2_*
git commit -m "feat(people): PS2 face atlases (8 expression cells) and hair strand texture, code-drawn

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `PS2Head` (faceted head, face cells, hair shells)

**Files:**
- Create: `scripts/characters/PS2Head.gd`
- Create: `tests/test_ps2_head.gd`

**Interfaces:**
- Consumes: Task 1 atlases; `CharacterBuilder._tex(file) -> Texture2D`, `CharacterBuilder._mat(key, color, rough, metal) -> StandardMaterial3D`, `CharacterBuilder._box(parent, pos, size, mat, rot) -> MeshInstance3D`, `CharacterBuilder._build_hair(head, style, hair_idx, outfit, width, rng)` (hat branches), `CharacterBuilder._build_helmet(head, color, width)`, `CharacterBuilder.SKIN_KEYS`, `CharacterBuilder.SKIN_TONES`, `CharacterBuilder.HAIR_COLORS`, `CharacterBuilder._mat_cache`.
- Produces (used by Tasks 3, 4, 10):
  - `PS2Head.build(parent: Node3D, pos: Vector3, opts: Dictionary, rig: Dictionary) -> Node3D` — pivot `Head` (meta `ps2_head` = true) with children `HeadMesh`, `Hair` (or hat parts), optional glasses/helmet, `HeadTop` at y 0.27; writes `rig["head"]`, `rig["face_mesh"]`, `rig["head_top"]`. opts: `skin` 0..3, `female` bool, `variant` 0..2 (random from seed when absent), `hair_style`, `hair_color` 0..4, `width` 0.94..1.06, `seed` int, `outfit` Dictionary (`glasses`, `helmet` + `helmet_color`, `cap` + `cap_color`, `chef_hat`).
  - `PS2Head.CELLS: Array[String]`, `PS2Head.cell_offset(expr: String) -> Vector3` (the material `uv1_offset` for that cell), `PS2Head.face_material(skin_idx: int, female: bool, variant: int) -> StandardMaterial3D` (unique per call, meta `ps2_face` = true when the atlas loaded, `uv1_scale` = (0.25, 0.5, 1)).
  - `PS2Head.head_mesh(k: Dictionary) -> ArrayMesh`, `PS2Head.hair_mesh(style: String, k: Dictionary) -> ArrayMesh` (cached), `PS2Head.HEAD_H` = 0.235.
  - Head frame identical to the old code head: pivot at the chin, face toward -Z, head centre about y 0.12, so the old glasses/helmet/cap/chef-hat builders fit.

- [ ] **Step 1: Write the failing test**

Create `tests/test_ps2_head.gd`:

```gdscript
# File: res://tests/test_ps2_head.gd
# Test headless PS2Head: số tam giác, kích thước, chiều quấn mặt hướng ra ngoài, UV mặt trước / sau đầu,
# mọi kiểu tóc bao đỉnh đầu, build() ghi rig + vật liệu một ô atlas, ô biểu cảm, kính, mũ đầu bếp.
# Chạy:  godot --headless --path . --script tests/test_ps2_head.gd
extends SceneTree

var done: bool = false


func _initialize() -> void:
	var k: Dictionary = {"w": 1.0, "jaw": 1.0, "nose": 1.0}
	var mesh: ArrayMesh = PS2Head.head_mesh(k)
	var arr: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var tris: int = idx.size() / 3
	print("  head: %d triangles, %d vertices" % [tris, verts.size()])
	if not _check(tris >= 250 and tris <= 420, "head must have 250..420 triangles (got %d)" % tris):
		return
	var ab: AABB = mesh.get_aabb()
	print("  head aabb: ", ab)
	if not _check(absf(ab.size.y - PS2Head.HEAD_H) < 0.012, "head height must be ~0.235 m (got %.3f)" % ab.size.y):
		return
	if not _check(ab.size.x > 0.15 and ab.size.x < 0.2, "head width must be 0.15..0.2 m incl. ears (got %.3f)" % ab.size.x):
		return
	if not _check(ab.position.z < -0.115, "nose must stick out in front (aabb front z %.3f)" % ab.position.z):
		return
	# winding: (c - a) x (b - a) points outward for at least 95 % of triangles (Godot front faces are clockwise)
	var outward: int = 0
	for t: int in range(tris):
		var a: Vector3 = verts[idx[t * 3]]
		var b: Vector3 = verts[idx[t * 3 + 1]]
		var c: Vector3 = verts[idx[t * 3 + 2]]
		var cen: Vector3 = (a + b + c) / 3.0
		var out: Vector3 = cen - Vector3(0.0, 0.12, 0.0)
		if (c - a).cross(b - a).dot(out) >= -0.0000001:
			outward += 1
	if not _check(float(outward) / float(tris) >= 0.95, "only %d of %d triangles face outward" % [outward, tris]):
		return
	# UV: the front vertex nearest the eye line maps near (0.5, 0.468); the back of the head maps to a skin border column
	var front_uv := Vector2(-1.0, -1.0)
	var back_ok: bool = true
	var best: float = 99.0
	for i: int in range(verts.size()):
		var p: Vector3 = verts[i]
		var d: float = Vector2(p.x, p.y - 0.125).length() if p.z < -0.05 else 99.0
		if d < best:
			best = d
			front_uv = uvs[i]
		if p.z > 0.09 and p.y > 0.08 and p.y < 0.2 and uvs[i].x > 0.03 and uvs[i].x < 0.97:
			back_ok = false
	print("  front uv ", front_uv)
	if not _check(absf(front_uv.x - 0.5) < 0.03 and absf(front_uv.y - (1.0 - 0.125 / 0.235)) < 0.08, "front vertex uv must be near (0.5, 0.47), got %s" % front_uv):
		return
	if not _check(back_ok, "back-of-head vertices must map to a skin border column (u < 0.03 or u > 0.97)"):
		return
	for style: String in PS2Head.HAIR_STYLES:
		var hm: ArrayMesh = PS2Head.hair_mesh(style, k)
		var hab: AABB = hm.get_aabb()
		var ht: int = hm.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 3 if hm.surface_get_arrays(0)[Mesh.ARRAY_INDEX] == null else hm.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3
		if not _check(ht > 20 and hab.end.y >= PS2Head.HEAD_H, "hair %s must cover the crown (%d tris, top %.3f)" % [style, ht, hab.end.y]):
			return
	# build(): rig keys, face material on one atlas cell, glasses, cell offsets
	var holder := Node3D.new()
	root.add_child(holder)
	var rig: Dictionary = {}
	var head: Node3D = PS2Head.build(holder, Vector3.ZERO, {"skin": 2, "female": true, "variant": 1, "hair_style": "ponytail", "hair_color": 1, "seed": 7, "outfit": {"glasses": true}}, rig)
	if not _check(head != null and head.name == "Head" and bool(head.get_meta("ps2_head", false)), "build() returns the Head pivot with meta ps2_head"):
		return
	for key: String in ["head", "face_mesh", "head_top"]:
		if not _check(rig.has(key), "rig[%s] missing" % key):
			return
	var fm: StandardMaterial3D = (rig["face_mesh"] as MeshInstance3D).material_override as StandardMaterial3D
	if not _check(fm != null and bool(fm.get_meta("ps2_face", false)) and fm.uv1_scale.is_equal_approx(Vector3(0.25, 0.5, 1.0)), "face material samples one atlas cell"):
		return
	if not _check(PS2Head.cell_offset("open").is_equal_approx(Vector3.ZERO) and PS2Head.cell_offset("angry").is_equal_approx(Vector3(0.75, 0.0, 0.0)) and PS2Head.cell_offset("pain").is_equal_approx(Vector3(0.75, 0.5, 0.0)), "cell offsets follow the 4 x 2 atlas order"):
		return
	if not _check(head.get_node_or_null("Hair") != null, "hair mesh node missing"):
		return
	var n_mi: int = 0
	for ch: Node in head.get_children():
		if ch is MeshInstance3D:
			n_mi += 1
	if not _check(n_mi >= 10, "glasses must add frame parts (only %d mesh instances under Head)" % n_mi):
		return
	var rig2: Dictionary = {}
	var chef: Node3D = PS2Head.build(holder, Vector3(1.0, 0.0, 0.0), {"skin": 0, "seed": 3, "outfit": {"chef_hat": true}}, rig2)
	if not _check(chef.get_node_or_null("Hair") == null and chef.get_child_count() >= 5, "chef hat path builds the hat instead of the hair shell"):
		return
	print("✅ SUCCESS: PS2 HEAD MESH, UV, HAIR, CELLS AND ACCESSORIES OK")
	quit(0)


func _check(ok: bool, msg: String) -> bool:
	if not ok and not done:
		done = true
		print("❌ FAILED: ", msg)
		quit(2)
	return ok
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless --path . --script tests/test_ps2_head.gd > /tmp/t2.log 2>&1; grep -E "SUCCESS|FAILED|Identifier" /tmp/t2.log`
Expected: a parse error `Identifier "PS2Head" not declared in the current scope.` (no SUCCESS line).

- [ ] **Step 3: Implement `PS2Head`**

Create `scripts/characters/PS2Head.gd`:

```gdscript
# File: res://scripts/characters/PS2Head.gd
# Đầu người kiểu PS2 (phong cách Vice City): khối ít mặt (~300 tam giác) dựng từ bảng vòng RINGS, mặt vẽ Pillow
# chiếu phẳng từ phía trước (atlas 4 x 2 ô biểu cảm; đổi ô bằng uv1_offset của vật liệu riêng mỗi nhân vật), tóc là vỏ
# ít mặt theo kiểu tóc. Cùng hệ toạ độ với đầu tự dựng cũ của CharacterBuilder (pivot "Head" ở chân cằm, mặt nhìn -Z,
# tâm đầu ~y 0.12) nên kính / mũ bảo hiểm / mũ bảo vệ / mũ đầu bếp cũ vẫn khớp.
# Không dùng autoload ở đây (class_name biên dịch trước autoload khi chạy test --script).
class_name PS2Head
extends RefCounted

const HEAD_H: float = 0.235
const FACE_U_SPAN: float = 0.2
const BACK_UV_DEG: float = 100.0
const CELLS: Array[String] = ["open", "closed", "happy", "angry", "surprised", "done", "talk", "pain"]
const ATLAS_COLS: int = 4
const ATLAS_ROWS: int = 2
const SEGMENTS: int = 16
const SUPER_N: float = 2.6
## [y, nửa bề ngang, sâu phía trước, sâu phía sau] từ cằm (y 0) lên đỉnh đầu.
const RINGS: Array = [
	[0.000, 0.028, 0.058, 0.004],
	[0.022, 0.050, 0.080, 0.032],
	[0.050, 0.064, 0.094, 0.064],
	[0.080, 0.072, 0.100, 0.088],
	[0.110, 0.077, 0.101, 0.100],
	[0.140, 0.079, 0.099, 0.106],
	[0.170, 0.077, 0.093, 0.104],
	[0.198, 0.066, 0.077, 0.090],
	[0.220, 0.044, 0.050, 0.060],
	[0.235, 0.000, 0.000, 0.000],
]
const HAIR_STYLES: Array[String] = ["short", "side_part", "spiky", "undercut", "bob", "ponytail", "long", "bun"]
const HAIR_PUFF: float = 1.07
## Mép dưới của tóc (y, m) theo dải góc: [trước |θ| < 50°, hai bên < 110°, sau gáy].
const HAIRLINES: Dictionary = {
	"short": [0.180, 0.125, 0.040], "side_part": [0.172, 0.125, 0.040], "spiky": [0.182, 0.130, 0.045],
	"undercut": [0.176, 0.172, 0.150], "bob": [0.168, 0.030, 0.020], "ponytail": [0.176, 0.120, 0.060],
	"long": [0.168, 0.030, 0.010], "bun": [0.178, 0.122, 0.070],
}

static var _mesh_cache: Dictionary = {}


# ===========================================================================
# API
# ===========================================================================
## Dựng đầu PS2 dưới parent: pivot "Head" tại pos. Ghi rig["head"], rig["face_mesh"], rig["head_top"].
static func build(parent: Node3D, pos: Vector3, opts: Dictionary, rig: Dictionary) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(opts.get("seed", 1))
	var female: bool = bool(opts.get("female", false))
	var skin_idx: int = clampi(int(opts.get("skin", 1)), 0, CharacterBuilder.SKIN_TONES.size() - 1)
	var variant: int = clampi(int(opts.get("variant", rng.randi_range(0, 2))), 0, 2)
	var width: float = float(opts.get("width", 1.0))
	var k: Dictionary = {
		"w": snappedf(width * (0.95 if female else 1.0), 0.01),
		"jaw": snappedf((0.9 if female else 1.0) * rng.randf_range(0.94, 1.06), 0.01),
		"nose": snappedf((0.85 if female else 1.0) * rng.randf_range(0.88, 1.12), 0.01),
	}
	var head := Node3D.new()
	head.name = "Head"
	head.position = pos
	parent.add_child(head)
	rig["head"] = head
	var mi := MeshInstance3D.new()
	mi.name = "HeadMesh"
	mi.mesh = head_mesh(k)
	mi.material_override = face_material(skin_idx, female, variant)
	head.add_child(mi)
	rig["face_mesh"] = mi
	var outfit: Dictionary = opts.get("outfit", {})
	var hair_idx: int = clampi(int(opts.get("hair_color", 0)), 0, CharacterBuilder.HAIR_COLORS.size() - 1)
	if bool(outfit.get("chef_hat", false)) or bool(outfit.get("cap", false)):
		CharacterBuilder._build_hair(head, "short", hair_idx, outfit, width, rng)   # mũ + tóc ngắn của bộ dựng cũ (vừa đầu này)
	else:
		var hm := MeshInstance3D.new()
		hm.name = "Hair"
		hm.mesh = hair_mesh(String(opts.get("hair_style", "short")), k)
		hm.material_override = hair_material(hair_idx)
		head.add_child(hm)
	if bool(outfit.get("glasses", false)):
		_build_glasses(head, k)
	if bool(outfit.get("helmet", false)):
		CharacterBuilder._build_helmet(head, outfit.get("helmet_color", Color("#F1C40F")), width)
	var top := Node3D.new()
	top.name = "HeadTop"
	top.position = Vector3(0.0, 0.27, 0.0)
	head.add_child(top)
	rig["head_top"] = top
	head.set_meta("ps2_head", true)
	return head


## uv1_offset của ô biểu cảm (ô lạ -> "open").
static func cell_offset(expr: String) -> Vector3:
	var i: int = maxi(0, CELLS.find(expr))
	return Vector3(float(i % ATLAS_COLS) / float(ATLAS_COLS), float(floori(float(i) / float(ATLAS_COLS))) / float(ATLAS_ROWS), 0.0)


## Vật liệu mặt RIÊNG cho một nhân vật (đổi ô biểu cảm / chớp mắt không ảnh hưởng người khác).
static func face_material(skin_idx: int, female: bool, variant: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.roughness = 0.85
	var tex: Texture2D = CharacterBuilder._tex("char_ps2_face_%s%s%d.png" % [CharacterBuilder.SKIN_KEYS[skin_idx], "f" if female else "m", variant])
	if tex:
		m.albedo_texture = tex
		m.uv1_scale = Vector3(1.0 / float(ATLAS_COLS), 1.0 / float(ATLAS_ROWS), 1.0)
		m.uv1_offset = cell_offset("open")
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	else:
		push_warning("PS2Head: thiếu atlas mặt PS2, dùng da trơn (chạy generate_character_textures.py --ps2-only)")
		m.albedo_color = CharacterBuilder.SKIN_TONES[skin_idx]
	m.set_meta("ps2_face", tex != null)
	return m


static func hair_material(idx: int) -> StandardMaterial3D:
	var key: String = "ps2_hair_%d" % idx
	if CharacterBuilder._mat_cache.has(key):
		return CharacterBuilder._mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = CharacterBuilder.HAIR_COLORS[idx]
	m.roughness = 0.8
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var t: Texture2D = CharacterBuilder._tex("char_ps2_hair.png")
	if t:
		m.albedo_texture = t
	CharacterBuilder._mat_cache[key] = m
	return m


# ===========================================================================
# MESH ĐẦU
# ===========================================================================
static func head_mesh(k: Dictionary) -> ArrayMesh:
	var key: String = "head_%.2f_%.2f_%.2f" % [float(k.get("w", 1.0)), float(k.get("jaw", 1.0)), float(k.get("nose", 1.0))]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step: float = TAU / float(SEGMENTS)
	for i: int in range(RINGS.size() - 1):
		for j: int in range(SEGMENTS):
			var th1: float = -PI + float(j) * step
			var th2: float = th1 + step
			var side: float = signf(th1 + step * 0.5)
			var a: Vector3 = _ring_point(RINGS[i], th1, k)
			var b: Vector3 = _ring_point(RINGS[i], th2, k)
			var c: Vector3 = _ring_point(RINGS[i + 1], th1, k)
			var d: Vector3 = _ring_point(RINGS[i + 1], th2, k)
			var want: Vector3 = _outward((a + b + c + d) * 0.25)
			_quad(st, a, b, c, d, _uv(a, th1, side), _uv(b, th2, side), _uv(c, th1, side), _uv(d, th2, side), want)
	# đáy cằm: quạt về tâm
	var under := Vector3(0.0, 0.004, -0.02)
	for j: int in range(SEGMENTS):
		var th1: float = -PI + float(j) * step
		var th2: float = th1 + step
		var side: float = signf(th1 + step * 0.5)
		var a: Vector3 = _ring_point(RINGS[0], th1, k)
		var b: Vector3 = _ring_point(RINGS[0], th2, k)
		_tri(st, a, b, under, _uv(a, th1, side), _uv(b, th2, side), _uv(under, 0.0, 0.0), Vector3(0.0, -1.0, -0.2))
	# mũi
	var nk: float = float(k.get("nose", 1.0))
	var nb := Vector3(0.0, 0.133, _front_z(0.133) - 0.003)
	var nt := Vector3(0.0, 0.093, _front_z(0.093) - 0.024 * nk)
	var nl := Vector3(-0.016, 0.089, _front_z(0.089) + 0.006)
	var nr := Vector3(0.016, 0.089, _front_z(0.089) + 0.006)
	var nn := Vector3(0.0, 0.086, _front_z(0.086) - 0.009 * nk)
	_tri(st, nb, nl, nt, _uv(nb, 0.0, 0.0), _uv(nl, 0.0, 0.0), _uv(nt, 0.0, 0.0), Vector3(-0.6, 0.2, -1.0))
	_tri(st, nb, nt, nr, _uv(nb, 0.0, 0.0), _uv(nt, 0.0, 0.0), _uv(nr, 0.0, 0.0), Vector3(0.6, 0.2, -1.0))
	_tri(st, nl, nn, nt, _uv(nl, 0.0, 0.0), _uv(nn, 0.0, 0.0), _uv(nt, 0.0, 0.0), Vector3(-0.3, -1.0, -0.6))
	_tri(st, nt, nn, nr, _uv(nt, 0.0, 0.0), _uv(nn, 0.0, 0.0), _uv(nr, 0.0, 0.0), Vector3(0.3, -1.0, -0.6))
	# tai: tấm phẳng, hai mặt
	var w: float = float(k.get("w", 1.0))
	for sx: float in [-1.0, 1.0]:
		var xe: float = sx * (0.077 * w + 0.004)
		var et := Vector3(xe, 0.150, 0.010)
		var ef := Vector3(xe, 0.124, -0.004)
		var eb := Vector3(xe, 0.100, 0.008)
		var ek := Vector3(xe + sx * 0.011, 0.127, 0.026)
		var th: float = sx * PI * 0.5
		var ut: Vector2 = _uv(et, th, sx)
		var uf: Vector2 = _uv(ef, th, sx)
		var ub: Vector2 = _uv(eb, th, sx)
		var uk: Vector2 = _uv(ek, th, sx)
		_tri(st, et, ef, ek, ut, uf, uk, Vector3(sx, 0.0, 0.3))
		_tri(st, ef, eb, ek, uf, ub, uk, Vector3(sx, 0.0, 0.3))
		_tri(st, et, ef, ek, ut, uf, uk, Vector3(0.2 * sx, 0.0, 1.0))
		_tri(st, ef, eb, ek, uf, ub, uk, Vector3(0.2 * sx, 0.0, 1.0))
	st.index()
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	_mesh_cache[key] = mesh
	return mesh


# ===========================================================================
# TÓC
# ===========================================================================
static func hair_mesh(style: String, k: Dictionary) -> ArrayMesh:
	var key: String = "hair_%s_%.2f_%.2f" % [style, float(k.get("w", 1.0)), float(k.get("jaw", 1.0))]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var lines: Array = HAIRLINES.get(style, HAIRLINES["short"])
	var puff: float = HAIR_PUFF * (1.05 if style in ["bob", "long"] else 1.0)
	var lift: float = 0.006 + (0.012 if style == "undercut" else 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step: float = TAU / float(SEGMENTS)
	for i: int in range(RINGS.size() - 1):
		var y0: float = float(RINGS[i][0])
		for j: int in range(SEGMENTS):
			var th1: float = -PI + float(j) * step
			var th2: float = th1 + step
			if y0 < _hairline(style, lines, th1 + step * 0.5):
				continue
			var a: Vector3 = _puffed(_ring_point(RINGS[i], th1, k), puff, lift)
			var b: Vector3 = _puffed(_ring_point(RINGS[i], th2, k), puff, lift)
			var c: Vector3 = _puffed(_ring_point(RINGS[i + 1], th1, k), puff, lift)
			var d: Vector3 = _puffed(_ring_point(RINGS[i + 1], th2, k), puff, lift)
			_quad(st, a, b, c, d, _huv(th1, a.y), _huv(th2, b.y), _huv(th1, c.y), _huv(th2, d.y), _outward((a + b + c + d) * 0.25))
	match style:
		"spiky":
			for s: int in range(7):
				var th: float = -0.9 + float(s) * 0.3
				var base: Vector3 = _puffed(_ring_point(RINGS[7], th, k), puff, lift)
				var out: Vector3 = _outward(base)
				var tip: Vector3 = base + out * 0.04 + Vector3(0.0, 0.025, 0.0)
				var side := Vector3(cos(th), 0.0, sin(th)) * 0.014
				var p1: Vector3 = base + side
				var p2: Vector3 = base - side
				var p3: Vector3 = base - out * 0.012 + Vector3(0.0, 0.01, 0.0)
				var uv := Vector2(0.5, 0.5)
				_tri(st, p1, p2, tip, uv, uv, uv, out)
				_tri(st, p2, p3, tip, uv, uv, uv, -side.normalized() + out)
				_tri(st, p3, p1, tip, uv, uv, uv, side.normalized() + out)
		"bun":
			_add_blob(st, Vector3(0.0, 0.205, 0.085), 0.042)
		"ponytail":
			_add_tube(st, Vector3(0.0, 0.15, 0.112), Vector3(0.0, -0.07, 0.17), 0.03, 0.016, 6)
		"long":
			_quad(st, Vector3(-0.088, -0.20, 0.10), Vector3(0.088, -0.20, 0.10), Vector3(-0.092, 0.07, 0.112), Vector3(0.092, 0.07, 0.112),
				Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, 2.7), Vector2(1.0, 2.7), Vector3(0.0, 0.0, 1.0))
			for sx: float in [-1.0, 1.0]:
				_quad(st, Vector3(sx * 0.088, -0.02, -0.03), Vector3(sx * 0.090, -0.02, 0.07), Vector3(sx * 0.086, 0.15, -0.04), Vector3(sx * 0.090, 0.15, 0.08),
					Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, 1.7), Vector2(1.0, 1.7), Vector3(sx, 0.0, 0.0))
	var mesh: ArrayMesh = st.commit()
	_mesh_cache[key] = mesh
	return mesh


static func _hairline(style: String, lines: Array, th: float) -> float:
	var deg: float = absf(rad_to_deg(th))
	if deg < 50.0:
		if style == "side_part" and rad_to_deg(th) < -10.0:
			return float(lines[0]) - 0.008
		return float(lines[0])
	if deg < 110.0:
		return float(lines[1])
	return float(lines[2])


static func _puffed(p: Vector3, puff: float, lift: float) -> Vector3:
	return Vector3(p.x * puff, 0.12 + (p.y - 0.12) * (1.0 + (puff - 1.0) * 0.6) + lift, p.z * puff)


static func _huv(th: float, y: float) -> Vector2:
	return Vector2((th / TAU + 0.5) * 6.0, y * 10.0)


# ===========================================================================
# KÍNH (khung vuông kiểu thập niên 80, đặt trước mặt đầu PS2)
# ===========================================================================
static func _build_glasses(head: Node3D, k: Dictionary) -> void:
	var gm: StandardMaterial3D = CharacterBuilder._mat("ps2_glasses", Color("#16161A"), 0.4, 0.3)
	var w: float = float(k.get("w", 1.0))
	var y: float = 0.127
	var z: float = _front_z(y) - 0.008
	for sx: float in [-1.0, 1.0]:
		var cx: float = sx * 0.032 * w
		CharacterBuilder._box(head, Vector3(cx, y + 0.009, z), Vector3(0.03, 0.004, 0.004), gm)
		CharacterBuilder._box(head, Vector3(cx, y - 0.009, z), Vector3(0.03, 0.003, 0.004), gm)
		CharacterBuilder._box(head, Vector3(cx + sx * 0.016, y, z), Vector3(0.003, 0.021, 0.004), gm)
		CharacterBuilder._box(head, Vector3(cx - sx * 0.016, y, z), Vector3(0.003, 0.021, 0.004), gm)
		CharacterBuilder._box(head, Vector3(sx * 0.081 * w, y + 0.004, z + 0.05), Vector3(0.003, 0.003, 0.1), gm)
	CharacterBuilder._box(head, Vector3(0.0, y + 0.006, z), Vector3(0.008, 0.003, 0.004), gm)


# ===========================================================================
# HÌNH HỌC
# ===========================================================================
static func _ring_point(ring: Array, theta: float, k: Dictionary) -> Vector3:
	var s: float = sin(theta)
	var c: float = cos(theta)
	var ps: float = signf(s) * pow(absf(s), 2.0 / SUPER_N)
	var pc: float = pow(absf(c), 2.0 / SUPER_N)
	var y: float = float(ring[0])
	var w: float = float(ring[1]) * float(k.get("w", 1.0)) * (float(k.get("jaw", 1.0)) if y < 0.06 else 1.0)
	if c >= 0.0:
		return Vector3(w * ps, y, -float(ring[2]) * pc)
	return Vector3(w * ps, y, float(ring[3]) * pc)


## z mặt trước tại độ cao y (đường giữa mặt, x = 0).
static func _front_z(y: float) -> float:
	for i: int in range(RINGS.size() - 1):
		var r0: Array = RINGS[i]
		var r1: Array = RINGS[i + 1]
		if y <= float(r1[0]):
			var t: float = clampf((y - float(r0[0])) / maxf(float(r1[0]) - float(r0[0]), 0.0001), 0.0, 1.0)
			return -lerpf(float(r0[2]), float(r1[2]), t)
	return 0.0


## UV mặt: chiếu phẳng từ trước cho |θ| <= BACK_UV_DEG; sau đầu lấy cột viền da (trái/phải theo side của ô quad).
static func _uv(p: Vector3, theta: float, side: float) -> Vector2:
	var v: float = clampf(1.0 - p.y / HEAD_H, 0.01, 0.99)
	if absf(rad_to_deg(theta)) > BACK_UV_DEG:
		return Vector2(0.99 if side > 0.0 else 0.01, v)
	return Vector2(clampf(0.5 + p.x / FACE_U_SPAN, 0.01, 0.99), v)


static func _outward(p: Vector3) -> Vector3:
	var o := Vector3(p.x, (p.y - 0.12) * 0.8, p.z)
	return o.normalized() if o.length() > 0.0001 else Vector3.UP


## Tam giác với chiều quấn mặt trước của Godot (theo chiều kim đồng hồ: (c - a) x (b - a) hướng ra ngoài = want).
static func _tri(st: SurfaceTool, pa: Vector3, pb: Vector3, pc: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, want: Vector3) -> void:
	if (pc - pa).cross(pb - pa).length_squared() < 1e-14:
		return
	if (pc - pa).cross(pb - pa).dot(want) < 0.0:
		var tp: Vector3 = pb
		pb = pc
		pc = tp
		var tu: Vector2 = ub
		ub = uc
		uc = tu
	st.set_uv(ua)
	st.add_vertex(pa)
	st.set_uv(ub)
	st.add_vertex(pb)
	st.set_uv(uc)
	st.add_vertex(pc)


## Tứ giác a-b (dưới), c-d (trên); tam giác suy biến (đỉnh đầu, cực cầu) tự bỏ.
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, want: Vector3) -> void:
	_tri(st, a, b, c, ua, ub, uc, want)
	_tri(st, b, d, c, ub, ud, uc, want)


static func _add_blob(st: SurfaceTool, c: Vector3, r: float) -> void:
	var rings: int = 4
	var segs: int = 6
	for i: int in range(rings):
		var p0: float = PI * float(i) / float(rings) - PI * 0.5
		var p1: float = PI * float(i + 1) / float(rings) - PI * 0.5
		for j: int in range(segs):
			var t0: float = TAU * float(j) / float(segs)
			var t1: float = TAU * float(j + 1) / float(segs)
			var a: Vector3 = c + r * Vector3(cos(p0) * cos(t0), sin(p0), cos(p0) * sin(t0))
			var b: Vector3 = c + r * Vector3(cos(p0) * cos(t1), sin(p0), cos(p0) * sin(t1))
			var cc: Vector3 = c + r * Vector3(cos(p1) * cos(t0), sin(p1), cos(p1) * sin(t0))
			var d: Vector3 = c + r * Vector3(cos(p1) * cos(t1), sin(p1), cos(p1) * sin(t1))
			var uv := Vector2(t0 / TAU * 2.0, p0)
			_quad(st, a, b, cc, d, uv, uv, uv, uv, ((a + b + cc + d) * 0.25 - c).normalized())


static func _add_tube(st: SurfaceTool, p0: Vector3, p1: Vector3, r0: float, r1: float, segs: int) -> void:
	var axis: Vector3 = (p1 - p0).normalized()
	var ref: Vector3 = Vector3.RIGHT if absf(axis.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var u: Vector3 = axis.cross(ref).normalized()
	var v: Vector3 = axis.cross(u).normalized()
	for j: int in range(segs):
		var t0: float = TAU * float(j) / float(segs)
		var t1: float = TAU * float(j + 1) / float(segs)
		var o0: Vector3 = u * cos(t0) + v * sin(t0)
		var o1: Vector3 = u * cos(t1) + v * sin(t1)
		var a: Vector3 = p0 + o0 * r0
		var b: Vector3 = p0 + o1 * r0
		var c: Vector3 = p1 + o0 * r1
		var d: Vector3 = p1 + o1 * r1
		_quad(st, a, b, c, d, Vector2(t0, 0.0), Vector2(t1, 0.0), Vector2(t0, 2.0), Vector2(t1, 2.0), (o0 + o1).normalized())
		_tri(st, c, d, p1 + axis * 0.012, Vector2(t0, 2.0), Vector2(t1, 2.0), Vector2(t0, 2.1), axis)
```

Run: `godot --headless --import --path . > /tmp/imp.log 2>&1; grep -c PS2Head .godot/global_script_class_cache.cfg`
Expected: `2` (or more) – the class is registered.

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot --headless --path . --script tests/test_ps2_head.gd > /tmp/t2.log 2>&1; grep -E "SUCCESS|FAILED" /tmp/t2.log`
Expected: `✅ SUCCESS: PS2 HEAD MESH, UV, HAIR, CELLS AND ACCESSORIES OK`

- [ ] **Step 5: Regression and commit**

Run the regression command. Expected: all green. Then:

```bash
git add scripts/characters/PS2Head.gd tests/test_ps2_head.gd
git commit -m "feat(people): PS2Head - faceted head mesh, front-projected face atlas cells, low-poly hair shells, 80s glasses

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: CharacterBuilder vice path (PS2 people for every preset)

**Files:**
- Modify: `scripts/CharacterBuilder.gd` (statics near line 47; `build()` line 98-300; `_build_rigged()` line 386-522; `_rig_torso_extras()` line 532; `set_expression()` line 637; `Animator` and `RigAnimator` blink functions)
- Modify: `scripts/GameFX.gd` (`_apply_art_style_statics()`)
- Create: `tests/test_ps2_people.gd`

**Interfaces:**
- Consumes: `PS2Head.build/cell_offset/CELLS` (Task 2).
- Produces:
  - `CharacterBuilder.ps2: bool` (static; GameFX sets it to `art_style == "vice"`).
  - In ps2 mode `build(opts)` returns a rigged body (meta `rigged` = true, `ps2_head` = true) unless `opts.rigged == false`; the rig contains every key of the code body: `hips, torso, neck, head, head_top, shoulder_l/r, elbow_l/r, hand_l/r, thigh_l/r, knee_l/r, foot_l/r, chest, face_mesh, torso_mesh`. The limb/torso/neck keys are attach pivots (Node3D at the joint following the bone; as built in Task 3 their -Y points down the bone toward the next joint, -Z toward the character's front and +X toward its right, matching the code body's pivot convention); rotating them does not move bones.
  - `CharacterBuilder.set_expression(root, expr)` supports the PS2 cells (`talk`, `pain` too); `Animator`/`RigAnimator` get `face_cells: bool`, `face_cell_open: Vector3`, `face_cell_closed: Vector3`.
  - Constant `CharacterBuilder.PS2_HEAD_SCALE_RIG: float = 1.06` (world head height ≈ 0.235 × 1.06 × 0.935 ≈ 0.233 m at height 1.0).

- [ ] **Step 1: Write the failing test**

Create `tests/test_ps2_people.gd`:

```gdscript
# File: res://tests/test_ps2_people.gd
# Test headless người PS2 (spec vice-people-and-movement, Phần 1): cổ điển không đổi (dấu vân tay ghi từ main),
# ở chế độ ps2 mọi preset là thân rigged + đầu PS2, đủ pivot của thân tự dựng, vật liệu mặt một ô atlas, cao đầu thật,
# đổi ô biểu cảm, chớp mắt bằng ô "closed", đồ gắn vào pivot cẳng tay nằm ở cổ tay, tư thế tĩnh + bake người ngồi xe
# (Task 4), thời gian dựng.
# Chạy:  godot --headless --path . --script tests/test_ps2_people.gd
extends SceneTree

const PRESETS: Array[String] = ["student", "student_m", "student_f", "player", "rider", "lecturer", "guard", "vovinam", "master", "cook", "proctor", "casual", "cop"]
const PIVOTS: Array[String] = ["hips", "torso", "neck", "head", "head_top", "shoulder_l", "shoulder_r", "elbow_l", "elbow_r", "hand_l", "hand_r", "thigh_l", "thigh_r", "knee_l", "knee_r", "foot_l", "foot_r", "chest", "face_mesh", "torso_mesh"]
## Dấu vân tay "số node:số MeshInstance3D" của thân CỔ ĐIỂN, ghi trên main trước Phần 1 (Task 3 Step 2-3).
const CLASSIC_FP: Dictionary = {"student": "?", "lecturer": "?", "player": "?", "player_rigged": "?"}

var world: Node3D
var chars: Array[Node3D] = []
var frames: int = 0
var done: bool = false
var blink_seen: Dictionary = {}
var wrist_probe: Node3D
var static_c: Node3D
var phase_task4: bool = false


func _initialize() -> void:
	world = Node3D.new()
	root.add_child(world)
	if not _classic_unchanged():
		return
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	for i: int in range(PRESETS.size()):
		var c: Node3D = CharacterBuilder.build({"preset": PRESETS[i], "seed": i * 31 + 1})
		c.position = Vector3(float(i) * 1.2, 0.0, 0.0)
		world.add_child(c)
		chars.append(c)
		if not _check(bool(c.get_meta("rigged", false)), "%s: vice build must be rigged" % PRESETS[i]):
			return
		if not _check(bool(c.get_meta("ps2_head", false)), "%s: vice build must carry a PS2 head" % PRESETS[i]):
			return
		for k: String in PIVOTS:
			if not _check(CharacterBuilder.get_pivot(c, k) != null, "%s: missing pivot %s" % [PRESETS[i], k]):
				return
		var fm: StandardMaterial3D = CharacterBuilder.get_pivot(c, "face_mesh").material_override as StandardMaterial3D
		if not _check(fm != null and bool(fm.get_meta("ps2_face", false)) and fm.uv1_scale.is_equal_approx(Vector3(0.25, 0.5, 1.0)), "%s: face material must sample one atlas cell" % PRESETS[i]):
			return
		var n_mi: int = CharacterBuilder._mesh_instances(c).size()
		if not _check(n_mi >= 6 and n_mi <= 40, "%s: %d mesh instances (expected 6..40)" % [PRESETS[i], n_mi]):
			return
	print("--- TEST PS2 PEOPLE: %d presets in ps2 mode ---" % PRESETS.size())


func _process(_d: float) -> bool:
	if done:
		return true
	frames += 1
	if frames == 3:
		for i: int in range(chars.size()):
			var mi: MeshInstance3D = CharacterBuilder.get_pivot(chars[i], "face_mesh") as MeshInstance3D
			var ab: AABB = mi.global_transform * mi.get_aabb()
			var h: float = ab.size.y
			if i < 3:
				print("  %s head height %.3f m, head top y %.2f" % [PRESETS[i], h, CharacterBuilder.head_top(chars[i]).global_position.y])
			if not _check(h > 0.20 and h < 0.26, "%s: world head height %.3f (expected 0.20..0.26: realistic, not cartoon)" % [PRESETS[i], h]):
				return true
		var top: float = CharacterBuilder.head_top(chars[1]).global_position.y
		if not _check(top > 1.5 and top < 2.0, "student_m head top at %.2f m (expected 1.5..2.0)" % top):
			return true
		# đồ gắn dưới pivot cẳng tay phải, 0.22 m dọc cẳng tay -> ở cổ tay
		wrist_probe = Node3D.new()
		wrist_probe.position = Vector3(0.0, -0.22, 0.0)
		CharacterBuilder.get_pivot(chars[0], "elbow_r").add_child(wrist_probe)
	if frames == 6:
		var sk: Skeleton3D = chars[0].get_meta("skeleton") as Skeleton3D
		var wb: int = sk.find_bone("Wrist.R")
		var wrist: Vector3 = sk.global_transform * sk.get_bone_global_pose(wb).origin
		var gap: float = wrist_probe.global_position.distance_to(wrist)
		print("  forearm attach -> wrist gap %.3f m" % gap)
		if not _check(gap < 0.08, "an attachment 0.22 m down the elbow_r pivot must sit at the wrist (gap %.3f m)" % gap):
			return true
		for e: String in ["happy", "pain", "talk"]:
			CharacterBuilder.set_expression(chars[0], e)
			var fm: StandardMaterial3D = CharacterBuilder.get_pivot(chars[0], "face_mesh").material_override as StandardMaterial3D
			if not _check(fm.uv1_offset.is_equal_approx(PS2Head.cell_offset(e)), "set_expression(%s) must move the face to its cell" % e):
				return true
		CharacterBuilder.set_expression(chars[0], "open")
	if frames >= 10 and frames < 420:
		var closed: Vector3 = PS2Head.cell_offset("closed")
		for i: int in range(chars.size()):
			var fm2: StandardMaterial3D = CharacterBuilder.get_pivot(chars[i], "face_mesh").material_override as StandardMaterial3D
			if fm2.uv1_offset.is_equal_approx(closed):
				blink_seen[i] = true
	if frames == 420:
		print("  blinked: %d / %d" % [blink_seen.size(), chars.size()])
		if not _check(blink_seen.size() >= 10, "blinking must switch to the closed cell (only %d of %d blinked in 7 s)" % [blink_seen.size(), chars.size()]):
			return true
		_task4_start()
	if phase_task4 and frames == 424:
		_task4_check_sit()
	if phase_task4 and frames == 428:
		_task4_check_rest_and_bake()
	return false


# --- Task 4: tư thế tĩnh (pose) + bake thân rigged; thời gian dựng ------------------------
func _task4_start() -> void:
	phase_task4 = true
	static_c = CharacterBuilder.build({"preset": "student", "seed": 77, "animate": false})
	static_c.position = Vector3(0.0, 0.0, 4.0)
	world.add_child(static_c)
	CharacterBuilder.pose(static_c, "sit", 0.0)


func _task4_check_sit() -> void:
	var hy: float = CharacterBuilder.get_pivot(static_c, "hips").global_position.y
	print("  static sit: hips y %.2f" % hy)
	if not _check(hy < 0.62, "pose(sit) on a rigged body must lower the hips (y %.2f)" % hy):
		return
	CharacterBuilder.pose(static_c, "", 0.0)


func _task4_check_rest_and_bake() -> void:
	var hy: float = CharacterBuilder.get_pivot(static_c, "hips").global_position.y
	if not _check(hy > 0.7, "pose('') must reset to the rest pose (hips y %.2f)" % hy):
		return
	var holder := Node3D.new()
	world.add_child(holder)
	var mi: MeshInstance3D = CharacterBuilder.build_baked_rider(holder, Vector3(0.0, 0.3, 0.0), {"seed": 5})
	var mesh: ArrayMesh = mi.mesh as ArrayMesh
	var verts: int = 0
	var has_face: bool = false
	for s: int in range(mesh.get_surface_count()):
		verts += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var m: Material = mesh.surface_get_material(s)
		if m and bool(m.get_meta("ps2_face", false)):
			has_face = true
	var ab: AABB = mesh.get_aabb()
	print("  baked PS2 rider: %d surfaces, %d verts, height %.2f" % [mesh.get_surface_count(), verts, ab.size.y])
	if not _check(mesh.get_surface_count() >= 3 and verts >= 2000, "baked rider too small (%d surfaces, %d verts)" % [mesh.get_surface_count(), verts]):
		return
	if not _check(has_face, "baked rider must keep the PS2 face material"):
		return
	if not _check(ab.size.y < 1.45, "baked rider must be seated (height %.2f m)" % ab.size.y):
		return
	# build time after warm-up
	var t0: int = Time.get_ticks_usec()
	for i: int in range(20):
		var c: Node3D = CharacterBuilder.build({"preset": PRESETS[i % PRESETS.size()], "seed": 500 + i})
		c.free()
	var per: float = float(Time.get_ticks_usec() - t0) / 20000.0
	print("  build time %.1f ms per character" % per)
	if not _check(per < 15.0, "building one PS2 character takes %.1f ms (budget 15)" % per):
		return
	print("✅ SUCCESS: PS2 PEOPLE - RIGGED BODIES, PS2 HEADS, PIVOTS, CELLS, BLINK, STATIC POSE, BAKED RIDER, CLASSIC UNCHANGED")
	done = true
	quit(0)


# --- Cổ điển không đổi ------------------------------------------------------------------
func _fp(c: Node3D) -> String:
	var nodes: int = 0
	var meshes: int = 0
	var stack: Array[Node] = [c]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		nodes += 1
		if n is MeshInstance3D:
			meshes += 1
		for ch: Node in n.get_children():
			stack.append(ch)
	return "%d:%d" % [nodes, meshes]


func _classic_unchanged() -> bool:
	CharacterBuilder.ps2 = false
	var probes: Dictionary = {
		"student": {"preset": "student", "seed": 1}, "lecturer": {"preset": "lecturer", "seed": 2},
		"player": {"preset": "player", "seed": 3}, "player_rigged": {"preset": "player", "seed": 2805, "rigged": true},
	}
	var ok: bool = true
	for key: String in probes.keys():
		var c: Node3D = CharacterBuilder.build(probes[key])
		var fp: String = _fp(c)
		c.free()
		print("  classic fingerprint %s = %s" % [key, fp])
		if fp != String(CLASSIC_FP[key]):
			ok = false
	return _check(ok, "classic characters changed (copy the fingerprints printed above from an UNMODIFIED main into CLASSIC_FP)")


func _check(ok: bool, msg: String) -> bool:
	if not ok and not done:
		done = true
		print("❌ FAILED: ", msg)
		quit(2)
	return ok
```

- [ ] **Step 2: Run the test on the unmodified code to record the classic fingerprints**

Run: `godot --headless --path . --script tests/test_ps2_people.gd > /tmp/t3.log 2>&1; grep -E "fingerprint|SUCCESS|FAILED" /tmp/t3.log`
Expected: four `classic fingerprint <key> = <n>:<m>` lines, then `❌ FAILED: classic characters changed ...`.

- [ ] **Step 3: Paste the four printed values into `CLASSIC_FP`**

Replace each `"?"` in `CLASSIC_FP` with the value printed for that key (for example `"student": "61:47"` if that is what Step 2 printed). Re-run the Step 2 command.
Expected: the fingerprint lines match and the test now fails at `PS2Head`/ps2 checks, e.g. `❌ FAILED: student: vice build must carry a PS2 head` or a parse error about `ps2` not being a member of `CharacterBuilder`.

- [ ] **Step 4: Implement the vice path in `CharacterBuilder.gd`**

4a. Below `static var head_scale_default: float = 1.3` add:

```gdscript
## Phong cách Vice City (GameFX._apply_art_style_statics đặt = art_style == "vice"): mọi preset dựng trên thân Quaternius
## với đầu PS2 (PS2Head), tỉ lệ người thật; cổ điển (false) giữ nguyên nhân vật hiện tại.
static var ps2: bool = false
const PS2_HEAD_SCALE_RIG: float = 1.06
## Pivot gắn đồ của thân rigged: khóa thân tự dựng -> [xương, độ dời (m, hệ gốc nhân vật) dọc chi ở tư thế nghỉ].
const ATTACH_BONES: Dictionary = {
	"torso": ["Torso", Vector3.ZERO], "neck": ["Neck", Vector3.ZERO],
	"shoulder_l": ["UpperArm.L", Vector3.ZERO], "shoulder_r": ["UpperArm.R", Vector3.ZERO],
	"elbow_l": ["LowerArm.L", Vector3.ZERO], "elbow_r": ["LowerArm.R", Vector3.ZERO],
	"thigh_l": ["UpperLeg.L", Vector3.ZERO], "thigh_r": ["UpperLeg.R", Vector3.ZERO],
	"knee_l": ["LowerLeg.L", Vector3.ZERO], "knee_r": ["LowerLeg.R", Vector3.ZERO],
	"foot_l": ["LowerLeg.L", Vector3(0.0, -0.42, 0.0)], "foot_r": ["LowerLeg.R", Vector3(0.0, -0.42, 0.0)],
}
```

4b. In `build()`, change the first line of the body from `if bool(opts.get("rigged", rigged_default)):` to:

```gdscript
	if bool(opts.get("rigged", rigged_default or ps2)):
```

4c. In `build()` (code body path) replace the head block

```gdscript
	var head: Node3D = _build_head(neck, Vector3(0.0, 0.065, 0.0), skin_idx, female, width, hair_style, hair_idx, outfit, rng, rig)
	var face_mat: StandardMaterial3D = _face_mat(skin_idx, female)
	var head_mi: MeshInstance3D = rig["face_mesh"]
```

with

```gdscript
	var head: Node3D
	if ps2:
		head = PS2Head.build(neck, Vector3(0.0, 0.065, 0.0), {"skin": skin_idx, "female": female, "hair_style": hair_style, "hair_color": hair_idx, "width": width, "seed": rng.randi(), "outfit": outfit}, rig)
	else:
		head = _build_head(neck, Vector3(0.0, 0.065, 0.0), skin_idx, female, width, hair_style, hair_idx, outfit, rng, rig)
	var head_mi: MeshInstance3D = rig["face_mesh"]
	var face_mat: StandardMaterial3D = head_mi.material_override as StandardMaterial3D if ps2 else _face_mat(skin_idx, female)
```

and change `var stylized: bool = bool(opts.get("stylized", true))` to `var stylized: bool = bool(opts.get("stylized", not ps2))`. In the same function's Animator block replace the `if an.blink_enabled:` body with:

```gdscript
		if an.blink_enabled:
			if ps2:
				if face_mat and bool(face_mat.get_meta("ps2_face", false)):
					an.face_mat = face_mat
					an.face_cells = true
					an.face_cell_open = PS2Head.cell_offset("open")
					an.face_cell_closed = PS2Head.cell_offset("closed")
				else:
					an.blink_enabled = false
			else:
				var open_tex: Texture2D = face_mat.albedo_texture
				var closed_tex: Texture2D = _tex("char_face_%s%s_closed.png" % [SKIN_KEYS[skin_idx], "f" if female else "m"])
				if open_tex and closed_tex:
					var own: StandardMaterial3D = face_mat.duplicate()
					head_mi.material_override = own
					an.face_mat = own
					an.face_open = open_tex
					an.face_closed = closed_tex
				else:
					an.blink_enabled = false
```

Also set `root.set_meta("ps2_head", true)` right after `root.set_meta("skin_idx", skin_idx)` when `ps2` is true.

4d. In `_build_rigged()`:
- Replace `var hs: float = float(opts.get("head_scale", head_scale_default))` with:

```gdscript
	var hs: float = float(opts.get("head_scale", PS2_HEAD_SCALE_RIG if ps2 else head_scale_default))
	var wk: float = 1.0
	if ps2:
		wk = float(opts.get("body_width", rng.randf_range(0.92, 1.12)))
		model.scale = Vector3(wk, 1.0, wk)
```

  (place it right after `root.add_child(model)` so `model` exists; move the original `hs` line there).
- In the material loop, after `mi.set_surface_override_material(si, m)` loop finishes for a mesh instance, record the torso mesh: add at the end of the `for mi` body:

```gdscript
		if not is_legs and not is_feet and main_si >= 0 and not rig.has("torso_mesh"):
			rig["torso_mesh"] = mi
```

- Replace the head block (`var head_pivot: Node3D = _build_head(att, ...)` .. `head_pivot.scale = Vector3(hs, hs, hs)`) with:

```gdscript
	var head_pivot: Node3D
	if ps2:
		head_pivot = PS2Head.build(att, Vector3.ZERO, {"skin": skin_idx, "female": female, "hair_style": hair_style, "hair_color": hair_idx, "width": width, "seed": rng.randi(), "outfit": outfit}, rig)
	else:
		head_pivot = _build_head(att, Vector3(0.0, 0.0, 0.0), skin_idx, female, width, hair_style, hair_idx, outfit, rng, rig)
	head_pivot.rotation.y = PI   # đầu nhìn về -Z của pivot; xương Head nhìn về +Z của mô hình (đã quay PI)
	head_pivot.position = Vector3(0.0, -0.045 + (hs - 1.0) * 0.1, 0.0)
	head_pivot.scale = Vector3(hs / wk, hs, hs / wk)   # bù bề ngang thân (wk) để mặt không méo
```

- After `_rig_torso_extras(rig["chest"], rig["hips"], outfit, width)` add `_rig_attach_pivots(root, sk, rig)`, and after `root.set_meta("skeleton", sk)` add `if ps2: root.set_meta("ps2_head", true)`.
- In the RigAnimator block replace the `if an.blink_enabled:` body with the same two-branch block as 4c, using `var face_mat: StandardMaterial3D = (rig["face_mesh"] as MeshInstance3D).material_override as StandardMaterial3D` for the ps2 branch and keeping today's texture-swap code (`_face_mat(...)` + `char_face_*_closed.png`) for the classic branch.

4e. Add the attach-pivot builder after `_rig_torso_extras()`:

```gdscript
## Pivot gắn đồ cho thân rigged theo quy ước thân tự dựng: Node3D đặt tại khớp, trục trùng trục gốc nhân vật ở tư thế
## nghỉ (Quaternius: tay buông chéo ~20°, chân hơi dạng), rồi đi theo xương. Chỉ để gắn đồ (đồng hồ, tai nghe...):
## xoay pivot này KHÔNG xoay xương.
static func _rig_attach_pivots(root: Node3D, sk: Skeleton3D, rig: Dictionary) -> void:
	var to_root: Transform3D = _local_xform(sk, root)
	for key: String in ATTACH_BONES.keys():
		if rig.has(key):
			continue
		var spec: Array = ATTACH_BONES[key]
		var b: int = sk.find_bone(String(spec[0]))
		if b < 0:
			continue
		var att := BoneAttachment3D.new()
		att.name = "Att_" + key
		sk.add_child(att)
		att.bone_name = String(spec[0])
		var rest: Transform3D = to_root * sk.get_bone_global_rest(b)
		var pivot := Node3D.new()
		pivot.name = "Pivot_" + key
		pivot.transform = rest.affine_inverse() * Transform3D(Basis.IDENTITY, rest.origin + (spec[1] as Vector3))
		att.add_child(pivot)
		rig[key] = pivot
```

4f. In `_rig_torso_extras()` add the Vovinam belt (today only the code body draws it) before the backpack block:

```gdscript
	if outfit.get("vovinam_belt", false):
		var vb: Material = outfit["vbelt_mat"]
		_box(hips, Vector3(0.0, 0.12, 0.0), Vector3(0.34 * width, 0.06, 0.25 * width), vb)
		_box(hips, Vector3(-0.03, 0.02, front * (cz + 0.012)), Vector3(0.03, 0.2, 0.012), vb, Vector3(0.0, 0.0, 0.1))
		_box(hips, Vector3(0.03, 0.02, front * (cz + 0.012)), Vector3(0.03, 0.2, 0.012), vb, Vector3(0.0, 0.0, -0.1))
```

4g. Face cells in both animators. In `class Animator` and in `class RigAnimator` add the members

```gdscript
	var face_cells: bool = false         # đầu PS2: chớp mắt / biểu cảm bằng ô atlas (uv1_offset) thay vì đổi texture
	var face_cell_open: Vector3 = Vector3.ZERO
	var face_cell_closed: Vector3 = Vector3.ZERO
```

and replace each class's `_blink()` with:

```gdscript
	func _blink(dt: float) -> void:
		if not blink_enabled or face_mat == null:
			return
		if _blink_closed > 0.0:
			_blink_closed -= dt
			if _blink_closed <= 0.0:
				_show_face(false)
			return
		_blink_t -= dt
		if _blink_t <= 0.0:
			_blink_t = randf_range(2.0, 5.5)
			_blink_closed = 0.13
			_show_face(true)

	func _show_face(closed: bool) -> void:
		if face_cells:
			face_mat.uv1_offset = face_cell_closed if closed else face_cell_open
		else:
			face_mat.albedo_texture = face_closed if closed else face_open
```

4h. In `set_expression()` insert, right after the `if face == null: return` guard:

```gdscript
	var fmat: StandardMaterial3D = face.material_override as StandardMaterial3D
	if fmat and bool(fmat.get_meta("ps2_face", false)):
		var off: Vector3 = PS2Head.cell_offset(expr if expr in PS2Head.CELLS else "open")
		if an and bool(an.get("face_cells")):
			an.face_cell_open = off
			if an._blink_closed <= 0.0:
				fmat.uv1_offset = off
		else:
			fmat.uv1_offset = off
		return
```

4i. In `scripts/GameFX.gd` replace `_apply_art_style_statics()` with:

```gdscript
## Kiểu nhân vật theo phong cách: cổ điển = toon + viền, đầu 1.3; Vice City = người PS2 (CharacterBuilder.ps2: thân
## Quaternius + đầu PS2 tỉ lệ thật, không viền) theo spec 2026-10-22-vice-people-and-movement-design.md.
func _apply_art_style_statics() -> void:
	var classic: bool = art_style == "classic"
	CharacterBuilder.toon = classic
	CharacterBuilder.ps2 = not classic
	CharacterBuilder.head_scale_default = 1.3 if classic else 1.0
```

- [ ] **Step 5: Run the test**

Run: `godot --headless --path . --script tests/test_ps2_people.gd > /tmp/t3.log 2>&1; grep -E "fingerprint|head height|wrist|blinked|static sit|SUCCESS|FAILED" /tmp/t3.log`
Expected: classic fingerprints unchanged, head heights 0.20..0.26, wrist gap < 0.08, at least 10 of 13 blinked, then a failure at the Task 4 part: `❌ FAILED: pose(sit) on a rigged body must lower the hips` (Task 4 implements it). If any earlier check fails, fix this task before continuing.

- [ ] **Step 6: Regression and commit**

Run the regression command. Every stage bot test now runs with PS2 people (tests construct GameFX, whose saved style defaults to vice). Expected: all green; `test_character_builder` is unaffected (it does not create GameFX, so `ps2` stays false). Then:

```bash
git add scripts/CharacterBuilder.gd scripts/GameFX.gd tests/test_ps2_people.gd
git commit -m "feat(people): vice style builds every preset as a Quaternius body with a PS2 head (realistic scale), attach pivots, face-cell blink and expressions; classic unchanged

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Rigged static poses, rigged bake and PS2 scooter riders

**Files:**
- Modify: `scripts/CharacterBuilder.gd` (`pose()` line 574, `build_baked_rider()` line 587, `bake()` line 700; new `_rig_pose`, `_apply_bone_pose`, `_bake_rigged`, `_rig_xform`)
- Test: `tests/test_ps2_people.gd` (Task 4 part already written in Task 3)

**Interfaces:**
- Consumes: Task 3 rigged ps2 bodies (meta `skeleton`).
- Produces: `CharacterBuilder.pose(root, clip, t, params)` works on rigged bodies (sets bone poses once; `clip == ""` resets to rest); `CharacterBuilder.bake(root)` merges a posed rigged body (needs the body inside the tree for skinned parts); `CharacterBuilder.build_baked_rider(parent, pos, opts)` returns a PS2 rider mesh in ps2 mode and today's rider otherwise.

- [ ] **Step 1: Confirm the Task 4 part of the test fails**

Run: `godot --headless --path . --script tests/test_ps2_people.gd > /tmp/t4.log 2>&1; grep -E "static sit|SUCCESS|FAILED" /tmp/t4.log`
Expected: `❌ FAILED: pose(sit) on a rigged body must lower the hips (y 0.8x)`.

- [ ] **Step 2: Implement**

Replace the first two lines of `pose()` (`if root.get_meta("rigged", false): return`) with:

```gdscript
	if root.get_meta("rigged", false):
		_rig_pose(root, clip, t, params)
		return
```

Add after `pose()`:

```gdscript
## Tư thế tĩnh cho thân rigged (không cần Animator): xương đặt theo bảng clip của Animator, đè tư thế nghỉ; clip "" = nghỉ.
static func _rig_pose(root: Node3D, clip: String, t: float, params: Dictionary) -> void:
	var sk: Skeleton3D = root.get_meta("skeleton", null) as Skeleton3D
	if sk == null:
		return
	sk.reset_bone_poses()
	if clip == "":
		return
	var an := Animator.new()
	an.rig = {}
	for k: String in params.keys():
		an.params[k] = params[k]
	var cpose: Dictionary = an._clip_pose(clip, t)
	an.free()
	_apply_bone_pose(sk, cpose, 1.0)


## Áp tư thế {khớp: Euler hệ nhân vật} lên xương Quaternius, trộn với tư thế hiện tại theo w (1 = đè hẳn):
## local = (Pg⁻¹·R·Pg)·rest_local; "hips_y" dời xương Body (đơn vị mô hình). Nơi DUY NHẤT chứa phép này:
## pose() tĩnh và RigAnimator._apply_bones() đều gọi hàm này.
static func _apply_bone_pose(sk: Skeleton3D, cpose: Dictionary, w: float) -> void:
	for k: String in cpose.keys():
		if not BONE_OF.has(k):
			continue
		var b: int = sk.find_bone(String(BONE_OF[k]))
		if b < 0:
			continue
		var e: Vector3 = cpose[k]
		if MODEL_YAW != 0.0:
			e = Vector3(-e.x, e.y, -e.z)
		var r := Basis.from_euler(e)
		var pb: int = sk.get_bone_parent(b)
		var pg: Basis = sk.get_bone_global_rest(pb).basis if pb >= 0 else Basis.IDENTITY
		var local: Basis = (pg.inverse() * r * pg) * sk.get_bone_rest(b).basis
		var q_cur: Quaternion = sk.get_bone_pose_rotation(b)
		sk.set_bone_pose_rotation(b, q_cur.slerp(local.get_rotation_quaternion(), w))
	if cpose.has("hips_y"):
		var body: int = sk.find_bone("Body")
		if body >= 0:
			var rest_pos: Vector3 = sk.get_bone_rest(body).origin
			var p: Vector3 = sk.get_bone_pose_position(body)
			sk.set_bone_pose_position(body, p.lerp(rest_pos + Vector3(0.0, float(cpose["hips_y"]), 0.0), w))
```

Then replace the whole body of `RigAnimator._apply_bones(cpose, w)` with one line, so the bone math lives in one place (keep the RigAnimator caches `_bone`, `_rest_local`, `_parent_rest`: other RigAnimator code and Task 6 use them):

```gdscript
	func _apply_bones(cpose: Dictionary, w: float) -> void:
		CharacterBuilder._apply_bone_pose(skeleton, cpose, w)
```

Replace the rigged guard at the top of `bake()` (the `push_warning(...)` + `return ArrayMesh.new()` block) with `return _bake_rigged(root)` and add:

```gdscript
## Gộp thân rigged ở tư thế hiện tại: phần skinned qua bake_mesh_from_current_skeleton_pose() (cần nằm trong cây),
## phần gắn xương (đầu, đồ gắn) theo tư thế xương. Bỏ mesh ẩn (đầu gốc của mô hình).
static func _bake_rigged(root: Node3D) -> ArrayMesh:
	var sk: Skeleton3D = root.get_meta("skeleton", null) as Skeleton3D
	var out := ArrayMesh.new()
	if sk == null:
		return out
	if sk.is_inside_tree():
		sk.force_update_all_bone_transforms()
	var by_mat: Dictionary = {}
	for mi: MeshInstance3D in _mesh_instances(root):
		if mi.mesh == null or not mi.visible:
			continue
		var src: Mesh = mi.mesh
		if mi.skin != null:
			if not mi.is_inside_tree():
				push_warning("CharacterBuilder.bake: thân rigged phải nằm trong cây để bake phần skinned")
				continue
			src = mi.bake_mesh_from_current_skeleton_pose()
			if src == null:
				continue
		var xf: Transform3D = _rig_xform(mi, root, sk)
		for si: int in range(src.get_surface_count()):
			var mat: Material = mi.material_override if mi.material_override else mi.get_active_material(si)
			if not by_mat.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				by_mat[mat] = st
			(by_mat[mat] as SurfaceTool).append_from(src, si, xf)
	for mat: Material in by_mat.keys():
		var st: SurfaceTool = by_mat[mat]
		st.index()
		st.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, mat)
	return out


## Transform của n trong hệ root cho thân rigged (trong hay ngoài cây): BoneAttachment3D thay bằng tư thế xương hiện tại.
static func _rig_xform(n: Node3D, root: Node3D, sk: Skeleton3D) -> Transform3D:
	var xf: Transform3D = n.transform
	if n is BoneAttachment3D:
		xf = sk.get_bone_global_pose(sk.find_bone((n as BoneAttachment3D).bone_name))
	var p: Node = n.get_parent()
	while p and p != root and p is Node3D:
		if p is BoneAttachment3D:
			xf = sk.get_bone_global_pose(sk.find_bone((p as BoneAttachment3D).bone_name)) * xf
		else:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf
```

Replace `build_baked_rider()` with:

```gdscript
## Người ngồi xe máy đã bake thành 1 MeshInstance3D – cho xe NPC / menu / bãi xe. Gốc đặt tại yên xe:
## pos = (0, cao_yên − 0.62, z_yên). Hướng -Z như xe. Chế độ ps2: thân Quaternius + đầu PS2 (tạm vào cây để bake).
static func build_baked_rider(parent: Node3D, pos: Vector3, opts: Dictionary = {}) -> MeshInstance3D:
	var o: Dictionary = opts.duplicate()
	if not o.has("preset"):
		o["preset"] = "rider"
	o["animate"] = false
	o["rigged"] = ps2
	var rig: Node3D = build(o)
	var params: Dictionary = {"ride_shoulder": float(o.get("ride_shoulder", 1.15)), "ride_elbow": float(o.get("ride_elbow", 0.3)), "ride_lean": float(o.get("ride_lean", 0.42)), "lean": float(o.get("lean", 0.0))}
	var host: Node = null
	if rig.get_meta("rigged", false):
		host = parent if parent.is_inside_tree() else (Engine.get_main_loop() as SceneTree).root
		host.add_child(rig)   # phần skinned chỉ tìm được skeleton khi nằm trong cây
	pose(rig, "ride", 0.0, params)
	var mesh: ArrayMesh = bake(rig)
	if host:
		host.remove_child(rig)
	var mi := MeshInstance3D.new()
	mi.name = String(o.get("name", "Rider"))
	mi.mesh = mesh
	mi.position = pos
	mi.scale = rig.scale
	parent.add_child(mi)
	rig.free()
	return mi
```

- [ ] **Step 3: Run the test to verify it passes**

Run: `godot --headless --path . --script tests/test_ps2_people.gd > /tmp/t4.log 2>&1; grep -E "static sit|baked|build time|SUCCESS|FAILED" /tmp/t4.log`
Expected: `static sit: hips y 0.4x`, `baked PS2 rider: N surfaces, M verts, height 1.2x`, `build time X ms`, then `✅ SUCCESS: PS2 PEOPLE - ...`. If the baked height is ≥ 1.45 the skeleton pose was not applied before baking: call `sk.force_update_all_bone_transforms()` after `pose()` inside `build_baked_rider()` and re-run.

- [ ] **Step 4: Regression and commit**

Run the regression command. The Extra exam students (`animate: false` + `pose(student, "type", ...)` + attachments on `head` and `elbow_r`) and the traffic/menu/Stage 2 riders now go through these paths: `test_stage_extra_eos`, `test_stage2_stairs`, `test_main_menu`, `test_stage1_race` and smoke must stay green. Then:

```bash
git add scripts/CharacterBuilder.gd
git commit -m "feat(people): static poses and baking for rigged bodies; PS2 scooter riders and seated exam students in the vice style

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Look pass and stage performance (PS2 people)

**Files:**
- Create: `tests/preview_people.gd`
- Modify (only if the review below finds a problem): `scripts/characters/PS2Head.gd` (RINGS, hairlines), `scripts/CharacterBuilder.gd` (`PS2_HEAD_SCALE_RIG`, head pivot y offset, `_rig_torso_extras` positions), `generate_character_textures.py` (face painting)
- Create (renders): `docs/preview/vice_people_lineup.png`, `vice_people_faces_a.png`, `vice_people_faces_b.png`, `vice_people_clips.png`, `vice_people_vs_classic.png`, refreshed `docs/preview/vice_stage_*.png`

**Interfaces:**
- Consumes: Tasks 1-4.
- Produces: owner-facing previews; constants possibly retuned (keep names).

- [ ] **Step 1: Create the preview script**

Create `tests/preview_people.gd`:

```gdscript
# File: res://tests/preview_people.gd
# Ảnh người PS2 (phong cách Vice City) – cần cửa sổ render:
#   godot --path . --script tests/preview_people.gd          (PREVIEW_DIR=<thư mục tuyệt đối> thay user://preview)
# Ảnh: vice_people_lineup, vice_people_faces_a/b (8 biểu cảm), vice_people_clips, vice_people_vs_classic.
extends SceneTree

const PRESETS: Array[String] = ["student_m", "student_f", "player", "lecturer", "proctor", "guard", "cop", "cook", "vovinam", "master", "casual", "rider", "student"]
const CLIPS: Array = [["walk", 1.3], ["run", 3.2], ["sit", 0.0], ["type", 0.0], ["phone", 0.0], ["cheer", 0.0], ["wave", 0.0], ["carry", 0.0], ["facepalm", 0.0]]
const SPACING: float = 0.9

var cam: Camera3D
var chars: Array[Node3D] = []
var frames: int = 0
var out_dir: String
var world: Node3D
var classic: Node3D


func _initialize() -> void:
	var dir_env: String = OS.get_environment("PREVIEW_DIR")
	out_dir = dir_env if dir_env != "" else ProjectSettings.globalize_path("user://preview")
	DirAccess.make_dir_recursive_absolute(out_dir)
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	world = Node3D.new()
	world.name = "PeopleStudio"
	root.add_child(world)
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, 35.0, 0.0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60.0, 60.0)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.82, 0.78, 0.72)
	floor_mi.material_override = fm
	world.add_child(floor_mi)
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	for i: int in range(PRESETS.size()):
		var c: Node3D = CharacterBuilder.build({"preset": PRESETS[i], "seed": 100 + i * 7, "name": "P_" + PRESETS[i]})
		c.position = Vector3((float(i) - float(PRESETS.size() - 1) * 0.5) * SPACING, 0.0, 0.0)
		c.rotation.y = PI
		world.add_child(c)
		chars.append(c)
		var label := Label3D.new()
		label.text = PRESETS[i]
		label.font_size = 26
		label.pixel_size = 0.004
		label.position = Vector3(0.0, 2.05, 0.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(0.1, 0.1, 0.1)
		label.outline_modulate = Color(1, 1, 1, 0.8)
		c.add_child(label)
	CharacterBuilder.ps2 = false
	CharacterBuilder.toon = true
	classic = CharacterBuilder.build({"preset": "student_m", "seed": 100, "name": "Classic_student_m"})
	classic.position = Vector3(-0.6, 0.0, 3.0)
	classic.rotation.y = PI
	classic.visible = false
	world.add_child(classic)
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	var gfx = load("res://scripts/GameFX.gd")   # untyped on purpose: static calls through a typed Script var fail
	gfx.upgrade_scene_visuals(world, "morning")
	cam = Camera3D.new()
	world.add_child(cam)
	cam.current = true
	_shot(Vector3(0.0, 1.45, 7.6), Vector3(0.0, 0.95, 0.0), 50.0)
	print("PREVIEW OUT DIR: ", out_dir)


func _shot(pos: Vector3, look: Vector3, fov: float) -> void:
	cam.fov = fov
	cam.look_at_from_position(pos, look, Vector3.UP)


func _save(name: String) -> void:
	var img: Image = root.get_texture().get_image()
	var err: int = img.save_png(out_dir.path_join(name + ".png"))
	print("  saved %s.png err=%d fps=%.0f" % [name, err, Engine.get_frames_per_second()])


func _faces(exprs: Array) -> void:
	for i: int in range(4):
		CharacterBuilder.set_expression(chars[i], String(exprs[i]))
		CharacterBuilder.look_at_point(chars[i], cam.global_position)
	var x0: float = chars[0].position.x
	var x3: float = chars[3].position.x
	_shot(Vector3((x0 + x3) * 0.5, 1.62, 2.2), Vector3((x0 + x3) * 0.5, 1.52, 0.0), 36.0)


func _process(_d: float) -> bool:
	frames += 1
	match frames:
		60:
			_save("vice_people_lineup")
			_faces(["open", "happy", "angry", "pain"])
		75:
			_save("vice_people_faces_a")
			_faces(["surprised", "done", "talk", "open"])
		90:
			_save("vice_people_faces_b")
			for i: int in range(chars.size()):
				CharacterBuilder.set_expression(chars[i], "open")
				CharacterBuilder.look_at_point(chars[i], null)
				var cl: Array = CLIPS[i % CLIPS.size()]
				CharacterBuilder.set_speed(chars[i], float(cl[1]))
				if float(cl[1]) == 0.0:
					CharacterBuilder.play(chars[i], String(cl[0]), 30.0)
			_shot(Vector3(0.0, 1.5, 7.6), Vector3(0.0, 0.85, 0.0), 50.0)
		125:
			_save("vice_people_clips")
			for c: Node3D in chars:
				c.visible = false
			chars[0].visible = true
			chars[0].position = Vector3(0.6, 0.0, 3.0)
			CharacterBuilder.stop_clip(chars[0])
			CharacterBuilder.set_speed(chars[0], 0.0)
			classic.visible = true
			_shot(Vector3(0.0, 1.3, 6.2), Vector3(0.0, 0.9, 3.0), 42.0)
		150:
			_save("vice_people_vs_classic")
			print("PREVIEW PEOPLE DONE")
			quit(0)
	return false
```

- [ ] **Step 2: Render and review**

Run: `PREVIEW_DIR="$(pwd)/docs/preview" godot --path . --script tests/preview_people.gd > /tmp/pp.log 2>&1; grep -E "saved|DONE|ERROR" /tmp/pp.log`
Expected: five `saved ... err=0` lines and `PREVIEW PEOPLE DONE`. Open every image with the Read tool and check:
1. Proportions read as adults (head about 1/7.5 of the body, no oversized cartoon heads), no gap or overlap at the neck, the face looks forward (not into the shoulder).
2. Every preset is recognisable against `docs/preview/rig_01_lineup.png` / `char_01_lineup.png`: FPT orange polo + logo, lanyard, lecturer/proctor shirt + tie, guard/cop cap, chef hat + apron, blue Vovinam uniform with belt (yellow / red for master), rider helmet.
3. Faces: the 8 expressions are readable at that distance; eyes sit in the face (not on the brow or cheeks); hair covers the crown and never pokes through the forehead; no seam stripes across the face.
4. Seated (`sit`, `type`) bodies have hips at seat height and hands near the lap/keyboard.

If a check fails, fix the cause (head pivot y in `_build_rigged`, `PS2_HEAD_SCALE_RIG`, `RINGS`, `HAIRLINES`, the `_rig_torso_extras` positions or the face painting), re-render, re-check.

- [ ] **Step 3: Stage previews and performance**

Run: `VICE_STYLE=vice PREVIEW_NOVSYNC=1 PREVIEW_DIR="$(pwd)/docs/preview/_vice_tmp" PREVIEW_ONLY=menu,s1,s2,s3,s4,s5,s6,ex godot --path . --script tests/preview_stages.gd > /tmp/ps.log 2>&1; grep saved /tmp/ps.log`
Expected: every shot saved with `fps=` ≥ 45 (menu ≥ 60). Open s3, s5, ex, s6 images: crowds are PS2 people, seated students fit their chairs and desks, the Extra exam earbuds and watches sit on the ear and wrist. Copy each `<shot>.png` to `docs/preview/vice_stage_<shot>.png` (menu_01 -> `vice_menu.png`) and delete `_vice_tmp`.

- [ ] **Step 4: Regression and commit**

Run the regression command (all green), then:

```bash
git add tests/preview_people.gd docs/preview/vice_people_*.png docs/preview/vice_stage_*.png docs/preview/vice_menu.png scripts/ generate_character_textures.py assets/textures/char_ps2_*
git commit -m "docs(people): PS2 people previews (lineup, 8 expressions, clips, vs classic) and stage renders; look tuning

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: RigAnimator locomotion layer and new clips

**Files:**
- Modify: `scripts/CharacterBuilder.gd` (constants near `PACK_CLIP`; `Animator.ONE_SHOT`, `Animator._process`, `Animator._clip_pose`; `RigAnimator` members, `play`, `_process`, `_look`, new `_overlay`, `_add_rot`, `_fidget_update`)
- Create: `tests/test_locomotion_anim.gd`

**Interfaces:**
- Produces (used by Tasks 7 and 10):
  - Clips playable with `CharacterBuilder.play(root, name, duration)`: `jump_takeoff` (0.12 s), `jump_air`, `fall_flail`, `land_soft` (0.18 s), `skid` (0.3 s), `stumble` (0.8 s), `knockdown` (holds the fallen pose until another clip), `getup` (≈0.9 s), `roll` (pack Roll).
  - Params: `set_param(root, "sprint", 0..1)` (stride rate +35 %, forward lean 12°, arm swing ×1.6), `set_param(root, "lean", radians)` (hip roll, positive = lean left).
  - `RigAnimator.fidget_count: int` (idle fidgets started; for tests).

- [ ] **Step 1: Write the failing test**

Create `tests/test_locomotion_anim.gd`:

```gdscript
# File: res://tests/test_locomotion_anim.gd
# Test headless lớp chuyển động của RigAnimator: nước rút tăng biên độ vung tay, nghiêng người không cộng dồn,
# "getup" phát ngược clip Death rồi về clip nền, đủ clip mới chạy trên thân rigged và thân tự dựng, đứng yên lâu có
# động tác vặt (fidget).
# Chạy:  godot --headless --path . --script tests/test_locomotion_anim.gd
extends SceneTree

const NEW_CLIPS: Array[String] = ["jump_takeoff", "jump_air", "fall_flail", "land_soft", "skid", "stumble", "knockdown", "getup", "roll"]
const CLIPS_AT: int = 640   # khung bắt đầu chạy lần lượt các clip mới (sau phần getup)

var getup_end: int = 0
var world: Node3D
var rig: Node3D
var code: Node3D
var sk: Skeleton3D
var frames: int = 0
var done: bool = false
var amp_jog: float = 0.0
var amp_sprint: float = 0.0
var arm_min: float = 99.0
var arm_max: float = -99.0
var lean_x30: float = 0.0
var clip_i: int = 0


func _initialize() -> void:
	Engine.max_fps = 60   # bộ hoạt ảnh chạy theo thời gian thật; headless vẽ ~145 khung/s nên đếm khung phải khoá 60
	world = Node3D.new()
	root.add_child(world)
	rig = CharacterBuilder.build({"preset": "player", "seed": 2805, "rigged": true})
	world.add_child(rig)
	code = CharacterBuilder.build({"preset": "student", "seed": 4, "rigged": false})
	code.position = Vector3(3.0, 0.0, 0.0)
	world.add_child(code)
	sk = rig.get_meta("skeleton") as Skeleton3D
	CharacterBuilder.set_speed(rig, 4.2)
	print("--- TEST LOCOMOTION ANIM ---")


func _arm_angle() -> float:
	var b: int = sk.find_bone("UpperArm.L")
	return (sk.get_bone_rest(b).basis.get_rotation_quaternion().inverse() * sk.get_bone_pose_rotation(b)).get_angle()


func _head_x() -> float:
	var hb: int = sk.find_bone("Head")
	var hips: int = sk.find_bone("Hips")
	var d: Vector3 = sk.get_bone_global_pose(hb).origin - sk.get_bone_global_pose(hips).origin
	return d.x


func _process(_d: float) -> bool:
	if done:
		return true
	frames += 1
	# 1) jog 120 frames: biên độ vung tay; 2) sprint 120 frames: phải lớn hơn >= 1.3 lần
	if frames > 30 and frames <= 150:
		var a: float = _arm_angle()
		arm_min = minf(arm_min, a)
		arm_max = maxf(arm_max, a)
	if frames == 150:
		amp_jog = arm_max - arm_min
		arm_min = 99.0
		arm_max = -99.0
		CharacterBuilder.set_param(rig, "run", 0.45)
		CharacterBuilder.set_param(rig, "sprint", 1.0)
		CharacterBuilder.set_speed(rig, 7.5)
	if frames > 180 and frames <= 300:
		var a2: float = _arm_angle()
		arm_min = minf(arm_min, a2)
		arm_max = maxf(arm_max, a2)
	if frames == 300:
		amp_sprint = arm_max - arm_min
		print("  arm swing amplitude: jog %.3f rad, sprint %.3f rad" % [amp_jog, amp_sprint])
		if not _check(amp_sprint >= amp_jog * 1.3, "sprint must swing the arms at least 1.3x wider (jog %.3f, sprint %.3f)" % [amp_jog, amp_sprint]):
			return true
		CharacterBuilder.set_param(rig, "sprint", 0.0)
		CharacterBuilder.set_param(rig, "run", 0.0)
		CharacterBuilder.set_speed(rig, 0.0)   # đo nghiêng khi đứng (Idle): không lẫn với lắc ngang của chu kỳ chạy
		CharacterBuilder.set_param(rig, "lean", 0.2)
	if frames == 330:
		lean_x30 = _head_x()
	if frames == 360:
		var x60: float = _head_x()
		CharacterBuilder.set_param(rig, "lean", 0.0)
		print("  lean 0.2: head x offset %.3f -> %.3f" % [lean_x30, x60])
		if not _check(absf(x60 - lean_x30) < 0.05, "lean must not accumulate (head x %.3f then %.3f)" % [lean_x30, x60]):
			return true
	if frames == 390:
		var x0: float = _head_x()
		if not _check(absf(lean_x30 - x0) > 0.04, "lean 0.2 rad must move the head sideways (%.3f vs %.3f)" % [lean_x30, x0]):
			return true
		CharacterBuilder.set_speed(rig, 0.0)
		CharacterBuilder.play(rig, "knockdown")
	if frames == 470:
		CharacterBuilder.play(rig, "getup")
	if frames == 472:
		var ap: AnimationPlayer = (CharacterBuilder.get_animator(rig) as Node).get("player")
		print("  getup: anim %s speed %.2f" % [ap.current_animation, ap.get_playing_speed()])
		if not _check(ap.current_animation == "Death" and ap.get_playing_speed() < 0.0, "getup must play Death backwards"):
			return true
		getup_end = frames + int(ceil(ap.get_animation("Death").length / CharacterBuilder.GETUP_SPEED * 60.0)) + 8
	if getup_end > 0 and frames == getup_end:
		var an: Node = CharacterBuilder.get_animator(rig)
		if not _check(String(an.get("clip")) == "", "after getup the animator returns to its base clip (clip = '%s')" % an.get("clip")):
			return true
	# mọi clip mới chạy 20 frame trên cả hai thân, không lỗi
	if frames >= CLIPS_AT and frames < CLIPS_AT + NEW_CLIPS.size() * 20 and (frames - CLIPS_AT) % 20 == 0:
		var c: String = NEW_CLIPS[(frames - CLIPS_AT) / 20]
		CharacterBuilder.play(rig, c)
		CharacterBuilder.play(code, c)
	if frames == CLIPS_AT + NEW_CLIPS.size() * 20:
		CharacterBuilder.stop_clip(rig)
		CharacterBuilder.stop_clip(code)
		CharacterBuilder.set_speed(rig, 0.0)
	# đứng yên 13 s: ít nhất một fidget
	if frames == CLIPS_AT + NEW_CLIPS.size() * 20 + 780:
		var n: int = int((CharacterBuilder.get_animator(rig) as Node).get("fidget_count"))
		print("  idle fidgets in 13 s: %d" % n)
		if not _check(n >= 1, "standing still for 13 s must trigger at least one fidget"):
			return true
		print("✅ SUCCESS: LOCOMOTION LAYER - SPRINT SWING, LEAN, GETUP REVERSED, NEW CLIPS, IDLE FIDGETS")
		done = true
		quit(0)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok and not done:
		done = true
		print("❌ FAILED: ", msg)
		quit(2)
	return ok
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless --path . --script tests/test_locomotion_anim.gd > /tmp/t6.log 2>&1; grep -E "amplitude|SUCCESS|FAILED" /tmp/t6.log`
Expected: `❌ FAILED: sprint must swing the arms at least 1.3x wider ...`

- [ ] **Step 3: Implement**

3a. Next to `PACK_CLIP` add the new pack clips and constants:

```gdscript
const PACK_CLIP: Dictionary = {"wave": "Wave", "punch": "Punch_Right", "kick": "Kick_Right", "flinch": "HitRecieve", "roll": "Roll",
	"interact": "Interact", "lie": "Death", "chop": "Sword_Slash", "stumble": "HitRecieve", "knockdown": "Death"}
## Clip gói giữ khung cuối tới khi có clip khác (không tự hết giờ).
const HOLD_CLIPS: Array[String] = ["lie", "knockdown"]
## Tốc độ phát ngược Death cho "getup" (Death ~1.3 s -> đứng dậy ~0.9 s).
const GETUP_SPEED: float = 1.4
## Tốc độ hoà clip tự dựng (1/s); mặc định 5.
const FAST_BLEND: Dictionary = {"jump_takeoff": 14.0, "jump_air": 10.0, "fall_flail": 8.0, "land_soft": 14.0, "skid": 10.0, "stumble": 10.0}
```

3b. In `class Animator`: extend `ONE_SHOT` to

```gdscript
	const ONE_SHOT: Dictionary = {"flinch": 0.9, "facepalm": 1.6, "bow": 1.4, "cheer_once": 1.6, "nod": 0.8,
		"jump_takeoff": 0.12, "land_soft": 0.18, "skid": 0.3, "stumble": 0.8, "getup": 0.9}
```

replace `clip_weight = minf(1.0, clip_weight + dt * 5.0)` in `Animator._process` with `clip_weight = minf(1.0, clip_weight + dt * float(FAST_BLEND.get(clip, 5.0)))`, change the `"jump":` pattern of `_clip_pose` to `"jump", "jump_air":` and the `"lie":` pattern to `"lie", "knockdown":`, and add these branches before `return p` of `_clip_pose`:

```gdscript
			"jump_takeoff":
				p["thigh_l"] = Vector3(0.55, 0.0, 0.08)
				p["thigh_r"] = Vector3(0.55, 0.0, -0.08)
				p["knee_l"] = Vector3(-1.05, 0.0, 0.0)
				p["knee_r"] = Vector3(-1.05, 0.0, 0.0)
				p["foot_l"] = Vector3(0.45, 0.0, 0.0)
				p["foot_r"] = Vector3(0.45, 0.0, 0.0)
				p["hips_y"] = -0.14
				p["torso"] = Vector3(-0.32, 0.0, 0.0)
				p["shoulder_l"] = Vector3(-0.65, 0.0, 0.18)
				p["shoulder_r"] = Vector3(-0.65, 0.0, -0.18)
				p["elbow_l"] = Vector3(0.35, 0.0, 0.0)
				p["elbow_r"] = Vector3(0.35, 0.0, 0.0)
			"fall_flail":
				var f: float = sin(ct * 11.0)
				var g: float = sin(ct * 9.0 + 1.3)
				p["shoulder_l"] = Vector3(2.3 + 0.45 * f, 0.0, 0.55)
				p["shoulder_r"] = Vector3(2.3 - 0.45 * f, 0.0, -0.55)
				p["elbow_l"] = Vector3(0.5 + 0.3 * g, 0.0, 0.0)
				p["elbow_r"] = Vector3(0.5 - 0.3 * g, 0.0, 0.0)
				p["thigh_l"] = Vector3(0.55 + 0.45 * g, 0.0, 0.12)
				p["thigh_r"] = Vector3(0.55 - 0.45 * g, 0.0, -0.12)
				p["knee_l"] = Vector3(-0.9 - 0.3 * f, 0.0, 0.0)
				p["knee_r"] = Vector3(-0.9 + 0.3 * f, 0.0, 0.0)
				p["torso"] = Vector3(0.12, 0.0, 0.0)
				p["head"] = Vector3(0.25, 0.0, 0.0)
			"land_soft":
				var k: float = sin(clampf(ct / 0.18, 0.0, 1.0) * PI)
				p["thigh_l"] = Vector3(0.75 * k, 0.0, 0.1)
				p["thigh_r"] = Vector3(0.75 * k, 0.0, -0.1)
				p["knee_l"] = Vector3(-1.25 * k, 0.0, 0.0)
				p["knee_r"] = Vector3(-1.25 * k, 0.0, 0.0)
				p["foot_l"] = Vector3(0.5 * k, 0.0, 0.0)
				p["foot_r"] = Vector3(0.5 * k, 0.0, 0.0)
				p["hips_y"] = -0.2 * k
				p["torso"] = Vector3(-0.3 * k, 0.0, 0.0)
				p["shoulder_l"] = Vector3(0.45 * k, 0.0, 0.3)
				p["shoulder_r"] = Vector3(0.45 * k, 0.0, -0.3)
			"skid":
				p["thigh_l"] = Vector3(0.7, 0.0, 0.1)
				p["thigh_r"] = Vector3(-0.25, 0.0, -0.1)
				p["knee_l"] = Vector3(-0.15, 0.0, 0.0)
				p["knee_r"] = Vector3(-0.6, 0.0, 0.0)
				p["hips_y"] = -0.1
				p["torso"] = Vector3(0.28, 0.0, 0.0)
				p["shoulder_l"] = Vector3(0.9, 0.0, 0.45)
				p["shoulder_r"] = Vector3(0.7, 0.0, -0.45)
				p["elbow_l"] = Vector3(0.5, 0.0, 0.0)
				p["elbow_r"] = Vector3(0.6, 0.0, 0.0)
				p["head"] = Vector3(-0.15, 0.0, 0.0)
			"stumble":
				var k2: float = sin(clampf(ct / 0.8, 0.0, 1.0) * PI)
				p["torso"] = Vector3(0.35 * k2, 0.25 * k2, 0.15 * k2)
				p["shoulder_l"] = Vector3(1.2 * k2, 0.0, 0.8 * k2)
				p["shoulder_r"] = Vector3(0.6 * k2, 0.0, -0.9 * k2)
				p["thigh_r"] = Vector3(-0.35 * k2, 0.0, -0.1)
				p["knee_r"] = Vector3(-0.3 * k2, 0.0, 0.0)
				p["head"] = Vector3(0.2 * k2, 0.0, 0.0)
			"getup":
				var k3: float = 1.0 - clampf(ct / 0.9, 0.0, 1.0)
				p["torso"] = Vector3(-0.9 * k3, 0.0, 0.0)
				p["thigh_l"] = Vector3(1.2 * k3, 0.0, 0.1)
				p["thigh_r"] = Vector3(1.2 * k3, 0.0, -0.1)
				p["knee_l"] = Vector3(-1.6 * k3, 0.0, 0.0)
				p["knee_r"] = Vector3(-1.6 * k3, 0.0, 0.0)
				p["hips_y"] = -0.5 * k3
```

3c. In `class RigAnimator` add members:

```gdscript
	var fidget_count: int = 0
	var _fidget: String = ""
	var _fidget_t: float = 8.0
	var _fidget_time: float = 0.0
	var _fidget_yaw: float = 0.0
```

replace `play()` with:

```gdscript
	func play(name: String, duration: float = -1.0) -> void:
		clip = name
		clip_time = 0.0
		clip_duration = duration if duration > 0.0 else float(Animator.ONE_SHOT.get(name, -1.0))
		if name == "getup" and player.has_animation("Death"):
			_pack_clip_playing = "Death"
			player.play("Death", 0.05, -GETUP_SPEED, true)
			_cur_anim = "Death"
			if duration <= 0.0:
				clip_duration = player.get_animation("Death").length / GETUP_SPEED
			return
		if PACK_CLIP.has(name) and player.has_animation(PACK_CLIP[name]):
			var a: String = PACK_CLIP[name]
			_pack_clip_playing = a
			player.play(a, 0.12)
			player.speed_scale = 1.0
			_cur_anim = a
			if clip_duration < 0.0 and not (name in HOLD_CLIPS):
				clip_duration = player.get_animation(a).length
		else:
			_pack_clip_playing = ""
```

In `RigAnimator._process` replace `clip_weight = minf(1.0, clip_weight + dt * 5.0)` with the `FAST_BLEND` form used in 3b, and replace the locomotion block (from `if _pack_clip_playing != "":` to the end of the `Run` branch) with:

```gdscript
		var sprint: float = clampf(float(params.get("sprint", 0.0)), 0.0, 1.0)
		if _pack_clip_playing != "":
			if clip == "lie" and not player.is_playing():
				pass   # giữ khung cuối (Death)
		elif amp < 0.08:
			_fidget_update(dt)
			if _fidget != "neutral":
				_play_anim("Idle")
				player.speed_scale = 1.0
		elif amp < 1.05 and float(params.get("run", 0.0)) < 0.3:
			_fidget_stop()
			_play_anim("Walk")
			player.speed_scale = clampf(speed / 1.25, 0.6, 1.6)
		else:
			_fidget_stop()
			_play_anim("Run")
			player.speed_scale = clampf(speed / 3.2, 0.7, 1.5) * (1.0 + 0.35 * sprint)
		if _pack_clip_playing == "" and clip_weight < 0.999:
			_overlay(sprint * (1.0 - clip_weight), float(params.get("lean", 0.0)) * (1.0 - clip_weight))
```

Add the helpers inside `RigAnimator`:

```gdscript
	## Lớp cộng thêm sau AnimationPlayer: nước rút (vung tay rộng hơn quanh tư thế nghỉ, thân đổ trước 12°), nghiêng hông.
	func _overlay(sprint: float, lean: float) -> void:
		if sprint > 0.01:
			for k: String in ["shoulder_l", "shoulder_r", "elbow_l", "elbow_r"]:
				if not _bone.has(k):
					continue
				var b: int = _bone[k]
				var rest_q: Quaternion = (_rest_local[b] as Basis).get_rotation_quaternion()
				var d: Quaternion = rest_q.inverse() * skeleton.get_bone_pose_rotation(b)
				var ang: float = d.get_angle()
				if ang > 0.0001:
					skeleton.set_bone_pose_rotation(b, rest_q * Quaternion(d.get_axis().normalized(), ang * (1.0 + 0.6 * sprint)))
			_add_rot("torso", Vector3(-0.21 * sprint, 0.0, 0.0))
		if absf(lean) > 0.001:
			_add_rot("hips", Vector3(0.0, 0.0, lean))

	## Xoay cộng thêm (Euler hệ nhân vật) lên tư thế hiện tại của xương khớp k.
	func _add_rot(k: String, e: Vector3) -> void:
		if not _bone.has(k):
			return
		var b: int = _bone[k]
		var ee: Vector3 = Vector3(-e.x, e.y, -e.z) if MODEL_YAW != 0.0 else e
		var pg: Basis = _parent_rest[b]
		var cur := Basis(skeleton.get_bone_pose_rotation(b))
		skeleton.set_bone_pose_rotation(b, ((pg.inverse() * Basis.from_euler(ee) * pg) * cur).get_rotation_quaternion())

	## Động tác vặt khi đứng yên: nhìn quanh (đầu ±50°), đổi chân (lắc hông), Idle_Neutral – mỗi 6..12 s.
	func _fidget_update(dt: float) -> void:
		if clip != "":
			_fidget_stop()
			return
		if _fidget == "":
			_fidget_t -= dt
			if _fidget_t <= 0.0:
				_fidget_t = randf_range(6.0, 12.0)
				_fidget = ["look", "shift", "neutral"][randi() % 3]
				_fidget_time = 0.0
				fidget_count += 1
				if _fidget == "neutral":
					if player.has_animation("Idle_Neutral"):
						_cur_anim = "Idle_Neutral"
						player.play("Idle_Neutral", 0.25)
					else:
						_fidget = "look"
			return
		_fidget_time += dt
		match _fidget:
			"look":
				_fidget_yaw = sin(_fidget_time / 3.0 * TAU) * 0.85
				if _fidget_time >= 3.0:
					_fidget_stop()
			"shift":
				_add_rot("hips", Vector3(0.0, 0.0, 0.06 * sin(_fidget_time / 2.5 * PI)))
				if _fidget_time >= 2.5:
					_fidget_stop()
			"neutral":
				if _fidget_time >= player.get_animation("Idle_Neutral").length:
					_fidget_stop()

	func _fidget_stop() -> void:
		_fidget = ""
		_fidget_yaw = 0.0
```

In `RigAnimator._look()` change the last line to `head_pivot.rotation = Vector3(_look_pitch, PI + _look_yaw + _fidget_yaw, 0.0)`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot --headless --path . --script tests/test_locomotion_anim.gd > /tmp/t6.log 2>&1; grep -E "amplitude|lean|getup|fidgets|SUCCESS|FAILED" /tmp/t6.log`
Expected: the four diagnostic lines then `✅ SUCCESS: LOCOMOTION LAYER - ...`. If the lean check reports accumulation, a locomotion animation does not key the Hips bone: cache the animation pose of Hips at the start of `_overlay` (`skeleton.get_bone_pose_rotation`) only when `player.is_playing()`, and skip `_add_rot("hips", ...)` otherwise.

- [ ] **Step 5: Regression and commit**

Run the regression command (all green; `test_character_builder` exercises every old clip on code bodies), then:

```bash
git add scripts/CharacterBuilder.gd tests/test_locomotion_anim.gd
git commit -m "feat(movement): rig locomotion layer (sprint arm pump and forward lean, hip lean, idle fidgets) and jump/fall/land/skid/stumble/knockdown/getup clips

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: ThirdPersonController movement state machine

**Files:**
- Modify: `scripts/ThirdPersonController.gd` (constants, members, `_build`, `_ensure_input_map`, `teleport`, `_physics_process`, `_update_camera`; new state functions)
- Create: `tests/test_locomotion.gd`

**Interfaces:**
- Consumes: Task 6 clips and params.
- Produces (used by Tasks 8, 10, 12):
  - Constants `WALK_SPEED = 1.7`, `JOG_SPEED = 4.2`, `SPRINT_SPEED = 7.5`, `RUN_SPEED = SPRINT_SPEED` (old name kept), `STAMINA_MAX_S = 6.0`, landing thresholds `SOFT_LAND_MAX = 2.5`, `ROLL_LAND_MAX = 6.0`.
  - Members `move_state: String` (`GROUND|JUMP|AIR|LAND_SOFT|LAND_ROLL|SPLAT`), `stamina: float` (0..1), `horizontal_speed`, `is_sprinting`, `walk_override: bool`, `jump_override: bool` (one-shot press for bots/tests), `slow_t: float` (seconds of half speed; the pedestrian spawner sets it), `landings: Array[String]` (test log).
  - Signal `landed(kind: String, drop: float)`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_locomotion.gd`:

```gdscript
# File: res://tests/test_locomotion.gd
# Test headless di chuyển kiểu GTA của ThirdPersonController: đi bộ 1.7 / chạy 4.2 m/s, thể lực nước rút ~6 s rồi hồi,
# nhảy tại chỗ cao ~0.9 m, nhảy khi nước rút xa >= 3.2 m, rơi 2 / 4 / 8 m -> nhún / lăn / ngã (khoá điều khiển rồi đứng
# dậy), đi qua bó vỉa 0.15 m không bao giờ vào trạng thái rơi.
# Chạy:  godot --headless --path . --script tests/test_locomotion.gd
extends SceneTree

var world: Node3D
var p: ThirdPersonController
var frames: int = 0
var phase: String = "settle"
var t0: int = 0
var mark := Vector3.ZERO
var peak: float = 0.0
var done: bool = false
var air_frames: int = 0


func _initialize() -> void:
	world = Node3D.new()
	root.add_child(world)
	_box(Vector3(0.0, -0.5, 0.0), Vector3(400.0, 1.0, 400.0))                 # sàn y = 0
	for h: float in [2.0, 4.0, 8.0]:
		_box(Vector3(60.0 + h * 10.0, h * 0.5, 0.0), Vector3(4.0, h, 4.0))     # bục cao h tại x = 80 / 100 / 140
	for i: int in range(6):
		_box(Vector3(-40.0 + float(i) * 1.2, 0.075, 30.0), Vector3(0.6, 0.15, 6.0))   # bó vỉa 0.15 m, cách nhau 0.6 m
	p = ThirdPersonController.new()
	p.capture_on_click = false
	world.add_child(p)
	p.teleport(Vector3(-150.0, 0.05, 0.0), -PI * 0.5)   # nhìn về +X
	physics_frame.connect(_on_physics)
	print("--- TEST LOCOMOTION (GTA-style movement) ---")


## Máy pha chạy theo nhịp vật lý (SceneTree.physics_frame phát mỗi bước vật lý).
func _on_physics() -> void:
	if done:
		return
	frames += 1
	_physics_process_test()


func _box(c: Vector3, size: Vector3) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = c
	world.add_child(sb)


func _goto(next: String) -> void:
	phase = next
	t0 = frames


func _physics_process_test() -> void:
	var t: int = frames - t0
	match phase:
		"settle":
			if t == 30:
				p.walk_override = true
				p.input_override = Vector2(0.0, -1.0)
				_goto("walk")
		"walk":
			if t == 90:
				print("  walk speed %.2f m/s" % p.horizontal_speed)
				if not _check(absf(p.horizontal_speed - 1.7) < 0.12, "walk speed must be 1.7 m/s (got %.2f)" % p.horizontal_speed):
					return
				p.walk_override = false
				_goto("jog")
		"jog":
			if t == 90:
				print("  jog speed %.2f m/s" % p.horizontal_speed)
				if not _check(absf(p.horizontal_speed - 4.2) < 0.15, "jog speed must be 4.2 m/s (got %.2f)" % p.horizontal_speed):
					return
				p.sprint_override = true
				_goto("sprint")
		"sprint":
			if not p.is_sprinting and t > 30:
				var secs: float = float(t) / 60.0
				print("  sprint lasted %.2f s" % secs)
				if not _check(absf(secs - 6.0) < 0.35, "stamina must last 6 s (got %.2f)" % secs):
					return
				p.sprint_override = false
				p.input_override = Vector2.ZERO
				_goto("rest")
		"rest":
			if t == 240:   # 1 s chờ + 3 s hồi -> 2.4 s thể lực
				var s: float = p.stamina * 6.0
				print("  stamina after 4 s rest: %.2f s" % s)
				if not _check(absf(s - 2.4) < 0.25, "stamina must refill 0.8 s per s after a 1 s delay (got %.2f s)" % s):
					return
				p.teleport(Vector3(-150.0, 0.05, -60.0), -PI * 0.5)
				_goto("jump_settle")
		"jump_settle":
			if t == 20:
				mark = p.global_position
				peak = mark.y
				p.jump_override = true
				_goto("jump")
		"jump":
			peak = maxf(peak, p.global_position.y)
			if t > 5 and p.move_state == "GROUND":
				var apex: float = peak - mark.y
				print("  standing jump apex %.2f m" % apex)
				if not _check(apex > 0.85 and apex < 1.0, "standing jump apex must be 0.85..1.0 m (got %.2f)" % apex):
					return
				p.stamina = 1.0
				p.sprint_override = true
				p.input_override = Vector2(0.0, -1.0)
				_goto("run_up")
		"run_up":
			if t == 120:
				mark = p.global_position
				p.jump_override = true
				_goto("long_jump")
		"long_jump":
			if t > 5 and p.move_state in ["GROUND", "LAND_SOFT"]:
				var dist: float = Vector2(p.global_position.x - mark.x, p.global_position.z - mark.z).length()
				print("  running jump distance %.2f m" % dist)
				if not _check(dist >= 3.2, "a sprint jump must cover at least 3.2 m (got %.2f)" % dist):
					return
				p.sprint_override = false
				p.landings.clear()
				p.teleport(Vector3(78.5, 2.05, 0.0), -PI * 0.5)   # bục 2 m (x 78..82): đi ra mép +X
				_goto("drop2")
		"drop2", "drop4", "drop8":
			if t == 10:
				p.input_override = Vector2(0.0, -1.0)
			if p.landings.size() > 0 and phase == "drop2":
				print("  2 m drop -> %s" % p.landings[0])
				if not _check(p.landings[0] == "LAND_SOFT", "a 2 m drop must give LAND_SOFT (got %s)" % p.landings[0]):
					return
				p.landings.clear()
				p.teleport(Vector3(98.5, 4.05, 0.0), -PI * 0.5)
				_goto("drop4")
			elif p.landings.size() > 0 and phase == "drop4":
				print("  4 m drop -> %s" % p.landings[0])
				if not _check(p.landings[0] == "LAND_ROLL", "a 4 m drop must give LAND_ROLL (got %s)" % p.landings[0]):
					return
				p.landings.clear()
				p.teleport(Vector3(138.5, 8.05, 0.0), -PI * 0.5)
				_goto("drop8")
			elif p.landings.size() > 0 and phase == "drop8":
				print("  8 m drop -> %s" % p.landings[0])
				if not _check(p.landings[0] == "SPLAT", "an 8 m drop must give SPLAT (got %s)" % p.landings[0]):
					return
				mark = p.global_position
				_goto("splat")
		"splat":
			if t == 140:   # 2.33 s: vẫn đang ngã/đứng dậy (1.5 + 0.9 s), không di chuyển dù giữ W
				var moved: float = Vector2(p.global_position.x - mark.x, p.global_position.z - mark.z).length()
				print("  moved %.2f m during the splat" % moved)
				if not _check(moved < 0.3, "input must be locked during the splat (moved %.2f m)" % moved):
					return
			if t == 170:
				if not _check(p.move_state == "GROUND", "after splat + getup the player is back on the ground state (got %s)" % p.move_state):
					return
				p.input_override = Vector2.ZERO
				p.teleport(Vector3(-43.0, 0.05, 30.0), -PI * 0.5)
				air_frames = 0
				_goto("kerbs")
		"kerbs":
			if t == 10:
				p.input_override = Vector2(0.0, -1.0)
			if p.move_state in ["AIR", "JUMP"]:
				air_frames += 1
			if t == 150:
				print("  kerb crossing: %d air frames, landings %s" % [air_frames, p.landings])
				if not _check(air_frames == 0 and p.landings.is_empty(), "stepping over 0.15 m kerbs must never enter the air state"):
					return
				print("✅ SUCCESS: GTA-STYLE MOVEMENT - SPEEDS, STAMINA, JUMPS, LANDINGS, SPLAT LOCK, KERBS")
				done = true
				quit(0)


func _process(_d: float) -> bool:
	return done


func _check(ok: bool, msg: String) -> bool:
	if not ok and not done:
		done = true
		print("❌ FAILED: ", msg)
		quit(2)
	return ok
```

(The jump impulse uses `sqrt(2 g h)`; with semi-implicit integration at 60 Hz the discrete apex comes out about 0.05 m higher than `JUMP_APEX`, hence the 0.85..1.0 bound.)

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless --path . --script tests/test_locomotion.gd > /tmp/t7.log 2>&1; grep -E "speed|SUCCESS|FAILED|Invalid" /tmp/t7.log`
Expected: a failure such as `Invalid assignment of property or key 'walk_override'` or `❌ FAILED: walk speed must be 1.7 m/s (got 4.20)`.

- [ ] **Step 3: Implement the state machine**

Replace the constants block at the top of `scripts/ThirdPersonController.gd` (from `const WALK_SPEED` to `const TURN_LERP`) with:

```gdscript
const WALK_SPEED: float = 1.7            # giữ Ctrl
const JOG_SPEED: float = 4.2             # mặc định
const SPRINT_SPEED: float = 7.5          # giữ Shift
const RUN_SPEED: float = SPRINT_SPEED    # tên cũ (mã ngoài / test)
const GRAVITY: float = 20.0
const ACCEL_JOG: float = 14.0
const ACCEL_SPRINT: float = 9.0
const DECEL: float = 18.0
const TURN_RATE_JOG: float = 10.0
const TURN_RATE_SPRINT: float = 6.0
const LEAN_K: float = 0.6                # độ nghiêng (độ) = LEAN_K × tốc độ quay (rad/s) × tốc độ (m/s)
const LEAN_MAX_DEG: float = 14.0
const STAMINA_MAX_S: float = 6.0
const STAMINA_DRAIN: float = 1.0
const STAMINA_REGEN: float = 0.8
const STAMINA_REGEN_DELAY: float = 1.0
const STAMINA_RESUME: float = 0.25
const SKID_MIN_SPEED: float = 6.0
const SKID_TIME: float = 0.25
const JUMP_APEX: float = 0.9
const JUMP_BUFFER: float = 0.12
const COYOTE: float = 0.1
const AIR_CONTROL: float = 0.3
const SOFT_LAND_MAX: float = 2.5
const ROLL_LAND_MAX: float = 6.0
const SOFT_LAND_TIME: float = 0.15
const ROLL_TIME: float = 0.8
const ROLL_KEEP: float = 0.7
const SPLAT_TIME: float = 1.5
const GETUP_TIME: float = 0.9
const FLAIL_AFTER: float = 0.5
const FLAIL_VY: float = -6.0
const FLOOR_SNAP: float = 0.4
const SPRINT_FOV_ADD: float = 6.0
const STEP_HEIGHT: float = 0.35
const CAM_DISTANCE: float = 3.2
const CAM_HEIGHT: float = 1.6
const CAM_MARGIN: float = 0.25
const MOUSE_SENS: float = 0.0022
const ORBIT_SPEED: float = 2.2          # rad/s khi giữ Z/C
const ORBIT_LEFT_KEY: Key = KEY_Z
const ORBIT_RIGHT_KEY: Key = KEY_C
const PITCH_MIN: float = -1.1
const PITCH_MAX: float = 0.55
const DEFAULT_PITCH: float = -0.2
```

Add below `extends CharacterBody3D`: `signal landed(kind: String, drop: float)`. Add these members after `var is_sprinting: bool = false`:

```gdscript
## Trạng thái di chuyển: GROUND | JUMP | AIR | LAND_SOFT | LAND_ROLL | SPLAT.
var move_state: String = "GROUND"
## Thể lực nước rút 0..1 (1 = STAMINA_MAX_S giây).
var stamina: float = 1.0
var walk_override: bool = false
## Bot / test: nhấn nhảy một lần (tự xoá sau khi đọc).
var jump_override: bool = false
## Giây còn lại bị chậm một nửa (va người đi đường khi nước rút).
var slow_t: float = 0.0
## Nhật ký kiểu tiếp đất (test).
var landings: Array[String] = []
var _exhausted: bool = false
var _stamina_wait: float = 0.0
var _state_t: float = 0.0
var _air_t: float = 0.0
var _peak_y: float = 0.0
var _last_floor_y: float = 0.0
var _jump_buffer_t: float = 0.0
var _coyote_t: float = 0.0
var _skid_t: float = 0.0
var _lean: float = 0.0
var _air_clip: String = ""
var _splat_phase: int = 0
var _shake_t: float = 0.0
var _shake_amp: float = 0.0
var _fov_base: float = 70.0
```

In `_build()` replace `floor_snap_length = 0.4` with `floor_snap_length = FLOOR_SNAP`. In `_ensure_input_map()` add to the bindings dictionary: `"walk": [KEY_CTRL], "jump": [KEY_SPACE]`. In `teleport()` add before `set_facing(yaw_rad)`:

```gdscript
	move_state = "GROUND"
	floor_snap_length = FLOOR_SNAP
	_peak_y = pos.y
	_last_floor_y = pos.y
	_air_clip = ""
	_state_t = 0.0
```

Replace `_physics_process()` with:

```gdscript
func _physics_process(delta: float) -> void:
	if not _built:
		return
	input_dir = _read_input()
	var want_sprint: bool = sprint_override or (controls_enabled and _pressed("sprint"))
	var want_walk: bool = walk_override or (controls_enabled and _pressed("walk"))
	if jump_override or (controls_enabled and InputMap.has_action("jump") and Input.is_action_just_pressed("jump")):
		_jump_buffer_t = JUMP_BUFFER
	jump_override = false
	if controls_enabled:
		if Input.is_physical_key_pressed(ORBIT_LEFT_KEY):
			yaw += ORBIT_SPEED * delta
		if Input.is_physical_key_pressed(ORBIT_RIGHT_KEY):
			yaw -= ORBIT_SPEED * delta
	var f := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var r := Vector3(cos(yaw), 0.0, -sin(yaw))
	var move: Vector3 = f * (-input_dir.y) + r * input_dir.x
	if move.length_squared() > 1.0:
		move = move.normalized()
	_state_t += delta
	_jump_buffer_t = maxf(0.0, _jump_buffer_t - delta)
	_coyote_t = COYOTE if is_on_floor() else maxf(0.0, _coyote_t - delta)
	slow_t = maxf(0.0, slow_t - delta)
	match move_state:
		"GROUND":
			_ground(delta, move, want_sprint, want_walk)
		"JUMP", "AIR":
			_air(delta, move)
		"LAND_SOFT":
			_ground(delta, move, want_sprint, want_walk)
			if move_state == "LAND_SOFT" and _state_t >= SOFT_LAND_TIME:
				move_state = "GROUND"
		"LAND_ROLL":
			_roll(delta, move)
		"SPLAT":
			_splat(delta)
	horizontal_speed = Vector2(velocity.x, velocity.z).length()
	if model:
		var moving_state: bool = move_state == "GROUND" or move_state == "LAND_SOFT"
		var sprint_anim: bool = is_sprinting and horizontal_speed > JOG_SPEED + 0.5
		CharacterBuilder.set_speed(model, horizontal_speed if moving_state else 0.0)
		CharacterBuilder.set_param(model, "run", 0.45 if sprint_anim else 0.0)
		CharacterBuilder.set_param(model, "sprint", 1.0 if sprint_anim else 0.0)
		CharacterBuilder.set_param(model, "lean", _lean)
	_update_camera(false)


func _pressed(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action)


func _play(clip: String, duration: float = -1.0) -> void:
	if model:
		CharacterBuilder.play(model, clip, duration)


## Thể lực: tụt 1/s khi đang nước rút nhanh hơn 5 m/s; hồi 0.8/s sau 1 s không nước rút; cạn thì chỉ chạy lại khi > 25 %.
func _update_stamina(delta: float, sprinting_now: bool) -> void:
	var s: float = stamina * STAMINA_MAX_S
	if sprinting_now and horizontal_speed > 5.0:
		s = maxf(0.0, s - STAMINA_DRAIN * delta)
		_stamina_wait = STAMINA_REGEN_DELAY
		if s <= 0.0:
			_exhausted = true
	else:
		_stamina_wait = maxf(0.0, _stamina_wait - delta)
		if _stamina_wait <= 0.0:
			s = minf(STAMINA_MAX_S, s + STAMINA_REGEN * delta)
	if _exhausted and s > STAMINA_RESUME * STAMINA_MAX_S:
		_exhausted = false
	stamina = s / STAMINA_MAX_S


func _ground(delta: float, move: Vector3, want_sprint: bool, want_walk: bool) -> void:
	var has_input: bool = move.length_squared() > 0.0001
	is_sprinting = want_sprint and has_input and not _exhausted
	_update_stamina(delta, is_sprinting)
	var speed: float = SPRINT_SPEED if is_sprinting else (WALK_SPEED if want_walk else JOG_SPEED)
	if slow_t > 0.0:
		speed *= 0.5
	if has_input:
		var accel: float = ACCEL_SPRINT if is_sprinting else ACCEL_JOG
		velocity.x = move_toward(velocity.x, move.x * speed, accel * delta)
		velocity.z = move_toward(velocity.z, move.z * speed, accel * delta)
		_skid_t = 0.0
	else:
		if horizontal_speed > SKID_MIN_SPEED and _skid_t <= 0.0 and move_state == "GROUND":
			_skid_t = SKID_TIME
			_play("skid", SKID_TIME)
		velocity.x = move_toward(velocity.x, 0.0, DECEL * delta)
		velocity.z = move_toward(velocity.z, 0.0, DECEL * delta)
	_skid_t = maxf(0.0, _skid_t - delta)
	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
		_last_floor_y = global_position.y
	else:
		velocity.y -= GRAVITY * delta
	if _jump_buffer_t > 0.0 and _coyote_t > 0.0:
		_start_jump()
		return
	if has_input and is_on_floor():
		_try_step_up(move, delta)
	move_and_slide()
	_turn(delta, move, TURN_RATE_SPRINT if is_sprinting else TURN_RATE_JOG)
	if not is_on_floor() and _coyote_t <= 0.0:
		_enter_air(false)


func _start_jump() -> void:
	_jump_buffer_t = 0.0
	_coyote_t = 0.0
	velocity.y = sqrt(2.0 * GRAVITY * JUMP_APEX)
	_enter_air(true)
	_play("jump_takeoff", 0.12)
	move_and_slide()


func _enter_air(jumped: bool) -> void:
	move_state = "JUMP" if jumped else "AIR"
	_state_t = 0.0
	_air_t = 0.0
	_air_clip = ""
	_peak_y = maxf(global_position.y, _last_floor_y)
	floor_snap_length = 0.0


func _air(delta: float, move: Vector3) -> void:
	_air_t += delta
	_update_stamina(delta, false)
	is_sprinting = false
	if move.length_squared() > 0.0001:
		var speed: float = maxf(JOG_SPEED, horizontal_speed)
		velocity.x = move_toward(velocity.x, move.x * speed, ACCEL_JOG * AIR_CONTROL * delta)
		velocity.z = move_toward(velocity.z, move.z * speed, ACCEL_JOG * AIR_CONTROL * delta)
	velocity.y -= GRAVITY * delta
	move_and_slide()
	_peak_y = maxf(_peak_y, global_position.y)
	_turn(delta, move, TURN_RATE_SPRINT * AIR_CONTROL)
	if move_state == "JUMP" and velocity.y <= 0.0:
		move_state = "AIR"
	var clip: String = "fall_flail" if (_air_t > FLAIL_AFTER or velocity.y < FLAIL_VY) else ("jump_air" if _air_t > 0.1 else "")
	if clip != "" and clip != _air_clip:
		_air_clip = clip
		_play(clip)
	if is_on_floor() and velocity.y <= 0.0 and _air_t > 0.05:
		_land(_peak_y - global_position.y)


func _land(drop: float) -> void:
	floor_snap_length = FLOOR_SNAP
	_air_clip = ""
	_state_t = 0.0
	_last_floor_y = global_position.y
	if drop < SOFT_LAND_MAX:
		move_state = "LAND_SOFT"
		_play("land_soft", SOFT_LAND_TIME)
	elif drop < ROLL_LAND_MAX:
		move_state = "LAND_ROLL"
		var fwd: Vector3 = facing_dir()
		var sp: float = maxf(horizontal_speed * ROLL_KEEP, 2.5)
		velocity.x = fwd.x * sp
		velocity.z = fwd.z * sp
		_play("roll", ROLL_TIME)
		_shake(0.25)
	else:
		move_state = "SPLAT"
		velocity.x = 0.0
		velocity.z = 0.0
		_splat_phase = 0
		_play("knockdown")
		_shake(0.5)
	landings.append(move_state)
	landed.emit(move_state, drop)


## Lăn: chỉ lái hướng; vận tốc bám hướng thân, giảm dần.
func _roll(delta: float, move: Vector3) -> void:
	_turn(delta, move, TURN_RATE_SPRINT)
	var sp: float = move_toward(Vector2(velocity.x, velocity.z).length(), 0.0, 2.0 * delta)
	var fwd: Vector3 = facing_dir()
	velocity.x = fwd.x * sp
	velocity.z = fwd.z * sp
	velocity.y = minf(velocity.y, 0.0) if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	if _state_t >= ROLL_TIME:
		move_state = "GROUND"


## Ngã sóng soài: khoá điều khiển SPLAT_TIME, rồi đứng dậy (getup) GETUP_TIME.
func _splat(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, DECEL * delta)
	velocity.z = move_toward(velocity.z, 0.0, DECEL * delta)
	velocity.y = minf(velocity.y, 0.0) if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	if _splat_phase == 0 and _state_t >= SPLAT_TIME:
		_splat_phase = 1
		_play("getup")
	elif _splat_phase == 1 and _state_t >= SPLAT_TIME + GETUP_TIME:
		move_state = "GROUND"
		_state_t = 0.0
		if model:
			CharacterBuilder.stop_clip(model)


## Quay thân về hướng di chuyển với tốc độ góc cố định (rad/s); nghiêng người theo tốc độ quay × tốc độ chạy.
func _turn(delta: float, move: Vector3, rate: float) -> void:
	if model == null:
		return
	var before: float = model.rotation.y
	if move.length_squared() > 0.0001:
		var diff: float = wrapf(atan2(-move.x, -move.z) - before, -PI, PI)
		model.rotation.y = before + clampf(diff, -rate * delta, rate * delta)
	var turn_rate: float = wrapf(model.rotation.y - before, -PI, PI) / maxf(delta, 0.0001)
	var lean_deg: float = clampf(LEAN_K * turn_rate * horizontal_speed, -LEAN_MAX_DEG, LEAN_MAX_DEG)
	_lean = lerpf(_lean, deg_to_rad(lean_deg), minf(1.0, delta * 8.0))


func _shake(amp: float) -> void:
	_shake_amp = amp
	_shake_t = 0.35
```

At the end of `_update_camera(snap)` append:

```gdscript
	var sprinting: bool = is_sprinting and horizontal_speed > JOG_SPEED + 0.5
	camera.fov = lerpf(camera.fov, _fov_base + (SPRINT_FOV_ADD if sprinting else 0.0), 0.08)
	var bob: float = 0.0
	if move_state == "GROUND" and horizontal_speed > JOG_SPEED - 0.5:
		bob = sin(float(Time.get_ticks_msec()) * 0.001 * TAU * horizontal_speed / 2.6) * 0.03 * clampf(horizontal_speed / SPRINT_SPEED, 0.0, 1.0)
	var sx: float = 0.0
	var sy: float = 0.0
	if _shake_t > 0.0:
		_shake_t -= get_process_delta_time()
		var k: float = _shake_amp * clampf(_shake_t / 0.35, 0.0, 1.0) * 0.12
		sx = randf_range(-k, k)
		sy = randf_range(-k, k)
	camera.position.x = sx
	camera.position.y = bob + sy
```

Update the header comment's API line to mention `move_state`, `stamina`, `walk_override`, `jump_override`, `slow_t`, `landed` and the `walk`/`jump` actions.

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot --headless --path . --script tests/test_locomotion.gd > /tmp/t7.log 2>&1; grep -E "speed|lasted|stamina|apex|distance|drop|moved|kerb|SUCCESS|FAILED" /tmp/t7.log`
Expected: every diagnostic line within its bound, then `✅ SUCCESS: GTA-STYLE MOVEMENT - ...`.

- [ ] **Step 5: Regression and commit**

Run the regression command. `test_free_roam` drives the controller (sprint at 7.5 m/s now, stamina limits long sprints): it must stay green; if a check there assumed endless sprint, give that check `player.set("stamina", 1.0)` before its sprint, never relax its assertion. Then:

```bash
git add scripts/ThirdPersonController.gd tests/test_locomotion.gd tests/test_free_roam.gd
git commit -m "feat(movement): GTA-style on-foot movement - walk/jog/sprint with 6 s stamina, inertia and skid, turn lean, jump with buffer and coyote time, soft/roll/splat landings, sprint FOV and camera shake

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: FreeRoam movement integration (after VC-2 and VC-4 are merged)

**Files:**
- Modify: `scripts/FreeRoam.gd` (`DECK_GUARD_ABOVE`, `BANK_WALL_H`, `BANK_GAP_DECK_MAX`, `HINT_DEFAULT`, `_build_hud()`, `_physics_process()`)
- Modify: `tests/test_free_roam.gd` (jump at the spawn, sprint-jump copies of the low-deck walks, stamina bar)
- Create: `tests/preview_movement.gd`
- Create (renders): `docs/preview/vice_move_sprint.png`, `vice_move_jump.png`, `vice_move_roll.png`

**Interfaces:**
- Consumes: Task 7 controller members (`stamina`, `move_state`, `is_sprinting`, `jump_override`, `landed`).
- Produces: `FreeRoam.stamina_bar: ProgressBar` (visible while stamina < 1 or sprinting).

- [ ] **Step 1: Write the failing checks in `tests/test_free_roam.gd`**

The test is an integer phase machine in `_process()` (`match phase:`). Add two members next to `var deck_min_y: float = 0.0`:

```gdscript
var jump_y0: float = 0.0
var deck_jumped: bool = false
```

In phase `1:` (the walk check that prints `walked %.2f m in 60 physics frames`) replace its last three lines

```gdscript
				roam.call("mount_bike")
				mark = pf
				phase = 2
```

with

```gdscript
				jump_y0 = player.global_position.y
				player.set("jump_override", true)
				mark = pf
				phase = 100
```

and add this phase to the `match` (anywhere among the numbered phases):

```gdscript
		100:
			if pf >= mark + 90:
				var st: String = String(player.get("move_state"))
				print("  jump at the spawn: state %s, y %.2f (start %.2f)" % [st, player.global_position.y, jump_y0])
				if not _check(st == "GROUND" and absf(player.global_position.y - jump_y0) < 0.3, "a jump at the spawn lands back on the ground state within 1.5 s"):
					return true
				if not _check(roam.get("stamina_bar") != null, "FreeRoam exposes a stamina bar"):
					return true
				roam.call("mount_bike")
				mark = pf
				phase = 2
```

At the end of `_setup_deck_walks()` (just before its `print("  %d sideways walks off low decks over water" ...)`) append a jumping copy of every walk:

```gdscript
	var n_plain: int = deck_walks.size()
	for i: int in range(n_plain):
		var jw: Array = (deck_walks[i] as Array).duplicate()
		jw[4] = String(jw[4]) + " + jump"
		jw.append(true)   # index 5: jump 1.2 m before the edge
		deck_walks.append(jw)
```

In `_start_deck_walk()` add `deck_jumped = false`, and at the top of phase `85:` add:

```gdscript
			var dw: Array = deck_walks[deck_i]
			if dw.size() > 5 and bool(dw[5]) and not deck_jumped:
				var dir3: Vector3 = dw[1]
				var lat: float = (_xz(player.global_position) - (dw[3] as Vector2)).dot(Vector2(dir3.x, dir3.z))
				if lat > float(dw[2]) - 1.2:
					player.set("jump_override", true)
					deck_jumped = true
```

The existing `_finish_deck_walk()` assertions (never below the deck, stopped by the invisible guard at the ribbon edge) now also cover sprint jumps.

Run: `godot --headless --path . --script tests/test_free_roam.gd > /tmp/t8.log 2>&1; grep -E "jump at the spawn|deck .*jump|SUCCESS|FAILED" /tmp/t8.log`
Expected: `❌ FAILED: FreeRoam exposes a stamina bar`.

- [ ] **Step 2: Implement**

2a. Raise the invisible water guards above the jump (spec: a jump must not clear the bank walls or the low-deck guards; the discrete jump apex is about 0.95 m and both are 1.0 m today). In `scripts/FreeRoam.gd` change:

```gdscript
const DECK_GUARD_ABOVE: float = 1.6      # lan can vô hình cao tới mặt đường + 1,6 m (cú nhảy ~0,95 m không qua được)
const BANK_WALL_H: float = 1.6           # tường bờ kênh vô hình: từ dưới mặt nước lên 1,6 m trên mặt đất
const BANK_GAP_DECK_MAX: float = 1.65    # tường bờ chỉ khoét dưới đoạn ribbon có mặt thấp hơn đỉnh tường (+5 cm)
```

(update the matching header comment numbers in the same file).

2b. Add `var stamina_bar: ProgressBar` with the other HUD members. At the end of `_build_hud()` add:

```gdscript
	# Thanh thể lực nước rút (Shift): hiện khi đang nước rút hoặc chưa hồi đầy; nằm ngay trên bảng gợi ý đáy
	stamina_bar = GameFXScript.make_bar(100.0, Color("#3FF2FF"), 10)
	stamina_bar.name = "StaminaBar"
	stamina_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	stamina_bar.offset_left = -110.0
	stamina_bar.offset_right = 110.0
	stamina_bar.offset_top = -96.0
	stamina_bar.offset_bottom = -86.0
	stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamina_bar.visible = false
	hud.add_child(stamina_bar)
```

In `_physics_process()`, right after `_update_hotspot()`, add:

```gdscript
	if stamina_bar:
		var on_foot: bool = not mounted and player.visible
		var st: float = float(player.get("stamina"))
		stamina_bar.value = st * 100.0
		stamina_bar.visible = on_foot and (st < 0.999 or bool(player.get("is_sprinting"))) and not (map_overlay and map_overlay.visible)
```

Replace the `HINT_DEFAULT` constant with:

```gdscript
const HINT_DEFAULT: String = "[WASD] đi · [Shift] chạy nước rút · [Ctrl] đi bộ · [Space] nhảy · [Z]/[C] xoay camera · [F] xe máy · [T] giờ trong ngày · [M] bản đồ · [ESC] tạm dừng"
```

(`_hint_text()` keeps working: it still replaces the `[F] xe máy` part with the distance to the bike.) Run `tests/test_hud_bounds.gd` afterwards: the longer hint must still fit (the hint panel autowraps; if it is clipped at 1280x720, shorten "trong ngày" to nothing).

- [ ] **Step 3: Create the movement preview**

Create `tests/preview_movement.gd`:

```gdscript
# File: res://tests/preview_movement.gd
# Ảnh di chuyển kiểu GTA trong FreeRoam (cần cửa sổ render):
#   godot --path . --script tests/preview_movement.gd      (PREVIEW_DIR=..., VICE_STYLE=vice|classic)
# vice_move_sprint (đang nước rút), vice_move_jump (giữa cú nhảy xa), vice_move_roll (lăn sau khi rơi 4 m).
extends SceneTree

var roam: Node3D
var player: ThirdPersonController
var frames: int = 0
var out_dir: String
var ledge: StaticBody3D


func _initialize() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	var style: String = OS.get_environment("VICE_STYLE")
	if style != "":
		var fx: Node = root.get_node("GameFX")
		fx.ready.connect(func() -> void: fx.call("set_art_style", style, false), CONNECT_ONE_SHOT)
	var dir_env: String = OS.get_environment("PREVIEW_DIR")
	out_dir = dir_env if dir_env != "" else ProjectSettings.globalize_path("user://preview")
	DirAccess.make_dir_recursive_absolute(out_dir)
	roam = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	root.add_child(roam)


func _save(name: String) -> void:
	var err: int = root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("  saved %s.png err=%d fps=%.0f" % [name, err, Engine.get_frames_per_second()])


func _process(_d: float) -> bool:
	frames += 1
	if frames == 5:
		player = roam.get("player")
		player.capture_on_click = false
		player.sprint_override = true
		player.input_override = Vector2(0.0, -1.0)
	if frames == 100:
		_save("vice_move_sprint")
		player.jump_override = true
	if frames == 118:
		_save("vice_move_jump")
		player.sprint_override = false
		var spot: Vector3 = player.global_position + player.facing_dir() * 3.0
		ledge = StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(3.0, 4.0, 3.0)
		cs.shape = bs
		ledge.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = bs.size
		mi.mesh = bm
		ledge.add_child(mi)
		roam.add_child(ledge)
		ledge.global_position = spot + Vector3(0.0, 2.0, 0.0)
		player.teleport(spot + Vector3(0.0, 4.05, 0.0), player.facing_yaw())
		player.input_override = Vector2(0.0, -1.0)
	if frames > 130 and player.move_state == "LAND_ROLL" and not roam.has_meta("roll_saved"):
		roam.set_meta("roll_saved", true)
		_save("vice_move_roll")
		print("PREVIEW MOVEMENT DONE")
		quit(0)
	if frames > 600:
		print("PREVIEW MOVEMENT: roll not reached")
		quit(1)
	return false
```

- [ ] **Step 4: Run tests and previews**

Run: `godot --headless --path . --script tests/test_free_roam.gd > /tmp/t8.log 2>&1; grep -E "SUCCESS|FAILED" /tmp/t8.log` — expected `✅ SUCCESS: FREE ROAM OK (...)`.
Run: `VICE_STYLE=vice PREVIEW_NOVSYNC=1 PREVIEW_DIR="$(pwd)/docs/preview" godot --path . --script tests/preview_movement.gd > /tmp/pm.log 2>&1; grep -E "saved|DONE" /tmp/pm.log` — expected three saved images with fps ≥ 45 and `PREVIEW MOVEMENT DONE`. Open them with the Read tool: the sprint shot shows pumping arms and a forward lean with the cyan stamina bar draining; the jump shot shows the airborne pose; the roll shot shows the rolling body.

- [ ] **Step 5: Regression and commit**

Run the regression command (all green), then:

```bash
git add scripts/FreeRoam.gd tests/test_free_roam.gd tests/preview_movement.gd docs/preview/vice_move_*.png
git commit -m "feat(movement): FreeRoam stamina bar and controls hint; jump checks at the spawn and the canal decks; movement previews

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

> **Part 3 re-planned (2026-10-22)** for the spec's "Amendment 2026-10-22: dense crowds and ambient traffic": Task 9 walk graph with zones, a cheap ring sampler and a per-MapData cache, Task 10 pedestrian with walk profiles and a stable identity, Task 11 far crowd impostors, Task 12 three-tier spawner + FreeRoam wiring, Task 13 ambient traffic, Task 14 docs. An independent plan review (2026-10-22) found 5 blockers (frame timing in headless tests, bike-capsule contact, physics timing monitor, graph build cost, a shared packed array in a test) and 8 majors; all are folded into the task text below.

### Task 9: `PedWalkGraph`

**Files:**
- Create: `scripts/roam/PedWalkGraph.gd`
- Create: `tests/test_pedestrians.gd` (part A only in this task)

**Interfaces:**
- Consumes:
  - `MapData` and `MapData.landmark("be6_outer")`;
  - from `MapBuilder`:
    - `_water_polygons(md)`, `region_shape(md, region)`, `KERB_MIN_ROAD_W`, `KERB_W`;
    - the cached 64 m OSM-building hash: `_prepare_osm_index(md)`, `_osm_hash`, `_osm_boxes`, `_osm_polys`, `_cell(p)`, `_cells_of_box(box, grow)`;
  - from `FPTUCampusBuilder`:
    - placement: `real_plot_transform()`, `plot_rect()`, `ring_outer_rect()`, `ring_courtyard_rect()`;
    - entrances: `main_gate_local()`, `west_gate_local()`, `back_gate_local()`, `lobby_u()`, `back_gap_u()`;
    - constants `PARK_LANE_V`, `PITCH_CX`, `PITCH_LEN`.
- Produces (Tasks 10-13):
  - Zones: `PedWalkGraph.ZONE_CAMPUS` (0, within 60 m of the campus plot), `ZONE_RESIDENTIAL` (1, inside the Vinhomes region shape), `ZONE_ROAD` (2, everything else), and `zone_at(i: int) -> int`.
  - `PedWalkGraph.build(md: MapData, opts: Dictionary = {}) -> PedWalkGraph`. It is cached per MapData: the first build costs < 1.5 s. Later builds return a fresh copy whose adjacency can be cut independently, because FreeRoam reloads after every stage.
  - `PedWalkGraph.from_lines(lines: Array) -> PedWalkGraph` (no filtering; for tests).
  - Queries:
    - `node_count() -> int`, `node_pos(i: int) -> Vector3`, `neighbours(i: int) -> Array`;
    - `next_node(node: int, came_from: int, rng: RandomNumberGenerator = null) -> int`;
    - `nearest(p: Vector3, max_r: float = 30.0) -> int`;
    - `random_point_ring(p: Vector3, r_min: float, r_max: float, rng: RandomNumberGenerator, tries: int = 12) -> int` (-1 when none; cheap even for the 150-220 m impostor ring).
  - `block_near(points: Array, r: float) -> void` cuts every edge passing within r of a point; it only scans hash cells near the points.
  - `static func _offset(pts, off)` offsets to the right of travel for off > 0. RoamTraffic uses it.

- [ ] **Step 1: Write the failing test (part A)**

Create `tests/test_pedestrians.gd`:

```gdscript
# File: res://tests/test_pedestrians.gd
# Test headless người đi đường FreeRoam (spec vice-people-and-movement, Phần 3).
#   A (Task 9):  đồ thị lối đi bộ từ mapdata: > 500 nút, không nút nào dưới nước / trong nhà OSM / trên lòng đường,
#                ba khu (campus / dân cư / đường) đủ nút, vòng quảng trường BE6, truy vấn random_point_ring / next_node,
#                lần dựng thứ hai lấy từ bộ nhớ đệm và block_near trên bản chép không cắt bản gốc.
#   B (Task 10): người đi đường trên đồ thị tự dựng: tốc độ theo kiểu đi, đi bộ + chạy bộ, va nhẹ -> STUMBLE, nước rút
#                -> KNOCKDOWN rồi đi lại trong 3 s, xe > 3 m/s -> KNOCKDOWN (tín hiệu "bike"), tầng giữa không va chạm.
#   C (Task 12): FreeRoam: mật độ theo khu (campus >= 40, dân cư >= 30, đường >= 15 người trong 80 m), trần từng tầng,
#                đêm còn 30 %, lên/xuống tầng giữ nguyên danh tính, tránh hotspot, xe tông người bị chậm lại, chi phí.
# Chạy:  godot --headless --path . --script tests/test_pedestrians.gd
extends SceneTree

const PART_B: bool = false   # Task 10 bật
const PART_C: bool = false   # Task 12 bật

var done: bool = false
var frames: int = 0


func _initialize() -> void:
	if not _part_a():
		return
	if not PART_B and not PART_C:
		print("✅ SUCCESS: PEDESTRIANS (part A: walk graph)")
		done = true
		quit(0)


func _part_a() -> bool:
	var md: MapData = MapData.load_default()
	var t0: int = Time.get_ticks_msec()
	var g: PedWalkGraph = PedWalkGraph.build(md)
	var ms: int = Time.get_ticks_msec() - t0
	print("  walk graph: %d nodes in %d ms" % [g.node_count(), ms])
	if not _check(g.node_count() > 500, "walk graph must have > 500 nodes (got %d)" % g.node_count()):
		return false
	if not _check(ms < 1500, "walk graph build must take < 1.5 s (took %d ms)" % ms):
		return false
	var water: Array = MapBuilder._water_polygons(md)
	var bld: Array = []
	for b: Dictionary in md.buildings():
		if not MapBuilder.is_msft(b):
			bld.append(MapData.poly(b.get("outer", [])))
	var roads: Array = []
	for r: Dictionary in md.roads():
		if int(r.get("lanes", 2)) > 0:
			roads.append([MapData.poly(r.get("points", [])), float(r.get("width", 6.0)) * 0.5])
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for n: int in range(300):
		var i: int = rng.randi_range(0, g.node_count() - 1)
		var p := Vector2(g.node_pos(i).x, g.node_pos(i).z)
		for w: PackedVector2Array in water:
			if not _check(not Geometry2D.is_point_in_polygon(p, w), "node %d %s lies in water" % [i, p]):
				return false
		for poly: PackedVector2Array in bld:
			# chỉ đường campus tự vẽ được phép nằm trong đường viền OSM (nhà campus dựng riêng bằng FPTUCampusBuilder)
			if poly.size() >= 3 and Geometry2D.is_point_in_polygon(p, poly) and not _campus_node(p):
				if not _check(false, "node %d %s lies inside an OSM building" % [i, p]):
					return false
		for rd: Array in roads:
			var pts: PackedVector2Array = rd[0]
			for k: int in range(pts.size() - 1):
				var d: float = Geometry2D.get_closest_point_to_segment(p, pts[k], pts[k + 1]).distance_to(p)
				if d < float(rd[1]) - 0.05 and not _campus_node(p):
					return _check(false, "node %d %s lies on a carriageway (%.2f m from the centreline, half width %.1f)" % [i, p, d, rd[1]])
	var spawn: Vector3 = md.spawn_transform().origin
	for ring: Vector2 in [Vector2(40.0, 80.0), Vector2(95.0, 220.0)]:
		var hits: int = 0
		for n: int in range(40):
			var j: int = g.random_point_ring(spawn, ring.x, ring.y, rng)
			if j >= 0:
				var d2: float = Vector2(g.node_pos(j).x - spawn.x, g.node_pos(j).z - spawn.z).length()
				if not _check(d2 >= ring.x and d2 <= ring.y, "random_point_ring returned a node %.1f m away (%.0f..%.0f)" % [d2, ring.x, ring.y]):
					return false
				hits += 1
		if not _check(hits >= 30, "random_point_ring found nodes %.0f..%.0f m from the BE6 spawn only %d / 40 times" % [ring.x, ring.y, hits]):
			return false
	var zc: Array = [0, 0, 0]
	for i2: int in range(g.node_count()):
		var z: int = g.zone_at(i2)
		zc[z] = int(zc[z]) + 1
		if z == PedWalkGraph.ZONE_CAMPUS and not _near_campus(Vector2(g.node_pos(i2).x, g.node_pos(i2).z)):
			return _check(false, "campus-zone node %d lies more than 60 m from the campus plot" % i2)
	print("  zones: campus %d, residential %d, road %d" % zc)
	if not _check(int(zc[0]) >= 50 and int(zc[1]) >= 50 and int(zc[2]) >= 50, "every zone needs >= 50 nodes (campus %d, residential %d, road %d)" % zc):
		return false
	var ns: int = g.nearest(spawn, 60.0)
	if not _check(ns >= 0 and g.zone_at(ns) == PedWalkGraph.ZONE_RESIDENTIAL, "the BE6 spawn must lie in the residential zone (nearest node %d)" % ns):
		return false
	var plaza: int = _be6_ring_nodes(g, md)
	print("  BE6 plaza ring: %d nodes" % plaza)
	if not _check(plaza >= 12, "the BE6 plaza ring must add >= 12 walk nodes 4-8 m outside the tower (got %d)" % plaza):
		return false
	var deg2: int = -1
	for i: int in range(g.node_count()):
		if g.neighbours(i).size() >= 2:
			deg2 = i
			break
	var a: int = int(g.neighbours(deg2)[0])
	for n: int in range(10):
		var nxt: int = g.next_node(deg2, a, rng)
		if not _check(nxt != a and g.neighbours(deg2).has(nxt), "next_node must pick a neighbour other than came_from"):
			return false
	var keep: int = g.neighbours(deg2).size()
	var t1: int = Time.get_ticks_msec()
	var g2: PedWalkGraph = PedWalkGraph.build(md)
	var ms2: int = Time.get_ticks_msec() - t1
	print("  cached rebuild: %d ms" % ms2)
	if not _check(ms2 < 200 and g2.node_count() == g.node_count(), "a second build must come from the cache (%d ms, %d nodes)" % [ms2, g2.node_count()]):
		return false
	g2.block_near([g2.node_pos(deg2)], 3.0)
	return _check(g2.neighbours(deg2).is_empty() and g.neighbours(deg2).size() == keep, "block_near on one copy must not cut another copy or the cache")


func _campus_node(p: Vector2) -> bool:
	var local: Vector3 = FPTUCampusBuilder.real_plot_transform().affine_inverse() * Vector3(p.x, 0.0, p.y)
	return FPTUCampusBuilder.plot_rect().grow(3.0).has_point(Vector2(local.x, local.z))


func _near_campus(p: Vector2) -> bool:
	var local: Vector3 = FPTUCampusBuilder.real_plot_transform().affine_inverse() * Vector3(p.x, 0.0, p.y)
	return FPTUCampusBuilder.plot_rect().grow(PedWalkGraph.CAMPUS_NEAR_M + 1.0).has_point(Vector2(local.x, local.z))


## Số nút cách đường viền toà BE6 từ 4 tới 8 m (vòng quảng trường dời 6 m ra ngoài).
func _be6_ring_nodes(g: PedWalkGraph, md: MapData) -> int:
	var be6: PackedVector2Array = MapData.poly(md.landmark("be6_outer"))
	var box := Rect2(be6[0], Vector2.ZERO)
	for q: Vector2 in be6:
		box = box.expand(q)
	box = box.grow(10.0)
	var n: int = 0
	for i: int in range(g.node_count()):
		var p := Vector2(g.node_pos(i).x, g.node_pos(i).z)
		if not box.has_point(p) or Geometry2D.is_point_in_polygon(p, be6):
			continue
		var d: float = INF
		for k: int in range(be6.size()):
			d = minf(d, Geometry2D.get_closest_point_to_segment(p, be6[k], be6[(k + 1) % be6.size()]).distance_to(p))
		if d > 4.0 and d < 8.0:
			n += 1
	return n


func _check(ok: bool, msg: String) -> bool:
	if not ok and not done:
		done = true
		print("❌ FAILED: ", msg)
		quit(2)
	return ok
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless --path . --script tests/test_pedestrians.gd > /tmp/t9.log 2>&1; grep -E "SUCCESS|FAILED|Identifier" /tmp/t9.log`
Expected: `Identifier "PedWalkGraph" not declared in the current scope.`

- [ ] **Step 3: Implement**

Create `scripts/roam/PedWalkGraph.gd`:

```gdscript
# File: res://scripts/roam/PedWalkGraph.gd
# Đồ thị lối đi bộ cho người đi đường FreeRoam, dựng từ MapData (một lần mỗi MapData, các lần sau chép): lề sau bó vỉa
# hai bên mỗi làn xe rộng >= MapBuilder.KERB_MIN_ROAD_W (đường một chiều chỉ lề phải: bên trái là dải phân cách của
# đường đôi), đường đi bộ (lanes == 0), vòng quảng trường quanh BE6, đường quanh toà nhà campus + sân trong + lối xuyên
# sảnh / lối sau + ba cổng. Bỏ điểm dưới / sát nước, trong nhà OSM, trên lòng đường, ngoài ba vùng đã dựng, (đường OSM)
# trong lô campus; nối các đường gần nhau (góc phố, băng qua đường). Nhà Microsoft và vật cản dựng thêm do
# PedestrianSpawner kiểm bằng vật lý.
# Mỗi nút mang khu (campus: trong 60 m quanh lô campus / dân cư: trong vùng Vinhomes / đường) cho PedestrianSpawner.
# Không dùng autoload ở đây (class_name biên dịch trước autoload khi chạy test --script).
class_name PedWalkGraph
extends RefCounted

const SAMPLE_M: float = 6.0
const VERGE_OFFSET: float = 0.45
const ROAD_CLEAR: float = 0.3
const WATER_CLEAR: float = 0.8
const LINK_R: float = 6.0
const MAX_LINKS: int = 3
const CELL: float = 16.0
const SEG_CELL: float = 32.0
const CAMPUS_LOOP_GROW: float = 5.0
const COURTYARD_INSET: float = 1.5
const BE6_PLAZA_M: float = 6.0
const REGIONS: Array[String] = ["vinhomes", "corridor", "campus"]
## Khu (mật độ + preset người đi đường): campus = trong vòng 60 m quanh lô campus; dân cư = trong vùng Vinhomes; còn lại = đường.
const ZONE_CAMPUS: int = 0
const ZONE_RESIDENTIAL: int = 1
const ZONE_ROAD: int = 2
const CAMPUS_NEAR_M: float = 60.0

static var _cache_md: MapData = null
static var _cache_graph: PedWalkGraph = null

var pos: PackedVector3Array = PackedVector3Array()
var adj: Array = []             # Array of Array[int]
var line_of: PackedInt32Array = PackedInt32Array()
var zone_of: PackedByteArray = PackedByteArray()
var _hash: Dictionary = {}      # Vector2i -> Array[int]


# ===========================================================================
# DỰNG
# ===========================================================================
## Đồ thị của md: dựng lần đầu (< 1,5 s); các lần sau (FreeRoam nạp lại sau mỗi màn) trả bản chép của đồ thị đã dựng –
## nút dùng chung, danh sách kề riêng, nên block_near trên bản chép không cắt đồ thị gốc.
static func build(md: MapData, _opts: Dictionary = {}) -> PedWalkGraph:
	if md == null:
		push_warning("PedWalkGraph: không có MapData")
		return PedWalkGraph.new()
	if md != _cache_md or _cache_graph == null:
		_cache_graph = _build_uncached(md)
		_cache_md = md
	return _cache_graph._copy()


static func _build_uncached(md: MapData) -> PedWalkGraph:
	var g := PedWalkGraph.new()
	var ctx: Dictionary = _context(md)
	var line_id: int = 0
	for r: Dictionary in md.roads():
		if bool(r.get("bridge", false)):
			continue
		var pts: PackedVector2Array = MapData.poly(r.get("points", []))
		if pts.size() < 2:
			continue
		var w: float = float(r.get("width", 6.0))
		if int(r.get("lanes", 2)) <= 0:
			g._add_line(pts, ctx, line_id, true, true, true)
			line_id += 1
		elif w >= MapBuilder.KERB_MIN_ROAD_W:
			var off: float = w * 0.5 + MapBuilder.KERB_W + VERGE_OFFSET
			g._add_line(_offset(pts, off), ctx, line_id, true, true, true)
			line_id += 1
			if not bool(r.get("oneway", false)):   # đường một chiều (nửa đường đôi): bên trái là dải phân cách
				g._add_line(_offset(pts, -off), ctx, line_id, true, true, true)
				line_id += 1
	var be6: Variant = md.landmark("be6_outer")
	if be6 is Array and (be6 as Array).size() >= 3:
		for ring: PackedVector2Array in Geometry2D.offset_polygon(MapData.poly(be6), BE6_PLAZA_M):
			var loop: PackedVector2Array = ring.duplicate()
			loop.append(ring[0])
			g._add_line(loop, ctx, line_id, true, true, true)
			line_id += 1
	for line: PackedVector2Array in _campus_lines():
		g._add_line(line, ctx, line_id, false, false, false)
		line_id += 1
	g._link(ctx)
	return g


## Đồ thị từ các polyline (Array[PackedVector2Array], toạ độ bản đồ) không lọc gì – cho test.
static func from_lines(lines: Array) -> PedWalkGraph:
	var g := PedWalkGraph.new()
	var id: int = 0
	for line: PackedVector2Array in lines:
		var prev: int = -1
		for p: Vector2 in line:
			var n: int = g._add_node(p, id)
			if prev >= 0:
				g._connect(prev, n)
			prev = n
		id += 1
	return g


## Bản chép: vị trí / khu / băm dùng chung (chỉ đọc), danh sách kề riêng.
func _copy() -> PedWalkGraph:
	var g := PedWalkGraph.new()
	g.pos = pos
	g.line_of = line_of
	g.zone_of = zone_of
	g._hash = _hash
	for a: Array in adj:
		g.adj.append(a.duplicate())
	return g


# ===========================================================================
# TRUY VẤN
# ===========================================================================
func zone_at(i: int) -> int:
	return zone_of[i]


func node_count() -> int:
	return pos.size()


func node_pos(i: int) -> Vector3:
	return pos[i]


func neighbours(i: int) -> Array:
	return adj[i]


## Nút kế tiếp từ `node` (vừa tới từ `came_from`): ngẫu nhiên trong các nút kề trừ nút vừa đi; ngõ cụt thì quay lại.
func next_node(node: int, came_from: int, rng: RandomNumberGenerator = null) -> int:
	var n: Array = adj[node]
	if n.is_empty():
		return node
	var choices: Array[int] = []
	for v: int in n:
		if v != came_from:
			choices.append(v)
	if choices.is_empty():
		return came_from if came_from >= 0 else int(n[0])
	if rng == null:
		return choices[randi() % choices.size()]
	return choices[rng.randi_range(0, choices.size() - 1)]


func nearest(p: Vector3, max_r: float = 30.0) -> int:
	var best: int = -1
	var best_d: float = max_r * max_r
	var c0: Vector2i = _cell(Vector2(p.x, p.z))
	var reach: int = ceili(max_r / CELL)
	for dx: int in range(-reach, reach + 1):
		for dz: int in range(-reach, reach + 1):
			for i: int in _hash.get(Vector2i(c0.x + dx, c0.y + dz), []):
				var d: float = Vector2(pos[i].x - p.x, pos[i].z - p.z).length_squared()
				if d < best_d:
					best_d = d
					best = i
	return best


## Cắt mọi cạnh đi qua vùng bán kính r quanh các điểm (Array[Vector3]): nút bên trong thành cô lập, nên người đi đường
## (chỉ đi tới nút kề) không bao giờ đi vào hay lướt qua vùng đó (cột sáng hotspot, điểm spawn BE6). Chỉ quét các ô băm
## trong r + độ dài cạnh tối đa quanh mỗi điểm.
func block_near(points: Array, r: float) -> void:
	var reach: int = ceili((r + SAMPLE_M * 1.6) / CELL)
	for pt: Variant in points:
		var pv: Vector3 = pt
		var p2 := Vector2(pv.x, pv.z)
		var c0: Vector2i = _cell(p2)
		for dx: int in range(-reach, reach + 1):
			for dz: int in range(-reach, reach + 1):
				for i: int in _hash.get(Vector2i(c0.x + dx, c0.y + dz), []):
					var a := Vector2(pos[i].x, pos[i].z)
					for e: int in (adj[i] as Array).duplicate():
						var b := Vector2(pos[e].x, pos[e].z)
						if Geometry2D.get_closest_point_to_segment(p2, a, b).distance_to(p2) < r:
							(adj[i] as Array).erase(e)
							(adj[e] as Array).erase(i)


## Nút ngẫu nhiên trong vành r_min..r_max quanh p, rẻ cả với vành rộng (người nộm ở 150-220 m): thử `tries` điểm rải đều
## theo diện tích, mỗi điểm lấy một nút của ô băm chứa nó nếu nút đó nằm trong vành. -1 nếu không trúng lần nào.
func random_point_ring(p: Vector3, r_min: float, r_max: float, rng: RandomNumberGenerator, tries: int = 12) -> int:
	for k: int in range(tries):
		var ang: float = rng.randf() * TAU
		var r: float = sqrt(rng.randf_range(r_min * r_min, r_max * r_max))
		var cell: Array = _hash.get(_cell(Vector2(p.x + cos(ang) * r, p.z + sin(ang) * r)), [])
		if cell.is_empty():
			continue
		var i: int = int(cell[rng.randi_range(0, cell.size() - 1)])
		var d: float = Vector2(pos[i].x - p.x, pos[i].z - p.z).length()
		if d >= r_min and d <= r_max:
			return i
	return -1


# ===========================================================================
# NỘI BỘ
# ===========================================================================
func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


func _add_node(p: Vector2, line_id: int, zone: int = ZONE_ROAD) -> int:
	var id: int = pos.size()
	pos.append(Vector3(p.x, 0.0, p.y))
	adj.append([])
	line_of.append(line_id)
	zone_of.append(zone)
	var c: Vector2i = _cell(p)
	if not _hash.has(c):
		_hash[c] = []
	(_hash[c] as Array).append(id)
	return id


func _connect(a: int, b: int) -> void:
	if a == b or (adj[a] as Array).has(b):
		return
	(adj[a] as Array).append(b)
	(adj[b] as Array).append(a)


## Lấy mẫu polyline mỗi SAMPLE_M m; điểm hỏng cắt đường; hai điểm liền nhau chỉ nối khi trung điểm không ướt (kênh hẹp).
func _add_line(pts: PackedVector2Array, ctx: Dictionary, line_id: int, check_buildings: bool, check_roads: bool, outside_plot: bool) -> void:
	var prev: int = -1
	var prev_p := Vector2.ZERO
	for i: int in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n: int = maxi(1, ceili(a.distance_to(b) / SAMPLE_M))
		for s: int in range(0 if i == 0 else 1, n + 1):
			var p: Vector2 = a.lerp(b, float(s) / float(n))
			if not _ok(p, ctx, check_buildings, check_roads, outside_plot):
				prev = -1
				continue
			var id: int = _add_node(p, line_id, _zone(p, ctx))
			if prev >= 0 and prev_p.distance_to(p) <= SAMPLE_M * 1.6 and not _wet((prev_p + p) * 0.5, ctx):
				_connect(prev, id)
			prev = id
			prev_p = p


## Nối nút của các đường khác nhau trong LINK_R (góc phố, băng qua đường): mỗi nút tối đa MAX_LINKS, gần nhất trước,
## trung điểm đoạn nối không dưới nước / trong nhà OSM (trong lô campus không kiểm nhà OSM: nhà campus dựng riêng).
func _link(ctx: Dictionary) -> void:
	var plot: PackedVector2Array = ctx["plot"]
	for i: int in range(pos.size()):
		var p := Vector2(pos[i].x, pos[i].z)
		var best: Dictionary = {}    # line id -> [node, dist]
		var c0: Vector2i = _cell(p)
		for dx: int in range(-1, 2):
			for dz: int in range(-1, 2):
				for j: int in _hash.get(Vector2i(c0.x + dx, c0.y + dz), []):
					if line_of[j] == line_of[i]:
						continue
					var d: float = p.distance_to(Vector2(pos[j].x, pos[j].z))
					if d > LINK_R:
						continue
					if not best.has(line_of[j]) or d < float((best[line_of[j]] as Array)[1]):
						best[line_of[j]] = [j, d]
		var links: Array = best.values()
		links.sort_custom(func(x: Array, y: Array) -> bool: return float(x[1]) < float(y[1]))
		var made: int = 0
		for l: Array in links:
			if made >= MAX_LINKS or (adj[i] as Array).size() >= MAX_LINKS + 2:
				break
			var j2: int = int(l[0])
			var mid: Vector2 = (p + Vector2(pos[j2].x, pos[j2].z)) * 0.5
			if _ok(mid, ctx, not Geometry2D.is_point_in_polygon(mid, plot), false, false):
				_connect(i, j2)
				made += 1


static func _ok(p: Vector2, ctx: Dictionary, check_buildings: bool, check_roads: bool, outside_plot: bool) -> bool:
	var inside: bool = false
	var shapes: Array = ctx["shapes"]
	var shape_box: Array = ctx["shape_box"]
	for i: int in range(shapes.size()):
		if (shape_box[i] as Rect2).has_point(p) and Geometry2D.is_point_in_polygon(p, shapes[i]):
			inside = true
			break
	if not inside or _wet(p, ctx):
		return false
	if check_buildings:
		for bi: int in MapBuilder._osm_hash.get(MapBuilder._cell(p), []):
			if (MapBuilder._osm_boxes[bi] as Rect2).has_point(p) and Geometry2D.is_point_in_polygon(p, MapBuilder._osm_polys[bi]):
				return false
	if outside_plot and Geometry2D.is_point_in_polygon(p, ctx["plot"]):
		return false
	if check_roads:
		var key := Vector2i(floori(p.x / SEG_CELL), floori(p.y / SEG_CELL))
		var segs: Array = ctx["segs"]
		for si: int in (ctx["seg_hash"] as Dictionary).get(key, []):
			var s: Array = segs[si]
			if Geometry2D.get_closest_point_to_segment(p, s[0], s[1]).distance_to(p) < float(s[2]) + ROAD_CLEAR:
				return false
	return true


## Trong nước hoặc cách mép nước dưới WATER_CLEAR: đa giác nước đã nở sẵn WATER_CLEAR, tra qua băm ô 64 m của MapBuilder.
static func _wet(p: Vector2, ctx: Dictionary) -> bool:
	var water: Array = ctx["water"]
	var water_box: Array = ctx["water_box"]
	for wi: int in (ctx["water_hash"] as Dictionary).get(MapBuilder._cell(p), []):
		if (water_box[wi] as Rect2).has_point(p) and Geometry2D.is_point_in_polygon(p, water[wi]):
			return true
	return false


static func _context(md: MapData) -> Dictionary:
	var ctx: Dictionary = {"water": [], "water_box": [], "water_hash": {}, "segs": [], "seg_hash": {}, "shapes": [], "shape_box": []}
	MapBuilder._prepare_osm_index(md)   # băm ô 64 m của nhà OSM, dùng chung với MapBuilder
	for w: PackedVector2Array in MapBuilder._water_polygons(md):
		for gw: PackedVector2Array in Geometry2D.offset_polygon(w, WATER_CLEAR):
			var wi: int = (ctx["water"] as Array).size()
			var bb: Rect2 = _bbox(gw)
			(ctx["water"] as Array).append(gw)
			(ctx["water_box"] as Array).append(bb)
			for c: Vector2i in MapBuilder._cells_of_box(bb, 0.0):
				if not (ctx["water_hash"] as Dictionary).has(c):
					ctx["water_hash"][c] = []
				(ctx["water_hash"][c] as Array).append(wi)
	for r: Dictionary in md.roads():
		if int(r.get("lanes", 2)) <= 0:
			continue
		var pts: PackedVector2Array = MapData.poly(r.get("points", []))
		var hw: float = float(r.get("width", 6.0)) * 0.5
		for i: int in range(pts.size() - 1):
			var si: int = (ctx["segs"] as Array).size()
			(ctx["segs"] as Array).append([pts[i], pts[i + 1], hw])
			var bb2: Rect2 = Rect2(pts[i], Vector2.ZERO).expand(pts[i + 1]).grow(hw + ROAD_CLEAR)
			for cx: int in range(floori(bb2.position.x / SEG_CELL), floori(bb2.end.x / SEG_CELL) + 1):
				for cz: int in range(floori(bb2.position.y / SEG_CELL), floori(bb2.end.y / SEG_CELL) + 1):
					var key := Vector2i(cx, cz)
					if not (ctx["seg_hash"] as Dictionary).has(key):
						ctx["seg_hash"][key] = []
					(ctx["seg_hash"][key] as Array).append(si)
	for reg: String in REGIONS:
		for poly: PackedVector2Array in MapBuilder.region_shape(md, reg):
			(ctx["shapes"] as Array).append(poly)
			(ctx["shape_box"] as Array).append(_bbox(poly))
	var xf: Transform3D = FPTUCampusBuilder.real_plot_transform()
	var pr: Rect2 = FPTUCampusBuilder.plot_rect()
	var plot := PackedVector2Array()
	for c: Vector2 in [pr.position, Vector2(pr.end.x, pr.position.y), pr.end, Vector2(pr.position.x, pr.end.y)]:
		var w3: Vector3 = xf * Vector3(c.x, 0.0, c.y)
		plot.append(Vector2(w3.x, w3.z))
	ctx["plot"] = plot
	var near := PackedVector2Array()
	var pg: Rect2 = pr.grow(CAMPUS_NEAR_M)
	for c2: Vector2 in [pg.position, Vector2(pg.end.x, pg.position.y), pg.end, Vector2(pg.position.x, pg.end.y)]:
		var w4: Vector3 = xf * Vector3(c2.x, 0.0, c2.y)
		near.append(Vector2(w4.x, w4.z))
	ctx["campus_near"] = near
	ctx["vinhomes"] = MapBuilder.region_shape(md, "vinhomes")
	return ctx


static func _zone(p: Vector2, ctx: Dictionary) -> int:
	if Geometry2D.is_point_in_polygon(p, ctx["campus_near"]):
		return ZONE_CAMPUS
	for poly: PackedVector2Array in ctx["vinhomes"]:
		if Geometry2D.is_point_in_polygon(p, poly):
			return ZONE_RESIDENTIAL
	return ZONE_ROAD


## Lối đi campus (hệ cục bộ u dọc D1, v vào lô): đường hở quanh toà nhà – từ sau rào sân bóng theo giữa làn bãi xe sau lưng
## (tránh cột mái che và hai dãy xe), xuống mép Tây, dọc mặt trước, lên dải ĐN rồi dừng trước rào sân bóng; vòng sân
## trong; lối xuyên sảnh trước và lối sau (lệch 0,8 m khỏi cột mái dãy A) nối vòng ngoài với sân trong; ba cổng.
static func _campus_lines() -> Array:
	var xf: Transform3D = FPTUCampusBuilder.real_plot_transform()
	var out: Array = []
	var ro: Rect2 = FPTUCampusBuilder.ring_outer_rect()
	var u0: float = ro.position.x - CAMPUS_LOOP_GROW
	var u1: float = ro.end.x + CAMPUS_LOOP_GROW
	var v0: float = ro.position.y - CAMPUS_LOOP_GROW
	var vb: float = FPTUCampusBuilder.PARK_LANE_V
	var pitch_end: float = FPTUCampusBuilder.PITCH_CX + FPTUCampusBuilder.PITCH_LEN * 0.5 + 2.0
	out.append(_local_line([Vector2(pitch_end, vb), Vector2(u1, vb), Vector2(u1, v0), Vector2(u0, v0), Vector2(u0, ro.end.y)], xf))
	var court: Rect2 = FPTUCampusBuilder.ring_courtyard_rect().grow(-COURTYARD_INSET)
	out.append(_rect_loop(court, xf))
	var lu: float = FPTUCampusBuilder.lobby_u()
	out.append(_local_line([Vector2(lu, v0), Vector2(lu, court.position.y)], xf))
	var bu: float = FPTUCampusBuilder.back_gap_u() - 0.8
	out.append(_local_line([Vector2(bu, vb), Vector2(bu, court.end.y)], xf))
	for g: Vector3 in [FPTUCampusBuilder.main_gate_local(), FPTUCampusBuilder.west_gate_local()]:
		out.append(_local_line([Vector2(g.x, -2.0), Vector2(g.x, v0)], xf))
	var bg: Vector3 = FPTUCampusBuilder.back_gate_local()
	out.append(_local_line([Vector2(bg.x, bg.z + 2.0), Vector2(bg.x, vb)], xf))
	return out


static func _rect_loop(r: Rect2, xf: Transform3D) -> PackedVector2Array:
	return _local_line([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position], xf)


static func _local_line(pts: Array, xf: Transform3D) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		var w: Vector3 = xf * Vector3(p.x, 0.0, p.y)
		out.append(Vector2(w.x, w.z))
	return out


## Polyline dời sang PHẢI chiều đi (off > 0; hệ x đông / z nam: pháp tuyến (-dz, dx)) / trái (off < 0) theo pháp tuyến
## trung bình ở mỗi đỉnh (giới hạn mitre). RoamTraffic dùng off = +rộng/4 cho làn bên phải.
static func _offset(pts: PackedVector2Array, off: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n: int = pts.size()
	for i: int in range(n):
		var d0: Vector2 = (pts[i] - pts[i - 1]).normalized() if i > 0 else (pts[1] - pts[0]).normalized()
		var d1: Vector2 = (pts[i + 1] - pts[i]).normalized() if i < n - 1 else d0
		var sum: Vector2 = d0 + d1
		var nrm: Vector2 = Vector2(-sum.y, sum.x).normalized() if sum.length() > 0.01 else Vector2(-d1.y, d1.x)
		var cos_half: float = maxf(0.35, nrm.dot(Vector2(-d1.y, d1.x)))
		out.append(pts[i] + nrm * off / cos_half)
	return out


static func _bbox(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p: Vector2 in poly:
		r = r.expand(p)
	return r
```

Run: `godot --headless --import --path . > /tmp/imp.log 2>&1; grep -c PedWalkGraph .godot/global_script_class_cache.cfg` — expected ≥ 2.

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot --headless --path . --script tests/test_pedestrians.gd > /tmp/t9.log 2>&1; grep -E "walk graph|zones|plaza|cached|SUCCESS|FAILED" /tmp/t9.log`
Expected:
- `walk graph: N nodes in M ms` (N > 500, M < 1500);
- `zones: campus a, residential b, road c` (each ≥ 50);
- `BE6 plaza ring: k nodes` (k ≥ 12);
- `cached rebuild: m ms` (m < 200);
- then `✅ SUCCESS: PEDESTRIANS (part A: walk graph)`.

Write N, M, the zone counts and m in the report.

- [ ] **Step 5: Regression and commit**

Run the regression command (all green), then:

```bash
git add scripts/roam/PedWalkGraph.gd tests/test_pedestrians.gd
git commit -m "feat(peds): pedestrian walk graph from the real map (verges behind kerbs, footways, BE6 plaza ring, campus paths with lobby and back-gap pass-throughs, gates) with campus/residential/road zones, hashed water/building checks, a per-MapData cache and spatial queries

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: `Pedestrian` (wandering, walk profiles, reactions)

**Files:**
- Create: `scripts/roam/Pedestrian.gd`
- Modify: `scripts/CharacterBuilder.gd` (one new branch `"phone_stand"` in `Animator._clip_pose`)
- Create: `tests/support/stub_mover.gd`
- Modify: `tests/test_pedestrians.gd` (part B)

**Interfaces:**
- Consumes:
  - `PedWalkGraph` (Task 9);
  - Task 6 clips (`stumble`, `knockdown`, `getup`) and PS2 expressions (`angry`, `pain`, `open`);
  - the `PlayerBike.tscn` collider (a capsule, r 0.42, height 1.55, lying along Z);
  - `CharacterBuilder._mesh_instances()`.
- Produces (Tasks 11-13):
  - `class_name Pedestrian extends CharacterBody3D`; `enum State { WALK, IDLE, STUMBLE, KNOCKDOWN, FLEE }`; `var state: int`.
  - Walker identity: a Dictionary that survives every tier change. Keys: `preset` (String), `seed` (int, model), `female` (bool, optional), `profile` (`"walk"` | `"jog"` | `"stroll"`, default `"walk"`), `wseed` (int, the walker's own randomness: speed and idle stops; default = `seed`), `wid` (int, unique walker id from the spawner; default -1), `v` (int, crowd variant from `CrowdImpostors.variants()`; default -1). Extra keys (for example `zone`) are kept as they are.
  - `setup(g: PedWalkGraph, node: int, identity: Dictionary) -> void`: the first call builds the capsule and the model. Later calls on a detached (pooled) pedestrian reset only the walker state; the model is rebuilt only when `preset`, `seed` or `female` differ. Call it while the pedestrian is not in the tree.
  - `static func model_opts(identity: Dictionary) -> Dictionary`: the `CharacterBuilder.build` options for an identity. The impostor bake in Task 11 uses the same function, so a walker never changes look.
  - `static func speed_for(profile: String, wseed: int) -> float`: deterministic speed inside `PROFILES[profile]`, where `const PROFILES: Dictionary = {"walk": [1.1, 1.6], "jog": [2.4, 2.8], "stroll": [0.7, 0.9]}`.
  - Members set by the spawner:
    - `player: Node3D`, `bike: Node3D`, `mounted_fn: Callable` (returns bool);
    - `crowd: Array` (shared list of pedestrians), `spawner: Node` (for `request_line`);
    - `lod_far: bool`: mid tier, with no `move_and_slide`, no gravity, no contact checks and no separation. A floor snap every 30 physics frames keeps its height.
    - The spawner switches tiers with `set_far(far: bool)`. This also turns the model's shadows off in the mid tier, and puts the pedestrian back on the floor when it returns to the near tier.
  - Read by the spawner: `identity: Dictionary`, `target_node: int`, `prev_node: int`, `walk_speed: float`, `snap_to_floor() -> void`.
  - `CharacterBuilder.play(model, "phone_stand", t)`: a standing phone pose (arms, head and torso only). The existing `"phone"` clip is a seated pose.
  - Contact with the bike is measured to the axis of its capsule (`BIKE_HALF_AXIS` 0.355), not to its origin. A player or bike slower than 0.5 m/s causes no reaction.
  - Reactions and logs:
    - `react(kind: String, away: Vector3, speed: float) -> void` and signal `hit(ped: Pedestrian, kind: String)`;
    - `hits: Array[String]` (test log) and `stuck_out: bool` (the spawner recycles the pedestrian when true);
    - `PED_LINES: Dictionary` (kind -> Array[String]).

- [ ] **Step 1: Write the failing test (part B)**

In `tests/test_pedestrians.gd` set `const PART_B: bool = true` and add, after `_part_a()` in `_initialize()`:

```gdscript
	if PART_B:
		physics_frame.connect(_on_physics_b)   # phần B đếm khung vật lý (60 Hz), bắt đầu khi gốc đã vào cây
```

(Headless Godot renders about 145 frames a second, so phases must count physics frames, not process frames. Nodes added inside `_initialize()` are not in the tree yet, so part B starts in the first physics frame.) Add these members and functions:

```gdscript
var world_b: Node3D
var ped: Pedestrian
var jogger: Pedestrian
var stub_player: CharacterBody3D
var stub_bike: CharacterBody3D
var mounted: bool = false
var b_started: bool = false
var b_phase: String = ""
var b_t0: int = 0
var b_hits: Array[String] = []
var jog_start: Vector3


func _part_b_start() -> void:
	var rig: Node3D = CharacterBuilder.build({"preset": "student", "seed": 4, "rigged": true, "animate": false})
	var sk: Skeleton3D = rig.get_meta("skeleton", null) as Skeleton3D
	var thigh: int = sk.find_bone("UpperLeg.L")
	var arm: int = sk.find_bone("UpperArm.L")
	CharacterBuilder.pose(rig, "phone_stand")
	var leg_deg: float = rad_to_deg(sk.get_bone_pose_rotation(thigh).angle_to(sk.get_bone_rest(thigh).basis.get_rotation_quaternion()))
	var arm_deg: float = rad_to_deg(sk.get_bone_pose_rotation(arm).angle_to(sk.get_bone_rest(arm).basis.get_rotation_quaternion()))
	rig.free()
	if not _check(leg_deg < 1.0 and arm_deg > 20.0, "phone_stand keeps the legs standing and raises the arms (thigh %.1f°, arm %.1f°)" % [leg_deg, arm_deg]):
		return
	for prof: String in Pedestrian.PROFILES.keys():
		var lim: Array = Pedestrian.PROFILES[prof]
		for s: int in range(20):
			var v: float = Pedestrian.speed_for(prof, s)
			if not _check(v >= float(lim[0]) and v <= float(lim[1]) and v == Pedestrian.speed_for(prof, s), "speed_for(%s, %d) = %.2f must be deterministic and inside %s" % [prof, s, v, str(lim)]):
				return
	world_b = Node3D.new()
	world_b.position = Vector3(0.0, 0.0, 5000.0)   # xa thế giới thật của phần A (không dựng gì ở đây)
	root.add_child(world_b)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(200.0, 1.0, 200.0)
	cs.shape = bs
	sb.add_child(cs)
	sb.position = Vector3(0.0, -0.5, 0.0)
	world_b.add_child(sb)
	# hai đường thẳng 60 m dọc trục X cách nhau 12 m (toạ độ bản đồ = thế giới của world_b): nút 0..10 và 11..21
	var line := PackedVector2Array()
	var line2 := PackedVector2Array()
	for i: int in range(11):
		line.append(Vector2(-30.0 + float(i) * 6.0, 5000.0))
		line2.append(Vector2(-30.0 + float(i) * 6.0, 5012.0))
	var g: PedWalkGraph = PedWalkGraph.from_lines([line, line2])
	stub_player = _stub("StubPlayer", Vector3(40.0, 0.0, 5000.0), 0.4)
	stub_bike = _stub("StubBike", Vector3(-40.0, 0.0, 5000.0), 0.6)
	ped = _ped(g, 5, {"preset": "student", "seed": 11}, Vector3(0.0, 0.05, 5000.0))
	ped.hit.connect(func(_p: Pedestrian, kind: String) -> void: b_hits.append(kind))
	jogger = _ped(g, 16, {"preset": "casual", "seed": 12, "profile": "jog", "wseed": 3}, Vector3(0.0, 0.05, 5012.0))
	jog_start = jogger.global_position
	b_phase = "walk"
	b_t0 = 0


func _ped(g: PedWalkGraph, node: int, ident: Dictionary, at: Vector3) -> Pedestrian:
	var p := Pedestrian.new()
	p.setup(g, node, ident)
	p.player = stub_player
	p.bike = stub_bike
	p.mounted_fn = func() -> bool: return mounted
	root.add_child(p)
	p.global_position = at
	return p


func _stub(name: String, at: Vector3, r: float) -> CharacterBody3D:
	var s := CharacterBody3D.new()
	s.name = name
	s.set_script(load("res://tests/support/stub_mover.gd"))
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = r
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0.0, 0.85, 0.0)
	s.add_child(cs)
	s.collision_layer = 0   # chỉ đo khoảng cách, không đẩy người đi đường
	root.add_child(s)
	s.global_position = at
	return s


func _on_physics_b() -> void:
	if done:
		return
	if not b_started:
		b_started = true
		_part_b_start()
		return
	if b_phase == "":
		return
	frames += 1
	var t: int = frames - b_t0
	match b_phase:
		"walk":
			if t == 90:   # 1.5 s
				var moved: float = Vector2(ped.global_position.x, ped.global_position.z - 5000.0).length()
				var jogged: float = jogger.global_position.distance_to(jog_start)
				print("  pedestrian walked %.2f m in 1.5 s (state %d), jogger %.2f m" % [moved, ped.state, jogged])
				if not _check(moved > 1.2 and ped.state == Pedestrian.State.WALK, "a pedestrian must walk along the graph (moved %.2f m)" % moved):
					return
				if not _check(jogged > 2.9 and jogger.state == Pedestrian.State.WALK, "a jogger must cover > 2.9 m in 1.5 s (got %.2f m)" % jogged):
					return
				stub_player.set("speed_value", 3.0)
				stub_player.global_position = ped.global_position + Vector3(0.65, 0.0, 0.0)
				b_phase = "bump"
				b_t0 = frames
		"bump":
			if t == 3:
				print("  bump -> state %d, hits %s" % [ped.state, b_hits])
				if not _check(ped.state == Pedestrian.State.STUMBLE and b_hits.size() == 1 and b_hits[0] == "bump", "a walking bump (3 m/s) must give STUMBLE and one 'bump' hit"):
					return
				stub_player.global_position = Vector3(40.0, 0.0, 5000.0)
			if t == 80:   # 1.33 s: hết hồi 1 s và lảo đảo 0.8 s
				stub_player.set("speed_value", 7.0)
				stub_player.global_position = ped.global_position + Vector3(0.65, 0.0, 0.0)
				b_phase = "sprint"
				b_t0 = frames
		"sprint":
			if t == 3:
				if not _check(ped.state == Pedestrian.State.KNOCKDOWN and b_hits.back() == "sprint", "a sprint hit (7 m/s) must give KNOCKDOWN"):
					return
				stub_player.global_position = Vector3(40.0, 0.0, 5000.0)
			if t == 180:   # 3 s (ngã 1.2 s + đứng dậy 0.9 s)
				print("  after knockdown: state %d" % ped.state)
				if not _check(ped.state == Pedestrian.State.FLEE or ped.state == Pedestrian.State.WALK, "a knocked-down pedestrian walks again within 3 s (state %d)" % ped.state):
					return
				mounted = true
				stub_bike.set("speed_value", 6.0)
				stub_bike.global_position = ped.global_position + Vector3(-0.8, 0.0, 0.0)
				b_phase = "bike"
				b_t0 = frames
		"bike":
			if t == 3:
				print("  bike hit -> state %d, hits %s" % [ped.state, b_hits])
				if not _check(ped.state == Pedestrian.State.KNOCKDOWN and b_hits.back() == "bike", "a bike hit above 3 m/s must give KNOCKDOWN with kind 'bike'"):
					return
				mounted = false
				stub_bike.global_position = Vector3(-40.0, 0.0, 5000.0)
				jogger.set_far(true)
				stub_player.set("speed_value", 7.0)
				stub_player.global_position = jogger.global_position + Vector3(0.65, 0.0, 0.0)
				b_phase = "mid"
				b_t0 = frames
		"mid":
			if t == 3:
				print("  mid-tier contact -> jogger hits %s, state %d" % [jogger.hits, jogger.state])
				if not _check(jogger.hits.is_empty() and jogger.state == Pedestrian.State.WALK, "a mid-tier pedestrian (lod_far) makes no contact checks"):
					return
				stub_player.global_position = Vector3(40.0, 0.0, 5000.0)
				if not PART_C:
					print("✅ SUCCESS: PEDESTRIANS (parts A + B)")
					done = true
					quit(0)
```

Create the tiny stub script `tests/support/stub_mover.gd`. It is a body whose speed the test sets; the pedestrian reads `horizontal_speed` from a player and `current_speed_ms` from a bike:

```gdscript
# File: res://tests/support/stub_mover.gd
# Thân giả cho test người đi đường / xe chạy: speed_value đóng vai horizontal_speed (người chơi) và current_speed_ms (xe).
extends CharacterBody3D

var speed_value: float = 0.0
var horizontal_speed: float:
	get:
		return speed_value
var current_speed_ms: float:
	get:
		return speed_value
	set(v):
		speed_value = v
```

Run: `godot --headless --path . --script tests/test_pedestrians.gd > /tmp/t10.log 2>&1; grep -E "SUCCESS|FAILED|Identifier" /tmp/t10.log`
Expected: `Identifier "Pedestrian" not declared in the current scope.`

- [ ] **Step 2: Implement**

In `scripts/CharacterBuilder.gd`, inside `Animator._clip_pose`, add this branch to the `match name:` block, next to `"sleepy"`. The existing `"phone"` clip shares the seated branch (thighs up, hips lowered), so a standing pedestrian needs its own pose with only the arm, head and torso keys:

```gdscript
			"phone_stand":   # đứng xem điện thoại (người đi đường dừng chân): tay, đầu, thân như "phone"; chân để nguyên
				p["shoulder_l"] = Vector3(0.95, 0.0, 0.18)
				p["shoulder_r"] = Vector3(0.95, 0.0, -0.18)
				p["elbow_l"] = Vector3(1.25, -0.35, 0.0)
				p["elbow_r"] = Vector3(1.25, 0.35, 0.0)
				p["head"] = Vector3(-0.55, 0.0, 0.0)
				p["torso"] = Vector3(-0.12, 0.0, 0.0)
```

Create `scripts/roam/Pedestrian.gd`:

```gdscript
# File: res://scripts/roam/Pedestrian.gd
# Người đi đường FreeRoam: thân CharacterBuilder (rigged; đầu PS2 ở phong cách Vice City), đi theo PedWalkGraph với kiểu
# đi walk / jog / stroll, thỉnh thoảng đứng lại; tự đo va chạm với người chơi (đi bộ) / xe (khi cưỡi) bằng khoảng cách và
# phản ứng: va nhẹ -> STUMBLE (lảo đảo, né 0.6 m), nước rút > 6 m/s -> KNOCKDOWN (ngã rồi đứng dậy, bỏ chạy),
# xe > 3 m/s -> KNOCKDOWN văng 2..4 m; mỗi lần một câu càu nhàu (spawner giới hạn nhịp). Không phạt gì.
# Tầng giữa (lod_far, PedestrianSpawner đặt): trượt theo đồ thị không vật lý, không đo va chạm, không tách đám.
# Danh tính (identity) giữ nguyên khi đổi tầng: preset / seed / female quyết định mô hình (model_opts), profile / wseed
# quyết định cách đi. Không dùng autoload ở đây (class_name biên dịch trước autoload khi chạy test --script).
class_name Pedestrian
extends CharacterBody3D

signal hit(ped: Pedestrian, kind: String)

enum State { WALK, IDLE, STUMBLE, KNOCKDOWN, FLEE }

const RADIUS: float = 0.28
const HEIGHT: float = 1.7
const GRAVITY: float = 20.0
## Khoảng tốc độ (m/s) theo kiểu đi (spec Amendment: người chạy bộ ~2.5 m/s, người tản bộ ~0.8 m/s).
const PROFILES: Dictionary = {"walk": [1.1, 1.6], "jog": [2.4, 2.8], "stroll": [0.7, 0.9]}
const FLEE_SPEED: float = 3.2
const STUMBLE_TIME: float = 0.8
const STUMBLE_DECEL: float = 6.0
const FALL_TIME: float = 1.2
const GETUP_TIME: float = 0.9
const FLEE_TIME: float = 3.0
const THROW_TIME: float = 0.5
const THROW_KEEP: float = 0.75           # tốc văng = quãng / THROW_TIME x 0,75, rồi hãm THROW_DECEL: tổng ~ quãng văng
const THROW_DECEL: float = 16.0
const HIT_COOLDOWN: float = 1.0
const SIDESTEP_M: float = 0.6
const STUCK_TIME: float = 3.0
const STUCK_RECYCLE: float = 10.0
const SEPARATION_R: float = 1.2
const SEPARATION_EVERY: int = 4          # tính lực tách đám mỗi 4 khung vật lý (lệch pha theo wseed)
const SNAP_EVERY: int = 30               # tầng giữa: đặt lại lên mặt sàn mỗi 30 khung vật lý
const STEP_HEIGHT: float = 0.35          # bậc lề 0,12-0,15 m, bậc sân campus tới 0,32 m (như ThirdPersonController)
const PLAYER_RADIUS: float = 0.4
const BIKE_RADIUS: float = 0.6
const BIKE_HALF_AXIS: float = 0.355      # PlayerBike.tscn: capsule r 0,42 cao 1,55 nằm dọc Z -> trục ±0,355 m quanh gốc xe
const MIN_HIT_SPEED: float = 0.5         # người chơi / xe gần như đứng yên: người đi đường tự né, không phản ứng
const SPRINT_HIT_SPEED: float = 6.0
const BIKE_HIT_SPEED: float = 3.0
const IDLE_CHANCE: float = 0.1
const ARRIVE_R: float = 0.6
const PED_LINES: Dictionary = {
	"bump": ["Ê, nhìn đường chứ bạn!", "Đi đứng kiểu gì vậy trời…", "Từ từ thôi, trễ học hả?", "Xin lỗi một tiếng coi!"],
	"sprint": ["Chạy deadline hả em?!", "Ối giời ơi, đụng người ta rồi!", "Thanh niên gì mà hấp tấp vậy!", "Điểm danh trễ cũng đâu cần chạy vậy!"],
	"bike": ["Trời đất ơi, chạy xe kiểu gì vậy!", "Có bằng lái không đó?!", "Đi chậm lại giùm cái!", "Gọi bảo vệ bây giờ!"],
}

var graph: PedWalkGraph
var model: Node3D
var identity: Dictionary = {}
var state: int = State.WALK
var walk_speed: float = 1.3
var target_node: int = -1
var prev_node: int = -1
var player: Node3D
var bike: Node3D
var mounted_fn: Callable
var crowd: Array = []
var spawner: Node
var lod_far: bool = false
var hits: Array[String] = []
var stuck_out: bool = false
var _t: float = 0.0
var _cool: float = 0.0
var _stuck_t: float = 0.0
var _stuck_total: float = 0.0
var _last_pos: Vector3
var _has_last: bool = false
var _throw_v: Vector3 = Vector3.ZERO
var _away: Vector3 = Vector3.ZERO
var _getting_up: bool = false
var _idle_left: float = 0.0
var _walked: int = 0
var _sep: Vector3 = Vector3.ZERO
var _sep_phase: int = 0
var _rng := RandomNumberGenerator.new()


## Tuỳ chọn CharacterBuilder.build() của một danh tính (dùng chung với bake người nộm của CrowdImpostors).
static func model_opts(ident: Dictionary) -> Dictionary:
	var o: Dictionary = {"preset": String(ident.get("preset", "student")), "seed": int(ident.get("seed", 0)), "rigged": true}
	if ident.has("female"):
		o["female"] = bool(ident["female"])
	return o


## Tốc độ đi (m/s) theo kiểu đi và wseed – cố định, nên người nộm và người đi đường cùng danh tính đi cùng tốc độ.
static func speed_for(profile: String, wseed: int) -> float:
	var lim: Array = PROFILES.get(profile, PROFILES["walk"])
	var r := RandomNumberGenerator.new()
	r.seed = wseed * 7919 + 17
	return r.randf_range(float(lim[0]), float(lim[1]))


## Dựng (lần đầu) hoặc đặt lại (người trong pool của spawner) một người đi đường; gọi khi chưa ở trong cây.
## Mô hình chỉ dựng lại khi preset / seed / female khác mô hình đang có.
func setup(g: PedWalkGraph, node: int, ident: Dictionary) -> void:
	graph = g
	identity = ident.duplicate()
	identity["profile"] = String(identity.get("profile", "walk"))
	identity["wseed"] = int(identity.get("wseed", int(identity.get("seed", 0))))
	identity["wid"] = int(identity.get("wid", -1))
	identity["v"] = int(identity.get("v", -1))
	_rng.seed = int(identity["wseed"])
	walk_speed = speed_for(String(identity["profile"]), int(identity["wseed"]))
	_sep_phase = int(identity["wseed"]) % SEPARATION_EVERY
	prev_node = node
	target_node = node
	state = State.WALK
	velocity = Vector3.ZERO
	hits.clear()
	stuck_out = false
	lod_far = false
	collision_layer = 1
	_t = 0.0
	_cool = 0.0
	_stuck_t = 0.0
	_stuck_total = 0.0
	_has_last = false
	_throw_v = Vector3.ZERO
	_getting_up = false
	_walked = 0
	_sep = Vector3.ZERO
	floor_snap_length = 0.4
	if get_node_or_null("Capsule") == null:
		var cs := CollisionShape3D.new()
		cs.name = "Capsule"
		var cap := CapsuleShape3D.new()
		cap.radius = RADIUS
		cap.height = HEIGHT
		cs.shape = cap
		cs.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
		add_child(cs)
	var key: String = "%s|%d|%s" % [String(identity.get("preset", "student")), int(identity.get("seed", 0)), str(identity.get("female", "-"))]
	if model != null and String(model.get_meta("ped_key", "")) == key:
		CharacterBuilder.stop_clip(model)
		CharacterBuilder.set_expression(model, "open")
		CharacterBuilder.set_speed(model, 0.0)
		_shadows(true)
		return
	if model != null:
		model.free()
	var o: Dictionary = model_opts(identity)
	o["name"] = "Model"
	model = CharacterBuilder.build(o)
	model.set_meta("ped_key", key)
	add_child(model)


## Đổi tầng (PedestrianSpawner): tầng giữa không vật lý, không va chạm, không đổ bóng; về tầng gần thì đặt lại lên sàn.
func set_far(far: bool) -> void:
	if far == lod_far:
		return
	lod_far = far
	_shadows(not far)
	if not far:
		snap_to_floor()


## Đặt lại độ cao lên mặt sàn ngay dưới chân (về tầng gần, và định kỳ ở tầng giữa).
func snap_to_floor() -> void:
	if not is_inside_tree():
		return
	var rq := PhysicsRayQueryParameters3D.create(global_position + Vector3(0.0, 1.0, 0.0), global_position - Vector3(0.0, 1.5, 0.0))
	rq.exclude = [get_rid()]
	rq.collide_with_areas = false
	var hit_info: Dictionary = get_world_3d().direct_space_state.intersect_ray(rq)
	if not hit_info.is_empty():
		global_position.y = (hit_info["position"] as Vector3).y + 0.02
		velocity.y = 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	_cool = maxf(0.0, _cool - delta)
	match state:
		State.WALK, State.FLEE:
			_walk(delta)
		State.IDLE:
			_idle(delta)
		State.STUMBLE:
			_stumble(delta)
		State.KNOCKDOWN:
			_knockdown(delta)
	_check_contacts()


# ---------------------------------------------------------------------------
# VA CHẠM
# ---------------------------------------------------------------------------
func _check_contacts() -> void:
	if lod_far or _cool > 0.0 or state == State.KNOCKDOWN:
		return
	var mounted: bool = bool(mounted_fn.call()) if mounted_fn.is_valid() else false
	var other: Node3D = bike if mounted else player
	if other == null or not other.is_inside_tree():
		return
	var r: float = (BIKE_RADIUS if mounted else PLAYER_RADIUS) + RADIUS + 0.05
	var d := Vector2(global_position.x - other.global_position.x, global_position.z - other.global_position.z)
	if mounted:
		# xe máy là capsule nằm dọc hướng xe: đo tới đoạn trục của nó, không tới gốc (đầu xe nhô 0,78 m trước gốc)
		var f3: Vector3 = -other.global_basis.z
		var f := Vector2(f3.x, f3.z).normalized()
		d -= f * clampf(d.dot(f), -BIKE_HALF_AXIS, BIKE_HALF_AXIS)
	if d.length() > r or absf(global_position.y - other.global_position.y) > 1.2:
		return
	var speed: float = absf(float(other.get("current_speed_ms")) if mounted else float(other.get("horizontal_speed")))
	if speed < MIN_HIT_SPEED:
		return
	var away: Vector3 = Vector3(d.x, 0.0, d.y).normalized() if d.length() > 0.01 else Vector3.FORWARD
	var kind: String
	if mounted:
		kind = "bike" if speed > BIKE_HIT_SPEED else "bump"
	else:
		kind = "sprint" if speed > SPRINT_HIT_SPEED else "bump"
	_cool = HIT_COOLDOWN
	react(kind, away, speed)
	hit.emit(self, kind)


func react(kind: String, away: Vector3, speed: float) -> void:
	hits.append(kind)
	_away = away
	_t = 0.0
	if kind == "bump":
		state = State.STUMBLE
		var v0: float = sqrt(2.0 * STUMBLE_DECEL * SIDESTEP_M)   # trượt ngang đúng SIDESTEP_M rồi dừng
		velocity.x = away.x * v0
		velocity.z = away.z * v0
		CharacterBuilder.play(model, "stumble")
		CharacterBuilder.set_expression(model, "angry")
	else:
		state = State.KNOCKDOWN
		_getting_up = false
		var throw: float = clampf(2.0 + (speed - BIKE_HIT_SPEED) * 0.25, 2.0, 4.0) if kind == "bike" else 0.8
		_throw_v = away * (throw / THROW_TIME * THROW_KEEP) + Vector3(0.0, 3.0 if kind == "bike" else 0.0, 0.0)
		model.rotation.y = atan2(away.x, away.z)   # nhìn về phía cú va: ngã ngửa ra xa nó
		collision_layer = 0                         # đang ngã: xe / người đi qua được
		CharacterBuilder.play(model, "knockdown")
		CharacterBuilder.set_expression(model, "pain")
	if spawner and spawner.has_method("request_line"):
		spawner.request_line(self, kind)


# ---------------------------------------------------------------------------
# TRẠNG THÁI
# ---------------------------------------------------------------------------
func _walk(delta: float) -> void:
	if target_node < 0 or graph == null or graph.node_count() == 0:
		state = State.IDLE
		_idle_left = 2.0
		return
	var tp: Vector3 = graph.node_pos(target_node)
	var to := Vector3(tp.x - global_position.x, 0.0, tp.z - global_position.z)
	if to.length() < ARRIVE_R:
		_arrive()
		return
	if not lod_far and (Engine.get_physics_frames() + _sep_phase) % SEPARATION_EVERY == 0:
		_sep = _separation()
	var dir: Vector3 = (to.normalized() + (Vector3.ZERO if lod_far else _sep * 0.8)).normalized()
	var sp: float = FLEE_SPEED if state == State.FLEE else walk_speed
	velocity.x = dir.x * sp
	velocity.z = dir.z * sp
	if lod_far:
		velocity.y = 0.0
		global_position += Vector3(velocity.x, 0.0, velocity.z) * delta
		if (Engine.get_physics_frames() + _sep_phase * 7) % SNAP_EVERY == 0:
			snap_to_floor()
	else:
		_gravity(delta)
		if is_on_wall():
			_try_step_up(dir, delta)
		move_and_slide()
	_face(dir, delta)
	CharacterBuilder.set_speed(model, sp)
	_stuck_check(delta)
	if state == State.FLEE and _t >= FLEE_TIME:
		state = State.WALK


func _arrive() -> void:
	var nxt: int = graph.next_node(target_node, prev_node, _rng)
	prev_node = target_node
	target_node = nxt
	_walked += 1
	# không dừng ở nút đầu tiên (vừa xuất hiện); người chạy bộ không dừng
	if state == State.WALK and _walked > 1 and String(identity.get("profile", "walk")) != "jog" and _rng.randf() < IDLE_CHANCE:
		state = State.IDLE
		_idle_left = _rng.randf_range(2.0, 6.0)
		CharacterBuilder.set_speed(model, 0.0)
		if _rng.randf() < 0.5:
			CharacterBuilder.play(model, "phone_stand", _idle_left)


func _idle(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if lod_far:
		velocity.y = 0.0
	else:
		_gravity(delta)
		move_and_slide()
	_idle_left -= delta
	if _idle_left <= 0.0:
		CharacterBuilder.stop_clip(model)
		state = State.WALK


func _stumble(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, STUMBLE_DECEL * delta)
	velocity.z = move_toward(velocity.z, 0.0, STUMBLE_DECEL * delta)
	_gravity(delta)
	move_and_slide()
	CharacterBuilder.set_speed(model, 0.0)
	if _t >= STUMBLE_TIME:
		state = State.WALK
		CharacterBuilder.set_expression(model, "open")


func _knockdown(delta: float) -> void:
	_gravity(delta)
	if _t < THROW_TIME:
		velocity.x = _throw_v.x
		velocity.z = _throw_v.z
		if _throw_v.y > 0.0 and _t < delta * 1.5:
			velocity.y = _throw_v.y   # đặt sau _gravity: đang chạm đất vẫn bật lên được (cú văng của xe)
	else:
		velocity.x = move_toward(velocity.x, 0.0, THROW_DECEL * delta)
		velocity.z = move_toward(velocity.z, 0.0, THROW_DECEL * delta)
	move_and_slide()
	CharacterBuilder.set_speed(model, 0.0)
	if _t >= FALL_TIME and not _getting_up:
		_getting_up = true
		CharacterBuilder.play(model, "getup")
	if _t >= FALL_TIME + GETUP_TIME:
		_getting_up = false
		_throw_v = Vector3.ZERO
		collision_layer = 1
		state = State.FLEE
		_t = 0.0
		CharacterBuilder.stop_clip(model)
		CharacterBuilder.set_expression(model, "open")
		# bỏ chạy: chọn nút kề xa người chơi nhất
		if graph and target_node >= 0:
			var best: int = target_node
			var best_d: float = -1.0
			var src: Node3D = player if player else self
			for v: int in graph.neighbours(target_node):
				var d: float = graph.node_pos(v).distance_to(src.global_position)
				if d > best_d:
					best_d = d
					best = v
			prev_node = target_node
			target_node = best


# ---------------------------------------------------------------------------
# PHỤ TRỢ
# ---------------------------------------------------------------------------
func _gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
	else:
		velocity.y -= GRAVITY * delta


func _face(dir: Vector3, delta: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	model.rotation.y = lerp_angle(model.rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * 8.0))


## Bước lên bậc thấp khi đang bị chặn (lề, bậc sân campus), như ThirdPersonController._try_step_up.
func _try_step_up(dir: Vector3, delta: float) -> void:
	var motion: Vector3 = Vector3(velocity.x, 0.0, velocity.z) * delta
	if motion.length_squared() < 0.000001:
		return
	var xf: Transform3D = global_transform
	if not test_move(xf, motion):
		return
	var up := Vector3(0.0, STEP_HEIGHT + 0.03, 0.0)
	if test_move(xf, up):
		return
	var probe: Vector3 = motion + dir * 0.12
	var raised: Transform3D = xf.translated(up)
	if test_move(raised, probe):
		return
	var col := KinematicCollision3D.new()
	if not test_move(raised.translated(probe), Vector3(0.0, -(STEP_HEIGHT + 0.06), 0.0), col):
		return
	if col.get_normal().y < 0.7:
		return
	var step_h: float = up.y + col.get_travel().y
	if step_h > 0.02 and step_h <= STEP_HEIGHT + 0.03:
		global_position.y += step_h + 0.01


## Bật / tắt bóng đổ của mô hình (tầng giữa tắt), nhớ cài đặt gốc của từng mesh.
func _shadows(on: bool) -> void:
	if model == null:
		return
	for mi: MeshInstance3D in CharacterBuilder._mesh_instances(model):
		if not mi.has_meta("ped_cast"):
			mi.set_meta("ped_cast", mi.cast_shadow)
		var orig: GeometryInstance3D.ShadowCastingSetting = mi.get_meta("ped_cast")
		mi.cast_shadow = orig if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _separation() -> Vector3:
	var push := Vector3.ZERO
	for o: Variant in crowd:
		if o == self or not is_instance_valid(o):
			continue
		var on: Pedestrian = o
		if on.lod_far:
			continue
		var d := Vector3(global_position.x - on.global_position.x, 0.0, global_position.z - on.global_position.z)
		var l: float = d.length()
		if l > 0.01 and l < SEPARATION_R:
			push += d / l * (1.0 - l / SEPARATION_R)
	if player and player.is_inside_tree():
		var dp := Vector3(global_position.x - player.global_position.x, 0.0, global_position.z - player.global_position.z)
		var lp: float = dp.length()
		if lp > 0.01 and lp < SEPARATION_R * 1.5:
			push += dp / lp * (1.0 - lp / (SEPARATION_R * 1.5))
	return push


func _stuck_check(delta: float) -> void:
	if not _has_last:
		_has_last = true
		_last_pos = global_position
		_stuck_t = 0.0
		return
	_stuck_t += delta
	if _stuck_t < STUCK_TIME:
		return
	var moved: float = global_position.distance_to(_last_pos)
	_last_pos = global_position
	_stuck_t = 0.0
	if moved < 0.15:
		_stuck_total += STUCK_TIME
		var alt: int = graph.next_node(target_node, -1, _rng)
		prev_node = target_node
		target_node = alt
		if _stuck_total >= STUCK_RECYCLE:
			stuck_out = true
	else:
		_stuck_total = 0.0
	if global_position.y < -20.0:
		stuck_out = true
```

Run: `godot --headless --import --path . > /tmp/imp.log 2>&1; grep -c "Pedestrian" .godot/global_script_class_cache.cfg` — expected ≥ 2.

- [ ] **Step 3: Run the test to verify it passes**

Run: `godot --headless --path . --script tests/test_pedestrians.gd > /tmp/t10.log 2>&1; grep -E "pedestrian walked|bump|after knockdown|bike hit|mid-tier|SUCCESS|FAILED" /tmp/t10.log`
Expected: the five diagnostics, then `✅ SUCCESS: PEDESTRIANS (parts A + B)`.

- [ ] **Step 4: Regression and commit**

Run the regression command (all green), then:

```bash
git add scripts/roam/Pedestrian.gd scripts/CharacterBuilder.gd tests/test_pedestrians.gd tests/support/stub_mover.gd
git commit -m "feat(peds): Pedestrian - walk/jog/stroll profiles with a stable identity, wanders the walk graph with step-ups, mid tier without physics or shadows, bumps/sprint hits/bike hits measured to the bike capsule, stumbles or falls and gets up, standing phone pose, mild fictional complaints

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: `CrowdImpostors` (far crowd tier) and the static "stride" pose

**Files:**
- Create: `scripts/roam/CrowdImpostors.gd`
- Modify: `scripts/CharacterBuilder.gd` (one new branch `"stride"` in `Animator._clip_pose`)
- Create: `tests/test_crowd_impostors.gd`

**Interfaces:**
- Consumes: `PedWalkGraph` (Task 9), `Pedestrian.model_opts()` (Task 10), `CharacterBuilder.build/pose/bake` (Task 4).
- Produces (Task 12):
  - `CharacterBuilder.pose(root, "stride")`: a frozen walking stride (front thigh forward, back thigh back, arms swung against the legs), on code bodies and rigged bodies.
  - Variant table:
    - `CrowdImpostors.VARIANTS_PER_ZONE = 8` and `ZONE_PRESETS`;
    - `static func variants() -> Array`: 24 fixed identities `{"v", "zone", "preset", "seed", "female"}`, where the index equals `v`;
    - `static func bake_variant(identity) -> Array`: returns `[ArrayMesh, Vector3 root scale]`.
  - `setup(g: PedWalkGraph, opts := {})` with opts `cap` (default 200) and `seed`. It gives each variant one `MultiMeshInstance3D` (shadows off) and records `bake_ms`.
    - The 24 bakes are cached statically per art style, so re-entering FreeRoam costs nothing.
    - Every instance is lowered by its variant's lowest point, so the lifted stride feet touch the ground.
  - Adding and reading impostors:
    - `add(state: Dictionary) -> bool`. The state has `wid`, `identity` (with `v`), `node` (the node being walked to), `prev`, `pos` and `speed`. It returns false at the cap or for an unknown variant.
    - `count() -> int`, `state_at(i) -> Dictionary` (the same keys plus `yaw`), `positions() -> PackedVector3Array`, `wids() -> PackedInt32Array`.
  - Moving and drawing: `step(dt: float)` moves impostors along graph edges (`_physics_process` calls it at 10 Hz), and `flush()` writes the MultiMesh transforms.
  - Removing impostors:
    - `take_within(center: Vector3, r: float, max_n: int, pred: Callable = Callable()) -> Array` removes up to max_n impostors within r and returns their states, closest first. When `pred` is given, it takes only impostors whose `pred(pos)` is true;
    - `remove_where(pred: Callable) -> int` uses `pred(pos: Vector3) -> bool`;
    - `remove_farthest(center: Vector3, n: int) -> int`.
  - Test accessors: `multimesh(v) -> MultiMesh`, `variant_mesh(v) -> ArrayMesh`, `variant_scale(v) -> Vector3`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_crowd_impostors.gd`:

```gdscript
# File: res://tests/test_crowd_impostors.gd
# Test headless tầng xa của đám đông FreeRoam (CrowdImpostors, plan Task 11): 24 biến thể cố định (3 khu x 8), clip tĩnh
# "stride" (hai gối tách trước / sau), mỗi biến thể bake thành người cao 1,3-2,0 m với một MultiMesh cỡ bằng trần, người
# nộm trượt theo cạnh đồ thị, số instance hiện = số người nộm, take_within (gần trước, giữ danh tính), remove_where,
# remove_farthest, trần.
# Chạy:  godot --headless --path . --script tests/test_crowd_impostors.gd
extends SceneTree

var done: bool = false


func _initialize() -> void:
	CharacterBuilder.ps2 = true      # mặc định của game là vice (người PS2); test --script không có GameFX
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	if not _variants_ok() or not _stride_ok() or not _crowd_ok():
		return
	print("✅ SUCCESS: CROWD IMPOSTORS")
	done = true
	quit(0)


func _variants_ok() -> bool:
	var vs: Array = CrowdImpostors.variants()
	if not _check(vs.size() == 24, "24 crowd variants (got %d)" % vs.size()):
		return false
	var students_campus: int = 0
	var females: int = 0
	for i: int in range(vs.size()):
		var v: Dictionary = vs[i]
		var zone_want: int = int(float(i) / float(CrowdImpostors.VARIANTS_PER_ZONE))
		if not _check(int(v["v"]) == i and int(v["zone"]) == zone_want, "variant %d has v %d zone %d" % [i, int(v["v"]), int(v["zone"])]):
			return false
		if int(v["zone"]) == PedWalkGraph.ZONE_CAMPUS and String(v["preset"]) == "student":
			students_campus += 1
		if bool(v["female"]):
			females += 1
	if not _check(students_campus == 7 and females == 12, "campus: 7 student variants (got %d); 12 female variants (got %d)" % [students_campus, females]):
		return false
	return _check(str(CrowdImpostors.variants()) == str(vs), "variants() returns the same table every call")


func _stride_ok() -> bool:
	var rig: Node3D = CharacterBuilder.build({"preset": "student", "seed": 3, "rigged": true, "animate": false})
	var sk: Skeleton3D = rig.get_meta("skeleton", null) as Skeleton3D
	if not _check(sk != null, "a rigged body exposes its skeleton (meta 'skeleton')"):
		return false
	var kl0: Vector3 = CharacterBuilder._bone_global_now(sk, sk.find_bone("LowerLeg.L")).origin
	var kr0: Vector3 = CharacterBuilder._bone_global_now(sk, sk.find_bone("LowerLeg.R")).origin
	CharacterBuilder.pose(rig, "stride")
	var kl: Vector3 = CharacterBuilder._bone_global_now(sk, sk.find_bone("LowerLeg.L")).origin
	var kr: Vector3 = CharacterBuilder._bone_global_now(sk, sk.find_bone("LowerLeg.R")).origin
	rig.free()
	print("  stride: knee gap along Z %.2f (rest %.2f, model units)" % [absf(kl.z - kr.z), absf(kl0.z - kr0.z)])
	return _check(absf(kl.z - kr.z) > 0.2 and absf(kl0.z - kr0.z) < 0.05, "the stride pose splits the legs front/back (knee gap %.2f, rest %.2f)" % [absf(kl.z - kr.z), absf(kl0.z - kr0.z)])


func _crowd_ok() -> bool:
	var line := PackedVector2Array()
	for i: int in range(21):
		line.append(Vector2(-60.0 + float(i) * 6.0, 7000.0))
	var g: PedWalkGraph = PedWalkGraph.from_lines([line])
	var imp := CrowdImpostors.new()
	root.add_child(imp)
	imp.setup(g, {"cap": 40, "seed": 5})
	print("  baked 24 variants in %d ms" % imp.bake_ms)
	if not _check(imp.bake_ms < 8000, "baking 24 variants must take < 8 s headless (took %d ms)" % imp.bake_ms):
		return false
	for v: int in range(24):
		var m: ArrayMesh = imp.variant_mesh(v)
		var h: float = m.get_aabb().size.y * imp.variant_scale(v).y if m else 0.0
		# nữ thấp hơn (hệ số 0,88-1,01) và tư thế sải chân nhấc hai bàn chân ~0,1 m: 1,3-2,0 m
		if not _check(m != null and m.get_surface_count() > 0 and h > 1.3 and h < 2.0, "variant %d bakes a 1.3-2.0 m person (height %.2f)" % [v, h]):
			return false
		if not _check(imp.multimesh(v).mesh == m and imp.multimesh(v).instance_count == 40, "variant %d: one MultiMesh sized to the cap" % v):
			return false
	var vs: Array = CrowdImpostors.variants()
	if not _check(not imp.add({"wid": 1, "identity": {"v": 99}, "node": 1, "prev": 0, "pos": g.node_pos(0), "speed": 1.0}), "add() refuses an unknown variant"):
		return false
	for k: int in range(30):
		var ident: Dictionary = (vs[k % 24] as Dictionary).duplicate()
		ident["wid"] = 100 + k
		var node: int = 2 + (k % 17)
		if not _check(imp.add({"wid": 100 + k, "identity": ident, "node": node + 1, "prev": node, "pos": g.node_pos(node), "speed": 1.3}), "add() below the cap"):
			return false
	var start: PackedVector3Array = imp.positions().duplicate()   # mảng đóng gói dùng chung tham chiếu: phải chép
	imp.step(1.0)
	imp.step(1.0)
	var moved_ok: int = 0
	for i: int in range(imp.count()):
		var p: Vector3 = imp.positions()[i]
		if not _check(absf(p.z - 7000.0) < 0.01, "impostor %d left the walk line (z %.2f)" % [i, p.z]):
			return false
		if absf(p.distance_to(start[i]) - 2.6) < 0.05:
			moved_ok += 1
	if not _check(moved_ok == 30, "every impostor glides 2.6 m in 2 s at 1.3 m/s (%d / 30)" % moved_ok):
		return false
	imp.flush()
	var vis: int = 0
	for v2: int in range(24):
		vis += imp.multimesh(v2).visible_instance_count
	if not _check(vis == 30, "visible instances %d == impostors 30" % vis):
		return false
	var center := Vector3(0.0, 0.0, 7000.0)
	var before: int = imp.count()
	var got: Array = imp.take_within(center, 20.0, 5)
	var last_d: float = -1.0
	for st: Dictionary in got:
		var d: float = (st["pos"] as Vector3).distance_to(center)
		if not _check(d <= 20.0 and d >= last_d, "take_within returns states within 20 m, closest first (%.1f after %.1f)" % [d, last_d]):
			return false
		last_d = d
		var w: int = int(st["wid"])
		if not _check(w == int((st["identity"] as Dictionary)["wid"]) and imp.wids().find(w) < 0, "a taken impostor keeps its identity and leaves the crowd (wid %d)" % w):
			return false
	if not _check(got.size() == 5 and imp.count() == before - 5, "take_within took 5 (got %d), count %d -> %d" % [got.size(), before, imp.count()]):
		return false
	var only_east: Array = imp.take_within(center, 60.0, 3, func(q: Vector3) -> bool: return q.x > 0.0)
	for st2: Dictionary in only_east:
		if not _check((st2["pos"] as Vector3).x > 0.0, "take_within with a predicate returned an impostor at x %.1f" % (st2["pos"] as Vector3).x):
			return false
	var cut: int = imp.remove_where(func(q: Vector3) -> bool: return q.x > 30.0)
	for q2: Vector3 in imp.positions():
		if not _check(q2.x <= 30.0, "remove_where left an impostor at x %.1f" % q2.x):
			return false
	var far_before: float = 0.0
	for q3: Vector3 in imp.positions():
		far_before = maxf(far_before, q3.distance_to(center))
	var n_before: int = imp.count()
	imp.remove_farthest(center, 3)
	var far_after: float = 0.0
	for q4: Vector3 in imp.positions():
		far_after = maxf(far_after, q4.distance_to(center))
	print("  remove_where cut %d; remove_farthest: %d -> %d, farthest %.1f -> %.1f m" % [cut, n_before, imp.count(), far_before, far_after])
	if not _check(imp.count() == n_before - 3 and far_after < far_before, "remove_farthest removes the 3 farthest"):
		return false
	while imp.count() < 40:
		imp.add({"wid": 999, "identity": vs[0], "node": 1, "prev": 0, "pos": g.node_pos(0), "speed": 1.0})
	if not _check(not imp.add({"wid": 1000, "identity": vs[0], "node": 1, "prev": 0, "pos": g.node_pos(0), "speed": 1.0}), "add() refuses beyond the cap"):
		return false
	imp.queue_free()
	return true


func _check(ok: bool, msg: String) -> bool:
	if not ok and not done:
		done = true
		print("❌ FAILED: ", msg)
		quit(2)
	return ok
```

Run: `godot --headless --path . --script tests/test_crowd_impostors.gd > /tmp/t11.log 2>&1; grep -E "SUCCESS|FAILED|Identifier" /tmp/t11.log`
Expected: `Identifier "CrowdImpostors" not declared in the current scope.`

- [ ] **Step 2: The static "stride" clip**

In `scripts/CharacterBuilder.gd`, inside `Animator._clip_pose`, add this branch to the `match name:` block (next to `"sleepy"`). It returns the procedural walk cycle frozen at the widest stride, so `pose()` works on code bodies and, through `_apply_bone_pose`, on rigged bodies:

```gdscript
			"stride":   # bước đi đứng hình cho người nộm đám đông xa (CrowdImpostors): tư thế đi ở pha sải chân rộng nhất
				var keep: float = _phase
				_phase = PI * 0.5
				p = _loco_pose(1.0)
				_phase = keep
				p.erase("breathe")
```

- [ ] **Step 3: Implement `CrowdImpostors`**

Create `scripts/roam/CrowdImpostors.gd`:

```gdscript
# File: res://scripts/roam/CrowdImpostors.gd
# Tầng xa của đám đông FreeRoam (spec vice-people-and-movement, "Amendment 2026-10-22"): người đi đường ở 90-225 m là
# "người nộm" – mỗi biến thể (preset + seed + female, 8 biến thể mỗi khu) bake MỘT lần ở tư thế "stride" thành một
# ArrayMesh và vẽ bằng một MultiMeshInstance3D (không đổ bóng); người nộm trượt theo cạnh PedWalkGraph, transform cập nhật
# 10 lần / giây. Cùng danh tính (identity) với Pedestrian nên PedestrianSpawner đổi qua lại hai tầng mà người đi không đổi
# mặt. Mesh bake lưu tĩnh theo phong cách (vào lại FreeRoam không bake lại). Mảng song song, xoá bằng cách đổi chỗ với
# phần tử cuối. Không dùng autoload ở đây (class_name biên dịch trước autoload khi chạy test --script).
class_name CrowdImpostors
extends Node3D

const VARIANTS_PER_ZONE: int = 8
## Preset 8 biến thể mỗi khu (chỉ số = PedWalkGraph.ZONE_*): campus 7 sinh viên + 1 giảng viên; dân cư và đường: dân
## thường (casual) nhiều nhất, có sinh viên ở trọ và giảng viên / dân văn phòng (spec Phần 3: 90/10 và 60/30/10).
const ZONE_PRESETS: Array = [
	["student", "student", "student", "student", "student", "student", "student", "lecturer"],
	["casual", "casual", "casual", "casual", "casual", "student", "student", "lecturer"],
	["casual", "casual", "casual", "casual", "student", "student", "student", "lecturer"],
]
const DEFAULT_CAP: int = 200
const TICK_S: float = 0.1

static var _bake_cache: Dictionary = {}   # "preset|seed|female|ps2" -> [ArrayMesh, Vector3 scale]

var graph: PedWalkGraph
var cap: int = DEFAULT_CAP
var bake_ms: int = 0
var _meshes: Array = []            # v -> ArrayMesh
var _scales: Array = []            # v -> Vector3 (root.scale của nhân vật lúc bake)
var _lift: Array = []              # v -> float: hạ instance theo điểm thấp nhất (chân nhấc lên trong tư thế sải chân)
var _mm: Array = []                # v -> MultiMesh
var _wid := PackedInt32Array()
var _v := PackedInt32Array()
var _node := PackedInt32Array()
var _prev := PackedInt32Array()
var _pos := PackedVector3Array()
var _speed := PackedFloat32Array()
var _yaw := PackedFloat32Array()
var _ident: Array = []             # Dictionary danh tính đầy đủ của từng người nộm
var _rng := RandomNumberGenerator.new()
var _acc: float = 0.0
var _dirty: bool = false


## Bảng 24 biến thể (3 khu x 8), cố định giữa các lần chạy: {"v", "zone", "preset", "seed", "female"}.
static func variants() -> Array:
	var out: Array = []
	for z: int in range(ZONE_PRESETS.size()):
		var list: Array = ZONE_PRESETS[z]
		for k: int in range(list.size()):
			out.append({"v": z * VARIANTS_PER_ZONE + k, "zone": z, "preset": String(list[k]), "seed": 7100 + z * 100 + k * 7, "female": k % 2 == 1})
	return out


## Bake một biến thể: nhân vật rigged (người PS2 ở Vice City) ở tư thế "stride" -> [ArrayMesh, root.scale].
## Lưu tĩnh theo preset / seed / female / phong cách (CharacterBuilder.ps2).
static func bake_variant(ident: Dictionary) -> Array:
	var key: String = "%s|%d|%s|%s" % [String(ident.get("preset", "student")), int(ident.get("seed", 0)), str(ident.get("female", "-")), str(CharacterBuilder.ps2)]
	if _bake_cache.has(key):
		return _bake_cache[key]
	var o: Dictionary = Pedestrian.model_opts(ident)
	o["animate"] = false
	var rig: Node3D = CharacterBuilder.build(o)
	CharacterBuilder.pose(rig, "stride")
	var mesh: ArrayMesh = CharacterBuilder.bake(rig)
	var s: Vector3 = rig.scale
	rig.free()
	_bake_cache[key] = [mesh, s]
	return _bake_cache[key]


func setup(g: PedWalkGraph, opts: Dictionary = {}) -> void:
	graph = g
	cap = int(opts.get("cap", DEFAULT_CAP))
	_rng.seed = int(opts.get("seed", 4242))
	var t0: int = Time.get_ticks_msec()
	for ident: Dictionary in variants():
		var baked: Array = bake_variant(ident)
		var mesh: ArrayMesh = baked[0]
		var s: Vector3 = baked[1]
		_meshes.append(mesh)
		_scales.append(s)
		_lift.append(-mesh.get_aabb().position.y * s.y)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = cap
		mm.visible_instance_count = 0
		_mm.append(mm)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Variant_%d" % int(ident["v"])
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	bake_ms = Time.get_ticks_msec() - t0


## Thêm một người nộm. state: wid, identity (có "v"), node (nút đang tới), prev, pos, speed. false khi đầy / biến thể lạ.
func add(state: Dictionary) -> bool:
	if _wid.size() >= cap:
		return false
	var ident: Dictionary = state["identity"]
	var v: int = int(ident.get("v", -1))
	if v < 0 or v >= _mm.size():
		return false
	_wid.append(int(state.get("wid", -1)))
	_v.append(v)
	_node.append(int(state["node"]))
	_prev.append(int(state.get("prev", int(state["node"]))))
	_pos.append(state["pos"])
	_speed.append(float(state.get("speed", 1.3)))
	_yaw.append(float(state.get("yaw", 0.0)))
	_ident.append(ident)
	_dirty = true
	return true


func count() -> int:
	return _wid.size()


func state_at(i: int) -> Dictionary:
	return {"wid": _wid[i], "identity": _ident[i], "node": _node[i], "prev": _prev[i], "pos": _pos[i], "speed": _speed[i], "yaw": _yaw[i]}


func positions() -> PackedVector3Array:
	return _pos


func wids() -> PackedInt32Array:
	return _wid


func multimesh(v: int) -> MultiMesh:
	return _mm[v]


func variant_mesh(v: int) -> ArrayMesh:
	return _meshes[v]


func variant_scale(v: int) -> Vector3:
	return _scales[v]


## Lấy ra (xoá khỏi đám) tối đa max_n người nộm trong bán kính r quanh center, gần trước; có pred thì chỉ lấy người mà
## pred(pos: Vector3) trả true. Trả về state của họ.
func take_within(center: Vector3, r: float, max_n: int, pred: Callable = Callable()) -> Array:
	if max_n <= 0:
		return []
	var near: Array = []
	for i: int in range(_wid.size()):
		var d: float = _flat(_pos[i], center)
		if d <= r and (not pred.is_valid() or bool(pred.call(_pos[i]))):
			near.append([d, i])
	near.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	near.resize(mini(near.size(), max_n))
	var states: Array = []
	for e: Array in near:
		states.append(state_at(int(e[1])))
	_remove_indices(near.map(func(e: Array) -> int: return int(e[1])))
	return states


## Xoá mọi người nộm mà pred(pos: Vector3) trả true; trả về số người đã xoá.
func remove_where(pred: Callable) -> int:
	var n: int = 0
	for i: int in range(_wid.size() - 1, -1, -1):
		if bool(pred.call(_pos[i])):
			_remove(i)
			n += 1
	return n


func remove_farthest(center: Vector3, n: int) -> int:
	if n <= 0:
		return 0
	var all: Array = []
	for i: int in range(_wid.size()):
		all.append([_flat(_pos[i], center), i])
	all.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	all.resize(mini(all.size(), n))
	_remove_indices(all.map(func(e: Array) -> int: return int(e[1])))
	return all.size()


## Đi tiếp dt giây theo cạnh đồ thị; tới nút thì chọn nút kế (next_node); nút cô lập (block_near) thì đứng yên.
func step(dt: float) -> void:
	if graph == null:
		return
	for i: int in range(_wid.size()):
		var p: Vector3 = _pos[i]
		var left: float = _speed[i] * dt
		var guard: int = 0
		while left > 0.0 and guard < 4:
			guard += 1
			var tp: Vector3 = graph.node_pos(_node[i])
			var to := Vector3(tp.x - p.x, 0.0, tp.z - p.z)
			var d: float = to.length()
			if d > 0.001:
				_yaw[i] = atan2(-to.x, -to.z)
			if d > left:
				p += to / d * left
				left = 0.0
			else:
				p = Vector3(tp.x, p.y, tp.z)
				left -= d
				var nxt: int = graph.next_node(_node[i], _prev[i], _rng)
				_prev[i] = _node[i]
				_node[i] = nxt
				if nxt == _prev[i]:
					break
		_pos[i] = p
	_dirty = true


## Ghi transform mọi người nộm vào MultiMesh của biến thể (mặt nhìn -Z như nhân vật, cỡ = root.scale lúc bake, hạ theo
## điểm thấp nhất của biến thể để chân chạm đất).
func flush() -> void:
	var used := PackedInt32Array()
	used.resize(_mm.size())
	used.fill(0)
	for i: int in range(_wid.size()):
		var v: int = _v[i]
		var k: int = used[v]
		used[v] = k + 1
		var b: Basis = Basis(Vector3.UP, _yaw[i]).scaled(_scales[v])
		(_mm[v] as MultiMesh).set_instance_transform(k, Transform3D(b, _pos[i] + Vector3(0.0, float(_lift[v]), 0.0)))
	for v2: int in range(_mm.size()):
		(_mm[v2] as MultiMesh).visible_instance_count = used[v2]
	_dirty = false


func _physics_process(delta: float) -> void:
	_acc += delta
	if _acc >= TICK_S:
		step(_acc)
		_acc = 0.0
	if _dirty:
		flush()


func _remove_indices(idx: Array) -> void:
	idx.sort()
	idx.reverse()
	for i: int in idx:
		_remove(i)


## Xoá phần tử i: phần tử cuối thế vào chỗ i (xoá theo chỉ số giảm dần thì các chỉ số nhỏ hơn không đổi).
func _remove(i: int) -> void:
	var last: int = _wid.size() - 1
	if i != last:
		_wid[i] = _wid[last]
		_v[i] = _v[last]
		_node[i] = _node[last]
		_prev[i] = _prev[last]
		_pos[i] = _pos[last]
		_speed[i] = _speed[last]
		_yaw[i] = _yaw[last]
		_ident[i] = _ident[last]
	_wid.resize(last)
	_v.resize(last)
	_node.resize(last)
	_prev.resize(last)
	_pos.resize(last)
	_speed.resize(last)
	_yaw.resize(last)
	_ident.resize(last)
	_dirty = true


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
```

Run: `godot --headless --import --path . > /tmp/imp.log 2>&1; grep -c CrowdImpostors .godot/global_script_class_cache.cfg` — expected ≥ 2.

- [ ] **Step 4: Run the tests**

Run: `godot --headless --path . --script tests/test_crowd_impostors.gd > /tmp/t11.log 2>&1; grep -E "stride|baked|remove_where|SUCCESS|FAILED" /tmp/t11.log`
Expected: the knee gap (> 0.2), the bake time (< 8000 ms; write the number in the report), then `✅ SUCCESS: CROWD IMPOSTORS`.
Run `tests/test_ps2_people.gd` and `tests/test_character_builder.gd` again (the new clip must not change other poses).

- [ ] **Step 5: Regression and commit**

Run the regression command (all green), then:

```bash
git add scripts/roam/CrowdImpostors.gd scripts/CharacterBuilder.gd tests/test_crowd_impostors.gd
git commit -m "feat(peds): far crowd tier - 24 fixed variants baked in a static stride pose and drawn as MultiMeshes, impostors glide along the walk graph at 10 Hz, closest-first take for promotion

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: `PedestrianSpawner` (three tiers, zone densities, night) and FreeRoam wiring

**Files:**
- Create: `scripts/roam/PedestrianSpawner.gd`
- Modify: `scripts/FreeRoam.gd`:
  - add `var pedestrians: PedestrianSpawner` and `var crowd_enabled: bool = true`;
  - call `_build_pedestrians()` at the end of `_ready()`, after `set_time_of_day("morning")`, only when `crowd_enabled`.
- Modify: `tests/test_free_roam.gd` (builds FreeRoam with `crowd_enabled = false`)
- Modify: `tests/test_pedestrians.gd` (part C)
- Create: `tests/preview_peds.gd`, which renders `docs/preview/vice_roam_peds_1.png`, `_2.png` and `_3.png`

**Interfaces:**
- Consumes:
  - Tasks 9-11;
  - FreeRoam: `free_spot_at(p, base_y) -> Variant`, `find_free_spot(centre, base_y, max_r)`, `mounted`, `hotspots`, `spawn_xf`, `tod_preset`, `set_time_of_day(preset)`;
  - `ThirdPersonController.slow_t` and `cam_ray`; `PlayerBike.current_speed_ms` and `spring_arm`.
- Produces:
  - `PedestrianSpawner.setup(md: MapData, player_node: Node3D, opts: Dictionary = {})` with opts `bike`, `roam`, `avoid` (Array[Vector3]) and `seed`.
  - Constants:
    - tiers: `PED_CAP` 80, `NEAR_CAP` 40, `NEAR_R` 35, `PROMOTE_R` 90, `DEMOTE_R` 95, `CULL_R` 225, `IMP_CAP` 200;
    - day targets: `PED_TARGET` [60, 45, 25] and `IMP_TARGET` [150, 120, 60], indexed by zone;
    - `NIGHT_FACTOR` 0.3.
  - Queries: `pedestrians() -> Array`, `targets() -> Vector2i` (current pedestrian and impostor targets around the player), `targets_at(c: Vector3)`, `zone_at(c: Vector3) -> int`.
  - Members: `graph: PedWalkGraph`, `impostors: CrowdImpostors`.
  - `request_line(ped, kind)` and signal `pedestrian_hit(ped, kind)`.
  - Counters `spawned`, `recycled`, `promoted`, `demoted`. Test logs `promotions` (`{wid, identity, from, to}`) and `demotions` (`{wid, identity, pos}`), each keeping the last 64.
  - `FreeRoam.pedestrians` and `FreeRoam.crowd_enabled`.

Behaviour (spec Part 3 amendment). Each check runs every 0.25 s around the player, or around the bike when mounted:
1. Demote. Pedestrians beyond 95 m become impostors with the same `wid` and identity. Stuck pedestrians are released.
2. Cull. Impostors beyond 225 m are removed.
3. Clear out-of-view impostors. When pedestrians are at the zone target, impostors that wandered inside 90 m out of the camera view are removed; new impostors appear on the outer ring.
4. Trim. When pedestrians exceed the target by more than 4 (a zone change, or in-view promotions), the farthest out-of-view pedestrians are released. They are never demoted inside 90 m, so no frozen impostor appears in front of the player.
5. Impostors. Refill impostors on the 150-220 m ring, or remove the farthest when over the target.
6. Tiers. `set_far()` makes the 40 closest pedestrians within 35 m near (physics, shadows); all others are mid.

Builds, between checks:
- The check grants 2 build tokens. Each following physics frame spends at most one (`_build_one`), because a build costs about 15 ms; this avoids a 30 ms spike.
- A token promotes the closest impostor within 90 m when pedestrians are below the target, or when the impostor is in the camera view (up to `PED_CAP`, so nobody freezes in sight). A promoted pedestrian reuses a pooled `Pedestrian` of the same variant when there is one.
- With no impostor to promote and pedestrians below the target, the token builds a new pedestrian on the 40-85 m ring, out of view first.

Special cases:
- A jump of more than 120 m between checks (a teleport) refills everything at once: pedestrians at 12-85 m and impostors at 95-220 m.
- Switching to or from night trims the crowd to the new targets at once, farthest first. The whole scene relights at the same moment, so the cut is not noticeable.

- [ ] **Step 1: Write the failing test (part C)**

In `tests/test_pedestrians.gd` set `const PART_C: bool = true`. At the end of the part B `"mid"` branch (after the `if not PART_C:` block) add:

```gdscript
				if PART_C:
					b_phase = ""
					_part_c_start()
```

Then add:

```gdscript
const MIN_NEAR: Array[int] = [40, 30, 15]   # spec Amendment: người đi đường trong 80 m – campus / dân cư / đường
const ROAD_SPOT := Vector3(2058.0, 0.0, -71.0)   # giữa đường Nguyễn Xiển (hành lang)

## Nút chạy SAU mọi _physics_process khác: cùng mốc đầu khung (đặt ở đầu _on_physics_c, tín hiệu physics_frame phát trước
## khi các nút xử lý vật lý) đo thời gian phía script của từng bước vật lý. Performance.TIME_PHYSICS_PROCESS không dùng
## được: Godot chỉ cập nhật nó mỗi giây bằng bước chậm nhất trong giây đó.
class PhysTail extends Node:
	var on_tail: Callable

	func _physics_process(_d: float) -> void:
		on_tail.call()


var roam: Node3D
var c_phase: String = ""
var c_t0: int = 0
var c_frames: int = 0
var phys_with: float = 0.0
var phys_without: float = 0.0
var timing: bool = false
var _pt0: int = 0
var p_usec: int = 0
var p_n: int = 0
var snap: Dictionary = {}           # wid -> identity của mọi người nộm trước khi tiến lại gần
var day_t: Vector2i


func _part_c_start() -> void:
	for n: Node in [ped, jogger, world_b, stub_player, stub_bike]:
		n.queue_free()
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n2: Node = s.new()
			n2.name = pair[0]
			root.add_child(n2)
	var tail := PhysTail.new()
	tail.name = "PhysTail"
	tail.process_physics_priority = 1 << 30
	tail.on_tail = _phys_tail
	root.add_child(tail)
	roam = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	root.add_child(roam)
	c_phase = "settle"
	c_t0 = c_frames
	physics_frame.connect(_on_physics_c)


func _phys_tail() -> void:
	if timing:
		p_usec += Time.get_ticks_usec() - _pt0
		p_n += 1


func _sp() -> PedestrianSpawner:
	return roam.get("pedestrians") as PedestrianSpawner


func _player() -> Node3D:
	return roam.get("player") as Node3D


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _teleport(p: Vector3) -> void:
	var spot: Variant = roam.call("find_free_spot", Vector3(p.x, 0.0, p.z), 0.0, 8)
	var at: Vector3 = spot if spot is Vector3 else Vector3(p.x, 0.5, p.z)
	_player().call("teleport", at + Vector3(0.0, 0.05, 0.0), 0.0)


func _same_identity(a: Dictionary, b: Dictionary) -> bool:
	for k: String in ["v", "preset", "seed", "female", "profile", "wseed", "wid"]:
		if str(a.get(k, "-")) != str(b.get(k, "-")):
			return false
	return true


## Mật độ theo khu, trần các tầng, tầng gần trong 35 m, không ai rơi, người nộm trong vòng 225 m.
func _density_ok(label: String) -> bool:
	var sp: PedestrianSpawner = _sp()
	var c: Vector3 = _player().global_position
	var zone: int = sp.zone_at(c)
	var peds: Array = sp.pedestrians()
	var n80: int = 0
	var near: int = 0
	for p: Pedestrian in peds:
		var d: float = _flat(p.global_position, c)
		if d <= 80.0:
			n80 += 1
		if not p.lod_far:
			near += 1
			if not _check(d <= PedestrianSpawner.NEAR_R + 4.0, "%s: a near-tier pedestrian is %.1f m away (near tier <= 35 m)" % [label, d]):
				return false
		if not _check(p.global_position.y > -1.0, "%s: a pedestrian fell through the world" % label):
			return false
	var imp: int = sp.impostors.count()
	print("  %s: zone %d, %d pedestrians within 80 m (%d total, %d near), %d impostors" % [label, zone, n80, peds.size(), near, imp])
	if not _check(n80 >= MIN_NEAR[zone], "%s: at least %d pedestrians within 80 m in zone %d (got %d)" % [label, MIN_NEAR[zone], zone, n80]):
		return false
	if not _check(peds.size() <= PedestrianSpawner.PED_CAP and near <= PedestrianSpawner.NEAR_CAP and imp <= PedestrianSpawner.IMP_CAP, "%s: tier caps (pedestrians %d / 80, near %d / 40, impostors %d / 200)" % [label, peds.size(), near, imp]):
		return false
	if not _check(imp >= int(float(sp.targets().y) * 0.6), "%s: impostors %d below 60 %% of the target %d" % [label, imp, sp.targets().y]):
		return false
	for q: Vector3 in sp.impostors.positions():
		if not _check(_flat(q, c) <= PedestrianSpawner.CULL_R + 5.0, "%s: an impostor %.0f m away (cull at 225 m)" % [label, _flat(q, c)]):
			return false
	return true


func _on_physics_c() -> void:
	_pt0 = Time.get_ticks_usec()
	if done:
		return
	c_frames += 1
	var t: int = c_frames - c_t0
	match c_phase:
		"settle":
			if t == 150:
				if not _check(_sp() != null, "FreeRoam must expose a pedestrians spawner"):
					return
				if not _check(_sp().zone_at(_player().global_position) == PedWalkGraph.ZONE_RESIDENTIAL, "the BE6 spawn is in the residential zone"):
					return
				if not _density_ok("BE6 spawn"):
					return
				for h: Variant in roam.get("hotspots"):
					var hn: Node3D = h
					for p: Pedestrian in _sp().pedestrians():
						if not _check(_flat(p.global_position, hn.global_position) >= 2.5, "pedestrian %.1f m from a hotspot (keep 3 m)" % _flat(p.global_position, hn.global_position)):
							return
				_teleport(ROAD_SPOT)
				c_phase = "road"
				c_t0 = c_frames
		"road":
			if t == 45:
				if not _check(_sp().zone_at(_player().global_position) == PedWalkGraph.ZONE_ROAD, "test setup: Nguyễn Xiển is in the road zone"):
					return
				if not _density_ok("Nguyễn Xiển"):
					return
				var cc: Vector2 = FPTUCampusBuilder.ring_courtyard_rect().get_center()
				_teleport(FPTUCampusBuilder.real_plot_transform() * Vector3(cc.x, 0.0, cc.y))
				c_phase = "campus"
				c_t0 = c_frames
		"campus":
			if t == 45:
				if not _check(_sp().zone_at(_player().global_position) == PedWalkGraph.ZONE_CAMPUS, "test setup: the courtyard is in the campus zone"):
					return
				if not _density_ok("campus courtyard"):
					return
				_sp().set_physics_process(false)   # dừng việc kiểm / dựng của spawner (con vẫn chạy): chỉ đo đám đông
				p_usec = 0
				p_n = 0
				timing = true
				c_phase = "perf_with"
				c_t0 = c_frames
		"perf_with":
			if t == 60:
				phys_with = float(p_usec) / float(maxi(1, p_n))
				_sp().process_mode = Node.PROCESS_MODE_DISABLED
				p_usec = 0
				p_n = 0
				c_phase = "perf_without"
				c_t0 = c_frames
		"perf_without":
			if t == 60:
				phys_without = float(p_usec) / float(maxi(1, p_n))
				timing = false
				var cost_ms: float = (phys_with - phys_without) / 1000.0
				print("  crowd physics cost %.2f ms per physics frame (%.0f vs %.0f us)" % [cost_ms, phys_with, phys_without])
				if not _check(cost_ms < 5.0, "the crowd (40 near + 40 mid + impostors) must cost < 5 ms per physics frame (got %.2f)" % cost_ms):
					return
				_sp().process_mode = Node.PROCESS_MODE_INHERIT
				_sp().set_physics_process(true)
				# danh tính: chụp mọi người nộm, tiến 45 m về phía người nộm gần nhất (dưới ngưỡng dịch chuyển 120 m)
				var sp: PedestrianSpawner = _sp()
				var c: Vector3 = _player().global_position
				snap.clear()
				var best: Vector3 = Vector3.INF
				for i: int in range(sp.impostors.count()):
					var st: Dictionary = sp.impostors.state_at(i)
					snap[int(st["wid"])] = st["identity"]
					var q: Vector3 = st["pos"]
					if best == Vector3.INF or _flat(q, c) < _flat(best, c):
						best = q
				var u: Vector3 = Vector3(best.x - c.x, 0.0, best.z - c.z).normalized()
				sp.promotions.clear()
				sp.demotions.clear()
				roam.set_meta("dir_u", u)
				_teleport(c + u * 45.0)
				c_phase = "promote"
				c_t0 = c_frames
		"promote":
			if t == 120:
				var sp2: PedestrianSpawner = _sp()
				var ok: int = 0
				for e: Dictionary in sp2.promotions:
					var wid: int = int(e["wid"])
					if not snap.has(wid):
						continue
					if not _check(_same_identity(e["identity"], snap[wid]), "a promoted walker keeps its identity (wid %d)" % wid):
						return
					var found: Pedestrian = null
					for p: Pedestrian in sp2.pedestrians():
						if int(p.identity.get("wid", -1)) == wid:
							found = p
					if found == null:
						continue   # đã bị bỏ trước lúc kiểm (ngoài tầm camera khi quá mục tiêu)
					if not _check(_same_identity(found.identity, snap[wid]), "the pedestrian of promoted wid %d has the impostor's identity" % wid):
						return
					var jump: float = (e["from"] as Vector3).distance_to(e["to"] as Vector3)
					if not _check(jump < 6.5, "promotion moved walker %d by %.1f m (keep < 6.5)" % [wid, jump]):
						return
					ok += 1
				print("  promotions checked: %d (log %d)" % [ok, sp2.promotions.size()])
				if not _check(ok >= 1, "walking 45 m toward the impostors must promote at least one of them"):
					return
				var u2: Vector3 = roam.get_meta("dir_u")
				_teleport(_player().global_position - u2 * 110.0)
				c_phase = "demote"
				c_t0 = c_frames
		"demote":
			if t == 60:
				var sp3: PedestrianSpawner = _sp()
				var okd: int = 0
				for e2: Dictionary in sp3.demotions:
					var w2: int = int(e2["wid"])
					var idx: int = sp3.impostors.wids().find(w2)
					if idx < 0:
						continue   # đã ra ngoài 225 m
					if not _check(_same_identity(sp3.impostors.state_at(idx)["identity"], e2["identity"]), "a demoted walker keeps its identity as an impostor (wid %d)" % w2):
						return
					okd += 1
				print("  demotions checked: %d (log %d)" % [okd, sp3.demotions.size()])
				if not _check(okd >= 1, "walking 110 m away must demote at least one pedestrian into an impostor"):
					return
				day_t = sp3.targets()
				roam.call("set_time_of_day", "night")
				c_phase = "night"
				c_t0 = c_frames
		"night":
			if t == 30:
				var sp4: PedestrianSpawner = _sp()
				var nt: Vector2i = sp4.targets()
				print("  night: targets %s (day %s), pedestrians %d, impostors %d" % [nt, day_t, sp4.pedestrians().size(), sp4.impostors.count()])
				if not _check(nt.x == maxi(1, roundi(float(day_t.x) * 0.3)) and nt.y == maxi(1, roundi(float(day_t.y) * 0.3)), "night targets are 30 %% of the day targets"):
					return
				if not _check(sp4.pedestrians().size() <= nt.x and sp4.impostors.count() <= nt.y, "switching to night trims the crowd at once"):
					return
				roam.call("set_time_of_day", "morning")
				roam.call("mount_bike")
				c_phase = "bike_hit"
				c_t0 = c_frames
		"bike_hit":
			var bike: Node3D = roam.get("bike")
			if t == 30:
				var victim: Pedestrian = _sp().pedestrians()[0]
				victim.process_mode = Node.PROCESS_MODE_INHERIT
				victim.set_far(false)
				victim.global_position = bike.global_position - bike.global_basis.z * 0.9 + Vector3(0.0, 0.05, 0.0)
				bike.set("current_speed_ms", 6.0)
				roam.set_meta("victim", victim)
			if t == 34:
				var v: Pedestrian = roam.get_meta("victim")
				var bs: float = float(bike.get("current_speed_ms"))
				print("  bike hit: pedestrian state %d, bike speed %.2f" % [v.state, bs])
				if not _check(v.state == Pedestrian.State.KNOCKDOWN and bs <= 4.8, "a bike hit must knock the pedestrian down and cost the bike 25 %% of its speed (state %d, speed %.2f)" % [v.state, bs]):
					return
				print("✅ SUCCESS: PEDESTRIANS (parts A + B + C)")
				done = true
				quit(0)
```

Run: `godot --headless --path . --script tests/test_pedestrians.gd > /tmp/t12.log 2>&1; grep -E "SUCCESS|FAILED|Identifier" /tmp/t12.log`
Expected: `Identifier "PedestrianSpawner" not declared in the current scope.`

- [ ] **Step 2: Implement the spawner**

Create `scripts/roam/PedestrianSpawner.gd`:

```gdscript
# File: res://scripts/roam/PedestrianSpawner.gd
# Đám đông FreeRoam ba tầng quanh người chơi (hoặc xe khi đang cưỡi), spec vice-people-and-movement Phần 3 +
# "Amendment 2026-10-22":
#   gần (<= 35 m, tối đa 40): Pedestrian đủ vật lý + phản ứng va chạm;
#   giữa (35-90 m): Pedestrian không vật lý (lod_far), hoạt ảnh theo LOD khoảng cách sẵn có của RigAnimator;
#   xa (90-225 m, tối đa 200): người nộm CrowdImpostors (MultiMesh theo biến thể).
# Mục tiêu ban ngày theo khu quanh người chơi (PedWalkGraph.zone_at): campus 60 / dân cư 45 / đường 25 người đi đường
# trong 90 m và 150 / 120 / 60 người nộm; ban đêm (FreeRoam.tod_preset == "night") còn 30 %, cắt ngay khi đổi giờ.
# Người đi đường ra ngoài 95 m thành người nộm, người nộm vào trong 90 m thành người đi đường (khi còn dưới mục tiêu,
# hoặc khi đang trong tầm camera để không ai đứng hình trước mặt), cùng wid + danh tính (preset, seed, female, profile,
# wseed). Dựng / lên tầng tối đa 2 người mỗi 0.25 s và tối đa một người mỗi khung (mỗi lần dựng ~15 ms), bù người ngoài
# tầm camera trước; quá mục tiêu thì bỏ người xa nhất ngoài tầm camera; người bị bỏ vào pool theo biến thể để dùng lại.
# Dịch chuyển > 120 m thì lấp đầy lại ngay.
# Một bong bóng thoại dùng chung (mỗi 4 s tối đa một câu); nước rút tông người -> người chơi chậm 0.2 s, xe tông -> xe
# mất 25 % tốc độ. Không dùng autoload ở đây.
class_name PedestrianSpawner
extends Node3D

signal pedestrian_hit(ped: Pedestrian, kind: String)

const PED_CAP: int = 80
const NEAR_CAP: int = 40
const NEAR_R: float = 35.0
const PROMOTE_R: float = 90.0
const DEMOTE_R: float = 95.0
const CULL_R: float = 225.0
const IMP_CAP: int = 200
const RING_MIN: float = 40.0
const RING_MAX: float = 85.0
const INITIAL_MIN: float = 12.0
const IMP_SPAWN_MIN: float = 150.0
## Mục tiêu ban ngày theo khu quanh người chơi (chỉ số = PedWalkGraph.ZONE_*): người đi đường trong PROMOTE_R / người nộm.
const PED_TARGET: Array[int] = [60, 45, 25]
const IMP_TARGET: Array[int] = [150, 120, 60]
## Kiểu đi của người mới theo khu nơi họ xuất hiện: xác suất [walk, jog, stroll].
const PROFILE_MIX: Array = [[0.9, 0.0, 0.1], [0.7, 0.15, 0.15], [0.85, 0.1, 0.05]]
const NIGHT_FACTOR: float = 0.3
const CHECK_EVERY: float = 0.25
const BUILDS_PER_CHECK: int = 2
const IMP_SPAWNS_PER_CHECK: int = 12
const TRIM_SLACK: int = 4
const VIEW_SPAWN_R: float = 70.0
const TELEPORT_M: float = 120.0
const POOL_MAX: int = 24
const HOTSPOT_CLEAR: float = 3.0
const SPAWN_CLEAR: float = 8.0
const LINE_GAP_S: float = 4.0
const LINE_SHOW_S: float = 2.0
const PLAYER_SLOW_S: float = 0.2
const BIKE_SPEED_KEEP: float = 0.75
const LOG_MAX: int = 64

var graph: PedWalkGraph
var impostors: CrowdImpostors
var md: MapData
var player: Node3D
var bike: Node3D
var roam: Node
var night: bool = false
var spawned: int = 0
var recycled: int = 0
var promoted: int = 0
var demoted: int = 0
var promotions: Array = []         # test: {wid, identity, from, to}
var demotions: Array = []          # test: {wid, identity, pos}
var _peds: Array = []
var _pool: Dictionary = {}         # v -> Array[Pedestrian] đã tách khỏi cây
var _pool_n: int = 0
var _by_zone: Array = [[], [], []] # khu -> biến thể của khu (CrowdImpostors.variants())
var _avoid: Array = []
var _rng := RandomNumberGenerator.new()
var _next_wid: int = 1
var _check_t: float = 0.0
var _tokens: int = 0                # lần dựng / lên tầng còn được phép, mỗi khung vật lý tối đa một
var _last_center: Vector3 = Vector3.INF
var _line_t: float = -99.0
var _bubble: Label3D
var _bubble_ped: Pedestrian
var _bubble_left: float = 0.0


func setup(map_data: MapData, player_node: Node3D, opts: Dictionary = {}) -> void:
	md = map_data
	player = player_node
	bike = opts.get("bike", null)
	roam = opts.get("roam", null)
	_avoid = opts.get("avoid", [])
	_rng.seed = int(opts.get("seed", 2026))
	graph = PedWalkGraph.build(md)
	if graph.node_count() == 0:
		push_warning("PedestrianSpawner: đồ thị lối đi bộ rỗng, tắt người đi đường")
		set_physics_process(false)
		set_process(false)
		return
	graph.block_near(_avoid, HOTSPOT_CLEAR)
	for vt: Dictionary in CrowdImpostors.variants():
		(_by_zone[int(vt["zone"])] as Array).append(vt)
	impostors = CrowdImpostors.new()
	impostors.name = "Impostors"
	add_child(impostors)
	impostors.setup(graph, {"cap": IMP_CAP, "seed": int(opts.get("seed", 2026)) + 1})
	_bubble = Label3D.new()
	_bubble.name = "SpeechBubble"
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.font_size = 40
	_bubble.pixel_size = 0.005
	_bubble.outline_size = 10
	_bubble.modulate = Color(1.0, 1.0, 1.0)
	_bubble.outline_modulate = Color(0.08, 0.04, 0.12, 0.95)
	_bubble.no_depth_test = true
	_bubble.visible = false
	add_child(_bubble)
	night = _is_night()
	_refill_all(_center())


func pedestrians() -> Array:
	return _peds


## Khu quanh điểm c (khu của nút đồ thị gần nhất trong 80 m; không có thì "đường").
func zone_at(c: Vector3) -> int:
	if graph == null:
		return PedWalkGraph.ZONE_ROAD
	var n: int = graph.nearest(c, 80.0)
	return graph.zone_at(n) if n >= 0 else PedWalkGraph.ZONE_ROAD


## Mục tiêu (người đi đường trong PROMOTE_R, người nộm) quanh c theo khu và ngày / đêm.
func targets_at(c: Vector3) -> Vector2i:
	var z: int = zone_at(c)
	var f: float = NIGHT_FACTOR if night else 1.0
	return Vector2i(maxi(1, roundi(float(PED_TARGET[z]) * f)), maxi(1, roundi(float(IMP_TARGET[z]) * f)))


func targets() -> Vector2i:
	return targets_at(_center())


## Câu càu nhàu của người đi đường (giới hạn: mỗi LINE_GAP_S giây một câu cho cả đám).
func request_line(ped: Pedestrian, kind: String) -> void:
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if now - _line_t < LINE_GAP_S or _bubble == null:
		return
	_line_t = now
	var lines: Array = Pedestrian.PED_LINES.get(kind, Pedestrian.PED_LINES["bump"])
	_bubble.text = String(lines[_rng.randi_range(0, lines.size() - 1)])
	_bubble_ped = ped
	_bubble_left = LINE_SHOW_S
	_bubble.visible = true


func _physics_process(delta: float) -> void:
	if _tokens > 0:
		_build_one(_center())
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = CHECK_EVERY
	var center: Vector3 = _center()
	if _flat(center, _last_center) > TELEPORT_M:
		_reset_around(center)
		return
	_last_center = center
	if _is_night() != night:
		night = not night
		_trim_now(center)
	var t: Vector2i = targets_at(center)
	var want_p: int = mini(t.x, PED_CAP)
	# 1. người đi đường: kẹt / rơi -> bỏ; ra ngoài DEMOTE_R -> người nộm (cùng danh tính)
	for pv: Variant in _peds.duplicate():
		if not is_instance_valid(pv):
			_peds.erase(pv)
			continue
		var p: Pedestrian = pv
		if p.stuck_out:
			recycled += 1
			_release(p)
		elif _flat(p.global_position, center) > DEMOTE_R:
			_demote(p, center)
	# 2. người nộm ra ngoài CULL_R -> bỏ
	recycled += impostors.remove_where(func(q: Vector3) -> bool: return _flat(q, center) > CULL_R)
	# 3. đủ người đi đường: người nộm đã lọt vào trong PROMOTE_R mà ngoài tầm camera thì bỏ (người nộm trong tầm camera
	#    vẫn được _build_one đưa lên tầng, nên không ai đứng hình trước mặt người chơi)
	if _peds.size() >= want_p:
		recycled += impostors.remove_where(func(q: Vector3) -> bool: return _flat(q, center) < PROMOTE_R and not _in_view(q, CULL_R))
	# 4. quá mục tiêu (đổi khu, người nộm vừa lên tầng): bỏ người xa nhất NGOÀI tầm camera, không hạ thành người nộm
	if _peds.size() > want_p + TRIM_SLACK:
		_trim_out_of_view(center, mini(BUILDS_PER_CHECK, _peds.size() - want_p - TRIM_SLACK))
	# 5. người nộm: bớt người xa nhất khi quá mục tiêu, bù ở vòng ngoài
	if impostors.count() > t.y + TRIM_SLACK * 3:
		recycled += impostors.remove_farthest(center, impostors.count() - t.y)
	var made: int = 0
	var tries: int = 0
	while impostors.count() < t.y and made < IMP_SPAWNS_PER_CHECK and tries < IMP_SPAWNS_PER_CHECK * 3:
		tries += 1
		if _spawn_impostor(center, IMP_SPAWN_MIN, CULL_R - 5.0):
			made += 1
	_assign_tiers(center)
	_tokens = BUILDS_PER_CHECK   # các khung kế tiếp: mỗi khung tối đa một lần dựng / lên tầng


## Một lần dựng / lên tầng: người nộm gần nhất trong PROMOTE_R lên tầng khi còn dưới mục tiêu, hoặc khi đang trong tầm
## camera (tới trần PED_CAP); không có thì bù một người mới ở vòng RING_MIN..RING_MAX, ngoài tầm camera trước.
func _build_one(center: Vector3) -> void:
	_tokens -= 1
	if _peds.size() >= PED_CAP:
		return
	var under: bool = _peds.size() < mini(targets_at(center).x, PED_CAP)
	var got: Array = impostors.take_within(center, PROMOTE_R, 1, func(q: Vector3) -> bool: return under or _in_view(q, CULL_R))
	if not got.is_empty():
		_promote(got[0])
		return
	if under:
		for k: int in range(6):
			if _spawn_new(center, RING_MIN, RING_MAX, k < 4):
				return


func _process(delta: float) -> void:
	if _bubble == null or not _bubble.visible:
		return
	_bubble_left -= delta
	if _bubble_left <= 0.0 or not is_instance_valid(_bubble_ped) or not _bubble_ped.is_inside_tree():
		_bubble.visible = false
		return
	var top: Node3D = CharacterBuilder.head_top(_bubble_ped.model)
	_bubble.global_position = (top.global_position if top else _bubble_ped.global_position + Vector3(0.0, 1.9, 0.0)) + Vector3(0.0, 0.35, 0.0)


## Người trong pool đã tách khỏi cây: giải phóng khi spawner rời cây (đổi cảnh) để không rò Node.
func _exit_tree() -> void:
	for list: Variant in _pool.values():
		for p: Variant in list:
			if is_instance_valid(p):
				(p as Node).queue_free()
	_pool.clear()
	_pool_n = 0


# ---------------------------------------------------------------------------
# LẤP ĐẦY / CẮT BỚT
# ---------------------------------------------------------------------------
func _refill_all(center: Vector3) -> void:
	_last_center = center
	var t: Vector2i = targets_at(center)
	var want_p: int = mini(t.x, PED_CAP)
	var tries: int = 0
	while _peds.size() < want_p and tries < want_p * 6:
		tries += 1
		_spawn_new(center, INITIAL_MIN, RING_MAX, false)
	tries = 0
	while impostors.count() < t.y and tries < t.y * 4:
		tries += 1
		_spawn_impostor(center, DEMOTE_R, CULL_R - 5.0)
	_assign_tiers(center)


## Dịch chuyển (về từ màn chơi, test): bỏ hết rồi lấp đầy quanh chỗ mới.
func _reset_around(center: Vector3) -> void:
	for pv: Variant in _peds.duplicate():
		if is_instance_valid(pv):
			_release(pv)
	_peds.clear()
	impostors.remove_where(func(_q: Vector3) -> bool: return true)
	night = _is_night()
	_refill_all(center)


## Đổi ngày / đêm: cắt ngay về mục tiêu mới, người xa nhất trước (đèn cả cảnh đổi cùng lúc nên không lộ).
func _trim_now(center: Vector3) -> void:
	var t: Vector2i = targets_at(center)
	var order: Array = _sorted_by_distance(center, true)
	for i: int in range(maxi(0, order.size() - t.x)):
		recycled += 1
		_release(order[i])
	if impostors.count() > t.y:
		recycled += impostors.remove_farthest(center, impostors.count() - t.y)


## Bỏ tối đa n người xa nhất đang NGOÀI tầm camera (vào pool / giải phóng).
func _trim_out_of_view(center: Vector3, n: int) -> void:
	var cut: int = 0
	for p: Pedestrian in _sorted_by_distance(center, true):
		if cut >= n:
			return
		if not _in_view(p.global_position, CULL_R):
			recycled += 1
			_release(p)
			cut += 1


## 40 người gần nhất trong 35 m có vật lý và bóng đổ; còn lại là tầng giữa (Pedestrian.set_far).
func _assign_tiers(center: Vector3) -> void:
	var order: Array = _sorted_by_distance(center, false)
	for i: int in range(order.size()):
		var p: Pedestrian = order[i]
		p.set_far(i >= NEAR_CAP or _flat(p.global_position, center) > NEAR_R)


func _sorted_by_distance(center: Vector3, farthest_first: bool) -> Array:
	var pairs: Array = []
	for p: Pedestrian in _peds:
		pairs.append([_flat(p.global_position, center), p])
	if farthest_first:
		pairs.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	else:
		pairs.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	return pairs.map(func(x: Array) -> Pedestrian: return x[1])


# ---------------------------------------------------------------------------
# NGƯỜI ĐI ĐƯỜNG / NGƯỜI NỘM
# ---------------------------------------------------------------------------
func _spawn_new(center: Vector3, r_min: float, r_max: float, avoid_view: bool) -> bool:
	var node: int = graph.random_point_ring(center, r_min, r_max, _rng)
	if node < 0:
		return false
	var p: Vector3 = graph.node_pos(node)
	if not _clear_of_avoid(p) or (avoid_view and _in_view(p, VIEW_SPAWN_R)):
		return false
	var spot: Variant = _free_spot(p)
	if not (spot is Vector3):
		return false
	_spawn_ped(node, node, spot, _new_identity(graph.zone_at(node)))
	return true


func _spawn_impostor(center: Vector3, r_min: float, r_max: float) -> bool:
	var node: int = graph.random_point_ring(center, r_min, r_max, _rng)
	if node < 0 or not _clear_of_avoid(graph.node_pos(node)):
		return false
	var ident: Dictionary = _new_identity(graph.zone_at(node))
	var sp: float = Pedestrian.speed_for(String(ident["profile"]), int(ident["wseed"]))
	return impostors.add({"wid": int(ident["wid"]), "identity": ident, "node": node, "prev": node, "pos": graph.node_pos(node), "speed": sp})


## Danh tính mới: một biến thể của khu (8 biến thể mỗi khu), kiểu đi theo PROFILE_MIX, wseed và wid riêng.
func _new_identity(zone: int) -> Dictionary:
	var list: Array = _by_zone[zone]
	var ident: Dictionary = (list[_rng.randi_range(0, list.size() - 1)] as Dictionary).duplicate()
	var mix: Array = PROFILE_MIX[zone]
	var r: float = _rng.randf()
	var profile: String = "walk" if r < float(mix[0]) else ("jog" if r < float(mix[0]) + float(mix[1]) else "stroll")
	if String(ident["preset"]) == "lecturer" and profile == "jog":
		profile = "walk"
	ident["profile"] = profile
	ident["wseed"] = _rng.randi() % 1000000
	ident["wid"] = _next_wid
	_next_wid += 1
	return ident


func _spawn_ped(node: int, prev: int, at: Vector3, ident: Dictionary) -> Pedestrian:
	var v: int = int(ident.get("v", -1))
	var p: Pedestrian = null
	var pool: Array = _pool.get(v, [])
	if not pool.is_empty():
		p = pool.pop_back()
		_pool_n -= 1
	else:
		p = Pedestrian.new()
		p.name = "Ped_%d" % spawned
	p.setup(graph, node, ident)
	p.prev_node = prev
	p.player = player
	p.bike = bike
	p.mounted_fn = _mounted
	p.crowd = _peds
	p.spawner = self
	if not p.hit.is_connected(_on_hit):
		p.hit.connect(_on_hit)
	add_child(p)
	p.global_position = at + Vector3(0.0, 0.05, 0.0)
	_peds.append(p)
	spawned += 1
	if player and player.get("cam_ray"):
		(player.get("cam_ray") as RayCast3D).add_exception(p)
	if bike and bike.get("spring_arm"):
		(bike.get("spring_arm") as SpringArm3D).add_excluded_object(p.get_rid())
	return p


## Người nộm -> người đi đường tại chỗ người nộm đứng (hoặc nút nó đang tới); không có chỗ cho thân thật thì bỏ.
func _promote(st: Dictionary) -> void:
	var at: Variant = _free_spot(st["pos"])
	if not (at is Vector3):
		at = _free_spot(graph.node_pos(int(st["node"])))
	if not (at is Vector3):
		recycled += 1
		return
	var p: Pedestrian = _spawn_ped(int(st["node"]), int(st["prev"]), at, st["identity"])
	promoted += 1
	_log(promotions, {"wid": int(st["wid"]), "identity": p.identity, "from": st["pos"], "to": p.global_position})


func _demote(p: Pedestrian, center: Vector3) -> void:
	if _flat(p.global_position, center) < CULL_R:
		var st: Dictionary = {"wid": int(p.identity.get("wid", -1)), "identity": p.identity, "node": p.target_node, "prev": p.prev_node, "pos": p.global_position, "speed": p.walk_speed}
		if impostors.add(st):
			demoted += 1
			_log(demotions, {"wid": int(st["wid"]), "identity": p.identity, "pos": st["pos"]})
	_release(p)


## Bỏ một người đi đường khỏi đám: vào pool của biến thể (tách khỏi cây) nếu còn chỗ, không thì giải phóng.
func _release(p: Pedestrian) -> void:
	_peds.erase(p)
	if _bubble_ped == p and _bubble:
		_bubble.visible = false
	var v: int = int(p.identity.get("v", -1))
	if v >= 0 and _pool_n < POOL_MAX and not p.stuck_out:
		remove_child(p)
		if not _pool.has(v):
			_pool[v] = []
		(_pool[v] as Array).append(p)
		_pool_n += 1
	else:
		if player and player.get("cam_ray"):
			(player.get("cam_ray") as RayCast3D).remove_exception(p)
		if bike and bike.get("spring_arm"):
			(bike.get("spring_arm") as SpringArm3D).remove_excluded_object(p.get_rid())
		p.queue_free()


# ---------------------------------------------------------------------------
# PHỤ TRỢ
# ---------------------------------------------------------------------------
func _center() -> Vector3:
	if _mounted() and bike:
		return bike.global_position
	return player.global_position if player else Vector3.ZERO


func _mounted() -> bool:
	return roam != null and bool(roam.get("mounted"))


func _is_night() -> bool:
	return roam != null and String(roam.get("tod_preset")) == "night"


func _free_spot(p: Vector3) -> Variant:
	if roam and roam.has_method("free_spot_at"):
		return roam.call("free_spot_at", Vector3(p.x, 0.0, p.z), 0.0)
	return Vector3(p.x, 0.0, p.z)


func _clear_of_avoid(p: Vector3) -> bool:
	for a: Variant in _avoid:
		var av: Vector3 = a
		if Vector2(p.x - av.x, p.z - av.z).length() < HOTSPOT_CLEAR + 0.5:
			return false
	if player and Vector2(p.x - player.global_position.x, p.z - player.global_position.z).length() < SPAWN_CLEAR:
		return false
	return true


func _in_view(p: Vector3, max_d: float) -> bool:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return false
	return cam.global_position.distance_to(p) < max_d and cam.is_position_in_frustum(p + Vector3(0.0, 1.0, 0.0))


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _log(arr: Array, e: Dictionary) -> void:
	arr.append(e)
	if arr.size() > LOG_MAX:
		arr.pop_front()


func _on_hit(ped: Pedestrian, kind: String) -> void:
	if kind == "sprint" and player:
		player.set("slow_t", PLAYER_SLOW_S)
	elif kind == "bike" and bike:
		bike.set("current_speed_ms", float(bike.get("current_speed_ms")) * BIKE_SPEED_KEEP)
	pedestrian_hit.emit(ped, kind)
```

Wire it into `scripts/FreeRoam.gd`:
- Add `var pedestrians: PedestrianSpawner` next to `var bike: PlayerBike`.
- Add the flag `var crowd_enabled: bool = true`, with the comment `## false = không dựng người đi đường / xe chạy (test_free_roam đặt trước add_child để các pha kiểm tra cố định)`.
- At the end of `_ready()`, right after `set_time_of_day("morning")`, add:

```gdscript
	if crowd_enabled:
		_build_pedestrians()
```

and add the function:

```gdscript
## Đám đông ba tầng (spec vice-people-and-movement, Phần 3 + Amendment): tránh cột sáng hotspot và điểm spawn.
func _build_pedestrians() -> void:
	pedestrians = PedestrianSpawner.new()
	pedestrians.name = "Pedestrians"
	add_child(pedestrians)
	var avoid: Array = [spawn_xf.origin]
	for h: Area3D in hotspots:
		avoid.append(h.global_position)
	pedestrians.setup(md, player, {"bike": bike, "roam": self, "avoid": avoid})
```

In `tests/test_free_roam.gd` `_initialize()`, right after `roam = packed.instantiate()`, add:

```gdscript
	roam.set("crowd_enabled", false)   # các pha kiểm tra cố định: không người đi đường / xe chạy chen vào
```

Run: `godot --headless --import --path . > /tmp/imp.log 2>&1; grep -c PedestrianSpawner .godot/global_script_class_cache.cfg` — expected ≥ 2.

- [ ] **Step 3: Run the tests**

Run: `godot --headless --path . --script tests/test_pedestrians.gd > /tmp/t12.log 2>&1; grep -E "zone|physics cost|promotions|demotions|night|bike hit|SUCCESS|FAILED" /tmp/t12.log`
Expected:
- the three density lines meet the thresholds (BE6 ≥ 30, Nguyễn Xiển ≥ 15, courtyard ≥ 40);
- the crowd costs < 5 ms;
- at least one promotion and one demotion are checked;
- the night targets are 30 %;
- then `✅ SUCCESS: PEDESTRIANS (parts A + B + C)`.

If the physics cost is 5 ms or more, stop and report the number; the controller decides on the fallback (near pedestrians farther than 15 m from the player run `move_and_slide` every second physics frame with twice the delta).

Frame time outside physics is measured by the Step 4 preview. If a shot drops below 45 fps, report it with the numbers; do not tune silently. The known levers are:
- `PED_TARGET`, `IMP_CAP` and `NEAR_CAP`;
- advancing each mid-tier AnimationPlayer manually at about 10 Hz. Its `AnimationMixer` runs every frame regardless of the `RigAnimator` LOD.

Run: `godot --headless --path . --script tests/test_free_roam.gd > /tmp/fr.log 2>&1; grep -E "SUCCESS|FAILED|build" /tmp/fr.log` — expected SUCCESS (built without the crowd).
Run: `godot --headless --path . --script tests/smoke_all_stages.gd > /tmp/smoke.log 2>&1; grep -c "SCRIPT ERROR\|^ERROR:" /tmp/smoke.log` — expected 0 (FreeRoam with the crowd).

- [ ] **Step 4: Preview**

Create `tests/preview_peds.gd`:

```gdscript
# File: res://tests/preview_peds.gd
# Ảnh đám đông + xe chạy FreeRoam (cần cửa sổ render): vice_roam_peds_1 (trước sảnh BE6, khu dân cư), vice_roam_peds_2
# (cổng chính campus), vice_roam_peds_3 (lề đường Nguyễn Xiển). fps của từng ảnh là cổng hiệu năng của spec.
#   godot --path . --script tests/preview_peds.gd      (PREVIEW_DIR=..., VICE_STYLE=vice|classic, PREVIEW_NOVSYNC=1)
extends SceneTree

var roam: Node3D
var frames: int = 0
var out_dir: String


func _initialize() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	var style: String = OS.get_environment("VICE_STYLE")
	if style != "":
		var fx: Node = root.get_node("GameFX")
		fx.ready.connect(func() -> void: fx.call("set_art_style", style, false), CONNECT_ONE_SHOT)
	if OS.get_environment("PREVIEW_NOVSYNC") == "1":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var dir_env: String = OS.get_environment("PREVIEW_DIR")
	out_dir = dir_env if dir_env != "" else ProjectSettings.globalize_path("user://preview")
	DirAccess.make_dir_recursive_absolute(out_dir)
	roam = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	root.add_child(roam)


func _save(name: String) -> void:
	var err: int = root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("  saved %s.png err=%d fps=%.0f" % [name, err, Engine.get_frames_per_second()])


func _process(_d: float) -> bool:
	frames += 1
	var player: ThirdPersonController = roam.get("player") as ThirdPersonController
	if frames == 240:
		_save("vice_roam_peds_1")
		var gate: Vector3 = FPTUCampusBuilder.real_plot_transform() * (FPTUCampusBuilder.main_gate_local() + Vector3(0.0, 0.5, -14.0))
		player.teleport(gate, PI)
	if frames == 480:
		_save("vice_roam_peds_2")
		player.teleport(Vector3(2051.0, 0.5, -69.0), 0.0)   # lề tây Nguyễn Xiển, nhìn dọc đường về phía bắc
	if frames == 720:
		_save("vice_roam_peds_3")
		print("PREVIEW PEDS DONE")
		quit(0)
	return false
```

Run: `VICE_STYLE=vice PREVIEW_NOVSYNC=1 PREVIEW_DIR="$(pwd)/docs/preview" godot --path . --script tests/preview_peds.gd > /tmp/pp2.log 2>&1; grep -E "saved|DONE" /tmp/pp2.log`
Expected: three images with fps ≥ 45. Open them and check:
- PS2 pedestrians walk on verges and footways, never in the carriageway, in water or inside buildings;
- students crowd the campus gate and residents fill the BE6 plaza;
- small far figures fill the distance, and none of them hovers or faces sideways.

- [ ] **Step 5: Regression and commit**

Run the regression command (all green), then:

```bash
git add scripts/roam/PedestrianSpawner.gd scripts/FreeRoam.gd tests/test_pedestrians.gd tests/test_free_roam.gd tests/preview_peds.gd docs/preview/vice_roam_peds_*.png
git commit -m "feat(peds): three-tier FreeRoam crowd - zone densities (campus/residential/road), near physics tier, mid tier without physics, MultiMesh far tier with identity-keeping promotion and demotion, pool, night scaling, shared speech bubble, sprint/bike hit consequences

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: `RoamTraffic` (ambient vehicles) and `PropBuilder.build_car`

**Files:**
- Create: `scripts/roam/RoamTraffic.gd`
- Modify: `scripts/PropBuilder.gd` (new `build_car()` and one header line)
- Modify: `scripts/FreeRoam.gd` (`var traffic: RoamTraffic`; `_build_traffic()` after `_build_pedestrians()` inside the `crowd_enabled` block)
- Create: `tests/test_roam_traffic.gd`, `tests/support/stub_roam.gd`
- Re-render: `docs/preview/vice_roam_peds_*.png` (now with traffic)

**Interfaces:**
- Consumes:
  - `MapData.roads()`, `MapBuilder.CLASS_ALIAS`, `MapBuilder.ROAD_Y`, `PedWalkGraph._offset()` (right of travel for a positive offset);
  - `FPTUCampusBuilder.real_plot_transform()`, `plot_rect()`, `BIKE_PAINTS`;
  - `PropBuilder.build_scooter()`, `build_bus()`, `CharacterBuilder.build_baked_rider()` (PS2 rider in vice);
  - the `PlayerBike` crash handling for group `traffic_obstacle`;
  - the FreeRoam members of Task 12, and `PedestrianSpawner.pedestrians`.
- Produces:
  - `PropBuilder.build_car(parent: Node3D, paint_color: Color, baked: bool = true) -> Node3D`: a hatchback of about 3.9 × 1.7 × 1.5 m that faces -Z.
  - `RoamTraffic.setup(md: MapData, player_node: Node3D, opts := {})` with opts:
    - `bike`, `roam`, `peds_fn` (Callable -> Array of pedestrians);
    - `kinds` (Array of `RoamTraffic.Kind`; default 20 MOTO + 3 CAR + 2 BUS);
    - `plot` (PackedVector2Array; default the campus plot grown 3 m; empty = no exclusion) and `seed`.
  - `enum Kind { MOTO, CAR, BUS }`, and the inner class `RoamTraffic.Vehicle` with:
    - position and motion: `active`, `kind`, `lane`, `s`, `pos: Vector2`, `dir: Vector2`, `speed`, `cruise`, `half_len`, `half_w`;
    - turning: `exit` (the chosen `[lane, s_in, back]`), `turn_at` and `conn` (the Bezier while turning);
    - `blocked_by` and `body: AnimatableBody3D`.
  - Members:
    - `vehicles: Array`, `recycled: int`, `night: bool`;
    - the lane arrays `lane_pts`, `lane_cum`, `lane_len`, `lane_speed`, `lane_kinds` (bit `1 << Kind`), `lane_road` and `lane_exits`. Each exit is `[lane, s_in, back]`.
  - `bodies() -> Array`, `active_count() -> int`, `lane_count() -> int`, `static func _campus_plot() -> PackedVector2Array`.
  - Constants `SPAWN_MIN` 40, `SPAWN_MAX` 150, `DESPAWN` 200, `STOP_GAP` 3, `TURN_R` 4, `NIGHT_FACTOR` 0.3.
  - `FreeRoam.traffic`.

Behaviour (spec Part 3 amendment):
- **Lanes.** Lanes come from MapData carriageways. Roads with `lanes > 0` count; service roads, bridges and anything inside the campus plot are left out. A two-way road gives two lanes, each offset `width / 4` to the right of its travel direction. A one-way road gives one lane on its centreline in the OSM point order.
- **Turning at a lane end.**
  - Each lane end links to every lane passing within 9 m whose entry point still has at least 8 m of lane ahead. With no such lane, the end links to a U-turn onto the other lane of the same road. With no U-turn either, the vehicle is recycled at the end.
  - A vehicle picks its exit when it enters a lane. It starts turning `back = TURN_R - (q - e)·dir` metres before the lane end, where `TURN_R` is 4 m, `e` is the lane end and `q` the closest point on the exit lane. It enters the new lane `TURN_R / 2` past `q`.
  - OSM lanes end at the junction centre, so the entry of a right turn lies behind the lane end. Starting the turn early keeps the quadratic Bezier (driven at 60 % of cruise speed) always moving forward.
- **Speeds and vehicle kinds.**
  - Speed by road class: motorway 13, primary 11, secondary 10, tertiary 9 and everything else 6.5 m/s.
  - Motorbikes drive at 0.85-1.15 of that speed, cars at 0.9-1.05 and buses at 0.8.
  - Cars need a road at least 6 m wide. Buses need a primary, secondary, tertiary or motorway road at least 7 m wide.
- **Looking ahead.**
  - Every third physics frame each vehicle checks the strip ahead of it, `6 + 1.6 × speed` m long and as wide as both bodies plus 0.5 m.
  - It brakes for the nearest other vehicle, pedestrian, the player or the player's bike (ridden or parked), and stops 3 m behind it.
  - Obstacles farther than the strip length + 8 m are skipped before the strip test.
  - Approaching a turn, the strip ends 6 m past the turn start, so pedestrians on the far verge of a T-junction do not stop the vehicle.
  - A vehicle held by another vehicle for 5 s ignores vehicles for 2 s. This breaks junction deadlocks; it still respects people.
- **Spawning and recycling.**
  - Vehicles appear 40-150 m from the player, out of the camera view first; the first fill uses 20-150 m.
  - Vehicles beyond 200 m are parked (hidden, physics off) and later reused elsewhere. A vehicle body is never rebuilt.
- **Night.** Night keeps 30 %, parking the farthest vehicles first.
- **Bodies.** The bodies are `AnimatableBody3D` boxes in the group `traffic_obstacle`; buses are also in `slipstream_vehicle`. The player's bike therefore bumps them with the existing crash handling.

- [ ] **Step 1: Write the failing test**

Create `tests/support/stub_roam.gd`:

```gdscript
# File: res://tests/support/stub_roam.gd
# FreeRoam giả cho test xe chạy: chỉ có cờ mounted và tod_preset.
extends Node

var mounted: bool = false
var tod_preset: String = "morning"
```

Create `tests/test_roam_traffic.gd`:

```gdscript
# File: res://tests/test_roam_traffic.gd
# Test headless xe chạy FreeRoam (RoamTraffic, plan Task 13).
#   A: MapData tự dựng ở z ~ 5000 (xa campus thật): hình vuông 160 m bốn đường chính hai chiều 10,5 m + một nhánh cụt
#      6 m. Làn bên phải, nối làn ở góc (rẽ không bao giờ đi lùi), quay đầu ở ngõ cụt, xe buýt chỉ trên đường cho xe
#      buýt, dừng 2,4-6,5 m sau người chơi rồi đi tiếp, xe ra ngoài 200 m bị đưa đi, xe mới xuất hiện cách 40-150 m,
#      đêm còn 30 %, build_car. Đếm khung vật lý (60 Hz): headless vẽ ~145 khung / giây.
#   B: FreeRoam thật: >= 15 xe trong 150 m quanh điểm spawn, mọi xe trên lòng đường, không làn / xe nào trong lô campus,
#      chi phí vật lý < 1,5 ms (đo trực tiếp, đám đông tạm tắt), xe máy người chơi tông xe -> xử lý va chạm sẵn có (mất
#      tốc), đêm còn <= 8 xe.
# Chạy:  godot --headless --path . --script tests/test_roam_traffic.gd
extends SceneTree

const W: float = 10.5
const CENTER := Vector3(0.0, 0.0, 5000.0)


## Chạy SAU mọi _physics_process khác: cùng mốc đầu khung (tín hiệu physics_frame) đo thời gian phía script mỗi bước vật lý.
class PhysTail extends Node:
	var on_tail: Callable

	func _physics_process(_d: float) -> void:
		on_tail.call()


var done: bool = false
var frames: int = 0
var traffic: RoamTraffic
var stub_player: CharacterBody3D
var stub_roam: Node
var a_started: bool = false
var phase: String = ""
var t0: int = 0
var seen: Dictionary = {}
var last_pos: Dictionary = {}
var last_lane: Dictionary = {}
var lane_changes: int = 0
var watch: RoamTraffic.Vehicle
var roads: Array = []
var roam: Node3D
var b_phase: String = ""
var b_t0: int = 0
var b_frames: int = 0
var crashes: int = 0
var phys_with: float = 0.0
var phys_without: float = 0.0
var timing: bool = false
var _pt0: int = 0
var p_usec: int = 0
var p_n: int = 0


func _initialize() -> void:
	CharacterBuilder.ps2 = true      # mặc định của game là vice; test --script không có GameFX
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	if not _car_model_ok():
		return
	physics_frame.connect(_on_physics_a)   # nút thêm trong _initialize chưa vào cây: bắt đầu ở khung vật lý đầu tiên


func _start_a() -> void:
	var md := MapData.new()
	roads = _synthetic_roads()
	md.data = {"roads": roads}
	stub_player = CharacterBody3D.new()
	stub_player.set_script(load("res://tests/support/stub_mover.gd"))
	stub_player.collision_layer = 0
	root.add_child(stub_player)
	stub_player.global_position = CENTER
	stub_roam = Node.new()
	stub_roam.set_script(load("res://tests/support/stub_roam.gd"))
	root.add_child(stub_roam)
	traffic = RoamTraffic.new()
	root.add_child(traffic)
	var kinds: Array = []
	for k: int in range(10):
		kinds.append(RoamTraffic.Kind.MOTO if k < 6 else (RoamTraffic.Kind.CAR if k < 8 else RoamTraffic.Kind.BUS))
	traffic.setup(md, stub_player, {"roam": stub_roam, "kinds": kinds, "plot": PackedVector2Array(), "seed": 9})
	if not _lanes_ok():
		return
	phase = "run"
	t0 = frames


func _synthetic_roads() -> Array:
	var sq: Array = [[Vector2(-80.0, 5080.0), Vector2(80.0, 5080.0)], [Vector2(80.0, 5080.0), Vector2(80.0, 4920.0)],
		[Vector2(80.0, 4920.0), Vector2(-80.0, 4920.0)], [Vector2(-80.0, 4920.0), Vector2(-80.0, 5080.0)]]
	var out: Array = []
	for i: int in range(sq.size()):
		var a: Vector2 = sq[i][0]
		var b: Vector2 = sq[i][1]
		out.append({"id": i + 1, "name": "Vuông %d" % (i + 1), "class": "primary", "width": W, "lanes": 2, "oneway": false, "roundabout": false, "bridge": false, "region": "corridor", "points": [[a.x, a.y], [b.x, b.y]]})
	out.append({"id": 9, "name": "Nhánh cụt", "class": "residential", "width": 6.0, "lanes": 2, "oneway": false, "roundabout": false, "bridge": false, "region": "corridor", "points": [[0.0, 5080.0], [0.0, 5160.0]]})
	return out


func _car_model_ok() -> bool:
	var holder := Node3D.new()
	root.add_child(holder)
	var mi: MeshInstance3D = PropBuilder.build_car(holder, Color("#7FD8D2"), true) as MeshInstance3D
	var bb: AABB = mi.mesh.get_aabb() if mi and mi.mesh else AABB()
	print("  build_car: %s" % bb.size)
	var ok: bool = _check(mi != null and bb.size.x > 1.6 and bb.size.x < 2.1 and bb.size.y > 1.4 and bb.size.y < 1.7 and bb.size.z > 3.8 and bb.size.z < 4.1, "PropBuilder.build_car bakes a ~1.7 x 1.5 x 3.9 m car (got %s)" % bb.size)
	holder.queue_free()
	return ok


func _lanes_ok() -> bool:
	if not _check(traffic.lane_count() == 10, "8 square lanes + 2 stub lanes (got %d)" % traffic.lane_count()):
		return false
	var dead_end: int = -1
	for l: int in range(traffic.lane_count()):
		var pts: PackedVector2Array = traffic.lane_pts[l]
		if not _check((traffic.lane_exits[l] as Array).size() >= 1, "lane %d has no exit" % l):
			return false
		if pts[pts.size() - 1].y > 5150.0:
			dead_end = l
		var on_stub: bool = absf(pts[0].x) < 3.0 and absf(pts[pts.size() - 1].x) < 3.0
		var bus_ok: bool = (traffic.lane_kinds[l] & (1 << RoamTraffic.Kind.BUS)) != 0
		if not _check(bus_ok != on_stub, "buses use the 10.5 m primary square but not the 6 m residential stub (lane %d)" % l):
			return false
	if not _check(dead_end >= 0, "test setup: the stub's southbound lane ends at z ~ 5160"):
		return false
	var dx: Array = traffic.lane_exits[dead_end]
	var back: int = int((dx[0] as Array)[0])
	return _check(dx.size() == 1 and traffic.lane_road[back] == traffic.lane_road[dead_end] and float((dx[0] as Array)[1]) <= RoamTraffic.TURN_R * 0.5 + 0.01, "a dead end turns back onto the start of the same road's other lane")


## Mỗi xe vừa xuất hiện phải cách người chơi 40-150 m (lần lấp đầy đầu lúc setup được phép từ 20 m).
func _check_new_spawns() -> void:
	var c := Vector2(stub_player.global_position.x, stub_player.global_position.z)
	for v: RoamTraffic.Vehicle in traffic.vehicles:
		if not v.active:
			seen.erase(v)
			continue
		if seen.has(v):
			continue
		seen[v] = true
		if frames > 1:
			var d: float = v.pos.distance_to(c)
			_check(d >= RoamTraffic.SPAWN_MIN - 1.0 and d <= RoamTraffic.SPAWN_MAX + 1.0, "a vehicle appeared %.1f m from the player (40-150)" % d)


## Không xe nào đi lùi (rẽ phải ở ngã tư: điểm vào nằm sau cuối làn) và đếm số lần đổi làn.
func _check_motion() -> void:
	for v: RoamTraffic.Vehicle in traffic.vehicles:
		if not v.active:
			last_pos.erase(v)
			last_lane.erase(v)
			continue
		if last_pos.has(v):
			var mv: Vector2 = v.pos - (last_pos[v] as Vector2)
			if mv.length() < 2.0 and mv.dot(v.dir) < -0.02:
				_check(false, "a vehicle moved backwards by %.2f m (lane %d, turning %s)" % [-mv.dot(v.dir), v.lane, str(v.conn.size() == 3)])
				return
			if int(last_lane[v]) != v.lane:
				lane_changes += 1
		last_pos[v] = v.pos
		last_lane[v] = v.lane


func _lane_keeping_ok() -> bool:
	for v: RoamTraffic.Vehicle in traffic.vehicles:
		if not v.active or v.conn.size() == 3:
			continue
		var best_d: float = INF
		var best_rel := Vector2.ZERO
		var best_w: float = 0.0
		var near_end: bool = false
		for r: Dictionary in roads:
			var pts: PackedVector2Array = MapData.poly(r["points"])
			if v.pos.distance_to(pts[0]) < 10.0 or v.pos.distance_to(pts[pts.size() - 1]) < 10.0:
				near_end = true
			for i: int in range(pts.size() - 1):
				var q: Vector2 = Geometry2D.get_closest_point_to_segment(v.pos, pts[i], pts[i + 1])
				if q.distance_to(v.pos) < best_d:
					best_d = q.distance_to(v.pos)
					best_rel = v.pos - q
					best_w = float(r["width"])
		if near_end:
			continue
		if not _check(v.dir.cross(best_rel) > 0.0 and absf(best_rel.length() - best_w * 0.25) < 0.3, "a vehicle keeps to the right-hand lane (offset %.2f m, side %.2f, road %.1f m)" % [best_rel.length(), v.dir.cross(best_rel), best_w]):
			return false
	return true


func _pick_watch() -> RoamTraffic.Vehicle:
	for v: RoamTraffic.Vehicle in traffic.vehicles:
		if not v.active or v.conn.size() == 3 or v.speed < 2.0 or traffic.lane_len[v.lane] - v.s < 40.0:
			continue
		var clear: bool = true
		for o: RoamTraffic.Vehicle in traffic.vehicles:
			if o == v or not o.active:
				continue
			var rel: Vector2 = o.pos - v.pos
			if rel.dot(v.dir) > 0.0 and rel.dot(v.dir) < 35.0 and absf(rel.cross(v.dir)) < 3.0:
				clear = false
		if clear:
			return v
	return null


func _on_physics_a() -> void:
	if done:
		return
	if not a_started:
		a_started = true
		_start_a()
		return
	if phase == "":
		return
	frames += 1
	var t: int = frames - t0
	_check_new_spawns()
	_check_motion()
	match phase:
		"run":
			if t % 30 == 0 and not _lane_keeping_ok():
				return
			if t == 480:   # 8 s
				print("  lane changes during the run: %d" % lane_changes)
				if not _check(lane_changes >= 1, "vehicles must turn onto other lanes (lane changes %d in 8 s)" % lane_changes):
					return
				watch = _pick_watch()
				if not _check(watch != null, "test setup: a moving vehicle with 40 m of free lane ahead"):
					return
				stub_player.global_position = Vector3(watch.pos.x + watch.dir.x * 24.0, 0.0, watch.pos.y + watch.dir.y * 24.0)
				phase = "stop"
				t0 = frames
		"stop":
			if t == 300:   # 5 s: phanh 3,5 m/s² từ 9-13 m/s mất ~3,4 s
				var rel := Vector2(stub_player.global_position.x, stub_player.global_position.z) - watch.pos
				var gap: float = rel.dot(watch.dir) - watch.half_len - 0.4
				print("  stopped behind the player: speed %.2f, gap %.2f m, blocked by '%s'" % [watch.speed, gap, watch.blocked_by])
				if not _check(watch.speed < 0.1 and gap >= 2.4 and gap <= 6.5 and watch.blocked_by == "player", "a vehicle stops 2.4-6.5 m behind a player standing in its lane (speed %.2f, gap %.2f, '%s')" % [watch.speed, gap, watch.blocked_by]):
					return
				stub_player.global_position = CENTER
				phase = "go"
				t0 = frames
		"go":
			if t == 180:
				if not _check(watch.speed > 1.0, "the vehicle drives on once the lane is clear (speed %.2f)" % watch.speed):
					return
				stub_player.global_position = CENTER + Vector3(0.0, 0.0, 600.0)
				phase = "away"
				t0 = frames
		"away":
			if t == 120:
				print("  player 600 m away: %d active, recycled %d" % [traffic.active_count(), traffic.recycled])
				if not _check(traffic.active_count() == 0 and traffic.recycled >= 10, "vehicles beyond 200 m are parked and none appear without lanes in range (active %d, recycled %d)" % [traffic.active_count(), traffic.recycled]):
					return
				stub_player.global_position = CENTER
				phase = "back"
				t0 = frames
		"back":
			if t == 240:   # 4 s: 4 lần kiểm x 3 xe
				print("  back at the square: %d active" % traffic.active_count())
				if not _check(traffic.active_count() == 10, "vehicles refill around the player (active %d / 10)" % traffic.active_count()):
					return
				stub_roam.set("tod_preset", "night")
				phase = "night"
				t0 = frames
		"night":
			if t == 90:
				print("  night: %d active" % traffic.active_count())
				if not _check(traffic.active_count() >= 1 and traffic.active_count() <= 3, "night keeps 30 %% of the vehicles (active %d / 3)" % traffic.active_count()):
					return
				phase = ""
				traffic.queue_free()
				stub_player.queue_free()
				stub_roam.queue_free()
				_part_b_start()


func _part_b_start() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	var tail := PhysTail.new()
	tail.name = "PhysTail"
	tail.process_physics_priority = 1 << 30
	tail.on_tail = _phys_tail
	root.add_child(tail)
	roam = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	root.add_child(roam)
	b_phase = "settle"
	b_t0 = 0
	physics_frame.connect(_on_physics_b)


func _phys_tail() -> void:
	if timing:
		p_usec += Time.get_ticks_usec() - _pt0
		p_n += 1


func _on_carriageway(md: MapData, p: Vector2) -> bool:
	for r: Dictionary in md.roads():
		if int(r.get("lanes", 2)) <= 0 or bool(r.get("bridge", false)):
			continue
		var pts: PackedVector2Array = MapData.poly(r.get("points", []))
		var hw: float = float(r.get("width", 6.0)) * 0.5 + 0.3
		for i: int in range(pts.size() - 1):
			if Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1]).distance_to(p) <= hw:
				return true
	return false


func _on_physics_b() -> void:
	_pt0 = Time.get_ticks_usec()
	if done:
		return
	b_frames += 1
	var t: int = b_frames - b_t0
	var tr: RoamTraffic = roam.get("traffic") as RoamTraffic
	match b_phase:
		"settle":
			if t == 150:
				if not _check(tr != null, "FreeRoam must expose a traffic node"):
					return
				var player: Node3D = roam.get("player")
				var c := Vector2(player.global_position.x, player.global_position.z)
				var plot: PackedVector2Array = RoamTraffic._campus_plot()
				var md: MapData = MapData.load_default()
				var n150: int = 0
				for v: RoamTraffic.Vehicle in tr.vehicles:
					if not v.active:
						continue
					if v.pos.distance_to(c) <= 150.0:
						n150 += 1
					if not _check(not Geometry2D.is_point_in_polygon(v.pos, plot), "a vehicle drives inside the campus plot at %s" % v.pos):
						return
					if not _check(v.pos.distance_to(c) > 2.0, "a vehicle sits on the player"):
						return
					if v.conn.size() != 3 and not _check(_on_carriageway(md, v.pos), "vehicle at %s is off the carriageway" % v.pos):
						return
				for l: int in range(tr.lane_count()):
					for p: Vector2 in (tr.lane_pts[l] as PackedVector2Array):
						if not _check(not Geometry2D.is_point_in_polygon(p, plot), "lane %d enters the campus plot at %s" % [l, p]):
							return
				print("  FreeRoam traffic: %d active, %d within 150 m, %d lanes" % [tr.active_count(), n150, tr.lane_count()])
				if not _check(n150 >= 15, "at least 15 vehicles within 150 m of the BE6 spawn (got %d)" % n150):
					return
				var crowd: Node = roam.get("pedestrians")
				if crowd:
					crowd.process_mode = Node.PROCESS_MODE_DISABLED   # đo riêng xe chạy
				p_usec = 0
				p_n = 0
				timing = true
				b_phase = "perf_with"
				b_t0 = b_frames
		"perf_with":
			if t == 60:
				phys_with = float(p_usec) / float(maxi(1, p_n))
				tr.process_mode = Node.PROCESS_MODE_DISABLED
				p_usec = 0
				p_n = 0
				b_phase = "perf_without"
				b_t0 = b_frames
		"perf_without":
			if t == 60:
				phys_without = float(p_usec) / float(maxi(1, p_n))
				timing = false
				var cost_ms: float = (phys_with - phys_without) / 1000.0
				print("  traffic physics cost %.2f ms per physics frame (%.0f vs %.0f us)" % [cost_ms, phys_with, phys_without])
				if not _check(cost_ms < 1.5, "25 vehicles must cost < 1.5 ms per physics frame (got %.2f)" % cost_ms):
					return
				tr.process_mode = Node.PROCESS_MODE_INHERIT
				var crowd2: Node = roam.get("pedestrians")
				if crowd2:
					crowd2.process_mode = Node.PROCESS_MODE_INHERIT
				roam.call("mount_bike")
				b_phase = "bump_setup"
				b_t0 = b_frames
		"bump_setup":
			if t == 20:
				tr.set_physics_process(false)   # xe đứng yên làm vật cản
				var target_v: RoamTraffic.Vehicle = null
				for v2: RoamTraffic.Vehicle in tr.vehicles:
					if v2.active and v2.conn.size() != 3 and (target_v == null or v2.kind != RoamTraffic.Kind.MOTO):
						target_v = v2
				if not _check(target_v != null, "test setup: an active vehicle to bump"):
					return
				var bike: CharacterBody3D = roam.get("bike")
				var back: Vector2 = target_v.pos - target_v.dir * (target_v.half_len + 2.6)
				bike.global_position = Vector3(back.x, 0.3, back.y)
				bike.rotation = Vector3(0.0, atan2(-target_v.dir.x, -target_v.dir.y), 0.0)
				bike.velocity = Vector3.ZERO
				bike.set("current_speed_ms", 8.0)
				crashes = 0
				bike.connect("crash_occurred", func() -> void: crashes += 1)
				b_phase = "bump"
				b_t0 = b_frames
		"bump":
			var bk: Node3D = roam.get("bike")
			var bs: float = float(bk.get("current_speed_ms"))
			if crashes > 0 or t == 60:
				print("  bike bump: crashes %d, bike speed %.2f" % [crashes, bs])
				if not _check(crashes >= 1 and bs < 4.0, "the player's bike hitting a traffic vehicle uses the existing crash handling (crashes %d, speed %.2f)" % [crashes, bs]):
					return
				tr.set_physics_process(true)
				roam.call("set_time_of_day", "night")
				b_phase = "night"
				b_t0 = b_frames
		"night":
			if t == 90:
				var n: int = tr.active_count()
				print("  night traffic: %d active" % n)
				if not _check(n >= 1 and n <= roundi(25.0 * RoamTraffic.NIGHT_FACTOR), "night keeps 30 %% of the vehicles (active %d)" % n):
					return
				print("✅ SUCCESS: ROAM TRAFFIC (parts A + B)")
				done = true
				quit(0)


func _check(ok: bool, msg: String) -> bool:
	if not ok and not done:
		done = true
		print("❌ FAILED: ", msg)
		quit(2)
	return ok
```

Run: `godot --headless --path . --script tests/test_roam_traffic.gd > /tmp/t13.log 2>&1; grep -E "SUCCESS|FAILED|Identifier|Invalid call" /tmp/t13.log`
Expected: a failure naming `PropBuilder.build_car` or `RoamTraffic` (neither exists yet).

- [ ] **Step 2: `PropBuilder.build_car`**

In `scripts/PropBuilder.gd` add the header line `#   build_car(parent, paint, baked)                   ô tô con hatchback (xe chạy FreeRoam), mặt trước -Z` under the `build_bus` line, and add after `build_bus()`:

```gdscript
# ===========================================================================
# Ô TÔ CON (xe chạy FreeRoam)
# ===========================================================================
## Ô tô con kiểu hatchback ~3,9 x 1,7 x 1,5 m, mặt trước hướng -Z như xe máy / xe buýt; baked = 1 MeshInstance3D.
static func build_car(parent: Node3D, paint_color: Color, baked: bool = true) -> Node3D:
	var root := Node3D.new()
	root.name = "CarModel"
	var pm: Material = paint(paint_color)
	var dark: Material = black_plastic()
	var glass: Material = glass_dark()
	# thân dưới, nắp capô, khoang kính, mui
	CharacterBuilder._box(root, Vector3(0.0, 0.62, 0.0), Vector3(1.7, 0.62, 3.9), pm)
	CharacterBuilder._box(root, Vector3(0.0, 0.98, -1.25), Vector3(1.62, 0.12, 1.3), pm)
	CharacterBuilder._box(root, Vector3(0.0, 1.22, 0.25), Vector3(1.56, 0.6, 2.1), glass)
	CharacterBuilder._box(root, Vector3(0.0, 1.55, 0.3), Vector3(1.5, 0.08, 1.8), pm)
	for sx: float in [-1.0, 1.0]:
		CharacterBuilder._box(root, Vector3(sx * 0.79, 1.22, -0.78), Vector3(0.06, 0.58, 0.08), pm)      # trụ A
		CharacterBuilder._box(root, Vector3(sx * 0.79, 1.22, 1.27), Vector3(0.06, 0.58, 0.12), pm)       # trụ C
		CharacterBuilder._box(root, Vector3(sx * 0.86, 0.42, 0.0), Vector3(0.04, 0.16, 3.0), dark)       # ốp sườn
		CharacterBuilder._box(root, Vector3(sx * 0.62, 0.78, -1.96), Vector3(0.34, 0.14, 0.04), lens(Color("#FFF4C8"), 1.4))
		CharacterBuilder._box(root, Vector3(sx * 0.66, 0.85, 1.96), Vector3(0.28, 0.16, 0.04), lens(Color("#E53935"), 1.0))
		CharacterBuilder._box(root, Vector3(sx * 0.95, 1.1, -0.72), Vector3(0.14, 0.1, 0.2), dark)       # gương
	CharacterBuilder._box(root, Vector3(0.0, 0.42, -1.97), Vector3(1.72, 0.22, 0.08), dark)             # cản trước
	CharacterBuilder._box(root, Vector3(0.0, 0.42, 1.97), Vector3(1.72, 0.22, 0.08), dark)              # cản sau
	for z: float in [-1.25, 1.25]:
		for sx: float in [-1.0, 1.0]:
			build_wheel(root, Vector3(sx * 0.78, 0.32, z), 0.32, 0.2, 5, Color("#B0B6BC"))
	if baked:
		return bake_into(parent, root, "CarModel", Vector3.ZERO)
	parent.add_child(root)
	return root
```

- [ ] **Step 3: Implement `RoamTraffic`**

Create `scripts/roam/RoamTraffic.gd`:

```gdscript
# File: res://scripts/roam/RoamTraffic.gd
# Xe chạy trong FreeRoam (spec vice-people-and-movement, "Amendment 2026-10-22"): mặc định 25 xe ban ngày (đêm 30 %) –
# xe máy có người lái bake (người PS2 ở Vice City), vài ô tô và xe buýt – chạy theo làn bên phải lòng đường MapData
# (lanes > 0; bỏ đường nội bộ "service", cầu và lô campus), xuất hiện cách người chơi 40-150 m (ngoài tầm camera trước),
# ra ngoài 200 m thì cất đi rồi dùng lại thân xe ở chỗ khác (không dựng lại). Hết làn thì rẽ sang một làn đi ngang trong
# 9 m (đường cong Bezier bậc hai, 60 % tốc độ), không có thì quay đầu sang làn kia của chính đường đó, không có nữa thì cất
# xe. Nhìn trước: giảm tốc và dừng cách STOP_GAP sau xe khác, người đi đường, người chơi hoặc xe người chơi. Thân
# AnimatableBody3D nhóm "traffic_obstacle" (xe buýt thêm "slipstream_vehicle"): PlayerBike tông vào thì dùng xử lý va
# chạm sẵn có. Không dùng autoload ở đây.
class_name RoamTraffic
extends Node3D

enum Kind { MOTO, CAR, BUS }

const KIND_COUNT: Array[int] = [20, 3, 2]          # mặc định: 20 xe máy, 3 ô tô, 2 xe buýt
const KIND_SIZE: Array = [Vector3(0.7, 1.4, 1.9), Vector3(1.7, 1.5, 3.9), Vector3(2.5, 3.0, 7.5)]
const NIGHT_FACTOR: float = 0.3
const SPAWN_MIN: float = 40.0
const SPAWN_MAX: float = 150.0
const INITIAL_MIN: float = 20.0
const DESPAWN: float = 200.0
const LANE_STEP: float = 6.0
const MIN_LANE_LEN: float = 15.0
const EXIT_R: float = 9.0
const EXIT_MIN_LEFT: float = 8.0
const TURN_R: float = 4.0                         # rẽ bắt đầu ~TURN_R m trước điểm vào, vào làn mới TURN_R / 2 m sau nó
const PLOT_GROW: float = 3.0
const SEG_CELL: float = 16.0
const SPAWN_CELL: float = 32.0
const SPAWN_STEP: float = 10.0
const SPAWN_END_CLEAR: float = 8.0
const SPAWN_GAP: float = 14.0
const SPAWNS_PER_CHECK: int = 3
const CHECK_EVERY: float = 0.5
const LOOK_EVERY: int = 3
const LOOK_BASE: float = 6.0
const LOOK_PER_MS: float = 1.6
const LAT_PAD: float = 0.5
const STOP_GAP: float = 3.0
const ACCEL: float = 2.5
const BRAKE: float = 7.0
const TURN_FACTOR: float = 0.6
const STUCK_S: float = 5.0
const GHOST_S: float = 2.0
const VIEW_R: float = 160.0
const SPEED_BY_CLASS: Dictionary = {"motorway": 13.0, "primary": 11.0, "secondary": 10.0, "tertiary": 9.0}
const SPEED_DEFAULT: float = 6.5
const BUS_CLASSES: Array[String] = ["motorway", "primary", "secondary", "tertiary"]
const CAR_PAINTS: Array[Color] = [Color("#F4A6C0"), Color("#7FD8D2"), Color("#FFF1B5"), Color("#AFCBFF"), Color("#F2F4F5"), Color("#3A3F44"), Color("#E57373")]
const HELMETS: Array[Color] = [Color("#E74C3C"), Color("#F1C40F"), Color("#FFFFFF"), Color("#0984E3"), Color("#2C3E50")]


class Vehicle:
	var body: AnimatableBody3D
	var kind: int = 0
	var lane: int = -1
	var s: float = 0.0
	var speed: float = 0.0
	var cruise: float = 8.0
	var limit: float = 99.0
	var half_len: float = 1.0
	var half_w: float = 0.4
	var exit: Array = []                 # lối ra đã chọn của làn hiện tại: [làn, s_vào, back]
	var turn_at: float = 0.0             # s bắt đầu rẽ = độ dài làn - back
	var conn: PackedVector2Array = PackedVector2Array()   # Bezier bậc hai [p0, điểm điều khiển, p2] khi đang rẽ
	var conn_t: float = 0.0
	var conn_len: float = 1.0
	var next_lane: int = -1
	var next_s: float = 0.0
	var active: bool = false
	var pos: Vector2 = Vector2.ZERO
	var dir: Vector2 = Vector2(0.0, -1.0)
	var blocked_by: String = ""      # "car" | "ped" | "player" | ""
	var stuck_t: float = 0.0
	var ghost_t: float = 0.0


var md: MapData
var player: Node3D
var bike: Node3D
var roam: Node
var peds_fn: Callable
var vehicles: Array = []                 # Array[Vehicle]
var lane_pts: Array = []                 # Array[PackedVector2Array]
var lane_cum: Array = []                 # Array[PackedFloat32Array] (độ dài cộng dồn tại mỗi đỉnh)
var lane_len := PackedFloat32Array()
var lane_speed := PackedFloat32Array()
var lane_kinds := PackedByteArray()      # bit 1 << Kind
var lane_road := PackedInt32Array()
var lane_exits: Array = []               # Array của Array[[lane, s]]
var recycled: int = 0
var night: bool = false
var _spawn_hash: Dictionary = {}         # Vector2i -> Array[[lane, s]]
var _rng := RandomNumberGenerator.new()
var _check_t: float = 0.0
var _frame: int = 0
var _rot: int = 0


func setup(map_data: MapData, player_node: Node3D, opts: Dictionary = {}) -> void:
	md = map_data
	player = player_node
	bike = opts.get("bike", null)
	roam = opts.get("roam", null)
	peds_fn = opts.get("peds_fn", Callable())
	_rng.seed = int(opts.get("seed", 77))
	_build_lanes(opts.get("plot", _campus_plot()))
	if lane_pts.is_empty():
		push_warning("RoamTraffic: không có làn xe nào, tắt xe chạy")
		set_physics_process(false)
		return
	var kinds: Array = opts.get("kinds", [])
	if kinds.is_empty():
		for k: int in range(KIND_COUNT.size()):
			for i: int in range(KIND_COUNT[k]):
				kinds.append(k)
	for kind: Variant in kinds:
		vehicles.append(_make_vehicle(int(kind)))
	night = _is_night()
	_fill_initial()


func bodies() -> Array:
	return vehicles.map(func(v: Vehicle) -> AnimatableBody3D: return v.body)


func active_count() -> int:
	return vehicles.filter(func(v: Vehicle) -> bool: return v.active).size()


func lane_count() -> int:
	return lane_pts.size()


static func _campus_plot() -> PackedVector2Array:
	var xf: Transform3D = FPTUCampusBuilder.real_plot_transform()
	var pr: Rect2 = FPTUCampusBuilder.plot_rect().grow(PLOT_GROW)
	var out := PackedVector2Array()
	for c: Vector2 in [pr.position, Vector2(pr.end.x, pr.position.y), pr.end, Vector2(pr.position.x, pr.end.y)]:
		var w: Vector3 = xf * Vector3(c.x, 0.0, c.y)
		out.append(Vector2(w.x, w.z))
	return out


# ===========================================================================
# XE
# ===========================================================================
func _make_vehicle(kind: int) -> Vehicle:
	var c := Vehicle.new()
	c.kind = kind
	var size: Vector3 = KIND_SIZE[kind]
	c.half_len = size.z * 0.5
	c.half_w = size.x * 0.5
	var b := AnimatableBody3D.new()
	b.name = "Vehicle_%d" % vehicles.size()
	b.add_to_group("traffic_obstacle")
	if kind == Kind.BUS:
		b.add_to_group("slipstream_vehicle")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = Vector3(0.0, size.y * 0.5, 0.0)
	b.add_child(cs)
	match kind:
		Kind.MOTO:
			var paint: Color = FPTUCampusBuilder.BIKE_PAINTS[_rng.randi() % FPTUCampusBuilder.BIKE_PAINTS.size()]
			PropBuilder.build_scooter(b, Vector3.ZERO, 0.0, paint, {"baked": true, "name": "Scooter"})
			var ro: Dictionary = {"seed": _rng.randi(), "helmet_color": HELMETS[_rng.randi() % HELMETS.size()]}
			if _rng.randf() < 0.3:
				ro["backpack"] = true
			CharacterBuilder.build_baked_rider(b, Vector3(0.0, 0.32, 0.12), ro)
		Kind.CAR:
			PropBuilder.build_car(b, CAR_PAINTS[_rng.randi() % CAR_PAINTS.size()], true)
		Kind.BUS:
			PropBuilder.build_bus(b, _rng.randf() < 0.5, true)
	add_child(b)
	c.body = b
	_park(c)
	return c


## Cất xe: ẩn, tắt xử lý (thân bị gỡ khỏi không gian vật lý), đặt xa dưới đất.
func _park(c: Vehicle) -> void:
	c.active = false
	c.speed = 0.0
	c.body.visible = false
	c.body.process_mode = Node.PROCESS_MODE_DISABLED
	c.body.position = Vector3(0.0, -200.0, 0.0)


func _activate(c: Vehicle, l: int, s: float) -> void:
	c.lane = l
	c.s = s
	c.conn = PackedVector2Array()
	_choose_exit(c)
	var f: float = _rng.randf_range(0.85, 1.15) if c.kind == Kind.MOTO else (_rng.randf_range(0.9, 1.05) if c.kind == Kind.CAR else 0.8)
	c.cruise = lane_speed[l] * f
	c.speed = c.cruise * 0.6
	c.limit = 99.0
	c.stuck_t = 0.0
	c.ghost_t = 0.0
	c.blocked_by = ""
	c.active = true
	c.body.process_mode = Node.PROCESS_MODE_INHERIT
	c.body.visible = true
	_place(c, 1.0)


func _fill_initial() -> void:
	var c3: Vector3 = _center()
	var c2 := Vector2(c3.x, c3.z)
	var target: int = roundi(float(vehicles.size()) * (NIGHT_FACTOR if night else 1.0))
	var active: int = 0
	for c: Vehicle in vehicles:
		if active >= target:
			break
		var spot: Array = _random_spot(c2, INITIAL_MIN, SPAWN_MAX, c.kind, false)
		if spot.is_empty():
			continue
		_activate(c, int(spot[0]), float(spot[1]))
		active += 1


## Mỗi CHECK_EVERY: cất xe ra ngoài DESPAWN, đêm thì cất xe xa nhất cho còn 30 %, thiếu thì đưa xe đang cất ra (tối đa
## SPAWNS_PER_CHECK, xoay vòng điểm bắt đầu để mọi loại xe đều được dùng).
func _maintain() -> void:
	var c3: Vector3 = _center()
	var c2 := Vector2(c3.x, c3.z)
	night = _is_night()
	var target: int = roundi(float(vehicles.size()) * (NIGHT_FACTOR if night else 1.0))
	var live: Array = []
	for c: Vehicle in vehicles:
		if not c.active:
			continue
		if c.pos.distance_to(c2) > DESPAWN:
			_park(c)
			recycled += 1
		else:
			live.append(c)
	if live.size() > target:
		live.sort_custom(func(a: Vehicle, b: Vehicle) -> bool: return a.pos.distance_to(c2) > b.pos.distance_to(c2))
		for i: int in range(live.size() - target):
			_park(live[i])
			recycled += 1
		return
	var n: int = vehicles.size()
	var active: int = live.size()
	var made: int = 0
	for k: int in range(n):
		if active >= target or made >= SPAWNS_PER_CHECK:
			break
		var c: Vehicle = vehicles[(_rot + k) % n]
		if c.active:
			continue
		var spot: Array = _random_spot(c2, SPAWN_MIN, SPAWN_MAX, c.kind, true)
		if spot.is_empty():
			continue
		_activate(c, int(spot[0]), float(spot[1]))
		active += 1
		made += 1
	_rot = (_rot + 7) % maxi(1, n)


func _physics_process(delta: float) -> void:
	_frame += 1
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = CHECK_EVERY
		_maintain()
	var obs: Array = []
	var gathered: bool = false
	for i: int in range(vehicles.size()):
		var c: Vehicle = vehicles[i]
		if not c.active:
			continue
		if (_frame + i) % LOOK_EVERY == 0:
			if not gathered:
				obs = _obstacles()
				gathered = true
			c.limit = _look_ahead(c, obs)
		var target: float = minf(c.cruise * (TURN_FACTOR if c.conn.size() == 3 else 1.0), c.limit)
		c.speed = move_toward(c.speed, target, (ACCEL if target > c.speed else BRAKE) * delta)
		if c.speed < 0.2 and c.blocked_by == "car":
			c.stuck_t += delta
			if c.stuck_t > STUCK_S:
				c.ghost_t = GHOST_S       # kẹt ở ngã tư với xe khác: bỏ qua xe khác 2 s (vẫn dừng trước người)
				c.stuck_t = 0.0
		else:
			c.stuck_t = 0.0
		c.ghost_t = maxf(0.0, c.ghost_t - delta)
		_advance(c, c.speed * delta)
		if c.active:
			_place(c, delta)


## Vật cản cho nhìn trước: [vị trí, nửa dài, nửa rộng, loại, xe].
func _obstacles() -> Array:
	var out: Array = []
	for c: Vehicle in vehicles:
		if c.active:
			out.append([c.pos, c.half_len, c.half_w, "car", c])
	if peds_fn.is_valid():
		for p: Variant in peds_fn.call():
			if is_instance_valid(p) and (p as Node3D).is_inside_tree():
				var pn: Node3D = p
				out.append([Vector2(pn.global_position.x, pn.global_position.z), 0.3, 0.3, "ped", null])
	var mounted: bool = roam != null and bool(roam.get("mounted"))
	var who: Node3D = bike if mounted else player
	if who != null and who.is_inside_tree():
		out.append([Vector2(who.global_position.x, who.global_position.z), 1.0 if mounted else 0.4, 0.45 if mounted else 0.4, "player", null])
	if not mounted and bike != null and bike.visible and bike.is_inside_tree():
		out.append([Vector2(bike.global_position.x, bike.global_position.z), 1.0, 0.45, "bike", null])   # xe người chơi đang đỗ
	return out


## Tốc độ cho phép theo khoảng hở tới vật cản gần nhất trong dải phía trước (dừng hẳn khi khe <= STOP_GAP).
func _look_ahead(c: Vehicle, obs: Array) -> float:
	var look: float = LOOK_BASE + c.speed * LOOK_PER_MS
	if c.conn.size() != 3 and not c.exit.is_empty():
		look = minf(look, maxf(c.turn_at - c.s, 0.0) + LOOK_BASE)   # sắp rẽ: không nhìn thẳng qua ngã tư tới lề bên kia
	var reach2: float = (look + 8.0) * (look + 8.0)
	var best: float = INF
	c.blocked_by = ""
	for o: Array in obs:
		if o[4] == c or (c.ghost_t > 0.0 and String(o[3]) == "car"):
			continue
		var rel: Vector2 = (o[0] as Vector2) - c.pos
		if rel.length_squared() > reach2:
			continue
		var fwd: float = rel.dot(c.dir)
		if fwd <= 0.0:
			continue
		var gap: float = fwd - c.half_len - float(o[1])
		if gap > look:
			continue
		if absf(rel.cross(c.dir)) > c.half_w + float(o[2]) + LAT_PAD:
			continue
		if gap < best:
			best = gap
			c.blocked_by = String(o[3])
	if best == INF:
		return 99.0
	if best <= STOP_GAP:
		return 0.0
	return sqrt(BRAKE * (best - STOP_GAP))


func _advance(c: Vehicle, dist: float) -> void:
	if c.conn.size() == 3:
		c.conn_t += dist / c.conn_len
		if c.conn_t < 1.0:
			return
		dist = (c.conn_t - 1.0) * c.conn_len
		c.lane = c.next_lane
		c.s = c.next_s
		c.conn = PackedVector2Array()
		_choose_exit(c)
	c.s += dist
	if c.s < c.turn_at:
		return
	if c.exit.is_empty():
		_park(c)
		recycled += 1
		return
	var over: float = c.s - c.turn_at
	var nl: int = int(c.exit[0])
	var ns: float = float(c.exit[1])
	var p0: Vector2 = _lane_point(c.lane, c.turn_at)
	var d0: Vector2 = _lane_dir(c.lane, c.turn_at)
	var p2: Vector2 = _lane_point(nl, ns)
	var d2: Vector2 = _lane_dir(nl, ns)
	var chord: float = p0.distance_to(p2)
	var ctrl: Vector2 = p0 + d0 * chord * 0.5
	var den: float = d0.cross(d2)
	if absf(den) > 0.2:
		var a: float = (p2 - p0).cross(d2) / den   # giao của tia ra (p0, d0) và tia vào (p2, -d2)
		if a > 0.0 and a < chord * 1.5:
			ctrl = p0 + d0 * a
	c.conn = PackedVector2Array([p0, ctrl, p2])
	c.conn_len = maxf(0.5, (chord + p0.distance_to(ctrl) + ctrl.distance_to(p2)) * 0.5)
	c.conn_t = over / c.conn_len
	c.next_lane = nl
	c.next_s = ns


## Chọn lối ra của làn vừa vào (theo loại xe); rẽ bắt đầu ở turn_at = độ dài làn - back (không có lối ra: cuối làn).
func _choose_exit(c: Vehicle) -> void:
	c.exit = _pick_exit(c)
	c.turn_at = lane_len[c.lane] - (float(c.exit[2]) if not c.exit.is_empty() else 0.0)


func _pick_exit(c: Vehicle) -> Array:
	var opts: Array = []
	for ex: Array in lane_exits[c.lane]:
		if lane_kinds[int(ex[0])] & (1 << c.kind):
			opts.append(ex)
	if opts.is_empty():
		return []
	return opts[_rng.randi_range(0, opts.size() - 1)]


func _place(c: Vehicle, delta: float) -> void:
	if c.conn.size() == 3:
		var t: float = clampf(c.conn_t, 0.0, 1.0)
		var u: float = 1.0 - t
		c.pos = c.conn[0] * u * u + c.conn[1] * 2.0 * u * t + c.conn[2] * t * t
		var dv: Vector2 = (c.conn[1] - c.conn[0]) * 2.0 * u + (c.conn[2] - c.conn[1]) * 2.0 * t
		if dv.length_squared() > 0.0001:
			c.dir = dv.normalized()
	else:
		c.pos = _lane_point(c.lane, c.s)
		c.dir = _lane_dir(c.lane, c.s)
	var yaw: float = lerp_angle(c.body.rotation.y, atan2(-c.dir.x, -c.dir.y), minf(1.0, delta * 10.0))
	c.body.global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(c.pos.x, MapBuilder.ROAD_Y, c.pos.y))


# ===========================================================================
# LÀN XE
# ===========================================================================
func _build_lanes(plot: PackedVector2Array) -> void:
	var road_i: int = 0
	for r: Dictionary in md.roads():
		road_i += 1
		var cls: String = String(r.get("class", ""))
		if int(r.get("lanes", 2)) <= 0 or bool(r.get("bridge", false)) or cls == "service":
			continue
		var pts: PackedVector2Array = MapData.poly(r.get("points", []))
		if pts.size() < 2:
			continue
		cls = String(MapBuilder.CLASS_ALIAS.get(cls, cls))
		var w: float = float(r.get("width", 6.0))
		var sp: float = float(SPEED_BY_CLASS.get(cls, SPEED_DEFAULT))
		var kinds: int = 1 << Kind.MOTO
		if w >= 6.0:
			kinds |= 1 << Kind.CAR
		if w >= 7.0 and BUS_CLASSES.has(cls):
			kinds |= 1 << Kind.BUS
		if bool(r.get("oneway", false)):
			_add_lane(pts, plot, sp, kinds, road_i)
		else:
			_add_lane(PedWalkGraph._offset(pts, w * 0.25), plot, sp, kinds, road_i)
			var rev: PackedVector2Array = pts.duplicate()
			rev.reverse()
			_add_lane(PedWalkGraph._offset(rev, w * 0.25), plot, sp, kinds, road_i)
	_link_lanes()
	_index_spawn_points()


## Lấy mẫu làn mỗi LANE_STEP m, cắt làn ở chỗ đi vào lô campus (mỗi đoạn ngoài lô thành một làn riêng).
func _add_lane(pts: PackedVector2Array, plot: PackedVector2Array, speed: float, kinds: int, road: int) -> void:
	var piece := PackedVector2Array()
	for i: int in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n: int = maxi(1, ceili(a.distance_to(b) / LANE_STEP))
		for k: int in range(0 if i == 0 else 1, n + 1):
			var p: Vector2 = a.lerp(b, float(k) / float(n))
			if plot.size() >= 3 and Geometry2D.is_point_in_polygon(p, plot):
				_commit_lane(piece, speed, kinds, road)
				piece = PackedVector2Array()
				continue
			piece.append(p)
	_commit_lane(piece, speed, kinds, road)


func _commit_lane(piece: PackedVector2Array, speed: float, kinds: int, road: int) -> void:
	if piece.size() < 2:
		return
	var cum := PackedFloat32Array([0.0])
	for i: int in range(1, piece.size()):
		cum.append(cum[i - 1] + piece[i - 1].distance_to(piece[i]))
	if cum[cum.size() - 1] < MIN_LANE_LEN:
		return
	lane_pts.append(piece)
	lane_cum.append(cum)
	lane_len.append(cum[cum.size() - 1])
	lane_speed.append(speed)
	lane_kinds.append(kinds)
	lane_road.append(road)


## Lối ra ở cuối mỗi làn: làn khác (khác đường) đi ngang trong EXIT_R, điểm vào còn >= EXIT_MIN_LEFT m, không ngược chiều
## gắt; không có thì quay đầu sang đầu làn kia của chính đường đó (ngõ cụt, mép lô campus). Mỗi lối ra [làn, s_vào, back]:
## rẽ bắt đầu back = TURN_R - (q - e)·hướng m trước cuối làn (rẽ phải ở ngã tư: q nằm SAU cuối làn vì làn OSM dừng ở tâm
## giao lộ) và vào làn mới TURN_R / 2 m sau q, nên đường cong luôn đi tới.
func _link_lanes() -> void:
	var seg_hash: Dictionary = {}
	for l: int in range(lane_pts.size()):
		var pts: PackedVector2Array = lane_pts[l]
		for i: int in range(pts.size() - 1):
			var bb := Rect2(pts[i], Vector2.ZERO).expand(pts[i + 1])
			for cx: int in range(floori(bb.position.x / SEG_CELL), floori(bb.end.x / SEG_CELL) + 1):
				for cz: int in range(floori(bb.position.y / SEG_CELL), floori(bb.end.y / SEG_CELL) + 1):
					var key := Vector2i(cx, cz)
					if not seg_hash.has(key):
						seg_hash[key] = []
					(seg_hash[key] as Array).append(Vector2i(l, i))
	var reach: int = ceili(EXIT_R / SEG_CELL)
	for l: int in range(lane_pts.size()):
		var pts: PackedVector2Array = lane_pts[l]
		var e: Vector2 = pts[pts.size() - 1]
		var de: Vector2 = (e - pts[pts.size() - 2]).normalized()
		var best: Dictionary = {}     # làn -> [s_vào, khoảng cách, back]
		var uturn: Array = []
		var c0 := Vector2i(floori(e.x / SEG_CELL), floori(e.y / SEG_CELL))
		for dx: int in range(-reach, reach + 1):
			for dz: int in range(-reach, reach + 1):
				for li: Vector2i in seg_hash.get(Vector2i(c0.x + dx, c0.y + dz), []):
					var m: int = li.x
					if m == l:
						continue
					var mp: PackedVector2Array = lane_pts[m]
					var a: Vector2 = mp[li.y]
					var b: Vector2 = mp[li.y + 1]
					var q: Vector2 = Geometry2D.get_closest_point_to_segment(e, a, b)
					var d: float = q.distance_to(e)
					if d > EXIT_R:
						continue
					var back: float = clampf(TURN_R - (q - e).dot(de), 0.0, maxf(0.0, lane_len[l] - 1.0))
					var s: float = float((lane_cum[m] as PackedFloat32Array)[li.y]) + a.distance_to(q)
					var s_in: float = minf(s + TURN_R * 0.5, lane_len[m] - 1.0)
					if lane_road[m] == lane_road[l]:
						if li.y == 0 and uturn.is_empty():
							uturn = [m, s_in, back]
						continue
					if lane_len[m] - s < EXIT_MIN_LEFT or de.dot((b - a).normalized()) < -0.3:
						continue
					if not best.has(m) or d < float((best[m] as Array)[1]):
						best[m] = [s_in, d, back]
		var ex: Array = []
		for m: int in best.keys():
			var bm: Array = best[m]
			ex.append([m, float(bm[0]), float(bm[2])])
		if ex.is_empty() and not uturn.is_empty():
			ex.append(uturn)
		lane_exits.append(ex)


func _index_spawn_points() -> void:
	for l: int in range(lane_pts.size()):
		var s: float = 0.0
		while s < lane_len[l] - SPAWN_END_CLEAR:
			var p: Vector2 = _lane_point(l, s)
			var key := Vector2i(floori(p.x / SPAWN_CELL), floori(p.y / SPAWN_CELL))
			if not _spawn_hash.has(key):
				_spawn_hash[key] = []
			(_spawn_hash[key] as Array).append([l, s])
			s += SPAWN_STEP


func _seg_at(l: int, s: float) -> int:
	var cum: PackedFloat32Array = lane_cum[l]
	return clampi(cum.bsearch(s, true) - 1, 0, cum.size() - 2)


func _lane_point(l: int, s: float) -> Vector2:
	var pts: PackedVector2Array = lane_pts[l]
	var cum: PackedFloat32Array = lane_cum[l]
	var i: int = _seg_at(l, s)
	var seg: float = maxf(cum[i + 1] - cum[i], 0.001)
	return pts[i].lerp(pts[i + 1], clampf((s - cum[i]) / seg, 0.0, 1.0))


func _lane_dir(l: int, s: float) -> Vector2:
	var pts: PackedVector2Array = lane_pts[l]
	var i: int = _seg_at(l, s)
	return (pts[i + 1] - pts[i]).normalized()


## Chỗ xuất hiện ngẫu nhiên [làn, s] cách c2 từ r_min tới r_max (rải đều theo diện tích qua ô băm điểm mẫu), làn cho
## phép loại xe, cách xe đang chạy SPAWN_GAP; avoid_view: 12 lần thử đầu bỏ chỗ trong tầm camera.
func _random_spot(c2: Vector2, r_min: float, r_max: float, kind: int, avoid_view: bool) -> Array:
	for k: int in range(16):
		var ang: float = _rng.randf() * TAU
		var r: float = sqrt(_rng.randf_range(r_min * r_min, r_max * r_max))
		var q: Vector2 = c2 + Vector2(cos(ang), sin(ang)) * r
		var cell: Array = _spawn_hash.get(Vector2i(floori(q.x / SPAWN_CELL), floori(q.y / SPAWN_CELL)), [])
		if cell.is_empty():
			continue
		var cand: Array = cell[_rng.randi_range(0, cell.size() - 1)]
		var l: int = int(cand[0])
		if not (lane_kinds[l] & (1 << kind)):
			continue
		var p: Vector2 = _lane_point(l, float(cand[1]))
		var d: float = p.distance_to(c2)
		if d < r_min or d > r_max or not _clear_of_vehicles(p, SPAWN_GAP):
			continue
		if avoid_view and k < 12 and _in_view(Vector3(p.x, 1.0, p.y)):
			continue
		return [l, float(cand[1])]
	return []


func _clear_of_vehicles(p: Vector2, r: float) -> bool:
	for c: Vehicle in vehicles:
		if c.active and c.pos.distance_to(p) < r:
			return false
	return true


func _in_view(p: Vector3) -> bool:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam != null and cam.global_position.distance_to(p) < VIEW_R and cam.is_position_in_frustum(p)


func _center() -> Vector3:
	var mounted: bool = roam != null and bool(roam.get("mounted"))
	if mounted and bike:
		return bike.global_position
	return player.global_position if player else Vector3.ZERO


func _is_night() -> bool:
	return roam != null and String(roam.get("tod_preset")) == "night"
```

Wire it into `scripts/FreeRoam.gd`:
- Add `var traffic: RoamTraffic` next to `var pedestrians: PedestrianSpawner`.
- Extend the block at the end of `_ready()` to:

```gdscript
	if crowd_enabled:
		_build_pedestrians()
		_build_traffic()
```

and add the function:

```gdscript
## Xe chạy (spec vice-people-and-movement, Amendment 2026-10-22): làn bên phải, dừng trước người / xe; camera đi xuyên xe.
func _build_traffic() -> void:
	traffic = RoamTraffic.new()
	traffic.name = "Traffic"
	add_child(traffic)
	var opts: Dictionary = {"bike": bike, "roam": self}
	if pedestrians:
		opts["peds_fn"] = pedestrians.pedestrians
	traffic.setup(md, player, opts)
	for b: Variant in traffic.bodies():
		var body: CollisionObject3D = b
		if player and player.cam_ray:
			player.cam_ray.add_exception(body)
		if bike and bike.spring_arm:
			bike.spring_arm.add_excluded_object(body.get_rid())
```

Run: `godot --headless --import --path . > /tmp/imp.log 2>&1; grep -c RoamTraffic .godot/global_script_class_cache.cfg` — expected ≥ 2.

- [ ] **Step 4: Run the tests**

Run: `godot --headless --path . --script tests/test_roam_traffic.gd > /tmp/t13.log 2>&1; grep -E "build_car|lane changes|stopped|600 m|back at|night|FreeRoam traffic|physics cost|bike bump|SUCCESS|FAILED" /tmp/t13.log`
Expected: every diagnostic in range, then `✅ SUCCESS: ROAM TRAFFIC (parts A + B)`.
Run `tests/test_pedestrians.gd` again (part C now runs with traffic on the roads) and `tests/test_free_roam.gd` (crowd and traffic off) — both SUCCESS.

- [ ] **Step 5: Preview**

Re-run the Task 12 preview command. The three `vice_roam_peds_*.png` images now show traffic: PS2 riders on scooters, a few pastel cars and buses keeping to the right-hand lane. Check that fps stays ≥ 45 at all three spots, and write the numbers in the report.

- [ ] **Step 6: Regression and commit**

Run the regression command (all green), then:

```bash
git add scripts/roam/RoamTraffic.gd scripts/PropBuilder.gd scripts/FreeRoam.gd tests/test_roam_traffic.gd tests/support/stub_roam.gd docs/preview/vice_roam_peds_*.png
git commit -m "feat(traffic): ambient FreeRoam traffic - motorbikes with PS2 riders, cars and buses on right-hand lanes of the real roads, Bezier turns and dead-end U-turns, look-ahead stops for vehicles/pedestrians/player, recycling beyond 200 m, night 30 %; PropBuilder.build_car

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 14: Docs, final regression and fps table

**Files:**
- Modify:
  - `README.md` (Vietnamese, player-facing);
  - `PLAN.md` (new section, English);
  - `docs/superpowers/plans/2026-10-22-vice-city-art-direction.md` (D3 and VC-6 notes);
  - `docs/superpowers/specs/2026-10-22-vice-people-and-movement-design.md` (status line and implementation notes).

**Interfaces:**
- Consumes: everything above. Produces: docs only.

- [ ] **Step 1: README**

In `README.md`, in the controls section, add the on-foot keys: `Shift` (chạy nước rút, có thể lực), `Ctrl` (đi bộ), `Space` (nhảy; trên xe vẫn là drift). Under the Vice City / open-world part add one paragraph:

"Ở phong cách Vice City, mọi nhân vật là người kiểu PS2: tỉ lệ người thật, đầu ít mặt với gương mặt vẽ tay bằng code (8 biểu cảm), quần áo giữ nguyên. Thế giới mở đông người hơn: sinh viên kín sân trường, cư dân dạo phố Vinhomes (có người chạy bộ, người tản bộ), người đi bộ trên lề các tuyến đường, nhìn xa vẫn thấy dòng người; xe máy, ô tô và xe buýt chạy đúng làn bên phải và dừng lại khi có người chắn đường. Ban đêm vắng hơn. Va nhẹ thì người đi đường lảo đảo càu nhàu, chạy nước rút hay đi xe tông thì họ ngã rồi đứng dậy bỏ chạy. Rơi từ cao không mất máu: dưới 2,5 m nhún gối, 2,5-6 m lăn, cao hơn thì nằm một lúc rồi đứng dậy."

- [ ] **Step 2: PLAN.md, vice plan, spec**

Add to `PLAN.md` a section "XIV. VICE PEOPLE AND GTA-STYLE MOVEMENT" (English). It covers:
- what was built: PS2Head, ps2 mode, rigged poses/bake, locomotion layer, controller states, the walk graph with zones, pedestrians with walk profiles, crowd impostors, the three-tier spawner and the traffic;
- the controls and the landing thresholds;
- the crowd numbers (tiers, zone targets, night factor);
- the commit hashes of Tasks 1-13 (`git log --oneline`).

In the vice plan:
- In the owner-decision table, change D3 to "Superseded by docs/superpowers/specs/2026-10-22-vice-people-and-movement-design.md: PS2 people at realistic scale".
- Under Task VC-6, add "Outfit items dropped by the owner (clothes unchanged); vehicle paint stays".

In the spec, change the status line to "Implemented (commits ...)" and add a short "Implementation notes" list:
- **Walk graph.**
  - `PedWalkGraph.random_point_ring` replaces `random_point_near`. It makes area-uniform tries through the spatial hash, so it stays cheap for the 150-220 m impostor ring, and returns a node id or -1.
  - The graph is built once per MapData and copied for each FreeRoam entry.
  - Water and building checks go through 64 m hashes; the building hash is MapBuilder's OSM index.
  - Verge lines run behind the kerb, because MapBuilder draws kerbs, not sidewalks, along carriageways. One-way roads get only the right-hand verge, because their left side is a median.
  - The BE6 plaza is a ring 6 m outside the tower. Campus paths avoid the fenced pitch and the parking posts, and reach the courtyard through the lobby and the back gap.
- **Identity.** Walker identity is `{v, preset, seed, female, profile, wseed, wid}`, drawn from 24 fixed crowd variants (8 per zone). Impostor and pedestrian share it, so promotion and demotion never change a walker. Impostor bakes are cached statically per art style.
- **Spawner.**
  - Pedestrians are pooled per variant (at most 24 detached).
  - Builds and promotions are limited to 2 per 0.25 s and at most one per physics frame.
  - In-view impostors inside 90 m are always promoted (up to 80), so none freezes in sight. Extra pedestrians are released only out of view.
  - A teleport of more than 120 m refills at once, and switching day/night trims at once.
  - Mid tier: no physics, no shadows, a floor snap every 30 physics frames. The total cap is 80 with near ≤ 40, so the mid tier takes the rest; the spec's separate mid cap of 40 is not enforced.
  - Near pedestrians step up kerbs and slabs like the player.
  - Idle pedestrians use a new standing `phone_stand` pose; the old `phone` clip is seated.
  - Bike contact is measured to the bike capsule's axis.
- **Traffic.**
  - `RoamTraffic` lanes are right-hand offsets of the OSM centrelines (two-way roads) or the centreline (one-way roads).
  - Exits link lane ends to lanes passing within 9 m. A turn starts `TURN_R - (q - e)·dir` before the lane end, so right turns at junctions never run backwards. A lane with no exit U-turns.
  - The player's parked bike is an obstacle.
  - PlayerBike's near-miss whoosh and the bus slipstream boost now also work against FreeRoam traffic (intended).
- **Tests.**
  - `FreeRoam.crowd_enabled = false` keeps `tests/test_free_roam.gd` deterministic.
  - Headless tests count physics frames, because headless renders about 145 fps.
  - Physics cost is timed directly (`physics_frame` to a last-priority node), because `Performance.TIME_PHYSICS_PROCESS` is a once-per-second maximum.
  - The vice-path tests live in `tests/test_ps2_people.gd`; crowds and traffic are in `tests/test_pedestrians.gd`, `tests/test_crowd_impostors.gd` and `tests/test_roam_traffic.gd`.
- A sprint jump covers about 4-4.5 m.

- [ ] **Step 3: Final regression and fps table**

Run the regression command; every line must be green. Then, on main after the merge, run the windowed previews once more with `PREVIEW_NOVSYNC=1`:
- `tests/preview_stages.gd` with `PREVIEW_ONLY=menu,s1,s2,s3,s4,s5,s6,ex`;
- `tests/preview_peds.gd`.

Collect the `fps=` numbers into a table in the PLAN.md section. The gates are menu ≥ 60, stages ≥ 45, and FreeRoam with full daytime density ≥ 45 at the BE6 spawn, the campus main gate and on Nguyễn Xiển.

- [ ] **Step 4: Commit**

```bash
git add README.md PLAN.md docs/superpowers/plans/2026-10-22-vice-city-art-direction.md docs/superpowers/specs/2026-10-22-vice-people-and-movement-design.md
git commit -m "docs: vice people, GTA-style movement, crowds and traffic - README controls and world notes, PLAN section with fps table, spec status and implementation notes, vice plan D3/VC-6 notes

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
