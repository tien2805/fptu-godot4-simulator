# Rà soát thiết kế: làm FPTU Student Simulator "cuốn" hơn

*Vai: Lead Game Designer / Technical Designer. Ngày 2026-10-20. Căn cứ: đọc toàn bộ mã nguồn, chạy 9 bot test, 3 bộ ảnh render, 2 phiên giả lập người chơi theo từng phím. Tôi nói rõ ở cuối những gì tôi chưa chắc vì chưa có người thật cầm bàn phím.*

---

## Bước 1 – Nhật ký chơi thử (theo lát 10 giây, lấy từ log bot và ảnh chụp từng bước)

Tôi không có tay người để "cảm" theo nghĩa đen, nên tôi dùng ba nguồn thay thế và ghi lại những gì chúng phơi bày: log autopilot từng 300 frame, ảnh chụp cửa sổ game theo từng bước phím, và đọc tham số trong code. Những dòng dưới là sự kiện thật, không phải cảm nhận bịa.

**Màn 1 – Đua xe (ngân sách 104 s, autopilot về đích 91–92 s)**
- 0–20 s: chỉ lái thẳng. Ổ gà rơi ngẫu nhiên ở 240–750 m (giây 12–36), chó băng qua ở 470 m (giây 22). Không có xe ngược chiều nào trong tầm lách.
- 33–40 s: đèn đỏ ở 778 m. Đây là "sự kiện" đầu tiên buộc phải làm gì đó khác ngoài giữ ga.
- 57 s: lần "sát nút" đầu tiên (log: `frame 4200: offset 1163 m, nearmiss=2`). Nghĩa là cơ chế được quảng cáo là hay nhất của màn chỉ xuất hiện ở 45% cuối chặng. Tổng cả chặng: 5 lần sát nút, 0 lần drift boost của bot.
- 88–92 s: về đích. Không có cú chốt nào ngoài biển "đích".

**Màn 2 – Bãi xe & chạy bộ (55 s + 48 s)**
- 0–8 s: 28 m trên D1 rồi rẽ vào cổng, bị chặn cho tới khi bấm E. Khoảnh khắc tốt: luật được dạy bằng việc bị chặn.
- 8–22 s: 95 m đường thẳng ven cánh nhà, không có gì để làm ngoài giữ W.
- 22–40 s: tranh ô. Xe NPC đi 4,6 m/s, tới ô sau khoảng 30 s; người lái bình thường thắng dễ, người lạc đường thua hẳn. Nhị phân, ít kịch tính.
- Pha chạy: 221 m, 24 chướng ngại cách đều theo tỉ lệ quãng đường. Bot: 1 lần vấp, 8 lần né, dư 10 s. Ảnh chụp cho thấy nhịp vào guồng sau khoảng 15 s rồi đều đều tới cầu thang. Cầu thang 105 bậc là đoạn đẹp nhất nhưng không khác gì đoạn phẳng về cơ chế.

**Màn 3 – Roll call FAP (45 s + 60 s)**
- Pha 1: chiến thuật tối ưu là bấm TAB rồi chờ 5 s, gõ 6 ký tự, xong. Đoán mã nhòe chỉ là cách thua nhanh hơn. Một pha 45 s mà hành động có nghĩa chỉ kéo dài 8 s.
- Pha 2: 4 thanh chạy cùng lúc (buồn ngủ, đói, chú ý của giảng viên, nhịp). Nhịp 0,8 s với cửa sổ 0,12 s là 15%, khá gắt. Log bot cuối màn: đói chạm 100 mà không có hậu quả rõ rệt ngoài con số đỏ. Thanh nào cũng là chữ và vạch, không có gì trong cảnh 3D thay đổi theo.

**Màn 4 – Vovinam (3 vòng + finisher 30 s)**
- Vòng 1–3 chỉ có 8/10/12 nốt ở 85/110/135 BPM: tổng thời gian chơi nhạc thật chỉ khoảng 20 s. Bot: 24 perfect, 6 miss, 1 lần hít đất. Finisher 5 bước là đoạn kịch tính nhất của cả game về mặt dàn dựng (camera cắt, hit-stop) nhưng người chơi học thuộc chuỗi phím chứ không "đọc" đối thủ.

**Màn 5 – Căn tin (60 s + 35 s)**
- Khi tôi để bot đi đường thẳng qua giữa hiên, nó va 14–15 lần trong một lượt vì NPC đổi hướng không báo trước và vạch thăng bằng trôi ngẫu nhiên (drift đổi chiều mỗi 0,8–1,6 s). Người chơi sẽ cảm thấy "đổ cơm vì game chứ không phải vì mình".
- Pha 7-Eleven: bài toán ngân sách thiết kế tốt (30k có đúng một lời giải), nhưng là màn duy nhất bắt cầm chuột, ngay sau 60 s dùng bàn phím.

**Màn 6 – Boss Capstone (90 s)**
- 3 đợt ở giây 0/30/60, đạn rơi 6,5 → 5,0 → 3,8 s mỗi làn. Bot gõ 21 từ, 1 lỗi, hạ boss ở khoảng giây 52, resolve 2/3 conflict. Đây là vòng lặp chặt nhất của game: gõ xong là thấy ngay kết quả. Thiếu: không có quyết định nào ngoài gõ nhanh hơn; skill 4 người dùng theo cooldown chứ không theo tình huống.

**Extra – Giám thị (90 s)**
- Tell chỉ 0,85–1,5 s, cách nhau 5–9,5 s, loại tell khó mở khoá dần ở giây 0/25/50. Bot bắt 5 người ở giây 31 (có 1 lần bắt oan cố ý). Cảm giác "rình" là có thật và CCTV là lựa chọn chiến thuật đúng nghĩa. Điểm yếu: 30 giây đầu người chơi mới chưa biết tell trông thế nào nên chụp phí ảnh.

**Toàn cục**
- Giữa các màn là cắt đen. Không có điểm tổng của ngày, không có lý do nào để chơi lại ngoài chữ S/A/B/C.
- Không có nhạc. Trong 15 phút chơi, tai chỉ nghe tiếng bíp tổng hợp.

## Bước 2 – Chẩn đoán theo khung "cuốn" (1 = kém, 5 = rất tốt)

| Màn | Vòng lặp | Nhịp độ | Rủi ro–thưởng | Đọc tình huống | Phản hồi | Hài | Tổng |
| :-- | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
| 1 Đua xe | 4 | 2 | 4 | 4 | 4 | 2 | 20 |
| 2 Bãi xe & chạy | 3 | 3 | 3 | 4 | 3 | 3 | 19 |
| 3 FAP | 2 | 2 | 2 | 2 | 3 | 3 | 14 |
| 4 Vovinam | 4 | 3 | 3 | 3 | 5 | 3 | 21 |
| 5 Căn tin | 3 | 3 | 3 | 2 | 3 | 4 | 18 |
| 6 Boss Capstone | 5 | 4 | 3 | 4 | 5 | 4 | 25 |
| Extra Giám thị | 4 | 4 | 5 | 3 | 3 | 3 | 22 |

Giải thích ngắn các điểm thấp:
- Màn 1 nhịp độ 2: 20 s đầu trống, cơ chế hay nhất xuất hiện muộn. Hài 2: 5 checkpoint hài là chữ bay qua ở 80 km/h, không ai đọc kịp.
- Màn 3 gần như thấp đều: pha 1 có lời giải trội (TAB rồi chờ), pha 2 là bốn đồng hồ chạy song song, mắt phải đọc HUD thay vì nhìn lớp học.
- Màn 5 đọc tình huống 2: NPC không có tín hiệu trước khi đổi hướng, vạch thăng bằng trôi ngẫu nhiên.
- Extra phản hồi 3: chụp đúng chỉ có flash trắng; lập biên bản đúng chưa có "cú chốt" tương xứng với công rình.

**Xếp hạng từ yếu đến mạnh:** Màn 3 → Màn 5 → Màn 2 → Màn 1 → Màn 4 → Extra → Màn 6.

**Nên đầu tư vào đâu nhất:** Màn 1, vì nó là 100 giây đầu tiên quyết định người ta có chơi tiếp hay không, và vì khung xương (drift, núp gió, sát nút, sự kiện đường) đã đủ tốt, chỉ sai ở chỗ đặt và ở cách cho điểm. Màn 6 đã là cao trào tốt, chỉ cần thêm lựa chọn. Màn 3 cần sửa cấu trúc nhưng chi phí cao hơn, xếp sau.

## Bước 3 – Tham chiếu có kỷ luật (đúng 2 game mỗi màn, 1 cơ chế mỗi game)

**Màn 1**
- *Crazy Taxi* – chuỗi "Crazy Through" hiện to giữa màn hình và nhân thưởng tăng dần. Game đã đếm chuỗi sát nút nhưng thưởng phẳng và hiển thị nhỏ; người chơi không "săn" sát nút vì không thấy nó đáng.
- *Burnout 3* – thanh boost nạp bằng lái liều (đi làn ngược chiều, sát nút) và người chơi tự chọn lúc xả. Hợp vì sinh viên FPT muộn giờ đúng là kiểu "liều để kịp slot"; nó gộp drift, núp gió và sát nút vào một tài nguyên duy nhất dễ hiểu.

**Màn 2**
- *Subway Surfers* – sự kiện giữa đường theo kịch bản và vật phẩm xếp thành vệt chỉ làn tối ưu. Giải quyết nhịp đều đều của 24 chướng ngại cách đều.
- *Mario Kart* – đối thủ co giãn tốc độ (rubber-band) để cuộc đua luôn sát nút ở 5 m cuối. Xe NPC tranh ô hiện tại đi tốc độ cố định nên kết quả nhị phân.

**Màn 3**
- *Keep Talking and Nobody Explodes* – thông tin bị chia đôi giữa hai nguồn, người chơi phải ghép. Thay "đoán hoặc chờ 4G" bằng: màn chiếu hiện 3 ký tự, tin nhắn Zalo của đứa bạn trên điện thoại hiện 3 ký tự còn lại, nhưng điện thoại phải giấu khi giảng viên quay xuống. Pha 1 thành 45 s hành động liên tục thay vì 8 s.
- *WarioWare* – không bao giờ quá một yêu cầu tại một thời điểm, mỗi yêu cầu là một động từ in to và một nhịp đếm 4 phách. Thay bốn đồng hồ song song bằng chuỗi vi tình huống: "GIẤU!", "GẬT ĐẦU!", "ĂN LẸ!", "TRẢ LỜI!".

**Màn 4**
- *Rhythm Heaven* – gọi–đáp: thầy làm mẫu một ô nhịp, trò lặp lại; tín hiệu âm thanh là chính, hình ảnh là phụ. Hợp với lớp Vovinam thật (thầy hô, trò đáp) và cho phép nhắm mắt vẫn chơi được.
- *Punch-Out!!* – đối thủ có "tell" trước mỗi đòn, người chơi đọc tell rồi phản đòn. Áp cho finisher: thay chuỗi 5 phím học thuộc bằng 5 tell của nộm/đối thủ, mỗi tell ứng một phím.

**Màn 5**
- *Overcooked* – bảng đơn hàng có đồng hồ riêng từng đơn và tiền tip theo tốc độ; nhiều đơn cùng lúc tạo quyết định lộ trình. Hiện chỉ có 1 đơn một lúc nên không có gì để cân nhắc.
- *Slay the Spire* – cửa hàng điều hướng hoàn toàn bằng phím/tay cầm, thẻ hiện giá và lợi ích rõ, chọn là xong. Thay kéo thả chuột.

**Màn 6**
- *The Typing of the Dead* – độ khó đến từ hình dạng từ (dài hơn, có ký tự đặc biệt, cụm nhiều từ) chứ không chỉ từ tốc độ rơi; đạn "boss" là cả câu. Đợt 3 hiện chỉ nhanh hơn.
- *Vampire Survivors* – mỗi mốc là một lựa chọn 1 trong 3 nâng cấp. Áp vào lúc chuyển đợt (giây 30, 60): chọn một buff cho nhóm. Skill 4 thành viên sẽ thành "build" chứ không chỉ là nút cooldown.

**Extra**
- *Hitman* – tầm nhìn bản năng (Instinct) có giới hạn và NPC đổi hành vi khi bị nhìn chằm chằm. Thí sinh gian lận sẽ dừng tell nếu giám thị đứng trong 2,5 m quá 1,5 s; buộc người chơi đi tuần theo nhịp hoặc dùng CCTV đúng lúc, tạo trò mèo vờn chuột.
- *Papers Please* – mỗi "ca thi" mở thêm một điều luật và có bản tin ngắn giải thích. Lần đầu bắt được một kiểu gian lận thì mở khoá thẻ "hồ sơ thủ đoạn" kèm ảnh bằng chứng, giải quyết 30 s mù đầu màn.

**Hệ thống xuyên suốt (mượn Hades)**
Hades biến mỗi lượt chơi thành một câu chuyện có tổng kết và cho người chơi tự tăng độ khó bằng "Pact of Punishment" để đổi phần thưởng. Áp dụng: **GPA của ngày** (quy rank từng màn ra điểm 4.0, tổng kết cuối ngày bằng một màn riêng, lưu kỷ lục, hiện ở menu) và **Thử thách học kỳ** (bật tuỳ chọn như "trời mưa cả ngày", "Wi-Fi chết hẳn", "giảng viên khó tính" để nhân điểm). Nó trả lời câu hỏi "vì sao chơi ngày thứ hai": để kéo GPA lên và thử ngày khó hơn, mà không cần thêm nội dung mới.

## Bước 4 – Danh sách thay đổi ưu tiên (12 mục, theo tác động/công sức)

```
#1  Dồn "sát nút" lên đầu chặng + chuỗi nhân thưởng hiện to
Màn/hệ thống ảnh hưởng: Màn 1 (TrafficSpawner, HUDManager, PlayerBike)
Vấn đề hiện tại: log autopilot cho thấy lần sát nút đầu tiên ở giây 57 (1163 m); 20 s đầu không có gì ngoài giữ ga; thưởng sát nút phẳng, trần 8 s.
Thay đổi cụ thể: xe ngược chiều rải thành 6 cụm tại 180, 320, 480, 640, 900, 1250 m (hiện tập trung sau 1100 m). Thưởng theo chuỗi: lần 1 +0,5 s, lần 2 +0,75 s, lần 3 trở đi +1,0 s, chuỗi ngắt nếu 6 s không có sát nút hoặc va chạm; trần tổng thưởng 8 s giữ nguyên nhưng hiện thanh "còn X s thưởng có thể lấy". Chữ "SÁT NÚT x3!" cỡ 56 giữa màn hình kèm hit-stop 0,04 s.
Cảm giác mong đợi: trong 15 s đầu đã có một pha thót tim; người chơi chủ động dí sát xe ngược chiều thay vì tránh.
Game tham chiếu: Crazy Taxi – chuỗi Crazy Through hiện to, nhân thưởng tăng.
Công sức: S
Rủi ro và cách đo: test_stage1_race và test_near_miss phải cập nhật vị trí; mục tiêu bot: sát nút đầu tiên trước giây 15, tổng 6–9 lần, về đích 88–95 s; người chơi lần đầu thua 30–50% (hiện ước tính dưới 20%, quá dễ).
```

```
#2  Cửa hàng 7-Eleven điều khiển bằng bàn phím
Màn/hệ thống ảnh hưởng: Màn 5 pha 2
Vấn đề hiện tại: màn duy nhất bắt cầm chuột, ngay sau 60 s dùng WASD; kéo thả trên máy yếu dễ trượt.
Thay đổi cụ thể: lưới 4x2 thẻ món; mũi tên di chuyển con trỏ (viền vàng), Enter thêm vào giỏ, Backspace bỏ món cuối, Space thanh toán khi đủ điều kiện, Tab nhảy sang giỏ để bỏ món cụ thể. Giữ kéo thả cho ai thích chuột. Tổng tiền/năng lượng/tinh thần cập nhật từng phím kèm tiếng "tick".
Cảm giác mong đợi: liền tay, không phải với sang chuột; quyết định mua nhanh hơn nên 35 s trở nên căng đúng kiểu "sắp vào lớp".
Game tham chiếu: Slay the Spire – cửa hàng điều hướng bằng phím.
Công sức: S
Rủi ro và cách đo: test_stage5_canteen thêm nhánh mua bằng phím (hiện bot gọi hàm add_to_basket); mục tiêu: bot hoàn tất giỏ hợp lệ trong dưới 12 s chỉ bằng phím.
```

```
#3  Bảng tổng kết ngày: GPA, danh hiệu, kỷ lục
Màn/hệ thống ảnh hưởng: toàn cục (StageManager, scene mới DaySummary, MainMenu)
Vấn đề hiện tại: thắng Màn 6 xong là hết, không có số nào gom cả ngày lại; menu chỉ hiện rank lẻ từng màn.
Thay đổi cụ thể: sau Màn 6 (hoặc Extra nếu chơi) hiện màn tổng kết: 7 thanh điểm chạy lần lượt 0,4 s/thanh, GPA = trung bình (S=4.0, A=3.5, B=3.0, C=2.0, thua=0) của 6 màn chính + 0,2 nếu Extra đạt A trở lên, trần 4.0. Danh hiệu: ≥3.6 "Cóc Vàng xuất sắc", ≥3.2 "Giỏi", ≥2.5 "Khá", còn lại "Học lại học phần". Lưu GPA tốt nhất, menu hiện "GPA kỷ lục". Nút "Sao chép bảng điểm" đưa văn bản vào clipboard để khoe nhóm chat.
Cảm giác mong đợi: có một con số để so với bạn bè và với chính mình; lý do rõ ràng để chơi lại ngày mới.
Game tham chiếu: Hades – tổng kết cuối lượt và động lực chạy lại.
Công sức: M
Rủi ro và cách đo: test headless mới test_day_summary.gd (nạp scene với run_stats giả, kiểm tra GPA và danh hiệu); playtest: ít nhất 3/4 người tự nhắc tới GPA sau khi chơi xong.
```

```
#4  Dạy chơi Màn 1 bằng 10 giây "khởi động" thay vì một dòng chữ
Màn/hệ thống ảnh hưởng: Màn 1 (RoadEvents, HUDManager)
Vấn đề hiện tại: luật drift, núp gió, sát nút nằm trong một dòng HUD dài; log bot cho thấy 0 drift boost cả chặng, tức là cơ chế này gần như vô hình.
Thay đổi cụ thể: 0–120 m là đoạn an toàn không tính giờ (đồng hồ bắt đầu ở 120 m): một xe buýt đỗ hờ để núp gió (chữ 3D "GIỮ SÁT ĐUÔI BUÝT" trên đường), một khúc cua nhẹ có vạch "GIỮ SPACE + A" vẽ xuống mặt đường, hai xe máy chậm để lách. Hoàn thành cả 3 thì nhận "+2 s khởi động tốt". Không làm cũng không phạt.
Cảm giác mong đợi: người mới hiểu 3 cơ chế bằng tay trong 10 s; người cũ lấy 2 s thưởng.
Game tham chiếu: Celeste – dạy bằng phòng an toàn trước khi phạt; Burnout 3 – thanh boost nạp bằng hành vi liều.
Công sức: M
Rủi ro và cách đo: test_stage1_race cập nhật mốc; mục tiêu: 80% người chơi lần đầu thực hiện được ít nhất 1 drift boost trong chặng (hiện gần 0).
```

```
#5  Thẻ chuyển cảnh 3 giây giữa các màn
Màn/hệ thống ảnh hưởng: StageManager.change_stage, dùng lại camera menu
Vấn đề hiện tại: cắt đen giữa các màn, mất cảm giác "một ngày liền mạch" là lời hứa của game.
Thay đổi cụ thể: lớp phủ 3 s: đồng hồ số nhảy từ giờ màn trước sang giờ màn sau (07:26 → 07:30), một câu thoại ngắn theo kết quả (thắng S: "Giảng viên còn chưa tới, ngồi ghế đầu luôn"; thua: "Lần sau nhớ đặt báo thức"), nền là một shot camera campus phù hợp (đã có hệ shot của menu). Bấm phím bất kỳ để bỏ qua.
Cảm giác mong đợi: nhịp thở giữa hai pha căng; câu chuyện ngày học rõ hơn; chỗ để cài hài mà người chơi đọc kịp.
Game tham chiếu: Hades – đoạn hội thoại ngắn giữa các phòng; WarioWare – thẻ chuyển màn 2 s.
Công sức: S
Rủi ro và cách đo: smoke và test_main_menu giữ nguyên; đo bằng playtest: không ai bấm bỏ qua trước 1,5 s.
```

```
#6  Căn tin công bằng hơn: tín hiệu trước va chạm, bỏ trôi ngẫu nhiên, nhiều đơn cùng lúc
Màn/hệ thống ảnh hưởng: Màn 5 pha 1
Vấn đề hiện tại: bot đi thẳng va 14–15 lần/lượt; vạch thăng bằng trôi ngẫu nhiên đổi chiều mỗi 0,8–1,6 s nên đổ cơm không do lỗi người chơi.
Thay đổi cụ thể: NPC hiện dấu "!" 0,4 s và quay đầu trước khi đổi hướng; bỏ trôi ngẫu nhiên, độ nghiêng chỉ tăng theo tốc độ đi (0 khi đứng yên, +22°/s khi chạy hết tốc) và theo va chạm (+28°); bảng đơn Overcooked: 3 đơn cùng lúc, mỗi đơn 25 s, giao trong 15 s đầu được tip x1.5. Thời lượng pha giữ 60 s, cần giao 3/4 đơn để qua.
Cảm giác mong đợi: đổ cơm là do mình tham chạy; chọn giao đơn nào trước là quyết định thật.
Game tham chiếu: Overcooked – bảng đơn có đồng hồ và tip; Crossy Road – chướng ngại luôn báo trước.
Công sức: M
Rủi ro và cách đo: test_stage5_canteen cập nhật bot đọc dấu "!"; mục tiêu bot: dưới 4 va chạm/lượt, giao 3 đơn; người chơi thua 30–45%.
```

```
#7  Pha sinh tồn Màn 3 theo kiểu WarioWare: một yêu cầu một lúc
Màn/hệ thống ảnh hưởng: Màn 3 pha 2
Vấn đề hiện tại: 4 đồng hồ song song, mắt dán vào HUD; đói chạm 100 không có hậu quả.
Thay đổi cụ thể: bộ điều phối phát tối đa 1 yêu cầu chính + 1 yêu cầu nền (nhịp tỉnh táo). Mỗi yêu cầu: banner động từ cỡ 48 ("GIẤU ĐIỆN THOẠI!", "ĂN LẸ!", "TRẢ LỜI!", "GẬT ĐẦU!") + đếm 4 phách + 2,5–4 s để làm; thất bại thì giảng viên chú ý +25 và có phản ứng trong cảnh 3D (bước lại gần 1 m, bong bóng thoại). Đói 100 → bụng kêu: chú ý +15 và nhân vật ôm bụng 1 s. Số yêu cầu: 10 trong 60 s, mật độ tăng dần.
Cảm giác mong đợi: nhìn vào lớp học thay vì nhìn vạch; mỗi 6 s có một tiếng cười hoặc một cú thót.
Game tham chiếu: WarioWare – một động từ, một nhịp đếm; Papers Please – áp lực chú ý từ nhân vật có mặt trong cảnh.
Công sức: M
Rủi ro và cách đo: test_stage3_classroom viết lại theo bộ điều phối; mục tiêu bot: qua với 1–2 lỗi; người chơi thua 35–50%.
```

```
#8  Pha điểm danh Màn 3 thành ghép thông tin
Màn/hệ thống ảnh hưởng: Màn 3 pha 1
Vấn đề hiện tại: lời giải trội là TAB rồi chờ 5 s; 37 s còn lại vô nghĩa.
Thay đổi cụ thể: màn chiếu hiện 3 ký tự rõ, 3 ký tự nhòe hẳn; bấm TAB lật điện thoại thấy tin nhắn Zalo của bạn có 3 ký tự còn lại nhưng xen 2 ký tự nhiễu phải loại theo quy tắc hiện trên bảng ("bỏ chữ O và số 0"); giảng viên quay xuống mỗi 6–9 s, điện thoại đang mở lúc đó là bị tịch thu (mất kênh thông tin, phải đoán). Sai 3 lần vẫn thua. Thời lượng 45 s giữ nguyên.
Cảm giác mong đợi: căng từ giây đầu, có khoảnh khắc "suýt bị bắt"; thành công đến từ tay nhanh và nhớ quy tắc.
Game tham chiếu: Keep Talking and Nobody Explodes – thông tin chia đôi; Papers Please – đối chiếu quy tắc dưới áp lực.
Công sức: M
Rủi ro và cách đo: test_stage3_classroom cập nhật; mục tiêu bot: gửi đúng mã trong 20–30 s; người chơi gửi đúng lần đầu 50–60%.
```

```
#9  Màn 2: đối thủ co giãn tốc độ + sự kiện giữa đường chạy + vệt vật phẩm chỉ làn
Màn/hệ thống ảnh hưởng: Màn 2 cả hai pha
Vấn đề hiện tại: xe NPC tốc độ cố định 4,6 m/s nên kết quả nhị phân; đường chạy 24 chướng ngại cách đều, bot vào guồng sau 15 s.
Thay đổi cụ thể: NPC = tốc độ người chơi x0,92 khi dẫn trước, x1,08 khi tụt lại, kẹp trong 3,5–6 m/s; còi làm nó khựng 1,6 s nhưng cooldown 6 s hiện trên HUD. Pha chạy: tại checkpoint sảnh (giây ~25) nhóm 6 sinh viên băng ngang 3 làn trong 1,2 s buộc nhảy xa (giữ SPACE 0,3 s); 12 ly Passio xếp thành vệt chỉ làn an toàn, mỗi ly +8 thể lực.
Cảm giác mong đợi: cuộc đua ô luôn kết thúc trong gang tấc; đoạn chạy có một cú ngoặt ở giữa thay vì đều đều.
Game tham chiếu: Mario Kart – rubber-band; Subway Surfers – sự kiện giữa đường và vệt vật phẩm.
Công sức: M
Rủi ro và cách đo: test_stage2_stairs thêm nhánh nhảy xa; mục tiêu bot: thắng với 6–9 s dư (hiện 10 s); tỉ lệ bị cướp ô ở người chơi 40–55%.
```

```
#10  Màn 6: chọn 1 trong 3 nâng cấp lúc chuyển đợt + độ khó theo hình dạng từ
Màn/hệ thống ảnh hưởng: Màn 6
Vấn đề hiện tại: chỉ có một cách chơi là gõ nhanh hơn; đợt 3 chỉ nhanh hơn chứ không khác.
Thay đổi cụ thể: ở giây 30 và 60 game dừng 2 s, hiện 3 thẻ (ví dụ: "Code review: đạn làn mình rơi chậm 20%", "Pair programming: 2 làn kế nhau dùng chung từ", "Deadline extension: +5 s", "Caffeine: từ 4 ký tự trở xuống tự nổ"), chọn bằng 1/2/3. Đợt 3 đổi hình dạng từ: 30% đạn là cụm có ký tự đặc biệt ("null->ptr", "i:=0", "git rebase -i"), gõ đúng được x2 sát thương.
Cảm giác mong đợi: mỗi lượt có "build" riêng để kể lại; đợt 3 thách thức ngón tay theo cách mới.
Game tham chiếu: Vampire Survivors – chọn 1/3 mỗi mốc; The Typing of the Dead – độ khó theo hình dạng từ.
Công sức: M
Rủi ro và cách đo: test_stage6_capstone chọn thẻ 1 tự động; mục tiêu bot: hạ boss ở giây 55–70 (hiện 52); từ có ký tự đặc biệt không làm tỉ lệ gõ sai của bot vượt 10%.
```

```
#11  Vovinam: gọi–đáp theo âm thanh, vòng dài gấp rưỡi, finisher đọc tell
Màn/hệ thống ảnh hưởng: Màn 4
Vấn đề hiện tại: 8/10/12 nốt là chỉ 20 s nhạc thật; nốt chỉ là hình trượt trên vạch; finisher là chuỗi phím học thuộc.
Thay đổi cụ thể: metronome click tổng hợp + mỗi nốt có "tiếng hô" khác nhau (5 tông cho 5 đòn) phát sớm đúng một ô nhịp (gọi), người chơi bấm ở ô kế (đáp); số nốt 12/16/20 ở 85/110/135 BPM (tổng ~45 s); finisher: nộm/đối thủ làm 5 tell có hình (ngả vai trái, nhấc chân phải...) mỗi tell 0,9 s, bấm đúng phím ứng với tell; sai 1 tell được làm lại tell đó một lần.
Cảm giác mong đợi: bấm theo tai như lớp võ thật; finisher là "đọc đối thủ" chứ không phải nhớ bài.
Game tham chiếu: Rhythm Heaven – gọi–đáp; Punch-Out!! – tell trước đòn.
Công sức: M
Rủi ro và cách đo: test_stage4_vovinam cập nhật số nốt và tell; mục tiêu bot: perfect ≥ 70%, 1 lần hít đất; người chơi hoàn thành finisher lần đầu 60–70%.
```

```
#12  Extra: nghi ngờ khi bị nhìn chằm chằm + hồ sơ thủ đoạn mở khoá
Màn/hệ thống ảnh hưởng: Extra
Vấn đề hiện tại: 30 s đầu người mới chụp phí vì chưa biết tell; đứng cạnh một máy là chiến thuật trội.
Thay đổi cụ thể: thí sinh gian lận dừng tell khi giám thị đứng trong 2,5 m quá 1,5 s (icon mắt nhỏ trên đầu); CCTV không gây nghi ngờ nhưng chỉ bật tối đa 8 s rồi nghỉ 4 s. Lần đầu bắt một kiểu gian lận mở "hồ sơ thủ đoạn" (thẻ góc màn hình mô tả tell bằng hình vẽ code), hồ sơ lưu qua các lần chơi. Lập biên bản đúng: slow-motion 0,6 s, còi, thí sinh gục mặt xuống bàn.
Cảm giác mong đợi: nhịp tuần tra có chiến thuật; lần chơi sau hiểu biết tích luỹ; bắt đúng sướng tay hơn.
Game tham chiếu: Hitman – NPC phản ứng khi bị nhìn, tầm nhìn bản năng có giới hạn; Papers Please – luật mở dần kèm bản tin.
Công sức: M
Rủi ro và cách đo: test_stage_extra_eos giữ kịch bản dịch chuyển; mục tiêu bot: vẫn bắt 5 trong 90 s; người chơi lần đầu bắt 3–4, lần hai bắt 5.
```

Ngoài 12 mục trên, nhạc nền là thiếu sót lớn nhưng tôi không xếp vào danh sách vì ràng buộc "không AI, không mua" buộc phải tổng hợp bằng code hoặc tự thu âm; đó là việc L và cần người có tai nhạc. Tôi ghi ở phần cuối.

## Bước 5 – Đặc tả chi tiết cho 3 mục đầu

### #1 Dồn "sát nút" lên đầu + chuỗi nhân thưởng

**Trạng thái chuỗi (trong PlayerBike / HUDManager)**
- `chain = 0`, `chain_timer = 0`. Khi tín hiệu near_miss phát: `chain += 1`, `chain_timer = 6.0`. Mỗi frame `chain_timer -= delta`; về 0 thì `chain = 0` và HUD hiện "CHUỖI ĐỨT" mờ 0,6 s. Va chạm (crash) đặt `chain = 0` ngay.
- Thưởng mỗi lần: `bonus = [0.5, 0.75, 1.0][min(chain, 3) - 1]`; cộng vào tổng thưởng với trần 8 s như cũ. Khi đạt trần, vẫn hiện chuỗi và đếm cho điểm xếp hạng nhưng không cộng giây.

**Bảng tham số**

| Tham số | Hiện tại | Đề xuất | Lý do |
| :-- | :-- | :-- | :-- |
| Vị trí cụm xe ngược chiều | tập trung sau ~1100 m | 180, 320, 480, 640, 900, 1250 m (mỗi cụm 2–3 xe, cách nhau 25–40 m) | sát nút đầu tiên trước giây 15 |
| Thưởng sát nút | phẳng | 0,5 / 0,75 / 1,0 s theo chuỗi | săn chuỗi đáng hơn tránh |
| Thời gian giữ chuỗi | không có | 6 s | đủ để đi từ cụm này sang cụm kế ở 80 km/h (khoảng 130 m) |
| Trần thưởng | 8 s | 8 s | giữ cân bằng 104 s |
| Hit-stop khi sát nút | không | 0,04 s ở chuỗi ≥ 3 | nhấn khoảnh khắc mà không phá nhịp lái |

**HUD**: trong TopBar hiện có, thêm một PanelContainer căn giữa (CENTER_TOP, margin 92) chứa VBox: Label "SÁT NÚT x3" cỡ 40 màu vàng FPT, ProgressBar 10 px thể hiện `chain_timer / 6`. Panel ẩn khi `chain == 0`, hiện với tween scale 1,2 → 1,0 trong 0,12 s mỗi lần tăng chuỗi. Dòng thống kê phía dưới thêm "CHUỖI DÀI NHẤT: N".

**Âm thanh/juice**: tiếng "whoosh" cao dần theo chuỗi (pitch 1,0 / 1,15 / 1,3); chữ bay "+0.75s" tại vị trí xe vừa lách; ở chuỗi ≥ 3 viền màn hình loé vàng 0,15 s.

**Điểm xếp hạng**: cộng `longest_chain * 60` vào điểm Màn 1; ngưỡng rank S nâng từ 1100 lên 1250 để S đòi hỏi ít nhất một chuỗi 3.

**Nghiệm thu**: (1) test_near_miss: xe ngược chiều đặt ở 180 m phải được phát hiện; (2) test_stage1_race: sát nút đầu tiên tại frame < 900 (15 s), tổng sát nút 6–9, chuỗi dài nhất ≥ 2, về đích 88–95 s, 0 va chạm; (3) smoke sạch; (4) playtest: ít nhất 3/4 người nhắc tới "lách xe" khi được hỏi điều nhớ nhất của Màn 1.

### #2 Cửa hàng 7-Eleven bằng bàn phím

**Trạng thái**: `focus_idx` (0–7) trên lưới 4x2; `focus_zone` ∈ {SHOP, BASKET}; `basket_idx`.

**Phím**: ← → ↑ ↓ di chuyển `focus_idx` trong lưới (bọc vòng theo hàng); Enter thêm món đang trỏ (gọi add_to_basket như kéo thả); Backspace bỏ món cuối giỏ; Tab đổi `focus_zone`; trong BASKET ↑ ↓ chọn món, Enter/Delete bỏ món đó; Space = nút thanh toán (chỉ khi `pay_btn.disabled == false`, ngược lại tiếng "error" và lắc panel 0,2 s). Chuột và kéo thả giữ nguyên.

**Hiển thị**: thẻ đang trỏ có StyleBox viền vàng 3 px, scale 1,04; dòng tổng ở đáy đổi màu đỏ khi vượt ngân sách, xanh khi đủ hai chỉ tiêu; mỗi lần thêm/bỏ phát "tick"/"pop". Gợi ý phím hiện một dòng dưới tiêu đề: "←→↑↓ chọn · Enter thêm · Backspace bỏ · Space trả tiền".

**Tham số**: không đổi giá, ngân sách, chỉ tiêu. Thời lượng 35 s giữ nguyên; nếu playtest cho thấy người chơi xong dưới 15 s thì giảm còn 28 s.

**Nghiệm thu**: test_stage5_canteen thêm nhánh `use_keyboard = true` gửi InputEventKey theo kế hoạch mua [indomie, banh_bao, monster] và bấm Space; bot thanh toán hợp lệ trong dưới 12 s; nhánh cũ bằng hàm vẫn pass; playtest: 0 người với tay sang chuột ở pha này.

### #3 Bảng tổng kết ngày (GPA)

**Luồng**: Màn 6 thắng → StageManager.change_stage sang `scenes/DaySummary.tscn` (scene mới, không đụng tên scene cũ). Extra là tuỳ chọn: nếu đã chơi trong ngày thì tính thưởng. Từ DaySummary có nút "Chơi lại ngày mới" (start_new_day), "Thử Extra" và "Về menu".

**Công thức**: điểm màn = {S: 4.0, A: 3.5, B: 3.0, C: 2.0, thua/không chơi: 0}. `GPA = trung bình 6 màn chính`; `+0.2` nếu Extra đạt A trở lên; trần 4.0; làm tròn 2 chữ số. Danh hiệu: ≥ 3.6 "Cóc Vàng xuất sắc", ≥ 3.2 "Sinh viên Giỏi", ≥ 2.5 "Sinh viên Khá", ≥ 1.5 "Qua môn trong gang tấc", dưới 1.5 "Học lại học phần".

**Dàn dựng**: nền là shot camera flycam của menu; CenterContainer + PanelContainer 900x560; VBox: tiêu đề "BẢNG ĐIỂM NGÀY 20/10", 7 hàng HBox (tên màn, ProgressBar điểm chạy 0 → giá trị trong 0,4 s, chữ rank), mỗi thanh chạy xong phát "tick" cao dần; sau thanh cuối 0,5 s hiện GPA cỡ 64 với flash và danh hiệu; nếu GPA là kỷ lục mới hiện "KỶ LỤC MỚI" và rung màn hình 0,3. Nút "Sao chép bảng điểm" gọi DisplayServer.clipboard_set với văn bản 7 dòng + GPA.

**Lưu trữ**: StageManager.best_stats thêm khoá "day_gpa" (float) và "day_title"; menu Nhật ký hành trình hiện thêm dòng "GPA kỷ lục: 3.42 – Sinh viên Giỏi".

**Nghiệm thu**: test_day_summary.gd nạp scene với run_stats giả (S,S,A,B,C,A + Extra A) và kiểm tra GPA = 3.53 (3.33 + 0.2) và danh hiệu "Sinh viên Giỏi"; không ghi đĩa khi headless (theo guard hiện có); smoke thêm scene mới; playtest: 3/4 người nhắc tới GPA hoặc danh hiệu khi được hỏi "bạn nhớ gì nhất".

## Bước 6 – Kế hoạch playtest 30 phút

**Người chơi**: 4 sinh viên FPT (2 hay chơi game, 2 ít chơi), từng người một, máy laptop có chuột, không ai được hướng dẫn trước. Người quan sát ngồi chéo phía sau, không nói trừ khi người chơi kẹt quá 60 s.

**Thứ tự** (tổng 25 phút chơi + 5 phút hỏi cuối): Menu (quan sát 60 s họ làm gì) → Màn 1 → Màn 2 → Màn 5 → Màn 6 → nếu còn giờ: Màn 3, Màn 4, Extra. Lý do: ưu tiên ấn tượng đầu, cao trào và hai màn đang sửa nhiều nhất.

**Câu hỏi sau mỗi màn** (tối đa 3, không dẫn dắt):
1. "Điều gì vừa xảy ra mà bạn nhớ nhất?"
2. "Có lúc nào bạn không biết phải làm gì không? Lúc nào?"
3. "Nếu thua, bạn nghĩ tại sao?"

**Số liệu ghi tay**: thời gian hoàn thành từng pha; số lần thua và lý do thua theo log game; số lần người chơi rời tay khỏi bàn phím; câu người chơi tự thốt ra (ghi nguyên văn); số lần nhìn xuống bàn phím ở Màn 6.

**Ngưỡng quyết định**:
- #1 giữ nếu ≥ 3/4 nhắc tới lách xe hoặc chuỗi; bỏ nếu ≥ 2 người va chạm trên 3 lần vì xe ngược chiều ở 20 s đầu.
- #2 giữ nếu 0 người với chuột; xem lại nếu ≥ 2 người hỏi "bấm gì để mua".
- #3 giữ nếu ≥ 3/4 nhắc GPA/danh hiệu hoặc bấm "Chơi lại ngày mới" mà không được gợi ý.
- Chung: nếu một màn có tỉ lệ thua lần đầu trên 60% thì nới tham số 10% trước khi thử người tiếp theo; dưới 25% thì siết 10%.
- Sau 4 người: mỗi thay đổi còn giữ phải có ít nhất một câu nói tự phát của người chơi ủng hộ nó, nếu không thì xếp vào "chưa chứng minh".

## Điều tôi chưa chắc

1. Tôi chưa chơi bằng tay người. Mọi nhận định về "cảm giác" suy ra từ log bot, ảnh từng bước và tham số; cảm giác lái xe, độ nặng của drift và độ "đã" của hit-stop cần người thật xác nhận.
2. Thiếu nhạc có thể là nguyên nhân lớn nhất khiến game "chưa cuốn" mà toàn bộ danh sách trên không chạm tới. Nếu chấp nhận nhạc chiptune tổng hợp bằng code (hợp ràng buộc), đó là việc L nhưng có thể đổi cảm nhận toàn cục.
3. Hài kiểu sinh viên FPT: tôi không đo được câu nào gây cười thật; playtest cần ghi riêng số lần bật cười.
4. Campus dựng đúng thực tế có thể bị người chơi cảm nhận là "trống và đều" vì thiếu người qua lại; tôi chưa biết nó đọc là "đẹp" hay "vắng".
5. Rubber-band ở Màn 2 nếu bị nhận ra sẽ gây cảm giác bị chơi xấu; cần theo dõi câu thốt ra kiểu "nó ăn gian".
6. GPA có thể gợi áp lực học hành thật thay vì vui; nếu playtest thấy người chơi nhíu mày, đổi tên thành "Điểm Cóc Vàng" và giữ công thức.
7. Mức đồ hoạ Thấp/Trung bình chưa được nhìn bằng mắt; máy yếu có thể biến game thành phẳng lì và kéo theo cảm nhận "rẻ".
