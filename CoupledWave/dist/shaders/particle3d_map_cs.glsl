#version 450

#include "hash_cs.h.glsl"

layout(local_size_x = 1024) in;

struct Particle
{
   vec4 pos;
   vec4 vel;
   vec4 acc;
};

layout (std430, binding = 0) restrict buffer PARTICLES 
{
	Particle particles[];
};

layout(location = 0) uniform int uMode=0; 
layout(location = 1) uniform int uNumElements=0;

const int MODE_INIT = 0;
const int MODE_ADVECT = 1;

void InitParticle(int ix);
void AdvectParticle(int ix);

void main()
{
	int gid = int(gl_GlobalInvocationID.x);
	if(gid >= uNumElements) return;

	switch(uMode)
	{
		case MODE_INIT:
			InitParticle(gid);
		break;

		case MODE_ADVECT:
			AdvectParticle(gid);
		break;
	}
}

void InitParticle(int ix)
{
	vec3 p = hash(vec3(ix, 23.0*ix, ix+15.0));
	p = 2.0*p-vec3(1.0);
	p.z *= 0.2;
	particles[ix].pos = vec4(p, 1.0);	
	particles[ix].vel = vec4(0.0);
	particles[ix].acc = vec4(0.0);
}

void AdvectParticle(int ix)
{
	const float dt = 0.01;
	Particle p = particles[ix];
	float r = length(p.pos.xy);
	float theta = atan(p.pos.y, p.pos.x);
	//vec3 v_cyl = vec3(0.0, 1.0, 0.0);
	vec3 v_cyl = vec3(0.0, 1.0, sin(6.0*theta));

	vec3 e_r = vec3(cos(theta), sin(theta), 0.0);
	vec3 e_theta = e_r.yxz*vec3(1.0, -1.0, 0.0);
	vec3 e_z = vec3(0.0, 0.0, 1.0);

	vec3 v_cart = v_cyl[0]*e_r + v_cyl[1]*e_theta + v_cyl[2]*e_z;
	p.vel.xyz = v_cart;

	p.pos += dt*p.vel;
	particles[ix] = p;
}

