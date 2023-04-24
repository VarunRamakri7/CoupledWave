#version 450
#include "std_uniforms.h.glsl"
#line 4
layout(local_size_x = 10, local_size_y = 10, local_size_z = 10) in;

const int STATIC_MODE = 0;
const int ANIMATE_MODE = 1;

layout(rgba32f, binding = 0) restrict uniform image3D uImage; 
uniform int uMode = STATIC_MODE;

void main()
{
	ivec3 gid = ivec3(gl_GlobalInvocationID.xyz);
	ivec3 size = imageSize(uImage);

	if(any(greaterThanEqual(gid, size))) return;

	vec3 cen = 0.5*vec3(size);
	float a = 1.0f;
	if(uMode==ANIMATE_MODE)
	{
		a = 0.5*cos(0.5*SceneUniforms.Time)+0.5;
	}
	float r = 0.45*size.x*a;
	float f = 0.0;
	if(distance(gid, cen) < r)
	{
		f = 1.0;
	}
	imageStore(uImage, gid, vec4(f));	
}
