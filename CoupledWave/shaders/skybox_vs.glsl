#version 450            

#include "std_uniforms.h.glsl"
#line 5

const vec4 cube[8] = vec4[]( vec4(-1.0, -1.0, -1.0, 1.0),
								vec4(-1.0, +1.0, -1.0, 1.0),
								vec4(+1.0, +1.0, -1.0, 1.0),
								vec4(+1.0, -1.0, -1.0, 1.0),
								vec4(-1.0, -1.0, +1.0, 1.0),
								vec4(-1.0, +1.0, +1.0, 1.0),
								vec4(+1.0, +1.0, +1.0, 1.0),
								vec4(+1.0, -1.0, +1.0, 1.0));

const int index[14] = int[](1, 0, 2, 3, 7, 0, 4, 1, 5, 2, 6, 7, 5, 4);

out VertexData
{
   vec3 pw;			//world-space vertex position
} outData; 

void main(void)
{
	mat4 Vsky = SceneUniforms.V;
	Vsky[3] = vec4(0.0, 0.0, 0.0, 1.0);

	int ix = index[gl_VertexID];
	vec4 v = cube[ix];
	outData.pw = v.xyz;
	gl_Position = SceneUniforms.P*Vsky*v;
	
}