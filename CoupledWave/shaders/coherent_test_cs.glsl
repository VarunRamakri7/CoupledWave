#version 450
#pragma optimize(off)
layout(local_size_x = 1024) in;

//#define COHERENT

#ifdef COHERENT
	layout(r32f, binding = 0) uniform coherent restrict image2D test_image; 
	layout (std430, binding = 0) coherent restrict buffer COHERENT_BUFFER
	{
		float data[];
	};
#else
	layout(r32f, binding = 0) uniform restrict image2D test_image; 
	layout (std430, binding = 0) restrict buffer INCOHERENT_BUFFER
	{
		float data[];
	};
#endif

layout(location = 0) uniform int uMode = 1; 

//When working correctly this shader should set all the of the image and buffer values to 1.0.

void coherence_test_main();

void main()
{
	coherence_test_main();
}

void set_right(int split, float v);
void copy_right_to_left(int split);

//This function works with COHERENT, but otherwise does not
void coherence_test_main()
{
	uint gid = gl_GlobalInvocationID.x;
	ivec2 size = imageSize(test_image);
	
	int split = size.x/2;
	
	if(gid == size.x-1) //Right side: these invocations set the values on the right side of the split
	{
		set_right(split, 1.0);
		memoryBarrierBuffer();
		memoryBarrierImage();
		barrier();
	}
	if(gid==1) //Left side: This single invocation copies from right to left to fill the L1 cache for its SM.
				//Note that it copies before the barrier();
	{
		copy_right_to_left(split);
		memoryBarrierBuffer();
		memoryBarrierImage();
		barrier();
	}
	if(gid==0) //Left side: This single invocation shares an L1 cache with gid==1, so when the buffer is not COHERENT	
				// it can read stale values from the cache.
	{
		barrier();
		copy_right_to_left(split);
	}
}

//Set all elements to right of split to v
void set_right(int split, float v)
{
	for(int i=split; i<imageSize(test_image).x; i++)
	{
		data[i] = v;
		imageStore(test_image, ivec2(i, 0), vec4(v));
	}		
}

//Copy right side of split to left side
void copy_right_to_left(int split)
{
	for(int i=0; i<split; i++)
	{
		//Read from right side, write to left side
		data[i] = data[i+split];
		vec4 im = imageLoad(test_image, ivec2(i+split, 0));
		imageStore(test_image, ivec2(i, 0), im);
	}	
}


