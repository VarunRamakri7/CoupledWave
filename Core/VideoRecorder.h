#pragma once


#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <GL/glew.h>


namespace VideoRecorder
{
   int Start(const char *filename, int width, int height, int framerate, int64_t bitrate);
   void EncodeBuffer(GLint buffer);
   void EncodeTexture(GLint tex, int level=0);
   void Stop();
   bool Recording();
};