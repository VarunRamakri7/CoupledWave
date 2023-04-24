#ifndef __SCREENGRABBER_H__
#define __SCREENGRABBER_H__

#include <FreeImage.h>
#include <windows.h>
#include <string>
#include <vector>
#include <GL/glew.h>

class ScreenGrabber
{

   public:
      void Init();
      void Grab(const std::string& filename = "", GLenum buffer = GL_FRONT);
      std::string GenerateFilename();
      void SetBpp(int bpp) {mBpp = bpp;}
      void SetDir(const std::string& dir) { mDir = dir; }
      void SetExt(const std::string& ext) { mExt = ext; }

   protected:

      std::vector<GLubyte> mBuffer;

      int mBpp = 3; //bytes per pixel (3 or 4)
      std::string mDir = "grabs/";
      std::string mExt = ".png";
};

class TiledGrabber
{
   public:
      TiledGrabber(int h_tiles, int v_tiles, int tile_w, int tile_h);
      ~TiledGrabber();
      void GrabTile(int i, int j, GLenum buffer = GL_FRONT);
      void Save(const std::string& filename = "");

   protected:
      int mHTiles;
      int mVTiles;
      int mTileWidth;
      int mTileHeight;

      int mBpp = 3;   
     
      std::vector<GLubyte> mBuffer;
      FIBITMAP* mImage; 
};

#endif