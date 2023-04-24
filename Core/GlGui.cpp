#include "GlGui.h"
#include "UniformGui.h"
#include "GlEnumToString.h"
#include "imgui.h"
#include "GL/glew.h"
#include <glm/glm.hpp>

void gl_disable_blend(const ImDrawList* parent_list, const ImDrawCmd* cmd)
{
   glDisable(GL_BLEND);
}

void gl_enable_blend(const ImDrawList* parent_list, const ImDrawCmd* cmd)
{
   glEnable(GL_BLEND);
}

void im_disable_blend()
{
   ImGui::GetWindowDrawList()->AddCallback(gl_disable_blend, nullptr);
}

void im_enable_blend()
{
   ImGui::GetWindowDrawList()->AddCallback(gl_enable_blend, nullptr);
}

void TextureBrowser::TextureGui(int id)
{
      static bool id_change = true;
      
      static int last_id=-1;
      if(last_id != id) id_change = true;
      else id_change = false;
      last_id = id;

      int target, layers, levels, filter[2], wrap[3], size[3], format;
      int min_lod, max_lod, immutable;
      glGetTextureParameteriv(id, GL_TEXTURE_TARGET, &target);
      glGetTextureParameteriv(id, GL_TEXTURE_VIEW_NUM_LAYERS, &layers);
      //glGetTextureParameteriv(id, GL_TEXTURE_MIN_LOD, &min_lod);
      //glGetTextureParameteriv(id, GL_TEXTURE_MAX_LOD, &max_lod);
      glGetTextureParameteriv(id, GL_TEXTURE_VIEW_NUM_LEVELS, &levels);
      levels = glm::max(1, levels);
      layers = glm::max(1, layers);

      glGetTextureParameteriv(id, GL_TEXTURE_MIN_FILTER, &filter[0]);
      glGetTextureParameteriv(id, GL_TEXTURE_MAG_FILTER, &filter[1]);

      glGetTextureParameteriv(id, GL_TEXTURE_WRAP_S, &wrap[0]);
      glGetTextureParameteriv(id, GL_TEXTURE_WRAP_T, &wrap[1]);
      glGetTextureParameteriv(id, GL_TEXTURE_WRAP_R, &wrap[2]);

      glGetTextureParameteriv(id, GL_TEXTURE_IMMUTABLE_FORMAT, &immutable);

      glGetTextureLevelParameteriv(id, 0, GL_TEXTURE_WIDTH, &size[0]);
      glGetTextureLevelParameteriv(id, 0, GL_TEXTURE_HEIGHT, &size[1]);
      glGetTextureLevelParameteriv(id, 0, GL_TEXTURE_DEPTH, &size[2]);

      glGetTextureLevelParameteriv(id, 0, GL_TEXTURE_INTERNAL_FORMAT, &format);

      ImGui::Text("Target %s", GlEnumToString::get_tex(target).c_str());
      ImGui::Text("Format %s", GlEnumToString::get_tex(format).c_str());
      ImGui::Text("Layers %d", layers);
      ImGui::Text("Levels %d", levels);
      ImGui::Text("Filter %s, %s", GlEnumToString::get_tex(filter[0]).c_str(), GlEnumToString::get_tex(filter[1]).c_str());
      ImGui::Text("Wrap %s, %s, %s", GlEnumToString::get_tex(wrap[0]).c_str(), GlEnumToString::get_tex(wrap[1]).c_str(), GlEnumToString::get_tex(wrap[2]).c_str());
      ImGui::Text("Size %d, %d, %d", size[0], size[1], size[2]);

      static int level = 0;
      static int layer = 0;
      if (id_change == true) //rest level and layer
      {
         level=0;
         layer=0;
      }

      bool level_change = ImGui::SliderInt("Level", &level, 0, levels - 1);
      bool layer_change = ImGui::SliderInt("Layer", &layer, 0, layers - 1);

      int level_size[3];
      glGetTextureLevelParameteriv(id, level, GL_TEXTURE_WIDTH, &level_size[0]);
      glGetTextureLevelParameteriv(id, level, GL_TEXTURE_HEIGHT, &level_size[1]);
      glGetTextureLevelParameteriv(id, level, GL_TEXTURE_DEPTH, &level_size[2]);
      ImGui::Text("Level Size %d, %d, %d", level_size[0], level_size[1], level_size[2]);

      static bool blend = true;
      ImGui::Checkbox("Enable preview blending", &blend);
      
      const int min_size = 32;
      ImVec2 isize(glm::max(level_size[0], min_size), glm::max(level_size[1], min_size));
      if(target == GL_TEXTURE_2D)
      {
         if(bool(immutable)==true)
         {
            static GLuint tex_view = -1;
            if (level_change || layer_change || tex_view==-1 || id_change)
            {
               if (tex_view != -1 || id_change)
               {
                  glDeleteTextures(1, &tex_view);
                  tex_view = -1;
               }
               glGenTextures(1, &tex_view);
               if(tex_view != id)
               {
                  glTextureView(tex_view, target, id, format, level, 1, layer, 1);
               }
            }

            if(tex_view != -1 && tex_view != id)
            {
               if (blend == false) im_disable_blend();
               ImGui::Image((void*)tex_view, isize);
               if (blend == false) im_enable_blend();
            }
         }
         else
         {
            ImGui::Text("Can't browse mipmaps or layers of mutable textures");
            if (blend == false) im_disable_blend();
            ImGui::Image((void*)id, isize);
            if (blend == false) im_enable_blend();
         }
      }
      if (target == GL_TEXTURE_3D)
      {
         static int slice = 0;
         static GLuint tex_slice = -1;
         static bool slice_change=false;
         if (ImGui::SliderInt("Slice", &slice, 0, level_size[2] - 1))
         {
            slice_change = true;
         }
         if (level_change || layer_change || id_change)
         {
            slice == 0;
         }
         if (slice_change || level_change || layer_change || id_change)
         {
            if (tex_slice != -1)
            {
               glDeleteTextures(1, &tex_slice);
               tex_slice = -1;
            }
            glGenTextures(1, &tex_slice);
            glCreateTextures(GL_TEXTURE_2D, 1, &tex_slice);
            glTextureStorage2D(tex_slice, 1, format, level_size[0], level_size[1]);
            glCopyImageSubData(id, target, level, 0, 0, slice, tex_slice, GL_TEXTURE_2D, 0, 0, 0, 0, level_size[0], level_size[1], 1);
         }
         
         if (blend == false) im_disable_blend();
         ImGui::Image((void*)tex_slice, isize);
         if (blend == false) im_enable_blend();
      }
     
}


void TextureBrowser::DrawGui(bool& open)
{
   if(open==false) return;
   ImGui::Begin("Texture Browser", &open);
   static int id = 1;
   ImGui::SliderInt("ID", &id, 0, 32);

   bool is_texture = glIsTexture(id);
   if (is_texture == false)
   {
      ImGui::Text("Not a valid texture id");
   }
   else
   {
      TextureGui(id);
   }
   ImGui::End();
}

void FboBrowser::DrawGui(bool& open)
{
   if (open == false) return;
   ImGui::Begin("Fbo Browser", &open);
   static int id = 1;
   ImGui::SliderInt("ID", &id, 0, 32);
   

   bool is_fbo = glIsFramebuffer(id);
   if (is_fbo == false)
   {
      ImGui::Text("Not a valid fbo id");
   }
   else
   {
      GLint max_attach = 0;
      glGetIntegerv(GL_MAX_COLOR_ATTACHMENTS, &max_attach);
      int type, r_size, g_size, b_size, a_size, depth_size, stencil_size, name;

      ImGui::Text("Depth Attachment");
      glGetNamedFramebufferAttachmentParameteriv(id, GL_DEPTH_ATTACHMENT, GL_FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE, &type);
      ImGui::Text("Type %s", GlEnumToString::get_fbo(type).c_str());
      if(type != GL_NONE)
      {
         glGetNamedFramebufferAttachmentParameteriv(id, GL_DEPTH_ATTACHMENT, GL_FRAMEBUFFER_ATTACHMENT_DEPTH_SIZE, &depth_size);
         ImGui::Text("Depth size %d", depth_size);
      }
      
      ImGui::Text("Stencil Attachment");
      glGetNamedFramebufferAttachmentParameteriv(id, GL_STENCIL_ATTACHMENT, GL_FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE, &type);
      ImGui::Text("Type %s", GlEnumToString::get_fbo(type).c_str());
      if (type != GL_NONE)
      {
         glGetNamedFramebufferAttachmentParameteriv(id, GL_STENCIL_ATTACHMENT, GL_FRAMEBUFFER_ATTACHMENT_STENCIL_SIZE, &stencil_size);
         ImGui::Text("Stencil size %d", stencil_size);
      }

      ImGui::Text("Max color attachments: %d", max_attach);

      static int attachment_ix=0;
      ImGui::SliderInt("Attachment", &attachment_ix, 0, max_attach-1);
      int attachment = GL_COLOR_ATTACHMENT0 + attachment_ix;
      
      glGetNamedFramebufferAttachmentParameteriv(id, attachment, GL_FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE, &type);
      if (type == GL_NONE)
      {
         ImGui::Text("No attachment");
      }
      else
      {
         glGetNamedFramebufferAttachmentParameteriv(id, attachment, GL_FRAMEBUFFER_ATTACHMENT_RED_SIZE, &r_size);
         glGetNamedFramebufferAttachmentParameteriv(id, attachment, GL_FRAMEBUFFER_ATTACHMENT_GREEN_SIZE, &g_size);
         glGetNamedFramebufferAttachmentParameteriv(id, attachment, GL_FRAMEBUFFER_ATTACHMENT_BLUE_SIZE, &b_size);
         glGetNamedFramebufferAttachmentParameteriv(id, attachment, GL_FRAMEBUFFER_ATTACHMENT_ALPHA_SIZE, &a_size);
         glGetNamedFramebufferAttachmentParameteriv(id, attachment, GL_FRAMEBUFFER_ATTACHMENT_DEPTH_SIZE, &depth_size);
         glGetNamedFramebufferAttachmentParameteriv(id, attachment, GL_FRAMEBUFFER_ATTACHMENT_STENCIL_SIZE, &stencil_size);
         glGetNamedFramebufferAttachmentParameteriv(id, attachment, GL_FRAMEBUFFER_ATTACHMENT_OBJECT_NAME, &name);

         ImGui::Text("Type %s", GlEnumToString::get_fbo(type).c_str());
         ImGui::Text("R,G,B,A size %d, %d, %d, %d", r_size, g_size, b_size, a_size);
         ImGui::Text("Depth size %d", depth_size);
         ImGui::Text("Stencil size %d", stencil_size);

         if (type == GL_RENDERBUFFER)
         {
            ImGui::Text("Renderbuffer id %d", name);
         }
         if (type == GL_TEXTURE)
         {
            ImGui::Text("Texture id %d", name);

            int level, layer;
            glGetNamedFramebufferAttachmentParameteriv(id, attachment, GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_LAYER, &layer);
            glGetNamedFramebufferAttachmentParameteriv(id, attachment, GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_LEVEL, &level);
            ImGui::Text("Attachment layer %d", layer);
            ImGui::Text("Attachment level %d", level);
            ImGui::Separator();
            ImGui::Text("Texture %d info", name);
            TextureBrowser::TextureGui(name);
         }
      }
      
   }
   ImGui::End();
}

#include <vector>
namespace BufferBrowser
{
   GLuint debug_buffer=-1;
   int debug_buffer_size = 4*4*16;
   std::vector<char> buffer_data;

   void init_debug_buffer()
   {
      buffer_data.resize(debug_buffer_size);
      if (debug_buffer != -1)
      {
         glDeleteBuffers(1, &debug_buffer);
         debug_buffer = -1;
      }
      glGenBuffers(1, &debug_buffer);
      glBindBuffer(GL_COPY_WRITE_BUFFER, debug_buffer);
      glNamedBufferStorage(debug_buffer, debug_buffer_size, 
         nullptr, GL_MAP_PERSISTENT_BIT| GL_MAP_READ_BIT| GL_MAP_WRITE_BIT);
   }
}

void BufferBrowser::DrawGui(bool& open)
{
   if (open == false) return;
   ImGui::Begin("Buffer Browser", &open);
   static int id = 1;
   ImGui::SliderInt("ID", &id, 0, 32);

   bool is_buffer = glIsBuffer(id);
   if (is_buffer == false)
   {
      ImGui::Text("Not a valid buffer id");
   }
   else
   {
      int immutable, flags, usage, size;
      glGetNamedBufferParameteriv(id, GL_BUFFER_SIZE, &size);
      glGetNamedBufferParameteriv(id, GL_BUFFER_IMMUTABLE_STORAGE, &immutable);
      glGetNamedBufferParameteriv(id, GL_BUFFER_STORAGE_FLAGS, &flags);
      glGetNamedBufferParameteriv(id, GL_BUFFER_USAGE, &usage);

      ImGui::Text("Size %d bytes", size);
      ImGui::Text("Immutable %d, Flags %d, Usage %d", immutable, flags, usage);
      
      if (id != debug_buffer)
      {
         if (debug_buffer == -1)
         {
            init_debug_buffer();
         }
         static int read_offset = 0;
         static int read_offset_floats = 0;
         if (ImGui::SliderInt("Read Offset (bytes)", &read_offset, 0, size))
         {
            read_offset_floats = read_offset/4;
         }
         if (ImGui::SliderInt("Read Offset (sizeof(float))", &read_offset_floats, 0, size/4))
         {
            read_offset = 4*read_offset_floats;
         }

         const int write_offset = 0;
         int copy_size = glm::min(debug_buffer_size, size-read_offset);
         glCopyNamedBufferSubData(id, debug_buffer, read_offset, write_offset, copy_size);
         //glGetNamedBufferSubData(debug_buffer, 0, copy_size, buffer_data.data());

         //float* fp = (float*)(buffer_data.data());
         float* fp = (float*)glMapNamedBuffer(debug_buffer, GL_READ_WRITE);
         int rows = copy_size/4/4;

         //TODO: pick int/float fmt
         //TODO: edit buffer contents

         static int f = 0;
         ImGui::RadioButton("float", &f, 0); ImGui::SameLine();
         ImGui::RadioButton("int", &f, 1); ImGui::SameLine();
         ImGui::RadioButton("uint", &f, 2);
         const char* fmts[] = {"%f", "%i", "%u"};
         const char* fmt = fmts[f];


         if (ImGui::BeginTable("Buffer Preview", 5))
         {
            for (int row = 0; row < rows; row++)
            {
               ImGui::TableNextRow();
               ImGui::TableNextColumn();
                  ImGui::Text(fmt, fp[4 * row + 0]);
               ImGui::TableNextColumn();
                  ImGui::Text(fmt, fp[4 * row + 1]);
               ImGui::TableNextColumn();
                  ImGui::Text(fmt, fp[4 * row + 2]);
               ImGui::TableNextColumn();
                  ImGui::Text(fmt, fp[4 * row + 3]);
               ImGui::TableNextColumn();
            }
            ImGui::EndTable();
            glUnmapNamedBuffer(debug_buffer);
            glCopyNamedBufferSubData(debug_buffer, id, write_offset, read_offset, copy_size);
         }
/*
         if (ImGui::BeginTable("Buffer Preview", 5))
         {
            for (int row = 0; row < rows; row++)
            {
               ImGui::TableNextRow();
               ImGui::TableNextColumn();
               //ImGui::Text(fmt, fp[4 * row + 0]);
                  ImGui::PushID(4 * row + 0);
                  //ImGui::InputFloat("", &fp[4 * row + 0], 0.0f, 0.0f, "%.6f");
                  ImGui::InputScalar("", ImGuiDataType_Float, &fp[4 * row + 0], nullptr, nullptr, "%.6f");
                  ImGui::PopID();
               ImGui::TableNextColumn();
               //ImGui::Text(fmt, fp[4 * row + 1]);
                  ImGui::PushID(4 * row + 1);
                  ImGui::InputFloat("", &fp[4 * row + 1], 0.0f, 0.0f, "%.6f");
                  ImGui::PopID();
               ImGui::TableNextColumn();
               //ImGui::Text(fmt, fp[4 * row + 2]);
                  ImGui::PushID(4 * row + 2);
                  ImGui::InputFloat("", &fp[4 * row + 2], 0.0f, 0.0f, "%.6f");
                  ImGui::PopID();
               ImGui::TableNextColumn();
               //ImGui::Text(fmt, fp[4 * row + 3]);
                  ImGui::PushID(4 * row + 3);
                  ImGui::InputFloat("", &fp[4 * row + 3], 0.0f, 0.0f, "%.6f");
                  ImGui::PopID();
               ImGui::TableNextColumn();
            }
            ImGui::EndTable();
            glUnmapNamedBuffer(debug_buffer);
            glCopyNamedBufferSubData(debug_buffer, id, write_offset, read_offset, copy_size);
         }
*/

/*
         for (int i = 0; i < rows; i++)
         {
            ImGui::Text("%f, %f, %f, %f", fp[4*i+0], fp[4 * i + 1], fp[4 * i + 2], fp[4 * i + 3]);
         }
*/
      }
   }
   ImGui::End();
}


void ShaderBrowser::DrawGui(bool& open)
{
   if (open == false) return;
   ImGui::Begin("Shader Browser", &open);
   static int id = 1;
   ImGui::SliderInt("ID", &id, 0, 32);

   static bool show_uniforms = false;
   static bool show_uniform_blocks = false;

   bool is_shader = glIsProgram(id);
   if (is_shader == false)
   {
      ImGui::Text("Not a valid program id");
   }
   else
   {
      int valid;
      glGetProgramiv(id, GL_VALIDATE_STATUS, &valid);
      if (valid == 0)
      {
         ImGui::Text("Program invalid");
      }
      else
      {
         int num_attribs, num_shaders;
         glGetProgramiv(id, GL_ACTIVE_ATTRIBUTES, &num_attribs);
         glGetProgramiv(id, GL_ATTACHED_SHADERS, &num_shaders);
         ImGui::Text("Num shaders %d, num attribs %d", num_attribs, num_shaders);
      }
      
      ImGui::Checkbox("Show uniforms", &show_uniforms);
      ImGui::SameLine();
      ImGui::Checkbox("Show uniform blocks", &show_uniform_blocks);
   }
   ImGui::End();

   if (is_shader==true && show_uniforms == true)
   {
      UniformGui(id, "Shader Browser");
   }

   if (is_shader == true && show_uniform_blocks == true)
   {
      UniformBlockWindow(id, "Shader Browser", show_uniform_blocks);
   }
}

