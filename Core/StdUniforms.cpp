#include "StdUniforms.h"

namespace StdUniforms
{
   //Locations for the uniforms which are not in uniform blocks
   namespace UniformLocs
   {
      int M = 0; //model matrix
      int time = 1;
      int pass = 2;
   }

   namespace UboBinding
   {
      //These values come from the binding value specified in the shader block layout
      int scene = 61;
      int light = 62;
      int material = 63;
   }

   void MaterialUbo::Init()
   {
      if (mUbo.mBuffer != -1)
      {
         mUbo.Free();
      }
      mUbo.Init(sizeof(MaterialUniforms), &mMaterial);
      mUbo.mBinding = UboBinding::material;
   }

   void MaterialUbo::Bind()
   {
      if (mUbo.mBuffer != -1)
      {
         mUbo.BindBufferBase();
      }
   }

}