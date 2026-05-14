// Depth-pushed silhouette outline pass for multi-part 2D sprite characters.
// Apply as material_overlay on every Sprite3D part.
// Set render_priority to -1 so it draws BEFORE the main sprites.
// The main sprites will depth-occlude the interior, leaving only the outer edge.

shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, blend_mix;

uniform sampler2D tex : source_color, filter_nearest;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// How many texels to expand outward.
uniform float outline_size : hint_range(0.5, 16.0, 0.5) = 2.0;
// pixel_size of the Sprite3D — must match the node's pixel_size property.
uniform float pixel_size : hint_range(0.0001, 0.1) = 0.005;

void vertex() {
	// For Godot 4 Sprite3D with billboard mode, VERTEX is in view space
	// after the billboard transform.  Expanding XY in view space gives
	// a screen-aligned enlargement, which is exactly what we want.
	vec2 uv_dir = (UV - vec2(0.5)) * 2.0; // remap [0,1] -> [-1,1]
	float expand = outline_size * pixel_size;
	VERTEX.xy += uv_dir * expand;

	// Push slightly away from camera in view space so the outline sits
	// *behind* the main sprite when it renders afterwards.
	VERTEX.z += 0.01;
}

void fragment() {
	float alpha = texture(tex, UV).a;
	// Discard where the texture is fully transparent —
	// this keeps the silhouette tight to the actual sprite shape.
	if (alpha < 0.05) discard;

	ALBEDO = outline_color.rgb;
	ALPHA  = outline_color.a;
}
