#version 450
 
layout(location = 1) uniform float time;
layout(location = 2) uniform int pass;

#include "std_uniforms.h.glsl"

in VertexData
{
   vec3 pw;   //world-space vertex position
   vec3 peye; //eye-space position
   vec3 color;
} inData;   

out vec4 fragcolor; //the output color for this fragment    

void main(void)
{   
	//fragcolor = kd;
	fragcolor = vec4(inData.color, 1.0);
}




















