# File: res://scripts/cine/CineTimeWarp.gd
# Đồng hồ slow-motion của cinematic: ánh xạ thời gian THỰC r (giây video, khớp nhạc) <-> thời gian TRUYỆN s (giây trong
# truyện, diễn viên / hiệu ứng chạy theo s).
#   • Mỗi cú đánh h: tốc độ ds/dr giảm mượt (smoothstep, ramp_in giây truyện) từ 1× xuống k (0.25-0.5×) từ h - pre, giữ k
#     tới h + post, rồi tăng mượt lại 1× (ramp_out) – "wind-up 1×, chạm 0.25-0.4×, bật lại 1×".
#   • Đóng băng: tại h đồng hồ truyện dừng hẳn freeze giây thực (0.1-0.2 s).
#   • Nhiều cú gần nhau: lấy tốc độ nhỏ nhất.
# Bảng (r, s) dựng một lần với bước 0.5 ms truyện; tra ngược bằng tìm kiếm nhị phân. Độ dài thực cố định: phần đuôi chạy
# 1× tới đúng `length` giây thực.
class_name CineTimeWarp
extends RefCounted

const DS: float = 0.0005

var hits: Array = []       # [{s, k, pre, post, ri, ro, freeze, name}]
var length: float = 25.0   # giây thực
var s_end: float = 0.0
var _r: PackedFloat64Array = []
var _s: PackedFloat64Array = []


func add_hit(s: float, k: float, pre: float, post: float, freeze: float, name: String, ramp_in: float = 0.08, ramp_out: float = 0.14) -> void:
	hits.append({"s": s, "k": k, "pre": pre, "post": post, "ri": ramp_in, "ro": ramp_out, "freeze": freeze, "name": name})
	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) < float(b["s"]))


## Tốc độ ds/dr tại thời gian truyện s (không tính đóng băng).
func speed_at_story(s: float) -> float:
	var v: float = 1.0
	for h: Dictionary in hits:
		var hs: float = h["s"]
		var k: float = h["k"]
		var a: float = hs - float(h["pre"])
		var b: float = hs + float(h["post"])
		var ri: float = h["ri"]
		var ro: float = h["ro"]
		var vv: float = 1.0
		if s >= a and s <= b:
			vv = k
		elif s < a and s > a - ri:
			var u: float = (s - (a - ri)) / ri
			vv = lerpf(1.0, k, u * u * (3.0 - 2.0 * u))
		elif s > b and s < b + ro:
			var u2: float = (s - b) / ro
			vv = lerpf(k, 1.0, u2 * u2 * (3.0 - 2.0 * u2))
		v = minf(v, vv)
	return v


## Dựng bảng; story_min: thời gian truyện tối thiểu cần phủ (phần đuôi 1× lấp tới length giây thực).
func build() -> void:
	_r = PackedFloat64Array()
	_s = PackedFloat64Array()
	var r: float = 0.0
	var s: float = 0.0
	var hi: int = 0
	_r.append(0.0)
	_s.append(0.0)
	while r < length:
		# đóng băng tại cú đánh kế tiếp nếu s vừa chạm tới nó
		while hi < hits.size() and float(hits[hi]["s"]) <= s:
			var f: float = hits[hi]["freeze"]
			if f > 0.0:
				r += f
				_r.append(r)
				_s.append(s)
			hi += 1
		var ds: float = DS
		if hi < hits.size():
			ds = minf(ds, float(hits[hi]["s"]) - s)
			if ds <= 0.0:
				ds = DS
		var v: float = speed_at_story(s + ds * 0.5)
		r += ds / maxf(v, 0.01)
		s += ds
		_r.append(r)
		_s.append(s)
	s_end = story_at(length)


## Thời gian truyện tại giây thực r.
func story_at(r: float) -> float:
	if _r.is_empty():
		return r
	if r <= 0.0:
		return 0.0
	var n: int = _r.size()
	if r >= _r[n - 1]:
		return _s[n - 1] + (r - _r[n - 1])
	var lo: int = 0
	var hi: int = n - 1
	while hi - lo > 1:
		var mid: int = (lo + hi) >> 1
		if _r[mid] <= r:
			lo = mid
		else:
			hi = mid
	var dr: float = _r[hi] - _r[lo]
	if dr <= 0.0:
		return _s[lo]
	return lerpf(_s[lo], _s[hi], (r - _r[lo]) / dr)


## Giây thực khi truyện tới s (đầu đoạn đóng băng nếu s là một cú đánh).
func real_at(s: float) -> float:
	var n: int = _s.size()
	if n == 0:
		return s
	if s >= _s[n - 1]:
		return _r[n - 1] + (s - _s[n - 1])
	var lo: int = 0
	var hi: int = n - 1
	while hi - lo > 1:
		var mid: int = (lo + hi) >> 1
		if _s[mid] < s:
			lo = mid
		else:
			hi = mid
	var ds: float = _s[hi] - _s[lo]
	if ds <= 0.0:
		return _r[lo]
	return lerpf(_r[lo], _r[hi], (s - _s[lo]) / ds)


## Tốc độ hiện tại ds/dr tại giây thực r (0 trong lúc đóng băng).
func speed_at(r: float) -> float:
	var e: float = 0.004
	return (story_at(r + e) - story_at(maxf(r - e, 0.0))) / (r + e - maxf(r - e, 0.0))


## Bảng nhịp: mỗi cú đánh -> [tên, giây thực chạm, giây thực hết đóng băng, thời gian truyện, tốc độ slow].
func beat_rows() -> Array:
	var rows: Array = []
	for h: Dictionary in hits:
		var r0: float = real_at(float(h["s"]))
		rows.append([h["name"], r0, r0 + float(h["freeze"]), float(h["s"]), float(h["k"]), float(h["freeze"])])
	return rows
