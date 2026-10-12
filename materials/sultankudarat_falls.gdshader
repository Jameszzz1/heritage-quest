shader_type canvas_item;

// ---------- WATER DETECTION (walang mask) ----------
uniform float hue_min : hint_range(0.0, 1.0) = 0.47;
uniform float hue_max : hint_range(0.0, 1.0) = 0.58;
uniform float pool_sat_min : hint_range(0.0, 1.0) = 0.45;
uniform float pool_val_min : hint_range(0.0, 1.0) = 0.42;
uniform float falls_val_min : hint_range(0.0, 1.0) = 0.62;
uniform bool debug_mask = false;

// ---------- LAYOUT ----------
uniform float pool_start_y : hint_range(0.0, 1.0) = 0.63;

// ---------- FALLS ----------
uniform float fall_speed = 6.0;
uniform float stripe_width = 2.0;
uniform float stripe_height = 5.0;
uniform float foam_amount : hint_range(0.0, 1.0) = 0.30;
uniform float dark_amount : hint_range(0.0, 1.0) = 0.22;
uniform float falls_sway_px : hint_range(0.0, 3.0) = 1.0;

// ---------- POOL: ALON ----------
uniform float pool_speed : hint_range(0.0, 6.0) = 2.6;
uniform float wave_px : hint_range(0.0, 8.0) = 3.5;       // lakas ng galaw ng tubig
uniform float light_wave : hint_range(0.0, 0.4) = 0.14;   // liwanag/dilim na sumasabay sa alon

// ---------- POOL: RIPPLES (singsing) ----------
uniform float ripple_speed : hint_range(0.0, 4.0) = 1.1;      // bilis ng paglabas ng singsing
uniform float ripple_freq : hint_range(2.0, 40.0) = 14.0;     // dami ng singsing (taas = mas siksik)
uniform float ripple_width : hint_range(0.05, 0.5) = 0.22;    // kapal ng singsing
uniform float ripple_reach : hint_range(0.1, 1.0) = 0.42;     // gaano kalayo kumalat bago mawala
uniform float ripple_strength : hint_range(0.0, 1.0) = 0.75;  // liwanag ng singsing
uniform float ripple_shadow : hint_range(0.0, 1.0) = 0.35;    // dilim sa likod ng singsing
uniform vec2 ripple_a = vec2(0.51, 0.66); // tama ng falls
uniform vec2 ripple_b = vec2(0.40, 0.74); // dagdag na pinagmulan sa kaliwa
uniform vec2 ripple_c = vec2(0.62, 0.77); // dagdag na pinagmulan sa kanan

uniform vec4 foam_color : source_color = vec4(0.85, 0.97, 1.0, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.05, 0.25, 0.35, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float water_px(sampler2D tex, vec2 uv) {
	vec4 c = texture(tex, uv);
	if (c.a < 0.1) {
		return 0.0;
	}
	vec3 h = rgb2hsv(c.rgb);
	float in_hue = step(hue_min, h.x) * step(h.x, hue_max);
	float pool = in_hue * step(pool_sat_min, h.y) * step(pool_val_min, h.z);
	float falls = step(falls_val_min, h.z) * step(0.08, h.y) * step(hue_min - 0.02, h.x) * step(h.x, hue_max + 0.02);
	return max(pool, falls);
}

float is_water(sampler2D tex, vec2 uv, vec2 px) {
	float c = water_px(tex, uv);
	float n = water_px(tex, uv + vec2(px.x, 0.0))
			+ water_px(tex, uv - vec2(px.x, 0.0))
			+ water_px(tex, uv + vec2(0.0, px.y))
			+ water_px(tex, uv - vec2(0.0, px.y));
	return c * step(3.0, n);
}

// Isang source ng ripple. Return: x = liwanag ng singsing, y = anino sa likod nito
vec2 ripple(vec2 uv_s, vec2 center, vec2 px, float t, float phase_offset) {
	float aspect = px.x / px.y; // width / height ng texture
	// 2:1 isometric: pa-oval ang singsing
	float d = length(vec2(uv_s.x - center.x, (uv_s.y - center.y) * 2.0 / aspect));
	float fade = clamp(1.0 - d / ripple_reach, 0.0, 1.0);
	float ph = fract(d * ripple_freq - t * ripple_speed + phase_offset);
	float line = step(ph, ripple_width) * step(0.12, fade);
	float shade = step(ripple_width, ph) * step(ph, ripple_width * 2.2) * step(0.12, fade);
	return vec2(line, shade);
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 base = texture(TEXTURE, UV);
	float w = is_water(TEXTURE, UV, px);

	if (debug_mask) {
		COLOR = vec4(vec3(w), base.a);
	} else if (w < 0.5) {
		COLOR = base; // bato, puno, etc. - hindi gagalaw
	} else {
		vec2 p = floor(UV / px);
		vec2 uv_s = p * px; // pixel-snapped UV
		vec3 col = base.rgb;

		if (UV.y < pool_start_y) {
			// ===== FALLS =====
			float sway = round(sin(p.y * 0.25 + TIME * 3.0) * falls_sway_px);
			float px_x = p.x + sway;

			float cx = floor(px_x / stripe_width);
			float cy = floor(p.y / stripe_height - TIME * fall_speed);
			float r1 = hash(vec2(cx, cy));
			float r2 = hash(vec2(cx + 17.0, cy + 3.0));

			float cx2 = floor((px_x + 3.0) / (stripe_width + 1.0));
			float cy2 = floor(p.y / (stripe_height * 1.8) - TIME * fall_speed * 0.6);
			float r3 = hash(vec2(cx2 + 41.0, cy2 + 7.0));

			if (r1 > 1.0 - foam_amount) {
				col = mix(col, foam_color.rgb, 0.85);
			} else if (r3 > 0.8) {
				col = mix(col, foam_color.rgb, 0.45);
			} else if (r2 > 1.0 - dark_amount) {
				col = mix(col, shadow_color.rgb, 0.4);
			}
		} else {
			// ===== POOL =====
			float t = TIME * pool_speed;
			float d1 = p.x + p.y * 2.0;
			float d2 = p.x - p.y * 2.0;

			// alon: displacement na pa-diagonal
			vec2 shift = vec2(
				round(sin(d1 * 0.14 - t) * wave_px + sin(p.y * 0.55 + t * 1.7) * wave_px * 0.5),
				round(cos(d2 * 0.12 + t * 0.8) * wave_px * 0.6 + sin(p.x * 0.4 - t * 1.3) * wave_px * 0.3)
			);
			vec2 uv2 = UV + shift * px;
			if (water_px(TEXTURE, uv2) > 0.5) {
				col = texture(TEXTURE, uv2).rgb;
			}

			// liwanag at dilim na sumasabay sa alon
			float lw = sin(d1 * 0.1 - t * 1.2) * 0.5 + sin(d2 * 0.13 + t) * 0.5;
			col += vec3(lw * light_wave);

			// ripples: 3 pinagmulan, magkakaiba ang phase para hindi sabay-sabay
			vec2 ra = ripple(uv_s, ripple_a, px, TIME, 0.0);
			vec2 rb = ripple(uv_s, ripple_b, px, TIME, 0.37);
			vec2 rc = ripple(uv_s, ripple_c, px, TIME, 0.71);
			float line = max(ra.x, max(rb.x, rc.x));
			float shade = max(ra.y, max(rb.y, rc.y));

			col = mix(col, shadow_color.rgb, ripple_shadow * shade * (1.0 - line));
			col = mix(col, foam_color.rgb, ripple_strength * line);
		}

		COLOR = vec4(col, base.a);
	}
}