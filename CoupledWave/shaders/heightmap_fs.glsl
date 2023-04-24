#version 450

layout(binding = 0) uniform sampler2D heightmap_tex;
layout(binding = 1) uniform samplerCube skybox_tex;
layout(location = 1) uniform float time = 0.0;
layout(location = 2) uniform int pass = 0;
layout(location = 3) uniform float scale = 1.0;
layout(location = 4) uniform bool wireframe = true;

layout(binding = 2) uniform sampler2DShadow shadow_map;
layout(location = 10) uniform mat4 Shadow; //shadow matrix
uniform float polygon_offset = 0.008;

#include "std_uniforms.h.glsl"
#line 12
in VertexData
{
   vec2 tex_coord;
   vec3 pw;       //world-space vertex position
   vec3 nw;   //world-space normal vector
   vec3 peye; //eye-space position
   float wave_h;
} inData;   //block is named 'inData'

out vec4 fragcolor; //the output color for this fragment    

void main(void)
{   
	if(wireframe)
	{
		fragcolor = vec4(1.0);
		return;
	}
	else
	{
		//Compute per-fragment Phong lighting
		//vec4 ktex = texture(diffuse_tex, inData.tex_coord);

		vec4 shadow_coord = Shadow*vec4(inData.pw, 1.0);
		shadow_coord.z -= polygon_offset; //polygon offset
		float lit = 1.0;
		if(textureSize(shadow_map, 0).x > 0)
		{
			lit = textureProj(shadow_map, shadow_coord);
		}

		vec4 ambient_term = MaterialUniforms.ka*LightUniforms.La;

		const float eps = 1e-8; //small value to avoid division by 0
		float d = distance(LightUniforms.light_w.xyz, inData.pw.xyz);
		float atten = 1.0/(dot(LightUniforms.quad_atten.xyz, vec3(1.0, d, d*d))+eps);// quadratic attenutation

		vec3 nw = normalize(inData.nw);			//world-space unit normal vector
		vec3 lw = normalize(LightUniforms.light_w.xyz - inData.pw.xyz);	//world-space unit light vector

		vec4 kd0 = MaterialUniforms.kd;
		vec4 kd1 = 0.25*kd0;
		vec4 kd = mix(kd0, kd1, smoothstep(+1.0, -1.0, inData.wave_h));

		vec4 diffuse_term = atten*kd*LightUniforms.Ld*max(0.0, dot(nw, lw));

		vec3 e_w = vec3(inverse(SceneUniforms.V)*vec4(0.0, 0.0, 0.0, 1.0)); //world-space eye pos
		//vec3 e_w = SceneUniforms.eye_w.xyz;
		vec3 vw = normalize(e_w - inData.pw.xyz);	//world-space unit view vector
		vec3 rw = reflect(-lw, nw);	//world-space unit reflection vector

		vec3 rv = reflect(-vw, nw);
		vec4 refl = vec4(1.0);
		if(textureSize(skybox_tex, 2).x > 0)
		{
			refl = texture(skybox_tex, rv, 2.0);
		}
		//vec4 specular_term = atten*refl*MaterialUniforms.ks*LightUniforms.Ls*pow(max(0.0, dot(rw, vw)), MaterialUniforms.shininess);

		vec4 specular_term = refl*MaterialUniforms.ks*LightUniforms.Ls*pow(max(0.0, dot(rw, vw)), MaterialUniforms.shininess);

		const float eta = 0.15; // Water
		float fresnel = eta + (1.0 - eta) * pow(max(0.0, 1.0 - dot(vw, nw)), 5.0);
		fresnel = clamp(fresnel-0.2, 0.0, 1.0);

		vec4 phong = ambient_term + lit*(diffuse_term + specular_term);

		fragcolor = phong;
		//fragcolor = mix(phong, refl, fresnel);

		//fragcolor = kd;
		//fragcolor = vec4(fresnel);
		//fragcolor = specular_term;
		//fragcolor = ambient_term;
		//fragcolor = diffuse_term;
		//fragcolor = vec4(abs(nw), 1.0);
		//fragcolor = refl;
		//fragcolor.xyz = e.xyz;
		//fragcolor.xyz = abs(vw.xyz);
   }
}




















