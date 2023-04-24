#pragma once
#include <iostream>
#include "Module.h"
#include "Uniforms.h"
#include "Renderer.h"
#include "UniformGrid.h"
#include "MeshDataGeometry.h"
#include "LoadTexture.h"
#include "imgui.h"
#include <iostream>
#include <fstream>
#include <glm/gtc/random.hpp>
#include <glm/gtx/transform.hpp>
#include <glm/gtc/type_ptr.hpp>


namespace SceneModules
{
   struct Particle
   {
      glm::vec4 pos;
      glm::vec4 vel;
      glm::vec4 acc;
   };
   
   namespace ParticleAttribLoc
   {
      const int pos = 0;
      const int vel = 1;
      const int acc = 2;
   };
}

struct Wave2D : public Module
{
   ImageStencil mWave2dStencil;
   ComputeShader mWave2dStencilCs = ComputeShader("wave2D_cs.glsl");

   HeightmapRenderer mHeightmapRenderer;
   Texture2DRenderer mTexture2DRenderer;
   Renderer* pRenderer = nullptr;

   ShadowmapRenderer mShadowmapRenderer;

   enum Mode
   {
      INIT = 0,
      ITERATE = 1 
   };

   const glm::ivec3 mImageSize = glm::ivec3(256, 256, 1);
   const int mNumImages = 3;
   std::vector<ImageTexture> mWave2dImages = std::vector<ImageTexture>(mNumImages, ImageTexture(GL_TEXTURE_2D));

   void Init() override
   {
      mHeightmapRenderer = HeightmapRenderer::GetDefault();
      StdUniforms::MaterialUniforms& mat = mHeightmapRenderer.GetMaterial().mMaterial;
      mat.ka = glm::vec4(0.5f);
      mat.kd = glm::vec4(0.6f, 0.75f, 1.0f, 1.0f);
      mat.ks = glm::vec4(1.5f);
      mat.shininess = 60.0f;
      mHeightmapRenderer.Init();
      mTexture2DRenderer = Texture2DRenderer::GetDefault();
      mTexture2DRenderer.Init();
      pRenderer = &mHeightmapRenderer;

      mShadowmapRenderer.SetShadowmapSize(glm::ivec2(2048, 2048));
      mShadowmapRenderer.SetRenderer(&mHeightmapRenderer);
      mShadowmapRenderer.SetSceneUniforms(SceneData, scene_ubo);
      mShadowmapRenderer.Init();

      StdUniforms::LookAtParams look;
      look.mPos = glm::vec4(10.0f, 10.0f, 0.0f, 1.0f);//LightData.pos_w;
      look.mAt = glm::vec4(0.0);
      look.mUp = glm::vec4(0.0f, 0.0f, 1.0f, 0.0f);
      mShadowmapRenderer.SetLightLookAt(look);

      StdUniforms::ProjectionParams proj;
      proj.mFov = 0.157f;
      proj.mNear = 5.0f;
      proj.mFar = 100.0f;
      proj.mAspect = 1.0;
      mShadowmapRenderer.SetLightProjection(proj);

      //mWave2dStencilCs.Init();
      mWave2dStencil.SetComputeShader(mWave2dStencilCs);
      mWave2dStencil.Init();

      for (int i = 0; i < mWave2dImages.size(); i++)
      {
         mWave2dImages[i].SetSize(mImageSize);
         mWave2dImages[i].Init();
      }

      Reinit();
   }
   void Reinit() override
   {
      mWave2dStencilCs.SetMode(INIT);
      mWave2dStencil.Compute(mWave2dImages);

      glCopyImageSubData(mWave2dImages[1].GetTexture(), mWave2dImages[1].GetTarget(), 0, 0, 0, 0,
         mWave2dImages[0].GetTexture(), mWave2dImages[0].GetTarget(), 0, 0, 0, 0,
         mImageSize.x, mImageSize.y, mImageSize.z);

      glCopyImageSubData(mWave2dImages[1].GetTexture(), mWave2dImages[1].GetTarget(), 0, 0, 0, 0,
         mWave2dImages[2].GetTexture(), mWave2dImages[2].GetTarget(), 0, 0, 0, 0,
         mImageSize.x, mImageSize.y, mImageSize.z);
   }
   void Compute() override
   {
      if (mWantsCompute == false) return;
      mWave2dStencilCs.SetMode(ITERATE);
      mWave2dStencil.Compute(mWave2dImages);
   }

   void Draw() override
   {
      if (mWantsDraw == false) return;
      if (pRenderer == nullptr) return;

      mShadowmapRenderer.Draw();
      GLuint shadow_map = mShadowmapRenderer.GetShadowMap();
      glm::mat4 Shadow = mShadowmapRenderer.GetShadowMatrix();
      const int shadow_map_unit = 2;
      const int shadow_matrix_loc = 10;
      glBindTextureUnit(shadow_map_unit, shadow_map);
      glProgramUniformMatrix4fv(mHeightmapRenderer.GetShader()->GetShaderID(), shadow_matrix_loc, 1, false, glm::value_ptr(Shadow));

      mHeightmapRenderer.SetTexture(mWave2dImages[0].GetTexture());
      mTexture2DRenderer.SetTexture(mWave2dImages[0].GetTexture());
      pRenderer->Draw();
   }

   void DrawGui() override
   {
      if (mWantsDrawGui == false) return;
      Module::DrawGui();
      if (mGuiOpen == true)
      {
         ImGui::Begin(typeid(*this).name(), &mGuiOpen);
        
         if (ImGui::Button("Splash"))
         {
            //Start splash now
            const int splash_frame_loc = 10;
            glProgramUniform1i(mWave2dStencilCs.GetShader(), splash_frame_loc, SceneData.Frame);
         }

         if (ImGui::Button("Wave"))
         {
            //Start wave now
            const int wave_frame_loc = 11;
            glProgramUniform1i(mWave2dStencilCs.GetShader(), wave_frame_loc, SceneData.Frame);
         }

         if (ImGui::Button("Wake"))
         {
             //Start wake now
             const int wake_frame_loc = 12;
             glProgramUniform1i(mWave2dStencilCs.GetShader(), wake_frame_loc, SceneData.Frame);
         }

         ImGui::End();
      }
   }
   
};

struct SphParticle
{
   glm::vec4 pos;
   glm::vec4 vel;
   glm::vec4 force;
};

struct SphModule : public Module
{
   UniformGrid3D mUgrid;
   ComputeShader mUniformGridShader = ComputeShader("uniform_grid_points_3d_cs.glsl");

   BufferGather mBufferGather;
   ComputeShader mBufferGatherCs = ComputeShader("koschier3d_ugrid_cs.glsl");

   int mNumParticles = 4096;
   int mMaxParticles = 64*1024;
   int mSubsteps = 1;
   std::vector<BufferArray> mParticles = std::vector<BufferArray>(2, BufferArray(GL_SHADER_STORAGE_BUFFER));
   AttriblessParticleRenderer mParticleRenderer;
   ShadowmapRenderer mShadowmapRenderer;
   DoubleBufferedGpuTimer mTimer;

   enum Mode
   {
      INIT = 0,
      ITERATE = 1,
      ITERATE_2 = 2
   };


   void Init() override
   {
      mTimer.SetName(typeid(*this).name());

      mParticleRenderer = AttriblessParticleRenderer::GetAttribless3D();
      //mParticleRenderer.SetBlendEnabled(false);
      mParticleRenderer.SetBlendEnabled(true);
      mParticleRenderer.SetBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
      mParticleRenderer.SetDepthMask(true);
      mParticleRenderer.SetNumParticles(mNumParticles);
      mParticleRenderer.Init();

      mShadowmapRenderer.SetShadowmapSize(glm::ivec2(2048, 2048));
      mShadowmapRenderer.SetRenderer(&mParticleRenderer);
      mShadowmapRenderer.SetSceneUniforms(SceneData, scene_ubo);
      mShadowmapRenderer.Init();

      StdUniforms::LookAtParams look;
      look.mPos = LightData.pos_w;
      look.mAt = glm::vec4(0.0);
      look.mUp = glm::vec4(0.0f, 0.0f, 1.0f, 0.0f);
      mShadowmapRenderer.SetLightLookAt(look);

      StdUniforms::ProjectionParams proj;
      proj.mFov = 0.157f;
      proj.mNear = 5.0f;
      proj.mFar = 100.0f;
      proj.mAspect = 1.0;
      mShadowmapRenderer.SetLightProjection(proj);

      for(int i=0; i<2; i++)
      {
         mParticles[i].Init(mMaxParticles, sizeof(SphParticle));
         mParticles[i].mNumElements = mNumParticles;
      }


      GridInfo3D grid;
      grid.mExtents.mMin = glm::vec4(-1.1f, -1.1f, -1.1f, 1.0f);
      grid.mExtents.mMax = glm::vec4(1.1f, 1.1f, 1.1f, 1.0f);
      grid.mNumCells = glm::ivec4(32, 32, 32, 1);
      mUgrid.SetGridInfo(grid);


      mUgrid.SetUniformGridShader(mUniformGridShader);
      mUgrid.SetMaxCellsPerElement(1);
      mUgrid.SetNumElements(mNumParticles);
      mUgrid.Init();

      mBufferGather.SetComputeShader(mBufferGatherCs);
      mBufferGather.SetSubsteps(mSubsteps);
      mBufferGather.Init();

      Reinit();
   }

   void Reinit() override
   {
      mUgrid.Init();
      mUgrid.BindGridInfoUbo();
      mBufferGatherCs.SetMode(INIT);
      mBufferGather.Compute(mParticles);
   }

   void Compute() override
   {
      if (mWantsCompute == false) return;
      mTimer.Restart();
      mUgrid.UpdateGrid(mParticles[0]);

      mBufferGatherCs.SetMode(ITERATE);
      mBufferGather.Compute(mParticles);
      mBufferGatherCs.SetMode(ITERATE_2);
      mBufferGather.Compute(mParticles);
      mTimer.Stop();
   }

   void Draw() override
   {
      if (mWantsDraw == false) return;

      mParticles[0].BindBufferBase(0);
      mShadowmapRenderer.Draw();

      GLuint shadow_map = mShadowmapRenderer.GetShadowMap();
      glm::mat4 Shadow = mShadowmapRenderer.GetShadowMatrix();
      
      const int shadow_map_unit = 2;
      const int shadow_matrix_loc = 10;
      glBindTextureUnit(shadow_map_unit, shadow_map);
      glProgramUniformMatrix4fv(mParticleRenderer.GetShader()->GetShaderID(), shadow_matrix_loc, 1, false, glm::value_ptr(Shadow));
      mParticles[0].BindBufferBase(0);
      mParticleRenderer.Draw();
   }

   void DrawGui() override
   {
      if (mWantsDrawGui == false) return;
      Module::DrawGui();
      if (mGuiOpen == true)
      {
         ImGui::Begin(typeid(*this).name(), &mGuiOpen);
        
         if (ImGui::SliderInt("NumParticles", &mNumParticles, 0, mMaxParticles))
         {
            mParticles[0].mNumElements = mNumParticles;
            mParticles[1].mNumElements = mNumParticles;
            mParticleRenderer.SetNumParticles(mNumParticles);
            mUgrid.SetNumElements(mNumParticles);
         }

         if (ImGui::SliderInt("Substeps", &mSubsteps, 0, 10))
         {
            mBufferGather.SetSubsteps(mSubsteps);
         }

         if (ImGui::Button("Splash"))
         {
            //Start splash now
            const int splash_frame_loc = 10;
            glProgramUniform1i(mBufferGatherCs.GetShader(), splash_frame_loc, SceneData.Frame);
         }

         if (ImGui::Button("Wave"))
         {
            //Start wave now
            const int wave_frame_loc = 11;
            glProgramUniform1i(mBufferGatherCs.GetShader(), wave_frame_loc, SceneData.Frame);
         }

         /*if (ImGui::Button("Wake"))
         {
             //Start wake now
             const int wake_frame_loc = 12;
             glProgramUniform1i(mBufferGatherCs.GetShader(), wake_frame_loc, SceneData.Frame);
         }*/

         ImGui::End();
      }
   }
};


struct WaveSphModule : public SphModule
{
   ImageStencil mWave2dStencil;
   ComputeShader mWave2dStencilCs = ComputeShader("wave2D_cs.glsl");
   HeightmapRenderer mHeightmapRenderer;

   const glm::ivec3 mImageSize = glm::ivec3(256, 256, 1);
   const int mNumImages = 3;
   std::vector<ImageTexture> mWave2dImages = std::vector<ImageTexture>(mNumImages, ImageTexture(GL_TEXTURE_2D));

   SkyboxRenderer mSkyboxRenderer;
   float mWaveScale = 1.0f;
   glm::vec2 mWaveShift = glm::vec2(0.0f);

   bool mPauseWave = false;

   enum WaveMode
   {
      WAVE_INIT = 0,
      WAVE_ITERATE = 1
   };

   void Init() override
   {
      mSkyboxRenderer = SkyboxRenderer::GetDefault();
      GLuint sky_tex = LoadSkybox("sky.png");
      mSkyboxRenderer.SetTexture(sky_tex);

      //Wave init
      mHeightmapRenderer = HeightmapRenderer::GetDefault();
      StdUniforms::MaterialUniforms& mat = mHeightmapRenderer.GetMaterial().mMaterial;
      mat.ka = glm::vec4(0.9f, 1.0f, 1.0f, 1.0f);
      mat.kd = glm::vec4(0.6f, 0.92f, 0.94f, 1.0f);
      mat.ks = glm::vec4(1.0f);
      mat.shininess = 60.0f;
      mHeightmapRenderer.Init();

      //mWave2dStencilCs.Init();
      mWave2dStencil.SetComputeShader(mWave2dStencilCs);
      mWave2dStencil.Init();

      for (int i = 0; i < mWave2dImages.size(); i++)
      {
         mWave2dImages[i].SetSize(mImageSize);
         mWave2dImages[i].Init();
      }

      mBufferGatherCs = ComputeShader("koschier3d_wave_cs.glsl");
      SphModule::Init();
      Reinit();
   }

  void Reinit() override
   {
      SphModule::Reinit();

      mWave2dStencilCs.SetMode(WAVE_INIT);
      mWave2dStencil.Compute(mWave2dImages);

      glCopyImageSubData(mWave2dImages[1].GetTexture(), mWave2dImages[1].GetTarget(), 0, 0, 0, 0,
         mWave2dImages[0].GetTexture(), mWave2dImages[0].GetTarget(), 0, 0, 0, 0,
         mImageSize.x, mImageSize.y, mImageSize.z);

      glCopyImageSubData(mWave2dImages[1].GetTexture(), mWave2dImages[1].GetTarget(), 0, 0, 0, 0,
         mWave2dImages[2].GetTexture(), mWave2dImages[2].GetTarget(), 0, 0, 0, 0,
         mImageSize.x, mImageSize.y, mImageSize.z);
   }

   void Compute() override
   {
      if (mWantsCompute == false) return;
      mTimer.Restart();
      if(mPauseWave==false)
      {
         mWave2dStencilCs.SetMode(WAVE_ITERATE);
         mWave2dStencil.Compute(mWave2dImages);
      }

      mWave2dImages[0].SetUnit(0);
      mWave2dImages[0].BindTextureUnit();

      mUgrid.UpdateGrid(mParticles[0]);

      mWave2dImages[0].SetUnit(0);
      mWave2dImages[0].BindTextureUnit();
      mWave2dImages[1].SetUnit(1);
      mWave2dImages[1].BindTextureUnit();

      mBufferGatherCs.SetMode(ITERATE);
      mBufferGather.Compute(mParticles);
      mBufferGatherCs.SetMode(ITERATE_2);
      mBufferGather.Compute(mParticles);
      mTimer.Stop();
   }

   void Draw() override
   {
      if (mWantsDraw == false) return;
      mSkyboxRenderer.Draw();

      mParticles[0].BindBufferBase(0);
      mShadowmapRenderer.Draw();

      GLuint shadow_map = mShadowmapRenderer.GetShadowMap();
      glm::mat4 Shadow = mShadowmapRenderer.GetShadowMatrix();
      
      const int shadow_map_unit = 2;
      const int shadow_matrix_loc = 10;
      glBindTextureUnit(shadow_map_unit, shadow_map);
      glProgramUniformMatrix4fv(mHeightmapRenderer.GetShader()->GetShaderID(), shadow_matrix_loc, 1, false, glm::value_ptr(Shadow));
      glProgramUniformMatrix4fv(mParticleRenderer.GetShader()->GetShaderID(), shadow_matrix_loc, 1, false, glm::value_ptr(Shadow));

      glBindTextureUnit(1, mSkyboxRenderer.GetTexture());
      mHeightmapRenderer.SetTexture(mWave2dImages[0].GetTexture());
      mHeightmapRenderer.Draw();

      mParticles[0].BindBufferBase(0);
      mParticleRenderer.Draw();
   }

   void DrawGui() override
   {
      if (mWantsDrawGui == false) return;
      Module::DrawGui();
      if (mGuiOpen == true)
      {
         ImGui::Begin(typeid(*this).name(), &mGuiOpen);
        
         if (ImGui::SliderInt("NumParticles", &mNumParticles, 0, mMaxParticles))
         {
            mParticles[0].mNumElements = mNumParticles;
            mParticles[1].mNumElements = mNumParticles;
            mParticleRenderer.SetNumParticles(mNumParticles);
            mUgrid.SetNumElements(mNumParticles);
         }
         ImGui::Checkbox("Pause wave", &mPauseWave);

         if(ImGui::SliderFloat("Wave scale", &mWaveScale, 0.25f, 4.0f))
         {
            const int wave_scale_loc = 20;
            glProgramUniform1f(mBufferGatherCs.GetShader(), wave_scale_loc, mWaveScale);
            glProgramUniform1f(mHeightmapRenderer.GetShader()->GetShaderID(), wave_scale_loc, 1.0/mWaveScale);
         }

         if(ImGui::SliderFloat2("Wave shift", &mWaveShift.x, -1.0f, 1.0f))
         {
            const int wave_shift_loc = 21;
            glProgramUniform2f(mBufferGatherCs.GetShader(), wave_shift_loc, mWaveShift.x, mWaveShift.y);
            glProgramUniform2f(mHeightmapRenderer.GetShader()->GetShaderID(), wave_shift_loc, -mWaveShift.x, -mWaveShift.y);
         }

         if (ImGui::Button("Splash"))
         {
            //Start splash now
            const int splash_frame_loc = 10;
            glProgramUniform1i(mWave2dStencilCs.GetShader(), splash_frame_loc, SceneData.Frame);
         }
         ImGui::SameLine();
         if (ImGui::Button("Wave"))
         {
            //Start wave now
            const int wave_frame_loc = 11;
            glProgramUniform1i(mWave2dStencilCs.GetShader(), wave_frame_loc, SceneData.Frame);
         }
         ImGui::SameLine();
         if (ImGui::Button("Wake"))
         {
            //Start wake now
            const int wake_frame_loc = 12;
            glProgramUniform1i(mWave2dStencilCs.GetShader(), wake_frame_loc, SceneData.Frame);
         }

         ImGui::End();
      }
   }
};