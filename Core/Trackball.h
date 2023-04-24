#pragma once
#include "Module.h"
#include <glm/glm.hpp>

class Trackball : public Module
{
   private:
      glm::mat4 mM;
      glm::mat4 mDelta;
      bool mInUse;
      glm::vec3 mClickPt;

   public:
      Trackball();
      glm::mat4 GetM() { return mDelta*mM; }
      void MouseCursor(glm::vec2 pos) override;
      void MouseButton(int button, int action, int mods, glm::vec2 pos) override;
};
