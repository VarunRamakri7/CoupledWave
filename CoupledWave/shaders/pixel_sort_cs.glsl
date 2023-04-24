#version 450 core
#include "std_uniforms.h.glsl"
#line 4
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

layout (location=0) uniform int h = 0;
layout (location=1) uniform int algorithm = 0;
layout (location=2) uniform ivec2 image_size = ivec2(0);

// Workgroup local memory. We use this to minimise round-trips to global memory.
// It allows us to evaluate a sorting network of up to 1024 with one shader invocation.
shared uint local_value[gl_WorkGroupSize.x * 2];

bool is_less(in int ax, in int bx, in const uint A, in const uint B)
{
	float t = SceneUniforms.Time;
	//if(ax>= image_size.x*image_size.y) return false;
	//if(bx>= image_size.x*image_size.y) return false;

	//return ax>bx; //sorted by index
	//return A > B; //sorted by uint value

	vec4 va = unpackUnorm4x8(A); //extract 8-bit rgba from packed 32-bit value
	vec4 vb = unpackUnorm4x8(B);
	const vec4 L = vec4(0.3, 0.59, 0.11, 0.0);
	float luma = dot(va, L);
	float lumb = dot(vb, L);

	//float thresh = 0.5;
	//float split1 = image_size.x/2;
	//float split2 = image_size.x/3;
	//if(ax<split1 && bx>split1) return false;
	//if(ax>split1 && bx<split1) return false;

	//if(ax/50 != bx/50) return false;

	//Whole image sort 
	ivec2 acoord = ivec2(ax/image_size.x, ax%image_size.x);
	ivec2 bcoord = ivec2(bx/image_size.x, bx%image_size.x);
	//if(acoord.x%50 != bcoord.x%50) return false;

	//if(acoord.y != bcoord.y) return false;
	return luma>lumb;
	//int wa = int(50*sin(0.01*acoord.x));
	//int wb = int(50*sin(0.01*bcoord.x));
	//if(acoord.y/wa != bcoord.y/wb) return false;

	int offset = int(t);
	//if(acoord.y/100 != bcoord.y/100) return false;
	//if(acoord.y<200 || bcoord.y<200) return false;

	//return luma>lumb;

	//find start and end
	/*
	int start = -1;
	int end = image_size.x;
	float thresh = 0.5;
	
	for(int i=0; i<image_size.x; i++)
	{
		vec4 vi = unpackUnorm4x8(value[i]); //extract 8-bit rgba from packed 32-bit value
		float lumi = dot(vi, L);
		if(start < 0 && lumi<thresh)
		{
			start = i;
		}
		if(start >= 0 && lumi>thresh)
		{
			end = i;
			break;
		}
	}
	
	if(ax>=start && ax<=end && bx>=start && bx<=end)
	{
		return luma>lumb;
	}
	*/
	return false;
}

// Pick comparison funtion
#define COMPARE is_less

void global_compare_and_swap(ivec2 idx)
{
	if (COMPARE(idx.x, idx.y, value[idx.x], value[idx.y])) 
	{
		uint tmp = value[idx.x];
		value[idx.x] = value[idx.y];
		value[idx.y] = tmp;
	}
}

void local_compare_and_swap(ivec2 idx)
{
	int offset = int(gl_WorkGroupSize.x * 2 * gl_WorkGroupID.x); //offset from local to global indices
	if (COMPARE(offset+idx.x, offset+idx.y, local_value[idx.x], local_value[idx.y])) 
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