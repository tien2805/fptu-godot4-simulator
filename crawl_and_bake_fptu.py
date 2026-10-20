import os
import sys
import time
import urllib.request
import urllib.parse
import json
from io import BytesIO
from PIL import Image, ImageDraw, ImageFont

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if sys.stderr and hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

REF_DIR = "reference_photos"
TEX_DIR = os.path.join("assets", "textures")
os.makedirs(REF_DIR, exist_ok=True)
os.makedirs(TEX_DIR, exist_ok=True)

# 1. Danh sách ẢNH CHỤP THẬT (100% REAL CAMERA PHOTOGRAPHS) từ Wikimedia Commons
# Tuyệt đối KHÔNG dùng AI Image Generation!
REAL_PHOTOS = [
    {
        "filename": "fptu_real_admin_checkerboard_facade.jpg",
        "title": "File:FPT University administration building.jpg",
        "desc": "Ảnh chụp thực tế mặt tiền ô bàn cờ (Checkerboard Facade) đan xen bồn cây xanh do VTN Architects thiết kế",
    },
    {
        "filename": "fptu_real_campus_overview.jpg",
        "title": "File:FPT UNIVERSITY Overview.jpg",
        "desc": "Ảnh chụp toàn cảnh khuôn viên trường ĐH FPT (Overview) từ góc nhìn trên cao",
    },
    {
        "filename": "fptu_real_campus_side_wing.jpg",
        "title": "File:FPT UNIVERSITY Side.jpg",
        "desc": "Ảnh chụp cánh tòa nhà giật cấp theo hình thái ngọn núi uốn lượn (Undulating mountain wings)",
    },
    {
        "filename": "fptu_real_campus_courtyard_view.jpg",
        "title": "File:FPT UNIVERSITY View.jpg",
        "desc": "Ảnh chụp thực tế sân trung tâm (Central Courtyard) và khuôn viên xanh",
    },
    {
        "filename": "fptu_real_campus_hall.jpg",
        "title": "File:FPT UNIVERSITY Hall.jpg",
        "desc": "Ảnh chụp sảnh đón và khu hội trường sinh viên bên trong campus",
    },
    {
        "filename": "fptu_real_spring_festival_campus.jpg",
        "title": "File:FPT UNIVERSITY SPRING FESTIVAL.jpg",
        "desc": "Ảnh chụp sân trường ĐH FPT trong lễ hội mùa xuân",
    },
    {
        "filename": "fptu_real_students_fall2023.jpg",
        "title": "File:FPTU Fall 2023.jpg",
        "desc": "Ảnh chụp thực tế sinh viên ĐH FPT trong kỳ học Fall 2023",
    },
    {
        "filename": "fptu_real_shtp_high_tech_park.jpg",
        "title": "File:Saigon Hi-Tech Park.JPG",
        "desc": "Ảnh chụp thực tế Khu Công nghệ cao TP.HCM (SHTP) - Trục đường D1 nơi ĐH FPT TP.HCM tọa lạc",
    },
    {
        "filename": "fptu_real_lotus_pond_reference.jpg",
        "title": "File:Sacred Lotus in a Pond 2.jpg",
        "desc": "Ảnh chụp thực tế hồ sen và hoa sen tự nhiên làm tư liệu ánh xạ cho Hồ Sen sinh thái FPTU",
    },
    {
        "filename": "vtn_architects_vo_trong_nghia.jpg",
        "title": "File:Vo Trong Nghia at Columbia GSAPP (1).jpg",
        "desc": "Ảnh chụp Kiến trúc sư Võ Trọng Nghĩa (VTN Architects) - tác giả thiết kế công trình ĐH FPT",
    }
]

def get_wikimedia_image_info(title, headers, target_width=1920):
    """Truy vấn Wikimedia MediaWiki API để lấy đường dẫn tải ảnh chất lượng cao chuẩn Wikimedia Policy."""
    api_url = (
        f"https://commons.wikimedia.org/w/api.php?action=query"
        f"&titles={urllib.parse.quote(title)}"
        f"&prop=imageinfo&iiprop=url|size|mime"
        f"&iiurlwidth={target_width}&format=json"
    )
    req = urllib.request.Request(api_url, headers=headers)
    with urllib.request.urlopen(req, timeout=12) as resp:
        data = json.loads(resp.read().decode("utf-8"))
        pages = data.get("query", {}).get("pages", {})
        if not pages:
            return None
        page = list(pages.values())[0]
        infos = page.get("imageinfo", [])
        if not infos:
            return None
        info = infos[0]
        download_url = info.get("thumburl") or info.get("url")
        if "?" in download_url:
            download_url = download_url.split("?")[0]
        return {
            "url": download_url,
            "orig_width": info.get("width", 0),
            "orig_height": info.get("height", 0),
            "mime": info.get("mime", "")
        }

def download_real_photographs():
    print("[1/2] Kiểm tra và cập nhật các ẢNH CHỤP THỰC TẾ (100% Real Photographs, NO AI)...")
    headers = {
        "User-Agent": "FPTUStudentSimulatorBot/1.0 (Educational open source project; contact: student.simulator@fpt.edu.vn)"
    }
    
    downloaded_count = 0
    readme_lines = [
        "# DANH SÁCH ẢNH CHỤP THỰC TẾ THAM CHIẾU (REAL PHOTOGRAPHIC REFERENCES)",
        "",
        "> **LƯU Ý QUAN TRỌNG:**",
        "> Tất cả ảnh trong thư mục này là **ẢNH CHỤP THỰC TẾ 100% TỪ MÁY ẢNH** (Real camera photographs) ",
        "> được cấp phép công khai (Creative Commons / Public Domain) trên Wikimedia Commons.",
        "> **TUYỆT ĐỐI KHÔNG SỬ DỤNG AI ĐỂ GEN ẢNH** (No Midjourney / DALL-E / Stable Diffusion).",
        "",
        "## Bảng chi tiết các tệp ảnh chụp thực tế:",
        "",
        "| Tên tệp | Tên nguồn Wikimedia Commons | Độ phân giải thực | Kích thước | Mô tả thực tế |",
        "| :--- | :--- | :--- | :--- | :--- |"
    ]
    
    for item in REAL_PHOTOS:
        filename = item["filename"]
        title = item["title"]
        save_path = os.path.join(REF_DIR, filename)
        
        if os.path.exists(save_path) and os.path.getsize(save_path) > 100000:
            try:
                img = Image.open(save_path)
                w, h = img.size
                fsize_kb = os.path.getsize(save_path) // 1024
                print(f"  -> [ĐÃ CÓ SẴN] {filename} ({w}x{h}, {fsize_kb} KB)")
                readme_lines.append(f"| `{filename}` | {title} | {w}x{h} ({img.format}) | {fsize_kb} KB | {item['desc']} |")
                downloaded_count += 1
                continue
            except Exception:
                pass
        
        try:
            print(f"  -> Đang tra cứu metadata: {title}...")
            meta = get_wikimedia_image_info(title, headers, target_width=1920)
            if not meta or not meta["url"]:
                raise ValueError("Không lấy được URL ảnh từ Wikimedia")
            
            img_url = meta["url"]
            print(f"     Tải từ: {img_url}...")
            req = urllib.request.Request(img_url, headers=headers)
            with urllib.request.urlopen(req, timeout=20) as resp:
                data = resp.read()
            
            img = Image.open(BytesIO(data))
            w, h = img.size
            img_format = img.format
            fsize_kb = len(data) // 1024
            
            with open(save_path, "wb") as f:
                f.write(data)
            
            print(f"     [OK] Đã lưu {filename} ({w}x{h}, {fsize_kb} KB)")
            downloaded_count += 1
            readme_lines.append(f"| `{filename}` | {title} | {w}x{h} ({img_format}) | {fsize_kb} KB | {item['desc']} |")
            time.sleep(1.2)
        except Exception as e:
            print(f"     [!] Lỗi khi tải {filename}: {e}")
            readme_lines.append(f"| `{filename}` | {title} | Lỗi tải: {e} | - | {item['desc']} |")
            time.sleep(1.5)

    readme_path = os.path.join(REF_DIR, "README.md")
    with open(readme_path, "w", encoding="utf-8") as f:
        f.write("\n".join(readme_lines) + "\n")
    print(f"  + Đã lưu bảng giải trình nguồn ảnh chụp: {readme_path}")
    print(f"  + Tổng số ảnh chụp thực tế có sẵn: {downloaded_count}/{len(REAL_PHOTOS)}")

# 2. XỬ LÝ & KẾT XUẤT ẢNH CHỤP THỰC TẾ THÀNH TEXTURE TRONG GAME (100% PHOTO-BASED ASSETS)
def bake_game_textures_from_real_photos():
    print("[2/2] Đang chuyển đổi ảnh chụp thực tế thành Texture & Billboard 3D trong game...")

    # A. Texture Mặt Tiền Ô Bàn Cờ Cắt Trực Tiếp Từ Ảnh Chụp Thật (fptu_real_admin_checkerboard_facade.jpg)
    facade_photo_path = os.path.join(REF_DIR, "fptu_real_admin_checkerboard_facade.jpg")
    if os.path.exists(facade_photo_path):
        img_facade = Image.open(facade_photo_path)
        # Cắt chính xác vùng khối ô bàn cờ bê tông trắng và bồn cây (2000, 700, 4048, 2748)
        crop_facade = img_facade.crop((2000, 700, 4048, 2748))
        crop_facade = crop_facade.resize((1024, 1024), Image.Resampling.LANCZOS)
        tex_facade_path = os.path.join(TEX_DIR, "fptu_alpha_facade.png")
        crop_facade.save(tex_facade_path)
        print(f"  + [A] Đã xuất Texture Mặt tiền thực tế từ ảnh chụp: {tex_facade_path} (1024x1024)")

    # B. Texture Mặt Nước Hồ Sen Cắt Từ Ảnh Chụp Thật (fptu_real_lotus_pond_reference.jpg)
    lotus_photo_path = os.path.join(REF_DIR, "fptu_real_lotus_pond_reference.jpg")
    if os.path.exists(lotus_photo_path):
        img_lotus = Image.open(lotus_photo_path)
        tex_lotus = img_lotus.resize((512, 512), Image.Resampling.LANCZOS)
        tex_lotus_path = os.path.join(TEX_DIR, "lotus_pond_real.png")
        tex_lotus.save(tex_lotus_path)
        print(f"  + [B] Đã xuất Texture Hồ sen thực tế: {tex_lotus_path} (512x512)")

    # C. Bảng Sơ Đồ Toàn Cảnh Cổng D1 từ Ảnh Chụp Thật (fptu_real_campus_overview.jpg)
    overview_photo_path = os.path.join(REF_DIR, "fptu_real_campus_overview.jpg")
    if os.path.exists(overview_photo_path):
        img_map = Image.open(overview_photo_path)
        tex_map = img_map.resize((1024, 512), Image.Resampling.LANCZOS)
        draw = ImageDraw.Draw(tex_map)
        # Viền khung bảng thông tin
        draw.rectangle([0, 0, 1024, 48], fill=(243, 112, 33)) # Màu cam FPT
        draw.rectangle([0, 0, 1023, 511], outline=(255, 255, 255), width=6)
        tex_map_path = os.path.join(TEX_DIR, "fptu_campus_map_billboard.png")
        tex_map.save(tex_map_path)
        print(f"  + [C] Đã xuất Biển sơ đồ toàn cảnh khuôn viên: {tex_map_path} (1024x512)")

    # D. Bảng Triển Lãm Kiến Trúc VTN Architects & KTS Võ Trọng Nghĩa (vtn_architects_vo_trong_nghia.jpg)
    vtn_photo_path = os.path.join(REF_DIR, "vtn_architects_vo_trong_nghia.jpg")
    if os.path.exists(vtn_photo_path):
        img_vtn = Image.open(vtn_photo_path)
        tex_vtn = img_vtn.resize((512, 512), Image.Resampling.LANCZOS)
        draw = ImageDraw.Draw(tex_vtn)
        draw.rectangle([0, 0, 512, 38], fill=(39, 174, 96)) # Màu xanh kiến trúc
        draw.rectangle([0, 0, 511, 511], outline=(240, 240, 240), width=4)
        tex_vtn_path = os.path.join(TEX_DIR, "fptu_vtn_architecture_plaque.png")
        tex_vtn.save(tex_vtn_path)
        print(f"  + [D] Đã xuất Bảng kỷ niệm kiến trúc VTN: {tex_vtn_path} (512x512)")

    # E. Bảng Hoạt Động Sinh Viên & Lễ Hội Sân Trường (fptu_real_students_fall2023.jpg)
    stu_photo_path = os.path.join(REF_DIR, "fptu_real_students_fall2023.jpg")
    if os.path.exists(stu_photo_path):
        img_stu = Image.open(stu_photo_path)
        tex_stu = img_stu.resize((512, 512), Image.Resampling.LANCZOS)
        draw = ImageDraw.Draw(tex_stu)
        draw.rectangle([0, 0, 512, 38], fill=(243, 112, 33))
        draw.rectangle([0, 0, 511, 511], outline=(255, 255, 255), width=4)
        tex_stu_path = os.path.join(TEX_DIR, "fptu_student_activities_billboard.png")
        tex_stu.save(tex_stu_path)
        print(f"  + [E] Đã xuất Bảng hoạt động sinh viên: {tex_stu_path} (512x512)")

    # F. Sảnh Đón Sinh Viên & Atrium (fptu_real_campus_hall.jpg)
    hall_photo_path = os.path.join(REF_DIR, "fptu_real_campus_hall.jpg")
    if os.path.exists(hall_photo_path):
        img_hall = Image.open(hall_photo_path)
        tex_hall = img_hall.resize((1024, 512), Image.Resampling.LANCZOS)
        tex_hall_path = os.path.join(TEX_DIR, "fptu_campus_hall_atrium.png")
        tex_hall.save(tex_hall_path)
        print(f"  + [F] Đã xuất Sảnh đón sinh viên Atrium: {tex_hall_path} (1024x512)")

    # G. Biển Cột Mốc Khu Công Nghệ Cao SHTP (fptu_real_shtp_high_tech_park.jpg)
    shtp_photo_path = os.path.join(REF_DIR, "fptu_real_shtp_high_tech_park.jpg")
    if os.path.exists(shtp_photo_path):
        img_shtp = Image.open(shtp_photo_path)
        tex_shtp = img_shtp.resize((1024, 512), Image.Resampling.LANCZOS)
        draw = ImageDraw.Draw(tex_shtp)
        draw.rectangle([0, 0, 1024, 42], fill=(20, 50, 90))
        draw.rectangle([0, 0, 1023, 511], outline=(255, 255, 255), width=5)
        tex_shtp_path = os.path.join(TEX_DIR, "fptu_shtp_monument.png")
        tex_shtp.save(tex_shtp_path)
        print(f"  + [G] Đã xuất Biển chào SHTP: {tex_shtp_path} (1024x512)")

if __name__ == "__main__":
    download_real_photographs()
    bake_game_textures_from_real_photos()
    print("Hoàn tất! Toàn bộ ảnh chụp thực tế đã được chuyển đổi thành Texture và áp dụng vào game.")