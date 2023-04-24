#version 450

//This program checks the order of invocation by having each thread increment an atomic
// counter, and stores the counter value in a buffer.

layout(local_size_x = 1024) in;

layout (binding = 0) uniform atomic_uint counter;

layout (std430, binding = 1) restrict buffer ORDER_BUFFER
{
	uint invocation_order[];
};

layout(binding = 0) restrict writeonly uniform image2D invocation_image; 

void main()
{
	uint gid = gl_GlobalInvocationID.x;
	uint c = atomicCounterIncrement(counter);
	invocation_order[gid] = c;
	
	ivec2 size = imageSize(invocation_image);
	ivec2 coord = ivec2(gid, 0);
	vec4 color = vec4(float(c)/float(size.x));
	imageStore(invocation_image, coord, color);
}