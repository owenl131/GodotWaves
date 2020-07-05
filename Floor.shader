shader_type spatial;
render_mode cull_disabled;

float sigmoid(float x) {
	return 1.0 / (1.0 + exp(-100.0 * x + 50.0));
}

float depth(float x, float y) {
	x *= 0.003; // -0.1 to 0.1
	y *= 0.006;
	return (sigmoid(x + 0.48) * sigmoid(y + 0.48)) * 6.0 - 4.0;
}

void vertex() {
	VERTEX.y = depth(VERTEX.x, VERTEX.z);
}

void fragment() {
	ALBEDO = vec3(0.63, 0.6, 0.35);
}