#version 450 

#include "std_uniforms.h.glsl"
#include "hash_cs.h.glsl"
#line 6
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

layout(location=5) uniform float uParticleSize = 1.0;
uniform float clip_z = 100.0;

out VertexData
{
   vec3 pw;			//world-space vertex position
   vec3 peye;		//eye-space position
   vec3 vel_eye;
   float rand;
   float radius;
   float pressure;
} outData; 

void main(void)
{
	vec4 p = vec4(particles[gl_VertexID].pos.xyz, 1.0);
	if(p.z > clip_z) p.w = 0.0;
	float r = particles[gl_VertexID].pos.w;

	//p.xz *= 0.5;
	
	gl_Position = SceneUniforms.PV*p; 
	outData.peye = vec3(SceneUniforms.V*p);
	outData.pw = p.xyz;
	
	vec3 rand = uhash3(uvec3(gl_VertexID, 1, 0));
	
	outData.rand = rand.x;
	outData.vel_eye = vec3(SceneUniforms.V*vec4(particles[gl_VertexID].vel.xyz, 0.0));
	outData.pressure = particles[gl_VertexID].vel.w;

	gl_PointSize = SceneUniforms.Viewport[3] * SceneUniforms.P[1][1] * r / gl_Position.w;
	outData.radius = r;
}