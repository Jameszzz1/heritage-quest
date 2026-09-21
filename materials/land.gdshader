shader_type canvas_item;

uniform float sway_speed : hint_range(0.0, 5.0) = 1.2;
uniform float sway_strength : hint_range(0.0, 0.02) = 0.006;
uniform float sway_scale : hint_range(1.0, 30.0) = 10.0;
uniform vec4 warm_tint : source_color = vec4(1.0, 0.85, 0.55, 0.08);
uniform float light_pulse_speed : hint_range(0.0, 2.0) = 0.25;
uniform float gust_speed : hint_range(0.0, 1.0) = 0.08;
uniform float gust_scale : hint_range(0.5, 10.0) = 2.0;

// Simple noise para sa gust pattern
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	vec2 world_uv = UV + vec2(TIME * gust_speed * 0.1, 0.0); // para hindi paulit-ulit yung pattern

	// Gust map — malaking noise na dumadaan buong screen, parang totoong hangin
	float gust = noise(world_uv * gust_scale + vec2(TIME * gust_speed, 0.0));
	gust = smoothstep(0.3, 0.7, gust); // patchy, hindi lahat sabay gumagalaw

	// Sway na naka-modulate ng gust strength (mas malakas kung may gust)
	float sway_amount = sway_strength * (0.4 + gust * 1.2);
	float sway = sin(uv.x * sway_scale + TIME * sway_speed) * sway_amount;
	uv.x += sway;

	vec4 base_color = texture(TEXTURE, uv);

	// Warm golden overlay - SOCCSARGEN sunny/tropical
	base_color.rgb = mix(base_color.rgb, base_color.rgb + warm_tint.rgb, warm_tint.a);

	// Dappled sunlight - parang liwanag sumisilip sa dahon, multi-frequency
	float light1 = sin(TIME * light_pulse_speed + uv.x * 12.0 + uv.y * 8.0) * 0.025;
	float light2 = sin(TIME * light_pulse_speed * 0.7 - uv.x * 6.0 + uv.y * 15.0) * 0.02;
	base_color.rgb += (light1 + light2);

	// Gust-based brightness shift - parang bumabago ng shade yung damo kapag hinipan
	base_color.rgb += gust * 0.03;

	COLOR = base_color;
	COLOR.a = texture(TEXTURE, UV).a;
}