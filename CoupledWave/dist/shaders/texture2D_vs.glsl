#version 450 
layout(binding = 0) uniform sampler2D tex; 

layout(location = 0) uniform float vp_aspect = 1.0;

const vec4 quad[4] = vec4[] (vec4(-1.0, 1.0, 0.0, 1.0), 
							vec4(-1.0, -1.0, 0.0, 1.0), 
							vec4( 1.0, 1.0, 0.0, 1.0), 
							vec4( 1.0, -1.0, 0.0, 1.0) );

out VertexData
{
   vec2 tex_coord;

} outData; 

void main(void)
{
	ivec2 size = textureSize(tex, 0);
	float tex_aspect = float(size.x)/float(size.y);
	float aspect = tex_aspect/vp_aspect;
	vec2 scale = vec2(aspect, 1.0);
	if(aspect > 1.0) scale = vec2(1.0, 1.0/aspect);

	gl_Position = quad[ gl_VertexID ];
	gl_Position.xy *= scale;
	outData.tex_coord = 0.5*quad[ gl_VertexID ].xy + vec2(0.5);
}