# -*- coding: utf-8 -*-
"""Texture MẶT ĐỨNG campus v7 theo mô hình giấy FPTU HCM (vẽ bằng code Pillow/numpy, KHÔNG dùng ảnh AI):
  fptu_facade_modules.png / _n.png – 1 ô = 1 tầng (3,6 m) × 14 m tường trắng: 4 ô cửa kính tối khung xám nhạt,
                                     mạch sàn bê tông, ron tấm, vệt bẩn mưa nhẹ. Dán triplanar scale (1/14, 1/3.6, 1/14).
Chạy:  python generate_facade_texture.py
"""
import os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets", "textures")
random.seed(11)


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


def make_facade():
    W, H = 1024, 264  # 14 m × 3.6 m → 73 px/m
    ppm = W / 14.0
    base = np.array((238, 238, 234), dtype=np.float32)
    n = noise(W, H, 4, 0.55, 2)
    arr = base[None, None, :] + ((n - 0.5) * 14.0)[:, :, None]
    im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(im, "RGBA")
    height = np.full((H, W), 0.8, dtype=np.float32)
    # mạch sàn (mép sàn bê tông) ở đáy ô + ron tấm đứng mỗi 3,5 m
    d.rectangle([0, H - 14, W, H], fill=(214, 214, 210, 255))
    d.line([(0, H - 14), (W, H - 14)], fill=(170, 170, 166, 255), width=2)
    height[H - 14:, :] = 0.6
    for x in range(0, W, int(3.5 * ppm)):
        d.line([(x, 0), (x, H)], fill=(205, 205, 200, 140), width=2)
    # 4 ô cửa: rộng 1,7 m cao 1,75 m, bệ cửa cao 1,0 m, khung xám nhạt, kính xanh tối có phản chiếu trời
    for i in range(4):
        cx = (1.75 + i * 3.5) * ppm
        x0, x1 = int(cx - 0.85 * ppm), int(cx + 0.85 * ppm)
        y_bottom = int(H - 1.0 * ppm)
        y_top = int(H - 2.75 * ppm)
        d.rectangle([x0 - 6, y_top - 6, x1 + 6, y_bottom + 6], fill=(205, 207, 206, 255))
        # kính: gradient trời (sáng trên) + khung chia 2 cánh
        for yy in range(y_top, y_bottom):
            t = (yy - y_top) / max(1, (y_bottom - y_top))
            c = (int(70 + 60 * (1 - t)), int(92 + 60 * (1 - t)), int(118 + 50 * (1 - t)))
            d.line([(x0, yy), (x1, yy)], fill=c + (255,))
        d.line([(int(cx), y_top), (int(cx), y_bottom)], fill=(200, 202, 204, 255), width=3)
        d.line([(x0, int((y_top + y_bottom) * 0.5)), (x1, int((y_top + y_bottom) * 0.5))], fill=(200, 202, 204, 255), width=2)
        # phản chiếu chéo nhạt
        d.polygon([(x0, y_bottom), (x0 + 30, y_top), (x0 + 60, y_top), (x0 + 30, y_bottom)], fill=(255, 255, 255, 26))
        height[y_top - 6:y_bottom + 6, x0 - 6:x1 + 6] = 0.35
        # bệ cửa + vệt nước mưa dưới bệ
        d.rectangle([x0 - 10, y_bottom + 6, x1 + 10, y_bottom + 14], fill=(200, 200, 196, 255))
        for k in range(4):
            xx = random.randint(x0, x1)
            d.line([(xx, y_bottom + 14), (xx + random.randint(-3, 3), y_bottom + random.randint(20, 60))], fill=(190, 190, 186, 90), width=2)
    # lỗ thông gió nhỏ gần đỉnh ô giữa các cửa (chi tiết nhà thật)
    for i in range(4):
        cx = (3.5 + i * 3.5) * ppm
        if cx < W - 20:
            d.rectangle([int(cx) - 14, 18, int(cx) + 14, 30], fill=(120, 122, 124, 255))
            height[18:30, int(cx) - 14:int(cx) + 14] = 0.4
    im = im.filter(ImageFilter.GaussianBlur(0.3))
    save(im, "fptu_facade_modules.png")
    save(normal_from_height(height + (n - 0.5) * 0.05, 1.6), "fptu_facade_modules_n.png")


if __name__ == "__main__":
    make_facade()
    print("DONE")
