#include "RaytraceGrid.h"
#include <glm/glm.hpp>
#include <glm/gtx/transform.hpp>
#include <glm/gtc/type_ptr.hpp>

void RaytraceGrid2D::Init()
{
   mGrid.SetSize(glm::ivec3(256,256,1));
   mGrid.Init();
   mShader.Init();
   image_map.SetComputeShader(mShader);
   image_map.Init();
}

void RaytraceGrid2D::Compute()
{
   mShader.SetMode(1);
   mGrid = image_map.Compute(mGrid);
}


void RaytraceGrid3D::Init()
{
   mGenShader.Init();

   mVoxels.SetSize(glm::ivec3(32));
   mVoxels.Init();
 
   generator_map.SetComputeShader(mGenShader);
   generator_map.Init();

   mRaytraceShader.Init();

   mImage.SetSize(glm::ivec3(1024, 1024, 1));
   mImage.Init();

   raytrace_map.SetComputeShader(mRaytraceShader);
   raytrace_map.Init();
}

void RaytraceGrid3D::GenerateVoxels()
{
   mGenShader.SetMode(0);
   mVoxels.SetAccess(GL_WRITE_ONLY);
   generator_map.Compute(mVoxels);
}

void RaytraceGrid3D::GenerateImage()
{
   mRaytraceShader.SetMode(0);
   mVoxels.BindImageTexture(1, GL_READ_ONLY);
   mImage.SetAccess(GL_WRITE_ONLY);//TODO this gets changed in compute
   raytrace_map.Compute(mImage); 
}

//////////////////////////////////////////////////////////////////////

void RaytraceOctreeGrid3D::Init()
{
   mGenShader.Init();

   const glm::ivec3 voxel_size(64);
   mVoxels.SetSize(glm::ivec3(64));
   mVoxels.SetLevelsToMax();
   mVoxels.Init();

   int size = glm::max(voxel_size.x, glm::max(voxel_size.y, voxel_size.z));
   mM = glm::translate(glm::vec3(-0.5f)) * glm::scale(glm::vec3(1.0f / size));

   generator_map.SetComputeShader(mGenShader);
   generator_map.Init();

   mRaytraceShader.Init();

   const glm::ivec2 image_size(1024);
   mImage.SetSize(glm::ivec3(image_size, 1));
   mImage.Init();

   raytrace_map.SetComputeShader(mRaytraceShader);
   raytrace_map.Init();

   mipmap_reduce.SetComputeShader(mMipmapShader);
   mipmap_reduce.Init();

   mMaterialUbo.mMaterial.ka = glm::vec4(0.5f, 0.5f, 0.5f, 1.0f);
   mMaterialUbo.mMaterial.kd = glm::vec4(0.9f, 0.8f, 0.7f, 1.0f);
   mMaterialUbo.Init();
}

void RaytraceOctreeGrid3D::ComputeP()
{
   assert(pProjParams != nullptr);
   float aspect = float(mImage.GetSize().x)/float(mImage.GetSize().y);
   mP = glm::perspective(pProjParams->mFov, aspect, pProjParams->mNear, pProjParams->mFar);
}

void RaytraceOctreeGrid3D::GenerateVoxels()
{
   const int STATIC_MODE = 0;
   const int ANIMATE_MODE = 1;
   mGenShader.SetMode(ANIMATE_MODE);
   mGenShader.SetMode(ANIMATE_MODE);
   mVoxels.SetAccess(GL_WRITE_ONLY);
   generator_map.Compute(mVoxels);

   //generate mipmap
   const int MAX_MODE = 1;
   mMipmapShader.SetMode(MAX_MODE);
   mipmap_reduce.Compute(mVoxels);
}

void RaytraceOctreeGrid3D::GenerateImage()
{
   ComputeP();
   glm::mat4 PVM = mP*(*pV)*mM;
   glm::mat4 PVinv = glm::inverse(PVM);
   int PV_inv_loc = mRaytraceShader.GetUniformLocation("PVinv");
   glProgramUniformMatrix4fv(mRaytraceShader.GetShader(), PV_inv_loc, 1, false, glm::value_ptr(PVinv));

   mMaterialUbo.Bind();
   mRaytraceShader.SetMode(0);

   mVoxels.SetAccess(GL_READ_ONLY);
   mVoxels.SetUnit(1);
   mVoxels.BindTextureUnit();

   mImage.SetAccess(GL_WRITE_ONLY);
   raytrace_map.Compute(mImage);
}