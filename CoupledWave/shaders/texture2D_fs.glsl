#version 450

layout(binding = 0) uniform sampler2D tex; 
layout(location=3) uniform float scale = 2.0;
in VertexData
{
   vec2 tex_coord;
   
} inData;   

out vec4 fragcolor; 

void main(void)
{   
   fragcolor = scale*texture(tex, inData.tex_coord);
   //fragcolor = vec4(1.0, 0.0, 0.0, 1.0); //debug
}




















