import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import random

OUT_DIR = r"C:\Users\nguye\.gemini\antigravity-ide\scratch\fptu-godot4-simulator\assets\textures"
os.makedirs(OUT_DIR, exist_ok=True)

def get_font(size):
    try:
        # Standard Windows fonts that support Vietnamese accents
        return ImageFont.truetype("arialbd.ttf", size)
    except:
        try:
            return ImageFont.truetype("segoeui.ttf", size)
        except:
            return ImageFont.load_default()

def get_font_regular(size):
    try:
        return ImageFont.truetype("arial.ttf", size)
    except:
        return ImageFont.load_default()

# 1. Realistic Asphalt Texture (1024x1024)
def make_asphalt():
    im = Image.new("RGB", (1024, 1024), (45, 48, 52))
    draw = ImageDraw.Draw(im)
    random.seed(42)
    # Add noise & aggregate stones
    for _ in range(50000):
        x = random.randint(0, 1023)
        y = random.randint(0, 1023)
        c = random.randint(30, 75)
        im.putpixel((x, y), (c, c, c + 2))
    for _ in range(1500):
        x = random.randint(0, 1020)
        y = random.randint(0, 1020)
        s = random.randint(2, 4)
        c = random.randint(60, 100)
        draw.ellipse([x, y, x + s, y + s], fill=(c, c, c))
    im = im.filter(ImageFilter.GaussianBlur(0.6))
    im.save(os.path.join(OUT_DIR, "asphalt_road.png"))
    print("Created asphalt_road.png")

# 2. Sidewalk Interlocking Pavers (512x512)
def make_sidewalk():
    im = Image.new("RGB", (512, 512), (195, 175, 140)) # Warm yellow-beige paving stones
    draw = ImageDraw.Draw(im)
    tile_w, tile_h = 64, 32
    for y in range(0, 512, tile_h):
        offset = (tile_w // 2) if (y // tile_h) % 2 == 1 else 0
        for x in range(-offset, 512, tile_w):
            c_noise = random.randint(-12, 12)
            base_col = (195 + c_noise, 175 + c_noise, 140 + c_noise)
            draw.rectangle([x + 2, y + 2, x + tile_w - 2, y + tile_h - 2], fill=base_col)
            draw.rectangle([x, y, x + tile_w, y + tile_h], outline=(140, 125, 100), width=2)
    im.save(os.path.join(OUT_DIR, "sidewalk_tiles.png"))
    print("Created sidewalk_tiles.png")

# 3. Curb Stone (Red/White traffic pattern)
def make_curb():
    im = Image.new("RGB", (512, 128), (220, 220, 220))
    draw = ImageDraw.Draw(im)
    seg_w = 64
    for i, x in enumerate(range(0, 512, seg_w)):
        color = (205, 30, 30) if i % 2 == 0 else (240, 240, 240)
        draw.rectangle([x, 0, x + seg_w, 128], fill=color)
        draw.line([x, 0, x, 128], fill=(80, 80, 80), width=2)
    im.save(os.path.join(OUT_DIR, "curb_stone.png"))
    print("Created curb_stone.png")

# 4. Milano Coffee Facade
def make_milano():
    im = Image.new("RGB", (512, 256), (30, 30, 30))
    draw = ImageDraw.Draw(im)
    # Signboard
    draw.rectangle([0, 0, 512, 110], fill=(20, 20, 20), outline=(60, 60, 60), width=4)
    font_bold = get_font(42)
    font_sub = get_font(18)
    font_small = get_font_regular(14)
    draw.text((256, 40), "MILANO COFFEE", fill=(255, 255, 255), font=font_bold, anchor="mm")
    draw.text((256, 78), "CÀ PHÊ NGUYÊN CHẤT - PHA PHIN ĐẬM ĐÀ", fill=(220, 180, 100), font=font_sub, anchor="mm")
    draw.text((256, 98), "ĐC: ĐƯỜNG NGUYỄN XIỂN, P. LONG THẠNH MỸ", fill=(180, 180, 180), font=font_small, anchor="mm")
    # Lower shop: Green folding iron gate
    draw.rectangle([0, 110, 512, 256], fill=(35, 75, 55))
    for x in range(0, 512, 24):
        draw.line([x, 110, x, 256], fill=(20, 45, 32), width=3)
    im.save(os.path.join(OUT_DIR, "shop_milano.png"))
    print("Created shop_milano.png")

# 5. Sửa Xe Máy Í Chương Facade
def make_suaxe():
    im = Image.new("RGB", (512, 256), (40, 40, 45))
    draw = ImageDraw.Draw(im)
    # Yellow sign with red bold letters (classic VN motorbike repair shop)
    draw.rectangle([0, 0, 512, 110], fill=(245, 195, 35), outline=(180, 130, 10), width=4)
    font_bold = get_font(36)
    font_sub = get_font(20)
    font_small = get_font_regular(15)
    draw.text((256, 36), "SỬA XE Í CHƯƠNG", fill=(210, 20, 20), font=font_bold, anchor="mm")
    draw.text((256, 70), "CHUYÊN VÁ VỎ XE GA - THAY NHỚT CASTROL / MOTUL", fill=(10, 20, 110), font=font_sub, anchor="mm")
    draw.text((256, 95), "CỨU HỘ XE MÁY ĐƯỜNG NGUYỄN XIỂN - ĐT: 0908.xxx.xxx", fill=(30, 30, 30), font=font_small, anchor="mm")
    # Lower shop: corrugated roller shutter
    draw.rectangle([0, 110, 512, 256], fill=(130, 135, 140))
    for y in range(110, 256, 12):
        draw.line([0, y, 512, y], fill=(85, 90, 95), width=2)
    im.save(os.path.join(OUT_DIR, "shop_suaxe.png"))
    print("Created shop_suaxe.png")

# 6. Bún Bò Huế Facade
def make_bunbo():
    im = Image.new("RGB", (512, 256), (50, 45, 40))
    draw = ImageDraw.Draw(im)
    # Red sign with yellow text
    draw.rectangle([0, 0, 512, 110], fill=(195, 25, 25), outline=(130, 10, 10), width=4)
    font_bold = get_font(38)
    font_sub = get_font(20)
    font_small = get_font_regular(15)
    draw.text((256, 36), "BÚN BÒ HUẾ CÔ NHƯ", fill=(255, 235, 40), font=font_bold, anchor="mm")
    draw.text((256, 70), "BÁNH CANH CUA - PHỞ BÒ - BÁNH MÌ SÁNG", fill=(255, 255, 255), font=font_sub, anchor="mm")
    draw.text((256, 95), "ĐẶC BIỆT CÓ BÁN NƯỚC MÍA SIÊU SẠCH 10K", fill=(255, 220, 150), font=font_small, anchor="mm")
    # Lower shop: metal folding door + tiled bottom
    draw.rectangle([0, 110, 512, 256], fill=(65, 95, 120))
    for x in range(0, 512, 20):
        draw.line([x, 110, x, 256], fill=(40, 60, 80), width=2)
    im.save(os.path.join(OUT_DIR, "shop_bunbo.png"))
    print("Created shop_bunbo.png")

# 7. Tạp Hóa Bà Bảy Facade
def make_taphoa():
    im = Image.new("RGB", (512, 256), (40, 40, 40))
    draw = ImageDraw.Draw(im)
    # Blue sign
    draw.rectangle([0, 0, 512, 110], fill=(25, 90, 180), outline=(15, 50, 110), width=4)
    font_bold = get_font(36)
    font_sub = get_font(19)
    font_small = get_font_regular(15)
    draw.text((256, 36), "TẠP HÓA CÔ BẢY", fill=(255, 255, 255), font=font_bold, anchor="mm")
    draw.text((256, 70), "BIA NƯỚC NGỌT - THUỐC LÁ - THẺ CÀO ĐIỆN THOẠI", fill=(255, 230, 50), font=font_sub, anchor="mm")
    draw.text((256, 95), "BĂNG VỆ SINH - GẠO - TRỨNG - NƯỚC MẮM", fill=(220, 240, 255), font=font_small, anchor="mm")
    # Lower shop
    draw.rectangle([0, 110, 512, 256], fill=(120, 125, 130))
    for y in range(110, 256, 14):
        draw.line([0, y, 512, y], fill=(75, 80, 85), width=2)
    im.save(os.path.join(OUT_DIR, "shop_taphoa.png"))
    print("Created shop_taphoa.png")

# 8. Bách Hóa Xanh Facade
def make_bachhoaxanh():
    im = Image.new("RGB", (512, 256), (30, 30, 30))
    draw = ImageDraw.Draw(im)
    draw.rectangle([0, 0, 512, 110], fill=(0, 135, 68), outline=(0, 95, 45), width=4)
    font_bold = get_font(40)
    font_sub = get_font(20)
    draw.text((256, 40), "BÁCH HÓA XANH", fill=(255, 235, 30), font=font_bold, anchor="mm")
    draw.text((256, 80), "THỊT CÁ TƯƠI SỐNG - RAU CỦ QUẢ MỖI NGÀY", fill=(255, 255, 255), font=font_sub, anchor="mm")
    draw.rectangle([0, 110, 512, 256], fill=(220, 225, 230))
    # Glass store entrance
    draw.rectangle([60, 125, 452, 256], fill=(140, 190, 220), outline=(60, 60, 60), width=4)
    im.save(os.path.join(OUT_DIR, "shop_bachhoaxanh.png"))
    print("Created shop_bachhoaxanh.png")

# 9. Retractable Awning (Mái hiên di động kẻ sọc)
def make_awnings():
    # Red-white striped
    im_red = Image.new("RGB", (256, 128), (255, 255, 255))
    draw_red = ImageDraw.Draw(im_red)
    stripe_w = 32
    for x in range(0, 256, stripe_w * 2):
        draw_red.rectangle([x, 0, x + stripe_w, 128], fill=(205, 30, 30))
    im_red.save(os.path.join(OUT_DIR, "awning_red.png"))

    # Blue-white striped
    im_blue = Image.new("RGB", (256, 128), (255, 255, 255))
    draw_blue = ImageDraw.Draw(im_blue)
    for x in range(0, 256, stripe_w * 2):
        draw_blue.rectangle([x, 0, x + stripe_w, 128], fill=(25, 95, 205))
    im_blue.save(os.path.join(OUT_DIR, "awning_blue.png"))
    print("Created awning textures")

# 10. Roundabout Traffic Sign (Biển báo Vòng xoay D1/D2)
def make_roundabout_sign():
    im = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    # Circle sign (R403)
    draw.ellipse([30, 30, 482, 482], fill=(20, 85, 215), outline=(255, 255, 255), width=14)
    font_title = get_font(42)
    font_bold = get_font(34)
    font_sub = get_font(26)
    
    # White 3 arrows circle representation
    draw.arc([130, 130, 382, 382], start=0, end=360, fill=(255, 255, 255), width=24)
    # Text directional info
    draw.rectangle([40, 200, 472, 320], fill=(15, 60, 160, 240), outline=(255, 255, 255), width=4)
    draw.text((256, 235), "VÒNG XOAY D1 - D2", fill=(255, 235, 30), font=font_title, anchor="mm")
    draw.text((256, 285), "RẼ PHẢI ➔ ĐƯỜNG D1 (ĐH FPT)", fill=(255, 255, 255), font=font_bold, anchor="mm")
    im.save(os.path.join(OUT_DIR, "roundabout_sign.png"))
    print("Created roundabout_sign.png")

# 11. FPT University Main Gate Signboard
def make_fptu_sign():
    im = Image.new("RGB", (1024, 256), (255, 255, 255))
    draw = ImageDraw.Draw(im)
    # Orange border and background
    draw.rectangle([0, 0, 1024, 256], fill=(243, 112, 33)) # FPT Orange #F37021
    draw.rectangle([12, 12, 1012, 244], outline=(255, 255, 255), width=6)
    font_fpt = get_font(60)
    font_sub = get_font(32)
    font_small = get_font_regular(22)
    draw.text((512, 70), "TRƯỜNG ĐẠI HỌC FPT", fill=(255, 255, 255), font=font_fpt, anchor="mm")
    draw.text((512, 140), "PHÂN HIỆU TP. HỒ CHÍ MINH", fill=(255, 240, 210), font=font_sub, anchor="mm")
    draw.text((512, 195), "LÔ E2A-7, ĐƯỜNG D1, KHU CÔNG NGHỆ CAO, TP. THỦ ĐỨC", fill=(255, 255, 255), font=font_small, anchor="mm")
    im.save(os.path.join(OUT_DIR, "fptu_gate_sign.png"))
    print("Created fptu_gate_sign.png")

# 12. 7-Eleven Facade
def make_7eleven():
    im = Image.new("RGB", (512, 256), (255, 255, 255))
    draw = ImageDraw.Draw(im)
    # Top 3 colored stripes (Green, Orange, Red)
    draw.rectangle([0, 0, 512, 30], fill=(0, 128, 77)) # Green
    draw.rectangle([0, 30, 512, 60], fill=(238, 114, 3)) # Orange
    draw.rectangle([0, 60, 512, 90], fill=(237, 27, 36)) # Red
    # Signboard
    draw.rectangle([0, 90, 512, 180], fill=(255, 255, 255), outline=(220, 220, 220), width=3)
    font_big = get_font(64)
    font_sub = get_font(22)
    draw.text((256, 135), "7-ELEVEN", fill=(0, 128, 77), font=font_big, anchor="mm")
    draw.text((256, 215), "CỬA HÀNG TIỆN LỢI FPTU CAMPUS", fill=(238, 114, 3), font=font_sub, anchor="mm")
    im.save(os.path.join(OUT_DIR, "seven_eleven_sign.png"))
    print("Created seven_eleven_sign.png")

# 13. Bridge Barrier (Lan can Cầu Trau Trảu)
def make_bridge_barrier():
    im = Image.new("RGB", (512, 128), (170, 175, 180)) # Galvanized steel
    draw = ImageDraw.Draw(im)
    # Horizontal beams
    draw.rectangle([0, 15, 512, 45], fill=(210, 215, 220), outline=(100, 105, 110), width=2)
    draw.rectangle([0, 75, 512, 105], fill=(210, 215, 220), outline=(100, 105, 110), width=2)
    # Vertical posts
    for x in range(0, 512, 64):
        draw.rectangle([x - 6, 0, x + 6, 128], fill=(90, 95, 100))
    # Hazard stripes on edge posts
    for x in [0, 256, 480]:
        for i in range(0, 32, 8):
            draw.line([x + i, 15, x + i + 8, 45], fill=(245, 195, 35), width=3)
    im.save(os.path.join(OUT_DIR, "bridge_barrier.png"))
    print("Created bridge_barrier.png")

# 14. Vành Đai 3 Construction Pillar texture
def make_ringroad3_pillar():
    im = Image.new("RGB", (256, 512), (160, 165, 170))
    draw = ImageDraw.Draw(im)
    # Concrete formwork seams
    for y in range(0, 512, 64):
        draw.line([0, y, 256, y], fill=(110, 115, 120), width=2)
    # Caution text
    font_cau = get_font(20)
    font_sub = get_font(14)
    draw.rectangle([10, 210, 246, 300], fill=(245, 200, 30), outline=(0, 0, 0), width=3)
    draw.text((128, 235), "CÔNG TRÌNH VÀNH ĐAI 3", fill=(0, 0, 0), font=font_cau, anchor="mm")
    draw.text((128, 265), "CHÚ Ý CẨU THÁP HOẠT ĐỘNG", fill=(200, 20, 20), font=font_sub, anchor="mm")
    im.save(os.path.join(OUT_DIR, "ringroad3_pillar.png"))
    print("Created ringroad3_pillar.png")

# 15. Power Lines & Electric Pole
def make_wire_pole():
    im = Image.new("RGB", (128, 512), (180, 185, 190))
    draw = ImageDraw.Draw(im)
    # Pole seams
    for y in range(0, 512, 48):
        draw.line([0, y, 128, y], fill=(130, 135, 140), width=2)
    # Yellow danger plate with lightning
    draw.rectangle([18, 180, 110, 270], fill=(245, 215, 30), outline=(20, 20, 20), width=3)
    font_d = get_font(18)
    draw.text((64, 210), "CẤM LẠI GẦN", fill=(210, 20, 20), font=font_d, anchor="mm")
    draw.text((64, 240), "ĐIỆN CAO THẾ", fill=(0, 0, 0), font=font_d, anchor="mm")
    im.save(os.path.join(OUT_DIR, "wire_pole.png"))
    print("Created wire_pole.png")

# 16. HUTECH University High Tech Park Signboard
def make_hutech_sign():
    im = Image.new("RGB", (1024, 256), (0, 85, 165)) # HUTECH Royal Blue #0055A5
    draw = ImageDraw.Draw(im)
    draw.rectangle([12, 12, 1012, 244], outline=(255, 209, 0), width=6) # Golden Yellow #FFD100
    font_h = get_font(48)
    font_s = get_font(32)
    font_sm = get_font_regular(20)
    draw.text((512, 65), "TRƯỜNG ĐẠI HỌC CÔNG NGHỆ TP.HCM (HUTECH)", fill=(255, 209, 0), font=font_h, anchor="mm")
    draw.text((512, 135), "VIỆN CÔNG NGHỆ CAO HUTECH", fill=(255, 255, 255), font=font_s, anchor="mm")
    draw.text((512, 195), "LÔ E2B-4, ĐƯỜNG D1, KHU CÔNG NGHỆ CAO, TP. THỦ ĐỨC", fill=(255, 240, 200), font=font_sm, anchor="mm")
    im.save(os.path.join(OUT_DIR, "hutech_sign.png"))
    print("Created hutech_sign.png")

# 17. Vinhomes Grand Park Modern Apartment Facade (1024x1024)
def make_vinhomes_facade():
    im = Image.new("RGB", (1024, 1024), (242, 245, 248)) # Modern white-cream exterior
    draw = ImageDraw.Draw(im)

    # 1. Ground floor podium (Shophouse chân đế & sảnh lễ tân)
    draw.rectangle([0, 860, 1024, 1024], fill=(45, 52, 60))
    # Glass storefronts
    store_w = 230
    for i in range(4):
        x = 20 + i * 250
        draw.rectangle([x, 880, x + store_w, 1010], fill=(120, 175, 205), outline=(20, 25, 30), width=4)
        # Store signs
        sign_colors = [(180, 20, 20), (0, 120, 60), (220, 110, 20), (20, 60, 160)]
        sign_names = ["HIGHLANDS", "WINMART+", "GS25", "PHỞ 24"]
        draw.rectangle([x + 10, 890, x + store_w - 10, 925], fill=sign_colors[i])
        font_s = get_font(18)
        draw.text((x + store_w // 2, 907), sign_names[i], fill=(255, 255, 255), font=font_s, anchor="mm")

    # 2. Upper residential floors (8 floors represented with balconies & windows)
    floor_h = 95
    for f in range(8):
        y_top = 80 + f * floor_h
        y_bot = y_top + floor_h - 10
        # Horizontal concrete floor slab
        draw.rectangle([0, y_bot, 1024, y_bot + 10], fill=(215, 220, 225))

        # Windows and balconies across 6 apartment bays per floor
        bay_w = 150
        for b in range(6):
            bx = 30 + b * 165
            # Window glass (alternating day-sky blue and warm morning interior)
            is_warm = (f + b) % 3 == 0
            glass_col = (255, 235, 170) if is_warm else (90, 150, 195)
            draw.rectangle([bx, y_top + 10, bx + bay_w, y_bot - 4], fill=glass_col, outline=(30, 35, 40), width=2)

            # Modern glass balcony railing
            draw.rectangle([bx - 4, y_bot - 38, bx + bay_w + 4, y_bot], fill=(70, 130, 160), outline=(230, 235, 240), width=3)
            # Balcony handrail
            draw.line([bx - 6, y_bot - 38, bx + bay_w + 6, y_bot - 38], fill=(255, 255, 255), width=3)

    # 3. Top floor architectural crown (Pergola louvers)
    draw.rectangle([0, 0, 1024, 80], fill=(55, 62, 70))
    for x in range(20, 1000, 40):
        draw.rectangle([x, 15, x + 24, 75], fill=(210, 215, 220))

    im.save(os.path.join(OUT_DIR, "vinhomes_facade.png"))
    print("Created vinhomes_facade.png")

# 18. Vinhomes Grand Park Grand Entrance Archway
def make_vinhomes_gate():
    im = Image.new("RGB", (1024, 256), (30, 36, 44))
    draw = ImageDraw.Draw(im)
    draw.rectangle([12, 12, 1012, 244], outline=(220, 185, 110), width=6) # Golden trim
    font_bold = get_font(52)
    font_sub = get_font(26)
    font_sm = get_font_regular(20)
    draw.text((512, 70), "VINHOMES GRAND PARK", fill=(245, 210, 120), font=font_bold, anchor="mm")
    draw.text((512, 140), "ĐẠI ĐÔ THỊ ĐẲNG CẤP QUỐC TẾ - TP. THỦ ĐỨC", fill=(255, 255, 255), font=font_sub, anchor="mm")
    draw.text((512, 195), "CỬA NGÕ NGUYỄN XIỂN - CHÚC QUÝ KHÁCH THƯỢNG LỘ BÌNH AN", fill=(210, 215, 220), font=font_sm, anchor="mm")
    im.save(os.path.join(OUT_DIR, "vinhomes_gate.png"))
    print("Created vinhomes_gate.png")

# 19. FPT University Iconic Alpha Building Undulating Facade (1024x1024)
def make_fptu_alpha_facade():
    im = Image.new("RGB", (1024, 1024), (250, 250, 252)) # Pure architectural white
    draw = ImageDraw.Draw(im)

    # Characteristic checkerboard pattern of FPTU Alpha building with green planters
    cell_w, cell_h = 128, 128
    for r in range(8):
        for c in range(8):
            x = c * cell_w
            y = r * cell_h
            if (r + c) % 2 == 0:
                # White projecting concrete block
                draw.rectangle([x, y, x + cell_w, y + cell_h], fill=(245, 248, 252), outline=(210, 215, 220), width=2)
                # Recessed window
                draw.rectangle([x + 24, y + 24, x + cell_w - 24, y + cell_h - 24], fill=(75, 135, 185), outline=(30, 35, 40), width=2)
            else:
                # Recessed green balcony box
                draw.rectangle([x, y, x + cell_w, y + cell_h], fill=(30, 35, 42))
                # Window
                draw.rectangle([x + 10, y + 10, x + cell_w - 10, y + cell_h - 10], fill=(55, 105, 150))
                # Lush green vegetation spilling over balcony
                draw.rectangle([x + 12, y + cell_h - 45, x + cell_w - 12, y + cell_h - 4], fill=(40, 145, 65))
                for _ in range(12):
                    lx = random.randint(x + 14, x + cell_w - 20)
                    ly = random.randint(y + cell_h - 45, y + cell_h - 2)
                    draw.ellipse([lx, ly, lx + 10, ly + 8], fill=(65, 185, 90))

    # Prominent FPT Orange brand band across middle
    draw.rectangle([0, 500, 1024, 524], fill=(243, 112, 33)) # #F37021
    im.save(os.path.join(OUT_DIR, "fptu_alpha_facade.png"))
    print("Created fptu_alpha_facade.png")

# 20. HUTECH University High-Tech Campus Building Facade
def make_hutech_building():
    im = Image.new("RGB", (1024, 1024), (235, 238, 242))
    draw = ImageDraw.Draw(im)

    # Blue glass curtain wall with Golden yellow louvers
    for f in range(9):
        y = 50 + f * 105
        # Blue glass band
        draw.rectangle([0, y, 1024, y + 75], fill=(25, 90, 170), outline=(15, 55, 110), width=3)
        # Vertical golden-yellow louvers
        for x in range(30, 1000, 60):
            draw.rectangle([x, y - 6, x + 16, y + 81], fill=(255, 210, 0), outline=(180, 140, 0), width=1)
        # White horizontal floor slab
        draw.rectangle([0, y + 75, 1024, y + 105], fill=(245, 248, 252), outline=(190, 195, 200), width=2)

    # HUTECH large header brand
    draw.rectangle([0, 0, 1024, 60], fill=(0, 85, 165))
    font_h = get_font(32)
    draw.text((512, 30), "VIỆN CÔNG NGHỆ CAO HUTECH", fill=(255, 210, 0), font=font_h, anchor="mm")

    im.save(os.path.join(OUT_DIR, "hutech_building.png"))
    print("Created hutech_building.png")

if __name__ == "__main__":
    make_asphalt()
    make_sidewalk()
    make_curb()
    make_milano()
    make_suaxe()
    make_bunbo()
    make_taphoa()
    make_bachhoaxanh()
    make_awnings()
    make_roundabout_sign()
    make_fptu_sign()
    make_7eleven()
    make_bridge_barrier()
    make_ringroad3_pillar()
    make_wire_pole()
    make_hutech_sign()
    make_vinhomes_facade()
    make_vinhomes_gate()
    make_fptu_alpha_facade()
    make_hutech_building()
    print("ALL REALISTIC TEXTURES GENERATED SUCCESSFULLY!")
