#version 450

layout(local_size_x = 32, local_size_y = 32) in;

const int MODE_MIN = 0;
const int MODE_MAX = 1;
const int MODE_AVG = 2;
layout(location=0) uniform int uMode = MODE_MIN; 

layout(rgba32f, binding = 0) readonly uniform image2D input_image;
layout(rgba32f, binding = 1) writeonly uniform image2D output_image;


void main()
{
	ivec2 gid = ivec2(gl_GlobalInvocationID.xy);
	ivec2 in_size = imageSize(input_image);
	ivec2 out_size = imageSize(output_image);

	if(gid.x >= out_size.x) return;
	if(gid.y >= out_size.y) return;

	ivec2 in_coord0 = clamp(2*gid, ivec2(0), in_size-ivec2(1));
	vec4 v0 = imageLoad(input_image, in_coord0);
	
	ivec2 in_coord1 = clamp(2*gid+ivec2(1,0), ivec2(0), in_size-ivec2(1));
	vec4 v1 = imageLoad(input_image, in_coord1);
	
	ivec2 in_coord2 = clamp(2*gid+ivec2(0,1), ivec2(0), in_size-ivec2(1));
	vec4 v2 = imageLoad(input_image, in_coord2);
	
	ivec2 in_coord3 = clamp(2*gid+ivec2(1,1), ivec2(0), in_size-ivec2(1));
	vec4 v3 = imageLoad(input_image, in_coord3);

	vec4 vout;
	if(uMode == MODE_MAX)
	{
		vout = max(max(v0, v1), max(v2, v3));
	}
	else if(uMode == MODE_MIN)
	{
		vout = min(min(v0, v1), min(v2, v3));
	}
	else if(uMode == MODE_AVG)
	{
		vout = 0.25*(v0+v1+v2+v3);
	}

	ivec2 out_coord = clamp(gid, ivec2(0), out_size-ivec2(1));
	imageStore(output_image, out_coord, vout);
}

