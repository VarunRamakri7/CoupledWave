#version 450 

#include "std_uniforms.h.glsl"
#include "aabb_cs.h.glsl"

layout (std430, binding = 0) readonly restrict buffer PARTICLES
{
	aabb2D boxes[];
};

//https://www.shadertoy.com/view/ll2GD3
// cosine based palette, 4 vec3 params
vec3 palette( in float t, in vec3 a, in vec3 b, in vec3 c, in vec3 d )
{
    return a + b*cos( 6.28318*(c*t+d) );
}

vec3 rainbow( float t)
{
	return palette(t, vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,1.0),vec3(0.0,0.33,0.67) );
}

out VertexData
{
	vec3 pw;			//world-space vertex position
	vec3 peye;		//eye-space position
	vec3 color;
} outData; 

void main(void)
{
	int ix = gl_InstanceID;
	vec4 verts[4];
	verts[0] = vec4(boxes[ix].mMin, 0.0, 1.0);
	verts[1] = vec4(boxes[ix].mMin.x, boxes[ix].mMax.y, 0.0, 1.0);
	verts[2] = vec4(boxes[ix].mMax.x, boxes[ix].mMin.y, 0.0, 1.0);
	verts[3] = vec4(boxes[ix].mMax, 0.0, 1.0);
	gl_Position = SceneUniforms.P_ortho*verts[gl_VertexID%4]; //transform vertices and send result into pipeline

	outData.color = rainbow(float(ix)*0.1);
}