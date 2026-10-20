# -*- coding: utf-8 -*-
"""Texture cho ĐỒ VẬT (PropBuilder.gd) – vẽ bằng code Pillow/numpy, KHÔNG dùng ảnh AI.
  prop_wood.png / prop_wood_n.png        – vân gỗ (bàn căn tin, nộm gỗ, ghế)
  prop_metal_brushed.png / _n.png        – kim loại xước (ống xả, khung xe, chân bàn)
  prop_leather.png / prop_leather_n.png  – da yên xe / đệm đầu nộm
  prop_tread_n.png                       – normal gai lốp
  prop_plate_59.png                      – biển số xe máy TP.HCM (chữ vẽ bằng font hệ thống)
  prop_bus_side.png                      – dải trang trí thân xe buýt (sọc + chữ) – hai biến thể F-Bus / VinBus
Chạy:  python generate_prop_textures.py
"""
import os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets", "textures")
os.makedirs(OUT_DIR, exist_ok=True)


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
        cell = max(2, 2 ** (o + 2))
        small = rng.random((max(2, h // (h // cell)), max(2, w // (w // cell)))).astype(np.float32)
        im = Image.fromarray((small * 255).astype(np.uint8), "L").resize((w, h), Image.BICUBIC)
        acc += np.asarray(im, dtype=np.float32) / 255.0 * amp
        total += amp
        amp *= persistence
    return acc / total


def make_wood():
    W = H = 512
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    warp = noise(W, H, 4, 0.55, 3) * 40.0
    rings = np.sin((xx + warp) * 0.11 + np.sin(yy * 0.012) * 3.0) * 0.5 + 0.5
    grain = noise(W, H, 5, 0.6, 4)
    h = rings * 0.65 + grain * 0.35
    base = np.array((172, 118, 70), dtype=np.float32)
    dark = np.array((96, 60, 32), dtype=np.float32)
    arr = dark[None, None, :] * (1.0 - h)[:, :, None] + base[None, None, :] * h[:, :, None]
    # vệt gỗ dọc mảnh
    streak = (np.sin(xx * 0.9 + warp * 0.3) > 0.97).astype(np.float32) * 18.0
    arr -= streak[:, :, None]
    save(Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB"), "prop_wood.png")
    save(normal_from_height(h, 1.2), "prop_wood_n.png")


def make_metal():
    W = H = 256
    rng = np.random.default_rng(8)
    rows = rng.random(H).astype(np.float32)
    streaks = np.tile(rows[:, None], (1, W))
    streaks = np.asarray(Image.fromarray((streaks * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(0.8)), dtype=np.float32) / 255.0
    n = noise(W, H, 3, 0.5, 9)
    h = streaks * 0.7 + n * 0.3
    arr = 150 + (h - 0.5) * 60
    save(Image.fromarray(np.clip(np.stack([arr, arr, arr + 4], axis=-1), 0, 255).astype(np.uint8), "RGB"), "prop_metal_brushed.png")
    save(normal_from_height(h, 0.8), "prop_metal_brushed_n.png")


def make_leather():
    W = H = 256
    yy, xx = np.mgrid[0:H, 0:W]
    cells = noise(W, H, 5, 0.7, 12)
    pebble = np.abs(np.sin(xx * 0.5 + cells * 9.0) * np.sin(yy * 0.5 + cells * 7.0))
    h = pebble * 0.6 + cells * 0.4
    base = np.array((40, 36, 38), dtype=np.float32)
    arr = base[None, None, :] + (h - 0.5)[:, :, None] * 26.0
    save(Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB"), "prop_leather.png")
    save(normal_from_height(h, 1.6), "prop_leather_n.png")


def make_tread():
    W = H = 256
    yy, xx = np.mgrid[0:H, 0:W]
    blocks = (((xx // 32) + (yy // 16)) % 2).astype(np.float32)
    groove = ((yy % 16) < 3).astype(np.float32)
    h = blocks * 0.5 + (1.0 - groove) * 0.5
    save(normal_from_height(h, 2.0), "prop_tread_n.png")


def make_plate():
    im = Image.new("RGB", (256, 192), (245, 245, 240))
    d = ImageDraw.Draw(im)
    d.rectangle([3, 3, 252, 188], outline=(20, 20, 20), width=5)
    f1, f2 = font(64), font(74)
    d.text((128, 52), "59-X1", font=f1, fill=(15, 15, 15), anchor="mm")
    d.text((128, 136), "280.05", font=f2, fill=(15, 15, 15), anchor="mm")
    save(im, "prop_plate_59.png")


def make_bus_side(name, color, accent, text):
    W, H = 1024, 256
    im = Image.new("RGB", (W, H), color)
    d = ImageDraw.Draw(im)
    # sọc trang trí chéo
    for i in range(-3, 9):
        x0 = i * 150
        d.polygon([(x0, H), (x0 + 110, H), (x0 + 210, 0), (x0 + 100, 0)], fill=accent)
    d.rectangle([0, 0, W, 34], fill=(240, 240, 240))
    d.rectangle([0, H - 30, W, H], fill=(30, 30, 30))
    d.text((W // 2, H // 2), text, font=font(110), fill=(255, 255, 255), anchor="mm", stroke_width=5, stroke_fill=(25, 25, 25))
    save(im, name)


if __name__ == "__main__":
    print("Generating prop textures ->", OUT_DIR)
    make_wood()
    make_metal()
    make_leather()
    make_tread()
    make_plate()
    make_bus_side("prop_bus_side_fbus.png", (243, 112, 33), (255, 160, 90), "F-BUS FPTU")
    make_bus_side("prop_bus_side_vinbus.png", (0, 168, 89), (60, 200, 130), "VINBUS")
    print("DONE")
