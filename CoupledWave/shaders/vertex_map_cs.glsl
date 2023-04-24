#version 450

#include "std_uniforms.h.glsl"
#line 5

layout(local_size_x = 1024) in;

layout (std430, binding = 0) restrict buffer VERTICES 
{
	float verts[];
};

layout (std430, binding = 1) restrict buffer NORMALS 
{
	float normals[];
};

layout(location = 0) uniform int uMode=0; 
layout(location = 1) uniform int uNumElements=0;

vec3 read_vertex(int ix)
{
	return vec3(verts[3*ix+0], verts[3*ix+1], verts[3*ix+2]);
}

void write_vertex(int ix, vec3 v)
{
	verts[3*ix+0] = v.x;
	verts[3*ix+1] = v.y;
	verts[3*ix+2] = v.z;
}

vec3 read_normal(int ix)
{
	return vec3(normals[3*ix+0], normals[3*ix+1], normals[3*ix+2]);
}

void write_normal(int ix, vec3 n)
{
	normals[3*ix+0] = n.x;
	normals[3*ix+1] = n.y;
	normals[3*ix+2] = n.z;
}

void main()
{
	int gid = int(gl_GlobalInvocationID.x);
	if(gid >= uNumElements) return;

	vec3 v = read_vertex(gid);
	vec3 n = read_normal(gid);
	v.z += 0.05*cos(SceneUniforms.Time + 10.0*v.x)*SceneUniforms.DeltaTime;
	write_vertex(gid, v);
}



