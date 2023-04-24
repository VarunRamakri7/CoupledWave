#version 450

#include "aabb_cs.h.glsl"
#include "hash_cs.h.glsl"
#line 6

layout(local_size_x = 1024) in;

const int kGridUboBinding = 0;
const int kSpheresInBinding = 0;
const int kSpheresOutBinding = 1;
const int kCountBinding = 2;
const int kStartBinding = 3;
const int kContentBinding = 4;

const int kVelocityInBinding = 10;
const int kVelocityOutBinding = 11;

layout (std430, binding = kSpheresInBinding) restrict readonly buffer PARTICLES_IN 
{
	vec4 spheres_in[]; //center = .xyz, radius = .w
};

layout (std430, binding = kSpheresOutBinding) restrict writeonly buffer PARTICLES_OUT 
{
	vec4 spheres_out[]; //center = .xyz, radius = .w
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

layout (std430, binding = kVelocityInBinding) restrict readonly buffer VELOCITY_IN 
{
	vec4 velocity_in[]; 
};

layout (std430, binding = kVelocityOutBinding) restrict writeonly buffer VELOCITY_OUT 
{
	vec4 velocity_out[]; 
};

#include "grid_2d_cs.h.glsl"
#line 56

layout(location = 0) uniform int uMode=0; 
layout(location = 1) uniform int uNumElements=0;

const int MODE_INIT = 0;
const int MODE_ITERATE = 1;
const int MODE_ITERATE_NO_GRID = 2;

void InitSphere(int ix);
void IterateSpheres(int ix);
void IterateSpheresNoGrid(int ix);

void main()
{
	int gid = int(gl_GlobalInvocationID.x);
	if(gid >= uNumElements) return;

	switch(uMode)
	{
		case MODE_INIT:
			InitSphere(gid);
		break;

		case MODE_ITERATE:
			IterateSpheres(gid);
		break;

		case MODE_ITERATE_NO_GRID:
			IterateSpheresNoGrid(gid);
		break;
	}
}

void InitSphere(int ix)
{
	vec3 rand = 2.0*uhash3(uvec3(16*ix, 2*ix, 3*ix))-vec3(1.0);
	float r = 0.005;
	spheres_out[ix] = vec4(rand.xy, 0.0, r);
	velocity_out[ix] = vec4(0.0);
}

const vec2 G = vec2(0.0, -0.2);
const float DT = 0.01;
const float DAMPING = 0.2;
const float E = 0.75;
const float M = 1.0;

const float factor = 0.5;

void CollideA(vec4 a, vec4 va, vec4 b, vec4 vb, inout vec2 disp, inout vec2 f)
{
	vec2 r = a.xy-b.xy;
	float d = length(r)+1e-8;
	vec2 u = r/d;
	float overlap = a.w + b.w - d;
	if(overlap > 0.0)
	{
		disp += 0.5*overlap*u; //unpenetrate

		
		float ma = M;
		float mb = M;
		
		//float vn = min(0.0, dot(u, va.xy-vb.xy));
		//f -= 0.5*(1.0f+E)*vn*u;
	
		//Stable
		float vn = min(0.0, dot(va.xy, u));
		f -= (1.0f+E)*mb/(ma+mb)*vn*u;

		//Stable
		//float vn = min(0.0, dot(va.xy-vb.xy, u));
		//f -= (1.0f+E)*mb/(ma+mb)*vn*u;

		
		//mat2 M0 = mat2(M, E, M, -E);
		//vec2 vn0 = vec2(dot(u, va.xy), dot(u, vb.xy));
		//mat2 M1 = mat2(M, -1.0, M, 1.0);
		//vec2 vn1 = inverse(M1)*M0*vn0;
		//f += max(0.0,(vn1[0]-vn0[0]))*u;
		
	}
}

void IterateSpheres(int ix)
{
	vec4 sphi = spheres_in[ix];
	vec4 vi = velocity_in[ix];

	vi.xy += G*DT;
	sphi.xy += vi.xy*DT;

	vec2 hw = vec2(sphi.w, sphi.w);
	aabb2D bi;
	bi.mMin = sphi.xy-hw;
	bi.mMax = sphi.xy+hw;

	//collide with extents
	float overlap;
	overlap = max(0.0, mExtents.mMin.x-bi.mMin.x);
	if(overlap > 0.0)
	{
		sphi.x += overlap;
		if(vi.x<0.0) vi.x -= (1.0+E)*vi.x;
	}

	overlap = max(0.0, mExtents.mMin.y-bi.mMin.y);
	if(overlap > 0.0)
	{
		sphi.y += overlap;
		if(vi.y<0.0) vi.y -= (1.0+E)*vi.y;
	}

	overlap = min(0.0, mExtents.mMax.x-bi.mMax.x);
	if(overlap < 0.0)
	{
		sphi.x += overlap;
		if(vi.x>0.0) vi.x -= (1.0+E)*vi.x;
	}

	overlap = min(0.0, mExtents.mMax.y-bi.mMax.y);
	if(overlap < 0.0)
	{
		sphi.y += overlap;
		if(vi.y>0.0) vi.y -= (1.0+E)*vi.y;
	}

	vec2 disp = vec2(0.0);
	vec2 f = vec2(0.0);

	//These are the cells the query overlaps
	ivec2 cell_min = CellCoord(bi.mMin);
	ivec2 cell_max = CellCoord(bi.mMax);

	for(int i=cell_min.x; i<=cell_max.x; i++)
	for(int j=cell_min.y; j<=cell_max.y; j++)
	{
		ivec2 cell = ivec2(i,j);
		ivec2 range = ContentRange(cell);
		for(int list_index = range[0]; list_index<=range[1]; list_index++)
		{
			int jx = mContent[list_index];
			if(jx != ix) //don't process self (ix)
			{
				vec4 sphj = spheres_in[jx];
				ivec2 home = max(cell_min, CellCoord(sphj.xy-vec2(sphj.w)));
				if(home == cell)
				{
					vec4 vj = velocity_in[jx];
					CollideA(sphi, vi, sphj, vj, disp, f);
				}
			}
		}       
	}
	sphi.xy += disp;
	vi.xy += f/M;
	spheres_out[ix] = sphi;
	velocity_out[ix] = vi;
}

void IterateSpheresNoGrid(int ix)
{
/*
	vec4 sphi = spheres_in[ix];
	vec2 hw = vec2(sphi.w, sphi.w);
	aabb2D bi;
	bi.mMin = sphi.xy-hw;
	bi.mMax = sphi.xy+hw;

	//collide with extents
	vec2 extent_overlap;
	extent_overlap = max(vec2(0.0), mExtents.mMin-bi.mMin);
	sphi.xy += extent_overlap;
	extent_overlap = min(vec2(0.0), mExtents.mMax-bi.mMax);
	sphi.xy += extent_overlap;
	
	for(int jx=0; jx<uNumElements; jx++)
	{
		if(jx != ix) //don't process self (ix)
		{
			vec4 sphj = spheres_in[jx];
			CollideA(sphi, sphj);
		}
	}
	spheres_out[ix] = sphi;
	*/
}
