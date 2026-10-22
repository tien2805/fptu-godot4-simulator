> **Superseded on 2026-10-22:** the owner dropped this weekday story (T2-T7) entirely. The new story is `docs/superpowers/specs/2026-10-22-story-tool-den-design.md` ("TOOL ĐEN – 7 ngày minh oan"). Kept for history only.

# Thiết kế chế độ CỐT TRUYỆN và THẾ GIỚI MỞ – FPTU Student Simulator v1.2

Ngày: 2026-10-21 · Trạng thái: đã duyệt từng phần với chủ dự án qua hội thoại, chờ duyệt bản viết này.

## 0. Quyết định đã chốt

| Câu hỏi | Quyết định |
| :-- | :-- |
| Hướng phát triển | Chủ đạo là **chế độ cốt truyện**; có thêm **chế độ thế giới mở** đi dạo campus; giữ **Chơi nhanh** (ngày 7 màn + Campaign Hub hiện tại). |
| Cách làm | **Cách A**: lớp cốt truyện đặt lên 7 màn hiện có; cảnh thoại là cảnh 3D trong campus với hộp thoại dưới màn hình; thế giới mở là scene riêng. |
| Độ dài | **Một tuần học**: 6 chương = Thứ Hai → Thứ Bảy. |
| Giọng kể | Hài đời sống sinh viên (nền) → tình bạn và nhóm Capstone (trục chính) → lãng mạn học đường (tuyến phụ) → bí ẩn/điều tra vụ tool cheat EOS (cao trào). Có **cinematic bẩn bựa** xuyên suốt. |
| Nhân vật chính | Cố định, có tên, người chơi chọn **nam (Khoa) / nữ (Khuyên)**; đổi mô hình 3D và đại từ, cốt truyện giữ nguyên. |
| Phân nhánh | **Thân cây chung**; lựa chọn thoại và kết quả mini-game cộng/trừ 3 trục điểm; **4 kết thúc** cuối tuần. |
| Thế giới mở | Đi bộ/đi xe tự do trong campus, tới đúng địa điểm thì vào mini-game để phá kỷ lục; mở từ menu ngay từ đầu; NPC chỉ nói một câu, không nhiệm vụ. |
| Trình bày | Cảnh 3D + hộp thoại; chân dung render trực tiếp từ nhân vật 3D; **không ảnh AI**, không ảnh người thật. |
| Giảng viên phản diện hài | Tên hư cấu **ThS. ToanHLM**, nhóm chat gọi **"Toàn Nổ"**; mặt hư cấu (nam ~40, mặt tròn, trán chữ M hơi hói, tóc ngắn củn, polo bóng, thẻ giảng viên, đồng hồ to). Không dựng theo ảnh người thật, không gắn tính cách với dân tộc nào. |
| Băng bán tool | Cừu Dolly, Lò Văn Lụm, Lò Thị Lụm, Lê Minh Gia Mẫn (tất cả là tên hư cấu do chủ dự án nghĩ ra, theo chất tên meme group FB). |

Ràng buộc kỹ thuật không đổi: Godot 4.7 GDScript thuần, không plugin, không C#, giữ cấu trúc thư mục và `class_name`, texture chỉ vẽ/xử lý bằng code (Pillow), sau mỗi thay đổi chạy `--check-only` + smoke + bot test.

## 1. Kiến trúc và luồng chơi

### 1.1 Menu chính
Ba mục: **Cốt truyện** (Bắt đầu tuần mới / Tiếp tục / Chọn chương đã qua), **Khám phá campus**, **Chơi nhanh** (menu cũ). Mục Cài đặt, Hướng dẫn, Thoát giữ nguyên. Khi chọn Cốt truyện lần đầu: màn chọn Khoa/Khuyên (2 nhân vật 3D đứng ở Sảnh Trống Đồng, quay được).

### 1.2 Thành phần mới
- `scripts/StoryDirector.gd` (autoload `StoryDirector`): tiến độ (chương, nhịp), giới tính, cờ, 3 trục điểm, bank thoại; chạy danh sách nhịp của chương; lưu `user://story.cfg` sau mỗi nhịp; cung cấp `stage_params` cho màn chơi; nhận kết quả màn chơi và đổi thành điểm.
- `scripts/StoryScene.gd` + `scenes/StoryScene.tscn`: scene dùng chung cho mọi cảnh thoại. Nạp bối cảnh (`Sets`), đặt diễn viên (`Cast` + `CharacterBuilder`), chạy lệnh kịch bản, điều khiển camera, cinematic, âm thanh.
- `scripts/DialogueBox.gd` (CanvasLayer): tên người nói (màu theo nhân vật), chân dung SubViewport nhìn vào đầu nhân vật đang nói, chữ chạy máy đánh chữ 45 ký tự/giây, `Space/Enter/click` tiếp, `Ctrl` giữ để bỏ qua, `H` nhật ký thoại, lựa chọn 2–3 nút chọn bằng chuột hoặc phím `1 2 3`.
- `scripts/Cinematic.gd` (node con của StoryScene): các hiệu ứng điện ảnh (xem §2.3).
- `story/Cast.gd`, `story/Sets.gd`, `story/Lines.gd` (bank câu đặc trưng), `story/Chapter1.gd` … `story/Chapter6.gd`.
- `scripts/ThirdPersonController.gd` (tách từ Màn 5), `scripts/FreeRoam.gd` + `scenes/FreeRoam.tscn`.
- `StageManager`: khi `StoryDirector.active` thì màn chơi kết thúc trả kết quả về `StoryDirector` (không về hub); hỗ trợ "quay về FreeRoam".

### 1.3 Luồng một chương
Cảnh sáng → mini-game 1 → cảnh giữa (tuỳ chương) → mini-game 2 → cảnh tối có lựa chọn chính → thẻ tổng kết ngày → tự lưu. Thẻ chuyển cảnh 3 giây hiện có (M1) dùng giữa cảnh và mini-game; mỗi ngày mở bằng **thẻ tựa tập** kiểu phim bộ ("TẬP 4 – ĐÊM KHÔNG NGỦ") và đóng bằng **cliffhanger** một dòng.

## 2. Kịch bản: định dạng, lệnh, cinematic

### 2.1 Định dạng
Mỗi chương là file GDScript dữ liệu trả về `Array` nhịp. Ba loại nhịp:

```gdscript
{"type": "scene", "id": "mon_lab_intro", "set": "lab402", "time": "07:29",
 "actors": {"MC": {"at": "seat_mc", "clip": "sit"}, "ToanHLM": {"at": "door"}},
 "script": [ ... lệnh ... ]}
{"type": "stage", "id": "mon_rollcall", "stage": 3,
 "params": {"lecturer": "ToanHLM"},
 "on_result": {"win": {"rep": 1}, "rank_S": {"team": 1}, "fail": {"rep": -2, "flag": "absent_mon"}}}
{"type": "summary", "id": "mon_end", "title": "THỨ HAI – SỐNG SÓT SLOT 1", "journal": "…", "teaser": "…"}
```

Câu thoại dùng `{MC}` (tên nhân vật chính) và `{anh|chị}`, `{cậu|cô}` (đại từ theo giới tính). Dòng thoại tối đa 140 ký tự.

### 2.2 Lệnh trong cảnh
`say` nhân vật câu · `think` câu · `choice` [[chữ, hiệu ứng, nhãn, điều kiện?]…] · `act` nhân vật clip · `move` nhân vật điểm tốc độ · `look` nhân vật mục tiêu · `cam` góc (`wide`, `close` A, `two_shot` A B, `over_shoulder` A B, hoặc {pos, look, fov, dur}) · `flag` tên giá trị · `if` điều kiện nhãn (điều kiện: cờ, hoặc `team>=8`) · `label` · `jump` · `music` style tension · `sfx` tên · `wait` giây · `fade` out/in · `title` chữ · `spawn`/`despawn` extra · `post` (bài đăng group FB nổi lên: tên, nội dung, số cmt tăng dần) · `end`.

Hiệu ứng của `choice`: `{"team": ±n, "romance": ±n, "rep": ±n, "flag": "tên"}`; điều kiện hiện: `{"req": "rep>=3"}`.

### 2.3 Cinematic bẩn bựa (node `Cinematic`)
`slowmo` tỷ_lệ giây · `punch_in` nhân vật (zoom giật + sting "dun dun duuun") · `dutch` độ · `shake` cường_độ · `letterbox` on/off · `freeze` chữ (đóng băng + tiếng đĩa than + caption "Đúng vậy, đó là tôi…") · `caption` chữ (meme to giữa màn hình: SEEN KHÔNG REP, ABSENT, NO NÊ) · `sticker` nhân vật biểu_tượng · `flop` nhân vật (ngã sõng soài) · `scream` nhân vật · `dab` · `kneel` (quỳ xin điểm) · `sprint_panic` · `sting` tên (nhạc ngắt + hợp âm bi kịch hoặc kèn vuvuzela) · `light` preset (đèn đỏ sân khấu, chớp sét ngoài cửa sổ, đèn nháy) · `crowd` phản_ứng ("ồồồ", vỗ tay, quay lưng bỏ đi) · `jumpscare` nhân vật (mặt thầy Toàn phóng to 0,3 giây kèm tiếng thét, dùng tối đa 2 lần cả tuần).

Mọi hiệu ứng là camera, animation `CharacterBuilder` (thêm clip `flop`, `scream`, `dab`, `kneel`, `sprint_panic`), `Label3D`/Control và `MusicDirector`/SFX tổng hợp; không tài nguyên ngoài.

Cảm hứng "dramatic" thêm từ *Quán Phở Của Anh Hai* (indie Godot Việt, kinh dị pha hài, cắt cảnh meme): dựng vài đoạn **kinh dị giả** trong khung hài: đêm cày Capstone đèn chớp tắt và "quái vật deadline" (đã có ở Màn 6) được dẫn bằng cảnh tin nhắn 23:58 của thầy Toàn; hành lang phòng thi Thứ Sáu với nhạc căng, bước chân giám thị, rồi vỡ ra thành chuyện bẩn bựa (thí sinh nuốt phao). Nhịp: căng 10–15 giây rồi xả bằng một câu ngu người.

Ranh giới: slapstick, meme sinh viên, trash talk, gross-out nhẹ. Không nội dung tình dục, không nhắm vào người thật, không dùng ảnh người thật.

### 2.4 Dàn nhân vật (`story/Cast.gd`)

| Mã | Tên | Preset CharacterBuilder | Vai |
| :-- | :-- | :-- | :-- |
| MC | Khoa / Khuyên | player (nam/nữ theo chọn) | nhân vật chính, SE năm 3 |
| Minh | Minh | student_m, kính, tóc side_part | leader nhóm, hay gánh, nhìn camera kiểu The Office |
| Linh | Linh | student_f, tóc bob | frontend, tuyến tình cảm |
| Tu | Tú | student_m casual | tester, hài, uống Monster |
| Phuc | Phúc | student_m, tóc spiky | "seen không rep", ngủ gục, biến mất Thứ Năm |
| ToanHLM | ThS. ToanHLM "Toàn Nổ" | lecturer_boss (mới: trán chữ M, hói nhẹ, tóc củn, polo bóng, đồng hồ to) | phản diện hài, dạy slot 1, ngồi hội đồng |
| Hanh | Cô Hạnh | lecturer (nữ, bun) | hướng dẫn Capstone, hiền nhưng nghiêm |
| Bay | Chú Bảy | guard | bảo vệ cổng |
| CoBa | Cô Ba | cook | căn tin |
| Dolly | Cừu Dolly | casual, mũ, xuất hiện ×2–3 bản sao | băng tool: "bao pass, bao điểm, bao luôn thầy" |
| LoVanLum | Lò Văn Lụm | casual | băng tool: lụm đề, lụm key, lụm thẻ sinh viên (manh mối 1) |
| LoThiLum | Lò Thị Lụm | student_f casual, clip phone | băng tool: "ib em cứu", seen không rep khách |
| GiaMan | Lê Minh Gia Mẫn | casual áo sơ mi, kính | trùm băng tool, giọng khởi nghiệp, lộ diện Thứ Sáu |

### 2.5 Bank câu đặc trưng (`story/Lines.gd`)
- ToanHLM: "Nhà tôi không có gì ngoài tiền.", "Sáng nay tôi mới đi uống cà phê với anh Minh bên Marvell.", "Ai muốn đi thực tập bên Qualcomm gửi CV đi, tôi nói mấy anh bên đó duyệt cho.", "Dốt như bò. Mấy ông cho về đi chăn heo.", "Code kiểu này mà đòi lương nghìn đô? Bên Marvell người ta cho về sau hai phút.", "Slide này tôi soạn ở lounge sân bay, hạng thương gia đấy.", "Hỏi gì mà hỏi. Google mất hai giây, hỏi tôi mất hai điểm.", "Điểm này tôi cho vì thương, không phải vì giỏi.", "Ai làm được câu này tôi mời Starbucks, tiền lẻ với tôi thôi.", "Hồi tôi bằng tuổi mấy ông, tôi đã có hai cái nhà rồi."
- Băng tool: "ib anh cứu", "ib em cứu nha mọi người", "full đề EOS, bao pass, không pass hoàn tiền", "ai cần tool PRN ib mình", "uy tín 5 năm, feedback đầy", "còn 3 slot, nhanh tay", "ib mình gửi key", "nhận làm lab, đồ án, bao điểm 8+", "ad duyệt bài giúp em với", "cmt chấm để nhận tài liệu", "chốt đơn", "xin vía qua môn", "thi xong đừng khoe điểm, ib anh cứu"; Gia Mẫn: "hệ sinh thái tool", "uy tín 5 năm", "kết nối mentor", "em nghĩ lớn đi".
- Sinh viên campus / nhóm chat: "cho em hỏi thầy này dễ không ạ", "có ai slot 1 bị kẹt xe không", "chụp giúp mình điểm danh với", "xin link slide", "seen không rep là có lý do", "cần tìm team Capstone, mình làm tester", "pass môn này bao không", "lên đồ đi thi", "cà phê Passio ai đi không", "nhà tôi không có gì ngoài deadline".

### 2.6 Bối cảnh (`story/Sets.gd`)
`lobby_trong_dong`, `canteen`, `courtyard_pond`, `atrium_hall`, `atrium_stair_top`, `lab402`, `lab402_night`, `room311`, `vovinam_mat`, `parking`, `gate_d1`, `rooftop` (sân thượng mái bằng mới), `seven_eleven`. Mỗi bối cảnh: cách dựng (campus + opts hoặc phòng), điểm đứng có tên, góc máy có tên, preset ánh sáng, style nhạc.

## 3. Tuần truyện, điểm và kết thúc

### 3.1 Sáu chương

| Chương | Mini-game | Trục truyện | Khoảnh khắc bẩn bựa |
| :-- | :-- | :-- | :-- |
| Thứ Hai – "Slot 1" | Màn 1, Màn 3 (thầy Toàn) | ra mắt nhóm, thầy Toàn, cô Hạnh, chú Bảy, cô Ba | quẹt thẻ trượt 3 lần quay chậm; thầy gọi tên punch-in, tiếng ruồi |
| Thứ Ba – "Khay cơm định mệnh" | Màn 2 (cầu thang trong nhà), Màn 5 | mâu thuẫn nhóm bắt đầu, Linh | Phúc gục bàn phím 400 dòng "jjjj"; trượt vũng nước, cô Ba "KHAY CỦA CÔ", freeze |
| Thứ Tư – "Đòn chân kẹp cổ" | Màn 4 | manh mối 1: bài đăng "ib anh cứu", Lò Văn Lụm lụm thẻ | đá hụt quay chậm, đồng môn facepalm; Linh nhắn nhầm nhóm, caption SEEN |
| Thứ Năm – "Đêm không ngủ" | Màn 6 biến thể ngắn (đêm cày) | Phúc biến mất; lựa chọn lớn: che hay tố giác việc Phúc mua tool | Tú uống Monster thứ tư mắt sáng xanh; tin nhắn 23:58, chớp sét, cả nhóm quỳ |
| Thứ Sáu – "Phòng 311" | Extra (MC được thầy nhờ quan sát) | cao trào băng tool, Gia Mẫn lộ diện | giám thị dolly, nuốt phao, "KHÔNG TÌM THẤY BẰNG CHỨNG"; truy đuổi sprint_panic |
| Thứ Bảy – "Bảo vệ" | Màn 6 bản cuối | buổi bảo vệ, thầy Toàn trong hội đồng, kết thúc | demo crash quay chậm, Minh dab, "nhóm em không có gì ngoài bug"; cảnh kết riêng |

### 3.2 Ba trục điểm
Nhóm, Tình cảm, Uy tín: 0–20, bắt đầu 5. Nguồn: lựa chọn (±1/±2), mini-game (bảng §3.3), sự kiện phụ. Chỉ hiện ở thẻ tổng kết ngày và nhật ký.

### 3.3 Mini-game → điểm (mặc định, kịch bản có thể ghi đè)

| Màn | Thắng | Rank S | Thua |
| :-- | :-- | :-- | :-- |
| Thứ Hai – Màn 1 | Uy tín +1 | Nhóm +1 | Uy tín −2, cờ `late_mon` |
| Thứ Hai – Màn 3 | Uy tín +1 | Nhóm +1 | Uy tín −2, cờ `absent_mon` |
| Thứ Ba – Màn 2 | Uy tín +1 | Tình cảm +1 | Nhóm −1 |
| Thứ Ba – Màn 5 | Nhóm +1 | Tình cảm +1 | Nhóm −1 |
| Thứ Tư – Màn 4 | Uy tín +1 | Tình cảm +1 | Uy tín −1 |
| Thứ Năm – Màn 6 ngắn | Nhóm +2 | Nhóm +1 | Nhóm −2, cờ `phuc_left_early` |
| Thứ Sáu – Extra | Uy tín +2 | Uy tín +1 | Uy tín −2; mỗi lần bắt oan −1 |
| Thứ Bảy – Màn 6 cuối | quyết định kết thúc | | quyết định kết thúc |

### 3.4 Truyện → màn chơi (`StoryDirector.stage_params`)
Nhóm ≥ 10: Phúc tỉnh táo từ đầu Màn 6, team +HP. Tình cảm ≥ 8: Linh chờ ở căn tin, giảm số lần bị xô. Uy tín ≤ 4: thầy Toàn gắt hơn (thời gian nhập mã ngắn hơn, nhiều câu chửi). Cờ `mocked_toan`: đổi lời thoại của ông ở mọi màn. Màn 3 dùng mô hình và bộ thoại thầy Toàn khi `lecturer == "ToanHLM"`.

### 3.5 Bốn kết thúc (xét theo thứ tự)
1. **Kết ẩn "Anh Minh bên Marvell có thật"**: bảo vệ thắng, Uy tín ≥ 12, Nhóm ≥ 10, đủ 3 manh mối, không có `mocked_toan`.
2. **Cóc Vàng**: bảo vệ thắng, Nhóm ≥ 9, Uy tín ≥ 8; thêm đoạn tình cảm nếu Tình cảm ≥ 9.
3. **Qua môn trong gang tấc** (mặc định): bảo vệ thắng.
4. **Nhóm tan rã**: bảo vệ thua hoặc Nhóm < 6; biến thể **Đình chỉ** khi Uy tín < 5 (cả nhóm đi chăn heo, chữ "ĐÚNG Ý THẦY").

Mỗi kết thúc mở thành tích; sau khi hết tuần mở chọn lại chương; nhật ký liệt kê cờ đã có để săn kết khác.

### 3.6 Lưu
`user://story.cfg`: chương, nhịp, giới tính, tên, 3 trục điểm, cờ, kết thúc đã đạt. Tự lưu sau mỗi nhịp. Menu: Tiếp tục / Bắt đầu tuần mới (hỏi xác nhận xoá) / Chọn chương.

## 4. Thế giới mở "Khám phá campus"
- `FreeRoam.tscn`: campus v7 có va chạm + D1 + HUTECH; `T` đổi giờ (bình minh/trưa/đêm) bằng preset ánh sáng; đêm bật đèn cột và sảnh; nhạc "menu" nhẹ.
- Nhân vật: `ThirdPersonController.gd` (WASD theo camera, Shift chạy, chuột/Q E xoay camera, lên được cầu thang trong nhà và sân thượng). Xe tay ga ở bãi xe: `F` lên/xuống, lái bằng vật lý PlayerBike quanh D1 và đường nội bộ.
- 7 điểm nóng (Area3D + cột sáng + biển: tên màn, kỷ lục, `[E]`): cổng D1 → Màn 1; cổng bãi xe → Màn 2; cửa Lab 402 → Màn 3 (ngày) / Màn 6 (đêm); sân võ → Màn 4; quầy cô Ba → Màn 5; phòng 311 → Extra. Chơi xong quay về đúng chỗ; kỷ lục ghi `progress.cfg`.
- Sự sống: ~25 sinh viên đi theo lối đi và cầu thang (CharacterBuilder, LOD), nhóm tụ tập ở căn tin và hồ sen, chú Bảy, cô Ba, xe ra vào bãi; `E` cạnh NPC → một câu ngẫu nhiên từ bank.
- `M` bản đồ Control (cánh nhà, điểm nóng, vị trí người chơi); `P` chụp ảnh (ẩn HUD, camera tự do, `Enter` lưu `user://photos`); `ESC` tạm dừng.

## 5. Kiểm thử, hiệu năng, lộ trình
- Test mới: `tests/test_story_scripts.gd` (nhân vật/bối cảnh/điểm đứng/clip/nhãn tồn tại, lựa chọn có lối ra, dòng ≤ 140 ký tự), `tests/test_story_run.gd` (bot chơi hết tuần, ép điểm để chạm cả 4 kết thúc), `tests/test_free_roam.gd` (bot tới 3 điểm nóng, mở 1 màn, quay lại đúng chỗ). Test cũ giữ nguyên; `test_hud_bounds` thêm StoryScene, FreeRoam.
- Hiệu năng: cảnh thoại tối đa 8 diễn viên có animator; đám đông thế giới mở dùng LOD và bake; chân dung SubViewport 256×256 chỉ render khi hộp thoại mở.
- Lộ trình (mỗi bước: commit, preview ảnh, test xanh): (1) khung truyện + Thứ Hai chơi được; (2) Thứ Ba–Thứ Năm; (3) Thứ Sáu, Thứ Bảy, 4 kết thúc, thẻ tổng kết, lưu/tiếp tục, menu 3 chế độ; (4) thế giới mở; (5) hoàn thiện, docs, changelog, v1.2.0 (tag chỉ khi chủ dự án đồng ý).

## 6. Ngoài phạm vi
Nhiệm vụ phụ trong thế giới mở, lồng tiếng, nhân vật luân phiên, phân nhánh cốt truyện thật sự giữa tuần, bản mobile.
