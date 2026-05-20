// Cloud shadow system — included in both terrain and grass shaders.
// Uses global uniforms so both materials are always perfectly in sync.
// All values are set once by CloudManager.gd on scene load.

global uniform sampler2D cloud_shadow_texture : filter_linear_mipmap, repeat_enable;
global uniform float cloud_scale;
global uniform float cloud_speed;
global uniform vec2 cloud_direction;
global uniform float cloud_threshold;
global uniform float cloud_feather;
global uniform float cloud_shadow_strength;

// Sample the scrolling cloud noise and return a darkened version of the input albedo.
vec3 apply_cloud_shadow(vec3 albedo, vec3 world_position) {
	vec2 uv = world_position.xz * cloud_scale
			 + normalize(cloud_direction) * cloud_speed * TIME;
	float noise_val = texture(cloud_shadow_texture, uv).r;
	// 1.0 = shadowed, 0.0 = clear sky
	float in_shadow = 1.0 - smoothstep(cloud_threshold,
										cloud_threshold + cloud_feather,
										noise_val);
	return albedo * (1.0 - in_shadow * cloud_shadow_strength);
}
