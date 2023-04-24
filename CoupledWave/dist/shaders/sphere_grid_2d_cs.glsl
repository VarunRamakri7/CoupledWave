#version 450
#include "aabb_cs.h.glsl"
#include "hash_cs.h.glsl"
#line 5

layout(local_size_x = 1024) in;

const int kGridUboBinding = 0;
const int kSpheresInBinding = 0;
const int kSpheresOutBinding = 1;
const int kCountBinding = 2;
const int kStartBinding = 3;
const int kContentBinding = 4;

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

#include "grid_2d_cs.h.glsl"
#line 41

layout(location = 0) uniform int uMode=0; 
layout(location = 1) uniform int uNumElements=0;

const int MODE_INIT = 0;
const int MODE_SEPARATE = 1;
const int MODE_SEPARATE_NO_GRID = 2;

void InitSphere(int ix);
void SeparateSpheres(int ix);
void SeparateSpheresNoGrid(int ix);

void main()
{
	int gid = int(gl_GlobalInvocationID.x);
	if(gid >= uNumElements) return;

	switch(uMode)
	{
		case MODE_INIT:
			InitSphere(gid);
		break;

		case MODE_SEPARATE:
			SeparateSpheres(gid);
		break;

		case MODE_SEPARATE_NO_GRID:
			SeparateSpheresNoGrid(gid);
		break;
	}
}

void InitSphere(int ix)
{
	vec3 rand = 2.0*uhash3(uvec3(ix, 2*ix, 3*ix))-vec3(1.0);
	float r = 0.05;
	spheres_out[ix] = vec4(rand.xy, 0.0, r);
}

void SeparateA(inout vec4 a, in vec4 b)
{
	vec2 v = a.xy-b.xy;
	float d = length(v)+1e-6;
	vec2 u = v/d;
	float overlap = a.w + b.w - d;
	if(overlap > 0.0)
	{
		a.xy += 0.5*overlap*u;
	}
}


void SeparateSpheres(int ix)
{
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
					SeparateA(sphi, sphj);
				}
			}
		}       
	}
	
	spheres_out[ix] = sphi;
}

void SeparateSpheresNoGrid(int ix)
{
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
			SeparateA(sphi, sphj);
		}
	}
	spheres_out[ix] = sphi;
}
