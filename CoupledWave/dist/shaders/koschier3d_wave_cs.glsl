#version 450
#include "hash_cs.h.glsl"
#include "aabb_cs.h.glsl"
#include "std_uniforms.h.glsl"
#line 6

layout(local_size_x = 1024) in;

layout(binding=0) uniform sampler2D Wave;
layout(binding=1) uniform sampler2D Wave0;

struct Particle
{
   vec4 pos;
   vec4 vel;    //.xyz = vel,   .w = pressure (p)
   vec4 acc;    //.xyz = force, .w = density (rho)
};

float get_rho(Particle p)
{
    return p.acc.w;
}

void set_rho(inout Particle p, float rho)
{
    p.acc.w = rho;
}

float get_pressure(Particle p)
{
    return p.vel.w;
}

void set_pressure(inout Particle p, float press)
{
    p.vel.w = press;
}

layout (std430, binding = 0) readonly restrict buffer IN 
{
	Particle particles_in[];
};

layout (std430, binding = 1) writeonly restrict buffer OUT 
{
	Particle particles_out[];
};

const int kGridUboBinding = 0;

const int kCountBinding = 2;
const int kStartBinding = 3;
const int kContentBinding = 4;

layout (std430, binding = kCountBinding) restrict readonly buffer GRID_COUNTER 
{
	int mCount[];
};

layout (std430, binding = kStartBinding) restrict readonly buffer GRID_START 
{
	int mStart[];
};

layout (std430, binding = kContentBinding) restrict readonly buffer CONTENT_LIST 
{
	int mContent[];
};

#include "grid_3d_cs.h.glsl"
#line 72

const vec3 G = vec3(0.0, -9.8, 0.0);   // external (gravitational) forces m/s^2
const float M_PI = 3.14159265;

#define BIG_PARTICLES

#ifdef BIG_PARTICLES
    //For 3D (big particles)
    const float PARTICLE_RADIUS = 0.02;
    const float PARTICLE_DIAM = 2.0*PARTICLE_RADIUS;
    const float H = 4.0*PARTICLE_RADIUS;//SUPPORT_RADIUS
    const float HSQ = H * H;
    const float REST_DENS = 1000.0;
    const float VISC = 0.02;
    const float MASS = 0.05*PARTICLE_DIAM*PARTICLE_DIAM*REST_DENS;
    const float DT = 0.003;
    const float GAS_CONST = 5500.0;

    const float k2 = 40.0/(7.0*M_PI*HSQ);
    const float k3 = 8.0/(M_PI*H*H*H);
    const float kdim = k3; //for 3D
    uniform float PSI = 5.0*REST_DENS;

#else

//For 3D (small particles)
    const float PARTICLE_RADIUS = 0.01;
    const float PARTICLE_DIAM = 2.0*PARTICLE_RADIUS;
    const float H = 4.0*PARTICLE_RADIUS;//SUPPORT_RADIUS
    const float HSQ = H * H;
    const float REST_DENS = 1000.0;
    const float VISC = 0.005;
    const float MASS = 0.03*PARTICLE_DIAM*PARTICLE_DIAM*REST_DENS;
    const float DT = 0.002;
    const float GAS_CONST = 1500.0;

    const float k2 = 40.0/(7.0*M_PI*HSQ);
    const float k3 = 8.0/(M_PI*H*H*H);
    const float kdim = k3; //for 3D
    uniform float PSI = 5.0*REST_DENS;
#endif

layout(location=20) uniform float wave_scale = 1.0;
layout(location=21) uniform vec2 wave_shift = vec2(0.0);

float wave_height(vec3 pos)
{
    pos.xz += wave_shift;
    pos.xz *= wave_scale;
    vec2 uv = 0.5*pos.xz+vec2(0.5);
    float h = texture(Wave, uv).x;
    return h-0.5;
}

float wave_height0(vec3 pos)
{
    pos.xz += wave_shift;
    pos.xz *= wave_scale;
    vec2 uv = 0.5*pos.xz+vec2(0.5);
    float h = texture(Wave0, uv).x;
    return h-0.5;
}

vec3 wave_normal(vec3 pos)
{
    pos.xz += wave_shift;
    pos.xz *= wave_scale;
    vec2 uv = 0.5*pos.xz+vec2(0.5);
    vec3 duv = vec3(1.0/textureSize(Wave, 0), 0.0);
    float dx = texture(Wave, uv+duv.xz).x - texture(Wave, uv-duv.xz).x;
    float dy = texture(Wave, uv+duv.yz).x - texture(Wave, uv-duv.yz).x;
    vec3 n = normalize(vec3(dx, 0.1, dy));
    return n;
}

float W_cubic(float r)
{
    float q = r/H;
    if(q>=1.0) return 0.0;
    if(q<=0.5)
    {
        return kdim*(6.0*q*q*(q-1.0)+1.0);
    }
    else
    {
        float q1 = 1.0-q;
        return kdim*2.0*q1*q1*q1;
    }
}

float W_cubic_grad(float r)
{
    
    float q = r/H;
    if(q>=1.0) return 0.0;
    if(q<=0.5)
    {
        return 6.0*kdim*q*(3.0*q-2.0)/H;
    }
    else
    {
        float q1 = 1.0-q;
        return -6.0*kdim*(q1*q1)/H;
    }
}

float W_cubic_lap(float r)
{
    float q = r/H;
    if(q>=1.0) return 0.0;
    if(q<=0.5)
    {
        return kdim*6.0*(6.0*q-2.0)/HSQ;
    }
    else
    {
        return kdim*12.0*(1.0-q)/HSQ;
    }
}

layout(location = 0) uniform int uMode=0; 
layout(location = 1) uniform int uNumElements=0;

const int MODE_INIT = 0;
const int MODE_COMPUTE_DENSITY_PRESSURE = 1;
const int MODE_COMPUTE_FORCES = 2;
const int MODE_COMPUTE_INTEGRATE = 3;

void InitParticle(int ix);
void ComputeDensityPressure(int ix);
void ComputeForces(int ix);

float CompressibleStateEqn(float rho)
{
    return GAS_CONST * (rho/REST_DENS - 1.0);
}

float WeaklyCompressibleStateEqn(float rho)
{
    float gamma = 3.0;
    return GAS_CONST * (pow(rho/REST_DENS, gamma) - 1.0);
}

void main()
{
	int gid = int(gl_GlobalInvocationID.x);
	if(gid >= uNumElements) return;

	switch(uMode)
	{
		case MODE_INIT:
			InitParticle(gid);
		break;

		case MODE_COMPUTE_DENSITY_PRESSURE:
			ComputeDensityPressure(gid);
		break;

        case MODE_COMPUTE_FORCES:
			ComputeForces(gid);
		break;
	}
}

void wrap_particle(inout Particle pi);
void wall_collision_acc(inout Particle pi, vec4 plane);
void wave_collision_acc(inout Particle pi, float offset);

vec4 init_grid(int ix);
bool wave_boundary = true;

void InitParticle(int ix)
{
    vec4 p = init_grid(ix);
   
    particles_out[ix].pos = vec4(0.5*p.xyz+vec3(0.0, 0.5, 0.0), PARTICLE_RADIUS);
	particles_out[ix].vel = vec4(0.0);
    particles_out[ix].acc = vec4(0.0, 0.0, 0.0, REST_DENS);
}

vec4 init_grid(int ix)
{
    vec3 rand = uhash3(uvec3(ix, uNumElements, 0));
    vec3 pos = 2.0*rand-vec3(1.0);
	return vec4(pos, 1.0);
}

//wall collisions
const vec4 wall[6] = vec4[](vec4(+1.0, 0.0, 0.0, -1.0),
							vec4(-1.0, 0.0, 0.0, -1.0),
							vec4(0.0, +1.0, 0.0, -1.0),
							vec4(0.0, -1.0, 0.0, -1.0),
                            vec4(0.0, 0.0, +1.0, -1.0),
							vec4(0.0, 0.0, -1.0, -1.0));

float sdPlane( vec3 p, vec4 plane )
{
  // n must be normalized
  return dot(p, plane.xyz) + plane.w;
}

float rho_boundary(vec3 p, vec4 plane)
{
    float rho = 0.0;
    float d = sdPlane(p, plane);
    if(d<H)
    {
        vec3 near = p - d*plane.xyz;
        vec3 t = cross(plane.yzx, plane.xyz);
        vec3 b = cross(t, plane.xyz);
        int nb = 5;
        for(int i=0; i<nb; i++)
        {
            float dx = (i-nb/2)*PARTICLE_DIAM;
            for(int j=0; j<nb; j++)
            {
                float dy = (j-nb/2)*PARTICLE_DIAM;
                vec3 b_pos = near + dx*t + dy*b;
                rho += 1.0*W_cubic(distance(p, b_pos));
            }
        }
    }
    return rho;
}

float rho_wave(vec3 p)
{
    float rho = 0.0;
    float h = wave_height(p);
    float d = p.y-h;
    const vec3 t = vec3(1.0, 0.0, 0.0);
    const vec3 b = vec3(0.0, 0.0, 1.0);
    //vec3 n = wave_normal(p);
    //vec3 t = cross(n.yzx, n.xyz);
    //vec3 b = cross(t, n.xyz);

    if(d<H)
    {
        int nb = 5;
        for(int i=0; i<nb; i++)
        {
            float dx = (i-nb/2)*PARTICLE_DIAM;
            for(int j=0; j<nb; j++)
            {
                float dy = (j-nb/2)*PARTICLE_DIAM;
                vec3 b_pos = p + dx*t + dy*b;
                b_pos.y = wave_height(b_pos);
                rho += 1.0*W_cubic(distance(p, b_pos));
            }
        }
    }
    return rho;
}

void ComputeDensityPressure(int ix)
{
	Particle pi = particles_in[ix];

	float rho = 0.0;
    const float c_rho = MASS;

    aabb3D query_aabb = aabb3D(vec4(pi.pos.xyz-vec3(H), 0.0), vec4(pi.pos.xyz+vec3(H), 0.0));
    //These are the cells the query overlaps
    ivec3 cell_min = CellCoord(query_aabb.mMin.xyz);
	ivec3 cell_max = CellCoord(query_aabb.mMax.xyz);
    
    for(int i=cell_min.x; i<=cell_max.x; i++)
    {
	    for(int j=cell_min.y; j<=cell_max.y; j++)
	    {
            for(int k=cell_min.z; k<=cell_max.z; k++)
	        {
		        int cell = Index(ivec3(i,j,k));
			    int start = mStart[cell];
			    int count = mCount[cell];

		        for(int list_index = start; list_index<start+count; list_index++)
		        {
			        int jx = mContent[list_index];
                    Particle pj = particles_in[jx];
                    vec3 rij = pi.pos.xyz - pj.pos.xyz;
        
                    float r2 = dot(rij,rij);
                    if (r2 < HSQ)
                    {
                        rho += W_cubic(sqrt(r2));
                    }
		        }       
            }
	    }
    }

    //boundary
    if(wave_boundary)
    {
        for(int i=0; i<6; i++)
        {
            //rho += rho_boundary(pi.pos.xyz, wall[i]);
        }
        rho += rho_wave(pi.pos.xyz);
    }
    
    rho = c_rho * rho;
    rho = max(REST_DENS, rho); // clamp density
    set_rho(pi, rho);

    //float press_i = CompressibleStateEqn(rho);
    float press_i = WeaklyCompressibleStateEqn(rho);
    set_pressure(pi, press_i);

	particles_out[ix] = pi;
}

void force_boundary(vec3 p, vec4 plane, float acc_press_i, inout vec3 acc_press, inout vec3 acc_visc)
{
    float d = sdPlane(p, plane);
    if(d<H)
    {
        vec3 near = p - d*plane.xyz;
        vec3 t = cross(plane.yzx, plane.xyz);
        vec3 b = cross(t, plane.xyz);
        int nb = 5;
        for(int i=0; i<nb; i++)
        {
            float dx = (i-nb/2)*PARTICLE_DIAM;
            for(int j=0; j<nb; j++)
            {
                float dy = (j-nb/2)*PARTICLE_DIAM;
                vec3 b_pos = near + dx*t + dy*b;
                vec3 b_vel = vec3(0.0);
                vec3 rij = p - b_pos;
                float r = length(rij);
                float Wgrad = W_cubic_grad(r);
                vec3 uij = rij/r;
                float rho_j = PSI;
                float press_j = WeaklyCompressibleStateEqn(rho_j);
                acc_press -= (acc_press_i + press_j/(rho_j*rho_j)) * Wgrad*uij;

                vec3 vij = p - b_vel;
                acc_visc -= 1.0/rho_j * dot(vij, rij)/(r*r + 0.01*HSQ) * Wgrad*uij;
            }
        }
    }
}

void force_wave(vec3 p, float acc_press_i, inout vec3 acc_press, inout vec3 acc_visc)
{
    float h = wave_height(p);
    float d = p.y-h;
    const vec3 t = vec3(1.0, 0.0, 0.0);
    const vec3 b = vec3(0.0, 0.0, 1.0);
    //vec3 n = wave_normal(p);
    //vec3 t = cross(n.yzx, n.xyz);
    //vec3 b = cross(t, n.xyz);
    if(d<H)
    {
        int nb = 5;
        for(int i=0; i<nb; i++)
        {
            float dx = (i-nb/2)*PARTICLE_DIAM;
            for(int j=0; j<nb; j++)
            {
                float dy = (j-nb/2)*PARTICLE_DIAM;
                vec3 b_pos = p + dx*t + dy*b;
                b_pos.y = wave_height(b_pos);
                vec3 b_vel = vec3(0.0);
                vec3 rij = p - b_pos;
                float r = length(rij);
                float Wgrad = W_cubic_grad(r);
                vec3 uij = rij/r;
                float rho_j = PSI;
                float press_j = WeaklyCompressibleStateEqn(rho_j);
                acc_press -= (acc_press_i + press_j/(rho_j*rho_j)) * Wgrad*uij;

                vec3 vij = p - b_vel;
                acc_visc -= 1.0/rho_j * dot(vij, rij)/(r*r + 0.01*HSQ) * Wgrad*uij;
            }
        }
    }

    if(d>0.0)
    {
        acc_press += 5.0*d*d*G;
    }
    //acc_press += -100.0*vec3(0.0, p.y-h, 0.0);
}

void ComputeForces(int ix)
{
	Particle pi = particles_in[ix];
    float rho_i = get_rho(pi);
    vec3 acc_press = vec3(0.0);
    vec3 acc_visc = vec3(0.0);
    vec3 acc_grav = G.xyz;
    float c_visc = -VISC*8.0*MASS;
    //float c_visc = VISC*MASS;
    float c_press = MASS;

    float acc_press_i = get_pressure(pi)/(rho_i*rho_i);

    aabb3D query_aabb = aabb3D(vec4(pi.pos.xyz-vec3(H), 0.0), vec4(pi.pos.xyz+vec3(H), 0.0));
    //These are the cells the query overlaps
    ivec3 cell_min = CellCoord(query_aabb.mMin.xyz);
	ivec3 cell_max = CellCoord(query_aabb.mMax.xyz);
    
    for(int i=cell_min.x; i<=cell_max.x; i++)
    {
	    for(int j=cell_min.y; j<=cell_max.y; j++)
	    {
            for(int k=cell_min.z; k<=cell_max.z; k++)
			{
				int cell = Index(ivec3(i,j,k));
				int start = mStart[cell];
				int count = mCount[cell];
		    
		        for(int list_index = start; list_index<start+count; list_index++)
		        {
			        int jx = mContent[list_index];
                    Particle pj = particles_in[jx];
			  
			        if(jx != ix) //don't process self (ix)
			        {
                        vec3 rij = pi.pos.xyz - pj.pos.xyz;
                        float r = length(rij);

                        if (r < H)
                        {
                            float Wgrad = W_cubic_grad(r);
                            vec3 uij = rij/r;
                            float rho_j = get_rho(pj);
                            // compute pressure force contribution
                            acc_press -= (acc_press_i + get_pressure(pj)/(rho_j*rho_j)) * Wgrad*uij;
                            // compute viscosity force contribution
                            vec3 vij = pi.vel.xyz - pj.vel.xyz;
                            acc_visc -= 1.0/rho_j * dot(vij, rij)/(r*r + 0.01*HSQ) * Wgrad*uij;
                            //float Wij = W_cubic(r);
                            //acc_visc += 1.0/(rho_j*DT)*Wij*vij;
                        }   
			        }
		        }  
            }
	    }
    }

    //boundary
    if(wave_boundary)
    {
        for(int i=0; i<6; i++)
        {
            //force_boundary(pi.pos.xyz, wall[i], acc_press_i, acc_press, acc_visc);
        }
        force_wave(pi.pos.xyz, acc_press_i, acc_press, acc_visc);
    }
    
    acc_visc *= c_visc;
    acc_press *= c_press;
    
    //INTEGRATE
    //semi-implicit Euler integration
    pi.acc.xyz = acc_press + acc_visc + acc_grav;
    pi.vel.xyz += DT * pi.acc.xyz;
    pi.pos.xyz += DT * pi.vel.xyz;

    float h = pi.pos.y-wave_height(pi.pos.xyz);
    if(h < 0.0)
    {
        pi.pos.y += 0.05;
    }

    //Periodic BC
    float eps = 0.05;
    vec3 rand = hash( pi.pos.xyz );
    if(pi.pos.x < -1.0+eps) {pi.pos.x += 2.0-2.0*eps;  pi.pos.y = wave_height(pi.pos.xyz) + h; pi.vel.xyz *= 0.5f;}
    if(pi.pos.x > +1.0-eps) {pi.pos.x -= 2.0-2.0*eps;  pi.pos.y = wave_height(pi.pos.xyz) + h; pi.vel.xyz *= 0.5f;}
    if(pi.pos.z < -1.0+eps) {pi.pos.z += 2.0-2.0*eps;  pi.pos.y = wave_height(pi.pos.xyz) + h; pi.vel.xyz *= 0.5f;}
    if(pi.pos.z > +1.0-eps) {pi.pos.z -= 2.0-2.0*eps;  pi.pos.y = wave_height(pi.pos.xyz) + h; pi.vel.xyz *= 0.5f;}

    particles_out[ix] = pi;
}
