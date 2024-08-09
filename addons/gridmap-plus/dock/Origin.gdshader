// This is copied verbatim from Godot Engine and thus has the same licensing
// requirements as the engine itself.

// 3D editor origin line shader.

shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, fog_disabled;

void vertex() {
	vec3 point_a = MODEL_MATRIX[3].xyz;
	// Encoded in scale.
	vec3 point_b = vec3(MODEL_MATRIX[0].x, MODEL_MATRIX[1].y, MODEL_MATRIX[2].z);

	// Points are already in world space, so no need for MODEL_MATRIX anymore.
	vec4 clip_a = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(point_a, 1.0));
	vec4 clip_b = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(point_b, 1.0));

	vec2 screen_a = VIEWPORT_SIZE * (0.5 * clip_a.xy / clip_a.w + 0.5);
	vec2 screen_b = VIEWPORT_SIZE * (0.5 * clip_b.xy / clip_b.w + 0.5);

	vec2 x_basis = normalize(screen_b - screen_a);
	vec2 y_basis = vec2(-x_basis.y, x_basis.x);

	float width = 3.0;
	vec2 screen_point_a = screen_a + width * (VERTEX.x * x_basis + VERTEX.y * y_basis);
	vec2 screen_point_b = screen_b + width * (VERTEX.x * x_basis + VERTEX.y * y_basis);
	vec2 screen_point_final = mix(screen_point_a, screen_point_b, VERTEX.z);

	vec4 clip_final = mix(clip_a, clip_b, VERTEX.z);

	POSITION = vec4(clip_final.w * ((2.0 * screen_point_final) / VIEWPORT_SIZE - 1.0), clip_final.z, clip_final.w);
	UV = VERTEX.yz * clip_final.w;

	if (!OUTPUT_IS_SRGB) {
		COLOR.rgb = mix(pow((COLOR.rgb + vec3(0.055)) * (1.0 / (1.0 + 0.055)), vec3(2.4)), COLOR.rgb * (1.0 / 12.92), lessThan(COLOR.rgb, vec3(0.04045)));
	}
}

void fragment() {
	// Multiply by 0.5 since UV is actually UV is [-1, 1].
	float line_width = fwidth(UV.x * 0.5);
	float line_uv = abs(UV.x * 0.5);
	float line = smoothstep(line_width * 1.0, line_width * 0.25, line_uv);

	ALBEDO = COLOR.rgb;
	ALPHA *= COLOR.a * line;
}