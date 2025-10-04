shader_type canvas_item;

uniform float glow_strength : hint_range(0.0, 2.0) = 0.5;
uniform vec4 glow_color : source_color = vec4(0.5, 0.4, 0.7, 0.3);
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.0;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    
    // Create a pulsing glow effect
    float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
    float glow_amount = glow_strength * pulse;
    
    // Add glow to the edges
    float edge = 1.0 - max(abs(UV.x - 0.5), abs(UV.y - 0.5)) * 2.0;
    edge = smoothstep(0.0, 0.5, edge);
    
    vec4 final_color = tex_color + (glow_color * edge * glow_amount);
    COLOR = final_color;
}