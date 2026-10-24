# Nhạc và âm thanh cho cinematic: bài đã chọn và gợi ý

Cập nhật: 2026-10-25.

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
- Không có file thì game phát nhạc và âm thanh tự tạo bằng code.
- File dài hơn cảnh sẽ mờ dần trong 0,5 s cuối.
- **Các file này chỉ nằm trên máy, không bao giờ commit lên git hay đưa vào bản phát hành.**
- Bỏ cả bài vào thư mục Downloads là Claude có thể dò nhịp và cắt đúng đoạn hay nhất cho từng cảnh. Độ dài và các nhịp đánh của mỗi cảnh nằm trong `docs/cinematics/<tên cảnh>.txt`.

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
| `boss_d7` | *Thunderstruck*, AC/DC | dồn dập |
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
