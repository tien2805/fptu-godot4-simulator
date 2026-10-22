# Vice People and GTA-style Movement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** PS2-era Vice City-like people (realistic proportions, low-poly heads with painted faces) in the vice art style, GTA-style on-foot movement for the FreeRoam player, and wandering pedestrians that react to bumps and bike hits.

**Architecture:** `CharacterBuilder` gains a `ps2` mode (set by GameFX for the vice style) that builds every preset on the Quaternius rigged body with a new code-built `PS2Head` (faceted mesh, Pillow face atlas with 8 expression cells switched through `uv1_offset`). `RigAnimator` gets a locomotion layer (sprint overlay, lean, idle fidgets) and new clips (jump, fall, land, skid, stumble, knockdown, get-up). `ThirdPersonController` becomes a small movement state machine. Three new FreeRoam classes add pedestrians: `PedWalkGraph` (walk network from MapData), `Pedestrian` (CharacterBody3D with reactions) and `PedestrianSpawner` (spawn ring, recycling, speech bubbles).

**Tech Stack:** Godot 4.7.2, pure GDScript, Pillow/numpy (code-drawn textures), headless SceneTree tests, windowed preview scripts.

**Spec:** `docs/superpowers/specs/2026-10-22-vice-people-and-movement-design.md` (owner-approved). Owner decisions P-D1..P-D8 there are binding.

## Global Constraints

- Pure GDScript, Godot 4.2+ API; no C#, no plugins or addons; keep folder structure, scene names and `class_name`s.
- No AI-generated images; textures only drawn by code (Pillow); every new PNG gets an `.import` stub with `importer="keep"` and is loaded through `CharacterBuilder._tex()` (FileAccess) so exported builds work.
- Style homage only: no Rockstar assets, fonts, logos, names. Never a real person's likeness. Pedestrian lines are fictional and mild.
- `class_name` scripts never write the identifiers `GameFX` or `StageManager` (`CharacterBuilder.gd`, `PS2Head.gd`, `PedWalkGraph.gd`, `Pedestrian.gd`, `PedestrianSpawner.gd`, `ThirdPersonController.gd`, `MapBuilder.gd`, `MapData.gd`, `FPTUCampusBuilder.gd`). Read settings through `get_node_or_null("/root/GameFX")`.
- Models change only in vice (`CharacterBuilder.ps2 == true`); classic characters stay exactly as today (P-D2). Movement and pedestrians apply in both styles (P-D3). Clothing unchanged (P-D8).
- Controls (P-D4): jog by default; hold Shift = sprint with 6 s stamina; hold Ctrl = walk; Space = jump on foot (Space stays "drift" on the bike); F, E, T, M, Z, C, Esc unchanged.
- Falls never hurt (P-D5): < 2.5 m soft landing, 2.5..6 m roll, > 6 m splat 1.5 s then get up. Hitting pedestrians has no penalty (P-D6). Pedestrians only in FreeRoam (P-D7).
- Performance gates (RTX 4050, 1280x720, quality 2, V-Sync off): FreeRoam with 24 pedestrians >= 45 fps at the BE6 spawn and the campus gate; every stage >= 45 fps; building one character < 15 ms after the first.
- Headless safety: no RenderingDevice work when `DisplayServer.get_name() == "headless"`.
- Test hygiene: never pipe Godot output through `head`/`grep` directly (redirect to a log, then grep); a failed `assert` inside `_initialize` hangs `--script` runs, so tests use a `_check(cond, msg)` helper that prints and calls `quit(2)`; if Godot exits 139 right after a SUCCESS line, re-run once (known shutdown crash).
- A fresh git worktree has no `.godot` cache: run `godot --headless --import --path .` before any test, and again after adding a new `class_name` script; confirm the class appears in `.godot/global_script_class_cache.cfg`. Do the same on main after every merge.
- Write files that contain Vietnamese text with the file tools, never bash heredocs. Python printing Vietnamese needs `PYTHONIOENCODING=utf-8`.
- Full regression after every task: `godot --headless --quit --check-only --path .` (0 `ERROR`), `tests/smoke_all_stages.gd` (0 `ERROR:` / `SCRIPT ERROR`), and every `tests/test_*.gd` (list: `ls tests/test_*.gd`). Commit after every green task; commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never push, tag or release.
- Scheduling: Tasks 1-7 only touch character, controller and texture files and may run before the VC-2/VC-4 branches merge. Tasks 8-12 edit `scripts/FreeRoam.gd` and must start after VC-2 and VC-4 are merged into main.

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
| `scripts/CharacterBuilder.gd` | modify | `ps2` mode, rigged-for-all routing, PS2 head on rigged and code bodies, attach pivots, face-cell blink and expressions, rigged `pose()`/`bake()`, PS2 baked riders, new clips, RigAnimator locomotion layer |
| `scripts/GameFX.gd` | modify (1 function) | `_apply_art_style_statics()` sets `CharacterBuilder.ps2` and head scale |
| `scripts/ThirdPersonController.gd` | modify | Movement state machine, stamina, jump/landing, lean, camera FOV/bob/shake, `walk`/`jump` actions |
| `scripts/roam/PedWalkGraph.gd` | create | Walk network from MapData with spatial queries |
| `scripts/roam/Pedestrian.gd` | create | Pedestrian body, wandering, contact detection, reactions, lines |
| `scripts/roam/PedestrianSpawner.gd` | create | Spawn ring, recycling, LOD, speech bubble, hit consequences |
| `scripts/FreeRoam.gd` | modify | Stamina bar and hint text, pedestrian spawner wiring |
| `tests/test_ps2_textures.gd`, `tests/test_ps2_head.gd`, `tests/test_ps2_people.gd`, `tests/test_locomotion_anim.gd`, `tests/test_locomotion.gd`, `tests/test_pedestrians.gd` | create | Headless tests |
| `tests/test_free_roam.gd` | modify | Jump checks near water guards |
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
# Không dùng GameFX / StageManager ở đây (class_name biên dịch trước autoload khi chạy test --script).
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
  - In ps2 mode `build(opts)` returns a rigged body (meta `rigged` = true, `ps2_head` = true) unless `opts.rigged == false`; the rig contains every key of the code body: `hips, torso, neck, head, head_top, shoulder_l/r, elbow_l/r, hand_l/r, thigh_l/r, knee_l/r, foot_l/r, chest, face_mesh, torso_mesh`. The limb/torso/neck keys are attach pivots (Node3D at the joint, axes = character axes in the rest pose, following the bone); rotating them does not move bones.
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
- Produces (used by Tasks 8, 10, 11):
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

### Task 9: `PedWalkGraph`

**Files:**
- Create: `scripts/roam/PedWalkGraph.gd`
- Create: `tests/test_pedestrians.gd` (part A only in this task)

**Interfaces:**
- Consumes: `MapData`, `MapBuilder._water_polygons(md)`, `MapBuilder.is_msft(b)`, `MapBuilder.region_shape(md, region)`, `MapBuilder.KERB_MIN_ROAD_W`, `MapBuilder.KERB_W`, `FPTUCampusBuilder.real_plot_transform()`, `plot_rect()`, `ring_outer_rect()`, `ring_courtyard_rect()`, `main_gate_local()`, `west_gate_local()`, `back_gate_local()`.
- Produces (Tasks 10-11): `PedWalkGraph.build(md: MapData, opts: Dictionary = {}) -> PedWalkGraph`, `PedWalkGraph.from_lines(lines: Array) -> PedWalkGraph` (no filtering; tests), `node_count() -> int`, `node_pos(i: int) -> Vector3`, `neighbours(i: int) -> Array`, `next_node(node: int, came_from: int, rng: RandomNumberGenerator = null) -> int`, `nearest(p: Vector3, max_r: float = 30.0) -> int`, `random_point_near(p: Vector3, r_min: float, r_max: float, rng: RandomNumberGenerator) -> int` (-1 when none), `block_near(points: Array, r: float) -> void` (cuts every edge passing within r of a point).

- [ ] **Step 1: Write the failing test (part A)**

Create `tests/test_pedestrians.gd`:

```gdscript
# File: res://tests/test_pedestrians.gd
# Test headless người đi đường FreeRoam (spec vice-people-and-movement, Phần 3).
#   A (Task 9):  đồ thị lối đi bộ từ mapdata: > 500 nút, không nút nào dưới nước / trong nhà OSM / trên lòng đường,
#                truy vấn random_point_near / next_node.
#   B (Task 10): một người đi đường trên đồ thị tự dựng: đi bộ, va nhẹ -> STUMBLE, nước rút -> KNOCKDOWN rồi đi lại
#                trong 3.2 s, xe > 3 m/s -> KNOCKDOWN (tín hiệu "bike").
#   C (Task 11): FreeRoam: 18..30 người trong 80 m, tránh hotspot, thay người khi đi xa, xe tông người bị chậm lại,
#                chi phí vật lý.
# Chạy:  godot --headless --path . --script tests/test_pedestrians.gd
extends SceneTree

const PART_B: bool = false   # Task 10 bật
const PART_C: bool = false   # Task 11 bật

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
	var hits: int = 0
	for n: int in range(40):
		var j: int = g.random_point_near(spawn, 40.0, 80.0, rng)
		if j >= 0:
			var d2: float = Vector2(g.node_pos(j).x - spawn.x, g.node_pos(j).z - spawn.z).length()
			if not _check(d2 >= 40.0 and d2 <= 80.0, "random_point_near returned a node %.1f m away (40..80)" % d2):
				return false
			hits += 1
	if not _check(hits >= 30, "random_point_near found nodes 40..80 m from the BE6 spawn only %d / 40 times" % hits):
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
	return true


func _campus_node(p: Vector2) -> bool:
	var local: Vector3 = FPTUCampusBuilder.real_plot_transform().affine_inverse() * Vector3(p.x, 0.0, p.y)
	return FPTUCampusBuilder.plot_rect().grow(3.0).has_point(Vector2(local.x, local.z))


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
# Đồ thị lối đi bộ cho người đi đường FreeRoam, dựng một lần từ MapData: lề sau bó vỉa hai bên mỗi làn xe rộng
# >= MapBuilder.KERB_MIN_ROAD_W, đường đi bộ (lanes == 0), vòng quanh nhà campus + sân trong + lối qua ba cổng.
# Bỏ điểm dưới / sát nước, trong nhà OSM, trên lòng đường, ngoài ba vùng đã dựng, (đường OSM) trong lô campus; nối các
# đường gần nhau (góc phố, băng qua đường). Nhà Microsoft và vật cản dựng thêm do PedestrianSpawner kiểm bằng vật lý.
# Không dùng GameFX / StageManager ở đây (class_name biên dịch trước autoload khi chạy test --script).
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
const REGIONS: Array[String] = ["vinhomes", "corridor", "campus"]

var pos: PackedVector3Array = PackedVector3Array()
var adj: Array = []             # Array of Array[int]
var line_of: PackedInt32Array = PackedInt32Array()
var _hash: Dictionary = {}      # Vector2i -> Array[int]


# ===========================================================================
# DỰNG
# ===========================================================================
static func build(md: MapData, _opts: Dictionary = {}) -> PedWalkGraph:
	var g := PedWalkGraph.new()
	if md == null:
		push_warning("PedWalkGraph: không có MapData")
		return g
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
			g._add_line(_offset(pts, -off), ctx, line_id + 1, true, true, true)
			line_id += 2
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


# ===========================================================================
# TRUY VẤN
# ===========================================================================
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
## (chỉ đi tới nút kề) không bao giờ đi vào hay lướt qua vùng đó (cột sáng hotspot, điểm spawn BE6).
func block_near(points: Array, r: float) -> void:
	for i: int in range(pos.size()):
		var a := Vector2(pos[i].x, pos[i].z)
		for e: int in (adj[i] as Array).duplicate():
			var b := Vector2(pos[e].x, pos[e].z)
			for pt: Variant in points:
				var pv: Vector3 = pt
				var p2 := Vector2(pv.x, pv.z)
				if Geometry2D.get_closest_point_to_segment(p2, a, b).distance_to(p2) < r:
					(adj[i] as Array).erase(e)
					(adj[e] as Array).erase(i)
					break


func random_point_near(p: Vector3, r_min: float, r_max: float, rng: RandomNumberGenerator) -> int:
	var cands: Array[int] = []
	var c0: Vector2i = _cell(Vector2(p.x, p.z))
	var reach: int = ceili(r_max / CELL)
	for dx: int in range(-reach, reach + 1):
		for dz: int in range(-reach, reach + 1):
			for i: int in _hash.get(Vector2i(c0.x + dx, c0.y + dz), []):
				var d: float = Vector2(pos[i].x - p.x, pos[i].z - p.z).length()
				if d >= r_min and d <= r_max:
					cands.append(i)
	if cands.is_empty():
		return -1
	return cands[rng.randi_range(0, cands.size() - 1)]


# ===========================================================================
# NỘI BỘ
# ===========================================================================
func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


func _add_node(p: Vector2, line_id: int) -> int:
	var id: int = pos.size()
	pos.append(Vector3(p.x, 0.0, p.y))
	adj.append([])
	line_of.append(line_id)
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
			var id: int = _add_node(p, line_id)
			if prev >= 0 and prev_p.distance_to(p) <= SAMPLE_M * 1.6:
				_connect(prev, id)
			prev = id
			prev_p = p


## Nối nút của các đường khác nhau trong LINK_R (góc phố, băng qua đường): mỗi nút tối đa MAX_LINKS, gần nhất trước,
## trung điểm đoạn nối không dưới nước / trong nhà OSM.
func _link(ctx: Dictionary) -> void:
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
			if _ok(mid, ctx, true, false, false):
				_connect(i, j2)
				made += 1


static func _ok(p: Vector2, ctx: Dictionary, check_buildings: bool, check_roads: bool, outside_plot: bool) -> bool:
	var inside: bool = false
	var shapes: Array = ctx["shapes"]
	for i: int in range(shapes.size()):
		if (ctx["shape_box"][i] as Rect2).has_point(p) and Geometry2D.is_point_in_polygon(p, shapes[i]):
			inside = true
			break
	if not inside:
		return false
	var water: Array = ctx["water"]
	for i: int in range(water.size()):
		if (ctx["water_box"][i] as Rect2).grow(WATER_CLEAR).has_point(p) and _near_poly(p, water[i], WATER_CLEAR):
			return false
	if check_buildings:
		var bld: Array = ctx["bld"]
		for i: int in range(bld.size()):
			if (ctx["bld_box"][i] as Rect2).has_point(p) and Geometry2D.is_point_in_polygon(p, bld[i]):
				return false
	if outside_plot and Geometry2D.is_point_in_polygon(p, ctx["plot"]):
		return false
	if check_roads:
		var key := Vector2i(floori(p.x / SEG_CELL), floori(p.y / SEG_CELL))
		for si: int in (ctx["seg_hash"] as Dictionary).get(key, []):
			var s: Array = ctx["segs"][si]
			if Geometry2D.get_closest_point_to_segment(p, s[0], s[1]).distance_to(p) < float(s[2]) + ROAD_CLEAR:
				return false
	return true


static func _near_poly(p: Vector2, poly: PackedVector2Array, margin: float) -> bool:
	if Geometry2D.is_point_in_polygon(p, poly):
		return true
	var n: int = poly.size()
	for i: int in range(n):
		if Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % n]).distance_to(p) < margin:
			return true
	return false


static func _context(md: MapData) -> Dictionary:
	var ctx: Dictionary = {"water": [], "water_box": [], "bld": [], "bld_box": [], "segs": [], "seg_hash": {}, "shapes": [], "shape_box": []}
	for w: PackedVector2Array in MapBuilder._water_polygons(md):
		(ctx["water"] as Array).append(w)
		(ctx["water_box"] as Array).append(_bbox(w))
	for b: Dictionary in md.buildings():
		if MapBuilder.is_msft(b):
			continue
		var poly: PackedVector2Array = MapData.poly(b.get("outer", []))
		if poly.size() >= 3:
			(ctx["bld"] as Array).append(poly)
			(ctx["bld_box"] as Array).append(_bbox(poly))
	for r: Dictionary in md.roads():
		if int(r.get("lanes", 2)) <= 0:
			continue
		var pts: PackedVector2Array = MapData.poly(r.get("points", []))
		var hw: float = float(r.get("width", 6.0)) * 0.5
		for i: int in range(pts.size() - 1):
			var si: int = (ctx["segs"] as Array).size()
			(ctx["segs"] as Array).append([pts[i], pts[i + 1], hw])
			var bb: Rect2 = Rect2(pts[i], Vector2.ZERO).expand(pts[i + 1]).grow(hw + ROAD_CLEAR)
			for cx: int in range(floori(bb.position.x / SEG_CELL), floori(bb.end.x / SEG_CELL) + 1):
				for cz: int in range(floori(bb.position.y / SEG_CELL), floori(bb.end.y / SEG_CELL) + 1):
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
	return ctx


static func _campus_lines() -> Array:
	var xf: Transform3D = FPTUCampusBuilder.real_plot_transform()
	var out: Array = []
	var plot: Rect2 = FPTUCampusBuilder.plot_rect().grow(-3.0)
	var loop: Rect2 = FPTUCampusBuilder.ring_outer_rect().grow(CAMPUS_LOOP_GROW).intersection(plot)
	out.append(_rect_loop(loop, xf))
	out.append(_rect_loop(FPTUCampusBuilder.ring_courtyard_rect().grow(-COURTYARD_INSET), xf))
	for g: Vector3 in [FPTUCampusBuilder.main_gate_local(), FPTUCampusBuilder.west_gate_local()]:
		out.append(_local_line([Vector2(g.x, -2.0), Vector2(g.x, loop.position.y)], xf))
	var bg: Vector3 = FPTUCampusBuilder.back_gate_local()
	out.append(_local_line([Vector2(bg.x, bg.z + 2.0), Vector2(bg.x, loop.end.y)], xf))
	return out


static func _rect_loop(r: Rect2, xf: Transform3D) -> PackedVector2Array:
	return _local_line([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position], xf)


static func _local_line(pts: Array, xf: Transform3D) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		var w: Vector3 = xf * Vector3(p.x, 0.0, p.y)
		out.append(Vector2(w.x, w.z))
	return out


## Polyline dời sang trái (off > 0) / phải (off < 0) theo pháp tuyến trung bình ở mỗi đỉnh (giới hạn mitre).
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

Run: `godot --headless --path . --script tests/test_pedestrians.gd > /tmp/t9.log 2>&1; grep -E "walk graph|SUCCESS|FAILED" /tmp/t9.log`
Expected: `walk graph: N nodes in M ms` (N > 500, M < 1500) then `✅ SUCCESS: PEDESTRIANS (part A: walk graph)`.

- [ ] **Step 5: Regression and commit**

Run the regression command (all green), then:

```bash
git add scripts/roam/PedWalkGraph.gd tests/test_pedestrians.gd
git commit -m "feat(peds): pedestrian walk graph from the real map (verges behind kerbs, footways, campus loops and gates) with spatial queries

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: `Pedestrian` (wandering and reactions)

**Files:**
- Create: `scripts/roam/Pedestrian.gd`
- Modify: `tests/test_pedestrians.gd` (part B)

**Interfaces:**
- Consumes: `PedWalkGraph` (Task 9), Task 6 clips (`stumble`, `knockdown`, `getup`), PS2 expressions (`angry`, `pain`, `open`).
- Produces (Task 11):
  - `class_name Pedestrian extends CharacterBody3D`; `enum State { WALK, IDLE, STUMBLE, KNOCKDOWN, FLEE }`; `var state: int`.
  - `setup(g: PedWalkGraph, node: int, preset_opts: Dictionary, seed: int) -> void` (builds the model; call before `add_child`).
  - Wiring members set by the spawner: `player: Node3D`, `bike: Node3D`, `mounted_fn: Callable` (returns bool), `crowd: Array` (shared list of pedestrians), `spawner: Node` (for `request_line`), `lod_far: bool`.
  - `react(kind: String, away: Vector3, speed: float) -> void`; signal `hit(ped: Pedestrian, kind: String)`; `hits: Array[String]` (test log); `stuck_out: bool` (spawner recycles when true).
  - Constants `PED_LINES: Dictionary` (kind -> Array[String]).

- [ ] **Step 1: Write the failing test (part B)**

In `tests/test_pedestrians.gd` set `const PART_B: bool = true` and add, after `_part_a()` in `_initialize()`:

```gdscript
	if PART_B:
		_part_b_start()
```

and add these members and functions:

```gdscript
var world_b: Node3D
var ped: Pedestrian
var stub_player: CharacterBody3D
var stub_bike: CharacterBody3D
var mounted: bool = false
var b_phase: String = ""
var b_t0: int = 0
var b_hits: Array[String] = []


func _part_b_start() -> void:
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
	# đường thẳng 60 m dọc trục X (toạ độ bản đồ = thế giới của world_b)
	var line := PackedVector2Array()
	for i: int in range(11):
		line.append(Vector2(-30.0 + float(i) * 6.0, 5000.0))
	var g: PedWalkGraph = PedWalkGraph.from_lines([line])
	ped = Pedestrian.new()
	ped.setup(g, 5, {"preset": "student"}, 11)
	stub_player = _stub("StubPlayer", Vector3(40.0, 0.0, 5000.0), 0.4)
	stub_bike = _stub("StubBike", Vector3(-40.0, 0.0, 5000.0), 0.6)
	ped.player = stub_player
	ped.bike = stub_bike
	ped.mounted_fn = func() -> bool: return mounted
	ped.hit.connect(func(_p: Pedestrian, kind: String) -> void: b_hits.append(kind))
	root.add_child(ped)
	ped.global_position = Vector3(0.0, 0.05, 5000.0)
	b_phase = "walk"
	b_t0 = 0


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


func _process(_d: float) -> bool:
	if done or not PART_B or b_phase == "":
		return done
	frames += 1
	var t: int = frames - b_t0
	match b_phase:
		"walk":
			if t == 90:
				var moved: float = Vector2(ped.global_position.x, ped.global_position.z - 5000.0).length()
				print("  pedestrian walked %.2f m in 1.5 s (state %d)" % [moved, ped.state])
				if not _check(moved > 1.2 and ped.state == Pedestrian.State.WALK, "a pedestrian must walk along the graph (moved %.2f m)" % moved):
					return true
				stub_player.set("speed_value", 3.0)
				stub_player.global_position = ped.global_position + Vector3(0.65, 0.0, 0.0)
				b_phase = "bump"
				b_t0 = frames
		"bump":
			if t == 3:
				print("  bump -> state %d, hits %s" % [ped.state, b_hits])
				if not _check(ped.state == Pedestrian.State.STUMBLE and b_hits.size() == 1 and b_hits[0] == "bump", "a walking bump (3 m/s) must give STUMBLE and one 'bump' hit"):
					return true
				stub_player.global_position = Vector3(40.0, 0.0, 5000.0)
			if t == 80:   # > 1 s cooldown
				stub_player.set("speed_value", 7.0)
				stub_player.global_position = ped.global_position + Vector3(0.65, 0.0, 0.0)
				b_phase = "sprint"
				b_t0 = frames
		"sprint":
			if t == 3:
				if not _check(ped.state == Pedestrian.State.KNOCKDOWN and b_hits.back() == "sprint", "a sprint hit (7 m/s) must give KNOCKDOWN"):
					return true
				stub_player.global_position = Vector3(40.0, 0.0, 5000.0)
			if t == 180:   # 3 s (ngã 1.2 s + đứng dậy 0.9 s)
				print("  after knockdown: state %d" % ped.state)
				if not _check(ped.state == Pedestrian.State.FLEE or ped.state == Pedestrian.State.WALK, "a knocked-down pedestrian walks again within 3 s (state %d)" % ped.state):
					return true
				mounted = true
				stub_bike.set("speed_value", 6.0)
				stub_bike.global_position = ped.global_position + Vector3(-0.8, 0.0, 0.0)
				b_phase = "bike"
				b_t0 = frames
		"bike":
			if t == 3:
				print("  bike hit -> state %d, hits %s" % [ped.state, b_hits])
				if not _check(ped.state == Pedestrian.State.KNOCKDOWN and b_hits.back() == "bike", "a bike hit above 3 m/s must give KNOCKDOWN with kind 'bike'"):
					return true
				if not PART_C:
					print("✅ SUCCESS: PEDESTRIANS (parts A + B)")
					done = true
					quit(0)
	return done
```

Create the tiny stub script `tests/support/stub_mover.gd` (a body whose speed the test sets; the pedestrian reads `horizontal_speed` from a player and `current_speed_ms` from a bike):

```gdscript
# File: res://tests/support/stub_mover.gd
# Thân giả cho test người đi đường: speed_value đóng vai horizontal_speed (người chơi) và current_speed_ms (xe).
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

Create `scripts/roam/Pedestrian.gd`:

```gdscript
# File: res://scripts/roam/Pedestrian.gd
# Người đi đường FreeRoam: thân CharacterBuilder (rigged; đầu PS2 ở phong cách Vice City), đi theo PedWalkGraph,
# thỉnh thoảng đứng lại; tự đo va chạm với người chơi (đi bộ) / xe (khi cưỡi) bằng khoảng cách và phản ứng:
#   va nhẹ -> STUMBLE (lảo đảo, né 0.6 m), nước rút > 6 m/s -> KNOCKDOWN (ngã rồi đứng dậy, bỏ chạy),
#   xe > 3 m/s -> KNOCKDOWN văng 2..4 m; mỗi lần một câu càu nhàu (spawner giới hạn nhịp). Không phạt gì.
# Không dùng GameFX / StageManager ở đây (class_name biên dịch trước autoload khi chạy test --script).
class_name Pedestrian
extends CharacterBody3D

signal hit(ped: Pedestrian, kind: String)

enum State { WALK, IDLE, STUMBLE, KNOCKDOWN, FLEE }

const RADIUS: float = 0.28
const HEIGHT: float = 1.7
const GRAVITY: float = 20.0
const WALK_MIN: float = 1.1
const WALK_MAX: float = 1.6
const FLEE_SPEED: float = 3.2
const STUMBLE_TIME: float = 0.8
const FALL_TIME: float = 1.2
const GETUP_TIME: float = 0.9
const FLEE_TIME: float = 3.0
const HIT_COOLDOWN: float = 1.0
const SIDESTEP_M: float = 0.6
const STUCK_TIME: float = 3.0
const STUCK_RECYCLE: float = 10.0
const SEPARATION_R: float = 1.2
const PLAYER_RADIUS: float = 0.4
const BIKE_RADIUS: float = 0.6
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
var _throw_v: Vector3 = Vector3.ZERO
var _away: Vector3 = Vector3.ZERO
var _getting_up: bool = false
var _idle_left: float = 0.0
var _rng := RandomNumberGenerator.new()


## Dựng thân + capsule; gọi trước add_child. preset_opts: tuỳ chọn CharacterBuilder.build() (preset...).
func setup(g: PedWalkGraph, node: int, preset_opts: Dictionary, seed: int) -> void:
	graph = g
	_rng.seed = seed
	prev_node = node
	target_node = node
	walk_speed = _rng.randf_range(WALK_MIN, WALK_MAX)
	floor_snap_length = 0.4
	var cs := CollisionShape3D.new()
	cs.name = "Capsule"
	var cap := CapsuleShape3D.new()
	cap.radius = RADIUS
	cap.height = HEIGHT
	cs.shape = cap
	cs.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	add_child(cs)
	var o: Dictionary = preset_opts.duplicate()
	o["seed"] = seed
	o["rigged"] = true
	o["name"] = "Model"
	model = CharacterBuilder.build(o)
	add_child(model)


func _ready() -> void:
	_last_pos = global_position


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
	if _cool > 0.0 or state == State.KNOCKDOWN:
		return
	var mounted: bool = bool(mounted_fn.call()) if mounted_fn.is_valid() else false
	var other: Node3D = bike if mounted else player
	if other == null or not other.is_inside_tree():
		return
	var r: float = (BIKE_RADIUS if mounted else PLAYER_RADIUS) + RADIUS + 0.05
	var d := Vector2(global_position.x - other.global_position.x, global_position.z - other.global_position.z)
	if d.length() > r or absf(global_position.y - other.global_position.y) > 1.2:
		return
	var speed: float = float(other.get("current_speed_ms")) if mounted else float(other.get("horizontal_speed"))
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
		velocity.x = away.x * SIDESTEP_M / STUMBLE_TIME * 2.0
		velocity.z = away.z * SIDESTEP_M / STUMBLE_TIME * 2.0
		CharacterBuilder.play(model, "stumble")
		CharacterBuilder.set_expression(model, "angry")
	else:
		state = State.KNOCKDOWN
		_getting_up = false
		var throw: float = clampf(2.0 + (speed - BIKE_HIT_SPEED) * 0.25, 2.0, 4.0) if kind == "bike" else 0.8
		_throw_v = away * (throw / 0.5) + Vector3(0.0, 3.0 if kind == "bike" else 0.0, 0.0)
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
	var dir: Vector3 = (to.normalized() + _separation() * 0.8).normalized()
	var sp: float = FLEE_SPEED if state == State.FLEE else walk_speed
	velocity.x = dir.x * sp
	velocity.z = dir.z * sp
	_gravity(delta)
	if lod_far:
		global_position += Vector3(velocity.x, 0.0, velocity.z) * delta
	else:
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
	if state == State.WALK and _rng.randf() < IDLE_CHANCE:
		state = State.IDLE
		_idle_left = _rng.randf_range(2.0, 6.0)
		CharacterBuilder.set_speed(model, 0.0)
		if _rng.randf() < 0.5:
			CharacterBuilder.play(model, "phone", _idle_left)


func _idle(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_gravity(delta)
	if not lod_far:
		move_and_slide()
	_idle_left -= delta
	if _idle_left <= 0.0:
		CharacterBuilder.stop_clip(model)
		state = State.WALK


func _stumble(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 6.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 6.0 * delta)
	_gravity(delta)
	move_and_slide()
	CharacterBuilder.set_speed(model, 0.0)
	if _t >= STUMBLE_TIME:
		state = State.WALK
		CharacterBuilder.set_expression(model, "open")


func _knockdown(delta: float) -> void:
	if _t < 0.5:
		velocity.x = _throw_v.x
		velocity.z = _throw_v.z
		if _throw_v.y > 0.0 and _t < delta * 1.5:
			velocity.y = _throw_v.y
	else:
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
	_gravity(delta)
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


func _separation() -> Vector3:
	var push := Vector3.ZERO
	for o: Variant in crowd:
		if o == self or not is_instance_valid(o):
			continue
		var on: Node3D = o
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

Run: `godot --headless --path . --script tests/test_pedestrians.gd > /tmp/t10.log 2>&1; grep -E "pedestrian walked|bump|after knockdown|bike hit|SUCCESS|FAILED" /tmp/t10.log`
Expected: the four diagnostics, then `✅ SUCCESS: PEDESTRIANS (parts A + B)`.

- [ ] **Step 4: Regression and commit**

Run the regression command (all green), then:

```bash
git add scripts/roam/Pedestrian.gd tests/test_pedestrians.gd tests/support/stub_mover.gd
git commit -m "feat(peds): Pedestrian - wanders the walk graph, detects bumps/sprint hits/bike hits by distance, stumbles or falls and gets up, mild fictional complaints

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: `PedestrianSpawner` and FreeRoam wiring (after VC-2 and VC-4 are merged)

**Files:**
- Create: `scripts/roam/PedestrianSpawner.gd`
- Modify: `scripts/FreeRoam.gd` (`var pedestrians`, `_build_pedestrians()` called at the end of `_ready()` after `_apply_spawn()`)
- Modify: `tests/test_pedestrians.gd` (part C)
- Create: `tests/preview_peds.gd`; renders `docs/preview/vice_roam_peds_1.png`, `vice_roam_peds_2.png`

**Interfaces:**
- Consumes: Tasks 9-10; `FreeRoam.free_spot_at(p, base_y) -> Variant`, `FreeRoam.mounted`, `FreeRoam.hotspots`, `FreeRoam.spawn_xf`, `ThirdPersonController.slow_t`, `ThirdPersonController.cam_ray`, `PlayerBike.current_speed_ms`, `PlayerBike.spring_arm`.
- Produces: `PedestrianSpawner.setup(md: MapData, player_node: Node3D, opts: Dictionary = {})` with opts `bike`, `roam`, `avoid` (Array[Vector3]), `count` (24), `spawn_min` (40), `spawn_max` (80), `initial_min` (12), `despawn` (110); `pedestrians() -> Array`; `request_line(ped, kind)`; signal `pedestrian_hit(ped, kind)`; counters `spawned`, `recycled`; `FreeRoam.pedestrians: PedestrianSpawner`.

- [ ] **Step 1: Write the failing test (part C)**

In `tests/test_pedestrians.gd` set `const PART_C: bool = true`, and in the part B `"bike"` branch keep the `if not PART_C` exit (it now falls through). Add at the end of the `"bike"` branch: `if PART_C: b_phase = ""; _part_c_start()`. Add:

```gdscript
var roam: Node3D
var c_phase: String = ""
var c_t0: int = 0
var c_frames: int = 0
var phys_with: float = 0.0
var phys_without: float = 0.0


func _part_c_start() -> void:
	ped.queue_free()
	world_b.queue_free()
	stub_player.queue_free()
	stub_bike.queue_free()
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	roam = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	root.add_child(roam)
	c_phase = "settle"
	c_t0 = c_frames
	physics_frame.connect(_on_physics_c)


func _active_near(center: Vector3, r: float) -> int:
	var sp: Node = roam.get("pedestrians")
	var n: int = 0
	for p: Variant in sp.call("pedestrians"):
		var pn: Node3D = p
		if Vector2(pn.global_position.x - center.x, pn.global_position.z - center.z).length() <= r:
			n += 1
	return n


func _on_physics_c() -> void:
	if done:
		return
	c_frames += 1
	var t: int = c_frames - c_t0
	var player: Node3D = roam.get("player")
	match c_phase:
		"settle":
			if t == 150:
				var sp: Node = roam.get("pedestrians")
				if not _check(sp != null, "FreeRoam must expose a pedestrians spawner"):
					return
				var n: int = _active_near(player.global_position, 80.0)
				print("  pedestrians within 80 m of the spawn: %d" % n)
				if not _check(n >= 18 and n <= 30, "18..30 pedestrians within 80 m (got %d)" % n):
					return
				for h: Variant in roam.get("hotspots"):
					var hn: Node3D = h
					for p: Variant in sp.call("pedestrians"):
						var pn: Node3D = p
						var d: float = Vector2(pn.global_position.x - hn.global_position.x, pn.global_position.z - hn.global_position.z).length()
						if not _check(d >= 2.5, "pedestrian %.1f m from a hotspot (keep 3 m)" % d):
							return
				for p2: Variant in sp.call("pedestrians"):
					if not _check((p2 as Node3D).global_position.y > -1.0, "a pedestrian fell through the world"):
						return
				phys_with = 0.0
				c_phase = "perf_with"
				c_t0 = c_frames
		"perf_with":
			phys_with += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
			if t == 60:
				phys_with /= 60.0
				var sp2: Node = roam.get("pedestrians")
				for p3: Variant in sp2.call("pedestrians"):
					(p3 as Node).process_mode = Node.PROCESS_MODE_DISABLED
				sp2.process_mode = Node.PROCESS_MODE_DISABLED
				phys_without = 0.0
				c_phase = "perf_without"
				c_t0 = c_frames
		"perf_without":
			phys_without += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
			if t == 60:
				phys_without /= 60.0
				var cost_ms: float = (phys_with - phys_without) * 1000.0
				print("  pedestrian physics cost %.2f ms per physics frame" % cost_ms)
				if not _check(cost_ms < 3.0, "24 pedestrians must cost < 3 ms per physics frame (got %.2f)" % cost_ms):
					return
				var sp3: Node = roam.get("pedestrians")
				sp3.process_mode = Node.PROCESS_MODE_INHERIT
				for p4: Variant in sp3.call("pedestrians"):
					(p4 as Node).process_mode = Node.PROCESS_MODE_INHERIT
				# đi xa 400 m dọc tuyến đường -> người cũ bị thay, người mới quanh chỗ mới
				var md: MapData = MapData.load_default()
				var route: PackedVector2Array = md.route_points(20.0)
				var far: Vector2 = route[mini(route.size() - 1, 25)]
				player.call("teleport", Vector3(far.x, 0.5, far.y), 0.0)
				c_phase = "moved"
				c_t0 = c_frames
		"moved":
			if t == 240:
				var sp4: Node = roam.get("pedestrians")
				var rec: int = int(sp4.get("recycled"))
				var near: int = _active_near(player.global_position, 80.0)
				print("  after moving 400 m: recycled %d, near %d" % [rec, near])
				if not _check(rec > 0 and near >= 10, "moving away must recycle pedestrians and refill near the player (recycled %d, near %d)" % [rec, near]):
					return
				# xe tông người: người ngã, xe chậm lại còn <= 0.8 tốc độ
				roam.call("mount_bike")
				c_phase = "bike_hit"
				c_t0 = c_frames
		"bike_hit":
			var bike: Node3D = roam.get("bike")
			var sp5: Node = roam.get("pedestrians")
			if t == 30:
				var pl: Array = sp5.call("pedestrians")
				var victim: Pedestrian = pl[0]
				victim.process_mode = Node.PROCESS_MODE_INHERIT
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

Run: `godot --headless --path . --script tests/test_pedestrians.gd > /tmp/t11.log 2>&1; grep -E "SUCCESS|FAILED" /tmp/t11.log`
Expected: `❌ FAILED: FreeRoam must expose a pedestrians spawner`.

- [ ] **Step 2: Implement the spawner**

Create `scripts/roam/PedestrianSpawner.gd`:

```gdscript
# File: res://scripts/roam/PedestrianSpawner.gd
# Người đi đường quanh người chơi FreeRoam: giữ `count` người trên PedWalkGraph trong vòng spawn_min..spawn_max m
# (lần đầu từ initial_min), ưu tiên ngoài tầm camera, kiểm chỗ đứng bằng FreeRoam.free_spot_at; người xa hơn `despawn`
# hoặc kẹt bị thay (tối đa 2 người mới mỗi 0.25 s để không giật). LOD: xa > 45 m di chuyển rẻ, > 90 m ẩn.
# Một bong bóng thoại dùng chung (mỗi 4 s tối đa một câu). Hậu quả va chạm: nước rút -> người chơi chậm 0.2 s,
# xe tông -> xe mất 25 % tốc độ. Không dùng GameFX / StageManager ở đây.
class_name PedestrianSpawner
extends Node3D

signal pedestrian_hit(ped: Pedestrian, kind: String)

const DEFAULT_COUNT: int = 24
const LOD_FAR: float = 45.0
const HIDE_FAR: float = 90.0
const HOTSPOT_CLEAR: float = 3.0
const SPAWN_CLEAR: float = 8.0
const LINE_GAP_S: float = 4.0
const LINE_SHOW_S: float = 2.0
const CHECK_EVERY: float = 0.25
const SPAWNS_PER_CHECK: int = 2
const PLAYER_SLOW_S: float = 0.2
const BIKE_SPEED_KEEP: float = 0.75
const CAMPUS_NEAR_M: float = 60.0

var graph: PedWalkGraph
var md: MapData
var player: Node3D
var bike: Node3D
var roam: Node
var count: int = DEFAULT_COUNT
var spawn_min: float = 40.0
var spawn_max: float = 80.0
var initial_min: float = 12.0
var despawn: float = 110.0
var spawned: int = 0
var recycled: int = 0
var _peds: Array = []
var _avoid: Array = []
var _rng := RandomNumberGenerator.new()
var _check_t: float = 0.0
var _line_t: float = -99.0
var _bubble: Label3D
var _bubble_ped: Pedestrian
var _bubble_left: float = 0.0
var _campus_poly := PackedVector2Array()
var _filled_once: bool = false


func setup(map_data: MapData, player_node: Node3D, opts: Dictionary = {}) -> void:
	md = map_data
	player = player_node
	bike = opts.get("bike", null)
	roam = opts.get("roam", null)
	count = int(opts.get("count", DEFAULT_COUNT))
	spawn_min = float(opts.get("spawn_min", 40.0))
	spawn_max = float(opts.get("spawn_max", 80.0))
	initial_min = float(opts.get("initial_min", 12.0))
	despawn = float(opts.get("despawn", 110.0))
	_avoid = opts.get("avoid", [])
	_rng.seed = int(opts.get("seed", 2026))
	graph = PedWalkGraph.build(md)
	if graph.node_count() == 0:
		push_warning("PedestrianSpawner: đồ thị lối đi bộ rỗng, tắt người đi đường")
		set_physics_process(false)
		return
	graph.block_near(_avoid, HOTSPOT_CLEAR)
	var xf: Transform3D = FPTUCampusBuilder.real_plot_transform()
	var pr: Rect2 = FPTUCampusBuilder.plot_rect().grow(CAMPUS_NEAR_M)
	for c: Vector2 in [pr.position, Vector2(pr.end.x, pr.position.y), pr.end, Vector2(pr.position.x, pr.end.y)]:
		var w: Vector3 = xf * Vector3(c.x, 0.0, c.y)
		_campus_poly.append(Vector2(w.x, w.z))
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
	_fill(initial_min, count)
	_filled_once = true


func pedestrians() -> Array:
	return _peds


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
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = CHECK_EVERY
	var center: Vector3 = _center()
	for i: int in range(_peds.size() - 1, -1, -1):
		var p: Pedestrian = _peds[i]
		if not is_instance_valid(p):
			_peds.remove_at(i)
			continue
		var d: float = Vector2(p.global_position.x - center.x, p.global_position.z - center.z).length()
		if d > despawn or p.stuck_out:
			_peds.remove_at(i)
			p.queue_free()
			recycled += 1
			continue
		p.lod_far = d > LOD_FAR
		p.visible = d < HIDE_FAR
	_fill(spawn_min, SPAWNS_PER_CHECK)


func _process(delta: float) -> void:
	if _bubble == null or not _bubble.visible:
		return
	_bubble_left -= delta
	if _bubble_left <= 0.0 or not is_instance_valid(_bubble_ped):
		_bubble.visible = false
		return
	var top: Node3D = CharacterBuilder.head_top(_bubble_ped.model)
	_bubble.global_position = (top.global_position if top else _bubble_ped.global_position + Vector3(0.0, 1.9, 0.0)) + Vector3(0.0, 0.35, 0.0)


func _center() -> Vector3:
	var mounted: bool = roam != null and bool(roam.get("mounted"))
	if mounted and bike:
		return bike.global_position
	return player.global_position if player else Vector3.ZERO


func _fill(r_min: float, max_new: int) -> void:
	var center: Vector3 = _center()
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var made: int = 0
	var attempts: int = 0
	while _peds.size() < count and made < max_new and attempts < max_new * 6:
		attempts += 1
		var node: int = graph.random_point_near(center, r_min, spawn_max, _rng)
		if node < 0:
			break
		var p: Vector3 = graph.node_pos(node)
		if not _clear_of_avoid(p):
			continue
		if _filled_once and cam and attempts <= max_new * 4 and cam.is_position_in_frustum(p + Vector3(0.0, 1.0, 0.0)) and cam.global_position.distance_to(p) < 70.0:
			continue
		var spot: Variant = p
		if roam and roam.has_method("free_spot_at"):
			spot = roam.call("free_spot_at", p, 0.0)
		if not (spot is Vector3):
			continue
		_spawn(node, spot)
		made += 1


func _clear_of_avoid(p: Vector3) -> bool:
	for a: Variant in _avoid:
		var av: Vector3 = a
		if Vector2(p.x - av.x, p.z - av.z).length() < HOTSPOT_CLEAR + 0.5:
			return false
	if player and Vector2(p.x - player.global_position.x, p.z - player.global_position.z).length() < SPAWN_CLEAR:
		return false
	return true


func _spawn(node: int, at: Vector3) -> void:
	var p := Pedestrian.new()
	p.name = "Ped_%d" % spawned
	p.setup(graph, node, {"preset": _pick_preset(at)}, 9000 + spawned * 13)
	p.player = player
	p.bike = bike
	p.mounted_fn = func() -> bool: return roam != null and bool(roam.get("mounted"))
	p.crowd = _peds
	p.spawner = self
	p.hit.connect(_on_hit)
	add_child(p)
	p.global_position = at + Vector3(0.0, 0.05, 0.0)
	_peds.append(p)
	spawned += 1
	if player and player.get("cam_ray"):
		(player.get("cam_ray") as RayCast3D).add_exception(p)
	if bike and bike.get("spring_arm"):
		(bike.get("spring_arm") as SpringArm3D).add_excluded_object(p.get_rid())


func _pick_preset(at: Vector3) -> String:
	var r: float = _rng.randf()
	if Geometry2D.is_point_in_polygon(Vector2(at.x, at.z), _campus_poly):
		return "student" if r < 0.9 else "lecturer"
	if r < 0.6:
		return "casual"
	return "student" if r < 0.9 else "lecturer"


func _on_hit(ped: Pedestrian, kind: String) -> void:
	if kind == "sprint" and player:
		player.set("slow_t", PLAYER_SLOW_S)
	elif kind == "bike" and bike:
		bike.set("current_speed_ms", float(bike.get("current_speed_ms")) * BIKE_SPEED_KEEP)
	pedestrian_hit.emit(ped, kind)
```

In `scripts/FreeRoam.gd` add `var pedestrians: PedestrianSpawner` next to `var bike: PlayerBike`, call `_build_pedestrians()` at the end of `_ready()` right after `_apply_spawn()` (before the `for k in GameFXScript.TOD_PRESETS` loop is fine), and add:

```gdscript
## Người đi đường (spec vice-people-and-movement, Phần 3): tránh cột sáng hotspot và điểm spawn.
func _build_pedestrians() -> void:
	pedestrians = PedestrianSpawner.new()
	pedestrians.name = "Pedestrians"
	add_child(pedestrians)
	var avoid: Array = [spawn_xf.origin]
	for h: Area3D in hotspots:
		avoid.append(h.global_position)
	pedestrians.setup(md, player, {"bike": bike, "roam": self, "avoid": avoid})
```

Run: `godot --headless --import --path . > /tmp/imp.log 2>&1; grep -c PedestrianSpawner .godot/global_script_class_cache.cfg` — expected ≥ 2.

- [ ] **Step 3: Run the tests**

Run: `godot --headless --path . --script tests/test_pedestrians.gd > /tmp/t11.log 2>&1; grep -E "within 80|physics cost|after moving|bike hit|SUCCESS|FAILED" /tmp/t11.log`
Expected: counts within bounds, cost < 3 ms, then `✅ SUCCESS: PEDESTRIANS (parts A + B + C)`.
Run: `godot --headless --path . --script tests/test_free_roam.gd > /tmp/fr.log 2>&1; grep -E "SUCCESS|FAILED|build" /tmp/fr.log` — expected SUCCESS and the build still < 15 s (pedestrian setup adds the graph build, < 1.5 s).

- [ ] **Step 4: Preview**

Create `tests/preview_peds.gd`:

```gdscript
# File: res://tests/preview_peds.gd
# Ảnh người đi đường FreeRoam (cần cửa sổ render): vice_roam_peds_1 (trước sảnh BE6), vice_roam_peds_2 (cổng campus).
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
	if frames == 240:
		_save("vice_roam_peds_1")
		var gate: Vector3 = FPTUCampusBuilder.real_plot_transform() * (FPTUCampusBuilder.main_gate_local() + Vector3(0.0, 0.5, -14.0))
		(roam.get("player") as ThirdPersonController).teleport(gate, PI)
	if frames == 480:
		_save("vice_roam_peds_2")
		print("PREVIEW PEDS DONE")
		quit(0)
	return false
```

Run: `VICE_STYLE=vice PREVIEW_NOVSYNC=1 PREVIEW_DIR="$(pwd)/docs/preview" godot --path . --script tests/preview_peds.gd > /tmp/pp2.log 2>&1; grep -E "saved|DONE" /tmp/pp2.log`
Expected: two images with fps ≥ 45. Open them: PS2 pedestrians walk on verges and footways (never in the carriageway, water or inside buildings), students near the campus, residents around BE6.

- [ ] **Step 5: Regression and commit**

Run the regression command (all green), then:

```bash
git add scripts/roam/PedestrianSpawner.gd scripts/FreeRoam.gd tests/test_pedestrians.gd tests/preview_peds.gd docs/preview/vice_roam_peds_*.png
git commit -m "feat(peds): pedestrian spawner around the player (spawn ring, recycling, LOD, shared speech bubble, sprint/bike hit consequences) wired into FreeRoam

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Docs, final regression and fps table

**Files:**
- Modify: `README.md` (Vietnamese, player-facing), `PLAN.md` (new section, English), `docs/superpowers/plans/2026-10-22-vice-city-art-direction.md` (D3 and VC-6 notes), `docs/superpowers/specs/2026-10-22-vice-people-and-movement-design.md` (status line + implementation notes)

**Interfaces:**
- Consumes: everything above. Produces: docs only.

- [ ] **Step 1: README**

In `README.md`, in the controls section add the on-foot keys `Shift` (chạy nước rút, có thể lực), `Ctrl` (đi bộ), `Space` (nhảy; trên xe vẫn là drift); add one paragraph under the Vice City / open-world part: "Ở phong cách Vice City, mọi nhân vật là người kiểu PS2: tỉ lệ người thật, đầu ít mặt với gương mặt vẽ tay bằng code (8 biểu cảm), quần áo giữ nguyên. Ngoài thế giới mở có người đi đường đi trên lề và vỉa hè: va nhẹ thì họ lảo đảo càu nhàu, chạy nước rút hay đi xe tông thì họ ngã rồi đứng dậy bỏ chạy. Rơi từ cao không mất máu: dưới 2,5 m nhún gối, 2,5-6 m lăn, cao hơn thì nằm một lúc rồi đứng dậy."

- [ ] **Step 2: PLAN.md, vice plan, spec**

Add to `PLAN.md` a section "XIV. VICE PEOPLE AND GTA-STYLE MOVEMENT" (English): what was built (PS2Head, ps2 mode, rigged poses/bake, locomotion layer, controller states, walk graph, pedestrians, spawner), the controls, the landing thresholds, and the commit hashes of Tasks 1-11 (`git log --oneline`). In the vice plan's owner-decision table change D3 to "Superseded by docs/superpowers/specs/2026-10-22-vice-people-and-movement-design.md: PS2 people at realistic scale" and add under Task VC-6 "Outfit items dropped by the owner (clothes unchanged); vehicle paint stays". In the spec change the status line to "Implemented (commits ...)" and add a short "Implementation notes" list: `random_point_near` returns a node id (-1 when none); pedestrians are freed and respawned instead of pooled (at most 2 new per 0.25 s); verge lines run behind the kerb (MapBuilder draws kerbs, not sidewalks, along carriageways); a sprint jump covers about 4-4.5 m; vice-path tests live in `tests/test_ps2_people.gd`.

- [ ] **Step 3: Final regression and fps table**

Run the regression command; every line must be green. Then on main after the merge run the windowed previews once more with `PREVIEW_NOVSYNC=1` (`tests/preview_stages.gd` PREVIEW_ONLY=menu,s1,s2,s3,s4,s5,s6,ex; `tests/preview_peds.gd`) and collect the `fps=` numbers into a table in the PLAN.md section (gate: menu ≥ 60, stages ≥ 45, FreeRoam with pedestrians ≥ 45 at BE6 and the campus gate).

- [ ] **Step 4: Commit**

```bash
git add README.md PLAN.md docs/superpowers/plans/2026-10-22-vice-city-art-direction.md docs/superpowers/specs/2026-10-22-vice-people-and-movement-design.md
git commit -m "docs: vice people and GTA-style movement - README controls, PLAN section with fps table, spec status, vice plan D3/VC-6 notes

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
