shader_type canvas_item;
uniform bool red_team = false;
uniform float flash = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a < 0.30) { discard; }
	if (red_team && c.b > c.r * 1.2 && c.g > c.r * 1.05) {
		float value = dot(c.rgb, vec3(0.333));
		c.rgb = vec3(0.76, 0.27, 0.22) * (value * 1.6 + 0.2);
	}
	c.rgb = mix(c.rgb, vec3(1.0, 0.85, 0.60), flash * 0.55);
	c.a = 1.0;
	COLOR = c;
}
