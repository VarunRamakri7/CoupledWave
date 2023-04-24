#version 450

layout(local_size_x = 1024) in;

struct Particle
{
   vec4 pos;
   vec4 vel;
   vec4 acc;
};

layout (std430, binding = 0) restrict readonly buffer PARTICLES_IN 
{
	Particle particles_in[];
};

layout (std430, binding = 1) restrict writeonly buffer PARTICLES_OUT 
{
	Particle particles_out[];
};

layout(location = 0) uniform int uMode=0; 
layout(location = 1) uniform int uNumElements=0;

uniform vec4 grav = vec4(0.1);

const int MODE_INIT = 0;
const int MODE_ADVECT = 1;

void InitParticle(int ix);
void AdvectParticle(int ix);

void main()
{
	int gid = int(gl_GlobalInvocationID.x);
	if(gid >= uNumElements) return;

	switch(uMode)
	{
		case MODE_INIT:
			InitParticle(gid);
		break;

		case MODE_ADVECT:
			AdvectParticle(gid);
		break;
	}
}

void InitParticle(int ix)
{
	particles_out[ix].pos = vec4(sin(12345.0*ix), cos(67890.0*ix), 0.0, 1.0);	
	particles_out[ix].vel = vec4(0.0);
	particles_out[ix].acc = vec4(0.0);
}

float quadImpulse( float k, float x )
{
    return 2.0*sqrt(k)*x/(1.0+k*x*x);
}

float expSustainedImpulse( float x, float f, float k )
{
    float s = max(x-f,0.0);
    return min( x*x/(f*f), 1.0+(2.0/f)*s*exp(-k*s));
}

void AdvectParticle(int ix)
{
	const float dt = 0.001;
	Particle pi = particles_in[ix];
	
	for(int jx=0; jx<uNumElements; jx++)
	{
		if(jx==ix) continue; //no self-interactions
		Particle pj = particles_in[jx];
		const float eps = 1e-6;
		vec4 u = pj.pos-pi.pos;
		float d = length(u.xy)+eps;
		u = u/d;
		pi.acc *= 0.99;
		//pi.acc += 50.1*quadImpulse(5.0, 4.0*d-0.15)*u;
		pi.acc += 0.3*(expSustainedImpulse(4.0*d, 1.0, 1.0)-0.9)*u;
		//pi.acc += 100.3*(smoothstep(0.05, 0.1, d)-0.25)*u;
		//pi.acc += 0.5*u*smoothstep(0.05, 0.1, d);
	}
	
	pi.vel += dt*pi.acc;
	pi.pos += dt*pi.vel;

	particles_out[ix] = pi;
}

