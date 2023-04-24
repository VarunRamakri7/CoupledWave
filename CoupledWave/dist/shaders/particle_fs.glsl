#version 450
 
layout(location = 1) uniform float time;
layout(location = 2) uniform int pass;

#include "std_uniforms.h.glsl"

in VertexData
{
	vec4 pos;
	vec4 vel;		
	vec4 acc;
	flat int id;	
} inData;   

out vec4 fragcolor; //the output color for this fragment    

const int ROUND_PARTICLES = 0;
const int POINTED_PARTICLES = 1;

uniform int mode = POINTED_PARTICLES;

void round_particle();
void pointed_particle();

// https://iquilezles.org/articles/distfunctions2d/ 
float sdUnevenCapsuleY( vec2 p, float r1, float r2, float h );
float sdUnevenCapsule( in vec2 p, in vec2 pa, in vec2 pb, in float ra, in float rb );
float sdSegment( in vec2 p, in vec2 a, in vec2 b );

void main(void)
{   
	switch(mode)
	{
		case ROUND_PARTICLES:
			round_particle();
		break;

		case POINTED_PARTICLES:
			pointed_particle();
		break;
	}	
}

void round_particle()
{
	float r = distance(gl_PointCoord.xy, vec2(0.5));
	if(r>=0.5) discard;
	float a = exp(-12.0*r)+0.1*exp(-2.0*r);
	//fragcolor = vec4(0.5, 0.5, 0.5, 1.0-2.0*r);
	fragcolor = vec4(MaterialUniforms.kd.rgb, a*MaterialUniforms.kd.a);
}

void pointed_particle()
{
    const float eps = 1e-2;
    vec2 p = gl_PointCoord.xy-vec2(0.5);
    vec2 pa = -1.0*inData.vel.xy*vec2(-1.0,1.0);
    vec2 pb = +1.5*inData.vel.xy*vec2(-1.0,1.0);
    const float rb = 0.02;
    const float ra = 0.1;

    float r = sdUnevenCapsule(p, pa, pb, ra, rb)-0.1;
    if(length(inData.vel.xy)<0.1) r = sdSegment(p, pa, pb)-0.2;
    
    //float r = sdSegment(p, pa, pb)-0.2;
	if(r>=0.5) discard;
	float a = exp(-12.0*r)+0.1*exp(-2.0*r);
	
    float age = inData.pos.w;
    //vec4 color = mix(MaterialUniforms.kd, MaterialUniforms.ka, age/10.0);

    vec4 color = MaterialUniforms.kd;
    if(inData.id %2==0) color = MaterialUniforms.ka;
	fragcolor = vec4(color.rgb, a*color.a);
}


float sdUnevenCapsuleY( vec2 p, float r1, float r2, float h )
{
    p.x = abs(p.x);
    float b = (r1-r2)/h;
    float a = sqrt(1.0-b*b);
    float k = dot(p,vec2(-b,a));
    if( k < 0.0 ) return length(p) - r1;
    if( k > a*h ) return length(p-vec2(0.0,h)) - r2;
    return dot(p, vec2(a,b) ) - r1;
}

float cro(in vec2 a, in vec2 b ) { return a.x*b.y - a.y*b.x; }

float sdUnevenCapsule( in vec2 p, in vec2 pa, in vec2 pb, in float ra, in float rb )
{
    p  -= pa;
    pb -= pa;
    float h = dot(pb,pb);
    vec2  q = vec2( dot(p,vec2(pb.y,-pb.x)), dot(p,pb) )/h;
    
    //-----------
    
    q.x = abs(q.x);
    
    float b = ra-rb;
    vec2  c = vec2(sqrt(h-b*b),b);
    
    float k = cro(c,q);
    float m = dot(c,q);
    float n = dot(q,q);
    
         if( k < 0.0 ) return sqrt(h*(n            )) - ra;
    else if( k > c.x ) return sqrt(h*(n+1.0-2.0*q.y)) - rb;
                       return m                       - ra;
}


float sdSegment( in vec2 p, in vec2 a, in vec2 b )
{
    vec2 pa = p-a, ba = b-a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length( pa - ba*h );
}
















