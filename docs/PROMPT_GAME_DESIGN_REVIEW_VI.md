# PROMPT: Nhà thiết kế game chuyên nghiệp rà soát và nâng độ "cuốn" cho FPTU Student Simulator

> Dán toàn bộ nội dung dưới đây cho người (hoặc AI) sẽ đóng vai. Phần trong ngoặc vuông là chỗ bạn có thể sửa.

---

## 1. Vai trò của bạn

Bạn là **Lead Game Designer kiêm Technical Designer** với hơn 10 năm làm game indie thương mại thành công trên Steam, từng ship các game theo kiểu arcade-chương hồi và mini-game có nhịp nhanh. Bạn giỏi ba thứ: (1) phân tích vì sao một game "cuốn" dựa trên vòng lặp cốt lõi, nhịp độ và phản hồi; (2) mượn có chọn lọc cơ chế đã được chứng minh từ game khác rồi biến tấu cho đúng chất riêng; (3) viết đặc tả đủ cụ thể, có con số, để lập trình viên làm ngay mà không phải hỏi lại.

Bạn làm việc theo nguyên tắc: **không khen xã giao, không đề xuất chung chung**. Mỗi đề xuất phải trả lời được "người chơi sẽ cảm thấy gì khác đi, đo bằng gì".

## 2. Game bạn sẽ sửa

**FPTU Student Simulator: Đường Đến Trường** – game 3D hài hước mô phỏng một ngày của sinh viên Đại học FPT TP.HCM, làm bằng Godot 4.7 thuần GDScript, không plugin. Toàn bộ 7 màn diễn ra trong một khuôn viên trường được dựng lại theo ảnh flycam thật và bản đồ OpenStreetMap (vòng nhà chữ nhật khép kín, sân trong có hồ sen, bãi xe máy, cầu thang ngoài trời, đối diện HUTECH qua đường D1).

Hành trình hiện tại (mỗi màn 1–2 pha, mỗi pha 35–90 giây):

| Màn | Giờ | Cơ chế cốt lõi hiện có | Lấy cảm hứng từ |
| :-- | :-- | :-- | :-- |
| 1 Đua xe | 07:05 | Lái xe máy 1,9 km trên tuyến đường thật, drift (giữ SPACE + lái, thả để boost), núp gió xe buýt, "lách sát" xe ngược chiều để ăn giây thưởng (chuỗi near-miss), né ổ gà, xe tải hỏng, chó băng qua, dừng đèn đỏ, mưa trơn, 5 checkpoint hài. Thua nếu quá 07:30 | Road Rash, Traffic Rider, Crazy Taxi |
| 2 Bãi xe & chạy bộ | 07:26 | Pha 1: quét thẻ ở barie, chạy vào bãi xe sau nhà, tranh ô đỗ với một xe NPC (còi làm nó khựng), đỗ đúng ô, thẳng, dừng hẳn 0,6 s, có lùi. Pha 2: auto-runner 3 làn theo Path3D xuyên campus lên 105 bậc thang: đổi làn, nhảy, trượt, sprint tốn thể lực, uống Monster | Subway Surfers, Temple Run |
| 3 Roll call FAP | 07:30 | Pha 1: đoán mã điểm danh 6 ký tự bị nhòe do Wi-Fi lag hoặc chờ 5 s bật 4G, sai 3 lần thua. Pha 2: sinh tồn 60 s trong phòng lạnh: bấm đúng nhịp để tỉnh, cà phê, bánh bao khi giảng viên không nhìn, bị gọi tên phải gõ đáp án, úp điện thoại kịp lúc | WarioWare, Papers Please (áp lực chú ý) |
| 4 Vovinam | 09:30 | Rhythm game 3 vòng nhanh dần (85→125 BPM), 5 phím đòn, combo x1–x4, sai nhiều phải hít đất mash SPACE, kết thúc bằng chuỗi finisher 5 bước "Đòn chân kẹp cổ số 21" | Rhythm Heaven, Friday Night Funkin' |
| 5 Căn tin | 11:30 | Pha 1: bưng khay cơm qua đám đông, thanh thăng bằng dao động, va chạm làm lệch, đứng yên giữ SPACE để cân; giao 2 đơn. Pha 2: kéo thả 8 món 7-Eleven vào giỏ trong ngân sách ngẫu nhiên 30k/40k/50k, cần đủ Năng lượng và Tinh thần; Monster/cà phê mua được dùng ở màn khác | Overcooked, Papers Please (mua sắm ràng buộc) |
| 6 Boss Capstone | 23:00 | Bullet-hell gõ chữ: đạn là tên lỗi (404, NullPointer, deadlock...) rơi theo 4 làn ứng với 4 thành viên nhóm; gõ đúng để bắn; combo; skill từng người; gọi dậy thành viên "seen không rep" bằng mash; resolve 3 Git conflict chọn đúng khối; push cuối trước 23:59 | The Typing of the Dead, ZType |
| Extra Giám thị EOS | 08:00 | Đi tuần phòng thi 16 máy hoặc xem CCTV góc trần, 6 thí sinh gian lận có "tell" ngắn 0,85–1,5 s (Alt+Tab, điện thoại sáng dưới bàn, tai nghe, đồng hồ), chụp bằng chứng (8 ảnh), lập biên bản; bắt oan trừ 35 uy tín | Papers Please, Where's Waldo có thời gian |

Hệ thống chung đã có: menu chính nền campus 3D, Campaign Hub chọn màn, rank S/A/B/C mỗi màn, kỷ lục lưu đĩa, vật phẩm xuyên màn (Monster, cà phê, bánh bao), hiệu ứng "juice" (rung màn hình, flash, hit-stop, slow-motion, chữ bay, vignette nhịp tim), SFX tổng hợp bằng code, 3 mức đồ hoạ.

### Điểm yếu đã biết (hãy xác nhận hoặc bác bỏ bằng phân tích của bạn)

- Nhân vật là hình khối (capsule, cầu) nên biểu cảm hài phụ thuộc hoàn toàn vào chữ popup; thiếu animation phản ứng.
- Chưa có nhạc nền; âm thanh chỉ là SFX tổng hợp.
- Giữa các màn không có "móc" khiến người chơi muốn chơi tiếp: không có điểm tổng ngày, không có thành tựu, không có lý do chơi lại ngoài rank.
- Độ khó mới chỉ cân bằng bằng bot tự động (bot thắng với 8–12 giây dư), chưa qua tay người chơi thật.
- Mỗi màn dạy cách chơi bằng một dòng chữ dài trên HUD; không có onboarding bằng hành động.
- Pha mua sắm 7-Eleven dùng chuột kéo thả trong khi cả game dùng bàn phím.
- Chuyển cảnh giữa màn là cắt thẳng, chưa có "đoạn nghỉ" kể chuyện.

## 3. Ràng buộc bắt buộc (không được vi phạm)

1. Godot 4.7, GDScript thuần, không C#, không plugin, không asset mua ngoài.
2. **Tuyệt đối không dùng AI tạo ảnh/âm thanh.** Ảnh tham chiếu phải là ảnh chụp thật có giấy phép; texture 2D vẽ bằng code (Pillow); âm thanh tổng hợp bằng code hoặc ghi âm thật.
3. Giữ nguyên cấu trúc thư mục `scenes/ scripts/ assets/ tests/ docs/`, tên file scene và `class_name` các màn, đường dẫn texture mặt tiền `fptu_alpha_facade.png`.
4. Khuôn viên phải tiếp tục đúng kiến trúc thật (không được biến thành khối trừu tượng cho tiện).
5. Mọi thay đổi phải qua được: `godot --headless --quit --check-only --path .`, `tests/smoke_all_stages.gd`, và các bot test `tests/test_stage*.gd`, `tests/test_main_menu.gd`. Nếu đổi cơ chế làm bot cũ không còn đúng, phải cập nhật bot kèm theo.
6. Mỗi pha chơi giữ trong 45–90 giây; cả hành trình 7 màn dưới 15 phút.
7. HUD dùng anchors/containers chuẩn Godot, không toạ độ cứng.
8. Hài hước phải đúng văn hoá sinh viên FPT (FAP, slot, EOS, Capstone, cóc vàng, áo cam, 7-Eleven, Vovinam là môn bắt buộc) và không xúc phạm cá nhân thật.

## 4. Việc bạn phải làm, theo đúng thứ tự

### Bước 1 – Đọc để hiểu thật (không bỏ qua)
Đọc `README.md`, `PLAN.md` (đặc biệt mục III, IV, VI, VII), `docs/superpowers/specs/2026-10-20-gameplay-redesign-design.md`, rồi lướt `scripts/` của từng màn và `scripts/GameFX.gd`, `scripts/StageManager.gd`. Chạy `run_game.bat` và chơi thử từng màn ít nhất 2 lần. Ghi lại cảm xúc thật theo từng 10 giây: chỗ nào hồi hộp, chỗ nào chán, chỗ nào không hiểu phải làm gì, chỗ nào thua mà thấy bất công.

### Bước 2 – Chẩn đoán theo khung "cuốn"
Với mỗi màn, chấm 1–5 và giải thích ngắn trên 6 trục:
- **Vòng lặp cốt lõi** (hành động → phản hồi → quyết định tiếp theo có diễn ra dưới 3 giây không?)
- **Nhịp độ** (có đỉnh và nghỉ, hay đều đều?)
- **Rủi ro – phần thưởng** (người chơi có được chọn "tham hay an toàn" không?)
- **Đọc được tình huống** (nhìn là biết nguy hiểm ở đâu, không cần đọc chữ)
- **Phản hồi/juice** (trúng đòn, thắng, thua có đã tay không?)
- **Hài** (tiếng cười đến từ tình huống hay chỉ từ câu chữ?)

Xếp hạng 7 màn từ yếu nhất đến mạnh nhất. Nêu màn nào đáng được đầu tư nhất vì nó là ấn tượng đầu tiên (Màn 1) hoặc là cao trào (Màn 6).

### Bước 3 – Tham khảo game khác một cách có kỷ luật
Với mỗi màn, nêu **đúng 2 game tham chiếu**, và với mỗi game chỉ ra **một cơ chế cụ thể** đáng mượn, kèm lý do nó hợp với bối cảnh sinh viên FPT. Ví dụ dạng mẫu: "Crazy Taxi – hệ 'Crazy Through' thưởng thời gian khi lách sát xe. Game đã có near-miss nhưng thưởng cố định; mượn cách Crazy Taxi hiện chuỗi và nhân thưởng tăng dần để người chơi chủ động lách nhiều hơn." Ngoài danh sách gợi ý ở bảng trên, bạn được tự chọn, miễn là giải thích. Cấm mượn nguyên xi tên gọi, nhân vật, tài sản của game khác.

Ngoài từng màn, đề xuất **một hệ thống xuyên suốt** mượn từ game có vòng lặp meta tốt (Hades, Vampire Survivors, Overcooked, Peglin, Balatro... tuỳ bạn) để trả lời câu hỏi: "Vì sao chơi xong một ngày người ta muốn chơi lại ngày thứ hai?" Gợi ý hướng, không bắt buộc: điểm "GPA ngày", thử thách hàng ngày với seed cố định, bộ sưu tập meme/thành tựu kiểu "Cóc Vàng", bảng xếp hạng nội bộ, modifier (ngày thi, ngày mưa, ngày có kiểm tra bất ngờ).

### Bước 4 – Danh sách thay đổi ưu tiên
Trình bày tối đa **12 thay đổi**, sắp theo tỉ lệ "tác động lên độ cuốn / công sức". Mỗi mục theo đúng khuôn:

```
#N  Tên ngắn
Màn/hệ thống ảnh hưởng:
Vấn đề hiện tại (dẫn chứng từ lúc chơi thử):
Thay đổi cụ thể (con số, phím, thời lượng, điều kiện thắng/thua):
Cảm giác người chơi mong đợi sau khi sửa:
Game tham chiếu và cơ chế mượn:
Công sức: S / M / L (S < 2 giờ, M < 1 ngày, L vài ngày)
Rủi ro và cách đo (test bot nào cần sửa, số liệu mục tiêu, ví dụ "bot trung bình thắng với 5–8 s dư, người chơi lần đầu thua 40–60%")
```

Ít nhất 3 mục phải là loại S có thể làm trong ngày. Ít nhất 1 mục phải giải quyết onboarding bằng hành động (dạy bằng tình huống an toàn trong 10 giây đầu thay vì chữ).

### Bước 5 – Đặc tả chi tiết cho 3 thay đổi đầu bảng
Với 3 mục ưu tiên nhất, viết đặc tả đủ để lập trình viên làm ngay: trạng thái và chuyển trạng thái, công thức tính điểm, bảng tham số (giá trị hiện tại → giá trị đề xuất, kèm lý do), thay đổi HUD (mô tả bố cục bằng container của Godot), SFX/juice cần thêm (mô tả bằng lời để tổng hợp bằng code), và **tiêu chí nghiệm thu** có thể kiểm tra bằng bot headless hoặc bằng người chơi thật.

### Bước 6 – Kế hoạch playtest
Thiết kế một buổi playtest 30 phút với 3–5 sinh viên: thứ tự màn, câu hỏi hỏi sau mỗi màn (tối đa 3 câu, tránh câu hỏi dẫn dắt), số liệu cần ghi (thời gian hoàn thành, số lần thua, chỗ dừng tay, câu người chơi tự thốt ra), và ngưỡng quyết định giữ hay bỏ từng thay đổi.

## 5. Định dạng đầu ra

- Viết bằng tiếng Việt, xưng "tôi", giọng thẳng thắn của người trong nghề.
- Dùng tiêu đề theo đúng 6 bước trên; bảng cho phần chấm điểm; khuôn cố định cho danh sách thay đổi.
- Mọi con số đề xuất phải có lý do. Không viết "tăng tính hấp dẫn" mà không nói tăng bằng cách nào.
- Nếu phải đánh đổi giữa "cuốn hơn" và "đúng thực tế hơn", hãy nêu rõ hai phương án và khuyến nghị một.
- Kết thúc bằng mục "Điều tôi chưa chắc" liệt kê giả định cần kiểm chứng bằng playtest.

## 6. Ví dụ mức chi tiết mong đợi (để hiệu chuẩn, không phải đáp án)

"Màn 2 pha chạy bộ hiện dài 221 m với 24 chướng ngại đặt đều, người chơi vào nhịp sau 15 giây rồi không còn gì mới. Mượn Subway Surfers cách 'sự kiện giữa đường': tại checkpoint sảnh chính (giây ~25) thả một nhóm 6 sinh viên đi ngang chắn cả 3 làn trong 1,2 giây buộc phải nhảy qua lan can (phím mới SPACE giữ lâu = nhảy xa), và cho phép ăn 'ly Passio' trên đường để hồi 30 thể lực. Mục tiêu: nhịp tim tăng ở giây 25–35, tỉ lệ dùng sprint tăng từ hiếm lên 2–3 lần mỗi lượt. Đo bằng bot `tests/test_stage2_stairs.gd`: thêm nhánh xử lý nhảy xa, bot vẫn thắng với 6–9 giây dư."

---

[Tuỳ chọn thêm cho người nhận: "Hãy bắt đầu bằng Bước 1 và 2, gửi tôi bản chẩn đoán trước khi viết đề xuất, để tôi xác nhận bạn đã hiểu đúng game."]
