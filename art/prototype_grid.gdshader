shader_type spatial;

uniform vec3 albedo_color : source_color = vec3(0.12, 0.12, 0.12);
uniform vec3 grid_color : source_color = vec3(0.25, 0.25, 0.25);
uniform float grid_size = 1.0;
uniform float line_width = 0.05;

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
	// Triplanar mapping logic
	float x_grid = get_grid(world_pos.zy);
	float y_grid = get_grid(world_pos.xz);
	float z_grid = get_grid(world_pos.xy);
	
	// Normalize weights
	vec3 weights = world_normal / (world_normal.x + world_normal.y + world_normal.z);
	float final_grid = x_grid * weights.x + y_grid * weights.y + z_grid * weights.z;
	
	ALBEDO = mix(albedo_color, grid_color, final_grid);
	ROUGHNESS = 0.8;
}
