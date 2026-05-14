shader_type spatial;
render_mode unshaded, depth_draw_opaque, cull_disabled;

uniform sampler2D tex : source_color, filter_nearest;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width = 1.0;
uniform float depth_offset_amount = 0.0001;

void fragment() {
	vec4 base_color = texture(tex, UV) * COLOR;
	vec2 size = vec2(textureSize(tex, 0));
	
	float outline = 0.0;
	
	outline += texture(tex, UV + vec2(-outline_width, 0.0) / size).a;
	outline += texture(tex, UV + vec2(outline_width, 0.0) / size).a;
	outline += texture(tex, UV + vec2(0.0, -outline_width) / size).a;
	outline += texture(tex, UV + vec2(0.0, outline_width) / size).a;
	
	outline += texture(tex, UV + vec2(-outline_width, outline_width) / size).a;
	outline += texture(tex, UV + vec2(outline_width, outline_width) / size).a;
	outline += texture(tex, UV + vec2(-outline_width, -outline_width) / size).a;
	outline += texture(tex, UV + vec2(outline_width, -outline_width) / size).a;
	
	outline = min(outline, 1.0);
	
	if (base_color.a < 0.1 && outline > 0.1) {
		ALBEDO = outline_color.rgb * COLOR.rgb;
		ALPHA = outline_color.a * COLOR.a;
		ALPHA_SCISSOR_THRESHOLD = 0.1;
		DEPTH = FRAGCOORD.z + depth_offset_amount;
	} else {
		discard;
	}
}
