#version 450
#include "hash_cs.h.glsl"
#include "aabb_cs.h.glsl"
#include "std_uniforms.h.glsl"
#line 6

#ifndef LOCAL_SIZE
#define LOCAL_SIZE 1024
#endif
layout(local_size_x = LOCAL_SIZE) in;

layout(binding=0) uniform sampler2D Wave;

struct XpbdParticle
{
   vec4 xpos;	//xpos.w == radius
   vec4 xprev;	//xprev.w == w (1.0/mass);
   vec4 vel;
};

float GetRadius(XpbdParticle p) {return p.xpos.w;}
void SetRadius(inout XpbdParticle p, float r) {p.xpos.w = r;}
float GetW(XpbdParticle p) {return p.xprev.w;}
void SetW(inout XpbdParticle p, float w) {p.xprev.w = w;}

uniform float r_min = 0.005;
const float r_max = r_min;
uniform float density = 1000.0; //all particles have the same density
uniform float c = 0.9995; //velocity damping
uniform float dt = 0.0001; //timestep
uniform float omega = 0.5;
uniform vec3 g = vec3(0.0, -10.0, 0.0); //gravity
uniform float alpha = 0.00000001; //compliance value for distance constraints
uniform bool apply_dist_constraints = false;
uniform float wave_scale = 1.0;
const ivec2 grid_size = ivec2(64,64);

const int kGridUboBinding = 0;

const int kPointsInBinding = 0;
const int kPointsOutBinding = 1;
const int kCountBinding = 2;
const int kStartBinding = 3;
const int kContentBinding = 4;

const float eps = 1e-6;

const vec4 wall[5] = vec4[](vec4(+1.0, 0.0, 0.0, -1.0),
							vec4(-1.0, 0.0, 0.0, -1.0),
							vec4(0.0, 0.0, +1.0, -1.0),
							vec4(0.0, 0.0, -1.0, -1.0),
							vec4(0.0, +1.0, 0.0, -2.0));


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


#include "grid_3d_cs.h.glsl"
#line 79

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

vec3 WavePos(int ix)
{
	ix = ix%(grid_size.x*grid_size.y);
	int rows = grid_size.x;
	int i = ix/rows;
	int j = ix%rows;

	vec3 pos = vec3(0.0);
	pos.x = 2.0*float(i)/(rows-1)-1.0;
	pos.z = 2.0*float(j)/(rows-1)-1.0;
	pos.xz *= 0.95;
	
	vec2 uv = 0.5*pos.xz+vec2(0.5);
	pos.y = wave_scale*texture(Wave, uv).x - 0.5;

	return pos;
}

void InitParticle(int ix)
{
	XpbdParticle p;
	
	vec3 pos = WavePos(ix);

	int layer = ix/(grid_size.x*grid_size.y);
	if(layer == 0)
	{
		SetW(p, 0.0);
	}
	else
	{
		SetW(p, 1.0);
		vec3 rand = uhash3(uvec3(ix, uNumElements, 0));
		pos += 0.1*rand;
	}
	
	p.xpos.xyz = pos;
	p.xprev.xyz = pos;
	p.vel = vec4(0.0);
	SetRadius(p, r_min);

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

	//wave constraint
	
	if(ix/(grid_size.x*grid_size.y)==0)
	{
		vec3 pos = WavePos(ix);
		pi.xpos.xyz = pos;
		pi.xprev.xyz = pos;
	}

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

	//wave constraint

	if(ix/(grid_size.x*grid_size.y)==0)
	{
		vec3 pos = WavePos(ix)-vec3(0.0, 0.01, 0.0);
		pi.xpos.xyz = pos;
		pi.xprev.xyz = pos;
	}

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
	for(int i=0; i<5; i++)
	{
		dx += WallCollision(pi, wall[i]);
	}

	vec3 box_hw = vec3(2.0*ri);
	aabb3D query_aabb = aabb3D(vec4(pi.xpos.xyz-box_hw, 0.0), vec4(pi.xpos.xyz+box_hw, 0.0));
	//These are the cells the query overlaps
	ivec3 cell_min = CellCoord(query_aabb.mMin.xyz);
	ivec3 cell_max = CellCoord(query_aabb.mMax.xyz);

	//Collision constraints
	for(int i=cell_min.x; i<=cell_max.x; i++)
	{
		for(int j=cell_min.y; j<=cell_max.y; j++)
		{
			for(int k=cell_min.z; k<=cell_max.z; k++)
			{
				int cell = Index(ivec3(i,j,k));
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
						//dx += omega*h*uij;
					}
				}
			}
		}
	}

	

	
	vec2 uv = 0.5*pi.xpos.xz+vec2(0.5);
	float h = wave_scale*texture(Wave, uv).x - 0.5;
	
	//other constraints
	//if(apply_dist_constraints==true)
	{
		int ngrid = grid_size.x*grid_size.y;
		int layer = ix/ngrid;

		if(layer==1)
		{
			XpbdParticle pj0 = particles_in[ix-ngrid]; //layer 0 particle
			dx += DistConstraint(pi, pj0);

			XpbdParticle pj2 = particles_in[ix+ngrid]; //layer 2 particle
			dx += DistConstraint(pi, pj2);

			if(pi.xpos.y < h)
			{
				dx += omega*vec3(0.0, h - pi.xpos.y, 0.0);
			}
		}
		if(layer==2)
		{
			XpbdParticle pj1 = particles_in[ix-ngrid]; //layer 1 particle
			dx += DistConstraint(pi, pj1);

			if(pi.xpos.y < h)
			{
				dx += omega*vec3(0.0, h - pi.xpos.y, 0.0);
			}
		}
	}

	pi.xpos.xyz += dx;

	//mouse constraint
	//if(ix==0) pi.xpos.xy = vec2(1.0, -1.0)*(2.0*SceneUniforms.MousePos.xy/vec2(SceneUniforms.Viewport.zw)-vec2(1.0));

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
	float l0 = 0.5*(GetRadius(pi)+GetRadius(pj));
	float l = distance(pi.xpos.xyz, pj.xpos.xyz);
	float C = l-l0;
	vec3 gradCi = (pi.xpos.xyz-pj.xpos.xyz)/l;
	vec3 gradCj = -gradCi;
	float wi = GetW(pi);
	float wj = GetW(pj);
	float lambda = -C/(wi*dot(gradCi, gradCi) + wj*dot(gradCj, gradCj) + alpha/dt/dt);

	return omega*lambda*wi*gradCi;
}
