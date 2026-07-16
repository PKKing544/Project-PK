shader_type spatial;
#include "res://materials/shaderinc/dither.gdshaderinc"

group_uniforms colours_and_textures;
uniform vec3 albedo_color : source_color = vec3(0.12, 0.12, 0.12);

group_uniforms colours_and_textures.albedo2;
uniform vec4 albedo2 : source_color = vec4(1.0f);
uniform sampler2D albedo2_noise;
uniform float albedo2_scale : hint_range(0.0, 1.0, 0.001) = 0.005;
uniform float albedo2_threshold : hint_range(0.0, 1.0, 0.001) = 0.604;

group_uniforms colours_and_textures.albedo3;
uniform vec4 albedo3 : source_color = vec4(1.0f);
uniform sampler2D albedo3_noise;
uniform float albedo3_scale : hint_range(0.0, 0.1, 0.001) = 0.003;
uniform float albedo3_threshold : hint_range(0.0, 1.0, 0.001) = 0.661;

group_uniforms grid;
uniform bool show_grid = true;
uniform vec3 grid_color : source_color = vec3(0.25, 0.25, 0.25);
uniform float grid_size = 1.0;
uniform float line_width = 0.05;

group_uniforms fading;
// Updated every frame by OcclusionManager.gd — do not edit manually
uniform vec3 player_world_pos = vec3(0.0);
uniform vec3 camera_world_pos = vec3(0.0);
uniform float vignette_inner : hint_range(0.0, 20.0, 0.1) = 1.5;
uniform float vignette_outer : hint_range(0.0, 20.0, 0.1) = 4.0;
uniform float vignette_offset : hint_range(0.0, 10.0, 0.1) = 2.0;

group_uniforms clouds;
uniform sampler2D cloud_texture : filter_linear_mipmap, repeat_enable;
uniform float cloud_scale : hint_range(0.0, 0.05, 0.0001) = 0.003;
uniform float cloud_speed : hint_range(0.0, 0.1, 0.0001) = 0.006;
uniform vec2 cloud_direction = vec2(1.0, 0.5);
uniform float cloud_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float cloud_feather : hint_range(0.0, 0.5) = 0.15;
uniform float cloud_strength : hint_range(0.0, 1.0) = 0.35;

group_uniforms lighting;
uniform int cuts : hint_range(1, 8) = 3;
uniform float wrap : hint_range(-2.0f, 2.0f) = 0.0f;
uniform float steepness : hint_range(1.0f, 8.0f) = 1.0f;
uniform float threshold_gradient_size = 0.2;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = abs(NORMAL);
}

float get_grid(vec2 uv) {
	vec2 grid = abs(fract(uv / grid_size - 0.5) - 0.5) / fwidth(uv / grid_size);
	float line = min(grid.x, grid.y);
	return 1.0 - smoothstep(0.0, 1.0, line - line_width * 10.0);
}

void fragment() {
	// Triplanar mapping logic for Grid
	float x_grid = get_grid(world_pos.zy);
	float y_grid = get_grid(world_pos.xz);
	float z_grid = get_grid(world_pos.xy);
	
	// Normalize weights
	vec3 weights = world_normal / (world_normal.x + world_normal.y + world_normal.z);
	float final_grid = x_grid * weights.x + y_grid * weights.y + z_grid * weights.z;
	
	// Texture noises for grass patches matching exactly with the grass shader!
	float albedo2_noise_tex = texture(albedo2_noise, world_pos.xz * albedo2_scale).r;
	float albedo3_noise_tex = texture(albedo3_noise, world_pos.xz * albedo3_scale).r;
	
	// Set base floor colours based on noise thresholds
	vec3 base_color = albedo_color;
	if (albedo2_noise_tex > albedo2_threshold) {
		base_color = albedo2.rgb;
	} 
	if (albedo3_noise_tex > albedo3_threshold) {
		base_color = albedo3.rgb;
	}
	
	// If the vertex color has an alpha > 0, it's a path!
	// We use dither_check (already included in this shader) to create a stylized pixel-dithered edge
	if (COLOR.a > 0.0) {
		if (!dither_check(FRAGCOORD.xy, COLOR.a)) {
			base_color = COLOR.rgb;
		}
	}
	
	ALBEDO = show_grid ? mix(base_color, grid_color, final_grid) : base_color;

	// Cloud shadows — scrolling noise darkens terrain and walls
	vec2 cloud_uv = world_pos.xz * cloud_scale
				 + normalize(cloud_direction) * cloud_speed * TIME;
	float cloud_val = texture(cloud_texture, cloud_uv).r;
	float in_shadow = 1.0 - smoothstep(cloud_threshold, cloud_threshold + cloud_feather, cloud_val);
	ALBEDO *= 1.0 - in_shadow * cloud_strength;

	ROUGHNESS = 0.8;

	// Offset the vignette center behind the player (toward the camera) in XZ
	vec2 to_cam_xz = camera_world_pos.xz - player_world_pos.xz;
	float to_cam_len = length(to_cam_xz);
	vec2 vignette_center = player_world_pos.xz;
	if (to_cam_len > 0.001) {
		vignette_center += normalize(to_cam_xz) * vignette_offset;
	}

	// Distance from this surface pixel to the offset vignette center
	float dist_xz = length(world_pos.xz - vignette_center);
	float proximity_fade = smoothstep(vignette_inner, vignette_outer, dist_xz);

	// Only affect vertical walls — floors/ceilings stay solid
	float is_wall = 1.0 - world_normal.y;

	if (dither_check(FRAGCOORD.xy, mix(proximity_fade, 1.0, 1.0 - is_wall))) discard;
}

void light() {
	float NdotL = dot(NORMAL, LIGHT);
	float diffuse_amount = NdotL + (ATTENUATION - 1.0) + wrap;
	diffuse_amount *= steepness;

	float cuts_inv = 1.0f / float(cuts);
	float cut = cuts_inv; 
	float original_index = ceil(diffuse_amount * float(cuts));
	float original_stepped = clamp(original_index * cut, 0.0, 1.0);
	float diffuse_stepped = clamp(diffuse_amount + mod(1.0f - diffuse_amount, cuts_inv), 0.0f, 1.0f);

	if (threshold_gradient_size > 0.0) {
		float nearest_k = floor(diffuse_amount / cut + 0.5);
		float threshold = nearest_k * cut;
		if (nearest_k >= 0.0 && nearest_k <= float(cuts)) {
			float halfWidth = 0.5 * cut * threshold_gradient_size;
			float low  = max(0.0, threshold - halfWidth);
			float high = min(1.0, threshold + halfWidth);
			float blend = (high > low) ? smoothstep(low, high, diffuse_amount) : step(threshold, diffuse_amount);
			float leftValue  = threshold;
			float rightValue = min(threshold + (cut * 1.0), 1.0);
			diffuse_stepped = clamp(mix(leftValue, rightValue, blend), 0.0, 1.0);
		} else {
			diffuse_stepped = original_stepped;
		}
	}
	vec3 diffuse = ALBEDO.rgb * LIGHT_COLOR / PI;
	diffuse *= diffuse_stepped;
	DIFFUSE_LIGHT = max(DIFFUSE_LIGHT, diffuse);
}
