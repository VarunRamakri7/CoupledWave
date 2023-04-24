#include "Buffer.h"
#include <cassert>
#include <vector>
#include <GL/glew.h>

Buffer::Buffer(GLuint target, GLuint binding): mTarget(target), mBinding(binding)
{

}

void Buffer::Free()
{
   if (mBuffer != -1)
   {
      glDeleteBuffers(1, &mBuffer);
   }
   mBuffer = -1;
   mSize = 0;
}

void Buffer::Init(int size, void* data, GLuint flags)
{
   mSize = size;
   mFlags = flags;
   if(mEnableDebug == true)
   {
      mFlags = mFlags | GL_MAP_PERSISTENT_BIT | GL_MAP_READ_BIT;
   }
   
   if(mBuffer != -1)
   {
      glDeleteBuffers(1, &mBuffer);
   }

   glGenBuffers(1, &mBuffer);
   glBindBuffer(mTarget, mBuffer);
   glNamedBufferStorage(mBuffer, size, data, mFlags);
}

void Buffer::ClearToInt(int i)
{
   //assert(false); //this function may not work correctly. float version is fine.
   static int si;
   si = i;
   glClearNamedBufferData(mBuffer, GL_R32I, GL_RED_INTEGER, GL_INT, (void*)&si);
}

void Buffer::ClearToUint(unsigned int u)
{
   //assert(false); //this function may not work correctly. float version is fine.
   static unsigned int su;
   su = u;
   glClearNamedBufferData(mBuffer, GL_R32UI, GL_RED_INTEGER, GL_UNSIGNED_INT, (void*)&su);
}

void Buffer::ClearToFloat(float f)
{
   static float sf;
   sf = f;
   glClearNamedBufferData(mBuffer, GL_R32F, GL_RED, GL_FLOAT, (void*)&sf);
}

void Buffer::CopyToBufferSubData(Buffer& dest)
{
   assert(mSize == dest.mSize);
   glCopyNamedBufferSubData(mBuffer, dest.mBuffer, 0, 0, mSize);
}

void Buffer::CopyFromBufferSubData(Buffer& src)
{
   assert(mSize == src.mSize);
   glCopyNamedBufferSubData(src.mBuffer, mBuffer, 0, 0, mSize);
}

void Buffer::GetBufferSubData(void* data)
{
   glGetNamedBufferSubData(mBuffer, 0, mSize, data);
}

void Buffer::BufferSubData(int offset, int size, void* data)
{
   glNamedBufferSubData(mBuffer, offset, size, data);
}

void Buffer::BindBufferBase() const
{
   glBindBufferBase(mTarget, mBinding, mBuffer);
}

void Buffer::BindBufferBase(GLuint binding) const
{
   mBinding = binding;
   BindBufferBase();
}

void Buffer::DebugReadInt()
{
   if(mEnableDebug)
   {
      std::vector<int> buf(mSize / sizeof(int));
      glGetNamedBufferSubData(mBuffer, 0, mSize, buf.data());
   }
}

void Buffer::DebugReadFloat()
{
   if(mEnableDebug)
   {
      std::vector<float> buf(mSize / sizeof(float));
      glGetNamedBufferSubData(mBuffer, 0, mSize, buf.data());
   }
}



BufferArray::BufferArray(GLuint target) : Buffer(target)
{

}

void BufferArray::Init(int max_elements, int size, void* data, GLuint flags)
{
   mMaxElements = max_elements;
   mNumElements = mMaxElements;
   mElementSize = size;
   mSize = mNumElements* mElementSize;
   Buffer::Init(mSize, data, flags);
}



