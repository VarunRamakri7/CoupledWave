#pragma once

#include <GL/glew.h>

class Buffer
{
   public:
      GLuint mBuffer = -1;
      mutable GLuint mBinding = -1;
      GLenum mTarget = -1;
      GLuint mFlags = -1;
      GLuint mSize = 0;
      bool mEnableDebug = false;
      
      Buffer(GLuint target = -1, GLuint binding = -1);

      //~Buffer();
      void Free();
      void Init(int size, void* data = 0, GLuint flags = 0);
      void BufferSubData(int offset, int size, void* data);
      void BindBufferBase() const;
      void BindBufferBase(GLuint binding) const;
      void ClearToInt(int i);                   //clear buffer contents to i
      void ClearToUint(unsigned int u);         //clear buffer contents to u
      void ClearToFloat(float f);               //clear buffer contents to f
      void CopyToBufferSubData(Buffer& dest);   //copy buffer contents from this to dest
      void CopyFromBufferSubData(Buffer& src);  //copy buffer contents from src to this
      void GetBufferSubData(void* data);        //copy buffer contents to client memory

      void DebugReadFloat(); //to do: make template
      void DebugReadInt();

};

class BufferArray : public Buffer
{
   public:
      BufferArray(GLuint target = -1);
      void Init(int max_elements, int size, void* data = 0, GLuint flags = 0);

      int mMaxElements = 0;
      int mNumElements = 0;
      int mElementSize = 0;
};
