#pragma once

#include "Module.h"
#include "ImageTexture.h"
#include "ReductionPattern.h"
#include "StdUniforms.h"

struct RaytraceGrid2D: public Module
{
   ImageMap image_map;
   ImageTexture mGrid = ImageTexture(GL_TEXTURE_2D);
   ComputeShader mShader = ComputeShader("raytrace_grid_2d_cs.glsl");

   void Init() override;
   void Compute() override;
};


struct RaytraceGrid3D: public Module
{
   ImageTexture mVoxels = ImageTexture(GL_TEXTURE_3D);
   ImageTexture mImage = ImageTexture(GL_TEXTURE_2D);

   ImageMap generator_map;
   ComputeShader mGenShader = ComputeShader("generate_grid_3d_cs.glsl");

   ImageMap raytrace_map;
   ComputeShader mRaytraceShader = ComputeShader("raytrace_grid_3d_cs.glsl");

   void Init() override;
   //void Compute() override;
   void GenerateVoxels();
   void GenerateImage();
};

struct RaytraceOctreeGrid3D: public Module
{
   ImageTexture mVoxels = ImageTexture(GL_TEXTURE_3D);
   ImageTexture mImage = ImageTexture(GL_TEXTURE_2D);

   ImageMap generator_map;
   ComputeShader mGenShader = ComputeShader("generate_grid_3d_cs.glsl");

   ImageMap raytrace_map;
   ComputeShader mRaytraceShader = ComputeShader("raytrace_octree_grid_3d_cs.glsl");

   ImageReductionPattern mipmap_reduce;
   ComputeShader mMipmapShader = ComputeShader("image_reduce_3d_cs.glsl");
   void SetProjParamsPointer(StdUniforms::ProjectionParams const* p_params) { pProjParams= p_params;}
   void SetVPointer(glm::mat4 const* pv) {pV = pv;}
   void ComputeP();

   glm::mat4 mM;
   glm::mat4 const * pV;
   glm::mat4 mP;
   StdUniforms::ProjectionParams const * pProjParams = nullptr;

   StdUniforms::MaterialUbo mMaterialUbo;

   void Init() override;
   //void Compute() override;
   void GenerateVoxels();
   void GenerateImage();
};
