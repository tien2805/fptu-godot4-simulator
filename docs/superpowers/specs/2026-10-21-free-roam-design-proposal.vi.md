<!-- Companion Vietnamese version generated 2026-10-21 by the free-roam ideation workflow. The English file 2026-10-21-free-roam-design-proposal.md is canonical. -->

# Đề xuất thiết kế: Chế độ thế giới mở "Khám phá campus"

Phiên bản đề xuất cho v1.2, viết cho chủ dự án (1 người, Godot 4.7 GDScript thuần, texture Pillow).

Lưu ý quan trọng trước khi đọc: mọi bản kiểm chứng đều phát hiện cùng một điều, repo HIỆN CHƯA CÓ nền thế giới mở. Không có `scenes/FreeRoam.tscn`, `ThirdPersonController.gd`, NPC đi dạo, phím T, bản đồ M hay chế độ P; chúng mới nằm ở spec §1.2 và lộ trình §5 bước (4). Vì vậy đề xuất này có thêm "Tầng 0: nền tảng" và mọi ngày công tầng 1 trở đi đều tính TRÊN nền đó.

## 1. Trụ cột của thế giới mở

- Campus có người đáng sợ. Toàn Nổ đi tuần với hình nón tầm nhìn, chú Bảy là luật ở barie và sân trong. Người chơi luôn có một thứ để né, để trêu, để bị bắt rồi kể lại.
- Mọi NPC là đồ chơi. Một phím chọc cho 13 preset phản ứng khác nhau, Phúc ngủ gục khắp nơi, Tú uống Monster thứ tư. Không có nhiệm vụ nhưng có việc để làm với từng người.
- Nỗi đau thật của sinh viên FPT HCM thành trò chơi lại được: quẹt thẻ dây cam 07:29, tìm xe trong bãi gần 200 chiếc giống nhau, chờ thang máy sảnh G.
- Số nhảy và bộ sưu tập là lý do quay lại: Cóc Vàng, Điểm rèn luyện, Sổ tay Toàn Nổ 20 câu, 10 chỗ ngủ của Phúc, Album bựa. Seed theo ngày đổi chỗ ngủ, đổi lỗi thẻ, 1/10 ngày xe bị lụm.
- Thế giới mở nuôi mini-game chứ không cạnh tranh: điểm nóng phá kỷ lục cộng tiền, vía Cóc Vàng mang vào Màn 3/4, lon Monster mua ở Màn 5 đem về cho Tú.
- Mỗi tương tác là một clip 15 giây: quay chậm, freeze frame, caption, tem đỏ, tiếng ruồi, sét đánh. Dùng đúng ngữ pháp "cinematic bẩn bựa" của truyện.

## 2. Vòng chơi cốt lõi

Một vòng duy nhất: Khám phá, Thử, Nhận, Sưu tập, Tiêu, Quay lại. Hai con số xương sống là Cóc Vàng (CV, tiền tiêu được) và Điểm rèn luyện (ĐRL, 0-100, chỉ cộng lần đầu mỗi việc để không cày vô hạn).

| Bước | Người chơi làm gì | Nhận gì | Lưu ở đâu |
|---|---|---|---|
| Khám phá | Đi bộ/lái xe quanh campus, T đổi preset giờ, nghe tiếng ngáy, thấy Toàn Nổ xuất hiện | Thấy sự kiện, biển [E] | Không lưu |
| Thử | Vào điểm nóng chơi mini-game, quẹt thẻ, né Toàn Nổ, chọc NPC, gọi Phúc dậy | CV + ĐRL + kỷ lục roam | `best_stats` (mini-game), `roam_stats` (mới) |
| Sưu tập | Câu chửi Toàn Nổ, chỗ ngủ Phúc, ảnh selfie, (tầng 2) tờ rơi | % hoàn thành, cảnh thưởng khi đủ | `roam_stats` bitmask |
| Tiêu | (tầng 2) Dâng lễ Cóc Vàng lấy vía, mua lon cho Tú | Buff vào Màn 3/4, cảnh Tú overdose | `inventory` (phiên), ví (đĩa) |
| Quay lại | Seed ngày: chỗ Phúc, bộ lỗi thẻ, ngày xe bị lụm, mốc ĐRL kế tiếp, câu chửi chưa mở | Việc mới mỗi lần mở game | Hash ngày hệ thống |

Nguồn thu và chỗ tiêu ở v1.2:

| Nguồn CV / ĐRL | Mức | Chỗ tiêu (sink) |
|---|---|---|
| Thắng mini-game ở điểm nóng: S 60 / A 40 / B 25 CV, phá kỷ lục x2, thắng lần đầu +100 CV +5 ĐRL | Chính | Tầng 1: chưa có sink lớn, ship kèm một sink nhỏ (xem câu hỏi 6) |
| Quẹt thẻ sạch, Thẻ VIP, sống sót Toàn Nổ, combo bựa, tìm Phúc | +5 đến +20 CV, +1 ĐRL lần đầu | Tầng 2: lễ vật Cóc Vàng (meme-04), lon Monster cho Tú (bua-04) |
| ĐRL dưới 50 | Thư cảnh cáo CTSV ở sảnh, Toàn Nổ chửi | Tầng 3: gara (loop-05), căn tin (loop-07) |

## 3. Ba tầng hạng mục

### TẦNG 0: nền tảng bắt buộc (chưa có trong code)

**Nền FreeRoam tối thiểu.** Scene `scenes/FreeRoam.tscn` dựng campus `build_authentic_campus(root, Vector3.ZERO, 0.0, {colliders:true, parking_gaps:[...]})` + Ground StaticBody (campus builder không có collider mặt đất, Stage2 tự thêm), đoạn D1 và HUTECH. Controller góc 3 tách từ `StageExtra_EOSExam._handle_movement/_update_walk_camera` (bỏ clamp phòng 311, thêm trọng lực, camera xa hơn 2.8 m) và `Stage5._process_walk`. NPC walker từ mẫu `Stage5._build_npcs/_process_npcs`, gắn `meta role`. Xe tay ga F lên/xuống bằng `PlayerBike` (gán `road_path = null` tường minh, thêm `@export fallback_respawn`). T đổi preset qua `GameFX.upgrade_scene_visuals` chỉ khi preset đổi. Cờ để `StageManager._input` bỏ qua phím M khi ở FreeRoam.
- Tái dùng (đã kiểm chứng): `FPTUCampusBuilder.build_authentic_campus` + opts `colliders`, `StageExtra_EOSExam._handle_movement:453`, `Stage5_Canteen._process_npcs:690`, `PlayerBike.lane_clamp_enabled:37`, `GameFX.TOD_PRESETS:648`, `Animator` LOD sẵn (:1305-1318).
- Việc mới: 2 scene/script trên, `StageManager.roam_stats` + section `[roam]` trong `progress.cfg` đọc/ghi 2 chiều (save_progress hiện ghi đè cả file chỉ với `stage_%d`, khoá chuỗi gây lỗi runtime), tham số đường dẫn cho test headless, nút "Về campus" trong modal kết quả + cờ `return_to_roam`, thêm FreeRoam vào `smoke_all_stages.gd`.
- Ngày công: 4.5 (các bản kiểm chứng ước 3 đến 5).
- Bẩn bựa: 0/5. Trong spec §4.

### TẦNG 1: phải có cho v1.2

**1.1 loop-01 Ví Cóc Vàng + Điểm rèn luyện.** Mọi việc trả về CV và ĐRL, HUD góc trên hiện ví + thanh ĐRL, popup "+30 Cóc Vàng, +2 ĐRL" kèm tiếng cash. ĐRL dưới 50 thì bảng "THÔNG BÁO CTSV" ở Sảnh Trống Đồng có Toàn Nổ đứng cạnh nói "Điểm rèn luyện này tôi cho vì thương". Bảng mốc ĐRL mở bằng J. Mốc mở khoá khu vực hoãn (không có geometry gara/cổng sau).
- Tái dùng: `StageManager.report_stage_result:512` (đã so kỷ lục, `b.wins` phát hiện thắng lần đầu), `save_progress/load_progress:125-149`, `GameFX.anchored_panel:850`, `make_bar:826`, `play_sfx('cash')`, `MainMenu._refresh_journal:376`, phím J còn trống trong `StageManager._input`.
- Việc mới: ví + ĐRL là THÀNH VIÊN của StageManager (không autoload mới, tránh vỡ 15 test headless tự tạo autoload), `earn/spend/drl_add/drl_tier` + signal, lưu section `[roam]` hoặc `user://wallet.cfg` có tham số path; `FPTUCampusBuilder.lobby_center()` mới; `tests/test_wallet.gd`.
- Ngày công: 3. Bẩn bựa: 2/5. Vượt spec §4/§6 (tiến trình trong thế giới mở).

**1.2 bua-01 Toàn Nổ đi tuần campus.** Cứ 3 đến 5 phút Toàn Nổ xuất hiện ở sảnh, đi tuyến cố định lobby → căn tin → lối sau → chân thang, kéo theo nón nhìn 8 m. Chạy Shift, ngồi xe trong sân, hoặc đứng bấm điện thoại trong nón là bị bắt: punch-in, quay chậm, chỉ tay, một câu từ bank. 2 giây chọn: cúi chào [E] (thầy nod, bỏ qua), bỏ chạy (rượt 6 s trong vùng lát gạch, bắt được thì freeze frame "ĐÚNG VẬY, ĐÓ LÀ TÔI" + tem "ĐI CHĂN HEO"), nấp sau cây (raycast chạm collider cây là thoát). Mỗi lần thoát mở 1 câu trong Sổ tay Toàn Nổ, đủ 20 câu mở cảnh thầy ngồi uống cà phê một mình, caption "Anh Minh bên Marvell không nghe máy".
- Tái dùng: preset `lecturer` + `set_expression('angry')`, clip `bow/nod/facepalm`, chạy = `set_speed(6-7)+set_param('run')` (không có clip run), `Stage3 lecturer_bubble:118`, `GameFX.slow_motion(0.3,1.2)`, `music_play('exam')` + `music_tension` (style exam có heartbeat), tuyến từ `lobby_u()/canteen_center()/back_gap_u()/stair_foot()`, cây sân trong có collider r0.3.
- Việc mới: `scripts/roam/ToanPatrol.gd` (máy trạng thái idle→patrol→spot→lecture/chase→lose, nón = dot > cos 35° + RayCast3D, rượt chỉ trong u∈[36,85], v∈[35,71], 3 raycast ngắn tránh cây/hồ, kẹt 1 s = lose); preset `lecturer_boss` + nhánh tóc `receding` + áo polo `_mat(..., rough 0.4)` + opts `watch_scale` (cốt truyện cũng cần); `scripts/ui/FreezeFrame.gd` (chụp viewport + caption + tem xoay -12°, dùng chung Cinematic sau này); 8 câu mới tạm đặt trong `ToanPatrol.LINES`; cooldown 1 lần/3 phút, tắt khi đứng trong Area3D điểm nóng; `tests/test_toan_patrol.gd`. Cắt khỏi v1: NPC tản ra, nấp sau nhóm sinh viên, mốc 07:25 (chưa có đồng hồ).
- Ngày công: 4.5. Bẩn bựa: 5/5. Vượt spec §6 (sưu tập câu).

**1.3 bua-08 Một phím chọc NPC + selfie bẩn bựa.** Phím G (F đã dành cho xe, KEY_G chưa dùng ở đâu) chọc NPC: sinh viên flinch + mặt angry; chú Bảy thổi còi, lần 3 lập biên bản; cô Ba hét "KHAY CỦA CÔ" ném khay bay vào mặt; Toàn Nổ punch-in "Google mất hai giây, hỏi tôi mất hai điểm"; Minh nhìn thẳng camera kiểu The Office, đóng băng 1 s; Linh trái tim rồi "seen". Chọc 5 NPC khác nhau trong 30 s = "COMBO BỰA x5", mọi NPC trong 20 m facepalm cùng nhịp + vuvuzela. Trong chế độ P, G cạnh NPC = selfie: NPC bốc tư thế ngẫu nhiên, ảnh lưu `user://photos` kèm caption meme.
- Tái dùng: `CharacterBuilder.play:601` + `ONE_SHOT:1278` (flinch/facepalm/bow/cheer_once/nod; wave/stance/plank lặp nên phải truyền duration), `set_expression:633` (32 texture mặt có thật), `look_at_point:627`, `PropBuilder.build_tray:450`, `Stage5._on_npc_bump:632` làm mẫu, `GameFX.slow_motion(0.02,1.0)` cho The Office, chụp ảnh = `get_viewport().get_texture().get_image().save_png` như `tests/preview_*` (không cần SubViewport, HUD caption đã nằm trong khung).
- Việc mới: `scripts/roam/NpcReactions.gd` (bảng role → clip/duration/expr/line/fx, ~150 dòng), ring buffer combo 30 s, clip `dab` mới (~15 dòng trong `Animator._clip_pose`), synth `vuvuzela` + `whistle` trong `GameFX._synth`, chặn ghi ảnh khi headless, `tests/test_npc_reactions.gd` (mọi preset kể cả rigged=true không SCRIPT ERROR, biểu cảm về `open`). Bỏ hạng mục "bake thêm tư thế" (không có pipeline bake đám đông, Animator đã tự LOD).
- Ngày công: 2. Bẩn bựa: 4/5. Vượt spec §6 (Album bựa).

**1.4 meme-03 Quẹt thẻ dây cam 07:29.** Lái xe tới barie bãi xe, mỗi lần E là thanh canh thời gian + một lỗi random trong 5 loại v1 (ngược thẻ, lag, rơi thẻ, quên thẻ phải gõ "ib anh cứu", barie hóc). Trượt thì thẻ bay quay chậm + tiếng ruồi, hàng 4 đến 6 xe NPC sau lưng mất kiên nhẫn bấm còi, chú Bảy chửi theo nhịp. Qua được thì bảng "quẹt N lần, M giây, độ nhục". 5 lần "quẹt 1 phát ăn ngay" liên tiếp mở thành tích Thẻ VIP.
- Tái dùng: `FPTUCampusBuilder._build_gate:1007` + opts `skip_barrier_at`, `park_gate_guard_pos:761`, mẫu `Stage2_Parking._build_gate_props:278` và `_scan_student_card:756` (tween `rotation_degrees:z`), `_update_guard_nag:677` (port tay ~60 dòng, không phải bank tái dùng được), `PropBuilder.build_scooter:171` + `CharacterBuilder.build_baked_rider:583` cho hàng xe, `GameFX.play_sfx('res://assets/audio/bike_horn.wav')` (play_sfx nhận đường dẫn res://), `hit_stop/slow_motion/popup/float_text`, `play_sfx('error','pop','beep','miss')`.
- Việc mới: `scripts/roam/CardSwipeQTE.gd` (máy trạng thái 5 lỗi, mỗi lỗi QTE 2 đến 4 s), dựng CẢ HAI thanh barie bằng code (thanh 1 của Màn 2 là node .tscn), mesh thẻ BoxMesh + texture `prop_student_card.png` thêm vào `generate_prop_textures.py` (ở gốc repo), hàng xe tự nhích + thanh kiên nhạn, còi giới hạn 1 lần/0.8 s/xe và tối đa 3 xe cùng lúc, bank 12 câu chú Bảy, kỷ lục `roam_stats.gate`, `tests/test_roam_gate.gd`. Điểm nóng vào Màn 2 giữ nguyên, QTE đặt sau barie hoặc dùng phím khác E.
- Ngày công: 3. Bẩn bựa: 4/5. Vượt spec §6 nhẹ (thành tích).

**1.5 bua-03 Phúc ngủ gục khắp nơi.** Mỗi lần vào FreeRoam hoặc bấm T, Phúc chọn 1 trong 10 chỗ ngủ chắc chắn có sàn (gầm bàn căn tin, mép bệ Cóc Vàng ngồi gật, kẹt giữa hai xe trong ô `parking_gaps`, cạnh hồ sen, chân thang, bốt bảo vệ, hiên vòng cung...). Tiếng ngáy 3D nghe trong 20 m là manh mối. Tới nơi E → mash SPACE 14 lần/4 s → Phúc giật bắn, mặt surprised, nói một câu, đi đúng 10 m rồi gục ngủ tiếp. Đủ 10 chỗ mở cảnh Phúc ngủ trên đầu Cóc Vàng, sét đánh vẫn không dậy, caption "SEEN KHÔNG REP LÀ CÓ LÝ DO".
- Tái dùng: `build({preset:'student_m', hair_style:'spiky'})`, clip `sleepy/sleepy_sit/lie/slump/flinch`, `set_expression('surprised'/'done')`, mash 14/4 s của `Stage6._phone_start:798` làm mẫu, `GameFX._synth` trả AudioStreamWAV cho AudioStreamPlayer3D, `flash + play_sfx('explode')` cho sét, `canteen_center/parking_spot_candidates/stair_foot/lobby_u`.
- Việc mới: `scripts/roam/PhucSpots.gd` (bảng {pos, clip, yaw, line, walk_dir}, pick theo seed giờ), `scripts/roam/MashPrompt.gd` riêng (không refactor Màn 6 vì `test_stage6` đọc trực tiếp `phone_active`), synth `snore` (~8 dòng), helper `toad_pos()/pond_center()` (dùng chung với meme-04/bua-04/bua-06), 1 label "jjjj" nhiều dòng thay vì 400 Label3D, bitmask `roam_stats.phuc_found`, `tests/test_phuc_spots.gd` (raycast xuống mỗi chỗ phải trúng sàn). Chỗ chiếu nghỉ thang, sân thượng, Lab 402 thêm lại khi có collider thang/tầng trên.
- Ngày công: 2. Bẩn bựa: 3/5. Vượt spec §6 (sưu tập).

### TẦNG 2: nên có (v1.3)

**2.1 meme-04 Cóc Vàng xin vía.** Dâng 1 lon (hoặc CV) tại tượng, chọn vía, QTE lạy 3 lạy nhịp 0.8 s bằng clip `bow`, nhận quẻ meme theo 4 mức hiếm, mắt cóc sáng, sét quay chậm. Vía là item thật: `via_fap` +5 s ở Màn 3 (hook ở `_ready` cạnh dòng 168, không đổi điểm), `via_vovinam` tha 1 miss ở `Stage4._judge_result` nhánh miss (phải giữ `n['judged']=true`). Đây là sink đầu tiên của ví.
- Tái dùng: tượng cóc `_build_courtyard:1217`, `StageManager.inventory` + `add_item/consume_item:496-510`, `GameFX.flash/slow_motion/play_sfx('explode','success')`.
- Việc mới: `toad_pos()`, đặt tên node `ToadEyeL/R` + vật liệu emission riêng (KHÔNG tween `m['dark']` vì dùng chung cả campus), `scripts/roam/ToadShrine.gd`, bank 30 quẻ, cờ `via:true` trong `report_stage_result` + dấu * ở `get_best_text`, khoá 1 lần/ngày trong `[roam]`.
- Ngày công: 3. Bẩn bựa: 3/5. Vượt spec §4 (buff làm bẩn kỷ lục, cần duyệt).

**2.2 explore-08 Tìm xe mình trong bãi gần 200 chiếc.** Xe người chơi nằm ở ô ngẫu nhiên theo seed ngày; K bíp chìa (AudioStreamPlayer3D gắn vào xe, max_distance 25, tối đa 5 bíp), đèn nháy bằng tween emission/OmniLight trên PlayerBike. Lái vào sân trong thì Area3D ép `max_speed_ms` 8, quá 3 s bị tịch thu về bốt, float_text "-50k". Ngày % 10 == 0: không có xe, Lò Văn Lụm đang chở nó ra cổng, đuổi theo bằng PlayerBike thứ 2 (đổi `chase_cam.current`).
- Tái dùng: lưới xe `_build_back_facilities:1263-1279` (seed 7 cố định, bước 1.3 m), opts `parking_gaps` như Stage2, `build_scooter` baked + `build_baked_rider`, mẫu `_rival_plan_route:420` (chép, không gọi), `PlayerBike.set_rain`.
- Việc mới: `FPTUCampusBuilder.parking_slots()` static, `scripts/roam/ParkingFinder.gd`, Area3D sân trong, nhánh ngày lụm, `tests/test_parking_finder.gd`. Không đụng MultiMesh (15 MMI, biến cục bộ, không trả chỉ số).
- Ngày công: 3. Bẩn bựa: 4/5. Vượt spec §6 (sự kiện ngày).

**2.3 bua-04 Tú và lon Monster thứ tư.** Tú cắm ở máy Monster (tách `Stage2._build_monster_machine` 89 dòng sang `PropBuilder.build_vending_machine`). Lon 1 "Ngon", lon 2 đi nhanh gấp đôi, lon 3 rung bần bật, lon 4 mắt sáng xanh, tension 1.0, quay chậm, chạy 8 waypoint quanh hồ sen (né cây, tween không vật lý) để lại "jjjj", gục với caption "TU.EXE ĐÃ NGỪNG HOẠT ĐỘNG" + tiếng ruồi. Người chơi tự uống: sprint x2 kẹp 9 m/s, FOV nở, speedlines, vignette đập nhịp tim, hết buff thì cháy máy flop ngã, NPC quanh đó giơ điện thoại.
- Tái dùng: `MONSTER_POS`, `SPRINT_SPEED 9`, `StageManager.inventory` (Màn 5 `add_item('monster')` :901), `HUDManager.SPEEDLINES_SHADER` const, `GameFX.set_vignette(strength,color,pulse_hz)`, `play_sfx('heart','shutter')`, `get_pivot(root,'head')`.
- Việc mới: `scripts/roam/TuMonster.gd` với `overdose()` gọi lại được từ StoryScene (kịch bản Thứ Năm §3.1 cần đúng cảnh này), clip `flop` + `photo` (pose đứng giơ điện thoại, `phone` hiện là pose ngồi), synth `fly` (180 Hz có LFO), `apply_monster()` trong controller, mắt xanh = 2 cầu emission (OmniLight sẽ chiếu sáng mặt trong đầu), chạy lại `test_stage2_stairs` sau khi tách máy.
- Ngày công: 2.5. Bẩn bựa: 4/5. Vượt spec §6 nhẹ. Lưu ý: inventory KHÔNG lưu đĩa, `start_new_day()` reset về 0.

**2.4 bua-06 Trò nghịch: còi, hồ sen, Cóc Vàng.** Bóp còi H sát nhóm NPC: flinch tán loạn, 1 người rơi khay, cô Ba ló ra; 5 lần/10 s thì chú Bảy tới, "BIÊN BẢN: XE BỊ TẠM GIỮ 60s", khoá F. Bước xuống hồ sen (opt `pond_collider:false` + Area3D đĩa): splash CPUParticles3D, quay chậm, camera nghiêng, ướt 20 s đi chậm 50% + lá sen `m['leaf2']` dưới `head_top()`; preset night thì sét, nằm lie, hồi sinh trước sảnh "GAME NÀY KHÔNG CÓ BẢO HIỂM". Cóc Vàng: giữ E 3 s = tween lên đầu cóc (không có nhảy/bám mép), NPC 15 m tới cheer, chú Bảy "XUỐNG!".
- Tái dùng: `Input.is_action_just_pressed('horn')` như Stage2:669 (PlayerBike không phát signal), hình học hồ/cóc trong `_build_courtyard`, `preset night` qua `root.get_meta('visual_preset')`, clip `flinch/cheer/lie/carry`, `set_opacity`.
- Việc mới: `scripts/roam/PrankSystem.gd`, opts `pond_collider`/`toad_climbable`, hành vi NPC đi-tới + clip (~30 dòng, dùng chung với bua-02), `roam_stats.pranks`, `tests/test_pranks.gd`. Hồ hiện cao hơn sân 0.1 m, muốn có độ sâu thật +0.5 ngày.
- Ngày công: 3.5. Bẩn bựa: 5/5. Vượt spec §6 (thành tích).

**2.5 bua-02 Băng tool chào hàng "IB ANH CỨU".** Cừu Dolly (cùng seed = bản sao y hệt, opts `cap` mới) + Lò Văn Lụm + Lò Thị Lụm bám theo 1.5 m, giơ điện thoại, tuôn câu bank; E lần 2 = "Em không mua" để họ bỏ đi 2 phút. Nhận tờ rơi → overlay bài đăng FB giả với cmt "chấm" nhảy số. "Chốt đơn" = "ĐÃ CHUYỂN KHOẢN 200K", Uy tín -1, Lò Thị Lụm seen; "Báo chú Bảy" = guard spawn cách 15-20 m + còi, cả băng chạy quay chậm, caption "UY TÍN 5 NĂM" gạch chéo. Mỗi lần đuổi Dolly, lần sau thêm 1 bản sao (tối đa 6). 12 tờ rơi Pillow 256x256; cảnh Gia Mẫn TED-talk sân thượng cắt sang tầng 3 (chưa có collider mái).
- Tái dùng: `build(opts)` với `seed`, clip `phone/flinch`, `_rival_say` làm mẫu bong bóng, `GameFX.anchored_panel/make_label`, `play_sfx('ring','cash','whoosh')`, `generate_lobby_textures.py` font()/save(), `stair_foot()` làm điểm hoạt động (cửa Lab 402 ở y 17.9 không tới được).
- Việc mới: `scripts/roam/ToolGang.gd` (CharacterBody3D + move_and_slide, giữ ở vùng trống hồ sen/làn bãi xe vì không có navmesh), `scripts/ui/FbPostOverlay.gd` (StoryScene dùng lại sau), `lotus_pond_center()`, opts `cap`, `generate_flyer_textures.py`, `tests/test_tool_gang.gd`. Không hiện STK/QR thật.
- Ngày công: 4. Bẩn bựa: 4/5. Vượt spec §0/§6 (sưu tập tờ rơi, cần duyệt).

### TẦNG 3: để sau (v1.4+)

**3.1 meme-01 Hội thánh chờ thang máy sảnh G.** State machine cửa đóng/mở/đầy/kẹt, luật "càng bấm càng lâu", bỏ đi thì cửa mở sau lưng + freeze frame. Cần khoét pocket cabin trong khối link 1-2 (`build_module_wing:668`), getter `lobby_elevator_doors()`, Label3D số tầng, hàng chờ bằng slot cố định, 10 người cabin `pose()+bake()`. Kích hoạt bằng Area3D khi preset morning (không có đồng hồ). Nhánh "chạy thang bộ" sai địa lý (thang thông tầng ở cánh phải cách sảnh 75 m) nên đích là `lab402_door()` qua fade-teleport. Ngày công 3, bựa 3/5, vượt spec §0/§6. Gộp làm chung với explore-02.

**3.2 meme-06 Giờ G 07:25 cả campus chạy slot 1.** Cần `scripts/roam/CampusClock.gd` (1 phút game = 10 s, T nhảy tới mốc kế -1 phút) + `NpcSchedule.gd` (idle→rush→inside, waypoint qua `stair_profile()`, ẩn ở cửa), F-Bus tween xả 15-20 NPC, `BikeNpc.gd` tách từ rival Màn 2, chuông = `play_sfx('res://assets/audio/absent_gameover.wav')` (không gọi `_trigger_absent_screen` vì nó ghi thua vào kỷ lục Màn 1). Giới hạn ≤30 nhân vật có Animator, đám đông xa bake MultiMesh. Ngày công 4, bựa 3/5, vượt spec §4 (đồng hồ động + lịch NPC). Bản rẻ hơn: sự kiện "Stampede" trong bua-07.

**3.3 Nhóm gộp từ 28 ý còn lại** (chỉ nêu tên, chi tiết ở phụ lục): bua-07 BuaDirector, life-01 đồng hồ + lịch NPC theo tiết, life-06 đám đông quay clip, explore-05/meme-05/loop-04 gộp thành "Album group FB có đề bài", explore-02 thang máy tầng B1, explore-03 tờ rơi manh mối, meme-08 đánh Trống Đồng, loop-05 gara, loop-06 tủ đồ huy hiệu, life-07/explore-06 campus đêm, life-08 động vật, meme-07/explore-04 F-Bus, explore-01 lên nóc, loop-03 đồ lụm, bua-05 độ dị, loop-02 thời khoá biểu ngày, life-04 sự kiện lớn.

## 4. Bẩn bựa trong thế giới mở

| # | Sự kiện | Cách kích hoạt |
|---|---|---|
| 1 | Freeze frame "ĐÚNG VẬY, ĐÓ LÀ TÔI" + tem "ĐI CHĂN HEO" xoay -12° | Bị Toàn Nổ bắt khi chạy Shift trong nón 8 m, chọn bỏ chạy và bị rượt kịp trong 6 s |
| 2 | Thầy nod, bỏ qua, nhưng vẫn nói "Nhà tôi không có gì ngoài tiền" | Trong 2 s bấm E cúi chào (clip bow) |
| 3 | Toàn Nổ ngồi uống cà phê một mình ở hiên căn tin, caption "Anh Minh bên Marvell không nghe máy" | Mở đủ 20 câu trong Sổ tay Toàn Nổ |
| 4 | Thư cảnh cáo CTSV ở sảnh, Toàn Nổ đứng cạnh "Điểm rèn luyện này tôi cho vì thương" | ĐRL dưới 50 khi bước vào Sảnh Trống Đồng |
| 5 | Cô Ba hét "KHAY CỦA CÔ", khay bay thẳng vào camera, người chơi flinch + shake | Bấm G vào NPC role `cook` |
| 6 | Minh nhìn thẳng camera kiểu The Office, cả thế giới đứng im 1 s, caption "…" | Bấm G vào NPC role `minh` (slow_motion 0.02, 1.0 s) |
| 7 | Linh hiện trái tim bay lên rồi lập tức "seen" | Bấm G vào NPC role `linh` |
| 8 | COMBO BỰA x5: mọi NPC trong 20 m quay lại facepalm cùng nhịp + vuvuzela | Chọc 5 NPC khác nhau trong 30 s |
| 9 | Thẻ dây cam bay quay chậm + tiếng ruồi, hàng xe sau bấm còi, chú Bảy chửi theo nhịp còi | Trượt QTE quẹt thẻ; thanh kiên nhẫn của hàng xe tụt |
| 10 | "Thẻ VIP": barie tự mở trước khi quẹt, chú Bảy bow | 5 lần "quẹt 1 phát ăn ngay" liên tiếp |
| 11 | Phúc bật dậy "Em đang debug trong mơ", đi đúng 10 m rồi gục ngủ tiếp ở chỗ kế | Mash SPACE 14/4 s cạnh Phúc |
| 12 | Phúc ngủ trên đầu Cóc Vàng, sét đánh flash trắng, vẫn không dậy, caption "SEEN KHÔNG REP LÀ CÓ LÝ DO" | Tìm đủ 10 chỗ ngủ |
| 13 | Selfie: NPC bốc tư thế dab/plank/stance + biểu cảm ngẫu nhiên, caption "chụp giúp mình điểm danh với" | Chế độ P, đứng cạnh NPC bấm G |

(Tầng 2 thêm: TU.EXE ngừng hoạt động, "ĐÃ CHUYỂN KHOẢN 200K", Dolly nhân bản, sét đánh khi tắm hồ sen ban đêm, xe bị Lò Văn Lụm chở đi.)

## 5. NPC và lịch campus

v1.2 không có đồng hồ chạy; "giờ" là 4 preset của `GameFX.TOD_PRESETS` đổi bằng T. Lịch dưới dùng preset và clip có thật trong `CharacterBuilder` (chạy = `set_speed` + `set_param('run')`, không có clip run).

| Preset (giờ ngụ ý) | Ai | Ở đâu (hàm) | Làm gì (clip) |
|---|---|---|---|
| dawn (07:00-07:30) | Chú Bảy (`guard`) | `park_gate_guard_pos()` | `guard`, `wave` khi xe tới, `facepalm` khi trượt thẻ |
| dawn | 12 sinh viên (`student_m/f`, `casual`) | từ `back_gap_u()` qua sân trong tới `stair_foot()` | đi nhanh, vài người `phone` vừa đi |
| dawn | Toàn Nổ (`lecturer_boss`) | `lobby_center()` | xuất hiện lần đầu, `nod`, bắt đầu tuần |
| dawn | Phúc (`student_m` spiky) | chỗ ngủ theo seed | `sleepy_sit`/`lie`, ngáy 3D |
| dawn | Tú (`student_m`) | máy Monster `MONSTER_POS` | `phone` |
| morning (07:30-11:30) | Nhóm sinh viên | hiên vòng cung, ghế đá | `sit`, `type`, `phone` |
| morning | Linh (`student_f`) | bờ hồ sen `pond_center()` | `phone`, nhìn về người chơi khi tới gần |
| morning | Minh (`student_m` glasses) | ghế gần `stair_foot()` | `type` (laptop PropBuilder) |
| morning | CLB Vovinam (`vovinam`, `master`) | sân võ | `stance`, `punch`, `kick` luân phiên |
| morning | Toàn Nổ | tuyến lobby → canteen → back_gap → stair_foot | tuần, `facepalm` khi thấy người chạy |
| noon (11:30-13:30) | Cô Ba (`cook`) + 10 sinh viên | `canteen_center()` | `carry`, `eat`, `sit`; Phúc `lie` dưới gầm bàn |
| noon | Chú Bảy | bốt bảo vệ | `sleepy` (ngáp) |
| noon | Toàn Nổ | hiên căn tin | `eat` một mình, chỉ nổi giận khi bị chọc |
| noon | Băng tool (tầng 2, `casual` cap) | làn bãi xe | `phone`, bám theo |
| night (18:00+) | Chú Bảy | bốt | `sleepy`, đèn pin (tầng 3) |
| night | Nhóm Capstone (Minh, Linh, 2 `student`) | chân thang (Lab 402 chưa lên được) | `type`, `slump`, 1 người `sleepy` |
| night | Tú | máy Monster | `slump` sau lon 3 (tầng 2) |
| night | Phúc | mép bệ Cóc Vàng | `sleepy_sit`; sét khi đủ bộ sưu tập |
| night | Toàn Nổ | không tuần; đứng ở sảnh nếu ĐRL < 50 | `nod`, một câu CTSV |

## 6. Kiến trúc kỹ thuật

Scene và script mới (thư mục mới `scripts/roam/`, thống nhất một tên, không dùng song song `freeroam/`):
- `scenes/FreeRoam.tscn` + `scripts/roam/FreeRoam.gd`: host, dựng campus `colliders:true`, Ground StaticBody 600x0.4x600 như Stage2, `parking_gaps` cho ô xe mình, 7 Area3D điểm nóng, spawner NPC gắn `meta role` (student/guard/cook/lecturer/minh/linh/tu/phuc), HUD ví.
- `scripts/roam/ThirdPersonController.gd`: CharacterBody3D, WASD theo basis camera (từ EOS), trọng lực, Shift sprint, cờ `input_locked`, `camera_roll`, `apply_monster()` (tầng 2).
- `scripts/roam/RoamNpc.gd`: walker waypoint kinematic (từ Stage5), `[E]` một câu, `get_animator()`.
- `scripts/roam/RoamClock.gd`: v1 chỉ giữ preset hiện tại + signal `preset_changed`; tầng 3 nâng thành CampusClock có phút.
- `scripts/roam/ToanPatrol.gd`, `NpcReactions.gd`, `CardSwipeQTE.gd`, `PhucSpots.gd`, `MashPrompt.gd`; `scripts/ui/FreezeFrame.gd` (tầng 2 thêm `FbPostOverlay.gd`, `ToadShrine.gd`, `ParkingFinder.gd`, `TuMonster.gd`, `PrankSystem.gd`, `ToolGang.gd`).
- Tests: `tests/test_free_roam.gd` (smoke 300 frame, không SCRIPT ERROR), mỗi hạng mục 1 test theo mẫu `test_stage_extra_eos.gd`; thêm FreeRoam vào `smoke_all_stages.gd` và `test_hud_bounds.gd`.

Dữ liệu lưu (`user://progress.cfg`, section mới `[roam]`, đọc/ghi trong chính `save_progress/load_progress`, có tham số path để test headless ghi được):
`wallet`, `drl`, `gate_best_time`, `gate_vip_streak`, `toan_survived`, `toan_caught`, `toan_lines` (bitmask 20), `phuc_found` (bitmask), `combo_best`, `photos_taken`, `shrine_day` (tầng 2). `inventory` vẫn chỉ sống trong phiên như spec v2. `best_stats` giữ nguyên khoá int.

Gắn với StageManager / StoryDirector:
- Điểm nóng gọi `StageManager.change_stage(id)` sau khi đặt `return_to_roam = true` và `roam_spawn = hotspot_id`; modal kết quả thêm nút "Về campus" (hiện chỉ có next/hub/menu).
- `report_stage_result()` là nơi duy nhất cộng CV/ĐRL cho mini-game; cờ `via` (tầng 2) đi cùng dict result.
- `StageManager._input` bỏ qua M khi scene hiện tại là FreeRoam; J mở bảng ĐRL ở mọi scene.
- StoryDirector (chưa có trong code) sẽ dùng lại: `ToanPatrol.LINES` chuyển sang `story/Lines.gd` khi file ra đời, `FreezeFrame.gd` cho Cinematic §2.3, `TuMonster.overdose()` cho kịch bản Thứ Năm, `FbPostOverlay` cho lệnh `post` §2.2, preset `lecturer_boss` dùng chung.

Helper cần thêm vào kho chung (mỗi cái vài dòng, làm một lần ở tuần 1):
- `FPTUCampusBuilder`: `toad_pos()`, `pond_center()`, `lobby_center()`, `parking_slots()`, `lobby_elevator_doors()` (tầng 3), opts `stair_colliders`, `pond_collider`, `toad_climbable`, đặt tên node `ToadEyeL/R`.
- `CharacterBuilder`: preset `lecturer_boss`, tóc `receding`, opts `cap`/`cap_color`/`watch_scale`, clip `dab`, `flop`, `photo`.
- `GameFX._synth`: `whistle`, `vuvuzela`, `snore`, `fly`, `absent_bell` (port 15 dòng từ HUDManager).
- `PropBuilder`: `build_vending_machine()` tách từ Stage2 (tầng 2), `build_student_card()`.
- `PlayerBike`: `@export fallback_respawn`, không tự tìm `RoadSystem/RoadTrack/RoadPath` trong FreeRoam.

Hiệu năng:
- `Animator` đã có LOD CPU (>35 m bỏ 3 frame, >80 m bỏ 8, >140 m đóng băng); giới hạn ≤30 NPC có Animator trong FreeRoam, mỗi nhân vật code ~30 MeshInstance3D nên 25 NPC ≈ 750 draw call, chấp nhận được; đám đông xa (tầng 3) dùng `pose()+bake()` vào MultiMesh với `rigged=false`.
- NPC thế giới mở dựng thân code (rigged=false): bake được, đủ clip; thân Quaternius chỉ map 8 clip và `bake()` trả rỗng.
- Collider chỉ ở tầng trệt + sàn + (sau này) bậc thang, không bật collider tầng trên; Jolt `areas_detect_static_bodies` đã bật.
- `upgrade_scene_visuals` nhân bản Environment và bật lại SDFGI mỗi lần gọi: chỉ gọi khi preset đổi.
- Âm thanh: AudioStreamPlayer3D chỉ cho ngáy, bíp chìa, còi xe NPC; còi giới hạn 3 nguồn đồng thời; `GameFX.popup` tối đa 4 chồng.
- Không gọi `slow_motion` khi đang pause; test headless không được dựa vào `Engine.time_scale = 6` ở những đoạn có slow-mo (hàm này đặt lại 1.0 vô điều kiện).

## 7. Thứ tự làm và tổng ngày công

| Tuần | Việc | Ngày công |
|---|---|---|
| Tuần 1 | Tầng 0: FreeRoam.tscn, ThirdPersonController, RoamNpc, T preset, F xe, section `[roam]`, nút "Về campus", helper builder/synth/clip, smoke test | 4.5 |
| Tuần 2 | loop-01 ví + ĐRL (3) rồi meme-03 quẹt thẻ (3, dùng PlayerBike vừa gắn) | 6 |
| Tuần 3 | bua-01 Toàn Nổ đi tuần + preset lecturer_boss + FreezeFrame (4.5); bắt đầu bua-08 (0.5) | 5 |
| Tuần 4 | bua-08 còn lại (1.5), bua-03 Phúc (2), chạy toàn bộ test + smoke, chỉnh nhịp, chốt v1.2 (1) | 4.5 |

Tổng tầng 1 (kể cả nền): 4.5 + 3 + 3 + 4.5 + 2 + 2 = 19 ngày công, cộng 1 ngày đệm chốt = 20 ngày, tức 4 tuần làm việc. Nếu cần ra sớm, cắt bua-03 sang v1.3 còn 17 ngày. Tầng 2 ước 16 ngày (meme-04 3, explore-08 3, bua-04 2.5, bua-06 3.5, bua-02 4), ship theo từng hạng mục.

## 8. Câu hỏi cần chủ dự án quyết định

1. **Vượt spec §6 (không nhiệm vụ phụ):** các bộ sưu tập (Sổ tay Toàn Nổ, chỗ ngủ Phúc, Album bựa, tờ rơi) là "nhiệm vụ nhẹ". Khuyến nghị: duyệt dưới dạng sưu tập không có quest log, không có NPC giao việc; NPC vẫn chỉ nói một câu.
2. **Buff vía có được đổi kỷ lục mini-game không (meme-04)?** Khuyến nghị: cho phép, nhưng ghi cờ `via` vào result và hiện dấu * trong bảng kỷ lục; ở Màn 3 buff chỉ giảm rủi ro fail (công thức điểm không dùng thời gian) nên an toàn.
3. **Bảng phím:** E tương tác, F lên/xuống xe, G chọc, H/B còi, K bíp chìa, J bảng ĐRL, M bản đồ (StageManager nhường), P chụp, T đổi giờ, SPACE mash. Khuyến nghị: chốt bảng này ngay tuần 1 và ghi vào spec §4 để không đổi về sau.
4. **Đồng hồ:** v1.2 chỉ 4 preset tĩnh đổi bằng T, hay làm đồng hồ chạy 1 phút game = 10 s ngay? Khuyến nghị: preset tĩnh cho v1.2 (mọi hạng mục tầng 1 đều chạy được), đồng hồ động để tầng 3 cùng meme-06/life-01 với T tua tới mốc.
5. **Ví + ĐRL đặt ở đâu:** autoload mới hay thành viên StageManager? Khuyến nghị: thành viên StageManager, lưu trong section `[roam]` của progress.cfg; autoload mới sẽ vỡ 15 test headless đang tự tạo autoload bằng tay.
6. **Sink đầu tiên của ví:** tầng 1 chưa có chỗ tiêu. Khuyến nghị: ship kèm một sink nhỏ ngay v1.2 là mua lon Monster bằng CV tại máy sau toà nhà (tách `build_vending_machine` sớm, 0.5 ngày), máy trong Màn 2 vẫn miễn phí; vía Cóc Vàng và Tú theo sau ở v1.3.
7. **Mở khoá khu vực theo ĐRL (sân thượng, gara, cổng sau):** campus không có gara/cổng sau, mái không có collider. Khuyến nghị: hoãn; ĐRL ở v1.2 chỉ mở caption/sticker chụp ảnh và câu thoại Toàn Nổ, bàn lại khi explore-01 (lên nóc) được làm.

## 9. Phụ lục: toàn bộ ý tưởng

| ID | Tên | Điểm TB | Trạng thái | Lý do |
|---|---|---|---|---|
| meme-03 | Quẹt thẻ dây cam 07:29 | 8.67 | Tầng 1 | Rẻ nhất bảng, tái dùng barie/guard nag Màn 2, clip 20 s hoàn chỉnh |
| bua-01 | Toàn Nổ đi tuần campus | 8.67 | Tầng 1 | Linh hồn hài của game, preset lecturer_boss cốt truyện cũng cần |
| bua-08 | Một phím chọc NPC + selfie | 8.25 | Tầng 1 | 2 ngày biến mọi NPC thành đồ chơi, clip có sẵn gần hết |
| explore-08 | Tìm xe trong bãi gần 200 chiếc | 8.17 | Tầng 2 | Nỗi đau thật, nhưng cần F xe + nhánh ngày lụm với 2 PlayerBike |
| bua-03 | Phúc ngủ gục khắp nơi | 8.17 | Tầng 1 | 2 ngày, hài vô vọng đúng nhân vật, 10 chỗ chắc chắn có sàn |
| bua-04 | Tú và lon Monster thứ tư | 8.00 | Tầng 2 | Cần tách máy bán nước + buff controller; overdose() dùng lại cho truyện |
| bua-02 | Băng tool IB ANH CỨU | 7.92 | Tầng 2 | 4 ngày, NPC bám đuôi cần CharacterBody3D, cảnh Gia Mẫn chờ mái có collider |
| meme-01 | Hội thánh chờ thang máy sảnh G | 7.83 | Tầng 3 | Phải khoét cabin trong khối link, trùng phần đầu explore-02 |
| meme-04 | Cóc Vàng xin vía | 7.83 | Tầng 2 | Sink tự nhiên của ví, buff làm bẩn kỷ lục nên cần duyệt trước |
| loop-01 | Ví Cóc Vàng + ĐRL | 7.75 | Tầng 1 | Xương sống tiến trình, mọi ý khác cần nó, 3 ngày |
| meme-06 | Giờ G 07:25 cả campus chạy slot 1 | 7.50 | Tầng 3 | Cần đồng hồ động + lịch NPC + bake đám đông, bản rẻ là Stampede trong bua-07 |
| bua-06 | Trò nghịch: còi, hồ sen, Cóc Vàng | 7.50 | Tầng 2 | Bựa 5/5 nhưng 3.5 ngày và cần sửa collider hồ/cóc |
| loop-02 | Thời khoá biểu ngày: 3 thử thách theo seed | 7.3 | Tầng 3 | Cần biến thể trong từng màn (mưa, ngân sách, BPM), đụng cân bằng đã test |
| life-06 | Đám đông phản ứng + lên group FB | 7.3 | Tầng 3 | Gộp vào bua-08 combo + FbPostOverlay của bua-02 khi hai cái đó xong |
| bua-07 | Đạo diễn sự kiện bẩn bựa (BuaDirector) | 7.2 | Tầng 3 | Lập lịch sự kiện cần Cinematic §2.3 và nhiều NPC behavior chưa có |
| meme-08 | Đánh Trống Đồng busking | 7.1 | Tầng 3 | Tái dùng rhythm Màn 4 được, nhưng rượt quanh sảnh cần AI guard như ToanPatrol |
| explore-03 | 7 tờ rơi manh mối băng tool | 7.1 | Tầng 3 | Gộp với tờ rơi bua-02; vài vị trí (chiếu nghỉ, phòng 311) chưa tới được |
| explore-05 | Album Cóc Vàng: 12 đề bài + bộ lọc | 7.1 | Tầng 3 | Gộp với meme-05/loop-04 thành một "Album group FB" sau khi P có selfie |
| meme-05 | Chụp ảnh đăng group FPTU Hóng Hớt | 7.0 | Tầng 3 | Trùng explore-05; kiểm tra khung bằng frustum + role là đủ, không cần nhận dạng ảnh |
| explore-02 | Thang máy chữ G và tầng B1 | 7.0 | Tầng 3 | Cần cabin có collider + 11 hành lang dựng tại chỗ; làm chung với meme-01 |
| loop-04 | Album group FB: 24 đề ảnh + feed | 6.9 | Tầng 3 | Trùng explore-05, giữ phần like đổi CV khi ví đã chạy |
| meme-07 | F-Bus ngủ gật lạc sang HUTECH | 6.8 | Tầng 3 | Cần trạm bus + tuyến bus; gộp explore-04 |
| life-07 | Đêm campus: tuần tra, lab đêm, 311 | 6.6 | Tầng 3 | Preset night có sẵn, nhưng đèn pin nón sáng + tuần tra là ToanPatrol phiên bản đêm, làm sau |
| meme-02 | Mưa ngập D1 lội nước | 6.5 | Loại | Mực nước dâng + chết máy là hệ thống mới, mưa Màn 1 nội bộ không tái dùng được |
| explore-06 | Giới nghiêm 22h trốn chú Bảy | 6.4 | Tầng 3 | Gộp vào life-07, cần nón đèn pin + 5 bí mật đêm nhiều geometry |
| bua-05 | Độ dị của NPC (Quirk Gene) | 6.4 | Tầng 3 | Chỉ là tham số build + biến thể clip, rẻ, nhưng không có loop riêng nên để sau bua-08 |
| loop-03 | 30 đồ lụm được + sổ tay | 6.3 | Tầng 3 | Hơn nửa vị trí ở sân thượng/chiếu nghỉ chưa có collider |
| life-08 | Động vật campus | 6.3 | Tầng 3 | Rẻ (MultiMesh), làm campus sống, ưu tiên sau khi loop chính ổn |
| life-04 | Sự kiện lớn: cúp điện, ngày hội CLB | 6.3 | Tầng 3 | Gộp vào bua-07 BuaDirector |
| loop-05 | Gara độ xe bằng Cóc Vàng | 6.1 | Tầng 3 | Sink lớn tốt, nhưng cần ví chứng minh trước và kỷ lục xe zin/xe độ tách riêng |
| explore-04 | Đi nhờ F-Bus vòng D1 | 6.1 | Tầng 3 | Gộp meme-07; tuyến bus khép kín cần đường D1 dài hơn hiện có |
| explore-01 | Lên nóc trường | 6.0 | Tầng 3 | Mái và thang kỹ thuật không có collider, cần nhảy mép mái chưa có |
| loop-06 | Tủ đồ 36 huy hiệu | 5.9 | Tầng 3 | CharacterBuilder opts đã đủ để đổi trang phục, chờ có đủ thành tích để treo |
| life-03 | Thời tiết Sài Gòn | 5.6 | Loại | Máy trạng thái thời tiết + hành vi đám đông, điểm thấp so với công |
| loop-07 | Kinh tế căn tin + làm thêm | 5.4 | Loại | Quá sâu cho 1 người, đụng cân bằng Màn 5 đã test |
| life-01 | Đồng hồ campus + lịch NPC theo tiết | 5.4 | Tầng 3 | Gộp vào meme-06 CampusClock khi làm |
| life-02 | Giao thông D1 thở theo giờ | 5.1 | Loại | TrafficSpawner cần road_path, bus theo lịch cần đồng hồ, ít hài |
| loop-08 | Bóng ma kỷ lục + bảng vàng 3 hồ sơ | 4.8 | Loại | Replay 10 Hz + 3 hồ sơ đổi định dạng save, không bựa |
| explore-07 | 5 đường chạy có bóng ma | 4.7 | Loại | Cần mái tôn, lá sen chìm, bóng ma; geometry và vật lý chưa có |
| life-05 | Âm thanh môi trường theo vùng/giờ | 4.3 | Loại | Đẹp nhưng không có loop, để MusicDirector mở rộng sau khi mọi thứ khác xong |
