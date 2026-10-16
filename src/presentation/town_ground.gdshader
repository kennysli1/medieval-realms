shader_type canvas_item;
render_mode unshaded;

uniform sampler2D road_map : filter_nearest, repeat_disable;
uniform sampler2D grass_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D stone_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool show_grid = false;
uniform bool has_square = true;
uniform int gate_count = 0;
uniform vec4 gates[32];

vec2 road(vec2 cell) {
	if (any(lessThan(cell, vec2(0.0))) || any(greaterThanEqual(cell, vec2(32.0)))) { return vec2(0.0); }
	return texture(road_map, (cell + vec2(0.5)) / 32.0).rg;
}

float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 v = b - a;
	return length(p - a - v * clamp(dot(p - a, v) / max(dot(v, v), 0.0001), 0.0, 1.0));
}

void fragment() {
	vec2 g = UV * 32.0 - vec2(0.5);
	vec2 cell = floor(g + vec2(0.5));
	float stone_d = 100.0;
	float dirt_d = 100.0;
	// Union in the ground plane: junctions share the exact same width and UVs.
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 c = cell + vec2(float(x), float(y));
			vec2 material = road(c);
			if (material.r < 0.5) { continue; }
			float width = material.g > 0.5 ? 0.29 : 0.20;
			float d = length(g - c) - width;
			if (road(c + vec2(1, 0)).r > 0.5) {
				d = min(d, segment_distance(g, c, c + vec2(1, 0)) - width);
			}
			if (road(c + vec2(0, 1)).r > 0.5) {
				d = min(d, segment_distance(g, c, c + vec2(0, 1)) - width);
			}
			if (material.g > 0.5) { stone_d = min(stone_d, d); }
			else { dirt_d = min(dirt_d, d); }
		}
	}
	if (has_square) {
		vec2 q = abs(g - vec2(16, 15)) - vec2(1.25);
		float square = length(max(q, vec2(0))) + min(max(q.x, q.y), 0.0) - 0.18;
		stone_d = min(stone_d, square);
	}
	for (int i = 0; i < 32; i++) {
		if (i >= gate_count) { break; }
		dirt_d = min(dirt_d, segment_distance(g, gates[i].xy, gates[i].zw) - 0.105);
	}
	vec3 grass = texture(grass_texture, UV * 5.0).rgb;
	grass = mix(vec3(0.35, 0.44, 0.25), grass * vec3(0.87, 1.02, 0.75), 0.42);
	vec3 dirt = texture(dirt_texture, UV * 9.0).rgb;
	float grain = dot(dirt, vec3(0.333));
	vec3 soil = mix(vec3(0.51, 0.44, 0.30), dirt * vec3(1.16, 1.10, 0.90), 0.48);
	vec3 stone = texture(stone_texture, UV * 12.0).rgb;
	stone = mix(vec3(0.55, 0.53, 0.43), stone * vec3(1.03, 0.99, 0.88), 0.70);
	float worn_edge = (grain - 0.5) * 0.045;
	float soil_mask = 1.0 - smoothstep(-0.025, 0.095, dirt_d + worn_edge);
	float stone_mask = 1.0 - smoothstep(-0.018, 0.045, stone_d + worn_edge * 0.25);
	vec3 color = mix(grass, soil, soil_mask);
	color = mix(color, stone, stone_mask);
	float edge_d = min(dirt_d, stone_d);
	float rim = (1.0 - smoothstep(0.01, 0.10, edge_d)) * smoothstep(-0.035, 0.01, edge_d);
	color *= 1.0 - rim * 0.12;
	if (show_grid) {
		vec2 edge = abs(fract(g + 0.5) - 0.5);
		float line = smoothstep(0.475, 0.497, max(edge.x, edge.y));
		color = mix(color, vec3(0.82, 0.78, 0.51), line * 0.25);
	}
	COLOR = vec4(color, 1.0);
}
