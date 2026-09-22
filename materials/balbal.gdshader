shader_type canvas_item;

uniform float flutter_speed : hint_range(5.0, 30.0) = 15.0;
uniform float flutter_strength : hint_range(0.0, 0.3) = 0.15;
uniform float hover_speed : hint_range(0.5, 5.0) = 2.5;
uniform float hover_height : hint_range(0.0, 5.0) = 2.0;

void vertex() {
    // Wing flutter - i-stretch/squash yung X width para parang kumakaway ang pakpak
    float flutter = sin(TIME * flutter_speed) * flutter_strength;
    VERTEX.x *= (1.0 + flutter);
    
    // Hovering/flying bob - taas-baba habang lumilipad
    VERTEX.y += sin(TIME * hover_speed) * hover_height;
}

void fragment() {
    COLOR = texture(TEXTURE, UV);
}