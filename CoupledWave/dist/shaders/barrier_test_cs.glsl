#version 450

layout(local_size_x = 1024) in;

layout (std430, binding = 0) coherent restrict buffer BUFFER
{
	int data[];
};

layout(location = 0) uniform int uMode = 1; 
layout(location = 1) uniform int uNumElements=0;

//When working correctly this shader should set all the of the image and buffer values to 1.0.

void test0_no_barrier();
void test0_with_barrier();
void test1_no_barrier();
void test1_with_barrier();

void main()
{
	switch(uMode)
	{
		case 0:
			test0_no_barrier();
		break;

		case 1:
			test0_with_barrier();
		break;

		case 2:
			test1_no_barrier();
		break;

		case 3:
			test1_with_barrier();
		break;
	}
}

void test0_no_barrier()
{
	uint gid = gl_GlobalInvocationID.x;
	if(gid >= uNumElements) return;

	if(gid >= uNumElements/2)
	{
		data[gid] = uNumElements;
	}
	else
	{
		data[gid] = data[gid+uNumElements/2];
	}
}

void test0_with_barrier()
{
	uint gid = gl_GlobalInvocationID.x;
	if(gid >= uNumElements) return;

	if(gid >= uNumElements/2)
	{
		data[gid] = uNumElements;
		barrier();
	}
	else
	{
		barrier();
		data[gid] = data[gid+uNumElements/2];
	}
}

void test1_no_barrier()
{
	uint gid = gl_GlobalInvocationID.x;
	if(gid >= uNumElements) return;

	data[gid] = int(gid);
	data[gid] = data[(gid+512)%uNumElements];
}

void test1_with_barrier()
{
	uint gid = gl_GlobalInvocationID.x;
	if(gid >= uNumElements) return;

	data[gid] = int(gid);
	barrier();
	int temp = data[(gid+512)%uNumElements];
	barrier();
	data[gid] = temp;
	//barrier(); //would be needed for later reads from data
}