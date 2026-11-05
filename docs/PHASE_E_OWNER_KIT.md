# Bộ tài liệu Phase E cho chủ game (2026-11-03)

Mọi thứ game cần từ máy của bạn nằm ở đây: 3 clip AI (mỗi clip 2 bản nam / nữ), toàn bộ chỗ đặt nhạc, các âm thanh có thể
thay. Tài liệu này thay cho `docs/cinematics/music_to_download.md` và `docs/cinematics/music_suggestions.md` (hai file đó giữ
lại để tra lịch sử).

## 0. Để file ở đâu, kiểm tra thế nào

Thư mục dữ liệu của game:

```
%APPDATA%\Godot\app_userdata\FPTU Student Simulator- Godot 4 Edition\
    video\   3 clip AI x 2 bản: ai_intro_m.ogv, ai_intro_f.ogv, ...
    music\   nhạc: <slot>.ogg hoặc <slot>.mp3
    sfx\     âm thanh: <tên>.ogg, .mp3 hoặc .wav (vài nhóm chỉ đọc .ogg, xem mục 3)
```

- Thư mục `video\` chưa có: tự tạo.
- Các file này **chỉ nằm trên máy bạn**, không bao giờ đưa lên git hay vào bản phát hành.
- Thiếu video: game phát cảnh dựng sẵn trong game. Thiếu nhạc: chỗ đó **im lặng** (game không có nhạc tạo bằng code).
  Thiếu âm thanh: game dùng âm tự tạo.

**Công cụ kiểm tra** (chỉ đọc, không sửa hay xoá gì, không đụng save):

```
godot --headless --path . --script tools/check_owner_media.gd
godot --headless --path . --script tools/check_owner_media.gd -- --missing     (chỉ in cái còn thiếu)
```

Chạy trong thư mục dự án. Nó in từng file `[CÓ]`, `[THIẾU]`, `[MƯỢN]` (slot dùng file của slot cha) hay `[TỰ TẠO]` (âm do
game tạo), và liệt kê file game **không đọc** trong ba thư mục (sai tên, hoặc sai đuôi như `boss_d2.wav`). Lần chạy ngày 2026-11-03 trên máy bạn:
thiếu 6 video và 32 slot nhạc (28 bài, vì 4 đoạn đuôi lựa chọn mượn bài của cảnh chính); `sfx\loa_keo_keo` chưa có
nên loa kẹo kéo đang phát bolero tự tạo.

---

## 1. Ba clip AI

### 1.1 Thông số

| Clip | Phát lúc | Dài | File nam | File nữ | Nhạc phát đè |
|---|---|---|---|---|---|
| `ai_intro` | cuối Ngày 0: email đình chỉ thi, TOANG! | 20 s | `video\ai_intro_m.ogv` | `video\ai_intro_f.ogv` | `music\ai_intro` (đã có) |
| `ai_reveal` | cuối Ngày 6: bảng LỌ ACADEMY bật sáng | 24 s | `video\ai_reveal_m.ogv` | `video\ai_reveal_f.ogv` | `music\ai_reveal` (đã có) |
| `ai_true_end` | kết A, sau credits: tấm biển sập | 20 s | `video\ai_true_end_m.ogv` | `video\ai_true_end_f.ogv` | `music\ai_true_end`, không có thì bài của `end_a` |

- **Định dạng:** Ogg Theora `.ogv` (Godot không đọc .mp4). Khung 16:9, 1920x1080 hoặc 1280x720, 24-30 hình/giây. Khung khác
  16:9 vẫn chạy (game giữ tỉ lệ, thêm viền đen).
- **Độ dài:** đúng như bảng là đẹp nhất; dài hơn hay ngắn hơn vài giây vẫn chạy, clip hết là game đi tiếp.
- **Nam / nữ:** game chọn theo nhân vật người chơi tạo. Thiếu bản nào thì bản đó phát cảnh dựng sẵn.
- **Âm thanh:** có file nhạc của slot thì nhạc đó phát từ hình đầu tiên, mờ dần theo clip, và **tiếng của clip bị tắt**.
  Không có file nhạc thì tiếng của clip phát. Muốn giữ tiếng gốc của clip thì đổi tên file nhạc slot đó đi.
- **Chữ và phụ đề:** clip thay hoàn toàn cảnh trong game. Game **không** vẽ thêm phụ đề, email, dấu TOANG!, tin nhắn hay
  tựa đề lên video. Bạn tự chèn chữ (CapCut, Premiere) hoặc đốt phụ đề vào hình bằng ffmpeg (mục 1.6).
- **Xem lại phim** trong menu Chọn cảnh phát bản dựng trong game, không phát video.
- Người chơi giữ Esc hoặc Enter 0,6 s để bỏ qua clip.

### 1.2 Ảnh tham chiếu nhân vật

Công cụ AI cần ảnh mẫu để nhân vật giống game. Tự chụp trong game (Win + Shift + S):

- **Nhân vật chính:** vào màn tạo nhân vật, xoay mặt trước, chéo 3/4, ngang, sau lưng. Chụp một bộ nam, một bộ nữ.
- **Nhân vật phụ:** chụp lúc họ đứng trong cảnh (Win + Shift + S làm màn hình đứng lại để chụp; đừng giữ Esc, giữ Esc là
  bỏ qua cảnh). Thị Lọ ở cảnh `cine_d6_caught` / `ai_reveal`, Phúc và Anh Duy ở `end_a` / `ai_true_end` (vào bằng Chọn
  cảnh > Xem lại phim).
- Nền trơn là tốt nhất; cắt bớt giao diện trước khi đưa vào công cụ AI.

Mô tả nhân vật (dùng trong prompt, tiếng Anh):

| Nhân vật | Mô tả |
|---|---|
| Nhân vật chính, nam (HERO_M) | a young Vietnamese male university student, short black hair, plain orange polo shirt, blue jeans, white sneakers, black backpack, low-poly PS2-era game character |
| Nhân vật chính, nữ (HERO_F) | a young Vietnamese female university student, shoulder-length black hair, plain orange polo shirt, blue jeans, white sneakers, black backpack, low-poly PS2-era game character |
| Lùm Thị Lọ | a young woman with a neon-pink bob haircut, leopard-print jacket, oversized black sunglasses, low-poly PS2-era game character |
| Lùm Văn Lọ (chỉ trên biển quảng cáo) | a smug middle-aged man, white suit, pastel-pink shirt, gold chain, gold-rimmed glasses |
| Phúc | a skinny male student with spiky black hair, rumpled plain orange polo, holding an energy-drink can |
| Anh Duy | a big-bellied IT guy, faded grey hoodie, over-ear headphones, a lanyard with a bunch of keys, a laptop |
| Người áo cừu | a figure in a white fluffy sheep mask and a cream wool cardigan |

### 1.3 Phong cách chung

Thêm vào cuối mọi prompt:

```
Style: stylized 3D game cutscene matching the reference renders, PS2-era low-poly people, pastel 1980s Miami palette,
soft film grain, cinematic camera, 16:9.
```

Negative prompt (nếu công cụ có ô này):

```
realistic faces, photorealistic skin, real people, celebrities, gore, blood, logos, brand names, watermark, text artifacts,
extra fingers, distorted faces
```

Mỗi prompt bên dưới có `{HERO}`: thay bằng HERO_M cho bản nam, HERO_F cho bản nữ, và đính kèm ảnh tham chiếu tương ứng.
Phần lớn công cụ tạo 5-10 s mỗi lần: tạo từng cảnh rồi ghép, cắt đúng độ dài cột "Dài".

### 1.4 `ai_intro` (20 s): TOANG!

Sáng hôm sau trước tòa BE6, nhân vật chính đọc email đình chỉ thi. Nhạc gợi ý: *The End of the World*, Skeeter Davis (đã có).

| Cảnh | Từ | Dài | Prompt |
|---|---|---|---|
| S1 | 0,0 | 1,4 s | Wide shot, sunny morning in front of a modern university building with orange accents, {HERO} stands on the plaza reading a smartphone, students passing in the background. Static camera. |
| S2 | 1,4 | 3,5 s | Over-the-shoulder close-up of the smartphone screen: an official email titled "Quyết định đình chỉ thi" types itself out line by line (done by 2,8 s, then held still for reading), then (at 4,0 s) a huge red rubber stamp "TOANG!" slams onto it, the phone shakes. Static camera. |
| S3 | 4,9 | 3,5 s | Push-in on {HERO}'s face, shocked, mouth open; then a comic facepalm. Morning light. |
| S4 | 8,4 | 5,0 s | Low-angle hero shot of {HERO} lowering the phone, determined look, clenching a fist, the building towering behind, lens flare. |
| S5 | 13,4 | 6,6 s | Slow orbit around {HERO} standing still on the plaza while the sky turns to a warm sunset; leave the upper third empty for the title "TOOL ĐEN – 7 ngày minh oan". At the end the phone lights up with a new message. |

Chữ cần chèn: email "Phòng Khảo thí: Quyết định đình chỉ thi" (S2, chữ hiện dần), dấu đỏ "TOANG!" (S2, ở 4,0 s), tin của
Mr.T "Thầy tin em. Tìm bằng chứng đi." (đầu S3), đồng hồ đếm ngược lật về 7 (S4), tựa đề "TOOL ĐEN – 7 ngày minh oan" (S5).

### 1.5 `ai_reveal` (24 s): Lọ Academy

Đêm cuối Ngày 6, bờ kênh dưới cầu Rạch Hầm. Nhạc gợi ý: *O Fortuna* (Carmina Burana), Carl Orff (đã có).

| Cảnh | Từ | Dài | Prompt |
|---|---|---|---|
| S1 | 0,0 | 2,6 s | Wide night shot under a concrete bridge by a dark canal, {HERO} walks to the water's edge reading an old ledger book, the far bank dark. Static camera, blue moonlight, neon reflections on the water. |
| S2 | 2,6 | 1,8 s | Low shot just above the water: a jet ski glides in out of the dark, a biker in a grey wolf-head helmet drives, Lùm Thị Lọ (neon-pink bob, leopard-print jacket, oversized sunglasses) sits behind him. |
| S3 | 4,4 | 1,8 s | Two-shot: {HERO} on the bank, Thị Lọ on the idling jet ski, she lowers her sunglasses with a smirk. |
| S4 | 6,2 | 3,6 s | Crane up over {HERO}'s shoulder: across the canal a giant billboard "LỌ ACADEMY" flickers on in pink and gold neon with a smug man's face, fireworks burst behind it. |
| S5 | 9,8 | 4,1 s | Slow push-in on Thị Lọ pointing at the billboard, laughing, pink neon on her face. |
| S6 | 13,9 | 2,4 s | Slow push-in on {HERO}, eyes wide, the billboard reflected in the eyes. |
| S7 | 16,3 | 2,0 s | Wide: the jet ski roars off to the right in a fan of spray, the billboard glowing over the water. |
| S8 | 18,3 | 2,4 s | Low-angle hero shot of {HERO} on the bank, a comic facepalm. |
| S9 | 20,7 | 3,3 s | Close-up: a smartphone screen lights {HERO}'s face from below, the billboard glowing over the shoulder. |

Chữ cần chèn: bảng "LỌ ACADEMY" và dòng "ĐẬU 100%, KHÔNG CẦN HỌC" (S4); tin của Phúc "Trà Sữa Lọ giảm 50% tối nay" (S8,
câu đùa); tin Số lạ ở S9 (phụ đề bên dưới).

### 1.6 `ai_true_end` (20 s): tấm biển sập

Kết A, hoàng hôn bên kênh. Nhạc: file `music\ai_true_end` riêng, không có thì bài của `end_a` (*September*, đã có).

| Cảnh | Từ | Dài | Prompt |
|---|---|---|---|
| S1 | 0,0 | 1,0 s | Wide sunset shot of a canal: a giant "LỌ ACADEMY – Học thật, đậu thật" billboard with a smug man's face across the water, three friends on the near bank seen from behind. |
| S2 | 1,0 | 4,2 s | Two-shot: Anh Duy (big belly, grey hoodie, headphones) types on a laptop and presses Enter dramatically, {HERO} beside him nods. |
| S3 | 5,2 | 3,2 s | Low shot of the billboard: it wobbles, creaks and topples backward, the smug face going down, a big dust cloud. |
| S4 | 8,4 | 2,3 s | Push-in on Phúc (spiky hair, energy drink) cheering wildly, arms up. |
| S5 | 10,7 | 2,3 s | Low-angle hero shot of {HERO} smiling at the sunset, the backpack on one shoulder. |
| S6 | 13,0 | 3,7 s | Post-credits: dark canal water at dusk, a white fluffy sheep mask floats in slowly from the left. Static camera, eerie stillness. |
| S7 | 16,7 | 3,3 s | Close-up: the floating sheep mask has slowly turned to face the camera. Hold. |

"Giảm hù dọa" không làm dịu được video: giữ S6-S7 nhẹ nhàng (không giật mình, không tiếng hét).

### 1.7 Phụ đề (.srt)

Lưu thành file `.srt` (UTF-8) rồi đốt vào hình ở bước 1.8. Tên người chơi không đưa vào video được, nên câu của nhân vật
chính không ghi tên người nói.

`ai_intro.srt`:

```
1
00:00:05,000 --> 00:00:06,900
Mình... bị đình chỉ thi á?!

2
00:00:06,950 --> 00:00:08,650
Mới được khen hôm qua mà...

3
00:00:10,500 --> 00:00:13,400
Được. Bảy ngày. Phải tìm ra kẻ cài cái kính đó!

4
00:00:17,000 --> 00:00:19,500
Số lạ (tin nhắn): Đừng đào sâu. Mày còn 7 ngày thôi.
```

`ai_reveal.srt`:

```
1
00:00:00,600 --> 00:00:02,500
Sổ cái có rồi. Xong một vụ...

2
00:00:04,600 --> 00:00:06,200
Thị Lọ: Tưởng vậy là xong hả?

3
00:00:10,000 --> 00:00:12,500
Thị Lọ: Anh tao sẽ cho cả trường mày đậu...

4
00:00:12,600 --> 00:00:13,800
Thị Lọ: ...bằng tool!

5
00:00:14,100 --> 00:00:16,100
Lùm Văn Lọ... là anh bả?

6
00:00:16,300 --> 00:00:18,000
Thị Lọ: Hẹn gặp ở Lọ Academy nha!

7
00:00:19,200 --> 00:00:20,700
...Phúc ơi là Phúc.

8
00:00:21,000 --> 00:00:23,600
Số lạ (tin nhắn): 8 giờ sáng mai cả trường thi. Cản nổi không?
```

`ai_true_end.srt`:

```
1
00:00:01,200 --> 00:00:03,700
Anh Duy: Lệnh gỡ biển approve r, a bấm deploy nha. (Dịch: Gỡ tấm biển xuống.)

2
00:00:03,900 --> 00:00:04,800
Bấm đi anh.

3
00:00:08,700 --> 00:00:10,700
Phúc: Đỉnh nóc, kịch trần, bay phấp phới!

4
00:00:10,900 --> 00:00:12,900
Học thật, đậu thật. Giờ mới đúng nghĩa.

5
00:00:17,400 --> 00:00:19,600
Số lạ (tin nhắn): Hẹn gặp lại... năm sau.
```

### 1.8 Đổi sang .ogv bằng ffmpeg

Đã thử trên máy này với Godot 4.7: các lệnh dưới đây cho file game đọc được.

```
:: Ghép xong, đổi sang Theora (bước bắt buộc)
ffmpeg -i ai_intro_m.mp4 -c:v libtheora -q:v 7 -c:a libvorbis -q:a 5 ai_intro_m.ogv

:: Đốt phụ đề vào hình
ffmpeg -i ai_intro_m.mp4 -vf "subtitles=ai_intro.srt:force_style='FontName=Arial,FontSize=22,Outline=2'" -c:v libtheora -q:v 7 -c:a libvorbis -q:a 5 ai_intro_m.ogv

:: Khung không phải 16:9: thu nhỏ vào 1920x1080 có viền đen
ffmpeg -i in.mp4 -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2" -c:v libtheora -q:v 7 -c:a libvorbis -q:a 5 out.ogv

:: Cắt đúng độ dài (ai_reveal 24 s; ai_intro: -t 20; ai_true_end: -t 20)
ffmpeg -i in.mp4 -t 24 -c:v libtheora -q:v 7 -c:a libvorbis -q:a 5 out.ogv
```

Chép file `.ogv` vào `video\`, chạy công cụ kiểm tra, rồi chơi tới cảnh đó (hoặc Chọn cảnh vào beat ngay trước).

---

## 2. Nhạc: toàn bộ 101 slot

Mỗi dòng là một file `music\<slot>.ogg` hoặc `music\<slot>.mp3`. Trạng thái là lần kiểm tra ngày 2026-11-03.

- **Nhạc nền** (menu, đi tự do, màn chơi, nhiệm vụ, đêm): tự lặp, chuyển bài mờ dần 1,2 s. Bản cắt vài phút là đủ (game đọc
  cả file vào bộ nhớ). Cắt bỏ khoảng im lặng ở đầu.
- **Cảnh phim:** phát một lần từ giây 0 của cảnh. File dài hơn cảnh mờ dần trong 0,5 s cuối. Nhịp từng cảnh nằm trong
  `docs/cinematics/<slot>.txt`.
- **Replay ngắn:** dài 5,0 s, cú đánh mạnh nhất ở khoảng 2,75 s: cắt sao cho đoạn mạnh của bài rơi đúng chỗ đó.
- Tải bài về `Downloads`, đặt tên bắt đầu bằng tên slot (ví dụ `boss_d2_Hungry Like the Wolf.mp3`) rồi báo Claude cắt và
  đưa vào `music\` là nhanh nhất.

### 2.1 Còn thiếu (cần tải 28 bài)

| | Slot | Phát khi | Bài gợi ý | Độ dài / cắt |
|---|---|---|---|---|
| [ ] | `mission_bike_chase_b` | đợt 3 của cuộc rượt xe Ngày 2, sau khi Sói Xám vượt mặt (không có thì *Tokyo Drift* chạy tiếp) | *Gas Gas Gas*, Manuel | nền, lặp |
| [ ] | `boss_d2` | đấu tay đôi Sói Xám dưới cầu Rạch Hầm (Ngày 2) | *Hungry Like the Wolf*, Duran Duran | nền, lặp |
| [ ] | `cine_d2_intro` | Anh Duy dò đường Bầy Sói trên ba laptop (Ngày 2) | *Who Let the Dogs Out*, Baha Men | 14 s |
| [ ] | `cine_d3_intro` | chạy xe đêm tới kênh, Anh Duy nói qua bộ đàm (Ngày 3) | *A Real Hero*, College & Electric Youth | 14 s |
| [ ] | `mission_sneak` | lẻn vào bến container (Ngày 3) | *Sneaky Snitch*, Kevin MacLeod | nền, lặp |
| [ ] | `cine_d3_mannequins` | cửa container mở, ma-nơ-canh quay đầu, "Surprise!" (Ngày 3) | *Toccata and Fugue in D minor*, J. S. Bach | 9,3 s |
| [ ] | `meme_mannequin` | ma-nơ-canh đứng im khi lính quay lại (Ngày 3) | *Black Beatles*, Rae Sremmurd | nền, lặp |
| [ ] | `mission_gunfight` | đấu súng ở bến container (Ngày 3) | *Bang Bang (My Baby Shot Me Down)*, Nancy Sinatra | nền, lặp |
| [ ] | `meme_coffin_dance` | bảo vệ khiêng thùng kính kiểu "coffin dance" (Ngày 3) | *Astronomia*, Vicetone & Tony Igy | nền, lặp |
| [ ] | `boss_d3` | trùm xe nâng Alexander (Ngày 3) | *Copacabana*, Barry Manilow | nền, lặp |
| [ ] | `cine_d5_intro` | Anh Duy giải mã USB (Ngày 5) | *Technologic*, Daft Punk | 14 s |
| [ ] | `mission_basement` | đi lén dưới hầm server (Ngày 5) | *Oxygène (Part IV)*, Jean-Michel Jarre | nền, lặp |
| [ ] | `cine_d5_monitors` | mặt Za Mẫn cười trên 50 màn hình (Ngày 5) | *Mr. Roboto*, Styx | 10 s |
| [ ] | `mission_gunfight_d5` | đấu súng dưới hầm (Ngày 5) | *Blue (Da Ba Dee)*, Eiffel 65 | nền, lặp |
| [ ] | `mission_typing` | gõ phím xoá "Lọ Thần 9.0" (Ngày 5) | *Around the World*, Daft Punk | nền, lặp |
| [ ] | `mission_fire_hack` | phòng server cháy, gõ phím trong lúc đếm ngược (Ngày 5) | *Disco Inferno*, The Trammps | nền, lặp |
| [ ] | `cine_d5_choice` | phòng server cháy, "Ổn mà", lựa chọn 2 (Ngày 5) | *Don't Worry, Be Happy*, Bobby McFerrin | 14 s |
| [ ] | `boss_d5` | đấu kiếm với Za Mẫn (Ngày 5) | *Battle Without Honor or Humanity*, Tomoyasu Hotei | nền, lặp |
| [ ] | `cine_d6_intro` | Phúc đưa bộ đồ shipper hồng trước quán (Ngày 6) | *Sugar, Sugar*, The Archies | 16 s |
| [ ] | `mission_shop` | làm ca sau quầy Trà Sữa Lọ (Ngày 6) | *Barbie Girl*, Aqua | nền, lặp |
| [ ] | `cine_d6_caught` | bóng người trong gương, "Gì?", "Còn cái nịt", cúp điện (Ngày 6) | *Material Girl*, Madonna | 21 s |
| [ ] | `mission_boat` | rượt cano trên kênh Rạch Hầm ban đêm (Ngày 6) | *Danger Zone*, Kenny Loggins | nền, lặp |
| [ ] | `cine_d6_choice` | vali tiền trên bờ kênh, lựa chọn 3 (Ngày 6) | *Money for Nothing*, Dire Straits | 14 s |
| [ ] | `cine_d7_intro` | bình minh, Anh Duy báo 08:00 tool lên hệ thống thi (Ngày 7) | *Lux Aeterna*, Clint Mansell | 13 s |
| [ ] | `mission_tower` | leo tòa Lọ Academy: hầm xe, kho, tầng server, ma-nơ-canh, laser, gõ phím (Ngày 7) | *Thunderstruck*, AC/DC | nền, lặp |
| [ ] | `cine_d7_monologue` | Lùm Văn Lọ "Mọi thứ đều nằm trong kế hoạch", tắt đèn (Ngày 7) | *Sweet Dreams (Are Made of This)*, Eurythmics | 13 s |
| [ ] | `side_drift` | đua drift đêm tự do (3 tuyến) | *Night of Fire*, Niko | nền, lặp |
| [ ] | `side_delivery` | chạy giao hàng tính giờ (đi tự do) | *Running in the 90s*, Max Coveri (có thể chép từ `stage1_race`) | nền, lặp |

Đuôi lựa chọn (không bắt buộc: không có file riêng thì phát bài của cảnh chính):

| | Slot | Phát khi | Gợi ý | Dài |
|---|---|---|---|---|
| [ ] | `cine_d1_choice_cover` | che cho Phúc, "...Hai tô." | *With a Little Help from My Friends*, Joe Cocker | 4 s |
| [ ] | `cine_d1_choice_report` | báo cáo Phúc | *The Sound of Silence*, Simon & Garfunkel | 4,5 s |
| [ ] | `cine_d5_choice_accept` / `cine_d5_choice_refuse` | nhận / từ chối lời mời Za Mẫn | dùng bài `cine_d5_choice` | 4 s |
| [ ] | `cine_d6_choice_take` / `cine_d6_choice_refuse` | nhận / từ chối vali tiền | dùng bài `cine_d6_choice` | 5 s |
| [ ] | `ai_true_end` | clip kết A (mục 1.6) | dùng bài `end_a` | 20 s |

### 2.2 Nhạc nền đã có

| | Slot | Phát khi | Bài |
|---|---|---|---|
| [x] | `menu` | menu chính, tạo nhân vật | *Nightcall*, Kavinsky |
| [x] | `roam_day` | đi tự do ban ngày | *Take On Me*, a-ha |
| [x] | `roam_night` | đi tự do ban đêm | *Resonance*, HOME |
| [x] | `stage1_race` | Màn 1 đua xe | *Running in the 90s*, Max Coveri |
| [x] | `stage2_parking` | Màn 2 bãi xe | *Gonna Fly Now*, Bill Conti |
| [x] | `stage3_classroom` | Màn 3 lớp học | *Clair de Lune*, Debussy |
| [x] | `stage4_vovinam` | Màn 4 Vovinam | *Kung Fu Fighting*, Carl Douglas |
| [x] | `stage5_canteen` | Màn 5 căn tin | *Flight of the Bumblebee*, Rimsky-Korsakov |
| [x] | `stage6_capstone` | Màn 6 Capstone | *Harder, Better, Faster, Stronger*, Daft Punk |
| [x] | `stage_extra_exam` | màn phụ coi thi | *Mission: Impossible Theme*, Lalo Schifrin |
| [x] | `mission_stakeout` | rình bãi xe (Ngày 1) | *Secret Agent Man*, Johnny Rivers |
| [x] | `mission_chase` | rượt Mũ Đỏ (Ngày 1) | *Chase*, Giorgio Moroder |
| [x] | `mission_fight` | đánh tay không Ngày 1 và Ngày 4 | *Holding Out for a Hero*, Bonnie Tyler |
| [x] | `mission_canteen` | nằm vùng căn tin (Ngày 4), nhỏ hơn 6 dB | *Careless Whisper*, George Michael |
| [x] | `mission_corridor` | hành lang tối (Ngày 1) | *Tubular Bells*, Mike Oldfield |
| [x] | `mission_bike_chase` | rượt xe đá Bầy Sói (Ngày 2), phát từ đầu bài (beat vào ở 4,15 s) | *Tokyo Drift*, Teriyaki Boyz |
| [x] | `race_d2_drift` | đua drift với Sói Xám, bắt đầu lúc "ĐI!" | *Deja Vu*, Dave Rodgers |
| [x] | `boss_d7` | trùm cuối Lùm Văn Lọ (Ngày 7) | *The Final Countdown*, Europe |
| [x] | `night_stealth` | tòa nhà đêm: chưa bị nghi | *Stranger Things*, Kyle Dixon & Michael Stein |
| [x] | `night_tense` | tòa nhà đêm: bị nghi; cũng là nhạc hai cảnh bí mật ban đêm (thuyền ma 14 s, tầng 13 13 s) | *It Follows*, Disasterpeace |
| [x] | `night_chase` | tòa nhà đêm: bị đuổi | *Halloween Theme*, John Carpenter |
| [x] | `night_escape` | tòa nhà đêm: chạy thoát | *Turbo Killer*, Carpenter Brut |

### 2.3 Cảnh phim đã có

| | Slot | Cảnh | Dài | Bài |
|---|---|---|---|---|
| [x] | `cine_d0_wake` | tỉnh dậy hoảng loạn | 8 s | *Wake Me Up Before You Go-Go*, Wham! |
| [x] | `cine_d0_brief` | Mr.T nhờ coi thi | 12 s | *Peter Gunn Theme*, Henry Mancini |
| [x] | `cine_d0_exam` | bằng chứng đầu tiên | 15,6 s | *I Got You (I Feel Good)*, James Brown |
| [x] | `cine_d0_midnight` | nửa đêm ở BE6 | 22 s | *Mr. Sandman*, The Chordettes |
| [x] | `ai_intro` | TOANG! | 20 s | *The End of the World*, Skeeter Davis |
| [x] | `cine_day_start` | tờ lịch bị xé mỗi sáng | 9 s | *Good Morning* (*Singin' in the Rain*) |
| [x] | `cine_d1_intro` | Mr.T cho xem camera | 14 s | *The X-Files Theme*, Mark Snow |
| [x] | `cine_d1_corridor` | cuối hành lang tối | 7,5 s | *The Murder* (*Psycho*), Bernard Herrmann |
| [x] | `cine_d1_choice` | Phúc thú nhận, lựa chọn 1 | 12 s | *Mad World*, Gary Jules |
| [x] | `cine_d1` | Sói Xám (cuối Ngày 1) | 18 s | *Green Onions*, Booker T. & the M.G.'s |
| [x] | `cine_d2` | trói Sói Xám | 18 s | đã có |
| [x] | `cine_d3` | tên dài nhất bến | 18 s | đã có |
| [x] | `cine_d4_intro` | Linh bày kế ở căn tin | 14 s | *Stayin' Alive*, Bee Gees |
| [x] | `cine_d4_stare` | cả căn tin nhìn bạn | 10 s | *The Lonely Shepherd*, Gheorghe Zamfir |
| [x] | `cine_d4` | Dolly khai | 18 s | *Every Breath You Take*, The Police |
| [x] | `cine_d5` | dòng tiền | 18 s | đã có |
| [x] | `ai_reveal` | Lọ Academy | 24 s | *O Fortuna*, Carl Orff |
| [x] | `end_a` | Kết A | 26 s | *September*, Earth, Wind & Fire |
| [x] | `end_b` | Kết B | 24 s | *Lean on Me*, Bill Withers |
| [x] | `end_c` | Kết C | 26,5 s | *Money, Money, Money*, ABBA |
| [x] | `end_d` | Kết D | 26 s | *Fly Me to the Moon*, Frank Sinatra |
| [x] | `end_e` | Kết E | 27 s | *Never Gonna Give You Up*, Rick Astley |
| [x] | `end_f` | Kết F | 22 s | *Celebration*, Kool & the Gang |
| [x] | `seg_d1_brawl` | đánh 3 shipper | 25 s | *I've Gotta Be Me* |
| [x] | `seg_d2_boss` | Sói Xám dưới cầu | 22 s | *Heartbreaker*, Pat Benatar |
| [x] | `seg_d3_boss` | móc cẩu và xe nâng của Alexander | 21 s | *Straighten Up and Fly Right*, Robbie Williams |
| [x] | `seg_d4_brawl` | bầy cừu ở căn tin | 25 s | *Ain't That a Kick in the Head*, Dean Martin |
| [x] | `seg_d5_boss` | cây gậy, katana cong gãy đôi, cú nhảy sào đá bay | 25 s | *The Good Life*, José James |
| [x] | `seg_d6_chase` | cano của Thị Lọ đâm vào bờ | 22 s | *Ring of Fire*, Des Rocs |
| [x] | `seg_d7_phase2` | có điện rồi | 25 s | *The Power of Love*, Jennifer Rush |
| [x] | `seg_d7_finisher` | đòn chân kẹp cổ số 21 | 25 s | *What a Wonderful World*, Louis Armstrong |
| [x] | `wanted_busted` | bị bắt khi bị truy nã | 7 s | *Bad Boys*, Inner Circle |

### 2.4 Replay ngắn đã có (5,0 s, đoạn mạnh ở 2,75 s)

| | Slot | Replay | Bài |
|---|---|---|---|
| [x] | `seg_d0_race` | đua xe Ngày 0 | *Deja Vu*, Dave Rodgers (từ tiếng hét "Deja vu!") |
| [x] | `seg_d0_exam` | bắt tool trong phòng thi | *Bad to the Bone* (riff) |
| [x] | `seg_d1_chase` | rượt shipper | *Yakety Sax* |
| [x] | `seg_d2_chase` | rượt xe đêm | *Tokyo Drift* (từ "I wonder if you know") |
| [x] | `seg_d3_gunfight` | đấu súng bến container | *Misirlou*, Dick Dale |
| [x] | `seg_d3_crates` | đập thùng | *Boom, Boom, Boom, Boom!!*, Vengaboys |
| [x] | `seg_d4_escape` | thoát tòa nhà đêm | *Ghostbusters* |
| [x] | `seg_d5_gunfight` | đấu súng dưới hầm | *Kernkraft 400*, Zombie Nation |
| [x] | `seg_d5_hack` | gõ phím xoá tool | *Sandstorm*, Darude |
| [x] | `seg_d6_infiltrate` | lấy sổ cái | *The Pink Panther Theme* |
| [x] | `seg_d7_floors` | leo hết các tầng | *Eye of the Tiger*, Survivor |
| [x] | `seg_d7_phase1` | Lọ và sáu bảo vệ gục | *In the Hall of the Mountain King*, Grieg |

Không có nhạc riêng (chỉ âm thanh): cuộc gọi 3 giờ sáng, thẻ giới thiệu, thẻ ngày.

---

## 3. Âm thanh có thể thay (`sfx\`)

Không có file thì game dùng âm tự tạo, nên mục này **không bắt buộc**. Tên file = tên trong bảng + đuôi. Chú ý cột định dạng:
nhóm "chỉ .ogg" bỏ qua file .mp3 / .wav (công cụ kiểm tra sẽ báo).

**Đã có trên máy:** `boom`, `sad_trombone`, `record_scratch`, `ba_dum_tss`, `bonk`, `dun_dun_duun`, `success_fanfare`,
`toang_sting`, `music_box`, `sheep_bleat_distorted`, `phone_ring_3am`, `static_burst`, `siuuu`, `bike_exhaust`,
`bike_horn`, `bike_rev`, `dolly_wc_full` (`dolly_wc_1` .. `dolly_wc_5` cũng có nhưng game chỉ đọc `dolly_wc_full`).

| Nhóm | Định dạng | Tên |
|---|---|---|
| Meme (cốt truyện) | .ogg / .mp3 / .wav | `boom` (Vine boom), `sad_trombone`, `record_scratch`, `ba_dum_tss` (rimshot), `bonk`, `dun_dun_duun`, `success_fanfare` (kiểu "mission passed"), `toang_sting` (tiếng lỗi Windows XP) |
| Kinh dị (cốt truyện; nhỏ hơn 6 dB khi bật "Giảm hù dọa") | .ogg / .mp3 / .wav | `heartbeat`, `breath`, `whisper_bed`, `violin_screech`, `music_box` (*Für Elise* hộp nhạc), `metal_creak`, `sheep_bleat_distorted`, `phone_ring_3am` (nhạc chuông Nokia), `static_burst` |
| Chi tiết kinh dị | .ogg / .mp3 / .wav | `dolly_hum`, `gasp`, `alarm_siren`, `cat_meow`, `bin_crash`, `locker_slam`, `rustle`, `door_knock`, `sniff`, `sub_boom`, `school_bell`, `cliff_sting` |
| Cảnh phim | chỉ .ogg | `impact_light`, `impact_medium`, `impact_heavy`, `whoosh_down`, `freeze_tick`, `crate_smash`, `body_fall`, `slide_whistle`, `groan`, `phone_buzz`, `engine_roar`, `neck_crack`, `helmet_clonk`, `tray_clang`, `pot_clonk`, `chair_smash`, `burp`, `fluoro_buzz`, `party_horn`, `wolf_howl`, `ringtone_synth` (nhạc chuông Sói Xám), `door_bang`, `keyboard_clack`, `glass_crack`, `sword_clang`, `blade_snap`, `fire_crackle`, `evil_laugh`, `applause`, `chain_rattle` |
| Đòn đánh | .ogg / .mp3 | `whoosh_hit`, `thud`, `body`, `crowd_oh`, `sting`, `keng`, `slam`, `metal_slam`, `wood_break`, `hit_tick`, `ko_tick`, `stick_crack` |
| Kiếm, gậy | .ogg / .mp3 | `staff_swish`, `staff_hit`, `staff_hit_heavy`, `blade_clash`, `parry_ring`, `glint`, `glint_red`, `katana_slash`, `katana_boing`, `katana_snap`, `howl`, `rain` |
| Vũ khí | .ogg / .mp3 | `punch`, `swish`, `knife_hit`, `reload`, `dry_click`, `shot_pistol`, `shot_shotgun`, `pump`, `ricochet`, `rocket_launch`, `explosion`, `bonk`, `dep_whoosh`, `durian_pop`, `cough`, `bolero`, `bag_drop`, `siuuu` |
| Súng, xe nâng | chỉ .ogg | `forklift_horn`, `forklift_lift`, `steam_hiss`, `party_horn`, `heartbeat` |
| Xe máy của bạn | .ogg / .mp3 / .wav | `bike_exhaust` (pô), `bike_horn` (còi), `bike_rev` (rồ ga) |
| Loa kẹo kéo (vũ khí) | .ogg / .mp3 | `loa_keo_keo`: bài loa phát. Không có file thì game phát bản bolero tự tạo |
| Chỉ có khi bạn thêm (thiếu = im lặng) | .ogg / .mp3 / .wav | `dolly_wc_full` (độc thoại của Dolly trong nhà vệ sinh) |

Câu meme có giọng ("Ét o ét!", "Gét gô!", "Tới công chuyện luôn!", "Còn cái nịt", "Xin vĩnh biệt cụ") hiện chỉ có phụ đề.
Nếu bạn hoặc bạn bè tự thu giọng thì báo Claude để thêm chỗ gắn từng câu. Không dùng giọng người nổi tiếng.

---

## 4. Thứ tự gợi ý

1. Tải 28 bài ở mục 2.1 (nhạc thiếu thì cảnh im lặng, đây là chỗ thấy rõ nhất).
2. `sfx\loa_keo_keo.ogg` hoặc `.mp3` nếu muốn loa kẹo kéo phát bài của bạn (không có thì game phát bolero tự tạo).
3. Ba clip AI, bản của giới tính bạn hay chơi trước; bản còn lại sau.
4. Chạy `tools/check_owner_media.gd -- --missing` sau mỗi đợt.
