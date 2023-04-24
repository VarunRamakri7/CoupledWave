#include "Callbacks.h"
#include "Scene.h"
#include "Uniforms.h"
#include "DrawGui.h"
#include "Shader.h"
#include "ComputeShader.h"
#include "Renderer.h"
#include "Trackball.h"
#include "ScreenGrabber.h"
#include "Fbo.h"
#include "imgui.h"
#include <iostream>
#include <glm/gtx/transform.hpp>

MeshRenderer Callbacks::DragAndDropMeshRenderer;

void Callbacks::Register(GLFWwindow* window)
{
   glfwSetKeyCallback(window, Keyboard);
   glfwSetCursorPosCallback(window, MouseCursor);
   glfwSetMouseButtonCallback(window, MouseButton);
   glfwSetFramebufferSizeCallback(window, Resize);
   glfwSetDropCallback(window, DragAndDrop);
   glfwSetScrollCallback(window, Scroll);

   DragAndDropMeshRenderer = MeshRenderer::GetDefault();
   DragAndDropMeshRenderer.SetWantsDraw(false);
}

//This function gets called when a key is pressed
void Callbacks::Keyboard(GLFWwindow* window, int key, int scancode, int action, int mods)
{
   //std::cout << "key : " << key << ", " << char(key) << ", scancode: " << scancode << ", action: " << action << ", mods: " << mods << std::endl;

   if (action == GLFW_PRESS)
   {
      switch (key)
      {
      case 'r':
      case 'R':
         Shader::sReloadAll();
         ComputeShader::sReloadAll();
         break;

      case GLFW_KEY_F1:
         DrawGui::HideGui = !DrawGui::HideGui;
         break;
      
      case GLFW_KEY_ESCAPE:
         glfwSetWindowShouldClose(window, GLFW_TRUE);
         break;

      case GLFW_KEY_PRINT_SCREEN:
         screenshot.Grab();
         break;
      }
   }
   Module::sAutoKeyboard(key, scancode, action, mods);
}

//This function gets called when the mouse moves over the window.
void Callbacks::MouseCursor(GLFWwindow* window, double x, double y)
{
   //std::cout << "cursor pos: " << x << ", " << y << std::endl;
   ImGuiIO& io = ImGui::GetIO();
   if (io.WantCaptureMouse) return;

   static glm::vec2 last_pos(0.0f);
   glm::vec2 pos(x,y);
   glm::vec2 delta = pos-last_pos;
   SceneData.MousePos = glm::vec4(pos, delta);

   if (GLFW_PRESS == glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_MIDDLE))
   {
      const float speed = 0.01f;
      SceneData.eye_w.x -= speed * delta.x;
      SceneData.eye_w.y += speed * delta.y;
   }
   
   if (GLFW_PRESS == glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_LEFT))
   {
      SceneData.LmbClickAndDrag.x = pos.x;
      SceneData.LmbClickAndDrag.y = pos.y;
   }
   if (GLFW_PRESS == glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_MIDDLE))
   {
      SceneData.MmbClickAndDrag.x = pos.x;
      SceneData.MmbClickAndDrag.y = pos.y;
   }
   if (GLFW_PRESS == glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_RIGHT))
   {
      SceneData.RmbClickAndDrag.x = pos.x;
      SceneData.RmbClickAndDrag.y = pos.y;
   }

   trackball.MouseCursor(pos);
   Camera::UpdateV(); //update view matrix, buffer all scene uniforms
   last_pos=pos;
   Module::sAutoMouseCursor(pos);
}

//This function gets called when a mouse button is pressed.
void Callbacks::MouseButton(GLFWwindow* window, int button, int action, int mods)
{
   //std::cout << "button : "<< button << ", action: " << action << ", mods: " << mods << std::endl;
   ImGuiIO& io = ImGui::GetIO();
   if (io.WantCaptureMouse) return;

   double x,y;
   glfwGetCursorPos(window, &x, &y);
   glm::vec2 pos(x,y);
   glm::vec2 last_pos = glm::vec2(SceneData.MousePos);
   glm::vec2 delta = pos - last_pos;

   SceneData.MouseButtonState[button] = action;
   SceneData.MousePos = glm::vec4(pos, delta);
   if (action == GLFW_PRESS && button == GLFW_MOUSE_BUTTON_LEFT)
   {
      SceneData.LmbClickAndDrag = glm::vec4(pos, pos);
   }
   if (action == GLFW_PRESS && button == GLFW_MOUSE_BUTTON_MIDDLE)
   {
      SceneData.MmbClickAndDrag = glm::vec4(pos, pos);
   }
   if (action == GLFW_PRESS && button == GLFW_MOUSE_BUTTON_RIGHT)
   {
      SceneData.RmbClickAndDrag = glm::vec4(pos, pos);
   }

   scene_ubo.BufferSubData(offsetof(SceneData, MouseButtonState), 5*sizeof(SceneData.MouseButtonState), &SceneData.MouseButtonState);

   trackball.MouseButton(button, action, mods, pos);
   Module::sAutoMouseButton(button, action, mods, pos);
}

void Callbacks::Scroll(GLFWwindow* window, double xoffset, double yoffset)
{
   //std::cout << "xoffset : "<< xoffset << ", yoffset: " << yoffset << std::endl;
   ImGuiIO& io = ImGui::GetIO();
   if (io.WantCaptureMouse) return;

   SceneData.ScrollPos.x += xoffset;
   SceneData.ScrollPos.y += yoffset;
   SceneData.ScrollPos.z = xoffset;
   SceneData.ScrollPos.w = yoffset;
   scene_ubo.BufferSubData(offsetof(SceneData, ScrollPos), sizeof(SceneData.ScrollPos), &SceneData.ScrollPos);

   SceneData.eye_w.z += 0.1f*yoffset;
   Camera::UpdateV();
}

void Callbacks::Resize(GLFWwindow* window, int width, int height)
{
   //std::cout << "width : " << width << ", height: " << height << std::endl;
   if(width==0 || height==0) return;
   //Set viewport to cover entire framebuffer
   glViewport(0, 0, width, height);
   //Set aspect ratio used in proj matrix calculation
   SceneData.ViewportAspect = float(width) / float(height);
   if (width == 0 || height == 0)
   {
      SceneData.ViewportAspect = 1.0f;
   }
   SceneData.Viewport[2] = width;
   SceneData.Viewport[3] = height;
   Camera::UpdateP(); //update projection matrix, buffer all scene uniforms

   blit_fbo.SetOutputSize(glm::ivec2(SceneData.Viewport[2], SceneData.Viewport[3]));
}


#include "LoadMesh.h"
#include "LoadTexture.h"
#include <filesystem>
namespace fs = std::filesystem;


void Callbacks::DragAndDrop(GLFWwindow* window, int count, const char** paths)
{
   for (int i = 0; i < count; i++)
   {
      if(ValidMeshFilename(paths[i]))
      {  
         MeshData* new_mesh = new MeshData;
         *new_mesh = LoadMesh(paths[i]);
         if (new_mesh->mScene != nullptr)
         {
            DragAndDropMeshRenderer.GetMeshData()->FreeMeshData();
         }
         DragAndDropMeshRenderer.SetMeshData(new_mesh);
      }
      if (ValidTextureFilename(paths[i]))
      {
         GLuint new_tex = LoadTexture(paths[i]);
         GLuint old_tex = DragAndDropMeshRenderer.GetTexture();
         if (new_tex >= 0 && old_tex >= 0)
         {
            glDeleteTextures(1, &old_tex);
         }
         DragAndDropMeshRenderer.SetTexture(new_tex);
      }
   }
}