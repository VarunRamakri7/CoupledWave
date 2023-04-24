#include "ReductionPattern.h"

void ImageReductionPattern::Init()
{
   ComputePattern::Init();
}


void ImageReductionPattern::BindData(const ImageTexture& img, int level)
{
   bool layered = false;
   if(img.GetTarget() == GL_TEXTURE_3D) layered = true;
   const int layer = 0;
   //bind mipmap level to c and level+1 to c+nc
   img.SetUnit(0);
   img.BindImageTexture(level, layered, layer, GL_READ_ONLY);
   img.SetUnit(1);
   img.BindImageTexture(level+1, layered, layer, GL_WRITE_ONLY);
}

glm::ivec3 ImageReductionPattern::Reduce(glm::ivec3 size)
{
   return glm::max(size / 2, glm::ivec3(1));
}

ImageTexture ImageReductionPattern::Compute(const ImageTexture& inout)
{
   assert(pShader != nullptr);
   if (mWantsCompute == false) inout;

   glm::ivec3 size = inout.GetSize();
   glm::ivec3 output_size = Reduce(size);
   int level = 0;

   pShader->UseProgram();
   mTimer.Restart();
   for (;;)
   {
      BindData(inout, level);
      pShader->SetGridSize(output_size);
      pShader->Dispatch();
      glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);

      if (output_size == glm::ivec3(1)) break;

      output_size = Reduce(output_size);
      level = level+1;
   }
   mTimer.Stop();
   return inout;
}

