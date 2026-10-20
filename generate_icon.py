# -*- coding: utf-8 -*-
"""
Tạo icon game "CÓC VÀNG FPTU" từ ảnh con cóc do người dùng cung cấp – XỬ LÝ ẢNH BẰNG CODE (Pillow),
KHÔNG dùng AI tạo ảnh:
  1. Tách nền: flood-fill từ mọi pixel biên có màu nền sáng (bỏ qua chỗ áo/viền chạm mép) -> nền trong suốt.
  2. Đổi màu da: pixel tông xanh lá (hue 50°–175°) -> vàng tươi "Cóc Vàng" (hue 50°), giữ bóng/sáng của ảnh gốc.
  3. Đổi màu áo: pixel tông xanh dương (hue 190°–262°) -> cam FPT (#F37021).
  4. Cắt sát, đệm thành hình vuông, phóng 1024 px, vẽ LOGO FPT nhỏ (3 khối cam / xanh lá / xanh dương, chữ trắng,
     tấm nền trắng) ở góc dưới phải, xuất icon.png + icon.ico đa kích thước (16…256) cho Windows.
Chạy:  python generate_icon.py assets/icon/source_frog.png
Kết quả: assets/icon/cocvang_icon.png (1024), assets/icon/cocvang_icon_256.png, assets/icon/cocvang_icon.ico
"""
import os, sys, colorsys
from collections import deque
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "assets", "icon")
os.makedirs(OUT_DIR, exist_ok=True)

SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(OUT_DIR, "source_frog.png")
SKIN_HUE = 50.0 / 360.0           # vàng cóc vàng
GREEN_LO, GREEN_HI = 50.0 / 360.0, 175.0 / 360.0
SHIRT_HUE = 22.0 / 360.0          # cam FPT (#F37021)
BLUE_LO, BLUE_HI = 190.0 / 360.0, 262.0 / 360.0
FPT_ORANGE = (243, 112, 33)
FPT_GREEN = (13, 177, 75)
FPT_BLUE = (0, 102, 179)


def font_bold(size):
    for name in ("arialbd.ttf", "segoeuib.ttf", "tahomabd.ttf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except Exception:
            continue
    return ImageFont.load_default()


def remove_background(im, tol=42):
    """Flood-fill từ các pixel biên có màu nền sáng, ít bão hoà -> trong suốt; làm mềm mép."""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)
    q = deque()
    border = [(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)] + [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)]
    for cx, cy in border:
        base = px[cx, cy][:3]
        if min(base) < 150 or (max(base) - min(base)) > 60:
            continue
        q.append((cx, cy, base))
    while q:
        x, y, base = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h:
            continue
        i = y * w + x
        if seen[i]:
            continue
        r, g, b, a = px[x, y]
        if abs(r - base[0]) + abs(g - base[1]) + abs(b - base[2]) > tol * 3:
            continue
        seen[i] = 1
        px[x, y] = (r, g, b, 0)
        q.append((x + 1, y, base)); q.append((x - 1, y, base))
        q.append((x, y + 1, base)); q.append((x, y - 1, base))
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] == 0 and (r + g + b) > 540:
                    px[x, y] = (r, g, b, 110)
                    break
    return im


def recolor(im):
    """Da xanh lá -> vàng; áo xanh dương -> cam FPT. Giữ mắt, miệng nâu, viền đen."""
    px = im.load()
    w, h = im.size
    n_skin = n_shirt = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            hh, ss, vv = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            if GREEN_LO <= hh <= GREEN_HI and ss > 0.18 and vv > 0.12:
                ns = min(1.0, max(0.88, ss * 1.3))
                nv = min(1.0, 0.72 + vv * 0.30)
                nr, ng, nb = colorsys.hsv_to_rgb(SKIN_HUE, ns, nv)
                px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
                n_skin += 1
            elif BLUE_LO <= hh <= BLUE_HI and ss > 0.3 and vv > 0.12:
                ns = min(1.0, max(0.84, ss))
                nv = min(1.0, 0.38 + vv * 0.62)
                nr, ng, nb = colorsys.hsv_to_rgb(SHIRT_HUE, ns, nv)
                px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
                n_shirt += 1
    return im, n_skin, n_shirt


def square_pad(im, margin=0.06):
    im = im.crop(im.getbbox())
    w, h = im.size
    side = int(max(w, h) * (1.0 + margin * 2))
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(im, ((side - w) // 2, (side - h) // 2), im)
    return canvas


def draw_fpt_logo(canvas, width=232, height=84, margin=30):
    """Logo FPT cách điệu vẽ bằng code: 3 khối nghiêng cam / xanh lá / xanh dương, chữ F P T trắng,
    đặt trên tấm nền trắng bo góc để nổi trên áo cam."""
    W, H = canvas.size
    x0 = W - width - margin
    y0 = H - height - margin
    pad = 11
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle([x0 - pad, y0 - pad, x0 + width + pad, y0 + height + pad], radius=20,
                           fill=(255, 255, 255, 255), outline=(60, 60, 60, 255), width=4)
    skew = 12
    block_w = (width - 2 * 8) / 3.0
    font = font_bold(int(height * 0.78))
    letters = ["F", "P", "T"]
    colors = [FPT_ORANGE, FPT_GREEN, FPT_BLUE]
    for i in range(3):
        bx = x0 + i * (block_w + 8)
        poly = [(bx + skew, y0), (bx + block_w + skew, y0), (bx + block_w, y0 + height), (bx, y0 + height)]
        draw.polygon(poly, fill=colors[i] + (255,))
        cx = bx + block_w / 2 + skew / 2
        cy = y0 + height / 2
        bbox = draw.textbbox((0, 0), letters[i], font=font)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        draw.text((cx - tw / 2 - bbox[0], cy - th / 2 - bbox[1]), letters[i], font=font, fill=(255, 255, 255, 255))
    return canvas


def main():
    if not os.path.exists(SRC):
        print("Khong tim thay anh nguon:", SRC)
        sys.exit(1)
    im = remove_background(Image.open(SRC))
    im, n_skin, n_shirt = recolor(im)
    print("pixel da -> vang:", n_skin, "| pixel ao -> cam:", n_shirt)
    big = square_pad(im).resize((1024, 1024), Image.LANCZOS)
    big = draw_fpt_logo(big)
    png_path = os.path.join(OUT_DIR, "cocvang_icon.png")
    big.save(png_path)
    big.save(os.path.join(OUT_DIR, "cocvang_icon.ico"),
             sizes=[(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (24, 24), (16, 16)])
    big.resize((256, 256), Image.LANCZOS).save(os.path.join(OUT_DIR, "cocvang_icon_256.png"))
    print("Created", png_path, big.size, "+ cocvang_icon.ico + cocvang_icon_256.png")


if __name__ == "__main__":
    main()
