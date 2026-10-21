shader_type canvas_item;

uniform float zoom = 0.80;          // zoom in para may extra na gilid (hindi makikita ang dulo)
uniform float pan_amount = 0.09;    // layo ng galaw pakaliwa-kanan (dapat mas maliit sa (1 - zoom) / 2)
uniform float pan_speed = 0.5;      // bilis ng galaw
uniform float wave_strength = 0.003;
uniform float wave_speed = 2.0;
uniform float wave_freq = 12.0;

void fragment() {
	// Zoom papasok sa gitna
	vec2 uv = (UV - 0.5) * zoom + 0.5;

	// Alon-alon
	uv.x += sin(uv.y * wave_freq + TIME * wave_speed) * wave_strength;
	uv.y += cos(uv.x * wave_freq + TIME * wave_speed) * wave_strength;

	// Pabalik-balik na galaw (walang tahi)
	uv.x += sin(TIME * pan_speed) * pan_amount;

	// Safety para hindi lumampas sa gilid
	uv = clamp(uv, vec2(0.0), vec2(1.0));

	COLOR = texture(TEXTURE, uv);
}