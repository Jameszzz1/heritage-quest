shader_type canvas_item;

// Parameters para sa hangin
uniform float bilis_ng_hangin : hint_range(0.0, 5.0) = 1.5;
uniform float lakas_ng_hangin : hint_range(0.0, 10.0) = 2.5;
uniform float randomness : hint_range(1.0, 100.0) = 30.0;

// Mga parameters para mahiwalay ang dahon sa katawan
// Sa Godot, ang Y-axis ay pababa. Pababa = mas mataas ang number.
uniform float tigas_ng_katawan_y : hint_range(-50.0, 50.0) = 15.0; 
uniform float lambot_ng_dahon : hint_range(0.1, 50.0) = 25.0; 

void vertex() {
	// 1. Gumawa ng "Mask" o "Weight"
	// Ang smoothstep ay gagawa ng gradient mula 0.0 (walang galaw) hanggang 1.0 (full galaw)
	// Base ito sa Y position ng puno mo.
	float weight = 1.0 - smoothstep(tigas_ng_katawan_y - lambot_ng_dahon, tigas_ng_katawan_y, VERTEX.y);
	
	// 2. Kalkulahin ang hangin (katulad nung dati)
	float offset = (VERTEX.x + VERTEX.y) / randomness;
	float time_val = TIME * bilis_ng_hangin + offset;
	
	float main_wind = sin(time_val);
	float micro_wind = sin(time_val * 2.3) * 0.3;
	float sway = (main_wind + micro_wind) * lakas_ng_hangin;
	
	// 3. I-apply ang galaw pero imultiply sa weight
	// Kapag nasa ugat (weight = 0), hindi gagalaw. Kapag nasa dahon (weight = 1), gagalaw.
	VERTEX.x += sway * weight;
}
