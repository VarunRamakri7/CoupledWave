#include "ImagePicker.h"
#include "imgui.h"
#include "LoadTexture.h"
#include <filesystem>

namespace ImagePicker
{

   static std::vector<ImagePickerItem> mItems;
   static ImagePickerItem* pPickedItem = nullptr;
   static int mIconHeight = 200;
}

bool ImagePicker::DrawGui(bool& open)
{
   if(open==false) return false;
   std::string dir = GetTextureDir();
   if (mItems.size() == 0)
   {
      Refresh(dir);
   }
   
   bool ret = false;
   if (ImGui::Begin("Image Picker", &open))
   {
      if (ImGui::Button("Refresh"))
      {
         Refresh(dir);
      }

      ImGui::Text("Images in %s", dir.c_str());
      if (mItems.size() == 0)
      {
         ImGui::Text("None");
      }
      else
      {
         const ImVec2 uv0(1.0f, 0.0f);
         const ImVec2 uv1(0.0f, 1.0f);
         for (ImagePickerItem& item : mItems)
         {
            ImVec2 icon_size(item.mAspect * mIconHeight, mIconHeight);
            if (ImGui::ImageButton((void*)item.mTexture, icon_size, uv1, uv0))
            {
               pPickedItem = &item;
               ret = true;
               open = false;
            }
            ImGui::SameLine();
            if (ImGui::Button(item.mFilename.c_str()))
            {
               pPickedItem = &item;
               ret = true;
               open = false;
            }
         }
      }

      ImGui::End();
   }
   return ret;
}

void ImagePicker::Refresh(std::string dir)
{
   pPickedItem = nullptr;
   //Load all models from this directory
   for (const auto& entry : std::filesystem::directory_iterator(dir))
   {
      std::string filename = entry.path().filename().string();
      if (ValidTextureFilename(filename))
      {
         ImagePickerItem item;
         item.mFilename = filename;
         item.mTexture = LoadTexture(filename);
         int w, h;
         glGetTextureLevelParameteriv(item.mTexture, 0, GL_TEXTURE_WIDTH, &w);
         glGetTextureLevelParameteriv(item.mTexture, 0, GL_TEXTURE_HEIGHT, &h);
         item.mAspect = float(w) / float(h);
         mItems.push_back(item);
      }
   }
}

ImagePicker::ImagePickerItem* ImagePicker::GetPickedItem()
{
   return pPickedItem;
}