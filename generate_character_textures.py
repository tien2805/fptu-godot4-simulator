# -*- coding: utf-8 -*-
"""Texture cho NHÂN VẬT (CharacterBuilder.gd) – vẽ hoàn toàn bằng code Pillow/numpy, KHÔNG dùng ảnh AI.

Tạo trong assets/textures/ (phẳng, để khớp include_filter "assets/textures/*.png" của export):
  char_face_<tone><sex>_<open|closed>.png  – bản đồ mặt equirect cho SphereMesh (u=0.5 là phía trước -Z, v=0 đỉnh đầu)
                                            tone a..d (sáng → rám), sex m/f, mắt mở / nhắm (chớp mắt)
  char_shirt_fpt.png                        – áo polo cam FPT (nẹp cúc, logo FPT ngực trái, vải pique)
  char_cloth_n.png                          – normal map dệt vải (dùng chung cho mọi áo quần màu trơn)
  char_denim.png / char_denim_n.png         – jeans chéo twill
  char_hair_n.png                           – normal map sợi tóc
  char_skin_n.png                           – lỗ chân lông rất nhẹ
Kèm file .import "keep" để Godot đóng gói nguyên bản (dự án nạp ảnh bằng GameFX.load_image_any).
Chạy:  python generate_character_textures.py
"""
import os, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets", "textures")
os.makedirs(OUT_DIR, exist_ok=True)
random.seed(2026)
np.random.seed(2026)

# Bảng da người Việt (sáng → rám) – PHẢI khớp CharacterBuilder.SKIN_TONES
TONES = {"a": (243, 213, 181), "b": (232, 192, 154), "c": (213, 164, 122), "d": (190, 138, 94)}


def font(size, bold=True):
    for name in (["arialbd.ttf", "segoeuib.ttf"] if bold else ["arial.ttf", "segoeui.ttf"]):
        try:
            return ImageFont.truetype(name, size)
        except Exception:
            pass
    return ImageFont.load_default()


def save(im, name):
    path = os.path.join(OUT_DIR, name)
    im.save(path)
    imp = path + ".import"
    if not os.path.exists(imp):
        with open(imp, "w", encoding="utf-8", newline="\n") as f:
            f.write('[remap]\n\nimporter="keep"\n')
    print("  wrote", name)


def normal_from_height(h, strength=2.0, wrap=True):
    """h: float32 0..1 (H,W). Chuẩn OpenGL (Y+ lên trên ảnh) như Godot yêu cầu."""
    if wrap:
        gx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5
        gy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5
    else:
        gy, gx = np.gradient(h)
    nx = -gx * strength
    ny = gy * strength  # gy dương = cao dần xuống dưới ảnh → pháp tuyến ngả lên trên (OpenGL)
    nz = np.ones_like(h)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    rgb = np.stack([nx / l, ny / l, nz / l], axis=-1) * 0.5 + 0.5
    return Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), "RGB")


def noise(w, h, octaves=4, persistence=0.5, seed=0):
    rng = np.random.default_rng(seed)
    acc = np.zeros((h, w), dtype=np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        s = 2 ** o
        small = rng.random((max(2, h // (16 // min(16, s)) ), max(2, w // (16 // min(16, s)))) ).astype(np.float32)
        im = Image.fromarray((small * 255).astype(np.uint8), "L").resize((w, h), Image.BILINEAR)
        acc += np.asarray(im, dtype=np.float32) / 255.0 * amp
        total += amp
        amp *= persistence
    return acc / total


# ---------------------------------------------------------------- MẶT
EXPRESSIONS = ["open", "closed", "happy", "angry", "surprised", "done"]


def make_face(tone_key, sex, expr):
    """Bản đồ mặt 512x256 cho SphereMesh (u=0.5 phía trước). expr: open/closed (chớp mắt)/happy/angry/surprised/done.
    Ảnh nền RGB + Draw mode "RGBA" để Pillow BLEND alpha."""
    S = 2
    W, H = 256 * S, 128 * S
    base = TONES[tone_key]
    arr = np.zeros((H, W, 3), dtype=np.float32)
    for y in range(H):
        k = 1.0 - 0.10 * max(0.0, (y - 60 * S) / (68.0 * S))
        arr[y, :, :] = np.array(base, dtype=np.float32) * k
    n = (noise(W, H, 3, 0.6, 7) - 0.5) * 10.0
    arr += n[:, :, None]
    im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(im, "RGBA")

    def E(box, **kw):
        d.ellipse([v * S for v in box], **kw)

    cx, ey = 128 * S, 62 * S
    lash = (38, 24, 18, 255)
    blush = (235, 120, 110, 55) if sex == "f" else (220, 130, 110, 26)
    if expr == "happy":
        blush = (235, 110, 100, 95)
    for sx in (-1, 1):
        E([128 + sx * 30 - 16, 74 - 8, 128 + sx * 30 + 16, 74 + 8], fill=blush)
    for sx in (-1, 1):
        E([128 + sx * 12 - 10, 62 - 7, 128 + sx * 12 + 10, 62 + 6], fill=(60, 30, 20, 18))
    E([128 - 4, 62 + 4, 128 + 4, 62 + 18], fill=(255, 255, 255, 22))
    E([128 - 7, 62 + 14, 128 + 7, 62 + 21], fill=(70, 30, 20, 30))
    # lông mày theo biểu cảm
    brow_w = (2 if sex == "f" else 4) * S // 2 + 1
    for sx in (-1, 1):
        x0 = cx + sx * 12 * S
        pts = []
        for i in range(9):
            t = i / 8.0
            x = x0 + sx * (t - 0.5) * 20 * S
            arch = (-5.0 if sex == "f" else -2.5) * math.sin(t * math.pi) * S
            lift = 0.0
            if expr == "angry":
                lift = (6.0 - 10.0 * t) * S * (1 if sx > 0 else 1)  # đầu trong (t=0) hạ thấp, đầu ngoài nhô
                lift = (-4.0 + 10.0 * (1 - t)) * S if False else lift
            elif expr == "surprised":
                lift = -9.0 * S
            elif expr == "done":
                lift = 1.5 * S
            pts.append((x, ey - 10 * S + arch + lift + (1.5 * S if (sx * (t - 0.5)) > 0 else 0.0)))
        if expr == "angry":
            # vẽ lại: mày xếch vào trong (đầu trong thấp hơn)
            pts = [(x0 + sx * (t / 8.0 - 0.5) * 20 * S, ey - 12 * S + (t / 8.0) * 8 * S * -1 + 8 * S * (1 - t / 8.0) * 0) for t in range(9)]
            pts = [(x0 + sx * (t / 8.0 - 0.5) * 20 * S, ey - 5 * S - (t / 8.0) * 8 * S) for t in range(9)]
            pts = [(x0 - sx * 10 * S + sx * (t / 8.0) * 20 * S, ey - 5 * S - (1 - t / 8.0) * 0 - (t / 8.0) * 7 * S) for t in range(9)]
        d.line(pts, fill=(44, 30, 22, 235), width=brow_w, joint="curve")
    # mắt
    for sx in (-1, 1):
        x = cx + sx * 12 * S
        ew, eh = ((11, 7) if sex == "f" else (11, 6))
        ew *= S
        eh *= S
        if expr == "surprised":
            ew = int(ew * 1.25)
            eh = int(eh * 1.5)
        if expr in ("closed",):
            d.arc([x - 6 * S, ey - 3 * S, x + 6 * S, ey + 4 * S], 15, 165, fill=lash, width=S)
            continue
        if expr == "happy":
            # mắt cười: cung cong lên
            d.arc([x - 6 * S, ey - 2 * S, x + 6 * S, ey + 6 * S], 195, 345, fill=lash, width=S + 1)
            continue
        if expr == "done":
            eh = max(2 * S, eh // 2)
        d.ellipse([x - ew / 2, ey - eh / 2, x + ew / 2, ey + eh / 2], fill=(247, 243, 240, 255))
        ir = 3.4 * S if expr != "surprised" else 2.6 * S
        iy = ey if expr != "done" else ey + 1 * S
        d.ellipse([x - ir, iy - ir, x + ir, iy + ir], fill=(96, 60, 34, 255))
        d.ellipse([x - ir, iy - ir, x + ir, iy + ir], outline=(50, 30, 18, 255), width=1)
        pr = 1.6 * S if expr != "surprised" else 1.1 * S
        d.ellipse([x - pr, iy - pr, x + pr, iy + pr], fill=(14, 10, 8, 255))
        d.ellipse([x - 2.4 * S, iy - 2.6 * S, x - 0.9 * S, iy - 1.1 * S], fill=(255, 255, 255, 235))
        d.arc([x - ew / 2 - S, ey - eh / 2 - S, x + ew / 2 + S, ey + eh / 2 + S], 195, 345, fill=lash, width=S)
        if expr == "done":
            d.line([(x - ew / 2, ey - eh / 2), (x + ew / 2, ey - eh / 2)], fill=lash, width=S + 1)  # mí sụp
        if sex == "f":
            d.arc([x - ew / 2 - 2 * S, ey - eh / 2 - 2 * S, x + ew / 2 + 2 * S, ey + eh / 2 + 2 * S], 205, 335, fill=lash, width=1)
            d.line([(x + sx * 6 * S, ey - 3 * S), (x + sx * 8 * S, ey - 5.5 * S)], fill=lash, width=S)
        d.arc([x - ew / 2, ey - eh / 2, x + ew / 2, ey + eh / 2 + S], 20, 160, fill=(120, 80, 60, 120), width=1)
    for sx in (-1, 1):
        E([128 + sx * 3 - 1.5, 79 - 1, 128 + sx * 3 + 1.5, 79 + 1], fill=(40, 15, 10, 110))
    # miệng theo biểu cảm
    my = 91 * S
    if expr == "happy":
        d.chord([cx - 11 * S, my - 7 * S, cx + 11 * S, my + 6 * S], 0, 180, fill=(120, 48, 56, 255))
        d.chord([cx - 9 * S, my - 6 * S, cx + 9 * S, my + 1 * S], 0, 180, fill=(250, 250, 248, 255))
    elif expr == "angry":
        d.arc([cx - 9 * S, my - 1 * S, cx + 9 * S, my + 9 * S], 200, 340, fill=(118, 50, 50, 255), width=S + 1)
    elif expr == "surprised":
        d.ellipse([cx - 5 * S, my - 5 * S, cx + 5 * S, my + 6 * S], fill=(90, 36, 40, 255))
        d.ellipse([cx - 3 * S, my - 3 * S, cx + 3 * S, my + 1 * S], fill=(250, 250, 248, 255))
    elif expr == "done":
        d.line([(cx - 8 * S, my + 1 * S), (cx + 8 * S, my + 1 * S)], fill=(118, 62, 58, 255), width=S)
        # giọt mồ hôi xanh ở thái dương
        d.polygon([(cx + 30 * S, 50 * S), (cx + 33 * S, 60 * S), (cx + 27 * S, 60 * S)], fill=(130, 190, 240, 230))
        d.ellipse([cx + 27 * S, 57 * S, cx + 33 * S, 63 * S], fill=(130, 190, 240, 230))
    elif sex == "f":
        E([128 - 8, 91 - 3, 128 + 8, 91 + 1], fill=(196, 92, 104, 225))
        E([128 - 8, 91 - 1, 128 + 8, 91 + 4], fill=(206, 104, 112, 235))
        d.line([(cx - 8 * S, my), (cx, my + 0.5 * S), (cx + 8 * S, my)], fill=(120, 48, 56, 255), width=1)
        E([128 - 3, 91 + 1, 128 + 3, 91 + 3], fill=(255, 255, 255, 60))
    else:
        d.line([(cx - 7 * S, my), (cx, my + 0.8 * S), (cx + 7 * S, my)], fill=(118, 62, 58, 255), width=S)
        E([128 - 6, 91 + 1, 128 + 6, 91 + 4], fill=(190, 110, 100, 110))
    E([128 - 14, 104, 128 + 14, 118], fill=(60, 25, 15, 26))
    save(im, "char_face_%s%s_%s.png" % (tone_key, sex, expr))


def make_cloth_folds():
    """Albedo vải trơn có bóng và nếp gấp mềm (nhân với albedo_color của vật liệu) – 'vẽ tay' hơn màu phẳng."""
    W = H = 256
    n = noise(W, H, 4, 0.55, 17)
    yy, xx = np.mgrid[0:H, 0:W]
    folds = np.sin(xx * 0.11 + n * 6.0) * 0.5 + 0.5
    h = 0.78 + 0.22 * (folds * 0.6 + n * 0.4)
    arr = np.stack([h, h, h], axis=-1) * 255.0
    save(Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB"), "char_cloth_folds.png")


# ---------------------------------------------------------------- ÁO POLO FPT
def make_shirt_fpt():
    W, H = 512, 256
    base = np.array((243, 112, 33), dtype=np.float32)
    n = (noise(W, H, 4, 0.55, 11) - 0.5) * 14.0
    # vải pique: ô nhỏ 3 px
    yy, xx = np.mgrid[0:H, 0:W]
    pique = ((np.sin(xx * 2.1) * np.sin(yy * 2.1)) * 4.0)
    arr = base[None, None, :] + (n + pique)[:, :, None]
    im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    d = ImageDraw.Draw(im, "RGBA")
    # nẹp cúc giữa ngực (u=0.5 → x=256), từ cổ (v≈0.06) xuống v≈0.30
    d.rectangle([250, 14, 262, 78], fill=(225, 98, 26, 255))
    d.line([(250, 14), (250, 78)], fill=(205, 88, 22, 255), width=1)
    d.line([(262, 14), (262, 78)], fill=(205, 88, 22, 255), width=1)
    for by in (34, 56):
        d.ellipse([253, by - 3, 259, by + 3], fill=(250, 240, 225, 255))
        d.ellipse([254, by - 2, 258, by + 2], outline=(200, 150, 110, 255), width=1)
    # logo FPT ngực trái của nhân vật (−X ⇒ u≈0.58 → x≈297), v≈0.33 → y≈84
    lx, ly = 297, 84
    pad = 2
    f = font(15)
    tw = d.textlength("FPT", font=f)
    d.rounded_rectangle([lx - 3, ly - 2, lx + tw + 3, ly + 16], radius=3, fill=(255, 255, 255, 235))
    d.text((lx, ly - 2), "FPT", font=f, fill=(243, 112, 33, 255))
    d.text((lx, ly + 16), "UNIVERSITY", font=font(6, False), fill=(255, 245, 235, 230))
    # đường may vai / nách (v≈0.1) và gấu áo (v≈0.97)
    d.line([(0, 24), (W, 24)], fill=(222, 95, 25, 160), width=1)
    d.line([(0, H - 6), (W, H - 6)], fill=(222, 95, 25, 200), width=2)
    save(im.convert("RGB"), "char_shirt_fpt.png")


# ---------------------------------------------------------------- VẢI / DENIM / TÓC / DA (normal map)
def make_cloth_normal():
    W = H = 256
    yy, xx = np.mgrid[0:H, 0:W]
    weave = (np.sin(xx * math.pi / 2.0) * np.sin(yy * math.pi / 2.0)) * 0.5 + 0.5
    h = weave * 0.6 + noise(W, H, 3, 0.5, 21) * 0.4
    save(normal_from_height(h, 1.4), "char_cloth_n.png")


def make_denim():
    W = H = 256
    yy, xx = np.mgrid[0:H, 0:W]
    twill = ((xx + yy) % 6 < 3).astype(np.float32)
    n = noise(W, H, 4, 0.55, 31)
    base = np.array((58, 78, 118), dtype=np.float32)
    arr = base[None, None, :] + (twill * 14 - 7 + (n - 0.5) * 22)[:, :, None]
    # sợi bạc màu ngẫu nhiên
    rng = np.random.default_rng(5)
    for _ in range(900):
        x, y = rng.integers(0, W), rng.integers(0, H)
        arr[y, x] += 28
    save(Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB"), "char_denim.png")
    h = twill * 0.5 + n * 0.5
    save(normal_from_height(h, 1.2), "char_denim_n.png")


def make_hair_normal():
    W = H = 256
    rng = np.random.default_rng(9)
    cols = rng.random(W).astype(np.float32)
    strands = np.tile(cols[None, :], (H, 1))
    strands = np.asarray(Image.fromarray((strands * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(1.2)), dtype=np.float32) / 255.0
    wave = (np.sin(np.mgrid[0:H, 0:W][0] * 0.12 + cols[None, :] * 6.0) * 0.5 + 0.5) * 0.25
    h = strands * 0.75 + wave
    save(normal_from_height(h, 2.4), "char_hair_n.png")


def make_skin_normal():
    W = H = 256
    pores = noise(W, H, 5, 0.65, 41)
    save(normal_from_height(pores, 0.35), "char_skin_n.png")


if __name__ == "__main__":
    print("Generating character textures ->", OUT_DIR)
    for t in TONES:
        for s in ("m", "f"):
            for ex in EXPRESSIONS:
                make_face(t, s, ex)
    make_cloth_folds()
    make_shirt_fpt()
    make_cloth_normal()
    make_denim()
    make_hair_normal()
    make_skin_normal()
    print("DONE")
