shader_type canvas_item;

// Mga adjustable parameters para makontrol mo sa Inspector ang galaw
uniform float float_speed : hint_range(0.1, 10.0) = 3.0;   // Bilis ng pag-lutang
uniform float float_height : hint_range(0.0, 20.0) = 4.0;  // Taas o lalim ng pag-angat/baba
uniform float tilt_amount : hint_range(0.0, 0.2) = 0.03;   // Banayad na pag-slant para parang tinatangay ng alon

void vertex() {
    // Pag-angat at pagbaba gamit ang sine wave base sa oras (TIME)
    float wave = sin(TIME * float_speed) * float_height;
    VERTEX.y += wave;

    // Banayad na pag-indayog pahalang para mukhang sumasabay sa tubig
    VERTEX.x += cos(TIME * float_speed) * (VERTEX.y * tilt_amount);
}