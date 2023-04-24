#pragma once
#include <GL/glew.h>
#include <GLFW/glfw3.h>

#include "Main.h"

class Shader;
class ScreenGrabber;
class MeshRenderer;
class Trackball;
class BlitFbo;

extern ScreenGrabber screenshot;
extern Trackball trackball;
extern BlitFbo blit_fbo;

namespace Camera
{
   void UpdateP();
   void UpdateV();
}

namespace Scene
{
   extern bool CaptureGui;
   extern bool RecordingBuffer;
   extern bool ClearDefaultFb;
   void Display(GLFWwindow* window);
   void Idle();
   void Init();
};

