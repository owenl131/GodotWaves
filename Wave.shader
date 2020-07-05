shader_type spatial;
render_mode cull_disabled;

uniform float pi = 3.141592;

// should let each wave component be represented 
// by a vec4 of kx, kz, amplitude and phase

uniform vec4 wave1 = vec4(1.0, 2.0, 0.05, 0.0);
uniform vec4 wave2 = vec4(2.0, 1.5, 0.1, 0.1);
uniform vec4 wave3 = vec4(0.2, 0.0, 0.0, 0.0);

float sigmoid(float x) {
	return 1.0 / (1.0 + exp(-100.0 * x + 50.0));
}

float calcdepth(float x, float y) {
	x *= 0.003; // -0.1 to 0.1
	y *= 0.006;
	return (sigmoid(x + 0.48) * sigmoid(y + 0.48)) * 6.0 - 4.0;
}

float calcAbsDepth(vec2 pos) {
	return abs(calcdepth(pos.x, pos.y)) + 0.2;
}

float calcK(vec4 wave) {
	return sqrt(wave.x * wave.x + wave.y * wave.y);
}

float calcOmega(vec4 wave, float depth) {
	float kx = wave.x;
	float kz = wave.y;
	float k = calcK(wave);
	return sqrt(9.81 * k * tanh(k * depth));
}

float calcTheta(vec4 wave, vec3 position, float t) {
	float kx = wave.x;
	float kz = wave.y;
	float alpha = position.x;
	float beta = position.z;
	float depth = calcAbsDepth(position.xz);
	float omega = calcOmega(wave, depth);
	float phase = wave.w;
	return kx * alpha + kz * beta - omega * t - phase;
}

vec2 calcScalar(vec4 wave, float depth) {
	float k = calcK(wave);
	float kx = wave.x;
	float kz = wave.y;
	float amp = wave.z;
	float intermediate = (amp / tanh(k * depth)) / k;
	return vec2(intermediate * kx, intermediate * kz);
}

vec3 applyWave(vec3 position, vec3 original, vec4 wave, float t) {
	float depth = calcAbsDepth(original.xz);
	float theta = calcTheta(wave, original, t);
	vec2 scalar = calcScalar(wave, depth);
	float amp = wave.z;
	return position + vec3(
		-scalar.x * sin(theta),
		amp * cos(theta),
		-scalar.y * sin(theta));
}

vec3 calcPosition(vec3 original, float t) {
	vec3 result = original;
	result = applyWave(result, original, wave1, t);
	result = applyWave(result, original, wave2, t);
	result = applyWave(result, original, wave3, t);
	return result;
}

void applyWaveNormal(inout vec3 dsda, inout vec3 dsdb, vec3 original, vec4 wave, float t) {
	float dThetada = wave.x;
	float dThetadb = wave.y;
	float amp = wave.z;
	float theta = calcTheta(wave, original, t);
	float dsinThetada = cos(theta) * dThetada;
	float dsinThetadb = cos(theta) * dThetadb;
	float depth = calcAbsDepth(original.xz);
	vec2 scalar = calcScalar(wave, depth);
	dsda += vec3(
		-scalar.x * dsinThetada, 
		-amp * sin(theta) * dThetada,
		-scalar.y * dsinThetada
	);
	dsdb += vec3(
		-scalar.x * dsinThetadb, 
		-amp * sin(theta) * dThetadb,
		-scalar.y * dsinThetadb
	);
}

vec3 calcNormal(vec3 original, float t) {
	vec3 dsda = vec3(1.0, 0.0, 0.0);
	vec3 dsdb = vec3(0.0, 0.0, 1.0);
	applyWaveNormal(dsda, dsdb, original, wave1, t);
	applyWaveNormal(dsda, dsdb, original, wave2, t);
	applyWaveNormal(dsda, dsdb, original, wave3, t);
	vec3 normal = normalize(cross(dsda, dsdb));
	return normal;
}

void vertex() {
	float t = TIME;
	NORMAL = calcNormal(VERTEX, t);
	VERTEX = calcPosition(VERTEX, t);
}

void fragment() {
	// vec4 worldCoords = CAMERA_MATRIX * vec4(VERTEX, 1.0);
	float t = TIME;
	vec3 coord = vec3(UV.x - 0.5, 0, UV.y - 0.5) * 30.0;
	vec3 pos = calcPosition(coord, t);
	float depth = calcdepth(pos.x, pos.z); // worldCoords.y; // calcdepth((UV.x - 0.5) * 20.0, (UV.y - 0.5) * 20.0);
	if (depth >= 0.2) {
		discard;
	}
	vec3 seaColor = vec3(0, 0.4, 0.8);
	vec3 foamColor = vec3(0.8, 0.9, 1.0);
	float threshold = 1.0;
	if (depth < -threshold) {
		ALBEDO = seaColor;
		ALPHA = 0.6;
	} 
	else {
		// depth runs from -0.5 to 0
		depth = (depth + threshold) / threshold;
		
		ALBEDO = mix(seaColor, foamColor, depth);
		ALPHA = mix(0.6, 0.2, depth);
	}
}

