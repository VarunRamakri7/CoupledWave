#version 450

layout(local_size_x = 32, local_size_y = 32) in;

layout(rgba32f, binding = 0) readonly restrict uniform image2D uInputImage0; //wave at time t-2
layout(rgba32f, binding = 1) readonly restrict uniform image2D uInputImage1; //wave at time t-1
layout(rgba32f, binding = 2) writeonly restrict uniform image2D uOutputImage; //wave at time t

#include "std_uniforms.h.glsl"
#line 11

const int MODE_INIT = 0;
const int MODE_ITERATE = 1;

layout(location=0) uniform int uMode; 
//wave equation parameters
layout(location = 1) uniform float lambda = 0.01; //alpha*h/k (alpha=const, h=grid spacing, k=time step)
layout(location = 2) uniform float atten = 0.9995; //attenuation
layout(location = 3) uniform float beta = 0.001; //damping

void InitWave(ivec2 coord);
void IterateWave(ivec2 coord, ivec2 size);

struct neighborhood
{
	vec4 c1;
	vec4 c0;
	vec4 n0;
	vec4 s0;
	vec4 e0;
	vec4 w0;
};

neighborhood get_clamp(ivec2 coord);

void main()
{
	ivec2 gid = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(uOutputImage);

	if(any(greaterThanEqual(gid.xy, size))) return;

	switch(uMode)
	{
		case MODE_INIT:
			InitWave(gid);
		break;

		case MODE_ITERATE:
			IterateWave(gid, size);
		break;
	}
}

void InitWave(ivec2 coord)
{
	vec4 vout = vec4(0.0);
	ivec2 size = imageSize(uOutputImage);
	ivec2 cen0 = ivec2(0.25*size);
	ivec2 cen1 = ivec2(0.75*size);

	//float d = min(distance(coord, cen0), distance(coord, cen1));
	float d = distance(coord, cen0);
	vout.x = 0.5*smoothstep(2.0, 0.0, d);
	imageStore(uOutputImage, coord, vout);
}

void boat(inout vec4 w, ivec2 coord)
{
	float r = 0.35;
	float a = SceneUniforms.Time;
	vec2 cen = vec2(0.5);
	vec2 boat_pos = r*vec2(cos(a), sin(a)) + cen;

	float d = -0.1;
	if(distance(vec2(coord), boat_pos) < 1.5)
	{
		w = min(vec4(d), w);
	}
}

void IterateWave(ivec2 coord, ivec2 size)
{
	neighborhood n = get_clamp(coord);
	vec4 w = (2.0-4.0*lambda-beta)*n.c0 + lambda*(n.n0+n.s0+n.e0+n.w0) - (1.0-beta)*n.c1;
	w = atten*w;
	boat(w, coord);
    imageStore(uOutputImage, coord, w);
}

ivec2 clamp_coord(ivec2 coord)
{
   ivec2 size = imageSize(uOutputImage);
   return ivec2(clamp(coord, ivec2(0), size-ivec2(1)));
}

neighborhood get_clamp(ivec2 coord)
{
	neighborhood n;
	n.c1 = imageLoad(uInputImage0, coord);
	n.c0 = imageLoad(uInputImage1, coord);
	n.n0 = imageLoad(uInputImage1, clamp_coord(coord+ivec2(0,+1)));
	n.s0 = imageLoad(uInputImage1, clamp_coord(coord+ivec2(0,-1)));
	n.e0 = imageLoad(uInputImage1, clamp_coord(coord+ivec2(+1,0)));
	n.w0 = imageLoad(uInputImage1, clamp_coord(coord+ivec2(-1,0)));

   return n;
}
