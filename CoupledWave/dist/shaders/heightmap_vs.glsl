#version 450 

layout(binding = 0) uniform sampler2D heightmap_tex;

layout(location=0) uniform mat4 M = mat4(1.0);
layout(location=3) uniform float scale = 1.0;
layout (location=1000) uniform ivec2 nxy = ivec2(10, 10);

#include "std_uniforms.h.glsl"
uniform float offset_h = 0.0;
layout(location=20) uniform float wave_scale = 1.0;
layout(location=21) uniform vec2 wave_shift = vec2(0.0);

out VertexData
{
   vec2 tex_coord;
   vec3 pw;			//world-space vertex position
   vec3 nw;			//world-space normal vector
   vec3 peye;		//eye-space position
   float wave_h;
} outData; 

//The rectangle that gets covered by an nxy.x x nxy.y mesh of vertices
const vec4 rect[4] = vec4[](vec4(-1.0, -1.0, 0.0, 1.0), vec4(+1.0, -1.0, 0.0, 1.0),
							vec4(-1.0, +1.0, 0.0, 1.0), vec4( +1.0, +1.0, 0.0, 1.0));

const ivec2 offset[6] = ivec2[](ivec2(0,0), ivec2(1,0), ivec2(0, 1), ivec2(1, 0), ivec2(0, 1), ivec2(1,1));

//This is just generating a grid in attributeless fashion
void grid_vertex(out vec4 pos, out vec2 uv, out ivec2 ij)
{
	//ivec2 nxy = textureSize(heightmap_tex, 0).xy;
	ivec2 qxy = nxy - ivec2(1); //number of rows and columns of quads
	int q = gl_VertexID/6;	//1D quad index (two triangles)
	int v = gl_VertexID%6;	//vertex index within the quad
	ij = ivec2(q%qxy.x, q/qxy.x); //2D quad index of current vertex
	ij += offset[v]; //2D grid index of each point
	uv = ij/vec2(nxy);
	pos = mix(mix(rect[0], rect[1], uv.s), mix(rect[2], rect[3], uv.s), uv.t);
}

vec3 calc_normal(ivec2 ij);

void main(void)
{
	vec4 pos;
	vec2 uv;
	ivec2 ij;
	grid_vertex(pos, uv, ij);
	float height = textureLod(heightmap_tex, uv, 0).r + offset_h;
	pos.zw = vec2(scale*height, 1.0);
	pos.xy *= wave_scale;
	pos.xy += wave_shift;
	pos = pos.xzyw-vec4(0.0, 0.5, 0.0, 0.0);
	gl_Position = SceneUniforms.PV*M*pos;
	outData.pw = vec3(M*pos);			//world-space vertex position
	outData.nw = vec3(M*vec4(calc_normal(ij).xzy, 0.0));	//world-space normal vector
	outData.peye = vec3(SceneUniforms.V*vec4(outData.pw, 1.0));
	outData.tex_coord = uv;
	outData.wave_h = height;
}

vec3 calc_normal(ivec2 ij)
{
	vec3 n;
	n.x = 0.5*scale*(texelFetch(heightmap_tex, ij+ivec2(1,0), 0).r - texelFetch(heightmap_tex, ij-ivec2(1,0), 0).r);
	n.y = 0.5*scale*(texelFetch(heightmap_tex, ij+ivec2(0,1), 0).r - texelFetch(heightmap_tex, ij-ivec2(0,1), 0).r);
	n.z = 0.01;

	return n;
}