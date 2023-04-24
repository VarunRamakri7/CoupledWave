#version 450

layout(local_size_x = 10, local_size_y = 10, local_size_z = 10) in;

const int MODE_MIN = 0;
const int MODE_MAX = 1;
const int MODE_AVG = 2;
layout(location=0) uniform int uMode = MODE_MIN; 

layout(rgba32f, binding = 0) readonly uniform image3D input_image;
layout(rgba32f, binding = 1) writeonly uniform image3D output_image;


void main()
{
	ivec3 gid = ivec3(gl_GlobalInvocationID.xyz);
	ivec3 in_size = imageSize(input_image);
	ivec3 out_size = imageSize(output_image);
	ivec3 max_coord = in_size-ivec3(1);

	if(any(greaterThanEqual(gid, out_size))) return;

	vec4 v[2][2][2];
	for(int i=0; i<2; i++)
	for(int j=0; j<2; j++)
	for(int k=0; k<2; k++)
	{
		ivec3 in_coord = clamp(2*gid+ivec3(i,j,k), ivec3(0), max_coord);
		v[i][j][k] = imageLoad(input_image, in_coord);
	}

	vec4 vout;
	if(uMode == MODE_MAX)
	{
		vout = max(max(max(v[0][0][0], v[1][0][0]), max(v[0][1][0], v[1][1][0])), max(max(v[0][0][1], v[1][0][1]), max(v[0][1][1], v[1][1][1])));
	}
	else if(uMode == MODE_MIN)
	{
		vout = min(min(min(v[0][0][0], v[1][0][0]), min(v[0][1][0], v[1][1][0])), min(min(v[0][0][1], v[1][0][1]), min(v[0][1][1], v[1][1][1])));
	}
	else if(uMode == MODE_AVG)
	{
		vout = vec4(0.0);
		for(int i=0; i<2; i++)
		for(int j=0; j<2; j++)
		for(int k=0; k<2; k++)
		{
			vout += v[i][j][k];
		}
		vout *= 0.125;
	}

	ivec3 out_coord = clamp(gid, ivec3(0), out_size-ivec3(1));
	imageStore(output_image, out_coord, vout);
}

