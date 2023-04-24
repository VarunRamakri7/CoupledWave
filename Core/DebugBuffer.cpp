#include "DebugBuffer.h"
#include "windows.h"

void DebugBuffer::Init()
{
   DebugData debug_data;
   mDebugBuffer.Init(sizeof(debug_data), &debug_data, GL_MAP_READ_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT);
   pDebugData = (DebugData*)glMapNamedBufferRange(mDebugBuffer.mBuffer, 0, sizeof(debug_data), GL_MAP_READ_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT);
}

void DebugBuffer::Bind()
{
   #ifndef _DEBUG
      return;
   #endif
   mDebugBuffer.BindBufferBase(kDebugBinding);
}

glm::ivec4 DebugBuffer::CheckForErrors()
{
   #ifndef _DEBUG
      return glm::ivec4(0);
   #endif

   if (pDebugData->mErrorCode.x != 0 && mEnableDebugBreak == true && mDebugBreakContinue == false)
   {
      DebugBreak();  //Check text console for error messages 
      mDebugBreakContinue = true; //This allows execution to continue after the break.
   }

   return pDebugData->mErrorCode;
}