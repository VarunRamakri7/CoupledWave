#version 450

layout(local_size_x = 32, local_size_y = 32) in;

layout(rgba8, binding = 0) restrict uniform image2D uImage; 

layout(location=0) uniform int uMode = 0; //a mask

const int NEGATIVE_MODE_MASK = 1;
const int VIGNETTE_MODE_MASK = 2;

vec4 photonegative(vec4 v);
vec4 vignette(vec4 v, vec2 uv);

void main()
{
	ivec2 gid = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(uImage);

	if(any(greaterThanEqual(gid, size))) return;

	vec2 uv = vec2(gid)/size;
	vec4 v = imageLoad(uImage, gid);

	if((uMode & NEGATIVE_MODE_MASK) > 0) v = photonegative(v);
	if((uMode & VIGNETTE_MODE_MASK) > 0) v = vignette(v, uv);
	
	imageStore(uImage, gid, v);
}

vec4 photonegative(vec4 v)
{
	return vec4(vec3(1.0)-v.rgb, v.a);
}

vec4 vignette(vec4 v, vec2 uv)
{
	float r = distance(uv, vec2(0.5));
	float f = smoothstep(1.0, 0.5, r);
	return vec4(f,f,f,1.0)*v;
}