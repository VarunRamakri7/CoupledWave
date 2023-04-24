#include "Scene.h"
#include "GL/glcorearb.h"
#include <iostream>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtx/transform.hpp>
#include <glm/gtc/type_ptr.hpp>

#include "DebugCallback.h"
#include "Callbacks.h"
#include "Uniforms.h"
#include "DrawGui.h"

#include "ComputeTests.h"
#include "VideoRecorder.h" 
#include "Fbo.h"
#include "ImageTexture.h"
#include "ScreenGrabber.h"
#include "SceneModules.h"
#include "RaytraceGrid.h"
#include "Trackball.h"
#include "InitShader.h"
#include "LoadTexture.h"

ScreenGrabber screenshot;
Trackball trackball;
SkyboxRenderer skybox_renderer;

Wave2D wave_2d;
SphModule sph_module;
WaveSphModule wave_sph_module;

//XpbdWaveModule xpbd_grid;



RenderFbo render_fbo;
BlitFbo blit_fbo;
std::vector<ImageTexture> render_tex(2);

namespace Scene
{
   bool CaptureGui = true;
   bool RecordingBuffer = false;
   bool ClearDefaultFb = true;
   std::string ShaderDir = "shaders/";
   std::string MeshDir = "assets/";
   std::string TextureDir = "assets/";
}

namespace Camera
{
   StdUniforms::ProjectionParams mProjParams{ glm::pi<float>() / 4.0f , 0.1f, 100.0f, 1.0f};

   void UpdateP()
   {  
      mProjParams.mAspect = float(SceneData.Viewport[2]) / float(SceneData.Viewport[3]);
      SceneData.P = glm::perspective(mProjParams.mFov, mProjParams.mAspect, mProjParams.mNear, mProjParams.mFar);
      SceneData.PV = SceneData.P * SceneData.V;
      SceneData.ViewportAspect = mProjParams.mAspect;
      if(SceneData.ViewportAspect >=1.0f)
      {
         SceneData.P_ortho = glm::ortho(-SceneData.ViewportAspect, SceneData.ViewportAspect, -1.0f, +1.0f);
      }
      else
      {
         SceneData.P_ortho = glm::ortho(-1.0f, +1.0f, -1.0f/ SceneData.ViewportAspect, 1.0f/ SceneData.ViewportAspect);
      }
      if (scene_ubo.mBuffer != -1)
      {
         scene_ubo.BufferSubData(0, sizeof(SceneData), &SceneData); //TODO: only when camera changes
      }
   }

   void UpdateV()
   {
      SceneData.V = glm::translate(glm::vec3(-SceneData.eye_w)) * trackball.GetM();
      SceneData.PV = SceneData.P * SceneData.V;
      if(scene_ubo.mBuffer != -1)
      {
         scene_ubo.BufferSubData(0, sizeof(SceneData), &SceneData); //TODO: only when camera changes
      }
   }
};

// This function gets called every time the scene gets redisplayed
void Scene::Display(GLFWwindow* window)
{
   if(ClearDefaultFb == true)
   {
      glBindFramebuffer(GL_FRAMEBUFFER, 0);
      glDrawBuffer(GL_BACK);
      glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
   }
   scene_ubo.BindBufferBase(); 

   render_fbo.PreRender();
      skybox_renderer.Draw(); //draw skybox first
      //draw mesh
      Callbacks::DragAndDropMeshRenderer.Draw();
      //draw modules
      Module::sAutoDraw();
   render_fbo.PostRender();

   if (blit_fbo.mInputTexture.GetTexture() == render_fbo.mOutputTextures[0]->GetTexture())
   {
      blit_fbo.BlitRect(glm::value_ptr(SceneData.Viewport), glm::value_ptr(SceneData.Viewport));
   }
   else
   {
      blit_fbo.Blit(glm::value_ptr(SceneData.Viewport));
   }

   //Record before GUI is drawn
   if (VideoRecorder::Recording() == true && Scene::RecordingBuffer == true && Scene::CaptureGui == false)
   {
      VideoRecorder::EncodeBuffer(GL_BACK);
   }

   DrawGui::Display(window);

   //Record after GUI is drawn
   if (VideoRecorder::Recording() == true && Scene::RecordingBuffer == true && Scene::CaptureGui == true)
   {
      VideoRecorder::EncodeBuffer(GL_BACK);
   }

   //Swap front and back buffers
   glfwSwapBuffers(window);
}

void Scene::Idle()
{
   static float prev_time_sec = 0.0f;
   float time_sec = static_cast<float>(glfwGetTime());
   float dt = time_sec-prev_time_sec;
   prev_time_sec = time_sec;

   SceneData.Time = time_sec;
   SceneData.DeltaTime = dt;
   SceneData.Frame++;
   scene_ubo.BufferSubData(offsetof(SceneData, Time), sizeof(SceneData.Time)+sizeof(SceneData.DeltaTime)+sizeof(SceneData.Frame), &SceneData.Time);

   Module::sAutoAnimate(time_sec, dt);
   Module::sAutoCompute();
}

//Initialize OpenGL state. This function only gets called once.
void Scene::Init()
{
#pragma region subsystem intializations
   glewInit();
   RegisterDebugCallback();
   screenshot.Init();
   SetShaderDir(ShaderDir);
   SetMeshDir(MeshDir);
   SetTextureDir(TextureDir);
#pragma endregion

#pragma region glGet OpenGL info

   //Print out information about the OpenGL version supported by the graphics driver.	
   std::ostringstream oss;
   oss << "GL_VENDOR: " << glGetString(GL_VENDOR) << std::endl;
   oss << "GL_RENDERER: " << glGetString(GL_RENDERER) << std::endl;
   oss << "GL_VERSION: " << glGetString(GL_VERSION) << std::endl;
   oss << "GL_SHADING_LANGUAGE_VERSION: " << glGetString(GL_SHADING_LANGUAGE_VERSION) << std::endl;

   int max_invocations = 0;
   glGetIntegerv(GL_MAX_COMPUTE_WORK_GROUP_INVOCATIONS, &max_invocations);
   oss << "GL_MAX_COMPUTE_WORK_GROUP_INVOCATIONS: " << max_invocations << std::endl;

   glm::ivec3 max_work_group_count;
   glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_COUNT, 0, &max_work_group_count.x);
   glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_COUNT, 1, &max_work_group_count.y);
   glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_COUNT, 2, &max_work_group_count.z);
   oss << "GL_MAX_COMPUTE_WORK_GROUP_COUNT: "
                                 << max_work_group_count.x << ", "
                                 << max_work_group_count.y << ", "
                                 << max_work_group_count.z << std::endl;

   glm::ivec3 max_work_group_size;
   glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_SIZE, 0, &max_work_group_size.x);
   glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_SIZE, 1, &max_work_group_size.y);
   glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_SIZE, 2, &max_work_group_size.z);
   oss << "GL_MAX_COMPUTE_WORK_GROUP_SIZE: "
                                 << max_work_group_size.x << ", "
                                 << max_work_group_size.y << ", "
                                 << max_work_group_size.z << std::endl;

   int shared_mem_size = 0;
   glGetIntegerv(GL_MAX_COMPUTE_SHARED_MEMORY_SIZE, &shared_mem_size);
   oss << "GL_MAX_COMPUTE_SHARED_MEMORY_SIZE: " << shared_mem_size << std::endl;

   int max_uniform_blocks = 0;
   glGetIntegerv(GL_MAX_COMPUTE_UNIFORM_BLOCKS, &max_uniform_blocks);
   oss << "GL_MAX_COMPUTE_UNIFORM_BLOCKS: " << max_uniform_blocks << std::endl;

   int max_uniform_block_size = 0;
   glGetIntegerv(GL_MAX_UNIFORM_BLOCK_SIZE, &max_uniform_block_size);
   oss << "GL_MAX_UNIFORM_BLOCK_SIZE: " << max_uniform_block_size << std::endl;
   
   int max_storage_blocks = 0;
   glGetIntegerv(GL_MAX_COMPUTE_SHADER_STORAGE_BLOCKS, &max_storage_blocks);
   oss << "GL_MAX_COMPUTE_SHADER_STORAGE_BLOCKS: " << max_storage_blocks << std::endl;

   int max_storage_block_size = 0;
   glGetIntegerv(GL_MAX_SHADER_STORAGE_BLOCK_SIZE, &max_storage_block_size);
   oss << "GL_MAX_SHADER_STORAGE_BLOCK_SIZE: " << max_storage_block_size << std::endl;

   int max_compute_texture_image_units = 0;
   glGetIntegerv(GL_MAX_COMPUTE_TEXTURE_IMAGE_UNITS, &max_compute_texture_image_units);
   oss << "GL_MAX_COMPUTE_TEXTURE_IMAGE_UNITS: " << max_compute_texture_image_units << std::endl;

   int max_texture_size = 0;
   glGetIntegerv(GL_MAX_TEXTURE_SIZE, &max_texture_size);
   oss << "GL_MAX_TEXTURE_SIZE: " << max_texture_size << std::endl;
   
   int max_3d_texture_size = 0;
   glGetIntegerv(GL_MAX_3D_TEXTURE_SIZE, &max_3d_texture_size);
   oss << "GL_MAX_3D_TEXTURE_SIZE: " << max_3d_texture_size << std::endl;

#ifdef GL_SUBGROUP_SIZE_KHR
   int subgroup_size = 0; //warp/wavefront size
   glGetIntegerv(GL_SUBGROUP_SIZE_KHR, &subgroup_size);
   oss << "GL_SUBGROUP_SIZE_KHR: " << subgroup_size << std::endl;
#endif
   
   //Output to console and file
   std::cout << oss.str();

   std::fstream info_file("info.txt", std::ios::out | std::ios::trunc);
   info_file << oss.str();
   info_file.close();
#pragma endregion

#pragma region OpenGL initial state
   SceneData.clear_color = glm::vec4(1.0f);
   glClearColor(SceneData.clear_color.r, SceneData.clear_color.g, SceneData.clear_color.b, SceneData.clear_color.a);

   glEnable(GL_DEPTH_TEST);

   //Enable gl_PointCoord in shader
   glEnable(GL_POINT_SPRITE);
   //Allow setting point size in fragment shader
   glEnable(GL_PROGRAM_POINT_SIZE);

   if (enable_msaa)
   {
      glEnable(GL_MULTISAMPLE);
   }
   else
   {
      glDisable(GL_MULTISAMPLE);
   }
#pragma endregion

   skybox_renderer = SkyboxRenderer::GetDefault();
   skybox_renderer.SetAutoMode(false);
   skybox_renderer.SetWantsDraw(false);

   ClearDefaultFb = true;

   init_ubos();

   glGetIntegerv(GL_VIEWPORT, &SceneData.Viewport[0]);
   Camera::UpdateV();
   Camera::UpdateP();

   //Render to texture
   for (int i = 0; i < 2; i++)
   {
      render_tex[i].SetTarget(GL_TEXTURE_2D);
      render_tex[i].SetSize(glm::ivec3(screen_size, 1));
      render_tex[i].SetLevelsToMax();
      render_tex[i].SetInternalFormat(GL_RGBA32F);
      render_tex[i].Init();
   }
   render_fbo.Init(screen_size, 0);
   render_fbo.PushAttachment(&render_tex[0]);

   //Blit the output
   blit_fbo.Init();
   blit_fbo.SetOutputSize(screen_size);
   BlitGui::SetBlitFbo(&blit_fbo);

   //Modules
   const bool test_mode = false;

   if (test_mode == true)
   {
      //sph_module.SetGuiOpen(true);
      wave_sph_module.SetGuiOpen(true);
   }

   wave_2d.SetAutoMode(false);
   wave_2d.Init();
   //wave_2d.SetAutoMode(true);

   sph_module.SetAutoMode(false);
   sph_module.Init();
   //sph_module.SetAutoMode(true);

   //wave_sph_module.SetAutoMode(false);
   //wave_sph_module.Init();
   wave_sph_module.SetAutoMode(true);
   
   blit_fbo.SetInputTexture(*render_fbo.mOutputTextures[0]);

   Timer::SetPrintAll(false);
   Module::sAutoInit();

}
