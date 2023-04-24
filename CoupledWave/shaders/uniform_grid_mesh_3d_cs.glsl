#version 450
#include "aabb_cs.h.glsl"

#define _DEBUG
#include "debug_cs.h.glsl"
#line 7

layout(local_size_x = 1024) in;

const int kGridUboBinding = 0;
const int kIndicesInBinding = 0;
const int kVerticesInBinding = 1;
const int kCountBinding = 2;
const int kStartBinding = 3;
const int kContentBinding = 4;


layout (std430, binding = kIndicesInBinding) restrict readonly buffer INDICES 
{
	uint indices[];
};

layout (std430, binding = kVerticesInBinding) restrict readonly buffer VERTICES 
{
	float verts[];
};

//Modes
const int COMPUTE_COUNT = 0;
const int COMPUTE_START = 1;
const int INSERT_TRIANGLES = 2;

layout(location=0) uniform int uMode = COMPUTE_COUNT;
layout(location=1) uniform int uNumElements = 0;
layout(location=2) uniform mat4 uM = mat4(1.0);

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

#include "grid_3d_cs.h.glsl"
#line 53

void ComputeCount(int gid);
void InsertTriangle(int gid);

uvec3 read_triangle_indices(uint ix)
{
	return uvec3(indices[3*ix+0], indices[3*ix+1], indices[3*ix+2]);
}

vec3 read_vertex(uint ix)
{
	vec3 v = vec3(verts[3*ix+0], verts[3*ix+1], verts[3*ix+2]);
	vec4 v_w = uM*vec4(v, 1.0);
	return v_w.xyz;
}

aabb3D get_triangle_aabb(int ix)
{
	uvec3 indices = read_triangle_indices(ix);
	vec3 v0 = read_vertex(indices[0]);
	vec3 v1 = read_vertex(indices[1]);
	vec3 v2 = read_vertex(indices[2]);

	aabb3D box;
	box.mMin.xyz = min(v0, min(v1, v2));
	box.mMax.xyz = max(v0, max(v1, v2));
	return box;
}

void main()
{
	int gid = int(gl_GlobalInvocationID.x);
	if(gid >= uNumElements) return;

	if(uMode==COMPUTE_COUNT)
	{
		ComputeCount(gid);	
	}
	else if(uMode==INSERT_TRIANGLES)
	{
		InsertTriangle(gid);
	}
}

void ComputeCount(int gid)
{
	aabb3D tri_aabb = get_triangle_aabb(gid);
	ivec3 cell_min = CellCoord(tri_aabb.mMin.xyz);
	ivec3 cell_max = CellCoord(tri_aabb.mMax.xyz);

	ivec3 cell;
	for(cell.x=cell_min.x; cell.x<=cell_max.x; cell.x++)
	{
		for(cell.y=cell_min.y; cell.y<=cell_max.y; cell.y++)
		{
			for(cell.z=cell_min.z; cell.z<=cell_max.z; cell.z++)
			{
				int ix = Index(cell);
				atomicAdd(mCount[ix], 1);
			}
		}
	}
}

void InsertTriangle(int gid)
{
	aabb3D tri_aabb = get_triangle_aabb(gid);
	ivec3 cell_min = CellCoord(tri_aabb.mMin.xyz);
	ivec3 cell_max = CellCoord(tri_aabb.mMax.xyz);

	ivec3 cell;
	for(cell.x=cell_min.x; cell.x<=cell_max.x; cell.x++)
	{
		for(cell.y=cell_min.y; cell.y<=cell_max.y; cell.y++)
		{
			for(cell.z=cell_min.z; cell.z<=cell_max.z; cell.z++)
			{
				int ix = Index(cell);
				int start = mStart[ix];
				int count = atomicAdd(mCount[ix], 1);
				mContent[start+count] = gid;
			}
		}
	}

	#ifdef _DEBUG
		int n_cells = (cell_max.x-cell_min.x+1)*(cell_max.x-cell_min.x+1);
		if(n_cells > mMaxCellsPerElement) SetError(1); //Possible mContent overflow
	#endif
}


/*
//Sample collision query function
void CollisionQuery(int ix, aabb3D query_aabb)
{
	//These are the cells the query overlaps
	ivec3 cell_min = CellCoord(query_aabb.mMin.xyz);
	ivec3 cell_max = CellCoord(query_aabb.mMax.xyz);

	for(int i=cell_min.x; i<=cell_max.x; i++)
	for(int j=cell_min.y; j<=cell_max.y; j++)
	for(int k=cell_min.z; k<=cell_max.z; k++)
	{
		ivec2 range = ContentRange(ivec2(i,j));
		for(int list_index = range[0]; list_index<=range[1]; list_index++)
		{
			int jx = mContent[list_index];
			if(jx != ix) //don't process self (ix)
			{
				//i,j collision detection and reaction
			}
		}       
	}
}
*/