#version 450

layout(local_size_x = 32, local_size_y = 32) in;

layout(rgba8, binding = 0) restrict readonly uniform image2D uInputImage; 
layout(rgba8, binding = 1) restrict writeonly uniform image2D uOutputImage;

layout(location=0) uniform int uMode = 1;
layout(location=1) uniform ivec2 uShift = ivec2(0);

const int BLUR_MODE_MASK = 1;
const int SHIFT_MODE_MASK = 2;
const int FLIP_X_MODE_MASK = 4;
const int FLIP_Y_MODE_MASK = 8;
const int FLIP_XY_MODE_MASK = 16;

vec4 blur(ivec2 coord);

void main()
{
	//Assumption: images are the same size
	ivec2 gid = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(uInputImage);

	if(any(greaterThanEqual(gid, size))) return;

	vec4 v = imageLoad(uInputImage, gid);
	ivec2 out_coord = gid;

	if((uMode & BLUR_MODE_MASK) > 0) v = blur(gid);
	if((uMode & SHIFT_MODE_MASK) > 0) out_coord = (out_coord+uShift) % size;
	if((uMode & FLIP_X_MODE_MASK) > 0) out_coord.x = size.x-1-out_coord.x;
	if((uMode & FLIP_Y_MODE_MASK) > 0) out_coord.y = size.y-1-out_coord.y;
	if((uMode & FLIP_XY_MODE_MASK) > 0) out_coord = size-ivec2(1)-out_coord;

	imageStore(uOutputImage, out_coord, v);
}

vec4 blur(ivec2 coord)
{
	vec4 v = vec4(0.0);
	ivec2 offset;
	const int hw = 1;
	for(offset.x=-hw; offset.x<=+hw; offset.x++)
	for(offset.y=-hw; offset.y<=+hw; offset.y++)
	{
		v += imageLoad(uInputImage, coord+offset);
	}
	v /= float((2*hw+1)*(2*hw+1));
	return v;
}