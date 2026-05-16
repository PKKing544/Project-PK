// Bayer 4x4 Ordered Dithering
// fade_amount: 0.0 = fully invisible, 1.0 = fully solid
// Call: if (dither_check(FRAGCOORD.xy, fade_amount)) discard;

float bayer4x4(vec2 frag_coord) {
	float m[16] = float[16](
		 0.0/16.0,  8.0/16.0,  2.0/16.0, 10.0/16.0,
		12.0/16.0,  4.0/16.0, 14.0/16.0,  6.0/16.0,
		 3.0/16.0, 11.0/16.0,  1.0/16.0,  9.0/16.0,
		15.0/16.0,  7.0/16.0, 13.0/16.0,  5.0/16.0
	);
	int idx = int(mod(frag_coord.y, 4.0)) * 4 + int(mod(frag_coord.x, 4.0));
	return m[idx];
}

bool dither_check(vec2 frag_coord, float fade_amount) {
	return fade_amount < bayer4x4(frag_coord);
}
