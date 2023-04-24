#version 450
#include "hash_cs.h.glsl"
#define LOCAL_SIZE 1024
layout(local_size_x = LOCAL_SIZE) in;

struct Particle
{
   vec4 pos;
   vec4 vel;
   vec4 acc;
};

float GetRadius(Particle p) {return p.pos.w;}
void SetRadius(inout Particle p, float r) {p.pos.w = r;}

uniform float r = 0.02; //all particles have the same radius
uniform float mass = 1.0; //all particles have the same mass
uniform float e = 0.9; //coefficient of elasticity
uniform float k = 1000.0; //separation spring
uniform float c = 10.0; //separation damper
uniform float dt = 0.0005; //timestep

const int EXPLICIT_EULER = 0;
const int SEMI_IMPLICIT_EULER = 1;
const int VERLET = 2;
uniform int integrator = EXPLICIT_EULER;

const float eps = 1e-6;

layout (std430, binding = 0) restrict buffer PARTICLES_IN 
//layout (std430, binding = 0) restrict readonly buffer PARTICLES_IN 
{
	Particle particles_in[];
};

layout (std430, binding = 1) restrict buffer PARTICLES_OUT
//layout (std430, binding = 1) restrict writeonly buffer PARTICLES_OUT 
{
	Particle particles_out[];
};

const int TILE_SIZE = LOCAL_SIZE;
shared Particle shared_particles[TILE_SIZE];

layout(location = 0) uniform int uMode=0; 
layout(location = 1) uniform int uNumElements=0;

const int MODE_INIT = 0;
const int MODE_ANIM = 1;

void InitParticle(int ix);
void AnimParticle(int ix);
void AnimParticleTiled(int ix);

void main()
{
	int gid = int(gl_GlobalInvocationID.x);
	
	switch(uMode)
	{
		case MODE_INIT:
			if(gid >= uNumElements) return;
			InitParticle(gid);
		break;

		case MODE_ANIM:
			//AnimParticle(gid);
			AnimParticleTiled(gid);
		break;
	}
}

void InitParticle(int ix)
{
	Particle p;
	vec3 rand = 2.0*uhash3(uvec3(ix, uNumElements, 0))-vec3(1.0);
	p.pos.xyz = vec3(rand.xy, 0.0);	
	p.vel = vec4(0.0);
	p.acc = vec4(0.0);
	SetRadius(p, r);

	particles_in[ix] = p;
	particles_out[ix] = p;
}

void wall_collision_acc(inout Particle pi, vec4 plane);

void AnimParticle(int ix)
{
	if(ix >= uNumElements) return;
	Particle pi = particles_in[ix];
	float ri = GetRadius(pi);
	float mi = mass;

	//update shared memory
	shared_particles[ix] = pi;
	barrier();
	
	pi.acc.xyz = vec3(0.0, -1.0, 0.0); //gravity

	//wall collisions
	const vec4 wall[4] = vec4[](vec4(+1.0, 0.0, 0.0, -1.0),
								vec4(-1.0, 0.0, 0.0, -1.0),
								vec4(0.0, +1.0, 0.0, -1.0),
								vec4(0.0, -1.0, 0.0, -1.0));

	for(int i=0; i<4; i++)
	{
		wall_collision_acc(pi, wall[i]);
	}

	for(int jx=0; jx<uNumElements; jx++)
	{
		if(jx==ix) continue; //no self-interactions
		//Particle pj = shared_particles[jx];
		Particle pj = particles_in[jx];

		float rj = GetRadius(pj);
		float mj = mass;
		vec3 nij = pi.pos.xyz - pj.pos.xyz;
		float d = length(nij)+eps;
		vec3 uij = nij/d;

		if(d < ri + rj)
		{
			//compute collision impulse
			vec3 vij = pi.vel.xyz - pj.vel.xyz;
			float vuij = dot(vij,uij);
			float j = -(1.0+e)*vuij/(1.0/mi + 1.0/mj);
			pi.acc.xyz += max(0.0, j/mi/dt)*uij;

			//damped spring separation force
			float L = ri+rj-d;
			pi.acc.xyz += (k*L - c*vuij)*uij/mi;
		}
	}

	if(integrator==EXPLICIT_EULER)
	{
		pi.pos += dt*pi.vel;
		pi.vel += dt*pi.acc;
	}
	else if(integrator==SEMI_IMPLICIT_EULER)
	{
		pi.vel += dt*pi.acc;
		pi.pos += dt*pi.vel;
	}

	particles_out[ix] = pi;
}


void AnimParticleTiled(int ix)
{
	Particle pi = particles_in[ix];
	float ri = GetRadius(pi);
	float mi = mass;

	pi.acc.xyz = vec3(0.0, -1.0, 0.0); //gravity

	//wall collisions
	const vec4 wall[4] = vec4[](vec4(+1.0, 0.0, 0.0, -1.0),
								vec4(-1.0, 0.0, 0.0, -1.0),
								vec4(0.0, +1.0, 0.0, -1.0),
								vec4(0.0, -1.0, 0.0, -1.0));

	for(int i=0; i<4; i++)
	{
		wall_collision_acc(pi, wall[i]);
	}

	int numTiles = int(ceil(float(uNumElements)/TILE_SIZE));
	for(int tile = 0; tile<numTiles; tile++)
	{
		int tileStart = tile*TILE_SIZE;
		//update shared memory
		if(tileStart+gl_LocalInvocationIndex < uNumElements)
		{
			shared_particles[gl_LocalInvocationIndex] = particles_in[tileStart+gl_LocalInvocationIndex];
		}
		barrier(); //wait here until all threads have written shared memory
		
		if(ix<uNumElements)
		for(int jx=0; jx<TILE_SIZE; jx++)
		{
			if(tileStart+jx >= uNumElements) break;
			if(tileStart+jx==ix) continue; //no self-interactions
 
			Particle pj = shared_particles[jx];
			//Particle pj = particles_in[tileStart+jx];

			float rj = GetRadius(pj);
			float mj = mass;
			vec3 nij = pi.pos.xyz - pj.pos.xyz;
			float d = length(nij)+eps;
			vec3 uij = nij/d;

			if(d < ri + rj)
			{
				//compute collision impulse
				vec3 vij = pi.vel.xyz - pj.vel.xyz;
				float vuij = dot(vij,uij);
				float j = -(1.0+e)*vuij/(1.0/mi + 1.0/mj);
				pi.acc.xyz += max(0.0, j/mi/dt)*uij;

				//damped spring separation force
				float L = ri+rj-d;
				pi.acc.xyz += (k*L - c*vuij)*uij/mi;
			}
		}
		barrier(); //wait here until all threads have read shared memory
	}

	if(ix>=uNumElements) return;

	if(integrator==EXPLICIT_EULER)
	{
		pi.pos += dt*pi.vel;
		pi.vel += dt*pi.acc;
	}
	else if(integrator==SEMI_IMPLICIT_EULER)
	{
		pi.vel += dt*pi.acc;
		pi.pos += dt*pi.vel;
	}
	else if(integrator==VERLET)
	{
		vec4 p_prev = particles_out[ix].pos;
		pi.pos.xyz = 2.0*pi.pos.xyz - p_prev.xyz + pi.acc.xyz*dt*dt;
		pi.vel.xyz = (pi.pos.xyz-p_prev.xyz)/(2.0*dt);
	}

	particles_out[ix] = pi;
}


void wall_collision_acc(inout Particle pi, vec4 plane)
{
	float ri = GetRadius(pi);
	float d = dot(pi.pos.xyz, plane.xyz)-plane.w;
	if(d > ri) return;

	float mi = mass;
	//compute collision impulse
	vec3 uij = plane.xyz;
	vec3 vij = pi.vel.xyz;
	float vuij = dot(vij,uij);
	float j = -(1.0+e)*vuij/(1.0/mi);
	pi.acc.xyz += max(0.0, j/mi/dt)*uij;

	//damped spring separation force
	float L = ri-d;
	pi.acc.xyz += (k*L - c*vuij)*uij/mi;
}