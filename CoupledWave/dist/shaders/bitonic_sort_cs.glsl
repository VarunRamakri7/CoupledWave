#version 450 core

// This shader implements a sorting network for 1024 elements.
//
// It is follows the alternative notation for bitonic sorting networks, as given at:
// https://en.m.wikipedia.org/wiki/Bitonic_sorter#Alternative_representation

//#extension GL_ARB_separate_shader_objects : enable
//#extension GL_ARB_shading_language_420pack : enable

// Note that there exist hardware limits - look these up for your GPU via https://vulkan.gpuinfo.org/
// sizeof(local_value[]) : Must be <= maxComputeSharedMemorySize
// local_size_x          : Must be <= maxComputeWorkGroupInvocations


// ENUM for uniform::Parameters.algorithm:
#define eLocalBitonicMergeSortExample      0
#define eLocalDisperse 1
#define eBigFlip       2
#define eBigDisperse   3

layout(local_size_x = 1024) in; // Set value for local_size_x via specialization constant with id 1

layout (binding = 0) buffer SortData 
{
	// This is our unsorted input buffer - tightly packed, 
	// an array of N_GLOBAL_ELEMENTS elements.
	uint value[];
};

// Note: These parameters are currently unused.
/*
layout (std140, binding=0) uniform Parameters 
{
	uint h;
	uint algorithm;
} parameters;
*/

layout (location=0) uniform int h = 0;
layout (location=1) uniform int algorithm = 0;

// Workgroup local memory. We use this to minimise round-trips to global memory.
// It allows us to evaluate a sorting network of up to 1024 with one shader invocation.
shared uint local_value[gl_WorkGroupSize.x * 2];


// naive comparison
bool is_greater(in const uint left, in const uint right)
{
	return left < right;
}

bool is_less(in const uint left, in const uint right)
{
	return left > right;
}

// Pick comparison funtion
#define COMPARE is_less

void global_compare_and_swap(ivec2 idx)
{
	if (COMPARE(value[idx.x], value[idx.y])) 
	{
		uint tmp = value[idx.x];
		value[idx.x] = value[idx.y];
		value[idx.y] = tmp;
	}
}

void local_compare_and_swap(ivec2 idx)
{
	if (COMPARE(local_value[idx.x], local_value[idx.y])) 
	{
		uint tmp = local_value[idx.x];
		local_value[idx.x] = local_value[idx.y];
		local_value[idx.y] = tmp;
	}
}

// Performs full-height flip (h height) over globally available indices.
void big_flip( in uint h) 
{

	uint t_prime = gl_GlobalInvocationID.x;
	uint half_h = h >> 1; // Note: h >> 1 is equivalent to h / 2 

	uint q       = ((2 * t_prime) / h) * h;
	uint x       = q     + (t_prime % half_h);
	uint y       = q + h - (t_prime % half_h) - 1; 


	global_compare_and_swap(ivec2(x,y));
}

// Performs full-height disperse (h height) over globally available indices.
void big_disperse( in uint h ) 
{

	uint t_prime = gl_GlobalInvocationID.x;

	uint half_h = h >> 1; // Note: h >> 1 is equivalent to h / 2 

	uint q       = ((2 * t_prime) / h) * h;
	uint x       = q + (t_prime % (half_h));
	uint y       = q + (t_prime % (half_h)) + half_h;

	global_compare_and_swap(ivec2(x,y));

}

// Performs full-height flip (h height) over locally available indices.
void local_flip(in uint h)
{
		uint t = gl_LocalInvocationID.x;
		barrier();

		uint half_h = h >> 1; // Note: h >> 1 is equivalent to h / 2 
		ivec2 indices = 
			ivec2( h * ( ( 2 * t ) / h ) ) +
			ivec2( t % half_h, h - 1 - ( t % half_h ) );

		local_compare_and_swap(indices);
}

// Performs progressively diminishing disperse operations (starting with height h)
// on locally available indices: e.g. h==8 -> 8 : 4 : 2.
// One disperse operation for every time we can divide h by 2.
void local_disperse(in uint h)
{
	uint t = gl_LocalInvocationID.x;
	for ( ; h > 1 ; h /= 2 ) 
	{
		
		barrier();

		uint half_h = h >> 1; // Note: h >> 1 is equivalent to h / 2 
		ivec2 indices = 
			ivec2( h * ( ( 2 * t ) / h ) ) +
			ivec2( t % half_h, half_h + ( t % half_h ) );

		local_compare_and_swap(indices);
	}
}

void local_bitonic_merge_sort_example(uint h)
{
	uint t = gl_LocalInvocationID.x;
	for ( uint hh = 2; hh <= h; hh <<= 1 ) 
	{  // note:  h <<= 1 is same as h *= 2
		local_flip( hh);
		local_disperse( hh/2 );
	}
}

void main()
{
	uint t = gl_LocalInvocationID.x;

	uint offset = gl_WorkGroupSize.x * 2 * gl_WorkGroupID.x; // we can use offset if we have more than one invocation.

	if (algorithm <= eLocalDisperse)
	{
		// In case this shader executes a `local_` algorithm, we must 
		// first populate the workgroup's local memory.
		//
		local_value[t*2]   = value[offset+t*2];
		local_value[t*2+1] = value[offset+t*2+1];
	}

	switch (algorithm)
	{
		case eLocalBitonicMergeSortExample:
			local_bitonic_merge_sort_example(h);
		break;
		case eLocalDisperse:
			local_disperse(h);
		break;
		case eBigFlip:
			big_flip(h);
		break;
		case eBigDisperse:
			big_disperse(h);
		break;
	}


	// Write local memory back to buffer in case we pulled in the first place.

	if (algorithm <= eLocalDisperse)
	{
		barrier();
		// push to global memory
		value[offset+t*2]   = local_value[t*2];
		value[offset+t*2+1] = local_value[t*2+1];
	}
}