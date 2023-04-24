#version 450
#include "aabb_cs.h.glsl"
#line 4

layout(local_size_x = 1024) in;

struct Particle
{
   vec4 pos;
   vec4 vel;
   vec4 acc;
};

const int kGridUboBinding = 0;
const int kPointsInBinding = 0;
const int kPointsOutBinding = 1;
const int kCountBinding = 2;
const int kStartBinding = 3;
const int kContentBinding = 4;

layout (std430, binding = kPointsInBinding) restrict readonly buffer PARTICLES_IN 
{
	Particle particles_in[];
};

layout (std430, binding = kPointsOutBinding) restrict writeonly buffer PARTICLES_OUT 
{
	Particle particles_out[];
};

layout (std430, binding = kCountBinding) restrict readonly buffer GRID_COUNTER 
{
	int mCount[];
};

layout (std430, binding = kStartBinding) restrict readonly buffer GRID_START 
{
	int mStart[];
};

layout (std430, binding = kContentBinding) restrict readonly buffer CONTENT_LIST 
{
	int mContent[];
};

#include "grid_2d_cs.h.glsl"
#line 48

layout(location = 0) uniform int uMode=0; 
layout(location = 1) uniform int uNumElements=0;

const int MODE_INIT = 0;
const int MODE_ADVECT = 1;
const int MODE_ADVECT_NO_GRID = 2;

void InitParticle(int ix);
void AdvectParticle(int ix);
void AdvectParticleNoGrid(int ix);
void AdvectParticleNoGrid2(int ix);

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

		case MODE_ADVECT_NO_GRID:
			AdvectParticleNoGrid(gid);
		break;
	}
}

void InitParticle(int ix)
{
	particles_out[ix].pos = vec4(0.1*sin(12345.0*ix), 0.1*cos(67890.0*ix), 0.0, 1.0);		
	particles_out[ix].vel = vec4(0.0);
	particles_out[ix].acc = vec4(0.0);
}

float quadImpulse( float k, float x )
{
    return 2.0*sqrt(k)*x/(1.0+k*x*x);
}

float expSustainedImpulse( float x, float f, float k )
{
    float s = max(x-f,0.0);
    return min( x*x/(f*f), 1.0+(2.0/f)*s*exp(-k*s));
}

void AdvectParticle(int ix)
{
	float dt = 0.001;
	Particle pi = particles_in[ix];

	pi.acc *= 0.5;

	const vec2 box_hw = vec2(0.4);

	aabb2D query_aabb = aabb2D(pi.pos.xy-box_hw, pi.pos.xy+box_hw);
	//These are the cells the query overlaps
	ivec2 cell_min = CellCoord(query_aabb.mMin);
	ivec2 cell_max = CellCoord(query_aabb.mMax);

	for(int i=cell_min.x; i<=cell_max.x; i++)
	for(int j=cell_min.y; j<=cell_max.y; j++)
	{
		ivec2 range = ContentRange(ivec2(i,j));
		for(int list_index = range[0]; list_index<=range[1]; list_index++)
		{
			int jx = mContent[list_index];
			if(jx != ix) //don't process self (ix)
			{
				Particle pj = particles_in[jx];
				const float eps = 1e-6;
				vec4 u = pj.pos-pi.pos;
				float d = length(u.xy)+eps;
				u = u/d;
				
				pi.acc += 0.3*(expSustainedImpulse(4.0*d, 1.0, 1.0)-0.9)*u;
				//pi.acc += 1.1*quadImpulse(5.0, 4.0*d-0.15)*u;
			}
		}       
	}

	pi.vel += dt*pi.acc;
	pi.pos += dt*pi.vel;

	particles_out[ix] = pi;
}

void AdvectParticleNoGrid(int ix)
{
	const float dt = 0.001;
	Particle pi = particles_in[ix];

	pi.acc *= 0.5;
	for(int jx=0; jx<uNumElements; jx++)
	{
		if(jx==ix) continue; //no self-interactions
		Particle pj = particles_in[jx];
		const float eps = 1e-6;
		vec4 u = pj.pos-pi.pos;
		float d = length(u.xy)+eps;
		u = u/d;
		
		//pi.acc += 1.1*quadImpulse(5.0, 4.0*d-0.15)*u;
		pi.acc += 0.3*(expSustainedImpulse(4.0*d, 1.0, 1.0)-0.9)*u;
		//pi.acc += 100.3*(smoothstep(0.05, 0.1, d)-0.25)*u;
		//pi.acc += 0.5*u*smoothstep(0.05, 0.1, d);
	}
	
	pi.vel += dt*pi.acc;
	pi.pos += dt*pi.vel;

	particles_out[ix] = pi;
}

void AdvectParticleNoGrid2(int ix)
{
	const float dt = 0.001;
	Particle pi = particles_in[ix];

	pi.acc *= 0.5;
	//for(int cx=0; cx<uNumElements; cx++)
	for(int cx=uNumElements-1; cx>=0; cx--)
	{
		int jx = mContent[cx];
		if(jx==ix) continue; //no self-interactions
		Particle pj = particles_in[jx];
		const float eps = 1e-6;
		vec4 u = pj.pos-pi.pos;
		float d = length(u.xy)+eps;
		u = u/d;
		
		//pi.acc += 1.1*quadImpulse(5.0, 4.0*d-0.15)*u;
		pi.acc += 0.3*(expSustainedImpulse(4.0*d, 1.0, 1.0)-0.9)*u;
		//pi.acc += 100.3*(smoothstep(0.05, 0.1, d)-0.25)*u;
		//pi.acc += 0.5*u*smoothstep(0.05, 0.1, d);
	}

	pi.vel += dt*pi.acc;
	pi.pos += dt*pi.vel;

	particles_out[ix] = pi;
}
