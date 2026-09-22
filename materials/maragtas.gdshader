shader_type canvas_item;

uniform float wave_speed : hint_range(1.0, 10.0) = 4.0;
uniform float wave_amplitude : hint_range(0.0, 10.0) = 3.0;
uniform float wave_frequency : hint_range(1.0, 20.0) = 8.0;

void vertex() {
    // Sinusoidal wave galing ulo papuntang buntot - parang gumagalaw yung katawan
    float wave = sin(VERTEX.x * wave_frequency * 0.01 + TIME * wave_speed) * wave_amplitude;
    VERTEX.y += wave;
}

void fragment() {
    COLOR = texture(TEXTURE, UV);
}