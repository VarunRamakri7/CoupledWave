#version 450
#include "hash_cs.h.glsl"
#line 4

layout(local_size_x = 1024) in;


layout (std430, binding = 0) restrict buffer DATA 
{
	uint values[];
};

layout (std430, binding = 1) restrict buffer SORTED 
{
	int sorted;
};

layout(location = 0) uniform int uMode=0; 
layout(location = 1) uniform int uNumElements=0;

const int MODE_EVEN = 0;
const int MODE_ODD = 1;

bool comp(uint a, uint b)
{
	return a<b;
}


void main()
{
	int gid = int(gl_GlobalInvocationID.x);

	int ix0 = 2*gid+uMode;	// uMode == ODD: 1, 3, 5, ...
	int ix1 = ix0+1;		// uMode == ODD: 2, 4, 6, ...

	if(ix1 >= uNumElements) return;

	uint v0 = values[ix0];
	uint v1 = values[ix1];

	if(comp(v0, v1)==false)
	{
		//swap
		values[ix0] = v1;
		values[ix1] = v0;
		sorted = 0;
	}
}


/*
// M x work
void main()
{
	uint gid = gl_GlobalInvocationID.x;

	const int M = 1;
	for(int i=0; i<M; i++)
	{
		uint ix0 = 2*(M*gid+i)+uMode;	// uMode == ODD: 1, 3, 5, ...
		uint ix1 = ix0+1;				// uMode == ODD: 2, 4, 6, ...

		if(ix1 >= uNumElements) return;

		uint v0 = values[ix0];
		uint v1 = values[ix1];

		if(comp(v0, v1)==false)
		{
			//swap
			values[ix0] = v1;
			values[ix1] = v0;
			sorted = 0;
		}
	}
}
*/