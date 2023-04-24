#version 450

layout(local_size_x = 32, local_size_y = 32) in;

//NB: format of uInputImage is rgba8
layout(rgba8, binding = 0) restrict readonly uniform image2D uInputImage; 
layout(binding = 1) restrict writeonly uniform image2D uOutputImage;

const int TRANSPOSE_MODE_MASK = 1;

layout(location=0) uniform int uMode = TRANSPOSE_MODE_MASK;

void main()
{
	ivec2 in_coord = ivec2(gl_GlobalInvocationID.xy);
	ivec2 in_size = imageSize(uInputImage);
	ivec2 out_size = imageSize(uOutputImage);

	if(any(greaterThanEqual(in_coord, in_size))) return;

	vec4 v = imageLoad(uInputImage, in_coord);
	ivec2 out_coord = in_coord;

	if((uMode & TRANSPOSE_MODE_MASK) > 0) out_coord.xy = in_coord.yx;

	if(any(greaterThanEqual(out_coord, out_size))) return;
	
	imageStore(uOutputImage, out_coord, v);
}