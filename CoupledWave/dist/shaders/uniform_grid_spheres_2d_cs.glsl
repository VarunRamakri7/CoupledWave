#version 450
#include "aabb_cs.h.glsl"

#define _DEBUG
#include "debug_cs.h.glsl"
#line 7

layout(local_size_x = 1024) in;

const int kGridUboBinding = 0;
const int kSpheresInBinding = 0;
const int kSpheresOutBinding = 1;
const int kCountBinding = 2;
const int kStartBinding = 3;
const int kContentBinding = 4;


layout (std430, binding = kSpheresInBinding) readonly restrict buffer IN 
{
	vec4 mSpheres[]; //center = .xyz, radius = .w
};

//Modes
const int COMPUTE_COUNT = 0;
const int COMPUTE_START = 1;
const int INSERT_SPHERES = 2;

layout(location=0) uniform int uMode = COMPUTE_COUNT;
layout(location=1) uniform int uNumElements = 0;

layout (std430, binding = kCountBinding) restrict buffer COUNTER 
{
	int mCount[];
};

layout (std430, binding = kStartBinding) restrict buffer START 
{
	int mStart[];
};

layout (std430, binding = kContentBinding) restrict buffer CONTENT
{
	int mContent[];
};

#include "grid_2d_cs.h.glsl"
#line 45

void ComputeCount(int gid);
void InsertSphere(int gid);

void main()
{
	int gid = int(gl_GlobalInvocationID.x);
	if(gid >= uNumElements) return;

	if(uMode==COMPUTE_COUNT)
	{
		ComputeCount(gid);	
	}
	else if(uMode==INSERT_SPHERES)
	{
		InsertSphere(gid);
	}
}

void ComputeCount(int gid)
{
	vec4 sph = mSpheres[gid];
	vec2 hw = vec2(mSpheres[gid].w);
	ivec2 cell_min = CellCoord(sph.xy-hw);
	ivec2 cell_max = CellCoord(sph.xy+hw);

	ivec2 cell;
	for(cell.x=cell_min.x; cell.x<=cell_max.x; cell.x++)
	{
		for(cell.y=cell_min.y; cell.y<=cell_max.y; cell.y++)
		{
			int ix = Index(cell);
			atomicAdd(mCount[ix], 1);
		}
	}
}

void InsertSphere(int gid)
{
	vec4 sph = mSpheres[gid];
	vec2 hw = vec2(mSpheres[gid].w);
	ivec2 cell_min = CellCoord(sph.xy-hw);
	ivec2 cell_max = CellCoord(sph.xy+hw);

	ivec2 cell;
	for(cell.x=cell_min.x; cell.x<=cell_max.x; cell.x++)
	{
		for(cell.y=cell_min.y; cell.y<=cell_max.y; cell.y++)
		{
			int ix = Index(cell);
			int offset = mStart[ix];
			int count = atomicAdd(mCount[ix], 1);
			mContent[offset+count] = gid;
		}
	}

	#ifdef _DEBUG
		int n_cells = (cell_max.x-cell_min.x+1)*(cell_max.x-cell_min.x+1);
		if(n_cells > mMaxCellsPerElement) SetError(1); //Possible mContent overflow
	#endif
}


/*
//Sample collision query function
void CollisionQuery(int ix, vec2 box_hw)
{
	aabb2D query_aabb = mBoxes[ix];
	//These are the cells the query overlaps
	ivec2 cell_min = CellCoord(query_aabb.mMin);
	ivec2 cell_max = CellCoord(query_aabb.mMax);

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
				if(jx != ix) //don't process self (ix)
			    {
					aabb2D box_j = mBoxes[jx];
					ivec2 home = max(cell_min, ComputeCellIndex(box_j.mMin));
					if(home == ivec2(i,j) && overlap(query_aabb, box))
					{
					   Collide(gid, box_index, query_aabb, box);
					}
				}
			}       
		}
	}
}
*/