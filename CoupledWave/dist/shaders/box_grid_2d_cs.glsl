#version 450
#include "aabb_cs.h.glsl"
#include "hash_cs.h.glsl"
#line 5

layout(local_size_x = 1024) in;

const int kGridUboBinding = 0;
const int kBoxesInBinding = 0;
const int kBoxesOutBinding = 1;
const int kCountBinding = 2;
const int kStartBinding = 3;
const int kContentBinding = 4;

layout (std430, binding = kBoxesInBinding) restrict readonly buffer PARTICLES_IN 
{
	aabb2D boxes_in[];
};

layout (std430, binding = kBoxesOutBinding) restrict writeonly buffer PARTICLES_OUT 
{
	aabb2D boxes_out[];
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

void InitBox(int ix);
void SeparateBoxes(int ix);
void SeparateBoxesNoGrid(int ix);

void main()
{
	int gid = int(gl_GlobalInvocationID.x);
	if(gid >= uNumElements) return;

	switch(uMode)
	{
		case MODE_INIT:
			InitBox(gid);
		break;

		case MODE_SEPARATE:
			SeparateBoxes(gid);
		break;

		case MODE_SEPARATE_NO_GRID:
			SeparateBoxesNoGrid(gid);
		break;
	}
}



void InitBox(int ix)
{
	aabb2D box;
	vec3 rand = 2.0*uhash3(uvec3(ix, 2*ix, 3*ix))-vec3(1.0);
	box.mMin = rand.xy;
	vec2 w = mCellSize;
	box.mMax = box.mMin + w;
	boxes_out[ix] = box;
}

void SeparateA(inout aabb2D a, in aabb2D b)
{
	vec2 unpen1 = 0.5*(b.mMax-a.mMin);
	if(abs(unpen1.x) < abs(unpen1.y)) unpen1.y=0.0;
	else unpen1.x = 0.0;

	vec2 unpen2 = 0.5*(b.mMin-a.mMax);
	if(abs(unpen2.x) < abs(unpen2.y)) unpen2.y=0.0;
	else unpen2.x = 0.0;

	vec2 unpen = unpen1;
	if(dot(unpen2, unpen2)<dot(unpen1, unpen1))
	{
		unpen = unpen2;
	}
	a.mMin += unpen;
	a.mMax += unpen;
}


void SeparateBoxes(int ix)
{
	aabb2D bi = boxes_in[ix];

	//collide with extents
	vec2 extent_overlap = max(vec2(0.0), mExtents.mMin-bi.mMin);
	bi.mMin += extent_overlap;
	bi.mMax += extent_overlap;
	extent_overlap = min(vec2(0.0), mExtents.mMax-bi.mMax);
	bi.mMin += extent_overlap;
	bi.mMax += extent_overlap;
		
	//These are the cells the query overlaps
	ivec2 cell_min = CellCoord(bi.mMin);
	ivec2 cell_max = CellCoord(bi.mMax);

	for(int i=cell_min.x; i<=cell_max.x; i++)
	for(int j=cell_min.y; j<=cell_max.y; j++)
	{
		ivec2 range = ContentRange(ivec2(i,j));
		for(int list_index = range[0]; list_index<=range[1]; list_index++)
		{
			int jx = mContent[list_index];
			if(jx != ix) //don't process self (ix)
			{
				aabb2D bj = boxes_in[jx];
				ivec2 home = max(cell_min, CellCoord(bj.mMin));
				if(home == ivec2(i,j) && overlap(bi, bj))
				{
					SeparateA(bi, bj);
				}
			}
		}       
	}

	boxes_out[ix] = bi;
}

void SeparateBoxesNoGrid(int ix)
{
	aabb2D bi = boxes_in[ix];

	//collide with extents
	vec2 extent_overlap = max(vec2(0.0), mExtents.mMin-bi.mMin);
	bi.mMin += extent_overlap;
	bi.mMax += extent_overlap;
	extent_overlap = min(vec2(0.0), mExtents.mMax-bi.mMax);
	bi.mMin += extent_overlap;
	bi.mMax += extent_overlap;
	
	for(int jx=0; jx<uNumElements; jx++)
	{
		if(jx != ix) //don't process self (ix)
		{
			aabb2D bj = boxes_in[jx];
			if(overlap(bi, bj)==true)
			{
				SeparateA(bi, bj);
			}
		}
	}

	boxes_out[ix] = bi;
}
