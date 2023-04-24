#version 450 

#include "std_uniforms.h.glsl"

struct Particle
{
   vec4 pos;
   vec4 vel;
   vec4 acc;
};

layout (std430, binding = 0) readonly restrict buffer PARTICLES
{
	Particle particles[];
};

//https://www.shadertoy.com/view/ll2GD3
// cosine based palette, 4 vec3 params
vec3 palette( in float t, in vec3 a, in vec3 b, in vec3 c, in vec3 d )
{
    return a + b*cos( 6.28318*(c*t+d) );
}

vec3 rainbow( float t)
{
	return palette(t, vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,1.0),vec3(0.0,0.33,0.67) );
}

out VertexData
{
	vec3 pw;		//world-space vertex position
	vec3 peye;		//eye-space position
	vec3 color;
} outData; 

void main(void)
{
	vec4 sph = particles[gl_VertexID].pos;
	vec4 p = vec4(sph.xy, 0.0, 1.0);
	gl_Position = SceneUniforms.P_ortho*p; //transform vertices and send result into pipeline
	
	outData.pw = p.xyz;
	vec4 clip = SceneUniforms.P_ortho*vec4(sph.w, sph.w, 0.0, 0.0);
	vec2 pixel = clip.xy*vec2(SceneUniforms.Viewport.zw);
	gl_PointSize = min(pixel.x, pixel.y);
	outData.color = rainbow(float(gl_VertexID)*0.1);
}