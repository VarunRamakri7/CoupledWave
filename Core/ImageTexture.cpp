#include "ImageTexture.h"

ImageTexture::ImageTexture(GLenum target):mTarget(target)
{

}

void ImageTexture::CopyState(ImageTexture& src)
{
   mUnit = src.mUnit;
   mTarget = src.mTarget;
   mLevels = src.mLevels;
   mLayers = src.mLayers;
   mInternalFormat = src.mInternalFormat;

   mWrap = src.mWrap;
   mFilter = src.mFilter;
   mSize = src.mSize;
}

void ImageTexture::SetLevelsToMax()
{
   int max_dim = glm::max(mSize.x, glm::max(mSize.y, mSize.z));
   assert(max_dim > 0); //Set size before calling
   mLevels = 1 + int(glm::floor(glm::log2(float(max_dim))));
}

void ImageTexture::Init()
{
   if (mTexture != -1)
   {
      glDeleteTextures(1, &mTexture);
   }

   glCreateTextures(mTarget, 1, &mTexture);

   if (mTarget == GL_TEXTURE_1D)
   {
      glTextureStorage1D(mTexture, mLevels, mInternalFormat, mSize.x);
      glTextureParameteri(mTexture, GL_TEXTURE_WRAP_S, mWrap[0]);
   }
   if(mTarget==GL_TEXTURE_2D)
   {
      glTextureStorage2D(mTexture, mLevels, mInternalFormat, mSize.x, mSize.y);
      glTextureParameteri(mTexture, GL_TEXTURE_WRAP_S, mWrap[0]);
      glTextureParameteri(mTexture, GL_TEXTURE_WRAP_T, mWrap[1]);
   }
   if (mTarget == GL_TEXTURE_3D)
   {
      glTextureStorage3D(mTexture, mLevels, mInternalFormat, mSize.x, mSize.y, mSize.z);
      glTextureParameteri(mTexture, GL_TEXTURE_WRAP_S, mWrap[0]);
      glTextureParameteri(mTexture, GL_TEXTURE_WRAP_T, mWrap[1]);
      glTextureParameteri(mTexture, GL_TEXTURE_WRAP_R, mWrap[2]);
   }

   glTextureParameteri(mTexture, GL_TEXTURE_MIN_FILTER, mFilter[0]);
   glTextureParameteri(mTexture, GL_TEXTURE_MAG_FILTER, mFilter[1]);
}

void ImageTexture::BindImageTexture() const
{
   const int level = 0;
   bool layered = false;
   const int layer = 0;
   if (mTarget == GL_TEXTURE_3D)
   {
      layered = true;
   }
   glBindImageTexture(mUnit, mTexture, level, layered, layer, mAccess, mInternalFormat);
}

void ImageTexture::BindImageTexture(GLenum access) const
{
   mAccess = access;
   const int level = 0;
   bool layered = false;
   const int layer = 0;
   if (mTarget == GL_TEXTURE_3D)
   {
      layered = true;
   }
   glBindImageTexture(mUnit, mTexture, level, layered, layer, access, mInternalFormat);
}

void ImageTexture::BindImageTexture(GLuint unit, GLenum access) const
{
   mUnit = unit;
   BindImageTexture(access);
}

void ImageTexture::BindImageTexture(int level, bool layered, int layer, GLenum access) const
{
   mAccess = access;
   glBindImageTexture(mUnit, mTexture, level, layered, layer, access, mInternalFormat);
}

void ImageTexture::BindTextureUnit() const
{
   glBindTextureUnit(mUnit, mTexture);
}

/*
void ImageTexture::TextureParameter(GLenum pname, GLint param)
{
   glTextureParameteri(mTexture, pname, param);
}
*/

void ImageTexture::SetSize(glm::ivec3 size)
{
   if (mTexture != -1)
   {
      Resize(size);
      return;
   }
   mSize = size;
}

void ImageTexture::Resize(glm::ivec3 size)
{
   glm::ivec3 old_size = mSize;
   GLuint old_tex = mTexture;

   mSize = size;
   mTexture = -1;
   Init();

   if (mTarget == GL_TEXTURE_2D)
   {
      static GLuint fbo = -1;
      if (fbo == -1)
      {
         glGenFramebuffers(1, &fbo);
      }

      const int old_fbo = 0;
      glBindFramebuffer(GL_FRAMEBUFFER, fbo);
      glNamedFramebufferTexture(fbo, GL_COLOR_ATTACHMENT0, old_tex, 0);
      
      glReadBuffer(GL_COLOR_ATTACHMENT0);
      glm::ivec3 overlap = glm::min(old_size, mSize);
      glCopyTextureSubImage2D(mTexture, 0, 0, 0, 0, 0, overlap.x, overlap.y);
      glBindFramebuffer(GL_FRAMEBUFFER, old_fbo);
      glDeleteTextures(1, &old_tex);
   }
}

int GetMipmapLevels(GLuint tex)
{

   glm::ivec3 size;
   glGetTextureLevelParameteriv(tex, 0, GL_TEXTURE_WIDTH, &size.x);
   glGetTextureLevelParameteriv(tex, 0, GL_TEXTURE_HEIGHT, &size.y);
   glGetTextureLevelParameteriv(tex, 0, GL_TEXTURE_DEPTH, &size.z);
   int max_levels = 1 + (int)glm::floor(glm::log2((float)glm::max(size.x, glm::max(size.y, size.z))));
   int num_levels = 0;
   for (int i = 0; i < max_levels; i++)
   {
      int w;
      glGetTextureLevelParameteriv(tex, i, GL_TEXTURE_WIDTH, &w);
      if (w!=0)
      {
         num_levels++;
      }
      else
      {
         break;
      }
   }

   return num_levels;
}

ImageTexture CreateImage(GLuint tex)
{
   ImageTexture img;
   img.mTexture = tex;

   glGetTextureParameteriv(tex, GL_TEXTURE_TARGET, &img.mTarget);

   glGetTextureParameteriv(tex, GL_TEXTURE_VIEW_NUM_LAYERS, &img.mLayers);
   glGetTextureParameteriv(tex, GL_TEXTURE_VIEW_NUM_LEVELS, &img.mLevels);
   //img.mLevels = GetMipmapLevels(tex);

   glGetTextureParameteriv(tex, GL_TEXTURE_MIN_FILTER, &img.mFilter.x);
   glGetTextureParameteriv(tex, GL_TEXTURE_MAG_FILTER, &img.mFilter.y);

   glGetTextureParameteriv(tex, GL_TEXTURE_WRAP_S, &img.mWrap.x);
   glGetTextureParameteriv(tex, GL_TEXTURE_WRAP_T, &img.mWrap.y);
   glGetTextureParameteriv(tex, GL_TEXTURE_WRAP_R, &img.mWrap.y);

   glGetTextureLevelParameteriv(tex, 0, GL_TEXTURE_WIDTH, &img.mSize.x);
   glGetTextureLevelParameteriv(tex, 0, GL_TEXTURE_HEIGHT, &img.mSize.y);
   glGetTextureLevelParameteriv(tex, 0, GL_TEXTURE_DEPTH, &img.mSize.z);

   glGetTextureLevelParameteriv(tex, 0, GL_TEXTURE_INTERNAL_FORMAT, &img.mInternalFormat);

   return img;
}

/*
#include <algorithm>

void SwapUnits(ImageTexture& i0, ImageTexture& i1)
{
   std::swap(i0.mUnit, i1.mUnit);
}
*/