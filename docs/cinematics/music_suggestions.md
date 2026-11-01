# Nhạc và âm thanh cho cinematic: bài đã chọn và gợi ý

Cập nhật: 2026-10-25 (thêm bảng mọi slot nhạc; game không còn nhạc tạo bằng code).

Gu chung là kiểu phim *Nobody*: nhạc cũ, vui, đặt ngược với cảnh hành động hoặc thảm họa.

**Trạng thái 2026-10-25:**
- Bạn đã tải mọi bài gợi ý bên dưới, toàn bộ bài trong mục Đã chốt và 12 âm thanh. Tất cả đã nằm trong `music\` và `sfx\` trên máy.
- Mỗi bài được cắt bỏ đoạn im lặng ở đầu. Riêng các replay ngắn bắt đầu ở chỗ bài vào đoạn mạnh.
- Cả 2 bài `seg_d0_race` (*Deja Vu*) và `seg_d2_chase` (*Tokyo Drift*) đã có trong `music\`.
  - *Deja Vu* bắt đầu từ giây 38,8 của file gốc, ngay trước điệp khúc "Deja vu!". Điệp khúc được dò bằng đoạn lặp nhiều nhất trong bài, nên có thể lệch một nhịp.
  - *Tokyo Drift* bắt đầu từ giây 11,4, đoạn hook "I wonder if you know…".
- Cả 39 bài nhạc và 13 âm thanh đều đã được nạp thử qua bộ đọc file của game: đọc được hết.
- Điểm cắt chính xác cho từng cảnh chưa làm sẽ chỉnh khi dựng cảnh đó.

## Cách dùng

- Bạn tự tải hoặc tự thu file, rồi bỏ vào thư mục dữ liệu của game: `%APPDATA%\Godot\app_userdata\FPTU Student Simulator- Godot 4 Edition\`.
  - Nhạc đặt ở `music\<tên cảnh>.ogg` hoặc `.mp3`, ví dụ `music\seg_d0_race.mp3`.
  - Âm thanh đặt ở `sfx\<tên âm>.ogg`, `.mp3` hoặc `.wav`, ví dụ `sfx\bonk.ogg`.
  - Video intro tự tạo đặt ở `video\ai_intro_m.ogv` (nam) hoặc `video\ai_intro_f.ogv` (nữ).
- Không có file nhạc thì chỗ đó **im lặng**: game không còn nhạc tạo bằng code ("tuyệt đối không xài nhạc code nữa"). Thiếu file âm thanh hiệu ứng thì game vẫn dùng âm tự tạo.
- File dài hơn cảnh sẽ mờ dần trong 0,5 s cuối.
- **Các file này chỉ nằm trên máy, không bao giờ commit lên git hay đưa vào bản phát hành.**
- Bỏ cả bài vào thư mục Downloads là Claude có thể dò nhịp và cắt đúng đoạn hay nhất cho từng cảnh. Độ dài và các nhịp đánh của mỗi cảnh nằm trong `docs/cinematics/<tên cảnh>.txt`.

## Toàn bộ chỗ đặt nhạc (slot)

Mỗi dòng là một file `music\<slot>.ogg` hoặc `music\<slot>.mp3`. Nhạc nền (menu, thế giới mở, màn chơi, nhiệm vụ, đêm) tự lặp lại và chuyển bài mờ dần 1,2 s; nhạc cảnh và replay phát một lần.

**Nhạc nền, màn chơi và nhiệm vụ**

| Slot | Phát khi | Bài | Bài thay thế |
|---|---|---|---|
| `menu` | menu chính, tạo nhân vật | *Nightcall*, Kavinsky | |
| `roam_day` | thế giới mở ban ngày, đi bộ hay chạy xe (sáng, trưa, chiều, hoàng hôn) | *Take On Me*, a-ha | *Self Control*, Laura Branigan |
| `roam_night` | thế giới mở ban đêm, đi bộ hay chạy xe | *Resonance*, HOME | *Midnight City*, M83 |
| `stage1_race` | Màn 1 đua xe | *Running in the 90s*, Max Coveri | |
| `stage2_parking` | Màn 2 bãi xe | *Gonna Fly Now* (nhạc Rocky), Bill Conti | |
| `stage3_classroom` | Màn 3 lớp học | *Clair de Lune*, Debussy | |
| `stage4_vovinam` | Màn 4 Vovinam (trống võ đường vẫn đánh từng phách 85/110/135 BPM, nhạc nằm bên dưới) | *Kung Fu Fighting*, Carl Douglas | |
| `stage5_canteen` | Màn 5 căn tin | *Flight of the Bumblebee*, Rimsky-Korsakov | |
| `stage6_capstone` | Màn 6 boss capstone | *Harder, Better, Faster, Stronger*, Daft Punk | |
| `stage_extra_exam` | Màn phụ thi cuối kỳ | *Mission: Impossible Theme*, Lalo Schifrin | |
| `mission_stakeout` | nhiệm vụ rình bãi xe (Ngày 1) | *Secret Agent Man*, Johnny Rivers | |
| `mission_chase` | nhiệm vụ đuổi theo Mũ Đỏ (Ngày 1) | *Chase*, Giorgio Moroder | |
| `mission_fight` | trận tay không Ngày 1 và Ngày 4 | *Holding Out for a Hero*, Bonnie Tyler | |
| `mission_canteen` | nằm vùng căn tin (Ngày 4); phát nhỏ hơn 6 dB để còn nghe tiếng ngân nga của Dolly | *Careless Whisper*, George Michael | |
| `mission_corridor` | hành lang tối (Ngày 1) | *Tubular Bells* (đoạn mở đầu), Mike Oldfield | |

Độ căng chỉ đổi âm lượng; riêng Màn 1 (tốc độ) và boss Màn 6 (máu boss) nhạc còn sáng dần lên (bớt lọc trầm). Không bao giờ đổi bài. Nhạc thế giới mở phát tiếp từ chỗ đang nghe sau nhiệm vụ, cinematic hay video. Replay có bài riêng thì nhạc nền tắt dần trong lúc replay. File nên là bản cắt vài phút: game đọc cả file vào bộ nhớ (đọc trước trên luồng phụ).

**Tòa nhà đêm (Ngày 4 và chạy riêng màn Night Building)**

| Slot | Phát khi | Bài |
|---|---|---|
| `night_stealth` | chưa con cừu nào nghi ngờ | *Stranger Things* (nhạc chủ đề), Kyle Dixon & Michael Stein |
| `night_tense` | có con nghi ngờ hoặc đang lùng sục | *It Follows* (Title), Disasterpeace |
| `night_chase` | có con đang đuổi | *Halloween Theme*, John Carpenter |
| `night_escape` | đủ 3 cầu chì, cửa sảnh mở, chạy ra | *Turbo Killer*, Carpenter Brut |

Lúc trốn trong tủ hay gầm bàn, nhạc tắt dần chỉ còn tim đập và tiếng thở. Đổi qua lại giữa yên / căng / bị đuổi giữ mỗi bài ít nhất 2 s. Mỗi bài nhớ chỗ đang phát: quay lại trạng thái cũ thì bài phát tiếp từ chỗ đó.

**Cảnh phim (cinematic)**

| Slot | Bài |
|---|---|
| `ai_intro` | *The End of the World*, Skeeter Davis |
| `cine_d0_wake` | *Wake Me Up Before You Go-Go*, Wham! |
| `cine_d0_brief` | *Peter Gunn Theme*, Henry Mancini |
| `cine_d0_exam` | *I Got You (I Feel Good)*, James Brown |
| `cine_d0_midnight` | *Mr. Sandman*, The Chordettes |
| `cine_day_start` | *Good Morning* (*Singin' in the Rain*) |
| `cine_d1_intro` | *The X-Files Theme*, Mark Snow |
| `cine_d1_corridor` | *The Murder* (Psycho), Bernard Herrmann |
| `cine_d1_choice` | *Mad World*, Gary Jules |
| `cine_d1_choice_cover` (đuôi lựa chọn: che cho Phúc, "…Hai tô.") | *With a Little Help from My Friends*, Joe Cocker |
| `cine_d1_choice_report` (đuôi lựa chọn: báo cáo Phúc) | *The Sound of Silence*, Simon & Garfunkel |

Hai đuôi lựa chọn không có file riêng thì phát file của `cine_d1_choice`; không có cả file đó thì im lặng.
| `cine_d1` | *Green Onions*, Booker T. & the M.G.'s |
| `cine_d4_intro` | *Stayin' Alive*, Bee Gees |
| `cine_d4_stare` | *The Lonely Shepherd*, Gheorghe Zamfir |
| `cine_d4` | *Every Breath You Take*, The Police |
| `seg_d1_brawl` | *I've Gotta Be Me* |
| `seg_d4_brawl` | *Ain't That a Kick in the Head*, Dean Martin |
| `wanted_busted` (bị bắt khi bị truy nã) | *Bad Boys*, Inner Circle |

**Replay ngắn**

| Slot | Bài |
|---|---|
| `seg_d0_race` | *Deja Vu*, Dave Rodgers |
| `seg_d0_exam` | *Bad to the Bone* (riff) |
| `seg_d1_chase` | *Yakety Sax* |
| `seg_d4_escape` | *Ghostbusters* |

Không có nhạc riêng (chỉ âm thanh hiệu ứng): cuộc gọi 3 giờ sáng (nhạc chuông, tiếng thì thầm), lao động công ích, thẻ giới thiệu, thẻ ngày. Loa kẹo kéo là vũ khí: file `sfx\loa_keo_keo` của bạn.

**Phase C: Ngày 2, 3 và 5 (2026-10-26, spec C-D11)**

| Slot | Phát khi | Bài |
|---|---|---|
| `cine_d2_intro` | Anh Duy dò đường Bầy Sói (14 s) | *Who Let the Dogs Out*, Baha Men |
| `mission_bike_chase` | rượt xe đá Bầy Sói, BE6 ra cầu Rạch Hầm (Ngày 2) | *Tokyo Drift*, Teriyaki Boyz (bản gốc từ đầu: beat vào ở 4.15 s, khớp `OPEN_DROP_S`) |
| `mission_bike_chase_b` | đợt 3 của cuộc rượt sau khi Sói Xám vượt mặt (không có file thì Tokyo Drift chạy tiếp) | *Gas Gas Gas*, Manuel |
| `boss_d2` | đấu tay đôi Sói Xám dưới cầu Rạch Hầm | *Hungry Like the Wolf*, Duran Duran |
| `race_d2_drift` | đua drift một vòng với Sói Xám quanh cầu Rạch Hầm; bắt đầu đúng lúc "ĐI!", đếm ngược không có nhạc | *Deja Vu*, Dave Rodgers (bản cắt từ điệp khúc, đã có); khác: *Running in the 90s*, Max Coveri |
| `cine_d2` | Sói Xám bị trói vào cột (18 s) | đã có |
| `seg_d2_boss` | cảnh đánh lớn 25 s dưới cầu | *Heartbreaker*, Pat Benatar (đã có) |
| `cine_d3_intro` | chạy xe đêm tới kênh (14 s) | *A Real Hero*, College & Electric Youth |
| `mission_sneak` | lẻn vào bến container | *Sneaky Snitch*, Kevin MacLeod |
| `cine_d3_mannequins` | cửa container mở, ma-nơ-canh quay đầu, "Surprise!" (10 s) | *Toccata and Fugue in D minor*, J. S. Bach |
| `mission_gunfight` | đấu súng ở bến container | *Bang Bang (My Baby Shot Me Down)*, Nancy Sinatra |
| `meme_mannequin` | ma-nơ-canh đứng im khi lính quay lại, kiểu "mannequin challenge" (Ngày 3, Wave 3) | *Black Beatles*, Rae Sremmurd |
| `meme_coffin_dance` | bảo vệ khiêng thùng kính | *Astronomia*, Vicetone & Tony Igy |
| `boss_d3` | trùm xe nâng Alexander | *Copacabana*, Barry Manilow |
| `cine_d3` | cái tên vô tận bị cắt ngang, USB rơi (18 s) | đã có |
| `seg_d3_boss` | cảnh đánh lớn 25 s ở bến container | *Straighten Up and Fly Right* (đã có) |
| `cine_d5_intro` | Anh Duy giải mã USB (14 s) | *Technologic*, Daft Punk |
| `mission_basement` | đi lén dưới hầm server | *Oxygène (Part IV)*, Jean-Michel Jarre |
| `cine_d5_monitors` | mặt Za Mẫn cười trên 50 màn hình (10 s) | *Mr. Roboto*, Styx |
| `mission_gunfight_d5` | đấu súng dưới hầm | *Blue (Da Ba Dee)*, Eiffel 65 |
| `mission_typing` | gõ phím xoá Lọ Thần 9.0 | *Around the World*, Daft Punk |
| `mission_fire_hack` | phòng server bốc cháy, gõ phím trong lúc đếm ngược (Ngày 5, Wave 3) | *Disco Inferno*, The Trammps |
| `cine_d5_choice` | phòng server cháy, lựa chọn 2 (14 s); đuôi `cine_d5_choice_accept` / `cine_d5_choice_refuse` dùng chung bài này | *Don't Worry, Be Happy*, Bobby McFerrin |
| `boss_d5` | đấu kiếm Za Mẫn | *Battle Without Honor or Humanity*, Tomoyasu Hotei |
| `seg_d5_boss` | cảnh đánh lớn 25 s trong phòng server | *The Good Life*, José James (đã có) |
| `cine_d5` | dòng tiền chỉ về Trà Sữa Lọ (18 s) | đã có |
| `cine_d7_intro` | bình minh, Anh Duy báo 08:00 tool lên hệ thống thi, Mr.T "giữ cửa thang máy" (13 s) | *Lux Aeterna* (nhạc phim *Requiem for a Dream*), Clint Mansell |
| `cine_d7_monologue` | Lùm Văn Lọ "Mọi thứ đều nằm trong kế hoạch", búng tay tắt đèn (13 s) | *Sweet Dreams (Are Made of This)*, Eurythmics |
| `end_c` | kết C "Kẻ phản diện mới" (26 s, có credits) | *Money, Money, Money*, ABBA (đã có) |

Nhạc chuông của Sói Xám là âm thanh tự tạo (`ringtone_synth`), không phải nhạc nền.

## Đã chốt

| Cảnh | Bài | Ghi chú |
|---|---|---|
| `seg_d1_brawl` | *I've Gotta Be Me* | file đã có, cắt khớp 25 s |
| `seg_d2_boss` | *Heartbreaker*, Pat Benatar | |
| `seg_d3_boss` | *Straighten Up and Fly Right* | |
| `seg_d4_brawl` | *Ain't That a Kick in the Head*, Dean Martin | |
| `seg_d5_boss` | *The Good Life*, José James | |
| `seg_d6_chase` | *Ring of Fire*, Des Rocs | |
| `seg_d7_phase2` | *The Power of Love*, Jennifer Rush | |
| `seg_d7_finisher` | *What a Wonderful World* | |
| `seg_d0_race` | *Deja Vu*, Dave Rodgers | cắt từ tiếng hét "Deja vu!"; meme drift hợp xe tay ga drift |
| `seg_d2_chase` | *Tokyo Drift*, Teriyaki Boyz | cắt từ intro "I wonder if you know…"; rượt xe đêm Nguyễn Xiển |

## Gợi ý: Ngày 0 (đã chơi được)

| Cảnh | Gợi ý | Vì sao |
|---|---|---|
| `cine_d0_wake` (tỉnh dậy hoảng loạn, 8 s) | *Wake Me Up Before You Go-Go*, Wham!; hoặc *Yakety Sax* | sáng trễ giờ thi |
| `cine_d0_brief` (Mr.T giao việc, 12 s) | *Peter Gunn Theme*, Henry Mancini | không khí điệp viên |
| `seg_d0_exam` (replay bắt tool) | *Bad to the Bone* (riff) | khoảnh khắc "bắt được rồi" |
| `cine_d0_exam` (đắc thắng rồi rợn, 18 s) | *I Got You (I Feel Good)*, James Brown | đang vui thì người cừu xuất hiện |
| `cine_d0_midnight` (mất ngủ, bị hù, 22 s) | *Mr. Sandman*, The Chordettes | bài ru ngủ ngọt mà rợn |
| `ai_intro` (thư đình chỉ, TOANG!, 24 s) | *The End of the World*, Skeeter Davis; hoặc *Que Sera, Sera* | nhạc ngọt phát trên thảm họa |
| `cine_day_start` (tờ lịch bị xé mỗi sáng, 9 s) | *Good Morning* (*Singin' in the Rain*) | vui vẻ trong khi đếm ngược |

## Gợi ý: cảnh cuối các ngày và các kết

| Cảnh | Gợi ý | Vì sao |
|---|---|---|
| `cine_d1` | *Green Onions*, Booker T. & the M.G.'s | groove ngầu, tăng dần |
| `cine_d2` | *Born to Be Wild*, Steppenwolf | băng biker Bầy Sói |
| `cine_d3` | *Mambo No. 5*, Lou Bega | bài toàn đọc tên, hợp cái tên vô tận của Alexander |
| `cine_d4` | *Every Breath You Take*, The Police | "bài hát kẻ bám đuôi", hợp Cừu Dolly |
| `cine_d5` | *Money*, Pink Floyd | tiếng máy tính tiền, dòng tiền |
| `ai_reveal` | *O Fortuna* (Carmina Burana) | hoành tráng kiểu meme |
| `mission_tower` | *Thunderstruck*, AC/DC | dồn dập, leo từng tầng tòa Lọ Academy |
| `boss_d7` | *The Final Countdown*, Europe | trùm cuối, đếm ngược tới 08:00 |
| `end_a` (kết thật) | *September*, Earth, Wind & Fire | |
| `end_b` (thắng nhưng mất bạn) | *Lean on Me*, Bill Withers | |
| `end_c` (thành CEO phản diện) | *Money, Money, Money*, ABBA | |
| `end_d` (trùm bay trực thăng thoát) | *Fly Me to the Moon*, Frank Sinatra | |
| `end_e` (Còn cái nịt) | *Never Gonna Give You Up*, Rick Astley | Rickroll lúc chạy credits |
| `end_f` (học bổng) | *Celebration*, Kool & the Gang | |

## Gợi ý: replay ngắn 4-6 s

| Cảnh | Gợi ý |
|---|---|
| `seg_d1_chase` | *Yakety Sax* |
| `seg_d3_gunfight` | *Misirlou*, Dick Dale |
| `seg_d3_crates` | *Boom, Boom, Boom, Boom!!*, Vengaboys |
| `seg_d4_escape` | *Ghostbusters* |
| `seg_d5_gunfight` | *Kernkraft 400*, Zombie Nation |
| `seg_d5_hack` | *Sandstorm*, Darude |
| `seg_d6_infiltrate` | *The Pink Panther Theme* |
| `seg_d7_floors` | *Eye of the Tiger* |
| `seg_d7_phase1` | *In the Hall of the Mountain King* |

## Gợi ý: hiệu ứng âm thanh (`sfx\<tên>`)

| Âm | Gợi ý |
|---|---|
| `boom` | Vine boom |
| `bonk` | bonk meme (thay cả bonk của vũ khí lẫn của cốt truyện) |
| `sad_trombone` | wah wah wah |
| `record_scratch` | tiếng đĩa xước |
| `ba_dum_tss` | rimshot |
| `dun_dun_duun` | dramatic chipmunk |
| `success_fanfare` | kiểu "mission passed" của GTA |
| `toang_sting` | tiếng tắt máy hoặc báo lỗi Windows XP |
| `phone_ring_3am` | nhạc chuông Nokia cổ điển |
| `music_box` | *Für Elise* bản hộp nhạc |
| `sheep_bleat_distorted` | meme dê hét |
| `static_burst` | nhiễu TV |
| `siuuu` | file của bạn, đã có |
| `bolero` (loa kẹo kéo) | bài bạn chọn, chỉ để trên máy |

## Câu meme có giọng

"Ét o ét!", "Gét gô!", "Tới công chuyện luôn!", "Còn cái nịt", "Xin vĩnh biệt cụ" hiện chỉ có phụ đề.

Cách hay nhất là bạn hoặc bạn bè **tự thu giọng**: vui, không dính bản quyền hay giọng người thật. Khi có file, Claude sẽ thêm chỗ gắn giọng cho từng câu.
