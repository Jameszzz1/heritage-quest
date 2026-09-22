shader_type canvas_item;

// --- DOOR LAMPS (FLICKERING) ---
uniform vec2 lamp_left_pos = vec2(0.53, 0.58); // Posisyon ng kaliwang ilaw
uniform vec2 lamp_right_pos = vec2(0.61, 0.53); // Posisyon ng kanang ilaw
uniform vec4 lamp_color : source_color = vec4(1.0, 0.6, 0.2, 0.85);

void fragment() {
    vec4 base_color = texture(TEXTURE, UV);
    vec3 final_color = base_color.rgb;
    
    // Door Lamps Effect (Flicker)
    float lamp1_dist = distance(UV, lamp_left_pos);
    float lamp2_dist = distance(UV, lamp_right_pos);
    float lamps_glow = smoothstep(0.03, 0.005, lamp1_dist) + smoothstep(0.03, 0.005, lamp2_dist);
    
    // Pagsamahin ang dalawang sine waves para maging random ang pitik ng ilaw
    float flicker = (sin(TIME * 15.0) * 0.1) + (sin(TIME * 25.0) * 0.05) + 0.85;
    final_color += lamp_color.rgb * lamps_glow * flicker * lamp_color.a;

    // Panatilihin ang transparency ng background
    COLOR = vec4(final_color, base_color.a);
}