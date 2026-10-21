# -*- coding: utf-8 -*-
"""Texture THÀNH PHỐ cho thế giới mở trên bản đồ thật (MapBuilder, plan Task 2) theo art direction GTA Vice City:
mặt đứng pastel (hồng / bạc hà / đào / tím nhạt) với các dải ngang art-deco, kính xanh ngọc ánh hoàng hôn,
tô phẳng kiểu PS2. Vẽ hoàn toàn bằng code Pillow/numpy, KHÔNG dùng ảnh thật, KHÔNG dùng ảnh AI.

Mỗi file rộng 512 px, lặp được theo x; mặt đứng 1 tầng cũng lặp được theo y. "Tile" = kích thước thật một lần lặp
phủ lên tường. Mesh của MapBuilder có UV u = chiều dài cạnh / 3 m, v = số tầng, nên _mat_for_style(style) đặt
uv1_scale = (3.0 / tile_w_m, 1.0 / số_tầng_mỗi_tile, 1). Mép DƯỚI ảnh = mạch sàn (tầng trệt với shophouse).

  city_tower_facade.png (+_n)    3,0 m x 1 tầng    tháp kính (Rainbow S1..S10): 1 nhịp = 2 ô kính 1,16 m, trụ hồng, dải spandrel
  city_beverly_facade.png (+_n)  3,0 m x 1 tầng    The Beverly: tường kem, sàn ban công trắng, lan can kính xanh ngọc, cửa lùa
  city_mall_facade.png           6,0 m x 1 tầng    Vincom: 4 tấm kính lớn 1,3 m dưới dải biển hiệu cam
  city_shophouse_facade.png     12,0 m x 3 tầng    3 nhà phố 4 m: cửa cuốn + bảng hiệu, 2 cửa sổ mỗi tầng, mỗi căn một màu pastel
  city_industrial_facade.png     6,0 m x 1 tầng    tôn sóng bạc hà, cửa cuốn, ô cửa sổ cao 1,2 m, ống thoát nước
  city_canal_water.png           8 m x 8 m          nước kênh xanh ngọc, lặp 2 chiều
  city_road_overlay.png (RGBA)   4 m dọc x 1 lòng đường ngang: vạch mép trắng + vạch tim vàng đứt (2 m vạch / 2 m trống)
  city_roof_flat.png             4 m x 4 m          mái bằng xám hồng nhạt với khe co giãn 2 m, lặp 2 chiều
Kèm file .import "keep" để Godot đóng gói nguyên bản (dự án nạp ảnh bằng FileAccess + load_png_from_buffer).
Chạy:  python generate_city_textures.py      (kiểm tra: python tests/test_city_textures.py)
"""
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFont

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets", "textures")
os.makedirs(OUT_DIR, exist_ok=True)
random.seed(1986)

W = 512          # chiều rộng mọi texture
STOREY_M = 3.2   # chiều cao một tầng (MapBuilder: BE6 30 tầng ~ 96 m)

# Bảng màu Vice City (Miami thập niên 80)
PAL = {
    "pink": (242, 172, 206), "hot_pink": (236, 96, 164), "magenta": (214, 58, 150),
    "mint": (166, 228, 210), "mint_pale": (204, 228, 218), "teal": (52, 188, 190),
    "peach": (250, 204, 166), "peach_dark": (226, 170, 136), "salmon": (246, 150, 136),
    "lilac": (198, 176, 230), "lilac_light": (224, 212, 240), "lemon": (250, 236, 170), "sky": (172, 216, 236),
    "cream": (248, 240, 222), "white": (252, 250, 244), "white_warm": (246, 240, 228),
    "frame": (232, 232, 236), "silver": (226, 228, 230),
    "orange": (255, 148, 66), "orange_deep": (236, 96, 84),
    "dark": (48, 44, 62), "slab": (150, 120, 134), "concrete": (184, 182, 176),
    "shutter": (206, 206, 212), "door_teal": (112, 184, 178),
}
# Bảng hiệu nhà phố: loại hình quán chung chung, không dùng thương hiệu thật
SIGN_WORDS = ["CÀ PHÊ", "TẠP HÓA", "SỬA XE", "PHỞ BÒ", "KARAOKE", "BÁNH MÌ", "TRÀ SỮA", "NAIL SPA"]


# ---------------------------------------------------------------- tiện ích (chép từ generate_facade_texture.py)
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


def noise(w, h, octaves=4, persistence=0.5, seed=0, cell0=4):
    """Như generate_facade_texture.noise nhưng TUẦN HOÀN: lưới ngẫu nhiên mỗi octave được xếp 3x3 trước khi
    phóng to rồi cắt ô giữa, nên kết quả lặp được theo cả hai trục (cần cho texture tile).
    cell0 = cỡ ô (px) của octave mịn nhất; cell0 lớn (16..32) cho nhiễu mềm, không có hạt."""
    rng = np.random.default_rng(seed)
    acc = np.zeros((h, w), dtype=np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        cell = cell0 * 2 ** o
        small = rng.random((max(2, h // cell), max(2, w // cell))).astype(np.float32)
        big = Image.fromarray((np.tile(small, (3, 3)) * 255).astype(np.uint8), "L").resize((w * 3, h * 3), Image.BICUBIC)
        acc += np.asarray(big, dtype=np.float32)[h:2 * h, w:2 * w] / 255.0 * amp
        total += amp
        amp *= persistence
    return acc / total


def blur_wrap(a, passes=2):
    """Làm mờ hộp 3x3 tuần hoàn (np.roll) để mép bản đồ độ cao thành vát 2-3 px mà vẫn tile được."""
    for _ in range(passes):
        a = sum(np.roll(np.roll(a, dy, 0), dx, 1) for dy in (-1, 0, 1) for dx in (-1, 0, 1)) / 9.0
    return a


def font(size, bold=True):
    for name in (["arialbd.ttf", "segoeuib.ttf"] if bold else ["arial.ttf", "segoeui.ttf"]):
        try:
            return ImageFont.truetype(name, size)
        except Exception:
            pass
    return ImageFont.load_default()


class Canvas:
    """Albedo RGB + bản đồ độ cao L vẽ song song. Mọi hình được vẽ thêm ở +-W (và +-H khi wrap_y) nên hình cắt
    qua mép tile sẽ nối liền ở mép đối diện (tile không có đường nối)."""

    def __init__(self, w, h, base, noise_amp=5.0, seed=0, height=0.6, wrap_y=True):
        self.w, self.h = w, h
        if isinstance(base, np.ndarray):
            arr = base.astype(np.float32)
        else:
            n = noise(w, h, 3, 0.5, seed)
            arr = np.array(base, np.float32)[None, None, :] + ((n - 0.5) * noise_amp)[:, :, None]
        self.im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")
        if isinstance(height, np.ndarray):
            self.hm = Image.fromarray((np.clip(height, 0, 1) * 255).astype(np.uint8), "L")
        else:
            self.hm = Image.new("L", (w, h), int(round(height * 255)))
        self.d = ImageDraw.Draw(self.im, "RGBA")
        self.dh = ImageDraw.Draw(self.hm)
        ys = (-h, 0, h) if wrap_y else (0,)
        self.offsets = [(dx, dy) for dx in (-w, 0, w) for dy in ys]

    def _boxes(self, box):
        x0, y0, x1, y1 = [int(round(v)) for v in box]
        return [[x0 + dx, y0 + dy, x1 + dx, y1 + dy] for dx, dy in self.offsets]

    def hrect(self, box, height):
        for b in self._boxes(box):
            self.dh.rectangle(b, fill=int(round(height * 255)))

    def rect(self, box, fill, height=None):
        for b in self._boxes(box):
            self.d.rectangle(b, fill=fill)
        if height is not None:
            self.hrect(box, height)

    def poly(self, pts, fill, height=None):
        for dx, dy in self.offsets:
            p = [(x + dx, y + dy) for x, y in pts]
            self.d.polygon(p, fill=fill)
            if height is not None:
                self.dh.polygon(p, fill=int(round(height * 255)))

    def vgrad(self, box, top, bottom, height=None):
        x0, y0, x1, y1 = [int(round(v)) for v in box]
        n = max(1, y1 - y0 - 1)
        for i, yy in enumerate(range(y0, y1)):
            t = i / n
            c = tuple(int(round(top[k] + (bottom[k] - top[k]) * t)) for k in range(3)) + (255,)
            for dx, dy in self.offsets:
                self.d.line([(x0 + dx, yy + dy), (x1 - 1 + dx, yy + dy)], fill=c)
        if height is not None:
            self.hrect(box, height)

    def slats(self, box, color, pitch, height=None, line=1, shade=(0, 0, 0, 70)):
        """Cửa cuốn / tấm lá sách: nền màu + vạch tối mỗi `pitch` px."""
        self.rect(box, color, height)
        x0, y0, x1, y1 = [int(round(v)) for v in box]
        y = y0
        while y < y1:
            self.rect([x0, y, x1, min(y1, y + line)], shade, None if height is None else height - 0.08)
            y += pitch

    def paste(self, img, xy):
        for dx, dy in self.offsets:
            self.im.paste(img, (xy[0] + dx, xy[1] + dy), img)

    def glass(self, box, seed=0, height=None, top=(96, 198, 216), bottom=(28, 62, 112)):
        """Kính: gradient trời xanh ngọc -> xanh đậm, 2 vệt phản chiếu hoàng hôn (cam, hồng) chéo, viền sáng trên."""
        x0, y0, x1, y1 = [int(round(v)) for v in box]
        bw, bh = max(1, x1 - x0), max(1, y1 - y0)
        g = Image.new("RGBA", (bw, bh))
        gd = ImageDraw.Draw(g, "RGBA")
        for yy in range(bh):
            t = yy / max(1, bh - 1)
            gd.line([(0, yy), (bw, yy)], fill=tuple(int(round(top[k] + (bottom[k] - top[k]) * t)) for k in range(3)) + (255,))
        rng = random.Random(seed)
        for col, frac in (((255, 158, 96, 86), 0.5), ((236, 92, 170, 64), 0.18)):
            sx = int(bw * (frac + rng.uniform(-0.08, 0.08)))
            wd = max(2, int(bw * 0.2))
            gd.polygon([(sx, bh), (sx + wd, bh), (sx + wd + bh // 2, 0), (sx + bh // 2, 0)], fill=col)
        gd.rectangle([0, 0, bw, max(1, bh // 18)], fill=(255, 255, 255, 44))
        self.paste(g, (x0, y0))
        if height is not None:
            self.hrect(box, height)

    def text(self, xy, s, fill, fnt):
        for dx, dy in self.offsets:
            self.d.text((xy[0] + dx, xy[1] + dy), s, fill=fill, font=fnt, anchor="mm")

    def height(self):
        return np.asarray(self.hm, dtype=np.float32) / 255.0

    def normal(self, seed, strength=1.6):
        h = blur_wrap(self.height()) + (noise(self.w, self.h, 4, 0.5, seed) - 0.5) * 0.03
        return normal_from_height(h, strength)


def ppm_for(tile_w_m):
    """px/m và chiều cao ảnh (px) cho một tile rộng tile_w_m, cao 1 tầng."""
    ppm = W / tile_w_m
    return ppm, int(round(STOREY_M * ppm))


# ---------------------------------------------------------------- mặt đứng
def make_tower():
    """Tháp kính 3 m x 1 tầng: trụ hồng rộng 0,6 m nằm giữa mép tile, 2 ô kính 1,16 m, spandrel đào với dải xanh ngọc."""
    ppm, H = ppm_for(3.0)
    P = lambda m: int(round(m * ppm))
    c = Canvas(W, H, PAL["cream"], noise_amp=4, seed=11, height=0.7)
    y_sp = P(2.3)
    c.rect([0, y_sp, W, H], PAL["peach"], 0.72)                              # spandrel
    c.rect([0, y_sp, W, y_sp + P(0.16)], PAL["teal"], 0.74)                   # dải xanh ngọc ngay dưới kính
    c.rect([0, y_sp + P(0.16), W, y_sp + P(0.21)], PAL["white"], 0.74)        # pinstripe trắng
    c.rect([0, H - P(0.32), W, H - P(0.24)], PAL["magenta"], 0.72)            # pinstripe magenta gần sàn
    c.rect([0, H - P(0.04), W, H], PAL["slab"], 0.62)                        # mạch sàn (nửa dưới)
    c.rect([0, 0, W, P(0.04)], PAL["slab"], 0.62)                            # mạch sàn (nửa trên, nối khi lặp)
    gx0, gx1, gy0 = P(0.30), P(2.70), P(0.10)
    c.rect([gx0 - P(0.06), P(0.04), gx1 + P(0.06), y_sp + P(0.03)], PAL["frame"], 0.66)   # khung
    c.glass([gx0, gy0, gx1, y_sp], seed=1, height=0.42)
    c.rect([P(1.46), gy0, P(1.54), y_sp], PAL["frame"], 0.66)                 # đố giữa -> 2 ô 1,16 m
    c.rect([gx0, P(1.25), gx1, P(1.25) + 3], PAL["frame"], 0.66)             # thanh ngang mỏng
    c.rect([-P(0.30), 0, P(0.30), H], PAL["pink"], 0.9)                      # trụ hồng giữa mép
    c.rect([-P(0.035), 0, P(0.035), H], PAL["white"], 0.9)                   # pinstripe dọc trụ
    save(c.im, "city_tower_facade.png")
    save(c.normal(12), "city_tower_facade_n.png")


def make_beverly():
    """The Beverly 3 m x 1 tầng: sàn ban công trắng 0,3 m vắt qua mạch tầng, lan can kính xanh ngọc 1,1 m,
    cửa lùa kính phía sau, tường kem, pinstripe xanh ngọc trên lanh tô."""
    ppm, H = ppm_for(3.0)
    P = lambda m: int(round(m * ppm))
    c = Canvas(W, H, PAL["cream"], noise_amp=4, seed=21, height=0.75)
    c.rect([0, P(0.14), W, P(0.20)], PAL["teal"], 0.78)                      # pinstripe lanh tô
    c.rect([P(0.39), P(0.30), P(2.61), P(2.95)], PAL["frame"], 0.6)           # khung cửa lùa
    c.glass([P(0.45), P(0.36), P(2.55), P(2.95)], seed=2, height=0.4)
    c.rect([P(1.47), P(0.36), P(1.53), P(2.95)], PAL["frame"], 0.6)           # đố giữa cửa lùa
    c.rect([P(0.25), P(1.85), P(2.75), P(2.95)], PAL["teal"] + (150,), 0.62)  # lan can kính (trong mờ)
    c.rect([P(0.25), P(1.85), P(2.75), P(1.90)], PAL["silver"], 0.66)         # tay vịn
    for x in (0.25, 1.5, 2.75):
        c.rect([P(x) - 2, P(1.85), P(x) + 2, P(2.95)], PAL["silver"], 0.66)   # trụ lan can
    c.rect([P(0.25), P(2.95), P(2.75), H], PAL["white"], 1.0)                 # sàn ban công (phần dưới)
    c.rect([P(0.25), 0, P(2.75), P(0.05)], PAL["white"], 1.0)                 # mép trên sàn (nối khi lặp)
    c.rect([P(0.25), H - P(0.06), P(2.75), H], PAL["peach_dark"], 0.95)       # bóng dưới sàn
    c.rect([-P(0.25), 0, P(0.25), H], PAL["white_warm"], 0.85)               # vách ngăn căn hộ giữa mép
    save(c.im, "city_beverly_facade.png")
    save(c.normal(22), "city_beverly_facade_n.png")


def make_mall():
    """Vincom 6 m x 1 tầng: dải biển hiệu cam (gradient) với hoạ tiết thoi, 4 tấm kính 1,3 m, trụ tím nhạt giữa mép."""
    ppm, H = ppm_for(6.0)
    P = lambda m: int(round(m * ppm))
    c = Canvas(W, H, PAL["lilac_light"], noise_amp=3, seed=31, height=0.7)
    c.rect([0, H - P(0.05), W, H], PAL["slab"], 0.6)
    c.rect([0, 0, W, P(0.03)], PAL["slab"], 0.6)
    c.vgrad([0, P(0.03), W, P(0.78)], PAL["orange"], PAL["orange_deep"], 0.76)   # dải biển hiệu
    c.rect([0, P(0.03), W, P(0.08)], (255, 204, 128), 0.76)
    c.rect([0, P(0.72), W, P(0.78)], PAL["cream"], 0.76)
    for k in range(5):                                                      # hoạ tiết thoi art-deco
        cx, cy, s = P(1.0 + k), P(0.40), P(0.15)
        c.poly([(cx, cy - s), (cx + s, cy), (cx, cy + s), (cx - s, cy)], PAL["cream"] + (210,), 0.78)
    c.rect([P(0.34), P(0.78), P(5.66), H - P(0.05)], PAL["frame"], 0.66)
    c.glass([P(0.40), P(0.84), P(5.60), H - P(0.05)], seed=3, height=0.4)
    for k in range(1, 4):
        c.rect([P(0.4 + 1.3 * k) - 3, P(0.78), P(0.4 + 1.3 * k) + 3, H - P(0.05)], PAL["frame"], 0.66)
    c.rect([P(0.40), P(1.95) - 2, P(5.60), P(1.95) + 2], PAL["frame"], 0.66)
    c.rect([-P(0.40), 0, P(0.40), H], PAL["lilac"], 0.9)                      # trụ giữa mép
    c.rect([-P(0.05), 0, P(0.05), H], PAL["magenta"], 0.9)
    save(c.im, "city_mall_facade.png")


def make_shophouse():
    """3 nhà phố 4 m x 3 tầng (12 m x 9,6 m): mỗi căn một màu pastel, lan can/gờ trắng, 2 cửa sổ 1,2 m mỗi tầng,
    tầng trệt cửa cuốn 3 m + bảng hiệu; vách ngăn 0,2 m tại x = 0 / 4 / 8 m (0 nằm giữa mép tile)."""
    ppm = W / 12.0
    H = int(round(3 * STOREY_M * ppm))
    P = lambda m: int(round(m * ppm))
    rng = random.Random(1986)
    cols, cw = 3, 4.0
    pastels = rng.sample([PAL["pink"], PAL["mint"], PAL["peach"], PAL["lilac"], PAL["lemon"], PAL["sky"]], cols)
    accents = rng.sample([PAL["teal"], PAL["hot_pink"], PAL["magenta"], PAL["orange"]], cols)
    words = rng.sample(SIGN_WORDS, cols)
    fnt = font(P(0.42))
    c = Canvas(W, H, PAL["cream"], noise_amp=5, seed=41, height=0.7, wrap_y=False)
    for i in range(cols):
        x0 = i * cw
        c.rect([P(x0), 0, P(x0 + cw), H], pastels[i], 0.7)
        c.rect([P(x0), 0, P(x0 + cw), P(0.35)], PAL["white"], 0.8)                         # lan can mái
        c.rect([P(x0), P(0.12), P(x0 + cw), P(0.18)], accents[i], 0.8)
        for fy in (STOREY_M, 2 * STOREY_M):
            c.rect([P(x0), P(fy) - P(0.14), P(x0 + cw), P(fy)], PAL["white"], 0.8)          # gờ sàn
        for fy in (0.0, STOREY_M):
            for wx in (0.55, 2.25):
                bx = [P(x0 + wx), P(fy + 0.9), P(x0 + wx + 1.2), P(fy + 2.4)]
                c.rect([bx[0] - 3, bx[1] - 3, bx[2] + 3, bx[3] + 3], PAL["white"], 0.66)   # khung
                c.glass(bx, seed=5 + i, height=0.42)
                c.rect([P(x0 + wx + 0.6) - 1, bx[1], P(x0 + wx + 0.6) + 1, bx[3]], PAL["white"], 0.66)
                c.rect([bx[0] - 5, bx[3] + 3, bx[2] + 5, bx[3] + 7], PAL["white"], 0.72)   # bệ cửa
        c.rect([P(x0), P(9.35), P(x0 + cw), H], PAL["concrete"], 0.7)                      # chân tường
        c.rect([P(x0 + 0.3), P(6.55), P(x0 + 3.7), P(7.25)], accents[i], 0.74)             # bảng hiệu
        c.text((P(x0 + 2.0), P(6.9)), words[i], PAL["white"] + (255,), fnt)
        c.rect([P(x0 + 0.45), P(7.25), P(x0 + 3.55), P(7.42)], (120, 120, 130), 0.7)       # hộp cửa cuốn
        c.slats([P(x0 + 0.5), P(7.42), P(x0 + 3.5), H], PAL["shutter"], P(0.1), 0.62)      # cửa cuốn
    for i in range(cols):
        c.rect([P(i * cw) - P(0.1), 0, P(i * cw) + P(0.1), H], PAL["white_warm"], 0.85)   # vách ngăn
    save(c.im, "city_shophouse_facade.png")


def make_industrial():
    """Nhà xưởng 6 m x 1 tầng: tôn sóng bạc hà (40 sóng / tile), dải mái cá hồi, cửa cuốn xanh ngọc 2,8 m,
    ô cửa sổ cao 1,2 m, chân tường bê tông, ống thoát nước."""
    ppm, H = ppm_for(6.0)
    P = lambda m: int(round(m * ppm))
    x = np.arange(W, dtype=np.float32)
    rib = np.sin(2.0 * np.pi * x * 40.0 / W)
    base = np.array(PAL["mint_pale"], np.float32)[None, None, :] + (rib * 13.0)[None, :, None]
    base = base + ((noise(W, H, 3, 0.5, 61) - 0.5) * 8.0)[:, :, None]
    hbase = np.broadcast_to(0.6 + rib[None, :] * 0.1, (H, W))
    c = Canvas(W, H, base, height=hbase)
    c.rect([0, H - P(0.03), W, H], PAL["dark"], 0.55)
    c.rect([0, 0, W, P(0.03)], PAL["dark"], 0.55)
    c.rect([0, P(0.03), W, P(0.30)], PAL["salmon"], 0.7)                     # dải mái
    c.rect([0, P(0.30), W, P(0.34)], PAL["dark"], 0.6)
    c.rect([0, P(2.75), W, H - P(0.03)], PAL["concrete"], 0.66)               # chân tường
    c.rect([P(0.52), P(0.45), P(3.48), H - P(0.03)], PAL["dark"], 0.5)        # khung cửa cuốn
    c.rect([P(0.52), P(0.45), P(3.48), P(0.70)], (90, 90, 100), 0.7)          # hộp cuốn
    c.slats([P(0.6), P(0.70), P(3.4), H - P(0.03)], PAL["door_teal"], P(0.1), 0.5, line=2)
    c.rect([P(4.14), P(0.54), P(5.46), P(1.26)], PAL["frame"], 0.66)         # ô cửa sổ cao
    c.glass([P(4.2), P(0.6), P(5.4), P(1.2)], seed=4, height=0.42)
    c.rect([P(5.77), 0, P(5.83), H], (110, 110, 120), 0.85)                  # ống thoát nước
    save(c.im, "city_industrial_facade.png")


# ---------------------------------------------------------------- nước, đường, mái
def make_water():
    S = 512
    n1 = noise(S, S, 4, 0.5, 51, cell0=32)                                    # mảng sáng / tối lớn, mềm
    n2 = noise(S, S, 3, 0.5, 52, cell0=16)                                    # trường mềm -> vân caustic dài
    n3 = noise(S, S, 3, 0.5, 53, cell0=8)                                     # lấp lánh thưa
    deep, light = np.array((20, 116, 142), np.float32), np.array((98, 214, 206), np.float32)
    t = np.clip((n1 - 0.32) / 0.36, 0, 1)
    arr = deep + (light - deep) * t[..., None]
    ridge = np.clip(1.0 - np.abs(n2 - 0.5) / 0.035, 0, 1) ** 2                # vân sáng kiểu caustic
    arr += np.array((150, 70, 60), np.float32) * ridge[..., None]
    sparkle = np.clip((n3 - 0.74) / 0.08, 0, 1)                               # ánh hồng hoàng hôn
    arr += np.array((90, 10, 40), np.float32) * sparkle[..., None]
    save(Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB"), "city_canal_water.png")


def make_road_overlay():
    """RGBA 4 m dọc đường (x) x 1 lòng đường (y): vạch mép trắng liền, vạch tim vàng đứt 2 m nằm vắt qua mép tile."""
    Wo, Ho = 512, 256
    im = Image.new("RGBA", (Wo, Ho), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    white, yellow = (245, 245, 238, 235), (248, 204, 64, 235)
    d.rectangle([0, 6, Wo, 12], fill=white)
    d.rectangle([0, Ho - 13, Wo, Ho - 7], fill=white)
    yc = Ho // 2
    d.rectangle([384, yc - 3, Wo, yc + 3], fill=yellow)
    d.rectangle([0, yc - 3, 127, yc + 3], fill=yellow)
    a = np.asarray(im).astype(np.float32)
    wear = noise(Wo, Ho, 4, 0.6, 71)
    holes = noise(Wo, Ho, 5, 0.5, 72)
    a[..., 3] *= (0.72 + 0.28 * wear) * (holes < 0.93)
    save(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA"), "city_road_overlay.png")


def make_roof():
    S = 512
    n = noise(S, S, 5, 0.65, 81)
    lo = noise(S, S, 6, 1.7, 82)                                              # chỉ còn octave thô: mảng ố
    arr = np.array((208, 196, 184), np.float32)[None, None, :] + ((n - 0.5) * 30)[..., None]
    arr += ((lo - 0.5) * 24)[..., None] * np.array((1.0, 0.9, 0.8), np.float32)
    joint = np.array((160, 150, 142), np.float32)
    for k in (0, 256):
        arr[:, [(k - 1) % S, k, (k + 1) % S]] = joint                          # khe co giãn dọc (x = 0 vắt qua mép)
        arr[[(k - 1) % S, k, (k + 1) % S], :] = joint                          # khe co giãn ngang
    save(Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB"), "city_roof_flat.png")


if __name__ == "__main__":
    make_tower()
    make_beverly()
    make_mall()
    make_shophouse()
    make_industrial()
    make_water()
    make_road_overlay()
    make_roof()
    print("DONE")
