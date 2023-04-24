#pragma once

#include <vector>
#include "Module.h"
#include "ImageTexture.h"
#include "ComputeShader.h"
#include "ComputePattern.h"

class ImageReductionPattern :public ComputePattern
{
public:
   void Init() override;
   ImageTexture Compute(const ImageTexture& inout);
 
protected:

   void BindData(const ImageTexture& img, int level);
   glm::ivec3 Reduce(glm::ivec3 size);
};
