#version 450
#include "hash_cs.h.glsl"
#include "aabb_cs.h.glsl"
#include "std_uniforms.h.glsl"
#line 6

#ifndef LOCAL_SIZE
#define LOCAL_SIZE 1024
#endif
layout(local_size_x = LOCAL_SIZE) in;

struct XpbdParticle
{
   vec4 xpos;
   vec4 xprev;
   vec4 vel;
};

float GetRadius(XpbdParticle p) {return p.xpos.w;}
void SetRadius(inout XpbdParticle p, float r) {p.xpos.w = r;}

uniform float r_min = 0.02;
const float r_max = r_min;
uniform float density = 1000.0; //all particles have the same density
uniform float c = 0.9995; //velocity damping
uniform float dt = 0.0005; //timestep
uniform float omega = 0.5;
uniform vec3 g = vec3(0.0, -10.0, 0.0); //gravity
uniform float alpha = 0.000001; //compliance value for distance constraints
uniform bool apply_dist_constraints = false;

const int kGridUboBinding = 0;

const int kPointsInBinding = 0;
const int kPointsOutBinding = 1;
const int kCountBinding = 2;
const int kStartBinding = 3;
const int kContentBinding = 4;

const float eps = 1e-6;

const vec4 wall[4] = vec4[](vec4(+1.0, 0.0, 0.0, -1.0),
							vec4(-1.0, 0.0, 0.0, -1.0),
							vec4(0.0, +1.0, 0.0, -1.0),
							vec4(0.0, -1.0, 0.0, -1.0));


layout (std430, binding = kPointsInBinding) restrict readonly buffer PARTICLES_IN 
{
	XpbdParticle particles_in[];
};

layout (std430, binding = kPointsOutBinding) restrict writeonly buffer PARTICLES_OUT 
{
	XpbdParticle particles_out[];
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
#line 70

layout(location = 0) uniform int uMode=0; 
layout(location = 1) uniform int uNumElements=0;

const int MODE_INIT = 0;
const int MODE_UPDATE_X = 1;
const int MODE_CONSTRAINT = 2;
const int MODE_UPDATE_V = 3;
const int MODE_UPDATE_V_AND_X = 4;
const int MODE_CONSTRAINT_GRID = 5;

void InitParticle(int ix);
void UpdateX(int ix);
void SolveConstraints(int ix);
void UpdateV(int ix);

void UpdateVandX(int ix);
void SolveConstraintsGrid(int ix);

vec3 DistConstraint(in XpbdParticle pi, in XpbdParticle pj);
vec3 WallCollision(in XpbdParticle pi, vec4 plane);

float GetMass(XpbdParticle p)
{
	float a = 3.1415*p.xpos.w*p.xpos.w;
	return density*a;
}


void main()
{
	int gid = int(gl_GlobalInvocationID.x);
	
	switch(uMode)
	{
		case MODE_INIT:
			if(gid >= uNumElements) return;
			InitParticle(gid);
		break;

		case MODE_UPDATE_X:
			UpdateX(gid);
		break;

		case MODE_CONSTRAINT:
			SolveConstraints(gid);
		break;

		case MODE_UPDATE_V:
			UpdateV(gid);
		break;

		case MODE_UPDATE_V_AND_X:
			UpdateVandX(gid);
		break;

		case MODE_CONSTRAINT_GRID:
			SolveConstraintsGrid(gid);
		break;
	}
}

void InitParticle(int ix)
{
	XpbdParticle p;
	//vec3 rand = 2.0*uhash3(uvec3(ix/3, uNumElements, 0))-vec3(1.0);
	//rand += 0.1*uhash3(uvec3(ix, uNumElements, 0));

	vec3 rand = uhash3(uvec3(ix/3, uNumElements, 0));
	vec3 pos = 2.0*rand-vec3(1.0);
	rand = uhash3(uvec3(ix, uNumElements, 0));
	pos += 0.2*rand;

	p.xpos.xyz = vec3(pos.xy, 0.0);
	p.vel = vec4(0.0);

	
	float r = r_min + rand.z*(r_max-r_min);
	SetRadius(p, r);
	p.xprev = p.xpos;

	particles_out[ix] = p;
}

void UpdateX(int ix)
{
	if(ix >= uNumElements) return;
	XpbdParticle pi = particles_in[ix];

	//Apply gravity and other external forces
	pi.vel.xyz += g*dt;
	pi.xprev = pi.xpos;
	pi.xpos.xyz += pi.vel.xyz*dt;

	particles_out[ix] = pi;
}

void UpdateV(int ix)
{
	if(ix >= uNumElements) return;
	XpbdParticle pi = particles_in[ix];

	pi.vel.xyz = c*(pi.xpos.xyz-pi.xprev.xyz)/dt;

	particles_out[ix] = pi;
}

void UpdateVandX(int ix)
{
	if(ix >= uNumElements) return;
	XpbdParticle pi = particles_in[ix];

	pi.vel.xyz = c*(pi.xpos.xyz-pi.xprev.xyz)/dt; //update V

	//Apply gravity and other external forces
	pi.vel.xyz += g*dt;
	pi.xprev = pi.xpos;
	pi.xpos.xyz += pi.vel.xyz*dt;

	particles_out[ix] = pi;
}


void SolveConstraints(int ix)
{
	if(ix >= uNumElements) return;
	XpbdParticle pi = particles_in[ix];
	float ri = GetRadius(pi);

	vec3 dx = vec3(0.0);

	//Environment constraints
	for(int i=0; i<4; i++)
	{
		dx += WallCollision(pi, wall[i]);
	}
	
	//Collision constraints
	for(int jx=0; jx<uNumElements; jx++)
	{
		if(jx==ix) continue; //no self-interactions
		XpbdParticle pj = particles_in[jx];
		float rj = GetRadius(pj);

		vec3 nij = pi.xpos.xyz - pj.xpos.xyz;
		float d = length(nij)+eps;
		vec3 uij = nij/d;

		if(d < ri + rj)
		{
			//separate
			float h = 0.5f*(ri+rj-d);
			dx += omega*h*uij;
		}
	}

	if(apply_dist_constraints==true)
	{
		int jx0, jx1;
		if(ix%3==0) {jx0 = ix+1; jx1 = ix+2;}
		if(ix%3==1) {jx0 = ix-1; jx1 = ix+1;}
		if(ix%3==2) {jx0 = ix-1; jx1 = ix-2;}

		XpbdParticle pj0 = particles_in[jx0];
		dx += DistConstraint(pi, pj0);
		XpbdParticle pj1 = particles_in[jx1];
		dx += DistConstraint(pi, pj1);
	}

	pi.xpos.xyz += dx;
	particles_out[ix] = pi;
}

void SolveConstraintsGrid(int ix)
{
	if(ix >= uNumElements) return;
	XpbdParticle pi = particles_in[ix];
	float ri = GetRadius(pi);

	vec3 dx = vec3(0.0);

	//Environment constraints
	for(int i=0; i<4; i++)
	{
		dx += WallCollision(pi, wall[i]);
	}

	float box_hw = 2.0*ri;
	aabb2D query_aabb = aabb2D(pi.xpos.xy-box_hw, pi.xpos.xy+box_hw);
	//These are the cells the query overlaps
	ivec2 cell_min = CellCoord(query_aabb.mMin);
	ivec2 cell_max = CellCoord(query_aabb.mMax);

	//Collision constraints
	for(int i=cell_min.x; i<=cell_max.x; i++)
	{
		for(int j=cell_min.y; j<=cell_max.y; j++)
		{
			int cell = Index(ivec2(i,j));
			int start = mStart[cell];
			int count = mCount[cell];

			for(int list_index = start; list_index<start+count; list_index++)
			{
				int jx = mContent[list_index];
				if(jx==ix) continue; //no self-interactions
				XpbdParticle pj = particles_in[jx];
				float rj = GetRadius(pj);
				
				vec3 nij = pi.xpos.xyz - pj.xpos.xyz;
				float d = length(nij)+eps;
				vec3 uij = nij/d;

				if(d < ri + rj)
				{
					//separate
					float h = 0.5f*(ri+rj-d);
					dx += omega*h*uij;
				}
			}
		}
	}

	//other constraints
	if(apply_dist_constraints==true)
	{
		int jx0 = ix-1, jx1=ix+1;
		if(ix%3==0) {jx0 = ix+1; jx1 = ix+2;}
		if(ix%3==1) {jx0 = ix-1; jx1 = ix+1;}
		if(ix%3==2) {jx0 = ix-1; jx1 = ix-2;}

		XpbdParticle pj0 = particles_in[jx0];
		dx += DistConstraint(pi, pj0);
		XpbdParticle pj1 = particles_in[jx1];
		dx += DistConstraint(pi, pj1);
	}

	pi.xpos.xyz += dx;

	//mouse constraint
	if(ix==0) pi.xpos.xy = vec2(1.0, -1.0)*(2.0*SceneUniforms.MousePos.xy/vec2(SceneUniforms.Viewport.zw)-vec2(1.0));

	particles_out[ix] = pi;
}


vec3 WallCollision(in XpbdParticle pi, vec4 plane)
{
	float ri = GetRadius(pi);
	float d = dot(pi.xpos.xyz, plane.xyz)-plane.w;
	if(d >= ri) return vec3(0.0);

	//clamp position
	vec3 uij = plane.xyz;
	return omega*(ri-d)*uij;
}

vec3 DistConstraint(in XpbdParticle pi, in XpbdParticle pj)
{
	float l0 = GetRadius(pi)+GetRadius(pj);
	float l = distance(pi.xpos.xyz, pj.xpos.xyz);
	float C = l-l0;
	vec3 gradCi = (pi.xpos.xyz-pj.xpos.xyz)/l;
	vec3 gradCj = -gradCi;
	float wi = 1.0/GetMass(pi);
	float wj = 1.0/GetMass(pj);
	float lambda = -C/(wi*dot(gradCi, gradCi) + wj*dot(gradCj, gradCj) + alpha/dt/dt);

	return omega*lambda*wi*gradCi;
}
