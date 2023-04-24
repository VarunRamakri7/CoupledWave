#pragma once
#include <string>
#include <vector>
#include <GL/glew.h>

namespace ImagePicker
{
      struct ImagePickerItem
      {
         std::string mFilename;
         GLuint mTexture;
         float mAspect;
      };

      void Refresh(std::string dir);
      bool DrawGui(bool& open);
      void AddItem(std::string filename);
      ImagePickerItem* GetPickedItem();
};