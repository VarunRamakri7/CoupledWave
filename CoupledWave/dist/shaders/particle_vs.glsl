#version 450 

#include "std_uniforms.h.glsl"

layout(location = 0) in vec4 pos_attrib; 
layout(location = 1) in vec4 vel_attrib;
layout(location = 2) in vec4 acc_attrib; 

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
	outData.pos = pos_attrib;
	outData.vel = vel_attrib;
	outData.acc = acc_attrib;

	vec4 p = pos_attrib;
	p.zw = vec2(0.0, 1.0);
	
	gl_Position = p; 
	gl_PointSize = uParticleSize;
}