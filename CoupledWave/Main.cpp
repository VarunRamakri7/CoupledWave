#include <windows.h>
//When using this as a template, be sure to make these changes in the new project: 
//1. In Debugging properties set the Environment to PATH=%PATH%;$(SolutionDir)\lib;
//2. Change window_title below
//3. Copy assets (mesh and texture) to new project directory

#include <GL/glew.h>
#include <GLFW/glfw3.h>

#include "imgui.h"
#include "imgui_impl_glfw.h"
#include "imgui_impl_opengl3.h"
#include "implot.h"

#include <glm/glm.hpp>
#include <iostream>

#include "Callbacks.h"     //callback function definitions for glfw events
#include "Scene.h"

const bool enable_msaa = false;
const int msaa_samples = 1;

const bool enable_stencil = false;

const bool fullscreen = false;
glm::ivec2 screen_size;
const char* const window_title = PROJECT_NAME; //defined in project settings

void glfw_error(int, const char* err_str)
{
   std::cout << "GLFW Error: " << err_str << std::endl;
}

int main(int argc, char **argv)
{
   GLFWwindow* window;

   /* Initialize the library */
   if (!glfwInit())
   {
      return -1;
   }
   glfwSetErrorCallback(glfw_error);

   //request stencil buffer
   if(enable_stencil)
   {
      glfwWindowHint(GLFW_STENCIL_BITS, 8);
   }

   //Request multisample framebuffer before window is created
   if(enable_msaa)
   {
      glfwWindowHint(GLFW_SAMPLES, msaa_samples);
   }

#ifdef _DEBUG
   glfwWindowHint(GLFW_OPENGL_DEBUG_CONTEXT, GL_TRUE);
#endif

   GLFWmonitor* prim_monitor = glfwGetPrimaryMonitor();
   const GLFWvidmode* mode = glfwGetVideoMode(prim_monitor);
   screen_size.x = mode->width;
   screen_size.y = mode->height;

   glfwWindowHint(GLFW_RED_BITS, mode->redBits);
   glfwWindowHint(GLFW_GREEN_BITS, mode->greenBits);
   glfwWindowHint(GLFW_BLUE_BITS, mode->blueBits);
   glfwWindowHint(GLFW_REFRESH_RATE, mode->refreshRate);
   glfwWindowHint(GLFW_DECORATED, GLFW_TRUE);

   GLFWmonitor* monitor = nullptr;
   if (fullscreen == true)
   {
      glfwWindowHint(GLFW_MAXIMIZED, GLFW_TRUE);
      monitor = prim_monitor;
   }
   /* Create a windowed mode window and its OpenGL context */
   window = glfwCreateWindow(screen_size.x, screen_size.y, window_title, monitor, nullptr);

   if (!window)
   {
      glfwTerminate();
      return -1;
   }

   /* Make the window's context current */
   glfwMakeContextCurrent(window);

   Scene::Init();

   //Register callback functions (from Callbacks.h) with glfw. 
   Callbacks::Register(window);
   
   //Init ImGui
   IMGUI_CHECKVERSION();
   ImGui::CreateContext();
   ImGui_ImplGlfw_InitForOpenGL(window, true);
   ImGui_ImplOpenGL3_Init("#version 150");

   ImPlot::CreateContext();

   /* Loop until the user closes the window */
   while (!glfwWindowShouldClose(window))
   {
      Scene::Idle();
      Scene::Display(window);

      /* Poll for and process events */
      glfwPollEvents();
   }

    // Cleanup ImGui
    ImGui_ImplOpenGL3_Shutdown();
    ImGui_ImplGlfw_Shutdown();
    ImGui::DestroyContext();

    ImPlot::DestroyContext();

   glfwTerminate();
   return 0;
}