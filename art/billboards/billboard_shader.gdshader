shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform float threshold : hint_range(0.0, 1.0) = 0.1;
uniform vec3 key_color : source_color = vec3(1.0, 1.0, 1.0);

void fragment() {
	vec4 color = texture(albedo_texture, UV);
	
	// Check distance from key color (default white)
	float d = distance(color.rgb, key_color);
	
	if (d < threshold) {
		discard;
	}
	
	ALBEDO = color.rgb;
	// Boost brightness slightly to ensure it pops in the distance
	ALBEDO *= 1.2;
	ALPHA = 1.0;
}
