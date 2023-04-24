#version 450
#include "hash_cs.h.glsl"
#include "std_uniforms.h.glsl"
#line 4

layout(local_size_x = 1024) in;

struct Particle
{
   vec4 pos;
   vec4 vel;
   vec4 acc;
};

#define COHERENT
//#define SHARED

#ifdef COHERENT
	layout (std430, binding = 0) restrict coherent buffer PARTICLES 
	{
		Particle particles[];
	};
#else
	layout (std430, binding = 0) restrict buffer PARTICLES 
	{
		Particle particles[];
	};
#endif

#ifdef SHARED
	shared Particle shared_particles[1024];
#endif



layout(location = 0) uniform int uMode=0; 
layout(location = 1) uniform int uNumElements=0;

const int MODE_INIT = 0;
const int MODE_ADVECT = 1;

void InitParticle(int ix);
void AdvectParticle(int ix);

void InitFlock(int ix);
void Flock(int ix);

void main()
{
	int gid = int(gl_GlobalInvocationID.x);
	if(gid >= uNumElements) return;

	switch(uMode)
	{
		case MODE_INIT:
			//InitParticle(gid);
			InitFlock(gid);
		break;

		case MODE_ADVECT:
			//AdvectParticle(gid);
			Flock(gid);
		break;
	}
}

void InitParticle(int ix)
{
	vec3 rand = 2.0*uhash3(uvec3(ix+10, 2*ix, 3*ix))-vec3(1.0);
	particles[ix].pos = vec4(2.0*rand.xy, 0.0, 1.0);	
	particles[ix].vel = vec4(0.0);
	particles[ix].acc = vec4(0.0);
}

void AdvectParticle(int ix)
{
	const float dt = 0.0005;
	Particle p = particles[ix];
	vec3 rand = 5.0*uhash3(uvec3(ix, 2*ix, 3*ix));
	vec2 v = rand.x*normalize(vec2(-p.pos.y, p.pos.x));
	p.vel = vec4(v, 0.0, 0.0);
	p.pos += dt*p.vel;

	particles[ix] = p;
}

void InitFlock(int ix)
{
	vec3 rand = 2.0*uhash3(uvec3(ix, 2*ix, 3*ix))-vec3(1.0);
	particles[ix].pos = vec4(rand.xy, 0.0, 10.0+15.0*abs(rand.z));	
	particles[ix].vel = vec4(1.0*normalize(2.0*rand.zy-vec2(0.0)), 0.0, 1.0);
	particles[ix].acc = vec4(0.0);
}
/*
uniform float d_separation = 0.05;
uniform float d_cohesion = 0.1;
uniform float d_alignment = 0.1;
	
uniform float w_separation = 0.13;
uniform float w_cohesion = 0.01;
uniform float w_alignment = 0.2;
uniform float w_center = 0.1;

vec3 v0(vec3 p)
{
	float time = SceneUniforms.Time;
	vec3 v = vec3(sin(-p.y*10.0+time/2.0-10.0), sin(-p.x*10.0+1.2*time+10.0), cos(+7.0*p.z -5.0*p.x + time+10.0));
	return v;
}

void Flock(int ix)
{
	const float dt = 0.002;
	const float eps = 1e-6; //avoid div by 0

	vec3 separation = vec3(0.0);
	vec3 cohesion = vec3(0.0);
	vec3 alignment = vec3(0.0);

	Particle pi = particles[ix];

	//pi.vel.xyz += 0.001*v0(pi.pos.xyz); //advection
	pi.vel.xyz += dt*pi.acc.xyz;
	pi.pos.xyz += dt*pi.vel.xyz;

	//wrap
	if(pi.pos.x < -1.0) pi.pos.x += 2.0;
	if(pi.pos.y < -1.0) pi.pos.y += 2.0;
	if(pi.pos.x > +1.0) pi.pos.x -= 2.0;
	if(pi.pos.y > +1.0) pi.pos.y -= 2.0;

	pi.acc *= 0.1;
	for(int jx=0; jx<uNumElements; jx++)
	{
		if(ix==jx) continue;
		Particle pj = particles[jx];
		
		vec3 r = pj.pos.xyz-pi.pos.xyz;
		float d = length(r);
		//r = r/d;

		if(d<d_separation)	separation -= r/d/d;
		if(d<d_cohesion)	cohesion += r;
		if(d<d_alignment)	alignment += pj.vel.xyz;
	}
	
	if(any(notEqual(separation.xyz, vec3(0.0))))	pi.acc.xyz += w_separation*normalize(separation);
	if(any(notEqual(cohesion.xyz, vec3(0.0))))		pi.acc.xyz += w_cohesion*normalize(cohesion);
	if(any(notEqual(alignment.xyz, vec3(0.0))))		pi.acc.xyz += w_alignment*normalize(alignment);


	vec3 u = normalize(pi.vel.xyz);
	float udota = dot(u, pi.acc.xyz);
	if(udota > 0.0)
	{
		pi.acc.xyz -= udota*u;
	}
	
	//clamp vel and acc
	const float vmax = 0.3;
	float vmag = length(pi.vel.xyz);
	if(vmag > vmax)
	{
		pi.vel.xyz = vmax*pi.vel.xyz/vmag;
	}
	
	const float amax = 0.9;
	float amag = length(pi.acc.xyz);
	if(amag > amax)
	{
		pi.acc.xyz = amax*pi.acc.xyz/amag;
	}

	particles[ix] = pi;
}
//*/


//*
uniform float d_separation = 0.005;
uniform float d_cohesion = 0.21;
uniform float d_alignment = 0.1;
	
uniform float w_separation = 0.68;
uniform float w_cohesion = 0.016;
uniform float w_alignment = 0.024;
uniform float w_center = 0.1;

uniform float maxforce = 50.0;
uniform float maxspeed = 1.0;

vec3 limit(vec3 v, float max_mag)
{
	if(length(v) > max_mag)
	{
		v = max_mag*normalize(v);
	}
	return v;
}

vec3 steer(vec3 desired, vec3 vel)
{	
	vec3 steer_force = desired-vel;
	return steer_force;
}

vec3 seek(vec3 target, vec3 pos, vec3 vel)
{
	vec3 desired = target-pos;
	return steer(desired, vel);
}

void Flock(int ix)
{
	Particle pi = particles[ix];

	#ifdef SHARED
		shared_particles[ix] = pi;
		memoryBarrierShared();
		barrier();
	#endif


	const float dt = 0.001;
	const float eps = 1e-6; //avoid div by 0

	vec3 separation = vec3(0.0);
	vec3 cohesion = vec3(0.0);
	vec3 alignment = vec3(0.0);

	

	pi.vel.xyz += dt*pi.acc.xyz;
	pi.pos.xyz += dt*pi.vel.xyz;

	//wrap
	if(pi.pos.x < -1.0) pi.pos.x += 2.0;
	if(pi.pos.y < -1.0) pi.pos.y += 2.0;
	if(pi.pos.x > +1.0) pi.pos.x -= 2.0;
	if(pi.pos.y > +1.0) pi.pos.y -= 2.0;

	pi.vel.xyz *= 0.975;
	pi.acc.xyz *= 0.0;

	int n = 0;
	for(int jx=0; jx<uNumElements; jx++)
	{
		if(ix==jx) continue;

		#ifdef SHARED
			Particle pj = shared_particles[jx];
		#else
			Particle pj = particles[jx];
		#endif

		vec3 r = pj.pos.xyz-pi.pos.xyz;
		float d = length(r);

		if(d<d_separation)									separation -= r/d/d;
		if(d<d_cohesion && d>d_separation && ix%2==jx%2)	cohesion += r/d;
		if(d<d_alignment && ix%2==jx%2)						alignment += pj.vel.xyz/d;

		if(d>d_alignment && ix%2!=jx%2)	alignment += pj.vel.yxz*vec3(-1.0, 1.0, 1.0);
		if(d<d_cohesion && d>d_separation && ix%2!=jx%2)	cohesion -= r/d/d;
		
	}
	
	if(any(notEqual(separation.xyz, vec3(0.0))))	pi.acc.xyz += w_separation*steer(separation, pi.vel.xyz);
	if(any(notEqual(cohesion.xyz, vec3(0.0))))		pi.acc.xyz += w_cohesion*steer(cohesion, pi.vel.xyz);
	if(any(notEqual(alignment.xyz, vec3(0.0))))		pi.acc.xyz += w_alignment*steer(alignment, pi.vel.xyz);

	//clamp vel and acc
	pi.vel.xyz = limit(pi.vel.xyz, maxspeed);
	pi.acc.xyz = limit(pi.acc.xyz, maxforce);

	particles[ix] = pi;
}
//*/