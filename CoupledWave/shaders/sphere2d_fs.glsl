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
	float r = distance(gl_PointCoord.xy, vec2(0.5));
	if(r>=0.5) discard;

	vec3 nw;
	nw.xy = vec2(1.0, -1.0)*(2.0*gl_PointCoord.xy-vec2(1.0));
	nw.z = sqrt(1.0-dot(nw.xy, nw.xy));
	vec3 lw = normalize(LightUniforms.light_w.xyz - inData.pw.xyz);

	vec4 ambient_term = vec4(inData.color, 1.0)*LightUniforms.La;
	vec4 diffuse_term = vec4(inData.color, 1.0)*LightUniforms.Ld*max(0.0, dot(nw, lw));

	vec3 vw = normalize(SceneUniforms.eye_w.xyz - inData.pw.xyz);
	vec3 rw = reflect(-lw, nw);
	vec4 specular_term = MaterialUniforms.ks*LightUniforms.Ls*pow(max(0.0, dot(rw, vw)), MaterialUniforms.shininess);

	fragcolor = ambient_term + diffuse_term + specular_term;
	//fragcolor = diffuse_term;
	//fragcolor = vec4(inData.color, 1.0);
	//fragcolor.rgb = n;
}




















