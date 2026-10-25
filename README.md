# <img src="assets/icon/cocvang_icon_256.png" width="56" align="top"> FPTU Student Simulator: Đường Đến Trường

Game 3D hài hước mô phỏng **một ngày của sinh viên Đại học FPT TP.HCM** (Khu Công nghệ cao, đường D1), làm bằng **Godot 4.7** thuần GDScript. Khuôn viên trường được dựng lại theo **ảnh flycam thật và mặt bằng OpenStreetMap**: vòng nhà chữ nhật khép kín với sân trong, hồ sen, bãi xe máy, cầu thang ngoài trời, đối diện HUTECH qua đường D1. Toàn bộ 7 màn chơi diễn ra trong chính khuôn viên đó, và chế độ **Thế giới mở** cho bạn đi bộ hoặc chạy xe máy từ toà BE6 ở Vinhomes Grand Park tới trường trên bản đồ thật.

![Menu chính](docs/preview/menu_01_gameplay_cam.png)

| Màn 2 – sân trong & hồ sen | Màn 3 – Lab 402 | Màn 1 – về đích trên D1 |
| :---: | :---: | :---: |
| ![](docs/preview/s2_06_courtyard_pond.png) | ![](docs/preview/s3_01_gameplay_cam.png) | ![](docs/preview/05_finish_both_campuses.png) |

## 🎮 Tải về và chơi ngay (không cần cài Godot)

1. Vào trang **[Releases](../../releases)** và tải file `FPTU-Student-Simulator-windows-*.zip` mới nhất.
2. Giải nén ra một thư mục bất kỳ.
3. Chạy `FPTU-Student-Simulator.exe`. Lần đầu mở có thể chờ vài giây để biên dịch shader.

Yêu cầu: Windows 10/11 64-bit, card đồ hoạ hỗ trợ Vulkan 1.0 (hoặc Direct3D 12). Máy yếu vào **Cài đặt đồ hoạ** trong menu chính để chọn mức Thấp / Trung bình.

> Windows SmartScreen có thể cảnh báo vì file chưa ký số. Chọn *More info → Run anyway*.

## 🗺️ Hành trình một ngày (7 màn)

| Giờ | Màn | Nội dung |
| :--- | :--- | :--- |
| 07:05 | **1 · Đua xe** | Phóng xe máy từ sảnh toà BE6 (Vinhomes Grand Park) theo **đúng tuyến đường thật 5,5 km**: Cầu Vồng 5, Nguyễn Xiển, cầu Rạch Hầm, Nguyễn Văn Tăng, D2B, vòng xoay rồi đường D1 tới cổng FPTU trước 07:30 (5 phút chơi). Drift, núp gió xe buýt, lách sát xe ngược chiều, né ổ gà, dừng đèn đỏ. |
| 07:26 | **2 · Bãi xe & chạy bộ** | Quét thẻ ở cổng bãi xe D1, tranh ô đỗ với xe khác, đỗ cho thẳng, rồi chạy bộ xuyên campus và leo 105 bậc cầu thang ngoài trời lên Lab 402. |
| 07:30 | **3 · Roll call FAP** | Đoán mã điểm danh qua Wi-Fi lag hoặc chờ 4G, rồi sinh tồn trong phòng lạnh 16°C: giữ tỉnh táo, chống đói, trả lời khi bị gọi tên, giấu điện thoại. |
| 09:30 | **4 · Vovinam** | Rhythm game 3 vòng nhanh dần giữa sân trong, hít đất nếu sai nhịp, kết thúc bằng chuỗi Đòn chân kẹp cổ số 21. |
| 11:30 | **5 · Căn tin** | Bưng khay cơm luồn qua biển người áo cam ở căn tin tầng trệt, rồi kéo thả combo 7-Eleven trong ngân sách. |
| 23:00 | **6 · Boss Capstone** | Bullet-hell gõ chữ trong Lab 402 lúc nửa đêm: bắn hạ 404 / NullPointer, gọi dậy đứa seen không rep, resolve Git conflict trước 23:59. |
| 08:00 | **Extra · Giám thị EOS** | Đi tuần phòng thi 311 hoặc xem CCTV, chụp bằng chứng đúng lúc, lập biên bản 5 thánh tool mà không bắt oan. |

Vật phẩm mua ở 7-Eleven (Màn 5) dùng được ở Màn 2 và 3. Kết quả từng màn có rank S/A/B/C và kỷ lục được lưu. Chơi lẻ từng màn: vào **KHÁM PHÁ CAMPUS** rồi tới cột sáng của màn đó, bấm `E`.

## 📖 Cốt truyện TOOL ĐEN – 7 ngày minh oan

Chọn **CỐT TRUYỆN** trong menu chính (đã có bản lưu thì game hỏi *"Ghi đè bản lưu Ngày N?"*).

- **Tạo nhân vật:** chọn giới tính, tên (mặc định "Bạn", tối đa 16 ký tự), khuôn mặt, kiểu tóc, màu tóc, màu da; kéo chuột để xoay nhân vật, `Ngẫu nhiên` nếu lười. Đồng phục cố định: áo polo cam FPT, quần jeans, giày trắng, ba lô đen. Nhân vật này xuất hiện ở mọi nơi: thế giới mở, cinematic, Màn 1 và phòng thi 311.
- **Ngày 0 (chơi trọn được):** tỉnh dậy trước sảnh BE6 → đua xe tới FPTU (Màn 1) → Mr.T nhờ phụ coi thi ở phòng 311, chụp bằng chứng (màn Extra) → về BE6 đi ngủ → nửa đêm có chuyện lạ → cuộc gọi 3 giờ sáng → sáng hôm sau… → tờ lịch "NGÀY 1 · CÒN 7 NGÀY".
- **Ngày 1 "Shipper bóng đêm" (ban đêm, trên bản đồ thật):** gặp Mr.T ở cổng chính → rình ở bãi xe D1 60 giây, đừng để hai bảo vệ và shipper thấy (bị thấy là rình lại từ đầu), đúng lúc giao hàng thì bấm `S` chụp ảnh → đuổi theo Mũ Đỏ qua sân trường, giữ khoảng cách dưới 25 m (coi chừng vỏ chuối) → đánh tay không với 3 shipper ("Gét gô!") → đi qua hành lang tầng trệt tối om… → (tùy chọn) mở tủ đồ bằng chìa khóa Mũ Đỏ đánh rơi để lấy bằng chứng E2 → Phúc thú nhận: **Lựa chọn 1** trong 10 giây (hết giờ thì game chọn giúp) → về BE6 ngủ, cuộc gọi "còn 6 ngày".
- **Ngày 2 và 3** tạm là ngày trống ("sắp có trong bản cập nhật sau"): về BE6 ngủ để sang ngày tiếp.
- **Ngày 4 "Cừu nhân bản":** Linh rủ ra căn tin nằm vùng: bưng khay đi chậm (chạy là rớt khay, bị nghi), tìm Cừu Dolly giữa 12 bản sao giống hệt nhau (nghe tiếng ngân nga hộp nhạc, vòng len màu kem ở cổ tay, móc khóa hình cừu), đứng trước mặt rồi bấm `E` để tố cáo; tố nhầm hay rớt khay thì thanh nghi ngờ tăng, đầy là **BỊ LỘ** → đánh các đợt nhân bản đeo mặt nạ cừu, Dolly bỏ chạy → đêm trong tòa nhà tối: tìm 3 cầu chì, lắp vào hộp điện ở phòng máy phát rồi chạy ra cửa sảnh; không bị bắt lần nào thì lấy được bằng chứng E5 → cuộc gọi "còn 3 ngày". Ngày 5 trở đi sẽ có ở các bản cập nhật sau.
- **Thua nhiệm vụ** hiện "TOANG!" (căn tin là "BỊ LỘ") với nút **THỬ LẠI** (chơi lại từ điểm lưu của nhiệm vụ, cũng có thể bấm `Enter`) hoặc **VỀ THẾ GIỚI MỞ** (cột nhiệm vụ vẫn còn đó). Trong tòa nhà tối, bị bắt thì tự chơi lại từ cầu chì vừa lắp. Nhiệm vụ trong campus chỉ dùng tay không và đi bộ.
- **Đánh tay không (Vovinam):** chuột trái combo 3 đòn · chuột phải đá tạt (phá thế đỡ) · giữ `Q` đỡ (đỡ đúng lúc là phản đòn) · `Space` lăn né khi có địch gần · `E` hạ gục địch đang choáng. Đòn nặng của địch nháy đỏ trước nửa giây: chỉ né được, không đỡ được.
- **Tòa nhà tối:** `F` bật / tắt đèn pin (pin cạn dần, nhặt thêm pin) · `E` trốn vào tủ, buồng vệ sinh, gầm bàn rồi `E` để ra · `Ctrl` đi rón rén (chạy nước rút gây tiếng động).
- **Nhiệm vụ** là cột sáng màu hồng (có chấm trên radar và bản đồ `M`), đứng vào rồi bấm `E`. Đang bị truy nã thì phải cắt đuôi trước. Dòng mục tiêu hiện ở giữa đáy màn hình; ngày hiện dưới ví tiền ("NGÀY 1 · CÒN 7 NGÀY").
- **Điện thoại `P`:** tin nhắn của Mr.T, Phúc, Anh Duy, Số lạ; ô bằng chứng E1–E7 (chưa có thì hiện "???"); nhiệm vụ và số ngày còn lại. `P` hoặc `Esc` để đóng.
- **Lưu và tiếp tục:** game tự lưu khi tạo nhân vật, sau mỗi nhiệm vụ thắng, khi sang ngày mới và khi về menu chính. Nút **TIẾP TỤC – NGÀY N** chỉ hiện khi có bản lưu.
- **"Giảm hù dọa"** (Cài đặt ở menu chính hoặc menu tạm dừng): bỏ tiếng rít và đèn chớp, cuộc gọi 3 giờ sáng không rung / loé, âm thanh kinh dị nhỏ hơn 6 dB.
- **File riêng của bạn (tùy chọn, chỉ trên máy bạn, không bao giờ commit hay đóng gói):** trong thư mục người dùng của game
  - `music\<slot>.ogg` hoặc `.mp3` cho nhạc cinematic: `cine_d0_wake`, `cine_d0_brief`, `cine_d0_exam`, `cine_d0_midnight`, `ai_intro`, `cine_day_start`, `seg_d0_race`, `seg_d0_exam`, `cine_d1_intro`, `cine_d1_corridor`, `cine_d1_choice`, `cine_d1`, `seg_d1_chase`, `seg_d1_brawl`, `cine_d4_intro`, `cine_d4_stare`, `seg_d4_brawl`, `seg_d4_escape`, `cine_d4`;
  - `sfx\<tên>.ogg`, `.mp3` hoặc `.wav` thay âm meme / kinh dị: `boom`, `sad_trombone`, `record_scratch`, `ba_dum_tss`, `bonk`, `dun_dun_duun`, `success_fanfare`, `toang_sting`, `heartbeat`, `breath`, `whisper_bed`, `violin_screech`, `music_box`, `metal_creak`, `sheep_bleat_distorted`, `phone_ring_3am`, `static_burst`;
  - `video\ai_intro_m.ogv` (nhân vật nam) hoặc `video\ai_intro_f.ogv` (nữ): clip mở đầu tự làm, phát thay đoạn dựng trong game (đổi MP4 sang Ogg Theora: `ffmpeg -i in.mp4 -c:v libtheora -q:v 7 -c:a libvorbis -q:a 5 out.ogv`).

Mọi nhân vật đều hư cấu (Mr.T, Phúc, Anh Duy, Linh, Chú Bảy, Cừu Dolly…); không dùng tên, mặt hay giọng người thật, không dùng bài hát có bản quyền. Thời điểm các cú hù / câu thoại của từng cinematic nằm trong `docs/cinematics/<slot>.txt`.

## 🌏 Thế giới mở

Chọn **KHÁM PHÁ CAMPUS** trong menu chính. Bạn xuất phát ngay trước sảnh **toà BE6 (The Beverly, Vinhomes Grand Park)**, bấm `F` lấy xe máy rồi tự chạy **tuyến đường thật 5,5 km** tới campus FPTU (Cầu Vồng 5, Nguyễn Xiển, cầu Rạch Hầm, Nguyễn Văn Tăng, D2B, đường D1), hoặc đi bộ ngắm khu đô thị, kênh đào Hoa giấy, dãy nhà ống hai bên đường. Góc trên phải luôn báo còn bao nhiêu mét tới cổng FPTU.

| Xuất phát ở BE6 | Bản đồ `M` |
| :---: | :---: |
| ![](docs/preview/roam_01_spawn_be6.png) | ![](docs/preview/roam_08_map.png) |

**Điều khiển:** `WASD` chạy bộ · `Shift` chạy nước rút (có thể lực) · `Ctrl` đi bộ · `Space` nhảy (trên xe vẫn là drift) · `Z`/`C` xoay camera · chuột nhìn (bấm chuột để bắt, `ESC` thả) · giữ chuột giữa: vòng vũ khí · chuột phải ngắm, chuột trái bắn, `R` nạp đạn · giữ `B`: vòng biểu cảm · `F` lên/xuống xe máy (khi lái: `W/S` ga/phanh, `A/D` lái, `SPACE` drift, `H` còi) · `E` vào điểm nóng để chơi màn · `T` đổi giờ (bình minh, sáng, trưa, đêm) · `M` bản đồ · `ESC` tạm dừng.

**6 điểm nóng** (cột sáng màu, đứng vào vòng sáng rồi bấm `E`):

| Điểm nóng | Màn chơi |
| :--- | :--- |
| Sân trước sảnh BE6 | Màn 1 · Đua xe trên tuyến thật tới cổng FPTU |
| Cổng sau campus, cạnh bãi xe | Màn 2 · Bãi xe & chạy bộ |
| Cửa kính sảnh thông tầng nhìn ra sân trong | Màn 3 · Roll call FAP ban ngày, **Màn 6 · Boss Capstone** ban đêm (bấm `T` tới Đêm khuya) |
| Đầu sân bóng, ngoài hàng rào | Màn 4 · Vovinam |
| Căn tin tầng trệt | Màn 5 · Căn tin |
| Sân trong, trước phòng 311 | Extra · Giám thị EOS |

Chơi xong một màn mở từ điểm nóng, bảng kết quả có nút **VỀ CAMPUS** để quay lại thế giới mở ngay cạnh điểm nóng đó (Màn 1 đưa bạn về BE6). Bấm *Chơi lại* thì nút này vẫn hiện ở lượt sau. Xe máy đang đỗ hiện trên bản đồ, đi xa thì dòng gợi ý báo xe cách bao nhiêu mét; lỡ rơi xuống kênh thì sau 1 giây bạn được đưa lên chỗ khô gần nhất.

Ở phong cách Vice City, mọi nhân vật là người kiểu PS2: tỉ lệ người thật, đầu ít mặt với gương mặt vẽ tay bằng code (8 biểu cảm), quần áo giữ nguyên. Ở cả hai phong cách, thế giới mở đông người hơn: sinh viên kín sân trường, cư dân dạo phố Vinhomes (có người chạy bộ, người tản bộ), người đi bộ trên lề các tuyến đường, nhìn xa vẫn thấy dòng người; xe máy, ô tô và xe buýt chạy đúng làn bên phải và dừng lại khi có người chắn đường. Ban đêm vắng hơn. Va nhẹ thì người đi đường lảo đảo càu nhàu, chạy nước rút hay đi xe tông thì họ ngã rồi đứng dậy bỏ chạy. Rơi từ cao không mất máu: dưới 2,5 m nhún gối, 2,5-6 m lăn, cao hơn thì nằm một lúc rồi đứng dậy.

**Vũ khí, truy nã và biểu cảm.** Giữ **chuột giữa** để mở vòng chọn vũ khí (game chậm lại, đưa chuột về ô rồi thả; `ESC` hoặc chuột phải để đóng), lăn chuột để đổi nhanh. Tám ô: Tay không, Dao, Súng lục, Shotgun, Tên lửa, Dép tổ ong (ném vòng rồi bay về tay), Sầu riêng (lựu đạn mùi), Loa kẹo kéo (giữ để phát nhạc đẩy người ra). Chuột phải ngắm qua vai, chuột trái bắn, `R` nạp đạn; chỉ dùng khi đi bộ. Không máu me, không ai chết: người trúng đòn nằm sao bay vòng vòng rồi đứng dậy bỏ chạy, xe trúng tên lửa lật ngửa bốc khói. Gây rối thì bị truy nã 1-3 sao: trong campus bảo vệ đuổi (từ 2 sao có cả Mr.T), ngoài đường cảnh sát chạy xe máy tới rồi xuống đuổi bộ; trốn khỏi tầm nhìn đủ lâu thì mất sao (vòng xanh trên radar là vùng đang bị tìm). Bị tóm thì xem đoạn "BỊ TÓM!" rồi đi lao động công ích: mặc áo cam nhặt 8 bao rác bỏ vô thùng trong 120 giây. Giữ **B** để mở vòng biểu cảm: "Siuuu!" chạy đà, nhảy xoay người, tiếp đất dang tay, người xung quanh vỗ tay, hô theo hoặc giơ điện thoại quay.

Bản đồ thế giới mở dựng từ dữ liệu **OpenStreetMap** (© OpenStreetMap contributors, [ODbL](https://www.openstreetmap.org/copyright)) và footprint nhà ống **Microsoft Global ML Building Footprints** (© Microsoft, [CDLA-Permissive-2.0](https://cdla.dev/permissive-2-0/)); trên bản đồ `M`, nhà lấy từ OpenStreetMap tô đậm hơn nhà lấy từ dữ liệu Microsoft.

## 🕹️ Điều khiển

* **Chung:** `M` mở Campaign Hub chọn màn · `ESC` đóng cửa sổ · chuột hoặc `↑↓ Enter` trong menu.
* **Màn 1:** `W` ga · `S` phanh/lùi · `A/D` lái · `SPACE`+`A/D` drift (thả để boost) · `H` còi.
* **Màn 2:** `E` quét thẻ · `H` còi · `S` lùi · pha chạy: `A/D` làn, `SPACE` nhảy, `S` trượt, `SHIFT` sprint, `Q` Monster.
* **Màn 3:** gõ mã + `ENTER` · `TAB` 4G · `SPACE` đúng nhịp · `C` cà phê · `B` bánh bao · `F` úp điện thoại.
* **Màn 4:** `←→↑↓ SPACE` theo nốt · hít đất mash `SPACE` · finisher theo hướng dẫn trên màn hình.
* **Màn 5:** `WASD` đi · `E` tương tác · đứng yên giữ `SPACE` cân khay · kéo thả món vào giỏ.
* **Màn 6:** gõ chữ trên đạn · `TAB` đổi người · `ENTER` skill / gọi điện · `←/→` chọn khối code.
* **Extra:** `WASD` đi tuần (theo hướng camera) · `C` CCTV · `S` chụp · `E` soi / lập biên bản.
* **Cốt truyện (Ngày 1, 4):** đánh tay không: chuột trái combo · chuột phải đá tạt · giữ `Q` đỡ · `Space` lăn né · `E` hạ gục · `S` chụp ảnh khi rình · `E` tố cáo / lấy khay ở căn tin · tòa nhà tối: `F` đèn pin, `E` trốn / ra / nhặt / lắp cầu chì, `Ctrl` đi rón rén · thua nhiệm vụ: `Enter` thử lại.
* **Thế giới mở:** `WASD` chạy bộ · `Shift` chạy nước rút (có thể lực) · `Ctrl` đi bộ · `Space` nhảy (trên xe vẫn là drift) · `Z/C` xoay camera · chuột nhìn · giữ chuột giữa: vòng vũ khí · lăn chuột: đổi vũ khí · chuột phải: ngắm · chuột trái: bắn · `R` nạp đạn · giữ `B`: vòng biểu cảm · `F` lên/xuống xe máy · `E` vào điểm nóng chơi màn · `T` đổi giờ · `M` bản đồ · `ESC` tạm dừng.

## 🛠️ Chạy từ mã nguồn / tự build

Cần [Godot 4.7.2](https://godotengine.org/download) (bản chuẩn, không cần .NET).

```bash
# Chạy game kèm kiểm tra cú pháp + smoke test
run_game.bat

# Build bản Windows đóng gói (cần cài Export Templates 4.7.2 trong Godot Editor)
build_windows.bat
```

Phát hành tự động: push một tag `v*` lên GitHub, workflow `.github/workflows/release.yml` sẽ build bản Windows trên máy chủ GitHub và đính kèm file zip vào Release.

Icon game (Cóc Vàng áo cam) được tạo bằng `generate_icon.py` từ ảnh gốc `assets/icon/source_frog.png`: tách nền, đổi tông màu da và áo, vẽ logo – thuần xử lý ảnh bằng Pillow. Exporter của Godot tự nhúng icon này vào file exe.

Kiểm thử headless (không cần cửa sổ): `tests/smoke_all_stages.gd`, `tests/test_stage*.gd`, `tests/test_main_menu.gd`, `tests/test_free_roam.gd` (thế giới mở), `tests/test_mapdata.gd` / `tests/test_mapbuilder.gd` (bản đồ thật), `tests/test_weapon_wheel.gd` … `tests/test_mayhem_perf.gd` (vũ khí, truy nã, biểu cảm). Chi tiết thiết kế xem [PLAN.md](PLAN.md).

## Cinematic: mocap Mixamo và nhạc (tùy chọn)

- **Mocap:** chạy `tools\import_mixamo.bat` (mặc định lấy file `.fbx` trong `D:\mixamo_fight`, hoặc truyền thư mục khác: `tools\import_mixamo.bat E:\thu_muc_fbx`). File được chép vào `assets\local\mixamo\`; thư mục này bị git bỏ qua và bị loại khỏi bản build. Script tự import bằng Godot rồi in báo cáo retarget (số clip, clip thiếu, clip lỗi). Không có các file này, game dùng clip CC0 của Quaternius hoặc tư thế dựng bằng code.
- **Nhạc:** đặt file `<slot>.ogg` hoặc `<slot>.mp3` vào thư mục `music\` trong thư mục người dùng của game. Đường dẫn chính xác được in ra bởi `godot --headless --path . --script tools/cine_beats.gd` và hiện trong cảnh xem thử cinematic. Tên các slot nằm ở mục 8.3 của `docs/superpowers/specs/2026-10-22-story-tool-den-design.md`. File dài hơn cinematic sẽ nhỏ dần trong 0,5 s cuối; không có file thì game phát nhạc tổng hợp.
- **Xem cinematic `seg_d1_brawl`** (25 s, trận đánh ở cổng sau campus lúc đêm; chỉ dành cho dev):
  - trong thế giới mở (FreeRoam), bấm **F9** (chỉ bản debug); giữ **Esc** 0,8 s để bỏ qua;
  - hoặc chạy `godot --path . res://scenes/dev/CinePreview.tscn`, thêm `CINE_DEBUG=1` để hiện thanh nhịp. **R** phát lại, **F10** bật/tắt thanh nhịp.
  - Nhạc của cinematic này là `seg_d1_brawl.ogg` hoặc `.mp3` trong thư mục `music\` ở trên (bản cắt "I've Gotta Be Me" của chủ dự án: mọi cú đánh rơi đúng nhịp mạnh của bài).
  - Thời điểm các cú đánh và cảnh quay nằm trong `docs/cinematics/seg_d1_brawl.txt` (tạo bằng `tools/cine_beats.gd`, đừng sửa tay).
- **Âm thanh vũ khí / biểu cảm (tùy chọn, chỉ trên máy của bạn):** đặt `<tên>.ogg` (hoặc `.mp3`) vào thư mục `sfx\` trong thư mục người dùng của game để thay âm tổng hợp. Tên: `punch`, `swish`, `knife_hit`, `reload`, `dry_click`, `shot_pistol`, `shot_shotgun`, `pump`, `ricochet`, `rocket_launch`, `explosion`, `bonk`, `dep_whoosh`, `durian_pop`, `cough`, `bolero`, `bag_drop`. Loa kẹo kéo phát `sfx\loa_keo_keo.ogg` hoặc `.mp3` nếu có, không có thì phát nhạc bolero tổng hợp. Tiếng "Siuuu" là `sfx\siuuu.ogg` hoặc `.mp3`, cắt theo bố cục cố định: chữ "S" từ 0,25 s, tiếng hô mạnh nhất ở 0,31 s, ngân tới 1,57 s. Các file này không bao giờ được commit hay đóng gói.
- **Đoạn "BỊ TÓM!"** (`wanted_busted`, 7 s) chạy bằng hệ cinematic; nhạc của nó là `music\wanted_busted.ogg` / `.mp3` nếu có. Thời điểm nằm trong `docs/cinematics/wanted_busted.txt`.

## 🧱 Công nghệ & tư liệu

* Godot 4.7 Forward+, GDScript 100%, không plugin. Đồ hoạ: SDFGI, SSIL, SSR, sương thể tích, bóng mềm; 3 mức chất lượng.
* Khuôn viên dựng bằng code theo footprint thật trên OpenStreetMap và ảnh flycam (`scripts/FPTUCampusBuilder.gd` v8: kích thước khu đất, hướng toà nhà, cổng D1, bãi xe phía sau đúng thực tế), dùng chung cho menu và cả 7 màn.
* Bản đồ thế giới mở (Vinhomes Grand Park quanh toà BE6, tuyến đường thật 5,5 km tới trường, khu Công nghệ cao quanh campus) dựng từ dữ liệu **OpenStreetMap**: © OpenStreetMap contributors, giấy phép [ODbL 1.0](https://www.openstreetmap.org/copyright), cùng footprint nhà của **Microsoft** (© Microsoft, giấy phép [CDLA-Permissive-2.0](https://cdla.dev/permissive-2-0/), chi tiết ở dòng dưới). Dữ liệu gốc lưu ở `reference_data/osm/` (không đóng gói vào game); file đã chuyển đổi `assets/data/mapdata.json` được tạo bằng `tools/osm_to_mapdata.py`. Tên cửa hàng, thương hiệu trên bản đồ đã được đổi tên vui; tên đường, khu vực, trường học giữ nguyên.
* Dãy nhà ống dọc các con đường (khoảng 2 500 căn mà OpenStreetMap chưa vẽ) lấy footprint từ **Microsoft Global ML Building Footprints** © Microsoft, giấy phép [CDLA-Permissive-2.0](https://cdla.dev/permissive-2-0/) (bản trích phạm vi game ở `reference_data/msbuildings/`, gộp vào `mapdata.json` với `"source": "msft"`); `scripts/MapBuilder.gd` dựng chúng thành khối gộp theo ô 128 m, có bồn nước inox trên mái.
* Texture mặt tiền, hồ sen và các bảng ảnh là **ảnh chụp thật** cấp phép Creative Commons từ Wikimedia Commons (nguồn ghi trong [reference_photos/README.md](reference_photos/README.md)). Texture còn lại vẽ bằng code (Pillow). **Không dùng AI tạo ảnh.**
* Âm thanh tổng hợp bằng code.

Tên trường, địa danh và thương hiệu xuất hiện trong game chỉ mang tính mô phỏng vui, không liên kết chính thức với các tổ chức đó.
