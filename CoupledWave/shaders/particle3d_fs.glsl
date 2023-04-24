#version 450
 
layout(location = 1) uniform float time;
layout(location = 2) uniform int pass;
layout(binding = 1) uniform samplerCube skybox_tex;

layout(binding = 2) uniform sampler2DShadow shadow_map;
layout(location = 10) uniform mat4 Shadow; //shadow matrix

#include "std_uniforms.h.glsl"
#line 12
uniform float alpha_scale = 1.0;

in VertexData
{
   vec3 pw;   //world-space vertex position
   vec3 peye; //eye-space position
   vec3 vel_eye;
   float rand;
   float radius;
   float pressure;
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

vec3 mixstep(vec3 c0, vec3 c1, float e0, float e1, float x)
{
    return mix(c0, c1, smoothstep(e0, e1, x));
}

vec4 mixstep(vec4 c0, vec4 c1, float e0, float e1, float x)
{
    return mix(c0, c1, smoothstep(e0, e1, x));
}

void pointed_particle();
void sphere();
float eps = 1e-6;
void main(void)
{   
	//fragcolor = vec4(1.0); 
	//return;

	sphere();
	return;

    pointed_particle();
    return;

	float r = distance(gl_PointCoord.xy, vec2(0.5));
	if(r>=0.5) discard;
	//float a = 0.0*exp(-15.0*r+eps)+0.5*exp(-2.0*r+eps);
	float a = 0.5;
	vec3 kd = vec3(1.0, 1.0, 1.0);

	fragcolor = vec4(kd, alpha_scale*a*MaterialUniforms.kd.a);
	float depth_cue = smoothstep(2.0, 5.0, -inData.peye.z);
	fragcolor.rgb *= 0.75 + 0.5*inData.rand;
	//fragcolor = MaterialUniforms.kd;
}

vec3 color = vec3(0.8, 0.9, 1.0);

uniform float offset = 0.002;

void sphere()
{
    float r_world = inData.radius;
    
    vec2 coord = vec2(1.0, -1.0)*(2.0*gl_PointCoord.xy - vec2(1.0));
    float r_coord = length(coord);
    if(r_coord>=1.0) discard;
    float alpha = 1.0;//.25+0.75*smoothstep(1.0, 0.95, r_coord);
    vec4 p_local = vec4(coord*r_world, 0.0, 1.0);
    p_local.z = sqrt(r_world*r_world - dot(p_local.xy, p_local.xy));

    vec4 p_eye =  p_local + vec4(inData.peye, 0.0);
    vec4 p_clip = SceneUniforms.P*p_eye;
    vec4 p_ndc = p_clip/p_clip.w;
    gl_FragDepth = 0.5*(gl_DepthRange.diff*p_ndc.z + gl_DepthRange.near + gl_DepthRange.far);

	vec3 nw;
	nw.xy = vec2(1.0, -1.0)*(2.0*gl_PointCoord.xy-vec2(1.0));
	nw.z = sqrt(1.0-dot(nw.xy, nw.xy));

    mat4 Vinv = inverse(SceneUniforms.V);
	nw = vec3(Vinv*vec4(nw, 0.0));
    vec4 eye_w = Vinv*vec4(0.0, 0.0, 0.0, 1.0);

    vec4 pw = Vinv*p_eye;
    vec4 shadow_coord = Shadow*pw;
    shadow_coord.z -= offset; //polygon offset
    float lit = textureProj(shadow_map, shadow_coord);

	vec3 lw = normalize(LightUniforms.light_w.xyz - inData.pw.xyz);

    vec3 c0 = 1.05*vec3(0.1, 0.75, 1.0);
    vec3 c1 = 1.05*vec3(1.2, 1.2, 0.9);
    //vec4 kd = mixstep(c1, c0, 2.0*0.47, 2.0*0.53, rho);
    color = mixstep(c1, c0, -0.1, 0.15, inData.pressure/1000.0);

    //lighting
	vec4 ambient_term = vec4(color, 1.0)*LightUniforms.La;
	vec4 diffuse_term = vec4(color, 1.0)*LightUniforms.Ld*max(0.0, dot(nw, lw));

	vec3 vw = normalize(eye_w.xyz - inData.pw.xyz);
	vec3 rw = reflect(-lw, nw);

	vec3 rv = reflect(-vw, nw);
	//vec4 refl = texture(skybox_tex, rv.xyz, 2.0);

	vec4 specular_term = MaterialUniforms.ks*LightUniforms.Ls*pow(max(0.0, dot(rw, vw)), MaterialUniforms.shininess);
    float rim = pow(p_local.z/r_world, 1.5);
    
	fragcolor = rim*ambient_term + lit*(diffuse_term + specular_term);
	//fragcolor = 1.2*refl;
	//fragcolor.a = 0.5;
    //fragcolor = vec4(p_local.z/r_world); //rim
    //fragcolor = vec4(lit);
    //fragcolor.rgb = eye_w.xyz;
    
    float d = -p_eye.z; //distance from eye
	const float fd = 0.05; //fog density
	float f = clamp(exp(-fd*d*d), 0.0, 1.0); //fog factor
    fragcolor.rgb = mix(SceneUniforms.fog_color.rgb, fragcolor.rgb, f);

    //gamma
    fragcolor = pow(fragcolor, vec4(1.0/2.2));
    fragcolor.a = alpha;
}

void pointed_particle()
{
    const float eps = 1e-2;
    vec2 p = gl_PointCoord.xy-vec2(0.5);
    vec2 pa = -1.5*inData.vel_eye.xy*vec2(-1.0,1.0);
    vec2 pb = +1.5*inData.vel_eye.xy*vec2(-1.0,1.0);
    const float rb = 0.02;
    const float ra = 0.1;

    vec2 pba = pb-pa;
    float g = dot(p-pa, pba)/dot(pba, pba);

    float r = sdSegment(p, pa, pb)-0.25;
    //float r = distance(p, vec2(0.0));
    if(r>=0.0) discard;

    vec3 color1 = vec3(0.80, 1.0, 0.95);
    vec3 color2 = vec3(1.0);
    vec3 color = mix(color1, color2, g);

    fragcolor = vec4(color1, 0.15);
    fragcolor.rgb *= 0.75 + 0.5*inData.rand;
    fragcolor.rgb *= 0.75 + 0.5*g;

    /*

    float r = sdUnevenCapsule(p, pa, pb, ra, rb)-0.1;
    //if(length(inData.vel_eye.xy)<0.1) r = sdSegment(p, pa, pb)-0.2;
    
    //float r = sdSegment(p, pa, pb)-0.2;
	if(r>=0.5) discard;
	float a = exp(-12.0*r)+0.1*exp(-2.0*r);
	
    fragcolor = vec4(1.0);
    fragcolor.rgb *= 0.75 + 0.5*inData.rand;
    */
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















