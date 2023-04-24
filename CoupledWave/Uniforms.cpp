#include <windows.h>
#include <GL/glew.h>
#include <glm/glm.hpp>
#include "imgui.h"

#include "Uniforms.h"
#include "Scene.h"

//These structures mirror the uniform block declared in the shader
StdUniforms::SceneUniforms SceneData;
StdUniforms::LightUniforms LightData;
StdUniforms::MaterialUniforms MaterialData;

//IDs for the buffer objects holding the uniform block data
Buffer scene_ubo(GL_UNIFORM_BUFFER, StdUniforms::UboBinding::scene);
Buffer light_ubo(GL_UNIFORM_BUFFER, StdUniforms::UboBinding::light);
Buffer material_ubo(GL_UNIFORM_BUFFER, StdUniforms::UboBinding::material);

void init_ubos()
{
   //Create and initialize uniform buffers
   scene_ubo.Init(sizeof(StdUniforms::SceneUniforms), &SceneData, GL_DYNAMIC_STORAGE_BIT);
   scene_ubo.BindBufferBase();

   LightData.La = glm::vec4(0.27f, 0.43f, 0.35f, 0.3f);
   LightData.Ld = glm::vec4(0.747f, 0.63f, 0.78f, 1.0f);
   LightData.Ls = glm::vec4(0.78f, 0.595f, 1.0f, 1.0f);
   LightData.pos_w = glm::vec4(0.0f, 20.0f, 0.0f, 1.0f);

   light_ubo.Init(sizeof(StdUniforms::LightUniforms), &LightData, GL_DYNAMIC_STORAGE_BIT);
   light_ubo.BindBufferBase();

   MaterialData.ka = (1.0f / 255.0f) * glm::vec4(255.0f);
   MaterialData.kd = (1.0f / 255.0f) * glm::vec4(44.0f, 165.0f, 144.0f, 255.0f);
   MaterialData.ks = (1.0f / 255.0f) * glm::vec4(160.0f);
   MaterialData.shininess = 1.0f;

   material_ubo.Init(sizeof(StdUniforms::MaterialUniforms), &MaterialData, GL_DYNAMIC_STORAGE_BIT);
   material_ubo.BindBufferBase();
}

void scene_uniforms_gui(bool& open)
{
   if(open)
   {
      ImGui::Begin("Scene Uniforms", &open);
      if (ImGui::ColorEdit4("Clear color", &SceneData.clear_color.r))
      {
         glClearColor(SceneData.clear_color.r, SceneData.clear_color.g, SceneData.clear_color.b, SceneData.clear_color.a);
      }
      ImGui::ColorEdit4("Fog color", &SceneData.fog_color.r);

      if (ImGui::SliderFloat3("Camera position", &SceneData.eye_w.x, -10.0f, +10.0f))
      {
         Camera::UpdateV();
      }

      if (ImGui::SliderInt4("Viewport", &SceneData.Viewport.x, 0, 2000))
      {
         Camera::UpdateP();
      }

      ImGui::SliderInt4("Mouse button", &SceneData.MouseButtonState.x, 0, 1);
      ImGui::SliderFloat4("Lmb Click and Drag", &SceneData.LmbClickAndDrag.x, 0.0f, 2000.0f);
      ImGui::SliderFloat4("Mmb Click and Drag", &SceneData.MmbClickAndDrag.x, 0.0f, 2000.0f);
      ImGui::SliderFloat4("Rmb Click and Drag", &SceneData.RmbClickAndDrag.x, 0.0f, 2000.0f);
      ImGui::SliderFloat4("Mouse Pos", &SceneData.MousePos.x, 0.0f, 2000.0f);
      ImGui::SliderFloat4("Scroll Pos", &SceneData.ScrollPos.x, 0.0f, 2000.0f);
      ImGui::End();

      scene_ubo.BufferSubData(0, sizeof(StdUniforms::SceneUniforms), &SceneData);
   }
}

void material_uniforms_gui(bool& open)
{
   if (open)
   {
      ImGui::Begin("Material Uniforms", &open);
      ImGui::ColorEdit4("ka", &MaterialData.ka.r);
      ImGui::ColorEdit4("kd", &MaterialData.kd.r);
      ImGui::ColorEdit4("ks", &MaterialData.ks.r);
      ImGui::SliderFloat("shininess", &MaterialData.shininess, 0.0f, 100.0f);
      ImGui::End();

      material_ubo.BufferSubData(0, sizeof(StdUniforms::MaterialUniforms), &MaterialData);
      material_ubo.BindBufferBase();
   }
}

void light_uniforms_gui(bool& open)
{
   if (open)
   {
      ImGui::Begin("Light Uniforms", &open);
      ImGui::ColorEdit4("La", &LightData.La.r);
      ImGui::ColorEdit4("Ld", &LightData.Ld.r);
      ImGui::ColorEdit4("Ls", &LightData.Ls.r);
      ImGui::SliderFloat3("pos", &LightData.pos_w.r, -100.0f, 100.0f);
      ImGui::End();

      light_ubo.BufferSubData(0, sizeof(StdUniforms::LightUniforms), &LightData);
   }
}


