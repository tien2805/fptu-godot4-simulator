# -*- coding: utf-8 -*-
"""Texture cho SẢNH TRỐNG ĐỒNG và sảnh tầng trệt (campus v7) – vẽ bằng code Pillow/numpy, KHÔNG dùng ảnh AI.
  fptu_terrazzo_lobby.png / _n.png   – sàn đá mài hoa văn đa giác xám/trắng/đen như sảnh chính FPTU HCM
  fptu_graffiti_stair.png            – mặt tường cầu thang khán đài đỏ vẽ graffiti (ASAP · FPTU · mũi tên)
  fptu_concrete_beam.png / _n.png    – bê tông trần lộ dầm (vân ván khuôn)
  fptu_bronze_drum.png               – hoa văn mặt trống đồng (ngôi sao 14 cánh + vòng hoa văn) dán lên mặt trống
Chạy:  python generate_lobby_textures.py
"""
import os, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets", "textures")
os.makedirs(OUT_DIR, exist_ok=True)
random.seed(7)


def font(size, bold=True):
    for name in (["arialbd.ttf", "segoeuib.ttf", "impact.ttf"] if bold else ["arial.ttf", "segoeui.ttf"]):
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


def normal_from_height(h, strength=2.0):
    gx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5
    gy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5
    nx, ny, nz = -gx * strength, gy * strength, np.ones_like(h)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    rgb = np.stack([nx / l, ny / l, nz / l], axis=-1) * 0.5 + 0.5
    return Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), "RGB")


def noise(w, h, octaves=4, persistence=0.5, seed=0):
    rng = np.random.default_rng(seed)
    acc = np.zeros((h, w), dtype=np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        cell = 2 ** (o + 2)
        small = rng.random((max(2, h // cell), max(2, w // cell))).astype(np.float32)
        im = Image.fromarray((small * 255).astype(np.uint8), "L").resize((w, h), Image.BICUBIC)
        acc += np.asarray(im, dtype=np.float32) / 255.0 * amp
        total += amp
        amp *= persistence
    return acc / total


def make_terrazzo():
    """Sàn đá mài hoa văn đa giác lớn (Voronoi) 3 tông: trắng xám, xám đậm, đen; vân đá mài li ti."""
    W = H = 1024
    im = Image.new("RGB", (W, H), (205, 205, 203))
    d = ImageDraw.Draw(im)
    rng = np.random.default_rng(3)
    # Voronoi: 60 hạt, mỗi ô một tông (mod 3 có trọng số: 55% sáng, 30% xám, 15% đen)
    pts = rng.random((60, 2)) * [W, H]
    tones = []
    for i in range(60):
        r = rng.random()
        tones.append((214, 214, 211) if r < 0.55 else ((150, 152, 154) if r < 0.85 else (36, 38, 42)))
    yy, xx = np.mgrid[0:H, 0:W]
    # chỉ số ô gần nhất (wrap ngang/dọc để tile)
    best = np.full((H, W), 1e18); idx = np.zeros((H, W), dtype=np.int32); second = np.full((H, W), 1e18)
    for i, (px, py) in enumerate(pts):
        for ox in (-W, 0, W):
            for oy in (-H, 0, H):
                d2 = (xx - (px + ox)) ** 2 + (yy - (py + oy)) ** 2
                closer = d2 < best
                second = np.where(closer, best, np.minimum(second, d2))
                idx = np.where(closer, i, idx)
                best = np.where(closer, d2, best)
    arr = np.zeros((H, W, 3), dtype=np.float32)
    for i, t in enumerate(tones):
        arr[idx == i] = t
    # ron trắng mảnh giữa các ô (nơi best ≈ second)
    edge = (np.sqrt(second) - np.sqrt(best)) < 2.2
    arr[edge] = (238, 238, 236)
    # vân đá mài: hạt đá nhỏ màu ngẫu nhiên
    grain = noise(W, H, 5, 0.6, 5)
    arr += ((grain - 0.5) * 18.0)[:, :, None]
    im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")
    dd = ImageDraw.Draw(im)
    for _ in range(9000):
        x, y = random.randint(0, W - 3), random.randint(0, H - 3)
        s = random.randint(1, 3)
        c = random.choice([(250, 250, 248), (120, 120, 122), (60, 60, 64), (190, 170, 150)])
        dd.ellipse([x, y, x + s, y + s], fill=c)
    im = im.filter(ImageFilter.GaussianBlur(0.4))
    save(im, "fptu_terrazzo_lobby.png")
    h = np.asarray(im.convert("L"), dtype=np.float32) / 255.0
    save(normal_from_height(h, 0.5), "fptu_terrazzo_lobby_n.png")


def make_graffiti():
    """Tường cầu thang khán đài: nền đỏ, chữ graffiti khối ASAP / FPTU / AS SOON AS POSSIBLE, mũi tên, vệt sơn."""
    W, H = 1024, 512
    im = Image.new("RGB", (W, H), (196, 38, 34))
    d = ImageDraw.Draw(im)
    n = noise(W, H, 4, 0.5, 9)
    arr = np.asarray(im, dtype=np.float32) + ((n - 0.5) * 26.0)[:, :, None]
    im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(im)
    # vệt sơn loang
    for _ in range(40):
        x, y = random.randint(0, W), random.randint(0, H)
        r = random.randint(20, 90)
        c = random.choice([(230, 60, 50), (160, 20, 20), (240, 240, 240), (20, 20, 20), (255, 200, 40)])
        d.ellipse([x - r, y - r // 3, x + r, y + r // 3], fill=c + (0,), outline=None)
    # chữ khối với viền đen dày
    def block(text, x, y, size, fill):
        f = font(size)
        for dx in (-6, 6):
            for dy in (-6, 6):
                d.text((x + dx, y + dy), text, font=f, fill=(15, 15, 15))
        d.text((x, y), text, font=f, fill=fill)
    block("ASAP", 60, 40, 170, (250, 250, 250))
    block("FPTU", 560, 70, 150, (255, 205, 50))
    block("AS SOON AS POSSIBLE", 70, 300, 64, (250, 250, 250))
    block("CÓC VÀNG", 640, 380, 72, (255, 205, 50))
    # mũi tên graffiti
    for (x, y, dirn) in [(420, 230, 1), (930, 260, -1)]:
        d.polygon([(x, y), (x + 70 * dirn, y - 40), (x + 70 * dirn, y - 15), (x + 150 * dirn, y - 15), (x + 150 * dirn, y + 15), (x + 70 * dirn, y + 15), (x + 70 * dirn, y + 40)], fill=(20, 20, 20))
    # giọt sơn chảy
    for _ in range(80):
        x = random.randint(0, W)
        y = random.randint(0, H - 60)
        d.line([(x, y), (x, y + random.randint(10, 60))], fill=random.choice([(15, 15, 15), (245, 245, 245), (255, 205, 50)]), width=random.randint(2, 4))
    save(im, "fptu_graffiti_stair.png")


def make_concrete_beam():
    W = H = 512
    n = noise(W, H, 5, 0.55, 13)
    yy, xx = np.mgrid[0:H, 0:W]
    boards = ((xx // 128) % 2).astype(np.float32) * 0.08 + ((yy % 128) < 3).astype(np.float32) * 0.2
    h = n * 0.8 + boards
    base = np.array((168, 168, 165), dtype=np.float32)
    arr = base[None, None, :] + ((h - 0.5) * 50.0)[:, :, None]
    rng = np.random.default_rng(4)
    for _ in range(300):
        x, y = rng.integers(0, W), rng.integers(0, H)
        arr[y:y + 2, x:x + 2] -= 40
    save(Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB"), "fptu_concrete_beam.png")
    save(normal_from_height(h, 1.0), "fptu_concrete_beam_n.png")


def make_bronze_drum_face():
    """Mặt trống đồng Đông Sơn cách điệu: ngôi sao 14 cánh ở tâm, các vòng hoa văn răng cưa / chim lạc (tam giác, vòng tròn)."""
    W = H = 1024
    im = Image.new("RGB", (W, H), (120, 92, 54))
    d = ImageDraw.Draw(im)
    cx = cy = W // 2
    dark = (62, 46, 26)
    light = (176, 140, 84)
    # vòng tròn đồng tâm
    for r in range(60, 500, 44):
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=dark, width=5)
        if (r // 44) % 2 == 0:
            d.ellipse([cx - r + 14, cy - r + 14, cx + r - 14, cy + r - 14], outline=light, width=2)
    # răng cưa / tam giác ở vài vành
    for r0 in (180, 300, 420):
        for i in range(48):
            a0 = i * 2 * math.pi / 48
            a1 = (i + 0.5) * 2 * math.pi / 48
            a2 = (i + 1) * 2 * math.pi / 48
            p = [(cx + math.cos(a0) * r0, cy + math.sin(a0) * r0), (cx + math.cos(a1) * (r0 + 26), cy + math.sin(a1) * (r0 + 26)), (cx + math.cos(a2) * r0, cy + math.sin(a2) * r0)]
            d.polygon(p, fill=dark if i % 2 == 0 else light)
    # chim lạc cách điệu (hình thoi + mỏ dài) trên vành 240
    for i in range(14):
        a = i * 2 * math.pi / 14
        r = 250
        px, py = cx + math.cos(a) * r, cy + math.sin(a) * r
        tx, ty = -math.sin(a), math.cos(a)
        body = [(px - tx * 22, py - ty * 22), (px + math.cos(a) * 12, py + math.sin(a) * 12), (px + tx * 22, py + ty * 22), (px - math.cos(a) * 12, py - math.sin(a) * 12)]
        d.polygon(body, fill=dark)
        d.line([(px + tx * 22, py + ty * 22), (px + tx * 60, py + ty * 60 - 10)], fill=dark, width=5)
    # ngôi sao 14 cánh ở tâm
    pts = []
    for i in range(28):
        a = i * math.pi / 14 - math.pi / 2
        r = 120 if i % 2 == 0 else 48
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    d.polygon(pts, fill=light, outline=dark)
    d.ellipse([cx - 14, cy - 14, cx + 14, cy + 14], fill=dark)
    # patina nhẹ
    n = noise(W, H, 4, 0.55, 21)
    arr = np.asarray(im, dtype=np.float32) + ((n - 0.5) * 30.0)[:, :, None]
    im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")
    save(im, "fptu_bronze_drum.png")


if __name__ == "__main__":
    print("Generating lobby textures ->", OUT_DIR)
    make_terrazzo()
    make_graffiti()
    make_concrete_beam()
    make_bronze_drum_face()
    print("DONE")
