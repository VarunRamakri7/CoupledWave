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

layout(location=10) uniform int SplashFrame = -1000;
layout(location=11) uniform int WaveFrame = -1000;
layout(location=12) uniform int WakeFrame = -1000;

void InitWave(ivec2 coord, ivec2 size);
void IterateWave(ivec2 coord, ivec2 size);
void FakeWave(ivec2 coord, ivec2 size);

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
			InitWave(gid, size);
		break;

		case MODE_ITERATE:
			IterateWave(gid, size);
			//FakeWave(gid, size);
		break;
	}
}

void FakeWave(ivec2 coord, ivec2 size)
{
	vec2 uv = vec2(coord)/vec2(size-ivec2(1));
	vec4 vout;
	//vout = 0.01*vec4(gl_GlobalInvocationID.x);
	//vout = 0.001*vec4(gl_LocalInvocationIndex);
	vout = vec4(0.2*sin(15.0*uv.x + 2.0*SceneUniforms.Time));
	//vout = vec4(0.2);

	imageStore(uOutputImage, coord, vout);
}

void InitWave(ivec2 coord, ivec2 size)
{
	vec4 vout = vec4(0.0);
	imageStore(uOutputImage, coord, vout);
}

void add_event(inout vec4 w, ivec2 coord)
{
	ivec2 size = imageSize(uOutputImage);
	vec2 p = 2.0*vec2(coord)/vec2(size-ivec2(1))-vec2(1.0);
    float d = 0.0;
	float t = float(SceneUniforms.Frame)/60.0;

	//add splash
    float t_splash = float(SceneUniforms.Frame-SplashFrame)/60.0;
	float r = length(p.xy);
	float splash_time_pulse = smoothstep(0.0, 0.1, t_splash)-smoothstep(0.1, 0.2, t_splash);
	float splash = smoothstep(0.2, 0.15, r);
    d += -0.0005*splash*splash_time_pulse;
    
	//add wave
    float t_wave = float(SceneUniforms.Frame-WaveFrame)/60.0;
	float wave_time_pulse = smoothstep(0.1, 0.5, t_wave)-smoothstep(7.5, 8.0, t_wave);
	float wave = 0.1*smoothstep(0.55, 0.95, p.x+0.3*t_wave);
	d += 0.0005*wave*wave_time_pulse;

	//add wake
	float t_wake = float(SceneUniforms.Frame-WakeFrame)/60.0;
	vec2 wake_cen = vec2(0.5*t_wake-1.0, 0.0);
	float r_wake = length(p.xy-wake_cen.xy);
	float wake = smoothstep(0.1, 0.05, r_wake);
    d += -0.0003*wake;

    w += vec4(d);
	
}

void add_boat(inout vec4 w, ivec2 coord)
{
	//*
	vec2 p = vec2(coord)/vec2(imageSize(uOutputImage));
	float r = 0.35;
	float speed = 1.4;
	float a = speed*SceneUniforms.Time;
	vec2 cen = vec2(0.5);
	vec2 boat_pos = r*vec2(cos(a), sin(a)) + cen;

	float d = -0.01;
	if(distance(p, boat_pos) < 0.002)
	{
		w = min(vec4(d), w);
	}
	//*/

	/*
	vec2 p = vec2(coord)/vec2(imageSize(uOutputImage));
	float r = 1.5;
	float speed = 0.4;
	float a = speed*SceneUniforms.Time;
	vec2 cen = vec2(0.5, 0.0);
	vec2 boat_pos = r*vec2(cos(a), 0.0) + cen;

	float d = -0.02;
	if(distance(p, boat_pos) < 0.005)
	{
		w = min(vec4(d), w);
	}
	*/
}

void IterateWave(ivec2 coord, ivec2 size)
{
	neighborhood n = get_clamp(coord);
	vec4 w = (2.0-4.0*lambda-beta)*n.c0 + lambda*(n.n0+n.s0+n.e0+n.w0) - (1.0-beta)*n.c1;
	w = atten*w;
	//add_boat(w, coord);
	add_event(w, coord);
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
