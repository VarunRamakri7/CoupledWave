#include <windows.h>
#include "ScreenGrabber.h"
#include <GL/glew.h>
#include <filesystem>
#include <chrono>

void ScreenGrabber::Init()
{
   FreeImage_Initialise(1);
}

std::string ScreenGrabber::GenerateFilename()
{
   std::chrono::system_clock::time_point tp = std::chrono::system_clock::now();
   tp = std::chrono::zoned_time{ std::chrono::current_zone(), tp };
   std::string stem = std::format("{:%F-%H-%M-%S}", tp);
   return mDir + stem + mExt;
}

void ScreenGrabber::Grab(const std::string& filename, GLenum buffer)
{
   int vp[4];
   glGetIntegerv(GL_VIEWPORT, vp);
   mBuffer.resize(vp[2]*vp[3]*mBpp);
   
   glReadBuffer(buffer);
   glPixelStorei(GL_PACK_ALIGNMENT, 1);
   glReadPixels(vp[0], vp[1], vp[2], vp[3], GL_BGR, GL_UNSIGNED_BYTE, mBuffer.data());
   
   FIBITMAP* image = FreeImage_ConvertFromRawBits(mBuffer.data(), vp[2], vp[3], 3 * vp[2], 24, 0x0000FF, 0xFF0000, 0x00FF00, false);

   if (std::filesystem::exists(mDir) == false)
   {
      std::filesystem::create_directory(mDir);
   }

   if(filename.length() == 0)
   {
      std::string gen_name = GenerateFilename();
      bool success = FreeImage_Save(FIF_PNG, image, gen_name.c_str(), 0);
   }
   else
   {
      bool success = FreeImage_Save(FIF_PNG, image, filename.c_str(), 0);
   }
   FreeImage_Unload(image);
}





TiledGrabber::TiledGrabber(int h_tiles, int v_tiles, int tile_w, int tile_h):
mHTiles(h_tiles), mVTiles(v_tiles), mTileWidth(tile_w), mTileHeight(tile_h)
{
   const int width = mHTiles*mTileWidth;
   const int height = mVTiles*mTileHeight;
   mImage = FreeImage_Allocate(width, height, mBpp*8, 0x0000FF, 0xFF0000, 0x00FF00);
   mBuffer.resize(mTileWidth*mTileHeight*mBpp);
}

TiledGrabber::~TiledGrabber()
{
   FreeImage_Unload(mImage);
}

void TiledGrabber::GrabTile(int i, int j, GLenum buffer)
{
   glReadBuffer(buffer);
   glPixelStorei(GL_PACK_ALIGNMENT, 1);
   glReadPixels(0, 0, mTileWidth, mTileHeight, GL_BGR, GL_UNSIGNED_BYTE, mBuffer.data());
   
   FIBITMAP* tile = FreeImage_ConvertFromRawBits(mBuffer.data(), mTileWidth, mTileHeight, 3 * mTileWidth, mBpp*8, 0x0000FF, 0xFF0000, 0x00FF00, true);
   const int alpha = 256;
   FreeImage_Paste(mImage, tile, i*mTileWidth, j*mTileHeight, alpha);
}

void TiledGrabber::Save(const std::string& filename)
{
   FreeImage_Save(FIF_PNG, mImage, filename.c_str(), 0);
}