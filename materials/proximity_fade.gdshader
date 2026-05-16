// Proximity Fade Shader
// Apply to any mesh that should dither out when it blocks the camera's view of the player.
// Add the MeshInstance3D node to the "fadeable" group and the OcclusionManager handles the rest.

shader_type spatial;
render_mode depth_prepass_alpha, cull_back;
#include "res://materials/shaderinc/dither.gdshaderinc"

group_uniforms appearance;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float roughness : hint_range(0.0, 1.0) = 0.8;

group_uniforms fading;
// Set by OcclusionManager.gd via set_instance_shader_parameter() — do not edit manually.
instance uniform float fade_amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = albedo.rgb * tex.rgb;
	ROUGHNESS = roughness;
	float alpha = tex.a * albedo.a;

	if (dither_check(FRAGCOORD.xy, fade_amount * alpha)) discard;
}
