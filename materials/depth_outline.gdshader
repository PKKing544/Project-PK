shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;

uniform sampler2D tex : source_color, filter_nearest;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width = 1.0;
uniform float depth_offset = 0.05;

uniform bool use_billboard = true;

void vertex() {
	if (use_billboard) {
		// Exact Godot 4 Fixed-Y Billboard source code
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
				vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
				vec4(0.0, 1.0, 0.0, 0.0),
				vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
				MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
				vec4(cos(INSTANCE_CUSTOM.x), -sin(INSTANCE_CUSTOM.x), 0.0, 0.0),
				vec4(sin(INSTANCE_CUSTOM.x), cos(INSTANCE_CUSTOM.x), 0.0, 0.0),
				vec4(0.0, 0.0, 1.0, 0.0),
				vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}

	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	
	// Pushing in VIEW space prevents rotated sprites from pushing sideways!
	float original_z = view_pos.z;
	view_pos.z -= depth_offset;
	
	if (original_z < -0.01 && view_pos.z < -0.01) {
		float scale = view_pos.z / original_z;
		view_pos.xy *= scale;
	}
	
	POSITION = PROJECTION_MATRIX * view_pos;
}

void fragment() {
	vec4 base_color = texture(tex, UV) * COLOR;
	vec2 size = vec2(textureSize(tex, 0));
	
	// If it's the inside of the sprite, we DISCARD it immediately.
	// We ONLY want to draw the outline ring in this overlay pass!
	if (base_color.a > 0.1) {
		discard;
	}
	
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
	
	if (outline < 0.1) {
		discard;
	}
	
	ALBEDO = outline_color.rgb * COLOR.rgb;
	ALPHA = outline;
	ALPHA_SCISSOR_THRESHOLD = 0.1;
}
