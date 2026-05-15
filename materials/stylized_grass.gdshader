// Original Code by Dylearn
// Adapted for Project PK (removed global cloud uniforms for simplicity, merged includes)
shader_type spatial;
render_mode depth_prepass_alpha, depth_draw_opaque, cull_disabled;

group_uniforms colours_and_textures;
uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform vec4 albedo1 : source_color = vec4(1.0f);

group_uniforms colours_and_textures.albedo2;
uniform vec4 albedo2 : source_color = vec4(1.0f);
uniform float albedo2_scale : hint_range(0.0, 1.0, 0.001) = 0.005;
uniform float albedo2_threshold : hint_range(0.0, 1.0, 0.001) = 0.604;
uniform sampler2D albedo2_noise;

group_uniforms colours_and_textures.albedo3;
uniform vec4 albedo3 : source_color = vec4(1.0f);
uniform float albedo3_scale : hint_range(0.0, 0.1, 0.001) = 0.003;
uniform float albedo3_threshold : hint_range(0.0, 1.0, 0.001) = 0.661;
uniform sampler2D albedo3_noise;

group_uniforms colours_and_textures.blending;
uniform float color_blend : hint_range(0.0, 1.0, 0.01) = 0.5;

group_uniforms colours_and_textures.accent1;
uniform float accent_frequency1 : hint_range(0.0, 0.05, 0.0001) = 0.001;
uniform sampler2D accent_texture1 : source_color, filter_nearest;
uniform vec4 accent_albedo1 : source_color = vec4(1.0f);
uniform float accent_height1 : hint_range(0.0, 1.0, 0.001) = 0.5;
uniform float accent_scale1 : hint_range(0.0, 2.0, 0.001) = 1.0;

group_uniforms animation;
uniform float framerate = 5.0;
uniform bool quantised = true;
group_uniforms animation.world_space;
uniform bool world_space_sway = true;
uniform float world_sway_angle : hint_range(0.0f, 180.0f) = 60.0;
uniform float fake_perspective_scale : hint_range(-0.15, 0.6, 0.001) = 0.3;
uniform sampler2D wind_noise;
uniform float wind_noise_threshold : hint_range(-1.0, 1.0, 0.001) = 0.365;
uniform float wind_noise_scale : hint_range(0.0, 0.1, 0.001) = 0.071;
uniform float wind_noise_speed : hint_range(0.0, 0.2, 0.001) = 0.025;
uniform vec2 wind_noise_direction = vec2(0.0, 1.0);
uniform float noise_diverge_angle : hint_range(0.0, 45.0, 0.001) = 10.0;
group_uniforms animation.view_space;
uniform bool view_space_sway = true;
uniform float view_sway_speed : hint_range(0.0f, 5.0f) = 0.1;
uniform float view_sway_angle : hint_range(0.0f, 45.0f) = 10.0;
group_uniforms character_displacement;
uniform bool character_displacement = true;
uniform float player_displacement_angle_z : hint_range(0.0, 360.0, 0.1) = 45.0;
uniform float player_displacement_angle_x : hint_range(0.0, 360.0, 0.1) = 45.0;
uniform float radius_exponent : hint_range(0.0, 10.0, 0.001) = 1.0;
const int character_count = 64;
uniform vec4[character_count] character_positions;

group_uniforms lighting;
uniform int cuts : hint_range(1, 8) = 3;
uniform float wrap : hint_range(-2.0f, 2.0f) = 0.0f;
uniform float steepness : hint_range(1.0f, 8.0f) = 1.0f;
uniform float threshold_gradient_size = 0.2;

group_uniforms transform;
uniform float pivot_offset : hint_range(0.0, 5.0, 0.1) = 0.5;

varying float wind_noise_sample;
varying float instance_id;
varying float id_seed1;
varying vec3 model_origin;
varying vec3 object_origin;
varying vec3 world_pos;
varying float player_displacement_fake_perspective;

vec2 rotate_vec2(vec2 vector, float angle) {
	float angle_deg = angle * (PI / 180.0);
	float rotated_x  = (vector.x * cos(angle_deg)) - (vector.y * sin(angle_deg));
	float rotated_y  = (vector.x * sin(angle_deg)) + (vector.y * cos(angle_deg));
	return vec2 (rotated_x, rotated_y);
}

float location_seed(vec2 location) {
	return fract(sin(dot(location, vec2(12.9898,78.233))) * 43758.5453123);
}
float random(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

mat4 rotateAroundAxis(vec3 axis, float angle) {
	axis = normalize(axis);
	float c = cos(angle);
	float s = sin(angle);
	float oc = 1.0 - c;
	return mat4(
		vec4(oc * axis.x * axis.x + c, oc * axis.x * axis.y - axis.z * s, oc * axis.z * axis.x + axis.y * s, 0.0),
		vec4(oc * axis.x * axis.y + axis.z * s, oc * axis.y * axis.y + c, oc * axis.y * axis.z - axis.x * s, 0.0),
		vec4(oc * axis.z * axis.x - axis.y * s, oc * axis.y * axis.z + axis.x * s, oc * axis.z * axis.z + c, 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
}
mat4 view_space_rotate(float angle) {
	return mat4(vec4(cos(angle), -sin(angle), 0.0, 0.0), vec4(sin(angle), cos(angle), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void vertex() {
	instance_id = float(INSTANCE_ID);
	id_seed1 = random(instance_id + 1.234);
	
	if (id_seed1 < accent_frequency1) {
		VERTEX.y += accent_height1;
		VERTEX *= accent_scale1;
	}
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	object_origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	
	float seed = 10.0 * location_seed(object_origin.xy);
	float frametime = 1.0 / framerate;
	float phase = mod(seed, frametime);
	
	float time = TIME;
	if (quantised) {
		time += phase;
		time = round(time * framerate) / framerate;
	}
	
	vec2 wind_noise_direction1 = rotate_vec2(wind_noise_direction, noise_diverge_angle);
	vec2 wind_noise_direction2 = rotate_vec2(wind_noise_direction, -noise_diverge_angle);
	vec2 wind_noise_time_direction1 = time * wind_noise_speed * normalize(wind_noise_direction1);
	vec2 wind_noise_time_direction2 = time * wind_noise_speed * normalize(wind_noise_direction2);
	
	float wind_noise_sample1 = texture(wind_noise, object_origin.xz * wind_noise_scale + wind_noise_time_direction1).r;
	float wind_noise_sample2 = texture(wind_noise, object_origin.xz * (wind_noise_scale * 0.8) + (wind_noise_time_direction2 * 0.89 * PI / 3.0)).r;
	
	wind_noise_sample = (wind_noise_sample1 * wind_noise_sample2);
	wind_noise_sample = clamp(wind_noise_sample + wind_noise_threshold, 0.0, 1.0);
	wind_noise_sample = (wind_noise_sample - 0.5) * 2.0;

	float world_sway = wind_noise_sample * radians(world_sway_angle);
	vec3 wind_world_axis = (vec4(wind_noise_direction.y, 0.0, -wind_noise_direction.x, 1.0) * INV_VIEW_MATRIX).xyz;
	mat4 world_rotation = rotateAroundAxis(wind_world_axis, world_sway);

	float model_sway = sin((time + seed) * view_sway_speed * 2.0 * PI) * radians(view_sway_angle);
	mat4 model_rotation = view_space_rotate(model_sway);

	float character_displacement_x = 0.0;
	float character_displacement_y = 0.0;
	for (int i=0; i < character_count; i++) {
		if (character_positions[i].w > 0.0) {
			float distance = length(character_positions[i].xyz - object_origin) / character_positions[i].w;
			float displacement_strength = pow(1.0 - distance, radius_exponent);
			if (displacement_strength > 0.0) {
				displacement_strength = clamp(displacement_strength, 0.0, 1.0);
				vec3 character_to_grass = object_origin - character_positions[i].xyz;
				float view_y_dot = dot(normalize(CAMERA_DIRECTION_WORLD.xz), normalize(character_to_grass.xz));
				vec3 perpendicular_camera_direction_world = vec3(CAMERA_DIRECTION_WORLD.z, 0.0, -CAMERA_DIRECTION_WORLD.x);
				float view_x_dot = dot(normalize(perpendicular_camera_direction_world.xz), normalize(character_to_grass.xz));
				character_displacement_x += displacement_strength * view_x_dot;
				character_displacement_y += displacement_strength * view_y_dot;
			}
		}
	}
	character_displacement_x = clamp(character_displacement_x, -1.0, 1.0);
	character_displacement_y = clamp(character_displacement_y, -1.0, 1.0);

	mat4 player_displacement_rotation = rotateAroundAxis(vec3(0.0, 0.0, 1.0), character_displacement_x * radians(player_displacement_angle_z)) * rotateAroundAxis(vec3(1.0, 0.0, 0.0), character_displacement_y * radians(player_displacement_angle_x));
	player_displacement_fake_perspective = character_displacement_y;

	if (view_space_sway) VERTEX = (model_rotation * vec4(VERTEX, 1.0)).xyz;
	if (character_displacement) VERTEX = (player_displacement_rotation * vec4(VERTEX, 1.0)).xyz;
	if (world_space_sway) VERTEX = (world_rotation * vec4(VERTEX, 1.0)).xyz;

	// Shift the pivot point up in world space to prevent the grass from clipping under the floor when looking top-down
	VERTEX.y -= pivot_offset;

	mat4 modified_model_view = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * length(MODEL_MATRIX[1].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz * length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3] + vec4(0.0, pivot_offset, 0.0, 0.0)
	);
	model_origin = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	MODELVIEW_MATRIX = modified_model_view;
}

void fragment() {
	vec2 uv = UV;
	uv.x -= 0.5;
	float _wind_noise_sample = (wind_noise_sample) * fake_perspective_scale;
	if (world_space_sway) {
		_wind_noise_sample *= dot(CAMERA_DIRECTION_WORLD.xz, wind_noise_direction);
		uv.x *= (1.0 - uv.y) * _wind_noise_sample + 1.0;
	}
	if (character_displacement) {
		uv.x *= (1.0 - uv.y) * -player_displacement_fake_perspective + 1.0;
	}
	uv.x += 0.5;
	uv.x = clamp(uv.x, 0.0, 1.0);

	vec4 albedo_tex = texture(albedo_texture, uv);
	float albedo2_noise_tex = texture(albedo2_noise, world_pos.xz * (albedo2_scale)).r;
	float albedo3_noise_tex = texture(albedo3_noise, world_pos.xz * (albedo3_scale)).r;
	
	vec3 base_terrain_color = albedo1.rgb;
	if (albedo2_noise_tex > albedo2_threshold) base_terrain_color = albedo2.rgb;
	if (albedo3_noise_tex > albedo3_threshold) base_terrain_color = albedo3.rgb;
	
	// Blend between exact terrain color and the multiplied texture color to prevent darkness
	ALBEDO = mix(base_terrain_color, base_terrain_color * albedo_tex.rgb, color_blend);
	
	if (id_seed1 < accent_frequency1) {
		vec4 accent_tex = texture(accent_texture1, uv);
		ALBEDO = accent_albedo1.rgb * accent_tex.rgb;
		ALPHA = accent_tex.a;
	} else {
		ALPHA = albedo_tex.a;
	}

	// Force normal to point straight up so grass gets the same flat lighting as the terrain floor
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	LIGHT_VERTEX = model_origin;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
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
