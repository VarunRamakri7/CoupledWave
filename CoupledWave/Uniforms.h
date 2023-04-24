#pragma once

#include "StdUniforms.h"
#include "Buffer.h"
#include <glm/glm.hpp>
#include <string>


extern StdUniforms::SceneUniforms SceneData;
extern StdUniforms::LightUniforms LightData;
extern StdUniforms::MaterialUniforms MaterialData;

extern Buffer scene_ubo;
extern Buffer light_ubo;
extern Buffer material_ubo;

void init_ubos();
void scene_uniforms_gui(bool& open);
void material_uniforms_gui(bool& open);
void light_uniforms_gui(bool& open);
