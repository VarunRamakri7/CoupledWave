#include <GL/glew.h>
#include <glm/glm.hpp>
#include <glm/gtc/constants.hpp>
#include "imgui.h"
#include "imgui_impl_glfw.h"
#include "imgui_impl_opengl3.h"
#include "implot.h"

#include "DrawGui.h"
#include "Scene.h"
#include "Timer.h"
#include "Uniforms.h"
#include "VideoRecorder.h"
#include "GlGui.h"
#include "Shader.h"
#include "ComputeShader.h"
#include "ScreenGrabber.h"
#include "Fbo.h"
#include "Renderer.h"
#include "SceneModules.h"
#include "ComputeTests.h"
#include "ImagePicker.h"

bool DrawGui::HideGui = false;

namespace DrawGui
{
   void ShaderErrorPopup();

   void Display(GLFWwindow* window)
   {
      if (HideGui == true) return;
      //Begin ImGui Frame
      ImGui_ImplOpenGL3_NewFrame();
      ImGui_ImplGlfw_NewFrame();
      ImGui::NewFrame();

      static bool show_image_picker = false;
      static bool show_debug_window = false;
      static bool show_imgui_test = false;
      static bool show_implot_test = false;
      static bool show_scene_uniforms = false;
      static bool show_material_uniforms = false;
      static bool show_light_uniforms = false;
      static bool show_capture_options = false;
      static bool show_tex_browser = false;
      static bool show_fbo_browser = false;
      static bool show_buffer_browser = false;
      static bool show_shader_browser = false;
      static bool mute_debug = false;

#pragma region menubar

      if (ImGui::BeginMainMenuBar())
      {
         if (ImGui::BeginMenu("File"))
         {
            if (ImGui::MenuItem("Open Image", 0, show_image_picker))
            {
               show_image_picker = !show_image_picker;
            }
            ImGui::EndMenu();
         }
         if (ImGui::BeginMenu("Uniforms"))
         {
            if (ImGui::MenuItem("Scene", 0, show_scene_uniforms))
            {
               show_scene_uniforms = !show_scene_uniforms;
            }
            if (ImGui::MenuItem("Light", 0, show_light_uniforms))
            {
               show_light_uniforms = !show_light_uniforms;
            }
            if (ImGui::MenuItem("Material", 0, show_material_uniforms))
            {
               show_material_uniforms = !show_material_uniforms;
            }
            ImGui::EndMenu();
         }

         ComputeShaderGui::Menu();
         ModuleGui::Menu();
         ComputeTest::Menu();
         RendererGui::Menu();
         TimerGui::Menu();
         BlitGui::Menu();

         if (ImGui::BeginMenu("Blit"))
         {
            ImGui::EndMenu();
         }

         if (ImGui::BeginMenu("Capture"))
         {
            if (ImGui::MenuItem("Show capture options", 0, show_capture_options))
            {
               show_capture_options = !show_capture_options;
            }
            ImGui::EndMenu();
         }
         if (ImGui::BeginMenu("Debug"))
         {
            if (ImGui::MenuItem("Show/Hide GUI", "F1", HideGui))
            {
               HideGui = !HideGui;
            }
            if (ImGui::MenuItem("Debug Menu", 0, show_debug_window))
            {
               show_debug_window = !show_debug_window;
            }
            if (ImGui::MenuItem("Shader Browser", 0, show_shader_browser))
            {
               show_shader_browser = !show_shader_browser;
            }
            if (ImGui::MenuItem("Texture Browser", 0, show_tex_browser))
            {
               show_tex_browser = !show_tex_browser;
            }
            if (ImGui::MenuItem("FBO Browser", 0, show_fbo_browser))
            {
               show_fbo_browser = !show_fbo_browser;
            }
            if (ImGui::MenuItem("Buffer Browser", 0, show_buffer_browser))
            {
               show_buffer_browser = !show_buffer_browser;
            }
            if (ImGui::MenuItem("ImGui Test Window", 0, show_imgui_test))
            {
               show_imgui_test = !show_imgui_test;
            }
            if (ImGui::MenuItem("ImPlot Test Window", 0, show_implot_test))
            {
               show_implot_test = !show_implot_test;
            }
            if (ImGui::MenuItem("Mute Debug Messages", 0, mute_debug))
            {
               mute_debug = !mute_debug;
               glDebugMessageControl(GL_DONT_CARE, GL_DONT_CARE, GL_DONT_CARE, 0, nullptr, !mute_debug);
            }
            ImGui::EndMenu();
         }
         ImGui::EndMainMenuBar();
      }
#pragma endregion 

      if(show_debug_window == true)
      {
         ImGui::Begin("Debug window", &show_debug_window);
         if (ImGui::Button("Quit"))
         {
            glfwSetWindowShouldClose(window, GLFW_TRUE);
         }

         ImGui::Text("Application average %.3f ms/frame (%.1f FPS)", 1000.0f / ImGui::GetIO().Framerate, ImGui::GetIO().Framerate);
         ImGui::End();
      }

#pragma region screenshot and video capture
      if (show_capture_options == true || VideoRecorder::Recording() == true)
      {
         ImGui::Begin("Capture", &show_capture_options);
         const int filename_len = 256;
         static char video_filename[filename_len] = "capture.mp4";
         ImGui::Checkbox("Capture Gui", &Scene::CaptureGui);

         ImGui::BeginDisabled(Scene::RecordingBuffer == false && VideoRecorder::Recording() == true);
         if (Scene::RecordingBuffer == false)
         {
            if (ImGui::Button("Start Recording"))
            {
               int w, h;
               glfwGetFramebufferSize(window, &w, &h);
               const int fps = 60;
               const int bitrate = 4000000;
               VideoRecorder::Start(video_filename, w, h, fps, bitrate); //Using ffmpeg
               Scene::RecordingBuffer = true;
            }
         }
         else
         {
            if (ImGui::Button("Stop Recording"))
            {
               VideoRecorder::Stop(); 
               Scene::RecordingBuffer = false;
            }
         }
         ImGui::EndDisabled();
         ImGui::SameLine();
         ImGui::InputText("Video filename", video_filename, filename_len);

         if (ImGui::Button("Screenshot"))
         {
            GLint buffer = GL_BACK;
            if(Scene::CaptureGui == true) buffer = GL_FRONT;
            screenshot.Grab("", buffer);
         }
         ImGui::End();
      }
#pragma endregion

      ImagePicker::DrawGui(show_image_picker);
      TextureBrowser::DrawGui(show_tex_browser);
      FboBrowser::DrawGui(show_fbo_browser);
      BufferBrowser::DrawGui(show_buffer_browser);
      ShaderBrowser::DrawGui(show_shader_browser);
      ComputeShaderGui::DrawGui();
      ModuleGui::DrawGui();
      RendererGui::DrawGui();
      TimerGui::DrawGui();
      BlitGui::DrawGui();

      scene_uniforms_gui(show_scene_uniforms);
      material_uniforms_gui(show_material_uniforms);
      light_uniforms_gui(show_light_uniforms);

      ShaderErrorPopup();

      if (show_imgui_test)
      {
         ImGui::ShowDemoWindow(&show_imgui_test);
      }

      if (show_implot_test)
      {
         ImPlot::ShowDemoWindow(&show_implot_test);
      }
   
      Module::sAutoDrawGui();

      //End ImGui Frame
      ImGui::Render();
      ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
   }

   void ShaderErrorPopup()
   {
      if (Shader::GetError() == false && ComputeShader::GetError() == false) return;
      ImGui::PushStyleColor(ImGuiCol_PopupBg, IM_COL32(155, 0, 0, 255));
      ImGui::OpenPopup("Shader Compilation Error");

      // Always center this window when appearing
      ImVec2 center = ImGui::GetMainViewport()->GetCenter();
      ImGui::SetNextWindowPos(center, ImGuiCond_Appearing, ImVec2(0.5f, 0.5f));

      if (ImGui::BeginPopupModal("Shader Compilation Error", NULL, ImGuiWindowFlags_AlwaysAutoResize))
      {
         ImGui::Text("Error: Check text console for details\n\n");
         ImGui::Separator();

         if (ImGui::Button("OK", ImVec2(120, 0)))
         {
            ImGui::CloseCurrentPopup();
            Shader::ClearError();
            ComputeShader::ClearError();
         }
         ImGui::SetItemDefaultFocus();
         ImGui::EndPopup();
      }
      ImGui::PopStyleColor();
   }
};