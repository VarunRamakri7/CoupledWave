#version 450
layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(rgba32f, binding = 0) restrict readonly uniform image2D uImage; 

layout (std430, binding = 1) restrict buffer HIST 
{
	int histogram[];
};

layout(location = 1) uniform int uNumElements=0;

void main(void)
{
   ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
   ivec2 input_size = imageSize(uImage);
   //Don't read outside image bounds
   if(coord.x >= input_size.x || coord.y >= input_size.y) return;

   //Compute integer luminance value
   vec4 color = imageLoad(uImage, coord);
   float lum = dot(vec3(0.2126, 0.7152, 0.0722), color.rgb);
   lum = clamp(lum, 0.0, 1.0);
   int ilum = int(round((uNumElements-1)*lum));

   //increment the histogram bin
   atomicAdd(histogram[ilum], 1);	
	//histogram[coord.x%uNumElements] = coord.x%uNumElements;
}

/*
//for reading from texture and writing to image
layout(binding = 0) uniform sampler2D input_tex; 
layout(r32i, binding = 1) uniform iimage1D output_tex;

void main(void)
{
   ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
   ivec2 input_size = textureSize(input_tex, 0);
   //Don't read outside image bounds
   if(coord.x >= input_size.x || coord.y >= input_size.y) return;

   //Compute integer luminance value
   vec4 color = texelFetch(input_tex, coord, 0);
   float lum = dot(vec3(0.2126, 0.7152, 0.0722), color.rgb);
   int ilum = int(round(255.0*lum));

   //increment the histogram bin
   imageAtomicAdd(output_tex, ilum, 1);	
}
*/

