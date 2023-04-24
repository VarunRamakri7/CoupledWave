#version 450

#include "std_uniforms.h.glsl"
#line 5

layout(local_size_x = 1024) in;

layout (std430, binding = 0) restrict readonly buffer VERTICES_N
{
	float verts_in[];
};

layout (std430, binding = 1) restrict writeonly buffer VERTICES_OUT 
{
	float verts_out[];
};

layout (std430, binding = 2) restrict readonly buffer ONE_RING_RANGE
{
	uvec2 one_ring_range[];
};

layout (std430, binding = 3) restrict readonly buffer ONE_RING
{
	uint one_ring[];
};


layout(location = 0) uniform int uMode=0; 
layout(location = 1) uniform int uNumElements=0;

vec3 read_vertex(int ix)
{
	return vec3(verts_in[3*ix+0], verts_in[3*ix+1], verts_in[3*ix+2]);
}

void write_vertex(int ix, vec3 v)
{
	verts_out[3*ix+0] = v.x;
	verts_out[3*ix+1] = v.y;
	verts_out[3*ix+2] = v.z;
}

//smooth mesh by moving vertex toward the average one ring position.
void main()
{
	int gid = int(gl_GlobalInvocationID.x);
	if(gid >= uNumElements) return;

	vec3 v = read_vertex(gid);

	if(uMode==0) //pass-through
	{
		write_vertex(gid, v);
		return;
	}

	uvec2 range = one_ring_range[gid];
	uint n = range[1]-range[0]+1;
	if(n>0)
	{
		vec3 one_ring_avg = vec3(0.0);
		for(uint i=range[0]; i<=range[1]; i++)
		{
			uint ix = one_ring[i];
			one_ring_avg += read_vertex(int(ix));
		}
		one_ring_avg /= float(n);
		v = mix(v, one_ring_avg, 0.01);
	}

	write_vertex(gid, v);
}



