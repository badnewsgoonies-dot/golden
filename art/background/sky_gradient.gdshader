
shader_type canvas_item;
uniform vec4 top_color : source_color = vec4(0.62, 0.78, 0.91, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.85, 0.93, 1.0, 1.0);
void fragment(){
    float t = 1.0 - UV.y;
    COLOR = mix(bottom_color, top_color, t);
}
