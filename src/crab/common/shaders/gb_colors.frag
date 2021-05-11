#version 330 core

in vec2 tex_coord;
out vec4 frag_color;

uniform sampler2D input_texture;

mat3 m = mat3(
  26, 0, 6,
  4, 24, 4,
  2, 8, 22
);

void main() {
  // Credits to [unknown] and Near for this color-correction algorithm.
  // https://byuu.net/video/color-emulation
  vec4 color = texture(input_texture, tex_coord);
  frag_color.rgb = min(vec3(30), m * color.rgb / 32);
  frag_color.a = 0.5;
}
