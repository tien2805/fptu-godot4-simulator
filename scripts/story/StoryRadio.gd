# File: res://scripts/story/StoryRadio.gd
# Radio chatter and typed text presentation (master plan 2026-10-29 Q5 "information moves to radio chatter during gameplay",
# plan 2026-10-29-w2-story T4). A small Node that types a line into a Label letter by letter with the speaker's blip voice
# (DialogueVoice) and shows the "Dịch:" line once the line is complete:
#   say(label, speaker_id, line, dich)      radio line: "<PREFIX>: line" + "\nDịch: dich" (Anh Duy keeps "ANH DUY (bộ đàm)")
#   type_text(label, head, body, tail, voice)  any typed text (the phone toast: head "Phúc: ", no tail)
#   step(dt)                                 advances the typing on the host's clock (missions: their mission clock)
#   reveal() / done() / min_secs()           the whole text at once / typing finished / the time a line needs on screen
# StoryMission.radio() / radio_as() use it; SCRIPTS holds the chatter each mission beat plays on its own clock (lines cut
# from the dialogue cinematics, Q5 pacing): [t (mission seconds), speaker id, line, dich ("" = none)]. A line waits while
# another radio line is on screen. Mission streams may add or replace a beat's lines here.
class_name StoryRadio
extends Node

const PREFIX: Dictionary = {"anh_duy": "ANH DUY (bộ đàm)", "mr_t": "MR.T (điện thoại)", "linh": "LINH (tai nghe)",
	"phuc": "PHÚC (điện thoại)", "chu_bay": "CHÚ BẢY (bộ đàm)",
	"thi_lo": "THỊ LỌ (loa)"}
const READ_PAD: float = 1.6     # seconds a line stays after it finished typing (min_secs)
const VOICE_DB: float = -10.0
## beat id -> [[t, speaker, line, dich], ...] (mission clock seconds, in order)
const SCRIPTS: Dictionary = {
	"d1_stakeout": [
		[9.0, "mr_t", "Chụp rõ mặt shipper đủ 3 cảnh là được. Đừng xông vào nha em.", ""],
		[24.0, "mr_t", "Bãi xe có bảo vệ đi tuần đó em. Thấy ổng thì núp phía bên kia xe.", ""]],
	"d1_chase": [
		[12.0, "chu_bay", "Thằng mũ đỏ chạy về phía cổng Tây đó con! Lu đuổi không kịp!", ""]],
	"d2_chase": [
		[14.0, "anh_duy", "Tụi nó ping nhau 2h, payload trên Nguyễn Xiển, chạy convoy.", "Hàng đi cả đoàn trên Nguyễn Xiển."],
		[46.0, "anh_duy", "Con Sói Xám lag 200ms đó e, aggro nó là nó tilt liền.", "Chọc tức nó là nó chạy ẩu."]],
	"d2_bridge": [
		[8.0, "anh_duy", "Đàn em nó về hết rồi, gầm cầu chỉ còn mình nó, 1v1 đi e.", "Chỉ còn mình nó, đánh tay đôi đi."]],
	"d3_gunfight": [
		[16.0, "anh_duy", "Hàng của Alexander order từ một IP lạ lắm, a đang trace.", "Có người khác đứng sau Alexander."]],
	"d3_crates": [
		[20.0, "anh_duy", "Mỗi thùng kính là một suất thi hộ đó e, smash hết.", "Đập hết, đừng chừa thùng nào."]],
	"d5_stealth": [
		[10.0, "anh_duy", "Server nằm sau phòng UPS, ping 10.13.0.7 là đúng chỗ.", "Đi tới phòng máy cuối hầm."]],
	"d5_gunfight": [
		[12.0, "anh_duy", "Za Mẫn deploy guard theo sprint đó e, hết wave là hết.", "Bắn hết đợt này là xong."]],
	"d6_shop": [
		[24.0, "anh_duy", "Cam quán push lên cloud của bả 5s một lần, a loop feed cũ rồi, e cứ diễn tự nhiên.", "Anh che camera rồi, cứ làm như nhân viên thật."],
		[58.0, "phuc", "Tao ngồi quán cà phê đối diện nè. Bả cứ ngó ra cửa hoài, chắc đang chờ hàng.", ""]],
	"d6_backroom": [
		[7.0, "anh_duy", "Phòng này ko có wifi, a chỉ thấy qua cam trên áo e thôi. Đi chậm, đừng spam phím.", "Anh chỉ thấy qua camera trên áo em. Đi chậm thôi."],
		[60.0, "anh_duy", "Két đời cũ, a brute force mã giùm. E đứng sát rồi giữ E là xong.", "Đứng sát két, giữ E, anh lo phần mã."]],
	"d6_boat": [
		[16.0, "anh_duy", "Cano bả độ máy, top speed hơn e một xíu. Đừng nhả ga là bám được.", "Cano bà ta nhanh hơn chút, cứ giữ ga."],
		[44.0, "phuc", "Tao đứng trên cầu thấy tụi mày nè! Phía trước có sà lan bắn pháo bông, coi chừng pháo lạc!", ""]],
}

var label: Label
var head: String = ""
var body: String = ""
var tail: String = ""
var voice: String = ""
var cps: float = 30.0
var t: float = 0.0
var n: int = 0
var blips: int = 0
var player: AudioStreamPlayer


## The radio lines of a beat (copy; [] when it has none).
static func lines(beat_id: String) -> Array:
	return (SCRIPTS.get(beat_id, []) as Array).duplicate(true)


static func prefix(speaker_id: String) -> String:
	return String(PREFIX.get(speaker_id, StoryCast.speaker(speaker_id).to_upper() if StoryCast.has(speaker_id) else speaker_id.to_upper()))


## The full text of a radio line (what the label shows once typed).
static func radio_text(speaker_id: String, line: String, dich: String) -> String:
	return "%s: %s" % [prefix(speaker_id), line] + ("\nDịch: %s" % dich if dich != "" else "")


func _init(bus: String = "SFX") -> void:
	name = "StoryRadio"
	player = AudioStreamPlayer.new()
	player.name = "Voice"
	player.bus = CinePlayer._bus(bus)
	player.volume_db = VOICE_DB
	add_child(player)


## A radio line typed into lbl with the speaker's voice.
func say(lbl: Label, speaker_id: String, line: String, dich: String = "") -> void:
	type_text(lbl, prefix(speaker_id) + ": ", line, ("\nDịch: %s" % dich) if dich != "" else "", DialogueVoice.voice_for(speaker_id, StoryCast.speaker(speaker_id) if StoryCast.has(speaker_id) else ""))


## Types body after head (always shown); tail (e.g. the "Dịch:" line) shows once body is complete. voice "" = silent.
func type_text(lbl: Label, h: String, b: String, tl: String = "", v: String = "") -> void:
	label = lbl
	head = h
	body = b
	tail = tl
	voice = v
	t = 0.0
	n = 0
	if v != "":
		DialogueVoice.warm([v])
	cps = float(DialogueVoice.profile(v if v != "" else "generic")["cps"])
	if label:
		label.text = head + body + tail
	_apply()


func step(dt: float) -> void:
	if label == null or not is_instance_valid(label) or done():
		return
	t += dt
	var nn: int = DialogueVoice.chars_at(body, t, cps)
	if nn > n:
		var words: PackedStringArray = DialogueVoice.new_words(body, n, nn)
		if not words.is_empty() and voice != "":
			_blip(words[words.size() - 1])
		n = nn
		_apply()


func _blip(word: String) -> void:
	blips += 1
	var st: AudioStream = DialogueVoice.blip(voice, word)
	if st == null or not player.is_inside_tree():
		return
	player.stream = st
	player.play()


func reveal() -> void:
	n = body.length()
	_apply()


func done() -> bool:
	return n >= body.length()


## Seconds the current text needs on screen: typing at the voice's speed plus READ_PAD.
func min_secs() -> float:
	return float(body.length()) / maxf(cps, 1.0) + READ_PAD


## The typed part (tests).
func typed() -> String:
	return body.substr(0, n)


func _apply() -> void:
	if label == null or not is_instance_valid(label):
		return
	label.visible_characters = -1 if done() else head.length() + n
