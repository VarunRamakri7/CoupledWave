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

layout(location=5) uniform float uParticleSize = 20.0;

out VertexData
{
	vec4 pos;
	vec4 vel;		
	vec4 acc;
	flat int id;	
} outData; 

void main(void)
{
	outData.id = gl_VertexID;
	outData.pos = particles[gl_VertexID].pos;
	outData.vel = particles[gl_VertexID].vel;
	outData.acc = particles[gl_VertexID].acc;

	vec4 p = particles[gl_VertexID].pos;
	p.zw = vec2(0.0, 1.0);
	
	gl_Position = p; 
	gl_PointSize = uParticleSize;
}