#version 450

layout(binding=0) uniform samplerCube skybox_tex;

out vec4 fragcolor; //the output color for this fragment    

in VertexData
{
   vec3 pw;       //world-space vertex position
} inData; 

void main(void)
{   
	fragcolor = texture(skybox_tex, normalize(inData.pw));
}




















