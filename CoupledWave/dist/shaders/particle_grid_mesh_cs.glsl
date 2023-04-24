#version 450
#include "aabb_cs.h.glsl"
#include "std_uniforms.h.glsl"
#line 5

layout(local_size_x = 1024) in;

struct Particle
{
   vec4 pos;
   vec4 vel;
   vec4 acc;
};

const int kGridUboBinding = 0;
const int kPointsInBinding = 0;
const int kPointsOutBinding = 1;
const int kCountBinding = 2;
const int kStartBinding = 3;
const int kContentBinding = 4;
const int kIndicesBinding = 5;
const int kVerticesBinding = 6;

layout (std430, binding = kPointsInBinding) restrict readonly buffer PARTICLES_IN 
{
	Particle particles_in[];
};

layout (std430, binding = kPointsOutBinding) restrict writeonly buffer PARTICLES_OUT 
{
	Particle particles_out[];
};

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

layout (std430, binding = kIndicesBinding) restrict readonly buffer INDICES 
{
	uint indices[];
};

layout (std430, binding = kVerticesBinding) restrict readonly buffer VERTICES 
{
	float verts[];
};

#include "grid_3d_cs.h.glsl"
#line 60

layout(location = 0) uniform int uMode=0; 
layout(location = 1) uniform int uNumElements=0;
layout(location = 2) uniform mat4 uM = mat4(1.0);

const int MODE_INIT = 0;
const int MODE_ANIM = 1;


void InitParticle(int ix);
void AnimParticle(int ix);

//reads triangle indices for GL_TRIANGLES index buffer
uvec3 read_triangle_indices(uint tri)
{
	return uvec3(indices[3*tri+0], indices[3*tri+1], indices[3*tri+2]);
}

//reads vec3 triangle vertices
vec3 read_vertex(uint ix)
{
	vec3 v = vec3(verts[3*ix+0], verts[3*ix+1], verts[3*ix+2]);
	vec4 v_w = uM*vec4(v, 1.0);
	return v_w.xyz;
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

		case MODE_ANIM:
			AnimParticle(gid);
		break;

	}
}

void InitParticle(int ix)
{
	particles_out[ix].pos = vec4(0.05*sin(12345.0*ix)+0.5*sin(SceneUniforms.Time), 0.25, 0.05*sin(54321.0*ix), 0.0);		
	particles_out[ix].vel = vec4(0.0);
	particles_out[ix].acc = vec4(0.0, -2.0, 0.0, 0.0);
}

//Ray-triangle intersection test
vec3 triIntersect( in vec3 ro, in vec3 rd, in vec3 v0, in vec3 v1, in vec3 v2 )
{
    vec3 v1v0 = v1 - v0;
    vec3 v2v0 = v2 - v0;
    vec3 rov0 = ro - v0;
    vec3  n = cross( v1v0, v2v0 );
    vec3  q = cross( rov0, rd );
    float d = 1.0/dot( rd, n );
    float u = d*dot( -q, v2v0 );
    float v = d*dot(  q, v1v0 );
    float t = d*dot( -n, rov0 );
    if( u<0.0 || v<0.0 || (u+v)>1.0 ) t = -1.0;
    return vec3( t, u, v );
}

void AnimParticle(int ix)
{
	float dt = 0.003;
	Particle pi = particles_in[ix];
	vec4 p0 = pi.pos;

	pi.vel += dt*pi.acc;
	pi.pos += dt*pi.vel;

	if(pi.pos.y < -0.5)
	{
		InitParticle(ix);
		return;
	}

	vec4 d = pi.pos-p0;
	vec3 box_min = min(p0.xyz, pi.pos.xyz);
	vec3 box_max = max(p0.xyz, pi.pos.xyz);

	//These are the cells the query overlaps
	ivec3 cell_min = CellCoord(box_min);
	ivec3 cell_max = CellCoord(box_max);

	if(pi.pos.w > 0.0)
	for(int i=cell_min.x; i<=cell_max.x; i++)
	for(int j=cell_min.y; j<=cell_max.y; j++)
	for(int k=cell_min.z; k<=cell_max.z; k++)
	{
		ivec2 range = ContentRange(ivec3(i,j,k));
		for(int list_index = range[0]; list_index<=range[1]; list_index++)
		{
			int tri = mContent[list_index];
			uvec3 vx = read_triangle_indices(tri);
			vec3 v0 = read_vertex(vx[0]);
			vec3 v1 = read_vertex(vx[1]);
			vec3 v2 = read_vertex(vx[2]);

			vec3 res = triIntersect(p0.xyz, d.xyz, v0, v1, v2 );
			if(res[0] >= 0.0 && res[0] <= 1.0)
			{
				pi.pos.xyz = p0.xyz + res[0]*d.xyz;
				vec3 n = normalize(cross(v1-v0, v2-v0));
				pi.vel.xyz += 1.8*abs(dot(pi.vel.xyz, n))*n;
				pi.pos.xyz += pi.vel.xyz*dt*(1.0-res[0]);
			}
		}       
	}
	pi.pos.w += 1.0;
	particles_out[ix] = pi;
}


