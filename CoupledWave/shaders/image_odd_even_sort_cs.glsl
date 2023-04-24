#version 450
#include "hash_cs.h.glsl"
#include "std_uniforms.h.glsl"
#line 5

layout(local_size_x = 32, local_size_y = 32) in;


layout(rgba8, binding = 0) restrict uniform image2D uImage; 

layout (std430, binding = 1) restrict buffer SORTED 
{
	int sorted;
};

layout(location = 0) uniform int uMode=0; 

const int MODE_EVEN = 0;
const int MODE_ODD = 1;

bool comp(vec4 a, vec4 b)
{
	const vec4 L = vec4(0.3, 0.59, 0.11, 0.0);
	float luma = dot(a, L);
	float lumb = dot(b, L);
	return luma<lumb;
}


void main()
{
	ivec2 size = imageSize(uImage);
	ivec2 gid = ivec2(gl_GlobalInvocationID.xy);

	//Horizontal fixed
	//ivec2 ix0 = ivec2(2,1)*gid+ivec2(uMode,0);	// uMode == ODD: 1, 3, 5, ...
	//ivec2 ix1 = ix0+ivec2(1, 0);					// uMode == ODD: 2, 4, 6, ...

	//diag fixed
	//ivec2 ix0 = ivec2(1,2)*gid+ivec2(uMode,uMode);	
	//ivec2 ix1 = ix0+ivec2(1, 1);	
	
	//General axis
	//ivec2 ix0 = (ivec2(1,1)+abs(dir))*gid + uMode*dir;	// uMode == ODD: 1, 3, 5, ...
	//ivec2 ix1 = ix0 + dir;					// uMode == ODD: 2, 4, 6, ...

	//ivec2 dir = ivec2(1,-1);
	//General diag
	//ivec2 ix0 = ivec2(1,2)*gid + uMode*dir;	// uMode == ODD: 1, 3, 5, ...
	//ivec2 ix1 = ix0 + dir;				// uMode == ODD: 2, 4, 6, ...

	//ivec2 dir = ivec2(1, round(sin(0.003*gid.x-t)));
	//ivec2 dir = ivec2(1, round(sin(0.05*gid.x)));

	ivec2 dir = ivec2(0,1);
	float t = SceneUniforms.Time;
	
	ivec2 ix0;
	if(dot(abs(dir), ivec2(1))==1)
	{
		ix0 = (ivec2(1,1)+abs(dir))*gid + uMode*dir;
	}
	else
	{
		ix0 = ivec2(1,2)*gid + uMode*dir;
	}
	ivec2 ix1 = ix0 + dir;

	if(any(greaterThanEqual(ix1, size))) return;
	if(any(greaterThanEqual(ix0, size))) return;
	if(any(lessThan(ix1, ivec2(0)))) return;
	if(any(lessThan(ix0, ivec2(0)))) return;

	vec4 v0 = imageLoad(uImage, ix0);
	vec4 v1 = imageLoad(uImage, ix1);

	if(comp(v0, v1)==false)
	{
		//swap
		imageStore(uImage, ix0, v1);
		imageStore(uImage, ix1, v0);
		sorted = 0;
	}
}



