

#ifdef _DEBUG

const int kDebugBinding = 15;
layout (std430, binding = kDebugBinding) restrict buffer ERROR 
{
	ivec4 mErrorCode;
	ivec4 mDebugDataInt;
	vec4 mDebugDataFloat;
};

void ClearError()
{
	mErrorCode = ivec4(0);
}

void SetError(int error)
{
	mErrorCode.x = error;
}

void SetError(ivec4 error)
{
	mErrorCode = error;
}

#else

void ClearError(){}
void SetError(int error){}
void SetError(ivec4 error){}
#endif
