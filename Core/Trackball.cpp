#include <GL/glew.h>
#include <GLFW/glfw3.h>
#include "Trackball.h"
#include <glm/gtx/transform.hpp>


Trackball::Trackball()
{
   mM = glm::mat4(1.0f);
   mDelta = glm::mat4(1.0f);
   mInUse = false;
}

void Trackball::MouseButton(int button, int action, int mods, glm::vec2 pos)
{
   if(button == GLFW_MOUSE_BUTTON_LEFT)
   { 
      if (action == GLFW_RELEASE)
      {
         if (mInUse)
         {
            mM = mDelta*mM;
         }

         mInUse = false;
         mDelta = glm::mat4(1.0f);
         return;
      }

      if (action == GLFW_PRESS)
      {
         int vp[4];
         glGetIntegerv(GL_VIEWPORT, vp);

         const int w = vp[2];
         const int h = vp[3];
         mInUse = true;
         mDelta = glm::mat4(1.0f);

         float r = 1.5f*glm::max(w/2, h/2);
         mClickPt = glm::vec3(pos.x-w/2, -pos.y+h/2, 0.0f);
         mClickPt.z = glm::sqrt(r*r - mClickPt.x*mClickPt.x - mClickPt.y*mClickPt.y);
         mClickPt = glm::normalize(mClickPt);
      }
   }
}

void Trackball::MouseCursor(glm::vec2 pos)
{
   if (mInUse == true)
   {
      int vp[4];
      glGetIntegerv(GL_VIEWPORT, vp);

      const int w = vp[2];
      const int h = vp[3];

      float r = 1.5f*glm::max(w / 2, h / 2);
      glm::vec3 movePt = glm::vec3(pos.x - w / 2, -pos.y + h / 2, 0.0f);
      movePt.z = glm::sqrt(glm::max(0.0f, r*r - movePt.x*movePt.x - movePt.y*movePt.y));
      movePt = glm::normalize(movePt);

      glm::vec3 axis = glm::cross(mClickPt, movePt);

      if(glm::length(axis) < 0.01f)
      {
         return;
      }

      const float speed = 1.5;
      float cos_ang = glm::clamp(glm::dot(mClickPt, movePt), -1.0f, +1.0f);
      float ang = speed*glm::acos(cos_ang);
      mDelta = glm::rotate(ang, axis);
   }
}