#pragma once

#include <glm/glm.hpp>
#include "Buffer.h"

struct DebugData
{
	glm::ivec4 mErrorCode = glm::ivec4(0);
	glm::ivec4 mDebugDataInt = glm::ivec4(0);
	glm::vec4 mDebugDataFloat = glm::vec4(0.0f);
};

//TODO: SHould this be a singleton?
class DebugBuffer
{
	public:
		void Init();
		void Bind();
		glm::ivec4 CheckForErrors();

	protected:
		DebugData* pDebugData = nullptr;
		Buffer mDebugBuffer = Buffer(GL_SHADER_STORAGE_BUFFER);
		bool mEnableDebugBreak = true;
		bool mDebugBreakContinue = false;
		const int kDebugBinding = 15;
};
