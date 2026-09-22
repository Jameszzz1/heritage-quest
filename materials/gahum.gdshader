shader_type canvas_item;

uniform float breathe_speed : hint_range(0.5, 5.0) = 2.0;
uniform float breathe_strength : hint_range(0.0, 0.1) = 0.03;
uniform float bob_height : hint_range(0.0, 5.0) = 1.5;

void vertex() {
    // Breathing effect - konting squash/stretch sa katawan
    float breathe = sin(TIME * breathe_speed) * breathe_strength;
    VERTEX.y *= (1.0 + breathe);
    
    // Subtle bob habang naka-idle (parang naka-alerto, gumagalaw ulo)
    VERTEX.y += sin(TIME * breathe_speed * 0.7) * bob_height;
}

void fragment() {
    COLOR = texture(TEXTURE, UV);
}