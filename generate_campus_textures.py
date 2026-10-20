# -*- coding: utf-8 -*-
"""
Texture 2D VẼ BẰNG CODE (Pillow) cho khuôn viên FPT TP.HCM dựng lại theo mặt bằng thật.
KHÔNG dùng AI gen ảnh. Các texture ảnh thật (fptu_*.png, lotus_pond_real.png, fptu_alpha_facade.png)
vẫn được giữ nguyên và dùng song song với các texture này.

Tạo ra:
  roof_terracotta.png        - mái ngói đỏ cam giật cấp (thấy rõ trong ảnh chụp thật của trường)
  grass_lawn.png             - thảm cỏ sân trước
  fptu_courtyard_paving.png  - sân trong lát gạch xám với các mảng đỏ cam / cát vàng uốn lượn
  fpt_university_board.png   - bảng tên cổng "TRƯỜNG ĐẠI HỌC FPT - TP. HỒ CHÍ MINH" nền cam chữ trắng
  vietnam_flag.png           - cờ đỏ sao vàng cho cột cờ sân trường
  parking_canopy_roof.png    - mái tôn sóng bãi xe máy
Chạy:  python generate_campus_textures.py
"""
import os, math, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets", "textures")
os.makedirs(OUT_DIR, exist_ok=True)
random.seed(2026)


def font_bold(size):
    for name in ("arialbd.ttf", "segoeuib.ttf", "tahomabd.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except Exception:
            continue
    return ImageFont.load_default()


def save(im, name):
    path = os.path.join(OUT_DIR, name)
    im.save(path)
    print("Created", name, im.size)


def make_roof_terracotta():
    w = h = 512
    im = Image.new("RGB", (w, h), (178, 84, 58))
    d = ImageDraw.Draw(im)
    row_h = 32
    for y in range(0, h, row_h):
        shade = random.randint(-14, 14)
        for x in range(-16, w, 48):
            off = 24 if (y // row_h) % 2 else 0
            c = (178 + shade + random.randint(-8, 8), 84 + shade // 2 + random.randint(-6, 6), 58 + random.randint(-6, 6))
            d.rectangle([x + off, y, x + off + 46, y + row_h - 2], fill=c)
            d.line([x + off, y + row_h - 2, x + off + 46, y + row_h - 2], fill=(120, 50, 35), width=2)
            d.line([x + off, y, x + off, y + row_h - 2], fill=(140, 60, 42), width=1)
    im = im.filter(ImageFilter.GaussianBlur(0.4))
    save(im, "roof_terracotta.png")


def make_grass_lawn():
    """Bãi cỏ nhiệt đới tự nhiên: nền xanh ô-liu tối, lẫn vệt cỏ vàng khô & mảng đậm nhạt lớn (ít bão hoà
    hơn bản cũ để ánh sáng gián tiếp SDFGI không ám xanh neon lên trần hiên / mặt dưới mái che)."""
    w = h = 512
    im = Image.new("RGB", (w, h), (74, 104, 50))
    px = im.load()
    # Mảng đậm nhạt tần số thấp
    blobs = [(random.randint(0, w), random.randint(0, h), random.randint(60, 160), random.randint(-14, 14)) for _ in range(28)]
    for y in range(h):
        for x in range(w):
            n = random.randint(-10, 10)
            v = 0
            for bx, by, br, bv in blobs:
                dx = min(abs(x - bx), w - abs(x - bx)); dy = min(abs(y - by), h - abs(y - by))
                if dx * dx + dy * dy < br * br:
                    v += bv
            v = max(-18, min(18, v))
            r = 74 + n + v + (6 if v > 8 else 0)
            g = 104 + n + v
            b = 50 + n // 2 + v // 2
            px[x, y] = (max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)))
    d = ImageDraw.Draw(im)
    for _ in range(1400):
        x = random.randint(0, w - 1); y = random.randint(0, h - 1)
        if random.random() < 0.3:
            col = (128 + random.randint(0, 30), 128 + random.randint(0, 20), 60 + random.randint(0, 20))  # cỏ khô vàng
        else:
            col = (58 + random.randint(0, 30), 112 + random.randint(0, 30), 42 + random.randint(0, 10))
        d.line([x, y, x + random.randint(-2, 2), y - random.randint(2, 6)], fill=col, width=1)
    im = im.filter(ImageFilter.GaussianBlur(0.5))
    save(im, "grass_lawn.png")


def make_courtyard_paving():
    w = h = 1024
    im = Image.new("RGB", (w, h), (168, 170, 172))
    d = ImageDraw.Draw(im)
    # Gạch xám lát ô vuông nhỏ
    for y in range(0, h, 32):
        for x in range(0, w, 32):
            c = 160 + random.randint(-10, 10)
            d.rectangle([x, y, x + 31, y + 31], fill=(c, c + 2, c + 4), outline=(135, 137, 140))
    # Các dải đỏ cam uốn lượn (như sân trong thật) và mảng cát vàng
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    for i in range(5):
        cx = random.randint(100, w - 100); cy = random.randint(100, h - 100)
        pts = []
        for k in range(14):
            ang = k / 14.0 * 2 * math.pi
            r = random.randint(120, 260)
            pts.append((cx + math.cos(ang) * r * random.uniform(0.6, 1.0), cy + math.sin(ang) * r * random.uniform(0.5, 1.0)))
        ld.polygon(pts, fill=(196, 78, 52, 235))
    for i in range(2):
        cx = random.randint(150, w - 150); cy = random.randint(150, h - 150)
        pts = []
        for k in range(12):
            ang = k / 12.0 * 2 * math.pi
            r = random.randint(90, 170)
            pts.append((cx + math.cos(ang) * r, cy + math.sin(ang) * r * 0.7))
        ld.polygon(pts, fill=(226, 202, 140, 235))
    layer = layer.filter(ImageFilter.GaussianBlur(6))
    im = Image.alpha_composite(im.convert("RGBA"), layer).convert("RGB")
    # Vân gạch mờ trên vùng đỏ
    d = ImageDraw.Draw(im)
    for y in range(0, h, 32):
        d.line([0, y, w, y], fill=(0, 0, 0), width=1)
    for x in range(0, w, 32):
        d.line([x, 0, x, h], fill=(0, 0, 0), width=1)
    im = Image.blend(im, im.filter(ImageFilter.GaussianBlur(1.2)), 0.5)
    save(im, "fptu_courtyard_paving.png")


def make_fpt_board():
    w, h = 1024, 256
    im = Image.new("RGB", (w, h), (243, 112, 33))
    d = ImageDraw.Draw(im)
    d.rectangle([6, 6, w - 7, h - 7], outline=(255, 255, 255), width=4)
    f1 = font_bold(74)
    f2 = font_bold(44)
    t1 = "TRƯỜNG ĐẠI HỌC FPT"
    t2 = "TP. HỒ CHÍ MINH  ·  FPT UNIVERSITY"
    b1 = d.textbbox((0, 0), t1, font=f1)
    b2 = d.textbbox((0, 0), t2, font=f2)
    d.text(((w - (b1[2] - b1[0])) / 2, 38), t1, font=f1, fill=(255, 255, 255))
    d.text(((w - (b2[2] - b2[0])) / 2, 150), t2, font=f2, fill=(255, 255, 255))
    save(im, "fpt_university_board.png")


def make_vietnam_flag():
    w, h = 300, 200
    im = Image.new("RGB", (w, h), (218, 37, 29))
    d = ImageDraw.Draw(im)
    cx, cy, R = w / 2, h / 2, 60
    r = R * 0.382
    pts = []
    for i in range(10):
        ang = -math.pi / 2 + i * math.pi / 5
        rad = R if i % 2 == 0 else r
        pts.append((cx + math.cos(ang) * rad, cy + math.sin(ang) * rad))
    d.polygon(pts, fill=(255, 255, 0))
    save(im, "vietnam_flag.png")


def make_parking_canopy():
    w = h = 256
    im = Image.new("RGB", (w, h), (150, 158, 165))
    d = ImageDraw.Draw(im)
    for x in range(0, w, 16):
        d.rectangle([x, 0, x + 7, h], fill=(170, 178, 185))
        d.line([x + 8, 0, x + 8, h], fill=(110, 118, 125), width=2)
    save(im, "parking_canopy_roof.png")


if __name__ == "__main__":
    make_roof_terracotta()
    make_grass_lawn()
    make_courtyard_paving()
    make_fpt_board()
    make_vietnam_flag()
    make_parking_canopy()


# ---------------------------------------------------------------------------
# NORMAL MAP vẽ từ chính texture (luminance -> height -> Sobel) & cỏ billboard
# ---------------------------------------------------------------------------
def make_normal_map(src_name, dst_name, strength=2.0, blur=1.0, invert=False):
    path = os.path.join(OUT_DIR, src_name)
    if not os.path.exists(path):
        print("skip normal (missing)", src_name)
        return
    im = Image.open(path).convert("L")
    if blur > 0:
        im = im.filter(ImageFilter.GaussianBlur(blur))
    w, h = im.size
    px = im.load()
    out = Image.new("RGB", (w, h))
    op = out.load()
    s = strength / 255.0
    for y in range(h):
        ym, yp = (y - 1) % h, (y + 1) % h
        for x in range(w):
            xm, xp = (x - 1) % w, (x + 1) % w
            # Sobel
            dx = (px[xp, ym] + 2 * px[xp, y] + px[xp, yp]) - (px[xm, ym] + 2 * px[xm, y] + px[xm, yp])
            dy = (px[xm, yp] + 2 * px[x, yp] + px[xp, yp]) - (px[xm, ym] + 2 * px[x, ym] + px[xp, ym])
            if invert:
                dx, dy = -dx, -dy
            nx, ny, nz = -dx * s, -dy * s, 1.0
            l = math.sqrt(nx * nx + ny * ny + nz * nz)
            nx, ny, nz = nx / l, ny / l, nz / l
            # Godot dùng OpenGL normal map (Y+ lên)
            op[x, y] = (int((nx * 0.5 + 0.5) * 255), int((-ny * 0.5 + 0.5) * 255), int((nz * 0.5 + 0.5) * 255))
    save(out, dst_name)


def make_grass_blades():
    w, h = 256, 256
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for i in range(28):
        x0 = random.randint(10, w - 10)
        top = random.randint(20, 110)
        lean = random.randint(-40, 40)
        g = random.randint(110, 170)
        col = (random.randint(40, 70), g, random.randint(30, 60), 255)
        d.polygon([(x0 - 7, h), (x0 + 7, h), (x0 + lean, top)], fill=col)
        d.polygon([(x0 - 3, h), (x0 + 3, h), (x0 + lean // 2, top + 30)], fill=(col[0] + 20, min(255, col[1] + 30), col[2] + 10, 255))
    save(im, "grass_blades.png")


def make_lab_floor_tiles():
    """Gạch lát sàn phòng học / căn tin 60x60 (2x2 viên / texture = chu kỳ 1.2 m), granite sáng có vân & ron xám."""
    w = h = 512
    im = Image.new("RGB", (w, h), (214, 210, 202))
    px = im.load()
    for y in range(h):
        for x in range(w):
            n = random.randint(-9, 9)
            fleck = 0
            if random.random() < 0.06:
                fleck = random.randint(-30, 10)
            px[x, y] = (214 + n + fleck, 210 + n + fleck, 202 + n + fleck)
    d = ImageDraw.Draw(im)
    for k in (0, 256):
        d.line([(k, 0), (k, h)], fill=(150, 148, 144), width=4)
        d.line([(0, k), (w, k)], fill=(150, 148, 144), width=4)
        d.line([(k + 2, 0), (k + 2, h)], fill=(232, 230, 226), width=1)
        d.line([(0, k + 2), (w, k + 2)], fill=(232, 230, 226), width=1)
    im = im.filter(ImageFilter.GaussianBlur(0.4))
    save(im, "lab_floor_tiles.png")


def make_asphalt_detail():
    """Nhựa đường độ phân giải cao hơn với vệt bánh xe & vá đường, dùng làm nguồn normal map."""
    w = h = 1024
    im = Image.new("RGB", (w, h), (46, 49, 54))
    px = im.load()
    for y in range(h):
        for x in range(w):
            n = random.randint(-14, 14)
            px[x, y] = (46 + n, 49 + n, 54 + n)
    d = ImageDraw.Draw(im)
    for _ in range(2500):
        x = random.randint(0, w - 4); y = random.randint(0, h - 4); s = random.randint(1, 4)
        c = random.randint(60, 105)
        d.ellipse([x, y, x + s, y + s], fill=(c, c, c + 3))
    for _ in range(6):
        x = random.randint(0, w); y = random.randint(0, h)
        d.line([x, y, x + random.randint(-300, 300), y + random.randint(-300, 300)], fill=(38, 40, 44), width=random.randint(2, 5))
    im = im.filter(ImageFilter.GaussianBlur(0.5))
    save(im, "asphalt_road_hd.png")


if __name__ == "__main__":
    make_asphalt_detail()
    make_grass_blades()
    make_normal_map("asphalt_road_hd.png", "asphalt_road_n.png", strength=2.5, blur=0.8)
    make_normal_map("sidewalk_tiles.png", "sidewalk_tiles_n.png", strength=4.0, blur=0.6)
    make_normal_map("roof_terracotta.png", "roof_terracotta_n.png", strength=3.0, blur=0.6)
    make_normal_map("grass_lawn.png", "grass_lawn_n.png", strength=1.5, blur=1.0)
    make_normal_map("fptu_alpha_facade.png", "fptu_alpha_facade_n.png", strength=3.5, blur=1.2)
    make_normal_map("fptu_courtyard_paving.png", "fptu_courtyard_paving_n.png", strength=2.0, blur=0.8)
