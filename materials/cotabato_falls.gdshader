shader_type canvas_item;

// ================= REGION NG SPRITE (kopyahin sa Inspector > Region > Rect) =================
uniform vec4 region_rect = vec4(76.0, 21.5, 421.0, 378.0); // x, y, w, h (pixels)

// ================= LOKASYON NG TUBIG (0..1 sa loob ng region) =================
// vec4(x_min, y_min, x_max, y_max)
uniform vec4 falls_rect = vec4(0.18, 0.20, 0.90, 0.80);
uniform vec4 pool_rect  = vec4(0.12, 0.74, 0.90, 0.96);
uniform float pool_start_y : hint_range(0.0, 1.0) = 0.77; // dito nagtatapos ang falls

// ================= DETECTION =================
uniform float falls_val_min : hint_range(0.0, 1.0) = 0.60;
uniform float falls_sat_max : hint_range(0.0, 1.0) = 0.55;
uniform float hue_min : hint_range(0.0, 1.0) = 0.44;
uniform float hue_max : hint_range(0.0, 1.0) = 0.60;
uniform float pool_sat_min : hint_range(0.0, 1.0) = 0.20;
uniform float pool_val_min : hint_range(0.0, 1.0) = 0.28;
uniform bool debug_mask = false; // ON = puti ang tubig, itim ang hindi

// ================= PIXEL SIZE =================
uniform float pixel_scale : hint_range(1.0, 8.0) = 2.0;

// ================= FALLS =================
uniform float fall_speed = 3.0;
uniform float stripe_width = 1.5;
uniform float stripe_height = 7.0;
uniform float foam_amount : hint_range(0.0, 1.0) = 0.28;
uniform float dark_amount : hint_range(0.0, 1.0) = 0.18;
uniform float falls_sway : hint_range(0.0, 3.0) = 1.0;
uniform float splash_height : hint_range(0.0, 0.2) = 0.05;
uniform float splash_amount : hint_range(0.0, 1.0) = 0.5;

// ================= POOL =================
uniform float pool_speed : hint_range(0.0, 6.0) = 2.0;
uniform float wave_px : hint_range(0.0, 8.0) = 1.5;
uniform float light_wave : hint_range(0.0, 0.4) = 0.10;
uniform float sparkle_amount : hint_range(0.0, 0.1) = 0.010;
uniform float sparkle_speed = 6.0;

// ================= RIPPLES =================
uniform float ripple_speed : hint_range(0.0, 4.0) = 0.9;
uniform float ripple_freq : hint_range(2.0, 60.0) = 22.0;
uniform float ripple_width : hint_range(0.05, 0.5) = 0.20;
uniform float ripple_reach : hint_range(0.05, 1.0) = 0.30;
uniform float ripple_strength : hint_range(0.0, 1.0) = 0.65;
uniform float ripple_shadow : hint_range(0.0, 1.0) = 0.30;
uniform vec2 ripple_a = vec2(0.50, 0.86); // gitna ng pool
uniform vec2 ripple_b = vec2(0.30, 0.84); // kaliwang falls
uniform vec2 ripple_c = vec2(0.76, 0.84); // kanang falls

uniform vec4 foam_color : source_color = vec4(0.88, 0.98, 1.0, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.05, 0.28, 0.38, 1.0);

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

float in_rect(vec2 l, vec4 r) {
	return step(r.x, l.x) * step(l.x, r.z) * step(r.y, l.y) * step(l.y, r.w);
}

// UV ng buong texture -> 0..1 sa loob ng region
vec2 to_local(vec2 uv, vec2 tex_size) {
	return (uv * tex_size - region_rect.xy) / region_rect.zw;
}

float water_px(sampler2D tex, vec2 uv, vec2 tex_size) {
	vec4 c = texture(tex, uv);
	if (c.a < 0.1) {
		return 0.0;
	}
	vec2 l = to_local(uv, tex_size);
	vec3 h = rgb2hsv(c.rgb);

	// FALLS: maputla/maliwanag at hindi berde
	float bluish = step(c.g, c.b + 0.03);
	float falls = in_rect(l, falls_rect) * step(falls_val_min, h.z) * step(h.y, falls_sat_max) * bluish;

	// POOL: teal na tubig
	float hue_ok = step(hue_min, h.x) * step(h.x, hue_max);
	float pool = in_rect(l, pool_rect) * hue_ok * step(pool_sat_min, h.y) * step(pool_val_min, h.z);

	return max(falls, pool);
}

float is_water(sampler2D tex, vec2 uv, vec2 px, vec2 tex_size) {
	float c = water_px(tex, uv, tex_size);
	float n = water_px(tex, uv + vec2(px.x, 0.0), tex_size)
			+ water_px(tex, uv - vec2(px.x, 0.0), tex_size)
			+ water_px(tex, uv + vec2(0.0, px.y), tex_size)
			+ water_px(tex, uv - vec2(0.0, px.y), tex_size);
	return c * step(2.0, n);
}

// x = liwanag ng singsing, y = anino sa likod
vec2 ripple(vec2 l, vec2 center, float t, float phase_offset) {
	vec2 dp = (l - center) * region_rect.zw;
	float d = length(vec2(dp.x, dp.y * 2.0)) / region_rect.z;
	float fade = clamp(1.0 - d / ripple_reach, 0.0, 1.0);
	float ph = fract(d * ripple_freq - t * ripple_speed + phase_offset);
	float line = step(ph, ripple_width) * step(0.12, fade);
	float shade = step(ripple_width, ph) * step(ph, ripple_width * 2.2) * step(0.12, fade);
	return vec2(line, shade);
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 tex_size = 1.0 / px;
	vec4 base = texture(TEXTURE, UV);
	float w = is_water(TEXTURE, UV, px, tex_size);

	if (debug_mask) {
		COLOR = vec4(vec3(w), base.a);
	} else if (w < 0.5) {
		COLOR = base; // bato, puno, lupa: hindi gagalaw
	} else {
		vec2 l = to_local(UV, tex_size);
		vec2 gp = UV * tex_size - region_rect.xy;        // pixel coords sa loob ng region
		vec2 p = floor(gp / pixel_scale);                 // chunky na cell
		vec2 l_s = (p * pixel_scale) / region_rect.zw;    // pixel-snapped local UV
		vec3 col = base.rgb;

		if (l.y < pool_start_y) {
			// ===================== FALLS =====================
			float sway = round(sin(p.y * 0.25 + TIME * 3.0) * falls_sway);
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

			// talsik sa paanan ng falls
			float near_base = smoothstep(pool_start_y - splash_height, pool_start_y, l.y);
			float sp = hash(vec2(p.x, p.y + floor(TIME * 8.0) * 13.0));
			if (sp > 1.0 - splash_amount * near_base) {
				col = mix(col, foam_color.rgb, 0.9);
			}
		} else {
			// ===================== POOL =====================
			float t = TIME * pool_speed;
			float d1 = p.x + p.y * 2.0;
			float d2 = p.x - p.y * 2.0;

			vec2 shift = vec2(
				round(sin(d1 * 0.14 - t) * wave_px + sin(p.y * 0.55 + t * 1.7) * wave_px * 0.5),
				round(cos(d2 * 0.12 + t * 0.8) * wave_px * 0.6 + sin(p.x * 0.4 - t * 1.3) * wave_px * 0.3)
			);
			vec2 uv2 = UV + shift * px * pixel_scale;
			if (water_px(TEXTURE, uv2, tex_size) > 0.5) {
				col = texture(TEXTURE, uv2).rgb;
			}

			float lw = sin(d1 * 0.1 - t * 1.2) * 0.5 + sin(d2 * 0.13 + t) * 0.5;
			col += vec3(lw * light_wave);

			vec2 ra = ripple(l_s, ripple_a, TIME, 0.0);
			vec2 rb = ripple(l_s, ripple_b, TIME, 0.37);
			vec2 rc = ripple(l_s, ripple_c, TIME, 0.71);
			float line = max(ra.x, max(rb.x, rc.x));
			float shade = max(ra.y, max(rb.y, rc.y));
			col = mix(col, shadow_color.rgb, ripple_shadow * shade * (1.0 - line));
			col = mix(col, foam_color.rgb, ripple_strength * line);

			float sp2 = hash(p + floor(TIME * sparkle_speed));
			if (sp2 > 1.0 - sparkle_amount) {
				col = mix(col, foam_color.rgb, 0.8);
			}
		}

		COLOR = vec4(col, base.a);
	}
} 