shader_type canvas_item;
render_mode unshaded;

uniform float brightness : hint_range(-50.0, 50.0, 1.0) = 0.0;

void fragment() {
	// Zero preserves the original pixels; gamma keeps black and white intact.
	if (brightness != 0.0) {
		COLOR.rgb = pow(max(COLOR.rgb, vec3(0.0)), vec3(exp2(-brightness * 0.01)));
	}
}
