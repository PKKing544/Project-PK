shader_type canvas_item;

uniform float outline_width : hint_range(0.0, 10.0, 0.1) = 2.0;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest, repeat_disable;

void fragment() {
	vec4 col = texture(screen_texture, SCREEN_UV);
	vec2 ps = SCREEN_PIXEL_SIZE;
	float a;
	float maxa = col.a;
	float mina = col.a;

	a = texture(screen_texture, SCREEN_UV + vec2(0.0, -outline_width) * ps).a;
	maxa = max(a, maxa);
	mina = min(a, mina);

	a = texture(screen_texture, SCREEN_UV + vec2(0.0, outline_width) * ps).a;
	maxa = max(a, maxa);
	mina = min(a, mina);

	a = texture(screen_texture, SCREEN_UV + vec2(-outline_width, 0.0) * ps).a;
	maxa = max(a, maxa);
	mina = min(a, mina);

	a = texture(screen_texture, SCREEN_UV + vec2(outline_width, 0.0) * ps).a;
	maxa = max(a, maxa);
	mina = min(a, mina);
	
	// Diagonal sampling for rounder outlines
	float diag = outline_width * 0.7071;
	a = texture(screen_texture, SCREEN_UV + vec2(-diag, -diag) * ps).a;
	maxa = max(a, maxa);
	mina = min(a, mina);
	a = texture(screen_texture, SCREEN_UV + vec2(diag, diag) * ps).a;
	maxa = max(a, maxa);
	mina = min(a, mina);
	a = texture(screen_texture, SCREEN_UV + vec2(-diag, diag) * ps).a;
	maxa = max(a, maxa);
	mina = min(a, mina);
	a = texture(screen_texture, SCREEN_UV + vec2(diag, -diag) * ps).a;
	maxa = max(a, maxa);
	mina = min(a, mina);

	vec4 final_color = mix(col, outline_color, maxa - mina);

	if (final_color.a > 0.0001) {
		final_color.rgb /= final_color.a;
	}

	COLOR = final_color;
}
