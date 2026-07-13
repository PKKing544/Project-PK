shader_type sky;

uniform vec3 sky_top_color : source_color = vec3(0.48, 0.72, 0.95);
uniform vec3 sky_horizon_color : source_color = vec3(0.8, 0.88, 0.95);
uniform vec3 sky_bottom_color : source_color = vec3(0.9, 0.94, 0.98);

uniform sampler2D cloud_texture : filter_linear_mipmap, repeat_enable;
uniform float cloud_speed = 0.015;
uniform vec2 cloud_direction = vec2(1.0, 0.4);
uniform float cloud_scale = 0.2;
uniform float cloud_threshold = 0.05;
uniform float cloud_feather = 0.1;
uniform vec4 cloud_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void sky() {
	// Vertical sky gradient based on normalized Y direction
	float y = EYEDIR.y;
	vec3 base_sky;
	if (y > 0.0) {
		base_sky = mix(sky_horizon_color, sky_top_color, clamp(y, 0.0, 1.0));
	} else {
		base_sky = mix(sky_horizon_color, sky_bottom_color, clamp(-y, 0.0, 1.0));
	}
	
	vec3 final_color = base_sky;
	
	if (y > 0.0) {
		// Dome UV projection with horizon stretch mitigation
		vec2 uv = EYEDIR.xz / (y + 0.08);
		
		// Scrolling UV offset
		vec2 scroll = normalize(cloud_direction) * TIME * cloud_speed;
		vec2 cloud_uv = uv * cloud_scale + scroll;
		
		// Sample the custom cloud texture
		vec4 tex = texture(cloud_texture, cloud_uv);
		
		// Blend the cloud color based on alpha channel
		float alpha = smoothstep(cloud_threshold, cloud_threshold + cloud_feather, tex.a);
		
		// Fade out clouds near the horizon to avoid clipping/stretching artifacts
		float horizon_fade = clamp(y * 4.0, 0.0, 1.0);
		float final_alpha = alpha * tex.a * cloud_color.a * horizon_fade;
		
		final_color = mix(base_sky, tex.rgb * cloud_color.rgb, final_alpha);
	}
	
	COLOR = final_color;
}
