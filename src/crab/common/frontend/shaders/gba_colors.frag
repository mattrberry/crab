#version 330 core

in vec2 tex_coord;
out vec4 frag_color;

uniform sampler2D input_texture;

void main() {
  // Credits to Talarubi and Near for this color-correction algorithm.
  // https://byuu.net/video/color-emulation
  vec4 color = texture(input_texture, tex_coord);
  float lcdGamma = 4.0, outGamma = 2.2;
  color.rgb = pow(color.rgb, vec3(lcdGamma));
  frag_color.rgb = pow(vec3(  0 * color.b +  50 * color.g + 255 * color.r,
                             30 * color.b + 230 * color.g +  10 * color.r,
                            220 * color.b +  10 * color.g +  50 * color.r) / 255,
                       vec3(1.0 / outGamma));
}
