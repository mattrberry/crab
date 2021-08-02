#version 330 core

out vec2 tex_coord;

uniform float aspect;
uniform float scale;

const vec2 vertices[4] = vec2[](vec2(-1.0, -1.0), vec2(1.0, -1.0), vec2(-1.0, 1.0), vec2(1.0, 1.0));

void main() {
    vec2 scaled_xy = vec2(vertices[gl_VertexID]) * scale;
    gl_Position = vec4(scaled_xy.x, scaled_xy.y * aspect, 0.0, 1.0);
    tex_coord = (vertices[gl_VertexID] + 1.0) / vec2(2.0, -2.0);
}
