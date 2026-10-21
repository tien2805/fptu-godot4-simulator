// Viền đen kiểu hoạt hình: vẽ ở pass thứ hai (next_pass) bằng cách lộn mặt (cull_front) và đẩy đỉnh ra theo pháp tuyến.
// Dùng cho nhân vật và đồ vật (CharacterBuilder / PropBuilder) khi bật phong cách toon.
shader_type spatial;
render_mode cull_front, unshaded, depth_draw_opaque, shadows_disabled;

uniform float width : hint_range(0.0, 0.1) = 0.012;
uniform vec4 line_color : source_color = vec4(0.06, 0.05, 0.08, 1.0);

void vertex() {
	// Độ dày viền không đổi theo khoảng cách: đẩy theo pháp tuyến trong không gian view, tỷ lệ với độ sâu
	vec4 clip_pos = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float dist = max(0.5, -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z);
	VERTEX += NORMAL * width * clamp(dist * 0.25, 0.6, 3.0);
}

void fragment() {
	ALBEDO = line_color.rgb;
}
