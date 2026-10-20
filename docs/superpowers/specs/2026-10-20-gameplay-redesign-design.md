# FPTU Student Simulator — Đề xuất thiết kế lại gameplay v2 (chờ duyệt)

Ngày: 2026-10-20. Trạng thái: **ĐÃ DUYỆT & ĐÃ TRIỂN KHAI** (phương án A cho Màn 2, bỏ phím nhảy ở Màn 1, Overcooked + kéo thả ở Màn 5, Tab/Enter ở Màn 6, thêm `docs/` và `tests/`). Khác biệt so với đề xuất khi triển khai: Màn 1 tăng thời gian lên 100s và tốc độ tối đa 81 km/h để lái sạch vừa kịp; Màn 2 pha 2 rút còn 42s; Màn 5 đổi bảng giá (mì 10k, bánh bao 8k, xúc xích 5k, Monster 18k, Sting 7k, trà 5k, cà phê 10k, kẹo 2k) và mục tiêu ⚡≥50 / 🧠≥30 để ngân sách 30k có đúng một lời giải; Màn 6 boss 1.600 HP, sát thương = độ dài × 6 × combo (x1→x3); near-miss dùng Area3D gắn trên xe NPC vì Jolt không cho Area3D thấy StaticBody3D. Chi tiết cập nhật trong `PLAN.md`.

Ràng buộc giữ nguyên: Godot 4.2+ GDScript thuần, không plugin; giữ tên scene/class_name; giữ cấu trúc `scenes/ scripts/ assets/ reference_photos/`; texture ảnh thật (`fptu_*.png`, `lotus_pond_real.png`, `fptu_alpha_facade.png`) giữ nguyên và tiếp tục dùng; texture 2D mới chỉ tạo bằng Pillow/code; không AI gen ảnh.

---

## 0. Hiện trạng đọc được từ code (baseline 2026-10-20)

| Màn | Điều code đang làm | Vấn đề cụ thể |
|---|---|---|
| 1 | 90s, đường ~1.930m, tốc độ tối đa 75 km/h, núp gió 92 km/h. `Space` = **NHẢY** (`PlayerBike.gd` dòng 71, 485), không phải drift như PLAN.md. Audio đã nạp đúng (đã xác minh header WAV 44 byte). | Không có sự kiện nào; group `pothole` được kiểm tra va chạm (dòng 508) nhưng **không có ổ gà nào được spawn**. Traffic chỉ 8 xe buýt StaticBody, không có xe ngược chiều để lách. Có thể leo gờ 1.1m rồi chạy trên cỏ tới 35m mới bị cứu hộ. |
| 2 | 45s **chung cho cả 2 pha**. Ô đỗ cố định, chỉ cần chạm Area3D là tính đỗ (không cần dừng, không cần thẳng xe). Không có lùi xe. Pha 2 là 3 dốc ramp ẩn dưới bậc thang + CharacterBody3D. | Pha 1 không có áp lực. Pha 2 phụ thuộc physics dốc; stamina chỉ đổi tốc độ sprint. |
| 3 | 40s. `_on_submit_fap_pressed` chấp nhận **mọi mã** khi đã bật 4G (`or is_using_4g`, dòng 111). Quiz 1 câu cố định, đáp án luôn A. | Gõ mã vô nghĩa; không có Wi-Fi lag thật; sinh tồn = bấm cà phê không giới hạn. |
| 4 | 5 lệnh cố định, không có timing, bấm đúng phím là qua. Finisher = 1 thanh lực, >60% là thắng. | Không có nhịp, không có combo, không có animation thật. |
| 5 | Thanh cân bằng random walk + 2 nút mua. Camera tĩnh, không di chuyển. | Gần như không có gameplay. |
| 6 | 4 nút skill, boss 1.200 HP, về 250 HP hiện nút Resolve, bấm là thắng. Công thức đồng hồ sai (`55 + (50-remain)/10`). | Không có trận chiến thật. |
| Extra | 16 máy, 5 gian lận cố định `[1,4,7,10,13]`, E rồi Space. Nút biên bản bị disable khi vô tội nên **không thể bắt nhầm**. | Không có hệ thống điểm, không có rủi ro, không tăng độ khó. |
| Chung | 3 bản copy `_load_wav_stream`; 7 bản copy modal/nút chuyển màn; StageManager không lưu inventory hay kết quả; `test_report.txt` báo test cũ lỗi. | Thiếu nền tảng dùng chung và smoke test cho toàn bộ scene. |

---

## 1. Nền tảng dùng chung (làm trước)

**`scripts/GameFX.gd`** (autoload `GameFX`): screen shake cho camera đang active, hit-stop ngắn (`Engine.time_scale`), floating text 3D (`Label3D` bay lên rồi mờ), flash overlay toàn màn, vignette nhịp tim, WAV loader dùng chung, `play_sfx(path)` đơn giản. Lý do: 7 màn đều cần cùng bộ "juice", tránh 7 bản copy.

**`StageManager` mở rộng**: `inventory: Dictionary` (monster, coffee, banh_bao), `run_stats` (thời gian, điểm, rank từng màn), `report_stage_result(stage_id, dict)`, `has_item()/consume_item()`. Lý do: tạo liên mạch giữa các màn (đồ mua ở 7-Eleven dùng ở Màn 2 và Màn 6 của vòng chơi sau; Màn 2 có lon Monster nhặt tại chỗ cho lần chơi đầu).

**`tests/smoke_all_stages.gd`**: chạy headless, `load()` + `instantiate()` cả 7 scene, tick 60 frame mỗi scene, thoát mã lỗi nếu có script error. Chạy sau mỗi thay đổi cùng `godot --headless --quit --check-only`.

**HUD**: panel mới dùng `MarginContainer` + anchors preset (`TOP_WIDE`, `CENTER_BOTTOM`, `FULL_RECT`), không offset tuyệt đối. Panel cũ sửa khi chạm tới.

---

## 2. Màn 1 — Đua xe Vinhomes → Cổng FPTU

### Thay đổi
1. **`Space` = Drift thật** (bỏ nhảy). Giữ Space + A/D: bán kính cua giảm ~35%, tốc độ chỉ tụt ~15% thay vì phanh gấp; khói bánh sau (`CPUParticles3D`), `tire_skid.wav` loop khi drift. Drift ≥ 0,7s rồi thả → mini-boost +4 m/s trong 1s + `slipstream_boost.wav`. Xe Wave không nhảy; ổ gà né bằng lái.
2. **Near-miss**: `Area3D` hộp 2 bên xe (1,4m). Xe NPC đi qua mà không va, tốc độ > 50 km/h → "SÁT NÚT! +0,5s" (trừ `elapsed_sec` của HUD). Chuỗi x2, x3 → +1s. Trần +8s/màn.
3. **Sự kiện trên đường** (`RoadEvents` sinh theo offset `Path3D`, một phần random mỗi lượt):
   - Ổ gà Nguyễn Xiển: 6–8 cái random trong 230–760m, group `pothole` (code va chạm đã sẵn), chạm → -40% tốc + shake.
   - Xe tải đỗ chắn 1 làn: 2 vị trí, làn random → buộc đổi làn.
   - Chó chạy qua đường: 1 lần, `Area3D` di chuyển ngang; đâm → "ĐÂM TRÚNG CHÓ CÔ BA! +3s".
   - Đèn đỏ ngã ba trước Cầu Trau Trảu: vàng 1,5s → đỏ 4s. Vượt → "CSGT HUÝT CÒI +4s"; dừng đúng → qua. Đây là nhịp "nín thở" giữa màn.
   - Mưa trơn Đại lộ D2 (50%): `steer_speed` ×0,75, drift dễ văng, overlay giọt mưa 2D + fog tăng.
   - Xe máy ngược chiều: `TrafficSpawner` thêm ~10 xe máy nhỏ làn trái, nhanh hơn buýt → nguồn near-miss chính.
4. **Lane clamping**: nếu khoảng cách tới tim đường > 6,9m → đẩy ngang về phía tim đường mỗi frame + giảm tốc; > 8,0m → đặt lại ở mép đường + phạt 1s. Áp dụng cả cầu và bùng binh. Hết chuyện chạy trên cỏ tới 35m.
5. **Checkpoint hài**: 5 cổng `Label3D` + banner HUD: "Qua Cầu Trau Trảu rồi! Vành Đai 3 xây 10 năm chưa xong!", "Bùng binh kìa! Đi VÒNG, đừng đi THẲNG!", "HUTECH bên trái, đừng rẽ nhầm trường!".
6. **Juice**: speed lines (`ColorRect` + shader `canvas_item` vạch tỏa tâm, alpha theo tốc độ), vignette > 80 km/h, shake va chạm tăng khi đâm xe tải.
7. **Thời gian**: giữ 90s, bonus near-miss/drift tạo cảm giác "thiếu chút nữa".

### Vì sao vui hơn
Hiện tại kết quả = giữ W + núp gió. Sau thay đổi cứ 10–15s có 1 quyết định (đổi làn, drift hay phanh, dừng đèn hay vượt) và có thưởng cho chơi liều.

---

## 3. Màn 2 — Bãi xe D1 & Leo tầng

### Pha 1 — Đỗ xe (35s riêng)
- **Bác bảo vệ càu nhàu**: bong bóng thoại `Label3D` mỗi 7s nếu chưa quét thẻ/chưa đỗ: "Nhanh lên em, 7h29 rồi!", "Đỗ kiểu gì vậy trời!".
- **Xe NPC cạnh tranh**: 1 xe máy NPC xuất phát cùng lúc, chạy waypoint tới ô trống. NPC vào trước → ô bị chiếm, ô mới sáng ở góc xa hơn (3 ô ứng viên). Bấm còi `H` khi gần → NPC giật mình dừng 1,5s.
- **Ô đỗ khó + đỗ hợp lệ**: ô kẹp giữa 2 xe, lối vào 1,6m. Thêm **lùi xe** (giữ S khi tốc độ 0 → lùi 3 m/s). Điều kiện đỗ: toàn thân xe trong Area, tốc độ < 0,8 m/s trong 0,6s, góc lệch < 25°. Đỗ lệch → "ĐỖ LỆCH! Đỗ lại!" (mất thời gian, không fail).
- **Risk/Reward Monster**: lon Monster phát sáng ở quầy 7-Eleven cạnh sảnh (lệch đường 4–5s). Chạm → có 1 Monster cho pha 2. Nếu `StageManager.inventory` đã có từ Màn 5 vòng trước thì khỏi nhặt.

### Pha 2 — Leo tầng (50s)
**Phương án A (khuyến nghị): Auto-runner 3D theo `Path3D`.** Runner tự chạy dọc một `Path3D` đi qua 3 đợt cầu thang + chiếu nghỉ hiện có; vị trí lấy từ `PathFollow3D.progress`, **không dùng va chạm sàn** → hết kẹt physics tận gốc. Người chơi: `A/D` đổi 3 làn, `Space` nhảy qua xe đẩy dọn vệ sinh / vũng nước, `S` trượt cúi dưới bảng thông báo CLB / ô của cô, `Shift` sprint tốn stamina. Chướng ngại: sinh viên áo cam chạy ngược (đổi làn), thầy cô đi chậm (vượt), xe đẩy (nhảy), biển sàn ướt (trượt). Va → vấp 1s, -15 stamina, shake. Camera third-person phía sau, vẫn thấy Hồ Sen và tòa nhà giật cấp. Giữ nguyên mesh cầu thang đã dựng.

**Phương án B: 2.5D side-scroll** nhìn ngang tòa VTN. Lạ mắt hơn nhưng phải dựng lại view ngang, mất bối cảnh 3D đang có. Chi phí cao hơn A ~1,5 lần.

**Stamina có nghĩa**: sprint -24/s. Về 0 → "HỤT HƠI" 2,5s: tốc độ -50%, không nhảy được, vignette đỏ nhịp 2 Hz, HUD rung, tiếng tim. `Q` uống Monster → đầy ngay + 3s sprint miễn phí.

**Mốc tầng**: `Label3D` + chime `checkpoint_bell.wav` mỗi chiếu nghỉ; đích Lab 402.

### Vì sao vui hơn
Runner trên path cho nhịp liên tục, loại bỏ bug physics là lý do chính pha này "tệ"; stamina thành tài nguyên phải quản lý thay vì thanh trang trí.

---

## 4. Màn 3 — FAP & Sinh tồn 16°C

### Pha 1 — Điểm danh (45s)
- Mã FAP 6 ký tự **ngẫu nhiên** hiện trên màn chiếu (`Label3D` đè lên texture `fap_portal_screen.png`).
- **Wi-Fi lag thật**: mỗi 0,35s có 3–4 ký tự bị thay bằng `▒` / ký tự nhiễu + vòng tròn loading; người chơi phải đoán hoặc chờ ký tự lộ ra.
- `TAB` bật 4G: thanh "Đang chuyển mạng… 5s" (khóa nhập); xong thì mã rõ nét.
- **Giảng viên đổi mã sau 20s** ("Lộ mã lên group lớp rồi, đổi!") → mã cũ gửi lên bị sai.
- **Sửa bug**: chỉ chấp nhận đúng mã. Sai → khóa 2s; 3 lần sai → Absent.

### Pha 2 — Sinh tồn (60s), nhiều việc cùng lúc
- **Buồn ngủ** +6/s. Vòng tròn nhịp tim trên HUD co giãn; bấm `Space` đúng nhịp (±120 ms) → -8; sai nhịp → +3 (gật gù). `C` cà phê -15, **chỉ 3 ly**.
- **Đói** +3/s. > 70 → mỗi 4s bụng kêu ("ỤC ỤC" + tiếng) → thanh **Giảng viên để ý** +15. `B` ăn bánh bao lén -40 đói; nếu giảng viên đang nhìn (đèn đỏ trên HUD) → để ý +30.
- **Gọi tên bất ngờ** (2 lần): `LineEdit` gõ đáp án ngắn trong 8s, pool 6 câu, ví dụ "SOLID chữ S?" → `single`; "HTTP 404?" → `not found`; "lệnh git lấy code về?" → `pull`. So khớp không phân biệt hoa thường, có alias. Sai → để ý +25, buồn ngủ +15.
- **Kiểm tra điện thoại** (1–2 lần): giảng viên đi dọc dãy (mesh di chuyển), cảnh báo 1,5s "📱 ÚP ĐIỆN THOẠI [F]!" → kịp thì ổn; trễ → tịch thu, để ý +40.
- Thua: buồn ngủ 100 (ngủ gục) hoặc để ý 100 (bị mời ra ngoài).

### Vì sao vui hơn
Pha 1 là "đoán mã dưới áp lực mạng lag" thay vì gõ 6 ký tự; pha 2 juggle 2 thanh + 2 sự kiện, đúng tinh thần "không lúc nào ngồi không".

---

## 5. Màn 4 — Vovinam

- **Rhythm lane**: nốt (icon phím) chạy từ phải sang trái vào vùng Hit. 3 round: 85 BPM × 8 nốt, 110 × 10, 135 × 12 (~45s). Judgement Perfect ±70 ms / Good ±150 ms / Miss. Combo multiplier x1→x4, điểm hiển thị. 3 Miss liên tiếp → **"HÍT ĐẤT 10 CÁI"**: mash `Space` 10 lần trong 4s rồi tiếp tục. Round 3 cần ≥ 70% Good trở lên mới vào finisher.
- **Animation capsule thật**: đấm = thân lao tới 0,4m + tay vung; chém = xoay thân 45°; tấn = hạ 0,3m; đá = chân xoay 80°; hét = scale pulse + `Label3D` "ÁAAA!". Nộm giật lùi + flash trắng khi Perfect. Thêm capsule thầy võ hô bằng `Label3D`.
- **Finisher chuỗi 5 bước** (đồng hồ 30s; sai bước → ngã, làm lại từ bước 1, mất 3s):
  1. giữ `W` 1,2s nạp đà (nhân vật chạy về nộm),
  2. `Space` khi vòng tròn co vào vạch vàng,
  3. `←→` luân phiên 6 lần trong 2s (xoay người),
  4. `Space` lần 2 đúng timing kẹp,
  5. `↓` quật.
- **Cinematic**: `time_scale` 0,3 trong 1,2s, camera tween zoom + orbit 90°, flash + shake, nộm ngã có bounce.

### Vì sao vui hơn
Timing + combo tạo skill curve; finisher thành chuỗi khiến "trượt bước 4" là cảm giác "suýt nữa, chơi lại".

---

## 6. Màn 5 — Căn tin & 7-Eleven

### Pha 1 — Bưng khay kiểu Overcooked (60s)
- Nhân vật đi được (`CharacterBody3D`, WASD, camera chéo từ trên). Lấy khay ở quầy (`E`) → đi tới bàn có bạn vẫy (`Label3D` "ĐÂY NÈ!!" + mũi tên).
- 12–14 NPC áo cam đi waypoint cắt ngang, 2–3 nhóm đứng tụ chặn lối.
- **Thanh nghiêng khay**: trôi theo tốc độ; va NPC → giật ±25 + tiếng; đứng yên giữ `Space` 0,4s để cân lại. 3 cú va liên tiếp không cân → đổ cơm, quay lại quầy (mất ~6s).
- Giao 2 đơn: cơm tấm (bàn gần), ly trà đá (bàn xa, NPC đông hơn).

### Pha 2 — 7-Eleven combo puzzle (35s)
- Ngân sách random 30k / 40k / 50k. 8 món kéo thả bằng drag-and-drop chuẩn Godot (`_get_drag_data / _can_drop_data / _drop_data`):

| Món | Giá | Năng lượng | Tinh thần |
|---|---|---|---|
| Indomie trộn | 12k | +30 | 0 |
| Bánh bao trứng cút | 10k | +20 | 0 |
| Xúc xích | 7k | +10 | 0 |
| Monster | 25k | 0 | +40 (+ item cho màn sau) |
| Sting dâu | 10k | 0 | +20 |
| Trà xanh | 8k | 0 | +10 |
| Cà phê lon | 15k | -5 | +30 |
| Kẹo cao su | 3k | +3 | 0 |

- Mục tiêu: Năng lượng ≥ 60 **và** Tinh thần ≥ 40, không vượt ngân sách. Tổng tiền cập nhật realtime; vượt → thu ngân từ chối.
- Mua Monster → `StageManager.inventory` (dùng ở Màn 2 / Màn 6).

Phương án thay thế (game nhớ order đứng sau quầy): **không chọn**, vì người chơi là sinh viên mua đồ, không phải nhân viên; đổi vai sẽ gãy mạch truyện.

### Vì sao vui hơn
Pha 1 có không gian và va chạm thật thay vì thanh random; pha 2 là bài toán nhỏ có nhiều lời giải thay vì bấm 2 nút.

---

## 7. Màn 6 — Boss Capstone 23:59

- **Bullet-hell typing** (90s, 23:57:30 → 23:59): boss phóng "viên đạn lỗi" (`Label` trong Control, trôi từ trên xuống 4 làn ứng 4 thành viên): `404`, `500`, `null`, `NPE`, `CORS`, `typo`, `lag`, `merge`, `leak`, `OOM`, `regex`. Gõ ký tự → đạn khớp prefix sáng lên; gõ xong → nổ, sát thương boss = độ dài từ × hệ số combo. Đạn chạm đáy → thành viên làn đó mất HP. 3 wave tăng tốc và mật độ.
- **4 thành viên có HP riêng**. `Tab` đổi thành viên đang điều khiển; `Enter` dùng skill có cooldown (số và chữ đều nằm trong từ nên không dùng phím 1–4):
  - Leader (10s): xóa toàn bộ đạn đang khớp một phần.
  - Frontend (12s): khiên chặn 3 đạn ở làn mình.
  - Tester (15s): đóng băng đạn 2,5s.
  - Seen-không-rep: ban đầu **NGỦ**, làn này không tự vệ. `Enter` khi chọn → minigame gọi điện: mash `Space` ≥ 14 lần trong 4s cho đến "📞 Bắt máy rồi!" → thức dậy, mở skill "git merge" hồi 150 HP cho team.
- **Boss 40% HP → Pha Git Conflict**: 3 xung đột liên tiếp, mỗi xung đột hiện 2 khối code (HEAD vs nhánh đồng đội) + gợi ý ("bản nào gọi đúng `submitCapstone()`?"), chọn `←` / `→` trong 8s. Sai → team -100 HP; đúng → boss -15%. Xong 3 → gõ `git push origin main` để kết liễu.
- Thắng: boss 0 HP trước 23:59. Thua: 2 thành viên 0 HP hoặc hết giờ. Pháo hoa particles + Cóc Vàng.

### Vì sao vui hơn
Gõ phím là kỹ năng sinh viên IT nên hợp chủ đề; áp lực realtime thay cho bấm 4 nút theo lượt; đồng đội ngủ là nguy cơ thật phải xử lý.

---

## 8. Extra — Giám thị EOS

- 90s, 16 máy, **6 thánh tool random mỗi lượt**, cần bắt 5. Uy tín khởi điểm 100.
- **Camera**: `C` đổi giữa đi tuần (như hiện tại) và **CCTV top-down** (`Camera3D` orthogonal trên trần, viền "REC ●", nhiễu nhẹ). CCTV thấy cả phòng nhưng không zoom chi tiết.
- **Hành vi "tell" có cửa sổ thời gian**: cheater làm động tác mỗi 6–10s, kéo dài 1,5s → 0,8s theo độ khó. Sinh viên ngay thẳng cũng có "nhiễu" (vươn vai, gãi đầu) không phải vi phạm.
  - Cấp 1 (0–30s): Alt+Tab lộ liễu, màn hình nháy sang màu khác 1,5s.
  - Cấp 2 (30–60s): điện thoại dưới bàn, `OmniLight3D` xanh nhấp nháy gầm bàn 1,2s.
  - Cấp 3 (60–90s): tai nghe bluetooth (đầu nghiêng + chấm trắng 0,9s) / Apple Watch (cổ tay sáng 0,8s).
- **Quy trình bằng chứng**: khi ở gần (≤ 4m) hoặc đang ở CCTV và rê chuột trúng máy, bấm `S` chụp. Tell đang diễn ra → "BẰNG CHỨNG #n: Máy 07, ánh sáng điện thoại" vào sổ; không → ảnh trống (tốn 1 trong 8 slot). `E` tại máy → bảng đối chiếu bằng chứng với Quy chế thi (Điều 1 Alt-Tab, Điều 2 thiết bị, Điều 3 liên lạc) → "Lập biên bản" chỉ bật khi có ≥ 1 bằng chứng của đúng máy đó.
- **Thưởng phạt**: bắt đúng +100 điểm. Ép lập biên bản không bằng chứng (`Shift+Space`) với người vô tội → Uy tín -35; uy tín ≤ 0 → "Bị Phòng Khảo thí đình chỉ coi thi". Kết thúc xếp hạng S/A/B theo điểm và uy tín.

### Vì sao vui hơn
Có vòng quan sát → ghi nhận → đối chiếu, có rủi ro bắt nhầm, độ khó leo thang thay vì bấm E rồi Space.

---

## 9. Thứ tự triển khai & kiểm thử

1. Nền tảng: `GameFX`, `StageManager` inventory, `tests/smoke_all_stages.gd`.
2. Màn 2 pha 2 (điểm đau lớn nhất) → Màn 1 → Màn 3 → Màn 4 → Màn 6 → Màn 5 → Extra.
3. Mỗi màn: code → `godot --headless --quit --check-only` + smoke test → báo cáo kèm output.
4. Cập nhật `PLAN.md` mục IV cho các màn đổi cơ chế lớn (2, 5, 6, Extra) sau khi xong.

Ước lượng: ~700–1.000 dòng GDScript mới/đổi mỗi màn lớn (1, 2, 6), ~400–600 dòng cho các màn còn lại.

---

## 10. Quyết định cần chốt trước khi code

1. Màn 2 pha 2: **A** auto-runner 3D theo Path3D (khuyến nghị) hay **B** 2.5D side-scroll?
2. Màn 1: bỏ hẳn phím nhảy để `Space` = drift? (khuyến nghị: bỏ)
3. Màn 5: chốt Overcooked + kéo thả (khuyến nghị) hay đổi sang game nhớ order?
4. Màn 6: `Tab` đổi người + `Enter` dùng skill vì chữ số nằm trong từ "404"? (khuyến nghị: đồng ý)
5. Cho phép thêm `docs/` (spec này) và `tests/` (smoke test), không đụng `scenes/ scripts/ assets/`?
